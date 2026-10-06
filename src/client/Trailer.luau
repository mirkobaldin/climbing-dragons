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

local function run(shots: { Shot }, s: Screen)
	local camera = workspace.CurrentCamera
	for _, shot in shots do
		if shot.at then
			pcall(function()
				player:RequestStreamAroundAsync(shot.at :: Vector3, 5)
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
			local cf = current.cam(u)
			if shake > 0 then
				cf *= CFrame.Angles((math.random() - 0.5) * 0.05 * shake, (math.random() - 0.5) * 0.05 * shake, 0)
				shake = math.max(0, shake - dt * 2)
			end
			camera.CFrame = cf
		end
	end)
	fadeTo(s, 0, 0.3)
	for _, shot in shots do
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
		return add({
			dur = dur,
			at = base,
			start = function()
				pose(adult, "fly", 0.55)
			end,
			update = function(u)
				if adult then
					local a = -1.1 + 2.2 * u
					local p = base + gside * math.sin(a) * 190 + gout * (math.cos(a) * 60 - 40) + Vector3.new(0, math.sin(u * 5) * 6, 0)
					local q = base + gside * math.sin(a + 0.05) * 190 + gout * (math.cos(a + 0.05) * 60 - 40)
					local bank = -math.cos(a) * 0.45
					adult.model:PivotTo(CFrame.lookAt(p, q) * CFrame.Angles(0, 0, bank))
				end
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

	if kind == "trailer" then
		-- 19 secondi
		local s1 = add({
			dur = 3,
			at = summit - Vector3.new(0, 1500, 0),
			cam = dolly(summit + flat(Vector3.new(-1, 0, 0.35)) * 1700 + Vector3.new(0, -1500, 0), summit + flat(Vector3.new(-1, 0, 0.35)) * 800 + Vector3.new(0, -400, 0), summit - Vector3.new(0, 900, 0), summit),
		})
		onStart(s1, function()
			say(s.big, "HARDCORE CLIMBING", 2.4)
		end)
		onStart(shotDragonPass(3.4), function()
			say(s.small, "TAME DRAGONS", 2.6, ORANGE)
		end)
		local g = shotIntoGrand(3, 0.1, 0.85)
		if g then
			onStart(g, function()
				say(s.small, "EXPLORE GIANT ICE CAVES", 2.4, ICE)
			end)
		end
		onStart(shotGas(2.4), function()
			say(s.small, "SURVIVE THE TOXIC VALLEYS", 2, Color3.fromRGB(240, 110, 230))
		end)
		local arena = add({ dur = 2.4, at = train, cam = orbit(train, 50, 20, 0.6, 1.5, 9) })
		onStart(arena, function()
			hide(gas)
			say(s.small, "TRAIN TO LV 100", 2, GOLD)
		end)
		add(evolution(s, train + Vector3.new(0, 0, 8), baby, adult, 3.2, 0.6))
		local last = add({
			dur = 1.8,
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
		local inside = shotIntoGrand(5, 0.5, 1)
		if inside then
			onStart(inside, function()
				say(s.small, "but that's not the biggest part...", 3, ICE)
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
