# Climbing & Dragons — altre 30 mesh VFX elementali

Trenta disegni aggiuntivi, numerati 37–66. Questo set usa facce sfaccettate, nastri con cresta, punte affusolate, filamenti e bordi a contrasto. I colori fanno parte di un atlante PNG incluso negli FBX e nel file Blender.

Solo gli otto elementi attivi: Roccia, Gelo, Cosmico, Tempesta, Eclissi, Fulmine, Ossa e Gas. Quattro effetti per ognuno dei primi sei; tre per Ossa e tre per Gas.

## Aprire e usare

- `VFX_Elementali_30.blend`: sorgente modificabile in Blender 5.2; camera, luci, etichette e fondale nella collezione `SOLO_ANTEPRIMA`.
- `VFX_Elementali_30.fbx`: tutte le nuove mesh in griglia, senza elementi di presentazione.
- `fbx/`: 30 file separati con origine pronta per il posizionamento.
- `textures/VFX_Palette.png`: atlante 128x256. Le UV sono disposte nei campioni colore, quindi non sono UV da usare direttamente con texture di rumore o maschere di dissolvenza.
- `preview/30_elementali.png`: panoramica; `preview/dettaglio_1.png`–`dettaglio_4.png`: tavole ravvicinate.
- `manifest.json`: nomi, elementi, ruolo suggerito, palette, assi, pivot e conteggi.
- `CATALOGO.md`: elenco leggibile delle 30 forme con collegamenti agli FBX.
- `PER_CLAUDE.md`: istruzioni complete da passare a Claude per l'integrazione.

I file sono anche copiati, gia' estratti, in `C:\Users\mirko\Desktop\Climbing & Dragons - VFX\02 - Nuove 30 elementali`. Il primo kit da 36 e' nella cartella sorella `01 - Kit originale 36`: totale 66 effetti.

Sono forme statiche. Le animazioni descritte nel manifest sono suggerimenti per il gioco; non ci sono clip o script di attacco implementati. Gli effetti composti restano un singolo MeshPart per facilitarne il riuso. Se serve animare indipendentemente le parti, separarle nel sorgente Blender prima di riesportare.

La mesh piu' complessa ha 8.584 triangoli; il set completo ne ha 94.568. Usare solo gli effetti richiesti dall'attacco e verificare il costo di molti effetti simultanei su telefono.

Gli FBX incorporano la palette e ne viene fornita anche una copia separata. Controllare in Studio la texture, mantenere il colore della mesh bianco quando si vuole preservare la palette e regolare il materiale. In particolare i bordi arancio di Eclissi devono rimanere distinguibili dalle superfici scure. La luce del render e' solo un'anteprima; non viene trasformata automaticamente in illuminazione Roblox.

Per formato e requisiti si rimanda alle [specifiche mesh Roblox](https://create.roblox.com/docs/art/modeling/specifications) e all'[Importer](https://create.roblox.com/docs/studio/importer).

## Riproducibilita'

Da questa cartella:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --python-exit-code 1 --python build_elemental.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --python-exit-code 1 --python verify_elemental.py
```

Aggiungere `-- --no-render` al generatore per saltare le anteprime. Nessuna libreria esterna. `validation.json` documenta i controlli sugli export; le prove in Studio e su telefono devono ancora essere eseguite.
