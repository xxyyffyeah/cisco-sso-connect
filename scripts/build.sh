#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
if [[ "$(uname -s)" != Darwin ]]; then echo "SSH Launch requires macOS." >&2; exit 1; fi
if ! xcrun --find clang >/dev/null 2>&1; then
    echo "Install Apple's Command Line Tools with xcode-select --install, then rerun." >&2
    exit 1
fi
app_path="$repo_dir/build/SSH Launch.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$repo_dir/build/AppIcon.iconset"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter \
    -mmacosx-version-min=13.0 -framework Cocoa -framework ApplicationServices -framework Security \
    src/Core.m src/App.m -o "$app_path/Contents/MacOS/SSHLaunch"
cp src/Info.plist "$app_path/Contents/Info.plist"
xcrun clang -fobjc-arc -O2 -framework Cocoa src/Icon.m -o build/make-icon
build/make-icon build/icon.png
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" build/icon.png --out "build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" build/icon.png --out "build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$app_path/Contents/Resources/AppIcon.icns"
# Generated build artifacts can inherit Finder metadata from a synced folder.
xattr -cr "$app_path"
codesign --force --sign - --requirements '=designated => identifier "org.sshlaunch.app"' "$app_path"
codesign --verify --deep --strict "$app_path"
plutil -lint "$app_path/Contents/Info.plist"
printf 'Built: %s\n' "$app_path"
