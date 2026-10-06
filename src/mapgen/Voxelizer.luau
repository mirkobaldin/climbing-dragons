--!strict
-- Scrive la heightmap nel Terrain di Roblox a blocchi di 64x64 studs.
-- Per ogni blocco: il nucleo di roccia profondo con FillBlock (veloce, nativo), poi solo la
-- fascia vicino alla superficie con WriteVoxels, con occupancy parziale per pendii lisci.
--
-- Montagna vuota: sotto le zone alte la roccia piena scende solo fino a HOLLOW.SHELL studs
-- sotto la colonna piu' bassa del blocco e dei blocchi vicini; sotto e' aria. Il guscio e'
-- chiuso da ogni lato (nessuna parete si affaccia sul vuoto) e il terreno da caricare cala
-- di molto: prima erano ~486 milioni di celle, quasi tutte roccia mai vista dentro la montagna.
-- Le grotte che passano nella parte vuota si portano dietro un rivestimento (vedi Caves).

local Heightmap = require(script.Parent.Heightmap)

local readf32, readu8 = buffer.readf32, buffer.readu8
local floor, ceil, min, max, clamp = math.floor, math.ceil, math.min, math.max, math.clamp

local Voxelizer = {}

local CHUNK = 16 -- colonne per lato (16 x 4 studs = 64 studs)
local MIN_FILL = 0.2 -- sotto questo riempimento il voxel diventa aria vuota (vedi writeChunk)

local function writeChunk(map: Heightmap.Map, terrain: Terrain, mats: { Enum.Material }, ix0: number, iz0: number, hollowTop: number)
	local cfg = map.cfg
	local V = cfg.VOXEL
	local BOTTOM = cfg.BOTTOM_Y
	local AIR, ROCK = Enum.Material.Air, Enum.Material.Rock
	local sx, sz = min(CHUNK, map.nx - ix0), min(CHUNK, map.nz - iz0)

	-- Intervallo verticale da scrivere
	local minSolid, maxTop = math.huge, -math.huge
	for dz = 0, sz - 1 do
		for dx = 0, sx - 1 do
			local i = (ix0 + dx) + (iz0 + dz) * map.nx
			local h, w = readf32(map.height, i * 4), readf32(map.water, i * 4)
			minSolid = min(minSolid, h)
			maxTop = max(maxTop, h, w)
		end
	end
	local coreTop = max(BOTTOM, floor((minSolid - 16) / V) * V)
	local top = ceil(maxTop / V) * V + V
	local x0, z0 = map.minX + ix0 * V, map.minZ + iz0 * V

	-- nucleo di roccia: dal fondo, oppure (montagna vuota) solo dal tetto della cavita'
	local coreBottom = max(BOTTOM, min(hollowTop, coreTop))
	if coreTop > coreBottom then
		terrain:FillBlock(
			CFrame.new(x0 + sx * V / 2, (coreBottom + coreTop) / 2, z0 + sz * V / 2),
			Vector3.new(sx * V, coreTop - coreBottom, sz * V),
			ROCK
		)
	end

	local ny = (top - coreTop) // V
	local materials = table.create(sx)
	local occupancy = table.create(sx)
	local liquid = table.create(sx)
	for dx = 1, sx do
		local mx, ox, lx = table.create(ny), table.create(ny), table.create(ny)
		for iy = 1, ny do
			mx[iy] = table.create(sz)
			ox[iy] = table.create(sz)
			lx[iy] = table.create(sz)
		end
		materials[dx], occupancy[dx], liquid[dx] = mx, ox, lx
	end

	for dz = 1, sz do
		for dx = 1, sx do
			local i = (ix0 + dx - 1) + (iz0 + dz - 1) * map.nx
			local h, w = readf32(map.height, i * 4), readf32(map.water, i * 4)
			local surf, sub = mats[readu8(map.surf, i)], mats[readu8(map.sub, i)]
			-- quota della colonna vicina piu' bassa: i voxel sopra quella quota si affacciano di lato
			-- sul vuoto (sono la faccia di una parete) e prendono il materiale di superficie. Prima
			-- solo i primi 5 studs sotto la cima lo avevano e le pareti innevate restavano roccia.
			local gx, gz = ix0 + dx - 1, iz0 + dz - 1
			local hmin = h
			if gx > 0 then hmin = min(hmin, readf32(map.height, (i - 1) * 4)) end
			if gx < map.nx - 1 then hmin = min(hmin, readf32(map.height, (i + 1) * 4)) end
			if gz > 0 then hmin = min(hmin, readf32(map.height, (i - map.nx) * 4)) end
			if gz < map.nz - 1 then hmin = min(hmin, readf32(map.height, (i + map.nx) * 4)) end
			-- anche in diagonale: sui fronti alti e frastagliati (es. il ghiacciaio della grotta) la
			-- faccia restava roccia a righe verticali
			if gx > 0 and gz > 0 then hmin = min(hmin, readf32(map.height, (i - 1 - map.nx) * 4)) end
			if gx < map.nx - 1 and gz > 0 then hmin = min(hmin, readf32(map.height, (i + 1 - map.nx) * 4)) end
			if gx > 0 and gz < map.nz - 1 then hmin = min(hmin, readf32(map.height, (i - 1 + map.nx) * 4)) end
			if gx < map.nx - 1 and gz < map.nz - 1 then hmin = min(hmin, readf32(map.height, (i + 1 + map.nx) * 4)) end
			local mx, ox, lx = materials[dx], occupancy[dx], liquid[dx]
			-- Un voxel con riempimento appena sopra zero e aria tutt'attorno e' veleno: Roblox
			-- cerca la superficie dove il riempimento vale 0.5 e, estrapolando da 0.05, la
			-- piazza decine di studs fuori dal voxel. Ne escono le lame piatte sospese in aria.
			-- Quindi: o il voxel e' pieno almeno per un quinto, o e' aria vuota, mai vie di mezzo.
			--
			-- Acqua: ogni voxel ha due canali separati, la roccia e l'acqua ("shorelines"). La
			-- riva resta liscia come il resto del terreno e l'acqua riempie la parte vuota dello
			-- stesso voxel. Prima un voxel era o roccia o acqua: sulla riva di una gola la linea
			-- dell'acqua seguiva la griglia a scalini di 4 studs e da sopra sembrava una sega.
			-- Il pelo dell'acqua e' agganciato al bordo del voxel e l'acqua e' sempre piena,
			-- cosi' lo specchio di una pozza e' perfettamente piatto.
			local ws = floor(w / V + 0.5) * V
			for iy = 1, ny do
				local yb = coreTop + (iy - 1) * V
				local o = clamp((h - yb) / V, 0, 1)
				local m
				if o > MIN_FILL then
					local depth = h - yb - V / 2
					m = if depth < 5 or yb + V > hmin then surf elseif depth < 14 then sub else ROCK
				else
					m, o = AIR, 0
				end
				mx[iy][dz] = m
				ox[iy][dz] = o
				lx[iy][dz] = if yb < ws and o < 1 then 1 else 0
			end
		end
	end

	terrain:WriteVoxelChannels(
		Region3.new(Vector3.new(x0, coreTop, z0), Vector3.new(x0 + sx * V, top, z0 + sz * V)),
		V,
		{ SolidMaterial = materials, SolidOccupancy = occupancy, LiquidOccupancy = liquid }
	)
