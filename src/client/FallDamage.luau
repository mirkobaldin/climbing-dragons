--!strict
-- Danni da caduta: misura la velocita' con cui atterri e i metri di caduta e li manda al
-- server, che toglie salute (il personaggio lo simula il client, quindi e' lui a sapere
-- quando tocca terra). Niente danni se atterri in acqua, se la corda ti ha fermato,
-- mentre scali, voli (admin) o subito dopo il Rampino.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.ClientState)
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local FallDamage = {}

function FallDamage.start()
	local falling = false
	local startY = 0
	local peak = 0
	-- tirato fuori dalla roccia dal server (Unstuck): la caduta dentro la montagna non conta
	player:GetAttributeChangedSignal("Rescued"):Connect(function()
		ClientState.noFallUntil = os.clock() + 2
	end)
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root or humanoid.Health <= 0 then
			falling = false
			return
		end
		local safe = ClientState.climbing or humanoid.PlatformStand or os.clock() < (ClientState.noFallUntil or 0)
		local vy = root.AssemblyLinearVelocity.Y
		local inAir = humanoid.FloorMaterial == Enum.Material.Air
		-- in acqua la caduta non conta
		if safe or humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			falling = false
			return
		end
		if inAir then
			if not falling then
				falling = true
				startY = root.Position.Y
				peak = 0
			end
			peak = math.max(peak, -vy)
			-- la corda ti ha fermato (velocita' tornata bassa a mezz'aria): si riparte da qui
			if peak > 40 and -vy < 8 and root:FindFirstChild("BelayRope") then
				startY = root.Position.Y
				peak = 0
			end
		elseif falling then
			falling = false
			local inWater = humanoid.FloorMaterial == Enum.Material.Water or humanoid:GetState() == Enum.HumanoidStateType.Swimming
			-- picchiata (potenziamento): atterrando veloce fai un'onda d'urto sui nemici; va
			-- mandata prima del danno da caduta, cosi' il server sa se annullarlo
			if not inWater and peak >= UpgradeConfig.PLUNGE_MIN_SPEED and UpgradeConfig.level(player, "Picchiata") >= 1 then
				local plunge = remotes:FindFirstChild("Plunge") :: RemoteEvent?
				if plunge then
					plunge:FireServer(peak)
				end
			end
			if not inWater and peak > 60 then
				local fallDamage = remotes:FindFirstChild("FallDamage") :: RemoteEvent?
				if fallDamage then
					fallDamage:FireServer(peak, startY - root.Position.Y)
				end
			end
		end
	end)
end

return FallDamage
