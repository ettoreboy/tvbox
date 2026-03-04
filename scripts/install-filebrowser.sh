#!/usr/bin/env bash
# Install FileBrowser (web file manager) on the Raspberry Pi.
# Run from your computer. Requires: sshpass (or use SSH keys and adapt).
set -e

show_help() {
  cat << 'HELP'
Usage:
  ./install-filebrowser.sh [OPTIONS] [HOST] [USER] [PASSWORD]
  Or use env: RASP_HOST, RASP_USER, RASP_PASS

Options:
  -h, --help    Show this help

Examples:
  ./install-filebrowser.sh 192.168.1.10 pi mypassword
  RASP_HOST=pi.local RASP_USER=pi RASP_PASS=secret ./install-filebrowser.sh
HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    *) break ;;
  esac
done

RASP_HOST="${RASP_HOST:-${1}}"
RASP_USER="${RASP_USER:-${2}}"
RASP_PASS="${RASP_PASS:-${3}}"
HOME_PI="/home/${RASP_USER}"
FB_DIR="${HOME_PI}/.config/filebrowser"
FB_DB="${FB_DIR}/filebrowser.db"

if [ -z "$RASP_HOST" ] || [ -z "$RASP_USER" ] || [ -z "$RASP_PASS" ]; then
  echo "Error: need HOST, USER, and PASSWORD (env or positional args)."
  echo ""; show_help; exit 1
fi

echo "=== FileBrowser install → ${RASP_USER}@${RASP_HOST} ==="

run_remote() {
  sshpass -p "$RASP_PASS" ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 "${RASP_USER}@${RASP_HOST}" "$@"
}

echo ""
echo "1. Downloading and installing FileBrowser binary (arm64)..."
run_remote 'curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | sudo bash'

echo ""
echo "2. Creating config directory and bootstrapping first user..."
run_remote "mkdir -p ${FB_DIR}"
run_remote "if [ ! -f ${FB_DB} ]; then
  TMP_PASS=tempBootstrap12
  HASH_TMP=\$(/usr/local/bin/filebrowser hash \$TMP_PASS 2>/dev/null || /usr/bin/filebrowser hash \$TMP_PASS 2>/dev/null)
  (/usr/local/bin/filebrowser -r ${HOME_PI} -p 8080 -a 0.0.0.0 -d ${FB_DB} --username \"${RASP_USER}\" --password \"\$HASH_TMP\" 2>/dev/null &); sleep 3; pkill -f 'filebrowser.*filebrowser.db' 2>/dev/null || true
  /usr/local/bin/filebrowser config set --minimumPasswordLength 6 -d ${FB_DB} 2>/dev/null || true
  HASH_REAL=\$(/usr/local/bin/filebrowser hash \"${RASP_PASS}\" 2>/dev/null || /usr/bin/filebrowser hash \"${RASP_PASS}\" 2>/dev/null)
  /usr/local/bin/filebrowser users update \"${RASP_USER}\" --password \"\$HASH_REAL\" -d ${FB_DB} 2>/dev/null || true
fi"

echo ""
echo "3. Creating systemd user service..."
run_remote 'mkdir -p ~/.config/systemd/user && cat > ~/.config/systemd/user/filebrowser.service << EOF
[Unit]
Description=FileBrowser web file manager

[Service]
ExecStart=/usr/local/bin/filebrowser -r '"${HOME_PI}"' -p 8080 -a 0.0.0.0 -d '"${FB_DB}"'
Environment=HOME='"${HOME_PI}"'
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload && systemctl --user enable filebrowser.service && systemctl --user start filebrowser.service'

echo ""
echo "4. Done. FileBrowser is running."
echo "    Web UI:  http://${RASP_HOST}:8080"
echo "    Login:   ${RASP_USER} / (your password)"
echo "=== Done ==="
