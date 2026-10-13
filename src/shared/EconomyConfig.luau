--!strict
-- Economia: prezzi di vendita, case comprabili e guadagno dei draghi posati in casa.
-- Tutti i numeri sono qui per bilanciarli facilmente.

local EconomyConfig = {}

EconomyConfig.START_COINS = 60

-- Vendita all'emporio (monete per pezzo)
EconomyConfig.ORE_PRICES = { Carbone = 3, Ferro = 5, Oro = 12, Cristallo = 18, Rubino = 35, Cosmico = 70 }
EconomyConfig.EGG_PRICES = { Comune = 20, Raro = 60, Epico = 180, Leggendario = 700 }
-- Un drago venduto vale questo x lo stadio (cucciolo 1, giovane 2, adulto 3)
EconomyConfig.DRAGON_PRICES = { Comune = 40, Raro = 120, Epico = 400, Leggendario = 1500 }

-- Case sul tuo terreno: il livello 1 (Tenda) sblocca il nido. roost = draghi posati in casa
-- che guadagnano monete anche mentre sei via; nest = uova in cova contemporaneamente
EconomyConfig.HOUSES = {
	{ name = "Tenda", cost = 100, roost = 1, nest = 1 },
	{ name = "Baita", cost = 1500, roost = 3, nest = 3 },
	{ name = "Chalet", cost = 8000, roost = 6, nest = 5 },
	-- sulle isole volanti (mapgen/Isole: terreni di livello 4): ci si arriva con "Home" o in
	-- groppa al drago
	{ name = "MegaChalet", cost = 30000, roost = 10, nest = 8 },
}

-- Monete al minuto di un drago posato in casa (x lo stadio)
EconomyConfig.ROOST_RATE = { Comune = 1, Raro = 3, Epico = 8, Leggendario = 20 }
-- Guadagno mentre sei offline: una parte del normale, per al massimo OFFLINE_HOURS
EconomyConfig.OFFLINE_FACTOR = 0.5
EconomyConfig.OFFLINE_HOURS = 8

return EconomyConfig
