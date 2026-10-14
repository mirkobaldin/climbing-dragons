--@client
-- Il modello viene spostato DOPO il calcolo (ordine sfavorevole fra PetAnimator e KfsPlayer):
-- il modulo deve accorgersene e anticipare, se no i piedi scivolano di v*dt a ogni frame.
local fallimenti = 0
local d
for _, x in SCHELETRI do if x.nome == "Drago_Gelo" then d = x end end
local model = modelloFinto(d)
local sk = DragonSkeleton.analyze(d.ossa)
setGround(sk.ground, 0, 0)
DragonProcedural.attach(model)
DragonProcedural.setAir(model, 0)
local dt = 1 / 60
local pos = Vector3.zero
local speed = 0
local prev = {}
local slide = { prima = 0, dopo = 0 }
for f = 1, 600 do
	speed += (6 - speed) * math.min(1, dt * 4)
	for _, b in model.bones do b.Transform = CFrame.identity end
	runPost(model, dt) -- prima il calcolo (col perno vecchio)...
	pos += Vector3.new(0, 0, -speed * dt)
	model:PivotTo(CFrame.new(pos)) -- ...poi lo spostamento
	stepHeartbeat()
	for i, l in sk.legs do
		local foot = mondoOsso(model, model.bones[l.chain[#l.chain]]).Position
		local st = DragonProcedural._debugLeg(model, i)
		if prev[i] and prev[i].planted and st.planted then
			local key = if f < 30 then "prima" else "dopo"
			slide[key] = math.max(slide[key], (foot - prev[i].foot).Magnitude)
		end
		prev[i] = { foot = foot, planted = st.planted }
	end
end
print(string.format("scivolamento per frame: primi 30 frame %.4f, poi %.4f (v*dt = %.4f)", slide.prima, slide.dopo, 6 * dt))
if slide.dopo > 6 * dt * 0.25 then
	fallimenti += 1
	print("  ERRORE: con l'ordine sfavorevole i piedi scivolano ancora")
end
print(if fallimenti == 0 then "TUTTO OK" else ("FALLIMENTI: " .. fallimenti))
