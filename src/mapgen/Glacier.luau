--!strict
-- L'alta montagna "viva", dopo che il terreno e' stato scritto. Usa i modelli di ghiaccio in
-- ServerStorage/IceKit. Ogni tipo di pezzo va solo dove ha senso, e ogni pezzo viene tenuto
-- solo se sta davvero appoggiato (altrimenti si scarta e si riprova altrove):
--   seracchi e torri   sul ghiacciaio, nelle seraccate, su fondo quasi piano, dritti
--   fronti             al termine di ogni ghiacciaio, con la parete di ghiaccio rivolta a valle
--   volte, stalattiti  appese sotto tetti di roccia piatti (strapiombi in quota, grotte di ghiaccio)
--   tende di stalattiti appese sotto il bordo dei crepacci
--   iceberg            a galla nel lago di montagna e nel mare ai piedi dei ghiacciai
--   frammenti          davanti ai fronti e sui bordi dei crepacci
--   macerie            sulle morene, mai sul ghiaccio
--   stalagmiti, colonne su ripiani innevati piatti vicino alla vetta e nelle grotte
-- Il lato -Z dei modelli e' la loro "faccia" (la parete dei seracchi, il fronte delle colate).

local ServerStorage = game:GetService("ServerStorage")
local Heightmap = require(script.Parent.Heightmap)

local Glacier = {}

local METAL = Color3.fromRGB(176, 180, 186)
local ROPE = Color3.fromRGB(230, 170, 40)
local Zone = Heightmap.Zone

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
terrainOnly.IgnoreWater = true

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ground(x: number, z: number, fromY: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -fromY - 300, 0), terrainOnly)
end

local function zoneAt(map: Heightmap.Map, x: number, z: number): number
	local V = map.cfg.VOXEL
	local ix = math.clamp(math.floor((x - map.minX) / V), 0, map.nx - 1)
	local iz = math.clamp(math.floor((z - map.minZ) / V), 0, map.nz - 1)
	return buffer.readu8(map.zone, ix + iz * map.nx)
end

------------------------------------------------------------------------------------------
-- Scale, corde fisse, paletti
------------------------------------------------------------------------------------------

local function ladder(parent: Instance, a: Vector3, b: Vector3, up: Vector3, width: number): Model
	local model = Instance.new("Model")
	model.Name = "Scala"
	local d = (b - a).Unit
	local len = (b - a).Magnitude
	local side = d:Cross(up).Unit
	local mid = (a + b) / 2
	for _, sgn in { -1, 1 } do
		local c = mid + side * sgn * width / 2
		part(model, "Montante", Vector3.new(0.3, 0.3, len), CFrame.lookAt(c, c + d, up), METAL)
	end
	local k = 0.7
	while k < len - 0.3 do
		local c = a + d * k
		part(model, "Piolo", Vector3.new(width, 0.22, 0.3), CFrame.lookAt(c, c + d, up), METAL)
		k += 1.25
	end
	model.Parent = parent
	return model
end

