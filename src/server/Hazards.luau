--!strict
-- Pericoli della montagna (piazzati dal generatore con i tag di CollectionService):
--   CrumblingRock  quando un giocatore ci si aggrappa trema e poi crolla; ricompare dopo un po'
--   RockfallSource ogni tanto fa rotolare un masso verso il sentiero sottostante
-- Eventi della montagna: ogni tanto, vicino a un giocatore che sta salendo (ovunque sia, cosi'
-- chi prova una via diversa dal sentiero li incontra lo stesso), parte una frana di massi o,
-- sopra la linea della neve, una valanga. Avviso 2 secondi prima; chi viene colpito perde
-- salute e viene spinto via (e si stacca dalla parete).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ClimbConfig = require(game:GetService("ReplicatedStorage").Shared.ClimbConfig)
local Players = game:GetService("Players")

local Survival = require(script.Parent.Survival)

local Hazards = {}

local RESPAWN_SECONDS = 25
local EVENT_MIN_SECONDS = 35
local EVENT_MAX_SECONDS = 80
local EVENT_MIN_ALTITUDE = 250
local SNOW_ALTITUDE = 1650
local knockback: RemoteEvent? = nil

local function crumble(rock: BasePart)
	if rock:GetAttribute("Crumbling") then
		return
	end
	rock:SetAttribute("Crumbling", true)
	local original = rock:Clone()
	original:SetAttribute("Crumbling", nil)
	local parent = rock.Parent
	local home = rock.CFrame

	-- Trema per un attimo: il giocatore ha il tempo di reagire
	for _ = 1, 14 do
		rock.CFrame = home * CFrame.new(math.random() * 0.2 - 0.1, math.random() * 0.2 - 0.1, 0)
		task.wait(0.07)
	end

	-- Si spezza in frammenti che cadono
	for _ = 1, 4 do
		local chunk = Instance.new("Part")
		chunk.Size = rock.Size * (0.35 + math.random() * 0.2)
		chunk.CFrame = home * CFrame.new(math.random() * 1.6 - 0.8, math.random() * 1.2 - 0.6, 0)
		chunk.Material = rock.Material
		chunk.Color = rock.Color
		chunk.Parent = workspace
		chunk.AssemblyLinearVelocity = home.LookVector * 6 + Vector3.new(0, -4, 0)
		Debris:AddItem(chunk, 6)
	end
	rock:Destroy()

	task.delay(RESPAWN_SECONDS, function()
		original.Parent = parent
	end)
end

-- Colpo: danno + spinta (la spinta la applica il client, che simula il suo personaggio)
local function hitPlayer(humanoid: Humanoid, push: Vector3, damage: number, cause: string?)
	Survival.damage(humanoid, damage, cause or "Colpito da un masso")
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	if player and knockback then
		(knockback :: RemoteEvent):FireClient(player, push)
	end
end

