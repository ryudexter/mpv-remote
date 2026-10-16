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
- A Mac (macOS 14 or later) with mpv and the MPV Remote script
- Both on the same Wi-Fi network

Just want to look around first? Tap **Try the Demo** in the app — no Mac
needed.

## Setting up

1. Get the MPV Remote script for mpv (the download is coming soon to this
   repository's Releases page; until then, build it with
   `./Companion/package.sh` as described in the [README](README.md#running-it)).
2. Move the `mpv-remote` folder into `~/.config/mpv/scripts/`. That's all on
   the Mac: it starts by itself whenever mpv does, and needs no changes to
   `mpv.conf`.
3. Open a video in mpv. Then open MPV Player Remote on your iPhone, allow it to
   find devices on your local network, and tap your Mac.
4. Enter the 4-digit code that appears over the video in mpv.

## Common problems

**My Mac doesn't appear in the list.**
The script only runs while mpv is open, so open a video first. Both devices
must be on the same Wi-Fi; guest and hotel networks often stop devices from
seeing each other. If you declined the local network prompt, turn it back on
in *Settings → Privacy & Security → Local Network → MPV Player Remote*. You
can also tap *Enter Address Manually* and type your Mac's IP address.

**I have several mpv windows open.**
The remote controls the first one you opened. Once that one closes, the next
mpv window you open takes over.

**I lost the pairing code.**
Cancel and tap your Mac again; the code appears over the video again.

## Privacy

MPV Player Remote collects no data. See the [privacy policy](PRIVACY.md).

MPV Player Remote is an independent app and is not affiliated with or
endorsed by the mpv project.
