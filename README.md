# MPV Remote

Control mpv on your computer from your iPhone and Apple Watch, over Wi-Fi.
Coming to the App Store as **MPV Player Remote** —
[support](SUPPORT.md) · [privacy policy](PRIVACY.md).

Two parts that talk to each other:

| | |
|---|---|
| `App/` | The iPhone app (SwiftUI, iOS 26+) and its Apple Watch app (watchOS 10+), which comes inside it. Open `App/MPVRemote.xcodeproj` in Xcode. |
| `Companion/` | A small program that runs on the Mac next to mpv. It talks to mpv over mpv's local IPC socket and serves the phone app. |
| `Shared/` | The message format both sides use, so they can't drift apart. |

## Running it

### On the Mac: an mpv script

The quickest start is [MPV Player Tiger Version](https://github.com/ryudexter/mpv-macos-setup),
the Mac player this app is made with, coming to the Mac App Store with this
script built in. Any other mpv works too, with the script below.

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

### On the Apple Watch

The Watch app (`App/MPVRemoteWatch`, bundle identifier
`com.ryudexter.mpvremote.watchkitapp`) comes with the iPhone app and installs
with it. Its screen is Cingle Remote's Watch remote, tinted in the iPhone
app's purple: a pad under the computer's name, with what's playing along its
top and Previous, Play/Pause and Next along its bottom. Tap the pad to play or
pause, swipe sideways to skip 10 seconds (a long drag keeps skipping), and
swipe up or down, or turn the Digital Crown, for volume. The button in the
top-left corner has Full Screen, Mute, and the subtitle and audio tracks.

It uses whichever computer the iPhone is set up with, and never pairs itself.
watchOS doesn't let apps open the companion's WebSocket, so the Watch sends
its commands to the iPhone app over WatchConnectivity, and the iPhone forwards
them (`WatchRelay.swift`; the messages are `WatchMessage` in `Shared`). The
iPhone app doesn't need to be open: iOS starts it in the background for the
Watch. The Watch checks in when it opens and every 15 seconds while it's open;
the iPhone connects to the computer on the first check-in and stays connected
for 25 seconds after each message, then lets the connection go. Commands that
arrive while it's still connecting are sent once the companion accepts it. The
iPhone sends the Watch what's playing whenever it changes, except the
position's steady tick, which the Watch works out itself. `App/Common` holds
the formatting both apps share.

It has run in the Watch and iPhone simulators, against the companion's server
and in Demo Mode, including with the iPhone app in the background; not yet on
a real Watch.

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
large (1320×2868) and medium (1179×2556) sizes, and the Watch screenshots
(416×496, from the Apple Watch Series 12 (46mm) simulator).
Both are generated, as is the app icon. `make-icon.swift` draws MPV Player
Tiger Version's Mac icon too (`laptop` instead of `remote`), so the two apps
keep matching icons:

```bash
swift App/Tools/make-icon.swift remote App/MPVRemote/Assets.xcassets/AppIcon.appiconset/AppIcon.png
swift App/Tools/make-store-art.swift <raw-screenshots-dir> App/MPVRemote/Assets.xcassets/AppIcon.appiconset/AppIcon.png AppStore
```

The raw screenshots come from the iPhone 18 Pro Max simulator
(`xcrun simctl io booted screenshot …`, after
`xcrun simctl status_bar booted override --time 09:41 --batteryState discharging --batteryLevel 100`),
named as in the `shots` list at the top of `make-store-art.swift`. The phone
is connected to a stand-in Mac rather than in Demo Mode, so they show
"MacBook Pro" and a picture: `ScreenshotCompanion` runs the companion's own
server with the demo series, sending a frame `make-demo-frame.swift` draws
(an aurora, for "The Northern Lights"):

```bash
swift App/Tools/make-demo-frame.swift /tmp/frame.jpg
HOME=/tmp/shots CFFIXED_USER_HOME=/tmp/shots swift run --package-path App/Tools/ScreenshotCompanion screenshot-companion /tmp/frame.jpg --port 7656 --at 1452
```

Tap *MacBook Pro* and enter the code it prints. The spare home folder keeps
the simulator out of the real companion's `paired-devices.json`.

## How it fits together

```
iPhone app  ──WebSocket (Wi-Fi, Bonjour _mpvremote._tcp, port 7655)──▶  companion  ──JSON IPC (Unix socket)──▶  mpv
    ▲
    └──WatchConnectivity──  Apple Watch app
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
