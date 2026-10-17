--!strict
-- Schiusa dell'uovo (Mirko 16/10): sequenza di ~5 s nel mondo 3D, solo sul client e solo grafica
-- (il drago e' gia' stato deciso e salvato dal server: qui si guarda la differenza in DragonData,
-- client/DragonReveal). Passi:
--   0.0  l'uovo VERO dell'elemento (ReplicatedStorage.Previews.Eggs, coi suoi effetti di
--        EffettiUova) arriva in primo piano girando, illuminato da sinistra in alto
--   1.0  oscilla e trema sempre di piu', la luce dell'elemento cresce tra le scaglie (guscio
--        luminoso che si accende), energia e particelle girano attorno
--   3.3  si rompe: frammenti che volano, lampo e impulso di luce, effetto d'impatto dell'elemento
--   3.5  compare il drago 3D (stesso modello del menu), poi nome, elemento, rarita' e CONTINUE
-- Effetti diversi per elemento (Roccia polvere e schegge, Gelo brina e ghiaccio, Tempesta
-- fulmini azzurri, Fulmine scariche viola, Cosmico energia in orbita e distorsione, Eclissi
-- corona, Gas vapori ciano-fucsia, Ossa polvere e frammenti d'osso).
-- La scena sta in alto nel cielo sopra il giocatore (niente terreno o alberi davanti), la
-- telecamera e i comandi tornano com'erano alla fine e tutto quello che e' stato creato sparisce.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local Names = require(Shared:WaitForChild("Names"))
local Ui = require(Shared:WaitForChild("UiView"))
local UiKit = require(script.Parent.UiKit)
local Theme = require(script.Parent.Theme)
local Sfx = require(script.Parent.Sfx)
local MeshFX = require(script.Parent.MeshFX)
local Fondali = require(Shared:WaitForChild("Fondali"))
local player = Players.LocalPlayer

local EggHatch = {}
local busy = false

type Look = { color: Color3, glow: Color3, dust: ColorSequence?, sparkle: ColorSequence?, bolts: Color3?, orbit: boolean?, corona: boolean?, bones: boolean?, sound: string }
local LOOKS: { [string]: Look } = {
	Roccia = { color = Color3.fromRGB(120, 98, 78), glow = Color3.fromRGB(255, 150, 70), dust = ColorSequence.new(Color3.fromRGB(150, 128, 104), Color3.fromRGB(90, 76, 62)), sound = "Roccia" },
	Gelo = { color = Color3.fromRGB(170, 220, 255), glow = Color3.fromRGB(150, 225, 255), dust = ColorSequence.new(Color3.fromRGB(235, 248, 255), Color3.fromRGB(170, 220, 255)), sparkle = ColorSequence.new(Color3.fromRGB(200, 240, 255)), sound = "CristalloGelo" },
	Tempesta = { color = Color3.fromRGB(70, 110, 160), glow = Color3.fromRGB(120, 205, 255), bolts = Color3.fromRGB(120, 205, 255), sparkle = ColorSequence.new(Color3.fromRGB(150, 220, 255)), sound = "Fulmine" },
	Fulmine = { color = Color3.fromRGB(40, 28, 60), glow = Color3.fromRGB(175, 95, 255), bolts = Color3.fromRGB(175, 95, 255), sparkle = ColorSequence.new(Color3.fromRGB(190, 120, 255)), sound = "Fulmine" },
	Cosmico = { color = Color3.fromRGB(60, 40, 110), glow = Color3.fromRGB(150, 120, 255), orbit = true, sparkle = ColorSequence.new(Color3.fromRGB(140, 170, 255), Color3.fromRGB(230, 140, 255)), sound = "Stelle" },
	Eclissi = { color = Color3.fromRGB(40, 30, 30), glow = Color3.fromRGB(255, 170, 60), corona = true, sparkle = ColorSequence.new(Color3.fromRGB(255, 200, 110)), sound = "ScoppioFuoco" },
	Gas = { color = Color3.fromRGB(70, 120, 110), glow = Color3.fromRGB(90, 255, 220), dust = ColorSequence.new(Color3.fromRGB(80, 240, 230), Color3.fromRGB(240, 90, 220)), sound = "SoffioGas" },
	Ossa = { color = Color3.fromRGB(225, 214, 190), glow = Color3.fromRGB(255, 240, 200), dust = ColorSequence.new(Color3.fromRGB(214, 200, 170), Color3.fromRGB(160, 146, 120)), bones = true, sound = "Ossa" },
}

local function preview(kind: string, element: string): Model?
	local f = RS:FindFirstChild("Previews")
	local sub = f and f:FindFirstChild(kind)
	local m = sub and sub:FindFirstChild(element)
	return if m and m:IsA("Model") then m else nil
end

local function part(parent: Instance, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, transparency: number?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function emitter(parent: Instance, texture: string, color: ColorSequence, size: NumberSequence, life: number, speed: number, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = color
	e.Size = size
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Rate = rate
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 0.6
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = parent
	return e
end

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- fulmine: segmenti neon a zig-zag tra due punti, durano un attimo
local function bolt(parent: Instance, from: Vector3, to: Vector3, color: Color3)
	local points = { from }
	local n = 5
	for i = 1, n - 1 do
		local p = from:Lerp(to, i / n) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.9
		table.insert(points, p)
	end
	table.insert(points, to)
	local parts = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		table.insert(parts, part(parent, Enum.PartType.Block, Vector3.new(0.07, 0.07, len), CFrame.lookAt((a + b) / 2, b), color, Enum.Material.Neon, 0.05))
	end
	task.delay(0.09, function()
		for _, p in parts do
			p:Destroy()
		end
	end)
end

-- fulmine che cade dal cielo (Mirko 17/10: "migliora i Vfx magari aggiungendo fulmini"): piu'
-- spesso, a zig-zag ampio, con due rami e un lampo di luce dove colpisce
local function strike(parent: Instance, from: Vector3, to: Vector3, color: Color3)
	local parts = {}
	local function line(a: Vector3, b: Vector3, n: number, jitter: number, width: number)
		local prev = a
		for i = 1, n do
			local p = if i == n then b else a:Lerp(b, i / n) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * jitter
			local len = (p - prev).Magnitude
			table.insert(parts, part(parent, Enum.PartType.Block, Vector3.new(width, width, len), CFrame.lookAt((prev + p) / 2, p), color, Enum.Material.Neon, 0))
			prev = p
		end
	end
	line(from, to, 9, 3.2, 0.22)
	for _ = 1, 2 do
		local s = from:Lerp(to, 0.3 + math.random() * 0.4)
		local e = s + Vector3.new(math.random() - 0.5, -0.6, math.random() - 0.5) * 9
		line(s, e, 4, 1.6, 0.1)
	end
	local flashAt = part(parent, Enum.PartType.Ball, Vector3.one * 0.2, CFrame.new(to), color, Enum.Material.Neon, 1)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = 8
	l.Range = 26
	l.Parent = flashAt
	table.insert(parts, flashAt)
	task.delay(0.14, function()
		for _, p in parts do
			p:Destroy()
		end
	end)
end

-- FONDALE 3D (Mirko 17/10): prima un'immagine della valle su un pannello, storta rispetto alla
-- camera, con tre raggi di luce verticali ("strisce bruttissime"). Ora un posto fatto apposta per
-- l'elemento (shared/Fondali: cava, ghiacciaio, valle dei gas, costole del drago gigante...) con
-- luce di riempimento del colore dell'elemento e scintille che salgono piano davanti
local function backdrop(parent: Instance, stage: CFrame, element: string, glow: Color3)
	Fondali.get(element, parent, stage * CFrame.new(0, -2.2, 0), 1)
	local fill = part(parent, Enum.PartType.Ball, Vector3.one * 0.2, stage * CFrame.new(0, 12, 6), Color3.new(), Enum.Material.SmoothPlastic, 1)
	local l = Instance.new("PointLight")
	l.Color = glow:Lerp(Color3.new(1, 1, 1), 0.6)
	l.Brightness = 1.2
	l.Range = 60
	l.Parent = fill
	local field = part(parent, Enum.PartType.Block, Vector3.new(40, 1, 14), stage * CFrame.new(0, -3, 14), Color3.new(), Enum.Material.SmoothPlastic, 1)
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = SPARK
	motes.Color = ColorSequence.new(glow, Color3.new(1, 1, 1))
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.22), NumberSequenceKeypoint.new(1, 0) })
	motes.Lifetime = NumberRange.new(4, 7)
	motes.Speed = NumberRange.new(1, 3)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.SpreadAngle = Vector2.new(25, 25)
	motes.Rate = 26
	motes.LightEmission = 1
	motes.Acceleration = Vector3.new(0, 0.6, 0)
	motes.Parent = field
