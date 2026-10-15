#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
log_section() { echo -e "\n${BOLD}═══ $* ═══${RESET}"; }

# ── Boards ────────────────────────────────────────────────────────────────────
BOARDS=(arduino esp32 pico teensy python node cpp)
TREES=(claude dev)

# ── Parse args ────────────────────────────────────────────────────────────────
SKIP_PREREQS=false
SKIP_VSCODE=false
SKIP_DOCKER=false
SKIP_CONTAINERS=false
SKIP_GH=false
SKIP_UDEV=false
SKIP_SCRIPTS=false
SKIP_SHORTCUTS=false
AUTO_YES=false
BUILD_BOARDS=("${BOARDS[@]}")

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --skip-prereqs       Skip host prerequisite install (git, curl, wget, gpg)
  --skip-vscode        Skip VS Code installation
  --skip-docker        Skip Docker installation
  --skip-containers    Skip building Docker images
  --skip-gh            Skip GitHub CLI installation
  --skip-udev          Skip udev rules installation
  --skip-scripts       Skip new-project symlink installation
  --skip-shortcuts     Skip desktop shortcuts and dash pins
  --boards BOARDS      Comma-separated list of boards to set up (default: all)
                       Available: arduino,esp32,pico,teensy,python,node,cpp
  -y, --yes            Skip confirmation prompts
  -h, --help           Show this help

Examples:
  $0                                    # Full install
  $0 --boards arduino,pico              # Only Arduino and Pico
  $0 --boards python,node,cpp           # Only the software environments
  $0 --skip-containers --skip-udev      # Folders and configs only
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-prereqs)    SKIP_PREREQS=true ;;
        --skip-vscode)     SKIP_VSCODE=true ;;
        --skip-docker)     SKIP_DOCKER=true ;;
        --skip-containers) SKIP_CONTAINERS=true ;;
        --skip-gh)         SKIP_GH=true ;;
        --skip-udev)       SKIP_UDEV=true ;;
        --skip-scripts)    SKIP_SCRIPTS=true ;;
        --skip-shortcuts)  SKIP_SHORTCUTS=true ;;
        --boards)          IFS=',' read -ra BUILD_BOARDS <<< "$2"; shift ;;
        -y|--yes)          AUTO_YES=true ;;
        -h|--help)         usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

# ── Guard: must not run as root ───────────────────────────────────────────────
check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        echo -e "${RED}[ERROR]${RESET} Do not run this script with sudo or as root." >&2
        echo -e "        Run as your normal user — individual steps will call sudo as needed:" >&2
        echo -e "        ${BOLD}bash install.sh --yes${RESET}" >&2
        exit 1
    fi
}

# ── Phase 1: Host prerequisites ───────────────────────────────────────────────
install_host_prereqs() {
    log_section "Host Prerequisites"
    local pkgs=()
    command -v git    &>/dev/null || pkgs+=(git)
    command -v curl   &>/dev/null || pkgs+=(curl)
    command -v wget   &>/dev/null || pkgs+=(wget)
    command -v gpg    &>/dev/null || pkgs+=(gnupg)
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        log_ok "All host prerequisites already installed."
        return
    fi
    log_info "Installing host prerequisites: ${pkgs[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${pkgs[@]}"
    log_ok "Host prerequisites installed."
}

# ── Phase 2: VS Code ──────────────────────────────────────────────────────────
install_vscode() {
    log_section "VS Code"
    if command -v code &>/dev/null; then
        log_ok "VS Code already installed: $(code --version | head -1)"
        return
    fi
    log_info "Installing VS Code..."
    local tmp_gpg
    tmp_gpg=$(mktemp)
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor > "$tmp_gpg"
    sudo install -o root -g root -m 644 "$tmp_gpg" \
        /usr/share/keyrings/microsoft-archive-keyring.gpg
    rm -f "$tmp_gpg"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] \
https://packages.microsoft.com/repos/vscode stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y code
    log_ok "VS Code installed."
}

# ── Phase 3: GitHub CLI (optional) ───────────────────────────────────────────
install_gh_cli() {
    log_section "GitHub CLI"
    if command -v gh &>/dev/null; then
        log_ok "GitHub CLI already installed: $(gh --version | head -1)"
        return
    fi
    log_info "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y gh
    log_ok "GitHub CLI installed. Run 'gh auth login' to authenticate."
}

