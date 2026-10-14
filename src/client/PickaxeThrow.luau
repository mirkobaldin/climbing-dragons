--!strict
-- Lancio della piccozza (tasto Q o pulsante sul telefono, con la Piccozza in mano e a terra):
-- carica il braccio dietro la testa, lancia, la piccozza vola roteando verso il mirino (55
-- studs, o fino alla roccia), poi torna indietro curvando e la riprendi al volo. Il danno lo
-- calcola il server (Remotes.PickaxeThrow). Il mirino compare con la piccozza in mano: segue il
-- mouse sul computer, sta al centro dello schermo sul telefono.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClimbConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClimbConfig"))
local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiView"))
local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)

local PickaxeThrow = {}

local player = Players.LocalPlayer
-- portata: potenziamento "Lancio" (55 studs senza)
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local function rangeNow(): number
	return UpgradeConfig.value(Players.LocalPlayer, "Lancio", "range")
end
local SPEED = 90 -- studs al secondo (uguale al server)
local busy = false

-- punto dello schermo da cui si mira: il mouse (computer) o, sul telefono, un punto fisso un po'
-- sopra il centro con la camera spostata oltre la spalla (come Blox Fruits): prima il mirino
-- stava al centro, cioe' sopra il personaggio, e non si vedeva dove si tirava
local function aimScreenPoint(): Vector2
	local cam = workspace.CurrentCamera
	if UserInputService.MouseEnabled and not Ui.touch() then
		return UserInputService:GetMouseLocation()
	end
	return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y * 0.4)
end
local SHOULDER = Vector3.new(2.6, 1.2, 0) -- spostamento della camera con la piccozza in mano (telefono)

-- dove punta il mirino nel mondo (escluso il personaggio, i draghi e la piccozza in volo):
-- prima il raggio partiva dalla mano lungo la camera, che guarda in giu', e colpiva il terreno a
-- due passi: la piccozza girava attorno al braccio e tornava
local function aimPoint(character: Model, extra: { Instance }): Vector3
	local cam = workspace.CurrentCamera
	local screen = aimScreenPoint()
	local ray = cam:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { character }
	for _, name in { "Pets", "PiccozzaLanciata" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, x in extra do
		table.insert(ignore, x)
	end
	params.FilterDescendantsInstances = ignore
	local reach = (cam.CFrame.Position - character:GetPivot().Position).Magnitude + rangeNow()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * reach
end

-- mira assistita: il nemico (yeti, golem) a tiro piu' vicino al mirino sullo schermo, entro
-- un cerchio di ~1/7 dello schermo e senza roccia in mezzo. Prima la piccozza andava solo dritta
-- verso il punto del mirino e mancava i nemici che si muovevano
local function lockTarget(character: Model): (Model?, BasePart?)
	local folder = workspace:FindFirstChild("Nemici")
	if not folder then
		return nil, nil
	end
	local cam = workspace.CurrentCamera
	local screen = aimScreenPoint()
	local radius = math.max(90, cam.ViewportSize.Y / 7)
	local me = character:GetPivot().Position
	local range = rangeNow() + 6
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local best, bestRoot, bestD = nil, nil, radius
	for _, m in folder:GetChildren() do
		local hum = m:FindFirstChildOfClass("Humanoid")
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if m:IsA("Model") and root and hum and hum.Health > 0 and (root.Position - me).Magnitude <= range then
			local p, onScreen = cam:WorldToViewportPoint(root.Position)
			if onScreen then
				-- stesse coordinate del mouse (schermo intero, mirino con IgnoreGuiInset)
				local d = (Vector2.new(p.X, p.Y) - screen).Magnitude
				if d < bestD and not workspace:Raycast(me + Vector3.new(0, 2, 0), root.Position - me - Vector3.new(0, 2, 0), params) then
					best, bestRoot, bestD = m, root, d
				end
			end
		end
	end
	return best, bestRoot
end

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
	if busy or not tool or tool.Name ~= ClimbConfig.TOOL_NAME or not root or ClientState.climbing or (ClientState :: any).dragonMode then
		return
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end
	busy = true
	local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("PickaxeThrow") :: RemoteEvent?
	local from0 = (root :: BasePart).Position + Vector3.new(0, 1.5, 0)
	local target, targetRoot = lockTarget(character :: Model)
	local aim = if targetRoot then targetRoot.Position else aimPoint(character :: Model, {})
	local dir = aim - from0
	if dir.Magnitude < 6 then
		-- mirino sui piedi: si lancia dritto davanti
		local look = workspace.CurrentCamera.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
	end
	dir = dir.Unit
	-- il personaggio si gira verso il bersaglio
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 0.05 then
		(root :: BasePart).CFrame = CFrame.lookAt((root :: BasePart).Position, (root :: BasePart).Position + flat)
	end
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
		remote:FireServer(dir, target)
	end
	Sfx.play("Lancio", (root :: BasePart).Position)
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
	local ignore: { Instance } = { character :: Instance, flying }
	if workspace:FindFirstChild("Pets") then
		table.insert(ignore, workspace.Pets)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, dir * rangeNow(), params)
	local far = if hit and hit.Distance > 4 then hit.Position - dir * 1.5 else from + dir * (if hit then 4 else rangeNow())
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
		-- bersaglio agganciato: la piccozza lo insegue (se si sposta) fino a colpirlo
		if targetRoot and targetRoot.Parent and t < outTime then
			far = targetRoot.Position
		end
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
	-- mirino: solo con la piccozza in mano, a terra, fuori dall'arena dei draghi
	local gui = Instance.new("ScreenGui")
	gui.Name = "MirinoPiccozza"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")
	local cross = Instance.new("Frame")
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Size = UDim2.fromOffset(26, 26)
	cross.BackgroundTransparency = 1
	cross.Visible = false
	cross.Parent = gui
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = 2
	ring.Transparency = 0.2
	local circle = Instance.new("Frame")
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundTransparency = 1
	circle.Parent = cross
	ring.Parent = circle
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = circle
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Color3.fromRGB(255, 200, 90)
	dot.BorderSizePixel = 0
	dot.Parent = cross
	cc:Clone().Parent = dot
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local tool = character and character:FindFirstChildWhichIsA("Tool")
		local show = tool ~= nil and tool.Name == ClimbConfig.TOOL_NAME and not ClientState.climbing and not (ClientState :: any).dragonMode
		cross.Visible = show
		-- telefono: camera oltre la spalla destra finche' hai la piccozza in mano
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			local want = if show and Ui.touch() then SHOULDER else Vector3.zero
			if hum.CameraOffset ~= want and (hum.CameraOffset == Vector3.zero or hum.CameraOffset == SHOULDER) then
				hum.CameraOffset = want
			end
		end
		if show then
			local p = aimScreenPoint()
			-- nemico agganciato: il mirino gli si mette sopra, rosso e piu' grande
			local _, lockRoot = lockTarget(character :: Model)
			if lockRoot and not busy then
				local sp = workspace.CurrentCamera:WorldToViewportPoint(lockRoot.Position)
				cross.Position = UDim2.fromOffset(sp.X, sp.Y)
				cross.Size = UDim2.fromOffset(40, 40)
				ring.Color = Color3.fromRGB(255, 60, 50)
				ring.Thickness = 3
			else
				cross.Position = UDim2.fromOffset(p.X, p.Y)
				cross.Size = UDim2.fromOffset(26, 26)
				ring.Thickness = 2
				-- arancione se il punto mirato e' a tiro (entro la gittata)
				local aim = aimPoint(character :: Model, {})
				local inRange = ((character :: Model):GetPivot().Position - aim).Magnitude <= rangeNow()
				ring.Color = if busy then Color3.fromRGB(120, 120, 120) elseif inRange then Color3.fromRGB(255, 120, 90) else Color3.new(1, 1, 1)
			end
		end
	end)
	ContextActionService:BindAction("LancioPiccozza", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(throw)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)
end

-- Il pulsante in StarterGui usa lo stesso gesto e lo stesso controllo del tasto Q.
PickaxeThrow.activate = throw
return PickaxeThrow
