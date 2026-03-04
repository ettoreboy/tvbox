# Raspberry Pi TV screensaver – plan

**Goal:** Use the Pi (tvbox @ 192.168.178.38) as a screensaver connected to a TV: rotate **photos** from a **USB drive** (or network), with **web UI** to manage/configure. **Photos only – no video.**

---

## Chosen solution: Picframe (Pi3D PictureFrame)

| Requirement | Solution |
|-------------|----------|
| Photos | Picframe reads from `~/Pictures` or any path (e.g. USB mount) |
| Display | Wayland + labwc; Picframe fullscreen on HDMI |
| Web UI | Built-in HTTP server on **port 9000** (enable in `configuration.yaml`) |
| Optional | MQTT for Home Assistant; Samba to add photos over network |
| USB | Use **udiskie** to auto-mount USB; set `pic_dir` in config to `/media/admin/<label>` or `~/Pictures` and copy from USB |

---

## Requirements summary

| Requirement | Notes |
|-------------|--------|
| Source | USB stick/drive or `~/Pictures` (Samba) – **photos only** |
| Display | Rotation/slideshow on TV (HDMI) |
| Control | Web UI at `http://tvbox:9000` (or `http://192.168.178.38:9000`) |
| Already done | Debian updated, Italian locale |

---

## Research – main options

### 1. **Picframe (Pi3D PictureFrame)** – best for photos + web UI

