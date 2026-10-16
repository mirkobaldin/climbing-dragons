--!strict
-- Missioni dopo il tutorial: un obiettivo alla volta, come il tutorial (pannello in alto a
-- sinistra con l'attributo "MissionText"), con le frecce guida sul terreno e un segnale col
-- nome e la distanza sopra la meta (attributi "GuideTarget" e "GuideLabel", client/Guide).
-- Il passo e' l'attributo "MissionStep" del giocatore (salvato da Progression).
-- Servono perche' uova e grotte sono difficili da trovare: la freccia porta all'uovo piu'
-- vicino, poi al nido, all'arena, alla palestra, alla grotta coi minerali e in vetta.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = require(script.Parent.Tutorial)
local Economy = require(script.Parent.Economy)

local Missions = {}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

type Memo = { [string]: any }
type Mission = {
	text: string,
	label: string, -- scritta sopra la meta
	check: (Player, Memo) -> boolean,
	target: (Player, Memo) -> Vector3?,
	reward: number, -- monete
}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(player: Player, target: Vector3?, radius: number): boolean
	local root = rootOf(player)
	return root ~= nil and target ~= nil and (root.Position - (target :: Vector3)).Magnitude < radius
end

-- l'attributo e' salito rispetto a quando e' cominciata la missione (di almeno "by")
local function grew(name: string, by: number?): (Player, Memo) -> boolean
	return function(player, memo)
		local value = (player:GetAttribute(name) or 0) :: number
		local key = "base_" .. name
		if memo[key] == nil then
			memo[key] = value
		end
		-- avanzamento per il riquadro della missione ("3/5"), attributo MissionProgress
		memo.progress = string.format("%d/%d", math.clamp(value - memo[key], 0, by or 1), by or 1)
		return value >= memo[key] + (by or 1)
	end
end

local function playerVec(name: string): (Player, Memo) -> Vector3?
	return function(player)
		local v = player:GetAttribute(name)
		return if typeof(v) == "Vector3" then v else nil
	end
end

local function worldVec(name: string): (Player, Memo) -> Vector3?
	return function()
		local v = workspace:GetAttribute(name)
		return if typeof(v) == "Vector3" then v else nil
	end
end

local function marker(name: string): Vector3?
	local markers = workspace:FindFirstChild("MapMarkers")
	local m = markers and markers:FindFirstChild(name, true)
	return if m and m:IsA("BasePart") then m.Position else nil
end

-- la cosa piu' vicina al giocatore in una lista di posizioni
local function nearest(player: Player, list: { Vector3 }): Vector3?
	local root = rootOf(player)
	if not root then
		return list[1]
	end
	local best, bestD = nil, math.huge
	for _, p in list do
		local d = (p - root.Position).Magnitude
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best
end

-- uovo selvatico piu' vicino (workspace.Eggs)
local function wildEgg(player: Player): Vector3?
	local eggs = workspace:FindFirstChild("Eggs")
	local list = {}
	for _, e in (if eggs then eggs:GetChildren() else {}) :: { Instance } do
		if e:IsA("Model") then
			table.insert(list, e:GetPivot().Position)
		elseif e:IsA("BasePart") then
			table.insert(list, e.Position)
		end
	end
	return nearest(player, list)
end

-- giacimento nelle grotte piu' vicino che ha ancora minerale
local function caveOre(player: Player): Vector3?
	local list = {}
	for _, node in CollectionService:GetTagged("OreNode") do
		if node:IsDescendantOf(workspace) and ((node:GetAttribute("Amount") or 1) :: number) > 0 then
			local p = if node:IsA("Model") then node:GetPivot().Position elseif node:IsA("BasePart") then node.Position else nil
			if p then
				table.insert(list, p)
			end
		end
	end
	local ore = nearest(player, list)
	local root = rootOf(player)
	if not ore or not root then
		return ore
	end
	-- gia' sottoterra (roccia sopra la testa): dritto al minerale
	local up = workspace:Raycast(root.Position, Vector3.new(0, 80, 0), terrainOnly)
	if up or (ore - root.Position).Magnitude < 200 then
		return ore
	end
	-- fuori e lontano: prima l'ingresso di grotta piu' vicino (la freccia non passa nella roccia)
	local entrances = {}
	local markers = workspace:FindFirstChild("MapMarkers")
	for _, m in (if markers then markers:GetDescendants() else {}) :: { Instance } do
		if m:IsA("BasePart") and string.find(m.Name, "^CaveEntrance") then
			table.insert(entrances, m.Position)
		end
	end
	return nearest(player, entrances) or ore
end

-- testo = "OBIETTIVO CORTO|aiuto": l'HUD mostra l'obiettivo (★ VERBO...) e l'aiuto solo se il
-- giocatore ci mette un po' (aiuto progressivo, client/HUD)
local MISSIONS: { Mission } = {
	{
		text = "FIND A DRAGON EGG|Follow the arrows to the egg",
		label = "Dragon egg",
		check = function(player, memo)
			return player:GetAttribute("CarryingEgg") ~= nil or grew("EggsIncubated")(player, memo)
		end,
		target = wildEgg,
		reward = 150,
	},
	{
		text = "RETURN THE EGG TO YOUR NEST|Your nest is at your camp",
		label = "Your nest",
		check = grew("EggsIncubated"),
		target = playerVec("NestPosition"),
		reward = 150,
	},
	{
		text = "HATCH YOUR EGG|Open the menu, then Dragons, and tap Hatch {UI:Dragons}",
		label = "Your nest",
		check = grew("EggsHatched"),
		target = playerVec("NestPosition"),
		reward = 300,
	},
	{
		-- la meta e' la pedana davanti all'arena (l'arena e' chiusa: prima la freccia puntava al
		-- centro e il personaggio, rimasto fuori, non la raggiungeva mai)
		text = "GO TO THE DRAGON ARENA|Step on the glowing platform",
		label = "Dragon Arena",
		check = function(player)
			local pad = workspace:GetAttribute("TrainingPad") or workspace:GetAttribute("TrainingCenter")
			return player:GetAttribute("Training") == true or (typeof(pad) == "Vector3" and near(player, pad, 28))
		end,
		target = function()
			local pad = workspace:GetAttribute("TrainingPad") or workspace:GetAttribute("TrainingCenter")
			return if typeof(pad) == "Vector3" then pad else nil
		end,
		reward = 100,
	},
	{
		text = "TRAIN YOUR DRAGON|Stay on the platform and shoot the crystals",
		label = "Platform",
		check = function(player)
			return player:GetAttribute("Training") == true
		end,
		target = function()
			local pad = workspace:GetAttribute("TrainingPad") or workspace:GetAttribute("TrainingCenter")
			return if typeof(pad) == "Vector3" then pad else nil
		end,
		reward = 200,
	},
	{
		text = "GO TO MUSCLE BEACH|Follow the arrows to the gym",
		label = "Gym",
		check = function(player)
			local c = workspace:GetAttribute("GymCenter")
			return typeof(c) == "Vector3" and near(player, c, 70)
		end,
		target = worldVec("GymCenter"),
		reward = 100,
	},
	{
		text = "WORK OUT ONCE|Use any gym machine",
		label = "Gym",
		check = function(player, memo)
			local total = 0
			for _, stat in { "Forza", "Resistenza", "Recupero" } do
				total += ((player:GetAttribute(stat .. "XP") or 0) :: number) + ((player:GetAttribute(stat) or 0) :: number) * 100
			end
			if memo.gym0 == nil then
				memo.gym0 = total
			end
			return total > memo.gym0
		end,
		target = worldVec("GymCenter"),
		reward = 150,
	},
	{
		text = "MINE 5 ORES|Find ore in the caves. {KEY2}",
		label = "Ores",
		check = grew("OresMined", 5),
		target = caveOre,
		reward = 400,
	},
	{
		text = "REACH THE SUMMIT|Keep climbing up the mountain",
		label = "Summit",
		check = function(player)
			return near(player, marker("Summit"), 80)
		end,
		target = function()
			return marker("Summit")
		end,
		reward = 1000,
	},
}

local function publish(player: Player, step: number)
	player:SetAttribute("MissionStep", step)
	local m = MISSIONS[step]
	player:SetAttribute("MissionText", if m then string.format("(%d/%d) %s", step, #MISSIONS, m.text) else nil)
	-- ricompensa e avanzamento mostrati nel riquadro (client/HUD)
	player:SetAttribute("MissionReward", if m then m.reward else nil)
	player:SetAttribute("MissionProgress", nil)
	if not m then
		player:SetAttribute("GuideTarget", nil)
		player:SetAttribute("GuideLabel", nil)
	end
end

local function tutorialDone(player: Player): boolean
	local t = player:GetAttribute("TutorialStep")
	return type(t) == "number" and t > Tutorial.STEP_COUNT
end

local function run(player: Player)
	-- aspetta il salvataggio e la fine del tutorial
	while player.Parent and (player:GetAttribute("MissionStep") == nil or not tutorialDone(player)) do
		task.wait(1)
	end
	local memo: Memo = {}
	local step = player:GetAttribute("MissionStep") :: number
	publish(player, step)
	while player.Parent do
		task.wait(0.5)
		if not tutorialDone(player) then
			-- tutorial ricominciato (admin): le missioni aspettano
			player:SetAttribute("MissionText", nil)
			continue
		end
		local now = player:GetAttribute("MissionStep") :: number
		if now ~= step then
			step = now
			memo = {}
			publish(player, step)
		end
		local m = MISSIONS[step]
		if not m then
			continue
		end
		player:SetAttribute("GuideTarget", m.target(player, memo))
		player:SetAttribute("GuideLabel", m.label)
		local done = m.check(player, memo)
		player:SetAttribute("MissionProgress", memo.progress)
		if done then
			Economy.addCoins(player, m.reward)
			player:SetAttribute("Notice", string.format("Mission complete! +%d coins", m.reward))
			player:SetAttribute("NoticeTime", os.clock())
			step += 1
			memo = {}
			publish(player, step)
		end
	end
end

-- ricomincia le missioni (comando admin)
function Missions.reset(player: Player)
	publish(player, 1)
end

function Missions.setup()
	local skip = Instance.new("RemoteEvent")
	skip.Name = "SkipMission"
	skip.Parent = ReplicatedStorage:WaitForChild("Remotes")
	skip.OnServerEvent:Connect(function(player)
		local step = player:GetAttribute("MissionStep")
		if type(step) == "number" and step <= #MISSIONS then
			publish(player, step + 1)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(run, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(run, player)
	end
end

Missions.COUNT = #MISSIONS

return Missions