local function rope(parent: Instance, a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	part(parent, "CordaFissa", Vector3.new(0.14, 0.14, len), CFrame.lookAt((a + b) / 2, b), ROPE, Enum.Material.Fabric).CanCollide = false
end

local function picket(parent: Instance, base: Vector3): Vector3
	part(parent, "Paletto", Vector3.new(0.3, 4, 0.3), CFrame.new(base + Vector3.new(0, 1.6, 0)), METAL)
	return base + Vector3.new(0, 3.4, 0)
end

------------------------------------------------------------------------------------------
-- Coordinate dei ghiacciai (stesse formule di Heightmap)
------------------------------------------------------------------------------------------

local function sample(g: any, s: number, arr: { number }): number
	local f = math.clamp(s / g.step + 1, 1, g.n)
	local k0 = math.floor(f)
	local k1 = math.min(g.n, k0 + 1)
	return arr[k0] + (arr[k1] - arr[k0]) * (f - k0)
end

local function toWorld(g: any, s: number, t: number): (number, number)
	local off = sample(g, s, g.off)
	return g.tx + g.ax * s + g.sx * (t + off), g.tz + g.az * s + g.sz * (t + off)
end

local function crevasseCentre(g: any, c: any, t: number): number
	local half = sample(g, c.s0, g.half)
	return c.s0 + c.bow * (t / half) ^ 2 + c.tilt * t + math.noise(t / 35, c.seed, 1.7) * 5
end

------------------------------------------------------------------------------------------
-- Il kit e il piazzamento controllato
------------------------------------------------------------------------------------------

local KIT = {
	seracs = { "Iceberg_Castello", "Iceberg_Doppia_Punta", "Iceberg_Pinna", "Iceberg_Rampa", "Fronte_Seracchi_Alto", "Fronte_Seracchi_Curvo" },
	fronts = { "Fronte_Seracchi_Dritto", "Fronte_Seracchi_Alto", "Fronte_Seracchi_Curvo", "Fronte_Seracchi_Crollato" },
	icebergs = { "Iceberg_Tabulare", "Iceberg_Cupola", "Iceberg_Frastagliato" },
	fragments = {
		"Frammento_Ghiaccio_01", "Frammento_Ghiaccio_02", "Frammento_Ghiaccio_03", "Frammento_Ghiaccio_04",
		"Frammento_Ghiaccio_05", "Frammento_Ghiaccio_06", "Frammento_Ghiaccio_07", "Frammento_Ghiaccio_08",
		"Frammento_Ghiaccio_09", "Frammento_Ghiaccio_10", "Frammento_Ghiaccio_11", "Frammento_Ghiaccio_12",
		"Frammento_Ghiaccio_13", "Frammento_Ghiaccio_14",
	},
	debris = { "Cumulo_Macerie" },
	hanging = { "Volta_Stalattiti_Cattedrale", "Volta_Stalattiti_Fitta", "Volta_Stalattiti_Rada", "Stalattite_Gigante" },
	curtains = { "Tenda_Stalattiti", "Tenda_Stalattiti_Lunga" },
	standing = { "Grappolo_Stalagmiti", "Grappolo_Stalagmiti_Basso", "Stalagmite_Gigante", "Colonna_Ghiaccio" },
}
-- modelli del kit da non usare (le "pareti colate" sembravano pannelli incollati alla roccia)
local SKIP = { Parete_Colate = true }
local ROCKY = { Cumulo_Macerie = true }

local templates: { [string]: Model } = {}
local used: { [string]: number } = {}
local rejected = 0
local why: { [string]: number } = {}
local placedBig: { { p: Vector3, r: number } } = {}

local function loadKit(): boolean
	table.clear(templates)
	table.clear(used)
	table.clear(placedBig)
	rejected = 0
	table.clear(why)
	local kit = ServerStorage:FindFirstChild("IceKit")
	if not kit then
		return false
	end
	for _, m in kit:GetDescendants() do
		if m:IsA("Model") and not SKIP[m.Name] and m:FindFirstChildWhichIsA("BasePart", true) then
			local clean = m:Clone()
			for _, d in clean:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy() -- mai script dentro i modelli della mappa
				end
			end
			templates[m.Name] = clean
			used[m.Name] = 0
		end
	end
	return next(templates) ~= nil
end

local function pick(list: { string }, rng: Random): string?
	-- tra quelli della lista, preferisce il meno usato: cosi' ogni modello compare
	local best, bestUse = nil, math.huge
	for _ = 1, 3 do
		local name = list[rng:NextInteger(1, #list)]
		if templates[name] and used[name] < bestUse then
			best, bestUse = name, used[name]
		end
	end
	return best
end

-- Clona, scala, orienta (`rot`) e sposta in modo che il punto `anchor` del riquadro (in [-1,1]
-- per asse, nel sistema del modello) cada su `at`. Non lo mette ancora nel mondo.
local function make(name: string?, rot: CFrame, scale: number, at: Vector3, anchor: Vector3): (Model?, CFrame, Vector3)
	local t = name and templates[name]
	if not t then
		return nil, CFrame.identity, Vector3.zero
	end
	local m = t:Clone()
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(rot.Rotation + at)
	local box, size = m:GetBoundingBox()
	local target = box * CFrame.new(size * anchor / 2)
	m:PivotTo(m:GetPivot() + (at - target.Position))
	box, size = m:GetBoundingBox()
	return m, box, size
end

local function commit(parent: Instance, name: string, m: Model, size: Vector3)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.Material = if ROCKY[name] then Enum.Material.Slate else Enum.Material.Glacier
			d.CastShadow = size.Magnitude > 12
			d.CanCollide = size.Magnitude > 9 -- i frammenti piccoli non devono far inciampare
		end
	end
	m.Parent = parent
	used[name] += 1
end

local function reject(m: Model?, reason: string?): nil
	if m then
		m:Destroy()
	end
	rejected += 1
	local key = reason or "altro"
	why[key] = (why[key] or 0) + 1
	return nil
end

-- niente pezzi grandi uno dentro l'altro
local function crowded(p: Vector3, r: number): boolean
	for _, o in placedBig do
		if (o.p - p).Magnitude < (o.r + r) * 0.75 then
			return true
		end
	end
	return false
end

-- APPOGGIATO A TERRA, dritto. Si misurano 9 punti sotto la base:
--   * se il terreno a valle scende di piu' di `maxGap` (frazione dell'altezza) il pezzo si scarta;
--   * altrimenti, se c'e' `support`, sotto il pezzo si costruisce il gradino che lo regge (ghiaccio
--     sul ghiacciaio, neve, roccia): niente piu' pezzi a mensola sul vuoto;
--   * il lato a monte puo' affondare nel pendio fino a `maxBury` dell'altezza, non oltre.
--   * con `step` il pendio a monte viene tagliato in un gradino piano (come in una seraccata vera):
--     il pezzo poggia su un ripiano invece di affondare nel pendio
type Opts = { support: Enum.Material?, maxGap: number?, maxBury: number?, back: boolean?, step: boolean? }
local function standOn(parent: Instance, name: string?, at: Vector3, face: Vector3, scale: number, sink: number, opts: Opts?): Model?
	if not name then
		return nil
	end
	local o: Opts = opts or {}
	local look = Vector3.new(face.X, 0, face.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.xAxis
	local m, box, size = make(name, CFrame.lookAt(Vector3.zero, look), scale, at, Vector3.new(0, -1 + 2 * sink, 0))
	if not m then
		return nil
	end
	local r = math.max(size.X, size.Z) / 2
	if size.Magnitude > 20 and crowded(box.Position, r) then
		return reject(m, "affollato")
	end
	local bottom = box.Position.Y - size.Y / 2
	local lowest, highest = math.huge, -math.huge
	local heights: { { u: number, v: number, h: number } } = {}
	for _, u in { -0.42, 0, 0.42 } do
		for _, v in (if o.back then { 0.1, 0.42 } else { -0.42, 0, 0.42 }) :: { number } do
			local q = box * Vector3.new(u * size.X, 0, v * size.Z)
			local hit = workspace:Raycast(Vector3.new(q.X, bottom + size.Y + 120, q.Z), Vector3.new(0, -size.Y * 3 - 200, 0), terrainOnly)
			if not hit then
				return reject(m, "niente terreno")
			end
			lowest = math.min(lowest, hit.Position.Y)
			highest = math.max(highest, hit.Position.Y)
			table.insert(heights, { u = u, v = v, h = hit.Position.Y })
		end
	end
	-- Il pezzo scende fino al punto piu' basso del terreno sotto di lui (affondato di poco):
	-- cosi' nessun lato resta per aria. Il lato a monte resta sepolto nel pendio, e se e' troppo
	-- si taglia il gradino.
	-- a cavallo di un crepaccio o di un buco: no (il punto piu' basso finirebbe in fondo al buco)
	-- piano del pendio sotto il pezzo (minimi quadrati sulla griglia 3x3): un punto molto sotto
	-- il piano e' un crepaccio o un buco, e a cavallo di un buco il pezzo non si mette
	local a, b, c, su, sv = 0, 0, 0, 0, 0
	for _, q in heights do
		a += q.h
		b += q.u * q.h
		c += q.v * q.h
		su += q.u * q.u
		sv += q.v * q.v
	end
	a /= #heights
	b = if su > 0 then b / su else 0
	c = if sv > 0 then c / sv else 0
	local planeLow = math.huge
	for _, q in heights do
		local plane = a + b * q.u + c * q.v
		if q.h < plane - math.max(3, size.Y * 0.25) then
			return reject(m, "sopra un buco")
		end
		planeLow = math.min(planeLow, plane, q.h)
	end
	lowest = planeLow
	local newBottom = lowest - math.min(sink * size.Y, 3)
	m:PivotTo(m:GetPivot() + Vector3.new(0, newBottom - bottom, 0))
	box = box + Vector3.new(0, newBottom - bottom, 0)
	bottom = newBottom
	local bury = highest - bottom
	if bury > size.Y * (o.maxBury or 0.5) then
		if not o.step or bury > size.Y * 1.6 then
			return reject(m, "sepolto")
		end
		-- gradino: si toglie il pendio a monte sopra la base (un po' piu' largo del pezzo)
		-- ripiano di traverso al pendio (largo, aperto ai lati) e scavato solo a monte: una buca
		-- squadrata attorno al pezzo sembrava una nicchia fatta a mano
		local cut = highest + 4 - (bottom + 1)
		local back = box.Rotation:VectorToWorldSpace(Vector3.new(0, 0, size.Z * 0.25))
		workspace.Terrain:FillBlock(
			box.Rotation + Vector3.new(box.Position.X + back.X, bottom + 1 + cut / 2, box.Position.Z + back.Z),
			Vector3.new(size.X * 2.5, cut, size.Z * 0.75 + 6),
			Enum.Material.Air
		)
		-- e il ripiano su cui poggia, dello stesso materiale del posto
		if o.support then
			workspace.Terrain:FillBlock(
				box.Rotation + Vector3.new(box.Position.X, bottom - 2, box.Position.Z),
				Vector3.new(size.X + 6, 6, size.Z + 6),
				o.support
			)
		end
	end
	commit(parent, name, m, size)
	if size.Magnitude > 20 then
		table.insert(placedBig, { p = box.Position, r = r })
	end
	return m
end

-- APPOGGIATO A UNA PARETE piana (normale orizzontale `n`): il retro tocca la roccia in tutti e
-- sei i punti controllati, altrimenti sembra un pannello incollato
local function onWall(parent: Instance, name: string?, wallPoint: Vector3, n: Vector3, scale: number): Model?
	if not name then
		return nil
	end
	local m, box, size = make(name, CFrame.lookAt(Vector3.zero, n), scale, wallPoint - n * 1.2, Vector3.new(0, 0, 1))
	if not m then
		return nil
	end
	for _, u in { -0.42, 0.42 } do
		for _, v in { -0.42, 0, 0.42 } do
			local p = box * Vector3.new(u * size.X, v * size.Y, -size.Z / 2)
			local hit = workspace:Raycast(p + n * 2, -n * (size.Z + 8), terrainOnly)
			local gap = hit and (hit.Position - p):Dot(-n) - size.Z
			if not hit or (gap :: number) > 2 or (gap :: number) < -size.Z * 0.9 then
				return reject(m)
			end
		end
	end
	commit(parent, name, m, size)
	return m
end

-- APPESO SOTTO UN TETTO piatto: la cima tocca la roccia in tutti e cinque i punti controllati
local function hangUnder(parent: Instance, name: string?, roofPoint: Vector3, yaw: number, scale: number): Model?
	if not name then
		return nil
	end
	local m, box, size = make(name, CFrame.Angles(0, yaw, 0), scale, roofPoint + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0))
	if not m then
		return nil
	end
	local top = box.Position.Y + size.Y / 2
	local touching = 0
	for k, uv in { { 0, 0 }, { -0.4, -0.4 }, { 0.4, -0.4 }, { -0.4, 0.4 }, { 0.4, 0.4 } } do
		local p = box * Vector3.new(uv[1] * size.X, 0, uv[2] * size.Z)
		local hit = workspace:Raycast(Vector3.new(p.X, top - size.Y * 0.4, p.Z), Vector3.new(0, size.Y * 0.4 + 4, 0), terrainOnly)
		if hit and hit.Normal.Y < -0.4 then
			touching += 1
		elseif k == 1 then
			return reject(m) -- il centro deve sempre toccare
		end
	end
	if touching < 3 then
		return reject(m)
	end
	commit(parent, name, m, size)
	return m
end

-- A GALLA: la base sott'acqua per un terzo dell'altezza, e il fondale deve essere abbastanza
-- profondo da non farlo "appoggiare" su una secca
local function floatAt(parent: Instance, name: string?, at: Vector3, waterY: number, scale: number, yaw: number): Model?
	if not name then
		return nil
	end
	local m, box, size = make(name, CFrame.Angles(0, yaw, 0), scale, Vector3.new(at.X, waterY, at.Z), Vector3.new(0, -1 + 2 * 0.33, 0))
	if not m then
		return nil
	end
	local bottom = box.Position.Y - size.Y / 2
	for _, uv in { { 0, 0 }, { -0.45, -0.45 }, { 0.45, -0.45 }, { -0.45, 0.45 }, { 0.45, 0.45 } } do
		local p = box * Vector3.new(uv[1] * size.X, 0, uv[2] * size.Z)
		local hit = workspace:Raycast(Vector3.new(p.X, waterY + 2, p.Z), Vector3.new(0, -200, 0), terrainOnly)
		if hit and hit.Position.Y > bottom - 1 then
			return reject(m)
		end
	end
	if crowded(box.Position, math.max(size.X, size.Z) / 2) then
		return reject(m)
	end
	commit(parent, name, m, size)
	table.insert(placedBig, { p = box.Position, r = math.max(size.X, size.Z) / 2 })
	return m
end

------------------------------------------------------------------------------------------
-- Dove va ogni cosa
------------------------------------------------------------------------------------------

-- Seraccate: blocchi e torri solo dove il ghiacciaio e' ripido, solo sul ghiaccio, su fondo
-- quasi piano. Il pezzo guarda a valle (la sua parete verso il basso, come un seracco vero).
local function icefalls(folder: Instance, map: Heightmap.Map, g: any, rng: Random): number
	local count = 0
	local axis = Vector3.new(g.ax, 0, g.az)
	for k = 1, g.n do
		-- solo dove il pendio permette di appoggiare un blocco (sotto ~50 gradi)
		local slope = (g.surf[math.max(1, k - 2)] - g.surf[math.min(g.n, k + 2)]) / (4 * g.step)
		-- seraccate dove il pendio regge, e campi di seracchi sparsi sulla lingua (le creste di
		-- pressione dove il ghiaccio rallenta): mai su tratti piu' ripidi di ~40 gradi
		if slope < 0.85 and (g.icefall[k] or (k % 3 == 0 and rng:NextNumber() < 0.35)) then
			local s = (k - 1) * g.step
			local half = g.half[k]
			for _ = 1, 8 do
				local t = rng:NextNumber(-half * 0.75, half * 0.75)
				local x, z = toWorld(g, s, t)
				if zoneAt(map, x, z) == Zone.GLACIER then
					local hit = ground(x, z, g.surf[k] + 300)
					if hit and hit.Normal.Y > 0.45 then
						local face = (axis + Vector3.new(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))).Unit
						if standOn(folder, pick(KIT.seracs, rng), hit.Position, face, rng:NextNumber(0.8, 1.6), 0.2, { maxBury = 0.5 }) then
							count += 1
							break
						end
					end
				end
			end
		end
	end
	return count
end

-- vicino all'ingresso della grotta di ghiaccio azzurro (li' il fronte resta libero)
local function nearCave(map: Heightmap.Map, x: number, z: number, r: number): boolean
	local gc = map.features.glacierCave
	return gc ~= nil and (Vector2.new(x, z) - Vector2.new(gc.entrance.x, gc.entrance.z)).Magnitude < r
end

-- Fronte: una fila di pareti di seracchi dove finisce la lingua, rivolte a valle (gli angoli
-- della lingua sono arrotondati: la fila resta nel tratto dritto)
local function front(folder: Instance, map: Heightmap.Map, g: any, rng: Random): number
	local count = 0
	local axis = Vector3.new(g.ax, 0, g.az)
	local sEnd = g.length - 14
	local half = sample(g, sEnd, g.half)
	local t = -half * 0.6
	while t < half * 0.6 do
		local x, z = toWorld(g, sEnd, t)
		if nearCave(map, x, z, 48) then
			t += 12
			continue
		end
		local hit = ground(x, z, sample(g, sEnd, g.surf) + 300)
		local m = hit and standOn(folder, pick(KIT.fronts, rng), hit.Position, axis, rng:NextNumber(1.2, 1.7), 0.2, { maxBury = 0.5 })
		if m then
			count += 1
			t += select(2, m:GetBoundingBox()).X * 0.85
		else
			t += 12
		end
	end
	-- frammenti caduti davanti al fronte
	for _ = 1, 16 do
		local x, z = toWorld(g, g.length + rng:NextNumber(8, 50), rng:NextNumber(-half, half))
		local hit = not nearCave(map, x, z, 40) and ground(x, z, sample(g, sEnd, g.surf) + 300)
		if hit and hit.Normal.Y > 0.5 then
			if standOn(folder, pick(KIT.fragments, rng), hit.Position, Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)), rng:NextNumber(0.8, 1.8), 0.2, { support = Enum.Material.Snow, maxGap = 0.6, maxBury = 0.85 }) then
				count += 1
			end
		end
	end
	return count
