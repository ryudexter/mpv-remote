# MPV Player Remote: localized App Store text for 1.4 (proposal, 2026-11-24)

**Status: applied 2026-11-26 to iOS 1.4 (`e1a6a8e6`, all 14 locales, app info `48b5824a`), not submitted; the zh name suffixes were not used.** Originally: written, nothing applied. iOS 1.3 is live and no version 1.4 exists in App Store Connect, so nothing is
editable. Everything below goes on with 1.4 (main already has the 1.4 number). The text is in `locales.json`; the
searches behind it are in `baseline-2026-11-24.md`; `apply_l10n.py` checks and applies it.

## What changes

1. **en-US gets a subtitle.** It has none today, the biggest gap: **Wi-Fi Video & Subtitle Control** (30/30).
2. **en-US keywords:** `video,mac,wifi,control,controller,media,movie,subtitles,playback,playlist,computer,film,tv,laptop`
   → `mac,macbook,laptop,computer,wifi,media,movie,film,playlist,playback,audio,watch,controller,chapter` (98/100).
   video, control and subtitle move into the subtitle (Apple combines the fields), tv goes (it pulls in TV-remote
   searches the app can't serve), macbook, audio, watch and chapter come in.
3. **en-US promotional text without price words.** Live: "Made for MPV Player Tiger Version on the Mac App Store,
   with the companion built in. Or use plain mpv with the free MPV Remote script. No account, nothing to buy."
   New (162/170): "Control mpv on your Mac from the couch with your iPhone or Apple Watch: play, skip, volume,
   subtitles and audio tracks. For MPV Player Tiger Version or plain mpv."
4. **en-US description refreshed** (2,603/4,000): it now mentions the Apple Watch app, the picture from mpv,
   double-tap to skip, the iPhone's volume buttons, Enter Address Manually and Try the Demo, and has a plain
   "FREE, WITH NOTHING TO BUY" section (no ads, no in-app purchases, no subscription). Price words stay in the
   description only, as Apple asked after the Tiger rejection.
5. **What's New for 1.4**, true to the commits since the 1.3 build (f3800cc): first (added 2026-11-26) the pixel-art
   tick that comes out of the Dynamic Island or the notch once the app connects (build 5), then the Watch's bigger Play/Pause button
   and first-launch tips (#10), a quick tap needed to pause and no more wrong-way Digital Crown steps (766409d), hints
   that fit the smaller Watches (#13), typed IP addresses that connect, IPv6 included (d565868, 42c5df5), and the
   pairing screen on small iPhones (#12). Companion-only changes (pairing rationing, second mpv) are left out.
6. **13 new localizations** (below), each with every field.
7. **Optional, separate yes:** a local name suffix for zh-Hans and zh-Hant only.

The name stays **MPV Player Remote** everywhere. No Apple product names in any subtitle, no price words in any
name, subtitle, keyword field or promo (`check` enforces both).

## Which languages, and why these

The audience is mpv users, so the set is the default list trimmed to stores where mpv on a Mac has a real following
or where one localization covers many stores. Downloads since launch (26 first downloads): TR 7, US 5, IN 2, CN 2,
CA 2, and VN, ZA, VE, MY, GH, HK, JP, MA one each. 16 of the 26 came from stores that list English (U.K.) but none
of the app's languages, so they don't search its en-US keywords.

| Locale | Stores it is searched in (Apple's table) | Why |
| --- | --- | --- |
| en-GB | UK and ~150 others: Türkiye, India, China, Korea, Latin America, the Gulf, Southeast Asia, Australia… | The most valuable one: "mpv" ranks #164 in the UK and #126 in Türkiye against #9 in the US. |
| en-CA | Canada (with fr-CA only) | Canada searches no en-US field today; 2 downloads. Cheap (en-US text). |
| fr-CA | Canada | French Canada; near-copy of fr-FR (divan, liste de lecture, service infonuagique). Drop it if you want fewer locales. |
| es-MX | Mexico, Latin America, and the US | Spanish-speaking mpv users; one download from Venezuela. |
| pt-BR | Brazil, and the US | Large Mac/mpv community. |
| de-DE | Switzerland now; Germany and Austria once the DSA block lifts | mpv is popular with German users. |
| fr-FR | Switzerland, French-speaking Africa, Canada's fallback, and the US | One download from Morocco. |
| ru | Russia, Kazakhstan, and the US | mpv is widely used there; "mpv" is #163 in Russia today. |
| tr | Türkiye (with en-GB) | Most downloads so far (7). |
| ja | Japan (with en-US) | Japan suggests "mpv remote"; "mpv" alone doesn't list the app. |
| ko | Korea (with en-GB), and the US | "mpv" #89; thin computer-remote searches. |
| zh-Hans | China mainland (with en-GB), and the US | mpv and mpv-based players are popular; 2 downloads; 电脑遥控器 is a real, thin suggestion (median 188). |
| zh-Hant | Taiwan, Hong Kong, Macau (with en-GB), and the US | 電腦遙控器 is thin in Taiwan (median 81); one HK download. |

**Left out, on purpose:** en-AU (Australia and New Zealand search en-GB, which carries the same words); es-ES, it,
nl-NL, pl and other EU-only languages (blocked by the DSA status; add them when it clears); uk (Ukraine searches ru
and en-GB); ar-SA, hi, id, ms, th, vi, no (their stores list en-GB, mpv users there search in English, and nothing in
the baseline shows local demand). Every locale needs What's New on every update from now on, so fewer is better for
a niche app. Any of these can be added later.

## Per locale

All names are `MPV Player Remote` (17/30). Counts are characters.

| Locale | Subtitle | Keywords |
| --- | --- | --- |
| en-US, en-GB, en-CA | Wi-Fi Video & Subtitle Control (30) | `mac,macbook,laptop,computer,wifi,media,movie,film,playlist,playback,audio,watch,controller,chapter` (98) |
| es-MX | Control remoto para tus videos (30) | `reproductor,subtítulo,película,computadora,serie,anime,volumen,pista,velocidad,capítulo,reloj,lista` (99) |
| pt-BR | Controle remoto para vídeos (27) | `reprodutor,legenda,filme,série,anime,computador,notebook,faixa,velocidade,capítulo,relógio,celular` (98) |
| de-DE | Video-Fernbedienung per WLAN (28) | `steuerung,wiedergabe,untertitel,tonspur,lautstärke,serie,notebook,rechner,videoplayer,kapitel,uhr` (97) |
| fr-FR, fr-CA | Télécommande vidéo par Wi-Fi (28) | `contrôle,lecteur,sous-titre,piste,son,ordinateur,portable,série,lecture,chapitre,vitesse,montre` (95) |
| ru | Пульт для видео на компьютере (29) | `компьютера,мак,макбук,ноутбук,плеер,субтитры,звук,громкость,дорожка,фильм,сериал,аниме,скорость,часы` (100) |
| tr | Bilgisayar Video Kumandası (26) | `kumanda,uzaktan,kontrol,oynatıcı,altyazı,ses,dizi,anime,dizüstü,bölüm,kablosuz,saat,telefon` (91) |
| ja | パソコンの動画をWi-Fiでリモコン操作 (20) | `マック,プレイヤー,プレーヤー,再生,字幕,音量,音声,スマホ,アップルウォッチ,映画,アニメ,倍速,早送り,プレイリスト,チャプター,ノートパソコン,メディア,コントローラー,無線,マックブック` (98) |
| ko | Wi-Fi로 쓰는 컴퓨터 동영상 리모컨 (21) | `맥,맥북,노트북,플레이어,재생,자막,음량,볼륨,오디오,영화,애니,재생목록,챕터,배속,무선,애플워치,컨트롤러,리모콘,미디어,빨리감기,홈시어터,아이폰` (81) |
| zh-Hans | 手机遥控电脑视频播放，字幕音轨一键切换 (19) | `播放器,苹果电脑,笔记本,影音,电影,动漫,番剧,音量,倍速,快进,播放列表,章节,无线,苹果手表,控制器,局域网,家庭影院,多媒体` (66) |
| zh-Hant | 電腦影片遙控器・字幕音軌一鍵切換 (16) | `手機,播放器,蘋果電腦,筆電,影音,電影,動畫,動漫,追劇,音量,倍速,快轉,播放清單,章節,無線,蘋果手錶,控制,區域網路,視頻,家庭劇院,多媒體` (74) |

In English: es-MX/pt-BR "Remote control for (your) videos"; de "Video remote over Wi-Fi"; fr "Video remote over
Wi-Fi"; ru "Remote for video on the computer"; tr "Computer video remote"; ja "Control the computer's videos by
remote over Wi-Fi"; ko "Computer video remote that works over Wi-Fi"; zh-Hans "Phone remote for video playback on
the computer, switch subtitles and audio in one tap"; zh-Hant "Computer video remote, switch subtitles and audio in
one tap".

**Why these words.** The baseline shows the app can't reach the head searches (remote for mac, computer remote,
media remote and their local forms are led by apps with 600–6,300 ratings), but people who find it through "mpv"
and "mpv remote" (#2 in the US, UK and Japan) need to see at once that it's a remote for a video player on a
computer. So each subtitle says *remote + video + computer/Wi-Fi* in the words that market uses (リモコン, 리모컨,
遥控/遙控, пульт, kumanda, Fernbedienung, télécommande, control/controle remoto), and the keywords add the
feature words mpv users care about (subtitles, audio tracks, speed, chapters, playlist), the Mac and Watch in local
script, and film/series/anime. "Computer" rather than "PC" (and no `pc` keyword), since the app needs a Mac.

**Keyword rules the check enforces:** comma-separated without spaces, no word twice, nothing already in the name
or subtitle, no other app's name, no price word, and no local keyword that repeats a word of the English
localization the same store searches (en-US in the US and Japan, en-GB elsewhere, en-CA in Canada), since Apple adds
those fields up. That's why `audio`, `film`, `mac` and `player` appear only in the English fields.

Every non-English description ends with one line saying the app's screens are in English (e.g. "Uygulamanın
ekranları İngilizcedir.", "アプリの画面は英語です。"). UI labels inside the descriptions (Enter Address Manually, Try the
Demo) stay in English for the same reason.

## Optional names (separate approval)

Only China's 电脑遥控器 ("computer remote") is a real suggestion that's thin enough (median 188, the app not in);
Taiwan's 電腦遙控器 is thin (median 81) but has no suggestion. Both searches mostly want mouse/keyboard apps.

| Locale | Name | Length |
| --- | --- | --- |
| zh-Hans | MPV Player Remote: 电脑遥控器 | 24/30 |
| zh-Hant | MPV Player Remote: 電腦遙控器 | 24/30 |

No other language fits a useful phrase in 30 characters ("MPV Player Remote: Fernbedienung" is 32). Apply with
`--name-suffix` only after a yes.

## Least sure

All non-English text is Claude's and not read by a native speaker. Least sure: **ko** and **zh-Hans / zh-Hant**
(subtitle phrasing and the keyword choices), then **ja** and **tr**. es-MX, pt-BR, de-DE, fr-FR/fr-CA and ru are
more conventional. A native read of the subtitles alone would remove most of the risk.

## Open questions for you

1. **Tiger isn't on the Mac App Store yet** (1.0 is WAITING_FOR_REVIEW). The new text, like the live 1.3 text, says
   MPV Player Tiger Version is "on the Mac App Store". Submit 1.4 only after Tiger is live (as with 1.2), or change
   those lines to "coming to the Mac App Store"?
2. **Category:** the app's primary category is Productivity; its "mpv" neighbours are Photo & Video or
   Entertainment (the other "MPV Remote" is Entertainment). Switch to Photo & Video with 1.4? Not done by the script.
3. **fr-CA and en-CA**: keep both (cheap, Canada searches no other field), or drop fr-CA to keep the set smaller?
4. **Optional zh suffixes**: yes or no.
5. **en-US subtitle**: "Wi-Fi Video & Subtitle Control" (chosen), or "Control Video on Your Computer" (30), which
   reads more plainly but drops "subtitle" and "Wi-Fi"?
6. The description keeps the live text's spelling "MPV Player Tiger Version"; the Mac App Store name is
   "MPV Player- Tiger Version". Keep it?

## Apply order (when 1.4 exists)

1. You create iOS version 1.4 in App Store Connect and attach its build (this script never creates or submits a
   version). The new app info appears with it.
2. From the repo root:
   ```
   python3 -I AppStore/store-l10n/apply_l10n.py check
   python3 -I AppStore/store-l10n/apply_l10n.py status
   python3 -I AppStore/store-l10n/apply_l10n.py apply --version 1.4            # dry run, prints every write
   python3 -I AppStore/store-l10n/apply_l10n.py apply --version 1.4 --send     # writes, reads back, compares
   ```
   Add `--locales en-US,en-GB,…` to write only the approved ones, and `--name-suffix` only after a yes on the
   optional names. The script PATCHes en-US (subtitle on the app info; description, keywords, promo and What's New on
   the version), POSTs the new app-info localizations (name, subtitle, en-US's privacy URL), and if App Store Connect
   answers 409 it creates the version localization first and PATCHes the name and subtitle afterwards. New version
   localizations get en-US's support URL.
3. `status` again; the new locales show en-US's screenshots, which is fine.
4. Submitting stays your call.
5. About a week after 1.4 is live, re-run the baseline (`baseline-2026-11-24.md`, last section) and compare.

From 1.4 on, every update needs What's New in all 14 locales.
