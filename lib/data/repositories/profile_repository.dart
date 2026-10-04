import '../api/api_client.dart';
import '../api/token_storage.dart';
import '../models/app_user.dart';

/// /api/profile. Changing the password revokes every token, so the returned one is stored immediately.
class ProfileRepository {
  ProfileRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<AppUser> getProfile() async =>
      AppUser.fromJson(await _api.get('/api/profile') as Map<String, dynamic>);

  Future<AppUser> updateProfile({required String username, String? avatarUrl}) async {
    final body = await _api.put('/api/profile', data: {
      'username': username.trim(),
      'avatarUrl': (avatarUrl == null || avatarUrl.trim().isEmpty) ? null : avatarUrl.trim(),
    });
    return AppUser.fromJson(body as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final body = await _api.post('/api/profile/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    }) as Map<String, dynamic>;
    await _tokens.write(body['accessToken'] as String);
  }
}
