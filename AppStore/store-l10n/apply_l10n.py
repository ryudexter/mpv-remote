#!/usr/bin/env python3
"""Localized App Store text for MPV Player Remote (App Store Connect app 6823685362), from locales.json.

    python3 -I AppStore/store-l10n/apply_l10n.py check
    python3 -I AppStore/store-l10n/apply_l10n.py status
    python3 -I AppStore/store-l10n/apply_l10n.py apply --version 1.4 [--locales en-US,en-GB,...] [--name-suffix]
                                                        [--send]

Written 2026-11-24 (proposal.md, baseline-2026-11-24.md). Nothing here was sent to App Store Connect then: 1.3 is
live and no version 1.4 existed, so nothing was editable.

- check: offline. Apple's limits counted in characters (name and subtitle 30, keywords 100, promotional text 170,
  description and What's New 4000), NFC, keyword rules (comma-separated, no spaces next to commas, no empty entry,
  no word twice, no word already in the name or subtitle), no Apple product name in a name or subtitle, no price
  word in a name, subtitle, keywords or promotional text, no other app's name in a name, subtitle or keywords,
  every non-English description ends with the "screens are in English" line, and no keyword repeated across
  localizations that one storefront searches together (Apple adds their fields up).
- status: GETs only. The iOS versions and app infos, which of them can be edited now, and which of these locales
  each one has.
- apply: a dry run unless --send. Needs --version (an existing iOS version in an editable state; this script never
  creates a version and never submits anything). Refuses while that version isn't editable or there isn't exactly
  one app info that isn't live. Then:
    1. app info: PATCH the locales it has (en-US gets its subtitle); POST the new ones with name, subtitle and the
       en-US privacy policy URL. If App Store Connect refuses a POST with HTTP 409 (an app info in review does that),
       that locale goes "version-first": step 2 creates its version localization, Apple then adds the locale to the
       app info with en-US's name, and step 3 PATCHes the name and subtitle on.
    2. version: PATCH the locales it has; POST the new ones (description, keywords, promotional text, What's New,
       support URL). A new version starts with an empty promotional text, so it is always written.
    3. app info again, for the version-first locales.
    Every write is read back and compared; the states of all versions and app infos are printed at the end to show
    nothing else moved.
  --locales limits it to the locales the user approved (en-US is never added unless listed).
  --name-suffix uses a locale's "nameWithSuffix" (proposal.md, optional names) instead of "MPV Player Remote".

Calls the API only through ~/.appstoreconnect/asc.py. The text is Claude's and not checked by a native speaker.
"""
import json, os, re, subprocess, sys, tempfile, unicodedata

APP = "6823685362"
HERE = os.path.dirname(os.path.abspath(__file__))
ASC = os.path.expanduser("~/.appstoreconnect/asc.py")
TEXT = os.path.join(HERE, "locales.json")
BRAND = "MPV Player Remote"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
LIVE_INFO = {"READY_FOR_DISTRIBUTION"}
INFO_FIELDS = ("name", "subtitle")
VERSION_FIELDS = ("description", "keywords", "promotionalText", "whatsNew")
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotionalText": 170, "description": 4000,
          "whatsNew": 4000}
ENGLISH = {"en-US", "en-GB", "en-CA", "en-AU"}
# Apple product names: 5.2.5 rejections (Cingle Mac, MPV Tiger) for these in a name or subtitle.
APPLE_PRODUCTS = {"apple", "iphone", "ipad", "ipados", "ios", "mac", "macs", "macos", "macbook", "imac", "watch",
                  "watchos", "tvos", "siri", "airplay", "airpods", "homepod", "facetime", "アップル", "アイフォン",
                  "マック", "애플", "아이폰", "맥", "맥북", "苹果", "蘋果", "айфон", "макбук", "мак"}
# Other apps (2.3.7): never in a name, subtitle or keywords.
OTHER_APPS = {"iina", "vlc", "infuse", "outplayer", "plex", "kodi", "jellyfin", "emby", "elmedia", "movist",
              "potplayer", "mplayer", "nplayer", "remotemouse", "unified"}
