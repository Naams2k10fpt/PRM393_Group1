import '../api/api_client.dart';
import '../api/token_storage.dart';
import '../models/app_user.dart';

/// /api/auth/*. Login stores the token; register does not log in (the email must be confirmed first).
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<AppUser> login(String email, String password) async {
    final body = await _api.post(
      '/api/auth/login',
      data: {'email': email.trim(), 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    await _tokens.write(body['accessToken'] as String);
    return AppUser.fromJson(body['user'] as Map<String, dynamic>);
  }

  /// Returns the backend's message ("check your inbox ...").
  Future<String> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final body = await _api.post(
      '/api/auth/register',
      data: {
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      },
      auth: false,
    ) as Map<String, dynamic>;
    return body['message'] as String;
  }

  Future<String> resendVerification(String email) => _message('/api/auth/resend-verification', email);

  Future<String> forgotPassword(String email) => _message('/api/auth/forgot-password', email);

  Future<bool> hasToken() async => (await _tokens.read())?.isNotEmpty == true;

  Future<void> logout() => _tokens.clear();

  Future<String> _message(String path, String email) async {
    final body = await _api.post(path, data: {'email': email.trim()}, auth: false) as Map<String, dynamic>;
    return body['message'] as String;
  }
}
