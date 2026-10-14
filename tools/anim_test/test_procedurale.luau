--@client
-- client/DragonProcedural con le ossa vere su un terreno finto e una camminata finta come quella
-- di MapGen.AnimDraghi (coscia avanti/indietro, ginocchio che si piega in volo, 62% appoggio).
-- Controlli: nessun NaN; piede bloccato che non scivola; piede in appoggio sul terreno (ne' sotto
-- ne' in punta di piedi); zampa mai tesa oltre la sua lunghezza; ginocchio che piega dalla parte
-- dell'animazione; piede orientato come nell'animazione (in piano niente dita storte); muso in
-- giu' sul pendio in discesa.
local fallimenti = 0
local function check(cond: boolean, msg: string)
	if not cond then
		fallimenti += 1
		print("  ERRORE: " .. msg)
	end
end
local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end
local function angleOf(a, b) -- angolo fra due CFrame (rotazioni)
	local _, ang = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	return ang
end
for _, nome in (NOMI or { "Drago_Gelo", "Drago_Eclissi_Adulto", "Drago_Roccia", "Drago_FulmineNero" }) do
	local d
	for _, x in SCHELETRI do if x.nome == nome then d = x end end
	local model = modelloFinto(d)
	local sk = DragonSkeleton.analyze(d.ossa)
	setGround(sk.ground, 0)
	check(DragonProcedural.attach(model), nome .. ": attach fallito")
	print(DragonProcedural.info(model))
	DragonProcedural.setAir(model, 0)
	local size = sk.length
	local dt = 1 / 60
	local pos, yaw = Vector3.zero, 0
	local SLOPE, Z0 = 0, 0
	local phases = { 0, 0.5, 0.25, 0.75 }
	local stats = {}
	local function reset() stats = { slide = 0, under = 0, tiptoe = 0, stretch = 0, knee = 0, twist = 0, nan = false } end
	reset()
	local prevLock = {}
	local walkT = 0
	local frames = 0
	local function frame(speed: number, yawRate: number)
		yaw += yawRate * dt
		local fwd = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		pos += fwd * speed * dt
		model:PivotTo(CFrame.new(pos.X, SLOPE * math.min(0, pos.Z - Z0), pos.Z) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), yaw))
		workspace.CurrentCamera.CFrame = CFrame.new(pos.X, 10, pos.Z + 30) -- la camera segue il drago
		-- camminata finta: passo lungo ~0.55 * lunghezza del drago a ciclo, come PetAnimator
		walkT += dt * (if speed > 0.01 then math.clamp(speed / (size * 0.55), 0.6, 2.2) else 0)
		for _, b in model.bones do b.Transform = CFrame.identity end
		local anim = {}
		for i, l in sk.legs do
			local ph = (walkT + phases[((i - 1) % 4) + 1]) % 1
			local swing, lift
			if ph < 0.62 then swing, lift = 1 - 2 * ph / 0.62, 0
			else local x = (ph - 0.62) / 0.38; swing, lift = -1 + 2 * x * x * (3 - 2 * x), math.sin(math.pi * x) end
			if speed < 0.01 then swing, lift = 0, 0 end
			local right = sk.right
			model.bones[l.chain[1]].Transform = CFrame.fromAxisAngle(right, math.rad(-28 * swing))
			if l.chain[2] then model.bones[l.chain[2]].Transform = CFrame.fromAxisAngle(right, math.rad((if l.front then -55 else 55) * lift)) end
			if l.chain[3] then model.bones[l.chain[3]].Transform = CFrame.fromAxisAngle(right, math.rad((if l.front then 30 else -30) * lift)) end
		end
		-- posa dell'animazione nel mondo (prima del procedurale): piede e ginocchio
		for i, l in sk.legs do
			local n = #l.chain
			local A = mondoOsso(model, model.bones[l.chain[1]]).Position
			local C = mondoOsso(model, model.bones[l.chain[n]])
			local kb, best = 2, -1
			for k = 2, n - 1 do
				local q = mondoOsso(model, model.bones[l.chain[k]]).Position - A
				local u = (C.Position - A).Unit
				local dd = (q - u * q:Dot(u)).Magnitude
				if dd > best then best, kb = dd, k end
			end
			local B = mondoOsso(model, model.bones[l.chain[kb]]).Position
			anim[i] = { foot = C, kneeN = (A - B):Cross(C.Position - B), kb = kb }
		end
		runPost(model, dt)
		stepHeartbeat()
		frames += 1
		for i, l in sk.legs do
			local n = #l.chain
			local footCF = mondoOsso(model, model.bones[l.chain[n]])
			local foot = footCF.Position
			if not finite(foot) then stats.nan = true end
			local st = DragonProcedural._debugLeg(model, i)
			local L = st.len
			-- terreno sotto il piede piu' l'altezza a riposo di quel piede (alcuni piedi stanno sopra le dita)
			local h0 = d.ossa[l.chain[n]].pos.Y - sk.ground
			local gy = sk.ground + h0 + SLOPE * math.min(0, foot.Z - Z0)
			if st.lock and DEBUG and i == 1 then print(string.format("f%d lock %.3f %.3f %.3f foot %.3f %.3f %.3f", frames, st.lock.X, st.lock.Y, st.lock.Z, foot.X, foot.Y, foot.Z)) end
			if st.lock then
				if prevLock[i] then stats.slide = math.max(stats.slide, (Vector3.new(foot.X, 0, foot.Z) - Vector3.new(prevLock[i].X, 0, prevLock[i].Z)).Magnitude / L) end
				prevLock[i] = foot
				stats.tiptoe = math.max(stats.tiptoe, (foot.Y - gy) / L)
			else
				prevLock[i] = nil
			end
			stats.under = math.max(stats.under, (gy - foot.Y) / L)
			local A = mondoOsso(model, model.bones[l.chain[1]]).Position
			stats.stretch = math.max(stats.stretch, (foot - A).Magnitude / L)
			local B = mondoOsso(model, model.bones[l.chain[anim[i].kb]]).Position
			local kn = (A - B):Cross(foot - B)
			if kn.Magnitude > 1e-4 and anim[i].kneeN.Magnitude > 1e-4 and kn:Dot(anim[i].kneeN) < 0 then stats.knee += 1 end
			if SLOPE == 0 then stats.twist = math.max(stats.twist, math.deg(angleOf(footCF, anim[i].foot))) end
		end
	end
	local righe = {}
	local function fase(nomeF, nFrames, speed, yr)
		reset()
		for _ = 1, nFrames do frame(speed, yr) end
		table.insert(righe, string.format("%s: scivola %.3f, sotto %.3f, alto %.3f, tesa %.2f, ginocchia al contrario %d, dita %.1f gradi",
			nomeF, stats.slide, stats.under, stats.tiptoe, stats.stretch, stats.knee, stats.twist))
		check(not stats.nan, nome .. " " .. nomeF .. ": numeri non validi")
		check(stats.slide < 0.025, nome .. " " .. nomeF .. ": il piede appoggiato scivola")
		check(stats.under < 0.05, nome .. " " .. nomeF .. ": il piede entra nel terreno")
		check(stats.tiptoe < 0.04, nome .. " " .. nomeF .. ": in appoggio il piede non tocca terra (punta di piedi)")
		check(stats.stretch < 1.0, nome .. " " .. nomeF .. ": zampa tesa oltre la lunghezza")
		check(stats.knee == 0, nome .. " " .. nomeF .. ": ginocchio piegato al contrario")
		check(stats.twist < 3, nome .. " " .. nomeF .. ": piede ruotato rispetto all'animazione in piano")
	end
	fase("fermo", 90, 0, 0)
	fase("cammina", 300, size * 0.35, 0)
	fase("corre", 200, size * 0.9, 0)
	fase("curva", 240, size * 0.35, 0.7)
	fase("gira sul posto", 120, 0, 1.0)
	yaw = 0
	Z0 = pos.Z - size * 0.6
	SLOPE = 0.25
	setGround(sk.ground, 0.25, Z0)
	fase("pendio", 300, size * 0.3, 0)
	fase("fermo sul pendio", 120, 0, 0)
	for _, rr in righe do print("  " .. rr) end
	local lean = DragonProcedural.riderLean(model)
	check(lean.Y < -0.12, string.format("%s: beccheggio %.3f sul pendio in discesa (atteso circa -0.24)", nome, lean.Y))
	DragonProcedural.detach(model)
end
print(if fallimenti == 0 then "TUTTO OK" else ("FALLIMENTI: " .. fallimenti))
