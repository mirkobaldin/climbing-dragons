--!strict
-- Effetti dell'addestramento dei draghi (server/Training manda l'evento "TrainingFX"):
--   hit     il drago spara un colpo del suo elemento al bersaglio: palla luminosa con scia,
--           esplosione e onda d'urto sul bersaglio (che trema), "+14 XP" sopra il drago
--   level   esplosione di luce attorno al drago e "LEVEL 23!"; ogni 25 livelli anche una
--           colonna di luce; a 100 "MAX LEVEL · READY TO EVOLVE!"
--   evolve  vortice di anelli, lampo bianco: poi arriva il drago piu' grande
-- Inoltre: sopra ogni drago al seguito "Lv 23" (attributo Level del modello) e, quando il
-- padrone sta nel cerchio di addestramento, un'aura del colore dell'elemento.
-- Il campo: i cristalli-bersaglio fluttuano e girano (e si frantumano quando li colpisci), il
-- Cristallo del Potere ruota, i bracieri divampano col colore del drago che si allena.
--   miss     colpo a vuoto (solo a chi ha sparato)
-- Vista dal drago: quando sei nel cerchio col drago (attributo Training) la camera passa dietro
-- la testa del tuo drago, il mouse muove la mira (mirino al centro) e il click spara: al server
-- va ("shoot", origine, direzione) e lui decide se hai preso un cristallo.
--   rush     sfida Target Rush: il cristallo dorato da colpire, tempo e punti in alto
--   rushEnd  risultato della sfida

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local TrainingFX = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function elementColor(id: string?): Color3
	local e = id and DragonConfig.element(id)
	return if e then e.glow else Color3.fromRGB(150, 70, 255)
end

local function petOf(userId: number, dragonId: number?): Model?
	local pets = workspace:FindFirstChild("Pets")
	local folder = pets and pets:FindFirstChild(tostring(userId))
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and (not dragonId or m:GetAttribute("DragonId") == dragonId) then
			return m
		end
	end
	return nil
end

-- punto da cui parte il colpo: la testa (osso o parte), se no il centro un po' in alto
local function mouthOf(pet: Model): Vector3
	-- l'osso della testa lo segna il modello (attributo HeadBone, dall'analisi dello scheletro)
	local headName = pet:GetAttribute("HeadBone")
	local headBone = type(headName) == "string" and pet:FindFirstChild(headName, true)
	if headBone and headBone:IsA("Bone") then
		return headBone.WorldPosition
	end
	for _, n in { "head", "spine.011", "Head" } do
		local d = pet:FindFirstChild(n, true)
		if d and d:IsA("Bone") then
			return d.WorldPosition
		elseif d and d:IsA("BasePart") then
			return d.Position
		end
	end
	local cf, size = pet:GetBoundingBox()
	return cf.Position + Vector3.new(0, size.Y * 0.3, 0)
end

local function fxPart(shape: Enum.PartType, size: Vector3, color: Color3, at: CFrame): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.CFrame = at
	p.Parent = workspace
	return p
end

local function burst(at: Vector3, color: Color3, count: number, speed: number, size: number)
	local holder = fxPart(Enum.PartType.Block, Vector3.one * 0.2, color, CFrame.new(at))
	holder.Transparency = 1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKLE
	sparks.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(size, 0)
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Speed = NumberRange.new(speed * 0.5, speed)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 4
	sparks.Rate = 0
	sparks.Parent = holder
	local smoke = sparks:Clone()
	smoke.Texture = SMOKE
	smoke.LightEmission = 0.3
	smoke.Size = NumberSequence.new(size * 1.5, size * 3)
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Lifetime = NumberRange.new(0.6, 1.1)
	smoke.Speed = NumberRange.new(1, speed * 0.3)
	smoke.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12 + size * 4
	light.Brightness = 4
	light.Parent = holder
	sparks:Emit(count)
	smoke:Emit(math.ceil(count / 3))
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 1.5)
end

-- onda d'urto: un anello piatto che si allarga e svanisce
local function shockwave(at: Vector3, color: Color3, radius: number, time: number)
	local ring = fxPart(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), color, CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2))
	ring.Transparency = 0.15
	TweenService:Create(ring, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, time + 0.1)