# Price words: never in a name, subtitle, keywords or promotional text (2.3.7). The description may state the price.
PRICE_WORDS = ("free", "nothing to buy", "price", "purchase", "discount", "trial", "gratis", "gratuit", "gratuite",
               "gratuito", "grátis", "kostenlos", "umsonst", "бесплатн", "ücretsiz", "bedava", "fiyat", "無料",
               "タダ", "免费", "免費", "무료", "$", "€", "£", "¥", "₺")
# The last line of every non-English description says the app's screens are in English.
ENGLISH_SCREENS = {
    "es-MX": "Las pantallas de la app están en inglés.",
    "pt-BR": "As telas do app estão em inglês.",
    "de-DE": "Die Oberfläche der App ist auf Englisch.",
    "fr-FR": "Les écrans de l’app sont en anglais.",
    "fr-CA": "Les écrans de l’app sont en anglais.",
    "ru": "Интерфейс приложения на английском языке.",
    "tr": "Uygulamanın ekranları İngilizcedir.",
    "ja": "アプリの画面は英語です。",
    "ko": "앱 화면은 영어로 되어 있습니다.",
    "zh-Hans": "App 界面为英文。",
    "zh-Hant": "App 介面為英文。",
}
# Storefronts and the English localization each searches next to its own (Apple's "App Store localizations" table;
# only the locales this app has or proposes). A local keyword that repeats a word of that English localization (its
# keywords, name or subtitle) is a wasted slot there, since Apple adds the fields up. Duplicates between two local
# languages (es-MX and pt-BR both searched in the US, say) are allowed: each one's home store needs it.
STOREFRONTS = {
    "United States": ("en-US", ["es-MX", "fr-FR", "pt-BR", "ru", "ko", "zh-Hans", "zh-Hant"]),
    "Japan": ("en-US", ["ja"]),
    "Türkiye": ("en-GB", ["tr"]),
    "Mexico and Latin America": ("en-GB", ["es-MX"]),
    "Brazil": ("en-GB", ["pt-BR"]),
    "Korea": ("en-GB", ["ko"]),
    "China mainland": ("en-GB", ["zh-Hans"]),
    "Taiwan, Hong Kong, Macau": ("en-GB", ["zh-Hant"]),
    "Russia": ("en-GB", ["ru"]),
    "Switzerland": ("en-GB", ["de-DE", "fr-FR"]),
    "Canada": ("en-CA", ["fr-CA"]),
}
CJK = re.compile(r"[぀-ヿ㐀-鿿가-힯]")

DRY = "--send" not in sys.argv


def arg(flag):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv and sys.argv.index(flag) + 1 < len(sys.argv) else None


def fold(word):
    return "".join(c for c in unicodedata.normalize("NFD", word.lower()) if not unicodedata.combining(c))


def words(text):
    return {fold(w) for w in re.findall(r"[^\W_]+", text)}


def in_title(keyword, title):
    """A keyword is wasted if Apple already has it from the name or subtitle."""
    k = fold(keyword)
    return k in words(title) or (bool(CJK.search(keyword)) and k in fold(title))


def price_words(text):
    t = text.lower()
    hits = []
    for p in PRICE_WORDS:
        if re.match(r"\w", p) and not CJK.search(p):
            if re.search(rf"(?<![^\W\d_]){re.escape(p)}", t):
                hits.append(p)
        elif p in t:
            hits.append(p)
    return hits


def load():
    with open(TEXT, encoding="utf-8") as f:
        data = json.load(f)
    return {k: v for k, v in data.items() if not k.startswith("_")}


def name_of(f, suffix):
    return f["appInfo"].get("nameWithSuffix") if suffix and f["appInfo"].get("nameWithSuffix") else f["appInfo"]["name"]


