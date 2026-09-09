#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/package-app.sh" debug
open "$ROOT/artifacts/Lid.app"
