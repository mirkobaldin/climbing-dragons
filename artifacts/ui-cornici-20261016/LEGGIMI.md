# Cornici UI — da approvare

Branch `codex/ui-cornici-20261016`. Nessun file del gioco modificato, nessun upload.
Illustrazioni e varianti create con lo strumento **image_gen integrato**. Prompt originali
in `prompt.json`, modifiche e stati in `prompt_varianti.json`.

## Cosa guardare

- `anteprima_telefono_891x353.png`: HUD e menu montati alla risoluzione richiesta.
- `anteprima_computer_1920x1080.png`: stessa famiglia di elementi su computer.
- `catalogo_pezzi.png`: tutti i venti pezzi e i due livelli da tingere del ritratto drago.
- `catalogo_stati.png`: confronto normal/hover/pressed/selected/valid/disabled dove previsti.

Le anteprime usano esattamente i PNG della consegna con testo fittizio in inglese. Lo sfondo
e' schematico; i cerchi PLAYER/FROST sostituiscono i ViewportFrame. Per questa prova locale
sono usati Bahnschrift e Segoe UI, disponibili sul PC: nell'integrazione restano Oswald e
Titillium Web di UiKit. Non sono screenshot di Roblox e non attestano prove in Play.

## File da integrare dopo il si' di Mirko

`png/` contiene 32 immagini per i 20 id principali e i loro stati, piu' i due livelli da
tingere e le sezioni del separatore. I file sono RGBA a risoluzione 2x, con lati multipli
di quattro. I file di `originali/` sono sorgenti ad alta risoluzione e NON vanno caricati
al posto dei PNG confezionati. Le versioni `_v1` dei ritratti sono conservate solo come
storia delle correzioni: avevano il foro troppo piccolo.

`manifest.json` indica per ciascun id:

- `file`, `size` e `usage_size`;
- `slice` = margini **in pixel del PNG 2x**, nell'ordine `[left, top, right, bottom]`;
- `free_rect` = `[x, y, width, height]`, sempre nei pixel del PNG;
- `free_circle` per i ritratti: centro effettivo e diametro disponibile;
- `states` con file e rettangolo libero di ogni stato;
- `tint_layers` o `layers` per i pezzi da sovrapporre separatamente.

Per Roblox: `SliceCenter = Rect.new(l, t, width-r, height-b)`, **SliceScale = 0.5** alla
misura d'uso. Non passare i quattro margini direttamente a Rect.new. Conservare i lati
ornati nei margini fissi e allungare solo i tratti semplici. I terminali delle barre sono
montati per lasciare un canale sufficientemente alto senza separare i raccordi.

Ritratti, medaglioni e ornamento della morte: sola scala uniforme. Le schede hanno il lato
sinistro verticale e il solo lato destro obliquo: si allungano in larghezza mantenendo
fisso il terminale destro. Non deformarle verticalmente. Il separatore estensibile si monta
con `frame_separator_left`, `frame_separator_gem`, `frame_separator_right`: la gemma centrale
mantiene la sua dimensione. Il PNG completo e' disponibile per la misura nativa.

I fori utili sono di 96 px (giocatore), 84 px (drago), 40 px (valuta) alle misure d'uso.
I centri effettivi sono nel manifest e non vanno dedotti dal centro della cresta esterna.
La tessera record riserva 64x64 px per l'icona. Il fondo interno del pannello e' carbone
uniforme con alfa 235/255. Le gemme e il filo rarita' sono livelli grigi separati; il
riempimento barre e' anch'esso grigio e si colora con ImageColor3.

## Rigenerazione tecnica

Le immagini artistiche originali restano immutate. Gli script eseguono ritaglio, montaggio
delle parti, registrazione dei livelli, dimensionamento, pulizia dell'alfa e catalogazione.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' confeziona.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' anteprime.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' catalogo.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' valida.py
```

Dipendenze locali gia' disponibili nel Python di Blender: Pillow e NumPy. Il risultato
dei controlli e' `verifica.json`: misure, alfa, margini, inventario degli stati, aperture,
vano icona, livelli grigi e dimensioni delle due anteprime.

Claude dovra' verificare in Studio dopo l'approvazione: registrazione dei ViewportFrame
nei cerchi, 9-slice alle larghezze reali, cambio degli stati senza salti, ritaglio dei
riempimenti, tintura delle gemme e rarita', testi Oswald/Titillium Web e leggibilita' su
telefono. Caricamento Roblox e aggiornamento di UiAssets restano a Claude.
