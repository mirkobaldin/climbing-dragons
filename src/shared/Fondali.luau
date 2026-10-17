--!strict
-- Fondali 3D dei draghi (Mirko 17/10): un posto fatto apposta per ogni elemento, nel bioma del suo
-- uovo, al posto delle immagini piatte che stonavano col modello che gira (schiusa e menu draghi).
-- Ogni fondale e' un piccolo anfiteatro: terreno, un anello di rocce attorno (si vede da ogni lato,
-- anche con la camera che gira), cime lontane e oggetti del bioma (cava, ghiaccio, fulmini, ossa...).
--
-- Convenzione: origin = centro del palco al livello del suolo; davanti (verso la camera della
-- schiusa) = -Z di origin. `unit` scala tutto: 1 = schiusa (uovo alto ~3 studs, anello a 22 studs).
--
-- Si possono ritoccare in Studio: `require(game.ReplicatedStorage.Shared.Fondali).salva()` dalla
-- Command Bar crea ReplicatedStorage.Fondali.<Elemento> (unit 1, pivot = centro del palco). Se un
-- modello li' esiste, schiusa e menu usano quello (gli script dentro vengono tolti).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fondali = {}

export type Theme = {
	ground: Color3,
	groundMat: Enum.Material,
	patch: Color3, -- macchie del suolo
	patchMat: Enum.Material,
	rock: Color3,
	rockMat: Enum.Material,
	rock2: Color3, -- seconda tinta delle rocce
	far: Color3, -- cime lontane
	snow: Color3?, -- neve sulle cime
	skyTop: Color3,
	skyLow: Color3,
	glow: Color3,
	props: string,
}

