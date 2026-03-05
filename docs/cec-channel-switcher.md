# CEC + HDMI channel switcher

Use the **TV remote** (HDMI CEC) to switch between full-screen “channels” on the TV Box (e.g. photo frame, weather). You can use **number keys** (1, 2, 3, …) or **channel up / channel down** to rotate through the configured full-screen apps.

## How it works

1. **CEC daemon** runs in the same Wayland session as labwc. It listens to `cec-client` for remote key presses.
2. **Number keys** (1–9) jump to that channel. **Channel up** and **channel down** rotate through the configured channels in order (e.g. 1 → 2 → 1 or 1 → 2 → 3 → 1), so you can cycle without remembering numbers.
3. For each channel, the daemon runs **wlrctl window focus** with the channel’s `app_id` (or title). If the app is not running, an optional start command can be run first.

So: **remote key → channel → focus full-screen window (or start then focus)**.

## Key mapping

| Remote key        | Action                                                       |
|-------------------|--------------------------------------------------------------|
| **1** … **9**     | Jump to channel 1, 2, 3, … (if configured)                 |
| **0**             | Jump to channel 1                                            |
| **Channel up**    | Next channel (rotate: 1→2→3→1…)                             |
| **Channel down**  | Previous channel (rotate: …3→2→1→3)                          |
| **Left / Right**  | Run channel-specific command (e.g. `1_left=wtype -k Left`)   |

When you switch channel, the **channel number and app name** are shown briefly on screen (via `notify-send`). With **dunst** you can put the notification top-left: in `~/.config/dunst/dunst.conf` set `origin = top-left`, `geometry = 0x0+10+10`, then restart dunst.

CEC key codes for digits 1–9 are standard (e.g. 0x31 = 1, 0x32 = 2). Channel up/down/left/right codes can be checked on the Pi with `cec-client -m` and pressing the buttons.

## Service

The daemon runs as a **systemd system** service (so its logs go to the system journal and are visible from SSH):

- **Unit**: `/etc/systemd/system/cec-channel.service`
- **User**: the Pi login user (e.g. admin), with `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` set so it can focus windows
- **After**: LightDM (so the graphical session and Wayland are up)
- **Restart**: `on-failure`

It is enabled by the install script and starts automatically after boot when the display manager is up.

## Config

- **Path**: `~/.config/tvbox/channel-config`
- **Format**: one line per channel, key=value:
  - `N=app_id` — channel N (1, 2, 3, …) focuses the window with this app_id (or title).
  - `N_start=command` — optional: run this command if the window is not found (e.g. launch the app).
  - `N_left=command`, `N_right=command` — optional: run when left/right is pressed while channel N is active (e.g. `1_left=wtype -k Left` for Picframe prev/next).

Default config (deployed by `install-cec-channel.sh` when none exists) has one channel:

```
1=picframe
```

To add the **weather channel** (full-screen wttr.in, e.g. Lana, Bolzano), use the separate app script:

```bash
./scripts/install-weather-channel.sh [HOST] [USER] [PASSWORD]
# Optional: different location
./scripts/install-weather-channel.sh -l "Milan,Italy"
```

That script installs Chromium and appends `2=weather` and `2_start=chromium --app="https://wttr.in/..."` to your channel-config. You can also edit `~/.config/tvbox/channel-config` by hand to add or change channels.

**CEC device name (TV list):** The name shown on the TV (e.g. Anynet+ “Discover devices”) defaults to the Pi’s **hostname** (e.g. `tvbox`), or `tvbox` if hostname is not available (max 14 characters). Override by setting `CEC_OSD_NAME` in the service (e.g. in the unit file or via `Environment=CEC_OSD_NAME=MyFrame`).

## Logs

The daemon runs as a system service and logs to the **system journal**. From your computer (SSH):

```bash
ssh admin@tvbox.local 'journalctl -u cec-channel.service -f'
```

Logs are minimal: startup line, key name when you press a button (e.g. `key: 1`, `key: channel up`), and the result (e.g. `channel 1: picframe (ok)`). No cec-client debug output.

## Requirements

- **Python 3** (standard on Raspberry Pi OS)
- **libCEC** and **cec-client** (Debian: `cec-utils`)
- **wlrctl** (for `wlrctl window focus`); may need to be built from source on Raspberry Pi OS
- **notify-send** (Debian: `libnotify-bin`) for the on-screen channel label; optional **dunst** for a notification daemon and top-left position
- For the weather channel (optional): run `install-weather-channel.sh`; it installs **Chromium** and needs network for wttr.in
- Pi must be the **active HDMI source** on the TV for the remote to send keys to the Pi

## Troubleshooting

### "ioctl CEC_S_MODE failed - errno=16" / "unable to open the device on port /dev/cec0"

**errno 16 = EBUSY**: only one process can open the CEC adapter at a time. If you run `cec-client -m` in a terminal and see this, the **cec-channel service** (or another app like Kodi) is already using `/dev/cec0`.

