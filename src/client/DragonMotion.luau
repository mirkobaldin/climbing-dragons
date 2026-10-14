--!strict
-- Movimenti secondari dei draghi, sopra le animazioni (KfsPlayer.setOverlay): Mirko trovava le
-- animazioni rigide (collo e testa sempre nella stessa posizione, busto fermo nelle virate, testa
-- che non si distende in picchiata). Qui, ogni frame, dal volo vero del drago:
--   collo e testa entrano nella virata e, da fermo, si guardano attorno
--   busto: si torce e si inclina verso l'interno della curva (il petto piu' dell'anca)
--   coda: segue in ritardo dalla parte opposta e ondeggia in volo
--   picchiata: il collo si distende in linea col corpo; in salita la testa si alza
--   a terra: il bacino ondeggia col passo
-- I ruoli e gli assi delle ossa li scrive il server (DragonModels.markBones, attributi Ruolo,
-- Indice, AsseSu, AsseDx, AsseAv e CollaAlzo sul modello).

local KfsPlayer = require(script.Parent.KfsPlayer)

local DragonMotion = {}

export type Motion = {
	turn: number, -- velocita' di virata (rad/s, + a sinistra)
	vy: number, -- velocita' verticale (studs/s)
	speed: number, -- velocita' orizzontale (studs/s)
	air: number, -- 0 a terra, 1 in volo
	walk: number, -- fase del passo (radianti)
	t: number, -- tempo
}

type Joint = { bone: Bone, w: number, up: Vector3, right: Vector3, fwd: Vector3, i: number, n: number }
type Rig = {
	neck: { Joint },
	spine: { Joint },
	tail: { Joint },
	hips: Joint?,
	lift: number, -- gradi di cui sale il collo a riposo
	seed: number,
	s: { [string]: number }, -- molle
	map: { [Bone]: CFrame },
}

local rigs: { [Model]: Rig | false } = setmetatable({}, { __mode = "k" }) :: any

local function vec(b: Bone, name: string, fallback: Vector3): Vector3
	local v = b:GetAttribute(name)
	return if typeof(v) == "Vector3" and v.Magnitude > 0.01 then v.Unit else fallback
end

