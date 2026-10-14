# Animazioni procedurali dei draghi

Scritto dalla sessione cloud il 2026-10-14 (branch `cloud/modelli-20261014`). Mirko voleva draghi
che si muovono "da gioco tripla A": zampe che spingono e poggiano sul terreno, virate col
corpo, collo e coda con inerzia, chi monta seduto alla base del collo.

## Cosa c'e'
| File | Cosa fa |
|---|---|
| `src/shared/DragonSkeleton.luau` (nuovo) | riconosce lo scheletro dalla **forma** (bacino, colonna, petto, collo, **testa con mascella, muso e corna separati**, coda, 4 zampe con il piede, ali con braccio e dita) |
| `src/shared/DragonGait.luau` (nuovo) | IK FABRIK, pianificatore dei passi (piedi fermi mentre appoggiati, passo ad arco, mai due zampe dello stesso lato ne' le due davanti/dietro insieme, passo d'emergenza se un piede esce di portata), molle |
| `src/client/DragonProcedural.luau` (nuovo) | lavora sulle ossa vere dopo `KfsPlayer`: corpo sul terreno, zampe, inerzia di collo e coda, sguardo, mascella, ali in virata, sella |
| `src/client/KfsPlayer.luau` | **+ `setPost(model, fn)`**: chiama una funzione dopo aver scritto le pose del frame (8 righe) |
| `src/client/PetAnimator.luau` | **+ 12 righe**: `attach` quando il drago ha le animazioni KfsPlayer, `setAir`, `setLegs` (seduto/dorme), `setLook` (guarda il padrone da fermo), sella in monta (`seatShift`), slancio al decollo (`impulse`) |
| `tools/studio/scheletri_compatti.luau` | stampa gli scheletri nell'Output (da cui sono venuti i dati di prova) |
| `tools/anim_test/` | prove fuori da Roblox con il Luau da riga di comando (vedi sotto) |

Il riconoscimento corregge un errore di `MapGen.AnimDraghi.analizza`: in Gas giovane, Roccia adulto
ed Eclissi adulto il "collo" finiva in un **corno** (la testa ruotava il corno). Ora la testa e'
l'osso dove il collo si divide; la mascella si distingue solo se in avanti ci sono almeno due rami
(Roccia ed Eclissi adulti; negli altri la bocca non si puo' aprire da sola).

## Come funziona, in breve
- **Corpo**: altezza, beccheggio e rollio vengono dai piedi (davanti/dietro, destra/sinistra);
  si abbassa dal lato della zampa in aria; in curva si piega verso l'interno; in accelerazione il
  petto si alza (spinta delle zampe dietro), in frenata scende; `impulse("decollo")` lo carica in
  giu' e poi spinge, `"atterraggio"` assorbe, `"colpito"` da' uno scatto.
- **Zampe** (solo a terra e entro ~180 studs dalla camera): ogni piede resta fermo nel mondo
  finche' e' appoggiato; quando la sua "casa" (dove starebbe a riposo, un po' piu' avanti se il drago
  si muove, ruotata con la virata) e' troppo lontana fa un passo ad arco; la durata del passo
  dipende dalla lunghezza della zampa e dalla velocita'. In curva le zampe esterne fanno passi
  piu' lunghi; da fermo il drago si gira spostando le zampe una alla volta. In aria, scendendo verso
  il terreno, le zampe si allungano verso il suolo.
- **Collo e coda**: molle poco smorzate: nelle virate restano indietro e, quando il drago si ferma,
  oscillano e rientrano. Si sommano a `DragonMotion` (che fa i movimenti "voluti").
- **Sella**: il posto di chi monta e' attaccato al petto (attributo `Seat` del server o base del
  collo) e ammortizzato; `PetAnimator` in monta sposta il drago di `seatShift` cosi' il giocatore
  resta sulla sella mentre il corpo si muove sotto di lui. `riderLean` da' rollio e beccheggio del
  corpo per far piegare anche il giocatore (non ancora usato).
