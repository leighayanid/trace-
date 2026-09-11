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
build time. See `lib/core/config.dart`:

```bash
flutter run \
  --dart-define=NEON_AUTH_BASE_URL=https://ENDPOINT.neonauth.REGION.aws.neon.tech/neondb/auth \
  --dart-define=NEON_DATA_API_URL=https://ENDPOINT.apirest.REGION.aws.neon.tech/neondb/rest/v1
```

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
flutter build appbundle --release   # Play Store
flutter build apk --release --split-per-abi   # sideloading, ~21 MB each
```

A plain `flutter build apk --release` produces one ~59 MB APK carrying all three
ABIs. Nobody downloads all three; prefer the bundle or the split.

### iOS

Signing is configured in Xcode (`ios/Runner.xcworkspace`, Runner target,
Signing & Capabilities). It needs an Apple developer account and a Mac, and is
not scripted here.

```bash
flutter build ipa --release
```

### Icons

Every launcher icon is generated from one script so they cannot drift apart.
`assets/icon/trace-icon.png` is the 1024px source of record. See
`tool/make_icons.py`.

### Store listing

Copy for both stores, including the data-safety answers, is in
`store/listing.md`.
