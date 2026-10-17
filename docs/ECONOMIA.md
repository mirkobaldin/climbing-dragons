# Economia: dove vanno le monete e cosa vendere a Robux

Scritto il 17/10 (sessione cloud). Mirko: "le monete servono solo per la casa e le cose del
negozio, ma quello che guadagni è molto più alto di quello che hai da spendere". Poi: "pensa a
diversi developer product da mettere, tipo Blox Fruits (compri soldi, drop dei boss x2...)".

## Il problema
Entrate (per ora senza misure vere, vanno prese dai dati del playtest):
- draghi posati a casa: fino a 20 monete/min x stadio per un leggendario adulto, anche offline;
- montepremi fino a 50.000, sfida del giorno 800-1.500, taglie, minerali, eventi;
- regali del tempo di gioco (~1.100 a partita), +15% monete a ogni rinascita.

Uscite prima di oggi: le case (in tutto 39.600), i potenziamenti (al massimo 5.000 a livello),
le uova del negozio (300 e 1.200) e le cose piccole (chiodi, medkit, thermos). Quasi tutto si
compra **una volta**: dopo qualche giorno le monete si accumulano e non servono più. Un gioco
tiene i giocatori quando le monete hanno sempre un uso: cose che si ricomprano, che crescono di
prezzo o che si mostrano agli altri.

## Fatto oggi (nel branch `cloud/ui-rifinitura-20261017`)
| Cosa | Prezzo | Perché funziona |
|---|---|---|
| **Dragon Feast** (negozio) | 600 | un terzo di livello a ogni drago al seguito: serve a ogni livello, si ricompra sempre |
| **Evolution Stone** (negozio) | 7.500 | le pietre adesso arrivano solo dal Duello: chi ha monete può evolvere prima |
| **Rinascita che costa sempre di più** | 2.500 x 1,6^n | prima era fissa a 2.500: con +15% di monete per rinascita costava sempre meno |

I prezzi stanno in `shared/ShopConfig.luau` e `UpgradeConfig.REBIRTH`. Le icone sono provvisorie
(drago, uovo, cristallo) finché Codex non fa quelle vere.

## Altre idee per spendere monete (da scegliere)
In ordine di quanto rendono rispetto al lavoro che chiedono.
1. **Aspetto dei draghi** (aura, scia in volo, colore degli occhi, corona): 10.000-250.000.
   È la spesa che dura di più perché si fa vedere agli altri. Gli effetti ci sono già
   (`client/VFXKit`, `MeshFX`).
2. **Potenziamenti dal 6 al 10** con costi che crescono in fretta (x2 a livello): continuano
   la progressione di chi ha già tutto al 5.
3. **Allenatore dei draghi**: con 15.000 si rilancia una statistica del drago (attacco o
   critico). Tiene vive le monete dei giocatori forti.
4. **Bagno d'oro**: 25.000 per avere il 10% di rendere shiny un drago. È una scommessa con le
   monete del gioco, non coi Robux, quindi va bene.
