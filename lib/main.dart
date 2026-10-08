import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'data/api/token_storage.dart';
import 'data/repositories/auth_repository.dart';
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
  final auth = AuthController(authRepository, profileRepository);
  api.onUnauthorized = auth.handleUnauthorized;

  runApp(
    QuizManagementApp(
      auth: auth,
      authRepository: authRepository,
      profileRepository: profileRepository,
      api: api,
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
    required this.api,
  });

  final AuthController auth;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ApiClient api;

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
        Provider<QuizRepository>(create: (_) => QuizRepository(widget.api)),
        Provider<GroupsRepository>(create: (_) => GroupsRepository(widget.api)),
        ChangeNotifierProvider<AuthController>.value(value: widget.auth),
      ],
      child: MaterialApp.router(
        title: 'Quiz Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        routerConfig: _router,
      ),
    );
  }
}
