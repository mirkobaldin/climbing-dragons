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

## Lavoro in parallelo
Claude Code lavora anche direttamente in Studio (MCP). Per evitare conflitti: un compito = un branch,
commit piccoli, non modificare gli stessi file contemporaneamente.
