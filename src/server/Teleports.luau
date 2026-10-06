--!strict
-- Teletrasporto per chi ha lo Chalet (casa di livello 3, attributo HouseLevel): dal menu del
-- client (tasto T) si va nei punti principali. Il server controlla livello e attesa.
-- La vetta non c'e' apposta: quella si conquista scalando.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Teleports = {}

local COOLDOWN = 20

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
	return {
		["Base camp (hub)"] = function()
			return marker("HubSpawn")
		end,
		["My chalet"] = function(player)
			local p = player:GetAttribute("PlotPosition")
			return if typeof(p) == "Vector3" then p + Vector3.new(0, 0, 8) else nil
		end,
		["Glacier camp"] = function()
			return plotsOf(1)
		end,
		["Dragon village"] = function()
			local c = workspace:GetAttribute("TrainingCenter")
			return if typeof(c) == "Vector3" then c + Vector3.new(0, 0, 70) else nil
		end,
		["Toxic valley (edge)"] = function()
			local c = workspace:GetAttribute("GasCenter")
			local r = workspace:GetAttribute("GasRadius")
			return if typeof(c) == "Vector3" and type(r) == "number" then c + Vector3.new(r * 1.4, 0, 0) else nil
		end,
	}
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
		if ((player:GetAttribute("HouseLevel") or 0) :: number) < 3 then
			player:SetAttribute("Notice", "Teleport unlocks with the Chalet")
			player:SetAttribute("NoticeTime", os.clock())
			return
		end
		local wait = COOLDOWN - (os.clock() - (last[player] or -math.huge))
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
		character:PivotTo(CFrame.new(ground(at)))
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

Teleports.NAMES = { "Base camp (hub)", "My chalet", "Glacier camp", "Dragon village", "Toxic valley (edge)" }

return Teleports
