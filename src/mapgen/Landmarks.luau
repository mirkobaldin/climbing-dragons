--!strict
-- Scheletro di drago gigante:
--   * teschio enorme (DRAGON.SKULL_LENGTH) sul varco ovest della valle, a bocca aperta verso
--     l'interno: e' l'ingresso dell'isola, si passa sotto il cranio tra le due mandibole
--   * costato (costole + spina dorsale) dietro al teschio, dentro la valle
-- Modelli: se in ServerStorage c'e' un Model "DragonSkull", o un Model con dentro una
-- MeshPart con "Skull" nel nome (e la mandibola con "Jaw"), usa quello; altrimenti un teschio
-- a blocchi ingrandito. "DragonRibs" sostituisce il costato (pivot a terra, muso verso -Z).

local ServerStorage = game:GetService("ServerStorage")
local Heightmap = require(script.Parent.Heightmap)

local abs = math.abs

local Landmarks = {}

local BONE = Color3.fromRGB(221, 211, 188)
local BONE_DARK = Color3.fromRGB(170, 158, 134)
local SOCKET = Color3.fromRGB(28, 22, 20)

local function newPart(parent: Instance, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Material = Enum.Material.Limestone
	p.Color = color or BONE
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function newWedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3?): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Material = Enum.Material.Limestone
	w.Color = color or BONE
	w.Parent = parent
	return w
end

-- Osso cilindrico tra due punti, con nodo sferico all'estremita'
local function bone(parent: Instance, a: Vector3, b: Vector3, thick: number)
	local length = (b - a).Magnitude
	newPart(
		parent,
		Enum.PartType.Cylinder,
		Vector3.new(length + thick * 0.4, thick, thick),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	)
	newPart(parent, Enum.PartType.Ball, Vector3.one * thick * 1.25, CFrame.new(b), BONE_DARK)
end

local function useTemplate(name: string, pivot: CFrame, parent: Instance): boolean
	local template = ServerStorage:FindFirstChild(name)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		clone:PivotTo(pivot)
		clone.Parent = parent
		return true
	end
	return false
end

-- Costato: centro a terra, "forward" = direzione della spina dorsale
local function buildRibcage(map: Heightmap.Map, parent: Instance, center: Vector3, forward: Vector3)
	local pivot = CFrame.lookAt(center, center + forward)
	if useTemplate("DragonRibs", pivot, parent) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "DragonRibs"
	model.Parent = parent
	local right = forward:Cross(Vector3.yAxis).Unit
	local LENGTH, TOP, WIDTH = 130, 34, 26

	-- Spina dorsale con vertebre e spine
	local spinePts = {}
	for k = 0, 10 do
		local u = k / 10 - 0.5
		local p = center + forward * (u * LENGTH) + Vector3.new(0, TOP * (1 - u * u * 0.6), 0)
		table.insert(spinePts, p)
		newPart(model, Enum.PartType.Ball, Vector3.one * 5, CFrame.new(p), BONE_DARK)
		newWedge(model, Vector3.new(1.5, 6 - abs(u) * 6, 5), CFrame.lookAt(p + Vector3.new(0, 4, 0), p + Vector3.new(0, 4, 0) - forward))
	end
	for k = 1, #spinePts - 1 do
		bone(model, spinePts[k], spinePts[k + 1], 3.2)
	end

	-- Coppie di costole ad arco, piu' alte al centro
	for r = 0, 6 do
		local u = r / 6 - 0.5
		local along = u * LENGTH * 0.85
		local h = TOP * (1 - u * u * 0.6)
		local w = WIDTH * (1 - u * u * 0.5)
		for _, side in { -1, 1 } do
			local prev: Vector3? = nil
			for s = 0, 6 do
				local a = 0.12 + (s / 6) * (math.pi / 2 + 0.1)
				local base = center + forward * (along - s * 1.2)
				local p = base + right * (side * w * math.sin(a)) + Vector3.new(0, h * math.cos(a), 0)
				if s == 6 then
					-- l'estremita' affonda nel terreno reale
					local ground = Heightmap.sampleH(map, p.X, p.Z)
					p = Vector3.new(p.X, ground - 3, p.Z)
				end
				if prev then
					bone(model, prev, p, 2.8 - s * 0.15)
				end
				prev = p
			end
		end
	end
end

-- Teschio: "floor" = pavimento della bocca, "outward" = verso cui guarda il muso
local function buildSkull(parent: Instance, floor: Vector3, outward: Vector3): Model
	local cf = CFrame.lookAt(floor, floor + outward) -- muso verso -Z locale
	local model = Instance.new("Model")
	model.Name = "DragonSkull"
	model.Parent = parent
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	-- Cranio, cupola e arcata sopraccigliare
	newPart(model, nil, Vector3.new(34, 20, 36), at(0, 26, 4))
	newPart(model, Enum.PartType.Ball, Vector3.one * 30, at(0, 30, 8))
	newPart(model, nil, Vector3.new(38, 6, 10), at(0, 31, -12) * CFrame.Angles(0.15, 0, 0), BONE_DARK)
	-- Muso
	newPart(model, nil, Vector3.new(24, 9, 36), at(0, 18.5, -32))
	newWedge(model, Vector3.new(24, 9, 34), at(0, 27.5, -31))
	for _, side in { -1, 1 } do
		-- Orbite con occhi rossi luminosi
		newPart(model, Enum.PartType.Ball, Vector3.one * 10, at(side * 12, 27, -16), SOCKET).Material = Enum.Material.Slate
		local eye = newPart(model, Enum.PartType.Ball, Vector3.one * 3.5, at(side * 12, 27, -19.5), Color3.fromRGB(255, 40, 20))
		eye.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 60, 30)
		light.Range = 24
		light.Brightness = 2
		light.Parent = eye
		-- Narici
		newPart(model, Enum.PartType.Ball, Vector3.one * 4, at(side * 5, 22, -48), SOCKET)
		-- Denti superiori (verso il basso) e zanne
		for z = -46, -18, 4.5 do
			newWedge(model, Vector3.new(1.6, 5, 3), at(side * 10.5, 11.5, z) * CFrame.Angles(math.pi, 0, 0))
		end
		newWedge(model, Vector3.new(2.2, 9, 3.5), at(side * 6, 9.5, -48) * CFrame.Angles(math.pi, 0, 0))
		-- Mandibola appoggiata a terra con denti verso l'alto
		newPart(model, nil, Vector3.new(4, 5, 52), at(side * 13, 2.5, -24) * CFrame.Angles(0, side * 0.08, 0))
		for z = -44, -10, 5 do
			newWedge(model, Vector3.new(1.6, 4, 3), at(side * 12.5, 7, z))
		end
		-- Corna curve all'indietro
		local horn = {
			at(side * 14, 34, 12).Position,
			at(side * 20, 44, 28).Position,
			at(side * 22, 50, 46).Position,
			at(side * 20, 52, 62).Position,
		}
		for k = 1, 3 do
			bone(model, horn[k], horn[k + 1], 6.5 - k * 1.5)
		end
	end
	model.WorldPivot = cf
	return model
end

-- Modello 3D del teschio messo dall'utente in ServerStorage
local SKULL_WORDS = { "skull", "cranio", "teschio" }
local JAW_WORDS = { "jaw", "mandibola", "mascella" }
local function nameHas(name: string, words: { string }): boolean
	local lower = string.lower(name)
	for _, w in words do
		if string.find(lower, w, 1, true) then
			return true
		end
	end
	return false
end

local function findSkullTemplate(): Model?
	local named = ServerStorage:FindFirstChild("DragonSkull")
	if named and named:IsA("Model") then
		return named
	end
	for _, d in ServerStorage:GetDescendants() do
		if d:IsA("MeshPart") and nameHas(d.Name, SKULL_WORDS) then
			local m = d.Parent
			if m and m:IsA("Model") then
				return m
			end
		end
	end
	return nil
