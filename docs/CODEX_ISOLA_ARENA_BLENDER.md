# Prompt per Codex: Isola dei Draghi e arena DRACONICA in Blender (senza bake)

Da incollare a Codex. Branch `codex/isola-arena-20261015` da `main`. Leggi prima `AGENTS.md`,
`gusti/` (gusti di Mirko: `gusti/Mappa/regole.md`), `cloud/IsolaDraghi/SCHEDA.md` (misure e punti
di gioco: restano validi), `tools/modelli/LEGGIMI.md` (come arrivano i modelli in Studio).
Segna il compito in `LAVORI.md`. Nessun file `src/**`.

## Perche' (Mirko, 2026-10-15)
"L'isola e l'arena fatte con Claude in cloud fanno cagare. L'arena cosi' fa schifo, deve essere
un'arena DRACONICA. Non fare il bake delle texture."
Oggi l'arena e' un castello squadrato di mattoni marroni con torrette: sembra un forte medievale
qualsiasi, niente draghi. L'isola sotto e' un cono di roccia con texture cotte sfocate.

## Cosa deve essere: un'arena costruita DA e PER i draghi
Idee da combinare (scegli tu, ma il drago deve leggersi da 500 m):
- **Il recinto e' un drago**: le mura sono il corpo di un drago di pietra colossale avvolto ad
  anello attorno all'arena (coda che si chiude sulla testa), oppure lo scheletro di un drago
  antico con le costole che fanno da archi e la cassa toracica come gradinate.
- **Portale = fauci**: si entra dalla bocca spalancata di una testa di drago alta 30 m (i denti
  sono le punte della saracinesca), gli occhi sono bracieri.
- **8 torri = 8 artigli/ali**: pilastri a forma di artiglio o di ala chiusa che si alzano dalle
  mura, ognuno col braciere del suo elemento (Roccia, Gelo, Cosmico, Tempesta, Eclissi,
  Fulmine, Ossa, Gas) e un posatoio in cima (`SPOT_Posatoio1..8`).
- **Pavimento**: grande sigillo di drago inciso (non un cerchio di rune generico), lastre a
  scaglie, segni di artigli e bruciature.
- Dettagli: scaglie scolpite in rilievo sulle mura (geometria, non texture), corna, catene
  enormi, uova di pietra, ossa sparse, stendardi lunghi fra le "costole".
- Riferimenti: Dragon's Dogma (Pawn arena), Elden Ring (Farum Azula, colosseo di Caelid),
  Skyrim Dragonsreach, How to Train Your Dragon (arena di Berk), Monster Hunter (arena dei draghi
  anziani). Stile stilizzato-realistico Roblox, forme grandi e leggibili, niente microdettagli.

## L'isola
- Piu' grande di prima: circa 650 x 650 m di prato (l'arena al centro occupa ~190 m), sotto roccia
  a cono rovesciato con strati, radici di pietra e 3-4 punti da cui cadranno cascate
  (`SPOT_Cascata1..n` sul bordo, l'acqua la fa il gioco).
- Sopra: il prato come mesh separata `Isola_Prato` (colline morbide, NIENTE alberi: li mette il
  gioco; l'erba vera la fa il Terrain usando le altezze di questa mesh, vedi
  `tools/modelli/prato_altezze.js`), sentiero lastricato dall'arrivo al portale, rocce sparse.
- 5 isolette (40-80 m) con rovine draconiche (piccoli altari, ossa, statue) e posatoi.
- Punti di gioco con gli STESSI nomi di `cloud/IsolaDraghi/Markers.json`: SPOT_Arrivo,
  SPOT_Domatore, SPOT_Altare, SPOT_Posatoio1..8, SPOT_PosatoioIsola1..5, SPOT_Cascata*,
  SPOT_Statua_<Elemento>. Origine del modello = centro del pavimento dell'arena, metri, +Y su,
  portale verso +Z (come ora).

## Materiali: NIENTE BAKE, niente texture
Ogni mesh usa materiali piatti col nome `MAT_<Nome>`: in Studio diventano un materiale di Roblox
+ un colore (tabella `plain` in `tools/modelli/carica_modelli.luau`). Usa questi e, se ne servono
altri, aggiungili alla tabella `plain` (puoi toccare quel file) con materiale Roblox e colore:
| Nome | Roblox | Uso |
|---|---|---|
| MAT_Basalto | Basalt, #2B2724 | corpo del drago di pietra, mura |
| MAT_PietraScura | Slate, #3E3936 | lastre, gradinate |
| MAT_Scaglie | Slate, #4A3F3A | scaglie in rilievo |
| MAT_Osso | Limestone, #D9D2C0 | ossa, costole, denti, corna |
| MAT_Bronzo | Metal, #8A5A2E | catene, finiture |
| MAT_Gold | Metal, #D6B046 | (c'e' gia') |
| MAT_Ember | Neon, arancio | (c'e' gia') occhi, bracieri |
| MAT_RocciaIsola | Rock, #6B625A | sotto l'isola |
| MAT_Terra | Ground, #5C4A36 | bordi del prato, sentiero sporco |
| MAT_Lastricato | Cobblestone, #7A7068 | sentiero |
| MAT_Green | LeafyGrass | (c'e' gia') prato |
| MAT_Stendardo_<Elemento> | Fabric, colore dell'elemento | stendardi |
I materiali di Roblox danno gia' la grana: forme e colori devono reggere da soli.
Shade Smooth sulle forme organiche (Mirko non vuole facce piatte su rocce e corpi).

## Consegna (stesso formato dei modelli del cloud, vedi tools/modelli/LEGGIMI.md)
`artifacts/isola-arena-20261015/`:
- `IsolaDraghi.fbx` (pezzi separati: `Isola_Roccia_*`, `Isola_Prato`, `Arena_Drago_*` (corpo,
  testa/portale, artigli/torri), `Arena_Pavimento`, `Arena_Palco`, `Arena_Altare`, `Isoletta_*`,
  ogni pezzo sotto 20.000 triangoli, 400.000 in tutto);
- `IsolaDraghi_Collision.fbx` (scatole/convessi semplici: pavimento, mura percorribili, palco,
  scale, arrivo, sentiero; NIENTE collisione sul prato: ci pensa il Terrain);
- `Markers.json`, `Materials.json` (nome -> materiale Roblox, colore), `anteprime/` (render da
  lontano 500 m, dal punto d'arrivo, dentro l'arena dal palco, da sotto l'isola), `LEGGIMI.md`.
- Controllo in Blender come per le uova (bordi aperti, facce degeneri, budget, scala in metri).

## In Studio (lo fa Claude dopo)
Caricamento con `tools/modelli`, poi `mapgen/IsolaDraghi.build()` (allargamento, Terrain del
prato dalle altezze di `Isola_Prato`, alberi, altare della forma di drago). Scrivi nel messaggio
finale cosa va verificato (proporzioni col personaggio, porte, scale, da lontano).
