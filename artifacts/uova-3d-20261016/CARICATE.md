# Uova v6 di Codex caricate in Studio (17/10, Claude)

FBX e texture restano nella copia di Codex: `../RObloxGame-codex/artifacts/uova-3d-20261016/v6/`
(qui solo manifest, LEGGIMI e anteprime).

- `tools/modelli/esporta_uova.py` (Blender 5.2, headless) -> un JSON per mesh dell'uovo intero
  (guscio, luce, gemma, castone e decori, ali).
- Texture: 80 PNG caricati (body e wings: color, normal, roughness, metalness, emission).
- `tools/modelli/carica_uova.luau` in Studio (Edit) -> `ServerStorage.Uova.Uovo_<Elemento>`,
  SurfaceAppearance con le quattro mappe PBR e la maschera dell'emissione tinta col colore
  dell'elemento; `_Luce` = Neon del colore dell'elemento. Girate di 180 gradi: la gemma guarda -Z
  (il davanti dei modelli Roblox). Attributi `UovoV6`, `Girato`.
- Le vecchie (e quelle di Sole/Brace/Ombra) sono in `ServerStorage.Cestino.UovaVecchie`.
- I frammenti della rottura non sono caricati: la schiusa (client/EggHatch) fa i suoi pezzi.

Le uova stanno nel file del place: dopo il caricamento va SALVATO il place.
