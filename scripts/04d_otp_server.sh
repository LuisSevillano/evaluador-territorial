#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OTP_DIR="${OTP_DIR:-$ROOT_DIR/data/raw/otp}"
GRAPH_DIR="$OTP_DIR/graph"
OTP_IMAGE="${OTP_IMAGE:-docker.io/opentripplanner/opentripplanner:2.8.1}"
OTP_MEMORY="${OTP_MEMORY:-8g}"
DOCKER_RUN_INTERACTIVE=(-i)

if [ -t 0 ] && [ -t 1 ]; then
  DOCKER_RUN_INTERACTIVE=(-it)
fi

if [ ! -d "$GRAPH_DIR" ]; then
  printf '[otp] No existe %s. Ejecuta scripts/04c_otp_download_inputs.sh primero.\n' "$GRAPH_DIR" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  printf '[otp] Docker no esta disponible en PATH.\n' >&2
  exit 1
fi

if ! ls "$GRAPH_DIR"/*.osm.pbf >/dev/null 2>&1; then
  printf '[otp] Falta OSM PBF en %s.\n' "$GRAPH_DIR" >&2
  exit 1
fi

if ! find "$GRAPH_DIR" -name '*gtfs*.zip' -type f -size +0c | grep -q .; then
  printf '[otp] Falta al menos un GTFS zip con gtfs en el nombre dentro de %s.\n' "$GRAPH_DIR" >&2
  exit 1
fi

case "${1:-serve}" in
  build)
    docker run --rm \
      -e JAVA_TOOL_OPTIONS="-Xmx$OTP_MEMORY" \
      -v "$GRAPH_DIR:/var/opentripplanner" \
      "$OTP_IMAGE" --build --save
    ;;
  serve)
    docker run "${DOCKER_RUN_INTERACTIVE[@]}" --rm -p 8080:8080 \
      -e JAVA_TOOL_OPTIONS="-Xmx$OTP_MEMORY" \
      -v "$GRAPH_DIR:/var/opentripplanner" \
      "$OTP_IMAGE" --load --serve
    ;;
  build-serve)
    docker run --rm \
      -e JAVA_TOOL_OPTIONS="-Xmx$OTP_MEMORY" \
      -v "$GRAPH_DIR:/var/opentripplanner" \
      "$OTP_IMAGE" --build --save
    docker run "${DOCKER_RUN_INTERACTIVE[@]}" --rm -p 8080:8080 \
      -e JAVA_TOOL_OPTIONS="-Xmx$OTP_MEMORY" \
      -v "$GRAPH_DIR:/var/opentripplanner" \
      "$OTP_IMAGE" --load --serve
    ;;
  *)
    printf 'Uso: %s [build|serve|build-serve]\n' "$0" >&2
    exit 1
    ;;
esac
