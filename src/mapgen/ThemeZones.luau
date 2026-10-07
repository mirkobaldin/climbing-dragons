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
local function crystal(parent: Instance, base: Vector3, h: number, tilt: Vector3, color: Color3, rng: Random): Part
	local holder = Instance.new("Model")
	holder.Name = "Cristallo"
	holder:SetAttribute("Height", h)
	holder:SetAttribute("Base", base)
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
local function nest(parent: Instance, markers: Instance?, at: Vector3, element: string, color: Color3, stone: Color3)
	part(parent, "Altare", Vector3.new(3, 12, 12), CFrame.new(at + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), stone, M.Slate, Enum.PartType.Cylinder)
	local ring = part(parent, "AnelloAltare", Vector3.new(0.4, 13, 13), CFrame.new(at + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, M.Neon, Enum.PartType.Cylinder)
	ring.CanCollide = false
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
local function placeModel(parent: Instance, tpl: Model, base: Vector3, h: number, rng: Random)
	local m = tpl:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local _, s0 = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * h / s0.Y)
	-- forma diversa ogni volta: allungato o schiacciato su un solo asse
	local axis = rng:NextInteger(1, 3)
	local k = rng:NextNumber(0.7, 1.6)
	local f = Vector3.new(if axis == 1 then k else 1, if axis == 2 then k else 1, if axis == 3 then k else 1)
	local pv = m:GetPivot()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local rel = pv:PointToObjectSpace(p.Position)
			p.Size = p.Size * f
			p.Position = pv:PointToWorldSpace(rel * f)
		end
	end
	-- e inclinato un poco
	m:PivotTo(CFrame.new(base) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)))
	local box, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, base.Y - (box.Position.Y - s.Y / 2) - 0.5 - s.Y * 0.06, 0))
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
	-- uno scheletro: due file di costole che si guardano, la spina dorsale in mezzo
	local axis = Vector3.new(z.rng:NextNumber(-1, 1), 0, z.rng:NextNumber(-1, 1)).Unit
	local side = Vector3.new(-axis.Z, 0, axis.X)
	for k = -4, 4 do
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

BUILD.Tempesta = function(z, t)
	local STORM = Color3.fromRGB(78, 92, 128)
	local BLUE = Color3.fromRGB(150, 200, 255)
	for _, p in z.points(18) do
		local top = spire(z.folder, p, z.rng:NextNumber(18, 40), z.rng:NextNumber(5, 9), STORM, M.Slate, z.rng)
		if z.rng:NextNumber() < 0.35 then
			local rod = part(z.folder, "Parafulmine", Vector3.new(0.5, 6, 0.5), top.CFrame * CFrame.new(0, top.Size.Y / 2 + 3, 0), BLUE, M.Neon)
			rod.CanCollide = false
			glow(rod, BLUE, 14, 1)
		end
	end
	-- rocce che fluttuano nel vento
	for _, p in z.points(10) do
		local r = part(z.folder, "RocciaSospesa", Vector3.new(z.rng:NextNumber(5, 12), z.rng:NextNumber(3, 7), z.rng:NextNumber(5, 12)), CFrame.new(p + Vector3.new(0, z.rng:NextNumber(14, 35), 0)) * CFrame.Angles(z.rng:NextNumber(0, 1), z.rng:NextNumber(0, 6), 0), STORM, M.Slate)
		particles(r, Color3.fromRGB(200, 215, 235), SMOKE, 3, 3, 4, 2)
	end
	local _ = t
end

BUILD.Fulmine = function(z, t)
	local OBSIDIAN = Color3.fromRGB(22, 18, 30)
	local VIOLET = Color3.fromRGB(170, 140, 255)
	for _, p in z.points(16) do
		local h = z.rng:NextNumber(20, 45)
		local top = spire(z.folder, p, h, z.rng:NextNumber(4, 8), OBSIDIAN, M.Glass, z.rng)
		-- vena viola che sale lungo la guglia
		local vein = part(z.folder, "Vena", Vector3.new(0.5, h * 0.9, 0.5), CFrame.new(p + Vector3.new(0, h * 0.45, 0)) * CFrame.Angles(0, 0, z.rng:NextNumber(-0.1, 0.1)), VIOLET, M.Neon)
		vein.CanCollide = false
		if z.rng:NextNumber() < 0.5 then
			glow(top, VIOLET, 18, 1.5)
			particles(top, VIOLET, SPARK, 6, 1.2, 6, 0.6)
		end
	end
	for _, p in z.points(18) do
		crystal(z.folder, p, z.rng:NextNumber(2, 5), Vector3.new(z.rng:NextNumber(-0.5, 0.5), 0, z.rng:NextNumber(-0.5, 0.5)), VIOLET, z.rng)
	end
	local _ = t
end

