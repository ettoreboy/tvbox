#!/usr/bin/env bash
# Install Picframe (photos-only digital picture frame) on the Raspberry Pi.
# Run from your computer. Requires: sshpass (or use SSH keys and adapt).
set -e

show_help() {
  cat << 'HELP'
Usage:
  ./scripts/install-photo-frame.sh [OPTIONS] [HOST] [USER] [PASSWORD]
  Or use env: RASP_HOST, RASP_USER, RASP_PASS

Options:
  -h, --help    Show this help

Examples:
  ./scripts/install-photo-frame.sh 192.168.1.10 pi mypassword
  RASP_HOST=pi.local RASP_USER=pi RASP_PASS=secret ./scripts/install-photo-frame.sh
  # Or use .env from repo root: RASP_HOST, RASP_USER, RASP_PASS
HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    *) break ;;
  esac
done

# Load .env from repo root if present (same as install-cec-channel.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
[[ -f "$REPO_ROOT/.env" ]] && source "$REPO_ROOT/.env"

RASP_HOST="${RASP_HOST:-${1}}"
RASP_USER="${RASP_USER:-${2}}"
RASP_PASS="${RASP_PASS:-${3}}"
HOME_PI="/home/${RASP_USER}"

if [ -z "$RASP_HOST" ] || [ -z "$RASP_USER" ] || [ -z "$RASP_PASS" ]; then
  echo "Error: need HOST, USER, and PASSWORD (env or positional args)."
  echo ""; show_help; exit 1
fi

echo "=== Picframe (photos-only) install → ${RASP_USER}@${RASP_HOST} ==="

run_remote() {
  sshpass -p "$RASP_PASS" ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 "${RASP_USER}@${RASP_HOST}" "$@"
}

echo ""
echo "1. Set ${RASP_USER} password and console autologin..."
run_remote 'echo "'"${RASP_USER}"':'"${RASP_PASS}"'" | sudo chpasswd; sudo mkdir -p /etc/systemd/system/getty@tty1.service.d && echo "[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin '"${RASP_USER}"' --noclear %I 38400 linux" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf && sudo systemctl enable getty@tty1'

echo ""
echo "2. Enabling user linger..."
run_remote "sudo loginctl enable-linger ${RASP_USER}"

echo ""
echo "3. Installing packages (libsdl2, Wayland, labwc, LightDM, Samba)..."
run_remote 'sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git libsdl2-dev xwayland labwc lightdm wlr-randr samba udiskie udisks2'

echo ""
echo "4. Enabling nightly apt auto-updates (3:00 AM)..."
run_remote 'echo "# Nightly apt update and upgrade at 3:00 AM
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root env DEBIAN_FRONTEND=noninteractive apt-get -qq update && apt-get -y -o Dpkg::Options::=--force-confold upgrade >> /var/log/apt-nightly.log 2>&1" | sudo tee /etc/cron.d/apt-nightly-upgrade > /dev/null && sudo chmod 644 /etc/cron.d/apt-nightly-upgrade'

echo ""
echo "5. Configuring Samba..."
run_remote 'sudo apt-get install -y samba 2>/dev/null; (sudo pdbedit -L 2>/dev/null | grep -q "^'"${RASP_USER}"':") || (echo "'"${RASP_PASS}"'\n'"${RASP_PASS}"'" | sudo smbpasswd -a -s '"${RASP_USER}"'); echo "[global]
security = user
workgroup = WORKGROUP
server role = standalone server
map to guest = never
encrypt passwords = yes
client min protocol = SMB2
client max protocol = SMB3

['"${RASP_USER}"']
comment = Picture frame media
browseable = yes
path = '"${HOME_PI}"'
read only = no
create mask = 0775
directory mask = 0775" | sudo tee /etc/samba/smb.conf > /dev/null && sudo systemctl restart smbd'

echo ""
echo "6. Creating Pictures and DeletedPictures directories..."
run_remote "mkdir -p ${HOME_PI}/Pictures ${HOME_PI}/DeletedPictures"

echo ""
echo "7. Creating Python venv and installing picframe..."
run_remote "python3 -m venv ${HOME_PI}/venv_picframe && ${HOME_PI}/venv_picframe/bin/pip install --break-system-packages picframe 2>/dev/null || ${HOME_PI}/venv_picframe/bin/pip install picframe"

echo ""
echo "8. Patching pi3d for Wayland app_id (picframe) so CEC channel switcher can focus it..."
run_remote 'PF="${HOME_PI}/venv_picframe/lib/python3.13/site-packages/pi3d/util/DisplayOpenGL.py"
if [ -f "$PF" ] && ! grep -q "SDL_VIDEO_WAYLAND_WMCLASS" "$PF" 2>/dev/null; then
  perl -i -0pe "s/(import sdl2\n)(      stat = sdl2\.SDL_Init)/$1      sdl2.SDL_SetHint(b\"SDL_VIDEO_WAYLAND_WMCLASS\", b\"picframe\")\n$2/s" "$PF"
  echo "   Patched pi3d DisplayOpenGL.py (Wayland app_id=picframe)"
