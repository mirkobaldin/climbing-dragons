--!strict
-- Generatore delle animazioni dei draghi (strumento di Studio: non gira nel gioco).
-- Dalla Command Bar di Studio:
--   require(game.ServerStorage.MapGen.AnimDraghi).genera()               -- tutti i rig
--   require(game.ServerStorage.MapGen.AnimDraghi).genera("Drago_Gelo")   -- uno solo
-- Per ogni rig in Workspace.RigDraghi (scheletri di Meshy: Bone_000, Bone_001...) riconosce dalla
-- forma dello scheletro anca, colonna, petto, coda, zampe, ali e collo, e crea in
-- ServerStorage.RBX_ANIMSAVES.<rig> tre animazioni che si aprono nell'Animation Editor:
--   drago-volo (1.2 s)   drago-cammina (1.0 s)   drago-fermo (2.4 s)   drago-picchiata (0.8 s)
--   drago-librato (0.9 s, fermo in aria)   drago-planata (3 s)
--   in monta: drago-virata-sx, drago-virata-dx (1.2 s), drago-salita (0.9 s), drago-discesa (2.4 s)
--   una volta sola: drago-ruggito (2.2 s)   drago-soffio (2.0 s)   drago-morso (1.0 s)   drago-colpito (0.6 s)
-- Le curve vengono dal mocap (dataset MoCapAnything, animali "zoo"): battito d'ali del tucano,
-- passo, bacino e coda del giaguaro, respiro del leopardo; i ritardi lungo l'ala dalla viverna.
-- Il verso di ogni rotazione si decide provandola sul rig (es. quale verso alza la punta dell'ala).
-- Le animazioni con lo stesso nome gia' presenti finiscono in ServerStorage.BackupAnimazioni.

-- Un ciclo per giunto: 16 campioni (-1..1) e ampiezza in gradi (estratti dai BVH)
local MOCAP = {
	fly = {
		wing = { amp = 46.6, wave = { 0.653, 0.72, 0.641, 0.427, -0.019, -0.511, -0.885, -1, -0.921, -0.697, -0.393, -0.065, 0.232, 0.468, 0.634, 0.718 } },
		elbow = { amp = 27.3, wave = { 0.455, 0.653, 0.789, 0.856, 0.824, 0.685, 0.469, 0.198, -0.136, -0.517, -0.794, -0.913, -1, -0.972, -0.602, 0.006 } },
		leg = { amp = 22, wave = { 0.864, 0.651, 0.465, 0.328, 0.175, 0.105, 0.046, -0.493, -0.929, -1, -0.812, -0.505, -0.191, 0.156, 0.454, 0.687 } },
		hips = { amp = 6.1, wave = { -0.283, 0.275, 0.687, 0.922, 1, 0.853, 0.524, 0.196, -0.072, -0.26, -0.413, -0.553, -0.701, -0.807, -0.773, -0.595 } },
		chest = { amp = 5, wave = { -0.239, -0.066, 0.296, 0.591, 0.834, 1, 0.876, 0.626, 0.415, 0.135, -0.353, -0.831, -0.99, -0.925, -0.821, -0.545 } },
		head = { amp = 11.2, wave = { -1, -0.835, -0.684, -0.453, -0.18, 0.082, 0.367, 0.639, 0.836, 0.866, 0.739, 0.563, 0.3, -0.038, -0.423, -0.78 } },
	},
	walk = {
		thigh = { amp = 18, wave = { 0.585, 0.7, 0.834, 0.863, 0.745, 0.553, 0.316, 0.062, -0.193, -0.452, -0.754, -1, -0.974, -0.725, -0.459, -0.102 } },
		shin = { amp = 39.8, wave = { -0.762, -0.629, -0.382, -0.124, 0.094, 0.321, 0.543, 0.736, 0.87, 0.907, 0.757, 0.441, -0.166, -0.786, -1, -0.82 } },
		ankle = { amp = 44.2, wave = { 0.969, 0.794, 0.47, 0.142, -0.122, -0.395, -0.655, -0.871, -1, -0.949, -0.596, -0.209, 0.181, 0.548, 0.789, 0.904 } },
		foot = { amp = 34.8, wave = { -1, -0.536, -0.092, 0.232, 0.422, 0.551, 0.629, 0.663, 0.646, 0.506, 0.144, -0.151, -0.274, -0.365, -0.552, -0.822 } },
		arm = { amp = 37, wave = { -1, -0.468, -0.202, -0.234, -0.2, -0.129, -0.036, 0.121, 0.233, 0.281, 0.416, 0.519, 0.53, 0.454, 0.173, -0.457 } },
		forearm = { amp = 40.3, wave = { -0.02, -0.695, -0.745, -0.216, 0.244, 0.625, 0.875, 1, 0.95, 0.704, 0.301, -0.144, -0.563, -0.86, -0.909, -0.548 } },
		hand = { amp = 13.4, wave = { 0.044, 1, 0.672, -0.515, -0.522, -0.177, 0.03, 0.068, 0.024, -0.015, -0.067, -0.124, -0.173, -0.2, -0.128, 0.084 } },
		pelvis = { amp = 18.5, wave = { 1, 0.88, 0.548, 0.239, 0.092, 0.01, -0.05, -0.115, -0.22, -0.461, -0.851, -0.938, -0.665, -0.273, 0.182, 0.623 } },
		spine = { amp = 12.8, wave = { -0.65, -0.215, 0.461, 0.936, 1, 0.869, 0.629, 0.347, 0.087, -0.128, -0.32, -0.442, -0.534, -0.627, -0.699, -0.714 } },
		spine1 = { amp = 27.7, wave = { -1, -0.763, -0.463, -0.198, -0.015, 0.137, 0.27, 0.387, 0.492, 0.6, 0.67, 0.579, 0.324, 0.008, -0.343, -0.686 } },
		head = { amp = 16.1, wave = { 0.447, 0.616, 0.911, 1, 0.757, 0.379, -0.05, -0.474, -0.827, -0.986, -0.81, -0.583, -0.395, -0.203, 0.001, 0.215 } },
		tail1 = { amp = 14.6, wave = { -0.799, -0.48, -0.114, 0.205, 0.442, 0.647, 0.801, 0.888, 0.873, 0.751, 0.472, -0.042, -0.707, -0.986, -1, -0.951 } },
		tail2 = { amp = 32.8, wave = { -1, -0.593, -0.13, 0.27, 0.517, 0.631, 0.644, 0.589, 0.492, 0.389, 0.311, 0.139, -0.233, -0.49, -0.675, -0.86 } },
		tail3 = { amp = 32.8, wave = { -1, -0.853, -0.635, -0.36, -0.008, 0.348, 0.582, 0.651, 0.656, 0.638, 0.607, 0.485, 0.186, -0.125, -0.434, -0.739 } },
		tail4 = { amp = 34.6, wave = { -0.921, -0.901, -0.909, -0.78, -0.482, -0.164, 0.147, 0.448, 0.774, 1, 0.981, 0.81, 0.537, 0.198, -0.18, -0.557 } },
	},
	idle = {
		head = { amp = 4.4, wave = { 1, 0.886, 0.673, 0.409, 0.147, -0.098, -0.356, -0.595, -0.779, -0.848, -0.824, -0.657, -0.35, 0.058, 0.49, 0.844 } },
		neck = { amp = 0, wave = { -0.685, -0.875, 0.264, -0.424, -0.021, -0.733, -0.638, -0.187, 0.264, 0.098, 0.027, 0.098, 0.169, 1, 0.786, 0.858 } },
		spine = { amp = 0.8, wave = { -0.665, -0.355, 0.142, 0.65, 0.996, 1, 0.669, 0.236, -0.066, -0.172, -0.198, -0.217, -0.277, -0.432, -0.613, -0.698 } },
		pelvis = { amp = 4.2, wave = { 0.192, -0.144, -0.562, -0.909, -1, -0.906, -0.692, -0.41, -0.092, 0.232, 0.53, 0.771, 0.926, 0.883, 0.725, 0.457 } },
	},
}

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local AnimDraghi = {}

local UP = Vector3.yAxis

-- valore di un ciclo del mocap a una fase (0..1), interpolato tra i 16 campioni
local function wave(clip: string, joint: string, phase: number): number
	local w = (MOCAP :: any)[clip][joint].wave
	local n = #w
	local x = (phase % 1) * n
	local i = math.floor(x)
	local f = x - i
	local a, b = w[i % n + 1], w[(i + 1) % n + 1]
	return a + (b - a) * f
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.zAxis
end

------------------------------------------------------------------------------------------
-- Scheletro: chi e' chi, dalla forma

type Leg = { bones: { Bone }, side: number, front: boolean, phase: number }
type Wing = { arm: { Bone }, fingers: { { Bone } }, side: number, tip: Bone }
type Skel = {
	rig: Model,
	mesh: MeshPart,
	rest: { [Bone]: CFrame },
	hips: Bone,
	spine: { Bone },
	chest: Bone,
	tail: { Bone },
	neck: { Bone },
	legs: { Leg },
	wings: { Wing },
	fwd: Vector3,
	right: Vector3,
	height: number,
	groundY: number,
}

local function kids(b: Instance): { Bone }
	local list = {}
	for _, c in b:GetChildren() do
		if c:IsA("Bone") then
			table.insert(list, c)
		end
	end
	return list
end

local function count(b: Bone): number
	local n = 1
	for _, c in kids(b) do
		n += count(c)
	end
	return n
end

-- la catena principale da un osso: si scende sempre nel figlio con piu' ossa
local function mainChain(b: Bone): { Bone }
	local chain = { b }
	local cur = b
	while true do
		local best, bestN = nil, 0
		for _, c in kids(cur) do
			local n = count(c)
			if n > bestN then
				best, bestN = c, n
			end
		end
		if not best then
			break
		end
		table.insert(chain, best)
		cur = best
	end
	return chain
end

local function leafAverage(b: Bone): (Vector3, number)
	local sum, n, minY = Vector3.zero, 0, math.huge
	local function walk(x: Bone)
		local k = kids(x)
		if #k == 0 then
			sum += x.WorldPosition
			n += 1
			minY = math.min(minY, x.WorldPosition.Y) -- solo le punte: la base di un collo basso non conta
		end
		for _, c in k do
			walk(c)
		end
	end
	walk(b)
	return sum / math.max(n, 1), minY
end

function AnimDraghi.analizza(rig: Model): Skel
	local mesh = rig:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart
	assert(mesh, rig.Name .. ": nessuna MeshPart")
	local rest: { [Bone]: CFrame } = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Bone") then
			d.Transform = CFrame.identity
		end
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("Bone") then
			rest[d] = d.WorldCFrame
		end
	end
	-- radice: il primo osso della mesh (quello con piu' ossa sotto)
	local top: Bone? = nil
	for _, c in kids(mesh) do
		if not top or count(c) > count(top :: Bone) then
			top = c
		end
	end
	assert(top, rig.Name .. ": nessun osso")
	-- anca: si scende finche' l'osso ha un figlio solo
	local hips = top :: Bone
	while #kids(hips) == 1 do
		hips = kids(hips)[1]
	end
	-- colonna: il ramo piu' grande dell'anca, fino al primo bivio (il petto)
	local spineRoot: Bone? = nil
	for _, c in kids(hips) do
		if not spineRoot or count(c) > count(spineRoot :: Bone) then
			spineRoot = c
		end
	end
	local spine: { Bone } = {}
	local chest = spineRoot :: Bone
	while #kids(chest) == 1 do
		table.insert(spine, chest)
		chest = kids(chest)[1]
	end
	local fwd = flat(chest.WorldPosition - hips.WorldPosition)
	local right = fwd:Cross(UP)
	local cf, size = rig:GetBoundingBox()
	local groundY = cf.Position.Y - size.Y / 2
	local height = size.Y
	local sk: Skel = {
		rig = rig, mesh = mesh, rest = rest, hips = hips, spine = spine, chest = chest,
		tail = {}, neck = {}, legs = {}, wings = {}, fwd = fwd, right = right, height = height, groundY = groundY,
	}
	-- dall'anca: la coda (va piu' indietro) e le zampe posteriori
	local tailRoot, tailBack = nil, -math.huge
	for _, c in kids(hips) do
		if c ~= spineRoot then
			local avg = leafAverage(c)
			local back = -(avg - hips.WorldPosition):Dot(fwd)
			if back > tailBack then
				tailRoot, tailBack = c, back
			end
		end
	end
	if tailRoot then
		sk.tail = mainChain(tailRoot)
	end
	for _, c in kids(hips) do
		if c ~= spineRoot and c ~= tailRoot then
			local avg = leafAverage(c)
			local side = if (avg - hips.WorldPosition):Dot(right) >= 0 then 1 else -1
			table.insert(sk.legs, { bones = mainChain(c), side = side, front = false, phase = 0 })
		end
	end
	-- dal petto: zampe anteriori (arrivano a terra), ali (larghe, si dividono in dita), collo.
	-- In alcuni scheletri (es. Roccia) dal petto partono solo le ali e un ramo che piu' avanti si
	-- divide in collo e zampe anteriori: quel ramo e' la continuazione del petto, si segue.
	local neckRoot, neckScore = nil, -math.huge
	local function leafSpan(c: Bone): (number, number, number)
		local lo, hi, n = math.huge, -math.huge, 0
		local function walk(x: Bone)
			local k = kids(x)
			if #k == 0 then
				lo = math.min(lo, x.WorldPosition.Y)
				hi = math.max(hi, x.WorldPosition.Y)
				n += 1
			end
			for _, y in k do
				walk(y)
			end
		end
		walk(c)
		return lo, hi, n
	end
	local function classify(hub: Bone)
		for _, c in kids(hub) do
			local avg, minY = leafAverage(c)
			local rel = avg - hub.WorldPosition
			local lateral = math.abs(rel:Dot(right))
			local lo, hi, leaves = leafSpan(c)
			if leaves >= 3 and lo - groundY < height * 0.2 and hi - groundY > height * 0.45 and lateral < height * 0.15 then
				-- collo e zampe insieme: si segue il ramo fino al bivio e si continua da li'
				local cur = c
				while #kids(cur) == 1 do
					table.insert(sk.spine, cur)
					cur = kids(cur)[1]
				end
				table.insert(sk.spine, cur)
				classify(cur)
			elseif minY - groundY < height * 0.2 then
				table.insert(sk.legs, { bones = mainChain(c), side = if rel:Dot(right) >= 0 then 1 else -1, front = true, phase = 0 })
			elseif lateral > height * 0.18 or count(c) >= 7 and lateral > height * 0.1 then
				-- ala: braccio fino al bivio, poi le dita
				local arm = { c }
				local cur = c
				while #kids(cur) == 1 do
					cur = kids(cur)[1]
					table.insert(arm, cur)
				end
				local fingers = {}
				for _, f in kids(cur) do
					table.insert(fingers, mainChain(f))
				end
				-- la punta: la foglia piu' lontana dal petto
				local tip, far = arm[#arm], 0
				for _, chain in fingers do
					local last = chain[#chain]
					local d = (last.WorldPosition - chest.WorldPosition).Magnitude
					if d > far then
						tip, far = last, d
					end
				end
				table.insert(sk.wings, { arm = arm, fingers = fingers, side = if rel:Dot(right) >= 0 then 1 else -1, tip = tip })
			else
				local score = rel:Dot(fwd) + rel.Y * 0.5 - lateral
				if score > neckScore then
					neckRoot, neckScore = c, score
				end
			end
		end
	end
	classify(chest)
	if neckRoot then
		sk.neck = mainChain(neckRoot)
	end
	-- passo a quattro tempi: posteriore sx, anteriore sx, posteriore dx, anteriore dx
	for _, leg in sk.legs do
		leg.phase = (if leg.front then 0.25 else 0) + (if leg.side > 0 then 0.5 else 0)
	end
	return sk
end

------------------------------------------------------------------------------------------
-- Rotazioni negli assi del corpo, portate nello spazio dell'osso

local function bodyRot(sk: Skel, b: Bone, axis: Vector3, deg: number): CFrame
	local Q = sk.rest[b].Rotation
	return Q:Inverse() * CFrame.fromAxisAngle(axis, math.rad(deg)) * Q
end

-- verso giusto di una rotazione: si prova davvero e si guarda dove va la punta
local function signFor(sk: Skel, b: Bone, axis: Vector3, tip: Bone, measure: (Vector3) -> number): number
	local before = tip.WorldPosition
	local old = b.Transform
	b.Transform = bodyRot(sk, b, axis, 8)
	local moved = tip.WorldPosition - before
	b.Transform = old
	return if measure(moved) >= 0 then 1 else -1
end

type Poses = { [Bone]: CFrame }
local function add(poses: Poses, sk: Skel, b: Bone, axis: Vector3, deg: number)
	if math.abs(deg) < 1e-3 then
		poses[b] = poses[b] or CFrame.identity
		return
	end
	poses[b] = (poses[b] or CFrame.identity) * bodyRot(sk, b, axis, deg)
end

------------------------------------------------------------------------------------------
-- Le tre animazioni

type Signs = { [string]: number }

-- quanto si sposta la punta (col segno) provando la rotazione
local function moveFor(sk: Skel, b: Bone, axis: Vector3, tip: Bone, measure: (Vector3) -> number): number
	local before = tip.WorldPosition
	local old = b.Transform
	b.Transform = bodyRot(sk, b, axis, 8)
	local moved = tip.WorldPosition - before
	b.Transform = old
	return measure(moved)
end

local function computeSigns(sk: Skel): Signs
	local s: Signs = {}
	-- Ali: le rotazioni attorno all'asse verticale e a quello avanti-indietro di un'ala sono lo
	-- specchio di quelle dell'altra (verso opposto). Il verso si misura sull'ala dove la prova e'
	-- piu' netta e l'altra lo prende specchiato: prima ogni ala faceva la sua prova e su alcuni
	-- draghi una si chiudeva all'indietro e l'altra in avanti (ali storte, una "arrotolata").
	local tests = {
		flap = function(w: Wing) return moveFor(sk, w.arm[1], sk.fwd, w.tip, function(m) return m.Y end) end, -- + = punta su
		sweep = function(w: Wing) return moveFor(sk, w.arm[1], UP, w.tip, function(m) return -m:Dot(sk.fwd) end) end, -- + = punta indietro
		fold = function(w: Wing) return if w.arm[2] then moveFor(sk, w.arm[2], UP, w.tip, function(m) return -m:Dot(sk.fwd) end) else 0 end,
	}
	for key, test in tests do
		local values = {}
		for i, w in sk.wings do
			values[i] = test(w)
		end
		local ref = 1
		for i in sk.wings do
			if math.abs(values[i]) > math.abs(values[ref]) then
				ref = i
			end
		end
		local refSign = if (values[ref] or 0) >= 0 then 1 else -1
		for i, w in sk.wings do
			local same = sk.wings[ref] == nil or w.side == sk.wings[ref].side
			s[key .. i] = if same then refSign else -refSign
		end
	end
	for i, leg in sk.legs do
		local foot = leg.bones[#leg.bones]
		s["swing" .. i] = signFor(sk, leg.bones[1], sk.right, foot, function(m) return m:Dot(sk.fwd) end) -- + = zampa avanti
		if leg.bones[2] then
			s["lift" .. i] = signFor(sk, leg.bones[2], sk.right, foot, function(m) return m.Y end) -- + = piede su
		end
	end
	if #sk.tail > 0 then
		local tip = sk.tail[#sk.tail]
		s.tailYaw = signFor(sk, sk.tail[1], UP, tip, function(m) return m:Dot(sk.right) end)
		s.tailPitch = signFor(sk, sk.tail[1], sk.right, tip, function(m) return m.Y end)
	end
	-- impennata: verso della rotazione dell'anca che alza il petto
	s.bodyPitch = signFor(sk, sk.hips, sk.right, sk.chest, function(m) return m.Y end)
	if #sk.neck > 0 then
		local head = sk.neck[#sk.neck]
		s.neckPitch = signFor(sk, sk.neck[1], sk.right, head, function(m) return m.Y end) -- + = testa su
		s.neckYaw = signFor(sk, sk.neck[1], UP, head, function(m) return m:Dot(sk.right) end)
	end
	return s
end

-- Ali piegate (camminata e fermo): indietro, un po' giu', avambraccio e dita chiusi. Gli angoli
-- non sono fissi: prima erano uguali per tutti e su molti draghi l'avambraccio passava oltre la
-- schiena, sopra l'altra ala. Per ogni ala si cerca sul rig la piega piu' raccolta in cui
--   * nessun osso dell'ala passa oltre la meta' della distanza tra la schiena e la spalla;
--   * nessun osso scende sotto il 40% dell'altezza (dentro le zampe);
--   * la punta resta dietro la spalla.
-- amount 1 = chiuse del tutto, 0.6 = "un attimo piegate"
type Fold = { sweep: number, down: number, elbow: number, finger: number }

local function foldPoses(poses: Poses, sk: Skel, s: Signs, i: number, w: Wing, f: Fold, breathe: number)
	add(poses, sk, w.arm[1], UP, s["sweep" .. i] * f.sweep)
	add(poses, sk, w.arm[1], sk.fwd, -s["flap" .. i] * (f.down - breathe))
	if w.arm[2] then
		add(poses, sk, w.arm[2], UP, (s["fold" .. i] or 1) * f.elbow)
	end
	for _, finger in w.fingers do
		add(poses, sk, finger[1], UP, (s["fold" .. i] or 1) * f.finger)
	end
end

local function wingBones(w: Wing): { Bone }
	local list = table.clone(w.arm)
	for _, chain in w.fingers do
		for _, b in chain do
			table.insert(list, b)
		end
	end
	return list
end

local function bestFold(sk: Skel, s: Signs, i: number, w: Wing, amount: number): Fold
	local bones = wingBones(w)
	local shoulder = sk.rest[w.arm[1]].Position
	local mid = sk.rest[sk.chest].Position
	local lateral0 = (shoulder - mid):Dot(sk.right) * w.side
	-- nessun osso piu' vicino alla schiena della spalla: prima bastava meta' strada e le due ali
	-- piegate si alzavano ad arco fino a toccarsi sopra il dorso
	local minLateral = math.max(lateral0, sk.height * 0.1)
	local floorY = sk.groundY + sk.height * 0.4
	local backY = mid.Y + sk.height * 0.12 -- sopra questa quota l'ala fa "la cupola" sul dorso
	-- un osso che a riposo e' gia' piu' in basso o piu' vicino alla schiena puo' restarci
	local limit: { [Bone]: { lat: number, y: number } } = {}
	for _, b in bones do
		local p = sk.rest[b].Position
		limit[b] = { lat = math.min(minLateral, (p - mid):Dot(sk.right) * w.side - 0.5), y = math.min(floorY, p.Y - 0.5) }
	end
	local best, bestScore = { sweep = 0, down = 0, elbow = 0, finger = 0 }, math.huge
	for _, sweep in { 0, 15, 30, 45, 60, 75 } do
		for _, down in { -10, 0, 15, 30, 45, 60 } do
			for _, elbow in { 0, 20, 40, 60, 80, 100 } do
				for _, finger in { 0, 15, 30, 45 } do
					local f = { sweep = sweep * amount, down = down * amount, elbow = elbow * amount, finger = finger * amount }
					local poses: Poses = {}
					foldPoses(poses, sk, s, i, w, f, 0)
					for b, cf in poses do
						b.Transform = cf
					end
					local ok, wide, high = true, 0, 0
					for _, b in bones do
						local p = b.WorldPosition
						local lat = (p - mid):Dot(sk.right) * w.side
						if lat < limit[b].lat or p.Y < limit[b].y then
							ok = false
							break
						end
						wide = math.max(wide, lat)
						high = math.max(high, p.Y - backY)
					end
					-- la mesh va oltre l'ultimo osso di ogni dito: si controlla anche la punta
					-- prolungata (prima le punte si incrociavano sopra la coda)
					if ok then
						local chains = if #w.fingers > 0 then w.fingers else { w.arm }
						for _, chain in chains do
							local n = #chain
							if n >= 2 then
								local a, b = chain[n - 1].WorldPosition, chain[n].WorldPosition
								local tipX = b + (b - a) * 1.2
								if (tipX - mid):Dot(sk.right) * w.side < minLateral * 0.8 then
									ok = false
									break
								end
							end
						end
					end
					local tip = w.tip.WorldPosition
					for b in poses do
						b.Transform = CFrame.identity
					end
					if ok then
						-- stretta lungo il fianco, bassa (niente cupola sul dorso), punta verso la coda
						local score = wide + 2 * math.max(0, high) + 0.6 * (tip - shoulder):Dot(sk.fwd)
						if score < bestScore then
							best, bestScore = f, score
						end
					end
				end
			end
		end
	end
	return best
end

local function foldWings(poses: Poses, sk: Skel, s: Signs, folds: { Fold }, breathe: number)
	for i, w in sk.wings do
		foldPoses(poses, sk, s, i, w, folds[i], breathe)
	end
end

local FLY_T, WALK_T, IDLE_T = 1.2, 1.0, 2.4
local KEYS = 16

-- campana liscia (0 ai bordi, 1 a meta') tra le fasi a e b del ciclo (modulo 1), 0 fuori
local function hump(p: number, a: number, b: number): number
	local len = (b - a) % 1
	local x = (p - a) % 1
	if x > len then
		return 0
	end
	return 0.5 - 0.5 * math.cos(2 * math.pi * x / len)
end
-- fasi del battito del tucano: ala piu' in basso e piu' in alto
local FLY_LOW, FLY_HIGH = 0.44, 0.08
-- ampiezza del battito per il rig in lavorazione: la si abbassa finche' nessun osso di un'ala
-- passa oltre la meta' del corpo (prima in alto le ali si incrociavano sopra la schiena)
local flyAmp = 1
-- ali aperte in volo: nei modelli le ali sono ripiegate all'indietro lungo il corpo, e battere
-- un'ala che punta indietro attorno all'asse avanti-indietro la faceva solo girare su se' stessa
-- (il drago sembrava una statua). Per ogni ala: gomito disteso, ala portata di lato (20 gradi
-- indietro) e appena sopra l'orizzontale; il battito parte da li'. Misurate sul rig.
type Spread = { elbow: number, sweep: number, elev: number }
local spreads: { Spread } = {}

-- angolo (gradi, col segno) per portare a su b girando attorno ad axis
local function signedAngle(a: Vector3, b: Vector3, axis: Vector3): number
	local pa = a - axis * a:Dot(axis)
	local pb = b - axis * b:Dot(axis)
	return math.deg(math.atan2(pa:Cross(pb):Dot(axis), pa:Dot(pb)))
end

local function buildFly(sk: Skel, s: Signs, t: number): Poses
	local poses: Poses = {}
	local p = t / FLY_T
	-- ali: il battito del tucano; le ossa verso la punta in ritardo (viverna)
	for i, w in sk.wings do
		local flap = s["flap" .. i]
		local lags = { 0, 0.08, 0.14, 0.2 }
		for k, b in w.arm do
			local lag = lags[math.min(k, #lags)]
			-- sulle ali a catena lunga (es. Roccia, 7 ossa in fila) le ossa in ritardo si sommavano
			-- e la punta faceva quasi un giro: l'ampiezza dopo il gomito si divide tra le ossa
			local amp = if k == 1 then 42 elseif k == 2 then 16 else 10 * math.min(1, 2 / math.max(#w.arm - 2, 1))
			add(poses, sk, b, sk.fwd, flap * amp * flyAmp * wave("fly", "wing", p - lag))
		end
		local sp = spreads[i]
		if sp then
			-- prima si apre l'ala (di lato, poi all'altezza giusta), il battito si somma sopra
			add(poses, sk, w.arm[1], sk.fwd, sp.elev)
			add(poses, sk, w.arm[1], UP, sp.sweep)
			if w.arm[2] then
				add(poses, sk, w.arm[2], UP, sp.elbow)
			end
		end
		-- risalita: avambraccio e dita si richiudono; discesa: le punte vanno avanti (l'ala si gonfia)
		-- a campana su tutta la risalita e la discesa: prima si accendeva di colpo al cambio e la
		-- punta dell'ala scattava in una sola chiave
		local up, down = hump(p, FLY_LOW, FLY_HIGH), hump(p, FLY_HIGH, FLY_LOW)
		if w.arm[2] then
			add(poses, sk, w.arm[2], UP, (s["fold" .. i] or 1) * 22 * up)
		end
		for _, finger in w.fingers do
			add(poses, sk, finger[1], UP, (s["fold" .. i] or 1) * (16 * up - 10 * down))
			if finger[2] then
				add(poses, sk, finger[2], sk.fwd, flap * 8 * wave("fly", "wing", p - 0.25))
			end
		end
	end
	-- corpo che segue il battito, testa in ritardo (ampiezze piccole: prima corpo, collo e coda
	-- ondeggiavano tutti insieme e il drago sembrava una banana che dondola)
	add(poses, sk, sk.hips, sk.right, 1.5 * wave("fly", "hips", p))
	for _, b in sk.spine do
		add(poses, sk, b, sk.right, 0.8 * wave("fly", "chest", p))
	end
	for k, b in sk.neck do
		local share = if k == #sk.neck then 0.4 else 0.6 / math.max(#sk.neck - 1, 1)
		add(poses, sk, b, sk.right, (s.neckPitch or 1) * 4 * share * wave("fly", "head", p))
	end
	-- zampe: raccolte all'indietro, penzolano appena col battito
	for i, leg in sk.legs do
		local tuck = if leg.front then -28 else -38
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * (tuck + 5 * wave("fly", "leg", p)))
		if leg.bones[2] then
			add(poses, sk, leg.bones[2], sk.right, (s["lift" .. i] or 1) * (16 + 5 * wave("fly", "leg", p - 0.12)))
		end
		if leg.bones[3] then
			add(poses, sk, leg.bones[3], sk.right, (s["lift" .. i] or 1) * -6 * wave("fly", "leg", p - 0.22))
		end
	end
	-- coda tesa: solo un'onda leggera verso la punta
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		add(poses, sk, b, UP, (s.tailYaw or 1) * (1.5 + 2.5 * f) * math.sin(2 * math.pi * (p - 0.1 * k)))
		add(poses, sk, b, sk.right, (s.tailPitch or 1) * 1.2 * wave("fly", "hips", p - 0.08 * k))
	end
	return poses
end

-- picchiata: ali chiuse strette all'indietro (le punte vibrano nel vento), collo teso in avanti,
-- zampe raccolte, coda dritta con un fremito
local DIVE_T = 0.8
local function buildDive(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / DIVE_T
	foldWings(poses, sk, s, folds, 3 * math.sin(4 * math.pi * p))
	for _, b in sk.neck do
		add(poses, sk, b, sk.right, (s.neckPitch or 1) * -5 / math.max(#sk.neck, 1))
	end
	for i, leg in sk.legs do
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * (if leg.front then -40 else -50))
		if leg.bones[2] then
			add(poses, sk, leg.bones[2], sk.right, (s["lift" .. i] or 1) * 30)
		end
	end
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		add(poses, sk, b, UP, (s.tailYaw or 1) * 2.5 * f * math.sin(2 * math.pi * (2 * p - 0.15 * k)))
	end
	return poses
end

local function buildWalk(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / WALK_T
	-- zampe: appoggio e volo. Prima la coscia oscillava avanti e indietro come un pendolo (le
	-- zampe "a dondolo"): ora per il 62% del passo il piede sta a terra e la zampa scorre
	-- indietro a velocita' costante, poi si stacca, il ginocchio si piega, torna avanti morbida
	-- e si distende prima di appoggiare.
	local STANCE = 0.62
	for i, leg in sk.legs do
		local ph = (p + leg.phase) % 1
		local swing, lift
		if ph < STANCE then
			swing = 1 - 2 * ph / STANCE
			lift = 0
		else
			local x = (ph - STANCE) / (1 - STANCE)
			swing = -1 + 2 * x * x * (3 - 2 * x)
			lift = math.sin(math.pi * x)
		end
		local amp = if leg.front then 20 else 24
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * amp * swing)
		if leg.bones[2] then
			add(poses, sk, leg.bones[2], sk.right, (s["lift" .. i] or 1) * 42 * lift)
		end
		if leg.bones[3] then
			-- piede: in volo le dita scendono, all'appoggio torna piatto
			add(poses, sk, leg.bones[3], sk.right, (s["lift" .. i] or 1) * -24 * lift)
		end
	end
	-- il corpo si abbassa un poco a ogni appoggio (due volte per passo): niente "carrello"
	local hipsRest = sk.rest[sk.hips]
	local drop = sk.height * 0.012 * (0.5 + 0.5 * math.cos(4 * math.pi * p))
	poses[sk.hips] = CFrame.new(hipsRest:VectorToObjectSpace(Vector3.new(0, -drop, 0))) * (poses[sk.hips] or CFrame.identity)
	-- bacino che ondeggia, schiena che compensa, testa che dondola a ogni passo
	add(poses, sk, sk.hips, UP, 4 * wave("walk", "pelvis", p))
	add(poses, sk, sk.hips, sk.fwd, 2.5 * wave("walk", "pelvis", p + 0.25))
	for _, b in sk.spine do
		add(poses, sk, b, UP, -2 * wave("walk", "spine", p))
	end
	for k, b in sk.neck do
		local share = 1 / math.max(#sk.neck, 1)
		add(poses, sk, b, sk.right, (s.neckPitch or 1) * 6 * share * math.sin(4 * math.pi * p))
		add(poses, sk, b, UP, (s.neckYaw or 1) * 4 * share * wave("walk", "head", p))
	end
	-- coda: le quattro curve del giaguaro distribuite lungo la coda
	local tailKeys = { "tail1", "tail2", "tail3", "tail4" }
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		local key = tailKeys[math.clamp(math.floor(f * 3.999) + 1, 1, 4)]
		add(poses, sk, b, UP, (s.tailYaw or 1) * (3 + 6 * f) * wave("walk", key, p))
	end
	-- le ali chiuse si sollevano un poco a ogni passo (per l'equilibrio): prima erano ferme
	foldWings(poses, sk, s, folds, 15 * math.sin(4 * math.pi * p))
	for i, w in sk.wings do
		-- e ondeggiano avanti e indietro col passo (si vede che sono vive)
		add(poses, sk, w.arm[1], UP, (s["sweep" .. i] or 1) * 8 * math.sin(2 * math.pi * p + (if w.side > 0 then 0 else math.pi)))
		if w.arm[2] then
			add(poses, sk, w.arm[2], UP, (s["fold" .. i] or 1) * 6 * math.sin(4 * math.pi * p))
		end
	end
	return poses
end

local function buildIdle(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / IDLE_T
	-- respiro (leopardo) e sguardo che si guarda attorno
	add(poses, sk, sk.hips, sk.right, 1.5 * wave("idle", "pelvis", p))
	for _, b in sk.spine do
		add(poses, sk, b, sk.right, 1.5 * wave("idle", "spine", p))
	end
	for k, b in sk.neck do
		local share = 1 / math.max(#sk.neck, 1)
		add(poses, sk, b, UP, (s.neckYaw or 1) * 14 * share * math.sin(2 * math.pi * p))
		add(poses, sk, b, sk.right, (s.neckPitch or 1) * 5 * share * wave("idle", "head", p))
	end
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		add(poses, sk, b, UP, (s.tailYaw or 1) * (2 + 5 * f) * math.sin(2 * math.pi * (p - 0.06 * k)))
	end
	foldWings(poses, sk, s, folds, 3 * wave("idle", "pelvis", p))
	return poses
end

------------------------------------------------------------------------------------------
-- Animazioni d'azione (boss, attacco speciale, eventi). Quelle "una volta" partono e finiscono
-- nella posa di riposo (ali piegate), cosi' si attaccano a volo/fermo senza scatti.

local ROAR_T, BREATH_T, BITE_T, HOVER_T, GLIDE_T, HIT_T = 2.2, 2.0, 1.0, 0.9, 3.0, 0.6

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
-- 0 prima di a, sale fino a b, resta a 1 fino a c, scende fino a d
local function bell(p: number, a: number, b: number, c: number, d: number): number
	if p <= a or p >= d then
		return 0
	elseif p < b then
		return smooth((p - a) / (b - a))
	elseif p <= c then
		return 1
	end
	return 1 - smooth((p - c) / (d - c))
end

-- ali tra piegate (k = 0) e aperte come in volo (k = 1); "raise" le alza sopra la schiena
local function wingsOpen(poses: Poses, sk: Skel, s: Signs, folds: { Fold }, k: number, raise: number)
	for i, w in sk.wings do
		local f = folds[i]
		foldPoses(poses, sk, s, i, w, { sweep = f.sweep * (1 - k), down = f.down * (1 - k), elbow = f.elbow * (1 - k), finger = f.finger * (1 - k) }, 0)
		local sp = spreads[i]
		if sp and k > 0 then
			add(poses, sk, w.arm[1], sk.fwd, sp.elev * k + s["flap" .. i] * raise)
			add(poses, sk, w.arm[1], UP, sp.sweep * k)
			if w.arm[2] then
				add(poses, sk, w.arm[2], UP, sp.elbow * k)
			end
		end
	end
end

-- il corpo si impenna sull'anca (petto su di "deg" gradi); le zampe dietro e la coda
-- compensano, cosi' i piedi restano a terra
local function rear(poses: Poses, sk: Skel, s: Signs, deg: number)
	add(poses, sk, sk.hips, sk.right, (s.bodyPitch or 1) * deg)
	for _, leg in sk.legs do
		if not leg.front then
			add(poses, sk, leg.bones[1], sk.right, -(s.bodyPitch or 1) * deg)
		end
	end
	if sk.tail[1] then
		add(poses, sk, sk.tail[1], sk.right, -(s.bodyPitch or 1) * deg * 0.7)
	end
end

local function neckTurn(poses: Poses, sk: Skel, s: Signs, pitch: number, yaw: number)
	for k, b in sk.neck do
		-- piu' piega verso la testa: il collo fa una curva, non un bastone
		local share = (k / #sk.neck) / ((#sk.neck + 1) / 2)
		add(poses, sk, b, sk.right, (s.neckPitch or 1) * pitch * share)
		add(poses, sk, b, UP, (s.neckYaw or 1) * yaw * share)
	end
end

local function tailLash(poses: Poses, sk: Skel, s: Signs, amp: number, p: number, cycles: number)
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		add(poses, sk, b, UP, (s.tailYaw or 1) * amp * (0.3 + f) * math.sin(2 * math.pi * (cycles * p - 0.08 * k)))
	end
end

-- ruggito: si impenna, ali aperte e alzate, collo prima indietro poi avanti con la testa che
-- trema, zampe davanti che artigliano l'aria, coda che frusta
local function buildRoar(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / ROAR_T
	local up = bell(p, 0.04, 0.3, 0.72, 0.96)
	rear(poses, sk, s, 20 * up)
	for _, b in sk.spine do
		add(poses, sk, b, sk.right, (s.bodyPitch or 1) * 3 * up)
	end
	local back = bell(p, 0.05, 0.25, 0.3, 0.42) -- prende fiato
	local shout = bell(p, 0.32, 0.42, 0.72, 0.92) -- ruggisce
	local shake = shout * math.sin(2 * math.pi * 9 * p)
	neckTurn(poses, sk, s, 28 * back - 14 * shout + 3 * shake, 5 * shake)
	wingsOpen(poses, sk, s, folds, up, 22 * shout + 6 * math.sin(2 * math.pi * 3 * p) * up)
	for i, leg in sk.legs do
		if leg.front then
			local claw = up * (0.7 + 0.3 * math.sin(2 * math.pi * (2 * p + (if leg.side > 0 then 0 else 0.5))))
			add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * 34 * claw)
			if leg.bones[2] then
				add(poses, sk, leg.bones[2], sk.right, (s["lift" .. i] or 1) * 30 * claw)
			end
		end
	end
	tailLash(poses, sk, s, 14 * up, p, 3)
	return poses
end

-- soffio (fuoco, gelo, gas...): inspira con la testa alta e il petto gonfio, poi allunga il
-- collo in avanti e un po' giu' e spazza da un lato all'altro
local function buildBreath(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / BREATH_T
	local inhale = bell(p, 0.02, 0.22, 0.3, 0.4)
	local blow = bell(p, 0.34, 0.44, 0.84, 0.97)
	local sweep = blow * math.sin(2 * math.pi * (p - 0.4) * 1.1)
	rear(poses, sk, s, 8 * inhale - 4 * blow)
	for _, b in sk.spine do
		add(poses, sk, b, sk.right, (s.bodyPitch or 1) * (4 * inhale - 2 * blow))
	end
	neckTurn(poses, sk, s, 24 * inhale - 16 * blow, 18 * sweep)
	wingsOpen(poses, sk, s, folds, 0.55 * math.max(inhale, blow), 8 * blow)
	for i, leg in sk.legs do
		if leg.front then
			-- si pianta sulle zampe davanti
			add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * 8 * blow)
		end
	end
	tailLash(poses, sk, s, 6 * blow, p, 2)
	return poses
end

-- morso con artigliata: carica all'indietro, scatta in avanti col collo e una zampa davanti
local function buildBite(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / BITE_T
	local load = bell(p, 0.02, 0.28, 0.32, 0.42)
	local strike = bell(p, 0.34, 0.46, 0.56, 0.9)
	rear(poses, sk, s, 7 * load - 6 * strike)
	neckTurn(poses, sk, s, 20 * load - 26 * strike, -6 * strike)
	wingsOpen(poses, sk, s, folds, 0.35 * load + 0.25 * strike, 10 * load)
	local swiped = false
	for i, leg in sk.legs do
		if leg.front and not swiped and leg.side > 0 then
			swiped = true
			add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * (30 * load - 22 * strike))
			if leg.bones[2] then
				add(poses, sk, leg.bones[2], sk.right, (s["lift" .. i] or 1) * 36 * load)
			end
		end
	end
	tailLash(poses, sk, s, 8 * (load + strike), p, 1.5)
	return poses
end

-- volo librato (fermo in aria): battito piu' ampio e veloce, corpo dritto, zampe che pendono
local function buildHover(sk: Skel, s: Signs, t: number): Poses
	local poses = buildFly(sk, s, t / HOVER_T * FLY_T)
	rear(poses, sk, s, 26)
	for i, leg in sk.legs do
		-- le zampe del volo sono raccolte: qui pendono
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * (if leg.front then 14 else 26))
	end
	neckTurn(poses, sk, s, -18, 0) -- testa giu': guarda i giocatori sotto
	return poses
end

-- planata: ali aperte e quasi ferme, solo le punte che ondeggiano nel vento
local function buildGlide(sk: Skel, s: Signs, t: number): Poses
	local poses: Poses = {}
	local p = t / GLIDE_T
	for i, w in sk.wings do
		local sp = spreads[i]
		if sp then
			add(poses, sk, w.arm[1], sk.fwd, sp.elev + s["flap" .. i] * 5 * math.sin(2 * math.pi * p))
			add(poses, sk, w.arm[1], UP, sp.sweep)
			if w.arm[2] then
				add(poses, sk, w.arm[2], UP, sp.elbow)
			end
		end
		for _, finger in w.fingers do
			if finger[2] then
				add(poses, sk, finger[2], sk.fwd, s["flap" .. i] * 4 * math.sin(2 * math.pi * (2 * p - 0.2)))
			end
		end
	end
	for i, leg in sk.legs do
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * (if leg.front then -30 else -40))
	end
	neckTurn(poses, sk, s, 3 * math.sin(2 * math.pi * p), 6 * math.sin(2 * math.pi * p + 1))
	tailLash(poses, sk, s, 3, p, 1)
	return poses
end

-- colpito: sobbalzo all'indietro, testa che scatta di lato, ali che si aprono di riflesso
local function buildHit(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / HIT_T
	local jolt = bell(p, 0, 0.12, 0.2, 0.85)
	rear(poses, sk, s, 9 * jolt)
	neckTurn(poses, sk, s, 10 * jolt, 22 * jolt)
	wingsOpen(poses, sk, s, folds, 0.3 * jolt, 14 * jolt)
	tailLash(poses, sk, s, 10 * jolt, p, 2)
	return poses
end

------------------------------------------------------------------------------------------
-- Vita a terra: seduto, dorme, corsa, e i gesti (annusa, si scrolla, si guarda attorno,
-- decollo, atterraggio). Mirko: "le animazioni sono ancora troppo limitate".

local SIT_T, SLEEP_T, RUN_T = 3.0, 4.0, 0.6
local SNIFF_T, SHAKE_T, LOOK_T, TAKEOFF_T, LAND_T = 2.2, 1.4, 2.6, 1.3, 1.1

-- abbassa (o alza) il bacino di "amount" studs
local function drop(poses: Poses, sk: Skel, amount: number)
	local hipsRest = sk.rest[sk.hips]
	poses[sk.hips] = CFrame.new(hipsRest:VectorToObjectSpace(Vector3.new(0, -amount, 0))) * (poses[sk.hips] or CFrame.identity)
end

-- zampe piegate sotto il corpo (k = 0 dritte, 1 del tutto piegate)
local function tuckLegs(poses: Poses, sk: Skel, s: Signs, k: number, backOnly: boolean?)
	for i, leg in sk.legs do
		if backOnly and leg.front then
			continue
		end
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * (if leg.front then -20 else 35) * k)
		if leg.bones[2] then
			add(poses, sk, leg.bones[2], sk.right, (s["lift" .. i] or 1) * 60 * k)
		end
		if leg.bones[3] then
			add(poses, sk, leg.bones[3], sk.right, (s["lift" .. i] or 1) * -35 * k)
		end
	end
end

-- seduto come un cane: posteriori piegate, petto alto, coda attorno, si guarda in giro
local function buildSit(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / SIT_T
	drop(poses, sk, sk.height * 0.12)
	rear(poses, sk, s, 24)
	tuckLegs(poses, sk, s, 1, true)
	neckTurn(poses, sk, s, -10 + 4 * wave("idle", "head", p), 18 * math.sin(2 * math.pi * p))
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		add(poses, sk, b, UP, (s.tailYaw or 1) * (8 + 14 * f) + 3 * math.sin(2 * math.pi * (p - 0.05 * k)))
	end
	foldWings(poses, sk, s, folds, 2 * wave("idle", "pelvis", p))
	return poses
end

-- dorme: steso, zampe sotto, collo girato sul fianco, coda arrotolata, respiro lento
local function buildSleep(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / SLEEP_T
	local breath = math.sin(2 * math.pi * p)
	drop(poses, sk, sk.height * 0.28)
	tuckLegs(poses, sk, s, 1)
	for _, b in sk.spine do
		add(poses, sk, b, sk.right, (s.bodyPitch or 1) * 1.5 * breath)
	end
	neckTurn(poses, sk, s, -22 + 2 * breath, 55)
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		add(poses, sk, b, UP, (s.tailYaw or 1) * (10 + 22 * f))
	end
	foldWings(poses, sk, s, folds, 2 * breath)
	return poses
end

-- corsa: il passo piu' veloce e ampio, il corpo che va su e giu' a balzi
local function buildRun(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses = buildWalk(sk, s, (t / RUN_T) * WALK_T, folds)
	local p = t / RUN_T
	drop(poses, sk, sk.height * 0.03 * math.sin(4 * math.pi * p))
	add(poses, sk, sk.hips, sk.right, (s.bodyPitch or 1) * 4 * math.sin(2 * math.pi * p))
	neckTurn(poses, sk, s, -8, 0)
	return poses
end

-- annusa il terreno: testa giu', piccoli scatti a destra e sinistra, poi su
local function buildSniff(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / SNIFF_T
	local down = bell(p, 0.05, 0.3, 0.75, 0.97)
	rear(poses, sk, s, -6 * down)
	neckTurn(poses, sk, s, -38 * down, 14 * down * math.sin(2 * math.pi * 5 * p))
	foldWings(poses, sk, s, folds, 0)
	tailLash(poses, sk, s, 4, p, 1.5)
	return poses
end

-- si scrolla come un cane bagnato: il corpo ruota avanti e indietro, ali e testa sbattono
local function buildShake(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / SHAKE_T
	local env = bell(p, 0.02, 0.15, 0.75, 0.98)
	local w = math.sin(2 * math.pi * 7 * p) * env
	add(poses, sk, sk.hips, sk.fwd, 12 * w)
	for _, b in sk.spine do
		add(poses, sk, b, sk.fwd, -8 * w)
	end
	neckTurn(poses, sk, s, 4 * env, 25 * w)
	wingsOpen(poses, sk, s, folds, 0.35 * env, 18 * w)
	tailLash(poses, sk, s, 16 * env, p, 7)
	return poses
end

-- si guarda attorno: la testa a sinistra, poi a destra, un po' in alto
local function buildLook(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local poses: Poses = {}
	local p = t / LOOK_T
	local yaw = 40 * (bell(p, 0.05, 0.25, 0.4, 0.5) - bell(p, 0.5, 0.65, 0.8, 0.97))
	neckTurn(poses, sk, s, 8 * bell(p, 0.05, 0.2, 0.8, 0.97), yaw)
	foldWings(poses, sk, s, folds, 0)
	tailLash(poses, sk, s, 3, p, 1)
	return poses
end

-- decollo: si accuccia, salta sulle posteriori aprendo le ali con un battito grande
local function buildTakeoff(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local p = t / TAKEOFF_T
	local crouch = bell(p, 0, 0.2, 0.28, 0.4)
	local leap = bell(p, 0.3, 0.45, 0.7, 0.98)
	local poses: Poses = {}
	drop(poses, sk, sk.height * 0.12 * crouch)
	tuckLegs(poses, sk, s, 0.6 * crouch)
	rear(poses, sk, s, 18 * leap)
	wingsOpen(poses, sk, s, folds, math.max(crouch * 0.4, leap), 35 * leap * math.sin(math.pi * math.clamp((p - 0.3) / 0.6, 0, 1)) - 15 * crouch)
	neckTurn(poses, sk, s, 12 * leap - 10 * crouch, 0)
	tailLash(poses, sk, s, 6 * leap, p, 1)
	return poses
end

-- atterraggio: ali aperte e alzate per frenare, zampe avanti, poi si richiude
local function buildLand(sk: Skel, s: Signs, t: number, folds: { Fold }): Poses
	local p = t / LAND_T
	local brake = bell(p, 0, 0.1, 0.45, 0.85)
	local touch = bell(p, 0.4, 0.55, 0.65, 0.95)
	local poses: Poses = {}
	rear(poses, sk, s, 20 * brake)
	drop(poses, sk, sk.height * 0.08 * touch)
	wingsOpen(poses, sk, s, folds, brake, 28 * brake)
	for i, leg in sk.legs do
		if leg.front then
			add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * 25 * brake)
		end
	end
	neckTurn(poses, sk, s, -8 * touch, 0)
	return poses
end

------------------------------------------------------------------------------------------
-- In monta (client/PetAnimator le mescola col volo secondo come si muove il drago): virata a
-- sinistra e a destra, salita, discesa. Mirko: "fai anche altre animazioni per il volo, virata
-- dai vari lati, discesa, distacco da terra" (il distacco e' drago-decollo, qui sopra).

local BANK_T, CLIMB_T, DESCEND_T = FLY_T, 0.9, 2.4

-- virata verso turn (-1 sinistra, +1 destra): il corpo fa la curva (collo e coda verso
-- l'interno), l'ala interna si raccoglie un po' e sale, quella esterna si stende e batte piena
local function buildBank(sk: Skel, s: Signs, t: number, turn: number): Poses
	local poses = buildFly(sk, s, t)
	local p = t / BANK_T
	for i, w in sk.wings do
		local inner = w.side == turn
		if inner then
			add(poses, sk, w.arm[1], sk.fwd, s["flap" .. i] * 12)
			if w.arm[2] then
				add(poses, sk, w.arm[2], UP, (s["fold" .. i] or 1) * 20)
			end
		else
			add(poses, sk, w.arm[1], sk.fwd, s["flap" .. i] * -6 * (1 + 0.3 * math.sin(2 * math.pi * p)))
			add(poses, sk, w.arm[1], UP, -(s["sweep" .. i] or 1) * 6) -- in avanti: ala piu' aperta
		end
	end
	neckTurn(poses, sk, s, 4, 22 * turn)
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		add(poses, sk, b, UP, (s.tailYaw or 1) * turn * (4 + 6 * f))
	end
	return poses
end

-- salita: battiti piu' ampi e veloci, petto su, testa alta, zampe che penzolano indietro
local function buildClimb(sk: Skel, s: Signs, t: number): Poses
	local old = flyAmp
	flyAmp = math.min(1, old * 1.25)
	local poses = buildFly(sk, s, t / CLIMB_T * FLY_T)
	flyAmp = old
	rear(poses, sk, s, 14)
	neckTurn(poses, sk, s, 14, 0)
	for i, leg in sk.legs do
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * -12)
	end
	return poses
end

-- discesa: ali aperte e alzate a V quasi ferme (le punte vibrano), muso giu', zampe raccolte
local function buildDescend(sk: Skel, s: Signs, t: number): Poses
	local poses = buildGlide(sk, s, t / DESCEND_T * GLIDE_T)
	local p = t / DESCEND_T
	for i, w in sk.wings do
		add(poses, sk, w.arm[1], sk.fwd, s["flap" .. i] * (16 + 3 * math.sin(4 * math.pi * p)))
	end
	rear(poses, sk, s, -8)
	neckTurn(poses, sk, s, -10, 0)
	for i, leg in sk.legs do
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * -10)
	end
	return poses
end

------------------------------------------------------------------------------------------
-- KeyframeSequence: posa radice col nome della mesh, poi le ossa annidate come lo scheletro

local function writeSequence(sk: Skel, name: string, length: number, build: (number) -> Poses): KeyframeSequence
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = name
	kfs.Loop = true
	kfs.Priority = Enum.AnimationPriority.Action
	for i = 0, KEYS do
		local t = i / KEYS * length
		local poses = build(if i == KEYS then 0 else t) -- l'ultima chiave e' uguale alla prima
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local rootPose = Instance.new("Pose")
		rootPose.Name = sk.mesh.Name
		rootPose.Weight = 0
		rootPose.Parent = kf
		local made: { [Instance]: Pose } = { [sk.mesh] = rootPose }
		local function poseFor(b: Instance): Pose
			if made[b] then
				return made[b]
			end
			local parentPose = poseFor(b.Parent :: Instance)
			local pose = Instance.new("Pose")
			pose.Name = b.Name
			pose.Weight = 0
			pose.Parent = parentPose
			made[b] = pose
			return pose
		end
		for b, cf in poses do
			local pose = poseFor(b)
			pose.CFrame = cf
			pose.Weight = 1
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
		end
		kf.Parent = kfs
	end
	return kfs
end

-- Stili di passaggio: Cubic dove il movimento torna indietro, lineare dove continua
local function easeSequence(kfs: KeyframeSequence)
	local EPS = math.rad(0.4)
	local L = 0
	for _, kf in kfs:GetKeyframes() do
		L = math.max(L, (kf :: Keyframe).Time)
	end
	local tracks: { [string]: { { t: number, pose: Pose } } } = {}
	for _, kf in kfs:GetKeyframes() do
		for _, p in kf:GetDescendants() do
			if p:IsA("Pose") and p.Weight > 0 then
				tracks[p.Name] = tracks[p.Name] or {}
				table.insert(tracks[p.Name], { t = (kf :: Keyframe).Time, pose = p })
			end
		end
	end
	for _, list in tracks do
		table.sort(list, function(a, b) return a.t < b.t end)
		local n = #list
		if n >= 3 then
			local v = {}
			for i = 1, n - 1 do
				local ax, an = (list[i].pose.CFrame:Inverse() * list[i + 1].pose.CFrame):ToAxisAngle()
				v[i] = ax * an
			end
			local function ext(i: number): boolean
				local a = if i > 1 then v[i - 1] else v[n - 1]
				local b = if i < n then v[i] else v[1]
				if a.Magnitude < EPS or b.Magnitude < EPS then
					return true
				end
				return a:Dot(b) < 0.3 * a.Magnitude * b.Magnitude
			end
			for i = 1, n - 1 do
				local pose = list[i].pose
				local s, e = ext(i), ext(i + 1)
				if v[i].Magnitude < EPS or (not s and not e) then
					pose.EasingStyle = Enum.PoseEasingStyle.Linear
				else
					pose.EasingStyle = Enum.PoseEasingStyle.Cubic
					pose.EasingDirection = if s and e then Enum.PoseEasingDirection.InOut elseif s then Enum.PoseEasingDirection.Out else Enum.PoseEasingDirection.In
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------

-- Genera le animazioni di un rig (o di tutti quelli in Workspace.RigDraghi)
function AnimDraghi.genera(soloNome: string?): string
	local folder = Workspace:FindFirstChild("RigDraghi")
	assert(folder, "manca Workspace.RigDraghi")
	local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	assert(saves, "manca ServerStorage.RBX_ANIMSAVES")
	local backup = ServerStorage:FindFirstChild("BackupAnimazioni") or Instance.new("Folder")
	backup.Name = "BackupAnimazioni"
	backup.Parent = ServerStorage
	local report = {}
	for _, rig in folder:GetChildren() do
		if rig:IsA("Model") and (not soloNome or rig.Name == soloNome) then
			local sk = AnimDraghi.analizza(rig)
			local s = computeSigns(sk)
			-- l'adulto tiene le ali "un attimo piegate", i cuccioli un po' di piu'
			local fold = if string.find(string.lower(rig.Name), "adulto") then 0.55 else 0.75
			local folds = {}
			local foldsDive = {} -- in picchiata le ali si chiudono del tutto
			for i, w in sk.wings do
				folds[i] = bestFold(sk, s, i, w, fold)
				foldsDive[i] = bestFold(sk, s, i, w, 1)
			end
			-- ali aperte per il volo (vedi spreads)
			spreads = {}
			for i, w in sk.wings do
				local sp: Spread = { elbow = 0, sweep = 0, elev = 0 }
				local elbow = w.arm[2]
				if elbow then
					sp.elbow = 0.7 * signedAngle(flat(w.tip.WorldPosition - elbow.WorldPosition), flat(elbow.WorldPosition - w.arm[1].WorldPosition), UP)
					elbow.Transform = bodyRot(sk, elbow, UP, sp.elbow)
				end
				local d = w.tip.WorldPosition - w.arm[1].WorldPosition
				local side = sk.right * w.side * math.cos(math.rad(20)) - sk.fwd * math.sin(math.rad(20))
				sp.sweep = signedAngle(d, side, UP)
				local d2 = CFrame.fromAxisAngle(UP, math.rad(sp.sweep)) * d
				sp.elev = signedAngle(d2, flat(d2) * math.cos(math.rad(8)) + UP * math.sin(math.rad(8)), sk.fwd)
				if elbow then
					elbow.Transform = CFrame.identity
				end
				spreads[i] = sp
			end
			-- ampiezza del volo: si prova il battito sul rig e si abbassa se un'ala passa la meta'
			flyAmp = 1
			local hipsPos = sk.rest[sk.hips].Position
			for _, try in { 1, 0.85, 0.7, 0.58, 0.46, 0.36 } do
				flyAmp = try
				local crossed = false
				for k = 0, 15 do
					local poses = buildFly(sk, s, k / 16 * FLY_T)
					for b, cf in poses do
						b.Transform = cf
					end
					for _, w in sk.wings do
						local shoulder = math.abs((w.arm[1].WorldPosition - hipsPos):Dot(sk.right))
						for _, b in wingBones(w) do
							if (b.WorldPosition - hipsPos):Dot(sk.right) * w.side < shoulder * 0.5 then
								crossed = true
							end
						end
					end
					for b in poses do
						b.Transform = CFrame.identity
					end
					if crossed then
						break
					end
				end
				if not crossed then
					break
				end
			end
			local store = saves:FindFirstChild(rig.Name) or Instance.new("Model")
			store.Name = rig.Name
			store.Parent = saves
			for name, info in {
				["drago-volo"] = { FLY_T, function(t) return buildFly(sk, s, t) end },
				["drago-cammina"] = { WALK_T, function(t) return buildWalk(sk, s, t, folds) end },
				["drago-fermo"] = { IDLE_T, function(t) return buildIdle(sk, s, t, folds) end },
				["drago-picchiata"] = { DIVE_T, function(t) return buildDive(sk, s, t, foldsDive) end },
				["drago-librato"] = { HOVER_T, function(t) return buildHover(sk, s, t) end },
				["drago-planata"] = { GLIDE_T, function(t) return buildGlide(sk, s, t) end },
				-- una volta sola (il terzo valore): partono e finiscono a riposo
				["drago-ruggito"] = { ROAR_T, function(t) return buildRoar(sk, s, t, folds) end, true },
				["drago-soffio"] = { BREATH_T, function(t) return buildBreath(sk, s, t, folds) end, true },
				["drago-morso"] = { BITE_T, function(t) return buildBite(sk, s, t, folds) end, true },
				["drago-colpito"] = { HIT_T, function(t) return buildHit(sk, s, t, folds) end, true },
				["drago-seduto"] = { SIT_T, function(t) return buildSit(sk, s, t, folds) end },
				["drago-dorme"] = { SLEEP_T, function(t) return buildSleep(sk, s, t, foldsDive) end },
				["drago-corsa"] = { RUN_T, function(t) return buildRun(sk, s, t, folds) end },
				["drago-annusa"] = { SNIFF_T, function(t) return buildSniff(sk, s, t, folds) end, true },
				["drago-scrolla"] = { SHAKE_T, function(t) return buildShake(sk, s, t, folds) end, true },
				["drago-guarda"] = { LOOK_T, function(t) return buildLook(sk, s, t, folds) end, true },
				["drago-decollo"] = { TAKEOFF_T, function(t) return buildTakeoff(sk, s, t, folds) end, true },
				["drago-atterra"] = { LAND_T, function(t) return buildLand(sk, s, t, folds) end, true },
				["drago-virata-sx"] = { BANK_T, function(t) return buildBank(sk, s, t, -1) end },
				["drago-virata-dx"] = { BANK_T, function(t) return buildBank(sk, s, t, 1) end },
				["drago-salita"] = { CLIMB_T, function(t) return buildClimb(sk, s, t) end },
				["drago-discesa"] = { DESCEND_T, function(t) return buildDescend(sk, s, t) end },
			} do
				local old = store:FindFirstChild(name)
				if old then
					old.Name = rig.Name .. "_" .. name .. "_prima"
					old.Parent = backup
				end
				local kfs = writeSequence(sk, name, info[1], info[2])
				easeSequence(kfs)
				if info[3] then
					kfs.Loop = false
				end
				kfs.Parent = store
			end
			for _, d in rig:GetDescendants() do
				if d:IsA("Bone") then
					d.Transform = CFrame.identity
				end
			end
			local f1 = folds[1]
			table.insert(report, string.format("%s (volo %.2f): ali %d, zampe %d, coda %d ossa, collo %d ossa | piega: indietro %d, giu' %d, gomito %d, dita %d", rig.Name, flyAmp, #sk.wings, #sk.legs, #sk.tail, #sk.neck,
				f1 and f1.sweep or 0, f1 and f1.down or 0, f1 and f1.elbow or 0, f1 and f1.finger or 0))
		end
	end
	return table.concat(report, "\n")
end

return AnimDraghi
