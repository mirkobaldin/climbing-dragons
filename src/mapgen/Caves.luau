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
--   * stanze lungo la galleria a spirale (una ogni TUNNEL_ROOM_EVERY punti), coi giacimenti
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

-- Stanze lungo la galleria principale: prima si camminava per minuti nella spirale senza trovare
-- niente. Ogni TUNNEL_ROOM_EVERY punti (3 stud l'uno) una sala di lato al tunnel, a destra e a
-- sinistra alternate, con il pavimento piatto: ci vanno i giacimenti e una luce (vedi Ores).
local function carveTunnelRooms(map: Heightmap.Map, terrain: Terrain, helix: { Vector3 }, rng: Random, yield: () -> ())
	local CV = map.cfg.CAVES
	local every = CV.TUNNEL_ROOM_EVERY or 0
	local rooms = {}
	if every <= 0 then
		map.features.tunnelRooms = rooms
		return
	end
	local side = 1
	for k = math.floor(every * 0.6), #helix - 4, every do
		local p, q = helix[k], helix[k + 3]
		local along = Vector3.new(q.X - p.X, 0, q.Z - p.Z)
		if along.Magnitude < 0.01 then
			continue
		end
		local across = along.Unit:Cross(Vector3.yAxis) * side
		side = -side
		local R = rng:NextNumber(16, 24)
		local c = p + across * (CV.TUNNEL_RADIUS + R * 0.55) + Vector3.new(0, R * 0.15, 0)
		-- deve restare roccia sopra (se no il soffitto e' sottile e ci si cade dentro)
		if sampleH(map, c.X, c.Z) - c.Y < R + CV.COVER + 6 then
			continue
		end
		terrain:FillBall(c + Vector3.new(0, R * 0.2, 0), R, AIR)
		for _ = 1, 3 do
			local o = Vector3.new(rng:NextNumber(-R, R) * 0.5, rng:NextNumber(0, R * 0.3), rng:NextNumber(-R, R) * 0.5)
			terrain:FillBall(c + o, R * rng:NextNumber(0.45, 0.65), AIR)
		end
		local floorY = math.max(c.Y - R * 0.45, p.Y - CV.TUNNEL_RADIUS + 1)
		terrain:FillBlock(CFrame.new(c.X, floorY - 3, c.Z), Vector3.new(R * 2.2, 6, R * 2.2), Enum.Material.Slate)
		-- passaggio largo dal tunnel alla stanza
		carvePath(terrain, { p, Vector3.new(c.X, floorY + 7, c.Z) }, CV.TUNNEL_RADIUS - 2, yield)
		table.insert(rooms, { x = c.X, y = floorY, z = c.Z, radius = R })
		yield()
	end
	map.features.tunnelRooms = rooms
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
			terrain:FillBall(c, 46, AIR)
			for _ = 1, 3 do
				terrain:FillBall(c + Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(-6, 14), rng:NextNumber(-30, 30)), rng:NextNumber(22, 32), AIR)
			end
			terrain:FillBlock(CFrame.new(c - Vector3.new(0, 40, 0)), Vector3.new(90, 8, 90), Enum.Material.Glacier) -- pavimento piano
			-- Pareti di ghiaccio attorno alla camera
			local region = Region3.new(c - Vector3.new(84, 60, 84), c + Vector3.new(84, 70, 84)):ExpandToGrid(4)
			for _, mat in { Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Snow } do
				terrain:ReplaceMaterial(region, 4, mat, Enum.Material.Glacier)
			end
			local out = Vector3.new(M.X + cos(theta) * (rs + 8), y + 4, M.Z + sin(theta) * (rs + 8))
			carvePath(terrain, { c, out }, CV.LINK_RADIUS, yield)
			table.insert(caves, { x = c.X, y = c.Y - 36, z = c.Z, cy = c.Y, r = 46 })
		end
	end
	map.features.iceCaves = caves
end

-- Grotta dentro la montagna vuota (Voxelizer: guscio di roccia e cavita' dentro). Le sfere
-- scavate possono sfondare il guscio e aprirsi sulla cavita': cosi' la sala della grotta di
-- ghiaccio aveva i lati e il fondo aperti sul vuoto e camminando verso i lobi si cadeva fuori
-- dalla mappa (Mirko 16/10, video 124253). Qui, solo sui voxel d'aria:
--   * attorno alle sfere, per `shell` studs e solo sotto la superficie, ghiaccio (le pareti
--     diventano un guscio chiuso);
--   * dentro le sfere che hanno `floor`, sotto quella quota, ghiaia (pavimento pieno, niente
--     buchi nel fondo).
-- balls: { c, r, floor? }; surface(x, z) = quota della superficie; skip(p) = true per non
-- toccare quel punto (l'ingresso, che deve restare aperto).
export type Ball = { c: Vector3, r: number, floor: number? }
function Caves.seal(terrain: Terrain, balls: { Ball }, shell: number, surface: (number, number) -> number, skip: ((Vector3) -> boolean)?, yield: () -> ())
	if #balls == 0 then
		return 0, 0
	end
	local lo, hi = balls[1].c, balls[1].c
	for _, b in balls do
		local e = Vector3.one * (b.r + shell + 4)
		lo = lo:Min(b.c - e)
		hi = hi:Max(b.c + e)
	end
	local CH = 64 -- studs per blocco (16 voxel per lato)
	local cols: { [number]: number } = {}
	local function top(x: number, z: number): number
		local key = math.floor(x / 4) * 100003 + math.floor(z / 4)
		local v = cols[key]
		if not v then
			v = surface(x, z)
			cols[key] = v
		end
		return v
	end
	local filled, floored = 0, 0
	for bx = math.floor(lo.X / CH) * CH, hi.X, CH do
		for bz = math.floor(lo.Z / CH) * CH, hi.Z, CH do
			for by = math.floor(lo.Y / CH) * CH, hi.Y, CH do
				local region = Region3.new(Vector3.new(bx, by, bz), Vector3.new(bx + CH, by + CH, bz + CH))
				-- sfere che toccano questo blocco
				local near: { Ball } = {}
				local mid = Vector3.new(bx + CH / 2, by + CH / 2, bz + CH / 2)
				for _, b in balls do
					if (b.c - mid).Magnitude < b.r + shell + CH then
						table.insert(near, b)
					end
				end
				if #near > 0 then
					local mats, occs = terrain:ReadVoxels(region, 4)
					local size = mats.Size
					local changed = false
					for i = 1, size.X do
						for j = 1, size.Y do
							for k = 1, size.Z do
								if mats[i][j][k] == AIR then
									local p = Vector3.new(bx + (i - 0.5) * 4, by + (j - 0.5) * 4, bz + (k - 0.5) * 4)
									local inside, floorBall, gap = false, false, math.huge
									for _, b in near do
										local d = (p - b.c).Magnitude - b.r
										if d < 0 then
											inside = true
											if b.floor and p.Y < (b.floor :: number) then
												floorBall = true
											end
										elseif d < gap then
											gap = d
										end
									end
									if not (skip and (skip :: (Vector3) -> boolean)(p)) then
										if inside and floorBall then
											mats[i][j][k] = Enum.Material.Slate
											occs[i][j][k] = 1
											changed = true
											floored += 1
										elseif not inside and gap <= shell and p.Y < top(p.X, p.Z) - 6 then
											mats[i][j][k] = Enum.Material.Ice
											occs[i][j][k] = 1
											changed = true
											filled += 1
										end
									end
								end
							end
						end
					end
					if changed then
						terrain:WriteVoxels(region, 4, mats, occs)
					end
					yield()
				end
			end
		end
	end
	return filled, floored
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
local function carveGlacierCave(map: Heightmap.Map, terrain: Terrain, rng: Random, yield: () -> (), GC: any)
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
		local t = R * 2 * sin(k * 0.075 + phase) * math.clamp(k / 8, 0, 1)
		local x, z = at(s, t)
		table.insert(points, Vector3.new(x, y, z))
		table.insert(inside, s < g.length - R * 2.6) -- piu' vicino al fronte la conversione arrivava fuori (un quadrato azzurro)
		y += STEP * GC.GRADE
	end
	-- sfere scavate: servono dopo per chiudere la grotta verso la cavita' della montagna
	local carved: { Ball } = {}
	local floorY: number? = nil -- quota del pavimento per le sfere che si stanno scavando
	local function cut(c: Vector3, r: number, force: boolean)
		-- mai sfondare la superficie (tranne all'ingresso, che e' un arco nel fronte)
		if not force and sampleH(map, c.X, c.Z) - (c.Y + r) < 12 then
			r = sampleH(map, c.X, c.Z) - 12 - c.Y
			if r < 5 then
				return
			end
		end
		terrain:FillBall(c, r, AIR)
		table.insert(carved, { c = c, r = r, floor = floorY })
	end
	for k, p in points do
		local entry = k <= 4
		floorY = p.Y - 2
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
	-- la sala ha il pavimento alla quota dell'ultimo punto: sotto, tutto pieno (anche nei lobi)
	floorY = last.Y - 1
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
	-- chiusura verso la montagna vuota: pareti di ghiaccio e fondo pieno (prima la sala si apriva
	-- sulla cavita' e si cadeva fuori dalla mappa); l'ingresso nel fronte resta aperto
	local mouth = points[1]
	Caves.seal(terrain, carved, GC.SHELL, function(x, z)
		return sampleH(map, x, z)
	end, function(p)
		return Vector3.new(p.X - mouth.X, 0, p.Z - mouth.Z).Magnitude < R * 2.5
	end, yield)
	local feature = {
		entrance = toPoint(points[1]),
		hall = { x = last.X, y = last.Y, z = last.Z, radius = H },
		points = points,
		radius = R,
	}
	map.features.glacierCaves = map.features.glacierCaves or {}
	table.insert(map.features.glacierCaves, feature)
	map.features.glacierCave = map.features.glacierCave or feature -- la prima: li' davanti c'e' il campo base
	-- la sala conta anche come grotta di ghiaccio (uova del Gelo, golem)
	table.insert(map.features.iceCaves, { x = last.X, y = last.Y, z = last.Z, cy = hallC.Y, r = H })
end

-- Spaccatura: la montagna e' spaccata. Una fessura larga e profonda entra nel fianco della
-- montagna ed e' aperta verso il cielo: niente gallerie, la si vede da lontano. Le pareti e il
-- fondo diventano ghiaccio azzurro; la larghezza cambia lungo la fessura (piu' stretta in fondo).
-- Prima si riveste di roccia (la montagna e' vuota dentro: senza, si aprirebbe sulla cavita').
local function carveChasm(map: Heightmap.Map, terrain: Terrain, rng: Random, yield: () -> ())
	local C = map.cfg.CAVES.CHASM
	if not C then
		return
	end
	local M = map.cfg.MOUNTAIN
	local a = C.ANGLE
	local out = Vector3.new(cos(a), 0, sin(a))
	local side = Vector3.new(-out.Z, 0, out.X)
	local mouth = Vector3.new(M.X, 0, M.Z) + out * (C.DIST * M.RADIUS)
	local floorY = sampleH(map, mouth.X, mouth.Z) - C.DEPTH * 0.3
	local STEP = 8
	local n = math.floor(C.LENGTH / STEP)
	local seed = rng:NextNumber(0, 100)
	local centers: { Vector3 } = {}
	for k = 0, n do
		local f = k / n
		local wobble = noise(seed, k * 0.09, 2.2) * 30
		local p = mouth - out * (k * STEP) + side * wobble
		-- il fondo scende piano entrando, poi risale verso la fine (finisce a punta)
		local y = floorY - C.DEPTH * math.sin(f * math.pi) * 0.7
		table.insert(centers, Vector3.new(p.X, y, p.Z))
	end
	-- 1. rivestimento di roccia attorno alla fessura, sotto la superficie
	for k, p in centers do
		local f = (k - 1) / n
		local w = (C.WIDTH[1] + (C.WIDTH[2] - C.WIDTH[1]) * (0.5 + 0.5 * noise(seed, k * 0.13, 5.1))) * (1 - 0.6 * f)
		local top = sampleH(map, p.X, p.Z)
		local h = top - (p.Y - 16)
		if h > 8 then
			terrain:FillBlock(CFrame.lookAt(Vector3.new(p.X, p.Y - 16 + h / 2 - 2, p.Z), Vector3.new(p.X, p.Y - 16 + h / 2 - 2, p.Z) + out), Vector3.new(w + 26, h - 4, STEP + 26), ROCK)
		end
	end
	yield()
	-- 2. la fessura, aperta fino al cielo
	for k, p in centers do
		local f = (k - 1) / n
		local w = (C.WIDTH[1] + (C.WIDTH[2] - C.WIDTH[1]) * (0.5 + 0.5 * noise(seed, k * 0.13, 5.1))) * (1 - 0.6 * f)
		local top = sampleH(map, p.X, p.Z) + 60
		local h = top - p.Y
		terrain:FillBlock(CFrame.lookAt(Vector3.new(p.X, p.Y + h / 2, p.Z), Vector3.new(p.X, p.Y + h / 2, p.Z) + out), Vector3.new(w, h, STEP + 6), AIR)
		-- pareti ondulate: conche a varie altezze
		if k % 2 == 0 then
			local sgn = if rng:NextNumber() < 0.5 then -1 else 1
			terrain:FillBall(p + side * sgn * w * 0.45 + Vector3.new(0, rng:NextNumber(8, math.max(10, h * 0.6)), 0), rng:NextNumber(8, 14), AIR)
		end
		if k % 10 == 0 then
			yield()
		end
	end
	-- 3. tutto il ghiaccio: pareti e fondo azzurri
	for k, p in centers do
		if k % 2 == 1 then
			local top = sampleH(map, p.X, p.Z) + 10
			local half = Vector3.new(C.WIDTH[2] * 0.5 + 18, 0, C.WIDTH[2] * 0.5 + 18)
			local region = Region3.new(Vector3.new(p.X - half.X, p.Y - 14, p.Z - half.Z), Vector3.new(p.X + half.X, top, p.Z + half.Z)):ExpandToGrid(4)
			for _, mat in ICE_FROM do
				terrain:ReplaceMaterial(region, 4, mat, Enum.Material.Ice)
			end
		end
	end
	-- fondo camminabile (ghiaia) lungo la fessura
	for k = 1, #centers - 1 do
		local a1, b1 = centers[k], centers[k + 1]
		local f = (k - 1) / n
		local w = C.WIDTH[1] * (1 - 0.6 * f)
		terrain:FillBlock(CFrame.lookAt(a1:Lerp(b1, 0.5) - Vector3.new(0, 3, 0), b1 - Vector3.new(0, 3, 0)), Vector3.new(w * 0.7, 6, (b1 - a1).Magnitude + 4), Enum.Material.Slate)
	end
	local mid = centers[math.floor(#centers / 2)]
	map.features.chasm = { mouth = toPoint(centers[1]), middle = toPoint(mid), points = centers }
	table.insert(map.features.iceCaves, { x = mid.X, y = mid.Y, z = mid.Z, cy = mid.Y + 20, r = C.WIDTH[2] })
end

-- Grande Grotta: un'apertura ovale enorme nella parete e dentro una sala di ghiaccio azzurro.
-- Si fa direttamente sui voxel, in un passaggio: dentro la sala aria; attorno, per SHELL studs e
-- solo dentro la montagna, ghiaccio (riveste anche la cavita' della montagna vuota, cosi' non si
-- vede il buio dentro); in basso terrazze di neve e ghiaccio; colonne di ghiaccio da terra al
-- soffitto. La parete fuori resta roccia.
-- Ghiaccio che sfuma nella roccia attorno all'apertura: chiazze (piu' fitte vicino al bordo)
-- di ghiaccio, poi ghiacciaio e neve, sulla superficie della parete. Niente stacco netto.
local function iceFade(face: Vector3, out: Vector3, side: Vector3, G: any, rng: Random, yield: () -> ())
	local terrain = workspace.Terrain
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local M = Enum.Material
	local rocks = { M.Rock, M.Slate, M.Basalt, M.Ground, M.Limestone, M.Mud, M.Sandstone, M.Grass, M.LeafyGrass }
	local W, H = G.WIDTH * 0.95, G.HEIGHT * 0.95
	for k = 1, 420 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local f = rng:NextNumber() ^ 1.7 -- 0 = sul bordo, 1 = lontano
		local extra = f * G.FADE
		local q = face + side * math.cos(a) * (W + extra) + Vector3.new(0, math.sin(a) * (H + extra), 0)
		local hit = workspace:Raycast(q + out * 160, -out * 320, params)
		if hit and hit.Material ~= M.Air and hit.Material ~= M.Water then
			local s = rng:NextNumber(10, 26) * (1 - f * 0.5)
			local to = if f < 0.45 then M.Ice elseif f < 0.75 then M.Glacier else M.Snow
			local region = Region3.new(hit.Position - Vector3.one * s, hit.Position + Vector3.one * s):ExpandToGrid(4)
			for _, from in rocks do
				terrain:ReplaceMaterial(region, 4, from, to)
			end
			if to == M.Ice then
				terrain:ReplaceMaterial(region, 4, M.Snow, M.Glacier)
			end
		end
		if k % 25 == 0 then
			yield()
		end
	end
end

local function carveGrandCave(map: Heightmap.Map, yield: () -> (), G: any, key: string)
	if not G then
		return
	end
	local M = map.cfg.MOUNTAIN
	local terrain = workspace.Terrain
	local rs = findSurfaceR(map, G.ANGLE, G.Y)
	if not rs then
		return
	end
	local out = Vector3.new(cos(G.ANGLE), 0, sin(G.ANGLE))
	local side = Vector3.new(-out.Z, 0, out.X)
	local face = Vector3.new(M.X, G.Y, M.Z) + out * rs
	local C = face - out * G.INSET
	local floorY = C.Y - G.HEIGHT * 0.55
	local rng = Random.new(map.cfg.SEED + 777)
	local columns = {}
	for k = 1, G.COLUMNS do
		local u, v = rng:NextNumber(-0.65, 0.65), rng:NextNumber(-0.7, 0.3)
		if math.abs(u) > 0.2 then -- al centro il corridoio dall'apertura al trono resta libero
			table.insert(columns, { p = C + side * u * G.WIDTH + out * v * G.DEPTH, r = rng:NextNumber(6, 13) })
		end
	end
	local seed = rng:NextNumber(0, 100)
	-- distanza "normalizzata" dalla sala: < 1 dentro
	local function inside(p: Vector3): number
		local d = p - C
		local x, y, z = d:Dot(side) / G.WIDTH, d.Y / G.HEIGHT, d:Dot(out) / G.DEPTH
		if G.OPEN and y > 0 then
			y *= 0.4 -- cratere: la sala sale fino a sfondare il pendio
		end
		local n = noise(p.X / 45 + seed, p.Y / 45, p.Z / 45) * 0.14
		return math.sqrt(x * x + y * y + z * z) + n
	end
	local reach = math.max(G.WIDTH, G.DEPTH) + G.SHELL + 8
	local lo = C - Vector3.new(reach, G.HEIGHT + G.SHELL + 8, reach)
	local hi = C + Vector3.new(reach, (if G.OPEN then G.HEIGHT * 2.5 else G.HEIGHT) + G.SHELL + 8, reach)
	local region = Region3.new(lo, hi):ExpandToGrid(4)
	local mats, occs = terrain:ReadVoxels(region, 4)
	local size = mats.Size
	local origin = region.CFrame.Position - region.Size / 2
	local ICE, SNOW, AIRM = Enum.Material.Ice, Enum.Material.Snow, Enum.Material.Air
	local shellK = 1 + G.SHELL / math.min(G.WIDTH, G.HEIGHT, G.DEPTH)
	for ix = 1, size.X do
		local x = origin.X + (ix - 0.5) * 4
		for iz = 1, size.Z do
			local z = origin.Z + (iz - 0.5) * 4
			local top = sampleH(map, x, z)
			for iy = 1, size.Y do
				local y = origin.Y + (iy - 0.5) * 4
				local p = Vector3.new(x, y, z)
				local k = inside(p)
				local inMountain = top > y + 2
				if k < 1 then
					-- terrazze del pavimento (gradini da 6 studs che salgono verso il fondo)
					local back = -(p - C):Dot(out) / G.DEPTH
					local step = math.floor(math.max(0, back + 0.2) * 4) * 6
					local floorHere = floorY + step + noise(x / 30, z / 30, seed) * 3
					local column = false
					for _, c in columns do
						local dx, dz = x - c.p.X, z - c.p.Z
						if dx * dx + dz * dz < c.r * c.r * (1 + 0.25 * math.sin(y / 9)) then
							column = true
						end
					end
					if y < floorHere and (inMountain or (p - face):Dot(out) < 25) then -- niente ripiano sospeso fuori dalla parete
						mats[ix][iy][iz] = if y > floorHere - 6 then SNOW else ICE
						occs[ix][iy][iz] = 1
					elseif column then
						mats[ix][iy][iz] = ICE
						occs[ix][iy][iz] = 1
					else
						mats[ix][iy][iz] = AIRM
						occs[ix][iy][iz] = 0
					end
				elseif k < shellK and inMountain and (p - face):Dot(out) < -14 then -- il bordo fuori resta roccia
					mats[ix][iy][iz] = ICE
					occs[ix][iy][iz] = 1
				end
			end
		end
		if ix % 6 == 0 then
			yield()
		end
	end
	terrain:WriteVoxels(region, 4, mats, occs)
	iceFade(face, out, side, G, rng, yield)
	map.features[key] = {
		center = toPoint(C),
		floor = floorY,
		face = toPoint(face),
		out = { x = out.X, z = out.Z },
		width = G.WIDTH,
		height = G.HEIGHT,
		depth = G.DEPTH,
	}
	table.insert(map.features.iceCaves, { x = C.X, y = floorY, z = C.Z, cy = C.Y, r = G.WIDTH })
	-- niente pance di roccia davanti o sopra l'apertura (prima un tetto la copriva a meta')
	map.features.keepOut = map.features.keepOut or {}
	table.insert(map.features.keepOut, { x = face.X, y = face.Y - G.HEIGHT, z = face.Z, keepOut = G.WIDTH * 1.6 })
	table.insert(map.features.keepOut, { x = face.X, y = face.Y + G.HEIGHT, z = face.Z, keepOut = G.WIDTH * 1.6 })
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
	carveTunnelRooms(map, terrain, helix, rng, yield)
	carveLoops(map, terrain, helix, rng, yield)
	progress("Catacomba segreta", 0.6)
	carveCatacomb(map, terrain, helix[1], yield)
	progress("Grotte di ghiaccio", 0.8)
	carveIceCaves(map, terrain, rng, yield)
	for _, GC in map.cfg.CAVES.GLACIER_CAVES or {} do
		carveGlacierCave(map, terrain, rng, yield, GC)
	end
	carveChasm(map, terrain, rng, yield)
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
	carveGrandCave(map, yield, map.cfg.CAVES.GRAND, "grandCave")
	carveGrandCave(map, yield, map.cfg.CAVES.CRATER, "craterCave")
	progress("Grotte", 1)
end

return Caves