- **What it is:** High-quality image viewer (crossfade, matting, 4K). Official stack for “digital picture frame” on Pi with Bookworm/Wayland.
- **Photos:** ✅ From any folder → can use **USB** by pointing `pic_dir` to the USB mount (e.g. with [Udiskie](https://dev.to/leocolman/expand-your-digital-picture-frame-use-cases-with-pi3d-integrated-usb-media-stick-support-using-2737)).
- **Videos:** ❌ No video support (images only).
- **Web UI:** ✅ Built-in **HTTP server** on port 9000 (`use_http: True` in `configuration.yaml`). Serves a local config/control page (LAN only).
- **App-like control:** ✅ **MQTT** → integrates with **Home Assistant** as a device (pause, next slide, display on/off, etc.).
- **Stack:** Python venv, `picframe`, Wayland + labwc (or similar). Images added via Samba share or by copying to `~/Pictures` (or USB mount path).
- **Best for:** Photo-only frames with web + HA control and USB as source.

**References:** [TheDigitalPictureFrame.com](https://www.thedigitalpictureframe.com/) (Bookworm/Wayland guide), [picframe GitHub](https://github.com/helgeerbe/picframe), [Configuration wiki](https://github.com/helgeerbe/picframe/wiki/Configuration).

---

### 2. **Raspberry Slideshow (Binary Emotions)** – photos + videos from USB

- **What it is:** Dedicated OS/image that boots to a slideshow. Reads from USB and/or remote sources.
- **Photos + videos:** ✅ **Images and videos** (mainly MP4). USB: put files in **root** of a single-partition stick (vFAT/NTFS/ext4); optional `media.conf` on same USB for options.
- **Web UI:** ❌ No built-in web UI. Configuration via **media.conf** on the USB (or network shares, Dropbox, Google Drive, URLs).
- **Control:** Change content by updating USB or remote inventory; no in-browser control.
- **Caveat:** “Release” build has limited features; full versions may require donation. Pi 5 supported in recent builds.
- **Best for:** Simple “plug USB and play” with both photos and videos, no need for web UI.

**References:** [Raspberry Slideshow download/docs](https://www.binaryemotions.com/raspberry-slideshow-download/), [SourceForge](https://sourceforge.net/projects/raspberrypictureframe/).

---

### 3. **PiViewer** – web UI + slideshow

- **What it is:** Python/PySide6 slideshow viewer with **Flask web interface** on port 8080.
- **Features:** Multiple monitors, rotation interval, shuffle, remote control via web. Optional Spotify album art. systemd service.
- **USB / video:** To be confirmed (likely folder-based; USB = use mounted path). Video support unclear from repo summary.
- **Best for:** If you want a single app with web UI and can accept “folder on disk” (e.g. mounted USB) and possibly photos-only.

**Reference:** [PiViewer GitHub](https://github.com/tpersp/piviewer).

---

### 4. **Custom / hybrid**

- **Idea:** Lightweight slideshow (e.g. **feh** or **mpv** in slideshow mode for images/video) reading from a fixed folder (e.g. `/media/usb0` or `/home/admin/SlideshowMedia`), plus a small **Flask/FastAPI** web UI to:
  - List/add/delete media (or point to USB path),
  - Set interval, shuffle on/off,
  - Optional: simple auth, mobile-friendly layout.
- **Pros:** Full control, USB + video + web UI, no dependency on a specific “frame” OS.
- **Cons:** More setup and maintenance (scripting, systemd, auto-mount USB).

---

## Recommendation

- **If you need both photos and videos + web/app control:**  
  - **Preferred:** **Custom/hybrid** (USB mount + mpv/feh + small web UI), **or**  
  - **Simpler but no web UI:** **Raspberry Slideshow** (USB root + media.conf); control = swap USB or edit config.

- **If photos only are enough:**  
  - **Picframe** is the strongest option: great quality, HTTP UI on port 9000, MQTT/Home Assistant, and USB possible via Udiskie + `pic_dir`.

---

## Suggested next steps

1. **Choose path**
   - **A)** Photos only → install **Picframe** + Udiskie, point `pic_dir` to USB mount, enable HTTP and optionally MQTT/HA.
   - **B)** Photos + videos, no web UI → try **Raspberry Slideshow** (write image to SD, use USB for media).
   - **C)** Photos + videos + web UI → design **custom** solution (USB auto-mount + player + Flask/FastAPI UI).

2. **If Picframe (A)**
   - Install Raspberry Pi OS Bookworm (if not already) with Wayland + labwc (or follow TheDigitalPictureFrame.com one-click guide).
   - Install Udiskie, configure auto-mount, set `pic_dir` to USB mount path.
   - Enable HTTP in `configuration.yaml`; optionally set up MQTT for Home Assistant.

3. **If Raspberry Slideshow (B)**
   - Download release image, flash with Balena Etcher to SD, boot Pi from it.
   - Prepare USB: one partition, root folder with images/videos (and optional `media.conf`).

4. **If custom (C)**
   - Add udev/udiskie (or fstab) rule to mount USB to a fixed path.
   - Implement or choose a player (mpv for video + image slideshow, or separate image/video scripts).
   - Implement small web UI (Flask/FastAPI) for source path, interval, shuffle, and basic media list.

---

## Your Pi context

- **Host:** tvbox @ 192.168.178.38  
- **OS:** Debian 13 (trixie), Raspberry Pi kernel (aarch64).  
- **User:** admin (SSH).  
- **Note:** The install script uses user `admin` and paths under `/home/admin`.

---

## Installation (photos-only Picframe)

**Script:** `install-photo-frame.sh` – run from this Mac; it SSHs to the Pi and installs everything.

**What it does:**

1. **System:** Console autologin as `admin` (so Wayland/labwc can start at boot).
2. **Packages:** `libsdl2-dev`, `xwayland`, `labwc`, `wlr-randr`, `samba` (to add photos from Mac/PC), optional `udiskie` for USB auto-mount.
3. **Picframe:** Python venv under `/home/admin/venv_picframe`, `pip install picframe`, init config.
4. **Config:** `~/picframe_data/config/configuration.yaml` – `use_http: true`, port 9000, `pic_dir: ~/Pictures`, locale `it_IT.UTF-8`.
5. **Autostart:** labwc starts at boot; labwc runs `start_picframe.sh` → picframe.

**Run from this machine:**

```bash
./install-photo-frame.sh
```

Optional args: `./install-photo-frame.sh [HOST] [USER] [PASSWORD]` (default: 192.168.178.38 admin admin).

**After install:** Reboot the Pi. Add photos to `~/Pictures` via Samba (e.g. `smb://192.168.178.38/admin`) or copy over SSH. Open **http://192.168.178.38:9000** in a browser for the Picframe web UI.

**USB later:** Install `udiskie`; plug USB; mount appears under `/media/admin/`. Set `pic_dir` in `configuration.yaml` to that path (or symlink `~/Pictures` to it) and restart picframe.
