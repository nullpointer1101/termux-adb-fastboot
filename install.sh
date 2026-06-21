#!/data/data/com.termux/files/usr/bin/bash

set -e

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
I='\033[0;90m'
N='\033[0m'

LOG="${TMPDIR:-$PREFIX/tmp}/.termux_adb_install.log"
mkdir -p "${TMPDIR:-$PREFIX/tmp}"

run_step() {
    local msg="$1"
    local cmd="$2"
    echo -e "${I}${msg}...${N}"
    if eval "$cmd" > "$LOG" 2>&1; then
        echo -e "  -> ${G}OK${N}\n"
    else
        echo -e "  -> ${R}FAILED${N}"
        echo -e "${R}${msg} failed${N}"
        echo -e "${I}last output:${N}"
        tail -n 15 "$LOG"
        echo
        exit 1
    fi
}

echo

if [ ! -d "$HOME/storage" ]; then
    echo -e "${Y}Run 'termux-setup-storage' first, then rerun this script${N}\n"
    exit 1
fi

if ! cmd package list packages --user 0 com.termux.api < /dev/null 2>/dev/null | grep -q 'com.termux.api'; then
    echo -e "${R}Termux:API app not found${N}"
    echo -e "Install from: ${G}https://github.com/termux/termux-api/releases/${N}\n"
    exit 1
fi

echo -e "${I}Checking for core package updates...${N}"
pkg update -y > "$LOG" 2>&1 || true

CRITICAL=$(apt list --upgradable 2>/dev/null | grep -E '^(bash|libc\+\+|termux-tools|termux-keyring|dpkg|apt|resolv-conf)/' | cut -d/ -f1 || true)

if [ -n "$CRITICAL" ]; then
    echo -e "  -> ${Y}restart needed${N}\n"
    echo -e "${I}Core packages need upgrading first:${N} $(echo "$CRITICAL" | tr '\n' ' ')"
    echo -e "${I}Upgrading them now...${N}"
    pkg upgrade -y > "$LOG" 2>&1 || true
    echo
    echo -e "${Y}Close Termux completely (run command 'exit' & swipe it away from recent apps), reopen it, then run this script again.${N}"
    exit 0
fi

echo -e "  -> ${G}OK${N}\n"

CREATE_SHORTCUTS=true

if pkg list-installed 2>/dev/null | grep -q "^android-tools/"; then
    echo -e "${Y}android-tools package is already installed${N}\n"
    echo "Do you want to remove it?"
    echo -e "${I}(yes: adb/fastboot work directly)"
    echo -e "(no: you'll use termux-adb/termux-fastboot instead)${N}\n"

    while true; do
        read -p "Remove android-tools? (y/n): " choice < /dev/tty
        case "$choice" in
            [Yy]* )
                echo
                echo -e "${I}Removing android-tools...${N}"
                pkg remove android-tools -y > /dev/null 2>&1 || true
                echo -e "  -> ${G}OK${N}\n"
                CREATE_SHORTCUTS=true
                break
                ;;
            [Nn]* )
                echo
                echo -e "${I}Keeping android-tools installed${N}"
                echo -e "${I}You'll use termux-adb and termux-fastboot instead of direct adb and fastboot${N}\n"
                CREATE_SHORTCUTS=false
                break
                ;;
            * )
                echo "Please answer y or n"
                ;;
        esac
    done
fi

run_step "Upgrading remaining packages" \
"pkg upgrade -y"

run_step "Installing dependencies" \
"pkg install -y coreutils gnupg wget libusb termux-api"

if [ ! -f "$PREFIX/etc/apt/sources.list.d/termux-adb.list" ]; then
    run_step "Adding termux-adb repository" \
"mkdir -p '$PREFIX/etc/apt/sources.list.d' && echo 'deb https://nohajc.github.io termux extras' > '$PREFIX/etc/apt/sources.list.d/termux-adb.list' && wget -qP '$PREFIX/etc/apt/trusted.gpg.d' https://nohajc.github.io/nohajc.gpg && pkg update"
fi

run_step "Installing termux-adb" \
"pkg install -y termux-adb"

if [ "$CREATE_SHORTCUTS" = true ]; then
    run_step "Creating shortcuts" \
"ln -sf '$PREFIX/bin/termux-adb' '$PREFIX/bin/adb' && ln -sf '$PREFIX/bin/termux-fastboot' '$PREFIX/bin/fastboot'"
fi

echo -e "${G}Done!${N}\n"

echo "Now you can use ADB and Fastboot in Termux without root"
echo
echo "For available commands, run:"
if [ "$CREATE_SHORTCUTS" = true ]; then
    echo -e "  ${G}adb help${N}"
    echo -e "  ${G}fastboot help${N}"
else
    echo -e "  ${G}termux-adb help${N}"
    echo -e "  ${G}termux-fastboot help${N}"
fi

echo
echo -e "${I}Credits: nohajc (https://github.com/nohajc) for his work on adb and fastboot for termux.${N}"
echo
