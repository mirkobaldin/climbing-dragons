# Prompt per Codex: interfaccia nuova con immagini (StarterGui)

Da incollare a Codex così com'è. Sono due compiti, da fare in ordine su due branch diversi.

---

## Contesto (leggi prima AGENTS.md e LAVORI.md)

Gioco Roblox "Hardcore Climbing & Survival": arrampicata su una montagna stile K2 (ghiaccio e
roccia), sopravvivenza al freddo, minerali, uova e draghi familiari di 11 elementi (Roccia, Brace,
Gelo, Cosmico, Tempesta, Sole, Ombra, Eclissi, Fulmine, Ossa, Gas). Si gioca da PC e da telefono.

Oggi tutta l'interfaccia è costruita da codice in `src/client` (Frame grigi con UICorner, colori
in `src/client/Theme.luau`) e **StarterGui è vuoto**. Il risultato è piatto e anonimo. Mirko vuole:
- immagini vere (sfondi, cornici, pulsanti, icone) in uno stile riconoscibile;
- le schermate dentro **StarterGui**, così le vede e le ritocca in Studio;
- tutto leggibile e comodo sul telefono.

Regole che restano valide: testi a schermo SOLO in inglese (mai scritti dentro le immagini,
tranne il logo); id dei dati in italiano mostrati con `shared/Names` (`Names.t("Gelo")` = "Frost");
nomi dei Tool da `ClimbConfig` (TOOL_NAME, PICKAXE_NAME, GRAPPLE_NAME, TORCH_NAME); commenti in
italiano; `--!strict` dove c'è già; niente librerie esterne.

---

## Compito 1: le immagini (branch `codex/ui-immagini-20261010`)

Cartella: `artifacts/ui-20261010/`, un PNG per voce con il nome indicato, più un `index.md` con
la tabella nome → misura → margini 9-slice → dove si usa. Segna il compito in `LAVORI.md`.

### Direzione artistica (uguale per TUTTE le immagini)

Usa questo blocco di stile all'inizio di ogni prompt:

