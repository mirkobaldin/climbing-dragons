# Modelli 3D per arricchire la mappa (compito per Codex)

Scritto da Claude il 2026-10-13. Lavora come per il set alpino (`codex/alpine-assets-20261013`):
Blender 5.2, un `.fbx` per modello + `<Nome>_Collision.fbx` + `Markers.json` (luci, fuoco), metri
reali (1 m = 1 stud; il gioco scala), ingresso/lato frontale verso **+Z**, origine a terra al centro.
Si caricano con `tools/modelli` (vedi `tools/modelli/LEGGIMI.md`): nomi dei file **sotto i 50
caratteri**, texture PBR 1024 (BaseColor, Normal, Roughness), niente script.

**Da non fare** (Mirko li ha già bocciati o li ha suoi): attrezzi, zaino, forziere, nido, cristalli,
piccozze, torii sulle isole. Stile: realistico-stilizzato come le case di Codex (non low-poly a
blocchi), colori caldi, bordi smussati.

## Collisioni (importante)
Le scale vanno fatte come **rampa inclinata** nella collisione (`COL_Rampa...`), non come scatola
piena: le scatole `COL_Scala*` delle case erano muri (ora il gioco le sostituisce con un cuneo).
Porte e passaggi larghi almeno 1.4 m, soffitti almeno 2.6 m.

## Lista (in ordine di priorità)

| # | Nome file | Cosa | Misure (m) | Dove va |
|---|---|---|---|---|
| 1 | `PosatoioDrago` | Trespolo di legno e ferro per draghi adulti: tronco con rami tagliati, base di pietra, catena | 4 x 6 x 4 | recinto dei draghi dietro le case (8-10 per casa) |
| 2 | `MangiatoiaDrago` | Mangiatoia lunga di pietra con pesci/carne stilizzati e abbeveratoio | 5 x 1.2 x 1.6 | recinto dei draghi |
| 3 | `PonteTibetano` | Ponte sospeso di corde e assi, modulare (tratto da 6 m + 2 pali di testa) | 6 x 2 x 1.6 | fra i costoni degli Chalet e sulle gole |
| 4 | `BivaccoAlto` | Bivacco d'alta quota a botte in lamiera rossa (stile Gervasutti), 4 brande dentro | 5 x 3 x 3 | campi base sopra i 2000 m |
| 5 | `StatuaDrago_<Elemento>` | Statua di drago seduto su piedistallo, una per gli 8 elementi (Roccia, Gelo, Cosmico, Tempesta, Eclissi, Fulmine, Ossa, Gas) | 3 x 5 x 3 | ingresso dell'arena, nidi a tema, piazze dei borghi |
| 6 | `AltareDuello` | Altare del Duello dei draghi: blocco di basalto con rune, braciere rosso e due corna di drago | 3 x 4 x 3 | arena (oggi è fatto di Part) |
| 7 | `Giunca` + `Sampan` | Barca a vela cinese grande e barchetta coperta, ormeggiabili | 18 x 12 x 5 / 7 x 2.5 x 2 | porti: Lantern Bay, Fisher's Cove, Sunset Harbor |
| 8 | `MulinoAcqua` | Mulino con ruota (ruota separata come oggetto `Ruota` per farla girare) | 7 x 7 x 6 | cascate e torrenti dei borghi |
| 9 | `BandierePreghiera` | Filo di bandierine tibetane fra due pali (modulare, 8 m) | 8 x 4 x 0.2 | sentieri alti, campi base, passi |
| 10 | `Teleferica` | Pilone di ferro + cabina rossa (cavo lo fa il gioco con un Beam) | pilone 3 x 14 x 3, cabina 2.5 x 2.5 x 2.5 | dal campo base principale ai costoni (solo decorazione) |
| 11 | `FaroScogliera` | Faro di pietra con lanterna in cima (marcatore `FX_Light_Faro`) | 5 x 18 x 5 | scogliere sul mare, vicino ai porti |
| 12 | `FossiliDrago` | Set di 4 pezzi: teschio piccolo, vertebre a semicerchio, artiglio, ala ossea | 2-8 m | Dragon Graveyard, Wyrm's Rest, Bone Ridge |
| 13 | `PinoInnevato` (3 varianti) | Pino con neve sui rami, tronco separato (per le foglie trasparenti) | 4 x 9-14 x 4 | sopra i 600 m, dove oggi ci sono i ciliegi |
| 14 | `SantuarioVetta` | Piccolo santuario di pietra con campana e ometto di sassi | 4 x 4 x 4 | vetta e campi base alti (traguardo) |

## Verifiche richieste per ogni modello
- Render di anteprima davanti e dietro (`artifacts/<compito>/anteprime`).
- Triangoli sotto 15k (le statue sotto 25k), materiali al massimo 4 per modello.
- Collisione semplice: scatole e rampe, niente mesh dettagliate.
- Scrivi nel messaggio finale cosa va provato in Studio (scala, porte, rampe).
