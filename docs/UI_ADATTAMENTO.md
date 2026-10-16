# Una sola UI per computer e telefono

Ricerca del 17/10 (sessione cloud) per il compito `docs/CLOUD_UI_RIFINITURA.md`. Mirko vuole
"la stessa UI del computer anche sul telefono, come Blox Fruits": stessa impaginazione, solo
piu' piccola, e sul telefono in piu' i tasti da toccare.

## Cosa ho trovato

### 1. Scale contro Offset
- Il team UI di Roblox: l'Offset sono pixel, la Scale e' la percentuale del genitore. Il solo
  Offset va bene solo se il gioco esiste su una piattaforma
  ([Scale vs. Offset, DevForum](https://devforum.roblox.com/t/scale-vs-offset/188291)).
- La Scale da sola "stira" la UI quando cambia il rapporto dei lati (telefono 2,5:1, monitor
  16:9, tablet 4:3): molti sul DevForum la combinano con `UIAspectRatioConstraint` o con una
  scala unica ([UI on Phone, Tablet, and PC](https://devforum.roblox.com/t/ui-on-phone-tablet-and-pc/477962),
  [UI Scaling Across Devices](https://devforum.roblox.com/t/ui-scaling-across-devices/1395004)).
- La documentazione di Roblox avverte che una Scale fissa (es. 75% della larghezza) diventa
  enorme su un televisore 4K: serve adattarsi alla grandezza dello schermo, non solo alle
  percentuali ([Cross-platform development](https://create.roblox.com/docs/en-us/projects/cross-platform)).

### 2. Risoluzione di riferimento + UIScale unica
- Metodo "AutoUIScale": si disegna la UI per una risoluzione di riferimento
  (REFERENCE_WIDTH/HEIGHT) e un solo `UIScale` sulla ScreenGui la adatta allo schermo vero
  ([Roblox AutoUIScale](https://developerplacebruno.itch.io/roblox-autouiscale)). Varianti sul
  DevForum: scala 0,5 quando c'e' il touch, `UISizeConstraint` per non scendere sotto una misura
  minima ([UI size problem](https://devforum.roblox.com/t/ui-size-problem/1190778),
  [Mobile UI Scaling Help](https://devforum.roblox.com/t/mobile-ui-scaling-help/733681)).
- E' quello che fanno i giochi tipo Blox Fruits: sul telefono la UI e' la stessa del computer,
  rimpicciolita; cambiano solo i tasti da toccare. Non ho trovato analisi pubbliche del codice di
  Blox Fruits (nessuna fonte specifica): lo si vede dai video e dagli screenshot.
- Limite: `UIScale` rimpicciolisce anche i testi. `UITextSizeConstraint` ha minimo e massimo
  (sotto 9 px e' difficile da leggere, dice Roblox:
  [Size modifiers and constraints](https://create.roblox.com/docs/en-us/ui/size-modifiers)), ma
  il minimo vale prima della scala: il testo minimo sullo schermo va garantito a mano.
- `UIStroke` e' in pixel e non segue la Scale dei genitori: va scalato a mano o tenuto sottile
  ([UI stroke problem for mobile](https://devforum.roblox.com/t/ui-stroke-problem-for-mobile/2652341)).

### 3. Aree sicure e barra di Roblox
- `ScreenGui.ScreenInsets` ([ScreenInsets](https://create.roblox.com/docs/en-us/reference/engine/enums/ScreenInsets.md)):
  * `CoreUISafeInsets` (predefinito): l'area senza tacche del telefono E senza i tasti di Roblox
    (logo, menu, chat, voce). Consigliato per tutto quello che si tocca o si deve leggere;
  * `DeviceSafeInsets`: evita solo tacche e fori della fotocamera, non i tasti di Roblox;
  * `TopbarSafeInsets`: solo lo spazio libero dentro la barra in alto;
  * `None`: solo per sfondi.
  * `IgnoreGuiInset = true` trasforma `CoreUISafeInsets` in `DeviceSafeInsets`: e' il motivo per
    cui da noi monete, montepremi e "Home ... m" finivano sotto i tasti di Roblox.
- `GuiService.TopbarInset` e' un `Rect` con lo spazio libero nella barra in alto, fra i tasti di
  Roblox a sinistra e il bordo sicuro a destra; cambia mentre si gioca (chat, menu, vita), quindi
  si ascolta `GetPropertyChangedSignal("TopbarInset")`
  ([GuiService](https://create.roblox.com/docs/en-us/reference/engine/classes/GuiService),
  [Top bar Menu Issues](https://devforum.roblox.com/t/top-bar-menu-issues/3060582),
  [Inconsistent Top Bar](https://devforum.roblox.com/t/inconsistent-top-bar/3228098)).
  Sul telefono i tasti di Roblox sono piu' grandi che in Studio: per questo col telefono simulato
  non si vedeva il problema.
- `GuiService.ViewportDisplaySize` (Small/Medium/Large) dice la categoria dello schermo senza
  indovinarla dai pixel ([Build Cross-Platform UI with the ViewportDisplaySize API](https://devforum.roblox.com/t/full-release-build-cross-platform-ui-with-the-viewportdisplaysize-api/3880384)).
  Utile per i tasti touch, non per l'impaginazione (noi vogliamo la stessa).
- Linee guida di Roblox: sul telefono gli angoli in basso sono dei comandi (joystick e salto):
  niente informazioni importanti li' ([Adaptive design guidelines](https://create.roblox.com/docs/en-us/production/publishing/adaptive-design)).

### 4. Telefoni bassi e tablet
- Samsung S24 Ultra in orizzontale: 891x353 pixel logici utili (dopo la barra). Rapporto 2,5:1:
  molto largo e molto basso. Un tablet (iPad 1024x768) e' quasi 4:3: alto e stretto.
- Con la scala di prima (scala 1 su tutti gli schermi bassi, impaginazione "compact" a parte)
  il telefono aveva un'area logica di 891x353 contro 1280x680 del computer: due impaginazioni
  diverse, e ogni pagina aveva rami compact/short/low che si rompevano (riquadri schiacciati a
  zero, pulsanti fuori, finestra piu' alta dello schermo).

## Metodo scelto

**Una sola impaginazione disegnata per un'area logica minima di 1280x540; una UIScale unica la
adatta a ogni schermo.**

1. `scala = min(larghezza / 1280, altezza / 540)`, fra 0,55 e 2,5. L'area logica e' quindi
   sempre almeno 1280x540 (piu' larga sul telefono, piu' alta sul tablet e sul computer). Sul
   computer 16:9 non cambia niente rispetto a prima (1280x680):
   | schermo (area utile) | scala | area logica |
   |---|---|---|
   | S24 Ultra 891x353 | 0,654 | 1362x540 |
   | iPhone 844x390 meno barra (~844x350) | 0,648 | 1302x540 |
   | iPad 1024x710 | 0,8 | 1280x888 |
   | PC 1366x700 | 1,07 | 1280x656 |
   | PC 1920x1020 | 1,5 | 1280x680 |
   | 4K 3840x2100 | 2,5 | 1536x840 |
2. L'area si misura dalla ScreenGui stessa (`AbsoluteSize`), non dalla telecamera meno
   `GetGuiInset`: cosi' le aree sicure (`ScreenInsets`) sono gia' tolte e la finestra non puo'
   piu' uscire dallo schermo.
3. Menu, HUD e pannelli usano `CoreUISafeInsets` (IgnoreGuiInset = false). Le cose che stanno
   NELLA fila della barra di Roblox (monete | montepremi | pietre) usano `GuiService.TopbarInset`
   e se lo spazio non basta scendono sotto la barra.
4. Testo minimo sullo schermo: 10 pixel veri (`UiKit.text` alza la grandezza logica a
   `10 / scala` quando la scala e' sotto 1). Sul telefono un testo da 16 diventa 16 (10,5 veri),
   uno da 13 diventa 16.
5. I tasti da toccare (MobileControls) restano fuori dalla scala: devono avere un'area di tocco
   fisica di almeno 44 punti.
6. Dentro le pagine: misure in pixel logici (Offset), percentuali solo per dividere lo spazio
   (lista 58% / scheda 42%), e niente piu' rami "se telefono": se una pagina deve cambiare, lo fa
   in base alla SUA misura logica (che ora e' la stessa sul telefono e sul computer piccolo).

## Come l'ho applicato qui
- `shared/UiView`: `UiView.REF` (1280x540), `UiView.scaleFor`, `fitScale` con la nuova formula,
  `UiView.guiViewport(gui, cb)` (area vera della ScreenGui, con la prova `SimViewport`),
  `UiView.compact` vero solo per schermi in verticale (area logica stretta),
  `UiView.topbar()` (spazio libero della barra di Roblox in pixel logici).
- `client/UiKit`: `UiKit.minText` (testo minimo, lo aggiorna chi chiama fitScale).
- `client/MainMenu`: finestra, intestazione, colonna delle schede e pagina con una sola
  impaginazione; spariti i rami compact/short.
- Pagine (`UpgradeUI`, `TravelUI`, `CraftingUI`, `ProfileUI`, `DragonUI`): con l'area logica
  minima di 540 la pagina e' alta almeno ~450, quindi i rami "low" (h < 420) non scattano piu';
  restano solo come rete di sicurezza.
- `client/HUD`, `client/Montepremi`, `client/Combat`: stessa scala, posizioni dalle aree sicure.
- Prova dal computer: attributo `SimViewport = Vector2.new(891, 353)` sul giocatore (simula
  l'area utile del telefono dentro la finestra di Studio) e `SimTouch = true` per i tasti.
