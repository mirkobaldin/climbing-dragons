--!strict
-- Animazioni della palestra: mentre un giocatore fa un esercizio (attributo GymExercise, messo dal
-- server che lo blocca sull'attrezzo) si muovono le sue articolazioni R15 a mano (Motor6D.Transform,
-- dopo le animazioni normali). Le vede chiunque: ogni client anima tutti quelli che si allenano.
--   bench   panca: braccia che spingono in alto
--   pullup  trazioni: braccia in alto, il corpo sale e scende
--   curl    manubri: un gomito alla volta (manubri in mano)
--   squat   anche e ginocchia piegate, bacino che scende
--   rope    corda: braccia alternate, gambe raccolte
--   box     sacco: pugni alternati, busto che ruota
-- Convenzioni R15: +X sulla spalla = braccio avanti, +X sul gomito = avambraccio che si piega,
-- +X sull'anca = coscia avanti, -X sul ginocchio = gamba che si piega.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GymAnim = {}

local PERIOD = { bench = 1.6, pullup = 1.8, curl = 1.4, squat = 1.9, rope = 1.2, box = 0.7 }

local function smoothWave(p: number): number
	return (1 - math.cos(2 * math.pi * p)) / 2 -- 0 -> 1 -> 0
end

-- articolazioni: Motor6D (personaggi vecchi) o AnimationConstraint (le nuove articolazioni di
-- Roblox): entrambe hanno Transform
type Rig = { motors: { [string]: any }, props: { BasePart } }
local rigs: { [Model]: Rig } = {}

local function rigOf(character: Model): Rig
	local r = rigs[character]
	if r then
		return r
	end
	local motors = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			motors[d.Name] = d
		end
	end
	r = { motors = motors, props = {} }
	rigs[character] = r
	return r
end

local function dumbbell(): BasePart
	local p = Instance.new("Part")
	p.Name = "ManubrioInMano"
	p.Size = Vector3.new(1.4, 0.3, 0.3)
	p.Shape = Enum.PartType.Cylinder
	p.Color = Color3.fromRGB(52, 54, 60)
	p.Material = Enum.Material.Metal
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Parent = workspace
	return p
end

-- bilanciere in mano: sbarra cromata e dischi rossi, tenuto tra le due mani
local function heldBarbell(): { BasePart }
	local function make(size: Vector3, color: Color3, mat: Enum.Material): BasePart
		local p = Instance.new("Part")
		p.Name = "BilanciereInMano"
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = color
		p.Material = mat
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Parent = workspace
		return p
	end
	return {
		make(Vector3.new(8, 0.35, 0.35), Color3.fromRGB(190, 192, 198), Enum.Material.Metal),
		make(Vector3.new(0.5, 2.6, 2.6), Color3.fromRGB(200, 50, 45), Enum.Material.SmoothPlastic),
		make(Vector3.new(0.5, 2.6, 2.6), Color3.fromRGB(200, 50, 45), Enum.Material.SmoothPlastic),
	}
end

-- il bilanciere fermo sull'attrezzo si nasconde (solo qui) mentre lo tieni in mano
local hiddenBar: { [Model]: { BasePart } } = {}
local function hideStationBar(character: Model, hide: boolean, names: { [string]: boolean }?)
	if hide then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local gym = workspace:FindFirstChild("Palestra")
		local list = {}
		local want = names or { Sbarra = true, Disco = true }
		if root and gym then
			for _, d in gym:GetChildren() do
				-- (prima i dischi restavano: un controllo sulla grandezza li escludeva)
				if d:IsA("BasePart") and want[d.Name] and (d.Position - (root :: BasePart).Position).Magnitude < 7.5 and not (d.Name == "Sbarra" and d.Position.Y - (root :: BasePart).Position.Y > 5) then
					d.LocalTransparencyModifier = 1
					table.insert(list, d)
				end
			end
		end
		hiddenBar[character] = list
	else
		for _, d in hiddenBar[character] or {} do
			d.LocalTransparencyModifier = 0
		end
		hiddenBar[character] = nil
	end
end

