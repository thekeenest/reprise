#!/usr/bin/env bash
# Builds Reprise.app (universal-ready, ad-hoc signed) into ./dist
#   scripts/build-app.sh            release build
#   scripts/build-app.sh --install  also copies to /Applications and links the CLI
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
APP="dist/Reprise.app"
CONFIG="release"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG" --product RepriseApp
swift build -c "$CONFIG" --product reprise
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp "$BIN/RepriseApp" "$APP/Contents/MacOS/Reprise"
cp "$BIN/reprise" "$APP/Contents/Helpers/reprise"

if [ ! -f Resources/AppIcon.icns ]; then
  echo "▸ Rendering icon"
  ICONTMP="$(mktemp -d)"
  swift scripts/make-icon.swift "$ICONTMP" >/dev/null
  SET="$ICONTMP/AppIcon.iconset"; mkdir -p "$SET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$ICONTMP/icon-1024.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    d=$((s*2)); sips -z $d $d "$ICONTMP/icon-1024.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o Resources/AppIcon.icns
  cp "$ICONTMP/icon-1024.png" docs/assets/icon.png
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Reprise</string>
  <key>CFBundleDisplayName</key><string>Reprise</string>
  <key>CFBundleIdentifier</key><string>dev.thekeenest.reprise</string>
  <key>CFBundleExecutable</key><string>Reprise</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

echo "▸ Signing (ad-hoc)"
codesign --force --sign - "$APP/Contents/Helpers/reprise"
codesign --force --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
  echo "▸ Installing to /Applications"
  rm -rf /Applications/Reprise.app
  cp -R "$APP" /Applications/
  mkdir -p "$HOME/.local/bin"
  ln -sf /Applications/Reprise.app/Contents/Helpers/reprise "$HOME/.local/bin/reprise"
  echo "  CLI linked → ~/.local/bin/reprise"
fi

echo "✓ $APP"
