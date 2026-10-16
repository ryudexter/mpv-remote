#!/bin/zsh
# Archives the app and uploads it to App Store Connect. It shows up under
# TestFlight once Apple has processed it, usually within 5–15 minutes.
#
# Needs, once: your Apple ID signed in to Xcode (Settings → Accounts), your
# team chosen under Signing & Capabilities, and the app created in App Store Connect.
set -euo pipefail

here=${0:A:h}
build="${here:h}/build"
archive="$build/MPVRemote.xcarchive"

rm -rf "$archive" "$build/export"
echo "Archiving…"
xcodebuild -quiet -project "$here/MPVRemote.xcodeproj" -scheme MPVRemote -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$archive" -allowProvisioningUpdates archive
echo "Uploading to App Store Connect…"
xcodebuild -quiet -exportArchive -archivePath "$archive" -exportOptionsPlist "$here/ExportOptions.plist" \
    -exportPath "$build/export" -allowProvisioningUpdates
echo "Uploaded. It appears under TestFlight in App Store Connect once processing finishes."
