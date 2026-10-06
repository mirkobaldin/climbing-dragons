--!strict
-- Generatore delle animazioni dei draghi (strumento di Studio: non gira nel gioco).
-- Dalla Command Bar di Studio:
--   require(game.ServerStorage.MapGen.AnimDraghi).genera()               -- tutti i rig
--   require(game.ServerStorage.MapGen.AnimDraghi).genera("Drago_Gelo")   -- uno solo
-- Per ogni rig in Workspace.RigDraghi (scheletri di Meshy: Bone_000, Bone_001...) riconosce dalla
-- forma dello scheletro anca, colonna, petto, coda, zampe, ali e collo, e crea in
-- ServerStorage.RBX_ANIMSAVES.<rig> tre animazioni che si aprono nell'Animation Editor:
--   drago-volo (1.2 s)   drago-cammina (1.0 s)   drago-fermo (2.4 s)
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
		tail = {}, neck = {}, legs = {}, wings = {}, fwd = fwd, right = right, height = height,
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

local function computeSigns(sk: Skel): Signs
	local s: Signs = {}
	for i, w in sk.wings do
		local base = w.arm[1]
		s["flap" .. i] = signFor(sk, base, sk.fwd, w.tip, function(m) return m.Y end) -- + = punta su
		s["sweep" .. i] = signFor(sk, base, UP, w.tip, function(m) return -m:Dot(sk.fwd) end) -- + = punta indietro
		if w.arm[2] then
			s["fold" .. i] = signFor(sk, w.arm[2], UP, w.tip, function(m) return -m:Dot(sk.fwd) end)
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
	if #sk.neck > 0 then
		local head = sk.neck[#sk.neck]
		s.neckPitch = signFor(sk, sk.neck[1], sk.right, head, function(m) return m.Y end) -- + = testa su
		s.neckYaw = signFor(sk, sk.neck[1], UP, head, function(m) return m:Dot(sk.right) end)
	end
	return s
end

-- ali piegate (camminata e fermo): indietro, un po' giu', avambraccio e dita chiusi.
-- amount 1 = chiuse del tutto, 0.6 = "un attimo piegate"
local function foldWings(poses: Poses, sk: Skel, s: Signs, amount: number, breathe: number)
	for i, w in sk.wings do
		add(poses, sk, w.arm[1], UP, s["sweep" .. i] * 45 * amount)
		add(poses, sk, w.arm[1], sk.fwd, -s["flap" .. i] * (42 * amount - breathe)) -- giu', lungo i fianchi
		if w.arm[2] then
			add(poses, sk, w.arm[2], UP, (s["fold" .. i] or 1) * 55 * amount)
		end
		for _, finger in w.fingers do
			add(poses, sk, finger[1], UP, (s["fold" .. i] or 1) * 25 * amount)
		end
	end
end

local FLY_T, WALK_T, IDLE_T = 1.2, 1.0, 2.4
local KEYS = 16

local function buildFly(sk: Skel, s: Signs, t: number): Poses
	local poses: Poses = {}
	local p = t / FLY_T
	-- ali: il battito del tucano; le ossa verso la punta in ritardo (viverna)
	for i, w in sk.wings do
		local flap = s["flap" .. i]
		local lags = { 0, 0.08, 0.14, 0.2 }
		for k, b in w.arm do
			local lag = lags[math.min(k, #lags)]
			local amp = if k == 1 then 42 elseif k == 2 then 16 else 10
			add(poses, sk, b, sk.fwd, flap * amp * wave("fly", "wing", p - lag))
		end
		-- risalita: avambraccio e dita si richiudono; discesa: le punte vanno avanti (l'ala si gonfia)
		local v = wave("fly", "wing", p + 0.03) - wave("fly", "wing", p - 0.03)
		local up = math.clamp(v * 6, -1, 1)
		if w.arm[2] then
			add(poses, sk, w.arm[2], UP, (s["fold" .. i] or 1) * 22 * math.max(0, up))
		end
		for _, finger in w.fingers do
			add(poses, sk, finger[1], UP, (s["fold" .. i] or 1) * (16 * math.max(0, up) - 10 * math.max(0, -up)))
			if finger[2] then
				add(poses, sk, finger[2], sk.fwd, flap * 8 * wave("fly", "wing", p - 0.25))
			end
		end
	end
	-- corpo che segue il battito, testa in ritardo
	add(poses, sk, sk.hips, sk.right, 4 * wave("fly", "hips", p))
	for _, b in sk.spine do
		add(poses, sk, b, sk.right, 2 * wave("fly", "chest", p))
	end
	for k, b in sk.neck do
		local share = if k == #sk.neck then 0.4 else 0.6 / math.max(#sk.neck - 1, 1)
		add(poses, sk, b, sk.right, (s.neckPitch or 1) * 10 * share * wave("fly", "head", p))
	end
	-- zampe: raccolte all'indietro, penzolano col battito (ginocchio e piede in ritardo)
	for i, leg in sk.legs do
		local tuck = if leg.front then -20 else -30
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * (tuck + 12 * wave("fly", "leg", p)))
		if leg.bones[2] then
			add(poses, sk, leg.bones[2], sk.right, (s["lift" .. i] or 1) * (10 + 10 * wave("fly", "leg", p - 0.12)))
		end
		if leg.bones[3] then
			add(poses, sk, leg.bones[3], sk.right, (s["lift" .. i] or 1) * -8 * wave("fly", "leg", p - 0.22))
		end
	end
	-- coda: onda che va verso la punta
	for k, b in sk.tail do
		local f = (k - 1) / math.max(#sk.tail - 1, 1)
		add(poses, sk, b, UP, (s.tailYaw or 1) * (3 + 5 * f) * math.sin(2 * math.pi * (p - 0.1 * k)))
		add(poses, sk, b, sk.right, (s.tailPitch or 1) * 2.5 * wave("fly", "hips", p - 0.08 * k))
	end
	return poses
end

local function buildWalk(sk: Skel, s: Signs, t: number, fold: number): Poses
	local poses: Poses = {}
	local p = t / WALK_T
	-- zampe: oscillazione della coscia dal giaguaro; il piede si alza mentre la zampa va avanti
	for i, leg in sk.legs do
		local ph = p + leg.phase
		local key = if leg.front then "arm" else "thigh"
		local swing = wave("walk", key, ph)
		local ahead = wave("walk", key, ph + 0.04) - wave("walk", key, ph - 0.04)
		local lift = math.max(0, ahead) * 4 -- solo quando va avanti
		add(poses, sk, leg.bones[1], sk.right, s["swing" .. i] * 20 * swing)
		if leg.bones[2] then
			add(poses, sk, leg.bones[2], sk.right, (s["lift" .. i] or 1) * math.min(28, 28 * lift))
		end
		if leg.bones[3] then
			add(poses, sk, leg.bones[3], sk.right, (s["lift" .. i] or 1) * -math.min(16, 16 * lift))
		end
	end
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
	foldWings(poses, sk, s, fold, 2 * math.sin(2 * math.pi * p))
	return poses
end

local function buildIdle(sk: Skel, s: Signs, t: number, fold: number): Poses
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
	foldWings(poses, sk, s, fold, 3 * wave("idle", "pelvis", p))
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
			local store = saves:FindFirstChild(rig.Name) or Instance.new("Model")
			store.Name = rig.Name
			store.Parent = saves
			for name, info in {
				["drago-volo"] = { FLY_T, function(t) return buildFly(sk, s, t) end },
				["drago-cammina"] = { WALK_T, function(t) return buildWalk(sk, s, t, fold) end },
				["drago-fermo"] = { IDLE_T, function(t) return buildIdle(sk, s, t, fold) end },
			} do
				local old = store:FindFirstChild(name)
				if old then
					old.Name = rig.Name .. "_" .. name .. "_prima"
					old.Parent = backup
				end
				local kfs = writeSequence(sk, name, info[1], info[2])
				easeSequence(kfs)
				kfs.Parent = store
			end
			for _, d in rig:GetDescendants() do
				if d:IsA("Bone") then
					d.Transform = CFrame.identity
				end
			end
			table.insert(report, string.format("%s: ali %d, zampe %d, coda %d ossa, collo %d ossa", rig.Name, #sk.wings, #sk.legs, #sk.tail, #sk.neck))
		end
	end
	return table.concat(report, "\n")
end

return AnimDraghi
