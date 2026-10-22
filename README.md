# Quiz Management Mobile (PRM393)

Flutter mobile app for the Quiz Management system — the mobile version of
[PRN232_Group5](https://github.com/Naams2k10fpt/PRN232_Group5) (web: https://prn232-group5.onrender.com).

## Features

- Account: login, register (email verification), profile, change password
- Kahoot Live player: join by PIN or QR code, answer in realtime (SignalR)
- Subjects and decks, flashcard study with flip/swipe and review progress
- Personal quizzes: single/multiple answers, timer, draft recovery, results and paged history
- Study groups: create/discover/join, cancel pending requests, realtime chat and unread counts

TV3 implementation and verification: [Quiz and group chat](docs/tv3-mobile.md).
Channel chat with replies, reactions and study files: [TV3 channel chat](docs/channel-chat.md).

## Getting started

```bash
flutter pub get
flutter test
flutter run -d chrome                                             # against the Render backend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5039   # against a local backend
```

Demo account (also on Render): `user.demo@quiz.local` / `Test@123456`.

Project layout and conventions: see [CLAUDE.md](CLAUDE.md).
