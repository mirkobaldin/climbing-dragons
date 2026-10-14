# Isola dei Draghi con l'arena — scheda

## A cosa serve nel gioco
Dalla pedana del campo il giocatore si teletrasporta su un'isola volante lontana (`SPOT_Arrivo`).
Li' **diventa il suo drago**: lo comanda dal **palco del domatore** (`SPOT_Domatore`) mentre il drago
vola dentro l'arena (addestramento, Duello dei draghi a 3 round contro draghi selvatici che si
posano sugli anelli in cima alle mura, `SPOT_Posatoio1..8`). L'altare del duello (`SPOT_Altare`)
avvia il duello. L'isola si vede da lontano: deve essere riconoscibile come "il posto dei draghi"
dalla sagoma (isola sospesa + colosseo con torri e bracieri accesi).

## Misure (metri; personaggio 1,7 m = 5 stud)
| Cosa | Misura |
|---|---|
| Isola | circa 400 x 400 m vista dall'alto, spessore 160 m (sotto cono irregolare) |
| Arena | ottagono, interno Ø 150 m (apotema 75), esterno circa Ø 190 m |
| Mura | podio 4 m, gradinate fino a 22 m, parapetto e merli fino a 26 m |
| Torri | 8, alte 40 m al braciere, Ø circa 16 m, una per elemento |
| Portale | arco 20 x 30 m (ci passano i draghi), fra due teste di drago (Meshy) |
| Palco del domatore | balcone sul lato del portale, piano a 12 m, parapetto 1,1 m |
| Arrivo | piattaforma tonda Ø 16 m, 3 gradini da 0,3 m, cerchio di rune |
| Sentiero | lastricato largo 4 m dall'arrivo al portale |
| Porte a misura d'uomo | 3 m di altezza, 1,6 m di larghezza (scale delle torri, palco) |
| Gradini a misura d'uomo | 0,3 m alzata, 0,35 m pedata (scale verso il palco) |
| Isolette | 5, da 40 a 80 m, con rovine e posatoi |

## Riferimenti (cosa prendo da ognuno)
1. **Colosseo di Roma**: la facciata ad archi a tutto sesto su piu' ordini con semicolonne fra
   gli archi e il cornicione; i gradoni interni a fasce (maeniana) con le scalette che li tagliano;
   le parti crollate e i blocchi mancanti in cima.
2. **Arene di Elden Ring (Colosseo di Limgrave, Caelid)**: pietra scura consumata, archi profondi
   con ombre forti, bracieri sulle torri, bordi irregolari e crepe; il senso di "rovina ancora in uso".
3. **Dragonsreach (Skyrim)**: le teste di drago e i motivi scolpiti come elemento d'ingresso, il
   legno e il bronzo dentro la pietra, il palco rialzato del jarl (qui: il palco del domatore).
4. **Cittadelle di Dragon's Dogma**: contrafforti massicci, torri tozze con merli, stendardi
   lunghi che pendono dalle torri, l'uso del bronzo e dell'oro antico per le rifiniture.
5. **Isole volanti (Avatar, Zelda Skyward Sword)**: sotto l'isola roccia a cono rovesciato con
   strati, radici di pietra, cascate che cadono dal bordo; sopra prato e sentieri.

## Palette (5 colori)
| Colore | Uso | sRGB |
|---|---|---|
| Pietra vulcanica | mura, torri, gradoni | #3E3936 |
| Basalto scuro | basi, altare, roccia dell'isola | #26221F |
| Bronzo | fasce, anelli, saracinesca, bracieri | #8A5A2E |
| Oro antico | stemmi, cornici del portale, rune spente | #B38E3E |
| Prato e sabbia | sopra l'isola / pavimento dell'arena | #55753A / #BFA67E |
Accenti: colori degli 8 elementi solo su stendardi e spicchi del pavimento (poco saturi).

## Pezzi (FBX `cloud/IsolaDraghi/IsolaDraghi.fbx`)
`Isola_Roccia_01..n`, `Isola_Prato`, `Isola_Sentiero`, `Isoletta_1..5`, `Arena_Mura_01..08`
(una per lato, ognuna in piu' oggetti se serve per il budget), `Arena_Torre_<Elemento>`,
`Arena_Portale`, `Arena_Palco`, `Arena_Pavimento`, `Arena_Stendardo_<Elemento>`,
`Arena_Statua_<Elemento>` (segnaposto, Meshy), `Arena_Altare`, `Arrivo`.
Budget: 400.000 triangoli in tutto, ogni pezzo sotto 20.000.

## Organici (Meshy, vedi MESHY_PROMPT.md)
Le due teste di drago del portale, le 8 statue di draghi accucciati sulle torri e le corna
dell'altare: nell'ambiente non c'e' `MESHY_API_KEY` e Hugging Face (backend image-to-3D della
skill) e' bloccato dalla rete, quindi al loro posto ci sono segnaposto `PLACEHOLDER_*` con le
misure giuste e i prompt sono in `MESHY_PROMPT.md`.
