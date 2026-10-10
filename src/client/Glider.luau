--!strict
-- Parapendio (si costruisce al Banco da lavoro, Gear "Parapendio"): Spazio mentre cadi lo apre,
-- Spazio di nuovo (o toccare terra, o aggrapparsi) lo chiude. Si guida con la camera: vai dove
-- guardi, scendendo piano. Col drago al seguito dal livello DRAGON_GLIDE_LEVEL si va piu' veloci.
-- La vela la vedono tutti: il server mette l'attributo "Gliding" (remote "Glide") e ogni client
-- disegna la vela sopra chi ce l'ha.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gear"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)

local Glider = {}

local player = Players.LocalPlayer
local G = UpgradeConfig.GLIDE
local gliding = false
local mover: LinearVelocity? = nil
local glideAttachment: Attachment? = nil

local function remote(): RemoteEvent?
	return ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Glide") :: RemoteEvent?
end

-- livello del primo drago al seguito (dal JSON pubblicato dal server)
local function dragonLevel(): number
	local raw = player:GetAttribute("DragonData")
	if type(raw) ~= "string" then
		return 0
	end
	local ok, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" then
		return 0
	end
	local id = data.equipped and data.equipped[1]
	for _, d in data.dragons or {} do
		if d.id == id then
			return d.level or 1
		end
	end
	return 0
end

local function stop()
	if not gliding then
		return
	end
	gliding = false
	if mover then
		mover:Destroy()
		mover = nil
	end
	if glideAttachment then
		glideAttachment:Destroy()
		glideAttachment = nil
	end
	ClientState.noFallUntil = os.clock() + 0.6
	local r = remote()
	if r then
		r:FireServer(false)
	end
end

local function start()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if gliding or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	gliding = true
	local a = Instance.new("Attachment")
	a.Parent = root
	glideAttachment = a
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = a
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = root.AssemblyLinearVelocity
	lv.Parent = root
	mover = lv
	Sfx.play("Lancio", root.Position)
	local r = remote()
	if r then
		r:FireServer(true)
	end
end

-- vela sopra i giocatori che planano (anche il tuo)
local canopies: { [Player]: Model } = {}
local function canopy(owner: Player): Model?
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Vela"
	local wing = Instance.new("Part")
	wing.Name = "Vela"
	wing.Size = Vector3.new(11, 0.4, 3.6)
	wing.Material = Enum.Material.Fabric
	wing.Color = Color3.fromRGB(230, 120, 40)
	wing.CanCollide = false
	wing.CanQuery = false
	wing.Massless = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.5, 1)
	mesh.Parent = wing
	wing.CFrame = root.CFrame * CFrame.new(0, 7, 0)
	wing.Parent = m
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = wing
	weld.Parent = wing
	-- corde dalla vela alle spalle
	for _, side in { -1, 1 } do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(side * 4.6, 0, 0)
		a0.Parent = wing
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(side * 0.8, 1, 0)
		a1.Parent = root
		local rope = Instance.new("Beam")
		rope.Attachment0 = a0
		rope.Attachment1 = a1
		rope.Width0, rope.Width1 = 0.08, 0.08
		rope.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
		rope.FaceCamera = true
		rope.Parent = wing
	end
	m.Parent = character
	return m
end

function Glider.start()
	ContextActionService:BindAction("Parapendio", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if gliding then
			stop()
			return Enum.ContextActionResult.Sink
		end
		if not root or not humanoid or not Gear.has(player, "Parapendio") or ClientState.climbing then
			return Enum.ContextActionResult.Pass
		end
		local falling = humanoid.FloorMaterial == Enum.Material.Air and root.AssemblyLinearVelocity.Y < -G.MIN_FALL_SPEED
		if falling then
			start()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	RunService.Heartbeat:Connect(function(dt)
		-- tuo volo
		if gliding then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 or humanoid.FloorMaterial ~= Enum.Material.Air or ClientState.climbing then
				stop()
			elseif mover then
				local look = workspace.CurrentCamera.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				flat = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
				local speed = if dragonLevel() >= UpgradeConfig.DRAGON_GLIDE_LEVEL then G.DRAGON_SPEED else G.SPEED
				-- guardando in giu' si scende piu' in fretta (e si va piu' veloci)
				local dive = math.clamp(-look.Y, 0, 0.8)
				local want = flat * speed * (1 + dive * 0.5) + Vector3.new(0, -G.FALL - dive * 30, 0)
				local current = (mover :: LinearVelocity).VectorVelocity
				;(mover :: LinearVelocity).VectorVelocity = current:Lerp(want, math.min(1, dt * 2.5))
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
				ClientState.noFallUntil = os.clock() + 0.5 -- planando non ci si fa male
			end
		end
		-- vele di tutti
		for _, p in Players:GetPlayers() do
			local want = p:GetAttribute("Gliding") == true or (p == player and gliding)
			local has = canopies[p]
			if want and (not has or not has.Parent) then
				local m = canopy(p)
				if m then
					canopies[p] = m
				end
			elseif not want and has then
				has:Destroy()
				canopies[p] = nil
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		gliding = false
		mover = nil
		glideAttachment = nil
	end)
end

return Glider
