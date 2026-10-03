--!strict
-- Piccozze sempre piantate: la roccia non e' liscia, quindi con le sole animazioni la punta a
-- volte spariva dentro la parete e a volte restava sospesa nel vuoto.
-- Ogni frame, subito dopo che l'animazione ha messo in posa il braccio (PreSimulation):
--   1. si calcola dove l'animazione mette la punta della piccozza (cinematica diretta delle
--      giunture: Root, Waist, Shoulder, Elbow, Wrist, presa)
--   2. un raggio lungo la normale della parete misura quanto la punta e' fuori o dentro la roccia
--   3. se la punta e' vicina alla roccia (il braccio sta piantando, non allungando), la mano si
--      sposta solo verso/via dalla parete finche' la punta entra di BITE studs: IK a due ossa
--      su spalla e gomito, con il gomito che resta sul piano scelto dall'animazione
-- L'animazione resta tua: quando il braccio si stacca per allungarsi la correzione svanisce.
-- Funziona con Motor6D e con le AnimationConstraint (le giunture nuove dei personaggi).

local RunService = game:GetService("RunService")

local ClimbIK = {}

local BITE = 0.35 -- quanto entra la punta nella roccia
local ENGAGE = 1.2 -- entro questa distanza dalla roccia la punta viene piantata...
local RELEASE = 2.2 -- ...oltre questa il braccio e' libero (sta allungando)
local MAX_SHIFT = 1.8 -- la mano non si sposta mai piu' di cosi'

type Joint = { inst: Instance, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame }
-- in Studio: distanza della punta dalla roccia prima/dopo (attributo ClimbIK del giocatore)
local debugInfo: { string } = {}
local lastDebug = 0

type Arm = {
	shoulder: Joint,
	elbow: Joint,
	wrist: Joint,
	grip: () -> (CFrame?, Vector3?), -- presa della piccozza rispetto alla mano, misure del manico
	weight: number,
}

local active = false
local wallNormal = Vector3.zAxis
local arms: { Arm } = {}
local chainToTorso: { Joint } = {}
local rootPart: BasePart? = nil
local connection: RBXScriptConnection? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }

local function joint(part: Instance?, name: string): Joint?
	local inst = part and part:FindFirstChild(name)
	if not inst then
		return nil
	end
	if inst:IsA("Motor6D") and inst.Part0 and inst.Part1 then
		return { inst = inst, part0 = inst.Part0, part1 = inst.Part1, c0 = inst.C0, c1 = inst.C1 }
	end
	if inst:IsA("AnimationConstraint") and inst.Attachment0 and inst.Attachment1 then
		local a0, a1 = inst.Attachment0 :: Attachment, inst.Attachment1 :: Attachment
		local p0, p1 = a0.Parent, a1.Parent
		if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
			return { inst = inst, part0 = p0, part1 = p1, c0 = a0.CFrame, c1 = a1.CFrame }
		end
	end
	return nil
end

local function transformOf(j: Joint): CFrame
	return (j.inst :: any).Transform
end

local function setTransform(j: Joint, cf: CFrame)
	(j.inst :: any).Transform = cf
end

-- posa del Part1 data la posa del Part0 e il Transform della giuntura
local function child(j: Joint, parent: CFrame, transform: CFrame): CFrame
	return parent * j.c0 * transform * j.c1:Inverse()
end

-- la piccozza in mano: la saldatura (della presa del Tool o della seconda piccozza) che parte
-- dalla mano e porta a un manico
local function gripFor(hand: BasePart): () -> (CFrame?, Vector3?)
	return function()
		for _, w in hand.Parent and (hand.Parent :: Instance):GetDescendants() or {} do
			if w:IsA("Weld") and w.Part0 == hand and w.Part1 and w.Part1:IsA("BasePart") then
				local name = (w.Part1 :: BasePart).Name
				if name == "Handle" or name == "FakeHandle" or name == "LeftHandle" or name == "OffHandle" then
					return w.C0 * w.C1:Inverse(), (w.Part1 :: BasePart).Size
				end
			end
		end
		return nil, nil
	end
end

function ClimbIK.bind(character: Model)
	table.clear(arms)
	table.clear(chainToTorso)
	rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootJoint = joint(character:FindFirstChild("LowerTorso"), "Root")
	local waist = joint(character:FindFirstChild("UpperTorso"), "Waist")
	if not rootPart or not rootJoint or not waist then
		return -- R6 o rig diverso: niente IK, restano le animazioni
	end
	chainToTorso = { rootJoint, waist }
	for _, side in { "Right", "Left" } do
		local shoulder = joint(character:FindFirstChild(side .. "UpperArm"), side .. "Shoulder")
		local elbow = joint(character:FindFirstChild(side .. "LowerArm"), side .. "Elbow")
		local wrist = joint(character:FindFirstChild(side .. "Hand"), side .. "Wrist")
		local hand = character:FindFirstChild(side .. "Hand")
		if shoulder and elbow and wrist and hand and hand:IsA("BasePart") then
			table.insert(arms, { shoulder = shoulder, elbow = elbow, wrist = wrist, grip = gripFor(hand), weight = 0 })
		end
	end
end

