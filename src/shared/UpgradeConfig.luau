--!strict
-- Potenziamenti dello scalatore, taglie, rinascita ed eventi (giro di gioco: uccidi -> raccogli
-- -> potenzia -> sali piu' in alto). Il livello di ogni potenziamento e' l'attributo
-- "Up_<id>" del giocatore (0 = non comprato), salvato da Progression.
--
--   Rampino       portata del rampino
--   Uncino        il rampino si aggancia ai nemici: voli addosso e li stordisci
--   Lancio        lancio della piccozza (Q): danno, portata, rimbalzi su altri nemici
--   Esoscheletro  stamina che dura di piu' e meno danni da caduta
--   Scudo         scudo di ghiaccio che assorbe i colpi e si ricarica
--   Stivali       corri piu' veloce
--   Furia, Ali, Maestria, Tesoro, Addestramento: potenziamenti dei draghi (group "Dragon")

export type Upgrade = {
	id: string,
	group: string?, -- nil = scalatore, "Dragon" = potenziamento dei draghi
	name: string,
	description: string,
	max: number,
	-- valori per livello (indice = livello + 1)
	values: { [string]: { number } },
	-- costo per passare al livello n (indice = n)
	costs: { { coins: number, items: { [string]: number } } },
	text: (number) -> string, -- cosa fa al livello dato (mostrato nella scheda)
}

local UpgradeConfig = {}

UpgradeConfig.UPGRADES = {
	{
		id = "Rampino",
		name = "Grapple Range",
		description = "Your Grappling Hook reaches farther.",
		max = 5,
		values = { range = { 90, 105, 120, 135, 150, 175 } },
		costs = {
			{ coins = 150, items = { Ferro = 4 } },
			{ coins = 350, items = { Ferro = 6, Pelliccia_Yeti = 2 } },
			{ coins = 700, items = { Oro = 4, Cristallo_Ghiaccio = 3 } },
			{ coins = 1300, items = { Oro = 6, Nucleo_Glaciale = 2 } },
			{ coins = 2400, items = { Rubino = 3, Nucleo_Glaciale = 4 } },
		},
		text = function(l)
			return string.format("Range %d studs", UpgradeConfig.UPGRADES[1].values.range[l + 1])
		end,
	},
	{
		id = "Uncino",
		name = "Grapple Strike",
		description = "Grapple an enemy: you fly at it, hit it and stun it. Upgrades make it hit harder.",
		max = 5,
		values = { damage = { 12, 25, 40, 60, 85, 120 }, stun = { 0.6, 1, 1.3, 1.6, 2, 2.5 } },
		costs = {
			{ coins = 300, items = { Pelliccia_Yeti = 3 } },
			{ coins = 600, items = { Pelliccia_Yeti = 5, Ferro = 6 } },
			{ coins = 1100, items = { Cristallo_Ghiaccio = 5, Oro = 4 } },
			{ coins = 1900, items = { Nucleo_Glaciale = 3, Oro = 6 } },
			{ coins = 3200, items = { Nucleo_Glaciale = 5, Rubino = 3 } },
		},
		text = function(l)
			local v = UpgradeConfig.UPGRADES[2].values
			return string.format("%d damage, stun %.1f s", v.damage[l + 1], v.stun[l + 1])
		end,
	},
	{
		id = "Lancio",
		name = "Axe Throw",
		description = "Thrown Ice Axe (Q): more damage, more range, bounces to other enemies.",
		max = 5,
		values = { mult = { 1, 1.25, 1.5, 1.8, 2.1, 2.6 }, range = { 55, 62, 70, 80, 90, 105 }, bounces = { 0, 0, 1, 1, 2, 3 } },
		costs = {
			{ coins = 120, items = { Ferro = 5 } },
			{ coins = 300, items = { Ferro = 8, Carbone = 6 } },
			{ coins = 650, items = { Pelliccia_Yeti = 4, Oro = 3 } },
			{ coins = 1200, items = { Cristallo_Ghiaccio = 6, Oro = 5 } },
			{ coins = 2200, items = { Nucleo_Glaciale = 4, Rubino = 2 } },
		},
		text = function(l)
			local v = UpgradeConfig.UPGRADES[3].values
			return string.format("x%.2f damage, %d studs, %d bounces", v.mult[l + 1], v.range[l + 1], v.bounces[l + 1])
		end,
	},
	{
		id = "Esoscheletro",
		name = "Exoskeleton",
		description = "Frame on your back: stamina lasts longer and falls hurt less.",
		max = 5,
		values = { stamina = { 1, 1.15, 1.3, 1.45, 1.6, 1.8 }, fall = { 0, 0.1, 0.2, 0.3, 0.4, 0.5 } },
		costs = {
			{ coins = 200, items = { Ferro = 6, Carbone = 4 } },
			{ coins = 450, items = { Ferro = 10, Oro = 2 } },
			{ coins = 900, items = { Oro = 5, Cristallo = 3 } },
			{ coins = 1600, items = { Cristallo = 5, Nucleo_Glaciale = 2 } },
			{ coins = 2800, items = { Rubino = 3, Nucleo_Glaciale = 4 } },
		},
		text = function(l)
			local v = UpgradeConfig.UPGRADES[4].values
			return string.format("Stamina x%.2f, fall damage -%d%%", v.stamina[l + 1], math.floor(v.fall[l + 1] * 100))
		end,
	},
	{
		id = "Scudo",
		name = "Frost Shield",
		description = "Ice shield that soaks up hits and recharges when you're safe.",
		max = 5,
		values = { hp = { 0, 20, 35, 55, 80, 110 } },
		costs = {
			{ coins = 250, items = { Cristallo_Ghiaccio = 2 } },
			{ coins = 550, items = { Cristallo_Ghiaccio = 4, Cristallo = 2 } },
			{ coins = 1000, items = { Cristallo_Ghiaccio = 6, Cristallo = 4 } },
			{ coins = 1800, items = { Nucleo_Glaciale = 3, Cristallo = 6 } },
			{ coins = 3000, items = { Nucleo_Glaciale = 5, Cosmico = 2 } },
		},
		text = function(l)
			if l == 0 then
				return "No shield"
			end
			return string.format("%d shield points", UpgradeConfig.UPGRADES[5].values.hp[l + 1])
		end,
	},
	{
		id = "Stivali",
		name = "Swift Boots",
		description = "Lighter boots: you walk and run faster.",
		max = 5,
		values = { speed = { 1, 1.06, 1.12, 1.18, 1.24, 1.32 } },
		costs = {
			{ coins = 100, items = { Carbone = 4 } },
			{ coins = 250, items = { Pelliccia_Yeti = 2, Carbone = 6 } },
			{ coins = 550, items = { Pelliccia_Yeti = 4, Ferro = 6 } },
			{ coins = 1000, items = { Pelliccia_Yeti = 6, Oro = 4 } },
			{ coins = 1800, items = { Nucleo_Glaciale = 2, Oro = 6 } },
		},
		text = function(l)
			return string.format("Speed +%d%%", math.floor((UpgradeConfig.UPGRADES[6].values.speed[l + 1] - 1) * 100 + 0.5))
		end,
	},
	-- Potenziamenti del drago (group = "Dragon", scheda Dragon del menu Upgrades): valgono per
	-- tutti i tuoi draghi. La Picchiata (onda d'urto atterrando, niente danni da caduta) e' stata
	-- tolta: Mirko 15/10, "se no uno non muore mai se cade dalla montagna"
	{
		id = "Furia",
		group = "Dragon",
		name = "Dragon Fury",
		description = "Your dragons hit harder: bites, ride shots and the Z special.",
		max = 5,
		values = { mult = { 1, 1.1, 1.22, 1.36, 1.52, 1.7 } },
		costs = {
			{ coins = 250, items = { Ferro = 6, Pelliccia_Yeti = 1 } },
			{ coins = 600, items = { Oro = 4, Pelliccia_Yeti = 3 } },
			{ coins = 1200, items = { Cristallo_Ghiaccio = 5, Oro = 5 } },
			{ coins = 2200, items = { Nucleo_Glaciale = 3, Rubino = 2 } },
			{ coins = 3800, items = { Nucleo_Glaciale = 5, Cosmico = 2 } },
		},
		text = function(l)
			return string.format("Dragon damage +%d%%", math.floor(UpgradeConfig.UPGRADES[7].values.mult[l + 1] * 100 - 100 + 0.5))
		end,
	},
	{
		id = "Ali",
		group = "Dragon",
		name = "Wing Power",
		description = "Stronger wings: your dragon flies faster when you ride it.",
		max = 5,
		values = { speed = { 1, 1.08, 1.16, 1.25, 1.35, 1.5 } },
		costs = {
			{ coins = 200, items = { Carbone = 8, Ferro = 4 } },
			{ coins = 500, items = { Pelliccia_Yeti = 3, Oro = 2 } },
			{ coins = 1000, items = { Cristallo_Ghiaccio = 4, Oro = 4 } },
			{ coins = 1800, items = { Nucleo_Glaciale = 2, Cristallo = 6 } },
			{ coins = 3200, items = { Nucleo_Glaciale = 4, Rubino = 3 } },
		},
		text = function(l)
			return string.format("Flight speed +%d%%", math.floor(UpgradeConfig.UPGRADES[8].values.speed[l + 1] * 100 - 100 + 0.5))
		end,
	},
	{
		id = "Maestria",
		group = "Dragon",
		name = "Elemental Mastery",
		description = "Your dragon's special attack (Z) recharges faster.",
		max = 5,
		values = { cut = { 0, 0.08, 0.16, 0.24, 0.32, 0.4 } },
		costs = {
			{ coins = 300, items = { Cristallo = 3 } },
			{ coins = 700, items = { Cristallo = 5, Cristallo_Ghiaccio = 2 } },
			{ coins = 1300, items = { Cristallo_Ghiaccio = 5, Oro = 4 } },
			{ coins = 2300, items = { Nucleo_Glaciale = 3, Rubino = 2 } },
			{ coins = 4000, items = { Nucleo_Glaciale = 5, Cosmico = 3 } },
		},
		text = function(l)
			return string.format("Special cooldown -%d%%", math.floor(UpgradeConfig.UPGRADES[9].values.cut[l + 1] * 100 + 0.5))
		end,
	},
	{
		id = "Tesoro",
		group = "Dragon",
		name = "Treasure Hoard",
		description = "Dragons resting in your farm make more gold coins.",
		max = 5,
		values = { mult = { 1, 1.15, 1.3, 1.5, 1.75, 2 } },
		costs = {
			{ coins = 400, items = { Oro = 3 } },
			{ coins = 900, items = { Oro = 6, Ferro = 6 } },
			{ coins = 1700, items = { Oro = 8, Cristallo = 4 } },
			{ coins = 3000, items = { Rubino = 3, Nucleo_Glaciale = 2 } },
			{ coins = 5000, items = { Rubino = 5, Cosmico = 3 } },
		},
		text = function(l)
			return string.format("Farm coins x%.2f", UpgradeConfig.UPGRADES[10].values.mult[l + 1])
		end,
	},
	{
		id = "Addestramento",
		group = "Dragon",
		name = "Quick Learner",
		description = "Your dragons earn more XP from fights, training and the arena.",
		max = 5,
		values = { mult = { 1, 1.1, 1.2, 1.35, 1.5, 1.7 } },
		costs = {
			{ coins = 250, items = { Carbone = 6, Cristallo = 1 } },
			{ coins = 600, items = { Cristallo = 4, Pelliccia_Yeti = 2 } },
			{ coins = 1200, items = { Cristallo_Ghiaccio = 4, Oro = 4 } },
			{ coins = 2100, items = { Nucleo_Glaciale = 2, Rubino = 2 } },
			{ coins = 3600, items = { Nucleo_Glaciale = 4, Cosmico = 2 } },
		},
		text = function(l)
			return string.format("Dragon XP +%d%%", math.floor(UpgradeConfig.UPGRADES[11].values.mult[l + 1] * 100 - 100 + 0.5))
		end,
	},
} :: { Upgrade }

-- dove si trovano i materiali dei potenziamenti (scheda del menu Upgrades e Crafting)
UpgradeConfig.SOURCES = {
	-- fasce di quota di mapgen/Ores (frazione dell'altezza della montagna)
	Carbone = "Ore veins at the foot of the mountain",
	Ferro = "Ore veins on the lower third of the mountain",
	Oro = "Ore veins in the lower half of the mountain",
	Cristallo = "Glowing veins in the middle of the mountain",
	Rubino = "High up: needs the Reinforced Pickaxe",
	Cosmico = "Near the summit: needs the Reinforced Pickaxe",
	Pelliccia_Yeti = "Dropped by Yetis, or craft it at the Workbench",
	Cristallo_Ghiaccio = "Dropped by Yetis and Ice Golems, or craft it",
	Nucleo_Glaciale = "Dropped by Ice Golems, or craft it at the Workbench",
} :: { [string]: string }

function UpgradeConfig.find(id: string): Upgrade?
	for _, u in UpgradeConfig.UPGRADES do
		if u.id == id then
			return u
		end
	end
	return nil
end

function UpgradeConfig.level(player: Player, id: string): number
	return (player:GetAttribute("Up_" .. id) or 0) :: number
end

-- valore "key" del potenziamento id al livello attuale del giocatore
function UpgradeConfig.value(player: Player, id: string, key: string): number
	local u = UpgradeConfig.find(id)
	if not u then
		return 0
	end
	local list = u.values[key]
	local l = math.clamp(UpgradeConfig.level(player, id), 0, u.max)
	return list[l + 1]
end

-- moltiplicatori dei potenziamenti del drago (1 se non comprati)
function UpgradeConfig.dragonDamage(player: Player): number
	return UpgradeConfig.value(player, "Furia", "mult")
end
function UpgradeConfig.dragonXp(player: Player): number
	return UpgradeConfig.value(player, "Addestramento", "mult")
end

------------------------------------------------------------------------------------------
-- Scudo: secondi senza colpi prima che si ricarichi, punti al secondo
UpgradeConfig.SHIELD_DELAY = 6
UpgradeConfig.SHIELD_REGEN = 12

------------------------------------------------------------------------------------------
-- Attacco speciale del drago (tasto Z): onda dell'elemento attorno a te
UpgradeConfig.SPECIAL = {
	COOLDOWN = 14, -- secondi (meno 0.1 per livello del drago, minimo 6)
	RADIUS = 26,
	DAMAGE = 30, -- + 2 per livello del drago
	SECOND = 0.6, -- col pass Extra Dragon ruggisce anche il secondo drago (parte del danno)
}
-- planata col drago: dal livello DRAGON_GLIDE_LEVEL il parapendio e' piu' veloce
UpgradeConfig.DRAGON_GLIDE_LEVEL = 15

-- Draghi "Shiny" (dorati): probabilita' alla schiusa, bonus esperienza e valore
UpgradeConfig.SHINY_CHANCE = 1 / 25
UpgradeConfig.SHINY_XP = 1.5
UpgradeConfig.SHINY_VALUE = 3

------------------------------------------------------------------------------------------
-- Parapendio (si costruisce al Banco: vedi Gear "Parapendio")
UpgradeConfig.GLIDE = {
	SPEED = 52, -- avanti
	FALL = 9, -- giu'
	DRAGON_SPEED = 72,
	MIN_FALL_SPEED = 12, -- si apre solo cadendo (Spazio in aria)
}

------------------------------------------------------------------------------------------
-- Rinascita: dopo essere arrivato in vetta puoi ricominciare (monete, minerali e potenziamenti
-- tornano a zero; draghi, attrezzi e casa restano) con un bonus permanente
UpgradeConfig.REBIRTH = {
	MIN_COINS = 2500, -- monete che servono (e che si perdono)
	COIN_BONUS = 0.15, -- +15% monete per ogni rinascita
	XP_BONUS = 0.15, -- +15% esperienza ai draghi
}

function UpgradeConfig.coinMult(player: Player): number
	return 1 + ((player:GetAttribute("Rebirths") or 0) :: number) * UpgradeConfig.REBIRTH.COIN_BONUS
end

function UpgradeConfig.xpMult(player: Player): number
	return 1 + ((player:GetAttribute("Rebirths") or 0) :: number) * UpgradeConfig.REBIRTH.XP_BONUS
end

------------------------------------------------------------------------------------------
-- Nemici piu' forti salendo: livello = 1 + quota / ZONE_STEP
UpgradeConfig.ZONE_STEP = 450
UpgradeConfig.ZONE_HEALTH = 0.3 -- +30% vita per livello
UpgradeConfig.ZONE_DAMAGE = 0.15
UpgradeConfig.ZONE_REWARD = 0.35

------------------------------------------------------------------------------------------
-- Taglie: tre alla volta, quando ne finisci una la riscuoti e ne arriva un'altra. Piu' una
-- sfida del giorno (cambia a mezzanotte UTC) con un premio grande.
-- stat = contatore del giocatore (attributo) che deve crescere di "need"
export type Bounty = { id: string, text: string, stat: string, need: { number }, coins: number, items: { [string]: number }? }
UpgradeConfig.BOUNTIES = {
	{ id = "Yeti", text = "Defeat %d Yetis", stat = "Kills_Yeti", need = { 3, 5, 8 }, coins = 60, items = { Pelliccia_Yeti = 1 } },
	{ id = "Golem", text = "Defeat %d Ice Golems", stat = "Kills_GolemGhiaccio", need = { 2, 3, 5 }, coins = 110, items = { Nucleo_Glaciale = 1 } },
	{ id = "Ores", text = "Mine %d ores", stat = "OresMined", need = { 10, 20, 35 }, coins = 8 },
	{ id = "Climb", text = "Climb %d meters", stat = "MetersClimbed", need = { 150, 300, 600 }, coins = 1 },
	{ id = "Eggs", text = "Bring %d eggs to your nest", stat = "EggsIncubated", need = { 1, 2, 3 }, coins = 150 },
	{ id = "Plunge", text = "Hit %d enemies with a Plunge or Grapple Strike", stat = "AirHits", need = { 2, 4, 6 }, coins = 80 },
	{ id = "Special", text = "Use your dragon's special attack %d times", stat = "Specials", need = { 3, 6, 10 }, coins = 30 },
} :: { Bounty }
UpgradeConfig.DAILY = {
	{ text = "Reach the summit", stat = "Summits", need = 1, coins = 1500 },
	{ text = "Defeat a boss (Yeti King, Ice Titan, a wild dragon or the Summit Guardian)", stat = "BossKills", need = 1, coins = 1200 },
	{ text = "Defeat 15 enemies", stat = "Kills", need = 15, coins = 900 },
	{ text = "Finish a descent from the summit", stat = "Descents", need = 1, coins = 1000 },
	{ text = "Mine 50 ores", stat = "OresMined", need = 50, coins = 800 },
}

------------------------------------------------------------------------------------------
-- Eventi della mappa (uno ogni EVERY secondi, a caso)
UpgradeConfig.EVENTS = {
	EVERY = { 360, 600 },
	METEORS = 7, -- meteore per pioggia
	METEOR_REWARD = { Cosmico = 2, Cristallo = 1 },
	RAID_SECONDS = 150, -- durata dell'attacco del drago selvatico
	AVALANCHE_REWARD = 120, -- monete a chi sopravvive alla grande valanga
}

-- Colpo del drago in monta (click o F, server/Enemies "RideAttack"): danno = attacco del drago x
-- DAMAGE_MULT, palla dell'elemento lunga al massimo RANGE, area RADIUS
UpgradeConfig.RIDE_SHOT = { COOLDOWN = 0.7, RANGE = 220, SPEED = 260, RADIUS = 13, DAMAGE_MULT = 1.4,
	WING = 0.5, -- in monta il secondo drago (Extra Dragon) vola accanto e spara insieme (parte del danno)
	WING_DELAY = 0.22 }
-- ogni drago colpisce in modo diverso (in monta): area (radius) e danno (damage) rispetto a
-- RIDE_SHOT, stordimento e rallentamento (secondi), rimbalzi del fulmine (chain, a meta' danno),
-- danno nel tempo (dot: frazione del colpo divisa in 4 tocchi in 2 s, nella stessa area)
export type RideElement = { radius: number, damage: number, stun: number?, slow: number?, crit: number?, chain: number?, dot: number?, text: string }
UpgradeConfig.RIDE_ELEMENT = {
	Roccia = { radius = 1.4, damage = 1.1, stun = 1, text = "Boulder: wide area, stuns" },
	Gelo = { radius = 1, damage = 0.9, slow = 3, text = "Ice lance: slows enemies" },
	Cosmico = { radius = 1.2, damage = 1, crit = 2, text = "Comet: double critical chance" },
	Tempesta = { radius = 1.7, damage = 0.85, text = "Hurricane: the widest area" },
	Eclissi = { radius = 1, damage = 1.2, dot = 0.5, text = "Solar serpent: burns" },
	Fulmine = { radius = 0.8, damage = 1, chain = 3, text = "Black lightning: jumps to 3 more enemies" },
	Ossa = { radius = 1, damage = 1.15, stun = 0.6, text = "Bone spear: heavy hit, stuns" },
	Gas = { radius = 1.3, damage = 0.6, dot = 1.2, text = "Toxic orb: poison cloud" },
} :: { [string]: RideElement }

-- Draghi volanti (drago selvatico e guardiano della vetta)
export type Flyer = { name: string, element: string, health: number, damage: number, radius: number, height: number, speed: number, coins: number, xp: number, scale: number }
UpgradeConfig.WILD_DRAGON = {
	name = "Wild Dragon", element = "Gelo", health = 900, damage = 22, radius = 60, height = 45, speed = 0.35,
	coins = 500, xp = 400, scale = 1.6,
} :: Flyer
UpgradeConfig.GUARDIAN = {
	name = "Summit Guardian", element = "Eclissi", health = 4000, damage = 38, radius = 85, height = 70, speed = 0.22,
	coins = 2500, xp = 1500, scale = 2.4,
} :: Flyer
UpgradeConfig.GUARDIAN_RESPAWN = 900


return UpgradeConfig
