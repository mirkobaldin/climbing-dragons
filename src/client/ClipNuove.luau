--!strict
-- Clip nuove per TikTok, girate in automatico (comandi admin clip21 ... clip25; la scena la
-- prepara il server in Workspace.ClipProps, vedi server/ClipProps). Niente scritte: i testi si
-- mettono nell'editor di TikTok (docs/CLIP_NUOVE.md). L'ora del giorno e' quella che hai fissato
-- col comando "time" (es. time 17).
--   clip21  RATE EVERY DRAGON: gli 8 adulti che ruggiscono uno dopo l'altro
--   clip22  THE SUMMIT HAD A GUARDIAN: in vetta il drago sale dal precipizio, atterra, ruggisce e soffia
--   clip23  1 IQ vs 200 IQ: cade dalla parete e si schianta; poi la stessa caduta salvata dal rampino
--   clip24  SHINY HATCH: l'uovo trema tre volte, lampo dorato, il cucciolo shiny ruggisce
--   clip25  4000 m DESCENT: parapendio dalla vetta al campo base col cronometro

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local KfsPlayer = require(script.Parent.KfsPlayer)
local Sfx = require(script.Parent.Sfx)

local ClipNuove = {}

local player = Players.LocalPlayer

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zAxis
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local function groundAt(p: Vector3): Vector3
	local hit = workspace:Raycast(p + Vector3.new(0, 200, 0), Vector3.new(0, -600, 0), terrainOnly)
	return if hit then hit.Position else p
end

------------------------------------------------------------------------------------------
-- Set: interfaccia nascosta, personaggio nascosto, camera, lampi, scossa

type Set = { gui: ScreenGui, fade: Frame, flash: Frame, cam: CFrame, fov: number, shake: number, restore: () -> () }

local function openSet(): Set
	local hiddenGuis = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClipNuova"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 300
	gui.ResetOnSpawn = false
	local function frame(color: Color3, t: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BackgroundTransparency = t
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = 5
		f.Parent = gui
		return f
	end
	local fade = frame(Color3.new(0, 0, 0), 0)
	local flashF = frame(Color3.new(1, 1, 1), 1)
	gui.Parent = player.PlayerGui
	-- il personaggio vero sparisce e sta fermo (e trascina lo streaming dove serve)
	local me = player.Character
	local root = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	local home = me and me:GetPivot()
	local hiddenParts: { BasePart } = {}
	local function hideAll(m: Instance?)
		for _, d in (if m then m:GetDescendants() else {}) :: { Instance } do
			if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
				d.LocalTransparencyModifier = 1
				table.insert(hiddenParts, d)
			end
		end
	end
	hideAll(me)
	hideAll(workspace:FindFirstChild("Pets"))
	if root then
		root.Anchored = true
	end
	local blurred = {}
	for _, e in Lighting:GetChildren() do
		if (e:IsA("DepthOfFieldEffect") or e:IsA("BlurEffect")) and (e :: any).Enabled then
			(e :: any).Enabled = false
			table.insert(blurred, e)
		end
	end
	local set: Set
	set = {
		gui = gui,
		fade = fade,
		flash = flashF,
		cam = workspace.CurrentCamera.CFrame,
		fov = 60,
		shake = 0,
		restore = function()
			RunService:UnbindFromRenderStep("ClipNuova")
			gui:Destroy()
			for _, g in hiddenGuis do
				g.Enabled = true
			end
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
			end)
			for _, p in hiddenParts do
				p.LocalTransparencyModifier = 0
			end
			for _, e in blurred do
				(e :: any).Enabled = true
			end
			if me and root and home then
				me:PivotTo(home)
				root.Anchored = false
			end
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Custom
			cam.FieldOfView = 70
		end,
	}
	RunService:BindToRenderStep("ClipNuova", Enum.RenderPriority.Camera.Value + 5, function(dt)
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		local cf = set.cam
		if set.shake > 0 then
			cf *= CFrame.Angles((math.random() - 0.5) * 0.05 * set.shake, (math.random() - 0.5) * 0.05 * set.shake, (math.random() - 0.5) * 0.02 * set.shake)
			set.shake = math.max(0, set.shake - dt * 2.5)
		end
		cam.CFrame = cf
		cam.FieldOfView = set.fov
	end)
	return set
end

-- carica la mappa attorno ai punti (schermo nero) e porta li' il personaggio nascosto
local function preload(points: { Vector3 })
	local me = player.Character
	for _, p in points do
		if me then
			me:PivotTo(CFrame.new(p + Vector3.new(0, 30, 0)))
		end
		pcall(function()
			player:RequestStreamAroundAsync(p, 5)
		end)
	end
	if me and points[1] then
		me:PivotTo(CFrame.new(points[1] + Vector3.new(0, 30, 0)))
	end
	task.wait(1.5)
end

local function flash(set: Set, color: Color3?, time: number?)
	set.flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	set.flash.BackgroundTransparency = 0
	TweenService:Create(set.flash, TweenInfo.new(time or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

local function fadeTo(set: Set, alpha: number, time: number)
	TweenService:Create(set.fade, TweenInfo.new(time), { BackgroundTransparency = 1 - alpha }):Play()
end

-- un tratto della scena: step(u, t) a ogni frame per "dur" secondi
local function beat(dur: number, step: (number, number) -> ())
	local t0 = os.clock()
	while true do
		local t = os.clock() - t0
		local u = math.clamp(t / dur, 0, 1)
		step(u, t)
		if u >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

------------------------------------------------------------------------------------------
-- Attori

-- sosia del giocatore (senza attrezzi), giunture per le pose
type Body = { model: Model, joints: { [string]: Motor6D } }
local function body(): Body?
	local Cinematic = require(script.Parent.Cinematic) :: any
	local m = Cinematic.kit.cloneActor()
	if not m then
		return nil
	end
	for _, x in m:GetDescendants() do
		if x:IsA("Tool") then
			x:Destroy()
		elseif x:IsA("BasePart") then
			-- solo la radice ferma: le altre parti seguono le giunture (le pose funzionano)
			x.Anchored = x.Name == "HumanoidRootPart"
		end
	end
	local joints = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	m.Parent = workspace
	return { model = m, joints = joints }
end

-- pose a mano (gradi): braccia e gambe
local function pose(b: Body?, arms: number, legs: number, flail: number?)
	if not b then
		return
	end
	local j = b.joints
	local w = os.clock() * 14
	local f = flail or 0
	if j.RightShoulder then
		j.RightShoulder.Transform = CFrame.Angles(math.rad(arms + math.sin(w) * f), 0, math.rad(-10))
	end
	if j.LeftShoulder then
		j.LeftShoulder.Transform = CFrame.Angles(math.rad(arms + math.sin(w + 2) * f), 0, math.rad(10))
	end
	if j.RightHip then
		j.RightHip.Transform = CFrame.Angles(math.rad(legs + math.sin(w + 1) * f * 0.6), 0, 0)
	end
	if j.LeftHip then
		j.LeftHip.Transform = CFrame.Angles(math.rad(-legs + math.sin(w + 3) * f * 0.6), 0, 0)
	end
end

-- animazioni del drago di scena (quelle del suo rig)
type Dragon = { model: Model, tracks: { [string]: any } }
local function dragon(m: Instance?): Dragon?
	if not m or not m:IsA("Model") then
		return nil
	end
	local saves = ReplicatedStorage:FindFirstChild("DragonAnimSaves")
	local set = saves and saves:FindFirstChild((m:GetAttribute("AnimKey") or "") :: string)
	local tracks = {}
	m:SetAttribute("AnimRange", 2000)
	for _, name in { "Fly", "Glide", "Hover", "Dive", "Idle", "Walk", "Roar", "Breath", "Bite", "Hit" } do
		local k = set and set:FindFirstChild("Dragon_" .. name)
		if k and k:IsA("KeyframeSequence") then
			local tr = KfsPlayer.load(m, k)
			tr.Looped = not (name == "Roar" or name == "Breath" or name == "Bite" or name == "Hit")
			if tr.Looped then
				tr:Play(0, 0.001)
			end
			tracks[name] = tr
		end
	end
	return { model = m, tracks = tracks }
end

-- ciclo di base (volo, librato, fermo...) e gesto una tantum sopra
local function loop(d: Dragon?, name: string)
	for n, tr in (if d then d.tracks else {}) :: { [string]: any } do
		if tr.Looped then
			tr:AdjustWeight(if n == name then 1 else 0.001, 0.25)
		end
	end
end
local function gesture(d: Dragon?, name: string): number
	local tr = d and d.tracks[name]
	if not tr then
		return 0
	end
	tr.time = 0
	tr:Play(0.1, 1.6)
	task.delay(tr.clip.length - 0.15, function()
		tr:Stop(0.3)
	end)
	return tr.clip.length
end

local function sizeOf(m: Model): Vector3
	local _, s = m:GetBoundingBox()
	return s
end

local function props(kind: string): Instance?
	local f = workspace:WaitForChild("ClipProps", 10)
	local t0 = os.clock()
	while f and f:GetAttribute("Kind") ~= kind and os.clock() - t0 < 5 do
		task.wait(0.1)
		f = workspace:FindFirstChild("ClipProps")
	end
	task.wait(1) -- i modelli arrivano (streaming)
	return f
end

------------------------------------------------------------------------------------------
-- clip21: RATE EVERY DRAGON

local function clip21(set: Set, f: Instance)
	local list = {}
	for _, m in f:GetChildren() do
		if m:IsA("Model") then
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b)
		return ((a:GetAttribute("Order") or 0) :: number) < ((b:GetAttribute("Order") or 0) :: number)
	end)
	local dragons = {}
	for _, m in list do
		local d = dragon(m)
		loop(d, "Idle")
		table.insert(dragons, d)
	end
	local points = {}
	for _, m in list do
		table.insert(points, m:GetPivot().Position)
	end
	preload(points)
	fadeTo(set, 0, 0.25)
	for i, m in list do
		local d = dragons[i]
		local cf = m:GetBoundingBox()
		local s = sizeOf(m)
		local front = m:GetPivot().LookVector
		local side = front:Cross(Vector3.yAxis)
		local r = math.max(s.X, s.Z) * 0.95
		gesture(d, "Roar")
		task.delay(0.35, function()
			Sfx.play("Ruggito", cf.Position, 2)
			set.shake = 0.8
		end)
		beat(1.6, function(u)
			-- dal basso, di lato verso il muso: il drago sembra enorme
			local camPos = cf.Position + front * r + side * r * (0.6 - 1.2 * u) + Vector3.new(0, -s.Y * 0.15, 0)
			set.cam = CFrame.lookAt(camPos, cf.Position + Vector3.new(0, s.Y * 0.2, 0))
			set.fov = 58 - 6 * u
		end)
	end
	fadeTo(set, 1, 0.3)
	task.wait(0.35)
