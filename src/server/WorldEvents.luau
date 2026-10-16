--!strict
-- Eventi della mappa, uno ogni 6-10 minuti vicino a un giocatore a caso:
--   * pioggia di meteore: cadono attorno a lui, fanno male se ti prendono e lasciano meteoriti
--     da raccogliere (minerale Cosmico e Cristallo)
--   * drago selvatico: un drago volante (server/Flyers) gira sopra di lui per 2 minuti e sputa
--     fuoco; se lo abbatti lascia un uovo Epico
--   * grande valanga (solo sopra la linea della neve): tre ondate, chi sopravvive prende monete
-- Annuncio a tutti con "Notice" e l'attributo del Workspace "WorldEvent" (testo) + "WorldEventPos".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local Names = require(ReplicatedStorage.Shared.Names)
local Economy = require(script.Parent.Economy)
local Survival = require(script.Parent.Survival)
local Hazards = require(script.Parent.Hazards)
local Flyers = require(script.Parent.Flyers)
local Progression = require(script.Parent.Progression)

local WorldEvents = {}

local SNOW_ALTITUDE = 1650
local fxEvent: RemoteEvent

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- l'annuncio lo disegna client/EventBanner sotto il Prize Pool (3 s, poi un'etichetta finche'
-- dura): niente piu' "Notice" uguale per tutti, che lo faceva comparire due volte
local function announce(text: string, at: Vector3?, seconds: number)
	workspace:SetAttribute("WorldEvent", text)
	workspace:SetAttribute("WorldEventPos", at)
	workspace:SetAttribute("WorldEventT", workspace:GetServerTimeNow())
	task.delay(seconds, function()
		if workspace:GetAttribute("WorldEvent") == text then
			workspace:SetAttribute("WorldEvent", nil)
			workspace:SetAttribute("WorldEventPos", nil)
		end
	end)
end

local function groundAt(x: number, z: number, fromY: number): Vector3?
	local hit = workspace:Raycast(Vector3.new(x, fromY + 300, z), Vector3.new(0, -800, 0), terrainOnly)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

-- giocatori all'aperto (non in volo come admin, non nel trailer)
local function candidates(minY: number?): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not player:GetAttribute("Filming") and not player:GetAttribute("Training") and root.Position.Y > (minY or -math.huge) then
			table.insert(out, player)
		end
	end
	return out
end

local function rootPos(player: Player): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

------------------------------------------------------------------------------------------
-- Pioggia di meteore

local function meteorite(at: Vector3)
	local rock = Instance.new("Part")
	rock.Name = "Meteorite"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * 3.2
	rock.Material = Enum.Material.CrackedLava
	rock.Color = Color3.fromRGB(120, 60, 200)
	rock.Anchored = true
	rock.CanCollide = false
	rock.Position = at + Vector3.new(0, 1.2, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 120, 255)
	light.Range = 14
	light.Brightness = 2
	light.Parent = rock
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(220, 150, 255))
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(0.6, 1.2)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.LightEmission = 1
	sparkle.Parent = rock
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect"
	prompt.ObjectText = "Meteorite"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = rock
	local taken = false
	prompt.Triggered:Connect(function(player)
		if taken then
			return
		end
		taken = true
		local parts = {}
		for ore, n in UpgradeConfig.EVENTS.METEOR_REWARD do
			Progression.oreValue(player, ore).Value += n
			table.insert(parts, string.format("+%d %s", n, Names.t(ore)))
		end
		Progression.updateTotal(player)
		player:SetAttribute("Notice", "Meteorite: " .. table.concat(parts, ", "))
		player:SetAttribute("NoticeTime", os.clock())
		rock:Destroy()
	end)
	rock.Parent = workspace
	task.delay(150, function()
		if rock.Parent then
			rock:Destroy()
		end
	end)
end

