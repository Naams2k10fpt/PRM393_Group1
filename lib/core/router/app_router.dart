import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/kahoot/kahoot_entry_screen.dart';
import '../../features/profile/change_password_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';

/// Route paths. Use these constants with context.go / context.push instead of string literals.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const checkEmail = '/check-email';
  static const home = '/';
  static const kahoot = '/kahoot';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const changePassword = '/profile/change-password';

  /// Reachable without an account. Kahoot players may join as guests.
  static const public = {login, register, checkEmail, kahoot};
}

/// Re-evaluates [redirect] when the auth status changes, so login/logout/revoked tokens navigate by themselves.
GoRouter createRouter(AuthController auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth.statusListenable,
    redirect: (context, state) => redirectFor(auth.status, state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: AppRoutes.checkEmail,
        // Only reachable from a successful registration; without its arguments (e.g. app restart) go to login.
        redirect: (context, state) => state.extra is CheckEmailArgs ? null : AppRoutes.login,
        builder: (context, state) => CheckEmailScreen(args: state.extra! as CheckEmailArgs),
      ),
      // Nested so the page stack can be rebuilt from the URL alone (deep link, sign-in redirect):
      // /profile/edit always has Profile and Home beneath it.
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(path: 'edit', builder: (context, state) => const EditProfileScreen()),
              GoRoute(path: 'change-password', builder: (context, state) => const ChangePasswordScreen()),
            ],
          ),
        ],
      ),
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
      const signedOutOnly = {AppRoutes.splash, AppRoutes.login, AppRoutes.register, AppRoutes.checkEmail};
      return signedOutOnly.contains(location) ? AppRoutes.home : null;
  }
}
