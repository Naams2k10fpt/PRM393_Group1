# Quiz Management Mobile — repo notes

Flutter client for the PRN232 backend (`PRN232_Group5`: ASP.NET Core 9 + PostgreSQL, live at
https://prn232-group5.onrender.com). Same features as the website, for phones.

## Layout

```
lib/
  core/       config (base URL), theme, router, shared widgets
  data/       API client (Dio + JWT), token storage, models, repositories — one per backend area
  features/   one folder per feature: auth, profile, home, kahoot, ... (screens + their controller)
  main.dart   wires providers + router
```

- Routes live in `core/router/app_router.dart` (`go_router`); use the `AppRoutes` constants.
- State: `provider` + `ChangeNotifier`. Screens never call Dio directly — they go through a repository.
- Theme: `AppTheme.dark()` / `AppColors` (aligned with the web `site.css`). Only Kahoot keeps `KahootColors`.

## Backend contract

- REST under `/api/*`, JSON, camelCase. Swagger: `<backend>/swagger`. Postman: `PRN232_Group5/docs/postman/`.
- Auth: `POST /api/auth/login` → `accessToken` (JWT, ~7 days, no refresh token). Send
  `Authorization: Bearer <token>`; SignalR hubs take `?access_token=`. The `ApiClient` interceptor does both jobs.
- Errors are `{ code, message, errors?, retryAfterSeconds? }`. Switch on `code`, show `message`
  (already Vietnamese). `ApiException` carries these fields.
- A 401 means the token was revoked or expired (password change, account disabled): the client clears the token
  and the router sends the user to login.

## Run it

- Base URL comes from `--dart-define=API_BASE_URL=...`; default is the Render production URL.
  Local backend: `dotnet run --project QuizManagement --launch-profile http` in PRN232 → `http://localhost:5039`
  (Android emulator: `http://10.0.2.2:5039`).
- Checks: `flutter analyze` and `flutter test` (widget tests use fake repositories — no network).
- Run: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5039` is the lightest way to click
  through. **Disk is tight on the dev machine**: prefer analyze/tests/web; avoid repeated APK or desktop builds,
  and delete `build/` afterwards.

## Conventions

- UI text is Vietnamese; code, comments and commit messages are English.
- New feature = new folder under `features/` + a repository under `data/` + routes in `app_router.dart`.
- A screen that other features open or that needs a deep link gets a route; a feature's own short sub-flow
  (e.g. Kahoot entry → QR scanner) may use `Navigator.push`.