end

-- Crepacci: tende di stalattiti appese sotto il bordo, frammenti sui
-- bordi e stalagmiti basse sul fondo dei piu' larghi
local function crevasseIce(folder: Instance, map: Heightmap.Map, g: any, rng: Random): number
	local count = 0
	for _, c in g.crevasses or {} do
		local tt = rng:NextNumber(c.t0 + (c.t1 - c.t0) * 0.2, c.t1 - (c.t1 - c.t0) * 0.2)
		local sc = crevasseCentre(g, c, tt)
		local cx, cz = toWorld(g, sc, tt)
		local bottom = ground(cx, cz, 9000)
		if c.width >= 7 and bottom then
			-- una parete del crepaccio: raggio orizzontale dal centro verso un lato, a meta' altezza
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local sx, sz = toWorld(g, sc + side * 30, tt)
			local dir = Vector3.new(sx - cx, 0, sz - cz).Unit
			local lipX, lipZ = toWorld(g, sc + side * (c.width / 2 + 3), tt)
			local lip = ground(lipX, lipZ, 9000)
			if lip then
				local mid = Vector3.new(cx, (bottom.Position.Y + lip.Position.Y) / 2, cz)
				local wall = workspace:Raycast(mid, dir * (c.width + 6), terrainOnly)
				if wall and math.abs(wall.Normal.Y) < 0.35 and rng:NextNumber() < 0.6 then
					-- tenda di stalattiti appesa poco sotto il bordo
					local high = workspace:Raycast(Vector3.new(cx, lip.Position.Y - 5, cz), dir * (c.width + 6), terrainOnly)
					if high and math.abs(high.Normal.Y) < 0.35 then
						if onWall(folder, pick(KIT.curtains, rng), high.Position, Vector3.new(high.Normal.X, 0, high.Normal.Z).Unit, rng:NextNumber(0.5, 0.9)) then
							count += 1
						end
					end
				end
			end
			if c.width >= 10 and bottom.Normal.Y > 0.8 and rng:NextNumber() < 0.5 then
				if standOn(folder, pick({ "Grappolo_Stalagmiti_Basso", "Grappolo_Stalagmiti" }, rng), bottom.Position, Vector3.xAxis, rng:NextNumber(0.4, 0.7), 0.1, { support = Enum.Material.Glacier, maxGap = 0.7, maxBury = 0.8 }) then
					count += 1
				end
			end
		end
		-- frammenti sul bordo
		if rng:NextNumber() < 0.5 then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local x, z = toWorld(g, sc + side * (c.width / 2 + rng:NextNumber(3, 9)), tt)
			local hit = ground(x, z, 9000)
			if hit and hit.Normal.Y > 0.5 then
				if standOn(folder, pick(KIT.fragments, rng), hit.Position, Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)), rng:NextNumber(0.6, 1.4), 0.25, { support = Enum.Material.Snow, maxGap = 0.6, maxBury = 0.85 }) then
					count += 1
				end
			end
		end
	end
	return count
