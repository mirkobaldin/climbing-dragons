# Prompt per Codex: rifare TUTTA l'interfaccia, colorata e pulita

Da incollare a Codex così com'è. Branch: `codex/ui-rifacimento-20261014` (parti da `main`, che ha
già i pulsanti v2 uniti). Segna il compito in `LAVORI.md` prima di iniziare. Leggi `AGENTS.md`,
`docs/UI_STARTERGUI.md` e `artifacts/ui-v2-20261014/index.md`.

## Il giudizio di Mirko (2026-10-14, parole sue in sostanza)
"La UI fa schifo, i colori sono spenti, mi viene la depressione. Rifatele tutte e bene."
Problemi visti in gioco (screenshot del menu Teleport, ma vale per tutte le schermate):
1. **Colori spenti**: blu notte, grigio ardesia, oro scuro dappertutto. Anche il set v2
   (`artifacts/ui-v2-20261014/anteprima.png`) è troppo scuro e marrone.
2. **Aloni che escono dai bordi**: gli sfondi colorati / i bagliori dietro icone e pannelli
   sbordano fuori dalle cornici (es. il cerchio sfocato dietro le icone della barra in alto, gli
   aloni delle tessere dei draghi).
3. **Scritte fuori dai riquadri**: nel Teleport le distanze ("1017 m", "1181 m") finiscono sopra il
   bordo destro del pulsante; le etichette della barra in alto ("Shop (P)", "Backpack (I)"...) sono
   tagliate e coperte dalla finestra aperta.
