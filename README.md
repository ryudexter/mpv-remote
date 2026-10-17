# MPV Remote

Control mpv on your computer from your iPhone, over Wi-Fi.
Coming to the App Store as **MPV Player Remote** —
[support](SUPPORT.md) · [privacy policy](PRIVACY.md).

Two parts that talk to each other:

| | |
|---|---|
| `App/` | The iPhone app (SwiftUI, iOS 26+). Open `App/MPVRemote.xcodeproj` in Xcode. |
| `Companion/` | A small program that runs on the Mac next to mpv. It talks to mpv over mpv's local IPC socket and serves the phone app. |
| `Shared/` | The message format both sides use, so they can't drift apart. |

## Running it

### On the Mac: an mpv script

The companion ships as an mpv script, a folder holding `main.lua` and the
helper program. The signed, notarized build is on the
[Releases page](https://github.com/ryudexter/mpv-remote/releases/latest):
[download `mpv-remote.zip`](https://github.com/ryudexter/mpv-remote/releases/latest/download/mpv-remote.zip),
unzip it and move the `mpv-remote` folder into `~/.config/mpv/scripts/`. To
build and install it from source instead:

```bash
./Companion/package.sh install
```

That builds it and copies it to `~/.config/mpv/scripts/mpv-remote/`. From then
on it starts whenever mpv starts and quits when mpv does. It switches on mpv's
IPC socket by itself, or reuses one mpv already has (like the
`/tmp/mpv-single.sock` of the `mpv-open` launcher), so `mpv.conf` needs no
changes. When a phone asks to pair, the 4-digit code appears over the video
and as a notification. Its log is `~/Library/Logs/MPV Remote/companion.log`.

Options go in `~/.config/mpv/script-opts/mpv-remote.conf`: `port=` and `name=`
(how the Mac appears on the phone).

`./Companion/package.sh` on its own builds `build/mpv-remote.zip` for others to
download, signed and notarized when a Developer ID certificate and the
`mpv-remote` notarytool profile exist (`Companion/save-notary-login.sh` saves
that profile from an App Store Connect API key).

Other ways to run the companion, one at a time since they share a port:

- In a terminal: `swift run --package-path Companion mpv-remote --socket /tmp/mpvsocket`
- As a login item that waits for mpv to come and go:
  `./Companion/login-item.sh install /tmp/mpvsocket` (and `uninstall`)

### On the iPhone

Run the app from Xcode. It finds the Mac on the network by itself; tap it and
enter the code. After that the phone reconnects without asking. *Try the Demo*
on the first screen runs a pretend player with no Mac at all — which is also
how App Review can try the app.

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
processes them. Internal testers need no review; inviting people outside your
team does go through a short Beta App Review.

### App Store art

`AppStore/` holds the product-page header and the iPhone screenshots, in the
large (1320×2868) and medium (1179×2556) sizes.
Both are generated, as is the app icon:

```bash
swift App/Tools/make-icon.swift App/MPVRemote/Assets.xcassets/AppIcon.appiconset/AppIcon.png
swift App/Tools/make-store-art.swift <raw-screenshots-dir> App/MPVRemote/Assets.xcassets/AppIcon.appiconset/AppIcon.png AppStore
```

The raw screenshots come from the iPhone 18 Pro Max simulator
(`xcrun simctl io booted screenshot …`), named as in the `shots` list at the
top of `make-store-art.swift`.

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
- Next/Previous use mpv's stock `playlist-next`/`playlist-prev`, so they skip
  the resume-point and shuffle-history logic that `x`/`z` run in this mpv setup.
