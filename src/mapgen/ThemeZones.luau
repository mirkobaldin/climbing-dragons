--!strict
-- Zone a tema sulla montagna, una per drago, con i colori del drago:
--   Roccia    Canyon delle Frane     (piedi della montagna) torri di arenaria, cristalli d'ambra
--   Ossa      Cimitero dei Draghi    costole giganti, vertebre, nebbia verde pallido
--   Tempesta  Cresta della Tempesta  guglie grigio-blu, rocce sospese, fulmini (client)
--   Fulmine   Guglie del Fulmine Nero ossidiana nera con vene viola, scintille
--   Cosmico   Altopiano delle Stelle cristalli viola e magenta, sfere che fluttuano, stelle
--   Eclissi   Santuario dell'Eclissi anello nero e oro sospeso, obelischi, braci arancio
-- (Gelo = le grotte di ghiaccio, Gas = le valli tossiche: esistono gia'.)
-- Ogni zona: terreno ricolorato a chiazze, oggetti a tema fatti di parti, luci e particelle,
-- un altare-nido (MapMarkers.ThemeNests, attributo Element: li' nascono le uova di quel drago),
-- un cartello e gli attributi del Workspace ThemeZone<i>Center/Radius/Element (il client
-- cambia luce e colori quando ci entri, client/ThemeFX).

local Heightmap = require(script.Parent.Heightmap)

local ThemeZones = {}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local M = Enum.Material
local NATURAL = { M.Rock, M.Slate, M.Basalt, M.Ground, M.Grass, M.LeafyGrass, M.Mud, M.Limestone, M.Snow, M.Sand, M.Sandstone, M.Cobblestone, M.Glacier }
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function down(x: number, z: number, fromY: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -fromY - 100, 0), terrainOnly)
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
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function glow(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

local function particles(p: BasePart, color: Color3, texture: string, rate: number, size: number, speed: number, life: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = rate
	e.Parent = p
end

-- cristallo: solo il segnaposto (altezza e base); al suo posto va un cristallo-modello di Mirko
-- (i prismi fatti a blocchi non ci sono piu'). Restituisce un punto luce invisibile alla base.
local function crystal(parent: Instance, base: Vector3, h: number, tilt: Vector3, color: Color3, rng: Random, normal: Vector3?): Part
	local holder = Instance.new("Model")
	holder.Name = "Cristallo"
	holder:SetAttribute("Height", h)
	holder:SetAttribute("Base", base)
	holder:SetAttribute("Normal", normal or Vector3.yAxis) -- cresce perpendicolare alla roccia
	holder.Parent = parent
	local light = part(holder, "LuceCristallo", Vector3.one, CFrame.new(base + Vector3.new(0, h * 0.4, 0)), color, M.SmoothPlastic)
	light.Transparency = 1
	light.CanCollide = false
	local _ = tilt
	local _ = rng
	return light
end

-- guglia: pila di blocchi che si stringono salendo
local function spire(parent: Instance, base: Vector3, h: number, w: number, color: Color3, material: Enum.Material, rng: Random): Part
	local n = 4
	local top: Part? = nil
	for k = 0, n - 1 do
		local f = 1 - k / n
		local seg = h / n
		local cf = CFrame.new(base + Vector3.new(rng:NextNumber(-0.6, 0.6) * k, seg * (k + 0.5) - 1, rng:NextNumber(-0.6, 0.6) * k)) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(0, 6.28), rng:NextNumber(-0.06, 0.06))
		top = part(parent, "Guglia", Vector3.new(w * f, seg + 0.5, w * f), cf, color, material)
	end
	return top :: Part
end

-- costola: arco di cilindri dal suolo verso l'alto e poi giu' verso il centro della zona
local function rib(parent: Instance, base: Vector3, toward: Vector3, h: number, color: Color3)
	local dir = Vector3.new(toward.X, 0, toward.Z).Unit
	local prev = base - Vector3.new(0, 2, 0)
	for k = 1, 9 do
		local t = k / 9
		local p = base + dir * (h * 0.55 * t) + Vector3.new(0, h * math.sin(t * math.pi * 0.85), 0)
		local len = (p - prev).Magnitude
		local r = h * 0.07 * (1 - t * 0.55)
		part(parent, "Costola", Vector3.new(len + r, r * 2, r * 2), CFrame.lookAt((p + prev) / 2, p) * CFrame.Angles(0, math.pi / 2, 0), color, M.Limestone, Enum.PartType.Cylinder)
		prev = p
	end
end

local function sign(parent: Instance, at: Vector3, center: Vector3, title: string, sub: string, color: Color3)
	local look = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z))
	local STONE = Color3.fromRGB(60, 56, 62)
	part(parent, "Stele", Vector3.new(7.5, 9, 1.2), look * CFrame.new(0, 4, 0), STONE, M.Slate)
	local board = part(parent, "Cartello", Vector3.new(6.6, 4, 0.2), look * CFrame.new(0, 5.6, -0.7), STONE, M.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = color
	label.Text = title .. "\n<font size=\"18\">" .. sub .. "</font>"
	label.Parent = gui
end

-- altare-nido: pietra rotonda con l'anello del colore del drago; il marcatore per le uova sopra
-- modello di Mirko (ServerStorage.Modelli e sottocartelle) alto h, base in "at"
local function userModel(name: string, parent: Instance, at: Vector3, h: number, yaw: number): Model?
	local store = game:GetService("ServerStorage"):FindFirstChild("Modelli")
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
			d.CanCollide = false
		end
	end
	local _, s0 = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * h / math.max(s0.Y, 0.05))
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, yaw, 0))
	local box, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, at.Y - (box.Position.Y - s.Y / 2) - 0.3, 0))
	m.Parent = parent
	return m
end

local function nest(parent: Instance, markers: Instance?, at: Vector3, element: string, color: Color3, stone: Color3)
	-- il nido di Mirko dell'elemento (Modelli.Nidi.Nido_<Elemento>), se no l'altare a blocchi
	if not userModel("Nido_" .. element, parent, at, 7, 0) then
		part(parent, "Altare", Vector3.new(3, 12, 12), CFrame.new(at + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), stone, M.Slate, Enum.PartType.Cylinder)
	end
	local ring = part(parent, "AnelloAltare", Vector3.new(0.3, 15, 15), CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, M.Neon, Enum.PartType.Cylinder)
	ring.CanCollide = false
	ring.Transparency = 0.3
	glow(ring, color, 22, 1.5)
	if markers then
		local m = Instance.new("Part")
		m.Name = "Nido" .. element
		m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.Transparency = true, false, false, false, 1
		m.Size = Vector3.one
		m.Position = at + Vector3.new(0, 3, 0)
		m:SetAttribute("Element", element)
		m.Parent = markers
	end
end

-- i cristalli di Mirko in ServerStorage.Modelli per quell'elemento (maiuscole, spazi e "_"
-- non contano; "fulminenero" = Fulmine)
local ALIAS: { [string]: string } = { fulminenero = "fulmine" }
local function crystalModels(element: string): { Model }
	local out = {}
	local store = game:GetService("ServerStorage"):FindFirstChild("Modelli")
	local want = "cristallo" .. string.lower(element)
	for _, m in (if store then store:GetChildren() else {}) :: { Instance } do
		local n = string.lower((string.gsub(m.Name, "[%s_]", "")))
		for from, to in ALIAS do
			n = string.gsub(n, from, to)
		end
		if m:IsA("Model") and n == want then
			table.insert(out, m)
		end
	end
	return out
end

-- un cristallo-modello alto h appoggiato in base
local function placeModel(parent: Instance, tpl: Model, base: Vector3, h: number, rng: Random, normal: Vector3?, element: string?)
	local m = tpl:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false -- le mesh hanno la collisione a scatola: si inciampava nel vuoto
		end
	end
	local _, s0 = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * h / math.max(s0.Y, 0.05))
	-- forma diversa ogni volta: altezza e larghezza cambiano in modo indipendente (alti e sottili,
	-- bassi e larghi, schiacciati di lato...). Si deforma ogni parte nei suoi assi.
	local f = Vector3.new(rng:NextNumber(0.55, 1.5), rng:NextNumber(0.6, 2.3), rng:NextNumber(0.55, 1.5))
	m:PivotTo(CFrame.new())
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local rel = p.Position
			local localF = p.CFrame:VectorToObjectSpace(f)
			p.Size = p.Size * Vector3.new(math.abs(localF.X), math.abs(localF.Y), math.abs(localF.Z))
			p.Position = rel * f
		end
	end
	-- inclinato a caso, poi appoggiato con la base sulla roccia lungo la sua normale (sulle pareti
	-- delle grotte e sotto le isole crescono di lato o a testa in giu')
	local tilt = CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35))
	m:PivotTo(tilt)
	local box, s = m:GetBoundingBox()
	local lift = -(box.Position.Y - s.Y / 2) - s.Y * 0.12 -- un poco affondato
	local n = (normal or Vector3.yAxis).Unit
	local axis = Vector3.yAxis:Cross(n)
	local rot = if axis.Magnitude < 1e-3 then (if n.Y > 0 then CFrame.identity else CFrame.Angles(math.pi, 0, 0)) else CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(n.Y, -1, 1)))
	m:PivotTo(CFrame.new(base) * rot * CFrame.new(0, lift, 0) * tilt)
	m:SetAttribute("Base", base) -- per il controllo finale: deve poggiare sulla roccia
	m:SetAttribute("Normal", n)
	m:SetAttribute("Element", element) -- per gli effetti sul client (client/CrystalFX)
	m.Name = "Cristallo"
	m.Parent = parent
end

------------------------------------------------------------------------------------------

type Zone = { center: Vector3, radius: number, rng: Random, folder: Instance, points: (number) -> { Vector3 } }

-- gli oggetti di ogni tema
local BUILD: { [string]: (Zone, any) -> () } = {}

BUILD.Roccia = function(z, t)
	local AMBER = Color3.fromRGB(240, 190, 110)
	for _, p in z.points(16) do
		-- torri di arenaria (terreno: si scalano)
		local h = z.rng:NextNumber(25, 60)
		local w = z.rng:NextNumber(10, 18)
		for k = 0, 3 do
			workspace.Terrain:FillBlock(CFrame.new(p + Vector3.new(0, h * k / 4 + h / 8, 0)) * CFrame.Angles(0, z.rng:NextNumber(0, 6.28), 0), Vector3.new(w * (1 - k * 0.15), h / 4 + 2, w * (1 - k * 0.15)), if k % 2 == 0 then M.Sandstone else M.Rock)
		end
	end
	for _, p in z.points(22) do
		local c = crystal(z.folder, p, z.rng:NextNumber(3, 8), Vector3.new(z.rng:NextNumber(-0.4, 0.4), 0, z.rng:NextNumber(-0.4, 0.4)), AMBER, z.rng)
		if z.rng:NextNumber() < 0.4 then
			glow(c, AMBER, 16, 1.2)
		end
	end
	local _ = t
end

BUILD.Ossa = function(z, t)
	local BONE = Color3.fromRGB(226, 220, 200)
	local GREEN = Color3.fromRGB(190, 255, 210)
	-- lo scheletro di drago gigante di Mirko; se manca, costole fatte a cilindri
	local axis = Vector3.new(z.rng:NextNumber(-1, 1), 0, z.rng:NextNumber(-1, 1)).Unit
	local side = Vector3.new(-axis.Z, 0, axis.X)
	local skel = userModel("Scheletro_Drago_Gigante", z.folder, z.center, 30, z.rng:NextNumber(0, 6.28))
	for k = -4, if skel then -5 else 4 do
		for _, s in { -1, 1 } do
			local q = z.center + axis * k * 11 + side * s * 16
			local hit = down(q.X, q.Z, q.Y + 120)
			if hit then
				rib(z.folder, hit.Position, -side * s, 26 - math.abs(k) * 2, BONE)
			end
		end
		local v = z.center + axis * k * 11
		local hit = down(v.X, v.Z, v.Y + 120)
		if hit then
			part(z.folder, "Vertebra", Vector3.new(5, 6, 6), CFrame.new(hit.Position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), BONE, M.Limestone, Enum.PartType.Cylinder)
		end
	end
	-- ossa sparse e fuochi fatui verdi
	for _, p in z.points(26) do
		part(z.folder, "Osso", Vector3.new(z.rng:NextNumber(6, 14), 1.6, 1.6), CFrame.new(p + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, z.rng:NextNumber(0, 6.28), z.rng:NextNumber(-0.2, 0.2)), BONE, M.Limestone, Enum.PartType.Cylinder)
	end
	for _, p in z.points(8) do
		local wisp = part(z.folder, "FuocoFatuo", Vector3.one, CFrame.new(p + Vector3.new(0, 4, 0)), GREEN, M.Neon, Enum.PartType.Ball)
		wisp.CanCollide = false
		glow(wisp, GREEN, 18, 1.5)
		particles(wisp, GREEN, SMOKE, 4, 4, 1, 4)
	end
	local _ = t
end

-- Tempesta e Fulmine Nero: le isole volanti le fa shapeZone; qui solo vento, nuvole basse e
-- scintille (niente guglie o prismi: sembravano i vecchi cristalli)
BUILD.Tempesta = function(z, t)
	for _, p in z.points(8) do
		local a = part(z.folder, "Vento", Vector3.one, CFrame.new(p + Vector3.new(0, z.rng:NextNumber(10, 30), 0)), t.COLOR, M.SmoothPlastic)
		a.Transparency, a.CanCollide, a.CanQuery = 1, false, false
		particles(a, Color3.fromRGB(200, 215, 235), SMOKE, 3, 6, 6, 3)
	end
end

BUILD.Fulmine = function(z, t)
	for _, p in z.points(8) do
		local a = part(z.folder, "Scintille", Vector3.one, CFrame.new(p + Vector3.new(0, z.rng:NextNumber(4, 20), 0)), t.COLOR, M.SmoothPlastic)
		a.Transparency, a.CanCollide, a.CanQuery = 1, false, false
		particles(a, t.COLOR, SPARK, 6, 1.2, 6, 0.6)
	end
end

-- Cosmico: la grotta-geode la fa shapeZone; qui polvere di stelle che sale (particelle)
BUILD.Cosmico = function(z, t)
	for _, p in z.points(6) do
		local a = part(z.folder, "Polvere", Vector3.one, CFrame.new(p + Vector3.new(0, 3, 0)), t.COLOR, M.SmoothPlastic)
		a.Transparency, a.CanCollide, a.CanQuery = 1, false, false
		particles(a, Color3.fromRGB(255, 230, 255), SPARK, 5, 0.8, 2, 3)
	end
end

BUILD.Eclissi = function(z, t)
	local BLACK = Color3.fromRGB(26, 24, 34)
	local GOLD = Color3.fromRGB(255, 170, 60)
	-- l'anello dell'eclissi sospeso sopra il centro: 28 blocchi neri e un bordo d'oro
	local c = z.center + Vector3.new(0, 34, 0)
	local R = 22
	local N = 28
	for k = 0, N - 1 do
		local a = k / N * 2 * math.pi
		local p = c + Vector3.new(math.cos(a) * R, math.sin(a) * R, 0)
		local q = c + Vector3.new(math.cos(a + 2 * math.pi / N) * R, math.sin(a + 2 * math.pi / N) * R, 0)
		part(z.folder, "Anello", Vector3.new(4, 4, (q - p).Magnitude + 0.6), CFrame.lookAt((p + q) / 2, q), BLACK, M.Basalt)
		local rim = part(z.folder, "BordoOro", Vector3.new(1, 1, (q - p).Magnitude + 0.6), CFrame.lookAt((p + q) / 2 * 0.985 + c * 0.015, q), GOLD, M.Neon)
		rim.CanCollide = false
	end
	local core = part(z.folder, "Corona", Vector3.one, CFrame.new(c), GOLD, M.Neon)
	core.Transparency = 1
	glow(core, GOLD, 60, 2)
	particles(core, GOLD, SPARK, 10, 1.5, 8, 2)
	-- obelischi neri con lo spigolo d'oro
	for _, p in z.points(10) do
		local h = z.rng:NextNumber(14, 26)
		local o = part(z.folder, "Obelisco", Vector3.new(3.5, h, 3.5), CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, z.rng:NextNumber(0, 6.28), 0), BLACK, M.Basalt)
		local edge = part(z.folder, "SpigoloOro", Vector3.new(0.4, h, 0.4), o.CFrame * CFrame.new(1.8, 0, 1.8), GOLD, M.Neon)
		edge.CanCollide = false
	end
	for _, p in z.points(12) do
		local ember = part(z.folder, "Brace", Vector3.new(2, 0.4, 2), CFrame.new(p + Vector3.new(0, 0.2, 0)), GOLD, M.Neon, Enum.PartType.Cylinder)
		ember.CanCollide = false
		particles(ember, GOLD, SPARK, 4, 0.6, 3, 1.5)
	end
	local _ = t
end

------------------------------------------------------------------------------------------
-- Forme delle zone (al posto della piattaforma piatta):
--   canyon  (Roccia)            una gola scavata nel pendio, pareti a strati
--   bowl    (Ossa)              una conca, il cimitero sul fondo
--   cave    (Cosmico, Eclissi)  una grotta scavata nella montagna, aperta verso la valle
--   islands (Tempesta, Fulmine) isole che fluttuano, collegate da sassi sospesi
-- Si lavora sui voxel (come la Grande Grotta): dentro la forma aria, sotto il pavimento il
-- materiale del tema, attorno un guscio di roccia SOLO dove c'e' la montagna (la montagna e' cava:
-- senza guscio si sfonderebbe nel vuoto interno).

local SHAPE = { Roccia = "canyon", Ossa = "bowl", Cosmico = "cave", Eclissi = "cave", Tempesta = "islands", Fulmine = "islands" }

type Stage = { stage: Vector3, nest: Vector3, castFrom: number, spots: { { p: Vector3, n: Vector3 } } }

