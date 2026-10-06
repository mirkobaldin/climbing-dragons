--!strict
-- Effetti dell'addestramento dei draghi (server/Training manda l'evento "TrainingFX"):
--   hit     il drago spara un colpo del suo elemento al bersaglio: palla luminosa con scia,
--           esplosione e onda d'urto sul bersaglio (che trema), "+14 XP" sopra il drago
--   level   esplosione di luce attorno al drago e "LEVEL 23!"; ogni 25 livelli anche una
--           colonna di luce; a 100 "MAX LEVEL · READY TO EVOLVE!"
--   evolve  vortice di anelli, lampo bianco: poi arriva il drago piu' grande
-- Inoltre: sopra ogni drago al seguito "Lv 23" (attributo Level del modello) e, quando il
-- padrone sta nel cerchio di addestramento, un'aura del colore dell'elemento.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
		-- il bersaglio trema (solo qui sul client)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local zone = workspace:FindFirstChild("ZonaAddestramento")
		if zone then
			params.FilterDescendantsInstances = { zone }
			for _, p in workspace:GetPartBoundsInRadius(target, 4, params) do
				local m = p:FindFirstAncestorOfClass("Model")
				if m and m ~= zone then
					local base = m:GetPivot()
					task.spawn(function()
						for k = 1, 6 do
							m:PivotTo(base * CFrame.Angles(math.rad((if k % 2 == 0 then 1 else -1) * (7 - k)), 0, 0))
							task.wait(0.03)
						end
						m:PivotTo(base)
					end)
					break
				end
			end
		end
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
			end
		end)
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
