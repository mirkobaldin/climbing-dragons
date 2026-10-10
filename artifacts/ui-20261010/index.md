# Climbing & Dragons — asset UI, 10 ottobre 2026

Set completo: **87 PNG**, sul branch `codex/ui-immagini-20261010`. Generazione con lo strumento integrato image_gen; ridimensionamento proporzionale con `prepare.ps1`. Il titolo corretto indicato da Mirko e' **Climbing & Dragons**.

I PNG da importare sono solo quelli direttamente in questa cartella; `review/` contiene tavole di controllo, non asset di gioco. `manifest.json` contiene i prompt base e le dimensioni; `prompt-variants.json` conserva le istruzioni delle varianti e delle correzioni; `sources.json` collega gli originali generati. Nessun caricamento Roblox e' stato eseguito.

## Uso in Studio

Margini nell'ordine **sinistra, alto, destra, basso**, in pixel della texture. `SliceCenter = Rect.new(sinistra, alto, larghezza - destra, altezza - basso)`. Impostare `ScaleType = Slice`, `BackgroundTransparency = 1`, `ImageColor3 = Color3.new(1,1,1)`. Le righe senza slice usano `Fit` (icone/logo) o `Crop` (sfondi).

Per i pannelli scegliere `SliceScale` in funzione della dimensione a schermo, senza comprimere gli angoli sotto i margini complessivi. Per i pulsanti circolari mantenere `UIAspectRatioConstraint = 1` e usare `SliceScale = lato visualizzato / 256`: la forma circolare richiede una scala uniforme; non allungarli come pannelli rettangolari. Sovrapporre le icone `act_*` in bianco. Il minimo di 44 px riguarda l'area cliccabile nella GUI.

Testi in TextLabel/TextButton separati, mai incorporati nelle immagini tranne il logo. Prezzi e quantita' del negozio restano dinamici. Le immagini `pass_*` e `prod_*`, gli sfondi e le anteprime hanno fondo opaco come richiesto.

## Elenco completo richiesto

| File | Misura px | Margini L,T,R,B | SliceCenter (x1,y1,x2,y2) | Uso |
|---|---|---|---|---|
| [bg_loading.png](bg_loading.png) | 1024 × 576 | — | — | Caricamento |
| [bg_menu.png](bg_menu.png) | 1024 × 576 | — | — | Menu |
| [bg_death.png](bg_death.png) | 1024 × 576 | — | — | Morte |
| [logo.png](logo.png) | 1024 × 512 | — | — | Caricamento e menu |
| [panel_main.png](panel_main.png) | 512 × 512 | 136, 136, 136, 136 | 136, 136, 376, 376 | Finestre |
| [panel_card.png](panel_card.png) | 256 × 256 | 72, 72, 72, 72 | 72, 72, 184, 184 | Carte oggetti |
| [panel_header.png](panel_header.png) | 512 × 128 | 136, 60, 136, 60 | 136, 60, 376, 68 | Titoli finestre |
| [panel_toast.png](panel_toast.png) | 512 × 128 | 112, 60, 112, 60 | 112, 60, 400, 68 | Avvisi HUD |
| [panel_quest.png](panel_quest.png) | 512 × 192 | 112, 80, 80, 64 | 112, 80, 432, 128 | Missione/tutorial |
| [rarity_common.png](rarity_common.png) | 256 × 256 | 72, 72, 72, 72 | 72, 72, 184, 184 | Rarita' draghi/oggetti |
| [rarity_rare.png](rarity_rare.png) | 256 × 256 | 72, 72, 72, 72 | 72, 72, 184, 184 | Rarita' draghi/oggetti |
| [rarity_epic.png](rarity_epic.png) | 256 × 256 | 72, 72, 72, 72 | 72, 72, 184, 184 | Rarita' draghi/oggetti |
| [rarity_legendary.png](rarity_legendary.png) | 256 × 256 | 72, 72, 72, 72 | 72, 72, 184, 184 | Rarita' draghi/oggetti |
| [btn_primary_normal.png](btn_primary_normal.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante primary / normal |
| [btn_primary_hover.png](btn_primary_hover.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante primary / hover |
| [btn_primary_pressed.png](btn_primary_pressed.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante primary / pressed |
| [btn_secondary_normal.png](btn_secondary_normal.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante secondary / normal |
| [btn_secondary_hover.png](btn_secondary_hover.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante secondary / hover |
| [btn_secondary_pressed.png](btn_secondary_pressed.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante secondary / pressed |
| [btn_danger_normal.png](btn_danger_normal.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante danger / normal |
| [btn_danger_hover.png](btn_danger_hover.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante danger / hover |
| [btn_danger_pressed.png](btn_danger_pressed.png) | 384 × 128 | 48, 40, 48, 40 | 48, 40, 336, 88 | Pulsante danger / pressed |
| [btn_round_normal.png](btn_round_normal.png) | 256 × 256 | 127, 127, 127, 127 | 127, 127, 129, 129 | Pulsante round / normal |
| [btn_round_hover.png](btn_round_hover.png) | 256 × 256 | 127, 127, 127, 127 | 127, 127, 129, 129 | Pulsante round / hover |
| [btn_round_pressed.png](btn_round_pressed.png) | 256 × 256 | 127, 127, 127, 127 | 127, 127, 129, 129 | Pulsante round / pressed |
| [btn_close.png](btn_close.png) | 128 × 128 | — | — | Chiusura finestre |
| [icon_shop.png](icon_shop.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_backpack.png](icon_backpack.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_dragons.png](icon_dragons.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_crafting.png](icon_crafting.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_teleport.png](icon_teleport.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_settings.png](icon_settings.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_coin.png](icon_coin.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_health.png](icon_health.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_stamina.png](icon_stamina.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_warmth.png](icon_warmth.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_cold.png](icon_cold.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_piton.png](icon_piton.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_altitude.png](icon_altitude.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_quest.png](icon_quest.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_egg.png](icon_egg.png) | 256 × 256 | — | — | Menu/HUD |
| [icon_lock.png](icon_lock.png) | 256 × 256 | — | — | Menu/HUD |
| [weather_clear.png](weather_clear.png) | 256 × 256 | — | — | Meteo HUD |
| [weather_night.png](weather_night.png) | 256 × 256 | — | — | Meteo HUD |
| [weather_cloudy.png](weather_cloudy.png) | 256 × 256 | — | — | Meteo HUD |
| [weather_rain.png](weather_rain.png) | 256 × 256 | — | — | Meteo HUD |
| [weather_thunder.png](weather_thunder.png) | 256 × 256 | — | — | Meteo HUD |
| [weather_storm.png](weather_storm.png) | 256 × 256 | — | — | Meteo HUD |
| [weather_snow.png](weather_snow.png) | 256 × 256 | — | — | Meteo HUD |
| [act_climb.png](act_climb.png) | 256 × 256 | — | — | Comandi telefono |
| [act_jump.png](act_jump.png) | 256 × 256 | — | — | Comandi telefono |
| [act_piton.png](act_piton.png) | 256 × 256 | — | — | Comandi telefono |
| [act_grapple.png](act_grapple.png) | 256 × 256 | — | — | Comandi telefono |
| [act_throw.png](act_throw.png) | 256 × 256 | — | — | Comandi telefono |
| [act_sprint.png](act_sprint.png) | 256 × 256 | — | — | Comandi telefono |
| [act_mine.png](act_mine.png) | 256 × 256 | — | — | Comandi telefono |
| [act_shoot.png](act_shoot.png) | 256 × 256 | — | — | Comandi telefono |
| [elem_Roccia.png](elem_Roccia.png) | 256 × 256 | — | — | Elemento drago Roccia |
| [elem_Brace.png](elem_Brace.png) | 256 × 256 | — | — | Elemento drago Brace |
| [elem_Gelo.png](elem_Gelo.png) | 256 × 256 | — | — | Elemento drago Gelo |
| [elem_Cosmico.png](elem_Cosmico.png) | 256 × 256 | — | — | Elemento drago Cosmico |
| [elem_Tempesta.png](elem_Tempesta.png) | 256 × 256 | — | — | Elemento drago Tempesta |
| [elem_Sole.png](elem_Sole.png) | 256 × 256 | — | — | Elemento drago Sole |
| [elem_Ombra.png](elem_Ombra.png) | 256 × 256 | — | — | Elemento drago Ombra |
| [elem_Eclissi.png](elem_Eclissi.png) | 256 × 256 | — | — | Elemento drago Eclissi |
| [elem_Fulmine.png](elem_Fulmine.png) | 256 × 256 | — | — | Elemento drago Fulmine |
| [elem_Ossa.png](elem_Ossa.png) | 256 × 256 | — | — | Elemento drago Ossa |
| [elem_Gas.png](elem_Gas.png) | 256 × 256 | — | — | Elemento drago Gas |
| [ore_Carbone.png](ore_Carbone.png) | 256 × 256 | — | — | Minerale Carbone |
| [ore_Ferro.png](ore_Ferro.png) | 256 × 256 | — | — | Minerale Ferro |
| [ore_Oro.png](ore_Oro.png) | 256 × 256 | — | — | Minerale Oro |
| [ore_Cristallo.png](ore_Cristallo.png) | 256 × 256 | — | — | Minerale Cristallo |
| [ore_Rubino.png](ore_Rubino.png) | 256 × 256 | — | — | Minerale Rubino |
| [ore_Cosmico.png](ore_Cosmico.png) | 256 × 256 | — | — | Minerale Cosmico |
| [pass_FastIncubation.png](pass_FastIncubation.png) | 512 × 512 | — | — | Negozio Robux |
| [pass_EggFinder.png](pass_EggFinder.png) | 512 × 512 | — | — | Negozio Robux |
| [pass_ExtraDragon.png](pass_ExtraDragon.png) | 512 × 512 | — | — | Negozio Robux |
| [pass_ExtraIncubator.png](pass_ExtraIncubator.png) | 512 × 512 | — | — | Negozio Robux |
| [pass_TrainingX2.png](pass_TrainingX2.png) | 512 × 512 | — | — | Negozio Robux |
| [prod_Coins1000.png](prod_Coins1000.png) | 512 × 512 | — | — | Negozio Robux |
| [prod_InstantHatch.png](prod_InstantHatch.png) | 512 × 512 | — | — | Negozio Robux |
| [prod_Revive.png](prod_Revive.png) | 512 × 512 | — | — | Negozio Robux |
| [prod_TrainingBoost.png](prod_TrainingBoost.png) | 512 × 512 | — | — | Negozio Robux |
| [game_icon.png](game_icon.png) | 512 × 512 | — | — | Icona pagina gioco |
| [thumb_1.png](thumb_1.png) | 1024 × 576 | — | — | Anteprima pagina gioco |
| [thumb_2.png](thumb_2.png) | 1024 × 576 | — | — | Anteprima pagina gioco |
| [thumb_3.png](thumb_3.png) | 1024 × 576 | — | — | Anteprima pagina gioco |

## Consegna e verifiche

`prepare.ps1 -Validate` controlla dimensioni, pixel trasparenti e bordi: 87/87 immagini conformi, misure pari e lato massimo 1024. `validation.json` riporta i risultati per file. I ritagli hanno alpha reale e bordo esterno trasparente; sfondi, carte negozio e immagini pagina gioco sono opachi.

`preview.ps1` produce cinque tavole con campioni anche a 32 px. `preview-slices.ps1` produce cinque tavole con pannelli e pulsanti allungati a 360x180 e 560x130, SliceScale 0.5. Controllati visivamente testo, bordi, simboli e decorazioni: rimossi gli ornamenti al centro dei bordi del pannello missioni e uniformate le quattro cornici delle rarita'. Le simulazioni locali non sostituiscono la verifica 9-slice in Studio dopo il caricamento.

Anteprime: [sfondi, logo e pannelli](review/contact-1.png), [pulsanti e HUD](review/contact-2.png), [meteo e comandi touch](review/contact-3.png), [elementi, minerali e negozio](review/contact-4.png), [prodotti e pagina gioco](review/contact-5.png). Le immagini sono illustrazioni promozionali, non screenshot del place. I colori degli elementi seguono DragonConfig; i modelli nel place non sono accessibili da questa copia.

Claude o Mirko: importare i PNG con Asset Manager > Bulk Import, conservando questi nomi, e assegnare gli ID. Sono tutti ancora senza ID Roblox. Non importare gli script PowerShell, i JSON o le tavole di controllo.

Il compito StarterGui resta separato: prima di toccare i client servono conferma che main contenga le ultime modifiche e rilascio dei file UI registrati a nome di Claude in LAVORI.md. Verifiche Play e Device Emulator non eseguibili da questa copia Codex.
