--!strict
-- Arrampicata con le Piccozze: il corpo e' guidato da LinearVelocity + AlignOrientation (al
-- posto della fisica normale dell'Humanoid), con le animazioni Climb_Idle / Climb_Up (vedi
-- shared/ClimbPoses) che si alternano con una dissolvenza; si scivola se si resta fermi troppo
-- a lungo con poca stamina.
--   Click o E vicino a una parete -> ti aggrappi (di nuovo: ti lasci andare)
--   W/S (o avanti/indietro)     -> sali / scendi       A/D -> di lato
--   Spazio sulla parete         -> ti dai la spinta e salti via
--   in cima alla parete         -> ti issi sopra da solo
--   strapiombi e tetti          -> ci si resta attaccati: il corpo ruota con la roccia, ma
--                                  serve la Piccozza e la stamina cala in fretta
--   F (o X sul gamepad)         -> tocco: chiodo subito; tenuto premuto: miri col cerchio
--   R (o Y)                     -> sganci la corda
-- Regole della montagna: le pareti di ghiaccio vogliono i Ramponi, le pareti lisce (tag
-- "NoClimb") si superano solo col Rampino. La stamina cala sulla parete (di piu' su ghiaccio
-- e col vento); quando e' quasi finita scivoli giu', a zero cadi.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClimbConfig = require(Shared:WaitForChild("ClimbConfig"))
local Gear = require(Shared:WaitForChild("Gear"))
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local ClimbPoses = require(Shared:WaitForChild("ClimbPoses"))
local ClimbAnimator = require(script.Parent.ClimbAnimator)
local ClimbIK = require(script.Parent.ClimbIK)
local ClimbFeel = require(script.Parent.ClimbFeel)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Climbing = {}
local placePitonAction: () -> () = function() end

local ICY = { [Enum.Material.Ice] = true, [Enum.Material.Glacier] = true }
local R15_CLIMB = "rbxassetid://507765644" -- animazioni di arrampicata standard di Roblox
local R6_CLIMB = "rbxassetid://180436334"

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local controls: any = nil

local attached = false
local wallNormal = Vector3.zAxis
local mover: LinearVelocity? = nil
local aligner: AlignOrientation? = nil
local moverAttachment: Attachment? = nil
local track: AnimationTrack? = nil -- Climb_Up (o l'animazione standard di Roblox come riserva)
local idleTrack: AnimationTrack? = nil -- Climb_Idle
local roofTrack: AnimationTrack? = nil -- Climb_Roof (sotto tetti e strapiombi)
local sideRTrack: AnimationTrack? = nil -- Climb_SideR / Climb_SideL: traverso con A e D
local sideLTrack: AnimationTrack? = nil
local jumpTrack: AnimationTrack? = nil -- Climb_Jump: lancio a due piccozze
local sideBlend = 0 -- 0 = salita, 1 = traverso
local lastInputZ = 0 -- W tenuto? (lo legge il salto)
local lastRoofness = 0
local dynoUntil = 0 -- fine della spinta del lancio
local holdTrack: AnimationTrack? = nil -- Axe_Hold: le due piccozze in mano camminando
local poseBlend = 0 -- 0 = Climb_Idle, 1 = Climb_Up
local animCycle = 2 * math.pi -- quanta fase di trazione copre un giro dell'animazione
local animIds: { [string]: string } = {}
local promptsShown = 0
local noWallTime = 0
local stuckTime = 0
local headMissTime = 0 -- da quanto la parete all'altezza della testa non c'e' piu'
local climbPhase = 0 -- avanza a ogni trazione; muove anche l'animazione
-- quanto si vede Climb_Up (0..1): anche la spinta cresce con lei, cosi' premendo W a colpetti
-- non si sale mai in posa idle
local upBlend = 0
local lastEffortTime = -math.huge
local lastPull = -1
local mantling = false
local mantleTo: (CFrame) -> ()
local lastToggle = 0
local lastRopeSync = 0
local reportedRocks: { [Instance]: boolean } = {}
-- "Su" lungo la roccia. Su una parete verticale e' la verticale del mondo; su uno strapiombo si
-- inclina, e sotto un tetto diventa orizzontale (la direzione in cui si sta avanzando).
local climbUp = Vector3.yAxis
local aiming = false
local aimDown = 0
local aimMarker: Part? = nil
local aimDot: Part? = nil
local aimPos: Vector3? = nil
local aimNormal: Vector3? = nil

local function rayParams(): RaycastParams
	local ignore = {}
	for _, inst in { character, workspace:FindFirstChild("Pitons"), workspace:FindFirstChild("Forest"), workspace.CurrentCamera } do
		if inst then
			table.insert(ignore, inst)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function isWall(result: RaycastResult?): boolean
	return result ~= nil and result.Normal.Y < ClimbConfig.WALL_MAX_NORMAL_Y
end

-- Quanto la roccia sporge sopra di te: 0 su una parete verticale, 1 sotto un tetto piatto.
local function roofnessOf(n: Vector3): number
	return math.clamp(-n.Y, 0, 1)
end

-- Direzione "su" lungo la superficie: la verticale del mondo appiattita sulla roccia. Sotto un
-- tetto la verticale sparisce (e' perpendicolare alla roccia), quindi si tiene la direzione di
-- prima: si continua nel verso in cui si stava salendo invece di impuntarsi.
local function surfaceUp(n: Vector3, prev: Vector3): Vector3
	local up = prev - n * prev:Dot(n)
	if up.Magnitude < 0.25 then
		up = Vector3.yAxis - n * n.Y
	end
	if up.Magnitude < 0.25 then
		up = Vector3.zAxis - n * n.Z
	end
	return up.Unit
end

-- Come sta il corpo sulla roccia: guarda dentro la parete, testa verso `up`. Su una parete
-- verticale viene esattamente in piedi come prima; sotto un tetto si corica sotto la roccia.
local function bodyCFrame(pos: Vector3, n: Vector3, up: Vector3): CFrame
	return CFrame.fromMatrix(pos, up:Cross(n).Unit, up, n)
end

-- Parete davanti: ventaglio di raggi come nel kit, a due altezze
local function findWallAround(): RaycastResult?
	local r = root :: BasePart
	local params = rayParams()
	local best: RaycastResult? = nil
	local bestDist = math.huge
	local function try(origin: Vector3, dir: Vector3)
		local result = workspace:Raycast(origin, dir, params)
		if isWall(result) then
			local dist = ((result :: RaycastResult).Position - origin).Magnitude
			if dist < bestDist then
				best, bestDist = result, dist
			end
		end
	end
	for _, height in { 1, -0.5 } do
		local origin = r.Position + Vector3.new(0, height, 0)
		for angle = -75, 75, 15 do
			try(origin, (r.CFrame * CFrame.Angles(0, math.rad(angle), 0)).LookVector * ClimbConfig.REACH)
		end
	end
	-- Anche sopra la testa: sotto uno strapiombo la roccia e' li' e ci si deve poter appendere.
	local head = r.Position + Vector3.new(0, 2.2, 0)
	for _, pitch in { 35, 60, 85 } do
		for _, yaw in { 0, -35, 35 } do
			local dir = (r.CFrame * CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)).LookVector
			try(head, dir * (ClimbConfig.REACH + 1.5))
		end
	end
	return best
end

local function hasTool(name: string): boolean
	return character ~= nil and (character :: Model):FindFirstChild(name) ~= nil
end

-- Puo' aggrapparsi a questa superficie? Se no, spiega perche'
local function canGrab(result: RaycastResult): (boolean, string?)
	if result.Instance and CollectionService:HasTag(result.Instance, "NoClimb") then
		return false, "Parete liscia: qui serve il Rampino"
	end
	if ICY[result.Material] and not Gear.has(player, "Ramponi") and not DragonConfig.hasAbility(player, "Gelo") then
		return false, "Parete di ghiaccio: servono i Ramponi (Banco da lavoro)"
	end
	if ClientState.stamina < ClimbConfig.MIN_STAMINA_TO_GRAB then
		return false, "Troppo stanco per aggrapparti"
	end
	return true, nil
end

-- Id dell'animazione: quello pubblicato (ClimbConfig) oppure, in Studio, quello temporaneo che
-- si ottiene registrando al volo la KeyframeSequence costruita dalle pose
local function climbAnimId(name: string, configured: string): string?
	if configured ~= "" then
		return configured
	end
	if animIds[name] then
		return animIds[name]
	end
	if RunService:IsStudio() then
		-- prima quella che hai modificato nell'Animation Editor, se c'e'
		local edited = ReplicatedStorage:FindFirstChild("ClimbAnimSaves")
		local kfs = edited and edited:FindFirstChild(name)
		local ok, id = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(if kfs then kfs :: KeyframeSequence else ClimbPoses.build(name))
		end)
		if ok and id then
			animIds[name] = id
			return id
		end
	end
	return nil