5. **Posti nel nido e nel recinto** comprati con monete (20.000, 60.000) oltre a quelli del pass.
6. **Arredamento della casa** e trofei (teste dei boss, uova d'oro): va col sistema delle case.
7. **Rinnovo delle taglie** (500) e **nome del drago** (5.000): spese piccole.

## Prodotti da vendere a Robux (stile Blox Fruits)
I prodotti si comprano più volte, i pass una volta sola.
Da creare nel Creator Hub (Monetization) e mettere gli ID in `ShopConfig.DEV_PRODUCTS` o
`DragonConfig.GAMEPASSES`.

### Prodotti (si ricomprano)
| Prodotto | Robux | Note |
|---|---|---|
| Pacchetti di monete 2.500 / 12.000 / 50.000 / 200.000 | 49 / 199 / 699 / 1.999 | il pacco grande conviene di più (+20%); scalare con le rinascite come i regali |
| Evolution Stone x1 / x3 | 79 / 199 | si lega al Duello e allo shop a monete |
| **Gold Rain** | 199 | per **tutto il server**: pioggia di monete per 60 s attorno a chi lo compra, col suo nome in alto. Fa entrare gli amici, molto usato nei simulatori |
| **Call the Wild Dragon** | 149 | fa partire subito l'evento del drago selvatico (`WorldEvents`) per tutti: chi lo compra prende il drop x2 |
| Egg Radar (15 min) | 49 | tutte le uova della mappa nella bussola (versione a tempo dell'Egg Finder) |
| Mountain Rescue / Instant Hatch / Training Boost | 25 / 49 / 39 | ci sono già nel codice (ID da creare) |

### Pass (una volta sola)
| Pass | Robux | Note |
|---|---|---|
| **2x Boss Drops** | 499 | come Blox Fruits: drop dei capi e dei draghi volanti raddoppiati (`server/Drops`, `Drops.BOSS`) |
| **2x Coins** | 399 | moltiplica come le rinascite (`UpgradeConfig.coinMult`) |
| **VIP** | 299 | nome dorato in chat, +10% monete, posatoio VIP sull'Isola dei Draghi, regali del tempo di gioco più ricchi |
| **Fast Travel** | 349 | teletrasporto da qualunque posto (non solo dai punti di viaggio) |
| **Extra Dragon / Big Nest / Fast Incubation / Egg Finder / Training x2** | — | ci sono già |
| **Royal Wings** | 199 | solo aspetto: vela del parapendio d'oro con la scia |

Regole di Roblox da rispettare:
- ogni cosa a caso pagata con Robux deve mostrare le probabilità, come già fanno le uova del
  negozio;
- niente premi a caso dentro i pacchetti a Robux, per non avere problemi nei paesi con le leggi
  sulle loot box: i prodotti sopra danno sempre la stessa cosa.

### Cosa mettere per il lancio (21 novembre)
1. 2x Coins e 2x Boss Drops: sono i pass più venduti nei giochi di questo tipo.
2. Pacchetti di monete e Gold Rain: Gold Rain fa anche pubblicità, perché lo vedono tutti.
3. VIP.
4. Il resto dopo, guardando i dati: dove si fermano i giocatori e cosa cercano nel negozio.

## Da misurare nel playtest
Monete guadagnate all'ora (al primo giorno e dopo una settimana), quando si compra la Baita e lo
Chalet, quante monete ha chi esce dal gioco. Se le monete crescono senza uso, alzare i prezzi
delle cose che si ricomprano o aggiungere le idee 1-3.

## Aggiornamento del 17/10 sera: negozio a Robux fatto
Mirko: "Mystery Egg, Rare Egg e la velocità di schiusa non si comprano con le monete: sono
prodotti a Robux che si ricomprano, non pass". E come riferimento la pagina dei pacchetti di un
simulatore (Starter Pack una volta sola, poi Value Packs con monete e pozioni).
- Pagina **Robux** del negozio (`client/RobuxShop`), dall'alto: Starter Pack, Value Packs
  (Hatcher, Hunter, Dragon Rider), uova Mystery/Rare/Epic con le probabilità, quattro pozioni,
  quattro pacchetti di monete, aiuti (Nest Warmer, Instant Hatch, Mountain Rescue, Training
  Boost) e pass.
- Pozioni da 15 minuti (`shared/Items`), che si sommano se ne bevi più di una: x2 monete,
  fortuna della schiusa (30% che l'uovo salga di rarità), shiny x3, x2 drop. Vanno nello zaino e
  nella barra 1-5, e quelle attive si vedono sotto il meteo (`client/BoostBar`).
- Lo Starter Pack si compra una volta sola (attributo `Comprato_StarterPack`, salvato).
- Le uova comprate entrano nel nido anche se è pieno.
- Ogni acquisto si consegna una volta sola: `PurchaseId` salvato nel DataStore `AcquistiRobux`.
- **Da fare in Creator Hub**: creare i developer product con i nomi e i prezzi di
  `ShopConfig.DEV_PRODUCTS` / `ROBUX_PRICES` e mettere gli ID. Finché un ID è 0, la carta mostra
  COMING SOON.
