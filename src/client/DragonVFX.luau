--!strict
-- Effetti degli attacchi dei draghi, diversi per ogni elemento (tutto locale). Base fatta con
-- gli strumenti di Roblox (ParticleEmitter, Trail, PointLight, TweenService) piu' gli effetti
-- flipbook e le mesh della libreria VFXLib (VFXKit) e un suono per la partenza e per l'impatto:
--   Brace, Eclissi, Sole  palla di fuoco (mesh) con fiamme, esplosione di fuoco, crepa a terra
--   Gelo                  scheggia di ghiaccio, scoppio di ghiaccio magico, spuntoni di ghiaccio
--   Tempesta, Fulmine     fulmine a zig-zag, saetta dal cielo sul bersaglio, scariche
--   Gas                   sfera tossica, nube e bolle che restano, vortice a terra
--   Roccia                masso con polvere, crepa, spuntoni di pietra
--   Ossa                  lancia d'osso con scia verde, fendente spettrale
--   Cosmico, Ombra        stella (sfera glitch) con scintille, vortice ed esplosione stellare
-- DragonVFX.shot(elemento, da, a, colore) disegna il colpo e l'impatto; la camera trema un poco.
-- DragonVFX.mouth(modello, verso) trova la punta del muso dallo scheletro.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)
local VFXKit = require(script.Parent.VFXKit)
local MeshFX = require(script.Parent.MeshFX)

local DragonVFX = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

DragonVFX.shake = 0 -- letto da chi muove la camera (TrainingFX)

local function fx(shape: Enum.PartType, size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.CFrame = cf
	p.Parent = workspace
	return p
end

local function emitter(parent: Instance, texture: string, color: ColorSequence, size: NumberSequence, life: number, speed: number, rate: number, spread: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = color
	e.Size = size
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Rate = rate
	e.SpreadAngle = Vector2.new(spread or 180, spread or 180)
	e.LightEmission = 0.9
	e.Transparency = NumberSequence.new(0.1, 1)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number, fade: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if fade then
		TweenService:Create(l, TweenInfo.new(fade), { Brightness = 0 }):Play()
	end
end

local function trail(p: BasePart, color: Color3, width: number, life: number)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
	a0.Parent, a1.Parent = p, p
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	t.LightEmission = 1
	t.Lifetime = life
	t.Transparency = NumberSequence.new(0, 1)
	t.WidthScale = NumberSequence.new(1, 0)
	t.FaceCamera = true
	t.Parent = p
end

-- texture di esplosione incluse in Roblox
local CORE = "rbxasset://textures/particles/explosion01_core_main.dds"
local WAVE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local EXSMOKE = "rbxasset://textures/particles/explosion01_smoke_main.dds"
local FSPARK = "rbxasset://textures/particles/fire_sparks_main.dds"
local GLOW = "rbxasset://textures/particles/forcefield_glow_main.dds"

-- anello d'urto: a terra se il bersaglio e' vicino al terreno, se no di fronte al colpo
local function ring(at: Vector3, dir: Vector3, color: Color3, size: number)
	local ground = VFXKit.ground(at, 6)
	local cf = ground or (CFrame.lookAt(at, at + dir) * CFrame.Angles(math.pi / 2, 0, 0))
	VFXKit.mesh("Shock", cf, { color = color, from = size * 1.5, to = size * 11, time = 0.5, spin = 0.25, flat = true, transparency = 0.15 })
	return ground
end

-- (lampo e nucleo piccoli: sopra devono vedersi le mesh VFX dell'elemento)
-- esplosione a strati: lampo bianco al centro, nucleo colorato, onda d'urto piatta, scintille
-- che cadono, fumo, luce che si spegne
local function impact(at: Vector3, color: Color3, size: number, texture: string?, extra: ((Part) -> ())?)
	local holder = fx(Enum.PartType.Block, Vector3.one * 0.2, color, CFrame.new(at))
	holder.Transparency = 1
	local flashE = emitter(holder, GLOW, ColorSequence.new(Color3.new(1, 1, 1)), NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 1.6), NumberSequenceKeypoint.new(1, size * 5) }), 0.14, 0, 0)
	flashE.LightEmission = 1
	flashE:Emit(2)
	local core = emitter(holder, CORE, ColorSequence.new(Color3.new(1, 1, 1), color), NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 1.4), NumberSequenceKeypoint.new(1, size * 4.5) }), 0.35, 1, 0)
	core.LightEmission = 0.8
	core:Emit(2)
	local wave = emitter(holder, WAVE, ColorSequence.new(color), NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 2), NumberSequenceKeypoint.new(1, size * 14) }), 0.4, 0, 0)
	wave.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	wave.EmissionDirection = Enum.NormalId.Top
	wave.Speed = NumberRange.new(0.01)
	wave.LightEmission = 1
	wave:Emit(1)
	local sp = emitter(holder, texture or FSPARK, ColorSequence.new(Color3.new(1, 1, 1), color), NumberSequence.new(size * 0.6, 0), 0.9, size * 22, 0)
	sp.Drag = 3
	sp.Acceleration = Vector3.new(0, -40, 0)
	sp:Emit(45)
	local sm = emitter(holder, EXSMOKE, ColorSequence.new(color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.5)), NumberSequence.new(size * 2, size * 6), 1.4, size * 3, 0)
	sm.LightEmission = 0.1
	sm:Emit(8)
	light(holder, color, 22 + size * 8, 8, 0.7)
	if extra then
		extra(holder)
	end
	Debris:AddItem(holder, 2.5)
	DragonVFX.shake = math.max(DragonVFX.shake, 0.45)
