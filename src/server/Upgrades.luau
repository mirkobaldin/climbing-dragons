--!strict
-- Progressione "da combattimento" (vedi shared/UpgradeConfig):
--   * potenziamenti comprati con monete + minerali + drop dei nemici (attributi "Up_<id>")
--   * statistiche (uccisioni, vette, discese...) come attributi del giocatore, salvate
--   * taglie: tre alla volta piu' la sfida del giorno (attributo "BountyData", JSON per il menu)
--   * scudo di ghiaccio: assorbe i danni (aggancio Survival.absorb) e si ricarica
--   * vetta: conta le salite (leaderstats "Summits") e fa partire la discesa a tempo, che finisce
--     al campo base (record personale e classifica di tutti in un OrderedDataStore)
--   * rinascita: monete, minerali e potenziamenti a zero, bonus permanente
-- Il salvataggio lo fa Progression (Upgrades.serialize / Upgrades.load).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local Names = require(ReplicatedStorage.Shared.Names)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Economy = require(script.Parent.Economy)
local Survival = require(script.Parent.Survival)

local Upgrades = {}

-- statistiche salvate (contatori)
-- PlayTime (secondi di gioco) e MaxAltitude (quota piu' alta) servono alla pagina dei record del menu
local STATS = { "Kills", "Kills_Yeti", "Kills_GolemGhiaccio", "BossKills", "Summits", "Descents", "AirHits", "Specials", "MetersClimbed", "DuelTier", "PlayTime", "MaxAltitude" }

type BountySlot = { id: string, need: number, progress: number }
type State = {
	bounties: { BountySlot },
	daily: { day: number, index: number, progress: number, claimed: boolean },
	shield: number,
	lastHurt: number,
	-- discesa a tempo
	atSummit: boolean,
	descentStart: number?,
	lastPos: Vector3?,
	climbY: number?,
}
local states: { [Player]: State } = {}

local recordStore: OrderedDataStore? = nil
local top: { { name: string, seconds: number } } = {}

-- chi arriva in vetta (lo imposta init: il montepremi)
Upgrades.onSummit = nil :: ((Player) -> ())?

local function notice(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

local function today(): number
	return os.time() // 86400
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function marker(name: string): Vector3?
	local markers = workspace:FindFirstChild("MapMarkers")
	local m = markers and markers:FindFirstChild(name, true)
	return if m and m:IsA("BasePart") then m.Position else nil
end

------------------------------------------------------------------------------------------
-- Oggetti: minerali (cartella "Ores") e drop dei nemici (cartella "Materiali")

local function itemValue(player: Player, name: string): IntValue?
	for _, folderName in { "Ores", "Materiali" } do
		local f = player:FindFirstChild(folderName)
		local v = f and f:FindFirstChild(name)
		if v and v:IsA("IntValue") then
			return v
		end
	end
	return nil
end

local function itemCount(player: Player, name: string): number
	local v = itemValue(player, name)
	return if v then v.Value else 0
end

-- totale dei minerali nella classifica (come Progression.updateTotal)
local function updateOreTotal(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	local total = stats and stats:FindFirstChild("Ores") :: IntValue?
	local f = player:FindFirstChild("Ores")
	if total and f then
		local sum = 0
		for _, v in f:GetChildren() do
			if v:IsA("IntValue") then
				sum += v.Value
			end
		end
		total.Value = sum
	end
end

local function itemName(name: string): string
	local icons = ReplicatedStorage:FindFirstChild("DropIcone")
	local nameMap = icons and icons:FindFirstChild("Nomi")
	local shown = nameMap and nameMap:GetAttribute(name)
	return if type(shown) == "string" then shown else Names.t(name)
end

------------------------------------------------------------------------------------------
-- Classifica (leaderstats) e statistiche

local function leaderValue(player: Player, name: string): IntValue
	local stats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local v = stats:FindFirstChild(name) :: IntValue?
	if not v then
		local nv = Instance.new("IntValue")
		nv.Name = name
		nv.Parent = stats
		v = nv
	end
	return v :: IntValue
end

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = {
			bounties = {},
			daily = { day = today(), index = 1, progress = 0, claimed = false },
			shield = 0,
			lastHurt = 0,
			atSummit = false,
		}
		states[player] = s
	end
	return s :: State
end

local function publishBounties(player: Player)
	local s = state(player)
	local list = {}
	for _, b in s.bounties do
		local def = nil
		for _, d in UpgradeConfig.BOUNTIES do
			if d.id == b.id then
				def = d
			end
		end
		if def then
			local reward = def.coins * (if def.stat == "MetersClimbed" or def.stat == "OresMined" then b.need else 1)
			table.insert(list, {
				text = string.format(def.text, b.need),
				progress = math.min(b.progress, b.need),
				need = b.need,
				coins = reward,
				items = def.items,
			})
		end
	end
	local daily = UpgradeConfig.DAILY[s.daily.index]
	player:SetAttribute("BountyData", HttpService:JSONEncode({
		bounties = list,
		daily = daily and {
			text = daily.text,
			progress = math.min(s.daily.progress, daily.need),
			need = daily.need,
			coins = daily.coins,
			claimed = s.daily.claimed,
		},
		resetIn = (today() + 1) * 86400 - os.time(),
	}))
end

local function newBounty(s: State): BountySlot
	-- una taglia diversa da quelle gia' attive
	local pool = {}
	for _, d in UpgradeConfig.BOUNTIES do
		local used = false
		for _, b in s.bounties do
			if b.id == d.id then
				used = true
			end
		end
		if not used then
			table.insert(pool, d)
		end
	end
	local def = pool[math.random(1, math.max(#pool, 1))] or UpgradeConfig.BOUNTIES[1]
	return { id = def.id, need = def.need[math.random(1, #def.need)], progress = 0 }
end

local function checkDaily(player: Player)
	local s = state(player)
	if s.daily.day ~= today() then
		s.daily = { day = today(), index = today() % #UpgradeConfig.DAILY + 1, progress = 0, claimed = false }
	end
end

-- il contatore "stat" e' cresciuto di "amount": avanzano taglie e sfida del giorno
local function progress(player: Player, stat: string, amount: number)
	local s = state(player)
	local changed = false
	for _, b in s.bounties do
		for _, d in UpgradeConfig.BOUNTIES do
			if d.id == b.id and d.stat == stat and b.progress < b.need then
				b.progress = math.min(b.need, b.progress + amount)
				changed = true
				if b.progress >= b.need then
					notice(player, "Bounty complete! Claim it in the menu (U)")
				end
			end
		end
	end
	checkDaily(player)
	local daily = UpgradeConfig.DAILY[s.daily.index]
	if daily and daily.stat == stat and not s.daily.claimed and s.daily.progress < daily.need then
		s.daily.progress = math.min(daily.need, s.daily.progress + amount)
		changed = true
		if s.daily.progress >= daily.need then
			notice(player, "Daily challenge complete! Claim it in the menu (U)")
		end
	end
	if changed then
		publishBounties(player)
	end
end

function Upgrades.addStat(player: Player, stat: string, amount: number?)
	local n = amount or 1
	player:SetAttribute(stat, ((player:GetAttribute(stat) or 0) :: number) + n)
	if stat == "Summits" then
		leaderValue(player, "Summits").Value = (player:GetAttribute("Summits") or 0) :: number
	end
	progress(player, stat, n)
end

------------------------------------------------------------------------------------------
-- Acquisti

local function buy(player: Player, id: string): (boolean, string)
	local u = UpgradeConfig.find(id)
	if not u then
		return false, "Unknown upgrade"
	end
	local level = UpgradeConfig.level(player, id)
	if level >= u.max then
		return false, "Already at max level"
	end
	local cost = u.costs[level + 1]
	if Economy.coins(player) < cost.coins then
		return false, string.format("You need %d coins", cost.coins)
	end
	for name, n in cost.items do
		if itemCount(player, name) < n then
			return false, "You're missing " .. itemName(name)
		end
	end
	Economy.addCoins(player, -cost.coins)
	for name, n in cost.items do
		local v = itemValue(player, name)
		if v then
			v.Value -= n
		end
	end
	updateOreTotal(player)
	player:SetAttribute("Up_" .. id, level + 1)
	if id == "Scudo" then
		state(player).shield = UpgradeConfig.value(player, "Scudo", "hp")
		player:SetAttribute("Shield", state(player).shield)
	end
	return true, string.format("%s level %d!", u.name, level + 1)
end

local function claim(player: Player, index: number): (boolean, string)
	local s = state(player)
	local b = s.bounties[index]
	if not b or b.progress < b.need then
		return false, "Not finished yet"
	end
	for _, d in UpgradeConfig.BOUNTIES do
		if d.id == b.id then
			local coins = d.coins * (if d.stat == "MetersClimbed" or d.stat == "OresMined" then b.need else 1)
			Economy.addCoins(player, coins)
			for name, n in d.items or {} do
				local v = itemValue(player, name)
				if not v then
					local f = player:FindFirstChild("Materiali") or Instance.new("Folder")
					f.Name = "Materiali"
					f.Parent = player
					local nv = Instance.new("IntValue")
					nv.Name = name
					nv.Parent = f
					v = nv
				end
				(v :: IntValue).Value += n
			end
		end
	end
	s.bounties[index] = newBounty(s)
	publishBounties(player)
	return true, "Bounty claimed!"
end

local function claimDaily(player: Player): (boolean, string)
	checkDaily(player)
	local s = state(player)
	local daily = UpgradeConfig.DAILY[s.daily.index]
	if not daily or s.daily.claimed or s.daily.progress < daily.need then
		return false, "Not finished yet"
	end
	s.daily.claimed = true
	Economy.addCoins(player, daily.coins)
	publishBounties(player)
	return true, string.format("Daily challenge: +%d coins", daily.coins)
end

local function rebirth(player: Player): (boolean, string)
	if ((player:GetAttribute("SummitsSinceRebirth") or 0) :: number) < 1 then
		return false, "Reach the summit first"
	end
	local cost = UpgradeConfig.rebirthCost(player)
	if Economy.coins(player) < cost then
		return false, string.format("You need %d coins", cost)
	end
	Economy.addCoins(player, -Economy.coins(player))
	local ores = player:FindFirstChild("Ores")
	for _, v in (if ores then ores:GetChildren() else {}) :: { Instance } do
		if v:IsA("IntValue") then
			v.Value = 0
		end
	end
	updateOreTotal(player)
	for _, u in UpgradeConfig.UPGRADES do
		player:SetAttribute("Up_" .. u.id, 0)
	end
	state(player).shield = 0
	player:SetAttribute("Shield", 0)
	player:SetAttribute("SummitsSinceRebirth", 0)
	local n = ((player:GetAttribute("Rebirths") or 0) :: number) + 1
	player:SetAttribute("Rebirths", n)
	leaderValue(player, "Rebirths").Value = n
	return true, string.format("Rebirth %d! +%d%% coins and dragon XP forever", n, math.floor(n * UpgradeConfig.REBIRTH.COIN_BONUS * 100 + 0.5))
end

------------------------------------------------------------------------------------------
-- Scudo: assorbe i danni prima della salute

local function absorb(player: Player, amount: number): number
	local s = state(player)
	s.lastHurt = os.clock()
	if s.shield <= 0 or amount <= 0 then
		return amount
	end
	local taken = math.min(s.shield, amount)
	s.shield -= taken
	player:SetAttribute("Shield", math.floor(s.shield))
	return amount - taken
end

------------------------------------------------------------------------------------------
-- Discesa a tempo: parte lasciando la vetta, finisce al campo base

local function saveRecord(player: Player, seconds: number)
	local best = player:GetAttribute("BestDescent")
	if type(best) ~= "number" or seconds < best then
		player:SetAttribute("BestDescent", seconds)
		notice(player, string.format("New descent record: %.1f s!", seconds))
	else
		notice(player, string.format("Descent finished in %.1f s (best %.1f s)", seconds, best))
	end
	if recordStore then
		task.spawn(function()
			pcall(function()
				(recordStore :: OrderedDataStore):UpdateAsync(tostring(player.UserId), function(old)
					local ms = math.floor(seconds * 1000)
					if type(old) == "number" and old <= ms then
						return nil
					end
					return ms
				end)
			end)
		end)
	end
end

local function refreshTop()
	if not recordStore then
		return
	end
	local ok, pages = pcall(function()
		return (recordStore :: OrderedDataStore):GetSortedAsync(true, 10)
	end)
	if not ok then
		return
	end
	local list = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local name = "?"
		pcall(function()
			name = Players:GetNameFromUserIdAsync(tonumber(entry.key) or 0)
		end)
		table.insert(list, { name = name, seconds = (entry.value :: number) / 1000 })
	end
	top = list
	workspace:SetAttribute("DescentTop", HttpService:JSONEncode(list))
end

-- un secondo di controlli per ogni giocatore: vetta, discesa, metri saliti, scudo
local function tick(player: Player, dt: number)
	local s = state(player)
	local root = rootOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		if s.descentStart then
			s.descentStart = nil
			player:SetAttribute("DescentStart", nil)
		end
		s.lastPos = nil
		return
	end
	local pos = root.Position
	-- salto enorme in un secondo = teletrasporto: la discesa non vale
	local jumped = s.lastPos ~= nil and (pos - (s.lastPos :: Vector3)).Magnitude > 450
	-- metri saliti (si conta solo la salita, non i teletrasporti)
	if s.lastPos and not jumped then
		local up = pos.Y - (s.lastPos :: Vector3).Y
		if up > 0.5 and up < 40 then
			s.climbY = (s.climbY or 0) + up
			if (s.climbY :: number) >= 1 then
				local whole = math.floor(s.climbY :: number)
				s.climbY = (s.climbY :: number) - whole
				Upgrades.addStat(player, "MetersClimbed", whole)
			end
		end
	end
	s.lastPos = pos

	local summit = marker("Summit")
	if summit then
		local onTop = (pos - summit).Magnitude < 90
		if onTop and not s.atSummit then
			s.atSummit = true
			Upgrades.addStat(player, "Summits")
			player:SetAttribute("SummitsSinceRebirth", ((player:GetAttribute("SummitsSinceRebirth") or 0) :: number) + 1)
			if Upgrades.onSummit then
				task.spawn(Upgrades.onSummit :: any, player) -- montepremi (server/Montepremi)
			end
			notice(player, "You reached the summit! Glide down to the base camp for a timed descent")
			if s.descentStart then
				s.descentStart = nil
				player:SetAttribute("DescentStart", nil)
			end
		elseif not onTop and s.atSummit and pos.Y < summit.Y - 25 then
			-- si parte: la discesa a tempo comincia
			s.atSummit = false
			s.descentStart = os.clock()
			player:SetAttribute("DescentStart", workspace:GetServerTimeNow())
		elseif not onTop and pos.Y < summit.Y - 400 then
			s.atSummit = false
		end
	end
	if s.descentStart then
		local hub = marker("HubSpawn")
		local elapsed = os.clock() - (s.descentStart :: number)
		if jumped or elapsed > 900 then
			s.descentStart = nil
			player:SetAttribute("DescentStart", nil)
		elseif hub and Vector3.new(pos.X - hub.X, 0, pos.Z - hub.Z).Magnitude < 220 and pos.Y < hub.Y + 80 then
			s.descentStart = nil
			player:SetAttribute("DescentStart", nil)
			Upgrades.addStat(player, "Descents")
			saveRecord(player, elapsed)
		end
	end

	-- scudo: si ricarica dopo qualche secondo senza colpi
	local maxShield = UpgradeConfig.value(player, "Scudo", "hp")
	if maxShield > 0 and s.shield < maxShield and os.clock() - s.lastHurt > UpgradeConfig.SHIELD_DELAY then
		s.shield = math.min(maxShield, s.shield + UpgradeConfig.SHIELD_REGEN * dt)
		player:SetAttribute("Shield", math.floor(s.shield))
	end
	player:SetAttribute("ShieldMax", maxShield)
end

------------------------------------------------------------------------------------------
-- Salvataggio (lo chiama Progression)

function Upgrades.serialize(player: Player): any
	local s = states[player]
	if not s then
		return nil
	end
	local levels = {}
	for _, u in UpgradeConfig.UPGRADES do
		levels[u.id] = UpgradeConfig.level(player, u.id)
	end
	local stats = {}
	for _, name in STATS do
		stats[name] = player:GetAttribute(name) or 0
	end
	return {
		levels = levels,
		stats = stats,
		rebirths = player:GetAttribute("Rebirths") or 0,
		sinceRebirth = player:GetAttribute("SummitsSinceRebirth") or 0,
		best = player:GetAttribute("BestDescent"),
		camps = player:GetAttribute("CampsFound"), -- campi base scoperti (teletrasporto)
		bounties = s.bounties,
		daily = s.daily,
	}
end

function Upgrades.load(player: Player, data: any)
	local s = state(player)
	if type(data) == "table" then
		for id, l in data.levels or {} do
			if UpgradeConfig.find(id) then
				player:SetAttribute("Up_" .. id, tonumber(l) or 0)
			end
		end
		for name, v in data.stats or {} do
			if table.find(STATS, name) then
				player:SetAttribute(name, tonumber(v) or 0)
			end
		end
		player:SetAttribute("Rebirths", tonumber(data.rebirths) or 0)
		player:SetAttribute("SummitsSinceRebirth", tonumber(data.sinceRebirth) or 0)
		if type(data.best) == "number" then
			player:SetAttribute("BestDescent", data.best)
		end
		if type(data.camps) == "string" then
			player:SetAttribute("CampsFound", data.camps)
		end
		if type(data.bounties) == "table" then
			for _, b in data.bounties do
				if type(b) == "table" and type(b.id) == "string" and type(b.need) == "number" then
					table.insert(s.bounties, { id = b.id, need = b.need, progress = tonumber(b.progress) or 0 })
				end
			end
		end
		if type(data.daily) == "table" and data.daily.day == today() then
			s.daily = { day = data.daily.day, index = tonumber(data.daily.index) or 1, progress = tonumber(data.daily.progress) or 0, claimed = data.daily.claimed == true }
		end
	end
	checkDaily(player)
	while #s.bounties < 3 do
		table.insert(s.bounties, newBounty(s))
	end
	s.shield = UpgradeConfig.value(player, "Scudo", "hp")
	player:SetAttribute("Shield", s.shield)
	leaderValue(player, "Summits").Value = (player:GetAttribute("Summits") or 0) :: number
	leaderValue(player, "Rebirths").Value = (player:GetAttribute("Rebirths") or 0) :: number
	publishBounties(player)
	player:SetAttribute("UpgradesLoaded", true)
end

------------------------------------------------------------------------------------------

function Upgrades.setup()
	pcall(function()
		-- record della discesa: ripartono da zero col reset del 17/10 (prima "DiscesaRecord")
		recordStore = DataStoreService:GetOrderedDataStore("DiscesaRecord_v2")
	end)
	Survival.absorb = absorb

	local fn = Instance.new("RemoteFunction")
	fn.Name = "Upgrade"
	fn.Parent = ReplicatedStorage:WaitForChild("Remotes")
	fn.OnServerInvoke = function(player: Player, action: any, arg: any): (boolean, string)
		if not player:GetAttribute("UpgradesLoaded") then
			return false, "Loading your save..."
		end
		if action == "buy" and type(arg) == "string" then
			return buy(player, arg)
		elseif action == "claim" and type(arg) == "number" then
			return claim(player, arg)
		elseif action == "daily" then
			return claimDaily(player)
		elseif action == "rebirth" then
			return rebirth(player)
		end
		return false, "Unknown action"
	end

	-- parapendio aperto/chiuso: l'attributo serve agli altri client per disegnare la vela
	local glide = Instance.new("RemoteEvent")
	glide.Name = "Glide"
	glide.Parent = ReplicatedStorage.Remotes
	glide.OnServerEvent:Connect(function(player, on)
		player:SetAttribute("Gliding", on == true and Gear.hasGlider(player))
	end)

	-- gli altri contatori che crescono altrove (minerali, uova) avanzano le taglie
	local function watch(player: Player)
		for _, stat in { "OresMined", "EggsIncubated" } do
			local last = (player:GetAttribute(stat) or 0) :: number
			player:GetAttributeChangedSignal(stat):Connect(function()
				local now = (player:GetAttribute(stat) or 0) :: number
				if now > last then
					progress(player, stat, now - last)
				end
				last = now
			end)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- i dati si tengono ancora qualche secondo: Progression salva all'uscita e prima trovava
		-- gia' tutto cancellato (il 2026-10-13 ha scritto un profilo senza draghi ne' monete)
		task.delay(10, function()
			if not player.Parent then
				states[player] = nil
			end
		end)
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("UpgradesLoaded") then
					local ok, err = pcall(tick, player, dt)
					if not ok then
						warn("[Upgrades] " .. tostring(err))
					end
				end
			end
		end
	end)
	-- tempo di gioco e quota record (pagina dei record del menu), ogni 10 secondi
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("UpgradesLoaded") then
					player:SetAttribute("PlayTime", ((player:GetAttribute("PlayTime") or 0) :: number) + 10)
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						local alt = math.floor(math.max(0, root.Position.Y - 20))
						if alt > ((player:GetAttribute("MaxAltitude") or 0) :: number) then
							player:SetAttribute("MaxAltitude", alt)
						end
					end
				end
			end
		end
	end)
	-- la sfida del giorno cambia a mezzanotte, la classifica delle discese ogni 2 minuti
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if states[player] then
					checkDaily(player)
					publishBounties(player)
				end
			end
			pcall(refreshTop)
			task.wait(120)
		end
	end)
end

Upgrades.top = function()
	return top
end

return Upgrades
