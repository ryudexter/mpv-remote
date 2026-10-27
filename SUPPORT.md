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
- A Mac with MPV Player Tiger Version (macOS 15 or later), or with mpv and the
  free MPV Remote script (macOS 14 or later)
- Both on the same Wi-Fi network

Just want to look around first? Tap **Try the Demo** in the app — no Mac
needed.

## Setting up

### Easiest: MPV Player Tiger Version

**[MPV Player Tiger Version](https://github.com/ryudexter/mpv-macos-setup)**,
coming to the Mac App Store, is the player MPV Player Remote is made with: mpv,
ready to use on the Mac, with the MPV Remote script built in. Install it, open
a video, then skip to step 3 below.

### Free: mpv with the MPV Remote script

MPV Player Remote works with plain mpv too, and both are free. mpv itself is on
[GitHub](https://github.com/mpv-player/mpv/releases/latest) and
[mpv.io](https://mpv.io/installation/) (or `brew install mpv` with
[Homebrew](https://brew.sh)). Already use mpv? Start here:

1. **[Download the MPV Remote script for mpv](https://github.com/ryudexter/mpv-remote/releases/latest/download/mpv-remote.zip)**
   and double-click the zip to unpack it.
2. Move the `mpv-remote` folder into `~/.config/mpv/scripts/` (in Finder, press
   *Shift-Command-G* and type `~/.config/mpv/scripts`; create the `scripts`
   folder if it isn't there). That's all on the Mac: it starts by itself
   whenever mpv does, and needs no changes to `mpv.conf`.
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
