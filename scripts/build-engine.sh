#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export UV_CACHE_DIR="$PWD/.build/uv-cache"
export UV_TOOL_DIR="$PWD/.build/uv-tools"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
uv tool run --with ninja --from meson meson setup .build/engine vendor/scrcpy-4.1 --buildtype=release -Dcompile_server=false -Dportable=true
uv tool run --with ninja --from meson meson compile -C .build/engine
