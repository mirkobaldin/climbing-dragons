--!strict
-- Anima i draghi al seguito (di tutti i giocatori) sul client, cosi' si muovono fluidi:
--   * volano accanto alla spalla del padrone, lo seguono con un po' di ritardo, si
--     inclinano nelle curve, ondeggiano col battito d'ali e ogni tanto gli girano intorno
--   * "parts": sbattono le ali, muovono la coda e la testa (parti con nome/attributo Anim)
--   * "bones": muovono le ossa (tentacoli, pinne, coda, ali, orecchie, mascella, braccia)
--   * "mesh": una mesh sola senza ossa -> solo movimento del corpo intero
--   * quadrupedi con scheletro Rigify (es. il drago Ombra: spine.*, thigh.*, front_thigh.*,
--     shoulder.*.00x per le ali): a terra CAMMINANO accanto al padrone (passo diagonale), in
--     aria o quando il padrone arrampica VOLANO (ali che battono, zampe raccolte). Le ossa
--     ruotano attorno agli assi del corpo, non ai loro assi locali: cosi' non si accartocciano.
-- Il muso del modello viene trovato da solo (osso/parte "head"); per le mesh senza ossa si
-- assume +Z (gira col attributo "Yaw" in gradi sul modello in ServerStorage se serve).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local KfsPlayer = require(script.Parent.KfsPlayer)
local DragonMotion = require(script.Parent.DragonMotion)
local DragonProcedural = require(script.Parent.DragonProcedural)
local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local ClientState = require(script.Parent.ClientState)

local PetAnimator = {}

type PartRig = { part: BasePart, rest: CFrame, kind: string, side: number, index: number }
type BoneRig = { bone: Bone, kind: string, index: number, side: number, amp: number }
-- osso di un quadrupede Rigify: ruota attorno a un asse del corpo, espresso nell'osso
type QuadBone = { bone: Bone, role: string, side: number, index: number, axisX: Vector3, axisY: Vector3, axisZ: Vector3 }
type Pet = {
	model: Model,
	ownerId: number,
	slot: number,
	rig: string,
	fix: CFrame, -- porta il muso del modello su -Z
	pivot0: CFrame,
	parts: { PartRig },
	bones: { BoneRig },
	size: number,
	cf: CFrame?,
	phase: number,
	nextOrbit: number,
	stillSince: number?, -- fermo dal (si siede dopo 10 s, dorme dopo 30 s)
	nextGesture: number?, -- prossimo gesto a caso (annusa, si guarda attorno...)
	actUntil: number?, -- fine del gesto in corso
	wasAir: boolean?, -- era in volo (decollo e atterraggio ai cambi)
	quad: { QuadBone }?,
	footDrop: number, -- quanto stanno sotto il pivot le zampe (per camminare a terra)
	walkPhase: number,
	airBlend: number, -- 0 = a terra, 1 = in volo (passaggio morbido)
	-- animazioni fatte nell'Animation Editor (volo, camminata, fermo): se ci sono, sostituiscono
	-- il movimento procedurale delle ossa
	tracks: { fly: AnimationTrack, walk: AnimationTrack, idle: AnimationTrack }?,
	seat: Vector3?, -- dove si siede chi monta (spazio del corpo: -Z muso, +Y su)
	yaw: number?, -- direzione dell'ultimo fotogramma (per le virate in monta)
	velS: Vector3?, -- velocita' del padrone filtrata
	turn: number, -- velocita' di virata filtrata (rad/s, + a sinistra)
	wasRidden: boolean?,
	lift: number, -- quanto si alza a terra perche' la posa non affondi
}

local pets: { [Model]: Pet } = {}

-- Ampiezza del movimento per tipo di osso
local BONE_KINDS = {
	{ word = "tentacle", kind = "wave", amp = 0.35 },
	{ word = "tail", kind = "wave", amp = 0.3 },
	{ word = "coda", kind = "wave", amp = 0.3 },
	{ word = "fin", kind = "wave", amp = 0.4 },
	{ word = "wing", kind = "flap", amp = 0.6 },
	{ word = "ala", kind = "flap", amp = 0.6 },
	{ word = "ear", kind = "wave", amp = 0.15 },
	{ word = "hair", kind = "wave", amp = 0.25 },
	{ word = "jaw", kind = "jaw", amp = 0.15 },
	{ word = "tongue", kind = "wave", amp = 0.1 },
	{ word = "hand", kind = "wave", amp = 0.15 },
	{ word = "arm", kind = "wave", amp = 0.12 },
	{ word = "neck", kind = "nod", amp = 0.06 },
	{ word = "head", kind = "nod", amp = 0.05 },
	{ word = "spine", kind = "wave", amp = 0.05 },
}

local function chainIndex(name: string): number
	local n = tonumber(string.match(name, "(%d+)$"))
	if n then
		return n
	end
	local lower = string.lower(name)
	if string.find(lower, "_mid") then
		return 2
	elseif string.find(lower, "_end") then
		return 3
	end
	return 1
end

local function sideOf(name: string, x: number): number
	local lower = string.lower(name)
	if string.find(name, "L_") or string.find(name, "L$") or string.find(lower, "left") then
		return 1
	elseif string.find(name, "R_") or string.find(name, "R$") or string.find(lower, "right") then
		return -1
	end
	return if x >= 0 then 1 else -1
