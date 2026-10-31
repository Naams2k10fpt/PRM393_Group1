# TV3 channel chat

Groups now contain text channels. `#chung` preserves the existing room history. The phone UI opens channels from the `#` button; wide layouts show channels and members beside the timeline.

The same channel drawer also lists **KÊNH THOẠI**. Choose a voice room and tap **Tham gia phòng** to join as a listener with microphone and camera off. Enable either device when ready, switch speaker/camera using the call controls, or choose **Về chat** to keep calling while using the text timeline. The voice dock returns to the call or leaves it. A green border responds to the audio level without a speaking label.

Calls use the backend's authenticated `/hubs/voice` signalling and WebRTC ICE configuration, including TURN credentials when configured by the server. Membership, room capacity and the one-call-per-account rule are enforced by the backend. Devices are released on leave, access revocation and connection loss; reconnecting requires joining again with devices off. Calls currently run in the foreground: backgrounding the app ends the call. Android requests microphone permission on joining, before initializing the shared WebRTC audio engine ([upstream issue #2119](https://github.com/flutter-webrtc/flutter-webrtc/issues/2119)); capture remains off until enabled. Camera permission is requested when enabling video. iOS requests device permissions when enabling capture.

Android has version-guarded compatibility overrides for `flutter_webrtc 1.6.3` in `android/webrtc_compat`: camera startup must not busy-wait on Flutter's platform thread, and renderer disposal abandons its buffer queue and releases EGL on a serial worker. A native completion barrier keeps subsequent camera operations from racing renderer cleanup. Camera changes first release video views, then restore them after capture is ready; tracks and audio remain connected. These prevent platform-thread/EGL deadlocks with incoming video. Gradle compiles the replacements while leaving the cached package untouched. Review/remove these overrides when upgrading the plugin. The original MIT license is included beside them.

Members can reply, edit their own messages, delete their own messages and react. Group managers can create/rename/archive channels and delete messages. Each channel retains its own text/file/reply draft while the room stays open. An edited/deleted source updates its reply quotes, including when the source is not loaded in the timeline.

Attach images or study documents using **Đính kèm ảnh/file**. Limit: three files per message, 5 MiB per file; the server also enforces a 100 MiB group quota. Images are previewed and files are saved through the platform's file picker. Download requests carry the normal JWT header; URLs never contain tokens. File bytes are stored durably by the backend in PostgreSQL.

The backend requires the `AddDiscordStyleChat` migration and new channel endpoints; the old deployed backend is not sufficient. See `PRN232_Group5/docs/tv3-channel-chat.md` for the protocol, permissions and storage rules.

```powershell
flutter pub get
flutter test --no-pub
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5057
```

Local preview tests use an isolated backend/database. To run live tests against a similarly isolated instance:

```powershell
$env:LIVE_API_BASE_URL = 'http://127.0.0.1:5057'
$env:TV3_LIVE_MUTATIONS = '1'
flutter test --no-pub test/live/tv3_live_test.dart
```

The live suite includes two real SignalR clients, channel file upload/download, replies, edits, reactions, read positions, retry idempotency and deletion. Device acceptance still includes Android/iOS picker/save dialogs, app suspension and network handoff. On Windows, native desktop plugin builds require Developer Mode; web builds and widget tests do not.

The opt-in `integration_test/voice_web_test.dart` runs a real native call against an already joined web participant. Supply `API_BASE_URL`, `VOICE_TEST_EMAIL`, `VOICE_TEST_PASSWORD` and optionally `VOICE_TEST_GROUP` (default 1) via `--dart-define-from-file` using a credential file outside the checkout. It checks inbound/outbound audio/video RTP, camera and speaker switching, device toggles, the chat dock, leave and rejoin. Never distribute its test APK; build the normal `lib/main.dart` app afterwards. Release builds must allow Flutter's platform tooling regeneration (omit `--no-pub`) so dev-only plugins are excluded from the generated registrant.