> Stylized fantasy game UI asset for a Roblox mountain-climbing and dragon game. Hand-painted,
> clean readable shapes, soft bevels, subtle frost texture. Palette: deep night-navy panels
> (#10141C to #1C2230), carved dark slate stone rims, frosted ice-blue highlights (#8FD3FF),
> warm gold trim and accents (#FFC450), small ember-orange glow details. Lit from top-left.
> No text, no letters, no numbers, no watermark. Centered, isolated on a fully transparent
> background (PNG with alpha), crisp edges, no drop shadow outside the canvas.

Vincoli tecnici:
- PNG con alpha vero (sfondi esclusi), lato massimo 1024 px (limite di Roblox), misure pari.
- Cornici e pulsanti fatti per il **9-slice** (`ScaleType = Slice`): angoli decorati, centro e bordi
  ripetibili/allungabili senza dettagli; scrivi i margini `SliceCenter` in `index.md`.
- Icone leggibili a 32 px: silhouette forte, contorno scuro di 2-3 px, poco dettaglio interno.
- Stessa luce, stessa palette e stesso spessore di bordo in tutto il set.
- Controlla ogni immagine (sfondo davvero trasparente, niente testo comparso per sbaglio, niente
  tagli ai bordi) e rifalla se serve.

### Lista delle immagini

**Sfondi e logo**
| Nome | Misura | Prompt (dopo il blocco di stile; per gli sfondi niente "transparent background") |
|---|---|---|
| `bg_loading.png` | 1024x576 | Epic dusk view of a huge K2-like ice and rock mountain, glaciers and icefall, a tiny climber with an ice axe on a ridge in the foreground, a dragon silhouette circling the summit, warm sunset light on the peak, cold blue shadows below, cinematic, leave the lower third darker and calm for UI text |
| `bg_menu.png` | 1024x576 | Night base camp at the foot of the mountain, glowing tents and lanterns, a sleeping baby dragon by a campfire, aurora over the snowy peak, soft vignette, left 40% darker and calm for the menu column |
| `bg_death.png` | 1024x576 | Blizzard whiteout on a frozen cliff, broken rope and an ice axe stuck in the snow, cold desaturated blue with a red vignette at the edges, center calm for text |
| `logo.png` | 1024x512 | Game logo "HARDCORE CLIMBING" in carved icy stone letters with gold trim, a crossed ice axe and dragon wing behind, transparent background (QUI il testo serve: controlla che sia scritto giusto) |

**Cornici e pannelli (9-slice)**
| Nome | Misura | Prompt |
|---|---|---|
| `panel_main.png` | 512x512 | Window frame: dark navy translucent glass center, carved slate stone border with frost on top corners and small gold rivets in the corners, plain stretchable edges |
| `panel_card.png` | 256x256 | Smaller item card: dark slate center, thin ice-blue inner line, gold corner studs |
| `panel_header.png` | 512x128 | Title banner plate: carved stone with gold trim and two small ice crystals at the ends, empty center |
| `panel_toast.png` | 512x128 | Notification bar: dark glass with a thin gold left accent, rounded ends |
| `panel_quest.png` | 512x192 | Quest/mission scroll plate: dark leather-and-stone, small compass emblem on the left corner, empty center |
| `rarity_common.png` / `_rare` / `_epic` / `_legendary` | 256x256 ognuna | Item card frame, same shape for all four: grey stone (common), ice-blue glowing (rare), violet crystal (epic), gold with ember glow (legendary) |

**Pulsanti (9-slice, 3 stati ciascuno: `_normal`, `_hover`, `_pressed`)**
| Nome | Misura | Prompt |
|---|---|---|
| `btn_primary_*` | 384x128 | Wide game button, warm gold-orange glossy face with carved stone rim; hover = brighter with soft glow; pressed = darker, pushed in |
| `btn_secondary_*` | 384x128 | Same shape, frosted ice-blue face |
| `btn_danger_*` | 384x128 | Same shape, deep red face |
| `btn_round_*` | 256x256 | Round mobile action button, dark glass with ice-blue rim (icon goes on top) |
| `btn_close.png` | 128x128 | Small round close button with an X made of two crossed ice shards |

**Icone dei menu e dell'HUD (256x256)**
`icon_shop` (market stall with lantern), `icon_backpack` (climber backpack with rope),
`icon_dragons` (dragon head emblem), `icon_crafting` (anvil with hammer), `icon_teleport`
(glowing rune portal), `icon_settings` (gear), `icon_coin` (gold coin with a mountain engraved),
`icon_health` (red heart with frost edge), `icon_stamina` (green lightning bolt), `icon_warmth`
(thermometer with flame), `icon_cold` (thermometer with snowflake), `icon_piton` (steel piton
with rope loop), `icon_altitude` (mountain with up arrow), `icon_quest` (scroll with compass),
`icon_egg` (speckled dragon egg), `icon_lock` (padlock with frost).

Meteo e ora: `weather_clear`, `weather_night`, `weather_cloudy`, `weather_rain`,
`weather_thunder`, `weather_storm`, `weather_snow`.

Comandi da telefono (bianchi su trasparente, vanno sopra `btn_round`): `act_climb` (ice axe),
`act_jump`, `act_piton`, `act_grapple` (grappling hook), `act_throw` (spinning axe),
`act_sprint`, `act_mine` (pickaxe), `act_shoot` (dragon fire breath).

Elementi dei draghi (emblema tondo 256x256, un colore guida per elemento, prendi i colori da
`DragonConfig` e dai modelli: Gas è azzurro/ciano con nuvole magenta, non verde):
`elem_Roccia`, `elem_Brace`, `elem_Gelo`, `elem_Cosmico`, `elem_Tempesta`, `elem_Sole`,
`elem_Ombra`, `elem_Eclissi`, `elem_Fulmine`, `elem_Ossa`, `elem_Gas`.

Minerali: se in `artifacts/materiali-20261007/` ci sono già le immagini, riusale (ritagliate a
256x256 con lo stesso contorno); altrimenti `ore_Carbone`, `ore_Ferro`, `ore_Oro`,
`ore_Cristallo`, `ore_Rubino`, `ore_Cosmico`.

Negozio Robux (512x512, cornice gold, sfondo pieno scuro, per gamepass e prodotti):
`pass_FastIncubation`, `pass_EggFinder`, `pass_ExtraDragon`, `pass_ExtraIncubator`,
`pass_TrainingX2`, `prod_Coins1000`, `prod_InstantHatch`, `prod_Revive`, `prod_TrainingBoost`.

Pagina del gioco: `game_icon.png` 512x512 (climber + dragon on the summit, bold, readable as a
small square) e `thumb_1.png`..`thumb_3.png` 1024x576 (scalata sul ghiaccio, arena dei draghi,
borgo giapponese ai piedi della montagna).

Fine compito 1: messaggio finale con l'elenco dei file. Il caricamento su Roblox lo fa Claude
(Studio MCP) o Mirko (Asset Manager > Bulk Import): Codex non può caricare.

---

## Compito 2: le schermate in StarterGui (branch `codex/ui-startergui`)

Parti da `main` aggiornato (chiedi a Mirko se le ultime modifiche sono già nel commit). Segna in
`LAVORI.md` i file: `default.project.json`, `src/gui/**`, `src/shared/UiAssets.luau`,
`src/client/{Theme,HUD,MainMenu,DragonUI,CraftingUI,DeathScreen,TeleportMenu,UIPolish,MobileControls}.luau`,
`src/first/LoadingScreen.client.luau`.

1. **ID delle immagini**: crea `src/shared/UiAssets.luau` con una tabella `nome -> "rbxassetid://..."`
   per ogni PNG del compito 1, tutti con stringa vuota per ora (li riempie Claude dopo il caricamento),
   e una funzione `UiAssets.get(name): string?` che restituisce nil se l'id è vuoto.
2. **StarterGui con Rojo**: in `default.project.json` aggiungi
   `"StarterGui": { "$path": "src/gui", "$ignoreUnknownInstances": true }`.
   In `src/gui/` una cartella per ScreenGui (`MainMenu`, `ClimbHUD`, `DeathScreen`, `Teletrasporto`,
   `MobileControls`), con `init.meta.json` (`ResetOnSpawn = false`, `IgnoreGuiInset` dove serve,
   `ZIndexBehavior = Sibling`) e i figli come `.model.json`. Stessi nomi delle ScreenGui di adesso,
   così il resto del codice continua a trovarle.
3. **Il codice usa StarterGui**: in ogni file client sostituisci la costruzione dei Frame con
   `PlayerGui:WaitForChild("<Nome>")` e i riferimenti per nome; la logica (aggiornamenti, tasti,
   remote) resta identica. **Ripiego**: se la ScreenGui non c'è, il file crea quella di oggi (così
   il gioco non si rompe se Mirko apre un place senza StarterGui). Un file per commit.
4. **Immagini**: `ImageLabel`/`ImageButton` con `ScaleType = Slice` e `SliceCenter` presi da
   `index.md`; se `UiAssets.get` dà nil si tiene lo stile di oggi (Frame + UICorner + UIStroke).
   Testi sopra le immagini: font `GothamBold`/`GothamBlack` (titoli `Fantasy` solo per il logo e i
   nomi dei borghi), `TextStrokeTransparency` 0.6 per leggerli su ogni sfondo.
5. **Telefono**: solo misure in Scale con `UIAspectRatioConstraint` e `UISizeConstraint`
   (minimo 44 px per ogni cosa da toccare); niente sopra il joystick (in basso a sinistra) e il
   tasto salto (in basso a destra). Prova le misure 1920x1080, 1366x768, 844x390 (iPhone in
   orizzontale) e 390x844 (verticale), con il plugin Device Emulator descritto nel messaggio finale.
6. **Animazioni leggere**: apertura delle finestre con TweenService (scala 0.92→1 e trasparenza in
   0.18 s), pulsanti che si abbassano di 2 px quando premuti, niente loop a ogni frame.

### Schermate (cosa deve contenere ciascuna)

- **Caricamento** (`src/first/LoadingScreen`): `bg_loading` a tutto schermo, `logo` in alto al
  centro, barra di caricamento con cornice `panel_card`, frase a rotazione con un consiglio
  ("Press F on the wall to place a piton", ...), pulsante "PLAY" (`btn_primary`) quando è pronto.
- **HUD** (`ClimbHUD`): in alto a sinistra salute + stamina con icone e barre dentro una cornice;
  sotto, monete e chiodi; in alto a destra pannello meteo (icona meteo, ora, quota in metri,
  calore); al centro in alto il pannello missione/tutorial (`panel_quest` + `icon_quest`, con
  "Skip" piccolo); pannello del drago fisso (emblema dell'elemento, livello, barra XP); avvisi
  (`Notice`) come toast `panel_toast` che entrano dall'alto.
- **Menu principale** (`MainMenu`): colonna di pulsanti a sinistra con le icone (Shop,
  Backpack, Dragons, Crafting, Teleport) e il tasto tra parentesi su PC (B, I, G, N, T); finestra
  `panel_main` con `panel_header` e `btn_close`; schede:
  - Shop: compra / vendi / Robux. Carte `panel_card` in griglia, prezzo con `icon_coin`, pulsante
    Buy `btn_primary`, Sell `btn_secondary`; la scheda Robux usa le immagini `pass_*` e `prod_*`.
  - Backpack: griglia di carte (minerali `ore_*`, drop, attrezzi) con quantità in basso a destra.
  - Dragons: lista dei draghi con la cornice di rarità, emblema dell'elemento, livello, pulsanti
    Follow / Rest / Hatch; il nido con le uova e il tempo di schiusa.
  - Crafting: ricette con i materiali richiesti (icona + quantità posseduta/richiesta in rosso o
    verde) e il pulsante Craft.
- **Morte** (`DeathScreen`): `bg_death` semitrasparente, "YOU FELL" grande, causa, pulsanti
  Respawn (`btn_primary`) e Revive con Robux (`btn_secondary` + icona).
- **Teletrasporto**: finestra con le destinazioni come carte (icona, nome, distanza), quelle
  bloccate con `icon_lock`.
- **Comandi da telefono** (`MobileControls`): `btn_round` + icone `act_*`, a ventaglio sopra il
  tasto salto; solo i comandi utili in quel momento (sulla parete: piton e salto; nell'arena: shoot).

### Fine compito 2
`git rebase main`, branch pronto. Nel messaggio finale scrivi cosa deve controllare Claude in Studio:
che le ScreenGui compaiano in StarterGui, che ogni schermata si apra in Play da PC e col Device
Emulator del telefono, e l'elenco delle immagini ancora senza ID.
