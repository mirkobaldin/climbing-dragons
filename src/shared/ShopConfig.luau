--!strict
-- Negozio (emporio del campo): cosa si compra con le monete e i prodotti a Robux.
-- Le vendite (minerali, uova, draghi) usano i prezzi di EconomyConfig.

export type Item = {
	id: string,
	name: string,
	description: string,
	price: number,
	color: Color3,
}

local ShopConfig = {}

ShopConfig.ITEMS = {
	{
		id = "Pitons",
		name = "Pitons (refill)",
		description = "Refills your stock of rock pitons.",
		price = 25,
		color = Color3.fromRGB(170, 174, 180),
	},
	{
		id = "Medkit",
		name = "Medkit",
		description = "Full health when you use it. Goes into your backpack and hotbar.",
		price = 40,
		color = Color3.fromRGB(220, 70, 70),
	},
	{
		id = "Thermos",
		name = "Hot Flask",
		description = "Warmth back to 100% when you drink it. Goes into your backpack and hotbar.",
		price = 30,
		color = Color3.fromRGB(255, 150, 70),
	},
	-- MONETE CHE SERVONO (Mirko 17/10: "si guadagna molto di piu' di quello che c'e' da
	-- spendere"): cose che si ricomprano sempre, utili a ogni livello (docs/ECONOMIA.md)
	{
		id = "DragonFeast",
		name = "Dragon Feast",
		description = "Your following dragons gain a third of a level.",
		price = 600,
		color = Color3.fromRGB(230, 120, 80),
	},
	{
		id = "EvoStone",
		name = "Evolution Stone",
		description = "One stone to evolve a dragon (Young needs 1, Adult 2).",
		price = 7500,
		color = Color3.fromRGB(170, 120, 255),
	},
} :: { Item }

-- Probabilita' delle uova a Robux (mostrate sulla carta, come chiede Roblox per le cose a caso)
ShopConfig.EGG_ODDS = {
	MysteryEgg = { Comune = 75, Raro = 22, Epico = 3 },
	RareEgg = { Raro = 85, Epico = 13, Leggendario = 2 },
	EpicEgg = { Epico = 85, Leggendario = 15 },
}

-- Prodotti a Robux (crea su create.roblox.com i Developer Product e metti qui gli ID; 0 = nascosto)
-- Prodotti che si comprano piu' volte: vanno creati come "Prodotti sviluppatore", non come Pass
-- (Coins x1000, Revive e Training Boost il 2026-10-14 erano stati creati come Pass: con un ID di
-- pass il gioco non li puo' vendere)
-- Mirko 17/10: uova e velocita' della schiusa NON si comprano con le monete ma a Robux, come
-- prodotti che si ricomprano; pacchetti stile simulatore (Starter una volta sola, poi Value).
-- Da creare nel Creator Hub (Monetization > Developer Products) con questi nomi e prezzi.
ShopConfig.DEV_PRODUCTS = {
	Revive = 0, -- "Soccorso alpino": rinasci dove sei caduto
	InstantHatch = 0, -- schiude subito tutte le uova del nido
	Coins1000 = 0, -- (vecchio: al suo posto i pacchetti di monete qui sotto)
	TrainingBoost = 0, -- XP di addestramento x3 per 15 minuti
	NestWarmer = 0, -- dimezza il tempo che manca alle uova del nido
	MysteryEgg = 0,
	RareEgg = 0,
	EpicEgg = 0,
	PotionCoins = 0,
	PotionHatchLuck = 0,
	PotionShinyLuck = 0,
	PotionDropLuck = 0,
	Coins_S = 0,
	Coins_M = 0,
	Coins_L = 0,
	Coins_XL = 0,
	StarterPack = 0,
	HatcherPack = 0,
	HunterPack = 0,
	RiderPack = 0,
}

-- prezzo da mostrare finche' Roblox non dice quello vero (MarketplaceService, client/RobuxShop)
ShopConfig.ROBUX_PRICES = {
	Revive = 25, InstantHatch = 49, TrainingBoost = 39, NestWarmer = 19,
	MysteryEgg = 49, RareEgg = 149, EpicEgg = 399,
	PotionCoins = 39, PotionHatchLuck = 49, PotionShinyLuck = 79, PotionDropLuck = 39,
	Coins_S = 49, Coins_M = 199, Coins_L = 699, Coins_XL = 1999,
	StarterPack = 199, HatcherPack = 299, HunterPack = 299, RiderPack = 399,
	EggFinder = 1299, FastIncubation = 299, ExtraDragon = 999, ExtraIncubator = 399, TrainingX2 = 399,
} :: { [string]: number }

-- uova a Robux: elemento a caso (tutti uguali), rarita' da EGG_ODDS. Vanno nel nido (anche pieno)
ShopConfig.ROBUX_EGGS = {
	{ id = "MysteryEgg", name = "Mystery Egg", preview = "Roccia" },
	{ id = "RareEgg", name = "Rare Egg", preview = "Gelo" },
	{ id = "EpicEgg", name = "Epic Egg", preview = "Cosmico" },
}

-- pacchetti di monete (non moltiplicati dalle rinascite ne' dalla pozione)
ShopConfig.COIN_PACKS = {
	{ id = "Coins_S", coins = 2500, name = "Pouch of Coins" },
	{ id = "Coins_M", coins = 12000, name = "Chest of Coins" },
	{ id = "Coins_L", coins = 50000, name = "Dragon Hoard" },
	{ id = "Coins_XL", coins = 200000, name = "Mountain of Gold" },
}

-- pacchetti: cosa c'e' dentro. kind: "egg" (rarita' fissa, elemento a caso), "coins", "item"
-- (oggetto di shared/Items), "stones" (pietre dell'evoluzione), "hatch" (schiude il nido)
export type PackItem = { kind: string, n: number, id: string?, rarity: string?, text: string }
export type Pack = { id: string, name: string, art: string, oneTime: boolean?, color: Color3, items: { PackItem } }
ShopConfig.PACKS = {
	{
		id = "StarterPack", name = "Starter Pack", art = "pack_Starter", oneTime = true, color = Color3.fromRGB(255, 190, 70),
		items = {
			{ kind = "egg", n = 1, rarity = "Epico", text = "1 Epic egg (random element)" },
			{ kind = "coins", n = 10000, text = "10,000 Coins" },
			{ kind = "item", n = 2, id = "PotionHatchLuck", text = "2x Hatch Luck Potion" },
			{ kind = "item", n = 2, id = "PotionCoins", text = "2x Coin Potion" },
		},
	},
	{
		id = "HatcherPack", name = "Hatcher Pack", art = "pack_Hatcher", color = Color3.fromRGB(110, 200, 255),
		items = {
			{ kind = "egg", n = 2, rarity = "Raro", text = "2 Rare eggs (random element)" },
			{ kind = "item", n = 2, id = "PotionHatchLuck", text = "2x Hatch Luck Potion" },
			{ kind = "item", n = 2, id = "PotionShinyLuck", text = "2x Shiny Luck Potion" },
			{ kind = "hatch", n = 1, text = "Instant Hatch" },
		},
	},
	{
		id = "HunterPack", name = "Hunter Pack", art = "pack_Hunter", color = Color3.fromRGB(255, 110, 90),
		items = {
			{ kind = "coins", n = 15000, text = "15,000 Coins" },
			{ kind = "item", n = 3, id = "PotionCoins", text = "3x Coin Potion" },
			{ kind = "item", n = 3, id = "PotionDropLuck", text = "3x Drop Luck Potion" },
		},
	},
	{
		id = "RiderPack", name = "Dragon Rider Pack", art = "pack_Rider", color = Color3.fromRGB(190, 130, 255),
		items = {
			{ kind = "stones", n = 3, text = "3 Evolution Stones" },
			{ kind = "coins", n = 8000, text = "8,000 Coins" },
			{ kind = "item", n = 3, id = "Medkit", text = "3 Medkits" },
		},
	},
} :: { Pack }

function ShopConfig.pack(id: string): Pack?
	for _, p in ShopConfig.PACKS do
		if p.id == id then
			return p
		end
	end
	return nil
end

function ShopConfig.item(id: string): Item?
	for _, it in ShopConfig.ITEMS do
		if it.id == id then
			return it
		end
	end
	return nil
end

return ShopConfig