end

-- Macerie di roccia sulle morene ai lati dei ghiacciai
local function moraines(folder: Instance, map: Heightmap.Map, g: any, rng: Random): number
	local count = 0
	for _ = 1, 30 do
		local s = rng:NextNumber(g.length * 0.3, g.length)
		local half = sample(g, s, g.half)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = toWorld(g, s, side * (half + rng:NextNumber(10, 40)))
		if zoneAt(map, x, z) ~= Zone.GLACIER then
			local hit = ground(x, z, sample(g, s, g.surf) + 300)
			if hit and hit.Normal.Y > 0.5 then
				if standOn(folder, pick(KIT.debris, rng), hit.Position, Vector3.new(g.ax, 0, g.az), rng:NextNumber(1, 2), 0.3, { maxBury = 0.6 }) then
					count += 1
				end
			end
		end
	end
	return count
end

-- Strapiombi in quota: volte e stalattiti appese sotto il tetto
local function overhangIce(folder: Instance, map: Heightmap.Map, rng: Random): number
	local H = map.cfg.MOUNTAIN.HEIGHT
	local count = 0
	for _, o in map.features.overhangs or {} do
		if o.roof > H * map.cfg.BIOMES.SNOW_LINE * 0.8 then
			local n = Vector3.new(o.nx, 0, o.nz)
			local tangent = Vector3.new(-o.nz, 0, o.nx)
			for _ = 1, 6 do
				local p = Vector3.new(o.x, o.roof - (o.under or 40) * 0.7, o.z)
					+ n * (o.depth * rng:NextNumber(0.2, 0.7))
					+ tangent * rng:NextNumber(-o.width * 0.25, o.width * 0.25)
				local up = workspace:Raycast(p, Vector3.new(0, 160, 0), terrainOnly)
				if up and up.Normal.Y < -0.4 then
					if hangUnder(folder, pick(KIT.hanging, rng), up.Position, math.atan2(-n.X, -n.Z) + rng:NextNumber(-0.4, 0.4), rng:NextNumber(0.8, 1.8)) then
						count += 1
					end
				end
			end
		end
	end
	return count
