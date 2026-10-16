# Codex: uova di drago 3D e cornici della UI (2026-10-16)

Due compiti separati, due branch. Prima di iniziare: riga in `LAVORI.md` (cartella principale),
lavoro SOLO in `../RObloxGame-codex`, nessun file in `src/`. Leggi prima `AGENTS.md` e la cartella
`gusti/` (soprattutto `gusti/UI/regole.md` e `gusti/Mappa/regole.md`): sono i gusti di Mirko.
Testi su immagini e modelli: nessuno. L'integrazione in Studio (upload, codice, prove in Play) la
fa Claude: tu consegni file, anteprime e un manifest.

---

## COMPITO 1 — Uova di drago (branch `codex/uova-3d-20261016`)

### Perche' si rifanno
Mirko ha bocciato tutte le proposte fatte finora (icone piatte, uova con le ali, uova lucide da
cartone animato, il set Blender "senza rilievo"). Cosa vuole:
- uova **realistiche**, come un oggetto vero illuminato, non un'icona;
- **scaglie sovrapposte come geometria con spessore**: ogni scaglia e' un pezzo in rilievo che
  copre in parte quella sotto, con il bordo che fa ombra (non una texture dipinta su un ovale);
- **niente ali, niente aloni, anelli, scritte o cornici** attorno all'uovo: gli effetti (luce,
  particelle, fulmini) li fa il gioco;
- ogni uovo si riconosce dall'elemento a colpo d'occhio, anche piccolo nel nido.

### Gli 8 elementi (solo questi: Brace, Sole e Ombra NON esistono piu')
| id (nome file) | Nome in gioco | Materiale delle scaglie | Palette | Dettaglio tra le scaglie |
|---|---|---|---|---|
| Roccia | Rock | pietra scheggiata, scaglie spesse e irregolari | bruno, ocra, grigio caldo | fessure arancio-brace molto sottili |
| Gelo | Frost | ghiaccio compatto semi-traslucido sui bordi | bianco, azzurro ghiaccio, blu profondo | brina nelle giunture |
| Tempesta | Storm | ardesia levigata, scaglie lunghe a punta | blu temporale, grigio piombo | venature azzurre a zig-zag |
| Fulmine | Black Lightning | ossidiana nera lucida | nero, viola scuro | crepe viola elettrico |
| Cosmico | Cosmic | smalto scuro con riflessi | blu notte, viola, puntini stellari | nebulosa visibile nelle fessure |
| Eclissi | Eclipse | metallo brunito scuro | nero, bronzo, oro | linee d'oro caldo, come una corona |
| Gas | Gas | scaglie molli, un po' organiche | verde petrolio, ciano, fucsia | vapore colorato nelle giunture |
| Ossa | Bone | osso e avorio, scaglie a lastra | avorio, beige, grigio | crepe da fossile |

### Forma e misure
- Uovo dritto, leggermente piu' largo in basso, proporzione altezza/larghezza ~1,3.
- In gioco e' alto 2,6 studs; il pivot al centro del volume, base piatta quanto basta per stare in
  piedi nel nido.
- Deve reggere il **primo piano**: nella schiusa la camera sta a ~8 studs e l'uovo occupa il 40%
  dello schermo (luce principale in alto a sinistra).

### Pezzi da consegnare per ogni elemento
1. `Uovo_<id>` — l'uovo intero (mesh unica o pochi pezzi), max 15.000 triangoli per mesh
   (limite Roblox 20.000), texture PBR 1024x1024 (colore, normal, roughness, metalness).
2. `Uovo_<id>_Luce` — **guscio interno della luce**: una mesh che sta appena sotto le scaglie e si
   vede solo nelle giunture/crepe (in gioco diventa Neon del colore dell'elemento e si accende
   prima della schiusa). Stesso pivot dell'uovo.
3. `Uovo_<id>_Frammenti` — 8-12 frammenti del guscio (gruppi di scaglie con spessore), ognuno un
   oggetto separato col pivot al suo centro, pronti a volare via quando l'uovo si rompe.

### Prima l'anteprima, poi l'export
- **Passo 1 (da approvare da Mirko)**: un foglio con gli 8 uova renderizzati in Blender 5.2
  (Cycles), stessa luce (principale in alto a sinistra, contro-luce fredda), sfondo grigio scuro
  neutro, vista di tre quarti + un dettaglio ravvicinato delle scaglie di 2 uova. Niente export
  finche' Mirko non dice si'.
