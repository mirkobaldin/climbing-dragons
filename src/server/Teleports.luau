--!strict
-- Teletrasporto (menu T del client) tra i PUNTI DI VIAGGIO: campo base principale, il tuo
-- accampamento, arena, palestra e i campi base della montagna che hai gia' raggiunto a piedi
-- (attributo "CampsFound", es. "1,3,4", salvato da Upgrades). Si parte SOLO stando vicino a un
-- punto di viaggio (attributo "AtWaypoint", lo calcola BaseCamps): prima dalla vetta si tornava
-- giu' in zero secondi. La vetta non c'e' apposta: quella si conquista scalando.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Teleports = {}

local COOLDOWN = 20
local HOME_COOLDOWN = 60 -- "My camp" da lontano

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- punto a terra vicino a p (cerca dall'alto)
local function ground(p: Vector3): Vector3
	local hit = workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -300, 0), terrainOnly)
	return (if hit then hit.Position else p) + Vector3.new(0, 4, 0)
end

-- destinazioni: nome mostrato -> funzione che dice dove (per giocatore)
local function destinations(): { [string]: (Player) -> Vector3? }
	local markers = workspace:FindFirstChild("MapMarkers")
	local function marker(name: string): Vector3?
		local m = markers and markers:FindFirstChild(name, true)
		return if m and m:IsA("BasePart") then m.Position else nil
	end
	local function plotsOf(level: number): Vector3?
		local village = workspace:FindFirstChild("Village")
		local plots = village and village:FindFirstChild("Plots")
		local sum, n = Vector3.zero, 0
		for _, p in (plots and plots:GetChildren() or {}) :: { Instance } do
			if p:IsA("Model") and p:GetAttribute("Level") == level then
				sum += p:GetPivot().Position
				n += 1
			end
		end
		return if n > 0 then sum / n else nil
	end
	local list: { [string]: (Player) -> Vector3? } = {
		["Base camp (hub)"] = function()
			return marker("HubSpawn")
		end,
		["My camp"] = function(player)
			local p = player:GetAttribute("PlotSpawn") or player:GetAttribute("PlotPosition")
			return if typeof(p) == "Vector3" then p else nil
		end,
		["Muscle Beach (gym)"] = function()
			local c = workspace:GetAttribute("GymCenter")
			return if typeof(c) == "Vector3" then c + Vector3.new(0, 0, 30) else nil
		end,
		["Dragon training"] = function()
			-- davanti alla pedana, fuori dall'arena (prima finiva sotto la piattaforma dell'arena)
			local c = workspace:GetAttribute("TrainingCenter")
			local pad = workspace:GetAttribute("TrainingPad")
			if typeof(c) == "Vector3" and typeof(pad) == "Vector3" then
				local away = Vector3.new(pad.X - c.X, 0, pad.Z - c.Z).Unit
				return pad + away * 14
			end
			return nil
		end,
	}
	-- i campi base della montagna (solo quelli scoperti: lo controlla chi chiama)
	local camps = markers and markers:FindFirstChild("BaseCamps")
	for _, c in (if camps then camps:GetChildren() else {}) :: { Instance } do
		local index = tonumber(string.match(c.Name, "%d+"))
		if index and c:IsA("BasePart") then
			list["Base Camp " .. index] = function(player)
				local found = "," .. tostring(player:GetAttribute("CampsFound") or "") .. ","
				return if string.find(found, "," .. index .. ",", 1, true) then (c :: BasePart).Position else nil
			end
		end
	end
	return list
end

function Teleports.setup()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Teleport"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	local last: { [Player]: number } = {}
	remote.OnServerEvent:Connect(function(player: Player, name: any)
		if type(name) ~= "string" then
			return
		end
		local need = Teleports.NEEDS[name]
		local blocked = if need == "dragon" then ((player:GetAttribute("DragonCount") or 0) :: number) < 1
			elseif need == "chalet" then ((player:GetAttribute("HouseLevel") or 0) :: number) < 3
			else false
		if blocked then
			player:SetAttribute("Notice", if need == "dragon" then "Unlocks with your first dragon" else "Unlocks with the Chalet")
			player:SetAttribute("NoticeTime", os.clock())
			return
		end
		-- a casa si torna da qualunque posto (prima trovarla era quasi impossibile), con una
		-- ricarica piu' lunga e non durante la discesa a tempo; il resto solo dai punti di viaggio
		local home = name == "My camp"
		if home and player:GetAttribute("DescentStart") then
			player:SetAttribute("Notice", "Finish your timed descent first")
			player:SetAttribute("NoticeTime", os.clock())
			return
		end
		if not home and not player:GetAttribute("AtWaypoint") then
			player:SetAttribute("Notice", "Teleport only from a base camp, your camp, the arena or the gym")
			player:SetAttribute("NoticeTime", os.clock())
			return
		end
		local wait = (if home and not player:GetAttribute("AtWaypoint") then HOME_COOLDOWN else COOLDOWN) - (os.clock() - (last[player] or -math.huge))
		if wait > 0 then
			player:SetAttribute("Notice", string.format("Teleport ready in %d s", math.ceil(wait)))
			player:SetAttribute("NoticeTime", os.clock())
			return
		end
		local fn = destinations()[name]
		local at = fn and fn(player)
		local character = player.Character
		if not at or not character then
			return
		end
		last[player] = os.clock()
		-- il tuo accampamento: il punto e' gia' a terra (o sulla pedana dello Chalet)
		character:PivotTo(CFrame.new(if name == "My camp" then at + Vector3.new(0, 2, 0) else ground(at)))
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

Teleports.NAMES = { "Base camp (hub)", "My camp", "Dragon training", "Muscle Beach (gym)" }
-- chi puo' andarci: tutti, dal primo drago, con lo Chalet
Teleports.NEEDS = { ["Dragon training"] = "dragon" } :: { [string]: string }

return Teleports