def texts():
    t = load()
    problems = []
    for loc, f in t.items():
        info, ver = f["appInfo"], f["version"]
        for part, fields in (("appInfo", info), ("version", ver)):
            for k, v in fields.items():
                if not isinstance(v, str):
                    continue
                lim = LIMITS.get("name" if k == "nameWithSuffix" else k)
                if lim and len(v) > lim:
                    problems.append(f"{loc} {k}: {len(v)} > {lim} characters")
                if not unicodedata.is_normalized("NFC", v):
                    problems.append(f"{loc} {k}: not NFC")
                if v != v.strip():
                    problems.append(f"{loc} {k}: leading or trailing space")
        missing = [k for k in VERSION_FIELDS if not ver.get(k)] + [k for k in INFO_FIELDS if not info.get(k)]
        if missing:
            problems.append(f"{loc}: empty {missing}")
        if info["name"] != BRAND:
            problems.append(f"{loc} name is {info['name']!r}, not {BRAND!r} (suffixes go in nameWithSuffix)")
        if info.get("nameWithSuffix") and not info["nameWithSuffix"].startswith(BRAND + ":"):
            problems.append(f"{loc} nameWithSuffix doesn't start with '{BRAND}:'")
        for k in ("name", "nameWithSuffix", "subtitle"):
            v = info.get(k) or ""
            if words(v) & APPLE_PRODUCTS or any(p in v for p in APPLE_PRODUCTS if CJK.search(p)):
                problems.append(f"{loc} {k} names an Apple product: {v!r}")
            if price_words(v):
                problems.append(f"{loc} {k} has a price word: {price_words(v)}")
            if words(v) & OTHER_APPS:
                problems.append(f"{loc} {k} names another app: {sorted(words(v) & OTHER_APPS)}")
        for k in ("keywords", "promotionalText"):
            if price_words(ver[k]):
                problems.append(f"{loc} {k} has a price word: {price_words(ver[k])}")
        kw = ver["keywords"].split(",")
        if "" in kw or any(w != w.strip() for w in kw):
            problems.append(f"{loc} keywords: a space next to a comma, or an empty entry")
        folded = [fold(w) for w in kw]
        if len(folded) != len(set(folded)):
            problems.append(f"{loc} keywords: a word twice: {sorted({w for w in folded if folded.count(w) > 1})}")
        if {fold(w) for w in kw} & OTHER_APPS:
            problems.append(f"{loc} keywords name another app")
        for title in {info["name"] + " " + info["subtitle"],
                      (info.get("nameWithSuffix") or info["name"]) + " " + info["subtitle"]}:
            clash = [w for w in kw if in_title(w, title)]
            if clash:
                problems.append(f"{loc} keywords already in the name or subtitle: {clash}")
        if loc not in ENGLISH:
            line = ENGLISH_SCREENS.get(loc)
            if not line:
                problems.append(f"{loc}: no 'screens are in English' line defined")
            elif not ver["description"].rstrip().endswith(line):
                problems.append(f"{loc} description doesn't end with {line!r}")
    for store, (base, others) in STOREFRONTS.items():
        if base not in t:
            continue
        b = t[base]
        taken = words(b["appInfo"]["name"] + " " + b["appInfo"]["subtitle"]) | {
            fold(w) for w in b["version"]["keywords"].split(",")}
        for loc in others:
            if loc in t:
                dup = [w for w in t[loc]["version"]["keywords"].split(",") if fold(w) in taken]
                if dup:
                    problems.append(f"{store}: {loc} keywords repeat {base}'s words, searched there too: {dup}")
    if problems:
        raise SystemExit("Text problems:\n  " + "\n  ".join(problems))
    return t


def check():
    t = texts()
    for loc, f in t.items():
        i, v = f["appInfo"], f["version"]
        print(f"  {loc:7} name {len(i['name']):2}/30"
              + (f" (suffix {len(i['nameWithSuffix']):2}/30)" if i.get("nameWithSuffix") else " " * 15)
              + f"  subtitle {len(i['subtitle']):2}/30  keywords {len(v['keywords']):3}/100"
              f"  promo {len(v['promotionalText']):3}/170  description {len(v['description']):4}/4000"
              f"  whatsNew {len(v['whatsNew']):3}/4000")
    print(f"{len(t)} locales. All limits and rules pass.")


# --- App Store Connect, through asc.py only ---------------------------------------------------------------------

