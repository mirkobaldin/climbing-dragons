# Climbing & Dragons — pulsanti e cornici v2

Consegna del 14 ottobre 2026. Branch `codex/ui-bottoni-v2-20261014`.
**24 PNG richiesti + 2 livelli opzionali del piedistallo**, tutti RGBA e privi di testo.
I 105 file preesistenti in `artifacts/ui-20261010/` sono identici al punto di partenza (SHA-256).
Nessun utilizzo delle vecchie immagini è stato sostituito.

Apri [preview.html](preview.html) per provare normal/hover/pressed col mouse.
[anteprima.png](anteprima.png) confronta tutti i 21 stati a 120×44, 200×56 e 320×64
su sfondo illustrato, pannello scuro e sfondo chiaro: 189 combinazioni.
Altre tavole: [panoramica](review/panoramica.png), [cornici e piedistallo](review/cornici.png),
[metà grandezza](review/telefono-50.png).

## Chiavi e impieghi

| Chiave / nome PNG | Misura | 9-slice | Impiego |
|---|---|---|---|
| `btn_buy_v2_normal` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Buy / Craft / Hatch / Follow |
| `btn_buy_v2_hover` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Buy / Craft / Hatch / Follow |
| `btn_buy_v2_pressed` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Buy / Craft / Hatch / Follow |
| `btn_sell_v2_normal` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Sell / Sell all |
| `btn_sell_v2_hover` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Sell / Sell all |
| `btn_sell_v2_pressed` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Sell / Sell all |
| `btn_main_v2_normal` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Rebirth / Ride / Unlock / Upgrade |
| `btn_main_v2_hover` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Rebirth / Ride / Unlock / Upgrade |
| `btn_main_v2_pressed` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Rebirth / Ride / Unlock / Upgrade |
| `btn_alt_v2_normal` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Rest / Skip / Reset |
| `btn_alt_v2_hover` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Rest / Skip / Reset |
| `btn_alt_v2_pressed` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Rest / Skip / Reset |
| `btn_off_v2_normal` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Not ready yet / unavailable |
| `btn_off_v2_hover` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Not ready yet / unavailable |
| `btn_off_v2_pressed` | 512 × 160 | `Rect.new(64, 48, 448, 112)` | Not ready yet / unavailable |
| `tab_on_v2_normal` | 384 × 112 | `Rect.new(56, 36, 328, 76)` | Selected tab |
| `tab_on_v2_hover` | 384 × 112 | `Rect.new(56, 36, 328, 76)` | Selected tab |
| `tab_on_v2_pressed` | 384 × 112 | `Rect.new(56, 36, 328, 76)` | Selected tab |
| `tab_off_v2_normal` | 384 × 112 | `Rect.new(56, 36, 328, 76)` | Unselected tab |
| `tab_off_v2_hover` | 384 × 112 | `Rect.new(56, 36, 328, 76)` | Unselected tab |
| `tab_off_v2_pressed` | 384 × 112 | `Rect.new(56, 36, 328, 76)` | Unselected tab |
| `card_glass_v2` | 256 × 256 | `Rect.new(72, 72, 184, 184)` | Rebirth overlay |
| `card_item_v2` | 256 × 256 | `Rect.new(72, 72, 184, 184)` | Store and crafting cards |
| `pedestal_v2` | 512 × 256 | Nessuno; ScaleType.Fit | Dragon menu |
| `pedestal_base_v2` | 512 × 256 | Nessuno; ScaleType.Fit | Optional clean base for separately tinted runes |
| `pedestal_runes_v2` | 512 × 256 | Nessuno; ScaleType.Fit | Optional white rune overlay, alpha 50%, same size and position as base |

Le famiglie `btn_buy_v2`, `btn_sell_v2`, `btn_main_v2`, `btn_alt_v2`, `btn_off_v2`,
`tab_on_v2` e `tab_off_v2` hanno tutte i suffissi `_normal`, `_hover`, `_pressed`.
Il verde indica acquisti/creazione, il rosso vendite, l'ambra le azioni principali, il blu quelle secondarie.
Il grigio indica indisponibilità; i suoi stati aggiuntivi sono forniti per completezza,
ma un pulsante realmente disattivato dovrebbe mantenere lo stato normal e non rispondere ai clic.

## Collegamento da fare in locale

Le **26 nuove voci** di `UiAssets.ids` sono predisposte come stringhe vuote; i 23 margini nuovi
sono in `UiAssets.slices`. Le voci e gli ID precedenti non sono cambiati.
Il comando `node tools/ui/sync-fallback.mjs` è stato eseguito: non produce differenze di contenuto,
perché nessun JSON delle schermate è stato modificato.

**I PNG non sono stati caricati su Roblox e non hanno nuovi ID pubblicati.**
Come nel precedente incarico `docs/CODEX_UI.md`, importali dall'account del gioco e inserisci gli ID
nelle sole nuove voci. Collegamento e prova in Studio restano a Mirko/Claude.

Prima di collegare i pulsanti, aggiorna il riconoscimento delle misure in
`src/shared/UiView.luau`: attualmente `imageSize` considera ogni `btn_*` da 384×128
e ogni nome sconosciuto da 256×256. Per il set v2 deve riconoscere:

