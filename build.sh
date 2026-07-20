#!/bin/bash
# Fumin.app をビルドして ~/Applications に配置する。再実行OK。
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="/Applications/Fumin.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

echo "▶ クリーンアップ & ディレクトリ作成"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

echo "▶ Info.plist 作成"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Fumin</string>
  <key>CFBundleDisplayName</key><string>Fumin</string>
  <key>CFBundleIdentifier</key><string>com.yanagi.fumin</string>
  <key>CFBundleExecutable</key><string>Fumin</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.2</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▶ Swift コンパイル（ユニバーサル: Apple Silicon + Intel）"
swiftc -O -swift-version 5 -target arm64-apple-macos13 \
  -framework Cocoa -framework ServiceManagement -framework IOKit \
  -o "$MACOS/Fumin-arm64" "$SRC_DIR/Fumin.swift"
swiftc -O -swift-version 5 -target x86_64-apple-macos13 \
  -framework Cocoa -framework ServiceManagement -framework IOKit \
  -o "$MACOS/Fumin-x86_64" "$SRC_DIR/Fumin.swift"
lipo -create -output "$MACOS/Fumin" "$MACOS/Fumin-arm64" "$MACOS/Fumin-x86_64"
rm -f "$MACOS/Fumin-arm64" "$MACOS/Fumin-x86_64"

echo "▶ アドホック署名（ログイン項目登録に必要）"
codesign --force --sign - --identifier com.yanagi.fumin "$APP"

echo "✅ 完成: $APP"
echo "   起動するには: open \"$APP\""
