--!strict
-- Modalita' regista per registrare clip di gameplay VERO (comando admin "regista"): niente
-- interfaccia, giochi normalmente e la camera fa le inquadrature da clip. Tasti:
--   J / L   inquadratura precedente / successiva:
--             spalla   dietro la spalla, morbida, campo stretto (scalata, combattimenti)
--             boss     tu e il nemico piu' vicino (drago volante, yeti, golem) sempre in quadro
--             drone    giro lento dall'alto attorno a te (eventi, paesaggi, meteore)
--             selfie   davanti a te, guardi in camera: il drago o il boss alle spalle
--             caduta   dall'alto verso il basso mentre cadi: si vede quanto e' profondo
--   Y       righe del taglio 9:16 (per inquadrare; spegnile prima di registrare)
--   H       mostra/nasconde l'HUD (barre, monete, discesa)
-- Il mouse gira la camera come sempre. "regista" di nuovo per uscire.
-- Anche "sfilata": gli 8 draghi adulti in fila che ruggiscono uno dopo l'altro (formato "vota
-- ogni drago da 1 a 10"); i modelli li mette il server (cartella Workspace.Sfilata).

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local KfsPlayer = require(script.Parent.KfsPlayer)
local Sfx = require(script.Parent.Sfx)

local Regista = {}

local player = Players.LocalPlayer
local MODES = { "spalla", "boss", "drone", "selfie", "caduta" }
local on = false
local mode = 1
local yaw, pitch = 0, -0.15
local smoothCf: CFrame? = nil
local hiddenGuis: { ScreenGui } = {}
local hudShown = false
local guides: ScreenGui? = nil
local label: TextLabel? = nil

