# Climbing & Dragons — interfaccia v3

Consegna del 15 ottobre 2026, ramo `codex/ui-rifacimento-20261014`, worktree `C:/Users/mirko/Desktop/RObloxGame-codex`.

50 PNG trasparenti nuovi: 29 icone dedicate, 15 pulsanti e 6 schede. Le immagini precedenti e i relativi ID sono conservati. I collegamenti nei controller sono implementati; i 50 ID nuovi in `src/shared/UiAssets.luau` sono volutamente vuoti, come richiesto. Il caricamento su Roblox e la prova in Studio spettano a Claude.

## Aprire la consegna

- [Catalogo illustrato](anteprima.png): tutti i 50 asset.
- [Anteprima navigabile](preview.html): scelta fra le otto schermate a 1920x1080 e 844x390.
- [Cartella delle tavole](screens/).
- [Manifest](manifest.json): nomi, misure, slice e prompt originali.
- [Verifiche PNG](png-checks.json), [geometria](layout-checks.json), [345 misure tipografiche](text-checks.json).

Le tavole sono **render locali illustrativi, non screenshot di Roblox**. Usano i PNG consegnati e il font locale Montserrat Black (GothamBlack in Roblox). I testi principali vengono estratti da ClimbConfig, Names, Gear, ShopConfig e UpgradeConfig; i valori dinamici sono esempi di impaginazione. Gli effettivi modelli dei draghi e le icone dei drop si trovano nel place e vanno verificati in Studio. Le tavole mostrano l'inizio delle liste: il contenuto continua scorrendo.

## Cosa cambia nel gioco

- Palette centralizzata in Theme: azzurro, turchese, lime, giallo, arancio, fragola, viola e rosa; pannelli blu medio.
- Barra superiore sempre sopra le finestre, sei colonne in orizzontale e tre nel ritratto. Controlli non ridotti sotto 44 px dalla scala globale.
- Pulsanti semantici verdi/rossi/oro/blu/grigio con normal, hover e pressed; selezione schede oro/blu. Il ripiego senza ID usa colori e testi nativi.
- Testi dichiarativi con padding, dimensioni adattive e minimo 12; etichette dei pulsanti su una riga. Contenuti lunghi nei pannelli scorrevoli.
- Travel: cinque destinazioni fisse nei JSON, campi scoperti in lista, icona pertinente, distanza contenuta, stato bloccato e badge 60 s. Nomi inviati al server invariati.
- Draghi: Grade fra le statistiche, Power, Level, reddito, attacco in monta/evoluzione; riquadro Special ability preso dalla configurazione. Icona abilita' nelle tessere, testo nel nido/schiusa. Cornice shiny arcobaleno; script rimossi dai cloni delle anteprime.
- Nuova barra attrezzi dell'HUD: icona sopra il nome, selezione con click/tocco e tasti 1-9, stessi Tool e Humanoid esistenti. I nomi dei quattro Tool provengono da ClimbConfig. Il backpack grafico di Roblox viene nascosto per evitare due barre.
- HUD e comandi mobili si nascondono quando i menu occupano lo schermo. Il codice delle azioni mobili, i remoti, prezzi e dati di progressione non sono cambiati.

## Per Claude

1. Esaminare il ramo e integrare secondo il flusso di lavoro del progetto. Non avviare Rojo da questa copia.
2. Caricare i **50 PNG elencati sotto**, mantenendo gli stessi nomi, e inserire gli ID nelle nuove chiavi di UiAssets. Non sostituire gli ID vecchi. Le icone usano Fit, pulsanti e schede Slice.
3. Provare in Studio con `nosave` sul server: 1920x1080, 1366x768, 844x390 e 390x844; aggiungere `SimViewport = Vector2.new(844, 354)` e `SimTouch = true`.
4. Aprire Shop/Backpack/Dragons/Crafting/Upgrades/Travel con tasti e barra. Verificare scorrimento, testo, selezione e hover/pressed, anche con ID temporaneamente vuoti.
5. Verificare Buy/Sell/Craft, Rebirth pronto/non pronto/conferma, Follow/Rest, Evolve/Ride e conferma Sell. Nessuna pubblicazione eseguita da Codex.
6. In Travel provare nessun drago, fuori da un waypoint, casa con 60 s, Dragon Island e molti campi base.
7. Con Cosmico verificare la scritta del doppio salto; con Fulmine il testo lungo; controllare tutti i gradi, adulti/cuccioli, shiny, nido e schiusa.
8. Verificare la nuova barra Tool: 1-4, cambio con click/tocco, disequipaggiamento, respawn, strumenti aggiunti/rimossi, eventuali Tool extra con scorrimento, compatibilita' con arrampicata e monta.
9. Verificare i modelli dei drop da ReplicatedStorage.DropIcone e i ViewportFrame dei draghi: non sono disponibili nel repo.

## Verifiche locali

- Build Rojo del progetto completo.
- Compilazione Luau dei file modificati.
- Test UiView: riuso delle ScreenGui, ripiego, caricamento tardivo, cambio ruolo/stato, rimozione superficie quando l'ID manca e assenza di didascalie duplicate.
- 107 testi e 41 pulsanti nei JSON; geometria in cinque viewport.
- 345 misure delle stringhe reali con il font del gioco, nessuna eccedenza nei casi controllati.
- 50 PNG con alpha trasparente e bordi esterni vuoti; 16 tavole di schermata e catalogo ispezionati.

Queste verifiche non simulano completamente il layout/rendering di Roblox: il controllo finale in Play resta necessario.

Rigenerazione delle verifiche:

```powershell
node tools/ui/sync-fallback.mjs
node tools/ui/check-ui.mjs C:/Users/mirko/AppData/Local/Temp/climbing-ui-luau/luau.exe
node tools/ui/test-view.mjs C:/Users/mirko/AppData/Local/Temp/climbing-ui-luau/luau.exe
node tools/ui/preview-v3.mjs
```

`prepare.ps1` esporta le sorgenti generate indicate in sources.json: crop alpha, proporzioni delle icone conservate, dimensioni finali, normalizzazione della zona allungabile e controllo dei bordi. I file sorgente originali sono nella cartella locale di immagini generate da Codex; i PNG finali qui sono autonomi.

## Indice PNG

Slice indicato come `Rect.new(x1, y1, x2, y2)`; margini esterni dei pulsanti 4 px, icone almeno 12 px. Le immagini non contengono testi.

