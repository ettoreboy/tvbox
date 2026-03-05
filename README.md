# TV Box – Raspberry Pi digital picture frame

Simple setup to turn a **Raspberry Pi** (connected to a TV) into a **photo slideshow** with:

- **Picframe** – slideshow on the TV (photos only, no video)
- **FileBrowser** – web UI to upload and manage photos
- **Samba** – optional network share for adding photos from Mac/PC
- **LightDM autologin** – no login screen on boot
- **Nightly apt updates** – automatic at 3:00 AM

Scripts run from your machine (Mac/Linux) via SSH. Credentials via env vars or arguments.

## Requirements

- Raspberry Pi 4 (or compatible) with **Debian / Raspberry Pi OS**, connected to the same network
- SSH access to the Pi (user + password or key)
- On your computer: **sshpass** (for password-based SSH from scripts), or use SSH keys and adapt the scripts

```bash
# macOS
brew install sshpass
```

## Configuration

Use **environment variables** or **script arguments** for the Pi's host, user, and password.

```bash
export RASP_HOST=192.168.178.33    # or your Pi IP / hostname (e.g. tvbox.local)
export RASP_USER=admin             # SSH user on the Pi
export RASP_PASS=your_password     # SSH password (or use SSH keys and remove sshpass)
```

Or pass them when running a script:

```bash
./scripts/setup-raspberry.sh [OPTIONS] [HOST] [USER] [PASSWORD]
./scripts/install-photo-frame.sh [OPTIONS] [HOST] [USER] [PASSWORD]
./scripts/install-filebrowser.sh [OPTIONS] [HOST] [USER] [PASSWORD]
./scripts/install-cec-channel.sh [OPTIONS] [HOST] [USER] [PASSWORD]
./scripts/install-weather-channel.sh [OPTIONS] [HOST] [USER] [PASSWORD]
./scripts/change-splash.sh [IMAGE_PATH] [HOST] [USER] [PASSWORD]
```

All scripts support `-h` or `--help`. Setup and photo-frame support `-l` / `--language CODE` (e.g. `it`, `en`, `de`, `fr`, `es`, `pt`, `nl`; default `en`).

Scripts exit with usage if host, user, or password are missing.

## Usage

**1. Initial Pi setup (optional)**  
Update Debian, fix locale warnings, set system language (default: English):

```bash
./scripts/setup-raspberry.sh
# With language: ./scripts/setup-raspberry.sh -l it 192.168.1.10 pi mypassword
```

**2. Install the picture frame (Picframe + LightDM autologin + Samba + nightly updates)**  
Installs Picframe, configures autologin, and sets up the web control (port 9000). Use `-l it` (or other code) to match the locale from step 1:

```bash
./scripts/install-photo-frame.sh
# e.g. Italian: ./scripts/install-photo-frame.sh -l it
```

**3. Install the web file manager (FileBrowser)**  
Adds a web UI to upload/manage files (port 8080). First user is created with the same username/password as `RASP_USER`/`RASP_PASS`:

```bash
./scripts/install-filebrowser.sh
```

**4. (Optional) Install CEC channel switcher**  
Use the TV remote (HDMI CEC) to switch “channels”: number keys 1, 2, … or channel up/down to rotate between configured full-screen apps (e.g. Picframe, weather). See [docs/cec-channel-switcher.md](docs/cec-channel-switcher.md). For the weather channel (key 2), run `install-weather-channel.sh` after the CEC install.

```bash
./scripts/install-cec-channel.sh
./scripts/install-weather-channel.sh          # optional: add channel 2 (weather, Lana/Bolzano)
./scripts/install-weather-channel.sh -l Milan  # optional: other location
```

**5. Reboot the Pi** so the picture frame and (if used) LightDM autologin, FileBrowser, and CEC daemon start correctly.

**6. (Optional) Custom boot splash**  
Put a PNG in `splash/splash.png` (e.g. 1920×1080), then run `./scripts/change-splash.sh`. Reboot the Pi to see it.

## After installation

| What | URL or address |
|------|----------------|
| **Picframe web UI** (control slideshow) | `http://<RASP_HOST>:9000` |
| **FileBrowser** (upload photos) | `http://<RASP_HOST>:8080` |
| **Samba** (Mac: Connect to Server) | `smb://<RASP_HOST>` |
| **Photos folder** | Directory **Pictures** in the shared home or in FileBrowser |

Photos placed in the **Pictures** folder (via FileBrowser or Samba) appear in the slideshow on the TV.

**Docs for end users (replace placeholders with your host/user/password):**
- **Adding photos:** [English](docs/adding-photos.md) · [Italiano](docs/come-aggiungere-foto.md)
- **How it works (Picframe, FileBrowser, folders):** [English](docs/how-it-works.md) · [Italiano](docs/come-funziona.md)

## Credits and thanks

This setup uses and builds on the following projects:

- **[Picframe](https://github.com/helgeerbe/picframe)** by Helge Erbe – Picture frame viewer for Raspberry Pi (pi3d), MQTT/HTTP control, [MIT License](https://github.com/helgeerbe/picframe/blob/main/LICENSE).
- **[pi3d](https://github.com/pi3d/pi3d)** – 3D graphics library for Raspberry Pi, used by Picframe.
- **[FileBrowser](https://filebrowser.org/)** – Web-based file manager; [GitHub](https://github.com/filebrowser/filebrowser), [Apache 2.0](https://github.com/filebrowser/filebrowser/blob/master/LICENSE).
- **[labwc](https://labwc.github.io/)** – Wayland compositor used on the Pi for the picture frame session.
- **[TheDigitalPictureFrame.com](https://www.thedigitalpictureframe.com/)** – Guides and community around Pi-based digital picture frames.

Contributing: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

This repository is licensed under the [MIT License](LICENSE). Third-party software (Picframe, FileBrowser, etc.) is subject to their respective licenses.
