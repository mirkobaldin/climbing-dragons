--!strict
-- Oggetti che si usano e finiscono (Mirko 17/10: "le bende, il medikit, la fiaschetta le puoi
-- comprare ma non le trovi da nessuna parte: non si equipaggiano nella barra e non compaiono
-- nello zaino"). Ognuno e' un Tool vero nello zaino di Roblox (va nella barra 1-5 come gli
-- attrezzi) con la quantita' nell'attributo Quantita; il numero vero sta nella cartella
-- "Oggetti" del giocatore (IntValue, salvata da Progression). Usarlo = click col Tool in mano o
-- USE nello zaino (server/Items). Le pozioni accendono un potenziamento a tempo: attributo
-- "Boost_<tipo>" = ora del server in cui finisce (si sommano se ne bevi due).

export type Item = {
	id: string,
	name: string, -- nome a schermo e nome del Tool (non cambiarlo: la barra 1-5 lo salva)
	text: string,
	icon: string, -- icona in UiAssets
	fallback: string, -- icona finche' quella vera non c'e'
	color: Color3, -- colore del Tool in mano
	heal: number?, -- vita (math.huge = piena)
	warmth: number?, -- calore rimesso
	boost: string?, -- potenziamento a tempo
}

local Items = {}

Items.BOOST_SECONDS = 15 * 60
Items.COIN_MULT = 2 -- pozione delle monete
Items.HATCH_LUCK = 0.3 -- probabilita' che l'uovo salga di una rarita' alla schiusa
Items.SHINY_MULT = 3 -- probabilita' shiny moltiplicata
Items.DROP_MULT = 2 -- probabilita' dei drop dei nemici moltiplicata

Items.LIST = {
	{ id = "Medkit", name = "Medkit", text = "Full health, right now.", icon = "item_Medkit", fallback = "icon_health",
		color = Color3.fromRGB(220, 70, 70), heal = math.huge },
	{ id = "Bende", name = "Bandages", text = "Patch yourself up: +40 health.", icon = "item_Bende", fallback = "icon_health",
		color = Color3.fromRGB(235, 225, 205), heal = 40 },
	{ id = "Thermos", name = "Hot Flask", text = "Warmth back to 100% (handy up high).", icon = "item_Thermos", fallback = "icon_warmth",
		color = Color3.fromRGB(255, 150, 70), warmth = 100 },
	{ id = "PotionCoins", name = "Coin Potion", text = "x2 coins for 15 minutes.", icon = "item_PotionCoins", fallback = "icon_coin",
		color = Color3.fromRGB(255, 200, 60), boost = "Coins" },
	{ id = "PotionHatchLuck", name = "Hatch Luck Potion", text = "For 15 minutes every egg you hatch has a 30% chance to go up one rarity.",
		icon = "item_PotionHatchLuck", fallback = "icon_egg", color = Color3.fromRGB(110, 200, 255), boost = "HatchLuck" },
	{ id = "PotionShinyLuck", name = "Shiny Luck Potion", text = "x3 chance of a SHINY dragon for 15 minutes.",
		icon = "item_PotionShinyLuck", fallback = "icon_egg", color = Color3.fromRGB(255, 225, 120), boost = "ShinyLuck" },
	{ id = "PotionDropLuck", name = "Drop Luck Potion", text = "x2 monster drops for 15 minutes.",
		icon = "item_PotionDropLuck", fallback = "icon_quest", color = Color3.fromRGB(120, 230, 140), boost = "DropLuck" },
} :: { Item }

-- testo a schermo dei potenziamenti
Items.BOOST_NAMES = { Coins = "x2 Coins", HatchLuck = "Hatch Luck", ShinyLuck = "Shiny Luck", DropLuck = "x2 Drops" } :: { [string]: string }

function Items.get(id: string): Item?
	for _, it in Items.LIST do
		if it.id == id then
			return it
		end
	end
	return nil
end

function Items.byName(name: string): Item?
	for _, it in Items.LIST do
		if it.name == name then
			return it
		end
	end
	return nil
end

-- secondi che restano del potenziamento (0 = spento). Va sul server e sul client
function Items.boostLeft(player: Player, kind: string): number
	local t = player:GetAttribute("Boost_" .. kind)
	if type(t) ~= "number" then
		return 0
	end
	return math.max(0, t - workspace:GetServerTimeNow())
end

function Items.boosted(player: Player, kind: string): boolean
	return Items.boostLeft(player, kind) > 0
end

return Items
