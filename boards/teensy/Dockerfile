FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-venv \
    python-is-python3 \
    curl git \
    libusb-1.0-0 udev \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Install PlatformIO CLI
RUN pip3 install --break-system-packages platformio

# Pre-install Teensy platform and common frameworks
# This speeds up first-time project setup
RUN platformio platform install teensy && \
    platformio platform install atmelavr

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace
