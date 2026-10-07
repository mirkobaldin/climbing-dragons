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
	local at = groundAt(p) + Vector3.new(0, size.Y / 2, 0)
	a.model:PivotTo(CFrame.lookAt(at, at + flat(dir)))
end

------------------------------------------------------------------------------------------
-- Riprese

type Shot = { dur: number, cam: (number) -> CFrame, update: ((number) -> ())?, start: (() -> ())?, at: Vector3? }

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
		if shot.at then
			focus(shot.at)
			pcall(function()
				player:RequestStreamAroundAsync(shot.at :: Vector3, 3)
			end)
		end
	end
	local current: Shot? = nil
	local t0 = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		camera.CameraType = Enum.CameraType.Scriptable
		if current then
			local u = math.clamp((os.clock() - t0) / current.dur, 0, 1)
			if current.update then
				current.update(u)
			end
			local cf = keepOut(current.cam(u))
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
	local bob = math.sin(os.clock() * 2 * math.pi / beat) * 1.2
	local pitch = math.cos(os.clock() * 2 * math.pi / beat) * 0.05
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
		local function bodyAt(u: number): Vector3
			return from:Lerp(lip + n * 3 + Vector3.new(0, 2, 0), smooth(u * 1.15))
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
		for _, e in { "Roccia", "Brace", "Gelo", "Cosmico", "Tempesta", "Sole", "Fulmine", "Ossa", "Gas" } do
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
			say(s.small, "TAME 11 DRAGONS", 2.5, ORANGE)
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
