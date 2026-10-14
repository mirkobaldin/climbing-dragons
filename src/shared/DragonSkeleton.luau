--!strict
-- Riconoscimento dello scheletro dei draghi dalla FORMA (non dai nomi delle ossa): i draghi di
-- Meshy hanno ossa Bone_000.. con nomi che non dicono niente e ogni modello (giovane e adulto) ha
-- un ordine diverso. Qui, dalle posizioni a riposo e dai genitori, si trovano: bacino, colonna,
-- petto, collo, testa (con mascella, muso e corna separati), coda, 4 zampe (davanti/dietro, lato,
-- osso del piede) e ali (braccio e dita).
-- Puro (solo Vector3): lo usano client/DragonProcedural e i test in tools/anim_test.
--
-- Rispetto a MapGen.AnimDraghi.analizza: la' il collo seguiva un ramo a caso della testa e in
-- Gas giovane, Roccia adulto ed Eclissi adulto finiva in un corno (scheletri esportati il
-- 2026-10-14). Qui la testa e' l'osso dove il collo si divide; la mascella e' il ramo piu' basso
-- fra quelli che vanno avanti (solo se ce ne sono almeno due, se no non si sa quale sia), i rami
-- che vanno indietro sono corna o cresta.

local DragonSkeleton = {}

export type BoneIn = { pos: Vector3, parent: number } -- indici da 1, parent 0 = nessun osso
export type Leg = {
	chain: { number }, -- dall'attacco al corpo fino al piede (incluso)
	toe: number?, -- punta delle dita dopo il piede, se c'e'
	front: boolean,
	side: number, -- +1 destra, -1 sinistra (rispetto a fwd)
}
export type Wing = { arm: { number }, fingers: { { number } }, side: number }
export type Skeleton = {
	root: number,
	hips: number,
	spine: { number }, -- fra bacino e petto (esclusi)
	chest: number,
	neck: { number }, -- dalla base del collo fino all'osso prima della testa
	head: number,
	jaw: { number }, -- vuota se la mascella non si distingue
	snout: { { number } },
	horns: { { number } },
	tail: { number },
	legs: { Leg },
	wings: { Wing },
	fwd: Vector3, -- avanti (orizzontale), nello spazio delle posizioni date
	right: Vector3,
	ground: number, -- Y piu' bassa (i piedi)
	height: number,
	length: number,
	warnings: { string },
}

