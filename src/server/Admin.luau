--!strict
-- Comandi admin: si aprono con il tasto ; (o F2) e si scrivono nella barra in basso.
-- Solo per gli admin: in Studio tutti, nel gioco pubblicato il proprietario (o il
-- proprietario del gruppo) e gli UserId in DragonConfig.ADMINS. Il server controlla sempre.
-- Il proprietario puo' dare la modalita' admin ad altri giocatori ("admin <nome>", salvato nel
-- DataStore "AdminConcessi") e ogni admin puo' fare un comando per un altro ("to <nome> fly").
-- I comandi di movimento (fly, noclip) li esegue il client, ma solo dopo il si' del server.

local DataStoreService = game:GetService("DataStoreService")

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
local Missions = require(script.Parent.Missions)
local Weather = require(script.Parent.Weather)
local TrailerProps = require(script.Parent.TrailerProps)
local Preflight = require(script.Parent.Preflight)
local WorldEvents = require(script.Parent.WorldEvents)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)

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
missions <reset|skip>  le missioni dopo il tutorial
evento [meteore|drago|valanga]   evento della mappa vicino a te (senza nome: a caso)
regista                modalita' regista per le clip (J/L inquadratura, Y righe 9:16, H HUD)
sfilata                gli 8 draghi adulti in fila che ruggiscono (clip "vota ogni drago")
shiny                  la prossima schiusa e' SHINY (clip della schiusa)
upmax / upreset        tutti i potenziamenti al massimo / a zero
materiali <n>          n di ogni drop dei nemici (pelliccia, cristallo di ghiaccio, nucleo)
admin <nome> / unadmin <nome>   dai o togli la modalita' admin a un giocatore (resta salvata)
admins                 chi ha la modalita' admin
to <nome> <comando>    il comando per un altro giocatore: to Luca fly, to Luca coins 5000,
                       to Luca dragon Gelo Raro, to Luca clip12, to Luca god
uscita                 cosa manca per pubblicare il gioco
cinematica             scena da trailer: strapiombo, uovo e caduta
tiktok                 scenetta: il rampino aggancia un drago
trailer                trailer di 19 s (montagna, draghi, grotte, gas, addestramento, evoluzione)
clip1 / clip2 / clip3  clip per TikTok: evoluzione Eclissi, grotta di ghiaccio, valle dei gas
clip4 / clip5 / clip6  clip senza scritte: boss Titano, giro delle zone dei draghi, volo del drago
clip7 ... clip11       giro della mappa, una sola mappa, rampino, gas, giorno 1 / giorno 30
clip12 clip13 clip15   palestra, drago contro cristalli, case (clip14 tolta)
clip16                 lancio della piccozza al Titano in terza persona coi 3 draghi
clip17                 sopra le nuvole: isole volanti, rampino da un'isola all'altra, drago
clip18                 ogni cristallo, ogni bioma (uno per elemento, dal basso alla vetta)
clip19                 tre piccozze una dopo l'altra, l'ultima rompe il cristallo
clip20                 dall'uovo al drago: machiya, altare del tempio di notte, schiusa, alba
help]]

