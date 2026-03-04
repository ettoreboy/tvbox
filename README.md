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

**4. Reboot the Pi** so the picture frame and (if used) LightDM autologin and FileBrowser start correctly.

## After installation

| What | URL or address |
|------|----------------|
| **Picframe web UI** (control slideshow) | `http://<RASP_HOST>:9000` |
| **FileBrowser** (upload photos) | `http://<RASP_HOST>:8080` |
| **Samba** (Mac: Connect to Server) | `smb://<RASP_HOST>` |
| **Photos folder** | Directory **Pictures** in the shared home or in FileBrowser |

Photos placed in the **Pictures** folder (via FileBrowser or Samba) appear in the slideshow on the TV.  
You can give end users a simple instruction sheet (see `docs/COME-AGGIUNGERE-FOTO.md`) after replacing placeholders with your host and credentials.

## Credits and thanks

This setup uses and builds on the following projects:

- **[Picframe](https://github.com/helgeerbe/picframe)** by Helge Erbe – Picture frame viewer for Raspberry Pi (pi3d), MQTT/HTTP control, [MIT License](https://github.com/helgeerbe/picframe/blob/main/LICENSE).
- **[pi3d](https://github.com/pi3d/pi3d)** – 3D graphics library for Raspberry Pi, used by Picframe.
- **[FileBrowser](https://filebrowser.org/)** – Web-based file manager; [GitHub](https://github.com/filebrowser/filebrowser), [Apache 2.0](https://github.com/filebrowser/filebrowser/blob/master/LICENSE).
- **[labwc](https://labwc.github.io/)** – Wayland compositor used on the Pi for the picture frame session.
- **[TheDigitalPictureFrame.com](https://www.thedigitalpictureframe.com/)** – Guides and community around Pi-based digital picture frames.

## Repository layout

| Path | Purpose |
|------|--------|
| `README.md` | This file – overview, usage, credits |
| `scripts/setup-raspberry.sh` | Debian update, locale fix, set language (`-l it` etc.) |
| `scripts/install-photo-frame.sh` | Installs Picframe, Samba, LightDM autologin, nightly apt; `-l` for locale |
| `scripts/install-filebrowser.sh` | Installs FileBrowser (web file manager) |
| `docs/raspberry-screensaver-plan.md` | Planning notes and options (photos-only, no video) |
| `docs/COME-AGGIUNGERE-FOTO.md` | **Template** instructions for end users (replace placeholders) |
| `CONTRIBUTING.md` | How to contribute (issues and pull requests) |
| `scripts/setup-github.sh` | Apply repo settings with \`gh\` (disable wiki/projects, protect \`main\`) |
| `.env.example` | Env template – copy to `.env` and fill in |

## Contributing

We use **issues** for bugs and ideas and **pull requests** for changes. To apply repo settings (disable wiki, protect `main`, require PRs), run from repo root: `./scripts/setup-github.sh` (requires [gh](https://cli.github.com/) auth). See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Scripts and docs in this repository are provided as-is. Use of third-party software (Picframe, FileBrowser, etc.) is subject to their respective licenses.
