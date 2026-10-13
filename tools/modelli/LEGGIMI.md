# Modelli di Codex in Studio senza l'Importer

Case (Tent, StoneCabin, ModernChalet, MegaChalet), falo' (Campfire) e parapendio (Gliders/*),
caricati il 2026-10-14.

1. `esporta_modelli.py` (Blender 5.2, `-b --factory-startup`): per ogni cartella apre
   `<Nome>.fbx` e `<Nome>_Collision.fbx` e scrive un JSON per oggetto (assi Roblox, metri), piu'
   `index.json` con parti, materiali, ossa delle ali e marcatori (luci, fuoco).
2. `node prepara.js <repo> <cartella json>`: scatole di collisione e `textures.json`
   (BaseColor/Normal/Roughness per materiale).
3. `node serve.js <repo> <cartella json>` su `http://127.0.0.1:8766` (`/repo/...` e `/json/...`).
4. Texture: `upload_image` dell'MCP sugli URL `/repo/...`, poi `matids.json` (materiale -> ID) nella
   cartella json.
5. `carica_modelli.luau` come ModuleScript in Studio: `require(m)("MegaChalet", 1, 14)` a gruppi.
   Mette il modello in `ServerStorage.CaseCodex` (i parapendio poi in `ReplicatedStorage.Vele`).

Attenzione: `CreateAssetAsync` rifiuta i nomi oltre 50 caratteri (UploadFailed).

Le case le usa `server/Economy` (CODEX_HOUSE, scala HOUSE_SCALE, pedana, luci), i parapendio
`client/Glider` (attributo GliderSkin, comando admin `vela`).
