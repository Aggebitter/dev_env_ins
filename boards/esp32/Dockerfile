FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git wget curl flex bison gperf \
    python3 python3-pip python3-venv \
    cmake ninja-build ccache \
    libffi-dev libssl-dev dfu-util \
    libusb-1.0-0 udev \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Clone latest stable ESP-IDF v5.x
RUN LATEST_TAG=$(curl -s "https://api.github.com/repos/espressif/esp-idf/releases/latest" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])") && \
    echo "Installing ESP-IDF ${LATEST_TAG}" && \
    git clone --depth=1 --branch ${LATEST_TAG} \
        --recurse-submodules --shallow-submodules \
        https://github.com/espressif/esp-idf.git /opt/esp-idf

ENV IDF_PATH=/opt/esp-idf

# Install ESP-IDF toolchains for common ESP32 targets
RUN /opt/esp-idf/install.sh esp32,esp32s2,esp32s3,esp32c3,esp32c6

# Add idf.py to path via export script
RUN echo 'source /opt/esp-idf/export.sh > /dev/null 2>&1' >> /root/.bashrc

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

SHELL ["/bin/bash", "-c"]
