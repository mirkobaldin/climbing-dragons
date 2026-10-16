# PNG della rifinitura UI (17/10, sessione cloud)

Fatti con `tools/ui/rifinitura_png.py` partendo dai PNG di Codex approvati
(`artifacts/ui-cornici-20261016/png`): niente disegni nuovi, solo correzioni e varianti.
Anteprima (non e' uno screenshot di Roblox): `anteprima_hud_e_schede.png`
(`tools/ui/rifinitura_anteprima.py`, HUD in alto a sinistra con le misure di `client/HUD`).

Tutti i PNG sono 2x come quelli di Codex: `SliceCenter = Rect.new(l, t, larghezza - r, altezza - b)`,
margini qui sotto in pixel del PNG nell'ordine **sinistra, sopra, destra, sotto**.

## Da caricare e SOSTITUIRE (stesso nome in `src/shared/UiAssets.luau`, cambia solo l'ID)

| File | Misura | Margini 9-slice | Perche' |
|---|---|---|---|
| `frame_tab_normal.png` | 552x128 | 109, 38, 109, 38 | il fondo aveva un gradino di colore proprio dove inizia il margine destro: allungata, la scheda sembrava "tagliata" (punto 2) |
| `frame_tab_hover.png` | 552x128 | 109, 38, 109, 38 | idem |
| `frame_tab_selected.png` | 552x128 | 109, 38, 109, 38 | idem |
| `frame_panel.png` | 800x600 | 112, 112, 112, 112 | fra la cornice e il fondo carbone c'era una fessura trasparente di 20 px: dentro i pannelli si vedeva lo scenario (punto 7) |

I margini non cambiano: basta mettere il nuovo ID al posto di quello vecchio in `UiAssets.ids`.

## Da caricare NUOVI (ID vuoti gia' pronti in `UiAssets.ids`)

| Nome (id) | File | Misura | Margini 9-slice | Spazio libero (x, y, larg., alt.) | Obliquo del riempimento |
|---|---|---|---|---|---|
| `frame_bar_health_slant` | `frame_bar_health_slant.png` | 680x72 | 89, 17, 89, 16 | 30, 17, 617, 39 | 21 px |
| `frame_bar_stamina_slant` | `frame_bar_stamina_slant.png` | 631x56 | 78, 14, 78, 14 | 35, 14, 559, 28 | 15 px |
| `frame_bar_shield_slant` | `frame_bar_shield_slant.png` | 591x56 | 68, 14, 68, 14 | 33, 14, 523, 28 | 15 px |
| `frame_bar_xp_slant` | `frame_bar_xp_slant.png` | 586x48 | 60, 11, 60, 11 | 26, 11, 532, 26 | 14 px |

Barre a parallelogramma (punto 6: "com'erano prima, con la cornice"): i PNG delle barre di Codex
inclinati (shear orizzontale 0,55, in alto spostati a destra come le vecchie barre oblique).
Margini, spazio libero e obliquo sono gia' in `UiAssets.slices` / `UiAssets.frames`
(voce `shear`): li usa `UiKit.bar`. Finche' gli ID sono vuoti le barre restano dritte nella
cornice dritta (stesse misure nuove, attaccate).

## Gia' caricato, nessun PNG nuovo
- Sfondo del palco nel menu draghi (punto 9): `bg_loading` (la valle col ghiacciaio della
  schermata di caricamento), ritagliato nel codice (`ImageRectOffset 440,0`, `ImageRectSize
  576x576`). Se si vuole un'immagine apposta basta caricarla col nome `bg_drago_valle` (quadrata):
  `client/DragonUI` la usa al posto del ritaglio.
- Medaglione del meteo e del tasto ⚙: `frame_currency_medallion`; targa dell'ora e del montepremi:
  `frame_currency_counter` (tinta di rosa per il montepremi).

## Misure corrette senza cambiare i PNG
Lo spazio libero delle barre dritte (`UiAssets.frames.frame_bar_*`) ora e' l'interno vero
misurato sul PNG (salute 22..618 invece di 51..589): il riempimento arriva ai terminali invece di
fermarsi prima.
