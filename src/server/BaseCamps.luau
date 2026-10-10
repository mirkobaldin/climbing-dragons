--!strict
-- Campi base sulla montagna: ci si accampa (prompt "E"), si riforniscono i chiodi, si
-- recupera la salute e il campo diventa il punto di rinascita (checkpoint).
-- Cartelli di viaggio (tag "TravelPost"): dal campo ai piedi della montagna e ritorno, e
-- dal campo all'ultimo campo base raggiunto (la strada a piedi e' lunga).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Ropes = require(script.Parent.Ropes)
local Economy = require(script.Parent.Economy)

local BaseCamps = {}

-- Punto di rinascita: l'ultimo campo base usato, altrimenti lo spawn della valle
local function spawnPoint(player: Player): Vector3?
	-- "Soccorso alpino" (Robux): una volta sola, dove sei caduto
	local revive = player:GetAttribute("ReviveAt")
	if typeof(revive) == "Vector3" then
		player:SetAttribute("ReviveAt", nil)
		return revive
	end
	local checkpoint = player:GetAttribute("Checkpoint")
	if typeof(checkpoint) == "Vector3" then
		return checkpoint
	end
	local markers = workspace:FindFirstChild("MapMarkers")
	local spawn = markers and markers:FindFirstChild("HubSpawn") :: BasePart?
	return spawn and spawn.Position
end

-- Appoggia il personaggio sul terreno vero sotto il punto (raycast dall'alto), cosi' non
-- puo' mai finire dentro o sotto la mappa
local function teleport(player: Player, character: Model, target: Vector3)
	pcall(function()
		player:RequestStreamAroundAsync(target)
	end)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	-- prima vicino al punto (sui pendii sopra potrebbe esserci un'altra parete), poi dall'alto
	local hit = workspace:Raycast(target + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), params)
		or workspace:Raycast(target + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
	local ground = if hit then hit.Position else target
	character:PivotTo(CFrame.new(ground + Vector3.new(0, 4, 0)))
end

local function onCharacter(player: Player, character: Model)
	local target = spawnPoint(player)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if target and root then
		teleport(player, character, target)
	end
end

local function travelPrompt(parent: Instance, action: string, object: string, onTrigger: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	prompt.Triggered:Connect(onTrigger)
end

local function travelTo(player: Player, target: Vector3?)
	local character = player.Character
	if character and target then
		teleport(player, character, target)
	end
end

local function bindTravelPost(post: Instance)
	if not post:IsA("BasePart") then
		return
	end
	local dest = post:GetAttribute("Target")
	local label = post:GetAttribute("Label") or "Viaggia"
	if typeof(dest) == "Vector3" then
		travelPrompt(post, label, "Cartello", function(player)
			travelTo(player, dest)
		end)
	end
	if post:GetAttribute("LastCamp") then
		travelPrompt(post, "To the last base camp", "Sign", function(player)
			local cp = player:GetAttribute("Checkpoint")
			if typeof(cp) == "Vector3" then
				travelTo(player, cp)
			else
				player:SetAttribute("Notice", "You haven't reached a base camp yet")
				player:SetAttribute("NoticeTime", os.clock())
			end
		end)
	end
end

------------------------------------------------------------------------------------------
-- Utilita' dei campi base

local CAMP_REWARD = 120 -- monete per ogni campo scoperto, per il numero del campo
local WAYPOINT_RADIUS = 45

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function groundAt(p: Vector3): Vector3
	local hit = workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), terrainOnly)
	return if hit then hit.Position else p
end

-- copia di un modello (Modelli di Mirko o BorghiKit) appoggiata a terra in "at"
local function placeModel(name: string, folderName: string, at: Vector3, look: Vector3, height: number?, scale: number?): Model?
	local store = game:GetService("ServerStorage"):FindFirstChild(folderName)
	local t = store and store:FindFirstChild(name, true)
	if not t or not t:IsA("Model") then
		return nil
	end
	local m = t:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local _, s0 = m:GetBoundingBox()
	if height then
		m:ScaleTo(m:GetScale() * height / math.max(s0.Y, 0.05))
	elseif scale then
		m:ScaleTo(m:GetScale() * scale)
	end
	local ground = groundAt(at)
	m:PivotTo(CFrame.lookAt(ground, ground + Vector3.new(look.X, 0, look.Z)).Rotation + m:GetPivot().Position)
	local box, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (ground - (box.Position - Vector3.new(0, s.Y / 2, 0))))
	return m
end

