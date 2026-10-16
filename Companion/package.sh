#!/bin/zsh
# Builds the mpv script package: one folder (main.lua plus the helper) that
# users drop into ~/.config/mpv/scripts/.
#
#   ./Companion/package.sh            builds build/mpv-remote/ and build/mpv-remote.zip
#   ./Companion/package.sh install    also installs it into ~/.config/mpv/scripts/
#
# For downloads, the helper must be signed and notarized or macOS refuses to
# run it. That happens automatically once both exist:
#   - a "Developer ID Application" certificate in your keychain
#     (Xcode → Settings → Accounts → Manage Certificates → +)
#   - a notarytool profile named mpv-remote, made once with
#     xcrun notarytool store-credentials mpv-remote --apple-id YOU --team-id UJ978AQ83J
# Without them the package still works on the Mac that built it.
set -euo pipefail

here=${0:A:h}
build="${here:h}/build"
package="$build/mpv-remote"

echo "Building the helper for Apple silicon and Intel…"
swift build -c release --arch arm64 --arch x86_64 --package-path "$here"
rm -rf "$package" "$build/mpv-remote.zip"
mkdir -p "$package"
cp "$(swift build -c release --arch arm64 --arch x86_64 --package-path "$here" --show-bin-path)/mpv-remote" "$package/"
cp "$here/mpv-script/main.lua" "$package/"

identity=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ { print $2; exit }')
if [[ -n $identity ]]; then
    codesign --force --options runtime --timestamp --sign "$identity" "$package/mpv-remote"
    echo "Signed with $identity"
else
    echo "No Developer ID certificate found: the helper is unsigned, so it only runs on this Mac."
fi

ditto -c -k --keepParent "$package" "$build/mpv-remote.zip"

if [[ -n $identity ]] && xcrun notarytool history --keychain-profile mpv-remote >/dev/null 2>&1; then
    echo "Notarizing…"
    xcrun notarytool submit "$build/mpv-remote.zip" --keychain-profile mpv-remote --wait
fi
echo "Package: $build/mpv-remote.zip"

if [[ ${1:-} == install ]]; then
    destination=~/.config/mpv/scripts/mpv-remote
    rm -rf "$destination"
    cp -R "$package" "$destination"
    echo "Installed: $destination (starts with mpv from now on)"
fi
