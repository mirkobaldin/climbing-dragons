--!strict
-- Sopravvivenza: danni da caduta, causa della morte e rinascita.
--   * il client segnala l'atterraggio (velocita' e metri di caduta): il server toglie salute
--     (niente danni se atterri in acqua o se la corda ti ha fermato)
--   * ogni danno registra la causa (attributo "DamageCause"): la schermata di morte la mostra
--   * "Respawn" dalla schermata di morte; "Soccorso alpino" (Robux) ti fa rinascere dove sei caduto

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)

local Survival = {}

-- scudo di ghiaccio (lo imposta Upgrades): restituisce il danno che resta dopo lo scudo
Survival.absorb = nil :: ((Player, number) -> number)?

local SAFE_SPEED = 78 -- sotto questa velocita' d'impatto non ti fai niente (~15 studs di caduta)
local DAMAGE_PER_SPEED = 0.72 -- mortale da ~120 studs (prima ~90)

function Survival.setCause(player: Player, cause: string)
	player:SetAttribute("DamageCause", cause)
	player:SetAttribute("DamageCauseTime", os.clock())
end

-- Danno con la causa (usato anche da freddo, frane, valanghe)
function Survival.damage(humanoid: Humanoid, amount: number, cause: string)
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	if player then
		Survival.setCause(player, cause)
		if Survival.absorb then
			amount = (Survival.absorb :: any)(player, amount)
		end
	end
	if amount <= 0 then
		return
	end
	humanoid:TakeDamage(amount)
end

local function onFall(player: Player, speed: any, meters: any)
	if type(speed) ~= "number" or type(meters) ~= "number" or speed ~= speed then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	speed = math.clamp(speed, 0, 500)
	local dmg = (speed - SAFE_SPEED) * DAMAGE_PER_SPEED
	if DragonConfig.hasAbility(player, "Ombra") then
		dmg *= 0.5 -- il drago Ombra attutisce le cadute
	end
	-- esoscheletro: meno danni (la Picchiata che li annullava e' stata tolta)
	dmg *= 1 - UpgradeConfig.value(player, "Esoscheletro", "fall")
	if dmg > 0 then
		Survival.damage(humanoid, dmg, string.format("Fell %d meters", math.floor(math.clamp(meters, 0, 5000))))
	end
end

function Survival.setup()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fall = Instance.new("RemoteEvent")
	fall.Name = "FallDamage"
	fall.Parent = remotes
	fall.OnServerEvent:Connect(onFall)

	local respawn = Instance.new("RemoteEvent")
	respawn.Name = "Respawn"
	respawn.Parent = remotes
	respawn.OnServerEvent:Connect(function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			player:LoadCharacter()
		end
	end)

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local maxY = 0
		local born = os.clock()
		-- vita nuova: niente causa della morte di prima (client/DeathScreen la mostrerebbe ancora)
		player:SetAttribute("DeathCause", nil)
		local lastY = 0
		humanoid.Died:Connect(function()
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local recent = os.clock() - ((player:GetAttribute("DamageCauseTime") or 0) :: number) < 8
			-- caduto fuori dalla mappa: il corpo sparisce sotto FallenPartsDestroyHeight
			local y = if root and root.Parent then root.Position.Y else lastY
			local void = not root or not root.Parent or y < workspace.FallenPartsDestroyHeight + 60
			-- causa vera se c'e' (danno recente), "Fell into the void" fuori mappa, altrimenti
			-- un testo neutro (prima diceva sempre "Exhaustion")
			local cause = if recent then player:GetAttribute("DamageCause") elseif void then "Fell into the void" else "You died"
			player:SetAttribute("DeathCause", cause)
			player:SetAttribute("DeathStats", string.format("%d|%d", math.floor(maxY), math.floor(os.clock() - born)))
			if root then
				player:SetAttribute("DeathPosition", root.Position)
			end
		end)
		task.spawn(function()
			-- CharacterAdded arriva prima che il personaggio sia nel Workspace: senza attesa il
			-- ciclo finiva subito e la quota della schermata di morte era sempre 0
			local t0 = os.clock()
			while not character.Parent and os.clock() - t0 < 10 do
				task.wait(0.1)
			end
			while character.Parent and humanoid.Health > 0 do
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					maxY = math.max(maxY, root.Position.Y - 20)
					lastY = root.Position.Y
				end
				task.wait(1)
			end
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return Survival
