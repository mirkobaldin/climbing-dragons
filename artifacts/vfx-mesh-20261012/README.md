# Climbing & Dragons — 36 mesh VFX

Kit modellato in Blender 5.2 dalla schermata di riferimento: forme bianche, spezzate e aperte, con strisce, spirali, sfere e punte. Gli spazi vuoti sono nella geometria; non servono texture alpha per ottenere le sagome.

36 sagome distinte: 12 generiche, 16 per gli otto elementi dei draghi, 8 per mostri e Guardiano. Da 132 a 3.864 triangoli per effetto; 47.828 triangoli nell'intero catalogo.

- `VFX_Kit_36.blend`: sorgente modificabile, 36 oggetti nella collezione `VFX_MESH_36`; fondale, camera e scritte sono nella collezione separata `ANTEPRIMA_NON_ESPORTARE`.
- `VFX_Kit_36.fbx`: tutte le mesh disposte in griglia, senza fondale, luci o etichette.
- `fbx/`: 36 export singoli, ciascuno con il proprio pivot all'origine.
- `preview/kit_36.png`: panoramica; `preview/dettaglio_1.png`–`dettaglio_3.png`: tavole ingrandite.
- `manifest.json`: catalogo con impiego, pivot, animazione suggerita, dimensioni Blender e conteggio dei triangoli.
- `validation.json`: esito della reimportazione effettiva degli FBX in Blender.

Gli oggetti sono mesh statiche pronte da animare nel gioco. Le animazioni suggerite nel catalogo non sono clip o script implementati. Nessun file del gioco in `src/` viene modificato.

## Catalogo

Ogni nome corrisponde a `fbx/<nome>.fbx`.

| Mesh | Attacco / impiego |
|---|---|
| VFX_01_Vortice | Vortice basso e carica |
| VFX_02_SpiraleConica | Spirale ascendente, stretta in alto |
| VFX_03_SferaNastri | Palla di energia a nastri |
| VFX_04_SferaFrammentata | Sfera spezzata, vicina alla reference |
| VFX_05_OndaUrto | Anello da picchiata |
| VFX_06_AnelliSpezzati | Corone concentriche discontinue |
| VFX_07_Fendente | Taglio a mezzaluna |
| VFX_08_FendenteTriplo | Tre tagli paralleli |
| VFX_09_CoronaImpatto | Corona verticale da atterraggio |
| VFX_10_Colonna | Colonna di energia a tre nastri |
| VFX_11_StellaImpatto | Lampo radiale a dodici raggi |
| VFX_12_Scia | Scia lunga curva |
| VFX_13_RocciaProiettile | Grappolo di frammenti di roccia |
| VFX_14_RocciaOnda | Onda con punte di pietra |
| VFX_15_GeloLance | Proiettile a cinque lance |
| VFX_16_GeloEruzione | Schegge di ghiaccio dal terreno |
| VFX_17_CosmicoNucleo | Nucleo con orbite inclinate |
| VFX_18_CosmicoPortale | Portale verticale a cerchi e raggi |
| VFX_19_TempestaLame | Cinque lame di vento rotanti |
| VFX_20_TempestaTornado | Tornado largo in alto |
| VFX_21_EclissiCorona | Sfera aperta con corona dentata |
| VFX_22_EclissiFalce | Falce con denti esterni |
| VFX_23_FulmineDardo | Saetta ramificata |
| VFX_24_FulmineGabbia | Sette archi elettrici intorno al bersaglio |
| VFX_25_OssaSpina | Proiettile a vertebre e costole |
| VFX_26_OssaMorso | Due arcate con zanne |
| VFX_27_GasNube | Nube cava a sette volute |
| VFX_28_GasGetto | Getto a spirale crescente |
| VFX_29_YetiArtigli | Cinque strisciate di artiglio |
| VFX_30_YetiPugno | Pugno a terra con schegge di neve |
| VFX_31_GolemFrattura | Crepe ramificate sul terreno |
| VFX_32_GolemStalagmiti | Fila di sei punte di ghiaccio |
| VFX_33_GuardianoRespiro | Grande cono di soffio aperto |
| VFX_34_GuardianoOnda | Onda doppia a sedici raggi |
| VFX_35_MostroMorso | Impronta di morso a dieci denti |
| VFX_36_MostroCoda | Spazzata orizzontale con punte |

## Importazione in Roblox Studio

1. Aprire l'Importer e selezionare il kit FBX oppure uno degli FBX singoli. Lasciare disattivata l'unione delle mesh per mantenere i 36 effetti separati. Il formato FBX e il comportamento di Merge Meshes sono descritti nella [documentazione Roblox](https://create.roblox.com/docs/studio/importer).
2. Verificare scala e orientamento nell'anteprima di importazione: in Blender l'alto e' Z; l'export dichiara Y come alto e -Z come avanti. Le direzioni indicate nel catalogo sono quelle locali del sorgente Blender. Gli effetti di terreno hanno pivot alla base; i soffi all'emettitore; le sfere al centro. Il kit e' una griglia di consultazione, gli export singoli partono dall'origine.
3. Per l'aspetto della reference usare `Material = Neon`, colore bianco o quello dell'elemento, `CanCollide = false`, `CanTouch = false`, `CanQuery = false` e ombre disattivate. Per una prima prova tenerli ancorati. Il materiale luminoso del render Blender e' una presentazione: regolare l'aspetto effettivo in Studio.
4. Tutte le forme hanno spessore geometrico sottile e UV. Non richiedono DoubleSided per vedere il retro; si puo' valutare quella proprieta' se si elimina lo spessore in una variante. Le UV dei nastri seguono lunghezza e larghezza, con isole sovrapposte intenzionalmente: adatte a maschere ripetute, non a un bake univoco dell'intera mesh. Vedere [MeshPart e UV](https://create.roblox.com/docs/reference/engine/classes/MeshPart).
5. Animare scala, rotazione e trasparenza nel sistema VFX del gioco. Indicazioni artistiche iniziali: fendenti 0,15–0,3 s; onde 0,3–0,6 s; proiettili per il tempo del volo; cariche 0,6–1,2 s. Evitare di istanziare l'intero kit per un singolo attacco.

Colori suggeriti: Roccia ambra e pietra; Gelo ciano; Cosmico viola e magenta; Tempesta azzurro e bianco; Eclissi arancio; Fulmine violetto; Ossa avorio; Gas ciano e magenta. Nessuna forma dedicata a Brace, Sole o Ombra.

Le punte e i frammenti di un effetto sono uniti in un solo oggetto per semplificare l'uso. Per animarli separatamente, duplicare il sorgente e usare Separate > By Loose Parts in Blender. La nube Gas e' una forma stilizzata a volute aperte, non un volume di fumo realistico.

## Verifica e rigenerazione

Il generatore controlla UV finite, coordinate finite, triangoli degeneri, bordi aperti, manifold e tetto di 8.000 triangoli per singola mesh. `verify_exports.py` reimporta ogni FBX e verifica nomi, triangoli, UV, dimensioni e origine; controlla anche che il kit contenga esattamente 36 mesh.

Da questa cartella, con Blender 5.2:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --python-exit-code 1 --python build_vfx.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --python-exit-code 1 --python verify_exports.py
```

Aggiungere `-- --no-render` al primo comando per ricreare solo modelli, FBX e catalogo. I controlli geometrici non sono una prova di prestazioni in gioco: Claude o Mirko devono ancora verificare importazione, scala, colori Neon, pivot e molti attacchi simultanei in Play, anche da telefono.
