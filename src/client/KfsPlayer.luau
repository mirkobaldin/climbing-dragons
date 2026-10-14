--!strict
-- Riproduttore di KeyframeSequence fatto a mano: legge le pose e le scrive ogni frame nei
-- Bone.Transform del modello. Serve nel gioco pubblicato: le animazioni salvate nell'editor
-- (RBX_ANIMSAVES) si possono registrare solo in Studio, e senza ID pubblicati sul telefono i
-- draghi restavano fermi. Le "tracce" hanno gli stessi metodi di AnimationTrack usati dal gioco
-- (Play, Stop, AdjustWeight, AdjustSpeed).

local RunService = game:GetService("RunService")

local KfsPlayer = {}

type Curve = { times: { number }, cfs: { CFrame } }
type Clip = { length: number, curves: { [string]: Curve } }

local clips: { [KeyframeSequence]: Clip } = {}

local function parse(kfs: KeyframeSequence): Clip
	local cached = clips[kfs]
	if cached then
		return cached
	end
	local list = kfs:GetKeyframes() :: { any }
	table.sort(list, function(a, b)
		return a.Time < b.Time
	end)
	local curves: { [string]: Curve } = {}
	local length = 0
	for _, kf in list do
		length = math.max(length, kf.Time)
		for _, p in kf:GetDescendants() do
			if p:IsA("Pose") and p.Weight > 0 then
				local c = curves[p.Name]
				if not c then
					c = { times = {}, cfs = {} }
					curves[p.Name] = c
				end
				table.insert(c.times, kf.Time)
				table.insert(c.cfs, p.CFrame)
			end
		end
	end
	local clip = { length = math.max(length, 0.05), curves = curves }
	clips[kfs] = clip
	return clip
end

local function sample(c: Curve, t: number): CFrame
	local times = c.times
	local n = #times
	if t <= times[1] then
		return c.cfs[1]
	elseif t >= times[n] then
		return c.cfs[n]
	end
	for i = 1, n - 1 do
		if t < times[i + 1] then
			local a = (t - times[i]) / (times[i + 1] - times[i])
			return c.cfs[i]:Lerp(c.cfs[i + 1], a)
		end
	end
	return c.cfs[n]
end

export type Track = {
	clip: Clip,
	time: number,
	speed: number,
	weight: number,
	target: number,
	fade: number,
	playing: boolean,
	Looped: boolean,
	Play: (Track, number?, number?) -> (),
	Stop: (Track, number?) -> (),
	AdjustWeight: (Track, number, number?) -> (),
	AdjustSpeed: (Track, number) -> (),
}

local TrackMethods = {}
TrackMethods.__index = TrackMethods
function TrackMethods.Play(self: Track, fade: number?, weight: number?)
	self.playing = true
	self.target = weight or 1
	self.fade = fade or 0.1
	if (fade or 0.1) <= 0 then
		self.weight = self.target
	end
end
function TrackMethods.Stop(self: Track, fade: number?)
	self.target = 0
	self.fade = fade or 0.1
end
function TrackMethods.AdjustWeight(self: Track, w: number, fade: number?)
	self.target = w
	self.fade = fade or 0.1
end
function TrackMethods.AdjustSpeed(self: Track, s: number)
	self.speed = s
end

type Rig = { model: Model, bones: { [string]: Bone }, tracks: { Track } }
local rigs: { [Model]: Rig } = {}

-- una traccia per la sequenza, sul modello (le ossa si trovano per nome)
function KfsPlayer.load(model: Model, kfs: KeyframeSequence): Track
	local rig = rigs[model]
	if not rig then
		local bones = {}
		for _, d in model:GetDescendants() do
			if d:IsA("Bone") and not bones[d.Name] then
				bones[d.Name] = d
			end
		end
		rig = { model = model, bones = bones, tracks = {} }
		rigs[model] = rig
	end
	local track = setmetatable({
		clip = parse(kfs),
		time = 0,
		speed = 1,
		weight = 0,
		target = 0,
		fade = 0.1,
		playing = false,
		Looped = true,
	}, TrackMethods) :: any
	table.insert((rig :: Rig).tracks, track)
	return track
end

local MAX_DIST = 350 -- piu' lontano non si vede: niente calcoli

local function step(dt: number)
	local camPos = workspace.CurrentCamera.CFrame.Position
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		if (model:GetPivot().Position - camPos).Magnitude > ((model:GetAttribute("AnimRange") or MAX_DIST) :: number) then
			continue
		end
		-- tempi e pesi
		for _, tr in rig.tracks do
			if tr.playing then
				tr.time += dt * tr.speed
				if tr.Looped then
					tr.time %= tr.clip.length
				else
					tr.time = math.min(tr.time, tr.clip.length)
				end
				local k = if tr.fade <= 0 then 1 else math.min(1, dt / tr.fade)
				tr.weight += (tr.target - tr.weight) * k
			end
		end
		-- le pose sono in studs del rig su cui sono state fatte (Workspace.RigDraghi): sui draghi
		-- rimpiccioliti gli spostamenti vanno ridotti come fa l'Animator di Roblox. L'attributo
		-- AnimBaseScale e' la scala del modello quando era grande come il rig (DragonModels: 1).
		-- Prima un drago del recinto a scala 0.2 scendeva di 19 studs (la posa "dorme"
		-- dell'adulto) e spariva sotto la pedana
		local base = model:GetAttribute("AnimBaseScale")
		local scale = if type(base) == "number" and base > 0 then model:GetScale() / base else 1
		-- per ogni osso, media pesata delle pose delle tracce
		for name, bone in rig.bones do
			local acc: CFrame? = nil
			local total = 0
			for _, tr in rig.tracks do
				local c = tr.playing and tr.weight > 0.002 and tr.clip.curves[name]
				if c then
					local cf = sample(c, tr.time)
					total += tr.weight
					acc = if acc then (acc :: CFrame):Lerp(cf, tr.weight / total) else cf
				end
			end
			if acc then
				local cf = if total < 1 then CFrame.identity:Lerp(acc :: CFrame, total) else acc :: CFrame
				if scale ~= 1 then
					cf = cf.Rotation + cf.Position * scale
				end
				bone.Transform = cf
			end
		end
	end
end

RunService.RenderStepped:Connect(step)

return KfsPlayer