end

-- un proiettile che vola da from a to (parte gia' costruita), poi l'impatto
local function fly(p: BasePart, from: Vector3, to: Vector3, speed: number, spin: boolean, onHit: () -> ())
	local dist = (to - from).Magnitude
	local time = math.clamp(dist / speed, 0.1, 0.7)
	p.CFrame = CFrame.lookAt(from, to)
	local goal = CFrame.lookAt(to, to + (to - from).Unit) * (if spin then CFrame.Angles(0, 0, math.pi * 6) else CFrame.identity)
	local tw = TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = goal })
	tw:Play()
	tw.Completed:Connect(function()
		p:Destroy()
		onHit()
	end)
	Debris:AddItem(p, time + 1)
end

-- mesh della libreria che segue un proiettile (palla di fuoco, sfera glitch): gira su se stessa
local function rider(name: string, p: BasePart, color: Color3, size: number)
	local m = VFXKit.part(name, size)
	if not m then
		return
	end
	-- le mesh con la palette (VFX_37..66) restano bianche, se no la tinta la sporca
	m.Color = if m.TextureID ~= "" then Color3.new(1, 1, 1) else color
	m.CFrame = p.CFrame
	m.Parent = workspace
	Debris:AddItem(m, 2)
	-- il proiettile si muove a tween: la mesh lo segue ogni frame girando su se stessa
	local spinAt = os.clock()
	task.spawn(function()
		while m.Parent and p.Parent do
			m.CFrame = p.CFrame * CFrame.Angles(0, 0, (os.clock() - spinAt) * 9)
			task.wait()
		end
		m:Destroy()
	end)
end

-- fulmine a zig-zag tra due punti (segmenti al neon che spariscono subito)
local function bolt(from: Vector3, to: Vector3, color: Color3, width: number)
	local n = 8
	local prev = from
	local dir = to - from
	local side = dir:Cross(Vector3.yAxis)
	side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
	local up = side:Cross(dir).Unit
	for k = 1, n do
		local f = k / n
		local jitter = if k == n then Vector3.zero else (side * (math.random() - 0.5) + up * (math.random() - 0.5)) * dir.Magnitude * 0.08
		local p = from + dir * f + jitter
		local seg = fx(Enum.PartType.Block, Vector3.new(width, width, (p - prev).Magnitude), color, CFrame.lookAt((p + prev) / 2, p))
		seg.Transparency = 0
		TweenService:Create(seg, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, seg.Size.Z) }):Play()
		Debris:AddItem(seg, 0.3)
		prev = p
	end
