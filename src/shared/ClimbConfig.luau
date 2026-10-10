--!strict
-- Parametri di gioco condivisi tra server e client (arrampicata, corde, meteo).

local ClimbConfig = {
	-- nomi dei Tool (si leggono nello zaino): i modelli in ServerStorage possono chiamarsi ancora
	-- "Piccozza", "Piccone", "Rampino", "Torcia" (vedi server/Tools)
	TOOL_NAME = "Ice Axe",
	PICKAXE_NAME = "Pickaxe",
	GRAPPLE_NAME = "Grappling Hook",
	TORCH_NAME = "Torch",

	-- Arrampicata
	WALL_MAX_NORMAL_Y = 0.55, -- una superficie e' "parete" se la sua normale ha Y sotto questo (> ~57 gradi)
	REACH = 3.5, -- distanza massima dalla parete per aggrapparsi
	BODY_OFFSET = 1.7, -- distanza del corpo dalla parete mentre scali
	CLIMB_SPEED = 11,
	-- Ritmo delle trazioni: senza questo si sale a velocita' costante e sembra un ascensore.
	-- PULL_RATE e' in radianti al secondo (2*pi = una trazione), SURGE quanto spinge ogni
	-- trazione (0.6 = si va da 0.4x a 1.6x della velocita' media).
	PULL_RATE = 9,
	PULL_SURGE = 0.6,
	MANTLE_TIME = 0.34, -- durata della salita sul bordo (prima era uno scatto istantaneo)
	-- Animazioni d'arrampicata (vedi shared/ClimbPoses). Vuote = in Studio si costruiscono al volo
	-- dalle pose; nel gioco pubblicato servono gli id: pubblicale e incolla qui "rbxassetid://..."
	CLIMB_IDLE_ANIM = "",
	CLIMB_UP_ANIM = "",
	CLIMB_ROOF_ANIM = "", -- sotto tetti e strapiombi (se manca si usa Climb_Up)
	CLIMB_SIDE_R_ANIM = "", -- traverso a destra / sinistra (se mancano si usa Climb_Up)
	CLIMB_SIDE_L_ANIM = "",
	CLIMB_JUMP_ANIM = "", -- lancio a due piccozze
	AXE_HOLD_ANIM = "", -- camminando con le piccozze in mano (braccia lungo i fianchi)
	-- Lancio: sulla parete, Spazio tenendo W. Ci si spinge in su e si ripianta con tutte e due
	-- le piccozze insieme. Spazio senza W = ti stacchi dalla parete come prima.
	DYNO_HEIGHT = 9, -- studs guadagnati
	DYNO_TIME = 0.45, -- durata della spinta
	DYNO_STAMINA = 18,
	-- Suoni (i tuoi): colpi di piccozza nella roccia e frane
	SFX_AXE_ROCK = { "rbxassetid://9125869504", "rbxassetid://9125869138" },
	SFX_ROCKFALL = "rbxassetid://82178026493518",
	ANIM_FADE = 0.25, -- dissolvenza tra fermo e in movimento (le pose di idle e salita sono diverse)
	JUMP_OFF_SPEED = Vector3.new(0, 34, 0),
	JUMP_OFF_PUSH = 18,

	-- Stamina (0-100)
	STAMINA_MAX = 100,
	DRAIN_HANGING = 2.5, -- al secondo, fermo sulla parete
	DRAIN_MOVING = 7, -- al secondo, mentre ti muovi
	ICE_MULTIPLIER = 1.8, -- ghiaccio e neve stancano di piu'
	REGEN_GROUND = 25,
	REGEN_ROPE = 6, -- appeso alla corda recuperi un po'
	MIN_STAMINA_TO_GRAB = 10,
	NO_AXE_MULTIPLIER = 1.6, -- senza piccozza in mano si scala lo stesso, ma stanca di piu' (e il ghiaccio no)

	-- Corsa (Shift)
	WALK_SPEED = 24,
	SPRINT_SPEED = 40,
	SPRINT_DRAIN = 6, -- stamina al secondo mentre corri
	SPRINT_FOV = 82,

	-- Chiodi e corda
	PITONS_START = 8,
	PITONS_MAX = 12,
	PITONS_IN_WORLD = 12, -- chiodi piantati per giocatore prima che spariscano i piu' vecchi
	PLACE_RANGE = 14, -- raggio entro cui si pianta un chiodo (col mirino si sceglie il punto)
	ROPE_MAX = 70, -- oltre serve un chiodo nuovo
	ROPE_SLACK = 2,

	-- Meteo e tempo
	DAY_LENGTH_MINUTES = 30, -- durata di un giorno intero (giorno + notte) in minuti reali
	START_CLOCK_TIME = 16.5, -- ora del giorno all'avvio del server
	WEATHER_MIN_SECONDS = 90, -- il tempo cambia spesso (le nuvole arrivano e se ne vanno piano)
	WEATHER_MAX_SECONDS = 210,
	FOG_DENSITY = 0.2, -- foschia col bel tempo (Atmosphere.Density); il brutto tempo la aumenta un po'
	FOG_HAZE = 0.7,
	THUNDER_SOUND = "rbxassetid://139319051979882", -- tuono (vuoto = fulmini senza suono)
	SNOW_LINE = 1650, -- sopra questa quota la pioggia diventa neve
	WIND_ALTITUDE = 1000, -- sopra questa quota il vento del meteo si sente sempre

	-- Miniere
	MINE_RANGE = 12, -- distanza massima dal giacimento
	MINE_COOLDOWN = 0.6,
	ORE_RESPAWN_SECONDS = 180,
}

return ClimbConfig
