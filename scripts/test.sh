#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -swift-version 5 -parse-as-library -module-cache-path "$PWD/.build/clang-cache" Sources/FoldLink/Core.swift Sources/FoldLink/ImageClipboard.swift scripts/TestRunner.swift -o .build/FoldLinkTests
.build/FoldLinkTests
cc scripts/test-engine.c -o .build/FoldLinkEngineTests
.build/FoldLinkEngineTests
