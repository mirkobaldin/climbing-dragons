# Compito per la sessione cloud di Claude: modelli 3D in Blender

Scritto da Claude (locale) il 2026-10-14. Leggi prima `AGENTS.md`.

La sessione cloud **non vede Roblox Studio** e il file place non e' nel repo: lavori solo in
Blender (senza interfaccia) e consegni file. L'import in Studio, le texture caricate su Roblox e la
prova in Play le fa Claude in locale. Non toccare `src/` (ci lavora Claude in locale nello stesso
momento): i tuoi file vanno solo nelle cartelle indicate sotto.

## 0. Preparazione dell'ambiente
- Serve l'accesso a internet completo (impostazioni dell'ambiente cloud: "Full"), per scaricare
  Blender 5.2 per Linux da `download.blender.org` (archivio `.tar.xz`, nessuna installazione).
- Lancia sempre `blender -b --factory-startup --python <script> -- <argomenti>`.
- Ogni modello si fa **da script Python** (`tools/blender/arena.py` e `tools/blender/mappa.py`, con
  funzioni comuni in `tools/blender/borghi_lib.py` se ti servono), cosi' si rifa' identico.
- Branch: `cloud/modelli-20261014`. Commit piccoli in italiano. Alla fine `git rebase main`.
- Le uscite pesanti (`.fbx`, texture, anteprime) vanno nella cartella del modello sotto
  `cloud/<Nome>/` e si committano con **Git LFS** (`git lfs track "cloud/**/*.fbx" "cloud/**/*.png"`).

## 1. Formato di consegna (uguale al set alpino di Codex, gia' caricato in Studio)
Una cartella per modello: `cloud/<Nome>/`
- `<Nome>.fbx`: la mesh, **metri reali** (1 m = 1 stud: il gioco poi scala), lato frontale /
  ingresso verso **+Z**, origine a terra al centro, trasformazioni applicate.
- `<Nome>_Collision.fbx`: solo scatole, cilindri e rampe semplici (oggetti `COL_*`); le scale
  sono `COL_Rampa*` inclinate, mai scatole piene.
- `Markers.json`: empty `FX_Light_<nome>` (luci), `FX_Fire_<nome>` (fuoco dei bracieri),
  `SPOT_<nome>` (punti che il gioco usa, vedi l'arena), con `position_y_up_m` (assi Roblox: x, z, -y).
- Texture PBR 1024x1024 per materiale: `<Mat>_BaseColor.png`, `_Normal.png`, `_Roughness.png`
  (al massimo 4 materiali per mesh). Nomi di file e oggetti **sotto i 50 caratteri**.
- Ogni singola mesh: **sotto 20.000 triangoli** e **sotto 2048 m** per lato (limite di Roblox):
  i modelli grandi vanno divisi in pezzi (oggetti separati nello stesso `.fbx`).
- `anteprime/`: render davanti, dietro, dall'alto e in 3/4 (Eevee, 1600x900), da guardare prima
  di consegnare. Se un render sembra brutto, rifallo: Mirko boccia i modelli "a blocchi".
- Niente script, niente armature (sono modelli fissi).

Lo stile: realistico-stilizzato come le case di Codex (`MegaChalet`, `StoneCabin`), bordi smussati
(bevel), pietra consumata, legno, ferro battuto, oro antico; dettagli scolpiti veri (non solo
texture). Colori dei draghi: Roccia marrone/ambra, Gelo azzurro ghiaccio, Cosmico viola/blu
stellato, Tempesta blu acciaio, Eclissi nero/oro, Fulmine (Fulmine Nero) nero/giallo elettrico,
Ossa avorio, Gas verde acido.

## 2. PRIORITA' 1: la nuova Arena dei Draghi (`cloud/ArenaDraghi/`)
Quella di oggi (`arenadrago`, uno scheletro di drago scalato a 100 stud) non sembra un'arena. Serve
un **colosseo dei draghi** degno del nome, visibile da lontano.

Come si usa nel gioco (server/Training): il giocatore sale su una **pedana fuori dalle mura**,
davanti all'ingresso, e da li' "diventa" il suo drago, che vola **dentro** l'arena e combatte contro
draghi selvatici che girano in cerchio (Duello: 3 round). Dentro ci volano solo i draghi: l'interno
va lasciato **libero e aperto in alto** (niente tetto, niente pilastri in mezzo).

Misure (metri):
- Pianta circolare (o ottagonale, 8 lati = 8 elementi), **diametro interno 150**, esterno ~190.
- Mura con **gradinate** all'interno (4-5 file, 22 m d'altezza), arcate a due piani all'esterno
  (stile Colosseo ma con pietra scura e ferro), cornicione merlato.
- **8 torri** sul perimetro (alte 40 m), una per elemento: stendardo del colore dell'elemento,
  braciere in cima (`FX_Fire_Torre<Elemento>`, `FX_Light_Torre<Elemento>`), simbolo scolpito.
- **Portale d'ingresso** monumentale sul lato +Z: arco alto 30 m fra due teste di drago scolpite
  a bocca aperta, catene, saracinesca alzata. Davanti, a 12 m dalle mura, la **pedana del
  domatore**: piattaforma tonda di 10 m di diametro con 3 gradini e un leggio di pietra con rune
  (`SPOT_Pedana` al centro, a filo del piano). Da li' si vede dentro dall'arco.
- **Palco d'onore** sul lato opposto (-Z): loggia coperta con trono e due statue di drago.
- **Pavimento** dell'arena: sabbia/pietra con un grande cerchio di rune incise (70 m) e 8 spicchi
  colorati poco saturi; segni di bruciature e graffi (texture). `SPOT_Centro` al centro a 0 m.
- **8 pali per i draghi selvatici** (`SPOT_Posatoio1..8`) in cima alle mura, ogni 45 gradi: anelli
  di ferro con catene.
- **Altare del Duello** (`SPOT_Altare`), fuori dalle mura a destra della pedana: blocco di basalto
  con rune rosse luminose, braciere e due corna di drago (oggi e' fatto di Part rosse).
- Origine: centro del pavimento, a terra (Y = 0). Le fondamenta scendono 6 m sotto Y = 0 (il terreno
  non e' mai piano del tutto).
- Pezzi separati nell'`.fbx`: `Arena_Mura_01..08` (un ottavo ciascuno), `Arena_Torre_<Elemento>`,
  `Arena_Portale`, `Arena_Pedana`, `Arena_Palco`, `Arena_Pavimento`, `Arena_Altare`,
  `Arena_Stendardo_<Elemento>` (separati: il gioco li fa ondeggiare).
- Collisione: muro esterno e gradinate come scatole/rampe, il pavimento piatto, la pedana con
  rampa sui gradini; l'arco del portale **aperto** (ci passano i draghi: largo 20 m).
- Triangoli in tutto: sotto 250.000.

## 3. PRIORITA' 2: modelli della mappa
Fai la lista di `docs/CODEX_MODELLI_MAPPA.md` (stessa consegna, una cartella `cloud/<Nome>/` per
modello), saltando il n. 6 `AltareDuello` (e' gia' dentro l'arena). Ordine: 1, 2, 3, 5, 9, 13, 14,
poi gli altri.

## 4. Quando hai finito
- Aggiorna `cloud/LEGGIMI.md` con l'elenco dei modelli, misure, triangoli e marcatori.
- Nel messaggio finale scrivi cosa va controllato in Studio (scala, passaggi, rampe, luci).
- Non unire niente in `main`: lo fa Claude in locale dopo la prova in Play.
