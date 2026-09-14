#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
BT="$SDK/build-tools/35.0.0"
OUT="$PWD/.build/clipboard"
mkdir -p "$OUT/classes" "$OUT/dex"
javac --release 8 -classpath "$SDK/platforms/android-35/android.jar" -d "$OUT/classes" android-clipboard/src/local/foldlink/clipboard/*.java
"$BT/d8" --lib "$SDK/platforms/android-35/android.jar" --output "$OUT/dex" "$OUT"/classes/local/foldlink/clipboard/*.class
"$BT/aapt2" compile --dir android-clipboard/res -o "$OUT/resources.zip"
"$BT/aapt2" link -I "$SDK/platforms/android-35/android.jar" --manifest android-clipboard/AndroidManifest.xml -o "$OUT/unsigned.apk" "$OUT/resources.zip"
(cd "$OUT/dex" && zip -q -u ../unsigned.apk classes.dex)
"$BT/zipalign" -f 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
if [[ ! -f "$OUT/development.keystore" ]]; then
  keytool -genkeypair -keystore "$OUT/development.keystore" -storepass android -keypass android -alias foldlink -dname "CN=FoldLink Local Development" -keyalg RSA -keysize 2048 -validity 10000 >/dev/null
fi
"$BT/apksigner" sign --ks "$OUT/development.keystore" --ks-pass pass:android --out "$OUT/FoldLinkClipboard.apk" "$OUT/aligned.apk"
"$BT/apksigner" verify "$OUT/FoldLinkClipboard.apk"
