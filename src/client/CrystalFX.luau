--!strict
-- Effetti dei cristalli delle zone a tema (Workspace.ZoneATema, modelli "Cristallo" con
-- l'attributo Element), presi dalla libreria VFXLib e solo per quelli vicini alla camera
-- (sono quasi 2000: accesi tutti insieme sarebbero troppi):
--   Gelo      brillii di ghiaccio, ogni tanto il ghiaccio scricchiola
--   Gas       bolle e un filo di nebbia magenta alla base
--   Tempesta  brillii azzurri e piccole scariche elettriche che saltano sul cristallo
--   Fulmine   come la tempesta, ma viola scuro (fulmine nero)
--   Cosmico   scintille viola-magenta e ogni tanto un vortice di stelle in cima
--   Eclissi   braci arancioni che salgono e fumo scuro
--   Roccia    qualche riflesso d'ambra
-- Tutto locale.

local Sfx = require(script.Parent.Sfx)
local VFXKit = require(script.Parent.VFXKit)

local CrystalFX = {}

local NEAR = 150 -- entro questa distanza dalla camera si accendono
local FAR = 190 -- oltre si spengono
local MAX_ACTIVE = 36

type Look = {
	glint: Color3, -- colore dei brillii
	glintRate: number,
	mist: Color3?, -- nebbia alla base
	bubbles: Color3?,
	arcs: Color3?, -- scariche elettriche
	swirl: Color3?, -- vortice in cima
	crackle: boolean?,
}

local LOOKS: { [string]: Look } = {
	Gelo = { glint = Color3.fromRGB(200, 240, 255), glintRate = 3, crackle = true },
	-- il drago Gas e' azzurro con nuvole magenta (non verde)
	Gas = { glint = Color3.fromRGB(90, 220, 255), glintRate = 1, mist = Color3.fromRGB(240, 80, 220), bubbles = Color3.fromRGB(90, 220, 255) },
	Tempesta = { glint = Color3.fromRGB(170, 215, 255), glintRate = 2, arcs = Color3.fromRGB(150, 200, 255) },
	Fulmine = { glint = Color3.fromRGB(180, 150, 255), glintRate = 2, arcs = Color3.fromRGB(130, 80, 230) },
	Cosmico = { glint = Color3.fromRGB(230, 120, 255), glintRate = 4, swirl = Color3.fromRGB(220, 90, 255) },
	Eclissi = { glint = Color3.fromRGB(255, 150, 60), glintRate = 2, mist = Color3.fromRGB(70, 30, 90) },
	Roccia = { glint = Color3.fromRGB(255, 205, 130), glintRate = 1.2 },
}

type Crystal = { model: Model, element: string, at: Vector3 }
type Active = { holder: Part, crystal: Crystal, size: number }

local ELEMENT_OF_FOLDER: { [string]: boolean } = {}
for el in LOOKS do
	ELEMENT_OF_FOLDER[el] = true
end

local function elementOf(m: Model): string?
	local el = m:GetAttribute("Element")
	if type(el) == "string" and LOOKS[el] then
		return el
	end
	local parent = m.Parent
	if parent and ELEMENT_OF_FOLDER[parent.Name] then
		return parent.Name
	end
	return nil
end

-- una parte invisibile grande come il cristallo: le particelle nascono nel suo volume
local function decorate(c: Crystal): Active?
	local cf, size = c.model:GetBoundingBox()
	if size.Magnitude < 0.5 then
		return nil
	end
	local look = LOOKS[c.element]
	local h = math.max(size.X, size.Y, size.Z)
	local holder = Instance.new("Part")
	holder.Name = "EffettiCristallo"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = true, false, false, false, false
	holder.Transparency = 1
	holder.Size = size * 0.7
	holder.CFrame = cf
	holder.Parent = workspace.CurrentCamera -- solo locale, fuori dalla mappa (e dallo streaming)
	local function onVolume(a: Attachment?)
		-- dall'Attachment (un punto) alla parte (tutto il volume del cristallo)
		if a then
			for _, e in a:GetChildren() do
				e.Parent = holder
			end
			a:Destroy()
		end
	end
	onVolume(VFXKit.attach("Scintille", holder, { color = look.glint, rate = look.glintRate * math.clamp(h / 10, 0.6, 3), scale = math.clamp(h / 18, 0.4, 1.2), light = 1 }))
	if look.bubbles then
		onVolume(VFXKit.attach("Bolle", holder, { color = look.bubbles, rate = 0.5, scale = math.clamp(h / 12, 0.5, 1.5) }))
	end
	if look.mist then
		local base = Instance.new("Attachment")
		base.Position = Vector3.new(0, -size.Y * 0.4, 0)
		base.Parent = holder
		VFXKit.attach("Nebbia", base, { color = look.mist, rate = 0.25, scale = math.clamp(h / 10, 0.5, 2.5), light = 0.2 })
	end
	return { holder = holder, crystal = c, size = h }
end

function CrystalFX.start()
	task.spawn(function()
		local zones = workspace:WaitForChild("ZoneATema", 120)
		if not zones then
			return
		end
		local crystals: { [Model]: Crystal } = {}
		local function add(d: Instance)
			if d:IsA("Model") and d.Name == "Cristallo" and not crystals[d] then
				local el = elementOf(d)
				if el then
					crystals[d] = { model = d, element = el, at = d:GetPivot().Position }
				end
			end
		end
		for _, d in zones:GetDescendants() do
			add(d)
		end
		-- con lo streaming i cristalli arrivano (e se ne vanno) mentre ti muovi
		zones.DescendantAdded:Connect(function(d)
			task.defer(add, d)
		end)
		zones.DescendantRemoving:Connect(function(d)
			if d:IsA("Model") then
				crystals[d] = nil
			end
		end)

		local active: { [Model]: Active } = {}
		local list: { Active } = {}
		local lastSound = 0

		-- accende i vicini e spegne i lontani
		task.spawn(function()
			while true do
				local camera = workspace.CurrentCamera
				local here = camera and camera.CFrame.Position
				if here then
					for m, a in active do
						if not m.Parent or (a.crystal.at - here).Magnitude > FAR then
							a.holder:Destroy()
							active[m] = nil
						end
					end
					local near = {}
					for m, c in crystals do
						if not active[m] then
							local d = (c.at - here).Magnitude
							if d < NEAR then
								table.insert(near, { c = c, d = d })
							end
						end
					end
					table.sort(near, function(a, b)
						return a.d < b.d
					end)
					local count = 0
					for _ in active do
						count += 1
					end
					for _, n in near do
						if count >= MAX_ACTIVE then
							break
						end
						local a = decorate(n.c)
						if a then
							active[n.c.model] = a
							count += 1
						end
					end
					list = {}
					for _, a in active do
						table.insert(list, a)
					end
				end
				task.wait(1)
			end
		end)

		-- ogni tanto qualcosa succede: scariche, vortici, il ghiaccio che scricchiola
		while true do
			task.wait(0.35)
			if #list > 0 then
				local a = list[math.random(1, #list)]
				if a.holder.Parent then
					local look = LOOKS[a.crystal.element]
					local cf = a.holder.CFrame
					local s = a.holder.Size
					local spot = cf:PointToWorldSpace(Vector3.new((math.random() - 0.5) * s.X, (math.random() - 0.2) * s.Y * 0.6, (math.random() - 0.5) * s.Z))
					local camera = workspace.CurrentCamera
					local close = camera and (camera.CFrame.Position - spot).Magnitude < 45
					if look.arcs and math.random() < 0.6 then
						VFXKit.burst("Fulmine", spot, { color = look.arcs, scale = math.clamp(a.size / 25, 0.25, 0.9) })
						if close and os.clock() - lastSound > 1.5 then
							lastSound = os.clock()
							Sfx.play("CristalloScarica", spot)
						end
					elseif look.swirl and math.random() < 0.35 then
						VFXKit.burst("Vortice", cf.Position + Vector3.new(0, s.Y * 0.5, 0), { color = look.swirl, scale = math.clamp(a.size / 30, 0.25, 0.8) })
					elseif look.crackle and close and math.random() < 0.08 and os.clock() - lastSound > 4 then
						lastSound = os.clock()
						Sfx.play("CristalloGelo", spot)
					end
				end
			end
		end
	end)
end

return CrystalFX