end

-- Teschio dal modello: lo lascia com'e' l'hai composto (cranio + mandibola attaccati), capisce
-- da che parte e' il muso (asse piu' lungo del cranio), lo ingrandisce e lo appoggia a terra.
-- Se il muso esce girato: DRAGON.SKULL_YAW in Config o attributo "Yaw" (gradi) sul modello.
local function skullFromTemplate(template: Model, cfg: any): Model?
	local model = template:Clone()
	local skull: BasePart? = nil
	local parts: { BasePart } = {}
	-- L'export da Blender porta dentro anche quello che c'era nella scena: il cubo di default,
	-- il fondale, le luci, la camera. Se qualche pezzo si chiama cranio/mandibola teniamo solo
	-- quelli, altrimenti si finirebbe con una cassa gigante piantata davanti all'isola.
	local wanted: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (nameHas(d.Name, SKULL_WORDS) or nameHas(d.Name, JAW_WORDS)) then
			table.insert(wanted, d)
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Light") or d:IsA("Camera") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			if #wanted > 0 and not (nameHas(d.Name, SKULL_WORDS) or nameHas(d.Name, JAW_WORDS)) then
				d:Destroy()
				continue
			end
			-- solo la parte superiore: senza mandibola i denti toccano terra e la bocca aperta
			-- diventa l'arco d'ingresso sotto cui si passa
			if cfg.DRAGON.JAW == false and nameHas(d.Name, JAW_WORDS) then
				d:Destroy()
				continue
			end
			d.Anchored = true
			table.insert(parts, d)
			if not nameHas(d.Name, JAW_WORDS) and (not skull or d.Size.Magnitude > (skull :: BasePart).Size.Magnitude) then
				skull = d
			end
		end
	end
	if not skull then
		model:Destroy()
		return nil
	end
	-- Il modello arriva senza texture se le PNG non erano accanto al FBX: gli diamo comunque
	-- un aspetto d'osso antico, cosi' non resta grigio plastica.
	for _, d in parts do
		-- con le sue texture (SurfaceAppearance) il colore e il materiale non vanno toccati
		if d:FindFirstChildOfClass("SurfaceAppearance") then
			continue
		end
		if d.Color == Color3.new(1, 1, 1) or d.Color == Color3.fromRGB(163, 162, 165) then
			d.Color = Color3.fromRGB(196, 182, 152)
			d.Material = Enum.Material.Sandstone
		end
	end
	local sk = skull :: BasePart
	local s = sk.Size
	local axis = if s.X >= s.Z then sk.CFrame.RightVector else sk.CFrame.LookVector
	axis = Vector3.new(axis.X, 0, axis.Z).Unit
	local length = math.max(s.X, s.Z)
	local yaw = cfg.DRAGON.SKULL_YAW + ((template:GetAttribute("Yaw") or 0) :: number)
	axis = CFrame.Angles(0, math.rad(yaw), 0):VectorToWorldSpace(axis)

	-- pivot a terra sotto il centro, con -Z verso il muso
	local minY = math.huge
	local center = Vector3.zero
	for _, p in parts do
		minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
		center += p.Position
	end
	center /= #parts
	local base = Vector3.new(center.X, minY, center.Z)
	model.WorldPivot = CFrame.lookAt(base, base + axis)
	model:ScaleTo(model:GetScale() * cfg.DRAGON.SKULL_LENGTH / length)

	-- collisioni precise (si passa sotto il cranio); se Studio non lo permette, niente collisioni
	for _, p in parts do
		if p:IsA("MeshPart") then
			local ok = pcall(function()
				(p :: any).CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
			end)
			if not ok then
				p.CanCollide = false
			end
		end
	end
	return model
end

