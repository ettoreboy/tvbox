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

show_help() {
  cat << 'HELP'
Usage:
  ./setup-raspberry.sh [OPTIONS] [HOST] [USER] [PASSWORD]
  Or use env: RASP_HOST, RASP_USER, RASP_PASS

Options:
  -h, --help              Show this help
  -l, --language CODE     Set system language (default: en)
                          Codes: it, en, de, fr, es, pt, nl

Examples:
  ./setup-raspberry.sh --language it 192.168.1.10 pi mypassword
  RASP_HOST=pi.local RASP_USER=pi RASP_PASS=secret ./setup-raspberry.sh -l it
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

echo "=== Target: ${RASP_USER}@${RASP_HOST} (language: ${LANG_CODE} -> ${LOCALE_MAIN}) ==="

run_remote() {
  sshpass -p "$RASP_PASS" ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "${RASP_USER}@${RASP_HOST}" "$@"
}

echo ""
echo "1. Updating Debian..."
run_remote 'sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y'

echo ""
echo "2. Fixing locale (enable in locale.gen, then generate)..."
run_remote "sudo apt-get install -y locales && sudo sed -i 's/^# *\\(${LOCALE_MAIN}\\)/\\1/' /etc/locale.gen && sudo sed -i 's/^# *\\(en_US.UTF-8\\)/\\1/' /etc/locale.gen && sudo locale-gen"

echo ""
echo "3. Clearing bad locale vars and setting language to ${LOCALE_MAIN}..."
run_remote "sudo sed -i \"/^LC_CTYPE=/d\" /etc/default/locale 2>/dev/null; sudo update-locale LANG=${LOCALE_MAIN} LC_ALL=${LOCALE_MAIN} LC_CTYPE=${LOCALE_MAIN} LANGUAGE=${LOCALE_LANG}"

echo ""
echo "4. Ensuring locale in environment (persist after reboot)..."
run_remote "echo \"export LANG=${LOCALE_MAIN}
export LC_ALL=${LOCALE_MAIN}
export LC_CTYPE=${LOCALE_MAIN}\" | sudo tee /etc/profile.d/locale.sh"

echo ""
echo "5. Stop SSH from accepting client locale (fixes LC_CTYPE warnings)..."
run_remote 'sudo sed -i "s/^AcceptEnv/#AcceptEnv/" /etc/ssh/sshd_config 2>/dev/null; sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh 2>/dev/null || true'

echo ""
echo "6. Force valid locale in shell startup..."
run_remote 'grep -q "LC_CTYPE='"${LOCALE_MAIN}"'" ~/.bashrc 2>/dev/null || (echo ""; echo "# Fix locale (override bad LC_CTYPE from SSH client)"; echo "export LC_CTYPE='"${LOCALE_MAIN}"'"; echo "export LANG='"${LOCALE_MAIN}"'"; echo "export LC_ALL='"${LOCALE_MAIN}"'"; echo "") >> ~/.bashrc'

echo ""
echo "Done. Current locale on Pi:"
run_remote 'locale'

echo ""
echo "=== Reboot the Pi for all locale changes to apply (optional): ssh ${RASP_USER}@${RASP_HOST} 'sudo reboot'"
