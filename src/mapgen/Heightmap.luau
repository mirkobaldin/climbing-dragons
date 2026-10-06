--!strict
-- Costruisce la heightmap dell'isola: altezza del suolo, livello dell'acqua, zone e materiali
-- per ogni colonna di voxel (4x4 studs). E' solo matematica: non tocca il Terrain,
-- cosi' la si puo' testare anche fuori da Roblox Studio.

local Noise = require(script.Parent.Noise)

local fbm, ridged, smoothstep, lerp = Noise.fbm, Noise.ridged, Noise.smoothstep, Noise.lerp
local noise = math.noise
local abs, floor, ceil, max, min, sqrt = math.abs, math.floor, math.ceil, math.max, math.min, math.sqrt
local sin, cos, atan2, clamp = math.sin, math.cos, math.atan2, math.clamp
local readf32, writef32 = buffer.readf32, buffer.writef32
local readu8, writeu8 = buffer.readu8, buffer.writeu8

local Heightmap = {}

Heightmap.NO_WATER = -10000

Heightmap.Zone = {
	NATURAL = 0,
	HUB = 1,
	RIVERBED = 2,
	RIVERBANK = 3,
	LAKE = 4,
	GORGE = 5,
	GORGE_WALL = 6,
	PATH = 7,
	SUMMIT = 8,
	POOL = 9,
	RAPIDS = 10, -- tratto ripido del torrente: letto di roccia, schiuma fatta di particelle
	ROAD = 11, -- strada lastricata dalla base alla montagna
	BEACH = 12, -- spiaggia del lago grande
	GLACIER = 13, -- ghiacciai, seraccate e crepacci
	MORAINE = 14, -- cordoni di detriti ai lati dei ghiacciai
	ICECAP = 15, -- ghiaccio sospeso sulle pareti alte, che finisce in una parete di seracchi
	TOXIC = 16, -- valle dei gas tossici (zona del drago Gas)
}
local Zone = Heightmap.Zone

-- Codici materiale (indice in questa lista = codice salvato nel buffer)
Heightmap.MATERIALS = {
	"Grass",
	"LeafyGrass",
	"Ground",
	"Mud",
	"Sand",
	"Sandstone",
	"Rock",
	"Slate",
	"Basalt",
	"Snow",
	"Glacier",
	"Limestone",
	"Cobblestone",
	"Asphalt", -- solo nella valle dei gas: roccia blu-viola (colore in Environment)
	"CrackedLava", -- solo nella valle dei gas: croste che brillano fucsia
}
local GRASS, LEAFY, GROUND, MUD, SAND, SANDSTONE, ROCK, SLATE, BASALT, SNOW, GLACIER, LIMESTONE, COBBLE =
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
local TOXROCK, TOXCRUST = 14, 15

export type Point = { x: number, y: number, z: number }

export type Map = {
	cfg: any,
	nx: number,
	nz: number,
	minX: number,
	minZ: number,
	height: buffer, -- f32: quota del suolo
	water: buffer, -- f32: quota del pelo dell'acqua (NO_WATER se asciutto)
	gully: buffer, -- u8: intensita' dei canaloni d'erosione (0-255)
	zone: buffer, -- u8: Zone.*
	surf: buffer, -- u8: materiale di superficie
	sub: buffer, -- u8: materiale sotto la superficie
	features: { [string]: any },
}

------------------------------------------------------------------------------------------
-- Accesso ai dati
------------------------------------------------------------------------------------------

local function getH(map: Map, i: number): number
	return readf32(map.height, i * 4)
end

local function setH(map: Map, i: number, h: number)
	writef32(map.height, i * 4, h)
end

local function getW(map: Map, i: number): number
	return readf32(map.water, i * 4)
end

local function setW(map: Map, i: number, w: number)
	writef32(map.water, i * 4, w)
end

-- Altezza interpolata in un punto qualsiasi del mondo
function Heightmap.sampleH(map: Map, x: number, z: number): number
	local V = map.cfg.VOXEL
	local fx = clamp((x - map.minX) / V - 0.5, 0, map.nx - 1.001)
	local fz = clamp((z - map.minZ) / V - 0.5, 0, map.nz - 1.001)
	local ix, iz = floor(fx), floor(fz)
	local tx, tz = fx - ix, fz - iz
	local i = ix + iz * map.nx
	local h00, h10 = getH(map, i), getH(map, i + 1)
	local h01, h11 = getH(map, i + map.nx), getH(map, i + map.nx + 1)
	return lerp(lerp(h00, h10, tx), lerp(h01, h11, tx), tz)
end
local sampleH = Heightmap.sampleH

-- Tetto della cavita' interna della montagna in (x, z): sotto questa quota e' aria (vedi
-- Voxelizer, montagna vuota). -math.huge = qui il terreno e' pieno fino in fondo.
function Heightmap.hollowTop(map: Map, x: number, z: number): number
	local h = map.features and map.features.hollow
	if not h then
		return -math.huge
	end
	local cx = floor((x - map.minX) / h.chunk)
	local cz = floor((z - map.minZ) / h.chunk)
	if cx < 0 or cz < 0 or cx >= h.nx or cz >= h.nz then
		return -math.huge
	end
	return h.tops[cx + cz * h.nx + 1]
end

-- Partendo dal centro della montagna e andando verso l'esterno lungo l'angolo theta,
-- restituisce la distanza a cui il suolo scende sotto la quota y (cioe' la parete esterna).
function Heightmap.findSurfaceR(map: Map, theta: number, y: number): number?
	local M = map.cfg.MOUNTAIN
	local c, s = cos(theta), sin(theta)
	local r = 0
	local limit = M.RADIUS * 1.4
	if sampleH(map, M.X, M.Z) < y then
		return nil
	end
	while r < limit do
		if sampleH(map, M.X + c * r, M.Z + s * r) < y then
			local lo, hi = r - 8, r
			for _ = 1, 6 do
				local mid = (lo + hi) / 2
				if sampleH(map, M.X + c * mid, M.Z + s * mid) >= y then
					lo = mid
				else
					hi = mid
				end
			end
			return lo
		end
		r += 8
	end
	return nil
end
local findSurfaceR = Heightmap.findSurfaceR

-- Chiama fn(indice, x, z) per ogni colonna dentro il rettangolo indicato
local function forColumns(map: Map, x0: number, z0: number, x1: number, z1: number, fn: (number, number, number) -> ())
	local V = map.cfg.VOXEL
	local ix0 = max(0, floor((x0 - map.minX) / V))
	local ix1 = min(map.nx - 1, floor((x1 - map.minX) / V))
	local iz0 = max(0, floor((z0 - map.minZ) / V))
	local iz1 = min(map.nz - 1, floor((z1 - map.minZ) / V))
	for iz = iz0, iz1 do
		local z = map.minZ + iz * V + V / 2
		for ix = ix0, ix1 do
			fn(ix + iz * map.nx, map.minX + ix * V + V / 2, z)
		end
	end
end

------------------------------------------------------------------------------------------
-- 1) Forma base: pianura, montagna, colline, pareti a gradoni, piana, baia, costa
------------------------------------------------------------------------------------------

-- Area base: cerchio delle tende (verso il mare) e mezzaluna rialzata a due livelli verso la
-- montagna (cabine sul primo livello, chalet sul secondo, con vista). Ricorda il simbolo del Toro.
-- Restituisce di quanto alzare il terreno piatto della piana in quel punto.
local function crescentHeight(cfg: any, x: number, z: number): number
	local HUB = cfg.HUB
	local C = HUB.CRESCENT
	local cx, cz = HUB.X + HUB.CAMP.DX, HUB.Z + HUB.CAMP.DZ
	local r = sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
	if r < C.INNER - 30 or r > C.OUTER + 45 then
		return 0
	end
	local ang = atan2(z - cz, x - cx) -- 0 = verso la montagna (est)
	local span = abs(ang)
	if span > C.SPAN then
		return 0
	end
	local taper = smoothstep(C.SPAN, C.SPAN - 0.2, span)
	-- Muri di contenimento verticali tra i livelli
	local h = 0
	if r >= C.OUTER then
		h = C.TIER2 * smoothstep(C.OUTER + 45, C.OUTER, r) -- pendio dolce verso est
	elseif r >= C.MID then
		h = C.TIER2
	elseif r >= C.INNER then
		h = C.TIER1 + (C.TIER2 - C.TIER1) * smoothstep(C.MID - 1.5, C.MID, r)
	else
		h = C.TIER1 * smoothstep(C.INNER - 1.5, C.INNER, r)
	end
	-- Rampe camminabili per salire ai livelli
	for _, ra in C.RAMPS do
		if abs(ang - ra) * r < 7 then
			if r < C.INNER and r > C.INNER - 26 then
				h = C.TIER1 * (r - (C.INNER - 26)) / 26
			elseif r < C.MID and r > C.MID - 26 then
				h = C.TIER1 + (C.TIER2 - C.TIER1) * (r - (C.MID - 26)) / 26
			end
		end
	end
	return h * taper
end

