--!strict
-- Passi e IK dei draghi a terra (puro: solo Vector3, provato con tools/anim_test).
-- Usato da client/DragonProcedural:
--   * fabrik: porta la punta di una catena di ossa (zampa) su un punto, partendo dalla posa
--     dell'animazione (cosi' ginocchio e gomito piegano dalla parte giusta)
--   * passi: ogni piede resta FERMO nel mondo finche' e' appoggiato; quando la sua "casa" (dove
--     starebbe a riposo sotto la spalla o l'anca, piu' avanti se il drago corre) si allontana
--     troppo, fa un passo ad arco verso dove sara' la casa all'atterraggio. Al massimo due
--     zampe in aria e mai due dello stesso lato: viene fuori da solo il passo diagonale.
--     In curva le zampe esterne fanno passi piu' lunghi delle interne (la loro casa si sposta
--     di piu'), da fermo il drago si gira spostando le zampe una alla volta.

local DragonGait = {}

-- FABRIK: points[1] resta fermo, l'ultimo punto va su target; restituisce i nuovi punti
function DragonGait.fabrik(points: { Vector3 }, target: Vector3, iterations: number?): { Vector3 }
	local n = #points
	local p = table.clone(points)
	local len: { number } = {}
	local total = 0
	for i = 1, n - 1 do
		len[i] = (points[i + 1] - points[i]).Magnitude
		total += len[i]
	end
	local root = points[1]
	local toT = target - root
	if toT.Magnitude >= total then
		-- fuori portata: catena tesa verso il bersaglio
		local d = if toT.Magnitude > 1e-6 then toT.Unit else Vector3.new(0, -1, 0)
		for i = 2, n do
			p[i] = p[i - 1] + d * len[i - 1]
		end
		return p
	end
	for _ = 1, iterations or 8 do
		-- all'indietro dalla punta
		p[n] = target
		for i = n - 1, 1, -1 do
			local d = p[i] - p[i + 1]
			p[i] = p[i + 1] + (if d.Magnitude > 1e-6 then d.Unit else Vector3.new(0, 1, 0)) * len[i]
		end
		-- in avanti dalla radice
		p[1] = root
		for i = 2, n do
			local d = p[i] - p[i - 1]
			p[i] = p[i - 1] + (if d.Magnitude > 1e-6 then d.Unit else Vector3.new(0, -1, 0)) * len[i - 1]
		end
		if (p[n] - target).Magnitude < total * 1e-3 then
			break
		end
	end
	return p
end

export type LegState = {
	foot: Vector3, -- dove sta il piede adesso (mondo)
	planted: boolean,
	from: Vector3,
	to: Vector3,
	s: number, -- 0..1 durante il passo
	dur: number,
	side: number,
	front: boolean,
	len: number, -- lunghezza della zampa (studs)
	settle: number, -- secondi con il piede fuori posto da fermo
	lift: number, -- 0..1: quanto e' alzato (per abbassare il corpo da quel lato)
}

function DragonGait.newLeg(foot: Vector3, side: number, front: boolean, len: number): LegState
	return { foot = foot, planted = true, from = foot, to = foot, s = 0, dur = 0.3, side = side, front = front, len = len, settle = 0, lift = 0 }
end

export type GaitInput = {
	homes: { Vector3 }, -- dove starebbe ogni piede adesso (gia' a terra)
	landing: { Vector3 }, -- dove starebbe all'atterraggio di un passo che parte adesso (gia' a terra)
	speed: number, -- velocita' orizzontale (studs/s)
	up: Vector3,
	force: { boolean }?, -- piede appoggiato quasi fuori portata: deve partire subito
}

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- durata di un passo: zampe lunghe passi piu' lenti, di corsa piu' veloci
function DragonGait.stepDuration(len: number, speed: number): number
	local base = 0.22 + 0.06 * math.sqrt(len)
	return math.clamp(base / (1 + speed / (len * 2.2)), 0.12, 0.9)
end

