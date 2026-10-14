# Compito per la sessione cloud di Claude: modelli 3D (versione 2)

Scritto da Claude (locale) il 2026-10-14, dopo il primo giro. Leggi prima `AGENTS.md`.

## 0. Com'e' andato il primo giro (da leggere)
Mirko ha bocciato l'arena del primo giro ("fa schifo"). Cosa non va, in pratica:
- era fatta di **primitive generate da codice** (cilindri, scatole, ossa procedurali): da vicino
  sembra "geometria di programmatore", non un modello da gioco;
- nessuna anteprima nel repo (l'upload LFS e' fallito), quindi nessuno l'ha potuta controllare;
- nessun confronto con riferimenti veri: la qualita' non e' stata misurata.

Questa volta valgono le regole qui sotto. **Un modello non e' finito finche' non passa il
controllo della sezione 3** (con le anteprime nel repo).

## 1. Ambiente e consegna
- Accesso a internet "Full" (Blender 5.2 per Linux da `download.blender.org`, `.tar.xz`).
- `git pull origin main` prima di iniziare (main e' andato avanti), lavora sul branch
  `cloud/modelli-20261014`, commit piccoli in italiano, alla fine `git rebase main`.
- **Niente Git LFS** (GitHub l'ha rifiutato): togli le regole LFS da `.gitattributes`. I file
  vanno nel git normale: ogni FBX sotto 40 MB (se e' piu' grande dividilo in pezzi), texture in
  PNG 1024 (o JPG di qualita' 90 per la BaseColor), anteprime in JPG 1280x720 sotto 400 KB.
- Non toccare `src/` (il gioco lo integra Claude in locale).
- Formato come prima: `cloud/<Nome>/<Nome>.fbx`, `<Nome>_Collision.fbx` (solo scatole e rampe
  `COL_*`), `Markers.json` (`FX_Light_*`, `FX_Fire_*`, `SPOT_*`), texture PBR (BaseColor,
  Normal, Roughness; max 4 materiali per mesh), metri reali, ingresso verso +Z, origine a terra.
  Ogni mesh sotto 20.000 triangoli e sotto 2048 m per lato.

## 2. Metodo (obbligatorio, in quest'ordine)
1. **Scheda del modello** (`cloud/<Nome>/SCHEDA.md`): a cosa serve nel gioco, misure rispetto al
   personaggio (alto 5 stud = circa 1,7 m: le porte 3 m, i gradini 0,3 m), 3-5 riferimenti reali
   descritti a parole (architettura, giochi, foto: cosa prendi da ognuno), palette di 5 colori.
2. **Sagoma** (blockout): solo forme grandi. Render da 4 lati e dall'alto, **alla distanza della
   camera del gioco** (15-40 m) e da lontano (200 m). Domanda: si capisce cos'e' dalla sola
   sagoma nera? Se no, rifai prima di andare avanti.
3. **Modellazione vera**, non primitive:
   - kit modulare (un tratto di muro, un arco, una colonna, un gradino, una torre) modellato
     bene una volta e ripetuto, con varianti (rotture, crepe, pietre mancanti);
   - bevel su tutti gli spigoli (0,03-0,1 m), niente facce piatte enormi: blocchi di pietra
     separati, assi di legno con venature, ferro con chiodi;
   - asimmetria e usura: niente sembra uscito da una fabbrica;
   - modificatori applicati prima dell'export.
4. **Modelli organici** (crani, statue, draghi, alberi, rocce scolpite): **non farli con le
   primitive**. Se nell'ambiente c'e' la variabile `MESHY_API_KEY`, usa l'API di Meshy
   (`https://api.meshy.ai`, text-to-3D o image-to-3D con texture PBR), poi in Blender: pulizia,
   decimate sotto il budget, UV, scala, origine. Se la chiave non c'e', scrivi per ognuno un
   prompt in `cloud/<Nome>/MESHY_PROMPT.md` (Mirko li genera a mano e li mette in `cloud/<Nome>/meshy/`)
   e lascia al loro posto un segnaposto con le misure giuste (`PLACEHOLDER_<cosa>`).
5. **Materiali**: PBR veri. Base dalle texture procedurali va bene, ma con **ambient occlusion
   e curvatura cotte** (bake): sporco nelle fessure, bordi consumati e piu' chiari, muschio o neve
   dove serve. Niente colore piatto.
6. **Controllo** (sezione 3), poi export.

## 3. Controllo di qualita' (scrivilo in `cloud/<Nome>/CONTROLLO.md`, con le immagini)
Render Eevee con luce del giorno e cielo, in `cloud/<Nome>/anteprime/`: davanti, 3/4, dietro,
dall'alto, un dettaglio da vicino, e uno **con una sagoma umana di 1,7 m** accanto per la scala.
Rispondi onestamente, voto da 1 a 5 per ognuna; sotto 4 si rifa' quella parte:
- [ ] la sagoma si legge da lontano ed e' interessante (non un cilindro/una scatola)
- [ ] da vicino ci sono dettagli veri (bevel, blocchi, rotture), non facce piatte
- [ ] i materiali hanno sporco, usura, variazione di colore
- [ ] le proporzioni sono giuste rispetto al personaggio (porte, gradini, parapetti)
- [ ] sembra un modello di un gioco Roblox di qualita' alta (stile "stilizzato-realistico",
      colori saturi ma non plastica), non un esercizio di programmazione
- [ ] budget: triangoli, materiali, misure, collisioni semplici
Confronta con 1-2 immagini di riferimento (descritte nella SCHEDA): cosa manca ancora?

## 4. PRIORITA' 1: l'Isola dei Draghi con l'arena (`cloud/IsolaDraghi/`)
Nuova idea di gioco (decisa con Mirko): l'arena non sta piu' sulla mappa. Dalla pedana del
campo ci si teletrasporta su **un'isola volante lontana**, dove il giocatore **diventa il suo
drago** (comanda il drago invece del personaggio) per addestramento e duelli. Serve:

**L'isola** (circa 400 x 400 m vista dall'alto, 160 m di spessore):
- sotto: roccia rovesciata a cono irregolare, con radici di pietra e stalattiti, cristalli di
  ghiaccio NO (Mirko non li vuole), qualche cascata che cade dal bordo (solo la roccia: l'acqua la
  fa il gioco con gli effetti; lascia `SPOT_Cascata1..n` sul bordo);
- sopra: prato e rocce, sentieri lastricati dal punto d'arrivo (`SPOT_Arrivo`, piattaforma
  circolare di pietra con un cerchio di rune, Ø 16 m) fino all'arena;
