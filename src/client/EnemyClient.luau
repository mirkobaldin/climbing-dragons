--!strict
-- Nemici sul client (server/Enemies decide tutto, qui solo input ed effetti):
--   * click con Piccozza o Piccone vicino a un nemico: colpo (evento "EnemyHit") e fendente
--   * effetti dell'evento "EnemyFX": numeri del danno e lampo, carica, onda d'urto del colpo a
--     terra (con scossa della camera se sei vicino), schegge di ghiaccio quando muore, spinta
--     quando ti colpisce, ricompensa

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClimbConfig = require(Shared:WaitForChild("ClimbConfig"))
local EnemyConfig = require(Shared:WaitForChild("EnemyConfig"))
local Climbing = require(script.Parent.Climbing)

local player = Players.LocalPlayer

local EnemyClient = {}

local ICE = Color3.fromRGB(170, 225, 255)

local function rootOf(model: Instance): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function fxPart(shape: Enum.PartType, size: Vector3, color: Color3, cf: CFrame): Part
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
	p.CFrame = cf
	p.Parent = workspace
	return p
end

local function floatText(at: Vector3, text: string, color: Color3, size: number)
	local anchor = fxPart(Enum.PartType.Block, Vector3.one * 0.2, color, CFrame.new(at))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 6, size)
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
	local drift = Vector3.new((math.random() - 0.5) * 3, 4, (math.random() - 0.5) * 3)
	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + drift) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end

local shake = 0
local function onFx(kind: string, a: any, b: any, c: any)
	if kind == "hurt" then
		local model = a :: Model
		local root = model and rootOf(model)
		if not root then
			return
		end
		floatText(root.Position + Vector3.new(0, root.Size.Y * 0.9, 0), "-" .. math.floor(b), Color3.fromRGB(255, 120, 100), 30)
		local flash = Instance.new("Highlight")
		flash.FillColor = Color3.new(1, 1, 1)
		flash.FillTransparency = 0.4
		flash.OutlineTransparency = 1
		flash.Parent = model
		TweenService:Create(flash, TweenInfo.new(0.25), { FillTransparency = 1 }):Play()
		Debris:AddItem(flash, 0.3)
	elseif kind == "windup" then
		local model = a :: Model
		local glow = Instance.new("Highlight")
		glow.FillColor = Color3.fromRGB(255, 80, 60)
		glow.FillTransparency = 0.75
		glow.OutlineColor = Color3.fromRGB(255, 120, 90)
		glow.Parent = model
		Debris:AddItem(glow, 0.5)
	elseif kind == "slam" then
		local model = a :: Model
		local root = model and rootOf(model)
		if not root then
			return
		end
		local _, size = model:GetBoundingBox()
		local feet = root.Position - Vector3.new(0, size.Y * 0.45, 0) + root.CFrame.LookVector * size.Z * 0.4
		local ring = fxPart(Enum.PartType.Cylinder, Vector3.new(0.3, 2, 2), ICE, CFrame.new(feet) * CFrame.Angles(0, 0, math.pi / 2))
		ring.Transparency = 0.2
		TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, size.Y * 1.6, size.Y * 1.6), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.5)
		for _ = 1, 8 do
			local chunk = fxPart(Enum.PartType.Block, Vector3.one * (0.4 + math.random() * 0.6), ICE, CFrame.new(feet) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6))
			chunk.Material = Enum.Material.Glass
			chunk.Transparency = 0.2
			local dir = Vector3.new(math.random() - 0.5, 1.2, math.random() - 0.5).Unit
			TweenService:Create(chunk, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = chunk.CFrame + dir * 6, Transparency = 1 }):Play()
			Debris:AddItem(chunk, 0.7)
		end
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if me and (me.Position - feet).Magnitude < size.Y * 2.5 then
			shake = math.max(shake, math.clamp(size.Y / 10, 0.4, 1.5))
		end
	elseif kind == "death" then
		local model = a :: Model
		local root = model and rootOf(model)
		if not root then
			return
		end
		local _, size = model:GetBoundingBox()
		for _ = 1, 22 do
			local shard = fxPart(Enum.PartType.Block, Vector3.new(0.3, 0.9, 0.3) * (0.6 + math.random()), ICE, CFrame.new(root.Position + Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.3) * size.Y, (math.random() - 0.5) * size.Z)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0))
			shard.Material = Enum.Material.Glass
			shard.Transparency = 0.15
			local dir = Vector3.new(math.random() - 0.5, 0.6 + math.random(), math.random() - 0.5).Unit
			TweenService:Create(shard, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = shard.CFrame + dir * 9, Transparency = 1 }):Play()
			Debris:AddItem(shard, 1.1)
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				TweenService:Create(d, TweenInfo.new(1.3), { LocalTransparencyModifier = 1 }):Play()
			end
		end
	elseif kind == "knock" then
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if me then
			Climbing.release() -- il colpo ti stacca dalla parete
			-- in aria, se no il controllo del personaggio annulla subito la spinta
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end
			me.AssemblyLinearVelocity += a :: Vector3
			shake = math.max(shake, 0.8)
		end
	elseif kind == "reward" then
		floatText((a :: Vector3) + Vector3.new(0, 6, 0), string.format("+%d coins  +%d XP", b, c), Color3.fromRGB(255, 220, 110), 34)
	end
end

-- il nemico piu' vicino a tiro (prima quelli davanti)
local function enemyInReach(root: BasePart): Model?
	local folder = workspace:FindFirstChild("Nemici")
	if not folder then
		return nil
	end
	local best, bestScore = nil, math.huge
	for _, m in folder:GetChildren() do
		local r = m:IsA("Model") and rootOf(m)
		local humanoid = m:FindFirstChildOfClass("Humanoid")
		if r and humanoid and humanoid.Health > 0 then
			local offset = r.Position - root.Position
			local d = offset.Magnitude
			if d <= EnemyConfig.PLAYER_REACH + r.Size.X * 0.5 then
				local front = offset.Unit:Dot(root.CFrame.LookVector)
				local score = d - front * 6
				if score < bestScore then
					best, bestScore = m, score
				end
			end
		end
	end
	return best
end

function EnemyClient.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fx = remotes:WaitForChild("EnemyFX", 30) :: RemoteEvent?
	local hit = remotes:WaitForChild("EnemyHit", 30) :: RemoteEvent?
	if fx then
		(fx :: RemoteEvent).OnClientEvent:Connect(onFx)
	end
	local function bind(tool: Instance)
		if not tool:IsA("Tool") or tool:GetAttribute("BoundEnemy") then
			return
		end
		if tool.Name ~= ClimbConfig.TOOL_NAME and tool.Name ~= ClimbConfig.PICKAXE_NAME then
			return
		end
		tool:SetAttribute("BoundEnemy", true)
		tool.Activated:Connect(function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or not hit then
				return
			end
			local target = enemyInReach(root :: BasePart)
			if target then
				(hit :: RemoteEvent):FireServer(target)
				-- fendente (lo fa lo script Animate standard quando trova "toolanim")
				local anim = Instance.new("StringValue")
				anim.Name = "toolanim"
				anim.Value = "Slash"
				anim.Parent = tool
				Debris:AddItem(anim, 0.3)
			end
		end)
	end
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(bind)
		for _, c in character:GetChildren() do
			bind(c)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	-- scossa della camera
	RunService.RenderStepped:Connect(function(dt)
		if shake > 0 then
			local camera = workspace.CurrentCamera
			camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.03 * shake, (math.random() - 0.5) * 0.03 * shake, 0)
			shake = math.max(0, shake - dt * 2)
		end
	end)
end

return EnemyClient
