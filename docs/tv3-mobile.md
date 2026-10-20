# TV3 — Personal quizzes and study-group chat

Home provides **Quiz cá nhân** and **Nhóm học** alongside Subjects/Flashcards and Kahoot.
The backend contract is documented in [PRN232 TV3 API](https://github.com/Naams2k10fpt/PRN232_Group5/blob/main/docs/tv3-quiz-chat-api.md).

## Quiz

- Choose a subject, deck and 1–500 questions, bounded by the available question count.
- Choose one or multiple answers according to the question type. Question chips allow navigation without losing selections.
- A timed attempt automatically submits at expiry. Answers are locked after expiry; a failed submission can be retried manually, subject to the server's submission grace period.
- Drafts are stored per user and resumed using the server attempt ID. A temporary resume failure keeps the draft and prevents a new attempt from overwriting it. An invalid/expired attempt is removed.
- Draft writes and deletion are serialized so a late save cannot recreate a completed attempt's draft in the same screen.
- Results show score, percentage, correct/wrong answers, selections and explanations. History supports paging and opening a past result.
- Quiz is also available from each deck's menu. Results include pass/fail and completion time, support retrying the deck, render Markdown questions/answers/explanations, and let the student report a question with the same reasons as the web. A failed report keeps its note for retry; the server rejects duplicate pending reports and reports against another user's history.

## Groups and chat

- List joined groups and unread counts. Discovery supports search by name/description, subject and access-mode filters, newest/popular sorting, and paging.
- Create a public, approval-required or private group, optionally associated with one of the creator's subjects. Accept/decline in-app invitations, join public groups, cancel pending requests, or paste an invite link and preview the group before confirming.
- Room members and online/web-waiting/offline states update through SignalR. Membership events appear alongside chat history. Revoked access closes room sub-screens as well as the room.
- **Thông tin và quản lý nhóm** shows the member list. Owners/managers can invite by email, approve/reject requests, remove lower-role members and unban accounts. Only owners can change access mode, grant/revoke moderator status, transfer ownership, and create/copy/revoke invitation links (1/7/30 days or permanent). A non-owner can leave; the owner must transfer ownership first. Permissions are enforced by the backend.
- Each room owns one `ChatConnection`. It sends the current JWT through SignalR's token factory, joins the room again after an automatic reconnect and refreshes message history.
- History is paged with `beforeId`; messages are deduplicated by ID when HTTP history, hub events and send acknowledgements overlap.
- Leaving a screen closes the connection. A delayed connection completion does not resume work on a disposed screen.
- A closed/failed connection can be retried. Revoked access returns to the group list. Sending preserves a new draft typed while the previous message is in flight.

## Checks

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Tests use fake REST repositories and a fake room connection for UI failure/recovery scenarios. The live tests below exercise the actual mobile repositories and SignalR implementation.

### Local integration tests

Use a **dedicated, disposable PostgreSQL database**, apply the backend EF migrations, and run `PRN232_Group5/db/seed-demo.sql` against that database only. Never seed an existing user database. Start the backend with that connection and `Email:Provider=Log`; no real emails are needed.

```powershell
$env:LIVE_API_BASE_URL = 'http://127.0.0.1:5049'
$env:TV3_LIVE_MUTATIONS = '1'
flutter test --no-pub test/live/tv3_live_test.dart
Remove-Item Env:LIVE_API_BASE_URL, Env:TV3_LIVE_MUTATIONS
```

The mutating tests run only with explicit opt-in and a localhost URL. They create quiz history and a study group in the disposable database. They verify quiz resume, grading/result parsing, idempotent resubmission, persisted history, two-account SignalR delivery, read positions and room reopening. They do not delete test data; discard the dedicated database after stopping the backend.

## Verification on 19 October 2026

- Flutter suite: **79 passed**, four opt-in live tests skipped in the offline run.
- TV3 live suite: **2 passed**, against an isolated local backend/database.
- Backend suite: **235 passed**, using the configured local PostgreSQL credentials.
- Flutter analyzer: **no issues**. Release web build: **passed**.
- Browser verification against the isolated backend: demo sign-in → Home (all four modules) → choose subject/deck → start quiz → select multiple answers → confirm submission → rendered score/correct answers. Group history loaded and a message sent through SignalR appeared in the room. No browser console errors on the completed run.
- Widget tests cover phone layout and navigation, single/multiple selections, confirmation, draft resume, failed submissions, timer expiry, group creation/approval cancellation, hub duplicates, reconnect catch-up, old messages and disposal during connection setup.

Physical Android/iOS devices, background suspension, network handoff and camera/QR are separate acceptance checks. Flashcards REST API availability depends on the backend TV2 PR; TV3 uses the existing quiz/history/groups endpoints on backend main.

## Running the expanded TV3 features locally

The mobile client and backend must both use the updated source in this workspace; an older Render backend does not expose the new management endpoints. Restart the existing backend after rebuilding, then run:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5039
```

Android emulator uses `http://10.0.2.2:5039`. Invite links copied from the web or mobile can be pasted using the link button on **Nhóm học**. Native OS app-link registration is not included; browser links still open the backend's web invitation page.

Verification on 20 October 2026: backend build has zero warnings/errors; all **243 backend tests** pass, including HTTP management permissions, private invite links/revocation, history ownership for reports and duplicate report rejection. The Flutter suite has **89 passed**, with four opt-in live tests skipped. New widget coverage includes private creation/subject selection, discovery filters, invitation acceptance, owner/moderator actions, ownership transfer, member presence and reconnect status while the roster is open, nested-screen revocation and reporting/retry from quiz results. Existing user's local database was not seeded or reset.