-- modifica i voxel nella scatola: classify(p, top) restituisce (materiale, pieno?) o nil (non toccare)
local function editVoxels(map: Heightmap.Map, lo: Vector3, hi: Vector3, classify: (Vector3, number) -> (Enum.Material?, number?))
	local T = workspace.Terrain
	local region = Region3.new(lo, hi):ExpandToGrid(4)
	local mats, occs = T:ReadVoxels(region, 4)
	local size = mats.Size
	local origin = region.CFrame.Position - region.Size / 2
	for ix = 1, size.X do
		local x = origin.X + (ix - 0.5) * 4
		for iz = 1, size.Z do
			local z = origin.Z + (iz - 0.5) * 4
			local top = Heightmap.sampleH(map, x, z)
			for iy = 1, size.Y do
				local m, o = classify(Vector3.new(x, origin.Y + (iy - 0.5) * 4, z), top)
				if m then
					mats[ix][iy][iz] = m
					occs[ix][iy][iz] = o or 1
				end
			end
		end
		if ix % 8 == 0 then
			task.wait()
		end
	end
	T:WriteVoxels(region, 4, mats, occs)
end

local function strata(y: number, a: Enum.Material, b: Enum.Material): Enum.Material
	return if math.floor(y / 9) % 2 == 0 then a else b
end

-- punti sulle superfici di una cavita': raggi dal centro in tutte le direzioni (pareti, soffitto,
-- pavimento), con la normale per far crescere i cristalli verso l'interno
local function cavitySpots(c: Vector3, reach: number, n: number, rng: Random, below: boolean?): { { p: Vector3, n: Vector3 } }
	local out = {}
	for _ = 1, n * 3 do
		if #out >= n then
			break
		end
		local d = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(if below then -1 else -0.6, if below then -0.2 else 0.9), rng:NextNumber(-1, 1))
		if d.Magnitude > 0.1 then
			local hit = workspace:Raycast(c, d.Unit * reach, terrainOnly)
			if hit then
				table.insert(out, { p = hit.Position, n = hit.Normal })
			end
		end
	end
	return out
end

