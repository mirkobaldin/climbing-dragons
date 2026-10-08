--!strict
-- Effetti degli attacchi dei draghi, diversi per ogni elemento (tutto locale, con gli strumenti di
-- Roblox: ParticleEmitter, Trail, Beam, PointLight, TweenService):
--   Brace, Eclissi, Sole  palla di fuoco con fiamme e scia, esplosione di fiamme
--   Gelo                  scheggia di ghiaccio che gira, scoppio di cristalli e brina
--   Tempesta, Fulmine     fulmine istantaneo a zig-zag, scintille e lampo
--   Gas                   sfera tossica con fumo, nube che resta qualche secondo
--   Roccia                masso con polvere, detriti che rimbalzano
--   Ossa                  lancia d'osso con scia verde spettrale, fuochi fatui
--   Cosmico, Ombra        stella con scia di scintille, esplosione stellare
-- DragonVFX.shot(elemento, da, a, colore) disegna il colpo e l'impatto; la camera trema un poco.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

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

-- esplosione generica: scintille, fumo, luce, onda
local function impact(at: Vector3, color: Color3, size: number, texture: string?, extra: ((Part) -> ())?)
	local holder = fx(Enum.PartType.Block, Vector3.one * 0.2, color, CFrame.new(at))
	holder.Transparency = 1
	local sp = emitter(holder, texture or SPARK, ColorSequence.new(color, Color3.new(1, 1, 1)), NumberSequence.new(size, 0), 0.7, size * 12, 0)
	sp.Drag = 4
	sp:Emit(40)
	local sm = emitter(holder, SMOKE, ColorSequence.new(color), NumberSequence.new(size * 1.5, size * 4), 1.1, size * 3, 0)
	sm.LightEmission = 0.2
	sm:Emit(12)
	light(holder, color, 18 + size * 6, 6, 0.6)
	local ring = fx(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), color, CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2))
	ring.Transparency = 0.1
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, size * 10, size * 10), Transparency = 1 }):Play()
	if extra then
		extra(holder)
	end
	Debris:AddItem(ring, 0.5)
	Debris:AddItem(holder, 2.5)
	DragonVFX.shake = math.max(DragonVFX.shake, 0.35)
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
	local f = fx(Enum.PartType.Ball, Vector3.one * 2.5, color, CFrame.new(at))
	f.Transparency = 0.2
	TweenService:Create(f, TweenInfo.new(0.18), { Size = Vector3.one * 5, Transparency = 1 }):Play()
	light(f, color, 16, 5, 0.18)
	Debris:AddItem(f, 0.25)
end

function DragonVFX.shot(element: string?, from: Vector3, to: Vector3, color: Color3)
	DragonVFX.muzzle(from, color)
	local e = element or ""
	if e == "Tempesta" or e == "Fulmine" then
		-- fulmine istantaneo: due rami e un lampo
		bolt(from, to, color, 0.7)
		bolt(from, to, Color3.new(1, 1, 1), 0.25)
		impact(to, color, 1.1, SPARK)
		return
	end
	if e == "Gelo" then
		local shard = fx(Enum.PartType.Block, Vector3.new(0.9, 0.9, 3.4), color, CFrame.new(from), Enum.Material.Glass)
		shard.Transparency = 0.15
		trail(shard, color, 1, 0.25)
		emitter(shard, SPARK, ColorSequence.new(Color3.new(1, 1, 1)), NumberSequence.new(0.4, 0), 0.4, 2, 40)
		light(shard, color, 10, 2)
		fly(shard, from, to, 160, true, function()
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
		local orb = fx(Enum.PartType.Ball, Vector3.one * 2.2, color, CFrame.new(from))
		orb.Transparency = 0.25
		emitter(orb, SMOKE, ColorSequence.new(color, Color3.fromRGB(240, 80, 220)), NumberSequence.new(1, 3), 0.8, 1, 40)
		light(orb, color, 12, 2)
		fly(orb, from, to, 90, false, function()
			impact(to, color, 1.3, SMOKE, function(h)
				-- nube che resta
				local cloud = emitter(h, SMOKE, ColorSequence.new(color, Color3.fromRGB(240, 80, 220)), NumberSequence.new(3, 6), 2, 1.5, 25)
				cloud.LightEmission = 0.4
				task.delay(1.2, function()
					cloud.Enabled = false
				end)
			end)
		end)
		return
	end
	if e == "Roccia" then
		local rock = fx(Enum.PartType.Ball, Vector3.new(2.2, 1.8, 2), Color3.fromRGB(130, 110, 90), CFrame.new(from), Enum.Material.Slate)
		emitter(rock, SMOKE, ColorSequence.new(Color3.fromRGB(200, 170, 120)), NumberSequence.new(0.8, 2), 0.6, 1, 30)
		fly(rock, from, to, 110, true, function()
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
		local dir = (to - from).Unit
		spear.CFrame = CFrame.lookAt(from, from + dir) * CFrame.Angles(0, math.pi / 2, 0)
		local time = math.clamp((to - from).Magnitude / 140, 0.1, 0.6)
		local tw = TweenService:Create(spear, TweenInfo.new(time), { CFrame = CFrame.lookAt(to, to + dir) * CFrame.Angles(0, math.pi / 2, 0) })
		tw:Play()
		tw.Completed:Connect(function()
			spear:Destroy()
			impact(to, color, 1, SMOKE)
		end)
		return
	end
	if e == "Cosmico" or e == "Ombra" then
		local star = fx(Enum.PartType.Ball, Vector3.one * 1.6, Color3.new(1, 1, 1), CFrame.new(from))
		trail(star, color, 1.4, 0.4)
		emitter(star, SPARK, ColorSequence.new(color, Color3.new(1, 1, 1)), NumberSequence.new(0.6, 0), 0.6, 3, 60)
		light(star, color, 12, 3)
		fly(star, from, to, 120, false, function()
			impact(to, color, 1.4, SPARK)
		end)
		return
	end
	-- fuoco (Brace, Eclissi, Sole e tutti gli altri)
	local ball = fx(Enum.PartType.Ball, Vector3.one * 3, color, CFrame.new(from))
	ball.Transparency = 0.1
	trail(ball, color, 2.6, 0.35)
	emitter(ball, FIRE, ColorSequence.new(Color3.fromRGB(255, 230, 140), color), NumberSequence.new(2.6, 0.6), 0.4, 2, 90)
	light(ball, color, 14, 3)
	fly(ball, from, to, 120, false, function()
		impact(to, color, 1.3, FIRE)
	end)
end

return DragonVFX
