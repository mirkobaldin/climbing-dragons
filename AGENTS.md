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
- Elementi dei draghi (solo questi 7): Roccia, Brace, Gelo, Cosmico, Tempesta, Sole, Ombra.
- Modelli 3D (uova, draghi, piccozze, baite, palafitte, costole) stanno in `ServerStorage` dentro il file place, non nel repo.
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
