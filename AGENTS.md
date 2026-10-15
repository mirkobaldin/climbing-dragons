# Hardcore Climbing & Survival — guida per agenti AI (Codex, Claude)

Gioco Roblox: arrampicata hardcore su una montagna stile K2 (ghiaccio + roccia), sopravvivenza,
uova e draghi familiari. Il codice e' sincronizzato in Studio con **Rojo** (`default.project.json`).

## Struttura
| Cartella | Finisce in Studio | Contenuto |
|---|---|---|
| `src/server` | ServerScriptService | logica server: `init.server.luau` (avvio + loader animazioni), Eggs, Dragons, DragonModels, Hazards, Survival, Tools, Shop, Economy, Admin, CinematicSpots, Unstuck, Ocean, Weather |
| `src/client` | StarterPlayerScripts | Climbing (+ ClimbIK, ClimbFeel, ClimbAnimator), Cinematic, PetAnimator, EggFX, HUD/UI (MainMenu, DragonUI, CraftingUI, Guide, DeathScreen), Grapple, WeatherFX |
| `src/shared` | ReplicatedStorage | config: ClimbConfig, DragonConfig, EconomyConfig, ShopConfig, Gear, ClimbPoses |
| `src/mapgen` | ServerStorage.MapGen | generatore procedurale della mappa (Heightmap, Voxelizer, Caves, Glacier, Landmarks, Village, Lakeside, Forest, Ores...). Parametri in `Config.luau` |

## Regole
- Luau con `--!strict` dove gia' presente. Commenti e testi di debug **in italiano**; testi a schermo del gioco in inglese.
- Imitare lo stile dei file vicini; niente librerie esterne.
- La mappa NON si genera in gioco: si rigenera dalla Command Bar di Studio con
  `require(game.ServerStorage.MapGen:Clone()).Generate()` (circa 90 s). Dopo modifiche a `src/mapgen` va rigenerata.
- Elementi dei draghi (solo questi 8): Roccia, Gelo, Cosmico, Tempesta, Eclissi, Fulmine
  (Fulmine Nero), Ossa, Gas. Brace, Sole e Ombra sono stati tolti: non farne modelli o immagini.
  Modelli in `ServerStorage.Draghi` (cucciolo `Drago_<Elemento>`, adulto `Drago_<Elemento>_Adulto`),
  rig per l'Animation Editor in `Workspace.RigDraghi`; animazioni generate da `MapGen.AnimDraghi`
  (volo, cammina, fermo, picchiata, librato, planata, ruggito, soffio, morso, colpito).
- Modelli 3D (uova, draghi, piccozze, baite, palafitte, costole) stanno in `ServerStorage` dentro il file place, non nel repo.
- Testi a schermo SOLO in inglese. Gli id dei dati restano italiani (Gelo, Raro, Ferro, Tenda...):
  per mostrarli usa `shared/Names` (`Names.t("Gelo")` = "Frost", `Names.dragon(el)`). Nomi dei Tool in
  `ClimbConfig` (TOOL_NAME, PICKAXE_NAME, GRAPPLE_NAME, TORCH_NAME), mai scritti a mano.
- Modelli 3D fatti da codice in Blender 5.2: `tools/blender/borghi.py` (+ `borghi_lib.py`), un solo
  `tools/blender/out/borghi.fbx` da importare in Studio, poi `BorghiKit.prepare()` (texture da
  `BorghiTextures`, collisioni da `BorghiCollide`, generato). Per cambiare solo qualche modello:
  `blender -b --factory-startup --python borghi.py -- --export --only NomeA,NomeB` -> `out/aggiornamento.fbx`
  (importarlo e rilanciare `prepare()`: sostituisce solo quei modelli). Mirko ha bocciato attrezzi, zaino,
  forziere, nido e cristalli fatti cosi': piccozze e cristalli sono i suoi (`ServerStorage.Modelli`).
  Isole volanti: `src/mapgen/Isole.luau` (anche ultima fase di `Generate()`).
