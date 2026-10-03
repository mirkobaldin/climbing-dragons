--!strict
-- Ostacoli sulla montagna (qui vengono solo piazzati; il comportamento e' negli script di gioco
-- in ServerScriptService, che li trovano tramite i tag di CollectionService):
--   CrumblingRock  appigli sulle pareti verticali che si sgretolano quando ti aggrappi
--   IcePatch       lastre di ghiaccio scivolose sulle cenge alte del sentiero
--   RockfallSource punti da cui cadono sassi lungo i canaloni sopra il sentiero
--   WindZone       zone di raffiche in quota che ti spingono via dalla parete
--   NoClimb        pareti lisce sui salti alti del sentiero: si superano solo col Rampino

local CollectionService = game:GetService("CollectionService")
local Heightmap = require(script.Parent.Heightmap)

local readf32 = buffer.readf32
local floor, max = math.floor, math.max

local Obstacles = {}

local function tagged(parent: Instance, tag: string, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	for k, v in props do
		(p :: any)[k] = v
	end
	CollectionService:AddTag(p, tag)
	p.Parent = parent
	return p
end

-- Cerca il gradino piu' alto tra una colonna e le vicine: li' c'e' una parete verticale.
-- Restituisce il punto sulla faccia della parete e la normale (verso l'esterno).
local function wallSpot(map: Heightmap.Map, x: number, z: number, rng: Random): (Vector3?, Vector3?)
	local V = map.cfg.VOXEL
	local ix, iz = floor((x - map.minX) / V), floor((z - map.minZ) / V)
	if ix < 1 or iz < 1 or ix >= map.nx - 1 or iz >= map.nz - 1 then
		return nil, nil
	end
	local i = ix + iz * map.nx
	local h = readf32(map.height, i * 4)
	local best, bestDir, bestLow = 0, nil, 0
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local j = (ix + d[1]) + (iz + d[2]) * map.nx
		local drop = h - readf32(map.height, j * 4)
		if drop > best then
			best, bestDir, bestLow = drop, Vector3.new(d[1], 0, d[2]), h - drop
		end
	end
	if best < 8 or not bestDir then
		return nil, nil
	end
	local cx, cz = map.minX + ix * V + V / 2, map.minZ + iz * V + V / 2
	local y = bestLow + 3 + rng:NextNumber() * (best - 6)
	return Vector3.new(cx, y, cz) + bestDir * (V / 2 + 0.6), bestDir
end

local function crumblingRock(parent: Instance, pos: Vector3, normal: Vector3, rng: Random)
	local size = Vector3.new(rng:NextNumber(2.5, 4), rng:NextNumber(1.6, 2.4), 2)
	tagged(parent, "CrumblingRock", {
		Name = "CrumblingRock",
		Size = size,
		CFrame = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, rng:NextNumber(-0.3, 0.3)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(112, 104, 96),
	})
end

function Obstacles.place(map: Heightmap.Map)
	local cfg = map.cfg
	local O = cfg.OBSTACLES
	local M = cfg.MOUNTAIN
	local rng = Random.new(cfg.SEED + 33)
	-- tutte le vecchie (se una generazione si era interrotta ne restavano due, poi tre...)
	for _, old in workspace:GetChildren() do
		if old.Name == "Obstacles" then
			old:Destroy()
		end
	end
	local root = Instance.new("Folder")
	root.Name = "Obstacles"

	-- Appigli friabili: prima sulle pareti dei buchi del sentiero, poi sparsi sulle pareti
	local rocks = Instance.new("Folder")
	rocks.Name = "CrumblingRocks"
	rocks.Parent = root
	local placed = 0
	for _, gap in map.features.gaps do
		if gap.kind == "climb" and gap.to then
			for _ = 1, 4 do
				local pos, normal = wallSpot(map, gap.to.x + rng:NextNumber(-10, 10), gap.to.z + rng:NextNumber(-10, 10), rng)
				if pos and normal then
					crumblingRock(rocks, pos, normal, rng)
					placed += 1
				end
			end
		end
	end
	local tries = 0
	while placed < O.CRUMBLING_ROCKS and tries < O.CRUMBLING_ROCKS * 60 do
		tries += 1
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(80, M.RADIUS * 0.8)
		local x, z = M.X + math.cos(a) * r, M.Z + math.sin(a) * r
		local h = Heightmap.sampleH(map, x, z)
		if h > 250 and h < M.HEIGHT * 0.9 then
			local pos, normal = wallSpot(map, x, z, rng)
			if pos and normal then
				crumblingRock(rocks, pos, normal, rng)
				placed += 1
			end
		end
	end

	-- Strapiombi: pareti che "spanciano", cioe' vengono in fuori salendo (come le falesie di
	-- Arco o i tetti di El Capitan). Una mappa di altezze non puo' averli, quindi li aggiungiamo
	-- nei voxel del terreno vero: una pancia della stessa roccia della parete, con sopra una
	-- cengia (o un dorso ripido) e sotto un soffitto inclinato di ANGLE gradi dalla verticale che rientra fino a
	-- raccordarsi alla parete. Si aggiunge soltanto (mai scavare): niente buchi ne' schegge.
	-- Sotto lo strapiombo ci si stanca molto di piu'.
	local terrain = workspace.Terrain
	local OV = O.OVERHANG
	local V = cfg.VOXEL
	local Zone = Heightmap.Zone
	local protected = { [Zone.PATH] = true, [Zone.SUMMIT] = true, [Zone.LAKE] = true, [Zone.GORGE] = true, [Zone.RIVERBED] = true, [Zone.GLACIER] = true, [Zone.BEACH] = true, [Zone.ICECAP] = true }
	local function zoneAt(x: number, z: number): number
		local ix = math.clamp(floor((x - map.minX) / V), 0, map.nx - 1)
		local iz = math.clamp(floor((z - map.minZ) / V), 0, map.nz - 1)
		return buffer.readu8(map.zone, ix + iz * map.nx)
	end
	-- Parete in un punto: direzione di discesa, piede e ciglio. nil se non e' una parete alta.
	local function cliffAt(x: number, z: number, hint: Vector3?): (Vector3?, Vector3?, number?, number?)
		local n = hint
		if not n then
			local gx = Heightmap.sampleH(map, x + V, z) - Heightmap.sampleH(map, x - V, z)
			local gz = Heightmap.sampleH(map, x, z + V) - Heightmap.sampleH(map, x, z - V)
			local g = Vector3.new(-gx, 0, -gz)
			if g.Magnitude < 0.5 then
				return nil, nil, nil, nil
			end
			n = g.Unit
		end
		local dir = n :: Vector3
		-- cerca lungo la discesa il tratto piu' ripido e misura il salto
		local top, base = -math.huge, math.huge
		local faceT, steepest = 0, 0
		local prev = Heightmap.sampleH(map, x - dir.X * 28, z - dir.Z * 28)
		top = prev
		for t = -24, 28, 4 do
			local h = Heightmap.sampleH(map, x + dir.X * t, z + dir.Z * t)
			if prev - h > steepest then
				steepest, faceT = prev - h, t - 2
			end
			prev = h
		end
		if steepest < 10 then
			return nil, nil, nil, nil
		end
		-- misura tutta la parete: si scende e si sale finche' il pendio resta ripido (le pareti
		-- del bastione sono alte centinaia di studs, non pochi metri)
		local function march(sign: number): number
			local t = faceT
			local h = Heightmap.sampleH(map, x + dir.X * t, z + dir.Z * t)
			for _ = 1, 50 do
				local nt = t + sign * 6
				local nh = Heightmap.sampleH(map, x + dir.X * nt, z + dir.Z * nt)
				if (h - nh) * sign < 5 then -- meno di ~40 gradi: la parete e' finita
					break
				end
				t, h = nt, nh
			end
			return h
		end
		top = march(-1)
		base = march(1)
		if top - base < OV.MIN_CLIFF then
			return nil, nil, nil, nil
		end
		return Vector3.new(x + dir.X * faceT, base, z + dir.Z * faceT), dir, base, top
	end
	-- punti da non murare: imbocchi delle gallerie e finestre delle grotte
	local openings: { any } = {}
	for _, key in { "caveEntrance", "caveExit", "caveWindow", "catacombShaft", "niche" } do
		local p = (map.features :: any)[key]
		if type(p) == "table" and type(p.x) == "number" then
			table.insert(openings, p)
		end
	end
	for _, key in { "caveEntrances", "secretExits", "iceCaves" } do
		for _, p in (map.features :: any)[key] or {} do
			if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then
				table.insert(openings, p)
			end
		end
	end
	local snowY = M.HEIGHT * cfg.BIOMES.SNOW_LINE
	local ROCKS = {
		[Enum.Material.Rock] = true, [Enum.Material.Slate] = true, [Enum.Material.Basalt] = true,
		[Enum.Material.Sandstone] = true, [Enum.Material.Limestone] = true,
	}
	local AIR = Enum.Material.Air
	local function smooth01(s: number): number
		s = math.clamp(s, 0, 1)
		return s * s * (3 - 2 * s)
	end
	-- Aggiunge una pancia strapiombante alla parete. Non e' un pezzo appiccicato: e' la parete
	-- stessa che si gonfia. A ogni quota si parte da dove sta la roccia vera e la si sposta in
	-- fuori di un profilo morbido:
	--   sotto  la roccia si stacca dalla parete senza spigolo (tangente nulla), a meta' sporge
	--          di ANGLE gradi dalla verticale, al ciglio si arrotonda;
	--   sopra  rientra piano nella parete per un tratto CROWN volte la sporgenza.
	-- E' sempre larga almeno WIDTH_RATIO volte quanto sporge: cosi' sembra un rigonfiamento
	-- della parete e non un naso. Si aggiunge soltanto roccia vicino alla superficie.
	local rejected: { [string]: number } = {}
	local function reject(why: string): boolean
		rejected[why] = (rejected[why] or 0) + 1
		return false
	end
	local function bulge(x: number, z: number, aroundY: number?): boolean
		local face, n, base, top = cliffAt(x, z, nil)
		if not face or not n or not base or not top then
			return reject("niente parete")
		end
		local tangent = Vector3.new(-n.Z, 0, n.X)
		local cliff = top - base
		local scale = math.clamp(cliff / 120, 1, OV.MAX_SCALE)
		local depth = OV.MAX_DEPTH * math.sqrt(scale) * rng:NextNumber(0.55, 1)
		local width = math.max(rng:NextNumber(OV.WIDTH[1], OV.WIDTH[2]) * math.sqrt(scale), depth * OV.WIDTH_RATIO)
		width = math.min(width, OV.WIDTH[2] * 1.6)
		-- con la curva a S la pendenza massima e' 1.5 volte la media: il ventre e' alto quanto serve
		-- perche' nel mezzo lo strapiombo sia esattamente di ANGLE gradi
		local steep = math.tan(math.rad(rng:NextNumber(OV.ANGLE[1], OV.ANGLE[2])))
		-- Lo strapiombo si misura rispetto alla verticale, non alla parete: se la parete sotto
		-- e' inclinata all'indietro (lean studs in dentro per ogni stud in su) la pancia deve
		-- venire in fuori di piu' per ogni stud, altrimenti la parete se la "mangia" e resta
		-- appena un gradino. Si misura la parete al centro, 40 studs sotto la quota scelta.
		local function wallU(c: number, y: number): number?
			local fx, fz = face.X + tangent.X * c, face.Z + tangent.Z * c
			local u = 0
			if Heightmap.sampleH(map, fx, fz) >= y then
				while u < 260 and Heightmap.sampleH(map, fx + n.X * (u + 2), fz + n.Z * (u + 2)) >= y do
					u += 2
				end
			else
				while u > -260 and Heightmap.sampleH(map, fx + n.X * u, fz + n.Z * u) < y do
					u -= 2
				end
			end
			return if u < 260 and u > -260 then u else nil
		end
		local probeY = aroundY or (base + top) / 2
		local u1, u2 = wallU(0, probeY), wallU(0, probeY - 40)
		local lean = if u1 and u2 then math.clamp((u2 - u1) / 40, 0, 2) else 0
		local under = 1.5 * depth / (steep + lean)
		if cliff < under + 20 then
			return reject("parete bassa")
		end
		local lowRoof, highRoof = base + under, math.max(base + under, top - depth * 0.4)
		local roofY = if aroundY
			then math.clamp(aroundY, lowRoof, highRoof)
			else lowRoof + (highRoof - lowRoof) * rng:NextNumber(0.15, 0.85)
		local over = math.max(depth * rng:NextNumber(OV.CROWN[1], OV.CROWN[2]), depth)
		local seed = rng:NextNumber(0, 100)
		local yMin, yMax = roofY - under - V, roofY + over + V

		-- Dove sta la parete, colonna per colonna e quota per quota (coordinata u lungo la
		-- normale, positiva verso l'esterno). false dove a quella quota non c'e' parete.
		local cols = floor(width / V)
		local rows = floor((yMax - yMin) / V) + 1
		local wall: { { any } } = table.create(cols + 1)
		local lo, hi = math.huge, -math.huge
		local valid, total = 0, 0
		for ci = 0, cols do
			local c = -width / 2 + ci * V
			local fx, fz = face.X + tangent.X * c, face.Z + tangent.Z * c
			local col = table.create(rows, false)
			local u = 0
			for ri = 1, rows do
				local y = yMin + (ri - 1) * V
				if Heightmap.sampleH(map, fx + n.X * u, fz + n.Z * u) >= y then
					while u < 260 and Heightmap.sampleH(map, fx + n.X * (u + 2), fz + n.Z * (u + 2)) >= y do
						u += 2
					end
				else
					while u > -260 and Heightmap.sampleH(map, fx + n.X * u, fz + n.Z * u) < y do
						u -= 2
					end
				end
				total += 1
				if u < 260 and u > -260 then
					col[ri] = u
					valid += 1
					lo, hi = math.min(lo, u), max(hi, u)
				end
			end
			wall[ci + 1] = col
		end
		if valid < total * 0.7 then
			return reject("parete irregolare")
		end
		-- parete ammorbidita lungo la parete: segue la roccia senza copiarne ogni dentino
		local smoothWall: { { any } } = table.create(cols + 1)
		for ci = 1, cols + 1 do
			local col = table.create(rows, false)
			for ri = 1, rows do
				if wall[ci][ri] then
					local sum, cnt = 0, 0
					for k = max(1, ci - 3), math.min(cols + 1, ci + 3) do
						local v = wall[k][ri]
						if v then
							sum += v
							cnt += 1
						end
					end
					col[ri] = sum / cnt
				end
			end
			smoothWall[ci] = col
		end

		-- niente pance sopra il sentiero, la vetta, l'acqua o gli imbocchi delle grotte
		local roofRow = floor((roofY - yMin) / V) + 1
		for ci = 0, cols, 3 do
			local u0 = wall[ci + 1][roofRow]
			if u0 then
				local c = -width / 2 + ci * V
				for u = u0 - 8, u0 + depth * 1.2, 10 do
					if protected[zoneAt(face.X + tangent.X * c + n.X * u, face.Z + tangent.Z * c + n.Z * u)] then
						return reject("zona protetta")
					end
				end
			end
		end
		local reach = width / 2 + depth * 1.2 + 24 + max(hi, -lo)
		for _, p in openings do
			if p.y > yMin - 24 and p.y < yMax + 24 and Vector3.new(p.x - face.X, 0, p.z - face.Z).Magnitude < reach then
				return reject("grotta vicina")
			end
		end

		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, c in { -width / 2, width / 2 } do
			for _, u in { lo - 8, hi + depth * 1.25 + 8 } do
				local px, pz = face.X + tangent.X * c + n.X * u, face.Z + tangent.Z * c + n.Z * u
				minX, maxX = math.min(minX, px), max(maxX, px)
				minZ, maxZ = math.min(minZ, pz), max(maxZ, pz)
			end
		end
		local region = Region3.new(Vector3.new(minX, yMin, minZ), Vector3.new(maxX, yMax, maxZ)):ExpandToGrid(V)
		local ch = terrain:ReadVoxelChannels(region, V, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
		local mats, occ, liq = ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy
		-- ReadVoxelChannels (a differenza di ReadVoxels) non dice quanto e' grande la griglia
		local cells = region.Size / V
		local size = Vector3.new(math.round(cells.X), math.round(cells.Y), math.round(cells.Z))
		local origin = region.CFrame.Position - region.Size / 2

		-- la roccia della pancia e' quella piu' comune della parete li' intorno
		local tally: { [Enum.Material]: number } = {}
		for i = 1, size.X, 3 do
			for j = 1, size.Y, 3 do
				for k = 1, size.Z, 3 do
					local m = mats[i][j][k]
					if ROCKS[m] then
						tally[m] = (tally[m] or 0) + 1
					end
				end
			end
		end
		local rock, most = Enum.Material.Rock, 0
		for m, count in tally do
			if count > most then
				rock, most = m, count
			end
		end

		local changed = 0
		for i = 1, size.X do
			local wx = origin.X + (i - 0.5) * V
			local matsX, occX, liqX = mats[i], occ[i], liq[i]
			for k = 1, size.Z do
				local wz = origin.Z + (k - 0.5) * V
				local dx, dz = wx - face.X, wz - face.Z
				local c = dx * tangent.X + dz * tangent.Z
				if math.abs(c) >= width / 2 or protected[zoneAt(wx, wz)] then
					continue
				end
				local ci = floor((c + width / 2) / V + 0.5) + 1
				local rawCol, smCol = wall[ci], smoothWall[ci]
				if not rawCol or not smCol then
					continue
				end
				local u = dx * n.X + dz * n.Z
				-- ai lati la pancia si assottiglia fino a sparire nella parete
				local side = smooth01(1 - math.abs(c) / (width / 2))
				for j = 1, size.Y do
					local wy = origin.Y + (j - 0.5) * V
					local ri = floor((wy - yMin) / V + 0.5) + 1
					local raw, sm = rawCol[ri], smCol[ri]
					-- solo vicino alla superficie: mai riempire gallerie o grotte dentro la roccia
					if not raw or not sm or u < raw - 6 then
						continue
					end
					local t = wy - roofY
					local prof = if t <= 0 then smooth01((t + under) / under) else smooth01(1 - t / over)
					if prof <= 0 then
						continue
					end
					local out = depth * prof * side * (1 + 0.18 * math.noise(wx / 45, wy / 45, wz / 45 + seed))
					local o = math.min((sm + out - u) / V + 0.5, 1)
					-- sotto un quinto di voxel Roblox estrapola la superficie fuori dalla cella e
					-- ne esce una lama piatta sospesa: meglio niente
					if o > 0.2 and o > occX[j][k] and liqX[j][k] <= 0 then
						if matsX[j][k] == AIR or occX[j][k] <= 0 then
							matsX[j][k] = rock
						end
						occX[j][k] = o
						changed += 1
					end
				end
			end
		end
		if changed < 80 then
			return reject("niente da aggiungere")
		end
		terrain:WriteVoxelChannels(region, V, { SolidMaterial = mats, SolidOccupancy = occ, LiquidOccupancy = liq })
		task.wait() -- lascia respirare Studio tra una pancia e l'altra
		local lip = wall[floor(cols / 2) + 1][roofRow] or 0
		table.insert(map.features.overhangs, {
			x = face.X + n.X * lip, z = face.Z + n.Z * lip, base = base, top = top, roof = roofY,
			nx = n.X, nz = n.Z, width = width, depth = depth, height = under + over, under = under,
		})
		return true
	end

	map.features.overhangs = {}
	local overhangs, tries = 0, 0
	-- prima sui monoliti (le pareti piu' alte), poi sparsi su tutta la montagna
	for _, mo in map.features.monoliths or {} do
		for _ = 1, OV.PER_MONOLITH * 6 do
			local a = rng:NextNumber(0, 2 * math.pi)
			local r = mo.radius * rng:NextNumber(0.8, 1.0)
			if bulge(mo.x + math.cos(a) * r, mo.z + math.sin(a) * r) then
				overhangs += 1
			end
		end
	end
	-- Poi sparsi su tutta la montagna, con la quota scelta a caso in modo uniforme: prima si
	-- sceglieva un punto a caso sulla pianta, e siccome la cima vista dall'alto e' piccola lassu'
	-- non ne finiva quasi nessuno.
	while overhangs < OV.COUNT and tries < OV.COUNT * 60 do
		tries += 1
		local y = rng:NextNumber(OV.MIN_Y, M.HEIGHT * OV.MAX_Y_FRAC)
		local theta = rng:NextNumber(0, 2 * math.pi)
		local r = Heightmap.findSurfaceR(map, theta, y)
		if r and bulge(M.X + math.cos(theta) * r, M.Z + math.sin(theta) * r, y) then
			overhangs += 1
		end
	end
	local why = {}
	for k, v in rejected do
		table.insert(why, k .. " " .. v)
	end
	print(string.format("[MapGen] Strapiombi: %d pance di roccia (%d tentativi; scartati: %s)", overhangs, tries, table.concat(why, ", ")))

	-- Pareti lisce (tag "NoClimb") sui salti alti del sentiero: non si scalano, serve il
	-- Rampino. Una lastra di ghiaccio vivo appoggiata alla roccia + un anello d'aggancio in cima.
	local smooth = Instance.new("Folder")
	smooth.Name = "SmoothWalls"
	smooth.Parent = root
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	for index, gap in map.features.gaps do
		local def = cfg.PATH.GAPS[index]
		if gap.kind ~= "climb" or not gap.from or not gap.to or not def or def.at < O.SMOOTH_WALLS_FROM then
			continue
		end
		local out = Vector3.new(gap.to.x - M.X, 0, gap.to.z - M.Z).Unit
		local sum, normalSum, hits = Vector3.zero, Vector3.zero, 0
		local lowY, highY = math.min(gap.from.y, gap.to.y) - 6, gap.to.y - 1
		for y = lowY, highY, 4 do
			for _, side in { -8, 0, 8 } do
				local across = Vector3.new(-out.Z, 0, out.X) * side
				local origin = Vector3.new(gap.to.x, y, gap.to.z) + out * 40 + across
				local hit = workspace:Raycast(origin, -out * 90, terrainOnly)
				if hit and hit.Normal.Y < 0.6 then
					sum += hit.Position
					normalSum += Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
					hits += 1
				end
			end
		end
		if hits >= 4 and normalSum.Magnitude > 0.1 then
			local center = sum / hits
			local n = normalSum.Unit
			local height = highY - lowY + 8
			local mid = Vector3.new(center.X, (lowY + highY) / 2, center.Z) + n * 0.8
			-- cascata di ghiaccio: lastre spesse e irregolari, un po' storte, con stalattiti
			local faceCf = CFrame.lookAt(mid, mid + n)
			for k = 1, 5 do
				local w = rng:NextNumber(10, 16)
				tagged(smooth, "NoClimb", {
					Name = "PareteLiscia",
					Size = Vector3.new(w, height * rng:NextNumber(0.75, 1), rng:NextNumber(2.5, 4.5)),
					CFrame = faceCf * CFrame.new(-17 + (k - 0.5) * 34 / 5, rng:NextNumber(-3, 3), rng:NextNumber(-0.8, 0.4))
						* CFrame.Angles(rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.04, 0.04)),
					Material = Enum.Material.Glacier,
					Color = Color3.fromRGB(150 + k * 6, 200 + k * 3, 225),
				})
			end
			for k = 1, 9 do
				local len = rng:NextNumber(3, 9)
				local icicle = Instance.new("WedgePart")
				icicle.Name = "Stalattite"
				icicle.Anchored = true
				icicle.CanCollide = false
				icicle.Material = Enum.Material.Ice
				icicle.Color = Color3.fromRGB(200, 232, 245)
				icicle.Size = Vector3.new(rng:NextNumber(0.8, 1.6), len, rng:NextNumber(0.8, 1.4))
				icicle.CFrame = faceCf * CFrame.new(rng:NextNumber(-16, 16), height / 2 - len / 2 + 1, -2.6) * CFrame.Angles(math.pi, 0, 0)
				icicle.Parent = smooth
			end
			local ring = tagged(smooth, "GrappleAnchor", {
				Name = "AnelloAggancio",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 3, 3),
				CFrame = CFrame.lookAt(mid + Vector3.new(0, height / 2 - 2, 0) + n * 1.4, mid + Vector3.new(0, height / 2 - 2, 0) + n * 3)
					* CFrame.Angles(0, math.pi / 2, 0),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(200, 170, 90),
			})
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 210, 120)
			glow.Range = 14
			glow.Brightness = 1.5
			glow.Parent = ring
		end
	end

	-- Ghiaccio sul sentiero sopra la linea della neve
	local ice = Instance.new("Folder")
	ice.Name = "IcePatches"
	ice.Parent = root
	local count = 0
	for k, p in map.features.path do
		if p.y > snowY and k % 2 == 0 and count < O.ICE_PATCHES then
			count += 1
			tagged(ice, "IcePatch", {
				Name = "IcePatch",
				Size = Vector3.new(rng:NextNumber(5, 8), 0.4, rng:NextNumber(5, 8)),
				CFrame = CFrame.new(p.x, p.y + 0.2, p.z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Material = Enum.Material.Ice,
				Color = Color3.fromRGB(190, 225, 240),
				Transparency = 0.15,
				CustomPhysicalProperties = PhysicalProperties.new(0.9, 0, 0.3, 100, 1),
			})
		end
	end

	-- Frane: sorgenti sopra il sentiero, in salita verso la vetta
	local falls = Instance.new("Folder")
	falls.Name = "RockfallSources"
	falls.Parent = root
	local path = map.features.path
	for k = 1, O.ROCKFALL_SOURCES do
		local p = path[math.clamp(floor(#path * (k - 0.5) / O.ROCKFALL_SOURCES), 1, #path)]
		if p and p.y > 300 then
			local theta = math.atan2(p.z - M.Z, p.x - M.X)
			local r = Heightmap.findSurfaceR(map, theta, p.y + 120)
			if r then
				local pos = Vector3.new(M.X + math.cos(theta) * (r + 6), p.y + 126, M.Z + math.sin(theta) * (r + 6))
				local src = tagged(falls, "RockfallSource", {
					Name = "RockfallSource",
					Size = Vector3.new(4, 4, 4),
					Position = pos,
					Transparency = 1,
					CanCollide = false,
					CanQuery = false,
				})
				src:SetAttribute("Interval", rng:NextNumber(8, 18))
				src:SetAttribute("Target", Vector3.new(p.x, p.y, p.z))
			end
		end
	end

	-- Raffiche di vento in quota
	local wind = Instance.new("Folder")
	wind.Name = "WindZones"
	wind.Parent = root
	local high = {}
	for _, p in path do
		if p.y > M.HEIGHT * 0.45 then
			table.insert(high, p)
		end
	end
	for k = 1, O.WIND_ZONES do
		local p = high[math.clamp(floor(#high * (k - 0.5) / O.WIND_ZONES), 1, max(#high, 1))]
		if p then
			local outward = Vector3.new(p.x - M.X, 0, p.z - M.Z).Unit
			local zone = tagged(wind, "WindZone", {
				Name = "WindZone",
				Size = Vector3.new(180, 100, 180),
				Position = Vector3.new(p.x, p.y + 30, p.z),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			})
			zone:SetAttribute("Strength", rng:NextNumber(60, 120) * (p.y / M.HEIGHT + 0.5))
			zone:SetAttribute("Direction", outward)
		end
	end

	root.Parent = workspace
end

return Obstacles
