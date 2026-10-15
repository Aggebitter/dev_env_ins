# Dev Environment Installer

Sets up an MCU development environment using VS Code dev containers. Each board family gets
an isolated workspace with its own toolchain, build/flash/debug tasks, and knowledge base.

## Supported Boards

| Board | Toolchain | Flash | Debug |
|-------|-----------|-------|-------|
| Arduino | arduino-cli, avr-gcc | arduino-cli upload | cortex-debug (ARM boards) |
| ESP32 | ESP-IDF (latest stable) | esptool / idf.py | OpenOCD + xtensa-gdb |
| Raspberry Pi Pico | arm-none-eabi-gcc, cmake | picotool / USB drag | cortex-debug + OpenOCD |
| Teensy | PlatformIO | pio upload (HalfKay) | cortex-debug (4.x) |

## Software Environments

Plain software (no hardware) using the same container/workspace pattern:

| Env | Toolchain | Run / Test | Debug |
|-----|-----------|------------|-------|
| Python | Python 3.12, uv, ruff, pytest | `uv run`, `uv run pytest` | debugpy |
| Node | Node 24 LTS, npm, pnpm, TypeScript | `npm start` (native .ts), `node --test` | Node inspector |
| C/C++ | gcc/g++, clang, CMake + Ninja, ccache, valgrind | `./build/main`, `ctest` | gdb (cppdbg) |

Software containers don't run `--privileged` (no USB needed); they use `--net=host` so dev
servers are reachable on `localhost`. The C/C++ container adds `SYS_PTRACE` for gdb/valgrind.

## Prerequisites

- Ubuntu 24.04 (or compatible Debian-based distro)
- `sudo` access
- Internet connection (Docker images are built during install)
- `git`, `curl`, `wget`, `gpg` — installed automatically by the installer if missing

## Install

```bash
git clone <this-repo> ~/claude/dev_env_ins
cd ~/claude/dev_env_ins
bash install.sh
```

> **Do not run with `sudo bash install.sh`** — the script must run as your normal user.
> Steps that need elevated permissions call `sudo` internally and will prompt you.

### Options

```bash
./install.sh                          # Full install, all boards
./install.sh --boards arduino,pico    # Specific boards only
./install.sh --boards python,node,cpp # Software environments only
./install.sh --skip-containers        # Folders and configs only, no Docker builds
./install.sh --skip-vscode            # Skip VS Code install
./install.sh --skip-docker            # Skip Docker install
./install.sh --skip-gh                # Skip GitHub CLI install
./install.sh --skip-udev              # Skip udev rules
./install.sh --skip-scripts           # Skip new-project symlink
./install.sh --yes                    # Non-interactive, skip prompts

# Beta testing — skips all sudo-requiring steps:
./install.sh --skip-prereqs --skip-vscode --skip-docker --skip-containers \
             --skip-gh --skip-udev --skip-scripts --yes
```

## What Gets Created

```
~/
├── claude/                  # AI-assisted development (Claude Code inside containers)
│   ├── arduino/
│   │   ├── .devcontainer/   # Docker container definition
│   │   ├── arduino.code-workspace
│   │   ├── projects/        # Your sketches/projects
│   │   └── knowledge/
│   │       ├── snippets/arduino/
│   │       ├── docs/arduino/
│   │       └── datasheets/arduino/
│   ├── esp32/
│   ├── pico/
│   ├── teensy/
│   ├── python/
│   ├── node/
│   └── cpp/
│
└── dev/                     # Standalone development (same containers, no AI context)
    ├── arduino/
    ├── esp32/
    ├── pico/
    ├── teensy/
    ├── python/
    ├── node/
    └── cpp/
```

Both trees use the same Docker images — the difference is which folder VS Code opens.

## Usage

### Open a workspace

```bash
code ~/claude/arduino/arduino.code-workspace
code ~/claude/esp32/esp32.code-workspace
code ~/claude/pico/pico.code-workspace
code ~/claude/teensy/teensy.code-workspace
code ~/claude/python/python.code-workspace
code ~/claude/node/node.code-workspace
code ~/claude/cpp/cpp.code-workspace
```

Once the workspace opens, press `Ctrl+Shift+P` and run **Dev Containers: Reopen in Container**.
The container starts with the full toolchain and Claude Code installed.

