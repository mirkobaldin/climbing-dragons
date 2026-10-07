# Prompt per le immagini dei modelli (da usare su Meshy, image-to-3D)

Regole per tutte le immagini:

- **Un solo soggetto**, centrato, intero nell'inquadratura.
- **Niente sfondo** (trasparente o bianco piatto), niente ombre per terra, niente testo.
- **Personaggi e mostri in posa neutra** (A-pose: braccia leggermente aperte, gambe dritte; quadrupedi dritti sulle quattro zampe, coda distesa, ali aperte lateralmente), così il rig viene pulito.
- **Oggetti** (piccozze, materiali) in vista 3/4 dall'alto, dritti, senza mani che li tengono.
- **Stile:** stylized semi-realistic, colori saturi, adatto a Roblox, materiali PBR leggibili.
- **Colori:** quelli del drago della zona.

Quando li importi, mettili in **ServerStorage.Modelli** (nemici e boss in ServerStorage.Nemici).

---

## 1. Nemici delle zone (versione SEMPLICE)

Quelli di prima venivano troppo complessi: piume una per una, ossa sottili, mantelli strappati, fumo, punte ovunque. Su Meshy diventano mesh sporche e il rig si rompe. Queste versioni hanno:

- **forme grandi e chiuse**, stile "giocattolo / Clash Royale", proporzioni un po' cartoon (testa e mani grandi);
- **niente parti sottili** (niente piume singole, dita lunghe, catene, mantelli strappati, capelli);
- **niente effetti** (fumo, fulmini, scintille, nebbia: quelli li fa il gioco con le particelle);
- **2-3 colori principali** del drago della zona, più un colore luminoso per occhi e cristalli;
- **superfici lisce o a grandi sfaccettature**, ali come lastre spesse e piene, senza buchi.

Chiusura uguale per tutti:
> Simple chunky stylized 3D game character, toy-like proportions, big readable shapes, smooth solid surfaces, no thin parts, no particles, no smoke, no lightning effects, no transparency. Neutral pose: [POSA]. Full body, centered, plain white background, no shadow, front 3/4 view, Roblox game asset.

Posa: bipedi "standing straight, A-pose, arms slightly away from the body"; quadrupedi "standing on four legs, tail straight back"; creature con ali "wings fully opened to the sides, flat and solid".

### Roccia
**Basilisco di Roccia** (comune)
> A low wide lizard made of big rounded sandstone plates in warm ochre and tan, four short thick legs, a heavy blunt head with two small glowing amber eyes, a short thick tail ending in a round rock club, three large amber crystals sticking out of the back. + chiusura (quadrupede)

**Colosso d'Ambra** (boss)
> A huge round golem made of a few big smooth boulders in ochre and brown, a large glowing amber crystal in the middle of the chest, two big boulder fists, short thick legs, a small head with two glowing amber eyes, two amber crystals on the shoulders. + chiusura (bipede)

### Ossa
**Guerriero d'Ossa** (comune)
> A cute chunky skeleton warrior with thick rounded bones in ivory white, a big round dragon-skull helmet with two short horns, glowing mint-green eyes, a simple bone shield on one arm, a short wide bone club in the other hand, a solid grey cloth belt. + chiusura (bipede)

**Wyrm d'Ossa** (boss)
> A big chunky bone dragon on four legs, ivory white thick rounded bones forming a solid body (ribs closed with a pale green glowing core inside), a large horned skull head with glowing green eyes, two big solid bone wings shaped like thick plates, a short thick bony tail. + chiusura (creatura con ali)

### Tempesta
**Arpia della Tempesta** (comune)
> A chunky round bird creature standing on two thick legs, body made of large smooth feather plates in slate grey and storm blue, two big wing shapes made of solid layered panels, a round head with a short yellow-grey beak and glowing pale blue eyes, a small cloud-shaped crest. + chiusura (creatura con ali)

**Roc del Tuono** (boss)
> A huge chunky eagle made of large smooth feather plates in dark navy and storm grey, a white chest, big solid wings shaped like wide panels with a pale blue lightning-bolt pattern painted on them, a strong steel-grey beak, glowing white-blue eyes, thick talons. + chiusura (creatura con ali)

### Fulmine Nero
**Pantera del Vuoto** (comune)
> A chunky stylized black panther with a smooth glossy body, thick legs and big paws, a round head with short ears and glowing violet eyes, a few wide painted violet lightning stripes on the body, a thick tail with a violet glowing tip. + chiusura (quadrupede)

**Sentinella d'Ossidiana** (boss)
> A big blocky golem made of large faceted black obsidian blocks with purple reflections, wide shoulders, big block fists, short thick legs, a square head with one horizontal glowing violet visor, a few violet glowing lines on the chest. + chiusura (bipede)

### Cosmico
**Spettro Stellare** (comune)
> A cute floating ghost-like creature with a solid rounded body in deep purple with small painted white stars, a hood shape over the head, two big glowing white round eyes, two short round arms, the lower body ends in a solid rounded tail (no wisps). + chiusura (bipede)

**Serpente Stellare** (boss)
> A big chunky cosmic serpent dragon lying in a wide S shape, thick smooth body in dark purple and indigo with painted white star dots and magenta spots, a round head with two short horns and glowing white eyes, a row of rounded purple crystals along the back, no legs. + chiusura (quadrupede, "body laid flat in an S curve")

### Eclissi
**Cavaliere dell'Eclissi** (comune)
> A chunky armored knight with smooth rounded plate armor in matte black and dark navy, thick gold trims, a round helmet with a black visor and a thin glowing gold ring around the face, a big round black shield with a gold eclipse symbol, a short wide sword. + chiusura (bipede)

**Guardiano dell'Eclissi** (boss)
> A huge chunky armored giant in matte black and dark navy with thick gold trims, a large solid black disc with a glowing gold rim attached behind the head like a halo, big round shoulder plates, big fists, a faceless helmet with one glowing gold line for eyes. + chiusura (bipede)

### Gas
**Predatore della Palude** (comune)
> A chunky crocodile-like creature with a wide smooth body in dark indigo blue, big rounded glowing cyan sacs on its sides, a wide head with glowing magenta eyes, short thick legs, a row of rounded cyan spikes along the back, a thick tail. + chiusura (quadrupede)

**Idra Tossica** (boss)
> A big chunky three-headed hydra with a round heavy body in royal blue, three thick short necks with simple round dragon heads, glowing magenta eyes, rounded cyan spikes on the necks, a big glowing cyan belly, four thick legs, a short thick tail. + chiusura (quadrupede)

### Gelo (opzionale)
**Re Yeti** (boss)
> A huge chunky yeti with thick smooth white fur shaped in big rounded clumps, pale blue face and hands, a crown of a few big blue ice crystals, glowing icy blue eyes, big round fists. + chiusura (bipede)

**Titano di Ghiaccio** (boss)
> A huge golem made of a few big smooth blocks of light blue ice, a glowing white core in the chest, two big ice block fists, snow caps on the shoulders, a small square head with two glowing blue eyes. + chiusura (bipede)

---

## 1b. Cristalli delle zone a tema

Mettili in `ServerStorage.Modelli` con questi nomi esatti e alla prossima rigenerazione della mappa prendono il posto dei cristalli fatti a blocchi:

| Nome del modello | Prompt |
|---|---|
| `Cristallo_Roccia` | A cluster of 3 to 5 chunky amber crystals growing out of a rough sandstone base, warm orange-gold, glowing from inside, big faceted shapes, stylized. |
| `Cristallo_Ossa` | A cluster of pale mint-green crystals growing out of an old ivory dragon bone lying on the ground, chunky faceted shapes, soft green glow, stylized. |
| `Cristallo_Tempesta` | A cluster of steel-blue crystals with white tips, a jagged lightning-bolt shape, on a dark slate rock base, chunky faceted, stylized. |
| `Cristallo_Fulmine` | A cluster of glossy black obsidian crystals with glowing violet cracks running through them, sharp but chunky facets, on a black rock base, stylized. |
| `Cristallo_Cosmico` | A cluster of deep purple and magenta crystals with tiny white star dots inside, one tall central crystal, rounded rock base, stylized. |
| `Cristallo_Eclissi` | A cluster of matte black crystals with glowing gold-orange edges, a black disc with a gold ring on the tallest crystal, dark rock base, stylized. |
| `Cristallo_Gelo` | A cluster of clear light-blue ice crystals with frosty white edges, on a snowy rock base, stylized. |
| `Cristallo_Gas` | A cluster of glowing cyan crystals with magenta tips, a few round bubbles on the rock base, dark indigo rock, stylized. |

Chiusura per tutti:
> Single prop, centered, plain white background, no shadow, Roblox game asset.

---

## 1c. Immagine della schermata di caricamento (Codex o qualsiasi generatore)