-- admin "veri" (possono dare la modalita' admin agli altri)
local function isOwner(player: Player): boolean
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

-- giocatori a cui il proprietario ha dato la modalita' admin (UserId -> nome)
local granted: { [number]: string } = {}
local grantStore: DataStore? = nil

local function saveGranted()
	local list = {}
	for id, name in granted do
		table.insert(list, { id = id, name = name })
	end
	task.spawn(function()
		if grantStore then
			pcall(function()
				(grantStore :: DataStore):SetAsync("utenti", list)
			end)
		end
	end)
end

local function isAdmin(player: Player): boolean
	return isOwner(player) or granted[player.UserId] ~= nil
end

-- giocatore dal nome (anche solo l'inizio, nome o nome visualizzato)
local function findPlayer(name: string?): Player?
	if not name or name == "" then
		return nil
	end
	local lower = string.lower(name)
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
			return p
		end
	end
	for _, p in Players:GetPlayers() do
		if string.sub(string.lower(p.Name), 1, #lower) == lower or string.sub(string.lower(p.DisplayName), 1, #lower) == lower then
			return p
		end
	end
	return nil
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

local function splitArgs(text: string): { string }
	local args = string.split(string.gsub(text, "^[;:/]", ""), " ")
	for k = #args, 1, -1 do
		if args[k] == "" then
			table.remove(args, k)
		end
	end
	return args
end

-- Esegue un comando per "player" (chi lo scrive, o il giocatore scelto con "to");
-- restituisce (ok, messaggio, azione per il client di "player")
local function exec(player: Player, args: { string }): (boolean, string, string?)
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
	elseif cmd == "trailer" or (string.match(cmd, "^clip%d+$") and (tonumber(string.sub(cmd, 5)) or 99) <= 20) then
		local take = TrailerProps.prepare()
		-- mentre giri la clip i nemici ti ignorano (il personaggio nascosto segue la camera)
		player:SetAttribute("Filming", true)
		task.delay(120, function()
			if player.Parent then
				player:SetAttribute("Filming", nil)
			end
		end)
		return true, "Ciak! (" .. cmd .. ")", "trailer " .. cmd .. " " .. take
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
			return false, "No character", nil
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
			return false, "No character", nil
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
	elseif cmd == "uscita" then
		local lines = Preflight.report()
		return true, table.concat(lines, "\n"), nil
	elseif cmd == "tutorial" then
		if args[2] == "skip" then
			player:SetAttribute("TutorialStep", Tutorial.STEP_COUNT + 1)
			player:SetAttribute("TutorialText", nil)
		else
			Tutorial.reset(player)
		end
		return true, "Tutorial " .. (args[2] or "reset"), nil
	elseif cmd == "regista" then
		return true, "Regista: J/L inquadratura, Y righe 9:16, H HUD (regista di nuovo per uscire)", "regista"
	elseif cmd == "shiny" then
		player:SetAttribute("ForceShiny", true)
		return true, "La prossima schiusa sara' SHINY", nil
	elseif cmd == "sfilata" then
		-- gli 8 draghi adulti in fila davanti a te (per 70 s), la camera li passa uno a uno
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local store = game:GetService("ServerStorage"):FindFirstChild("Draghi")
		if not root or not store then
			return false, "Serve il personaggio e ServerStorage.Draghi", nil
		end
		local old = workspace:FindFirstChild("Sfilata")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Sfilata"
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local side = look:Cross(Vector3.yAxis)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local order = { "Gelo", "Roccia", "Ossa", "Gas", "Tempesta", "Cosmico", "FulmineNero", "Eclissi" }
		for k, el in order do
			local t = store:FindFirstChild("Drago_" .. el .. "_Adulto")
			if t and t:IsA("Model") then
				local m = t:Clone()
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
					elseif d:IsA("LuaSourceContainer") then
						d:Destroy()
					end
				end
				local at = root.Position + look * 80 + side * ((k - 4.5) * 75)
				local hit = workspace:Raycast(at + Vector3.new(0, 300, 0), Vector3.new(0, -800, 0), params)
				local _, size = m:GetBoundingBox()
				local base = (if hit then hit.Position else at) + Vector3.new(0, size.Y / 2, 0)
				m:PivotTo(CFrame.lookAt(base, base - look))
				m:SetAttribute("AnimKey", m.Name)
				m:SetAttribute("Order", k)
				m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
				m.Parent = folder
			end
		end
		folder.Parent = workspace
		task.delay(70, function()
			folder:Destroy()
		end)
		return true, "Sfilata dei draghi adulti", "sfilata"
	elseif cmd == "evento" then
		return true, WorldEvents.run(args[2], player), nil
	elseif cmd == "upmax" or cmd == "upreset" then
		for _, u in UpgradeConfig.UPGRADES do
			player:SetAttribute("Up_" .. u.id, if cmd == "upmax" then u.max else 0)
		end
		player:SetAttribute("Shield", UpgradeConfig.value(player, "Scudo", "hp"))
		return true, if cmd == "upmax" then "Potenziamenti al massimo" else "Potenziamenti a zero", nil
	elseif cmd == "materiali" then
		local n = tonumber(args[2]) or 10
		local f = player:FindFirstChild("Materiali") or Instance.new("Folder")
		f.Name = "Materiali"
		f.Parent = player
		for _, name in { "Pelliccia_Yeti", "Cristallo_Ghiaccio", "Nucleo_Glaciale" } do
			local v = f:FindFirstChild(name) :: IntValue?
			if not v then
				local nv = Instance.new("IntValue")
				nv.Name = name
				nv.Parent = f
				v = nv
			end
			(v :: IntValue).Value += n
		end
		return true, "Materiali +" .. n, nil
	elseif cmd == "missions" then
		if args[2] == "skip" then
			player:SetAttribute("MissionStep", ((player:GetAttribute("MissionStep") or 1) :: number) + 1)
		else
			Missions.reset(player)
		end
		return true, "Missions " .. (args[2] or "reset"), nil
	end
	return false, "Comando sconosciuto (scrivi help)", nil
end

local actionEvent: RemoteEvent? = nil

local function run(player: Player, text: any): (boolean, string, string?)
	if not isAdmin(player) then
		return false, "Non sei admin", nil
	end
	if type(text) ~= "string" then
		return false, "Comando vuoto", nil
	end
	local args = splitArgs(text)
	local cmd = string.lower(args[1] or "")
	if cmd == "admin" or cmd == "unadmin" then
		if not isOwner(player) then
			return false, "Solo il proprietario puo' dare la modalita' admin", nil
		end
		local target = findPlayer(args[2])
		if not target then
			return false, "Giocatore non trovato (uso: " .. cmd .. " <nome>)", nil
		end
		if cmd == "admin" then
			granted[target.UserId] = target.Name
		else
			granted[target.UserId] = nil
		end
		saveGranted()
		target:SetAttribute("IsAdmin", isAdmin(target))
		return true, (if cmd == "admin" then "Modalita' admin data a " else "Modalita' admin tolta a ") .. target.Name, nil
	elseif cmd == "admins" then
		local names = {}
		for _, name in granted do
			table.insert(names, name)
		end
		table.sort(names)
		return true, if #names > 0 then "Admin dati: " .. table.concat(names, ", ") else "Nessun admin dato (oltre al proprietario)", nil
	elseif cmd == "to" then
		local target = findPlayer(args[2])
		if not target then
			return false, "Giocatore non trovato (uso: to <nome> <comando>)", nil
		end
		local rest = table.move(args, 3, #args, 1, {})
		local sub = string.lower(rest[1] or "")
		if sub == "" or sub == "to" or sub == "admin" or sub == "unadmin" or sub == "admins" or sub == "help" or sub == "uscita" then
			return false, "Uso: to <nome> <comando>", nil
		end
		local ok, message, action = exec(target, rest)
		-- l'azione (volo, noclip, clip...) la fa il client dell'altro giocatore
		if ok and action and actionEvent then
			(actionEvent :: RemoteEvent):FireClient(target, action, player.Name .. ": " .. table.concat(rest, " "))
		end
		return ok, "[" .. target.Name .. "] " .. message, nil
	end
	return exec(player, args)
end

function Admin.setup()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fn = Instance.new("RemoteFunction")
	fn.Name = "AdminCommand"
	fn.Parent = remotes
	fn.OnServerInvoke = run
	local ev = Instance.new("RemoteEvent")
	ev.Name = "AdminAction"
	ev.Parent = remotes
	actionEvent = ev
	local function onPlayer(player: Player)
		player:SetAttribute("IsAdmin", isAdmin(player))
	end
	-- chi ha avuto la modalita' admin nelle partite prima
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("AdminConcessi")
	end)
	if ok then
		grantStore = store
		task.spawn(function()
			local okGet, list = pcall(function()
				return store:GetAsync("utenti")
			end)
			if okGet and type(list) == "table" then
				for _, e in list do
					if type(e) == "table" and type(e.id) == "number" then
						granted[e.id] = tostring(e.name)
					end
				end
				for _, p in Players:GetPlayers() do
					onPlayer(p)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return Admin