BUILD.Cosmico = function(z, t)
	local PURPLE = Color3.fromRGB(120, 70, 220)
	local MAGENTA = Color3.fromRGB(220, 90, 255)
	for _, p in z.points(14) do
		-- grappolo di cristalli
		for _ = 1, z.rng:NextInteger(3, 6) do
			local q = p + Vector3.new(z.rng:NextNumber(-4, 4), 0, z.rng:NextNumber(-4, 4))
			crystal(z.folder, q, z.rng:NextNumber(4, 14), Vector3.new(z.rng:NextNumber(-0.5, 0.5), 0, z.rng:NextNumber(-0.5, 0.5)), if z.rng:NextNumber() < 0.5 then PURPLE else MAGENTA, z.rng)
		end
	end
	for _, p in z.points(12) do
		local orb = part(z.folder, "Stella", Vector3.one * z.rng:NextNumber(1.5, 3.5), CFrame.new(p + Vector3.new(0, z.rng:NextNumber(10, 30), 0)), Color3.fromRGB(240, 220, 255), M.Neon, Enum.PartType.Ball)
		orb.CanCollide = false
		glow(orb, MAGENTA, 20, 1.2)
		particles(orb, Color3.fromRGB(255, 230, 255), SPARK, 5, 0.8, 2, 2)
	end
	local _ = t
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
		-- ripiano piatto al centro (meta' del raggio): ci stanno l'altare, i nemici e si cammina
		T:FillCylinder(CFrame.new(center - Vector3.new(0, 7, 0)), 14, t.RADIUS * 0.5, (M :: any)[t.GROUND[1]])
		T:FillCylinder(CFrame.new(center + Vector3.new(0, 45, 0)), 90, t.RADIUS * 0.5, M.Air)
		local zone: Zone = { center = center, radius = t.RADIUS, rng = rng, folder = zf, points = points }
		local build = BUILD[t.ELEMENT]
		if build then
			build(zone, t)
		end
		-- in ogni zona anche grappoli di cristalli grandi (prima alcune zone, es. Tempesta, non ne
		-- avevano: si vedevano solo le guglie)
		for _, p in points(18) do
			crystal(zf, p, rng:NextNumber(8, 20), Vector3.zero, t.COLOR, rng)
		end
		-- i cristalli sono solo i modelli di Mirko (ServerStorage.Modelli, "Cristallo_<elemento>"),
		-- piu' grandi, inclinati e allungati su un asse; i segnaposto senza modello si tolgono
		local models = crystalModels(t.ELEMENT)
		for _, holder in zf:GetDescendants() do
			if holder:IsA("Model") and holder.Name == "Cristallo" and holder:GetAttribute("Height") then
				if #models > 0 then
					local h = (holder:GetAttribute("Height") :: number) * 1.8
					placeModel(holder.Parent :: Instance, models[rng:NextInteger(1, #models)], holder:GetAttribute("Base") :: Vector3, h, rng)
				end
				holder:Destroy()
			end
		end
		-- nido al centro e cartello sul bordo verso valle
		nest(zf, nests, center, t.ELEMENT, t.COLOR, t.STONE)
		local outward = Vector3.new(center.X - Mo.X, 0, center.Z - Mo.Z).Unit
		local edge = center + outward * t.RADIUS * 0.85
		local eh = down(edge.X, edge.Z, center.Y + 300)
		if eh then
			sign(zf, eh.Position, center, t.TITLE, t.SUBTITLE, t.COLOR)
		end
		workspace:SetAttribute("ThemeZone" .. i .. "Center", center)
		workspace:SetAttribute("ThemeZone" .. i .. "Radius", t.RADIUS)
		workspace:SetAttribute("ThemeZone" .. i .. "Element", t.ELEMENT)
		workspace:SetAttribute("ThemeZone" .. i .. "Title", t.TITLE)
		table.insert(made, string.format("%s a %d m", t.ELEMENT, math.floor(center.Y)))
		task.wait()
	end
	workspace:SetAttribute("ThemeZoneCount", #list)
	if nests and markers then
		nests.Parent = markers
	end
	folder.Parent = workspace
	local extra = Instance.new("Folder")
	extra.Name = "CristalliGeloGas"
	extra.Parent = folder
	local rng = Random.new(cfg.SEED + 991)
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
			local a = rng:NextNumber(0, 2 * math.pi)
			local r = radius * math.sqrt(rng:NextNumber())
			local hit = workspace:Raycast(Vector3.new(c.X + math.cos(a) * r, fromY, c.Z + math.sin(a) * r), Vector3.new(0, -fromY + c.Y - 60, 0), terrainOnly)
			if hit and hit.Normal.Y > 0.6 then
				placeModel(extra, models[rng:NextInteger(1, #models)], hit.Position, rng:NextNumber(5, 12), rng)
				placed += 1
			end
		end
	end
	for _, key in { "GrandCave", "CraterCave" } do
		local den = workspace:GetAttribute(key .. "Den")
		if typeof(den) == "CFrame" then
			-- dentro la sala: i raggi partono poco sopra il pavimento (sopra c'e' il soffitto)
			scatter("Gelo", den.Position, 110, 14, den.Position.Y + 25)
		end
	end
	for i = 1, (workspace:GetAttribute("GasCount") or 0) :: number do
		local c, r = workspace:GetAttribute("GasCenter" .. i), workspace:GetAttribute("GasRadius" .. i)
		if typeof(c) == "Vector3" and type(r) == "number" then
			scatter("Gas", c, r * 0.8, 10, c.Y + 300)
		end
	end
	print("[MapGen] Zone a tema: " .. table.concat(made, ", "))
end

return ThemeZones