Fondali.THEMES = {
	-- cava di pietra calda nel canyon (uova di roccia: pareti e frane)
	Roccia = {
		ground = Color3.fromRGB(150, 118, 86), groundMat = Enum.Material.Sandstone,
		patch = Color3.fromRGB(120, 96, 72), patchMat = Enum.Material.Ground,
		rock = Color3.fromRGB(176, 132, 92), rockMat = Enum.Material.Sandstone,
		rock2 = Color3.fromRGB(132, 100, 74),
		far = Color3.fromRGB(150, 112, 92),
		skyTop = Color3.fromRGB(70, 110, 170), skyLow = Color3.fromRGB(240, 186, 130),
		glow = Color3.fromRGB(255, 190, 110), props = "cava",
	},
	-- ghiacciaio con cristalli di ghiaccio
	Gelo = {
		ground = Color3.fromRGB(226, 236, 246), groundMat = Enum.Material.Snow,
		patch = Color3.fromRGB(150, 200, 235), patchMat = Enum.Material.Glacier,
		rock = Color3.fromRGB(116, 132, 152), rockMat = Enum.Material.Slate,
		rock2 = Color3.fromRGB(160, 200, 232),
		far = Color3.fromRGB(150, 172, 200), snow = Color3.fromRGB(240, 246, 255),
		skyTop = Color3.fromRGB(40, 80, 140), skyLow = Color3.fromRGB(190, 225, 250),
		glow = Color3.fromRGB(150, 225, 255), props = "ghiaccio",
	},
	-- creste di roccia scura sotto la tempesta, aste di ferro che chiamano i fulmini
	Tempesta = {
		ground = Color3.fromRGB(62, 70, 80), groundMat = Enum.Material.Slate,
		patch = Color3.fromRGB(80, 96, 104), patchMat = Enum.Material.Rock,
		rock = Color3.fromRGB(70, 80, 94), rockMat = Enum.Material.Rock,
		rock2 = Color3.fromRGB(52, 58, 70),
		far = Color3.fromRGB(56, 66, 86), snow = Color3.fromRGB(170, 190, 210),
		skyTop = Color3.fromRGB(16, 22, 36), skyLow = Color3.fromRGB(70, 96, 130),
		glow = Color3.fromRGB(120, 205, 255), props = "aste",
	},
	-- basalto nero e schegge viola del Fulmine Nero
	Fulmine = {
		ground = Color3.fromRGB(34, 30, 40), groundMat = Enum.Material.Basalt,
		patch = Color3.fromRGB(60, 44, 80), patchMat = Enum.Material.Slate,
		rock = Color3.fromRGB(40, 36, 48), rockMat = Enum.Material.Basalt,
		rock2 = Color3.fromRGB(26, 24, 32),
		far = Color3.fromRGB(44, 36, 62),
		skyTop = Color3.fromRGB(10, 6, 20), skyLow = Color3.fromRGB(76, 40, 110),
		glow = Color3.fromRGB(175, 95, 255), props = "schegge",
	},
	-- altopiano sotto le stelle, rocce sospese e cristalli
	Cosmico = {
		ground = Color3.fromRGB(46, 40, 70), groundMat = Enum.Material.Slate,
		patch = Color3.fromRGB(80, 60, 130), patchMat = Enum.Material.Glass,
		rock = Color3.fromRGB(58, 50, 90), rockMat = Enum.Material.Slate,
		rock2 = Color3.fromRGB(90, 70, 140),
		far = Color3.fromRGB(50, 40, 90),
		skyTop = Color3.fromRGB(6, 6, 24), skyLow = Color3.fromRGB(70, 50, 140),
		glow = Color3.fromRGB(150, 120, 255), props = "stelle",
	},
	-- terra vulcanica con crepe di brace (il drago della vetta)
	Eclissi = {
		ground = Color3.fromRGB(46, 36, 34), groundMat = Enum.Material.CrackedLava,
		patch = Color3.fromRGB(30, 26, 26), patchMat = Enum.Material.Basalt,
		rock = Color3.fromRGB(42, 34, 32), rockMat = Enum.Material.Basalt,
		rock2 = Color3.fromRGB(70, 46, 36),
		far = Color3.fromRGB(60, 36, 30),
		skyTop = Color3.fromRGB(20, 10, 10), skyLow = Color3.fromRGB(170, 80, 30),
		glow = Color3.fromRGB(255, 160, 60), props = "brace",
	},
	-- valle di calcare con le costole di un drago gigante
	Ossa = {
		ground = Color3.fromRGB(196, 184, 156), groundMat = Enum.Material.Limestone,
		patch = Color3.fromRGB(160, 146, 120), patchMat = Enum.Material.Sand,
		rock = Color3.fromRGB(176, 164, 140), rockMat = Enum.Material.Limestone,
		rock2 = Color3.fromRGB(140, 128, 108),
		far = Color3.fromRGB(150, 140, 126),
		skyTop = Color3.fromRGB(80, 90, 120), skyLow = Color3.fromRGB(220, 200, 160),
		glow = Color3.fromRGB(255, 240, 200), props = "costole",
	},
	-- valle dei gas: pozze velenose e camini fumanti
	Gas = {
		ground = Color3.fromRGB(56, 70, 60), groundMat = Enum.Material.Mud,
		patch = Color3.fromRGB(70, 90, 70), patchMat = Enum.Material.Slate,
		rock = Color3.fromRGB(70, 82, 74), rockMat = Enum.Material.Rock,
		rock2 = Color3.fromRGB(90, 70, 100),
		far = Color3.fromRGB(60, 80, 76),
		skyTop = Color3.fromRGB(16, 30, 30), skyLow = Color3.fromRGB(90, 160, 140),
		glow = Color3.fromRGB(90, 255, 220), props = "pozze",
	},
} :: { [string]: Theme }

local RADIUS = 22 -- anello di rocce (unit 1)

function Fondali.theme(element: string): Theme
	return Fondali.THEMES[element] or Fondali.THEMES.Roccia
end