end

------------------------------------------------------------------------------------------
-- clip22: THE SUMMIT HAD A GUARDIAN

local function clip22(set: Set, f: Instance)
	local dir = flat(f:GetAttribute("Dir") :: Vector3)
	-- lo scalatore sta sul bordo dello spiazzo (fuori dal santuario), il drago sale dal vuoto oltre
	local S = (f:GetAttribute("Edge") :: Vector3) - dir * 10
	local d = dragon(f:FindFirstChild("Guardiano"))
	if not d then
		return
	end
	local m = d.model
	local s = sizeOf(m)
	preload({ S, S + dir * 120 - Vector3.new(0, 150, 0) })
	local b = body()
	local feet = groundAt(S + dir * 4)
	local bodyCf = CFrame.lookAt(feet + Vector3.new(0, 3, 0), feet + Vector3.new(0, 3, 0) + dir)
	if b then
		b.model:PivotTo(bodyCf)
	end
	-- librato davanti allo scalatore, oltre il bordo (sotto c'e' il vuoto)
	local landAt = S + dir * (s.Z * 0.55 + 22) + Vector3.new(0, s.Y * 0.15, 0)
	local below = S + dir * (s.Z * 0.6 + 40) - Vector3.new(0, 160, 0)
	m:PivotTo(CFrame.lookAt(below, below - dir))
	loop(d, "Hover")
	fadeTo(set, 0, 0.25)
	-- 1) di spalle: lo scalatore guarda il panorama dalla vetta
	beat(1.8, function(u)
		pose(b, 15, 0)
		local p = bodyCf.Position
		set.cam = CFrame.lookAt(p - dir * (7 - u) + Vector3.new(1.8, 2.2, 0), p + dir * 60 + Vector3.new(0, -8, 0))
		set.fov = 62
	end)
	-- 2) il drago sale dal precipizio, enorme, battendo le ali
	Sfx.play("Ruggito", below, 1.5)
	beat(2.0, function(u)
		pose(b, 15 + 30 * u, 0)
		local k = smooth(u)
		local p = below:Lerp(landAt + Vector3.new(0, s.Y * 0.5, 0), k)
		m:PivotTo(CFrame.lookAt(p, p - dir) * CFrame.Angles(math.rad(-20 * (1 - k)), 0, 0))
		local bp = bodyCf.Position
		set.cam = CFrame.lookAt(bp - dir * 6 + Vector3.new(1.5, 1.5, 0), p:Lerp(bp, 0.2))
		set.fov = 62 + 10 * k
		set.shake = 0.4
	end)
	-- 3) si ferma in aria davanti a lui
	beat(0.8, function(u)
		local p = (landAt + Vector3.new(0, s.Y * 0.5, 0)):Lerp(landAt, smooth(u))
		m:PivotTo(CFrame.lookAt(p, p - dir))
		local bp = bodyCf.Position
		set.cam = CFrame.lookAt(bp - dir * 6 + Vector3.new(1.5, 1.2, 0), p)
	end)
	set.shake = 1.2
	-- 4) ruggito in faccia: camera bassa davanti allo scalatore che guarda in su
	local roar = gesture(d, "Roar")
	task.delay(0.6, function()
		Sfx.play("Ruggito", landAt, 3)
		set.shake = 2.2
	end)
	beat(math.max(roar, 2.2), function(u)
		pose(b, 120, 10, 10)
		local bp = bodyCf.Position
		set.cam = CFrame.lookAt(bp + dir * 4 + Vector3.new(-2, -1.5, 0), landAt + Vector3.new(0, s.Y * 0.25, 0))
		set.fov = 70 + 6 * u
	end)
	-- 5) soffio: la camera si gira sullo scalatore, lampo di fuoco
	local breath = gesture(d, "Breath")
	beat(math.max(breath * 0.7, 1.4), function(u)
		pose(b, 160, -20, 25)
		local bp = bodyCf.Position
		set.cam = CFrame.lookAt(bp + (dir:Cross(Vector3.yAxis)) * 12 + Vector3.new(0, 3, 0), bp:Lerp(landAt, 0.4))
		if u > 0.55 and set.flash.BackgroundTransparency > 0.95 then
			flash(set, Color3.fromRGB(255, 150, 60), 1)
			Sfx.play("SoffioFuoco", bp, 2)
			set.shake = 2
		end
	end)
	fadeTo(set, 1, 0.25)
	task.wait(0.3)
	if b then
		b.model:Destroy()
	end
