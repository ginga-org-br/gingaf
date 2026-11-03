#!/usr/bin/env bash
set -e

echo "Installing Ubuntu / Debian dependencies..."
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libwebkit2gtk-4.1-dev \
    libmpv-dev \
    mpv \
    curl \
    git \
    unzip \
    snapd

if ! command -v flutter >/dev/null 2>&1 && [ ! -x /snap/bin/flutter ]; then
    if command -v snap >/dev/null 2>&1; then
        echo "Installing Flutter via snap..."
        sudo snap install flutter --classic
    fi
fi

echo "Dependencies installed successfully."
