import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/api/api_exception.dart';
import 'package:quiz_management_mobile/features/auth/login_screen.dart';
import 'package:quiz_management_mobile/features/profile/change_password_screen.dart';
import 'package:quiz_management_mobile/features/profile/edit_profile_screen.dart';
import 'package:quiz_management_mobile/features/profile/profile_screen.dart';

import '../support/fakes.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<TestApp> openProfile(WidgetTester tester) async {
  final app = TestApp(token: 'stored');
  await app.start(tester);
  await tester.tap(find.byTooltip('Hồ sơ'));
  await tester.pumpAndSettle();
  expect(find.byType(ProfileScreen), findsOneWidget);
  return app;
}

const fieldError = ApiException(
  code: 'validation_failed',
  message: 'Dữ liệu không hợp lệ.',
  statusCode: 400,
  fieldErrors: {
    'username': ['Tên người dùng đã được sử dụng.'],
    'currentPassword': ['Mật khẩu hiện tại không đúng.'],
  },
);

void main() {
  testWidgets('profile shows the signed-in user', (tester) async {
    await openProfile(tester);

    expect(find.text(demoUser.username), findsOneWidget);
    expect(find.text(demoUser.email), findsOneWidget);
    expect(find.text('Học viên'), findsOneWidget);
  });

  testWidgets('edit profile saves and the new name shows everywhere', (tester) async {
    final app = await openProfile(tester);
    await tester.tap(find.text('Sửa hồ sơ'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Tên người dùng'), 'renamed');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(app.profileRepository.calls.single, 'update:renamed:');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('renamed'), findsOneWidget);
    expect(app.auth.user!.username, 'renamed');
  });

  testWidgets('edit profile: bad avatar URL is caught on the device, taken name comes from the backend',
      (tester) async {
    final app = await openProfile(tester);
    await tester.tap(find.text('Sửa hồ sơ'));
    await tester.pumpAndSettle();

    await tester.enterText(field('URL ảnh đại diện (không bắt buộc)'), 'not a url');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('URL avatar không hợp lệ.'), findsOneWidget);
    expect(app.profileRepository.calls, isEmpty);

    app.profileRepository.updateError = fieldError;
    await tester.enterText(field('URL ảnh đại diện (không bắt buộc)'), '');
    await tester.enterText(field('Tên người dùng'), 'admin_demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Tên người dùng đã được sử dụng.'), findsOneWidget);
  });

  group('change password', () {
    Future<TestApp> open(WidgetTester tester) async {
      final app = await openProfile(tester);
      await tester.tap(find.text('Đổi mật khẩu'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      return app;
    }

    Future<void> fill(WidgetTester tester, {String confirm = 'a new long passphrase'}) async {
      await tester.enterText(field('Mật khẩu hiện tại'), demoPassword);
      await tester.enterText(field('Mật khẩu mới (8–100 ký tự)'), 'a new long passphrase');
      await tester.enterText(field('Xác nhận mật khẩu mới'), confirm);
      await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
      await tester.pumpAndSettle();
    }

    testWidgets('mismatched confirmation is caught on the device', (tester) async {
      final app = await open(tester);

      await fill(tester, confirm: 'different');

      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      expect(app.profileRepository.calls, isEmpty);
    });

    testWidgets('wrong current password shows under that field', (tester) async {
      final app = await open(tester);
      app.profileRepository.changePasswordError = fieldError;

      await fill(tester);

      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('success returns to the profile and stays signed in', (tester) async {
      final app = await open(tester);

      await fill(tester);

      expect(app.profileRepository.calls.single, 'changePassword');
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.textContaining('Đổi mật khẩu thành công'), findsOneWidget);
    });
  });

  testWidgets('logout from the profile returns to login', (tester) async {
    await openProfile(tester);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
