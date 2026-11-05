#!/usr/bin/env bash
set -euo pipefail
: "${UTIL_SIGN_IDENTITY:?UTIL_SIGN_IDENTITY yok: signing.env oluştur (bkz. signing.env.example)}"
[ "$UTIL_SIGN_IDENTITY" = "-" ] && { echo "Ad-hoc imza yasak"; exit 1; }
swift build -c release --product Util
APP=build/Util.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Util "$APP/Contents/MacOS/Util"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "$UTIL_SIGN_IDENTITY" --identifier com.yumoteknoloji.util "$APP"
codesign --verify --strict "$APP"