- attorno, 4-6 isolette piccole (40-80 m) con rovine e posatoi per i draghi (`SPOT_Posatoio*`).

**L'arena** (al centro dell'isola, aperta in alto: dentro volano i draghi):
- colosseo ottagonale, interno Ø 150 m, mura a gradoni alte 22 m, 8 torri da 40 m (una per
  elemento: Roccia, Gelo, Cosmico, Tempesta, Eclissi, Fulmine, Ossa, Gas; stendardo e braciere);
- stile: pietra scura vulcanica con rifiniture di bronzo e oro antico, archi a tutto sesto,
  contrafforti, statue di draghi accucciati sopra le torri (organiche: Meshy, vedi 2.4);
  riferimenti da descrivere nella scheda: Colosseo di Roma, arene di Elden Ring, Dragonsreach
  (Skyrim), cittadelle di Dragon's Dogma;
- **portale monumentale** con due teste di drago scolpite a fauci aperte (Meshy) e saracinesca;
- **palco del domatore** (`SPOT_Domatore`): balcone sul lato del portale, da dove il personaggio
  "guarda" mentre comanda il drago;
- pavimento di sabbia e lastre con un grande cerchio di rune (Ø 70 m) e 8 spicchi colorati;
- 8 anelli di ferro in cima alle mura per i draghi selvatici (`SPOT_Posatoio1..8`);
- altare del duello (basalto, rune rosse, due corna) vicino al portale, dentro (`SPOT_Altare`);
- pezzi separati: `Isola_Roccia_*`, `Isola_Prato`, `Arena_Mura_01..08`, `Arena_Torre_<Elemento>`,
  `Arena_Portale`, `Arena_Palco`, `Arena_Pavimento`, `Arena_Stendardo_<Elemento>`,
  `Arena_Statua_<Elemento>`, `Arena_Altare`, `Arrivo`.