# ── Phase 4: Docker ──────────────────────────────────────────────────────────
install_docker() {
    log_section "Docker"
    if command -v docker &>/dev/null; then
        log_ok "Docker already installed: $(docker --version)"
    else
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sudo sh
        log_ok "Docker installed."
    fi
    # Always ensure user is in the docker group regardless of whether Docker was just installed
    if id -nG "$USER" | grep -qw docker; then
        log_ok "User '${USER}' already in group 'docker'."
    else
        sudo usermod -aG docker "$USER"
        log_warn "Added '${USER}' to group 'docker'. Log out and back in (or run 'newgrp docker') for it to take effect."
    fi
}

# ── Phase 5: Folder trees ────────────────────────────────────────────────────
create_folder_tree() {
    log_section "Folder Structure"
    for tree in "${TREES[@]}"; do
        for board in "${BUILD_BOARDS[@]}"; do
            local base="$HOME/${tree}/${board}"
            mkdir -p \
                "${base}/projects" \
                "${base}/knowledge/snippets/${board}" \
                "${base}/knowledge/docs/${board}" \
                "${base}/knowledge/datasheets/${board}" \
                "${base}/.devcontainer"
            log_info "Created: ~/${tree}/${board}/"
        done
    done
    log_ok "Folder trees ready."
}

# ── Phase 6: Deploy board configs ────────────────────────────────────────────
deploy_board_configs() {
    log_section "Board Configs"
    for board in "${BUILD_BOARDS[@]}"; do
        local src="${SCRIPT_DIR}/boards/${board}"
        if [[ ! -d "$src" ]]; then
            log_warn "No board template found for '${board}', skipping."
            continue
        fi

        for tree in "${TREES[@]}"; do
            local dest="$HOME/${tree}/${board}"

            # devcontainer (shared — same image for both trees)
            cp "${src}/devcontainer.json" "${dest}/.devcontainer/devcontainer.json"

            # workspace file
            cp "${src}/${board}.code-workspace" "${dest}/${board}.code-workspace"

            log_info "Deployed configs: ~/${tree}/${board}/"
        done
    done
    log_ok "Board configs deployed."
}

# ── Phase 7: Build Docker images ─────────────────────────────────────────────
build_containers() {
    log_section "Docker Images"
    if ! docker info &>/dev/null; then
        log_warn "Docker socket not accessible for current user."
        log_warn "If Docker was just installed, run: newgrp docker"
        log_warn "Then rebuild images with: bash ${SCRIPT_DIR}/install.sh --skip-prereqs --skip-vscode --skip-docker --skip-gh --skip-udev --skip-scripts --yes"
        return
    fi
    for board in "${BUILD_BOARDS[@]}"; do
        local dockerfile="${SCRIPT_DIR}/boards/${board}/Dockerfile"
        if [[ ! -f "$dockerfile" ]]; then
            log_warn "No Dockerfile for '${board}', skipping."
            continue
        fi

        local image_name="dev-${board}:latest"
        if docker image inspect "${image_name}" &>/dev/null; then
            log_warn "Image ${image_name} already exists. To rebuild: docker build -t ${image_name} ${SCRIPT_DIR}/boards/${board}"
        else
            log_info "Building ${image_name} (this may take a while)..."
            if docker build -t "${image_name}" "${SCRIPT_DIR}/boards/${board}"; then
                log_ok "Built: ${image_name}"
            else
                log_warn "Failed to build ${image_name} — fix Dockerfile and re-run: docker build -t ${image_name} ${SCRIPT_DIR}/boards/${board}"
            fi
        fi
    done
}

# ── Phase 8: new-project script ──────────────────────────────────────────────
install_scripts() {
    log_section "Scripts"
    chmod +x "${SCRIPT_DIR}/scripts/new-project.sh"
    local link="/usr/local/bin/new-project"
    if [[ -L "$link" ]] && [[ "$(readlink "$link")" == "${SCRIPT_DIR}/scripts/new-project.sh" ]]; then
        log_ok "new-project already linked."
    else
        sudo ln -sf "${SCRIPT_DIR}/scripts/new-project.sh" "$link"
        log_ok "new-project available system-wide: new-project <board> <name> [tree]"
    fi
}

# ── Phase 9: Claude Code skill ───────────────────────────────────────────────
install_skill() {
    log_section "Claude Code Skill"
    local skill_src="${SCRIPT_DIR}/skills/github-upload.md"
    local skill_dest="${HOME}/.claude/commands/github-upload.md"
    mkdir -p "${HOME}/.claude/commands"
    if [[ -f "$skill_dest" ]] && diff -q "$skill_src" "$skill_dest" &>/dev/null; then
        log_ok "Skill /github-upload already up to date."
    else
        cp "$skill_src" "$skill_dest"
        log_ok "Skill installed: /github-upload (use inside Claude Code)"
    fi
}

