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

-- Cerchio di addestramento: il terreno sotto viene spianato (pavimento di pietra), sopra due
-- anelli luminosi sottili con una stella a sei punte e pietre con le rune tutto attorno.
-- Restituisce la quota del pavimento.
local RUNE = Color3.fromRGB(120, 200, 255)
local function glowLine(parent: Instance, p1: Vector3, p2: Vector3, width: number, transparency: number)
	local mid = (p1 + p2) / 2
	local seg = part(parent, "Runa", Vector3.new(width, 0.12, (p2 - p1).Magnitude + width * 0.4), CFrame.lookAt(mid, p2), RUNE, Enum.Material.Neon)
	seg.Transparency = transparency
	seg.CanCollide = false
	seg.CanQuery = false
	seg.CastShadow = false
end

local function buildCircle(parent: Instance, center: Vector3): number
	local R = T.CIRCLE_RADIUS
	local terrain = workspace.Terrain
	-- spiazzo piano: pieno sotto la quota del centro, vuoto sopra (le gobbe spariscono)
	terrain:FillCylinder(CFrame.new(center - Vector3.new(0, 4, 0)), 8, R + 5, Enum.Material.Slate)
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, 8, 0)), 16, R + 5, Enum.Material.Air)
	local floorY = groundAt(center).Y
	local y = Vector3.new(center.X, floorY + 0.08, center.Z)
	-- due anelli e la stella
	for _, ring in { { R, 0.5, 0.15 }, { R - 2.5, 0.25, 0.35 } } do
		local n = 48
		for k = 0, n - 1 do
			local a1, a2 = k / n * 2 * math.pi, (k + 1) / n * 2 * math.pi
			glowLine(parent, y + Vector3.new(math.cos(a1) * ring[1], 0, math.sin(a1) * ring[1]), y + Vector3.new(math.cos(a2) * ring[1], 0, math.sin(a2) * ring[1]), ring[2], ring[3])
		end
	end
	local points = {}
	for k = 0, 5 do
		local a = k / 6 * 2 * math.pi
		points[k + 1] = y + Vector3.new(math.cos(a) * (R - 2.5), 0, math.sin(a) * (R - 2.5))
	end
	for k = 1, 6 do
		glowLine(parent, points[k], points[(k + 1) % 6 + 1], 0.3, 0.3) -- due triangoli intrecciati
	end
	-- pietre basse tutto attorno, con una runa accesa
	for k = 0, 11 do
		local a = k / 12 * 2 * math.pi
		local p = groundAt(center + Vector3.new(math.cos(a) * (R + 1.8), 0, math.sin(a) * (R + 1.8)))
		local look = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z))
		local stone = part(parent, "PietraRuna", Vector3.new(1.8, 3, 1.2), look * CFrame.new(0, 1.1, 0), STONE, Enum.Material.Slate)
		local rune = part(parent, "Runa", Vector3.new(0.6, 0.9, 0.1), stone.CFrame * CFrame.new(0, 0.4, -0.62), RUNE, Enum.Material.Neon)
		rune.CanCollide = false
	end
	-- scintille che salgono da tutto il cerchio
	local emitterPart = part(parent, "ScintilleCerchio", Vector3.new(R * 2, 0.2, R * 2), CFrame.new(y), RUNE, Enum.Material.SmoothPlastic)
	emitterPart.Transparency = 1
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(160, 220, 255))
	sparks.Size = NumberSequence.new(0.3, 0)
	sparks.Lifetime = NumberRange.new(2, 3.5)
	sparks.Speed = NumberRange.new(1.5, 3)
	sparks.SpreadAngle = Vector2.new(5, 5)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Shape = Enum.ParticleEmitterShape.Disc
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.Rate = 18
	sparks.LightEmission = 1
	sparks.Parent = emitterPart
	local light = Instance.new("PointLight")
	light.Color = RUNE
	light.Range = R * 1.4
	light.Brightness = 0.8
	light.Parent = emitterPart
	return floorY
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
		center = Vector3.new(center.X, buildCircle(folder, center), center.Z)
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