local function build(model: Model): Rig | false
	local lists: { [string]: { Joint } } = { neck = {}, spine = {}, tail = {}, hips = {}, chest = {} }
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			local role = d:GetAttribute("Ruolo")
			if type(role) == "string" and lists[role] then
				table.insert(lists[role], {
					bone = d,
					w = 0,
					up = vec(d, "AsseSu", Vector3.yAxis),
					right = vec(d, "AsseDx", Vector3.xAxis),
					fwd = vec(d, "AsseAv", -Vector3.zAxis),
					i = (d:GetAttribute("Indice") or 1) :: number,
					n = (d:GetAttribute("Di") or 1) :: number,
				})
			end
		end
	end
	if #lists.neck == 0 and #lists.tail == 0 then
		return false
	end
	for _, l in lists do
		table.sort(l, function(a, b)
			return a.i < b.i
		end)
	end
	-- pesi lungo le catene: crescono verso la punta (la testa gira piu' della base del collo)
	local function weigh(l: { Joint })
		local sum = 0
		for k in l do
			sum += k
		end
		for k, j in l do
			j.w = k / math.max(sum, 1)
		end
	end
	weigh(lists.neck)
	weigh(lists.tail)
	-- la colonna: il petto conta come ultimo pezzo (si torce di piu')
	for _, c in lists.chest do
		table.insert(lists.spine, c)
	end
	weigh(lists.spine)
	local lift = model:GetAttribute("CollaAlzo")
	return {
		neck = lists.neck,
		spine = lists.spine,
		tail = lists.tail,
		hips = lists.hips[1],
		lift = math.clamp(if type(lift) == "number" then lift else 25, -10, 70),
		seed = math.random() * 100,
		s = {},
		map = {},
	}
end

-- Pose a terra (seduto, dorme): quanto alzare il modello perche' non affondi. Contare solo le
-- ossa non bastava: sdraiato, l'osso piu' basso e' quello della schiena e la pancia (la mesh
-- attorno) finiva sotto la paglia per tutto lo spessore del corpo. Qui le ossa del corpo (anca,
-- colonna, petto: attributo Ruolo) devono restare sopra il terreno dello spessore del corpo,
-- il resto (zampe, collo, coda sottile) solo sopra il terreno. Il riposo si calcola dalla catena delle ossa
-- (Bone.CFrame dal genitore), senza le animazioni.
type Ground = { bones: { Bone }, body: { [Bone]: boolean }, restLow: number, thick: number }
local grounds: { [Model]: Ground | false } = setmetatable({}, { __mode = "k" }) :: any

local function buildGround(model: Model): Ground | false
	local bones: { Bone } = {}
	local body: { [Bone]: boolean } = {}
	local rest: { [Bone]: CFrame } = {}
	local function restOf(b: Bone): CFrame
		local r = rest[b]
		if r then
			return r
		end
		local parent = b.Parent
		local base = if parent and parent:IsA("Bone") then restOf(parent) elseif parent and parent:IsA("BasePart") then parent.CFrame else CFrame.identity
		r = base * b.CFrame
		rest[b] = r
		return r
	end
	local low = math.huge
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			table.insert(bones, d)
			local role = d:GetAttribute("Ruolo")
			if role == "hips" or role == "spine" or role == "chest" then
				body[d] = true
			end
			low = math.min(low, pivot:PointToObjectSpace(restOf(d).Position).Y)
		end
	end
	if #bones == 0 then
		return false
	end
	local _, size = model:GetBoundingBox()
	return { bones = bones, body = body, restLow = low, thick = size.Y * 0.14 }
end

function DragonMotion.groundLift(model: Model): number
	local g = grounds[model]
	if g == nil then
		g = buildGround(model)
		grounds[model] = g
	end
	if not g then
		return 0
	end
	local gg = g :: Ground
	local pivot = model:GetPivot()
	local legLow, bodyLow = math.huge, math.huge
	for _, b in gg.bones do
		local y = pivot:PointToObjectSpace(b.TransformedWorldCFrame.Position).Y
		if gg.body[b] then
			bodyLow = math.min(bodyLow, y)
		else
			legLow = math.min(legLow, y)
		end
	end
	local need = 0
	if legLow < math.huge then
		need = math.max(need, gg.restLow - legLow)
	end
	if bodyLow < math.huge then
		need = math.max(need, gg.restLow + gg.thick - bodyLow)
	end
	return math.max(0, need)
end

-- molla: va verso target con tempo caratteristico 1/k (piccolo k = piu' lenta, segue in ritardo)
local function spring(r: Rig, key: string, target: number, dt: number, k: number): number
	local v = r.s[key] or 0
	v += (target - v) * (1 - math.exp(-dt * k))
	r.s[key] = v
	return v
end

local function rot(j: Joint, yaw: number, pitch: number, roll: number): CFrame
	local cf = CFrame.identity
	if yaw ~= 0 then
		cf = CFrame.fromAxisAngle(j.up, yaw)
	end
	if pitch ~= 0 then
		cf *= CFrame.fromAxisAngle(j.right, pitch)
	end
	if roll ~= 0 then
		cf *= CFrame.fromAxisAngle(j.fwd, roll)
	end
	return cf
end

function DragonMotion.update(model: Model, dt: number, m: Motion)
	local r = rigs[model]
	if r == nil then
		r = build(model)
		rigs[model] = r
	end
	if not r then
		return
	end
	local rig = r :: Rig
	local air = math.clamp(m.air, 0, 1)
	local turn = math.clamp(m.turn, -3, 3)
	local moving = math.clamp(m.speed / 30, 0, 1)
	local dive = math.clamp((-m.vy - 15) / 35, 0, 1) * air
	local climb = math.clamp((m.vy - 8) / 25, 0, 1) * air
	-- da fermo (a terra o librato) la testa si guarda attorno piano
	local still = 1 - math.max(moving, dive)
	local lookYaw = math.noise(m.t * 0.22, rig.seed) * 1.6 * still
	local lookPitch = math.noise(m.t * 0.17, rig.seed + 13.7) * 0.5 * still

	-- collo: entra nella virata, si distende in picchiata (fino in linea con la schiena), si
	-- alza in salita; in volo ondeggia appena col battito
	local neckYaw = spring(rig, "ny", math.clamp(turn * 0.5, -0.95, 0.95) * math.max(air, 0.4) + lookYaw, dt, 4)
	local neckPitch = spring(rig, "np", -math.rad(rig.lift) * 0.9 * dive + 0.35 * climb + lookPitch, dt, 3)
	local neckWave = math.sin(m.t * 5.2) * 0.05 * air * (1 - dive)
	for _, j in rig.neck do
		rig.map[j.bone] = rot(j, neckYaw * j.w, (neckPitch + neckWave) * j.w, 0)
	end

	-- busto: piega verso l'interno della curva e si inclina (rollio), il petto piu' dell'anca;
	-- a terra ondeggia col passo
	local sway = math.sin(m.walk) * 0.05 * moving * (1 - air)
	local spineYaw = spring(rig, "sy", math.clamp(turn * 0.28, -0.5, 0.5) * air + sway, dt, 5)
	local spineRoll = spring(rig, "sr", math.clamp(turn * 0.4, -0.65, 0.65) * air, dt, 4)
	local spinePitch = spring(rig, "sp", -0.12 * dive + 0.1 * climb, dt, 3)
	for _, j in rig.spine do
		rig.map[j.bone] = rot(j, spineYaw * j.w, spinePitch * j.w, spineRoll * j.w)
	end
	if rig.hips then
		local h = rig.hips :: Joint
		rig.map[h.bone] = rot(h, 0, 0, math.cos(m.walk) * 0.04 * moving * (1 - air))
	end

	-- coda: dalla parte opposta alla virata e in ritardo (molla lenta), ondeggia in volo e si
	-- tende in picchiata
	-- la coda punta indietro: una rotazione positiva sull'asse in su porta la punta a destra,
	-- cioe' all'esterno di una virata a sinistra (turn > 0)
	local tailYaw = spring(rig, "ty", math.clamp(turn * 0.6, -1, 1), dt, 1.8)
	local tailPitch = spring(rig, "tp", 0.25 * dive - 0.2 * climb, dt, 2)
	for k, j in rig.tail do
		local wave = math.sin(m.t * (if air > 0.5 then 2.6 else 1.4) - k * 0.55) * (0.03 + 0.03 * air) * (1 - dive * 0.7)
		rig.map[j.bone] = rot(j, tailYaw * j.w + wave, tailPitch * j.w, 0)
	end
	KfsPlayer.setOverlay(model, rig.map)
end

return DragonMotion
