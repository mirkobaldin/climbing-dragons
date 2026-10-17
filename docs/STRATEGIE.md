# Strategie per far crescere il gioco (compiti)

Scritto il 17/10 dalla sessione cloud confrontando il gioco con la pagina di Roblox
"Strategie consigliate" (Hub Creatori > Inizia > Strategie consigliate, letta dal file salvato
da Mirko). Ogni compito dice CHI lo fa: **Codex** (codice e dati, senza Studio), **Claude**
(Claude Code in locale: va provato in Studio), **Mirko** (Creator Hub, Discord, decisioni).

Regola della pagina che conta piu' di tutte: **prima i numeri e i playtest, poi le funzioni
nuove**. Il gioco ha gia' tantissimo; quello che manca e' sapere cosa funziona.

## Cosa c'e' gia' (non rifarlo)
- Genere collaudato (sopravvivenza + draghi da collezionare + simulatore con rinascita).
- Telefono curato (scala unica, `docs/UI_ADATTAMENTO.md`), prestazioni (`client/Prestazioni`).
- Sistemi espandibili: missioni, taglie, sfida del giorno, eventi del mondo, collezione di draghi.
- Obiettivi a breve/medio/lungo termine, segreti (grotte, shiny), momenti "wow" (schiusa 3D).
- Amico degli streamer: HIDE HUD, clip TikTok (`docs/CLIP_NUOVE.md`).
- Filtro dei nomi dei draghi (`TextService:FilterStringAsync`), difese dei remote (`server/Guardia`).

## Decisioni gia' prese (17/10)
- **Niente drago regalato al primo accesso** (FATTO nel branch `cloud/ui-rifinitura-20261017`:
  `DragonConfig.STARTER_DRAGON = nil`, `server/Dragons.load`). Il primo drago nasce dall'uovo del
  tutorial; l'Eclissi resta il drago della vetta. Chi l'aveva gia' lo tiene.
  Da verificare in Studio (Claude), con un profilo nuovo (`nosave` + DataStore vuoto in Studio):
  HUD senza drago (riquadro del drago nascosto, missione sotto il giocatore), niente tasto Roar/Z,
  nessun errore nell'Output finche' non schiudi l'uovo, Travel "Dragon Island" che compare solo
  dopo il primo drago, nessun nemico del tutorial che richieda il drago.
- **La Tenda resta nel tutorial**: senza Tenda non c'e' il nido e l'uovo non si schiude.

---

## 1. KPI e dati (PRIORITA' 1)
Oggi nel codice non c'e' nessun `AnalyticsService`: non sappiamo dove i giocatori smettono.

**Obiettivi da scrivere qui e da controllare ogni settimana** (Mirko li puo' cambiare):
| KPI | Cos'e' | Obiettivo iniziale |
|---|---|---|
| D1 | tornano il giorno dopo | >= 20% |
| D7 / D30 | tornano dopo 7 / 30 giorni | >= 6% / >= 2% |
| Tempo di gioco | sessioni al giorno x durata | sessione >= 15 min |
| Conversione | % di giocatori che spende Robux | >= 1% |
| ARPPU | Robux medi per chi paga | da misurare |
| Fine tutorial | % che arriva al passo 9 | >= 60% |

**Compito A1 (Codex) — `server/Analisi.luau` (nuovo)**, una sola porta per tutti gli eventi:
- `Analisi.tutorial(player, passo, nome)` -> `AnalyticsService:LogOnboardingFunnelStepEvent`
  (chiamato da `server/Tutorial` a ogni passo completato, 1..9, nomi corti in inglese:
  "ReachWall", "ClimbWall", "Piton", "Mine", "Sell", "Egg", "Tent", "Nest", "Hatch").
- `Analisi.funnel(player, nome, passo, nomePasso)` -> `LogFunnelStepEvent` per le missioni dopo il
  tutorial (`server/Missions`).
- `Analisi.economia(player, entraEsce, valuta, quanto, saldo, tipo, oggetto)` ->
  `LogEconomyEvent`: monete guadagnate (minerali venduti, taglie, vette, fattoria) e spese
  (shop, case, potenziamenti, crafting). Valute: "Coins", "Stones".
- `Analisi.progressione(player, ...)` -> `LogProgressionEvent`: prima vetta, quota massima a
  scaglioni (500, 1000, 2000 m), livelli del drago, evoluzioni, rinascite.
- `Analisi.evento(player, nome, valore)` -> `LogCustomEvent`: morti per causa (da
  `server/Survival`), uova schiuse per rarita', apertura delle pagine del menu (c'e' gia'
  `Remotes.MenuOpened`).
