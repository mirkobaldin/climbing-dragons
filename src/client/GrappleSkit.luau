--!strict
-- Scenetta da TikTok (comando admin "tiktok"): "I added a grappling hook to my climbing game".
--
--   1. IL RAMPINO    ai piedi del ghiacciaio il sosia del tuo personaggio prende la mira verso la
--                    montagna con la pistola-rampino (il tuo modello "Rampino")
--   2. LO SPARO      l'uncino vola su per il ghiacciaio... e si aggancia alla coda di un drago
--                    Ombra gigante che passava di li'. "that's not a wall"
--   3. IL VOLO       il drago lo trascina su per tutto il ghiacciaio fino alla vetta (si vede la
--                    mappa dall'alto) e intanto la corda si riavvolge
--   4. LA VETTA      sopra il santuario l'uncino si sgancia: atterraggio rovinoso accanto
--                    all'altare con l'uovo leggendario. "+1 legendary egg?"
--   5. MAMMA DRAGO   alle sue spalle sale il drago: "it was her egg". Ruggito, YOU DIED, titolo.
--
-- Tutto locale (sosia, drago, corda): niente danni. Usa i pezzi della cinematica (Cinematic.kit).
-- Per registrare: Studio > Play, barra admin (F2) > "tiktok", e registra lo schermo.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local Cinematic = require(script.Parent.Cinematic)

local kit = Cinematic.kit
local smooth, flat, groundY = kit.smooth, kit.flat, kit.groundY
local player = Players.LocalPlayer

local GrappleSkit = {}
local playing = false

local HOOK_SPEED = 160 -- l'uncino in volo (studs/s)
local CATCH_DIST = 240 -- a che distanza, su per il ghiacciaio, il drago incrocia l'uncino
local DRAGON_LENGTH = 46 -- il drago gigante (studs dal muso alla coda)
local FLIGHT_TIME = 11 -- dal ghiacciaio alla vetta
local ROPE_SHORT = 34 -- la corda riavvolta durante il volo
local REEL_SPEED = 60 -- quanto in fretta si riavvolge
local CLEAR = 45 -- il drago vola almeno a questa altezza dal terreno

-- tempi (secondi di scena)
local T_AIM = 3.4 -- prende la mira
local T_FIRE = 5.4 -- spara
local HOVER = 1.9 -- dopo l'aggancio: il drago si ferma un attimo ("uh oh")
local ARC_TIME = 1.1 -- volo dall'uncino sganciato a terra
local SLIDE_TIME = 0.5
local LIE_TIME = 1.1
local GETUP_TIME = 0.8
local WALK_TIME = 1.5
local TURN_AT = 1.7 -- dopo l'apparizione del drago, si gira
local ROAR_AT = 3.1

local TITLE_TEXT = "I added a grappling hook to my climbing game"

------------------------------------------------------------------------------------------
-- Pezzi

local function animIdFor(name: string, configured: string): string?
	if configured ~= "" then
		return configured
	end
	if not RunService:IsStudio() then
		return nil
	end
	local saves = ReplicatedStorage:FindFirstChild("ClimbAnimSaves")
	local kfs = saves and saves:FindFirstChild(name)
	if not kfs or not kfs:IsA("KeyframeSequence") then
		return nil
	end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
	end)
	return if ok then id else nil
end

-- Scritta in alto stile TikTok: bianca, bordo nero, compare con un piccolo "pop"
local function memeLabel(gui: ScreenGui): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Meme"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.2)
	label.Size = UDim2.fromScale(0.8, 0.075)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.ZIndex = 3
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	label.Parent = gui
	return label
end

local function say(label: TextLabel, text: string, hold: number)
	label.Text = text
	label.TextTransparency = 0
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local scale = label:FindFirstChildOfClass("UIScale")
	if stroke then
		stroke.Transparency = 0
	end
	if scale then
		scale.Scale = 1.25
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	task.delay(hold, function()
		if label.Parent and label.Text == text then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
	end)
end

-- Il drago gigante: il modello del drago Ombra (anteprime del menu), con volo e fermo
type Dragon = {
	model: Model,
	fix: CFrame,
	fly: AnimationTrack?,
	idle: AnimationTrack?,
	tail: Bone?,
	head: Bone?,
	height: number,
}
local function makeDragon(): Dragon?
	local previews = ReplicatedStorage:FindFirstChild("Previews")
	local dragons = previews and previews:FindFirstChild("Dragons")
	local source = dragons and (dragons:FindFirstChild("Ombra") or dragons:FindFirstChildWhichIsA("Model"))
	if not source or not source:IsA("Model") then
		return nil
	end
	local model = source:Clone()
	model.Name = "DragoScena"
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * DRAGON_LENGTH / math.max(size.X, size.Z, 0.1))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	-- dove guarda il muso (come in PetAnimator): la testa, portata su -Z
	local pivot = model:GetPivot()
	local fix = CFrame.identity
	local head: Bone? = nil
	for _, d in model:GetDescendants() do
		local n = string.lower(d.Name)
		if d:IsA("Bone") and (n == "head" or n == "testa" or n == "face") then
			head = d
			break
		end
	end
	if head then
		local dir = pivot:VectorToObjectSpace((head :: Bone).WorldPosition - pivot.Position)
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude > 0.05 then
			fix = CFrame.lookAt(Vector3.zero, dir.Unit):Inverse()
		end
	end
	local yaw = model:GetAttribute("Yaw")
	if type(yaw) == "number" then
		fix = CFrame.Angles(0, math.rad(yaw), 0) * fix
	end
	local tail = model:FindFirstChild("spine.001", true)
	local _, scaled = model:GetBoundingBox()
	model.Parent = workspace
	local dragon: Dragon = {
		model = model,
		fix = fix,
		fly = nil,
		idle = nil,
		tail = if tail and tail:IsA("Bone") then tail else nil,
		head = head,
		height = scaled.Y,
	}
	-- le animazioni del drago (Animation Editor); senza, vola fermo
	local fly = animIdFor("Dragon_Fly", DragonConfig.FLY_ANIM)
	local idle = animIdFor("Dragon_Idle", DragonConfig.IDLE_ANIM) or fly
	if fly then
		local controller = Instance.new("AnimationController")
		local animator = Instance.new("Animator")
		animator.Parent = controller
		controller.Parent = model
		local function load(id: string): AnimationTrack?
			local a = Instance.new("Animation")
			a.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(a)
			end)
			if not ok then
				return nil
			end
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
			return track
		end
		dragon.fly = load(fly)
		dragon.idle = if idle then load(idle) else nil
		if dragon.fly then
			(dragon.fly :: AnimationTrack):Play(0)
		end
	end
	return dragon
