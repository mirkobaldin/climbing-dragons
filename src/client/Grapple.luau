--!strict
-- Rampino (si costruisce al Banco da lavoro): click su un punto lontano fino a GRAPPLE_RANGE
-- studs, l'uncino si aggancia e la corda ti tira fin li'. Se arrivi su una parete ti ci
-- aggrappi (come con la Piccozza), cosi' puoi superare le pareti lisce della montagna.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gear"))
local ClientState = require(script.Parent.ClientState)
local Climbing = require(script.Parent.Climbing)

local player = Players.LocalPlayer

local Grapple = {}

local busy = false
local lastUse = 0

local function aimRay(root: BasePart): RaycastResult?
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, camera }
	params.IgnoreWater = true
	-- dal punto della camera fino alla portata (misurata dal personaggio)
	local reach = Gear.GRAPPLE_RANGE + (camera.CFrame.Position - root.Position).Magnitude
	local result = workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	if result and (result.Position - root.Position).Magnitude <= Gear.GRAPPLE_RANGE then
		return result
	end
	return nil
end

local function fire()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if busy or not root or not humanoid or os.clock() - lastUse < Gear.GRAPPLE_COOLDOWN then
		return
	end
	local hit = aimRay(root)
	if not hit then
		ClientState.hint = "Troppo lontano per il Rampino (max " .. Gear.GRAPPLE_RANGE .. ")"
		return
	end
	busy = true
	lastUse = os.clock()
	Climbing.release()

	-- uncino + corda (visibile solo a te) e trazione verso il punto
	local anchor = Instance.new("Part")
	anchor.Name = "GrappleHook"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Size = Vector3.new(0.6, 0.6, 0.6)
	anchor.Material = Enum.Material.Metal
	anchor.Color = Color3.fromRGB(160, 164, 170)
	-- la corda parte dalla bocca della pistola (attacco "Bocca" del modello), se c'e'
	local tool = character:FindFirstChildWhichIsA("Tool")
	local muzzle = tool and tool:FindFirstChild("Bocca", true)
	local from = if muzzle and muzzle:IsA("Attachment") then muzzle.WorldPosition else root.Position
	anchor.CFrame = CFrame.lookAt(from, hit.Position)
	anchor.Parent = workspace
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1: Attachment
	if muzzle and muzzle:IsA("Attachment") then
		a1 = muzzle
	else
		a1 = Instance.new("Attachment")
		a1.Parent = root
	end
	local rope = Instance.new("RopeConstraint")
	rope.Visible = true
	rope.Color = BrickColor.new("Brick yellow")
	rope.Thickness = 0.15
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Length = (hit.Position - root.Position).Magnitude + 2
	rope.Parent = anchor
	-- prima l'uncino vola fino alla parete, poi la corda tira
	local flyTime = math.clamp((hit.Position - from).Magnitude / Gear.GRAPPLE_SPEED * 0.35, 0.08, 0.45)
	local flight = os.clock()
	while os.clock() - flight < flyTime do
		local a = (os.clock() - flight) / flyTime
		anchor.CFrame = CFrame.lookAt(from:Lerp(hit.Position, a), hit.Position)
		RunService.Heartbeat:Wait()
	end
	anchor.CFrame = CFrame.new(hit.Position)
	local pull = Instance.new("BodyVelocity")
	pull.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	pull.P = 8000
	pull.Parent = root
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	local target = hit.Position + hit.Normal * 2.5
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local offset = target - root.Position
		local done = offset.Magnitude < 3.5 or os.clock() - started > 4 or humanoid.Health <= 0
		if done then
			conn:Disconnect()
			pull:Destroy()
			anchor:Destroy()
			if a1.Name ~= "Bocca" then
				a1:Destroy()
			end
			root.AssemblyLinearVelocity = Vector3.zero
			ClientState.noFallUntil = os.clock() + 2
			if not Climbing.grabNearest() then
				ClientState.hint = "Agganciato!"
			end
			busy = false
			return
		end
		pull.Velocity = offset.Unit * Gear.GRAPPLE_SPEED
		rope.Length = math.max(2, offset.Magnitude + 1)
	end)
end

function Grapple.start()
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == "Rampino" and not child:GetAttribute("Bound") then
				child:SetAttribute("Bound", true)
				child.Activated:Connect(fire)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return Grapple
