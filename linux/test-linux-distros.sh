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

# Fall back to a global CDN HTTP mirror (or honor UBUNTU_MIRROR) when default
# archive.ubuntu.com over plain HTTP (port 80) is blocked, unreachable, or too
# slow (e.g., corporate/university firewalls or Canonical mirror outages).
# Minimal ubuntu:* Docker images do not ship ca-certificates, so initial APT
# fetches must succeed over HTTP before HTTPS mirrors can be used.
APT_MIRROR="${UBUNTU_MIRROR:-}"
if [ -z "$APT_MIRROR" ] && command -v curl >/dev/null 2>&1; then
    if ! curl -4 -fsS --max-time 3 -o /dev/null http://archive.ubuntu.com/ubuntu/dists/noble/main/binary-amd64/Packages.gz 2>/dev/null; then
        APT_MIRROR="http://mirrors.edge.kernel.org/ubuntu/"
    fi
fi
if [ -n "$APT_MIRROR" ]; then
    APT_MIRROR="${APT_MIRROR%/}/"
fi

echo "=================================================="
echo "Testing gingaf across Linux distros via Docker"
echo "Target: $TARGET"
echo "Arguments: $CMD_ARGS"
echo "Mirror: ${APT_MIRROR:-http://archive.ubuntu.com/ubuntu/}"
echo "=================================================="

RESULTS=()
FAILED=0

for distro in "${DISTROS[@]}"; do
    echo ""
    echo "--------------------------------------------------"
    echo "Testing on Ubuntu $distro..."
    echo "--------------------------------------------------"

    DOCKER_CMD=(
        docker run --rm -i
        -e APT_MIRROR="$APT_MIRROR"
        -v "$TARGET":/tmp/gingaf.deb:ro
        -v "gingaf-apt-cache-$distro":/var/cache/apt
        -v "gingaf-apt-lists-$distro":/var/lib/apt/lists
        "ubuntu:$distro" bash -s -- "$CMD_ARGS"
    )
    EXEC_TEST='
set -e
export DEBIAN_FRONTEND=noninteractive
rm -f /etc/apt/apt.conf.d/docker-clean
if [ -n "$APT_MIRROR" ]; then
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources; do
        if [ -f "$f" ]; then
            sed -i "s|http://archive.ubuntu.com/ubuntu/|$APT_MIRROR|g; s|http://security.ubuntu.com/ubuntu/|$APT_MIRROR|g" "$f"
        fi
    done
fi
APT_OPTS=(
    -o Acquire::ForceIPv4=true
    -o Acquire::Retries=3
    -o Acquire::http::Timeout=15
    -o Acquire::https::Timeout=15
    -o DPkg::Lock::Timeout=60
)
echo "1. Installing .deb package via APT..."
if ! {
    apt-get "${APT_OPTS[@]}" update -qq
    apt-get "${APT_OPTS[@]}" install -y -qq --no-install-recommends /tmp/gingaf.deb
} >/tmp/apt.log 2>&1; then
    cat /tmp/apt.log >&2
    exit 1
fi

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
        FAILED=1
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

exit "$FAILED"
