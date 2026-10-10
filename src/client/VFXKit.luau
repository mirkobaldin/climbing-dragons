--!strict
-- Effetti presi dalla libreria ReplicatedStorage.VFXLib (fatta in Studio dai pacchetti VFX di
-- Mirko, "VFX PACK" e "VFX"): animazioni flipbook di fuoco, fumo, fulmini, ghiaccio, crepe e
-- mesh di onde d'urto, palle di fuoco, fulmini, spuntoni.
--   VFXKit.burst(nome, punto, opzioni)    un colpo solo (esplosione, crepa, lampo...)
--   VFXKit.attach(nome, parte, opzioni)   emitter che restano accesi (scia, aura di un cristallo)
--   VFXKit.mesh(nome, cframe, opzioni)    mesh che cresce e sparisce (anello, fulmine, spuntoni)
-- Se la libreria manca le funzioni non fanno niente: gli effetti fatti a mano restano.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VFXKit = {}

export type Options = {
	color: Color3?, -- ricolora (le sfumature verso il nero restano scure)
	scale: number?, -- grandezza delle particelle
	count: number?, -- particelle per emitter in un burst
	rate: number?, -- per attach: particelle al secondo
	light: number?, -- LightEmission
}

local function library(kind: string): Instance?
	local lib = ReplicatedStorage:FindFirstChild("VFXLib")
	return lib and lib:FindFirstChild(kind)
end

function VFXKit.has(name: string): boolean
	local p = library("Particelle")
	return p ~= nil and p:FindFirstChild(name) ~= nil
end

local function scaled(seq: NumberSequence, k: number): NumberSequence
	local list = {}
	for _, kp in seq.Keypoints do
		table.insert(list, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
	end
	return NumberSequence.new(list)
end

local function tinted(seq: ColorSequence, color: Color3): ColorSequence
	local list = {}
	for _, kp in seq.Keypoints do
		local v = kp.Value
		local luma = v.R * 0.3 + v.G * 0.59 + v.B * 0.11
		-- la fine scura del fuoco (arancio -> nero) resta scura, il resto prende il colore
		table.insert(list, ColorSequenceKeypoint.new(kp.Time, if luma < 0.15 then v else color))
	end
	return ColorSequence.new(list)
end

-- copia gli emitter di un effetto dentro un Attachment nuovo
local function clone(name: string, parent: Instance, opts: Options?): Attachment?
	local folder = library("Particelle")
	local src = folder and folder:FindFirstChild(name)
	if not src then
		return nil
	end
	local o = opts or {}
	local a = Instance.new("Attachment")
	a.Name = "VFX_" .. name
	for _, e in src:GetChildren() do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			if o.scale and o.scale ~= 1 then
				c.Size = scaled(c.Size, o.scale)
				c.Speed = NumberRange.new(c.Speed.Min * o.scale, c.Speed.Max * o.scale)
			end
			if o.color then
				c.Color = tinted(c.Color, o.color)
			end
			if o.light then
				c.LightEmission = o.light
			end
			-- le crepe e le onde stanno piatte perpendicolari alla velocita': senza un minimo di
			-- velocita' (verso +Y dell'Attachment) non saprebbero come girarsi
			if c.Orientation == Enum.ParticleOrientation.VelocityPerpendicular and c.Speed.Max == 0 then
				c.Speed = NumberRange.new(0.01)
			end
			c.Parent = a
		end
	end
	a.Parent = parent
	return a
end

-- un punto invisibile nel mondo che regge gli effetti
local function holder(at: CFrame, life: number): Part
	local p = Instance.new("Part")
	p.Name = "VFX"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = at
	p.Parent = workspace
	Debris:AddItem(p, life)
	return p
end

-- un colpo solo; at puo' essere un punto o un CFrame (l'asse Y del CFrame orienta le crepe e le
-- onde che stanno piatte)
function VFXKit.burst(name: string, at: Vector3 | CFrame, opts: Options?)
	local cf = if typeof(at) == "CFrame" then at else CFrame.new(at)
	local p = holder(cf, 3)
	local a = clone(name, p, opts)
	if not a then
		p:Destroy()
		return
	end
	local n = (opts and opts.count) or 1
	local longest = 0
	for _, e in a:GetChildren() do
		if e:IsA("ParticleEmitter") then
			e:Emit(n)
			longest = math.max(longest, e.Lifetime.Max)
		end
	end
	Debris:AddItem(p, longest + 0.3)
end

-- emitter accesi attaccati a una parte; restituisce l'Attachment (si spegne distruggendolo)
function VFXKit.attach(name: string, parent: BasePart | Attachment, opts: Options?): Attachment?
	local a = clone(name, parent, opts)
	if not a then
		return nil
	end
	for _, e in a:GetChildren() do
		if e:IsA("ParticleEmitter") then
			if opts and opts.rate then
				e.Rate = opts.rate
			end
			e.Enabled = true
		end
	end
	return a
end

export type MeshOptions = {
	color: Color3?,
	from: number?, -- grandezza iniziale (studs, lato piu' lungo)
	to: number?, -- grandezza finale
	time: number?,
	spin: number?, -- giri attorno all'asse Y durante la vita
	transparency: number?, -- trasparenza iniziale
	material: Enum.Material?,
	flat: boolean?, -- cresce solo in X e Z (anelli a terra)
}

-- una mesh della libreria grande "size" (lato piu' lungo), ancora da mettere nel mondo
function VFXKit.part(name: string, size: number): MeshPart?
	local folder = library("Mesh")
	local src = folder and folder:FindFirstChild(name)
	if not src or not src:IsA("MeshPart") then
		return nil
	end
	local m = src:Clone()
	m.Size = m.Size / math.max(m.Size.X, m.Size.Y, m.Size.Z) * size
	return m
end

-- mesh della libreria che cresce, gira e sparisce; restituisce la parte (o nil)
function VFXKit.mesh(name: string, cf: CFrame, opts: MeshOptions?): MeshPart?
	local folder = library("Mesh")
	local src = folder and folder:FindFirstChild(name)
	if not src or not src:IsA("MeshPart") then
		return nil
	end
	local o = opts or {}
	local m = src:Clone()
	local base = m.Size / math.max(m.Size.X, m.Size.Y, m.Size.Z)
	local from, to = o.from or 2, o.to or 8
	local time = o.time or 0.45
	local function size(k: number): Vector3
		if o.flat then
			return Vector3.new(base.X * k, base.Y * math.max(from, 1), base.Z * k)
		end
		return base * k
	end
	m.Size = size(from)
	m.CFrame = cf
	m.Color = o.color or Color3.new(1, 1, 1)
	m.Material = o.material or Enum.Material.Neon
	m.Transparency = o.transparency or 0.1
	m.Parent = workspace
	local goal: { [string]: any } = { Size = size(to), Transparency = 1 }
	if o.spin then
		goal.CFrame = cf * CFrame.Angles(0, o.spin * math.pi * 2, 0)
	end
	TweenService:Create(m, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(m, time + 0.1)
	return m
end

-- il terreno sotto un punto (per crepe e anelli a terra): CFrame con Y lungo la normale
function VFXKit.ground(at: Vector3, depth: number?): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -(depth or 8), 0), params)
	if not hit then
		return nil
	end
	local n = hit.Normal
	local side = if math.abs(n.Y) > 0.99 then Vector3.xAxis else n:Cross(Vector3.yAxis).Unit
	return CFrame.fromMatrix(hit.Position + n * 0.15, side, n)
end

return VFXKit
