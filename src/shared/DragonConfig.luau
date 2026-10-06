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
DragonConfig.SUMMIT_EGG = "Sole" -- elemento dell'uovo leggendario sull'altare della vetta
DragonConfig.STARTER_DRAGON = "Eclissi" -- il drago che ricevi al primo accesso

DragonConfig.ELEMENTS = {
	{
		id = "Roccia",
		name = "Drago Roccia",
		color = Color3.fromRGB(128, 118, 104),
		accent = Color3.fromRGB(70, 64, 58),
		glow = Color3.fromRGB(230, 200, 140),
		ability = "Ti mostra le rocce friabili e i giacimenti vicini",
		words = { "rock", "roccia", "stone", "pietra", "earth", "terra", "ground" },
	},
	{
		id = "Brace",
		name = "Drago Brace",
		color = Color3.fromRGB(200, 70, 40),
		accent = Color3.fromRGB(40, 30, 28),
		glow = Color3.fromRGB(255, 140, 50),
		ability = "Ti scalda (niente freddo in quota) e fa luce di notte",
		words = { "fire", "fuoco", "brace", "lava", "flame", "fiamma", "ember", "magma" },
	},
	{
		id = "Gelo",
		name = "Drago Gelo",
		color = Color3.fromRGB(190, 230, 250),
		accent = Color3.fromRGB(90, 150, 200),
		glow = Color3.fromRGB(160, 230, 255),
		ability = "Presa sul ghiaccio anche senza Ramponi",
		words = { "ice", "ghiaccio", "gelo", "frost", "snow", "neve", "cryo", "frozen" },
	},
	{
		id = "Cosmico",
		name = "Drago Cosmico",
		color = Color3.fromRGB(110, 60, 200),
		accent = Color3.fromRGB(255, 0, 191),
		glow = Color3.fromRGB(220, 90, 255),
		ability = "Doppio salto (Spazio a mezz'aria)",
		words = { "cosmic", "cosmico", "space", "spazio", "void", "star", "stella", "galaxy", "black hole" },
	},
	{
		id = "Tempesta",
		name = "Drago Tempesta",
		color = Color3.fromRGB(80, 100, 150),
		accent = Color3.fromRGB(230, 240, 255),
		glow = Color3.fromRGB(150, 200, 255),
		ability = "Il vento non ti spinge e non ti stanca",
		words = { "tempesta", "storm", "thunder", "tuono" }, -- "fulmine" e' del drago Fulmine Nero
	},
	{
		id = "Sole",
		name = "Drago Sole",
		color = Color3.fromRGB(250, 190, 70),
		accent = Color3.fromRGB(255, 245, 200),
		glow = Color3.fromRGB(255, 225, 120),
		ability = "Sali il 20% piu' veloce",
		words = { "sole", "sun", "solar", "solare", "light", "luce" },
	},
	{
		id = "Ombra",
		name = "Drago Ombra",
		color = Color3.fromRGB(45, 35, 60),
		accent = Color3.fromRGB(150, 80, 220),
		glow = Color3.fromRGB(170, 100, 255),
		ability = "Le cadute fanno meta' danno",
		words = { "ombra", "shadow", "dark", "buio", "oscur" },
	},
	{
		id = "Eclissi",
		name = "Drago Eclissi",
		color = Color3.fromRGB(30, 28, 34),
		accent = Color3.fromRGB(240, 236, 230),
		glow = Color3.fromRGB(255, 150, 50),
		ability = "Vede al buio: di notte e nelle grotte ti fa luce",
		words = { "eclissi", "eclipse" },
	},
	{
		id = "Fulmine",
		name = "Drago Fulmine Nero",
		color = Color3.fromRGB(35, 30, 50),
		accent = Color3.fromRGB(150, 110, 255),
		glow = Color3.fromRGB(170, 140, 255),
		ability = "Il Rampino si ricarica in meta' tempo e corri piu' veloce",
		words = { "fulmine", "lightning", "thunderbolt" },
	},
	{
		id = "Ossa",
		name = "Drago Ossa",
		color = Color3.fromRGB(225, 220, 205),
		accent = Color3.fromRGB(90, 80, 70),
		glow = Color3.fromRGB(200, 255, 220),
		ability = "Sente le uova: ti indica la piu' vicina",
		words = { "ossa", "bone", "skeleton", "scheletro" },
	},
	{
		id = "Gas",
		name = "Drago Gas",
		color = Color3.fromRGB(50, 80, 210),
		accent = Color3.fromRGB(240, 80, 220),
		glow = Color3.fromRGB(90, 220, 255),
		ability = "Immune ai gas tossici",
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
-- Per evolvere il drago deve essere a livello MAX_LEVEL (si addestra nella zona di addestramento);
-- dopo l'evoluzione riparte dal livello 1. Le pietre per ora sono 0: il boss non c'e' ancora.
DragonConfig.STAGES = {
	{ name = "Cucciolo", size = 5.5, stones = 0 },
	{ name = "Giovane", size = 10, stones = 0 },
	{ name = "Adulto", size = 18, stones = 0 },
}

-- Livelli e addestramento (zona delle costole del drago, vedi server/Training)
DragonConfig.MAX_LEVEL = 100
DragonConfig.TRAINING = {
	TARGET_XP = 14, -- XP per ogni colpo a un bersaglio
	TARGET_COOLDOWN = 1.1, -- secondi tra un colpo e l'altro
	CIRCLE_XP = 3, -- XP al secondo stando nel cerchio di addestramento
	CIRCLE_RADIUS = 16,
	TARGETS = 6,
	CRYSTAL_RING = 38, -- i cristalli-bersaglio girano attorno al cerchio a questa distanza
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
	local h = 9 + 4 * math.sin(index * 2.3) + 2.5 * math.sin(t * 1.3 + index)
	return center + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
end

-- XP per passare dal livello "level" al successivo (dal livello 1 al 100: circa 22 000 XP)
function DragonConfig.xpForLevel(level: number): number
	return 25 + level * 4
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
	FastIncubation = 0, -- cova in meta' tempo
	EggFinder = 0, -- bussola verso l'uovo piu' vicino
	ExtraDragon = 0, -- +1 drago che ti segue
	ExtraIncubator = 0, -- +2 posti nel nido
	TrainingX2 = 0, -- XP di addestramento x2 per sempre
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
