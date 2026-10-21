#!/usr/bin/env bash
set -e

echo "Installing macOS dependencies via Homebrew..."

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Please install Homebrew from https://brew.sh first."
    exit 1
fi

brew install git cmake ninja pkg-config
brew install --cask flutter || true

echo "Dependencies installed successfully."
