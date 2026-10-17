--!strict
-- Draghi dei giocatori: collezione, draghi che ti seguono, nido di cova, pietre
-- dell'evoluzione e abilita'. Tutto lato server (il client chiede, il server decide).
--
-- Stato per giocatore (salvato da Progression):
--   dragons    { id, element, rarity, stage, level, xp }  (level 1..MAX_LEVEL, si addestra)
--   equipped   id dei draghi che ti seguono (max MAX_EQUIPPED, +1 col gamepass)
--   nest       uova in cova { element, rarity, readyAt (os.time) }
--   stones     pietre dell'evoluzione
-- Il client legge lo stato dall'attributo "DragonData" (JSON) e agisce col RemoteFunction
-- "DragonAction" (equip, unequip, evolve, hatch, release, rename).

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local Names = require(ReplicatedStorage.Shared.Names)
local DragonModels = require(script.Parent.DragonModels)
local Guardia = require(script.Parent.Guardia)

local Dragons = {}

export type DragonData = { id: number, element: string, rarity: string, stage: number, level: number?, xp: number?, shiny: boolean?, atk: number?, crit: number?, name: string? }
export type NestEgg = { element: string, rarity: string, readyAt: number }
export type State = {
	dragons: { DragonData },
	equipped: { number },
	nest: { NestEgg },
	stones: number,
	nextId: number,
	starter: boolean?,
}

local states: { [Player]: State } = {}
local petFolder: Folder

local function newState(): State
	return { dragons = {}, equipped = {}, nest = {}, stones = 0, nextId = 1 }
end

function Dragons.state(player: Player): State
	local s = states[player]
	if not s then
		s = newState()
		states[player] = s
	end
	return s
end

-- Gamepass: attributo "Pass_<nome>" (messo qui sotto se il giocatore lo possiede, o da un admin)
function Dragons.hasPass(player: Player, name: string): boolean
	if player:GetAttribute("Pass_" .. name) then
		return true
	end
	return false
end

local function checkPasses(player: Player)
	for name, id in DragonConfig.GAMEPASSES do
		if id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				player:SetAttribute("Pass_" .. name, true)
			end
		end
	end
end

function Dragons.maxEquipped(player: Player): number
	return DragonConfig.MAX_EQUIPPED + (if Dragons.hasPass(player, "ExtraDragon") then 1 else 0)
end

-- Posti nel nido: dipendono dalla casa (attributo NestSlots, vedi Economy) + gamepass
function Dragons.nestSlots(player: Player): number
	local slots = (player:GetAttribute("NestSlots") or 0) :: number
	if slots <= 0 then
		return 0
	end
	return slots + (if Dragons.hasPass(player, "ExtraIncubator") then 2 else 0)
end

local function findDragon(s: State, id: number): (DragonData?, number?)
	for k, d in s.dragons do
		if d.id == id then
			return d, k
		end
	end
	return nil, nil
end

-- Pubblica lo stato al client e aggiorna abilita' e draghi al seguito
local function publish(player: Player)
	local s = Dragons.state(player)
	player:SetAttribute("DragonCount", #s.dragons) -- sblocca il teletrasporto all'addestramento
	player:SetAttribute("DragonData", HttpService:JSONEncode({
		dragons = s.dragons,
		equipped = s.equipped,
		nest = s.nest,
		stones = s.stones,
		now = os.time(),
		maxEquipped = Dragons.maxEquipped(player),
		nestSlots = Dragons.nestSlots(player),
		roostSlots = player:GetAttribute("RoostSlots") or 0,
	}))
	local abilities = {}
	for _, id in s.equipped do
		local d = findDragon(s, id)
		if d then
			table.insert(abilities, d.element)
		end
	end
	player:SetAttribute("PetAbilities", table.concat(abilities, ","))
end

-- Modelli dei draghi al seguito: stanno in workspace.Pets e li muove/anima ogni client
local function refreshPets(player: Player)
	local s = Dragons.state(player)
	local existing = petFolder:FindFirstChild(tostring(player.UserId))
	if existing then
		existing:Destroy()
	end
	if #s.equipped == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = tostring(player.UserId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if root then root.CFrame else CFrame.new(0, 100, 0)
	for slot, id in s.equipped do
		local d = findDragon(s, id)
		if d then
			local model = DragonModels.dragon(d.element, d.rarity, d.stage, d.level)
			model:SetAttribute("Owner", player.UserId)
			model:SetAttribute("DragonId", d.id)
			model:SetAttribute("Level", d.level or 1)
			model:SetAttribute("Slot", slot)
			if d.name then
				model:SetAttribute("DragonName", d.name) -- nome dato dal giocatore (gia' filtrato)
			end
			model:SetAttribute("Stage", d.stage or 1) -- client/PetAnimator: la sella va solo sull'adulto
			if d.shiny then
				model:SetAttribute("Shiny", true)
			end
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			model:PivotTo(start * CFrame.new(slot * 3, 3, 3))
			model.Parent = folder
		end
	end
	folder.Parent = petFolder
end

-- Agganci impostati da Economy (vendita dei draghi, draghi posati in casa)
Dragons.onSell = nil :: ((Player, DragonData) -> number)?
Dragons.onChanged = nil :: ((Player) -> ())?

local function changed(player: Player, petsToo: boolean)
	publish(player)
	if petsToo then
		refreshPets(player)
	end
	if Dragons.onChanged then
		(Dragons.onChanged :: any)(player)
	end
end

-- Mette il drago "id" al primo posto dei draghi al seguito (quello che si monta, server/Riding);
-- se non ti seguiva prende il posto dell'ultimo
function Dragons.setLead(player: Player, id: number): (boolean, string?)
	local s = Dragons.state(player)
	local d = findDragon(s, id)
	if not d then
		return false, "Dragon not found"
	end
	local idx = table.find(s.equipped, d.id)
	if idx == 1 then
		return true, nil
	end
	if idx then
		table.remove(s.equipped, idx)
	elseif #s.equipped >= Dragons.maxEquipped(player) then
		table.remove(s.equipped)
	end
	table.insert(s.equipped, 1, d.id)
	changed(player, true)
	return true, nil
end

-- danno di un colpo del drago (stadio, livello, statistiche e critico)
function Dragons.hitDamage(d: DragonData): number
	local dmg = DragonConfig.attack(d)
	if math.random() < (d.crit or 0.05) then
		dmg *= 2
	end
	return dmg
end

-- Draghi che ti seguono adesso
function Dragons.equippedDragons(player: Player): { DragonData }
	local s = Dragons.state(player)
	local list = {}
	for _, id in s.equipped do
		local d = findDragon(s, id)
		if d then
			table.insert(list, d)
		end
	end
	return list
end

-- Esperienza a un drago: sale di livello finche' basta (fino a MAX_LEVEL). Restituisce il
-- livello prima e dopo. Il drago cresce un po' ogni 10 livelli (si ricostruisce il modello).
Dragons.onLevelUp = nil :: ((Player, DragonData, number) -> ())?
function Dragons.addXp(player: Player, dragonId: number, amount: number): (number, number)
	local s = Dragons.state(player)
	local d = findDragon(s, dragonId)
	if not d then
		return 0, 0
	end
	-- rinascite e draghi shiny: piu' esperienza
	amount *= UpgradeConfig.xpMult(player) * UpgradeConfig.dragonXp(player) * (if d.shiny then UpgradeConfig.SHINY_XP else 1)
	local before = d.level or 1
	d.level = before
	d.xp = (d.xp or 0) + amount
	while (d.level :: number) < DragonConfig.MAX_LEVEL and (d.xp :: number) >= DragonConfig.xpForLevel(d.level :: number) do
		d.xp = (d.xp :: number) - DragonConfig.xpForLevel(d.level :: number)
		d.level = (d.level :: number) + 1
	end
	if (d.level :: number) >= DragonConfig.MAX_LEVEL then
		d.xp = 0
	end
	local after = d.level :: number
	local grew = before // 10 ~= after // 10
	publish(player)
	if after > before then
		-- il livello sopra la testa del drago al seguito
		local folder = petFolder:FindFirstChild(tostring(player.UserId))
		if folder then
			for _, m in folder:GetChildren() do
				if m:GetAttribute("DragonId") == d.id then
					m:SetAttribute("Level", after)
				end
			end
		end
		if Dragons.onLevelUp then
			(Dragons.onLevelUp :: any)(player, d, after)
		end
		if grew then
			task.delay(1.2, refreshPets, player) -- dopo l'effetto del livello
		end
	end
	return before, after
end

function Dragons.refresh(player: Player)
	publish(player)
end

------------------------------------------------------------------------------------------
-- Azioni

function Dragons.give(player: Player, element: string, rarity: string, stage: number?, shiny: boolean?): DragonData?
	local s = Dragons.state(player)
	if #s.dragons >= DragonConfig.MAX_DRAGONS then
		return nil
	end
	local atk, crit = DragonConfig.rollStats(rarity)
	local d: DragonData = { id = s.nextId, element = element, rarity = rarity, stage = stage or 1, shiny = if shiny then true else nil, atk = atk, crit = crit }
	s.nextId += 1
	table.insert(s.dragons, d)
	local pets = false
	if #s.equipped < Dragons.maxEquipped(player) then
		table.insert(s.equipped, d.id)
		pets = true
	end
	changed(player, pets)
	return d
end

-- Mette un uovo nel nido; false se il nido e' pieno. seconds = tempo di cova forzato
function Dragons.incubate(player: Player, element: string, rarity: string, seconds: number?): boolean
	element = DragonConfig.RETIRED[element] or element
	local s = Dragons.state(player)
	if #s.nest >= Dragons.nestSlots(player) then
		return false
	end
	-- (0 posti = non hai ancora una casa: il nido si sblocca con la Tenda)
	local minutes = DragonConfig.rarity(rarity).hatchMinutes
	if Dragons.hasPass(player, "FastIncubation") then
		minutes *= 0.5
	end
	table.insert(s.nest, { element = element, rarity = rarity, readyAt = os.time() + math.floor(seconds or minutes * 60) })
	changed(player, false)
	return true
end

function Dragons.finishIncubation(player: Player)
	for _, egg in Dragons.state(player).nest do
		egg.readyAt = os.time()
	end
	changed(player, false)
end

function Dragons.addStones(player: Player, amount: number)
	local s = Dragons.state(player)
	s.stones = math.max(0, s.stones + amount)
	changed(player, false)
end

Dragons.onEvolve = nil :: ((Player, DragonData) -> ())?

-- Evento di schiusa (lo imposta Eggs per l'effetto al nido)
Dragons.onHatch = nil :: ((Player, NestEgg) -> ())?

local function action(player: Player, kind: any, arg: any, extra: any): (boolean, string)
	local s = Dragons.state(player)
	if kind == "equip" then
		local d = findDragon(s, tonumber(arg) or -1)
		if not d then
			return false, "Dragon not found"
		end
		if table.find(s.equipped, d.id) then
			return false, "Already following you"
		end
		if #s.equipped >= Dragons.maxEquipped(player) then
			table.remove(s.equipped, 1) -- sostituisce il primo
		end
		table.insert(s.equipped, d.id)
		changed(player, true)
		return true, "Now following you!"
	elseif kind == "unequip" then
		local idx = table.find(s.equipped, tonumber(arg) or -1)
		if idx then
			table.remove(s.equipped, idx)
			changed(player, true)
		end
		return true, ""
	elseif kind == "evolve" then
		local d = findDragon(s, tonumber(arg) or -1)
		if not d then
			return false, "Dragon not found"
		end
		local nextStage = DragonConfig.STAGES[d.stage + 1]
		if not nextStage then
			return false, "Already an adult"
		end
		if (d.level or 1) < DragonConfig.MAX_LEVEL then
			return false, string.format("It must reach level %d: train it at the dragon ribs", DragonConfig.MAX_LEVEL)
		end
		if s.stones < nextStage.stones then
			return false, string.format("You need %d evolution stones: win Dragon Duels in the arena or defeat the Summit Guardian", nextStage.stones)
		end
		s.stones -= nextStage.stones
		d.stage += 1
		d.level = 1
		d.xp = 0
		local following = table.find(s.equipped, d.id) ~= nil
		publish(player)
		if Dragons.onEvolve then
			(Dragons.onEvolve :: any)(player, d)
		end
		-- il modello nuovo arriva dopo il vortice dell'evoluzione
		task.delay(if following then 1.6 else 0, function()
			changed(player, following)
		end)
		return true, "It evolved: " .. Names.t(nextStage.name) .. "!"
	elseif kind == "hatch" then
		-- una schiusa per volta (un doppio tocco schiudeva anche l'uovo successivo)
		if not Guardia.ok(player, "hatch", 1) then
			return false, "One egg at a time"
		end
		local index = tonumber(arg) or -1
		local egg = s.nest[index]
		if not egg then
			return false, "Egg not found"
		end
		if os.time() < egg.readyAt then
			return false, "Not ready yet"
		end
		if #s.dragons >= DragonConfig.MAX_DRAGONS then
			return false, "Collection full: release a dragon"
		end
		table.remove(s.nest, index)
		if Dragons.onHatch then
			(Dragons.onHatch :: any)(player, egg)
		end
		-- ogni tanto nasce un drago Shiny (dorato): piu' esperienza e vale di piu'
		local shiny = math.random() < UpgradeConfig.SHINY_CHANCE or player:GetAttribute("ForceShiny") == true
		player:SetAttribute("ForceShiny", nil) -- (comando admin "shiny")
		Dragons.give(player, egg.element, egg.rarity, 1, shiny)
		return true, string.format("A %s%s %s hatched!", if shiny then "SHINY " else "", Names.t(egg.rarity), Names.dragon(egg.element))
	elseif kind == "release" or kind == "sell" then
		local d, k = findDragon(s, tonumber(arg) or -1)
		if not d or not k then
			return false, "Dragon not found"
		end
		if #s.dragons <= 1 then
			return false, "You can't sell your only dragon"
		end
		table.remove(s.dragons, k)
		local idx = table.find(s.equipped, d.id)
		if idx then
			table.remove(s.equipped, idx)
		end
		local value = if Dragons.onSell then (Dragons.onSell :: any)(player, d) else 0
		changed(player, idx ~= nil)
		return true, string.format("Sold for %d coins", value)
	elseif kind == "rename" then
		-- nome al drago dal livello NAME_LEVEL (lo vedono anche gli altri: va filtrato da Roblox)
		local d = findDragon(s, tonumber(arg) or -1)
		if not d then
			return false, "Dragon not found"
		end
		if (d.level or 1) < DragonConfig.NAME_LEVEL then
			return false, string.format("Reach level %d to give your dragon a name", DragonConfig.NAME_LEVEL)
		end
		if type(extra) ~= "string" then
			return false, "Invalid name"
		end
		local raw = string.gsub(string.gsub(extra, "[^%w ]", ""), "^%s*(.-)%s*$", "%1")
		if #raw < 2 or #raw > 16 then
			return false, "Names are 2-16 letters or numbers"
		end
		local ok, filtered = pcall(function()
			local result = TextService:FilterStringAsync(raw, player.UserId)
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if not ok or type(filtered) ~= "string" or string.find(filtered, "#", 1, true) then
			return false, "That name is not allowed"
		end
		d.name = filtered
		changed(player, table.find(s.equipped, d.id) ~= nil)
		return true, string.format("Your dragon is now called %s!", filtered)
	end
	return false, "Unknown action"
end

------------------------------------------------------------------------------------------
-- Salvataggio (usato da Progression)

function Dragons.serialize(player: Player): any
	local s = states[player]
	return s and {
		dragons = s.dragons,
		equipped = s.equipped,
		nest = s.nest,
		stones = s.stones,
		nextId = s.nextId,
		starter = s.starter,
	}
end

function Dragons.load(player: Player, data: any)
	local s = newState()
	if type(data) == "table" then
		s.dragons = data.dragons or {}
		s.equipped = data.equipped or {}
		s.nest = data.nest or {}
		s.stones = data.stones or 0
		s.nextId = data.nextId or (#s.dragons + 1)
		s.starter = data.starter
	end
	-- i draghi nati prima delle statistiche le ricevono adesso (una volta, poi si salvano)
	for _, d in s.dragons do
		if d.atk == nil then
			d.atk, d.crit = DragonConfig.rollStats(d.rarity)
		end
	end
	states[player] = s
	checkPasses(player)
	-- Primo accesso: niente piu' drago regalato (Mirko 17/10: il primo drago nasce dall'uovo del
	-- tutorial, l'Eclissi e' il drago della vetta). Si regala solo se STARTER_DRAGON torna a esserci
	if not s.starter then
		s.starter = true
		local starter = DragonConfig.STARTER_DRAGON
		if starter then
			Dragons.give(player, starter, "Comune", 1)
		end
	end
	changed(player, true)
end

------------------------------------------------------------------------------------------

function Dragons.setup()
	petFolder = workspace:FindFirstChild("Pets") :: Folder or Instance.new("Folder")
	petFolder.Name = "Pets"
	petFolder.Parent = workspace
	DragonModels.preload()
	task.spawn(DragonModels.makePreviews)

	local fn = Instance.new("RemoteFunction")
	fn.Name = "DragonAction"
	fn.Parent = ReplicatedStorage:WaitForChild("Remotes")
	-- limite: al massimo 6 azioni al secondo per giocatore (server/Guardia)
	fn.OnServerInvoke = function(player: Player, ...: any)
		if not Guardia.ok(player, "dragon", 6) then
			return false, ""
		end
		return action(player, ...)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			refreshPets(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local f = petFolder:FindFirstChild(tostring(player.UserId))
		if f then
			f:Destroy()
		end
		-- i dati si tengono ancora qualche secondo: Progression salva all'uscita e prima trovava
		-- gia' tutto cancellato (il 2026-10-13 ha scritto un profilo senza draghi ne' monete)
		task.delay(10, function()
			if not player.Parent then
				states[player] = nil
			end
		end)
	end)
end

return Dragons