local function seedOf(s: string): number
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- cubo in equilibrio su un vertice, quasi tutto sotto terra: sembra una cima a tre facce
local CORNER_UP = CFrame.Angles(math.rad(45), 0, math.rad(35.264))
local SQ3 = math.sqrt(3) / 2

local function peak(parent: Instance, at: CFrame, s: number, yaw: number, color: Color3, material: Enum.Material, snow: Color3?)
	-- il vertice in alto sta a s*SQ3 dal centro: se ne lascia fuori poco piu' della meta'
	local top = at.Position + Vector3.new(0, s * SQ3 * 0.55, 0)
	part(parent, Vector3.new(s, s, s), CFrame.new(top - Vector3.new(0, s * SQ3, 0)) * CFrame.Angles(0, yaw, 0) * CORNER_UP, color, material)
	if snow then
		local c = s * 0.32
		part(parent, Vector3.new(c, c, c), CFrame.new(top + Vector3.new(0, 0.02 * s, 0) - Vector3.new(0, c * SQ3, 0)) * CFrame.Angles(0, yaw, 0) * CORNER_UP, snow, Enum.Material.Snow)
	end
end

-- masso o guglia fatta di 2-4 blocchi inclinati (rocce spigolose, niente sfere lisce)
local function crag(parent: Instance, rng: Random, at: Vector3, h: number, w: number, t: Theme)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local n = rng:NextInteger(2, 4)
	for i = 1, n do
		local hh = h * (if i == 1 then 1 else rng:NextNumber(0.35, 0.75))
		local ww = w * (if i == 1 then 1 else rng:NextNumber(0.45, 0.8))
		local off = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-0.6, 0.6) * w, 0, rng:NextNumber(-0.6, 0.6) * w)
		local tilt = CFrame.Angles(rng:NextNumber(-0.18, 0.18), yaw + rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.18, 0.18))
		local cf = CFrame.new(at + off + Vector3.new(0, hh * 0.45, 0)) * tilt
		local color = if rng:NextNumber() < 0.6 then t.rock else t.rock2
		part(parent, Vector3.new(ww, hh, ww * rng:NextNumber(0.6, 0.95)), cf, color, t.rockMat)
		-- punta spezzata: un cubo sul vertice in cima
		if i == 1 and rng:NextNumber() < 0.7 then
			local c = ww * 0.8
			part(parent, Vector3.new(c, c, c), cf * CFrame.new(0, hh / 2, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) * CORNER_UP, color, t.rockMat)
		end
	end
end

-- cristallo: prisma allungato con la punta, inclinato verso fuori
local function crystal(parent: Instance, rng: Random, at: Vector3, h: number, color: Color3, material: Enum.Material, transparency: number)
	local w = h * rng:NextNumber(0.16, 0.24)
	local dir = Vector3.new(rng:NextNumber(-0.35, 0.35), 1, rng:NextNumber(-0.35, 0.35)).Unit
	local base = CFrame.lookAt(at, at + dir) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.rad(45), 0)
	local body = part(parent, Vector3.new(w, h, w), base * CFrame.new(0, h / 2, 0), color, material, nil, transparency)
	local tip = w * 0.71
	part(parent, Vector3.new(tip, tip, tip), body.CFrame * CFrame.new(0, h / 2, 0) * CORNER_UP, color, material, nil, transparency)
end

-- arco di cilindri (costole del drago gigante)
local function rib(parent: Instance, from: Vector3, to: Vector3, rise: number, thick: number, color: Color3)
	local n = 7
	local prev = from
	for i = 1, n do
		local a = i / n
		local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * rise, 0)
		local len = (p - prev).Magnitude
		local w = thick * (1 - 0.45 * a)
		part(parent, Vector3.new(len + w * 0.6, w, w), CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.Limestone, Enum.PartType.Cylinder)
		prev = p
	end
end

