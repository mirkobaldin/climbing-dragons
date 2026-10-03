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
DragonConfig.ALTAR_RESPAWN = 600 -- secondi prima che sull'altare ricompaia l'uovo Ombra

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
		words = { "tempesta", "storm", "thunder", "tuono", "fulmine", "lightning" },
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
} :: { Element }

-- Rarita': weight = probabilita' relativa, hatchMinutes = tempo di cova, scale = grandezza
DragonConfig.RARITIES = {
	{ id = "Comune", weight = 60, hatchMinutes = 5, color = Color3.fromRGB(210, 210, 210), sparkle = false },
	{ id = "Raro", weight = 28, hatchMinutes = 15, color = Color3.fromRGB(90, 170, 255), sparkle = false },
	{ id = "Epico", weight = 10, hatchMinutes = 40, color = Color3.fromRGB(190, 90, 255), sparkle = true },
	{ id = "Leggendario", weight = 2, hatchMinutes = 90, color = Color3.fromRGB(255, 200, 60), sparkle = true },
}

-- Stadi di crescita: dimensione del drago (studs) e pietre dell'evoluzione per arrivarci
DragonConfig.STAGES = {
	{ name = "Cucciolo", size = 5.5, stones = 0 },
	{ name = "Giovane", size = 8.5, stones = 1 },
	{ name = "Adulto", size = 13, stones = 3 },
}

-- Uova nel mondo
-- Animazioni del drago Ombra (rig Drago_Ombra_Rig nell'Animation Editor). Vuote = in Studio si
-- usano quelle salvate in ServerStorage.RBX_ANIMSAVES; senza animazioni si muove a procedura.
-- Nel gioco pubblicato: Publish to Roblox dall'editor e incolla qui gli ID (rbxassetid://...)
DragonConfig.FLY_ANIM = ""
DragonConfig.WALK_ANIM = ""
DragonConfig.IDLE_ANIM = ""

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
