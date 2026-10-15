#!/usr/bin/env bash
# new-project.sh — Create a new project with git init and board-appropriate .gitignore
# Usage: new-project.sh <board> <project-name> [tree]
#   board        : arduino | esp32 | pico | teensy | python | node | cpp
#   project-name : name of the new project folder
#   tree         : claude (default) | dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
GITIGNORE_DIR="${SCRIPT_DIR}/gitignores"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

VALID_BOARDS=(arduino esp32 pico teensy python node cpp)

usage() {
    cat <<EOF
Usage: new-project.sh <board> <project-name> [tree]

  board        : arduino | esp32 | pico | teensy | python | node | cpp
  project-name : name for the new project folder
  tree         : claude (default) | dev

Examples:
  new-project.sh arduino blink
  new-project.sh esp32 wifi-sensor dev
  new-project.sh pico hello-world claude
  new-project.sh python data-tool
EOF
}

# ── Args ──────────────────────────────────────────────────────────────────────
[[ $# -lt 2 ]] && { usage; exit 1; }

BOARD="$1"
PROJECT_NAME="$2"
TREE="${3:-claude}"

# Validate board
valid=false
for b in "${VALID_BOARDS[@]}"; do [[ "$b" == "$BOARD" ]] && valid=true && break; done
$valid || log_error "Unknown board '${BOARD}'. Valid: ${VALID_BOARDS[*]}"

# Validate tree
[[ "$TREE" == "claude" || "$TREE" == "dev" ]] || log_error "Tree must be 'claude' or 'dev'."

PROJECT_DIR="$HOME/${TREE}/${BOARD}/projects/${PROJECT_NAME}"

[[ -e "$PROJECT_DIR" ]] && log_error "Project already exists: ${PROJECT_DIR}"

# ── Create project ─────────────────────────────────────────────────────────────
log_info "Creating project: ${PROJECT_DIR}"
mkdir -p "$PROJECT_DIR"

# Copy .gitignore
cp "${GITIGNORE_DIR}/${BOARD}.gitignore" "${PROJECT_DIR}/.gitignore"

# Create board-specific starter file
case "$BOARD" in
    arduino)
        cat > "${PROJECT_DIR}/${PROJECT_NAME}.ino" <<EOF
// ${PROJECT_NAME}
#define LED_PIN LED_BUILTIN

void setup() {
    Serial.begin(115200);
    pinMode(LED_PIN, OUTPUT);
}

void loop() {
    digitalWrite(LED_PIN, HIGH);
    delay(500);
    digitalWrite(LED_PIN, LOW);
    delay(500);
}
EOF
        ;;
    esp32)
        mkdir -p "${PROJECT_DIR}/main"
        cat > "${PROJECT_DIR}/main/main.c" <<EOF
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"

#define LED_PIN GPIO_NUM_2   // Built-in LED on most ESP32 devboards

void app_main(void) {
    gpio_reset_pin(LED_PIN);
    gpio_set_direction(LED_PIN, GPIO_MODE_OUTPUT);

    while (1) {
        gpio_set_level(LED_PIN, 1);
        vTaskDelay(pdMS_TO_TICKS(500));
        gpio_set_level(LED_PIN, 0);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}
EOF
        cat > "${PROJECT_DIR}/main/CMakeLists.txt" <<EOF
idf_component_register(SRCS "main.c"
                        INCLUDE_DIRS ".")
EOF
        cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.16)
include(\$ENV{IDF_PATH}/tools/cmake/project.cmake)
project(${PROJECT_NAME})
EOF
        ;;
    pico)
        cat > "${PROJECT_DIR}/main.c" <<EOF
#include "pico/stdlib.h"

#define LED_PIN 25   // Built-in LED on Pico (GPIO 25)

int main() {
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    while (true) {
        gpio_put(LED_PIN, 1);
        sleep_ms(500);
        gpio_put(LED_PIN, 0);
        sleep_ms(500);
    }
}
EOF
        cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.13)
include(\$ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)
project(${PROJECT_NAME} C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
pico_sdk_init()

add_executable(\${PROJECT_NAME} main.c)
target_link_libraries(\${PROJECT_NAME} pico_stdlib)
pico_add_extra_outputs(\${PROJECT_NAME})
EOF
        ;;
    teensy)
        cat > "${PROJECT_DIR}/platformio.ini" <<EOF
[env:teensy41]
platform = teensy
board = teensy41
framework = arduino
EOF
        mkdir -p "${PROJECT_DIR}/src"
        cat > "${PROJECT_DIR}/src/main.cpp" <<EOF
