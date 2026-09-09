#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DURATION="${1:-}"
if [[ "$DURATION" == "--duration" ]]; then
  DURATION="${2:-10}"
  EXTRA=("${@:3}")
elif [[ "$DURATION" == --* ]]; then
  EXTRA=("$@")
  DURATION="10"
else
  DURATION="${DURATION:-10}"
  EXTRA=("${@:2}")
fi

swift run --configuration debug lid-sensor --duration "$DURATION" "${EXTRA[@]}"
