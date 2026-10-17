#!/bin/zsh
# Saves the notarization login that package.sh uses (keychain profile
# "mpv-remote"), from an App Store Connect API key in ~/Downloads.
# Asks only for the Issuer ID; the key file and its ID are found automatically.
set -euo pipefail

key=$(ls -t ~/Downloads/AuthKey_*.p8 2>/dev/null | head -1 || true)
if [[ -z $key ]]; then
    echo "No AuthKey_….p8 file in Downloads. Download your API key from App Store Connect first."
    exit 1
fi
key_id=${${key:t:r}#AuthKey_}
echo "Using API key $key_id"
echo
echo "Paste your Issuer ID (the code with dashes at the top of the App Store Connect"
echo "API keys page), then press Enter. For an Individual key, just press Enter:"
read -r issuer
if [[ -n $issuer ]]; then
    xcrun notarytool store-credentials mpv-remote --key "$key" --key-id "$key_id" --issuer "$issuer"
else
    # Individual API keys carry no Issuer ID.
    xcrun notarytool store-credentials mpv-remote --key "$key" --key-id "$key_id"
fi
echo
echo "All set. You can delete $key now."
