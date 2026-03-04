# Come funziona il quadro (Italiano)

Una breve guida su cosa gira sul Raspberry Pi e come si collegano le parti.

---

## Cosa vedi sulla TV

- **Picframe** mostra uno **slideshow di foto** sulla TV.
- Usa solo **foto** (niente video).
- Le foto vengono da **una sola cartella**: **Pictures** nella home dell’utente sul Pi.

Tutto quello che metti in **Pictures** compare nello slideshow. Aggiungi o togli file lì per cambiare cosa si vede in TV.

---

## Dove stanno le foto

- Sul Pi il percorso è: **`/home/<utente>/Pictures`** (spesso `admin` o `pi`).
- Quella cartella è:
  - L’**unica** che Picframe usa per lo slideshow.
  - La stessa che vedi quando usi il **file manager dal browser** o la **condivisione di rete**.

Quindi: **una cartella = cosa vedi in TV.**

---

## Come aggiungi o togli foto

Hai due modi principali:

1. **FileBrowser (browser)**  
   - Apri **`http://<IP-o-nome-del-Pi>:8080`** da qualsiasi dispositivo.  
   - Accedi con lo stesso utente/password del Pi (o quello impostato dall’installatore per FileBrowser).  
   - Apri la cartella **Pictures** e carica o elimina file.  
   - È il modo più semplice per la maggior parte delle persone.

2. **Samba (rete)**  
   - Da Mac: **Vai → Connetti al server** → `smb://<IP-o-nome-del-Pi>`.  
   - Da Windows: **Esplora file** → `\\<IP-o-nome-del-Pi>`.  
   - Accedi, apri **Pictures** e copia/elimina foto come in una cartella normale.

I passaggi dettagliati sono in **[Come aggiungere foto](come-aggiungere-foto.md)** (italiano) e **[Adding photos](adding-photos.md)** (inglese).

---

## Controllare lo slideshow (Picframe web UI)

- Picframe ha un **pannello di controllo web** sulla porta **9000**.  
   - Apri **`http://<IP-o-nome-del-Pi>:9000`** nel browser per mettere in pausa, avviare o cambiare le impostazioni dello slideshow (se l’installatore l’ha attivato).
- Lo **slideshow** legge solo dalla cartella **Pictures**; il pannello web serve solo a controllare come viene mostrato.

---

## Riassunto

| Cosa | A cosa serve |
|------|------------------|
| **Picframe** | Mostra lo slideshow di foto sulla TV. Legge solo da **Pictures**. |
| **Cartella Pictures** | È l’unica usata per lo slideshow. Aggiungi/togli foto qui. |
| **FileBrowser (porta 8080)** | File manager dal browser per caricare/eliminare file in **Pictures** (e nel resto della home). |
| **Samba** | Condivisione di rete per aprire la home del Pi (e **Pictures**) da Mac/Windows. |
| **Picframe web UI (porta 9000)** | Pagina web per controllare lo slideshow (pausa, play, impostazioni). |

Tutto gira sul **Raspberry Pi**. Tu usi computer o telefono (browser o rete) per gestire la cartella **Pictures**; la TV mostra semplicemente quello che c’è in quella cartella.
