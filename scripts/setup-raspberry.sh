#!/usr/bin/env bash
# Configure Raspberry Pi: update Debian, fix locale, set system language.
# Run from your computer. Requires: sshpass (or use SSH keys and adapt).
set -e

# Supported: it, en, de, fr, es, pt, nl (add more as needed: lang_TERRITORY.UTF-8)
LOCALE_MAP() {
  case "$1" in
    it) echo "it_IT.UTF-8 it_IT:it" ;;
    en) echo "en_US.UTF-8 en_US:en" ;;
    de) echo "de_DE.UTF-8 de_DE:de" ;;
    fr) echo "fr_FR.UTF-8 fr_FR:fr" ;;
    es) echo "es_ES.UTF-8 es_ES:es" ;;
    pt) echo "pt_PT.UTF-8 pt_PT:pt" ;;
    nl) echo "nl_NL.UTF-8 nl_NL:nl" ;;
    *)  echo "en_US.UTF-8 en_US:en" ;;
  esac
}

# WiFi regulatory country (ISO 3166-1 alpha-2) from language code
WIFI_COUNTRY_MAP() {
  case "$1" in
    it) echo "IT" ;;
    en) echo "GB" ;;
    de) echo "DE" ;;
    fr) echo "FR" ;;
    es) echo "ES" ;;
    pt) echo "PT" ;;
    nl) echo "NL" ;;
    *)  echo "GB" ;;
  esac
}

show_help() {
  cat << 'HELP'
Usage:
  ./scripts/setup-raspberry.sh [OPTIONS] [HOST] [USER] [PASSWORD]
  Or use env: RASP_HOST, RASP_USER, RASP_PASS

Options:
  -h, --help              Show this help
  -l, --language CODE     Set system language (default: en)
                          Codes: it, en, de, fr, es, pt, nl

Examples:
  ./scripts/setup-raspberry.sh --language it 192.168.1.10 pi mypassword
  RASP_HOST=pi.local RASP_USER=pi RASP_PASS=secret ./scripts/setup-raspberry.sh -l it
HELP
}

# Parse options
LANG_CODE="en"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -l|--language)
      LANG_CODE="${2:-en}"
      shift 2
      ;;
    --language=*)
      LANG_CODE="${1#*=}"
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Load .env from repo root if present (no export needed in .env)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
[[ -f "$REPO_ROOT/.env" ]] && source "$REPO_ROOT/.env"

RASP_HOST="${RASP_HOST:-${1}}"
RASP_USER="${RASP_USER:-${2}}"
RASP_PASS="${RASP_PASS:-${3}}"

if [ -z "$RASP_HOST" ] || [ -z "$RASP_USER" ] || [ -z "$RASP_PASS" ]; then
  echo "Error: need HOST, USER, and PASSWORD (env or positional args)."
  echo ""
  show_help
  exit 1
fi

LOCALE_LINE=$(LOCALE_MAP "$LANG_CODE")
LOCALE_MAIN="${LOCALE_LINE%% *}"       # e.g. it_IT.UTF-8
LOCALE_LANG="${LOCALE_LINE#* }"       # e.g. it_IT:it
WIFI_COUNTRY=$(WIFI_COUNTRY_MAP "$LANG_CODE")

echo "=== Target: ${RASP_USER}@${RASP_HOST} (language: ${LANG_CODE} -> ${LOCALE_MAIN}, WiFi country: ${WIFI_COUNTRY}) ==="

run_remote() {
  sshpass -p "$RASP_PASS" ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "${RASP_USER}@${RASP_HOST}" "$@"
}

echo ""
echo "Updating Debian..."
run_remote 'sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y'

echo ""
echo "Fixing locale (enable in locale.gen, then generate)..."
run_remote "sudo apt-get install -y locales && sudo sed -i 's/^# *\\(${LOCALE_MAIN}\\)/\\1/' /etc/locale.gen && sudo sed -i 's/^# *\\(en_US.UTF-8\\)/\\1/' /etc/locale.gen && sudo locale-gen"

echo ""
echo "Clearing bad locale vars and setting language to ${LOCALE_MAIN}..."
run_remote "sudo sed -i \"/^LC_CTYPE=/d\" /etc/default/locale 2>/dev/null; sudo update-locale LANG=${LOCALE_MAIN} LC_ALL=${LOCALE_MAIN} LC_CTYPE=${LOCALE_MAIN} LANGUAGE=${LOCALE_LANG}"

echo ""
echo "Ensuring locale in environment (persist after reboot)..."
run_remote "echo \"export LANG=${LOCALE_MAIN}
export LC_ALL=${LOCALE_MAIN}
export LC_CTYPE=${LOCALE_MAIN}\" | sudo tee /etc/profile.d/locale.sh"

echo ""
echo "Stop SSH from accepting client locale (fixes LC_CTYPE warnings)..."
run_remote 'sudo sed -i "s/^AcceptEnv/#AcceptEnv/" /etc/ssh/sshd_config 2>/dev/null; sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh 2>/dev/null || true'

echo ""
echo "Force valid locale in shell startup..."
run_remote 'grep -q "LC_CTYPE='"${LOCALE_MAIN}"'" ~/.bashrc 2>/dev/null || (echo ""; echo "# Fix locale (override bad LC_CTYPE from SSH client)"; echo "export LC_CTYPE='"${LOCALE_MAIN}"'"; echo "export LANG='"${LOCALE_MAIN}"'"; echo "export LC_ALL='"${LOCALE_MAIN}"'"; echo "") >> ~/.bashrc'

echo ""
echo "Checking power (under-voltage / throttling)..."
run_remote 'T=$(vcgencmd get_throttled 2>/dev/null); echo "   $T"; case "${T#*=}" in 0x0) echo "   OK (no under-voltage or throttling)." ;; *) echo "   WARNING: under-voltage or throttling detected. Use a better power supply (5V 3A USB-C for Pi 4)." ;; esac'

echo ""
echo "Disabling under-voltage warning icon (use a proper PSU to fix the cause)..."
run_remote 'CFG=/boot/firmware/config.txt; [ -f "$CFG" ] || CFG=/boot/config.txt; if [ -f "$CFG" ]; then sudo grep -q "^avoid_warnings=" "$CFG" && sudo sed -i "s/^avoid_warnings=.*/avoid_warnings=2/" "$CFG" || echo "avoid_warnings=2" | sudo tee -a "$CFG" >/dev/null; echo "   Set avoid_warnings=2 in $CFG"; fi'

echo ""
echo "Setting WiFi country to ${WIFI_COUNTRY} (removes antenna power/channel limits)..."
run_remote 'CFG=/boot/firmware/config.txt; [ -f "$CFG" ] || CFG=/boot/config.txt; if [ -f "$CFG" ]; then sudo grep -q "^country=" "$CFG" && sudo sed -i "s/^country=.*/country='"${WIFI_COUNTRY}"'/" "$CFG" || echo "country='"${WIFI_COUNTRY}"'" | sudo tee -a "$CFG" >/dev/null; echo "   Set country='"${WIFI_COUNTRY}"' in $CFG. Reboot to apply."; fi'

echo ""
echo "Done. Current locale on Pi:"
run_remote 'locale'

echo ""
echo "=== Reboot the Pi for locale and WiFi country to apply: ssh ${RASP_USER}@${RASP_HOST} 'sudo reboot'"