- **To run cec-client manually**: stop the service first:
  ```bash
  sudo systemctl stop cec-channel.service
  cec-client -m
  ```
- **To use the remote for channel switching**: keep the service running and do not run another `cec-client`; the daemon is the single CEC client. Check that key presses are handled with:
  ```bash
  ssh admin@tvbox.local 'journalctl -u cec-channel.service -f'
  ```
  Then press 1 on the remote; you should see `key: 1` and `channel 1: picframe (ok)` (or similar).

If the service is stopped and you still get EBUSY, ensure no other application (e.g. Kodi, another CEC script) is using CEC. Only one CEC client can be active on the Pi.

### Service runs but nothing happens when I press 1 or channel up/down

If the journal shows `started` and `listening (channels 1-2)` but no `key: 1` (or similar) when you press the remote:

1. **Enable debug** so the daemon logs any key-like line it receives (and “unparsed” if it didn’t match):
   ```bash
   sudo systemctl edit cec-channel.service
   ```
   Add under `[Service]`:
   ```ini
   [Service]
   Environment=CEC_DEBUG=1
   ```
   Save, then:
   ```bash
   sudo systemctl daemon-reload && sudo systemctl restart cec-channel.service
   ```
2. Run `journalctl -u cec-channel.service -f`, press 1 and channel up/down.  
   - If you see **`unparsed: ...`**: the daemon is getting cec-client output but the parser doesn’t match; the exact line format can be used to fix the parser.  
   - If you see **`cec: physical address invalid`**: see “No key events / physical address is invalid” below.  
   - If you see **nothing** when pressing keys: cec-client is not receiving key events (TV not sending to Pi, or wrong input).  
3. When done debugging, remove the `Environment=CEC_DEBUG=1` line (or set it to 0) and restart.

### "connection opened" then "could not start CEC communications"

This can happen right after the device was released by another process (e.g. after stopping the service). Wait a few seconds and try again, or rely on the daemon: start the service and use the remote; the daemon will retry if `cec-client` exits.

### No key events / "physical address is invalid" (phys_addr=ffff)

If the service runs and cec-client opens but **no key presses appear** in the journal when you use the remote, and you see **"physical address is invalid"** or **phys_addr=ffff**, the TV is not giving the Pi a valid CEC address, so it doesn’t send remote key presses to the Pi. (Video can still work — this is a CEC/Anynet+ discovery issue, not the HDMI input.)

The daemon uses **normal mode** (not monitor-only) so the Pi registers as a CEC device; some TVs (e.g. Samsung Anynet+) only assign an address and send keys when the device does that.

- Ensure **Anynet+ (HDMI-CEC)** is **On** in the TV (e.g. Settings → Connection → External Device Manager).
- Try another **HDMI port** on the TV; some ports behave better with CEC.
- **Power cycle** the TV (or switch to another input and back) so it rediscovers the Pi.
- If you still see phys_addr=ffff when running `cec-client` manually (with the service stopped), try a different HDMI cable (some don’t carry CEC properly).

### TV "Discover devices" (Anynet+) finds nothing

If the TV's Anynet+ **Discover devices** / device list stays empty:

- **Use HDMI0 on the Pi** (Raspberry Pi 4: the port **next to the USB-C power**). CEC is only active on one port; the other HDMI port does not expose CEC. If the Pi is in HDMI1, the TV will never see it as a CEC device.
- **Do not disable CEC in config:** On the Pi, check `/boot/config.txt` and ensure you do **not** have `hdmi_ignore_cec=1` (that turns off CEC completely). `hdmi_ignore_cec_init=1` only skips the "switch to Pi" at boot; it does not prevent discovery.
- **Diagnostic on the Pi** (with the cec-channel service stopped):
  ```bash
  sudo systemctl stop cec-channel.service
  echo 'scan' | cec-client -s -d 1
  ```
  See whether the Pi sees the TV and what physical address it reports. If the scan shows nothing or the Pi as `f.f.f.f`, the link or config is still wrong.
- **Samsung + Pi CEC** is known to be flaky: some Samsung TVs never list the Pi in Anynet+ even when CEC works for key presses later. If the daemon eventually gets key events (e.g. after normal mode + power cycle), you can ignore "discover" being empty. If nothing works, a **USB HDMI-CEC adapter** (e.g. Pulse-Eight) often works better with Samsung than the Pi's built-in CEC.

## Install

**CEC only** (daemon, config, service – one channel by default):

```bash
./scripts/install-cec-channel.sh [HOST] [USER] [PASSWORD]
# or: RASP_HOST=... RASP_USER=... RASP_PASS=... ./scripts/install-cec-channel.sh
```

**Weather channel** (adds channel 2, installs Chromium, location Lana/Bolzano by default):

```bash
./scripts/install-weather-channel.sh [HOST] [USER] [PASSWORD]
./scripts/install-weather-channel.sh -l "Milan,Italy"   # other location
```

The CEC script installs dependencies (cec-utils, wlrctl, libnotify-bin), the daemon, a minimal default config (1=picframe), and the system service. Use the app scripts for additional channels.
