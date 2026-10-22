# TV3 channel chat

Groups now contain text channels. `#chung` preserves the existing room history. The phone UI opens channels from the `#` button; wide layouts show channels and members beside the timeline.

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
