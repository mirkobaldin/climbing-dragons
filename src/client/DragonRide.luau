--!strict
-- In groppa al drago adulto (serve la Sella, server/Riding). Tasto H (o il pulsante "Ride" sul
-- telefono): sali e scendi. In volo si va dove guarda la camera:
--   WASD / joystick   avanti, indietro, di lato
--   Spazio / Ctrl     su / giu' (sul telefono si sale e scende guardando in alto o in basso)
--   Shift             piu' veloce
--   click / F         il drago spara la palla del suo elemento dove miri (server/Enemies
--                     RideAttack); Z resta l'attacco speciale. In groppa niente attrezzi
--                     (il rampino tirava giu' il drago)
-- Il tuo personaggio e' seduto e lo spinge una LinearVelocity; il drago lo mette sotto di te
-- PetAnimator (attributo "Riding", lo vedono tutti).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local ClientState = require(script.Parent.ClientState)
local Climbing = require(script.Parent.Climbing)
local Sfx = require(script.Parent.Sfx)

local DragonRide = {}

local player = Players.LocalPlayer
local SPEED, BOOST, CLIMB = 70, 125, 45
local SIT_ANIM = "rbxassetid://2506281703" -- seduto (animazione standard di Roblox, R15)

local mover: LinearVelocity? = nil
local turner: AlignOrientation? = nil
local att: Attachment? = nil
local sitTrack: AnimationTrack? = nil
local riding = false

local function remote(): RemoteEvent?
	return ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("DragonRide") :: RemoteEvent?
end

local function cleanup()
	for _, o in { mover, turner, att } :: { Instance? } do
		if o then
			o:Destroy()
		end
	end
	mover, turner, att = nil, nil, nil
	if sitTrack then
		sitTrack:Stop(0.2)
		sitTrack = nil
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end
	riding = false
	ClientState.riding = false
	ClientState.noFallUntil = os.clock() + 2
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end)
end

local function mount()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or riding then
		return
	end
	Climbing.release()
	riding = true
	ClientState.riding = true
	-- attrezzi riposti e barra nascosta: il click ora e' il colpo del drago
	humanoid:UnequipTools()
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	local a = Instance.new("Attachment")
	a.Name = "MontaDrago"
	a.Parent = root
	att = a
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = a
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.new(0, 25, 0) -- decollo
	lv.Parent = root
	mover = lv
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = a
	ao.MaxTorque = 1e6
	ao.Responsiveness = 18
	ao.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
	ao.Parent = root
	turner = ao
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = SIT_ANIM
		local ok, tr = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and tr then
			tr.Priority = Enum.AnimationPriority.Action4
			tr.Looped = true
			tr:Play(0.2)
			sitTrack = tr
		end
	end
	Sfx.play("Ruggito", root.Position, 0.8)
end