local function clear(character: Model)
	local r = rigs[character]
	if not r then
		return
	end
	for _, p in r.props do
		p:Destroy()
	end
	hideStationBar(character, false)
	rigs[character] = nil
end

local function pose(r: Rig, kind: string, p: number)
	local m = r.motors
	local function set(name: string, cf: CFrame)
		local motor = m[name]
		if motor then
			motor.Transform = cf
		end
	end
	local s = smoothWave(p)
	local A = CFrame.Angles
	if kind == "bench" then
		-- sdraiato: "avanti" per le braccia e' verso l'alto
		set("RightShoulder", A(math.rad(85), 0, 0))
		set("LeftShoulder", A(math.rad(85), 0, 0))
		set("RightElbow", A(math.rad(95 * (1 - s)), 0, 0))
		set("LeftElbow", A(math.rad(95 * (1 - s)), 0, 0))
		set("RightHip", A(math.rad(70), 0, 0))
		set("LeftHip", A(math.rad(70), 0, 0))
		set("RightKnee", A(math.rad(-85), 0, 0))
		set("LeftKnee", A(math.rad(-85), 0, 0))
	elseif kind == "pullup" then
		set("RightShoulder", A(math.rad(170 - 40 * s), 0, math.rad(-10)))
		set("LeftShoulder", A(math.rad(170 - 40 * s), 0, math.rad(10)))
		set("RightElbow", A(math.rad(110 * s), 0, 0))
		set("LeftElbow", A(math.rad(110 * s), 0, 0))
		set("RightKnee", A(math.rad(-50), 0, 0))
		set("LeftKnee", A(math.rad(-50), 0, 0))
		set("Root", CFrame.new(0, 2.2 * s, 0))
	elseif kind == "curl" then
		local a = smoothWave(p)
		local b = smoothWave(p + 0.5)
		set("RightShoulder", A(math.rad(10), 0, 0))
		set("LeftShoulder", A(math.rad(10), 0, 0))
		set("RightElbow", A(math.rad(15 + 115 * a), 0, 0))
		set("LeftElbow", A(math.rad(15 + 115 * b), 0, 0))
		set("Waist", A(math.rad(-3 * a + 3 * b), 0, 0))
	elseif kind == "squat" then
		set("RightHip", A(math.rad(95 * s), 0, 0))
		set("LeftHip", A(math.rad(95 * s), 0, 0))
		set("RightKnee", A(math.rad(-120 * s), 0, 0))
		set("LeftKnee", A(math.rad(-120 * s), 0, 0))
		set("RightAnkle", A(math.rad(30 * s), 0, 0))
		set("LeftAnkle", A(math.rad(30 * s), 0, 0))
		set("Waist", A(math.rad(-25 * s), 0, 0))
		-- mani sul bilanciere dietro la testa
		set("RightShoulder", A(math.rad(150), 0, math.rad(-40)))
		set("LeftShoulder", A(math.rad(150), 0, math.rad(40)))
		set("RightElbow", A(math.rad(120), 0, 0))
		set("LeftElbow", A(math.rad(120), 0, 0))
		set("Root", CFrame.new(0, -1.7 * s, 0))
	elseif kind == "rope" then
		local a = smoothWave(p)
		local b = smoothWave(p + 0.5)
		set("RightShoulder", A(math.rad(120 + 50 * a), 0, 0))
		set("LeftShoulder", A(math.rad(120 + 50 * b), 0, 0))
		set("RightElbow", A(math.rad(70 * (1 - a)), 0, 0))
		set("LeftElbow", A(math.rad(70 * (1 - b)), 0, 0))
		set("RightHip", A(math.rad(40 + 30 * b), 0, 0))
		set("LeftHip", A(math.rad(40 + 30 * a), 0, 0))
		set("RightKnee", A(math.rad(-60), 0, 0))
		set("LeftKnee", A(math.rad(-60), 0, 0))
		set("Root", CFrame.new(0, 1.2 * math.sin(2 * math.pi * p), 0))
	elseif kind == "box" then
		local right = p < 0.5
		local k = math.sin((p % 0.5) * 2 * math.pi) -- 0 -> 1 -> 0 per pugno
		set("RightShoulder", A(math.rad(if right then 40 + 50 * k else 40), 0, 0))
		set("LeftShoulder", A(math.rad(if right then 40 else 40 + 50 * k), 0, 0))
		set("RightElbow", A(math.rad(if right then 110 * (1 - k) else 110), 0, 0))
		set("LeftElbow", A(math.rad(if right then 110 else 110 * (1 - k)), 0, 0))
		set("Waist", A(0, math.rad(if right then 20 * k else -20 * k), 0))
		set("RightKnee", A(math.rad(-15), 0, 0))
		set("LeftKnee", A(math.rad(-15), 0, 0))
	end