end

-- Grotte di ghiaccio: volte sul soffitto, colonne e grappoli sul pavimento
local function caveIce(folder: Instance, map: Heightmap.Map, rng: Random): number
	local count = 0
	for _, c in map.features.iceCaves or {} do
		local centre = Vector3.new(c.x, c.cy or (c.y + 12), c.z)
		for _ = 1, 10 do
			local p = centre + Vector3.new(rng:NextNumber(-18, 18), 0, rng:NextNumber(-18, 18))
			local up = workspace:Raycast(p, Vector3.new(0, 60, 0), terrainOnly)
			if up and up.Normal.Y < -0.7 and hangUnder(folder, pick(KIT.hanging, rng), up.Position, rng:NextNumber(0, 6.28), rng:NextNumber(0.7, 1.2)) then
				count += 1
			end
			local down = workspace:Raycast(p, Vector3.new(0, -60, 0), terrainOnly)
			if down and down.Normal.Y > 0.85 then
				if standOn(folder, pick(KIT.standing, rng), down.Position, Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)), rng:NextNumber(0.6, 1.1), 0.12, { support = Enum.Material.Glacier, maxGap = 0.7, maxBury = 0.8 }) then
					count += 1
				end
			end
		end
	end
	return count
end

-- Grotta di ghiaccio azzurro nel fronte del ghiacciaio: luci azzurre sotto la volta (la luce
-- che passa nel ghiaccio), stalattiti lungo la galleria, colonne e volte nella sala
local function glacierCave(folder: Instance, map: Heightmap.Map, rng: Random): number
	local gc = map.features.glacierCave
	if not gc then
		return 0
	end
	local count = 0
	local lights = Instance.new("Folder")
	lights.Name = "LuciGrottaGhiaccio"
	lights.Parent = folder
	local function light(p: Vector3, range: number, brightness: number, color: Color3)
		local a = Instance.new("Part")
		a.Name = "Luce"
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.Transparency = 1
		a.Size = Vector3.one
		a.Position = p
		a.Parent = lights
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Shadows = false
		l.Parent = a
	end
	local BLUE = Color3.fromRGB(110, 190, 255)
	local pts = gc.points
	for k = 4, #pts, 4 do
		local p = pts[k]
		local up = workspace:Raycast(p + Vector3.new(0, 3, 0), Vector3.new(0, 50, 0), terrainOnly)
		if up then
			light(p + Vector3.new(0, (up.Position.Y - p.Y) * 0.75, 0), 30, 1.3, BLUE)
			if k % 8 == 0 and hangUnder(folder, pick(KIT.hanging, rng), up.Position, rng:NextNumber(0, 6.28), rng:NextNumber(0.3, 0.5)) then
				count += 1
			end
		end
	end
	-- la sala
	local h = gc.hall
	local c = Vector3.new(h.x, h.y, h.z)
	light(c + Vector3.new(0, h.radius * 0.8, 0), h.radius * 1.6, 2, BLUE)
	for j = 1, 5 do
		local a = j / 5 * 2 * math.pi
		local p = c + Vector3.new(math.cos(a) * h.radius * 0.6, 6, math.sin(a) * h.radius * 0.6)
		light(p, 26, 1.2, if j % 2 == 0 then Color3.fromRGB(150, 220, 255) else BLUE)
		local up = workspace:Raycast(p, Vector3.new(0, 90, 0), terrainOnly)
		if up and hangUnder(folder, pick(KIT.hanging, rng), up.Position, rng:NextNumber(0, 6.28), rng:NextNumber(0.6, 1)) then
			count += 1
		end
		local down = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), terrainOnly)
		if down and rng:NextNumber() < 0.7 and standOn(folder, pick(KIT.standing, rng), down.Position, Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)), rng:NextNumber(0.5, 0.9), 0.12, { support = Enum.Material.Slate, maxGap = 0.7, maxBury = 0.8 }) then
			count += 1
		end
	end
	return count
