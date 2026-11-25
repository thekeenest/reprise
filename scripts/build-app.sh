#!/usr/bin/env bash
# Builds Reprise.app (universal-ready, ad-hoc signed) into ./dist
#   scripts/build-app.sh                      release build of the default design (Console)
#   scripts/build-app.sh --world Board        a build whose design is Board (or Studio)
#   scripts/build-app.sh --all                all three designs, side by side in ./dist
#   scripts/build-app.sh --install            also copies to /Applications and links the CLI
set -euo pipefail
cd "$(dirname "$0")/.."

WORLD="Console"; INSTALL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --world) WORLD="$2"; shift 2 ;;
    --install) INSTALL=1; shift ;;
    --all)
      for w in Console Board Studio; do "$0" --world "$w"; done
      exit 0 ;;
    *) echo "unknown option $1"; exit 1 ;;
  esac
done

VERSION="0.3.0"
CONFIG="release"
if [[ "$WORLD" == "Console" ]]; then
  APP="dist/Reprise.app"; BUNDLE_ID="dev.thekeenest.reprise"; NAME="Reprise"; ICON="Resources/AppIcon.icns"
else
  LOWER="$(echo "$WORLD" | tr '[:upper:]' '[:lower:]')"
  APP="dist/Reprise $WORLD.app"; BUNDLE_ID="dev.thekeenest.reprise.$LOWER"; NAME="Reprise $WORLD"; ICON="Resources/AppIcon-$WORLD.icns"
fi

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG" --product RepriseApp
swift build -c "$CONFIG" --product reprise
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp "$BIN/RepriseApp" "$APP/Contents/MacOS/Reprise"
cp "$BIN/reprise" "$APP/Contents/Helpers/reprise"

if [ ! -f "$ICON" ]; then
  echo "▸ Rendering $WORLD icon"
  ICONTMP="$(mktemp -d)"
  swift scripts/make-icon.swift "$ICONTMP" "$WORLD" >/dev/null
  SET="$ICONTMP/AppIcon.iconset"; mkdir -p "$SET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$ICONTMP/icon-1024.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    d=$((s*2)); sips -z $d $d "$ICONTMP/icon-1024.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o "$ICON"
  if [[ "$WORLD" == "Console" ]]; then cp "$ICONTMP/icon-1024.png" docs/assets/icon.png
  else cp "$ICONTMP/icon-1024.png" "docs/assets/icon-$LOWER.png"; fi
fi
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>RepriseWorld</key><string>$WORLD</string>
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

if [[ "$INSTALL" == 1 ]]; then
  echo "▸ Installing to /Applications"
  rm -rf "/Applications/$(basename "$APP")"
  cp -R "$APP" /Applications/
  mkdir -p "$HOME/.local/bin"
  ln -sf "/Applications/$(basename "$APP")/Contents/Helpers/reprise" "$HOME/.local/bin/reprise"
  echo "  CLI linked → ~/.local/bin/reprise"
fi

echo "✓ $APP"
