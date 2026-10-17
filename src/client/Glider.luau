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

-- vela sopra i giocatori che planano (anche il tuo): i modelli di Codex in
-- ReplicatedStorage.Vele (AlpineParaglider; DragonWings e AncientStormWyvern con le ali che
-- battono). Quale: attributo "GliderSkin" del giocatore (comando admin "vela").
local canopies: { [Player]: Model } = {}
local GLIDER_SCALE = 2.8
type Wing = { weld: Weld, rest: CFrame, head: Vector3, side: number, tip: boolean }
local wings: { [Model]: { Wing } } = {}

local function modelCanopy(owner: Player, root: BasePart): Model?
	local vele = ReplicatedStorage:FindFirstChild("Vele")
	if not vele then
		return nil
	end
	-- la vela migliore che ha (Gear.glider); GliderSkin = scelta dell'admin per le prove
	local own = Gear.glider(owner)
	local skin = owner:GetAttribute("GliderSkin") or (if own then own.skin else nil)
	local tpl = (type(skin) == "string" and vele:FindFirstChild(skin)) or vele:FindFirstChild("AlpineParaglider")
	if not tpl or not tpl:IsA("Model") then
		return nil
	end
	local m = tpl:Clone()
	m.Name = "Vela"
	local col = m:FindFirstChild("Collisione")
	if col then
		col:Destroy()
	end
	m:ScaleTo(GLIDER_SCALE)
	-- il punto dell'imbragatura (ATTACH_Player) sul bacino; il modello guarda +Z: si gira
	local attach = m:FindFirstChild("ATTACH_Player", true)
	local up = if attach and attach:IsA("Attachment") then attach.Position.Y else 0.95 * GLIDER_SCALE
	m:PivotTo(root.CFrame * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, -up, 0))
	local list: { Wing } = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = p
			w.C0 = root.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
			local bone = p:GetAttribute("Bone")
			if type(bone) == "string" and string.find(bone, "WING", 1, true) then
				local rootBone = string.gsub(string.gsub(bone, "_TIP$", ""), "_ROOT$", "")
				local headM = m:GetAttribute("BoneHead_" .. rootBone .. (if m:GetAttribute("BoneHead_" .. rootBone .. "_ROOT") then "_ROOT" else ""))
				if typeof(headM) == "Vector3" then
					-- l'osso in metri nello spazio del modello -> spazio del bacino
					local head = root.CFrame:PointToObjectSpace(m:GetPivot():PointToWorldSpace(headM * GLIDER_SCALE))
					table.insert(list, { weld = w, rest = w.C0, head = head, side = if head.X >= 0 then 1 else -1, tip = string.find(bone, "TIP", 1, true) ~= nil })
				end
			end
		end
	end
	if #list > 0 then
		wings[m] = list
	end
	m.Parent = root.Parent
	return m
end

local function canopy(owner: Player): Model?
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local made = modelCanopy(owner, root)
	if made then
		return made
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

-- in aria col parapendio nello zaino (per il pulsante Glide del telefono, client/MobileControls:
-- il salto del telefono non e' il tasto Spazio e prima non si poteva aprire la vela)
function Glider.available(): boolean
	if gliding then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil and humanoid ~= nil and Gear.hasGlider(player) and not ClientState.climbing
		and not ClientState.riding and humanoid.FloorMaterial == Enum.Material.Air and root.AssemblyLinearVelocity.Y < 2
end

-- apre o chiude la vela; anyFall: basta essere in aria (il pulsante), non serve gia' cadere forte
function Glider.toggle(anyFall: boolean?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if gliding then
		stop()
		return true
	end
	-- in groppa al drago niente vela (Spazio li' fa salire il drago)
	if not root or not humanoid or not Gear.hasGlider(player) or ClientState.climbing or ClientState.riding or player:GetAttribute("Riding") == true then
		return false
	end
	local vy = root.AssemblyLinearVelocity.Y
	local falling = humanoid.FloorMaterial == Enum.Material.Air and (if anyFall then vy < 2 else vy < -G.MIN_FALL_SPEED)
	if falling then
		start()
		return true
	end
	return false
end

function Glider.isGliding(): boolean
	return gliding
end

function Glider.start()
	ContextActionService:BindAction("Parapendio", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		return if Glider.toggle(false) then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	RunService.Heartbeat:Connect(function(dt)
		-- tuo volo
		if gliding then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 or humanoid.FloorMaterial ~= Enum.Material.Air or ClientState.climbing or ClientState.grappling or ClientState.riding then
				stop()
			elseif mover then
				local look = workspace.CurrentCamera.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				flat = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
				-- velocita' e discesa della vela che hai (Gear.GLIDERS); col drago al seguito dal
				-- livello DRAGON_GLIDE_LEVEL ancora piu' veloce
				local sail = Gear.glider(player)
				local base = if sail then sail.speed else G.SPEED
				local speed = if dragonLevel() >= UpgradeConfig.DRAGON_GLIDE_LEVEL then base + (G.DRAGON_SPEED - G.SPEED) else base
				local fall = if sail then sail.fall else G.FALL
				-- guardando in giu' si scende piu' in fretta (e si va piu' veloci)
				local dive = math.clamp(-look.Y, 0, 0.8)
				local want = flat * speed * (1 + dive * 0.5) + Vector3.new(0, -fall - dive * 30, 0)
				local current = (mover :: LinearVelocity).VectorVelocity
				;(mover :: LinearVelocity).VectorVelocity = current:Lerp(want, math.min(1, dt * 2.5))
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
				ClientState.noFallUntil = os.clock() + 0.5 -- planando non ci si fa male
			end
		end
		-- ali dei glider di drago: battono piano mentre plani
		local t = os.clock()
		for m, list in wings do
			if not m.Parent then
				wings[m] = nil
				continue
			end
			local a = math.sin(t * 2.4) * 0.16 + 0.05
			for _, w in list do
				local rot = CFrame.new(w.head) * CFrame.Angles(0, 0, w.side * a * (if w.tip then 1.5 else 1)) * CFrame.new(-w.head)
				w.weld.C0 = rot * w.rest
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