#include <Arduino.h>

#define LED_PIN LED_BUILTIN   // Pin 13 on Teensy 4.1

void setup() {
    pinMode(LED_PIN, OUTPUT);
}

void loop() {
    digitalWrite(LED_PIN, HIGH);
    delay(500);
    digitalWrite(LED_PIN, LOW);
    delay(500);
}
EOF
        ;;
    python)
        cat > "${PROJECT_DIR}/pyproject.toml" <<EOF
[project]
name = "${PROJECT_NAME}"
version = "0.1.0"
description = ""
requires-python = ">=3.12"
dependencies = []

[dependency-groups]
dev = ["pytest", "ruff"]

[tool.pytest.ini_options]
pythonpath = ["."]
testpaths = ["tests"]

[tool.ruff]
line-length = 100
EOF
        cat > "${PROJECT_DIR}/main.py" <<EOF
"""${PROJECT_NAME}"""


def greet(name: str) -> str:
    return f"Hello, {name}!"


def main() -> None:
    print(greet("world"))


if __name__ == "__main__":
    main()
EOF
        mkdir -p "${PROJECT_DIR}/tests"
        cat > "${PROJECT_DIR}/tests/test_main.py" <<EOF
from main import greet


def test_greet():
    assert greet("world") == "Hello, world!"
EOF
        ;;
    node)
        cat > "${PROJECT_DIR}/package.json" <<EOF
{
  "name": "${PROJECT_NAME}",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "start": "node src/index.ts",
    "dev": "node --watch src/index.ts",
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "test": "node --test \"src/**/*.test.ts\""
  },
  "devDependencies": {
    "@types/node": "^24.0.0",
    "typescript": "^5.9.0"
  }
}
EOF
        cat > "${PROJECT_DIR}/tsconfig.json" <<EOF
{
  "compilerOptions": {
    "target": "es2023",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "rootDir": "src",
    "outDir": "dist",
    "strict": true,
    "skipLibCheck": true,
    "erasableSyntaxOnly": true,
    "verbatimModuleSyntax": true,
    "rewriteRelativeImportExtensions": true
  },
  "include": ["src"],
  "exclude": ["src/**/*.test.ts"]
}
EOF
        mkdir -p "${PROJECT_DIR}/src"
        cat > "${PROJECT_DIR}/src/greet.ts" <<EOF
export function greet(name: string): string {
    return \`Hello, \${name}!\`;
}
EOF
        cat > "${PROJECT_DIR}/src/index.ts" <<EOF
// ${PROJECT_NAME}
import { greet } from "./greet.ts";

console.log(greet("world"));
EOF
        cat > "${PROJECT_DIR}/src/greet.test.ts" <<EOF
import { test } from "node:test";
import assert from "node:assert/strict";
import { greet } from "./greet.ts";

test("greet", () => {
    assert.equal(greet("world"), "Hello, world!");
});
EOF
        ;;
    cpp)
        cat > "${PROJECT_DIR}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.20)
project(${PROJECT_NAME} CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_compile_options(-Wall -Wextra -Wpedantic)

add_executable(main src/main.cpp)

enable_testing()
add_test(NAME runs COMMAND main)
EOF
        mkdir -p "${PROJECT_DIR}/src"
        cat > "${PROJECT_DIR}/src/main.cpp" <<EOF
// ${PROJECT_NAME}
#include <iostream>

int main() {
    std::cout << "Hello, world!\n";
    return 0;
}
EOF
        ;;
esac

# ── Git init ──────────────────────────────────────────────────────────────────
log_info "Initialising git repository..."
git -C "$PROJECT_DIR" init -b main
# Set local identity if no global config is present
if ! git config --global user.email &>/dev/null; then
    git -C "$PROJECT_DIR" config user.email "dev@localhost"
    git -C "$PROJECT_DIR" config user.name "Developer"
fi
git -C "$PROJECT_DIR" add .
git -C "$PROJECT_DIR" commit -m "Initial project scaffold (${BOARD})"

log_ok "Project ready: ${PROJECT_DIR}"
echo ""
echo -e "  Open in VS Code container:"
echo -e "  ${BOLD}code ~/${TREE}/${BOARD}/${BOARD}.code-workspace${RESET}"
echo ""
echo -e "  Upload to GitHub later:"
echo -e "  ${BOLD}claude  →  /github-upload${RESET}"
