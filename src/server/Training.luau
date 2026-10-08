--!strict
-- Zona di addestramento dei draghi, dentro la cassa toracica del drago gigante (DragonRibs):
--   * CERCHIO     cerchio di rune con al centro il Cristallo del Potere, che manda un raggio di
--                 luce verso il cielo; finche' ci stai dentro col drago: CIRCLE_XP al secondo
--   * BRACIERI    uno per elemento attorno al cerchio: divampano quando si allena un drago di
--                 quell'elemento (effetto sul client)
--   * CRISTALLI   bersagli che volano attorno al cerchio (DragonConfig.crystalAt). Dentro il
--                 cerchio la vista passa al tuo drago: miri col mouse e clicchi, il drago spara
--                 (TARGET_XP). Il client manda ("shoot", origine, direzione), il server controlla
--   * TARGET RUSH sfida di RUSH_SECONDS: si accende un cristallo dorato alla volta, colpiscilo
--                 prima che cambi (RUSH_XP). Classifica del server sul tabellone
--   * BANCARELLA  pass "Training XP x2" e boost "x3 per 15 minuti" a Robux
-- L'XP e' moltiplicata dal pass TrainingX2, dal boost (attributo TrainingBoostUntil) e da
-- Roblox Premium (l'attributo TrainingMult la mostra al client).
-- Gli effetti li fa ogni client (client/TrainingFX) con l'evento "TrainingFX":
--   ("hit", userId, punto, elemento, xp) · ("level", userId, dragonId, livello)
--   · ("evolve", userId, dragonId) · ("hint", 0, testo) · ("rush", 0, cristallo, secondi, punti)
--   · ("rushEnd", 0, punti, record)

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local Dragons = require(script.Parent.Dragons)

local Training = {}

local T = DragonConfig.TRAINING
local STONE = Color3.fromRGB(116, 110, 102)
local DARK = Color3.fromRGB(46, 44, 50)
local WOOD = Color3.fromRGB(96, 66, 42)
local RUNE = Color3.fromRGB(120, 200, 255)
local GOLD = Color3.fromRGB(255, 205, 90)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

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

local function deco(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Modelli di Mirko (ServerStorage.PlotBuildings): copia senza script, alta "height", con la base
-- in cf. Le mesh hanno la collisione a scatola (non si cambia da script): niente collisioni, si
-- cammina sul terreno. Il perno finisce al centro del modello (i cristalli li muove il client).
local function prop(parent: Instance, name: string, height: number, cf: CFrame): Model?
	local ServerStorage = game:GetService("ServerStorage")
	local src: Instance? = nil
	for _, folderName in { "Modelli", "PlotBuildings" } do
		local store = ServerStorage:FindFirstChild(folderName)
		src = src or (store and store:FindFirstChild(name))
	end
	if not src or not src:IsA("Model") then
		return nil
	end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * height / size.Y)
	m:PivotTo(cf.Rotation + m:GetPivot().Position)
	local box, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (cf.Position - (box.Position - Vector3.new(0, s.Y / 2, 0))))
	m.WorldPivot = (m:GetBoundingBox())
	m.Parent = parent
	return m
end

local function prompt(parent: Instance, action: string, object: string, distance: number): ProximityPrompt
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = distance
	pr.RequiresLineOfSight = false
	pr.Parent = parent
	return pr
end

-- Gemma: cubo appoggiato su uno spigolo (guscio di vetro + cuore luminoso)
local function gem(parent: Instance, name: string, at: CFrame, size: number, shell: Color3, core: Color3): Part
	local model = Instance.new("Model")
	model.Name = name
	local tilt = at * CFrame.Angles(math.rad(45), 0, math.rad(35))
	local glass = deco(part(model, "Guscio", Vector3.one * size, tilt, shell, Enum.Material.Glass))
	glass.Transparency = 0.3
	glass.CanQuery = true -- il prompt sta qui
	deco(part(model, "Cuore", Vector3.one * size * 0.55, tilt, core, Enum.Material.Neon))
	model.PrimaryPart = glass
	model.Parent = parent
	return glass
end

