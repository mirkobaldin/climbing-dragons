--!strict
-- Lancio della piccozza (tasto Q o pulsante sul telefono, con la Piccozza in mano e a terra):
-- carica il braccio dietro la testa, lancia, la piccozza vola roteando verso dove guardi (55
-- studs, o fino alla roccia), poi torna indietro curvando e la riprendi al volo. Il danno lo
-- calcola il server (Remotes.PickaxeThrow).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.ClientState)

local PickaxeThrow = {}

local player = Players.LocalPlayer
local RANGE = 55
local SPEED = 90 -- studs al secondo (uguale al server)
local busy = false

local function joints(character: Model): { [string]: any }
	local out = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			out[d.Name] = d
		end
	end
	return out
end

local function throw()
	local character = player.Character
	local tool = character and character:FindFirstChildWhichIsA("Tool")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if busy or not tool or tool.Name ~= "Piccozza" or not root or ClientState.climbing or (ClientState :: any).dragonMode then
		return
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end
	busy = true
	local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("PickaxeThrow") :: RemoteEvent?
	local cam = workspace.CurrentCamera
	local dir = Vector3.new(cam.CFrame.LookVector.X, math.clamp(cam.CFrame.LookVector.Y, -0.4, 0.4), cam.CFrame.LookVector.Z).Unit
	local j = joints(character :: Model)
	-- 1) carica: braccio destro dietro la testa (0.22 s), busto girato
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Stepped:Connect(function()
		local t = os.clock() - t0
		local wind = math.clamp(t / 0.22, 0, 1)
		local release = math.clamp((t - 0.22) / 0.12, 0, 1)
		local a = 170 * wind - 230 * release -- spalla: su e indietro, poi giu' in avanti
		if j.RightShoulder then
			j.RightShoulder.Transform = CFrame.Angles(math.rad(a), 0, 0)
		end
		if j.RightElbow then
			j.RightElbow.Transform = CFrame.Angles(math.rad(60 * wind * (1 - release)), 0, 0)
		end
		if j.Waist then
			j.Waist.Transform = CFrame.Angles(0, math.rad(-25 * wind + 40 * release), 0)
		end
		if t > 0.6 then
			conn:Disconnect()
		end
	end)
	task.wait(0.28)
	if remote then
		remote:FireServer(dir)
	end
	-- 2) la piccozza vola: copia del manico, l'originale si nasconde
	local flying = Instance.new("Model")
	flying.Name = "PiccozzaLanciata"
	for _, p in tool:GetDescendants() do
		if p:IsA("BasePart") then
			local c = p:Clone()
			for _, d in c:GetDescendants() do
				if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") or d:IsA("Sound") then
					d:Destroy()
				end
			end
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
			c.Parent = flying
			p.LocalTransparencyModifier = 1
		end
	end
	flying.PrimaryPart = flying:FindFirstChild("Handle") :: BasePart?
	flying.Parent = workspace
	-- scia
	local trailHost = flying.PrimaryPart
	if trailHost then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)
		a0.Parent, a1.Parent = trailHost, trailHost
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
		tr.Transparency = NumberSequence.new(0.3, 1)
		tr.Lifetime = 0.2
		tr.LightEmission = 0.6
		tr.Parent = trailHost
	end
	-- fin dove arriva: 55 studs o la prima roccia/nemico
	local from = (root :: BasePart).Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance, flying }
	local hit = workspace:Raycast(from, dir * RANGE, params)
	local far = if hit then hit.Position - dir * 1.5 else from + dir * RANGE
	local outTime = (far - from).Magnitude / SPEED
	local side = dir:Cross(Vector3.yAxis)
	side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
	local start = os.clock()
	local spin = 0
	local done = false
	local fly: RBXScriptConnection
	fly = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - start
		spin += dt * 22
		local pos: Vector3
		if t < outTime then
			pos = from:Lerp(far, t / outTime)
		else
			-- ritorno: curva verso la mano (che intanto puo' essersi mossa)
			local back = math.clamp((t - outTime) / (outTime * 1.1 + 0.15), 0, 1)
			local hand = character:FindFirstChild("RightHand") :: BasePart?
			local target = if hand then hand.Position else (root :: BasePart).Position
			pos = far:Lerp(target, back * back * (3 - 2 * back)) + side * math.sin(back * math.pi) * 6
			if back >= 1 then
				done = true
			end
		end
		local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(spin, 0, 0)
		if flying.PrimaryPart then
			flying:PivotTo(cf)
		end
		if done then
			fly:Disconnect()
			flying:Destroy()
			for _, p in tool:GetDescendants() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 0
				end
			end
			busy = false
		end
	end)
	-- se qualcosa va storto non resta bloccato
	task.delay(4, function()
		if busy then
			if fly.Connected then
				fly:Disconnect()
			end
			if flying.Parent then
				flying:Destroy()
			end
			for _, p in tool:GetDescendants() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 0
				end
			end
			busy = false
		end
	end)
end

function PickaxeThrow.start()
	ContextActionService:BindAction("LancioPiccozza", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(throw)
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.Q)
	ContextActionService:SetTitle("LancioPiccozza", "Throw")
	ContextActionService:SetPosition("LancioPiccozza", UDim2.new(1, -150, 1, -190))
end

return PickaxeThrow