local function props(parent: Instance, rng: Random, t: Theme, R: number)
	local function onRing(a: number, r: number): Vector3
		return Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
	end
	if t.props == "cava" then
		-- blocchi tagliati impilati e gradoni della cava
		for i = 1, 7 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.45, 0.8) * R)
			local s = rng:NextNumber(1.6, 3.2)
			part(parent, Vector3.new(s * 1.4, s, s), CFrame.new(at + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), t.rock, Enum.Material.Limestone)
			if rng:NextNumber() < 0.5 then
				part(parent, Vector3.new(s, s * 0.7, s * 0.8), CFrame.new(at + Vector3.new(0, s * 1.35, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), t.rock2, Enum.Material.Limestone)
			end
		end
		for k = 1, 3 do
			local a = math.pi + (k - 2) * 0.55
			local at = onRing(a, R * 0.98)
			part(parent, Vector3.new(R * 0.5, R * 0.18 * k, R * 0.3), CFrame.lookAt(at + Vector3.new(0, R * 0.09 * k, 0), Vector3.new(0, R * 0.09 * k, 0)), t.rock2, t.rockMat)
		end
	elseif t.props == "ghiaccio" then
		for _ = 1, 14 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.4, 0.95) * R)
			crystal(parent, rng, at, rng:NextNumber(2.5, 7), Color3.fromRGB(170, 225, 255), Enum.Material.Ice, 0.15)
		end
		for _ = 1, 4 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.85, 1.05) * R)
			crystal(parent, rng, at, rng:NextNumber(9, 14), Color3.fromRGB(150, 210, 245), Enum.Material.Glass, 0.3)
		end
	elseif t.props == "aste" then
		for i = 1, 5 do
			local at = onRing(math.pi + (i - 3) * 0.5 + rng:NextNumber(-0.1, 0.1), R * rng:NextNumber(0.7, 0.9))
			local h = rng:NextNumber(8, 13)
			part(parent, Vector3.new(h, 0.35, 0.35), CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2 + rng:NextNumber(-0.08, 0.08)), Color3.fromRGB(70, 74, 82), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
			part(parent, Vector3.one * 0.8, CFrame.new(at + Vector3.new(0, h, 0)), t.glow, Enum.Material.Neon, Enum.PartType.Ball)
		end
		for _ = 1, 8 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.5, 0.95) * R)
			crag(parent, rng, at, rng:NextNumber(5, 10), rng:NextNumber(1, 1.8), t) -- aghi di roccia
		end
	elseif t.props == "schegge" then
		for _ = 1, 16 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.4, 1) * R)
			crystal(parent, rng, at, rng:NextNumber(2, 8), if rng:NextNumber() < 0.7 then Color3.fromRGB(120, 60, 200) else Color3.fromRGB(30, 20, 44), if rng:NextNumber() < 0.4 then Enum.Material.Neon else Enum.Material.Glass, 0.1)
		end
	elseif t.props == "stelle" then
		-- rocce sospese con cristalli e stelle vicine
		for _ = 1, 7 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.6, 1.1) * R) + Vector3.new(0, rng:NextNumber(6, 16), 0)
			local s = rng:NextNumber(2, 4.5)
			part(parent, Vector3.new(s, s, s), CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)), t.rock, t.rockMat)
			crystal(parent, rng, at + Vector3.new(0, s * 0.4, 0), s * 1.1, Color3.fromRGB(150, 120, 255), Enum.Material.Glass, 0.2)
		end
		for _ = 1, 10 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.45, 0.9) * R)
			crystal(parent, rng, at, rng:NextNumber(1.5, 4.5), Color3.fromRGB(190, 140, 255), Enum.Material.Glass, 0.15)
		end
		for _ = 1, 40 do
			local a = rng:NextNumber(0, math.pi * 2)
			local at = onRing(a, rng:NextNumber(2.2, 3.5) * R) + Vector3.new(0, rng:NextNumber(10, 2.4 * R), 0)
			part(parent, Vector3.one * rng:NextNumber(0.3, 0.9), CFrame.new(at), Color3.fromRGB(230, 225, 255), Enum.Material.Neon, Enum.PartType.Ball)
		end
	elseif t.props == "brace" then
		-- crepe di brace a zig-zag nel suolo
		for _ = 1, 9 do
			local a = rng:NextNumber(0, math.pi * 2)
			local p = onRing(a, rng:NextNumber(0.25, 0.5) * R)
			for _ = 1, 4 do
				local q = p + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5)) + p.Unit * 2.2
				local len = (q - p).Magnitude
				part(parent, Vector3.new(0.35, 0.12, len), CFrame.lookAt((p + q) / 2 + Vector3.new(0, 0.02, 0), q + Vector3.new(0, 0.02, 0)), t.glow, Enum.Material.Neon)
				p = q
			end
		end
		for _ = 1, 6 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.6, 0.95) * R)
			crag(parent, rng, at, rng:NextNumber(4, 9), rng:NextNumber(1.5, 2.6), t)
		end
	elseif t.props == "costole" then
		-- gabbia toracica di un drago gigante che fa da arco dietro il palco
		local bone = Color3.fromRGB(226, 216, 192)
		for i = -2, 2 do
			local z = R * 0.62 + i * 3.2
			rib(parent, Vector3.new(-R * 0.55, 0, z), Vector3.new(-1, R * 0.5, z + 1), R * 0.12, 1.3 - math.abs(i) * 0.15, bone)
			rib(parent, Vector3.new(R * 0.55, 0, z), Vector3.new(1, R * 0.5, z + 1), R * 0.12, 1.3 - math.abs(i) * 0.15, bone)
		end
		-- spina dorsale
		for i = -3, 3 do
			part(parent, Vector3.new(1.6, 1.2, 1.6), CFrame.new(0, R * 0.5, R * 0.62 + i * 3.2) * CFrame.Angles(0, 0.3 * i, 0), bone, Enum.Material.Limestone)
		end
		for _ = 1, 8 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.3, 0.9) * R)
			part(parent, Vector3.new(rng:NextNumber(2, 4), 0.5, 0.5), CFrame.new(at + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), bone, Enum.Material.Limestone, Enum.PartType.Cylinder)
		end
	elseif t.props == "pozze" then
		for _ = 1, 6 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.35, 0.8) * R)
			local s = rng:NextNumber(3, 6)
			part(parent, Vector3.new(0.3, s + 1, s + 1), CFrame.new(at + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), t.rock2, Enum.Material.Slate, Enum.PartType.Cylinder)
			part(parent, Vector3.new(0.32, s, s), CFrame.new(at + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.pi / 2), t.glow, Enum.Material.Neon, Enum.PartType.Cylinder, 0.35)
		end
		for _ = 1, 5 do
			local at = onRing(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.6, 0.95) * R)
			local h = rng:NextNumber(2.5, 5)
			part(parent, Vector3.new(h, 1.6, 1.6), CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), t.rock, t.rockMat, Enum.PartType.Cylinder)
			part(parent, Vector3.new(0.2, 1, 1), CFrame.new(at + Vector3.new(0, h + 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), t.glow, Enum.Material.Neon, Enum.PartType.Cylinder, 0.2)
		end
	end
end

-- costruisce il fondale procedurale (unit 1) dentro un modello con pivot = centro del palco
local function make(element: string): Model
	local t = Fondali.theme(element)
	local rng = Random.new(seedOf(element))
	local m = Instance.new("Model")
	m.Name = element
	local R = RADIUS
	-- suolo e macchie
	part(m, Vector3.new(1, R * 3, R * 3), CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), t.ground, t.groundMat, Enum.PartType.Cylinder)
	for _ = 1, 9 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.3, 1.3) * R
		local s = rng:NextNumber(4, 10)
		part(m, Vector3.new(0.2, s, s * rng:NextNumber(0.6, 1)), CFrame.new(math.sin(a) * r, 0.02, math.cos(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 3), math.pi / 2), t.patch, t.patchMat, Enum.PartType.Cylinder)
	end
	-- sassi sparsi
	for _ = 1, 22 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.25, 1.2) * R
		local s = rng:NextNumber(0.4, 1.4)
		part(m, Vector3.new(s, s * 0.7, s * 0.9), CFrame.new(math.sin(a) * r, s * 0.25, math.cos(a) * r) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), t.rock2, t.rockMat)
	end
	-- anello di rocce: piu' alte dietro (+Z), piu' basse davanti, ma chiuso tutto attorno
	local N = 16
	for i = 1, N do
		local a = (i - 1) / N * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local back = (math.cos(a) + 1) / 2 -- 1 dietro, 0 davanti
		local r = R * rng:NextNumber(0.95, 1.2)
		local h = R * (0.35 + 0.65 * back) * rng:NextNumber(0.7, 1.15)
		crag(m, rng, Vector3.new(math.sin(a) * r, 0, math.cos(a) * r), h, R * rng:NextNumber(0.16, 0.26), t)
	end
	-- cime lontane (due file, la seconda piu' chiara: foschia)
	for row = 1, 2 do
		local count = if row == 1 then 12 else 16
		for i = 1, count do
			local a = (i - 1) / count * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local r = R * (if row == 1 then rng:NextNumber(2.4, 3) else rng:NextNumber(3.6, 4.4))
			local s = R * (if row == 1 then rng:NextNumber(1.1, 1.8) else rng:NextNumber(1.6, 2.6))
			local color = if row == 1 then t.far else t.far:Lerp(t.skyLow, 0.45)
			peak(m, CFrame.new(math.sin(a) * r, 0, math.cos(a) * r), s, rng:NextNumber(0, 6), color, t.rockMat, t.snow)
		end
	end
	props(m, rng, t, R)
	-- niente PrimaryPart: il pivot del modello sarebbe quello del disco del suolo (girato di 90
	-- gradi per fare il cilindro in piedi) e PivotTo girerebbe tutto il fondale
	m.WorldPivot = CFrame.new()
	return m
end

local function strip(m: Instance)
	for _, x in m:GetDescendants() do
		if x:IsA("LuaSourceContainer") then
			x:Destroy() -- regola del gioco: niente script dentro i modelli clonati
		elseif x:IsA("BasePart") then
			x.Anchored = true
			x.CanCollide = false
			x.CanQuery = false
			x.CanTouch = false
		end
	end
end

-- il fondale dell'elemento in parent, con il centro del palco in origin e grande `unit`
function Fondali.get(element: string, parent: Instance, origin: CFrame, unit: number?): Model
	local folder = ReplicatedStorage:FindFirstChild("Fondali")
	local custom = folder and folder:FindFirstChild(element)
	local m: Model
	if custom and custom:IsA("Model") then
		m = custom:Clone()
		strip(m)
	else
		m = make(element)
	end
	m.Name = "Fondale_" .. element
	local u = unit or 1
	if math.abs(u - 1) > 1e-3 then
		m:ScaleTo(u)
	end
	m:PivotTo(origin)
	m.Parent = parent
	return m
end

-- Studio (Command Bar): crea ReplicatedStorage.Fondali con gli 8 fondali da ritoccare a mano.
-- Quelli gia' presenti non vengono toccati (passa true per rifarli tutti)
function Fondali.salva(rifai: boolean?)
	local folder = ReplicatedStorage:FindFirstChild("Fondali")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Fondali"
		folder.Parent = ReplicatedStorage
	end
	local i = 0
	for element in Fondali.THEMES do
		local old = (folder :: Instance):FindFirstChild(element)
		if old and rifai then
			old:Destroy()
			old = nil
		end
		if not old then
			local m = make(element)
			m.Parent = folder
			i += 1
		end
	end
	print("[Fondali] creati " .. i .. " fondali in ReplicatedStorage.Fondali (pivot = centro del palco)")
end

return Fondali
