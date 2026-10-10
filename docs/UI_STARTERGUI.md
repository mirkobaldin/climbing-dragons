# Climbing & Dragons ? consegna StarterGui

Branch: codex/ui-startergui. Le immagini del primo compito sono gia in main; questo branch collega struttura, controller e registro degli ID. Nessun upload Roblox, merge in main o test Play eseguito da Codex.

## Struttura modificabile

StarterGui contiene MainMenu, ClimbHUD, DeathScreen, Teletrasporto, MobileControls, CombatHUD e Caricamento. Ogni cartella in src/gui ha init.meta.json e figli model.json. MainMenu/Window/Content contiene Store, Backpack, Dragons, Crafting e Upgrades; MainMenu/Templates contiene le carte clonabili, nascoste nell'originale. Per vedere una finestra in Studio abilitarne Visible temporaneamente; DeathScreen e Caricamento hanno anche Enabled=false.

I nomi dei nodi sono il contratto dei controller: cambiare colori, testi statici, proporzioni dei figli e cornici; non rinominare i nodi senza aggiornare i riferimenti. Le posizioni dei pannelli principali sono adattate dai controller quando cambia il viewport. Riportare nel repo le modifiche fatte in Studio prima della sincronizzazione successiva.

Dopo ogni modifica ai JSON eseguire:

    node tools/ui/sync-fallback.mjs

Il modulo generato src/shared/UiFallback.luau ricrea le stesse schermate se mancano nel place. UiView attende PlayerGui con timeout, riusa una GUI gia esistente, clona StarterGui se disponibile e solo infine costruisce il ripiego. ResetOnSpawn=false e controllo della replica tardiva evitano GUI duplicate. Senza ID si mantengono Frame, UICorner, UIStroke, testi e anteprime 3D; con ID si applicano immagini e margini slice dell'indice del primo compito.

Il formato dei modelli e dei metadati segue la [documentazione Rojo](https://rojo.space/docs/v7/sync-details/).

## Verifiche locali

- Build Rojo 7.7.0 riuscita, con tutte e sette le ScreenGui nel place esportato temporaneamente.
- Compilazione sintattica dei file Luau modificati con il compilatore ufficiale Luau 0.742. Questa verifica non e una verifica dei tipi Roblox in Studio.
- tools/ui/test-view.mjs: riuso della GUI, ripiego senza StarterGui, copia tardiva, ID vuoti e sconosciuti, modelli clonati, superficie unica, aggiornamento delle didascalie e apertura.
- tools/ui/check-ui.mjs: 87 nomi, margini slice uguali al manifest, nomi dei figli univoci, dimensioni statiche in Scale, minimo 44 px sui pulsanti e funzioni responsive reali valutate con Luau a 1920x1080, 1366x768, 844x390, 390x844.
- La prova geometrica assume un inset superiore di 36 px e riserva 160x160 px negli angoli inferiori; il codice legge invece l'inset corrente da GuiService. Controllati anche colonna menu e comandi touch nello scenario con quattro azioni visibili. Resoconto: artifacts/ui-startergui-review/layout-check.json.

Per ripetere le verifiche (passare il percorso del proprio luau.exe):

    node tools/ui/sync-fallback.mjs --check
    node tools/ui/check-ui.mjs PERCORSO/luau.exe
    node tools/ui/test-view.mjs PERCORSO/luau.exe
    rojo build -o PERCORSO_TEMPORANEO/ui-check.rbxlx

Le simulazioni locali verificano struttura e logica selezionata; non simulano il rendering Roblox, i font, il comportamento completo del touch o le risposte del server.

## Prove richieste a Claude/Mirko in Studio

Usare il Device Simulator integrato in Studio (chiamato Device Emulator nelle versioni precedenti): non e necessario installare un plugin. Impostare i quattro formati sopra, attivare input touch per i due telefoni e ruotare durante Play. [Documentazione ufficiale del simulatore](https://create.roblox.com/docs/studio/device-simulator).

1. Dopo l'unione e la sincronizzazione Rojo, verificare i sette nomi sotto StarterGui e l'assenza di duplicati in PlayerGui, anche dopo la rinascita.
2. Caricamento: titolo Climbing & Dragons, progressione da zero, consigli e PLAY solo dopo gioco/personaggio pronti. Con ID vuoti deve essere leggibile; ripetere con bg_loading, logo e pulsante caricati.
3. Menu: B, I/V, G, N, U, T; apertura da negozio, nido e banco da lavoro; Hide/Show, chiusura, scorrimento della colonna su telefono basso. Confermare che 44 px siano realmente comodi con la scala/DPI del simulatore.
4. Shop: Buy, Sell 1, Sell all, Sell egg e Robux (pass posseduto/non disponibile). Zaino: monete/casa, minerali, drop e attrezzi; aggiornamento senza riaprire.
5. Dragons: timer di schiusa, Hatch, Follow/Rest, XP, Evolve e doppia conferma Sell. Crafting: costi posseduti/richiesti, ricette ovunque/al banco e risposta server.
6. Upgrades: livelli/costi, Claim, daily, conferma Rebirth, record. HUD: salute, stamina, scudo, meteo notte/giorno, caldo, monete/chiodi, drago, missione e conferma Skip; un avviso temporaneo puo sovrapporsi alla missione in alto.
7. Teleport: nomi, distanza quando il marker e disponibile in streaming, lucchetto Dragon training prima del primo drago; il server continua a decidere autorizzazione e cooldown.
8. Touch: sulla parete Piton (pressione e rilascio), Jump e Unclip; a terra Run, Climb e azione del tool; nell'arena Shoot con gli effetti originali; Roar speciale e cooldown fuori dall'arena. Controllare che joystick e salto restino liberi e che il vecchio pulsante CAS Throw non compaia.
9. Morte: YOU FELL, causa/statistiche, Respawn, Revive solo con prodotto configurato. Ripetere con ID mancanti e immagini presenti; nessun messaggio rosso in Output.
10. In una copia di prova rimuovere le sette GUI prima di Play: il ripiego deve ricrearle e le azioni devono funzionare. Per visualizzare le immagini servono ID pubblicati e autorizzati per questa esperienza.

## Immagini ancora senza ID

Tutti gli 87 ID sono intenzionalmente vuoti in src/shared/UiAssets.luau. Inserire rbxassetid://ID nella tabella ids senza modificare get o slices. L'indice grafico resta artifacts/ui-20261010/index.md. Brace, Sole e Ombra restano nel registro del set consegnato; le schede mostrano i draghi presenti nei dati/config attuali, senza reintrodurre elementi nel gioco.

- bg_loading.png
- bg_menu.png
- bg_death.png
- logo.png
- panel_main.png
- panel_card.png
- panel_header.png
- panel_toast.png
- panel_quest.png
- rarity_common.png
- rarity_rare.png
- rarity_epic.png
- rarity_legendary.png
- btn_primary_normal.png
- btn_primary_hover.png
- btn_primary_pressed.png
- btn_secondary_normal.png
- btn_secondary_hover.png
- btn_secondary_pressed.png
- btn_danger_normal.png
- btn_danger_hover.png
- btn_danger_pressed.png
- btn_round_normal.png
- btn_round_hover.png
- btn_round_pressed.png
- btn_close.png
- icon_shop.png
- icon_backpack.png
- icon_dragons.png
- icon_crafting.png
- icon_teleport.png
- icon_settings.png
- icon_coin.png
- icon_health.png
- icon_stamina.png
- icon_warmth.png
- icon_cold.png
- icon_piton.png
- icon_altitude.png
- icon_quest.png
- icon_egg.png
- icon_lock.png
- weather_clear.png
- weather_night.png
- weather_cloudy.png
- weather_rain.png
- weather_thunder.png
- weather_storm.png
- weather_snow.png
- act_climb.png
- act_jump.png
- act_piton.png
- act_grapple.png
- act_throw.png
- act_sprint.png
- act_mine.png
- act_shoot.png
- elem_Roccia.png
- elem_Brace.png
- elem_Gelo.png
- elem_Cosmico.png
- elem_Tempesta.png
- elem_Sole.png
- elem_Ombra.png
- elem_Eclissi.png
- elem_Fulmine.png
- elem_Ossa.png
- elem_Gas.png
- ore_Carbone.png
- ore_Ferro.png
- ore_Oro.png
- ore_Cristallo.png
- ore_Rubino.png
- ore_Cosmico.png
- pass_FastIncubation.png
- pass_EggFinder.png
- pass_ExtraDragon.png
- pass_ExtraIncubator.png
- pass_TrainingX2.png
- prod_Coins1000.png
- prod_InstantHatch.png
- prod_Revive.png
- prod_TrainingBoost.png
- game_icon.png
- thumb_1.png
- thumb_2.png
- thumb_3.png
