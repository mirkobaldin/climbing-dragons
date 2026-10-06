--!strict
-- Trailer (meno di 20 secondi) e clip per TikTok, girati sul client dopo i comandi admin:
--   trailer  montagna, drago in volo, grotta di ghiaccio, valle dei gas, addestramento,
--            evoluzione dell'Eclissi, titolo
--   clip1    "POV: your dragon finally hits Lv 100" -> evoluzione dell'Eclissi
--   clip2    la grotta di ghiaccio nascosta: fronte del ghiacciaio, galleria, sala
--   clip3    la valle dei gas: "never enter without a Gas dragon"
-- Le scritte stanno nella fascia centrale (40% della larghezza): tagliando il video in 3:4 per
-- TikTok restano intere. Niente bande nere. Il server (TrailerProps) prepara i draghi di scena
-- e i punti della mappa negli attributi di Workspace.TrailerProps.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local PetAnimator = require(script.Parent.PetAnimator)

local player = Players.LocalPlayer

local Trailer = {}

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
-- Schermo: scritte al centro, dissolvenze, lampo

type Screen = { gui: ScreenGui, fade: Frame, flash: Frame, big: TextLabel, small: TextLabel }

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
	local function label(y: number, h: number, font: Enum.Font): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.38, h) -- fascia centrale: resta intera nel taglio 3:4
		l.Font = font
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
	local big = label(0.42, 0.11, Enum.Font.GothamBlack)
	local small = label(0.2, 0.07, Enum.Font.GothamBlack)
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, fade = fade, flash = flash, big = big, small = small }
end

