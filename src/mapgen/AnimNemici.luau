--!strict
-- Generatore delle animazioni dei nemici (strumento di Studio: non gira nel gioco).
-- Dalla Command Bar di Studio:
--   require(game.ServerStorage.MapGen.AnimNemici).genera()          -- tutti i rig
--   require(game.ServerStorage.MapGen.AnimNemici).genera("Yeti")    -- uno solo
-- Per ogni rig in Workspace.RigNemici con scheletro Mixamo (mixamorig:Hips, ...) crea in
-- ServerStorage.RBX_ANIMSAVES.<rig> tre animazioni che si aprono nell'Animation Editor:
--   nemico-cammina (passo alternato, braccia opposte alle gambe, busto curvo)
--   nemico-fermo   (respiro, braccia che dondolano, sguardo che si guarda attorno)
--   nemico-attacco (carica a braccia alzate, colpo a terra a 0.5 s, ritorno)
-- Il verso di ogni rotazione si decide provandola sul rig (es. quale verso porta il piede avanti).

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local AnimNemici = {}

local UP = Vector3.yAxis
local KEYS = 16

type Skel = { rig: Model, mesh: MeshPart, rest: { [Bone]: CFrame }, b: { [string]: Bone }, fwd: Vector3, right: Vector3 }

local function bone(rig: Model, name: string): Bone?
	local b = rig:FindFirstChild("mixamorig:" .. name, true)
	return if b and b:IsA("Bone") then b else nil
end

local function analizza(rig: Model): Skel
	local mesh = rig:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart
	local rest = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Bone") then
			d.Transform = CFrame.identity
		end
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("Bone") then
			rest[d] = d.WorldCFrame
		end
	end
	local b: { [string]: Bone } = {}
	for _, n in { "Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot" } do
		local x = bone(rig, n)
		assert(x, rig.Name .. ": manca l'osso " .. n)
		b[n] = x :: Bone
	end
	-- davanti: dalla testa verso "headfront" (se c'e'), se no dal pivot del modello
	local front = rig:FindFirstChild("headfront", true)
	local fwd = if front and front:IsA("Bone") then front.WorldPosition - b.Head.WorldPosition else rig:GetPivot().LookVector
	fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
	return { rig = rig, mesh = mesh, rest = rest, b = b, fwd = fwd, right = fwd:Cross(UP) }
end

local function bodyRot(sk: Skel, b: Bone, axis: Vector3, deg: number): CFrame
	local Q = sk.rest[b].Rotation
	return Q:Inverse() * CFrame.fromAxisAngle(axis, math.rad(deg)) * Q
end

local function signFor(sk: Skel, b: Bone, axis: Vector3, tip: Bone, measure: (Vector3) -> number): number
	local before = tip.WorldPosition
	b.Transform = bodyRot(sk, b, axis, 8)
	local moved = tip.WorldPosition - before
	b.Transform = CFrame.identity
	return if measure(moved) >= 0 then 1 else -1
end

type Poses = { [Bone]: CFrame }
local function add(poses: Poses, sk: Skel, b: Bone, axis: Vector3, deg: number)
	poses[b] = (poses[b] or CFrame.identity) * bodyRot(sk, b, axis, deg)
end

type Signs = { [string]: number }
local function computeSigns(sk: Skel): Signs
	local b, fwd, right = sk.b, sk.fwd, sk.right
	local s: Signs = {}
	for _, side in { "Left", "Right" } do
		s[side .. "Swing"] = signFor(sk, b[side .. "UpLeg"], right, b[side .. "Foot"], function(m) return m:Dot(fwd) end) -- + = piede avanti
		s[side .. "Knee"] = signFor(sk, b[side .. "Leg"], right, b[side .. "Foot"], function(m) return -m:Dot(fwd) end) -- + = ginocchio piegato
		s[side .. "ArmFwd"] = signFor(sk, b[side .. "Arm"], right, b[side .. "Hand"], function(m) return m:Dot(fwd) end) -- + = mano avanti
		s[side .. "ArmUp"] = signFor(sk, b[side .. "Arm"], right, b[side .. "Hand"], function(m) return m.Y end) -- + = mano su
		s[side .. "Elbow"] = signFor(sk, b[side .. "ForeArm"], right, b[side .. "Hand"], function(m) return m.Y + m:Dot(fwd) end) -- + = gomito piegato
	end
	s.Lean = signFor(sk, b.Spine, right, b.Head, function(m) return m:Dot(fwd) end) -- + = busto in avanti
	return s
end

-- posa di base: busto un po' curvo in avanti, gomiti appena piegati
local function base(poses: Poses, sk: Skel, s: Signs, lean: number)
	add(poses, sk, sk.b.Spine, sk.right, s.Lean * lean)
	for _, side in { "Left", "Right" } do
		add(poses, sk, sk.b[side .. "ForeArm"], sk.right, s[side .. "Elbow"] * 15)
	end
end

local function buildWalk(sk: Skel, s: Signs, p: number): Poses
	local poses: Poses = {}
	base(poses, sk, s, 10)
	local b, right = sk.b, sk.right
	for i, side in { "Left", "Right" } do
		local ph = p + (if i == 2 then 0.5 else 0)
		local swing = math.sin(2 * math.pi * ph)
		local forward = math.cos(2 * math.pi * ph) -- > 0 mentre la gamba va avanti
		add(poses, sk, b[side .. "UpLeg"], right, s[side .. "Swing"] * 26 * swing)
		add(poses, sk, b[side .. "Leg"], right, s[side .. "Knee"] * (8 + 38 * math.max(0, forward)))
		add(poses, sk, b[side .. "Foot"], right, -s[side .. "Swing"] * 10 * math.max(0, forward))
		-- braccio opposto alla gamba dello stesso lato
		add(poses, sk, b[side .. "Arm"], right, -s[side .. "ArmFwd"] * 20 * swing)
	end
	-- bacino che ondeggia, busto che compensa, testa che dondola a ogni passo
	add(poses, sk, b.Hips, UP, 6 * math.sin(2 * math.pi * p))
	add(poses, sk, b.Hips, sk.fwd, 3 * math.sin(2 * math.pi * p))
	add(poses, sk, b.Spine1, UP, -5 * math.sin(2 * math.pi * p))
	add(poses, sk, b.Head, right, 3 * math.sin(4 * math.pi * p))
	return poses