end

-- schermate del gioco da spegnere durante la sequenza (si riaccendono alla fine)
local HIDE = { "MainMenu", "CombatHUD", "MobileControls", "MontaDrago", "Montepremi", "AnnuncioEvento", "SuggerimentiTutorial", "MirinoPiccozza", "MirinoMonta", "BussolaCasa", "AdminButtons", "Teletrasporto", "NomeZona" }

-- d = il drago appena nato (dati di DragonData); onDone a sequenza chiusa
function EggHatch.play(d: any, onDone: () -> ())
	if busy then
		onDone()
		return
	end
	busy = true
	local element = tostring(d.element)
	local el = DragonConfig.element(element)
	local look = LOOKS[element] or { color = if el then el.color else Color3.new(1, 1, 1), glow = if el then el.glow else UiKit.ACCENT, sparkle = ColorSequence.new(UiKit.ACCENT), sound = "Stelle" }
	local glowColor = look.glow
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	local folder = Instance.new("Folder")
	folder.Name = "SchiusaUovo"
	folder.Parent = cam
	local pg = player.PlayerGui
	player:SetAttribute("SchiusaInCorso", true)
	local hidden: { ScreenGui } = {}
	for _, n in HIDE do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	local menu = pg:FindFirstChild("MainMenu")
	if menu then
		menu:SetAttribute("MenuOpen", false)
	end
	local controls: any = nil
	pcall(function()
		controls = (require :: any)(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 2)):GetControls()
		controls:Disable()
	end)
	local oldType, oldCF, oldFov = cam.CameraType, cam.CFrame, cam.FieldOfView
	local conns: { RBXScriptConnection } = {}
	local finished = false

	-- SCENA nel cielo sopra il giocatore (girata come la telecamera di adesso)
	local base = (if root then root.Position else cam.CFrame.Position) + Vector3.new(0, 2600, 0)
	local yaw = math.atan2(-cam.CFrame.LookVector.X, -cam.CFrame.LookVector.Z)
	local stage = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local front = stage.LookVector -- la telecamera sta davanti, l'uovo guarda verso di lei
	local center = stage.Position
	-- fondale dell'elemento e piedistallo con l'anello
	backdrop(folder, stage, element, glowColor)
	part(folder, Enum.PartType.Cylinder, Vector3.new(0.6, 7, 7), stage * CFrame.new(0, -1.9, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 38, 48), Enum.Material.Slate)
	local rune = part(folder, Enum.PartType.Cylinder, Vector3.new(0.65, 6, 6), stage * CFrame.new(0, -1.86, 0) * CFrame.Angles(0, 0, math.pi / 2), glowColor, Enum.Material.Neon, 0.6)
	part(folder, Enum.PartType.Cylinder, Vector3.new(0.7, 5.4, 5.4), stage * CFrame.new(0, -1.84, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(34, 32, 42), Enum.Material.Slate)
	-- luci: principale in alto a sinistra (fredda) e contro-luce dell'elemento
	local keyHolder = part(folder, Enum.PartType.Ball, Vector3.one * 0.2, CFrame.new(center + front * 6 + stage.RightVector * -5 + Vector3.new(0, 6, 0)), Color3.new(), Enum.Material.SmoothPlastic, 1)
	local key = Instance.new("PointLight")
	key.Range = 22
	key.Brightness = 3
	key.Color = Color3.fromRGB(255, 240, 220)
	key.Shadows = true
	key.Parent = keyHolder
	local core = part(folder, Enum.PartType.Ball, Vector3.one * 0.2, CFrame.new(center), Color3.new(), Enum.Material.SmoothPlastic, 1)
	local inner = Instance.new("PointLight")
	inner.Range = 6
	inner.Brightness = 0
	inner.Color = glowColor
	inner.Parent = core

	-- l'UOVO vero dell'elemento
	local eggTemplate = preview("Eggs", element)
	local egg: Model
	if eggTemplate then
		egg = eggTemplate:Clone()
	else
		egg = Instance.new("Model")
		local p = part(egg, Enum.PartType.Ball, Vector3.new(2.2, 2.8, 2.2), CFrame.new(), look.color, Enum.Material.SmoothPlastic)
		egg.PrimaryPart = p
	end
	for _, x in egg:GetDescendants() do
		if x:IsA("LuaSourceContainer") then
			x:Destroy()
		elseif x:IsA("BasePart") then
			x.Anchored = true
			x.CanCollide = false
			x.CanQuery = false
		end
	end
	egg.Parent = folder
	local eggPivot0 = egg:GetPivot()
	local cf0, size0 = egg:GetBoundingBox()
	local offset = eggPivot0:ToObjectSpace(CFrame.new(cf0.Position)) -- dal pivot al centro
	local eggH = math.max(size0.Y, 1)
	local function placeEgg(cf: CFrame)
		egg:PivotTo(cf * offset:Inverse())
	end
	-- guscio di luce tra le scaglie: copie appena piu' grandi in Neon che si accendono
	local shells: { BasePart } = {}
	for _, x in egg:GetDescendants() do
		if x:IsA("BasePart") and x.Transparency < 0.9 then
			local s = x:Clone()
			for _, c in s:GetChildren() do
				c:Destroy()
			end
			s.Material = Enum.Material.Neon
			s.Color = glowColor
			s.Size = x.Size * 1.035
			s.Transparency = 1
			if s:IsA("MeshPart") then
				s.TextureID = ""
			end
			s.Parent = folder
			table.insert(shells, s)
		end
	end
	local effectRemove: (() -> ())? = nil
	pcall(function()
		local mod = RS:FindFirstChild("EffettiUova")
		if mod and mod:IsA("ModuleScript") then
			local Effetti = (require :: any)(mod)
			local ok, remove = pcall(Effetti.Applica, egg, element)
			if ok and type(remove) == "function" then
				effectRemove = remove
			end
		end
	end)

	-- particelle attorno (si accendono durante l'attesa)
	local aura = Instance.new("Attachment")
	aura.Parent = core
	local sparks = emitter(aura, SPARK, look.sparkle or ColorSequence.new(glowColor), NumberSequence.new(0.35, 0), 1.2, 3, 0)
	local dust = emitter(aura, SMOKE, look.dust or ColorSequence.new(glowColor), NumberSequence.new(0.6, 2.2), 1.6, 1.5, 0)
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.LightEmission = 0.1
	local orbiters: { Part } = {}
	if look.orbit then
		for i = 1, 3 do
			table.insert(orbiters, part(folder, Enum.PartType.Ball, Vector3.one * 0.35, CFrame.new(center), if i == 2 then Color3.fromRGB(230, 140, 255) else glowColor, Enum.Material.Neon))
		end
	end
	local corona: Part? = nil
	if look.corona then
		-- corona dell'eclisse: disco nero davanti a un anello di luce, dietro l'uovo
		local ring = part(folder, Enum.PartType.Cylinder, Vector3.new(0.1, 0.5, 0.5), stage * CFrame.new(0, 0.6, 2.4) * CFrame.Angles(0, math.pi / 2, 0), glowColor, Enum.Material.Neon, 0.1)
		part(folder, Enum.PartType.Cylinder, Vector3.new(0.12, 0.42, 0.42), stage * CFrame.new(0, 0.6, 2.25) * CFrame.Angles(0, math.pi / 2, 0), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		corona = ring
	end

	-- TELECAMERA
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 42
	local camDist = 8.5
	local function shot(dist: number, lift: number): CFrame
		return CFrame.lookAt(center + front * dist + Vector3.new(0, lift, 0) + stage.RightVector * -0.6, center + Vector3.new(0, 0.2, 0))
	end
	-- la telecamera si muove qui, DOPO gli altri script della camera (alcuni la spostano a ogni
	-- frame anche in Scriptable: la sequenza finiva inquadrata sul personaggio)
	local camFrom, camTo, camT0, camDur = shot(camDist + 3, 1.6), shot(camDist, 1.1), os.clock(), 1
	local function moveCam(to: CFrame, dur: number)
		camFrom, camTo, camT0, camDur = cam.CFrame, to, os.clock(), dur
	end
	RunService:BindToRenderStep("SchiusaCamera", Enum.RenderPriority.Camera.Value + 10, function()
		local a = math.clamp((os.clock() - camT0) / camDur, 0, 1)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = camFrom:Lerp(camTo, 1 - (1 - a) ^ 3)
	end)

	-- SCRITTE: in basso (il centro resta libero per l'uovo e il drago)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SchiusaTesti"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 61
	gui.ResetOnSpawn = false
	gui.Parent = pg
	local flash = Instance.new("Frame")
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.Parent = gui
	local head = UiKit.label(gui, "AN EGG IS HATCHING", "section", 26)
	head.TextXAlignment = Enum.TextXAlignment.Center
	head.TextColor3 = UiKit.ACCENT
	local title = UiKit.label(gui, "", "title", 46)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local sub = UiKit.label(gui, "", "name", 22)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	local badge = UiKit.label(gui, "SHINY", "button", 18)
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.TextColor3 = Color3.fromRGB(40, 24, 0)
	badge.BackgroundColor3 = UiKit.ACCENT
	badge.BackgroundTransparency = 0
	badge.Visible = false
	local go = Instance.new("TextButton")
	go.Parent = gui
	UiKit.button(go, "primary")
	go.Text = "CONTINUE"
	go.Visible = false
	Ui.viewportChanged(function(vp)
		if not gui.Parent then
			return
		end
		local logical = Ui.fitScale(gui, vp)
		local compact = logical.Y < 520
		local bottom = logical.Y - (if compact then 10 else 24)
		local bh = if compact then 40 else 50
		Ui.px(go, 0.5, 0, 0, bottom, if compact then 200 else 240, bh, 0.5, 1)
		Ui.px(sub, 0.5, 0, 0, bottom - bh - (if compact then 30 else 40), math.min(600, logical.X - 20), if compact then 24 else 30, 0.5, 0)
		Ui.px(title, 0.5, 0, 0, bottom - bh - (if compact then 70 else 92), math.min(700, logical.X - 20), if compact then 40 else 52, 0.5, 0)
		Ui.px(badge, 0.5, 0, 0, bottom - bh - (if compact then 98 else 128), 110, if compact then 24 else 30, 0.5, 0)
		Ui.px(head, 0.5, 0, 0, if compact then 10 else 24, 500, 26, 0.5, 0)
		title.TextSize = if compact then 34 else 46
		sub.TextSize = if compact then 17 else 22
	end)

	-- chiusura: tutto come prima, una volta sola
	local function finish()
		if finished then
			return
		end
		finished = true
		for _, c in conns do
			c:Disconnect()
		end
		RunService:UnbindFromRenderStep("SchiusaCamera")
		if effectRemove then
			pcall(effectRemove :: () -> ())
		end
		folder:Destroy()
		gui:Destroy()
		cam.CameraType = oldType
		cam.FieldOfView = oldFov
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
		cam.CFrame = oldCF
		if controls then
			pcall(function()
				controls:Enable()
			end)
		end
		for _, g in hidden do
			if g.Parent then
				g.Enabled = true
			end
		end
		player:SetAttribute("SchiusaInCorso", nil)
		busy = false
		onDone()
	end
	go.Activated:Connect(finish)
	-- morte o respawn durante la sequenza: si chiude subito
	table.insert(conns, player.CharacterAdded:Connect(finish))

	-- ANIMAZIONE
	local t0 = os.clock()
	local broken = false
	local dragon: Model? = nil
	local dragonBase = CFrame.new()
	local dragonScale = 1
	local dragonT = 0
	local fragments: { { p: BasePart, v: Vector3, w: Vector3 } } = {}
	local nextBolt = 0
	Sfx.play("CristalloScarica", nil, 0.8)
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		-- alcune schermate si riaccendono da sole (admin, combattimento): restano spente fino alla fine
		for _, n in HIDE do
			local g = pg:FindFirstChild(n)
			if g and g:IsA("ScreenGui") and g.Enabled then
				g.Enabled = false
				if not table.find(hidden, g) then
					table.insert(hidden, g)
				end
			end
		end
		-- 1) arrivo girando (0-1 s), 2) oscillazioni e tremori sempre piu' forti (1-3.3 s)
		if not broken then
			local arrive = math.clamp(t / 1, 0, 1)
			local e = 1 - (1 - arrive) ^ 3
			local spin = (1 - e) * math.pi * 2 + t * 0.25
			local build = math.clamp((t - 1) / 2.3, 0, 1)
			local wobble = math.sin(t * (6 + build * 14)) * (0.04 + build * 0.22)
			local shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * build * build * 0.12
			local cf = stage * CFrame.new(0, -0.4 + e * 0.6 + eggH * 0.0, 0) * CFrame.new(shake) * CFrame.Angles(0, spin, wobble) * CFrame.Angles(wobble * 0.6, 0, 0)
			placeEgg(cf)
			for _, s in shells do
				s.Transparency = 1 - build * 0.45 - (if build > 0.6 then (math.sin(t * 30) + 1) * 0.08 else 0)
			end
			-- i gusci seguono le loro parti
			local k = 0
			for _, x in egg:GetDescendants() do
				if x:IsA("BasePart") and x.Transparency < 0.9 then
					k += 1
					local s = shells[k]
					if s then
						s.CFrame = x.CFrame
					end
				end
			end
			inner.Brightness = build * 5
			inner.Range = 6 + build * 8
			rune.Transparency = 0.6 - build * 0.5
			sparks.Rate = build * 40
			dust.Rate = if look.dust then build * 18 else 0
			for i, o in orbiters do
				local a = t * (2 + build * 4) + i * math.pi * 2 / 3
				o.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * 1.8, math.sin(a * 0.7 + i) * 0.6, math.sin(a) * 1.8))
			end
			if corona then
				local c = corona :: Part
				local s = 0.5 + build * 3.6
				c.Size = Vector3.new(0.1, s, s)
			end
			-- scariche attorno all'uovo: per tutti gli elementi (del loro colore), piu' fitte per
			-- Tempesta e Fulmine; nell'ultimo tratto cadono anche dal cielo
			if build > 0.25 and t > nextBolt then
				nextBolt = t + (if look.bolts then 0.12 else 0.3) + math.random() * (0.25 - build * 0.15)
				local a = math.random() * math.pi * 2
				local from = center + Vector3.new(math.cos(a) * 2.4, math.random() * 2 - 0.4, math.sin(a) * 2.4)
				bolt(folder, from, center + Vector3.new(0, (math.random() - 0.5) * 1.2, 0), look.bolts or glowColor)
				if build > 0.75 and math.random() < 0.35 then
					local far = center + stage.RightVector * (math.random() - 0.5) * 24 + Vector3.new(0, 26, 0) + stage.LookVector * -(6 + math.random() * 10)
					strike(folder, far, center + stage.RightVector * (math.random() - 0.5) * 8 + Vector3.new(0, -2, 0) + stage.LookVector * -(3 + math.random() * 6), look.bolts or glowColor)
				end
			end
			if t > 2 and t - dt <= 2 then
				MeshFX.charge(element, center, front, 0.6)
			end
			-- 3) rottura
			if t >= 3.3 then
				broken = true
				Sfx.play(look.sound, nil, 1)
				Sfx.play("Esplosione", nil, 0.5)
				for _, x in egg:GetDescendants() do
					if x:IsA("BasePart") then
						x.Transparency = 1
					end
				end
				for _, s in shells do
					s:Destroy()
				end
				table.clear(shells)
				if effectRemove then
					pcall(effectRemove :: () -> ())
					effectRemove = nil
				end
				-- frammenti del guscio (schegge d'osso per Ossa)
				for i = 1, 16 do
					local dir = (Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5)).Unit
					local sz = if look.bones then Vector3.new(0.18, 0.18, 0.5 + math.random() * 0.4) else Vector3.new(0.35 + math.random() * 0.3, 0.12, 0.3 + math.random() * 0.3)
					local p = part(folder, Enum.PartType.Block, sz, CFrame.new(center + dir * 0.8) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
						if look.bones then Color3.fromRGB(235, 226, 205) else look.color, if element == "Gelo" then Enum.Material.Ice else Enum.Material.Slate)
					table.insert(fragments, { p = p, v = dir * (9 + math.random() * 6) + Vector3.new(0, 4, 0), w = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14 })
					local _ = i
				end
				-- lampo e impulso di luce
				local pulse = part(folder, Enum.PartType.Ball, Vector3.one * 1, CFrame.new(center), glowColor, Enum.Material.Neon, 0.2)
				TweenService:Create(pulse, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = Vector3.one * 9, Transparency = 1 }):Play()
				inner.Brightness = 18
				inner.Range = 22
				TweenService:Create(inner, TweenInfo.new(0.9), { Brightness = 2, Range = 10 }):Play()
				flash.BackgroundTransparency = 0.35
				TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
				sparks:Emit(60)
				-- fulmini dal cielo sull'uovo, onda d'urto sul piedistallo e colonna di scintille
				for k = 1, 3 do
					task.delay((k - 1) * 0.07, function()
						local top = center + stage.RightVector * (math.random() - 0.5) * 10 + Vector3.new(0, 30, 0) + stage.LookVector * -4
						strike(folder, top, center, look.bolts or glowColor)
					end)
				end
				local ring = part(folder, Enum.PartType.Cylinder, Vector3.new(0.15, 2, 2), CFrame.new(center - Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, 0, math.pi / 2), glowColor, Enum.Material.Neon, 0.1)
				TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, 30, 30), Transparency = 1 }):Play()
				local column = Instance.new("ParticleEmitter")
				column.Texture = SPARK
				column.Color = ColorSequence.new(Color3.new(1, 1, 1), glowColor)
				column.Size = NumberSequence.new(0.5, 0)
				column.Lifetime = NumberRange.new(0.8, 1.4)
				column.Speed = NumberRange.new(12, 24)
				column.SpreadAngle = Vector2.new(14, 14)
				column.EmissionDirection = Enum.NormalId.Top
				column.LightEmission = 1
				column.Rate = 0
				column.Acceleration = Vector3.new(0, -10, 0)
				column.Parent = aura
				column:Emit(90)
				if look.dust then
					dust:Emit(30)
				end
				sparks.Rate, dust.Rate = 6, 0
				MeshFX.impact(element, center, -front, 0.45)
				if element == "Cosmico" then
					-- distorsione: bolla ForceField che si allarga
					local bubble = part(folder, Enum.PartType.Ball, Vector3.one * 1, CFrame.new(center), glowColor, Enum.Material.ForceField, 0)
					TweenService:Create(bubble, TweenInfo.new(0.8), { Size = Vector3.one * 12, Transparency = 1 }):Play()
				end
				-- 4) il drago
				local tmpl = preview("Dragons", element)
				if tmpl then
					local m = tmpl:Clone()
					for _, x in m:GetDescendants() do
						if x:IsA("LuaSourceContainer") then
							x:Destroy()
						elseif x:IsA("BasePart") then
							x.Anchored = true
							x.CanCollide = false
						end
					end
					m.Parent = folder
					-- il drago guarda la telecamera di tre quarti: il davanti e' verso la testa (ossa del
					-- collo, come in DragonUI), non sempre -LookVector
					local pivot = m:GetPivot()
					local bcf = m:GetBoundingBox()
					local head: Vector3? = nil
					local best = -1
					for _, b in m:GetDescendants() do
						if b:IsA("Bone") and b:GetAttribute("Ruolo") == "neck" then
							local i = (b:GetAttribute("Indice") or 0) :: number
							if i > best then
								best, head = i, b.WorldPosition
							end
						end
					end
					local headDir = -pivot.LookVector
					if head then
						local flat = Vector3.new((head :: Vector3).X - bcf.Position.X, 0, (head :: Vector3).Z - bcf.Position.Z)
						if flat.Magnitude > 0.1 then
							headDir = flat.Unit
						end
					end
					-- testa in pivot-spazio, poi ruotata verso la telecamera (un po' di lato)
					local localHead = pivot:VectorToObjectSpace(Vector3.new(headDir.X, 0, headDir.Z))
					local want = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-35)) * front)
					local yawWant = math.atan2(want.X, want.Z)
					local yawLocal = math.atan2(localHead.X, localHead.Z)
					dragonBase = CFrame.new(center) * CFrame.Angles(0, yawWant - yawLocal, 0)
					dragonScale = m:GetScale()
					m:ScaleTo(dragonScale * 0.2)
					dragon = m
				end
				Sfx.play("Ruggito", nil, 1)
				moveCam(CFrame.lookAt(center + front * 11 + Vector3.new(0, 2.6, 0) + stage.RightVector * -0.6, center + Vector3.new(0, 1.3, 0)), 0.8)
			end
		else
			-- frammenti: volano e cadono
			for _, f in fragments do
				f.v += Vector3.new(0, -30, 0) * dt
				f.p.CFrame = (f.p.CFrame + f.v * dt) * CFrame.Angles(f.w.X * dt, f.w.Y * dt, f.w.Z * dt)
				f.p.Transparency = math.min(1, f.p.Transparency + dt * 0.5)
			end
			if dragon then
				dragonT += dt
				local m = dragon :: Model
				local k = math.clamp(dragonT / 0.55, 0, 1)
				-- crescita con un piccolo rimbalzo, poi gira piano
				local s = 0.2 + 0.8 * (1 + 2.70158 * (k - 1) ^ 3 + 1.70158 * (k - 1) ^ 2)
				m:ScaleTo(dragonScale * math.max(0.05, s))
				m:PivotTo(dragonBase * CFrame.Angles(0, math.sin(dragonT * 0.6) * 0.5, 0))
				-- appoggiato sul piedistallo, centrato
				local bcf, bsize = m:GetBoundingBox()
				local want = Vector3.new(center.X, center.Y - 1.55 + bsize.Y / 2, center.Z)
				m:PivotTo(m:GetPivot() + (want - bcf.Position))
			end
			-- 5) nome, elemento, rarita' e CONTINUE
			if t >= 4.2 and not go.Visible then
				local name = if type(d.name) == "string" and d.name ~= "" then d.name else Names.dragon(element)
				local rarity = Theme.RARITY[d.rarity]
				head.Text = "NEW DRAGON"
				title.Text = string.upper(name)
				sub.Text = string.upper(Names.t(d.rarity) .. "  ·  " .. Names.t(element))
				sub.TextColor3 = if rarity then rarity[1] else UiKit.MUTED
				badge.Visible = d.shiny == true
				go.Visible = true
				title.TextTransparency = 1
				TweenService:Create(title, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
				if d.shiny then
					Sfx.play("Stelle", nil, 1)
				end
			end
			-- chiusura da sola dopo un po'
			if t > 12 then
				finish()
			end
		end
	end))
end

return EggHatch
