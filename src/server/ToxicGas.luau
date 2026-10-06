--!strict
-- Gas tossici nella valle del drago Gas: chi e' dentro perde salute ogni secondo (piu' si va
-- verso il centro, peggio e'), tranne chi ha un drago Gas al seguito. La zona la scrive il
-- generatore della mappa negli attributi del Workspace: GasCenter, GasRadius, GasTop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Survival = require(script.Parent.Survival)

local ToxicGas = {}

local DAMAGE_PER_SECOND = 5
local NOTICE_EVERY = 6

-- 0 = fuori, 1 = in pieno nel gas (sfuma sull'orlo)
function ToxicGas.amount(pos: Vector3): number
	local center = workspace:GetAttribute("GasCenter")
	local radius = workspace:GetAttribute("GasRadius")
	local top = workspace:GetAttribute("GasTop")
	if typeof(center) ~= "Vector3" or type(radius) ~= "number" or type(top) ~= "number" then
		return 0
	end
	if pos.Y > top then
		return 0
	end
	local d = Vector2.new(pos.X - center.X, pos.Z - center.Z).Magnitude
	return 1 - math.clamp((d - radius * 0.75) / (radius * 0.25), 0, 1)
end

function ToxicGas.setup()
	local lastNotice: { [Player]: number } = {}
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not root or not humanoid or humanoid.Health <= 0 then
					continue
				end
				local k = ToxicGas.amount(root.Position)
				if k > 0.05 and not DragonConfig.hasAbility(player, "Gas") then
					Survival.damage(humanoid, DAMAGE_PER_SECOND * k, "Gas tossici")
					if os.clock() - (lastNotice[player] or 0) > NOTICE_EVERY then
						lastNotice[player] = os.clock()
						player:SetAttribute("Notice", "TOXIC GAS! Get out, or come back with a Gas dragon")
						player:SetAttribute("NoticeTime", os.clock())
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastNotice[player] = nil
	end)
end

return ToxicGas
