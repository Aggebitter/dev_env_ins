#!/usr/bin/env bash
# uninstall.sh — Remove everything installed by install.sh
# Safe by default: preserves ~/claude/<board>/projects/ and knowledge/ folders
#
# Usage:
#   ./uninstall.sh                        # Remove all boards, keep projects/knowledge
#   ./uninstall.sh --boards arduino,pico  # Specific boards only
#   ./uninstall.sh --purge                # Also delete projects/ and knowledge/
#   ./uninstall.sh --yes                  # Skip confirmation prompts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_skip()    { echo -e "        skipped — $*"; }
log_section() { echo -e "\n${BOLD}═══ $* ═══${RESET}"; }

if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}[ERROR]${RESET} Do not run this script with sudo or as root." >&2
    echo -e "        Run as your normal user: ${BOLD}bash uninstall.sh${RESET}" >&2
    exit 1
fi

BOARDS=(arduino esp32 pico teensy python node cpp)
TREES=(claude dev)
BUILD_BOARDS=("${BOARDS[@]}")
PURGE=false
AUTO_YES=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --boards BOARDS   Comma-separated list of boards (default: all)
  --purge           Also remove projects/ and knowledge/ folders (destructive!)
  --yes             Skip confirmation prompts
  -h, --help        Show this help

What is removed by default:
  - Docker images (dev-<board>:latest)
  - Docker volumes (board caches)
  - Deployed .devcontainer/ and .code-workspace files
  - /usr/local/bin/new-project symlink
  - ~/.claude/commands/github-upload.md skill
  - /etc/udev/rules.d/99-dev-boards.rules

What is preserved by default:
  - ~/claude/<board>/projects/   (your code)
  - ~/claude/<board>/knowledge/  (your docs/snippets)
  - ~/dev/<board>/projects/
  - ~/dev/<board>/knowledge/
  - VS Code, Docker, GitHub CLI (system tools)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --boards) IFS=',' read -ra BUILD_BOARDS <<< "$2"; shift ;;
        --purge)  PURGE=true ;;
        --yes)    AUTO_YES=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

# ── Confirm ───────────────────────────────────────────────────────────────────
confirm() {
    $AUTO_YES && return 0
    echo -en "${YELLOW}$* [y/N]${RESET} "
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# ── Summary before proceeding ─────────────────────────────────────────────────
echo -e "${BOLD}Dev Environment Uninstaller${RESET}"
echo "Boards : ${BUILD_BOARDS[*]}"
echo "Trees  : ${TREES[*]}"
echo "Purge  : $PURGE"
echo ""
if $PURGE; then
    echo -e "${RED}WARNING: --purge will delete projects/ and knowledge/ folders.${RESET}"
    echo -e "${RED}This cannot be undone. Make sure everything is pushed to GitHub.${RESET}"
    echo ""
fi

confirm "Proceed with uninstall?" || { echo "Aborted."; exit 0; }

# ── Step 1: Docker containers + images ───────────────────────────────────────
log_section "Docker Containers & Images"
if command -v docker &>/dev/null; then
    for board in "${BUILD_BOARDS[@]}"; do
        local_image="dev-${board}:latest"
        if docker image inspect "$local_image" &>/dev/null 2>&1; then
            # Stop and remove any containers using this image
            containers=$(docker ps -aq --filter "ancestor=${local_image}" 2>/dev/null)
            if [[ -n "$containers" ]]; then
                log_info "Stopping containers using ${local_image}..."
                docker stop $containers &>/dev/null || true
                docker rm   $containers &>/dev/null || true
                log_ok "Stopped and removed containers for ${local_image}"
            fi
            log_info "Removing image: ${local_image}"
            if docker rmi "$local_image" &>/dev/null; then
                log_ok "Removed: ${local_image}"
            else
                log_warn "Could not remove ${local_image} — close VS Code and retry."
            fi
        else
            log_skip "${local_image} not found"
        fi
    done
else
    log_skip "Docker not installed"
fi

# ── Step 2: Docker volumes ────────────────────────────────────────────────────
log_section "Docker Volumes"
if command -v docker &>/dev/null; then
    volumes=(arduino-cli-data esp-idf-components platformio-packages
             python-uv-cache node-npm-cache node-pnpm-store cpp-ccache)
    for vol in "${volumes[@]}"; do
        if docker volume inspect "$vol" &>/dev/null 2>&1; then
            log_info "Removing volume: ${vol}"
            docker volume rm "$vol" && log_ok "Removed: ${vol}"
        else
            log_skip "volume ${vol} not found"
        fi
    done
else
    log_skip "Docker not installed"
fi

# ── Step 3: Deployed board configs ────────────────────────────────────────────
log_section "Board Config Files"
for tree in "${TREES[@]}"; do
    for board in "${BUILD_BOARDS[@]}"; do
        base="$HOME/${tree}/${board}"
        [[ -d "$base" ]] || continue

        # Safe to always remove — generated by installer
        rm -rf "${base}/.devcontainer"
        rm -f  "${base}/${board}.code-workspace"
        log_ok "Removed configs: ~/${tree}/${board}/"

        if $PURGE; then
            if [[ -d "${base}/projects" ]] || [[ -d "${base}/knowledge" ]]; then
                confirm "  Delete ~/${tree}/${board}/projects/ and knowledge/?" && {
                    rm -rf "${base}/projects" "${base}/knowledge"
                    log_ok "Removed projects/ and knowledge/ for ~/${tree}/${board}/"
                } || log_skip "kept projects/ and knowledge/"
            fi
            # Remove the board folder entirely if now empty
            rmdir "${base}" 2>/dev/null && log_ok "Removed empty dir: ~/${tree}/${board}/" || true
        fi
    done

    # Remove the tree folder if empty (only if purging all boards)
    if $PURGE; then
        rmdir "$HOME/${tree}" 2>/dev/null && log_ok "Removed empty dir: ~/${tree}/" || true
    fi
done

# ── Step 4: new-project symlink ───────────────────────────────────────────────
log_section "Scripts"
if [[ -L "/usr/local/bin/new-project" ]]; then
    sudo rm -f /usr/local/bin/new-project
    log_ok "Removed /usr/local/bin/new-project"
else
    log_skip "new-project symlink not found"
fi

# ── Step 5: Claude Code skill ─────────────────────────────────────────────────
log_section "Claude Code Skill"
skill="${HOME}/.claude/commands/github-upload.md"
if [[ -f "$skill" ]]; then
    rm -f "$skill"
    log_ok "Removed skill: /github-upload"
else
    log_skip "skill not found"
fi

# ── Step 6: udev rules ────────────────────────────────────────────────────────
log_section "udev Rules"
rules="/etc/udev/rules.d/99-dev-boards.rules"
if [[ -f "$rules" ]]; then
    sudo rm -f "$rules"
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    log_ok "Removed udev rules and reloaded."
else
    log_skip "udev rules not found"
fi

# ── Step 7: Desktop shortcuts ─────────────────────────────────────────────────
log_section "Desktop Shortcuts"
removed_shortcuts=()
for board in "${BUILD_BOARDS[@]}"; do
    desktop="${HOME}/.local/share/applications/dev-env-${board}.desktop"
    icon="${HOME}/.local/share/icons/dev-env-${board}.png"
    [[ -f "$desktop" ]] && rm -f "$desktop" && removed_shortcuts+=("$board")
    [[ -f "$icon" ]]    && rm -f "$icon"
done
if [[ ${#removed_shortcuts[@]} -gt 0 ]]; then
    update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
    log_ok "Removed shortcuts: ${removed_shortcuts[*]}"
    # Unpin from GNOME dash
    if command -v gsettings &>/dev/null && gsettings get org.gnome.shell favorite-apps &>/dev/null 2>&1; then
        python3 - "${BUILD_BOARDS[@]}" <<'PYEOF'
import sys, subprocess, ast
boards = sys.argv[1:]
remove = {f'dev-env-{b}.desktop' for b in boards}
result = subprocess.run(['gsettings', 'get', 'org.gnome.shell', 'favorite-apps'],
                        capture_output=True, text=True)
raw = result.stdout.strip()
try:
    favorites = ast.literal_eval(raw.replace('@as ', '').strip())
except Exception:
    favorites = []
favorites = [f for f in favorites if f not in remove]
value = "[" + ", ".join(f"'{e}'" for e in favorites) + "]"
subprocess.run(['gsettings', 'set', 'org.gnome.shell', 'favorite-apps', value])
PYEOF
        log_ok "Unpinned from GNOME dash."
    fi
else
    log_skip "no shortcuts found"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
log_section "Done"
echo -e "${GREEN}Uninstall complete.${RESET}"
echo ""
echo "Preserved (not removed):"
echo "  - VS Code, Docker, GitHub CLI"
for tree in "${TREES[@]}"; do
    for board in "${BUILD_BOARDS[@]}"; do
        base="$HOME/${tree}/${board}"
        [[ -d "${base}/projects" ]]  && echo "  - ~/${tree}/${board}/projects/"
        [[ -d "${base}/knowledge" ]] && echo "  - ~/${tree}/${board}/knowledge/"
    done
done
echo ""
echo "To reinstall: ./install.sh"
