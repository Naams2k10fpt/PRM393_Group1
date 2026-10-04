import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/core/router/app_router.dart';
import 'package:quiz_management_mobile/features/auth/auth_controller.dart';
import 'package:quiz_management_mobile/features/auth/login_screen.dart';
import 'package:quiz_management_mobile/features/auth/splash_screen.dart';
import 'package:quiz_management_mobile/features/home/home_screen.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('no stored token → login screen', (tester) async {
    await TestApp().start(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('stored token the backend accepts → home (auto-login)', (tester) async {
    final app = TestApp(token: 'stored');
    await app.start(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.auth.user?.email, demoUser.email);
  });

  testWidgets('stored token the backend revoked → login', (tester) async {
    final app = TestApp(token: 'revoked', profile: FakeProfileRepository()..getError = unauthorized);
    await app.start(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('server unreachable at start → splash offers a retry instead of signing out', (tester) async {
    final profile = FakeProfileRepository()..getError = offline;
    final app = TestApp(token: 'stored', profile: profile);
    await app.start(tester);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text(offline.message), findsOneWidget);

    profile.getError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('login → home; logout → login', (tester) async {
    final app = TestApp();
    await app.start(tester);

    await tester.enterText(find.byType(TextField).at(0), demoUser.email);
    await tester.enterText(find.byType(TextField).at(1), demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(app.authRepository.token, isNull);
  });

  testWidgets('a 401 during use (token revoked elsewhere) sends the user to login', (tester) async {
    final app = TestApp(token: 'stored');
    await app.start(tester);

    app.auth.handleUnauthorized();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  test('route guard', () {
    expect(redirectFor(AuthStatus.unknown, AppRoutes.home), AppRoutes.splash);
    expect(redirectFor(AuthStatus.signedOut, AppRoutes.home), AppRoutes.login);
    expect(redirectFor(AuthStatus.signedOut, AppRoutes.kahoot), isNull);
    expect(redirectFor(AuthStatus.signedIn, AppRoutes.login), AppRoutes.home);
    expect(redirectFor(AuthStatus.signedIn, AppRoutes.kahoot), isNull);
  });
}
