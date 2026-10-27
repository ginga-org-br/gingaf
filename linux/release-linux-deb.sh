#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | sed 's/version: //' | cut -d'+' -f1 | tr -d '\r')}"
FLUTTER_SDK_DIR="${FLUTTER_SDK_DIR:-$(which flutter | xargs readlink -f | xargs dirname | xargs dirname)}"
PUB_CACHE_DIR="${PUB_CACHE_DIR:-$HOME/.pub-cache}"

docker build -t gingaf-builder-ubuntu2204 -f "$ROOT_DIR/linux/Dockerfile.builder-ubuntu2204" "$ROOT_DIR/linux/"
docker run --rm \
	--user "$(id -u):$(id -g)" \
	-e HOME=/tmp \
	-e PATH="$FLUTTER_SDK_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
	-v "$FLUTTER_SDK_DIR:$FLUTTER_SDK_DIR" \
	-v "$PUB_CACHE_DIR:$PUB_CACHE_DIR:ro" \
	-v "$ROOT_DIR:$ROOT_DIR" \
	-w "$ROOT_DIR" \
	gingaf-builder-ubuntu2204 \
	bash -c "flutter build linux --no-pub --release && bash linux/package-deb.sh build/linux/x64/release/bundle $VERSION $ROOT_DIR/gingaf-v$VERSION-linux-amd64.deb"