local function meteorShower(player: Player)
	local p = rootPos(player)
	if not p then
		return
	end
	local center = p + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40))
	announce("EVENT: Meteor shower! Collect the meteorites (Cosmic ore)", center, 60)
	task.wait(3)
	for _ = 1, UpgradeConfig.EVENTS.METEORS do
		local a = math.random() * math.pi * 2
		local r = 15 + math.random() * 70
		local ground = groundAt(center.X + math.cos(a) * r, center.Z + math.sin(a) * r, center.Y)
		if ground then
			local sky = ground + Vector3.new(math.random(-80, 80), 260, math.random(-80, 80))
			local fall = 1.6
			fxEvent:FireAllClients("meteor", sky, ground, fall)
			task.delay(fall, function()
				for _, pl in Players:GetPlayers() do
					local character = pl.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if root and humanoid and (root.Position - ground).Magnitude < 12 then
						Survival.damage(humanoid, 25, "Hit by a meteor")
						local away = root.Position - ground
						away = Vector3.new(away.X, 0, away.Z)
						away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
						fxEvent:FireClient(pl, "knock", away * 50 + Vector3.new(0, 35, 0))
					end
				end
				meteorite(ground)
			end)
		end
		task.wait(1.2 + math.random() * 1.5)
	end
end

------------------------------------------------------------------------------------------
-- Drago selvatico

local function dragonRaid(player: Player)
	local p = rootPos(player)
	if not p then
		return
	end
	local ground = groundAt(p.X, p.Z, p.Y) or p
	local f = Flyers.spawnWild(ground)
	if f then
		announce("EVENT: A wild dragon is attacking! Defeat it for an Epic egg", ground, UpgradeConfig.EVENTS.RAID_SECONDS)
	end
end

------------------------------------------------------------------------------------------
-- Grande valanga

local function avalanche(player: Player)
	local p = rootPos(player)
	if not p then
		return
	end
	announce("EVENT: GREAT AVALANCHE! Run sideways or hang on with a piton!", p, 20)
	local started = os.clock()
	task.wait(3)
	if not Hazards.bigAvalanche(p) then
		return
	end
	task.wait(6)
	-- chi era vicino ed e' ancora in piedi senza essere stato travolto: premio
	for _, pl in Players:GetPlayers() do
		local q = rootPos(pl)
		local humanoid = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
		local swept = pl:GetAttribute("DamageCause") == "Swept away by an avalanche" and ((pl:GetAttribute("DamageCauseTime") or 0) :: number) > started
		if q and humanoid and humanoid.Health > 0 and (q - p).Magnitude < 250 and not swept then
			Economy.addCoins(pl, UpgradeConfig.EVENTS.AVALANCHE_REWARD)
			pl:SetAttribute("Notice", string.format("You survived the avalanche! +%d coins", UpgradeConfig.EVENTS.AVALANCHE_REWARD))
			pl:SetAttribute("NoticeTime", os.clock())
		end
	end
end

------------------------------------------------------------------------------------------

-- Lancia un evento subito (anche dal comando admin "evento <meteore|drago|valanga>")
function WorldEvents.run(kind: string?, target: Player?): string
	local list = candidates()
	local player = target or list[math.random(1, math.max(#list, 1))]
	if not player then
		return "Nessun giocatore"
	end
	local p = rootPos(player)
	local choice = kind
	if not choice then
		local options = { "meteore", "drago" }
		if p and p.Y > SNOW_ALTITUDE then
			table.insert(options, "valanga")
		end
		choice = options[math.random(1, #options)]
	end
	if choice == "meteore" then
		task.spawn(meteorShower, player)
	elseif choice == "drago" then
		task.spawn(dragonRaid, player)
	elseif choice == "valanga" then
		task.spawn(avalanche, player)
	else
		return "Evento sconosciuto: meteore, drago, valanga"
	end
	return "Evento " .. choice .. " vicino a " .. player.Name
end

function WorldEvents.setup()
	fxEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EnemyFX") :: RemoteEvent
	task.spawn(function()
		while true do
			task.wait(math.random(UpgradeConfig.EVENTS.EVERY[1], UpgradeConfig.EVENTS.EVERY[2]))
			if #candidates() > 0 then
				local ok, err = pcall(WorldEvents.run, nil, nil)
				if not ok then
					warn("[Eventi] " .. tostring(err))
				end
			end
		end
	end)
end

return WorldEvents
