--!strict
-- Valle dei gas tossici (zona del drago Gas), dopo che il terreno e' stato scritto. Colori del
-- drago Gas: blu, azzurro e fucsia.
--   * fumarole: monticelli di roccia con il buco in cima che sputa gas azzurro e fucsia, una luce
--     colorata e attorno una crosta che brilla (CrackedLava, colore in Environment)
--   * nebbia bassa che riempie il fondo della conca
--   * cartello di pericolo al varco d'ingresso
--   * punti per le uova del drago Gas (MapMarkers.GasZone) e attributi del Workspace con la zona
--     (GasCenter, GasRadius, GasTop): li usano server/ToxicGas (danno) e client/GasFX (aspetto)

local Heightmap = require(script.Parent.Heightmap)

local Toxic = {}

local CYAN = Color3.fromRGB(90, 220, 255)
local BLUE = Color3.fromRGB(60, 90, 230)
local PINK = Color3.fromRGB(240, 80, 220)
local VIOLET = Color3.fromRGB(140, 70, 210)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function ground(x: number, z: number, fromY: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -400, 0), terrainOnly)
end

local function anchor(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- gas che esce da una fumarola: parte azzurro (o fucsia), sale, si allarga e vira al viola
local function plume(parent: Part, first: Color3, second: Color3)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, first),
		ColorSequenceKeypoint.new(0.5, second),
		ColorSequenceKeypoint.new(1, VIOLET),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 24) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(6, 9)
	e.Rate = 6
	e.Speed = NumberRange.new(3, 6)
	e.SpreadAngle = Vector2.new(14, 14)
	e.Acceleration = Vector3.new(0.4, 0.6, 0.3)
	e.RotSpeed = NumberRange.new(-12, 12)
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = 0.25
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
end

-- nebbia bassa: grandi sbuffi lenti dentro un volume sopra il fondo
local function haze(parent: Part)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CYAN),
		ColorSequenceKeypoint.new(0.5, PINK),
		ColorSequenceKeypoint.new(1, BLUE),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 22), NumberSequenceKeypoint.new(1, 40) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.62), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(10, 15)
	e.Rate = 9
	e.Speed = NumberRange.new(0.3, 1)
	e.RotSpeed = NumberRange.new(-6, 6)
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = 0.15
	e.Parent = parent
end

local function sign(parent: Instance, at: Vector3, center: Vector3)
	local look = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z))
	local WOOD = Color3.fromRGB(70, 52, 40)
	for _, x in { -2.6, 2.6 } do
		local post = Instance.new("Part")
		post.Name = "PaloCartello"
		post.Anchored = true
		post.Size = Vector3.new(0.6, 7, 0.6)
		post.CFrame = look * CFrame.new(x, 3.5, 0)
		post.Material = Enum.Material.Wood
		post.Color = WOOD
		post.Parent = parent
	end
	local board = Instance.new("Part")
	board.Name = "Cartello"
	board.Anchored = true
	board.Size = Vector3.new(7, 3, 0.3)
	board.CFrame = look * CFrame.new(0, 5.6, 0)
	board.Material = Enum.Material.WoodPlanks
	board.Color = WOOD
	board.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.fromRGB(255, 150, 240)
	label.Text = "DANGER · TOXIC GAS\n<font size=\"20\">Only a Gas dragon can breathe in this valley</font>"
	label.Parent = gui
end

function Toxic.build(map: Heightmap.Map)
	local old = workspace:FindFirstChild("ValleGas")
	if old then
		old:Destroy()
	end
	local t = map.features.toxic
	if not t then
		return
	end
	local T = map.cfg.TOXIC
	local terrain = workspace.Terrain
	local rng = Random.new(map.cfg.SEED + 313)
	local folder = Instance.new("Folder")
	folder.Name = "ValleGas"
	local center = Vector3.new(t.x, t.y, t.z)

	-- fumarole sparse sul fondo, mai troppo vicine
	local vents: { Vector3 } = {}
	local tries = 0
	while #vents < T.VENTS and tries < 200 do
		tries += 1
		local a, r = rng:NextNumber(0, 2 * math.pi), t.radius * math.sqrt(rng:NextNumber(0.02, 1)) * 0.55
		local x, z = t.x + math.cos(a) * r, t.z + math.sin(a) * r
		local far = true
		for _, v in vents do
			if (Vector2.new(v.X, v.Z) - Vector2.new(x, z)).Magnitude < 30 then
				far = false
			end
		end
		local hit = far and ground(x, z, t.top + 100)
		if hit and hit.Normal.Y > 0.8 then
			table.insert(vents, hit.Position)
		end
	end
	for k, p in vents do
		-- crosta che brilla attorno, monticello di roccia, buco in cima
		terrain:FillCylinder(CFrame.new(p - Vector3.new(0, 2, 0)), 6, rng:NextNumber(8, 12), Enum.Material.CrackedLava)
		terrain:FillBall(p - Vector3.new(0, 2.5, 0), rng:NextNumber(6, 7.5), Enum.Material.Asphalt)
		terrain:FillBall(p + Vector3.new(0, 4.5, 0), 4, Enum.Material.Air)
		local vent = anchor(folder, "Fumarola", Vector3.new(3, 1, 3), CFrame.new(p + Vector3.new(0, 3, 0)))
		local pink = k % 2 == 0
		plume(vent, if pink then PINK else CYAN, if pink then VIOLET else BLUE)
		local light = Instance.new("PointLight")
		light.Color = if pink then PINK else CYAN
		light.Brightness = 1.6
		light.Range = 24
		light.Shadows = false
		light.Parent = vent
	end

	-- nebbia sul fondo
	for k = 0, 2 do
		local a = k / 3 * 2 * math.pi
		local p = center + Vector3.new(math.cos(a) * t.radius * 0.3, 7, math.sin(a) * t.radius * 0.3)
		haze(anchor(folder, "Nebbia", Vector3.new(t.radius * 0.8, 8, t.radius * 0.8), CFrame.new(p)))
	end

	-- cartello al varco, un po' fuori dall'orlo
	local b = t.breach
	local sx, sz = t.x + math.cos(b) * t.radius * 1.12, t.z + math.sin(b) * t.radius * 1.12
	local at = ground(sx, sz, t.top + 200)
	if at then
		sign(folder, at.Position, center)
	end

	-- punti per le uova del drago Gas, vicino alle fumarole
	local markers = workspace:FindFirstChild("MapMarkers")
	if markers then
		local spots = Instance.new("Folder")
		spots.Name = "GasZone"
		for k, p in vents do
			local a = rng:NextNumber(0, 2 * math.pi)
			local hit = ground(p.X + math.cos(a) * 14, p.Z + math.sin(a) * 14, t.top + 100)
			if hit then
				local m = anchor(spots, "GasSpot" .. k, Vector3.new(4, 4, 4), CFrame.new(hit.Position + Vector3.new(0, 2, 0)))
				m:SetAttribute("Kind", "GasSpot")
			end
		end
		spots.Parent = markers
	end

	-- la zona per il danno (server) e la nebbia colorata (client): gli attributi del Workspace
	-- arrivano sempre al client, anche con lo streaming
	workspace:SetAttribute("GasCenter", center)
	workspace:SetAttribute("GasRadius", t.radius)
	workspace:SetAttribute("GasTop", t.top + 15)
	folder.Parent = workspace
	print(string.format("[MapGen] Valle dei gas: centro (%d, %d, %d), raggio %d, %d fumarole", t.x, t.y, t.z, t.radius, #vents))
end

return Toxic
