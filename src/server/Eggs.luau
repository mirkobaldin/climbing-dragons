--!strict
-- Uova di drago nel mondo:
--   * spawn: fino a MAX_WORLD_EGGS uova sparse tra tunnel, caverne, fiumi, boschi e pareti.
--     L'elemento dipende dal posto (grotte -> Roccia/Brace, ghiaccio -> Gelo, acqua -> Fiume,
--     boschi -> Ciliegio, quota alta -> Cosmico) e la rarita' migliora salendo
--   * trasporto: "Pick up" mette l'uovo sulla schiena; se muori cade dove sei
--   * nido (tag "Incubator") nella tua casa (si sblocca comprando la Tenda): "Metti a covare";
--     il resto dal menu Draghi (tasto G)
-- La cartella workspace.EggIndex ha un Vector3Value per uovo: la usa la bussola (Egg Finder)
-- anche per le uova lontane che il client non ha ancora caricato.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Names = require(ReplicatedStorage.Shared.Names)
local DragonModels = require(script.Parent.DragonModels)
local Dragons = require(script.Parent.Dragons)

local Eggs = {}

type Spot = { position: Vector3, element: string }

local rng = Random.new()
local spots: { Spot } = {}
local eggFolder: Folder
local indexFolder: Folder
local nextEggId = 1
local carried: { [Player]: Model } = {}

local function notice(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

local function rollRarity(altitude: number): string
	local total = 0
	local weights = {}
	for k, r in DragonConfig.RARITIES do
		-- in quota le rarita' alte diventano piu' probabili
		local w = r.weight * (if k >= 3 then 1 + altitude / 800 else 1)
		weights[k] = w
		total += w
	end
	local roll = rng:NextNumber(0, total)
	for k, r in DragonConfig.RARITIES do
		roll -= weights[k]
		if roll <= 0 then
			return r.id
		end
	end
	return DragonConfig.RARITIES[1].id
end

-- Punti possibili, dai marcatori della mappa (li crea MapGen)
local function collectSpots()
	table.clear(spots)
	local markers = workspace:FindFirstChild("MapMarkers")
	if not markers then
		warn("[Uova] MapMarkers non trovato: genera la mappa con MapGen")
		return
	end
	local count = 0
	local function add(folderName: string, element: string | (Vector3) -> string)
		local f = markers:FindFirstChild(folderName)
		if not f then
			return
		end
		for _, m in f:GetChildren() do
			count += 1
			if count % 400 == 0 then
				task.wait()
			end
			if m:IsA("BasePart") then
				local el = if type(element) == "function" then element(m.Position) else element
				table.insert(spots, { position = m.Position, element = el :: string })
			end
		end
	end
	local function byAltitude(p: Vector3): string
		local roll = rng:NextNumber()
		if p.Y > 3200 then
			-- vicino alla vetta: il sole, le stelle, l'eclissi e il gelo
			return if roll < 0.3 then "Sole" elseif roll < 0.55 then "Cosmico" elseif roll < 0.8 then "Eclissi" else "Gelo"
		elseif p.Y > 2300 then
			-- creste esposte al vento e ai fulmini
			return if roll < 0.3 then "Tempesta" elseif roll < 0.55 then "Fulmine" elseif roll < 0.8 then "Cosmico" else "Gelo"
		elseif p.Y > 1600 then
			return "Gelo"
		elseif p.Y > 500 then
			return "Roccia"
		end
		return if rng:NextNumber() < 0.3 then "Ombra" else "Roccia"
	end
	add("MineChambers", function(p)
		return if p.Y > 600 then "Brace" else "Roccia"
	end)
	add("OreRooms", "Brace")
	-- grotte: roccia, e nel buio piu' profondo l'ombra e le ossa
	local function cave(_: Vector3): string
		local roll = rng:NextNumber()
		return if roll < 0.35 then "Ombra" elseif roll < 0.6 then "Ossa" else "Roccia"
	end
	add("CaveEntrances", cave)
	add("SecretExits", "Ombra")
	add("IceCaves", "Gelo")
	add("GasZone", "Gas") -- valle dei gas tossici
	-- nidi delle zone a tema: le uova di quel drago (piu' volte: sono i posti migliori)
	local nests = markers:FindFirstChild("ThemeNests")
	for _, m in (if nests then nests:GetChildren() else {}) :: { Instance } do
		local el = m:GetAttribute("Element")
		if m:IsA("BasePart") and type(el) == "string" then
			for _ = 1, 4 do
				table.insert(spots, { position = m.Position, element = el })
			end
		end
	end
	add("Ponds", "Gelo")
	add("Rivers", "Gelo")
	add("PathPoints", byAltitude)
	add("BaseCamps", byAltitude)
	-- punti nei boschi bassi, trovati con dei raggi sul terreno
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	-- niente uova dentro le case dei borghi: dall'alto il raggio deve arrivare al terreno
	local roofs = RaycastParams.new()
	roofs.FilterType = Enum.RaycastFilterType.Include
	roofs.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("Borghi") or workspace.Terrain }
	for _ = 1, 80 do
		local origin = Vector3.new(rng:NextNumber(-2600, 2600), 900, rng:NextNumber(-1700, 1700))
		local hit = workspace:Raycast(origin, Vector3.new(0, -1000, 0), params)
		local top = hit and workspace:Raycast(origin, Vector3.new(0, -1000, 0), roofs)
		if hit and top and top.Instance == workspace.Terrain and hit.Position.Y > 30 and hit.Position.Y < 450 and (hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.LeafyGrass) then
			table.insert(spots, { position = hit.Position, element = if rng:NextNumber() < 0.3 then "Ombra" else "Roccia" })
		end
	end
	print(string.format("[Uova] %d punti possibili per le uova", #spots))
end

-- Appoggia al suolo vicino al punto (anche dentro le grotte)
local function groundNear(p: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local offset = Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
	local hit = workspace:Raycast(p + offset + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
		or workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position
end

local function occupied(pos: Vector3): boolean
	for _, egg in eggFolder:GetChildren() do
		if egg:IsA("Model") and (egg:GetPivot().Position - pos).Magnitude < 40 then
			return true
		end
	end
	return false
end

-- Uovo nel mondo con il prompt per raccoglierlo
local function placeEgg(pos: Vector3, element: string, rarity: string, extra: { [string]: any }?): Model
	element = DragonConfig.RETIRED[element] or element -- niente uova di Sole, Ombra, Brace
	local model = DragonModels.egg(element, rarity)
	local _, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(pos + Vector3.new(0, size.Y / 2 - 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)))
	-- appoggiato davvero: le uova 3D nuove non hanno il pivot al centro e finivano mezze sotto
	-- terra (Mirko 17/10, uovo del tutorial). Il fondo del riquadro va 0,2 studs sotto il suolo
	local bcf, bsize = model:GetBoundingBox()
	local bottom = bcf.Position.Y - bsize.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, (pos.Y - 0.2) - bottom, 0))
	local id = "Egg" .. nextEggId
	nextEggId += 1
	model.Name = id
	for k, v in extra or {} do
		model:SetAttribute(k, v)
	end
	local root = model.PrimaryPart
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pick up"
		local e = DragonConfig.element(element)
		prompt.ObjectText = string.format("%s Egg (%s)", Names.t(if e then e.id else element), Names.t(rarity))
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(player)
			Eggs.pickUp(player, model)
		end)
	end
	model.Parent = eggFolder
	local v = Instance.new("Vector3Value")
	v.Name = id
	v.Value = pos
	v:SetAttribute("Element", element)
	v:SetAttribute("Rarity", rarity)
	v.Parent = indexFolder
	return model
end

local function removeEgg(model: Model)
	local v = indexFolder:FindFirstChild(model.Name)
	if v then
		v:Destroy()
	end
	model:Destroy()
end

function Eggs.spawnRandom(): Model?
	if #spots == 0 then
		return nil
	end
	for _ = 1, 10 do
		local spot = spots[rng:NextInteger(1, #spots)]
		local pos = groundNear(spot.position)
		if pos and not occupied(pos) then
			return placeEgg(pos, spot.element, rollRarity(pos.Y))
		end
	end
	return nil
end

-- Uovo davanti a un giocatore (comandi admin)
function Eggs.spawnAt(pos: Vector3, element: string, rarity: string): Model
	return placeEgg(pos, element, rarity)
end

local function carrying(player: Player): boolean
	return carried[player] ~= nil
end

local function stopCarrying(player: Player)
	local m = carried[player]
	if m then
		m:Destroy()
	end
	carried[player] = nil
	player:SetAttribute("CarryingEgg", nil)
	player:SetAttribute("CarryingQuick", nil)
end

-- Sulla schiena del personaggio
function Eggs.pickUp(player: Player, egg: Model)
	if not egg.Parent then
		return
	end
	local character = player.Character
	local back = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not back then
		return
	end
	if carrying(player) then
		notice(player, "You already have an egg: take it to your nest")
		return
	end
	local owner = egg:GetAttribute("OnlyFor")
	if owner and owner ~= player.UserId then
		notice(player, "This egg belongs to another player")
		return
	end
	local element = egg:GetAttribute("Element") :: string
	local rarity = egg:GetAttribute("Rarity") :: string
	local quick = egg:GetAttribute("Quick") == true
	local respawnTutorial = egg:GetAttribute("TutorialSpot")
	removeEgg(egg)

	local visual = DragonModels.egg(element, rarity)
	visual.Name = "CarriedEgg"
	for _, d in visual:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
		end
	end
	local root = visual.PrimaryPart :: BasePart
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
	visual:PivotTo(back.CFrame * CFrame.new(0, 0.2, 1.3))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = back
	weld.Part1 = root
	weld.Parent = root
	visual.Parent = character
	carried[player] = visual
	player:SetAttribute("CarryingEgg", element .. "|" .. rarity)
	player:SetAttribute("CarryingQuick", quick)
	notice(player, "Egg picked up! Take it to your home nest or sell it at the store (fall and you lose it)")

	if typeof(respawnTutorial) == "Vector3" then
		-- l'uovo del tutorial ricompare per il prossimo giocatore
		task.delay(20, function()
			placeEgg(respawnTutorial, element, rarity, { Quick = true, TutorialSpot = respawnTutorial })
		end)
	end
end

-- Toglie l'uovo dalla schiena e dice cos'era (per venderlo all'emporio)
function Eggs.takeCarried(player: Player): (string?, string?)
	local value = player:GetAttribute("CarryingEgg")
	if type(value) ~= "string" then
		return nil, nil
	end
	stopCarrying(player)
	local element, rarity = string.match(value, "^(.-)|(.*)$")
	return element, rarity
end

-- Se muori con l'uovo, cade li' (e resta nel mondo)
local function dropEgg(player: Player)
	local value = player:GetAttribute("CarryingEgg")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local quick = player:GetAttribute("CarryingQuick") == true
	stopCarrying(player)
	if type(value) == "string" and root then
		local element, rarity = string.match(value, "^(.-)|(.*)$")
		local pos = groundNear(root.Position) or root.Position
		placeEgg(pos, element or "Roccia", rarity or "Comune", if quick then { Quick = true } else nil)
		notice(player, "You lost the egg! It's where you fell")
	end
end

-- Nido: mette a covare l'uovo trasportato, altrimenti apre il menu Draghi
local function useNest(player: Player, remotes: { [string]: RemoteEvent }, nest: Instance)
	local owner = nest:GetAttribute("Owner")
	if owner and owner ~= player.UserId then
		notice(player, "This is another player's nest: yours is at your house")
		return
	end
	local value = player:GetAttribute("CarryingEgg")
	if type(value) ~= "string" then
		remotes.OpenDragons:FireClient(player, "nest")
		return
	end
	local element, rarity = string.match(value, "^(.-)|(.*)$")
	local quick = player:GetAttribute("CarryingQuick") == true
	-- l'uovo del tutorial si schiude in 20 secondi
	if Dragons.incubate(player, element or "Roccia", rarity or "Comune", if quick then 20 else nil) then
		stopCarrying(player)
		player:SetAttribute("EggsIncubated", (player:GetAttribute("EggsIncubated") or 0) + 1)
		notice(player, "Egg in the nest! Press G to see when it hatches")
		remotes.OpenDragons:FireClient(player, "nest")
	else
		notice(player, "The nest is full: hatch an egg first")
	end
end

-- Effetto di schiusa sopra il nido: l'uovo trema e si rompe in pezzi
local function hatchEffect(player: Player, egg: Dragons.NestEgg)
	local nests = CollectionService:GetTagged("Incubator")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local nest = nests[1] :: BasePart?
	if root then
		for _, n in nests do
			if n:IsA("BasePart") and (n.Position - root.Position).Magnitude < 60 then
				nest = n
			end
		end
	end
	local pos = if nest then nest.Position + Vector3.new(0, 3, 0) elseif root then root.Position + root.CFrame.LookVector * 4 else nil
	if not pos then
		return
	end
	local model = DragonModels.egg(egg.element, egg.rarity)
	model:PivotTo(CFrame.new(pos :: Vector3))
	model.Parent = workspace
	task.spawn(function()
		for k = 1, 10 do
			model:PivotTo(CFrame.new(pos :: Vector3) * CFrame.Angles(0, 0, math.sin(k * 1.7) * 0.25))
			task.wait(0.06)
		end
		local burst = Instance.new("Part")
		burst.Anchored = true
		burst.CanCollide = false
		burst.Transparency = 1
		burst.Position = pos :: Vector3
		burst.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		local el = DragonConfig.element(egg.element)
		e.Color = ColorSequence.new(if el then el.glow else Color3.new(1, 1, 1))
		e.Speed = NumberRange.new(10, 20)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.5, 1)
		e.Rate = 0
		e.Parent = burst
		e:Emit(40)
		-- i pezzi del guscio volano via
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = true
				d.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(12, 24), rng:NextNumber(-12, 12))
			end
		end
		task.wait(2.5)
		model:Destroy()
		burst:Destroy()
	end)
	player:SetAttribute("EggsHatched", (player:GetAttribute("EggsHatched") or 0) + 1)
end

-- Uovo del tutorial vicino alla parete di allenamento (sempre disponibile, si schiude subito)
local function tutorialEgg()
	local t = workspace:FindFirstChild("Tutorial")
	local spot = t and t:FindFirstChild("EggSpot") :: BasePart?
	if spot then
		-- sul suolo vero sotto (o sopra) il segnaposto: il terreno attorno alla parete e' in
		-- pendenza e il segnaposto poteva restare sotto terra
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(spot.Position + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
		local at = if hit then hit.Position else spot.Position
		placeEgg(at, "Roccia", "Comune", { Quick = true, TutorialSpot = at })
	end
end

function Eggs.setup(remotes: { [string]: RemoteEvent })
	local old = workspace:FindFirstChild("Eggs")
	if old then
		old:Destroy()
	end
	eggFolder = Instance.new("Folder")
	eggFolder.Name = "Eggs"
	eggFolder.Parent = workspace
	indexFolder = Instance.new("Folder")
	indexFolder.Name = "EggIndex"
	indexFolder.Parent = workspace

	Dragons.onHatch = hatchEffect

	local function bindNest(nest: Instance)
		local prompt = nest:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				useNest(player, remotes, nest)
			end)
		end
	end
	for _, n in CollectionService:GetTagged("Incubator") do
		bindNest(n)
	end
	CollectionService:GetInstanceAddedSignal("Incubator"):Connect(bindNest)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				dropEgg(player)
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		stopCarrying(player)
	end)

	-- Altari: nella camera del tesoro (centro della montagna) un uovo Ombra Leggendario, sulla
	-- vetta quello di DragonConfig.SUMMIT_EGG. Quando qualcuno lo prende ne ricompare un altro
	-- dopo ALTAR_RESPAWN secondi
	local function altarEggs(altarName: string, element: string)
		local landmarks = workspace:WaitForChild("Landmarks", 30)
		local altar = landmarks and landmarks:FindFirstChild(altarName, true)
		if not altar or not altar:IsA("BasePart") then
			return
		end
		while true do
			local present = false
			for _, e in eggFolder:GetChildren() do
				if e:GetAttribute("Altare") == altarName then
					present = true
				end
			end
			if not present then
				placeEgg(altar.Position + Vector3.new(0, altar.Size.Y / 2 + DragonConfig.EGG_SIZE * 0.7, 0), element, "Leggendario", { Altare = altarName })
			end
			task.wait(DragonConfig.ALTAR_RESPAWN or 600)
		end
	end
	task.spawn(altarEggs, "AltareUovo", "Ombra")
	task.spawn(altarEggs, "AltareVetta", DragonConfig.SUMMIT_EGG or "Sole")

	task.defer(function() -- dopo l'avvio (tanti marcatori: niente timeout)
		collectSpots()
		tutorialEgg()
		for _ = 1, DragonConfig.MAX_WORLD_EGGS do
			Eggs.spawnRandom()
		end
		while true do
			task.wait(DragonConfig.EGG_RESPAWN_SECONDS)
			if #eggFolder:GetChildren() < DragonConfig.MAX_WORLD_EGGS + 1 then
				Eggs.spawnRandom()
			end
		end
	end)
end

return Eggs