end

-- Uncino: tre artigli d'acciaio con una scia gialla
local function makeHook(): Part
	local hook = Instance.new("Part")
	hook.Name = "UncinoScena"
	hook.Size = Vector3.new(0.5, 0.5, 1.4)
	hook.Material = Enum.Material.Metal
	hook.Color = Color3.fromRGB(170, 174, 182)
	hook.Anchored = true
	hook.CanCollide = false
	hook.CanQuery = false
	for k = 0, 2 do
		local claw = Instance.new("Part")
		claw.Size = Vector3.new(0.18, 0.18, 0.9)
		claw.Material = Enum.Material.Metal
		claw.Color = hook.Color
		claw.Anchored = true
		claw.CanCollide = false
		claw.CanQuery = false
		claw.Name = "Artiglio"
		claw:SetAttribute("Angle", k * 2 * math.pi / 3)
		claw.Parent = hook
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.2, 0), Vector3.new(0, -0.2, 0)
	a0.Parent, a1.Parent = hook, hook
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.3
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 1
	trail.Parent = hook
	hook.Parent = workspace
	return hook
end

local function placeHook(hook: Part, cf: CFrame)
	hook.CFrame = cf
	for _, c in hook:GetChildren() do
		if c:IsA("BasePart") then
			local a = c:GetAttribute("Angle") :: number
			c.CFrame = cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.35, -0.6) * CFrame.Angles(-0.7, 0, 0)
		end
	end
end

-- Corda: un cilindro tirato tra due punti
local function makeRope(): Part
	local rope = Instance.new("Part")
	rope.Name = "CordaScena"
	rope.Shape = Enum.PartType.Cylinder
	rope.Material = Enum.Material.Fabric
	rope.Color = Color3.fromRGB(214, 176, 96)
	rope.Anchored = true
	rope.CanCollide = false
	rope.CanQuery = false
	rope.CastShadow = false
	rope.Size = Vector3.new(1, 0.16, 0.16)
	rope.Parent = workspace
	return rope
end