end

------------------------------------------------------------------------------------------
-- clip23: 1 IQ vs 200 IQ

local function rope(a: Vector3, b: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery = true, false, false
	p.Material = Enum.Material.Fabric
	p.Color = Color3.fromRGB(220, 190, 120)
	local len = (b - a).Magnitude
	p.Size = Vector3.new(0.25, 0.25, len)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = workspace
	return p
end

local function clip23(set: Set, f: Instance)
	local T = f:GetAttribute("CliffTop") :: Vector3
	local D = f:GetAttribute("CliffDir") :: Vector3
	local B = f:GetAttribute("CliffBottom") :: Vector3
	local drop = T.Y - B.Y
	preload({ T, B })
	local b = body()
	local start = T + D * 3 + Vector3.new(0, 3, 0)
	local landing = B + Vector3.new(0, 1, 0)
	local side = D:Cross(Vector3.yAxis)
	local function fall(u: number): Vector3
		-- cade lungo la parete, un po' in fuori
		local y = start.Y - (start.Y - landing.Y) * (u * u)
		local out = start:Lerp(landing, u)
		return Vector3.new(out.X, y, out.Z)
	end
	fadeTo(set, 0, 0.2)
	-- 1 IQ: si sporge, salta, si schianta
	beat(0.7, function(u)
		pose(b, 20, 0)
		if b then
			b.model:PivotTo(CFrame.lookAt(start, start + D))
		end
		set.cam = CFrame.lookAt(start + Vector3.new(0, 14, 0) - D * 8 + side * 4, start + D * 20 - Vector3.new(0, 40, 0))
	end)
	local dur = math.clamp(drop / 140, 1.6, 2.6)
	beat(dur, function(u)
		local p = fall(u)
		pose(b, 170, 20, 40)
		if b then
			b.model:PivotTo(CFrame.lookAt(p, p + D) * CFrame.Angles(math.rad(-30 * u), 0, math.rad(u * 200)))
		end
		-- dall'alto: si vede quanto e' profondo
		set.cam = CFrame.lookAt(p + Vector3.new(0, 16, 0) - D * 5, p - Vector3.new(0, 30, 0))
		set.fov = 70 + 15 * u
	end)
	set.shake = 3
	flash(set, Color3.fromRGB(200, 0, 0), 0.8)
	Sfx.play("Esplosione", landing, 1.5)
	beat(0.9, function()
		if b then
			b.model:PivotTo(CFrame.lookAt(landing, landing + D) * CFrame.Angles(math.rad(-90), 0, 0))
		end
		set.cam = CFrame.lookAt(landing + Vector3.new(0, 10, 0) - D * 6, landing)
	end)
	-- stacco
	flash(set, Color3.new(1, 1, 1), 0.4)
	-- 200 IQ: stessa caduta, a meta' il rampino si aggancia alla parete e lo ferma
	local hookAt = Vector3.new(start.X, start.Y - drop * 0.3, start.Z) - D * 3
	local stopAt = Vector3.new(start.X, start.Y - drop * 0.45, start.Z) + D * 2
	local line: Part? = nil
	beat(0.5, function()
		pose(b, 20, 0)
		if b then
			b.model:PivotTo(CFrame.lookAt(start, start + D))
		end
		set.cam = CFrame.lookAt(start + side * 18 + Vector3.new(0, 4, 0), start)
		set.fov = 65
	end)
	beat(1.0, function(u)
		local p = start:Lerp(stopAt, u * u * 0.6)
		pose(b, 170, 20, 40)
		if b then
			b.model:PivotTo(CFrame.lookAt(p, p + D))
		end
		set.cam = CFrame.lookAt(p + side * 18 + Vector3.new(0, 6, 0), p)
	end)
	Sfx.play("Lancio", hookAt, 1.5)
	local from = start:Lerp(stopAt, 0.6)
	beat(1.4, function(u)
		-- l'uncino vola alla parete, poi la corda lo tira e lo fa oscillare contro la roccia
		local hookP = from:Lerp(hookAt, math.min(1, u * 4))
		local k = smooth(math.max(0, u - 0.25) / 0.75)
		local swing = math.sin(k * math.pi) * 6
		local p = from:Lerp(stopAt, k) + D * swing
		if line then
			line:Destroy()
		end
		line = rope(p + Vector3.new(0, 1.5, 0), hookP)
		pose(b, 160, 10, 15 * (1 - k))
		if b then
			b.model:PivotTo(CFrame.lookAt(p, p - D))
		end
		set.cam = CFrame.lookAt(p + side * 16 + D * 4 + Vector3.new(0, 3, 0), p)
		if u > 0.25 and set.shake < 0.1 and k < 0.1 then
			set.shake = 1
		end
	end)
	-- appeso alla parete: la camera si allontana e mostra il vuoto sotto
	beat(1.8, function(u)
		pose(b, 150, 15)
		set.cam = CFrame.lookAt(stopAt + side * (16 + 40 * u) + D * (6 + 50 * u) + Vector3.new(0, -10 * u, 0), stopAt - Vector3.new(0, 30 * u, 0))
		set.fov = 65 + 10 * u
	end)
	fadeTo(set, 1, 0.25)
	task.wait(0.3)
	if line then
		line:Destroy()
	end
	if b then
		b.model:Destroy()
	end
end

------------------------------------------------------------------------------------------
-- clip24: SHINY HATCH

local function clip24(set: Set, f: Instance)
	local spot = f:GetAttribute("Spot") :: Vector3
	local look = f:GetAttribute("Look") :: Vector3
	local egg = f:FindFirstChild("Uovo") :: Model?
	local cub = dragon(f:FindFirstChild("Cucciolo"))
	preload({ spot })
	if not egg then
		return
	end
	local eggCf = egg:GetPivot()
	local es = sizeOf(egg)
	local center = eggCf.Position
	loop(cub, "Idle")
	fadeTo(set, 0, 0.25)
	local function orbitCam(u: number, dist: number, height: number)
		local a = -0.6 + u * 0.8
		local dir = CFrame.Angles(0, a, 0) * look
		set.cam = CFrame.lookAt(center + dir * dist + Vector3.new(0, height, 0), center)
	end
	-- tre tremiti, sempre piu' forti
	for k = 1, 3 do
		Sfx.play("Roccia", center, 0.6 + k * 0.3)
		beat(0.7, function(u)
			local wob = math.sin(u * math.pi * 6) * math.rad(6 + k * 5) * (1 - u)
			egg:PivotTo(eggCf * CFrame.Angles(wob, 0, wob * 0.6))
			orbitCam((k - 1 + u) / 4, es.Y * 2.6 - k * 0.6, es.Y * 0.4)
			set.shake = 0.15 * k
		end)
	end
	-- lampo dorato: l'uovo sparisce, il cucciolo shiny e' li'
	flash(set, Color3.fromRGB(255, 215, 90), 1.2)
	Sfx.play("Stelle", center, 2)
	egg:PivotTo(CFrame.new(0, -1000, 0))
	local burst = Instance.new("Part")
	burst.Anchored, burst.CanCollide, burst.CanQuery = true, false, false
	burst.Transparency = 1
	burst.Position = center
	burst.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110))
	e.LightEmission = 1
	e.Speed = NumberRange.new(10, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Size = NumberSequence.new(1.2, 0)
	e.Rate = 0
	e.Parent = burst
	e:Emit(120)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 90)
	glow.Range = 30
	glow.Brightness = 4
	glow.Parent = burst
	Debris:AddItem(burst, 6)
	if cub then
		local cs = sizeOf(cub.model)
		local at = groundAt(center) + Vector3.new(0, cs.Y / 2, 0)
		cub.model:PivotTo(CFrame.lookAt(at, at + look))
		-- brillii dorati sul cucciolo
		local part = cub.model:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local s2 = e:Clone()
			s2.Rate = 18
			s2.Speed = NumberRange.new(1, 3)
			s2.Size = NumberSequence.new(0.6, 0)
			s2.Parent = part
		end
		local roar = gesture(cub, "Roar")
		task.delay(0.5, function()
			Sfx.play("Ruggito", at, 1.2)
		end)
		beat(math.max(roar, 2.6), function(u)
			glow.Brightness = 4 * (1 - u * 0.6)
			set.cam = CFrame.lookAt(at + look * (cs.Z * 2.2 - u * cs.Z * 0.6) + Vector3.new(0, cs.Y * 0.2, 0), at + Vector3.new(0, cs.Y * 0.1, 0))
			set.fov = 55
		end)
	end
	fadeTo(set, 1, 0.3)
	task.wait(0.35)
	egg:PivotTo(eggCf)