end

local function buildIdle(sk: Skel, s: Signs, p: number): Poses
	local poses: Poses = {}
	base(poses, sk, s, 8)
	local b, right = sk.b, sk.right
	local breath = math.sin(2 * math.pi * p)
	add(poses, sk, b.Spine1, right, s.Lean * -2 * breath)
	add(poses, sk, b.Spine2, right, s.Lean * -1.5 * breath)
	for i, side in { "Left", "Right" } do
		add(poses, sk, b[side .. "Arm"], right, s[side .. "ArmFwd"] * 4 * math.sin(2 * math.pi * p + i))
	end
	add(poses, sk, b.Neck, UP, 12 * math.sin(2 * math.pi * p))
	add(poses, sk, b.Head, right, 3 * breath)
	return poses
end

-- attacco: 0..0.4 carica (braccia su, busto indietro), 0.4..0.55 colpo (braccia giu' e avanti,
-- busto in avanti), poi si torna alla posa di riposo
local function buildAttack(sk: Skel, s: Signs, t: number): Poses
	local poses: Poses = {}
	local b, right = sk.b, sk.right
	local function smooth(x: number): number
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end
	local raise, strike, back
	if t < 0.4 then
		raise, strike, back = smooth(t / 0.4), 0, 0
	elseif t < 0.55 then
		raise, strike, back = 1, smooth((t - 0.4) / 0.15), 0
	else
		raise, strike, back = 1, 1, smooth((t - 0.55) / 0.45)
	end
	local keep = 1 - back
	local lean = (-12 * raise * (1 - strike) + 22 * strike) * keep
	base(poses, sk, s, 8 + lean)
	for _, side in { "Left", "Right" } do
		local armUp = (130 * raise * (1 - strike) + 40 * strike) * keep
		add(poses, sk, b[side .. "Arm"], right, s[side .. "ArmUp"] * armUp)
		add(poses, sk, b[side .. "ForeArm"], right, s[side .. "Elbow"] * 25 * raise * (1 - strike) * keep)
		add(poses, sk, b[side .. "Leg"], right, s[side .. "Knee"] * 20 * strike * keep)
	end
	add(poses, sk, b.Head, right, s.Lean * -10 * raise * (1 - strike) * keep)
	return poses
end

local function writeSequence(sk: Skel, name: string, length: number, loop: boolean, build: (number) -> Poses): KeyframeSequence
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = name
	kfs.Loop = loop
	kfs.Priority = if loop then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
	for i = 0, KEYS do
		local t = i / KEYS * length
		local poses = build(if loop and i == KEYS then 0 else t)
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local rootPose = Instance.new("Pose")
		rootPose.Name = sk.mesh.Name
		rootPose.Weight = 0
		rootPose.Parent = kf
		local made: { [Instance]: Pose } = { [sk.mesh] = rootPose }
		local function poseFor(x: Instance): Pose
			if made[x] then
				return made[x]
			end
			local pose = Instance.new("Pose")
			pose.Name = x.Name
			pose.Weight = 0
			pose.Parent = poseFor(x.Parent :: Instance)
			made[x] = pose
			return pose
		end
		for bn, cf in poses do
			local pose = poseFor(bn)
			pose.CFrame = cf
			pose.Weight = 1
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
		end
		kf.Parent = kfs
	end
	return kfs
end

function AnimNemici.genera(soloNome: string?): string
	local folder = Workspace:FindFirstChild("RigNemici")
	assert(folder, "manca Workspace.RigNemici")
	local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	assert(saves, "manca ServerStorage.RBX_ANIMSAVES")
	local backup = ServerStorage:FindFirstChild("BackupAnimazioni") or Instance.new("Folder")
	backup.Name = "BackupAnimazioni"
	backup.Parent = ServerStorage
	local report = {}
	for _, rig in folder:GetChildren() do
		if rig:IsA("Model") and (not soloNome or rig.Name == soloNome) then
			local sk = analizza(rig)
			local s = computeSigns(sk)
			local store = saves:FindFirstChild(rig.Name) or Instance.new("Model")
			store.Name = rig.Name
			store.Parent = saves
			for name, info in {
				["nemico-cammina"] = { 1.2, true, function(t) return buildWalk(sk, s, t / 1.2) end },
				["nemico-fermo"] = { 2.4, true, function(t) return buildIdle(sk, s, t / 2.4) end },
				["nemico-attacco"] = { 1.0, false, function(t) return buildAttack(sk, s, t) end },
			} do
				local old = store:FindFirstChild(name)
				if old then
					old.Name = rig.Name .. "_" .. name .. "_prima"
					old.Parent = backup
				end
				writeSequence(sk, name, info[1], info[2], info[3]).Parent = store
			end
			for _, d in rig:GetDescendants() do
				if d:IsA("Bone") then
					d.Transform = CFrame.identity
				end
			end
			table.insert(report, rig.Name .. ": cammina, fermo, attacco")
		end
	end
	return table.concat(report, "\n")
end

return AnimNemici
