import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/api/api_exception.dart';
import 'package:quiz_management_mobile/data/models/app_user.dart';
import 'package:quiz_management_mobile/data/repositories/auth_repository.dart';
import 'package:quiz_management_mobile/data/repositories/profile_repository.dart';
import 'package:quiz_management_mobile/features/auth/auth_controller.dart';
import 'package:quiz_management_mobile/main.dart';

const demoUser = AppUser(id: 'u1', username: 'user_demo', email: 'user.demo@quiz.local', role: 'User');
const demoPassword = 'Test@123456';

const unauthorized = ApiException(code: 'unauthorized', message: 'Bạn cần đăng nhập.', statusCode: 401);
const offline = ApiException(code: ApiException.networkError, message: 'Không kết nối được máy chủ.');

/// In-memory stand-in for the backend's /api/auth endpoints.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.token});

  String? token;
  ApiException? loginError;
  ApiException? registerError;
  final calls = <String>[];

  @override
  Future<AppUser> login(String email, String password) async {
    calls.add('login:${email.trim()}');
    if (loginError != null) throw loginError!;
    if (email.trim() != demoUser.email || password != demoPassword) {
      throw const ApiException(
        code: 'invalid_credentials',
        message: 'Email hoặc mật khẩu không đúng.',
        statusCode: 401,
      );
    }
    token = 'token';
    return demoUser;
  }

  @override
  Future<String> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    calls.add('register:$username:$email');
    if (registerError != null) throw registerError!;
    return 'Đăng ký thành công. Vui lòng kiểm tra email để xác minh tài khoản.';
  }

  @override
  Future<String> resendVerification(String email) async {
    calls.add('resend:$email');
    return 'Nếu tài khoản tồn tại và chưa được xác minh, email mới đã được gửi.';
  }

  @override
  Future<String> forgotPassword(String email) async {
    calls.add('forgot:$email');
    return 'Nếu tài khoản hợp lệ, email đặt lại mật khẩu đã được gửi.';
  }

  @override
  Future<bool> hasToken() async => token != null;

  @override
  Future<void> logout() async => token = null;
}

/// In-memory stand-in for /api/profile.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([this.user = demoUser]);

  AppUser user;
  ApiException? getError;
  ApiException? updateError;
  ApiException? changePasswordError;
  final calls = <String>[];

  @override
  Future<AppUser> getProfile() async {
    if (getError != null) throw getError!;
    return user;
  }

  @override
  Future<AppUser> updateProfile({required String username, String? avatarUrl}) async {
    calls.add('update:$username:${avatarUrl ?? ''}');
    if (updateError != null) throw updateError!;
    return user = AppUser(
      id: user.id,
      username: username.trim(),
      email: user.email,
      role: user.role,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    calls.add('changePassword');
    if (changePasswordError != null) throw changePasswordError!;
  }
}

/// Boots the real app (router, providers, screens) on fake repositories.
class TestApp {
  TestApp({String? token, FakeProfileRepository? profile})
      : authRepository = FakeAuthRepository(token: token),
        profileRepository = profile ?? FakeProfileRepository() {
    auth = AuthController(authRepository, profileRepository);
  }

  final FakeAuthRepository authRepository;
  final FakeProfileRepository profileRepository;
  late final AuthController auth;

  Future<void> start(WidgetTester tester) async {
    // A phone-sized screen, so layout problems show up as they would on a device.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(QuizManagementApp(
      auth: auth,
      authRepository: authRepository,
      profileRepository: profileRepository,
    ));
    await auth.restoreSession();
    await tester.pumpAndSettle();
  }
}