local function shapeZone(map: Heightmap.Map, kind: string, t: any, center: Vector3, out: Vector3, rng: Random, zf: Instance): Stage
	local R = t.RADIUS
	local side = Vector3.new(-out.Z, 0, out.X)
	local g1, g2 = (M :: any)[t.GROUND[1]], (M :: any)[t.GROUND[2]]
	local seed = rng:NextNumber(0, 100)
	local function wob(p: Vector3, s: number): number
		return math.noise(p.X / s + seed, p.Y / s, p.Z / s)
	end
	if kind == "canyon" then
		-- gola lungo il pendio (di traverso), larga 26-40, profonda ~26, pareti a strati
		local L, W, D = R * 0.95, R * 0.17, 26
		local floorY = center.Y - D
		editVoxels(map, center - Vector3.new(L + 30, D + 12, L + 30), center + Vector3.new(L + 30, 70, L + 30), function(p, top)
			local d = p - center
			local s, lat = d:Dot(side), d:Dot(out)
			local w = W * (1 + 0.35 * math.sin(s / 23 + seed)) * (1 + math.max(0, p.Y - floorY) / 55)
			local k = math.max(math.abs(lat) / w, math.abs(s) / L) + wob(p, 30) * 0.12
			local fl = floorY + wob(p, 40) * 3
			if k < 1 and p.Y > fl then
				return M.Air, 0
			elseif k < 1 and p.Y > fl - 6 then
				return g1, 1
			elseif k < 1 + 10 / w and p.Y > fl - 6 and top > p.Y + 2 then
				return strata(p.Y, M.Sandstone, M.Rock), 1
			end
			return nil
		end)
		local spots = {}
		for _ = 1, 110 do
			local s = rng:NextNumber(-0.9, 0.9) * L
			local q = center + side * s + Vector3.new(0, rng:NextNumber(-D + 4, 10), 0)
			local dir = out * (if rng:NextNumber() < 0.5 then 1 else -1) + Vector3.new(0, rng:NextNumber(-0.8, 0.2), 0)
			local hit = workspace:Raycast(q, dir.Unit * 60, terrainOnly)
			if hit and #spots < 70 then
				table.insert(spots, { p = hit.Position, n = hit.Normal })
			end
		end
		local nestAt = down(center.X, center.Z, center.Y + 40)
		return { stage = Vector3.new(center.X, floorY, center.Z), nest = if nestAt then nestAt.Position else center, castFrom = 60, spots = spots }
	elseif kind == "bowl" then
		-- conca: ellissoide schiacciato aperto in alto, fondo a ~0.3R sotto il bordo
		local rx, ry = R * 0.85, R * 0.32
		local c = center + Vector3.new(0, ry * 0.15, 0)
		local floorY = c.Y - ry * 0.75
		editVoxels(map, c - Vector3.new(rx + 16, ry + 16, rx + 16), c + Vector3.new(rx + 16, ry + 50, rx + 16), function(p, top)
			local d = p - c
			local k = math.sqrt((d.X / rx) ^ 2 + (d.Y / ry) ^ 2 + (d.Z / rx) ^ 2) + wob(p, 35) * 0.1
			local fl = floorY + wob(p, 45) * 3
			if k < 1 and p.Y > fl then
				return M.Air, 0
			elseif k < 1 then
				return g1, 1
			elseif k < 1 + 12 / ry and top > p.Y + 2 and p.Y < c.Y then
				return g2, 1
			end
			-- sopra il bordo: niente pendio dentro la conca
			if p.Y >= c.Y and math.sqrt(d.X * d.X + d.Z * d.Z) < rx then
				return M.Air, 0
			end
			return nil
		end)
		local stage = Vector3.new(c.X, floorY, c.Z)
		return { stage = stage, nest = stage, castFrom = 120, spots = cavitySpots(c + Vector3.new(0, 4, 0), rx * 1.2, 60, rng, true) }
	elseif kind == "cave" then
		-- grotta: ellissoide scavato dentro la montagna, l'apertura verso la valle
		local rx, ry, rz = R * 0.6, R * 0.42, R * 0.6
		-- la bocca va dove il pendio e' davvero alto: si cerca la parete della montagna a meta'
		-- altezza della grotta (prima su un ripiano piano la grotta restava senza tetto)
		local face = center
		local Mo = map.cfg.MOUNTAIN
		local theta = math.atan2(center.Z - Mo.Z, center.X - Mo.X)
		local rs = Heightmap.findSurfaceR(map, theta, center.Y + ry * 1.1)
		if rs then
			face = Vector3.new(Mo.X + math.cos(theta) * rs, center.Y, Mo.Z + math.sin(theta) * rs)
		end
		local c = face - out * rz * 0.45 + Vector3.new(0, ry * 0.55, 0)
		local floorY = c.Y - ry * 0.6
		local SH = 12
		editVoxels(map, c - Vector3.new(rx + rz + SH, ry + SH, rx + rz + SH), c + Vector3.new(rx + rz + SH, ry + SH, rx + rz + SH), function(p, top)
			local d = p - c
			local k = math.sqrt((d:Dot(side) / rx) ^ 2 + (d.Y / ry) ^ 2 + (d:Dot(out) / rz) ^ 2) + wob(p, 28) * 0.13
			local fl = floorY + wob(p, 30) * 2.5
			if k < 1 and p.Y > fl then
				return M.Air, 0
			elseif k < 1 and p.Y > fl - 8 then
				return g1, 1
			elseif k < 1 + SH / ry and (p - face):Dot(out) < -6 and top > p.Y + 2 then
				return g2, 1 -- guscio colorato del tema (pareti e soffitto)
			end
			return nil
		end)
		local stage = Vector3.new(c.X, floorY, c.Z)
		local ground = down(c.X, c.Z, c.Y + 4)
		return { stage = stage, nest = if ground then ground.Position else stage, castFrom = ry * 0.4, spots = cavitySpots(c, math.max(rx, ry, rz) * 1.6, 90, rng) }
	end
	-- isole volanti: una grande al centro (col nido) e 5-6 attorno a quote diverse, sassi sospesi
	-- a spirale dal suolo fino all'isola centrale
	local T = workspace.Terrain
	local spots = {}
	local function island(at: Vector3, r: number)
		T:FillCylinder(CFrame.new(at), 6, r, g1)
		for k = 1, 4 do
			local rr = r * (1 - k * 0.2)
			T:FillBall(at - Vector3.new(rng:NextNumber(-2, 2), k * r * 0.3, rng:NextNumber(-2, 2)), rr, if k % 2 == 0 then g2 else g1)
		end
		T:FillCylinder(CFrame.new(at + Vector3.new(0, 12, 0)), 18, r + 2, M.Air) -- cima piatta
		for _ = 1, 9 do
			local a = rng:NextNumber(0, 2 * math.pi)
			local q = at + Vector3.new(math.cos(a) * r * rng:NextNumber(0.1, 0.8), 8, math.sin(a) * r * rng:NextNumber(0.1, 0.8))
			local hit = workspace:Raycast(q, Vector3.new(0, -20, 0), terrainOnly)
			if hit then
				table.insert(spots, { p = hit.Position, n = hit.Normal })
			end
		end
		-- cristalli appesi sotto (a testa in giu')
		for _ = 1, 4 do
			local q = at - Vector3.new(rng:NextNumber(-r, r) * 0.3, r * 2.2, rng:NextNumber(-r, r) * 0.3)
			local hit = workspace:Raycast(q, Vector3.new(0, r * 2.5, 0), terrainOnly)
			if hit and hit.Normal.Y < -0.3 then
				table.insert(spots, { p = hit.Position, n = hit.Normal })
			end
		end
	end
	local mainAt = center + Vector3.new(0, 45, 0)
	island(mainAt, R * 0.3)
	local n = rng:NextInteger(7, 9)
	for k = 1, n do
		local a = k / n * 2 * math.pi + rng:NextNumber(-0.25, 0.25)
		local r = R * rng:NextNumber(0.55, 1.05)
		local g = down(center.X + math.cos(a) * r, center.Z + math.sin(a) * r, center.Y + 400)
		local baseY = if g then math.max(g.Position.Y, center.Y) else center.Y
		island(Vector3.new(center.X + math.cos(a) * r, baseY + rng:NextNumber(35, 120), center.Z + math.sin(a) * r), R * rng:NextNumber(0.13, 0.22))
		if k % 2 == 0 then
			task.wait()
		end
	end
	-- sassi sospesi: spirale dal suolo all'isola centrale (si sale saltando)
	local a0 = rng:NextNumber(0, 2 * math.pi)
	local steps = 9
	for k = 1, steps do
		local f = k / (steps + 1)
		local a = a0 + f * math.pi * 1.4
		local r = R * 0.3 + 14 * (1 - f) + 6
		local p = center + Vector3.new(math.cos(a) * r, 4 + f * 41, math.sin(a) * r)
		T:FillBall(p, 4.5, g2)
	end
	local _ = zf
	return { stage = mainAt, nest = mainAt + Vector3.new(0, 0.5, 0), castFrom = 400, spots = spots }
end

------------------------------------------------------------------------------------------

function ThemeZones.build(map: Heightmap.Map)
	local old = workspace:FindFirstChild("ZoneATema")
	if old then
		old:Destroy()
	end
	local cfg = map.cfg
	local Mo = cfg.MOUNTAIN
	local list = cfg.THEME_ZONES or {}
	local folder = Instance.new("Folder")
	folder.Name = "ZoneATema"
	local markers = workspace:FindFirstChild("MapMarkers")
	local nests: Folder? = nil
	if markers then
		local old2 = markers:FindFirstChild("ThemeNests")
		if old2 then
			old2:Destroy()
		end
		nests = Instance.new("Folder")
		nests.Name = "ThemeNests"
	end
	local made = {}
	local centers: { Vector3 } = {} -- le zone non si sovrappongono
	-- da evitare: Grande Grotta, cratere, grotte dei ghiacciai, il punto della cinematica
	local avoid: { Vector3 } = {}
	for _, key in { "GrandCaveCenter", "CraterCaveCenter", "CineSpot" } do
		local v = workspace:GetAttribute(key)
		if typeof(v) == "Vector3" then
			table.insert(avoid, v)
		end
	end
	for _, gc in map.features.glacierCaves or {} do
		local e = gc.entrance
		if e then
			table.insert(avoid, Vector3.new(e.x, e.y, e.z))
		end
	end
	for _, ic in map.features.iceCaves or {} do
		table.insert(avoid, Vector3.new(ic.x, ic.y, ic.z))
	end
	for i, t0 in list do
		local t = table.clone(t0)
		t.RADIUS *= 1.4 -- zone piu' grandi
		local rng = Random.new(cfg.SEED + 900 + i)
		-- centro: attorno all'angolo scelto, alla quota piu' vicina a Y, dove c'e' poco ghiacciaio
		-- e il terreno e' meno ripido (prima molte zone finivano su un ghiacciaio in pendenza)
		local best: Vector3? = nil
		local bestScore = math.huge
		for da = -0.5, 0.5, 0.1 do
			local dir = Vector3.new(math.cos(t.ANGLE + da), 0, math.sin(t.ANGLE + da))
			for r = Mo.RADIUS * 0.05, Mo.RADIUS * 1.3, 16 do
				local hit = down(Mo.X + dir.X * r, Mo.Z + dir.Z * r, Mo.HEIGHT + 600)
				local clash = false
				if hit then
					for _, o in centers do
						if (o - hit.Position).Magnitude < 340 then
							clash = true
						end
					end
					for _, o in avoid do
						if (o - hit.Position).Magnitude < 280 then
							clash = true
						end
					end
					-- cielo libero sopra (prima una zona e' finita dentro una grotta di ghiaccio) e
					-- niente ghiaccio sotto
					if hit.Material == M.Ice or hit.Material == M.Glacier or workspace:Raycast(hit.Position + Vector3.new(0, 4, 0), Vector3.new(0, 400, 0), terrainOnly) then
						clash = true
					end
				end
				if hit and not clash and hit.Material ~= M.Water and math.abs(hit.Position.Y - t.Y) < 160 then
					local p = hit.Position
					local bad = 0
					for k = 1, 10 do
						local a = k / 10 * 2 * math.pi
						local q = down(p.X + math.cos(a) * t.RADIUS * 0.5, p.Z + math.sin(a) * t.RADIUS * 0.5, p.Y + 300)
						if not q or q.Material == M.Glacier or q.Material == M.Water then
							bad += 2
						elseif q.Normal.Y < 0.7 or math.abs(q.Position.Y - p.Y) > t.RADIUS * 0.35 then
							bad += 1
						end
					end
					local score = math.abs(p.Y - t.Y) * 0.15 + bad * 10 + math.abs(da) * 20
					if SHAPE[t.ELEMENT] == "cave" or SHAPE[t.ELEMENT] == "canyon" then
						-- grotte e gole vogliono il pendio: dietro (verso la montagna) il terreno sale
						local inward = down(p.X - dir.X * t.RADIUS * 0.5, p.Z - dir.Z * t.RADIUS * 0.5, p.Y + 600)
						local rise = if inward then inward.Position.Y - p.Y else 0
						score += math.max(0, t.RADIUS * 0.45 - rise) * 0.4 - bad * 6
					end
					if score < bestScore then
						best, bestScore = p, score
					end
				end
			end
		end
		if not best then
			continue
		end
		local center = best :: Vector3
		table.insert(centers, center)
		local zf = Instance.new("Folder")
		zf.Name = t.ELEMENT
		zf.Parent = folder
		-- punti a terra nella zona (piu' fitti al centro); niente dove il terreno e' troppo ripido
		local function points(n: number): { Vector3 }
			local out = {}
			local tries = 0
			while #out < n and tries < n * 12 do
				tries += 1
				local a = rng:NextNumber(0, 2 * math.pi)
				local r = t.RADIUS * math.sqrt(rng:NextNumber()) * 0.9
				local hit = down(center.X + math.cos(a) * r, center.Z + math.sin(a) * r, center.Y + 400)
				if hit and hit.Normal.Y > 0.5 and math.abs(hit.Position.Y - center.Y) < t.RADIUS * 0.8 then
					table.insert(out, hit.Position)
				end
			end
			return out
		end
		-- terreno a chiazze coi materiali del tema (piu' fitte al centro: sfuma ai bordi)
		local T = workspace.Terrain
		for k = 1, 480 do
			local a = rng:NextNumber(0, 2 * math.pi)
			local f = rng:NextNumber() ^ 0.75 * 1.6 -- 0 = centro, 1.6 = fuori
			local r = t.RADIUS * f
			-- oltre il raggio le chiazze si diradano: il tema sfuma nella roccia attorno
			local keep = f < 0.9 or rng:NextNumber() < (1.6 - f) / 0.7
			local hit = keep and down(center.X + math.cos(a) * r, center.Z + math.sin(a) * r, center.Y + 400)
			if hit then
				local s = rng:NextNumber(8, 18) * (1.2 - f * 0.6)
				local region = Region3.new(hit.Position - Vector3.one * s, hit.Position + Vector3.one * s):ExpandToGrid(4)
				local to = if rng:NextNumber() < 0.65 then (M :: any)[t.GROUND[1]] else (M :: any)[t.GROUND[2]]
				for _, from in NATURAL do
					if from ~= to then
						T:ReplaceMaterial(region, 4, from, to)
					end
				end
			end
			if k % 40 == 0 then
				task.wait()
			end
		end
		-- la forma della zona (gola, conca, grotta, isole volanti)
		local outward = Vector3.new(center.X - Mo.X, 0, center.Z - Mo.Z).Unit
		local st = shapeZone(map, SHAPE[t.ELEMENT] or "bowl", t, center, outward, rng, zf)
		local stage = st.stage
		-- i punti per gli oggetti ora stanno sul fondo della forma (per le grotte i raggi partono
		-- da dentro, non dal cielo che colpirebbe il tetto)
		local function stagePoints(n: number): { Vector3 }
			local out = {}
			local tries = 0
			while #out < n and tries < n * 12 do
				tries += 1
				local a = rng:NextNumber(0, 2 * math.pi)
				local r = t.RADIUS * math.sqrt(rng:NextNumber()) * (if SHAPE[t.ELEMENT] == "cave" then 0.45 else 0.8)
				local hit = down(stage.X + math.cos(a) * r, stage.Z + math.sin(a) * r, stage.Y + st.castFrom)
				if hit and hit.Normal.Y > 0.5 and math.abs(hit.Position.Y - stage.Y) < t.RADIUS * 0.6 then
					table.insert(out, hit.Position)
				end
			end
			return out
		end
		local _ = points
		local zone: Zone = { center = stage, radius = t.RADIUS * (if SHAPE[t.ELEMENT] == "cave" then 0.5 else 1), rng = rng, folder = zf, points = stagePoints }
		local build = BUILD[t.ELEMENT]
		if build then
			build(zone, t)
		end
		-- tanti cristalli: sulle superfici della forma (pareti delle grotte e della gola, sotto e
		-- sopra le isole) e a grappoli sul fondo
		for _, sp in st.spots do
			crystal(zf, sp.p, rng:NextNumber(6, 18), Vector3.zero, t.COLOR, rng, sp.n)
		end
		for _, p in stagePoints(16) do
			for _ = 1, rng:NextInteger(2, 4) do
				local q = p + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
				local hit = down(q.X, q.Z, q.Y + 20)
				if hit then
					crystal(zf, hit.Position, rng:NextNumber(5, 16), Vector3.zero, t.COLOR, rng, hit.Normal)
				end
			end
		end
		-- i cristalli sono solo i modelli di Mirko (ServerStorage.Modelli, "Cristallo_<elemento>"),
		-- grandi, deformati e inclinati; i segnaposto senza modello si tolgono
		local models = crystalModels(t.ELEMENT)
		for _, holder in zf:GetDescendants() do
			if holder:IsA("Model") and holder.Name == "Cristallo" and holder:GetAttribute("Height") then
				if #models > 0 then
					local h = (holder:GetAttribute("Height") :: number) * 1.8
					placeModel(holder.Parent :: Instance, models[rng:NextInteger(1, #models)], holder:GetAttribute("Base") :: Vector3, h, rng, holder:GetAttribute("Normal") :: Vector3?, t.ELEMENT)
				end
				holder:Destroy()
			end
		end
		-- luci del tema dentro la forma
		for k = 1, 5 do
			local q = stage + Vector3.new(rng:NextNumber(-1, 1) * t.RADIUS * 0.35, 10 + k * 3, rng:NextNumber(-1, 1) * t.RADIUS * 0.35)
			local l = part(zf, "LuceZona", Vector3.one, CFrame.new(q), t.COLOR, M.SmoothPlastic)
			l.Transparency, l.CanCollide, l.CanQuery = 1, false, false
			glow(l, t.COLOR, 45, 1.4)
		end
		-- nido sul fondo (o sull'isola centrale) e cartello sul bordo verso valle
		nest(zf, nests, st.nest, t.ELEMENT, t.COLOR, t.STONE)
		local edge = center + outward * t.RADIUS * 0.85
		local eh = down(edge.X, edge.Z, center.Y + 300)
		if eh then
			sign(zf, eh.Position, center, t.TITLE, t.SUBTITLE, t.COLOR)
		end
		workspace:SetAttribute("ThemeZone" .. i .. "Center", center)
		workspace:SetAttribute("ThemeZone" .. i .. "Radius", t.RADIUS)
		workspace:SetAttribute("ThemeZone" .. i .. "Element", t.ELEMENT)
		workspace:SetAttribute("ThemeZone" .. i .. "Title", t.TITLE)
		workspace:SetAttribute("ThemeZone" .. i .. "Stage", stage) -- il cuore della forma (clip)
		workspace:SetAttribute("ThemeZone" .. i .. "Out", outward)
		workspace:SetAttribute("ThemeZone" .. i .. "Shape", SHAPE[t.ELEMENT] or "bowl")
		table.insert(made, string.format("%s a %d m", t.ELEMENT, math.floor(center.Y)))
		task.wait()
	end
	workspace:SetAttribute("ThemeZoneCount", #list)
	if nests and markers then
		nests.Parent = markers
	end
	folder.Parent = workspace
	local removed = ThemeZones.crystals(cfg.SEED)
	print(string.format("[MapGen] Zone a tema: %s (cristalli sospesi tolti: %d)", table.concat(made, ", "), removed))
end

------------------------------------------------------------------------------------------
-- Cristalli delle grotte di ghiaccio e delle valli dei gas (cartella ZoneATema.CristalliGeloGas).
-- Si puo' rilanciare da sola, senza rigenerare la mappa, dalla Command Bar:
--   require(game.ServerStorage.MapGen:Clone().ThemeZones).crystals()
-- Nelle grotte: tanti cristalli in tre taglie (piccoli, medi, giganti), a ciuffi, anche sulle
-- pareti e appesi al soffitto. Le forme: il cristallo di ghiaccio di Mirko e, rifatte di ghiaccio
-- (vetro azzurro traslucido), le sagome degli altri suoi cristalli.

local ICE = Color3.fromRGB(165, 225, 255)

-- le sagome degli altri cristalli di Mirko, di ghiaccio (fuori dal mondo: sono solo stampi)
local function iceShapes(): { Model }
	local out = {}
	for _, element in { "Tempesta", "Fulmine", "Cosmico", "Eclissi", "Roccia", "Gas" } do
		for _, tpl in crystalModels(element) do
			local _, size = tpl:GetBoundingBox()
			if size.Magnitude > 1 then -- uno dei modelli della roccia e' vuoto (0.05 studs)
				local m = tpl:Clone()
				for _, d in m:GetDescendants() do
					if d:IsA("SurfaceAppearance") or d:IsA("LuaSourceContainer") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.Material = Enum.Material.Glass
						d.Color = ICE
						d.Transparency = 0.2
						d.Reflectance = 0.08
					end
				end
				table.insert(out, m)
			end
		end
	end
	return out
end

function ThemeZones.crystals(seed: number?): number
	local folder = workspace:FindFirstChild("ZoneATema")
	if not folder then
		warn("[MapGen] manca Workspace.ZoneATema: rigenera la mappa")
		return 0
	end
	local old = folder:FindFirstChild("CristalliGeloGas")
	if old then
		old:Destroy()
	end
	local extra = Instance.new("Folder")
	extra.Name = "CristalliGeloGas"
	extra.Parent = folder
	local rng = Random.new((seed or 1) + 991)
	local ice = crystalModels("Gelo")
	local shapes = iceShapes()
	-- meta' il cristallo di ghiaccio originale, meta' le altre forme
	local function iceModel(): Model?
		if #shapes > 0 and (#ice == 0 or rng:NextNumber() < 0.5) then
			return shapes[rng:NextInteger(1, #shapes)]
		end
		return if #ice > 0 then ice[rng:NextInteger(1, #ice)] else nil
	end
	-- taglie: tanti piccoli, un po' di medi, qualche gigante (solo dove c'e' spazio)
	local function iceSize(giants: boolean): number
		local r = rng:NextNumber()
		if r < 0.55 then
			return rng:NextNumber(4, 11)
		elseif r < 0.88 or not giants then
			return rng:NextNumber(12, 24)
		end
		return rng:NextNumber(28, 48)
	end
	-- un cristallo di ghiaccio alto al massimo il 40% dello spazio libero sopra di lui (la forma
	-- si puo' allungare fino a 2.3 volte): i giganti non bucano il soffitto della grotta
	local function placeIce(tpl: Model, at: Vector3, h: number, normal: Vector3)
		local up = workspace:Raycast(at + normal * 1.5, normal * 220, terrainOnly)
		if up then
			h = math.min(h, up.Distance * 0.4)
		end
		if h >= 2.5 then
			placeModel(extra, tpl, at, h, rng, normal, "Gelo")
		end
	end
	local function floorSpot(c: Vector3, radius: number, fromY: number): RaycastResult?
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = radius * math.sqrt(rng:NextNumber())
		local hit = workspace:Raycast(Vector3.new(c.X + math.cos(a) * r, fromY, c.Z + math.sin(a) * r), Vector3.new(0, -fromY + c.Y - 60, 0), terrainOnly)
		return if hit and hit.Normal.Y > 0.6 then hit else nil
	end
	local function iceFloor(c: Vector3, radius: number, n: number, fromY: number, giants: boolean)
		local placed = 0
		for _ = 1, n * 6 do
			if placed >= n then
				break
			end
			local hit = floorSpot(c, radius, fromY)
			local tpl = iceModel()
			if hit and tpl then
				placeIce(tpl, hit.Position, iceSize(giants), hit.Normal)
				placed += 1
			end
		end
	end
	-- ciuffi: un cristallo grande e qualche piccolo attorno, inclinati verso l'esterno
	local function iceClusters(c: Vector3, radius: number, n: number, fromY: number)
		for _ = 1, n do
			local hit = floorSpot(c, radius, fromY)
			if hit then
				local center = hit.Position
				local big = iceModel()
				if big then
					placeIce(big, center, rng:NextNumber(10, 22), hit.Normal)
				end
				for _ = 1, rng:NextInteger(3, 5) do
					local a = rng:NextNumber(0, 2 * math.pi)
					local q = center + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(3, 7)
					local h2 = workspace:Raycast(q + Vector3.new(0, 8, 0), Vector3.new(0, -16, 0), terrainOnly)
					local tpl = iceModel()
					if h2 and tpl then
						local lean = (h2.Normal + Vector3.new(math.cos(a), 0, math.sin(a)) * 0.6).Unit
						placeIce(tpl, h2.Position, rng:NextNumber(4, 10), lean)
					end
				end
			end
		end
	end
	-- pareti e soffitto (i pavimenti li fanno gli altri)
	local function iceWalls(c: Vector3, reach: number, n: number, small: boolean)
		for _, s in cavitySpots(c, reach, n * 2, rng) do
			if s.n.Y < 0.5 and n > 0 then
				local tpl = iceModel()
				if tpl then
					placeIce(tpl, s.p, if small then rng:NextNumber(3, 9) else rng:NextNumber(4, 16), s.n)
					n -= 1
				end
			end
		end
	end
	local function scatter(element: string, c: Vector3, radius: number, n: number, fromY: number)
		local models = crystalModels(element)
		if #models == 0 then
			return
		end
		local placed = 0
		for _ = 1, n * 6 do
			if placed >= n then
				break
			end
			local hit = floorSpot(c, radius, fromY)
			if hit then
				placeModel(extra, models[rng:NextInteger(1, #models)], hit.Position, rng:NextNumber(5, 12), rng, nil, element)
				placed += 1
			end
		end
	end
	for _, key in { "GrandCave", "CraterCave" } do
		local den = workspace:GetAttribute(key .. "Den")
		if typeof(den) == "CFrame" then
			-- dentro la sala: i raggi partono poco sopra il pavimento (sopra c'e' il soffitto)
			local c = den.Position
			iceFloor(c, 150, 110, c.Y + 25, true)
			iceClusters(c, 140, 25, c.Y + 25)
			iceWalls(c + Vector3.new(0, 18, 0), 170, 70, false)
		end
		task.wait()
	end
	-- anche lungo le gallerie delle grotte di ghiaccio (le luci azzurre segnano il percorso)
	local glacier = workspace:FindFirstChild("Glacier")
	for _, l in (if glacier then glacier:GetDescendants() else {}) :: { Instance } do
		if l:IsA("BasePart") and l.Parent and string.find(l.Parent.Name, "Luci", 1, true) then
			iceFloor(l.Position, 32, 8, l.Position.Y + 6, false)
			iceWalls(l.Position, 40, 4, true)
		end
	end
	for i = 1, (workspace:GetAttribute("GasCount") or 0) :: number do
		local c, r = workspace:GetAttribute("GasCenter" .. i), workspace:GetAttribute("GasRadius" .. i)
		if typeof(c) == "Vector3" and type(r) == "number" then
			scatter("Gas", c, r * 0.95, 35, c.Y + 300)
		end
	end
	for _, m in shapes do
		m:Destroy()
	end
	-- via i cristalli che non poggiano sulla roccia
	local removed = 0
	for k, m in folder:GetDescendants() do
		if m:IsA("Model") and m.Name == "Cristallo" then
			local b, n = m:GetAttribute("Base"), m:GetAttribute("Normal")
			if typeof(b) == "Vector3" and typeof(n) == "Vector3" then
				local hit = workspace:Raycast(b + n * 3, -n * 9, terrainOnly)
				if not hit then
					m:Destroy()
					removed += 1
				end
			end
		end
		if k % 300 == 0 then
			task.wait()
		end
	end
	print(string.format("[MapGen] Cristalli di grotte e gas: %d (sospesi tolti: %d)", #extra:GetChildren(), removed))
	return removed
end

return ThemeZones
