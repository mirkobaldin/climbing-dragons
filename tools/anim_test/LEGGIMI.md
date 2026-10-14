# Prove delle animazioni procedurali fuori da Roblox

    bash tools/anim_test/esegui.sh test_scheletro.luau
    bash tools/anim_test/esegui.sh test_passi.luau
    bash tools/anim_test/esegui.sh test_procedurale.luau
    bash tools/anim_test/esegui.sh test_ordine.luau

Serve il Luau da riga di comando (https://github.com/luau-lang/luau/releases, `luau` nel PATH o
`LUAU=/percorso/luau`). `esegui.sh` unisce in un file: `vector3.luau` (Vector3 finto), i moduli
puri di `src/shared` (DragonSkeleton, DragonGait), per i test che iniziano con `--@client` anche
`cframe.luau`, `mondo_finto.luau` (ossa, modello, terreno, raycast, KfsPlayer finti) e
`src/client/DragonProcedural.luau`, poi gli scheletri veri (`scheletri.txt`, dall'Output di
`tools/studio/scheletri_compatti.luau`) e il test. Documentazione: `docs/ANIMAZIONI_PROCEDURALI.md`.