end

-- Vetta e spalla: grappoli di stalagmiti e colonne di ghiaccio sui ripiani innevati piatti
local function summitIce(folder: Instance, map: Heightmap.Map, rng: Random): number
	local M = map.cfg.MOUNTAIN
	local count, tries = 0, 0
	while count < 45 and tries < 4000 do
		tries += 1
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(40, M.RADIUS * 0.45)
		local x, z = M.X + math.cos(a) * r, M.Z + math.sin(a) * r
		local top = map.features.summit
		local clear = not top or (Vector2.new(x, z) - Vector2.new(top.x, top.z)).Magnitude > (top.radius or 12) + 25 -- fuori dal santuario
		local hit = clear and ground(x, z, M.HEIGHT + 400)
		if hit and hit.Position.Y > M.HEIGHT * 0.6 and hit.Normal.Y > 0.7 and (hit.Material == Enum.Material.Snow or hit.Material == Enum.Material.Glacier) then
			if standOn(folder, pick(KIT.standing, rng), hit.Position, Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)), rng:NextNumber(0.9, 1.8), 0.15, { support = Enum.Material.Snow, maxGap = 0.6, maxBury = 0.85 }) then
				count += 1
			end
		end
	end
	return count
end

-- Seracchi sul ghiaccio sospeso: sul bordo della parete di ghiaccio (dove subito fuori il
-- terreno crolla), girati verso valle, come la fascia di seracchi del K2
local function iceCapSeracs(folder: Instance, map: Heightmap.Map, rng: Random): number
	local M = map.cfg.MOUNTAIN
	local count, tries = 0, 0
	while count < 70 and tries < 9000 do
		tries += 1
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(M.RADIUS * 0.15, M.RADIUS * 0.7)
		local x, z = M.X + math.cos(a) * r, M.Z + math.sin(a) * r
		if zoneAt(map, x, z) == Zone.ICECAP then
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local hit = ground(x, z, M.HEIGHT + 400)
			local beyond = hit and ground(x + out.X * 10, z + out.Z * 10, M.HEIGHT + 400)
			if hit and beyond and hit.Normal.Y > 0.6 and hit.Position.Y - beyond.Position.Y > 10 then
				local face = (out + Vector3.new(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))).Unit
				if standOn(folder, pick(KIT.seracs, rng), hit.Position, face, rng:NextNumber(1, 1.8), 0.2, { maxGap = 0.7, maxBury = 0.5 }) then
					count += 1
				end
			end
		end
	end
	return count
