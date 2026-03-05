#!/usr/bin/env bash
# Install CEC channel switcher daemon on the Raspberry Pi (CEC only: daemon, config, service).
# Run from your computer. Requires: sshpass, and the tvbox repo (cec-channel-daemon/).
# For apps (e.g. weather channel) use the separate scripts: install-weather-channel.sh, etc.
set -e

show_help() {
  cat << 'HELP'
Usage:
  ./scripts/install-cec-channel.sh [OPTIONS] [HOST] [USER] [PASSWORD]
  Or use env: RASP_HOST, RASP_USER, RASP_PASS

Options:
  -h, --help    Show this help

Examples:
  ./scripts/install-cec-channel.sh 192.168.1.10 pi mypassword
  RASP_HOST=tvbox.local RASP_USER=admin RASP_PASS=secret ./scripts/install-cec-channel.sh
HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    *) break ;;
  esac
done

# Load .env from repo root if present (no export needed in .env)
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

DAEMON_SRC="$REPO_ROOT/cec-channel-daemon/cec-channel.py"
CONFIG_SRC="$REPO_ROOT/cec-channel-daemon/channel-config.default"

if [ ! -f "$DAEMON_SRC" ] || [ ! -f "$CONFIG_SRC" ]; then
  echo "Error: CEC daemon files not found. Run this script from the tvbox repo (cec-channel-daemon/ must be present)."
  exit 1
fi

echo "=== CEC channel switcher install → ${RASP_USER}@${RASP_HOST} ==="

# Reuse one SSH connection for all steps (much faster than opening 15+ separate connections)
SSH_CTL="/tmp/ssh-tvbox-${RASP_USER}@${RASP_HOST}-$$"
cleanup_ssh() { ssh -O exit -o ControlPath="$SSH_CTL" "${RASP_USER}@${RASP_HOST}" 2>/dev/null || true; }
trap cleanup_ssh EXIT

run_remote() {
  sshpass -p "$RASP_PASS" ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=60 \
    -o ControlMaster=auto -o ControlPath="$SSH_CTL" -o ControlPersist=120 \
    "${RASP_USER}@${RASP_HOST}" "$@"
}

run_scp() {
  sshpass -p "$RASP_PASS" scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=60 \
    -o ControlMaster=auto -o ControlPath="$SSH_CTL" -o ControlPersist=120 \
    "$@"
}

echo ""
echo "1. Checking Pi is online..."
if ! run_remote 'true' 2>/dev/null; then
  echo "Error: Pi unreachable at ${RASP_USER}@${RASP_HOST}. Check host, SSH, and credentials."
  exit 1
fi
echo "   Pi is reachable."

echo ""
echo "2. Installing cec-utils (libCEC, cec-client) and python3..."
run_remote 'sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cec-utils python3'

echo ""
echo "3. Installing Wayland tools (wlrctl, wtype) and libnotify-bin (for channel OSD)..."
run_remote 'if command -v wlrctl &>/dev/null; then echo "   wlrctl already installed."; elif sudo apt-get install -y wlrctl 2>/dev/null; then echo "   wlrctl installed from apt."; else echo "   wlrctl not in apt."; fi'
run_remote 'if command -v wtype &>/dev/null; then echo "   wtype already installed."; else sudo apt-get install -y wtype 2>/dev/null && echo "   wtype installed from apt." || echo "   wtype not in apt."; fi'
run_remote 'sudo DEBIAN_FRONTEND=noninteractive apt-get install -y libnotify-bin 2>/dev/null && echo "   libnotify-bin installed (notify-send for channel OSD)." || echo "   libnotify-bin not installed; channel label on screen will be skipped."'

echo ""
echo "4. Creating directories and adding ${RASP_USER} to video group (for CEC device access)..."
run_remote "mkdir -p ${HOME_PI}/.local/bin ${HOME_PI}/.config/tvbox ${HOME_PI}/.config/systemd/user"
run_remote "sudo usermod -aG video ${RASP_USER}"

echo ""
echo "5. Deploying daemon and config..."
run_scp "$DAEMON_SRC" "${RASP_USER}@${RASP_HOST}:${HOME_PI}/.local/bin/cec-channel.py"
run_remote "chmod +x ${HOME_PI}/.local/bin/cec-channel.py"
run_remote "python3 -c \"import ast; ast.parse(open('${HOME_PI}/.local/bin/cec-channel.py').read())\"" && echo "   Daemon deployed (Python)." || echo "   Warning: daemon may be corrupt."
# Default config only if not present (do not overwrite user edits)
run_remote "mkdir -p ${HOME_PI}/.config/tvbox"
if run_remote "[ -f ${HOME_PI}/.config/tvbox/channel-config ]" 2>/dev/null; then
  run_remote "echo '   channel-config already exists; leaving it unchanged.'"
else
  run_scp "$CONFIG_SRC" "${RASP_USER}@${RASP_HOST}:${HOME_PI}/.config/tvbox/channel-config"
  run_remote "echo '   Created default channel-config (1=picframe). Use install-weather-channel.sh etc. for more channels.'"
fi

echo ""
echo "6. Installing systemd system service (logs to system journal, visible from SSH)..."
PI_UID=$(run_remote "id -u ${RASP_USER}" | tr -d '\r\n')
run_remote 'sudo tee /etc/systemd/system/cec-channel.service > /dev/null << EOF
[Unit]
Description=CEC channel switcher (TV remote -> Wayland focus)
After=lightdm.service
PartOf=lightdm.service

[Service]
Type=simple
User='"${RASP_USER}"'
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/'"${PI_UID}"'
ExecStart=/usr/bin/python3 '"${HOME_PI}"'/.local/bin/cec-channel.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF'

echo ""
echo "7. Enabling and starting cec-channel service..."
run_remote "systemctl --user disable cec-channel.service 2>/dev/null || true; sudo systemctl daemon-reload && sudo systemctl enable cec-channel.service && sudo systemctl restart cec-channel.service"

echo ""
echo "8. Verifying service..."
run_remote "sudo systemctl is-active cec-channel.service && echo '   Service is active.' || (echo '   Service failed. Check: sudo journalctl -u cec-channel.service -n 30'; exit 1)"

echo ""
echo "9. Done. CEC channel switcher is installed."
echo "   Config: ${RASP_USER}@${RASP_HOST}:~/.config/tvbox/channel-config"
echo "   Logs from SSH: ssh ${RASP_USER}@${RASP_HOST} 'journalctl -u cec-channel.service -f'"
echo "   For more channels (e.g. weather): ./scripts/install-weather-channel.sh [HOST] [USER] [PASSWORD]"
echo "=== Done ==="