local function invisiblePart(name: string, at: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.Transparency = true, false, 1
	p.Size = Vector3.new(6, 3, 3)
	p.Position = at + Vector3.new(0, 3, 0)
	p.Parent = parent
	return p
end

local function furnish(marker: BasePart)
	local folder = Instance.new("Folder")
	folder.Name = "Servizi"
	local center = marker.Position
	local out = Vector3.new(marker.CFrame.RightVector.X, 0, marker.CFrame.RightVector.Z)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis
	-- banco da lavoro a sinistra
	local benchAt = groundAt(center - out * 12)
	local bench = placeModel("Banco_Crafting", "Modelli", benchAt, -out, 7, nil)
	if bench then
		bench.Parent = folder
	end
	local top = invisiblePart("Bench", benchAt + Vector3.new(0, 1, 0), folder)
	CollectionService:AddTag(top, "Workbench")
	-- commerciante a destra (bancarella dei borghi)
	local stallAt = groundAt(center + out * 12)
	local stall = placeModel("Bancarella", "BorghiKit", stallAt, out, nil, 2)
	if stall then
		stall.Parent = folder
	end
	local counter = invisiblePart("Counter", stallAt, folder)
	CollectionService:AddTag(counter, "ShopCounter")
	folder.Parent = marker
end

-- punto di viaggio (si puo' usare il teletrasporto) e scoperta dei campi base
local function checkPlayer(player: Player, camps: Instance?)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		player:SetAttribute("AtWaypoint", false)
		return
	end
	local pos = root.Position
	local function near(p: Vector3?, r: number): boolean
		return p ~= nil and (p - pos).Magnitude < r
	end
	local markers = workspace:FindFirstChild("MapMarkers")
	local hub = markers and markers:FindFirstChild("HubSpawn") :: BasePart?
	local plot = player:GetAttribute("PlotSpawn") or player:GetAttribute("PlotPosition")
	local gym = workspace:GetAttribute("GymCenter")
	local pad = workspace:GetAttribute("TrainingPad")
	local at = near(hub and hub.Position, 90)
		or (typeof(plot) == "Vector3" and near(plot, 60))
		or (typeof(gym) == "Vector3" and near(gym, 90))
		or (typeof(pad) == "Vector3" and near(pad, 50))
	for _, c in (if camps then camps:GetChildren() else {}) :: { Instance } do
		if c:IsA("BasePart") and near(c.Position, WAYPOINT_RADIUS) then
			at = true
			local index = tonumber(string.match(c.Name, "%d+")) or 0
			local found = tostring(player:GetAttribute("CampsFound") or "")
			if not string.find("," .. found .. ",", "," .. index .. ",", 1, true) then
				player:SetAttribute("CampsFound", if found == "" then tostring(index) else found .. "," .. index)
				local coins = CAMP_REWARD * index
				Economy.addCoins(player, coins)
				player:SetAttribute("Notice", string.format("Base Camp %d discovered! +%d coins, fast travel unlocked (T)", index, coins))
				player:SetAttribute("NoticeTime", os.clock())
			end
		end
	end
	player:SetAttribute("AtWaypoint", at == true)
end

function BaseCamps.setup()
	local markers = workspace:WaitForChild("MapMarkers", 10)
	local camps = markers and markers:FindFirstChild("BaseCamps")
	if camps then
		for index, marker in camps:GetChildren() do
			if marker:IsA("BasePart") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Camp here"
				prompt.ObjectText = "Base Camp " .. index
				prompt.HoldDuration = 1
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = marker
				prompt.Triggered:Connect(function(player: Player)
					Ropes.refill(player)
					player:SetAttribute("Checkpoint", marker.Position)
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = humanoid.MaxHealth
					end
					player:SetAttribute("Warmth", 100)
				end)
				-- discesa rapida: dal campo base si torna alla valle
				travelPrompt(marker, "Back to camp", "Base Camp " .. index, function(player)
					local markersFolder = workspace:FindFirstChild("MapMarkers")
					local spawn = markersFolder and markersFolder:FindFirstChild("HubSpawn") :: BasePart?
					travelTo(player, spawn and spawn.Position)
				end)
				CollectionService:AddTag(marker, "HeatSource")
			end
		end
	else
		warn("[BaseCamps] MapMarkers.BaseCamps non trovato: genera la mappa con MapGen")
	end

	-- ogni campo base ha un banco da lavoro e un commerciante (vendi minerali, compri chiodi,
	-- bende...): sulla montagna non serve scendere a valle per tutto
	for _, marker in (if camps then camps:GetChildren() else {}) :: { Instance } do
		if marker:IsA("BasePart") then
			pcall(furnish, marker)
		end
	end

	-- punti di viaggio e scoperta dei campi (una volta al secondo)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(checkPlayer, player, camps)
				if not ok then
					warn("[BaseCamps] " .. tostring(err))
				end
			end
		end
	end)


	for _, post in CollectionService:GetTagged("TravelPost") do
		bindTravelPost(post)
	end
	CollectionService:GetInstanceAddedSignal("TravelPost"):Connect(bindTravelPost)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return BaseCamps