- **Passo 2**: FBX (uno per uovo, scala in studs, Y in alto), texture PNG, e un `manifest.json` con
  nomi, triangoli, file delle texture.
- Cartella: `artifacts/uova-3d-20261016/` (render, `.blend`, `fbx/`, `textures/`, `manifest.json`).
- Script Blender rigenerabile da riga di comando
  (`blender -b --factory-startup --python uova.py -- --export`), come `tools/blender/borghi.py`.

### Da non fare
Ali, aloni, anelli, testo, sfondo dentro il modello, forme di icona, colori "caramella" lucidi,
texture dipinte al posto del rilievo, nomi in italiano dentro i file diversi dagli id della tabella.

---

## COMPITO 2 — Cornici e pezzi della UI (branch `codex/ui-cornici-20261016`)

### Cosa vuole Mirko
Cornici fantasy ornamentali con **profondita' vera**, non un rettangolo con contorno, angoli tondi,
gradiente o ombra generica. Tre livelli leggibili:
1. **ornamenti in primo piano**: artigli, scaglie, corna, creste, incisioni;
2. **struttura della cornice**: metallo scuro lavorato e oro antico (o pietra dove indicato);
3. **vano interno arretrato**: dove stanno ritratto, barra o contenuto, chiaramente incassato.

Il rilievo si legge da: spessore dei pezzi scolpiti, sovrapposizioni, ombre di contatto nelle
giunture e sotto gli ornamenti, **luce sempre dall'alto a sinistra**, riflessi discreti sul metallo,
stacco netto tra cornice, fondo e contenuto. Decorazioni ricche attorno ai ritratti, sobrie attorno
a testi e statistiche. Stile coerente col gioco (draghi, ghiaccio e roccia di montagna), riferimento
di presentazione: menu di Black Ops III (angoli vivi, superfici scure, accento oro).

**Mirko vuole i parallelogrammi**: le schede del menu restano parallelogrammi con il solo lato verso
il centro obliquo (come ora), con un effetto di prospettiva 3D.

### Regole tecniche (per tutti i pezzi)
- PNG con **sfondo trasparente** vero (alfa pulito, niente aloni bianchi o neri sui bordi).
- **Nessun testo, numero, icona o contenuto dinamico** dentro l'immagine.
- Ogni cornice che si allunga e' **9-slice**: gli ornamenti (angoli, artigli, creste) stanno solo
  negli angoli o in pezzi separati, i lati e il centro si possono stirare senza deformare niente.
  Per ognuna scrivi nel manifest i margini dello slice in pixel (left, top, right, bottom).
- Le zone libere (vano del ritratto, canale della barra, spazio del numero) sono **vuote e
  trasparenti** o di un colore scuro uniforme indicato, misurate nel manifest (rettangolo in px).
- Pezzi che si colorano dal gioco (gemme dell'elemento e della rarita', riempimento delle barre):
  consegnali **bianchi/grigi su trasparente**, in un livello separato, cosi' il gioco li tinge.