local function rootOf(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- bersaglio piu' vicino: drago volante, poi nemici
local function nearestFoe(from: Vector3): Vector3?
	local best, bestD = nil, 400
	for _, m in CollectionService:GetTagged("Volante") do
		if m:IsA("Model") then
			local d = (m:GetPivot().Position - from).Magnitude
			if d < bestD then
				best, bestD = m:GetPivot().Position, d
			end
		end
	end
	local enemies = workspace:FindFirstChild("Nemici")
	for _, m in (if enemies then enemies:GetChildren() else {}) :: { Instance } do
		local r = m:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			local d = (r.Position - from).Magnitude
			if d < bestD * 0.6 then -- i draghi volanti hanno la precedenza
				best, bestD = r.Position, d
			end
		end
	end
	return best
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- la camera non entra nella montagna: se tra il personaggio e la camera c'e' roccia si avvicina
local function unblock(focus: Vector3, cam: Vector3): Vector3
	local d = cam - focus
	local hit = workspace:Raycast(focus, d, terrainOnly)
	if hit then
		return hit.Position - d.Unit * 1.5
	end
	return cam
end

local function showMode()
	if label then
		label.Text = "REGISTA: " .. string.upper(MODES[mode]) .. "   (J/L cambia, Y righe 9:16, H HUD)"
		label.TextTransparency = 0
		local text = label.Text
		task.delay(1.5, function()
			if label and label.Text == text then
				label.TextTransparency = 1
			end
		end)
	end
end

local function step(dt: number)
	local root = rootOf()
	local cam = workspace.CurrentCamera
	if not root then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local p = root.Position + Vector3.new(0, 1.5, 0)
	local look = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local want: CFrame
	local fov = 62
	local m = MODES[mode]
	if m == "spalla" then
		local camPos = p + (look * CFrame.new(2.6, 1.2, 10)).Position
		want = CFrame.lookAt(unblock(p, camPos), p + look.LookVector * 30 + Vector3.new(0, 1, 0))
		fov = 58
	elseif m == "boss" then
		local foe = nearestFoe(p)
		if foe then
			-- dietro di te sulla linea nemico -> te, un po' in alto: tutti e due in quadro
			local away = p - foe
			local flatAway = Vector3.new(away.X, 0, away.Z)
			flatAway = if flatAway.Magnitude > 0.1 then flatAway.Unit else Vector3.zAxis
			local dist = away.Magnitude
			local camPos = p + flatAway * (12 + dist * 0.25) + Vector3.new(0, 6 + dist * 0.12, 0) + flatAway:Cross(Vector3.yAxis) * 5
			want = CFrame.lookAt(unblock(p, camPos), foe:Lerp(p, 0.35))
			fov = math.clamp(45 + dist * 0.18, 50, 85)
		else
			local camPos = p + (look * CFrame.new(3, 2, 14)).Position
			want = CFrame.lookAt(unblock(p, camPos), p + look.LookVector * 30)
		end
	elseif m == "drone" then
		local a = os.clock() * 0.12
		local camPos = p + Vector3.new(math.cos(a) * 70, 45, math.sin(a) * 70)
		want = CFrame.lookAt(camPos, p)
		fov = 55
	elseif m == "selfie" then
		local face = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		face = if face.Magnitude > 0.1 then face.Unit else Vector3.zAxis
		local camPos = p + face * 9 + Vector3.new(0, 1.5, 0) + face:Cross(Vector3.yAxis) * 1.5
		want = CFrame.lookAt(unblock(p, camPos), p + Vector3.new(0, 0.8, 0))
		fov = 60
	else -- caduta
		local v = root.AssemblyLinearVelocity
		local side = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		local camPos = p + Vector3.new(0, 14, 0) + side * 6 - Vector3.new(0, math.min(0, v.Y) * 0.05, 0)
		want = CFrame.lookAt(camPos, p - Vector3.new(0, 40, 0))
		fov = 70
	end
	-- morbida (niente scatti), piu' reattiva quando giri il mouse in spalla
	local k = 1 - math.exp(-dt * (if m == "spalla" then 9 else 5))
	smoothCf = if smoothCf then (smoothCf :: CFrame):Lerp(want, k) else want
	cam.CFrame = smoothCf :: CFrame
	cam.FieldOfView += (fov - cam.FieldOfView) * math.min(1, dt * 3)
end

local function setHud(show: boolean)
	hudShown = show
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = show
		end
	end
end

function Regista.toggle()
	on = not on
	local cam = workspace.CurrentCamera
	if on then
		hiddenGuis = {}
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "Regista" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		local gui = Instance.new("ScreenGui")
		gui.Name = "Regista"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 300
		gui.Parent = player.PlayerGui
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 30)
		l.Position = UDim2.new(0, 0, 1, -40)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 18
		l.TextColor3 = Color3.fromRGB(255, 220, 120)
		l.TextStrokeTransparency = 0.4
		l.Parent = gui
		label = l
		-- righe del taglio 9:16 (centrato)
		local g9 = Instance.new("ScreenGui")
		g9.Name = "ReggiaGuide"
		g9.IgnoreGuiInset = true
		g9.Enabled = false
		g9.DisplayOrder = 299
		g9.Parent = player.PlayerGui
		local vp = cam.ViewportSize
		local w = vp.Y * 9 / 16
		for _, x in { (vp.X - w) / 2, (vp.X + w) / 2 } do
			local f = Instance.new("Frame")
			f.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
			f.BorderSizePixel = 0
			f.Size = UDim2.new(0, 2, 1, 0)
			f.Position = UDim2.fromOffset(x, 0)
			f.Parent = g9
		end
		guides = g9
		local _, y = cam.CFrame:ToEulerAnglesYXZ()
		yaw = y
		smoothCf = nil
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		RunService:BindToRenderStep("Regista", Enum.RenderPriority.Camera.Value + 2, step)
		showMode()
	else
		RunService:UnbindFromRenderStep("Regista")
		setHud(true)
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		end)
		for _, name in { "Regista", "ReggiaGuide" } do
			local g = player.PlayerGui:FindFirstChild(name)
			if g then
				g:Destroy()
			end
		end
		label, guides = nil, nil
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

------------------------------------------------------------------------------------------
-- Sfilata: la camera passa davanti a ogni drago adulto mentre ruggisce

function Regista.sfilata()
	local folder = workspace:WaitForChild("Sfilata", 10)
	if not folder then
		return
	end
	task.wait(1.5) -- i modelli arrivano (streaming)
	local list = {}
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b)
		return ((a:GetAttribute("Order") or 0) :: number) < ((b:GetAttribute("Order") or 0) :: number)
	end)
	-- animazioni: fermo in loop, ruggito quando tocca a lui
	local saves = ReplicatedStorage:FindFirstChild("DragonAnimSaves")
	local roars = {}
	for _, m in list do
		local set = saves and saves:FindFirstChild((m:GetAttribute("AnimKey") or "") :: string)
		if set then
			local idle = set:FindFirstChild("Dragon_Idle")
			if idle and idle:IsA("KeyframeSequence") then
				KfsPlayer.load(m, idle):Play(0, 1)
			end
			local roar = set:FindFirstChild("Dragon_Roar")
			if roar and roar:IsA("KeyframeSequence") then
				local tr = KfsPlayer.load(m, roar)
				tr.Looped = false
				roars[m] = tr
			end
			m:SetAttribute("AnimRange", 600)
		end
	end
	local wasOn = on
	if not on then
		Regista.toggle()
	end
	RunService:UnbindFromRenderStep("Regista")
	local cam = workspace.CurrentCamera
	local PER = 2.6
	local t0 = os.clock()
	local current = 0
	RunService:BindToRenderStep("Sfilata", Enum.RenderPriority.Camera.Value + 3, function()
		cam.CameraType = Enum.CameraType.Scriptable
		local u = (os.clock() - t0) / PER
		local i = math.clamp(math.floor(u) + 1, 1, #list)
		local m = list[i]
		if not m then
			return
		end
		if i ~= current then
			current = i
			local tr = roars[m]
			if tr then
				tr.time = 0
				tr:Play(0.1, 1.6)
				task.delay(tr.clip.length, function()
					tr:Stop(0.3)
				end)
			end
			Sfx.play("Ruggito", m:GetPivot().Position, 2)
		end
		local cf, size = m:GetBoundingBox()
		local front = m:GetPivot().LookVector
		local local_u = u - math.floor(u)
		-- da un lato verso il muso, leggermente dal basso (il drago sembra enorme)
		local side = front:Cross(Vector3.yAxis)
		local r = math.max(size.X, size.Z) * 0.95
		local camPos = cf.Position + front * r + side * r * (0.6 - 1.2 * local_u) + Vector3.new(0, -size.Y * 0.15, 0)
		cam.CFrame = CFrame.lookAt(camPos, cf.Position + Vector3.new(0, size.Y * 0.2, 0))
		cam.FieldOfView = 60
	end)
	task.wait(PER * #list + 0.5)
	RunService:UnbindFromRenderStep("Sfilata")
	if wasOn then
		RunService:BindToRenderStep("Regista", Enum.RenderPriority.Camera.Value + 2, step)
	else
		Regista.toggle()
	end
end

function Regista.start()
	ContextActionService:BindAction("RegistaTasti", function(_, state, input)
		if not on or state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.L then
			mode = mode % #MODES + 1
			showMode()
		elseif input.KeyCode == Enum.KeyCode.J then
			mode = (mode - 2) % #MODES + 1
			showMode()
		elseif input.KeyCode == Enum.KeyCode.Y then
			if guides then
				(guides :: ScreenGui).Enabled = not (guides :: ScreenGui).Enabled
			end
		elseif input.KeyCode == Enum.KeyCode.H then
			setHud(not hudShown)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.J, Enum.KeyCode.L, Enum.KeyCode.Y, Enum.KeyCode.H)
	UserInputService.InputChanged:Connect(function(input)
		if on and input.UserInputType == Enum.UserInputType.MouseMovement then
			yaw -= input.Delta.X * 0.004
			pitch = math.clamp(pitch - input.Delta.Y * 0.004, -1.2, 0.8)
		end
	end)
end

return Regista
