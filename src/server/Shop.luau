--!strict
-- Negozio (emporio): comprare con le monete, vendere minerali/uova, prodotti e pass a Robux.
-- Il bancone (tag "ShopCounter") apre il negozio sul client; tutto passa dal RemoteFunction
-- "Shop" e il server controlla prezzi e disponibilita'.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Names = require(ReplicatedStorage.Shared.Names)
local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local Dragons = require(script.Parent.Dragons)
local Economy = require(script.Parent.Economy)
local Eggs = require(script.Parent.Eggs)
local Ropes = require(script.Parent.Ropes)

local Shop = {}

local rng = Random.new()

local function roll(odds: { [string]: number }): string
	local total = 0
	for _, w in odds do
		total += w
	end
	local r = rng:NextNumber(0, total)
	for rarity, w in odds do
		r -= w
		if r <= 0 then
			return rarity
		end
	end
	return "Comune"
end

local function randomElement(): string
	local list = {}
	for _, e in DragonConfig.ELEMENTS do
		if not DragonConfig.RETIRED[e.id] then
			table.insert(list, e.id)
		end
	end
	return list[rng:NextInteger(1, #list)]
end

local function buy(player: Player, id: string): (boolean, string)
	local item = ShopConfig.item(id)
	if not item then
		return false, "Unknown item"
	end
	if Economy.coins(player) < item.price then
		return false, string.format("You need %d coins", item.price)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if id == "Pitons" then
		Ropes.refill(player)
	elseif id == "Medkit" then
		if not humanoid then
			return false, "No character"
		end
		humanoid.Health = humanoid.MaxHealth
	elseif id == "Thermos" then
		player:SetAttribute("Warmth", 100)
	elseif id == "MysteryEgg" or id == "RareEgg" then
		local rarity = roll(ShopConfig.EGG_ODDS[id])
		local element = randomElement()
		if not Dragons.incubate(player, element, rarity) then
			return false, if Dragons.nestSlots(player) == 0 then "You need a nest: buy the Tent on your plot" else "The nest is full"
		end
		Economy.addCoins(player, -item.price)
		return true, string.format("%s %s Egg in your nest!", Names.t(rarity), Names.t(element))
	end
	Economy.addCoins(player, -item.price)
	return true, item.name .. " bought"
end

local function sellOre(player: Player, ore: string, amount: any): (boolean, string)
	local folder = player:FindFirstChild("Ores")
	local v = folder and folder:FindFirstChild(ore) :: IntValue?
	local price = EconomyConfig.ORE_PRICES[ore]
	if not v or not price or v.Value <= 0 then
		return false, "You don't have any"
	end
	local n = if amount == "all" then v.Value else math.clamp(math.floor(tonumber(amount) or 1), 1, v.Value)
	v.Value -= n
	local stats = player:FindFirstChild("leaderstats")
	local total = stats and stats:FindFirstChild("Ores") :: IntValue?
	if total then
		total.Value = math.max(0, total.Value - n)
	end
	Economy.addCoins(player, n * price)
	player:SetAttribute("OresSold", (player:GetAttribute("OresSold") or 0) + 1)
	return true, string.format("Sold %d %s for %d coins", n, Names.t(ore), n * price)
end

local function handle(player: Player, action: any, id: any, amount: any): (boolean, string)
	if action == "buy" and type(id) == "string" then
		return buy(player, id)
	elseif action == "sellOre" and type(id) == "string" then
		return sellOre(player, id, amount)
	elseif action == "discard" and type(id) == "string" then
		-- butta via minerali o materiali dallo zaino (client/MainMenu, pulsanti Drop 1 / Drop all)
		local kind, name = string.match(id, "^(%a+):(.+)$")
		local folder = player:FindFirstChild(if kind == "ore" then "Ores" elseif kind == "mat" then "Materiali" else "")
		local v = folder and name and folder:FindFirstChild(name)
		if not v or not v:IsA("IntValue") or v.Value <= 0 then
			return false, "You don't have any"
		end
		local n = if amount == "all" then v.Value else math.clamp(math.floor(tonumber(amount) or 1), 1, v.Value)
		v.Value -= n
		if kind == "ore" then
			local stats = player:FindFirstChild("leaderstats")
			local total = stats and stats:FindFirstChild("Ores") :: IntValue?
			if total then
				total.Value = math.max(0, total.Value - n)
			end
		end
		return true, string.format("Dropped %d %s", n, Names.t(name :: string))
	elseif action == "sellEgg" then
		local _, rarity = Eggs.takeCarried(player)
		if not rarity then
			return false, "You're not carrying an egg"
		end
		local value = EconomyConfig.EGG_PRICES[rarity] or 10
		Economy.addCoins(player, value)
		return true, string.format("Egg sold for %d coins", value)
	elseif action == "robux" and type(id) == "string" then
		local passId = DragonConfig.GAMEPASSES[id]
		local productId = ShopConfig.DEV_PRODUCTS[id]
		if passId and passId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, passId)
			return true, ""
		elseif productId and productId > 0 then
			MarketplaceService:PromptProductPurchase(player, productId)
			return true, ""
		end
		return false, "Not available yet"
	end
	return false, "Invalid request"
end

-- Acquisti a Robux completati
local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = info.ProductId
	if id == ShopConfig.DEV_PRODUCTS.Revive then
		local pos = player:GetAttribute("DeathPosition")
		if typeof(pos) == "Vector3" then
			player:SetAttribute("ReviveAt", pos)
		end
		player:LoadCharacter()
	elseif id == ShopConfig.DEV_PRODUCTS.InstantHatch then
		Dragons.finishIncubation(player)
	elseif id == ShopConfig.DEV_PRODUCTS.Coins1000 then
		Economy.addCoins(player, 1000)
	elseif id == ShopConfig.DEV_PRODUCTS.TrainingBoost then
		-- si somma a un boost gia' attivo
		local now = os.time()
		local untilT = math.max(now, (player:GetAttribute("TrainingBoostUntil") or 0) :: number)
		player:SetAttribute("TrainingBoostUntil", untilT + DragonConfig.TRAINING.BOOST_MINUTES * 60)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.setup(remotes: { [string]: RemoteEvent })
	local fn = Instance.new("RemoteFunction")
	fn.Name = "Shop"
	fn.Parent = ReplicatedStorage:WaitForChild("Remotes")
	fn.OnServerInvoke = handle

	-- il bancone apre il negozio
	local function bindCounter(counter: Instance)
		for _, p in counter:GetChildren() do
			if p:IsA("ProximityPrompt") then
				p:Destroy()
			end
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open store"
		prompt.ObjectText = "Store"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = counter
		prompt.Triggered:Connect(function(player)
			remotes.OpenShop:FireClient(player)
		end)
	end
	for _, c in CollectionService:GetTagged("ShopCounter") do
		bindCounter(c)
	end

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for name, id in DragonConfig.GAMEPASSES do
			if id == passId then
				player:SetAttribute("Pass_" .. name, true)
			end
		end
	end)
end

return Shop
