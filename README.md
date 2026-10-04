# Quiz Management Mobile (PRM393)

Flutter mobile app for the Quiz Management system — the mobile version of
[PRN232_Group5](https://github.com/Naams2k10fpt/PRN232_Group5) (web: https://prn232-group5.onrender.com).

## Features

- Account: login, register (email verification), profile, change password
- Kahoot Live player: join by PIN or QR code, answer in realtime (SignalR)
- More coming: subjects & flashcards, personal quizzes, study-group chat

## Getting started

```bash
flutter pub get
flutter test
flutter run -d chrome                                             # against the Render backend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5039   # against a local backend
```

Demo account (also on Render): `user.demo@quiz.local` / `Test@123456`.

Project layout and conventions: see [CLAUDE.md](CLAUDE.md).
