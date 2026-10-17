# Compito per Codex: interfaccia v4 (cornici leggere, tre temi a colori, tutte le icone)

Scritto il 17/10 sera (sessione cloud). **Sostituisce `docs/CODEX_ICONE_V2.md`**, che non era
ancora stato fatto. Mirko, sull'interfaccia di adesso:
- "i colori sono troppo bruti: ha letteralmente preso il tema dello sfondo di Black Ops 3. Devono
  essere più belli, non grigi: azzurro ghiaccio, viola cosmico, roba a tema dei draghi";
- "la struttura va bene così: solo cornici, sfondi e colori migliori";
- "cornici fighe ma che non siano ostruttive", col riferimento qui sotto;
- le barre di salute, stamina, scudo ed esperienza sono a parallelogramma, quindi anche le loro
  cornici devono esserlo;
- abbiamo aggiunto oggetti, pozioni, pacchetti a Robux e tasti nuovi: servono le icone.

## Prima di iniziare
- Leggi `AGENTS.md`, `gusti/UI/regole.md` (cosa piace e cosa no a Mirko) e
  `docs/CODEX_UOVA_E_CORNICI.md` (come hai fatto le cornici approvate del 16/10: stessi nomi,
  stesse misure, stessi margini 9-slice).
- Branch `codex/ui-v4`, segna il compito in `LAVORI.md`.
- Usa lo strumento di immagini integrato come per le cornici; tieni i prompt in `prompt.json`.
- Non toccare `src/`: gli ID li mette Claude dopo il caricamento.

## Il riferimento di Mirko (cornice di una scheda "Spirit" di un simulatore)
- Bordo **sottile** (circa 6-8 px su 800), viola acceso con una luce interna leggera.
- Gli ornamenti stanno **solo negli angoli**: grappoli di cristalli viola sfaccettati con
  qualche sasso. Non entrano nello spazio del contenuto.
- Il fondo è un **blu notte pieno** (non grigio, non trasparente). La testata ha un'illustrazione
  sfumata (montagne viola) e il ritratto sta in un riquadro col suo bordo.
- Le righe interne (statistiche) sono riquadri scuri arrotondati appena, con un bordo sottile.
- Colori saturi e luminosi: viola, blu, oro per la rarità. Niente grigio "militare".

Prendi da lì l'idea: **cornice leggera + ornamenti di cristallo negli angoli + fondo colorato
pieno**. Restano le nostre regole: angoli vivi o smussati a 45°, niente stile cartoon con
contorni neri spessi, niente foglie (siamo su una montagna di ghiaccio, coi draghi).

## Tre temi (stessi nomi dei file, cartelle diverse)
Il giocatore sceglierà il tema nelle impostazioni (il codice lo fa Claude). Fai prima **Frost**
completo, poi Cosmic, poi Ember.

| Tema | Colori | Ornamenti negli angoli | Fondo dei pannelli |
|---|---|---|---|
| **Frost** (ghiaccio, predefinito) | azzurro ghiaccio `#7FD8FF`, bianco brina `#E8F8FF`, acciaio blu `#3A6EA5` | cristalli di ghiaccio trasparenti con un po' di brina | blu profondo `#0B1E33` → `#123A5C`, brina appena visibile negli angoli |
| **Cosmic** (viola cosmico) | viola `#A77BFF`, magenta `#E26BFF`, oro chiaro `#FFD27A` | cristalli viola come nel riferimento, qualche stellina | indaco `#140C2E` → `#2A1656`, nebulosa leggera |
| **Ember** (eclissi e brace) | oro `#FFB547`, arancio brace `#FF6A2B`, rosso scuro `#7A1E14` | schegge di ossidiana con crepe di brace | bruno-rosso scuro `#1E0D0B` → `#3A1A12`, braci rare in basso |

## 1. Cornici v4 (per ogni tema)
Stessi id, misure, margini 9-slice e spazio libero di `artifacts/ui-cornici-20261016/manifest.json`,
così il codice non cambia. In più:
- **lo spazio libero è pieno**: il fondo del pannello arriva fino al bordo interno della
  cornice. Adesso tra fondo e cornice si vede una fessura trasparente: Mirko l'ha notata nei
  contatori, nel meteo e nel ritratto del giocatore. Nel manifest scrivi anche `fill` = il
  rettangolo fin dove arriva il fondo;
- **leggere**: il bordo non supera il 6% del lato corto. Gli ornamenti stanno negli angoli e
  stanno dentro i margini 9-slice;
- terminali dei pulsanti e delle schede al massimo il 22% della larghezza a 200 px.

