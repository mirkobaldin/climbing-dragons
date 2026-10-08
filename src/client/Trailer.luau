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
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local PetAnimator = require(script.Parent.PetAnimator)
local KfsPlayer = require(script.Parent.KfsPlayer)

local player = Players.LocalPlayer

local Trailer = {}

local ORANGE = Color3.fromRGB(255, 170, 70)
local ICE = Color3.fromRGB(130, 210, 255)
local RED = Color3.fromRGB(255, 70, 60)
local GOLD = Color3.fromRGB(255, 220, 120)

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
	local function hideAll(m: Instance?)
		if not m then
			return
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
				d.LocalTransparencyModifier = 1
				table.insert(hiddenParts, d)
			end
		end
	end
	hideAll(me)
	hideAll(workspace:FindFirstChild("Pets"))
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
	-- un attimo in piu': il terreno lontano (biomi, cristalli) finisce di comparire
	task.wait(2.5)
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
	for _, shot in shots do
		focus(shot.at)
		if shot.start then
			shot.start()
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
	a.model:PivotTo(CFrame.lookAt(p + Vector3.new(0, bob, 0), p + dir) * CFrame.Angles(pitch, 0, math.clamp(-turn * 60, -0.7, 0.7)))
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
		local Cinematic = require(script.Parent.Cinematic)
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
				body = Cinematic.kit.cloneActor()
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
		local Cinematic = require(script.Parent.Cinematic)
		local body = Cinematic.kit.cloneActor()
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
	if kind == "clip4" or kind == "clip5" or kind == "clip6" or kind == "clip7" or kind == "clip8" or kind == "clip9" or kind == "clip10" or kind == "clip11" then
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
			local allies: { { a: Actor?, color: Color3, phase: number } } = {
				{ a = adult, color = Color3.fromRGB(255, 160, 60), phase = 0 },
				{ a = actor(props, "StormoGelo"), color = Color3.fromRGB(140, 220, 255), phase = 0.33 },
				{ a = actor(props, "StormoFulmine"), color = Color3.fromRGB(180, 130, 255), phase = 0.66 },
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
					if tracks.sit then
						tracks.sit:Play(0, 1)
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
				-- 1) il cratere: si scende verso il Titano immobile (3 s)
				add({
					dur = 3,
					at = throne,
					start = function()
						prepareYeti()
						for _, al in allies do
							hide(al.a)
						end
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
				add({
					dur = 6,
					at = throne,
					start = function()
						for _, al in allies do
							pose(al.a, "fly", 0.7)
						end
					end,
					update = function(u)
						flyAll(u)
						local t = os.clock()
						if t > nextShot then
							nextShot = t + 0.3
							turn = turn % #allies + 1
							local al = allies[turn]
							if al.a then
								fireball(al.a.model:GetPivot().Position, throne + HIT + side * (math.random() - 0.5) * 8, al.color)
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
						local a = 0.6 + u * 1.4
						return CFrame.lookAt(throne + out * 95 * math.cos(a * 0.4) + side * 80 * math.sin(a) + Vector3.new(0, 30, 0), throne + HIT)
					end,
				})
				-- 4) colpo finale: i tre insieme, lampo, il Titano crolla all'indietro (3 s)
				add({
					dur = 3,
					at = throne,
					start = function()
						for _, al in allies do
							if al.a then
								fireball(al.a.model:GetPivot().Position, throne + HIT, al.color)
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
								local cf0 = y:GetPivot()
								local fall = Instance.new("NumberValue")
								fall.Changed:Connect(function(v)
									y:PivotTo(cf0 * CFrame.new(0, -v * 3, v * 4) * CFrame.Angles(-v * 1.4, 0, 0))
								end)
								TweenService:Create(fall, TweenInfo.new(1, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Value = 1 }):Play()
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
					end,
					cam = dolly(throne + out * 60 + side * 35 + Vector3.new(0, 14, 0), throne + out * 80 + side * 40 + Vector3.new(0, 24, 0), throne + Vector3.new(0, 14, 0), throne + Vector3.new(0, 6, 0)),
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
								end
							end
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
				for _, off in { 0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2 } do
					local a = base + off
					local cam = c + Vector3.new(math.cos(a) * r, r * 0.55, math.sin(a) * r)
					local ok = not solidAt(cam)
					for _, f in { 0.15, 0.4, 0.7 } do
						if ok and workspace:Raycast(cam, (c + Vector3.new(0, 8, 0) - cam) * f, terrainOnly) then
							ok = false
						end
					end
					local hit = workspace:Raycast(cam, c + Vector3.new(0, 8, 0) - cam, terrainOnly)
					if ok and (not hit or (hit.Position - c).Magnitude < r * 0.35) then
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
			local Cinematic = require(script.Parent.Cinematic)
			local UP = Vector3.yAxis
			local mcv = workspace:GetAttribute("CineCenter")
			local mc = if typeof(mcv) == "Vector3" then Vector3.new(mcv.X, 0, mcv.Z) else Vector3.new(summit.X, 0, summit.Z)
			local mR = (workspace:GetAttribute("CineRadius") or 2300) :: number
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
			-- raggio della montagna a quell'angolo e quota (dove inizia la roccia)
			local function surfaceR(a: number, y: number): number
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local hit = workspace:Raycast(Vector3.new(mc.X, y, mc.Z) + dir * 5000, -dir * 5000, terrainOnly)
				return if hit then (Vector3.new(hit.Position.X, 0, hit.Position.Z) - mc).Magnitude else 0
			end
			-- articolazioni del sosia (braccia, gambe) senza animazioni: Motor6D.Transform
			local function limbs(body: Model?, list: { [string]: CFrame })
				if not body then
					return
				end
				for _, d in body:GetDescendants() do
					if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and list[d.Name] then
						d.Transform = list[d.Name]
					end
				end
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
				table.insert(around, Vector3.new(mc.X + math.cos(a) * mR * 1.1, summit.Y * 0.3, mc.Z + math.sin(a) * mR * 1.1))
			end

			if kind == "clip7" then
				-- GIRO DELLA MAPPA: un unico giro largo attorno alla montagna, sale fino a meta'
				-- altezza e riscende, la camera insegue morbida da fuori
				local pts: { Vector3 } = {}
				local function build()
					pts = {}
					local a0 = if gc then math.atan2(gface.Z - mc.Z, gface.X - mc.X) else 0
					local N = 18
					for k = 0, N do
						local f = k / N
						local a = a0 + f * 2 * math.pi
						local y = 450 + (summit.Y * 0.6 - 450) * (0.5 - 0.5 * math.cos(f * 2 * math.pi))
						local r = math.max(surfaceR(a, y), surfaceR(a, y - 90), surfaceR(a, y + 90)) + 280
						table.insert(pts, Vector3.new(mc.X + math.cos(a) * r, y, mc.Z + math.sin(a) * r))
					end
				end
				local function path(u: number): Vector3
					return catmull(pts, u)
				end
				add({
					dur = 20,
					at = summit - Vector3.new(0, summit.Y * 0.6, 0),
					preload = around,
					smooth = 1.6,
					follow = true,
					start = function()
						build()
						pose(adult, "fly", 0.55)
					end,
					update = function(u)
						flyAlong(adult, path, u * 0.985, 2.2)
					end,
					cam = function(u)
						local k = u * 0.985
						local p = path(k)
						local ahead = path(math.min(1, k + 0.015))
						local out = flat(p - Vector3.new(mc.X, p.Y, mc.Z))
						local back = (ahead - p).Unit
						return CFrame.lookAt(p - back * 60 + out * 40 + UP * 20, p + back * 25 - out * 30)
					end,
				})
			elseif kind == "clip8" then
				-- UNA SOLA MAPPA: dal personaggio appeso alla parete la camera si allontana senza tagli
				-- fino a mostrare tutta la montagna
				local spot, nrm = workspace:GetAttribute("CineSpot"), workspace:GetAttribute("CineNormal")
				if typeof(spot) == "Vector3" and typeof(nrm) == "Vector3" then
					local n = flat(nrm)
					local side = Vector3.new(-n.Z, 0, n.X)
					local at = spot - Vector3.new(0, 26, 0) + n * 2
					local hit = workspace:Raycast(at + n * 30, -n * 60, terrainOnly)
					if hit then
						at = hit.Position + n * 1.6
					end
					local body: Model? = nil
					local dir = (n * 0.85 + side * 0.35 + UP * 0.3).Unit
					local far = Vector3.new(mc.X, summit.Y * 0.42, mc.Z)
					add({
						dur = 15,
						at = at,
						preload = around,
						follow = true,
						start = function()
							body = Cinematic.kit.cloneActor()
							if body then
								(body :: Model):PivotTo(CFrame.lookAt(at, at - n))
								limbs(body, {
									RightShoulder = CFrame.Angles(math.rad(165), 0, 0),
									LeftShoulder = CFrame.Angles(math.rad(150), 0, 0),
									RightHip = CFrame.Angles(math.rad(20), 0, 0),
									LeftKnee = CFrame.Angles(math.rad(-40), 0, 0),
								})
							end
						end,
						update = function(u)
							if u >= 0.999 and body then
								(body :: Model):Destroy()
								body = nil
							end
						end,
						cam = function(u)
							-- zoom indietro esponenziale: 8 studs -> ~4000 studs
							local d = 8 * 500 ^ (u ^ 1.1)
							local look = at:Lerp(far, smooth(math.clamp((u - 0.15) / 0.75, 0, 1)))
							return CFrame.lookAt(at + dir * d, look)
						end,
					})
				end
			elseif kind == "clip9" then
				-- RAMPINO: scivola, cade, all'ultimo il rampino si aggancia a un drago che passa
				local spot, nrm = workspace:GetAttribute("CineSpot"), workspace:GetAttribute("CineNormal")
				if typeof(spot) == "Vector3" and typeof(nrm) == "Vector3" then
					local n = flat(nrm)
					local side = Vector3.new(-n.Z, 0, n.X)
					local at = spot - Vector3.new(0, 20, 0) + n * 2
					local hitW = workspace:Raycast(at + n * 30, -n * 60, terrainOnly)
					if hitW then
						at = hitW.Position + n * 1.6
					end
					local fallEnd = at + n * 14 - UP * 55
					local dpts = {
						at - side * 220 + n * 70 - UP * 40,
						fallEnd - side * 60 + n * 25 + UP * 10,
						fallEnd + side * 10 + n * 30 + UP * 20,
						at + side * 90 + n * 90 + UP * 70,
						at + side * 160 + n * 120 + UP * 150,
					}
					local function dragonAt(u: number): Vector3
						return catmull(dpts, u)
					end
					local body: Model? = nil
					local rope = Instance.new("Part")
					rope.Anchored, rope.CanCollide, rope.CanQuery, rope.CanTouch = true, false, false, false
					rope.Color = Color3.fromRGB(90, 70, 50)
					rope.Material = Enum.Material.Fabric
					local hooked = false
					local function bodyAt(u: number): Vector3
						if u < 0.12 then
							return at + n * (u / 0.12) * 1.5
						elseif u < 0.32 then
							local f = (u - 0.12) / 0.2
							return at:Lerp(fallEnd, f * f * (1.6 - 0.6 * f)) -- rallenta alla fine (slow motion)
						end
						local d = dragonAt(u)
						return d - UP * 24 + side * math.sin(u * 14) * 3
					end
					add({
						dur = 11,
						at = at,
						preload = { fallEnd, dpts[4], dpts[5] },
						smooth = 3,
						start = function()
							body = Cinematic.kit.cloneActor()
							pose(adult, "fly", 0.6)
							rope.Parent = workspace
						end,
						update = function(u)
							flyAlong(adult, dragonAt, u, 2)
							local p = bodyAt(u)
							if body then
								local spin = if u > 0.12 and u < 0.32 then CFrame.Angles((u - 0.12) * 6, 0, (u - 0.12) * 3) else CFrame.identity
								;(body :: Model):PivotTo(CFrame.lookAt(p, p - n) * spin)
								limbs(body, { RightShoulder = CFrame.Angles(math.rad(if u > 0.32 then 170 else 60), 0, 0), LeftShoulder = CFrame.Angles(math.rad(if u > 0.32 then 160 else 120), 0, 0) })
							end
							if u >= 0.3 and not hooked then
								hooked = true
								shake = 1.2
								flash(s)
							end
							if hooked and adult then
								local hand = p + UP * 2.5
								local tail = adult.model:GetPivot().Position
								local reach = math.clamp((u - 0.3) / 0.05, 0, 1)
								local tip = hand:Lerp(tail, reach)
								rope.Size = Vector3.new(0.25, 0.25, math.max(0.1, (tip - hand).Magnitude))
								rope.CFrame = CFrame.lookAt((hand + tip) / 2, tip)
							end
							if u >= 0.999 then
								rope:Destroy()
								if body then
									(body :: Model):Destroy()
									body = nil
								end
							end
						end,
						cam = function(u)
							local p = bodyAt(u)
							if u < 0.32 then
								return CFrame.lookAt(at + n * 26 + side * 14 - UP * 6, p)
							end
							local d = dragonAt(u)
							local mid = (p + d) / 2
							return CFrame.lookAt(mid + n * 70 - side * 30 + UP * 6, mid)
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
				local function walker(dragon: Actor?, dur: number, dies: boolean)
					return {
						dur = dur,
						at = mid,
						smooth = 4,
						start = function()
							if body then
								(body :: Model):Destroy()
							end
							body = Cinematic.kit.cloneActor()
							if body then
								hp = bar(body :: Model)
							end
							hide(gelo)
							hide(gas)
							pose(dragon, "walk", 0.9)
							if dies then
								flash(s)
							else
								flash(s)
							end
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
				-- GIORNO 1 / GIORNO 30: tenda col cucciolo, stacco, chalet sul costone con l'adulto,
				-- poi l'adulto vola via
				local tentCf, chaletCf = d.TentCF, d.ChaletCF
				local tent = props and props:FindFirstChild("CasaTenda")
				local chalet = props and props:FindFirstChild("CasaChalet")
				if typeof(tentCf) == "CFrame" and typeof(chaletCf) == "CFrame" then
					local body: Model? = nil
					local function placeBody(cf: CFrame, offset: Vector3)
						if not body then
							body = Cinematic.kit.cloneActor()
						end
						local p = groundAt((cf * CFrame.new(offset)).Position) + UP * 3
						if body then
							(body :: Model):PivotTo(CFrame.lookAt(p, p - cf.LookVector))
						end
					end
					local function orbitAt(cf: CFrame, r: number, h: number): (number) -> CFrame
						local c = cf.Position
						return function(u)
							local a = math.atan2(-cf.LookVector.Z, -cf.LookVector.X) + 0.4 + u * 0.6
							return CFrame.lookAt(c + Vector3.new(math.cos(a) * r, h, math.sin(a) * r), c + UP * 6)
						end
					end
					add({
						dur = 4.2,
						at = tentCf.Position,
						preload = { chaletCf.Position },
						start = function()
							if tent and tent:IsA("Model") then
								tent:PivotTo(tentCf)
							end
							placeBody(tentCf, Vector3.new(4, 0, -16))
							standAt(baby, (tentCf * CFrame.new(-4, 0, -14)).Position, -tentCf.LookVector)
							pose(baby, "idle")
							hide(adult)
						end,
						cam = orbitAt(tentCf, 40, 14),
					})
					add({
						dur = 4.5,
						at = chaletCf.Position,
						start = function()
							flash(s)
							shake = 0.8
							hide(baby)
							if chalet and chalet:IsA("Model") then
								chalet:PivotTo(chaletCf)
							end
							placeBody(chaletCf, Vector3.new(6, 0, -30))
							standAt(adult, (chaletCf * CFrame.new(-14, 0, -34)).Position, -chaletCf.LookVector)
							pose(adult, "idle", 0.7)
						end,
						cam = orbitAt(chaletCf, 85, 30),
					})
					local launch = chaletCf * CFrame.new(-14, 0, -34)
					local function flight(u: number): Vector3
						return launch.Position + UP * (8 + 160 * u * u) - chaletCf.LookVector * 240 * u
					end
					add({
						dur = 4.5,
						at = chaletCf.Position,
						smooth = 3,
						start = function()
							pose(adult, "fly", 0.6)
						end,
						update = function(u)
							flyAlong(adult, flight, u * 0.98, 2)
							if u >= 0.999 then
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
							return CFrame.lookAt(p + chaletCf.LookVector * 70 + UP * 25 + chaletCf.RightVector * 30, p)
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
