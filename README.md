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
2. Install the companion as a login item, giving it that same path:

   ```bash
   ./Companion/login-item.sh install /tmp/mpv-single.sock
   ```

   It starts now and at every login, restarts itself if it ever quits, and
   waits for mpv to come and go. Rerun the same command after changing the
   companion's code; `./Companion/login-item.sh uninstall` removes it.
   Its log is `~/Library/Logs/MPV Remote/companion.log`.

   To run it in a terminal instead (stop the login item first, they share a port):

   ```bash
   swift run --package-path Companion mpv-remote --socket /tmp/mpv-single.sock
   ```
3. Run the app from Xcode. It finds the Mac on the network by itself; tap it
   and enter the 4-digit code, which the Mac shows as a notification (and
   writes to the log). After that the phone reconnects without asking.

To run the app on a real iPhone, pick your team under *Signing & Capabilities*
(the bundle identifier is `com.ryudexter.mpvremote`).

## TestFlight

Once:

1. Sign in to Xcode with your developer Apple ID (*Settings → Accounts*) and
   pick your team under *Signing & Capabilities*.
2. In [App Store Connect](https://appstoreconnect.apple.com), *Apps → + → New App*:
   iOS, any name, bundle ID `com.ryudexter.mpvremote`, any SKU. (The bundle ID
   only appears in that list after Xcode has registered it — building once with
   your team selected does that.)
3. Under *TestFlight → Internal Testing*, make a group and add yourself.

Then, for every build:

```bash
./App/testflight.sh
```

Install the TestFlight app on your iPhone; builds arrive there after Apple
processes them.

### App Store art

`AppStore/` holds the product-page header and the 6.9-inch screenshots.
Both are generated, as is the app icon:

```bash
swift App/Tools/make-icon.swift App/MPVRemote/Assets.xcassets/AppIcon.appiconset/AppIcon.png
swift App/Tools/make-store-art.swift <raw-screenshots-dir> App/MPVRemote/Assets.xcassets/AppIcon.appiconset/AppIcon.png AppStore
```

The raw screenshots come from the iPhone 18 Pro Max simulator
(`xcrun simctl io booted screenshot …`), named as in the `shots` list at the
top of `make-store-art.swift`. Internal testers need no review; inviting people outside your
team does go through a short Beta App Review.

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
- The companion has no interface of its own; a menu bar app showing the
  connection and the pairing code is the obvious next step.
- Next/Previous use mpv's stock `playlist-next`/`playlist-prev`, so they skip
  the resume-point and shuffle-history logic that `x`/`z` run in this mpv setup.
