--!strict
-- Palafitte sul lago grande: la zona tranquilla del gioco. Una passerella parte dalla riva
-- verso il campo e arriva a una piattaforma centrale con il falo' (scalda, tag "HeatSource") e
-- le panchine; attorno quattro capanne su pali, ognuna con amaca e lanterna, collegate da
-- passerelle; un piccolo molo con la barca. Panchine e amache sono Seat: ci si siede davvero.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Heightmap = require(script.Parent.Heightmap)

local Lakeside = {}

local WOOD = Color3.fromRGB(122, 88, 58)
local WOOD_DARK = Color3.fromRGB(86, 60, 40)
local THATCH = Color3.fromRGB(168, 140, 88)
local LANTERN = Color3.fromRGB(255, 190, 110)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
terrainOnly.IgnoreWater = true

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, class: string?): BasePart
	local p = Instance.new((class or "Part") :: any) :: BasePart
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

local function bedY(x: number, z: number, fromY: number): number
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -120, 0), terrainOnly)
	return if hit then hit.Position.Y else fromY - 20
end

-- palo che scende dal piano fino al fondo del lago
local function stilt(parent: Instance, top: Vector3)
	local bottom = bedY(top.X, top.Z, top.Y) - 2
	local len = top.Y - bottom
	local p = part(parent, "Palo", Vector3.new(len, 1.1, 1.1), CFrame.new(top.X, (top.Y + bottom) / 2, top.Z) * CFrame.Angles(0, 0, math.pi / 2), WOOD_DARK, Enum.Material.Wood)
	p.Shape = Enum.PartType.Cylinder
end

local function lantern(parent: Instance, at: Vector3)
	part(parent, "PaloLanterna", Vector3.new(0.4, 6, 0.4), CFrame.new(at + Vector3.new(0, 3, 0)), WOOD_DARK, Enum.Material.Wood)
	local lamp = part(parent, "Lanterna", Vector3.new(1.1, 1.4, 1.1), CFrame.new(at + Vector3.new(0, 6.4, 0)), LANTERN, Enum.Material.Neon)
	lamp.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = LANTERN
	light.Range = 18
	light.Brightness = 1.6
	light.Shadows = false -- le lanterne sono tante: ombre solo dal falo'
	light.Parent = lamp
end

-- passerella da a a b alla quota del piano, con i pali sotto
local function walkway(parent: Instance, a: Vector3, b: Vector3, width: number)
	local d = (b - a).Unit
	local len = (b - a).Magnitude
	local side = d:Cross(Vector3.yAxis).Unit
	part(parent, "Passerella", Vector3.new(width, 0.6, len), CFrame.lookAt((a + b) / 2, (a + b) / 2 + d), WOOD)
	local k = 4
	while k < len do
		for _, sgn in { -1, 1 } do
			stilt(parent, a + d * k + side * sgn * (width / 2 - 0.6) - Vector3.new(0, 0.3, 0))
		end
		k += 9
	end
	-- corrimano di corda ai lati
	for _, sgn in { -1, 1 } do
		local pa, pb = a + side * sgn * (width / 2) + Vector3.new(0, 2.6, 0), b + side * sgn * (width / 2) + Vector3.new(0, 2.6, 0)
		part(parent, "Corrimano", Vector3.new(0.25, 0.25, len), CFrame.lookAt((pa + pb) / 2, pb), Color3.fromRGB(200, 170, 120), Enum.Material.Fabric)
	end
end

local function bench(parent: Instance, cf: CFrame)
	local seat = part(parent, "Panchina", Vector3.new(6, 0.6, 1.8), cf * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.WoodPlanks, "Seat")
	seat.CanCollide = true
	part(parent, "Schienale", Vector3.new(6, 2, 0.4), cf * CFrame.new(0, 2.8, 0.8), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -2.5, 2.5 } do
		part(parent, "Gamba", Vector3.new(0.5, 1.4, 1.4), cf * CFrame.new(x, 0.7, 0), WOOD_DARK, Enum.Material.Wood)
	end
end

local function hut(parent: Instance, center: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(center, center + facing)
	local S = 16
	local model = Instance.new("Model")
	model.Name = "Palafitta"
	model.Parent = parent
	part(model, "Piano", Vector3.new(S, 0.8, S), cf, WOOD)
	for _, o in { Vector3.new(-S / 2 + 1, 0, -S / 2 + 1), Vector3.new(S / 2 - 1, 0, -S / 2 + 1), Vector3.new(-S / 2 + 1, 0, S / 2 - 1), Vector3.new(S / 2 - 1, 0, S / 2 - 1), Vector3.zero } do
		stilt(model, (cf * CFrame.new(o)).Position - Vector3.new(0, 0.4, 0))
	end
	-- capanna: tre pareti piene e quella davanti con la porta, tetto di paglia a due falde
	local W, Hh = 11, 7
	local base = cf * CFrame.new(0, 0.4, 1)
	part(model, "Muro", Vector3.new(W, Hh, 0.6), base * CFrame.new(0, Hh / 2, W / 2), WOOD, Enum.Material.WoodPlanks)
	part(model, "Muro", Vector3.new(0.6, Hh, W), base * CFrame.new(-W / 2, Hh / 2, 0), WOOD, Enum.Material.WoodPlanks)
	part(model, "Muro", Vector3.new(0.6, Hh, W), base * CFrame.new(W / 2, Hh / 2, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -3.6, 3.6 } do
		part(model, "Muro", Vector3.new(3.8, Hh, 0.6), base * CFrame.new(x, Hh / 2, -W / 2), WOOD, Enum.Material.WoodPlanks)
	end
	part(model, "Architrave", Vector3.new(3.4, 1.6, 0.6), base * CFrame.new(0, Hh - 0.8, -W / 2), WOOD, Enum.Material.WoodPlanks)
	for _, sgn in { -1, 1 } do
		local roof = part(model, "Tetto", Vector3.new(W + 3, 0.7, W / 2 + 2.6), base * CFrame.new(sgn * 3.1, Hh + 2.3, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(sgn * math.rad(38), 0, 0), THATCH, Enum.Material.Grass)
		roof.CastShadow = true
	end
	-- dentro: amaca e lanterna
	local hammock = part(model, "Amaca", Vector3.new(6, 0.4, 2.4), base * CFrame.new(0, 2.2, 1.5), Color3.fromRGB(205, 90, 70), Enum.Material.Fabric, "Seat")
	hammock.CanCollide = true
	local lamp = part(model, "Lanterna", Vector3.new(0.9, 1.1, 0.9), base * CFrame.new(0, Hh - 1.2, 0), LANTERN, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = LANTERN
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = lamp
end

function Lakeside.build(map: Heightmap.Map)
	local old = workspace:FindFirstChild("Lakeside")
	if old then
		old:Destroy()
	end
	local lake = map.features.bigLake
	if not lake then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lakeside"
	-- il tuo modello (ServerStorage.Modelli.Palafitte): al centro del lago, con i pali che
	-- affondano nel fondale e il lato lungo rivolto verso il campo
	local models = ServerStorage:FindFirstChild("Modelli")
	local template = models and models:FindFirstChild("Palafitte")
	if template and template:IsA("Model") then
		local m = template:Clone()
		-- senza le due baite rosse (Mirko 16/10: "togli le due baite")
		local cabins = m:FindFirstChild("Baite", true)
		if cabins then
			cabins:Destroy()
		end
		local spot = (map.cfg :: any).PALAFITTE
		if spot then
			-- nel lago del teschio: livello dell'acqua letto dal terreno gia' scritto
			local probe = RaycastParams.new()
			probe.FilterType = Enum.RaycastFilterType.Include
			probe.FilterDescendantsInstances = { workspace.Terrain }
			local hit = workspace:Raycast(Vector3.new(spot.X, 600, spot.Z), Vector3.new(0, -800, 0), probe)
			local waterY = if hit and hit.Material == Enum.Material.Water then hit.Position.Y else lake.y
			local at = Vector3.new(spot.X, waterY - spot.SINK, spot.Z)
			m:PivotTo(CFrame.lookAt(at, at + spot.LOOK))
		else
			local camp0 = map.features.campCenter
			local dir = Vector3.new(camp0.x - lake.x, 0, camp0.z - lake.z).Unit
			local at = Vector3.new(lake.x, lake.y - map.cfg.BIG_LAKE.DEPTH * 0.75, lake.z)
			m:PivotTo(CFrame.lookAt(at, at + dir))
		end
		m.Parent = folder
		folder.Parent = workspace
		return
	end
	local deckY = lake.y + 3.5
	local center = Vector3.new(lake.x, deckY, lake.z)
	local camp = map.features.campCenter
	local toCamp = Vector3.new(camp.x - lake.x, 0, camp.z - lake.z).Unit

	-- riva: dal centro verso il campo finche' il fondo esce dall'acqua
	local shore = center
	for r = 0, lake.radius * 1.6, 3 do
		local p = center + toCamp * r
		if bedY(p.X, p.Z, deckY + 40) > lake.y + 0.3 then
			shore = p
			break
		end
	end
	local platform = center + toCamp * lake.radius * 0.2
	local start = Vector3.new(shore.X, bedY(shore.X, shore.Z, deckY + 40) + 0.3, shore.Z) + toCamp * 4
	-- rampa dalla spiaggia al piano della passerella
	local rampTop = Vector3.new(shore.X, deckY, shore.Z) - toCamp * 6
	walkway(folder, start, rampTop, 6)
	walkway(folder, rampTop, platform + toCamp * 17, 6)

	-- piattaforma centrale con falo' e panchine
	local pcf = CFrame.lookAt(platform, platform + toCamp)
	part(folder, "Piattaforma", Vector3.new(34, 0.8, 34), pcf, WOOD)
	for x = -15, 15, 10 do
		for z = -15, 15, 10 do
			stilt(folder, (pcf * CFrame.new(x, -0.4, z)).Position)
		end
	end
	local pit = part(folder, "Falo", Vector3.new(1.2, 5, 5), pcf * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(80, 78, 76), Enum.Material.Slate)
	;(pit :: Part).Shape = Enum.PartType.Cylinder
	CollectionService:AddTag(pit, "HeatSource")
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 9
	fire.Parent = pit
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 150, 70)
	glow.Range = 26
	glow.Brightness = 2.2
	glow.Shadows = true
	glow.Parent = pit
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local pos = platform + Vector3.new(math.cos(a) * 8, 0.4, math.sin(a) * 8)
		bench(folder, CFrame.lookAt(pos, Vector3.new(platform.X, pos.Y, platform.Z)) * CFrame.Angles(0, math.pi, 0))
	end
	for _, o in { Vector3.new(16, 0, 16), Vector3.new(-16, 0, 16), Vector3.new(16, 0, -16), Vector3.new(-16, 0, -16) } do
		lantern(folder, (pcf * CFrame.new(o)).Position + Vector3.new(0, 0.4, 0))
	end

	-- quattro palafitte attorno, collegate da passerelle
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4 + math.atan2(toCamp.Z, toCamp.X)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local hc = platform + dir * 44
		-- solo dove c'e' ancora acqua sotto (non sulla spiaggia)
		if bedY(hc.X, hc.Z, deckY + 40) < lake.y - 1 then
			hut(folder, hc, -dir)
			walkway(folder, platform + dir * 17, hc - dir * 8, 4)
		end
	end

	-- molo con la barca, dalla parte opposta alla riva
	local dockStart = platform - toCamp * 17
	local dockEnd = dockStart - toCamp * 22
	walkway(folder, dockStart, dockEnd, 4)
	lantern(folder, dockEnd + Vector3.new(0, 0.3, 0))
	local side = toCamp:Cross(Vector3.yAxis).Unit
	local boatCf = CFrame.lookAt(dockEnd + side * 6 - Vector3.new(0, 3.2, 0), dockEnd + side * 6 - Vector3.new(0, 3.2, 0) - toCamp)
	local boat = Instance.new("Model")
	boat.Name = "Barca"
	boat.Parent = folder
	part(boat, "Fondo", Vector3.new(4, 0.6, 12), boatCf, WOOD_DARK, Enum.Material.Wood)
	for _, sgn in { -1, 1 } do
		part(boat, "Fianco", Vector3.new(0.5, 1.6, 12), boatCf * CFrame.new(sgn * 2, 0.8, 0), WOOD, Enum.Material.Wood)
	end
	part(boat, "Prua", Vector3.new(4, 1.6, 2), boatCf * CFrame.new(0, 0.8, -6.5), WOOD, Enum.Material.Wood, "WedgePart")
	local oarSeat = part(boat, "Sedile", Vector3.new(3.5, 0.4, 1.4), boatCf * CFrame.new(0, 1, 1), WOOD, Enum.Material.Wood, "Seat")
	oarSeat.CanCollide = true

	folder.Parent = workspace
	map.features.lakeside = { x = platform.X, y = deckY, z = platform.Z }
	print(string.format("[MapGen] Palafitte sul lago (livello %.0f)", lake.y))
end

return Lakeside
