-- Simulazione dei passi (DragonGait) con le proporzioni vere di Drago_Gelo: dritto, in curva,
-- fermo; e FABRIK sulle zampe vere.
local fallimenti = 0
local function check(cond: boolean, msg: string)
	if not cond then
		fallimenti += 1
		print("  ERRORE: " .. msg)
	end
end
local d = SCHELETRI[4]
assert(d.nome == "Drago_Gelo")
local sk = assert(DragonSkeleton.analyze(d.ossa))
local UP = Vector3.new(0, 1, 0)
-- offset di riposo dei piedi rispetto al bacino, sul piano (spazio del corpo: x destra, z avanti)
local hipsP = d.ossa[sk.hips].pos
local offs, lens = {}, {}
for i, l in sk.legs do
	local foot = d.ossa[l.chain[#l.chain]].pos
	local rel = foot - hipsP
	offs[i] = Vector3.new(rel:Dot(sk.right), 0, rel:Dot(sk.fwd))
	local L = 0
	for k = 1, #l.chain - 1 do
		L += (d.ossa[l.chain[k + 1]].pos - d.ossa[l.chain[k]].pos).Magnitude
	end
	lens[i] = L
end
local function world(pos: Vector3, yaw: number, o: Vector3): Vector3
	-- yaw 0 = avanti verso -Z; destra = +X
	local c, s = math.cos(yaw), math.sin(yaw)
	local fwd = Vector3.new(-s, 0, -c)
	local right = Vector3.new(c, 0, -s)
	return pos + right * o.X + fwd * o.Z
end
local legs = {}
for i, l in sk.legs do
	legs[i] = DragonGait.newLeg(world(Vector3.zero, 0, offs[i]), l.side, l.front, lens[i])
end
local pos, yaw = Vector3.zero, 0
local dt = 1 / 60
local maxSwing, sameSide, maxReach, slide = 0, 0, 0, 0
local stepLen = { 0, 0, 0, 0 }
local stepCnt = { 0, 0, 0, 0 }
local function run(seconds: number, speed: number, yawRate: number, label: string)
	for i = 1, #stepLen do stepLen[i], stepCnt[i] = 0, 0 end
	local t = 0
	while t < seconds do
		t += dt
		local before = {}
		for i, l in legs do before[i] = { foot = l.foot, planted = l.planted, from = l.from } end
		yaw += yawRate * dt
		local fwd = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		pos += fwd * speed * dt
		local homes, landing = {}, {}
		for i in legs do
			homes[i] = world(pos, yaw, offs[i])
			local dur = DragonGait.stepDuration(lens[i], speed)
			-- dove sara' la casa a meta' del prossimo appoggio (anticipo)
			landing[i] = world(pos + fwd * speed * dur * 1.0, yaw + yawRate * dur * 1.0, offs[i])
		end
		DragonGait.update(legs, dt, { homes = homes, landing = landing, speed = speed, up = UP })
		local sw, sides = 0, {}
		for i, l in legs do
			if before[i].planted and l.planted then
				slide = math.max(slide, (l.foot - before[i].foot).Magnitude)
			end
			if before[i].planted == false and l.planted then
				stepLen[i] += (l.foot - before[i].from).Magnitude
				stepCnt[i] += 1
			end
			if not l.planted then
				sw += 1
				if sides[l.side] then sameSide += 1 end
				sides[l.side] = true
			end
			maxReach = math.max(maxReach, (Vector3.new(l.foot.X, 0, l.foot.Z) - homes[i]).Magnitude / lens[i])
		end
		maxSwing = math.max(maxSwing, sw)
	end
	local s = {}
	for i, l in legs do
		table.insert(s, string.format("%s%s %d passi %.2f", if l.front then "A" else "P", if l.side > 0 then "dx" else "sx", stepCnt[i], if stepCnt[i] > 0 then stepLen[i] / stepCnt[i] else 0))
	end
	print(string.format("%-28s %s", label, table.concat(s, " | ")))
end
run(4, 6, 0, "dritto 6 stud/s")
run(4, 12, 0, "dritto 12 stud/s")
run(6, 6, 0.8, "curva a sinistra 6 stud/s")
local outer, inner = 0, 0
for i, l in legs do
	local avg = if stepCnt[i] > 0 then stepLen[i] / stepCnt[i] else 0
	if l.side > 0 then outer += avg else inner += avg end
end
check(outer > inner * 1.15, string.format("in curva a sinistra i passi a destra (esterni) devono essere piu' lunghi: %.2f contro %.2f", outer, inner))
run(3, 0, 1.2, "gira sul posto")
run(3, 0, 0, "fermo")
for i, l in legs do
	check(l.planted, "zampa " .. i .. " ancora in aria da ferma")
	check((Vector3.new(l.foot.X, 0, l.foot.Z) - world(pos, yaw, offs[i])).Magnitude < lens[i] * 0.5, "zampa " .. i .. " lontana dalla casa da fermo")
end
print(string.format("max zampe in aria %d, stesso lato %d volte, piede scivolato %.4f, distanza max dalla casa %.2f zampe", maxSwing, sameSide, slide, maxReach))
check(maxSwing <= 2, "piu' di due zampe in aria")
check(sameSide == 0, "due zampe dello stesso lato in aria")
check(slide < 1e-9, "un piede appoggiato e' scivolato")
check(maxReach < 0.95, "un piede e' finito fuori portata")
-- FABRIK sulle zampe vere: arriva al bersaglio e non cambia la lunghezza delle ossa
for _, l in sk.legs do
	local pts = {}
	for k, b in l.chain do pts[k] = d.ossa[b].pos end
	local target = pts[#pts] + Vector3.new(0.3, 0.6, -0.4)
	local out = DragonGait.fabrik(pts, target)
	check((out[#out] - target).Magnitude < 0.01, "FABRIK non arriva al bersaglio")
	check((out[1] - pts[1]).Magnitude < 1e-6, "FABRIK ha spostato la radice")
	for k = 1, #pts - 1 do
		check(math.abs((out[k + 1] - out[k]).Magnitude - (pts[k + 1] - pts[k]).Magnitude) < 1e-4, "FABRIK ha cambiato una lunghezza")
	end
end
-- molla: arriva al bersaglio senza esplodere anche con dt grande
local s = { x = 0, v = 0 }
for _ = 1, 30 do DragonGait.spring(s, 1, 0.1, 12, 1) end
check(math.abs(s.x - 1) < 0.01, "molla non arriva")
print(if fallimenti == 0 then "TUTTO OK" else ("FALLIMENTI: " .. fallimenti))
