#!/bin/zsh
# Makes the companion start at login, and restart if it ever quits. Or undoes that.
#
#   ./Companion/login-item.sh install [SOCKET]    SOCKET defaults to /tmp/mpvsocket
#   ./Companion/login-item.sh uninstall
#
# Rerun install after changing the companion's code to put the new build in place.
set -euo pipefail

label=local.mpv-remote.companion
here=${0:A:h}
support="$HOME/Library/Application Support/MPV Remote"
binary="$support/mpv-remote"
plist="$HOME/Library/LaunchAgents/$label.plist"
logfile="$HOME/Library/Logs/MPV Remote/companion.log"
domain="gui/$(id -u)"

stop() {
    launchctl bootout "$domain/$label" 2>/dev/null || true
}

case "${1:-}" in
install)
    socket=${2:-/tmp/mpvsocket}
    echo "Building the companion…"
    swift build -c release --package-path "$here"
    stop
    mkdir -p "$support" "${logfile:h}" "${plist:h}"
    # A copy rather than the build folder, so a rebuild can't swap the binary out from under the running one.
    cp "$(swift build -c release --package-path "$here" --show-bin-path)/mpv-remote" "$binary"
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$binary</string>
        <string>--socket</string>
        <string>$socket</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <!-- A background job gets its timers coalesced; button presses should land at once. -->
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$logfile</string>
    <key>StandardErrorPath</key>
    <string>$logfile</string>
</dict>
</plist>
EOF
    launchctl bootstrap "$domain" "$plist"
    echo "Installed: the companion is running now and will start at every login."
    echo "Log: $logfile"
    ;;
uninstall)
    stop
    rm -f "$plist" "$binary"
    echo "Removed. Paired phones are still remembered in $support/paired-devices.json."
    ;;
*)
    sed -n '4,5p' "$0" | sed 's/^# *//'
    exit 64
    ;;
esac
