#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TV30_DIR="${TV30_DIR:-$(cd "$ROOT_DIR/../TV30" 2>/dev/null && pwd || echo "$ROOT_DIR/../TV30")}"

ACTION="${1:-up}"
shift || true

if [ ! -d "$TV30_DIR" ]; then
  echo "TV30 directory not found at $TV30_DIR" >&2
  exit 1
fi

export PATH="/snap/bin:$PATH"

release_tv30() {
  make -C "$ROOT_DIR" release-web
  mkdir -p "$TV30_DIR/bcast/public/gingaf-web"
  cp -r "$ROOT_DIR/build/web/"* "$TV30_DIR/bcast/public/gingaf-web/"
  mkdir -p "$TV30_DIR/bcast/public/media/video360"
  cp "$ROOT_DIR/examples/video.ncl" \
     "$ROOT_DIR/examples/lua_canvas.ncl" \
     "$ROOT_DIR/examples/lua_canvas.lua" \
     "$ROOT_DIR/examples/logo.png" \
     "$ROOT_DIR/examples/current_service.html" \
     "$ROOT_DIR/examples/emb_html.ncl" \
     "$ROOT_DIR/examples/emb_ncl.ncl" \
     "$TV30_DIR/bcast/public/media/"
  cp -r "$ROOT_DIR/examples/video360/"* "$TV30_DIR/bcast/public/media/video360/"
  printf "%s\n" "gingaf-web successfully exported to $TV30_DIR/bcast/public/gingaf-web"
}

case "$ACTION" in
  up|start)
    if [ ! -f "$TV30_DIR/.env" ]; then
      cp "$TV30_DIR/.env.example" "$TV30_DIR/.env"
    fi
    sed -i 's/^#BCAST_PUBLISH=8081:8081/BCAST_PUBLISH=8081:8081/' "$TV30_DIR/.env" || true

    release_tv30

    if [ -z "${TV3WS_WS_PORT_RANGE:-}" ]; then
      for base in 45000 45100 45200 45300 45400 45500; do
        top=$((base + 99))
        if ! ss -tnH | awk '{print $4}' | grep -qE ":($(seq -s '|' "$base" "$top"))$"; then
          export WS_PORT_MIN="$base"
          export WS_PORT_MAX="$top"
          export TV3WS_WS_PORT_RANGE="${base}-${top}:${base}-${top}"
          break
        fi
      done
    fi

    (
      cd "$TV30_DIR"
      docker compose build bcast aop
      ./tv30 up "$@"
    )

    echo "TV 3.0 stack started with gingaf-web"
    echo "AoP UI: http://localhost:8080"
    echo "Ginga Video App: http://urn-tv30-app-ginga.apps.localhost:8080/graphicsAppProxy/gingaf-web/index.html?app=/media/video.ncl&tv30=true"
    echo "Broadcaster Service: http://localhost:8081"
    ;;
  down|stop)
    (
      cd "$TV30_DIR"
      ./tv30 down "$@"
    )
    ;;
  status)
    (
      cd "$TV30_DIR"
      ./tv30 status "$@"
    )
    ;;
  logs)
    (
      cd "$TV30_DIR"
      docker compose logs "$@"
    )
    ;;
  release)
    release_tv30
    ;;
  build)
    release_tv30
    (
      cd "$TV30_DIR"
      docker compose build bcast aop
    )
    ;;
  *)
    echo "Usage: $0 [up|down|status|logs|release|build]" >&2
    exit 2
    ;;
esac

