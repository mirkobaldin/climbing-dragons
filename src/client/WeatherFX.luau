--!strict
-- Effetti del meteo sul client: pioggia, neve (in quota o quando nevica), grandine nelle
-- tempeste, scie di vento, nebbia piu' fitta col brutto tempo. Inoltre:
--   * il vento spinge il personaggio in quota e dentro le WindZone (e stanca sulla parete)
--   * su ghiaccio si scivola: la velocita' cambia lentamente, come senza attrito

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gear"))
local ClimbConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClimbConfig"))
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local WeatherFX = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local PRECIPITATION = { Clear = 0, Cloudy = 0, Rain = 1, Thunderstorm = 1.5, Storm = 2, Snow = 1 }
local FOG = { Clear = 0, Cloudy = 0.03, Rain = 0.07, Thunderstorm = 0.09, Storm = 0.14, Snow = 0.1 }
local LIGHTNING = { Thunderstorm = true, Storm = true }
local SLIPPERY = { [Enum.Material.Ice] = true, [Enum.Material.Glacier] = true }

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 0
	e.LightInfluence = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Fulmine: una saetta a zigzag dal cielo al terreno, a qualche centinaio di studs, con il lampo
-- che illumina tutto e il tuono che arriva dopo (prima si vede, poi si sente)
local flash: ColorCorrectionEffect? = nil
local function lightning(camPos: Vector3)
	local rng = Random.new()
	local a = rng:NextNumber(0, 2 * math.pi)
	local dist = rng:NextNumber(250, 1100)
	local x, z = camPos.X + math.cos(a) * dist, camPos.Z + math.sin(a) * dist
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 6000, z), Vector3.new(0, -7000, 0), params)
	local ground = if hit then hit.Position else Vector3.new(x, camPos.Y - 50, z)
	local top = ground + Vector3.new(rng:NextNumber(-60, 60), rng:NextNumber(650, 900), rng:NextNumber(-60, 60))
	local folder = Instance.new("Folder")
	folder.Name = "Fulmine"
	local function segment(p1: Vector3, p2: Vector3, width: number)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(210, 225, 255)
		p.Size = Vector3.new(width, width, (p2 - p1).Magnitude)
		p.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
		p.Parent = folder
	end
	local steps = 14
	local prev = top
	for k = 1, steps do
		local f = k / steps
		local nextP = top:Lerp(ground, f)
		if k < steps then
			local wiggle = 45 * (1 - f * 0.6)
			nextP += Vector3.new(rng:NextNumber(-wiggle, wiggle), 0, rng:NextNumber(-wiggle, wiggle))
		end
		segment(prev, nextP, 2.2 - f)
		-- qualche ramo laterale
		if k > 2 and k < steps - 2 and rng:NextNumber() < 0.3 then
			local branch = nextP + Vector3.new(rng:NextNumber(-90, 90), -rng:NextNumber(40, 110), rng:NextNumber(-90, 90))
			segment(nextP, branch, 0.8)
		end
		prev = nextP
	end
	local glow = Instance.new("Part")
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Transparency = 1
	glow.Position = ground + Vector3.new(0, 30, 0)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 8
	light.Color = Color3.fromRGB(200, 215, 255)
	light.Parent = glow
	glow.Parent = folder
	folder.Parent = workspace
	-- lampo sullo schermo, piu' forte se il fulmine e' vicino
	if flash then
		local f = flash :: ColorCorrectionEffect
		f.Brightness = 0.55 * (1 - dist / 1500)
		TweenService:Create(f, TweenInfo.new(0.45), { Brightness = 0 }):Play()
	end
	-- la saetta tremola e sparisce
	task.spawn(function()
		task.wait(0.08)
		folder.Parent = nil
		task.wait(0.06)
		folder.Parent = workspace
		task.wait(0.14)
		folder:Destroy()
	end)
	-- il tuono arriva dopo, in base alla distanza
	if ClimbConfig.THUNDER_SOUND ~= "" then
		task.delay(dist / 700, function()
			local sound = Instance.new("Sound")
			sound.SoundId = ClimbConfig.THUNDER_SOUND
			sound.Volume = math.clamp(1.6 - dist / 900, 0.3, 1.5)
			sound.PlaybackSpeed = rng:NextNumber(0.85, 1.05)
			sound.Parent = SoundService
			sound:Play()
			Debris:AddItem(sound, 12)
		end)
	end
end