> Epic wide 16:9 key art for a Roblox game called "Hardcore Climbing". A gigantic snowy K2-like mountain with ice cliffs and a huge glowing blue ice cave in its face, a tiny climber with an ice axe on a ledge in the foreground, and a large dark navy dragon with gold glowing lines and a black-and-gold eclipse ring flying past the peak at sunset. Warm orange sky at the horizon, deep blue night at the top, a few stars. Stylized, vibrant, painterly 3D look like a mobile game splash screen. No text, no logo. Keep the lower third darker and simple, because the title goes there.

Caricala su Roblox (Creator Hub → Development Items → Images), copia l'id e incollalo in `src/first/LoadingScreen.client.luau`, alla riga `local IMAGE = ""`.

---

## 2. Piccozze (si craftano, si lanciano e tornano indietro)

**Piccozza da spedizione** (base)
> A stylized mountaineering ice axe, steel head with a curved serrated pick and a flat adze, slightly scratched worn metal, a straight wooden shaft wrapped with red and black climbing tape near the grip, a metal spike at the bottom and a small leather wrist loop. Single object, upright, 3/4 view from slightly above, centered, no hands, no background, no shadow, game-ready Roblox tool asset, PBR, stylized semi-realistic.

**Piccozza d'Ambra** (Roccia)
> A stylized fantasy ice axe with a head carved from warm sandstone and bronze metal, a large glowing amber crystal set where the head meets the shaft, the pick edge lined with smaller amber shards, a shaft of dark hardwood bound with brown leather straps and bronze rings. Single object, upright, 3/4 view from above, centered, no hands, no background, no shadow, Roblox tool asset, PBR, stylized.

**Piccozza d'Ossa** (Ossa)
> A stylized fantasy ice axe made of polished ivory dragon bone, the curved pick shaped like a dragon fang, a small dragon skull carved at the joint of the head with pale mint-green glowing eye sockets, a shaft of a long femur bone wrapped in faded grey cloth, small green runes along the shaft. Single object, upright, 3/4 view from above, centered, no hands, no background, no shadow, Roblox tool asset, PBR, stylized.

**Piccozza della Tempesta** (Tempesta)
> A stylized fantasy ice axe with a steel-blue metal head shaped like a lightning-split feather, thin pale-blue electric arcs between the pick and the adze, storm-grey metal shaft with silver rings and dark navy grip, a small glowing blue crystal at the end. Single object, upright, 3/4 view from above, centered, no hands, no background, no shadow, Roblox tool asset, PBR, stylized.

**Piccozza del Fulmine Nero** (Fulmine)
> A stylized fantasy ice axe made of black obsidian glass with sharp faceted edges, glowing violet lightning cracks running through the head and down the shaft, a grip wrapped in dark purple leather, a jagged obsidian spike at the bottom. Single object, upright, 3/4 view from above, centered, no hands, no background, no shadow, Roblox tool asset, PBR, stylized.

**Piccozza Stellare** (Cosmico)
> A stylized fantasy ice axe with a head of translucent deep purple crystal containing tiny glowing stars and magenta nebula swirls, silver metal fittings shaped like crescent moons, a dark indigo shaft with small embedded white star gems. Single object, upright, 3/4 view from above, centered, no hands, no background, no shadow, Roblox tool asset, PBR, stylized.

**Piccozza dell'Eclissi** (Eclissi)
> A stylized fantasy ice axe with a matte black metal head shaped like a crescent, a thin glowing gold-orange rim along every edge like an eclipse corona, a black disc emblem with a gold ring at the joint, a dark navy shaft with gold rings and a black leather grip. Single object, upright, 3/4 view from above, centered, no hands, no background, no shadow, Roblox tool asset, PBR, stylized.

**Piccozza Glaciale** (Gelo)
> A stylized fantasy ice axe with a head made of clear blue glacier ice with frost patterns, the pick a long sharp icicle, a pale silver shaft wrapped in white fur near the grip, small snowflake engravings, faint cold mist. Single object, upright, 3/4 view from above, centered, no hands, no background, no shadow, Roblox tool asset, PBR, stylized.

**Piccozza Tossica** (Gas)
> A stylized fantasy ice axe with a dark indigo metal head, glass vials of glowing cyan poison built into the head, the pick edge dripping with luminous cyan and magenta liquid, a shaft wrapped in deep blue leather with magenta stitching. Single object, upright, 3/4 view from above, centered, no hands, no background, no shadow, Roblox tool asset, PBR, stylized.

---

## 3. Materiali da craft (drop)

Per tutti: "Single small item, centered, 3/4 view from above, no background, no shadow, Roblox game item asset, PBR, stylized semi-realistic, readable silhouette."

