--!strict
-- Scava grotte e gallerie nel Terrain gia' scritto (FillBall/FillBlock con Air):
--   * galleria principale a spirale dentro la montagna (ingresso dalla piana, finestra sulla
--     cascata, uscita a meta' montagna)
--   * cunicoli laterali: vicoli ciechi con stanze per i minerali, alcuni sbucano all'esterno
--   * grotte di ghiaccio in quota
--   * catacomba segreta sotto il livello del mare, raggiungibile da un pozzo nascosto
--   * anfratto segreto nella parete piu' ripida
--   * blocchi di roccia fluttuanti nei buchi "floating" del sentiero
--   * camera del tesoro al centro della montagna, con l'altare dell'uovo del drago Ombra
--
-- La montagna e' vuota dentro (vedi Voxelizer): gli scavi vengono prima registrati, poi le
-- gallerie che passano nella cavita' ricevono un rivestimento di roccia (HOLLOW.WALL) e solo
-- dopo si scava. Cosi' ogni galleria resta un tubo chiuso anche dove intorno c'e' il vuoto.

local Heightmap = require(script.Parent.Heightmap)

local sampleH, findSurfaceR = Heightmap.sampleH, Heightmap.findSurfaceR
local cos, sin, min, max, ceil, abs = math.cos, math.sin, math.min, math.max, math.ceil, math.abs
local noise = math.noise

local Caves = {}

local AIR = Enum.Material.Air
local ROCK = Enum.Material.Rock

local function toPoint(v: Vector3): Heightmap.Point
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Tubo scavato tra una sequenza di punti, con raggio che varia un po' (pareti irregolari).
-- Il rumore puo' solo allargare, mai stringere: un cunicolo piu' stretto del raggio chiesto non si
-- attraversa (il personaggio e' alto ~5 studs e i voxel da 4 arrotondano ancora in difetto).
-- Se si passa `map`, il tubo si interrompe dove lascerebbe meno di COVER studs di roccia sopra:
-- altrimenti resta un soffitto sottile che si vede ma non regge, e ci si cade dentro.
local function carvePath(
	terrain: Terrain,
	points: { Vector3 },
	radius: number,
	yield: () -> (),
	map: Heightmap.Map?
)
	local cover = if map then (map :: Heightmap.Map).cfg.CAVES.COVER else -math.huge
	local function ball(p: Vector3, r: number)
		if map and sampleH(map :: Heightmap.Map, p.X, p.Z) - p.Y < r + cover then
			return
		end
		terrain:FillBall(p, r, AIR)
	end
	for k = 1, #points - 1 do
		local a, b = points[k], points[k + 1]
		local steps = max(1, ceil((b - a).Magnitude / (radius * 0.5)))
		for s = 0, steps - 1 do
			local p = a:Lerp(b, s / steps)
			local r = radius * (1 + 0.22 * (noise(p.X / 18, p.Y / 18, p.Z / 18) * 0.5 + 0.5))
			ball(p, r)
		end
		yield()
	end
	if #points > 0 then
		ball(points[#points], radius)
	end
end

local function surfacePoint(map: Heightmap.Map, theta: number, y: number, extra: number): Vector3?
	local M = map.cfg.MOUNTAIN
	local r = findSurfaceR(map, theta, y)
	if not r then
		return nil
	end
	return Vector3.new(M.X + cos(theta) * (r + extra), y, M.Z + sin(theta) * (r + extra))
end

-- Galleria a spirale: pendenza camminabile, sempre ben dentro la roccia
local function carveHelix(map: Heightmap.Map, terrain: Terrain, yield: () -> ()): { Vector3 }
	local cfg = map.cfg
	local M, CV = cfg.MOUNTAIN, cfg.CAVES
	local features = map.features
	local theta = math.pi - 0.05 -- verso la piana
	local y = CV.ENTRY_Y
	local rSurf = findSurfaceR(map, theta, y) or M.RADIUS * 0.7
	local radius = min(CV.HELIX_MAX_RADIUS, rSurf * 0.5)

	-- Ingresso dalla piana (dove poi va il teschio di drago)
	local outside = Vector3.new(M.X + cos(theta) * (rSurf + 12), y, M.Z + sin(theta) * (rSurf + 12))
	local start = Vector3.new(M.X + cos(theta) * radius, y, M.Z + sin(theta) * radius)
	carvePath(terrain, { outside, start }, CV.TUNNEL_RADIUS, yield)
	features.caveEntrance = {
		x = M.X + cos(theta) * rSurf,
		y = y,
		z = M.Z + sin(theta) * rSurf,
		dirX = cos(theta),
		dirZ = sin(theta),
		floor = y - CV.TUNNEL_RADIUS,
	}

	local lake = features.lake
	local lakeTheta = math.atan2(lake.z - M.Z, lake.x - M.X)
	local windowY = lake.y * 0.85
	local windowDone = false
	local topY = M.HEIGHT * CV.HELIX_TOP_FRAC
	local points = { start }
	while y < topY do
		local rs = findSurfaceR(map, theta, y) or radius * 2
		radius += (min(CV.HELIX_MAX_RADIUS, rs * 0.5) - radius) * 0.05
		theta += 3 / radius
		y += 3 * CV.HELIX_GRADE
		local p = Vector3.new(M.X + cos(theta) * radius, y, M.Z + sin(theta) * radius)
		table.insert(points, p)

		-- Finestra panoramica sulla cascata
		local dTheta = abs((theta - lakeTheta + math.pi) % (2 * math.pi) - math.pi)
		if not windowDone and y >= windowY and dTheta < 0.1 then
			windowDone = true
			local out = surfacePoint(map, theta, y + 6, 10)
			if out then
				carvePath(terrain, { p, out }, CV.TUNNEL_RADIUS + 2, yield)
				features.caveWindow = toPoint(out)
			end
		end
	end
	carvePath(terrain, points, CV.TUNNEL_RADIUS, yield)

	-- Uscita a meta' montagna
	local last = points[#points]
	local exit = surfacePoint(map, theta, last.Y + 8, 12)
	if exit then
		carvePath(terrain, { last, exit }, CV.TUNNEL_RADIUS, yield)
		features.caveExit = toPoint(exit)
	end
	return points
end

-- Cunicoli laterali: vagano nella roccia e finiscono in una stanza (o sbucano fuori)
local function carveBranches(map: Heightmap.Map, terrain: Terrain, helix: { Vector3 }, rng: Random, yield: () -> ())
	local CV = map.cfg.CAVES
	local WL = map.cfg.WATER_LEVEL
	local rooms, exits = {}, {}
	for b = 1, CV.BRANCHES do
		local startIndex = math.floor(#helix * (b - 0.5) / CV.BRANCHES)
		local p = helix[max(1, startIndex)]
		local yaw = rng:NextNumber(0, 2 * math.pi)
		local pitch = rng:NextNumber(-0.08, 0.22)
		local length = rng:NextNumber(150, 450)
		local radius = rng:NextNumber(CV.MIN_RADIUS, CV.MIN_RADIUS + 2)
		local points = { p }
		local brokeOut = false
		for s = 1, math.floor(length / 4) do
			yaw += noise(b * 3.1, s / 12, 7.7) * 0.35
			local dir = Vector3.new(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
			p += dir * 4
			if p.Y < WL + 15 then
				pitch = abs(pitch)
			end
			table.insert(points, p)
			if sampleH(map, p.X, p.Z) < p.Y + radius then
				brokeOut = true -- sbucato all'esterno: uscita segreta
				break
			end
		end
		carvePath(terrain, points, radius, yield, map)
		local last = points[#points]
		if brokeOut then
			table.insert(exits, toPoint(last))
		else
			local roomRadius = rng:NextNumber(10, 16)
			terrain:FillBall(last, roomRadius, AIR)
			table.insert(rooms, { x = last.X, y = last.Y - roomRadius * 0.7, z = last.Z })
		end
	end
	map.features.oreRooms = rooms
	map.features.secretExits = exits
end

-- Galleria "a verme" tra due punti: serpeggia invece di andare dritta
local function wormBetween(a: Vector3, b: Vector3, seed: number): { Vector3 }
	local dist = (b - a).Magnitude
	local n = max(2, ceil(dist / 12))
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local points = {}
	for k = 0, n do
		local t = k / n
		local wobble = math.sin(t * math.pi) -- fermo alle estremita'
		local off = side * noise(seed, t * 3, 1.3) * 60 * wobble + Vector3.new(0, noise(seed, t * 3, 4.1) * 20 * wobble, 0)
		table.insert(points, a:Lerp(b, t) + off)
	end
	return points
end

-- Ingressi extra sparsi sulla montagna, ognuno collegato al punto piu' vicino della galleria
local function carveEntrances(map: Heightmap.Map, terrain: Terrain, helix: { Vector3 }, rng: Random, yield: () -> ())
	local cfg = map.cfg
	local M, CV = cfg.MOUNTAIN, cfg.CAVES
	local entrances = {}
	local topY = M.HEIGHT * CV.HELIX_TOP_FRAC
	for k = 1, CV.ENTRANCES do
		local theta = (k / CV.ENTRANCES) * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local y = rng:NextNumber(CV.ENTRY_Y + 60, topY * 0.95)
		local out = surfacePoint(map, theta, y, 10)
		if out then
			local nearest = helix[1]
			for _, p in helix do
				if (p - out).Magnitude < (nearest - out).Magnitude then
					nearest = p
				end
			end
			carvePath(terrain, wormBetween(out, nearest, k * 13.7), CV.TUNNEL_RADIUS - 1, yield)
			table.insert(entrances, toPoint(out - Vector3.new(0, CV.TUNNEL_RADIUS - 1, 0)))
		end
	end
	map.features.caveEntrances = entrances
end

-- Caverne-miniera: grandi spiazzi con pavimento piatto a quote diverse, dove mettere i
-- giacimenti di minerali. Ognuna e' collegata alla galleria principale.
local function carveMineChambers(map: Heightmap.Map, terrain: Terrain, helix: { Vector3 }, rng: Random, yield: () -> ())
	local M, CV = map.cfg.MOUNTAIN, map.cfg.CAVES
	local chambers = {}
	for k = 1, CV.MINE_CHAMBERS do
		local frac = 0.06 + (k - 1) / math.max(CV.MINE_CHAMBERS - 1, 1) * 0.62
		local y = M.HEIGHT * frac
		local theta = rng:NextNumber(0, 2 * math.pi)
		local rs = findSurfaceR(map, theta, y)
		if rs then
			local R = rng:NextNumber(30, 44)
			local c = Vector3.new(M.X + cos(theta) * rs * 0.65, y, M.Z + sin(theta) * rs * 0.65)
			-- Cupola irregolare + pavimento piatto
			terrain:FillBall(c + Vector3.new(0, R * 0.3, 0), R, AIR)
			for _ = 1, 4 do
				local o = Vector3.new(rng:NextNumber(-R, R) * 0.6, rng:NextNumber(0, R * 0.4), rng:NextNumber(-R, R) * 0.6)
				terrain:FillBall(c + o, R * rng:NextNumber(0.45, 0.7), AIR)
			end
			local floorY = c.Y - R * 0.35
			terrain:FillBlock(CFrame.new(c.X, floorY - R * 0.25, c.Z), Vector3.new(R * 2.6, R * 0.5, R * 2.6), Enum.Material.Slate)
			-- Collegamento alla galleria principale
			local nearest = helix[1]
			for _, p in helix do
				if (p - c).Magnitude < (nearest - c).Magnitude then
					nearest = p
				end
			end
			carvePath(terrain, wormBetween(Vector3.new(c.X, floorY + 6, c.Z), nearest, k * 31.7), CV.LINK_RADIUS, yield, map)
			table.insert(chambers, { x = c.X, y = floorY, z = c.Z, radius = R, frac = frac })
		end
	end
	map.features.mineChambers = chambers
end

-- Collegamenti tra stanze, cunicoli e galleria: la rete diventa un labirinto con piu' strade
local function carveLoops(map: Heightmap.Map, terrain: Terrain, helix: { Vector3 }, rng: Random, yield: () -> ())
	local CV = map.cfg.CAVES
	local nodes = {}
	for _, r in map.features.oreRooms do
		table.insert(nodes, Vector3.new(r.x, r.y + 4, r.z))
	end
	for _, c in map.features.mineChambers do
		table.insert(nodes, Vector3.new(c.x, c.y + 6, c.z))
	end
	for k = 1, #helix, math.max(1, #helix // 12) do
		table.insert(nodes, helix[k])
	end
	for k = 1, CV.LOOPS do
		local a = nodes[rng:NextInteger(1, #nodes)]
		-- collega al nodo piu' vicino che non sia se stesso, entro 500 studs
		local best, bestD = nil, math.huge
		for _, b in nodes do
			local d = (b - a).Magnitude
			if d > 40 and d < 500 and d < bestD and rng:NextNumber() < 0.7 then
				best, bestD = b, d
			end
		end
		if best then
			carvePath(terrain, wormBetween(a, best, 100 + k * 7.1), rng:NextNumber(CV.LINK_RADIUS, CV.LINK_RADIUS + 1.5), yield, map)
		end
	end
end

local function carveCatacomb(map: Heightmap.Map, terrain: Terrain, helixStart: Vector3, yield: () -> ())
	local M, CV = map.cfg.MOUNTAIN, map.cfg.CAVES
	local cy = CV.CATACOMB_Y
	local center = Vector3.new(M.X, cy, M.Z)
	local SPACING, ROOM, HEIGHT = 64, 36, 20

	-- Griglia 3x3 di stanze collegate da corridoi, con colonne di roccia
	local roomCenters = {}
	for gx = -1, 1 do
		for gz = -1, 1 do
			local c = center + Vector3.new(gx * SPACING, 0, gz * SPACING)
			table.insert(roomCenters, c)
			terrain:FillBlock(CFrame.new(c), Vector3.new(ROOM, HEIGHT, ROOM), AIR)
			if gx < 1 then
				terrain:FillBlock(CFrame.new(c + Vector3.new(SPACING / 2, -5, 0)), Vector3.new(SPACING, 10, 10), AIR)
			end
			if gz < 1 then
				terrain:FillBlock(CFrame.new(c + Vector3.new(0, -5, SPACING / 2)), Vector3.new(10, 10, SPACING), AIR)
			end
		end
	end
	for _, c in roomCenters do
		for _, o in { Vector3.new(-9, 0, -9), Vector3.new(9, 0, -9), Vector3.new(-9, 0, 9), Vector3.new(9, 0, 9) } do
			-- colonne spesse almeno un voxel e mezzo, altrimenti Roblox le scrive come lame
			terrain:FillBlock(CFrame.new(c + o), Vector3.new(8, HEIGHT, 8), Enum.Material.Slate)
		end
	end
	yield()

	-- Passaggio segreto: fessura stretta di lato alla galleria, poi pozzo verticale
	local toCenter = (Vector3.new(M.X, helixStart.Y, M.Z) - helixStart).Unit
	local side = Vector3.new(-toCenter.Z, 0, toCenter.X)
	local pocket = helixStart + side * 24
	local shaftBottom = Vector3.new(pocket.X, cy + 4, pocket.Z)
	carvePath(terrain, { helixStart, pocket }, CV.LINK_RADIUS, yield, map)
	carvePath(terrain, { pocket, shaftBottom }, CV.LINK_RADIUS, yield, map)
	local nearest = roomCenters[1]
	for _, c in roomCenters do
		if (c - shaftBottom).Magnitude < (nearest - shaftBottom).Magnitude then
			nearest = c
		end
	end
	carvePath(terrain, { shaftBottom, nearest + Vector3.new(0, -4, 0) }, CV.LINK_RADIUS, yield, map)

	map.features.catacombShaft = toPoint(pocket)
	map.features.catacomb = { x = center.X, y = cy - HEIGHT / 2, z = center.Z }
end

local function carveIceCaves(map: Heightmap.Map, terrain: Terrain, rng: Random, yield: () -> ())
	local M, CV = map.cfg.MOUNTAIN, map.cfg.CAVES
	local caves = {}
	for _, frac in CV.ICE_CAVES do
		local y = M.HEIGHT * frac
		local theta = rng:NextNumber(0, 2 * math.pi)
		local rs = findSurfaceR(map, theta, y)
		if rs then
			local c = Vector3.new(M.X + cos(theta) * rs * 0.45, y, M.Z + sin(theta) * rs * 0.45)
			-- caverna grande: dentro ci vanno volte di stalattiti, colonne e grappoli di ghiaccio
			terrain:FillBall(c, 30, AIR)
			terrain:FillBlock(CFrame.new(c - Vector3.new(0, 26, 0)), Vector3.new(56, 8, 56), Enum.Material.Glacier) -- pavimento piano
			-- Pareti di ghiaccio attorno alla camera
			local region = Region3.new(c - Vector3.new(40, 40, 40), c + Vector3.new(40, 40, 40)):ExpandToGrid(4)
			for _, mat in { Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Snow } do
				terrain:ReplaceMaterial(region, 4, mat, Enum.Material.Glacier)
			end
			local out = Vector3.new(M.X + cos(theta) * (rs + 8), y + 4, M.Z + sin(theta) * (rs + 8))
			carvePath(terrain, { c, out }, CV.LINK_RADIUS, yield)
			table.insert(caves, { x = c.X, y = c.Y - 22, z = c.Z, cy = c.Y, r = 30 })
		end
	end
	map.features.iceCaves = caves
end

-- Grotta di ghiaccio azzurro nel ghiacciaio (come quelle dell'Islanda): l'ingresso e' un arco
-- nel fronte alto della lingua, poi una galleria che serpeggia salendo piano sotto il ghiacciaio
-- e finisce in una grande sala. Pareti e volta diventano ghiaccio (Ice, azzurro intenso), il
-- pavimento e' ghiaia (Slate). Volta piu' alta del raggio e "conche" sulle pareti, come il
-- ghiaccio scavato dall'acqua. Luci, stalattiti e colonne le mette Glacier.
local ICE_FROM = {
	Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Snow,
	Enum.Material.Glacier, Enum.Material.Ground, Enum.Material.Grass, Enum.Material.LeafyGrass,
	Enum.Material.Mud, Enum.Material.Limestone, Enum.Material.Sandstone, Enum.Material.Sand,
}
local function carveGlacierCave(map: Heightmap.Map, terrain: Terrain, rng: Random, yield: () -> ())
	local GC = map.cfg.CAVES.GLACIER_CAVE
	local g = GC and map.features.glaciers and map.features.glaciers[GC.GLACIER]
	if not g then
		return
	end
	local R, H = GC.RADIUS, GC.HALL
	local UP = Vector3.yAxis
	local function at(s: number, t: number): (number, number)
		return Heightmap.glacierToWorld(g, s, t)
	end
	-- percorso: dal piede del fronte verso monte, serpeggiando
	local s0 = g.length + 6
	local x0, z0 = at(s0, 0)
	local y = sampleH(map, x0, z0)
	local phase = rng:NextNumber(0, 6.28)
	local points: { Vector3 } = {}
	local inside: { boolean } = {}
	local STEP = 5
	for k = 0, math.floor(GC.LENGTH / STEP) do
		local s = s0 - k * STEP
		local t = 28 * sin(k * 0.075 + phase) * math.clamp(k / 8, 0, 1)
		local x, z = at(s, t)
		table.insert(points, Vector3.new(x, y, z))
		table.insert(inside, s < g.length - 34) -- piu' vicino al fronte la conversione arrivava fuori (un quadrato azzurro)
		y += STEP * GC.GRADE
	end
	local function cut(c: Vector3, r: number, force: boolean)
		-- mai sfondare la superficie (tranne all'ingresso, che e' un arco nel fronte)
		if not force and sampleH(map, c.X, c.Z) - (c.Y + r) < 12 then
			r = sampleH(map, c.X, c.Z) - 12 - c.Y
			if r < 5 then
				return
			end
		end
		terrain:FillBall(c, r, AIR)
	end
	for k, p in points do
		local entry = k <= 4
		local side = Vector3.new(-(points[min(k + 1, #points)] - p).Z, 0, (points[min(k + 1, #points)] - p).X)
		side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
		cut(p + UP * R * 0.75, R * (1 + 0.12 * noise(p.X / 20, p.Y / 20, p.Z / 20)), entry)
		cut(p + UP * R * 1.3, R * 0.6, entry) -- volta alta
		if k % 2 == 0 then
			-- conche nelle pareti, un po' a destra e un po' a sinistra
			local sgn = if rng:NextNumber() < 0.5 then -1 else 1
			cut(p + side * sgn * R * 0.6 + UP * R * rng:NextNumber(0.5, 1.1), R * rng:NextNumber(0.45, 0.65), entry)
		end
		if k % 8 == 0 then
			yield()
		end
	end
	-- sala in fondo: cupola irregolare
	local last = points[#points]
	local hallC = last + UP * H * 0.5
	cut(hallC, H, false)
	for j = 1, 5 do
		local a = j / 5 * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		cut(last + Vector3.new(cos(a) * H * 0.6, H * rng:NextNumber(0.25, 0.6), sin(a) * H * 0.6), H * rng:NextNumber(0.45, 0.65), false)
	end
	-- tutto quello che si vede dentro diventa ghiaccio azzurro; i primi metri restano del ghiaccio
	-- del ghiacciaio (piu' chiaro), come la luce del giorno che entra
	for k, p in points do
		if inside[k] then
			local half = Vector3.one * (R * 1.9 + GC.SHELL)
			local region = Region3.new(p + UP * R * 0.75 - half, p + UP * R * 0.75 + half):ExpandToGrid(4)
			for _, mat in ICE_FROM do
				if inside[k] or (mat ~= Enum.Material.Grass and mat ~= Enum.Material.LeafyGrass and mat ~= Enum.Material.Ground and mat ~= Enum.Material.Mud) then
					terrain:ReplaceMaterial(region, 4, mat, Enum.Material.Ice)
				end
			end
		end
	end
	local hallHalf = Vector3.one * (H * 1.7 + GC.SHELL)
	local hallRegion = Region3.new(hallC - hallHalf, hallC + hallHalf):ExpandToGrid(4)
	for _, mat in ICE_FROM do
		terrain:ReplaceMaterial(hallRegion, 4, mat, Enum.Material.Ice)
	end
	-- pavimento di ghiaia, in piano lungo la galleria
	for k = 1, #points - 1 do
		local a, b = points[k], points[k + 1]
		terrain:FillBlock(CFrame.lookAt(a:Lerp(b, 0.5) - UP * 3, b - UP * 3), Vector3.new(R * 1.6, 6, (b - a).Magnitude + 4), Enum.Material.Slate)
	end
	terrain:FillCylinder(CFrame.new(last - UP * 4), 8, H * 1.05, Enum.Material.Slate)
	map.features.glacierCave = {
		entrance = toPoint(points[1]),
		hall = { x = last.X, y = last.Y, z = last.Z, radius = H },
		points = points,
	}
	-- la sala conta anche come grotta di ghiaccio (uova del Gelo, golem)
	table.insert(map.features.iceCaves, { x = last.X, y = last.Y, z = last.Z, cy = hallC.Y, r = H })
end

-- Anfratto segreto: nel punto piu' ripido della parete est a quella quota
local function carveNiche(map: Heightmap.Map, terrain: Terrain)
	local M, CV = map.cfg.MOUNTAIN, map.cfg.CAVES
	local y = M.HEIGHT * CV.NICHE_FRAC
	local bestTheta, bestSlope, bestR = 0, -math.huge, nil
	for theta = -0.8, 0.8, 0.05 do
		local r = findSurfaceR(map, theta, y)
		if r then
			local hIn = sampleH(map, M.X + cos(theta) * (r - 6), M.Z + sin(theta) * (r - 6))
			local hOut = sampleH(map, M.X + cos(theta) * (r + 6), M.Z + sin(theta) * (r + 6))
			local slope = (hIn - hOut) / 12
			if slope > bestSlope then
				bestTheta, bestSlope, bestR = theta, slope, r
			end
		end
	end
	if not bestR then
		return
	end
	local c = Vector3.new(M.X + cos(bestTheta) * (bestR - 5), y, M.Z + sin(bestTheta) * (bestR - 5))
	terrain:FillBall(c, 7, AIR)
	terrain:FillBall(c - Vector3.new(cos(bestTheta), 0, sin(bestTheta)) * 8, 5, AIR)
	map.features.niche = { x = c.X, y = c.Y - 5, z = c.Z }
end

-- Blocchi di roccia sospesi nel vuoto al posto del sentiero, lungo un arco verso l'esterno
local function placeFloatingStones(map: Heightmap.Map, terrain: Terrain, rng: Random)
	local M = map.cfg.MOUNTAIN
	local stones = {}
	for _, gap in map.features.gaps do
		if gap.kind == "floating" and gap.from and gap.to then
			local a = Vector3.new(gap.from.x, gap.from.y, gap.from.z)
			local b = Vector3.new(gap.to.x, gap.to.y, gap.to.z)
			local mid = (a + b) / 2
			local outward = Vector3.new(mid.X - M.X, 0, mid.Z - M.Z).Unit
			local ctrl = mid + outward * 35 + Vector3.new(0, 6, 0)
			local n = max(3, math.floor((b - a).Magnitude / 12))
			for k = 1, n - 1 do
				local t = k / n
				local p = a * (1 - t) ^ 2 + ctrl * (2 * (1 - t) * t) + b * t * t
				p += Vector3.new(0, sin(k * 1.7) * 3 - 2, 0)
				local yaw = rng:NextNumber(0, math.pi)
				terrain:FillBlock(CFrame.new(p) * CFrame.Angles(0, yaw, 0), Vector3.new(10, 8, 10), Enum.Material.Slate)
				table.insert(stones, toPoint(p))
			end
		end
	end
	map.features.floatingStones = stones
end

-- Camera del tesoro: una grande cupola al centro della montagna, sotto la vetta, collegata alla
-- galleria a spirale. Al centro l'altare con l'uovo del drago Ombra (lo mette Eggs), attorno i
-- tesori (li mette la fase Treasure).
local function carveTreasureChamber(map: Heightmap.Map, terrain: Terrain, helix: { Vector3 }, yield: () -> ())
	local cfg = map.cfg
	local M, T = cfg.MOUNTAIN, cfg.TREASURE
	if not T then
		return
	end
	local c = Vector3.new(M.X, T.Y, M.Z)
	local R = T.RADIUS
	terrain:FillBall(c + Vector3.new(0, R * 0.25, 0), R, AIR)
	for k = 0, 5 do
		local a = k / 6 * 2 * math.pi
		terrain:FillBall(c + Vector3.new(cos(a) * R * 0.6, R * 0.1, sin(a) * R * 0.6), R * 0.55, AIR)
	end
	local floorY = c.Y - R * 0.45
	-- pavimento rotondo (un disco), non un quadrato
	terrain:FillCylinder(CFrame.new(c.X, floorY - 6, c.Z), 12, R * 1.05, Enum.Material.Slate)
	-- collegamento alla galleria a spirale (alla quota piu' vicina)
	local nearest = helix[1]
	for _, p in helix do
		if math.abs(p.Y - floorY) < math.abs(nearest.Y - floorY) then
			nearest = p
		end
	end
	local edge = c + (Vector3.new(nearest.X, 0, nearest.Z) - Vector3.new(c.X, 0, c.Z)).Unit * R * 0.8
	carvePath(terrain, wormBetween(Vector3.new(edge.X, floorY + 8, edge.Z), nearest, 77.7), cfg.CAVES.TUNNEL_RADIUS, yield)
	map.features.treasure = { x = c.X, y = floorY, z = c.Z, radius = R }
end

function Caves.carve(map: Heightmap.Map, yield: () -> (), progress: (string, number) -> ())
	-- gli scavi si registrano qui e si eseguono alla fine (rivestimento + scavo)
	local real = workspace.Terrain
	local ops: { any } = {}
	local recorder: any = {}
	function recorder.FillBall(_, center: Vector3, radius: number, material: Enum.Material)
		table.insert(ops, { kind = "ball", c = center, r = radius, m = material })
	end
	function recorder.FillBlock(_, cf: CFrame, size: Vector3, material: Enum.Material)
		table.insert(ops, { kind = "block", cf = cf, size = size, m = material })
	end
	function recorder.FillCylinder(_, cf: CFrame, height: number, radius: number, material: Enum.Material)
		table.insert(ops, { kind = "cylinder", cf = cf, h = height, r = radius, m = material })
	end
	function recorder.ReplaceMaterial(_, region: Region3, res: number, from: Enum.Material, to: Enum.Material)
		table.insert(ops, { kind = "replace", region = region, res = res, from = from, to = to })
	end
	local terrain = recorder :: Terrain
	local rng = Random.new(map.cfg.SEED + 99)
	progress("Galleria a spirale", 0)
	local helix = carveHelix(map, terrain, yield)
	progress("Cunicoli e stanze", 0.3)
	carveBranches(map, terrain, helix, rng, yield)
	progress("Ingressi e collegamenti", 0.5)
	carveEntrances(map, terrain, helix, rng, yield)
	carveMineChambers(map, terrain, helix, rng, yield)
	carveLoops(map, terrain, helix, rng, yield)
	progress("Catacomba segreta", 0.6)
	carveCatacomb(map, terrain, helix[1], yield)
	progress("Grotte di ghiaccio", 0.8)
	carveIceCaves(map, terrain, rng, yield)
	carveGlacierCave(map, terrain, rng, yield)
	carveNiche(map, terrain)
	placeFloatingStones(map, terrain, rng)
	carveTreasureChamber(map, terrain, helix, yield)

	-- 1. rivestimento: le gallerie che passano nella cavita' della montagna vuota diventano tubi
	--    chiusi (solo se il rivestimento resta tutto sottoterra: mai bolle di roccia all'esterno)
	progress("Rivestimento gallerie", 0.9)
	local W = if map.cfg.HOLLOW then map.cfg.HOLLOW.WALL else 0
	local lined = 0
	if W > 0 then
		for k, op in ops do
			if op.m == AIR then
				local p: Vector3 = if op.kind == "ball" then op.c elseif op.kind == "block" then op.cf.Position else Vector3.zero
				local half = if op.kind == "ball" then op.r elseif op.kind == "block" then max(op.size.X, op.size.Y, op.size.Z) / 2 else 0
				local top = Heightmap.hollowTop(map, p.X, p.Z)
				if half > 0 and p.Y - half - W < top and p.Y + half + W < sampleH(map, p.X, p.Z) - 4 then
					if op.kind == "ball" then
						real:FillBall(p, op.r + W, ROCK)
					else
						real:FillBlock(op.cf, op.size + Vector3.one * 2 * W, ROCK)
					end
					lined += 1
				end
			end
			if k % 150 == 0 then
				yield()
			end
		end
	end
	-- 2. scavo, nell'ordine in cui era stato chiesto
	for k, op in ops do
		if op.kind == "ball" then
			real:FillBall(op.c, op.r, op.m)
		elseif op.kind == "block" then
			real:FillBlock(op.cf, op.size, op.m)
		elseif op.kind == "cylinder" then
			real:FillCylinder(op.cf, op.h, op.r, op.m)
		else
			real:ReplaceMaterial(op.region, op.res, op.from, op.to)
		end
		if k % 150 == 0 then
			yield()
		end
	end
	print(string.format("[MapGen] Grotte: %d scavi, %d rivestiti nella cavita'", #ops, lined))
	progress("Grotte", 1)
end

return Caves
