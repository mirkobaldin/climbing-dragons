--!strict
-- Parametri della mappa. Cambia i valori qui e rilancia il generatore:
--   require(game.ServerStorage.MapGen).Generate()
-- Tutte le misure sono in studs. Le quote dei biomi sono frazioni di MOUNTAIN.HEIGHT,
-- cosi' se alzi la montagna i biomi si riscalano da soli.

local Config = {
	SEED = 20260929,

	VOXEL = 4, -- risoluzione del Terrain di Roblox (non cambiare)
	MAP_X = 7680, -- estensione est-ovest
	MAP_Z = 5632, -- estensione nord-sud
	BOTTOM_Y = -200, -- fondo del mondo (sotto c'e' il vuoto)
	WATER_LEVEL = 20,
	OCEAN_MARGIN = 2048, -- oceano extra oltre i bordi della mappa (solo acqua, costa poco)

	-- Isola irregolare con coste frastagliate e lagune basse (fondale di sabbia turchese)
	ISLAND_RX = 3250,
	ISLAND_RZ = 2350,
	-- Costa: in alcuni tratti la terra arriva alta fino al mare e cade a picco (falesie, con
	-- faraglioni davanti); altrove scende dolce in spiagge e lagune. Al largo qualche isolotto.
	COAST = { CLIFF_HEIGHT = 55, ISLETS = 9, STACKS = 14 },

	-- Montagna principale (stile Cervino) sul lato est
	-- PROFILE = forma della montagna (frazioni dell'altezza e del raggio): non un cono ma un
	-- massiccio a tre piani. SKIRT = quota dove finiscono le pendici boscose, SHOULDER = quota
	-- della spalla in cima al bastione di pareti; BASTION_FOOT / PYRAMID_FOOT = a che distanza
	-- dal centro (0 = vetta, 1 = piede) iniziano il bastione e la piramide della vetta;
	-- WALL_POWER = quanto e' verticale il bastione (1 = rampa, 3 = parete a picco).
	MOUNTAIN = {
		X = 1300,
		Z = 0,
		HEIGHT = 4200,
		RADIUS = 2300,
		-- piramide larga stile K2: bastione meno a picco, piramide della vetta che parte prima
		PROFILE = { SKIRT = 0.17, SHOULDER = 0.52, BASTION_FOOT = 0.62, PYRAMID_FOOT = 0.4, WALL_POWER = 1.8 },
	},

	-- Colline/cime secondarie attorno alla montagna
	FOOTHILLS = {
		{ X = 1782, Z = 1604, HEIGHT = 1250, RADIUS = 842 },
		{ X = 189, Z = -1459, HEIGHT = 900, RADIUS = 778 },
		{ X = 2557, Z = -1178, HEIGHT = 1100, RADIUS = 713 },
		{ X = -1000, Z = 1324, HEIGHT = 520, RADIUS = 670 },
	},

	-- Valle centrale (area base) a ovest: piana chiusa da un anello di pareti rocciose
	HUB = {
		X = -1380, -- il varco est della valle si apre quasi ai piedi della montagna
		Z = 0,
		RADIUS = 450,
		HEIGHT = 44,
		-- Cerchio delle tende verso il mare (spawn + falo'), offset dal centro della piana
		CAMP = { DX = -90, DZ = -40, RADIUS = 120 },
		-- Mezzaluna rialzata verso la montagna: cabine sul livello 1, chalet sul livello 2
		-- i terreni delle case non sono piu' qui (TIER a 0 = piana tutta in piano, li' c'e' il tutorial)
		CRESCENT = { INNER = 220, MID = 310, OUTER = 410, SPAN = 1.1, TIER1 = 0, TIER2 = 0, RAMPS = {} },
		-- Anello di pareti attorno alla valle; GATES = varchi (angolo: 0 = est/montagna, pi = ovest/mare)
		WALL = {
			RADIUS = 640,
			WIDTH = 150,
			HEIGHT = 110,
			GATES = { { ANGLE = math.pi, WIDTH = 0.32 }, { ANGLE = 0.05, WIDTH = 0.2 } },
		},
		RIBS_OFFSET = { -250, -420 }, -- costato del drago, nella valle (a sud)
	},
	HOT_POOLS = { -- sorgenti termali nella piana (offset dal centro HUB)
		{ DX = -150, DZ = -230, RADIUS = 14 },
		{ DX = -70, DZ = -255, RADIUS = 11 },
		{ DX = -230, DZ = -200, RADIUS = 9 },
	},

	-- Teschio del drago: ingresso dell'isola, sul varco ovest della valle (verso il mare) con la
	-- bocca aperta rivolta dentro la valle: arrivando dal mare si entra nell'isola dalla sua bocca.
	-- SKULL_LENGTH = lunghezza in studs, MOUTH_OPEN = apertura della bocca (gradi)
	-- SKULL_YAW = rotazione extra in gradi se il muso del tuo modello esce girato (0, 90, 180, 270);
	-- si puo' anche mettere l'attributo "Yaw" sul modello DragonSkull in ServerStorage
	DRAGON = { RIBS_LENGTH = 0.7, SKULL_LENGTH = 1000, SKULL_YAW = 0, JAW = false }, -- 0 per teschio_drago (muso verso -Z); JAW = false: solo la parte superiore, si passa sotto

	-- Parete di allenamento del tutorial davanti al campo delle tende (ANGLE: 0 = verso la
	-- montagna, pi = verso il mare, -pi/2 = sud; DISTANCE dal centro del campo). A ovest c'e'
	-- il teschio, a est la mezzaluna, a nord emporio e fiume: il posto libero e' a sud.
	TUTORIAL = { ANGLE = -math.pi / 2 - 0.1, DISTANCE = 320, WALL_WIDTH = 80, WALL_HEIGHT = 60 },

	-- Baia d'ingresso con spiaggia e laguna
	BAY = { X = -2300, Z = 350, RADIUS = 520 },

	-- Fiumi e valli. POINTS = percorso {x, z} dalla sorgente alla foce (la curva viene ammorbidita).
	-- Il primo fiume nasce dove finisce la gola della cascata. VALLEY_SLOPE = ripidita' dei
	-- fianchi della valle. Nei tratti ripidi l'acqua e' schiuma di particelle (vedi RIVER_CALM).
	RIVERS = {
		{
			NAME = "Fiume della Piana",
			POINTS = { { -360, 135 }, { -760, 330 }, { -1100, 400 }, { -1400, 380 }, { -1800, 360 }, { -2200, 380 }, { -2650, 400 }, { -3080, 420 } },
			HALF_WIDTH = 14,
			VALLEY_WIDTH = 160,
			VALLEY_SLOPE = 0.35,
			DEPTH = 5,
			MEANDER = 90,
		},
		{
			NAME = "Valle Nord",
			POINTS = { { 586, 1354 }, { 257, 1502 }, { -300, 1781 }, { -717, 2087 }, { -996, 2574 } },
			HALF_WIDTH = 8,
			VALLEY_WIDTH = 170,
			VALLEY_SLOPE = 0.75,
			DEPTH = 4,
			MEANDER = 60,
		},
		{
			NAME = "Valle Sud",
			POINTS = { { 1803, -1445 }, { 1926, -1669 }, { 2065, -2017 }, { 2274, -2574 } },
			HALF_WIDTH = 8,
			VALLEY_WIDTH = 150,
			VALLEY_SLOPE = 0.75,
			DEPTH = 4,
			MEANDER = 50,
		},
	},

	-- L'acqua del Terrain e' sempre piatta: un fiume in discesa e' quindi una scala di pozze
	-- piatte, con il fondo scavato piano (DEPTH studs sotto il pelo) e una soglia bassa tra una
	-- pozza e l'altra. Se per stare dietro al pendio servisse una soglia piu' alta di STEP, il
	-- tratto diventa uno scivolo di roccia (cascata), senza acqua ferma.
	--   DEPTH     profondita' dell'acqua nella pozza
	--   DROP      salto massimo tra una pozza e la successiva: dove il pendio e' dolce le pozze
	--             diventano lunghissime (il fiume sembra continuo), dove e' ripido si accorciano
	--             e si forma una scalinata di terrazze d'acqua
	--   MIN_LEN   lunghezza minima di una pozza in studs
	--   MAX_DEPTH nessuna pozza piu' profonda di cosi' (niente trincee allagate)
	RIVER_POOLS = { DEPTH = 5, DROP = 6, MIN_LEN = 16, MAX_DEPTH = 12 },
	-- Un bordo d'acqua che si affaccia su un salto piu' alto di questo (studs) diventa un labbro di
	-- roccia (evita "muri d'acqua" verticali); salti piu' piccoli restano acqua in discesa.
	WATER_EDGE_DROP = 9,

	-- Laghetti naturali nelle zone ampie e piatte (trovate da sole)
	PONDS = { COUNT = 4, RADIUS = 55, MIN_SPACING = 700, MIN_FROM_CAMP = 420 },
	-- Lago grande nella valle del campo, sul Fiume della Piana: il fiume che scende dalla
	-- montagna e' l'immissario, quello che prosegue verso il mare l'emissario. Sulla riva sud
	-- le palafitte (zona tranquilla con panchine, amache e falo').
	BIG_LAKE = { X = -1560, Z = 370, RADIUS = 145, DEPTH = 16, BEACH = 26 },
	-- il modello delle palafitte (ServerStorage.Modelli.Palafitte) sta nel lago del teschio, dietro
	-- il laghetto (Mirko 16/10), senza le due baite; LOOK = verso dove guarda il lato lungo,
	-- SINK = di quanto il perno del modello sta sotto il pelo dell'acqua
	PALAFITTE = { X = -2280, Z = 400, LOOK = Vector3.new(0.2144, 0, -0.9768), SINK = 10.7 },
	-- Ghiacciai (stile K2): lingue di ghiaccio che scendono lungo i canaloni seguendo la forma
	-- della montagna (niente pianori). ANGLE = versante, R_TOP / R_BOTTOM = da che distanza dal
	-- centro partono e arrivano (frazioni del raggio), WIDTH = larghezza in alto (si stringono
	-- scendendo). Dove il pendio e' ripido diventano seraccate piene di blocchi di ghiaccio; i
	-- crepacci sono archi irregolari, piu' fitti e caotici nelle seraccate.
	GLACIERS = {
		-- come sul K2: partono dai piedi delle pareti (seraccata) e scendono nelle valli alla base,
		-- dove la pendenza e' da ghiacciaio vero (30-40 gradi), non da parete
		{ ANGLE = math.rad(115), R_TOP = 0.5, R_BOTTOM = 0.86, WIDTH = 440 },
		{ ANGLE = math.rad(-60), R_TOP = 0.52, R_BOTTOM = 0.88, WIDTH = 400 },
		{ ANGLE = math.rad(30), R_TOP = 0.5, R_BOTTOM = 0.84, WIDTH = 360 },
		-- ghiacciai sospesi sulla spalla, sopra il bastione di pareti (le quattro creste e il lago):
		-- finiscono sul ciglio delle pareti con una barriera di seracchi
		{ ANGLE = math.rad(203), R_TOP = 0.34, R_BOTTOM = 0.465, WIDTH = 260 }, -- sopra il lago
		{ ANGLE = math.rad(158), R_TOP = 0.39, R_BOTTOM = 0.63, WIDTH = 300 }, -- verso la piana
		{ ANGLE = math.rad(-112), R_TOP = 0.38, R_BOTTOM = 0.59, WIDTH = 300 },
		{ ANGLE = math.rad(-22), R_TOP = 0.4, R_BOTTOM = 0.59, WIDTH = 280 },
		{ ANGLE = math.rad(68), R_TOP = 0.4, R_BOTTOM = 0.64, WIDTH = 280 },
	},
	-- Ghiaccio sospeso sulle pareti alte (fascia di seracchi come sul K2): da TOP in giu' il
	-- ghiaccio scende con pendenza SLOPE, finche' e' spesso MAX studs e si interrompe in una parete.
	-- LOBES = quante lingue attorno alla montagna (circa).
	ICECAP = { TOP = 0.82, BOTTOM = 0.35, SLOPE = 0.9, MAX = 130, LOBES = 5 },
	-- Pareti di ghiaccio vivo: tra BOTTOM e TOP (frazioni della quota) le pareti piu' ripide di
	-- MIN_SLOPE diventano ghiaccio nei settori dove il rumore supera THRESHOLD (piu' basso = piu'
	-- ghiaccio). SECTORS = quanti settori circa attorno alla montagna.
	ICEWALLS = { BOTTOM = 0.3, TOP = 0.9, MIN_SLOPE = 1.0, THRESHOLD = -0.05, SECTORS = 4 },
	GLACIER = {
		THICKNESS = 26, -- spessore del ghiaccio sopra la roccia
		SMOOTH = 7, -- campioni (x8 studs) per ammorbidire il letto: ghiaccio che riempie, non piallato
		ICEFALL = 1.3, -- seraccata dove il ghiacciaio e' ripido 1.3 volte la sua pendenza tipica
		CREVASSE_EVERY = { 26, 80 },
		CREVASSE_WIDTH = { 4, 15 },
		CREVASSE_DEPTH = { 25, 70 },
		LADDERS_PER_CREVASSE = 2,
	},

	-- Valle dei gas tossici (zona del drago Gas) ai piedi della montagna, sul lato est: una conca
	-- scavata nel pendio, con la montagna come parete alle spalle e un orlo rialzato verso il mare.
	-- Fondo di roccia blu-viola con croste che brillano fucsia, fumarole di gas azzurro e fucsia.
	-- ANGLE/DIST = posizione attorno alla montagna, RADIUS = raggio, RIM = altezza minima dell'orlo
	-- Piu' zone: la valle ai piedi del lato est, una conca sulla spalla nord e una piu' in alto.
	TOXIC_ZONES = {
		{ ANGLE = math.rad(-5), DIST = 0.84, RADIUS = 175, RIM = 34, VENTS = 9 },
		{ ANGLE = math.rad(-86), DIST = 0.6, RADIUS = 120, RIM = 26, VENTS = 6 },
		{ ANGLE = math.rad(91), DIST = 0.42, RADIUS = 100, RIM = 24, VENTS = 5 },
	},

	-- Lago d'alta quota + gola con pozze e salti d'acqua (cascata)
	-- (ai piedi del grande bastione, come i laghi sotto le pareti delle Dolomiti)
	LAKE = { ANGLE = math.pi + 0.35, HEIGHT_FRAC = 0.2, RADIUS = 60, RIM = 22 },
	-- STEP = altezza dei salti della gola: pozze piatte separate da salti veri (le cascate)
	GORGE = { HALF_WIDTH = 10, WALL = 26, DEPTH = 30, STEP = 26 },

	-- Biomi verticali (frazioni dell'altezza della montagna)
	BIOMES = {
		FOREST_TOP = 0.2, -- fino a ~600: erba, bosco
		MEADOW_TOP = 0.33, -- cenge d'erba alpina
		SNOW_LINE = 0.42, -- sopra ~1260: neve su tutto cio' che non e' parete verticale
		SNOW_SLOPE = 3.6, -- pendenza massima (tan) su cui resta la neve (~75 gradi)
		SNOW_CAP = 0.6, -- piu' in alto la neve copre fino a 5.5 (~80 gradi): pareti intonacate
		GLACIER_LINE = 0.62, -- sopra ~2600: colate di ghiaccio nei canaloni e sulle pareti
	},

	-- Pareti verticali (a gradoni) sparse sulla montagna + grande parete sul lato +Z
	-- MASK = soglie del rumore che decide dove ci sono pareti: piu' basse = piu' pareti
	CLIFFS = { STEP_MIN = 70, STEP_MAX = 170, BIG_WALL_STEP = 380, SHARPNESS = 8, MASK = { -0.08, 0.04 } },

	-- Monoliti: pareti enormi e verticali sui fianchi della montagna (tipo El Capitan e le
	-- falesie di Arco). ANGLE attorno alla montagna, DIST = frazione del raggio della montagna,
	-- HEIGHT = quanto si alzano sopra il pendio. Sulle loro facce ci sono i grandi tetti.
	MONOLITHS = {
		{ NAME = "El Capitano", ANGLE = -0.9, DIST = 0.78, RADIUS = 250, HEIGHT = 800 },
		{ NAME = "Torre di Arco", ANGLE = 2.6, DIST = 0.8, RADIUS = 190, HEIGHT = 560 },
		{ NAME = "Il Pulpito", ANGLE = 0.9, DIST = 0.82, RADIUS = 150, HEIGHT = 420 },
	},

	-- Sentiero di cresta a spirale (stretto, con interruzioni)
	PATH = {
		START_ANGLE = math.pi - 0.3,
		TURNS = 2.25,
		Y_START = 120,
		Y_END_FRAC = 0.8, -- oltre questa quota niente sentiero: solo arrampicata
		HALF_WIDTH = 4,
		CAMPS = { 0.12, 0.3, 0.5, 0.68, 0.84 }, -- campi base (piazzole piatte) lungo il sentiero
		CAMP_RADIUS = 16,
		GAPS = {
			-- at = posizione lungo il sentiero (0..1), length = buco in studs,
			-- rise = di quanto riparte piu' in alto (parete da scalare con i chiodi)
			{ at = 0.22, kind = "climb", length = 18, rise = 28 },
			{ at = 0.40, kind = "floating", length = 70, rise = 10 },
			{ at = 0.58, kind = "climb", length = 16, rise = 36 },
			{ at = 0.74, kind = "climb", length = 20, rise = 44 },
			{ at = 0.88, kind = "floating", length = 90, rise = 16 },
		},
	},

	-- Grotte e gallerie
	-- Montagna vuota (vedi Voxelizer): guscio di roccia spesso SHELL studs, cavita' solo dove il
	-- tetto verrebbe sopra MIN_Y (cioe' sotto la montagna e le colline alte, non sotto la piana).
	-- WALL = rivestimento di roccia attorno alle grotte che passano nella cavita'.
	HOLLOW = { SHELL = 48, MIN_Y = 60, WALL = 10 },
	-- Camera del tesoro al centro della montagna (quota del centro e raggio della cupola)
	TREASURE = { Y = 340, RADIUS = 80 },
	CAVES = {
		ENTRY_Y = 140, -- ingresso della grotta base (lato piana)
		HELIX_TOP_FRAC = 0.5, -- la galleria interna sale fino a meta' montagna
		HELIX_MAX_RADIUS = 260,
		HELIX_GRADE = 0.25, -- pendenza camminabile (~14 gradi)
		TUNNEL_RADIUS = 13, -- galleria principale (il personaggio e' alto ~5 studs, i voxel da 4 arrotondano)
		MIN_RADIUS = 9, -- cunicoli laterali: sotto questo raggio non ci si passa
		LINK_RADIUS = 9, -- collegamenti, pozzi e corridoi della catacomba
		COVER = 14, -- roccia che deve restare sopra una galleria: meno e' un soffitto in cui si cade
		BRANCHES = 18, -- cunicoli laterali (vicoli ciechi, stanze minerali)
		ENTRANCES = 7, -- ingressi extra sparsi sulla montagna, collegati alla galleria
		LOOPS = 14, -- gallerie che collegano tra loro stanze e cunicoli (rete intrecciata)
		MINE_CHAMBERS = 8, -- grandi caverne con pavimento piatto per i giacimenti
		TUNNEL_ROOM_EVERY = 90, -- una stanza coi giacimenti ogni 90 punti della spirale (~270 studs)
		ICE_CAVES = { 0.62, 0.68, 0.74 }, -- quote (frazioni) delle grotte di ghiaccio (sale da 46 studs)
		-- Grotta di ghiaccio azzurro (come quelle dell'Islanda) nel fronte del ghiacciaio GLACIER
		-- (indice in GLACIERS): FRONT = altezza del fronte di ghiaccio, LENGTH = lunghezza della
		-- galleria, RADIUS = raggio della galleria, HALL = raggio della sala in fondo
		-- Grotte di ghiaccio azzurro nei fronti dei ghiacciai (GLACIER = indice in GLACIERS):
		-- FRONT = altezza del fronte, LENGTH = galleria, RADIUS = raggio della galleria, HALL = sala
		GLACIER_CAVES = {
			{ GLACIER = 1, FRONT = 86, LENGTH = 300, RADIUS = 22, GRADE = 0.08, HALL = 75, SHELL = 12 },
			-- "cattedrale": galleria corta e una sala enorme
			{ GLACIER = 3, FRONT = 80, LENGTH = 110, RADIUS = 26, GRADE = 0.05, HALL = 100, SHELL = 12 },
		},
		-- Spaccatura: la montagna e' spaccata e la fessura e' aperta verso il cielo, pareti di ghiaccio
		-- azzurro, niente gallerie. ANGLE/DIST = dove si apre, LENGTH = quanto entra nella montagna,
		-- WIDTH = larghezza (varia lungo la fessura), DEPTH = quanto scende sotto l'imbocco
		CHASM = { ANGLE = -0.62, DIST = 0.76, LENGTH = 300, WIDTH = { 26, 54 }, DEPTH = 30 },
		-- Grande Grotta: un'apertura enorme nella parete della montagna e dentro una sala di ghiaccio
		-- grande come una cattedrale (colonne, terrazze di neve, stalattiti giganti). ANGLE = lato
		-- della montagna, Y = quota del centro, WIDTH/HEIGHT/DEPTH = raggi della sala, INSET = di
		-- quanto il centro sta dentro la parete (meno = apertura piu' grande)
		-- FADE = quanto si allarga attorno all'apertura il ghiaccio che sfuma nella roccia
		GRAND = { ANGLE = 2.72, Y = 1500, WIDTH = 300, HEIGHT = 190, DEPTH = 230, INSET = 55, SHELL = 20, COLUMNS = 10, FADE = 170 },
		-- Grotta-cratere sopra i 2000 m: stessa sala di ghiaccio, ma il tetto e' sfondato (OPEN) e
		-- dall'alto si vede un cratere nella montagna. Ci vive il Titano di ghiaccio (golem).
		CRATER = { ANGLE = 0.4, Y = 2450, WIDTH = 190, HEIGHT = 120, DEPTH = 170, INSET = 95, SHELL = 18, COLUMNS = 5, FADE = 140, OPEN = true },
		-- zone di gas sui pendii: le fumarole vanno anche dove il fondo non e' perfettamente piano
		NICHE_FRAC = 0.45, -- anfratto segreto nella parete est
		CATACOMB_Y = -100, -- catacomba segreta sotto il livello del mare
	},

	-- Bosco: una possibile posizione ogni CELL studs, DENSITY = quanto e' fitto.
	-- Modelli: qualunque Model con "Tree"/"albero" nel nome dentro ServerStorage (anche in
	-- sottocartelle, es. "Realistic Trees Pack"). Quelli con "cherry", "sakura" o "ciliegio" nel
	-- nome vanno in basso (piana, valli, rive), "pine"/"pino" in alto, gli altri in mezzo.
	-- SCALE = ingrandimento casuale dei modelli (i pack sono spesso piccoli per la nostra mappa).
	FOREST = {
		CELL = 22,
		DENSITY = 0.8,
		MAX_TREES = 3000,
		ABOVE_FOREST_TOP = 150,
		CHERRY_MAX_Y = 220,
		PINE_MIN_Y = 380,
		SCALE = { 2.2, 3.6 },
		GIANT_CHANCE = 0.12, -- alcuni alberi giganti
		GIANT_SCALE = { 4.5, 6.5 },
		EFFECTS_EVERY = 12, -- solo un albero ogni N tiene particelle (petali/foglie) e suoni
	},

	-- Strada lastricata dalla base al sentiero della montagna (passa dal varco est della valle)
	-- MAX_GRADE = pendenza massima, SMOOTH = quanti punti (x4 studs) per ammorbidire il profilo
	ROAD = { HALF_WIDTH = 6, SHOULDER = 14, MAX_GRADE = 0.14, SMOOTH = 12, LAMP_EVERY = 3 },

	-- CABINS/CHALETS = terreni dei giocatori sul primo/secondo livello della mezzaluna;
	-- HOUSE_SCALE = grandezza delle case (1 = a misura del modello a blocchi)
	-- Terreni delle case, uno per giocatore, in tre zone (la casa trasloca quando la migliori):
	--   TENTS  campo tende ai piedi della montagna, dove parte il sentiero (Tenda)
	--   CABINS villaggio attorno alle costole del drago (Baita)
	--   VILLAS villette a sbalzo sui costoni della montagna (Chalet)
	-- PLOT_HALF = meta' del lato del terreno per livello; HOUSE_SCALE = grandezza delle case
	-- Zone a tema dei draghi (mapgen/ThemeZones): ANGLE = lato della montagna, Y = quota cercata,
	-- RADIUS = grandezza, GROUND = due materiali del terreno (colori in Environment), COLOR = luce del
	-- drago, STONE = pietra dell'altare. Gelo (grotte di ghiaccio) e Gas (valli) ci sono gia'.
	THEME_ZONES = {
		{ ELEMENT = "Roccia", ANGLE = -2.6, Y = 120, RADIUS = 140, GROUND = { "Sandstone", "Rock" }, COLOR = Color3.fromRGB(240, 190, 110), STONE = Color3.fromRGB(120, 100, 80), TITLE = "ROCKFALL CANYON", SUBTITLE = "Home of the Rock dragon" },
		{ ELEMENT = "Ossa", ANGLE = 2.1, Y = 550, RADIUS = 120, GROUND = { "Salt", "Mud" }, COLOR = Color3.fromRGB(190, 255, 210), STONE = Color3.fromRGB(200, 195, 180), TITLE = "DRAGON GRAVEYARD", SUBTITLE = "Home of the Bone dragon" },
		{ ELEMENT = "Tempesta", ANGLE = -1.0, Y = 1300, RADIUS = 120, GROUND = { "Slate", "Basalt" }, COLOR = Color3.fromRGB(150, 200, 255), STONE = Color3.fromRGB(70, 82, 110), TITLE = "STORM RIDGE", SUBTITLE = "Home of the Storm dragon" },
		{ ELEMENT = "Fulmine", ANGLE = -2.0, Y = 2000, RADIUS = 110, GROUND = { "Pavement", "Basalt" }, COLOR = Color3.fromRGB(170, 140, 255), STONE = Color3.fromRGB(30, 26, 40), TITLE = "BLACK LIGHTNING SPIRES", SUBTITLE = "Home of the Black Lightning dragon" },
		{ ELEMENT = "Cosmico", ANGLE = 1.2, Y = 3100, RADIUS = 110, GROUND = { "Concrete", "Slate" }, COLOR = Color3.fromRGB(220, 90, 255), STONE = Color3.fromRGB(60, 40, 110), TITLE = "STARFALL PLATEAU", SUBTITLE = "Home of the Cosmic dragon" },
		{ ELEMENT = "Eclissi", ANGLE = 3.0, Y = 3600, RADIUS = 90, GROUND = { "Pavement", "Asphalt" }, COLOR = Color3.fromRGB(255, 170, 60), STONE = Color3.fromRGB(26, 24, 34), TITLE = "ECLIPSE SANCTUARY", SUBTITLE = "Home of the Eclipse dragon" },
		-- altre zone per drago (2-3 ciascuno), a lati e quote diverse
		{ ELEMENT = "Roccia", ANGLE = 0.9, Y = 160, RADIUS = 100, GROUND = { "Sandstone", "Rock" }, COLOR = Color3.fromRGB(240, 190, 110), STONE = Color3.fromRGB(120, 100, 80), TITLE = "AMBER HOLLOW", SUBTITLE = "Home of the Rock dragon" },
		{ ELEMENT = "Roccia", ANGLE = -1.6, Y = 380, RADIUS = 100, GROUND = { "Sandstone", "Rock" }, COLOR = Color3.fromRGB(240, 190, 110), STONE = Color3.fromRGB(120, 100, 80), TITLE = "BOULDER STEPS", SUBTITLE = "Home of the Rock dragon" },
		{ ELEMENT = "Ossa", ANGLE = -0.3, Y = 800, RADIUS = 100, GROUND = { "Salt", "Mud" }, COLOR = Color3.fromRGB(190, 255, 210), STONE = Color3.fromRGB(200, 195, 180), TITLE = "BONE RIDGE", SUBTITLE = "Home of the Bone dragon" },
		{ ELEMENT = "Ossa", ANGLE = 1.6, Y = 1050, RADIUS = 95, GROUND = { "Salt", "Mud" }, COLOR = Color3.fromRGB(190, 255, 210), STONE = Color3.fromRGB(200, 195, 180), TITLE = "WYRM'S REST", SUBTITLE = "Home of the Bone dragon" },
		{ ELEMENT = "Tempesta", ANGLE = 2, Y = 1750, RADIUS = 100, GROUND = { "Slate", "Basalt" }, COLOR = Color3.fromRGB(150, 200, 255), STONE = Color3.fromRGB(70, 82, 110), TITLE = "THUNDER SHELF", SUBTITLE = "Home of the Storm dragon" },
		{ ELEMENT = "Tempesta", ANGLE = 0, Y = 1900, RADIUS = 95, GROUND = { "Slate", "Basalt" }, COLOR = Color3.fromRGB(150, 200, 255), STONE = Color3.fromRGB(70, 82, 110), TITLE = "GALE PASS", SUBTITLE = "Home of the Storm dragon" },
		{ ELEMENT = "Fulmine", ANGLE = 1, Y = 2300, RADIUS = 95, GROUND = { "Pavement", "Basalt" }, COLOR = Color3.fromRGB(170, 140, 255), STONE = Color3.fromRGB(30, 26, 40), TITLE = "VOID CRAGS", SUBTITLE = "Home of the Black Lightning dragon" },
		{ ELEMENT = "Fulmine", ANGLE = -0.6, Y = 2600, RADIUS = 95, GROUND = { "Pavement", "Basalt" }, COLOR = Color3.fromRGB(170, 140, 255), STONE = Color3.fromRGB(30, 26, 40), TITLE = "STATIC PEAKS", SUBTITLE = "Home of the Black Lightning dragon" },
		{ ELEMENT = "Cosmico", ANGLE = -2.4, Y = 2850, RADIUS = 95, GROUND = { "Concrete", "Slate" }, COLOR = Color3.fromRGB(220, 90, 255), STONE = Color3.fromRGB(60, 40, 110), TITLE = "NEBULA BASIN", SUBTITLE = "Home of the Cosmic dragon" },
		{ ELEMENT = "Cosmico", ANGLE = 0.2, Y = 3300, RADIUS = 90, GROUND = { "Concrete", "Slate" }, COLOR = Color3.fromRGB(220, 90, 255), STONE = Color3.fromRGB(60, 40, 110), TITLE = "COMET CRATER", SUBTITLE = "Home of the Cosmic dragon" },
		{ ELEMENT = "Eclissi", ANGLE = -1.2, Y = 3450, RADIUS = 85, GROUND = { "Pavement", "Asphalt" }, COLOR = Color3.fromRGB(255, 170, 60), STONE = Color3.fromRGB(26, 24, 34), TITLE = "UMBRAL GATE", SUBTITLE = "Home of the Eclipse dragon" },
		{ ELEMENT = "Eclissi", ANGLE = 1.9, Y = 3800, RADIUS = 80, GROUND = { "Pavement", "Asphalt" }, COLOR = Color3.fromRGB(255, 170, 60), STONE = Color3.fromRGB(26, 24, 34), TITLE = "CORONA TERRACE", SUBTITLE = "Home of the Eclipse dragon" },
	},

	-- case: tende sparse ai piedi della montagna (accampamento di ogni giocatore), baite sul pendio
	-- a CABIN_Y, chalet sui costoni a VILLA_Y (quote in studs = metri dell'altimetro)
	VILLAGE = { TENTS = 20, CABINS = 14, VILLAS = 10, BRIDGES = 3, HOUSE_SCALE = 1.6, PLOT_HALF = { 22, 30, 34 }, CABIN_Y = { 260, 340 }, VILLA_Y = { 500, 650 } },

	-- Ostacoli sulla montagna
	OBSTACLES = {
		CRUMBLING_ROCKS = 60, -- appigli che si sgretolano quando ti aggrappi
		ICE_PATCHES = 40, -- lastre di ghiaccio scivolose sulle cenge alte
		ROCKFALL_SOURCES = 8, -- canaloni da cui cadono sassi
		WIND_ZONES = 6, -- raffiche di vento in quota
		-- Strapiombi: la parete si gonfia in fuori (vedi bulge in Obstacles).
		--   ANGLE       inclinazione massima sotto la pancia (gradi dalla verticale, 45 = un metro
		--               in fuori ogni metro in su)
		--   MAX_DEPTH   quanto sporge al massimo (cresce fino a sqrt(MAX_SCALE) volte sulle pareti
		--               enormi); WIDTH larghezza lungo la parete, mai meno di WIDTH_RATIO volte la
		--               sporgenza (altrimenti sembra un naso)
		--   CROWN       sopra il ciglio la roccia rientra nella parete in CROWN volte la sporgenza
		--   MIN_Y..MAX_Y_FRAC  fascia di quote in cui vengono sparse, in modo uniforme
		OVERHANG = {
			COUNT = 140,
			PER_MONOLITH = 4,
			ANGLE = { 45, 62 },
			MIN_CLIFF = 40,
			WIDTH = { 140, 300 },
			WIDTH_RATIO = 3.2,
			MAX_DEPTH = 55,
			CROWN = { 1.8, 3.5 },
			MIN_Y = 260,
			MAX_Y_FRAC = 0.93,
			MAX_SCALE = 5,
		},
		SMOOTH_WALLS_FROM = 0.5, -- i salti del sentiero oltre questo punto (0..1) sono pareti lisce: serve il Rampino
	},

	-- Nota: la pendenza massima camminabile (50 gradi, niente scalate "saltando") e'
	-- impostata in default.project.json -> StarterPlayer.CharacterMaxSlopeAngle
}

return Config
