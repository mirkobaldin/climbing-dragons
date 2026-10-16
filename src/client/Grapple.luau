--!strict
-- Rampino (si costruisce al Banco da lavoro): click su un punto lontano fino a GRAPPLE_RANGE
-- studs, l'uncino si aggancia e la corda ti tira fin li'. Se arrivi su una parete ti ci
-- aggrappi (come con la Piccozza), cosi' puoi superare le pareti lisce della montagna.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gear"))
local ClimbConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClimbConfig"))
local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local ClientState = require(script.Parent.ClientState)
local Climbing = require(script.Parent.Climbing)

local player = Players.LocalPlayer

local Grapple = {}

local busy = false
local lastUse = 0

-- portata del rampino (potenziamento "Rampino")
local function range(): number
	return UpgradeConfig.value(player, "Rampino", "range")
end

-- il modello di un nemico o di un drago volante colpito dal raggio (per il colpo d'uncino)
local function enemyOf(inst: Instance): Model?
	for _, name in { "Nemici", "Volanti" } do
		local f = workspace:FindFirstChild(name)
		if f and inst:IsDescendantOf(f) then
			local m = inst
			while m.Parent and m.Parent ~= f do
				m = m.Parent :: Instance
			end
			return if m:IsA("Model") then m else nil
		end
	end
	return nil
end

local function aimRay(root: BasePart): RaycastResult?
	local camera = workspace.CurrentCamera
	local aim = ClientState.aimPoint()
	local ray = camera:ViewportPointToRay(aim.X, aim.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, camera }
	params.IgnoreWater = true
	-- dal punto della camera fino alla portata (misurata dal personaggio)
	local reach = range() + (camera.CFrame.Position - root.Position).Magnitude
	local result = workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	if result and (result.Position - root.Position).Magnitude <= range() then
		return result
	end
	return nil
end

local function fire()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- il drago Fulmine Nero dimezza la ricarica
	local cooldown = Gear.GRAPPLE_COOLDOWN * (if DragonConfig.hasAbility(player, "Fulmine") then 0.5 else 1)
	if busy or not root or not humanoid or os.clock() - lastUse < cooldown then
		return
	end
	-- in groppa al drago il rampino tirava giu' il drago: niente rampino (client/DragonRide)
	if ClientState.riding then
		ClientState.hint = "Land first to use the Grappling Hook"
		return
	end
	local hit = aimRay(root)
	if not hit then
		ClientState.hint = "Too far for the Grappling Hook (max " .. range() .. ")"
		return
	end
	busy = true
	ClientState.grappling = true -- chiude il parapendio (le due spinte si annullavano: restavi fermo in aria)
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
	-- corda dritta (prima una RopeConstraint piu' lunga della distanza: si incurvava)
	local rope = Instance.new("Beam")
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Segments = 1
	rope.CurveSize0, rope.CurveSize1 = 0, 0
	rope.Width0, rope.Width1 = 0.18, 0.18
	rope.FaceCamera = true
	rope.Color = ColorSequence.new(Color3.fromRGB(200, 170, 110))
	rope.LightInfluence = 1
	rope.Parent = anchor
	-- il personaggio si gira verso l'uncino e ci resta girato mentre vola
	humanoid.AutoRotate = false
	local function face(p: Vector3)
		local d = Vector3.new(p.X - root.Position.X, 0, p.Z - root.Position.Z)
		if d.Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + d.Unit)
		end
	end
	face(hit.Position)
	-- prima l'uncino vola fino alla parete, poi la corda tira
	local flyTime = math.clamp((hit.Position - from).Magnitude / Gear.GRAPPLE_SPEED * 0.35, 0.08, 0.45)
	local flight = os.clock()
	while os.clock() - flight < flyTime do
		local a = (os.clock() - flight) / flyTime
		anchor.CFrame = CFrame.lookAt(from:Lerp(hit.Position, a), hit.Position)
		face(hit.Position)
		RunService.Heartbeat:Wait()
	end
	anchor.CFrame = CFrame.new(hit.Position)
	local pull = Instance.new("BodyVelocity")
	pull.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	pull.P = 8000
	pull.Parent = root
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	local target = hit.Position + hit.Normal * 2.5
	-- colpo d'uncino: agganciato a un nemico (o a un drago volante) ti tira addosso a lui
	local foe = enemyOf(hit.Instance)
	if foe then
		local strike = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("GrappleStrike") :: RemoteEvent?
		if strike then
			strike:FireServer(foe)
		end
	end
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if foe and foe.Parent then
			-- il nemico si muove: si punta davanti a lui
			local p = (foe :: Model):GetPivot().Position
			local toMe = root.Position - p
			toMe = if toMe.Magnitude > 0.1 then toMe.Unit else Vector3.yAxis
			target = p + toMe * 5
			anchor.CFrame = CFrame.new(p)
		end
		local offset = target - root.Position
		local done = offset.Magnitude < 3.5 or os.clock() - started > 4 or humanoid.Health <= 0
		if done then
			conn:Disconnect()
			pull:Destroy()
			anchor:Destroy()
			humanoid.AutoRotate = true
			ClientState.grappling = false
			if a1.Name ~= "Bocca" then
				a1:Destroy()
			end
			root.AssemblyLinearVelocity = Vector3.zero
			ClientState.noFallUntil = os.clock() + 2
			if foe then
				ClientState.hint = "Grapple Strike!"
			elseif not Climbing.grabNearest() then
				ClientState.hint = "Hooked!"
			end
			busy = false
			return
		end
		pull.Velocity = offset.Unit * Gear.GRAPPLE_SPEED
		face(target)
	end)
end

function Grapple.start()
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == ClimbConfig.GRAPPLE_NAME and not child:GetAttribute("Bound") then
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