end

local function loadTrack(animator: Animator, id: string): AnimationTrack?
	local a = Instance.new("Animation")
	a.AnimationId = id
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(a)
	end)
	return if ok then loaded else nil
end

local function playClimbAnimation(h: Humanoid)
	local animator = h:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	-- R15: le nostre animazioni con le due piccozze. Climb_Up gira a velocita' zero e la sua
	-- posizione segue il ritmo delle trazioni; Climb_Idle respira da sola. Si passa dall'una
	-- all'altra cambiando il peso, con ANIM_FADE secondi di dissolvenza.
	if h.RigType == Enum.HumanoidRigType.R15 then
		local idleId = climbAnimId("Climb_Idle", ClimbConfig.CLIMB_IDLE_ANIM)
		local upId = climbAnimId("Climb_Up", ClimbConfig.CLIMB_UP_ANIM)
		local idle = idleId and loadTrack(animator, idleId)
		local up = upId and loadTrack(animator, upId)
		if idle and up then
			idle.Looped, up.Looped = true, true
			idle.Priority, up.Priority = Enum.AnimationPriority.Action, Enum.AnimationPriority.Action
			idle:Play(ClimbConfig.ANIM_FADE, 1)
			up:Play(ClimbConfig.ANIM_FADE, 0.001)
			up:AdjustSpeed(0)
			idleTrack, track = idle, up
			poseBlend = 0
			-- sotto i tetti: Climb_Roof, se c'e' (segue lo stesso ritmo di Climb_Up)
			local roofId = climbAnimId("Climb_Roof", ClimbConfig.CLIMB_ROOF_ANIM)
			local roof = roofId and loadTrack(animator, roofId)
			if roof then
				roof.Looped = true
				roof.Priority = Enum.AnimationPriority.Action
				roof:Play(ClimbConfig.ANIM_FADE, 0.001)
				roof:AdjustSpeed(0)
				roofTrack = roof
			end
			-- traverso e lancio, se ci sono
			local function looped(name: string, configured: string): AnimationTrack?
				local id = climbAnimId(name, configured)
				local t = id and loadTrack(animator, id)
				if t then
					t.Looped = true
					t.Priority = Enum.AnimationPriority.Action
					t:Play(ClimbConfig.ANIM_FADE, 0.001)
					t:AdjustSpeed(0)
				end
				return t
			end
			sideRTrack = looped("Climb_SideR", ClimbConfig.CLIMB_SIDE_R_ANIM)
			sideLTrack = looped("Climb_SideL", ClimbConfig.CLIMB_SIDE_L_ANIM)
			sideBlend = 0
			local jumpId = climbAnimId("Climb_Jump", ClimbConfig.CLIMB_JUMP_ANIM)
			jumpTrack = jumpId and loadTrack(animator, jumpId)
			if jumpTrack then
				jumpTrack.Looped = false
				jumpTrack.Priority = Enum.AnimationPriority.Action2 -- sopra tutte le altre
			end
			animCycle = 4 * math.pi -- un giro di Climb_Up = due trazioni (sinistra e destra)
			return
		end
	end
	animCycle = 2 * math.pi
	-- l'animazione "climb" dello script Animate del personaggio (giusta per R6 o R15)
	local animate = character and (character :: Model):FindFirstChild("Animate")
	local climbFolder = animate and animate:FindFirstChild("climb")
	local anim = climbFolder and climbFolder:FindFirstChildOfClass("Animation")
	if not anim then
		local a = Instance.new("Animation")
		a.AnimationId = if h.RigType == Enum.HumanoidRigType.R15 then R15_CLIMB else R6_CLIMB
		anim = a
	end
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(anim :: Animation)
	end)
	if ok and loaded then
		loaded.Looped = true
		loaded.Priority = Enum.AnimationPriority.Action2
		loaded:Play(0.15)
		loaded:AdjustSpeed(0)
		track = loaded
	end