-- Profilo della montagna (0..1 dell'altezza) a distanza t dal centro (0 = vetta, 1 = piede).
-- Non un cono ma un massiccio a tre piani, come le Dolomiti:
--   pendici  dolci e boscose fino a SKIRT dell'altezza
--   bastione una fascia di pareti quasi verticali che sale fino alla spalla (SHOULDER)
--   piramide la vetta, sopra la spalla
-- wob (-0.5..0.5) sposta i piani e cambia la ripidita' a seconda del versante, cosi' i piani
-- non sono anelli perfetti: qui una parete enorme, li' una rampa piu' dolce.
local function mountainProfile(P: any, t: number, wob: number): number
	local a = P.BASTION_FOOT + wob * 0.10
	local b = P.PYRAMID_FOOT + wob * 0.06
	if t >= a then
		return P.SKIRT * ((1 - t) / (1 - a)) ^ 1.25
	elseif t >= b then
		local u = (a - t) / (a - b)
		local wall = P.WALL_POWER + wob * 1.4 -- 1 = rampa, 3 = parete verticale e spalla piatta
		return P.SKIRT + (P.SHOULDER - P.SKIRT) * (1 - (1 - u) ^ wall)
	end
	local u = 1 - t / b
	return P.SHOULDER + (1 - P.SHOULDER) * (0.45 * (1 - (1 - u) ^ 2.0) + 0.55 * u ^ 1.5)
end
Heightmap.mountainProfile = mountainProfile

local function buildBase(map: Map, S: { number }, yield: () -> (), progress: (string, number) -> ())
	local cfg = map.cfg
	local V = cfg.VOXEL
	local M = cfg.MOUNTAIN
	local MX, MZ, MH, MR = M.X, M.Z, M.HEIGHT, M.RADIUS
	local C = cfg.CLIFFS
	local HUB, BAY = cfg.HUB, cfg.BAY
	local RX, RZ = cfg.ISLAND_RX, cfg.ISLAND_RZ
	local foothills = cfg.FOOTHILLS
	local influence2 = (MR + 350) ^ 2
	-- Monoliti (pareti enormi tipo El Capitan / Arco): centro e quota della montagna li' sotto
	local monoliths = {}
	for _, mo in cfg.MONOLITHS or {} do
		local r = mo.DIST * MR
		local tc = mo.DIST
		table.insert(monoliths, {
			x = MX + cos(mo.ANGLE) * r,
			z = MZ + sin(mo.ANGLE) * r,
			radius = mo.RADIUS,
			top = MH * mountainProfile(M.PROFILE, tc, 0) + mo.HEIGHT,
			base = MH * mountainProfile(M.PROFILE, tc, 0),
			name = mo.NAME,
		})
	end
	map.features.monoliths = monoliths

	-- Isolotti al largo e faraglioni davanti alle falesie. Posizioni lungo la superellisse della
	-- costa (fattore 1 = sulla costa), cosi' seguono la forma dell'isola.
	local CO = cfg.COAST or { CLIFF_HEIGHT = 0, ISLETS = 0, STACKS = 0 }
	local crng = Random.new(cfg.SEED + 404)
	local rocks = {}
	local function onCoast(a: number, f: number): (number, number)
		local c, sn = cos(a), sin(a)
		return RX * f * math.sign(c) * abs(c) ^ (2 / 3), RZ * f * math.sign(sn) * abs(sn) ^ (2 / 3)
	end
	for _ = 1, CO.ISLETS do
		local x, z = onCoast(crng:NextNumber(0, 2 * math.pi), crng:NextNumber(1.1, 1.24))
		table.insert(rocks, { x = x, z = z, r = crng:NextNumber(60, 170), h = crng:NextNumber(25, 95), power = 1.3 })
	end
	for _ = 1, CO.STACKS do
		local x, z = onCoast(crng:NextNumber(0, 2 * math.pi), crng:NextNumber(1.02, 1.09))
		table.insert(rocks, { x = x, z = z, r = crng:NextNumber(12, 28), h = crng:NextNumber(55, 150), power = 6 })
	end
	map.features.islets = rocks
	local nx, nz = map.nx, map.nz

	for iz = 0, nz - 1 do
		local z = map.minZ + iz * V + V / 2
		for ix = 0, nx - 1 do
			local x = map.minX + ix * V + V / 2
			local i = ix + iz * nx

			-- Pianura ondulata
			local land = 46 + fbm(x / 900, z / 900, S[1], 4) * 70 + fbm(x / 210, z / 210, S[2], 3) * 12

			-- Montagne (solo vicino ai rilievi, per risparmiare calcoli)
			local m, gully = 0, 0
			local dx0, dz0 = x - MX, z - MZ
			local near = dx0 * dx0 + dz0 * dz0 < influence2
			if not near then
				for _, f in foothills do
					local fx, fz = x - f.X, z - f.Z
					if fx * fx + fz * fz < (f.RADIUS + 350) ^ 2 then
						near = true
						break
					end
				end
			end

			if near then
				-- Distorsione del dominio: niente forme geometriche perfette
				local wx = fbm(x / 800, z / 800, S[3], 3) * 300
				local wz = fbm(x / 800, z / 800, S[4], 3) * 300

				local dx, dz = dx0 + wx, dz0 + wz
				local r = sqrt(dx * dx + dz * dz)
				local theta = atan2(dz, dx)
				-- 4 creste principali (piramide tipo Cervino) + irregolarita' per non sembrare un cono
				local ct, st = cos(theta), sin(theta)
				local d = r * (1 + 0.16 * cos(4 * (theta - 0.4)) + 0.1 * noise(ct * 1.7 + S[5], st * 1.7 + S[6], S[7] + 3))
				local t = d / MR
				if t < 1 then
					-- Massiccio a tre piani (pendici, bastione di pareti, piramide); "wob" cambia da
					-- versante a versante
					local wob = fbm(ct * 1.3 + S[12], st * 1.3 + S[13], S[14], 2)
					m = MH * mountainProfile(M.PROFILE, t, clamp(wob, -0.5, 0.5))
					-- Costoloni di roccia che scendono dalla vetta
					local spur = 1 - clamp(abs(noise(ct * 4 + S[9], st * 4 + S[10], r / 700 + S[11])) * 2.5, 0, 1)
					m += spur ^ 3 * 180 * t * (1 - t) * 4
					-- Canaloni d'erosione radiali (scendono lungo il pendio)
					local g = abs(noise(ct * 5 + S[5], st * 5 + S[6], r / 450 + S[7]))
					gully = (1 - smoothstep(0, 0.07, g)) * smoothstep(0.02, 0.15, t) * smoothstep(0.97, 0.6, t)
					m -= gully * (20 + 90 * (1 - t))
					-- Rugosita' della roccia
					m += (ridged(x / 150, z / 150, S[8], 3) - 0.35) * 70 * sqrt(1 - t)
				end

				for _, f in foothills do
					local fdx, fdz = x - f.X + wx * 0.6, z - f.Z + wz * 0.6
					local fd = sqrt(fdx * fdx + fdz * fdz) / f.RADIUS
					if fd < 1 then
						local fh = f.HEIGHT * (1 - fd) ^ 1.8 + (ridged(x / 120, z / 120, S[9], 3) - 0.35) * 40 * (1 - fd)
						if fh > m then
							m = fh
						end
					end
				end

				-- Pareti verticali a gradoni: sparse (maschera di rumore) + grande parete sul lato +Z
				if m > 120 then
					local sn = sin(theta)
					local bigWall = if sn > 0 and t < 0.9 then sn ^ 8 * smoothstep(0.9, 0.4, t) else 0
					-- pareti a gradoni su gran parte della montagna (prima erano rare e sembrava un cono)
					local mask = max(smoothstep(C.MASK[1], C.MASK[2], fbm(x / 650, z / 650, S[10], 2)), bigWall)
					mask *= smoothstep(120, 260, m)
					if mask > 0.001 then
						local stepH = lerp(C.STEP_MIN, C.STEP_MAX, clamp(fbm(x / 900, z / 900, S[11], 1) + 0.5, 0, 1))
						stepH = lerp(stepH, C.BIG_WALL_STEP, bigWall)
						local tt = m / stepH
						local fl = floor(tt)
						m += ((fl + (tt - fl) ^ C.SHARPNESS) * stepH - m) * mask
					end
				end

				-- Monoliti: pareti quasi verticali alte centinaia di studs, cima a cupola
				for _, mo in monoliths do
					local mdx, mdz = x - mo.x, z - mo.z
					local md = sqrt(mdx * mdx + mdz * mdz) + fbm(x / 90, z / 90, S[14], 2) * mo.radius * 0.25
					if md < mo.radius then
						local shape = smoothstep(mo.radius, mo.radius * 0.9, md)
						local top = mo.top * (1 - 0.18 * (md / mo.radius) ^ 2) + (ridged(x / 60, z / 60, S[15], 2) - 0.4) * 30
						if top > m then
							m = lerp(m, top, shape)
						end
					end
				end
			end

			local h = land + m

			-- Piana della base: quasi piatta
			local hd = sqrt((x - HUB.X) ^ 2 + (z - HUB.Z) ^ 2) + fbm(x / 150, z / 150, S[12], 2) * 80
			local hk = smoothstep(HUB.RADIUS, HUB.RADIUS * 0.55, hd)
			h = lerp(h, HUB.HEIGHT + fbm(x / 120, z / 120, S[13], 2) * 3, hk)
			h += crescentHeight(cfg, x, z) * hk

			-- Anello di pareti rocciose attorno alla valle centrale, con varchi (mare e montagna)
			local WALL = HUB.WALL
			local hr = sqrt((x - HUB.X) ^ 2 + (z - HUB.Z) ^ 2) + fbm(x / 260, z / 260, S[12] + 9, 2) * 90
			if hr > WALL.RADIUS - 10 and hr < WALL.RADIUS + WALL.WIDTH then
				local ring = smoothstep(WALL.RADIUS - 4, WALL.RADIUS + 14, hr)
					* smoothstep(WALL.RADIUS + WALL.WIDTH, WALL.RADIUS + WALL.WIDTH * 0.45, hr)
				local ang = atan2(z - HUB.Z, x - HUB.X)
				for _, gate in WALL.GATES do
					local da = abs((ang - gate.ANGLE + math.pi) % (2 * math.pi) - math.pi)
					ring *= smoothstep(gate.WIDTH * 0.6, gate.WIDTH, da)
				end
				local wallH = WALL.HEIGHT * (0.85 + fbm(x / 140, z / 140, S[12] + 3, 3) * 0.8)
					+ (ridged(x / 60, z / 60, S[8] + 2, 2) - 0.4) * 30
				h = max(h, HUB.HEIGHT + wallH * ring)
			end

			-- Costa: superellisse (forma "squadrata" irregolare) deformata dal rumore, con baia
			local bd = sqrt((x - BAY.X) ^ 2 + (z - BAY.Z) ^ 2) + fbm(x / 200, z / 200, S[14], 2) * 140
			local bk = smoothstep(BAY.RADIUS, BAY.RADIUS * 0.45, bd)
			local e = ((abs(x) / RX) ^ 3 + (abs(z) / RZ) ^ 3) ^ (1 / 3)
				+ fbm(x / 1100, z / 1100, S[15], 3) * 0.5
				+ fbm(x / 260, z / 260, S[16], 2) * 0.08
			-- falesie: in alcuni tratti la terra resta alta fino al bordo e cade a picco nel mare
			local cliffK = smoothstep(0.05, 0.3, fbm(x / 750, z / 750, S[3] + 21, 2)) * (1 - bk)
			h += cliffK * smoothstep(0.7, 0.97, e) * (CO.CLIFF_HEIGHT + fbm(x / 90, z / 90, S[4] + 3, 2) * 25)
			local landF = lerp(smoothstep(1.0, 0.9, e), smoothstep(1.0, 0.985, e), cliffK) * (1 - bk)
			-- La valle centrale resta sempre terraferma (il mare arriva appena fuori dal varco ovest)
			local hubDist = sqrt((x - HUB.X) ^ 2 + (z - HUB.Z) ^ 2)
			landF = max(landF, smoothstep(HUB.WALL.RADIUS + 120, HUB.WALL.RADIUS - 60, hubDist))
			-- Anche la montagna resta intera fino al piede: e' piu' larga dell'isola, e la costa la
			-- tagliava con un dirupo seguito da una piana di sabbia fino al bordo della mappa
			local mDist = sqrt(dx0 * dx0 + dz0 * dz0)
			landF = max(landF, smoothstep(MR + 220, MR - 120, mDist) * (1 - bk))
			-- Fondale: laguna bassa di sabbia (acqua turchese) poi barriera e mare profondo
			local se = e + bk * 0.08
			local shelf = -3 - smoothstep(1.0, 1.2, se) * 7
			shelf += max(0, fbm(x / 170, z / 170, S[13] + 5, 2) - 0.12) * 60 -- secche di sabbia
			-- sempre un po' sott'acqua: quando arrivavano a pelo d'acqua restavano pozzanghere sparse
			shelf = min(shelf, cfg.WATER_LEVEL - 2.5)
			local deep = -70 + fbm(x / 500, z / 500, S[2] + 7, 2) * 20
			local sea = lerp(shelf, deep, smoothstep(1.2, 1.3, se))
			h = sea + (h - sea) * landF
			-- isolotti (cupole basse) e faraglioni (pilastri a pareti verticali)
			if e > 0.95 then
				for _, rk in rocks do
					local rdx, rdz = x - rk.x, z - rk.z
					if abs(rdx) < rk.r * 1.3 and abs(rdz) < rk.r * 1.3 then
						local rd = (sqrt(rdx * rdx + rdz * rdz) + fbm(x / 40, z / 40, S[5] + 9, 2) * rk.r * 0.35) / rk.r
						if rd < 1 then
							local top = rk.h * (1 - rd ^ rk.power) + (ridged(x / 30, z / 30, S[6] + 4, 2) - 0.4) * 10
							h = max(h, top)
						end
					end
				end
			end

			-- Bordo della mappa: negli ultimi EDGE studs il terreno scende dolce in mare (oltre c'e' solo
			-- l'oceano finto): niente piu' coste tagliate dritte
			local EDGE = 450
			local border = min(x - map.minX, map.minX + nx * V - x, z - map.minZ, map.minZ + nz * V - z)
			if border < EDGE then
				h = lerp(-40, h, smoothstep(0, EDGE, border))
			end

			setH(map, i, h)
			setW(map, i, if h < cfg.WATER_LEVEL then cfg.WATER_LEVEL else Heightmap.NO_WATER)
			writeu8(map.gully, i, floor(gully * 255))
			writeu8(map.zone, i, if hk > 0.6 and landF > 0.99 then Zone.HUB else Zone.NATURAL)
		end
		if iz % 8 == 0 then
			progress("Forma dell'isola", iz / nz)
		end
		yield()
	end
end

------------------------------------------------------------------------------------------
-- 2) Acqua: lago in quota, gola con cascate, fiume, sorgenti termali
------------------------------------------------------------------------------------------

local function carveLake(map: Map)
	local cfg = map.cfg
	local M, L = cfg.MOUNTAIN, cfg.LAKE
	local lakeY = M.HEIGHT * L.HEIGHT_FRAC
	local r = findSurfaceR(map, L.ANGLE, lakeY) or M.RADIUS * 0.45
	local outer = L.RADIUS + L.RIM
	-- tutto il lago (bordo compreso) sta dentro il pendio, dove il terreno e' piu' alto del pelo
	-- dell'acqua: si scava e basta. Prima meta' lago sporgeva a valle e il bordo diventava un muro
	-- costruito sopra la montagna, con l'acqua in cima
	local lx, lz = M.X + cos(L.ANGLE) * (r - outer - 8), M.Z + sin(L.ANGLE) * (r - outer - 8)

	forColumns(map, lx - outer, lz - outer, lx + outer, lz + outer, function(i, x, z)
		local d = sqrt((x - lx) ^ 2 + (z - lz) ^ 2)
		if d < L.RADIUS then
			setH(map, i, lakeY - 3 - 14 * (1 - (d / L.RADIUS) ^ 2))
			setW(map, i, lakeY)
			writeu8(map.zone, i, Zone.LAKE)
		elseif d < outer then
			-- Bordo del circo glaciale: si taglia la parete, mai si costruisce
			local rim = lakeY + 2 + noise(x / 9, z / 9, 3.3) * 2
			if rim < getH(map, i) then
				setH(map, i, rim)
				writeu8(map.zone, i, Zone.LAKE)
			end
		end
	end)

	map.features.lake = { x = lx, y = lakeY, z = lz, radius = L.RADIUS }
end

local function carveGorge(map: Map, sx: number, sz: number, srcLevel: number)
	local cfg = map.cfg
	local G = cfg.GORGE
	local lake = map.features.lake
	local lx, lz = lake.x, lake.z
	local lakeOuter = lake.radius + cfg.LAKE.RIM
	local len = sqrt((sx - lx) ^ 2 + (sz - lz) ^ 2)
	local vx, vz = (sx - lx) / len, (sz - lz) / len
	local px, pz = -vz, vx
	local N = ceil(len / 4)

	local function offset(t: number): number
		return sin(t * math.pi * 2.5) * 35 * sin(t * math.pi)
	end

	-- Profilo del fondo: sempre in discesa, a gradini (pozze + salti = cascate)
	local floors = table.create(N + 1, 0)
	local raw = lake.y - 8
	for k = 0, N do
		local t = k / N
		local cx, cz = lx + vx * len * t + px * offset(t), lz + vz * len * t + pz * offset(t)
		if k * 4 > lakeOuter then
			raw = min(raw, sampleH(map, cx, cz) - G.DEPTH)
		end
		floors[k + 1] = max(srcLevel - 4, if G.STEP > 0 then floor(raw / G.STEP) * G.STEP else raw)
	end
	local fallList = {}
	for k = 2, N + 1 do
		if floors[k - 1] - floors[k] > 8 then
			local t = (k - 1) / N
			table.insert(fallList, {
				x = lx + vx * len * t + px * offset(t),
				z = lz + vz * len * t + pz * offset(t),
				top = floors[k - 1] + 5,
				bottom = floors[k] + 5,
				dirX = vx,
				dirZ = vz,
				width = G.HALF_WIDTH * 1.6,
			})
		end
	end

	local reach = G.HALF_WIDTH + G.WALL
	forColumns(
		map,
		min(lx, sx) - reach - 40,
		min(lz, sz) - reach - 40,
		max(lx, sx) + reach + 40,
		max(lz, sz) + reach + 40,
		function(i, x, z)
			local rx, rz = x - lx, z - lz
			local along = rx * vx + rz * vz
			if along < -10 or along > len + 10 then
				return
			end
			local t = clamp(along / len, 0, 1)
			local d = abs(rx * px + rz * pz - offset(t))
			if d >= reach then
				return
			end
			local k = clamp(floor(t * N + 0.5), 0, N) + 1
			local fl = floors[k]
			local h = getH(map, i)
			local isLake = readu8(map.zone, i) == Zone.LAKE
			if d < G.HALF_WIDTH then
				-- solo dove la gola e' davvero scavata: un fondo sopra il terreno lascerebbe
				-- l'acqua sospesa (e poi un argine per tenerla)
				if fl < h then
					setH(map, i, fl)
					setW(map, i, max(getW(map, i), fl + 5))
					if not isLake then
						writeu8(map.zone, i, Zone.GORGE)
					end
				end
			else
				local wallH = fl + 5 + (d - G.HALF_WIDTH) * 3
				if wallH < h then
					setH(map, i, wallH)
					if not isLake then
						writeu8(map.zone, i, Zone.GORGE_WALL)
					end
				end
			end
		end
	)

	map.features.falls = fallList
end

-- Spline Catmull-Rom: curva morbida che passa per tutti i punti di controllo
local function catmullRom(p0: number, p1: number, p2: number, p3: number, t: number): (number, number)
	local t2, t3 = t * t, t * t * t
	local v = 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
	local dv = 0.5 * ((p2 - p0) + 2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) * t + 3 * (3 * p1 - p0 - 3 * p2 + p3) * t2)
	return v, dv
