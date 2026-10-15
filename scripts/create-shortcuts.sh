#!/usr/bin/env bash
# create-shortcuts.sh — Create desktop launchers for each board workspace.
# Composites VS Code + board badge icon, writes .desktop file, pins to GNOME dash.
#
# Usage: create-shortcuts.sh [board1 board2 ...]
#        If no boards given, creates shortcuts for all environments.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
log_info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

declare -A BOARD_NAMES=(
    [arduino]="Arduino Dev"
    [esp32]="ESP32 Dev"
    [pico]="Pico Dev"
    [teensy]="Teensy Dev"
    [python]="Python Dev"
    [node]="Node Dev"
    [cpp]="C++ Dev"
)

BOARDS=("$@")
if [[ $# -eq 0 ]]; then
    BOARDS=(arduino esp32 pico teensy python node cpp)
fi

APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons"
mkdir -p "$APPS_DIR" "$ICONS_DIR"

# ── Step 1: Ensure Pillow is available ───────────────────────────────────────
if ! python3 -c "from PIL import Image" &>/dev/null; then
    log_info "Installing python3-pil for icon compositing..."
    sudo apt-get install -y python3-pil
fi

# ── Step 2: Generate composite icons ─────────────────────────────────────────
log_info "Generating composite icons..."
python3 "${SCRIPT_DIR}/make-icons.py" "${BOARDS[@]}"

# ── Step 3: Create .desktop launcher files ───────────────────────────────────
for board in "${BOARDS[@]}"; do
    workspace="$HOME/claude/${board}/${board}.code-workspace"
    desktop_file="$APPS_DIR/dev-env-${board}.desktop"
    icon="$ICONS_DIR/dev-env-${board}.png"
    name="${BOARD_NAMES[$board]:-$board Dev}"

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Name=${name}
Comment=Open ${name} workspace in VS Code Dev Container
Exec=code "$workspace"
Icon=${icon}
Type=Application
Categories=Development;IDE;Electronics;
Keywords=${board};microcontroller;embedded;vscode;devcontainer;
StartupNotify=true
StartupWMClass=Code
EOF
    chmod +x "$desktop_file"
    log_ok "Created launcher: ${name}"
done

# ── Step 4: Update desktop database ──────────────────────────────────────────
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi

# ── Step 5: Pin to GNOME dash ────────────────────────────────────────────────
if command -v gsettings &>/dev/null && gsettings get org.gnome.shell favorite-apps &>/dev/null 2>&1; then
    log_info "Pinning to GNOME dash..."
    python3 - "${BOARDS[@]}" <<'PYEOF'
import sys
import subprocess

boards = sys.argv[1:]
new_entries = [f'dev-env-{b}.desktop' for b in boards]

result = subprocess.run(
    ['gsettings', 'get', 'org.gnome.shell', 'favorite-apps'],
    capture_output=True, text=True
)
raw = result.stdout.strip()

# Parse GVariant list (handles '@as []' for empty list)
import ast
try:
    favorites = ast.literal_eval(raw.replace('@as ', '').strip())
except Exception:
    favorites = []

added = []
for entry in new_entries:
    if entry not in favorites:
        favorites.append(entry)
        added.append(entry)

# Format back to GVariant string list
value = "[" + ", ".join(f"'{e}'" for e in favorites) + "]"
subprocess.run(['gsettings', 'set', 'org.gnome.shell', 'favorite-apps', value],
               check=True)

if added:
    print(f"  Pinned: {', '.join(added)}")
else:
    print("  Already pinned.")
PYEOF
    log_ok "GNOME dash updated."
else
    log_warn "GNOME shell not detected — skipping dash pin."
    log_warn "Launchers are in ~/.local/share/applications/ — drag to dash manually."
fi