end

-- Camminando con le piccozze: Axe_Hold muove solo gomiti e mani (piccozze impugnate, inclinate in
-- avanti); spalle e braccia oscillano con la camminata e la corsa di Roblox. La posa "toolnone"
-- di Roblox (braccio destro teso in avanti col Tool) viene fermata finche' tieni le piccozze.
local function isToolNone(t: AnimationTrack): boolean
	local a = t.Animation
	return a ~= nil and (a.Name == "ToolNoneAnim" or t.Name == "ToolNoneAnim")
end

local function playHold()
	local h = humanoid
	local animator = h and h:FindFirstChildOfClass("Animator")
	if not animator or attached then
		return
	end
	for _, t in animator:GetPlayingAnimationTracks() do
		if isToolNone(t) then
			t:Stop(0.1)
		end
	end
	if not animator:GetAttribute("FermaToolNone") then
		animator:SetAttribute("FermaToolNone", true)
		animator.AnimationPlayed:Connect(function(t)
			if isToolNone(t) and hasTool(ClimbConfig.TOOL_NAME) then
				t:Stop(0)
			end
		end)
	end
	if not holdTrack then
		local id = climbAnimId("Axe_Hold", ClimbConfig.AXE_HOLD_ANIM)
		holdTrack = id and loadTrack(animator, id)
		if holdTrack then
			holdTrack.Looped = true
			holdTrack.Priority = Enum.AnimationPriority.Action
		end
	end
	if holdTrack and not holdTrack.IsPlaying then
		holdTrack:Play(0.2)
	end
end

local function attachTo(result: RaycastResult)
	local r, h = root :: BasePart, humanoid :: Humanoid
	attached = true
	noWallTime = 0
	if holdTrack then
		(holdTrack :: AnimationTrack):Stop(0.15)
	end
	wallNormal = result.Normal
	climbUp = surfaceUp(wallNormal, Vector3.yAxis)
	h.AutoRotate = false
	local face = bodyCFrame(r.Position, wallNormal, climbUp)
	r.CFrame = face

	-- fisica dell'arrampicata: velocita' imposta e orientamento allineato alla roccia (la
	-- gravita' e gli stati normali dell'Humanoid non contano finche' si e' attaccati)
	local att = Instance.new("Attachment")
	att.Name = "ClimbAttachment"
	att.Parent = r
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ClimbVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 1e6
	lv.VectorVelocity = Vector3.zero
	lv.Parent = r
	local ao = Instance.new("AlignOrientation")
	ao.Name = "ClimbOrientation"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e6
	ao.Responsiveness = 40
	ao.CFrame = face
	ao.Parent = r
	moverAttachment, mover, aligner = att, lv, ao
	remotes.ClimbState:FireServer(true)

	playClimbAnimation(h)
	ClimbIK.setWall(wallNormal)
	ClimbIK.start() -- le piccozze entrano sempre della stessa misura nella roccia
	climbPhase = 0
	upBlend = 0
	lastEffortTime = -math.huge
	lastPull = -1
	ClimbFeel.kick(0.9, Vector3.new(0, -1, -0.5))
	ClimbFeel.impact(result.Position, result.Normal, nil, 10)
	ClientState.climbing = true
	ClientState.hint = ""
end

local function detach(jump: boolean, why: string?)
	if not attached then
		return
	end
	-- perche' ci si e' staccati: si legge in Studio (attributo del giocatore) quando qualcosa non va
	player:SetAttribute("UltimoDistacco", why or "?")
	attached = false
	ClimbIK.stop()
	for _, inst in { mover, aligner, moverAttachment } :: { Instance? } do
		if inst then
			inst:Destroy()
		end
	end
	mover, aligner, moverAttachment = nil, nil, nil
	for _, t in { track, idleTrack, roofTrack, sideRTrack, sideLTrack, jumpTrack } :: { AnimationTrack? } do
		if t then
			t:Stop(0.2)
		end
	end
	track, idleTrack, roofTrack = nil, nil, nil
	sideRTrack, sideLTrack, jumpTrack = nil, nil, nil
	dynoUntil = 0
	remotes.ClimbState:FireServer(false)
	ClientState.climbing = false
	if hasTool(ClimbConfig.TOOL_NAME) then
		playHold()
	end
	local h, r = humanoid, root
	if h and r then
		h.AutoRotate = true
		h.PlatformStand = false
		if jump then
			h:ChangeState(Enum.HumanoidStateType.Freefall)
			r.AssemblyLinearVelocity = wallNormal * ClimbConfig.JUMP_OFF_PUSH + ClimbConfig.JUMP_OFF_SPEED
			ClimbFeel.kick(1.1, Vector3.new(0, 1, 1))
		end
	end
	lastToggle = os.clock()
