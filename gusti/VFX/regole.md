# VFX: cosa sappiamo gia'

## Sbagliato
- Acqua finta: nastri di Glass, pannelli di cascata con texture, nuvole di particelle come schiuma
  ("fa schifo"). L'acqua e' Terrain vero.
- Il plugin VFX fatto da Claude per Studio ("fa schifo"): gli effetti si fanno nel codice del gioco
  con le istanze di Roblox (ParticleEmitter, Beam, Trail, luci) e la libreria `VFXLib`.

## Buono
- I pacchetti VFX di Mirko (ora in `ServerStorage.VFXSorgente`, copiati in `ReplicatedStorage.VFXLib`).
- Le 66 mesh VFX di Codex (`VFX_01..66`), usate da `client/MeshFX`.

## Da riempire
Aggiungi qui sotto (o in note separate) gli effetti che ti piacciono in altri giochi, con video.

## Schiusa (17/10)
- Mirko chiede piu' fulmini e particelle e uno sfondo figo nella schiusa: ora fulmini per ogni
  elemento che crescono, fulmini dal cielo alla rottura, onda d'urto, colonna di scintille,
  fondale con la valle del ghiacciaio, nebbia dell'elemento e raggi di luce. Da giudicare.
- Schiusa giudicata il 17/10 sera: uova nuove, animazioni e VFX vanno bene. SBAGLIATO: il fondale
  con l'immagine della valle (storto rispetto alla camera) e i raggi di luce verticali ("strisce
  bruttissime"). Ora un posto 3D fatto apposta per l'elemento (`shared/Fondali`). Da giudicare.
