--!strict
-- Regali del tempo di gioco (valori in shared/RegaliConfig): all'ingresso si segna l'ora
-- (attributo RegaliInizio), il client mostra il conto alla rovescia e chiede il regalo col
-- RemoteFunction Remotes.Regali ("claim", indice). Il server controlla il tempo vero, che non
-- l'abbia gia' preso e il limite di chiamate (server/Guardia), poi lo da'.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RegaliConfig = require(ReplicatedStorage.Shared.RegaliConfig)
local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)
local Guardia = require(script.Parent.Guardia)
local Economy = require(script.Parent.Economy)
local Dragons = require(script.Parent.Dragons)

local Regali = {}

local function give(player: Player, gift: RegaliConfig.Gift)
	if gift.kind == "Coins" then
		Economy.addCoins(player, gift.amount)
	elseif gift.kind == "Pitons" then
		player:SetAttribute("Pitons", math.min(ClimbConfig.PITONS_MAX, ((player:GetAttribute("Pitons") or 0) :: number) + gift.amount))
	elseif gift.kind == "Stones" then
		Dragons.addStones(player, gift.amount)
	elseif gift.kind == "DragonXp" then
		for _, d in Dragons.equippedDragons(player) do
			Dragons.addXp(player, d.id, gift.amount)
		end
	end
end

local function claim(player: Player, index: any): (boolean, string)
	if type(index) ~= "number" or index ~= math.floor(index) then
		return false, "Invalid request"
	end
	local gift = RegaliConfig.GIFTS[index]
	if not gift then
		return false, "Invalid request"
	end
	local claimed = RegaliConfig.claimed(player)
	if claimed[index] then
		return false, "Already claimed"
	end
	if RegaliConfig.elapsed(player) < gift.minutes * 60 - 1 then
		return false, "Not ready yet"
	end
	claimed[index] = true
	local list = {}
	for i in claimed do
		table.insert(list, tostring(i))
	end
	table.sort(list)
	player:SetAttribute("RegaliPresi", table.concat(list, ","))
	give(player, gift)
	return true, "Gift: " .. gift.text .. "!"
end

function Regali.setup()
	local fn = Instance.new("RemoteFunction")
	fn.Name = "Regali"
	fn.Parent = ReplicatedStorage:WaitForChild("Remotes")
	fn.OnServerInvoke = function(player: Player, action: any, index: any)
		if not Guardia.ok(player, "regali", 4) then
			return false, ""
		end
		if action == "claim" then
			return claim(player, index)
		end
		return false, "Unknown action"
	end
	local function joined(player: Player)
		player:SetAttribute("RegaliInizio", workspace:GetServerTimeNow())
		player:SetAttribute("RegaliPresi", "")
	end
	for _, p in Players:GetPlayers() do
		joined(p)
	end
	Players.PlayerAdded:Connect(joined)
end

return Regali
