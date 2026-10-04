import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/api/api_exception.dart';
import 'package:quiz_management_mobile/features/auth/register_screen.dart';
import 'package:quiz_management_mobile/features/home/home_screen.dart';
import 'package:quiz_management_mobile/features/kahoot/kahoot_entry_screen.dart';

import '../support/fakes.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);
Finder button(String text) => find.widgetWithText(FilledButton, text);

Future<void> login(WidgetTester tester, String email, String password) async {
  await tester.enterText(field('Email'), email);
  await tester.enterText(field('Mật khẩu'), password);
  await tester.tap(button('Đăng nhập'));
  await tester.pumpAndSettle();
}

void main() {
  group('Login', () {
    testWidgets('empty form is rejected on the device, without calling the API', (tester) async {
      final app = TestApp();
      await app.start(tester);

      await tester.tap(button('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Email là bắt buộc.'), findsOneWidget);
      expect(find.text('Mật khẩu là bắt buộc.'), findsOneWidget);
      expect(app.authRepository.calls, isEmpty);
    });

    testWidgets('wrong password shows the backend message', (tester) async {
      await TestApp().start(tester);

      await login(tester, demoUser.email, 'wrong password');

      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
    });

    testWidgets('correct credentials (with stray spaces) sign in', (tester) async {
      await TestApp().start(tester);

      await login(tester, '  ${demoUser.email} ', demoPassword);

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('unconfirmed email offers to resend the verification email', (tester) async {
      final app = TestApp();
      app.authRepository.loginError = const ApiException(
        code: 'email_not_confirmed',
        message: 'Email chưa được xác minh.',
        statusCode: 403,
      );
      await app.start(tester);

      await login(tester, demoUser.email, demoPassword);
      expect(find.text('Email chưa được xác minh.'), findsOneWidget);

      await tester.tap(find.text('Gửi lại email xác minh'));
      await tester.pumpAndSettle();

      expect(app.authRepository.calls.last, 'resend:${demoUser.email}');
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('lockout message is shown as is', (tester) async {
      final app = TestApp();
      app.authRepository.loginError = const ApiException(
        code: 'locked_out',
        message: 'Tài khoản tạm thời bị khóa. Thử lại sau 2 phút.',
        statusCode: 429,
        retryAfterSeconds: 90,
      );
      await app.start(tester);

      await login(tester, demoUser.email, demoPassword);

      expect(find.text('Tài khoản tạm thời bị khóa. Thử lại sau 2 phút.'), findsOneWidget);
    });

    testWidgets('forgot password sends the email typed in the dialog', (tester) async {
      final app = TestApp();
      await app.start(tester);
      await tester.enterText(field('Email'), demoUser.email);

      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();
      expect(find.text('Quên mật khẩu'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Gửi'));
      await tester.pumpAndSettle();

      expect(app.authRepository.calls.last, 'forgot:${demoUser.email}');
      expect(find.text('Nếu tài khoản hợp lệ, email đặt lại mật khẩu đã được gửi.'), findsOneWidget);
    });

    testWidgets('password visibility toggles', (tester) async {
      await TestApp().start(tester);
      EditableText passwordText() =>
          tester.widget<EditableText>(find.descendant(of: field('Mật khẩu'), matching: find.byType(EditableText)));

      expect(passwordText().obscureText, isTrue);
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pump();
      expect(passwordText().obscureText, isFalse);
    });

    testWidgets('guests can open Kahoot without an account', (tester) async {
      await TestApp().start(tester);

      await tester.tap(find.text('Vào phòng Kahoot (không cần tài khoản)'));
      await tester.pumpAndSettle();

      expect(find.byType(KahootEntryScreen), findsOneWidget);
    });
  });

  group('Register', () {
    Future<TestApp> openRegister(WidgetTester tester) async {
      final app = TestApp();
      await app.start(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      return app;
    }

    Future<void> fill(WidgetTester tester, {String confirm = 'a long passphrase'}) async {
      await tester.enterText(field('Tên người dùng'), 'newbie');
      await tester.enterText(field('Email'), 'newbie@example.com');
      await tester.enterText(field('Mật khẩu (8–100 ký tự)'), 'a long passphrase');
      await tester.enterText(field('Xác nhận mật khẩu'), confirm);
      await tester.tap(button('Đăng ký'));
      await tester.pumpAndSettle();
    }

    testWidgets('mismatched confirmation is caught before calling the API', (tester) async {
      final app = await openRegister(tester);

      await fill(tester, confirm: 'something else');

      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      expect(app.authRepository.calls, isEmpty);
    });

    testWidgets('success leads to "check your inbox" with a resend button, not to home', (tester) async {
      final app = await openRegister(tester);

      await fill(tester);

      expect(app.authRepository.calls.single, 'register:newbie:newbie@example.com');
      expect(find.byType(CheckEmailScreen), findsOneWidget);
      expect(find.textContaining('newbie@example.com'), findsOneWidget);

      await tester.tap(find.text('Gửi lại email xác minh'));
      await tester.pumpAndSettle();
      expect(app.authRepository.calls.last, 'resend:newbie@example.com');
    });

    testWidgets('backend field errors appear under their field', (tester) async {
      final app = await openRegister(tester);
      app.authRepository.registerError = const ApiException(
        code: 'validation_failed',
        message: 'Dữ liệu không hợp lệ.',
        statusCode: 400,
        fieldErrors: {
          'email': ['Email không hợp lệ.'],
        },
      );

      await fill(tester);

      expect(find.descendant(of: field('Email'), matching: find.text('Email không hợp lệ.')), findsOneWidget);
    });

    testWidgets('taken email or username shows the generic conflict message', (tester) async {
      final app = await openRegister(tester);
      app.authRepository.registerError = const ApiException(
        code: 'registration_conflict',
        message: 'Không thể đăng ký với thông tin này.',
        statusCode: 409,
      );

      await fill(tester);

      expect(find.text('Không thể đăng ký với thông tin này.'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });
}