function WeatherFX.start()
	local lampo = Instance.new("ColorCorrectionEffect")
	lampo.Name = "LampoFulmine"
	lampo.Parent = Lighting
	flash = lampo
	local nextBolt = 0
	-- Una lastra invisibile sopra la telecamera da cui cadono le particelle
	local sky = Instance.new("Part")
	sky.Name = "WeatherEmitter"
	sky.Anchored = true
	sky.CanCollide = false
	sky.CanQuery = false
	sky.CanTouch = false
	sky.Transparency = 1
	sky.Size = Vector3.new(150, 1, 150)
	sky.Parent = workspace.CurrentCamera

	local rain = emitter(sky, {
		Texture = SPARKLE,
		Speed = NumberRange.new(90, 110),
		Lifetime = NumberRange.new(0.6, 0.9),
		Size = NumberSequence.new(0.15),
		Squash = NumberSequence.new(3),
		Transparency = NumberSequence.new(0.35),
		Color = ColorSequence.new(Color3.fromRGB(190, 210, 230)),
	})
	local snow = emitter(sky, {
		Texture = SMOKE,
		Speed = NumberRange.new(8, 14),
		Lifetime = NumberRange.new(4, 6),
		Size = NumberSequence.new(0.35, 0.6),
		SpreadAngle = Vector2.new(25, 25),
		RotSpeed = NumberRange.new(-60, 60),
		Transparency = NumberSequence.new(0.1),
		Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)),
	})
	local hail = emitter(sky, {
		Texture = SPARKLE,
		Speed = NumberRange.new(110, 130),
		Lifetime = NumberRange.new(0.5, 0.7),
		Size = NumberSequence.new(0.35),
		Transparency = NumberSequence.new(0.05),
		Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)),
	})
	local streaks = emitter(sky, {
		Texture = SPARKLE,
		Speed = NumberRange.new(2, 4),
		Lifetime = NumberRange.new(1, 1.5),
		Size = NumberSequence.new(0.25),
		Squash = NumberSequence.new(-3), -- allungate in orizzontale
		Transparency = NumberSequence.new(0.6, 1),
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
	})

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local baseDensity = ClimbConfig.FOG_DENSITY
	local lastHorizontal = Vector3.zero
	local windForce: VectorForce? = nil

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local camPos = camera.CFrame.Position
		sky.CFrame = CFrame.new(camPos + Vector3.new(0, 35, 0))

		local weather = workspace:GetAttribute("Weather") or "Clear"
		local strength = workspace:GetAttribute("WindStrength") or 0
		local direction = workspace:GetAttribute("WindDirection") or Vector3.xAxis
		local high = camPos.Y > ClimbConfig.SNOW_LINE
		local precip = PRECIPITATION[weather] or 0
		local snowing = weather == "Snow" or (high and precip > 0)

		rain.Rate = if snowing then 0 else precip * 450
		snow.Rate = if snowing then precip * 220 else 0
		hail.Rate = if weather == "Storm" then 70 else 0
		-- fulmini nei temporali, ogni 3-10 secondi
		if LIGHTNING[weather] and os.clock() >= nextBolt then
			nextBolt = os.clock() + Random.new():NextNumber(3, 10)
			lightning(camPos)
		end
		streaks.Rate = if strength > 50 and camPos.Y > ClimbConfig.WIND_ALTITUDE then 40 else 0
		local push = direction * strength
		rain.Acceleration = push * 0.3
		snow.Acceleration = push * 0.15
		streaks.Acceleration = push * 1.5

		if atmosphere then
			local target = baseDensity + (FOG[weather] or 0) + (if snowing and high then 0.05 else 0) + ClientState.gas * 0.3
			atmosphere.Density += (target - atmosphere.Density) * math.min(1, dt * 0.5)
		end

		-- Vento e ghiaccio sul personaggio
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			return
		end
		if not windForce or windForce.Parent ~= root then
			local a = root:FindFirstChild("WindAttachment") :: Attachment? or Instance.new("Attachment")
			a.Name = "WindAttachment"
			a.Parent = root
			local vf = Instance.new("VectorForce")
			vf.Attachment0 = a
			vf.RelativeTo = Enum.ActuatorRelativeTo.World
			vf.ApplyAtCenterOfMass = true
			vf.Parent = root
			windForce = vf
		end

		local accel = Vector3.zero
		if root.Position.Y > ClimbConfig.WIND_ALTITUDE then
			accel += push * 0.2 * (root.Position.Y / 3000)
		end
		for _, zone in CollectionService:GetTagged("WindZone") do
			if zone:IsA("BasePart") then
				local rel = zone.CFrame:PointToObjectSpace(root.Position)
				local half = zone.Size / 2
				if math.abs(rel.X) < half.X and math.abs(rel.Y) < half.Y and math.abs(rel.Z) < half.Z then
					accel += (zone:GetAttribute("Direction") or Vector3.xAxis) * (zone:GetAttribute("Strength") or 60) * 0.35
				end
			end
		end
		local gust = 0.7 + math.noise(os.clock() * 0.6, 3.1, 0.5) * 0.9 -- raffiche
		accel *= math.max(0, gust)
		if DragonConfig.hasAbility(player, "Tempesta") then
			accel = Vector3.zero -- il drago Tempesta tiene lontano il vento
		end
		;(windForce :: VectorForce).Force = accel * root.AssemblyMass
		ClientState.windFactor = 1 + accel.Magnitude / 60

		-- Ghiaccio: la velocita' orizzontale cambia lentamente (si scivola)
		local v = root.AssemblyLinearVelocity
		local horizontal = Vector3.new(v.X, 0, v.Z)
		if SLIPPERY[humanoid.FloorMaterial] and not ClientState.climbing and not Gear.has(player, "Ramponi") and not DragonConfig.hasAbility(player, "Gelo") then
			local slide = lastHorizontal:Lerp(horizontal, math.min(1, dt * 3))
			root.AssemblyLinearVelocity = Vector3.new(slide.X, v.Y, slide.Z)
			lastHorizontal = slide
		else
			lastHorizontal = horizontal
		end
	end)
end

return WeatherFX
