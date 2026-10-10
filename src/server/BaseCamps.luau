--!strict
-- Campi base sulla montagna: ci si accampa (prompt "E"), si riforniscono i chiodi, si
-- recupera la salute e il campo diventa il punto di rinascita (checkpoint).
-- Cartelli di viaggio (tag "TravelPost"): dal campo ai piedi della montagna e ritorno, e
-- dal campo all'ultimo campo base raggiunto (la strada a piedi e' lunga).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Ropes = require(script.Parent.Ropes)

local BaseCamps = {}

-- Punto di rinascita: l'ultimo campo base usato, altrimenti lo spawn della valle
local function spawnPoint(player: Player): Vector3?
	-- "Soccorso alpino" (Robux): una volta sola, dove sei caduto
	local revive = player:GetAttribute("ReviveAt")
	if typeof(revive) == "Vector3" then
		player:SetAttribute("ReviveAt", nil)
		return revive
	end
	local checkpoint = player:GetAttribute("Checkpoint")
	if typeof(checkpoint) == "Vector3" then
		return checkpoint
	end
	local markers = workspace:FindFirstChild("MapMarkers")
	local spawn = markers and markers:FindFirstChild("HubSpawn") :: BasePart?
	return spawn and spawn.Position
end

-- Appoggia il personaggio sul terreno vero sotto il punto (raycast dall'alto), cosi' non
-- puo' mai finire dentro o sotto la mappa
local function teleport(player: Player, character: Model, target: Vector3)
	pcall(function()
		player:RequestStreamAroundAsync(target)
	end)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	-- prima vicino al punto (sui pendii sopra potrebbe esserci un'altra parete), poi dall'alto
	local hit = workspace:Raycast(target + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), params)
		or workspace:Raycast(target + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
	local ground = if hit then hit.Position else target
	character:PivotTo(CFrame.new(ground + Vector3.new(0, 4, 0)))
end

local function onCharacter(player: Player, character: Model)
	local target = spawnPoint(player)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if target and root then
		teleport(player, character, target)
	end
end

local function travelPrompt(parent: Instance, action: string, object: string, onTrigger: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	prompt.Triggered:Connect(onTrigger)
end

local function travelTo(player: Player, target: Vector3?)
	local character = player.Character
	if character and target then
		teleport(player, character, target)
	end
end

local function bindTravelPost(post: Instance)
	if not post:IsA("BasePart") then
		return
	end
	local dest = post:GetAttribute("Target")
	local label = post:GetAttribute("Label") or "Viaggia"
	if typeof(dest) == "Vector3" then
		travelPrompt(post, label, "Cartello", function(player)
			travelTo(player, dest)
		end)
	end
	if post:GetAttribute("LastCamp") then
		travelPrompt(post, "To the last base camp", "Sign", function(player)
			local cp = player:GetAttribute("Checkpoint")
			if typeof(cp) == "Vector3" then
				travelTo(player, cp)
			else
				player:SetAttribute("Notice", "You haven't reached a base camp yet")
				player:SetAttribute("NoticeTime", os.clock())
			end
		end)
	end
end

function BaseCamps.setup()
	local markers = workspace:WaitForChild("MapMarkers", 10)
	local camps = markers and markers:FindFirstChild("BaseCamps")
	if camps then
		for index, marker in camps:GetChildren() do
			if marker:IsA("BasePart") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Camp here"
				prompt.ObjectText = "Base Camp " .. index
				prompt.HoldDuration = 1
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = marker
				prompt.Triggered:Connect(function(player: Player)
					Ropes.refill(player)
					player:SetAttribute("Checkpoint", marker.Position)
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = humanoid.MaxHealth
					end
					player:SetAttribute("Warmth", 100)
				end)
				-- discesa rapida: dal campo base si torna alla valle
				travelPrompt(marker, "Back to camp", "Base Camp " .. index, function(player)
					local markersFolder = workspace:FindFirstChild("MapMarkers")
					local spawn = markersFolder and markersFolder:FindFirstChild("HubSpawn") :: BasePart?
					travelTo(player, spawn and spawn.Position)
				end)
				CollectionService:AddTag(marker, "HeatSource")
			end
		end
	else
		warn("[BaseCamps] MapMarkers.BaseCamps non trovato: genera la mappa con MapGen")
	end


	for _, post in CollectionService:GetTagged("TravelPost") do
		bindTravelPost(post)
	end
	CollectionService:GetInstanceAddedSignal("TravelPost"):Connect(bindTravelPost)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return BaseCamps
