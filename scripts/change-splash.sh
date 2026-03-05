#!/usr/bin/env bash
# Set the Raspberry Pi boot splash screen from an image in the repo (splash/splash.png).
# Run from your computer. Requires: sshpass (or SSH keys). Uses Plymouth on the Pi.
set -e

show_help() {
  cat << 'HELP'
Usage:
  ./scripts/change-splash.sh [OPTIONS] [IMAGE_PATH] [HOST] [USER] [PASSWORD]
  Or use env: RASP_HOST, RASP_USER, RASP_PASS

  IMAGE_PATH  Default: splash/splash.png (relative to repo root)
  Put a PNG there (e.g. 1920x1080) or pass another path.

Options:
  -h, --help    Show this help

Examples:
  ./scripts/change-splash.sh
  ./scripts/change-splash.sh splash/my-logo.png
  ./scripts/change-splash.sh /path/to/splash.png tvbox.local admin secret
HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    *) break ;;
  esac
done

# Load .env from repo root if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
[[ -f "$REPO_ROOT/.env" ]] && source "$REPO_ROOT/.env"

# First non-option arg can be image path
if [[ -n "$1" ]] && [[ "$1" != *@* ]] && [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IMAGE_ARG="$1"
  shift
else
  IMAGE_ARG=""
fi

RASP_HOST="${RASP_HOST:-${1}}"
RASP_USER="${RASP_USER:-${2}}"
RASP_PASS="${RASP_PASS:-${3}}"
HOME_PI="/home/${RASP_USER}"

if [ -z "$RASP_HOST" ] || [ -z "$RASP_USER" ] || [ -z "$RASP_PASS" ]; then
  echo "Error: need HOST, USER, and PASSWORD (env or positional args)."
  echo ""; show_help; exit 1
fi

# Resolve image path
if [[ -n "$IMAGE_ARG" ]]; then
  if [[ -f "$IMAGE_ARG" ]]; then
    SPLASH_SRC="$(cd "$(dirname "$IMAGE_ARG")" && pwd)/$(basename "$IMAGE_ARG")"
  elif [[ -f "$REPO_ROOT/$IMAGE_ARG" ]]; then
    SPLASH_SRC="$REPO_ROOT/$IMAGE_ARG"
  else
    echo "Error: image not found: $IMAGE_ARG"
    exit 1
  fi
else
  SPLASH_SRC="$REPO_ROOT/splash/splash.png"
fi

if [ ! -f "$SPLASH_SRC" ]; then
  echo "Error: splash image not found: $SPLASH_SRC"
  echo "Put a PNG at splash/splash.png or pass an image path."
  exit 1
fi

echo "=== Change boot splash → ${RASP_USER}@${RASP_HOST} (image: $SPLASH_SRC) ==="

run_remote() {
  sshpass -p "$RASP_PASS" ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=60 "${RASP_USER}@${RASP_HOST}" "$@"
}

echo ""
echo "1. Checking Pi is online..."
if ! run_remote 'true' 2>/dev/null; then
  echo "Error: Pi unreachable at ${RASP_USER}@${RASP_HOST}."
  exit 1
fi
echo "   Pi is reachable."

echo ""
echo "2. Ensuring Plymouth is installed..."
run_remote 'sudo apt-get update -y -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y plymouth plymouth-themes pix-plymouth 2>/dev/null || true'

echo ""
echo "3. Copying splash image to Pi..."
run_remote "mkdir -p ${HOME_PI}/.tvbox-splash"
sshpass -p "$RASP_PASS" scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=60 "$SPLASH_SRC" "${RASP_USER}@${RASP_HOST}:${HOME_PI}/.tvbox-splash/splash.png"

echo ""
echo "4. Installing splash and rebuilding initramfs..."
run_remote 'sudo cp ~/.tvbox-splash/splash.png /usr/share/plymouth/themes/pix/splash.png && sudo update-initramfs -u'

echo ""
echo "Done. Reboot the Pi to see the new splash: ssh ${RASP_USER}@${RASP_HOST} 'sudo reboot'"
