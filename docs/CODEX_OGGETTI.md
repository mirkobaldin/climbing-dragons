# Prompt per Codex: oggetti nuovi e mancanti (immagini per Meshy + icone)

Da incollare a Codex così com'è.

---

## Contesto (leggi prima AGENTS.md e LAVORI.md)

Gioco Roblox "Climbing & Dragons": montagna stile K2, arrampicata con piccozza e
rampino, minerali, nemici (yeti, golem di ghiaccio), draghi di 8 elementi (Roccia, Gelo, Cosmico,
Tempesta, Eclissi, Fulmine, Ossa, Gas: Brace, Sole e Ombra sono stati tolti, non vanno fatti). Sono appena arrivati:
potenziamenti dello scalatore, taglie, rinascita, parapendio con discesa a tempo, eventi (pioggia
di meteore, drago selvatico, grande valanga), Guardiano della vetta, draghi Shiny.

**Come lavoriamo coi modelli 3D:** Mirko NON vuole oggetti piccoli modellati a mano in Blender
(li ha bocciati: piccozze, zaino, forziere, nido, cristalli). Il flusso giusto è: Codex genera
**immagini di riferimento** pulite → Mirko le passa a **Meshy** (image-to-3D, e auto-rig per i
draghi) → importa in Studio. Quindi qui servono immagini fatte apposta per Meshy, non modelli.

Branch: `codex/oggetti-20261010`. Cartella: `artifacts/oggetti-20261010/`, un PNG per voce con il
nome indicato, più `index.md` (nome → a cosa serve → note per Meshy). Segna il compito in `LAVORI.md`.

### Regole per le immagini da dare a Meshy
- Sfondo **trasparente** (PNG con alpha), oggetto **intero e centrato**, niente ombre a terra,
  niente testo, niente mani o personaggi che lo tengono.
- Vista **3/4 frontale**, luce neutra e uniforme (niente controluce forte: Meshy la "cuoce" nella
  texture). Per i draghi e per gli oggetti indossabili aggiungi anche la **vista frontale** e
  **laterale** in file separati (`_front`, `_side`).
- Stile: fantasy stilizzato ma solido, forme leggibili da lontano, colori saturi, materiali chiari
  (pietra, ghiaccio, metallo, tessuto). Stessa direzione artistica dei draghi esistenti (vedi
  `artifacts/cuccioli-elementali-20261005` e `artifacts/drago-cosmico`).
- Draghi: **posa a T per l'auto-rig** (zampe dritte e separate, ali aperte di lato e piatte, coda
  dritta all'indietro, bocca chiusa). Quattro zampe + due ali, come gli altri. Niente parti
  sottili staccate (catene, fumo, fiamme libere): gli effetti li fa il gioco.
- 1024x1024, lato lungo dell'oggetto all'80% dell'immagine.
- Controlla ogni immagine (alpha vero, niente tagli, niente testo) e rifalla se serve.

---

## 1. Uova mancanti

