# Come aggiungere foto al quadro (TV)

Istruzioni semplici per chi usa il quadro digitale sulla TV.

**Nota per chi installa:** sostituisci `TUO_HOST` (es. `tvbox.local` o l’IP del Pi), `TUO_UTENTE` e `TUA_PASSWORD` con i valori usati in installazione, poi condividi questo foglio agli utenti finali.

---

## Cosa fa il quadro

Sulla TV scorrono le foto che sono nella cartella **Pictures** del Raspberry Pi.  
Per aggiungere o togliere foto si può usare **il browser** (più semplice) oppure la **rete di casa** (Mac/PC).

---

## Dal browser (gestione file – consigliato)

1. Sul computer o sul telefono apri **Chrome**, **Safari** o un altro **browser**.
2. Nella barra degli indirizzi scrivi:  
   **`http://TUO_HOST:8080`**  
   (es. `http://tvbox.local:8080` o `http://192.168.1.10:8080`)  
   e premi Invio.
3. Accedi con:
   - **Utente:** `TUO_UTENTE`
   - **Password:** `TUA_PASSWORD`
4. Si apre la gestione file. Clicca sulla cartella **Pictures**.
5. Per **aggiungere foto**: clicca **Upload** (Carica) e scegli le foto dal computer.  
   Oppure **trascina** le foto nella finestra del browser.
6. Per **togliere** una foto: selezionala, clicca sui tre puntini (⋮) e scegli **Elimina**.

Le foto in **Pictures** compaiono da sole sulla TV.

---

## Da Mac (rete)

1. Apri **Finder**.
2. In alto: **Vai** → **Connetti al server** (oppure premi **Cmd + K**).
3. Scrivi:  
   **`smb://TUO_HOST`**  
   (es. `smb://tvbox.local` o `smb://192.168.1.10`)  
   e clicca **Connetti**.
4. Quando chiede nome e password:
   - **Nome:** `TUO_UTENTE`
   - **Password:** `TUA_PASSWORD`
5. Si apre la cartella del quadro. Doppio clic su **Pictures**.
6. **Trascina** le foto dal Mac nella finestra **Pictures**.  
   Le foto compaiono da sole sulla TV (a volte dopo qualche secondo).

Per **togliere** una foto: apri **Pictures**, seleziona la foto e spostala nel Cestino (o cancellala).

---

## Da Windows (PC)

1. Apri **Esplora file**.
2. Nella barra in alto scrivi:  
   **`\\TUO_HOST`**  
   (es. `\\tvbox.local` o `\\192.168.1.10`)  
   e premi Invio.
3. Nome utente: **TUO_UTENTE**  
   Password: **TUA_PASSWORD**
4. Apri la cartella **Pictures**.
5. **Copia e incolla** (o trascina) le foto dentro **Pictures**.  
   Le foto compaiono sulla TV.

---

## Ricapitolo

| Cosa | Dove / Come |
|------|------------------|
| **Gestione file dal browser** | **http://TUO_HOST:8080** (TUO_UTENTE / TUA_PASSWORD) |
| Nome in rete / IP | **TUO_HOST** (es. tvbox.local o IP del Pi) |
| Utente | `TUO_UTENTE` |
| Password | `TUA_PASSWORD` |
| Cartella foto | **Pictures** (è quella che il quadro usa per lo slideshow) |

Solo quella cartella **Pictures** è quella che il quadro usa per lo slideshow.  
Tutto quello che metti lì viene mostrato sulla TV.
