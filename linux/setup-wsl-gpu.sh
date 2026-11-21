#!/usr/bin/env bash
set -euo pipefail

if [ ! -e /dev/dxg ] && [ -z "${WSL_DISTRO_NAME:-}" ] && [ -z "${WSL_INTEROP:-}" ]; then
    echo "Error: WSL2 GPU paravirtualization (/dev/dxg) not detected." >&2
    exit 1
fi

if [ ! -d /usr/lib/wsl/lib ]; then
    echo "Error: /usr/lib/wsl/lib not found. Install the Windows GPU driver on the host." >&2
    exit 1
fi

HAS_NVIDIA=0
if [ -f /usr/lib/wsl/lib/libcuda.so.1 ] && [ -f /usr/lib/wsl/lib/libnvcuvid.so.1 ]; then
    HAS_NVIDIA=1
fi

REQUIRED_PKGS=(libgl1-mesa-dri libwayland-egl1 ffmpeg)
if [ "$HAS_NVIDIA" -eq 0 ]; then
    REQUIRED_PKGS+=(mesa-va-drivers)
fi

MISSING_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done
if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
    echo "Installing WSL2 graphics and video packages: ${MISSING_PKGS[*]}..."
    sudo apt-get update
    sudo apt-get install -y "${MISSING_PKGS[@]}"
fi

BASHRC="${HOME}/.bashrc"
touch "$BASHRC"
BASHRC_BACKED_UP=0

ensure_bashrc_line() {
    local pattern="$1"
    local line="$2"
    if grep -Eq "$pattern" "$BASHRC"; then
        return 0
    fi
    if [ "$BASHRC_BACKED_UP" -eq 0 ]; then
        cp -a "$BASHRC" "${BASHRC}.bak"
        BASHRC_BACKED_UP=1
        if ! grep -Fq '# Added by setup-wsl-gpu.sh' "$BASHRC"; then
            printf '\n# Added by setup-wsl-gpu.sh\n' >> "$BASHRC"
        else
            printf '\n' >> "$BASHRC"
        fi
    fi
    printf '%s\n' "$line" >> "$BASHRC"
    echo "Added to $BASHRC: $line"
}

ensure_bashrc_line 'export[[:space:]]+PATH=.*\/usr\/lib\/wsl\/lib' \
    'export PATH="/usr/lib/wsl/lib:$PATH"'
ensure_bashrc_line 'export[[:space:]]+LD_LIBRARY_PATH=.*\/usr\/lib\/wsl\/lib' \
    'export LD_LIBRARY_PATH="/usr/lib/wsl/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"'
ensure_bashrc_line '^[[:space:]]*export[[:space:]]+GALLIUM_DRIVER=' \
    'export GALLIUM_DRIVER=d3d12'
if [ "$HAS_NVIDIA" -eq 1 ]; then
    ensure_bashrc_line '^[[:space:]]*export[[:space:]]+MESA_D3D12_DEFAULT_ADAPTER_NAME=' \
        'export MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA'
else
    ensure_bashrc_line '^[[:space:]]*export[[:space:]]+LIBVA_DRIVER_NAME=' \
        'export LIBVA_DRIVER_NAME=d3d12'
fi
ensure_bashrc_line '^[[:space:]]*export[[:space:]]+GDK_BACKEND=' \
    'export GDK_BACKEND=wayland'

if [ "$BASHRC_BACKED_UP" -eq 0 ]; then
    echo "$BASHRC already contains WSL2 GPU and Wayland environment variables."
fi

MPV_DIR="${HOME}/.config/mpv"
MPV_CONF="${MPV_DIR}/mpv.conf"
mkdir -p "$MPV_DIR"
MPV_BACKED_UP=0

ensure_mpv_option() {
    local key="$1"
    local value="$2"
    if [ -f "$MPV_CONF" ] && grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$MPV_CONF"; then
        local current
        current="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$MPV_CONF" | tail -n1 | cut -d= -f2- | tr -d '[:space:]')"
        if [ "$current" = "$value" ]; then
            return 0
        fi
        if [ "$MPV_BACKED_UP" -eq 0 ]; then
            cp -a "$MPV_CONF" "${MPV_CONF}.bak"
            MPV_BACKED_UP=1
        fi
        sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "$MPV_CONF"
        echo "Updated $MPV_CONF: ${key}=${value}"
        return 0
    fi
    if [ -f "$MPV_CONF" ] && [ "$MPV_BACKED_UP" -eq 0 ]; then
        cp -a "$MPV_CONF" "${MPV_CONF}.bak"
        MPV_BACKED_UP=1
    fi
    printf '%s=%s\n' "$key" "$value" >> "$MPV_CONF"
    echo "Added to $MPV_CONF: ${key}=${value}"
}

if [ "$HAS_NVIDIA" -eq 1 ]; then
    ensure_mpv_option "hwdec" "nvdec-copy"
else
    ensure_mpv_option "hwdec" "vaapi,auto-safe"
fi
ensure_mpv_option "gpu-api" "opengl"
ensure_mpv_option "gpu-context" "wayland"
ensure_mpv_option "vo" "gpu-next"

export PATH="/usr/lib/wsl/lib:$PATH"
export LD_LIBRARY_PATH="/usr/lib/wsl/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ "$HAS_NVIDIA" -eq 1 ] && command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
fi

echo "WSL2 GPU and Wayland setup complete."

