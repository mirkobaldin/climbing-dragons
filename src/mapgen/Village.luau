--!strict
-- Villaggio della valle centrale e strutture sulla montagna, costruiti con Part:
--   * cerchio di tende attorno al falo' (verso il mare), dove si spawna
--   * cabine sul primo livello della mezzaluna, chalet di lusso vetrati sul secondo
--   * emporio (shop) accanto al cerchio delle tende
--   * lanterne con luci calde che proiettano ombre
--   * ponti giapponesi ad arco (taiko-bashi) sul fiume della valle
--   * campi base sulle piazzole del sentiero (tenda + falo')
--   * lampioni lungo la strada per la montagna e ponti di pietra dove passa sopra un fiume
-- Per usare modelli veri metti in ServerStorage > Buildings dei Model chiamati "Tent",
-- "Cabin", "Chalet", "Shop" o "Bridge": verranno clonati al posto di quelli a blocchi
-- (pivot = centro a terra, ingresso verso -Z).

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Heightmap = require(script.Parent.Heightmap)

local cos, sin, abs, max, min = math.cos, math.sin, math.abs, math.max, math.min

local Village = {}

local currentMap: Heightmap.Map? = nil
local buildTemplates: () -> ()

local function groundY(x: number, z: number): number
	return Heightmap.sampleH(currentMap :: Heightmap.Map, x, z)
end

local WOOD = Color3.fromRGB(120, 86, 58)
local WOOD_DARK = Color3.fromRGB(72, 52, 38)
local STONE = Color3.fromRGB(128, 124, 118)
local ROOF = Color3.fromRGB(70, 66, 64)
local LACQUER = Color3.fromRGB(176, 38, 32)
local WARM = Color3.fromRGB(255, 176, 96)
local LIGHT_WOOD = Color3.fromRGB(176, 136, 96)
local WINDOW_GLOW = Color3.fromRGB(255, 196, 120)
local SHUTTER = Color3.fromRGB(64, 86, 62)
local GLASS = Color3.fromRGB(168, 196, 210)
local FRAME = Color3.fromRGB(38, 38, 40)
local TENT_COLORS = {
	Color3.fromRGB(196, 110, 46),
	Color3.fromRGB(96, 112, 70),
	Color3.fromRGB(160, 50, 40),
	Color3.fromRGB(62, 92, 130),
	Color3.fromRGB(190, 170, 120),
}

type Builder = {
	block: (size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?) -> Part,
	wedge: (size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?) -> WedgePart,
	rope: (a: Vector3, b: Vector3) -> Part,
	model: Model,
}

local function builder(parent: Instance, name: string): Builder
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local function block(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.WoodPlanks
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local function wedge(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = size
		w.CFrame = cf
		w.Color = color
		w.Material = material or Enum.Material.WoodPlanks
		w.Parent = model
		return w
	end
	-- corda sottile tra due punti (tiranti delle tende)
	local function rope(a: Vector3, b: Vector3): Part
		local len = (b - a).Magnitude
		local r = block(Vector3.new(0.12, 0.12, len), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(200, 190, 160), Enum.Material.Fabric)
		r.CanCollide = false
		r.CastShadow = false
		return r
	end
	return { block = block, wedge = wedge, rope = rope, model = model }
end

local function warmLight(part: BasePart, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false -- decine di lampioni con le ombre: troppo pesante (le ombre restano sui falo')
	light.Parent = part
end

local function template(name: string): Model?
	local folder = ServerStorage:FindFirstChild("Buildings")
	local t = folder and folder:FindFirstChild(name)
	if t and t:IsA("Model") then
		return t
	end
	return nil
end

local function fromTemplate(name: string, parent: Instance, cf: CFrame): boolean
	local t = template(name)
	if not t then
		return false
	end
	local clone = t:Clone()
	for _, d in clone:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- i modelli del Toolbox a volte contengono script indesiderati
		end
	end
	clone:PivotTo(cf)
	clone.Parent = parent
	return true
end

-- Un modello di Mirko (ServerStorage.Modelli, anche nelle sottocartelle) alto "height", con la
-- base appoggiata in cf; niente script, niente collisioni (le mesh hanno la collisione a scatola)
local function userModel(name: string, parent: Instance, cf: CFrame, height: number?, collide: boolean?): Model?
	local store = ServerStorage:FindFirstChild("Modelli")
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
			d.CanCollide = collide == true
		end
	end
	local _, s0 = m:GetBoundingBox()
	if height then
		m:ScaleTo(m:GetScale() * height / math.max(s0.Y, 0.05))
	end
	m:PivotTo(cf.Rotation + m:GetPivot().Position)
	local box, s = m:GetBoundingBox()
	-- base un poco sopra il terreno (le gambe del banco finivano sotto terra)
	m:PivotTo(m:GetPivot() + (cf.Position - (box.Position - Vector3.new(0, s.Y / 2, 0))) + Vector3.new(0, 0.6, 0))
	-- se sotto gli angoli il terreno (o un pavimento) e' piu' alto, si alza fino a li'
	m.Parent = parent
	box, s = m:GetBoundingBox()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { m }
	local bottom = box.Position.Y - s.Y / 2
	local highest = -math.huge
	for _, k in { Vector3.new(0.45, 0, 0.45), Vector3.new(-0.45, 0, 0.45), Vector3.new(0.45, 0, -0.45), Vector3.new(-0.45, 0, -0.45), Vector3.zero } do
		local p = box:PointToWorldSpace(k * s)
		local hit = workspace:Raycast(Vector3.new(p.X, bottom + s.Y * 0.6, p.Z), Vector3.new(0, -s.Y - 20, 0), params)
		if hit then
			highest = math.max(highest, hit.Position.Y)
		end
	end
	if highest > bottom - 0.1 then
		m:PivotTo(m:GetPivot() + Vector3.new(0, highest - bottom + 0.15, 0))
	end
	return m
end

-- Punto a terra orientato: "facing" = direzione verso cui guarda l'ingresso
local function groundCFrame(x: number, z: number, facing: Vector3, lift: number?): CFrame
	local y = groundY(x, z)
	return CFrame.lookAt(Vector3.new(x, y + (lift or 0), z), Vector3.new(x, y + (lift or 0), z) + facing)
end

------------------------------------------------------------------------------------------

-- Tenda canadese: telo su due falde con i triangoli chiusi dietro, ingresso aperto con i
-- lembi arrotolati, paletti, tiranti e picchetti, telo a terra. Ingresso verso -Z.
local function tent(parent: Instance, cf: CFrame, color: Color3)
	if fromTemplate("Tent", parent, cf) then
		return
	end
	local b = builder(parent, "Tent")
	local L, HW, H = 10, 3.6, 5.2 -- lunghezza, mezza larghezza, altezza del colmo
	local slope = math.sqrt(HW * HW + H * H)
	local angle = math.atan2(HW, H)
	local darker = color:Lerp(Color3.new(0, 0, 0), 0.25)
	-- telo a terra
	b.block(Vector3.new(HW * 2 + 1.2, 0.2, L + 1.2), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(70, 64, 54), Enum.Material.Fabric)
	-- falde
	for _, side in { -1, 1 } do
		b.block(
			Vector3.new(0.2, slope, L),
			cf * CFrame.new(side * HW / 2, H / 2 + 0.2, 0) * CFrame.Angles(0, 0, side * angle),
			color,
			Enum.Material.Fabric
		)
	end
	-- triangolo posteriore chiuso (due cunei)
	for _, side in { -1, 1 } do
		b.wedge(
			Vector3.new(0.2, H, HW),
			cf * CFrame.new(side * HW / 2, H / 2 + 0.2, L / 2 - 0.1) * CFrame.Angles(0, if side < 0 then math.pi / 2 else -math.pi / 2, 0),
			darker,
			Enum.Material.Fabric
		)
	end
	-- ingresso: interno scuro e lembi arrotolati ai lati
	b.wedge(
		Vector3.new(0.1, H * 0.9, HW * 0.9),
		cf * CFrame.new(-HW * 0.45 / 2, H * 0.45 + 0.2, L / 2 - 0.6) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(28, 24, 20),
		Enum.Material.Fabric
	)
	b.wedge(
		Vector3.new(0.1, H * 0.9, HW * 0.9),
		cf * CFrame.new(HW * 0.45 / 2, H * 0.45 + 0.2, L / 2 - 0.6) * CFrame.Angles(0, -math.pi / 2, 0),
		Color3.fromRGB(28, 24, 20),
		Enum.Material.Fabric
	)
	for _, side in { -1, 1 } do
		local roll = b.block(Vector3.new(H * 0.8, 0.5, 0.5), cf * CFrame.new(side * HW * 0.45, H * 0.45, -L / 2 + 0.2) * CFrame.Angles(0, 0, math.pi / 2 + side * angle), darker, Enum.Material.Fabric)
		roll.Shape = Enum.PartType.Cylinder
	end
	-- paletti e colmo
	for _, z in { -L / 2, L / 2 } do
		b.block(Vector3.new(0.25, H + 0.6, 0.25), cf * CFrame.new(0, (H + 0.6) / 2, z), WOOD_DARK, Enum.Material.Wood)
	end
	b.block(Vector3.new(0.25, 0.25, L + 0.4), cf * CFrame.new(0, H + 0.25, 0), WOOD_DARK, Enum.Material.Wood)
	-- tiranti e picchetti
	for _, z in { -L / 2 - 2.5, L / 2 + 2.5 } do
		local top = (cf * CFrame.new(0, H + 0.4, if z < 0 then -L / 2 else L / 2)).Position
		local stake = (cf * CFrame.new(0, 0.2, z)).Position
		b.rope(top, stake)
		b.block(Vector3.new(0.2, 0.8, 0.2), CFrame.new(stake), WOOD_DARK, Enum.Material.Wood)
	end
	for _, side in { -1, 1 } do
		for _, z in { -L / 3, L / 3 } do
			local top = (cf * CFrame.new(side * HW * 0.55, H * 0.5, z)).Position
			local stake = (cf * CFrame.new(side * (HW + 2.2), 0.2, z)).Position
			b.rope(top, stake)
		end
	end
end

local function campfire(parent: Instance, cf: CFrame, benches: boolean): BasePart
	local b = builder(parent, "Campfire")
	for k = 0, 9 do
		local a = k / 10 * 2 * math.pi
		b.block(
			Vector3.new(1.5, 0.9, 1.3),
			cf * CFrame.new(cos(a) * 2.8, 0.35, sin(a) * 2.8) * CFrame.Angles(0.2 * sin(k), a, 0.25 * cos(k)),
			STONE:Lerp(Color3.new(0, 0, 0), (k % 3) * 0.1),
			Enum.Material.Slate
		)
	end
	-- legna a piramide
	for k = 0, 4 do
		local a = k / 5 * 2 * math.pi
		local log = b.block(
			Vector3.new(3.2, 0.5, 0.5),
			cf * CFrame.new(cos(a) * 0.7, 1, sin(a) * 0.7) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, 0.9),
			WOOD_DARK,
			Enum.Material.Wood
		)
		log.Shape = Enum.PartType.Cylinder
	end
	local embers = b.block(Vector3.new(0.3, 2.6, 2.6), cf * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 90, 30), Enum.Material.Neon)
	embers.Shape = Enum.PartType.Cylinder
	local core = b.block(Vector3.new(1, 1, 1), cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	CollectionService:AddTag(core, "HeatSource") -- ci si scalda (freddo in quota)
	core.CanCollide = false
	core.Transparency = 1
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 10
	fire.Color = Color3.fromRGB(255, 130, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
	fire.Parent = core
	local smoke = Instance.new("Smoke")
	smoke.Size = 3
	smoke.RiseVelocity = 4
	smoke.Opacity = 0.08
	smoke.Color = Color3.fromRGB(90, 90, 90)
	smoke.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 40
	light.Brightness = 4
	light.Shadows = true
	light.Parent = core
	if benches then
		for k = 0, 3 do
			local a = k / 4 * 2 * math.pi + 0.4
			local log = b.block(
				Vector3.new(7, 1.5, 1.5),
				cf * CFrame.new(cos(a) * 9, 0.7, sin(a) * 9) * CFrame.Angles(0, -a + math.pi / 2, 0),
				WOOD,
				Enum.Material.Wood
			)
			log.Shape = Enum.PartType.Cylinder
		end
	end
	return core
end

-- Finestra con cornice, vetro caldo illuminato da dentro, davanzale e (opz.) scuri aperti
local function window(b: Builder, cf: CFrame, w: number, h: number, shutters: boolean)
	b.block(Vector3.new(w + 0.6, h + 0.6, 0.3), cf * CFrame.new(0, 0, -0.05), WOOD_DARK, Enum.Material.Wood)
	local glass = b.block(Vector3.new(w, h, 0.35), cf, WINDOW_GLOW, Enum.Material.Glass)
	glass.Transparency = 0.35
	b.block(Vector3.new(0.18, h, 0.4), cf, WOOD_DARK, Enum.Material.Wood)
	b.block(Vector3.new(w, 0.18, 0.4), cf, WOOD_DARK, Enum.Material.Wood)
	b.block(Vector3.new(w + 1, 0.3, 0.8), cf * CFrame.new(0, -h / 2 - 0.35, -0.3), WOOD_DARK, Enum.Material.Wood)
	if shutters then
		for _, side in { -1, 1 } do
			b.block(Vector3.new(w / 2, h + 0.2, 0.2), cf * CFrame.new(side * (w * 0.75 + 0.45), 0, -0.3), SHUTTER, Enum.Material.WoodPlanks)
		end
	end
end

-- Baita di tronchi: basamento in pietra, pareti di tronchi sovrapposti con gli incroci
-- sporgenti agli angoli, veranda coperta con panca e lanterna, tetto a due falde in
-- scandole con sporgenze, comignolo in pietra con fumo, finestre illuminate.
local function cabin(parent: Instance, cf: CFrame)
	if fromTemplate("Cabin", parent, cf) then
		return
	end
	local b = builder(parent, "Cabin")
	local W, D, H = 18, 14, 8.4 -- larghezza, profondita', altezza pareti
	local B = 1.6 -- altezza basamento
	local LOG = 1.2
	local rise = 5.2
	local roofAngle = math.atan2(rise, W / 2)

	-- basamento in pietra (scende sotto terra per i pendii)
	b.block(Vector3.new(W + 1.6, B + 4, D + 1.6), cf * CFrame.new(0, B / 2 - 2, 0), STONE, Enum.Material.Cobblestone)
	-- pavimento della veranda
	b.block(Vector3.new(W + 1.6, 0.5, 5), cf * CFrame.new(0, B - 0.25, -D / 2 - 2.5), LIGHT_WOOD, Enum.Material.WoodPlanks)
	b.block(Vector3.new(W + 1.6, B + 3, 5), cf * CFrame.new(0, (B - 0.5) / 2 - 1.5, -D / 2 - 2.5), STONE, Enum.Material.Cobblestone)

	-- pareti di tronchi (i tronchi dei lati corti sfalsati di mezzo tronco)
	local rows = math.floor(H / LOG)
	for r = 0, rows - 1 do
		local y = B + LOG / 2 + r * LOG
		local shade = if r % 2 == 0 then WOOD else WOOD:Lerp(WOOD_DARK, 0.25)
		for _, z in { -D / 2, D / 2 } do
			local isFront = z < 0
			if isFront and y > B + 0.5 and y < B + 7 then
				-- facciata: tronchi spezzati attorno alla porta (al centro, larga 4)
				for _, side in { -1, 1 } do
					local len = W / 2 - 2 + 1.4
					local log = b.block(Vector3.new(len, LOG, LOG), cf * CFrame.new(side * (2 + len / 2 - 0.1), y, z), shade, Enum.Material.Wood)
					log.Shape = Enum.PartType.Cylinder
				end
			else
				local log = b.block(Vector3.new(W + 2.4, LOG, LOG), cf * CFrame.new(0, y, z), shade, Enum.Material.Wood)
				log.Shape = Enum.PartType.Cylinder
			end
		end
		for _, x in { -W / 2, W / 2 } do
			local log = b.block(
				Vector3.new(D + 2.4, LOG, LOG),
				cf * CFrame.new(x, y + LOG / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
				shade,
				Enum.Material.Wood
			)
			log.Shape = Enum.PartType.Cylinder
		end
	end
	-- interno: pavimento, soffitto, letto, tavolo, stufa (si entra dalla porta aperta)
	b.block(Vector3.new(W - 0.6, 0.3, D - 0.6), cf * CFrame.new(0, B + 0.15, 0), LIGHT_WOOD, Enum.Material.WoodPlanks)
	b.block(Vector3.new(W - 0.6, 0.4, D - 0.6), cf * CFrame.new(0, B + H + 0.2, 0), WOOD_DARK, Enum.Material.WoodPlanks)
	b.block(Vector3.new(5, 1.4, 7.5), cf * CFrame.new(-W / 2 + 3.6, B + 0.9, D / 2 - 4.5), Color3.fromRGB(150, 60, 50), Enum.Material.Fabric)
	b.block(Vector3.new(5, 0.6, 1.4), cf * CFrame.new(-W / 2 + 3.6, B + 1.9, D / 2 - 1.2), Color3.fromRGB(236, 230, 220), Enum.Material.Fabric)
	b.block(Vector3.new(4, 0.4, 3), cf * CFrame.new(W / 4, B + 3, 1), LIGHT_WOOD, Enum.Material.Wood)
	b.block(Vector3.new(0.5, 2.8, 0.5), cf * CFrame.new(W / 4, B + 1.4, 1), WOOD_DARK, Enum.Material.Wood)
	local stove = b.block(Vector3.new(2.4, 3, 2.4), cf * CFrame.new(W / 4, B + 1.5, D / 2 - 2), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
	local ember = b.block(Vector3.new(1.4, 0.8, 0.2), stove.CFrame * CFrame.new(0, -0.3, -1.25), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	ember.CanCollide = false
	CollectionService:AddTag(ember, "HeatSource")
	-- porta aperta verso l'interno (si passa)
	local door = b.block(Vector3.new(4, 7, 0.4), cf * CFrame.new(-2, B + 3.5, -D / 2 + 0.3) * CFrame.Angles(0, math.rad(80), 0) * CFrame.new(2, 0, 0), Color3.fromRGB(92, 60, 38), Enum.Material.WoodPlanks)
	door.CanCollide = false
	b.block(Vector3.new(4.6, 0.5, 0.8), cf * CFrame.new(0, B + 7.2, -D / 2 - 0.3), WOOD_DARK, Enum.Material.Wood)
	-- finestre
	for _, x in { -W / 4 - 1, W / 4 + 1 } do
		window(b, cf * CFrame.new(x, B + 4.4, -D / 2 - 0.7) * CFrame.Angles(0, math.pi, 0), 3.2, 2.8, true)
	end
	for _, side in { -1, 1 } do
		window(b, cf * CFrame.new(side * (W / 2 + 0.7), B + 4.4, 0) * CFrame.Angles(0, side * math.pi / 2, 0), 3, 2.6, true)
	end

	-- frontoni di tavole (triangoli) e tetto
	local top = B + H + LOG / 2
	for _, z in { -D / 2, D / 2 } do
		for _, side in { -1, 1 } do
			b.wedge(
				Vector3.new(0.6, rise, W / 2),
				cf * CFrame.new(side * W / 4, top + rise / 2, z) * CFrame.Angles(0, if side < 0 then math.pi / 2 else -math.pi / 2, 0),
				WOOD_DARK,
				Enum.Material.WoodPlanks
			)
		end
	end
	local slope = (W / 2 + 2.2) / math.cos(roofAngle)
	for _, side in { -1, 1 } do
		b.block(
			Vector3.new(slope, 0.8, D + 8),
			cf * CFrame.new(side * (W / 4 + 0.55), top + rise / 2 + 0.55, -2) * CFrame.Angles(0, 0, -side * roofAngle),
			ROOF,
			Enum.Material.Slate
		)
		-- bordo di legno sotto le scandole
		b.block(
			Vector3.new(slope, 0.3, D + 8.2),
			cf * CFrame.new(side * (W / 4 + 0.55), top + rise / 2 + 0.05, -2) * CFrame.Angles(0, 0, -side * roofAngle),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	b.block(Vector3.new(0.9, 0.9, D + 8.4), cf * CFrame.new(0, top + rise + 0.8, -2), WOOD_DARK, Enum.Material.Wood)
	-- pali della veranda
	for _, x in { -W / 2 - 0.3, -W / 6, W / 6, W / 2 + 0.3 } do
		b.block(Vector3.new(0.7, top - B + 0.5, 0.7), cf * CFrame.new(x, B + (top - B) / 2, -D / 2 - 4.6), WOOD_DARK, Enum.Material.Wood)
	end
	-- panca e barile in veranda
	b.block(Vector3.new(4.5, 0.4, 1.3), cf * CFrame.new(-W / 4 - 1, B + 1.5, -D / 2 - 1.4), LIGHT_WOOD, Enum.Material.WoodPlanks)
	for _, x in { -W / 4 - 2.8, -W / 4 + 0.8 } do
		b.block(Vector3.new(0.4, 1.3, 1.1), cf * CFrame.new(x, B + 0.65, -D / 2 - 1.4), WOOD_DARK, Enum.Material.Wood)
	end
	local barrel = b.block(Vector3.new(2.6, 2, 2), cf * CFrame.new(W / 2 - 1.6, B + 1.3, -D / 2 - 1.6) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.Wood)
	barrel.Shape = Enum.PartType.Cylinder
	-- legnaia sul fianco
	for k = 0, 2 do
		for j = 0, 4 do
			local log = b.block(
				Vector3.new(4, 0.9, 0.9),
				cf * CFrame.new(W / 2 + 2.6, B - 1 + 0.45 + k * 0.8, -D / 2 + 2 + j * 0.95 + (k % 2) * 0.45),
				WOOD:Lerp(Color3.fromRGB(150, 120, 90), (j % 2) * 0.5),
				Enum.Material.Wood
			)
			log.Shape = Enum.PartType.Cylinder
		end
	end
	-- comignolo con fumo
	local chimneyH = top + rise + 3 - B
	b.block(Vector3.new(2.6, chimneyH + 2, 2.6), cf * CFrame.new(W / 4, B + chimneyH / 2 - 1, D / 4), STONE, Enum.Material.Cobblestone)
	local flue = b.block(Vector3.new(1.4, 0.4, 1.4), cf * CFrame.new(W / 4, B + chimneyH, D / 4), Color3.fromRGB(20, 20, 20), Enum.Material.Slate)
	local smoke = Instance.new("Smoke")
	smoke.Size = 2
	smoke.RiseVelocity = 5
	smoke.Opacity = 0.06
	smoke.Color = Color3.fromRGB(120, 120, 120)
	smoke.Parent = flue
	-- luci: lanterna in veranda e luce calda dentro
	local lamp = b.block(Vector3.new(0.8, 1.1, 0.8), cf * CFrame.new(2.8, B + 6.4, -D / 2 - 0.9), WARM, Enum.Material.Neon)
	lamp.CanCollide = false
	warmLight(lamp, 20, 2)
	local inside = b.block(Vector3.one, cf * CFrame.new(0, B + H - 2, 0), WARM, Enum.Material.Neon)
	inside.Transparency = 1
	inside.CanCollide = false
	warmLight(inside, 16, 1.2)
end

local function glassPane(b: Builder, size: Vector3, cf: CFrame): Part
	local g = b.block(size, cf, GLASS, Enum.Material.Glass)
	g.Transparency = 0.6
	g.Reflectance = 0.2
	g.CastShadow = false
	return g
end

-- Mezzo frontone triangolare (side = -1 sinistra, 1 destra), lato alto verso il centro
local function gableHalf(b: Builder, cf: CFrame, side: number, halfWidth: number, height: number, glass: boolean)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = Vector3.new(0.4, height, halfWidth)
	w.CFrame = cf * CFrame.new(side * halfWidth / 2, height / 2, 0) * CFrame.Angles(0, -side * math.pi / 2, 0)
	if glass then
		w.Material = Enum.Material.Glass
		w.Color = GLASS
		w.Transparency = 0.55
		w.Reflectance = 0.15
	else
		w.Material = Enum.Material.WoodPlanks
		w.Color = WOOD_DARK
	end
	w.Parent = b.model
end

-- Chalet di lusso: basamento in pietra con terrazza, piano terra tutto vetrato con travi
-- nere, piano alto a capanna con frontone di vetro, grande tetto in ardesia a sbalzo,
-- camino in pietra, terrazza con vasca idromassaggio, salotto illuminato dentro.
local function chalet(parent: Instance, cf: CFrame)
	if fromTemplate("Chalet", parent, cf) then
		return
	end
	local b = builder(parent, "LuxuryChalet")
	local W, D = 30, 22
	local G0, GH = 3.6, 10 -- quota e altezza del piano terra
	local UP = G0 + GH + 0.8 -- quota del piano alto
	local ROOF_ANGLE = 0.72
	local gableH = (W / 2) * math.tan(ROOF_ANGLE)

	-- basamento in pietra (scende sotto terra) e terrazza di legno verso la valle
	b.block(Vector3.new(W + 4, G0 + 5, D + 14), cf * CFrame.new(0, (G0 - 5) / 2, -5), STONE, Enum.Material.Slate)
	for k = 0, 3 do
		-- gradini
		b.block(Vector3.new(8, 0.9, 1.4), cf * CFrame.new(-W / 2 + 6, 0.45 + k * 0.9, -D / 2 - 12.8 + k * 1.4), STONE, Enum.Material.Slate)
	end
	b.block(Vector3.new(W + 4, 0.4, 12), cf * CFrame.new(0, G0 + 0.2, -D / 2 - 6), LIGHT_WOOD, Enum.Material.WoodPlanks)
	b.block(Vector3.new(W, 0.5, D), cf * CFrame.new(0, G0 + 0.25, 0), Color3.fromRGB(200, 190, 176), Enum.Material.Marble)

	-- piano terra: parete di fondo in pietra, vetrate giganti sugli altri tre lati
	b.block(Vector3.new(W, GH, 1.2), cf * CFrame.new(0, G0 + GH / 2, D / 2 - 0.6), STONE, Enum.Material.Slate)
	-- vetrata frontale con porta scorrevole aperta al centro (larga 6)
	for _, side in { -1, 1 } do
		glassPane(b, Vector3.new(W / 2 - 3, GH, 0.3), cf * CFrame.new(side * (W / 4 + 1.5), G0 + GH / 2, -D / 2))
	end
	glassPane(b, Vector3.new(6, GH - 8, 0.3), cf * CFrame.new(0, G0 + GH - (GH - 8) / 2, -D / 2)).CanCollide = true
	-- scala interna per il piano alto (lungo il lato sinistro)
	local steps = math.floor((UP - G0) / 1.1)
	for k = 1, steps do
		b.block(Vector3.new(3.6, 0.5, 1.6), cf * CFrame.new(-W / 2 + 2.3, G0 + k * 1.1 - 0.25, D / 2 - 1.5 - k * 1.3), LIGHT_WOOD, Enum.Material.WoodPlanks)
	end
	for _, side in { -1, 1 } do
		glassPane(b, Vector3.new(0.3, GH, D), cf * CFrame.new(side * W / 2, G0 + GH / 2, 0))
		b.block(Vector3.new(0.8, GH, 0.8), cf * CFrame.new(side * W / 2, G0 + GH / 2, -D / 2), FRAME, Enum.Material.Metal)
		for z = -D / 2 + 5.5, D / 2 - 4, 5.5 do
			b.block(Vector3.new(0.4, GH, 0.4), cf * CFrame.new(side * W / 2, G0 + GH / 2, z), FRAME, Enum.Material.Metal)
		end
	end
	for x = -W / 2 + 5, W / 2 - 5, 5 do
		if math.abs(x) > 3.5 then
			b.block(Vector3.new(0.4, GH, 0.4), cf * CFrame.new(x, G0 + GH / 2, -D / 2), FRAME, Enum.Material.Metal)
		end
	end
	b.block(Vector3.new(W + 0.4, 0.5, 0.5), cf * CFrame.new(0, G0 + GH, -D / 2), FRAME, Enum.Material.Metal)

	-- solaio a sbalzo con fascia di legno scuro e balcone con parapetto di vetro
	-- solaio con il buco della scala sul lato sinistro
	b.block(Vector3.new(W + 2 - 4.6, 1.2, D + 10), cf * CFrame.new(2.3, UP - 0.6, -4), WOOD_DARK, Enum.Material.Wood)
	b.block(Vector3.new(4.6, 1.2, 10), cf * CFrame.new(-W / 2 + 1.3, UP - 0.6, -D / 2 - 4), WOOD_DARK, Enum.Material.Wood)
	glassPane(b, Vector3.new(W + 2, 3.4, 0.25), cf * CFrame.new(0, UP + 1.7, -D / 2 - 9))
	for _, side in { -1, 1 } do
		glassPane(b, Vector3.new(0.25, 3.4, 9), cf * CFrame.new(side * (W / 2 + 1), UP + 1.7, -D / 2 - 4.5))
	end
	b.block(Vector3.new(W + 2.2, 0.25, 0.4), cf * CFrame.new(0, UP + 3.45, -D / 2 - 9), FRAME, Enum.Material.Metal)
	-- travi a vista che reggono il balcone
	for _, x in { -W / 2 + 1, -W / 6, W / 6, W / 2 - 1 } do
		b.block(Vector3.new(0.9, 0.9, 10), cf * CFrame.new(x, UP - 1.6, -D / 2 - 4), WOOD_DARK, Enum.Material.Wood)
		b.block(Vector3.new(0.9, UP - 1.2 - G0, 0.9), cf * CFrame.new(x, G0 + (UP - 1.2 - G0) / 2, -D / 2 - 8.6), WOOD_DARK, Enum.Material.Wood)
	end

	-- piano alto: pareti laterali di legno, frontone tutto vetro verso la valle, tetto a sbalzo
	for _, side in { -1, 1 } do
		b.block(Vector3.new(0.8, 3, D), cf * CFrame.new(side * (W / 2 - 0.4), UP + 1.5, 0), LIGHT_WOOD, Enum.Material.WoodPlanks)
	end
	local slope = (W / 2 + 3) / math.cos(ROOF_ANGLE)
	for _, side in { -1, 1 } do
		b.block(
			Vector3.new(slope, 1.2, D + 8),
			cf * CFrame.new(side * (W / 4 + 0.9), UP + gableH / 2 + 0.7, -1.5) * CFrame.Angles(0, 0, -side * ROOF_ANGLE),
			ROOF,
			Enum.Material.Slate
		)
		b.block(
			Vector3.new(slope, 0.4, D + 8.2),
			cf * CFrame.new(side * (W / 4 + 0.9), UP + gableH / 2, -1.5) * CFrame.Angles(0, 0, -side * ROOF_ANGLE),
			LIGHT_WOOD,
			Enum.Material.WoodPlanks
		)
		gableHalf(b, cf * CFrame.new(0, UP, -D / 2 - 1), side, W / 2, gableH, true)
		gableHalf(b, cf * CFrame.new(0, UP, D / 2 - 0.5), side, W / 2, gableH, false)
	end
	b.block(Vector3.new(1, 1, D + 8.4), cf * CFrame.new(0, UP + gableH + 1.2, -1.5), WOOD_DARK, Enum.Material.Wood)
	for x = -10, 10, 5 do
		local h = gableH * (1 - math.abs(x) / (W / 2))
		b.block(Vector3.new(0.35, h, 0.6), cf * CFrame.new(x, UP + h / 2, -D / 2 - 1), FRAME, Enum.Material.Metal)
	end
	b.block(Vector3.new(W * 0.7, 0.4, 0.6), cf * CFrame.new(0, UP + gableH * 0.4, -D / 2 - 1), FRAME, Enum.Material.Metal)

	-- camino in pietra che esce dal tetto, con fuoco visibile nel salotto
	local chimneyH = UP + gableH + 5
	b.block(Vector3.new(4, chimneyH, 4), cf * CFrame.new(W / 2 - 6, chimneyH / 2, D / 4), STONE, Enum.Material.Cobblestone)
	b.block(Vector3.new(4.6, 0.6, 4.6), cf * CFrame.new(W / 2 - 6, chimneyH, D / 4), Color3.fromRGB(60, 58, 56), Enum.Material.Slate)
	local fire = b.block(Vector3.new(2.4, 1.4, 1), cf * CFrame.new(W / 2 - 6, G0 + 1.2, D / 4 - 2.1), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	CollectionService:AddTag(fire, "HeatSource")
	fire.CanCollide = false
	local flames = Instance.new("Fire")
	flames.Size = 2
	flames.Heat = 4
	flames.Parent = fire
	warmLight(fire, 22, 2.2)

	-- salotto: divano ad angolo, tappeto, tavolino, lampada ad arco, tavolo da pranzo
	local sofa = Color3.fromRGB(206, 196, 180)
	b.block(Vector3.new(11, 1.4, 3.6), cf * CFrame.new(-5, G0 + 1.2, 4), sofa, Enum.Material.Fabric)
	b.block(Vector3.new(11, 2.4, 1), cf * CFrame.new(-5, G0 + 2.2, 5.6), sofa, Enum.Material.Fabric)
	b.block(Vector3.new(3.6, 1.4, 6), cf * CFrame.new(-9.2, G0 + 1.2, 0.6), sofa, Enum.Material.Fabric)
	b.block(Vector3.new(12, 0.1, 9), cf * CFrame.new(-4, G0 + 0.55, 0.5), Color3.fromRGB(120, 60, 50), Enum.Material.Fabric)
	b.block(Vector3.new(5, 1, 3), cf * CFrame.new(-4, G0 + 1, -0.5), LIGHT_WOOD, Enum.Material.Wood)
	b.block(Vector3.new(8, 0.4, 4), cf * CFrame.new(6, G0 + 3.2, -3), LIGHT_WOOD, Enum.Material.Wood)
	for _, x in { 3, 9 } do
		b.block(Vector3.new(0.5, 2.7, 3), cf * CFrame.new(x, G0 + 1.85, -3), WOOD_DARK, Enum.Material.Wood)
	end
	local pendant = b.block(Vector3.new(1.4, 0.8, 1.4), cf * CFrame.new(6, G0 + 7.5, -3), WARM, Enum.Material.Neon)
	pendant.CanCollide = false
	warmLight(pendant, 18, 1.6)

	-- vasca idromassaggio sulla terrazza, con vapore e luce azzurra
	local tubCf = cf * CFrame.new(W / 2 - 5.5, G0 + 1, -D / 2 - 6)
	b.block(Vector3.new(8, 2, 8), tubCf, WOOD_DARK, Enum.Material.WoodPlanks)
	local water = b.block(Vector3.new(7, 0.3, 7), tubCf * CFrame.new(0, 1.05, 0), Color3.fromRGB(80, 200, 220), Enum.Material.Glass)
	water.Transparency = 0.25
	water.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(90, 210, 240)
	glow.Range = 12
	glow.Brightness = 2
	glow.Parent = water
	local steam = Instance.new("Smoke")
	steam.Size = 4
	steam.RiseVelocity = 1.5
	steam.Opacity = 0.05
	steam.Color = Color3.fromRGB(240, 240, 240)
	steam.Parent = water
	-- lettini
	for k = 0, 1 do
		b.block(Vector3.new(2.4, 0.6, 6), cf * CFrame.new(-W / 2 + 4 + k * 3.4, G0 + 1, -D / 2 - 6), Color3.fromRGB(236, 232, 224), Enum.Material.Fabric)
	end

	-- luci calde interne (si vedono attraverso le vetrate) e sotto la gronda
	for _, y in { G0 + GH - 1.5, UP + gableH * 0.45 } do
		local lamp = b.block(Vector3.new(1, 1, 1), cf * CFrame.new(0, y, 0), WARM, Enum.Material.Neon)
		lamp.Transparency = 1
		lamp.CanCollide = false
		warmLight(lamp, 30, 2)
	end
	local strip = b.block(Vector3.new(W, 0.25, 0.25), cf * CFrame.new(0, UP - 1.3, -D / 2 - 8.9), WARM, Enum.Material.Neon)
	strip.CanCollide = false
	for _, x in { -W / 2 - 1, W / 2 + 1 } do
		local wall = b.block(Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(x, G0 + 5, -D / 2 - 11), WARM, Enum.Material.Neon)
		wall.CanCollide = false
		warmLight(wall, 16, 1.4)
	end
end

-- Emporio: bancone con tenda a strisce, insegna, scaffali con merce, casse e barili.
-- Il bancone ha un prompt "Compra" (gestito dal server tramite il tag ShopCounter).
-- l'Emporio del kit al posto del negozio: un bancone invisibile (tag "ShopCounter") sul
-- bancone vero tiene il prompt che apre il negozio (server/Shop lo collega)
function Village.placeEmporio(parent: Instance, template: Model, cf: CFrame): Model
	local m = template:Clone()
	m.Name = "Shop"
	m:PivotTo(cf)
	m:ScaleTo(m:GetScale() * 4) -- in scala 4 come gli edifici dei borghi
	local _, size = m:GetBoundingBox()
	-- il bancone (invisibile, col prompt) a terra appena dentro l'ingresso
	local counter = Instance.new("Part")
	counter.Name = "Counter"
	counter.Anchored, counter.CanCollide, counter.CanQuery, counter.Transparency = true, false, false, 1
	counter.Size = Vector3.new(14, 4, 3)
	counter.CFrame = cf * CFrame.new(0, 2.8, -size.Z / 2 + 10)
	counter.Parent = m
	CollectionService:AddTag(counter, "ShopCounter")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop"
	prompt.ObjectText = "General store"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	-- l'insegna grande sulla facciata
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name == "SIGN" then
			local gui = Instance.new("SurfaceGui")
			-- la faccia della tavola che guarda come la facciata
			local look = cf.LookVector
			local best, bestDot = Enum.NormalId.Front, -2
			for _, n in Enum.NormalId:GetEnumItems() do
				local d = p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(n)):Dot(look)
				if d > bestDot then
					best, bestDot = n, d
				end
			end
			gui.Face = best
			gui.PixelsPerStud = 25
			gui.LightInfluence = 0.3
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.Fantasy
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(240, 200, 100)
			label.Text = "GENERAL STORE"
			label.Parent = gui
			gui.Parent = p
		end
	end
	m.Parent = parent
	return m
end

local function shop(parent: Instance, cf: CFrame)
	if fromTemplate("Shop", parent, cf) then
		return
	end
	-- l'Emporio fatto in Blender (ServerStorage.BorghiKit), col bancone che apre il negozio
	local kitFolder = ServerStorage:FindFirstChild("BorghiKit")
	local emporio = kitFolder and kitFolder:FindFirstChild("Emporio")
	if emporio and emporio:IsA("Model") then
		Village.placeEmporio(parent, emporio, cf)
		return
	end
	-- lo shop di Mirko (Modelli.shop), grandezza originale, con collisioni; il bancone invisibile
	-- tiene il prompt dell'emporio
	local holder = Instance.new("Model")
	holder.Name = "Shop"
	holder.Parent = parent
	if userModel("shop", holder, cf, nil, true) then
		local counter = Instance.new("Part")
		counter.Name = "Counter"
		counter.Anchored, counter.CanCollide, counter.Transparency = true, false, 1
		counter.Size = Vector3.new(14, 4, 3)
		counter.CFrame = cf * CFrame.new(0, 3, -6)
		counter.Parent = holder
		CollectionService:AddTag(counter, "ShopCounter")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Shop"
		prompt.ObjectText = "General store"
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = counter
		return
	end
	holder:Destroy()
	local b = builder(parent, "Shop")
	local W, D, H = 22, 16, 11
	b.block(Vector3.new(W + 2, 1, D + 6), cf * CFrame.new(0, 0.5, -2), LIGHT_WOOD, Enum.Material.WoodPlanks)
	b.block(Vector3.new(W, H, 1), cf * CFrame.new(0, 1 + H / 2, D / 2), WOOD, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		b.block(Vector3.new(1, H, D), cf * CFrame.new(side * W / 2, 1 + H / 2, 0), WOOD, Enum.Material.WoodPlanks)
		b.block(Vector3.new(1.2, H + 1, 1.2), cf * CFrame.new(side * W / 2, 1.5 + H / 2, -D / 2), WOOD_DARK, Enum.Material.Wood)
	end
	b.block(Vector3.new(W + 3, 1, D + 3), cf * CFrame.new(0, H + 2.4, 0.5) * CFrame.Angles(-0.12, 0, 0), ROOF, Enum.Material.Slate)

	-- Tenda a strisce inclinata sopra il bancone
	for k = 0, 6 do
		local x = -W / 2 + 1.6 + k * ((W - 3.2) / 6)
		b.block(
			Vector3.new(W / 7, 0.3, 6),
			cf * CFrame.new(x, H - 0.5, -D / 2 - 2.6) * CFrame.Angles(0.35, 0, 0),
			if k % 2 == 0 then Color3.fromRGB(176, 42, 36) else Color3.fromRGB(236, 228, 210),
			Enum.Material.Fabric
		)
	end

	-- Insegna
	local sign = b.block(Vector3.new(14, 3, 0.4), cf * CFrame.new(0, H + 1.2, -D / 2 - 0.6), WOOD_DARK, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "GENERAL STORE"
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 140)
	label.Parent = gui

	-- Bancone con prompt di acquisto
	local counter = b.block(Vector3.new(W - 4, 3.6, 2), cf * CFrame.new(0, 2.8, -D / 2 + 1.5), LIGHT_WOOD, Enum.Material.WoodPlanks)
	counter.Name = "Counter"
	CollectionService:AddTag(counter, "ShopCounter")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = "Store: restock pitons"
	prompt.MaxActivationDistance = 10
	prompt.Parent = counter

	-- Scaffali con merce colorata
	for level = 0, 2 do
		b.block(Vector3.new(W - 4, 0.4, 2.5), cf * CFrame.new(0, 3 + level * 2.8, D / 2 - 2), WOOD_DARK, Enum.Material.Wood)
		for k = 0, 5 do
			b.block(
				Vector3.new(1.6, 1.6, 1.6),
				cf * CFrame.new(-W / 2 + 4 + k * 2.8, 4 + level * 2.8, D / 2 - 2),
				TENT_COLORS[1 + (k + level) % #TENT_COLORS],
				Enum.Material.Fabric
			)
		end
	end

	-- Casse e barili fuori
	for k, o in { { -W / 2 - 3, -4 }, { -W / 2 - 3, 0 }, { W / 2 + 3, -3 } } do
		b.block(Vector3.new(3, 3, 3), cf * CFrame.new(o[1], 2.5, o[2]) * CFrame.Angles(0, k * 0.4, 0), WOOD, Enum.Material.WoodPlanks)
	end
	local barrel = b.block(Vector3.new(4, 3, 3), cf * CFrame.new(W / 2 + 3, 3, 1.5) * CFrame.Angles(0, 0, math.pi / 2), WOOD_DARK, Enum.Material.Wood)
	barrel.Shape = Enum.PartType.Cylinder

	local lamp = b.block(Vector3.new(1, 1, 1), cf * CFrame.new(0, H - 1.5, 0), WARM, Enum.Material.Neon)
	warmLight(lamp, 22, 1.8)
end

-- Lanterna in stile giapponese (toro): base e cappello in pietra, luce calda dentro
-- Banco da lavoro: tavolo robusto con incudine, morsa e attrezzi appesi; il prompt apre il
-- menu per costruire l'equipaggiamento (Ramponi, Tuta termica, Rampino...)
local function workbench(parent: Instance, cf: CFrame)
	local b = builder(parent, "Workbench")
	local IRON = Color3.fromRGB(46, 46, 50)
	-- il banco di Mirko (Modelli.Banco_Crafting); il piano invisibile tiene il prompt
	if userModel("Banco_Crafting", b.model, cf, 7) then
		local top = b.block(Vector3.new(10, 0.3, 4), cf * CFrame.new(0, 3.95, 0), WOOD, Enum.Material.WoodPlanks)
		top.Name = "Bench"
		top.Transparency = 1
		CollectionService:AddTag(top, "Workbench")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Craft"
		prompt.ObjectText = "Workbench"
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = top
		return
	end
	b.block(Vector3.new(10, 0.8, 4), cf * CFrame.new(0, 3.4, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -4.4, 4.4 } do
		for _, z in { -1.5, 1.5 } do
			b.block(Vector3.new(0.7, 3, 0.7), cf * CFrame.new(x, 1.5, z), WOOD_DARK, Enum.Material.Wood)
		end
	end
	b.block(Vector3.new(9, 0.4, 3), cf * CFrame.new(0, 1, 0), WOOD_DARK, Enum.Material.WoodPlanks)
	-- incudine
	b.block(Vector3.new(1.2, 1, 1), cf * CFrame.new(-2.5, 4.3, 0), IRON, Enum.Material.Metal)
	b.block(Vector3.new(2.6, 0.7, 1.2), cf * CFrame.new(-2.5, 5.1, 0), IRON, Enum.Material.Metal)
	b.wedge(Vector3.new(1.2, 0.7, 1), cf * CFrame.new(-0.7, 5.1, 0) * CFrame.Angles(0, math.pi / 2, 0), IRON, Enum.Material.Metal)
	-- lingotti e corda
	for k = 0, 2 do
		b.block(Vector3.new(1.4, 0.4, 0.6), cf * CFrame.new(2 + k * 0.2, 4 + k * 0.4, -0.6), Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	end
	local coil = b.block(Vector3.new(0.6, 1.8, 1.8), cf * CFrame.new(3.4, 4.2, 0.9) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(196, 150, 80), Enum.Material.Fabric)
	coil.Shape = Enum.PartType.Cylinder
	-- pannello con attrezzi appesi
	b.block(Vector3.new(10, 5, 0.4), cf * CFrame.new(0, 6.3, 2), WOOD, Enum.Material.WoodPlanks)
	for k = -2, 2 do
		b.block(Vector3.new(0.25, 2.4, 0.25), cf * CFrame.new(k * 1.8, 6.5, 1.7) * CFrame.Angles(0, 0, 0.2 * k), IRON, Enum.Material.Metal)
	end
	local top = b.block(Vector3.new(10, 0.3, 4), cf * CFrame.new(0, 3.95, 0), WOOD, Enum.Material.WoodPlanks)
	top.Name = "Bench"
	CollectionService:AddTag(top, "Workbench")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Craft gear"
	prompt.ObjectText = "Workbench"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
	local lamp = b.block(Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(0, 9.2, 1.6), WARM, Enum.Material.Neon)
	lamp.CanCollide = false
	warmLight(lamp, 18, 1.8)
end

-- Nido di cova: anello di pietre con paglia, uova finte e bracieri; il prompt (tag
-- "Incubator") mette a covare l'uovo che porti o apre il menu Draghi
local function nest(parent: Instance, cf: CFrame)
	local b = builder(parent, "Nido")
	local STRAW = Color3.fromRGB(206, 176, 96)
	-- il nido di Mirko (Modelli.Nidi.Nido_Roccia) al posto di pietre, paglia e uova finte
	local custom = userModel("Nido_Roccia", b.model, cf, 5)
	for k = 0, if custom then -1 else 13 do
		local a = k / 14 * 2 * math.pi
		b.block(Vector3.new(2.6, 1.8, 2), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7, -7) * CFrame.Angles(0.1, 0, 0.15), STONE, Enum.Material.Slate)
	end
	if not custom then
		local bed = b.block(Vector3.new(1.2, 12, 12), cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), STRAW, Enum.Material.Fabric)
		bed.Shape = Enum.PartType.Cylinder
	end
	for k = 0, if custom then -1 else 17 do
		local a = k / 18 * 2 * math.pi
		local twig = b.block(Vector3.new(3.2, 0.3, 0.3), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.4, -5) * CFrame.Angles(0, 0.6, 0.35), STRAW:Lerp(WOOD_DARK, 0.3), Enum.Material.Wood)
		twig.CanCollide = false
	end
	for _, x in if custom then {} else { -1.8, 1.6 } do
		local egg = b.block(Vector3.new(2, 2.6, 2), cf * CFrame.new(x, 2.3, x * 0.4), Color3.fromRGB(230, 222, 200), Enum.Material.SmoothPlastic)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = egg
	end
	-- bracieri che tengono caldo il nido
	for _, a in { 0.8, 0.8 + math.pi } do
		local brazier = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -10)
		b.block(Vector3.new(0.6, 4, 0.6), brazier * CFrame.new(0, 2, 0), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
		local bowl = b.block(Vector3.new(1.2, 2.4, 2.4), brazier * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
		bowl.Shape = Enum.PartType.Cylinder
		local coal = b.block(Vector3.new(1.6, 0.4, 1.6), brazier * CFrame.new(0, 4.9, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
		coal.CanCollide = false
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = coal
		warmLight(coal, 22, 2)
		CollectionService:AddTag(coal, "HeatSource")
	end
	local core = b.block(Vector3.new(4, 1, 4), cf * CFrame.new(0, 1.8, 0), STRAW, Enum.Material.Fabric)
	core.Name = "NestCore"
	core.Transparency = 1
	core.CanCollide = false
	CollectionService:AddTag(core, "Incubator")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use nest"
	prompt.ObjectText = "Hatching nest"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
end

-- Cartello di viaggio: palo con frecce; il server aggiunge i prompt (tag "TravelPost")
local function travelPost(parent: Instance, cf: CFrame, label: string, target: Vector3, lastCamp: boolean)
	local b = builder(parent, "TravelPost")
	local pole = b.block(Vector3.new(0.8, 9, 0.8), cf * CFrame.new(0, 4.5, 0), WOOD_DARK, Enum.Material.Wood)
	for k, y in { 7.6, 6 } do
		local sign = b.block(Vector3.new(5, 1.1, 0.3), cf * CFrame.new(if k == 1 then 1.8 else -1.8, y, 0), LIGHT_WOOD, Enum.Material.WoodPlanks)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.PixelsPerStud = 40
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(50, 34, 20)
		text.Text = if k == 1 then label else (if lastCamp then "Base camps" else "Camp")
		text.Parent = gui
	end
	local lamp = b.block(Vector3.new(0.7, 0.9, 0.7), cf * CFrame.new(0, 9.4, 0), WARM, Enum.Material.Neon)
	lamp.CanCollide = false
	warmLight(lamp, 16, 1.6)
	pole:SetAttribute("Target", target)
	pole:SetAttribute("Label", label)
	pole:SetAttribute("LastCamp", lastCamp)
	CollectionService:AddTag(pole, "TravelPost")
end

local function lantern(parent: Instance, x: number, z: number)
	local b = builder(parent, "Lantern")
	local cf = groundCFrame(x, z, Vector3.xAxis)
	b.block(Vector3.new(1.8, 1, 1.8), cf * CFrame.new(0, 0.3, 0), STONE, Enum.Material.Slate)
	b.block(Vector3.new(0.8, 4.6, 0.8), cf * CFrame.new(0, 3.1, 0), STONE, Enum.Material.Slate)
	b.block(Vector3.new(1.9, 0.4, 1.9), cf * CFrame.new(0, 5.5, 0), STONE, Enum.Material.Slate)
	for _, a in { 0, math.pi / 2 } do
		for _, s in { -1, 1 } do
			b.block(Vector3.new(0.3, 1.6, 0.3), cf * CFrame.Angles(0, a, 0) * CFrame.new(s * 0.75, 6.5, 0.75), STONE, Enum.Material.Slate)
		end
	end
	local glow = b.block(Vector3.new(1.1, 1.3, 1.1), cf * CFrame.new(0, 6.5, 0), WARM, Enum.Material.Neon)
	glow.CanCollide = false
	warmLight(glow, 24, 2)
	b.wedge(Vector3.new(2.8, 1, 1.4), cf * CFrame.new(0, 7.8, -0.7) * CFrame.Angles(0, math.pi, 0), ROOF, Enum.Material.Slate)
	b.wedge(Vector3.new(2.8, 1, 1.4), cf * CFrame.new(0, 7.8, 0.7), ROOF, Enum.Material.Slate)
end

-- Lampione di ferro lungo la strada (braccio verso la carreggiata)
local function streetLamp(parent: Instance, pos: Vector3, toRoad: Vector3)
	local b = builder(parent, "StreetLamp")
	local cf = CFrame.lookAt(pos, pos + toRoad)
	local IRON = Color3.fromRGB(34, 34, 36)
	b.block(Vector3.new(1.4, 1.2, 1.4), cf * CFrame.new(0, 0.2, 0), STONE, Enum.Material.Slate)
	local pole = b.block(Vector3.new(11, 0.5, 0.5), cf * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal)
	pole.Shape = Enum.PartType.Cylinder
	b.block(Vector3.new(0.3, 0.3, 2.6), cf * CFrame.new(0, 11.2, -1.2), IRON, Enum.Material.Metal)
	b.block(Vector3.new(1.3, 0.3, 1.3), cf * CFrame.new(0, 11.3, -2.4), IRON, Enum.Material.Metal)
	local glow = b.block(Vector3.new(0.9, 1, 0.9), cf * CFrame.new(0, 10.6, -2.4), WARM, Enum.Material.Neon)
	glow.CanCollide = false
	warmLight(glow, 30, 2.2)
end

-- Ponte di pietra piatto dove la strada passa sopra un fiume
local function roadBridge(parent: Instance, a: Vector3, c: Vector3)
	local b = builder(parent, "StoneBridge")
	local y = max(a.Y, c.Y)
	local p0, p1 = Vector3.new(a.X, y, a.Z), Vector3.new(c.X, y, c.Z)
	local len = (p1 - p0).Magnitude + 6
	local cf = CFrame.lookAt((p0 + p1) / 2, p1)
	b.block(Vector3.new(13, 1.6, len), cf * CFrame.new(0, -0.8, 0), STONE, Enum.Material.Cobblestone)
	b.block(Vector3.new(13.4, 3, len * 0.5), cf * CFrame.new(0, -3, 0), STONE:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Slate)
	for _, side in { -1, 1 } do
		b.block(Vector3.new(1, 2.4, len), cf * CFrame.new(side * 6.5, 1.2, 0), STONE, Enum.Material.Slate)
	end
end

-- Ponte ad arco giapponese: legno del piano, parapetti laccati rossi, pomoli neri
local function bridge(parent: Instance, center: Vector3, across: Vector3, span: number)
	local a = center - across * (span / 2)
	local c = center + across * (span / 2)
	local ya, yc = groundY(a.X, a.Z), groundY(c.X, c.Z)
	local baseY = max(ya, yc, center.Y + 3)
	local cf = CFrame.lookAt(Vector3.new(center.X, baseY, center.Z), Vector3.new(center.X, baseY, center.Z) + across)
	if fromTemplate("Bridge", parent, cf) then
		return
	end
	local b = builder(parent, "JapaneseBridge")
	local N = 12
	local rise = span * 0.14
	local function point(t: number, side: number): Vector3
		-- t da 0 a 1 lungo il ponte; arco a parabola; estremi raccordati al terreno reale
		local along = (t - 0.5) * span
		local ends = if t < 0.5 then ya else yc
		local arch = baseY + rise * (1 - (2 * t - 1) ^ 2)
		local y = arch + (ends - baseY) * (abs(2 * t - 1) ^ 4)
		return (cf * CFrame.new(side * 4, 0, -along)).Position + Vector3.new(0, y - baseY, 0)
	end
	for k = 0, N - 1 do
		local p0, p1 = point(k / N, 0), point((k + 1) / N, 0)
		local len = (p1 - p0).Magnitude
		b.block(Vector3.new(8, 0.8, len + 0.3), CFrame.lookAt((p0 + p1) / 2, p1), Color3.fromRGB(142, 104, 70), Enum.Material.WoodPlanks)
		for _, side in { -1, 1 } do
			local r0, r1 = point(k / N, side), point((k + 1) / N, side)
			b.block(Vector3.new(0.5, 0.5, len + 0.3), CFrame.lookAt((r0 + r1) / 2, r1) * CFrame.new(0, 3.2, 0), LACQUER, Enum.Material.SmoothPlastic)
			b.block(Vector3.new(0.4, 0.4, len + 0.3), CFrame.lookAt((r0 + r1) / 2, r1) * CFrame.new(0, 1.6, 0), LACQUER, Enum.Material.SmoothPlastic)
			if k % 2 == 0 then
				b.block(Vector3.new(0.7, 3.8, 0.7), CFrame.new(r0 + Vector3.new(0, 1.9, 0)), LACQUER, Enum.Material.SmoothPlastic)
			end
		end
	end
	for _, t in { 0, 1 } do
		for _, side in { -1, 1 } do
			local p = point(t, side)
			b.block(Vector3.new(1, 4.6, 1), CFrame.new(p + Vector3.new(0, 2.3, 0)), LACQUER, Enum.Material.SmoothPlastic)
			local cap = b.block(Vector3.one * 1.4, CFrame.new(p + Vector3.new(0, 5, 0)), Color3.fromRGB(30, 28, 26), Enum.Material.Metal)
			cap.Shape = Enum.PartType.Ball
		end
	end
end

------------------------------------------------------------------------------------------

-- Terreno vuoto: recinto di paletti, cartello con il proprietario e il prompt di acquisto
-- (il server aggiorna testo e prompt). Il pivot del terreno e' il punto dove va la casa.
local plotCount = 0
local function plot(parent: Instance, cf: CFrame, S: number, level: number, zone: string)
	plotCount += 1
	local b = builder(parent, "Plot" .. plotCount)
	b.model:SetAttribute("Level", level) -- 1 tenda, 2 baita, 3 chalet: la casa di quel livello sta qui
	b.model:SetAttribute("Zone", zone)
	-- niente recinto (paletti e corde): resta solo il cartello col nome
	local post = b.block(Vector3.new(0.6, 5, 0.6), cf * CFrame.new(S - 3, 2.5, -S - 1), WOOD_DARK, Enum.Material.Wood)
	local board = b.block(Vector3.new(6, 3, 0.3), cf * CFrame.new(S - 3, 5, -S - 1.2), LIGHT_WOOD, Enum.Material.WoodPlanks)
	board.Name = "PlotSign"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Name = "Owner"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(50, 34, 20)
	text.Text = "Free plot"
	text.Parent = gui
	post.Name = "PlotPost"
	local anchor = b.block(Vector3.new(1, 1, 1), cf, WOOD, Enum.Material.Wood)
	anchor.Name = "HouseAnchor"
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	CollectionService:AddTag(b.model, "Plot")
	b.model.WorldPivot = cf
end

-- Modelli delle case comprabili (costruiti una volta in ServerStorage.PlotBuildings, con
-- pivot a terra e ingresso verso -Z): 1 Tenda, 2 Baita, 3 Chalet, ognuno col suo nido
buildTemplates = function()
	local ServerStorageService = game:GetService("ServerStorage")
	-- si rifanno solo le tre case: il resto della cartella (modelli messi a mano) non si tocca
	-- (prima la cartella si cancellava tutta e sono spariti i modelli dell'arena)
	local folder = ServerStorageService:FindFirstChild("PlotBuildings")
	if folder then
		for _, n in { "Tenda", "Baita", "Chalet" } do
			local old = folder:FindFirstChild(n)
			if old then
				old:Destroy()
			end
		end
		folder.Parent = nil
	else
		folder = Instance.new("Folder")
		folder.Name = "PlotBuildings"
	end
	local levels = {
		{
			name = "Tenda",
			build = function(p: Instance, cf: CFrame)
				tent(p, cf * CFrame.new(-2, 0, -2), TENT_COLORS[1])
				campfire(p, cf * CFrame.new(6, 0, -11), false)
			end,
		},
		{ name = "Baita", build = cabin },
		{ name = "Chalet", build = chalet },
	}
	for k, level in levels do
		local model = Instance.new("Model")
		model.Name = level.name
		model:SetAttribute("Level", k)
		model.Parent = folder
		local origin = CFrame.new(0, 0, 0)
		level.build(model, origin)
		model.WorldPivot = origin
		model:ScaleTo((currentMap :: Heightmap.Map).cfg.VILLAGE.HOUSE_SCALE) -- case piu' grandi
		-- nido nell'angolo dietro, dentro il recinto del terreno
		local half = (currentMap :: Heightmap.Map).cfg.VILLAGE.PLOT_HALF[k]
		-- il modello viene poi ingrandito di HOUSE_SCALE: si divide, se no il nido finiva fuori dal
		-- terreno (nelle rocce dietro lo Chalet)
		local S = (currentMap :: Heightmap.Map).cfg.VILLAGE.HOUSE_SCALE
		nest(model, origin * CFrame.new(-(half - 10) / S, 0, (half - 10) / S))
		-- niente banco da lavoro in casa: si crafta al campo base, e con lo Chalet alla forgia
		-- (la costruisce Economy accanto al punto d'arrivo)
		local _ = workbench
		-- le parti dei builder sono dentro sotto-modelli: tutto e' gia' ancorato
	end
	folder.Parent = ServerStorageService
end

function Village.build(map: Heightmap.Map)
	local cfg = map.cfg
	currentMap = map

	local old = workspace:FindFirstChild("Village")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Village"
	folder.Parent = workspace
	local rng = Random.new(cfg.SEED + 21)

	local HUB, V = cfg.HUB, cfg.VILLAGE
	local cx, cz = HUB.X + HUB.CAMP.DX, HUB.Z + HUB.CAMP.DZ
	local campCenter = Vector3.new(cx, groundY(cx, cz), cz)

	-- Falo' comune al centro del campo (le case invece si comprano: vedi i terreni piu' sotto)
	campfire(folder, CFrame.new(campCenter), true)

	-- Emporio a nord del cerchio, rivolto verso il falo'
	do
		local a = math.rad(100)
		local x, z = cx + cos(a) * (HUB.CAMP.RADIUS + 30), cz + sin(a) * (HUB.CAMP.RADIUS + 30)
		shop(folder, groundCFrame(x, z, Vector3.new(cx - x, 0, cz - z).Unit))
		-- banco da lavoro accanto all'emporio
		local wa = math.rad(125)
		local wx, wz = cx + cos(wa) * (HUB.CAMP.RADIUS + 22), cz + sin(wa) * (HUB.CAMP.RADIUS + 22)
		workbench(folder, groundCFrame(wx, wz, Vector3.new(cx - wx, 0, cz - wz).Unit))
	end

	-- Cartelli di viaggio: dal campo ai piedi della montagna (inizio del sentiero) e ritorno
	local trail = map.features.pathStart
	if trail then
		local ta = math.rad(-20)
		local tx, tz = cx + cos(ta) * (HUB.CAMP.RADIUS + 14), cz + sin(ta) * (HUB.CAMP.RADIUS + 14)
		local foot = Vector3.new(trail.x, trail.y, trail.z)
		travelPost(folder, groundCFrame(tx, tz, Vector3.new(cx - tx, 0, cz - tz).Unit), "Mountain", foot, true)
		local M = cfg.MOUNTAIN
		local out = Vector3.new(trail.x - M.X, 0, trail.z - M.Z).Unit
		local px, pz = trail.x + out.X * 14, trail.z + out.Z * 14
		travelPost(folder, groundCFrame(px, pz, -out), "Back to camp", Vector3.new(cx - 16, campCenter.Y, cz), false)
	end

	-- Terreni dei giocatori in tre zone, una per livello di casa (la casa trasloca quando la
	-- migliori, lo fa il server in Economy):
	--   1 Tenda  campo tende ai piedi della montagna, attorno a dove parte il sentiero
	--   2 Baita  villaggio attorno alle costole del drago
	--   3 Chalet villette a sbalzo sui costoni della montagna, con la vista sulla valle
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = folder
	local HALF = V.PLOT_HALF
	local placedPlots: { { p: Vector3, r: number } } = {}
	local Zone = Heightmap.Zone
	local BAD = {
		[Zone.ROAD] = true, [Zone.PATH] = true, [Zone.RIVERBED] = true, [Zone.RIVERBANK] = true,
		[Zone.LAKE] = true, [Zone.BEACH] = true, [Zone.GLACIER] = true, [Zone.TOXIC] = true,
		[Zone.GORGE] = true, [Zone.GORGE_WALL] = true, [Zone.POOL] = true, [Zone.RAPIDS] = true,
		[Zone.ICECAP] = true, [Zone.MORAINE] = true, [Zone.SUMMIT] = true,
	}
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	local function zoneAt(x: number, z: number): number
		local ix = math.clamp(math.floor((x - map.minX) / cfg.VOXEL), 0, map.nx - 1)
		local iz = math.clamp(math.floor((z - map.minZ) / cfg.VOXEL), 0, map.nz - 1)
		return buffer.readu8(map.zone, ix + iz * map.nx)
	end
	-- suolo vero (dopo grotte e strapiombi), nil sull'acqua
	local function realGround(x: number, z: number): RaycastResult?
		local hit = workspace:Raycast(Vector3.new(x, 6000, z), Vector3.new(0, -6400, 0), terrainOnly)
		if hit and hit.Material == Enum.Material.Water then
			return nil
		end
		return hit
	end
	local function crowdedPlot(p: Vector3, r: number): boolean
		for _, o in placedPlots do
			if (Vector2.new(o.p.X, o.p.Z) - Vector2.new(p.X, p.Z)).Magnitude < o.r + r + 10 then
				return true
			end
		end
		return false
	end
	-- terreno quasi piano e libero? restituisce la quota della piazzola
	local function flatSpot(x: number, z: number, half: number, maxDiff: number): number?
		local lo, hi = math.huge, -math.huge
		for _, u in { -1, 0, 1 } do
			for _, v in { -1, 0, 1 } do
				local px, pz = x + u * half, z + v * half
				if BAD[zoneAt(px, pz)] then
					return nil
				end
				local hit = realGround(px, pz)
				if not hit then
					return nil
				end
				lo, hi = math.min(lo, hit.Position.Y), math.max(hi, hit.Position.Y)
			end
		end
		if hi - lo > maxDiff then
			return nil
		end
		return (lo + hi) / 2
	end
	-- piazzola: terra in piano (tonda, cosi' sfuma nel prato), niente terreno sopra
	local function pad(cf: CFrame, half: number, surface: Enum.Material)
		local T = workspace.Terrain
		local r = half * 1.3 + 4
		T:FillCylinder(cf * CFrame.new(0, -14, 0), 22, r, Enum.Material.Rock)
		T:FillCylinder(cf * CFrame.new(0, -3, 0), 6, r, surface)
		T:FillCylinder(cf * CFrame.new(0, 20, 0), 40, r, Enum.Material.Air)
	end
	local function addPlot(level: number, zone: string, cf: CFrame)
		plot(plots, cf, HALF[level], level, zone)
		table.insert(placedPlots, { p = cf.Position, r = HALF[level] * 1.42 })
	end
	local function ring(level: number, zone: string, count: number, center: Vector3, r0: number, r1: number, face: (Vector3) -> Vector3, maxDiff: number, accept: ((Vector3) -> boolean)?): number
		local half = HALF[level]
		local placed, tries = 0, 0
		while placed < count and tries < 1500 do
			tries += 1
			local a = rng:NextNumber(0, 2 * math.pi)
			local r = rng:NextNumber(r0, r1)
			local x, z = center.X + cos(a) * r, center.Z + sin(a) * r
			if not crowdedPlot(Vector3.new(x, 0, z), half * 1.42) then
				local y = flatSpot(x, z, half, maxDiff)
				if y and (not accept or accept(Vector3.new(x, y, z))) then
					local at = Vector3.new(x, y, z)
					local cf = CFrame.lookAt(at, at + face(at))
					local hit = realGround(x, z)
					pad(cf, half, if hit and hit.Material ~= Enum.Material.Rock then hit.Material else Enum.Material.Ground)
					addPlot(level, zone, cf)
					placed += 1
				end
			end
		end
		return placed
	end

	-- 1) campo base ai piedi della montagna, come quello del K2: davanti al fronte del ghiacciaio
	-- con la grotta di ghiaccio (se manca, vicino all'inizio del sentiero), con un falo' comune
	local nTents = 0
	local campC: Vector3? = nil
	local gc = map.features.glacierCave
	local avoid: Vector3? = nil
	if gc then
		local e = gc.entrance
		local inner = gc.points[math.min(12, #gc.points)]
		local down = Vector3.new(e.x - inner.X, 0, e.z - inner.Z).Unit
		avoid = Vector3.new(e.x, e.y, e.z)
		campC = Vector3.new(e.x, e.y, e.z) + down * 170
	elseif map.features.pathStart then
		local t = map.features.pathStart
		campC = Vector3.new(t.x, t.y, t.z)
	end
	if avoid then
		-- davanti all'ingresso della grotta non si mette niente
		table.insert(placedPlots, { p = avoid, r = 40 })
	end
	-- tende sparse tutto attorno ai piedi della montagna (ognuno ha il suo accampamento, ci
	-- arriva a fine tutorial), girate verso la montagna
	-- zone dove non vanno tende: arena (costole), campo base e tutorial
	local keepAway: { { p: Vector3, r: number } } = { { p = Vector3.new(cx, 0, cz), r = 450 } }
	do
		local lm = workspace:FindFirstChild("Landmarks")
		local rb = lm and lm:FindFirstChild("DragonRibs")
		if rb and rb:IsA("Model") then
			local p = rb:GetPivot().Position
			table.insert(keepAway, { p = Vector3.new(p.X, 0, p.Z), r = 450 })
		end
		local tut = workspace:FindFirstChild("Tutorial")
		if tut then
			for _, d in tut:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(keepAway, { p = Vector3.new(d.Position.X, 0, d.Position.Z), r = 300 })
					break
				end
			end
		end
	end
	do
		local M = cfg.MOUNTAIN
		local mc = Vector3.new(M.X, 0, M.Z)
		nTents = ring(1, "Tende", V.TENTS, mc, M.RADIUS * 0.85, M.RADIUS * 1.25, function(at)
			return Vector3.new(mc.X - at.X, 0, mc.Z - at.Z).Unit
		end, 10, function(p)
			if p.Y < 15 or p.Y > 220 or BAD[zoneAt(p.X, p.Z)] then
				return false
			end
			for _, far in keepAway do
				if (Vector3.new(p.X, 0, p.Z) - far.p).Magnitude < far.r then
					return false
				end
			end
			return true
		end)
	end
	local _ = campC

	-- 2) villaggio attorno alle costole del drago (al centro c'e' la zona di addestramento)
	local nCabins = 0
	local landmarks = workspace:FindFirstChild("Landmarks")
	local ribs = landmarks and landmarks:FindFirstChild("DragonRibs")
	if ribs and ribs:IsA("Model") then
		-- due file di baite lungo i fianchi della cassa toracica (e' lunga e stretta: in cerchio
		-- finivano lontanissime), con la porta verso le costole
		local rcf, rsize = ribs:GetBoundingBox()
		local half = HALF[2]
		local long = if rsize.Z >= rsize.X then rcf.LookVector else rcf.RightVector
		local across = Vector3.new(-long.Z, 0, long.X).Unit
		local L, W = math.max(rsize.X, rsize.Z), math.min(rsize.X, rsize.Z)
		local center = rcf.Position
		-- l'arena al centro resta libera (niente case, alberi, rocce)
		table.insert(placedPlots, { p = center, r = 105 })
		map.features.clearings = map.features.clearings or {}
		table.insert(map.features.clearings, { x = center.X, z = center.Z, r = 170 }) -- anche per il bosco
		local tries = 0
		while false and nCabins < V.CABINS and tries < 1500 do -- le baite ora stanno sul pendio (sotto)
			tries += 1
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local along = rng:NextNumber(-L * 0.45, L * 0.45)
			local off = W / 2 + half + rng:NextNumber(12, 90)
			local at = center + long * along + across * side * off
			if not crowdedPlot(Vector3.new(at.X, 0, at.Z), half * 1.42) then
				local y = flatSpot(at.X, at.Z, half, 14)
				if y then
					local pos = Vector3.new(at.X, y, at.Z)
					local cf = CFrame.lookAt(pos, pos - across * side)
					local hit = realGround(at.X, at.Z)
					pad(cf, half, if hit and hit.Material ~= Enum.Material.Rock then hit.Material else Enum.Material.Ground)
					addPlot(2, "Villaggio", cf)
					nCabins += 1
				end
			end
		end
		for k = -3, 3 do
			for _, side in { -1, 1 } do
				local at = center + long * (k * L / 8) + across * side * (W / 2 + 6)
				lantern(folder, at.X, at.Z)
			end
		end
	end

	-- 2b) baite sul pendio della montagna, a CABIN_Y: un ripiano scavato nel pendio (sopra tutto
	-- libero, sotto un masso di roccia) con una pedana di pietra piatta
	do
		local M = cfg.MOUNTAIN
		local half = HALF[2]
		local T = workspace.Terrain
		local tries = 0
		while nCabins < V.CABINS and tries < 6000 do
			tries += 1
			local a = rng:NextNumber(0, 2 * math.pi)
			local out = Vector3.new(cos(a), 0, sin(a))
			local r = M.RADIUS * rng:NextNumber(0.45, 1)
			local x, z = M.X + out.X * r, M.Z + out.Z * r
			local hit = realGround(x, z)
			if not hit or hit.Position.Y < V.CABIN_Y[1] or hit.Position.Y > V.CABIN_Y[2] or BAD[zoneAt(x, z)] then
				continue
			end
			local at = Vector3.new(x, hit.Position.Y + 1, z)
			if crowdedPlot(at, half * 4) then
				continue
			end
			local cf = CFrame.lookAt(at, at + out) -- la porta guarda la valle
			-- ripiano largo e ben spianato: roccia piena sotto, tutto libero sopra (anche oltre il
			-- terreno, cosi' il pendio non entra nella casa)
			T:FillBall(cf * Vector3.new(0, -half * 1.1, 0), half * 1.25, Enum.Material.Rock)
			T:FillBlock(cf * CFrame.new(0, -6, 0), Vector3.new(half * 2 + 24, 12, half * 2 + 24), Enum.Material.Rock)
			T:FillBlock(cf * CFrame.new(0, 34, 0), Vector3.new(half * 2 + 30, 68, half * 2 + 30), Enum.Material.Air)
			local ledge = builder(folder, "Ripiano")
			ledge.block(Vector3.new(half * 2 + 20, 2, half * 2 + 20), cf * CFrame.new(0, -1, 0), STONE, Enum.Material.Slate)
			addPlot(2, "Pendio", cf)
			nCabins += 1
		end
	end

	-- 3) villette sui costoni: una piazzola sul bordo di un salto, con la casa che sporge sul
	-- vuoto sorretta da pilastri bianchi (come le ville sulle scogliere)
	local nVillas = 0
	do
		local M = cfg.MOUNTAIN
		local half = HALF[3]
		local tries = 0
		while nVillas < V.VILLAS and tries < 4000 do
			tries += 1
			local a = rng:NextNumber(0, 2 * math.pi)
			local r = M.RADIUS * rng:NextNumber(0.6, 0.88)
			local out = Vector3.new(cos(a), 0, sin(a))
			local x, z = M.X + out.X * r, M.Z + out.Z * r
			local hit = realGround(x, z)
			if not hit or hit.Position.Y < V.VILLA_Y[1] or hit.Position.Y > V.VILLA_Y[2] or BAD[zoneAt(x, z)] then
				continue
			end
			local y = hit.Position.Y
			local front = realGround(x + out.X * (half + 24), z + out.Z * (half + 24))
			local back = realGround(x - out.X * half, z - out.Z * half)
			if not front or not back or y - front.Position.Y < 15 or back.Position.Y - y > 60 then
				continue -- serve un salto davanti e niente parete enorme dietro
			end
			local at = Vector3.new(x, y + 2, z)
			if crowdedPlot(at, 230) then
				continue
			end
			local cf = CFrame.lookAt(at, at + out) -- la facciata di vetro guarda la valle
			local T = workspace.Terrain
			-- dietro: un masso tondo di roccia sotto la meta' interna (un blocco squadrato si vedeva
			-- sotto la pedana); sopra: tutto libero
			T:FillBall(cf * Vector3.new(0, -half * 1.05, half * 0.55), half * 1.0, Enum.Material.Rock)
			-- tutto libero sopra la pedana, con margine largo (prima il nido finiva nella roccia)
			T:FillBlock(cf * CFrame.new(0, 34, 0), Vector3.new(half * 2 + 30, 68, half * 2 + 30), Enum.Material.Air)
			local villa = builder(folder, "Costone")
			villa.block(Vector3.new(half * 2 + 16, 1.6, half * 2 + 16), cf * CFrame.new(0, -0.8, 0), Color3.fromRGB(232, 232, 228), Enum.Material.Concrete)
			-- pilastri inclinati sotto la parte che sporge
			for _, u in { -0.8, -0.3, 0.3, 0.8 } do
				for _, v in { -0.85, -0.35 } do
					local top = cf * Vector3.new(u * half, -1.6, v * half)
					local down = workspace:Raycast(top, Vector3.new(0, -260, 0), terrainOnly)
					if down and top.Y - down.Position.Y > 3 then
						local bottom = down.Position + (cf.Position - top) * Vector3.new(1, 0, 1) * 0.12 - Vector3.new(0, 2, 0)
						local len = (top - bottom).Magnitude
						local pillar = villa.block(Vector3.new(2.6, len, 2.6), CFrame.lookAt((top + bottom) / 2, top) * CFrame.Angles(-math.pi / 2, 0, 0), Color3.fromRGB(236, 236, 232), Enum.Material.Concrete)
						pillar.Name = "Pilastro"
					end
				end
			end
			-- parapetto di vetro sul bordo verso il vuoto
			local rail = villa.block(Vector3.new(half * 2 + 6, 3.2, 0.3), cf * CFrame.new(0, 1.6, -(half + 3)), GLASS, Enum.Material.Glass)
			rail.Transparency = 0.55
			addPlot(3, "Costone", cf)
			nVillas += 1
		end
	end
	buildTemplates()
	-- radure per il bosco (Forest viene dopo): niente alberi dentro i terreni
	map.features.clearings = map.features.clearings or {}
	for _, o in placedPlots do
		table.insert(map.features.clearings, { x = o.p.X, z = o.p.Z, r = o.r + 12 })
	end
	print(string.format("[MapGen] Case: %d tende ai piedi della montagna, %d baite sul pendio, %d chalet sui costoni", nTents, nCabins, nVillas))

	-- Lanterne attorno al cerchio del falo' della piana
	local lanterns = Instance.new("Folder")
	lanterns.Name = "Lanterns"
	lanterns.Parent = folder
	for k = 0, 9 do
		local a = k / 10 * 2 * math.pi
		lantern(lanterns, cx + cos(a) * (HUB.CAMP.RADIUS + 8), cz + sin(a) * (HUB.CAMP.RADIUS + 8))
	end

	-- Ponti giapponesi sul fiume della valle
	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = folder
	local main = map.features.rivers[1]
	local inside = {}
	for _, p in main.course do
		local d = math.sqrt((p.x - HUB.X) ^ 2 + (p.z - HUB.Z) ^ 2)
		-- non dentro il lago grande: li' il fiume e' diventato lago (e ci sono le palafitte)
		local lake = map.features.bigLake
		local inLake = lake and (p.x - lake.x) ^ 2 + (p.z - lake.z) ^ 2 < (lake.radius * 1.5 + 30) ^ 2
		if d < HUB.WALL.RADIUS - 80 and not inLake then
			table.insert(inside, p)
		end
	end
	for k = 1, V.BRIDGES do
		local p = inside[math.clamp(math.floor(#inside * k / (V.BRIDGES + 1)), 1, #inside)]
		if p then
			local across = Vector3.new(-p.dirZ, 0, p.dirX)
			bridge(bridges, Vector3.new(p.x, p.y, p.z), across, main.halfWidth * 2 + 22)
		end
	end

	-- Strada per la montagna: lampioni alternati ai lati e ponti di pietra sui fiumi
	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = folder
	local RD = cfg.ROAD
	for k, p in map.features.road or {} do
		if not p.inHub and k % RD.LAMP_EVERY == 0 then
			local side = if (k // RD.LAMP_EVERY) % 2 == 0 then 1 else -1
			local nx, nz = -p.dirZ * side, p.dirX * side
			local x, z = p.x + nx * (RD.HALF_WIDTH + 2.5), p.z + nz * (RD.HALF_WIDTH + 2.5)
			streetLamp(road, Vector3.new(x, groundY(x, z), z), Vector3.new(-nx, 0, -nz))
		end
	end
	for _, br in map.features.roadBridges or {} do
		roadBridge(road, Vector3.new(br.a.x, br.a.y, br.a.z), Vector3.new(br.b.x, br.b.y, br.b.z))
	end

	-- Campi base sulla montagna
	local camps = Instance.new("Folder")
	camps.Name = "BaseCamps"
	camps.Parent = folder
	local M = cfg.MOUNTAIN
	for k, c in map.features.camps do
		local outward = Vector3.new(c.x - M.X, 0, c.z - M.Z).Unit
		local base = CFrame.lookAt(Vector3.new(c.x, c.y, c.z), Vector3.new(c.x, c.y, c.z) + outward)
		local camp = Instance.new("Folder")
		camp.Name = "BaseCamp" .. k
		camp.Parent = camps
		campfire(camp, base * CFrame.new(0, 0, -3), false)
		tent(camp, base * CFrame.new(-7, 0, 5) * CFrame.Angles(0, 0.4, 0), TENT_COLORS[1 + k % #TENT_COLORS])
		-- baita (grande e piccola alternate) di fianco al campo: si spiana il terreno sotto e si
		-- libera lo spazio sopra, cosi' non resta sospesa ne' incastrata nel pendio
		local models = ServerStorage:FindFirstChild("Modelli")
		local cabin = models and models:FindFirstChild(if k % 2 == 1 then "Baita_Grande" else "Baita_Piccola")
		if cabin and cabin:IsA("Model") then
			local m = cabin:Clone()
			local _, size = m:GetBoundingBox()
			local side = base.RightVector * (size.X / 2 + 14)
			local at = Vector3.new(c.x, c.y, c.z) + side
			local cf = CFrame.lookAt(at, at + outward)
			local foot = Vector3.new(size.X + 6, 1, size.Z + 6)
			workspace.Terrain:FillBlock(cf * CFrame.new(0, -12, 0), Vector3.new(foot.X, 24, foot.Z), Enum.Material.Rock)
			workspace.Terrain:FillBlock(cf * CFrame.new(0, size.Y / 2 + 4, 0), Vector3.new(foot.X, size.Y + 8, foot.Z), Enum.Material.Air)
			m:PivotTo(cf)
			m.Parent = camp
		end
	end

end

return Village
