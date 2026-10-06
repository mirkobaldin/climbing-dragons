--!strict
-- Zona di addestramento dei draghi, dentro la cassa toracica del drago gigante (DragonRibs):
--   * BERSAGLI    ti avvicini e premi E: il tuo drago spara un colpo del suo elemento
--                 (TARGET_XP, uno ogni TARGET_COOLDOWN secondi)
--   * CERCHIO     finche' ci stai dentro col drago al seguito: CIRCLE_XP al secondo
-- Il drago sale di livello fino a MAX_LEVEL; solo a quel livello si puo' evolvere (diventa
-- piu' grande e riparte da 1). Gli effetti li fa ogni client (client/TrainingFX) con l'evento
-- "TrainingFX": ("hit", userId, punto, elemento, xp) · ("level", userId, dragonId, livello)
-- · ("evolve", userId, dragonId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Dragons = require(script.Parent.Dragons)

local Training = {}

local T = DragonConfig.TRAINING
local STONE = Color3.fromRGB(116, 110, 102)
local WOOD = Color3.fromRGB(96, 66, 42)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function groundAt(p: Vector3): Vector3
	local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 300, p.Z), Vector3.new(0, -600, 0), terrainOnly)
	return if hit then hit.Position else p
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Bersaglio: palo di pietra con un disco a cerchi rossi e bianchi rivolto verso il centro
local function buildTarget(parent: Instance, at: Vector3, center: Vector3, index: number): Part
	local model = Instance.new("Model")
	model.Name = "Bersaglio" .. index
	local look = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z))
	part(model, "Palo", Vector3.new(1.6, 7, 1.6), look * CFrame.new(0, 3.2, 0), STONE, Enum.Material.Slate)
	part(model, "Base", Vector3.new(3.4, 1, 3.4), look * CFrame.new(0, 0.2, 0), STONE, Enum.Material.Slate)
	local disc = part(model, "Disco", Vector3.new(0.6, 5.2, 5.2), look * CFrame.new(0, 7.6, -0.4) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(235, 228, 214), Enum.Material.WoodPlanks, Enum.PartType.Cylinder)
	for k, ring in { { 3.7, Color3.fromRGB(200, 50, 40) }, { 2.3, Color3.fromRGB(235, 228, 214) }, { 1.1, Color3.fromRGB(200, 50, 40) } } do
		local r = part(model, "Cerchio", Vector3.new(0.62 + k * 0.02, ring[1], ring[1]), disc.CFrame, ring[2], Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		r.CanCollide = false
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Train"
	prompt.ObjectText = "Dragon target"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 45
	prompt.RequiresLineOfSight = false
	prompt.Parent = disc
	model.PrimaryPart = disc
	model.Parent = parent
	return disc
end

-- Cerchio di addestramento: anello di pietra con rune luminose
local function buildCircle(parent: Instance, center: Vector3)
	local R = T.CIRCLE_RADIUS
	local floor = part(parent, "CerchioAddestramento", Vector3.new(0.4, R * 2, R * 2), CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 66, 74), Enum.Material.Slate, Enum.PartType.Cylinder)
	floor.CanCollide = false
	local glow = part(parent, "Runa", Vector3.new(0.45, R * 2 - 1.5, R * 2 - 1.5), floor.CFrame, Color3.fromRGB(120, 200, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	glow.Transparency = 0.75
	glow.CanCollide = false
	part(parent, "RunaCentro", Vector3.new(0.5, R * 2 - 4, R * 2 - 4), floor.CFrame, Color3.fromRGB(70, 66, 74), Enum.Material.Slate, Enum.PartType.Cylinder).CanCollide = false
	-- pietre basse tutto attorno
	for k = 0, 11 do
		local a = k / 12 * 2 * math.pi
		local p = groundAt(center + Vector3.new(math.cos(a) * (R + 1.5), 0, math.sin(a) * (R + 1.5)))
		local look = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z))
		local s = part(parent, "PietraRuna", Vector3.new(1.8, 2.6, 1.2), look * CFrame.new(0, 1, 0), STONE, Enum.Material.Slate)
		local rune = part(parent, "Runa", Vector3.new(0.6, 0.9, 0.1), s.CFrame * CFrame.new(0, 0.3, -0.62), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
		rune.CanCollide = false
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(140, 210, 255))
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Lifetime = NumberRange.new(2, 3)
	sparks.Speed = NumberRange.new(2, 4)
	sparks.SpreadAngle = Vector2.new(10, 10)
	sparks.EmissionDirection = Enum.NormalId.Right -- il cilindro e' girato: +X guarda in su
	sparks.Rate = 12
	sparks.LightEmission = 1
	sparks.Parent = glow
