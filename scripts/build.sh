#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
mkdir -p .build/release
bash scripts/build-engine.sh
bash scripts/build-clipboard.sh
swiftc -swift-version 5 -O -parse-as-library -module-cache-path "$CLANG_MODULE_CACHE_PATH" Sources/FoldLink/*.swift -o .build/release/FoldLink
APP="$PWD/dist/FoldLink.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
bash scripts/icon.sh
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/clipboard/FoldLinkClipboard.apk "$APP/Contents/Resources/FoldLinkClipboard.apk"
cp .build/release/FoldLink "$APP/Contents/MacOS/FoldLink"
cp .build/engine/app/scrcpy "$APP/Contents/MacOS/scrcpy-foldlink"
cp /opt/homebrew/opt/scrcpy/share/scrcpy/scrcpy-server "$APP/Contents/Resources/scrcpy-server"
cp vendor/scrcpy-4.1/LICENSE "$APP/Contents/Resources/scrcpy-LICENSE.txt"
cp vendor/scrcpy-4.1/app/data/disconnected.png "$APP/Contents/Resources/disconnected.png"
cp Assets/AppIcon.png "$APP/Contents/Resources/scrcpy.png"
codesign --force --sign - "$APP/Contents/MacOS/scrcpy-foldlink"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FoldLink</string>
<key>CFBundleIdentifier</key><string>local.foldlink.mac</string>
<key>CFBundleName</key><string>Galaxy Link</string>
<key>CFBundleDisplayName</key><string>Galaxy Link</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.7.0</string>
<key>CFBundleVersion</key><string>8</string>
<key>NSLocalNetworkUsageDescription</key><string>같은 Wi-Fi의 갤럭시에 연결해 휴대폰 화면을 표시합니다.</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf 'Built: %s\n' "$APP"