end

-- ID dell'animazione: quello in DragonConfig, oppure (solo in Studio) quella salvata nell'editor
local idCache: { [string]: string | false } = {}
local function animId(name: string, configured: string): string?
	if configured ~= "" then
		return configured
	end
	if idCache[name] ~= nil then
		return idCache[name] or nil
	end
	idCache[name] = false
	if RunService:IsStudio() then
		local saves = ReplicatedStorage:FindFirstChild("ClimbAnimSaves")
		local kfs = saves and saves:FindFirstChild(name)
		if kfs and kfs:IsA("KeyframeSequence") then
			local ok, id = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
			end)
			if ok then
				idCache[name] = id
			end
		end
	end
	return idCache[name] or nil
end

-- Animazioni del modello: ID pubblicati in DragonConfig.DRAGON_ANIMS, oppure (solo in Studio)
-- i salvataggi dell'editor passati dal server in ReplicatedStorage.DragonAnimSaves.<modello>
local keyCache: { [string]: string | false } = {}
local function modelAnim(key: string, name: string, published: string?): string?
	if published and published ~= "" then
		return published
	end
	local cacheKey = key .. "/" .. name
	if keyCache[cacheKey] ~= nil then
		return keyCache[cacheKey] or nil
	end
	keyCache[cacheKey] = false
	if RunService:IsStudio() then
		local saves = ReplicatedStorage:FindFirstChild("DragonAnimSaves")
		local set = saves and saves:FindFirstChild(key)
		local kfs = set and set:FindFirstChild(name)
		if kfs and kfs:IsA("KeyframeSequence") then
			local ok, id = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
			end)
			if ok then
				keyCache[cacheKey] = id
			end
		end
	end
	return keyCache[cacheKey] or nil
end

