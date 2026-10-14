--@client
SLOPE = 0
Z0 = 0
-- client/DragonProcedural con le ossa vere su un terreno finto: il drago cammina dritto, gira,
-- sale un pendio e si ferma. I piedi appoggiati devono restare fermi nel mondo (dopo corpo e IK).
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
for _, nome in { "Drago_Gelo", "Drago_Eclissi_Adulto", "Drago_Roccia" } do
	local d
	for _, x in SCHELETRI do if x.nome == nome then d = x end end
	local model = modelloFinto(d)
	local sk = DragonSkeleton.analyze(d.ossa)
	setGround(sk.ground, 0)
	SLOPE = 0
	Z0 = 0
	check(DragonProcedural.attach(model), nome .. ": attach fallito")
	print(DragonProcedural.info(model))
	DragonProcedural.setAir(model, 0)
	local size = sk.length
	local dt = 1 / 60
	local pos, yaw = Vector3.zero, 0
	local slideMax, ikErr, nan = 0, 0, false
	local prevFeet = {}
	local frames = 0
	local curSpeed, curYaw = 0, 0
	local function frame(speedT: number, yawT: number)
		-- come PetAnimator: velocita' e virata cambiano in fretta ma non di colpo
		curSpeed += (speedT - curSpeed) * math.min(1, dt * 4)
		curYaw += (yawT - curYaw) * math.min(1, dt * 4)
		local speed, yawRate = curSpeed, curYaw
		yaw += yawRate * dt
		local fwd = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		pos += fwd * speed * dt
		-- come PetAnimator: il drago resta all'altezza del terreno sotto di lui
		model:PivotTo(CFrame.new(pos.X, SLOPE * math.min(0, pos.Z - Z0), pos.Z) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), yaw))
		for _, b in model.bones do b.Transform = CFrame.identity end -- "animazione": posa a riposo
		runPost(model, dt)
		stepHeartbeat()
		frames += 1
		-- piedi nel mondo
		for i, l in sk.legs do
			local foot = mondoOsso(model, model.bones[l.chain[#l.chain]]).Position
			if not finite(foot) then nan = true end
			local st = DragonProcedural._debugLeg(model, i)
			if st and st.planted and prevFeet[i] and prevFeet[i].planted then
				slideMax = math.max(slideMax, (foot - prevFeet[i].foot).Magnitude / size)
			end
			if st and st.planted then
				ikErr = math.max(ikErr, (foot - st.foot).Magnitude / size)
			end
			prevFeet[i] = { foot = foot, planted = st and st.planted }
		end
	end
	local fasi = {}
	local function fase(nomeF: string, n: number, speed: number, yr: number)
		slideMax, ikErr = 0, 0
		for _ = 1, n do frame(speed, yr) end
		table.insert(fasi, string.format("%s: scivola %.3f, IK %.3f", nomeF, slideMax, ikErr))
		allSlide = math.max(allSlide, slideMax)
		allIk = math.max(allIk, ikErr)
	end
	allSlide, allIk = 0, 0
	fase("fermo", 120, 0, 0)
	fase("dritto", 240, size * 0.4, 0)
	fase("curva", 240, size * 0.4, 0.7)
	fase("gira sul posto", 180, 0, 1.0)
	-- pendio in discesa che comincia un po' piu' avanti, nella direzione in cui guarda
	yaw = 0
	Z0 = pos.Z - size * 0.8
	setGround(sk.ground, 0.25, Z0)
	SLOPE = 0.25
	fase("pendio", 300, size * 0.3, 0)
	fase("fermo sul pendio", 120, 0, 0)
	print("  " .. table.concat(fasi, " | "))
	slideMax, ikErr = allSlide, allIk
	-- il pendio sale verso +z (y = ground + 0.25 z): muso in su se il drago guarda verso +z
	local lean = DragonProcedural.riderLean(model)
	local facing = model:GetPivot():VectorToWorldSpace(sk.fwd)
	local expectUp = facing.Z > 0
	print(string.format("  %d frame: scivolamento max %.4f, errore IK max %.4f (in lunghezze del drago), beccheggio sul pendio %.2f rad, sella %s",
		frames, slideMax, ikErr, lean.Y, tostring(DragonProcedural.seat(model) ~= nil)))
	check(not nan, nome .. ": numeri non validi")
	check(slideMax < 0.01, nome .. ": i piedi appoggiati scivolano")
	check(ikErr < 0.02, nome .. ": il piede non arriva dove deve")
	-- guarda verso -z e il pendio scende verso -z: muso in giu' di circa atan(0.25) = 0.245
	check(lean.Y < -0.15, string.format("%s: beccheggio %.3f sul pendio in discesa (atteso circa -0.24)", nome, lean.Y))
	DragonProcedural.detach(model)
end
print(if fallimenti == 0 then "TUTTO OK" else ("FALLIMENTI: " .. fallimenti))