# ── Phase 10: udev rules ─────────────────────────────────────────────────────
install_udev_rules() {
    log_section "udev Rules"
    local rules_src="${SCRIPT_DIR}/udev/99-dev-boards.rules"
    local rules_dest="/etc/udev/rules.d/99-dev-boards.rules"

    if [[ ! -f "$rules_src" ]]; then
        log_warn "udev rules file not found at ${rules_src}, skipping."
        return
    fi

    if [[ -f "$rules_dest" ]]; then
        if diff -q "$rules_src" "$rules_dest" &>/dev/null; then
            log_ok "udev rules already up to date."
            return
        fi
        log_info "Updating udev rules..."
    else
        log_info "Installing udev rules..."
    fi

    sudo cp "$rules_src" "$rules_dest"
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    log_ok "udev rules installed: ${rules_dest}"

    # Add user to dialout and plugdev if not already member
    for group in dialout plugdev; do
        if id -nG "$USER" | grep -qw "$group"; then
            log_ok "User '${USER}' already in group '${group}'."
        else
            sudo usermod -aG "$group" "$USER"
            log_warn "Added '${USER}' to group '${group}'. Log out and back in for it to take effect."
        fi
    done
}

# ── Phase 11: Host VS Code extensions ────────────────────────────────────────
install_host_extensions() {
    log_section "VS Code Extensions (host)"
    if ! command -v code &>/dev/null; then
        log_warn "VS Code not found, skipping extension install."
        return
    fi
    local extensions=(
        "ms-vscode-remote.remote-containers"
        "ms-vscode-remote.vscode-remote-extensionpack"
        "eamodio.gitlens"
        "ms-vscode.cpptools"
    )
    for ext in "${extensions[@]}"; do
        if code --list-extensions | grep -q "^${ext}$"; then
            log_ok "Already installed: ${ext}"
        else
            log_info "Installing: ${ext}"
            code --install-extension "${ext}" --force
        fi
    done
}

# ── Phase 12: Desktop shortcuts ──────────────────────────────────────────────
install_shortcuts() {
    log_section "Desktop Shortcuts"
    if ! command -v code &>/dev/null; then
        log_warn "VS Code not found, skipping shortcuts."
        return
    fi
    bash "${SCRIPT_DIR}/scripts/create-shortcuts.sh" "${BUILD_BOARDS[@]}"
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
    log_section "Done"
    echo -e "${GREEN}Setup complete for boards: ${BUILD_BOARDS[*]}${RESET}"
    echo ""
    echo "Next steps:"
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${YELLOW}║  ACTION REQUIRED: Log out and log back in                ║${RESET}"
    echo -e "${YELLOW}║                                                          ║${RESET}"
    echo -e "${YELLOW}║  Group memberships (docker, dialout, plugdev) only take  ║${RESET}"
    echo -e "${YELLOW}║  effect in a new login session. Until you log out:       ║${RESET}"
    echo -e "${YELLOW}║    • VS Code will show 'no permission to run docker'     ║${RESET}"
    echo -e "${YELLOW}║    • USB serial devices may be inaccessible              ║${RESET}"
    echo -e "${YELLOW}║                                                          ║${RESET}"
    echo -e "${YELLOW}║  After logging back in, open a workspace from the dash   ║${RESET}"
    echo -e "${YELLOW}║  then: Ctrl+Shift+P → Reopen in Container                ║${RESET}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "Next steps (after re-login):"
    echo "  1. Open a board workspace from the dash or:"
    for board in "${BUILD_BOARDS[@]}"; do
        echo "       code ~/claude/${board}/${board}.code-workspace"
    done
    echo "  2. In VS Code: Ctrl+Shift+P → 'Dev Containers: Reopen in Container'"
    echo "  3. Inside the container, authenticate Claude Code: claude"
    echo "  4. Create a new project: new-project <board> <name>"
    echo "  5. Upload to GitHub from Claude Code: /github-upload"
    echo "  6. Authenticate GitHub CLI: gh auth login"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    check_not_root
    echo -e "${BOLD}Dev Environment Installer${RESET}"
    echo "Boards: ${BUILD_BOARDS[*]}"
    echo "Trees:  ${TREES[*]} (under ~/)"
    echo ""

    $SKIP_PREREQS    || install_host_prereqs
    $SKIP_VSCODE     || install_vscode
    $SKIP_GH         || install_gh_cli
    $SKIP_DOCKER     || install_docker
    create_folder_tree
    deploy_board_configs
    $SKIP_CONTAINERS || build_containers
    $SKIP_SCRIPTS    || install_scripts
    install_skill
    $SKIP_UDEV       || install_udev_rules
    install_host_extensions
    $SKIP_SHORTCUTS  || install_shortcuts
    print_summary
}

main