local function playersNear(position: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude < radius then
			return true
		end
	end
	return false
end

local function launchBoulder(source: BasePart)
	local target = source:GetAttribute("Target")
	if typeof(target) ~= "Vector3" then
		return
	end
	local size = 3 + math.random() * 3
	local boulder = Instance.new("Part")
	boulder.Name = "Boulder"
	boulder.Shape = Enum.PartType.Ball
	boulder.Size = Vector3.one * size
	boulder.Material = Enum.Material.Slate
	boulder.Color = Color3.fromRGB(100, 96, 92)
	boulder.Position = source.Position + Vector3.new(math.random() * 8 - 4, 0, math.random() * 8 - 4)
	boulder.Parent = workspace
	boulder.AssemblyLinearVelocity = (target - boulder.Position).Unit * 25
	-- il rombo della frana viaggia col masso
	local rumble = Instance.new("Sound")
	rumble.SoundId = ClimbConfig.SFX_ROCKFALL
	rumble.Volume = 0.9
	rumble.RollOffMinDistance = 20
	rumble.RollOffMaxDistance = 400
	rumble.PlaybackSpeed = 0.9 + math.random() * 0.2
	rumble.Parent = boulder
	rumble:Play()
	local hit: { [Humanoid]: boolean } = {}
	boulder.Touched:Connect(function(other)
		local humanoid = other.Parent and other.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and not hit[humanoid] and boulder.AssemblyLinearVelocity.Magnitude > 15 then
			hit[humanoid] = true
			hitPlayer(humanoid, boulder.AssemblyLinearVelocity * 0.6, 20)
		end
	end)
	Debris:AddItem(boulder, 15)
end

local function warnNear(position: Vector3, radius: number, text: string)
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude < radius then
			player:SetAttribute("Notice", text)
			player:SetAttribute("NoticeTime", os.clock())
		end
	end
end

-- Palla (masso o neve) che rotola/scivola giu' e colpisce chi tocca
local function rollingBall(position: Vector3, size: number, velocity: Vector3, snow: boolean, damage: number)
	local ball = Instance.new("Part")
	ball.Name = if snow then "Avalanche" else "Boulder"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * size
	ball.Material = if snow then Enum.Material.Snow else Enum.Material.Slate
	ball.Color = if snow then Color3.fromRGB(240, 244, 250) else Color3.fromRGB(100, 96, 92)
	ball.CustomPhysicalProperties = PhysicalProperties.new(if snow then 0.6 else 2.5, 0.3, 0.2)
	ball.Position = position
	ball.Parent = workspace
	ball:SetNetworkOwner(nil)
	ball.AssemblyLinearVelocity = velocity
	if snow then
		local puff = Instance.new("ParticleEmitter")
		puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
		puff.Color = ColorSequence.new(Color3.fromRGB(245, 248, 255))
		puff.Size = NumberSequence.new(size * 0.6, size * 1.4)
		puff.Transparency = NumberSequence.new(0.4, 1)
		puff.Lifetime = NumberRange.new(1, 1.8)
		puff.Rate = 12
		puff.Speed = NumberRange.new(1, 3)
		puff.Parent = ball
	end
	local hit: { [Humanoid]: boolean } = {}
	ball.Touched:Connect(function(other)
		local humanoid = other.Parent and other.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and not hit[humanoid] and ball.AssemblyLinearVelocity.Magnitude > 12 then
			hit[humanoid] = true
			hitPlayer(humanoid, ball.AssemblyLinearVelocity * 0.7 + Vector3.new(0, 20, 0), damage, if snow then "Travolto da una valanga" else "Travolto da una frana")
		end
	end)
	Debris:AddItem(ball, 14)
end

-- Punto a monte del giocatore (verso il centro della montagna e piu' in alto)
local function upslopeOf(position: Vector3): (Vector3?, Vector3)
	local markers = workspace:FindFirstChild("MapMarkers")
	local summit = markers and markers:FindFirstChild("Summit") :: BasePart?
	local center = if summit then summit.Position else Vector3.new(1000, 0, 0)
	local inward = Vector3.new(center.X - position.X, 0, center.Z - position.Z)
	inward = if inward.Magnitude > 1 then inward.Unit else Vector3.xAxis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local origin = position + inward * 45 + Vector3.new(0, 150, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -300, 0), params)
	if hit and hit.Position.Y > position.Y + 10 then
		return hit.Position + Vector3.new(0, 6, 0), -inward
	end
	return nil, -inward
end

local function mountainEvent()
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and root.Position.Y > EVENT_MIN_ALTITUDE then
			table.insert(candidates, root.Position)
		end
	end
	if #candidates == 0 then
		return
	end
	local target = candidates[math.random(1, #candidates)]
	local start, downhill = upslopeOf(target)
	if not start then
		return
	end
	local snow = target.Y > SNOW_ALTITUDE and math.random() < 0.55
	warnNear(target, 160, if snow then "VALANGA! Spostati di lato o pianta un chiodo!" else "FRANA! Massi in arrivo dall'alto!")
	task.wait(2)
	local across = Vector3.new(-downhill.Z, 0, downhill.X)
	local count = if snow then 16 else 7
	for k = 1, count do
		local lateral = (k / count - 0.5) * (if snow then 50 else 24)
		local pos = start + across * lateral + Vector3.new(0, math.random() * 6, 0)
		local speed = if snow then 32 else 24
		rollingBall(pos, if snow then 6 + math.random() * 8 else 3 + math.random() * 5, downhill * speed + Vector3.new(0, -10, 0), snow, if snow then 15 else 25)
		task.wait(if snow then 0.08 else 0.35)
	end
end

function Hazards.setup(remotes: { [string]: RemoteEvent })
	knockback = remotes.Knockback
	task.spawn(function()
		while true do
			task.wait(EVENT_MIN_SECONDS + math.random() * (EVENT_MAX_SECONDS - EVENT_MIN_SECONDS))
			local ok, err = pcall(mountainEvent)
			if not ok then
				warn("[Hazards] " .. tostring(err))
			end
		end
	end)

	remotes.GrabRock.OnServerEvent:Connect(function(player: Player, rock: any)
		if typeof(rock) ~= "Instance" or not rock:IsA("BasePart") or not CollectionService:HasTag(rock, "CrumblingRock") then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - rock.Position).Magnitude < 12 then
			task.spawn(crumble, rock)
		end
	end)

	local function startRockfall(source: Instance)
		if not source:IsA("BasePart") then
			return
		end
		task.spawn(function()
			while source.Parent do
				local interval = source:GetAttribute("Interval") or 12
				task.wait(interval * (0.7 + math.random() * 0.6))
				if playersNear(source.Position, 450) then
					launchBoulder(source)
				end
			end
		end)
	end
	for _, source in CollectionService:GetTagged("RockfallSource") do
		startRockfall(source)
	end
	CollectionService:GetInstanceAddedSignal("RockfallSource"):Connect(startRockfall)
end

return Hazards
