--!strict
-- Monta del drago adulto: con la Sella (Gear "Sella", si fa al Banco da lavoro) e un drago
-- adulto al seguito (il primo) si sale in groppa e si vola (client/DragonRide). Qui solo il
-- permesso: l'attributo "Riding" lo vedono tutti i client, che mettono il drago sotto di te
-- (client/PetAnimator).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Dragons = require(script.Parent.Dragons)

local Riding = {}

-- perche' non puoi salire (nil = puoi)
function Riding.reason(player: Player): string?
	if not Gear.has(player, "Sella") then
		return "You need a Dragon Saddle (Crafting, at a workbench)"
	end
	local list = Dragons.equippedDragons(player)
	local d = list[1]
	if not d then
		return "You need a dragon following you (G)"
	end
	if (d.stage or 1) < #DragonConfig.STAGES then
		return "Only an adult dragon can carry you: evolve it first"
	end
	if player:GetAttribute("Training") then
		return "Leave the training arena first"
	end
	return nil
end

function Riding.setup()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "DragonRide"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerEvent:Connect(function(player: Player, on: any)
		if on ~= true then
			player:SetAttribute("Riding", false)
			return
		end
		local why = Riding.reason(player)
		if why then
			player:SetAttribute("Riding", false)
			remote:FireClient(player, why)
			return
		end
		player:SetAttribute("Riding", true)
	end)
	-- se cambia il drago al seguito (o entri nell'arena) si scende
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("Riding") and Riding.reason(player) then
					player:SetAttribute("Riding", false)
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Riding", false)
		end)
	end)
end

return Riding
