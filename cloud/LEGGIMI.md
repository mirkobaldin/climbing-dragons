# Modelli della sessione cloud (2026-10-14)

Compito: `docs/CLOUD_SESSIONE.md`. Tutto si rifà da script (Blender 5.2):

```
blender -b --factory-startup --python tools/blender/arena.py -- [--render] [--viste davanti,pedana,...]
```

- `tools/blender/cloud_lib.py`: texture PBR 1024 procedurali (solo numpy), geometria, esportazione
  (FBX, collisioni, `Markers.json`, `Materials.json`, `info.json`) e anteprime.
- Le ossa dei draghi le fanno i generatori della skill `roblox-reference-modeling`
  (`.claude/skills/roblox-reference-modeling/scripts/anatomy_lib.py`: cranio, mascella, denti, corna,
  vertebre, costole, ossa delle ali, membrane, zampe, artigli), chiamati da `cloud_lib.anatomia()`.
  Non ci sono immagini di riferimento, quindi le fasi della skill sui riferimenti non si usano.
  La skill `roblox-creature-rig-animation` non serve: l'arena è un modello fisso.

**Attenzione:** da questa sessione GitHub rifiuta l'upload LFS. FBX, PNG e anteprime NON sono nel
repo. Si rigenerano in locale con il comando sopra (circa 25 s senza render).

## ArenaDraghi (priorità 1) — `cloud/ArenaDraghi/`

Colosseo ottagonale con **due draghi scheletrici giganti avvolti sulle mura**:
- i crani a fauci aperte poggiano sui piloni ai lati del portale;
- le spine dorsali corrono sopra le mura a 36 m, con le costole drappeggiate dentro e fuori;
- le zampe artigliano i merli e il camminamento;
- le ali si alzano fino a circa 80 m, visibili da lontano;
- le code si intrecciano in una guglia dietro il palco (`SPOT_GugliaCode`, 72 m).

Misure in metri. Assi Blender: Z in alto, l'ingresso guarda verso -Y, che in Roblox è +Z.

| Parte | Misure |
|---|---|
| Pianta | ottagono, apotema interno 75 (Ø 150), esterno 95 (Ø circa 190), fondamenta a -6 |
| Mura | podio 5 m, 10 gradoni (1,7 x 1) fino a 22, camminamento, parapetto 25, merli 27,5; fuori arcate a due piani con cancellate di ferro |
| Torri | 8, raggio 9, alte 40 con il braciere; stendardo (pezzo a parte) e stemma d'oro dell'elemento |
| Portale | arco 20 x 30 sul lato -Y, saracinesca alzata, targa con rune, catene dalle mascelle dei crani agli anelli a terra |
| Pedana | centro (0, -120): piano Ø 10 a 1,05 m, 3 gradini, leggio con rune |
| Altare | (16,5, -121): basalto, rune, braciere, due corna |
| Palco | lato +Y: loggia coperta, trono, due statue di drago Eclissi |
| Pavimento | lastricato con sabbia, cerchio di rune Ø 70, 8 spicchi degli elementi (atlante `Spicchi`) |

- Triangoli: 244.546 in tutto, 118 parti. La parte più pesante ha 8.400 triangoli (le catene del portale).
- Materiali: un materiale per parte, ognuno con texture BaseColor, Normal e Roughness. `MAT_Ember` (rune e braci) è Neon, senza texture.
- Collisioni: 200 scatole. L'arco del portale è aperto (20 x 30). Le rampe della pedana sono scatole inclinate.
  Le ossa dei draghi non hanno collisione, tranne i due crani.
- Marcatori: `FX_Fire/Light_Torre<Elemento>`, `FX_Fire/Light_Ingresso{Sx,Dx}`, `FX_Fire_Palco{Sx,Dx}`,
  `FX_Light_Palco`, `FX_Light_Occhi{Sx,Dx}`, `FX_Fire/Light_Altare`, `FX_Light_Pedana`,
  `SPOT_Pedana`, `SPOT_Centro`, `SPOT_Altare`, `SPOT_Posatoio1..8`, `SPOT_GugliaCode`.
- Posatoi: 1 sopra il portale, 5 sul tetto del palco, gli altri sul camminamento, al centro di ogni lato.
- Torri, dal lato del portale in senso antiorario visto dall'alto: Roccia, Gelo, Cosmico, Tempesta,
  Eclissi, Fulmine, Ossa, Gas.

### Da controllare in Studio
- Scala: il modello è in metri. `tools/modelli/prepara.js` va esteso con `ArenaDraghi: "cloud/ArenaDraghi"`.
- Passaggio dei draghi nell'arco e luce interna (le ali interne sono quasi verticali, sopra le gradinate).
- La pedana: si deve vedere dentro dall'arco. Le rampe sui gradini.
- Luci dei bracieri e degli occhi. Gli stendardi da far ondeggiare (`Arena_Stendardo_<Elemento>`).

## Modelli della mappa (priorità 2)
Non ancora fatti.