end

-- scritta che sale sopra un punto e svanisce
local function floatText(at: Vector3, text: string, color: Color3, big: boolean)
	local anchor = fxPart(Enum.PartType.Block, Vector3.one * 0.2, color, CFrame.new(at))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if big then 360 else 140, if big then 64 else 34)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(if big then 2.2 else 1.1), { CFrame = CFrame.new(at + Vector3.new(0, if big then 6 else 4, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(if big then 2.2 else 1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, if big then 2.3 else 1.2)
end

-- il cristallo colpito va in pezzi e si ricompone (solo qui sul client)
local hiddenUntil: { [Model]: number } = {}
local function shatter(at: Vector3, color: Color3)
	for _, m in CollectionService:GetTagged("CristalloBersaglio") do
		if m:IsA("Model") and (m:GetPivot().Position - at).Magnitude < 6 then
			for _ = 1, 12 do
				local shard = fxPart(Enum.PartType.Block, Vector3.new(0.3, 0.8, 0.3) * (0.6 + math.random()), Color3.fromRGB(190, 235, 255), CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0))
				shard.Material = Enum.Material.Glass
				shard.Transparency = 0.2
				local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
				TweenService:Create(shard, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = shard.CFrame + dir * 7 - Vector3.new(0, 2, 0), Transparency = 1 }):Play()
				Debris:AddItem(shard, 0.8)
			end
			hiddenUntil[m] = os.clock() + 0.45
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
				end
			end
			break
		end
	end
end

-- il braciere dell'elemento divampa
local function flare(element: string)
	for _, m in CollectionService:GetTagged("BracereElemento") do
		if m:GetAttribute("Element") == element then
			local fire = m:FindFirstChildWhichIsA("Fire", true)
			local light = m:FindFirstChildWhichIsA("PointLight", true)
			if fire then
				fire.Size = 9
				fire.Heat = 18
				task.delay(0.6, function()
					fire.Size = 3
					fire.Heat = 8
				end)
			end
			if light then
				light.Brightness = 5
				TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 1 }):Play()
			end
		end
	end
end

-- Target Rush: evidenzia il cristallo dorato e mostra tempo e punti
local rushLit = 0
local rushEnds = 0
local rushScore = 0
local rushGui: ScreenGui? = nil
local rushLabel: TextLabel? = nil
local litGlow: Highlight? = nil
local function rushUi(): TextLabel
	if rushLabel and rushGui and rushGui.Parent then
		return rushLabel
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TargetRush"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 70)
	label.Size = UDim2.fromOffset(360, 44)
	label.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 210, 100)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	rushGui, rushLabel = gui, label
	return label
end
local function setLit(index: number)
	rushLit = index
	if litGlow then
		litGlow:Destroy()
		litGlow = nil
	end
	for _, m in CollectionService:GetTagged("CristalloBersaglio") do
		if m:GetAttribute("Index") == index then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 200, 70)
			h.OutlineColor = Color3.fromRGB(255, 240, 160)
			h.FillTransparency = 0.25
			h.Parent = m
			litGlow = h
		end
	end
end

local function onHit(userId: number, target: Vector3, element: string, xp: number)
	local pet = petOf(userId)
	if not pet then
		return
	end
	local color = elementColor(element)
	local from = mouthOf(pet)
	-- il colpo: palla luminosa con scia
	local ball = fxPart(Enum.PartType.Ball, Vector3.one * 1.3, color, CFrame.new(from))
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
	a0.Parent, a1.Parent = ball, ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.LightEmission = 1
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = ball
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 3
	light.Parent = ball
	local time = math.clamp((target - from).Magnitude / 110, 0.12, 0.45)
	local tween = TweenService:Create(ball, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target) })
	tween:Play()
	tween.Completed:Connect(function()
		ball:Destroy()
		burst(target, color, 28, 18, 0.8)
		shockwave(target, color, 6, 0.4)
		shatter(target, color)
		flare(element)
		if userId == player.UserId and xp and xp > 0 then
			floatText(mouthOf(pet) + Vector3.new(0, 2, 0), "+" .. xp .. " XP", Color3.fromRGB(255, 230, 120), false)
		end
	end)
	Debris:AddItem(ball, time + 0.5)
end

local function onLevel(userId: number, dragonId: number, level: number)
	local pet = petOf(userId, dragonId)
	if not pet then
		return
	end
	local cf, size = pet:GetBoundingBox()
	local color = elementColor(pet:GetAttribute("Element") :: string?)
	local base = cf.Position - Vector3.new(0, size.Y / 2, 0)
	local big = level % 25 == 0
	burst(cf.Position, color, if big then 90 else 45, 22, 1)
	shockwave(base + Vector3.new(0, 0.3, 0), color, math.max(size.X, size.Z) * (if big then 2.5 else 1.4), 0.7)
	if big then
		-- colonna di luce
		local pillar = fxPart(Enum.PartType.Cylinder, Vector3.new(80, 3, 3), color, CFrame.new(base + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2))
		pillar.Transparency = 0.2
		TweenService:Create(pillar, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(80, 0.2, 0.2), Transparency = 1 }):Play()
		Debris:AddItem(pillar, 1.7)
	end
	local text = if level >= DragonConfig.MAX_LEVEL then "MAX LEVEL · READY TO EVOLVE!" else "LEVEL " .. level .. "!"
	floatText(cf.Position + Vector3.new(0, size.Y * 0.6 + 2, 0), text, color, true)
	if userId == player.UserId then
		ClientState.hint = if level >= DragonConfig.MAX_LEVEL then "Your dragon is level 100: open Dragons (G) and evolve it!" else "Your dragon reached level " .. level
	end
end

local function onEvolve(userId: number, dragonId: number)
	local pet = petOf(userId, dragonId)
	if not pet then
		return
	end
	local cf, size = pet:GetBoundingBox()
	local color = elementColor(pet:GetAttribute("Element") :: string?)
	local radius = math.max(size.X, size.Z)
	-- vortice: tre anelli che girano stringendosi attorno al drago
	for k = 1, 3 do
		local ring = fxPart(Enum.PartType.Cylinder, Vector3.new(0.3, radius * 2.4, radius * 2.4), color, CFrame.new(cf.Position + Vector3.new(0, (k - 2) * size.Y * 0.35, 0)) * CFrame.Angles(0, 0, math.pi / 2))
		ring.Transparency = 0.35
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 1.4 and ring.Parent do
				local a = (os.clock() - t0) / 1.4
				ring.CFrame = CFrame.new(cf.Position + Vector3.new(0, (k - 2) * size.Y * 0.35, 0)) * CFrame.Angles(a * 6 * k, a * 9, math.pi / 2 + math.sin(a * 10 + k) * 0.4)
				ring.Size = Vector3.new(0.3, radius * 2.4 * (1 - a * 0.7), radius * 2.4 * (1 - a * 0.7))
				task.wait()
			end
			ring:Destroy()
		end)
	end
	local flash = Instance.new("Highlight")
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 1
	flash.OutlineColor = color
	flash.Parent = pet
	TweenService:Create(flash, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FillTransparency = 0 }):Play()
	-- come nei Pokemon: tutto bianco, cresce pulsando, poi il lampo e arriva il drago grande
	local scale0 = pet:GetScale()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1.4 and pet.Parent do
			local a = (os.clock() - t0) / 1.4
			pet:ScaleTo(scale0 * (1 + 0.9 * a * a + 0.08 * math.sin(a * 40)))
			task.wait()
		end
	end)
	task.delay(1.45, function()
		burst(cf.Position, color, 140, 30, 1.4)
		shockwave(cf.Position - Vector3.new(0, size.Y / 2, 0), color, radius * 4, 1)
		floatText(cf.Position + Vector3.new(0, size.Y + 3, 0), "EVOLVED!", color, true)
	end)
	Debris:AddItem(flash, 1.6)
end

-- "Lv 23" sopra ogni drago al seguito, e l'aura quando si addestra nel cerchio
local function decorate(pet: Model)
	if pet:FindFirstChild("LivelloDrago") or not pet:GetAttribute("Owner") then
		return
	end
	local main = pet.PrimaryPart or pet:FindFirstChildWhichIsA("BasePart", true)
	if not main then
		return
	end
	local _, size = pet:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "LivelloDrago"
	gui.Size = UDim2.fromOffset(70, 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.6 + 1, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Adornee = main
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	label.BackgroundTransparency = 0.35
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = elementColor(pet:GetAttribute("Element") :: string?)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local function refresh()
		label.Text = "Lv " .. tostring(pet:GetAttribute("Level") or 1)
	end
	refresh()
	pet:GetAttributeChangedSignal("Level"):Connect(refresh)
	gui.Parent = pet

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "AuraAddestramento"
	aura.Texture = SPARKLE
	aura.Color = ColorSequence.new(elementColor(pet:GetAttribute("Element") :: string?))
	aura.LightEmission = 1
	aura.Size = NumberSequence.new(0.5, 0)
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Speed = NumberRange.new(3, 6)
	aura.Acceleration = Vector3.new(0, 4, 0)
	aura.SpreadAngle = Vector2.new(60, 60)
	aura.EmissionDirection = Enum.NormalId.Top
	aura.Rate = 0
	aura.Parent = main
	local owner = Players:GetPlayerByUserId(pet:GetAttribute("Owner") :: number)
	if owner then
		local function update()
			aura.Rate = if owner:GetAttribute("Training") then 30 else 0
		end
		update()
		owner:GetAttributeChangedSignal("Training"):Connect(update)
	end
end

-- Addestramento isolato: mentre miri non vedi gli altri giocatori ne' i loro draghi (con
-- 12-24 persone nell'arena era un caos e laggava). Si rimettono quando esci dal cerchio.
local hiddenOthers: { BasePart } = {}
local function hideOthers(hide: boolean)
	for _, p in hiddenOthers do
		p.LocalTransparencyModifier = 0
	end
	table.clear(hiddenOthers)
	if not hide then
		return
	end
	local function hideModel(m: Instance)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
				table.insert(hiddenOthers, d)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			hideModel(other.Character)
		end
	end
	local pets = workspace:FindFirstChild("Pets")
	for _, m in (if pets then pets:GetChildren() else {}) :: { Instance } do
		if m:GetAttribute("Owner") ~= player.UserId then
			hideModel(m)
		end
	end
end

local function startAim(event: RemoteEvent)
	local on = false
	local yaw, pitch = 0, -0.12
	local gui = Instance.new("ScreenGui")
	gui.Name = "MiraDrago"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	for _, size in { Vector2.new(22, 3), Vector2.new(3, 22) } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(size.X, size.Y)
		bar.BackgroundColor3 = Color3.fromRGB(255, 230, 140)
		bar.BorderSizePixel = 0
		bar.Parent = gui
	end
	local tip = Instance.new("TextLabel")
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.new(0.5, 0, 0.5, 30)
	tip.Size = UDim2.fromOffset(300, 22)
	tip.BackgroundTransparency = 1
	tip.Font = Enum.Font.GothamBold
	tip.TextScaled = true
	tip.TextColor3 = Color3.new(1, 1, 1)
	tip.TextStrokeTransparency = 0.4
	tip.Text = "Aim with the mouse · click to shoot"
	tip.Parent = gui
	local function myPet(): Model?
		return petOf(player.UserId)
	end
	local function shoot()
		local camera = workspace.CurrentCamera
		event:FireServer("shoot", camera.CFrame.Position, camera.CFrame.LookVector)
	end
	UserInputService.InputChanged:Connect(function(input)
		if on and input.UserInputType == Enum.UserInputType.MouseMovement then
			yaw -= input.Delta.X * 0.0045
			pitch = math.clamp(pitch - input.Delta.Y * 0.0045, -1.1, 0.7)
		elseif on and input.UserInputType == Enum.UserInputType.Touch then
			yaw -= input.Delta.X * 0.006
			pitch = math.clamp(pitch - input.Delta.Y * 0.006, -1.1, 0.7)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if on and not processed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2) then
			shoot()
		end
	end)
	UserInputService.TouchTap:Connect(function(_, processed)
		if on and not processed then
			shoot()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local pet = myPet()
		local want = player:GetAttribute("Training") == true and pet ~= nil and not player.PlayerGui:FindFirstChild("Trailer")
		if want and not on then
			-- si parte guardando dove guardava la camera
			local look = camera.CFrame.LookVector
			yaw = math.atan2(-look.X, -look.Z)
			pitch = -0.12
		elseif on and not want then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
		if want ~= on and player.Character then
			-- il tuo personaggio sparisce mentre miri (copriva la visuale)
			for _, d in player.Character:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					(d :: any).LocalTransparencyModifier = if want then 1 else 0
				end
			end
		end
		if want ~= on then
			hideOthers(want)
		elseif on and os.clock() % 2 < 0.02 then
			hideOthers(true) -- chi arriva dopo
		end
		on = want
		gui.Enabled = on
		ClientState.petLook = if on then Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit else nil
		if on and pet then
			local head = mouthOf(pet)
			local look = CFrame.fromOrientation(pitch, yaw, 0).LookVector
			camera.CameraType = Enum.CameraType.Scriptable
			-- piu' indietro e piu' in alto, campo largo: prima si vedeva troppo poco
			camera.FieldOfView = 88
			camera.CFrame = CFrame.lookAt(head - look * 16 + Vector3.new(0, 6, 0), head + look * 60)
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end
	end)
end

function TrainingFX.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local event = remotes:WaitForChild("TrainingFX", 30) :: RemoteEvent?
	if event then
		(event :: RemoteEvent).OnClientEvent:Connect(function(kind: string, userId: number, a: any, b: any, c: any)
			if kind == "hit" then
				onHit(userId, a, b, c)
			elseif kind == "level" then
				onLevel(userId, a, b)
			elseif kind == "evolve" then
				onEvolve(userId, a)
			elseif kind == "hint" then
				ClientState.hint = a
			elseif kind == "miss" then
				onHit(player.UserId, a, b, 0)
			elseif kind == "rush" then
				setLit(a)
				rushEnds = os.clock() + b
				rushScore = c
			elseif kind == "rushEnd" then
				setLit(0)
				rushEnds = 0
				local label = rushUi()
				label.Text = string.format("TARGET RUSH · %d hits (best %d)", a, b)
				task.delay(4, function()
					if rushEnds == 0 then
						label.Visible = false
					end
				end)
			end
		end)
	end
	-- cristalli che fluttuano e girano, contatore della sfida
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local center = workspace:GetAttribute("TrainingCenter")
		local serverT = workspace:GetServerTimeNow()
		for _, m in CollectionService:GetTagged("CristalloBersaglio") do
			if m:IsA("Model") and typeof(center) == "Vector3" then
				local i = (m:GetAttribute("Index") or 1) :: number
				m:PivotTo(CFrame.new(DragonConfig.crystalAt(center, i, serverT)) * CFrame.Angles(0, t * 0.9 + i, 0))
				local hide = hiddenUntil[m]
				if hide and t >= hide then
					hiddenUntil[m] = nil
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") then
							d.LocalTransparencyModifier = 0
						end
					end
				end
			end
		end
		for _, m in CollectionService:GetTagged("CristalloPotere") do
			local base = m:GetAttribute("Base")
			if m:IsA("Model") and typeof(base) == "Vector3" then
				m:PivotTo(CFrame.new(base + Vector3.new(0, math.sin(t * 0.8) * 1.2, 0)) * CFrame.Angles(0, t * 0.5, 0))
			end
		end
		if rushEnds > 0 then
			local label = rushUi()
			label.Visible = true
			label.Text = string.format("TARGET RUSH · %ds · %d hits", math.max(0, math.ceil(rushEnds - t)), rushScore)
		end
	end)

	-- vista dal drago e mira col mouse
	if event then
		startAim(event :: RemoteEvent)
	end

	local pets = workspace:WaitForChild("Pets")
	pets.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d:GetAttribute("Owner") then
			task.delay(0.3, decorate, d)
		end
	end)
	for _, d in pets:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Owner") then
			decorate(d)
		end
	end
end

return TrainingFX
