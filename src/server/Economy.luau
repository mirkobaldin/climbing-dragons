--!strict
-- Economia e case:
--   * Monete (classifica in alto a destra), salvate da Progression
--   * Vendite e acquisti all'emporio: vedi Shop
--   * Terreni (tag "Plot") sulla mezzaluna: ogni giocatore ne riceve uno quando entra; col
--     cartello compri la Tenda (sblocca il nido), poi la migliori in Baita e Chalet
--   * Draghi posati in casa (quelli che non ti seguono): guadagnano monete al minuto, anche
--     mentre sei offline (in parte)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local DragonModels = require(script.Parent.DragonModels)
local Dragons = require(script.Parent.Dragons)

local Economy = {}

type State = { coins: number, house: number, lastSeen: number, plot: Model?, pending: number }

local states: { [Player]: State } = {}
local plotOwner: { [Model]: Player } = {}

local function notice(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = { coins = EconomyConfig.START_COINS, house = 0, lastSeen = os.time(), plot = nil, pending = 0 }
		states[player] = s
	end
	return s
end

local function coinValue(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild("Monete")
	if not v and stats then
		local nv = Instance.new("IntValue")
		nv.Name = "Monete"
		nv.Parent = stats
		v = nv
	end
	return v :: IntValue?
end

local function publish(player: Player)
	local s = state(player)
	local v = coinValue(player)
	if v then
		v.Value = math.floor(s.coins)
	end
	player:SetAttribute("Coins", math.floor(s.coins))
	player:SetAttribute("HouseLevel", s.house)
	local house = EconomyConfig.HOUSES[s.house]
	player:SetAttribute("NestSlots", if house then house.nest else 0)
	player:SetAttribute("RoostSlots", if house then house.roost else 0)
end

function Economy.addCoins(player: Player, amount: number)
	local s = state(player)
	s.coins = math.max(0, s.coins + amount)
	publish(player)
end

function Economy.coins(player: Player): number
	return state(player).coins
end

------------------------------------------------------------------------------------------
-- Draghi posati in casa (guadagno AFK)

local function roosting(player: Player): { any }
	local ds = Dragons.state(player)
	local list = {}
	for _, d in ds.dragons do
		if not table.find(ds.equipped, d.id) then
			table.insert(list, d)
		end
	end
	table.sort(list, function(a, b)
		return (EconomyConfig.ROOST_RATE[a.rarity] or 1) * a.stage > (EconomyConfig.ROOST_RATE[b.rarity] or 1) * b.stage
	end)
	local slots = (player:GetAttribute("RoostSlots") or 0) :: number
	local out = {}
	for k = 1, math.min(slots, #list) do
		table.insert(out, list[k])
	end
	return out
end

local function ratePerMinute(player: Player): number
	local rate = 0
	for _, d in roosting(player) do
		rate += (EconomyConfig.ROOST_RATE[d.rarity] or 1) * d.stage
	end
	return rate
end

-- I draghi posati si vedono sopra la casa (fermi a mezz'aria, girati verso la valle)
local function refreshRoost(player: Player)
	local s = state(player)
	local plot = s.plot
	if not plot then
		return
	end
	local old = plot:FindFirstChild("Roost")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Roost"
	local anchor = plot:GetPivot()
	for k, d in roosting(player) do
		local model = DragonModels.dragon(d.element, d.rarity, d.stage)
		local a = (k - 1) / 6 * math.pi * 2
		model:PivotTo(anchor * CFrame.new(math.cos(a) * 12, 16 + (k % 2) * 3, math.sin(a) * 12 - 4))
		model.Parent = folder
	end
	folder.Parent = plot
	player:SetAttribute("RoostRate", ratePerMinute(player))
end

------------------------------------------------------------------------------------------
-- Terreni e case

local function plotSign(plot: Model): TextLabel?
	local sign = plot:FindFirstChild("PlotSign", true)
	local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	return gui and gui:FindFirstChild("Owner") :: TextLabel?
end

local function buildHouse(player: Player)
	local s = state(player)
	local plot = s.plot
	if not plot then
		return
	end
	local old = plot:FindFirstChild("House")
	if old then
		old:Destroy()
	end
	local house = EconomyConfig.HOUSES[s.house]
	local sign = plotSign(plot)
	if sign then
		local nextHouse = EconomyConfig.HOUSES[s.house + 1]
		sign.Text = player.DisplayName .. (if nextHouse then string.format("\n%s: %d monete", nextHouse.name, nextHouse.cost) else "")
	end
	player:SetAttribute("NestPosition", nil)
	if not house then
		return
	end
	local templates = ServerStorage:FindFirstChild("PlotBuildings")
	local template = templates and templates:FindFirstChild(house.name)
	if not template then
		warn("[Economy] Manca ServerStorage.PlotBuildings." .. house.name .. ": rigenera la mappa")
		return
	end
	local model = template:Clone() :: Model
	model.Name = "House"
	model:PivotTo(plot:GetPivot())
	for _, d in model:GetDescendants() do
		if CollectionService:HasTag(d, "Incubator") and d:IsA("BasePart") then
			d:SetAttribute("Owner", player.UserId)
			player:SetAttribute("NestPosition", d.Position)
			local prompt = d:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.ObjectText = "Nido di " .. player.DisplayName
			end
		end
	end
	model.Parent = plot
end

local function assignPlot(player: Player)
	local s = state(player)
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and not plotOwner[plot] then
			plotOwner[plot] = player
			s.plot = plot
			player:SetAttribute("PlotPosition", plot:GetPivot().Position)
			buildHouse(player)
			refreshRoost(player)
			return
		end
	end
	warn("[Economy] Nessun terreno libero per " .. player.Name)
end

local function releasePlot(player: Player)
	local s = states[player]
	local plot = s and s.plot
	if plot then
		plotOwner[plot] = nil
		for _, name in { "House", "Roost" } do
			local c = plot:FindFirstChild(name)
			if c then
				c:Destroy()
			end
		end
		local sign = plotSign(plot)
		if sign then
			sign.Text = "Terreno libero"
		end
	end
end

local function upgradeHouse(player: Player)
	local s = state(player)
	local nextHouse = EconomyConfig.HOUSES[s.house + 1]
	if not nextHouse then
		notice(player, "Hai gia' la casa migliore!")
		return
	end
	if s.coins < nextHouse.cost then
		notice(player, string.format("%s costa %d monete: ne hai %d. Vendi minerali e uova all'emporio!", nextHouse.name, nextHouse.cost, math.floor(s.coins)))
		return
	end
	s.coins -= nextHouse.cost
	s.house += 1
	publish(player)
	buildHouse(player)
	refreshRoost(player)
	Dragons.refresh(player)
	notice(player, string.format("Hai una %s! %s", nextHouse.name, if s.house == 1 then "Il nido e' sbloccato: ci puoi covare le uova" else "Piu' posti nel nido e per i draghi"))
end

------------------------------------------------------------------------------------------
-- Salvataggio (usato da Progression)

function Economy.serialize(player: Player): any
	local s = states[player]
	return s and { coins = math.floor(s.coins), house = s.house, lastSeen = os.time() }
end

function Economy.load(player: Player, data: any)
	local s = state(player)
	if type(data) == "table" then
		s.coins = data.coins or EconomyConfig.START_COINS
		s.house = data.house or 0
		s.lastSeen = data.lastSeen or os.time()
	end
	publish(player)
	assignPlot(player)
	-- guadagno dei draghi mentre eri via
	if type(data) == "table" and data.lastSeen then
		local minutes = math.min(os.time() - data.lastSeen, EconomyConfig.OFFLINE_HOURS * 3600) / 60
		local earned = math.floor(ratePerMinute(player) * minutes * EconomyConfig.OFFLINE_FACTOR)
		if earned > 0 then
			Economy.addCoins(player, earned)
			notice(player, string.format("Mentre eri via i tuoi draghi hanno guadagnato %d monete!", earned))
		end
	end
end

------------------------------------------------------------------------------------------

function Economy.setup()
	-- Cartelli dei terreni: compra/migliora la casa (solo il proprietario)
	local function bindPlot(plot: Instance)
		local post = plot:FindFirstChild("PlotPost", true)
		if not post then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Compra / migliora casa"
		prompt.ObjectText = "Terreno"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = post
		prompt.Triggered:Connect(function(player)
			if plotOwner[plot :: Model] ~= player then
				notice(player, "Questo terreno e' di un altro giocatore: il tuo ha il tuo nome sul cartello")
				return
			end
			upgradeHouse(player)
		end)
	end
	for _, plot in CollectionService:GetTagged("Plot") do
		bindPlot(plot)
	end

	-- vendere un drago dal menu Draghi
	Dragons.onSell = function(player: Player, d: any)
		local value = (EconomyConfig.DRAGON_PRICES[d.rarity] or 20) * d.stage
		Economy.addCoins(player, value)
		return value
	end
	-- quando cambiano i draghi, aggiorna quelli posati in casa
	local pendingRoost: { [Player]: boolean } = {}
	Dragons.onChanged = function(player: Player)
		if pendingRoost[player] then
			return
		end
		pendingRoost[player] = true
		task.delay(1, function()
			pendingRoost[player] = nil
			if player.Parent then
				refreshRoost(player)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player)
		states[player] = nil
	end)

	-- guadagno dei draghi posati: ogni 10 secondi (1/6 del valore al minuto)
	task.spawn(function()
		while true do
			task.wait(10)
			for player, s in states do
				local rate = ratePerMinute(player)
				if rate > 0 then
					s.pending += rate / 6
					if s.pending >= 1 then
						local whole = math.floor(s.pending)
						s.pending -= whole
						Economy.addCoins(player, whole)
					end
				end
			end
		end
	end)
end

Economy.upgradeHouse = upgradeHouse

return Economy