end

-- per le clip: mette un modello qualsiasi (il sosia) nella posa dell'esercizio, fase p (0-1)
function GymAnim.poseModel(model: Model, kind: string, p: number)
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			motors[d.Name] = d
		end
	end
	pose({ motors = motors, props = {} }, kind, p)
end
GymAnim.PERIOD = PERIOD

function GymAnim.start()
	-- mentre ti alleni i tasti dell'arrampicata (E, F, salto...) non fanno niente: prima E girava
	-- il personaggio di 90 gradi
	local ContextActionService = game:GetService("ContextActionService")
	local me = Players.LocalPlayer
	local function lock()
		if me:GetAttribute("GymExercise") then
			ContextActionService:BindActionAtPriority("BloccoPalestra", function()
				return Enum.ContextActionResult.Sink
			end, false, 3000, Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.Space, Enum.KeyCode.R, Enum.KeyCode.Q, Enum.KeyCode.G, Enum.UserInputType.MouseButton1)
		else
			ContextActionService:UnbindAction("BloccoPalestra")
		end
	end
	me:GetAttributeChangedSignal("GymExercise"):Connect(lock)
	-- dopo le animazioni normali di Roblox (Stepped): le nostre pose vincono
	RunService.Stepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, plr in Players:GetPlayers() do
			local character = plr.Character
			if not character then
				continue
			end
			local kind = plr:GetAttribute("GymExercise")
			if type(kind) == "string" then
				local r = rigOf(character)
				local since = (plr:GetAttribute("GymSince") or now) :: number
				local p = ((now - since) / (PERIOD[kind] or 1.5)) % 1
				pose(r, kind, p)
				-- bilanciere tra le mani (panca e squat)
				if kind == "bench" or kind == "squat" then
					if #r.props == 0 then
						r.props = heldBarbell()
						hideStationBar(character, true)
					end
					local rh, lh = character:FindFirstChild("RightHand"), character:FindFirstChild("LeftHand")
					if rh and lh and rh:IsA("BasePart") and lh:IsA("BasePart") then
						local mid = (rh.Position + lh.Position) / 2
						local axis = (rh.Position - lh.Position)
						axis = if axis.Magnitude > 0.1 then axis.Unit else (character:GetPivot().RightVector)
						-- cilindro lungo l'asse X: si allinea l'asse X tra le due mani
						local cf = CFrame.fromMatrix(mid, axis, axis:Cross(Vector3.yAxis).Magnitude > 0.1 and axis:Cross(Vector3.yAxis):Cross(axis).Unit or Vector3.zAxis)
						r.props[1].CFrame = cf
						r.props[2].CFrame = cf * CFrame.new(3.4, 0, 0)
						r.props[3].CFrame = cf * CFrame.new(-3.4, 0, 0)
					end
				end
				-- manubri nelle mani
				if kind == "curl" then
					if #r.props == 0 then
						r.props = { dumbbell(), dumbbell() }
						hideStationBar(character, true, { Manubrio = true, Peso = true })
					end
					for k, hand in { "RightHand", "LeftHand" } do
						local h = character:FindFirstChild(hand)
						if h and h:IsA("BasePart") then
							r.props[k].CFrame = h.CFrame * CFrame.new(0, -0.4, 0) * CFrame.Angles(0, math.pi / 2, 0)
						end
					end
				end
			elseif rigs[character] then
				clear(character)
			end
		end
	end)
end

return GymAnim
