# Prompt Meshy per l'Isola dei Draghi

Nella sessione cloud non c'e' `MESHY_API_KEY` e il backend image-to-3D della skill non raggiunge
Hugging Face (rete bloccata). Questi modelli vanno generati a mano su meshy.ai e messi in
`cloud/IsolaDraghi/meshy/` con il nome indicato (GLB o FBX con texture PBR). Al loro posto nel
modello ci sono segnaposto `PLACEHOLDER_*` con le misure e la posizione giuste: la sessione cloud
poi li pulisce (decimate sotto il budget, UV, scala, origine) e li mette al posto del segnaposto.

Impostazioni consigliate in Meshy: **Text to 3D** (o Image to 3D se hai un'immagine), stile
"Realistic", **PBR attivo**, poligoni "Medium" (circa 30-50k: li riduco io), posa simmetrica, sfondo
vuoto. Per le statue: una generazione per elemento (8), stessa posa.

## 1. `meshy/TestaDrago.glb` — teste del portale (una, la specchio io)
Misure finali: lunga 10 m, larga 6 m, alta 7 m (con le corna). Esce dal pilone del portale.

> Monumental carved stone dragon head emerging from a castle wall, mouth wide open roaring, long
> sharp teeth, curved horns sweeping back, heavy brow ridges, scales carved in dark volcanic
> basalt stone with worn edges, cracks and moss in the crevices, antique bronze rings in the horns,
> neck ends flat as if built into the wall, game asset, stylized realistic, PBR textures, front view symmetric

## 2. `meshy/StatuaDrago_<Elemento>.glb` — 8 statue accucciate sopra le torri
Misure finali: lunga 9 m, larga 5 m, alta 6 m. Una per elemento: Roccia, Gelo, Cosmico, Tempesta,
Eclissi, Fulmine, Ossa, Gas (nomi file: `StatuaDrago_Roccia.glb`, ...). Stessa posa per tutte:
accucciato sul bordo, artigli che stringono la pietra, ali chiuse, testa in avanti e un po' in giu'.

Base comune (poi aggiungi la riga dell'elemento):
> Stone gargoyle dragon statue crouching on a ledge, front claws gripping the edge, wings folded on
> its back, long tail curled around the base, head lowered and looking forward, carved from dark
> volcanic stone, weathered edges, cracks, game asset, stylized realistic, PBR textures

| Elemento | Riga da aggiungere |
|---|---|
| Roccia | with amber-brown stone plates on the back and jagged rock spikes along the spine |
| Gelo | pale blue-grey stone, frost-like ridges along the wings and spine |
| Cosmico | dark violet stone with small inlaid gold star patterns on the wings |
| Tempesta | steel blue-grey stone, swept-back horns shaped like wind, rippled wing membranes |
| Eclissi | black stone with an antique gold ring halo behind the head |
| Fulmine | black stone with jagged lightning-shaped horns and yellow-gold inlaid zigzag lines |
| Ossa | ivory bone-colored stone, exposed carved ribs and a skull-like face |
| Gas | dark green stone with bulbous sacs on the neck and small round vents along the back |

## 3. `meshy/CornaAltare.glb` — corna dell'altare del duello (un paio)
Misure finali: alte 2,5 m, base 0,5 m, curve verso l'interno, distanza fra le punte 1,5 m.

> Pair of huge curved dragon horns mounted on a stone base, ivory bone color with dark grooves
> and ridges, tips curving inward toward each other, ancient and cracked, game asset, PBR textures

## Dopo la generazione
Metti i file in `cloud/IsolaDraghi/meshy/` (anche via GitHub web: Add file > Upload files) e dimmelo:
li pulisco, li porto sotto 20.000 triangoli ognuno, li scalo alle misure qui sopra e li metto al
posto dei segnaposto, con anteprime e controllo.
