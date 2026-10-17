--!strict
-- Novita' degli aggiornamenti (pannello WHAT'S NEW, client/NewsPanel): la prima voce e' la piu'
-- recente. Quando esce un aggiornamento si aggiunge una voce IN CIMA con version piu' alta: chi
-- entra vede il pallino rosso sul tasto delle notizie (al posto del ritratto nell'HUD) e il
-- pannello si apre da solo una volta. Testi a schermo in inglese, corti (li leggono bambini).
-- La versione vista si salva in ControlsLayout (voce Novita, client/HudLayout).

export type Entry = { version: number, date: string, title: string, lines: { string } }

local Novita = {}

Novita.LIST = {
	{
		version = 1,
		date = "Oct 17",
		title = "The big UI update",
		lines = {
			"New menus with dragon-forged frames",
			"Inventory with your gear around your climber",
			"Move the HUD where you like: tap the gear button",
			"Phone buttons: flat, and you choose how see-through they are",
			"Your first dragon now hatches from the tutorial egg",
		},
	},
} :: { Entry }

function Novita.latest(): number
	local e = Novita.LIST[1]
	return if e then e.version else 0
end

return Novita
