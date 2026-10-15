# Lavori in corso (Claude Code / Codex)

Prima di iniziare un compito: aggiungi una riga qui sotto con chi, branch e file che toccherai.
Se un file e' gia' nella lista di un altro agente, NON modificarlo: scegli un altro compito o aspetta.
Quando il branch e' unito in `main`, togli la riga.

| Chi | Branch | Compito | File toccati |
|---|---|---|---|
| Claude | main | (15/10) UI v3 unita e ID caricati (bg_menu di nuovo visibile), Isola dei Draghi e 18 modelli del cloud in ServerStorage.CaseCodex, isola montata col Terrain sotto il prato, draghi: IK morbida, posto accanto senza giri, correzioni delle zampe ammorbidite | src/client/{PetAnimator,DragonProcedural,MainMenu}, src/mapgen/IsolaDraghi, tools/modelli/** |
| Claude (cloud) | cloud/modelli-20261014 | UNITO E CARICATO (15/10): isola e 18 modelli in ServerStorage.CaseCodex. Prossimo: pezzi Meshy (teste del portale, statue, corna, fossili) | solo cloud/** e tools/blender/**; nessun file src |
| Claude | main | bug draghi (terreno, monta, colpo in volo), attacchi per elemento, VFX, animazioni, UI telefono e colori, contatore | src/** |
| Codex | codex/discord-community-20261013 | IN CORSO: server Discord configurato, immagini e AutoMod pubblicati, bot online; verifica finale di gerarchia ruoli e permessi | artifacts/discord-community-20261013/** nel worktree; copia consegna Desktop/Climbing & Dragons Discord/**; nessun file src |
| Codex | codex/alpine-assets-20261013 | PRONTO: otto asset Blender esportati e verificati, catalogo in MegaChalet/SET_ALPINO.html; import e Play da provare in Studio | artifacts/alpine-assets-20261013/** nel worktree; esportazioni richieste in main/{Tent,Campfire,StoneCabin,ModernChalet,MegaChalet,Gliders}/**; nessun file src |
| Codex | codex/oggetti-20261010 | Riferimenti Meshy, sprite sheet VFX e icone nuove di Climbing & Dragons | artifacts/oggetti-20261010/**; nessun file src |
| Claude | main | borghi cinesi/giapponesi, testi in inglese (Names), VFX e suoni dei draghi | src/mapgen/{Borghi,Tutorial,Village,init}.luau, src/shared/{Names,Gear,ShopConfig,DragonConfig,ClimbConfig}.luau, quasi tutti i file di src/client e src/server (testi) |
| Codex | codex/drago-cosmico-blender | Modellazione Blender del Drago Cosmico dalla reference; blockout e verifiche progressive | Solo RObloxGame-codex/artifacts/drago-cosmico/*; nessun file src |
| Codex | codex/cuccioli-elementali-20261005 | Revisione cuccioli: ali piegate e separate per reference Meshy; adulti gia esportati | artifacts/cuccioli-elementali-20261005/*; export C:/Users/mirko/Pictures/drago*.png |
| Codex | codex/piccozze-20261007 | Generazione nove immagini di piccozze con sfondo trasparente | artifacts/piccozze-20261007/* |
| Codex | codex/creature-20261007 | Generazione 16 immagini nemici e boss con sfondo trasparente | artifacts/creature-20261007/* |
| Codex | codex/materiali-20261007 | Generazione 17 immagini di materiali e bottini con sfondo trasparente | artifacts/materiali-20261007/* |
| Codex | codex/altari-props-20261007 | Generazione 11 altari-nido, banco crafting, scheletro gigante e arena | artifacts/altari-props-20261007/* |
| Codex | codex/modelli-statici-20261007 | Revisione V4 Blender: piccozze decorate a 360 gradi, 24 varianti di cristalli con shader vetro/ghiaccio ed export | artifacts/modelli-statici-20261007/* |

Nota per Codex (Claude, 2026-10-10): immagini UI unite in main (a69ca2a). Il compito 2 di docs/CODEX_UI.md (schermate in StarterGui) puo' partire da main: i file UI sono liberi. Nuove schede da includere: Upgrades (client/UpgradeUI.luau, tasto U) e il pulsante dell'attacco speciale (client/Combat.luau). Prossimo compito immagini: docs/CODEX_OGGETTI.md.
