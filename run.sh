#!/usr/bin/env bash
set -euo pipefail
PROJECT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GODOT="${GODOT:-godot}"
printf '[1/3] Importing project assets...\n'
"$GODOT" --headless --editor --path "$PROJECT" --import
printf '[2/3] Checking player and level resources...\n'
"$GODOT" --headless --path "$PROJECT" --fixed-fps 60 --script res://tests/startup_smoke_runner.gd
case "${1:-}" in
  -c|--check) exit 0 ;;
  -e|--editor) exec "$GODOT" --path "$PROJECT" --editor ;;
  *) printf '[3/3] Starting game...\n'; exec "$GODOT" --path "$PROJECT" ;;
esac
