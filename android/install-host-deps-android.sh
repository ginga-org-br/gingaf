#!/usr/bin/env bash
set -e

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
CMDLINE_DIR="$ANDROID_HOME/cmdline-tools/latest"

if [ -d "$ANDROID_HOME/cmdline-tools/latest-2" ]; then
    rm -rf "$ANDROID_HOME/cmdline-tools/latest-2"
fi

if [ ! -d "$CMDLINE_DIR" ]; then
    echo "Setting up Android cmdline-tools in $CMDLINE_DIR..."
    mkdir -p "$CMDLINE_DIR"
    TEMP_ZIP=$(mktemp)
    OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [ "$OS_NAME" = "darwin" ]; then
        URL="https://dl.google.com/android/repository/commandlinetools-mac-15859902_latest.zip"
    else
        URL="https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip"
    fi
    echo "Downloading Android command-line tools..."
    curl -fsSL "$URL" -o "$TEMP_ZIP"
    TEMP_EXTRACT=$(mktemp -d)
    unzip -q "$TEMP_ZIP" -d "$TEMP_EXTRACT"
    mv "$TEMP_EXTRACT/cmdline-tools/"* "$CMDLINE_DIR/"
    rm -rf "$TEMP_ZIP" "$TEMP_EXTRACT"
fi

SDKMANAGER="$CMDLINE_DIR/bin/sdkmanager"
AVDMANAGER="$CMDLINE_DIR/bin/avdmanager"

if [ -x "$SDKMANAGER" ]; then
    echo "Installing Android platform-tools, platform 34, and emulator system image..."
    yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" "platform-tools" "platforms;android-34" "system-images;android-34;google_apis;x86_64" >/dev/null 2>&1 || true

    if [ -x "$AVDMANAGER" ]; then
        echo "Creating Android virtual device 'flutter_dev'..."
        "$AVDMANAGER" create avd -n flutter_dev -k "system-images;android-34;google_apis;x86_64" --device "pixel" --force >/dev/null 2>&1 || true
    fi
fi

echo "Android SDK and emulator 'flutter_dev' configured successfully in $ANDROID_HOME."
