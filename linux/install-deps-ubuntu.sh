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
    zip

echo "Dependencies installed successfully."
