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
	-- filtro del menu Crafting: "Equipment", "Tools", "Consumables" o "Materials"
	category: string,
	-- materiali che ricevi (ricette "Materials": servono ai potenziamenti, cartella Materiali)
	gives: { [string]: number }?,
	-- attrezzo che serve prima (le vele del parapendio: Alpine -> Dragon Wings -> Storm Wyvern)
	requires: string?,
}

local Gear = {}

local RECIPES: { Recipe } = {
	{
		id = "Ramponi",
		category = "Equipment",
		name = "Crampons",
		description = "Steel-spiked boots: climb ice without slipping.",
		cost = { Ferro = 8, Carbone = 6 },
		station = "Banco",
	},
	{
		id = "Tuta",
		category = "Equipment",
		name = "Thermal Suit",
		description = "High-altitude cold drains your warmth 4 times slower.",
		cost = { Cristallo = 6, Oro = 4, Carbone = 8 },
		station = "Banco",
	},
	{
		id = "Rampino",
		category = "Tools",
		name = "Grappling Hook",
		description = "Click a distant wall: the rope pulls you up. Gets you past smooth walls.",
		cost = { Ferro = 12, Oro = 3, Cristallo = 2 },
		tool = true,
		station = "Banco",
	},
	{
		id = "PiccoRinforzato",
		category = "Tools",
		name = "Reinforced Pickaxe",
		description = "Gold and crystal tip: mines Ruby and Cosmic ore.",
		cost = { Oro = 6, Cristallo = 4, Ferro = 6 },
		station = "Banco",
	},
	{
		id = "Parapendio",
		category = "Equipment",
		name = "Paraglider",
		description = "Jump while falling to open it and glide down the mountain.",
		cost = { Ferro = 10, Cristallo = 4, Carbone = 8 },
		station = "Banco",
	},
	-- Le altre due vele (modelli di Codex in ReplicatedStorage.Vele): piu' veloci e piu' lente a
	-- scendere, ognuna chiede la precedente (Gear.GLIDERS). Materiali provvisori: quando ci saranno
	-- i mostri a tema drago dei biomi (docs/CODEX_MOSTRI_BIOMI.md) i costi useranno i loro drop
	{
		id = "VelaDrago",
		category = "Equipment",
		name = "Dragon Wings",
		description = "A glider with real dragon wings: faster, and you fall slower.",
		cost = { Pelliccia_Yeti = 4, Cristallo_Ghiaccio = 4, Oro = 8, Rubino = 2 },
		station = "Banco",
		requires = "Parapendio",
	},
	{
		id = "VelaTempesta",
		category = "Equipment",
		name = "Storm Wyvern Wings",
		description = "Ancient storm wyvern wings: the fastest glider on the mountain.",
		cost = { Nucleo_Glaciale = 3, Cristallo_Ghiaccio = 6, Rubino = 4, Cosmico = 4 },
		station = "Banco",
		requires = "VelaDrago",
	},
	{
		id = "Sella",
		category = "Equipment",
		name = "Dragon Saddle",
		description = "Ride your adult dragon and fly anywhere.",
		cost = { Ferro = 12, Oro = 6, Cristallo = 6, Rubino = 2 },
		station = "Banco",
	},
	-- Da costruire ovunque, al volo, con quello che hai nello zaino
	{
		id = "Chiodi",
		category = "Consumables",
		name = "Pitons (+4)",
		description = "Forge four wall pitons from the iron in your pack.",
		cost = { Ferro = 2, Carbone = 1 },
		station = "Ovunque",
		consumable = true,
	},
	{
		id = "Torcia",
		category = "Tools",
		name = "Torch",
		description = "Lights up caves and the night, and warms your hands a little.",
		cost = { Carbone = 2, Ferro = 1 },
		station = "Ovunque",
		consumable = true,
		tool = true,
	},
	{
		id = "Bende",
		category = "Consumables",
		name = "Bandages",
		description = "Patch yourself up after a fall: +40 health.",
		cost = { Cristallo = 1, Carbone = 1 },
		station = "Ovunque",
		consumable = true,
	},
	-- Materiali dei potenziamenti (Mirko 15/10: "nel crafting non ci sono alcune cose degli upgrade,
	-- come le ottieni?"): cadono dai nemici, ma si possono anche fare al banco coi minerali
	{
		id = "Pelliccia_Yeti",
		category = "Materials",
		name = "Yeti Fur",
		description = "Thick fur for upgrades. Yetis drop it too.",
		cost = { Carbone = 8, Ferro = 4, Cristallo = 1 },
		station = "Banco",
		consumable = true,
		gives = { Pelliccia_Yeti = 1 },
	},
	{
		id = "Cristallo_Ghiaccio",
		category = "Materials",
		name = "Ice Crystal",
		description = "Frozen crystal for upgrades. Yetis and Ice Golems drop it.",
		cost = { Cristallo = 3, Ferro = 2 },
		station = "Banco",
		consumable = true,
		gives = { Cristallo_Ghiaccio = 1 },
	},
	{
		id = "Nucleo_Glaciale",
		category = "Materials",
		name = "Glacial Core",
		description = "The heart of an Ice Golem, fused from ice crystals and gold.",
		cost = { Cristallo_Ghiaccio = 3, Oro = 3 },
		station = "Banco",
		consumable = true,
		gives = { Nucleo_Glaciale = 1 },
	},
}
Gear.RECIPES = RECIPES
-- materiali dei nemici (cartella Materiali del giocatore); gli altri costi sono minerali (Ores)
Gear.MONSTER_MATERIALS = { Pelliccia_Yeti = true, Cristallo_Ghiaccio = true, Nucleo_Glaciale = true }

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

-- Le tre vele del parapendio, dalla piu' semplice: skin = modello in ReplicatedStorage.Vele,
-- speed = velocita' avanti, fall = discesa (UpgradeConfig.GLIDE ha MIN_FALL_SPEED e il bonus
-- del drago). Si usa la migliore che hai (o quella scelta: attributo GliderScelta)
export type Glider = { id: string, skin: string, speed: number, fall: number }
Gear.GLIDERS = {
	{ id = "Parapendio", skin = "AlpineParaglider", speed = 52, fall = 9 },
	{ id = "VelaDrago", skin = "DragonWings", speed = 62, fall = 7 },
	{ id = "VelaTempesta", skin = "AncientStormWyvern", speed = 74, fall = 5.5 },
} :: { Glider }

-- la vela che usa il giocatore (nil = nessuna)
function Gear.glider(player: Player): Glider?
	local chosen = player:GetAttribute("GliderScelta")
	local best: Glider? = nil
	for _, g in Gear.GLIDERS do
		if Gear.has(player, g.id) then
			if g.id == chosen then
				return g
			end
			best = g
		end
	end
	return best
end

function Gear.hasGlider(player: Player): boolean
	return Gear.glider(player) ~= nil
end

return Gear
