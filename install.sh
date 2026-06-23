#!/bin/bash
set -u

C_RESET="\033[0m"
C_DIM="\033[2m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_YELLOW="\033[33m"
C_CYAN="\033[36m"
C_GRAY="\033[90m"
C_PURPLE="\033[38;2;105;52;175m"

REPO_USER="CRYP70N1CZ"
REPO_NAME="Ronin-Linux"
BIN_URL="https://raw.githubusercontent.com/CRYP70N1CZ/Ronin-Linux/main/ronin/ronin"

get_time() {
    local s=""
    local mot="RoninLinux"
    local clrs=("180;120;255" "160;100;245" "140;85;230" "120;70;210" "105;52;175" "95;45;160" "85;40;145" "75;35;130" "65;30;115" "55;25;100")
    for ((i=0; i<${#mot}; i++)); do
        s+="\033[38;2;${clrs[$i]}m${mot:$i:1}"
    done
    s+="${C_RESET}"
    printf "%b" "${s}${C_GRAY}::${C_RESET}${C_GREEN}[$(date +%H:%M:%S)]${C_RESET}"
}

die() {
    sp_stop "fail" "$1"
    exit 1
}

SPIN_FRAMES=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
SP_PID=""
SP_MSG=""

sp_start() {
    SP_MSG="$1"
    printf "\033[?25l\033[?7l"
    (
        local i=0
        while true; do
            local frame="${SPIN_FRAMES[$((i % ${#SPIN_FRAMES[@]}))]}"
            printf "\r\033[2K%b ${C_CYAN}%s${C_RESET}  %s" "$(get_time)" "$frame" "$SP_MSG"
            i=$((i+1))
            sleep 0.08
        done
    ) &
    SP_PID=$!
    disown "$SP_PID" 2>/dev/null || true
}

sp_stop() {
    local st="${1:-ok}"
    local m="${2:-$SP_MSG}"
    if [[ -n "$SP_PID" ]] && kill -0 "$SP_PID" 2>/dev/null; then
        kill "$SP_PID" 2>/dev/null
        wait "$SP_PID" 2>/dev/null || true
    fi
    SP_PID=""
    printf "\r\033[2K"
    case "$st" in
        ok)   printf "%b ${C_GREEN}✔${C_RESET}  %b\n" "$(get_time)" "$m" ;;
        fail) printf "%b ${C_RED}✖${C_RESET}  %b\n"   "$(get_time)" "$m" ;;
        warn) printf "%b ${C_YELLOW}!${C_RESET}  %b\n" "$(get_time)" "$m" ;;
        *)    printf "%b    %b\n" "$(get_time)" "$m" ;;
    esac
    printf "\033[?7h\033[?25h"
}

log() { printf "%b %b\n" "$(get_time)" "$1"; }

banner() {
    echo ""
    printf "${C_PURPLE}      ██████╗   ██████╗ ███╗   ██╗██╗███╗   ██╗${C_RESET}\n"
    printf "${C_PURPLE}      ██╔══██╗ ██╔═══██╗████╗  ██║██║████╗  ██║${C_RESET}\n"
    printf "${C_PURPLE}      ██████╔╝ ██║   ██║██╔██╗ ██║██║██╔██╗ ██║${C_RESET}\n"
    printf "${C_PURPLE}      ██╔══██╗ ██║   ██║██║╚██╗██║██║██║╚██╗██║${C_RESET}\n"
    printf "${C_PURPLE}      ██║  ██║ ╚██████╔╝██║ ╚████║██║██║ ╚████║${C_RESET}\n"
    printf "${C_PURPLE}      ╚═╝  ╚═╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝${C_RESET}\n"
    printf "  %b  ${C_BOLD}Linux Installer${C_RESET}\n" "$(printf "\033[38;2;105;52;175m%s\033[0m" "Ronin")"
    echo ""
}

cleanup() {
    [[ -n "$SP_PID" ]] && kill "$SP_PID" 2>/dev/null
    printf "\033[?7h\033[?25h"
}
trap cleanup EXIT INT TERM

banner

# --- detect session ---
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
DESKTOP="${XDG_CURRENT_DESKTOP:-unknown}"
WAYLAND=0
[[ "$SESSION_TYPE" == "wayland" ]] && WAYLAND=1
[[ -n "${WAYLAND_DISPLAY:-}" ]] && WAYLAND=1

if [[ "$WAYLAND" -eq 1 ]]; then
    log "${C_CYAN}Session:${C_RESET} Wayland  ${C_CYAN}Desktop:${C_RESET} $DESKTOP"
else
    log "${C_CYAN}Session:${C_RESET} X11  ${C_CYAN}Desktop:${C_RESET} $DESKTOP"
fi

# --- arch check ---
sp_start "Scanning Architecture.."
sleep 0.3
arch=$(uname -m)
if [[ "$arch" != "x86_64" ]]; then
    sp_stop fail "Unsupported Architecture: $arch (Requires x86_64)"
    exit 1
fi
sp_stop ok "x86_64 Architecture Detected!"

# --- dependencies ---
sp_start "Checking dependencies..."
MISSING=""
for pkg in libGL libEGL libX11 libXext libXfixes libXrender libXtst libcrypto; do
    if ! ldconfig -p 2>/dev/null | grep -qi "$pkg\.so"; then
        MISSING="$MISSING $pkg"
    fi
done

if [[ "$WAYLAND" -eq 1 ]]; then
    for pkg in libwayland-client libwayland-egl libwayland-cursor libxkbcommon; do
        if ! ldconfig -p 2>/dev/null | grep -qi "$pkg\.so"; then
            MISSING="$MISSING $pkg"
        fi
    done
fi

if [[ -n "$MISSING" ]]; then
    sp_stop warn "Missing libraries:${MISSING}"
    log "${C_YELLOW}Install them with your package manager before running Ronin.${C_RESET}"
else
    sp_stop ok "All dependencies found!"
fi

# --- input group (wayland) ---
if [[ "$WAYLAND" -eq 1 ]]; then
    if id -nG 2>/dev/null | grep -qw input; then
        log "${C_GREEN}User is in 'input' group${C_RESET} (evdev hotkeys available)"
    else
        log "${C_YELLOW}User is NOT in 'input' group${C_RESET} — global hotkeys may not work on Wayland"
        log "${C_DIM}  Fix: sudo usermod -aG input \$USER  (then relog)${C_RESET}"
    fi
fi

# --- admin access ---
log "${C_CYAN}admin access required${C_RESET} — Enter Your Password."
sudo -v || die "Administrator Permissions Denied!"

# --- stop existing ---
sp_start "Stopping existing Ronin processes..."
sudo killall -9 ronin ronin-bin 2>/dev/null || true
sp_stop ok "Processes stopped!"

# --- clean old kwin scripts ---
if [[ "$WAYLAND" -eq 1 ]] && echo "$DESKTOP" | grep -qi "KDE\|plasma"; then
    QB=$(command -v qdbus6 2>/dev/null || command -v qdbus 2>/dev/null)
    if [[ -n "$QB" ]]; then
        $QB org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript ronin_above >/dev/null 2>&1 || true
    fi
fi

# --- download ---
dest="/usr/local/bin"
sp_start "Downloading Ronin to $dest..."

sudo curl -L -s -o "$dest/ronin-bin" "$BIN_URL" || die "Download failed!"
if ! file "$dest/ronin-bin" 2>/dev/null | grep -q "ELF 64-bit"; then
    sudo rm -f "$dest/ronin-bin"
    die "Downloaded file is not a Linux executable. Check BIN_URL."
fi
sudo chmod +x "$dest/ronin-bin"

# --- launcher wrapper ---
sudo bash -c "cat > '$dest/ronin' << 'WRAPPER'
#!/bin/bash
SESSION=\"\${XDG_SESSION_TYPE:-}\"
WAYLAND_ON=0
[[ \"\$SESSION\" == \"wayland\" ]] && WAYLAND_ON=1
[[ -n \"\${WAYLAND_DISPLAY:-}\" ]] && WAYLAND_ON=1

ENV_ARGS=(
    DISPLAY=\"\${DISPLAY:-}\"
    XAUTHORITY=\"\${XAUTHORITY:-\$HOME/.Xauthority}\"
    XDG_SESSION_TYPE=\"\${XDG_SESSION_TYPE:-}\"
    XDG_CURRENT_DESKTOP=\"\${XDG_CURRENT_DESKTOP:-}\"
    XDG_SESSION_DESKTOP=\"\${XDG_SESSION_DESKTOP:-}\"
    HOME=\"\${HOME:-}\"
    USER=\"\${USER:-}\"
    LOGNAME=\"\${LOGNAME:-\${USER:-}}\"
    LANG=\"\${LANG:-C.UTF-8}\"
    PATH=\"\${PATH:-/usr/local/bin:/usr/bin:/bin}\"
)

if [[ \"\$WAYLAND_ON\" -eq 1 ]]; then
    ENV_ARGS+=(
        WAYLAND_DISPLAY=\"\${WAYLAND_DISPLAY:-}\"
        XDG_RUNTIME_DIR=\"\${XDG_RUNTIME_DIR:-}\"
        DBUS_SESSION_BUS_ADDRESS=\"\${DBUS_SESSION_BUS_ADDRESS:-}\"
    )
fi

if [ \"\$EUID\" -ne 0 ]; then
    exec sudo env \"\${ENV_ARGS[@]}\" \"\$0\" \"\$@\"
fi
exec /usr/local/bin/ronin-bin \"\$@\"
WRAPPER"
sudo chmod +x "$dest/ronin"

usrbin_warn=0
if [ -d /usr/bin ]; then
    if [ ! -e /usr/bin/ronin ] || [ -L /usr/bin/ronin ]; then
        sudo ln -sfn /usr/local/bin/ronin /usr/bin/ronin || die "Failed to create /usr/bin/ronin"
    else
        usrbin_warn=1
    fi
fi

if ! command -v ronin >/dev/null 2>&1 && [ ! -x /usr/bin/ronin ]; then
    die "ronin was installed, but no runnable launcher was found in PATH."
fi

sp_stop ok "Ronin Downloaded and Installed!"
if [ "$usrbin_warn" -eq 1 ]; then
    log "${C_YELLOW}/usr/bin/ronin already exists; installed to /usr/local/bin/ronin${C_RESET}"
fi

# --- summary ---
echo ""
printf "  ${C_GREEN}✔  All done!${C_RESET}\n"
echo ""
printf "  ${C_CYAN}To run Ronin, open your terminal and type:${C_RESET} ${C_BOLD}ronin${C_RESET}\n"
if [[ "$WAYLAND" -eq 1 ]]; then
    echo ""
    printf "  ${C_PURPLE}Wayland Notes:${C_RESET}\n"
    printf "  ${C_DIM}  - Overlay requires alt-tab to focus for menu/hotkeys${C_RESET}\n"
    printf "  ${C_DIM}  - KWin/NVIDIA users: use X11 session if Sober crashes${C_RESET}\n"
    printf "  ${C_DIM}  - For global hotkeys: sudo usermod -aG input \$USER${C_RESET}\n"
fi
echo ""
