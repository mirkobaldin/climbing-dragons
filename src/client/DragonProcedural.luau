--!strict
-- Animazioni procedurali dei draghi, SOPRA le animazioni a keyframe (KfsPlayer) e sopra
-- DragonMotion. Lavora dopo che KfsPlayer ha scritto le pose del frame (KfsPlayer.setPost):
--   * corpo: si adatta al terreno (beccheggio e rollio dai piedi davanti/dietro e destra/sinistra),
--     si abbassa dal lato della zampa che fa il passo, si piega verso l'interno in curva,
--     si carica e spinge (decollo), assorbe l'atterraggio (DragonProcedural.impulse)
--   * zampe: piedi FERMI sul terreno mentre sono appoggiati (raycast + IK FABRIK dalla posa
--     dell'animazione), passi ad arco generati dalla velocita' (shared/DragonGait); in curva le
--     zampe esterne fanno passi piu' lunghi, da fermo si gira spostando le zampe una alla volta;
--     in aria, scendendo verso il terreno, le zampe si allungano verso il suolo
--   * collo e coda: inerzia (restano indietro nelle virate e oscillano quando il drago si ferma)
--   * testa: guarda un punto (setLook), mascella che si apre (setJaw) se lo scheletro la ha
--   * ali in volo: nelle virate si inclinano insieme al corpo
--   * sella: il posto di chi monta segue il petto, ammortizzato (seat / seatShift / riderLean)
-- Lo scheletro si riconosce dalla forma (shared/DragonSkeleton): vale per tutti i draghi di Meshy,
-- giovani e adulti. Si accende con DragonProcedural.attach(model) (PetAnimator), si spegne
-- con detach o con DragonProcedural.enabled = false. Documentazione: docs/ANIMAZIONI_PROCEDURALI.md

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DragonSkeleton = require(Shared:WaitForChild("DragonSkeleton"))
local DragonGait = require(Shared:WaitForChild("DragonGait"))
local KfsPlayer = require(script.Parent.KfsPlayer)

local DragonProcedural = {}
DragonProcedural.enabled = true
-- oltre queste distanze (in lunghezze del drago, minimo in studs) si salta il lavoro
local LEGS_RANGE = 180
local ALL_RANGE = 320

type Spring = DragonGait.Spring
type Leg = {
	chain: { number },
	toe: number?,
	front: boolean,
	side: number,
	len: number,
	homeLocal: Vector3, -- piede a riposo, spazio del perno del modello
	state: DragonGait.LegState,
}
type Axes = { up: Vector3, right: Vector3, fwd: Vector3 } -- assi del corpo nello spazio a riposo dell'osso
type Rig = {
	model: Model,
	bones: { Bone },
	parentIdx: { number }, -- 0 = il genitore e' una parte
	parentPart: { BasePart? },
	axes: { Axes },
	restPivot: { CFrame }, -- riposo nello spazio del perno
	sk: DragonSkeleton.Skeleton,
	scale: number,
	size: number, -- lunghezza del drago (studs)
	legs: { Leg },
	base: { [number]: CFrame }, -- posa dell'animazione (prima di noi)
	written: { [number]: CFrame }, -- cosa abbiamo scritto l'ultima volta
	cur: { CFrame }, -- posa di lavoro del frame
	W: { CFrame }, -- mondo del frame
	-- moto
	lastPivot: CFrame?,
	vel: Vector3,
	acc: Vector3,
	yawRate: number,
	air: number,
	airSet: number?,
	groundW: number,
	legW: number, -- 1 in piedi o camminando, 0 seduto o addormentato
	-- molle
	springs: { [string]: Spring },
	look: Vector3?,
	jaw: number,
	kick: number, -- velocita' verticale aggiunta al corpo (impulsi)
	-- sella
	seatLocal: CFrame?,
	seatRestPivot: Vector3?,
	seatCF: CFrame?,
	seatShift: Vector3,
	lean: Vector2,
	-- ordine rispetto a chi sposta il modello
	pivotAtPost: CFrame?,
	movesAfter: number, -- >0: chi sposta il modello lo fa DOPO di noi (si anticipa)
	predict: CFrame,
	params: RaycastParams,
	paramsAt: number,
}

local rigs: { [Model]: Rig } = {}

local function spring(r: Rig, key: string): Spring
	local s = r.springs[key]
	if not s then
		s = { x = 0, v = 0 }
		r.springs[key] = s
	end
	return s
end

local function fromTo(a: Vector3, b: Vector3): CFrame
	local ma, mb = a.Magnitude, b.Magnitude
	if ma < 1e-6 or mb < 1e-6 then
		return CFrame.identity
	end
	local ua, ub = a / ma, b / mb
	local axis = ua:Cross(ub)
	local s = axis.Magnitude
	local c = ua:Dot(ub)
	if s < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis / s, math.atan2(s, c))
