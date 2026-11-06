#!/usr/bin/env bash
set -euo pipefail
: "${UTIL_SIGN_IDENTITY:?UTIL_SIGN_IDENTITY yok: signing.env oluştur (bkz. signing.env.example)}"
[ "$UTIL_SIGN_IDENTITY" = "-" ] && { echo "Ad-hoc imza yasak"; exit 1; }
# The SwiftPM product stays "Util" (internal name); the shipped app is Tabla.
# The bundle id stays com.yumoteknoloji.util so granted permissions and the clipboard history carry over.
swift build -c release --product Util
APP=build/Tabla.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Util "$APP/Contents/MacOS/Tabla"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign "$UTIL_SIGN_IDENTITY" --identifier com.yumoteknoloji.util "$APP"
codesign --verify --strict "$APP"
