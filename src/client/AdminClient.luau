--!strict
-- Barra dei comandi admin: tasto ; (o F2) per aprirla, scrivi il comando e premi Invio
-- ("help" per l'elenco). Freccia su = comando precedente. Visibile solo agli admin.
-- Volo e noclip li fa il client (il personaggio e' simulato qui), dopo il si' del server.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local AdminClient = {}

local flying = false
local noclip = false
local flyVelocity: BodyVelocity? = nil
local flyGyro: BodyGyro? = nil
local controls: any = nil

local function stopFly()
	flying = false
	for _, inst in { flyVelocity, flyGyro } do
		if inst then
			inst:Destroy()
		end
	end
	flyVelocity, flyGyro = nil, nil
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function startFly()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	stopFly()
	flying = true
	humanoid.PlatformStand = true
	local v = Instance.new("BodyVelocity")
	v.MaxForce = Vector3.new(1e7, 1e7, 1e7)
	v.Velocity = Vector3.zero
	v.Parent = root
	local g = Instance.new("BodyGyro")
	g.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
	g.P = 20000
	g.Parent = root
	flyVelocity, flyGyro = v, g
end

local function applyAction(action: string)
	local cmd, arg = string.match(action, "^(%S+)%s*(.*)$")
	if cmd == "cinematica" then
		task.spawn(require(script.Parent.Cinematic).play)
	elseif cmd == "tiktok" then
		task.spawn(require(script.Parent.GrappleSkit).play)
	elseif cmd == "trailer" then
		local kind, take = string.match(arg, "^(%S+)%s*(%S*)$")
		task.spawn(require(script.Parent.Trailer).play, kind or "trailer", if take and take ~= "" then take else nil)
	elseif cmd == "regista" then
		require(script.Parent.Regista).toggle()
	elseif cmd == "sfilata" then
		task.spawn(require(script.Parent.Regista).sfilata)
	elseif cmd == "fly" then
		startFly()
	elseif cmd == "unfly" then
		stopFly()
	elseif cmd == "noclip" then
		noclip = true
	elseif cmd == "clip" then
		noclip = false
		local character = player.Character
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					d.CanCollide = d.Name == "Torso" or d.Name == "UpperTorso" or d.Name == "LowerTorso" or d.Name == "Head"
				end
			end
		end
	elseif cmd == "speed" then
		ClientState.speedOverride = tonumber(arg)
	end
end

function AdminClient.start()
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	controls = playerModule:GetControls()

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminBar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -12)
	frame.Size = UDim2.new(0.6, 0, 0, 36)
	frame.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = frame
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -16, 1, 0)
	box.Position = UDim2.new(0, 8, 0, 0)
	box.BackgroundTransparency = 1
	box.ClearTextOnFocus = false
	box.PlaceholderText = "Comando admin (help)..."
	box.Text = ""
	box.Font = Enum.Font.Code
	box.TextSize = 16
	box.TextColor3 = Color3.fromRGB(230, 230, 230)
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = frame
	local output = Instance.new("TextLabel")
	output.AnchorPoint = Vector2.new(0.5, 1)
	output.Position = UDim2.new(0.5, 0, 1, -54)
	output.Size = UDim2.new(0.6, 0, 0, 0)
	output.AutomaticSize = Enum.AutomaticSize.Y
	output.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	output.BackgroundTransparency = 0.2
	output.Font = Enum.Font.Code
	output.TextSize = 14
	output.TextColor3 = Color3.fromRGB(200, 220, 200)
	output.TextXAlignment = Enum.TextXAlignment.Left
	output.TextWrapped = true
	output.Text = ""
	output.Visible = false
	output.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = output

	local history: { string } = {}
	local historyIndex = 0

	local function open()
		if not player:GetAttribute("IsAdmin") then
			return
		end
		gui.Enabled = true
		task.defer(function()
			box:CaptureFocus()
			box.Text = ""
		end)
	end

	ContextActionService:BindAction("AdminBar", function(_, state)
		if state == Enum.UserInputState.Begin then
			if gui.Enabled and not box:IsFocused() then
				gui.Enabled = false
			else
				open()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Semicolon, Enum.KeyCode.F2)

	-- sul telefono non c'e' F2: due pulsanti visibili solo agli admin (il server controlla
	-- comunque ogni comando). "Admin" apre la barra (esce la tastiera), "God" accende e spegne
	-- la modalita' dio con un tocco.
	local buttons = Instance.new("ScreenGui")
	buttons.Name = "AdminButtons"
	buttons.ResetOnSpawn = false
	buttons.Enabled = false
	buttons.Parent = player:WaitForChild("PlayerGui")
	local godOn = false
	local row = Instance.new("Frame")
	row.Name = "Riga"
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, -12, 0, 170) -- sotto il riquadro dell'ora
	row.Size = UDim2.fromOffset(190, 40)
	row.BackgroundTransparency = 1
	row.Parent = buttons
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 12)
	layout.Parent = row
	for k, info in { { "Admin", Color3.fromRGB(60, 70, 110) }, { "God", Color3.fromRGB(150, 110, 30) } } do
		local b = Instance.new("TextButton")
		b.Name = info[1]
		b.LayoutOrder = k
		b.Size = UDim2.fromOffset(84, 38)
		b.BackgroundColor3 = info[2]
		b.Font = Enum.Font.GothamBold
		b.TextSize = 16
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = info[1]
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = b
		b.Parent = row
		b.Activated:Connect(function()
			if info[1] == "Admin" then
				if gui.Enabled then
					gui.Enabled = false
				else
					open()
				end
			else
				godOn = not godOn
				local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
				local fn = remote and remote:FindFirstChild("AdminCommand")
				if fn and fn:IsA("RemoteFunction") then
					task.spawn(function()
						fn:InvokeServer(if godOn then "god" else "ungod")
					end)
				end
				b.Text = if godOn then "God ON" else "God"
			end
		end)
	end
	local function showButtons()
		buttons.Enabled = player:GetAttribute("IsAdmin") == true
	end
	showButtons()
	player:GetAttributeChangedSignal("IsAdmin"):Connect(showButtons)

	box.FocusLost:Connect(function(enter)
		if not enter then
			return
		end
		local text = box.Text
		box.Text = ""
		if text == "" then
			gui.Enabled = false
			return
		end
		table.insert(history, text)
		historyIndex = #history + 1
		local ok, message, action = (remotes:WaitForChild("AdminCommand") :: RemoteFunction):InvokeServer(text)
		output.Visible = true
		output.Text = message or ""
		output.TextColor3 = if ok then Color3.fromRGB(200, 230, 200) else Color3.fromRGB(240, 150, 140)
		if ok and type(action) == "string" then
			applyAction(action)
		end
		task.defer(function()
			box:CaptureFocus()
		end)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if box:IsFocused() and #history > 0 then
			if input.KeyCode == Enum.KeyCode.Up then
				historyIndex = math.max(1, historyIndex - 1)
				box.Text = history[historyIndex]
			elseif input.KeyCode == Enum.KeyCode.Down then
				historyIndex = math.min(#history + 1, historyIndex + 1)
				box.Text = history[historyIndex] or ""
			end
		elseif input.KeyCode == Enum.KeyCode.Escape then
			gui.Enabled = false
		end
	end)

	player.CharacterAdded:Connect(function()
		stopFly()
		noclip = false
	end)

	-- comandi che un admin ha fatto per te ("to <nome> fly"): li esegue questo client
	local actionEvent = remotes:WaitForChild("AdminAction", 30)
	if actionEvent and actionEvent:IsA("RemoteEvent") then
		actionEvent.OnClientEvent:Connect(function(action: any, from: any)
			if type(action) == "string" then
				applyAction(action)
				output.Visible = true
				output.Text = tostring(from or "")
				output.TextColor3 = Color3.fromRGB(200, 230, 200)
			end
		end)
	end

	-- volo: WASD relativo alla camera, Spazio su, Ctrl/C giu', Shift veloce
	RunService.RenderStepped:Connect(function()
		if flying and flyVelocity and flyGyro then
			local camera = workspace.CurrentCamera
			local move = if controls then controls:GetMoveVector() else Vector3.zero
			local dir = camera.CFrame:VectorToWorldSpace(Vector3.new(move.X, 0, move.Z))
			local typing = box:IsFocused()
			if not typing and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				dir += Vector3.yAxis
			end
			if not typing and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C)) then
				dir -= Vector3.yAxis
			end
			local fast = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			local speed = if fast then 260 else 90
			flyVelocity.Velocity = if dir.Magnitude > 0.01 then dir.Unit * speed else Vector3.zero
			flyGyro.CFrame = camera.CFrame
		end
	end)
	RunService.Stepped:Connect(function()
		if noclip and player.Character then
			for _, d in player.Character:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
				end
			end
		end
	end)
end

return AdminClient