end

-- Oceano aperto oltre i bordi della mappa: una lastra d'acqua, cosi' l'orizzonte non finisce di colpo
local function fillOuterOcean(map: Heightmap.Map, terrain: Terrain, yield: () -> ())
	local cfg = map.cfg
	local TILE = 512
	local margin = cfg.OCEAN_MARGIN
	local x0, z0 = map.minX, map.minZ
	local x1, z1 = x0 + cfg.MAP_X, z0 + cfg.MAP_Z
	local depth = 60
	for x = x0 - margin, x1 + margin - TILE, TILE do
		for z = z0 - margin, z1 + margin - TILE, TILE do
			local inside = x >= x0 and x + TILE <= x1 and z >= z0 and z + TILE <= z1
			if not inside then
				terrain:FillBlock(
					CFrame.new(x + TILE / 2, cfg.WATER_LEVEL - depth / 2, z + TILE / 2),
					Vector3.new(TILE, depth, TILE),
					Enum.Material.Water
				)
				yield()
			end
		end
	end
end

function Voxelizer.write(map: Heightmap.Map, yield: () -> (), progress: (string, number) -> ())
	local terrain = workspace.Terrain
	local mats = {}
	for code, name in Heightmap.MATERIALS do
		mats[code] = (Enum.Material :: any)[name]
	end

	local cxN, czN = ceil(map.nx / CHUNK), ceil(map.nz / CHUNK)
	local total = cxN * czN
	-- quota minima del suolo per blocco, poi il tetto della cavita' (minimo sui blocchi vicini)
	local H = map.cfg.HOLLOW
	local lowest = table.create(cxN * czN, 0)
	for cz = 0, czN - 1 do
		for cx = 0, cxN - 1 do
			local m = math.huge
			for iz = cz * CHUNK, min(map.nz, (cz + 1) * CHUNK) - 1 do
				for ix = cx * CHUNK, min(map.nx, (cx + 1) * CHUNK) - 1 do
					local i = ix + iz * map.nx
					m = min(m, readf32(map.height, i * 4))
				end
			end
			lowest[cx + cz * cxN + 1] = m
		end
	end
	local tops = table.create(cxN * czN, -math.huge)
	for cz = 0, czN - 1 do
		for cx = 0, cxN - 1 do
			local m = math.huge
			for dz = -1, 1 do
				for dx = -1, 1 do
					local x, z = clamp(cx + dx, 0, cxN - 1), clamp(cz + dz, 0, czN - 1)
					m = min(m, lowest[x + z * cxN + 1])
				end
			end
			local t = if H then floor((m - H.SHELL) / map.cfg.VOXEL) * map.cfg.VOXEL else -math.huge
			tops[cx + cz * cxN + 1] = if H and t > H.MIN_Y then t else -math.huge
		end
	end
	map.features.hollow = { chunk = CHUNK * map.cfg.VOXEL, nx = cxN, nz = czN, tops = tops }
	for cz = 0, czN - 1 do
		for cx = 0, cxN - 1 do
			writeChunk(map, terrain, mats, cx * CHUNK, cz * CHUNK, tops[cx + cz * cxN + 1])
			yield()
		end
		progress("Scrittura voxel", (cz + 1) * cxN / total)
	end
	fillOuterOcean(map, terrain, yield)
end

return Voxelizer