end

-- Iceberg: a galla nel lago di montagna e nel mare ai piedi dei ghiacciai
local function icebergs(folder: Instance, map: Heightmap.Map, rng: Random): number
	local count = 0
	local lake = map.features.lake
	if lake then
		for _ = 1, 12 do
			local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0, lake.radius * 0.6)
			if floatAt(folder, pick(KIT.icebergs, rng), Vector3.new(lake.x + math.cos(a) * r, 0, lake.z + math.sin(a) * r), lake.y, rng:NextNumber(0.5, 0.9), rng:NextNumber(0, 6.28)) then
				count += 1
			end
		end
	end
	-- mare: lungo la costa nella direzione di ogni ghiacciaio
	local M = map.cfg.MOUNTAIN
	local WL = map.cfg.WATER_LEVEL
	for _, g in map.features.glaciers or {} do
		local dir = Vector3.new(math.cos(g.angle), 0, math.sin(g.angle))
		local placed, tries = 0, 0
		while placed < 5 and tries < 80 do
			tries += 1
			local spread = dir + Vector3.new(-dir.Z, 0, dir.X) * rng:NextNumber(-0.5, 0.5)
			local p = Vector3.new(M.X, 0, M.Z) + spread.Unit * rng:NextNumber(M.RADIUS * 0.95, M.RADIUS * 1.5)
			local below = workspace:Raycast(Vector3.new(p.X, WL + 2, p.Z), Vector3.new(0, -200, 0), terrainOnly)
			if below and below.Position.Y < WL - 25 then
				if floatAt(folder, pick(KIT.icebergs, rng), p, WL, rng:NextNumber(1.5, 3.5), rng:NextNumber(0, 6.28)) then
					placed += 1
					count += 1
				end
			end
		end
	end
	return count
end

------------------------------------------------------------------------------------------
-- Scale-ponte
------------------------------------------------------------------------------------------