| Materiale | Chi lo lascia | Prompt |
|---|---|---|
| **Frammento d'Ambra** | Basilisco, Colosso, rocce del canyon | A chunk of raw golden amber crystal with a warm inner glow, rough sandstone still attached at the base, small trapped bubbles inside. |
| **Cuore del Colosso** | Colosso d'Ambra (raro) | A large heart-shaped amber crystal with molten orange light pulsing inside, cracked sandstone shell around it. |
| **Osso Antico** | Guerriero d'Ossa, Wyrm d'Ossa | A large old ivory dragon bone, slightly curved, with cracks, moss spots and faint pale-green runes carved on it. |
| **Teschio del Wyrm** | Wyrm d'Ossa (raro) | A small dragon skull of ivory bone with two curved horns and pale-green glowing eye sockets. |
| **Piuma di Tempesta** | Arpia, Roc | A long storm feather in slate grey and steel blue with a pale-blue electric glow along the edge and tiny sparks. |
| **Penna del Tuono** | Roc del Tuono (raro) | A huge dark navy feather shaped like a lightning bolt, glowing electric white-blue core. |
| **Scheggia d'Ossidiana** | Pantera, guglie del fulmine | A sharp shard of black obsidian glass with glowing violet lightning cracks inside. |
| **Nucleo della Sentinella** | Sentinella d'Ossidiana (raro) | A faceted black crystal sphere with a single glowing violet eye-like core and purple arcs around it. |
| **Polvere di Stelle** | Spettro, cristalli cosmici | A small glass vial filled with glowing purple and magenta star dust, tiny stars floating inside, silver cork. |
| **Stella Caduta** | Serpente Stellare (raro) | A small fallen star, a glowing white-pink crystal star shape with a purple nebula halo. |
| **Frammento d'Eclissi** | Cavaliere | A black crescent-shaped stone fragment with a thin glowing gold-orange rim. |
| **Corona dell'Eclissi** | Guardiano (raro) | A black disc with a burning gold-orange ring of light around it, like a solar eclipse. |
| **Spora Tossica** | Predatore della palude, fumarole | A round glowing spore pod with a cyan translucent skin and magenta veins, dripping glowing liquid. |
| **Ghiandola dell'Idra** | Idra Tossica (raro) | A bulbous poison gland filled with luminous cyan liquid, deep blue scaly skin around it. |
| **Cristallo di Ghiaccio** | grotte di ghiaccio, golem | A clear blue ice crystal cluster with frost on the edges and a cold inner glow. |
| **Pelliccia di Yeti** | Yeti, Re Yeti | A folded thick white and pale-blue fur pelt with small frost crystals on it. |
| **Nucleo Glaciale** | Golem, Titano (raro) | A glowing white-blue orb of solid ice with swirling frost inside. |

**Come si usano:**
- materiale comune della zona + ferro → la piccozza del tema;
- materiale raro del boss → abilità forte della piccozza (lancio a rimbalzo, onda d'urto, veleno, gelo).

---

## 4. Oggetti di scena (opzionali, per abbellire le zone)

- **Altare-nido a tema (uno per drago):**
  > A circular stone altar for a dragon egg, carved dragon claws rising from the edge to hold a nest of twigs and feathers, runes on the side; colors: [colori del drago]. Single object, centered, no background, no shadow, Roblox prop asset, PBR, stylized.
- **Banco da lavoro del crafting:**
  > A fantasy blacksmith crafting table of dark wood and iron, an anvil on one side, a rack of ice axes, dragon scales hanging on hooks, glowing blue runes on the front, small tools and crystals on top. Single object, centered, no background, no shadow, Roblox prop, PBR, stylized.
- **Scheletro di drago gigante (Cimitero):**
  > A giant dragon skeleton lying on its side, ivory weathered bones, long ribcage, horned skull, broken wing bones, moss and pale green glow in the eye sockets. Single object, full view, no background, no shadow, Roblox environment prop, PBR, stylized.
- **Arena alternativa con ingresso chiaro** (se quella di adesso non ti convince):
  > A circular dragon training arena seen from above at 3/4 view, a flat round stone floor with a big glowing rune circle in the middle, a ring of low stone walls with dragon bones as decoration, ONE single wide clear entrance with big stairs and two dragon skull statues on the sides of the entrance, the rest of the ring closed, 8 stone braziers around the floor. Chunky stylized shapes, no thin parts. Single object, centered, plain white background, no shadow, Roblox environment asset.
