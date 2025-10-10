# Simple Node + Rust image suitable for Tauri builds (Linux)
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Node LTS and basic build deps
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs git curl build-essential libgtk-3-dev libwebkit2gtk-4.1-dev libsoup2.4-dev libjavascriptcoregtk-4.1-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Rust toolchain
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y \
    && /root/.cargo/bin/rustup target add x86_64-unknown-linux-gnu
ENV PATH="/root/.cargo/bin:${PATH}"

# Tauri CLI
RUN npm i -g @tauri-apps/cli

WORKDIR /workspace