local UP = Vector3.new(0, 1, 0)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function DragonSkeleton.analyze(bones: { BoneIn }): (Skeleton?, string?)
	local n = #bones
	if n < 8 then
		return nil, "troppe poche ossa (" .. n .. ")"
	end
	local kids: { { number } } = {}
	for i = 1, n do
		kids[i] = {}
	end
	for i, b in bones do
		if b.parent > 0 and b.parent <= n then
			table.insert(kids[b.parent], i)
		end
	end
	local function pos(i: number): Vector3
		return bones[i].pos
	end
	-- sotto-albero (lista di indici) con cache
	local subCache: { [number]: { number } } = {}
	local function sub(i: number): { number }
		local c = subCache[i]
		if c then
			return c
		end
		local out = { i }
		local k = 1
		while k <= #out do
			for _, ch in kids[out[k]] do
				table.insert(out, ch)
			end
			k += 1
		end
		subCache[i] = out
		return out
	end
	local function isChain(i: number): boolean
		for _, j in sub(i) do
			if #kids[j] > 1 then
				return false
			end
		end
		return true
	end
	local function follow(i: number): { number }
		-- catena semplice da i finche' non si divide o finisce (l'osso che si divide e' incluso)
		local out = { i }
		local cur = i
		while #kids[cur] == 1 do
			cur = kids[cur][1]
			table.insert(out, cur)
		end
		return out
	end
	local function farthest(i: number, from: Vector3): Vector3
		local best, bd = pos(i), -1
		for _, j in sub(i) do
			local d = (pos(j) - from).Magnitude
			if d > bd then
				best, bd = pos(j), d
			end
		end
		return best
	end

	-- radice: l'osso senza genitore con il sotto-albero piu' grande
	local root = 0
	for i, b in bones do
		if b.parent == 0 and (root == 0 or #sub(i) > #sub(root)) then
			root = i
		end
	end
	if root == 0 then
		return nil, "nessun osso radice"
	end
	local ground, top = math.huge, -math.huge
	for _, b in bones do
		ground = math.min(ground, b.pos.Y)
		top = math.max(top, b.pos.Y)
	end
	local height = math.max(top - ground, 1e-3)
	local function minY(i: number): number
		local m = math.huge
		for _, j in sub(i) do
			m = math.min(m, pos(j).Y)
		end
		return m
	end
	local function reachesGround(i: number): boolean
		return minY(i) < ground + 0.18 * height
	end

	-- bacino: il primo osso dalla radice che si divide in almeno 3 rami (colonna, zampe, coda)
	local hips = root
	while #kids[hips] == 1 do
		hips = kids[hips][1]
	end
	if #kids[hips] < 3 then
		return nil, "bacino non trovato (l'osso che si divide ha " .. #kids[hips] .. " rami)"
	end
	local hipsPos = pos(hips)
	-- colonna: il ramo del bacino con piu' ossa
	local spineKid = kids[hips][1]
	for _, k in kids[hips] do
		if #sub(k) > #sub(spineKid) then
			spineKid = k
		end
	end
	-- avanti: dal bacino al primo osso dove la colonna si divide (il petto o quasi). Il
	-- baricentro del ramo non va bene: le ali dell'Eclissi adulto arrivano oltre la coda
	local spineRun = follow(spineKid)
	local f = flat(pos(spineRun[#spineRun]) - hipsPos)
	if f.Magnitude < 1e-3 then
		local centroid = Vector3.zero
		for _, j in sub(spineKid) do
			centroid += pos(j)
		end
		f = flat(centroid / #sub(spineKid) - hipsPos)
	end
	if f.Magnitude < 1e-4 then
		return nil, "direzione avanti non trovata"
	end
	local fwd = f.Unit
	local right = fwd:Cross(UP).Unit
	local function lateral(p: Vector3): number
		return (p - hipsPos):Dot(right)
	end
	local function midline(i: number): boolean
		-- l'attacco E la punta vicini al centro (le ali possono attaccarsi quasi al centro)
		return math.abs(lateral(pos(i))) < 0.05 * height and math.abs(lateral(farthest(i, pos(i)))) < 0.15 * height
	end
	local function sideOf(i: number): number
		local s = lateral(farthest(i, pos(i)))
		if math.abs(lateral(pos(i))) > 1e-3 then
			s = lateral(pos(i))
		end
		return if s >= 0 then 1 else -1
	end

	local warnings: { string } = {}
	local legs: { Leg } = {}
	local wings: { Wing } = {}
	local function addLeg(k: number, front: boolean)
		local chain = follow(k)
		-- piede: l'osso piu' basso dal terzo in poi (a pari altezza il primo: pianta, poi dita)
		local foot = #chain
		local low = math.huge
		for idx = math.min(3, #chain), #chain do
			local y = pos(chain[idx]).Y
			if y < low - 0.01 * height then
				low = y
				foot = idx
			end
		end
		local legChain = table.move(chain, 1, foot, 1, {})
		table.insert(legs, { chain = legChain, toe = chain[foot + 1], front = front, side = sideOf(k) })
	end
	local function addWing(k: number)
		local arm = follow(k)
		local fingers: { { number } } = {}
		for _, ch in kids[arm[#arm]] do
			table.insert(fingers, follow(ch))
		end
		table.insert(wings, { arm = arm, fingers = fingers, side = sideOf(k) })
	end

	-- rami del bacino: zampe posteriori e coda
	local tail: { number } = {}
	for _, k in kids[hips] do
		if k == spineKid then
			continue
		end
		if reachesGround(k) and not midline(k) then
			addLeg(k, false)
		elseif (farthest(k, hipsPos) - hipsPos):Dot(fwd) < 0 then
			local c = follow(k)
			if #c > #tail then
				tail = c
			end
		else
			table.insert(warnings, "ramo del bacino non riconosciuto: osso " .. k)
		end
	end

	-- colonna fino al petto: dove si attaccano zampe anteriori, ali e collo
	local spine: { number } = {}
	local chest = spineKid
	local neckRoot = 0
	local cur = spineKid
	while true do
		local ks = kids[cur]
		if #ks == 0 then
			break
		elseif #ks == 1 then
			table.insert(spine, cur)
			cur = ks[1]
			continue
		end
		local cont = 0
		local neckCand = 0
		local hadLegs = false
		for _, k in ks do
			if midline(k) then
				if reachesGround(k) and not isChain(k) then
					cont = k -- la colonna continua (le zampe sono piu' avanti)
				elseif neckCand == 0 or (farthest(k, pos(cur)) - pos(cur)):Dot(fwd) > (farthest(neckCand, pos(cur)) - pos(cur)):Dot(fwd) then
					neckCand = k
				end
			elseif reachesGround(k) then
				addLeg(k, true)
				hadLegs = true
			else
				addWing(k)
			end
		end
		if hadLegs or cont == 0 then
			chest = cur
		end
		if cont ~= 0 then
			table.insert(spine, cur)
			if neckCand ~= 0 then
				neckRoot = neckCand
			end
			cur = cont
			continue
		end
		if neckCand ~= 0 then
			neckRoot = neckCand
		end
		break
	end
	-- la lista della colonna non deve contenere il petto
	for i = #spine, 1, -1 do
		if spine[i] == chest then
			table.remove(spine, i)
		end
	end
	if neckRoot == 0 then
		return nil, "collo non trovato"
	end

	-- collo e testa
	local neckChain = follow(neckRoot)
	local headIdx = neckChain[#neckChain]
	local jaw: { number } = {}
	local snout: { { number } } = {}
	local horns: { { number } } = {}
	if #kids[headIdx] >= 2 then
		local hp = pos(headIdx)
		local forward: { { c: { number }, d: Vector3 } } = {}
		for _, k in kids[headIdx] do
			local c = follow(k)
			local d = farthest(k, hp) - hp
			if d:Dot(fwd) > 0 then
				table.insert(forward, { c = c, d = d })
			else
				table.insert(horns, c)
			end
		end
		-- mascella: il ramo in avanti che scende di piu', solo se i rami in avanti sono due o piu'
		table.sort(forward, function(a, b)
			return a.d.Y > b.d.Y
		end)
		for idx, fb in forward do
			if idx == #forward and #forward >= 2 and fb.d.Y < 0 then
				jaw = fb.c
			else
				table.insert(snout, fb.c)
			end
		end
		table.remove(neckChain, #neckChain)
	else
		-- il collo non si divide: testa = l'osso piu' alto fra gli ultimi 4 (dopo, il muso scende)
		local best = #neckChain
		for idx = math.max(1, #neckChain - 3), #neckChain do
			if pos(neckChain[idx]).Y > pos(neckChain[best]).Y + 1e-4 then
				best = idx
			end
		end
		if best == #neckChain and #neckChain > 2 then
			best = #neckChain - 1
		end
		headIdx = neckChain[best]
		local rest = table.move(neckChain, best + 1, #neckChain, 1, {})
		if #rest > 0 then
			table.insert(snout, rest)
		end
		neckChain = table.move(neckChain, 1, best - 1, 1, {})
		table.insert(warnings, "il collo non si divide: mascella non separabile")
	end

	local nf, nb = 0, 0
	for _, l in legs do
		if l.front then
			nf += 1
		else
			nb += 1
		end
	end
	if nf ~= 2 or nb ~= 2 then
		table.insert(warnings, string.format("zampe: %d davanti, %d dietro", nf, nb))
	end
	if #wings ~= 2 then
		table.insert(warnings, "ali: " .. #wings)
	end
	if #tail == 0 then
		table.insert(warnings, "coda non trovata")
	end
	local lo, hi = math.huge, -math.huge
	for _, b in bones do
		local d = b.pos:Dot(fwd)
		lo = math.min(lo, d)
		hi = math.max(hi, d)
	end
	return {
		root = root,
		hips = hips,
		spine = spine,
		chest = chest,
		neck = neckChain,
		head = headIdx,
		jaw = jaw,
		snout = snout,
		horns = horns,
		tail = tail,
		legs = legs,
		wings = wings,
		fwd = fwd,
		right = right,
		ground = ground,
		height = height,
		length = hi - lo,
		warnings = warnings,
	}, nil
end

return DragonSkeleton