- Risoluzione: 2x della misura d'uso indicata (per gli schermi grandi), lati multipli di 4.
- Stati dove serve: `normal`, `hover`, `pressed` (superficie che si abbassa: ombra piu' corta,
  luce piu' debole in alto, niente effetto gommoso), `selected`, `disabled`.

### Lista dei pezzi (nome file = id che usera' il gioco)
| id | Funzione | Misura d'uso (px) | Note |
|---|---|---|---|
| `frame_portrait_player` | ritratto del giocatore nell'HUD | 128x128 | cerchio interno vuoto (diametro 96), metallo scuro e oro antico, due artigli che stringono il cerchio, piccola cresta in alto |
| `frame_portrait_dragon` | ritratto del drago nell'HUD | 112x112 | corna e scaglie attorno al cerchio (diametro 84); + livello separato `frame_portrait_dragon_gem` (3 gemme bianche da tingere: elemento) e `frame_portrait_dragon_rarity` (filo bianco da tingere: rarita') |
| `frame_level_badge` | cerchietto del livello sul ritratto del drago | 40x40 | medaglione con centro vuoto per il numero |
| `frame_bar_health` | contenitore della salute | 320x36 | alloggiamento allungato, scanalatura scura interna (zona libera per riempimento e valore), terminali ornati alle due estremita' (9-slice) |
| `frame_bar_stamina` | stamina | 300x28 | come sopra, piu' sobrio |
| `frame_bar_shield` | scudo | 280x28 | come sopra, motivo di ghiaccio sui terminali |
| `frame_bar_xp` | XP del drago | 280x24 | come sopra, motivo di scaglie |
| `frame_bar_fill` | riempimento generico delle barre | 64x16 | bianco con luce in alto e ombra in basso (9-slice), il gioco lo tinge |
| `frame_currency_medallion` | medaglione per l'icona di monete/gemme | 56x56 | cerchio vuoto per l'icona (diametro 40) |
| `frame_currency_counter` | alloggiamento del numero accanto al medaglione | 180x40 | 9-slice, zona libera per il numero |
| `frame_panel` | pannelli del profilo, record, statistiche, schede di dettaglio | 400x300 | 9-slice con angoli ornati (artigli/scaglie) e lati sobri; centro scuro semi-pieno (alfa ~0.92) |
| `frame_panel_header` | intestazione dei pannelli | 400x48 | 9-slice, lama di metallo con incisione centrale |
| `frame_record_tile` | tessera di un record nel profilo | 260x84 | 9-slice sobrio, vano a sinistra per l'icona (64x64) |
| `frame_slot` | casella dello zaino e della barra 1-5 | 76x76 | vano interno incassato; stati `normal`, `hover`, `selected`, `valid` (destinazione valida: bordo che si accende), `disabled` |
| `frame_button_primary` | pulsante principale (Travel, Unlock, Craft, Respawn) | 240x56 | forma netta, cornice oro antico, stati `normal/hover/pressed/disabled` |
| `frame_button_secondary` | pulsante secondario | 200x48 | metallo scuro, stati come sopra |
| `frame_tab` | scheda a **parallelogramma** del menu (lato destro obliquo) | 276x64 | stati `normal`, `hover`, `selected`; leggera prospettiva (il lato obliquo piu' alto/avanti), vano a sinistra per l'icona |
| `frame_separator` | separatore orizzontale | 400x12 | lama sottile con piccolo rombo/gemma al centro, sfuma ai lati |
| `death_ornament` | ornamento laterale della schermata di morte (due lati: il gioco lo specchia) | 96x240 | verticale, scolpito, metallo scuro e rosso scuro, nessun riquadro |
| `frame_toast` | avviso breve in alto (esito delle azioni, eventi) | 420x44 | 9-slice sobrio, filo d'oro |

### Prompt per ogni immagine (base da adattare a ciascun pezzo)
"Game UI asset for a fantasy dragon climbing game, [FUNZIONE]. Ornate sculpted frame made of dark
forged metal with antique gold trim, [DECORAZIONI: claws / overlapping dragon scales / small horn
crest / engraved runes], physically modeled with real thickness: foreground ornaments overlapping
the frame, contact shadows in the joints and under the ornaments, a clearly recessed inner well
[ZONA LIBERA: circular portrait well / long dark bar channel / empty number slot]. Single key light
from the upper left, soft cool rim light from the lower right, subtle metallic reflections, no
glow. Straight orthographic front view, centered, [PROPORZIONI]. Fully transparent background,
clean alpha edges. No text, no numbers, no icons, no characters inside the well. Corners and
ornaments separated from plain stretchable edges so it can be 9-sliced."

### Consegna
- Cartella `artifacts/ui-cornici-20261016/`: i PNG, un `manifest.json` (per ogni id: file, misura,
  slice `[l, t, r, b]`, zona libera `[x, y, w, h]`, stati, livelli da tingere), e due
  **anteprime montate** (non usate in gioco): HUD + menu su telefono 891x353 (Samsung S24 Ultra
  in orizzontale) e su computer 1920x1080, con contenuti finti, per vedere ingombri e leggibilita'.
- Controlla tu stesso sulle anteprime: ornamenti non deformati, testo leggibile sopra/accanto,
  ingombro sul telefono accettabile (gli ornamenti non devono mangiare spazio ai contenuti).
- Finito: `LAVORI.md` -> PRONTO PER GIUDIZIO. Upload su Roblox, ID in `src/shared/UiAssets.luau`
  e rifacimento della UI li fa Claude dopo l'approvazione di Mirko.