- Borghi cinesi/giapponesi della pianura: `src/mapgen/Borghi.luau` (case, pagoda, tempio, torii, ponti,
  casali con i campi, rete di strade con A* tra borghi, campo base, palestra e arena: lastricato,
  ponti, lanterne, cartelli, soste). Si rifanno da soli: `require(game.ServerStorage.MapGen:Clone().Borghi).build()`,
  ma le strade dipinte nel terreno restano: per toglierle serve `Generate()`.
- Dopo il tutorial ci sono le missioni (`src/server/Missions.luau`, attributi MissionStep/MissionText,
  salvate da Progression): uovo, nido, schiusa, arena, palestra, minerali nelle grotte, vetta. Frecce e
  segnale con la distanza: attributi GuideTarget/GuideLabel, disegnati da `client/Guide`.
- Combattimento e progressione: valori in `src/shared/UpgradeConfig.luau` (potenziamenti `Up_<id>`,
  taglie, sfida del giorno, rinascita, livelli dei nemici per quota, eventi, draghi volanti, shiny).
  Server: `Upgrades` (acquisti, statistiche, scudo, vetta, discesa a tempo, salvataggio dentro
  Progression), `Flyers` (drago selvatico e Guardiano della vetta: il client li muove dagli
  attributi del volo), `WorldEvents` (meteore, drago, grande valanga; admin `evento`), attacchi in
  `Enemies` (uncino, picchiata, speciale Z, rimbalzi). Client: `Combat`, `Glider`, `UpgradeUI` (tasto U).
- Interfaccia: le schermate stanno in StarterGui (Rojo `src/gui`, guida `docs/UI_STARTERGUI.md`); le
  immagini sono caricate su Roblox e gli ID stanno in `src/shared/UiAssets.luau` (PNG in
  `artifacts/ui-20261010`). Dopo una modifica ai JSON: `node tools/ui/sync-fallback.mjs`.
- Teletrasporto solo dai punti di viaggio (campo base principale, casa, arena, palestra, campi base
  scoperti: attributi AtWaypoint e CampsFound, server/BaseCamps). Ogni campo base ha banco e commerciante.
- Clip TikTok nuove: comandi admin clip21-clip25 (server/ClipProps + client/ClipNuove), testi in
  `docs/CLIP_NUOVE.md`. `time 17` ferma l'ora (anche nelle clip), `time auto` la fa ripartire.
