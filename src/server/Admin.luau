--!strict
-- Comandi admin: si aprono con il tasto ; (o F2) e si scrivono nella barra in basso.
-- Solo per gli admin: in Studio tutti, nel gioco pubblicato il proprietario (o il
-- proprietario del gruppo) e gli UserId in DragonConfig.ADMINS. Il server controlla sempre.
-- I comandi di movimento (fly, noclip) li esegue il client, ma solo dopo il si' del server.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Gear = require(ReplicatedStorage.Shared.Gear)
local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local Dragons = require(script.Parent.Dragons)
local Eggs = require(script.Parent.Eggs)
local Economy = require(script.Parent.Economy)
local Progression = require(script.Parent.Progression)
local Ropes = require(script.Parent.Ropes)
local Tutorial = require(script.Parent.Tutorial)
local Weather = require(script.Parent.Weather)
local TrailerProps = require(script.Parent.TrailerProps)

local Admin = {}

local HELP = [[
fly / unfly            volo (WASD, Spazio su, Ctrl giu', Shift veloce)
noclip / clip          attraversa i muri
speed <n>  jump <n>    velocita' e salto
tp <camp|mountain|summit|skull|tutorial|nome giocatore|x y z>
time <ora>             es. time 21
weather <Clear|Cloudy|Rain|Thunderstorm|Storm|Snow>
give <minerale|all> <n>   es. give Ferro 20
gear <all|Ramponi|Tuta|Rampino|PiccoRinforzato>
egg <elemento> [rarita']  uovo davanti a te
dragon <elemento> [rarita'] [stadio]
hatch                  tutte le uova del nido pronte
coins <n>              monete (anche negative)
house                  compra/migliora la casa gratis
stones <n>             pietre dell'evoluzione
pass <FastIncubation|EggFinder|ExtraDragon|ExtraIncubator>
god / ungod   heal   warm   pitons
tutorial <reset|skip>
cinematica             scena da trailer: strapiombo, uovo e caduta
tiktok                 scenetta: il rampino aggancia un drago
trailer                trailer di 19 s (montagna, draghi, grotte, gas, addestramento, evoluzione)
clip1 / clip2 / clip3  clip per TikTok: evoluzione Eclissi, grotta di ghiaccio, valle dei gas
help]]

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(DragonConfig.ADMINS, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

local function findElement(name: string?): string?
	if not name then
		return nil
	end
	local lower = string.lower(name)
	for _, e in DragonConfig.ELEMENTS do
		if string.lower(e.id) == lower then
			return e.id
		end
	end
	return DragonConfig.elementForName(name)
end

local function findRarity(name: string?): string
	if name then
		for _, r in DragonConfig.RARITIES do
			if string.lower(r.id) == string.lower(name) then
				return r.id
			end
		end
	end
	return "Comune"
end

local function marker(name: string): Vector3?
	local markers = workspace:FindFirstChild("MapMarkers")
	local m = markers and markers:FindFirstChild(name, true)
	if m and m:IsA("BasePart") then
		return m.Position
	end
	return nil
end

local function place(name: string): Vector3?
	name = string.lower(name)
	if name == "camp" or name == "campo" then
		return marker("HubSpawn")
	elseif name == "summit" or name == "vetta" then
		return marker("Summit")
	elseif name == "mountain" or name == "montagna" then
		return marker("PathPoint1")
	elseif name == "skull" or name == "teschio" then
		local skull = workspace:FindFirstChild("Landmarks") and workspace.Landmarks:FindFirstChild("DragonSkull")
		return skull and (skull :: Model):GetPivot().Position
	elseif name == "tutorial" then
		local t = workspace:FindFirstChild("Tutorial")
		local base = t and t:FindFirstChild("WallBase") :: BasePart?
		return base and base.Position
	end
	return nil
end

local function teleport(player: Player, pos: Vector3)
	local character = player.Character
	if character then
		pcall(function()
			player:RequestStreamAroundAsync(pos)
		end)
		character:PivotTo(CFrame.new(pos + Vector3.new(0, 5, 0)))
	end
end

-- Esegue un comando; restituisce (ok, messaggio, azione per il client)
local function run(player: Player, text: any): (boolean, string, string?)
	if not isAdmin(player) then
		return false, "Non sei admin", nil
	end
	if type(text) ~= "string" then
		return false, "Comando vuoto", nil
	end
	local args = string.split(string.gsub(text, "^[;:/]", ""), " ")
	for k = #args, 1, -1 do
		if args[k] == "" then
			table.remove(args, k)
		end
	end
	local cmd = string.lower(args[1] or "")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if cmd == "help" or cmd == "" then
		return true, HELP, nil
	elseif cmd == "fly" or cmd == "unfly" or cmd == "noclip" or cmd == "clip" then
		return true, cmd, cmd
	elseif cmd == "cinematica" then
		return true, "Ciak! (scena da trailer)", "cinematica"
	elseif cmd == "tiktok" then
		return true, "Ciak! (I added a grappling hook...)", "tiktok"
	elseif cmd == "trailer" or cmd == "clip1" or cmd == "clip2" or cmd == "clip3" then
		TrailerProps.prepare()
		return true, "Ciak! (" .. cmd .. ")", "trailer " .. cmd
	elseif cmd == "speed" and humanoid then
		humanoid.WalkSpeed = tonumber(args[2]) or 24
		return true, "Velocita' " .. humanoid.WalkSpeed, "speed " .. humanoid.WalkSpeed
	elseif cmd == "jump" and humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = tonumber(args[2]) or 50
		return true, "Salto " .. humanoid.JumpPower, nil
	elseif cmd == "tp" then
		local target: Vector3? = nil
		if #args >= 4 and tonumber(args[2]) then
			target = Vector3.new(tonumber(args[2]) or 0, tonumber(args[3]) or 0, tonumber(args[4]) or 0)
		elseif args[2] then
			target = place(args[2])
			if not target then
				for _, other in Players:GetPlayers() do
					if string.find(string.lower(other.Name), string.lower(args[2]), 1, true) then
						local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
						target = r and r.Position
					end
				end
			end
		end
		if not target then
			return false, "Posto non trovato", nil
		end
		teleport(player, target :: Vector3)
		return true, "Teletrasportato", nil
	elseif cmd == "time" then
		local h = tonumber(args[2])
		if not h then
			return false, "Uso: time 21", nil
		end
		Lighting.ClockTime = h % 24
		return true, "Ora " .. h, nil
	elseif cmd == "weather" then
		if args[2] and Weather.set(args[2]) then
			return true, "Meteo: " .. args[2], nil
		end
		return false, "Meteo: Clear, Cloudy, Rain, Storm, Snow", nil
	elseif cmd == "give" then
		local amount = tonumber(args[3]) or 10
		local ores = if args[2] and string.lower(args[2]) == "all"
			then { "Carbone", "Ferro", "Oro", "Cristallo", "Rubino", "Cosmico" }
			else { args[2] or "Ferro" }
		for _, ore in ores do
			local name = string.upper(string.sub(ore, 1, 1)) .. string.lower(string.sub(ore, 2))
			Progression.oreValue(player, name).Value += amount
		end
		Progression.updateTotal(player)
		return true, "Dati " .. amount .. " di " .. table.concat(ores, ", "), nil
	elseif cmd == "gear" then
		local which = args[2] or "all"
		for _, r in Gear.RECIPES do
			if string.lower(which) == "all" or string.lower(which) == string.lower(r.id) then
				player:SetAttribute("Gear_" .. r.id, true)
			end
		end
		Progression.giveTools(player)
		return true, "Attrezzi dati", nil
	elseif cmd == "egg" then
		local element = findElement(args[2]) or "Roccia"
		if not root then
			return false, "Nessun personaggio", nil
		end
		Eggs.spawnAt((root :: BasePart).Position + (root :: BasePart).CFrame.LookVector * 6 - Vector3.new(0, 3, 0), element, findRarity(args[3]))
		return true, "Uovo " .. element .. " creato davanti a te", nil
	elseif cmd == "dragon" then
		local element = findElement(args[2]) or "Roccia"
		local d = Dragons.give(player, element, findRarity(args[3]), math.clamp(tonumber(args[4]) or 1, 1, #DragonConfig.STAGES))
		return d ~= nil, if d then "Drago " .. element .. " aggiunto" else "Collezione piena", nil
	elseif cmd == "coins" then
		Economy.addCoins(player, tonumber(args[2]) or 1000)
		return true, "Monete: " .. math.floor(Economy.coins(player)), nil
	elseif cmd == "house" then
		local nextHouse = EconomyConfig.HOUSES[((player:GetAttribute("HouseLevel") or 0) :: number) + 1]
		if not nextHouse then
			return false, "Hai gia' la casa migliore", nil
		end
		Economy.addCoins(player, nextHouse.cost) -- gratis: aggiunge il costo e poi compra
		Economy.upgradeHouse(player)
		return true, "Casa migliorata", nil
	elseif cmd == "hatch" then
		Dragons.finishIncubation(player)
		return true, "Uova del nido pronte (G per schiuderle)", nil
	elseif cmd == "stones" then
		Dragons.addStones(player, tonumber(args[2]) or 3)
		return true, "Pietre dell'evoluzione aggiunte", nil
	elseif cmd == "pass" then
		local name = args[2] or ""
		if DragonConfig.GAMEPASSES[name] == nil then
			return false, "Pass: FastIncubation, EggFinder, ExtraDragon, ExtraIncubator", nil
		end
		player:SetAttribute("Pass_" .. name, true)
		return true, "Pass " .. name .. " attivo (solo per questa sessione)", nil
	elseif cmd == "god" or cmd == "ungod" then
		if not character then
			return false, "Nessun personaggio", nil
		end
		local ff = character:FindFirstChild("AdminGod")
		if cmd == "god" and not ff then
			local f = Instance.new("ForceField")
			f.Name = "AdminGod"
			f.Visible = false
			f.Parent = character
		elseif cmd == "ungod" and ff then
			ff:Destroy()
		end
		return true, cmd, nil
	elseif cmd == "heal" and humanoid then
		humanoid.Health = humanoid.MaxHealth
		return true, "Salute piena", nil
	elseif cmd == "warm" then
		player:SetAttribute("Warmth", 100)
		return true, "Calore pieno", nil
	elseif cmd == "pitons" then
		Ropes.refill(player)
		return true, "Chiodi pieni", nil
	elseif cmd == "tutorial" then
		if args[2] == "skip" then
			player:SetAttribute("TutorialStep", Tutorial.STEP_COUNT + 1)
			player:SetAttribute("TutorialText", nil)
		else
			Tutorial.reset(player)
		end
		return true, "Tutorial " .. (args[2] or "reset"), nil
	end
	return false, "Comando sconosciuto (scrivi help)", nil
end

function Admin.setup()
	local fn = Instance.new("RemoteFunction")
	fn.Name = "AdminCommand"
	fn.Parent = ReplicatedStorage:WaitForChild("Remotes")
	fn.OnServerInvoke = run
	local function onPlayer(player: Player)
		player:SetAttribute("IsAdmin", isAdmin(player))
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return Admin
