--!strict
-- Combattimento lato client (il danno lo calcola sempre il server, server/Enemies e Flyers):
--   * attacco speciale del drago: tasto Z (o il pulsante del drago sul telefono), ricarica
--     mostrata nel pulsante in basso
--   * effetti dell'evento "EnemyFX": onda del drago, picchiata, stordimento, rimbalzi della
--     piccozza, meteore, palle di fuoco dei draghi volanti
--   * draghi volanti (tag "Volante"): li muove ogni client dagli attributi del volo
--   * draghi Shiny: brillii dorati
--   * cronometro della discesa, evento della mappa in corso (lo scudo sta nella scheda dell'HUD)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local UpgradeConfig = require(Shared:WaitForChild("UpgradeConfig"))
local DragonVFX = require(script.Parent.DragonVFX)
local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)
local Theme = require(script.Parent.Theme)

local Combat = {}

local player = Players.LocalPlayer

local function elementColor(e: string?): Color3
	local el = e and DragonConfig.element(e)
	return if el then el.glow else Color3.fromRGB(255, 200, 120)
end

-- parte d'effetto (locale, senza collisioni)
local function fxPart(shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, transparency: number?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency or 0.2
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = workspace
	return p
end

-- anello che si allarga a terra
local function shockwave(at: Vector3, radius: number, color: Color3, time: number?)
	local t = time or 0.45
	local ring = fxPart(Enum.PartType.Cylinder, Vector3.new(0.4, 2, 2), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), color, 0.1)
	TweenService:Create(ring, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, t + 0.1)
	local dome = fxPart(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(at), color, 0.4)
	TweenService:Create(dome, TweenInfo.new(t * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 1.2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(dome, t)
end

local function shake(amount: number)
	local cam = workspace.CurrentCamera
	task.spawn(function()
		for k = 1, 8 do
			local s = amount * (1 - k / 8)
			cam.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.04 * s, (math.random() - 0.5) * 0.04 * s, 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

local function myRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

------------------------------------------------------------------------------------------
-- Effetti dal server

local function stunStars(model: Instance, seconds: number)
	if not model:IsA("Model") then
		return
	end
	local _, size = model:GetBoundingBox()
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.fromOffset(80, 30)
	bill.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.55 + 1.5, 0)
	bill.AlwaysOnTop = true
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "✦ ✦ ✦"
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.fromRGB(255, 230, 90)
	l.TextStrokeTransparency = 0.4
	l.Parent = bill
	bill.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	bill.Parent = model
	Debris:AddItem(bill, seconds)
	task.spawn(function()
		local t0 = os.clock()
		while bill.Parent and os.clock() - t0 < seconds do
			l.Rotation = math.sin((os.clock() - t0) * 8) * 12
			task.wait(0.05)
		end
	end)
end

local function meteor(sky: Vector3, ground: Vector3, fall: number)
	-- cerchio d'avviso a terra
	local warn = fxPart(Enum.PartType.Cylinder, Vector3.new(0.3, 24, 24), CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 70, 40), 0.55)
	Debris:AddItem(warn, fall)
	local rock = fxPart(Enum.PartType.Ball, Vector3.one * 5, CFrame.new(sky), Color3.fromRGB(255, 120, 40), 0)
	local fire = Instance.new("Fire")
	fire.Size = 14
	fire.Heat = 20
	fire.Color = Color3.fromRGB(255, 120, 40)
	fire.SecondaryColor = Color3.fromRGB(160, 60, 255)
	fire.Parent = rock
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 2, 0)
	a0.Parent = rock
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -2, 0)
	a1.Parent = rock
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(140, 60, 255))
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = rock
	TweenService:Create(rock, TweenInfo.new(fall, Enum.EasingStyle.Linear), { CFrame = CFrame.new(ground) }):Play()
	task.delay(fall, function()
		rock:Destroy()
		shockwave(ground, 14, Color3.fromRGB(255, 130, 50), 0.5)
		Sfx.play("Esplosione", ground)
		local root = myRoot()
		if root and (root.Position - ground).Magnitude < 60 then
			shake(1.2)
		end
	end)
end

local function fireball(from: Vector3, to: Vector3, element: string, travel: number)
	local warn = fxPart(Enum.PartType.Cylinder, Vector3.new(0.3, 20, 20), CFrame.new(to + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 60, 40), 0.6)
	Debris:AddItem(warn, travel)
	DragonVFX.shot(element, from, to, elementColor(element))
	task.delay(travel, function()
		shockwave(to, 10, elementColor(element), 0.35)
	end)
end

------------------------------------------------------------------------------------------
-- Draghi volanti: si muovono qui (posizione dagli attributi, uguale al server)

