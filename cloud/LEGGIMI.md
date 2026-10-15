# Modelli della sessione cloud (giro 2, 2026-10-14) — per Claude locale

Compito: `docs/CLOUD_SESSIONE.md` (v2). Tutto e' rifatto da script Blender 5.2 ed e' **nel git
normale** (niente LFS): FBX, collisioni, marcatori, texture e anteprime JPG. Mirko ha chiesto che
**sia Claude locale a caricarli in Studio e a montare la mappa dell'Isola dei Draghi**.

I due draghi scheletrici della prima arena sono tolti (il vecchio `tools/blender/arena.py` resta
solo come storia; la cartella `cloud/ArenaDraghi` non c'e' piu').

## Cosa c'e'
| Modello | Misure (m) | Triangoli | Marcatori | Voti |
|---|---|---|---|---|
| `IsolaDraghi` | 708 x 612 x 270 | 369158 | SPOT_Posatoio2, SPOT_Posatoio3, SPOT_Posatoio4, SPOT_Posatoio5, SPOT_Posatoio6, SPOT_Posatoio7 ... | 4/4/4/4/3/4 |
| `PosatoioDrago` | 4 x 6 x 4 | 6436 | SPOT_Posatoio | 4/4/4/4/4/5 |
| `MangiatoiaDrago` | 5 x 1,2 x 1,6 | 5672 | FX_Light_Acqua, SPOT_Cibo, SPOT_Acqua | 3/4/4/4/4/5 |
| `PonteTibetano` | tratto 6 x 2 x 1,6 (lungo Y), testata 3,2 x 3,2 x 2,7 | 8342 | SPOT_Inizio, SPOT_Fine | 4/4/4/5/4/5 |
| `BivaccoAlto` | 5 x 3 x 3 (lungo Y; porta verso -Y) | 14416 | FX_Light_Bivacco, SPOT_Porta | 5/4/4/5/4/5 |
| `StatuaDrago` | 3 x 5 x 3 con la statua (piedistallo 2,9 x 1,5 x 2,9) | 928 | SPOT_Statua | 3/4/4/4/3/5 |
| `SantuarioVetta` | 4 x 4 x 4 | 5032 | FX_Light_Candela, SPOT_Campana | 4/4/4/4/4/5 |
| `BandierePreghiera` | 8 x 4 x 0,2 | 2718 | SPOT_Bandiere | 4/4/4/5/4/5 |
| `PinoInnevato` | 4 x 9 / 11,5 / 14 x 4 | 17424 | SPOT_Pino1, SPOT_Pino2, SPOT_Pino3 | 4/4/4/5/4/5 |
| `RocceSet` | 2 / 3 / 4,5 / 6 (lastra) / 12 (sperone) / 8 (sporgenza) | 16328 | SPOT_Roccia1, SPOT_Roccia2, SPOT_Roccia3, SPOT_Roccia4, SPOT_Roccia5, SPOT_Roccia6 | 4/4/4/5/4/5 |
| `CarrelloMiniera` | carrello 2 x 1,5 x 1,2; binari 4 m (dritto), curva r 8 m 30 gradi, salita 4 m +0,5 m; scartamento 0,9 | 7624 | SPOT_BinariDritto_Inizio, SPOT_BinariDritto_Fine, SPOT_BinariCurva_Inizio, SPOT_BinariCurva_Fine, SPOT_BinariSalita_Inizio, SPOT_BinariSalita_Fine | 4/4/4/5/4/5 |
| `IngressoMiniera` | 6 x 5 x 3 | 7504 | FX_Light_Lanterna1, FX_Light_Lanterna2, SPOT_Galleria | 4/4/4/4/4/5 |
| `Incubatrice` | 3 x 1,5 x 3 | 4140 | SPOT_Uovo, FX_Fire_Incubatrice, FX_Light_Incubatrice | 4/4/4/4/4/5 |
| `StallaDraghi` | 14 x 9 x 10 (aperta verso -Y) | 16968 | FX_Light_Stalla1, FX_Light_Stalla2, SPOT_Drago | 4/4/4/5/4/5 |
| `BancarellaMercato` | 4 x 3 x 2,5 ciascuna | 12860 | FX_Light_Bancarella1_1, FX_Light_Bancarella1_2, SPOT_Bancarella1, FX_Light_Bancarella2_1, FX_Light_Bancarella2_2, SPOT_Bancarella2 ... | 4/4/4/5/4/5 |
| `Teleferica` | pilone 3 x 14 x 3, cabina 2 x 2,3 x 2,4, funi lunghe 50 m (lungo Y) | 2972 | SPOT_Cabina | 5/4/4/5/4/5 |
| `FaroScogliera` | 5 x 18 x 5 | 9026 | FX_Light_Faro, SPOT_Porta | 5/4/4/5/4/5 |
| `FossiliDrago` | lastra 9 x 1,6 x 6; fossili da Meshy (vedi MESHY_PROMPT.md) | 2592 | SPOT_Fossile_Teschio, SPOT_Fossile_Vertebre, SPOT_Fossile_Artiglio, SPOT_Fossile_Ala | 3/3/4/4/3/5 |
| `Giunca` | giunca 18 x 12 x 5 (lunga X, prua +X); sampan 7 x 2,5 x 2 a +Y | 7434 | FX_Light_Giunca1, FX_Light_Giunca2, SPOT_Ormeggio_Giunca, SPOT_Ormeggio_Sampan | 5/4/4/5/4/5 |

Voti (1-5): sagoma / dettagli / materiali / proporzioni / qualita' / budget. Ogni cartella ha
`CONTROLLO.md` con le anteprime (davanti, 3/4, dietro, alto, dettaglio, con il manichino di 1,7 m).

Ogni cartella `cloud/<Nome>/`:
- `<Nome>.fbx` (metri, Blender Z su; il davanti guarda +Z di Roblox), `<Nome>_Collision.fbx` (solo
  scatole `COL_*`, anche inclinate per rampe), `Markers.json` (posizioni in assi Roblox, metri),
  `Materials.json`, `info.json` (triangoli per pezzo, ingombro), `Textures/` (texture **cotte**:
  BaseColor JPG, Normal e Roughness PNG 1024 o 512), `anteprime/`, `CONTROLLO.md`, a volte
  `SCHEDA.md` e `MESHY_PROMPT.md`.
- Le texture **ripetute** (pietra, prato, legno, bronzo, corda...) sono una volta sola in
  `cloud/_Texture/` e `Materials.json` le indica come `../_Texture/<Materiale>_*.png`.
- Materiali senza texture (`MAT_*`): `MAT_Ember` braci/rune (Neon arancio), `MAT_WarmLight`
  lanterne (Neon), `MAT_Glass` vetri, `MAT_Gold`, `MAT_Water` (acqua della mangiatoia).
- `PLACEHOLDER_*`: pezzi organici da fare con Meshy (scatole con le misure giuste). Prompt in
  `MESHY_PROMPT.md` di IsolaDraghi (teste del portale, 8 statue sulle torri, corna dell'altare),
  StatuaDrago (8 statue sedute), FossiliDrago (teschio, vertebre, artiglio, ala), PosatoioDrago
  (tronco, facoltativo).

## Caricarli in Studio (stessa strada delle case di Codex, `tools/modelli/LEGGIMI.md`)
1. JSON per ogni modello (Blender 5.2):
   `blender -b --factory-startup --python tools/modelli/esporta_modelli.py -- cloud/<Nome> <cartella json>/<Nome>`
2. `CLOUD_MODELS=IsolaDraghi,PosatoioDrago,... node tools/modelli/prepara.js <repo> <cartella json>`
   (ora capisce i modelli in `cloud/`, i percorsi di `Materials.json`, `../_Texture` e la BaseColor `.jpg`).
3. `node tools/modelli/serve.js <repo> <cartella json>`, upload delle texture (MCP `upload_image`),
   `matids.json`, poi `carica_modelli.luau` (`require(m)("IsolaDraghi", 1, 20)` a gruppi: l'isola
   ha 119 pezzi). Il modello finisce in `ServerStorage.CaseCodex.<Nome>` in metri.
4. **Scala**: i modelli sono in metri veri e il personaggio e' 1,7 m = 5 stud, quindi
   `model:ScaleTo(2.94)` (5 / 1,7). L'isola diventa circa 2080 x 1800 stud (ogni pezzo resta sotto
   i 2048 stud per lato: il piu' grande e' `Isola_Prato`, circa 1350).
5. Luci e fuochi: ai marcatori `FX_Light_*` (PointLight) e `FX_Fire_*` (Fire o le emitter di
   `VFXLib`). Spawn e punti di gioco: `SPOT_*`.

## Isola dei Draghi: come montarla
- Origine = centro del pavimento dell'arena, a terra. Portale e arrivo verso +Z di Roblox.
- `SPOT_Arrivo` (piattaforma con le rune, 65 m davanti al portale): dove arriva il teletrasporto dal
  campo base. Sentiero lastricato fino al portale, 4 pilastrini con le braci.
- Arena: 8 lati (`Arena_Mura_01..08`, il lato 01 e' quello del portale), 8 torri
  (`Arena_Torre_<Elemento>`, dal portale in senso antiorario visto dall'alto: Roccia, Gelo,
  Cosmico, Tempesta, Eclissi, Fulmine, Ossa, Gas) con stendardo (`Arena_Stendardo_<Elemento>`, da
  far ondeggiare), braciere (`FX_Fire_<Elemento>`), segnaposto della statua (`SPOT_Statua_<El>`).
- `SPOT_Domatore`: palco del domatore (balcone coperto sopra l'arco, lato interno); porte di legno
  nei piloni. `SPOT_Altare`: altare del duello (basalto, drappo rosso, rune rosse Neon).
- `SPOT_Posatoio1..8`: anelli di bronzo dove si posano i draghi selvatici (1 sopra il portale).
- 5 isolette (`Isoletta_1..5`) con rovine e `SPOT_PosatoioIsola1..5`; `SPOT_Cascata1..4` sul bordo
  (l'acqua la fa il gioco).
- Collisioni: pavimento, mura, camminamenti, rampe sui gradoni, torri, piloni, palco, altare,
  sentiero, arrivo, piano centrale dell'isola (300 x 300 m). **Le colline del prato verso il bordo
  non hanno scatole**: per camminarci dare a `Isola_Prato` CollisionFidelity = PreciseConvexDecomposition
  (o Default) oppure coprirle col Terrain.
- Triangoli: 369.158 senza i pezzi Meshy (lasciano ~40.000 per statue, teste e corna).

## Cosa provare in Studio
1. Scala 2,94: il manichino del giocatore deve passare dalle porte del palco (1,6 x 3 m) e i gradini
   del sentiero e della scalinata centrale (0,3 m) devono essere a misura.
2. L'Isola intera: frame time con tutta l'isola visibile (StreamingEnabled aiuta); se pesa, le
   isolette e la roccia sotto si possono mettere con RenderFidelity Automatic.
3. Texture cotte: alcune parti dei muri usano la stessa texture (lati uguali); controllare che le
   UV siano giuste dopo l'import (nessun pezzo nero o stirato).
4. Normali morbide sugli smussi (modificatore WeightedNormal esportato nell'FBX): se in Studio i
   blocchi sembrano "gonfi", reimportare con le normali dell'FBX.

## Rifare i modelli
```
blender -b --factory-startup --python tools/blender/isola.py -- --fase modello --render
blender -b --factory-startup --python tools/blender/mappa.py -- --modello <Nome> --render
python3 tools/blender/controllo.py      # CONTROLLO.md e la tabella qui sopra
```
Script: `cloud_lib.py` (texture procedurali, export), `kit_pietra.py` (conci, archi, colonne,
cornici, merli, lastricati), `organico.py` (tronchi, rocce fratturate, scafi), `cottura.py`
(texture cotte: tinta per blocco, ombra nelle fessure, spigoli consumati, sporco, muschio, colori
vivi), `anteprime.py`.