end

-- Cartello all'ingresso
local function buildSign(parent: Instance, at: Vector3, center: Vector3)
	local look = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z))
	part(parent, "PaloCartello", Vector3.new(0.6, 6, 0.6), look * CFrame.new(-2.4, 3, 0), WOOD, Enum.Material.Wood)
	part(parent, "PaloCartello", Vector3.new(0.6, 6, 0.6), look * CFrame.new(2.4, 3, 0), WOOD, Enum.Material.Wood)
	local board = part(parent, "Cartello", Vector3.new(6.4, 2.6, 0.3), look * CFrame.new(0, 5, 0), WOOD, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 226, 160)
	label.Text = "DRAGON TRAINING GROUNDS\n<font size=\"20\">Hit the targets · stand in the circle · reach Lv 100 to evolve</font>"
	label.RichText = true
	label.Parent = gui
end

function Training.setup()
	local fx = Instance.new("RemoteEvent")
	fx.Name = "TrainingFX"
	fx.Parent = ReplicatedStorage:WaitForChild("Remotes")

	Dragons.onLevelUp = function(player: Player, d: any, level: number)
		fx:FireAllClients("level", player.UserId, d.id, level)
	end
	Dragons.onEvolve = function(player: Player, d: any)
		fx:FireAllClients("evolve", player.UserId, d.id)
	end

	task.spawn(function()
		local landmarks = workspace:WaitForChild("Landmarks", 30)
		local ribs = landmarks and landmarks:WaitForChild("DragonRibs", 10)
		if not ribs or not ribs:IsA("Model") then
			warn("[Addestramento] Costole del drago non trovate: zona non creata")
			return
		end
		local cf, size = ribs:GetBoundingBox()
		local center = groundAt(cf.Position)
		local folder = Instance.new("Folder")
		folder.Name = "ZonaAddestramento"
		buildCircle(folder, center)
		-- bersagli in cerchio dentro la cassa toracica
		local ring = math.clamp(math.min(size.X, size.Z) * 0.3, T.CIRCLE_RADIUS + 10, 60)
		local targets: { Part } = {}
		for k = 1, T.TARGETS do
			local a = (k - 0.5) / T.TARGETS * 2 * math.pi
			local at = groundAt(center + Vector3.new(math.cos(a) * ring, 0, math.sin(a) * ring))
			table.insert(targets, buildTarget(folder, at, center, k))
		end
		buildSign(folder, groundAt(center + Vector3.new(ring + 14, 0, 0)), center)
		folder.Parent = workspace
		workspace:SetAttribute("TrainingCenter", center)

		-- bersagli: un colpo del drago, XP a tutti i draghi al seguito
		local lastHit: { [Player]: number } = {}
		for _, disc in targets do
			local prompt = disc:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
			prompt.Triggered:Connect(function(player)
				local now = os.clock()
				if now - (lastHit[player] or 0) < T.TARGET_COOLDOWN then
					return
				end
				local list = Dragons.equippedDragons(player)
				if #list == 0 then
					fx:FireClient(player, "hint", 0, "You need a dragon following you to train")
					return
				end
				lastHit[player] = now
				for _, d in list do
					fx:FireAllClients("hit", player.UserId, disc.Position, d.element, T.TARGET_XP)
					Dragons.addXp(player, d.id, T.TARGET_XP)
				end
			end)
		end
		Players.PlayerRemoving:Connect(function(player)
			lastHit[player] = nil
		end)

		-- cerchio: XP al secondo a chi ci sta dentro col drago
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local inside = false
				if root then
					local d = root.Position - center
					inside = Vector3.new(d.X, 0, d.Z).Magnitude <= T.CIRCLE_RADIUS and math.abs(d.Y) < 12
				end
				local list = if inside then Dragons.equippedDragons(player) else {}
				player:SetAttribute("Training", #list > 0)
				for _, d in list do
					Dragons.addXp(player, d.id, T.CIRCLE_XP)
				end
			end
		end
	end)
end

return Training
