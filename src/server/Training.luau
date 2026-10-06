--!strict
-- Zona di addestramento dei draghi, dentro la cassa toracica del drago gigante (DragonRibs):
--   * CERCHIO     cerchio di rune con al centro il Cristallo del Potere, che manda un raggio di
--                 luce verso il cielo; finche' ci stai dentro col drago: CIRCLE_XP al secondo
--   * BRACIERI    uno per elemento attorno al cerchio: divampano quando si allena un drago di
--                 quell'elemento (effetto sul client)
--   * CRISTALLI   bersagli sospesi che girano: premi E e il tuo drago spara (TARGET_XP)
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
	local glass = gem(parent, "CristalloPotere", CFrame.new(floor + Vector3.new(0, 13, 0)), 5, Color3.fromRGB(190, 235, 255), RUNE)
	local model = glass.Parent :: Model
	model:SetAttribute("Base", floor + Vector3.new(0, 13, 0))
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
	local r = T.CIRCLE_RADIUS + 6
	for k, e in list do
		local a = (k - 1) / #list * 2 * math.pi
		local p = groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		local model = Instance.new("Model")
		model.Name = "Braciere" .. e.id
		model:SetAttribute("Element", e.id)
		part(model, "Colonna", Vector3.new(3.2, 1.6, 1.6), CFrame.new(p + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
		part(model, "Coppa", Vector3.new(0.8, 3, 3), CFrame.new(p + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
		local glow = deco(part(model, "Brace", Vector3.new(0.3, 2.4, 2.4), CFrame.new(p + Vector3.new(0, 3.95, 0)) * CFrame.Angles(0, 0, math.pi / 2), e.glow, Enum.Material.Neon, Enum.PartType.Cylinder))
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
local function buildTarget(parent: Instance, at: Vector3, index: number): Part
	part(parent, "Piedistallo" .. index, Vector3.new(1.2, 6, 6), CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
	deco(part(parent, "AnelloRune", Vector3.new(0.1, 6.6, 6.6), CFrame.new(at + Vector3.new(0, 1.12, 0)) * CFrame.Angles(0, 0, math.pi / 2), RUNE, Enum.Material.Neon, Enum.PartType.Cylinder)).Transparency = 0.4
	local base = at + Vector3.new(0, 8, 0)
	local glass = gem(parent, "Bersaglio" .. index, CFrame.new(base), 3, Color3.fromRGB(170, 225, 255), Color3.fromRGB(90, 170, 255))
	local model = glass.Parent :: Model
	model:SetAttribute("Base", base)
	model:SetAttribute("Index", index)
	CollectionService:AddTag(model, "CristalloBersaglio")
	prompt(glass, "Train", "Dragon target", 45)
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
	local board = part(parent, "TabelloneRecord", Vector3.new(9, 6, 0.4), look * CFrame.new(-8, 4.5, 0), WOOD, Enum.Material.WoodPlanks)
	part(parent, "PaloTabellone", Vector3.new(0.6, 7.5, 0.6), look * CFrame.new(-12, 3.75, 0), WOOD, Enum.Material.Wood)
	part(parent, "PaloTabellone", Vector3.new(0.6, 7.5, 0.6), look * CFrame.new(-4, 3.75, 0), WOOD, Enum.Material.Wood)
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
		local ring = math.clamp(math.min(size.X, size.Z) * 0.3, T.CIRCLE_RADIUS + 16, 60)
		local targets: { Part } = {}
		for k = 1, T.TARGETS do
			local a = (k - 0.5) / T.TARGETS * 2 * math.pi
			local at = groundAt(center + Vector3.new(math.cos(a) * ring, 0, math.sin(a) * ring))
			table.insert(targets, buildTarget(folder, at, k))
		end
		buildSign(folder, groundAt(center + Vector3.new(ring + 14, 0, 0)), center)
		local orb, board = buildRushAltar(folder, groundAt(center + Vector3.new(-(ring + 12), 0, 6)), center)
		local x2, x3 = buildStall(folder, groundAt(center + Vector3.new(0, 0, ring + 14)), center)
		folder.Parent = workspace
		workspace:SetAttribute("TrainingCenter", center)

		local function give(player: Player, d: any, base: number): number
			local xp = math.floor(base * xpMult(player) + 0.5)
			Dragons.addXp(player, d.id, xp)
			return xp
		end

		-- Target Rush: un cristallo dorato alla volta, per giocatore
		type Rush = { lit: number, score: number, ends: number, switchAt: number }
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
			local r: Rush = { lit = 0, score = 0, ends = os.clock() + T.RUSH_SECONDS, switchAt = 0 }
			newLit(r)
			rushes[player] = r
			lastRush[player] = os.clock()
			fx:FireClient(player, "rush", 0, r.lit, T.RUSH_SECONDS, 0)
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

		-- cristalli: un colpo del drago, XP a tutti i draghi al seguito
		local lastHit: { [Player]: number } = {}
		for index, glass in targets do
			local pr = glass:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
			pr.Triggered:Connect(function(player)
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
				local r = rushes[player]
				local golden = r ~= nil and r.lit == index
				for _, d in list do
					local xp = give(player, d, if golden then T.RUSH_XP else T.TARGET_XP)
					fx:FireAllClients("hit", player.UserId, glass.Position, d.element, xp)
				end
				if r and golden then
					r.score += 1
					newLit(r)
					fx:FireClient(player, "rush", 0, r.lit, math.max(0, r.ends - os.clock()), r.score)
				end
			end)
		end
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
					if now >= r.ends then
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
					local d = root.Position - center
					inside = Vector3.new(d.X, 0, d.Z).Magnitude <= T.CIRCLE_RADIUS and math.abs(d.Y) < 12
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
