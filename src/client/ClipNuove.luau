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
--   clip26  FROM BABY TO BEAST: il giovane si evolve in adulto, ci sali sul collo, volo su borgo,
--           cascate e isole, duello con un drago selvatico sopra la vetta

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
	hideAll(workspace:FindFirstChild("Volanti")) -- il Guardiano vero finiva nel duello della clip26
	local bills = {}
	for _, d in (if workspace:FindFirstChild("Volanti") then (workspace :: any).Volanti:GetDescendants() else {}) :: { Instance } do
		if d:IsA("BillboardGui") and d.Enabled then
			d.Enabled = false
			table.insert(bills, d)
		end
	end
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
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- la salute la mostra la HUD
			end)
			for _, p in hiddenParts do
				p.LocalTransparencyModifier = 0
			end
			for _, d in bills do
				d.Enabled = true
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
	local ONCE = { Roar = true, Breath = true, Bite = true, Hit = true, Takeoff = true, Land = true }
	for _, name in { "Fly", "Glide", "Hover", "Dive", "Idle", "Walk", "Roar", "Breath", "Bite", "Hit", "BankL", "BankR", "Climb", "Descend", "Takeoff", "Land" } do
		local k = set and set:FindFirstChild("Dragon_" .. name)
		if k and k:IsA("KeyframeSequence") then
			local tr = KfsPlayer.load(m, k)
			tr.Looped = not ONCE[name]
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
-- clip26: FROM BABY TO BEAST

-- dove si siede chi monta (attributo Seat del server: sulle spalle dietro il collo)
local function seatOf(m: Model): CFrame
	local seat = m:GetAttribute("Seat")
	local pivot = m:GetPivot()
	if typeof(seat) == "Vector3" then
		return pivot * CFrame.new(seat)
	end
	local cf, size = m:GetBoundingBox()
	return CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)) * pivot.Rotation
end

local function mouthOf(m: Model): Vector3
	local size = sizeOf(m)
	return (m:GetPivot() * CFrame.new(0, size.Y * 0.18, -size.Z * 0.47)).Position
end

-- a cavalcioni: gambe in avanti ai lati del collo, braccia avanti a tenersi
local function sit(b: Body?, lean: number?)
	if not b then
		return
	end
	local j = b.joints
	for _, n in { "RightHip", "LeftHip" } do
		if j[n] then
			j[n].Transform = CFrame.Angles(math.rad(70), 0, math.rad(if n == "RightHip" then -18 else 18))
		end
	end
	for _, n in { "RightKnee", "LeftKnee" } do
		if j[n] then
			j[n].Transform = CFrame.Angles(math.rad(-60), 0, 0)
		end
	end
	for _, n in { "RightShoulder", "LeftShoulder" } do
		if j[n] then
			j[n].Transform = CFrame.Angles(math.rad(55 + (lean or 0)), 0, math.rad(if n == "RightShoulder" then -8 else 8))
		end
	end
	if j.Waist then
		j.Waist.Transform = CFrame.Angles(math.rad(-12 - (lean or 0) * 0.3), 0, 0)
	end
end

-- palla dell'elemento da a a b in "time" secondi; all'arrivo esplode
local function shot(a: Vector3, b: Vector3, color: Color3, time: number, size: number)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Size = Vector3.one * size
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.CFrame = CFrame.new(a)
	ball.Parent = workspace
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/fire_main.dds"
	trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	trail.LightEmission = 1
	trail.Size = NumberSequence.new(size * 0.9, 0)
	trail.Lifetime = NumberRange.new(0.25, 0.45)
	trail.Rate = 120
	trail.Speed = NumberRange.new(1, 3)
	trail.Parent = ball
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 6
	light.Brightness = 3
	light.Parent = ball
	TweenService:Create(ball, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.new(b) }):Play()
	task.delay(time, function()
		trail.Enabled = false
		ball.Transparency = 1
		local boom = trail:Clone()
		boom.Rate = 0
		boom.Speed = NumberRange.new(size * 3, size * 7)
		boom.SpreadAngle = Vector2.new(180, 180)
		boom.Size = NumberSequence.new(size * 1.6, 0)
		boom.Lifetime = NumberRange.new(0.4, 0.8)
		boom.Enabled = true
		boom.Parent = ball
		boom:Emit(60)
		Sfx.play("Esplosione", b, 1.5)
		Debris:AddItem(ball, 1.2)
	end)
end

local STORM = Color3.fromRGB(110, 200, 255)
local DARK = Color3.fromRGB(170, 110, 255)

