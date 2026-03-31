FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git cmake ninja-build \
    gcc-arm-none-eabi libnewlib-arm-none-eabi \
    libstdc++-arm-none-eabi-newlib \
    python3 python3-pip \
    libusb-1.0-0 udev pkg-config \
    build-essential \
    openocd \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Clone Pico SDK (latest stable tag) — must come before picotool
RUN LATEST_TAG=$(git ls-remote --tags https://github.com/raspberrypi/pico-sdk.git \
        | grep -oP 'refs/tags/\d+\.\d+\.\d+$' | sort -V | tail -1 | sed 's|refs/tags/||') && \
    echo "Installing Pico SDK ${LATEST_TAG}" && \
    git clone --depth=1 --branch ${LATEST_TAG} \
        https://github.com/raspberrypi/pico-sdk.git /opt/pico-sdk && \
    cd /opt/pico-sdk && git submodule update --init

ENV PICO_SDK_PATH=/opt/pico-sdk

# Install picotool (requires PICO_SDK_PATH to be set)
RUN git clone https://github.com/raspberrypi/picotool.git /opt/picotool && \
    cmake -S /opt/picotool -B /opt/picotool/build \
        -DPICO_SDK_PATH=/opt/pico-sdk && \
    cmake --build /opt/picotool/build -j$(nproc) && \
    cmake --install /opt/picotool/build

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace
