#!/usr/bin/env bash
# Start the bundled watermarks-remover cleaning service.
# Python 3.10+ stdlib only — no venv, no pip install.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${WATERMARKS_HOST:-127.0.0.1}"
PORT="${WATERMARKS_PORT:-8765}"

exec python3 "$ROOT/service/scripts/server.py" --host "$HOST" --port "$PORT" "$@"
