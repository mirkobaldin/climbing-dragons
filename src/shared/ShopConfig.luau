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
		description = "Full health, right now.",
		price = 40,
		color = Color3.fromRGB(220, 70, 70),
	},
	{
		id = "Thermos",
		name = "Hot Flask",
		description = "Warmth back to 100% (handy up high).",
		price = 30,
		color = Color3.fromRGB(255, 150, 70),
	},
	{
		id = "MysteryEgg",
		name = "Mystery Egg",
		description = "Random element. 75% Common, 22% Rare, 3% Epic. Goes into your nest.",
		price = 300,
		color = Color3.fromRGB(230, 222, 200),
	},
	{
		id = "RareEgg",
		name = "Rare Egg",
		description = "Random element. 85% Rare, 13% Epic, 2% Legendary. Goes into your nest.",
		price = 1200,
		color = Color3.fromRGB(90, 170, 255),
	},
} :: { Item }

-- Probabilita' delle uova del negozio (mostrate nella descrizione, come chiede Roblox)
ShopConfig.EGG_ODDS = {
	MysteryEgg = { Comune = 75, Raro = 22, Epico = 3 },
	RareEgg = { Raro = 85, Epico = 13, Leggendario = 2 },
}

-- Prodotti a Robux (crea su create.roblox.com i Developer Product e metti qui gli ID; 0 = nascosto)
ShopConfig.DEV_PRODUCTS = {
	Revive = 0, -- "Soccorso alpino": rinasci dove sei caduto
	InstantHatch = 0, -- schiude subito tutte le uova del nido
	Coins1000 = 0, -- 1000 monete
	TrainingBoost = 0, -- XP di addestramento x3 per 15 minuti
}

function ShopConfig.item(id: string): Item?
	for _, it in ShopConfig.ITEMS do
		if it.id == id then
			return it
		end
	end
	return nil
end

return ShopConfig