def asc(method, path, body=None):
    args = ["python3", "-I", ASC, method, path]
    tmp = None
    if body is not None:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
            json.dump(body, f, ensure_ascii=False)
            tmp = f.name
        args.append(tmp)
    try:
        r = subprocess.run(args, capture_output=True, text=True)
    finally:
        if tmp:
            os.unlink(tmp)
    if r.returncode != 0:
        status = r.stderr.split("\n", 1)[0].replace("HTTP ", "").strip()
        return None, status, r.stderr
    out = r.stdout.strip()
    return (json.loads(out) if out.startswith("{") else {}), "200", ""


def get(path):
    data, status, err = asc("GET", path)
    if data is None:
        raise SystemExit(f"GET {path} failed (HTTP {status}):\n{err}")
    return data


def write(method, path, body):
    if DRY:
        attrs = body["data"].get("attributes", {})
        short = {k: (v if len(v) < 60 else v[:57] + "…") for k, v in attrs.items()}
        print(f"    (dry run) {method} {path} {json.dumps(short, ensure_ascii=False)}")
        return "dry"
    data, status, err = asc(method, path, body)
    if data is None:
        if status == "409" and method == "POST":
            return "409"
        raise SystemExit(f"{method} {path} failed (HTTP {status}):\n{err}")
    return "ok"


def versions():
    return get(f"/v1/apps/{APP}/appStoreVersions?limit=50")["data"]


def app_infos():
    return get(f"/v1/apps/{APP}/appInfos")["data"]


def localizations(path):
    return {d["attributes"]["locale"]: d for d in get(path + "?limit=50")["data"]}


def states():
    for v in versions():
        a = v["attributes"]
        print(f"  version {a['platform']} {a['versionString']:5} {a['appStoreState']:24} {v['id']}")
    for i in app_infos():
        print(f"  app info {i['attributes']['state']:24} {i['id']}")


