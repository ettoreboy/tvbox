# How to add photos to the picture frame (TV)

Simple instructions for anyone using the digital frame on the TV.

**Note for whoever set it up:** Replace `YOUR_HOST` (e.g. `tvbox.local` or the Pi’s IP), `YOUR_USER` and `YOUR_PASSWORD` with the values used during installation, then share this sheet with the people who will add photos.

---

## What the frame does

The TV shows a slideshow of photos from the **Pictures** folder on the Raspberry Pi.  
You can add or remove photos using **the browser** (easiest) or your **home network** (Mac/PC).

---

## From the browser (file manager – recommended)

1. On your computer or phone, open **Chrome**, **Safari**, or another **browser**.
2. In the address bar type:  
   **`http://YOUR_HOST:8080`**  
   (e.g. `http://tvbox.local:8080` or `http://192.168.1.10:8080`)  
   and press Enter.
3. Log in with:
   - **Username:** `YOUR_USER`
   - **Password:** `YOUR_PASSWORD`
4. The file manager opens. Click the **Pictures** folder.
5. To **add photos**: click **Upload** and choose photos from your device.  
   Or **drag** photos into the browser window.
6. To **remove** a photo: select it, click the three dots (⋮) and choose **Delete**.

Photos in **Pictures** automatically appear on the TV.

---

## From Mac (network)

1. Open **Finder**.
2. Menu: **Go** → **Connect to Server** (or press **Cmd + K**).
3. Type:  
   **`smb://YOUR_HOST`**  
   (e.g. `smb://tvbox.local` or `smb://192.168.1.10`)  
   and click **Connect**.
4. When it asks for name and password:
   - **Name:** `YOUR_USER`
   - **Password:** `YOUR_PASSWORD`
5. The frame’s folder opens. Double‑click **Pictures**.
6. **Drag** photos from your Mac into the **Pictures** window.  
   They appear on the TV (sometimes after a few seconds).

To **remove** a photo: open **Pictures**, select the photo and move it to Trash (or delete it).

---

## From Windows (PC)

1. Open **File Explorer**.
2. In the address bar type:  
   **`\\YOUR_HOST`**  
   (e.g. `\\tvbox.local` or `\\192.168.1.10`)  
   and press Enter.
3. Username: **YOUR_USER**  
   Password: **YOUR_PASSWORD**
4. Open the **Pictures** folder.
5. **Copy and paste** (or drag) photos into **Pictures**.  
   They appear on the TV.

---

## Quick reference

| What | Where / How |
|------|------------------|
| **File manager in browser** | **http://YOUR_HOST:8080** (YOUR_USER / YOUR_PASSWORD) |
| Network name / IP | **YOUR_HOST** (e.g. tvbox.local or Pi IP) |
| Username | `YOUR_USER` |
| Password | `YOUR_PASSWORD` |
| Photo folder | **Pictures** (this is the folder the frame uses for the slideshow) |

Only the **Pictures** folder is used for the slideshow.  
Whatever you put there is shown on the TV.
