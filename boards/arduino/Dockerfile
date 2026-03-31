FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl git wget \
    gcc-avr avr-libc avrdude \
    binutils-avr \
    python3 python3-pip \
    libusb-1.0-0 udev \
    build-essential \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Install arduino-cli
RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
ENV PATH="/root/bin:$PATH"

# Install core board platforms
RUN arduino-cli core update-index && \
    arduino-cli core install arduino:avr && \
    arduino-cli core install arduino:samd && \
    arduino-cli core install arduino:mbed_nano

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace
