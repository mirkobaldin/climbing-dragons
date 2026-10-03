--!strict
-- Draghi dei giocatori: collezione, draghi che ti seguono, nido di cova, pietre
-- dell'evoluzione e abilita'. Tutto lato server (il client chiede, il server decide).
--
-- Stato per giocatore (salvato da Progression):
--   dragons    { id, element, rarity, stage }
--   equipped   id dei draghi che ti seguono (max MAX_EQUIPPED, +1 col gamepass)
--   nest       uova in cova { element, rarity, readyAt (os.time) }
--   stones     pietre dell'evoluzione
-- Il client legge lo stato dall'attributo "DragonData" (JSON) e agisce col RemoteFunction
-- "DragonAction" (equip, unequip, evolve, hatch, release).

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local DragonModels = require(script.Parent.DragonModels)

local Dragons = {}

export type DragonData = { id: number, element: string, rarity: string, stage: number }
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
			local model = DragonModels.dragon(d.element, d.rarity, d.stage)
			model:SetAttribute("Owner", player.UserId)
			model:SetAttribute("Slot", slot)
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

function Dragons.refresh(player: Player)
	publish(player)
end

------------------------------------------------------------------------------------------
-- Azioni

function Dragons.give(player: Player, element: string, rarity: string, stage: number?): DragonData?
	local s = Dragons.state(player)
	if #s.dragons >= DragonConfig.MAX_DRAGONS then
		return nil
	end
	local d = { id = s.nextId, element = element, rarity = rarity, stage = stage or 1 }
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

-- Evento di schiusa (lo imposta Eggs per l'effetto al nido)
Dragons.onHatch = nil :: ((Player, NestEgg) -> ())?

local function action(player: Player, kind: any, arg: any): (boolean, string)
	local s = Dragons.state(player)
	if kind == "equip" then
		local d = findDragon(s, tonumber(arg) or -1)
		if not d then
			return false, "Drago non trovato"
		end
		if table.find(s.equipped, d.id) then
			return false, "Ti segue gia'"
		end
		if #s.equipped >= Dragons.maxEquipped(player) then
			table.remove(s.equipped, 1) -- sostituisce il primo
		end
		table.insert(s.equipped, d.id)
		changed(player, true)
		return true, "Ora ti segue!"
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
			return false, "Drago non trovato"
		end
		local nextStage = DragonConfig.STAGES[d.stage + 1]
		if not nextStage then
			return false, "E' gia' adulto"
		end
		if s.stones < nextStage.stones then
			return false, string.format("Servono %d pietre dell'evoluzione (sconfiggi il boss in vetta)", nextStage.stones)
		end
		s.stones -= nextStage.stones
		d.stage += 1
		changed(player, table.find(s.equipped, d.id) ~= nil)
		return true, "Si e' evoluto: " .. nextStage.name .. "!"
	elseif kind == "hatch" then
		local index = tonumber(arg) or -1
		local egg = s.nest[index]
		if not egg then
			return false, "Uovo non trovato"
		end
		if os.time() < egg.readyAt then
			return false, "Non e' ancora pronto"
		end
		if #s.dragons >= DragonConfig.MAX_DRAGONS then
			return false, "Collezione piena: libera un drago"
		end
		table.remove(s.nest, index)
		if Dragons.onHatch then
			(Dragons.onHatch :: any)(player, egg)
		end
		Dragons.give(player, egg.element, egg.rarity, 1)
		local e = DragonConfig.element(egg.element)
		return true, "E' nato un " .. (if e then e.name else "drago") .. " " .. egg.rarity .. "!"
	elseif kind == "release" or kind == "sell" then
		local d, k = findDragon(s, tonumber(arg) or -1)
		if not d or not k then
			return false, "Drago non trovato"
		end
		if #s.dragons <= 1 then
			return false, "Non puoi vendere il tuo unico drago"
		end
		table.remove(s.dragons, k)
		local idx = table.find(s.equipped, d.id)
		if idx then
			table.remove(s.equipped, idx)
		end
		local value = if Dragons.onSell then (Dragons.onSell :: any)(player, d) else 0
		changed(player, idx ~= nil)
		return true, string.format("Venduto per %d monete", value)
	end
	return false, "Azione sconosciuta"
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
	states[player] = s
	checkPasses(player)
	-- Primo accesso: il famiglio iniziale, un cucciolo di Drago Ciliegio che ti segue subito
	if not s.starter then
		s.starter = true
		Dragons.give(player, "Roccia", "Comune", 1)
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
	fn.OnServerInvoke = action

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
		states[player] = nil
	end)
end

return Dragons