local function say(l: TextLabel, text: string, hold: number, color: Color3?)
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Size = UDim2.fromScale(0.34, l.Size.Y.Scale)
	TweenService:Create(l, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0, TextStrokeTransparency = 0.2, Size = UDim2.fromScale(0.38, l.Size.Y.Scale) }):Play()
	task.delay(hold, function()
		if l.Text == text then
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function fadeTo(s: Screen, alpha: number, time: number)
	TweenService:Create(s.fade, TweenInfo.new(time), { BackgroundTransparency = 1 - alpha }):Play()
end

local function flash(s: Screen)
	s.flash.BackgroundTransparency = 0
	TweenService:Create(s.flash, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

------------------------------------------------------------------------------------------
-- Draghi di scena

type Actor = { model: Model, tracks: any? }

local function actor(name: string): Actor?
	local props = workspace:FindFirstChild("TrailerProps")
	local m = props and props:FindFirstChild(name)
	if not m or not m:IsA("Model") then
		return nil
	end
	local old = m:FindFirstChild("PetAnimationController")
	if old then
		old:Destroy()
	end
	local tracks = PetAnimator.loadTracks(m)
	return { model = m, tracks = tracks }
end

local function pose(a: Actor?, kind: string)
	if not a or not a.tracks then
		return
	end
	for name, track in a.tracks do
		track:AdjustWeight(if name == kind then 1 else 0.001, 0.2)
	end
end

local function hide(a: Actor?)
	if a then
		a.model:PivotTo(CFrame.new(0, -500, 0))
	end
end

-- appoggia il drago a terra in p, guardando verso dir
local function standAt(a: Actor?, p: Vector3, dir: Vector3)
	if not a then
		return
	end
	local _, size = a.model:GetBoundingBox()
	local g = groundAt(p)
	local at = g + Vector3.new(0, size.Y / 2, 0)
	a.model:PivotTo(CFrame.lookAt(at, at + flat(dir)))
end

------------------------------------------------------------------------------------------
-- Inquadrature: ogni ripresa e' { durata, camera(u) -> CFrame, update(u)? , inizio()? }

type Shot = { dur: number, cam: (number) -> CFrame, update: ((number) -> ())?, start: (() -> ())?, at: Vector3? }

local function run(shots: { Shot }, s: Screen)
	local camera = workspace.CurrentCamera
	-- prima si caricano le zone lontane (streaming), con lo schermo nero
	for _, shot in shots do
		if shot.at then
			pcall(function()
				player:RequestStreamAroundAsync(shot.at :: Vector3, 4)
			end)
		end
	end
	local current: Shot? = nil
	local t0 = 0
	local conn = RunService.RenderStepped:Connect(function()
		camera.CameraType = Enum.CameraType.Scriptable
		if current then
			local u = math.clamp((os.clock() - t0) / current.dur, 0, 1)
			if current.update then
				current.update(u)
			end
			camera.CFrame = current.cam(u)
		end
	end)
	fadeTo(s, 0, 0.35)
	for _, shot in shots do
		if shot.start then
			shot.start()
		end
		t0 = os.clock()
		current = shot
		task.wait(shot.dur)
	end
	fadeTo(s, 1, 0.5)
	task.wait(0.6)
	conn:Disconnect()
	camera.CameraType = Enum.CameraType.Custom
end

-- la camera passa da a a b guardando da la a lb
local function dolly(a: Vector3, b: Vector3, la: Vector3, lb: Vector3): (number) -> CFrame
	return function(u)
		local k = smooth(u)
		return CFrame.lookAt(a:Lerp(b, k), la:Lerp(lb, k))
	end
end

-- giro attorno a c
local function orbit(c: Vector3, radius: number, height: number, from: number, to: number, lookUp: number): (number) -> CFrame
	return function(u)
		local a = from + (to - from) * smooth(u)
		return CFrame.lookAt(c + Vector3.new(math.cos(a) * radius, height, math.sin(a) * radius), c + Vector3.new(0, lookUp, 0))
	end
end

------------------------------------------------------------------------------------------
-- Pezzi riusati

local function evolution(s: Screen, center: Vector3, baby: Actor?, adult: Actor?, dur: number): Shot
	local swapped = false
	local look = Vector3.new(0, 0, -1)
	return {
		dur = dur,
		at = center,
		start = function()
			swapped = false
			standAt(baby, center, look)
			hide(adult)
			pose(baby, "idle")
			pose(adult, "idle")
		end,
		update = function(u)
			if baby and u < 0.55 then
				-- il cucciolo si illumina e trema
				local base = baby.model:GetPivot()
				local shake = u * 0.25
				baby.model:PivotTo(base * CFrame.Angles((math.random() - 0.5) * shake, 0, (math.random() - 0.5) * shake))
			end
			if u >= 0.55 and not swapped then
				swapped = true
				flash(s)
				hide(baby)
				standAt(adult, center, look)
				say(s.big, "EVOLVED!", 1.6, Color3.fromRGB(255, 170, 70))
			end
		end,
		cam = function(u)
			-- vicino al cucciolo, poi indietro e in alto per far vedere quanto e' grande
			local k = smooth(math.max(0, (u - 0.5) / 0.5))
			local dist = 14 + 80 * k
			local h = 5 + 36 * k
			local a = 0.4 + u * 0.8
			return CFrame.lookAt(center + Vector3.new(math.sin(a) * dist, h, -math.cos(a) * dist), center + Vector3.new(0, 4 + 22 * k, 0))
		end,
	}
end

local function rings(center: Vector3, color: Color3)
	for k = 1, 3 do
		local ring = Instance.new("Part")
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.3
		ring.Size = Vector3.new(0.3, 4, 4)
		ring.CFrame = CFrame.new(center + Vector3.new(0, k * 3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, 60, 60), Transparency = 1 }):Play()
		game:GetService("Debris"):AddItem(ring, 1.7)
	end
end

------------------------------------------------------------------------------------------

local function data(): { [string]: any }
	local props = workspace:WaitForChild("TrailerProps", 10)
	return if props then props:GetAttributes() else {}
end

local function cavePath(d: { [string]: any }): { Vector3 }
	local list = {}
	for k = 1, (d.CaveCount or 0) :: number do
		local p = d["Cave" .. k]
		if typeof(p) == "Vector3" then
			table.insert(list, p)
		end
	end
	return list
end

local function alongPath(path: { Vector3 }, u: number): Vector3
	local f = 1 + u * (#path - 1)
	local i = math.clamp(math.floor(f), 1, #path - 1)
	return path[i]:Lerp(path[i + 1], f - i)
end

function Trailer.play(kind: string)
	local d = data()
	local s = screen()
	-- via HUD e menu durante le riprese
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
	local baby, adult, gas, gelo = actor("EclissiCucciolo"), actor("EclissiAdulto"), actor("Gas"), actor("Gelo")
	local summit = d.Summit or Vector3.new(1300, 4100, 0)
	local train = d.TrainingCenter or Vector3.new(-837, 70, -1186)
	local gasC = d.GasCenter or Vector3.new(3224, 327, -168)
	local cave = cavePath(d)
	local caveIn = cave[1] or summit
	local caveDir = if #cave >= 3 then flat(cave[1] - cave[3]) else Vector3.xAxis -- verso l'uscita
	local orange = Color3.fromRGB(255, 170, 70)

	local shots: { Shot } = {}
	local function add(shot: Shot)
		table.insert(shots, shot)
	end
	local function shotMountain(dur: number)
		local dir = flat(Vector3.new(-1, 0, 0.35))
		add({
			dur = dur,
			at = summit + dir * 900,
			cam = dolly(summit + dir * 1700 + Vector3.new(0, -summit.Y * 0.35, 0), summit + dir * 750 + Vector3.new(0, -summit.Y * 0.1, 0), summit - Vector3.new(0, 900, 0), summit),
		})
	end
	local function shotCave(dur: number, from: number, to: number)
		if #cave < 3 then
			return
		end
		add({
			dur = dur,
			at = caveIn,
			cam = function(u)
				local k = from + (to - from) * smooth(u)
				local p = alongPath(cave, k) - Vector3.new(0, 4, 0)
				local q = alongPath(cave, math.min(1, k + 0.12)) - Vector3.new(0, 5, 0)
				return CFrame.lookAt(p, q)
			end,
		})
	end
	local function shotGlacierFront(dur: number)
		local front = caveIn + caveDir * 40
		add({
			dur = dur,
			at = front,
			cam = dolly(front + caveDir * 160 + Vector3.new(0, 30, 0), front + caveDir * 25 + Vector3.new(0, 6, 0), front + Vector3.new(0, 10, 0), caveIn),
		})
	end
	local function shotFlyBy(dur: number)
		local base = caveIn + caveDir * 140 + Vector3.new(0, 60, 0)
		local side = Vector3.new(-caveDir.Z, 0, caveDir.X)
		add({
			dur = dur,
			at = base,
			start = function()
				pose(adult, "fly")
			end,
			update = function(u)
				if adult then
					local p = base + side * (-160 + 320 * u) + Vector3.new(0, math.sin(u * 6) * 4, 0)
					adult.model:PivotTo(CFrame.lookAt(p, p + side))
				end
			end,
			cam = function(u)
				local p = base + side * (-160 + 320 * u)
				return CFrame.lookAt(base + caveDir * 90 + Vector3.new(0, -15, 0), p)
			end,
		})
	end
	local function shotGas(dur: number, withDragon: boolean)
		add({
			dur = dur,
			at = gasC,
			start = function()
				if withDragon then
					standAt(gas, gasC + Vector3.new(30, 0, 0), Vector3.new(1, 0, 0.3))
					pose(gas, "walk")
				end
			end,
			update = function(u)
				if withDragon and gas then
					local p = gasC + Vector3.new(30 + 40 * u, 0, 12 * u)
					standAt(gas, p, Vector3.new(1, 0, 0.3))
				end
			end,
			cam = orbit(gasC, 110, 40, 2.2, 3.4, 8),
		})
	end
	local function shotTraining(dur: number)
		add({
			dur = dur,
			at = train,
			start = function()
				pose(gelo, "fly")
			end,
			update = function(u)
				if gelo then
					local a = u * 4
					local p = train + Vector3.new(math.cos(a) * 20, 14 + math.sin(a * 2) * 3, math.sin(a) * 20)
					gelo.model:PivotTo(CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))))
				end
			end,
			cam = orbit(train, 46, 18, 0.5, 1.6, 9),
		})
	end

	if kind == "trailer" then
		-- 19 secondi
		shotMountain(3.2)
		shots[#shots].start = function()
			say(s.big, "HARDCORE CLIMBING", 2.6)
		end
		shotFlyBy(2.8)
		shots[#shots].start = function()
			pose(adult, "fly")
			say(s.small, "TAME DRAGONS", 2.3, orange)
		end
		shotCave(2.8, 0.05, 0.6)
		shots[#shots].start = function()
			say(s.small, "EXPLORE ICE CAVES", 2.3, Color3.fromRGB(130, 210, 255))
		end
		shotGas(2.6, true)
		local gasStart = shots[#shots].start
		shots[#shots].start = function()
			if gasStart then
				gasStart()
			end
			say(s.small, "SURVIVE THE TOXIC VALLEY", 2.1, Color3.fromRGB(240, 110, 230))
		end
		shotTraining(2.6)
		local trStart = shots[#shots].start
		shots[#shots].start = function()
			if trStart then
				trStart()
			end
			say(s.small, "TRAIN TO LV 100", 2.1, Color3.fromRGB(255, 220, 120))
		end
		add(evolution(s, train + Vector3.new(0, 0, 8), baby, adult, 3.4))
		local evo = shots[#shots]
		local evoStart = evo.start
		evo.start = function()
			hide(gelo)
			if evoStart then
				evoStart()
			end
			task.delay(1.2, rings, train + Vector3.new(0, 0, 8), orange)
		end
		add({
			dur = 1.6,
			cam = shots[#shots].cam,
			start = function()
				fadeTo(s, 1, 0.4)
				task.delay(0.35, function()
					say(s.big, "HARDCORE CLIMBING", 1.5)
					say(s.small, "PLAY NOW", 1.5, orange)
				end)
			end,
		})
	elseif kind == "clip1" then
		-- POV: il drago arriva a 100 ed evolve (circa 11 s)
		add(evolution(s, train + Vector3.new(0, 0, 8), baby, adult, 7))
		local evo = shots[1]
		local evoStart = evo.start
		evo.start = function()
			if evoStart then
				evoStart()
			end
			say(s.small, "POV: your dragon finally hits Lv 100", 3.2)
			task.delay(2.2, function()
				say(s.big, "Lv 99 > 100", 1.4, Color3.fromRGB(255, 220, 120))
			end)
			task.delay(3.6, rings, train + Vector3.new(0, 0, 8), orange)
		end
		add({
			dur = 3.5,
			cam = orbit(train + Vector3.new(0, 0, 8), 95, 40, 1.6, 2.6, 22),
			start = function()
				say(s.small, "was it worth the grind?", 3)
			end,
		})
	elseif kind == "clip2" then
		-- la grotta di ghiaccio nascosta (circa 11 s)
		shotGlacierFront(3)
		shots[#shots].start = function()
			say(s.small, "found a hidden ice cave in my Roblox game...", 2.8)
		end
		shotCave(4.5, 0, 0.75)
		shotCave(3.5, 0.75, 1)
		shots[#shots].start = function()
			say(s.big, "it keeps going.", 2.5, Color3.fromRGB(130, 210, 255))
		end
	elseif kind == "clip3" then
		-- la valle dei gas (circa 10 s)
		add({
			dur = 3.5,
			at = gasC,
			cam = dolly(gasC + Vector3.new(260, 90, 120), gasC + Vector3.new(120, 40, 60), gasC + Vector3.new(0, 30, 0), gasC),
			start = function()
				say(s.small, "rule #1: never enter the toxic valley", 3.2)
			end,
		})
		shotGas(3.5, false)
		shots[#shots].start = function()
			say(s.big, "without a Gas dragon", 3, Color3.fromRGB(240, 110, 230))
		end
		shotGas(3, true)
		local st = shots[#shots].start
		shots[#shots].start = function()
			if st then
				st()
			end
			say(s.small, "...unless you have one", 2.6)
		end
	end
	run(shots, s)
	for _, a in { baby, adult, gas, gelo } do
		hide(a)
	end
	for _, g in hidden do
		g.Enabled = true
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	s.gui:Destroy()
end

return Trailer