- Budget: 400.000 triangoli in tutto, ogni pezzo sotto 20.000.

Puoi riusare parti buone del primo giro (`tools/blender/arena.py`, `cloud_lib.py`: misure, marker,
export), ma le forme vanno rifatte col metodo della sezione 2. I due draghi scheletrici avvolti
sulle mura vanno tolti.

## 5. PRIORITA' 2: modelli della mappa
Stesso metodo e stesso controllo, un modello alla volta, in quest'ordine (misure in metri):

| # | Nome | Cosa | Misure |
|---|---|---|---|
| 1 | `PosatoioDrago` | trespolo per draghi adulti: tronco nodoso con rami tagliati, base di pietra, catena | 4 x 6 x 4 |
| 2 | `MangiatoiaDrago` | mangiatoia di pietra con pesci e carne, abbeveratoio | 5 x 1,2 x 1,6 |
| 3 | `PonteTibetano` | ponte sospeso di corde e assi, modulare: tratto da 6 m + pali di testa | 6 x 2 x 1,6 |
| 4 | `BivaccoAlto` | bivacco a botte in lamiera rossa, 4 brande dentro | 5 x 3 x 3 |
| 5 | `StatuaDrago_<Elemento>` | statua di drago seduto su piedistallo, 8 elementi (Meshy) | 3 x 5 x 3 |
| 6 | `SantuarioVetta` | santuario di pietra con campana e ometto di sassi | 4 x 4 x 4 |
| 7 | `BandierePreghiera` | bandierine tibetane fra due pali, modulare | 8 x 4 x 0,2 |
| 8 | `PinoInnevato` (3 varianti) | pino con neve sui rami, tronco separato | 4 x 9-14 x 4 |
| 9 | `RocceSet` (6 pezzi) | massi e speroni di granito con neve sopra, per riempire i pendii | 2-12 m |
| 10 | `CarrelloMiniera` + `Binari` | carrello di legno e ferro, binari modulari (4 m, curva, salita) | 2 x 1,5 x 1,2 |
| 11 | `IngressoMiniera` | portale di travi di legno con lanterne, per le grotte | 6 x 5 x 3 |
| 12 | `Incubatrice` | nido-incubatrice di pietra calda con braci (per la casa) | 3 x 1,5 x 3 |
| 13 | `StallaDraghi` | stalla aperta per draghi adulti, tetto in legno, fieno | 14 x 9 x 10 |
| 14 | `BancarellaMercato` (3 varianti) | bancarelle con tende colorate, merci | 4 x 3 x 2,5 |
| 15 | `Teleferica` | pilone di ferro + cabina rossa | pilone 3 x 14 x 3 |
| 16 | `FaroScogliera` | faro di pietra con lanterna (`FX_Light_Faro`) | 5 x 18 x 5 |
| 17 | `FossiliDrago` | teschio, vertebre, artiglio, ala ossea (Meshy) | 2-8 m |
| 18 | `Giunca` + `Sampan` | barche cinesi ormeggiabili | 18 x 12 x 5 / 7 x 2,5 x 2 |

Da non fare (Mirko li ha bocciati o li ha suoi): attrezzi, zaino, forziere, nido, cristalli,
piccozze, torii sulle isole.

## 6. Quando hai finito ogni modello
- Aggiorna `cloud/LEGGIMI.md` (misure, triangoli, marcatori, voto del controllo).
- Commit con le anteprime: Mirko le guarda su GitHub prima che il modello entri nel gioco.
- Nel messaggio finale: cosa va provato in Studio e quali prompt Meshy servono.
