#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_DIR="${1:-$ROOT_DIR/build/linux/x64/release/bundle}"
VERSION="${2:-$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | sed 's/version: //' | cut -d'+' -f1 | tr -d '\r')}"
OUTPUT_DEB="${3:-$ROOT_DIR/gingaf-v${VERSION}-linux-amd64.deb}"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Error: bundle directory not found at $BUNDLE_DIR"
    exit 1
fi

TMP_DIR="$(mktemp -d /tmp/gingaf-deb-XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

PKG_ROOT="$TMP_DIR/pkg"
APP_DIR="$PKG_ROOT/usr/lib/gingaf"
BIN_DIR="$PKG_ROOT/usr/bin"
DESKTOP_DIR="$PKG_ROOT/usr/share/applications"
ICON_DIR="$PKG_ROOT/usr/share/icons/hicolor/256x256/apps"
DEBIAN_DIR="$PKG_ROOT/DEBIAN"

mkdir -p "$APP_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR" "$DEBIAN_DIR"

cp -r "$BUNDLE_DIR"/* "$APP_DIR/"
ln -sf /usr/lib/gingaf/gingaf "$BIN_DIR/gingaf"

if [ -f "$ROOT_DIR/assets/ginga-logo.png" ]; then
    cp "$ROOT_DIR/assets/ginga-logo.png" "$ICON_DIR/gingaf.png"
fi

cat << EOF > "$DESKTOP_DIR/gingaf.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Gingaf
Comment=Multi-platform Ginga NCL Player
Exec=/usr/bin/gingaf %U
Icon=gingaf
Terminal=false
StartupNotify=true
Categories=AudioVideo;Player;
EOF

INSTALLED_SIZE=$(du -sk "$PKG_ROOT" | cut -f1)

cat << EOF > "$DEBIAN_DIR/control"
Package: gingaf
Version: $VERSION
Section: video
Priority: optional
Architecture: amd64
Installed-Size: $INSTALLED_SIZE
Maintainer: Ginga Team
Depends: libc6 (>= 2.35), libgtk-3-0, libwebkit2gtk-4.1-0, libmpv2 | libmpv1 | mpv
Homepage: https://github.com/ginga-org-br/gingaf
Description: Multi-platform Ginga player
 Gingaf is a multi-platform player for NCL/Ginga digital TV applications.
EOF

cat << 'EOF' > "$DEBIAN_DIR/postinst"
#!/bin/sh
set -e

for libdir in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
    if [ -d "$libdir" ]; then
        [ -f "$libdir/libmpv.so.2" ] && [ ! -f "$libdir/libmpv.so.1" ] && ln -sf libmpv.so.2 "$libdir/libmpv.so.1" || true
        [ -f "$libdir/libmpv.so.1" ] && [ ! -f "$libdir/libmpv.so.2" ] && ln -sf libmpv.so.1 "$libdir/libmpv.so.2" || true
    fi
done
ldconfig 2>/dev/null || true
EOF
chmod 755 "$DEBIAN_DIR/postinst"

dpkg-deb --build --root-owner-group "$PKG_ROOT" "$OUTPUT_DEB"
echo "Generated Debian package: $OUTPUT_DEB"
