import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/kahoot/kahoot_entry_screen.dart';

/// Route paths. Use these constants with context.go / context.push instead of string literals.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const kahoot = '/kahoot';

  /// Reachable without an account. Kahoot players may join as guests.
  static const public = {login, kahoot};
}

/// Re-evaluates [redirect] whenever [auth] changes, so login/logout/revoked tokens navigate by themselves.
GoRouter createRouter(AuthController auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) => redirectFor(auth.status, state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
      // Kahoot screens push their own sub-screens (QR scanner, game) with Navigator.
      GoRoute(path: AppRoutes.kahoot, builder: (context, state) => const KahootEntryScreen()),
    ],
  );
}

String? redirectFor(AuthStatus status, String location) {
  switch (status) {
    case AuthStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.signedOut:
      return AppRoutes.public.contains(location) ? null : AppRoutes.login;
    case AuthStatus.signedIn:
      return location == AppRoutes.splash || location == AppRoutes.login ? AppRoutes.home : null;
  }
}