-- rotazione minima che porta la direzione a sulla direzione b
local function rotationBetween(a: Vector3, b: Vector3): CFrame
	local ua, ub = a.Unit, b.Unit
	local axis = ua:Cross(ub)
	local d = math.clamp(ua:Dot(ub), -1, 1)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

-- ruota una posa attorno a un perno (in coordinate del mondo)
local function rotateAbout(cf: CFrame, pivot: Vector3, rot: CFrame): CFrame
	return CFrame.new(pivot) * rot * CFrame.new(-pivot) * cf
end

local function solveArm(arm: Arm, torso: CFrame, dt: number)
	local gripCf, size = arm.grip()
	if not gripCf or not size then
		arm.weight = 0
		return
	end
	-- 1. posa dell'animazione
	local tS, tE = transformOf(arm.shoulder), transformOf(arm.elbow)
	local upper = child(arm.shoulder, torso, tS)
	local lower = child(arm.elbow, upper, tE)
	local hand = child(arm.wrist, lower, transformOf(arm.wrist))
	local handle = hand * gripCf
	-- le due estremita' della testa della piccozza: conta quella piu' vicina alla roccia
	local n = wallNormal
	local gap = math.huge
	for _, local_ in { Vector3.new(size.X * 0.36, size.Y * 0.4, 0), Vector3.new(-size.X * 0.26, size.Y * 0.34, 0) } do
		local tip = handle * local_
		local hit = workspace:Raycast(tip + n * 3, -n * 8, params)
		if hit then
			gap = math.min(gap, (tip - hit.Position):Dot(n))
		end
	end
	-- 2. piantata o libera? (morbido, per non scattare)
	local want = if gap == math.huge then 0 else 1 - math.clamp((gap - ENGAGE) / (RELEASE - ENGAGE), 0, 1)
	arm.weight += (want - arm.weight) * math.min(1, dt * 12)
	if arm.weight < 0.01 or gap == math.huge then
		return
	end
	local shift = math.clamp(-BITE - gap, -MAX_SHIFT, MAX_SHIFT) * arm.weight
	if math.abs(shift) < 0.02 then
		return
	end
	-- 3. IK a due ossa: spalla S, gomito E, polso W -> polso W' spostato lungo la normale
	local S = (torso * arm.shoulder.c0).Position
	local E = (upper * arm.elbow.c0).Position
	local W = (lower * arm.wrist.c0).Position
	local l1, l2 = (E - S).Magnitude, (W - E).Magnitude
	local target = W + n * shift
	local toT = target - S
	local reach = math.clamp(toT.Magnitude, math.abs(l1 - l2) + 0.01, l1 + l2 - 0.01)
	local dir = toT.Unit
	-- il gomito resta dalla parte in cui lo mette l'animazione
	local pole = (E - S) - dir * (E - S):Dot(dir)
	if pole.Magnitude < 1e-3 then
		pole = -n
	end
	pole = pole.Unit
	local along = (l1 * l1 - l2 * l2 + reach * reach) / (2 * reach)
	local height = math.sqrt(math.max(0, l1 * l1 - along * along))
	local E2 = S + dir * along + pole * height
	local W2 = S + dir * reach
	-- rotazioni nel mondo: braccio, poi avambraccio
	local r1 = rotationBetween(E - S, E2 - S)
	local upper2 = rotateAbout(upper, S, r1)
	local lower1 = rotateAbout(lower, S, r1)
	local W1 = (lower1 * arm.wrist.c0).Position
	local r2 = rotationBetween(W1 - E2, W2 - E2)
	local lower2 = rotateAbout(lower1, E2, r2)
	-- di nuovo nei Transform delle giunture (la mano segue l'avambraccio)
	setTransform(arm.shoulder, (torso * arm.shoulder.c0):Inverse() * upper2 * arm.shoulder.c1)
	setTransform(arm.elbow, (upper2 * arm.elbow.c0):Inverse() * lower2 * arm.elbow.c1)
	if RunService:IsStudio() then
		local hand2 = child(arm.wrist, lower2, transformOf(arm.wrist))
		local moved = (hand2.Position - hand.Position):Dot(n)
		table.insert(debugInfo, string.format("%.2f->%.2f w%.1f", gap, gap + moved, arm.weight))
	end
end

local function step(dt: number)
	if not active or not rootPart or #arms == 0 then
		return
	end
	local cf = (rootPart :: BasePart).CFrame
	for _, j in chainToTorso do
		cf = child(j, cf, transformOf(j))
	end
	table.clear(debugInfo)
	for _, arm in arms do
		solveArm(arm, cf, dt)
	end
	if RunService:IsStudio() and os.clock() - lastDebug > 0.2 then
		lastDebug = os.clock()
		local player = game:GetService("Players").LocalPlayer
		player:SetAttribute("ClimbIK", table.concat(debugInfo, " | "))
	end
end

-- chiamato ogni frame dall'arrampicata con la normale della parete
function ClimbIK.setWall(normal: Vector3)
	wallNormal = normal
end

function ClimbIK.start()
	active = true
	for _, arm in arms do
		arm.weight = 0
	end
	if not connection then
		-- PreSimulation: l'animazione ha appena scritto i Transform, la fisica non e' ancora partita
		connection = RunService.PreSimulation:Connect(step)
	end
end

function ClimbIK.stop()
	active = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return ClimbIK
