--!strict
-- Regali del tempo di gioco (Mirko 17/10: "pensare a qualcosa per far stare la gente anche AFK";
-- riferimento: il pacco col conto alla rovescia dei simulatori). In ogni partita i regali si
-- sbloccano dopo tot minuti passati nel gioco (contano anche da fermi) e si riscattano dal pacco
-- nell'HUD (client/RegaliUI, server/Regali). Ricominciano a ogni ingresso.
-- kind: "Coins" (monete, col bonus delle rinascite), "Pitons" (chiodi), "Stones" (pietre
-- dell'evoluzione), "DragonXp" (esperienza ai draghi al seguito)

export type Gift = { minutes: number, kind: string, amount: number, text: string }

local RegaliConfig = {}

RegaliConfig.GIFTS = {
	{ minutes = 5, kind = "Coins", amount = 60, text = "60 coins" },
	{ minutes = 10, kind = "Pitons", amount = 4, text = "4 pitons" },
	{ minutes = 15, kind = "Coins", amount = 150, text = "150 coins" },
	{ minutes = 20, kind = "DragonXp", amount = 150, text = "150 dragon XP" },
	{ minutes = 30, kind = "Coins", amount = 300, text = "300 coins" },
	{ minutes = 45, kind = "Stones", amount = 1, text = "1 evolution stone" },
	{ minutes = 60, kind = "Coins", amount = 600, text = "600 coins" },
	{ minutes = 90, kind = "Stones", amount = 2, text = "2 evolution stones" },
} :: { Gift }

-- regali gia' presi: attributo RegaliPresi del giocatore, numeri separati da virgole ("1,2,4")
function RegaliConfig.claimed(player: Player): { [number]: boolean }
	local out: { [number]: boolean } = {}
	local raw = player:GetAttribute("RegaliPresi")
	if type(raw) == "string" then
		for _, part in string.split(raw, ",") do
			local n = tonumber(part)
			if n then
				out[n] = true
			end
		end
	end
	return out
end

-- secondi passati nel gioco in questa partita (attributo RegaliInizio = ora del server all'ingresso)
function RegaliConfig.elapsed(player: Player): number
	local start = player:GetAttribute("RegaliInizio")
	if type(start) ~= "number" then
		return 0
	end
	return math.max(0, workspace:GetServerTimeNow() - start)
end

return RegaliConfig
