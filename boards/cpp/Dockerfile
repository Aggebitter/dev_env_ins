FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git curl ca-certificates \
    build-essential gcc g++ gdb \
    clang clang-format clang-tidy lldb \
    cmake ninja-build pkg-config ccache \
    valgrind cppcheck \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace
