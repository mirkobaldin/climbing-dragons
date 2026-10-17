# Compito: mostri a tema drago per ogni bioma e i loro drop

Scritto il 17/10 (sessione cloud). Mirko: "Codex aveva fatto tutti i vari drop su Blender ma non
sono stati inseriti perche' mancavano i modelli 3D dei nemici che li droppano; magari ci stava
fare uno o due mostri per ogni bioma a tema drago". In piu' le vele del parapendio (Dragon Wings,
Storm Wyvern Wings) devono costare materiali dei mostri (oggi hanno costi provvisori).

## Oggi nel gioco
- Nemici: solo `Yeti` (neve in quota) e `GolemGhiaccio` (ghiacciai e grotte di ghiaccio), piu'
  i capi nelle tane (`EnemyConfig.BOSSES`) e i draghi volanti (`server/Flyers`).
- Dati: `src/shared/EnemyConfig.luau` (statistiche), spawn in `server/Enemies` (`spawnFor`:
  quota e materiale del terreno), drop in `server/Drops` (`Drops.TABLE`, `Drops.BOSS`,
  `Drops.NAMES`, modelli in `ServerStorage.Modelli.Drop`), materiali dei mostri in
  `Gear.MONSTER_MATERIALS`, ricette e potenziamenti in `shared/Gear` e `shared/UpgradeConfig`.
- Modelli in `ServerStorage.Nemici` (nel file del place, non nel repo), scheletro **Mixamo**
  (`mixamorig:Hips`...): le animazioni (cammina, fermo, attacco) le genera
  `MapGen.AnimNemici` da Studio. Rig per l'Animation Editor in `Workspace.RigNemici`.
- Biomi (`src/mapgen/Config.luau`, BIOMES): bosco fino al 20% dell'altezza, prati alpini fino
  al 33%, roccia e neve dal 42%, ghiacciai dal 62%; poi grotte, valle dei gas, laghi, isole.

## I mostri (proposta: Mirko sceglie, almeno uno per bioma per il lancio)
Tutti "a tema drago" ma NON draghi da collezione (quelli sono gli 8 elementi): rettili, viverne
selvatiche, creature con scaglie. Niente Brace/Sole/Ombra.
| Bioma (quota) | Mostro (id) | Nome a schermo | Com'e' | Drop (id: nome) |
|---|---|---|---|---|
| Bosco (0-20%) | `DrakeMuschio` | Mossback Drake | lucertolone a quattro zampe con muschio e funghi sulla schiena, morde | `Scaglia_Muschio`: Moss Scale |
| Prati alpini (20-33%) | `Coboldo` | Scaleclaw Kobold | coboldo bipede con scaglie e lancia d'osso, in gruppi di 2-3 | `Zanna_Coboldo`: Kobold Fang |
| Pareti di roccia (33-62%) | `ViverneRupe` | Cliff Wyvern | viverna che si aggrappa alle pareti e piomba sugli scalatori | `Membrana_Viverna`: Wyvern Membrane |
| Neve (42-62%) | `Yeti` (c'e') | Yeti | — | `Pelliccia_Yeti`, `Cristallo_Ghiaccio` (ci sono) |
| Ghiacciai (62%+) | `GolemGhiaccio` (c'e') + `WyrmCristallo` | Crystal Wyrm | serpente di ghiaccio senza ali che esce dai crepacci | `Scaglia_Gelo`: Frost Scale |
| Grotte | `DrakeGrotta` | Cave Drake | drago cieco delle grotte, sputa scintille, vive al buio | `Ghiandola_Fuoco`: Ember Gland |
| Valle dei gas | `BasiliscoGas` | Gas Basilisk | basilisco con creste velenose, nube verde | `Sacca_Veleno`: Venom Sac |
| Alta quota / tempesta (80%+) | `ViverneTempesta` | Storm Wyvern | viverna con fulmini sulle ali, solo col brutto tempo | `Nucleo_Tempesta`: Storm Core |

**Costi delle vele dopo i mostri** (da mettere in `shared/Gear` al posto dei provvisori):
- Dragon Wings (`VelaDrago`): Membrana_Viverna 6, Scaglia_Muschio 4, Oro 6
- Storm Wyvern Wings (`VelaTempesta`): Nucleo_Tempesta 3, Membrana_Viverna 6, Scaglia_Gelo 4, Cosmico 4
Gli altri drop vanno in potenziamenti e ricette (proposta di Codex, bilanciata con le quote).

## Chi fa cosa
**Codex** (branch `codex/mostri-biomi`):
1. Una scheda per mostro in `cloud/Mostri/<Id>/SCHEDA.md`: a cosa serve, misure rispetto al
   personaggio (alto 5 stud), 3 riferimenti descritti a parole, palette di 5 colori, attacco.
2. **Modelli organici: NON con le primitive** (`docs/CLOUD_SESSIONE.md` 2.4). Prompt Meshy
   (text-to-3D con texture PBR) in `cloud/Mostri/<Id>/MESHY_PROMPT.md`: posa a T o A, bipedi o
   quadrupedi, faccia leggibile da lontano, sotto 15.000 triangoli. Mirko li genera.
3. I drop gia' fatti in Blender: mettili in `cloud/Drop/<Id>/` (FBX + anteprima) e controlla
   che i nomi siano quelli della tabella (o aggiorna la tabella).
4. Codice (senza Studio): voci in `EnemyConfig.TYPES` (statistiche scalate per quota come gli
   altri), regola di spawn per ognuno in `server/Enemies.spawnFor` (bioma = quota + materiale del
   terreno; la viverna sulle pareti ripide; quella della tempesta solo con `workspace.Weather` =
   Storm/Thunderstorm), `Drops.TABLE`/`Drops.BOSS`/`Drops.NAMES`, `Gear.MONSTER_MATERIALS`,
   ricette e costi. Se il modello non c'e' in `ServerStorage.Nemici` il mostro NON deve comparire
   (nessun errore).
5. Icone dei drop nello stile di `docs/CODEX_ICONE_V2.md` (512x512).

**Mirko**: genera i modelli con Meshy dai prompt e li mette in `cloud/Mostri/<Id>/meshy/`.

**Claude in locale**: rig Mixamo (o auto-rig di Meshy con nomi `mixamorig:`), import in
`ServerStorage.Nemici` e `Workspace.RigNemici`, `AnimNemici.genera("<Id>")`, prova in Play
(spawn nel bioma giusto, attacco, drop, ricetta della vela), poi unione in `main`.
