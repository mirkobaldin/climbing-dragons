# VFX Studio — plugin per gli effetti visivi

Pannello laterale di Roblox Studio per creare e ritoccare particelle, raggi e scie.
Usa solo le API native di Studio e le texture installate con Studio: niente internet,
niente `loadstring`, niente `HttpService`. Ogni modifica si annulla con **Ctrl+Z**.

## Installazione

### Metodo 1 — file nella cartella dei plugin (già fatto da Claude su questo PC)
1. Chiudi Roblox Studio.
2. Copia `VFXStudio.lua` in `%LOCALAPPDATA%\Roblox\Plugins\`
   (incolla quel percorso nella barra di Esplora file).
3. Riapri Studio: nella scheda **Plugins** compare il gruppo **VFX Studio**.

### Metodo 2 — "Salva come plugin locale" da Studio
1. Apri un place qualsiasi in Studio.
2. In **Explorer**, tasto destro su **ServerStorage** → **Insert Object** → **Script**.
3. Apri lo script, cancella tutto e incolla l'intero contenuto di `VFXStudio.lua`.
4. Tasto destro sullo script in Explorer → **Save as Local Plugin…** → conferma il nome.
5. Cancella lo script da ServerStorage (il plugin resta installato).
6. Il pulsante **VFX Studio** compare nella scheda **Plugins**.

Per aggiornarlo: sostituisci il file (metodo 1) o ripeti il metodo 2.
Per toglierlo: **Plugins → Manage Plugins**, oppure cancella il file dalla cartella.

## Uso
- **Crea**: seleziona una parte (o un attacco, o un modello) e premi un preset:
  Esplosione, Fuoco, Fumo, Scintille, Aura magica, Neve, Gas tossico, Portale, Fulmini,
  Polvere di stelle. Senza selezione l'effetto va su un supporto invisibile davanti alla camera.
  L'Esplosione è "a colpo" (Rate 0): nel gioco si lancia con
  `emitter:Emit(emitter:GetAttribute("VFX_Burst"))`.
- **Modifica**: seleziona gli emettitori (o i modelli che li contengono). Scegli i colori
  dalla tavolozza, scrivi i valori che vuoi cambiare (campo vuoto = non cambiare;
  per gli intervalli scrivi due numeri, es. `5 12`) e premi **Applica**.
  **Leggi valori** copia i valori del primo emettitore; **Emetti ora** li prova.
- **Raggi e scie**: per un raggio seleziona due oggetti (Ctrl+click) e scegli lo stile
  (Laser, Fulmine, Energia, Catena). Per una scia seleziona la parte che si muove e scegli
  Spada, Vento, Magia o Fuoco. **Togli gli effetti** pulisce la selezione.