Elenco: `frame_portrait_player`, `frame_portrait_dragon` (+ `_gem`, `_rarity`),
`frame_level_badge`, `frame_currency_medallion`, `frame_currency_counter`, `frame_panel`,
`frame_panel_header`, `frame_record_tile`, `frame_slot` (5 stati), `frame_button_primary` e
`frame_button_secondary` (4 stati), `frame_button_danger` (4 stati, rosso), `frame_tab` (3 stati,
fondo uniforme anche nel margine destro), `frame_separator`, `death_ornament`, `frame_toast`,
`frame_card` (nuova: carta del negozio e della lista dei draghi, 360x480, angoli coi cristalli
piccoli; rarità con filo colorato in un livello a parte `frame_card_rarity`).

### Barre a parallelogramma (le più importanti)
`frame_bar_health_slant`, `frame_bar_stamina_slant`, `frame_bar_shield_slant`,
`frame_bar_xp_slant` **disegnate già oblique**: shear 0,55, in alto spostate a destra, come in
`artifacts/ui-rifinitura-20261017/LEGGIMI.md`. Il bordo è sottile e i due lati obliqui sono
paralleli al riempimento. Non sono quelle dritte inclinate.
In più, per ogni barra, il **riempimento** obliquo: `bar_fill_health`, `bar_fill_stamina`,
`bar_fill_shield`, `bar_fill_xp` (stessa forma dello spazio libero, gradiente con una riga di
luce in alto, si allunga in orizzontale con la 9-slice). Colori fissi in tutti i temi:
salute rosso-rubino, stamina verde smeraldo, scudo azzurro, esperienza viola.

### Sfondi (per ogni tema)
- `bg_panel` (1024x1024, si ripete o si stira): fondo dei pannelli e delle finestre, colorato
  come nella tabella, con una texture leggerissima. Niente grigio.
- `bg_menu` (1920x1080): dietro la finestra del menu, più scuro ai bordi.
- `bg_header` (1600x240): illustrazione sfumata per le testate (montagne e ghiaccio per Frost,
  nebulosa per Cosmic, vulcano per Ember), come la testata del riferimento.
- `bg_card` (360x480): fondo delle carte (negozio, draghi), con una luce dal basso.

## 2. Icone (una sola serie, uguale per tutti i temi)
Regole di sempre: 512x512 RGBA, fondo trasparente, soggetto centrato con l'8% di margine,
leggibili a 32 px, spigolose, rilievo vero (luce in alto a sinistra, controluce fredda in basso
a destra), colori saturi, niente testo e niente riquadri tondi colorati dietro.
Fai 2 versioni per icona (v1, v2): Mirko sceglie.

**Da rifare** (stessi nomi di `src/shared/UiAssets.luau`):
- item (29): `item_Ramponi`, `item_Tuta`, `item_Rampino`, `item_PiccoRinforzato`,
  `item_Parapendio`, `item_Sella`, `item_Chiodi`, `item_Torcia`, `item_Bende`, `item_Pitons`,
  `item_Medkit`, `item_Thermos`, `item_MysteryEgg`, `item_RareEgg`, `item_Piccozza`,
  `item_Piccone`, `item_TravelHub`, `item_TravelHome`, `item_TravelArena`, `item_TravelGym`,
  `item_TravelIsland`, `item_TravelCamp`, `item_UpgradeRampino`, `item_UpgradeUncino`,
  `item_UpgradeLancio`, `item_UpgradeEsoscheletro`, `item_UpgradeScudo`, `item_UpgradeStivali`,
  `item_UpgradePicchiata`
- icon (16): `icon_shop`, `icon_backpack`, `icon_dragons`, `icon_crafting`, `icon_teleport`,
  `icon_settings`, `icon_coin`, `icon_health`, `icon_stamina`, `icon_warmth`, `icon_cold`,
  `icon_piton`, `icon_altitude`, `icon_quest`, `icon_egg`, `icon_lock`
- weather (7): `weather_clear`, `weather_night`, `weather_cloudy`, `weather_rain`,
  `weather_thunder`, `weather_storm`, `weather_snow`
- elem (8): `elem_Roccia`, `elem_Gelo`, `elem_Cosmico`, `elem_Tempesta`, `elem_Eclissi`,
  `elem_Fulmine` (Fulmine Nero), `elem_Ossa`, `elem_Gas`. NON Brace, Sole, Ombra.
- ore (6): `ore_Carbone`, `ore_Ferro`, `ore_Oro`, `ore_Cristallo`, `ore_Rubino`, `ore_Cosmico`
- act (8), tasti del telefono: `act_climb`, `act_jump`, `act_piton`, `act_grapple`,
  `act_throw`, `act_sprint`, `act_mine`, `act_shoot`. **Bianche, monocrome, a sagoma piena**:
  il codice le tinge col colore dell'azione.

**Nuove**:
- icone: `icon_news` (pergamena o stendardo col sigillo del drago), `icon_gift` (cassa con
  fasce di ferro e nastro), `icon_stone` (pietra dell'evoluzione: gemma sfaccettata con una
  runa di drago), `icon_theme` (tavolozza a forma di scaglia: scelta del tema), `icon_robux_shop`
  (scrigno con la gemma, per la pagina a Robux), `icon_drop` (mano che lascia cadere: "butta").
- tasti del telefono, bianchi come gli altri act: `act_ride` (testa di drago con la sella),
  `act_fire` (fiammata), `act_glide` (ali del parapendio), `act_unclip` (moschettone aperto),
  `act_roar` (drago che ruggisce, è il tasto dello speciale), `act_use` (mano che usa
  l'oggetto in mano).
- oggetti: `item_VelaDrago` (parapendio con vere ali di drago), `item_VelaTempesta` (ali di
  viverna della tempesta coi fulmini), `item_DragonFeast` (coscia arrosto e pesce su un
  vassoio di pietra con le scaglie), `item_EvoStone` (come `icon_stone`, più grande).
- pozioni (boccette sfaccettate, tappo di metallo, liquido che brilla; si comprano a Robux e
  durano 15 minuti): `item_PotionCoins` (oro, con una moneta dentro), `item_PotionHatchLuck`
  (azzurra, con un uovo inciso), `item_PotionShinyLuck` (dorata con stelline), `item_PotionDropLuck`
  (verde, con un artiglio).
- prodotti a Robux: `prod_MysteryEgg`, `prod_RareEgg`, `prod_EpicEgg` (uova coi colori della
  rarità: bianco, blu, viola), `prod_NestWarmer` (nido di pietra con braci), `prod_InstantHatch`
  (uovo che si apre con la luce), `prod_Revive`, `prod_Coins_S`, `prod_Coins_M`,
  `prod_Coins_L`, `prod_Coins_XL` (mucchi di monete sempre più grandi: borsa, forziere, carro),
  `prod_GoldRain` (nuvola che fa piovere monete), `prod_WildDragon` (corno da guerra col drago).
- pass: `pass_2xCoins`, `pass_2xBossDrops`, `pass_VIP` (corona con la gemma), `pass_FastTravel`
  (portale), `pass_RoyalWings` (parapendio d'oro). Rifai anche `pass_EggFinder`,
  `pass_FastIncubation`, `pass_ExtraDragon`, `pass_ExtraIncubator`, `pass_TrainingX2`.
- drop dei mostri: quelli di `docs/CODEX_MOSTRI_BIOMI.md` (`drop_Scaglia_Muschio`,
  `drop_Zanna_Coboldo`, `drop_Membrana_Viverna`, `drop_Scaglia_Gelo`, `drop_Ghiandola_Fuoco`,
  `drop_Sacca_Veleno`, `drop_Nucleo_Tempesta`) più quelli di oggi: `drop_Pelliccia_Yeti`,
  `drop_Cristallo_Ghiaccio`, `drop_Nucleo_Glaciale`.

## 3. Immagini dei pacchetti a Robux (come i pacchetti del simulatore che ha mandato Mirko)
Illustrazioni 1024x576 (le carte del negozio le tagliano), fondo trasparente o sfumato scuro:
- `pack_Starter`: un uovo epico viola che brilla, monete, due pozioni azzurre e due dorate;
- `pack_Hatcher`: due uova blu, pozioni azzurre e dorate, un nido;
- `pack_Hunter`: mucchio di monete, pozioni dorate e verdi, un artiglio di drago;
- `pack_Rider`: sella di drago, pietre dell'evoluzione, carne per draghi.

## Consegna
- `artifacts/ui-v4-<data>/frost/`, `cosmic/`, `ember/` (cornici, barre, riempimenti, sfondi:
  `png/`), più `icone/` (v1 e v2) e `pacchetti/`.
- per ogni tema: `catalogo_cornici.png`, `catalogo_stati.png`, `anteprima_telefono_891x353.png`,
  `anteprima_computer_1920x1080.png` (HUD e una finestra del menu, con le barre oblique piene);
- `catalogo_icone.png` (su fondo scuro e su fondo chiaro);
- `manifest.json` come quello delle cornici (file, misure, slice, free_rect, **fill_rect**,
  free_circle);
- `LEGGIMI.md`: cosa cambia, quali versioni consigli e perché.

Nel messaggio finale scrivi cosa deve guardare Mirko e cosa deve caricare Claude.
