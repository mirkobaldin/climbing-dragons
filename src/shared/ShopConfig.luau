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
		name = "Chiodi (pieni)",
		description = "Riempie la scorta di chiodi da roccia.",
		price = 25,
		color = Color3.fromRGB(170, 174, 180),
	},
	{
		id = "Medkit",
		name = "Kit medico",
		description = "Salute piena, subito.",
		price = 40,
		color = Color3.fromRGB(220, 70, 70),
	},
	{
		id = "Thermos",
		name = "Borraccia calda",
		description = "Calore al 100% (utile in quota).",
		price = 30,
		color = Color3.fromRGB(255, 150, 70),
	},
	{
		id = "MysteryEgg",
		name = "Uovo misterioso",
		description = "Elemento a caso. 75% Comune, 22% Raro, 3% Epico. Va nel tuo nido.",
		price = 300,
		color = Color3.fromRGB(230, 222, 200),
	},
	{
		id = "RareEgg",
		name = "Uovo raro",
		description = "Elemento a caso. 85% Raro, 13% Epico, 2% Leggendario. Va nel tuo nido.",
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
