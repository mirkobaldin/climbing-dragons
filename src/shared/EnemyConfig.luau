--!strict
-- Nemici: yeti (in alta quota, vicino alle uova) e golem di ghiaccio (ghiacciai e grotte di
-- ghiaccio). Modelli in ServerStorage.Nemici, rig per l'Animation Editor in Workspace.RigNemici,
-- animazioni generate da MapGen.AnimNemici (nemico-cammina, nemico-fermo, nemico-attacco).

local ClimbConfig = require(script.Parent.ClimbConfig)

local EnemyConfig = {}

export type EnemyType = {
	name: string, -- nome mostrato sopra la barra della vita
	height: number, -- altezza del modello in gioco (studs)
	health: number,
	speed: number,
	damage: number,
	reach: number, -- distanza del colpo
	cooldown: number, -- secondi tra un attacco e l'altro
	hitAt: number, -- secondi dall'inizio dell'animazione di attacco al colpo
	knockback: number, -- spinta del colpo
	aggro: number, -- vede i giocatori entro questa distanza
	leash: number, -- non si allontana dalla tana piu' di cosi'
	coins: number, -- ricompensa (divisa tra chi lo ha colpito)
	xp: number, -- esperienza ai draghi di chi lo ha colpito
	count: number, -- quanti nella mappa
	respawn: number, -- secondi prima che ne ricompaia uno
}

EnemyConfig.TYPES = {
	Yeti = {
		name = "Yeti",
		height = 10,
		health = 140,
		speed = 14,
		damage = 18,
		reach = 7,
		cooldown = 1.6,
		hitAt = 0.5,
		knockback = 35,
		aggro = 55,
		leash = 120,
		coins = 15,
		xp = 30,
		count = 7,
		respawn = 90,
	},
	GolemGhiaccio = {
		name = "Ice Golem",
		height = 15,
		health = 300,
		speed = 9,
		damage = 32,
		reach = 10,
		cooldown = 2.4,
		hitAt = 0.5,
		knockback = 70,
		aggro = 45,
		leash = 90,
		coins = 40,
		xp = 70,
		count = 5,
		respawn = 120,
	},
} :: { [string]: EnemyType }

-- Capi: uno per tana, nella sala di ghiaccio (attributo <den> del Workspace, lo scrive il
-- generatore della mappa). kind = modello di ServerStorage.Nemici; throne = aspetta seduto sul
-- trono di ghiaccio finche' non arrivi.
export type Boss = EnemyType & { kind: string, den: string, throne: boolean }
EnemyConfig.BOSSES = {
	{
		kind = "Yeti", den = "GrandCaveDen", throne = true,
		name = "Yeti King", height = 20, health = 1400, speed = 13, damage = 34, reach = 13,
		cooldown = 2, hitAt = 0.5, knockback = 90, aggro = 75, leash = 140, coins = 200, xp = 450,
		count = 1, respawn = 600,
	},
	{
		kind = "GolemGhiaccio", den = "CraterCaveDen", throne = false,
		name = "Ice Titan", height = 34, health = 2600, speed = 8, damage = 48, reach = 20,
		cooldown = 2.8, hitAt = 0.5, knockback = 130, aggro = 80, leash = 120, coins = 400, xp = 900,
		count = 1, respawn = 900,
	},
} :: { Boss }

-- Danno dei tuoi colpi (click con l'attrezzo in mano vicino al nemico)
-- (per nome del Tool: prima erano "Piccozza"/"Piccone" e dopo i nomi in inglese i colpi non
-- facevano piu' danno)
EnemyConfig.PLAYER_DAMAGE = { [ClimbConfig.TOOL_NAME] = 22, [ClimbConfig.PICKAXE_NAME] = 16 } :: { [string]: number }
EnemyConfig.PLAYER_REACH = 11
EnemyConfig.PLAYER_COOLDOWN = 0.55
-- Il drago al seguito aiuta: un colpo ogni DRAGON_EVERY secondi (danno + 0.15 per livello)
EnemyConfig.DRAGON_EVERY = 2
EnemyConfig.DRAGON_DAMAGE = 8

-- Animazioni nel gioco pubblicato (in Studio si usano i salvataggi di RBX_ANIMSAVES):
--   Yeti = { walk = "rbxassetid://...", idle = "rbxassetid://...", attack = "rbxassetid://..." },
EnemyConfig.ANIMS = {} :: { [string]: { walk: string, idle: string, attack: string } }

return EnemyConfig
