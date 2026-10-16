--!strict
-- Combattimento lato client (il danno lo calcola sempre il server, server/Enemies e Flyers):
--   * attacco speciale del drago: tasto Z (o il pulsante del drago sul telefono), ricarica
--     mostrata nel pulsante in basso
--   * effetti dell'evento "EnemyFX": onda del drago, picchiata, stordimento, rimbalzi della
--     piccozza, meteore, palle di fuoco dei draghi volanti
--   * draghi volanti (tag "Volante"): li muove ogni client dagli attributi del volo
--   * draghi Shiny: brillii dorati
--   * cronometro della discesa, evento della mappa in corso (lo scudo sta nella scheda dell'HUD)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local FlyerPath = require(Shared:WaitForChild("FlyerPath"))
local KfsPlayer = require(script.Parent.KfsPlayer)
local DragonMotion = require(script.Parent.DragonMotion)
local DragonVFX = require(script.Parent.DragonVFX)
local MeshFX = require(script.Parent.MeshFX)
local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)
local Theme = require(script.Parent.Theme)
local UiGlow = require(script.Parent.UiGlow)
local Ui = require(ReplicatedStorage:WaitForChild("Shared").UiView)

local Combat = {}

local player = Players.LocalPlayer

local function elementColor(e: string?): Color3
	local el = e and DragonConfig.element(e)
	return if el then el.glow else Color3.fromRGB(255, 200, 120)
end

-- parte d'effetto (locale, senza collisioni)
local function fxPart(shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, transparency: number?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency or 0.2
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = workspace
	return p
end

-- anello che si allarga a terra
local function shockwave(at: Vector3, radius: number, color: Color3, time: number?)
	local t = time or 0.45
	local ring = fxPart(Enum.PartType.Cylinder, Vector3.new(0.4, 2, 2), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), color, 0.1)
	TweenService:Create(ring, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, t + 0.1)
	local dome = fxPart(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(at), color, 0.4)
	TweenService:Create(dome, TweenInfo.new(t * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 1.2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(dome, t)
end

-- colonna di luce dell'attacco speciale: sale dal punto, si allarga e si spegne
local groundOnly = RaycastParams.new()
groundOnly.FilterType = Enum.RaycastFilterType.Include
groundOnly.FilterDescendantsInstances = { workspace.Terrain }
local function pillar(at: Vector3, radius: number, color: Color3)
	local h = radius * 3
	local col = fxPart(Enum.PartType.Cylinder, Vector3.new(h, radius * 0.25, radius * 0.25), CFrame.new(at + Vector3.new(0, h / 2 - 4, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, 0.15)
	local core = fxPart(Enum.PartType.Cylinder, Vector3.new(h, radius * 0.1, radius * 0.1), col.CFrame, color:Lerp(Color3.new(1, 1, 1), 0.5), 0.35)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = math.min(60, radius * 2)
	glow.Brightness = 6
	glow.Parent = core
	TweenService:Create(col, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(h, radius * 0.7, radius * 0.7), Transparency = 1 }):Play()
	TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(h, 0.2, 0.2), Transparency = 1 }):Play()
	TweenService:Create(glow, TweenInfo.new(0.7), { Brightness = 0 }):Play()
	Debris:AddItem(col, 0.8)
	Debris:AddItem(core, 0.8)
end

local function shake(amount: number)
	local cam = workspace.CurrentCamera
	task.spawn(function()
		for k = 1, 8 do
			local s = amount * (1 - k / 8)
			cam.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.04 * s, (math.random() - 0.5) * 0.04 * s, 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

local function myRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

------------------------------------------------------------------------------------------
-- Effetti dal server

local function stunStars(model: Instance, seconds: number)
	if not model:IsA("Model") then
		return
	end
	local _, size = model:GetBoundingBox()
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.fromOffset(80, 30)
	bill.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.55 + 1.5, 0)
	bill.AlwaysOnTop = true
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "✦ ✦ ✦"
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.fromRGB(255, 230, 90)
	l.TextStrokeTransparency = 0.4
	l.Parent = bill
	bill.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	bill.Parent = model
	Debris:AddItem(bill, seconds)
	task.spawn(function()
		local t0 = os.clock()
		while bill.Parent and os.clock() - t0 < seconds do
			l.Rotation = math.sin((os.clock() - t0) * 8) * 12
			task.wait(0.05)
		end
	end)
end

local function meteor(sky: Vector3, ground: Vector3, fall: number)
	-- cerchio d'avviso a terra
	local warn = fxPart(Enum.PartType.Cylinder, Vector3.new(0.3, 24, 24), CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 70, 40), 0.55)
	Debris:AddItem(warn, fall)
	local rock = fxPart(Enum.PartType.Ball, Vector3.one * 5, CFrame.new(sky), Color3.fromRGB(255, 120, 40), 0)
	local fire = Instance.new("Fire")
	fire.Size = 14
	fire.Heat = 20
	fire.Color = Color3.fromRGB(255, 120, 40)
	fire.SecondaryColor = Color3.fromRGB(160, 60, 255)
	fire.Parent = rock
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 2, 0)
	a0.Parent = rock
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -2, 0)
	a1.Parent = rock
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(140, 60, 255))
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = rock
	TweenService:Create(rock, TweenInfo.new(fall, Enum.EasingStyle.Linear), { CFrame = CFrame.new(ground) }):Play()
	task.delay(fall, function()
		rock:Destroy()
		shockwave(ground, 14, Color3.fromRGB(255, 130, 50), 0.5)
		Sfx.play("Esplosione", ground)
		local root = myRoot()
		if root and (root.Position - ground).Magnitude < 60 then
			shake(1.2)
		end
	end)
