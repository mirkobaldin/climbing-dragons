--!strict
-- Scena cinematografica per trailer e TikTok (comando admin "cinematica").
--
--   1. LA SALITA     il sosia del tuo personaggio, con le piccozze, sale il naso di roccia vicino
--                    alla cima: ravvicinato, carrello laterale, da sotto il tetto
--   2. IL BORDO      supera il bordo dello strapiombo e si issa sopra
--   3. L'UOVO        sul ripiano trova un uovo del drago Ombra (con i suoi effetti) e lo raccoglie
--   4. LA FRANA      dall'alto cadono dei massi: uno lo colpisce e lo sbalza nel vuoto
--   5. LA CADUTA     precipita al rallentatore mentre l'uovo vola via; YOU DIED
--   6. LA MONTAGNA   la camera si allontana, la montagna appare intera e le gira attorno; titolo
--
-- Bande nere da film, interfaccia nascosta, didascalie in basso, sfocatura sul soggetto, luci da
-- set (sotto il tetto il sole non arriva). Il sosia e' un clone locale: niente danni.
-- Lo strapiombo e la montagna li trova il server all'avvio (CinematicSpots).
-- Per registrare: Studio > Play, poi registra lo schermo (OBS o lo strumento di Windows).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClimbConfig = require(Shared:WaitForChild("ClimbConfig"))
local ClimbPoses = require(Shared:WaitForChild("ClimbPoses"))

local player = Players.LocalPlayer

local Cinematic = {}
local playing = false

local FPS = 30
local CLIMB_SPEED = 7.5
local CLIMB_TIME = 14 -- secondi di salita (se la parete e' corta si sale piu' piano)
local OPENING = 4 -- prima inquadratura della salita
local UNDER_ROOF = 4 -- ultima inquadratura della salita: da sotto il tetto
local BODY = 1.8 -- distanza del corpo dalla roccia
local MANTLE_TIME = 1.4 -- si issa sopra il bordo
local WALK_TIME = 2.4 -- cammina fino all'uovo
local PICK_TIME = 1.2 -- si china e raccoglie l'uovo
local ROCK_TIME = 1.3 -- dalla comparsa dei massi al colpo
local SLOWMO = 1.3 -- secondi di rallentatore quando viene colpito
local DEATH_AT = 2.6 -- dopo quanto dal colpo compare YOU DIED
local PULLBACK_TIME = 5 -- la camera si allontana e la montagna appare intera
local ORBIT_TIME = 12 -- giro attorno alla montagna
local CLEARANCE = 60 -- la camera in volo non scende mai sotto questa quota dal terreno

local TITLE = "HARDCORE CLIMBING"
local TAGLINE = "every egg has a price"

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function surfaceUp(n: Vector3, prev: Vector3): Vector3
	local up = prev - n * prev:Dot(n)
	if up.Magnitude < 0.25 then
		up = Vector3.yAxis - n * n.Y
	end
	if up.Magnitude < 0.25 then
		up = Vector3.zAxis - n * n.Z
	end
	return up.Unit
end

local function bodyCFrame(pos: Vector3, n: Vector3, up: Vector3): CFrame
	return CFrame.fromMatrix(pos, up:Cross(n).Unit, up, n)
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.xAxis
end

local function animId(name: string, configured: string): string?
	if configured ~= "" then
		return configured
	end
	if RunService:IsStudio() then
		local edited = ReplicatedStorage:FindFirstChild("ClimbAnimSaves")
		local kfs = edited and edited:FindFirstChild(name)
		local ok, id = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(if kfs then kfs :: KeyframeSequence else ClimbPoses.build(name))
		end)
		if ok then
			return id
		end
	end
	return nil
end

local function groundY(p: Vector3): number?
	local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 1500, p.Z), Vector3.new(0, -3000, 0), terrainOnly)
	return hit and hit.Position.Y
end

