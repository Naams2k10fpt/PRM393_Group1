import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/kahoot/kahoot_entry_screen.dart';

/// Route paths. Use these constants with context.go / context.push instead of string literals.
class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const kahoot = '/kahoot';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
      // Kahoot screens push their own sub-screens (QR scanner, game) with Navigator.
      GoRoute(path: AppRoutes.kahoot, builder: (context, state) => const KahootEntryScreen()),
    ],
  );
}
