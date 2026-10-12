# Consegna a Claude — nuove mesh VFX di Climbing & Dragons

Mirko chiede di usare le nuove mesh negli attacchi dei draghi e dei mostri. I file sono gia' sul suo computer, estratti e pronti da importare.

## Dove sono

Cartella visibile: `C:\Users\mirko\Desktop\Climbing & Dragons - VFX`.

- `01 - Kit originale 36`: le prime 36 mesh, file Blender, FBX singoli, kit e anteprime.
- `02 - Nuove 30 elementali`: altre 30 mesh, numeri 37–66, con atlante colori, sorgente Blender, FBX singoli, kit e anteprime.
- `LEGGIMI - PER CLAUDE.md`: copia di questa consegna.

Sorgenti nel worktree Codex:

- `C:\Users\mirko\Desktop\RObloxGame-codex\artifacts\vfx-mesh-20261012`
- `C:\Users\mirko\Desktop\RObloxGame-codex\artifacts\vfx-elementali-30-20261012`

Branch `codex/vfx-elementali-30-20261012`: include entrambi i kit, poiche' deriva dal precedente `codex/vfx-mesh-20261012`. Non occorre unire due volte i commit del vecchio kit. Verificare lo stato di main prima dell'unione. Codex non ha modificato `src/` e non ha caricato asset su Roblox.

## Lavoro richiesto in Studio e nel gioco

1. Leggi `AGENTS.md`, `LAVORI.md` e i cataloghi `manifest.json` dei due kit. Guarda le anteprime prima di scegliere i modelli.
2. Importa i file con l'Importer di Studio, preservando i nomi `VFX_01_...`–`VFX_66_...` e mantenendo gli effetti separati. `VFX_Elementali_30.fbx` include le 30 nuove mesh; `fbx/` contiene gli export individuali con pivot all'origine. Le griglie dei kit servono per consultazione, non sono una disposizione da inserire nella mappa.
3. Le nuove 30 hanno un solo materiale e UV su `textures/VFX_Palette.png` (128x256, incluso anche negli FBX). Verifica che la texture venga importata e assegnata; se manca, carica il PNG e assegnalo alla texture della mesh. Mantieni il colore base bianco per non alterare la palette. Regola Neon, trasparenza e luminosita' in Studio: il render Blender non garantisce una resa identica.
4. Nel repo esiste gia' `src/client/VFXKit.luau`: legge `ReplicatedStorage.VFXLib.Mesh`, `VFXKit.part(name, size)` clona una mesh e `VFXKit.mesh(name, cf, opts)` la anima. Usa questa struttura esistente dopo aver importato le mesh come MeshPart. I nomi nuovi non sono ancora istanze del place: non dare per scontato che esistano prima dell'importazione.
5. Imposta i template VFX senza collisioni, touch, query e ombre; ancorati per gli effetti animati via CFrame. Controlla scale e orientamento dopo l'importazione. Il catalogo indica assi e pivot del sorgente Blender (alto Z); l'FBX dichiara alto Y. Per onde a terra, orienta la mesh sulla normale del terreno.
6. Collega le mesh agli eventi e alle animazioni reali degli attacchi. Il repo ha gia' `src/client/DragonVFX.luau`, in particolare `DragonVFX.shot(element, from, to, color)` e l'helper `rider`: parti da questi percorsi per i proiettili. `rider` assegna attualmente `m.Color = color`: per le nuove mesh con atlante conserva il bianco, oppure la palette verra' moltiplicata per la tinta dell'elemento. Usa effetti distinti per carica, proiettile/soffio, impatto e speciale; non visualizzare tutto il catalogo a ogni attacco. Per rotazioni complete evita un unico tween verso una CFrame equivalente: aggiorna la rotazione durante la vita dell'effetto.
7. I colori incorporati distinguono Roccia, Gelo, Cosmico, Tempesta, Eclissi, Fulmine, Ossa e Gas. Non aggiungere Brace, Sole o Ombra. Gas resta ciano e magenta. Le forme sono statiche: movimento, dissolvenza, sincronizzazione del danno e suoni vanno collegati nel sistema client.
8. Prova in Play soffi, speciali, artigli, morso, impatti e attacchi simultanei. Verifica anche telefono, pulizia degli effetti a fine vita e riuso dei template. Non rigenerare la mappa per questo kit.

## Prima associazione suggerita

| Elemento | Carica / speciale | Proiettile / soffio | Impatto / taglio |
|---|---|---|---|
| Roccia | 37 CuoreFratturato | 40 Ariete | 38 ArtiglioTellurico, 39 FagliaRadiale |
| Gelo | 42 SigilloEsagonale | 41 LanciaAurora | 43 LotoGlaciale, 44 AlaTagliente |
| Cosmico | 45 Astrolabio, 48 StellaDimensionale | 47 CometaAstrale | 46 DiscoAccrescimento |
| Tempesta | 50 CicloneSpirale | 52 OcchioUragano | 49 AliBurrasca, 51 RasoioEolico |
| Eclissi | 53 SoleNero | 56 SerpenteSolare | 54 LamaApocalisse, 55 NovaOscura |
| Fulmine | 59 SferaTesla | 57 LanciaRamificata | 58 ArtiglioTuono, 60 ReteParalizzante |
| Ossa | 63 SpiraleVertebre | 25 OssaSpina dal kit originale | 61 FauciDraconiche, 62 ArtiglioScheletrico |
| Gas | 64 LotoMiasma | 65 BollaVorticosa, 66 SoffioSerpentino | 27 GasNube dal kit originale |

Per yeti, golem e Guardiano il kit originale include le forme 29–36. I nomi esatti completi e i file si trovano nei manifest; i numeri della tabella sono riferimenti al catalogo, non ID Roblox.

## Cosa e' stato verificato

Codex ha modellato e renderizzato i sorgenti in Blender 5.2, reimportato gli FBX e controllato nomi, triangoli, UV, dimensioni e pivot. Per le nuove 30 verifica anche la presenza effettiva della texture negli FBX e l'assenza di bordi aperti. I report sono `validation.json`. Importazione su Roblox, ID degli asset, animazioni e prestazioni in Play restano da verificare da Claude/Mirko.
