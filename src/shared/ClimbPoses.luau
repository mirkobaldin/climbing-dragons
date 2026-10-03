--!strict
-- Animazioni d'arrampicata per rig R15, scritte come dati: pose chiave (angoli in gradi delle
-- articolazioni) da cui si costruiscono le KeyframeSequence.
--
--   Climb_Idle  appeso con le due piccozze piantate: destra in alto, sinistra piu' bassa, un
--               piede alzato contro la parete; il busto respira piano. In loop.
--   Climb_Up    trazioni alternate: sale la sinistra e pianta piu' in alto mentre la destra tira,
--               poi il contrario. Comincia e finisce esattamente nella posa di Climb_Idle, cosi'
--               il passaggio tra le due non scatta.
--
-- Transizioni Cubic InOut, priorita' Action. Uso:
--   * in Studio il client le costruisce e le registra al volo (KeyframeSequenceProvider): si
--     vedono subito nei playtest;
--   * per il gioco pubblicato vanno pubblicate su Roblox (vedi README) e gli id messi in
--     ClimbConfig.CLIMB_IDLE_ANIM / CLIMB_UP_ANIM.
--
-- Convenzioni degli angoli (sistema di ogni articolazione, personaggio rivolto verso -Z):
--   braccio/gamba X+  = avanti e in su (verso la parete), Z+ = in fuori per il destro
--   gomito X+ = piega in avanti, ginocchio X- = piega indietro, busto X- = verso la parete

local ClimbPoses = {}

export type Pose = {
	torso: { number }, -- X, Z
	head: number, -- X
	rArm: { number }, -- spalla X, spalla Z, gomito X, polso X
	lArm: { number },
	rLeg: { number }, -- anca X, ginocchio X, caviglia X
	lLeg: { number },
}

-- Posa base (Climb_Idle): destra in alto, sinistra piu' bassa, piede destro alzato
local A: Pose = {
	torso = { -4, 0 },
	head = 14,
	rArm = { 165, 10, 25, -15 },
	lArm = { 125, -12, 45, -20 },
	rLeg = { 65, -90, 25 },
	lLeg = { 20, -35, 10 },
}
-- Posa specchiata: sinistra in alto, destra piu' bassa, piede sinistro alzato
local B: Pose = {
	torso = { -4, 0 },
	head = 14,
	rArm = { 125, 12, 45, -20 },
	lArm = { 165, -10, 25, -15 },
	rLeg = { 20, -35, 10 },
	lLeg = { 65, -90, 25 },
}

local function blend(a: Pose, b: Pose, over: Pose): Pose
	-- `over` sostituisce solo i campi che indica (usato per le pose di passaggio)
	local out = table.clone(a)
	for k, v in over :: any do
		(out :: any)[k] = v
	end
	return out
end

ClimbPoses.CLIPS = {
	Climb_Idle = {
		length = 1.8,
		loop = true,
		frames = {
			{ t = 0, pose = A },
			-- inspira: il busto si avvicina alla parete, le braccia si allungano appena
			{ t = 0.9, pose = blend(A, A, {
				torso = { -7, 1 },
				head = 12,
				rArm = { 168, 10, 22, -15 },
				lArm = { 128, -12, 42, -20 },
			} :: any) },
			{ t = 1.8, pose = A },
		},
	},
	Climb_Up = {
		length = 1.0,
		loop = true,
		frames = {
			{ t = 0, pose = A },
			-- la sinistra sale, la destra tira giu' il corpo, il piede sinistro si alza
			{ t = 0.25, pose = {
				torso = { -6, 4 },
				head = 18,
				rArm = { 140, 12, 50, -25 },
				lArm = { 175, -8, 10, -10 },
				rLeg = { 25, -30, 8 },
				lLeg = { 70, -95, 25 },
			} },
			{ t = 0.5, pose = B },
			-- la destra sale, la sinistra tira, il piede destro si alza
			{ t = 0.75, pose = {
				torso = { -6, -4 },
				head = 18,
				rArm = { 175, 8, 10, -10 },
				lArm = { 140, -12, 50, -25 },
				rLeg = { 70, -95, 25 },
				lLeg = { 25, -30, 8 },
			} },
			{ t = 1.0, pose = A },
		},
	},
}

local function ang(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

local function newPose(name: string, cf: CFrame, parent: Instance?): Instance
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.Weight = 1
	p.EasingStyle = Enum.PoseEasingStyle.Cubic
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	p.Parent = parent
	return p
end

-- Albero delle pose R15 per una posa
local function buildPoses(pose: Pose, keyframe: Instance)
	local root = newPose("HumanoidRootPart", CFrame.new(), keyframe)
	local lower = newPose("LowerTorso", CFrame.new(), root)
	local upper = newPose("UpperTorso", ang(pose.torso[1], 0, pose.torso[2]), lower)
	newPose("Head", ang(pose.head), upper)
	local ra = newPose("RightUpperArm", ang(pose.rArm[1], 0, pose.rArm[2]), upper)
	local rl = newPose("RightLowerArm", ang(pose.rArm[3]), ra)
	newPose("RightHand", ang(pose.rArm[4]), rl)
	local la = newPose("LeftUpperArm", ang(pose.lArm[1], 0, pose.lArm[2]), upper)
	local ll = newPose("LeftLowerArm", ang(pose.lArm[3]), la)
	newPose("LeftHand", ang(pose.lArm[4]), ll)
	local rh = newPose("RightUpperLeg", ang(pose.rLeg[1]), lower)
	local rk = newPose("RightLowerLeg", ang(pose.rLeg[2]), rh)
	newPose("RightFoot", ang(pose.rLeg[3]), rk)
	local lh = newPose("LeftUpperLeg", ang(pose.lLeg[1]), lower)
	local lk = newPose("LeftLowerLeg", ang(pose.lLeg[2]), lh)
	newPose("LeftFoot", ang(pose.lLeg[3]), lk)
end

function ClimbPoses.build(name: string): KeyframeSequence
	local clip = (ClimbPoses.CLIPS :: any)[name]
	assert(clip, "animazione sconosciuta: " .. name)
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = name
	kfs.Loop = clip.loop
	kfs.Priority = Enum.AnimationPriority.Action
	for _, f in clip.frames do
		local kf = Instance.new("Keyframe")
		kf.Time = f.t
		buildPoses(f.pose, kf)
		kf.Parent = kfs
	end
	return kfs
end

return ClimbPoses