end

-- Campiona il percorso del fiume ogni ~4 studs, con meandri, e calcola il livello dell'acqua
local function traceRiver(map: Map, S: { number }, river: any, index: number, sourceLevel: number?): { any }
	local cfg = map.cfg
	local pts = river.POINTS
	local samples = {}
	local s = 0
	for k = 1, #pts - 1 do
		local p0, p1, p2, p3 = pts[max(k - 1, 1)], pts[k], pts[k + 1], pts[min(k + 2, #pts)]
		local segLen = sqrt((p2[1] - p1[1]) ^ 2 + (p2[2] - p1[2]) ^ 2)
		local n = max(1, ceil(segLen / 4))
		for j = 0, n - 1 do
			local t = j / n
			local x, dx = catmullRom(p0[1], p1[1], p2[1], p3[1], t)
			local z, dz = catmullRom(p0[2], p1[2], p2[2], p3[2], t)
			local dl = max(sqrt(dx * dx + dz * dz), 1e-3)
			-- Niente meandri alla sorgente, cosi' resta attaccato alla gola/cascata
			local off = fbm(s / 350, index * 7.3, S[1] + 11, 2) * river.MEANDER * min(1, s / 200)
			table.insert(samples, { x = x - dz / dl * off, z = z + dx / dl * off, px = -dz / dl, pz = dx / dl })
			s += segLen / n
		end
	end
	local last = pts[#pts]
	local prev = samples[#samples]
	table.insert(samples, { x = last[1], z = last[2], px = prev and prev.px or 1, pz = prev and prev.pz or 0 })

	-- Quota ideale del fondo: segue il terreno ma non risale mai
	local WL = cfg.WATER_LEVEL
	local cur = sourceLevel or (sampleH(map, samples[1].x, samples[1].z) - river.DEPTH)
	-- Il fiume si scava nella montagna: la quota dell'acqua la decide il punto piu' basso della
	-- sezione (alveo e sponde), cosi' anche quando corre di traverso su un pendio il lato a valle
	-- non resta mai sotto l'acqua. Prima si guardava solo la linea centrale e il lato a valle
	-- veniva "chiuso" alzando un argine: un muro di terra sopra la montagna.
	local reach = river.HALF_WIDTH + 14
	for _, p in samples do
		local low = sampleH(map, p.x, p.z)
		for _, f in { -1, -0.5, 0.5, 1 } do
			low = min(low, sampleH(map, p.x + p.px * reach * f, p.z + p.pz * reach * f))
		end
		cur = max(WL, min(cur, low - river.DEPTH))
		p.level = cur
	end

	-- L'acqua del Terrain e' piatta: il fiume diventa una scala di pozze piatte. Da ogni punto
	-- guardiamo quanto lontano arriverebbe una pozza prima che il fondo scenda piu' di STEP:
	-- se il tratto e' abbastanza lungo diventa una pozza, altrimenti e' troppo ripido e diventa
	-- uno scivolo di roccia (la cascata).
	local POOL = cfg.RIVER_POOLS
	local n = #samples
	local minLen = max(2, ceil(POOL.MIN_LEN / 4)) -- i campioni sono ogni ~4 studs
	local k = 1
	while k <= n do
		-- la pozza si allunga finche' il fondo non e' sceso piu' di DROP: in piano diventa
		-- lunghissima, in salita si accorcia e nasce la scalinata di terrazze
		local j = k
		while j < n and samples[k].level - samples[j + 1].level <= POOL.DROP do
			j += 1
		end
		j = min(n, max(j, k + minLen - 1))
		local level = max(WL, samples[j].level)
		for m = k, j do
			samples[m].water = level
		end
		k = j + 1
	end
	return samples
end

local function carveRivers(map: Map, S: { number }, mainSourceLevel: number)
	local cfg = map.cfg
	local POOL = cfg.RIVER_POOLS
	local keepWater = { [Zone.LAKE] = true, [Zone.GORGE] = true }
	map.features.rivers = {}
	map.features.streams = {}

	for index, river in cfg.RIVERS do
		local samples = traceRiver(map, S, river, index, if index == 1 then mainSourceLevel else nil)
		local HW = river.HALF_WIDTH

		-- Valle: pendii dolci ai lati del fiume, che sfumano nel terreno naturale
		local R = HW + river.VALLEY_WIDTH
		for k = 1, #samples, 4 do
			local p = samples[k]
			forColumns(map, p.x - R, p.z - R, p.x + R, p.z + R, function(i, x, z)
				local d = sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
				if d >= R then
					return
				end
				local h = getH(map, i)
				local profile = p.level + 1 + max(0, d - HW) * river.VALLEY_SLOPE
				local target = lerp(profile, h, smoothstep(R * 0.55, R, d))
				if target < h then
					setH(map, i, target)
					if d < HW + 8 and readu8(map.zone, i) == Zone.NATURAL then
						writeu8(map.zone, i, Zone.RIVERBANK)
					end
				end
			end)
		end

		-- Alveo: nelle pozze il fondo viene spianato esattamente POOL.DEPTH sotto il pelo
		-- dell'acqua (cosi' nessun sasso spunta e non restano buchi), negli scivoli resta roccia.
		local streams, current = map.features.streams, nil
		for k, p in samples do
			forColumns(map, p.x - HW, p.z - HW, p.x + HW, p.z + HW, function(i, x, z)
				local d = sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
				if d >= HW then
					return
				end
				local zone = readu8(map.zone, i)
				local shape = 1 - (d / HW) ^ 2
				if p.water then
					local bed = p.water - POOL.DEPTH - 2 * shape
					if keepWater[zone] then
						if bed < getH(map, i) then
							setH(map, i, bed)
						end
						setW(map, i, max(getW(map, i), p.water))
					else
						setH(map, i, bed) -- fondo piatto, anche dove andrebbe riempito
						setW(map, i, p.water)
						writeu8(map.zone, i, Zone.RIVERBED)
					end
				elseif not keepWater[zone] then
					local bed = p.level - 1 - 1.5 * shape
					if bed < getH(map, i) then
						setH(map, i, bed)
					end
					setW(map, i, Heightmap.NO_WATER)
					writeu8(map.zone, i, Zone.RAPIDS)
				end
			end)
			if p.water then
				current = nil
			elseif k % 3 == 1 then
				if not current then
					current = { width = HW * 1.7 }
					table.insert(streams, current)
				end
				table.insert(current, { x = p.x, y = p.level - 2, z = p.z })
			end
		end

		-- Niente argini: il fiume e' scavato abbastanza in basso da non averne bisogno (gli argini
		-- rialzati sembravano muri di terra costruiti sulla montagna).

		-- Punti del fiume ogni ~40 studs con direzione (per ponti, suoni, pesca...)
		local course = {}
		for k = 1, #samples - 10, 10 do
			local p, q = samples[k], samples[k + 10]
			local dl = max(sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2), 1e-3)
			table.insert(course, { x = p.x, y = p.water or p.level, z = p.z, dirX = (q.x - p.x) / dl, dirZ = (q.z - p.z) / dl })
		end

		local first, last = samples[1], samples[#samples]
		table.insert(map.features.rivers, {
			name = river.NAME,
			halfWidth = HW,
			source = { x = first.x, y = first.level, z = first.z },
			mouth = { x = last.x, y = last.level, z = last.z },
			course = course,
		})
	end
end

local function carveHotPools(map: Map)
	local HUB = map.cfg.HUB
	for _, p in map.cfg.HOT_POOLS do
		local cx, cz = HUB.X + p.DX, HUB.Z + p.DZ
		local R = p.RADIUS
		local ground = sampleH(map, cx, cz)
		forColumns(map, cx - R - 6, cz - R - 6, cx + R + 6, cz + R + 6, function(i, x, z)
			local d = sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
			if d < R then
				setH(map, i, ground - 4 - 2 * (1 - (d / R) ^ 2))
				setW(map, i, ground - 1.5)
				writeu8(map.zone, i, Zone.POOL)
			elseif d < R + 5 then
				setH(map, i, max(getH(map, i), ground - 0.5))
				writeu8(map.zone, i, Zone.POOL)
			end
		end)
	end
end

------------------------------------------------------------------------------------------
-- 3) Vetta (spiazzo easter egg) e sentiero a spirale con interruzioni
------------------------------------------------------------------------------------------

-- Ghiaccio sospeso (come la grande fascia di seracchi del K2): attorno alla montagna, a ogni
-- angolo, si trova dove la roccia scende sotto ICECAP.TOP; da li' in giu' il ghiaccio scende con
-- una pendenza piu' dolce della roccia, quindi diventa sempre piu' spesso, finche' supera lo
-- spessore massimo: li' si interrompe di colpo ed e' la parete di seracchi. Solo alcune lingue
-- (LOBES), non un anello; le costole di roccia piu' alte del ghiaccio restano scoperte.
local function carveIceCaps(map: Map)
	local cfg = map.cfg
	local IC = cfg.ICECAP
	if not IC then
		return
	end
	local M = cfg.MOUNTAIN
	local H = M.HEIGHT
	local topY = H * IC.TOP
	local ANG = 1440
	local TAU = 2 * math.pi
	local rTop = table.create(ANG, 0)
	for k = 1, ANG do
		local th = (k - 1) / ANG * TAU
		local cx, cz = cos(th), sin(th)
		local r = 0
		while r < M.RADIUS * 1.5 and sampleH(map, M.X + cx * r, M.Z + cz * r) >= topY do
			r += 4
		end
		rTop[k] = r
	end
	local cells = 0
	forColumns(map, M.X - M.RADIUS, M.Z - M.RADIUS, M.X + M.RADIUS, M.Z + M.RADIUS, function(i, x, z)
		if readu8(map.zone, i) ~= Zone.NATURAL then
			return
		end
		local dx, dz = x - M.X, z - M.Z
		local th = atan2(dz, dx)
		if th < 0 then
			th += TAU
		end
		-- lingue di ghiaccio: rumore "circolare" (stesso valore a 0 e a 360 gradi)
		local lobe = noise(cos(th) * IC.LOBES * 0.5, sin(th) * IC.LOBES * 0.5, 7.7)
		if lobe < 0.02 then
			return
		end
		local k = floor(th / TAU * ANG) % ANG + 1
		local d = sqrt(dx * dx + dz * dz) - rTop[k]
		if d < 0 then
			return
		end
		local h = getH(map, i)
		if h < H * IC.BOTTOM then
			return
		end
		local ice = topY - d * IC.SLOPE
		local thick = ice - h
		-- spessore massimo: varia lungo il fronte (seracchi irregolari) e cala ai lati della lingua
		local maxT = IC.MAX * (0.65 + 0.35 * (noise(th * 9, 3.3, 1.1) + 1)) * smoothstep(0.02, 0.2, lobe)
		if thick <= 1.5 or thick > maxT then
			return
		end
		setH(map, i, ice)
		writeu8(map.zone, i, Zone.ICECAP)
		cells += 1
	end)
	map.features.iceCapCells = cells
end

local function carveSummit(map: Map)
	local M = map.cfg.MOUNTAIN
	local bestH, bx, bz = -math.huge, M.X, M.Z
	forColumns(map, M.X - 250, M.Z - 250, M.X + 250, M.Z + 250, function(i, x, z)
		local h = getH(map, i)
		if h > bestH then
			bestH, bx, bz = h, x, z
		end
	end)
	-- pianoro rotondo per il santuario (cerchio di pietre, pentacolo, altare): la quota e' la
	-- media del terreno sul bordo, cosi' la punta si taglia e i lati piu' bassi si riempiono;
	-- fuori dal cerchio si raccorda dolcemente con la montagna
	local R, BLEND = 34, 18
	local sum = 0
	for k = 0, 23 do
		local a = k / 24 * 2 * math.pi
		sum += sampleH(map, bx + cos(a) * R, bz + sin(a) * R)
	end
	local top = min(sum / 24, bestH - 5)
	forColumns(map, bx - R - BLEND, bz - R - BLEND, bx + R + BLEND, bz + R + BLEND, function(i, x, z)
		local d = sqrt((x - bx) ^ 2 + (z - bz) ^ 2)
		if d <= R then
			setH(map, i, top)
			writeu8(map.zone, i, Zone.SUMMIT)
		elseif d < R + BLEND then
			setH(map, i, lerp(top, getH(map, i), smoothstep(R, R + BLEND, d)))
		end
	end)
	map.features.summit = { x = bx, y = top, z = bz, radius = R }
end

local function carvePath(map: Map)
	local cfg = map.cfg
	local M, P = cfg.MOUNTAIN, cfg.PATH
	local yEnd = M.HEIGHT * P.Y_END_FRAC
	local theta0 = P.START_ANGLE
	local thetaEnd = theta0 + P.TURNS * 2 * math.pi
	local STEP = 3

	-- Campiona il percorso: segue le curve di livello, salendo piano
	local samples = {}
	local gaps = {}
	local gapIndex, inGap, gapStartArc = 1, false, 0
	local rise, arc = 0, 0
	local theta = theta0
	local rPrev: number? = nil
	while theta < thetaEnd do
		local frac = (theta - theta0) / (thetaEnd - theta0)
		local y = P.Y_START + (yEnd - P.Y_START) * frac + rise
		local r = findSurfaceR(map, theta, y)
		if r then
			if rPrev then
				r = clamp(r, rPrev - 6, rPrev + 6) -- niente salti bruschi
			end
			rPrev = r
			table.insert(samples, {
				x = M.X + cos(theta) * r,
				z = M.Z + sin(theta) * r,
				y = y,
				gap = inGap,
			})
		end

		local g = P.GAPS[gapIndex]
		if g and not inGap and frac >= g.at then
			inGap, gapStartArc = true, arc
			local last = samples[#samples]
			gaps[gapIndex] = { kind = g.kind, from = last and { x = last.x, y = last.y, z = last.z } }
		elseif g and inGap and arc - gapStartArc >= g.length then
			inGap = false
			rise += g.rise
			if g.kind == "climb" then
				rPrev = nil -- dopo il buco il sentiero riparte piu' in alto, sulla parete
			end
			gaps[gapIndex].pendingEnd = true
			gapIndex += 1
		end
		if not inGap and #gaps > 0 and gaps[#gaps].pendingEnd and #samples > 0 then
			local s = samples[#samples]
			if not s.gap then
				gaps[#gaps].pendingEnd = nil
				gaps[#gaps].to = { x = s.x, y = s.y, z = s.z }
			end
		end

		theta += STEP / max(r or rPrev or 100, 40)
		arc += STEP
	end

	-- Campi base: piazzole piatte lungo il sentiero dove ripararsi se il tempo peggiora
	local camps = {}
	for _, frac in P.CAMPS do
		local s = samples[math.clamp(math.floor(#samples * frac), 1, #samples)]
		if s and not s.gap then
			local R = P.CAMP_RADIUS
			forColumns(map, s.x - R, s.z - R, s.x + R, s.z + R, function(i, x, z)
				if (x - s.x) ^ 2 + (z - s.z) ^ 2 <= R * R then
					setH(map, i, s.y)
					writeu8(map.zone, i, Zone.PATH)
				end
			end)
			table.insert(camps, { x = s.x, y = s.y, z = s.z })
		end
	end
	map.features.camps = camps

	-- Scolpisce il sentiero (o il burrone, nei buchi)
	local hw = P.HALF_WIDTH
	local protected = { [Zone.GORGE] = true, [Zone.LAKE] = true, [Zone.RIVERBED] = true, [Zone.RAPIDS] = true, [Zone.SUMMIT] = true }
	for _, s in samples do
		local R = if s.gap then hw + 2 else hw
		forColumns(map, s.x - R, s.z - R, s.x + R, s.z + R, function(i, x, z)
			if (x - s.x) ^ 2 + (z - s.z) ^ 2 > R * R or protected[readu8(map.zone, i)] then
				return
			end
			if s.gap then
				if getH(map, i) > s.y - 50 then
					setH(map, i, s.y - 50)
					writeu8(map.zone, i, Zone.NATURAL)
				end
			elseif readu8(map.zone, i) ~= Zone.PATH or getH(map, i) < s.y then
				setH(map, i, s.y)
				writeu8(map.zone, i, Zone.PATH)
			end
		end)
	end

	-- Punti del sentiero ogni ~30 studs (utili per checkpoint e cartelli)
	local points = {}
	for k = 1, #samples, 10 do
		local s = samples[k]
		if not s.gap then
			table.insert(points, { x = s.x, y = s.y, z = s.z })
		end
	end
	map.features.path = points
	map.features.gaps = gaps
	map.features.pathStart = samples[1]
end

-- Strada lastricata dalla base (cerchio delle tende) al varco della valle verso la montagna e
-- poi fino all'inizio del sentiero. Pendenza limitata a MAX_GRADE: dove serve taglia le
-- colline e riempie gli avvallamenti. Nella base segue il terreno (rampe della mezzaluna);
-- dove incrocia un fiume lascia l'acqua e segna il punto per un ponte.
local function carveRoad(map: Map)
	local cfg = map.cfg
	local RD, HUB = cfg.ROAD, cfg.HUB
	local start = map.features.pathStart
	if not RD or not start then
		return
	end
	local M = cfg.MOUNTAIN
	local cx, cz = HUB.X + HUB.CAMP.DX, HUB.Z + HUB.CAMP.DZ

	-- Varco della valle piu' vicino alla direzione della montagna
	local toMountain = atan2(M.Z - HUB.Z, M.X - HUB.X)
	local ga, best = 0, math.huge
	for _, gate in HUB.WALL.GATES do
		local da = abs((gate.ANGLE - toMountain + math.pi) % (2 * math.pi) - math.pi)
		if da < best then
			ga, best = gate.ANGLE, da
		end
	end
	local gr = HUB.WALL.RADIUS + HUB.WALL.WIDTH * 0.4
	local ox, oz = start.x - M.X, start.z - M.Z
	local ol = max(sqrt(ox * ox + oz * oz), 1)
	local ctrl = {
		{ cx + cos(ga) * (HUB.CAMP.RADIUS + 6), cz + sin(ga) * (HUB.CAMP.RADIUS + 6) },
		{ HUB.X + cos(ga) * (HUB.WALL.RADIUS - 110), HUB.Z + sin(ga) * (HUB.WALL.RADIUS - 110) },
		{ HUB.X + cos(ga) * gr, HUB.Z + sin(ga) * gr },
		{ HUB.X + cos(ga) * (gr + 160), HUB.Z + sin(ga) * (gr + 160) },
		{ start.x + ox / ol * 140, start.z + oz / ol * 140 },
		{ start.x, start.z },
	}

	-- Punti ogni ~4 studs lungo la curva
	local pts = {}
	for k = 1, #ctrl - 1 do
		local p0, p1, p2, p3 = ctrl[max(k - 1, 1)], ctrl[k], ctrl[k + 1], ctrl[min(k + 2, #ctrl)]
		local n = max(1, ceil(sqrt((p2[1] - p1[1]) ^ 2 + (p2[2] - p1[2]) ^ 2) / 4))
		for j = 0, n - 1 do
			local x = catmullRom(p0[1], p1[1], p2[1], p3[1], j / n)
			local z = catmullRom(p0[2], p1[2], p2[2], p3[2], j / n)
			table.insert(pts, { x = x, z = z })
		end
	end
	table.insert(pts, { x = start.x, z = start.z })
	local n = #pts

	local V = cfg.VOXEL
	local river = { [Zone.RIVERBED] = true, [Zone.RAPIDS] = true, [Zone.LAKE] = true, [Zone.GORGE] = true, [Zone.POOL] = true }
	local function zoneAt(x: number, z: number): number
		local ix = clamp(floor((x - map.minX) / V), 0, map.nx - 1)
		local iz = clamp(floor((z - map.minZ) / V), 0, map.nz - 1)
		return readu8(map.zone, ix + iz * map.nx)
	end

	-- Profilo: terreno ammorbidito, quote fisse nella base e all'inizio del sentiero
	local raw = table.create(n, 0)
	for k, p in pts do
		raw[k] = sampleH(map, p.x, p.z)
		p.fixed = zoneAt(p.x, p.z) == Zone.HUB
		p.river = river[zoneAt(p.x, p.z)] == true
	end
	pts[n].fixed = true
	raw[n] = start.y
	local h = table.create(n, 0)
	for k = 1, n do
		if pts[k].fixed then
			h[k] = raw[k]
		else
			local sum, cnt = 0, 0
			for j = max(1, k - RD.SMOOTH), min(n, k + RD.SMOOTH) do
				if not pts[j].river then
					sum += raw[j]
					cnt += 1
				end
			end
			h[k] = if cnt > 0 then sum / cnt else raw[k]
		end
	end
	for _ = 1, 3 do
		for k = 2, n do
			local ds = sqrt((pts[k].x - pts[k - 1].x) ^ 2 + (pts[k].z - pts[k - 1].z) ^ 2)
			if not pts[k].fixed then
				h[k] = clamp(h[k], h[k - 1] - RD.MAX_GRADE * ds, h[k - 1] + RD.MAX_GRADE * ds)
			end
		end
		for k = n - 1, 1, -1 do
			local ds = sqrt((pts[k].x - pts[k + 1].x) ^ 2 + (pts[k].z - pts[k + 1].z) ^ 2)
			if not pts[k].fixed then
				h[k] = clamp(h[k], h[k + 1] - RD.MAX_GRADE * ds, h[k + 1] + RD.MAX_GRADE * ds)
			end
		end
	end

	-- Scolpisce carreggiata e scarpate
	local W, SH = RD.HALF_WIDTH, RD.SHOULDER
	local keep = { [Zone.PATH] = true, [Zone.SUMMIT] = true, [Zone.GORGE_WALL] = true }
	for k, p in pts do
		local roadH = h[k]
		forColumns(map, p.x - W - SH, p.z - W - SH, p.x + W + SH, p.z + W + SH, function(i, x, z)
			local zone = readu8(map.zone, i)
			if river[zone] or keep[zone] or getW(map, i) > getH(map, i) then
				return
			end
			local d = sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
			if d >= W + SH then
				return
			end
			if zone == Zone.HUB then
				-- nella base solo il lastricato, le quote restano quelle della mezzaluna
				if d < W then
					writeu8(map.zone, i, Zone.ROAD)
				end
				return
			end
			if d < W then
				setH(map, i, roadH)
				writeu8(map.zone, i, Zone.ROAD)
			elseif zone ~= Zone.ROAD then
				local cur = getH(map, i)
				setH(map, i, lerp(roadH, cur, smoothstep(W, W + SH, d)))
			end
		end)
	end

	-- Punti della strada ogni ~20 studs (lampioni) e tratti sopra l'acqua (ponti)
	local points, bridges = {}, {}
	local k = 1
	while k <= n do
		local p = pts[k]
		if p.river then
			local j = k
			while j <= n and pts[j].river do
				j += 1
			end
			local a, b = max(1, k - 3), min(n, j + 2)
			table.insert(bridges, {
				a = { x = pts[a].x, y = h[a], z = pts[a].z },
				b = { x = pts[b].x, y = h[b], z = pts[b].z },
			})
			k = j
		else
			if k % 5 == 1 then
				local q = pts[min(n, k + 1)]
				local dl = max(sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2), 1e-3)
				table.insert(points, {
					x = p.x,
					y = h[k],
					z = p.z,
					dirX = (q.x - p.x) / dl,
					dirZ = (q.z - p.z) / dl,
					inHub = p.fixed,
				})
			end
			k += 1
		end
	end
	map.features.road = points
	map.features.roadBridges = bridges
end

-- L'acqua del Terrain non scorre: se il bordo di una pozza confina con aria piu' in basso,
-- Roblox disegna un "muro" d'acqua verticale. Qui ogni bordo cosi' diventa un labbro di roccia
-- che trattiene la pozza (le cascate vere sono aggiunte dopo, come effetto visivo).
-- Nessuna pozza piu' profonda di RIVER_POOLS.MAX_DEPTH: senza questo, dove il fondo scendeva
-- in fretta restavano trincee allagate profonde decine di studs (bruttissime e pericolose).
-- Il mare e il lago d'alta quota restano profondi.
local function clampWaterDepth(map: Map)
	local maxDepth = map.cfg.RIVER_POOLS.MAX_DEPTH
	local deep = { [Zone.RIVERBED] = true, [Zone.GORGE] = true, [Zone.POOL] = true, [Zone.RAPIDS] = true }
	local NO_WATER = Heightmap.NO_WATER
	for i = 0, map.nx * map.nz - 1 do
		if deep[readu8(map.zone, i)] then
			local w = getW(map, i)
			if w ~= NO_WATER and w - getH(map, i) > maxDepth then
				setH(map, i, w - maxDepth)
			end
		end
	end
end

-- Laghetti: cerca da solo le zone ampie e piatte (prati lontani da base, strada e fiumi) e ci
-- scava un laghetto dalla forma irregolare, con le sponde fangose
local function carvePonds(map: Map, S: { number })
	local cfg = map.cfg
	local P = cfg.PONDS
	map.features.ponds = {}
	if not P or P.COUNT <= 0 then
		return
	end
	local WL = cfg.WATER_LEVEL
	local HUB = cfg.HUB
	local campX, campZ = HUB.X + HUB.CAMP.DX, HUB.Z + HUB.CAMP.DZ
	local R = P.RADIUS
	local maxY = cfg.MOUNTAIN.HEIGHT * cfg.BIOMES.FOREST_TOP

	local candidates = {}
	local x0, z0 = map.minX + R + 40, map.minZ + R + 40
	for cx = x0, map.minX + cfg.MAP_X - R - 40, 48 do
		for cz = z0, map.minZ + cfg.MAP_Z - R - 40, 48 do
			local h0 = sampleH(map, cx, cz)
			if h0 < WL + 4 or h0 > maxY or (cx - campX) ^ 2 + (cz - campZ) ^ 2 < P.MIN_FROM_CAMP ^ 2 then
				continue
			end
			-- controllo veloce su 4 punti prima di esaminare tutte le colonne
			local quick = true
			for _, o in { { R, 0 }, { -R, 0 }, { 0, R }, { 0, -R } } do
				if abs(sampleH(map, cx + o[1], cz + o[2]) - h0) > 8 then
					quick = false
				end
			end
			if not quick then
				continue
			end
			local lo, hi, ok = math.huge, -math.huge, true
			forColumns(map, cx - R - 16, cz - R - 16, cx + R + 16, cz + R + 16, function(i, x, z)
				if not ok or (x - cx) ^ 2 + (z - cz) ^ 2 > (R + 16) ^ 2 then
					return
				end
				local zone = readu8(map.zone, i)
				if zone ~= Zone.NATURAL or getW(map, i) > getH(map, i) then
					ok = false
					return
				end
				local h = getH(map, i)
				lo, hi = min(lo, h), max(hi, h)
			end)
			if ok and hi - lo < 9 and lo > WL + 3 then
				table.insert(candidates, { x = cx, z = cz, flat = hi - lo, low = lo })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.flat < b.flat
	end)

	for _, c in candidates do
		if #map.features.ponds >= P.COUNT then
			break
		end
		local far = true
		for _, p in map.features.ponds do
			if (p.x - c.x) ^ 2 + (p.z - c.z) ^ 2 < P.MIN_SPACING ^ 2 then
				far = false
			end
		end
		if far then
			local water = c.low - 0.8
			local seed = S[3] + #map.features.ponds * 17.1
			forColumns(map, c.x - R * 1.4, c.z - R * 1.4, c.x + R * 1.4, c.z + R * 1.4, function(i, x, z)
				local dx, dz = x - c.x, z - c.z
				local d = sqrt(dx * dx + dz * dz)
				local a = atan2(dz, dx)
				local edge = R * (0.8 + 0.35 * noise(cos(a) * 1.3 + seed, sin(a) * 1.3, seed * 0.37))
				if d < edge then
					local shape = 1 - (d / edge) ^ 2
					setH(map, i, water - 1.5 - 7 * shape)
					setW(map, i, water)
					writeu8(map.zone, i, Zone.RIVERBED)
				elseif d < edge + 10 then
					-- sponda: appena sopra l'acqua, che sfuma nel prato
					local t = (d - edge) / 10
					setH(map, i, lerp(water + 0.6, getH(map, i), smoothstep(0, 1, t)))
					writeu8(map.zone, i, Zone.RIVERBANK)
				end
			end)
			table.insert(map.features.ponds, { x = c.x, y = water, z = c.z, radius = R })
		end
	end
end

-- Lago grande sul Fiume della Piana, dentro la valle del campo. Il livello e' quello del fiume
-- nel punto piu' vicino: a monte il fiume entra (immissario), a valle esce verso il mare
-- (emissario) e i due tratti restano continui. Tutt'attorno una spiaggia di sabbia.
local function carveBigLake(map: Map, S: { number })
	local cfg = map.cfg
	local BL = cfg.BIG_LAKE
	if not BL then
		return
	end
	local river = map.features.rivers and map.features.rivers[1]
	local level = cfg.WATER_LEVEL + 6
	if river and river.course then
		local best = math.huge
		for _, p in river.course do
			local d = (p.x - BL.X) ^ 2 + (p.z - BL.Z) ^ 2
			if d < best and p.y then
				best, level = d, p.y
			end
		end
	end
	local R, seed = BL.RADIUS, S[4] + 5.5
	local outer = R * 1.35 + BL.BEACH
	forColumns(map, BL.X - outer, BL.Z - outer, BL.X + outer, BL.Z + outer, function(i, x, z)
		local dx, dz = x - BL.X, z - BL.Z
		local d = sqrt(dx * dx + dz * dz)
		local a = atan2(dz, dx)
		-- riva irregolare: insenature e piccole penisole
		local edge = R * (0.85 + 0.3 * noise(cos(a) * 1.6 + seed, sin(a) * 1.6, seed * 0.3))
		if d < edge then
			local shape = 1 - (d / edge) ^ 2
			setH(map, i, level - 1.5 - BL.DEPTH * shape)
			setW(map, i, level)
			writeu8(map.zone, i, Zone.LAKE)
		elseif d < edge + BL.BEACH then
			-- il letto del fiume attraversa la spiaggia: e' l'immissario/emissario, non si tocca
			local zone = readu8(map.zone, i)
			if zone == Zone.RIVERBED or zone == Zone.POOL or zone == Zone.RAPIDS or zone == Zone.RIVERBANK then
				return
			end
			local t = (d - edge) / BL.BEACH
			setH(map, i, lerp(level + 0.6, max(getH(map, i), level + 0.6), smoothstep(0, 1, t)))
			setW(map, i, Heightmap.NO_WATER)
			writeu8(map.zone, i, Zone.BEACH)
		end
	end)
	map.features.bigLake = { x = BL.X, y = level, z = BL.Z, radius = R }
end

-- Ghiacciai (stile K2). Ogni ghiacciaio scende lungo un versante seguendo la forma della
-- montagna: il letto di roccia viene solo ammorbidito (il ghiaccio riempie le asperita', non
-- spiana tutto), la lingua serpeggia e si stringe scendendo, ai lati ha le morene di detriti.
-- Dove il pendio e' ripido diventa seraccata: crepacci fitti e caotici, e piu' tardi il modulo
-- Glacier la riempie di blocchi di ghiaccio (i modelli in ServerStorage/IceKit).
-- Coordinate del ghiacciaio: s lungo l'asse (0 = in alto), t di traverso (0 = linea centrale).
local function glacierFrame(map: Map, def: any): any?
	local M = map.cfg.MOUNTAIN
	local theta = def.ANGLE
	local r0, r1 = def.R_TOP * M.RADIUS, def.R_BOTTOM * M.RADIUS
	local tx, tz = M.X + cos(theta) * r0, M.Z + sin(theta) * r0
	local bx, bz = M.X + cos(theta) * r1, M.Z + sin(theta) * r1
	local length = sqrt((bx - tx) ^ 2 + (bz - tz) ^ 2)
	local ax, az = (bx - tx) / length, (bz - tz) / length
	return { tx = tx, tz = tz, ax = ax, az = az, sx = -az, sz = ax, length = length, width = def.WIDTH, angle = theta }
end

local function glacierSample(g: any, s: number, arr: { number }): number
	local f = clamp(s / g.step + 1, 1, g.n)
	local k0 = floor(f)
	local k1 = min(g.n, k0 + 1)
	return lerp(arr[k0], arr[k1], f - k0)
end

local function glacierToWorld(g: any, s: number, t: number): (number, number)
	local off = glacierSample(g, s, g.off)
	return g.tx + g.ax * s + g.sx * (t + off), g.tz + g.az * s + g.sz * (t + off)
end

Heightmap.glacierSample = glacierSample
Heightmap.glacierToWorld = glacierToWorld

local function glacierLocal(g: any, x: number, z: number): (number, number)
	local dx, dz = x - g.tx, z - g.tz
	local s = dx * g.ax + dz * g.az
	return s, dx * g.sx + dz * g.sz - glacierSample(g, clamp(s, 0, g.length), g.off)
end

local function carveGlacier(map: Map, def: any, index: number)
	local GL = map.cfg.GLACIER
	local g = glacierFrame(map, def)
	if not g then
		return
	end
	local STEP = 8
	local n = floor(g.length / STEP) + 1
	g.step, g.n = STEP, n
	local seed = index * 13.37 + 2.2
	-- il ghiacciaio della grotta di ghiaccio ha un fronte alto (dentro c'e' la galleria)
	local caveFront: number? = nil
	for _, GC in (map.cfg.CAVES and map.cfg.CAVES.GLACIER_CAVES) or {} do
		if GC.GLACIER == index then
			caveFront = GC.FRONT
		end
	end
	g.index = index
	-- linea centrale che serpeggia e larghezza che si stringe scendendo
	g.off, g.half = table.create(n), table.create(n)
	for k = 1, n do
		local s = (k - 1) * STEP
		local u = s / g.length
		g.off[k] = noise(s / 380, seed, 0.3) * 90 * u
		g.half[k] = g.width / 2 * (1 - 0.5 * u) * (1 + 0.18 * noise(s / 160, seed, 4.1))
	end
	-- letto: quota del terreno lungo la linea centrale (media di traverso), appena ammorbidita
	local raw = table.create(n)
	for k = 1, n do
		local s = (k - 1) * STEP
		local sum = 0
		for _, f in { -0.3, 0, 0.3 } do
			local x, z = glacierToWorld(g, s, f * g.half[k])
			sum += sampleH(map, x, z)
		end
		raw[k] = sum / 3
	end
	local bed = table.create(n)
	for k = 1, n do
		local sum, cnt = 0, 0
		for j = max(1, k - GL.SMOOTH), min(n, k + GL.SMOOTH) do
			sum += raw[j]
			cnt += 1
		end
		bed[k] = sum / cnt
	end
	for k = 2, n do
		bed[k] = min(bed[k], bed[k - 1] - 0.5) -- il ghiaccio scende sempre
	end
	-- spessore: sottile nel nevaio in alto, pieno nella lingua, assottigliato al fronte
	g.surf, g.icefall = table.create(n), table.create(n, false)
	-- seraccata solo nei tratti piu' ripidi di questo ghiacciaio (rispetto alla sua pendenza tipica):
	-- su una montagna cosi' alta tutto e' ripido, e prima era seraccata da cima a fondo
	local slopes = table.create(n)
	for k = 1, n do
		slopes[k] = (bed[max(1, k - 3)] - bed[min(n, k + 3)]) / (6 * STEP)
	end
	local sorted = table.clone(slopes)
	table.sort(sorted)
	local typical = sorted[floor(n / 2) + 1]
	for k = 1, n do
		local u = (k - 1) / (n - 1)
		local thick = GL.THICKNESS * smoothstep(0, 0.2, u) * (1 - 0.5 * smoothstep(0.85, 1, u))
		if caveFront then
			thick = max(thick, lerp(GL.THICKNESS, caveFront, smoothstep(0.55, 0.92, u)))
		end
		g.surf[k] = bed[k] + thick
		g.icefall[k] = slopes[k] > typical * GL.ICEFALL and u > 0.1
	end

	local pad = g.width / 2 + 120
	local x0, z0 = g.tx, g.tz
	local x1, z1 = g.tx + g.ax * g.length, g.tz + g.az * g.length
	local keep = { [Zone.RIVERBED] = true, [Zone.POOL] = true, [Zone.RAPIDS] = true, [Zone.LAKE] = true, [Zone.GORGE] = true, [Zone.HUB] = true }
	forColumns(map, min(x0, x1) - pad, min(z0, z1) - pad, max(x0, x1) + pad, max(z0, z1) + pad, function(i, x, z)
		if keep[readu8(map.zone, i)] then
			return
		end
		local s, t = glacierLocal(g, x, z)
		if s < -60 or s > g.length + 20 then
			return
		end
		local sc = clamp(s, 0, g.length)
		local half = glacierSample(g, sc, g.half)
		-- bordi frastagliati (prima erano due righe quasi dritte: sembrava una pista da sci)
		half *= 1 + 0.14 * noise(x / 75, z / 75, seed + 5)
		half += noise(x / 26, z / 26, seed + 6) * 6
		-- angoli del fronte arrotondati
		local L = half * 0.45
		local tip = g.length - s
		if tip < L then
			local k = (L - tip) / L
			half *= 0.55 + 0.45 * sqrt(max(0, 1 - k * k))
		end
		local at = abs(t)
		if at > half + 60 then
			return
		end
		-- fianchi sfumati nella roccia, nevaio che sfuma in alto, fronte netto in basso
		local e = (1 - smoothstep(half * 0.8, half + 30, at)) * smoothstep(-60, 40, s)
		if s > g.length then
			e = 0
		end
		local h = getH(map, i)
		if e > 0 then
			-- superficie leggermente convessa, ondulata come ghiaccio che scorre
			local target = glacierSample(g, sc, g.surf) - 6 * (t / half) ^ 2 + noise(x / 45, z / 45, seed) * 4
			-- il ghiaccio riempie: ai bordi non scava mai sotto la roccia di piu' di qualche stud, e
			-- dentro la lingua copre sempre la roccia (prima le gobbe del letto bucavano il ghiaccio)
			target = max(target, h - 10, if e > 0.6 then h + 3 else -math.huge)
			setH(map, i, lerp(h, target, e))
			if e > 0.5 then
				writeu8(map.zone, i, Zone.GLACIER)
			end
		end
		-- morene laterali: un cordone di detriti appena fuori dal ghiaccio
		local mor = smoothstep(half + 4, half + 22, at) * (1 - smoothstep(half + 34, half + 58, at)) * smoothstep(40, 160, s)
		if mor > 0.2 then
			setH(map, i, getH(map, i) + mor * (5 + noise(x / 20, z / 20, seed + 7) * 3))
			writeu8(map.zone, i, Zone.MORAINE)
		end
	end)
	map.features.glaciers = map.features.glaciers or {}
	table.insert(map.features.glaciers, g)
end

-- Valle dei gas tossici (zona del drago Gas): una conca scavata nel pendio ai piedi della
-- montagna. Il fondo e' quasi piano alla quota del centro; verso monte la conca si incassa nel
-- pendio (la montagna fa da parete), verso valle un orlo rialzato la chiude, tranne un varco
-- da cui si entra (e da cui il gas "scivola" fuori). I materiali li decide classify (Zone.TOXIC),
-- fumarole, nebbia e cartello li mette il modulo Toxic.
local function carveToxicValley(map: Map)
	local T = map.cfg.TOXIC
	if not T then
		return
	end
	local M = map.cfg.MOUNTAIN
	local cx = M.X + cos(T.ANGLE) * T.DIST * M.RADIUS
	local cz = M.Z + sin(T.ANGLE) * T.DIST * M.RADIUS
	local R = T.RADIUS
	local floorY = sampleH(map, cx, cz) - 6
	-- orlo in 36 direzioni: il terreno a distanza R, mai meno di RIM sopra il fondo
	local N = 36
	local rim = table.create(N)
	local lowK, lowH = 1, math.huge
	for k = 1, N do
		local a = (k - 1) / N * 2 * math.pi
		local h = sampleH(map, cx + cos(a) * R, cz + sin(a) * R)
		if h < lowH then
			lowK, lowH = k, h
		end
		rim[k] = max(h + 6, floorY + T.RIM)
	end
	-- varco: nella direzione dove il pendio e' piu' basso
	local breach = (lowK - 1) / N * 2 * math.pi
	local function rimAt(a: number): number
		local f = (a / (2 * math.pi) * N) % N
		local k0 = floor(f)
		local k1 = (k0 + 1) % N
		local h = lerp(rim[k0 + 1], rim[k1 + 1], f - k0)
		local da = abs((a - breach + math.pi) % (2 * math.pi) - math.pi)
		return lerp(floorY + 2, h, smoothstep(0.12, 0.32, da))
	end
	local top = floorY
	forColumns(map, cx - R * 1.6, cz - R * 1.6, cx + R * 1.6, cz + R * 1.6, function(i, x, z)
		local dx, dz = x - cx, z - cz
		local a = atan2(dz, dx)
		local d = sqrt(dx * dx + dz * dz) * (1 + 0.1 * noise(cos(a) * 1.5 + 7.3, sin(a) * 1.5, 2.9))
		if d > R * 1.6 then
			return
		end
		local zone = readu8(map.zone, i)
		if zone == Zone.GLACIER or zone == Zone.PATH or zone == Zone.ROAD then
			return
		end
		local h = getH(map, i)
		local rh = rimAt(a % (2 * math.pi))
		local new
		if d < R * 0.62 then
			-- fondo quasi piano, con qualche gobba
			new = floorY + noise(x / 30, z / 30, 4.4) * 2.5
		elseif d < R then
			-- parete interna ripida fino all'orlo
			local u = (d - R * 0.62) / (R * 0.38)
			new = floorY + (rh - floorY) * smoothstep(0, 1, u) ^ 1.4
		else
			-- fuori: dall'orlo si torna dolcemente al pendio vero
			new = lerp(rh, h, smoothstep(R, R * 1.6, d))
		end
		setH(map, i, new)
		setW(map, i, Heightmap.NO_WATER)
		if d < R * 0.97 then
			writeu8(map.zone, i, Zone.TOXIC)
			top = max(top, new)
		end
	end)
	map.features.toxic = { x = cx, y = floorY, z = cz, radius = R, top = top, breach = breach }
end

-- Crepacci: archi irregolari di traverso (curvi, inclinati, di lunghezza e larghezza diverse,
-- mai a distanza regolare), crepacci marginali a 45 gradi vicino ai bordi, e nelle seraccate
-- tagli fitti e caotici in tutte le direzioni. Dove tagliano il sentiero si segna il punto:
-- li' ci sara' sempre una scala.
local function carveCrevasse(map: Map, g: any, c: any)
	local half = glacierSample(g, c.s0, g.half)
	-- riquadro del crepaccio nel mondo
	local reach = abs(c.bow) + abs(c.tilt) * half + c.width + 16
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, ss in { c.s0 - reach, c.s0 + reach } do
		for _, tt in { c.t0, c.t1 } do
			local x, z = glacierToWorld(g, clamp(ss, 0, g.length), tt)
			minX, maxX = min(minX, x), max(maxX, x)
			minZ, maxZ = min(minZ, z), max(maxZ, z)
		end
	end
	local pathT: { number } = {}
	forColumns(map, minX - 12, minZ - 12, maxX + 12, maxZ + 12, function(i, x, z)
		local zone = readu8(map.zone, i)
		if zone ~= Zone.GLACIER and zone ~= Zone.PATH then
			return
		end
		local s, t = glacierLocal(g, x, z)
		if t < c.t0 or t > c.t1 then
			return
		end
		local centre = c.s0 + c.bow * (t / half) ^ 2 + c.tilt * t + noise(t / 35, c.seed, 1.7) * 5
		local span = c.t1 - c.t0
		local ends = smoothstep(c.t0, c.t0 + span * 0.25, t) * (1 - smoothstep(c.t1 - span * 0.25, c.t1, t))
		local w = c.width * (0.25 + 0.75 * ends) * (1 + 0.25 * noise(t / 18, c.seed, 3.3))
		if abs(s - centre) < w / 2 then
			if zone == Zone.PATH then
				table.insert(pathT, t)
			end
			local d = c.depth * (0.35 + 0.65 * ends)
			setH(map, i, getH(map, i) - d + noise(x / 7, z / 7, c.seed) * 4)
			writeu8(map.zone, i, Zone.GLACIER)
		end
	end)
	if #pathT > 0 then
		local sum = 0
		for _, t in pathT do
			sum += t
		end
		c.path = sum / #pathT
	end
end

local function carveCrevasses(map: Map)
	local GL = map.cfg.GLACIER
	local rng = Random.new(map.cfg.SEED + 71)
	for _, g in map.features.glaciers or {} do
		g.crevasses = {}
		local s = rng:NextNumber(40, 80)
		while s < g.length - 30 do
			local k = floor(s / g.step) + 1
			local half = g.half[k]
			local icefall = g.icefall[k]
			if icefall then
				-- seraccata: due o tre tagli corti, ognuno storto a modo suo
				for _ = 1, rng:NextInteger(2, 3) do
					local tc = rng:NextNumber(-half * 0.7, half * 0.7)
					local len = rng:NextNumber(0.2, 0.45) * half * 2
					table.insert(g.crevasses, {
						s0 = s + rng:NextNumber(-6, 6), t0 = tc - len / 2, t1 = tc + len / 2,
						bow = rng:NextNumber(-10, 10), tilt = rng:NextNumber(-0.7, 0.7),
						width = rng:NextNumber(GL.CREVASSE_WIDTH[1], GL.CREVASSE_WIDTH[2]),
						depth = rng:NextNumber(GL.CREVASSE_DEPTH[1], GL.CREVASSE_DEPTH[2]),
						seed = rng:NextNumber(0, 100), icefall = true,
					})
				end
				s += rng:NextNumber(14, 30)
			else
				-- arco di traverso: non attraversa mai tutta la lingua, ha una sua curva e pendenza
				local span = rng:NextNumber(0.45, 0.95) * half * 2
				local tc = rng:NextNumber(-half + span / 2, half - span / 2)
				table.insert(g.crevasses, {
					s0 = s, t0 = tc - span / 2, t1 = tc + span / 2,
					bow = rng:NextNumber(-25, 25), tilt = rng:NextNumber(-0.25, 0.25),
					width = rng:NextNumber(GL.CREVASSE_WIDTH[1], GL.CREVASSE_WIDTH[2]),
					depth = rng:NextNumber(GL.CREVASSE_DEPTH[1], GL.CREVASSE_DEPTH[2]),
					seed = rng:NextNumber(0, 100),
				})
				-- a volte un crepaccio marginale a 45 gradi sul bordo
				if rng:NextNumber() < 0.45 then
					local side = if rng:NextNumber() < 0.5 then -1 else 1
					local len = rng:NextNumber(0.12, 0.25) * half * 2
					local tEdge = side * (half * 0.9 - len / 2)
					table.insert(g.crevasses, {
						s0 = s + rng:NextNumber(10, 25), t0 = tEdge - len / 2, t1 = tEdge + len / 2,
						bow = 0, tilt = side * rng:NextNumber(0.7, 1.1),
						width = rng:NextNumber(GL.CREVASSE_WIDTH[1], GL.CREVASSE_WIDTH[1] + 5),
						depth = rng:NextNumber(GL.CREVASSE_DEPTH[1], GL.CREVASSE_DEPTH[1] + 20),
						seed = rng:NextNumber(0, 100),
					})
				end
				s += rng:NextNumber(GL.CREVASSE_EVERY[1], GL.CREVASSE_EVERY[2])
			end
		end
		for _, c in g.crevasses do
			carveCrevasse(map, g, c)
		end
	end
end

local function sealWaterEdges(map: Map)
	-- Acqua che finirebbe a strapiombo su un terreno (o un'acqua) molto piu' basso: prima qui si
	-- alzava sempre il terreno a fare da argine, e venivano fuori canali rialzati come acquedotti.
	-- Ora si alza solo un bordino basso (al massimo LIP studs); se servirebbe un muro si toglie
	-- quell'acqua; i vicini che restano sospesi a loro volta si controllano dopo (a catena),
	-- cosi' una lastra d'acqua sopra il terreno sparisce tutta.
	local nx, nz = map.nx, map.nz
	local NO_WATER = Heightmap.NO_WATER
	local DROP = map.cfg.WATER_EDGE_DROP
	local LIP = 6 -- un bordo naturale si alza al massimo di tanto; di piu' sarebbe un muro
	local queue: { number } = {}
	local function check(i: number): boolean
		local ix, iz = i % nx, i // nx
		if ix < 1 or iz < 1 or ix > nx - 2 or iz > nz - 2 then
			return false
		end
		local w = getW(map, i)
		if w == NO_WATER or w <= getH(map, i) then
			return false
		end
		for _, j in { i - 1, i + 1, i - nx, i + nx } do
			if max(getH(map, j), getW(map, j)) < w - DROP then
				local h = getH(map, i)
				setW(map, i, NO_WATER)
				if w + 0.5 - h <= LIP then
					-- basta un bordino (es. dove una pozza del fiume finisce sulla cascata): si alza
					-- di poco e l'acqua e' trattenuta, niente catena
					setH(map, i, w + 0.5)
					return false
				end
				return true
			end
		end
		return false
	end
	for i = 0, nx * nz - 1 do
		if check(i) then
			table.insert(queue, i)
		end
	end
	local removed = #queue
	while #queue > 0 do
		local i = table.remove(queue) :: number
		for _, j in { i - 1, i + 1, i - nx, i + nx } do
			if check(j) then
				removed += 1
				table.insert(queue, j)
			end
		end
	end
	map.features.waterRemoved = removed
end

------------------------------------------------------------------------------------------
-- 4) Materiali in base a quota, pendenza, zona e canaloni
------------------------------------------------------------------------------------------

local function strata(h: number, n: number): number
	local s = sin(h / 19 + n * 4)
	if s > 0.55 then
		return SLATE
	elseif s < -0.94 then
		return BASALT -- (prima era calcare: in Roblox e' quasi bianco e sembrava neve a chiazze)
	end
	return ROCK
end

local function classify(
	cfg: any,
	h: number,
	slope: number,
	gully: number,
	zone: number,
	nA: number,
	nB: number,
	curv: number,
	nL: number,
	x: number,
	z: number
): (number, number)
	local H = cfg.MOUNTAIN.HEIGHT
	local B = cfg.BIOMES
	local WL = cfg.WATER_LEVEL

	if zone == Zone.HUB then
		if slope > 1.5 then
			return SLATE, ROCK -- muri di contenimento della mezzaluna
		elseif slope > 0.5 then
			return GROUND, GROUND
		end
		return if nB > 0.18 then GROUND elseif nA > 0.05 then LEAFY else GRASS, GROUND
	elseif zone == Zone.RIVERBED then
		return if h < WL + 1 or nB > 0 then SAND else SLATE, SANDSTONE
	elseif zone == Zone.RAPIDS then
		return if nB > 0 then SLATE else ROCK, ROCK
	elseif zone == Zone.RIVERBANK then
		return if slope < 0.5 then MUD else GROUND, GROUND
	elseif zone == Zone.LAKE or zone == Zone.GORGE then
		return SLATE, ROCK
	elseif zone == Zone.GORGE_WALL then
		return strata(h, nA), ROCK
	elseif zone == Zone.PATH then
		return if h < H * B.FOREST_TOP then GROUND else SLATE, ROCK
	elseif zone == Zone.SUMMIT then
		return GRASS, GROUND
	elseif zone == Zone.POOL then
		return LIMESTONE, LIMESTONE
	elseif zone == Zone.ROAD then
		return if nB > 0.45 then GROUND else COBBLE, GROUND
	elseif zone == Zone.BEACH then
		return if slope > 0.9 then GROUND else SAND, SANDSTONE
	elseif zone == Zone.GLACIER then
		-- ghiaccio vivo, con chiazze di neve sui tratti in piano
		return if slope < 0.5 and nB > 0.28 then SNOW else GLACIER, GLACIER
	elseif zone == Zone.ICECAP then
		-- ghiaccio sospeso: neve sopra, ghiaccio vivo sulla parete di seracchi
		return if slope < 1 then SNOW else GLACIER, GLACIER
	elseif zone == Zone.TOXIC then
		-- pareti di roccia scura, fondo blu-viola con chiazze di crosta che brilla
		if slope > 1.3 then
			return BASALT, BASALT
		end
		return if slope < 0.4 and nB > 0.3 then TOXCRUST else TOXROCK, BASALT
	elseif zone == Zone.MORAINE then
		-- detriti: sassi e terra, con un po' di neve sopra in quota
		return if h > cfg.MOUNTAIN.HEIGHT * cfg.BIOMES.SNOW_LINE and nB > 0.1 then SNOW elseif nB > -0.2 then ROCK else GROUND, ROCK
	end

	if h < WL + 2.5 + nA * 2.5 and slope < 0.7 then
		return SAND, SANDSTONE
	end

	local a = h + nA * 120
	local steep = slope > 1.1

	if a < H * B.FOREST_TOP then
		if steep then
			return strata(h, nA), ROCK
		elseif slope > 0.85 then
			return GROUND, ROCK
		end
		return if nB > 0.22 then GROUND elseif nA > 0.08 then LEAFY else GRASS, GROUND
	end

	local snowLine = H * B.SNOW_LINE - gully * 500
	if a < snowLine then
		if steep then
			if nB > 0.38 then
				return BASALT, ROCK
			end
			return strata(h, nA), ROCK
		elseif a < H * B.MEADOW_TOP then
			return if nB > 0.1 then GROUND else GRASS, GROUND
		end
		return if nB > 0 then ROCK else GROUND, ROCK -- ghiaione
	end

	-- Zona della neve, come sul K2: la neve riempie canaloni e pendii e si fonde col ghiaccio; la
	-- roccia scura resta sulle costole sporgenti (curv > 0) e sulle pareti piu' ripide, a fasce
	-- larghe (nL, rumore a grana grossa) invece che a chiazze. Piu' si sale piu' e' bianco.
	-- Niente piu' ghiaccio azzurro sparso sulle pareti: il ghiaccio vivo sta solo nei ghiacciai
	-- e nelle pareti di seracchi.
	local up = clamp((a - snowLine) / max(1, H - snowLine), 0, 1)
	-- Pareti di ghiaccio vivo (come una cascata di ghiaccio): settori larghi attorno alla
	-- montagna dove le pareti ripide sono ghiaccio azzurro invece che roccia. Il rumore usa
	-- l'angolo attorno alla vetta (stesso valore a 0 e 360 gradi) e la quota.
	local IW = cfg.ICEWALLS
	if IW and a > H * IW.BOTTOM and a < H * IW.TOP and slope > IW.MIN_SLOPE then
		local M = cfg.MOUNTAIN
		local th = atan2(z - M.Z, x - M.X)
		local band = noise(cos(th) * IW.SECTORS * 0.5, sin(th) * IW.SECTORS * 0.5, a / 700 + 4.4)
		if band + nB * 0.08 > IW.THRESHOLD then
			return GLACIER, GLACIER
		end
	end
	-- la montagna e' quasi tutta parete: la pendenza conta poco (solo le pareti quasi verticali
	-- restano scoperte), contano le costole e le fasce di roccia
	local rockScore = (slope - 3.2) * 0.35 + curv * 0.07 + nL * 0.55 - up * 1.2 + nB * 0.08 - 0.15
	if gully > 0.35 then
		rockScore -= 0.6 -- i canaloni sono bianchi
	end
	if a < snowLine + 140 then
		rockScore += (1 - (a - snowLine) / 140) * 0.6 -- appena sopra la linea, ancora roccia
	end
	if rockScore > 0 then
		return if nL > 0.2 then BASALT else strata(h, nA), ROCK
	end
	-- sotto la neve ancora neve: i bordi e i gradini restano bianchi, come cornici
	return SNOW, SNOW
end

local function paintMaterials(map: Map, S: { number }, yield: () -> (), progress: (string, number) -> ())
	local cfg = map.cfg
	local V = cfg.VOXEL
	local nx, nz = map.nx, map.nz
	for iz = 0, nz - 1 do
		local z = map.minZ + iz * V + V / 2
		for ix = 0, nx - 1 do
			local x = map.minX + ix * V + V / 2
			local i = ix + iz * nx
			local h = getH(map, i)
			local hx0 = getH(map, if ix > 0 then i - 1 else i)
			local hx1 = getH(map, if ix < nx - 1 then i + 1 else i)
			local hz0 = getH(map, if iz > 0 then i - nx else i)
			local hz1 = getH(map, if iz < nz - 1 then i + nx else i)
			local slope = sqrt(((hx1 - hx0) / (2 * V)) ^ 2 + ((hz1 - hz0) / (2 * V)) ^ 2)
			local nA = fbm(x / 90, z / 90, S[5] + 3, 2)
			local nB = noise(x / 35, z / 35, S[6] + 5)
			-- convessita' a 12 studs: positiva sulle costole, negativa nei canaloni
			local R = 3
			local cx0 = getH(map, i - min(ix, R))
			local cx1 = getH(map, i + min(nx - 1 - ix, R))
			local cz0 = getH(map, i - min(iz, R) * nx)
			local cz1 = getH(map, i + min(nz - 1 - iz, R) * nx)
			local curv = h - (cx0 + cx1 + cz0 + cz1) / 4
			local nL = noise(x / 240, z / 240, S[7] + 9)
			local surf, sub = classify(cfg, h, slope, readu8(map.gully, i) / 255, readu8(map.zone, i), nA, nB, curv, nL, x, z)
			writeu8(map.surf, i, surf)
			writeu8(map.sub, i, sub)
		end
		if iz % 16 == 0 then
			progress("Materiali", iz / nz)
		end
		yield()
	end
end

------------------------------------------------------------------------------------------

function Heightmap.build(cfg: any, yield: () -> (), progress: (string, number) -> ()): Map
	local V = cfg.VOXEL
	local nx, nz = cfg.MAP_X // V, cfg.MAP_Z // V
	local count = nx * nz
	local map: Map = {
		cfg = cfg,
		nx = nx,
		nz = nz,
		minX = -cfg.MAP_X / 2,
		minZ = -cfg.MAP_Z / 2,
		height = buffer.create(count * 4),
		water = buffer.create(count * 4),
		gully = buffer.create(count),
		zone = buffer.create(count),
		surf = buffer.create(count),
		sub = buffer.create(count),
		features = {},
	}
	local S = Noise.seeds(cfg.SEED, 16)

	buildBase(map, S, yield, progress)

	-- Il fiume principale nasce dove finisce la gola della cascata
	local source = cfg.RIVERS[1].POINTS[1]
	local sx, sz = source[1], source[2]
	local srcLevel = sampleH(map, sx, sz) - 6

	progress("Lago e cascata", 0)
	carveLake(map)
	carveGorge(map, sx, sz, srcLevel)
	progress("Fiumi e valli", 0)
	carveRivers(map, S, srcLevel)
	carveBigLake(map, S)
	carveHotPools(map)
	progress("Ghiacciai", 0)
	map.features.glaciers = {}
	for k, def in cfg.GLACIERS or {} do
		carveGlacier(map, def, k)
	end
	carveIceCaps(map)
	carveToxicValley(map)
	progress("Vetta e sentiero", 0)
	carveSummit(map)
	carvePath(map)
	carveCrevasses(map)
	progress("Strada", 0)
	carveRoad(map)
	carvePonds(map, S)
	clampWaterDepth(map)
	sealWaterEdges(map)
	yield()

	paintMaterials(map, S, yield, progress)

	local HUB = cfg.HUB
	map.features.hub = { x = HUB.X, y = sampleH(map, HUB.X, HUB.Z), z = HUB.Z }
	local campX, campZ = HUB.X + HUB.CAMP.DX, HUB.Z + HUB.CAMP.DZ
	map.features.campCenter = { x = campX, y = sampleH(map, campX, campZ), z = campZ }
	return map
end

return Heightmap