function DragonGait.update(legs: { LegState }, dt: number, input: GaitInput)
	local swinging = 0
	local sideBusy: { [number]: boolean } = {}
	local pairBusy: { [boolean]: boolean } = {}
	-- 1) i passi in corso avanzano; il punto d'arrivo segue la casa che si sposta
	for i, l in legs do
		if not l.planted then
			l.to = input.landing[i]
			l.s = math.min(1, l.s + dt / l.dur)
			local k = smooth(l.s)
			local arc = math.sin(math.pi * l.s) * l.len * (0.12 + 0.1 * math.clamp(input.speed / (l.len * 3), 0, 1))
			l.foot = l.from:Lerp(l.to, k) + input.up * arc
			l.lift = math.sin(math.pi * l.s)
			if l.s >= 1 then
				l.planted = true
				l.foot = l.to
				l.lift = 0
				l.settle = 0
				swinging -= 1
			end
		end
	end
	for _, l in legs do
		if not l.planted then
			sideBusy[l.side] = true
			pairBusy[l.front] = true
		end
	end
	-- 2) quali piedi appoggiati devono partire: il piu' lontano dalla casa per primo
	local order: { { i: number, err: number } } = {}
	local moving = input.speed > 0.05
	for i, l in legs do
		if l.planted then
			local err = (l.foot - input.landing[i]).Magnitude
			local here = (l.foot - input.homes[i]).Magnitude
			local stride = l.len * (0.35 + 0.25 * math.clamp(input.speed / (l.len * 2), 0, 1))
			local want = false
			if moving then
				want = err > stride
			else
				-- da fermo: si sistema solo se e' proprio fuori posto, e dopo un attimo
				if here > l.len * 0.18 then
					l.settle += dt
				else
					l.settle = 0
				end
				want = here > l.len * 0.5 or l.settle > 0.35
			end
			local forced = input.force ~= nil and (input.force :: { boolean })[i] == true
			if want or forced then
				table.insert(order, { i = i, err = err / l.len + (if forced then 10 else 0) })
			end
		end
	end
	table.sort(order, function(a, b)
		return a.err > b.err
	end)
	for _, o in order do
		local l = legs[o.i]
		-- mai due zampe dello stesso lato ne' le due davanti (o le due dietro) insieme; un
		-- piede che sta per uscire dalla portata della zampa parte lo stesso (passo d'emergenza)
		local forced = o.err >= 10
		if (swinging >= 2 or sideBusy[l.side] or pairBusy[l.front]) and not (forced and swinging < 3) then
			continue
		end
		l.planted = false
		l.from = l.foot
		l.to = input.landing[o.i]
		l.s = 0
		l.dur = DragonGait.stepDuration(l.len, input.speed)
		swinging += 1
		sideBusy[l.side] = true
		pairBusy[l.front] = true
	end
end

-- porta p (piede sul terreno) dentro la portata della zampa che parte da root: se e' troppo
-- lontano scivola verso il punto sotto l'attacco, finche' la distanza e' reach
function DragonGait.clampReach(p: Vector3, root: Vector3, reach: number): Vector3
	local d = p - root
	if d.Magnitude <= reach then
		return p
	end
	local under = Vector3.new(root.X, p.Y, root.Z)
	local h = root.Y - p.Y
	if h >= reach then
		return under
	end
	local maxFlat = math.sqrt(reach * reach - h * h)
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude < 1e-6 then
		return under
	end
	return under + flat.Unit * maxFlat
end

-- molla smorzata (angolo o numero): x verso target con pulsazione w e smorzamento z (1 = critico)
export type Spring = { x: number, v: number }
function DragonGait.spring(s: Spring, target: number, dt: number, w: number, z: number): number
	-- integrazione semi-implicita in passi piccoli (stabile anche con dt grandi)
	local steps = math.max(1, math.ceil(dt * w / 0.5))
	local h = dt / steps
	for _ = 1, steps do
		local a = w * w * (target - s.x) - 2 * z * w * s.v
		s.v += a * h
		s.x += s.v * h
	end
	return s.x
end

return DragonGait
