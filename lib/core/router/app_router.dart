import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/decks/deck_list_screen.dart';
import '../../features/flashcards/flashcard_study_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/chat/groups_screen.dart';
import '../../features/kahoot/kahoot_entry_screen.dart';
import '../../features/profile/change_password_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/quiz/quiz_screen.dart';
import '../../features/quiz/quiz_statistics_screen.dart';

/// Route paths. Use these constants with context.go / context.push instead of string literals.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const checkEmail = '/check-email';
  static const home = '/';
  static const kahoot = '/kahoot';
  static const quiz = '/quiz';
  static const quizStatistics = '/quiz/statistics';
  static const groups = '/groups';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const changePassword = '/profile/change-password';
  static const decksOfSubject = '/subjects/:subjectId/decks';
  static const flashcardStudy = '/decks/:deckId/study';

  /// Concrete path for one subject's decks; [decksOfSubject] is the pattern it matches.
  static String decksFor(String subjectId) => '/subjects/$subjectId/decks';

  /// Concrete path for one deck's study session; [flashcardStudy] is the pattern.
  static String studyFor(String deckId) => '/decks/$deckId/study';
  static String quizFor(String subjectId, String deckId) =>
      Uri(
        path: quiz,
        queryParameters: {'subjectId': subjectId, 'deckId': deckId},
      ).toString();

  /// Reachable without an account. Kahoot players may join as guests.
  static const public = {login, register, checkEmail, kahoot};
}

/// Re-evaluates [redirect] when the auth status changes, so login/logout/revoked tokens navigate by themselves.
GoRouter createRouter(AuthController auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth.statusListenable,
    redirect:
        (context, state) => redirectFor(auth.status, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkEmail,
        // Only reachable from a successful registration; without its arguments (e.g. app restart) go to login.
        redirect:
            (context, state) =>
                state.extra is CheckEmailArgs ? null : AppRoutes.login,
        builder:
            (context, state) =>
                CheckEmailScreen(args: state.extra! as CheckEmailArgs),
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
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditProfileScreen(),
              ),
              GoRoute(
                path: 'change-password',
                builder: (context, state) => const ChangePasswordScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'subjects/:subjectId/decks',
            builder:
                (context, state) => DeckListScreen(
                  subjectId: state.pathParameters['subjectId']!,
                  subjectName: state.extra as String?,
                ),
          ),
          GoRoute(
            path: 'decks/:deckId/study',
            builder:
                (context, state) => FlashcardStudyScreen(
                  deckId: state.pathParameters['deckId']!,
                  deckTitle: state.extra as String?,
                ),
          ),
        ],
      ),
      // Kahoot screens push their own sub-screens (QR scanner, game) with Navigator.
      GoRoute(
        path: AppRoutes.kahoot,
        builder: (context, state) => const KahootEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.quiz,
        builder:
            (context, state) => QuizScreen(
              initialSubjectId: int.tryParse(
                state.uri.queryParameters['subjectId'] ?? '',
              ),
              initialDeckId: int.tryParse(
                state.uri.queryParameters['deckId'] ?? '',
              ),
            ),
        routes: [
          GoRoute(
            path: 'statistics',
            builder: (context, state) => const QuizStatisticsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.groups,
        builder: (context, state) => const GroupsScreen(),
      ),
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
      const signedOutOnly = {
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.checkEmail,
      };
      return signedOutOnly.contains(location) ? AppRoutes.home : null;
  }
}
