# Prompt per Codex: pulsanti e cornici "v2" (senza cancellare quelli di prima)

Da incollare a Codex così com'è. Branch: `codex/ui-bottoni-v2-20261014`. Segna il compito in
`LAVORI.md` prima di iniziare. Leggi `AGENTS.md`.

## Perché
Feedback di un giocatore e di Mirko sull'interfaccia di oggi (`artifacts/ui-20261010/`):
- lo stile piace, ma i pulsanti **Buy / Sell / Unlock** su PC sono piccoli e la scritta bianca
  sopra l'oro si legge male;
- tutti i pulsanti hanno lo stesso colore: non si capisce subito quale e' "compra", quale "vendi",
  quale e' il principale;
- la schermata **Rebirth** (sfondo illustrato) piace molto: lo stile nuovo deve andare d'accordo
  con quegli sfondi (illustrati, caldi, fantasy).

Il codice e' gia' pronto per pulsanti piu' grandi (52-60 px di altezza logica, testo 20-22 in
GothamBlack con bordo scuro, vedi `src/shared/UiView.luau` CARD_STYLE): mancano le immagini.

## Regola d'oro
**Non toccare e non sovrascrivere** i file e le chiavi esistenti (`btn_primary_*`, `btn_secondary_*`,
`btn_danger_*`, `btn_round_*`, `panel_*` in `src/shared/UiAssets.luau` e `artifacts/ui-20261010/`).
Le immagini nuove hanno nomi nuovi con `_v2`; il passaggio dal vecchio al nuovo lo fa Claude nel
codice, cosi' si puo' tornare indietro.

## Direzione visiva
- Tema: draghi, montagna, fantasy "illustrato" (come gli sfondi `bg_menu`, `bg_death`). Metallo
  dorato consumato, pietra scura, smalto colorato, una gemma o una piccola testa/artiglio di drago
  come decorazione, mai invadente.
- Leggibilita' prima di tutto: **centro del pulsante piatto e scuro o con gradiente morbido**, dove
  il testo bianco con bordo scuro si legge sempre. La decorazione sta solo sul bordo.
- Ogni tipo ha il suo colore di smalto (centro):
  | Chiave | Uso | Colore centro |
  |---|---|---|
  | `btn_buy_v2` | Buy, Craft, Hatch, Follow | verde smeraldo |
  | `btn_sell_v2` | Sell, Sell all | rosso rubino |
  | `btn_main_v2` | azione principale (Rebirth, Ride, Unlock, Upgrade) | oro / ambra scura |
  | `btn_alt_v2` | secondario (Rest, Skip, Reset, schede non scelte) | blu notte |
  | `btn_off_v2` | disabilitato (non abbastanza monete, "Not ready") | grigio ardesia, bordo spento |
  | `tab_on_v2` / `tab_off_v2` | schede in alto (Buy/Sell/Robux, Upgrades/Bounties/Rebirth) | oro acceso / blu scuro |
- Per ognuno tre stati: `_normal`, `_hover` (un po' piu' luminoso, bordo che brilla), `_pressed`
  (piu' scuro, abbassato di 2 px). Esempio: `btn_buy_v2_normal.png`.

## Misure (9-slice)
- Pulsanti: PNG **512 x 160**, angoli decorati nei primi/ultimi **64 px** in orizzontale e **48 px**
  in verticale; il centro (da 64,48 a 448,112) deve potersi stirare senza rovinarsi (niente
  disegni nel centro, solo colore o gradiente verticale). Scrivi i margini in `index.md` nel
  formato `Rect.new(64, 48, 448, 112)`.
- Schede: PNG 384 x 112, margini `Rect.new(56, 36, 328, 76)`.
- Due cornici nuove per le carte:
  - `card_glass_v2` (256 x 256, margini 72): vetro scuro semitrasparente (alpha 70-80%) con
    bordo d'oro sottile: per i pannelli sopra gli sfondi illustrati (Rebirth), lo sfondo deve
    vedersi attraverso;
  - `card_item_v2` (256 x 256, margini 72): cornice per le carte del negozio e del crafting, angoli
    con piccola gemma, centro trasparente (il colore lo mette il gioco, `UiView.tint`).
- Un piedistallo per i draghi del menu: `pedestal_v2.png` 512 x 256, visto di tre quarti, pietra
  scura con bordo di bronzo e un anello di rune vuoto (bianco a 50%: il gioco lo colora
  dell'elemento). Sfondo trasparente.
- Tutto PNG RGBA, sfondo trasparente, niente testo dentro le immagini.

## Consegna
- `artifacts/ui-v2-20261014/` con i PNG, `index.md` (nome, misura, margini 9-slice, dove si usa)
  e `anteprima.png`: una tavola con tutti i pulsanti a 3 grandezze (120x44, 200x56, 320x64) con
  sopra le scritte vere (Buy, Sell all, Unlock, REBIRTH, Ride, Not ready yet) in GothamBlack bianco
  con bordo scuro, su tre sfondi (`bg_menu`, un pannello scuro, un colore chiaro). Controlla tu che
  si leggano da 1 metro dallo schermo e a meta' grandezza (telefono).
- Caricamento su Roblox e ID: come per `ui-20261010` (vedi `docs/CODEX_UI.md`): aggiungi le chiavi
  **nuove** in `src/shared/UiAssets.luau` (e i margini in `UiAssets.slices`), poi
  `node tools/ui/sync-fallback.mjs`. Non cambiare le chiavi vecchie.
- Nel messaggio finale: elenco chiavi e dove pensi vadano usate. Il collegamento nel codice
  (`UiView.skin(button, "btn_buy_v2_normal")` al posto di quelle vecchie) lo fa Claude in locale dopo
  averle viste in Studio.
