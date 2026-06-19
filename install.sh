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
BIN_URL="https://raw.githubusercontent.com/CRYP70N1CZ/Ronin-Linux/main/ronin"

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

log "${C_CYAN}admin access required${C_RESET} — Enter Your Password."
sudo -v || die "Administrator Permissions Denied!"

sp_start "Scanning Architecture.."
sleep 0.4
arch=$(uname -m)
if [[ "$arch" != "x86_64" ]]; then
    sp_stop fail "Unsupported Architecture: $arch (Requires x86_64)"
    exit 1
fi
sp_stop ok "x86_64 Architecture Detected!"

sp_start "Stopping existing Ronin processes..."
sudo killall -9 ronin 2>/dev/null || true
sp_stop ok "Processes stopped!"

dest="/usr/local/bin"
sp_start "Downloading Ronin to $dest..."

sudo curl -L -s -o "$dest/ronin-bin" "$BIN_URL" || die "Download failed!"
sudo chmod +x "$dest/ronin-bin"

sudo bash -c "cat > '$dest/ronin' << 'EOF'
#!/bin/bash
if [ \"\$EUID\" -ne 0 ]; then
    exec sudo DISPLAY=\"\$DISPLAY\" XAUTHORITY=\"\${XAUTHORITY:-\$HOME/.Xauthority}\" \"\$0\" \"\$@\"
fi
exec /usr/local/bin/ronin-bin \"\$@\"
EOF"
sudo chmod +x "$dest/ronin"

sp_stop ok "Ronin Downloaded and Installed!"

echo ""
printf "  ${C_GREEN}✔  All done!${C_RESET}\n"
echo ""
printf "  ${C_CYAN}To run Ronin, open your terminal and type:${C_RESET} ${C_BOLD}ronin${C_RESET}\n"
echo ""
