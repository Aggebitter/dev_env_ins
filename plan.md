# Plan — Future Improvements

Tracked ideas and improvements for the dev environment installer.
Add notes here as you discover things during use.

---

## Boards to Add

- [ ] **AVR standalone** — bare avr-gcc without arduino-cli, for direct register-level work
- [ ] **RISC-V** — ESP32-C3/C6 already covered via ESP-IDF; add standalone RISC-V toolchain
      (riscv-none-elf-gcc) for other MCUs like GD32VF103, CH32V
- [ ] **STM32** — arm-none-eabi-gcc + STM32CubeMX / STM32CubeIDE integration or
      STM32 platform via PlatformIO
- [ ] **nRF52** — Nordic SDK or Zephyr RTOS for BLE development
- [ ] **Zephyr RTOS** — west + Zephyr SDK, works across ARM/RISC-V targets

---

## Tooling Improvements

- [ ] **Version pinning** — currently ESP-IDF and Pico SDK fetch latest at build time.
      Add a `versions.env` file to pin specific versions per board for reproducible builds.

- [ ] **Container registry** — push built images to a private registry (ghcr.io or local)
      so re-installs on a new machine don't require a full rebuild from scratch.

- [ ] **Shared base image** — create a `dev-base:latest` image with common tools
      (nodejs, claude-code, git, cmake, python3) that all board images inherit from.
      Reduces total image size and rebuild time.

- [ ] **Arduino library management** — pre-install commonly used libraries inside the
      container (Wire, SPI, Servo, etc.) and persist via a named volume.

- [ ] **ESP-IDF component manager** — pre-install common components (esp-mqtt, esp-tls,
      lvgl) into the container volume cache.

- [ ] **Pico board variants** — the cmake task currently defaults to `pico` board.
      Consider per-project `CMakeUserPresets.json` templates for pico_w, pico2, pico2_w.

---

## Workspace / VS Code Improvements

- [ ] **Serial monitor** — replace terminal-based monitoring with the VS Code Serial Monitor
      extension (`ms-vscode.vscode-serial-monitor`) for a better UX.

- [ ] **Project templates** — add a task "New Project from Template" per board that
      scaffolds a minimal working project (CMakeLists.txt for Pico, platformio.ini for
      Teensy, sketch folder for Arduino, idf.py create-project for ESP32).

- [ ] **Intellisense for ESP-IDF** — the ESP-IDF extension can auto-generate
      `c_cpp_properties.json` via `idf.py --path . create-project`. Add a task for this.

- [ ] **Snippets** — populate `knowledge/snippets/<board>/` with starter code for common
      patterns: GPIO, timers, UART, I2C, SPI, interrupts, sleep modes.

- [ ] **Workspace settings per project** — investigate whether per-project `.vscode/`
      folders inside `projects/<sketch>/` are the right level for board/port settings,
      vs keeping them in the root workspace file.

---

## Installer Improvements

- [x] **Teensy Dockerfile — PlatformIO extension hangs at 50%** — missing `python3-venv` and
      `python-is-python3` packages. PlatformIO creates a venv internally and some scripts
      call `python` not `python3`. Added both packages to Dockerfile.
- [x] **Pico Dockerfile — picotool build order** — picotool requires `PICO_SDK_PATH` at cmake time,
      but Dockerfile was cloning pico-sdk *after* picotool. Fixed by moving pico-sdk clone first.
- [x] **Pico Dockerfile — OpenOCD** — `raspberrypi/openocd` branch `rp2040` no longer exists;
      RP2040/RP2350 support is now in mainline OpenOCD 0.12.0 (Ubuntu 24.04 apt package).
      Replaced custom build with `apt-get install openocd`.
- [x] **Pico Dockerfile — missing apt-get update** — OpenOCD `RUN` step called `apt-get install`
      after previous step cleared `/var/lib/apt/lists/*`. Fixed by adding `apt-get update`.
- [x] **Docker group not active during install** — `build_containers` was silently failing when
      Docker socket was inaccessible (group membership not yet active). Now detects this upfront
      and prints instructions to run `newgrp docker` and re-run.
- [x] **Root-run guard** — installer now exits with a clear error if run as `sudo bash install.sh`.
      Must be run as normal user; individual steps call sudo internally.
- [x] **Host prerequisites phase** — new Phase 1 installs git/curl/wget/gpg via apt if missing.
      Skippable with `--skip-prereqs` for beta testing.
- [x] **Temp file race condition** — VS Code GPG key was written to hardcoded `/tmp/microsoft.gpg`;
      replaced with `mktemp` to avoid permission conflicts on repeated runs.

- [ ] **`--update` flag** — re-deploy configs from `boards/` templates without
      overwriting user-modified files. Useful after pulling new template changes.

- [ ] **Confirm before overwriting configs** — currently `deploy_board_configs` silently
      overwrites existing `.devcontainer/devcontainer.json` and `.code-workspace` files.
      If users customise these, re-running the installer will destroy their changes.
      Add a diff-and-prompt step similar to how `install_udev_rules` works.

- [ ] **`--rebuild` flag** — force rebuild of specified Docker images even if they exist.

- [ ] **Backup on update** — before overwriting deployed config files, back up
      existing ones to `<file>.bak` so user changes aren't silently lost.

- [ ] **Dry-run mode** — `--dry-run` flag that prints what would be installed/created
      without making changes.

- [ ] **Distro support** — currently targets Ubuntu/Debian (apt). Add detection and
      support for Fedora/RHEL (dnf) and Arch (pacman) for VS Code and Docker installs.

- [ ] **Uninstall** — add an `uninstall.sh` or `./install.sh --uninstall <board>` that
      removes Docker images, udev rules, and optionally the folder tree.

---

## USB / Hardware

- [ ] **udev rules — Espressif USB JTAG** — verify VID/PID coverage for all ESP32
      variants with built-in JTAG (S2, S3, C3, C6, H2). Some share VID 303a with
      different PIDs than what's currently listed.

- [ ] **udev rules — Teensy LC / 3.x** — verify HalfKay PIDs for older Teensy models
      (Teensy LC, 3.2, 3.5, 3.6) match the current regex in the rules file.

- [ ] **Bluetooth flashing** — ESP32 supports flashing over BLE. Investigate whether
      this works from inside a container and what permissions are needed.

- [ ] **Multi-board simultaneous flashing** — tasks currently prompt for a single port.
      Consider a Python helper script that discovers all connected boards of a given
      type and flashes them in parallel.

---

## Git / GitHub

- [ ] **`/github-upload` — private vs org repos** — skill currently creates personal repos.
      Add option to push to a GitHub organisation.

- [ ] **Auto-push on commit** — optional git hook (`post-commit`) inside project repos
      that auto-pushes to origin if a remote is set. Useful for frequent backups.

- [ ] **Branch workflow** — new-project.sh always uses `main`. Add a `--branch` flag
      and a task for creating feature branches inside the workspace.

- [ ] **Installer repo backup** — add a one-liner to README for pushing dev_env_ins
      itself to GitHub. Consider a separate `/backup-installer` skill.

## Knowledge Base

- [ ] **Document knowledge folder conventions** — write a short `knowledge/README.md`
      per board describing what goes in snippets vs docs vs datasheets, and naming
      conventions for files.

- [ ] **Datasheet index** — a simple `knowledge/datasheets/<board>/INDEX.md` listing
      downloaded datasheets with short descriptions, so Claude can reference them.

- [ ] **Claude context files** — add `CLAUDE.md` per board workspace with board-specific
      context: common pin assignments, clock speeds, memory map, known gotchas.
      Claude Code reads these automatically.
