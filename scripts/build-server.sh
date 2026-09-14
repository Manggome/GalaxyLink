#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ANDROID_HOME="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
export ANDROID_PLATFORM=35 ANDROID_BUILD_TOOLS=35.0.0
export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
export BUILD_DIR="$PWD/.build/server"
mkdir -p "$BUILD_DIR"
bash vendor/scrcpy-4.1/server/build_without_gradle.sh