Stesso stile delle uova esistenti (guscio grande, motivo dell'elemento, base appoggiabile).
`uovo_eclissi` (black shell with a bright orange eclipse ring), `uovo_fulmine` (dark navy shell
with jagged violet lightning cracks), `uovo_ossa` (bone-white shell with fossil-like ribs and
skull pattern), `uovo_gas` (pale cyan shell with swirling magenta clouds; NON verde).

## 2. Oggetti delle funzioni nuove (3D, per Meshy)

| Nome | A cosa serve | Prompt |
|---|---|---|
| `parapendio` | vela del parapendio sopra il giocatore | Mountain paraglider canopy seen from below-front: curved orange and white fabric wing with cell openings on the front edge, thin suspension lines converging to a small harness bar; clean, no person |
| `meteorite` | meteorite da raccogliere (evento) | Fallen cosmic meteorite: rough dark rock the size of a boulder, deep violet crystal veins glowing from cracks, small magenta crystals poking out, slightly smoking crater rim |
| `esoscheletro` | si vede sulla schiena col potenziamento | Climbing exoskeleton frame worn on the back: lightweight steel and leather spine with two shoulder braces and hip belt, small pistons at the joints, rope coil and carabiners clipped on |
| `stivali_veloci` | stivali del potenziamento | Pair of light mountain boots with ice-blue fur trim, steel toe cap, small wing-shaped metal ornaments on the heels, crampon spikes under the sole |
| `scudo_gelo` | scudo di ghiaccio (bolla attorno al giocatore) | Translucent hexagonal ice shield dome segment, frosted edges, faint blue glow, a few cracks; one curved panel (the game repeats it into a bubble) |
| `bacheca_taglie` | bacheca delle taglie al campo base | Wooden mountain notice board with a small shingle roof, pinned parchment wanted posters, rope and lantern hanging on the side, sturdy legs planted in stones |
| `altare_rinascita` | altare della rinascita | Ancient stone altar on a mountain peak: circular platform with carved runes, four short obelisks, a floating glowing violet crystal in the center, snow on the stones |
| `stele_record` | classifica della discesa al campo base | Tall carved stone stele with a podium of three steps in front (gold, silver, bronze inlays), small mountain and paraglider relief carved at the top, blank flat face for text |
| `banco_potenziamenti` | dove si comprano i potenziamenti | Upgrade workbench of a mountaineer-blacksmith: heavy wooden table with anvil, grappling hooks, coiled ropes, a half-built exoskeleton, glowing forge brazier on one side |
| `uncino_rampino` | la testa del rampino che vola | Grappling hook head: three curved steel claws with sharp tips, ring for the rope at the back, worn metal, slight blue tint |
| `trono_guardiano` | nido del Guardiano sulla vetta | Giant dragon nest made of broken stone pillars, black rocks and bones, scattered gold coins and shards of eclipse crystal, wide enough for a huge dragon to sit in |

## 3. Immagini per effetti (texture, non 3D)

Sprite sheet 1024x1024 a griglia 4x4 (16 fotogrammi), sfondo nero (si usa con LightEmission) o
trasparente: `fx_palla_<elemento>` per gli 8 elementi (palla di fuoco/gelo/fulmine... che si
contorce, per i soffi dei draghi), `fx_meteora` (testa infuocata con scia viola), `fx_onda_urto`
(anello di polvere e neve visto dall'alto, per la picchiata), `fx_stordito` (stelline che girano).

## 4. Icone dell'interfaccia (256x256, stesso stile di `artifacts/ui-20261010`)

Usa lo stesso blocco di stile del compito UI (pietra scura, ghiaccio, oro, sfondo trasparente,
niente testo).
- Potenziamenti: `up_rampino` (rope with hook flying far), `up_uncino` (hook hitting a monster
  silhouette with a spark), `up_lancio` (spinning ice axe), `up_esoscheletro`, `up_scudo` (ice
  hexagon shield), `up_stivali` (winged boot), `up_picchiata` (boot slamming down with shockwave).
- Taglie: `taglia_yeti` (yeti head), `taglia_golem` (ice golem head), `taglia_minerali` (ore
  pile), `taglia_scalata` (mountain with up arrow), `taglia_uova` (egg in nest), `taglia_aria`
  (falling climber with shockwave), `taglia_speciale` (dragon roaring), `sfida_giorno` (sun badge
  with laurel).
- Altro: `rinascita` (violet phoenix-like spiral), `discesa` (stopwatch with paraglider),
  `evento_meteore`, `evento_drago`, `evento_valanga`, `shiny` (golden sparkle star),
  `speciale_<elemento>` per gli 8 elementi (pulsante dell'attacco speciale, simbolo
  dell'elemento in un cerchio).

## Fine compito
Messaggio finale con l'elenco dei file e, per ogni oggetto 3D, una riga "Meshy: …" con le
impostazioni consigliate (es. "quadruped auto-rig: sì" per i draghi, "polycount basso" per gli
oggetti piccoli). Il caricamento in Studio e l'aggancio al gioco li fa Claude (o Mirko): Codex non
tocca `src/`.