type Leaving = { t0: number, cf: CFrame, dead: boolean }
local leaving: { [Model]: Leaving } = {}

local function flash(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.4
	h.OutlineTransparency = 1
	h.Parent = model
	Debris:AddItem(h, 0.12)
end

local function moveFlyers()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local now = workspace:GetServerTimeNow()
	for _, m in CollectionService:GetTagged("Volante") do
		if not m:IsA("Model") then
			continue
		end
		local l = leaving[m]
		if l then
			local t = os.clock() - l.t0
			if l.dead then
				-- cade roteando
				m:PivotTo(l.cf * CFrame.new(0, -t * t * 30, 0) * CFrame.Angles(t * 1.5, 0, t))
			else
				-- vola via in alto
				m:PivotTo(l.cf + Vector3.new(0, t * 60, 0) + l.cf.LookVector * t * 80)
			end
			continue
		end
		local center = m:GetAttribute("Center")
		if typeof(center) == "Vector3" and (center - camPos).Magnitude < 1500 then
			local cf = UpgradeConfig.flyerCFrame(center, m:GetAttribute("Radius") :: number, m:GetAttribute("Height") :: number, m:GetAttribute("Speed") :: number, now)
			-- battito d'ali: sobbalzo leggero
			m:PivotTo(cf * CFrame.new(0, math.sin(os.clock() * 5) * 1.2, 0))
		end
	end
end

------------------------------------------------------------------------------------------
-- Draghi Shiny: brillii dorati e un filo di luce

local function decorateShiny(m: Instance)
	if not m:IsA("Model") or not m:GetAttribute("Shiny") or m:FindFirstChild("ShinyFX", true) then
		return
	end
	local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "ShinyFX"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 110))
	e.LightEmission = 1
	e.Rate = 14
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.7, 0)
	e.Parent = part
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 90)
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = part
end

------------------------------------------------------------------------------------------
-- Attacco speciale

local function special()
	local readyAt = (player:GetAttribute("SpecialReady") or 0) :: number
	if workspace:GetServerTimeNow() < readyAt then
		ClientState.hint = string.format("Dragon special ready in %d s", math.ceil(readyAt - workspace:GetServerTimeNow()))
		return
	end
	if (player:GetAttribute("PetAbilities") or "") == "" then
		ClientState.hint = "You need a dragon following you (G)"
		return
	end
	local r = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("DragonSpecial") :: RemoteEvent?
	if r then
		r:FireServer()
	end
end

------------------------------------------------------------------------------------------

function Combat.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	task.spawn(function()
		local fx = remotes:WaitForChild("EnemyFX", 60) :: RemoteEvent?
		if not fx then
			return
		end
		(fx :: RemoteEvent).OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any)
			if kind == "special" then
				-- onda dell'elemento del drago
				local color = elementColor(c)
				shockwave(a, b, color, 0.6)
				task.delay(0.12, shockwave, a, b * 0.7, Color3.new(1, 1, 1), 0.4)
				Sfx.play("Ruggito", a)
				if d == player.UserId then
					shake(1)
				end
			elseif kind == "plunge" then
				shockwave(a, b, Color3.fromRGB(200, 230, 255), 0.4)
				Sfx.play("Roccia", a)
				local root = myRoot()
				if root and (root.Position - a).Magnitude < 30 then
					shake(1.4)
				end
			elseif kind == "stun" then
				stunStars(a, b)
			elseif kind == "bounce" then
				local p = fxPart(Enum.PartType.Block, Vector3.new(0.5, 0.5, 2.4), CFrame.lookAt(a, b), Color3.fromRGB(180, 220, 255), 0)
				TweenService:Create(p, TweenInfo.new(0.18), { CFrame = CFrame.lookAt(b, b + (b - a)) }):Play()
				Debris:AddItem(p, 0.22)
			elseif kind == "meteor" then
				meteor(a, b, c)
			elseif kind == "fireball" then
				fireball(a, b, c, d)
			elseif kind == "flyerHurt" then
				flash(a)
			elseif kind == "flyerDeath" or kind == "flyerLeave" then
				if typeof(a) == "Instance" and a:IsA("Model") then
					leaving[a] = { t0 = os.clock(), cf = a:GetPivot(), dead = kind == "flyerDeath" }
					if kind == "flyerDeath" then
						Sfx.play("Ruggito", a:GetPivot().Position, 1.5)
					end
				end
			end
		end)
	end)

	-- tasto Z e pulsante del telefono
	ContextActionService:BindAction("SpecialeDrago", function(_, state)
		if state == Enum.UserInputState.Begin then
			special()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Z, Enum.KeyCode.ButtonY)

	-- interfaccia: pulsante del drago, cronometro, evento
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	-- pulsante dell'attacco speciale (in basso al centro, a destra della barra degli attrezzi)
	local touch = UserInputService.TouchEnabled
	local spBtn = Instance.new("TextButton")
	spBtn.Name = "Speciale"
	spBtn.AnchorPoint = Vector2.new(0.5, 1)
	spBtn.Position = if touch then UDim2.new(1, -120, 1, -110) else UDim2.new(0.5, 230, 1, -14)
	spBtn.Size = UDim2.fromOffset(64, 64)
	spBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	spBtn.Text = ""
	spBtn.Visible = false
	spBtn.Parent = gui
	Theme.corner(spBtn, 32)
	Theme.gradient(spBtn, Color3.fromRGB(60, 40, 90), Color3.fromRGB(18, 14, 30), 90)
	local spStroke = Instance.new("UIStroke")
	spStroke.Thickness = 2.5
	spStroke.Color = Theme.ACCENT
	spStroke.Parent = spBtn
	local spIcon = Theme.label(spBtn, "🐉", 26, Theme.TEXT, true)
	spIcon.Size = UDim2.new(1, 0, 1, -14)
	spIcon.TextXAlignment = Enum.TextXAlignment.Center
	local spKey = Theme.label(spBtn, if touch then "Roar" else "Z", 12, Theme.ACCENT, true)
	spKey.AnchorPoint = Vector2.new(0, 1)
	spKey.Position = UDim2.new(0, 0, 1, -4)
	spKey.Size = UDim2.new(1, 0, 0, 14)
	spKey.TextXAlignment = Enum.TextXAlignment.Center
	local spCool = Theme.label(spBtn, "", 20, Theme.TEXT, true)
	spCool.Size = UDim2.fromScale(1, 1)
	spCool.TextXAlignment = Enum.TextXAlignment.Center
	spCool.BackgroundTransparency = 0.35
	spCool.BackgroundColor3 = Color3.new(0, 0, 0)
	spCool.ZIndex = 3
	Theme.corner(spCool, 32)
	spBtn.Activated:Connect(special)

	-- cronometro della discesa e evento in corso (in alto al centro, sotto le monete)
	local timer = Theme.label(gui, "", 22, Theme.ACCENT, true)
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0, 46)
	timer.Size = UDim2.new(0, 320, 0, 28)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.TextStrokeTransparency = 0.4
	local eventLabel = Theme.label(gui, "", 15, Color3.fromRGB(255, 170, 120), true)
	eventLabel.AnchorPoint = Vector2.new(0.5, 0)
	eventLabel.Position = UDim2.new(0.5, 0, 0, 76)
	eventLabel.Size = UDim2.new(0, 520, 0, 22)
	eventLabel.TextXAlignment = Enum.TextXAlignment.Center
	eventLabel.TextStrokeTransparency = 0.4

	local accum = 0
	RunService.RenderStepped:Connect(function(dt)
		moveFlyers()
		accum += dt
		if accum < 0.1 then
			return
		end
		accum = 0
		-- attacco speciale
		local hasDragon = (player:GetAttribute("PetAbilities") or "") ~= ""
		spBtn.Visible = hasDragon and not ClientState.dragonMode
		local left = ((player:GetAttribute("SpecialReady") or 0) :: number) - workspace:GetServerTimeNow()
		spCool.Visible = left > 0
		spCool.Text = if left > 0 then tostring(math.ceil(left)) else ""
		spStroke.Color = if left > 0 then Theme.MUTED else Theme.ACCENT
		-- discesa a tempo
		local started = player:GetAttribute("DescentStart")
		if type(started) == "number" then
			local s = workspace:GetServerTimeNow() - started
			local best = player:GetAttribute("BestDescent")
			timer.Text = string.format("DESCENT %d:%04.1f%s", s // 60, s % 60, if type(best) == "number" then string.format("  (best %.1f s)", best) else "")
		else
			timer.Text = ""
		end
		-- evento della mappa
		local ev = workspace:GetAttribute("WorldEvent")
		local at = workspace:GetAttribute("WorldEventPos")
		local root = myRoot()
		if type(ev) == "string" then
			local dist = if typeof(at) == "Vector3" and root then string.format("  ·  %d m", math.floor((at - root.Position).Magnitude)) else ""
			eventLabel.Text = ev .. dist
		else
			eventLabel.Text = ""
		end
	end)

	-- draghi shiny (anche quelli degli altri)
	local pets = workspace:WaitForChild("Pets")
	pets.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d:GetAttribute("Owner") then
			task.delay(0.5, decorateShiny, d)
		end
	end)
	for _, d in pets:GetDescendants() do
		decorateShiny(d)
	end
end

return Combat
