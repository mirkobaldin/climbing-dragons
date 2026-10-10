--!strict
-- Trailer (meno di 20 secondi) e clip per TikTok, girati sul client dopo i comandi admin
-- (F2): trailer, clip1, clip2, clip3. Le scritte stanno nella fascia centrale (38% della
-- larghezza): tagliando il video in 3:4 per TikTok restano intere. Niente bande nere.
-- Il server (TrailerProps) prepara i draghi di scena (cartella Workspace.TrailerProps con
-- l'attributo Take: si aspetta quella giusta, prima alla seconda ripresa si prendeva la vecchia
-- che stava sparendo) e i punti della mappa negli attributi della cartella.
--   trailer  montagna, drago davanti alla Grande Grotta, grotta, gas, arena, evoluzione, titolo
--   clip1    RAGE: "I was 2 meters from the top..." -> caduta -> "-47 MINUTES" -> "would you
--            try again? YES or NO"
--   clip2    EVOLUZIONE: "don't skip: watch what happens at level 100" -> cresce, lampo,
--            adulto -> "which dragon should evolve next?"
--   clip3    GRANDE GROTTA: "this mountain is hollow." -> l'apertura -> dentro -> "part 2 at
--            1000 likes"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local PetAnimator = require(script.Parent.PetAnimator)
local KfsPlayer = require(script.Parent.KfsPlayer)
local DragonVFX = require(script.Parent.DragonVFX)
local GymAnim = require(script.Parent.GymAnim)
local ClimbConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClimbConfig"))

local player = Players.LocalPlayer

local Trailer = {}

local ORANGE = Color3.fromRGB(255, 170, 70)
local ICE = Color3.fromRGB(130, 210, 255)
local RED = Color3.fromRGB(255, 70, 60)
local GOLD = Color3.fromRGB(255, 220, 120)

-- ora del giorno nelle clip: se Mirko l'ha fissata col comando admin "time" (attributo
-- FixedTime) resta quella
local function setClock(h: number)
	if type(workspace:GetAttribute("FixedTime")) ~= "number" then
		game:GetService("Lighting").ClockTime = h
	end
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.xAxis
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local function groundAt(p: Vector3): Vector3
	local hit = workspace:Raycast(p + Vector3.new(0, 200, 0), Vector3.new(0, -500, 0), terrainOnly)
	return if hit then hit.Position else p
end

------------------------------------------------------------------------------------------
-- Schermo: scritte al centro, dissolvenze, lampo, scossa

type Screen = { gui: ScreenGui, fade: Frame, flash: Frame, red: Frame, big: TextLabel, small: TextLabel, bottom: TextLabel }

