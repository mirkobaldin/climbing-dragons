--!strict
-- Borghi in stile cinese e giapponese nella pianura (sotto la montagna), fatti con Part:
--   casa cinese a uno, due o tre piani (legno scuro o intonaco bianco), con ballatoio, tetto
--   curvo con le punte all'insu', tettoia tra i piani, lanterne rosse; sui pendii e sull'acqua
--   sta su palafitte (come le case di Fenghuang)
--   minka giapponese (casa di campagna col tetto di paglia e la veranda), sala del tempio
--   pagoda, torii, portale cinese col nome del borgo, padiglione, lanterne di pietra, fili di
--   lanterne rosse tra le case, bottega da te' con l'insegna
-- I tetti sono superfici vere (triangoli fatti da due WedgePart) a forma di anelli: gronda con
-- gli angoli alzati -> ginocchio -> colmo, quindi curvi e a padiglione, non a gradini.
-- Si genera con la mappa, oppure da solo dalla Command Bar (la mappa non si rifa'):
--   require(game.ServerStorage.MapGen:Clone().Borghi).build()
-- Tutto finisce in Workspace.Borghi (una cartella per borgo); gli alberi sopra le case si tolgono.

local ServerStorage = game:GetService("ServerStorage")

local Borghi = {}

-- i percorsi dei fiumi (letti quando il modulo si carica: dopo, la copia di MapGen puo' sparire)
local okConfig, Config = pcall(require, (script.Parent :: any).Config)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local M = Enum.Material

local TILE = Color3.fromRGB(58, 62, 70) -- coppi grigio scuro
local TILE_RIDGE = Color3.fromRGB(40, 42, 48)
local TIMBER = Color3.fromRGB(96, 62, 40)
local TIMBER_DARK = Color3.fromRGB(54, 36, 26)
local PLASTER = Color3.fromRGB(234, 226, 210)
local LACQUER = Color3.fromRGB(172, 36, 30)
local PAPER = Color3.fromRGB(236, 158, 78) -- carta delle finestre, illuminata da dentro (il Neon schiarisce molto)
local STONE = Color3.fromRGB(128, 126, 120)
local STONE_DARK = Color3.fromRGB(92, 90, 86)
local THATCH = Color3.fromRGB(146, 118, 74)
local GOLD = Color3.fromRGB(214, 170, 72)
local LANTERN_RED = Color3.fromRGB(226, 48, 36)
local WARM = Color3.fromRGB(255, 170, 90)

------------------------------------------------------------------------------------------
-- pezzi di base

local function part(m: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, deco: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.WoodPlanks
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if deco then
		p.CanCollide = false
		p.CastShadow = false
	end
	p.Parent = m
	return p
end

local function cylinder(m: Instance, from: Vector3, to: Vector3, d: number, color: Color3, mat: Enum.Material?, deco: boolean?): Part
	local len = (to - from).Magnitude
	local p = part(m, Vector3.new(len, d, d), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0), color, mat or M.Wood, deco)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- trave tra due punti
local function beam(m: Instance, from: Vector3, to: Vector3, w: number, h: number, color: Color3, mat: Enum.Material?, deco: boolean?): Part
	return part(m, Vector3.new(w, h, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), color, mat or M.Wood, deco)
end

local function wedge(m: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat
	w.Parent = m
end

-- triangolo pieno spesso "thick" fatto con due WedgePart (algoritmo classico di Roblox)
local function triangle(m: Instance, a: Vector3, b: Vector3, c: Vector3, thick: number, color: Color3, mat: Enum.Material)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 0.02 or bc.Magnitude < 0.05 then
		return
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < 0.02 then
		return
	end
	local l1, l2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if l1 > 0.02 then
		wedge(m, Vector3.new(thick, height, l1), CFrame.fromMatrix((a + b) / 2, right, up, back), color, mat)
	end
	if l2 > 0.02 then
		wedge(m, Vector3.new(thick, height, l2), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, mat)
	end
end

local function quad(m: Instance, a: Vector3, b: Vector3, c: Vector3, d: Vector3, thick: number, color: Color3, mat: Enum.Material)
	triangle(m, a, b, c, thick, color, mat)
	triangle(m, a, c, d, thick, color, mat)
end

------------------------------------------------------------------------------------------
-- tetti

-- anello rettangolare (mezze misure hx, hz, quota y) nel sistema di cf; "sub" punti in mezzo a
-- ogni lato; lift alza gli angoli (le punte all'insu'), flare li spinge fuori
local function ring(cf: CFrame, hx: number, y: number, hz: number, sub: number, lift: number, flare: number): { Vector3 }
	local corners = { Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz) }
	local out = {}
	for i = 1, 4 do
		local c0, c1 = corners[i], corners[i % 4 + 1]
		for j = 0, sub do
			local t = j / (sub + 1)
			local p = c0:Lerp(c1, t)
			local k = (2 * t - 1) ^ 4 -- 1 agli angoli, 0 a meta' lato
			local dir = Vector3.new(math.sign(p.X), 0, math.sign(p.Z))
			local push = if math.abs(p.X) >= hx - 0.01 and math.abs(p.Z) >= hz - 0.01 then dir.Unit * flare else Vector3.zero
			table.insert(out, cf:PointToWorldSpace(p + Vector3.new(0, y + lift * k, 0) + push * k))
		end
	end
	return out
end

local function band(m: Instance, lo: { Vector3 }, hi: { Vector3 }, thick: number, color: Color3, mat: Enum.Material)
	local n = #lo
	for i = 1, n do
		local j = i % n + 1
		quad(m, lo[i], lo[j], hi[j], hi[i], thick, color, mat)
	end
end

export type RoofOpts = {
	style: string?, -- "gable" (a padiglione e capanna, timpano sui lati corti) o "hip" (solo falde)
	color: Color3?,
	material: Enum.Material?,
	lift: number?, -- quanto si alzano le punte
	thick: number?,
	gableColor: Color3?,
	ridge: boolean?, -- colmo con le punte decorative
}

-- tetto curvo: cf = centro alla quota della gronda; hx, hz = mezze misure della gronda (gia'
-- con la sporgenza); h = altezza del colmo sopra la gronda
local function roof(m: Instance, cf: CFrame, hx: number, hz: number, h: number, o: RoofOpts?)
	local opts = o or {}
	local color = opts.color or TILE
	local mat = opts.material or M.Slate
	local lift = opts.lift or math.min(hx, hz) * 0.16
	local thick = opts.thick or 0.6
	local inset = math.min(hx, hz) * 0.42
	local kx, kz, ky = hx - inset, hz - inset, h * 0.3
	-- 1) dalla gronda (angoli alzati) al ginocchio: la parte piatta e allargata del tetto
	band(m, ring(cf, hx, 0, hz, 1, lift, lift * 0.5), ring(cf, kx, ky, kz, 1, lift * 0.15, 0), thick, color, mat)
	-- 2) dal ginocchio al colmo
	local k = ring(cf, kx, ky, kz, 0, lift * 0.15, 0)
	local ridgeHalf: number
	if opts.style == "hip" then
		ridgeHalf = math.max(kx - kz, 0)
		local top = ring(cf, ridgeHalf, h, 0, 0, 0, 0)
		band(m, k, top, thick, color, mat)
	else
		ridgeHalf = kx
		local function p(x: number, y: number, z: number): Vector3
			return cf:PointToWorldSpace(Vector3.new(x, y, z))
		end
		-- falde davanti e dietro
		quad(m, k[1], k[2], p(kx, h, 0), p(-kx, h, 0), thick, color, mat)
		quad(m, k[3], k[4], p(-kx, h, 0), p(kx, h, 0), thick, color, mat)
		-- timpani sui lati corti, appena rientrati
		local g = opts.gableColor or TIMBER_DARK
		for _, s in { -1, 1 } do
			triangle(m, p(s * (kx - 0.3), ky + 0.1, -kz + 0.3), p(s * (kx - 0.3), ky + 0.1, kz - 0.3), p(s * (kx - 0.3), h - 0.2, 0), 0.4, g, M.WoodPlanks)
		end
	end
	if opts.ridge ~= false then
		-- colmo con le due punte che si arricciano all'insu'
		local top = cf * CFrame.new(0, h + 0.25, 0)
		if ridgeHalf > 0.5 then
			part(m, Vector3.new(ridgeHalf * 2 + 0.6, 0.9, 0.9), top, TILE_RIDGE, M.Slate)
		end
		for _, s in { -1, 1 } do
			local base = top * CFrame.new(s * ridgeHalf, 0, 0)
			part(m, Vector3.new(0.7, 1.8, 0.7), base * CFrame.new(s * 0.4, 0.7, 0) * CFrame.Angles(0, 0, -s * 0.5), TILE_RIDGE, M.Slate, true)
		end
	end
end

-- tettoia tra un piano e l'altro: solo la falda della gronda attorno alla casa
local function skirt(m: Instance, cf: CFrame, hx: number, hz: number, out: number, drop: number, color: Color3?, mat: Enum.Material?)
	local lift = math.min(hx, hz) * 0.12
	band(m, ring(cf, hx + out, -drop, hz + out, 0, lift, lift * 0.5), ring(cf, hx - 0.2, 0, hz - 0.2, 0, 0, 0), 0.5, color or TILE, mat or M.Slate)
end

------------------------------------------------------------------------------------------
-- dettagli