local function clip26(set: Set, f: Instance)
	local spot = f:GetAttribute("Spot") :: Vector3
	local look = flat(f:GetAttribute("Look") :: Vector3)
	local young = dragon(f:FindFirstChild("Giovane"))
	local adultD = dragon(f:FindFirstChild("Adulto"))
	local rival = dragon(f:FindFirstChild("Rivale"))
	if not young or not adultD or not rival then
		return
	end
	local adultM, youngM, rivalM = adultD.model, young.model, rival.model
	local nSeg = (f:GetAttribute("Segs") or 0) :: number
	local segs = {}
	for k = 1, nSeg do
		table.insert(segs, { f:GetAttribute("Seg" .. k .. "A") :: Vector3, f:GetAttribute("Seg" .. k .. "B") :: Vector3 })
	end
	local fight = f:GetAttribute("Fight") :: Vector3
	local fightDir = flat(f:GetAttribute("FightDir") :: Vector3)
	local pre = { spot }
	for _, sg in segs do
		table.insert(pre, sg[1])
	end
	table.insert(pre, fight)
	preload(pre)
	local side = look:Cross(Vector3.yAxis)
	-- 1) il giovane davanti alle costole (dietro di lui), il giocatore accanto; la camera davanti
	local ys = sizeOf(youngM)
	local yBase = groundAt(spot) + Vector3.new(0, ys.Y / 2, 0)
	youngM:PivotTo(CFrame.lookAt(yBase, yBase + look))
	loop(young, "Idle")
	local b = body()
	local feet = groundAt(spot - side * (ys.X * 0.6 + 4) - look * 4)
	if b then
		b.model:PivotTo(CFrame.lookAt(feet + Vector3.new(0, 3, 0), feet + Vector3.new(0, 3, 0) + look))
	end
	fadeTo(set, 0, 0.25)
	beat(2.0, function(u)
		pose(b, 10, 0)
		local c = yBase + Vector3.new(0, ys.Y * 0.1, 0)
		set.cam = CFrame.lookAt(c + look * (ys.Z * 1.6 - u * 3) + side * ys.X * 0.7 + Vector3.new(0, ys.Y * 0.3, 0), c)
		set.fov = 60
	end)
	-- 2) l'evoluzione si carica: luce che cresce, scintille a spirale, scossa
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.Color = STORM
	orb.Transparency = 0.6
	orb.Anchored, orb.CanCollide, orb.CanQuery = true, false, false
	orb.Size = Vector3.one
	orb.CFrame = CFrame.new(yBase)
	orb.Parent = workspace
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(STORM, Color3.new(1, 1, 1))
	sparks.LightEmission = 1
	sparks.Rate = 160
	sparks.Speed = NumberRange.new(-14, -6) -- verso il centro
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.5, 0.9)
	sparks.Size = NumberSequence.new(1.2, 0)
	sparks.Parent = orb
	local glow = Instance.new("PointLight")
	glow.Color = STORM
	glow.Range = 40
	glow.Parent = orb
	gesture(young, "Roar")
	Sfx.play("Ruggito", yBase, 1.2)
	beat(2.0, function(u)
		pose(b, 40 * u, 0)
		local r = ys.Z * (0.3 + 1.1 * u)
		orb.Size = Vector3.one * r
		orb.Transparency = 0.75 - 0.35 * u
		glow.Brightness = 1 + 6 * u
		set.shake = 0.3 + 1.2 * u
		local c = yBase
		set.cam = CFrame.lookAt(c + look * (ys.Z * 1.4 + u * 6) + side * ys.X * 0.5 + Vector3.new(0, ys.Y * 0.2, 0), c)
		set.fov = 60 + 8 * u
	end)
	-- 3) lampo: al posto del giovane c'e' l'adulto, che ruggisce (camera bassa)
	flash(set, Color3.fromRGB(220, 245, 255), 1.4)
	Sfx.play("Fulmine", yBase, 2.5)
	youngM:PivotTo(CFrame.new(0, -2000, 0))
	orb:Destroy()
	local as = sizeOf(adultM)
	local aBase = groundAt(spot) + Vector3.new(0, as.Y / 2, 0)
	adultM:PivotTo(CFrame.lookAt(aBase, aBase + look))
	loop(adultD, "Idle")
	local roar = gesture(adultD, "Roar")
	task.delay(0.5, function()
		Sfx.play("Ruggito", aBase, 3)
		set.shake = 2
	end)
	beat(math.max(roar * 0.85, 2.0), function(u)
		pose(b, 120, 5, 8)
		local c = aBase + Vector3.new(0, as.Y * 0.2, 0)
		set.cam = CFrame.lookAt(c + look * (as.Z * 0.95 + u * 10) + side * as.X * 0.25 - Vector3.new(0, as.Y * 0.35, 0), c + Vector3.new(0, as.Y * 0.25, 0))
		set.fov = 72
	end)
	-- 4) in groppa: il giocatore sul collo, il drago spicca il volo
	flash(set, Color3.new(1, 1, 1), 0.4)
	local function ride()
		if b then
			local seat = seatOf(adultM)
			b.model:PivotTo(seat * CFrame.new(0, 2.1, 0))
			sit(b, 0)
		end
	end
	ride()
	local takeoff = gesture(adultD, "Takeoff")
	loop(adultD, "Climb")
	beat(math.max(takeoff, 1.4), function(u)
		local k = smooth(u)
		local p = aBase + Vector3.new(0, 40 * k, 0) + look * 20 * k
		adultM:PivotTo(CFrame.lookAt(p, p + look) * CFrame.Angles(math.rad(18 * math.sin(math.pi * u)), 0, 0))
		ride()
		set.cam = CFrame.lookAt(p - look * as.Z * 1.1 + side * as.X * 0.6 - Vector3.new(0, 8 - 14 * k, 0), p)
		set.fov = 74
		set.shake = 0.8 * (1 - u)
	end)
	-- 5) i posti piu' belli: un tratto per posto, tagli col lampo; il drago si inclina nelle curve
	for k, sg in segs do
		if k == #segs then
			break -- l'ultimo e' l'arrivo al duello
		end
		local a, c = sg[1], sg[2]
		local dir = (c - a).Unit
		local sideways = dir:Cross(Vector3.yAxis).Unit
		flash(set, Color3.new(1, 1, 1), 0.25)
		loop(adultD, if k % 2 == 1 then "BankL" else "BankR")
		local smoothCam: CFrame? = nil
		beat(1.9, function(u)
			-- una S leggera: curva a sinistra o a destra (bank)
			local sway = math.sin(u * math.pi) * 35 * (if k % 2 == 1 then -1 else 1)
			local p = a:Lerp(c, u) + sideways * sway
			local q = a:Lerp(c, math.min(1, u + 0.02)) + sideways * math.sin(math.min(1, u + 0.02) * math.pi) * 35 * (if k % 2 == 1 then -1 else 1)
			local fwd = if (q - p).Magnitude > 0.01 then (q - p).Unit else dir
			local roll = math.cos(u * math.pi) * 0.45 * (if k % 2 == 1 then 1 else -1)
			adultM:PivotTo(CFrame.lookAt(p, p + fwd) * CFrame.Angles(0, 0, roll))
			ride()
			local want = CFrame.lookAt(p - fwd * as.Z * 0.95 + Vector3.new(0, as.Y * 0.55, 0) + sideways * 6, p + fwd * 40)
			smoothCam = if smoothCam then CFrame.new(want.Position) * (smoothCam :: CFrame).Rotation:Lerp(want.Rotation, 0.25) else want
			set.cam = smoothCam :: CFrame
			set.fov = 80
		end)
	end
	-- 6) tra le isole della vetta: arriva il rivale
	local last = segs[#segs]
	local a6, c6 = if last then last[1] else fight - fightDir * 300, fight
	local rs = sizeOf(rivalM)
	local across0 = fightDir:Cross(Vector3.yAxis).Unit
	local rivalAt = fight + across0 * (rs.Z * 1.3 + 36) + fightDir * 30
	local rivalFrom = rivalAt + fightDir * 260 + Vector3.new(0, 90, 0)
	flash(set, Color3.new(1, 1, 1), 0.25)
	loop(adultD, "Fly")
	loop(rival, "Fly")
	beat(2.2, function(u)
		local p = a6:Lerp(c6, smooth(u))
		local fwd = (c6 - a6).Unit
		adultM:PivotTo(CFrame.lookAt(p, p + fwd))
		ride()
		local rp = rivalFrom:Lerp(rivalAt, smooth(u))
		rivalM:PivotTo(CFrame.lookAt(rp, rp - fightDir))
		set.cam = CFrame.lookAt(p - fwd * as.Z * 1.0 + Vector3.new(0, as.Y * 0.5, 0), rp:Lerp(p, 0.3))
		set.fov = 78
	end)
	-- 7) il duello: entrambi librati, il rivale soffia, schivata, tre colpi del tuo drago
	loop(adultD, "Hover")
	loop(rival, "Hover")
	local myAt = c6
	local function face()
		adultM:PivotTo(CFrame.lookAt(myAt, Vector3.new(rivalAt.X, myAt.Y, rivalAt.Z)))
		rivalM:PivotTo(CFrame.lookAt(rivalAt, Vector3.new(myAt.X, rivalAt.Y, myAt.Z)))
		ride()
	end
	face()
	local across = (rivalAt - myAt).Unit:Cross(Vector3.yAxis).Unit
	-- dalla parte della valle, vicina: i due draghi riempiono l'inquadratura, dietro la vetta
	-- distanza perche' entrino tutti e due (campo 70 gradi: meta' larghezza = 0.7 x distanza)
	local camDist = ((rivalAt - myAt).Magnitude * 0.5 + rs.Z * 0.7) / 0.62
	local camSide = myAt:Lerp(rivalAt, 0.5) - fightDir * camDist + Vector3.new(0, -8, 0)
	local _ = across
	gesture(rival, "Roar")
	Sfx.play("Ruggito", rivalAt, 3)
	beat(1.2, function(u)
		face()
		set.cam = CFrame.lookAt(camSide, myAt:Lerp(rivalAt, 0.5))
		set.fov = 70
		set.shake = 0.6
	end)
	-- il rivale soffia: il tuo drago scarta di lato (schivata) e la palla passa
	gesture(rival, "Breath")
	local dodgeFrom = myAt
	shot(mouthOf(rivalM), myAt + Vector3.new(0, 4, 0), DARK, 0.7, 6)
	beat(0.9, function(u)
		local k = math.sin(math.pi * math.clamp((u - 0.25) / 0.6, 0, 1))
		myAt = dodgeFrom + across * 26 * k + Vector3.new(0, 10 * k, 0)
		face()
		adultM:PivotTo(adultM:GetPivot() * CFrame.Angles(0, 0, -k * 1.2))
		ride()
		set.cam = CFrame.lookAt(camSide, dodgeFrom:Lerp(rivalAt, 0.5))
	end)
	myAt = dodgeFrom
	-- tre colpi: gli ultimi due lo colpiscono, il terzo e' il piu' grande
	for k = 1, 3 do
		gesture(adultD, if k == 3 then "Breath" else "Bite")
		local big = k == 3
		task.delay(0.25, function()
			shot(mouthOf(adultM), rivalAt + Vector3.new(0, rs.Y * 0.1, 0), STORM, 0.45, if big then 9 else 5)
		end)
		task.delay(0.7, function()
			gesture(rival, "Hit")
			set.shake = if big then 2.5 else 1
			if big then
				flash(set, STORM, 0.8)
			end
		end)
		beat(if big then 1.0 else 0.75, function(u)
			face()
			local behind = myAt - (rivalAt - myAt).Unit * (as.Z * 0.9) + Vector3.new(0, as.Y * 0.6, 0) + across * 8
			set.cam = CFrame.lookAt(if k == 2 then camSide else behind, rivalAt)
			set.fov = if big then 64 else 72
		end)
	end
	-- il rivale precipita, il tuo drago ruggisce vittorioso
	loop(rival, "Dive")
	local fallFrom = rivalAt
	local winRoar = gesture(adultD, "Roar")
	task.delay(0.4, function()
		Sfx.play("Ruggito", myAt, 3)
	end)
	beat(math.max(winRoar, 2.4), function(u)
		local rp = fallFrom + Vector3.new(0, -260 * u * u, 0) + fightDir * 40 * u
		rivalM:PivotTo(CFrame.lookAt(rp, rp - fightDir) * CFrame.Angles(math.rad(-50 * u), 0, math.rad(200 * u)))
		adultM:PivotTo(CFrame.lookAt(myAt, Vector3.new(rivalAt.X, myAt.Y, rivalAt.Z)))
		ride()
		-- la camera gira attorno a te e al tuo drago (sfondo: le isole e la vetta)
		local ang = 0.6 + u * 1.2
		local around = CFrame.Angles(0, ang, 0) * (-(rivalAt - myAt).Unit)
		set.cam = CFrame.lookAt(myAt + around * (as.Z * 1.3) + Vector3.new(0, as.Y * 0.35, 0), myAt + Vector3.new(0, as.Y * 0.15, 0))
		set.fov = 70
	end)
	fadeTo(set, 1, 0.3)
	task.wait(0.35)
	if b then
		b.model:Destroy()
	end
end

------------------------------------------------------------------------------------------

local SCENES = { clip21 = clip21, clip22 = clip22, clip23 = clip23, clip24 = clip24, clip25 = clip25, clip26 = clip26 }

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
