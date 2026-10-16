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
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiView"))
local ClientState = require(script.Parent.ClientState)
local Climbing = require(script.Parent.Climbing)
local Sfx = require(script.Parent.Sfx)

local DragonRide = {}
-- per i pulsanti del telefono (client/MobileControls): puoi salire, monta/scendi, spara
DragonRide.canRide = false

local player = Players.LocalPlayer
local SPEED, BOOST, CLIMB = 70, 125, 45
local SIT_ANIM = "rbxassetid://2506281703" -- seduto (animazione standard di Roblox, R15)

local mover: LinearVelocity? = nil
local turner: AlignOrientation? = nil
local att: Attachment? = nil
local sitTrack: AnimationTrack? = nil
local riding = false
local faceYaw: number? = nil -- direzione del drago in groppa, girata piano verso quella voluta
local TURN_RATE = 4 -- quanto in fretta segue la direzione voluta (1/s)
-- forma di drago (server/Riding, arena dell'Isola dei Draghi): sei il drago. A terra cammina
-- (Shift corre), Spazio decolla, vicino al suolo senza Spazio atterra
local WALK, RUN = 30, 58
local formAir = false
local savedZoom: number? = nil

local function form(): boolean
	return player:GetAttribute("DragonForm") == true
end

-- il tuo drago al seguito (posto 1)
local function leadDragon(): Model?
	local pets = workspace:FindFirstChild("Pets")
	local mine = pets and pets:FindFirstChild(tostring(player.UserId))
	for _, m in (if mine then mine:GetChildren() else {}) :: { Instance } do
		if m:IsA("Model") and (m:GetAttribute("Slot") or 1) == 1 then
			return m
		end
	end
	return nil
end

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
	faceYaw = nil
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
	formAir = false
	if savedZoom then
		player.CameraMinZoomDistance = savedZoom
		savedZoom = nil
	end
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
	lv.VectorVelocity = if form() then Vector3.zero else Vector3.new(0, 25, 0) -- decollo
	lv.Parent = root
	formAir = false
	if form() then
		-- sei il drago: camera piu' lontana, alle spalle del drago e non del collo
		savedZoom = player.CameraMinZoomDistance
		player.CameraMinZoomDistance = 34
	end
	mover = lv
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = a
	-- rigida: la virata morbida la fa il codice (faceYaw); con Responsiveness 18 il personaggio
	-- oscillava di +-10 gradi attorno alla direzione e il drago (che lo copia) andava a scatti
	ao.RigidityEnabled = true
	ao.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
	ao.Parent = root
	turner = ao
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator and not form() then
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

-- dove si mira (coordinate del viewport, barra in alto compresa): il mouse sul computer, sul
-- telefono un punto fisso un po' sopra il centro (il drago sta sotto e non lo copre, come in
-- Blox Fruits). Mirino e segno a terra (aimMarks) mostrano proprio questo punto
local function aimScreen(): Vector2
	local camera = workspace.CurrentCamera
	if Ui.touch() or not UserInputService.MouseEnabled then
		return Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y * 0.4)
	end
	return UserInputService:GetMouseLocation()
end

-- punto del mondo colpito mirando da "at" (escluso te e i tuoi draghi); hit = c'e' una superficie
local function aimAt(at: Vector2): (Vector3, RaycastResult?)
	local camera = workspace.CurrentCamera
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
	return (if hit then hit.Position else ray.Origin + ray.Direction * 260), hit
end

-- colpo del drago verso il mirino
local lastShot = 0
local function shoot(_: Vector2?)
	if not riding or os.clock() - lastShot < 0.35 then
		return
	end
	lastShot = os.clock()
	local aim = aimAt(aimScreen())
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

function DragonRide.toggle()
	toggle()
end

