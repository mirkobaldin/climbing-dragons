--!strict
-- Progressione tra una partita e l'altra:
--   * salvataggio (DataStore) di minerali, attrezzi, ultimo campo base, draghi e tutorial
--   * Banco da lavoro (tag "Workbench"): apre il menu di costruzione sul client; il server
--     controlla i minerali, li scala e da' l'attrezzo (vedi shared/Gear)
--   * freddo: calore del giocatore (attributo "Warmth" 0-100) che cala in quota
-- In Studio il salvataggio funziona solo con "Enable Studio Access to API Services" attivo
-- (Game Settings > Security); senza, si gioca lo stesso ma non si salva.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage.Shared.Gear)
local Names = require(ReplicatedStorage.Shared.Names)
local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)
local Tools = require(script.Parent.Tools)
local Dragons = require(script.Parent.Dragons)
local Economy = require(script.Parent.Economy)
local Survival = require(script.Parent.Survival)
local Upgrades = require(script.Parent.Upgrades)
local Guardia = require(script.Parent.Guardia)
local Drops = require(script.Parent.Drops)

local Progression = {}

local store: DataStore? = nil
local loaded: { [Player]: boolean } = {}

local function inventory(player: Player): Folder
	local folder = player:FindFirstChild("Ores")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Ores"
		folder.Parent = player
	end
	return folder :: Folder
end

local function oreValue(player: Player, ore: string): IntValue
	local folder = inventory(player)
	local v = folder:FindFirstChild(ore) :: IntValue?
	if not v then
		local nv = Instance.new("IntValue")
		nv.Name = ore
		nv.Parent = folder
		v = nv
	end
	return v :: IntValue
end

local function updateTotal(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	local total = stats and stats:FindFirstChild("Ores") :: IntValue?
	if total then
		local sum = 0
		for _, v in inventory(player):GetChildren() do
			if v:IsA("IntValue") then
				sum += v.Value
			end
		end
		total.Value = sum
	end
end

-- Da' (di nuovo) i Tool costruiti: servono a ogni spawn, quindi vanno anche in StarterGear
local function giveTools(player: Player)
	for _, recipe in Gear.RECIPES do
		if recipe.tool and Gear.has(player, recipe.id) then
			local gearFolder = player:FindFirstChild("StarterGear")
			if gearFolder and not gearFolder:FindFirstChild(recipe.name) then
				local tool = Tools.make(recipe.id)
				if tool then
					tool.Parent = gearFolder
					local backpack = player:FindFirstChild("Backpack")
					if backpack and not backpack:FindFirstChild(recipe.name) then
						tool:Clone().Parent = backpack
					end
				end
			end
		end
	end
end

local function save(player: Player)
	if not store or not loaded[player] then
		return
	end
	local data = {
		ores = {},
		gear = {},
		checkpoint = nil :: { number }?,
		dragons = Dragons.serialize(player),
		economy = Economy.serialize(player),
		tutorial = player:GetAttribute("TutorialStep"),
		controls = player:GetAttribute("ControlsLayout"), -- tasti del telefono spostati (client/ControlsEditor)
		bag = player:GetAttribute("BagOrder"), -- ordine delle caselle dello zaino (client/MainMenu)
		hotbar = player:GetAttribute("HotbarOrder"), -- attrezzi nelle caselle 1-5 (client/MainMenu, client/HUD)
		missions = player:GetAttribute("MissionStep"),
		upgrades = Upgrades.serialize(player), -- potenziamenti, statistiche, taglie, rinascite
		materials = (function() -- materiali raccolti (drop dei nemici)
			local t = {}
			local f = player:FindFirstChild("Materiali")
			for _, v in (if f then f:GetChildren() else {}) :: { Instance } do
				if v:IsA("IntValue") then
					t[v.Name] = v.Value
				end
			end
			return t
		end)(),
		gym = { -- palestra
			Forza = { player:GetAttribute("Forza") or 0, player:GetAttribute("ForzaXP") or 0 },
			Resistenza = { player:GetAttribute("Resistenza") or 0, player:GetAttribute("ResistenzaXP") or 0 },
			Recupero = { player:GetAttribute("Recupero") or 0, player:GetAttribute("RecuperoXP") or 0 },
		},
	}
	for _, v in inventory(player):GetChildren() do
		if v:IsA("IntValue") then
			data.ores[v.Name] = v.Value
		end
	end
	for _, recipe in Gear.RECIPES do
		data.gear[recipe.id] = Gear.has(player, recipe.id)
	end
	local cp = player:GetAttribute("Checkpoint")
	if typeof(cp) == "Vector3" then
		data.checkpoint = { cp.X, cp.Y, cp.Z }
	end
	-- prove in Studio (comando admin "nosave"): il Play scrive nel DataStore vero, cosi' i draghi
	-- e le monete di prova non finiscono nel salvataggio
	if player:GetAttribute("NoSave") then
		return
	end
	-- mai un profilo a meta': se draghi, monete o potenziamenti mancano (dati gia' cancellati o non
	-- ancora caricati) non si scrive niente. Il 2026-10-13 un salvataggio cosi' aveva cancellato
	-- draghi, casa e monete di Mirko (recuperati dalla versione precedente del DataStore)
	if data.dragons == nil or data.economy == nil or data.upgrades == nil then
		warn("[Progression] Salvataggio saltato: dati incompleti per " .. player.Name)
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync("player_" .. player.UserId, data)
	end)
	if not ok then
		warn("[Progression] Salvataggio non riuscito: " .. tostring(err))
	end
end

local function load(player: Player)
	local dragonData: any = nil
	local economyData: any = nil
	local tutorial: any = nil
	local missions: any = nil
	local upgradeData: any = nil
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync("player_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			for ore, amount in data.ores or {} do
				oreValue(player, ore).Value = amount
			end
			for id, owned in data.gear or {} do
				if owned then
					player:SetAttribute("Gear_" .. id, true)
				end
			end
			local cp = data.checkpoint
			if type(cp) == "table" and #cp == 3 then
				player:SetAttribute("Checkpoint", Vector3.new(cp[1], cp[2], cp[3]))
			end
			dragonData = data.dragons
			economyData = data.economy
			tutorial = data.tutorial
			if type(data.controls) == "string" and #data.controls < 2000 then
				player:SetAttribute("ControlsLayout", data.controls)
			end
			if type(data.bag) == "string" and #data.bag < 4000 then
				player:SetAttribute("BagOrder", data.bag)
			end
			if type(data.hotbar) == "string" and #data.hotbar < 400 then
				player:SetAttribute("HotbarOrder", data.hotbar)
			end
			missions = data.missions
			upgradeData = data.upgrades
			if type(data.materials) == "table" then
				local f = Instance.new("Folder")
				f.Name = "Materiali"
				for name, n in data.materials do
					local v = Instance.new("IntValue")
					v.Name = tostring(name)
					v.Value = tonumber(n) or 0
					v.Parent = f
				end
				f.Parent = player
			end
			if type(data.gym) == "table" then
				for _, stat in { "Forza", "Resistenza", "Recupero" } do
					local v = data.gym[stat]
					if type(v) == "table" then
						player:SetAttribute(stat, tonumber(v[1]) or 0)
						player:SetAttribute(stat .. "XP", tonumber(v[2]) or 0)
					end
				end
			elseif type(data.fitness) == "table" then
				player:SetAttribute("Resistenza", tonumber(data.fitness[1]) or 0) -- vecchio "Fitness"
			end
		elseif not ok then
			warn("[Progression] Caricamento non riuscito (in Studio attiva l'accesso alle API): " .. tostring(data))
		end
	end
	loaded[player] = true
	player:SetAttribute("TutorialStep", if type(tutorial) == "number" then tutorial else 1)
	player:SetAttribute("MissionStep", if type(missions) == "number" then missions else 1)
	Dragons.load(player, dragonData)
	Economy.load(player, economyData)
	Upgrades.load(player, upgradeData)
	-- i dati dei draghi per il menu (posti nel nido e nel recinto, draghi al seguito) dipendono
	-- dalla casa e dai potenziamenti: si ripubblicano ora che sono caricati (prima il menu diceva
	-- "Buy the Tent" anche a chi aveva il Mega Chalet)
	Dragons.refresh(player)
	updateTotal(player)
	giveTools(player)
end

-- Costruzione: controlla e scala i minerali, poi assegna l'attrezzo
local function craft(player: Player, id: any): (boolean, string)
	if type(id) ~= "string" then
		return false, "Invalid request"
	end
	local recipe = Gear.find(id)
	if not recipe then
		return false, "Unknown item"
	end
	if not recipe.consumable and Gear.has(player, id) then
		return false, "You already have it"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- si crafta solo a un banco: a casa (arriva con la Tenda) o in un campo base
	local nearBench = false
	if root then
		for _, b in CollectionService:GetTagged("Workbench") do
			local pos = if b:IsA("BasePart") then b.Position elseif b:IsA("Model") then b:GetPivot().Position else nil
			if pos and (pos - (root :: BasePart).Position).Magnitude < 30 then
				nearBench = true
			end
		end
	end
	if not nearBench then
		return false, "Craft at a Workbench: at your camp or in a base camp"
	end
	-- l'equipaggiamento vuole un banco da lavoro vicino (quello del campo o quello di casa)
	if recipe.station ~= "Ovunque" then
		local near = false
		for _, bench in CollectionService:GetTagged("Workbench") do
			if root and bench:IsA("BasePart") and bench:IsDescendantOf(workspace) and (bench.Position - root.Position).Magnitude < 16 then
				near = true
				break
			end
		end
		if not near then
			return false, "This is crafted at a Workbench (at camp or your house)"
		end
	end
	-- i consumabili non devono andare sprecati
	if id == "Chiodi" and (player:GetAttribute("Pitons") or 0) >= ClimbConfig.PITONS_MAX then
		return false, "You already carry as many pitons as you can"
	elseif id == "Torcia" and ((character and character:FindFirstChild(ClimbConfig.TORCH_NAME)) or player.Backpack:FindFirstChild(ClimbConfig.TORCH_NAME)) then
		return false, "You already have a torch"
	elseif id == "Bende" and (not humanoid or humanoid.Health >= humanoid.MaxHealth) then
		return false, "You're not hurt"
	end
	-- i costi possono essere minerali (Ores) o materiali dei nemici (Materiali)
	local function costValue(name: string): IntValue
		if Gear.MONSTER_MATERIALS[name] then
			local folder = Drops.materials(player)
			local v = folder:FindFirstChild(name) :: IntValue?
			if not v then
				Drops.add(player, name, 0)
				v = folder:FindFirstChild(name) :: IntValue?
			end
			return v :: IntValue
		end
		return oreValue(player, name)
	end
	for ore, amount in recipe.cost do
		if costValue(ore).Value < amount then
			return false, "You're missing " .. (Drops.NAMES[ore] or Names.t(ore))
		end
	end
	for ore, amount in recipe.cost do
		costValue(ore).Value -= amount
	end
	updateTotal(player)
	if recipe.gives then
		for name, n in recipe.gives do
			Drops.add(player, name, n)
		end
	elseif id == "Chiodi" then
		player:SetAttribute("Pitons", math.min(ClimbConfig.PITONS_MAX, (player:GetAttribute("Pitons") or 0) + 4))
	elseif id == "Torcia" then
		local torch = Tools.make("Torcia")
		if torch then
			torch.Parent = player.Backpack
		end
	elseif id == "Bende" and humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 40)
	else
		player:SetAttribute("Gear_" .. id, true)
		giveTools(player)
	end
	task.spawn(save, player)
	return true, recipe.name .. " crafted!"
end

-- Freddo in quota
local function heatSources(): { Vector3 }
	local list = {}
	for _, inst in CollectionService:GetTagged("HeatSource") do
		if inst:IsA("BasePart") then
			table.insert(list, inst.Position)
		end
	end
	return list
end

local function coldLoop()
	local sources = heatSources()
	local refresh = 0
	while true do
		local dt = task.wait(1)
		refresh += dt
		if refresh > 30 then
			refresh = 0
			sources = heatSources()
		end
		local t = Lighting.ClockTime
		local night = t < 6 or t > 19.5
		local weather = workspace:GetAttribute("Weather")
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 then
				continue
			end
			local warmth = (player:GetAttribute("Warmth") or 100) :: number
			local pos = root.Position
			local nearFire = false
			for _, s in sources do
				if (s - pos).Magnitude < Gear.HEAT_RANGE then
					nearFire = true
					break
				end
			end
			local abilities = player:GetAttribute("PetAbilities")
			if type(abilities) == "string" and string.find(abilities, "Brace", 1, true) then
				nearFire = true -- il Drago Brace ti scalda
			end
			if nearFire then
				warmth = math.min(100, warmth + Gear.HEAT_REGEN * dt)
			elseif pos.Y > Gear.COLD_ALTITUDE then
				local loss = (pos.Y - Gear.COLD_ALTITUDE) / 1000 * Gear.COLD_PER_1000 + 0.5
				if night then
					loss *= 1.6
				end
				if weather == "Snow" or weather == "Storm" then
					loss *= 1.5
				end
				if Gear.has(player, "Tuta") then
					loss *= Gear.SUIT_FACTOR
				end
				warmth = math.max(0, warmth - loss * dt)
			else
				warmth = math.min(100, warmth + 3 * dt)
			end
			player:SetAttribute("Warmth", warmth)
			if warmth <= 0 then
				Survival.damage(humanoid, Gear.FREEZE_DAMAGE * dt, "Froze to death")
			end
		end
	end
end

function Progression.setup(remotes: { [string]: RemoteEvent })
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("HardcoreClimbing_v1")
	end)
	if ok then
		store = result
	else
		warn("[Progression] DataStore non disponibile, i progressi non verranno salvati: " .. tostring(result))
	end

	-- posizione dei tasti del telefono scelta dal giocatore (client/ControlsEditor): una stringa
	-- JSON corta, salvata col resto
	local saveControls = Instance.new("RemoteEvent")
	saveControls.Name = "SaveControls"
	saveControls.Parent = ReplicatedStorage:WaitForChild("Remotes")
	saveControls.OnServerEvent:Connect(function(player, layout)
		if layout == nil then
			player:SetAttribute("ControlsLayout", nil)
		elseif type(layout) == "string" and #layout < 2000 and pcall(function()
			return game:GetService("HttpService"):JSONDecode(layout)
		end) then
			player:SetAttribute("ControlsLayout", layout)
		end
	end)

	-- ordine delle caselle dello zaino (trascinate dal giocatore): lista JSON di chiavi corte
	local saveBag = Instance.new("RemoteEvent")
	saveBag.Name = "SaveBagOrder"
	saveBag.Parent = ReplicatedStorage:WaitForChild("Remotes")
	saveBag.OnServerEvent:Connect(function(player, order)
		if type(order) == "string" and #order < 4000 and pcall(function()
			return game:GetService("HttpService"):JSONDecode(order)
		end) then
			player:SetAttribute("BagOrder", order)
		end
	end)

	-- barra 1-5 scelta dal giocatore nello zaino: lista JSON, le prime 5 voci sono le caselle
	-- (nome dell'attrezzo o "" = vuota), le altre gli attrezzi gia' visti ma tolti dalla barra
	-- (shared/Hotbar). Solo nomi corti: chi c'e' davvero lo decide il Backpack
	local saveHotbar = Instance.new("RemoteEvent")
	saveHotbar.Name = "SaveHotbar"
	saveHotbar.Parent = ReplicatedStorage:WaitForChild("Remotes")
	saveHotbar.OnServerEvent:Connect(function(player, order)
		if type(order) ~= "string" or #order > 400 or not Guardia.ok(player, "hotbar", 10) then
			return
		end
		local ok, list = pcall(function()
			return game:GetService("HttpService"):JSONDecode(order)
		end)
		if not ok or type(list) ~= "table" or #list > 16 then
			return
		end
		for i = 1, #list do
			local v = list[i]
			if type(v) ~= "string" or #v > 40 then
				return
			end
		end
		player:SetAttribute("HotbarOrder", order)
	end)

	local craftFn = Instance.new("RemoteFunction")
	craftFn.Name = "Craft"
	craftFn.Parent = ReplicatedStorage:WaitForChild("Remotes")
	-- limite: al massimo 4 al secondo per giocatore (server/Guardia)
	craftFn.OnServerInvoke = function(player: Player, id: any): (boolean, string)
		if not Guardia.ok(player, "craft", 4) then
			return false, ""
		end
		return craft(player, id)
	end

	-- Banchi da lavoro: aprono il menu sul client
	local function bindBench(bench: Instance)
		local prompt = bench:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				remotes.OpenCrafting:FireClient(player)
				player:SetAttribute("BenchOpened", true) -- per il tutorial
			end)
		end
	end
	for _, bench in CollectionService:GetTagged("Workbench") do
		bindBench(bench)
	end
	CollectionService:GetInstanceAddedSignal("Workbench"):Connect(bindBench)

	local function onPlayer(player: Player)
		local stats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
		if not stats:FindFirstChild("Ores") then
			local total = Instance.new("IntValue")
			total.Name = "Ores"
			total.Parent = stats
		end
		player:SetAttribute("Warmth", 100)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Warmth", 100)
		end)
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				save(player)
			end
		end
	end)
	task.spawn(coldLoop)
end

Progression.oreValue = oreValue
Progression.giveTools = giveTools
Progression.updateTotal = updateTotal

return Progression
