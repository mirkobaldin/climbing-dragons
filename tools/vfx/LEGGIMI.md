# Mesh VFX su Roblox senza l'Importer di Studio

Le 66 mesh VFX di Codex (`artifacts/vfx-mesh-20261012`, `artifacts/vfx-elementali-30-20261012`)
sono state caricate il 2026-10-13 cosi':

1. `esporta_mesh.py` (Blender 5.2, senza interfaccia) apre ogni FBX singolo e scrive un JSON per
   mesh: vertici gia' in assi Roblox (Y in alto, avanti Blender Y = -Z Roblox), UV con la V
   capovolta, normali e triangoli.

       blender -b --factory-startup --python esporta_mesh.py -- "<cartella kit 36>" "<cartella 30 elementali>" "<cartella json>"

2. `serve.js` serve quella cartella su `http://127.0.0.1:8765` (`node serve.js <cartella json>`).
3. `carica_in_studio.luau` (da eseguire in Studio, Edit) accende HttpEnabled per un attimo, legge i
   JSON, costruisce un EditableMesh, lo carica con `AssetService:CreateAssetAsync` e mette il
   MeshPart in `ReplicatedStorage.VFXLib.Mesh` con il nome `VFX_xx_...`. Le 37-66 prendono la
   palette (`rbxassetid://109155444409384`) come TextureID e restano bianche.

Gli ID ottenuti sono in `src/server/VFXMeshes.luau`: se un MeshPart manca nel place, il server lo
ricrea all'avvio. L'uso negli attacchi e' in `src/client/MeshFX.luau` (animazione in
`VFXKit.play`).