- **Ordine dei calcoli**: `PetAnimator` sposta il drago e `KfsPlayer` scrive le ossa nello stesso
  RenderStepped, in un ordine non garantito. Il modulo controlla a Heartbeat se il drago e' stato
  spostato dopo il calcolo e in quel caso anticipa lo spostamento (altrimenti i piedi
  scivolerebbero di v*dt a ogni frame).

## Provato qui (senza Roblox)
`bash tools/anim_test/esegui.sh <test>` (serve `luau`, https://github.com/luau-lang/luau/releases):
- `test_scheletro.luau`: 6 scheletri veri (Gas, Fulmine, Roccia, Gelo giovani; Roccia ed Eclissi
  adulti): testa, mascella, petto, zampe, ali, coda giusti, nessun corno nel collo.
- `test_passi.luau`: dritto, curva, giro sul posto, fermo: piedi appoggiati mai spostati, al massimo
  2 zampe in aria, mai dello stesso lato, passi esterni piu' lunghi in curva; FABRIK.
- `test_procedurale.luau`: il modulo vero su un mondo finto (ossa, terreno, pendio) con Gelo,
  Eclissi adulto e Roccia: piede appoggiato fermo (scivolamento < 0,0004 lunghezze del drago),
  piede sul bersaglio (< 0,002), muso in giu' in discesa (circa la pendenza).
- `test_ordine.luau`: drago spostato dopo il calcolo: i piedi restano fermi (0,003 contro 0,1 studs
  per frame senza anticipo).
- Tipi: `luau-lsp analyze` con le definizioni di Roblox: nessun errore nuovo (in KfsPlayer e
  PetAnimator restano solo quelli che c'erano gia').

**Non provato in Roblox Studio** (la sessione cloud non lo vede): va provato in Play.

## Da provare in Studio (Claude locale)
1. Unisci il branch, Rojo sincronizza. Nell'Output non devono comparire
   `[DragonProcedural] non attivo su ...` per i draghi del giocatore (se compare, scrivi il nome).
2. Drago al seguito a terra: cammina accanto al padrone, gira, si ferma. Guarda: piedi fermi sul
   terreno mentre appoggiati (niente pattinaggio), zampe che non si incrociano, corpo che si inclina
   sui pendii e in curva, coda che oscilla quando si ferma, testa che guarda il padrone da fermo.
   Prova un giovane e un adulto (l'Eclissi adulto e' il piu' grande).
3. Seduto e addormentato (10 e 30 s fermo): le zampe NON devono essere tirate a terra.
4. Monta (H): decollo con lo slancio, in volo il giocatore resta sulla sella (niente tremolii),
   le ali si inclinano nelle virate; atterraggio con le zampe che cercano il suolo.
5. Prestazioni: con 4-5 draghi vicini il frame time non deve salire molto (MicroProfiler).
6. Spegnere tutto per confrontare: `DragonProcedural.enabled = false` (dalla Command Bar del
   client: `require(game.Players.LocalPlayer.PlayerScripts.Client.DragonProcedural).enabled = false`).

Parametri da ritoccare se serve (in `DragonProcedural.luau` / `DragonGait.luau`): lunghezza del
passo (`stride` in `DragonGait.update`), durata (`stepDuration`), altezza dell'arco, rigidezza
delle molle di collo e coda (pulsazione 7/5, smorzamento 0,45/0,35), inclinazione in curva (0,12).

## Limiti noti
- Solo i draghi animati da **KfsPlayer**. Con gli ID di animazione pubblicati (Animator di Roblox)
  `attach` non viene chiamato: servirebbe applicare il procedurale dopo l'Animator.
- La bocca si apre (`setJaw`) solo dove la mascella e' un osso separato riconoscibile.
- Le ali senza dita (Roccia giovane, Gelo e Fulmine adulti) si inclinano ma non si piegano.
- Nessun controllo delle collisioni fra ali e giocatore in monta.
- Non ancora usati: `setJaw` (ruggito, soffio, morso: Combat/Enemies), `riderLean` (piegare il
  personaggio), `impulse("atterraggio")` e `"colpito"`.
