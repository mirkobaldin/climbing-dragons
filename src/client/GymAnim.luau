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

local function clear(character: Model)
	local r = rigs[character]
	if not r then
		return
	end
	for _, p in r.props do
		p:Destroy()
	end
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

function GymAnim.start()
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
				-- manubri nelle mani
				if kind == "curl" then
					if #r.props == 0 then
						r.props = { dumbbell(), dumbbell() }
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