local function stretch(rope: Part, a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	if len < 0.05 then
		rope.Transparency = 1
		return
	end
	rope.Transparency = 0
	rope.Size = Vector3.new(len, rope.Size.Y, rope.Size.Z)
	rope.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
end

-- Catmull-Rom tra i punti di controllo, poi ricampionato a passo costante (ogni STEP studs) e
-- tenuto sopra il terreno di almeno CLEAR
local STEP = 2
local function flightPath(points: { Vector3 }, keepLow: { [number]: boolean }): { Vector3 }
	local dense: { Vector3 } = {}
	local lowAt: { boolean } = {}
	for i = 1, #points - 1 do
		local p0 = points[math.max(1, i - 1)]
		local p1, p2 = points[i], points[i + 1]
		local p3 = points[math.min(#points, i + 2)]
		local n = math.max(4, math.floor((p2 - p1).Magnitude / 3))
		for k = 0, n - 1 do
			local t = k / n
			local t2, t3 = t * t, t * t * t
			table.insert(dense, 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
			table.insert(lowAt, keepLow[i] == true or keepLow[i + 1] == true)
		end
	end
	table.insert(dense, points[#points])
	table.insert(lowAt, keepLow[#points] == true)
	-- mai dentro la montagna
	for i, p in dense do
		local g = groundY(p)
		local clear = if lowAt[i] then 12 else CLEAR
		if g and p.Y < g + clear then
			dense[i] = Vector3.new(p.X, g + clear, p.Z)
		end
	end
	for _ = 1, 4 do
		local copy = table.clone(dense)
		for i = 2, #dense - 1 do
			local sum = 0
			local lo, hi = math.max(1, i - 6), math.min(#dense, i + 6)
			for j = lo, hi do
				sum += copy[j].Y
			end
			dense[i] = Vector3.new(dense[i].X, math.max(sum / (hi - lo + 1), copy[i].Y), dense[i].Z)
		end
	end
	-- passo costante: la posizione a distanza s e' even[s / STEP]
	local even: { Vector3 } = { dense[1] }
	local carry = 0
	for i = 1, #dense - 1 do
		local a, b = dense[i], dense[i + 1]
		local seg = (b - a).Magnitude
		local d = STEP - carry
		while d <= seg do
			table.insert(even, a:Lerp(b, d / seg))
			d += STEP
		end
		carry = seg - (d - STEP)
	end
	return even
end

-- A che distanza lungo il percorso si passa piu' vicini (in pianta) a un punto
local function nearestS(path: { Vector3 }, p: Vector3): number
	local best, at = math.huge, 0
	for i, q in path do
		local dx, dz = q.X - p.X, q.Z - p.Z
		local d2 = dx * dx + dz * dz
		if d2 < best then
			best, at = d2, i
		end
	end
	return (at - 1) * STEP
end

local function along(path: { Vector3 }, s: number): (Vector3, Vector3)
	local f = math.clamp(s / STEP, 0, #path - 1.001)
	local i = math.floor(f)
	local p = path[i + 1]:Lerp(path[i + 2], f - i)
	local ahead = path[math.min(#path, i + 4)] - path[math.max(1, i - 2)]
	return p, if ahead.Magnitude > 1e-3 then ahead.Unit else Vector3.zAxis
end

-- Distanza lungo la polilinea del ghiacciaio
local function alongPolyline(points: { Vector3 }, dist: number): Vector3
	local left = dist
	for i = 1, #points - 1 do
		local seg = (points[i + 1] - points[i]).Magnitude
		if left <= seg then
			return points[i]:Lerp(points[i + 1], left / math.max(seg, 1e-3))
		end
		left -= seg
	end
	return points[#points]
end

------------------------------------------------------------------------------------------

function GrappleSkit.play()
	if playing then
		return
	end
	local summit = workspace:GetAttribute("CineSummit") :: Vector3?
	local count = (workspace:GetAttribute("CineGlacierCount") :: number?) or 0
	if not summit or count < 3 then
		warn("[TikTok] Mancano vetta o ghiacciaio: rigenera la mappa e riavvia il Play")
		return
	end
	playing = true
	local S = summit :: Vector3

	-- il ghiacciaio dalla fronte verso l'alto
	local glacier: { Vector3 } = {}
	for k = count, 1, -1 do
		local p = workspace:GetAttribute("CineGlacier" .. k)
		if typeof(p) == "Vector3" then
			table.insert(glacier, p)
		end
	end

	-- interfaccia nascosta
	local hidden: { ScreenGui } = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	local screen = kit.letterbox()
	local meme = memeLabel(screen.gui)
	local camera = workspace.CurrentCamera
	local oldFov = camera.FieldOfView
	local oldExposure = Lighting.ExposureCompensation
	camera.CameraType = Enum.CameraType.Scriptable
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local oldAtmo = atmosphere and { atmosphere.Density, atmosphere.Haze }
	if atmosphere then
		atmosphere.Density = math.min(atmosphere.Density, 0.22)
		atmosphere.Haze = math.min(atmosphere.Haze, 0.8)
	end

	-- il personaggio vero sparisce (senza attrezzi in mano: il sosia ha il rampino)
	local me = player.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	local myHumanoid = me and me:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		myHumanoid:UnequipTools()
		task.wait(0.2)
	end
	local homeCf = myRoot and myRoot.CFrame
	local hiddenParts: { BasePart } = {}
	if me then
		for _, d in me:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
				table.insert(hiddenParts, d)
			end
		end
	end

	-- geografia: si parte dalla fronte del ghiacciaio, guardando in su
	local P0 = glacier[1]
	local fwd = flat(glacier[math.min(3, #glacier)] - P0)
	local side = Vector3.new(-fwd.Z, 0, fwd.X) -- a destra di chi guarda in su
	local catchGround = alongPolyline(glacier, CATCH_DIST)
	local I = catchGround + Vector3.new(0, 55, 0) -- dove il drago incrocia l'uncino

	-- santuario della vetta: l'altare e l'uovo leggendario
	if workspace.StreamingEnabled then
		if me and myRoot then
			myRoot.Anchored = true
			me:PivotTo(CFrame.new(P0 + Vector3.new(0, 8, 0) - fwd * 30))
		end
		local spots = { P0, I, S }
		for k = 2, #glacier, 2 do
			table.insert(spots, glacier[k])
		end
		for _, p in spots do
			pcall(function()
				player:RequestStreamAroundAsync(p, 8)
			end)
		end
	end
	local landmarks = workspace:FindFirstChild("Landmarks")
	local altar = landmarks and landmarks:FindFirstChild("AltareVetta", true)
	local altarPos = if altar and altar:IsA("BasePart") then altar.Position else S + Vector3.new(0, 6.4, 0)
	local altarTop = altarPos.Y + (if altar and altar:IsA("BasePart") then altar.Size.Y / 2 else 0.7)
	local plateau = groundY(altarPos + Vector3.new(0, 0, 8)) or S.Y
	-- l'uovo vero sull'altare (lo mette il server), se no uno per la scena
	local egg: Model? = nil
	local eggFx: (() -> ())? = nil
	local ownEgg = false
	for _, e in workspace:GetDescendants() do
		if e:IsA("Model") and e:GetAttribute("Altare") == "AltareVetta" then
			egg = e
			break
		end
	end
	if not egg then
		egg, eggFx = kit.placeEgg(Vector3.new(altarPos.X, altarTop, altarPos.Z), DragonConfig.SUMMIT_EGG or "Sole")
		ownEgg = true
	end
	local eggPos = (egg :: Model):GetPivot().Position

	-- da che parte arriva il drago sulla vetta: dal ghiacciaio
	local d = flat(glacier[#glacier] - S)
	local perp = Vector3.new(-d.Z, 0, d.X)

	-- il sosia con la pistola-rampino
	local actor = kit.cloneActor()
	local dragon = makeDragon()
	if not actor or not dragon then
		warn("[TikTok] Manca il personaggio o il drago Ombra")
		screen.gui:Destroy()
		if actor then
			actor:Destroy()
		end
		playing = false
		return
	end
	local act = actor :: Model
	local drg = dragon :: Dragon
	local root = act:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = act:FindFirstChildOfClass("Humanoid")
	local hip = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	local motors: { [string]: Motor6D } = {}
	local restC0: { [string]: CFrame } = {}
	for _, m in act:GetDescendants() do
		if m:IsA("Motor6D") then
			motors[m.Name] = m
			restC0[m.Name] = m.C0
			m.Transform = CFrame.identity
		end
	end
	local function pose(name: string, rot: CFrame)
		local m = motors[name]
		if m then
			m.C0 = restC0[name] * rot
		end
	end
	local gun: Model? = nil
	local gunGrip = CFrame.identity
	local source = ReplicatedStorage:FindFirstChild("RampinoScena")
	if source and source:IsA("Model") then
		gun = source:Clone()
		local g = source:GetAttribute("Grip")
		if typeof(g) == "CFrame" then
			gunGrip = g
		end
		;(gun :: Model).Parent = workspace
	end
	local gripAttachment = act:FindFirstChild("RightGripAttachment", true) :: Attachment?
	local function muzzlePos(): Vector3
		local m = gun and (gun :: Model):FindFirstChild("Bocca", true)
		if m and m:IsA("Attachment") then
			return m.WorldPosition
		end
		local hand = act:FindFirstChild("RightHand") or act:FindFirstChild("Right Arm")
		return if hand and hand:IsA("BasePart") then hand.Position else root.Position
	end
	local hook = makeHook()
	hook.Transparency = 1
	for _, c in hook:GetChildren() do
		if c:IsA("BasePart") then
			c.Transparency = 1
		end
	end
	local rope = makeRope()
	rope.Transparency = 1

	-- percorso del drago: arriva di lato, incrocia l'uncino in I, sale lungo il ghiacciaio, punta
	-- la vetta e passa basso sopra il santuario (dove si sgancia l'uncino), poi via
	local controls: { Vector3 } = {
		I + side * 420 + fwd * 80 + Vector3.new(0, 30, 0),
		I + side * 150 + fwd * 15 + Vector3.new(0, 8, 0),
		I,
	}
	local low: { [number]: boolean } = { [3] = true }
	local walked = 0
	for k = 2, #glacier do
		walked += (glacier[k] - glacier[k - 1]).Magnitude
		if walked > CATCH_DIST + 120 and k % 2 == 0 then
			table.insert(controls, glacier[k] + Vector3.new(0, 110, 0))
		end
	end
	table.insert(controls, S + d * 220 + Vector3.new(0, 110, 0))
	table.insert(controls, S + d * 70 + Vector3.new(0, 45, 0))
	table.insert(controls, S + Vector3.new(0, 26, 0))
	local releaseIndex = #controls
	low[#controls] = true
	table.insert(controls, S - d * 160 + perp * 60 + Vector3.new(0, 60, 0))
	table.insert(controls, S - d * 420 + perp * 200 + Vector3.new(0, 140, 0))
	local path = flightPath(controls, low)
	local sCatch = nearestS(path, I)
	local sRelease = nearestS(path, controls[releaseIndex])
	local catchPoint = along(path, sCatch)
	local sEnd = (#path - 1) * STEP

	-- tempi
	local hookFrom = P0 + Vector3.new(0, hip + 1, 0)
	local tCatch = T_FIRE + (catchPoint - hookFrom).Magnitude / HOOK_SPEED
	local tYank = tCatch + HOVER
	local approachSpeed = sCatch / math.max(tCatch - (T_FIRE - 1.5), 1)
	local flightSpeed = (sRelease - sCatch) / FLIGHT_TIME

	-- stato
	local st = 0 -- tempo di scena (col rallentatore)
	local stage = "intro"
	local lastShot = ""
	local camOff, lookOff = Vector3.zero, Vector3.zero
	local shake = 0
	local s = 0 -- dove sta il drago lungo il percorso
	local dragonSpeed = 0
	local dragonPos, dragonDir = along(path, 0)
	local aPos, aPrev = Vector3.zero, Vector3.zero
	local ropeLen = 0
	local released = false
	local tRelease = math.huge
	local relFrom = Vector3.zero
	local land1 = Vector3.new(altarPos.X, plateau, altarPos.Z) + d * 13
	local land2 = Vector3.new(altarPos.X, plateau, altarPos.Z) + d * 8
	local standEgg = Vector3.new(altarPos.X, plateau, altarPos.Z) + d * 5.4
	local momB = Vector3.new(altarPos.X, plateau, altarPos.Z) + d * 27
	local momGround = groundY(momB) or plateau
	local tReveal = math.huge
	local died = false
	local closing = false
	local landedDragon = false

	root.CFrame = CFrame.lookAt(P0 + Vector3.new(0, hip, 0), P0 + Vector3.new(0, hip, 0) + fwd)
	camera.FieldOfView = 55
	TweenService:Create(screen.fade, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
	say(meme, TITLE_TEXT, 3)

	local function finish()
		screen.gui:Destroy()
		for _, g in hidden do
			g.Enabled = true
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		camera.FieldOfView = oldFov
		camera.CameraType = Enum.CameraType.Custom
		Lighting.ExposureCompensation = oldExposure
		if atmosphere and oldAtmo then
			atmosphere.Density, atmosphere.Haze = oldAtmo[1], oldAtmo[2]
		end
		for _, part in hiddenParts do
			part.LocalTransparencyModifier = 0
		end
		if workspace.StreamingEnabled and me and myRoot and homeCf then
			me:PivotTo(homeCf)
			myRoot.Anchored = false
		end
		act:Destroy()
		drg.model:Destroy()
		hook:Destroy()
		rope:Destroy()
		if gun then
			(gun :: Model):Destroy()
		end
		if ownEgg and egg then
			if eggFx then
				pcall(eggFx)
			end
			(egg :: Model):Destroy()
		end
		playing = false
	end

	local function setDragon(pos: Vector3, dir: Vector3, bank: number)
		local look = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.zAxis
		local pitch = math.clamp(look.Y, -0.5, 0.5)
		local cf = CFrame.lookAt(pos, pos + flat(look)) * CFrame.Angles(pitch * 0.8, 0, bank)
		drg.model:PivotTo(cf * drg.fix)
		dragonPos, dragonDir = pos, look
	end
	local function tailPos(): Vector3
		if drg.tail then
			return (drg.tail :: Bone).WorldPosition
		end
		return dragonPos - dragonDir * DRAGON_LENGTH * 0.45
	end
	local function headPos(): Vector3
		if drg.head then
			return (drg.head :: Bone).WorldPosition
		end
		return dragonPos + dragonDir * DRAGON_LENGTH * 0.45
	end
	drg.model:PivotTo(CFrame.new(0, -5000, 0)) -- fuori scena finche' non arriva

	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(rdt)
		-- la camera resta nostra (il menu o altri script la rimettevano normale)
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		-- rallentatore: attorno all'aggancio
		local rate = if st > tCatch - 0.3 and st < tCatch + 0.35 then 0.3 else 1
		local dt = rdt * rate
		st += dt
		local actorCf = root.CFrame

		------------------------------------------------------------------ il drago
		if st >= T_FIRE - 1.5 and st < tCatch then
			s = math.min(sCatch, (st - (T_FIRE - 1.5)) * approachSpeed)
			local p, dir = along(path, s)
			setDragon(p, dir, -0.25)
		elseif st >= tCatch and st < tYank then
			-- si ferma un attimo, sbattendo le ali: si e' accorto di qualcosa
			local p, dir = along(path, sCatch)
			setDragon(p + Vector3.new(0, math.sin(st * 6) * 1.2, 0), dir, 0)
			s = sCatch
		elseif st >= tYank and not landedDragon then
			local x = st - tYank
			local speed = flightSpeed * math.min(1, 0.35 + x * 0.65) -- riparte accelerando
			dragonSpeed = speed
			s = math.min(sEnd, s + speed * dt)
			local p, dir = along(path, s)
			local _, dirAhead = along(path, s + 30)
			local bank = math.clamp(dir:Cross(dirAhead).Y * -6, -0.6, 0.6)
			setDragon(p, dir, bank)
		end

		------------------------------------------------------------------ il personaggio
		if st < tYank then
			-- in piedi ai piedi del ghiacciaio: prima tiene la pistola, poi prende la mira
			local base = P0 + Vector3.new(0, hip, 0)
			actorCf = CFrame.lookAt(base, base + fwd)
			local aim = math.clamp((st - T_AIM) / 0.5, 0, 1)
			local elev = math.asin(math.clamp((I - base).Unit.Y, -1, 1))
			pose("RightShoulder", CFrame.Angles(0.35 + (math.pi / 2 + elev - 0.35) * smooth(aim), 0, 0))
			pose("LeftShoulder", CFrame.Angles((math.pi / 2 + elev) * 0.85 * smooth(aim), 0, -0.45 * smooth(aim)))
			if st > tCatch + 0.6 then
				-- "uh oh": si irrigidisce
				pose("Neck", CFrame.Angles(0.25, 0, 0))
			end
			aPos, aPrev = base, base
			ropeLen = (tailPos() - base).Magnitude
		elseif not released then
			-- trascinato dal drago: corda (vincolo), gravita', terreno; la corda si riavvolge
			if stage ~= "drag" then
				stage = "drag"
				shake = 1.1
				say(meme, "free fast travel 😎", 2.6)
			end
			ropeLen = math.max(ROPE_SHORT, ropeLen - REEL_SPEED * dt)
			local vel = (aPos - aPrev) * 0.985 -- un po' di attrito dell'aria
			-- niente fionda: quando la corda si accorcia il corpo non deve superare il drago
			local maxStep = (dragonSpeed * 1.1 + 20) * dt
			if vel.Magnitude > maxStep then
				vel = vel.Unit * maxStep
			end
			aPrev = aPos
			aPos += vel + Vector3.new(0, -workspace.Gravity * 0.6, 0) * dt * dt
			local hookAt = tailPos()
			local off = aPos - hookAt
			if off.Magnitude > ropeLen then
				aPos = hookAt + off.Unit * ropeLen
			end
			local g = groundY(aPos)
			if g and aPos.Y < g + 1.2 then
				aPos = Vector3.new(aPos.X, g + 1.2, aPos.Z)
			end
			-- il corpo lungo la corda, braccia in alto, gambe che scalciano
			local up = (hookAt - aPos).Unit
			local moving = aPos - aPrev
			local look = if moving.Magnitude > 1e-3 then moving.Unit else fwd
			local right = look:Cross(up)
			right = if right.Magnitude > 0.1 then right.Unit else side
			actorCf = CFrame.fromMatrix(aPos, right, up) * CFrame.Angles(math.sin(st * 7) * 0.3, math.sin(st * 3) * 0.4, math.cos(st * 5) * 0.25)
			pose("RightShoulder", CFrame.Angles(math.pi * 0.95, 0, 0))
			pose("LeftShoulder", CFrame.Angles(math.pi * 0.9 + math.sin(st * 13) * 0.3, 0, 0.3))
			pose("RightHip", CFrame.Angles(math.sin(st * 14) * 0.8, 0, 0))
			pose("LeftHip", CFrame.Angles(-math.sin(st * 14) * 0.8, 0, 0))
			pose("RightKnee", CFrame.Angles(-0.4 - math.abs(math.sin(st * 14)) * 0.6, 0, 0))
			pose("LeftKnee", CFrame.Angles(-0.4 - math.abs(math.cos(st * 14)) * 0.6, 0, 0))
			pose("Neck", CFrame.Angles(-0.3, 0, 0))
			if s >= sRelease then
				released = true
				tRelease = st
				relFrom = aPos
				stage = "landing"
				shake = 0.4
			end
		else
			local x = st - tRelease
			local ground = Vector3.new(0, hip, 0)
			if x < ARC_TIME then
				-- l'uncino si e' sganciato: vola a terra facendo le capriole
				local a = x / ARC_TIME
				local p = relFrom:Lerp(land1 + Vector3.new(0, 1.2, 0), a) + Vector3.new(0, 14 * math.sin(a * math.pi), 0)
				actorCf = CFrame.lookAt(p, p - d) * CFrame.Angles(-a * 2.7 * math.pi * 2, 0, math.sin(a * 9) * 0.3)
				pose("RightShoulder", CFrame.Angles(math.pi * 0.7, 0, 0.6))
				pose("LeftShoulder", CFrame.Angles(math.pi * 0.7, 0, -0.6))
				pose("RightHip", CFrame.identity)
				pose("LeftHip", CFrame.identity)
				pose("RightKnee", CFrame.identity)
				pose("LeftKnee", CFrame.identity)
			elseif x < ARC_TIME + SLIDE_TIME + LIE_TIME then
				-- faccia a terra, scivola e resta li'
				if stage == "landing" then
					stage = "lying"
					shake = 1
					say(meme, "10/10 landing", 1.8)
				end
				local a = smooth(math.min(1, (x - ARC_TIME) / SLIDE_TIME))
				local p = land1:Lerp(land2, a) + Vector3.new(0, 0.9, 0)
				actorCf = CFrame.lookAt(p, p - d) * CFrame.Angles(-math.pi / 2, 0, 0)
				pose("RightShoulder", CFrame.Angles(math.pi * 0.9, 0, 0))
				pose("LeftShoulder", CFrame.Angles(0.2, 0, 0))
			elseif x < ARC_TIME + SLIDE_TIME + LIE_TIME + GETUP_TIME then
				-- si rialza
				local a = smooth((x - ARC_TIME - SLIDE_TIME - LIE_TIME) / GETUP_TIME)
				local lying = CFrame.lookAt(land2 + Vector3.new(0, 0.9, 0), land2 + Vector3.new(0, 0.9, 0) - d) * CFrame.Angles(-math.pi / 2, 0, 0)
				local standing = CFrame.lookAt(land2 + ground, land2 + ground - d)
				actorCf = lying:Lerp(standing, a)
				pose("RightShoulder", CFrame.Angles(math.pi * 0.9 * (1 - a), 0, 0))
				pose("LeftShoulder", CFrame.Angles(0.2 * (1 - a), 0, 0))
			else
				-- vede l'uovo e ci va
				if stage == "lying" then
					stage = "egg"
					say(meme, "+1 legendary egg?", 2.4)
				end
				local w = x - ARC_TIME - SLIDE_TIME - LIE_TIME - GETUP_TIME
				local a = smooth(math.min(1, w / WALK_TIME))
				local p = land2:Lerp(standEgg, a) + ground + Vector3.new(0, math.abs(math.sin(w * 7)) * 0.25 * (1 - a), 0)
				actorCf = CFrame.lookAt(p, p - d)
				pose("RightShoulder", CFrame.Angles(0.9 * a, 0, 0)) -- allunga la mano verso l'uovo
				pose("LeftShoulder", CFrame.identity)
				if w > WALK_TIME + 0.4 and tReveal == math.huge then
					tReveal = st
				end
				-- la mamma
				if st >= tReveal then
					local r = st - tReveal
					if stage == "egg" then
						stage = "mom"
						say(meme, "it was her egg", 3)
						landedDragon = true
						if drg.idle then
							(drg.idle :: AnimationTrack):Play(0.4)
						end
						if drg.fly then
							(drg.fly :: AnimationTrack):Stop(0.6)
						end
					end
					-- sale da dietro il bordo del pianoro, alle spalle del personaggio
					local rise = smooth(math.min(1, r / 1.4))
					local lunge = if r > ROAR_AT then smooth(math.min(1, (r - ROAR_AT) / 0.25)) * 7 else 0
					local base = Vector3.new(momB.X, momGround - drg.height * 0.9 + drg.height * 1.15 * rise, momB.Z) - d * lunge
					local cf = CFrame.lookAt(base, base - d) * CFrame.Angles(0.15 - lunge * 0.03, 0, 0)
					drg.model:PivotTo(cf * drg.fix)
					dragonPos, dragonDir = base, -d
					-- si gira piano verso il drago
					if r > TURN_AT then
						local turn = smooth(math.min(1, (r - TURN_AT) / 0.9))
						actorCf = CFrame.lookAt(p, p - d) * CFrame.Angles(0, math.pi * turn, 0)
						pose("RightShoulder", CFrame.Angles(0.9 * (1 - turn), 0, 0))
						pose("Neck", CFrame.Angles(0.35 * turn, 0, 0)) -- guarda in su
					end
					-- ruggito: scossone, lampo viola, YOU DIED
					if r > ROAR_AT and not died then
						died = true
						shake = 2
						local flash = Instance.new("Highlight")
						flash.FillColor = Color3.fromRGB(150, 70, 255)
						flash.FillTransparency = 0.3
						flash.OutlineTransparency = 1
						flash.Parent = drg.model
						TweenService:Create(flash, TweenInfo.new(0.6), { FillTransparency = 1 }):Play()
						local wave = Instance.new("Part")
						wave.Shape = Enum.PartType.Ball
						wave.Material = Enum.Material.Neon
						wave.Color = Color3.fromRGB(150, 70, 255)
						wave.Anchored = true
						wave.CanCollide = false
						wave.CanQuery = false
						wave.Size = Vector3.one * 3
						wave.Position = headPos()
						wave.Transparency = 0.2
						wave.Parent = workspace
						TweenService:Create(wave, TweenInfo.new(0.7), { Size = Vector3.one * 60, Transparency = 1 }):Play()
						task.delay(1, function()
							wave:Destroy()
						end)
						Lighting.ExposureCompensation = oldExposure + 1.5
						TweenService:Create(Lighting, TweenInfo.new(0.6), { ExposureCompensation = oldExposure }):Play()
						task.delay(0.55, function()
							TweenService:Create(screen.red, TweenInfo.new(0.4), { BackgroundTransparency = 0.45 }):Play()
							TweenService:Create(screen.died, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
						end)
					end
					if died and not closing and r > ROAR_AT + 3 then
						closing = true
						TweenService:Create(screen.fade, TweenInfo.new(1), { BackgroundTransparency = 0 }):Play()
						TweenService:Create(screen.title, TweenInfo.new(1.3), { TextTransparency = 0 }):Play()
						task.delay(4, function()
							conn:Disconnect()
							finish()
						end)
					end
				end
			end
		end
		root.CFrame = actorCf

		-- la pistola in mano destra (come il Tool vero)
		if gun and gripAttachment then
			(gun :: Model):PivotTo(gripAttachment.WorldCFrame * gunGrip:Inverse())
		end

		------------------------------------------------------------------ uncino e corda
		local muzzle = muzzlePos()
		local hookAt: Vector3? = nil
		if st >= T_FIRE and st < tCatch then
			local a = (st - T_FIRE) / (tCatch - T_FIRE)
			hookAt = hookFrom:Lerp(catchPoint, a)
			if stage == "intro" or stage == "aim" then
				stage = "hook"
				shake = 0.6
				-- lampo alla bocca
				local flash = Instance.new("Part")
				flash.Shape = Enum.PartType.Ball
				flash.Material = Enum.Material.Neon
				flash.Color = Color3.fromRGB(255, 220, 140)
				flash.Anchored = true
				flash.CanCollide = false
				flash.CanQuery = false
				flash.Size = Vector3.one * 0.6
				flash.Position = muzzle
				flash.Parent = workspace
				local light = Instance.new("PointLight")
				light.Range = 14
				light.Brightness = 4
				light.Color = flash.Color
				light.Parent = flash
				TweenService:Create(flash, TweenInfo.new(0.18), { Size = Vector3.one * 2.4, Transparency = 1 }):Play()
				task.delay(0.25, function()
					flash:Destroy()
				end)
			end
		elseif st >= tCatch and not released then
			hookAt = tailPos()
			if stage == "hook" then
				stage = "caught"
				shake = 0.5
				say(meme, "...that's not a wall", 2)
			end
		end
		if hookAt then
			local h = hookAt :: Vector3
			placeHook(hook, CFrame.lookAt(h, h + (h - muzzle)))
			hook.Transparency = 0
			for _, c in hook:GetChildren() do
				if c:IsA("BasePart") then
					c.Transparency = 0
				end
			end
			stretch(rope, muzzle, h)
		else
			hook.Transparency = 1
			for _, c in hook:GetChildren() do
				if c:IsA("BasePart") then
					c.Transparency = 1
				end
			end
			rope.Transparency = 1
		end
		if st > tCatch + 0.6 and st < tYank and stage == "caught" then
			stage = "uhoh"
			say(meme, "uh oh", 1.2)
		end

		------------------------------------------------------------------ inquadrature
		-- ogni inquadratura dice dove sta la camera e dove guarda, rispetto a un punto che segue
		-- ("anchor": il soggetto che si muove, o zero per le camere ferme). L'ammorbidimento si fa
		-- rispetto all'anchor: a 300 studs/s una camera ammorbidita nel mondo restava 50 studs indietro
		local subject = actorCf.Position
		local shot: string
		local anchor = Vector3.zero
		local camPos: Vector3
		local lookAt: Vector3
		local fov = 55
		if st < T_AIM then
			-- largo alle spalle: lui in basso, il ghiacciaio e la montagna davanti
			shot = "intro"
			local a = smooth(st / T_AIM)
			camPos = P0 - fwd * (13 - 3 * a) + side * (4 - 1.5 * a) + Vector3.new(0, 3.5, 0)
			lookAt = P0 + Vector3.new(0, hip + 5, 0) + fwd * 12
		elseif st < T_FIRE then
			-- sopra la spalla: prende la mira, zoom sul bersaglio
			shot = "aim"
			local a = smooth((st - T_AIM) / (T_FIRE - T_AIM))
			camPos = subject + side * 3.2 + Vector3.new(0, 1.8, 0) - fwd * 5.5
			lookAt = catchPoint
			fov = 55 - 25 * a
		elseif st < tCatch then
			-- dietro l'uncino in volo
			shot = "hook"
			local dir = (catchPoint - hookFrom).Unit
			anchor = hookFrom:Lerp(catchPoint, (st - T_FIRE) / (tCatch - T_FIRE))
			camPos = anchor - dir * 11 + Vector3.new(0, 2.5, 0) - side * 3
			lookAt = anchor + dir * 25
			fov = 62
		elseif st < tCatch + 0.6 then
			-- l'aggancio: la camera si ferma e guarda il drago
			shot = "catch"
			local dir = (catchPoint - hookFrom).Unit
			camPos = catchPoint - dir * 26 + Vector3.new(0, 4, 0) - side * 10
			lookAt = dragonPos
			fov = 62
		elseif st < tYank + 0.45 then
			-- davanti a lui: la corda tesa... "uh oh". Allo strappo la camera resta li'
			shot = "uhoh"
			local base = P0 + Vector3.new(0, hip, 0)
			camPos = base + fwd * 6 + side * 2.5 + Vector3.new(0, 0.6, 0)
			lookAt = if st < tYank then base + Vector3.new(0, 1.2, 0) else subject
			fov = 45
		elseif not released then
			-- il volo: inseguimento, poi largo di lato (la mappa sotto), poi davanti al muso
			local x = st - tYank
			shot = if x < 3.6 then "chase" elseif x < 7 then "side" elseif x < 9.4 then "face" else "side2"
			local mid = subject:Lerp(dragonPos, 0.5)
			local fl = flat(dragonDir)
			local sideF = Vector3.new(-fl.Z, 0, fl.X)
			if shot == "chase" then
				anchor = subject
				camPos = subject - fl * 18 + Vector3.new(0, 7, 0) + sideF * 5
				-- si guarda verso il drago ma poco oltre lui: resta in quadro anche a corda lunga
				local toDragon = dragonPos - subject
				lookAt = subject + (if toDragon.Magnitude > 1e-3 then toDragon.Unit * math.min(12, toDragon.Magnitude * 0.5) else fl * 10)
				fov = 65
			elseif shot == "face" then
				anchor = dragonPos
				camPos = dragonPos + fl * 34 + Vector3.new(0, 5, 0) + sideF * 8
				lookAt = mid
			else
				anchor = mid
				camPos = mid + sideF * 70 + Vector3.new(0, 14, 0) - fl * 10
				lookAt = mid
				fov = 50
			end
		elseif st - tRelease < ARC_TIME + SLIDE_TIME + LIE_TIME + 0.3 then
			-- sulla vetta: il santuario, lui che arriva dal cielo e si schianta
			shot = "landing"
			camPos = Vector3.new(altarPos.X, plateau, altarPos.Z) + perp * 22 - d * 4 + Vector3.new(0, 6, 0)
			lookAt = subject
			fov = 50
		elseif st < tReveal then
			-- sopra la spalla: l'uovo sull'altare
			shot = "egg"
			camPos = subject + d * 7 + perp * 3 + Vector3.new(0, 2.5, 0)
			lookAt = eggPos
			fov = 45
		else
			-- oltre l'altare, basso: lui di faccia, e alle sue spalle sale il drago
			shot = "mom"
			camPos = Vector3.new(altarPos.X, plateau, altarPos.Z) - d * 9 + perp * 4 + Vector3.new(0, 3.2, 0)
			lookAt = (subject + Vector3.new(0, 1.5, 0)):Lerp(headPos(), 0.45)
			fov = 52
		end
		-- mai dentro il drago
		if shot == "chase" or shot == "face" or shot == "side" or shot == "side2" then
			local away = camPos - dragonPos
			if away.Magnitude < DRAGON_LENGTH * 0.8 then
				camPos = dragonPos + (if away.Magnitude > 1e-3 then away.Unit else Vector3.yAxis) * DRAGON_LENGTH * 0.8
			end
		end
		-- mai sottoterra (e si continua a guardare il soggetto)
		local g = groundY(camPos)
		if g and camPos.Y < g + 2 then
			camPos = Vector3.new(camPos.X, g + 2, camPos.Z)
		end
		local cut = shot ~= lastShot
		lastShot = shot
		local k = 1 - math.exp(-rdt * 5)
		if cut then
			camOff, lookOff = camPos - anchor, lookAt - anchor
		else
			camOff = camOff:Lerp(camPos - anchor, k)
			lookOff = lookOff:Lerp(lookAt - anchor, k)
		end
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, rdt * 5)
		shake = math.max(0, shake - rdt * 1.4)
		camera.CFrame = CFrame.lookAt(anchor + camOff, anchor + lookOff)
			* CFrame.Angles((math.random() - 0.5) * 0.05 * shake, (math.random() - 0.5) * 0.05 * shake, 0)
	end)
end

return GrappleSkit
