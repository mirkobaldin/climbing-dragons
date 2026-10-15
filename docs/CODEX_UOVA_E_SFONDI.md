# Prompt per Codex: uova nuove (8 elementi) e sfondi scuri dei menu

Da incollare a Codex cosi' com'e'. Branch: `codex/uova-sfondi-20261015` (parti da `main`).
Prima leggi `AGENTS.md`, `docs/PROMPT_MODELLI.md` (regole delle immagini per Meshy) e segna il
compito in `LAVORI.md`. Nessun file `src/**` da toccare tranne `src/shared/UiAssets.luau` (solo
le chiavi nuove, vuote se l'ID non c'e' ancora).

## Perche' (Mirko, 2026-10-15)
"Di' a Codex di rifare i modelli delle uova, dato che abbiamo quelli vecchi, e il drago Sole e
Ombra non ci sono piu'."
Oggi in `ServerStorage.Uova` (dentro il file place, non nel repo) ci sono 7 uova vecchie:
`Uovo_Brace`, `Uovo_Cosmico`, `Uovo_Gelo`, `Uovo_Ombra`, `Uovo_Roccia`, `Uovo_Sole`,
`Uovo_Tempesta`. Brace, Sole e Ombra sono elementi tolti; mancano Eclissi, Fulmine, Ossa, Gas
(oggi il gioco le colora a caso partendo da un altro uovo). Il codice non fa piu' nascere uova di
Sole/Ombra/Brace (`DragonConfig.RETIRED`).

## 1. Le 8 uova (immagini per Meshy, image-to-3D)
Gli 8 elementi, SOLO questi: Roccia, Gelo, Cosmico, Tempesta, Eclissi, Fulmine (Fulmine Nero),
Ossa, Gas. Niente Brace, Sole, Ombra.

Un set coerente, tutte con la **stessa forma di base** (si devono riconoscere come famiglia):
- uovo grande e pieno, un po' piu' largo in basso, che sta in piedi da solo (base leggermente
  piatta, niente supporti, niente nido, niente piedistallo);
- il motivo dell'elemento **scolpito o dipinto sul guscio**, a grandi forme leggibili da 30 m
  (crepe luminose, placche, anelli, venature), niente parti sottili che escono dal guscio
  (niente corna lunghe, ali, catene, spuntoni fini): Meshy le rovina;
- un colore luminoso (le crepe/rune) che il gioco fara' brillare: tienilo in zone nette;
- colori presi dal drago vero (`ServerStorage.Draghi`, vedi le anteprime in
  `artifacts/cuccioli-elementali-20261005` e `ReplicatedStorage.Previews` se le hai): il Gas e'
  BLU/CIANO con nuvole magenta (Mirko ha bocciato il verde), l'Eclissi nero con anello arancio.

Chiusura uguale per tutte (aggiungila a ogni prompt):
> Single dragon egg, big smooth closed shape, stands upright on its own slightly flat bottom, no
> nest, no stand, no thin parts sticking out, stylized semi-realistic, saturated colors, PBR
> materials, centered, plain white background, no shadow, front 3/4 view, Roblox game asset.

Spunti per i prompt (riscrivili tu, stesso stile):
| File | Elemento | Guscio |
|---|---|---|
| `uovo_roccia.png` | Roccia | sandstone plates in ochre and tan like armor scales, glowing amber cracks between them |
| `uovo_gelo.png` | Gelo | pale icy blue shell, frosted crystal facets near the top, glowing light-cyan cracks |
| `uovo_cosmico.png` | Cosmico | deep violet shell with a starry nebula pattern, glowing magenta spiral |
| `uovo_tempesta.png` | Tempesta | slate blue shell with swirling white wind bands, glowing sky-blue rune |
| `uovo_eclissi.png` | Eclissi | matte black shell with a bright orange eclipse ring around the middle |
| `uovo_fulmine.png` | Fulmine | dark navy shell with jagged glowing violet lightning cracks |
| `uovo_ossa.png` | Ossa | bone-white shell with fossil ribs in relief and a faint skull pattern, mint glow |
| `uovo_gas.png` | Gas | pale cyan shell with swirling magenta clouds, glowing cyan spots (NOT green) |

Consegna: `artifacts/uova-20261015/` con le 8 PNG (1024x1024, sfondo bianco piatto), un
`anteprima.png` con le 8 affiancate e `PROMPT.md` con i prompt finali. Mirko le passa su Meshy.

### Dopo Meshy (scrivilo in `artifacts/uova-20261015/LEGGIMI.md`, lo fa Mirko o Claude in Studio)
- importare gli FBX/GLB in Studio e mettere ogni uovo in `ServerStorage.Uova` col nome
  `Uovo_<Elemento>` (es. `Uovo_Fulmine`): `server/DragonModels.egg` le trova dal nome
  (`DragonConfig.elementForName`, parole in `DragonConfig.ELEMENTS[*].words`);
- spostare `Uovo_Brace`, `Uovo_Sole`, `Uovo_Ombra` in `ServerStorage.Cestino` (non cancellarle);
- nessuno script dentro i modelli (regola di sicurezza di AGENTS.md).

## 2. Sfondi scuri dei menu, stile menu zombie di Black Ops 2
Mirko ha bocciato gli sfondi colorati delle finestre ("lo sfondo colorato fa schifo, dovrebbe
essere tipo lo sfondo del menu zombie di Black Ops 2"). Il codice ora fa da solo un fondo scuro
(carbone, fumo che scorre, brace dal basso, scintille che salgono: `client/UiGlow.darkBackground`),
ma serve un'immagine vera dietro.

Fai (PNG, niente testo, niente loghi, niente personaggi riconoscibili, niente armi da fuoco):
- `bg_menu_dark.png` 2048x1024: fondo quasi nero, texture sporca di cemento/metallo graffiato,
  fumo grigio a strati, bagliore di brace arancio-rosso dal basso, qualche scintilla; ai lati
  sagome scure appena visibili di rocce e ossa di drago (il nostro tema, non zombie); il centro
  deve restare scuro e pulito (ci vanno sopra le schede).
- `bg_panel_dark.png` 512x512 a 9-slice (bordi 24 px): riquadro scuro con graffi leggeri e un
  filo d'arancio in basso, angoli arrotondati 16 px; SENZA cornice spessa (Mirko: "un botto di
  cornici inutili", niente doppi bordi).
- `glow_ring.png` 256x256: anello luminoso bianco sfumato, trasparente al centro e fuori (lo
  colora e lo fa girare il codice).
- `glow_rays.png` 512x512: raggi bianchi sfumati dal centro, sfondo trasparente.

Mettili in `artifacts/ui-scuro-20261015/`, poi caricali su Roblox come gli altri (vedi
`docs/UI_STARTERGUI.md` e `tools/ui/`) e scrivi gli ID in `src/shared/UiAssets.luau` con le chiavi
`bg_menu_dark`, `bg_panel_dark`, `glow_ring`, `glow_rays`. `client/MainMenu` usa gia'
`bg_menu_dark` appena la chiave ha un ID (finche' e' vuota resta l'illustrazione della montagna
col velo scuro). Dopo una modifica ai JSON: `node tools/ui/sync-fallback.mjs`.

## Da verificare (scrivilo nel messaggio finale)
Tu non vedi Studio: elenca cosa va controllato in Play (uova nel mondo e nel menu Nest, sfondo
delle finestre Dragons, Backpack, Shop) e non inventare nomi di istanze che non stanno nel repo.
