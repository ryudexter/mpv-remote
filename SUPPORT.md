# MPV Player Remote — Support

MPV Player Remote turns your iPhone into a remote control for
[mpv](https://mpv.io) on your Mac, over your home Wi-Fi.

## Getting help

Something not working, or an idea for a feature?
**[Open an issue](https://github.com/ryudexter/mpv-remote/issues/new)** and
describe what you tried and what happened. Include your iPhone and macOS
versions if you can.

## What you need

- An iPhone with iOS 26 or later
- A Mac running mpv and the MPV Player Remote companion
- Both on the same Wi-Fi network

## Setting up

1. Install and start the companion on your Mac (see the
   [README](README.md#running-it) for now; a downloadable Mac app is coming).
2. Make sure mpv runs with its control socket switched on: add
   `input-ipc-server=/tmp/mpvsocket` to your `mpv.conf`, or start mpv with
   `--input-ipc-server=/tmp/mpvsocket`.
3. Open MPV Player Remote on your iPhone, allow it to find devices on your
   local network, tap your Mac, and enter the 4-digit code your Mac shows.

## Common problems

**My Mac doesn't appear in the list.**
Check that the companion is running and that both devices are on the same
Wi-Fi. Guest and hotel networks often stop devices from seeing each other. If
you declined the local network prompt, turn it back on in
*Settings → Privacy & Security → Local Network → MPV Player Remote*. You can
also tap *Enter Address Manually* and type your Mac's IP address.

**It connects, but says "Nothing Playing".**
mpv isn't reachable through its control socket. Make sure it was started with
the same `input-ipc-server` path the companion uses.

**I lost the pairing code.**
Cancel and tap your Mac again; the companion shows the code again as a
notification on your Mac.

## Privacy

MPV Player Remote collects no data. See the [privacy policy](PRIVACY.md).

MPV Player Remote is an independent app and is not affiliated with or
endorsed by the mpv project.
