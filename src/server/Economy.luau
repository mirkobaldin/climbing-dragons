--!strict
-- Economia e case:
--   * Monete (classifica in alto a destra), salvate da Progression
--   * Vendite e acquisti all'emporio: vedi Shop
--   * Terreni (tag "Plot") in tre zone: campo tende ai piedi della montagna (Tenda), villaggio
--     delle costole del drago (Baita), villette sui costoni (Chalet). Ogni giocatore ha il
--     terreno della zona del suo livello; col cartello compri la Tenda (sblocca il nido) e
--     quando la migliori la casa trasloca nella zona successiva
--   * Draghi posati in casa (quelli che non ti seguono): guadagnano monete al minuto, anche
--     mentre sei offline (in parte)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Names = require(ReplicatedStorage.Shared.Names)
local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
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
	local v = stats and stats:FindFirstChild("Coins")
	if not v and stats then
		local nv = Instance.new("IntValue")
		nv.Name = "Coins"
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
	if amount > 0 then
		amount = math.floor(amount * UpgradeConfig.coinMult(player) + 0.5) -- bonus delle rinascite
	end
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

-- Punto d'arrivo del teletrasporto: fuori dalla casa, sul terreno o sulla pedana del terreno.
-- Prima si arrivava al centro, cioe' dentro la tenda (non si usciva) o sotto la pedana dello
-- Chalet. Si provano punti attorno al centro: a terra, alla quota del terreno, senza tetto sopra.
local PLOT_HALF = { 22, 30, 34 }
local function plotSpawn(plot: Model): Vector3
	local center = plot:GetPivot()
	local half = PLOT_HALF[(plot:GetAttribute("Level") or 1) :: number] or 24
	local skip = { plot:FindFirstChild("House") }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local downParams = RaycastParams.new()
	downParams.FilterType = Enum.RaycastFilterType.Exclude
	downParams.FilterDescendantsInstances = skip :: { Instance }
	local house = plot:FindFirstChild("House")
	local upParams = RaycastParams.new()
	upParams.FilterType = Enum.RaycastFilterType.Include
	upParams.FilterDescendantsInstances = if house then { house } else {}
	for _, r in { half * 0.8, half * 0.95, half + 4, half * 0.6 } do
		for k = 0, 11 do
			-- prima davanti alla porta (-Z), poi tutto attorno
			local a = math.pi + (if k % 2 == 0 then 1 else -1) * math.ceil(k / 2) * (math.pi / 6)
			local p = center * Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
			local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), downParams)
			if hit and hit.Normal.Y > 0.7 and math.abs(hit.Position.Y - center.Y) < 8 then
				local roof = house and workspace:Raycast(hit.Position + Vector3.new(0, 1, 0), Vector3.new(0, 30, 0), upParams)
				if not roof then
					return hit.Position + Vector3.new(0, 3, 0)
				end
			end
		end
	end
	return center.Position + Vector3.new(0, 4, 0)
end

-- Forgia dello Chalet: incudine e braciere accanto al punto d'arrivo, apre il crafting come il
-- banco del campo base (tag Workbench)
local function buildForge(plot: Model, at: Vector3)
	local old = plot:FindFirstChild("Forgia")
	if old then
		old:Destroy()
	end
	local forge = Instance.new("Model")
	forge.Name = "Forgia"
	local center = plot:GetPivot()
	local side = center.RightVector
	local base = at + side * 7 - Vector3.new(0, 3, 0)
	local look = CFrame.lookAt(base, base - side)
	local function block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = forge
		return p
	end
	block("Base", Vector3.new(4, 2, 2.4), look * CFrame.new(0, 1, 0), Color3.fromRGB(70, 66, 64), Enum.Material.Slate)
	local anvil = block("Incudine", Vector3.new(3.6, 1, 1.4), look * CFrame.new(0, 2.5, 0), Color3.fromRGB(50, 52, 58), Enum.Material.Metal)
	local coals = block("Braciere", Vector3.new(2.6, 0.6, 2.6), look * CFrame.new(3.6, 1.6, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	block("Focolare", Vector3.new(3.2, 1.4, 3.2), look * CFrame.new(3.6, 0.7, 0), Color3.fromRGB(90, 80, 74), Enum.Material.Cobblestone)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = coals
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 16
	light.Parent = coals
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Craft"
	prompt.ObjectText = "Forge"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anvil
	CollectionService:AddTag(anvil, "Workbench")
	forge.Parent = plot
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
		sign.Text = player.DisplayName .. (if nextHouse then string.format("\n%s: %d coins", Names.t(nextHouse.name), nextHouse.cost) else "")
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
				prompt.ObjectText = player.DisplayName .. "'s Nest"
			end
		end
	end
	model.Parent = plot
	-- dove arriva il teletrasporto "My camp" (e il tutorial)
	local spawnAt = plotSpawn(plot)
	player:SetAttribute("PlotSpawn", spawnAt)
	local forge = plot:FindFirstChild("Forgia")
	if s.house >= 3 then
		buildForge(plot, spawnAt)
	elseif forge then
		forge:Destroy()
	end
end

local function assignPlot(player: Player)
	local s = state(player)
	-- prima un terreno della zona del suo livello (senza casa: il campo tende), se sono tutti
	-- presi uno qualunque
	local want = math.max(1, s.house)
	local free: Model? = nil
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and not plotOwner[plot] then
			if plot:GetAttribute("Level") == want then
				free = plot
				break
			end
			free = free or plot
		end
	end
	do
		local plot = free
		if plot then
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
local releasePlot: (Player) -> ()

releasePlot = function(player: Player)
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
			sign.Text = "Free plot"
		end
	end
end

local function upgradeHouse(player: Player)
	local s = state(player)
	local nextHouse = EconomyConfig.HOUSES[s.house + 1]
	if not nextHouse then
		notice(player, "You already have the best house!")
		return
	end
	if s.coins < nextHouse.cost then
		notice(player, string.format("The %s costs %d coins: you have %d. Sell ores and eggs at the store!", Names.t(nextHouse.name), nextHouse.cost, math.floor(s.coins)))
		return
	end
	s.coins -= nextHouse.cost
	s.house += 1
	publish(player)
	-- la casa nuova sta nella zona del suo livello: si trasloca
	local plot = s.plot
	if s.house > 1 and plot and plot:GetAttribute("Level") ~= s.house then
		releasePlot(player)
		s.plot = nil
		assignPlot(player)
		local zone = s.plot and s.plot:GetAttribute("Zone")
		if zone == "Villaggio" then
			notice(player, "Your Cabin is in the village around the dragon ribs!")
		elseif zone == "Costone" then
			notice(player, "Your Chalet hangs on a cliff of the mountain: enjoy the view!")
		end
	else
		buildHouse(player)
	end
	refreshRoost(player)
	Dragons.refresh(player)
	notice(player, string.format("You got a %s! %s", Names.t(nextHouse.name), if s.house == 1 then "The nest is unlocked: you can hatch eggs in it" else "More room for eggs and dragons"))
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
			notice(player, string.format("While you were away your dragons earned %d coins!", earned))
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
		prompt.ActionText = "Buy / upgrade house"
		prompt.ObjectText = "Plot"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = post
		prompt.Triggered:Connect(function(player)
			if plotOwner[plot :: Model] ~= player then
				notice(player, "This plot belongs to another player: yours has your name on the sign")
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
		local value = (EconomyConfig.DRAGON_PRICES[d.rarity] or 20) * d.stage * (if d.shiny then UpgradeConfig.SHINY_VALUE else 1)
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