function DragonRide.fire()
	shoot(nil)
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
	-- pillola arancio piena, senza la cornice dorata attorno (Mirko: "cornici inutili")
	btn.BackgroundColor3 = Color3.fromRGB(255, 138, 42)
	btn.BackgroundTransparency = 0
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 16
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextStrokeColor3 = Color3.fromRGB(11, 22, 51)
	btn.TextStrokeTransparency = 0.2
	btn.Text = "Ride"
	btn.Visible = false
	btn.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = btn
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 170, 150))
	shine.Parent = btn
	btn.Activated:Connect(toggle)
	-- sul telefono: pulsante del colpo (sopra quello per scendere)
	local fire = btn:Clone()
	fire.Name = "Fire"
	fire.Text = "Fire"
	fire.BackgroundColor3 = Color3.fromRGB(255, 77, 94)
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

	-- mirino in monta (al mouse o fisso sul telefono) e segno a terra dove arriva il colpo: prima
	-- sul telefono non si sapeva dove andava la palla
	local aimGui = Instance.new("ScreenGui")
	aimGui.Name = "MirinoMonta"
	aimGui.ResetOnSpawn = false
	aimGui.IgnoreGuiInset = true
	aimGui.DisplayOrder = 4
	aimGui.Parent = player:WaitForChild("PlayerGui")
	local reticle = Instance.new("Frame")
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Size = UDim2.fromOffset(34, 34)
	reticle.BackgroundTransparency = 1
	reticle.Visible = false
	reticle.Parent = aimGui
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = reticle
	local rs = Instance.new("UIStroke")
	rs.Color = Color3.fromRGB(255, 120, 60)
	rs.Thickness = 3
	rs.Parent = reticle
	for k = 0, 3 do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		local a = k * math.pi / 2
		tick.Position = UDim2.new(0.5, math.cos(a) * 24, 0.5, math.sin(a) * 24)
		tick.Size = if k % 2 == 0 then UDim2.fromOffset(10, 3) else UDim2.fromOffset(3, 10)
		tick.Parent = reticle
	end
	local mark = Instance.new("Part")
	mark.Name = "SegnoColpo"
	mark.Shape = Enum.PartType.Cylinder
	mark.Size = Vector3.new(0.3, 9, 9)
	mark.Material = Enum.Material.Neon
	mark.Color = Color3.fromRGB(255, 110, 50)
	mark.Transparency = 0.35
	mark.Anchored, mark.CanCollide, mark.CanQuery, mark.CanTouch, mark.CastShadow = true, false, false, false, false
	RunService.RenderStepped:Connect(function()
		reticle.Visible = riding
		if not riding then
			mark.Parent = nil
			return
		end
		local at = aimScreen()
		reticle.Position = UDim2.fromOffset(at.X, at.Y)
		reticle.Rotation = (os.clock() * 40) % 360
		local _, hit = aimAt(at)
		if hit then
			local n = hit.Normal
			mark.CFrame = CFrame.lookAt(hit.Position + n * 0.2, hit.Position + n * 1.2) * CFrame.Angles(0, math.pi / 2, 0)
			mark.Parent = workspace
		else
			mark.Parent = nil
		end
	end)

	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum > 0.5 then
			accum = 0
			local can = player:GetAttribute("Gear_Sella") == true and adultFollowing() and not ClientState.dragonMode
			DragonRide.canRide = can
			-- sul telefono Ride e Fire stanno nell'arco dei comandi (MobileControls): qui prima
			-- finivano a meta' schermo a destra, sotto il riquadro del meteo
			local touch = Ui.touch()
			btn.Visible = (can or form()) and not touch
			btn.Text = if form() then "Leave (H)" elseif player:GetAttribute("Riding") then "Land (H)" else "Ride (H)"
			fire.Visible = false
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
		-- potenziamento del drago Wing Power
		local speed = (if fast then BOOST else SPEED) * UpgradeConfig.value(player, "Ali", "speed")
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
		-- quanto manca fra la pancia del drago e il suolo sotto di lui
		local dragon = leadDragon()
		local gap: number? = nil
		if dragon then
			local bcf, bsize = dragon:GetBoundingBox()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { dragon, character :: Instance }
			local hit = workspace:Raycast(bcf.Position + Vector3.new(0, bsize.Y / 2, 0), Vector3.new(0, -600, 0), params)
			if hit then
				gap = (bcf.Position.Y - bsize.Y / 2) - hit.Position.Y
			end
		end
		if form() then
			local jump = UserInputService:IsKeyDown(Enum.KeyCode.Space) or humanoid.Jump
			if not formAir then
				if jump then
					formAir = true -- decollo
					Sfx.play("Ruggito", root.Position, 0.6)
				else
					-- a terra: passo o corsa nella direzione dei comandi, e il drago resta coi piedi
					-- sul suolo (sale e scende col terreno)
					local walk = if move.Magnitude > 0.05 then move.Unit * (if fast then RUN else WALK) * math.min(1, move.Magnitude) else Vector3.zero
					local vy = if gap then math.clamp(-gap * 8, -80, 45) else -60
					local flatV = Vector3.new(lv.VectorVelocity.X, 0, lv.VectorVelocity.Z):Lerp(walk, math.min(1, dt * 6))
					lv.VectorVelocity = Vector3.new(flatV.X, vy, flatV.Z)
					want = walk
				end
			end
			if formAir then
				if jump then
					want = Vector3.new(want.X, math.max(want.Y, CLIMB), want.Z)
				end
				-- vicino al suolo senza Spazio: atterra
				if gap and gap < 3 and not jump and want.Y <= 1 then
					formAir = false
				end
				lv.VectorVelocity = lv.VectorVelocity:Lerp(want, math.min(1, dt * 3))
			end
		else
			-- in groppa vicino al suolo il drago restava sotto terra (Mirko 15/10): tu stai sul suo
			-- collo, quindi non si scende piu' quando la sua pancia tocca il suolo, e se e' gia' dentro
			-- risale
			if gap and gap < 1 then
				want = Vector3.new(want.X, math.max(want.Y, (1 - gap) * 10), want.Z)
				local v = lv.VectorVelocity
				if v.Y < 0 then
					lv.VectorVelocity = Vector3.new(v.X, 0, v.Z)
				end
			end
			lv.VectorVelocity = lv.VectorVelocity:Lerp(want, math.min(1, dt * 3))
		end
		local face = if want.Magnitude > 5 then Vector3.new(want.X, 0, want.Z) else flat
		if face.Magnitude > 0.1 and turner then
			-- virata morbida: l'angolo si avvicina a quello voluto senza oscillare
			local yaw = math.atan2(-face.X, -face.Z)
			local cur = faceYaw or yaw
			local d = (yaw - cur + math.pi) % (2 * math.pi) - math.pi
			cur += d * math.min(1, dt * TURN_RATE)
			faceYaw = cur
			local ao = turner :: AlignOrientation
			ao.CFrame = CFrame.Angles(0, cur, 0)
		end
		ClientState.noFallUntil = os.clock() + 1
	end)
end

return DragonRide