-- La montagna intera: dalla posizione in cui la camera ha visto cadere lo scalatore si
-- allontana finche' la montagna appare tutta, poi le gira attorno.
local function planReveal(from: Vector3, fromLook: Vector3, center: Vector3, radius: number, top: number): ({ Vector3 }, { Vector3 })
	local cams, looks = {}, {}
	local orbitR = radius * 1.75
	local orbitH = top * 0.42
	local mountainLook = Vector3.new(center.X, top * 0.38, center.Z)
	local startAngle = math.atan2(from.Z - center.Z, from.X - center.X)
	local function around(angle: number, r: number, y: number): Vector3
		return Vector3.new(center.X + math.cos(angle) * r, y, center.Z + math.sin(angle) * r)
	end
	local to = around(startAngle, orbitR, orbitH)
	for f = 1, PULLBACK_TIME * FPS do
		local a = smooth(f / (PULLBACK_TIME * FPS))
		local xz = Vector3.new(from.X, 0, from.Z):Lerp(Vector3.new(to.X, 0, to.Z), math.sqrt(a))
		table.insert(cams, Vector3.new(xz.X, from.Y + (to.Y - from.Y) * a, xz.Z))
		table.insert(looks, fromLook:Lerp(mountainLook, smooth(math.min(1, a * 1.4))))
	end
	for f = 1, ORBIT_TIME * FPS do
		local x = f / (ORBIT_TIME * FPS)
		local s = 0.25 * x + 0.75 * smooth(x)
		local angle = startAngle + 1.6 * math.pi * s
		table.insert(cams, around(angle, orbitR * (1 - 0.08 * math.sin(s * math.pi)), orbitH + 220 * math.sin(s * math.pi)))
		table.insert(looks, mountainLook)
	end
	for i, c in cams do
		local g = groundY(c)
		if g and c.Y < g + CLEARANCE then
			cams[i] = Vector3.new(c.X, g + CLEARANCE, c.Z)
		end
	end
	for _ = 1, 3 do
		local copy = table.clone(cams)
		for i = 2, #cams - 1 do
			local sum, n = 0, 0
			for j = math.max(1, i - 8), math.min(#cams, i + 8) do
				sum += copy[j].Y
				n += 1
			end
			cams[i] = Vector3.new(cams[i].X, math.max(sum / n, copy[i].Y), cams[i].Z)
		end
	end
	return cams, looks
end

-- Percorso della salita: parte dalla parete sotto la pancia, sale, gira sotto il tetto e arriva
-- al bordo (dove la roccia finisce). Restituisce i CFrame del corpo e le normali.
local function planClimb(spot: Vector3, n0: Vector3, under: number): ({ CFrame }, { Vector3 })
	local first: RaycastResult? = nil
	for dy = under + 40, 10, -6 do
		local hit = workspace:Raycast(Vector3.new(spot.X, spot.Y - dy, spot.Z) + n0 * 200, -n0 * 400, terrainOnly)
		if hit and math.abs(hit.Normal.Y) < 0.5 then
			first = hit
			break
		end
	end
	if not first then
		return {}, {}
	end
	local frames, normals = {}, {}
	local n = first.Normal
	local up = surfaceUp(n, Vector3.yAxis)
	local pos = first.Position + n * BODY
	for _ = 1, 50 * FPS do
		table.insert(frames, bodyCFrame(pos, n, up))
		table.insert(normals, n)
		local nextPos = pos + up * (CLIMB_SPEED / FPS)
		local hit = workspace:Raycast(nextPos + n * 3, -n * 9, terrainOnly)
		if not hit then
			break -- il bordo: la roccia finisce
		end
		n = n:Lerp(hit.Normal, 0.18).Unit
		if n.Y > 0.55 then
			break -- la roccia e' diventata un ripiano: da qui si issa e cammina, non si striscia
		end
		up = surfaceUp(n, up)
		pos = hit.Position + n * BODY
	end
	-- solo l'ultimo tratto: la parte bella e' il tetto e il bordo
	local skip = math.max(0, #frames - CLIMB_TIME * FPS)
	if skip > 0 then
		frames = table.move(frames, skip + 1, #frames, 1, {})
		normals = table.move(normals, skip + 1, #normals, 1, {})
	end
	return frames, normals
end

-- Sopra il bordo: dove si mette i piedi (il ripiano sopra lo strapiombo) e dove sta l'uovo
type Top = { stand: Vector3, inward: Vector3, egg: Vector3 }
local function planTop(last: CFrame): Top?
	local outward = flat(last.UpVector) -- verso dove stava andando sotto il tetto
	for _, back in { 3, 6, 10 } do
		local probe = last.Position - outward * back + Vector3.new(0, 40, 0)
		local hit = workspace:Raycast(probe, Vector3.new(0, -60, 0), terrainOnly)
		if hit and hit.Normal.Y > 0.55 and hit.Position.Y > last.Position.Y then
			local inward = -outward
			local eggSpot = hit.Position + inward * 9
			local eggHit = workspace:Raycast(eggSpot + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), terrainOnly)
			return {
				stand = hit.Position,
				inward = inward,
				egg = if eggHit then eggHit.Position else eggSpot,
			}
		end
	end
	return nil
end

local function cloneActor(): Model?
	local character = player.Character
	if not character then
		return nil
	end
	character.Archivable = true
	local actor = character:Clone()
	character.Archivable = false
	if not actor then
		return nil
	end
	actor.Name = "AttoreCinematica"
	for _, d in actor:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Constraint") and d.Name:find("Climb") or d:IsA("Attachment") and d.Name == "ClimbAttachment" then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.LocalTransparencyModifier = 0 -- il personaggio vero e' nascosto, il sosia no
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local humanoid = actor:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = actor:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	actor.Parent = workspace
	return actor
end

-- L'uovo sul ripiano: il modello vero dell'uovo (Ombra se non si dice quale, o il primo che c'e'),
-- con i suoi effetti
local function placeEgg(at: Vector3, element: string?): (Model, (() -> ())?)
	local id = element or "Ombra"
	local previews = ReplicatedStorage:FindFirstChild("Previews")
	local eggs = previews and previews:FindFirstChild("Eggs")
	local source = eggs and (eggs:FindFirstChild(id) or eggs:FindFirstChildWhichIsA("Model"))
	local egg: Model
	if source and source:IsA("Model") then
		egg = source:Clone()
	else
		egg = Instance.new("Model")
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2, 2.6, 2)
		p.Color = Color3.fromRGB(80, 40, 140)
		p.Material = Enum.Material.Glass
		p.Parent = egg
	end
	local _, size = egg:GetBoundingBox()
	egg:ScaleTo(egg:GetScale() * 2.6 / math.max(size.Y, 0.1))
	_, size = egg:GetBoundingBox()
	egg:PivotTo(CFrame.new(at + Vector3.new(0, size.Y / 2 + 0.1, 0)))
	for _, d in egg:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	egg.Name = "UovoCinematica"
	egg.Parent = workspace
	local remove: (() -> ())? = nil
	local fx = ReplicatedStorage:FindFirstChild("EffettiUova")
	if fx and fx:IsA("ModuleScript") then
		local ok, Effetti = pcall(require, fx)
		if ok then
			local done, r = pcall((Effetti :: any).Applica, egg, id)
			if done then
				remove = r
			end
		end
	end
	return egg, remove
end

type Screen = { gui: ScreenGui, fade: Frame, title: TextLabel, caption: TextLabel, died: TextLabel, red: Frame }

local function letterbox(): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "Cinematica"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.fromScale(1, 0.11)
		bar.ZIndex = 4
		bar.Parent = gui
	end
	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(0, 1)
	caption.Position = UDim2.new(0.05, 0, 0.86, 0)
	caption.Size = UDim2.fromScale(0.5, 0.06)
	caption.Font = Enum.Font.GothamBold
	caption.TextScaled = true
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.TextStrokeTransparency = 1
	caption.TextTransparency = 1
	caption.TextStrokeColor3 = Color3.new(0, 0, 0)
	caption.ZIndex = 3
	caption.Parent = gui
	-- velo rosso e YOU DIED
	local red = Instance.new("Frame")
	red.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	red.BackgroundTransparency = 1
	red.BorderSizePixel = 0
	red.Size = UDim2.fromScale(1, 1)
	red.ZIndex = 2
	red.Parent = gui
	local died = Instance.new("TextLabel")
	died.BackgroundTransparency = 1
	died.AnchorPoint = Vector2.new(0.5, 0.5)
	died.Position = UDim2.fromScale(0.5, 0.5)
	died.Size = UDim2.fromScale(0.6, 0.14)
	died.Font = Enum.Font.Garamond
	died.TextScaled = true
	died.Text = "YOU DIED"
	died.TextColor3 = Color3.fromRGB(200, 20, 20)
	died.TextTransparency = 1
	died.ZIndex = 3
	died.Parent = gui
	local fade = Instance.new("Frame")
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 0 -- si parte dal nero
	fade.BorderSizePixel = 0
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 5
	fade.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Size = UDim2.fromScale(0.7, 0.13)
	title.Position = UDim2.fromScale(0.5, 0.45)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextTransparency = 1
	title.Text = TITLE
	title.ZIndex = 6
	title.Parent = fade
	local tagline = title:Clone()
	tagline.Font = Enum.Font.GothamMedium
	tagline.Size = UDim2.fromScale(0.5, 0.05)
	tagline.Position = UDim2.fromScale(0.5, 0.56)
	tagline.Text = TAGLINE
	tagline.Parent = fade
	title:GetPropertyChangedSignal("TextTransparency"):Connect(function()
		tagline.TextTransparency = title.TextTransparency
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, fade = fade, title = title, caption = caption, died = died, red = red }
end

local function showCaption(label: TextLabel, text: string, hold: number)
	label.Text = text
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
	task.delay(hold, function()
		if label.Parent and label.Text == text then
			TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- Luci da set: una luce morbida sullo scalatore e un faro che segue la camera
local function setLights(actorRoot: BasePart): (BasePart, SpotLight)
	local fill = Instance.new("PointLight")
	fill.Name = "LuceSet"
	fill.Range = 16
	fill.Brightness = 1.4
	fill.Color = Color3.fromRGB(255, 238, 215)
	fill.Shadows = false
	fill.Parent = actorRoot
	local rig = Instance.new("Part")
	rig.Name = "FaroCinematica"
	rig.Anchored = true
	rig.CanCollide = false
	rig.CanQuery = false
	rig.CanTouch = false
	rig.CastShadow = false
	rig.Transparency = 1
	rig.Size = Vector3.new(0.2, 0.2, 0.2)
	local key = Instance.new("SpotLight")
	key.Face = Enum.NormalId.Front
	key.Range = 60
	key.Angle = 70
	key.Brightness = 2.4
	key.Color = Color3.fromRGB(235, 242, 255)
	key.Shadows = false
	key.Parent = rig
	rig.Parent = workspace
	return rig, key
end

-- Camera con aria libera: tra le direzioni proposte (in ordine di preferenza) si prende la prima
-- da cui il soggetto si vede per tutta la distanza; se nessuna e' libera, quella con piu' spazio.
-- Sotto uno strapiombo la roccia e' da quasi tutte le parti: cosi' la camera trova il lato aperto.
local function clearShot(subject: Vector3, dirs: { Vector3 }, dist: number): Vector3
	local bestPos, bestRoom = subject + dirs[1].Unit * 4, -1
	for _, d in dirs do
		local dir = d.Unit
		local hit = workspace:Raycast(subject, dir * (dist + 2), terrainOnly)
		if not hit then
			return subject + dir * dist
		end
		local room = (hit.Position - subject).Magnitude - 2.5
		if room > bestRoom then
			bestPos, bestRoom = subject + dir * math.max(room, 3), room
		end
	end
	return bestPos
end

local function rock(size: number): Part
	local r = Instance.new("Part")
	r.Name = "MassoCinematica"
	r.Shape = Enum.PartType.Ball
	r.Size = Vector3.one * size
	r.Material = Enum.Material.Slate
	r.Color = Color3.fromRGB(92, 88, 84)
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.Parent = workspace
	return r
end

function Cinematic.play()
	if playing then
		return
	end
	local spot = workspace:GetAttribute("CineSpot") :: Vector3?
	local normal = workspace:GetAttribute("CineNormal") :: Vector3?
	if not spot or not normal then
		warn("[Cinematica] Nessuno strapiombo segnato: rigenera la mappa")
		return
	end
	local summit = workspace:GetAttribute("CineSummit") :: Vector3?
	local center = workspace:GetAttribute("CineCenter") :: Vector3?
	local radius = (workspace:GetAttribute("CineRadius") :: number?) or 2300
	local withReveal = summit ~= nil and center ~= nil
	playing = true
	local under = (workspace:GetAttribute("CineUnder") :: number?) or 60

	-- interfaccia nascosta, nero, bande
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
	local screen = letterbox()
	local camera = workspace.CurrentCamera
	local oldFov = camera.FieldOfView
	local oldExposure = Lighting.ExposureCompensation
	camera.CameraType = Enum.CameraType.Scriptable
	-- foschia piu' leggera: con quella di gioco la montagna intera non si vedeva
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local oldAtmo = atmosphere and { atmosphere.Density, atmosphere.Haze, atmosphere.Offset }
	if atmosphere then
		TweenService:Create(atmosphere, TweenInfo.new(1.5), { Density = math.min(atmosphere.Density, 0.22), Haze = math.min(atmosphere.Haze, 0.8) }):Play()
	end

	-- il sosia ha le piccozze in mano: si impugna la Piccozza prima di clonare il personaggio
	local me = player.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	local myHumanoid = me and me:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChild("Backpack")
	local axe = backpack and backpack:FindFirstChild(ClimbConfig.TOOL_NAME)
	if myHumanoid and axe and axe:IsA("Tool") then
		myHumanoid:EquipTool(axe)
		task.wait(0.4)
	end
	-- la camminata del personaggio (dallo script Animate) per quando cammina sul ripiano
	local walkAnimId: string? = nil
	local animate = me and me:FindFirstChild("Animate")
	local walkFolder = animate and animate:FindFirstChild("walk")
	local walkAnim = walkFolder and walkFolder:FindFirstChildWhichIsA("Animation")
	if walkAnim then
		walkAnimId = walkAnim.AnimationId
	end

	-- il personaggio vero sparisce. Con lo streaming acceso lo si porta (fermo) davanti al set
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
	local climbBase = (spot :: Vector3) - Vector3.new(0, under * 0.5, 0)
	if workspace.StreamingEnabled and me and myRoot then
		myRoot.Anchored = true
		me:PivotTo(CFrame.new(climbBase + (normal :: Vector3).Unit * 40))
		pcall(function()
			player:RequestStreamAroundAsync(climbBase, 10)
		end)
		task.wait(1)
	end

	local function restoreMe()
		for _, d in hiddenParts do
			d.LocalTransparencyModifier = 0
		end
		if workspace.StreamingEnabled and me and myRoot and homeCf then
			me:PivotTo(homeCf)
			myRoot.Anchored = false
		end
	end
	local function finish()
		screen.gui:Destroy()
		for _, g in hidden do
			g.Enabled = true
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- la salute la mostra il nostro HUD
		end)
		camera.FieldOfView = oldFov
		camera.CameraType = Enum.CameraType.Custom
		Lighting.ExposureCompensation = oldExposure
		if atmosphere and oldAtmo then
			atmosphere.Density, atmosphere.Haze, atmosphere.Offset = oldAtmo[1], oldAtmo[2], oldAtmo[3]
		end
		restoreMe()
		playing = false
	end

	local frames, normals = planClimb(spot :: Vector3, (normal :: Vector3).Unit, under)
	if #frames < 60 then
		warn("[Cinematica] Percorso troppo corto su questo strapiombo")
		finish()
		return
	end
	local top = planTop(frames[#frames])
	local actor = cloneActor()
	if not actor then
		finish()
		return
	end
	local root = actor:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = actor:FindFirstChildOfClass("Humanoid")
	local hip = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	local lightRig, keyLight = setLights(root)

	-- animazioni sul sosia
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local function track(id: string?, looped: boolean, priority: Enum.AnimationPriority): AnimationTrack?
		if not animator or not id then
			return nil
		end
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, tr = pcall(function()
			return (animator :: Animator):LoadAnimation(a)
		end)
		if not ok or not tr then
			return nil
		end
		tr.Looped = looped
		tr.Priority = priority
		return tr
	end
	local upTrack = track(animId("Climb_Up", ClimbConfig.CLIMB_UP_ANIM), true, Enum.AnimationPriority.Action)
	local roofTrack = track(animId("Climb_Roof", ClimbConfig.CLIMB_ROOF_ANIM), true, Enum.AnimationPriority.Action)
	local holdTrack = track(animId("Axe_Hold", ClimbConfig.AXE_HOLD_ANIM), true, Enum.AnimationPriority.Action)
	local walkTrack = track(walkAnimId, true, Enum.AnimationPriority.Movement)
	for _, tr in { upTrack, roofTrack } :: { AnimationTrack? } do
		if tr then
			tr:Play(0, if tr == upTrack then 1 else 0.001)
			tr:AdjustSpeed(0)
		end
	end
	root.CFrame = frames[1]

	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	local oldDof = dof and { dof.FarIntensity, dof.FocusDistance, dof.InFocusRadius, dof.NearIntensity }
	if dof then
		dof.FarIntensity, dof.NearIntensity, dof.InFocusRadius = 0.45, 0.3, 14
	end

	local n0 = normals[1]
	local lip = spot :: Vector3
	-- il lato da cui la parete non copre lo scalatore
	local tangent = Vector3.new(-n0.Z, 0, n0.X)
	do
		local startPos = frames[math.floor(#frames / 2)].Position
		for _, sign in { 1, -1 } do
			local side = Vector3.new(-n0.Z, 0, n0.X) * sign
			if not workspace:Raycast(startPos, n0 * 12 + side * 14, terrainOnly) then
				tangent = side
				break
			end
		end
	end

	-- tempi delle fasi
	local climbTime = math.max(#frames / FPS, CLIMB_TIME)
	local tMantle = climbTime
	local tWalk = tMantle + (if top then MANTLE_TIME else 0)
	local tPick = tWalk + (if top then WALK_TIME else 0)
	local tRocks = tPick + (if top then PICK_TIME else 0)
	local tHit = tRocks + (if top then ROCK_TIME else 0)

	-- uovo sul ripiano, massi che cadranno
	local egg: Model? = nil
	local eggFx: (() -> ())? = nil
	local stand: Vector3, standCf: CFrame = frames[#frames].Position, frames[#frames]
	local rocks: { { part: Part, from: Vector3, to: Vector3, delay: number } } = {}
	if top then
		local tp = top :: Top
		egg, eggFx = placeEgg(tp.egg)
		stand = tp.stand + Vector3.new(0, hip, 0)
		standCf = CFrame.lookAt(stand, stand + tp.inward)
		-- tre massi dall'alto: il primo colpisce la schiena, gli altri cadono attorno
		local hitPoint = tp.egg - tp.inward * 1.5 + Vector3.new(0, hip + 1, 0)
		for k, o in { Vector3.new(0, 0, 0), Vector3.new(5, 0, -4), Vector3.new(-6, 0, 3) } do
			local size = if k == 1 then 5 else 3.5
			local to = if k == 1 then hitPoint else hitPoint + o - Vector3.new(0, hip, 0)
			table.insert(rocks, { part = rock(size), from = to + Vector3.new(o.X * 0.5, 70 + k * 8, o.Z * 0.5), to = to, delay = (k - 1) * 0.25 })
		end
		for _, r in rocks do
			r.part.Position = r.from
			r.part.Transparency = 1
		end
	end

	local revealCams, revealLooks = {}, {}
	local revealStart = math.huge
	local fallEnd = tHit + SLOWMO + 3.5 -- senza la montagna: si chiude sulla caduta

	-- caduta: fisica semplice fatta a mano (gravita' e rotazione), con rallentatore iniziale
	local fallPos, fallVel, fallRot = Vector3.zero, Vector3.zero, CFrame.identity
	local eggPos, eggVel = Vector3.zero, Vector3.zero
	local fallStarted = false
	local slipCam: CFrame? = nil
	local shake = 0
	local stage = ""
	local camCf = CFrame.new()
	local fallClock = 0
	local closing = false
	local carried = false
	local died = false

	camera.FieldOfView = 48
	TweenService:Create(screen.fade, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(Lighting, TweenInfo.new(1.5), { ExposureCompensation = oldExposure + 0.3 }):Play()
	showCaption(screen.caption, string.format("THE OVERHANG  ·  %d m", math.floor(lip.Y)), 3.5)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		-- solo in Studio, per controllare le inquadrature: l'attributo CineFreeze (secondi) ferma
		-- la scena in quel momento
		local frozen = if RunService:IsStudio() then workspace:GetAttribute("CineFreeze") else nil
		if type(frozen) == "number" then
			t, dt = frozen, 0
			t0 = os.clock() - frozen
		end
		local actorCf: CFrame

		if t < climbTime then
			-- 1. salita: il corpo segue il percorso, l'animazione segue i metri saliti
			local f = math.clamp(math.floor(t / climbTime * #frames) + 1, 1, #frames)
			actorCf = frames[f]
			if upTrack and upTrack.Length > 0 then
				upTrack.TimePosition = (f / FPS * 0.9) % 1 * upTrack.Length
			end
			if roofTrack and roofTrack.Length > 0 then
				local x = math.clamp((-normals[f].Y - 0.1) / 0.4, 0, 1)
				roofTrack.TimePosition = (f / FPS * 0.9) % 1 * roofTrack.Length
				roofTrack:AdjustWeight(math.max(0.001, x), 0.1)
				if upTrack then
					upTrack:AdjustWeight(math.max(0.001, 1 - x), 0.1)
				end
			end
		elseif top and t < tWalk then
			-- 2. si issa sopra il bordo: arco dal bordo al ripiano, il corpo si raddrizza
			if stage ~= "mantle" then
				stage = "mantle"
				showCaption(screen.caption, "", 0)
			end
			local a = smooth((t - tMantle) / MANTLE_TIME)
			local from = frames[#frames]
			local ctrl = Vector3.new(from.Position.X, stand.Y + 2, from.Position.Z)
			local p = from.Position:Lerp(ctrl, a):Lerp(ctrl:Lerp(stand, a), a)
			actorCf = CFrame.new(p) * from.Rotation:Lerp(standCf.Rotation, a)
			if upTrack and upTrack.Length > 0 then
				upTrack.TimePosition = (a * 0.5) % 1 * upTrack.Length
			end
		elseif top and t < tPick then
			-- 3. cammina fino all'uovo
			if stage ~= "walk" then
				stage = "walk"
				for _, tr in { upTrack, roofTrack } :: { AnimationTrack? } do
					if tr then
						tr:Stop(0.3)
					end
				end
				if walkTrack then
					walkTrack:Play(0.3)
					walkTrack:AdjustSpeed(0.9)
				end
				if holdTrack then
					holdTrack:Play(0.3)
				end
				showCaption(screen.caption, "A DRAGON EGG...", 2.5)
				TweenService:Create(Lighting, TweenInfo.new(1), { ExposureCompensation = oldExposure + 0.2 }):Play()
			end
			local tp = top :: Top
			local a = smooth((t - tWalk) / WALK_TIME)
			local goal = tp.egg - tp.inward * 2.4 + Vector3.new(0, hip, 0)
			local g = groundY(stand:Lerp(goal, a))
			local p = stand:Lerp(goal, a)
			actorCf = CFrame.lookAt(Vector3.new(p.X, (g or p.Y - hip) + hip, p.Z), Vector3.new(p.X, (g or p.Y - hip) + hip, p.Z) + tp.inward)
		elseif top and t < tHit then
			-- 4. si china, raccoglie l'uovo e se lo lega sulla schiena; intanto cadono i massi
			local tp = top :: Top
			if stage ~= "pick" then
				stage = "pick"
				if walkTrack then
					walkTrack:Stop(0.3)
				end
			end
			local goal = tp.egg - tp.inward * 2.4 + Vector3.new(0, hip, 0)
			local a = math.clamp((t - tPick) / PICK_TIME, 0, 1)
			local bend = math.sin(math.min(a, 1) * math.pi) * 0.9
			actorCf = CFrame.lookAt(goal - Vector3.new(0, bend * 0.8, 0), goal - Vector3.new(0, bend * 0.8, 0) + tp.inward) * CFrame.Angles(-bend * 0.5, 0, 0)
			if a > 0.5 and not carried and egg then
				carried = true
				shake = 0.15
			end
			-- i massi: compaiono in alto e cadono accelerando
			for _, r in rocks do
				local ra = math.clamp((t - tRocks - r.delay) / ROCK_TIME, 0, 1.4)
				if t >= tRocks + r.delay then
					r.part.Transparency = 0
					r.part.Position = r.from:Lerp(r.to, ra * ra)
				end
			end
			if t >= tRocks and stage == "pick" then
				stage = "rocks"
				showCaption(screen.caption, "", 0)
			end
		else
			-- 5. colpito: sbalzato nel vuoto, rallentatore, l'uovo vola via
			if not fallStarted then
				fallStarted = true
				stage = "fall"
				local last = if top then (root.CFrame) else frames[#frames]
				local out = if top then -(top :: Top).inward else normals[#normals]
				fallPos = last.Position
				fallVel = out * 14 + Vector3.new(0, 7, 0)
				fallRot = last.Rotation
				shake = 1.2
				for _, tr in { upTrack, roofTrack, holdTrack, walkTrack } :: { AnimationTrack? } do
					if tr then
						tr:Stop(0.1)
					end
				end
				if egg then
					local e = egg :: Model
					eggPos = e:GetPivot().Position
					eggVel = out * 18 + tangent * 6 + Vector3.new(0, 12, 0)
				end
				slipCam = camera.CFrame
			end
			fallClock += dt
			local sdt = dt * (if fallClock < SLOWMO then 0.25 else 1)
			fallVel += Vector3.new(0, -workspace.Gravity * 0.55, 0) * sdt
			fallPos += fallVel * sdt
			fallRot = fallRot * CFrame.Angles(2.6 * sdt, 0.9 * sdt, 1.7 * sdt)
			actorCf = CFrame.new(fallPos) * fallRot
			if egg and (egg :: Model).Parent then
				eggVel += Vector3.new(0, -workspace.Gravity * 0.55, 0) * sdt
				eggPos += eggVel * sdt
				;(egg :: Model):PivotTo(CFrame.new(eggPos) * CFrame.Angles(t * 3, t * 2, t))
			end
			-- i massi continuano a cadere
			for _, r in rocks do
				r.part.Position += Vector3.new(0, -60 * sdt, 0) + -(if top then (top :: Top).inward else n0) * 8 * sdt
			end
			-- 6. morto: velo rosso e YOU DIED
			if not died and fallClock > DEATH_AT then
				died = true
				TweenService:Create(screen.red, TweenInfo.new(0.6), { BackgroundTransparency = 0.55 }):Play()
				TweenService:Create(screen.died, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
				task.delay(2.2, function()
					TweenService:Create(screen.red, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
					TweenService:Create(screen.died, TweenInfo.new(1), { TextTransparency = 1 }):Play()
				end)
			end
		end
		root.CFrame = actorCf
		-- l'uovo raccolto segue la schiena
		if carried and not fallStarted and egg then
			local torso = actor:FindFirstChild("UpperTorso") or actor:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				(egg :: Model):PivotTo(torso.CFrame * CFrame.new(0, 0.2, 1.6))
			end
		end
		local subject = actorCf.Position

		-- 7. la montagna: la camera lascia cadere lo scalatore e si allontana
		if t >= revealStart then
			local tr = t - revealStart
			local f = math.clamp(math.floor(tr * FPS) + 1, 1, #revealCams)
			local nextF = math.min(f + 1, #revealCams)
			local a = tr * FPS - math.floor(tr * FPS)
			camera.CFrame = CFrame.lookAt(revealCams[f]:Lerp(revealCams[nextF], a), revealLooks[f]:Lerp(revealLooks[nextF], a))
			camera.FieldOfView = 48 + 4 * smooth(tr / PULLBACK_TIME)
			if tr > 3 and actor.Parent then
				actor:Destroy()
			end
			if stage == "reveal" and tr > PULLBACK_TIME then
				stage = "orbit"
				showCaption(screen.caption, "ONE MOUNTAIN. NO SECOND CHANCES.", 5)
			end
			if stage == "orbit" and tr > PULLBACK_TIME + ORBIT_TIME - 1.6 then
				stage = "title"
				TweenService:Create(screen.fade, TweenInfo.new(1.3), { BackgroundTransparency = 0 }):Play()
				TweenService:Create(screen.title, TweenInfo.new(1.6), { TextTransparency = 0 }):Play()
			end
			if tr > PULLBACK_TIME + ORBIT_TIME + 2.8 then
				conn:Disconnect()
				lightRig:Destroy()
				finish()
			end
			return
		end

		-- inquadrature
		local desired: CFrame
		-- la camera si mette sempre di lato (in orizzontale rispetto alla parete) o poco sotto:
		-- mai sopra in verticale, dove Roblox non sa piu' dov'e' il "su" e l'immagine ruota
		local n = flat(-actorCf.LookVector)
		local down = Vector3.new(0, -1, 0)
		if t < OPENING then
			-- ravvicinato di tre quarti che si stringe piano
			local a = smooth(t / OPENING)
			local pos = clearShot(subject, { n * 0.75 + tangent * 0.65 + down * 0.2, n * 0.75 - tangent * 0.65 + down * 0.2, n + down * 0.3, n }, 22 - 8 * a)
			desired = CFrame.lookAt(pos, subject + Vector3.new(0, 1.2, 0))
		elseif t < climbTime - UNDER_ROOF then
			-- carrello laterale: segue braccia e piccozze
			local pos = clearShot(subject, { n * 0.6 + tangent * 0.8 + down * 0.2, n * 0.6 - tangent * 0.8 + down * 0.2, n + down * 0.3, n }, 14)
			desired = CFrame.lookAt(pos, subject + Vector3.new(0, 1.5, 0))
		elseif t < climbTime then
			-- da sotto il tetto: in fuori e in basso, guardando su
			local pos = clearShot(subject, { n + down * 0.6 + tangent * 0.3, n + down * 0.6 - tangent * 0.3, n + down * 0.2, n }, 14)
			desired = CFrame.lookAt(pos, subject)
			if stage == "" then
				stage = "roof"
				TweenService:Create(Lighting, TweenInfo.new(1.2), { ExposureCompensation = oldExposure + 0.9 }):Play()
			end
		elseif top and t < tWalk then
			-- dal vuoto davanti al bordo: lo si vede issarsi
			local tp = top :: Top
			local out = -tp.inward
			desired = CFrame.lookAt(stand + out * 16 + tangent * 7 + Vector3.new(0, 3, 0), subject)
		elseif top and t < tPick then
			-- dall'uovo: lo si vede arrivare
			local tp = top :: Top
			desired = CFrame.lookAt(tp.egg + tp.inward * 7 + tangent * 4 + Vector3.new(0, 2.5, 0), subject + Vector3.new(0, 0.5, 0))
		elseif top and not fallStarted then
			-- dal basso verso l'alto: l'uovo raccolto e i massi che arrivano
			local tp = top :: Top
			local lookUp = subject + Vector3.new(0, 4 + 10 * smooth((t - tRocks) / ROCK_TIME), 0)
			desired = CFrame.lookAt(subject - tp.inward * 8 + tangent * 6 + Vector3.new(0, 1, 0), lookUp)
		else
			-- la caduta: la camera resta dov'era e lo guarda precipitare
			local base = slipCam or camera.CFrame
			desired = CFrame.lookAt(base.Position, subject)
		end
		-- mai dietro la roccia: se tra il soggetto e la camera c'e' terreno, la camera viene avanti
		local toCam = desired.Position - subject
		local block = if t < climbTime then nil else workspace:Raycast(subject, toCam, terrainOnly)
		if block then
			desired = CFrame.lookAt(block.Position - toCam.Unit * 2.5 + block.Normal * 1.5, subject)
		end
		camCf = if t < 0.1 or type(frozen) == "number" then desired else camCf:Lerp(desired, math.min(1, dt * 4))
		shake = math.max(0, shake - dt * 1.2)
		local jitter = CFrame.Angles((math.random() - 0.5) * 0.04 * shake, (math.random() - 0.5) * 0.04 * shake, 0)
		camera.CFrame = camCf * jitter
		if dof then
			dof.FocusDistance = (camera.CFrame.Position - subject).Magnitude
		end
		lightRig.CFrame = camera.CFrame
		keyLight.Range = math.clamp((camera.CFrame.Position - subject).Magnitude + 25, 30, 60)

		-- dopo la caduta: il giro attorno alla montagna (o si chiude)
		if fallStarted and died and fallClock > DEATH_AT + 2.6 and revealStart == math.huge and not closing then
			if withReveal then
				revealCams, revealLooks = planReveal(camera.CFrame.Position, subject, center :: Vector3, radius, (summit :: Vector3).Y)
				revealStart = t
				stage = "reveal"
				keyLight.Enabled = false
				TweenService:Create(Lighting, TweenInfo.new(2), { ExposureCompensation = oldExposure }):Play()
				if dof then
					dof.FarIntensity, dof.NearIntensity, dof.InFocusRadius = 0, 0, 500
				end
			elseif t > fallEnd then
				closing = true
				TweenService:Create(screen.fade, TweenInfo.new(1.1), { BackgroundTransparency = 0 }):Play()
				TweenService:Create(screen.title, TweenInfo.new(1.4), { TextTransparency = 0 }):Play()
				task.delay(3, function()
					conn:Disconnect()
					actor:Destroy()
					lightRig:Destroy()
					finish()
				end)
			end
		end
	end)
	-- a scena finita: via uovo, massi e sfocatura come prima
	task.spawn(function()
		while playing do
			task.wait(0.5)
		end
		if eggFx then
			pcall(eggFx)
		end
		if egg then
			(egg :: Model):Destroy()
		end
		for _, r in rocks do
			r.part:Destroy()
		end
		if dof and oldDof then
			dof.FarIntensity, dof.FocusDistance, dof.InFocusRadius, dof.NearIntensity = oldDof[1], oldDof[2], oldDof[3], oldDof[4]
		end
	end)
end

-- Pezzi riusati dalle altre scene (GrappleSkit)
Cinematic.kit = {
	smooth = smooth,
	flat = flat,
	groundY = groundY,
	cloneActor = cloneActor,
	placeEgg = placeEgg,
	letterbox = letterbox,
	showCaption = showCaption,
	setLights = setLights,
}

return Cinematic
