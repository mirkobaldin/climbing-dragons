# Gamepass e prodotti: cosa inserire su Roblox

**Dove si creano:** create.roblox.com → il tuo gioco → **Monetization**:
- **Passes** per i gamepass (si comprano una volta sola e restano per sempre);
- **Developer Products** per gli acquisti ripetibili.

**Dove vanno gli ID:** dopo averli creati copia ogni ID (il numero nell'indirizzo della pagina) nel file indicato:
- i gamepass in `src/shared/DragonConfig.luau`, tabella `GAMEPASSES`;
- i prodotti in `src/shared/ShopConfig.luau`, tabella `DEV_PRODUCTS`.

Con ID = 0 il pass resta nascosto nel negozio del gioco.

**Immagini:** Roblox vuole un'icona quadrata **512×512**, e per i gamepass la mostra ritagliata in un cerchio. Per questo il soggetto va al centro, con il bordo vuoto.

Ogni prompt qui sotto è pronto da incollare in ChatGPT. Chiedi sempre "square 1:1 image" e poi ridimensiona a 512×512.

**Stile comune a tutte le icone** (già incluso in ogni prompt):
- stylized 3D game icon, Roblox store style;
- soggetto unico grande e centrato, contorno leggibile;
- sfondo a sfumatura radiale nel colore indicato;
- niente testo, niente scritte, niente loghi.

**Prezzi:** quelli indicati sono consigli. Per un gioco nuovo conviene partire bassi e alzarli quando hai i dati di vendita.

---

## GAMEPASS (si comprano una volta)

### 1. Fast Incubation
- **Cosa fa nel gioco:** le uova nel nido si schiudono in **metà tempo**.
- **ID in:** `DragonConfig.GAMEPASSES.FastIncubation`
- **Prezzo consigliato:** 149 Robux
- **Nome:** `Fast Incubation`
- **Descrizione:**
  > Your dragon eggs hatch TWICE as fast, forever. Less waiting, more dragons. Works on every egg in your nest, including Legendary ones.
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. A glowing dragon egg cracking open with golden light bursting out, a small golden hourglass with sand flowing fast next to it, motion streaks around the hourglass. Warm orange and gold radial gradient background. Single subject centered, big readable silhouette, empty margin around the edges for a circular crop. No text, no letters, no logo. Roblox game store style, vibrant, soft lighting.

### 2. Egg Finder
- **Cosa fa nel gioco:** una bussola ti indica sempre **l'uovo di drago più vicino** sulla mappa.
- **ID in:** `DragonConfig.GAMEPASSES.EggFinder`
- **Prezzo consigliato:** 99 Robux
- **Nome:** `Egg Finder`
- **Descrizione:**
  > A magic compass that always points to the nearest dragon egg on the mountain. Stop searching, start hatching. Finds eggs in caves, toxic valleys and dragon lands too.
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. An ornate brass explorer compass with a glowing blue crystal needle, a small speckled dragon egg reflected in the glass, sparkles around it. Deep teal to blue radial gradient background. Single subject centered, big readable silhouette, empty margin for a circular crop. No text, no letters, no logo. Roblox game store style, vibrant.

### 3. Extra Dragon
- **Cosa fa nel gioco:** **+1 drago** che ti segue e combatte con te (due al posto di uno).
- **ID in:** `DragonConfig.GAMEPASSES.ExtraDragon`
- **Prezzo consigliato:** 299 Robux
- **Nome:** `+1 Dragon Companion`
- **Descrizione:**
  > Bring TWO dragons on your adventure instead of one. Both follow you, both help in fights, both gain XP in the training arena. Double the power, double the style.
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. Two small cute dragons flying side by side, one dark navy with gold glowing lines, one icy light blue, wings spread, a bold green plus sign shape made of glowing light between them (a symbol, not a letter). Purple to magenta radial gradient background. Centered, big readable silhouette, empty margin for a circular crop. No text, no letters, no logo. Roblox game store style.

### 4. Extra Incubator
- **Cosa fa nel gioco:** **+2 posti** nel nido, così covi più uova insieme.
- **ID in:** `DragonConfig.GAMEPASSES.ExtraIncubator`
- **Prezzo consigliato:** 199 Robux
- **Nome:** `Bigger Nest (+2 slots)`
- **Descrizione:**
  > Your nest gets 2 extra slots: incubate up to 5 dragon eggs at the same time. Collect more, hatch more, find the rare ones faster.
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. A cozy round nest of twigs and feathers holding five colorful dragon eggs (red, blue, purple, gold, green), soft glow coming from the eggs. Warm brown to orange radial gradient background. Centered, big readable silhouette, empty margin for a circular crop. No text, no letters, no logo. Roblox game store style.

### 5. Training x2
- **Cosa fa nel gioco:** **XP doppia per sempre** nell'arena di addestramento dei draghi.
- **ID in:** `DragonConfig.GAMEPASSES.TrainingX2`
- **Prezzo consigliato:** 249 Robux
- **Nome:** `Double Training XP`
- **Descrizione:**
  > Your dragons gain DOUBLE XP in the Training Arena, forever. Reach Level 100 and evolve your dragon into its adult form in half the time.
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. A young dragon breathing a bright beam of fire at a floating blue crystal target that shatters into sparkles, two glowing upward arrows behind it (symbols, not letters). Dark navy to electric blue radial gradient background. Centered, big readable silhouette, empty margin for a circular crop. No text, no letters, no logo. Roblox game store style, dynamic.

---

## DEVELOPER PRODUCTS (si comprano quante volte vuoi)

### 6. Revive
- **Cosa fa nel gioco:** "Soccorso alpino": quando cadi e muori **rinasci dove sei caduto** invece di ricominciare dal fondo. È il prodotto più importante in un gioco "rage": la frustrazione vende.
- **ID in:** `ShopConfig.DEV_PRODUCTS.Revive`
- **Prezzo consigliato:** 25 Robux
- **Nome:** `Mountain Rescue (Revive)`
- **Descrizione:**
  > Fell? Don't start over. The mountain rescue team brings you back exactly where you fell. One use.
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. A red rescue helicopter with a white cross symbol hovering over a snowy mountain ledge, a rope hanging down, bright light beam. Red to warm orange radial gradient background. Centered, big readable silhouette, empty margin around edges. No text, no letters, no logo. Roblox game store style.

### 7. Instant Hatch
- **Cosa fa nel gioco:** **schiude subito** tutte le uova nel nido.
- **ID in:** `ShopConfig.DEV_PRODUCTS.InstantHatch`
- **Prezzo consigliato:** 49 Robux
- **Nome:** `Instant Hatch`
- **Descrizione:**
  > Hatch ALL the eggs in your nest right now. Meet your new dragons instantly.
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. Three dragon eggs exploding open at the same time with a flash of white and gold light, eggshell pieces flying, a lightning bolt symbol above them. Gold to white radial gradient background. Centered, big readable silhouette, empty margin. No text, no letters, no logo. Roblox game store style, energetic.

### 8. 1000 Coins
- **Cosa fa nel gioco:** **1000 monete** da spendere nell'emporio (chiodi, kit medico, uova, case).
- **ID in:** `ShopConfig.DEV_PRODUCTS.Coins1000`
- **Prezzo consigliato:** 79 Robux
- **Nome:** `1,000 Coins`
- **Descrizione:**
  >                                                   
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. A big open leather bag overflowing with shiny gold coins, a few coins flying out with sparkles. Green to gold radial gradient background. Centered, big readable silhouette, empty margin. No text, no letters, no numbers, no logo. Roblox game store style.

*(Da aggiungere più avanti: pacchi da 5.000 e 15.000 monete a 299 e 699 Robux. Il pacco grande fa sembrare conveniente quello medio.)*

### 9. Training Boost (15 min)
- **Cosa fa nel gioco:** **XP x3 per 15 minuti** nell'arena (si somma al pass Training x2).
- **ID in:** `ShopConfig.DEV_PRODUCTS.TrainingBoost`
- **Prezzo consigliato:** 39 Robux
- **Nome:** `Training Boost x3 (15 min)`
- **Descrizione:**
  > TRIPLE training XP for 15 minutes. Stacks with Double Training XP. Perfect before a Target Rush.
- **Prompt immagine:**
  > Square 1:1 stylized 3D game icon. A glowing potion bottle with swirling blue and gold liquid, a small dragon silhouette inside the bottle, a stopwatch symbol beside it. Blue to gold radial gradient background. Centered, big readable silhouette, empty margin. No text, no letters, no numbers, no logo. Roblox game store style.

---

## Regole di Roblox da ricordare
- **Probabilità delle uova:** gli oggetti a caso comprati con soldi veri, o con monete comprate con Robux, devono mostrare le probabilità. Le uova del negozio lo fanno già nella descrizione: non toglierle.
- **Niente promesse false:** nella descrizione scrivi solo quello che il pass fa davvero.
- **Questionario di maturità:** compilalo prima di pubblicare, altrimenti il gioco è visibile a pochi.
- **Icona e miniature del gioco:** servono 1 icona 512×512 e 3-5 miniature 1920×1080. Per le miniature puoi usare la schermata di caricamento e degli screenshot delle clip.
