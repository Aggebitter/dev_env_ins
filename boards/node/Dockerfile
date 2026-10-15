# Official Node.js LTS image (Debian bookworm) — current Node, npm and corepack included
FROM node:24-bookworm

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git curl ca-certificates \
    build-essential python3 \
    && rm -rf /var/lib/apt/lists/*

# Global tooling: TypeScript compiler, pnpm, and Claude Code
RUN npm install -g typescript pnpm @anthropic-ai/claude-code

WORKDIR /workspace
