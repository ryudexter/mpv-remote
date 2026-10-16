# MPV Remote

Control mpv on your computer from your iPhone, over Wi-Fi.

Two parts that talk to each other:

| | |
|---|---|
| `App/` | The iPhone app (SwiftUI, iOS 26+). Open `App/MPVRemote.xcodeproj` in Xcode. |
| `Companion/` | A small program that runs on the Mac next to mpv. It talks to mpv over mpv's local IPC socket and serves the phone app. |
| `Shared/` | The message format both sides use, so they can't drift apart. |

## Running it

1. mpv must have its IPC socket switched on — `--input-ipc-server=/path` on the
   command line or `input-ipc-server=/path` in `mpv.conf`. (The `mpv-open`
   launcher in `~/.config/mpv` already does this with `/tmp/mpv-single.sock`.)
2. Start the companion with that same path:

   ```bash
   swift run --package-path Companion mpv-remote --socket /tmp/mpv-single.sock
   ```

   It prints a 4-digit pairing code and keeps running. mpv can come and go;
   the companion reconnects on its own.
3. Run the app from Xcode. It finds the Mac on the network by itself; tap it
   and enter the code. After that the phone reconnects without asking.

To run the app on a real iPhone, pick your team under *Signing & Capabilities*
and change the bundle identifier from `com.example.mpvremote`.

## How it fits together

```
iPhone app  ──WebSocket (Wi-Fi, Bonjour _mpvremote._tcp, port 7655)──▶  companion  ──JSON IPC (Unix socket)──▶  mpv
```

- **Pairing.** A phone proves itself once with the code the companion prints and
  receives a random token. Five wrong codes in a row and the code changes.
  Paired phones are listed in `~/Library/Application Support/MPV Remote/paired-devices.json`;
  delete that file to unpair everything.
- **Fixed commands only.** The phone sends commands like `togglePause` or
  `seek(to:)`, and the companion maps each to one fixed mpv command. Raw mpv
  commands are never accepted from the network, because mpv's IPC can also
  start programs.
- **Smooth position without chatter.** While playing, the companion resyncs
  the position once a second (immediately on a seek), and the app extrapolates
  in between.

## Known gaps

- The Wi-Fi connection is not encrypted yet (plain `ws://`). Fine on a home
  network; it should move to TLS before an App Store release.
- The companion is a terminal program; a menu bar app is the obvious next step.
- Next/Previous use mpv's stock `playlist-next`/`playlist-prev`, so they skip
  the resume-point and shuffle-history logic that `x`/`z` run in this mpv setup.