end

function DragonVFX.muzzle(at: Vector3, color: Color3)
	-- bagliore alla bocca: alone che si allarga + scintille in avanti
	local f = fx(Enum.PartType.Block, Vector3.one * 0.2, color, CFrame.new(at))
	f.Transparency = 1
	local g = emitter(f, GLOW, ColorSequence.new(Color3.new(1, 1, 1), color), NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) }), 0.2, 0, 0)
	g.LightEmission = 1
	g:Emit(2)
	local s = emitter(f, FSPARK, ColorSequence.new(color), NumberSequence.new(0.5, 0), 0.35, 25, 0)
	s:Emit(14)
	light(f, color, 18, 6, 0.2)
	Debris:AddItem(f, 0.6)
	VFXKit.burst("Scintille", at, { color = color, count = 6, scale = 0.6 })
end

------------------------------------------------------------------------------------------
-- la bocca: la punta del muso trovata dallo scheletro. L'attributo HeadBone dei modelli in
-- alcuni draghi (Gas, Eclissi adulto) e' un osso della cresta o del corno, dietro e sopra il
-- muso: si cerca invece l'osso piu' avanti sulla linea di mezzo del corpo e si allunga fino alla
-- fine della mesh. Il punto e' salvato rispetto all'osso, cosi' segue il collo che si muove.

type Mouth = { bone: Bone, offset: Vector3 }
local mouths: { [Model]: Mouth } = setmetatable({}, { __mode = "k" }) :: any

local function findMouth(model: Model): Mouth?
	local piv = model:GetPivot()
	-- ingombro della mesh nello spazio del pivot (gli angoli di ogni parte)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local h = p.Size / 2
			for _, c in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local q = piv:PointToObjectSpace(p.CFrame:PointToWorldSpace(h * c))
				lo, hi = lo:Min(q), hi:Max(q)
			end
		end
	end
	if lo.X == math.huge then
		return nil
	end
	local width, depth = hi.X - lo.X, hi.Z - lo.Z
	-- da che parte guarda: di norma -Z; se l'osso HeadBone sta dietro, +Z
	local sign = -1
	local hb = model:GetAttribute("HeadBone")
	local hbone = if type(hb) == "string" then model:FindFirstChild(hb, true) else nil
	if hbone and hbone:IsA("Bone") and piv:PointToObjectSpace(hbone.WorldPosition).Z > depth * 0.15 then
		sign = 1
	end
	local best: Bone? = nil
	local bestZ = -math.huge
	local bestLocal = Vector3.zero
	for _, b in model:GetDescendants() do
		if b:IsA("Bone") then
			local q = piv:PointToObjectSpace(b.WorldPosition)
			-- sulla linea di mezzo (fuori restano zampe e ali) e la piu' avanti
			if math.abs(q.X - (lo.X + hi.X) / 2) < width * 0.12 and q.Z * sign > bestZ then
				best, bestZ, bestLocal = b, q.Z * sign, q
			end
		end
	end
	if not best then
		return nil
	end
	local front = if sign < 0 then lo.Z else hi.Z
	local gap = math.clamp((front - bestLocal.Z) * sign, 0, depth * 0.12)
	local tip = piv:PointToWorldSpace(bestLocal + Vector3.new(0, -depth * 0.01, gap * sign))
	return { bone = best, offset = best.TransformedWorldCFrame:PointToObjectSpace(tip) }
end

-- bocca del drago (punta del muso), spostata un po' verso il bersaglio
function DragonVFX.mouth(model: Model, toward: Vector3?): Vector3
	local _, size = model:GetBoundingBox()
	local p: Vector3? = nil
	local m = mouths[model]
	if not m or not m.bone:IsDescendantOf(model) then
		m = findMouth(model) :: any
		if m then
			mouths[model] = m
		end
	end
	if m then
		p = m.bone.TransformedWorldCFrame:PointToWorldSpace(m.offset)
	else
		-- modelli a parti: la parte o l'osso chiamato "head"
		for _, n in { "head", "Head" } do
			local d = model:FindFirstChild(n, true)
			if d and d:IsA("Bone") then
				p = d.TransformedWorldCFrame.Position
				break
			elseif d and d:IsA("BasePart") then
				p = d.Position
				break
			end
		end
	end
	if not p then
		local cf = model:GetPivot()
		p = cf.Position + cf.LookVector * size.Z * 0.4 + Vector3.new(0, size.Y * 0.25, 0)
	end
	local at = p :: Vector3
	if toward and (toward - at).Magnitude > 1 then
		at += (toward - at).Unit * math.max(size.X, size.Y, size.Z) * 0.02
	end
	return at
end

------------------------------------------------------------------------------------------

local FIRE_LIKE = { Brace = true, Sole = true, Eclissi = true }

local CAST: { [string]: string } = {
	Gelo = "SoffioGelo",
	Gas = "SoffioGas",
	Roccia = "SoffioVento",
	Ossa = "SoffioVento",
	Cosmico = "SoffioVento",
	Ombra = "SoffioOmbra",
}

-- durata del volo di un proiettile (uguale a fly)
local function travel(from: Vector3, to: Vector3, speed: number): number
	return math.clamp((to - from).Magnitude / speed, 0.1, 0.7)
end

-- il proiettile prende la forma della mesh dell'elemento (MeshFX): la parte resta invisibile
-- e regge scia, particelle e luce
local function shape(element: string, p: BasePart, from: Vector3, to: Vector3, speed: number)
	p.CFrame = CFrame.lookAt(from, to)
	if MeshFX.rider(element, p, travel(from, to, speed)) then
		p.Transparency = 1
	end
end

