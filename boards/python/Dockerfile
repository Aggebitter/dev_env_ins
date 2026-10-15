FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git curl ca-certificates \
    python3 python3-pip python3-venv python3-dev \
    build-essential pkg-config \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# uv — fast project/venv/dependency manager (also installs other Python versions on demand)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Cache lives on a docker volume, venvs on the bind mount — copy instead of hardlink
ENV UV_LINK_MODE=copy

# Global CLI tools (ruff, pytest) available outside of any project venv
RUN uv tool install ruff && uv tool install pytest
ENV PATH="/root/.local/bin:${PATH}"

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace
