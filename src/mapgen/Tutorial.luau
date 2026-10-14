--!strict
-- Zona tutorial davanti al campo delle tende: una parete di roccia vera (Terrain) alta
-- TUTORIAL.WALL_HEIGHT con la cima piatta e una scalinata dietro per scendere, un piazzale
-- in piano davanti, giacimenti di prova ai piedi della parete, il posto dell'uovo di
-- allenamento e i cartelli che spiegano i comandi. Tutto in workspace.Tutorial:
--   WallBase / WallTop  marcatori usati dal tutorial del server (arrivare in cima...)
--   EggSpot            dove compare l'uovo di allenamento (si schiude in 20 secondi)

local CollectionService = game:GetService("CollectionService")
local Heightmap = require(script.Parent.Heightmap)

local Tutorial = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.WoodPlanks
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function marker(parent: Instance, name: string, pos: Vector3): Part
	local p = part(parent, name, Vector3.new(2, 2, 2), CFrame.new(pos), Color3.new(1, 1, 0), Enum.Material.Neon)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Cartello di legno con testo
local function sign(parent: Instance, cf: CFrame, title: string, body: string)
	part(parent, "Post", Vector3.new(0.6, 6, 0.6), cf * CFrame.new(-3.5, 3, 0.4), Color3.fromRGB(72, 52, 38), Enum.Material.Wood)
	part(parent, "Post", Vector3.new(0.6, 6, 0.6), cf * CFrame.new(3.5, 3, 0.4), Color3.fromRGB(72, 52, 38), Enum.Material.Wood)
	local board = part(parent, "Sign", Vector3.new(9, 5, 0.4), cf * CFrame.new(0, 5.5, 0), Color3.fromRGB(176, 136, 96), Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextWrapped = true
	text.RichText = true
	text.TextColor3 = Color3.fromRGB(50, 34, 20)
	text.Text = "<font size=\"60\">" .. title .. "</font>\n" .. body
	text.Parent = gui
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 38
	limit.Parent = text
end

-- Freccia gialla luminosa che galleggia sopra un punto
local function beacon(parent: Instance, pos: Vector3)
	local arrow = part(parent, "Beacon", Vector3.new(1.4, 3, 1.4), CFrame.new(pos + Vector3.new(0, 4, 0)), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
	arrow.CanCollide = false
	arrow.CanQuery = false
	local tip = Instance.new("WedgePart")
	tip.Anchored = true
	tip.CanCollide = false
	tip.CanQuery = false
	tip.Size = Vector3.new(3, 2.4, 1.4)
	tip.CFrame = CFrame.new(pos + Vector3.new(0, 1.3, 0)) * CFrame.Angles(math.pi, 0, 0)
	tip.Color = arrow.Color
	tip.Material = Enum.Material.Neon
	tip.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = arrow.Color
	light.Range = 16
	light.Parent = arrow
end

local function trainingOre(parent: Instance, cf: CFrame, ore: string, color: Color3)
	local model = Instance.new("Model")
	model.Name = "Ore_" .. ore
	local rng = Random.new(#ore)
	for k = 1, 4 do
		local p = part(
			model,
			"Chunk",
			Vector3.new(rng:NextNumber(1.6, 2.6), rng:NextNumber(1.2, 2), rng:NextNumber(1.4, 2.2)),
			cf * CFrame.new(rng:NextNumber(-1.2, 1.2), 0.6 + rng:NextNumber(0, 0.8), rng:NextNumber(-1.2, 1.2))
				* CFrame.Angles(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)),
			if k == 1 then Color3.fromRGB(110, 106, 100) else color,
			if k == 1 then Enum.Material.Slate else Enum.Material.CorrodedMetal
		)
		if k == 1 then
			model.PrimaryPart = p
		end
	end
	CollectionService:AddTag(model, "OreNode")
	model:SetAttribute("OreType", ore)
	model:SetAttribute("Amount", 6)
	model:SetAttribute("MaxAmount", 6)
	model.Parent = parent
end

function Tutorial.build(map: Heightmap.Map)
	local cfg = map.cfg
	local T = cfg.TUTORIAL
	local old = workspace:FindFirstChild("Tutorial")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Tutorial"
	folder.Parent = workspace

	local HUB = cfg.HUB
	local cx, cz = HUB.X + HUB.CAMP.DX, HUB.Z + HUB.CAMP.DZ
	local dir = Vector3.new(math.cos(T.ANGLE), 0, math.sin(T.ANGLE))
	local center = Vector3.new(cx, 0, cz) + dir * T.DISTANCE
	local g = Heightmap.sampleH(map, center.X, center.Z)
	local face = -dir -- la parete guarda verso il campo
	local W, H, D = T.WALL_WIDTH, T.WALL_HEIGHT, 18
	-- sistema di riferimento: origine al piede della parete, -Z verso il campo
	local base = CFrame.lookAt(Vector3.new(center.X, g, center.Z), Vector3.new(center.X, g, center.Z) + face)
	local terrain = workspace.Terrain

	-- piazzale in piano davanti alla parete (via dossi e alberi)
	terrain:FillBlock(base * CFrame.new(0, -4, -26), Vector3.new(W + 30, 8, 44), Enum.Material.Grass)
	terrain:FillBlock(base * CFrame.new(0, 20, -26), Vector3.new(W + 30, 40, 44), Enum.Material.Air)
	-- la parete: faccia verticale verso il campo, cima piatta
	terrain:FillBlock(base * CFrame.new(0, H / 2 - 4, D / 2), Vector3.new(W, H + 8, D), Enum.Material.Rock)
	-- Niente strati piu' sottili di un voxel e mezzo: il Terrain e' fatto di cubi da 4 studs e
	-- un pezzo piu' sottile finisce scritto con occupancy quasi nulla, che Roblox disegna come
	-- una lama sottile sospesa in aria invece che come roccia.
	terrain:FillBlock(base * CFrame.new(0, H - 2, D / 2), Vector3.new(W, 8, D), Enum.Material.Ground)
	-- fascia di ghiaccio su un lato (per provare i Ramponi quando li avrai)
	terrain:FillBlock(base * CFrame.new(W / 2 - 5, H / 2, 2), Vector3.new(10, H - 2, 8), Enum.Material.Glacier)
	-- scalinata dietro per scendere
	local steps = math.ceil(H / 3)
	for k = 1, steps do
		local y = H - k * 3
		terrain:FillBlock(base * CFrame.new(-W / 4, y / 2 - 2, D + k * 4 + 2), Vector3.new(W / 2, y + 4, 8), Enum.Material.Rock)
	end

	marker(folder, "WallBase", (base * CFrame.new(0, 3, -4)).Position)
	marker(folder, "WallTop", (base * CFrame.new(0, H + 3, D / 2)).Position)
	beacon(folder, (base * CFrame.new(0, H + 2, 3)).Position)
	marker(folder, "EggSpot", (base * CFrame.new(-W / 2 - 6, 0.2, -8)).Position)

	-- giacimenti di prova ai piedi della parete
	trainingOre(folder, base * CFrame.new(-W / 2 + 6, 0, -5), "Ferro", Color3.fromRGB(163, 162, 165))
	trainingOre(folder, base * CFrame.new(-W / 2 + 12, 0, -4), "Carbone", Color3.fromRGB(38, 38, 42))
	trainingOre(folder, base * CFrame.new(W / 2 - 14, 0, -5), "Ferro", Color3.fromRGB(163, 162, 165))

	-- cartelli con i comandi
	local signs = {
		{ -W / 2 - 2, "CLIMBING", "Ice Axe (1): click near the rock\nW/S up and down, A/D sideways\nSpace: jump off" },
		{ -W / 6, "PITONS AND ROPE", "On the wall press F: piton\nIf you fall the rope catches you\nR: unclip the rope" },
		{ W / 6, "MINING AND CRAFTING", "Pickaxe (2): click the ores\nWorkbench at your camp:\nCrampons, Suit, Grappling Hook..." },
		{ W / 2 + 2, "DRAGON EGGS", "Pick up eggs and bring them\nto your camp's Nest\nG: Dragons menu" },
	}
	for _, s in signs do
		sign(folder, base * CFrame.new(s[1] :: number, 0, -20), s[2] :: string, s[3] :: string)
	end

	map.features.tutorial = { x = center.X, y = g, z = center.Z, radius = math.max(W, 60) }
end

return Tutorial
