--!strict
-- Draghi e uova: elementi, rarita', tempi di cova, abilita', evoluzione, admin e gamepass.
-- Una sola razza (i draghi) in piu' elementi: ogni elemento nasce da un uovo trovato in una
-- zona diversa dell'isola e ha un'abilita' che aiuta a scalare.
--
-- Modelli: metti in ServerStorage una cartella "Draghi" (o "Dragons") e una "Uova" (o
-- "Eggs"). Se il nome di un modello contiene una parola dell'elemento (vedi WORDS) viene
-- usato per quell'elemento, altrimenti i modelli vengono usati a turno e ricolorati.
-- Senza modelli si usano draghetti e uova costruiti a blocchi.

export type Element = {
	id: string,
	name: string,
	color: Color3,
	accent: Color3,
	glow: Color3,
	ability: string,
	words: { string },
}

local DragonConfig = {}

-- Solo gli elementi che hanno un uovo vero (i modelli Uovo_<Elemento> in ServerStorage.Uova)
DragonConfig.ALTAR_RESPAWN = 600 -- secondi prima che sugli altari ricompaia l'uovo leggendario
DragonConfig.SUMMIT_EGG = "Cosmico" -- elemento dell'uovo leggendario sull'altare della vetta
-- elementi tolti (Mirko: restano solo 8 draghi). Le voci in ELEMENTS restano per i draghi gia'
-- salvati, ma nessun uovo nuovo nasce di questi elementi: diventano quello a destra
DragonConfig.RETIRED = { Sole = "Cosmico", Ombra = "Eclissi", Brace = "Roccia" } :: { [string]: string }
DragonConfig.STARTER_DRAGON = "Eclissi" -- il drago che ricevi al primo accesso

DragonConfig.ELEMENTS = {
	{
		id = "Roccia",
		name = "Drago Roccia",
		color = Color3.fromRGB(128, 118, 104),
		accent = Color3.fromRGB(70, 64, 58),
		glow = Color3.fromRGB(230, 200, 140),
		ability = "Reveals crumbly rock and nearby ore veins",
		words = { "rock", "roccia", "stone", "pietra", "earth", "terra", "ground" },
	},
	{
		id = "Brace",
		name = "Drago Brace",
		color = Color3.fromRGB(200, 70, 40),
		accent = Color3.fromRGB(40, 30, 28),
		glow = Color3.fromRGB(255, 140, 50),
		ability = "Keeps you warm (no cold up high) and lights the night",
		words = { "fire", "fuoco", "brace", "lava", "flame", "fiamma", "ember", "magma" },
	},
	{
		id = "Gelo",
		name = "Drago Gelo",
		color = Color3.fromRGB(190, 230, 250),
		accent = Color3.fromRGB(90, 150, 200),
		glow = Color3.fromRGB(160, 230, 255),
		ability = "Grip on ice even without Crampons",
		words = { "ice", "ghiaccio", "gelo", "frost", "snow", "neve", "cryo", "frozen" },
	},
	{
		id = "Cosmico",
		name = "Drago Cosmico",
		color = Color3.fromRGB(110, 60, 200),
		accent = Color3.fromRGB(255, 0, 191),
		glow = Color3.fromRGB(220, 90, 255),
		ability = "Double jump (Space in mid-air)",
		words = { "cosmic", "cosmico", "space", "spazio", "void", "star", "stella", "galaxy", "black hole" },
	},
	{
		id = "Tempesta",
		name = "Drago Tempesta",
		color = Color3.fromRGB(80, 100, 150),
		accent = Color3.fromRGB(230, 240, 255),
		glow = Color3.fromRGB(150, 200, 255),
		ability = "Wind no longer pushes or tires you",
		words = { "tempesta", "storm", "thunder", "tuono" }, -- "fulmine" e' del drago Fulmine Nero
	},
	{
		id = "Sole",
		name = "Drago Sole",
		color = Color3.fromRGB(250, 190, 70),
		accent = Color3.fromRGB(255, 245, 200),
		glow = Color3.fromRGB(255, 225, 120),
		ability = "Climb 20% faster",
		words = { "sole", "sun", "solar", "solare", "light", "luce" },
	},
	{
		id = "Ombra",
		name = "Drago Ombra",
		color = Color3.fromRGB(45, 35, 60),
		accent = Color3.fromRGB(150, 80, 220),
		glow = Color3.fromRGB(170, 100, 255),
		ability = "Falls deal half damage",
		words = { "ombra", "shadow", "dark", "buio", "oscur" },
	},
	{
		id = "Eclissi",
		name = "Drago Eclissi",
		color = Color3.fromRGB(30, 28, 34),
		accent = Color3.fromRGB(240, 236, 230),
		glow = Color3.fromRGB(255, 150, 50),
		ability = "Sees in the dark: lights your way at night and in caves",
		words = { "eclissi", "eclipse" },
	},
	{
		id = "Fulmine",
		name = "Drago Fulmine Nero",
		color = Color3.fromRGB(35, 30, 50),
		accent = Color3.fromRGB(150, 110, 255),
		glow = Color3.fromRGB(170, 140, 255),
		ability = "Grappling Hook recharges twice as fast and you run faster",
		words = { "fulmine", "lightning", "thunderbolt" },
	},
	{
		id = "Ossa",
		name = "Drago Ossa",
		color = Color3.fromRGB(225, 220, 205),
		accent = Color3.fromRGB(90, 80, 70),
		glow = Color3.fromRGB(200, 255, 220),
		ability = "Senses eggs: points you to the nearest one",
		words = { "ossa", "bone", "skeleton", "scheletro" },
	},
	{
		id = "Gas",
		name = "Drago Gas",
		color = Color3.fromRGB(50, 80, 210),
		accent = Color3.fromRGB(240, 80, 220),
		glow = Color3.fromRGB(90, 220, 255),
		ability = "Immune to toxic gas",
		words = { "gas", "toxic", "tossico", "poison", "veleno" },
	},
} :: { Element }

-- Rarita': weight = probabilita' relativa, hatchMinutes = tempo di cova, scale = grandezza
DragonConfig.RARITIES = {
	{ id = "Comune", weight = 60, hatchMinutes = 5, color = Color3.fromRGB(210, 210, 210), sparkle = false },
	{ id = "Raro", weight = 28, hatchMinutes = 15, color = Color3.fromRGB(90, 170, 255), sparkle = false },
	{ id = "Epico", weight = 10, hatchMinutes = 40, color = Color3.fromRGB(190, 90, 255), sparkle = true },
	{ id = "Leggendario", weight = 2, hatchMinutes = 90, color = Color3.fromRGB(255, 200, 60), sparkle = true },
}

-- Stadi di crescita: dimensione del drago (studs) e pietre dell'evoluzione per arrivarci.
-- Per evolvere il drago deve essere a livello MAX_LEVEL (si addestra nella zona di addestramento)
-- e servono le pietre dell'evoluzione: si vincono nel Duello dei draghi (arena), battendo il
-- Guardiano della vetta o il drago selvatico degli eventi. Dopo l'evoluzione riparte dal livello 1.
DragonConfig.STAGES = {
	{ name = "Cucciolo", size = 8.6, stones = 0 }, -- scala del modello ~0.6 (prima 5.5 = 0.383)
	{ name = "Giovane", size = 14, stones = 1 },
	{ name = "Adulto", size = 33, stones = 2 }, -- prima 22: Mirko lo trovava troppo piccolo
}