-- colpo del drago: punto mirato col mouse (sul telefono il centro dello schermo), escluso te e
-- i tuoi draghi
local lastShot = 0
local function shoot(screenPos: Vector2?)
	if not riding or os.clock() - lastShot < 0.35 then
		return
	end
	lastShot = os.clock()
	local camera = workspace.CurrentCamera
	local at = screenPos or Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local ray = camera:ViewportPointToRay(at.X, at.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	if player.Character then
		table.insert(skip, player.Character)
	end
	local pets = workspace:FindFirstChild("Pets")
	local mine = pets and pets:FindFirstChild(tostring(player.UserId))
	if mine then
		table.insert(skip, mine)
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	local aim = if hit then hit.Position else ray.Origin + ray.Direction * 260
	local r = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("RideAttack") :: RemoteEvent?
	if r then
		r:FireServer(aim)
	end
end

local function toggle()
	local r = remote()
	if not r then
		return
	end
	if player:GetAttribute("Riding") then
		r:FireServer(false)
	else
		r:FireServer(true)
	end
end

-- il drago adulto al seguito (posto 1), per sapere se mostrare il pulsante
local function adultFollowing(): boolean
	local raw = player:GetAttribute("DragonData")
	if type(raw) ~= "string" then
		return false
	end
	local ok, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" or not data.equipped then
		return false
	end
	for _, d in data.dragons or {} do
		if d.id == data.equipped[1] then
			return (d.stage or 1) >= #DragonConfig.STAGES
		end
	end
	return false
end

function DragonRide.start()
	ContextActionService:BindAction("MontaDrago", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H)
	-- colpo del drago: click sinistro o F (pad: R2)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not riding or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			shoot(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			shoot(nil)
		end
	end)

	-- pulsante (telefono e computer): compare con un drago adulto al seguito e la sella
	local gui = Instance.new("ScreenGui")
	gui.Name = "MontaDrago"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local btn = Instance.new("TextButton")
	btn.Name = "Ride"
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Size = UDim2.fromOffset(84, 40)
	btn.Position = if UserInputService.TouchEnabled then UDim2.new(1, -24, 0.5, 0) else UDim2.new(1, -24, 1, -120)
	btn.BackgroundColor3 = Color3.fromRGB(24, 30, 46)
	btn.BackgroundTransparency = 0.1
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 16
	btn.TextColor3 = Color3.fromRGB(255, 214, 120)
	btn.Text = "Ride"
	btn.Visible = false
	btn.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 196, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- sul bordo, non sulle lettere (sembravano sfocate)
	stroke.Parent = btn
	btn.Activated:Connect(toggle)
	-- sul telefono: pulsante del colpo (sopra quello per scendere)
	local fire = btn:Clone()
	fire.Name = "Fire"
	fire.Text = "Fire"
	fire.TextColor3 = Color3.fromRGB(255, 160, 110)
	fire.Position = btn.Position - UDim2.fromOffset(0, 52)
	fire.Visible = false
	fire.Parent = gui
	fire.Activated:Connect(function()
		shoot(nil)
	end)

	local r = remote()
	if r then
		r.OnClientEvent:Connect(function(message: string)
			ClientState.hint = message
		end)
	end

	player:GetAttributeChangedSignal("Riding"):Connect(function()
		if player:GetAttribute("Riding") then
			mount()
		else
			cleanup()
		end
	end)
	player.CharacterAdded:Connect(function()
		mover, turner, att, sitTrack = nil, nil, nil, nil
		riding = false
		ClientState.riding = false
	end)

	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum > 0.5 then
			accum = 0
			local can = player:GetAttribute("Gear_Sella") == true and adultFollowing() and not ClientState.dragonMode
			btn.Visible = can
			btn.Text = if player:GetAttribute("Riding") then "Land (H)" else (if UserInputService.TouchEnabled then "Ride" else "Ride (H)")
			fire.Visible = riding and UserInputService.TouchEnabled
		end
		if not riding or not mover then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			cleanup()
			return
		end
		local camera = workspace.CurrentCamera
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local right = flat:Cross(Vector3.yAxis)
		-- comandi del movimento (tastiera o joystick del telefono)
		local move = Vector3.zero
		local ok, controls = pcall(function()
			return (require(player.PlayerScripts:WaitForChild("PlayerModule")) :: any):GetControls()
		end)
		if ok and controls then
			local v = controls:GetMoveVector() -- x destra, z indietro
			move = right * v.X - flat * v.Z
		end
		local up = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			up += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
			up -= 1
		end
		local fast = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		local speed = if fast then BOOST else SPEED
		local want = Vector3.zero
		if move.Magnitude > 0.05 then
			-- avanti si va anche su e giu' dove guarda la camera (comodo sul telefono)
			local dir = move.Unit + Vector3.new(0, look.Y * math.max(0, move.Unit:Dot(flat)), 0)
			want = dir * speed * math.min(1, move.Magnitude)
		end
		want += Vector3.new(0, up * CLIMB, 0)
		if move.Magnitude < 0.05 and up == 0 then
			want = Vector3.new(0, math.sin(os.clock() * 2) * 1.5, 0) -- in volo fermo: ondeggia appena
		end
		local lv = mover :: LinearVelocity
		lv.VectorVelocity = lv.VectorVelocity:Lerp(want, math.min(1, dt * 3))
		local face = if want.Magnitude > 5 then Vector3.new(want.X, 0, want.Z) else flat
		if face.Magnitude > 0.1 and turner then
			(turner :: AlignOrientation).CFrame = CFrame.lookAt(Vector3.zero, face.Unit)
		end
		ClientState.noFallUntil = os.clock() + 1
	end)
end

return DragonRide
