#!/bin/bash
# LidAwake.app をビルドして ~/Applications に配置する。再実行OK。
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/LidAwake.app"
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
  <key>CFBundleName</key><string>LidAwake</string>
  <key>CFBundleDisplayName</key><string>LidAwake</string>
  <key>CFBundleIdentifier</key><string>com.yanagi.lidawake</string>
  <key>CFBundleExecutable</key><string>LidAwake</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▶ Swift コンパイル"
swiftc -O -swift-version 5 \
  -framework Cocoa -framework ServiceManagement \
  -o "$MACOS/LidAwake" "$SRC_DIR/LidAwake.swift"

echo "▶ アドホック署名（ログイン項目登録に必要）"
codesign --force --sign - --identifier com.yanagi.lidawake "$APP"

echo "✅ 完成: $APP"
echo "   起動するには: open \"$APP\""