else
  echo "   pi3d already patched or file not found"
fi'

echo ""
echo "9. Initializing picframe config..."
run_remote "printf '\n\n\n' | ${HOME_PI}/venv_picframe/bin/picframe -i ${HOME_PI}/ 2>/dev/null || true"

echo ""
echo "10. Pointing Picframe at Pictures folder and enabling web UI (port 9000)..."
run_remote 'CFG='"${HOME_PI}"'/picframe_data/config/configuration.yaml; sed -i "s|pic_dir:.*|pic_dir: \"'"${HOME_PI}"'/Pictures\"|" "$CFG"; sed -i "s/use_http:.*/use_http: True/" "$CFG"; sed -i "s/port:.*/port: 9000/" "$CFG"; grep -q "use_http: True" "$CFG" || echo -e "\nhttp:\n  use_http: True\n  port: 9000" >> "$CFG"'

echo ""
echo "11. Creating start_picframe.sh and labwc autostart..."
run_remote "cat > ${HOME_PI}/start_picframe.sh << 'STARTEOF'
#!/bin/bash
source ~/venv_picframe/bin/activate
# Wayland app_id for wlrctl focus (CEC channel switcher)
export SDL_VIDEO_WAYLAND_WMCLASS=picframe
picframe &
STARTEOF
chmod +x ${HOME_PI}/start_picframe.sh"

run_remote "mkdir -p ${HOME_PI}/.config/labwc ${HOME_PI}/.config/systemd/user"
run_remote "echo '${HOME_PI}/start_picframe.sh' > ${HOME_PI}/.config/labwc/autostart"
run_remote "cat > ${HOME_PI}/.config/labwc/rc.xml << 'RCEOF'
<windowRules>
    <windowRule identifier=\"*\" serverDecoration=\"no\" />
    <windowRule identifier=\"*\">
      <action name=\"Maximize\" direction=\"both\"/>
    </windowRule>
    <!-- labwc black terminal (WL-1) - keep below picframe -->
    <windowRule identifier=\"labwc\" title=\"*WL*\">
      <action name=\"ToggleLayerBelow\"/>
    </windowRule>
    <!-- keyring password prompt - keep below -->
    <windowRule identifier=\"gcr-prompter\" title=\"*\">
      <action name=\"ToggleLayerBelow\"/>
    </windowRule>
</windowRules>
RCEOF"
run_remote "cat > ${HOME_PI}/.config/systemd/user/picframe.service << 'SVCEOF'
[Unit]
Description=PictureFrame (labwc)

[Service]
ExecStart=/usr/bin/labwc
Restart=always

[Install]
WantedBy=default.target
SVCEOF"
echo ""
echo "12. Configuring LightDM autologin (no login screen on boot)..."
PI_UID=$(run_remote "id -u ${RASP_USER}" | tr -d '\r\n')
run_remote 'sudo mkdir -p /etc/lightdm/lightdm.conf.d && echo "[Seat:*]
autologin-user='"${RASP_USER}"'
autologin-session=labwc" | sudo tee /etc/lightdm/lightdm.conf.d/90-autologin.conf > /dev/null && sudo chmod 644 /etc/lightdm/lightdm.conf.d/90-autologin.conf && export XDG_RUNTIME_DIR=/run/user/'"${PI_UID}"' && (systemctl --user stop picframe.service 2>/dev/null || true) && (systemctl --user disable picframe.service 2>/dev/null || true) && echo "   LightDM autologin set, old user service disabled."'

echo ""
echo "13. Starting picframe (if display already up)..."
PI_UID=$(run_remote "id -u ${RASP_USER}" | tr -d '\r\n')
run_remote 'if pgrep -u '"${PI_UID}"' labwc >/dev/null 2>&1 && ! pgrep -f "picframe" >/dev/null 2>&1; then
  cd ~ && source venv_picframe/bin/activate && SDL_VIDEO_WAYLAND_WMCLASS=picframe nohup picframe > /tmp/picframe.log 2>&1 &
  sleep 3
  pgrep -f picframe >/dev/null && echo "   Picframe started." || echo "   Picframe may have failed; check /tmp/picframe.log"
fi
if pgrep -u '"${PI_UID}"' labwc >/dev/null 2>&1; then
  WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/'"${PI_UID}"' wlrctl toplevel minimize app_id:labwc 2>/dev/null || true
  WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/'"${PI_UID}"' wlrctl toplevel focus app_id:python3.13 2>/dev/null || WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/'"${PI_UID}"' wlrctl toplevel focus app_id:picframe 2>/dev/null || true
  echo "   Brought picframe to front (minimized labwc terminal)."
fi'

echo ""
echo "14. Done."
echo "    Web UI: http://${RASP_HOST}:9000"
echo "    Photos: Samba \\\\${RASP_HOST}\\\\${RASP_USER} or scp to ${RASP_USER}@${RASP_HOST}:~/Pictures/"
echo "    If picframe did not start: ssh ${RASP_USER}@${RASP_HOST} '~/start_picframe.sh' or reboot"
echo "=== Done ==="