local function bridges(folder: Instance, g: any, rng: Random, perCrevasse: number): number
	local count = 0
	for _, c in g.crevasses or {} do
		if c.icefall and not c.path then
			continue
		end
		local spots: { number } = {}
		if c.path then
			table.insert(spots, c.path)
		end
		local want = if c.t1 - c.t0 > 120 then perCrevasse else 1
		local tries = 0
		while #spots < want and tries < 10 do
			tries += 1
			local t = rng:NextNumber(c.t0 + (c.t1 - c.t0) * 0.2, c.t1 - (c.t1 - c.t0) * 0.2)
			local far = true
			for _, o in spots do
				if math.abs(o - t) < 40 then
					far = false
				end
			end
			if far then
				table.insert(spots, t)
			end
		end
		for _, t in spots do
			local sc = crevasseCentre(g, c, t)
			local half = c.width * 0.65 + 4
			local function at(s: number): Vector3?
				local x, z = toWorld(g, s, t)
				local hit = ground(x, z, 9000)
				return hit and hit.Position
			end
			local a, b = at(sc - half), at(sc + half)
			if a and b and math.abs(a.Y - b.Y) < 14 then
				a += Vector3.new(0, 0.35, 0)
				b += Vector3.new(0, 0.35, 0)
				local bridge = ladder(folder, a, b, Vector3.yAxis, 2.4)
				bridge.Name = "PonteScala"
				local d = (b - a).Unit
				local plank = part(bridge, "Appoggio", Vector3.new(2.4, 0.3, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, (a + b) / 2 + d), METAL)
				plank.Transparency = 1
				local side = d:Cross(Vector3.yAxis).Unit
				for _, sgn in { -1, 1 } do
					rope(bridge, picket(bridge, a - d * 2 + side * sgn * 2), picket(bridge, b + d * 2 + side * sgn * 2))
				end
				count += 1
			end
		end
	end
	return count
end

------------------------------------------------------------------------------------------

function Glacier.build(map: Heightmap.Map)
	local old = workspace:FindFirstChild("Glacier")
	if old then
		old:Destroy()
	end
	local oldSpots = workspace:FindFirstChild("CinematicSpots")
	if oldSpots then
		oldSpots:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Glacier"
	local rng = Random.new(map.cfg.SEED + 91)
	local ladders = Instance.new("Folder")
	ladders.Name = "Scale"
	ladders.Parent = folder
	local ice = Instance.new("Folder")
	ice.Name = "Ghiaccio"
	ice.Parent = folder

	local nBridges, nCrev = 0, 0
	for _, g in map.features.glaciers or {} do
		nBridges += bridges(ladders, g, rng, map.cfg.GLACIER.LADDERS_PER_CREVASSE)
		nCrev += #(g.crevasses or {})
	end
	local counts = { seraccate = 0, fronti = 0, crepacci = 0, morene = 0 }
	local nOver, nGrotta, nCave, nTop, nBergs, nCap = 0, 0, 0, 0, 0, 0
	if loadKit() then
		for _, g in map.features.glaciers or {} do
			counts.seraccate += icefalls(ice, map, g, rng)
			counts.fronti += front(ice, map, g, rng)
			counts.crepacci += crevasseIce(ice, map, g, rng)
			counts.morene += moraines(ice, map, g, rng)
		end
		nOver = overhangIce(ice, map, rng)
		nGrotta = glacierCave(ice, map, rng)
		nCave = caveIce(ice, map, rng)
		nTop = summitIce(ice, map, rng)
		nCap = iceCapSeracs(ice, map, rng)
		nBergs = icebergs(ice, map, rng)
	else
		warn("[MapGen] ServerStorage/IceKit non trovato: i ghiacciai restano senza blocchi di ghiaccio")
	end
	folder.Parent = workspace
	local unused, total = {}, 0
	for name, n in used do
		total += n
		if n == 0 then
			table.insert(unused, name)
		end
	end
	print(string.format(
		"[MapGen] Ghiacciai: %d, crepacci %d, scale-ponte %d | ghiaccio %d pezzi (seraccate %d, fronti %d, crepacci %d, morene %d, strapiombi %d, grotta azzurra %d, grotte %d, vetta %d, ghiaccio sospeso %d, iceberg %d) | scartati %d (%s)%s",
		#(map.features.glaciers or {}), nCrev, nBridges, total, counts.seraccate, counts.fronti, counts.crepacci, counts.morene,
		nOver, nGrotta, nCave, nTop, nCap, nBergs, rejected, (function() local t = {} for k, v in why do table.insert(t, k .. " " .. v) end return table.concat(t, ", ") end)(),
		if #unused > 0 then " | NON USATI: " .. table.concat(unused, ", ") else " | tutti i modelli usati"
	))

	-- Punto per la scena cinematografica (comando admin "cinematica"): lo strapiombo piu'
	-- grande a quota media. Con lo streaming il client non riceve le parti lontane, quindi si
	-- passa tutto con gli attributi del Workspace.
	local H = map.cfg.MOUNTAIN.HEIGHT
	local best = nil
	for _, o in map.features.overhangs or {} do
		if o.roof > H * 0.12 and o.roof < H * 0.55 and (not best or o.depth * o.width > best.depth * best.width) then
			best = o
		end
	end
	if best then
		workspace:SetAttribute("CineSpot", Vector3.new(best.x, best.roof, best.z))
		workspace:SetAttribute("CineNormal", Vector3.new(best.nx, 0, best.nz))
		workspace:SetAttribute("CineDepth", best.depth)
		workspace:SetAttribute("CineUnder", best.under or 60)
	end
end

return Glacier
