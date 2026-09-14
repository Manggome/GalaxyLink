#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
objects=()
for obj in .build/engine/app/scrcpy.p/*.o; do
  case "$obj" in *src_main.c.o|*src_screen.c.o) continue;; esac
  objects+=("$obj")
done
cc -D_GNU_SOURCE -D_DARWIN_C_SOURCE -I.build/engine/app -Ivendor/scrcpy-4.1/app/src \
  $(pkg-config --cflags sdl3 libavformat libavcodec libavutil libswresample libusb-1.0) \
  scripts/test-video-window.c "${objects[@]}" \
  $(pkg-config --libs sdl3 libavformat libavcodec libavutil libswresample libusb-1.0) \
  -framework Cocoa -framework Carbon -o .build/FoldLinkVideoWindowTests
SDL_VIDEODRIVER=dummy .build/FoldLinkVideoWindowTests
