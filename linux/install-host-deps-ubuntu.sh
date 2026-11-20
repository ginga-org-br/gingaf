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
    adwaita-icon-theme \
    mesa-utils \
    curl \
    git \
    unzip \
    xz-utils

if command -v snap >/dev/null 2>&1 && snap list flutter >/dev/null 2>&1; then
    echo "Removing Snap Flutter..."
    sudo snap remove flutter
    hash -r
fi

FLUTTER_DIR="${FLUTTER_DIR:-$HOME/.local/share/flutter}"
BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

if ! command -v flutter >/dev/null 2>&1; then
    if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
        echo "Installing Flutter SDK (stable) to $FLUTTER_DIR..."
        mkdir -p "$(dirname "$FLUTTER_DIR")"
        git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
    fi
    mkdir -p "$BIN_DIR"
    ln -sf "$FLUTTER_DIR/bin/flutter" "$BIN_DIR/flutter"
    ln -sf "$FLUTTER_DIR/bin/dart" "$BIN_DIR/dart"
fi

if [ -f "$HOME/.bashrc" ] && ! grep -q '\.local/bin' "$HOME/.bashrc"; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
fi

flutter config --enable-linux-desktop
flutter precache --linux

echo "Dependencies installed successfully."