end

------------------------------------------------------------------------------------------
-- clip25: 4000 m DESCENT

local function canopyFor(b: Body): Part
	local wing = Instance.new("Part")
	wing.Anchored, wing.CanCollide, wing.CanQuery = true, false, false
	wing.Size = Vector3.new(11, 0.4, 3.6)
	wing.Material = Enum.Material.Fabric
	wing.Color = Color3.fromRGB(230, 120, 40)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.5, 1)
	mesh.Parent = wing
	wing.Parent = b.model
	return wing
end

local function clip25(set: Set, f: Instance)
	local n = (f:GetAttribute("Points") or 0) :: number
	local pts = {}
	for k = 0, n do
		table.insert(pts, f:GetAttribute("P" .. k) :: Vector3)
	end
	if #pts < 3 then
		return
	end
	preload({ pts[1], pts[math.floor(#pts / 2)], pts[#pts] })
	local b = body()
	if not b then
		return
	end
	local wing = canopyFor(b)
	-- cronometro come nel gioco (in alto al centro)
	local timer = Instance.new("TextLabel")
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.fromScale(0.5, 0.08)
	timer.Size = UDim2.fromScale(0.3, 0.06)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.GothamBlack
	timer.TextScaled = true
	timer.TextColor3 = Color3.fromRGB(255, 196, 80)
	timer.TextStrokeTransparency = 0.3
	timer.ZIndex = 4
	timer.Parent = set.gui
	local function at(u: number): Vector3
		local x = u * (#pts - 1)
		local i = math.clamp(math.floor(x) + 1, 1, #pts - 1)
		local a, c = pts[i], pts[i + 1]
		return a:Lerp(c, x - (i - 1))
	end
	fadeTo(set, 0, 0.25)
	local FINAL = 83.4 -- il tempo che si vede alla fine (s)
	local smoothCam: CFrame? = nil
	beat(14, function(u)
		local k = u ^ 0.9
		local p = at(k)
		local q = at(math.min(1, k + 0.01))
		local dir = q - p
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zAxis
		local cf = CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, math.sin(u * 20) * 0.15)
		b.model:PivotTo(cf)
		wing.CFrame = cf * CFrame.new(0, 7, 0)
		pose(b, 175, 0)
		-- dietro e un po' sopra, vicina: si vede lo scalatore, la vela e la montagna che scorre sotto
		local back = Vector3.new(dir.X, 0, dir.Z)
		back = if back.Magnitude > 0.01 then back.Unit else Vector3.zAxis
		local want = CFrame.lookAt(p - back * 11 + Vector3.new(2, 5, 0), p + dir * 25 - Vector3.new(0, 6, 0))
		smoothCam = if smoothCam then CFrame.new(want.Position) * (smoothCam :: CFrame).Rotation:Lerp(want.Rotation, 0.2) else want
		set.cam = smoothCam :: CFrame
		set.fov = 75 + 10 * math.sin(u * math.pi)
		local secs = FINAL * u
		timer.Text = string.format("DESCENT %d:%04.1f", secs // 60, secs % 60)
	end)
	-- arrivo al campo base
	timer.TextColor3 = Color3.fromRGB(120, 255, 140)
	set.shake = 0.6
	task.wait(1.2)
	fadeTo(set, 1, 0.3)
	task.wait(0.35)
	b.model:Destroy()
end

------------------------------------------------------------------------------------------

local SCENES = { clip21 = clip21, clip22 = clip22, clip23 = clip23, clip24 = clip24, clip25 = clip25 }

function ClipNuove.play(kind: string)
	local scene = SCENES[kind]
	if not scene then
		return
	end
	local f = props(kind)
	if not f then
		return
	end
	local set = openSet()
	local ok, err = pcall(scene, set, f)
	if not ok then
		warn("[Clip] " .. kind .. ": " .. tostring(err))
	end
	set.restore()
end

return ClipNuove
