--!strict
-- Equipaggiamento da costruire al Banco da lavoro con i minerali delle miniere.
-- La montagna non si scala in un giorno: ogni fascia di quota chiede un attrezzo nuovo,
-- e i minerali per costruirlo si trovano (sempre piu' rari) salendo.
--
--   Ramponi          pareti di ghiaccio (Glacier/Ice) e niente scivoloni sul ghiaccio
--   Tuta termica     il freddo in quota consuma molto meno calore
--   Rampino          spara una corda fino a RANGE studs: supera le pareti lisce
--   Piccone rinforzato  estrae Rubino e minerale Cosmico
--   Parapendio       Spazio mentre cadi: plani giu' dalla montagna (discesa a tempo dalla vetta)
--
-- Il giocatore possiede un attrezzo se ha l'attributo "Gear_<Id>" = true (salvato tra le
-- partite dal server).

export type Recipe = {
	id: string,
	name: string,
	description: string,
	cost: { [string]: number },
	tool: boolean?, -- true: e' un Tool che finisce nello zaino
	-- "Banco": solo vicino a un Banco da lavoro (al campo o in casa tua); "Ovunque": dal menu,
	-- in qualunque posto, se hai i materiali
	station: string?,
	consumable: boolean?, -- si puo' costruire tutte le volte che vuoi (non e' un attrezzo fisso)
}

local Gear = {}

local RECIPES: { Recipe } = {
	{
		id = "Ramponi",
		name = "Crampons",
		description = "Steel-spiked boots: climb ice without slipping.",
		cost = { Ferro = 8, Carbone = 6 },
		station = "Banco",
	},
	{
		id = "Tuta",
		name = "Thermal Suit",
		description = "High-altitude cold drains your warmth 4 times slower.",
		cost = { Cristallo = 6, Oro = 4, Carbone = 8 },
		station = "Banco",
	},
	{
		id = "Rampino",
		name = "Grappling Hook",
		description = "Click a distant wall: the rope pulls you up. Gets you past smooth walls.",
		cost = { Ferro = 12, Oro = 3, Cristallo = 2 },
		tool = true,
		station = "Banco",
	},
	{
		id = "PiccoRinforzato",
		name = "Reinforced Pickaxe",
		description = "Gold and crystal tip: mines Ruby and Cosmic ore.",
		cost = { Oro = 6, Cristallo = 4, Ferro = 6 },
		station = "Banco",
	},
	{
		id = "Parapendio",
		name = "Paraglider",
		description = "Press Space while falling to open it and glide down the mountain.",
		cost = { Ferro = 10, Cristallo = 4, Carbone = 8 },
		station = "Banco",
	},
	{
		id = "Sella",
		name = "Dragon Saddle",
		description = "Ride your adult dragon: press H (or Ride) and fly anywhere.",
		cost = { Ferro = 12, Oro = 6, Cristallo = 6, Rubino = 2 },
		station = "Banco",
	},
	-- Da costruire ovunque, al volo, con quello che hai nello zaino
	{
		id = "Chiodi",
		name = "Pitons (+4)",
		description = "Forge four wall pitons from the iron in your pack.",
		cost = { Ferro = 2, Carbone = 1 },
		station = "Ovunque",
		consumable = true,
	},
	{
		id = "Torcia",
		name = "Torch",
		description = "Lights up caves and the night, and warms your hands a little.",
		cost = { Carbone = 2, Ferro = 1 },
		station = "Ovunque",
		consumable = true,
		tool = true,
	},
	{
		id = "Bende",
		name = "Bandages",
		description = "Patch yourself up after a fall: +40 health.",
		cost = { Cristallo = 1, Carbone = 1 },
		station = "Ovunque",
		consumable = true,
	},
}
Gear.RECIPES = RECIPES

-- Minerali che si possono estrarre solo col Piccone rinforzato
Gear.HARD_ORES = { Rubino = true, Cosmico = true }

-- Freddo: sopra COLD_ALTITUDE il calore (0-100) cala, di piu' salendo, di notte e con la
-- neve/tempesta; vicino a un fuoco o in un campo base risale. A zero si perde salute.
Gear.COLD_ALTITUDE = 1200
Gear.COLD_PER_1000 = 4 -- calore perso al secondo ogni 1000 studs sopra COLD_ALTITUDE
Gear.SUIT_FACTOR = 0.25
Gear.HEAT_RANGE = 28 -- distanza da un fuoco per scaldarsi
Gear.HEAT_REGEN = 12
Gear.FREEZE_DAMAGE = 4 -- salute al secondo a calore zero

Gear.GRAPPLE_RANGE = 90
Gear.GRAPPLE_SPEED = 70
Gear.GRAPPLE_COOLDOWN = 2.5

function Gear.find(id: string): Recipe?
	for _, r in Gear.RECIPES do
		if r.id == id then
			return r
		end
	end
	return nil
end

function Gear.has(player: Player, id: string): boolean
	return player:GetAttribute("Gear_" .. id) == true
end

return Gear