local function lightIn(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- lanterna rossa di carta appesa (in cima al filo): at = punto d'aggancio
local function redLantern(m: Instance, at: Vector3, size: number, light: boolean?)
	local body = part(m, Vector3.one * size * 1.15, CFrame.new(at - Vector3.new(0, size * 0.75, 0)), LANTERN_RED, M.Neon, true)
	body.Shape = Enum.PartType.Ball
	part(m, Vector3.new(size * 0.6, size * 0.12, size * 0.6), CFrame.new(at - Vector3.new(0, size * 0.18, 0)), GOLD, M.Metal, true)
	part(m, Vector3.new(size * 0.6, size * 0.12, size * 0.6), CFrame.new(at - Vector3.new(0, size * 1.32, 0)), GOLD, M.Metal, true)
	part(m, Vector3.new(0.12, size * 0.5, 0.12), CFrame.new(at - Vector3.new(0, size * 1.6, 0)), LANTERN_RED, M.Fabric, true)
	if light then
		lightIn(body, Color3.fromRGB(255, 110, 70), 14, 1.2)
	end
end

-- filo di lanterne tra due punti, con la pancia in giu'
local function lanternString(parent: Instance, a: Vector3, b: Vector3, count: number)
	local m = Instance.new("Model")
	m.Name = "FiloLanterne"
	m.Parent = parent
	local len = (b - a).Magnitude
	local sag = math.min(len * 0.12, 4)
	local function at(t: number): Vector3
		return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	local prev = a
	for k = 1, 4 do
		local p = at(k / 4)
		beam(m, prev, p, 0.1, 0.1, Color3.fromRGB(40, 30, 24), M.Fabric, true)
		prev = p
	end
	for k = 1, count do
		redLantern(m, at(k / (count + 1)), 1.4, k == math.ceil(count / 2))
	end
end

-- finestra di carta con la grata (sul lato -Z del cf)
local function paperWindow(m: Instance, cf: CFrame, w: number, h: number)
	part(m, Vector3.new(w + 0.6, h + 0.6, 0.3), cf * CFrame.new(0, 0, -0.05), TIMBER_DARK, M.Wood, true)
	part(m, Vector3.new(w, h, 0.3), cf * CFrame.new(0, 0, -0.15), PAPER, M.Neon, true)
	for _, x in { -w / 6, w / 6 } do
		part(m, Vector3.new(0.18, h, 0.2), cf * CFrame.new(x, 0, -0.35), TIMBER_DARK, M.Wood, true)
	end
	part(m, Vector3.new(w, 0.18, 0.2), cf * CFrame.new(0, 0, -0.35), TIMBER_DARK, M.Wood, true)
end

local function door(m: Instance, cf: CFrame, w: number, h: number, color: Color3)
	part(m, Vector3.new(w + 1, h + 0.8, 0.4), cf * CFrame.new(0, h / 2 + 0.2, -0.05), TIMBER_DARK, M.Wood, true)
	for _, s in { -1, 1 } do
		part(m, Vector3.new(w / 2 - 0.15, h, 0.3), cf * CFrame.new(s * w / 4, h / 2, -0.25), color, M.WoodPlanks, true)
	end
end

-- ringhiera tra due punti (corrimano, traversa bassa, colonnine)
local function railing(m: Instance, a: Vector3, b: Vector3, h: number, color: Color3)
	local up = Vector3.new(0, h, 0)
	beam(m, a + up, b + up, 0.35, 0.3, color, M.Wood)
	beam(m, a + up * 0.4, b + up * 0.4, 0.25, 0.25, color, M.Wood, true)
	local n = math.max(1, math.floor((b - a).Magnitude / 2.5))
	for k = 0, n do
		local p = a:Lerp(b, k / n)
		part(m, Vector3.new(0.3, h, 0.3), CFrame.new(p + up / 2), color, M.Wood, true)
	end
end

local function sign(m: Instance, cf: CFrame, w: number, h: number, text: string, bg: Color3, fg: Color3)
	local board = part(m, Vector3.new(w, h, 0.3), cf, bg, M.Wood, true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.4
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.TextColor3 = fg
	label.Text = text
	label.Parent = gui
end

------------------------------------------------------------------------------------------
-- edifici (cf = centro del pavimento, ingresso verso -Z)

export type HouseOpts = {
	w: number, -- larghezza (X)
	d: number, -- profondita' (Z)
	floors: number,
	plaster: boolean?, -- muri bianchi con travi scure invece del legno
	balcony: boolean?,
	lanterns: boolean?,
	shopSign: string?, -- bottega: piano terra aperto con l'insegna
	kit: string?, -- modello di Blender (ServerStorage.BorghiKit) da usare
}

local FLOOR_H = 10

------------------------------------------------------------------------------------------
-- modelli di Blender (ServerStorage.BorghiKit, vedi BorghiKit.luau): se ci sono si usano loro,
-- se no gli edifici qui sotto fatti di Part

-- misure del corpo di ogni casa del kit (come in tools/blender/borghi.py)
local KIT_HOUSES: { [string]: HouseOpts } = {
	CasaFenghuang = { w = 18, d = 16, floors = 2 }, -- con il ballatoio su due lati
	TorreFenghuang = { w = 18, d = 16, floors = 3 },
	CasaTe = { w = 16, d = 16, floors = 2 }, -- casa da te' / bottega con l'insegna
	CasaHuizhou = { w = 21, d = 22, floors = 1, plaster = true }, -- a corte
}
local SURNAMES = { "WANG", "LI", "ZHANG", "LIU", "CHEN", "YANG", "HUANG", "ZHAO", "WU", "ZHOU" }

local function kitModel(name: string): Model?
	local f = ServerStorage:FindFirstChild("BorghiKit")
	local m = f and f:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- Le case del kit erano piccolissime rispetto al personaggio (una machiya larga 12 studs):
-- si ingrandiscono qui, e i lotti (kitSpec, tryKit, minka) usano le misure gia' scalate
-- (2026-10-10, Mirko: "ancora piccole, falle in scala 4"): tutti gli edifici in scala S, i
-- piccoli oggetti (bancarelle, pozzi, lanterne) in scala S/2; le distanze della disposizione dei
-- borghi (tempio, ingressi, piazze, via del mercato) si moltiplicano per S
-- (2026-10-14, Mirko: "tutte le case giapponesi scalale a 3"): le case in scala H = 3, i
-- monumenti (pagoda, tempio, torii, portali, padiglione, torre del tamburo) restano in scala S
local S = 4
local H = 3
local HOUSE_SCALE: { [string]: number } = {
	Machiya = H,
	Kura = H,
	Chashitsu = H,
	Granaio = H,
	Minka = H,
	Ryokan = H,
	CasaFenghuang = H,
	TorreFenghuang = H,
	CasaTe = H,
	CasaHuizhou = H,
	Pescatore = H,
	Emporio = H,
	Pagoda = S,
	Tempio = S,
	Torii = S,
	Portale = S,
	Padiglione = S,
	TorreTamburo = S,
	Bancarella = S / 2,
	Pozzo = S / 2,
	LanternaPietra = S / 2,
}
local function houseScale(name: string): number
	return HOUSE_SCALE[name] or 1
end

local function fromKit(name: string, parent: Instance, cf: CFrame, scale: number?): Model?
	local t = kitModel(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	local s = (scale or 1) * houseScale(name)
	if math.abs(s - 1) > 0.01 then
		m:ScaleTo(s)
	end
	m:PivotTo(cf)
	-- da lontano (fuori dal raggio di streaming) resta visibile come una mesh leggera
	pcall(function()
		(m :: any).LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	m.Parent = parent
	return m
end

-- la tavola "SIGN" del modello con un testo (insegna, nome del borgo)
local function kitSign(m: Model, text: string)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name == "SIGN" then
			local s = p.Size
			-- la faccia grande che guarda come il modello (il davanti)
			local look = m:GetPivot().LookVector
			local best, bestDot = Enum.NormalId.Front, -2
			for _, n in Enum.NormalId:GetEnumItems() do
				local dir = p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(n))
				local area = if n == Enum.NormalId.Front or n == Enum.NormalId.Back then s.X * s.Y elseif n == Enum.NormalId.Left or n == Enum.NormalId.Right then s.Z * s.Y else s.X * s.Z
				local score = dir:Dot(look) + area * 0.001
				if score > bestDot then
					best, bestDot = n, score
				end
			end
			local gui = Instance.new("SurfaceGui")
			gui.Face = best
			gui.PixelsPerStud = 30
			gui.LightInfluence = 0.3
			gui.Parent = p
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(0.94, 0.86)
			label.Position = UDim2.fromScale(0.03, 0.07)
			label.Font = Enum.Font.Fantasy
			label.TextScaled = true
			label.TextColor3 = GOLD
			label.Text = text
			label.Parent = gui
		end
	end
end

-- una luce calda dentro la casa (dietro la finestra di carta piu' grande)
local function kitLight(m: Model, range: number)
	local best: BasePart? = nil
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name == "PAPER" and (not best or p.Size.Magnitude > (best :: BasePart).Size.Magnitude) then
			best = p
		end
	end
	if best then
		lightIn(best :: BasePart, WARM, range, 1.3)
	end
end

-- casa cinese di legno (diaojiaolou)
local function chineseHouse(parent: Instance, cf: CFrame, o: HouseOpts): Model
	if o.kit then
		local km = fromKit(o.kit, parent, cf)
		if km then
			kitLight(km, 20)
			if o.kit == "CasaHuizhou" then
				kitSign(km, SURNAMES[math.random(1, #SURNAMES)])
			end
			if o.shopSign then
				kitSign(km, o.shopSign)
			end
			return km
		end
	end
	local m = Instance.new("Model")
	m.Name = if o.shopSign then "Bottega" else "CasaCinese"
	local hx, hz = o.w / 2, o.d / 2
	local wall = if o.plaster then PLASTER else TIMBER
	local wallMat = if o.plaster then M.Plaster else M.WoodPlanks
	part(m, Vector3.new(o.w + 1, 0.8, o.d + 1), cf * CFrame.new(0, -0.4, 0), TIMBER_DARK, M.WoodPlanks)
	local y = 0
	for f = 1, o.floors do
		local grow = if f > 1 then 0.8 else 0 -- i piani di sopra sporgono un poco
		local fx, fz = hx + grow, hz + grow
		local base = cf * CFrame.new(0, y, 0)
		local body = part(m, Vector3.new(fx * 2, FLOOR_H, fz * 2), base * CFrame.new(0, FLOOR_H / 2, 0), wall, wallMat)
		body.Name = "Piano" .. f
		-- pilastri agli angoli e travi
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(m, Vector3.new(0.9, FLOOR_H, 0.9), base * CFrame.new(sx * fx, FLOOR_H / 2, sz * fz), TIMBER_DARK, M.Wood, true)
			end
		end
		part(m, Vector3.new(fx * 2 + 0.6, 0.7, fz * 2 + 0.6), base * CFrame.new(0, FLOOR_H - 0.35, 0), TIMBER_DARK, M.Wood, true)
		if o.plaster then
			part(m, Vector3.new(fx * 2 + 0.4, 0.5, fz * 2 + 0.4), base * CFrame.new(0, FLOOR_H * 0.45, 0), TIMBER_DARK, M.Wood, true)
		end
		local front = base * CFrame.new(0, 0, -fz)
		if f == 1 then
			if o.shopSign then
				-- bottega: bancone, tende (noren) e insegna
				part(m, Vector3.new(fx * 2 - 2, 7.4, 0.4), front * CFrame.new(0, 3.9, -0.1), Color3.fromRGB(30, 22, 18), M.Wood, true)
				part(m, Vector3.new(fx * 2 - 3, 3, 1.4), front * CFrame.new(0, 1.5, -0.8), TIMBER, M.WoodPlanks)
				for k = -2, 2 do
					part(m, Vector3.new(fx * 0.34, 2.6, 0.1), front * CFrame.new(k * fx * 0.36, 6.4, -0.5), if k % 2 == 0 then Color3.fromRGB(36, 52, 92) else Color3.fromRGB(150, 40, 36), M.Fabric, true)
				end
				sign(m, front * CFrame.new(0, 8.8, -0.6), math.min(fx * 1.6, 10), 1.6, o.shopSign, TIMBER_DARK, GOLD)
			else
				door(m, front, 4.6, 7.4, TIMBER)
				for _, s in { -1, 1 } do
					if fx > 5.5 then
						paperWindow(m, front * CFrame.new(s * (fx * 0.62 + 0.6), 5, 0), math.min(fx * 0.5, 3.4), 3)
					end
				end
			end
		else
			-- piani alti: finestre su tutti i lati
			local n = math.max(1, math.floor(fx * 2 / 6))
			for k = 1, n do
				local x = -fx + (k - 0.5) * fx * 2 / n
				paperWindow(m, front * CFrame.new(x, 5, 0), 3, 3.4)
				paperWindow(m, base * CFrame.new(x, 5, fz) * CFrame.Angles(0, math.pi, 0), 3, 3.4)
			end
		end
		for _, s in { -1, 1 } do
			paperWindow(m, base * CFrame.new(s * fx, 5, 0) * CFrame.Angles(0, -s * math.pi / 2, 0), 3, 3)
		end
		-- ballatoio sul davanti al secondo piano
		if f == o.floors and f > 1 and o.balcony then
			local bz = -fz - 3.2
			part(m, Vector3.new(fx * 2 + 1, 0.6, 3.6), base * CFrame.new(0, 0.3, -fz - 1.6), TIMBER, M.WoodPlanks)
			railing(m, (base * CFrame.new(-fx - 0.4, 0.6, bz)).Position, (base * CFrame.new(fx + 0.4, 0.6, bz)).Position, 3, TIMBER_DARK)
			for _, s in { -1, 1 } do
				railing(m, (base * CFrame.new(s * (fx + 0.4), 0.6, bz)).Position, (base * CFrame.new(s * (fx + 0.4), 0.6, -fz)).Position, 3, TIMBER_DARK)
				part(m, Vector3.new(0.6, FLOOR_H, 0.6), base * CFrame.new(s * (fx + 0.3), FLOOR_H / 2, bz), TIMBER_DARK, M.Wood, true)
				-- mensole sotto il ballatoio
				beam(m, (base * CFrame.new(s * fx * 0.7, -2.5, -fz)).Position, (base * CFrame.new(s * fx * 0.7, 0, bz)).Position, 0.4, 0.4, TIMBER_DARK, M.Wood, true)
			end
		end
		y += FLOOR_H
		if f < o.floors then
			skirt(m, cf * CFrame.new(0, y - 0.2, 0), fx, fz, 2.6, 2.2)
		end
	end
	-- il tetto copre anche il ballatoio (che sta sull'ultimo piano)
	local top = if o.floors > 1 then 0.8 else 0
	local bal = o.balcony == true and o.floors > 1
	local shift = if bal then 1.8 else 0
	local roofHz = hz + top + 3 + shift
	roof(m, cf * CFrame.new(0, y, -shift), hx + top + 3, roofHz, roofHz * 0.85, { style = "gable" })
	-- lanterne agli angoli del davanti e una luce calda alla porta
	if o.lanterns ~= false then
		for _, s in { -1, 1 } do
			redLantern(m, (cf * CFrame.new(s * (hx + 1.5), y - 0.4, -hz - top - shift * 2 - 1.2)).Position, 1.6, false)
		end
	end
	local glow = part(m, Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 8.5, -hz - 1), WARM, M.Neon, true)
	glow.Transparency = 1
	lightIn(glow, WARM, 18, 1.4)
	m.Parent = parent
	return m
end

-- minka giapponese: pavimento rialzato su pietre, veranda (engawa), pareti di shoji, grande
-- tetto di paglia
local function minka(parent: Instance, cf: CFrame, w: number, d: number): Model
	local km = fromKit("Minka", parent, cf)
	if km then
		kitLight(km, 18)
		return km
	end
	local m = Instance.new("Model")
	m.Name = "Minka"
	local hx, hz = w / 2, d / 2
	local lift = 2
	-- pietre e pavimento con la veranda tutto attorno
	for _, sx in { -1, 0, 1 } do
		for _, sz in { -1, 0, 1 } do
			part(m, Vector3.new(1.6, 2.4, 1.6), cf * CFrame.new(sx * (hx + 1.4), -0.2, sz * (hz + 1.4)), STONE, M.Slate, true)
		end
	end
	part(m, Vector3.new(w + 4.4, 0.7, d + 4.4), cf * CFrame.new(0, lift - 0.35, 0), TIMBER, M.WoodPlanks)
	-- gradino davanti
	part(m, Vector3.new(4, 1, 1.6), cf * CFrame.new(0, 0.5, -hz - 3), STONE, M.Slate)
	local base = cf * CFrame.new(0, lift, 0)
	local h = 9
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, h / 2, 0), PLASTER, M.Plaster)
	-- pilastri e travi scure
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, Vector3.new(0.8, h, 0.8), base * CFrame.new(sx * hx, h / 2, sz * hz), TIMBER_DARK, M.Wood, true)
			-- pilastri della veranda
			part(m, Vector3.new(0.6, h, 0.6), base * CFrame.new(sx * (hx + 1.9), h / 2, sz * (hz + 1.9)), TIMBER_DARK, M.Wood, true)
		end
	end
	part(m, Vector3.new(w + 0.4, 0.8, d + 0.4), base * CFrame.new(0, h - 0.4, 0), TIMBER_DARK, M.Wood, true)
	-- pannelli shoji sul davanti (uno aperto: e' la porta)
	local n = math.max(3, math.floor(w / 3.2))
	for k = 1, n do
		local x = -hx + (k - 0.5) * w / n
		local cfp = base * CFrame.new(x, 3.6, -hz)
		if k == math.ceil(n / 2) then
			part(m, Vector3.new(w / n - 0.3, 7, 0.3), cfp * CFrame.new(0, 0, -0.15), Color3.fromRGB(34, 26, 20), M.Wood, true)
		else
			part(m, Vector3.new(w / n - 0.3, 7, 0.3), cfp * CFrame.new(0, 0, -0.15), PAPER, M.Neon, true)
			part(m, Vector3.new(0.18, 7, 0.2), cfp * CFrame.new(0, 0, -0.35), TIMBER_DARK, M.Wood, true)
			for _, yy in { -1.8, 0.6, 2.8 } do
				part(m, Vector3.new(w / n - 0.3, 0.16, 0.2), cfp * CFrame.new(0, yy, -0.35), TIMBER_DARK, M.Wood, true)
			end
		end
		part(m, Vector3.new(0.3, 7.2, 0.4), cfp * CFrame.new(w / n / 2, 0, -0.2), TIMBER_DARK, M.Wood, true)
	end
	for _, s in { -1, 1 } do
		paperWindow(m, base * CFrame.new(s * hx, 5, 0) * CFrame.Angles(0, -s * math.pi / 2, 0), 4, 3)
	end
	-- tetto di paglia spesso, ripido, con la cresta
	roof(m, base * CFrame.new(0, h, 0), hx + 3.6, hz + 3.6, (hz + 3.6) * 1.15, { style = "gable", color = THATCH, material = M.Grass, lift = 0.4, thick = 1.4, gableColor = TIMBER_DARK, ridge = false })
	local ridgeY = h + (hz + 3.6) * 1.15
	part(m, Vector3.new(w * 0.62, 1.6, 2.2), base * CFrame.new(0, ridgeY + 0.3, 0), Color3.fromRGB(110, 88, 56), M.Grass)
	for k = -2, 2 do
		part(m, Vector3.new(0.5, 0.6, 3.2), base * CFrame.new(k * w * 0.13, ridgeY + 1.2, 0), TIMBER_DARK, M.Wood, true)
	end
	local glow = part(m, Vector3.new(0.4, 0.4, 0.4), base * CFrame.new(0, 7, -hz - 2), WARM, M.Neon, true)
	glow.Transparency = 1
	lightIn(glow, WARM, 16, 1.2)
	m.Parent = parent
	return m
end

-- pagoda a "tiers" piani su una base di pietra con le scale
local function pagoda(parent: Instance, cf: CFrame, size: number, tiers: number): Model
	local km = fromKit("Pagoda", parent, cf, size / 13)
	if km then
		return km
	end
	local m = Instance.new("Model")
	m.Name = "Pagoda"
	local h0 = 3
	part(m, Vector3.new(size + 10, h0, size + 10), cf * CFrame.new(0, h0 / 2 - 1, 0), STONE, M.Cobblestone)
	part(m, Vector3.new(6, h0 * 0.66, 3), cf * CFrame.new(0, h0 * 0.33 - 1, -size / 2 - 6.5), STONE, M.Cobblestone)
	local y = h0 - 1
	local s = size
	for t = 1, tiers do
		local th = if t == 1 then 11 else 8
		local base = cf * CFrame.new(0, y, 0)
		part(m, Vector3.new(s, th, s), base * CFrame.new(0, th / 2, 0), PLASTER, M.Plaster)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(m, Vector3.new(1, th, 1), base * CFrame.new(sx * s / 2, th / 2, sz * s / 2), LACQUER, M.SmoothPlastic, true)
			end
		end
		-- porte/finestre sui 4 lati
		for k = 0, 3 do
			local side = base * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -s / 2)
			if t == 1 and k == 0 then
				door(m, side, 4.4, 7, LACQUER)
			else
				paperWindow(m, side * CFrame.new(0, th * 0.55, 0), math.min(s * 0.35, 3.4), th * 0.4)
			end
		end
		y += th
		if t < tiers then
			skirt(m, cf * CFrame.new(0, y, 0), s / 2, s / 2, 3 + s * 0.22, 3)
			-- lanterne agli angoli del tetto
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					redLantern(m, (cf * CFrame.new(sx * (s / 2 + 3.6), y - 2.2, sz * (s / 2 + 3.6))).Position, 1.2, t == 1)
				end
			end
		end
		s *= 0.82
	end
	roof(m, cf * CFrame.new(0, y, 0), s / 0.82 / 2 + 4, s / 0.82 / 2 + 4, s / 0.82 * 0.6 + 2, { style = "hip", ridge = false })
	-- pinnacolo dorato con gli anelli
	local tip = cf * CFrame.new(0, y + s / 0.82 * 0.6 + 2, 0)
	cylinder(m, tip.Position, (tip * CFrame.new(0, 9, 0)).Position, 0.6, GOLD, M.Metal, true)
	for k = 1, 5 do
		local r = part(m, Vector3.new(0.5, 2.2 - k * 0.25, 2.2 - k * 0.25), tip * CFrame.new(0, 1 + k * 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD, M.Metal, true)
		r.Shape = Enum.PartType.Cylinder
	end
	local ball = part(m, Vector3.one * 1.4, tip * CFrame.new(0, 9.4, 0), GOLD, M.Metal, true)
	ball.Shape = Enum.PartType.Ball
	m.Parent = parent
	return m
end

-- sala del tempio: piattaforma, colonnato rosso davanti, doppio tetto
local function templeHall(parent: Instance, cf: CFrame, w: number, d: number): Model
	local km = fromKit("Tempio", parent, cf, w / 28)
	if km then
		kitSign(km, "TEMPLE")
		kitLight(km, 24)
		return km
	end
	local m = Instance.new("Model")
	m.Name = "Tempio"
	local hx, hz = w / 2, d / 2
	part(m, Vector3.new(w + 10, 3, d + 10), cf * CFrame.new(0, 0.5, 0), STONE, M.Cobblestone)
	for k = 0, 2 do
		part(m, Vector3.new(10, 1, 1.4), cf * CFrame.new(0, 0.5 + k * 1 - 1, -hz - 5.6 - (2 - k) * 1.4), STONE, M.Cobblestone)
	end
	local base = cf * CFrame.new(0, 2, 0)
	local h = 13
	part(m, Vector3.new(w - 4, h, d - 4), base * CFrame.new(0, h / 2, 1), LACQUER, M.SmoothPlastic)
	-- colonnato
	local n = 6
	for k = 0, n - 1 do
		local x = -hx + 1 + k * (w - 2) / (n - 1)
		for _, z in { -hz + 0.5, hz - 0.5 } do
			cylinder(m, (base * CFrame.new(x, 0, z)).Position, (base * CFrame.new(x, h, z)).Position, 1.3, LACQUER, M.SmoothPlastic)
		end
	end
	for k = 1, n - 2 do
		local x = -hx + 1 + k * (w - 2) / (n - 1)
		paperWindow(m, base * CFrame.new(x, 6, -hz + 2.5), (w - 2) / (n - 1) - 2, 8)
	end
	part(m, Vector3.new(w + 1, 1.2, d + 1), base * CFrame.new(0, h - 0.6, 0), TIMBER_DARK, M.Wood, true)
	part(m, Vector3.new(w, 0.8, 0.5), base * CFrame.new(0, h - 2, -hz), GOLD, M.Metal, true)
	skirt(m, base * CFrame.new(0, h, 0), hx, hz, 5, 3)
	part(m, Vector3.new(w - 6, 5, d - 6), base * CFrame.new(0, h + 2.5, 0), LACQUER, M.SmoothPlastic)
	roof(m, base * CFrame.new(0, h + 5, 0), hx + 1, hz + 1, d * 0.45, { style = "gable", lift = 2.2 })
	for _, s in { -1, 1 } do
		redLantern(m, (base * CFrame.new(s * (hx - 1), h - 1.5, -hz - 1.5)).Position, 2, true)
	end
	m.Parent = parent
	return m
end

local function torii(parent: Instance, cf: CFrame, w: number, h: number)
	if fromKit("Torii", parent, cf, w / 12) then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Torii"
	for _, s in { -1, 1 } do
		cylinder(m, (cf * CFrame.new(s * w / 2, -1, 0)).Position, (cf * CFrame.new(s * w / 2, h, 0)).Position, 1.5, LACQUER, M.SmoothPlastic)
		part(m, Vector3.new(2.2, 1.4, 2.2), cf * CFrame.new(s * w / 2, 0.4, 0), Color3.fromRGB(30, 28, 26), M.Slate)
	end
	part(m, Vector3.new(w + 3, 1, 1.2), cf * CFrame.new(0, h * 0.78, 0), LACQUER, M.SmoothPlastic)
	-- trave in cima, nera, con le punte che salgono
	part(m, Vector3.new(w + 2, 1.3, 1.8), cf * CFrame.new(0, h + 0.5, 0), LACQUER, M.SmoothPlastic)
	part(m, Vector3.new(w * 0.7, 1, 2.2), cf * CFrame.new(0, h + 1.6, 0), Color3.fromRGB(26, 24, 24), M.SmoothPlastic)
	for _, s in { -1, 1 } do
		part(m, Vector3.new(w * 0.32, 1, 2.2), cf * CFrame.new(s * (w * 0.35 + w * 0.14), h + 1.9, 0) * CFrame.Angles(0, 0, s * 0.12), Color3.fromRGB(26, 24, 24), M.SmoothPlastic)
	end
	part(m, Vector3.new(1.4, h * 0.2, 0.4), cf * CFrame.new(0, h * 0.88, -0.6), Color3.fromRGB(26, 24, 24), M.SmoothPlastic, true)
	m.Parent = parent
	return m
end

-- portale cinese (paifang) col nome del borgo
local function paifang(parent: Instance, cf: CFrame, w: number, name: string)
	local km = fromKit("Portale", parent, cf, w / 22)
	if km then
		kitSign(km, name)
		return
	end
	local m = Instance.new("Model")
	m.Name = "Portale"
	local h = 15
	for _, x in { -w / 2, -w / 6, w / 6, w / 2 } do
		part(m, Vector3.new(1.4, h, 1.4), cf * CFrame.new(x, h / 2, 0), LACQUER, M.SmoothPlastic)
		part(m, Vector3.new(2.6, 1.6, 2.6), cf * CFrame.new(x, 0.6, 0), STONE, M.Slate)
	end
	part(m, Vector3.new(w + 1.4, 1.4, 1.4), cf * CFrame.new(0, h - 0.7, 0), LACQUER, M.SmoothPlastic)
	part(m, Vector3.new(w + 1.4, 1, 1.4), cf * CFrame.new(0, h - 4.5, 0), LACQUER, M.SmoothPlastic)
	sign(m, cf * CFrame.new(0, h - 2.6, -0.85), w / 3 * 0.95, 2.6, name, Color3.fromRGB(26, 34, 52), GOLD)
	roof(m, cf * CFrame.new(0, h, 0), w / 6 + 2.4, 3, 3.6, { style = "gable", lift = 1.2 })
	for _, s in { -1, 1 } do
		roof(m, cf * CFrame.new(s * w / 3, h - 2.4, 0), w / 6 + 1.2, 2.6, 2.8, { style = "gable", lift = 1 })
	end
	for _, s in { -1, 1 } do
		redLantern(m, (cf * CFrame.new(s * w / 3, h - 4, -0.9)).Position, 1.8, true)
	end
	m.Parent = parent
end

-- padiglione quadrato aperto con le panche
local function pavilion(parent: Instance, cf: CFrame, s: number)
	if fromKit("Padiglione", parent, cf, s / 11) then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Padiglione"
	local h = 9
	part(m, Vector3.new(s + 3, 1.2, s + 3), cf * CFrame.new(0, 0.2, 0), STONE, M.Cobblestone)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cylinder(m, (cf * CFrame.new(sx * s / 2, 0.8, sz * s / 2)).Position, (cf * CFrame.new(sx * s / 2, h, sz * s / 2)).Position, 1, LACQUER, M.SmoothPlastic)
		end
	end
	for k = 1, 3 do
		local side = cf * CFrame.Angles(0, k * math.pi / 2, 0)
		local seat = part(m, Vector3.new(s - 1, 0.5, 1.4), side * CFrame.new(0, 2.6, -s / 2 + 0.9), TIMBER, M.WoodPlanks)
		seat.Name = "Panca"
		part(m, Vector3.new(s - 1, 1.8, 0.3), side * CFrame.new(0, 1.6, -s / 2 + 0.3), LACQUER, M.SmoothPlastic, true)
	end
	part(m, Vector3.new(s + 0.6, 0.8, s + 0.6), cf * CFrame.new(0, h - 0.4, 0), TIMBER_DARK, M.Wood, true)
	roof(m, cf * CFrame.new(0, h, 0), s / 2 + 2.6, s / 2 + 2.6, s * 0.55 + 1, { style = "hip", lift = 1.4, ridge = false })
	local knob = part(m, Vector3.one * 1.2, cf * CFrame.new(0, h + s * 0.55 + 1.5, 0), GOLD, M.Metal, true)
	knob.Shape = Enum.PartType.Ball
	redLantern(m, (cf * CFrame.new(0, h - 0.8, 0)).Position, 1.6, true)
	m.Parent = parent
end

local function stoneLantern(parent: Instance, cf: CFrame)
	local km = fromKit("LanternaPietra", parent, cf)
	if km then
		kitLight(km, 12)
		return
	end
	local m = Instance.new("Model")
	m.Name = "LanternaPietra"
	part(m, Vector3.new(2.2, 0.8, 2.2), cf * CFrame.new(0, 0.2, 0), STONE_DARK, M.Slate)
	cylinder(m, (cf * CFrame.new(0, 0.6, 0)).Position, (cf * CFrame.new(0, 3.4, 0)).Position, 0.9, STONE_DARK, M.Slate)
	part(m, Vector3.new(2, 0.5, 2), cf * CFrame.new(0, 3.6, 0), STONE_DARK, M.Slate)
	local fire = part(m, Vector3.new(1.2, 1.3, 1.2), cf * CFrame.new(0, 4.5, 0), WARM, M.Neon, true)
	lightIn(fire, WARM, 12, 1)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, Vector3.new(0.35, 1.3, 0.35), cf * CFrame.new(sx * 0.7, 4.5, sz * 0.7), STONE_DARK, M.Slate, true)
		end
	end
	roof(m, cf * CFrame.new(0, 5.2, 0), 1.7, 1.7, 1.2, { style = "hip", color = STONE_DARK, lift = 0.3, thick = 0.4, ridge = false })
	part(m, Vector3.new(0.6, 0.8, 0.6), cf * CFrame.new(0, 6.6, 0), STONE_DARK, M.Slate, true)
	m.Parent = parent
end

------------------------------------------------------------------------------------------
-- dove costruire

local BAD_GROUND = { [M.Cobblestone] = true, [M.Sand] = true, [M.Sandstone] = true, [M.Glacier] = true, [M.Snow] = true, [M.Ice] = true }
local TREES = { CherryTree = true, OldTree = true, PineTree = true, OakTree = true }

-- per i pali delle palafitte: il fondo sotto l'acqua
local noWater = RaycastParams.new()
noWater.FilterType = Enum.RaycastFilterType.Include
noWater.FilterDescendantsInstances = { workspace.Terrain }
noWater.IgnoreWater = true

type Probe = { y: number, water: boolean, mat: Enum.Material }
local function probe(x: number, z: number): Probe?
	local hit = workspace:Raycast(Vector3.new(x, 3000, z), Vector3.new(0, -3300, 0), terrainOnly)
	if not hit then
		return nil
	end
	return { y = hit.Position.Y, water = hit.Material == M.Water, mat = hit.Material }
end

local function bed(x: number, z: number, fromY: number): number
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -120, 0), noWater)
	return if hit then hit.Position.Y else fromY - 40
end

local CELL = 40
type Circle = { p: Vector3, r: number }
type Lot = { cf: CFrame, low: number, stilts: boolean }
type Ctx = {
	rng: Random,
	grid: { [string]: { Vector3 } },
	keepOut: { Circle },
	placed: { Circle }, -- edifici gia' messi (per non sovrapporli e per togliere gli alberi)
	fronts: { Vector3 }, -- davanti alle case del borgo in costruzione (fili di lanterne, sentieri)
	paths: { { Vector3 } },
	folder: Instance,
	roadCells: { [string]: boolean }?, -- celle di 16 stud con la strada (per togliere gli alberi)
}

-- tutto quello che c'e' gia' nella mappa: villaggio, palafitte, zone a tema, minerali, sentiero...
local function obstacleGrid(): { [string]: { Vector3 } }
	local grid: { [string]: { Vector3 } } = {}
	for _, n in { "Village", "Lakeside", "shop", "Tutorial", "Landmarks", "ZoneATema", "Obstacles", "ValleGas", "Ores", "MapMarkers", "Glacier" } do
		local f = workspace:FindFirstChild(n)
		for _, d in (if f then f:GetDescendants() else {}) :: { Instance } do
			if d:IsA("BasePart") then
				local p = (d :: BasePart).Position
				local k = math.floor(p.X / CELL) .. "," .. math.floor(p.Z / CELL)
				local list = grid[k]
				if not list then
					list = {}
					grid[k] = list
				end
				table.insert(list, p)
			end
		end
	end
	return grid
end

local function blocked(ctx: Ctx, p: Vector3, r: number, body: number?): boolean
	for _, c in ctx.keepOut do
		if Vector2.new(p.X - c.p.X, p.Z - c.p.Z).Magnitude < c.r + r then
			return true
		end
	end
	for _, c in ctx.placed do
		if Vector2.new(p.X - c.p.X, p.Z - c.p.Z).Magnitude < c.r + (body or r) + 2 then
			return true
		end
	end
	local cx, cz = math.floor(p.X / CELL), math.floor(p.Z / CELL)
	local span = math.ceil(r / CELL)
	for i = -span, span do
		for j = -span, span do
			for _, q in ctx.grid[(cx + i) .. "," .. (cz + j)] or {} do
				if Vector2.new(q.X - p.X, q.Z - p.Z).Magnitude < r then
					return true
				end
			end
		end
	end
	return false
end

-- un lotto piano (o quasi) per un edificio di mezze misure hx, hz (gia' con le gronde) che
-- guarda verso "facing". Con allowStilts il lotto puo' stare sul pendio o in parte sull'acqua.
local function fitLot(ctx: Ctx, x: number, z: number, facing: Vector3, hx: number, hz: number, allowStilts: boolean?, body: number?): Lot?
	local look = Vector3.new(facing.X, 0, facing.Z)
	if look.Magnitude < 0.01 then
		return nil
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis)
	local c = Vector3.new(x, 0, z)
	if blocked(ctx, c, math.max(hx, hz), body) then
		return nil
	end
	local hi, lo, water = -math.huge, math.huge, 0
	for i = -1, 1 do
		for j = -1, 1 do
			local p = c + right * (i * hx) + look * (j * hz)
			local h = probe(p.X, p.Z)
			if not h or (BAD_GROUND[h.mat] and not (allowStilts and (h.mat == M.Sand or h.mat == M.Sandstone))) then
				return nil
			end
			if h.water then
				water += 1
			end
			hi, lo = math.max(hi, h.y), math.min(lo, h.y)
		end
	end
	if water > 0 and not allowStilts then
		return nil
	end
	if water > 4 or hi - lo > (if allowStilts then 22 else 6) then
		return nil
	end
	local pos = Vector3.new(x, hi + (if water > 0 then 3.5 else 0.8), z)
	return { cf = CFrame.lookAt(pos, pos + look), low = lo, stilts = water > 0 or hi - lo > 3.5 }
end

-- sotto l'edificio: basamento di pietra fino a terra, o palafitte (pali fino al fondo)
local function foundation(m: Instance, lot: Lot, hx: number, hz: number, top: number)
	local cf = lot.cf
	if not lot.stilts then
		local h = top - lot.low + 2
		if h > 0.6 then
			part(m, Vector3.new(hx * 2 + 1.2, h, hz * 2 + 1.2), cf.Rotation + Vector3.new(cf.X, top - h / 2, cf.Z), STONE, M.Cobblestone)
		end
		return
	end
	local tops = {}
	for i = -1, 1 do
		for j = -1, 1 do
			local t = (cf * CFrame.new(i * (hx - 0.6), 0, j * (hz - 0.6))).Position
			local bottom = bed(t.X, t.Z, top) - 1.5
			local a = Vector3.new(t.X, top, t.Z)
			cylinder(m, a, Vector3.new(t.X, bottom, t.Z), 1.3, TIMBER_DARK, M.Wood)
			part(m, Vector3.new(2, 1.2, 2), CFrame.new(t.X, bottom + 1.1, t.Z), STONE_DARK, M.Slate, true)
			tops[(i + 2) * 10 + j + 2] = { a = a, b = Vector3.new(t.X, bottom, t.Z) }
		end
	end
	-- traverse tra i pali del giro esterno a meta' altezza
	for _, pair in { { 11, 13 }, { 31, 33 }, { 11, 31 }, { 13, 33 } } do
		local p0, p1 = tops[pair[1]], tops[pair[2]]
		local y = math.max(p0.b.Y, p1.b.Y) + (top - math.max(p0.b.Y, p1.b.Y)) * 0.45
		if top - y > 2.5 then
			beam(m, Vector3.new(p0.a.X, y, p0.a.Z), Vector3.new(p1.a.X, y, p1.a.Z), 0.6, 0.6, TIMBER_DARK, M.Wood, true)
		end
	end
	part(m, Vector3.new(hx * 2, 0.8, hz * 2), cf.Rotation + Vector3.new(cf.X, top - 0.4, cf.Z), TIMBER_DARK, M.WoodPlanks)
end

local function record(ctx: Ctx, lot: Lot, body: number, frontDepth: number)
	table.insert(ctx.placed, { p = lot.cf.Position, r = body })
	table.insert(ctx.fronts, (lot.cf * CFrame.new(0, 0, -frontDepth)).Position)
end

-- tipi di casa (misure a caso)
local function kitSpec(name: string): HouseOpts?
	local k = KIT_HOUSES[name]
	if not k or not kitModel(name) then
		return nil
	end
	local s = houseScale(name)
	return { w = k.w * s, d = k.d * s, floors = k.floors, balcony = k.balcony, plaster = k.plaster, kit = name }
end

local function chineseSpec(rng: Random, tall: boolean?): HouseOpts
	-- con i modelli di Blender: uno dei cinque tipi di casa
	local pool = if tall then { "CasaFenghuang", "TorreFenghuang", "CasaFenghuang", "TorreFenghuang", "CasaHuizhou" } else { "CasaFenghuang", "CasaHuizhou", "CasaFenghuang", "TorreFenghuang" }
	local fromPool = kitSpec(pool[rng:NextInteger(1, #pool)])
	if fromPool then
		return fromPool
	end
	local floors = if tall then rng:NextInteger(2, 3) else (if rng:NextNumber() < 0.3 then 1 else rng:NextInteger(2, 3))
	return {
		w = rng:NextInteger(5, 7) * 2,
		d = rng:NextInteger(9, 12),
		floors = floors,
		plaster = rng:NextNumber() < 0.35,
		balcony = floors > 1 and rng:NextNumber() < 0.75,
	}
end

local function buildChinese(ctx: Ctx, lot: Lot, o: HouseOpts)
	local m = chineseHouse(ctx.folder, lot.cf, o)
	foundation(m, lot, o.w / 2 + (if o.floors > 1 then 0.8 else 0), o.d / 2 + (if o.floors > 1 then 0.8 else 0), lot.cf.Y - 0.8)
end

-- prova a mettere una casa cinese in (x, z) che guarda verso facing
local function tryChinese(ctx: Ctx, x: number, z: number, facing: Vector3, o: HouseOpts, stilts: boolean?): Lot?
	local hx, hz = o.w / 2 + 3, o.d / 2 + 3 + (if o.balcony then 2 else 0)
	local body = math.max(o.w, o.d) / 2 + 1.5
	local lot = fitLot(ctx, x, z, facing, hx, hz, stilts, body)
	if lot then
		buildChinese(ctx, lot, o)
		record(ctx, lot, body, o.d / 2 + (if o.balcony and o.floors > 1 then 5 else 1.5))
	end
	return lot
end

-- un modello qualsiasi del kit su un lotto grande quanto lui (misure dagli attributi Width/Depth
-- che mette BorghiKit), col basamento sotto se il terreno scende
local function tryKit(ctx: Ctx, name: string, x: number, z: number, facing: Vector3, stilts: boolean?): Lot?
	local t = kitModel(name)
	if not t then
		return nil
	end
	local hx = ((t:GetAttribute("Width") :: number?) or 16) / 2 * houseScale(name)
	local hz = ((t:GetAttribute("Depth") :: number?) or 16) / 2 * houseScale(name)
	local body = math.max(hx, hz) - 1
	local lot = fitLot(ctx, x, z, facing, hx, hz, stilts, body)
	if not lot then
		return nil
	end
	local m = fromKit(name, ctx.folder, lot.cf - Vector3.new(0, 0.5, 0))
	if not m then
		return nil
	end
	kitLight(m, 18)
	foundation(m, lot, hx - 2, hz - 2, lot.cf.Y - 1.0)
	record(ctx, lot, body, hz)
	return lot
end

-- case giapponesi del kit (la minka resta la piu' comune)
local JAPANESE = { "Machiya", "Machiya", "Kura", "Ryokan", "Granaio", "Chashitsu" }

local function tryMinka(ctx: Ctx, x: number, z: number, facing: Vector3): Lot?
	-- con i modelli di Blender: spesso una delle altre case (machiya, kura, ryokan...)
	if kitModel("Machiya") and ctx.rng:NextNumber() < 0.55 then
		local lot = tryKit(ctx, JAPANESE[ctx.rng:NextInteger(1, #JAPANESE)], x, z, facing)
		if lot then
			return lot
		end
	end
	local w, d = ctx.rng:NextInteger(14, 19), ctx.rng:NextInteger(10, 13)
	if kitModel("Minka") then
		-- la minka di Blender (piu' la veranda, che sta nel margine)
		w, d = 18 * houseScale("Minka"), 12 * houseScale("Minka")
	end
	local hx, hz = w / 2 + 4, d / 2 + 4
	local body = math.max(w, d) / 2 + 3
	local lot = fitLot(ctx, x, z, facing, hx, hz, false, body)
	if lot then
		local cf = lot.cf - Vector3.new(0, 0.5, 0)
		local m = minka(ctx.folder, cf, w, d)
		foundation(m, { cf = cf, low = lot.low, stilts = false }, w / 2 + 2.4, d / 2 + 2.4, cf.Y - 1.3)
		record(ctx, lot, body, d / 2 + 3.5)
	end
	return lot
end

------------------------------------------------------------------------------------------
-- disposizioni

local function ground(x: number, z: number, facing: Vector3): CFrame?
	local h = probe(x, z)
	if not h or h.water then
		return nil
	end
	local p = Vector3.new(x, h.y, z)
	return CFrame.lookAt(p, p + Vector3.new(facing.X, 0, facing.Z))
end

-- sentiero dipinto sul terreno (cambia solo il materiale, non la forma)
local PAINT_FROM = { M.Grass, M.LeafyGrass, M.Ground, M.Mud, M.Rock }
local function paint(a: Vector3, b: Vector3, width: number, mat: Enum.Material)
	local len = Vector2.new(b.X - a.X, b.Z - a.Z).Magnitude
	local steps = math.max(1, math.ceil(len / 5))
	for k = 0, steps do
		local p = a:Lerp(b, k / steps)
		local h = probe(p.X, p.Z)
		if h and not h.water then
			local r = Region3.new(Vector3.new(p.X - width / 2, h.y - 3, p.Z - width / 2), Vector3.new(p.X + width / 2, h.y + 1.5, p.Z + width / 2)):ExpandToGrid(4)
			for _, from in PAINT_FROM do
				workspace.Terrain:ReplaceMaterial(r, 4, from, mat)
			end
		end
	end
end

-- fili di lanterne tra le case vicine (all'altezza delle gronde basse)
local function stringLanterns(ctx: Ctx, minD: number, maxD: number, max: number)
	local used = {}
	local made = 0
	for i, a in ctx.fronts do
		if made >= max then
			break
		end
		local best, bestD = nil, math.huge
		for j, b in ctx.fronts do
			local d = (a - b).Magnitude
			if j ~= i and not used[j] and d > minD and d < maxD and d < bestD and math.abs(a.Y - b.Y) < 8 then
				best, bestD = j, d
			end
		end
		if best then
			used[i], used[best] = true, true
			lanternString(ctx.folder, a + Vector3.new(0, 9.5, 0), ctx.fronts[best] + Vector3.new(0, 9.5, 0), math.clamp(math.floor(bestD / 6), 2, 6))
			made += 1
		end
	end
end

-- ingresso del borgo verso il campo base: portale cinese col nome o torii col cartello
local function entrance(ctx: Ctx, center: Vector3, radius: number, name: string, japanese: boolean)
	local hub = workspace:FindFirstChild("MapMarkers") and (workspace :: any).MapMarkers:FindFirstChild("HubSpawn")
	local toward = if hub then (hub.Position - center) else Vector3.xAxis
	toward = Vector3.new(toward.X, 0, toward.Z).Unit
	for k = 0, 8 do
		local d = radius + 6 * S + k * 6 * S
		local p = center + toward * d
		local cf = ground(p.X, p.Z, toward)
		if cf and not blocked(ctx, p, 13 * S) then
			if japanese then
				torii(ctx.folder, cf, 12, 14)
				sign(ctx.folder, cf * CFrame.new(9 * S, 2.25 * S, -1), 4.2 * S, 1.1 * S, name, TIMBER_DARK, Color3.fromRGB(245, 235, 210))
				part(ctx.folder, Vector3.new(0.3 * S, 2.25 * S, 0.3 * S), cf * CFrame.new(9 * S, 1.1 * S, -0.8), TIMBER_DARK, M.Wood, true)
			else
				paifang(ctx.folder, cf, 22, name)
			end
			table.insert(ctx.placed, { p = p, r = 13 * S })
			table.insert(ctx.paths, { p, center })
			return
		end
	end
end

-- borgo a gruppi: le case attorno a una piazza, l'ingresso verso la piazza
local function clusterVillage(ctx: Ctx, center: Vector3, radius: number, count: number, japanese: boolean, square: boolean?)
	local rng = ctx.rng
	local made = 0
	for _ = 1, count * 30 do
		if made >= count then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = radius * (0.35 + 0.65 * math.sqrt(rng:NextNumber()))
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local toCenter = (Vector3.new(center.X, 0, center.Z) - Vector3.new(x, 0, z)).Unit
		local facing = (CFrame.Angles(0, rng:NextNumber(-0.35, 0.35), 0) * toCenter)
		local ok = if japanese then tryMinka(ctx, x, z, facing) else tryChinese(ctx, x, z, facing, chineseSpec(rng))
		if ok then
			made += 1
			task.wait()
		end
	end
	-- piazza: padiglione (o lanterne di pietra) al centro
	local cf = ground(center.X, center.Z, Vector3.zAxis)
	-- borgo cinese grande: la torre del tamburo in piazza; piccolo: il pozzo
	if square ~= false and cf and not japanese and kitModel("TorreTamburo") and radius >= 110 and tryKit(ctx, "TorreTamburo", center.X, center.Z, Vector3.zAxis) then
		square = false
	elseif square ~= false and cf and kitModel("Pozzo") and not blocked(ctx, center, 9 * S / 2) then
		fromKit("Pozzo", ctx.folder, cf)
		table.insert(ctx.placed, { p = center, r = 6 * S / 2 })
		if japanese then
			for k = 0, 3 do
				stoneLantern(ctx.folder, cf * CFrame.Angles(0, k * math.pi / 2 + math.pi / 4, 0) * CFrame.new(0, 0, -7 * S / 2))
			end
		end
		square = false
	end
	if square ~= false and cf and not blocked(ctx, center, 9 * S) then
		if japanese then
			for k = 0, 3 do
				local p = cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -5 * S / 2)
				stoneLantern(ctx.folder, p)
			end
		else
			pavilion(ctx.folder, cf, 10)
		end
		table.insert(ctx.placed, { p = center, r = 9 * S })
	end
	for _, f in ctx.fronts do
		table.insert(ctx.paths, { f, center })
	end
	return made
end

-- via del mercato: due file di botteghe e case che si guardano, fili di lanterne sopra la via,
-- portali alle due estremita'
local SHOPS = { "TEA HOUSE", "NOODLES", "SILK", "DUMPLINGS", "HERBS", "LANTERNS", "POTTERY", "RICE WINE", "MOONCAKES", "JADE" }
local function streetVillage(ctx: Ctx, a: Vector3, b: Vector3, name: string)
	local rng = ctx.rng
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = dir.Magnitude
	dir = dir.Unit
	local side = dir:Cross(Vector3.yAxis)
	local half = 9 * S * 0.6 -- mezza larghezza della via
	local rows: { [number]: { Vector3 } } = { [-1] = {}, [1] = {} }
	local shopIndex = 0
	for _, s in { -1, 1 } do
		local t = 4
		while t < len - 6 do
			local o = chineseSpec(rng, true)
			if not o.kit then
				o.balcony = rng:NextNumber() < 0.6
			end
			if rng:NextNumber() < 0.45 then
				shopIndex += 1
				o = kitSpec("CasaTe") or o
				o.shopSign = SHOPS[(shopIndex - 1) % #SHOPS + 1]
				o.floors = 2
			end
			local hz = o.d / 2 + 3 + (if o.balcony then 2 else 0)
			local p = a + dir * (t + o.w / 2) + side * s * (half + hz)
			local lot = tryChinese(ctx, p.X, p.Z, -side * s, o)
			if lot then
				table.insert(rows[s], (lot.cf * CFrame.new(0, 0, -(o.d / 2 + 1.5))).Position)
				-- davanti alle botteghe una bancarella sul bordo della via
				if o.shopSign and kitModel("Bancarella") then
					local q = lot.cf * CFrame.new(rng:NextNumber(-3, 3) * S, 0, -(hz + 1.5 * S))
					local g = ground(q.X, q.Z, -side * s)
					if g then
						local stall = fromKit("Bancarella", ctx.folder, g)
						if stall then
							kitSign(stall, SHOPS[rng:NextInteger(1, #SHOPS)])
						end
					end
				end
				t += o.w + rng:NextNumber(3, 6)
				task.wait()
			else
				t += 6
			end
		end
	end
	-- fili di lanterne sopra la via, tra case di fronte
	for i, l in rows[-1] do
		if i % 2 == 1 then
			local best, bestD = nil, math.huge
			for _, r in rows[1] do
				local d = (l - r).Magnitude
				if d < bestD then
					best, bestD = r, d
				end
			end
			if best and bestD < 45 * S then
				lanternString(ctx.folder, l + Vector3.new(0, 10 * S, 0), best + Vector3.new(0, 10 * S, 0), 5)
			end
		end
	end
	for _, e in { { a - dir * 4 * S, -dir }, { b + dir * 4 * S, dir } } do
		local cf = ground(e[1].X, e[1].Z, e[2])
		if cf then
			paifang(ctx.folder, cf, 22, name)
			table.insert(ctx.placed, { p = e[1], r = 13 * S })
		end
	end
	paint(a - dir * 8 * S, b + dir * 8 * S, half * 2 - 2, M.Pavement)
end

-- case sulla riva, come a Fenghuang: si segue la linea dell'acqua e le case si mettono una
-- accanto all'altra, col davanti (e il ballatoio) sulle palafitte sopra l'acqua; dietro una
-- seconda fila piu' alta, sempre rivolta verso l'acqua
local function shoreVillage(ctx: Ctx, center: Vector3, radius: number, count: number)
	local rng = ctx.rng
	-- punti di riva: terra con l'acqua a due passi
	local STEP = 8
	local edge: { { p: Vector3, n: Vector3 } } = {}
	for x = center.X - radius, center.X + radius, STEP do
		for z = center.Z - radius, center.Z + radius, STEP do
			if Vector2.new(x - center.X, z - center.Z).Magnitude < radius then
				local h = probe(x, z)
				if h and not h.water then
					local n = Vector3.zero
					for k = 0, 7 do
						local a = k / 8 * math.pi * 2
						local q = probe(x + math.cos(a) * STEP * 1.5, z + math.sin(a) * STEP * 1.5)
						if q and q.water then
							n += Vector3.new(math.cos(a), 0, math.sin(a))
						end
					end
					if n.Magnitude > 0.5 then
						table.insert(edge, { p = Vector3.new(x, h.y, z), n = n.Unit })
					end
				end
			end
		end
		task.wait()
	end
	if #edge == 0 then
		return 0
	end
	-- in fila lungo la riva: si parte da un capo e si va sempre al punto piu' vicino
	local avg = Vector3.zero
	for _, e in edge do
		avg += e.n
	end
	local axis = if avg.Magnitude > 0.1 then Vector3.new(-avg.Z, 0, avg.X).Unit else Vector3.xAxis
	table.sort(edge, function(a, b)
		return a.p:Dot(axis) < b.p:Dot(axis)
	end)
	local chain = { table.remove(edge, 1) :: any }
	while #edge > 0 do
		local last = chain[#chain].p
		local best, bestD = 1, math.huge
		for i, e in edge do
			local d = (e.p - last).Magnitude
			if d < bestD then
				best, bestD = i, d
			end
		end
		if bestD > STEP * 4 then
			-- un altro tratto di riva: si riparte dal piu' vicino rimasto
			table.insert(chain, { p = edge[best].p, n = edge[best].n, gap = true })
			table.remove(edge, best)
		else
			table.insert(chain, table.remove(edge, best) :: any)
		end
	end
	local made = 0
	local walked = 0
	local nextAt = rng:NextNumber(0, 6)
	for i = 2, #chain do
		if made >= count then
			break
		end
		local e = chain[i]
		walked += if e.gap then 0 else (e.p - chain[i - 1].p).Magnitude
		if walked >= nextAt then
			local o = chineseSpec(rng, true)
			o.balcony = true
			-- prima fila: il davanti sull'acqua
			local c = e.p + e.n * (o.d * 0.25)
			if tryChinese(ctx, c.X, c.Z, e.n, o, true) then
				made += 1
				nextAt = walked + o.w + rng:NextNumber(2, 5)
				-- ogni tanto la capanna del pescatore sull'acqua davanti, col pontile verso riva
				if made % 4 == 0 and kitModel("Pescatore") then
					local q = e.p + e.n * 26 * S
					local w = probe(q.X, q.Z)
					if w and w.water and not blocked(ctx, q, 12 * S) then
						local base = Vector3.new(q.X, w.y, q.Z)
						if fromKit("Pescatore", ctx.folder, CFrame.lookAt(base, base - e.n)) then
							table.insert(ctx.placed, { p = q, r = 12 * S })
						end
					end
				end
				-- seconda fila, piu' in alto dietro
				local o2 = kitSpec("TorreFenghuang") or chineseSpec(rng, true)
				o2.floors = 3
				local back = e.p - e.n * (o.d / 2 + o2.d / 2 + 11 * S)
				if tryChinese(ctx, back.X, back.Z, e.n, o2, true) then
					made += 1
				end
				task.wait()
			else
				nextAt = walked + 4 * S
			end
		end
	end
	return made
end


-- tempio: sala in fondo, pagoda e padiglione ai lati, viale con le lanterne di pietra e il torii
local function templeComplex(ctx: Ctx, center: Vector3, toward: Vector3)
	local axis = Vector3.new(toward.X, 0, toward.Z).Unit
	local side = axis:Cross(Vector3.yAxis)
	local lot = fitLot(ctx, center.X, center.Z, axis, 19 * S, 14 * S, false)
	if not lot then
		return false
	end
	local hall = templeHall(ctx.folder, lot.cf, 26, 16)
	foundation(hall, lot, 18 * S, 13 * S, lot.cf.Y - 1)
	table.insert(ctx.placed, { p = center, r = 19 * S })
	local function pagodaAt(p: Vector3): boolean
		local l = fitLot(ctx, p.X, p.Z, axis, 15 * S, 15 * S, false)
		if l then
			local pg = pagoda(ctx.folder, l.cf, 13, 5)
			foundation(pg, l, 11.5 * S, 11.5 * S, l.cf.Y - 1)
			table.insert(ctx.placed, { p = p, r = 15 * S })
			return true
		end
		return false
	end
	local p1 = center + axis * 40 * S + side * 30 * S
	if not pagodaAt(p1) then
		pagodaAt(center + axis * 40 * S - side * 30 * S)
	end
	local pv = center + axis * 40 * S - side * 28 * S
	local pl = fitLot(ctx, pv.X, pv.Z, axis, 8 * S, 8 * S, false)
	if pl then
		local m = Instance.new("Model")
		m.Name = "PadiglioneTempio"
		m.Parent = ctx.folder
		pavilion(m, pl.cf - Vector3.new(0, 0.6, 0), 10)
		foundation(m, pl, 6.5 * S, 6.5 * S, pl.cf.Y - 1)
		table.insert(ctx.placed, { p = pv, r = 8 * S })
	end
	-- viale: lanterne di pietra a coppie fino al torii
	local gate = center + axis * 95 * S
	for k = 1, 6 do
		for _, s in { -1, 1 } do
			local q = center + axis * (16 + k * 12) * S + side * s * 6.5 * S
			local cf = ground(q.X, q.Z, axis)
			if cf then
				stoneLantern(ctx.folder, cf)
			end
		end
	end
	local gcf = ground(gate.X, gate.Z, axis)
	if gcf then
		torii(ctx.folder, gcf, 12, 15)
	end
	paint(center + axis * 12 * S, gate + axis * 6 * S, 8 * S * 0.6, M.Pavement)
	return true
end

-- ponte da a a b (le due rive, a terra) sopra l'acqua:
--   "arch"    ponte ad arco giapponese, legno e parapetti laccati rossi
--   "covered" ponte coperto cinese (langqiao): arco basso, pilastri rossi, tetto curvo, lanterne
--   "stone"   ponte di pietra a schiena d'asino con le lanterne di pietra ai capi
local bridgeCount = 0
-- ponti gia' fatti (centro e mezza lunghezza): due strade che passano il fiume nello stesso punto
-- facevano due o tre ponti uno dentro l'altro, a quote diverse
local bridgeSpots: { { p: Vector3, r: number } } = {}
local BRIDGE_KIT = { arch = "PonteRosso", covered = "PonteCoperto", stone = "PontePietra" }
local function bridge(parent: Instance, a: Vector3, b: Vector3, style: string): boolean
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local span = dir.Magnitude
	local center = Vector3.new((a.X + b.X) / 2, 0, (a.Z + b.Z) / 2)
	for _, o in bridgeSpots do
		if (o.p - center).Magnitude < o.r + span / 2 + 20 then
			return false
		end
	end
	table.insert(bridgeSpots, { p = center, r = span / 2 })
	bridgeCount += 1
	dir = dir.Unit
	local side = dir:Cross(Vector3.yAxis)
	-- modello di Blender: lungo come il ponte (lo si scala), con i capi a terra
	local t = kitModel(BRIDGE_KIT[style] or "PonteRosso")
	if t then
		local mid = (a + b) / 2
		local base = Vector3.new(mid.X, math.max(a.Y, b.Y) + 0.3, mid.Z)
		local width = (t:GetAttribute("Width") :: number?) or span
		local km = fromKit(t.Name, parent, CFrame.lookAt(base, base + side), math.clamp(span / width, 0.6, 2.2))
		if km then
			km.Name = "Ponte"
			return true
		end
	end
	local m = Instance.new("Model")
	m.Name = "Ponte"
	local width = if style == "covered" then 9 else 8
	local rise = if style == "covered" then 2.5 else math.clamp(span * 0.16, 3, 9)
	local base = math.max(a.Y, b.Y) + 1
	local function point(t: number, s: number): Vector3
		local along = a:Lerp(b, t)
		local y = base + rise * (1 - (2 * t - 1) ^ 2)
		-- agli estremi scende fino a terra
		local ends = if t < 0.5 then a.Y + 0.6 else b.Y + 0.6
		y += (ends - base) * (math.abs(2 * t - 1) ^ 6)
		return Vector3.new(along.X, y, along.Z) + side * s
	end
	local N = math.clamp(math.floor(span / 5), 6, 16)
	local deckColor = if style == "stone" then STONE else Color3.fromRGB(142, 104, 70)
	local deckMat = if style == "stone" then M.Cobblestone else M.WoodPlanks
	local railColor = if style == "stone" then STONE_DARK else LACQUER
	for k = 0, N - 1 do
		local p0, p1 = point(k / N, 0), point((k + 1) / N, 0)
		local len = (p1 - p0).Magnitude
		part(m, Vector3.new(width, if style == "stone" then 1.6 else 0.8, len + 0.4), CFrame.lookAt((p0 + p1) / 2, p1), deckColor, deckMat)
		for _, s in { -1, 1 } do
			local r0, r1 = point(k / N, s * width / 2), point((k + 1) / N, s * width / 2)
			if style == "stone" then
				beam(m, r0 + Vector3.new(0, 1.2, 0), r1 + Vector3.new(0, 1.2, 0), 0.9, 2, railColor, M.Slate)
			else
				beam(m, r0 + Vector3.new(0, 3, 0), r1 + Vector3.new(0, 3, 0), 0.45, 0.45, railColor, M.SmoothPlastic, true)
				beam(m, r0 + Vector3.new(0, 1.4, 0), r1 + Vector3.new(0, 1.4, 0), 0.35, 0.35, railColor, M.SmoothPlastic, true)
				if style == "covered" then
					-- i pilastri arrivano fino al tetto (che e' piatto, alla quota del centro + 9)
					local h = point(0.5, 0).Y + 9 - r0.Y
					part(m, Vector3.new(0.6, h, 0.6), CFrame.new(r0 + Vector3.new(0, h / 2, 0)), railColor, M.SmoothPlastic, true)
				elseif k % 2 == 0 then
					part(m, Vector3.new(0.6, 3.6, 0.6), CFrame.new(r0 + Vector3.new(0, 1.8, 0)), railColor, M.SmoothPlastic, true)
				end
			end
		end
	end
	-- pile nell'acqua sotto il centro
	for _, t in { 0.33, 0.66 } do
		if span > 24 then
			local top = point(t, 0)
			local bottom = bed(top.X, top.Z, top.Y) - 1
			part(m, Vector3.new(width * 0.6, top.Y - bottom, 3), CFrame.lookAt(Vector3.new(top.X, (top.Y + bottom) / 2 - 0.6, top.Z), Vector3.new(top.X, (top.Y + bottom) / 2 - 0.6, top.Z) + dir), STONE_DARK, M.Slate)
		end
	end
	if style == "covered" then
		-- tetto lungo tutto il ponte, alla quota del centro
		local mid = point(0.5, 0)
		roof(m, CFrame.lookAt(mid, mid + side) + Vector3.new(0, 9, 0), span / 2 - 1, width / 2 + 2, 5, { style = "gable", lift = 1.4 })
		for k = 1, 3 do
			redLantern(m, point(k / 4, 0) + Vector3.new(0, 8.6, 0), 1.3, k == 2)
		end
	elseif style == "stone" then
		for _, e in { a, b } do
			for _, s in { -1, 1 } do
				local cf = ground((e + side * s * (width / 2 + 2) - dir * (if e == a then 2 else -2)).X, (e + side * s * (width / 2 + 2)).Z, dir)
				if cf then
					stoneLantern(m, cf)
				end
			end
		end
	else
		for _, t in { 0, 1 } do
			for _, s in { -1, 1 } do
				local p = point(t, s * width / 2)
				part(m, Vector3.new(1, 4.4, 1), CFrame.new(p + Vector3.new(0, 2.2, 0)), LACQUER, M.SmoothPlastic)
				local cap = part(m, Vector3.one * 1.4, CFrame.new(p + Vector3.new(0, 4.8, 0)), Color3.fromRGB(30, 28, 26), M.Metal, true)
				cap.Shape = Enum.PartType.Ball
			end
		end
	end
	m.Parent = parent
	return true
end

local BRIDGE_STYLES = { "arch", "covered", "stone" }

-- ponti lungo i fiumi della pianura (percorsi in Config.RIVERS): ogni "every" studs si cerca
-- l'acqua di traverso al fiume e, se il tratto e' abbastanza stretto, ci va un ponte
local function riverBridges(ctx: Ctx, every: number): number
	local ok, cfg = okConfig, Config
	if not ok then
		return 0
	end
	local made = 0
	for _, river in (cfg :: any).RIVERS or {} do
		local pts = river.POINTS
		local walked = every * 0.5
		for i = 1, #pts - 1 do
			local p0 = Vector3.new(pts[i][1], 0, pts[i][2])
			local p1 = Vector3.new(pts[i + 1][1], 0, pts[i + 1][2])
			local seg = (p1 - p0).Magnitude
			local dir = (p1 - p0).Unit
			local across = dir:Cross(Vector3.yAxis)
			local t = walked
			while t < seg do
				local c = p0 + dir * t
				-- solo in pianura (non sulla montagna) e lontano dal resto
				local h = probe(c.X, c.Z)
				if c.X < -380 and c.X > -2550 and h and h.y < 160 and not blocked(ctx, c, 40) then
					-- di traverso: dove comincia e finisce l'acqua
					local first, last: number? = nil, nil
					for s = -160, 160, 3 do
						local q = probe(c.X + across.X * s, c.Z + across.Z * s)
						if q and q.water then
							first = first or s
							last = s
						elseif first and last and s - last > 9 then
							break
						end
					end
					-- il fiume deve scorrere di traverso al ponte (acqua anche a monte e a valle del
					-- centro) ed essere vero fiume, non una pozza bassa sulla spiaggia
					local crosses = false
					if first and last then
						local mid = c + across * ((first + last) / 2)
						local up, down = probe(mid.X + dir.X * 14, mid.Z + dir.Z * 14), probe(mid.X - dir.X * 14, mid.Z - dir.Z * 14)
						local here = probe(mid.X, mid.Z)
						crosses = up ~= nil and down ~= nil and here ~= nil and up.water and down.water and here.water and here.y - bed(mid.X, mid.Z, here.y + 1) > 2
					end
					if first and last and crosses then
						local span = last - first
						if span >= 8 and span <= 60 then
							local a = c + across * (first - 7)
							local b = c + across * (last + 7)
							local ha, hb = probe(a.X, a.Z), probe(b.X, b.Z)
							if ha and hb and not ha.water and not hb.water and math.abs(ha.y - hb.y) < 10 then
								if not bridge(ctx.folder, Vector3.new(a.X, ha.y, a.Z), Vector3.new(b.X, hb.y, b.Z), BRIDGE_STYLES[bridgeCount % #BRIDGE_STYLES + 1]) then
									break
								end
								table.insert(ctx.placed, { p = c, r = span / 2 + 10 })
								-- un sentiero corto che parte dalle due rive
								paint(Vector3.new(a.X, ha.y, a.Z) - across * 30, Vector3.new(a.X, ha.y, a.Z), 5, M.Ground)
								paint(Vector3.new(b.X, hb.y, b.Z), Vector3.new(b.X, hb.y, b.Z) + across * 30, 5, M.Ground)
								made += 1
								task.wait()
							end
						end
					end
				end
				t += every
			end
			walked = t - seg
		end
	end
	return made
end

-- campo coltivato a strisce accanto alle case (solo il materiale del terreno)
local function field(ctx: Ctx, near: Vector3)
	local rng = ctx.rng
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local c = near + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(40, 70)
		local w, l = rng:NextInteger(28, 44), rng:NextInteger(36, 60)
		if not blocked(ctx, c, math.max(w, l) / 2) then
			local hi, lo, ok = -math.huge, math.huge, true
			for _, k in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.zero } do
				local h = probe(c.X + k.X * w / 2, c.Z + k.Z * l / 2)
				if not h or h.water or BAD_GROUND[h.mat] then
					ok = false
					break
				end
				hi, lo = math.max(hi, h.y), math.min(lo, h.y)
			end
			if ok and hi - lo < 7 then
				local row = 0
				for z = c.Z - l / 2, c.Z + l / 2 - 4, 4 do
					row += 1
					local r = Region3.new(Vector3.new(c.X - w / 2, lo - 4, z), Vector3.new(c.X + w / 2, hi + 2, z + 4)):ExpandToGrid(4)
					local mat = if row % 2 == 0 then M.Mud else M.LeafyGrass
					for _, from in PAINT_FROM do
						if from ~= mat then
							workspace.Terrain:ReplaceMaterial(r, 4, from, mat)
						end
					end
				end
				table.insert(ctx.placed, { p = c, r = math.max(w, l) / 2 })
				return
			end
		end
	end
end

-- casali sparsi per la pianura: due o tre case con il loro campo, lontano dai borghi
local function hamlets(ctx: Ctx, count: number, avoid: { Vector3 }, out: { Vector3 })
	local rng = ctx.rng
	local made = 0
	local spots = table.clone(avoid)
	for _ = 1, count * 40 do
		if made >= count then
			break
		end
		local p = Vector3.new(rng:NextNumber(-3150, -350), 0, rng:NextNumber(-2250, 2250))
		local far = true
		for _, q in spots do
			if Vector2.new(p.X - q.X, p.Z - q.Z).Magnitude < 260 then
				far = false
				break
			end
		end
		local h = far and probe(p.X, p.Z)
		if h and not h.water and h.y < 220 and not blocked(ctx, p, 30) then
			local before = #ctx.placed
			ctx.fronts = {}
			local japanese = rng:NextNumber() < 0.55
			clusterVillage(ctx, p, 34, rng:NextInteger(1, 3), japanese, false)
			if #ctx.placed > before then
				field(ctx, p)
				for _, f in ctx.fronts do
					paint(f, p, 3, M.Ground)
				end
				table.insert(spots, p)
				table.insert(out, p)
				made += 1
			end
		end
	end
	return made
end

------------------------------------------------------------------------------------------
-- strade: una rete che unisce borghi, tempio, campo base, palestra e arena, e le stradine dei
-- casali. Il percorso si cerca (A*) su una griglia della pianura: salire costa, l'acqua costa
-- tanto (si passa dove il fiume e' stretto e ci va il ponte), attorno agli edifici si gira,
-- sulle strade gia' fatte si va volentieri (cosi' si uniscono negli incroci). Poi si dipinge il
-- terreno (lastricato al centro, terra battuta ai bordi) e lungo la strada si mettono lanterne
-- di pietra, cartelli con i nomi e, sulle strade lunghe, un padiglione per la sosta.

local GRID = 16
local ROAD_FROM = { M.Grass, M.LeafyGrass, M.Ground, M.Mud, M.Rock, M.Sand }

type RoadGrid = {
	x0: number,
	z0: number,
	nx: number,
	nz: number,
	h: { number }, -- quota del terreno (math.huge = non si passa: montagna, edifici)
	water: { boolean },
	extra: { number }, -- costo in piu' (cose della mappa vicine)
	road: { [number]: boolean }, -- celle gia' strada
}

local function cellIndex(g: RoadGrid, x: number, z: number): (number, number)
	return math.clamp(math.floor((x - g.x0) / GRID), 0, g.nx - 1), math.clamp(math.floor((z - g.z0) / GRID), 0, g.nz - 1)
end

local function roadGrid(ctx: Ctx): RoadGrid
	local x0, z0 = -3330, -2470
	local nx, nz = math.ceil(3100 / GRID), math.ceil(4940 / GRID)
	local g: RoadGrid = {
		x0 = x0,
		z0 = z0,
		nx = nx,
		nz = nz,
		h = table.create(nx * nz, math.huge),
		water = table.create(nx * nz, false),
		extra = table.create(nx * nz, 0),
		road = {},
	}
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			local h = probe(x0 + (i + 0.5) * GRID, z0 + (j + 0.5) * GRID)
			if h and h.y < 240 and h.mat ~= M.Glacier and h.mat ~= M.Snow and h.mat ~= M.Ice then
				local k = i + j * nx + 1
				g.h[k] = h.y
				g.water[k] = h.water
			end
		end
		if j % 10 == 0 then
			task.wait()
		end
	end
	-- dentro gli edifici non si passa
	for _, c in ctx.placed do
		local r = c.r + 3
		local i0, j0 = cellIndex(g, c.p.X - r, c.p.Z - r)
		local i1, j1 = cellIndex(g, c.p.X + r, c.p.Z + r)
		for j = j0, j1 do
			for i = i0, i1 do
				local cx, cz = x0 + (i + 0.5) * GRID, z0 + (j + 0.5) * GRID
				if Vector2.new(cx - c.p.X, cz - c.p.Z).Magnitude < r then
					g.h[i + j * nx + 1] = math.huge
				end
			end
		end
	end
	-- le altre cose della mappa (campo base, palafitte, minerali...): meglio girarci attorno
	for _, list in ctx.grid do
		for _, p in list do
			local i, j = cellIndex(g, p.X, p.Z)
			local k = i + j * nx + 1
			g.extra[k] = math.min(g.extra[k] + 1.5, 6)
		end
	end
	return g
end

-- percorso piu' economico da a a b (lista di punti a terra), o nil
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
local function findRoad(g: RoadGrid, a: Vector3, b: Vector3): { Vector3 }?
	local nx = g.nx
	local si, sj = cellIndex(g, a.X, a.Z)
	local gi, gj = cellIndex(g, b.X, b.Z)
	local start, goal = si + sj * nx + 1, gi + gj * nx + 1
	-- vicino ai capi si puo' entrare anche nelle celle chiuse (la piazza col padiglione, il tempio)
	local function nearEnd(i: number, j: number): boolean
		return math.max(math.abs(i - si), math.abs(j - sj)) <= 3 or math.max(math.abs(i - gi), math.abs(j - gj)) <= 3
	end
	local function hOf(k: number): number
		local h = g.h[k]
		if h == math.huge then
			-- cella chiusa vicino ai capi: la quota della cella piu' vicina aperta (o del capo)
			return if k == start then a.Y else b.Y
		end
		return h
	end
	-- heap minimo di (f, cella)
	local heapF: { number }, heapK: { number } = {}, {}
	local function push(f: number, k: number)
		local n = #heapF + 1
		heapF[n], heapK[n] = f, k
		while n > 1 do
			local p = n // 2
			if heapF[p] <= heapF[n] then
				break
			end
			heapF[p], heapF[n] = heapF[n], heapF[p]
			heapK[p], heapK[n] = heapK[n], heapK[p]
			n = p
		end
	end
	local function pop(): (number, number)
		local f, k = heapF[1], heapK[1]
		local n = #heapF
		heapF[1], heapK[1] = heapF[n], heapK[n]
		heapF[n], heapK[n] = nil, nil
		n -= 1
		local i = 1
		while true do
			local l, r = i * 2, i * 2 + 1
			local m = i
			if l <= n and heapF[l] < heapF[m] then
				m = l
			end
			if r <= n and heapF[r] < heapF[m] then
				m = r
			end
			if m == i then
				break
			end
			heapF[m], heapF[i] = heapF[i], heapF[m]
			heapK[m], heapK[i] = heapK[i], heapK[m]
			i = m
		end
		return f, k
	end
	local gScore: { [number]: number } = { [start] = 0 }
	local came: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local function heur(i: number, j: number): number
		return Vector2.new(i - gi, j - gj).Magnitude * GRID * 0.5
	end
	push(heur(si, sj), start)
	local expanded = 0
	while #heapF > 0 do
		local _, k = pop()
		if k == goal then
			break
		end
		if closed[k] then
			continue
		end
		closed[k] = true
		expanded += 1
		if expanded > 160000 then
			return nil
		end
		if expanded % 6000 == 0 then
			task.wait()
		end
		local i, j = (k - 1) % nx, (k - 1) // nx
		local hk = hOf(k)
		for _, d in DIRS do
			local ni, nj = i + d[1], j + d[2]
			if ni < 0 or nj < 0 or ni >= nx or nj >= g.nz then
				continue
			end
			local nk = ni + nj * nx + 1
			if closed[nk] or (g.h[nk] == math.huge and not nearEnd(ni, nj)) then
				continue
			end
			local len = if d[1] ~= 0 and d[2] ~= 0 then GRID * 1.414 else GRID
			local hn = hOf(nk)
			if hn == math.huge then
				continue
			end
			local slope = math.abs(hn - hk) / len
			if slope > 0.8 and not nearEnd(ni, nj) then
				continue
			end
			local c = len * (1 + 14 * slope * slope + g.extra[nk])
			if g.water[nk] then
				c += len * 16
			end
			if g.road[nk] then
				c *= 0.4
			end
			local ng = (gScore[k] :: number) + c
			if ng < (gScore[nk] or math.huge) then
				gScore[nk] = ng
				came[nk] = k
				push(ng + heur(ni, nj), nk)
			end
		end
	end
	if not came[goal] then
		return nil
	end
	local cells = { goal }
	local k = goal
	while came[k] do
		k = came[k]
		table.insert(cells, 1, k)
	end
	local pts = { Vector3.new(a.X, 0, a.Z) }
	for n = 2, #cells - 1 do
		local c = cells[n]
		table.insert(pts, Vector3.new(g.x0 + ((c - 1) % nx + 0.5) * GRID, 0, g.z0 + ((c - 1) // nx + 0.5) * GRID))
	end
	table.insert(pts, Vector3.new(b.X, 0, b.Z))
	-- curve morbide (Chaikin, i capi restano) e un punto ogni 4 stud
	for _ = 1, 3 do
		local s = { pts[1] }
		for n = 1, #pts - 1 do
			table.insert(s, pts[n]:Lerp(pts[n + 1], 0.25))
			table.insert(s, pts[n]:Lerp(pts[n + 1], 0.75))
		end
		table.insert(s, pts[#pts])
		pts = s
	end
	local out = { pts[1] }
	local carry = 0
	for n = 1, #pts - 1 do
		local p0, p1 = pts[n], pts[n + 1]
		local len = (p1 - p0).Magnitude
		local t = 4 - carry
		while t <= len do
			table.insert(out, p0:Lerp(p1, t / len))
			t += 4
		end
		carry = len - (t - 4)
	end
	table.insert(out, pts[#pts])
	return out
end

type Road = {
	pts: { Vector3 }, -- un punto ogni 4 stud (y = 0)
	width: number,
	main: boolean,
	from: string,
	to: string,
}

-- colonne di voxel da dipingere: lastricato al centro, terra ai bordi
local function roadColumns(road: Road, cols: { [number]: Enum.Material })
	local core, edge = road.width / 2, road.width / 2 + (if road.main then 2.5 else 1.5)
	local coreMat = if road.main then M.Cobblestone else M.Ground
	local edgeMat = if road.main then M.Ground else M.Mud
	local span = math.ceil(edge / 4) + 1
	for n, p in road.pts do
		if n % 2 == 0 and n ~= #road.pts then
			continue -- ogni 8 stud basta (la colonna e' larga 4)
		end
		local cx, cz = math.floor(p.X / 4), math.floor(p.Z / 4)
		for dx = -span, span do
			for dz = -span, span do
				local x, z = cx + dx, cz + dz
				local d = Vector2.new((x + 0.5) * 4 - p.X, (z + 0.5) * 4 - p.Z).Magnitude
				local key = (x + 4000) * 10000 + (z + 4000)
				if d <= core then
					if cols[key] ~= M.Cobblestone then
						cols[key] = coreMat
					end
				elseif d <= edge and not cols[key] then
					cols[key] = edgeMat
				end
			end
		end
	end
end

-- cartello di legno con le frecce verso i borghi (testo su tutte e due le facce)
local function signpost(parent: Instance, at: Vector3, arrows: { { dir: Vector3, text: string } })
	local m = Instance.new("Model")
	m.Name = "Cartello"
	local post = part(m, Vector3.new(0.8, 10, 0.8), CFrame.new(at + Vector3.new(0, 4.6, 0)), TIMBER_DARK, M.Wood)
	post.Name = "Palo"
	part(m, Vector3.new(1.4, 0.8, 1.4), CFrame.new(at + Vector3.new(0, 9.9, 0)), TIMBER_DARK, M.Wood, true)
	for n, a in arrows do
		local dir = Vector3.new(a.dir.X, 0, a.dir.Z).Unit
		local len = math.clamp(#a.text * 0.62 + 2.4, 6, 11)
		local y = 8.6 - (n - 1) * 1.7
		local pos = at + dir * (len / 2 + 0.5) + Vector3.new(0, y, 0)
		-- l'asse -X della tavola punta verso il borgo: davanti la scritta va verso di lui
		local board = part(m, Vector3.new(len, 1.3, 0.25), CFrame.fromMatrix(pos, -dir, Vector3.yAxis), Color3.fromRGB(150, 112, 70), M.WoodPlanks, true)
		for face, label in { [Enum.NormalId.Front] = a.text .. "  >", [Enum.NormalId.Back] = "<  " .. a.text } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.PixelsPerStud = 30
			gui.LightInfluence = 0.5
			gui.Parent = board
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(0.94, 0.8)
			t.Position = UDim2.fromScale(0.03, 0.1)
			t.Font = Enum.Font.Fantasy
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(40, 26, 16)
			t.Text = label
			t.Parent = gui
		end
	end
	m.Parent = parent
end

-- nodi della rete: borghi, tempio, campo base, palestra, arena (con quanto accorciare la strada
-- all'arrivo: nel campo base e nella palestra non si entra dipingendo)
type Node = { p: Vector3, name: string, trim: number }

local function buildRoads(ctx: Ctx, nodes: { Node }, hamletSpots: { Vector3 }, map: any?): string
	local folder = Instance.new("Folder")
	folder.Name = "Strade"
	folder.Parent = ctx.folder
	ctx.folder = folder
	local g = roadGrid(ctx)
	-- quali coppie unire: l'albero piu' corto (Kruskal) e qualche anello in piu'
	type Edge = { a: number, b: number, len: number }
	local edges: { Edge } = {}
	for i = 1, #nodes do
		for j = i + 1, #nodes do
			table.insert(edges, { a = i, b = j, len = Vector2.new(nodes[i].p.X - nodes[j].p.X, nodes[i].p.Z - nodes[j].p.Z).Magnitude })
		end
	end
	table.sort(edges, function(x, y)
		return x.len < y.len
	end)
	local group = {}
	for i = 1, #nodes do
		group[i] = i
	end
	local function root(i: number): number
		while group[i] ~= i do
			i = group[i]
		end
		return i
	end
	local chosen: { Edge } = {}
	local adj: { [number]: { [number]: number } } = {}
	for i = 1, #nodes do
		adj[i] = {}
	end
	for _, e in edges do
		local ra, rb = root(e.a), root(e.b)
		if ra ~= rb then
			group[ra] = rb
			table.insert(chosen, e)
			adj[e.a][e.b], adj[e.b][e.a] = e.len, e.len
		end
	end
	-- anelli: una strada diretta dove il giro sulla rete e' molto piu' lungo
	local function graphDist(s: number, t: number): number
		local dist, done = { [s] = 0 }, {}
		while true do
			local best, bd = nil, math.huge
			for k, d in dist do
				if not done[k] and d < bd then
					best, bd = k, d
				end
			end
			if not best or best == t then
				return bd
			end
			done[best] = true
			for k, l in adj[best] do
				if bd + l < (dist[k] or math.huge) then
					dist[k] = bd + l
				end
			end
		end
	end
	local extra = 0
	for _, e in edges do
		if extra >= 7 or e.len > 1300 then
			break
		end
		if not adj[e.a][e.b] and graphDist(e.a, e.b) > e.len * 1.7 then
			table.insert(chosen, e)
			adj[e.a][e.b], adj[e.b][e.a] = e.len, e.len
			extra += 1
		end
	end
	-- prima le strade corte: le lunghe poi si appoggiano a quelle
	table.sort(chosen, function(x, y)
		return x.len < y.len
	end)
	local roads: { Road } = {}
	local function mark(road: Road)
		for _, p in road.pts do
			local i, j = cellIndex(g, p.X, p.Z)
			g.road[i + j * g.nx + 1] = true
		end
	end
	local function trimmed(pts: { Vector3 }, a: Node?, b: Node?): { Vector3 }
		local out = {}
		for _, p in pts do
			local ok = true
			for _, n in { a, b } do
				if n and n.trim > 0 and Vector2.new(p.X - n.p.X, p.Z - n.p.Z).Magnitude < n.trim then
					ok = false
				end
			end
			if ok then
				table.insert(out, p)
			end
		end
		return out
	end
	for _, e in chosen do
		local A, B = nodes[e.a], nodes[e.b]
		local pts = findRoad(g, A.p, B.p)
		if pts then
			local road: Road = { pts = trimmed(pts, A, B), width = 7, main = true, from = A.name, to = B.name }
			if #road.pts > 4 then
				table.insert(roads, road)
				mark(road)
			end
		end
		task.wait()
	end
	local mainCount = #roads
	-- stradine dei casali: fino alla strada piu' vicina
	local roadCells = {}
	for k in g.road do
		table.insert(roadCells, k)
	end
	for _, h in hamletSpots do
		local best, bd = nil, math.huge
		for _, k in roadCells do
			local x, z = g.x0 + ((k - 1) % g.nx + 0.5) * GRID, g.z0 + ((k - 1) // g.nx + 0.5) * GRID
			local d = Vector2.new(x - h.X, z - h.Z).Magnitude
			if d < bd then
				best, bd = Vector3.new(x, 0, z), d
			end
		end
		if best and bd > 30 and bd < 650 then
			local pts = findRoad(g, h, best :: Vector3)
			if pts then
				local road: Road = { pts = pts, width = 4, main = false, from = "", to = "" }
				table.insert(roads, road)
				mark(road)
			end
		end
		task.wait()
	end
	-- ponti dove la strada passa sull'acqua; il resto si dipinge
	local cols: { [number]: Enum.Material } = {}
	local bridges = 0
	for _, road in roads do
		local land: { Vector3 } = {}
		local lastLand: Vector3? = nil
		local runStart: Vector3? = nil
		for _, p in road.pts do
			local h = probe(p.X, p.Z)
			if h and h.water then
				if not runStart then
					runStart = lastLand
				end
			elseif h then
				local here = Vector3.new(p.X, h.y, p.Z)
				if runStart then
					local span = Vector2.new(here.X - (runStart :: Vector3).X, here.Z - (runStart :: Vector3).Z).Magnitude
					if span >= 8 and span <= 90 and math.abs(here.Y - (runStart :: Vector3).Y) < 12 then
						local d = Vector3.new(here.X - (runStart :: Vector3).X, 0, here.Z - (runStart :: Vector3).Z).Unit
						if bridge(folder, (runStart :: Vector3) - d * 4, here + d * 4, BRIDGE_STYLES[bridgeCount % #BRIDGE_STYLES + 1]) then
							table.insert(ctx.placed, { p = ((runStart :: Vector3) + here) / 2, r = span / 2 + 6 })
							bridges += 1
						end
					end
					runStart = nil
				end
				lastLand = here
				table.insert(land, p)
			end
		end
		roadColumns({ pts = land, width = road.width, main = road.main, from = road.from, to = road.to }, cols)
	end
	-- dipinge (sotto l'acqua no) e segna le celle per il bosco e i prati
	local cells: { [string]: boolean } = {}
	local painted = 0
	for key, mat in cols do
		local x, z = (key // 10000 - 4000) * 4, (key % 10000 - 4000) * 4
		local h = probe(x + 2, z + 2)
		if h and not h.water then
			local y = math.floor(h.y / 4) * 4
			local r = Region3.new(Vector3.new(x, y - 8, z), Vector3.new(x + 4, y + 4, z + 4))
			for _, from in ROAD_FROM do
				if from ~= mat then
					workspace.Terrain:ReplaceMaterial(r, 4, from, mat)
				end
			end
			cells[math.floor(x / 16) .. "," .. math.floor(z / 16)] = true
			painted += 1
			if painted % 400 == 0 then
				task.wait()
			end
		end
	end
	if map and map.features then
		map.features.roadCells = cells
	end
	ctx.roadCells = cells
	-- lungo le strade principali: lanterne di pietra, cartelli ai capi, padiglione per la sosta
	local lanterns, signs, rests = 0, 0, 0
	local lanternTpl = kitModel("LanternaPietra")
	local function nearNode(p: Vector3, r: number): boolean
		for _, n in nodes do
			if Vector2.new(p.X - n.p.X, p.Z - n.p.Z).Magnitude < r + n.trim then
				return true
			end
		end
		return false
	end
	for ri = 1, mainCount do
		local road = roads[ri]
		local pts = road.pts
		local side = 1
		for n = 6, #pts - 6, 12 do
			local p, q = pts[n], pts[n + 1]
			local dir = Vector3.new(q.X - p.X, 0, q.Z - p.Z)
			if dir.Magnitude < 0.01 then
				continue
			end
			dir = dir.Unit
			local across = dir:Cross(Vector3.yAxis)
			local at = p + across * side * (road.width / 2 + 4)
			side = -side
			local h = probe(at.X, at.Z)
			if h and not h.water and not BAD_GROUND[h.mat] and not nearNode(at, 70) and not blocked(ctx, at, 2.5) then
				local cf = CFrame.lookAt(Vector3.new(at.X, h.y, at.Z), Vector3.new(p.X, h.y, p.Z))
				if lanternTpl then
					fromKit("LanternaPietra", folder, cf)
				else
					stoneLantern(folder, cf)
				end
				table.insert(ctx.placed, { p = at, r = 2.5 })
				lanterns += 1
			end
		end
		-- cartelli a 70 stud dai due capi, con la freccia verso l'altro capo
		for _, e in { { n = math.min(18, #pts), to = road.to, toward = 1 }, { n = math.max(#pts - 17, 1), to = road.from, toward = -1 } } do
			local p = pts[e.n]
			local q = pts[math.clamp(e.n + e.toward * 3, 1, #pts)]
			local dir = Vector3.new(q.X - p.X, 0, q.Z - p.Z)
			if dir.Magnitude > 0.01 then
				local at = p + dir.Unit:Cross(Vector3.yAxis) * (road.width / 2 + 2.5)
				local h = probe(at.X, at.Z)
				if h and not h.water and not blocked(ctx, at, 2) then
					signpost(folder, Vector3.new(at.X, h.y, at.Z), { { dir = dir, text = e.to } })
					table.insert(ctx.placed, { p = at, r = 2 })
					signs += 1
				end
			end
		end
		-- sosta a meta' delle strade lunghe: padiglione accanto alla strada, bancarella del te'
		if #pts * 4 > 520 then
			for _, frac in { 0.5, 0.42, 0.58 } do
				local n = math.floor(#pts * frac)
				local p, q = pts[n], pts[n + 1]
				local dir = Vector3.new(q.X - p.X, 0, q.Z - p.Z)
				if dir.Magnitude > 0.01 then
					local across = dir.Unit:Cross(Vector3.yAxis)
					local c = p + across * (road.width / 2 + 16)
					local lot = fitLot(ctx, c.X, c.Z, -across, 11, 11, false)
					if lot then
						local m = Instance.new("Model")
						m.Name = "Sosta"
						m.Parent = folder
						pavilion(m, lot.cf - Vector3.new(0, 0.6, 0), 10)
						foundation(m, lot, 6.5, 6.5, lot.cf.Y - 1)
						table.insert(ctx.placed, { p = c, r = 11 })
						local s = lot.cf * CFrame.new(15, 0, -2)
						local sg = ground(s.X, s.Z, -across)
						if sg and kitModel("Bancarella") and not blocked(ctx, s.Position, 5) then
							local stall = fromKit("Bancarella", m, sg)
							if stall then
								kitSign(stall, "TEA")
							end
							table.insert(ctx.placed, { p = s.Position, r = 5 })
						end
						rests += 1
						break
					end
				end
			end
		end
		task.wait()
	end
	-- campi coltivati lungo le strade (le strade contano come occupate, cosi' non le coprono)
	for _, road in roads do
		for n = 1, #road.pts, 10 do
			table.insert(ctx.placed, { p = road.pts[n], r = road.width / 2 + 3 })
		end
	end
	local fields = 0
	for ri = 1, mainCount do
		local pts = roads[ri].pts
		for n = 30, #pts - 30, 70 do
			if ctx.rng:NextNumber() < 0.45 and not nearNode(pts[n], 120) then
				local before = #ctx.placed
				field(ctx, pts[n])
				if #ctx.placed > before then
					fields += 1
				end
			end
		end
	end
	return string.format("strade %d + stradine %d, ponti %d, lanterne %d, cartelli %d, soste %d, campi %d", mainCount, #roads - mainCount, bridges, lanterns, signs, rests, fields)
end

------------------------------------------------------------------------------------------

-- i borghi (centri scelti dove la pianura e' piana e libera; il resto lo decide il terreno)
-- i borghi si allargano con gli edifici (scala S): stessi centri, raggio piu' grande
local SPREAD = 2.4
local VILLAGES = {
	{ kind = "shore", name = "LANTERN BAY", at = Vector3.new(-2350, 0, 540), radius = 230, count = 36 },
	{ kind = "street", name = "JADE MARKET", a = Vector3.new(-2470, 0, -1150), b = Vector3.new(-2140, 0, -1150) },
	{ kind = "temple", name = "CLOUD TEMPLE", at = Vector3.new(-1860, 0, -300) },
	{ kind = "cluster", name = "MAPLE HOLLOW", at = Vector3.new(-2430, 0, 980), radius = 120, count = 9, japanese = true },
	{ kind = "shore", name = "FISHER'S COVE", at = Vector3.new(-2720, 0, -1880), radius = 200, count = 16 },
	{ kind = "cluster", name = "SEAWIND VILLAGE", at = Vector3.new(-1900, 0, 1860), radius = 130, count = 10 },
	{ kind = "cluster", name = "WILLOW FARMS", at = Vector3.new(-860, 0, -700), radius = 110, count = 6, japanese = true },
	{ kind = "cluster", name = "RIVERSIDE", at = Vector3.new(-2950, 0, -250), radius = 120, count = 8 },
	{ kind = "cluster", name = "PINE CROSSING", at = Vector3.new(-2550, 0, -560), radius = 130, count = 10 },
	{ kind = "cluster", name = "MISTY TERRACES", at = Vector3.new(-1250, 0, -520), radius = 110, count = 8, japanese = true },
	{ kind = "cluster", name = "RIVERBEND", at = Vector3.new(-1150, 0, 880), radius = 110, count = 8, japanese = true },
	{ kind = "shore", name = "SUNSET HARBOR", at = Vector3.new(-880, 0, -1960), radius = 180, count = 14 },
	{ kind = "cluster", name = "HOT SPRINGS", at = Vector3.new(-620, 0, 1620), radius = 100, count = 7, japanese = true },
	{ kind = "cluster", name = "WEST FIELDS", at = Vector3.new(-2950, 0, 1350), radius = 100, count = 7 },
	{ kind = "cluster", name = "STONE FORD", at = Vector3.new(-2800, 0, -1600), radius = 110, count = 8, japanese = true },
}

function Borghi.build(map: any?): Folder
	bridgeSpots = {}
	local old = workspace:FindFirstChild("Borghi")
	if old then
		old:Destroy()
	end
	local prova = workspace:FindFirstChild("BorghiProva")
	if prova then
		prova:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Borghi"
	root.Parent = workspace
	local keepOut: { Circle } = {}
	for _, n in { "gym", "puntocostole" } do
		local p = workspace:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			table.insert(keepOut, { p = p.Position, r = 210 }) -- palestra e arena si costruiscono in partita
		end
	end
	local hub = workspace:FindFirstChild("MapMarkers") and (workspace :: any).MapMarkers:FindFirstChild("HubSpawn")
	if hub then
		table.insert(keepOut, { p = hub.Position, r = 190 })
	end
	-- il teschio gigante e le costole (lunghi centinaia di studs): una fila di cerchi lungo l'asse
	-- lungo, cosi' le case non finiscono dentro le ossa
	local landmarks = workspace:FindFirstChild("Landmarks")
	for _, name in { "DragonSkull", "DragonRibs" } do
		local m = landmarks and landmarks:FindFirstChild(name)
		if m and m:IsA("Model") then
			local cf, size = m:GetBoundingBox()
			local long = if size.X > size.Z then cf.RightVector else cf.LookVector
			local length = math.max(size.X, size.Z)
			local r = math.min(size.X, size.Z) / 2 + 40
			for d = -length / 2, length / 2, r * 0.8 do
				table.insert(keepOut, { p = cf.Position + long * d, r = r })
			end
		end
	end
	local ctx: Ctx = {
		rng = Random.new(20261009),
		grid = obstacleGrid(),
		keepOut = keepOut,
		placed = {},
		fronts = {},
		paths = {},
		folder = root,
	}
	local report = {}
	for _, v in VILLAGES do
		local folder = Instance.new("Folder")
		folder.Name = v.name
		folder.Parent = root
		ctx.folder = folder
		ctx.fronts = {}
		ctx.paths = {}
		local before = #ctx.placed
		local ok, err = pcall(function()
			if v.kind == "shore" then
				shoreVillage(ctx, v.at, v.radius * SPREAD, v.count)
				stringLanterns(ctx, 12, 40, 8)
				entrance(ctx, v.at, v.radius * SPREAD * 0.6, v.name, false)
			elseif v.kind == "street" then
				streetVillage(ctx, v.a, v.b, v.name)
			elseif v.kind == "temple" then
				local toward = if hub then hub.Position - v.at else Vector3.xAxis
				if not templeComplex(ctx, v.at, toward) then
					-- se il punto esatto non va bene, qualche metro piu' in la'
					for k = 1, 12 do
						local p = v.at + Vector3.new(math.cos(k) * k * 12, 0, math.sin(k) * k * 12)
						if templeComplex(ctx, p, toward) then
							break
						end
					end
				end
			else
				clusterVillage(ctx, v.at, v.radius * SPREAD, v.count, v.japanese == true)
				if not v.japanese then
					stringLanterns(ctx, 12, 38, 6)
				end
				entrance(ctx, v.at, v.radius * SPREAD, v.name, v.japanese == true)
			end
			for _, path in ctx.paths do
				paint(path[1], path[2], if v.japanese then 4 else 5, if v.japanese then M.Ground else M.Pavement)
			end
		end)
		if not ok then
			warn("[Borghi] " .. v.name .. ": " .. tostring(err))
		end
		table.insert(report, string.format("%s %d", v.name, #ctx.placed - before))
		task.wait()
	end
	-- i capi della rete stradale: i borghi (sulla terra piu' vicina al centro), il campo base, la
	-- palestra e l'arena
	local nodes: { Node } = {}
	local centers = {}
	local function landNear(c: Vector3): Vector3?
		for r = 0, 200, 20 do
			for k = 0, (if r == 0 then 0 else 11) do
				local q = c + Vector3.new(math.cos(k / 12 * math.pi * 2) * r, 0, math.sin(k / 12 * math.pi * 2) * r)
				local h = probe(q.X, q.Z)
				if h and not h.water then
					return Vector3.new(q.X, h.y, q.Z)
				end
			end
		end
		return nil
	end
	for _, v in VILLAGES do
		local ends = if (v :: any).at then { (v :: any).at } else { (v :: any).a, (v :: any).b }
		table.insert(centers, (v :: any).at or ((v :: any).a + (v :: any).b) / 2)
		for _, c in ends do
			local p = landNear(c)
			if p then
				table.insert(nodes, { p = p, name = v.name, trim = 0 })
			end
		end
	end
	for _, spec in { { hub, "BASE CAMP", 60 }, { workspace:FindFirstChild("gym"), "TRAINING GROUNDS", 100 }, { workspace:FindFirstChild("puntocostole"), "DRAGON ARENA", 110 } } do
		local o = spec[1]
		if o and o:IsA("BasePart") then
			local p = landNear(o.Position)
			if p then
				table.insert(nodes, { p = p, name = spec[2], trim = spec[3] })
			end
		end
	end
	-- ponti sui fiumi
	local ponti = Instance.new("Folder")
	ponti.Name = "Ponti"
	ponti.Parent = root
	ctx.folder = ponti
	table.insert(report, "ponti " .. riverBridges(ctx, 250))
	-- casali sparsi
	local casali = Instance.new("Folder")
	casali.Name = "Casali"
	casali.Parent = root
	ctx.folder = casali
	local hamletSpots: { Vector3 } = {}
	local nCasali = hamlets(ctx, 34, centers, hamletSpots)
	table.insert(report, "casali " .. nCasali)
	-- strade (dopo case e casali: ci girano attorno)
	ctx.folder = root
	local okRoads, roadMsg = pcall(buildRoads, ctx, nodes, hamletSpots, map)
	if okRoads then
		table.insert(report, roadMsg)
	else
		warn("[Borghi] strade: " .. tostring(roadMsg))
	end
	-- via gli alberi e i sassi sotto gli edifici; con la mappa nuova diventano radure
	local removed = 0
	local function inside(p: Vector3, pad: number): boolean
		if ctx.roadCells and ctx.roadCells[math.floor(p.X / 16) .. "," .. math.floor(p.Z / 16)] then
			return true
		end
		for _, c in ctx.placed do
			if Vector2.new(p.X - c.p.X, p.Z - c.p.Z).Magnitude < c.r + pad then
				return true
			end
		end
		return false
	end
	local forest = workspace:FindFirstChild("Forest")
	for k, t in (if forest then forest:GetChildren() else {}) :: { Instance } do
		if t:IsA("Model") and TREES[t.Name] and inside(t:GetPivot().Position, 4) then
			t:Destroy()
			removed += 1
		end
		if k % 500 == 0 then
			task.wait()
		end
	end
	local deco = workspace:FindFirstChild("Decorazioni")
	for _, d in (if deco then deco:GetChildren() else {}) :: { Instance } do
		if d:IsA("BasePart") and inside(d.Position, 2) then
			d:Destroy()
		end
	end
	if map and map.features then
		map.features.clearings = map.features.clearings or {}
		for _, c in ctx.placed do
			table.insert(map.features.clearings, { x = c.p.X, z = c.p.Z, r = c.r + 4 })
		end
	end
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print(string.format("[MapGen] Borghi: %s (edifici %d, parti %d, alberi tolti %d)", table.concat(report, ", "), #ctx.placed, parts, removed))
	return root
end

------------------------------------------------------------------------------------------
-- prova: un esemplare di ogni edificio in fila (per le foto)

function Borghi.preview(at: Vector3?): Folder
	local old = workspace:FindFirstChild("BorghiProva")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "BorghiProva"
	local p = at or Vector3.new(-1850, 0, -300)
	local function ground(x: number, z: number): CFrame
		local hit = workspace:Raycast(Vector3.new(x, 3000, z), Vector3.new(0, -3200, 0), terrainOnly)
		return CFrame.new(x, (if hit then hit.Position.Y else 40) + 1, z)
	end
	chineseHouse(f, ground(p.X, p.Z), { w = 12, d = 10, floors = 1 })
	chineseHouse(f, ground(p.X + 30, p.Z), { w = 14, d = 11, floors = 2, balcony = true })
	chineseHouse(f, ground(p.X + 62, p.Z), { w = 13, d = 11, floors = 3, plaster = true, balcony = true })
	chineseHouse(f, ground(p.X + 92, p.Z), { w = 12, d = 10, floors = 2, shopSign = "TEA HOUSE" })
	minka(f, ground(p.X, p.Z + 40), 16, 11)
	pagoda(f, ground(p.X + 40, p.Z + 50), 12, 5)
	templeHall(f, ground(p.X + 90, p.Z + 50), 26, 16)
	torii(f, ground(p.X - 30, p.Z), 10, 13)
	paifang(f, ground(p.X - 30, p.Z + 40), 22, "LANTERN BAY")
	pavilion(f, ground(p.X - 30, p.Z + 75), 10)
	stoneLantern(f, ground(p.X - 12, p.Z - 12))
	local a = ground(p.X + 6, p.Z - 9).Position + Vector3.new(0, 10, 0)
	lanternString(f, a, a + Vector3.new(26, 0, 0), 5)
	f.Parent = workspace
	return f
end

Borghi._build = {
	chineseHouse = chineseHouse,
	minka = minka,
	pagoda = pagoda,
	templeHall = templeHall,
	torii = torii,
	paifang = paifang,
	pavilion = pavilion,
	stoneLantern = stoneLantern,
	lanternString = lanternString,
	redLantern = redLantern,
}

return Borghi
