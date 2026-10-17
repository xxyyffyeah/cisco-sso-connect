#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
destination="${1:-$HOME/Applications}"
if [[ "$destination" != /* || "$destination" == / || "$destination" == "$HOME" ]]; then
    echo "Pass an absolute Applications directory, not a home/filesystem root." >&2; exit 1
fi
/bin/bash "$repo_dir/scripts/build.sh"
app_path="$destination/SSO Connect.app"
if [[ -L "$app_path" ]]; then echo "Refusing a symlink app destination." >&2; exit 1; fi
if [[ -e "$app_path" ]]; then
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist" 2>/dev/null || true)
    if [[ "$bundle_id" != org.sshlaunch.app ]]; then echo "Destination is a different app; not overwritten." >&2; exit 1; fi
    backup="$destination/SSO Connect.backup-$(date +%Y%m%d-%H%M%S)-$$.app"
    ditto "$app_path" "$backup"
    printf 'Previous app backed up to: %s\n' "$backup"
fi
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
# Atomic executable replacement preserves an already-running session helper.
cp "$repo_dir/build/SSO Connect.app/Contents/MacOS/SSHLaunch" "$app_path/Contents/MacOS/SSHLaunch.next"
mv -f "$app_path/Contents/MacOS/SSHLaunch.next" "$app_path/Contents/MacOS/SSHLaunch"
cp "$repo_dir/src/Info.plist" "$app_path/Contents/Info.plist"
cp "$repo_dir/build/SSO Connect.app/Contents/Resources/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
xattr -cr "$app_path"
codesign --force --sign - --requirements '=designated => identifier "org.sshlaunch.app"' "$app_path"
codesign --verify --deep --strict "$app_path"
touch "$app_path"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app_path"
printf 'Installed: %s\nNo SSH config, credentials, or VS Code settings were changed.\n' "$app_path"