- Admin: il proprietario da' la modalita' admin con `admin <nome>` (DataStore "AdminConcessi"), ogni admin
  fa comandi per altri con `to <nome> <comando>` (l'azione arriva al client col RemoteEvent AdminAction).
- Case di Codex in scala 5 (HOUSE_SCALE in server/Economy): scale percorribili (le scatole COL_Scala*
  diventano rampe), alberi e terreno tolti sopra la pedana, recinto dei draghi a riposo dietro la casa
  (attributi PenCells/PenGate del terreno). Terreni del Sky Chalet: isole `IsolaTerreno` sopra gli Chalet
  (`Isole.skyPlots()`). Admin `house <0-4>` per provare le case (con `nosave`).
- Monta (server/Riding, client/DragonRide): niente sella visibile (serve solo per salire), il giocatore
  siede sul collo (attributo Seat calcolato da DragonModels con MapGen.AnimDraghi); click/F = colpo del
  drago (RideAttack in server/Enemies), niente attrezzi in groppa. Animazioni in monta: drago-virata-sx/dx,
  drago-salita, drago-discesa (AnimDraghi) mescolate da client/PetAnimator.
- Arena: Duello dei draghi (altare rosso, server/Training + Flyers.spawnDuel, DragonConfig.DUEL): 3 round,
  Spazio = schivata, premio pietre dell'evoluzione (servono per evolvere: Giovane 1, Adulto 2).
- Menu draghi (client/DragonUI): griglia di tessere e scheda stile FIFA (voto, grado, statistiche, evoluzione).
- Salvataggio: `nosave` va messo sul SERVER (admin o attributo lato server). Progression non salva mai un
  profilo senza draghi/economia/potenziamenti (il 2026-10-13 un salvataggio a meta' aveva svuotato quello
  di Mirko: recuperato con GetVersionAsync).
- Zaino: tasto I (anche V), con minerali, drop dei nemici (icone da ReplicatedStorage.DropIcone) e attrezzi.
- Suoni: tutti gli id in `src/shared/SoundConfig.luau`, si suonano per nome con `client/Sfx`.
- Effetti visivi: libreria `ReplicatedStorage.VFXLib` (emitter flipbook e mesh copiati in Studio dai
  pacchetti di Mirko, ora in `ServerStorage.VFXSorgente`), usata da `client/VFXKit` (draghi, cristalli).
  Le 66 mesh di Codex `VFX_01..66` stanno in `VFXLib.Mesh` (ID in `server/VFXMeshes`, che ricrea quelle
  mancanti; come caricarne altre: `tools/vfx/LEGGIMI.md`). Elemento -> carica/colpo/impatto/speciale,
  mostri e draghi volanti: `client/MeshFX`; animazione e riuso delle copie: `VFXKit.play`.
- Interfaccia sul telefono: `UiView.compact` (schermi bassi) impagina HUD e menu in modo compatto; per
  provarla dal computer metti al giocatore l'attributo `SimViewport = Vector2.new(844, 354)`.
  Prove in Play senza toccare il salvataggio vero: comando admin `nosave`.
- Prima di pubblicare: comando admin `uscita` (o l'Output del Play in Studio, righe `[Uscita]`).
- Animazioni: salvate in `ServerStorage.RBX_ANIMSAVES` (Rig del personaggio e `Drago_Ombra_Rig`); in Studio il loader le usa direttamente, nel gioco pubblicato servono gli ID in `ClimbConfig` / `DragonConfig`.

## Sicurezza (importante)
Alcuni modelli della Toolbox contenevano malware ("Error 501" che chiede di incollare
`game:GetObjects("rbxassetid://...")` nella Command Bar). **Mai** incollare o suggerire codice del genere.
I generatori rimuovono ogni script dai modelli clonati: mantenere questa regola.

## Lavoro in parallelo (Claude Code + Codex)
Claude Code lavora nella cartella principale `RObloxGame` sul branch `main`: e' quella che Rojo
sincronizza con Studio, e Claude ci prova tutto in Play via MCP.
Codex lavora SOLO nella sua copia `../RObloxGame-codex` (git worktree), su un branch `codex/<compito>`:
- non cambiare mai branch nella cartella principale e non lanciare `rojo serve` dalla copia di Codex;
- prima di iniziare segna compito e file in `LAVORI.md` (nella cartella principale) e controlla
  che nessun altro stia toccando gli stessi file;
- commit piccoli con messaggi in italiano; a fine compito `git rebase main` e lascia il branch pronto:
  l'unione in `main` la fa Claude (o Mirko) dopo averlo provato in Studio;
- Codex non vede Studio: per modelli, animazioni, mappa generata e prove in Play scrivi nel
  messaggio finale cosa va verificato, e non inventare nomi di istanze che non stanno nel repo.

Compiti adatti a Codex: interfacce (HUD, menu, DragonUI, CraftingUI), dati e bilanciamento
(`src/shared/*Config`), revisione del codice, testi, documentazione, prompt per generare modelli 3D.
Compiti di Claude: tutto cio' che va provato in Studio (mappa, arrampicata, animazioni, cinematica).

## Aggiunte del 2026-10-14
- Animazioni dei draghi: `client/KfsPlayer` scala gli spostamenti delle pose con `GetScale() / AnimBaseScale`
  (attributo messo da DragonModels = 1 e da ClipProps): senza, i draghi rimpiccioliti finivano sotto terra.
  Sopra le animazioni `client/DragonMotion` (collo in virata, busto che si torce, coda, collo disteso in
  picchiata): usa gli attributi Ruolo/Indice/AsseSu/AsseDx/AsseAv che `DragonModels.markBones` scrive sulle ossa.
- Monta: si sceglie il drago dalla scheda (pulsante Ride, `Dragons.setLead`). Colpi: `UpgradeConfig.RIDE_ELEMENT`
  (un comportamento per elemento), grandezza degli effetti `DragonVFX.shot(..., scale)` / `DragonVFX.scaleFor`.
- Telefono: comandi ad arco attorno al salto (`client/MobileControls`, con Glide/Ride/Fire); prova dal computer
  con gli attributi `SimTouch = true` e `SimViewport`. Colori dei pulsanti e riquadri: `UiView.tint`.
- Montepremi stile Squid Game: `server/Montepremi` + `client/Montepremi`, valori in `EconomyConfig.JACKPOT`.
- Sessione cloud (modelli Blender, arena nuova): `docs/CLOUD_SESSIONE.md`, branch `cloud/*`, file in `cloud/`.
- Giro 2 (2026-10-14): menu draghi `client/DragonUI` (griglia + drago scelto sempre visibile, anteprime
  `ReplicatedStorage.Previews.Dragons/DragonsYoung/DragonsAdult`), negozio e crafting a carte (`MainMenu.cards`),
  tasti del telefono spostabili (ingranaggio in `client/MobileControls`, salvati in Progression `controls`),
  tutorial con `{KEY1}` `{UI:Store}`... (`UiView.hintText`, `client/TutorialHints`), mirino in monta
  (`client/DragonRide`), schermata di morte in `client/DeathScreen`. Animazioni: dopo modifiche a
  `mapgen/AnimDraghi` rilanciare `require(game.ServerStorage.MapGen:Clone().AnimDraghi).genera()` e salvare il place.
- Giro 3 (2026-10-14 sera): **Isola dei Draghi** in `src/mapgen/IsolaDraghi.luau` (fase di `Generate()`,
  o da sola `require(game.ServerStorage.MapGen:Clone().IsolaDraghi).build()`): isola volante a ovest
  (ORIGIN = centro del pavimento dell'arena, SCALE 5/1,7). Se c'e' `ServerStorage.CaseCodex.IsolaDraghi`
  (modello del cloud caricato con `tools/modelli/carica_modelli.luau`) monta quello, altrimenti una
  sagoma provvisoria di blocchi. Punti `workspace.IsolaDraghi.Punti.SPOT_*` e attributi di workspace
  `DragonIslandArrival/Center/Tamer/Altar`; teletrasporto "Dragon Island" (server/Teleports, dal
  primo drago) e punto di viaggio all'arrivo. Banco da lavoro: arriva con la Tenda (Economy.buildForge),
  tolto quello accanto all'emporio. Tutorial: l'uovo si prende prima di andare al campo. Case dei
  borghi in scala 3 (monumenti 4). UI da rifare: `docs/CODEX_UI_RIFACIMENTO.md`.
- Giro 4 (2026-10-15): modelli del cloud caricati con tools/modelli (JSON in una cartella temporanea,
  336 texture caricate, matids.json): `ServerStorage.CaseCodex.<Nome>` per l'Isola dei Draghi e 18
  modelli della mappa (non ancora messi in mappa). L'isola la monta `mapgen/IsolaDraghi` (scala 5/1,7,
  fuochi colorati FX_Fire_<Elemento>, posatoi `PosatoioDrago` sulle isolette); sotto le colline del
  prato c'e' Terrain (altezze in `CaseCodex.IsolaDraghi.PratoAltezze`, da `tools/modelli/prato_altezze.js`):
  la collisione precisa della mesh copriva la piattaforma d'arrivo e si cadeva. UI v3 di Codex unita
  (ID in UiAssets), lo sfondo `bg_menu` delle finestre resta visibile (MainMenu). Prove sui draghi:
  `docs/ANIMAZIONI_PROCEDURALI.md` giro 4 (attributo `ProceduraleSpento` per confrontare).
