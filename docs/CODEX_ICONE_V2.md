# Compito per Codex: icone e cornici v2 (due temi, piu' versioni)

> **Sostituito da `docs/CODEX_UI_V4.md` (17/10 sera): usa quello.**

Scritto il 17/10 (sessione cloud) su richiesta di Mirko: "rifare le icone e le cornici ancora
piu' fighe, piu' versioni, un set in un modo e uno a tema diverso (colori), un po' le forme ma
sempre spigolose".

## Prima di iniziare
- Leggi `AGENTS.md`, `gusti/UI/regole.md` (cosa piace e cosa no a Mirko) e
  `docs/CODEX_UOVA_E_CORNICI.md` (come hai fatto le cornici approvate del 16/10).
- Lavora nella tua copia, branch `codex/icone-v2`, segna il compito in `LAVORI.md`.
- Usa lo strumento di immagini integrato come per le cornici; tieni i prompt in `prompt.json`.
- Non toccare `src/`: gli ID li mette Claude in locale dopo il caricamento.

## Stile (regole di Mirko)
- **Spigoloso**: angoli vivi, sfaccettature, punte; niente tondo morbido da "app" (i cerchi
  veri vanno bene solo dove la forma e' tonda: monete, medaglioni).
- Profondita' vera: rilievo scolpito, luce dall'alto a sinistra, controluce fredda in basso a
  destra, ombra interna. Colori saturi ma non plastica. Leggibili a 32 px sul telefono.
- **Sbagliato** (bocciato): icone piatte, uova con le ali, set senza rilievo, contorni neri
  spessi da gioco per bambini piccoli, riquadri tondi colorati dietro l'icona.
- Fondo trasparente, soggetto centrato con 8% di margine, nessun testo dentro l'icona.

## Due temi completi (stessi nomi, cartelle diverse)
- **Tema A "Forgia"** (quello di adesso, migliorato): oro antico, ferro brunito, braci.
- **Tema B "Tempesta di ghiaccio"**: argento, acciaio blu, ghiaccio, bagliore ciano e viola
  dei fulmini. Stesse forme del tema A, cambiano materiali e colori.
Per ogni icona fai **3 versioni** per tema (A1/A2/A3, B1/B2/B3): Mirko sceglie, poi si
confezionano solo quelle scelte.

## Le icone (85 di adesso + 4 nuove = 89)
Stessi nomi di `src/shared/UiAssets.luau`:
- **item (29)**: `item_Ramponi`, `item_Tuta`, `item_Rampino`, `item_PiccoRinforzato`,
  `item_Parapendio`, `item_Sella`, `item_Chiodi`, `item_Torcia`, `item_Bende`, `item_Pitons`,
  `item_Medkit`, `item_Thermos`, `item_MysteryEgg`, `item_RareEgg`, `item_Piccozza`,
  `item_Piccone`, `item_TravelHub`, `item_TravelHome`, `item_TravelArena`, `item_TravelGym`,
  `item_TravelIsland`, `item_TravelCamp`, `item_UpgradeRampino`, `item_UpgradeUncino`,
  `item_UpgradeLancio`, `item_UpgradeEsoscheletro`, `item_UpgradeScudo`, `item_UpgradeStivali`,
  `item_UpgradePicchiata`
- **icon (18)**: `icon_shop`, `icon_backpack`, `icon_dragons`, `icon_crafting`,
  `icon_teleport`, `icon_settings`, `icon_coin`, `icon_health`, `icon_stamina`, `icon_warmth`,
  `icon_cold`, `icon_piton`, `icon_altitude`, `icon_quest`, `icon_egg`, `icon_lock`,
  **`icon_news`** (nuova: notizie dell'HUD, al posto del ritratto: pergamena/stendardo con un
  sigillo a forma di drago), **`icon_gift`** (nuova: pacco dei regali del tempo di gioco, cassa
  con fasce di ferro e un nastro, spigolosa)
- **weather (7)**: `weather_clear`, `weather_night`, `weather_cloudy`, `weather_rain`,
  `weather_thunder`, `weather_storm`, `weather_snow`
- **act (8)**: `act_climb`, `act_jump`, `act_piton`, `act_grapple`, `act_throw`, `act_sprint`,
  `act_mine`, `act_shoot` — **ATTENZIONE**: sono le icone dei tasti del telefono, ora piatti e
  traslucidi e tinti dal codice col colore dell'azione: falle **bianche, monocrome, a sagoma
  piena** (solo il tema conta per il taglio delle forme, non per i colori). Aggiungi `act_ride`,
  `act_fire`, `act_glide`, `act_unclip` (oggi questi tasti non hanno icona).
- **elem (8)**: `elem_Roccia`, `elem_Gelo`, `elem_Cosmico`, `elem_Tempesta`, `elem_Eclissi`,
  `elem_Fulmine` (Fulmine Nero), `elem_Ossa`, `elem_Gas` (NON Brace, Sole, Ombra)
- **ore (6)**: `ore_Carbone`, `ore_Ferro`, `ore_Oro`, `ore_Cristallo`, `ore_Rubino`, `ore_Cosmico`
- **pass (5)**: `pass_FastIncubation`, `pass_EggFinder`, `pass_ExtraDragon`,
  `pass_ExtraIncubator`, `pass_TrainingX2`
- **prod (4)**: `prod_Coins1000`, `prod_InstantHatch`, `prod_Revive`, `prod_TrainingBoost`
- **nuove (2)**: `item_VelaDrago` (parapendio con vere ali di drago), `item_VelaTempesta` (ali di
  viverna antica della tempesta, membrane con fulmini). Guarda i modelli in
  `ReplicatedStorage.Vele` (DragonWings, AncientStormWyvern) descritti in `docs/CODEX_OGGETTI.md`.
- Le icone dei drop dei mostri nuovi le trovi in `docs/CODEX_MOSTRI_BIOMI.md` (stesso stile).

Misure: 512x512 RGBA (il gioco le mostra da 24 a 96 px).

## Cornici v2 (stessi id di `artifacts/ui-cornici-20261016/manifest.json`)
Rifai il set completo nei due temi, con le stesse misure, margini 9-slice e spazio libero
(il codice non deve cambiare): `frame_portrait_player`, `frame_portrait_dragon` (+ gem/rarity),
`frame_level_badge`, `frame_bar_health/stamina/shield/xp` **e le loro versioni oblique**
`_slant` (vedi `artifacts/ui-rifinitura-20261017/LEGGIMI.md`: shear 0,55, in alto spostate a
destra; disegnale gia' oblique invece di inclinare quelle dritte), `frame_bar_fill`,
`frame_currency_medallion`, `frame_currency_counter`, `frame_panel` (**fondo carbone fino alla
cornice, nessuna fessura trasparente**), `frame_panel_header`, `frame_record_tile`,
`frame_slot` (5 stati), `frame_button_primary/secondary` (4 stati), `frame_tab` (3 stati,
**fondo interno uniforme anche nel margine destro**: il gradino tagliava la scheda),
`frame_separator`, `death_ornament`, `frame_toast`.
Forme: piu' spigolose di adesso (punte, smussi a 45 gradi, artigli), ma i terminali dei
pulsanti e delle schede non devono superare il 22% della larghezza a 200 px.

## Consegna
- `artifacts/ui-icone-v2-<data>/temaA/` e `temaB/`: `png/` (versioni 1-3), `catalogo_A.png` e
  `catalogo_B.png` (tutte le icone in griglia, sopra fondo scuro e sopra fondo chiaro),
  `catalogo_cornici_A.png`/`_B.png` (come `catalogo_pezzi.png` e `catalogo_stati.png`),
  `anteprima_telefono_891x353.png` e `anteprima_computer_1920x1080.png` per ogni tema.
- `manifest.json` come quello delle cornici (file, misure, slice, free_rect, free_circle).
- `LEGGIMI.md`: cosa cambia rispetto a ora, quali versioni consigli e perche'.
- Nel messaggio finale: cosa deve guardare Mirko e cosa deve caricare Claude.
Mirko sceglie tema e versioni; poi si confeziona il set finale (si puo' anche lasciare al
giocatore la scelta del tema in un secondo momento: i nomi uguali lo rendono facile).
