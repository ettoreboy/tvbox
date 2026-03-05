#!/usr/bin/env bash
# Add weather channel (channel 2) to the CEC channel switcher on the Pi.
# Installs Chromium and appends 2=chromium + 2_start=... to ~/.config/tvbox/channel-config.
# Run after install-cec-channel.sh. Uses same .env / RASP_HOST, RASP_USER, RASP_PASS.
set -e

WTR_URL="https://weather.com/it-IT/weather/today/l/ac62971b2c4f0f50f695957dac2a69b7659a3929da214c6ca42a00d9fd766a6e"

show_help() {
  cat << HELP
Usage:
  ./scripts/install-weather-channel.sh [OPTIONS] [HOST] [USER] [PASSWORD]
  Or use env: RASP_HOST, RASP_USER, RASP_PASS

Options:
  -h, --help    Show this help

Examples:
  ./scripts/install-weather-channel.sh
  RASP_HOST=tvbox.local ./scripts/install-weather-channel.sh
HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    *) break ;;
  esac
done

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

echo "=== Weather channel install → ${RASP_USER}@${RASP_HOST} (weather.com Lana/Bolzano) ==="

SSH_CTL="/tmp/ssh-tvbox-${RASP_USER}@${RASP_HOST}-$$"
cleanup_ssh() { ssh -O exit -o ControlPath="$SSH_CTL" "${RASP_USER}@${RASP_HOST}" 2>/dev/null || true; }
trap cleanup_ssh EXIT

run_remote() {
  sshpass -p "$RASP_PASS" ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=60 \
    -o ControlMaster=auto -o ControlPath="$SSH_CTL" -o ControlPersist=120 \
    "${RASP_USER}@${RASP_HOST}" "$@"
}

echo ""
echo "1. Checking Pi is online..."
if ! run_remote 'true' 2>/dev/null; then
  echo "Error: Pi unreachable at ${RASP_USER}@${RASP_HOST}."
  exit 1
fi
echo "   Pi is reachable."

echo ""
echo "2. Installing Chromium..."
run_remote 'sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser 2>/dev/null || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium'
echo "   Chromium installed."

echo ""
echo "3. Adding channel 2 (weather) to CEC config..."
run_remote "mkdir -p ${HOME_PI}/.config/tvbox"
run_remote "touch ${HOME_PI}/.config/tvbox/channel-config"
WTR_CMD="2_start=chromium --password-store=basic --ozone-platform=wayland --kiosk --no-first-run --disable-notifications \"${WTR_URL}\""
if run_remote "grep -q '^2=' ${HOME_PI}/.config/tvbox/channel-config" 2>/dev/null; then
  run_remote "sed -i 's/^2=.*/2=chromium/' ${HOME_PI}/.config/tvbox/channel-config"
  run_remote "grep -v '^2_start=' ${HOME_PI}/.config/tvbox/channel-config > ${HOME_PI}/.config/tvbox/channel-config.tmp && mv ${HOME_PI}/.config/tvbox/channel-config.tmp ${HOME_PI}/.config/tvbox/channel-config"
  run_remote "echo '${WTR_CMD}' >> ${HOME_PI}/.config/tvbox/channel-config"
  echo "   Updated 2=chromium and 2_start (kiosk mode)."
else
  run_remote "echo '' >> ${HOME_PI}/.config/tvbox/channel-config"
  run_remote "echo '# Weather channel (added by install-weather-channel.sh)' >> ${HOME_PI}/.config/tvbox/channel-config"
  run_remote "echo '2=chromium' >> ${HOME_PI}/.config/tvbox/channel-config"
  run_remote "echo '${WTR_CMD}' >> ${HOME_PI}/.config/tvbox/channel-config"
  echo "   Added 2=chromium and 2_start (weather.com kiosk)."
fi

echo ""
echo "4. Restarting cec-channel service to pick up config..."
run_remote "sudo systemctl restart cec-channel.service 2>/dev/null && echo '   Service restarted.' || echo '   cec-channel.service not running (run install-cec-channel.sh first).'"

echo ""
echo "Done. Remote key 2 will open weather.com (Lana/Bolzano) in full screen."
echo "=== Done ==="