-- Cerchio di rune: terreno spianato (pietra), due anelli luminosi e una stella a sei punte,
-- pietre con le rune tutto attorno, scintille che salgono. Restituisce la quota del pavimento.
local function glowLine(parent: Instance, p1: Vector3, p2: Vector3, width: number, transparency: number)
	local mid = (p1 + p2) / 2
	local seg = deco(part(parent, "Runa", Vector3.new(width, 0.12, (p2 - p1).Magnitude + width * 0.4), CFrame.lookAt(mid, p2), RUNE, Enum.Material.Neon))
	seg.Transparency = transparency
end

local function buildCircle(parent: Instance, center: Vector3): number
	local R = T.CIRCLE_RADIUS
	local terrain = workspace.Terrain
	terrain:FillCylinder(CFrame.new(center - Vector3.new(0, 4, 0)), 8, R + 30, Enum.Material.Slate)
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, 10, 0)), 20, R + 30, Enum.Material.Air)
	local floorY = groundAt(center).Y
	local y = Vector3.new(center.X, floorY + 0.08, center.Z)
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
		glowLine(parent, points[k], points[(k + 1) % 6 + 1], 0.3, 0.3)
	end
	for k = 0, 11 do
		local a = k / 12 * 2 * math.pi
		local p = groundAt(center + Vector3.new(math.cos(a) * (R + 1.8), 0, math.sin(a) * (R + 1.8)))
		local look = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z))
		local stone = part(parent, "PietraRuna", Vector3.new(1.8, 3, 1.2), look * CFrame.new(0, 1.1, 0), STONE, Enum.Material.Slate)
		deco(part(parent, "Runa", Vector3.new(0.6, 0.9, 0.1), stone.CFrame * CFrame.new(0, 0.4, -0.62), RUNE, Enum.Material.Neon))
	end
	local emitterPart = deco(part(parent, "ScintilleCerchio", Vector3.new(R * 2, 0.2, R * 2), CFrame.new(y), RUNE, Enum.Material.SmoothPlastic))
	emitterPart.Transparency = 1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKLE
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
	return floorY
end

-- Cristallo del Potere sopra il centro del cerchio, con il raggio di luce verso il cielo
local function buildPowerCrystal(parent: Instance, floor: Vector3)
	local model = prop(parent, "crystal target", 26, CFrame.new(floor + Vector3.new(0, 58, 0))) -- alto sopra l'arena
	local glass: BasePart
	if model then
		model.Name = "CristalloPotere"
		glass = model:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	else
		glass = gem(parent, "CristalloPotere", CFrame.new(floor + Vector3.new(0, 13, 0)), 5, Color3.fromRGB(190, 235, 255), RUNE)
		model = glass.Parent :: Model
	end
	local model = model :: Model
	model:SetAttribute("Base", floor + Vector3.new(0, 71, 0))
	CollectionService:AddTag(model, "CristalloPotere")
	local light = Instance.new("PointLight")
	light.Color = RUNE
	light.Range = 40
	light.Brightness = 2.5
	light.Parent = glass
	local orbit = Instance.new("ParticleEmitter")
	orbit.Texture = SPARKLE
	orbit.Color = ColorSequence.new(RUNE, Color3.new(1, 1, 1))
	orbit.LightEmission = 1
	orbit.Size = NumberSequence.new(0.6, 0)
	orbit.Lifetime = NumberRange.new(1, 1.6)
	orbit.Speed = NumberRange.new(2, 4)
	orbit.SpreadAngle = Vector2.new(180, 180)
	orbit.Rate = 25
	orbit.Parent = glass
	-- raggio: due attacchi, uno nel cristallo e uno molto in alto
	local sky = deco(part(parent, "Cielo", Vector3.one, CFrame.new(floor + Vector3.new(0, 700, 0)), RUNE, Enum.Material.SmoothPlastic))
	sky.Transparency = 1
	local a0 = Instance.new("Attachment")
	a0.Parent = glass
	local a1 = Instance.new("Attachment")
	a1.Parent = sky
	for k, info in { { 6, 14, 0.55, "" }, { 3, 8, 0.2, SPARKLE } } do
		local beam = Instance.new("Beam")
		beam.Name = "Raggio" .. k
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = info[1], info[2]
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(RUNE, Color3.fromRGB(220, 245, 255))
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, info[3]), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) })
		if info[4] ~= "" then
			beam.Texture = info[4]
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 6
			beam.TextureSpeed = 1.5
		end
		beam.Segments = 2
		beam.Parent = glass
	end