- `btn_*_v2_*`: **512×160**, senza cambiare la misura dei vecchi pulsanti.
- `tab_*_v2_*`: **384×112**.
- `card_glass_v2` / `card_item_v2`: **256×256**.
- Piedistalli e maschera rune: **512×256**, senza 9-slice, rapporto 2:1.

Con i vecchi valori, il bordo destro del nuovo pulsante verrebbe calcolato usando
384 invece di 512. La tavola usa già le misure corrette e la formula di `fitSlice`
con massimo 0,5 per i pulsanti e 0,3 per schede/cornici.

Esempio per il collegamento successivo (non applicato):
```lua
UiView.skin(button, "btn_buy_v2_normal")
```
Mantieni `ImageColor3` bianco sui pulsanti: il colore semantico è già nel PNG.
Scegli i suffissi durante hover/pressione senza cambiare colore con `UiView.tint`.
I PNG pressed sono abbassati di **2 px nella texture sorgente**; un eventuale movimento del testo
va gestito separatamente nel codice, in funzione della scala visualizzata.

Per il vetro, usa un ImageLabel con `BackgroundTransparency = 1`:
il centro ha alpha **185–200/255 (72,5–78,4%)**, già contenuto nel PNG.
Non aggiungere un fondale opaco dietro il vetro se vuoi vedere l'illustrazione.
Per `card_item_v2` il centro ha alpha **0**; il colore della carta può stare in un Frame sottostante.

## Rune colorabili senza alterare il bronzo

`pedestal_v2.png` è la versione completa, con rune neutre già disegnate sulla pietra.
Per colorare **solo** le rune usa invece due ImageLabel sovrapposti, identici per posizione e misura:

1. `pedestal_base_v2`: pietra e bronzo, `ImageColor3` bianco.
2. `pedestal_runes_v2`: anello bianco con alpha massimo circa 50%, `ImageColor3` del drago.

La maschera è registrata sul piano del piedistallo nel suo PNG 512×256:
non ritagliarla nuovamente, non stirarla separatamente e mantieni il rapporto 2:1.
Il suo alpha è già ridotto: non aggiungere un'altra `ImageTransparency = 0.5`.
L'esempio colorato in [cornici.png](review/cornici.png) mostra Frost, Cosmic e Black Lightning.
Gli altri elementi usano la stessa maschera; non sono state introdotte immagini degli elementi rimossi.

## Verifica e limiti

- Tutti i 26 file hanno dimensioni previste, canale alpha e bordi esterni trasparenti.
- I centri 9-slice di tutti i 21 pulsanti/schede hanno **variazione orizzontale zero**:
  nessun disegno centrale viene deformato dall'allungamento.
- Contrasto minimo del testo bianco sul rettangolo centrale: **7,91:1**,
  calcolato anche componendo l'alpha del PNG sul bianco.
- Nessuna scritta tagliata nelle 189 combinazioni della tavola.
- Controllati visivamente panoramica, cornici e tavola al 50%.
  A 120 px, “Not ready yet” richiede testo ridotto; per conservarlo a 20–22 px usa circa 200 px di larghezza.
  Non ridurre tutta la UI a metà in gioco: conserva dimensioni logiche leggibili e toccabili.
- La distanza fisica di un metro e la resa su un telefono reale **non sono state misurate**.
  La conferma finale va fatta in Studio/Play, anche con `SimViewport = Vector2.new(844,354)`.
- La tavola usa Montserrat Black installato con Roblox: è la famiglia a cui Roblox mappa
  `Enum.Font.GothamBlack`, come indicato nella [documentazione ufficiale Font](https://create.roblox.com/docs/reference/engine/enums/Font).
  Nessun file del font viene redistribuito.

## Sorgenti e riproduzione

Grafica creata con lo strumento integrato **imagegen**, una generazione/modifica per asset/stato.
I prompt completi e i percorsi delle sorgenti sono in [sources.json](sources.json);
per i nomi ripetuti è selezionata l'ultima variante.
Le immagini ad alta risoluzione restano nella cartella locale `.codex/generated_images`;
tutti i PNG necessari al gioco sono già salvati **qui**, indipendenti da quella cartella.

`prepare.ps1` esegue l'esportazione tecnica: ritaglio alpha, misure, registro degli stati,
ripetizione della striscia verticale nel centro stirabile, calibrazione dell'alpha del vetro
e della maschera bianca. Non legge né modifica i PNG vecchi.
`preview.mjs` usa Chrome headless con un profilo isolato locale per produrre le tavole;
`preview.html` funziona come anteprima interattiva sul computer di Mirko.

Dalla radice del worktree:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File artifacts/ui-v2-20261014/prepare.ps1 -ValidateOnly
node artifacts/ui-v2-20261014/preview.mjs
node artifacts/ui-v2-20261014/verify.mjs
node tools/ui/sync-fallback.mjs --check
```

Risultati: [validation.json](validation.json), [preview-checks.json](review/preview-checks.json),
[delivery-checks.json](review/delivery-checks.json). Nessuna prova in Studio è dichiarata.

