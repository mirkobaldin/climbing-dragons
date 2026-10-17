--!strict
-- Movimenti secondari dei draghi, sopra le animazioni (KfsPlayer.setOverlay): Mirko trovava le
-- animazioni rigide (collo e testa sempre nella stessa posizione, busto fermo nelle virate, testa
-- che non si distende in picchiata). Qui, ogni frame, dal volo vero del drago:
--   collo e testa entrano nella virata e, da fermo, si guardano attorno
--   busto: si torce e si inclina verso l'interno della curva (il petto piu' dell'anca)
--   coda: segue in ritardo dalla parte opposta e ondeggia in volo
--   picchiata: il collo si distende in linea col corpo; in salita la testa si alza
--   collo che si DISTENDE (Mirko 17/10: "il collo rimane sempre piegato a S, non si distende
--   mai"): ogni vertebra si raddrizza di una parte della sua piega a riposo (j.straight), poco a
--   terra, molto in volo veloce e in picchiata; da fermo ogni tanto il drago si stiracchia
--   a terra: il bacino ondeggia col passo
-- I ruoli e gli assi delle ossa li scrive il server (DragonModels.markBones, attributi Ruolo,
-- Indice, AsseSu, AsseDx, AsseAv e CollaAlzo sul modello).

local KfsPlayer = require(script.Parent.KfsPlayer)

local DragonMotion = {}
DragonMotion.STRETCH = true -- collo che si distende (vedi update)

export type Motion = {
	turn: number, -- velocita' di virata (rad/s, + a sinistra)
	vy: number, -- velocita' verticale (studs/s)
	speed: number, -- velocita' orizzontale (studs/s)
	air: number, -- 0 a terra, 1 in volo
	walk: number, -- fase del passo (radianti)
	t: number, -- tempo
}

type Joint = { bone: Bone, w: number, up: Vector3, right: Vector3, fwd: Vector3, i: number, n: number, straight: number }
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
-- modelli senza ossa riconosciute: si riprova ogni 2 s (le ossa possono arrivare dopo, streaming)
local retryAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

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
					straight = 0,
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
	-- raddrizzamento del collo: per ogni vertebra, l'angolo attorno al suo asse destro che porta
	-- il pezzo dopo (fino alla vertebra seguente, o alla testa) in linea col pezzo prima. Dalla
	-- posa a riposo (Bone.WorldCFrame non contiene le animazioni). Ruotare l'osso di questo angolo
	-- toglie la sua parte di "S"; se ne usa una frazione (extend in update)
	local neck = lists.neck
	for k, j in neck do
		local b = j.bone
		local prev: Vector3? = nil
		local nextP: Vector3? = nil
		local parent = b.Parent
		if k > 1 then
			prev = neck[k - 1].bone.WorldPosition
		elseif parent and parent:IsA("Bone") then
			prev = parent.WorldPosition
		end
		if k < #neck then
			nextP = neck[k + 1].bone.WorldPosition
		else
			for _, c in b:GetChildren() do
				if c:IsA("Bone") then
					nextP = c.WorldPosition
					break
				end
			end
		end
		if prev and nextP then
			local cf = b.WorldCFrame
			local ax = j.right
			local pv = cf:VectorToObjectSpace(b.WorldPosition - (prev :: Vector3))
			local cv = cf:VectorToObjectSpace((nextP :: Vector3) - b.WorldPosition)
			pv -= ax * pv:Dot(ax)
			cv -= ax * cv:Dot(ax)
			if pv.Magnitude > 1e-3 and cv.Magnitude > 1e-3 then
				-- la prima vertebra parte dal petto, con un angolo che cambia molto da drago a
				-- drago: si raddrizza solo in parte
				j.straight = math.clamp(math.atan2(cv:Cross(pv):Dot(ax), cv:Dot(pv)), -0.9, 0.9) * (if k == 1 then 0.5 else 1)
			end
		end
	end
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
	if g == nil or (g == false and os.clock() >= (retryAt[model] or 0)) then
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
	if r == nil or (r == false and os.clock() >= (retryAt[model] or 0)) then
		r = build(model)
		rigs[model] = r
		retryAt[model] = os.clock() + 2
	end
	if not r then
		return
	end
	local rig = r :: Rig
	local air = math.clamp(m.air, 0, 1)
	-- virata filtrata (Mirko 17/10: tremolii): sotto 0,15 rad/s e da quasi fermi la direzione del
	-- drago cambia per piccoli aggiustamenti, non per una curva vera: era rumore che faceva
	-- tremare collo, busto e coda
	local rawTurn = math.clamp(m.turn, -3, 3)
	rawTurn = if math.abs(rawTurn) < 0.15 then 0 else rawTurn - math.sign(rawTurn) * 0.15
	rawTurn *= math.clamp((m.speed - 2) / 10, 0, 1)
	local turn = spring(rig, "turnIn", rawTurn, dt, 3)
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
	local neckWave = math.sin(m.t * 5.2) * 0.03 * air * (1 - dive)
	-- quanto si distende il collo (0 = la posa dell'animazione, 1 = dritto): in volo veloce e
	-- in planata si allunga davanti, in picchiata tutto, camminando un po'; da fermo ogni 14 s
	-- circa si stiracchia (sale piano, resta un attimo, torna)
	local stretchPulse = math.max(0, math.sin(m.t * (2 * math.pi / 14) + rig.seed)) ^ 4 * 0.65 * still
	local extendT = math.max(
		air * (0.35 + 0.45 * moving),
		dive,
		0.25 * climb + 0.3 * air,
		0.3 * moving * (1 - air),
		stretchPulse
	)
	-- prova in Studio: attributo ColloDisteso = false sul modello (o DragonMotion.STRETCH =
	-- false) per confrontare con la posa dell'animazione
	if not DragonMotion.STRETCH or model:GetAttribute("ColloDisteso") == false then
		extendT = 0
	end
	local extend = spring(rig, "ext", math.clamp(extendT, 0, 1), dt, 2)
	for _, j in rig.neck do
		rig.map[j.bone] = rot(j, neckYaw * j.w, (neckPitch + neckWave) * j.w + j.straight * extend, 0)
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
