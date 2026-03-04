# How the picture frame setup works (English)

A short overview of what runs on the Raspberry Pi and how the pieces fit together.

---

## What you see on the TV

- **Picframe** shows a **slideshow of photos** on the TV.
- It only uses **photos** (no video).
- Photos are taken from **one folder**: **Pictures** in the Pi user's home directory.

Anything you put in that **Pictures** folder appears in the slideshow. Add or remove files there to change what's on the TV.

---

## Where photos live

- On the Pi, the path is: **`/home/<user>/Pictures`** (often `admin` or `pi`).
- That folder is:
  - The **only** folder Picframe uses for the slideshow.
  - The same folder you see when you use the **browser file manager** or the **network share**.

So: **one folder = what's on the TV.**

---

## How you add or remove photos

You have two main options:

1. **FileBrowser (browser)**  
   - Open **`http://<Pi-IP-or-name>:8080`** on any device.  
   - Log in with the same user/password as the Pi (or the one the installer set for FileBrowser).  
   - Open the **Pictures** folder and upload or delete files.  
   - Easiest for most people.

2. **Samba (network share)**  
   - From Mac: **Go → Connect to Server** → `smb://<Pi-IP-or-name>`.  
   - From Windows: **File Explorer** → `\\<Pi-IP-or-name>`.  
   - Log in, then open **Pictures** and copy/delete photos as in a normal folder.

Step-by-step instructions: [Adding photos](adding-photos.md) (English) and [Come aggiungere foto](come-aggiungere-foto.md) (Italian).

---

## Controlling the slideshow (Picframe web UI)

- Picframe has a small **web control** on port **9000**.  
- Open **`http://<Pi-IP-or-name>:9000`** in a browser to pause, play, or change slideshow settings (if the installer enabled it).
- The **slideshow itself** only reads from the **Pictures** folder; the web UI just controls how it's shown.

---

## Summary

| Thing | What it does |
|-------|------------------|
| **Picframe** | Shows the photo slideshow on the TV. Reads only from **Pictures**. |
| **Pictures folder** | The only folder used for the slideshow. Add/remove photos here. |
| **FileBrowser (port 8080)** | Web file manager to upload/delete files in **Pictures** (and the rest of the home folder). |
| **Samba** | Network share so you can open the Pi's home (and **Pictures**) from Mac/Windows. |
| **Picframe web UI (port 9000)** | Web page to control the slideshow (pause, play, settings). |

All of this runs on the **Raspberry Pi**. You use your computer or phone (browser or network) to manage the **Pictures** folder; the TV just shows whatever is in that folder.