-- Livelli e addestramento (zona delle costole del drago, vedi server/Training)
DragonConfig.MAX_LEVEL = 100
DragonConfig.TRAINING = {
	TARGET_XP = 14, -- XP per ogni colpo a un bersaglio
	TARGET_COOLDOWN = 1.1, -- secondi tra un colpo e l'altro
	CIRCLE_XP = 3, -- XP al secondo stando nel cerchio di addestramento
	CIRCLE_RADIUS = 36, -- copre tutto il simbolo al centro dell'arena (arena in scala 2)
	TARGETS = 6,
	CRYSTAL_RING = 56, -- i cristalli-bersaglio girano attorno al cerchio a questa distanza
	SHOT_COOLDOWN = 0.6, -- secondi tra un colpo e l'altro (si mira col mouse dalla vista del drago)
	GROWTH = 0.2, -- a livello 100 il drago e' piu' grande del 20% rispetto al livello 1
	-- sfida "Target Rush": RUSH_SECONDS di tempo, si accende un cristallo dorato alla volta
	RUSH_SECONDS = 40,
	RUSH_XP = 30, -- XP per il cristallo dorato (gli altri danno TARGET_XP)
	RUSH_EVERY = 4, -- secondi prima che il cristallo dorato cambi (si corre da un cristallo all'altro)
	RUSH_COOLDOWN = 40, -- secondi tra una sfida e l'altra
	-- moltiplicatori dell'XP di addestramento (si sommano moltiplicando)
	PASS_MULT = 2, -- gamepass TrainingX2
	BOOST_MULT = 3, -- prodotto TrainingBoost
	BOOST_MINUTES = 15,
	PREMIUM_MULT = 1.2, -- abbonati Roblox Premium
}

-- Duello dei draghi (arena, server/Training): tre round contro draghi rivali sempre piu' forti.
-- Le vite sono in "colpi": il rivale regge HITS[round] colpi del tuo drago (sempre equilibrato,
-- cucciolo o adulto), il tuo drago regge TAKES[round] palle del rivale. Ogni duello vinto alza il
-- grado (attributo DuelTier, salvato): rivali piu' duri, premi piu' grandi.
DragonConfig.DUEL = {
	ROUNDS = 3,
	HITS = { 12, 16, 22 }, -- colpi del tuo drago per battere il rivale di ogni round (grado 1)
	TAKES = { 7, 6, 5 }, -- palle del rivale che il tuo drago regge
	TIER_HP = 0.15, -- +15% di vita al rivale per ogni grado
	EVERY = { 3.2, 2.7, 2.2 }, -- secondi tra un attacco e l'altro del rivale
	SCALE = { 0.9, 1.1, 1.5 }, -- grandezza del rivale (1 = 22 studs); il terzo e' il Campione
	NAMES = { "Rival Dragon", "Arena Veteran", "Arena Champion" },
	DODGE_WINDOW = 0.9, -- schivata (Spazio) valida per le palle in volo in quel momento
	DODGE_COOLDOWN = 1.6,
	ROUND_PAUSE = 3,
	COOLDOWN = 30, -- secondi tra un duello e l'altro
	STONES = 1, -- pietre dell'evoluzione a vittoria (+1 dal grado 3, +1 dal grado 6)
	COINS = 250, -- x grado
	XP = 120, -- x grado, al drago
	RIVAL_ORBIT = 46, -- raggio dei giri del rivale
}

-- Dove vola il tuo drago nell'arena al tempo t (secondi del server): server e client usano la
-- stessa formula (il server sa dove mira il rivale; la schivata la aggiunge il client)
function DragonConfig.arenaDragonAt(center: Vector3, t: number): Vector3
	local a = t * 0.3
	return center + Vector3.new(math.cos(a) * 26, 20 + math.sin(a * 2.3) * 4, math.sin(a) * 26)
end

-- Posizione di un cristallo-bersaglio del campo d'addestramento al tempo t (secondi del server):
-- girano attorno al cerchio a quote e velocita' diverse, meta' in un verso e meta' nell'altro,
-- avvicinandosi e allontanandosi dal centro. Server e client usano la stessa formula: il server
-- sa sempre dov'e' un cristallo e controlla i colpi.
function DragonConfig.crystalAt(center: Vector3, index: number, t: number): Vector3
	local TR = DragonConfig.TRAINING
	local dir = if index % 2 == 0 then -1 else 1
	local speed = 0.22 + 0.05 * (index % 3)
	local r = TR.CRYSTAL_RING + 7 * math.sin(index * 1.7) + 6 * math.sin(t * 0.5 + index * 0.9)
	local a = (index - 0.5) / TR.TARGETS * 2 * math.pi + dir * speed * t
	local h = 15 + 5 * math.sin(index * 2.3) + 3 * math.sin(t * 1.3 + index)
	return center + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
end

-- XP per passare dal livello "level" al successivo (dal livello 1 al 100: circa 22 000 XP)
function DragonConfig.xpForLevel(level: number): number
	return 25 + level * 4
end

-- Statistiche di ogni drago, tirate a sorte quando nasce (ogni uovo da' un drago diverso):
--   atk   moltiplicatore dell'attacco (le rarita' alte partono piu' in alto)
--   crit  probabilita' di colpo critico (danno x2)
-- Voto: C, B, A, S secondo quanto e' venuto bene il tiro rispetto alla sua rarita'.
DragonConfig.STAT_RANGES = {
	Comune = { atk = { 0.85, 1.10 }, crit = { 0.03, 0.08 } },
	Raro = { atk = { 0.95, 1.22 }, crit = { 0.05, 0.11 } },
	Epico = { atk = { 1.05, 1.35 }, crit = { 0.07, 0.14 } },
	Leggendario = { atk = { 1.18, 1.50 }, crit = { 0.10, 0.18 } },
}
-- l'adulto picchia molto piu' del cucciolo (prima facevano lo stesso danno)
DragonConfig.STAGE_POWER = { 1, 1.9, 3.2 }
DragonConfig.BASE_DAMAGE = 8

function DragonConfig.rollStats(rarity: string): (number, number)
	local r = DragonConfig.STAT_RANGES[rarity] or DragonConfig.STAT_RANGES.Comune
	local function roll(range: { number }): number
		-- due tiri, si tiene la media: i valori estremi sono piu' rari
		local a = (math.random() + math.random()) / 2
		return math.floor((range[1] + (range[2] - range[1]) * a) * 1000 + 0.5) / 1000
	end
	return roll(r.atk), roll(r.crit)
end

-- voto del drago (C/B/A/S) e quanto vale il tiro da 0 a 1
function DragonConfig.grade(d: any): (string, number)
	local r = DragonConfig.STAT_RANGES[d.rarity] or DragonConfig.STAT_RANGES.Comune
	local a = ((d.atk or 1) - r.atk[1]) / (r.atk[2] - r.atk[1])
	local c = ((d.crit or 0.05) - r.crit[1]) / (r.crit[2] - r.crit[1])
	local q = math.clamp(a * 0.7 + c * 0.3, 0, 1)
	return (if q >= 0.8 then "S" elseif q >= 0.6 then "A" elseif q >= 0.35 then "B" else "C"), q
end

-- attacco del drago: base x stadio x livello x statistica
function DragonConfig.attack(d: any): number
	local stage = DragonConfig.STAGE_POWER[math.clamp(d.stage or 1, 1, #DragonConfig.STAGE_POWER)]
	local lv = math.clamp(d.level or 1, 1, DragonConfig.MAX_LEVEL)
	return DragonConfig.BASE_DAMAGE * stage * (1 + 0.012 * (lv - 1)) * (d.atk or 1)
end

-- Grandezza del drago a un certo stadio e livello (studs)
function DragonConfig.dragonSize(stage: number, level: number?): number
	local st = DragonConfig.STAGES[math.clamp(stage, 1, #DragonConfig.STAGES)]
	local lv = math.clamp(level or 1, 1, DragonConfig.MAX_LEVEL)
	return st.size * (1 + DragonConfig.TRAINING.GROWTH * (lv - 1) / (DragonConfig.MAX_LEVEL - 1))
end

-- Uova nel mondo
-- Animazioni del drago Ombra (rig Drago_Ombra_Rig nell'Animation Editor). Vuote = in Studio si
-- usano quelle salvate in ServerStorage.RBX_ANIMSAVES; senza animazioni si muove a procedura.
-- Nel gioco pubblicato: Publish to Roblox dall'editor e incolla qui gli ID (rbxassetid://...)
DragonConfig.FLY_ANIM = ""
DragonConfig.WALK_ANIM = ""
DragonConfig.IDLE_ANIM = ""

-- Animazioni di ogni modello di drago (rig in Workspace.RigDraghi, salvataggi in
-- RBX_ANIMSAVES.<nome>: drago-volo, drago-cammina, drago-fermo; le genera
-- MapGen.AnimDraghi). In Studio si usano i salvataggi; nel gioco pubblicato servono gli ID:
--   Drago_Gelo = { fly = "rbxassetid://...", walk = "rbxassetid://...", idle = "rbxassetid://..." },
DragonConfig.DRAGON_ANIMS = {} :: { [string]: { fly: string, walk: string, idle: string } }

DragonConfig.MAX_WORLD_EGGS = 30
DragonConfig.EGG_RESPAWN_SECONDS = 45
DragonConfig.EGG_SIZE = 2.6
DragonConfig.INCUBATOR_SLOTS = 3
DragonConfig.MAX_EQUIPPED = 1
DragonConfig.MAX_DRAGONS = 60
-- trasportare un uovo occupa le mani: si scala piu' piano
DragonConfig.CARRY_CLIMB_FACTOR = 0.75

-- Gamepass (crea i pass su create.roblox.com e metti qui gli ID; 0 = disattivato)
DragonConfig.GAMEPASSES = {
	-- ID creati da Mirko il 2026-10-14 (Creator Hub > Monetizzazione > Pass)
	FastIncubation = 2034038497, -- cova in meta' tempo (299 Robux)
	EggFinder = 2032484502, -- bussola verso l'uovo piu' vicino (1299)
	ExtraDragon = 2032430530, -- +1 drago che ti segue (999)
	ExtraIncubator = 2033720485, -- +2 posti nel nido (399)
	TrainingX2 = 2035868268, -- XP di addestramento x2 per sempre (399)
}

-- Admin: UserId che possono usare i comandi (in Studio e il proprietario del gioco sempre)
DragonConfig.ADMINS = {} :: { number }

function DragonConfig.element(id: string): Element?
	for _, e in DragonConfig.ELEMENTS do
		if e.id == id then
			return e
		end
	end
	return nil
end

function DragonConfig.rarity(id: string): any
	for _, r in DragonConfig.RARITIES do
		if r.id == id then
			return r
		end
	end
	return DragonConfig.RARITIES[1]
end

-- Il giocatore ha un drago al seguito con questa abilita' (= id dell'elemento)?
function DragonConfig.hasAbility(player: Player, id: string): boolean
	local list = player:GetAttribute("PetAbilities")
	return type(list) == "string" and string.find(list, id, 1, true) ~= nil
end

-- Elemento che corrisponde a un nome di modello (nil se nessuna parola combacia)
function DragonConfig.elementForName(name: string): string?
	local lower = string.lower(name)
	for _, e in DragonConfig.ELEMENTS do
		for _, w in e.words do
			if string.find(lower, w, 1, true) then
				return e.id
			end
		end
	end
	return nil
end

return DragonConfig