end

local function fireball(from: Vector3, to: Vector3, element: string, travel: number, scale: number?, noWarn: boolean?)
	if not noWarn then
		-- cerchio rosso dove cadra' la palla (dei draghi volanti, per schivarla)
		local warn = fxPart(Enum.PartType.Cylinder, Vector3.new(0.3, 20, 20), CFrame.new(to + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 60, 40), 0.6)
		Debris:AddItem(warn, travel)
	end
	DragonVFX.shot(element, from, to, elementColor(element), scale or 2.5)
	task.delay(travel, function()
		shockwave(to, 10, elementColor(element), 0.35)
	end)
end

------------------------------------------------------------------------------------------
-- Draghi volanti: si muovono qui (posizione dagli attributi, uguale al server)

type Leaving = { t0: number, cf: CFrame, dead: boolean }
local leaving: { [Model]: Leaving } = {}

local function flash(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.4
	h.OutlineTransparency = 1
	h.Parent = model
	Debris:AddItem(h, 0.12)
end

-- animazioni del drago volante (quelle del suo rig, generate da MapGen.AnimDraghi): un ciclo
-- per il pezzo di volo (attributo "Anim") e un gesto quando cambia "ActT" (attributo "Act")
local LOOPS = { "Fly", "Glide", "Hover", "Dive", "Idle", "Walk" }
local ACTS = { "Roar", "Breath", "Bite", "Hit", "Land", "Takeoff", "Look", "Shake" }
local FALLBACK = { Glide = "Fly", Hover = "Fly", Dive = "Fly", Idle = "Fly", Walk = "Idle" }
type FlyAnim = { tracks: { [string]: any }, actT: number?, actTrack: any?, actUntil: number }
local flyAnims: { [Model]: FlyAnim } = {}

local function flyAnim(m: Model): FlyAnim?
	local a = flyAnims[m]
	if a then
		return a
	end
	local key = m:GetAttribute("AnimKey")
	local saves = ReplicatedStorage:FindFirstChild("DragonAnimSaves")
	local set = saves and type(key) == "string" and saves:FindFirstChild(key)
	if not set then
		return nil
	end
	local tracks = {}
	for _, name in LOOPS do
		local k = set:FindFirstChild("Dragon_" .. name)
		if k and k:IsA("KeyframeSequence") then
			local tr = KfsPlayer.load(m, k)
			tr:Play(0, 0.001)
			tracks[name] = tr
		end
	end
	for _, name in ACTS do
		local k = set:FindFirstChild("Dragon_" .. name)
		if k and k:IsA("KeyframeSequence") then
			local tr = KfsPlayer.load(m, k)
			tr.Looped = false
			tracks[name] = tr
		end
	end
	local made: FlyAnim = { tracks = tracks, actT = m:GetAttribute("ActT") :: number?, actTrack = nil, actUntil = 0 }
	flyAnims[m] = made
	return made
end

local function animateFlyer(m: Model)
	local a = flyAnim(m)
	if not a then
		return
	end
	local base = (m:GetAttribute("Anim") or "Fly") :: string
	while not a.tracks[base] and FALLBACK[base] do
		base = FALLBACK[base]
	end
	-- gesto (ruggito, soffio...): parte da capo quando il server cambia ActT
	local actT = m:GetAttribute("ActT")
	if type(actT) == "number" and actT ~= a.actT then
		a.actT = actT
		local tr = a.tracks[(m:GetAttribute("Act") or "") :: string]
		if tr then
			if a.actTrack and a.actTrack ~= tr then
				a.actTrack:Stop(0.15)
			end
			tr.time = 0
			tr:Play(0.12, 1)
			a.actTrack = tr
			a.actUntil = os.clock() + tr.clip.length - 0.2
			if m:GetAttribute("Act") == "Roar" then
				Sfx.play("Ruggito", m:GetPivot().Position, 2)
			end
			-- morso, soffio e ruggito a terra con le mesh VFX
			local actName = m:GetAttribute("Act")
			if type(actName) == "string" then
				MeshFX.flyer(m, actName, DragonVFX.mouth(m))
			end
		end
	end
	local acting = a.actTrack ~= nil and os.clock() < a.actUntil
	if a.actTrack and not acting then
		a.actTrack:Stop(0.3)
		a.actTrack = nil
	end
	for _, name in LOOPS do
		local tr = a.tracks[name]
		if tr then
			tr:AdjustWeight(if name == base then (if acting then 0.25 else 1) else 0.001, 0.35)
		end
	end
end

-- gesto una tantum sul drago al seguito di un giocatore (es. soffio dell'attacco speciale)
local petActs: { [Model]: { [string]: any } } = {}
local function petGesture(userId: number, name: string)
	local folder = workspace:FindFirstChild("Pets")
	local mine = folder and folder:FindFirstChild(tostring(userId))
	for _, m in (if mine then mine:GetChildren() else {}) :: { Instance } do
		local key = m:GetAttribute("AnimKey")
		local saves = ReplicatedStorage:FindFirstChild("DragonAnimSaves")
		local set = saves and type(key) == "string" and saves:FindFirstChild(key)
		local k = set and set:FindFirstChild("Dragon_" .. name)
		if m:IsA("Model") and k and k:IsA("KeyframeSequence") then
			petActs[m] = petActs[m] or {}
			local tr = petActs[m][name]
			if not tr then
				tr = KfsPlayer.load(m, k)
				tr.Looped = false
				petActs[m][name] = tr
			end
			tr.time = 0
			tr:Play(0.1, 1.5)
			task.delay(tr.clip.length - 0.15, function()
				tr:Stop(0.25)
			end)
		end
	end
end

local function moveFlyers()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local now = workspace:GetServerTimeNow()
	for _, m in CollectionService:GetTagged("Volante") do
		if not m:IsA("Model") then
			continue
		end
		local l = leaving[m]
		if l then
			local t = os.clock() - l.t0
			if l.dead then
				-- cade roteando
				m:PivotTo(l.cf * CFrame.new(0, -t * t * 30, 0) * CFrame.Angles(t * 1.5, 0, t))
			else
				-- vola via in alto
				m:PivotTo(l.cf + Vector3.new(0, t * 60, 0) + l.cf.LookVector * t * 80)
			end
			continue
		end
		if m:GetAttribute("SegKind") == nil then
			continue
		end
		local cf = FlyerPath.fromModel(m, now)
		if (cf.Position - camPos).Magnitude < 2500 then
			m:PivotTo(cf)
			animateFlyer(m)
		end
	end
	for m in flyAnims do
		if not m.Parent then
			flyAnims[m] = nil
		end
	end
	for m in petActs do
		if not m.Parent then
			petActs[m] = nil
		end
	end
end

------------------------------------------------------------------------------------------
-- Draghi Shiny: brillii dorati e un filo di luce

local function decorateShiny(m: Instance)
	if not m:IsA("Model") or not m:GetAttribute("Shiny") or m:FindFirstChild("ShinyFX", true) then
		return
	end
	local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "ShinyFX"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 110))
	e.LightEmission = 1
	e.Rate = 14
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.7, 0)
	e.Parent = part
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 90)
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = part
	-- scia dorata (si vede solo quando si muove, in volo): stessa mesh, si distingue dagli altri
	local _, size = m:GetBoundingBox()
	local half = math.max(1, size.Y * 0.2)
	local a0 = Instance.new("Attachment")
	a0.Name = "ShinyScia0"
	a0.Position = Vector3.new(0, half, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "ShinyScia1"
	a1.Position = Vector3.new(0, -half, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "ShinyScia"
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 170, 40))
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.LightEmission = 0.8
	trail.Lifetime = 0.45
	trail.MinLength = 0.5
	trail.FaceCamera = true
	trail.Parent = part
end

------------------------------------------------------------------------------------------
-- Attacco speciale

local function special()
	local readyAt = (player:GetAttribute("SpecialReady") or 0) :: number
	if workspace:GetServerTimeNow() < readyAt then
		ClientState.hint = string.format("Dragon special ready in %d s", math.ceil(readyAt - workspace:GetServerTimeNow()))
		return
	end
	if (player:GetAttribute("PetAbilities") or "") == "" then
		ClientState.hint = "You need a dragon following you: open Dragons and tap Follow"
		return
	end
	local r = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("DragonSpecial") :: RemoteEvent?
	if r then
		r:FireServer()
	end
end

------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Draghi a riposo attorno alla casa (tag "Riposo", server/Economy): dormono, si siedono,
-- ogni tanto si svegliano e si guardano attorno. Solo quelli vicini alla camera.

type Resting = { tracks: { [string]: any }, state: string, nextChange: number, base: CFrame, lift: number }
local resting: { [Model]: Resting } = {}

local function restStep()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local saves = ReplicatedStorage:FindFirstChild("DragonAnimSaves")
	for _, m in CollectionService:GetTagged("Riposo") do
		if not m:IsA("Model") or (m:GetPivot().Position - camPos).Magnitude > 250 then
			continue
		end
		local r = resting[m]
		if not r then
			local set = saves and saves:FindFirstChild((m:GetAttribute("AnimKey") or "") :: string)
			if not set then
				continue
			end
			local tracks = {}
			for _, name in { "Idle", "Sit", "Sleep", "Look", "Shake" } do
				local k = set:FindFirstChild("Dragon_" .. name)
				if k and k:IsA("KeyframeSequence") then
					local tr = KfsPlayer.load(m, k)
					tr.Looped = name == "Idle" or name == "Sit" or name == "Sleep"
					if tr.Looped then
						tr:Play(0, 0.001)
					end
					tracks[name] = tr
				end
			end
			r = { tracks = tracks, state = "", nextChange = 0, base = m:GetPivot(), lift = 0 }
			resting[m] = r
		end
		local rr = r :: Resting
		if os.clock() >= rr.nextChange then
			local roll = math.random()
			local state = if roll < 0.5 then "Sleep" elseif roll < 0.8 then "Sit" else "Idle"
			if rr.state == "Sleep" and state ~= "Sleep" then
				-- si sveglia: si scrolla o si guarda attorno
				local g = rr.tracks[if math.random() < 0.5 then "Shake" else "Look"]
				if g then
					g.time = 0
					g:Play(0.2, 1.2)
					task.delay(g.clip.length - 0.2, function()
						g:Stop(0.3)
					end)
				end
			end
			rr.state = state
			rr.nextChange = os.clock() + 15 + math.random() * 25
			for name, tr in rr.tracks do
				if tr.Looped then
					tr:AdjustWeight(if name == state then 1 else 0.001, 1.5)
				end
			end
		end
	end
	for m in resting do
		if not m.Parent then
			resting[m] = nil
		end
	end
end

function Combat.start()
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(restStep)
		end
	end)
	-- draghi del recinto: si guardano attorno (collo e testa, client/DragonMotion)
	RunService.RenderStepped:Connect(function(dt)
		local camPos = workspace.CurrentCamera.CFrame.Position
		local now = os.clock()
		for m, r in resting do
			if m.Parent and (m:GetPivot().Position - camPos).Magnitude < 200 then
				DragonMotion.update(m, dt, { turn = 0, vy = 0, speed = 0, air = 0, walk = 0, t = now })
				-- seduto o sdraiato: si alza quanto serve perche' la pancia non entri nella paglia
				r.lift += (DragonMotion.groundLift(m) - r.lift) * math.min(1, dt * 4)
				m:PivotTo(r.base + Vector3.new(0, r.lift, 0))
			end
		end
	end)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	task.spawn(function()
		local fx = remotes:WaitForChild("EnemyFX", 60) :: RemoteEvent?
		if not fx then
			return
		end
		(fx :: RemoteEvent).OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any, e: any)
			if kind == "special" then
				-- onda dell'elemento del drago: forme dell'elemento grandi quanto l'area del colpo,
				-- colonna di luce, tre onde d'urto e una raggiera di colpi dell'elemento verso
				-- l'esterno (prima era un anello piccolo che quasi non si vedeva)
				local color = elementColor(c)
				MeshFX.special(c, a, b)
				shockwave(a, b, color, 0.6)
				task.delay(0.12, shockwave, a, b * 0.7, Color3.new(1, 1, 1), 0.45)
				task.delay(0.28, shockwave, a, b * 1.2, color, 0.8)
				pillar(a, b, color)
				local S = math.clamp(b / 14, 1.5, 3.5)
				local spin = math.random() * math.pi * 2
				for k = 1, 6 do
					local ang = spin + k / 6 * math.pi * 2
					local out = a + Vector3.new(math.cos(ang) * b, 0, math.sin(ang) * b)
					local hit = workspace:Raycast(out + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), groundOnly)
					local to = if hit then hit.Position else out - Vector3.new(0, 6, 0)
					task.delay(0.05 + k * 0.04, DragonVFX.shot, c, a + Vector3.new(0, 2, 0), to, color, S)
				end
				Sfx.play("Ruggito", a)
				petGesture(d, "Breath")
				if d == player.UserId then
					shake(1.6)
				end
			elseif kind == "plunge" then
				shockwave(a, b, Color3.fromRGB(200, 230, 255), 0.4)
				Sfx.play("Roccia", a)
				local root = myRoot()
				if root and (root.Position - a).Magnitude < 30 then
					shake(1.4)
				end
			elseif kind == "stun" then
				stunStars(a, b)
			elseif kind == "bounce" then
				local p = fxPart(Enum.PartType.Block, Vector3.new(0.5, 0.5, 2.4), CFrame.lookAt(a, b), Color3.fromRGB(180, 220, 255), 0)
				TweenService:Create(p, TweenInfo.new(0.18), { CFrame = CFrame.lookAt(b, b + (b - a)) }):Play()
				Debris:AddItem(p, 0.22)
			elseif kind == "meteor" then
				meteor(a, b, c)
			elseif kind == "fireball" then
				fireball(a, b, c, d)
			elseif kind == "rideShot" then
				-- colpo del drago in monta (server/Enemies RideAttack): morso e palla dell'elemento.
				-- Parte dalla bocca del drago come lo vedi tu: la posizione del server in volo veloce
				-- e' indietro di 10-20 studs e il colpo partiva da dietro il drago
				local folder = workspace:FindFirstChild("Pets")
				local mine = folder and folder:FindFirstChild(tostring(e))
				local scale = 3
				for _, m in (if mine then mine:GetChildren() else {}) :: { Instance } do
					if m:IsA("Model") and m:GetAttribute("Slot") == 1 then
						local mouth = DragonVFX.mouth(m, b)
						local fwd = b - mouth
						scale = DragonVFX.scaleFor(m)
						if fwd.Magnitude > 1 then
							-- un po' davanti al muso, che non si veda nascere dentro la testa
							a = mouth + fwd.Unit * 2 * scale
						end
					end
				end
				fireball(a, b, c, d, scale, true)
				petGesture(e, "Bite")
				Sfx.play("Ruggito", a, 1.6)
			elseif kind == "chain" then
				-- rimbalzo del fulmine da un nemico all'altro (RIDE_ELEMENT.chain)
				DragonVFX.shot(c, a, b, elementColor(c), 1.6)
			elseif kind == "flyerHurt" then
				flash(a)
			elseif kind == "flyerDeath" or kind == "flyerLeave" then
				if typeof(a) == "Instance" and a:IsA("Model") then
					leaving[a] = { t0 = os.clock(), cf = a:GetPivot(), dead = kind == "flyerDeath" }
					if kind == "flyerDeath" then
						Sfx.play("Ruggito", a:GetPivot().Position, 1.5)
					end
				end
			end
		end)
	end)

	-- tasto Z e pulsante del telefono
	ContextActionService:BindAction("SpecialeDrago", function(_, state)
		if state == Enum.UserInputState.Begin then
			special()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Z, Enum.KeyCode.ButtonY)

	-- Il pulsante mantiene nome e azione; il modello e la cornice si modificano in Studio.
	local gui = Ui.screen("CombatHUD")
	local spBtn = Ui.node(gui, "Speciale")
	-- niente cornice dorata: un anello luminoso che gira quando lo speciale e' pronto
	spBtn.Stroke.Enabled = false
	-- via anche il riquadro quadrato dietro l'icona tonda (immagine del pulsante)
	spBtn:SetAttribute("UiAsset", nil)
	for _, n in { "AssetSurface", "AssetCaption" } do
		local o = spBtn:FindFirstChild(n)
		if o then
			o:Destroy()
		end
	end
	-- fondo tondo scuro (l'icona e' un drago bianco: senza fondo non si legge sul cielo)
	spBtn.BackgroundColor3 = Theme.DARK
	spBtn.BackgroundTransparency = 0.25
	spBtn.TextTransparency = 1
	for _, c in spBtn:GetChildren() do
		if c:IsA("UICorner") then
			c.CornerRadius = UDim.new(0.5, 0)
		end
	end
	-- la ricarica copre l'icona tonda: tonda anche lei (prima un quadrato scuro)
	local coolCorner = spBtn.Cooldown:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	coolCorner.CornerRadius = UDim.new(0.5, 0)
	coolCorner.Parent = spBtn.Cooldown
	local spRing = UiGlow.ring(spBtn, Theme.ACCENT, { round = true, thickness = 3, pad = 0, halo = false })
	local spReady: boolean? = nil
	local spCool = spBtn.Cooldown
	spBtn.Key.Text = if Ui.touch() then "Roar" else "Z"
	spBtn.Activated:Connect(special)
	local timer = Ui.node(gui, "Timer")
	local eventLabel = Ui.node(gui, "Event")
	-- pulsante dello speciale in basso a destra (sul telefono sopra il tasto salto); cronometro
	-- e evento in alto al centro sotto la missione (prima stavano in mezzo allo schermo)
	Ui.text(timer, 26, true)
	Ui.text(eventLabel, 18, true)
	-- Roar / Z si sposta come gli altri elementi dell'HUD (client/HudLayout, tasto ⚙)
	local HudLayout = require(script.Parent.HudLayout)
	HudLayout.register("Roar", spBtn, if Ui.touch() then "ROAR" else "DRAGON SPECIAL (Z)")
	local lastVp: Vector2? = nil
	local function layoutCombat()
		local vp = lastVp
		if not vp then
			return
		end
		local logical = Ui.fitScale(gui, vp)
		if Ui.touch() then
			-- in basso, a sinistra dell'arco dei comandi (MobileControls: arco attorno al salto,
			-- raggio fino a ~230 px veri dall'angolo, i tasti del telefono non seguono la scala),
			-- piu' in la' del secondo giro di tasti (prima toccava RIDE e la barra 1-5)
			local k = logical.X / vp.X
			local small = math.min(vp.X, vp.Y) <= 500
			local x, y = if small then 300 else 420, if small then 58 else 150
			Ui.px(spBtn, 1, -x * k, 1, -y * k, 76, 76, 0.5, 0.5)
		else
			Ui.px(spBtn, 1, -24, 1, -24, 76, 76, 1, 1)
		end
		HudLayout.place("Roar", spBtn)
		Ui.px(timer, 0.5, 0, 0, 190, math.min(520, logical.X - 32), 34, 0.5, 0)
		Ui.px(eventLabel, 0.5, 0, 0, 228, math.min(620, logical.X - 32), 28, 0.5, 0)
	end
	HudLayout.onChange(layoutCombat)
	Ui.viewportChanged(function(vp)
		lastVp = vp
		layoutCombat()
	end, gui)

	local accum = 0
	RunService.RenderStepped:Connect(function(dt)
		moveFlyers()
		accum += dt
		if accum < 0.1 then
			return
		end
		accum = 0
		-- attacco speciale
		local hasDragon = (player:GetAttribute("PetAbilities") or "") ~= ""
		spBtn.Visible = hasDragon and not ClientState.dragonMode
		local left = ((player:GetAttribute("SpecialReady") or 0) :: number) - workspace:GetServerTimeNow()
		spCool.Visible = left > 0
		spCool.Text = if left > 0 then tostring(math.ceil(left)) else ""
		if spReady ~= (left <= 0) then
			spReady = left <= 0
			UiGlow.color(spRing, if spReady then Theme.ACCENT else Theme.MUTED, not spReady)
		end
		-- discesa a tempo
		local started = player:GetAttribute("DescentStart")
		if type(started) == "number" then
			local s = workspace:GetServerTimeNow() - started
			local best = player:GetAttribute("BestDescent")
			timer.Text = string.format("DESCENT %d:%04.1f%s", s // 60, s % 60, if type(best) == "number" then string.format("  (best %.1f s)", best) else "")
		else
			timer.Text = ""
		end
		-- evento della mappa
		local ev = workspace:GetAttribute("WorldEvent")
		local at = workspace:GetAttribute("WorldEventPos")
		local root = myRoot()
		-- (l'evento ora lo mostra client/EventBanner sotto il Prize Pool: qui resta vuoto)
		local _ = ev
		local _ = at
		local _ = root
		eventLabel.Text = ""
		eventLabel.Visible = false
	end)

	-- draghi shiny (anche quelli degli altri)
	local pets = workspace:WaitForChild("Pets")
	pets.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d:GetAttribute("Owner") then
			task.delay(0.5, decorateShiny, d)
		end
	end)
	for _, d in pets:GetDescendants() do
		decorateShiny(d)
	end
end

return Combat