4. **Troppe scritte insieme**: ogni pulsante del Teleport ha due righe piccole ("Base camp (hub)
   / from a travel point" + distanza); titolo "Teleport · from here only Home". Troppo testo,
   troppo piccolo.
5. **Icone sbagliate o mancanti**: `client/Theme.luau` `Theme.ITEM_ICONS` usa icone di ripiego:
   Bende = cuore della salute, Torcia = sole del meteo, Tuta = fiocco del freddo, Parapendio =
   altitudine, Ramponi/Rampino/Piccone = icone d'azione bianche, **Sella = niente**. Lo stesso nel
   Teleport (tutte le destinazioni hanno la stessa spirale).
6. **Scheda del drago brutta** (`client/DragonUI.luau`, `showDetail`): manca l'**abilità speciale**
   del drago (es. Cosmic = doppio salto) e il **Grado** (C/B/A/S) deve stare tra le statistiche.

## Direzione visiva (nuova, vale per tutto)
- **Allegra, satura, luminosa**, stile dei simulatori Roblox più giocati (Pet Simulator 99,
  Dragon Adventures, Blox Fruits): colori pieni e chiari, gradienti vivaci, contorni spessi e
  scuri attorno a forme e scritte, ombra netta sotto (non sfocata), lucidi "candy" in alto.
- Palette guida (usala come token in `client/Theme.luau`, niente colori sparsi nei file):
  azzurro cielo `#3FB8FF`, turchese `#22D3C5`, verde lime `#5BD94A`, giallo sole `#FFD23F`,
  arancio `#FF8A2A`, rosso fragola `#FF4D5E`, viola `#9B5BFF`, rosa `#FF6FB5`; pannelli
  **blu medio** `#2B4C9B`→`#1E3A7A` (non nero), riquadri interni `#18306A` al 60%, testo bianco
  con contorno `#0B1633` spesso 2-3 px.
- Pulsanti per tipo (rifai i PNG v2 in chiave colorata, stessi nomi + `_v3`):
  Buy/Craft/Hatch/Follow verde lime, Sell rosso fragola, azione principale (Ride, Unlock,
  Upgrade, Rebirth) giallo-arancio, secondario azzurro, disabilitato grigio chiaro (non antracite).
- Colori degli elementi dei draghi e delle rarità ben riconoscibili (Comune grigio, Raro azzurro,
  Epico viola, Leggendario oro; shiny con riflesso arcobaleno) su tessere, scheda e notifiche.

## Regole di impaginazione (le controlla `tools/ui/check-ui.mjs`: estendilo)
- **Nessun testo fuori dal suo riquadro**: ogni TextLabel/TextButton con `UIPadding`,
  `TextScaled` + `UITextSizeConstraint` (min 12, max quello di progetto) oppure dimensione
  calcolata con `TextService:GetTextSize`; mai testo con `Size` più piccola del contenuto.
  Aggiungi al check un controllo che misuri le stringhe più lunghe vere (nomi dei Tool da
  `ClimbConfig`, `Names`, destinazioni del Teleport, "Not ready yet") alle 4 risoluzioni.
- **Nessun alone/immagine che esce dal genitore**: bagliori e sfondi colorati dentro la cornice
  (stessa misura o `ClipsDescendants`), niente ImageLabel più grandi del pulsante.
- **Meno parole**: una riga per pulsante. Le info secondarie diventano icone o badge:
  Teleport = icona del posto + nome + badge distanza dentro il pulsante; "from a travel point"
  diventa un lucchetto grigio quando non si può partire da lì, "60 s" un badge con l'orologio.
  Titolo solo "Travel". Fai lo stesso giro su Shop, Backpack, Crafting, Upgrades, HUD.
- La barra in alto (Shop/Backpack/Dragons/Crafting/Upgrades/Travel): etichette leggibili e mai
  coperte; quando una finestra è aperta la finestra parte sotto la barra.
- Telefono: `UiView.compact` e `SimViewport = Vector2.new(844, 354)` devono restare puliti
  (pulsanti >= 44 px, niente sovrapposizioni con `client/MobileControls`).

## Icone da fare (PNG 256x256, sfondo trasparente, stesso stile colorato, contorno scuro)
Una per oggetto, nome `item_<id>.png`, chiavi nuove in `UiAssets` e mappa in `Theme.ITEM_ICONS`:
- Attrezzi (`shared/Gear.luau`): Ramponi, Tuta, Rampino, PiccoRinforzato, Parapendio, **Sella**,
  Chiodi, **Torcia**, **Bende**.
- Negozio (`shared/ShopConfig.luau`): Pitons, Medkit, Thermos, MysteryEgg, RareEgg.
- Tool in mano (nomi in `ClimbConfig`): piccozza, piccone, rampino, torcia (barra in basso 1-4,
  oggi solo scritte: metti l'icona sopra al nome).
- Destinazioni del Teleport (`client/TeleportMenu.luau`): campo base, casa, arena dei draghi,
  palestra (Muscle Beach), **Dragon Island** (gia' nel menu: quinta destinazione fissa, nella GUI
  e' una copia di `Destination4` fatta da `layout()`; mettila nei JSON come `Destination5`),
  campo base numerato.
- Controlla anche minerali, drop dei nemici (`ReplicatedStorage.DropIcone`) e potenziamenti:
  dove un'icona è riusata per un'altra cosa, fanne una giusta.

## Scheda del drago (FIFA ma leggibile)
In `DragonUI.showDetail`:
- In alto: nome, rarità (colore), stadio; il voto grande resta in alto a destra.
- Palco col drago: alone **dentro** il riquadro, colore dell'elemento.
- Griglia statistiche 2 colonne con icona: **Grade** (C/B/A/S col suo colore, da
  `DragonConfig.grade(d)`), Power, Level, Coins/min at home, Ride attack
  (`UpgradeConfig.RIDE_ELEMENT[el].text`, solo adulti) o Evolve (pietre).
- Riquadro **Special ability** ben visibile con icona dell'elemento: testo da
  `DragonConfig.ELEMENTS[...].ability` (es. Cosmico "Double jump (Space in mid-air)"). Mostralo
  anche nelle tessere della griglia come piccola icona e nella schermata di schiusa.
- Tre pulsanti grandi in fondo con i colori nuovi (Follow verde, Ride/Evolve giallo, Sell rosso).

## File che puoi toccare
`src/gui/**`, `src/client/{MainMenu,DragonUI,CraftingUI,UpgradeUI,HUD,TeleportMenu,DeathScreen,
Theme,UIPolish,UIScaler,TutorialHints,Montepremi}.luau`, la parte grafica di
`src/client/MobileControls.luau`, `src/shared/{UiView,UiAssets,UiFallback}.luau`,
`tools/ui/**`, `artifacts/ui-v3-20261014/**`.
**Non toccare**: `src/server/**`, `src/mapgen/**`, logica di gioco nei client (Climbing, Combat,
DragonRide, PetAnimator, DragonProcedural...): li sta cambiando Claude.
Non rinominare i nodi delle ScreenGui senza aggiornare i controller; dopo i JSON
`node tools/ui/sync-fallback.mjs`.

## Consegna
- PNG in `artifacts/ui-v3-20261014/` con `index.md` (nome, misura, margini 9-slice, uso) e una
  tavola `anteprima.png` per OGNI schermata rifatta (HUD, Shop, Backpack, Dragons + scheda,
  Crafting, Upgrades, Travel, Death) a 1920x1080 e 844x390, con le scritte vere più lunghe.
  Guardale tu prima: se una scritta sborda o un alone esce, rifai.
- Chiavi nuove con ID vuoto in `UiAssets.luau` (il caricamento lo fa Claude con lo Studio MCP).
- Commit piccoli in italiano, `git rebase main` alla fine, branch pronto. Nel messaggio finale:
  cosa va provato in Studio e dove.