| File | Misura | Slice | Uso |
|---|---|---|---|
| [item_Ramponi.png](item_Ramponi.png) | 256×256 | — (Fit) | Icona dedicata: Ramponi |
| [item_Tuta.png](item_Tuta.png) | 256×256 | — (Fit) | Icona dedicata: Tuta |
| [item_Rampino.png](item_Rampino.png) | 256×256 | — (Fit) | Icona dedicata: Rampino |
| [item_PiccoRinforzato.png](item_PiccoRinforzato.png) | 256×256 | — (Fit) | Icona dedicata: PiccoRinforzato |
| [item_Parapendio.png](item_Parapendio.png) | 256×256 | — (Fit) | Icona dedicata: Parapendio |
| [item_Sella.png](item_Sella.png) | 256×256 | — (Fit) | Icona dedicata: Sella |
| [item_Chiodi.png](item_Chiodi.png) | 256×256 | — (Fit) | Icona dedicata: Chiodi |
| [item_Torcia.png](item_Torcia.png) | 256×256 | — (Fit) | Icona dedicata: Torcia |
| [item_Bende.png](item_Bende.png) | 256×256 | — (Fit) | Icona dedicata: Bende |
| [item_Pitons.png](item_Pitons.png) | 256×256 | — (Fit) | Icona dedicata: Pitons |
| [item_Medkit.png](item_Medkit.png) | 256×256 | — (Fit) | Icona dedicata: Medkit |
| [item_Thermos.png](item_Thermos.png) | 256×256 | — (Fit) | Icona dedicata: Thermos |
| [item_MysteryEgg.png](item_MysteryEgg.png) | 256×256 | — (Fit) | Icona dedicata: MysteryEgg |
| [item_RareEgg.png](item_RareEgg.png) | 256×256 | — (Fit) | Icona dedicata: RareEgg |
| [item_Piccozza.png](item_Piccozza.png) | 256×256 | — (Fit) | Icona dedicata: Piccozza |
| [item_Piccone.png](item_Piccone.png) | 256×256 | — (Fit) | Icona dedicata: Piccone |
| [item_TravelHub.png](item_TravelHub.png) | 256×256 | — (Fit) | Icona dedicata: TravelHub |
| [item_TravelHome.png](item_TravelHome.png) | 256×256 | — (Fit) | Icona dedicata: TravelHome |
| [item_TravelArena.png](item_TravelArena.png) | 256×256 | — (Fit) | Icona dedicata: TravelArena |
| [item_TravelGym.png](item_TravelGym.png) | 256×256 | — (Fit) | Icona dedicata: TravelGym |
| [item_TravelIsland.png](item_TravelIsland.png) | 256×256 | — (Fit) | Icona dedicata: TravelIsland |
| [item_TravelCamp.png](item_TravelCamp.png) | 256×256 | — (Fit) | Icona dedicata: TravelCamp |
| [item_UpgradeRampino.png](item_UpgradeRampino.png) | 256×256 | — (Fit) | Icona dedicata: UpgradeRampino |
| [item_UpgradeUncino.png](item_UpgradeUncino.png) | 256×256 | — (Fit) | Icona dedicata: UpgradeUncino |
| [item_UpgradeLancio.png](item_UpgradeLancio.png) | 256×256 | — (Fit) | Icona dedicata: UpgradeLancio |
| [item_UpgradeEsoscheletro.png](item_UpgradeEsoscheletro.png) | 256×256 | — (Fit) | Icona dedicata: UpgradeEsoscheletro |
| [item_UpgradeScudo.png](item_UpgradeScudo.png) | 256×256 | — (Fit) | Icona dedicata: UpgradeScudo |
| [item_UpgradeStivali.png](item_UpgradeStivali.png) | 256×256 | — (Fit) | Icona dedicata: UpgradeStivali |
| [item_UpgradePicchiata.png](item_UpgradePicchiata.png) | 256×256 | — (Fit) | Icona dedicata: UpgradePicchiata |
| [btn_buy_v3_normal.png](btn_buy_v3_normal.png) | 512×160 | 64, 48, 448, 112 | Pulsante buy · normal |
| [btn_buy_v3_hover.png](btn_buy_v3_hover.png) | 512×160 | 64, 48, 448, 112 | Pulsante buy · hover |
| [btn_buy_v3_pressed.png](btn_buy_v3_pressed.png) | 512×160 | 64, 48, 448, 112 | Pulsante buy · pressed |
| [btn_sell_v3_normal.png](btn_sell_v3_normal.png) | 512×160 | 64, 48, 448, 112 | Pulsante sell · normal |
| [btn_sell_v3_hover.png](btn_sell_v3_hover.png) | 512×160 | 64, 48, 448, 112 | Pulsante sell · hover |
| [btn_sell_v3_pressed.png](btn_sell_v3_pressed.png) | 512×160 | 64, 48, 448, 112 | Pulsante sell · pressed |
| [btn_main_v3_normal.png](btn_main_v3_normal.png) | 512×160 | 64, 48, 448, 112 | Pulsante main · normal |
| [btn_main_v3_hover.png](btn_main_v3_hover.png) | 512×160 | 64, 48, 448, 112 | Pulsante main · hover |
| [btn_main_v3_pressed.png](btn_main_v3_pressed.png) | 512×160 | 64, 48, 448, 112 | Pulsante main · pressed |
| [btn_alt_v3_normal.png](btn_alt_v3_normal.png) | 512×160 | 64, 48, 448, 112 | Pulsante alt · normal |
| [btn_alt_v3_hover.png](btn_alt_v3_hover.png) | 512×160 | 64, 48, 448, 112 | Pulsante alt · hover |
| [btn_alt_v3_pressed.png](btn_alt_v3_pressed.png) | 512×160 | 64, 48, 448, 112 | Pulsante alt · pressed |
| [btn_off_v3_normal.png](btn_off_v3_normal.png) | 512×160 | 64, 48, 448, 112 | Pulsante off · normal |
| [btn_off_v3_hover.png](btn_off_v3_hover.png) | 512×160 | 64, 48, 448, 112 | Pulsante off · hover |
| [btn_off_v3_pressed.png](btn_off_v3_pressed.png) | 512×160 | 64, 48, 448, 112 | Pulsante off · pressed |
| [tab_on_v3_normal.png](tab_on_v3_normal.png) | 384×112 | 56, 36, 328, 76 | Scheda selezionata · normal |
| [tab_on_v3_hover.png](tab_on_v3_hover.png) | 384×112 | 56, 36, 328, 76 | Scheda selezionata · hover |
| [tab_on_v3_pressed.png](tab_on_v3_pressed.png) | 384×112 | 56, 36, 328, 76 | Scheda selezionata · pressed |
| [tab_off_v3_normal.png](tab_off_v3_normal.png) | 384×112 | 56, 36, 328, 76 | Scheda secondaria · normal |
| [tab_off_v3_hover.png](tab_off_v3_hover.png) | 384×112 | 56, 36, 328, 76 | Scheda secondaria · hover |
| [tab_off_v3_pressed.png](tab_off_v3_pressed.png) | 384×112 | 56, 36, 328, 76 | Scheda secondaria · pressed |

## Tavole per schermata

| Schermata | Computer | Telefono |
|---|---|---|
| HUD | [1920×1080](screens/HUD-1920x1080.png) | [844×390](screens/HUD-844x390.png) |
| Shop | [1920×1080](screens/Shop-1920x1080.png) | [844×390](screens/Shop-844x390.png) |
| Backpack | [1920×1080](screens/Backpack-1920x1080.png) | [844×390](screens/Backpack-844x390.png) |
| Dragons | [1920×1080](screens/Dragons-1920x1080.png) | [844×390](screens/Dragons-844x390.png) |
| Crafting | [1920×1080](screens/Crafting-1920x1080.png) | [844×390](screens/Crafting-844x390.png) |
| Upgrades | [1920×1080](screens/Upgrades-1920x1080.png) | [844×390](screens/Upgrades-844x390.png) |
| Travel | [1920×1080](screens/Travel-1920x1080.png) | [844×390](screens/Travel-844x390.png) |
| Death | [1920×1080](screens/Death-1920x1080.png) | [844×390](screens/Death-844x390.png) |