end

-- Un braciere per elemento, attorno al cerchio, col fuoco del colore del drago
local function buildBraziers(parent: Instance, center: Vector3)
	local list = DragonConfig.ELEMENTS
	local r = T.CIRCLE_RADIUS + 24 -- sul bordo della piattaforma (prima stavano in mezzo)
	for k, e in list do
		local a = (k - 1) / #list * 2 * math.pi
		local p = groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		local model = Instance.new("Model")
		model.Name = "Braciere" .. e.id
		model:SetAttribute("Element", e.id)
		local H = 7
		local mesh = prop(model, "braciere draconico", H, CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)))
		if not mesh then
			H = 4
			part(model, "Colonna", Vector3.new(3.2, 1.6, 1.6), CFrame.new(p + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
			part(model, "Coppa", Vector3.new(0.8, 3, 3), CFrame.new(p + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		local glow = deco(part(model, "Brace", Vector3.new(0.3, 2.4, 2.4), CFrame.new(p + Vector3.new(0, H - 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), e.glow, Enum.Material.Neon, Enum.PartType.Cylinder))
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 8
		fire.Color = e.color
		fire.SecondaryColor = e.glow
		fire.Parent = glow
		local light = Instance.new("PointLight")
		light.Color = e.glow
		light.Range = 12
		light.Brightness = 1
		light.Parent = glow
		CollectionService:AddTag(model, "BracereElemento")
		model.Parent = parent
	end
end

-- Bersaglio: cristallo sospeso sopra un piedistallo con un anello di rune (gira e ondeggia sul
-- client). Restituisce la parte su cui sta il prompt.
local function buildTarget(parent: Instance, at: Vector3, index: number): BasePart
	local model = prop(parent, "crystal target", 7, CFrame.new(at - Vector3.new(0, 3.5, 0)))
	local glass: BasePart
	if model then
		model.Name = "Bersaglio" .. index
		glass = model:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	else
		glass = gem(parent, "Bersaglio" .. index, CFrame.new(at), 3, Color3.fromRGB(170, 225, 255), Color3.fromRGB(90, 170, 255))
		model = glass.Parent :: Model
	end
	local model = model :: Model
	model:SetAttribute("Index", index)
	local light = Instance.new("PointLight")
	light.Color = RUNE
	light.Range = 24
	light.Brightness = 4
	light.Parent = glass
	-- texture originale del modello (niente Highlight che la copriva): solo luce che esce dalle facce
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back } do
		local sl = Instance.new("SurfaceLight")
		sl.Face = face
		sl.Color = RUNE
		sl.Range = 14
		sl.Brightness = 3
		sl.Angle = 120
		sl.Parent = glass
	end
	CollectionService:AddTag(model, "CristalloBersaglio")
	return glass
end

-- Altare della sfida e tabellone dei record
local function buildRushAltar(parent: Instance, at: Vector3, center: Vector3): (Part, TextLabel)
	local look = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z))
	part(parent, "AltareSfida", Vector3.new(4, 3, 4), look * CFrame.new(0, 1.5, 0), STONE, Enum.Material.Slate)
	local orb = deco(part(parent, "SferaSfida", Vector3.one * 2.2, look * CFrame.new(0, 4.4, 0), GOLD, Enum.Material.Neon, Enum.PartType.Ball))
	orb.CanQuery = true
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14
	light.Brightness = 2
	light.Parent = orb
	local board: Part
	local stele = prop(parent, "rune scoreboard", 16, look * CFrame.new(-9, 0, 0))
	if stele then
		-- la lastra e' al centro del modello, sul davanti (verso il cerchio)
		local box, s = stele:GetBoundingBox()
		board = deco(part(parent, "TabelloneRecord", Vector3.new(s.X * 0.5, s.Y * 0.42, 0.2), CFrame.lookAt(box.Position, box.Position + look.LookVector) * CFrame.new(0, -s.Y * 0.04, -s.Z * 0.5 - 0.2), WOOD, Enum.Material.SmoothPlastic))
		board.Transparency = 1
	else
		board = part(parent, "TabelloneRecord", Vector3.new(9, 6, 0.4), look * CFrame.new(-8, 4.5, 0), WOOD, Enum.Material.WoodPlanks)
		part(parent, "PaloTabellone", Vector3.new(0.6, 7.5, 0.6), look * CFrame.new(-12, 3.75, 0), WOOD, Enum.Material.Wood)
		part(parent, "PaloTabellone", Vector3.new(0.6, 7.5, 0.6), look * CFrame.new(-4, 3.75, 0), WOOD, Enum.Material.Wood)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.fromRGB(255, 226, 160)
	label.Text = "TARGET RUSH · BEST\n<font size=\"18\">No records yet</font>"
	label.Parent = gui
	return orb, label
end

-- Bancarella dei boost (a Robux)
local function buildStall(parent: Instance, at: Vector3, center: Vector3): (Part, Part)
	local look = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z))
	part(parent, "Bancone", Vector3.new(8, 3, 3), look * CFrame.new(0, 1.5, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -3.6, 3.6 } do
		part(parent, "PaloBancarella", Vector3.new(0.5, 7, 0.5), look * CFrame.new(x, 3.5, 1.2), WOOD, Enum.Material.Wood)
	end
	part(parent, "Tendone", Vector3.new(9, 0.3, 4.4), look * CFrame.new(0, 7.1, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(70, 110, 190), Enum.Material.Fabric)
	local x2 = gem(parent, "PozioneX2", look * CFrame.new(-2, 4, 0), 1.3, Color3.fromRGB(200, 240, 255), RUNE)
	local x3 = gem(parent, "PozioneX3", look * CFrame.new(2, 4, 0), 1.3, Color3.fromRGB(255, 240, 200), GOLD)
	local sign = part(parent, "InsegnaBancarella", Vector3.new(7, 1.6, 0.2), look * CFrame.new(0, 6.2, -1.2), WOOD, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = "TRAINING BOOSTS"
	label.Parent = gui
	return x2, x3
end

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
	label.Text = "DRAGON TRAINING GROUNDS\n<font size=\"20\">Hit the crystals · stand in the circle · reach Lv 100 to evolve</font>"
	label.RichText = true
	label.Parent = gui
end

-- moltiplicatore dell'XP di addestramento di un giocatore
local function xpMult(player: Player): number
	local m = 1
	if Dragons.hasPass(player, "TrainingX2") then
		m *= T.PASS_MULT
	end
	if ((player:GetAttribute("TrainingBoostUntil") or 0) :: number) > os.time() then
		m *= T.BOOST_MULT
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		m *= T.PREMIUM_MULT
	end
	return m
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
		buildPowerCrystal(folder, center)
		buildBraziers(folder, center)
		local _ = size
		local hubMarker = workspace:FindFirstChild("MapMarkers") and (workspace :: any).MapMarkers:FindFirstChild("HubSpawn")
		local gateA = if hubMarker then math.atan2(hubMarker.Position.Z - center.Z, hubMarker.Position.X - center.X) else 0
		local ARENA_H = 100 -- il doppio di quella di prima
		-- terreno piatto sotto tutta l'arena (prima era storto e spuntava dalla piattaforma)
		workspace.Terrain:FillCylinder(CFrame.new(center - Vector3.new(0, 5, 0)), 10, ARENA_H * 1.45, Enum.Material.Ground)
		workspace.Terrain:FillCylinder(CFrame.new(center + Vector3.new(0, 30, 0)), 60, ARENA_H * 1.45, Enum.Material.Air)
		-- la piattaforma del modello sta al 35% dell'altezza: va a filo del terreno (prima era sopra la
		-- testa e si camminava sotto). Le scale del modello (lato -Z, davanti) guardano il portale.
		local gateDir = Vector3.new(math.cos(gateA), 0, math.sin(gateA))
		local arena = prop(folder, "arenadrago", ARENA_H, CFrame.lookAt(center, center + gateDir) - Vector3.new(0, ARENA_H * 0.35, 0))
		if arena then
			arena.Name = "ArenaOssa"
			-- l'arena e' tutta chiusa (un cilindro invisibile grande quanto le ossa): dentro ci vanno
			-- solo i draghi. Tu sali sulla pedana davanti alle scale e "diventi" il tuo drago, che
			-- vola al centro (prima si camminava nella mesh e il drago aveva le zampe nel pavimento)
			local _, asize = arena:GetBoundingBox()
			local R = math.max(asize.X, asize.Z) * 0.49
			local block = part(arena, "Recinto", Vector3.new(120, R * 2, R * 2), CFrame.new(center + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			block.Transparency = 1
			-- si sbatte contro, ma il rampino e l'arrampicata non lo vedono (prima ci si aggrappava al
			-- muro invisibile); niente ombra
			block.CanQuery = false
			block.CanTouch = false
			block.CastShadow = false
			local padAt = groundAt(center + gateDir * (R + 7))
			local pad = part(folder, "PedanaDrago", Vector3.new(1.2, 12, 12), CFrame.new(padAt + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 40, 52), Enum.Material.Slate, Enum.PartType.Cylinder)
			local ring = deco(part(folder, "AnelloPedana", Vector3.new(0.3, 12.6, 12.6), CFrame.new(padAt + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), RUNE, Enum.Material.Neon, Enum.PartType.Cylinder))
			ring.Transparency = 0.2
			local glowP = Instance.new("PointLight")
			glowP.Color = RUNE
			glowP.Range = 16
			glowP.Brightness = 2
			glowP.Parent = ring
			local _ = pad
			workspace:SetAttribute("TrainingPad", padAt)
		end
		for k = 0, 7 do
			local a = (k + 0.5) / 8 * 2 * math.pi
			local off = math.abs((a - gateA + math.pi) % (2 * math.pi) - math.pi)
			local outer = if arena then math.max(arena:GetExtentsSize().X, arena:GetExtentsSize().Z) * 0.56 else T.CRYSTAL_RING + 40
			local p = groundAt(center + Vector3.new(math.cos(a), 0, math.sin(a)) * outer)
			if off < 0.7 then
				continue -- davanti al portale
			end
			local pillar = prop(folder, "dragon pillar", 22, CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)) - Vector3.new(0, 1, 0))
			if pillar then
				-- collisione: un cilindro invisibile nella colonna
				local c = part(pillar, "Collisione", Vector3.new(22, 5, 5), CFrame.new(p + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
				c.Transparency = 1
			end
		end
		local ring = T.CRYSTAL_RING + 10
		local targets: { BasePart } = {}
		for k = 1, T.TARGETS do
			table.insert(targets, buildTarget(folder, DragonConfig.crystalAt(center, k, 0), k))
		end
		local function around(da: number, dist: number): Vector3
			return groundAt(center + Vector3.new(math.cos(gateA + da), 0, math.sin(gateA + da)) * dist)
		end
		-- altare della sfida, bancarella e cartello fuori dall'arena (chiusa), ai lati della pedana
		local outR = if arena then math.min(arena:GetExtentsSize().X, arena:GetExtentsSize().Z) * 0.47 else ring
		local arc = 14 / math.max(outR, 1) -- 14 studs di lato
		buildSign(folder, around(arc * 2.2, outR + 16), center)
		local orb, board = buildRushAltar(folder, around(-arc, outR + 9), center)
		local x2, x3 = buildStall(folder, around(arc, outR + 9), center)
		-- portale d'ingresso (il modello di Mirko in ServerStorage.Modelli.PortaleArena), con la
		-- scalinata rivolta verso la piana
		local models = game:GetService("ServerStorage"):FindFirstChild("Modelli")
		local gate = models and models:FindFirstChild("PortaleArena")
		if gate and gate:IsA("Model") then
			local g = gate:Clone()
			for _, d in g:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				end
			end
			local _, gsize = g:GetBoundingBox()
			g:ScaleTo(g:GetScale() * 62 / gsize.Y)
			local markers = workspace:FindFirstChild("MapMarkers")
			local hub = markers and markers:FindFirstChild("HubSpawn")
			local toHub = if hub and hub:IsA("BasePart") then hub.Position - center else Vector3.new(-1, 0, 1)
			local dir = Vector3.new(toHub.X, 0, toHub.Z).Unit
			local reach = if arena then math.max(arena:GetExtentsSize().X, arena:GetExtentsSize().Z) * 0.5 + 18 else 82
			local at = groundAt(center + dir * reach)
			g:PivotTo(CFrame.lookAt(at, at + dir))
			local box, bsize = g:GetBoundingBox()
			g:PivotTo(g:GetPivot() + Vector3.new(0, at.Y - (box.Position.Y - bsize.Y / 2) - 1, 0))
			g.Name = "PortaleArena"
			-- la mesh ha la collisione a scatola: chiudeva il passaggio. Si cammina sul terreno.
			for _, d in g:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true -- reimportato non ancorato: senza collisione cadeva nel vuoto
					d.CanCollide = false
				end
			end
			g.Parent = folder
		end
		folder.Parent = workspace
		workspace:SetAttribute("TrainingCenter", center)

		local function give(player: Player, d: any, base: number): number
			local xp = math.floor(base * xpMult(player) + 0.5)
			Dragons.addXp(player, d.id, xp)
			return xp
		end

		-- Target Rush: un cristallo dorato alla volta, per giocatore
		type Rush = { lit: number, score: number, ends: number, switchAt: number, armed: boolean }
		local rushes: { [Player]: Rush } = {}
		local lastRush: { [Player]: number } = {}
		local best: { { name: string, score: number } } = {}
		local function refreshBoard()
			local lines = { "TARGET RUSH · BEST" }
			for k = 1, math.min(5, #best) do
				table.insert(lines, string.format("<font size=\"18\">%d. %s  ·  %d</font>", k, best[k].name, best[k].score))
			end
			if #best == 0 then
				table.insert(lines, "<font size=\"18\">No records yet</font>")
			end
			board.Text = table.concat(lines, "\n")
		end
		local function newLit(r: Rush)
			local k = r.lit
			while k == r.lit and #targets > 1 do
				k = math.random(1, #targets)
			end
			r.lit = k
			r.switchAt = os.clock() + T.RUSH_EVERY
		end
		local function startRush(player: Player)
			if rushes[player] then
				return
			end
			local wait = T.RUSH_COOLDOWN - (os.clock() - (lastRush[player] or -math.huge))
			if wait > 0 then
				fx:FireClient(player, "hint", 0, string.format("Target Rush ready again in %d s", math.ceil(wait)))
				return
			end
			if #Dragons.equippedDragons(player) == 0 then
				fx:FireClient(player, "hint", 0, "You need a dragon following you to train")
				return
			end
			-- prenotata: il tempo parte quando entri nel cerchio (entro un minuto)
			rushes[player] = { lit = 0, score = 0, ends = os.clock() + 60, switchAt = math.huge, armed = true }
			lastRush[player] = os.clock()
			fx:FireClient(player, "hint", 0, "Target Rush ready: step into the circle to start!")
		end
		local function endRush(player: Player)
			local r = rushes[player]
			if not r then
				return
			end
			rushes[player] = nil
			local found = false
			for _, e in best do
				if e.name == player.DisplayName then
					e.score = math.max(e.score, r.score)
					found = true
				end
			end
			if not found then
				table.insert(best, { name = player.DisplayName, score = r.score })
			end
			table.sort(best, function(a, b)
				return a.score > b.score
			end)
			refreshBoard()
			fx:FireClient(player, "rushEnd", 0, r.score, best[1] and best[1].score or r.score)
		end
		prompt(orb, "Start Target Rush", string.format("%d s challenge", T.RUSH_SECONDS), 12).Triggered:Connect(startRush)

		-- bancarella: pass e boost a Robux (ID in DragonConfig.GAMEPASSES e ShopConfig.DEV_PRODUCTS)
		prompt(x2, "Training XP x2", "Game Pass", 10).Triggered:Connect(function(player)
			local id = DragonConfig.GAMEPASSES.TrainingX2
			if Dragons.hasPass(player, "TrainingX2") then
				fx:FireClient(player, "hint", 0, "You already have Training XP x2!")
			elseif id and id > 0 then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				fx:FireClient(player, "hint", 0, "Coming soon")
			end
		end)
		prompt(x3, "Boost x3 · 15 min", "Training boost", 10).Triggered:Connect(function(player)
			local id = ShopConfig.DEV_PRODUCTS.TrainingBoost
			if id and id > 0 then
				MarketplaceService:PromptProductPurchase(player, id)
			else
				fx:FireClient(player, "hint", 0, "Coming soon")
			end
		end)

		-- colpi mirati: il client dice da dove e verso dove ha sparato; il server cerca il cristallo
		-- su quella linea (dove si trova adesso e un attimo fa, per il ritardo della rete)
		local lastHit: { [Player]: number } = {}
		fx.OnServerEvent:Connect(function(player: Player, action: any, origin: any, dir: any)
			if action ~= "shoot" or typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or dir.Magnitude < 0.5 then
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- spara il drago, che vola dentro l'arena (lontano dal personaggio sulla pedana): l'origine
			-- deve stare nell'arena
			if not root or (origin - center).Magnitude > 170 or not player:GetAttribute("Training") then
				return
			end
			local now = os.clock()
			if now - (lastHit[player] or 0) < T.SHOT_COOLDOWN then
				return
			end
			local list = Dragons.equippedDragons(player)
			if #list == 0 then
				return
			end
			lastHit[player] = now
			dir = dir.Unit
			-- auto-mira: vale il cristallo piu' vicino al centro del mirino entro 12 gradi (prima
			-- bisognava passare a 5 studs dal cristallo: quasi impossibile)
			local best, bestAngle, bestPos = nil, math.rad(12), nil
			local tNow = workspace:GetServerTimeNow()
			for k = 1, #targets do
				for _, lag in { 0, 0.12, 0.25 } do
					local p = DragonConfig.crystalAt(center, k, tNow - lag)
					local v = p - origin
					local dist = v.Magnitude
					local angle = math.acos(math.clamp(v.Unit:Dot(dir), -1, 1))
					if dist < 220 and angle < bestAngle then
						best, bestAngle, bestPos = k, angle, p
					end
				end
			end
			if not best then
				fx:FireClient(player, "miss", 0, origin + dir * 90, list[1].element)
				return
			end
			local r = rushes[player]
			local golden = r ~= nil and r.lit == best
			for _, d in list do
				local xp = give(player, d, if golden then T.RUSH_XP else T.TARGET_XP)
				-- solo a chi spara: ognuno si addestra "da solo" (meno lag con tanti giocatori)
				fx:FireClient(player, "hit", player.UserId, bestPos, d.element, xp)
			end
			if r and golden then
				r.score += 1
				newLit(r)
				fx:FireClient(player, "rush", 0, r.lit, math.max(0, r.ends - os.clock()), r.score)
			end
		end)
		Players.PlayerRemoving:Connect(function(player)
			lastHit[player] = nil
			rushes[player] = nil
			lastRush[player] = nil
		end)

		-- sfide in corso: il cristallo dorato cambia da solo, e alla fine il risultato
		task.spawn(function()
			while true do
				task.wait(0.1)
				local now = os.clock()
				for player, r in rushes do
					if r.armed then
						if player:GetAttribute("Training") then
							r.armed = false
							r.ends = now + T.RUSH_SECONDS
							newLit(r)
							fx:FireClient(player, "rush", 0, r.lit, T.RUSH_SECONDS, 0)
						elseif now >= r.ends then
							rushes[player] = nil -- non e' mai entrato
						end
					elseif now >= r.ends then
						endRush(player)
					elseif now >= r.switchAt then
						newLit(r)
						fx:FireClient(player, "rush", 0, r.lit, r.ends - now, r.score)
					end
				end
			end
		end)

		-- cerchio: XP al secondo a chi ci sta dentro col drago
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				player:SetAttribute("TrainingMult", xpMult(player))
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local inside = false
				if root then
					-- sulla pedana davanti all'arena (se non c'e' l'arena: nel cerchio)
					local padAt = workspace:GetAttribute("TrainingPad")
					local d = root.Position - (if typeof(padAt) == "Vector3" then padAt else center)
					local r = if typeof(padAt) == "Vector3" then 7 else T.CIRCLE_RADIUS
					inside = Vector3.new(d.X, 0, d.Z).Magnitude <= r and math.abs(d.Y) < 12
				end
				local list = if inside then Dragons.equippedDragons(player) else {}
				player:SetAttribute("Training", #list > 0)
				for _, d in list do
					give(player, d, T.CIRCLE_XP)
				end
			end
		end
	end)
end

return Training