def status():
    t = load()
    print("iOS versions and app infos:")
    states()
    for i in app_infos():
        have = localizations(f"/v1/appInfos/{i['id']}/appInfoLocalizations")
        print(f"  app info {i['id'][:8]} ({i['attributes']['state']}) has {sorted(have)}")
        for loc in ("en-US",):
            if loc in have:
                a = have[loc]["attributes"]
                print(f"    {loc}: name {a['name']!r}, subtitle {a.get('subtitle')!r}")
    editable = [v for v in versions() if v["attributes"]["appStoreState"] in EDITABLE]
    for v in editable:
        have = localizations(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")
        print(f"  {v['attributes']['versionString']} ({v['attributes']['appStoreState']}) has {sorted(have)}; "
              f"of locales.json, missing {sorted(set(t) - set(have))}")
    if not editable:
        print("No editable iOS version: nothing can be written until version 1.4 is created in App Store Connect "
              "(the user does that; this script never creates one).")
    infos = [i for i in app_infos() if i["attributes"]["state"] not in LIVE_INFO]
    print(f"App info for the next version: {infos[0]['id']} ({infos[0]['attributes']['state']})" if infos else
          "No app info for a next version yet (it appears when the version is created).")


def apply():
    number = arg("--version")
    if not number:
        raise SystemExit("apply needs --version X.Y (an existing, editable iOS version). Nothing written.")
    t = texts()
    chosen = arg("--locales")
    if chosen:
        unknown = set(chosen.split(",")) - set(t)
        if unknown:
            raise SystemExit(f"Not in locales.json: {sorted(unknown)}. Nothing written.")
        t = {loc: f for loc, f in t.items() if loc in chosen.split(",")}
    suffix = "--name-suffix" in sys.argv
    target = next((v for v in versions() if v["attributes"]["platform"] == "IOS"
                   and v["attributes"]["versionString"] == number), None)
    if target is None:
        raise SystemExit(f"No iOS version {number}. This script never creates one. Nothing written.")
    vstate = target["attributes"]["appStoreState"]
    if vstate not in EDITABLE:
        raise SystemExit(f"iOS {number} is {vstate}, not editable. Nothing written.")
    infos = [i for i in app_infos() if i["attributes"]["state"] not in LIVE_INFO]
    if len(infos) != 1:
        raise SystemExit(f"Expected one app info that isn't live, found "
                         f"{[(i['id'], i['attributes']['state']) for i in infos]}. Nothing written.")
    info = infos[0]
    info_path = f"/v1/appInfos/{info['id']}/appInfoLocalizations"
    ver_path = f"/v1/appStoreVersions/{target['id']}/appStoreVersionLocalizations"
    print(("DRY RUN (add --send to write). " if DRY else "") +
          f"iOS {number} {target['id']} ({vstate}); app info {info['id']} ({info['attributes']['state']})")

    have_info = localizations(info_path)
    privacy = have_info["en-US"]["attributes"]["privacyPolicyUrl"] if "en-US" in have_info else None
    have_ver = localizations(ver_path)
    support = have_ver["en-US"]["attributes"]["supportUrl"] if "en-US" in have_ver else None
    if not privacy or not support:
        raise SystemExit("en-US has no privacy policy URL or support URL to copy. Nothing written.")

    want_info = {loc: {"name": name_of(f, suffix), "subtitle": f["appInfo"]["subtitle"]} for loc, f in t.items()}
    want_ver = {loc: {k: f["version"][k] for k in VERSION_FIELDS} for loc, f in t.items()}

    def put_info(loc, have):
        fields = want_info[loc]
        if loc in have:
            change = {k: v for k, v in fields.items() if have[loc]["attributes"].get(k) != v}
            if not change:
                print(f"  app info {loc}: already this")
                return "ok"
            print(f"  app info PATCH {loc}: {sorted(change)}")
            return write("PATCH", f"/v1/appInfoLocalizations/{have[loc]['id']}",
                         {"data": {"type": "appInfoLocalizations", "id": have[loc]["id"], "attributes": change}})
        print(f"  app info POST {loc}: {fields['name']} / {fields['subtitle']}")
        return write("POST", "/v1/appInfoLocalizations",
                     {"data": {"type": "appInfoLocalizations",
                               "attributes": dict(fields, locale=loc, privacyPolicyUrl=privacy),
                               "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})

    print("1. App info")
    later = [loc for loc in t if put_info(loc, have_info) == "409"]
    if later:
        print(f"  HTTP 409 for {later}: these go version-first (step 3).")

    print("2. Version")
    for loc, fields in want_ver.items():
        if loc in have_ver:
            change = {k: v for k, v in fields.items() if have_ver[loc]["attributes"].get(k) != v}
            if not change:
                print(f"  version {loc}: already this")
                continue
            print(f"  version PATCH {loc}: {sorted(change)}")
            write("PATCH", f"/v1/appStoreVersionLocalizations/{have_ver[loc]['id']}",
                  {"data": {"type": "appStoreVersionLocalizations", "id": have_ver[loc]["id"], "attributes": change}})
        else:
            print(f"  version POST {loc}")
            write("POST", "/v1/appStoreVersionLocalizations",
                  {"data": {"type": "appStoreVersionLocalizations",
                            "attributes": dict(fields, locale=loc, supportUrl=support),
                            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions",
                                                                           "id": target["id"]}}}}})

    if later:
        print("3. App info, version-first locales")
        now = localizations(info_path) if not DRY else {}
        for loc in later:
            if loc not in now:
                raise SystemExit(f"{loc} still isn't on app info {info['id']} after its version localization. "
                                 "Stopped; nothing else written.")
            put_info(loc, now)

    if DRY:
        print("Dry run: nothing written.")
        return
    compare("app info", want_info, {l: d["attributes"] for l, d in localizations(info_path).items()})
    compare(f"iOS {number}", want_ver, {l: d["attributes"] for l, d in localizations(ver_path).items()})
    print("States now (nothing is submitted by this script):")
    states()


def compare(label, want, got):
    wrong = {loc: [k for k, v in fields.items() if got.get(loc, {}).get(k) != v] for loc, fields in want.items()}
    wrong = {loc: ks for loc, ks in wrong.items() if ks}
    if wrong:
        print(f"{label}: read back DIFFERS: {wrong}")
        sys.exit(1)
    print(f"{label}: all {len(want)} locales read back identical.")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    {"check": check, "status": status, "apply": apply}.get(cmd, lambda: sys.exit(__doc__))()