- Tutto in `pcall` (in Studio i servizi possono non rispondere), nessun dato personale.
**Compito A2 (Claude)**: provare in Play che gli eventi partono senza errori; dopo la
pubblicazione controllare nel Creator Dashboard (Analytics > Funnel/Economy) che arrivino.
**Compito A3 (Mirko)**: ogni lunedi' guardare i numeri e scrivere qui sotto una riga
("17/10: D1 ?%, fine tutorial ?%").

## 2. MVP e playtest (PRIORITA' 2)
La pagina: metti il gioco in mano ai giocatori presto, piccoli test prima, poi pubblico.
- **P1 (Mirko)**: playtest con un gruppo piccolo (accesso solo a utenti scelti: 5-10 ragazzi,
  meta' sul telefono). Guardarli giocare senza aiutarli: dove si bloccano? Si divertono?
- **P2 (Mirko)**: test pubblico di un fine settimana, poi si toglie: servono i primi D1 e la
  durata delle sessioni (con A1 gia' attivo).
- **P3 (Mirko)**: beta aperta con "[BETA]" nel titolo.
- **P4 (tutti)**: durante i test **niente funzioni nuove**, solo correzioni e i primi 10 minuti.

## 3. Arrivare subito al divertimento (tutorial)
La pagina: tutorial corto, nel contesto, interattivo. Oggi 9 passi:
1 vai alla parete, 2 scala, 3 chiodo, 4 mina il cristallo, 5 **vendi i minerali**, 6 prendi
l'uovo, 7 **compra la Tenda**, 8 metti l'uovo nel nido, 9 schiudi.
La Tenda resta (serve il nido). Il passo 5 esiste solo perche' si parte con 60 monete e la
Tenda ne costa 100.
- **T1 (Codex)**: togliere il passo "SELL YOUR ORES" dal percorso obbligato:
  `EconomyConfig.START_COINS` da 60 a 110 (la Tenda e' pagabile subito) e il passo 5 diventa un
  passo che si completa da solo (vincolo: i passi devono restare 9, `TutorialStep` e' nei
  salvataggi e 10 = finito; vedi il commento in `server/Tutorial`). La vendita dei minerali diventa
  la prima missione dopo il tutorial (`server/Missions`).
- **T2 (Codex)**: unire 1 e 2 nel testo ("CLIMB THE WALL" con la freccia dalla partenza), stesso
  vincolo dei 9 passi (il passo 1 si completa appena arrivi, senza riquadro a parte).
- **T3 (Claude)**: misurare con A1 quanto dura il tutorial (obiettivo: drago schiuso in meno di
  8 minuti) e provarlo sul telefono simulato.
- Ora che non c'e' il drago regalato, **la schiusa e' il momento "wow"** del primo giorno: deve
  arrivare presto (vedi T3) e la schermata `client/EggHatch` deve restare bella.

## 4. Gioco con gli amici (il buco piu' grosso)
La pagina: su Roblox si gioca in gruppo; progetta il gioco per i gruppi e fai incontrare i
giocatori (mappa enorme = giocatori sparsi). Oggi nel server non c'e' niente di cooperativo.
- **S1 (Codex)**: inviti agli amici: pulsante "INVITE FRIENDS" nel menu (pagina Profile) con
  `SocialService:PromptGameInvite` (controllo `CanSendGameInviteAsync`), premio una tantum quando
  un amico invitato entra (es. 1 uovo raro, se Roblox lo consente: niente premi per il solo invito).
- **S2 (Codex + Claude)**: **cordata**: due giocatori vicini alla parete possono legarsi (prompt
  "Rope up with <nome>"); legati, il chiodo di uno ferma la caduta dell'altro e la stamina si
  ricarica un po' piu' in fretta. E' il sistema sociale piu' adatto a un gioco d'arrampicata.
  Claude lo prova in Studio con due giocatori (Test > Server e 2 client).
- **S3 (Codex)**: taglie di gruppo nella sfida del giorno ("Reach the summit with a friend":
  bonus se due giocatori della stessa cordata/amici arrivano in vetta entro 2 minuti).
- **S4 (Claude, mappa)**: il campo base e i campi intermedi come punti d'incontro: classifiche
  (vedi S5), commercianti, falo' dove ci si siede, posto dove i draghi degli altri si vedono.
- **S5 (Codex)**: classifiche globali (OrderedDataStore, aggiornate ogni pochi minuti): quota
  massima, vette, draghi posseduti, discesa piu' veloce (c'e' gia'). Tabellone nel campo base
  e pagina nel menu.

## 5. Tenere i giocatori (ritorno giornaliero)
- **R1 (Codex)**: premio di accesso giornaliero con serie di giorni (giorno 1 monete ... giorno
  7 uovo raro), salvato in Progression, mostrato all'ingresso (stile UiKit).
- **R2 (Codex)**: notifiche fuori dal gioco (`ExperienceNotificationService`, il giocatore deve
  accettarle): "Your egg is ready to hatch", "Your daily reward is waiting". Testi da creare nel
  Creator Hub (Mirko).
- **R3 (Codex)**: badge (`BadgeService`, Mirko li crea nel Creator Hub e mette gli ID in un
  config): prima vetta, primo drago, primo shiny, 1000 m, prima rinascita, tutti gli 8 elementi.

## 6. Monetizzazione F2P
La pagina: piu' livelli di prezzo, pacchetto iniziale, acquisti RIPETIBILI, negozio chiaro.
Oggi si vendono solo pass (una volta sola); i Developer Product sono tutti a 0.
- **M1 (Mirko)**: creare nel Creator Hub i Developer Product gia' pronti nel codice
  (`ShopConfig.DEV_PRODUCTS`: Revive, InstantHatch, Coins1000, TrainingBoost) e metterne gli ID.
- **M2 (Codex)**: **pacchetto iniziale** (una volta sola, prezzo basso, es. 99 Robux): uovo
  raro + 500 monete + 10 chiodi; mostrato dopo la prima schiusa e nello Shop finche' non comprato.
- **M3 (Codex)**: piu' tagli di monete (Coins1000, Coins5000, Coins15000) e consumabili:
  schiusa istantanea, Revive sulla schermata di morte (c'e' gia'), potenziamento XP a tempo.
- **M4 (Codex) — obbligo di Roblox**: le monete comprate con Robux possono comprare la Mystery Egg
  (casuale). Probabilita' gia' scritte; in piu' controllare
  `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` e, se vero,
  non vendere le uova casuali (o non vendere monete) a quel giocatore.
- **M5 (dopo i primi dati)**: pass stagionale (la pagina lo cita; GameAnalytics consiglia di
  aspettare sessioni di 13-18 minuti).

## 7. Comunita' e feedback
- **C1 (Mirko)**: server Discord collegato al gioco (Social Links nel Creator Hub), con
  moderazione e i canali consigliati: #rules/#faq, #announcements, #general, #bugs,
  #suggestions, #creative.
- **C2 (Codex)**: pulsante "COMMUNITY" nel menu che mostra il link (Roblox lo permette solo
  tramite i Social Links della pagina del gioco: testo che dice dove trovarlo).
- **C3 (Mirko)**: entrare nel gioco durante i test e guardare cosa fanno e cosa scrivono in chat.

## 8. Contenuti e aggiornamenti
- **U1 (Mirko + Claude)**: roadmap a 6-12 mesi in fondo a questo file. Ritmo consigliato:
  piccoli aggiornamenti ogni 1-2 settimane, sistemi grandi ogni 2-3 mesi.
- **U2 (Codex)**: riquadro "WHAT'S NEW" all'ingresso dopo un aggiornamento (testo in un config
  con la versione, si vede una volta).
- **U3 (Mirko)**: usare gli eventi di Roblox (pagina del gioco: i giocatori si iscrivono e
  ricevono la notifica) per ogni aggiornamento ed evento.
- **U4 (Codex)**: premi a tempo limitato visibili agli altri (aura o cornice del drago
  dell'evento, titolo sopra la testa): "come l'hai avuto?!" fa parlare del gioco.

## 9. Presentazione e crescita
- **G1 (Mirko)**: icona, 3-5 miniature e descrizione curate; provarne piu' versioni con le
  funzioni del Creator Dashboard e tenere quella che fa piu' clic e piu' D1.
- **G2 (Mirko)**: TikTok: clip gia' pronte (clip21-clip25); annunci mirati di TikTok dopo i test.
- **G3 (Mirko, dopo)**: annunci sponsorizzati di Roblox con Robux GUADAGNATI (quelli comprati
  rendono meno), solo quando il D1 e' buono: portano giocatori, ma il gioco deve tenerli.

---

## Ordine consigliato
1. A1 (dati) + T1/T2 (tutorial piu' corto) — Codex, poi prova di Claude.
2. P1 (playtest piccolo) — Mirko.
3. S1 (inviti) + R1 (premio giornaliero) + R3 (badge) — Codex.
4. M1-M4 (monetizzazione ripetibile e regole) — Mirko + Codex.
5. S2 (cordata) + S5 (classifiche) — Codex + Claude.
6. P2 (test pubblico) e poi il resto, guidati dai numeri.

## Numeri settimanali
(una riga a settimana, A3)

## Roadmap
(da scrivere, U1)
