import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/config/app_updates.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/academic_ambient_background.dart';
import 'data/api/api_client.dart';
import 'data/api/token_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/flashcard_repository.dart';
import 'data/repositories/groups_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/quiz_repository.dart';
import 'features/auth/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokens = SecureTokenStorage();
  final api = ApiClient(tokens: tokens);
  final authRepository = AuthRepository(api, tokens);
  final profileRepository = ProfileRepository(api, tokens);
  final catalogRepository = CatalogRepository(api);
  final flashcardRepository = FlashcardRepository(api);
  final auth = AuthController(authRepository, profileRepository);
  api.onUnauthorized = auth.handleUnauthorized;

  runApp(
    QuizManagementApp(
      auth: auth,
      authRepository: authRepository,
      profileRepository: profileRepository,
      catalogRepository: catalogRepository,
      flashcardRepository: flashcardRepository,
      quizRepository: QuizRepository(api),
      groupsRepository: GroupsRepository(api),
      updates: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AppUpdates()
          : null,
    ),
  );
  auth.restoreSession();
}

/// Provides the repositories and [AuthController] to every screen. Tests pass fakes here.
class QuizManagementApp extends StatefulWidget {
  const QuizManagementApp({
    super.key,
    required this.auth,
    required this.authRepository,
    required this.profileRepository,
    required this.catalogRepository,
    required this.flashcardRepository,
    required this.quizRepository,
    required this.groupsRepository,
    this.updates,
  });

  final AuthController auth;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final CatalogRepository catalogRepository;
  final FlashcardRepository flashcardRepository;
  final QuizRepository quizRepository;
  final GroupsRepository groupsRepository;
  final AppUpdates? updates;

  @override
  State<QuizManagementApp> createState() => _QuizManagementAppState();
}

class _QuizManagementAppState extends State<QuizManagementApp> {
  late final GoRouter _router = createRouter(widget.auth);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: widget.authRepository),
        Provider<ProfileRepository>.value(value: widget.profileRepository),
        Provider<CatalogRepository>.value(value: widget.catalogRepository),
        Provider<FlashcardRepository>.value(value: widget.flashcardRepository),
        Provider<QuizRepository>.value(value: widget.quizRepository),
        Provider<GroupsRepository>.value(value: widget.groupsRepository),
        Provider<AppUpdates?>.value(value: widget.updates),
        ChangeNotifierProvider<AuthController>.value(value: widget.auth),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeModeNotifier,
        builder: (context, themeMode, _) {
          return MaterialApp.router(
            title: 'Quiz Management',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            routerConfig: _router,
            builder: (context, child) {
              return Stack(
                children: [
                  const Positioned.fill(
                    child: AcademicAmbientBackground(
                      animate: false,
                      showRunes: false,
                    ),
                  ),
                  if (child != null) child,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