end

-- Aggrappati alla parete piu' vicina (usato anche dal Rampino a fine corsa)
function Climbing.grabNearest(): boolean
	if attached or not root then
		return attached
	end
	local result = findWallAround()
	if result then
		local ok, why = canGrab(result)
		if ok then
			attachTo(result)
			return true
		end
		ClientState.hint = why or ""
	end
	return false
end

function Climbing.isClimbing(): boolean
	return attached
end

function Climbing.release()
	detach(false, "release")
end

-- Per i pulsanti del telefono (MobileControls)
function Climbing.piton()
	placePitonAction()
end

function Climbing.releaseRope()
	remotes.ReleaseRope:FireServer()
end

function Climbing.jumpOff()
	if attached then
		detach(true, "jumpOff")
	end
end

-- Salita sul bordo: invece di teletrasportare, il corpo sale in un arco in MANTLE_TIME
-- secondi. Cosi' si vede il movimento e non si rischia di ricadere.
mantleTo = function(target: CFrame)
	local r, h = root :: BasePart, humanoid :: Humanoid
	detach(false, "mantle")
	mantling = true
	ClientState.hint = ""
	h.PlatformStand = true
	ClimbFeel.kick(0.7, Vector3.new(0, -1, 0))
	local start = r.CFrame
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not r.Parent or h.Health <= 0 then
			conn:Disconnect()
			mantling = false
			return
		end
		local a = math.min(1, (os.clock() - t0) / ClimbConfig.MANTLE_TIME)
		local eased = a * a * (3 - 2 * a)
		-- arco: prima si tira su, poi si sposta in avanti sul bordo
		local pos = start.Position:Lerp(target.Position, eased) + Vector3.new(0, math.sin(a * math.pi) * 1.6, 0)
		r.CFrame = CFrame.new(pos) * start.Rotation:Lerp(target.Rotation, eased)
		r.AssemblyLinearVelocity = Vector3.zero
		if a >= 1 then
			conn:Disconnect()
			mantling = false
			h.PlatformStand = false
			h:ChangeState(Enum.HumanoidStateType.Landed)
			ClimbFeel.kick(0.5, Vector3.new(0, -1, 0))
		end
	end)
end

-- In cima alla parete: cerca un bordo piano sopra (a varie distanze dentro la parete e a
-- varie altezze) e ci sale sopra, un po' dentro, cosi' non si ricade giu'
local function tryMantle(): boolean
	local r = root :: BasePart
	-- sotto un tetto non c'e' nessun bordo su cui issarsi: si continua ad avanzare
	if climbUp.Y < 0.35 then
		return false
	end
	local params = rayParams()
	local flat = Vector3.new(wallNormal.X, 0, wallNormal.Z)
	local inward = if flat.Magnitude > 0.1 then -flat.Unit else -Vector3.new(climbUp.X, 0, climbUp.Z).Unit
	for _, depth in { 2.5, 3.5, 5 } do
		for _, height in { 4.5, 6.5, 8.5 } do
			local origin = r.Position + Vector3.new(0, height, 0) + inward * depth
			-- lo spazio sopra il bordo deve essere libero
			-- Tutto il percorso dev'essere libero: prima su dritto, poi dentro sopra il bordo.
			-- Un raggio che parte dentro la roccia non la vede, quindi senza il controllo in
			-- verticale sotto una pancia di roccia si finiva "issati" dentro la montagna.
			local rising = workspace:Raycast(r.Position, Vector3.new(0, height, 0), params)
			local blocked = rising or workspace:Raycast(r.Position + Vector3.new(0, height, 0), inward * depth, params)
			if not blocked then
				local down = workspace:Raycast(origin, Vector3.new(0, -height - 3, 0), params)
				-- il ripiano deve continuare verso l'interno: e' una cengia o la cima, non un gradino
				local further = down and workspace:Raycast(origin + inward * 2.5, Vector3.new(0, -height - 3, 0), params)
				local deep = further ~= nil and math.abs((further :: RaycastResult).Position.Y - (down :: RaycastResult).Position.Y) < 1.6
				if down and deep and down.Normal.Y > 0.6 and down.Position.Y > r.Position.Y - 1 then
					local top = down.Position + Vector3.new(0, 3.2, 0) + inward * 1.5
					-- e dove si arriva ci dev'essere spazio per stare in piedi
					local headroom = workspace:Raycast(down.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 6, 0), params)
					local toTop = workspace:Raycast(origin, top - origin, params)
					if not headroom and not toTop then
						mantleTo(CFrame.lookAt(top, top + inward))
						return true
					end
				end
			end
		end
	end
	return false
end

-- Cerca la parete con piu' raggi (petto, testa, ginocchia, ai lati): un sasso sporgente o
-- una cengia piccola non fanno piu' staccare. Restituisce il colpo piu' "parete".
local function wallContact(params: RaycastParams): RaycastResult?
	local r = root :: BasePart
	-- gli scostamenti seguono la roccia (testa, piedi, fianchi), non le direzioni del mondo:
	-- sotto un tetto "sopra la testa" non e' piu' verso l'alto
	local right = climbUp:Cross(wallNormal)
	right = if right.Magnitude > 0.1 then right.Unit else r.CFrame.RightVector
	local best: RaycastResult? = nil
	for _, o in { climbUp, climbUp * 2.5, climbUp * -1.5, right * 1.2, -right * 1.2 } do
		for _, dir in { -wallNormal, r.CFrame.LookVector } do
			local hit = workspace:Raycast(r.Position + o, dir * 4.5, params)
			if hit and (not best or hit.Normal.Y < (best :: RaycastResult).Normal.Y) then
				best = hit
			end
		end
	end
	return best
end

local function climbStep(dt: number)
	local r = root :: BasePart
	local params = rayParams()

	-- La parete e' ancora li'? Anche una sporgenza (colpo non verticale) tiene la presa:
	-- si tiene la normale di prima finche' c'e' roccia davanti
	local hit = wallContact(params)
	if isWall(hit) then
		noWallTime = 0
		-- la normale cambia piano: i sassi non fanno girare di scatto il personaggio
		local n = (hit :: RaycastResult).Normal
		wallNormal = (wallNormal:Lerp(n, math.min(1, dt * 8))).Unit
		ClimbIK.setWall(wallNormal)
	elseif hit then
		noWallTime = 0
	else
		noWallTime += dt
		if noWallTime > 0.5 then
			if not tryMantle() then
				detach(false, "noWall")
			end
			return
		end
	end

	local input = if controls then controls:GetMoveVector() else Vector3.zero
	-- Gli assi seguono la roccia: su una parete verticale "su" e' la verticale del mondo, su uno
	-- strapiombo si inclina, sotto un tetto diventa il verso in cui stai avanzando. Cosi' W
	-- continua a voler dire "avanti sulla via" anche quando la roccia ti passa sopra la testa.
	climbUp = surfaceUp(wallNormal, climbUp)
	local roofness = roofnessOf(wallNormal)
	local up = climbUp
	-- destra di chi guarda la parete (guarda verso -normale): A a sinistra, D a destra
	local right = up:Cross(wallNormal)
	if right.Magnitude < 0.1 then
		right = r.CFrame.RightVector
	end
	right = right.Unit

	-- Salendo: se davanti la parete finisce, ci si issa sul bordo. Deve mancare per un attimo
	-- di fila (0.15 s): sulle pareti di voxel un solo raggio a vuoto capita su ogni gradino, e il
	-- personaggio provava a "issarsi" su sporgenze di pochi studs staccandosi dalla parete.
	if input.Z < -0.3 then
		local head = workspace:Raycast(r.Position + up * 3, -wallNormal * 4, params)
		headMissTime = if isWall(head) then 0 else headMissTime + dt
		if headMissTime > 0.15 and tryMantle() then
			headMissTime = 0
			return
		end
	else
		headMissTime = 0
	end

	local material = if hit then (hit :: RaycastResult).Material else Enum.Material.Rock
	local icy = ICY[material] == true
	if icy and not Gear.has(player, "Ramponi") and not DragonConfig.hasAbility(player, "Gelo") then
		ClientState.hint = "Ghiaccio! Senza Ramponi non tieni la presa"
		detach(false, "ice")
		return
	end
	if hit and (hit :: RaycastResult).Instance and CollectionService:HasTag((hit :: RaycastResult).Instance, "NoClimb") then
		ClientState.hint = "Parete liscia: qui serve il Rampino"
		detach(false, "noClimb")
		return
	end

	local axe = hasTool(ClimbConfig.TOOL_NAME)
	-- Sotto un tetto ci si tiene solo con le piccozze piantate nella roccia: a mani nude no.
	if roofness > 0.3 and not axe then
		ClientState.hint = "Sotto un tetto serve la Piccozza per restare attaccato"
		detach(false, "roofNoAxe")
		return
	end
	-- il corpo si corica sotto la roccia: l'Humanoid non deve provare a rimettersi in piedi
	;(humanoid :: Humanoid).PlatformStand = roofness > 0.25
	local speed = ClimbConfig.CLIMB_SPEED * (if icy then 0.75 else 1) * (if axe then 1 else 0.7)
		* (1 - 0.3 * roofness)
		* (if player:GetAttribute("CarryingEgg") then DragonConfig.CARRY_CLIMB_FACTOR else 1)
		* (if DragonConfig.hasAbility(player, "Sole") then 1.2 else 1)
	-- Ritmo: ogni trazione e' una spinta seguita da un assestamento. E' questo che fa sentire
	-- il peso del corpo; a velocita' costante sembrava un ascensore.
	local effort = math.min(1, math.abs(input.Z) + math.abs(input.X))
	climbPhase += dt * ClimbConfig.PULL_RATE * (0.3 + 0.7 * effort)
	local surge = 1 + ClimbConfig.PULL_SURGE * math.sin(climbPhase)
	if effort > 0.15 then
		lastEffortTime = os.clock()
	end
	-- la posa di salita resta un attimo dopo che lasci il tasto (colpetti di W = salita continua)
	local climbingPose = os.clock() - lastEffortTime < 0.35
	upBlend = math.clamp(upBlend + (if climbingPose then dt else -dt) / ClimbConfig.ANIM_FADE, 0, 1)
	local move = (up * (-input.Z * speed) + right * (input.X * speed * 0.85)) * surge * (if idleTrack then upBlend else 1)
	lastInputZ, lastRoofness = input.Z, roofness
	-- lancio: una spinta a campana lungo la via (forte a meta', zero all'inizio e alla fine)
	local now = os.clock()
	if now < dynoUntil then
		local a = 1 - (dynoUntil - now) / ClimbConfig.DYNO_TIME
		move += up * (ClimbConfig.DYNO_HEIGHT / ClimbConfig.DYNO_TIME) * 2 * math.sin(a * math.pi) ^ 2
	end
	local tired = ClientState.stamina < 12
	local sliding = false
	if tired and input.Z >= -0.3 then
		move -= up * 4 -- senza forze si scivola indietro lungo la via
		sliding = true
	end

	-- A ogni trazione: scossa della camera e scintille dove morde la piccozza
	local pull = math.floor((climbPhase - math.pi / 2) / (2 * math.pi))
	if effort > 0.15 and pull ~= lastPull then
		lastPull = pull
		ClimbFeel.kick(0.35 + 0.3 * effort, Vector3.new(0, -1, 0.3))
		if hit then
			local hr = hit :: RaycastResult
			ClimbFeel.impact(hr.Position, hr.Normal, if icy then Color3.fromRGB(205, 238, 252) else nil, if icy then 8 else 5)
		end
	end
	if sliding then
		ClimbFeel.kick(0.2, Vector3.new(0, 1, 0))
	end
	-- sasso sporgente sopra: se sali ma non ti muovi, ti sposti un attimo in fuori e lo scavalchi
	if input.Z < -0.3 and r.AssemblyLinearVelocity:Dot(up) < 1 then
		stuckTime += dt
	else
		stuckTime = 0
	end
	local steppingOut = stuckTime > 0.3
	if steppingOut then
		move += wallNormal * 7 + up * 3 -- ci si sporge in fuori e si scavalca il sasso
		if stuckTime > 0.9 then
			stuckTime = 0
		end
	end
	if roofness > 0.5 then
		ClientState.hint = "Tetto: sei appeso, le braccia non reggono a lungo"
	elseif roofness > 0.15 then
		ClientState.hint = "Strapiombo: la roccia spancia, stanca il doppio"
	end
	-- staccati dalla roccia? spingi verso la parete. Sotto un tetto tira con piu' forza,
	-- altrimenti il peso del corpo stacca le piccozze.
	local contact = workspace:Raycast(r.Position, -wallNormal * 2.2, params)
	if not contact and not steppingOut then
		move += -wallNormal * (5 + 9 * roofness)
	end
	;(mover :: LinearVelocity).VectorVelocity = move
	;(aligner :: AlignOrientation).CFrame = bodyCFrame(r.Position, wallNormal, up)

	-- L'animazione segue lo stesso ritmo delle trazioni, cosi' le braccia sono in sincrono
	if track then
		local len = track.Length
		if len > 0 then
			track.TimePosition = (climbPhase / animCycle) % 1 * len
		end
		if idleTrack then
			-- fermo (o scivolando): Climb_Idle; in movimento: Climb_Up. Sotto un tetto prende il
			-- posto di entrambe Climb_Roof, man mano che la roccia si corica sopra la testa.
			local wantUp = climbingPose and not sliding
			poseBlend = math.clamp(poseBlend + (if wantUp then dt else -dt) / ClimbConfig.ANIM_FADE, 0, 1)
			local roofW = 0
			if roofTrack then
				local x = math.clamp((roofness - 0.25) / 0.3, 0, 1)
				roofW = x * x * (3 - 2 * x)
				if len > 0 and roofTrack.Length > 0 then
					roofTrack.TimePosition = (climbPhase / animCycle) % 1 * roofTrack.Length
				end
				roofTrack:AdjustWeight(math.max(0.001, roofW), 0.05)
			end
			-- traverso: quando ci si muove soprattutto di lato (A/D) invece che su o giu'
			local wantSide = math.clamp((math.abs(input.X) - math.abs(input.Z)) * 2, 0, 1)
			sideBlend += (wantSide - sideBlend) * math.min(1, dt / ClimbConfig.ANIM_FADE)
			local sideW = if sideRTrack and sideLTrack then sideBlend else 0
			local goingRight = input.X > 0
			for _, st in { sideRTrack, sideLTrack } :: { AnimationTrack? } do
				if st then
					if st.Length > 0 then
						st.TimePosition = (climbPhase / animCycle) % 1 * st.Length
					end
					local mine = (st == sideRTrack) == goingRight
					st:AdjustWeight(math.max(0.001, if mine then poseBlend * (1 - roofW) * sideW else 0), 0.05)
				end
			end
			track:AdjustWeight(math.max(0.001, poseBlend * (1 - roofW) * (1 - sideW)), 0.05)
			idleTrack:AdjustWeight(math.max(0.001, (1 - poseBlend) * (1 - roofW)), 0.05)
		elseif sliding then
			track:AdjustSpeed(-0.4)
		else
			track:AdjustSpeed(0)
		end
	end

	local moving = math.abs(input.Z) + math.abs(input.X) > 0.1
	local drain = if moving then ClimbConfig.DRAIN_MOVING else ClimbConfig.DRAIN_HANGING
	drain *= (if icy then ClimbConfig.ICE_MULTIPLIER else 1) * (if axe then 1 else ClimbConfig.NO_AXE_MULTIPLIER) * ClientState.windFactor
	-- piu' la roccia sporge, piu' peso sta sulle braccia: verticale 1x, tetto 3.4x
	drain *= 1 + 2.4 * roofness
	ClientState.stamina = math.max(0, ClientState.stamina - drain * dt)
	if ClientState.stamina <= 0 then
		ClientState.hint = "Sei esausto! Riposa a terra o appeso alla corda."
		detach(false, "exhausted")
		return
	elseif sliding then
		ClientState.hint = "Scivoli! Stamina quasi finita"
	end

	-- Appiglio friabile: avvisa il server, che lo fara' crollare
	local hitInst = hit and (hit :: RaycastResult).Instance
	if hitInst and not reportedRocks[hitInst] and CollectionService:HasTag(hitInst, "CrumblingRock") then
		reportedRocks[hitInst] = true
		ClientState.hint = "La roccia si sgretola!"
		remotes.GrabRock:FireServer(hitInst)
	end
