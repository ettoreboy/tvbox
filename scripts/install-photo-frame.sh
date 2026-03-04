#!/usr/bin/env bash
# Install Picframe (photos-only digital picture frame) on the Raspberry Pi.
# Run from your computer. Requires: sshpass (or use SSH keys and adapt).
set -e

LOCALE_MAP() {
  case "$1" in it) echo "it_IT.UTF-8" ;; en) echo "en_US.UTF-8" ;; de) echo "de_DE.UTF-8" ;; fr) echo "fr_FR.UTF-8" ;; es) echo "es_ES.UTF-8" ;; pt) echo "pt_PT.UTF-8" ;; nl) echo "nl_NL.UTF-8" ;; *) echo "en_US.UTF-8" ;; esac
}

show_help() {
  cat << 'HELP'
Usage:
  ./install-photo-frame.sh [OPTIONS] [HOST] [USER] [PASSWORD]
  Or use env: RASP_HOST, RASP_USER, RASP_PASS

Options:
  -h, --help              Show this help
  -l, --language CODE     Picframe locale (default: en). Codes: it, en, de, fr, es, pt, nl

Examples:
  ./install-photo-frame.sh --language it 192.168.1.10 pi mypassword
  RASP_HOST=pi.local RASP_USER=pi RASP_PASS=secret ./install-photo-frame.sh -l it
HELP
}

LANG_CODE="en"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -l|--language) LANG_CODE="${2:-en}"; shift 2 ;;
    --language=*) LANG_CODE="${1#*=}"; shift ;;
    *) break ;;
  esac
done

RASP_HOST="${RASP_HOST:-${1}}"
RASP_USER="${RASP_USER:-${2}}"
RASP_PASS="${RASP_PASS:-${3}}"
HOME_PI="/home/${RASP_USER}"
PICFRAME_LOCALE=$(LOCALE_MAP "$LANG_CODE")

if [ -z "$RASP_HOST" ] || [ -z "$RASP_USER" ] || [ -z "$RASP_PASS" ]; then
  echo "Error: need HOST, USER, and PASSWORD (env or positional args)."
  echo ""; show_help; exit 1
fi

echo "=== Picframe (photos-only) install → ${RASP_USER}@${RASP_HOST} (locale: ${PICFRAME_LOCALE}) ==="

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
echo "3. Installing packages (libsdl2, Wayland, labwc, Samba)..."
run_remote 'sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git libsdl2-dev xwayland labwc wlr-randr samba udiskie udisks2'

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
echo "8. Initializing picframe config..."
run_remote "printf '\n\n\n' | ${HOME_PI}/venv_picframe/bin/picframe -i ${HOME_PI}/ 2>/dev/null || true"

echo ""
echo "9. Enabling HTTP web UI and locale ${PICFRAME_LOCALE} in configuration.yaml..."
run_remote 'CFG='"${HOME_PI}"'/picframe_data/config/configuration.yaml; sed -i "s|pic_dir:.*|pic_dir: \"'"${HOME_PI}"'/Pictures\"|" "$CFG"; sed -i "s/locale:.*/locale: '"${PICFRAME_LOCALE}"'/" "$CFG"; sed -i "s/use_http:.*/use_http: True/" "$CFG"; sed -i "s/port:.*/port: 9000/" "$CFG"; sed -i "s/display_w:.*/display_w: null/" "$CFG"; sed -i "s/display_h:.*/display_h: null/" "$CFG"; grep -q "use_http: True" "$CFG" || echo -e "\nhttp:\n  use_http: True\n  port: 9000" >> "$CFG"; grep -q "display_w:" "$CFG" || echo -e "\nviewer:\n  display_w: null\n  display_h: null" >> "$CFG"'

echo ""
echo "10. Creating start_picframe.sh and labwc autostart..."
run_remote "cat > ${HOME_PI}/start_picframe.sh << 'STARTEOF'
#!/bin/bash
source ~/venv_picframe/bin/activate
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
echo "11. Configuring LightDM autologin..."
run_remote 'if command -v lightdm >/dev/null 2>&1; then sudo mkdir -p /etc/lightdm/lightdm.conf.d && echo "[Seat:*]
autologin-user='"${RASP_USER}"'
autologin-session=labwc" | sudo tee /etc/lightdm/lightdm.conf.d/90-autologin.conf > /dev/null && sudo chmod 644 /etc/lightdm/lightdm.conf.d/90-autologin.conf && systemctl --user disable picframe.service 2>/dev/null; echo "LightDM autologin set."; else systemctl --user enable picframe.service 2>/dev/null; echo "No LightDM; enabled picframe user service."; fi'

echo ""
echo "12. Done. Reboot the Pi to start the picture frame."
echo "    Web UI: http://${RASP_HOST}:9000"
echo "    Photos: Samba \\\\${RASP_HOST}\\\\${RASP_USER} or scp to ${RASP_USER}@${RASP_HOST}:~/Pictures/"
echo "    Reboot: ssh ${RASP_USER}@${RASP_HOST} 'sudo reboot'"
echo "=== Done ==="
