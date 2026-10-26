#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-}"
CMD_ARGS="${2:---help}"
DISTROS=("22.04" "24.04" "26.04")

if [ -z "$TARGET" ]; then
    LATEST_DEB=$(find "$ROOT_DIR" -maxdepth 1 -type f -name "gingaf-v*-linux-amd64.deb" -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -n1 | cut -f2- || true)
    if [ -n "$LATEST_DEB" ] && [ -f "$LATEST_DEB" ]; then
        TARGET="$LATEST_DEB"
    else
        TARGET="$ROOT_DIR/build/linux/x64/release/bundle"
    fi
fi

if [[ "$TARGET" != *.deb ]]; then
    if [ ! -d "$TARGET" ]; then
        echo "Error: target not found at $TARGET"
        exit 1
    fi
    TEMP_DEB="$(mktemp /tmp/gingaf-test-XXXXXX.deb)"
    trap 'rm -f "$TEMP_DEB"' EXIT
    bash "$ROOT_DIR/linux/package-deb.sh" "$TARGET" "" "$TEMP_DEB" > /dev/null
    TARGET="$TEMP_DEB"
fi

if [ ! -f "$TARGET" ]; then
    echo "Error: Debian package not found at $TARGET"
    exit 1
fi
TARGET="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"

echo "=================================================="
echo "Testing gingaf across Linux distros via Docker"
echo "Target: $TARGET"
echo "Arguments: $CMD_ARGS"
echo "=================================================="

RESULTS=()

for distro in "${DISTROS[@]}"; do
    echo ""
    echo "--------------------------------------------------"
    echo "Testing on Ubuntu $distro..."
    echo "--------------------------------------------------"

    DOCKER_CMD=(
        docker run --rm -i
        -v "$TARGET":/tmp/gingaf.deb:ro
        "ubuntu:$distro" bash -s -- "$CMD_ARGS"
    )
    EXEC_TEST='
set -e
export DEBIAN_FRONTEND=noninteractive
echo "1. Installing .deb package via APT..."
{
    apt-get update -qq
    apt-get install -y -qq /tmp/gingaf.deb
} > /dev/null 2>&1

echo "2. Verifying host system libmpv is present..."
ldconfig -p 2>/dev/null | grep -i libmpv || true

echo "3. Running gingaf $1..."
/usr/bin/gingaf "$@"
'

    if "${DOCKER_CMD[@]}" <<< "$EXEC_TEST"; then
        echo "[PASS] Ubuntu $distro passed!"
        RESULTS+=("Ubuntu $distro: PASSED")
    else
        echo "[FAIL] Ubuntu $distro failed!"
        RESULTS+=("Ubuntu $distro: FAILED")
    fi
done

echo ""
echo "=================================================="
echo "Test Summary"
echo "=================================================="
for res in "${RESULTS[@]}"; do
    echo "$res"
done
echo "=================================================="