end

-- Corda: si "fila" mentre sali o cammini; se cadi resta tesa e ti ferma
local function ropeStep(dt: number)
	local r, h = root :: BasePart, humanoid :: Humanoid
	local grounded = h.FloorMaterial ~= Enum.Material.Air
	local rope = r:FindFirstChild("BelayRope") :: RopeConstraint?
	local hanging = false
	if rope and rope.Attachment0 then
		local dist = (rope.Attachment0.WorldPosition - r.Position).Magnitude
		if (attached or grounded) and dist > rope.Length - 1 and rope.Length < ClimbConfig.ROPE_MAX then
			rope.Length = math.min(dist + 1.5, ClimbConfig.ROPE_MAX)
			if os.clock() - lastRopeSync > 0.25 then
				lastRopeSync = os.clock()
				remotes.UpdateRope:FireServer(rope.Length)
			end
		end
		hanging = not attached and not grounded and dist >= rope.Length - 0.6
		if rope.Length >= ClimbConfig.ROPE_MAX and dist >= ClimbConfig.ROPE_MAX - 1 then
			ClientState.hint = "Corda finita: pianta un nuovo chiodo (F)"
		end
	end
	if not attached then
		local regen = if ClientState.sprinting then 0
			elseif grounded then ClimbConfig.REGEN_GROUND
			elseif hanging then ClimbConfig.REGEN_ROPE
			else 0
		ClientState.stamina = math.min(ClimbConfig.STAMINA_MAX, ClientState.stamina + regen * ClientState.regenBoost * dt)
	end