-- Il cerchio di pietre del modello (stile Stonehenge) al posto dei monoliti a blocchi: largo
-- quanto il cerchio (diametro 2 * (ring + 3.5)), appena affondato nel terreno, senza script
local function hengeModel(folder: Instance, floor: Vector3, ring: number): boolean
	local template: Instance? = nil
	for _, d in ServerStorage:GetDescendants() do
		local n = string.lower(d.Name)
		if d:IsA("Model") and (string.find(n, "henge") or string.find(n, "cerchio")) and not d:FindFirstAncestor("Cestino") then
			template = d
			break
		end
	end
	if not template then
		return false
	end
	local model = (template :: Model):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- i modelli della Toolbox a volte hanno virus
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * 2 * (ring + 3.5) / math.max(size.X, size.Z, 1))
	local cf, s2 = model:GetBoundingBox()
	-- il fondo del modello sul pavimento, mezzo stud sotto
	local offset = model:GetPivot().Position - cf.Position
	local bottom = Vector3.new(floor.X, floor.Y - 0.5 + s2.Y / 2, floor.Z)
	model:PivotTo(CFrame.new(bottom + offset) * model:GetPivot().Rotation)
	model.Name = "CerchioDiPietre"
	model.Parent = folder
	return true
end

-- Santuario: cerchio di pietre come Stonehenge (monoliti, un architrave su ogni coppia), pentacolo
-- di luce a terra inscritto in un cerchio e altare a dolmen al centro (due pietre in piedi e una
-- lastra, che si chiama altarName: Eggs ci mette sopra l'uovo leggendario). Usato nella camera
-- del tesoro e in vetta.
local function sanctuary(folder: Instance, floor: Vector3, ring: number, star: number, glowColor: Color3, altarName: string, rng: Random): Part
	local STONE = Color3.fromRGB(118, 112, 104)
	-- la quota della heightmap non e' la superficie dei voxel (sta un paio di studs sotto): si
	-- appoggia tutto sul terreno vero, se no il pentacolo resta sepolto
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(floor + Vector3.new(0, 15, 0), Vector3.new(0, -30, 0), terrainOnly)
	if hit then
		floor = Vector3.new(floor.X, hit.Position.Y, floor.Z)
	end
	-- dentro il cerchio pavimento di pietra: l'erba nascondeva il pentacolo
	local paved = ring + 4
	for gx = -paved, paved, 4 do
		for gz = -paved, paved, 4 do
			if gx * gx + gz * gz <= paved * paved then
				local c = floor + Vector3.new(gx, 0, gz)
				local region = Region3.new(c - Vector3.new(2, 8, 2), c + Vector3.new(2, 4, 2)):ExpandToGrid(4)
				for _, m in { Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Ground, Enum.Material.Snow, Enum.Material.Mud } do
					workspace.Terrain:ReplaceMaterial(region, 4, m, Enum.Material.Slate)
				end
			end
		end
	end
	local function stone(size: Vector3, cf: CFrame): Part
		local p = newPart(folder, nil, size, cf, STONE)
		p.Material = Enum.Material.Slate
		return p
	end
	-- cerchio di pietre: il modello di Mirko (ServerStorage, nome con "henge" o "cerchio"), se
	-- c'e'; altrimenti monoliti a blocchi piantati un po' nel terreno
	if not hengeModel(folder, floor, ring) then
	local STONES = 10
	local tops = {}
	for k = 0, STONES - 1 do
		local ang = k / STONES * 2 * math.pi
		local p = floor + Vector3.new(math.cos(ang) * ring, 0, math.sin(ang) * ring)
		local hgt = 13 + rng:NextNumber(-1, 1.5)
		local look = CFrame.lookAt(p, Vector3.new(floor.X, p.Y, floor.Z))
		stone(Vector3.new(4.5, hgt + 3, 2.6), look * CFrame.new(0, hgt / 2 - 2, 0) * CFrame.Angles(rng:NextNumber(-0.03, 0.03), 0, rng:NextNumber(-0.04, 0.04)))
		tops[k + 1] = p + Vector3.new(0, hgt, 0)
	end
	-- architravi sulle coppie (uno si' e uno no, come i triliti)
	for k = 1, STONES, 2 do
		local p1, p2 = tops[k], tops[k % STONES + 1]
		local mid = (p1 + p2) / 2
		local len = (p2 - p1).Magnitude + 4
		stone(Vector3.new(len, 2.2, 2.8), CFrame.lookAt(mid, mid + (p2 - p1).Unit) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0.6, 0))
	end
	end
	-- pentacolo di luce: cerchio e stella a cinque punte, appena sopra il pavimento
	local function glowLine(p1: Vector3, p2: Vector3, width: number)
		local mid = (p1 + p2) / 2
		local seg = newPart(folder, nil, Vector3.new(width, 0.25, (p2 - p1).Magnitude + width * 0.5), CFrame.lookAt(mid, p2), glowColor)
		seg.Material = Enum.Material.Neon
		seg.CanCollide = false
	end
	local y = floor + Vector3.new(0, 0.15, 0)
	for k = 0, 39 do
		local a1, a2 = k / 40 * 2 * math.pi, (k + 1) / 40 * 2 * math.pi
		glowLine(y + Vector3.new(math.cos(a1) * star, 0, math.sin(a1) * star), y + Vector3.new(math.cos(a2) * star, 0, math.sin(a2) * star), 0.6)
	end
	local points = {}
	for k = 0, 4 do
		local ang = -math.pi / 2 + k / 5 * 2 * math.pi
		points[k + 1] = y + Vector3.new(math.cos(ang) * star * 0.96, 0, math.sin(ang) * star * 0.96)
	end
	for k = 1, 5 do
		glowLine(points[k], points[(k + 1) % 5 + 1], 0.7) -- ogni punta collegata alla seconda dopo: la stella
	end
	-- dolmen al centro: due pietre in piedi e la lastra con l'uovo
	stone(Vector3.new(2.4, 6, 5), CFrame.new(floor + Vector3.new(-3, 2, 0)))
	stone(Vector3.new(2.4, 6, 5), CFrame.new(floor + Vector3.new(3, 2, 0)))
	local altar = stone(Vector3.new(9, 1.4, 6), CFrame.new(floor + Vector3.new(0, 5.7, 0)) * CFrame.Angles(0, 0, 0.03))
	altar.Name = altarName
	altar.Material = Enum.Material.Basalt
	altar.Color = Color3.fromRGB(32, 28, 38)
	local glow = Instance.new("PointLight")
	glow.Color = glowColor
	glow.Range = 45
	glow.Brightness = 2.2
	glow.Parent = altar
	return altar
end

-- Camera del tesoro (scavata da Caves al centro della montagna), rotonda come un santuario:
--   * cerchio di pietre come Stonehenge: monoliti con un architrave su ogni coppia
--   * pentacolo di luce viola a terra, inscritto in un cerchio
--   * altare a dolmen al centro (due pietre in piedi e una lastra): ci sta l'uovo del drago Ombra
--     (lo mette Eggs sul blocco "AltareUovo")
--   * forzieri e mucchi d'oro fuori dal cerchio, cristalli viola lungo la parete
local function buildTreasure(map: Heightmap.Map, parent: Instance)
	local t = map.features.treasure
	if not t then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CameraDelTesoro"
	folder.Parent = parent
	local floor = Vector3.new(t.x, t.y, t.z)
	local R = t.radius
	local GOLD, WOOD = Color3.fromRGB(255, 196, 60), Color3.fromRGB(96, 62, 36)
	local VIOLET = Color3.fromRGB(150, 70, 255)
	local rng = Random.new(map.cfg.SEED + 7)
	sanctuary(folder, floor, R * 0.5, R * 0.32, VIOLET, "AltareUovo", rng)
	-- tesori fuori dal cerchio, cristalli lungo la parete
	for k = 1, 10 do
		local ang = k / 10 * 2 * math.pi + math.pi / 10
		local p = floor + Vector3.new(math.cos(ang) * R * 0.72, 0, math.sin(ang) * R * 0.72)
		local look = CFrame.lookAt(p, Vector3.new(floor.X, p.Y, floor.Z))
		if k % 2 == 0 then
			newPart(folder, nil, Vector3.new(5, 3, 3.4), look * CFrame.new(0, 1.5, 0), WOOD).Material = Enum.Material.WoodPlanks
			newPart(folder, nil, Vector3.new(5, 0.6, 3.4), look * CFrame.new(0, 3.6, 1.6) * CFrame.Angles(-1.1, 0, 0), WOOD).Material = Enum.Material.WoodPlanks
			newPart(folder, nil, Vector3.new(4.4, 0.8, 2.8), look * CFrame.new(0, 3.1, 0), GOLD).Material = Enum.Material.Foil
		else
			for _ = 1, 6 do
				local o = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
				newPart(folder, Enum.PartType.Cylinder, Vector3.new(0.3, 1.6, 1.6), CFrame.new(p + o + Vector3.new(0, rng:NextNumber(0.2, 1.4), 0)) * CFrame.Angles(0, 0, math.pi / 2 + rng:NextNumber(-0.4, 0.4)), GOLD).Material = Enum.Material.Foil
			end
			newPart(folder, Enum.PartType.Ball, Vector3.new(6, 2.5, 6), CFrame.new(p + Vector3.new(0, 0.6, 0)), GOLD).Material = Enum.Material.Foil
		end
		local cp = floor + Vector3.new(math.cos(ang + 0.3) * R * 0.9, 4, math.sin(ang + 0.3) * R * 0.9)
		local crystal = newPart(folder, nil, Vector3.new(2.5, rng:NextNumber(7, 13), 2.5), CFrame.new(cp) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), VIOLET)
		crystal.Material = Enum.Material.Neon
		crystal.Transparency = 0.2
	end
end

-- Santuario della vetta: lo stesso cerchio di pietre col pentacolo, ma di luce dorata; sull'altare
-- "AltareVetta" Eggs mette l'uovo leggendario della vetta (DragonConfig.SUMMIT_EGG)
local function buildSummit(map: Heightmap.Map, parent: Instance)
	local s = map.features.summit
	if not s then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SantuarioVetta"
	folder.Parent = parent
	local R = s.radius or 34
	sanctuary(folder, Vector3.new(s.x, s.y, s.z), R * 0.62, R * 0.4, Color3.fromRGB(255, 176, 50), "AltareVetta", Random.new(map.cfg.SEED + 11))
end

function Landmarks.build(map: Heightmap.Map)
	local old = workspace:FindFirstChild("Landmarks")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Landmarks"
	folder.Parent = workspace

	local HUB = map.cfg.HUB
	buildTreasure(map, folder)
	buildSummit(map, folder)

	-- Ingresso della grotta sulla montagna: piazzola di terra davanti e imbocco libero
	local e = map.features.caveEntrance
	if e then
		local outward = Vector3.new(e.dirX, 0, e.dirZ)
		local floor = Vector3.new(e.x, e.floor, e.z) + outward * 6
		local cf = CFrame.lookAt(floor, floor + outward)
		workspace.Terrain:FillBlock(cf * CFrame.new(0, -15, -24), Vector3.new(46, 30, 60), Enum.Material.Ground)
		workspace.Terrain:FillBlock(cf * CFrame.new(0, 8, -22), Vector3.new(20, 16, 48), Enum.Material.Air)
	end

	-- Teschio gigante sul varco della valle verso il mare, con la bocca rivolta dentro la
	-- valle (tutta sull'isola): chi arriva dal mare entra passando sotto il cranio
	local cfg = map.cfg
	local toSea, best = math.pi, math.huge
	local toMountain = math.atan2(cfg.MOUNTAIN.Z - HUB.Z, cfg.MOUNTAIN.X - HUB.X)
	for _, gate in HUB.WALL.GATES do
		-- il varco piu' lontano dalla direzione della montagna
		local da = -abs((gate.ANGLE - toMountain + math.pi) % (2 * math.pi) - math.pi)
		if da < best then
			toSea, best = gate.ANGLE, da
		end
	end
	local outward = Vector3.new(math.cos(toSea), 0, math.sin(toSea))
	local gate = Vector3.new(HUB.X, 0, HUB.Z) + outward * (HUB.WALL.RADIUS + HUB.WALL.WIDTH * 0.3)
	local L = cfg.DRAGON.SKULL_LENGTH
	local inward = -outward
	local spot = gate + outward * (L * 0.2)
	-- appoggiato al fondo della valle (dentro il varco), appena affondato nel terreno
	local floorY = math.max(cfg.WATER_LEVEL + 2, Heightmap.sampleH(map, gate.X, gate.Z), Heightmap.sampleH(map, spot.X, spot.Z)) - L * 0.02
	local target = CFrame.lookAt(Vector3.new(spot.X, floorY, spot.Z), Vector3.new(spot.X, floorY, spot.Z) + inward)
	local template = findSkullTemplate()
	local skull = if template then skullFromTemplate(template, cfg) else nil
	if not skull then
		-- teschio a blocchi (lungo circa 110 studs) ingrandito fino a L
		local built = buildSkull(folder, Vector3.zero, Vector3.new(0, 0, -1))
		built:ScaleTo(L / 110)
		skull = built
	end
	local sk = skull :: Model
	sk.Name = "DragonSkull"
	sk:PivotTo(target)
	sk.Parent = folder
	map.features.dragonSkull = { x = spot.X, y = floorY, z = spot.Z }

	-- Costato dietro il teschio: il corpo del drago continua dalla nuca verso il mare. Il modello
	-- "DragonRibs" (ServerStorage) e' scalato in proporzione al teschio (DRAGON.RIBS_LENGTH);
	-- la spina dorsale e' il lato piu' lungo del modello e il suo -Z guarda verso la testa.
	local ribsTemplate = ServerStorage:FindFirstChild("DragonRibs")
	if ribsTemplate and ribsTemplate:IsA("Model") then
		local ribs = ribsTemplate:Clone()
		local _, size = ribs:GetBoundingBox()
		local length = L * (cfg.DRAGON.RIBS_LENGTH or 0.7)
		ribs:ScaleTo(ribs:GetScale() * length / math.max(size.X, size.Z, 1))
		local _, s2 = ribs:GetBoundingBox()
		local c = spot + outward * (L * 0.45 + math.max(s2.X, s2.Z) * 0.5)
		local facing = inward
		-- scelto a mano: una Part "PuntoCostole" in Workspace (la testa verso il suo davanti).
		-- Resta li' (invisibile) cosi' a ogni rigenerazione le costole tornano nello stesso posto
		local manual = workspace:FindFirstChild("PuntoCostole")
		if manual and manual:IsA("BasePart") then
			c = manual.Position
			local look = manual.CFrame.LookVector
			facing = if Vector3.new(look.X, 0, look.Z).Magnitude > 0.1 then Vector3.new(look.X, 0, look.Z).Unit else inward
			manual.Transparency = 1
			manual.CanCollide = false
			manual.CanQuery = false
			manual.Anchored = true
		end
		local y = math.max(cfg.WATER_LEVEL, Heightmap.sampleH(map, c.X, c.Z)) - s2.Y * 0.06 -- un po' sepolto
		local at = Vector3.new(c.X, y, c.Z)
		ribs:PivotTo(CFrame.lookAt(at, at + facing))
		ribs.Name = "DragonRibs"
		ribs.Parent = folder
	else
		local c = spot + outward * (L * 0.8)
		buildRibcage(map, folder, Vector3.new(c.X, Heightmap.sampleH(map, c.X, c.Z), c.Z), inward)
	end
end

return Landmarks