### First-time Claude Code auth

Inside the container terminal:

```bash
claude
```

Follow the authentication prompts. Auth is cached in the container volume.

### Running tasks

Open the Command Palette (`Ctrl+Shift+P`) → **Tasks: Run Task**, or use `Ctrl+Shift+B`
for the default build task.

| Board | Default build task |
|-------|--------------------|
| Arduino | Arduino: Compile |
| ESP32 | ESP-IDF: Build |
| Pico | Pico: Build |
| Teensy | PIO: Build |
| Python | Python: Run |
| Node | Node: Build (tsc) |
| C/C++ | C++: Build |

### USB flashing from inside the container

Containers run with `--privileged` so USB devices are accessible. The udev rules installed
by the script cover all common USB-serial chips, bootloaders, and debuggers.

If a device isn't detected, check the host:

```bash
lsusb                          # find your device
dmesg | tail -20               # see what was recognised
ls /dev/ttyUSB* /dev/ttyACM*   # serial ports
```

## Adding a New Board

1. Create a folder: `boards/<boardname>/`
2. Add three files:
   - `Dockerfile` — Ubuntu 24.04 base + toolchain + `npm install -g @anthropic-ai/claude-code`
   - `devcontainer.json` — reference image `dev-<boardname>:latest`, set USB runArgs
   - `<boardname>.code-workspace` — folders, tasks, launch configs, extension recommendations
3. Add new udev rules for the board's USB IDs to `udev/99-dev-boards.rules`
4. Run: `./install.sh --boards <boardname>`

Use an existing board folder as a reference (Pico is a good template for ARM boards,
Teensy for PlatformIO-based boards).

## Rebuilding a Container

```bash
docker build -t dev-arduino:latest boards/arduino/
docker build -t dev-esp32:latest   boards/esp32/
docker build -t dev-pico:latest    boards/pico/
docker build -t dev-teensy:latest  boards/teensy/
docker build -t dev-python:latest  boards/python/
docker build -t dev-node:latest    boards/node/
docker build -t dev-cpp:latest     boards/cpp/
```

## udev Rules

Rules are installed to `/etc/udev/rules.d/99-dev-boards.rules`. To update after editing:

```bash
sudo cp udev/99-dev-boards.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## Creating a New Project

Use `new-project` from any terminal on the host (installed system-wide by `install.sh`):

```bash
new-project arduino blink
new-project esp32 wifi-sensor dev
new-project pico hello-world
new-project teensy midi-controller
new-project python log-parser     # pyproject.toml + main.py + tests/
new-project node web-api          # package.json + tsconfig + src/*.ts
new-project cpp ring-buffer       # CMakeLists.txt + src/main.cpp
```

This creates the project folder under `~/<tree>/<board>/projects/<name>/`, adds a
board-appropriate `.gitignore`, drops in a minimal starter file, and runs `git init`
with an initial commit.

## Uploading a Project to GitHub

1. Open the project in VS Code (inside its dev container)
2. In the Claude Code terminal, run:
   ```
   /github-upload
   ```
3. Claude will walk you through: creating the GitHub repo (if needed), committing any
   pending changes, and pushing.

First time only — authenticate the GitHub CLI:
```bash
gh auth login
```

## Version Control for the Installer Itself

The installer repo is tracked with git. To back it up to GitHub:

```bash
cd ~/claude/dev_env_ins
git init -b main   # if not already done
git add .
git commit -m "Initial setup"
gh repo create dev-env-ins --private --source=. --remote=origin --push
```

## Structure of This Repo

```
dev_env_ins/
├── install.sh              # Main installer
├── boards/
│   ├── arduino/            # Dockerfile, devcontainer.json, arduino.code-workspace
│   ├── esp32/
│   ├── pico/
│   ├── teensy/
│   ├── python/             # software environments
│   ├── node/
│   └── cpp/
├── scripts/
│   ├── new-project.sh      # Create a new project with git init
│   └── gitignores/         # Board-specific .gitignore templates
├── skills/
│   └── github-upload.md    # Claude Code /github-upload skill
├── udev/
│   └── 99-dev-boards.rules
├── .gitignore
├── README.md
└── plan.md                 # Roadmap and future improvements
```
