# TRACE

> Don't optimize your life. Remember it.

A quiet, local-first record of what you actually did. Build. Read. Explore. Live.

`CLAUDE.md` is the product brief. `PLAN.md` is the implementation plan and
the current status of each phase.

## Running

```bash
flutter pub get
flutter run
```

That is the whole app. No account, no server, no configuration — everything
lives in a SQLite file on the device.

Sync is optional and stays hidden unless both backend URLs are supplied at
build time. Copy `config/neon.example.json` to `config/neon.json` (gitignored),
fill in the two URLs from the Neon Console, then:

```bash
flutter run --dart-define-from-file=config/neon.json
```

## Sync backend (Neon)

One-time setup, in order:

1. In the Neon Console, open **Data API** and enable it with **Managed Better
   Auth**. This also creates the `authenticated` role the schema grants to.
2. Run each file in `db/migrations/` in order (`001_…`, `002_…`, …) in the
   SQL Editor, then refresh the Data API schema cache — Console → Data API →
   **Refresh schema cache**, or `neon data-api refresh-schema --database neondb`.
   The Data API does not see new columns until you do.

   Upgrading an existing project, in this order:
   1. Run `002`. Older builds keep working against it; newer builds need it.
   2. Install the new build on every device.
   3. Run `003`. It drops `books.current_page`, which older builds still send,
      so it waits until none are left. Newer builds work with or without it.
3. Create the one account: `bash tool/neon_check.sh`, answering `y`. The same
   script, answering `n`, re-checks sign-in, the token exchange and RLS at any
   time. It never prints a token.

Before shipping a release build, run:

```bash
bash tool/ship.sh
```

It logs in to Neon, writes `config/neon.json` from the project, signs in once
to prove the settings work, then does the lock-down below and builds the
release bundle — and offers to install it on a connected Android phone. It
asks before changing anything on Neon and is safe to re-run. By hand, the same
steps are:

- **Disable sign-ups**, so the public auth endpoint cannot mint accounts:
  Console → Auth settings, or
  `neon neon-auth config email-password update --disable-sign-up`.
- **Stop relying on localhost.** Add a trusted domain you control
  (`neon neon-auth domain add https://trace.example.com`), set
  `NEON_AUTH_ORIGIN` to it in `config/neon.json`, then turn **Allow Localhost**
  off. Re-run the check with `NEON_AUTH_ORIGIN=… bash tool/neon_check.sh`.
- Build with the config: every `flutter build` below takes
  `--dart-define-from-file=config/neon.json`. Without it the build is
  local-only and shows no Sync screen at all.

Once signed in, the app syncs on its own — on launch, on resume, when the
network returns and a few seconds after an edit. If the session ends, it
signs out quietly and the Sync screen asks for the password again; nothing
local is touched.

## Tests

```bash
flutter test
flutter analyze
```

## Releasing

### Android

Release builds are signed from `android/key.properties`, which is gitignored.
Without it the build falls back to debug keys, so `flutter run --release` works
on a fresh clone.

Create a keystore once, and keep it somewhere that is not this repository —
losing it means you can never ship an update under the same listing:

```bash
keytool -genkey -v -keystore ~/trace-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias trace
```

Then copy `android/key.properties.example` to `android/key.properties` and fill
it in.

```bash
flutter build appbundle --release --dart-define-from-file=config/neon.json   # Play Store
flutter build apk --release --split-per-abi --dart-define-from-file=config/neon.json   # sideloading, ~21 MB each
```

A plain `flutter build apk --release` produces one ~59 MB APK carrying all three
ABIs. Nobody downloads all three; prefer the bundle or the split.

### iOS

Signing is configured in Xcode (`ios/Runner.xcworkspace`, Runner target,
Signing & Capabilities). It needs an Apple developer account and a Mac, and is
not scripted here.

```bash
flutter build ipa --release --dart-define-from-file=config/neon.json
```

### Icons

Every launcher icon is generated from one script so they cannot drift apart.
`assets/icon/trace-icon.png` is the 1024px source of record. See
`tool/make_icons.py`.

### Store listing

Copy for both stores, including the data-safety answers, is in
`store/listing.md`.