end

local function drivePiton(position: Vector3, normal: Vector3)
	if (player:GetAttribute("Pitons") or 0) <= 0 then
		ClientState.hint = "Chiodi finiti: riforniscili in un campo base o all'emporio"
		return
	end
	ClimbAnimator.hammer()
	remotes.PlacePiton:FireServer(position, normal)
end

-- Chiodo veloce: nel punto piu' comodo davanti a te, senza mirare
local function placePiton()
	if not root then
		return
	end
	local r = root :: BasePart
	local result = if attached
		then workspace:Raycast(r.Position + climbUp, -wallNormal * 4, rayParams())
		else findWallAround()
	if not result then
		ClientState.hint = "Avvicinati a una parete per piantare un chiodo"
		return
	end
	drivePiton((result :: RaycastResult).Position, (result :: RaycastResult).Normal)
end

placePitonAction = placePiton

-- Mirino: tenendo premuto F (o il pulsante Chiodo) compare un cerchio sulla roccia nel punto
-- che stai mirando, cosi' scegli tu dove va il chiodo invece di prendere quello che capita.
-- Verde = ci sta, rosso = no. Un tocco veloce pianta subito, senza mirare.
local function clearAim()
	aiming = false
	for _, part in { aimMarker, aimDot } do
		if part then
			part:Destroy()
		end
	end
	aimMarker, aimDot, aimPos, aimNormal = nil, nil, nil, nil
end

local function makeAim()
	local function marker(name: string, shape: Enum.PartType, size: Vector3, transparency: number): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = size
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Transparency = transparency
		-- sotto la telecamera: lo vedo solo io e i raggi lo ignorano gia'
		part.Parent = workspace.CurrentCamera
		return part
	end
	aimMarker = marker("MirinoChiodo", Enum.PartType.Cylinder, Vector3.new(0.2, 3.6, 3.6), 0.55)
	aimDot = marker("MirinoCentro", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), 0.1)
end

local function aimStep()
	local disc, dot = aimMarker, aimDot
	if not disc or not dot or not root then
		return
	end
	local r = root :: BasePart
	local cam = workspace.CurrentCamera
	local origin, dir
	if UserInputService.MouseEnabled then
		local m = UserInputService:GetMouseLocation()
		local viewRay = cam:ViewportPointToRay(m.X, m.Y)
		origin, dir = viewRay.Origin, viewRay.Direction
	else
		origin, dir = cam.CFrame.Position, cam.CFrame.LookVector
	end
	local hit = workspace:Raycast(origin, dir * 250, rayParams())
	if not hit then
		disc.Transparency, dot.Transparency = 1, 1
		aimPos, aimNormal = nil, nil
		ClientState.hint = "Punta la roccia dove vuoi il chiodo"
		return
	end
	local h = hit :: RaycastResult
	local far = (h.Position - r.Position).Magnitude > ClimbConfig.PLACE_RANGE
	local flat = h.Normal.Y > ClimbConfig.WALL_MAX_NORMAL_Y
	local ok = not far and not flat
	local color = if ok then Color3.fromRGB(110, 235, 130) else Color3.fromRGB(240, 90, 80)
	disc.Color, dot.Color = color, color
	disc.Transparency, dot.Transparency = 0.55, 0.1
	disc.CFrame = CFrame.lookAt(h.Position + h.Normal * 0.12, h.Position + h.Normal) * CFrame.Angles(0, math.pi / 2, 0)
	dot.CFrame = CFrame.new(h.Position + h.Normal * 0.3)
	aimPos, aimNormal = (if ok then h.Position else nil), (if ok then h.Normal else nil)
	ClientState.hint = if far
		then "Troppo lontano: avvicinati"
		elseif flat then "Il chiodo va in parete, non sul piano"
		else "Lascia il tasto per piantare il chiodo qui"
end

function Climbing.aimBegin()
	if not root or aiming then
		return
	end
	aiming = true
	aimDown = os.clock()
	makeAim()
end

