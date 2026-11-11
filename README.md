# Quiz Management Mobile (PRM393)

Flutter mobile app for the Quiz Management system — the mobile version of
[PRN232_Group5](https://github.com/Naams2k10fpt/PRN232_Group5) (web: https://prn232-group5.onrender.com).

The app provides student-facing features. Mentor and admin management stays on the web;
accounts can still sign in regardless of role.

## Features

- Account: login, register (email verification), profile, change password
- Kahoot Live player: join by PIN or QR code, answer in realtime (SignalR)
- Subjects and decks, flashcard study with flip/swipe and review progress
- Personal quizzes: single/multiple answers, timer, draft recovery, results and paged history
- Study groups: create/discover/join, cancel pending requests, realtime chat and unread counts
- Group voice/video rooms shared with the web: microphone, camera, speaker and camera switching

TV3 implementation and verification: [Quiz and group chat](docs/tv3-mobile.md).
Channel chat with replies, reactions and study files: [TV3 channel chat](docs/channel-chat.md).

## Getting started

Use **Flutter 3.47.2 / Dart 3.13.2**. The SDK is pinned in `.fvmrc`; with FVM,
run `fvm install` and prefix the commands below with `fvm`. Otherwise install
that Flutter version and confirm it with `flutter --version`.

Android builds use JDK 17+, Gradle 8.14, AGP 8.12.1 and Kotlin 2.4.0.
Keep AGP 8 while using `file_picker 11.0.2`: with AGP 9 and Flutter's external
Kotlin configuration, this plugin's Kotlin sources are omitted from the build.
On Windows, enable Developer Mode before `flutter pub get` so desktop plugin
symlinks can be generated, even when targeting Android or web.

```bash
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=API_BASE_URL=https://prn232-group5.onrender.com
flutter run -d chrome --dart-define=API_BASE_URL=https://prn232-group5.onrender.com
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5039   # against a local backend
```

Commit `pubspec.lock` when intentionally changing dependencies. Mobile CI uses
the same pinned SDK and verifies dependency resolution, analysis, tests and an
Android release build. Live tests require an isolated backend and are opt-in.
The development fallback is `http://localhost:5039`; always set `API_BASE_URL`
when building for a phone (`http://10.0.2.2:5039` for an Android emulator).

For a public Android release, set `QUIZ_ANDROID_KEYSTORE` to the production
keystore path and `QUIZ_ANDROID_STORE_PASSWORD` to its password. The keystore
uses the alias `quizmanagement` and the same password for the key and store.
Keep the keystore and password private and reuse them for every update. Builds
without these settings use the debug key for local demos and CI.
iOS builds require macOS and Xcode.

### Android updates

The Android app checks for optional updates on Home. **Hồ sơ → Kiểm tra cập nhật**
shows the installed version and lets the user check again. The update action
opens the official HTTPS release link.

When publishing an APK, increase the build number in `pubspec.yaml` and sign it
with the same key as the installed app. Once the artifact is available, set
`AppUpdates__Android__VersionName`, `AppUpdates__Android__VersionCode`,
`AppUpdates__Android__Abi`, and `AppUpdates__Android__UpdateUrl` on the backend
used by the Android build. Use the APK's actual manifest version code (for
example, build `4` produces `2004` for the ARM64 split) and `arm64-v8a` for that
split. The URL must be reachable by the intended users. Leave the settings
unset until an update is ready to distribute.

Demo account (also on Render): `user.demo@quiz.local` / `Test@123456`.

Project layout and conventions: see [CLAUDE.md](CLAUDE.md).