local function screen(): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "Trailer"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200
	gui.ResetOnSpawn = false
	local function frame(color: Color3, transparency: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = 5
		f.Parent = gui
		return f
	end
	local fade = frame(Color3.new(0, 0, 0), 0)
	local flash = frame(Color3.new(1, 1, 1), 1)
	local red = frame(Color3.fromRGB(150, 0, 0), 1)
	local function label(y: number, h: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.38, h) -- fascia centrale: resta intera nel taglio 3:4
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextWrapped = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.TextStrokeTransparency = 1
		l.TextTransparency = 1
		l.ZIndex = 8
		l.Parent = gui
		return l
	end
	local s = { gui = gui, fade = fade, flash = flash, red = red, big = label(0.45, 0.12), small = label(0.2, 0.09), bottom = label(0.78, 0.08) }
	gui.Parent = player:WaitForChild("PlayerGui")
	return s
end

local function say(l: TextLabel, text: string, hold: number, color: Color3?)
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	local h = l.Size.Y.Scale
	l.Size = UDim2.fromScale(0.3, h)
	TweenService:Create(l, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0, TextStrokeTransparency = 0.15, Size = UDim2.fromScale(0.38, h) }):Play()
	task.delay(hold, function()
		if l.Text == text then
			TweenService:Create(l, TweenInfo.new(0.25), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function fadeTo(s: Screen, alpha: number, time: number)
	TweenService:Create(s.fade, TweenInfo.new(time), { BackgroundTransparency = 1 - alpha }):Play()
end

local function flash(s: Screen, frame: Frame?)
	local f = frame or s.flash
	f.BackgroundTransparency = 0
	TweenService:Create(f, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

local shake = 0

------------------------------------------------------------------------------------------
-- Draghi di scena

type Actor = { model: Model, tracks: any? }

local function actor(props: Instance?, name: string): Actor?
	-- i draghi arrivano dopo la cartella (streaming): si aspettano, se no alla seconda ripresa
	-- mancavano
	local m = props and props:WaitForChild(name, 8)
	if m and m:IsA("Model") then
		local t0 = os.clock()
		while not m:FindFirstChildWhichIsA("Bone", true) and os.clock() - t0 < 4 do
			task.wait(0.1)
		end
	end
	if not m or not m:IsA("Model") then
		return nil
	end
	local old = m:FindFirstChild("PetAnimationController")
	if old then
		old:Destroy()
	end
	-- niente contorno (il bagliore della rarita' sembrava la selezione di Studio)
	for _, d in m:GetDescendants() do
		if d:IsA("Highlight") then
			d:Destroy()
		end
	end
	return { model = m, tracks = PetAnimator.loadTracks(m) }
end

local function pose(a: Actor?, kind: string, speed: number?)
	if not a or not a.tracks then
		return
	end
	for name, track in a.tracks do
		track:AdjustWeight(if name == kind then 1 else 0.001, 0.2)
		track:AdjustSpeed(speed or 1)
	end
end

local function hide(a: Actor?)
	if a then
		a.model:PivotTo(CFrame.new(0, -500, 0))
	end
end

local function standAt(a: Actor?, p: Vector3, dir: Vector3)
	if not a then
		return
	end
	local _, size = a.model:GetBoundingBox()
	-- un poco sopra il terreno: nell'arena il pavimento del modello sta poco sopra (zampe dentro)
	local at = groundAt(p) + Vector3.new(0, size.Y / 2 + 1.5, 0)
	a.model:PivotTo(CFrame.lookAt(at, at + flat(dir)))
end

------------------------------------------------------------------------------------------
-- Riprese

-- preload = altri punti da caricare prima di iniziare (riprese lunghe che girano la mappa);
-- follow = il personaggio nascosto segue la camera (cosi' la mappa si carica dove guarda);
-- smooth = la camera insegue la posa con un ritardo morbido (niente scatti nelle curve)
type Shot = { dur: number, cam: (number) -> CFrame, update: ((number) -> ())?, start: (() -> ())?, at: Vector3?, preload: { Vector3 }?, follow: boolean?, smooth: number? }

-- sosia del giocatore per le clip, senza attrezzi in mano (si vedevano le piccozze)
local function cloneBody(): Model?
	local Cinematic = require(script.Parent.Cinematic)
	local body = Cinematic.kit.cloneActor()
	if body then
		for _, x in body:GetDescendants() do
			if x:IsA("Tool") then
				x:Destroy()
			end
		end
	end
	return body
end

-- piccozza da lanciare nelle clip: copia dei pezzi della Piccozza vera, se c'e'
local function sceneAxe(): Model
	local m = Instance.new("Model")
	m.Name = "PiccozzaScena"
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = (character and character:FindFirstChild(ClimbConfig.TOOL_NAME)) or (backpack and backpack:FindFirstChild(ClimbConfig.TOOL_NAME))
	for _, p in (if tool then tool:GetDescendants() else {}) :: { Instance } do
		if p:IsA("BasePart") and p.Name ~= "FakeHandle" then
			local c = p:Clone()
			for _, x in c:GetDescendants() do
				if x:IsA("JointInstance") or x:IsA("WeldConstraint") or x:IsA("LuaSourceContainer") or x:IsA("Sound") then
					x:Destroy()
				end
			end
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
			c.LocalTransparencyModifier = 0
			c.Parent = m
		end
	end
	if #m:GetChildren() == 0 then
		local shaft = Instance.new("Part")
		shaft.Name = "Handle"
		shaft.Size = Vector3.new(0.3, 3.4, 0.3)
		shaft.Color = Color3.fromRGB(90, 60, 40)
		shaft.Material = Enum.Material.Wood
		shaft.Anchored, shaft.CanCollide = true, false
		shaft.Parent = m
		local head = Instance.new("Part")
		head.Size = Vector3.new(0.3, 0.4, 2.2)
		head.CFrame = shaft.CFrame * CFrame.new(0, 1.6, 0.3)
		head.Color = Color3.fromRGB(190, 195, 205)
		head.Material = Enum.Material.Metal
		head.Anchored, head.CanCollide = true, false
		head.Parent = m
	end
	m.PrimaryPart = (m:FindFirstChild("Handle") or m:FindFirstChildWhichIsA("BasePart")) :: BasePart?
	return m
end

-- le due piccozze nelle mani del sosia (si chiama dopo aver messo le braccia in posa)
local function holdAxes(body: Model, axes: { Model })
	for i, a in axes do
		local hand = body:FindFirstChild(if i == 1 then "RightHand" else "LeftHand", true)
			or body:FindFirstChild(if i == 1 then "Right Arm" else "Left Arm", true)
		if hand and hand:IsA("BasePart") then
			local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.45, 0)
			a:PivotTo(grip * CFrame.Angles(-math.pi / 2, 0, 0))
		end
	end
end

-- la camera non entra mai nel terreno: se finisce dentro (voxel pieno) sale finche' e' fuori
local function solidAt(p: Vector3): boolean
	local region = Region3.new(p - Vector3.one * 2, p + Vector3.one * 2):ExpandToGrid(4)
	local ok, mats, occs = pcall(function()
		return workspace.Terrain:ReadVoxels(region, 4)
	end)
	if not ok then
		return false
	end
	local _ = mats
	return occs[1][1][1] > 0.3
end
local function keepOut(cf: CFrame): CFrame
	local p = cf.Position
	for _ = 1, 30 do
		if not solidAt(p) then
			break
		end
		p += Vector3.new(0, 4, 0)
	end
	return cf.Rotation + p
end

local function run(shots: { Shot }, s: Screen)
	local camera = workspace.CurrentCamera
	-- STREAMING: la mappa arriva solo attorno al personaggio. Prima la camera andava lontano e
	-- terreno e modelli si caricavano mentre passava (tutto a scatti, sfarfallio). Ora il tuo
	-- personaggio (nascosto, fermo) va dove gira ogni scena: si precarica tutto a schermo nero e
	-- durante il trailer il personaggio segue le scene.
	local me = player.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	local homeCf = me and me:GetPivot()
	local hiddenParts: { BasePart } = {}
	local hiddenBillboards: { BillboardGui } = {}
	local function hideAll(m: Instance?)
		if not m then
			return
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
				d.LocalTransparencyModifier = 1
				table.insert(hiddenParts, d)
			elseif d:IsA("BillboardGui") and d.Enabled then
				-- l'etichetta "Lv" del drago si vedeva anche col drago nascosto
				d.Enabled = false
				table.insert(hiddenBillboards, d)
			end
		end
	end
	hideAll(me)
	hideAll(workspace:FindFirstChild("Pets"))
	hideAll(workspace:FindFirstChild("GuideArrows")) -- le frecce del tutorial
	if myRoot then
		myRoot.Anchored = true
	end
	local function focus(at: Vector3?)
		if at and me and myRoot then
			me:PivotTo(CFrame.new(at + Vector3.new(0, 30, 0)))
		end
	end
	for _, shot in shots do
		for _, at in { shot.at :: Vector3?, table.unpack(shot.preload or {}) } do
			if at then
				focus(at)
				pcall(function()
					player:RequestStreamAroundAsync(at :: Vector3, 5)
				end)
			end
		end
	end
	-- un attimo in piu': il terreno lontano (biomi, cristalli) finisce di comparire; poi si torna
	-- alla prima ripresa e si aspetta che anche li' sia tutto caricato
	task.wait(2.5)
	if shots[1] and shots[1].at then
		focus(shots[1].at)
		pcall(function()
			player:RequestStreamAroundAsync(shots[1].at :: Vector3, 5)
		end)
		task.wait(1.5)
	end
	-- niente profondita' di campo e sfocature durante le riprese (il video usciva sfocato)
	local Lighting = game:GetService("Lighting")
	local blurred: { PostEffect } = {}
	for _, e in Lighting:GetChildren() do
		if (e:IsA("DepthOfFieldEffect") or e:IsA("BlurEffect")) and e.Enabled then
			e.Enabled = false
			table.insert(blurred, e)
		end
	end
	local current: Shot? = nil
	local t0 = 0
	local smoothCf: CFrame? = nil
	local conn = RunService.RenderStepped:Connect(function(dt)
		camera.CameraType = Enum.CameraType.Scriptable
		if current then
			local u = math.clamp((os.clock() - t0) / current.dur, 0, 1)
			if current.update then
				current.update(u)
			end
			local cf = keepOut(current.cam(u))
			if current.smooth then
				smoothCf = if smoothCf then (smoothCf :: CFrame):Lerp(cf, 1 - math.exp(-dt * (current.smooth :: number))) else cf
				cf = smoothCf :: CFrame
			else
				smoothCf = nil
			end
			if current.follow and me and myRoot then
				me:PivotTo(CFrame.new(cf.Position - Vector3.new(0, 20, 0)))
			end
			if shake > 0 then
				cf *= CFrame.Angles((math.random() - 0.5) * 0.05 * shake, (math.random() - 0.5) * 0.05 * shake, 0)
				shake = math.max(0, shake - dt * 2)
			end
			camera.CFrame = cf
		end
	end)
	fadeTo(s, 0, 0.3)
	for i, shot in shots do
		focus(shot.at)
		-- la ripresa dopo si carica mentre gira questa (prima la camera arrivava su terreno ancora
		-- sfocato, a bassa definizione)
		local nextShot = shots[i + 1]
		if nextShot and nextShot.at then
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(nextShot.at :: Vector3, 5)
				end)
			end)
		end
		if shot.start then
			shot.start()
		end
		-- stacco netto se la nuova ripresa parte lontano: la camera morbida prima scivolava da una
		-- casa all'altra passando dentro la montagna
		local first = shot.cam(0)
		if smoothCf and ((smoothCf :: CFrame).Position - first.Position).Magnitude > 40 then
			smoothCf = nil
		end
		t0 = os.clock()
		current = shot
		task.wait(shot.dur)
	end
	fadeTo(s, 1, 0.4)
	task.wait(0.5)
	conn:Disconnect()
	for _, e in blurred do
		e.Enabled = true
	end
	camera.CameraType = Enum.CameraType.Custom
	for _, d in hiddenParts do
		d.LocalTransparencyModifier = 0
	end
	for _, b in hiddenBillboards do
		b.Enabled = true
	end
	if me and myRoot and homeCf then
		me:PivotTo(homeCf)
		myRoot.Anchored = false
	end
end

-- volo con la virata nelle curve e il corpo che sale e scende col battito (prima scivolava
-- dritto come una statua spinta)
local function flyAlong(a: Actor?, path: (number) -> Vector3, u: number, beat: number)
	if not a then
		return
	end
	local p, q, r = path(u), path(u + 0.004), path(u - 0.004)
	local dir = q - r
	if dir.Magnitude < 1e-3 then
		return
	end
	local turn = (q - p).Unit:Cross((p - r).Unit).Y
	-- poco dondolio (prima sembrava una banana appesa che oscilla)
	local bob = math.sin(os.clock() * 2 * math.pi / beat) * 0.45
	local pitch = math.cos(os.clock() * 2 * math.pi / beat) * 0.015
	-- in picchiata: ali chiuse all'indietro (animazione drago-picchiata)
	local tracks = a.tracks
	if tracks and tracks.dive and tracks.fly then
		local diving = dir.Unit.Y < -0.3
		tracks.dive:AdjustWeight(if diving then 1 else 0.001, 0.3)
		tracks.fly:AdjustWeight(if diving then 0.001 else 1, 0.3)
	end
	a.model:PivotTo(CFrame.lookAt(p + Vector3.new(0, bob, 0), p + dir) * CFrame.Angles(pitch, 0, math.clamp(-turn * 30, -0.35, 0.35)))
end

local function dolly(a: Vector3, b: Vector3, la: Vector3, lb: Vector3): (number) -> CFrame
	return function(u)
		local k = smooth(u)
		return CFrame.lookAt(a:Lerp(b, k), la:Lerp(lb, k))
	end
end

local function orbit(c: Vector3, radius: number, height: number, from: number, to: number, lookUp: number): (number) -> CFrame
	return function(u)
		local a = from + (to - from) * smooth(u)
		return CFrame.lookAt(c + Vector3.new(math.cos(a) * radius, height, math.sin(a) * radius), c + Vector3.new(0, lookUp, 0))
	end
end

-- Evoluzione come nei Pokemon: il cucciolo diventa bianco e cresce pulsando, lampo, l'adulto
local function evolution(s: Screen, center: Vector3, baby: Actor?, adult: Actor?, dur: number, grow: number, label: string?): Shot
	local swapped = false
	local look = Vector3.new(0, 0, -1)
	local glow: Highlight? = nil
	local scale0 = 1
	return {
		dur = dur,
		at = center,
		start = function()
			swapped = false
			if baby then
				scale0 = baby.model:GetScale()
			end
			standAt(baby, center, look)
			hide(adult)
			pose(baby, "idle")
			pose(adult, "idle", 0.6)
			if baby then
				local h = Instance.new("Highlight")
				h.FillColor = Color3.new(1, 1, 1)
				h.OutlineColor = ORANGE
				h.FillTransparency = 1
				h.Parent = baby.model
				glow = h
			end
		end,
		update = function(u)
			local t = math.clamp((u - 0.12) / (grow - 0.12), 0, 1)
			if baby and not swapped then
				baby.model:ScaleTo(scale0 * (1 + 1.3 * t * t + 0.07 * math.sin(t * 45) * t))
				standAt(baby, center, look)
				if glow then
					glow.FillTransparency = 1 - t
				end
			end
			if u >= grow and not swapped then
				swapped = true
				flash(s)
				shake = 1.2
				if glow then
					glow:Destroy()
				end
				if baby then
					baby.model:ScaleTo(scale0)
				end
				hide(baby)
				standAt(adult, center, look)
				say(s.big, label or "EVOLVED!", 1.8, ORANGE)
			end
		end,
		cam = function(u)
			local k = smooth(math.max(0, (u - grow) / (1 - grow)))
			local dist = 15 + 85 * k
			local h = 5 + 38 * k
			local a = 0.4 + u * 0.7
			return CFrame.lookAt(center + Vector3.new(math.sin(a) * dist, h, -math.cos(a) * dist), center + Vector3.new(0, 4 + 22 * k, 0))
		end,
	}
end

------------------------------------------------------------------------------------------

local function grand(d: { [string]: any }): (Vector3?, Vector3, Vector3)
	local c, out, face = d.GrandCenter, d.GrandOut, d.GrandFace
	if typeof(c) == "Vector3" and typeof(out) == "Vector3" and typeof(face) == "Vector3" then
		return c, flat(out), face
	end
	return nil, Vector3.xAxis, Vector3.zero
end

function Trailer.play(kind: string, take: string?)
	-- la cartella giusta (quella di questa ripresa)
	local props: Instance? = nil
	local t0 = os.clock()
	while os.clock() - t0 < 10 do
		local p = workspace:FindFirstChild("TrailerProps")
		if p and (not take or tostring(p:GetAttribute("Take")) == take) then
			props = p
			break
		end
		task.wait(0.1)
	end
	local d = if props then props:GetAttributes() else {}
	local s = screen()
	local hidden = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g ~= s.gui and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	local baby, adult, gas = actor(props, "EclissiCucciolo"), actor(props, "EclissiAdulto"), actor(props, "Gas")
	local summit = d.Summit or Vector3.new(1300, 4100, 0)
	local train = d.TrainingCenter or Vector3.new(-837, 70, -1186)
	local gasC = d.GasCenter or Vector3.new(3224, 327, -168)
	local gc, gout, gface = grand(d)
	local gside = Vector3.new(-gout.Z, 0, gout.X)
	local shots: { Shot } = {}
	local function add(shot: Shot): Shot
		table.insert(shots, shot)
		return shot
	end
	local function onStart(shot: Shot, fn: () -> ())
		local before = shot.start
		shot.start = function()
			if before then
				before()
			end
			fn()
		end
	end

	-- il drago adulto vola davanti all'apertura della Grande Grotta, virando; la camera lo segue
	local function shotDragonPass(dur: number): Shot
		local base = if gc then gface + gout * 170 else summit - Vector3.new(0, 2500, 0)
		local function path(u: number): Vector3
			local a = -1.1 + 2.2 * u
			return base + gside * math.sin(a) * 190 + gout * (math.cos(a) * 60 - 40)
		end
		return add({
			dur = dur,
			at = base,
			start = function()
				pose(adult, "fly", 0.55)
			end,
			update = function(u)
				flyAlong(adult, path, u, 1.2 / 0.55)
			end,
			cam = function(u)
				local a = -1.1 + 2.2 * u
				local p = base + gside * math.sin(a) * 190 + gout * (math.cos(a) * 60 - 40)
				return CFrame.lookAt(base + gout * 230 + Vector3.new(0, 40, 0), p:Lerp(gface, 0.35))
			end,
		})
	end
	local function shotIntoGrand(dur: number, from: number, to: number): Shot?
		if not gc then
			return nil
		end
		local c = gc :: Vector3
		local outside = gface + gout * 320 + Vector3.new(0, 60, 0)
		local mouth = gface + gout * 10 + Vector3.new(0, 10, 0)
		local deep = c - gout * 90 + Vector3.new(0, -10, 0)
		return add({
			dur = dur,
			at = c,
			cam = function(u)
				local k = from + (to - from) * smooth(u)
				local p = if k < 0.5 then outside:Lerp(mouth, k * 2) else mouth:Lerp(deep, (k - 0.5) * 2)
				return CFrame.lookAt(p, c - gout * 150 + Vector3.new(0, 10 - 20 * k, 0) + gside * math.sin(k * 3) * 20)
			end,
		})
	end
	local function shotGas(dur: number): Shot
		return add({
			dur = dur,
			at = gasC,
			start = function()
				standAt(gas, gasC + Vector3.new(30, 0, 0), Vector3.new(1, 0, 0.3))
				pose(gas, "walk", 0.8)
			end,
			update = function(u)
				standAt(gas, gasC + Vector3.new(30 + 40 * u, 0, 12 * u), Vector3.new(1, 0, 0.3))
			end,
			cam = orbit(gasC, 110, 40, 2.2, 3.4, 8),
		})
	end

	-- rampino: il sosia sale lungo la corda fino al bordo dello strapiombo (punto della cinematica)
	local function shotGrapple(dur: number): Shot?
		local spot, nrm = workspace:GetAttribute("CineSpot"), workspace:GetAttribute("CineNormal")
		if typeof(spot) ~= "Vector3" or typeof(nrm) ~= "Vector3" then
			return nil
		end
		local n = flat(nrm)
		local side = Vector3.new(-n.Z, 0, n.X)
		local lip = spot + n * 2
		local from = lip + n * 7 - Vector3.new(0, 75, 0)
		local body: Model? = nil
		local rope = Instance.new("Part")
		rope.Anchored, rope.CanCollide, rope.CanQuery, rope.CanTouch = true, false, false, false
		rope.Color = Color3.fromRGB(90, 70, 50)
		rope.Material = Enum.Material.Fabric
		local hook = Instance.new("Part")
		hook.Anchored, hook.CanCollide, hook.CanQuery, hook.CanTouch = true, false, false, false
		hook.Size = Vector3.new(1, 1, 1.6)
		hook.Color = Color3.fromRGB(60, 60, 66)
		hook.Material = Enum.Material.Metal
		-- sale lungo la parete vera: a ogni quota si cerca la roccia con un raggio da fuori e si sta
		-- 3 studs davanti (prima la linea dritta passava dentro la montagna)
		local function bodyAt(u: number): Vector3
			local p = from:Lerp(lip + n * 3 + Vector3.new(0, 2, 0), smooth(u * 1.15))
			local hit = workspace:Raycast(p + n * 80, -n * 160, terrainOnly)
			if hit then
				local d = (p - hit.Position):Dot(n)
				if d < 3 then
					p += n * (3 - d)
				end
			end
			return p
		end
		return add({
			dur = dur,
			at = lip,
			start = function()
				body = cloneBody()
				hook.CFrame = CFrame.lookAt(lip, lip - n)
				hook.Parent = workspace
				rope.Parent = workspace
			end,
			update = function(u)
				local p = bodyAt(u)
				if body then
					(body :: Model):PivotTo(CFrame.lookAt(p, p - n) * CFrame.Angles(math.rad(-15), 0, math.sin(u * 9) * 0.12))
				end
				local hand = p + Vector3.new(0, 2.5, 0) - n * 0.6
				rope.Size = Vector3.new(0.25, 0.25, (lip - hand).Magnitude)
				rope.CFrame = CFrame.lookAt((lip + hand) / 2, lip)
				if u >= 0.999 then
					rope.Parent, hook.Parent = nil, nil
					if body then
						(body :: Model):Destroy()
						body = nil
					end
				end
			end,
			cam = function(u)
				local p = bodyAt(u)
				return CFrame.lookAt(lip + n * 34 + side * 22 - Vector3.new(0, 55 - 40 * smooth(u), 0), p + Vector3.new(0, 4, 0))
			end,
		})
	end
	-- stormo: tutti i draghi in volo a V davanti alla parete, guidati dall'Eclissi adulto
	local flock: { Actor } = {}
	local function shotFlock(dur: number): Shot
		local base = if gc then gface + gout * 140 + Vector3.new(0, 20, 0) else summit - Vector3.new(0, 2600, 0)
		local dir = gside
		local function lead(u: number): Vector3
			return base + dir * (-200 + 400 * u) + gout * math.sin(u * 3) * 20 + Vector3.new(0, 15 * u, 0)
		end
		return add({
			dur = dur,
			at = base,
			start = function()
				pose(adult, "fly", 0.55)
				for _, a in flock do
					pose(a, "fly", 0.9)
				end
			end,
			update = function(u)
				flyAlong(adult, lead, u, 1.2 / 0.55)
				for k, a in flock do
					local row = math.ceil(k / 2)
					local sideK = if k % 2 == 0 then 1 else -1
					local off = -dir * (40 + row * 24) + gout * sideK * row * 20 + Vector3.new(0, math.sin(k * 1.9) * 6, 0)
					flyAlong(a, function(x: number): Vector3
						return lead(x) + off
					end, u, 1.2 / 0.9 + k * 0.03)
				end
			end,
			cam = function(u)
				local p = lead(u)
				-- la camera vola con lo stormo, dietro c'e' la Grande Grotta
				return CFrame.lookAt(p + gout * 95 - dir * 55 + Vector3.new(0, 14, 0), p - dir * 35 - gout * 10)
			end,
		})
	end
	-- dentro la Grande Grotta fino al trono del Re Yeti
	local function shotKing(dur: number): Shot?
		local den = workspace:GetAttribute("GrandCaveDen")
		if not gc or typeof(den) ~= "CFrame" then
			return nil
		end
		local throne = den.Position
		local mouth = gface + gout * 60 + Vector3.new(0, 30, 0)
		local close = throne + gout * 55 + Vector3.new(0, 18, 0)
		return add({
			dur = dur,
			at = throne,
			cam = function(u)
				local k = smooth(u)
				return CFrame.lookAt(mouth:Lerp(close, k), throne + Vector3.new(0, 10 + 10 * (1 - k), 0))
			end,
		})
	end
	-- il cratere sopra i 2000 m: dall'alto si scende verso il Titano di ghiaccio
	local function shotCrater(dur: number): Shot?
		local c, out, den = workspace:GetAttribute("CraterCaveCenter"), workspace:GetAttribute("CraterCaveOut"), workspace:GetAttribute("CraterCaveDen")
		if typeof(c) ~= "Vector3" or typeof(out) ~= "Vector3" or typeof(den) ~= "CFrame" then
			return nil
		end
		local o = flat(out)
		local target = den.Position + Vector3.new(0, 15, 0)
		return add({
			dur = dur,
			at = c,
			cam = dolly(c + o * 330 + Vector3.new(0, 260, 0), c + o * 130 + Vector3.new(0, 70, 0), target, target),
		})
	end

	if kind == "trailer" then
		-- 19 secondi: montagna, rampino, stormo, grotta col re, cratere col titano, gas,
		-- evoluzione nell'arena, titolo
		for _, e in { "Roccia", "Gelo", "Cosmico", "Tempesta", "Fulmine", "Ossa", "Gas" } do
			local a = actor(props, "Stormo" .. e)
			if a then
				table.insert(flock, a)
			end
		end
		local s1 = add({
			dur = 2.4,
			at = summit - Vector3.new(0, 1500, 0),
			cam = dolly(summit + flat(Vector3.new(-1, 0, 0.35)) * 1700 + Vector3.new(0, -1500, 0), summit + flat(Vector3.new(-1, 0, 0.35)) * 900 + Vector3.new(0, -500, 0), summit - Vector3.new(0, 900, 0), summit),
		})
		onStart(s1, function()
			say(s.big, "HARDCORE CLIMBING", 2.1)
		end)
		local gr = shotGrapple(2.2)
		if gr then
			onStart(gr, function()
				say(s.small, "GRAPPLE YOUR WAY UP", 2, ICE)
			end)
		end
		onStart(shotFlock(2.8), function()
			say(s.small, "TAME 8 DRAGONS", 2.5, ORANGE)
		end)
		local king = shotKing(2.8)
		if king then
			onStart(king, function()
				hide(adult)
				for _, a in flock do
					hide(a)
				end
				say(s.small, "GIANT ICE CAVES...", 1.3, ICE)
				task.delay(1.3, function()
					say(s.big, "...AND THEIR KING", 1.4, ICE)
				end)
			end)
		end
		local crater = shotCrater(1.8)
		if crater then
			onStart(crater, function()
				say(s.small, "THE ICE TITAN AWAITS", 1.6, ICE)
			end)
		end
		onStart(shotGas(1.6), function()
			say(s.small, "SURVIVE THE TOXIC VALLEYS", 1.4, Color3.fromRGB(240, 110, 230))
		end)
		local evo = add(evolution(s, train + Vector3.new(0, 0, 8), baby, adult, 3, 0.55))
		onStart(evo, function()
			hide(gas)
			say(s.small, "TRAIN TO LV 100", 1.5, GOLD)
		end)
		local last = add({
			dur = 2.2,
			cam = shots[#shots].cam,
			start = function()
				fadeTo(s, 1, 0.35)
				task.delay(0.3, function()
					say(s.big, "HARDCORE CLIMBING", 1.6)
					say(s.bottom, "COMING SOON", 1.6, ORANGE)
				end)
			end,
		})
		local _ = last
	elseif kind == "clip1" then
		-- RAGE (circa 16 s): un open loop ("2 metri dalla vetta"), la caduta, il conto, il voto
		local top = summit - Vector3.new(0, 40, 0)
		local outDir = flat(Vector3.new(-1, 0, 0.2))
		local ledge = groundAt(top + outDir * 60)
		local body = cloneBody()
		local fallTrack: AnimationTrack? = nil
		if body then
			local humanoid = body:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://507767968" -- caduta R15
				fallTrack = animator:LoadAnimation(anim)
			end
			body:PivotTo(CFrame.lookAt(ledge + Vector3.new(0, 3, 0), ledge + Vector3.new(0, 3, 0) - outDir))
		end
		local start = ledge + Vector3.new(0, 3, 0)
		local bottom = groundAt(start + outDir * 260 - Vector3.new(0, 400, 0))
		add({
			dur = 3,
			at = start,
			cam = dolly(start + outDir * 14 + Vector3.new(0, 2, 6), start + outDir * 9 + Vector3.new(0, 4, 4), start, start + Vector3.new(0, 1, 0)),
			start = function()
				say(s.small, "I was 2 meters from the top...", 2.8)
			end,
		})
		add({
			dur = 3.2,
			at = start,
			start = function()
				say(s.big, "then THIS happened", 1.4, RED)
				if fallTrack then
					(fallTrack :: AnimationTrack):Play()
				end
			end,
			update = function(u)
				if body then
					local k = u * u
					local p = start:Lerp(bottom + Vector3.new(0, 3, 0), k) + outDir * math.sin(u * math.pi) * 40
					body:PivotTo(CFrame.new(p) * CFrame.Angles(u * 9, u * 4, u * 6))
				end
			end,
			cam = function(u)
				local k = u * u
				local p = start:Lerp(bottom, k) + outDir * math.sin(u * math.pi) * 40
				return CFrame.lookAt(start + outDir * 30 + Vector3.new(0, 20 - 160 * u, 0), p)
			end,
		})
		add({
			dur = 3,
			at = bottom,
			start = function()
				flash(s, s.red)
				shake = 1.5
				say(s.big, "-47 MINUTES", 2.6, RED)
				say(s.bottom, "no checkpoints. no mercy.", 2.6)
			end,
			cam = dolly(bottom + outDir * 25 + Vector3.new(0, 8, 0), bottom + outDir * 45 + Vector3.new(0, 30, 0), bottom, bottom),
		})
		add({
			dur = 4.5,
			at = summit - Vector3.new(0, 1500, 0),
			start = function()
				if body then
					body:Destroy()
					body = nil
				end
				say(s.small, "would YOU try again?", 4.2)
				task.delay(1.2, function()
					say(s.bottom, "comment YES or NO", 3, GOLD)
				end)
			end,
			cam = dolly(bottom + outDir * 120 + Vector3.new(0, 60, 0), bottom + outDir * 900 + Vector3.new(0, 400, 0), bottom, summit),
		})
	elseif kind == "clip2" then
		-- EVOLUZIONE (circa 15 s): curiosity gap, conto alla rovescia, rivelazione, domanda
		local c = train + Vector3.new(0, 0, 8)
		local count = add({
			dur = 3.2,
			at = c,
			start = function()
				standAt(baby, c, Vector3.new(0, 0, -1))
				hide(adult)
				pose(baby, "idle")
				say(s.small, "don't skip: watch what happens at level 100", 3)
				for k, lv in { "Lv 97", "Lv 98", "Lv 99" } do
					task.delay(0.5 + k * 0.8, function()
						say(s.big, lv, 0.6, GOLD)
					end)
				end
			end,
			cam = dolly(c + Vector3.new(30, 14, -30), c + Vector3.new(14, 6, -14), c + Vector3.new(0, 4, 0), c + Vector3.new(0, 4, 0)),
		})
		local _ = count
		add(evolution(s, c, baby, adult, 7, 0.45, "Lv 100 · EVOLVED"))
		add({
			dur = 4,
			cam = orbit(c, 95, 40, 1.4, 2.4, 22),
			start = function()
				say(s.small, "which dragon should evolve next?", 3.8)
				task.delay(0.8, function()
					say(s.bottom, "ECLIPSE  or  TOXIC GAS? comment", 3, GOLD)
				end)
			end,
		})
	elseif kind == "clip3" then
		-- GRANDE GROTTA (circa 14 s): pattern interrupt, rivelazione, open loop finale
		local g = shotIntoGrand(5, 0, 0.5)
		if g then
			onStart(g, function()
				say(s.big, "this mountain is hollow.", 2.4)
				task.delay(2.6, function()
					say(s.small, "and someone carved THIS inside", 2.2, ICE)
				end)
			end)
		end
		-- dentro: il trono, e chi ci sta seduto
		local king = shotKing(5)
		if king then
			onStart(king, function()
				say(s.small, "and something LIVES in here...", 2.4, ICE)
				task.delay(2.6, function()
					say(s.big, "the YETI KING", 2.2, ICE)
				end)
			end)
		end
		onStart(shotDragonPass(4), function()
			say(s.big, "part 2 at 1000 likes", 3.6, GOLD)
		end)
	end
	-- clip16: la scena del boss vista dallo scalatore, in terza persona, che lancia la piccozza
	local withPlayer = kind == "clip16"
	if kind == "clip16" then
		kind = "clip4"
	end
	if string.match(kind, "^clip%d+$") and (tonumber(string.sub(kind, 5)) or 0) >= 4 then
		-- clip SENZA scritte (i testi si mettono nell'editor di TikTok: docs/TIKTOK_CLIPS.md)
		local function sparkBurst(at: Vector3, color: Color3, size: number)
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
			p.Size = Vector3.one
			p.Position = at
			p.Parent = workspace
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(color)
			e.LightEmission = 1
			e.Size = NumberSequence.new(size, 0)
			e.Speed = NumberRange.new(size * 4, size * 9)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Lifetime = NumberRange.new(0.4, 0.9)
			e.Parent = p
			e:Emit(60)
			local l = Instance.new("PointLight")
			l.Color = color
			l.Range = size * 10
			l.Brightness = 4
			l.Parent = p
			TweenService:Create(l, TweenInfo.new(0.5), { Brightness = 0 }):Play()
			task.delay(1.2, function()
				p:Destroy()
			end)
		end
		local function fireball(from: Vector3, to: Vector3, color: Color3)
			local b = Instance.new("Part")
			b.Shape = Enum.PartType.Ball
			b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
			b.Material = Enum.Material.Neon
			b.Color = color
			b.Size = Vector3.one * 3
			b.Position = from
			b.Parent = workspace
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)
			a0.Parent, a1.Parent = b, b
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Color = ColorSequence.new(color)
			tr.LightEmission = 1
			tr.Lifetime = 0.3
			tr.Transparency = NumberSequence.new(0, 1)
			tr.Parent = b
			local tw = TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = to })
			tw:Play()
			tw.Completed:Connect(function()
				b:Destroy()
				sparkBurst(to, color, 3)
				shake = math.max(shake, 0.6)
			end)
		end

		if kind == "clip4" then
			-- BOSS: nel cratere sopra i 2000 m il Titano di ghiaccio si risveglia, tre draghi (Eclissi,
			-- Gelo, Fulmine Nero) gli girano attorno e lo colpiscono, il Titano crolla
			local den = workspace:GetAttribute("CraterCaveDen")
			local allies: { { a: Actor?, color: Color3, phase: number, element: string } } = {
				{ a = adult, color = Color3.fromRGB(255, 160, 60), phase = 0, element = "Eclissi" },
				{ a = actor(props, "StormoGelo"), color = Color3.fromRGB(140, 220, 255), phase = 0.33, element = "Gelo" },
				{ a = actor(props, "StormoFulmine"), color = Color3.fromRGB(180, 130, 255), phase = 0.66, element = "Fulmine" },
			}
			if typeof(den) == "CFrame" then
				local throne = den.Position
				local out = den.LookVector
				local side = den.RightVector
				local yeti: Model? = nil
				local real: Model? = nil
				local realCf: CFrame? = nil
				local tracks: { [string]: any } = {}
				local hp: Frame? = nil
				local function prepareYeti()
					local folder = workspace:FindFirstChild("Nemici")
					for _, m in (if folder then folder:GetChildren() else {}) :: { Instance } do
						if m:IsA("Model") and m:GetAttribute("Boss") and (m:GetPivot().Position - throne).Magnitude < 90 then
							real = m
						end
					end
					if not real then
						return
					end
					-- si usa il Re vero, solo qui sul client: le sue animazioni del server si fermano e le
					-- pose le suona KfsPlayer (una copia del modello risultava invisibile)
					local r = real :: Model
					local c = r
					yeti = c
					realCf = r:GetPivot()
					-- in piedi sul pavimento del cratere, girato verso l'uscita (il trono non c'e':
					-- seduto sembrava sospeso in aria)
					r:PivotTo(CFrame.lookAt(throne, throne + out))
					local floorHit = workspace:Raycast(throne + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), terrainOnly)
					local floorY = if floorHit then floorHit.Position.Y else throne.Y
					local bcf, bsz = r:GetBoundingBox()
					r:PivotTo(r:GetPivot() + Vector3.new(0, floorY - (bcf.Position.Y - bsz.Y / 2), 0))
					local animator = r:FindFirstChildWhichIsA("Animator", true)
					if animator then
						for _, t in animator:GetPlayingAnimationTracks() do
							t:Stop(0)
						end
					end
					for _, d in r:GetDescendants() do
						if d:IsA("BillboardGui") then
							d.Enabled = false -- nome e barra del boss vero
						end
					end
					-- animazioni (copie client delle pose salvate)
					local set = game:GetService("ReplicatedStorage"):FindFirstChild("EnemyAnimSaves")
					set = set and set:FindFirstChild("GolemGhiaccio")
					for name, key in { sit = "nemico-seduto", idle = "nemico-fermo", attack = "nemico-attacco", walk = "nemico-cammina" } do
						local k = set and set:FindFirstChild(key)
						if k and k:IsA("KeyframeSequence") then
							tracks[name] = KfsPlayer.load(c, k)
						end
					end
					if tracks.idle then
						tracks.idle:Play(0, 1)
					end
					-- barra della vita (senza scritte)
					local bb = Instance.new("BillboardGui")
					bb.Size = UDim2.fromScale(12, 1.1)
					bb.StudsOffsetWorldSpace = Vector3.new(0, 26, 0)
					bb.AlwaysOnTop = true
					bb.Adornee = c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart", true)
					local back = Instance.new("Frame")
					back.Size = UDim2.fromScale(1, 1)
					back.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
					back.BorderSizePixel = 0
					back.Parent = bb
					local fill = Instance.new("Frame")
					fill.Size = UDim2.fromScale(1, 1)
					fill.BackgroundColor3 = Color3.fromRGB(230, 60, 50)
					fill.BorderSizePixel = 0
					fill.Parent = back
					bb.Parent = c
					hp = fill
				end
				local function play(name: string)
					for n, t in tracks do
						if n == name then
							t:Play(0.25, 1)
						else
							t:Stop(0.25)
						end
					end
				end
				local fightC = throne + out * 30
				local function pathFor(phase: number): (number) -> Vector3
					return function(u: number): Vector3
						local a = (u + phase) * math.pi * 2.2
						return fightC + side * math.sin(a) * 70 + out * (math.cos(a) * 55 + 10) + Vector3.new(0, 42 + 10 * math.sin(a * 2 + phase * 6), 0)
					end
				end
				local function flyAll(u: number)
					for _, al in allies do
						flyAlong(al.a, pathFor(al.phase), u, 2)
					end
				end
				local HIT = Vector3.new(0, 20, 0) -- petto del Titano
				-- lo scalatore (solo clip16): davanti al Titano, piccozza in mano
				local body: Model? = nil
				local axe: Model? = nil
				local meCf = CFrame.identity
				local function joints(m: Model, list: { [string]: CFrame })
					for _, x in m:GetDescendants() do
						if (x:IsA("Motor6D") or x:IsA("AnimationConstraint")) and list[x.Name] then
							(x :: any).Transform = list[x.Name]
						end
					end
				end
				local function handPos(): Vector3
					local h = body and body:FindFirstChild("RightHand")
					return if h and h:IsA("BasePart") then h.Position else meCf.Position + Vector3.new(0, 1.5, 0)
				end
				local function placeAxe(cf: CFrame)
					if axe and axe.PrimaryPart then
						axe:PivotTo(cf)
					end
				end
				local function setupPlayer()
					if not withPlayer or body then
						return
					end
					local p0 = throne + out * 40 + side * 6
					local hit = workspace:Raycast(p0 + Vector3.new(0, 10, 0), Vector3.new(0, -50, 0), terrainOnly)
					local p = (if hit then hit.Position else p0) + Vector3.new(0, 3, 0)
					meCf = CFrame.lookAt(p, p + flat(throne - p))
					body = cloneBody()
					if body then
						body:PivotTo(meCf)
					end
					local a = sceneAxe()
					a.Parent = workspace
					axe = a
				end
				-- 1) il cratere: si scende verso il Titano immobile (3 s)
				add({
					dur = 3,
					at = throne,
					start = function()
						prepareYeti()
						setupPlayer()
						for _, al in allies do
							hide(al.a)
						end
					end,
					update = function()
						placeAxe(CFrame.lookAt(handPos(), handPos() + meCf.LookVector) * CFrame.Angles(math.rad(-90), 0, 0))
					end,
					cam = dolly(throne + out * 150 + Vector3.new(0, 120, 0), throne + out * 70 + Vector3.new(0, 30, 0), throne + Vector3.new(0, 15, 0), throne + Vector3.new(0, 18, 0)),
				})
				-- 2) si risveglia: inquadratura dal basso, scossa, lampo rosso (2 s)
				add({
					dur = 2,
					at = throne,
					start = function()
						play("idle")
						shake = 1.4
						flash(s, s.red)
					end,
					cam = dolly(throne + out * 34 + side * 8 + Vector3.new(0, 3, 0), throne + out * 28 + side * 6 + Vector3.new(0, 2, 0), throne + Vector3.new(0, 26, 0), throne + Vector3.new(0, 32, 0)),
				})
				-- 3) combattimento: tre draghi gli girano attorno e sparano, il Titano colpisce (6 s)
				local nextShot = 0
				local nextSwing = 0
				local life = 1
				local turn = 0
				local hitIdx = -1
				local combatDur = if withPlayer then 8 else 6
				add({
					dur = combatDur,
					at = throne,
					start = function()
						for _, al in allies do
							pose(al.a, "fly", 0.7)
						end
					end,
					update = function(u)
						flyAll(u)
						-- lo scalatore lancia la piccozza ogni 2.6 s: carica, lancio, colpo, ritorno in mano
						local b = body
						if b then
							local tm = u * combatDur
							local tt = tm % 2.6
							local idx = math.floor(tm / 2.6)
							local wind = math.clamp(tt / 0.5, 0, 1)
							local rel = math.clamp((tt - 0.5) / 0.15, 0, 1)
							local settle = math.clamp((tt - 1.2) / 0.5, 0, 1)
							local catch = math.sin(math.clamp((tt - 1.75) / 0.5, 0, 1) * math.pi)
							b:PivotTo(meCf)
							joints(b, {
								RightShoulder = CFrame.Angles(math.rad(170 * wind - 230 * rel + 60 * settle + 70 * catch), 0, 0),
								RightElbow = CFrame.Angles(math.rad(60 * wind * (1 - rel)), 0, 0),
								Waist = CFrame.Angles(0, math.rad(-25 * wind + 40 * rel - 15 * settle), 0),
							})
							local hand = handPos()
							local tgt = throne + HIT + side * ((idx % 2) * 6 - 3)
							if tt < 0.62 then
								placeAxe(CFrame.lookAt(hand, tgt) * CFrame.Angles(math.rad(-90), 0, 0))
							elseif tt < 1.1 then
								local f = (tt - 0.62) / 0.48
								local p = hand:Lerp(tgt, f) + Vector3.new(0, math.sin(f * math.pi) * 3, 0)
								placeAxe(CFrame.lookAt(p, tgt) * CFrame.Angles(tm * 25, 0, 0))
							else
								if hitIdx ~= idx then
									hitIdx = idx
									sparkBurst(tgt, Color3.fromRGB(200, 230, 255), 5)
									shake = math.max(shake, 1)
									life = math.max(0.12, life - 0.06)
									if hp then
										TweenService:Create(hp, TweenInfo.new(0.3), { Size = UDim2.fromScale(life, 1) }):Play()
									end
								end
								local f = math.clamp((tt - 1.1) / 0.75, 0, 1)
								local e = f * f * (3 - 2 * f)
								local p = tgt:Lerp(hand, e) + meCf.RightVector * math.sin(f * math.pi) * 6 + Vector3.new(0, math.sin(f * math.pi) * 4, 0)
								-- (in mano p == hand: lookAt darebbe NaN e la piccozza spariva)
								local aim = if (hand - p).Magnitude > 0.05 then CFrame.lookAt(p, hand) else CFrame.new(p) * meCf.Rotation
								placeAxe(aim * CFrame.Angles(tm * 25 * (1 - f), 0, 0))
							end
						end
						local t = os.clock()
						if t > nextShot then
							nextShot = t + 0.3
							turn = turn % #allies + 1
							local al = allies[turn]
							if al.a then
								local to = throne + HIT + side * (math.random() - 0.5) * 8
								DragonVFX.shot(al.element, DragonVFX.mouth(al.a.model, to), to, al.color)
								life = math.max(0.12, life - 0.035)
								if hp then
									TweenService:Create(hp, TweenInfo.new(0.3), { Size = UDim2.fromScale(life, 1) }):Play()
								end
							end
						end
						if t > nextSwing then
							nextSwing = t + 1.6
							play("attack")
							task.delay(0.5, function()
								sparkBurst(throne + out * 18 + Vector3.new(0, 2, 0), Color3.fromRGB(180, 230, 255), 6)
								shake = 1.2
							end)
							task.delay(1.1, function()
								play("idle")
							end)
						end
					end,
					cam = function(u)
						if body then
							-- sopra la spalla dello scalatore
							local r = meCf.RightVector
							return CFrame.lookAt(meCf.Position - meCf.LookVector * (9 + 3 * u) + Vector3.new(0, 4.5, 0) + r * 3.5, throne + HIT * 0.75 + r * 2)
						end
						local a = 0.6 + u * 1.4
						return CFrame.lookAt(throne + out * 95 * math.cos(a * 0.4) + side * 80 * math.sin(a) + Vector3.new(0, 30, 0), throne + HIT)
					end,
				})
				-- 4) colpo finale: i tre insieme, lampo, il Titano si sbriciola (3 s)
				local finalCam = dolly(throne + out * 60 + side * 35 + Vector3.new(0, 14, 0), throne + out * 80 + side * 40 + Vector3.new(0, 24, 0), throne + Vector3.new(0, 14, 0), throne + Vector3.new(0, 6, 0))
				add({
					dur = 3,
					at = throne,
					start = function()
						for _, al in allies do
							if al.a then
								DragonVFX.shot(al.element, DragonVFX.mouth(al.a.model, throne + HIT), throne + HIT, al.color)
							end
						end
						task.delay(0.4, function()
							flash(s)
							shake = 2
							if hp then
								hp.Size = UDim2.fromScale(0, 1)
							end
							for _, t in tracks do
								t:Stop(0.3)
							end
							local y = yeti
							if y then
								-- si piega in avanti, scende un poco e si sbriciola in ghiaccio (prima ruotava
								-- in orizzontale sollevato da terra)
								local cf0 = y:GetPivot()
								local parts: { BasePart } = {}
								for _, p in y:GetDescendants() do
									if p:IsA("BasePart") then
										table.insert(parts, p)
									end
								end
								local fall = Instance.new("NumberValue")
								fall.Changed:Connect(function(v)
									y:PivotTo(cf0 * CFrame.new(0, -2.5 * v, 0) * CFrame.Angles(-0.3 * v, 0, 0))
									local fade = math.clamp((v - 0.45) / 0.55, 0, 1)
									for _, p in parts do
										p.LocalTransparencyModifier = fade
									end
								end)
								TweenService:Create(fall, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 }):Play()
								for k = 1, 5 do
									task.delay(0.5 + 0.15 * k, function()
										sparkBurst(throne + Vector3.new(math.random(-6, 6), 4 + math.random() * 16, math.random(-6, 6)), Color3.fromRGB(190, 230, 255), 7)
									end)
								end
							end
							for k = 1, 4 do
								task.delay(0.2 * k, function()
									sparkBurst(throne + Vector3.new(math.random(-8, 8), 6 + math.random() * 10, math.random(-8, 8)), Color3.fromRGB(255, 220, 90), 5)
								end)
							end
						end)
					end,
					update = function(u)
						flyAll(1 + u * 0.1)
						local b = body
						if b then
							-- piccozza alzata: vittoria
							b:PivotTo(meCf)
							joints(b, { RightShoulder = CFrame.Angles(math.rad(165), 0, math.rad(-10)) })
							placeAxe(CFrame.new(handPos()) * meCf.Rotation)
						end
					end,
					cam = function(u)
						if body then
							local r = meCf.RightVector
							local k = smooth(u)
							local p = meCf.Position - meCf.LookVector * (10 + 16 * k) + Vector3.new(0, 4 + 8 * k, 0) + r * (4 + 6 * k)
							return CFrame.lookAt(p, throne + HIT:Lerp(Vector3.new(0, 8, 0), k))
						end
						return finalCam(u)
					end,
				})
				-- 5) uscita: la camera sale fuori dal cratere coi draghi che girano sopra (2.5 s)
				add({
					dur = 2.5,
					at = throne,
					update = function(u)
						flyAll(1.1 + u * 0.3)
					end,
					cam = dolly(throne + out * 80 + Vector3.new(0, 30, 0), throne + out * 120 + Vector3.new(0, 230, 0), throne + Vector3.new(0, 10, 0), throne + Vector3.new(0, 10, 0)),
				})
				-- pulizia
				local cleanup = shots[#shots]
				local before = cleanup.start
				cleanup.start = function()
					if before then
						before()
					end
					task.delay(2.4, function()
						for _, t in tracks do
							t:Stop(0.2)
						end
						if real and realCf then
							(real :: Model):PivotTo(realCf :: CFrame)
						end
						if real then
							for _, d in (real :: Model):GetDescendants() do
								if d:IsA("BillboardGui") then
									d.Enabled = true
								elseif d:IsA("BasePart") then
									d.LocalTransparencyModifier = 0
								end
							end
						end
						if body then
							body:Destroy()
							body = nil
						end
						if axe then
							axe:Destroy()
							axe = nil
						end
					end)
				end
			end
		elseif kind == "clip5" then
			-- GIRO DELLE ZONE: tagli veloci (pattern interrupt) con un lampo tra una e l'altra
			local stops: { { c: Vector3, r: number } } = {}
			local seen = {}
			for i = 1, (workspace:GetAttribute("ThemeZoneCount") or 0) :: number do
				local e = workspace:GetAttribute("ThemeZone" .. i .. "Element")
				local c = workspace:GetAttribute("ThemeZone" .. i .. "Center")
				local r = workspace:GetAttribute("ThemeZone" .. i .. "Radius")
				if type(e) == "string" and not seen[e] and typeof(c) == "Vector3" and type(r) == "number" then
					seen[e] = true
					-- si inquadra il cuore della forma (fondo della gola, isola, dentro la grotta)
					local stg = workspace:GetAttribute("ThemeZone" .. i .. "Stage")
					table.insert(stops, { c = if typeof(stg) == "Vector3" then stg + Vector3.new(0, 10, 0) else c, r = r * 0.9 })
				end
			end
			local gas1 = workspace:GetAttribute("GasCenter1")
			if typeof(gas1) == "Vector3" then
				table.insert(stops, 4, { c = gas1, r = 140 })
			end
			if gc then
				table.insert(stops, 2, { c = gface + gout * 10, r = 160 })
			end
			-- la camera sta dal lato della valle (lontano dal centro della montagna) e si sceglie
			-- l'angolo da cui la zona si vede senza roccia in mezzo: prima passava dentro la montagna
			local mc = workspace:GetAttribute("CineCenter")
			local function viewAngle(c: Vector3, r: number): number
				local out = if typeof(mc) == "Vector3" then flat(c - Vector3.new(mc.X, c.Y, mc.Z)) else Vector3.xAxis
				local base = math.atan2(out.Z, out.X)
				-- 16 angoli attorno al lato della valle: il primo da cui la vista e' libera (niente
				-- isole o rocce tra la camera e la zona)
				for k = 0, 15 do
					local off = (if k % 2 == 0 then 1 else -1) * math.ceil(k / 2) * 0.3
					local a = base + off
					local cam = c + Vector3.new(math.cos(a) * r, r * 0.45, math.sin(a) * r)
					local ok = not solidAt(cam)
					local hit = ok and workspace:Raycast(cam, c - cam, terrainOnly)
					if ok and (not hit or (hit.Position - c).Magnitude < r * 0.25) then
						return a
					end
				end
				return base
			end
			for k, st in stops do
				local last = k == #stops
				local a0 = 0
				-- 3 secondi per bioma (prima 1.3: non si caricava e il video usciva sfocato), lenta
				-- carrellata che si avvicina; stacco netto senza lampo bianco
				add({
					dur = if last then 3.5 else 3,
					at = st.c,
					start = function()
						-- qui la zona e' gia' caricata (i raggi vedono il terreno)
						a0 = viewAngle(st.c, st.r * 1.1)
					end,
					cam = function(u)
						local a = a0 + (u - 0.5) * 0.25
						local r = st.r * 1.1 * (1 - 0.25 * smooth(u))
						return CFrame.lookAt(st.c + Vector3.new(math.cos(a) * r, r * 0.45, math.sin(a) * r), st.c)
					end,
				})
			end
		elseif kind == "clip6" then
			-- VOLO: camera dietro all'Eclissi adulto, dal cratere in picchiata lungo la montagna
			-- fino dentro la Grande Grotta
			local cc = workspace:GetAttribute("CraterCaveCenter")
			local co = workspace:GetAttribute("CraterCaveOut")
			if gc and typeof(cc) == "Vector3" and typeof(co) == "Vector3" then
				local o = flat(co)
				-- percorso sempre FUORI dalla montagna: a ogni tappa si misura col raggio quanto e'
				-- larga la montagna a quella quota e si vola 110 studs piu' in fuori (prima il drago
				-- passava dentro la roccia)
				local mcv = workspace:GetAttribute("CineCenter")
				local mc = if typeof(mcv) == "Vector3" then mcv else Vector3.zero
				local function surfaceR(a: number, y: number): number
					local dir = Vector3.new(math.cos(a), 0, math.sin(a))
					local from = Vector3.new(mc.X, y, mc.Z) + dir * 4000
					local hit = workspace:Raycast(from, -dir * 4000, terrainOnly)
					return if hit then (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(mc.X, 0, mc.Z)).Magnitude else 0
				end
				local function angleOf(p: Vector3): number
					return math.atan2(p.Z - mc.Z, p.X - mc.X)
				end
				local pts: { Vector3 } = { gface, gface + gout, gface + gout * 2 }
				-- si calcola all'inizio della ripresa, quando il terreno e' gia' caricato
				local function buildPath()
					local a1, a2 = angleOf(cc), angleOf(gface)
					local da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
					local y1, y2 = cc.Y + 160, gface.Y + 60
					pts = { cc + o * 60 + Vector3.new(0, 200, 0) }
					local N = 9
					for k = 1, N do
						local f = k / N
						local a = a1 + da * f
						local y = y1 + (y2 - y1) * f
						local r = math.max(surfaceR(a, y), surfaceR(a, y - 60), surfaceR(a, y + 60)) + 110
						table.insert(pts, Vector3.new(mc.X + math.cos(a) * r, y, mc.Z + math.sin(a) * r))
					end
					table.insert(pts, gface + gout * 90 + Vector3.new(0, 25, 0))
					table.insert(pts, gface + gout * 10 + Vector3.new(0, 10, 0))
					table.insert(pts, (gc :: Vector3) + Vector3.new(0, -10, 0))
					table.insert(pts, (gc :: Vector3) - gout * 90 + Vector3.new(0, -10, 0))
					-- se un tratto passa nella roccia, il punto dopo si sposta ancora in fuori
					for k = 2, #pts - 4 do
						for _ = 1, 4 do
							if workspace:Raycast(pts[k - 1], pts[k] - pts[k - 1], terrainOnly) then
								local p = pts[k]
								local out = flat(p - Vector3.new(mc.X, p.Y, mc.Z))
								pts[k] = p + out * 60 + Vector3.new(0, 20, 0)
							end
						end
					end
				end
				-- ripresa cortissima sul cratere: serve solo a caricare quella zona prima del volo
				add({ dur = 0.05, at = cc, cam = function()
					return CFrame.lookAt(cc + o * 200 + Vector3.new(0, 200, 0), cc)
				end })
				-- curva morbida che passa per tutti i punti (Catmull-Rom)
				local function path(u: number): Vector3
					u = math.clamp(u, 0, 1)
					local n = #pts - 1
					local x = u * n
					local i = math.min(math.floor(x), n - 1)
					local t = x - i
					local p0 = pts[math.max(1, i)]
					local p1 = pts[i + 1]
					local p2 = pts[i + 2]
					local p3 = pts[math.min(#pts, i + 3)]
					local t2, t3 = t * t, t * t * t
					return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
				end
				add({
					dur = 11,
					at = gface,
					smooth = 2.5, -- la camera insegue morbida (prima girava di scatto nelle curve)
					follow = true,
					start = function()
						buildPath()
						pose(adult, "fly", 0.7)
					end,
					update = function(u)
						flyAlong(adult, path, smooth(u) * 0.97, 1.6)
					end,
					cam = function(u)
						local k = smooth(u) * 0.97
						local p = path(k)
						local dir = (path(k + 0.01) - path(math.max(0, k - 0.01))).Unit
						return CFrame.lookAt(p - dir * 45 + Vector3.new(0, 14, 0), p + dir * 30)
					end,
				})
			end
		else
			-- ============ clip7 - clip11 ============
			local UP = Vector3.yAxis
			local mcv = workspace:GetAttribute("CineCenter")
			local mc = if typeof(mcv) == "Vector3" then Vector3.new(mcv.X, 0, mcv.Z) else Vector3.new(summit.X, 0, summit.Z)
			local mR = (workspace:GetAttribute("CineRadius") or 2300) :: number
			local top = summit.Y
			-- curva morbida tra punti (Catmull-Rom)
			local function catmull(pts: { Vector3 }, u: number): Vector3
				u = math.clamp(u, 0, 1)
				local n = #pts - 1
				local x = u * n
				local i = math.min(math.floor(x), n - 1)
				local t = x - i
				local p0, p1, p2, p3 = pts[math.max(1, i)], pts[i + 1], pts[i + 2], pts[math.min(#pts, i + 3)]
				local t2, t3 = t * t, t * t * t
				return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
			end
			-- raggi che vedono terreno E oggetti (colonne di ghiaccio, case, isole), non gli attori
			local solidParams = RaycastParams.new()
			solidParams.FilterType = Enum.RaycastFilterType.Exclude
			solidParams.FilterDescendantsInstances = { player.Character :: Instance, workspace:FindFirstChild("Pets") :: Instance, props :: Instance }
			local function surfaceR(a: number, y: number): number
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local hit = workspace:Raycast(Vector3.new(mc.X, y, mc.Z) + dir * 5000, -dir * 5000, solidParams)
				return if hit then (Vector3.new(hit.Position.X, 0, hit.Position.Z) - mc).Magnitude else 0
			end
			local function groundAll(p: Vector3): Vector3
				local hit = workspace:Raycast(p + UP * 60, -UP * 200, solidParams)
				return if hit then hit.Position else groundAt(p)
			end
			-- articolazioni del sosia: vanno rimesse OGNI fotogramma (l'Animator le azzera)
			local function limbs(body: Model?, list: { [string]: CFrame })
				if not body then
					return
				end
				for _, d in body:GetDescendants() do
					if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and list[d.Name] then
						(d :: any).Transform = list[d.Name]
					end
				end
			end
			local function deg(x: number): number
				return math.rad(x)
			end
			local function climbPose(body: Model?, t: number)
				local s = math.sin(t * 2.2)
				limbs(body, {
					RightShoulder = CFrame.Angles(deg(160 + 10 * s), 0, deg(-8)),
					LeftShoulder = CFrame.Angles(deg(140 - 10 * s), 0, deg(8)),
					RightElbow = CFrame.Angles(deg(25), 0, 0),
					LeftElbow = CFrame.Angles(deg(40), 0, 0),
					RightHip = CFrame.Angles(deg(25 + 8 * s), 0, 0),
					LeftHip = CFrame.Angles(deg(10 - 8 * s), 0, 0),
					RightKnee = CFrame.Angles(deg(-45), 0, 0),
					LeftKnee = CFrame.Angles(deg(-25), 0, 0),
				})
			end
			local function hangPose(body: Model?, t: number)
				limbs(body, {
					RightShoulder = CFrame.Angles(deg(172), 0, deg(-6)),
					LeftShoulder = CFrame.Angles(deg(168), 0, deg(6)),
					RightElbow = CFrame.Angles(deg(15), 0, 0),
					LeftElbow = CFrame.Angles(deg(15), 0, 0),
					RightHip = CFrame.Angles(deg(15 + 8 * math.sin(t * 3)), 0, 0),
					LeftHip = CFrame.Angles(deg(5 - 8 * math.sin(t * 3)), 0, 0),
					RightKnee = CFrame.Angles(deg(-30), 0, 0),
					LeftKnee = CFrame.Angles(deg(-20), 0, 0),
				})
			end
			local function fallPose(body: Model?, t: number)
				local s = math.sin(t * 9)
				limbs(body, {
					RightShoulder = CFrame.Angles(deg(130 + 30 * s), 0, deg(-40)),
					LeftShoulder = CFrame.Angles(deg(130 - 30 * s), 0, deg(40)),
					RightHip = CFrame.Angles(deg(30 * s), 0, 0),
					LeftHip = CFrame.Angles(deg(-30 * s), 0, 0),
					RightKnee = CFrame.Angles(deg(-40), 0, 0),
					LeftKnee = CFrame.Angles(deg(-40), 0, 0),
				})
			end
			local function walkPose(body: Model?, t: number, amp: number)
				local s = math.sin(t * 8)
				limbs(body, {
					RightHip = CFrame.Angles(math.rad(30 * s * amp), 0, 0),
					LeftHip = CFrame.Angles(math.rad(-30 * s * amp), 0, 0),
					RightShoulder = CFrame.Angles(math.rad(-25 * s * amp), 0, 0),
					LeftShoulder = CFrame.Angles(math.rad(25 * s * amp), 0, 0),
				})
			end
			local around: { Vector3 } = {}
			for k = 0, 7 do
				local a = k / 8 * 2 * math.pi
				table.insert(around, Vector3.new(mc.X + math.cos(a) * mR * 1.1, top * 0.3, mc.Z + math.sin(a) * mR * 1.1))
			end
			-- una parete di roccia ripida e libera davanti (lontana da zone, grotte e ghiaccio): li'
			-- si appende lo scalatore delle clip 8 e 9 (prima il punto della cinematica era finito
			-- dentro una grotta dei draghi e lo scalatore era in mezzo al vuoto)
			local function wallSpot(y: number): (Vector3?, Vector3)
				-- prima quella trovata dal server (ha tutta la mappa)
				if typeof(d.WallSpot) == "Vector3" and typeof(d.WallNormal) == "Vector3" then
					return d.WallSpot, d.WallNormal
				end
				local bad: { Vector3 } = {}
				for i = 1, (workspace:GetAttribute("ThemeZoneCount") or 0) :: number do
					local c = workspace:GetAttribute("ThemeZone" .. i .. "Center")
					if typeof(c) == "Vector3" then
						table.insert(bad, c)
					end
				end
				for _, key in { "GrandCaveCenter", "CraterCaveCenter" } do
					local v = workspace:GetAttribute(key)
					if typeof(v) == "Vector3" then
						table.insert(bad, v)
					end
				end
				for k = 0, 71 do
					local a = k / 72 * 2 * math.pi + 0.11
					local dir = Vector3.new(math.cos(a), 0, math.sin(a))
					local hit = workspace:Raycast(Vector3.new(mc.X, y, mc.Z) + dir * 5000, -dir * 5000, terrainOnly)
					if hit and math.abs(hit.Normal.Y) < 0.3 and hit.Material ~= Enum.Material.Ice and hit.Material ~= Enum.Material.Glacier then
						local ok = not workspace:Raycast(hit.Position + hit.Normal * 2, hit.Normal * 60, solidParams)
						for _, b in bad do
							if (b - hit.Position).Magnitude < 320 then
								ok = false
							end
						end
						-- la parete continua sopra e sotto (non uno spigolo)
						local above = workspace:Raycast(hit.Position + hit.Normal * 3 + UP * 10, -hit.Normal * 8, terrainOnly)
						local below = workspace:Raycast(hit.Position + hit.Normal * 3 - UP * 10, -hit.Normal * 8, terrainOnly)
						if ok and above and below then
							return hit.Position, flat(hit.Normal)
						end
					end
				end
				return nil, Vector3.xAxis
			end
			-- punto davanti alla parete dove il corpo intero (testa, petto, anche) e' fuori dalla
			-- roccia: i voxel del terreno sono a blocchi di 4 e la superficie trovata dal raggio non
			-- basta (prima lo scalatore era mezzo dentro la parete)
			local function outOfRock(p: Vector3, n: Vector3): Vector3
				-- raggi verso la parete all'altezza di testa, petto, anche, ginocchia e di lato: il
				-- corpo sta 1.4 studs davanti al punto di roccia piu' sporgente
				local side = Vector3.new(-n.Z, 0, n.X)
				local most = -math.huge
				for _, dy in { 2.6, 1.2, 0, -1.4, -2.8 } do
					for _, dx in { -1, 0, 1 } do
						local from = p + n * 30 + UP * dy + side * dx
						local hit = workspace:Raycast(from, -n * 60, terrainOnly)
						if hit then
							most = math.max(most, (hit.Position - p):Dot(n))
						end
					end
				end
				if most == -math.huge then
					most = 0
				end
				return p + n * (most + 2.4)
			end
			local function scaleActor(a: Actor?, f: number)
				if a then
					a.model:ScaleTo(a.model:GetScale() * f)
				end
			end

			if kind == "clip7" then
				-- GIRO DELLA MAPPA: inquadratura larga della montagna intera, poi la camera vola dietro
				-- al drago (ingrandito: prima sembrava minuscolo) attorno alla montagna, infine si
				-- allontana e la montagna si vede tutta
				local pts: { Vector3 } = {}
				local BIG = 2.5
				local function build()
					pts = {}
					-- i punti li calcola il server (ha tutta la montagna); qui solo se mancano
					for k = 0, ((d.OrbitCount or 0) :: number) - 1 do
						local p = d["Orbit" .. k]
						if typeof(p) == "Vector3" then
							table.insert(pts, p)
						end
					end
					if #pts > 3 then
						return
					end
					pts = {}
					local a0 = if gc then math.atan2(gface.Z - mc.Z, gface.X - mc.X) else 0
					local N = 22
					for k = 0, N do
						local f = k / N
						local a = a0 + f * 2 * math.pi
						local y = 520 + (top * 0.55 - 520) * (0.5 - 0.5 * math.cos(f * 2 * math.pi))
						local r = math.max(surfaceR(a, y), surfaceR(a, y - 110), surfaceR(a, y + 110)) + 190
						table.insert(pts, Vector3.new(mc.X + math.cos(a) * r, y, mc.Z + math.sin(a) * r))
					end
				end
				local function path(u: number): Vector3
					return catmull(pts, u)
				end
				local wideDir = Vector3.zero
				-- 1) la montagna intera, il drago passa davanti (3.5 s)
				add({
					dur = 3.5,
					at = Vector3.new(mc.X, top * 0.3, mc.Z),
					preload = around,
					smooth = 2,
					start = function()
						build()
						scaleActor(adult, BIG)
						pose(adult, "fly", 0.5)
						wideDir = flat(pts[1] - mc)
					end,
					update = function(u)
						flyAlong(adult, path, u * 0.02, 2.4)
					end,
					cam = function(u)
						local p = pts[1] or Vector3.zero
						local camPos = p + wideDir * (420 - 300 * smooth(u)) + UP * (60 - 30 * u)
						return CFrame.lookAt(camPos, (p + Vector3.new(mc.X, top * 0.45, mc.Z)) / 2)
					end,
				})
				-- 2) il giro: un arco di ~120 gradi (un giro intero in 15 s voleva dire 1000 studs al
				-- secondo: la camera restava indietro, dentro la roccia), camera dietro e di lato
				add({
					dur = 15,
					at = Vector3.new(mc.X, top * 0.4, mc.Z),
					smooth = 6,
					follow = true,
					update = function(u)
						flyAlong(adult, path, 0.02 + u * 0.3, 2.4)
					end,
					cam = function(u)
						local k = 0.02 + u * 0.3
						local p = path(k)
						local ahead = path(math.min(1, k + 0.012))
						local out = flat(p - Vector3.new(mc.X, p.Y, mc.Z))
						local back = (ahead - p).Unit
						-- il drago al centro, la parete della montagna dietro di lui
						return CFrame.lookAt(p - back * 50 + out * 32 + UP * 12, p + back * 18 - out * 6)
					end,
				})
				-- 3) la camera si allontana: tutta la montagna con il drago davanti (4 s)
				add({
					dur = 4,
					at = Vector3.new(mc.X, top * 0.4, mc.Z),
					smooth = 1.6,
					update = function(u)
						flyAlong(adult, path, 0.32 + u * 0.04, 2.4)
						if u >= 0.999 then
							scaleActor(adult, 1 / BIG)
						end
					end,
					cam = function(u)
						local p = path(0.32 + u * 0.04)
						local out = flat(p - Vector3.new(mc.X, p.Y, mc.Z))
						local d = 60 + (mR * 2.2) * smooth(u)
						return CFrame.lookAt(p + out * d + UP * (20 + top * 0.25 * smooth(u)), p:Lerp(Vector3.new(mc.X, top * 0.42, mc.Z), smooth(u)))
					end,
				})
			elseif kind == "clip8" then
				-- UNA SOLA MAPPA: dallo scalatore appeso a una parete vera la camera si allontana senza
				-- tagli fino a mostrare tutta la montagna
				local spot, n = wallSpot(top * 0.22)
				if spot then
					local side = Vector3.new(-n.Z, 0, n.X)
					local at = spot + n * 1.3
					local body: Model? = nil
					local dir = (n * 0.85 + side * 0.35 + UP * 0.3).Unit
					local far = Vector3.new(mc.X, top * 0.42, mc.Z)
					add({
						dur = 15,
						at = at,
						preload = around,
						start = function()
							body = cloneBody()
							at = outOfRock(spot, n) -- qui il terreno e' caricato
						end,
						update = function(u)
							if body then
								(body :: Model):PivotTo(CFrame.lookAt(at, at - n) * CFrame.Angles(deg(6), 0, 0))
								climbPose(body, os.clock())
							end
							if u >= 0.999 and body then
								(body :: Model):Destroy()
								body = nil
							end
						end,
						cam = function(u)
							local d = 9 * 450 ^ (u ^ 1.1)
							local look = (at - n * 1):Lerp(far, smooth(math.clamp((u - 0.15) / 0.75, 0, 1)))
							return CFrame.lookAt(at + dir * d, look)
						end,
					})
				end
			elseif kind == "clip9" then
				-- RAMPINO: scivola dalla parete, cade, all'ultimo spara il rampino che si aggancia alla
				-- coda di un drago che passa; resta appeso sotto e oscilla piano (pendolo)
				local spot, n = wallSpot(top * 0.2)
				if spot then
					local side = Vector3.new(-n.Z, 0, n.X)
					local at = spot + n * 1.3
					local fallEnd = at + n * 16 - UP * 48
					local dpts = {
						at - side * 260 + n * 90 - UP * 60,
						fallEnd - side * 70 + n * 30 + UP * 32,
						fallEnd + side * 40 + n * 45 + UP * 60,
						at + side * 150 + n * 110 + UP * 130,
						at + side * 260 + n * 130 + UP * 220,
					}
					-- il drago arriva sopra lo scalatore proprio quando spara (u = 0.33)
					local function dragonAt(u: number): Vector3
						local uu = if u < 0.33 then u / 0.33 * 0.25 else 0.25 + (u - 0.33) / 0.67 * 0.75
						return catmull(dpts, uu)
					end
					local function tail(): Vector3
						if not adult then
							return dragonAt(0.33)
						end
						local cf, size = adult.model:GetBoundingBox()
						return cf.Position - cf.LookVector * size.Z * 0.32 - UP * size.Y * 0.15
					end
					local body: Model? = nil
					local rope = Instance.new("Part")
					rope.Anchored, rope.CanCollide, rope.CanQuery, rope.CanTouch = true, false, false, false
					rope.Color = Color3.fromRGB(90, 70, 50)
					rope.Material = Enum.Material.Fabric
					local hook = Instance.new("Part")
					hook.Anchored, hook.CanCollide, hook.CanQuery, hook.CanTouch = true, false, false, false
					hook.Size = Vector3.new(0.8, 0.8, 1.4)
					hook.Color = Color3.fromRGB(60, 60, 66)
					hook.Material = Enum.Material.Metal
					local pos = at
					local last = 0
					local hooked = false
					add({
						dur = 11,
						at = at,
						preload = { fallEnd, dpts[3], dpts[4], dpts[5] },
						smooth = 3,
						start = function()
							body = cloneBody()
							pose(adult, "fly", 0.55)
							rope.Parent = workspace
							at = outOfRock(spot, n)
							pos = at
							last = os.clock()
						end,
						update = function(u)
							local dt = math.min(0.05, os.clock() - last)
							last = os.clock()
							flyAlong(adult, dragonAt, u, 2.2)
							local t = os.clock()
							if u < 0.12 then
								pos = at + n * (u / 0.12) * 1.2
								climbPose(body, t)
							elseif u < 0.35 then
								local f = (u - 0.12) / 0.23
								pos = at:Lerp(fallEnd, f * f * (1.6 - 0.6 * f))
								fallPose(body, t)
							else
								-- appeso: segue la coda del drago con un po' di ritardo (pendolo)
								local target = tail() - UP * 20
								pos = pos:Lerp(target, 1 - math.exp(-dt * 3.2))
								hangPose(body, t)
							end
							if body then
								local spin = if u > 0.12 and u < 0.35 then CFrame.Angles((u - 0.12) * 4, 0, (u - 0.12) * 2) else CFrame.identity
								;(body :: Model):PivotTo(CFrame.lookAt(pos, pos - n) * spin)
							end
							-- il rampino parte dalla mano e vola fino alla coda (0.31 - 0.35)
							if u >= 0.31 then
								if not hooked then
									hooked = true
									hook.Parent = workspace
									shake = 1
								end
								local hand = pos + UP * 2.6
								local reach = math.clamp((u - 0.31) / 0.04, 0, 1)
								local tip = hand:Lerp(tail(), reach)
								hook.CFrame = CFrame.lookAt(tip, tip + (tip - hand).Unit)
								rope.Size = Vector3.new(0.22, 0.22, math.max(0.1, (tip - hand).Magnitude))
								rope.CFrame = CFrame.lookAt((hand + tip) / 2, tip)
							end
							if u >= 0.999 then
								rope:Destroy()
								hook:Destroy()
								if body then
									(body :: Model):Destroy()
									body = nil
								end
							end
						end,
						cam = function(u)
							if u < 0.35 then
								return CFrame.lookAt(at + n * 30 + side * 16 - UP * 8, pos)
							end
							local d = adult and adult.model:GetPivot().Position or pos
							local mid = (pos + d) / 2
							return CFrame.lookAt(mid + n * 75 - side * 30 + UP * 8, mid)
						end,
					})
				end
			elseif kind == "clip10" then
				-- GAS: col drago Gelo la vita crolla, stacco, col drago Gas si attraversa la nebbia
				local gC = workspace:GetAttribute("GasCenter1") or gasC
				local gelo = actor(props, "Gelo")
				local mid = gC :: Vector3
				local dir = Vector3.new(1, 0, 0.35).Unit
				local side = Vector3.new(-dir.Z, 0, dir.X)
				local a, b = mid - dir * 45, mid + dir * 45
				local body: Model? = nil
				local hp: Frame? = nil
				local function bar(m: Model): Frame
					local bb = Instance.new("BillboardGui")
					bb.Size = UDim2.fromScale(5, 0.5)
					bb.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
					bb.AlwaysOnTop = true
					bb.Adornee = m:FindFirstChild("Head") or m.PrimaryPart
					local back = Instance.new("Frame")
					back.Size = UDim2.fromScale(1, 1)
					back.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
					back.BorderSizePixel = 0
					back.Parent = bb
					local fill = Instance.new("Frame")
					fill.Size = UDim2.fromScale(1, 1)
					fill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
					fill.BorderSizePixel = 0
					fill.Parent = back
					bb.Parent = m
					return fill
				end
				local function walker(dragon: Actor?, dur: number, dies: boolean): Shot
					return {
						dur = dur,
						at = mid,
						smooth = 4,
						start = function()
							if body then
								(body :: Model):Destroy()
							end
							body = cloneBody()
							if body then
								hp = bar(body :: Model)
							end
							hide(gelo)
							hide(gas)
							pose(dragon, "walk", 0.9)
							flash(s)
						end,
						update = function(u)
							local p = groundAt(a:Lerp(b, u * 0.8)) + UP * 3
							local fallen = dies and u > 0.8
							if body then
								local cf = CFrame.lookAt(p, p + dir)
								if fallen then
									cf = cf * CFrame.new(0, -2 * math.min(1, (u - 0.8) / 0.1), 0) * CFrame.Angles(-math.rad(85) * math.min(1, (u - 0.8) / 0.1), 0, 0)
								end
								(body :: Model):PivotTo(cf)
								walkPose(body, os.clock(), if fallen then 0 else 1)
							end
							if dragon and not fallen then
								standAt(dragon, p + side * 7 - dir * 2, dir)
							end
							if hp then
								local life = if dies then math.max(0.02, 1 - u * 1.2) else 1
								hp.Size = UDim2.fromScale(life, 1)
								hp.BackgroundColor3 = if life < 0.35 then Color3.fromRGB(230, 60, 50) else Color3.fromRGB(80, 220, 90)
							end
							if dies and u > 0.25 and math.random() < 0.05 then
								flash(s, s.red)
							end
						end,
						cam = function(u)
							local p = a:Lerp(b, u * 0.8)
							return CFrame.lookAt(groundAt(p) + side * 26 + UP * 9 - dir * 6, groundAt(p) + UP * 4 + dir * 4)
						end,
					}
				end
				add(walker(gelo, 6, true))
				add(walker(gas, 6.5, false))
				local cleanup = shots[#shots]
				local upd = cleanup.update
				cleanup.update = function(u)
					if upd then
						upd(u)
					end
					if u >= 0.999 and body then
						(body :: Model):Destroy()
						body = nil
					end
				end
			elseif kind == "clip11" then
				-- GIORNO 1 / GIORNO 30: tenda col cucciolo, stacco, chalet sul costone con l'adulto, poi
				-- l'adulto vola verso la valle e la camera si allontana fino a tutta la montagna
				local tentCf, chaletCf = d.TentCF, d.ChaletCF
				local tent = props and props:FindFirstChild("CasaTenda")
				local chalet = props and props:FindFirstChild("CasaChalet")
				if typeof(tentCf) == "CFrame" and typeof(chaletCf) == "CFrame" then
					local body: Model? = nil
					local function placeBody(cf: CFrame, offset: Vector3)
						if not body then
							body = cloneBody()
						end
						local p = groundAll((cf * CFrame.new(offset)).Position) + UP * 3
						if body then
							(body :: Model):PivotTo(CFrame.lookAt(p, p + cf.LookVector))
						end
					end
					-- la casa guarda la valle (LookVector): la camera sta dal lato della valle, in alto,
					-- cosi' non entra mai nella montagna
					local function frontOrbit(cf: CFrame, r: number, h: number, look: number): (number) -> CFrame
						local c = cf.Position
						local out = flat(cf.LookVector)
						local base = math.atan2(out.Z, out.X)
						return function(u)
							local a = base - 0.35 + u * 0.5
							return CFrame.lookAt(c + Vector3.new(math.cos(a) * r, h, math.sin(a) * r), c + UP * look)
						end
					end
					add({
						dur = 4.2,
						at = tentCf.Position,
						preload = { chaletCf.Position, chaletCf.Position + chaletCf.LookVector * 300, if typeof(d.CabinCF) == "CFrame" then (d.CabinCF :: CFrame).Position else chaletCf.Position },
						smooth = 3,
						start = function()
							if tent and tent:IsA("Model") then
								tent:PivotTo(tentCf)
							end
							placeBody(tentCf, Vector3.new(4, 0, -16))
							standAt(baby, (tentCf * CFrame.new(-4, 0, -14)).Position, tentCf.LookVector)
							pose(baby, "idle")
							hide(adult)
						end,
						update = function()
							walkPose(body, os.clock(), 0)
						end,
						cam = frontOrbit(tentCf, 36, 12, 5),
					})
					-- giorno 10: la baita sul pendio col drago cresciuto (il cucciolo piu' grande)
					local cabinCf = d.CabinCF
					local cabin = props and props:FindFirstChild("CasaBaita")
					if typeof(cabinCf) == "CFrame" then
						add({
							dur = 4,
							at = cabinCf.Position,
							smooth = 3,
							start = function()
								flash(s)
								if tent and tent:IsA("Model") then
									tent:PivotTo(CFrame.new(0, -600, 0))
								end
								if cabin and cabin:IsA("Model") then
									cabin:PivotTo(cabinCf)
								end
								placeBody(cabinCf, Vector3.new(6, 0, -22))
								scaleActor(baby, 1.6)
								standAt(baby, (cabinCf * CFrame.new(-8, 0, -20)).Position, cabinCf.LookVector)
							end,
							update = function(u)
								walkPose(body, os.clock(), 0)
								if u >= 0.999 then
									scaleActor(baby, 1 / 1.6)
									if cabin and cabin:IsA("Model") then
										cabin:PivotTo(CFrame.new(0, -600, 0))
									end
								end
							end,
							cam = frontOrbit(cabinCf, 60, 20, 8),
						})
					end
					-- il drago adulto sulla pedana, di lato allo chalet (non davanti, sul vuoto)
					local perch = groundAll((chaletCf * CFrame.new(-24, 0, 6)).Position) + UP * 2
					add({
						dur = 4.5,
						at = chaletCf.Position,
						smooth = 3,
						start = function()
							flash(s)
							shake = 0.6
							hide(baby)
							if chalet and chalet:IsA("Model") then
								chalet:PivotTo(chaletCf)
							end
							placeBody(chaletCf, Vector3.new(10, 0, -24))
							standAt(adult, perch, chaletCf.LookVector)
							pose(adult, "idle", 0.7)
						end,
						cam = frontOrbit(chaletCf, 95, 34, 10),
					})
					-- vola verso la valle e sale; la camera si allontana fino a tutta la montagna
					local function flight(u: number): Vector3
						return perch + UP * (10 + 160 * u * u) + chaletCf.LookVector * 300 * u
					end
					local out = flat(chaletCf.LookVector)
					add({
						dur = 5.5,
						at = chaletCf.Position + chaletCf.LookVector * 200,
						preload = around,
						smooth = 1.8,
						start = function()
							scaleActor(adult, 1.6)
							pose(adult, "fly", 0.6)
						end,
						update = function(u)
							flyAlong(adult, flight, u * 0.98, 2.2)
							if u >= 0.999 then
								scaleActor(adult, 1 / 1.6)
								if body then
									(body :: Model):Destroy()
									body = nil
								end
								for _, h in { tent, chalet } do
									if h and h:IsA("Model") then
										h:PivotTo(CFrame.new(0, -600, 0))
									end
								end
							end
						end,
						cam = function(u)
							local p = flight(u * 0.98)
							local k = smooth(u)
							local camPos = (chaletCf.Position + out * 110 + UP * 40):Lerp(Vector3.new(mc.X, 0, mc.Z) + out * mR * 2.3 + UP * top * 0.5, k)
							return CFrame.lookAt(camPos, p:Lerp(Vector3.new(mc.X, top * 0.42, mc.Z), k * 0.85))
						end,
					})
				end
			elseif kind == "clip12" then
				-- GYM ARC: tagli veloci agli attrezzi (panca, manubri, squat, sacco) con bilanciere e
				-- manubri in mano, poi lo stesso scalatore sale veloce una parete di roccia in alto (il
				-- server ha gia' calcolato i punti del corpo fuori dalla roccia) e la camera si allarga
				local gymFolder = workspace:FindFirstChild("Palestra")
				local stations: { BasePart } = {}
				for _, want in { "bench", "curl", "squat", "box" } do
					for _, dsc in (if gymFolder then gymFolder:GetDescendants() else {}) :: { Instance } do
						if dsc:IsA("BasePart") and dsc:GetAttribute("Exercise") == want then
							table.insert(stations, dsc)
							break
						end
					end
				end
				local body: Model? = nil
				local gc0 = workspace:GetAttribute("GymCenter")
				for k, st in stations do
					local poseCf = st:GetAttribute("Pose") :: CFrame
					if st:GetAttribute("Standing") then
						poseCf += UP * 3
					end
					local kindEx = st:GetAttribute("Exercise") :: string
					local per = GymAnim.PERIOD[kindEx] or 1.5
					local side = poseCf.RightVector
					add({
						dur = 1.6,
						at = if typeof(gc0) == "Vector3" then gc0 else poseCf.Position,
						start = function()
							if not body then
								body = cloneBody()
							end
							if k > 1 then
								flash(s)
							end
						end,
						update = function(u)
							if body then
								(body :: Model):PivotTo(poseCf)
								GymAnim.poseModel(body :: Model, kindEx, (u * 1.6 / per) % 1)
							end
							-- il draghetto svolazza accanto e guarda l'allenamento
							if baby then
								pose(baby, "fly", 1)
								local bp = poseCf.Position + side * 5.5 + UP * (4.5 + math.sin(os.clock() * 2.4) * 0.6) - poseCf.LookVector * 1.5
								baby.model:PivotTo(CFrame.lookAt(bp, poseCf.Position + UP * 2))
							end
						end,
						cam = function(u)
							local p = poseCf.Position
							return CFrame.lookAt(p + side * (7 + u) + UP * 2 + poseCf.LookVector * 5, p + UP * 0.5)
						end,
					})
				end
				-- la parete: punti dal server (ClimbN), altrimenti la parete delle clip 8 e 9
				local pts: { Vector3 } = {}
				for i = 0, ((d.ClimbCount or 0) :: number) - 1 do
					local v = d["Climb" .. i]
					if typeof(v) == "Vector3" then
						table.insert(pts, v)
					end
				end
				local n: Vector3 = if typeof(d.ClimbNormal) == "Vector3" then d.ClimbNormal else Vector3.xAxis
				if #pts < 2 then
					local spot, n0 = wallSpot(top * 0.2)
					if spot then
						n = n0
						local p0 = outOfRock(spot, n0)
						pts = { p0, p0 + UP * 90 }
					end
				end
				if #pts >= 2 then
					local wallSide = Vector3.new(-n.Z, 0, n.X)
					local climbAxes: { Model } = {}
					add({
						dur = 7,
						at = pts[1],
						preload = { pts[1], pts[#pts], pts[1] + n * 300 },
						smooth = 3,
						start = function()
							flash(s)
							shake = 0.5
							if body then
								GymAnim.clearModel(body :: Model)
							else
								body = cloneBody()
							end
							-- due piccozze in mano (prima il sosia arrampicava a mani vuote)
							for _ = 1, 2 do
								local a = sceneAxe()
								a.Parent = workspace
								table.insert(climbAxes, a)
							end
						end,
						update = function(u)
							local p = catmull(pts, u)
							if body then
								(body :: Model):PivotTo(CFrame.lookAt(p, p - n) * CFrame.Angles(deg(6), 0, 0))
								climbPose(body, os.clock() * 3)
								holdAxes(body :: Model, climbAxes)
							end
							-- il draghetto sale accanto allo scalatore
							if baby then
								pose(baby, "fly", 1.2)
								local bp = p + n * 6 + wallSide * 6 + UP * (1.5 + math.sin(os.clock() * 2.2) * 0.8)
								baby.model:PivotTo(CFrame.lookAt(bp, bp + UP * 3 - n * 2))
							end
							if u >= 0.999 then
								if body then
									(body :: Model):Destroy()
									body = nil
								end
								for _, a in climbAxes do
									a:Destroy()
								end
								table.clear(climbAxes)
								hide(baby)
							end
						end,
						cam = function(u)
							local p = catmull(pts, u)
							local k = smooth(u)
							local dist = 12 + 300 * k
							return CFrame.lookAt(p + n * dist + wallSide * (4 + 70 * k) + UP * (3 + dist * 0.3), p:Lerp(Vector3.new(mc.X, p.Y + 300, mc.Z), k * 0.35))
						end,
					})
				end
			elseif kind == "clip13" then
				-- DRAGON vs CRYSTAL: il cucciolo vola in cerchio nell'arena e spara ai cristalli dalla
				-- bocca (un colpo ogni mezzo secondo, effetti del suo elemento), poi evolve; la camera
				-- resta sull'adulto (ruggito) e poi sale all'indietro fino a mostrare la montagna
				local DragonConfigC = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DragonConfig"))
				local c = train
				local function circle(u: number): Vector3
					local a = u * math.pi * 1.6
					return c + Vector3.new(math.cos(a) * 30, 22 + math.sin(u * 9) * 2, math.sin(a) * 30)
				end
				local nextShot = 0
				local k = 0
				add({
					dur = 8,
					at = c,
					smooth = 4,
					start = function()
						scaleActor(baby, 1.5)
						pose(baby, "fly", 0.9)
						hide(adult)
					end,
					update = function(u)
						flyAlong(baby, circle, u, 1.4)
						if baby and os.clock() > nextShot then
							nextShot = os.clock() + 0.5
							k = k % DragonConfigC.TRAINING.TARGETS + 1
							local target = DragonConfigC.crystalAt(c, k, workspace:GetServerTimeNow())
							DragonVFX.shot("Eclissi", DragonVFX.mouth(baby.model, target), target, Color3.fromRGB(255, 160, 60))
						end
						if u >= 0.999 then
							scaleActor(baby, 1 / 1.5)
						end
					end,
					cam = function(u)
						local p = circle(u)
						local dir = (circle(math.min(1, u + 0.01)) - p).Unit
						return CFrame.lookAt(p - dir * 14 + UP * 5, p + dir * 30 - UP * 6)
					end,
				})
				local center = c + Vector3.new(0, 0, 8)
				add(evolution(s, center, baby, adult, 4.5, 0.45))
				-- l'adulto: giro stretto attorno, ruggito di fuoco verso il cielo, poi la camera
				-- arretra e sale dal lato opposto alla montagna, che appare dietro al drago
				local toMtn = flat(Vector3.new(mc.X, 0, mc.Z) - Vector3.new(center.X, 0, center.Z))
				local mountainLook = Vector3.new(mc.X, top * 0.55, mc.Z)
				-- da dove arretrare: la prima direzione da cui ne' il drago ne' la montagna sono coperti
				-- dallo scheletro dell'arena (o da una collina); prima era sempre quella opposta alla
				-- montagna e lo scheletro gigante riempiva l'inquadratura
				local backDir = -toMtn
				do
					local arena = workspace:FindFirstChild("ZonaAddestramento")
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = if arena then { arena, workspace.Terrain } else { workspace.Terrain }
					for _, off in { 0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35, 1.8, -1.8, 2.4, -2.4 } do
						local dir = CFrame.Angles(0, off, 0):VectorToWorldSpace(-toMtn)
						local ok = true
						for _, dist in { 120, 264 } do
							local eye = center + dir * dist + UP * (9 + 120 * (dist - 34) / 230)
							local toDragon = workspace:Raycast(eye, (center + UP * 12) - eye, params)
							local toMountain = workspace:Raycast(eye, (mountainLook - eye) * 0.6, params)
							if toDragon or toMountain then
								ok = false
								break
							end
						end
						if ok then
							backDir = dir
							break
						end
					end
				end
				local roared = 0
				add({
					dur = 8,
					at = center,
					preload = { center - toMtn * 260 + UP * 150 },
					smooth = 3,
					start = function()
						roared = 0
						pose(adult, "idle", 0.6)
					end,
					update = function(u)
						if adult and ((roared == 0 and u > 0.1) or (roared == 1 and u > 0.3)) then
							roared += 1
							local m = adult.model
							local sky = DragonVFX.mouth(m) + UP * 45 + toMtn * 12
							DragonVFX.shot("Eclissi", DragonVFX.mouth(m, sky), sky, ORANGE)
							shake = 0.9
						end
					end,
					cam = function(u)
						local turn = (1 - smooth(u / 0.4)) * 1.3
						local k2 = smooth((u - 0.4) / 0.6)
						local dirC = CFrame.Angles(0, turn, 0):VectorToWorldSpace(backDir)
						local dist = 34 + 230 * k2
						local look = (center + UP * 12):Lerp(mountainLook, k2 * 0.8)
						return CFrame.lookAt(center + dirC * dist + UP * (9 + 120 * k2), look)
					end,
				})
			elseif kind == "clip17" then
				-- SOPRA LE NUVOLE: si sale dalle nuvole e si scopre un'isola volante sopra la montagna,
				-- lo scalatore passa col rampino da un'isola all'altra, il drago plana tra le isole
				local isl: { { p: Vector3, r: number } } = {}
				for k = 1, (d.IslandCount or 0) :: number do
					local p, r = d["Island" .. k], d["IslandR" .. k]
					if typeof(p) == "Vector3" then
						table.insert(isl, { p = p, r = if type(r) == "number" then r else 20 })
					end
				end
				if #isl >= 2 then
					-- le due isole piu' vicine tra loro: il salto col rampino
					local A, B, bd = isl[1], isl[2], math.huge
					for i = 1, #isl do
						for j = i + 1, #isl do
							local dd = (isl[i].p - isl[j].p).Magnitude
							if dd < bd then
								A, B, bd = isl[i], isl[j], dd
							end
						end
					end
					local ab = flat(B.p - A.p)
					local side = Vector3.new(-ab.Z, 0, ab.X)
					local all = {}
					for _, i in isl do
						table.insert(all, i.p)
					end
					-- 1. dalle nuvole: la camera sale da sotto il bordo dell'isola e la scopre
					add({
						dur = 4,
						at = A.p,
						preload = all,
						start = function()
							pose(adult, "fly", 0.5)
						end,
						update = function(u)
							flyAlong(adult, function(x: number): Vector3
								return A.p + side * (-170 + 340 * x) + UP * (-25 + 45 * x) - ab * (A.r + 30)
							end, u, 2.2)
						end,
						cam = function(u)
							local k = smooth(u)
							local from = A.p - ab * (A.r * 3.2) + side * 30 - UP * (A.r * 1.6)
							local to = A.p - ab * (A.r * 2.1) + side * 18 + UP * (A.r * 0.35)
							return CFrame.lookAt(from:Lerp(to, k), A.p + UP * (6 * k - A.r * 0.5 * (1 - k)))
						end,
					})
					-- 2. il rampino: la corda si aggancia al bordo dell'altra isola e lo scalatore vola
					-- sotto, in un arco, fino a terra dall'altra parte
					local startP = A.p + ab * (A.r * 0.8) + UP * 3.2
					local endP = B.p - ab * (B.r * 0.8) + UP * 3.2
					local span = (endP - startP).Magnitude
					local sag = math.min(45, span * 0.35)
					local function swing(w: number): Vector3
						local k = smooth(w)
						return startP:Lerp(endP, k) - UP * (math.sin(k * math.pi) * sag)
					end
					local body: Model? = nil
					local rope = Instance.new("Part")
					rope.Anchored, rope.CanCollide, rope.CanQuery, rope.CanTouch = true, false, false, false
					rope.Color = Color3.fromRGB(90, 70, 50)
					rope.Material = Enum.Material.Fabric
					local hook = Instance.new("Part")
					hook.Anchored, hook.CanCollide, hook.CanQuery, hook.CanTouch = true, false, false, false
					hook.Size = Vector3.new(1, 1, 1.6)
					hook.Color = Color3.fromRGB(60, 60, 66)
					hook.Material = Enum.Material.Metal
					local function where(u: number): (Vector3, number)
						local w = math.clamp((u - 0.18) / 0.72, 0, 1)
						return (if u < 0.18 then startP else swing(w)), w
					end
					add({
						dur = 5,
						at = startP,
						start = function()
							body = cloneBody()
							rope.Parent = workspace
							hook.Parent = workspace
						end,
						update = function(u)
							local p, w = where(u)
							local anchor = endP + UP * 0.6
							local ahead = swing(math.min(1, w + 0.03)) - swing(math.max(0, w - 0.03))
							local look = if u < 0.18 or ahead.Magnitude < 0.01 then ab else flat(ahead)
							if body then
								(body :: Model):PivotTo(CFrame.lookAt(p, p + look) * CFrame.Angles(math.rad(-25 * math.sin(w * math.pi)), 0, 0))
								limbs(body, {
									RightShoulder = CFrame.Angles(deg(165), 0, deg(-5)),
									LeftShoulder = CFrame.Angles(deg(if u < 0.18 then 20 else 150), 0, deg(5)),
									RightHip = CFrame.Angles(deg(30 * math.sin(w * math.pi)), 0, 0),
									LeftHip = CFrame.Angles(deg(-20 * math.sin(w * math.pi)), 0, 0),
									RightKnee = CFrame.Angles(deg(-40), 0, 0),
									LeftKnee = CFrame.Angles(deg(-25), 0, 0),
								})
							end
							local hand = p + UP * 2.8 + look * 0.6
							-- il gancio vola fino all'altra isola, poi la corda tira
							local hk = if u < 0.18 then hand:Lerp(anchor, smooth(u / 0.18)) else anchor
							hook.CFrame = CFrame.lookAt(hk, hk + ab)
							if u < 0.93 then
								rope.Size = Vector3.new(0.22, 0.22, math.max(0.1, (hk - hand).Magnitude))
								rope.CFrame = CFrame.lookAt((hk + hand) / 2, hk)
								rope.Parent = workspace
							else
								rope.Parent = nil
								hook.Parent = nil
							end
							if u >= 0.999 then
								rope.Parent, hook.Parent = nil, nil
								if body then
									(body :: Model):Destroy()
									body = nil
								end
							end
						end,
						cam = function(u)
							local mid = (startP + endP) / 2
							local p = where(u)
							return CFrame.lookAt(mid + side * (span * 0.85 + 25) - UP * 6, p:Lerp(mid, 0.45))
						end,
					})
					-- 3. largo: il drago plana nell'anello di isole, sotto la vetta e il mare di nuvole
					local center = Vector3.new(summit.X, 0, summit.Z)
					local avgY, ringR = 0, 60
					for _, i in isl do
						avgY += i.p.Y / #isl
						ringR = math.max(ringR, (Vector3.new(i.p.X, 0, i.p.Z) - center).Magnitude)
					end
					local mid = Vector3.new(center.X, avgY, center.Z)
					add({
						dur = 6,
						at = mid,
						preload = all,
						smooth = 2,
						start = function()
							pose(adult, "fly", 0.45)
						end,
						update = function(u)
							flyAlong(adult, function(x: number): Vector3
								local a = 0.4 + x * 2.2
								return mid + Vector3.new(math.cos(a) * ringR * 0.85, -12 + math.sin(x * 6) * 8, math.sin(a) * ringR * 0.85)
							end, u, 2.6)
						end,
						cam = function(u)
							local a = 0.1 + u * 1.1
							local r = ringR + 150 + 90 * u
							return CFrame.lookAt(mid + Vector3.new(math.cos(a) * r, 55 + 70 * u, math.sin(a) * r), mid - UP * 25)
						end,
					})
				end
			elseif kind == "clip18" then
				-- OGNI CRISTALLO, OGNI BIOMA: stacchi rapidi sui cristalli di Mirko, uno per elemento,
				-- dal basso verso la vetta; la camera gira attorno e scoppia una scintilla del colore del
				-- cristallo. Alla fine la montagna intera
				local Sfx = require(script.Parent.Sfx)
				local COLORS: { [string]: Color3 } = {
					Roccia = Color3.fromRGB(255, 140, 60),
					Ossa = Color3.fromRGB(240, 235, 210),
					Tempesta = Color3.fromRGB(150, 205, 255),
					Fulmine = Color3.fromRGB(165, 120, 255),
					Cosmico = Color3.fromRGB(205, 120, 255),
					Eclissi = Color3.fromRGB(255, 170, 70),
					Gelo = Color3.fromRGB(140, 220, 255),
					Gas = Color3.fromRGB(90, 220, 255),
				}
				local list: { { p: Vector3, h: number, el: string } } = {}
				for k = 1, (d.CrysCount or 0) :: number do
					local p, h, el = d["Crys" .. k], d["CrysH" .. k], d["CrysEl" .. k]
					if typeof(p) == "Vector3" then
						table.insert(list, { p = p, h = math.max(if type(h) == "number" then h else 10, 4), el = tostring(el) })
					end
				end
				table.sort(list, function(a, b)
					return a.p.Y < b.p.Y
				end)
				for i, c in list do
					local col = COLORS[c.el] or Color3.new(1, 1, 1)
					-- abbastanza lontano e in alto da stare sopra gli altri cristalli della zona
					local r = c.h * 1.6 + 14
					local base = i * 1.7
					local look = c.p + UP * c.h * 0.1
					-- la camera non entra nella roccia (cristalli nelle grotte): si ferma prima della parete
					local function camPos(u: number): Vector3
						local a = base + u * 0.9
						local dist = r * (1.25 - 0.35 * smooth(u))
						local dir = Vector3.new(math.cos(a), 0.55 + 0.1 * smooth(u), math.sin(a)).Unit
						local hit = workspace:Raycast(look, dir * dist, terrainOnly)
						if hit then
							dist = math.max(3, (hit.Position - look).Magnitude - 2)
						end
						return look + dir * dist
					end
					add({
						dur = 2,
						at = c.p,
						start = function()
							task.delay(0.45, function()
								sparkBurst(c.p + UP * c.h * 0.3, col, math.clamp(c.h * 0.12, 1, 4))
								pcall(Sfx.play, if c.el == "Gelo" or c.el == "Tempesta" then "Ghiaccio" else "Vetro", c.p, 1)
							end)
						end,
						cam = function(u)
							return CFrame.lookAt(camPos(u), look)
						end,
					})
				end
				local o = Vector3.new(-1, 0, -0.25).Unit
				add({
					dur = 3.5,
					at = Vector3.new(mc.X, top * 0.5, mc.Z) + o * mR,
					cam = dolly(
						Vector3.new(mc.X, top * 0.35, mc.Z) + o * mR * 1.05,
						Vector3.new(mc.X, top * 0.75, mc.Z) + o * mR * 1.7,
						Vector3.new(mc.X, top * 0.45, mc.Z),
						Vector3.new(mc.X, top * 0.55, mc.Z)
					),
				})
			elseif kind == "clip19" then
				-- PICCOZZE: tre piccozze di Mirko una dopo l'altra, sospese e girate piano davanti a un
				-- cristallo (ASMR: il suono del ghiaccio a ogni cambio); l'ultima colpisce il cristallo, che
				-- va in pezzi
				local Sfx = require(script.Parent.Sfx)
				local axes: { Model } = {}
				for k = 1, 3 do
					local m = props and props:FindFirstChild("Ascia" .. k)
					if m and m:IsA("Model") then
						table.insert(axes, m)
					end
				end
				local crystal = props and props:FindFirstChild("CristalloScena")
				-- dove: davanti al cristallo di ghiaccio piu' grande (o in vetta), dal lato libero
				local spot: Vector3 = summit + UP * 4
				local rank = 0
				for k = 1, (d.CrysCount or 0) :: number do
					local r = if d["CrysEl" .. k] == "Gelo" then 3 elseif d["CrysEl" .. k] == "Tempesta" then 2 else 1
					if r > rank and typeof(d["Crys" .. k]) == "Vector3" then
						spot, rank = d["Crys" .. k] :: Vector3, r
					end
				end
				local open = Vector3.xAxis
				for a = 0, 7 do
					local dir = Vector3.new(math.cos(a * math.pi / 4), 0, math.sin(a * math.pi / 4))
					if not workspace:Raycast(spot + UP * 4, dir * 45, terrainOnly) then
						open = dir
						break
					end
				end
				local floor = groundAt(spot + open * 14)
				local stage = floor + UP * 5.5 -- dove gira la piccozza
				local crysAt = floor + open * -4
				if crystal and crystal:IsA("Model") then
					local _, size = crystal:GetBoundingBox()
					crystal:ScaleTo(crystal:GetScale() * 9 / math.max(size.Y, 0.1))
					local cf, s2 = crystal:GetBoundingBox()
					crystal:PivotTo(crystal:GetPivot() + (crysAt - Vector3.new(cf.X, cf.Y - s2.Y / 2, cf.Z)))
				end
				local function axeAt(m: Model, cf: CFrame)
					local box = m:GetBoundingBox()
					m:PivotTo(cf * box:ToObjectSpace(m:GetPivot()))
				end
				local camFrom = stage + open * 7.5 + UP * 1.2
				for k, m in axes do
					local _, size = m:GetBoundingBox()
					m:ScaleTo(m:GetScale() * 6 / math.max(size.X, size.Y, size.Z, 0.1))
					add({
						dur = 2.6,
						at = stage,
						start = function()
							for _, other in axes do
								other:PivotTo(CFrame.new(0, -500, 0))
							end
							flash(s)
							sparkBurst(stage, if k == 3 then GOLD else ICE, 1.6)
							pcall(Sfx.play, "Ghiaccio", stage, 0.8)
						end,
						update = function(u)
							axeAt(m, CFrame.new(stage + UP * math.sin(u * math.pi * 2) * 0.25) * CFrame.Angles(0, u * math.pi * 1.6 + k, math.rad(-12)))
						end,
						cam = function(u)
							return CFrame.lookAt(camFrom:Lerp(stage + open * 5.2 + UP * 0.6, smooth(u)), stage)
						end,
					})
				end
				-- il colpo: l'ultima piccozza cala sul cristallo, scintille e il cristallo esplode
				local hitDone = false
				local shards: { BasePart } = {}
				add({
					dur = 3.2,
					at = crysAt,
					start = function()
						hitDone = false
					end,
					update = function(u)
						local m = axes[#axes]
						if m then
							local k = smooth(math.clamp(u / 0.45, 0, 1))
							local swing = math.rad(-120 + 150 * k)
							local pivot = crysAt + open * 4.5 + UP * 6
							axeAt(m, CFrame.lookAt(pivot, pivot - open) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, 2.5, 0))
						end
						if u >= 0.45 and not hitDone then
							hitDone = true
							shake = 1.6
							flash(s)
							sparkBurst(crysAt + UP * 4, ICE, 3.5)
							pcall(Sfx.play, "Vetro", crysAt, 1)
							pcall(Sfx.play, "Ghiaccio", crysAt, 1)
							if crystal and crystal:IsA("Model") then
								for _, p in crystal:GetDescendants() do
									if p:IsA("BasePart") then
										p.LocalTransparencyModifier = 1
									end
								end
							end
							for i = 1, 16 do
								local sh = Instance.new("WedgePart")
								sh.Anchored, sh.CanCollide, sh.CanQuery, sh.CanTouch = true, false, false, false
								sh.Material = Enum.Material.Glass
								sh.Color = ICE
								sh.Transparency = 0.25
								sh.Size = Vector3.new(0.6, math.random() * 1.6 + 0.8, math.random() * 1.2 + 0.6)
								sh.CFrame = CFrame.new(crysAt + UP * (2 + math.random() * 5)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
								sh.Parent = workspace
								table.insert(shards, sh)
								local dir = (Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5) + open * 0.6).Unit
								TweenService:Create(sh, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									CFrame = sh.CFrame + dir * (8 + i % 5 * 3) - UP * 3,
									Transparency = 1,
								}):Play()
							end
						end
						if u >= 0.999 then
							for _, sh in shards do
								sh:Destroy()
							end
							table.clear(shards)
						end
					end,
					cam = function(u)
						local k = smooth(u)
						return CFrame.lookAt(crysAt + open * (14 + 6 * k) + UP * (4 + 2 * k) + Vector3.new(open.Z, 0, -open.X) * 5, crysAt + UP * 4)
					end,
				})
			elseif kind == "clip20" then
				-- DALL'UOVO AL DRAGO: l'uovo nel giardino interno della machiya, di notte sull'altare del
				-- tempio, si schiude (il cucciolo), all'alba il drago adulto vola via sopra i borghi
				local Lighting = game:GetService("Lighting")
				local Sfx = require(script.Parent.Sfx)
				local clock0 = Lighting.ClockTime
				local egg = props and props:FindFirstChild("UovoScena")
				-- l'uovo resta dritto come nel modello di Mirko; poggia con il fondo su p
				local eggRot = if egg and egg:IsA("Model") then egg:GetPivot().Rotation else CFrame.identity
				local function eggTo(p: Vector3, tilt: CFrame?)
					if egg and egg:IsA("Model") then
						egg:PivotTo(CFrame.new(p) * (tilt or CFrame.identity) * eggRot)
						local cf, size = egg:GetBoundingBox()
						egg:PivotTo(egg:GetPivot() + Vector3.new(p.X - cf.X, p.Y - (cf.Y - size.Y / 2), p.Z - cf.Z))
					end
				end
				if egg and egg:IsA("Model") then
					local _, size = egg:GetBoundingBox()
					egg:ScaleTo(egg:GetScale() * 2.6 / math.max(size.Y, 0.1))
				end
				local mcf = d.MachiyaCF
				local tcf, ts = d.TempioCF, (d.TempioScale or 1) :: number
				-- 1. il giardino interno della machiya, di giorno: la camera scende dal cielo
				if typeof(mcf) == "CFrame" then
					local m = mcf :: CFrame
					local eggP = m:PointToWorldSpace(Vector3.new(0.6, 0.6, 3.0))
					add({
						dur = 4,
						at = eggP,
						start = function()
							eggTo(eggP)
						end,
						update = function()
							setClock(15.5)
						end,
						cam = function(u)
							local k = smooth(u)
							local from = m:PointToWorldSpace(Vector3.new(-1, 34, 3))
							local to = m:PointToWorldSpace(Vector3.new(-3.6, 4.2, 5.4))
							return CFrame.lookAt(from:Lerp(to, k), eggP + UP * 0.8)
						end,
					})
				end
				if typeof(tcf) == "CFrame" then
					local t = tcf :: CFrame
					local eggP = t:PointToWorldSpace(Vector3.new(0, 5.35 * ts, 1.0 * ts))
					local glow = Instance.new("PointLight")
					glow.Color = ORANGE
					glow.Range = 14
					glow.Brightness = 0
					-- 2. di notte sull'altare del tempio: la luce dentro l'uovo pulsa
					add({
						dur = 3.5,
						at = eggP,
						start = function()
							eggTo(eggP)
							if egg and egg:IsA("Model") then
								glow.Parent = egg:FindFirstChildWhichIsA("BasePart", true)
							end
						end,
						update = function(u)
							setClock(0.5)
							glow.Brightness = 1.5 + math.sin(u * 18) * 1.2
						end,
						cam = function(u)
							local k = smooth(u)
							local from = t:PointToWorldSpace(Vector3.new(0, 7 * ts, -9.5 * ts))
							local to = t:PointToWorldSpace(Vector3.new(2.4 * ts, 6.4 * ts, -3.2 * ts))
							return CFrame.lookAt(from:Lerp(to, k), eggP + UP * 1.2)
						end,
					})
					-- 3. si schiude: l'uovo trema sempre di piu', crepe di luce, lampo, il cucciolo
					local hatched = false
					local nextCrack = 0
					add({
						dur = 4.5,
						at = eggP,
						start = function()
							hatched = false
							nextCrack = 0.15
							hide(baby)
							pose(baby, "idle")
						end,
						update = function(u)
							setClock(0.5)
							if not hatched then
								local a = math.rad(2 + 14 * u * u)
								eggTo(eggP, CFrame.Angles(math.sin(os.clock() * 31) * a, 0, math.cos(os.clock() * 27) * a))
								glow.Brightness = 2 + u * 4
								if u >= nextCrack then
									nextCrack += 0.16
									sparkBurst(eggP + UP * 1.3, ORANGE, 0.8)
									pcall(Sfx.play, "Roccia", eggP, 0.5)
								end
							end
							if u >= 0.68 and not hatched then
								hatched = true
								flash(s)
								shake = 1.2
								sparkBurst(eggP + UP * 1.5, GOLD, 2.5)
								pcall(Sfx.play, "Ruggito", eggP, 1)
								glow.Parent = nil
								if egg and egg:IsA("Model") then
									egg:PivotTo(CFrame.new(0, -500, 0))
								end
								if baby then
									local _, size = baby.model:GetBoundingBox()
									baby.model:ScaleTo(baby.model:GetScale() * 4.2 / math.max(size.Y, 0.1))
									local _, s2 = baby.model:GetBoundingBox()
									local p = eggP + UP * (s2.Y / 2)
									local front = t:VectorToWorldSpace(Vector3.new(0, 0, -1))
									baby.model:PivotTo(CFrame.lookAt(p, p + front))
								end
							end
						end,
						cam = function(u)
							local a = 0.5 - u * 0.9
							local r = (5.5 + 1.5 * u) * math.max(ts, 0.8)
							local front = t:VectorToWorldSpace(Vector3.new(0, 0, -1))
							local right = t:VectorToWorldSpace(Vector3.new(1, 0, 0))
							return CFrame.lookAt(eggP + front * math.cos(a) * r + right * math.sin(a) * r + UP * 2.2, eggP + UP * 1.4)
						end,
					})
					-- 4. all'alba il drago adulto esce dal cortile del tempio e vola sopra i borghi
					local front = t:VectorToWorldSpace(Vector3.new(0, 0, -1))
					local yard = t.Position + front * 30 * ts
					add({
						dur = 5,
						at = yard,
						start = function()
							hide(baby)
							pose(adult, "fly", 0.6)
						end,
						update = function(u)
							setClock(6.1 + u * 0.4)
							flyAlong(adult, function(x: number): Vector3
								return yard + front * (20 + 220 * x) + UP * (12 + 130 * x * x)
							end, u, 1.7)
							if u >= 0.999 then
								setClock(clock0)
							end
						end,
						cam = function(u)
							local k = smooth(u)
							local p = yard + front * (20 + 220 * k) + UP * (12 + 130 * k * k)
							return CFrame.lookAt(yard - front * 6 + UP * 5 + t:VectorToWorldSpace(Vector3.new(9, 0, 0)), p)
						end,
					})
				end
			elseif kind == "clip15" then
				-- WHICH HOUSE ARE YOU: tenda, baita, chalet, 3 secondi ciascuna. La camera sta sempre dal
				-- lato della valle (verso fuori dalla montagna) e controlla che tra lei e la casa non ci
				-- sia roccia (prima sulla baita passava dentro il pendio). Dopo lo chalet sale a spirale:
				-- il paesaggio e dove sta lo chalet rispetto alla montagna
				local list = {
					{ cf = d.TentCF, m = props and props:FindFirstChild("CasaTenda"), r = 34, h = 12 },
					{ cf = d.CabinCF, m = props and props:FindFirstChild("CasaBaita"), r = 60, h = 22 },
					{ cf = d.ChaletCF, m = props and props:FindFirstChild("CasaChalet"), r = 95, h = 34 },
				}
				local pre = {}
				for _, h in list do
					if typeof(h.cf) == "CFrame" then
						table.insert(pre, (h.cf :: CFrame).Position)
					end
				end
				for k, h in list do
					if typeof(h.cf) == "CFrame" then
						local cf = h.cf :: CFrame
						local c = cf.Position
						local out = flat(Vector3.new(c.X, 0, c.Z) - mc)
						local base = math.atan2(out.Z, out.X)
						local hUse, sweep = h.h, 0.6
						local function camAt(a: number): Vector3
							return c + Vector3.new(math.cos(a) * h.r, hUse, math.sin(a) * h.r)
						end
						add({
							dur = 3.2,
							at = c,
							preload = pre,
							smooth = 3,
							start = function()
								if k > 1 then
									flash(s)
								end
								for _, o in list do
									if o.m and o.m:IsA("Model") then
										o.m:PivotTo(if o == h then o.cf else CFrame.new(0, -600, 0))
									end
								end
								-- roccia tra camera e casa: piu' in alto e meno giro
								hUse, sweep = h.h, 0.6
								for _ = 1, 4 do
									local blocked = false
									for _, f in { -0.5, 0, 0.5 } do
										local from = c + UP * 6
										if workspace:Raycast(from, camAt(base + f * sweep) - from, solidParams) then
											blocked = true
										end
									end
									if not blocked then
										break
									end
									hUse *= 1.6
									sweep *= 0.5
								end
							end,
							cam = function(u)
								return CFrame.lookAt(camAt(base + (u - 0.5) * sweep), c + UP * 6)
							end,
						})
					end
				end
				local ch = d.ChaletCF
				if typeof(ch) == "CFrame" then
					local c = (ch :: CFrame).Position
					local out = flat(Vector3.new(c.X, 0, c.Z) - mc)
					local base = math.atan2(out.Z, out.X)
					local mid = Vector3.new(mc.X, c.Y + (top - c.Y) * 0.45, mc.Z)
					add({
						dur = 6.5,
						at = c,
						preload = { c + out * 500 + UP * 300, c + out * 700 + UP * 450 },
						smooth = 2,
						update = function(u)
							if u > 0.6 and adult then
								-- l'adulto passa davanti in volo verso la valle
								flyAlong(adult, function(x: number): Vector3
									return c + out * (60 + 500 * x) + UP * (40 + 120 * x)
								end, (u - 0.6) / 0.4, 1.4)
							end
						end,
						start = function()
							pose(adult, "fly", 0.7)
						end,
						cam = function(u)
							-- gira solo dal lato della valle (mai verso la montagna) allargandosi e salendo
							local k = smooth(u)
							local a = base + 0.3 - k * 1.5
							local r = 95 + 650 * k
							return CFrame.lookAt(c + Vector3.new(math.cos(a) * r, 34 + 420 * k, math.sin(a) * r), c:Lerp(mid, k * 0.7))
						end,
					})
				end
			end
		end
	end
	run(shots, s)
	for _, a in { baby, adult, gas } do
		hide(a)
	end
	if props then
		props:Destroy() -- solo qui sul client: alla prossima ripresa il server ne fa una nuova
	end
	for _, gui in hidden do
		gui.Enabled = true
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	s.gui:Destroy()
end

return Trailer
