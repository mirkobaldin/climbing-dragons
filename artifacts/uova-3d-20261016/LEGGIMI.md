# Uova v6 — rifinitura delle ali e consegna

Il 17/10 Mirko ha detto **"possono andare bene"** e chiesto di migliorare la texture
delle ali come nelle foto. La base v5 resta: otto elementi, colori, scaglie sporgenti,
ali aperte, gemma unica irregolare e Ossa al posto del bianco/oro. La rifinitura cambia
i materiali delle membrane e aggiunge UV dedicate, senza cambiare le loro forme.

## Anteprime

- `FOGLIO_V6.png`: otto uova; prima riga Roccia/Gelo/Tempesta/Fulmine, seconda
  Eclissi/Ossa/Cosmico/Gas. Sotto dettagli Roccia e Ossa.
- `DETTAGLI_ALI.png`: le otto ali ravvicinate nello stesso ordine.
- Versioni leggere con suffisso `_preview.jpg`; singoli render in `render/`.
- `render/IMPORT_Roccia.png`: controllo dal FBX reimportato e dalle mappe esportate.
- `render/FRAMMENTI_Roccia.png`: gli stessi dieci frammenti separati per controllo.

Venature ramificate originate dal polso e dalle nervature, aloni graduati, fibre
longitudinali e pori sottili. Le membrane presentano variazioni di colore e ruvidita'
e traslucenza nel materiale Blender. Gelo e fulmini hanno filamenti piu' luminosi;
Cosmico nebulose e stelle; Gas variazioni ciano/fucsia; Ossa pelle scura e porosa.
La presentazione accesa usa anche emissione e compositing, separati dalle mesh.

## File per Claude

`manifest.json` elenca per ogni elemento FBX, texture, nomi dei gruppi, triangoli e
pivot. `fbx/Uovo_<id>.fbx` contiene due gruppi **alternativi**, sovrapposti all'origine:

- `Uovo_<id>_Intero`: cinque mesh, incluso `_Luce` separato.
- `Uovo_<id>_Frammenti`: dieci frammenti, otto porzioni del guscio con gemma/decori
  assegnati e due ali. Ogni frammento ha il pivot al centro del proprio ingombro.

**Nascondere il gruppo Frammenti all'avvio**; mostrarlo solo alla rottura e nascondere
l'intero, incluso Luce. Il FBX registra `VisibleAtStart=false` come proprieta'
descrittiva; non presume che l'importatore Roblox la applichi automaticamente.
Le scaglie sono solidi chiusi; la frammentazione le raggruppa senza tagliarle a meta'.

Per ciascun elemento, `textures/Uovo_<id>/body/` e `textures/Uovo_<id>/wings/`
contengono ciascuna cinque mappe 1024 x 1024. Le ali hanno un atlante dedicato, con
spazio riservato a fronte e retro delle membrane, per conservare le venature sottili.
Sono 80 PNG in totale (64 mappe PBR e 16 guide di emissione).

| Mappa | Uso |
|---|---|
| color.png | Colore sRGB |
| normal.png | Normale tangente, dati lineari |
| roughness.png | Ruvidita', dati lineari |
| metalness.png | Metallicita', dati lineari |
| emission.png | Guida aggiuntiva sRGB; intensita' normalizzata per 8 |

Le mappe PBR usano `UV_Export`. Il campo `texture_set` del manifest specifica se una
mesh usa `body` o `wings`; i frammenti riutilizzano lo stesso atlante dell'intero.
La guida emissione conserva dove si trovano i dettagli luminosi. La
traslucenza fisica del materiale sorgente e il glow del render non fanno parte delle
quattro mappe PBR: l'integrazione deve gestire separatamente Luce e dettagli emissivi.
Non usare `color.png` come se includesse gia' luci, riflessi o alone della presentazione.

Unita' sorgente: stud, Z in alto; FBX esportato Y in alto. Guscio 2 x 2 x 2,6 studs,
ali oltre l'ingombro del guscio. Nel manifest i pivot e gli ingombri sono espressi
nelle coordinate sorgenti; il reimport FBX verifica che scala e trasformazioni restino
equivalenti. Ogni mesh intera e ogni frammento resta entro 15.000 triangoli.

## Riproducibilita'

Blender 5.2.2 LTS. Nessuna immagine della reference e' stata incollata sul modello:
`materiali_ali.py` sintetizza le venature e costruisce lo shader; `consegna.py` esegue
UV, bake e FBX. `uova.blend` conserva i materiali sorgenti e le immagini tecniche
incorporate. Gli otto modelli sono sovrapposti; Roccia e' quello abilitato nel render.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python uova.py -- --samples 96 --export
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python verifica_fbx.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python prova_import.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' foglio.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' verifica.py
```

`--only Roccia` limita render/export a quell'elemento; `--no-render --export` rigenera
soltanto la consegna. `verifica_geometria.json` controlla il modello sorgente;
`verifica_fbx.json` controlla gli otto file reimportati: nomi, triangoli, UV e pivot.

Da verificare in Studio: ingombro nel nido, ritaglio delle ali durante la schiusa,
orientamento delle normal map, luminosita' delle crepe e attivazione dei dieci
frammenti. Nessun upload o modifica in `src/` eseguito da Codex.