function Climbing.aimFinish()
	if not aiming then
		return
	end
	local held = os.clock() - aimDown
	local pos, normal = aimPos, aimNormal
	clearAim()
	-- tocco veloce: chiodo subito, come prima. Tenuto premuto: dove punta il cerchio.
	if held < 0.2 or not pos or not normal then
		placePiton()
	else
		drivePiton(pos :: Vector3, normal :: Vector3)
	end
end

-- Click con la Piccozza: aggrappati / lasciati andare
local function onAxeClick()
	if not root or mantling or os.clock() - lastToggle < 0.3 then
		return
	end
	if attached then
		detach(false, "click")
		return
	end
	local result = findWallAround()
	if not result then
		ClientState.hint = "Nessuna parete ripida davanti a te"
		return
	end
	local ok, why = canGrab(result)
	if ok then
		lastToggle = os.clock()
		attachTo(result)
	else
		ClientState.hint = why or ""
	end
end

-- Script di arrampicata/corsa scaricati dal Toolbox (es. "Auto Wall Climb") combattono con
-- questo sistema: forzano lo stato Climbing a ogni frame e il personaggio si blocca. Li spegniamo.
local CONFLICTING = { WallClimb = true, SprintScript = true, ["Ledge Climb"] = true }
local warned = false
local function disableConflicts(inst: Instance)
	if inst:IsA("LocalScript") and CONFLICTING[inst.Name] then
		inst.Enabled = false
		if not warned then
			warned = true
			warn("[Climbing] Disattivato lo script '" .. inst.Name .. "': va in conflitto con l'arrampicata. Toglilo dal Workspace.")
		end
	end
end

local function onCharacter(newCharacter: Model)
	detach(false, "respawn")
	for _, d in newCharacter:GetDescendants() do
		disableConflicts(d)
	end
	newCharacter.DescendantAdded:Connect(disableConflicts)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	ClientState.stamina = ClimbConfig.STAMINA_MAX
	table.clear(reportedRocks)
	ClimbAnimator.bind(newCharacter)
	ClimbIK.bind(newCharacter)
	holdTrack = nil -- nuovo personaggio, nuovo Animator
	;(humanoid :: Humanoid).Died:Connect(function()
		detach(false, "death")
	end)
	newCharacter.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == ClimbConfig.TOOL_NAME then
			if not child:GetAttribute("Bound") then
				child:SetAttribute("Bound", true)
				child.Activated:Connect(onAxeClick)
				child.Unequipped:Connect(function()
					detach(false, "unequip")
					if holdTrack then
						(holdTrack :: AnimationTrack):Stop(0.2)
					end
				end)
			end
			playHold()
			ClientState.hint = "Click vicino a una parete per aggrapparti  |  F: chiodo (tieni premuto per mirare)"
		end
	end)
end

function Climbing.start()
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	controls = playerModule:GetControls()

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	-- Spazio sulla parete: salto via dalla parete
	UserInputService.JumpRequest:Connect(function()
		if attached and os.clock() - lastToggle > 0.3 then
			-- Spazio tenendo W: lancio a due piccozze (si resta sulla parete); senza W ti stacchi
			local now = os.clock()
			if lastInputZ < -0.3 and lastRoofness < 0.3 and now > dynoUntil + 0.25 then
				if ClientState.stamina >= ClimbConfig.DYNO_STAMINA then
					ClientState.stamina -= ClimbConfig.DYNO_STAMINA
					dynoUntil = now + ClimbConfig.DYNO_TIME
					lastToggle = now
					if jumpTrack then
						(jumpTrack :: AnimationTrack):Play(0.08, 1, 1)
					end
					ClimbFeel.kick(0.8, Vector3.new(0, 1, 0.2))
					task.delay(ClimbConfig.DYNO_TIME, function()
						if attached and root then
							-- le due piccozze mordono insieme
							ClimbFeel.kick(1, Vector3.new(0, -1, -0.4))
							local p = (root :: BasePart).Position
							ClimbFeel.impact(p + Vector3.new(0, 2.5, 0) - wallNormal * 1.5, wallNormal, nil, 12)
						end
					end)
				else
					ClientState.hint = "Troppo stanco per lanciarti"
				end
				return
			end
			detach(true, "jump")
		end
	end)

	-- colpito da massi o valanga: ti stacchi dalla parete e vieni spinto via
	;(remotes:WaitForChild("Knockback") :: RemoteEvent).OnClientEvent:Connect(function(push: Vector3)
		detach(false, "knockback")
		if root then
			(root :: BasePart).AssemblyLinearVelocity += push
			ClientState.hint = "Colpito!"
		end
	end)

	ContextActionService:BindAction("PlacePiton", function(_, state)
		if state == Enum.UserInputState.Begin then
			Climbing.aimBegin()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			Climbing.aimFinish()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	-- E: aggrappati / lasciati, come il click (ma non se c'e' un prompt da usare: anche quelli
	-- vanno con la E, es. negozio e banco da lavoro)
	ProximityPromptService.PromptShown:Connect(function()
		promptsShown += 1
	end)
	ProximityPromptService.PromptHidden:Connect(function()
		promptsShown = math.max(0, promptsShown - 1)
	end)
	ContextActionService:BindAction("GrabWall", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if promptsShown > 0 and not attached then
			return Enum.ContextActionResult.Pass
		end
		onAxeClick()
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E)

	ContextActionService:BindAction("ReleaseRope", function(_, state)
		if state == Enum.UserInputState.Begin then
			remotes.ReleaseRope:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

	RunService.Heartbeat:Connect(function(dt)
		if not root or not humanoid or humanoid.Health <= 0 then
			if aiming then
				clearAim()
			end
			return
		end
		if aiming then
			aimStep()
		end
		if attached then
			climbStep(dt)
		end
		ropeStep(dt)
	end)
end

return Climbing