-- Volo, camminata e fermo partono insieme; il RenderStepped ne regola i pesi
-- gesti una tantum di ogni drago (vedi loadTracks)
local actsOf: { [Model]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any

local function loadTracks(model: Model): { fly: AnimationTrack, walk: AnimationTrack, idle: AnimationTrack }?
	local key = model:GetAttribute("AnimKey")
	local fly, walk, idle
	if type(key) == "string" then
		local published = DragonConfig.DRAGON_ANIMS[key]
		-- senza ID pubblicati: le pose salvate si suonano a mano (anche sul telefono; prima
		-- funzionavano solo in Studio e nel gioco il drago restava fermo)
		local saves = ReplicatedStorage:FindFirstChild("DragonAnimSaves")
		local set = saves and saves:FindFirstChild(key)
		if set and not (published and published.fly and published.fly ~= "") then
			local function kf(name: string): KeyframeSequence?
				local k = set:FindFirstChild(name)
				return if k and k:IsA("KeyframeSequence") then k else nil
			end
			local kFly = kf("Dragon_Fly")
			local kWalk = kf("Dragon_Walk") or kFly
			local kIdle = kf("Dragon_Idle") or kWalk
			if kFly and kWalk and kIdle then
				local tracks: { [string]: any } = {
					fly = KfsPlayer.load(model, kFly),
					walk = KfsPlayer.load(model, kWalk),
					idle = KfsPlayer.load(model, kIdle),
				}
				local kDive = kf("Dragon_Dive")
				if kDive then
					tracks.dive = KfsPlayer.load(model, kDive) -- picchiata (trailer e discese veloci)
				end
				-- in monta (cicli): virate, salita, discesa, librato e planata (MapGen.AnimDraghi)
				for name, key in { bankL = "Dragon_BankL", bankR = "Dragon_BankR", climb = "Dragon_Climb", descend = "Dragon_Descend", hover = "Dragon_Hover", glide = "Dragon_Glide" } do
					local k = kf(key)
					if k then
						tracks[name] = KfsPlayer.load(model, k)
					end
				end
				-- a terra: seduto, dorme, corsa (cicli)
				for name, key in { sit = "Dragon_Sit", sleep = "Dragon_Sleep", run = "Dragon_Run" } do
					local k = kf(key)
					if k then
						tracks[name] = KfsPlayer.load(model, k)
					end
				end
				for _, t in tracks do
					t:Play(0, 0.001)
				end
				-- gesti una tantum: annusa, si scrolla, si guarda attorno, ruggisce, decollo, atterraggio
				local acts = {}
				for _, name in { "Sniff", "Shake", "Look", "Roar", "Takeoff", "Land" } do
					local k = kf("Dragon_" .. name)
					if k then
						local tr = KfsPlayer.load(model, k)
						tr.Looped = false
						acts[name] = tr
					end
				end
				actsOf[model] = acts -- a parte: chi scorre le tracce (clip del Trailer) trova solo tracce
				-- animazioni procedurali sopra le pose (client/DragonProcedural): piedi sul terreno,
				-- inerzia di collo e coda, sella che segue il petto. Solo con KfsPlayer
				-- le ossa dei draghi grandi arrivano dopo il modello (streaming): se non ci sono ancora
				-- si riprova per 10 s (prima l'Eclissi e il Cosmico adulti restavano senza)
				if not DragonProcedural.attach(model) then
					task.spawn(function()
						local last = -1
						for _ = 1, 20 do
							task.wait(0.5)
							if not model.Parent then
								return
							end
							-- solo quando le ossa hanno smesso di arrivare (scheletro completo)
							local n = 0
							for _, d in model:GetDescendants() do
								if d:IsA("Bone") then
									n += 1
								end
							end
							if n >= 8 and n == last and DragonProcedural.attach(model) then
								return
							end
							last = n
						end
						warn("[DragonProcedural] non attivo su " .. model.Name)
					end)
				end
				return tracks :: any
			end
		end
		fly = modelAnim(key, "Dragon_Fly", published and published.fly)
		walk = modelAnim(key, "Dragon_Walk", published and published.walk) or fly
		idle = modelAnim(key, "Dragon_Idle", published and published.idle) or walk
	end
	-- l'Ombra ha anche i vecchi ID "globali"
	if not fly and model:FindFirstChild("spine.004", true) then
		fly = animId("Dragon_Fly", DragonConfig.FLY_ANIM)
		walk = animId("Dragon_Walk", DragonConfig.WALK_ANIM) or fly
		idle = animId("Dragon_Idle", DragonConfig.IDLE_ANIM) or walk
	end
	if not fly or not walk or not idle then
		return nil
	end
	local controller = Instance.new("AnimationController")
	controller.Name = "PetAnimationController"
	local animator = Instance.new("Animator")
	animator.Parent = controller
	controller.Parent = model
	local function load(id: string): AnimationTrack
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0, 0.001)
		return track
	end
	local ok, tracks = pcall(function()
		return { fly = load(fly :: string), walk = load(walk :: string), idle = load(idle :: string) }
	end)
	if not ok then
		warn("[PetAnimator] animazioni del drago non caricate: " .. tostring(tracks))
		controller:Destroy()
		return nil
	end
	return tracks
end

local function setup(model: Model)
	local ownerId = model:GetAttribute("Owner")
	if type(ownerId) ~= "number" or pets[model] then
		return
	end
	local pivot0 = model:GetPivot()
	local pet: Pet = {
		model = model,
		ownerId = ownerId,
		slot = (model:GetAttribute("Slot") or 1) :: number,
		rig = (model:GetAttribute("Rig") or "mesh") :: string,
		fix = CFrame.identity,
		pivot0 = pivot0,
		parts = {},
		bones = {},
		size = 4,
		cf = nil,
		phase = math.random() * 10,
		nextOrbit = os.clock() + 8 + math.random() * 10,
		quad = nil,
		footDrop = 0,
		walkPhase = 0,
		airBlend = 1,
		turn = 0,
		lift = 0,
	}
	local _, size = model:GetBoundingBox()
	pet.size = math.max(size.X, size.Y, size.Z)

	-- dov'e' la testa? (per sapere dove guarda il modello)
	local headPos: Vector3? = nil
	for _, d in model:GetDescendants() do
		local lower = string.lower(d.Name)
		if (d:IsA("Bone") or d:IsA("BasePart")) and (lower == "head" or lower == "testa" or lower == "face" or d:GetAttribute("Anim") == "head") then
			headPos = if d:IsA("Bone") then d.WorldPosition else (d :: BasePart).Position
			break
		end
	end
	if not headPos and pet.rig == "mesh" then
		pet.fix = CFrame.Angles(0, math.pi, 0) -- i pet a mesh unica di solito guardano verso +Z
	end
	if headPos then
		local dir = pivot0:VectorToObjectSpace((headPos :: Vector3) - pivot0.Position)
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude > 0.05 then
			pet.fix = CFrame.lookAt(Vector3.zero, dir.Unit):Inverse()
		end
	end

	-- chi monta: sulle spalle dietro la base del collo (attributo Seat del server, DragonModels);
	-- senza: sopra il centro del corpo
	do
		local bcf, bsize = model:GetBoundingBox()
		local body = pivot0 * pet.fix:Inverse()
		local seat = model:GetAttribute("Seat")
		pet.seat = if typeof(seat) == "Vector3" then body:PointToObjectSpace(pivot0 * seat) else body:PointToObjectSpace(bcf.Position + Vector3.new(0, bsize.Y * 0.16, 0))
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and pet.rig == "parts" then
			local rest = pivot0:ToObjectSpace(d.CFrame)
			local lower = string.lower(d.Name)
			local kind = d:GetAttribute("Anim") :: string?
			if not kind then
				kind = if string.find(lower, "wing") or string.find(lower, "ala") then "wing"
					elseif string.find(lower, "tail") or string.find(lower, "coda") then "tail"
					elseif string.find(lower, "head") or string.find(lower, "testa") then "head"
					else "body"
			end
			table.insert(pet.parts, {
				part = d,
				rest = rest,
				kind = kind :: string,
				side = (d:GetAttribute("Side") or (if rest.Position.X >= 0 then 1 else -1)) :: number,
				index = (d:GetAttribute("Index") or chainIndex(d.Name)) :: number,
			})
		elseif d:IsA("Bone") then
			local lower = string.lower(d.Name)
			for _, k in BONE_KINDS do
				if string.find(lower, k.word, 1, true) then
					table.insert(pet.bones, {
						bone = d,
						kind = k.kind,
						index = chainIndex(d.Name),
						side = sideOf(d.Name, d.Position.X),
						amp = k.amp,
					})
					break
				end
			end
		end
	end
	-- quadrupede Rigify: ruoli delle ossa dai nomi, assi del corpo portati nello spazio di ogni osso
	local spineRoot = model:FindFirstChild("spine.004", true)
	if spineRoot and spineRoot:IsA("Bone") and model:FindFirstChild("thigh.L", true) then
		local body = pivot0 * pet.fix:Inverse() -- assi del corpo: -Z muso, +Y su, +X destra
		local quad: { QuadBone } = {}
		local lowest = 0
		for _, b in model:GetDescendants() do
			if b:IsA("Bone") then
				local n = b.Name
				local role: string? = nil
				local index = tonumber(string.match(n, "%.(%d+)$")) or 0
				if string.match(n, "^shoulder%.[LR]%.00[1-4]$") then
					role = "wing"
				elseif n == "spine" or n == "spine.001" or n == "spine.002" or n == "spine.003" then
					role = "tail"
					index = 4 - index -- spine.003 attaccata al corpo, spine in punta
				elseif n == "spine.009" or n == "spine.010" or n == "spine.011" then
					role = "neck"
				elseif n == "jaw" then
					role = "jaw"
				elseif string.match(n, "^front_thigh") or string.match(n, "^thigh") then
					role = "thigh"
				elseif string.match(n, "^front_shin") or string.match(n, "^shin") then
					role = "shin"
				end
				local rel = body:PointToObjectSpace(b.WorldPosition)
				lowest = math.min(lowest, rel.Y)
				if role then
					local w = b.WorldCFrame
					table.insert(quad, {
						bone = b,
						role = role,
						side = if string.find(n, "%.L") then -1 elseif string.find(n, "%.R") then 1 else 0,
						index = index,
						-- zampe anteriori in fase con la posteriore opposta (passo diagonale)
						axisX = w:VectorToObjectSpace(body.RightVector),
						axisY = w:VectorToObjectSpace(body.UpVector),
						axisZ = w:VectorToObjectSpace(-body.LookVector),
					})
					if string.match(n, "^front_") then
						quad[#quad].index = 100 -- segna l'anteriore
					end
				end
			end
		end
		pet.quad = quad
		pet.footDrop = -lowest
	end
	-- animazioni fatte nell'editor (o generate): per tutti i modelli che le hanno
	pet.tracks = loadTracks(model)
	if pet.tracks and not pet.quad then
		pet.footDrop = size.Y / 2 -- il pivot e' al centro del modello
	end
	local yaw = model:GetAttribute("Yaw")
	if type(yaw) == "number" then
		pet.fix = CFrame.Angles(0, math.rad(yaw), 0) * pet.fix
	end
	pets[model] = pet
end

local function animateParts(pet: Pet, pivot: CFrame, t: number, speed: number)
	local flap = t * (6 + speed * 0.25) + pet.phase
	for _, p in pet.parts do
		local extra = CFrame.identity
		local pos = p.rest.Position
		if p.kind == "wing" then
			local hinge = Vector3.new(pos.X * 0.35, pos.Y, pos.Z)
			local angle = p.side * (math.sin(flap) * 0.7 + 0.15)
			extra = CFrame.new(hinge) * CFrame.Angles(0, 0, angle) * CFrame.new(-hinge)
		elseif p.kind == "tail" then
			local hinge = Vector3.new(0, pos.Y, 0)
			local angle = math.sin(t * 3 + pet.phase - p.index * 0.7) * 0.12 * math.sqrt(p.index)
			extra = CFrame.new(hinge) * CFrame.Angles(0, angle, 0) * CFrame.new(-hinge)
		elseif p.kind == "head" then
			local hinge = Vector3.new(0, pos.Y, pos.Z * 0.5)
			extra = CFrame.new(hinge) * CFrame.Angles(math.sin(t * 1.3 + pet.phase) * 0.08, math.sin(t * 0.7) * 0.15, 0) * CFrame.new(-hinge)
		end
		p.part.CFrame = pivot * extra * p.rest
	end
end

local function animateBones(pet: Pet, t: number, speed: number)
	local fast = 1 + speed * 0.04
	for _, b in pet.bones do
		local a = 0
		if b.kind == "wave" then
			a = math.sin(t * 2.2 * fast + pet.phase - b.index * 0.6) * b.amp
			b.bone.Transform = CFrame.Angles(0, a * 0.6, a)
		elseif b.kind == "flap" then
			a = math.sin(t * 6 * fast + pet.phase) * b.amp * b.side
			b.bone.Transform = CFrame.Angles(a, 0, a)
		elseif b.kind == "jaw" then
			a = (math.sin(t * 0.8 + pet.phase) + 1) * b.amp
			b.bone.Transform = CFrame.Angles(0, 0, a)
		elseif b.kind == "nod" then
			a = math.sin(t * 1.2 + pet.phase) * b.amp
			b.bone.Transform = CFrame.Angles(0, a, a * 0.5)
		end
	end
end

-- Quadrupede: volo (ali, zampe raccolte) e camminata (passo diagonale), mescolati con airBlend
local function animateQuad(pet: Pet, t: number, speed: number)
	local air = pet.airBlend
	local flap = t * 6.5 + pet.phase
	local walk = pet.walkPhase
	local moving = math.clamp(speed / 10, 0, 1)
	for _, q in pet.quad :: { QuadBone } do
		local rot = CFrame.identity
		if q.role == "wing" then
			-- in volo battono; a terra ripiegate sul dorso (tranne un piccolo respiro)
			local lag = (q.index - 1) * 0.5 -- la punta segue la spalla in ritardo
			local beat = math.sin(flap - lag) * (0.55 + 0.1 * q.index) * air
			local fold = (1 - air) * (if q.index <= 2 then 0.9 else 0.6)
			rot = CFrame.fromAxisAngle(q.axisZ, (beat - fold) * q.side)
		elseif q.role == "tail" then
			local amp = (0.12 + 0.05 * q.index) * (0.6 + 0.4 * air)
			rot = CFrame.fromAxisAngle(q.axisY, math.sin(t * 2.2 + pet.phase - q.index * 0.7) * amp)
				* CFrame.fromAxisAngle(q.axisX, math.sin(t * 1.6 + q.index) * 0.05)
		elseif q.role == "neck" then
			local look = math.sin(t * 0.5 + pet.phase) * 0.18 * (1 - moving)
			rot = CFrame.fromAxisAngle(q.axisY, look / 3) * CFrame.fromAxisAngle(q.axisX, math.sin(walk * 2) * 0.04 * moving + math.sin(flap) * 0.03 * air)
		elseif q.role == "jaw" then
			rot = CFrame.fromAxisAngle(q.axisX, (math.sin(t * 0.7 + pet.phase) + 1) * 0.06)
		elseif q.role == "thigh" or q.role == "shin" then
			local front = q.index == 100
			-- passo diagonale: anteriore sinistra con posteriore destra
			local ph = walk + (if (q.side > 0) ~= front then math.pi else 0)
			local step = if q.role == "thigh" then math.sin(ph) * 0.5 else math.max(0, -math.cos(ph)) * 0.7
			local tuck = if q.role == "thigh" then (if front then -0.9 else 0.9) else (if front then 1.2 else -1.2)
			rot = CFrame.fromAxisAngle(q.axisX, step * moving * (1 - air) + tuck * air * 0.6)
		end
		q.bone.Transform = rot
	end
end

function PetAnimator.start()
	local folder = workspace:WaitForChild("Pets")
	local function scan(inst: Instance)
		if inst:IsA("Model") and inst:GetAttribute("Owner") then
			-- aspetta che arrivino tutte le parti
			task.delay(0.2, setup, inst)
		end
	end
	folder.DescendantAdded:Connect(scan)
	for _, d in folder:GetDescendants() do
		scan(d)
	end

	-- camera piu' lontana col drago grande (l'adulto e' 33 studs: da vicino copriva tutto). Quando
	-- arriva un drago piu' grande la visuale si allontana una volta; poi la rotella resta libera.
	task.spawn(function()
		local me = Players.LocalPlayer
		local baseMax = me.CameraMaxZoomDistance
		local lastBig = 0
		while true do
			task.wait(1)
			local big = 0
			for model, pet in pets do
				if model.Parent and pet.ownerId == me.UserId and model:GetAttribute("Benched") ~= true then
					big = math.max(big, pet.size)
				end
			end
			me.CameraMaxZoomDistance = math.max(baseMax, big * 6)
			local want = if big >= 24 then big * 1.35 elseif big >= 13 then big * 1.6 else 0
			if want > 0 and big > lastBig + 1 and not ClientState.dragonMode then
				local oldMin = me.CameraMinZoomDistance
				me.CameraMinZoomDistance = math.min(want, me.CameraMaxZoomDistance)
				task.wait(1) -- la camera arriva alla distanza con una molla: serve tempo
				me.CameraMinZoomDistance = oldMin
			end
			lastBig = big
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local snap = ClientState.petSnap
		ClientState.petSnap = false
		local camera = workspace.CurrentCamera
		for model, pet in pets do
			if not model.Parent then
				pets[model] = nil
				continue
			end
			local owner = Players:GetPlayerByUserId(pet.ownerId)
			local character = owner and owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local r = root :: BasePart
			-- drago di un giocatore lontano: non si vede, niente calcoli (quando ti avvicini riparte
			-- dal padrone, vedi il controllo dei 600 studs qui sotto)
			if camera and (camera.CFrame.Position - r.Position).Magnitude > 500 then
				continue
			end
			local s = math.max(pet.size / 4, 1)
			local side = if pet.slot % 2 == 1 then 1 else -1
			-- battito d'ali: piccoli sobbalzi verso l'alto (solo per i modelli senza animazioni: con le
			-- ali animate il sobbalzo a |sin| non andava a tempo col battito e il volo sembrava a scatti)
			local flapT = t * 7 + pet.phase
			local flapBob = if pet.tracks then 0 else (1 - math.cos(flapT * 2)) * 0.15
			local bob = (math.sin(t * 1.3 + pet.phase) * 0.3 + flapBob) * s
			local offset = Vector3.new(side * (2.2 + s * 1.3), 1.6 + s * 0.7 + bob, 2 + s * 1.2 + (if pet.slot > 2 then 4 else 0))
			-- ogni tanto fa un giro intorno al padrone (3 secondi)
			-- addestramento: il tuo drago vola fermo nel punto indicato (centro dell'arena)
			local anchored = owner == Players.LocalPlayer and ClientState.petAnchor ~= nil
			-- nell'arena entra solo il drago del posto 1 (quello che si addestra): col gamepass
			-- ExtraDragon il secondo prima volava nello stesso punto e si incastravano
			local benched = anchored and pet.slot ~= 1
			if benched ~= (model:GetAttribute("Benched") == true) then
				model:SetAttribute("Benched", benched)
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						(d :: any).LocalTransparencyModifier = if benched then 1 else 0
					elseif d:IsA("BillboardGui") then
						d.Enabled = not benched
					end
				end
			end
			if benched then
				continue
			end
			local orbiting = not anchored and t >= pet.nextOrbit and t < pet.nextOrbit + 3
			if orbiting then
				local a = (t - pet.nextOrbit) / 3 * math.pi * 2
				local radius = math.max(4, offset.Magnitude)
				offset = Vector3.new(math.sin(a) * radius, offset.Y, math.cos(a) * radius)
			elseif t >= pet.nextOrbit + 3 then
				pet.nextOrbit = t + 15 + math.random() * 15
			end
			local target = r.CFrame * CFrame.new(offset)
			-- quadrupede (o drago animato): se il padrone e' a terra e non arrampica, cammina sul
			-- terreno al suo fianco; i draghi grandi stanno piu' di lato
			if pet.quad or pet.tracks then
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				local grounded = hum ~= nil and hum.FloorMaterial ~= Enum.Material.Air and not r:FindFirstChild("ClimbAttachment")
				pet.airBlend += ((if grounded and not anchored then 0 else 1) - pet.airBlend) * math.min(1, dt * 3)
				if grounded and not anchored then
					local beside = r.CFrame * CFrame.new(side * (3 + s * (if s > 3 then 2.2 else 1.5)), 0, if s > 3 then 1 + s * 0.4 else 2 + s)
					-- terreno e parti solide (la pedana della casa: sotto non c'e' terreno e prima il
					-- drago ci spariva sotto); il raggio parte alto, perche' in salita il punto a fianco
					-- puo' stare sopra il padrone e un raggio nato dentro il terreno non lo trova
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { model, character :: Instance }
					params.RespectCanCollide = true
					local hit = workspace:Raycast(beside.Position + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), params)
					if not hit or hit.Position.Y < beside.Position.Y - 12 then
						hit = workspace:Raycast(beside.Position + Vector3.new(0, 40, 0), Vector3.new(0, -50, 0), params) or hit
					end
					local y = if hit then hit.Position.Y + pet.footDrop else beside.Position.Y
					local ground = Vector3.new(beside.Position.X, y, beside.Position.Z)
					target = CFrame.new(ground:Lerp(target.Position, pet.airBlend)) * target.Rotation
				end
				pet.walkPhase += dt * (2 + (pet.velS or Vector3.zero).Magnitude * 0.45)
			end
			if anchored then
				target = CFrame.new((ClientState.petAnchor :: Vector3) + Vector3.new(0, bob, 0))
			end
			if owner == Players.LocalPlayer and snap then
				pet.cf = nil -- uscito dall'arena: niente volo attraverso la mappa
			end
			local current = pet.cf or target
			-- se la posizione si e' guastata (NaN o lontanissima, es. dopo un esercizio in palestra
			-- il drago finiva a -1000000) si riparte dal padrone
			local cp = current.Position
			if cp ~= cp or (cp - target.Position).Magnitude > 600 then
				current = target
			end
			local alpha = 1 - math.exp(-dt * (if t >= pet.nextOrbit and t < pet.nextOrbit + 3 then 9 else 5))
			local pos = current.Position:Lerp(target.Position, alpha)
			-- guarda dove va il padrone (o dove guarda, se e' fermo)
			-- velocita' del padrone FILTRATA: quella grezza della fisica trema da un frame all'altro e
			-- inclinazione, beccheggio e pesi delle animazioni di volo andavano a scatti
			local rawVel = r.AssemblyLinearVelocity
			if rawVel ~= rawVel then
				rawVel = Vector3.zero
			end
			pet.velS = (pet.velS or rawVel):Lerp(rawVel, math.min(1, dt * 5))
			local vel = pet.velS :: Vector3
			local flat = Vector3.new(vel.X, 0, vel.Z)
			local look = if flat.Magnitude > 2 then flat.Unit else Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
			-- il drago guarda dove va lui: quando il padrone si gira il suo posto passa dall'altra parte
			-- e prima ci andava camminando all'indietro
			local own = (pos - current.Position) / math.max(dt, 1 / 240)
			local ownFlat = Vector3.new(own.X, 0, own.Z)
			if ownFlat.Magnitude > math.max(6, flat.Magnitude * 0.6) then
				look = ownFlat.Unit
			end
			if owner == Players.LocalPlayer and ClientState.petLook then
				look = ClientState.petLook :: Vector3 -- nell'arena il drago si gira dove spari
			end
			if orbiting then
				-- guarda nella direzione del giro
				local moveDir = target.Position - current.Position
				moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
				if moveDir.Magnitude > 0.05 then
					look = moveDir.Unit
				end
			end
			if look.Magnitude < 0.01 then
				look = -Vector3.zAxis
			end
			local desired = CFrame.lookAt(pos, pos + look.Unit)
			local rotated = current.Rotation:Lerp(desired.Rotation, alpha)
			do
				local yaw = math.atan2(-rotated.LookVector.X, -rotated.LookVector.Z)
				local d = (yaw - (pet.yaw or yaw) + math.pi) % (2 * math.pi) - math.pi
				pet.yaw = yaw
				pet.turn += (d / math.max(dt, 1 / 240) - pet.turn) * math.min(1, dt * 6)
			end
			local lateral = flat:Dot(rotated.RightVector)
			local bank = math.clamp(-lateral * 0.02, -0.45, 0.45)
			local pitch = math.clamp(vel.Y * 0.015, -0.35, 0.35) + (if pet.tracks then 0 else math.sin(flapT) * 0.05)
			local cf = CFrame.new(pos) * rotated
			-- in groppa (server/Riding): il drago sta sotto chi lo monta e guarda dove va lui
			local riding = owner ~= nil and owner:GetAttribute("Riding") == true and pet.slot == 1 and not anchored and pet.seat ~= nil
			if riding then
				local face = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
				if face.Magnitude < 0.05 then
					face = -Vector3.zAxis
				end
				local hips = r.Position - Vector3.new(0, 1.4, 0)
				-- si inclina nelle virate e punta il muso su o giu' quando sale e scende; il perno
				-- e' il posto di chi monta, cosi' il giocatore resta attaccato al collo
				local roll = math.clamp(pet.turn * 0.35, -0.6, 0.6)
				local nose = math.clamp(vel.Y * 0.008, -0.4, 0.35)
				-- la sella si sposta col petto (DragonProcedural): il drago si muove sotto chi monta
				local shift = (pet.fix :: CFrame):VectorToWorldSpace(DragonProcedural.seatShift(model))
				if shift ~= shift then
					shift = Vector3.zero -- mai un NaN nella posizione del drago
				end
				cf = CFrame.lookAt(hips, hips + face.Unit) * CFrame.Angles(nose, 0, roll) * CFrame.new(-((pet.seat :: Vector3) + shift))
				pet.airBlend = 1
				pitch = 0
				bank = 0
				if not pet.wasRidden then
					pet.wasRidden = true
					DragonProcedural.impulse(model, "decollo")
					local tr = (actsOf[model] or {}).Takeoff
					if tr then
						tr.time = 0
						tr:Play(0.15, 1.2)
						task.delay(math.max(0.1, tr.clip.length - 0.2), function()
							tr:Stop(0.3)
						end)
					end
				end
			elseif pet.wasRidden then
				pet.wasRidden = false
			end
			pet.cf = cf

			if pet.quad or pet.tracks then
				pitch *= pet.airBlend
				bank *= pet.airBlend
			end
			local pivot = cf * CFrame.Angles(pitch, 0, bank) * pet.fix
			local far = camera and (camera.CFrame.Position - pos).Magnitude > 300
			if pet.rig == "parts" and not far then
				animateParts(pet, pivot, t, flat.Magnitude)
			else
				-- corpo intero (mesh, ossa); "respiro" leggero dei modelli a mesh unica
				local breathe = if pet.rig == "mesh" then CFrame.Angles(math.sin(t * 5 + pet.phase) * 0.06, 0, 0) else CFrame.identity
				-- a terra (seduto, dorme): non affonda (DragonMotion.groundLift)
				if pet.tracks and pet.airBlend < 0.99 then
					pet.lift += (DragonMotion.groundLift(model) * (1 - pet.airBlend) - pet.lift) * math.min(1, dt * 4)
				else
					pet.lift *= 0.9
				end
				model:PivotTo(pivot * breathe + Vector3.new(0, pet.lift, 0))
				if pet.tracks then
					-- collo, busto e coda che seguono il volo vero (sopra le animazioni)
					DragonMotion.update(model, dt, { turn = pet.turn, vy = vel.Y, speed = flat.Magnitude, air = pet.airBlend, walk = pet.walkPhase * math.pi, t = t })
					DragonProcedural.setAir(model, pet.airBlend)
				end
				if pet.tracks then
					-- pesi: in aria il volo, a terra camminata o fermo secondo la velocita'
					local tracks = pet.tracks
					local air = pet.airBlend
					local moving = math.clamp(flat.Magnitude / 8, 0, 1)
					-- in caduta veloce (il padrone scende in fretta) le ali si chiudono: picchiata
					local dive = if (tracks :: any).dive and vel.Y < -25 then air else 0
					if (tracks :: any).dive then
						(tracks :: any).dive:AdjustWeight(math.max(dive, 0.001), 0.2)
					end
					local tx = tracks :: any
					-- fermo a lungo accanto al padrone: prima si siede, poi si addormenta
					local now = os.clock()
					local still = air < 0.2 and moving < 0.1
					if not still then
						pet.stillSince = now
					end
					local stillFor = now - (pet.stillSince or now)
					local sleepK = if tx.sleep and stillFor > 30 then 1 else 0
					local sitK = if tx.sit and stillFor > 10 and sleepK == 0 then 1 else 0
					-- seduto o addormentato: niente piedi a terra; fermo e sveglio guarda il padrone
					DragonProcedural.setLegs(model, 1 - math.max(sitK, sleepK))
					local ownerHead = owner and owner.Character and owner.Character:FindFirstChild("Head")
					DragonProcedural.setLook(model, if still and sleepK == 0 and ownerHead and ownerHead:IsA("BasePart") then ownerHead.Position else nil)
					-- corsa quando il padrone corre (al posto della camminata)
					local runK = if tx.run then math.clamp((flat.Magnitude - 16) / 8, 0, 1) else 0
					local idleW = (1 - air) * (1 - moving)
					tracks.fly:AdjustWeight(math.max(air - dive, 0.001), 0.1)
					tracks.walk:AdjustWeight(math.max((1 - air) * moving * (1 - runK), 0.001), 0.1)
					-- passo alla velocita' vera (un passo lungo ~mezzo drago): i piedi non scivolano
					if (tracks.walk :: any).AdjustSpeed then
						(tracks.walk :: any):AdjustSpeed(math.clamp(flat.Magnitude / math.max(pet.size * 0.55, 2), 0.6, 2.2))
					end
					if tx.run then
						tx.run:AdjustWeight(math.max((1 - air) * moving * runK, 0.001), 0.15)
					end
					tracks.idle:AdjustWeight(math.max(idleW * (1 - sitK - sleepK), 0.001), 0.4)
					if tx.sit then
						tx.sit:AdjustWeight(math.max(idleW * sitK, 0.001), 0.8)
					end
					if tx.sleep then
						tx.sleep:AdjustWeight(math.max(idleW * sleepK, 0.001), 1.2)
					end
					-- in monta: librato da fermo, virate a destra e sinistra, salita, discesa e picchiata
					-- (le animazioni nuove di MapGen.AnimDraghi), il resto battito normale
					local w = { hover = 0, bankL = 0, bankR = 0, climb = 0, descend = 0, glide = 0 }
					if riding then
						local fwdK = math.clamp(flat.Magnitude / 30, 0, 1)
						local upK = math.clamp(vel.Y / 28, 0, 1)
						local downK = math.clamp(-vel.Y / 26, 0, 1)
						local diveK = if tx.dive then math.clamp((-vel.Y - 40) / 30, 0, 1) else 0
						local turnK = math.clamp(math.abs(pet.turn) / 1.1, 0, 1) * fwdK
						w.hover = if tx.hover then (1 - fwdK) * (1 - downK) * (1 - upK * 0.5) else 0
						w.climb = if tx.climb then upK * (1 - w.hover) else 0
						w.descend = if tx.descend then downK * (1 - diveK) else 0
						w.bankL = if tx.bankL and pet.turn > 0 then turnK * (1 - w.climb - w.descend) else 0
						w.bankR = if tx.bankR and pet.turn < 0 then turnK * (1 - w.climb - w.descend) else 0
						-- di corsa dritto e in piano (Shift): ali aperte, planata
						w.glide = if tx.glide and flat.Magnitude > 95 then (1 - turnK) * (1 - upK) * (1 - downK) else 0
						local used = w.hover + w.climb + w.descend + w.bankL + w.bankR + w.glide + diveK
						tracks.fly:AdjustWeight(math.max(1 - used, 0.001), 0.15)
						if tx.dive then
							tx.dive:AdjustWeight(math.max(diveK, 0.001), 0.2)
						end
					end
					for name, k in w do
						if tx[name] then
							tx[name]:AdjustWeight(math.max(k, 0.001), 0.25)
						end
					end
					-- gesti: decollo e atterraggio ai cambi, e ogni tanto uno a caso quando e' fermo
					local acts = actsOf[model] or {}
					local function act(name: string)
						local tr = acts[name]
						if tr then
							tr.time = 0
							tr:Play(0.15, 1.2)
							pet.actUntil = now + tr.clip.length
							task.delay(math.max(0.1, tr.clip.length - 0.2), function()
								tr:Stop(0.3)
							end)
						end
					end
					local wasAir = pet.wasAir or false
					if air > 0.6 and not wasAir then
						pet.wasAir = true
						act("Takeoff")
					elseif air < 0.3 and wasAir then
						pet.wasAir = false
						act("Land")
					end
					if still and sleepK == 0 and now > (pet.nextGesture or now + 6) and now > (pet.actUntil or 0) then
						local pick = { "Sniff", "Look", "Shake", "Look", "Sniff", "Roar" }
						act(pick[math.random(1, #pick)])
						pet.nextGesture = now + 7 + math.random() * 9
					elseif not pet.nextGesture then
						pet.nextGesture = now + 6
					end
					-- i draghi grandi battono le ali piu' lenti (un adulto che sbatte come un cucciolo
					-- sembrava un insetto)
					tracks.fly:AdjustSpeed(math.clamp(12 / pet.size, 0.45, 1))
				elseif pet.quad and not far then
					animateQuad(pet, t, flat.Magnitude)
				elseif pet.rig == "bones" and not far then
					animateBones(pet, t, flat.Magnitude)
				end
			end
		end
	end)
end

PetAnimator.loadTracks = loadTracks -- usato anche dal trailer

return PetAnimator