end

local function about(point: Vector3, rot: CFrame): CFrame
	return CFrame.new(point) * rot * CFrame.new(-point)
end

local function build(model: Model): Rig?
	local bones: { Bone } = {}
	local index: { [Bone]: number } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			table.insert(bones, d)
			index[d] = #bones
		end
	end
	if #bones < 8 then
		return nil
	end
	local parentIdx: { number } = {}
	local parentPart: { BasePart? } = {}
	local restWorld: { CFrame } = {}
	local pivot = model:GetPivot()
	local function rest(i: number): CFrame
		local done = restWorld[i]
		if done then
			return done
		end
		local b = bones[i]
		local p = b.Parent
		local base: CFrame
		if p and p:IsA("Bone") and index[p] then
			parentIdx[i] = index[p]
			base = rest(index[p])
		elseif p and p:IsA("BasePart") then
			parentIdx[i] = 0
			parentPart[i] = p
			base = p.CFrame
		else
			parentIdx[i] = 0
			base = pivot
		end
		local cf = base * b.CFrame
		restWorld[i] = cf
		return cf
	end
	local input: { DragonSkeleton.BoneIn } = {}
	local restPivot: { CFrame } = {}
	for i = 1, #bones do
		restPivot[i] = pivot:ToObjectSpace(rest(i))
		input[i] = { pos = restPivot[i].Position, parent = parentIdx[i] }
	end
	local sk, err = DragonSkeleton.analyze(input)
	if not sk then
		warn("[DragonProcedural] " .. model.Name .. ": " .. tostring(err))
		return nil
	end
	local skel = sk :: DragonSkeleton.Skeleton
	local up = Vector3.yAxis
	local axes: { Axes } = {}
	for i = 1, #bones do
		local r = restPivot[i]
		axes[i] = { up = r:VectorToObjectSpace(up), right = r:VectorToObjectSpace(skel.right), fwd = r:VectorToObjectSpace(skel.fwd) }
	end
	local legs: { Leg } = {}
	for _, l in skel.legs do
		local len = 0
		for k = 1, #l.chain - 1 do
			len += (restPivot[l.chain[k + 1]].Position - restPivot[l.chain[k]].Position).Magnitude
		end
		local homeLocal = restPivot[l.chain[#l.chain]].Position
		local foot = pivot * homeLocal
		table.insert(legs, {
			chain = l.chain,
			toe = l.toe,
			front = l.front,
			side = l.side,
			len = len,
			homeLocal = homeLocal,
			state = DragonGait.newLeg(foot, l.side, l.front, len),
		})
	end
	-- sella: attributo Seat del server (spazio del perno) o base del collo come DragonModels
	local seatPos: Vector3? = nil
	local s = model:GetAttribute("Seat")
	if typeof(s) == "Vector3" then
		seatPos = s
	elseif skel.neck[1] then
		seatPos = restPivot[skel.neck[1]].Position - skel.fwd * skel.length * 0.05 + up * skel.length * 0.075
	end
	local seatLocal: CFrame? = nil
	if seatPos then
		local body = CFrame.fromMatrix(seatPos :: Vector3, skel.right, up)
		seatLocal = restPivot[skel.chest]:Inverse() * body
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	return {
		model = model,
		bones = bones,
		parentIdx = parentIdx,
		parentPart = parentPart,
		axes = axes,
		restPivot = restPivot,
		sk = skel,
		scale = model:GetScale(),
		size = math.max(skel.length, 1),
		legs = legs,
		base = {},
		written = {},
		cur = {},
		W = {},
		vel = Vector3.zero,
		acc = Vector3.zero,
		yawRate = 0,
		air = 0,
		groundW = 1,
		legW = 1,
		springs = {},
		jaw = 0,
		kick = 0,
		seatLocal = seatLocal,
		seatRestPivot = seatPos,
		seatShift = Vector3.zero,
		lean = Vector2.zero,
		movesAfter = 0,
		predict = CFrame.identity,
		params = params,
		paramsAt = -math.huge,
	}
end

-- mondo di tutte le ossa con la posa di lavoro (le ossa sono in ordine: genitori prima)
local function computeWorld(r: Rig)
	for i, b in r.bones do
		local pi = r.parentIdx[i]
		local parentW: CFrame
		if pi > 0 then
			parentW = r.W[pi]
		else
			local part = r.parentPart[i]
			parentW = r.predict * (if part then part.CFrame else r.model:GetPivot())
		end
		r.W[i] = parentW * b.CFrame * r.cur[i]
	end
end

local function parentWorld(r: Rig, i: number): CFrame
	local pi = r.parentIdx[i]
	if pi > 0 then
		return r.W[pi]
	end
	local part = r.parentPart[i]
	return r.predict * (if part then part.CFrame else r.model:GetPivot())
end

-- applica una trasformazione nel mondo all'osso i (e per forza ai figli)
local function applyWorld(r: Rig, i: number, delta: CFrame)
	local A = parentWorld(r, i) * r.bones[i].CFrame
	r.cur[i] = A:Inverse() * delta * A * r.cur[i]
	r.W[i] = A * r.cur[i]
end

-- rotazione negli assi a riposo dell'osso (come gli overlay di KfsPlayer), prima della posa
local function preRotate(r: Rig, i: number, axis: Vector3, angle: number)
	if math.abs(angle) > 1e-5 then
		r.cur[i] = CFrame.fromAxisAngle(axis, angle) * r.cur[i]
	end
end

local function updateParams(r: Rig)
	local now = os.clock()
	if now - r.paramsAt < 1 then
		return
	end
	r.paramsAt = now
	local list: { Instance } = { r.model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	r.params.FilterDescendantsInstances = list
end

local function groundAt(r: Rig, p: Vector3, reach: number): (Vector3?, Vector3)
	local hit = workspace:Raycast(p + Vector3.yAxis * reach, Vector3.yAxis * (-reach * 2.5), r.params)
	if hit then
		return hit.Position, hit.Normal
	end
	return nil, Vector3.yAxis
end

-- IK di una zampa: la catena va dal punto d'attacco al piede; il piede va su target
local function solveLeg(r: Rig, leg: Leg, target: Vector3, weight: number)
	local chain = leg.chain
	local pts: { Vector3 } = {}
	for k, bi in chain do
		pts[k] = r.W[bi].Position
	end
	local goal = pts[#pts]:Lerp(target, math.clamp(weight, 0, 1))
	local q = DragonGait.fabrik(pts, goal, 10)
	for k = 1, #chain - 1 do
		local bi = chain[k]
		local child = r.bones[chain[k + 1]]
		local cur = r.W[bi] * child.CFrame.Position - r.W[bi].Position
		local want = q[k + 1] - r.W[bi].Position
		applyWorld(r, bi, about(r.W[bi].Position, fromTo(cur, want)))
		-- il figlio si aggiorna dal genitore nuovo
		local ci = chain[k + 1]
		r.W[ci] = r.W[bi] * child.CFrame * r.cur[ci]
	end
end

-- dita del piede parallele al terreno (solo se il piede e' appoggiato)
local function flattenToe(r: Rig, leg: Leg, normal: Vector3, weight: number)
	local toe = leg.toe
	if not toe or weight < 0.01 then
		return
	end
	local fi = leg.chain[#leg.chain]
	local child = r.bones[toe]
	local cur = r.W[fi] * child.CFrame.Position - r.W[fi].Position
	local flat = cur - normal * cur:Dot(normal)
	if flat.Magnitude < 1e-4 then
		return
	end
	local want = cur:Lerp(flat.Unit * cur.Magnitude, weight)
	applyWorld(r, fi, about(r.W[fi].Position, fromTo(cur, want)))
end

local function post(r: Rig, dt: number)
	local model = r.model
	if not DragonProcedural.enabled or not model.Parent or dt <= 0 then
		return
	end
	dt = math.min(dt, 1 / 20)
	local pivot = model:GetPivot()
	local cam = workspace.CurrentCamera
	local dist = if cam then (cam.CFrame.Position - pivot.Position).Magnitude else 0
	if dist > math.max(ALL_RANGE, r.size * 6) then
		-- lontano: si tolgono le nostre modifiche (le ossa non animate le terrebbero)
		for i, b in r.bones do
			local w = r.written[i]
			local base = r.base[i]
			if w and base and b.Transform == (w :: CFrame) then
				b.Transform = base
			end
		end
		r.written = {}
		r.lastPivot = nil
		return
	end
	if math.abs(model:GetScale() - r.scale) > 1e-3 then
		-- il drago e' cresciuto o e' stato scalato: si rifa' tutto
		local nr = build(model)
		if nr then
			rigs[model] = nr
		end
		return
	end
	updateParams(r)
	-- posa dell'animazione: se KfsPlayer non ha riscritto un osso, la base resta quella di prima
	for i, b in r.bones do
		local t = b.Transform
		local w = r.written[i]
		if not w or t ~= (w :: CFrame) then
			r.base[i] = t
		end
		r.cur[i] = r.base[i] or t
	end
	-- moto del corpo (dal perno) e anticipo se il modello viene spostato dopo di noi
	-- se chi sposta il modello lo fa dopo di noi, il perno che leggiamo e' quello del frame
	-- prima: si anticipa del movimento dell'ultimo frame (se no i piedi scivolano di v*dt)
	if r.movesAfter > 0 and r.lastPivot then
		local delta = (r.lastPivot :: CFrame):Inverse() * pivot
		r.predict = (pivot * delta) * pivot:Inverse()
	else
		r.predict = CFrame.identity
	end
	local rawPivot = pivot
	pivot = r.predict * pivot
	local sk = r.sk
	local fwdW = pivot:VectorToWorldSpace(sk.fwd)
	local rightW = pivot:VectorToWorldSpace(sk.right)
	if r.lastPivot then
		-- velocita' vera: fra due letture del perno (un frame), senza l'anticipo
		local lp = r.lastPivot :: CFrame
		local v = (rawPivot.Position - lp.Position) / dt
		local dv = (v - r.vel) / dt
		r.vel = r.vel:Lerp(v, math.min(1, dt * 12))
		r.acc = r.acc:Lerp(dv, math.min(1, dt * 6))
		local f0 = lp:VectorToWorldSpace(sk.fwd)
		local f1 = rawPivot:VectorToWorldSpace(sk.fwd)
		local yaw = math.atan2(f0:Cross(f1).Y, f0:Dot(f1))
		r.yawRate += (yaw / dt - r.yawRate) * math.min(1, dt * 10)
	end
	r.lastPivot = rawPivot
	local flatVel = Vector3.new(r.vel.X, 0, r.vel.Z)
	local speed = flatVel.Magnitude
	local size = r.size
	computeWorld(r)

	-- in aria o a terra: dal valore di PetAnimator o, se manca, dalla distanza dal terreno
	local hipsW = r.W[sk.hips].Position
	local restHipsH = r.restPivot[sk.hips].Position.Y - sk.ground
	local air = r.airSet
	if air == nil then
		local g = groundAt(r, hipsW, restHipsH * 3)
		air = if g and (hipsW.Y - (g :: Vector3).Y) < restHipsH * 1.5 then 0 else 1
	end
	r.air += ((air :: number) - r.air) * math.min(1, dt * 8)
	-- seduto o addormentato (setLegs 0): niente piedi a terra ne' corpo sul terreno
	local groundW = (1 - r.air) * r.legW
	r.groundW = groundW
	local nearLegs = dist < math.max(LEGS_RANGE, size * 4) and #r.legs >= 2

	-- 1) corpo: altezza, beccheggio e rollio dai piedi; inclinazione in curva e con la spinta
	local up = Vector3.yAxis
	if groundW > 0.01 and nearLegs then
		local fSum, fN, bSum, bN, rSum, rN, lSum, lN = 0, 0, 0, 0, 0, 0, 0, 0
		local fz, bz = 0, 0
		for _, leg in r.legs do
			local restY = (pivot * leg.homeLocal).Y
			local d = leg.state.foot.Y - restY
			if not leg.state.planted then
				d = (leg.state.to.Y - restY) - leg.len * 0.06 * leg.state.lift
			end
			d = math.clamp(d, -leg.len * 0.6, leg.len * 0.6)
			if leg.front then
				fSum += d
				fN += 1
				fz += leg.homeLocal:Dot(sk.fwd)
			else
				bSum += d
				bN += 1
				bz += leg.homeLocal:Dot(sk.fwd)
			end
			if leg.side > 0 then
				rSum += d
				rN += 1
			else
				lSum += d
				lN += 1
			end
		end
		local front = if fN > 0 then fSum / fN else 0
		local back = if bN > 0 then bSum / bN else 0
		local rgt = if rN > 0 then rSum / rN else 0
		local lft = if lN > 0 then lSum / lN else 0
		local span = math.max((if fN > 0 then fz / fN else 1) - (if bN > 0 then bz / bN else 0), 0.1)
		local width = math.max(sk.height * 0.35, 0.1)
		local accF = r.acc:Dot(fwdW) / size
		-- in accelerazione le zampe dietro spingono e il petto si alza; in frenata scende
		local pitchT = math.atan2(front - back, span) + math.clamp(accF * 0.02, -0.08, 0.08)
		local rollT = -math.atan2(rgt - lft, width) - math.clamp(speed * r.yawRate / size * 0.12, -0.12, 0.12)
		local heightT = (front + back) * 0.5
		local pitch = DragonGait.spring(spring(r, "bodyPitch"), pitchT * groundW, dt, 9, 0.9)
		local roll = DragonGait.spring(spring(r, "bodyRoll"), rollT * groundW, dt, 9, 0.9)
		local hs = spring(r, "bodyH")
		hs.v += r.kick * size
		r.kick = 0
		local h = DragonGait.spring(hs, heightT * groundW, dt, 10, 0.55)
		local rot = CFrame.fromAxisAngle(rightW, pitch) * CFrame.fromAxisAngle(fwdW, roll)
		applyWorld(r, sk.root, CFrame.new(up * h) * about(hipsW, rot))
		r.lean = Vector2.new(roll, pitch)
	else
		-- in aria il corpo torna a zero piano (e gli impulsi si consumano)
		local hs = spring(r, "bodyH")
		hs.v += r.kick * size
		r.kick = 0
		local h = DragonGait.spring(hs, 0, dt, 8, 0.7)
		local pitch = DragonGait.spring(spring(r, "bodyPitch"), 0, dt, 6, 1)
		local roll = DragonGait.spring(spring(r, "bodyRoll"), 0, dt, 6, 1)
		if math.abs(h) + math.abs(pitch) + math.abs(roll) > 1e-4 then
			applyWorld(r, sk.root, CFrame.new(up * h) * about(hipsW, CFrame.fromAxisAngle(rightW, pitch) * CFrame.fromAxisAngle(fwdW, roll)))
		end
		r.lean = Vector2.new(roll, pitch)
	end

	-- 2) collo e coda: inerzia nelle virate (la coda resta fuori, poi rientra oscillando)
	local yawRate = math.clamp(r.yawRate, -3, 3)
	local accUp = math.clamp(r.acc.Y / size, -3, 3)
	local nNeck = #sk.neck
	for k, bi in sk.neck do
		local w = k / math.max(nNeck, 1)
		local yaw = DragonGait.spring(spring(r, "neckY" .. k), -yawRate * 0.05 * w, dt, 7, 0.45)
		-- accelerando in su la testa resta indietro (giu')
		local pitch = DragonGait.spring(spring(r, "neckP" .. k), -accUp * 0.02 * w, dt, 7, 0.45)
		preRotate(r, bi, r.axes[bi].up, yaw)
		preRotate(r, bi, r.axes[bi].right, pitch)
	end
	local nTail = #sk.tail
	for k, bi in sk.tail do
		local w = k / math.max(nTail, 1)
		local yaw = DragonGait.spring(spring(r, "tailY" .. k), yawRate * 0.09 * w, dt, 5 - 2.5 * w, 0.35)
		-- la coda punta indietro: una rotazione positiva sull'asse destro abbassa la punta
		local pitch = DragonGait.spring(spring(r, "tailP" .. k), accUp * 0.03 * w, dt, 5 - 2.5 * w, 0.35)
		preRotate(r, bi, r.axes[bi].up, yaw)
		preRotate(r, bi, r.axes[bi].right, pitch)
	end

	-- 3) sguardo e mascella
	computeWorld(r)
	local lookYaw, lookPitch = 0, 0
	if r.look then
		local headPos = r.W[sk.head].Position
		local dir = (r.look :: Vector3) - headPos
		if dir.Magnitude > 0.01 then
			local f = dir:Dot(fwdW)
			lookYaw = math.clamp(math.atan2(-dir:Dot(rightW), f), -1.2, 1.2)
			lookPitch = math.clamp(math.atan2(dir.Y, math.sqrt(f * f + dir:Dot(rightW) ^ 2)), -0.6, 0.6)
		end
	end
	local ly = DragonGait.spring(spring(r, "lookY"), lookYaw, dt, 6, 1)
	local lp = DragonGait.spring(spring(r, "lookP"), lookPitch, dt, 6, 1)
	if math.abs(ly) + math.abs(lp) > 1e-4 then
		-- distribuito: piu' sulla testa e sulla parte alta del collo
		local chainLook = table.clone(sk.neck)
		table.insert(chainLook, sk.head)
		local total = 0
		for k in chainLook do
			total += k
		end
		for k, bi in chainLook do
			local w = k / total
			preRotate(r, bi, r.axes[bi].up, ly * w)
			preRotate(r, bi, r.axes[bi].right, lp * w)
		end
	end
	if sk.jaw[1] then
		local open = DragonGait.spring(spring(r, "jaw"), r.jaw, dt, 14, 0.8)
		local ji = sk.jaw[1]
		preRotate(r, ji, r.axes[ji].right, -open * 0.5)
	end

	-- 4) ali in volo: nella virata si inclinano col corpo
	if r.air > 0.05 then
		local bank = DragonGait.spring(spring(r, "wingBank"), -yawRate * 0.18 * r.air, dt, 6, 0.8)
		for _, wing in sk.wings do
			local wi = wing.arm[1]
			preRotate(r, wi, r.axes[wi].fwd, bank)
		end
	end
	computeWorld(r)

	-- 5) zampe: passi e IK a terra; in aria, scendendo, si allungano verso il suolo
	if nearLegs and r.legW > 0.05 then
		local homes: { Vector3 } = {}
		local landing: { Vector3 } = {}
		local normals: { Vector3 } = {}
		for i, leg in r.legs do
			local home = pivot * leg.homeLocal
			local g, n = groundAt(r, home, leg.len * 1.5)
			homes[i] = g or home
			normals[i] = n
			-- atterraggio un po' avanti (meta' appoggio sotto la spalla), ruotato con la virata
			local dur = DragonGait.stepDuration(leg.len, speed)
			local ahead = home + flatVel * dur * 0.6
			local rel = ahead - pivot.Position
			local spin = CFrame.fromAxisAngle(up, r.yawRate * dur * 0.6)
			ahead = pivot.Position + spin * rel
			local g2 = groundAt(r, ahead, leg.len * 1.5)
			-- mai oltre la portata della zampa (zampe quasi tese a riposo: Eclissi adulto)
			local root = r.W[leg.chain[1]].Position
			landing[i] = DragonGait.clampReach(g2 or ahead, root, leg.len * 0.97)
			homes[i] = DragonGait.clampReach(homes[i], root, leg.len * 0.97)
		end
		if groundW > 0.5 then
			local states: { DragonGait.LegState } = {}
			for i, leg in r.legs do
				states[i] = leg.state
			end
			local force: { boolean } = {}
			for i, leg in r.legs do
				force[i] = leg.state.planted and (leg.state.foot - r.W[leg.chain[1]].Position).Magnitude > leg.len * 0.93
			end
			DragonGait.update(states, dt, { homes = homes, landing = landing, speed = speed, up = up, force = force })
			for i, leg in r.legs do
				solveLeg(r, leg, leg.state.foot, groundW)
				flattenToe(r, leg, normals[i], if leg.state.planted then groundW else 0)
			end
		elseif r.air > 0.5 then
			-- in aria: piedi pronti per l'atterraggio; se il terreno e' vicino e si scende,
			-- le zampe si allungano verso il suolo
			local descending = r.vel.Y < -1
			for i, leg in r.legs do
				local footW = r.W[leg.chain[#leg.chain]].Position
				leg.state.foot = homes[i]
				leg.state.planted = true
				leg.state.lift = 0
				if descending then
					local gap = footW.Y - homes[i].Y
					local reach = math.clamp(1 - gap / (leg.len * 2.5), 0, 1) * 0.8
					if reach > 0.01 then
						solveLeg(r, leg, Vector3.new(footW.X, homes[i].Y, footW.Z), reach)
					end
				end
			end
		end
	end

	-- 6) sella: segue il petto, ammortizzata
	if r.seatLocal then
		computeWorld(r)
		local target = r.W[sk.chest] * (r.seatLocal :: CFrame)
		local prev = r.seatCF
		if prev then
			local k = math.min(1, dt * 14)
			r.seatCF = CFrame.new(prev.Position:Lerp(target.Position, k)) * prev.Rotation:Lerp(target.Rotation, k)
		else
			r.seatCF = target
		end
		if r.seatRestPivot then
			local now = pivot:PointToObjectSpace((r.seatCF :: CFrame).Position)
			r.seatShift = now - (r.seatRestPivot :: Vector3)
		end
	end

	-- scrive solo le ossa cambiate
	for i, b in r.bones do
		local c = r.cur[i]
		local base = r.base[i]
		if not base or c ~= (base :: CFrame) or r.written[i] then
			b.Transform = c
			r.written[i] = c
		end
	end
	r.pivotAtPost = rawPivot
end

-- chi sposta il modello lo fa prima o dopo di noi? (stesso frame: si guarda a Heartbeat)
RunService.Heartbeat:Connect(function()
	for model, r in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		if r.pivotAtPost then
			local moved = (model:GetPivot().Position - (r.pivotAtPost :: CFrame).Position).Magnitude > 1e-4
			r.movesAfter = math.clamp(r.movesAfter + (if moved then 1 else -1), -10, 10)
			r.pivotAtPost = nil
		end
	end
end)

-- API ----------------------------------------------------------------------------------------

-- accende il procedurale su un drago animato da KfsPlayer; false se lo scheletro non va
function DragonProcedural.attach(model: Model): boolean
	if rigs[model] then
		return true
	end
	local r = build(model)
	if not r then
		return false
	end
	rigs[model] = r
	KfsPlayer.setPost(model, function(dt: number)
		local cur = rigs[model]
		if cur then
			post(cur, dt)
		end
	end)
	return true
end

function DragonProcedural.detach(model: Model)
	local r = rigs[model]
	if r then
		for i, b in r.bones do
			if r.base[i] then
				b.Transform = r.base[i]
			end
		end
	end
	rigs[model] = nil
	KfsPlayer.setPost(model, nil)
end

-- 0 a terra, 1 in volo (PetAnimator.airBlend); nil = lo stima da solo col terreno
function DragonProcedural.setAir(model: Model, air: number?)
	local r = rigs[model]
	if r then
		r.airSet = air
	end
end

-- 1 in piedi o camminando, 0 seduto o addormentato (posa a terra che non e' sulle zampe)
function DragonProcedural.setLegs(model: Model, weight: number)
	local r = rigs[model]
	if r then
		r.legW += (math.clamp(weight, 0, 1) - r.legW) * 0.2
	end
end

-- punto da guardare (nil = niente)
function DragonProcedural.setLook(model: Model, target: Vector3?)
	local r = rigs[model]
	if r then
		r.look = target
	end
end

-- mascella: 0 chiusa, 1 aperta (ruggito, soffio, morso). Solo se lo scheletro ha la mascella
function DragonProcedural.setJaw(model: Model, open: number)
	local r = rigs[model]
	if r then
		r.jaw = math.clamp(open, 0, 1)
	end
end

-- "decollo": il corpo si carica (scende) e spinge; "atterraggio": assorbe; "colpito": scatto
function DragonProcedural.impulse(model: Model, kind: string)
	local r = rigs[model]
	if not r then
		return
	end
	if kind == "decollo" then
		r.kick -= 0.35
	elseif kind == "atterraggio" then
		r.kick -= 0.5
	elseif kind == "colpito" then
		r.kick -= 0.2
		local s = spring(r, "bodyRoll")
		s.v += (if math.random() < 0.5 then -1 else 1) * 1.5
	end
end

-- posto di chi monta (mondo), ammortizzato; nil se non c'e'
function DragonProcedural.seat(model: Model): CFrame?
	local r = rigs[model]
	return r and r.seatCF
end

-- di quanto la sella si e' spostata rispetto al riposo (spazio del perno): PetAnimator lo
-- aggiunge a pet.seat in monta, cosi' il giocatore resta sulla sella mentre il corpo si muove
function DragonProcedural.seatShift(model: Model): Vector3
	local r = rigs[model]
	return if r then r.seatShift else Vector3.zero
end

-- inclinazione del corpo (rollio, beccheggio in radianti): per far piegare anche chi monta
function DragonProcedural.riderLean(model: Model): Vector2
	local r = rigs[model]
	return if r then r.lean else Vector2.zero
end

-- stato di una zampa (per i test in tools/anim_test)
function DragonProcedural._debugLeg(model: Model, i: number): DragonGait.LegState?
	local r = rigs[model]
	local leg = r and r.legs[i]
	return leg and leg.state
end

-- riassunto dello scheletro riconosciuto (per i log e il comando admin)
function DragonProcedural.info(model: Model): string
	local r = rigs[model] or build(model)
	if not r then
		return model.Name .. ": scheletro non riconosciuto"
	end
	local sk = r.sk
	local nf, nb = 0, 0
	for _, l in sk.legs do
		if l.front then
			nf += 1
		else
			nb += 1
		end
	end
	return string.format("%s: %d ossa, collo %d, testa %s, mascella %s, corna %d, coda %d, zampe %d+%d, ali %d, lungo %.1f%s",
		model.Name, #r.bones, #sk.neck, r.bones[sk.head].Name, if sk.jaw[1] then r.bones[sk.jaw[1]].Name else "no", #sk.horns,
		#sk.tail, nf, nb, #sk.wings, sk.length, if #sk.warnings > 0 then " (" .. table.concat(sk.warnings, "; ") .. ")" else "")
end

return DragonProcedural