function DragonVFX.shot(element: string?, from: Vector3, to: Vector3, color: Color3)
	DragonVFX.muzzle(from, color)
	local e = element or ""
	local dir = if (to - from).Magnitude > 0.01 then (to - from).Unit else Vector3.zAxis
	MeshFX.charge(element, from, dir)
	if e ~= "Fulmine" then
		Sfx.play(CAST[e] or "SoffioFuoco", from)
	end
	if e == "Fulmine" then
		-- fulmine istantaneo: due rami, la lancia ramificata (mesh) tesa tra bocca e bersaglio,
		-- una saetta dal cielo e un lampo
		bolt(from, to, color, 0.7)
		bolt(from, to, Color3.fromRGB(40, 20, 70), 0.25)
		bolt(to + Vector3.new((math.random() - 0.5) * 6, 40, (math.random() - 0.5) * 6), to, Color3.new(1, 1, 1), 0.45)
		Sfx.play("Fulmine", to)
		local len = (to - from).Magnitude
		VFXKit.play("VFX_57_FulmineLanciaRamificata", CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.random() * 6, 0, 0), { from = len * 0.9, to = len, time = 0.28, fadeIn = 0.02, hold = 0.3, ease = "linear", light = 20, color = color })
		VFXKit.mesh("ThunderSpark", CFrame.new(to) * CFrame.Angles(0, math.random() * 6, 0), { color = color, from = 3, to = 9, time = 0.3 })
		VFXKit.burst("Fulmine", to, { color = color, scale = 0.9 })
		if not MeshFX.impact(e, to, dir) then
			ring(to, dir, color, 1)
		end
		impact(to, color, 1.1, SPARK)
		return
	end
	if e == "Tempesta" then
		-- occhio d'uragano che vola girando, poi ali di vento e rasoi a terra
		local core = fx(Enum.PartType.Ball, Vector3.one * 1.6, Color3.new(1, 1, 1), CFrame.new(from))
		core.Transparency = 0.3
		trail(core, color, 2.4, 0.3)
		VFXKit.attach("Vortice", core, { color = color, rate = 20, scale = 0.5 })
		light(core, color, 12, 2)
		shape(e, core, from, to, 170)
		fly(core, from, to, 170, false, function()
			Sfx.play("Fulmine", to, 0.6)
			VFXKit.burst("Vortice", to, { color = color, scale = 1 })
			bolt(to + Vector3.new((math.random() - 0.5) * 6, 40, (math.random() - 0.5) * 6), to, Color3.new(1, 1, 1), 0.35)
			MeshFX.impact(e, to, dir)
			impact(to, color, 1.1, SPARK)
		end)
		return
	end
	if e == "Gelo" then
		local shard = fx(Enum.PartType.Block, Vector3.new(0.9, 0.9, 3.4), color, CFrame.new(from), Enum.Material.Glass)
		shard.Transparency = 0.15
		trail(shard, color, 1, 0.25)
		emitter(shard, SPARK, ColorSequence.new(Color3.new(1, 1, 1)), NumberSequence.new(0.4, 0), 0.4, 2, 40)
		VFXKit.attach("Scintille", shard, { color = color, rate = 40, scale = 0.7 })
		light(shard, color, 10, 2)
		shape(e, shard, from, to, 160)
		fly(shard, from, to, 160, false, function()
			Sfx.play("Ghiaccio", to)
			VFXKit.burst("Ghiaccio", to, { count = 3, scale = 1.3 })
			-- sigillo a terra, loto di cristalli che si apre e ala tagliente (mesh); senza le mesh
			-- restano gli spuntoni di prima
			if not MeshFX.impact(e, to, dir) then
				local ground = ring(to, dir, color, 1)
				local base = ground or CFrame.new(to)
				VFXKit.mesh("GroundSpikes", base * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.random() * 6, 0), { color = Color3.fromRGB(190, 235, 255), from = 1, to = 7, time = 0.9, material = Enum.Material.Glass, transparency = 0.25 })
			end
			impact(to, color, 1, SPARK, function(h)
				for _ = 1, 8 do
					local c = fx(Enum.PartType.Block, Vector3.new(0.5, math.random() * 2 + 1, 0.5), color, CFrame.new(to) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Enum.Material.Glass)
					c.Transparency = 0.2
					local d = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
					TweenService:Create(c, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = c.CFrame + d * 6, Transparency = 1 }):Play()
					Debris:AddItem(c, 0.7)
				end
				local _ = h
			end)
		end)
		return
	end
	if e == "Gas" then
		local magenta = Color3.fromRGB(240, 80, 220)
		local orb = fx(Enum.PartType.Ball, Vector3.one * 2.2, color, CFrame.new(from))
		orb.Transparency = 0.25
		emitter(orb, SMOKE, ColorSequence.new(color, magenta), NumberSequence.new(1, 3), 0.8, 1, 40)
		VFXKit.attach("Nebbia", orb, { color = magenta, rate = 12, scale = 0.35 })
		light(orb, color, 12, 2)
		shape(e, orb, from, to, 90)
		fly(orb, from, to, 90, false, function()
			Sfx.play("ScoppioFuoco", to, 0.7)
			VFXKit.burst("Fumo", to, { color = color, scale = 1.2 })
			VFXKit.burst("Bolle", to + Vector3.new(0, 1, 0), { color = magenta, count = 4, scale = 1.5 })
			if not MeshFX.impact(e, to, dir) then
				local ground = VFXKit.ground(to, 6)
				VFXKit.mesh("Swirl", (ground or CFrame.new(to)) * CFrame.new(0, 0.3, 0), { color = magenta, from = 3, to = 12, time = 1.2, spin = 1, transparency = 0.3 })
			end
			impact(to, color, 1.3, SMOKE, function(h)
				-- nube che resta, con qualche bolla che scoppia
				local cloud = emitter(h, SMOKE, ColorSequence.new(color, magenta), NumberSequence.new(3, 6), 2, 1.5, 25)
				cloud.LightEmission = 0.4
				local bubbles = VFXKit.attach("Bolle", h, { color = color, rate = 5, scale = 1.2 })
				task.delay(1.2, function()
					cloud.Enabled = false
					if bubbles then
						bubbles:Destroy()
					end
				end)
			end)
		end)
		return
	end
	if e == "Roccia" then
		local rock = fx(Enum.PartType.Ball, Vector3.new(2.2, 1.8, 2), Color3.fromRGB(130, 110, 90), CFrame.new(from), Enum.Material.Slate)
		emitter(rock, SMOKE, ColorSequence.new(Color3.fromRGB(200, 170, 120)), NumberSequence.new(0.8, 2), 0.6, 1, 30)
		shape(e, rock, from, to, 110)
		fly(rock, from, to, 110, false, function()
			Sfx.play("Roccia", to)
			Sfx.play("Esplosione", to, 0.6)
			-- faglia radiale a terra e artigli di pietra che si chiudono (mesh)
			if MeshFX.impact(e, to, dir) then
				local ground = VFXKit.ground(to, 6)
				if ground then
					VFXKit.burst("Crepa", ground, { color = color, scale = 1 })
				end
			else
				local ground = ring(to, dir, color, 1.1)
				if ground then
					VFXKit.burst("Crepa", ground, { color = color, scale = 1 })
					VFXKit.mesh("Spike", ground * CFrame.Angles(0, math.random() * 6, 0), { color = Color3.fromRGB(150, 125, 95), from = 1, to = 6, time = 0.9, material = Enum.Material.Slate, transparency = 0 })
				end
			end
			VFXKit.burst("Fumo", to, { color = Color3.fromRGB(210, 180, 130), scale = 1.1 })
			impact(to, color, 1.2, SMOKE, function()
				for _ = 1, 7 do
					local c = fx(Enum.PartType.Block, Vector3.one * (0.5 + math.random()), Color3.fromRGB(120, 100, 82), CFrame.new(to) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Enum.Material.Slate)
					local d = Vector3.new(math.random() - 0.5, math.random() * 0.9 + 0.3, math.random() - 0.5).Unit
					TweenService:Create(c, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = c.CFrame + d * 8 - Vector3.new(0, 3, 0), Transparency = 1 }):Play()
					Debris:AddItem(c, 0.8)
				end
			end)
		end)
		return
	end
	if e == "Ossa" then
		local spear = fx(Enum.PartType.Cylinder, Vector3.new(4, 0.6, 0.6), Color3.fromRGB(235, 230, 215), CFrame.new(from), Enum.Material.Limestone)
		trail(spear, color, 0.8, 0.35)
		emitter(spear, SMOKE, ColorSequence.new(color), NumberSequence.new(0.6, 1.6), 0.5, 1, 30)
		light(spear, color, 10, 2)
		-- il cilindro e' lungo sull'asse X: si gira di 90 gradi rispetto alla direzione
		spear.CFrame = CFrame.lookAt(from, from + dir) * CFrame.Angles(0, math.pi / 2, 0)
		local time = math.clamp((to - from).Magnitude / 140, 0.1, 0.6)
		-- spina dorsale (mesh) che segue la lancia: il cilindro diventa invisibile
		local holder = fx(Enum.PartType.Block, Vector3.one * 0.2, color, CFrame.lookAt(from, to))
		holder.Transparency = 1
		if MeshFX.rider(e, holder, time) then
			spear.Transparency = 1
			TweenService:Create(holder, TweenInfo.new(time), { CFrame = CFrame.lookAt(to, to + dir) }):Play()
		end
		Debris:AddItem(holder, time + 0.2)
		local tw = TweenService:Create(spear, TweenInfo.new(time), { CFrame = CFrame.lookAt(to, to + dir) * CFrame.Angles(0, math.pi / 2, 0) })
		tw:Play()
		tw.Completed:Connect(function()
			spear:Destroy()
			Sfx.play("Ossa", to)
			VFXKit.burst("Taglio", to, { color = color, scale = 0.9 })
			VFXKit.burst("Fumo", to, { color = color, scale = 0.8 })
			-- fauci che si chiudono sul bersaglio, arcate a terra, artiglio scheletrico
			if not MeshFX.impact(e, to, dir) then
				ring(to, dir, color, 0.9)
			end
			impact(to, color, 1, SMOKE)
		end)
		return
	end
	if e == "Cosmico" or e == "Ombra" then
		local shadow = e == "Ombra"
		local star = fx(Enum.PartType.Ball, Vector3.one * 1.6, if shadow then Color3.fromRGB(30, 10, 50) else Color3.new(1, 1, 1), CFrame.new(from))
		trail(star, color, 1.4, 0.4)
		emitter(star, SPARK, ColorSequence.new(color, Color3.new(1, 1, 1)), NumberSequence.new(0.6, 0), 0.6, 3, 60)
		local shaped = MeshFX.rider(e, star, travel(from, to, 120))
		if shaped then
			star.Transparency = 1
		else
			rider("GlitchBall", star, color, 3)
		end
		light(star, color, 12, 3)
		fly(star, from, to, 120, false, function()
			Sfx.play(if shadow then "Esplosione" else "Stelle", to)
			VFXKit.burst("Vortice", to, { color = color, scale = 1.1 })
			VFXKit.burst("Scintille", to, { color = color, count = 25 })
			if shadow then
				VFXKit.burst("Taglio", to, { color = color, scale = 1 })
			else
				VFXKit.burst("Scoppio", to, { color = color, scale = 0.9 })
			end
			-- disco d'accrescimento a terra e stella dimensionale
			if not MeshFX.impact(e, to, dir) then
				ring(to, dir, color, 1.1)
			end
			impact(to, color, 1.4, SPARK)
		end)
		return
	end
	-- fuoco (Brace, Eclissi, Sole e tutti gli altri)
	local flame = if e == "Sole" then Color3.fromRGB(255, 230, 140) elseif e == "Eclissi" then color else Color3.fromRGB(255, 150, 60)
	local ball = fx(Enum.PartType.Ball, Vector3.one * 2.4, Color3.fromRGB(255, 240, 200), CFrame.new(from))
	ball.Transparency = 0
	trail(ball, color, 3.2, 0.4)
	local halo = emitter(ball, GLOW, ColorSequence.new(color), NumberSequence.new(5, 3), 0.15, 0, 60)
	halo.LightEmission = 1
	halo.LockedToPart = true
	emitter(ball, FIRE, ColorSequence.new(Color3.fromRGB(255, 230, 140), color), NumberSequence.new(2.6, 0.6), 0.4, 2, 90)
	VFXKit.attach("FuocoLoop", ball, { rate = 30, scale = 0.8 })
	-- Eclissi: il serpente solare (mesh) al posto della palla di fuoco
	if MeshFX.rider(e, ball, travel(from, to, 120)) then
		ball.Transparency = 1
	else
		rider("FireBall", ball, flame, 3.2)
	end
	light(ball, color, 14, 3)
	fly(ball, from, to, 120, false, function()
		Sfx.play("Esplosione", to)
		Sfx.play("ScoppioFuoco", to)
		VFXKit.burst("FuocoBurst", to + Vector3.new(0, 1, 0), { color = if FIRE_LIKE[e] and e ~= "Brace" then flame else nil, scale = 1.1 })
		VFXKit.burst("Scoppio", to, { color = flame, scale = 0.8 })
		-- nova oscura a terra e lama dell'apocalisse
		if not MeshFX.impact(e, to, dir) then
			local ground = ring(to, dir, color, 1.2)
			if ground then
				VFXKit.burst("Crepa", ground, { scale = 0.9 })
			end
		end
		impact(to, color, 1.3, FIRE)
	end)
end

return DragonVFX
