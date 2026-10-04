import 'package:flutter/foundation.dart';

import '../../data/api/api_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';

enum AuthStatus { unknown, signedIn, signedOut }

/// Who is signed in. The router listens to it: [AuthStatus.unknown] shows the splash screen,
/// [AuthStatus.signedOut] sends protected routes to login.
class AuthController extends ChangeNotifier {
  AuthController(this._auth, this._profile);

  final AuthRepository _auth;
  final ProfileRepository _profile;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  AppUser? _user;
  AppUser? get user => _user;

  /// Set when the session could not be checked (offline, server asleep). The splash screen offers a retry
  /// instead of silently signing the user out.
  ApiException? _startupError;
  ApiException? get startupError => _startupError;

  /// On app start: a stored token is only trusted after the backend accepts it, because the backend revokes
  /// tokens on password change or when the account is disabled.
  Future<void> restoreSession() async {
    _status = AuthStatus.unknown;
    _startupError = null;
    notifyListeners();

    if (!await _auth.hasToken()) {
      _setSignedOut();
      return;
    }

    try {
      _user = await _profile.getProfile();
      _status = AuthStatus.signedIn;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _setSignedOut();
      } else {
        _startupError = e;
        notifyListeners();
      }
    }
  }

  /// Throws [ApiException] for the login screen to show.
  Future<void> login(String email, String password) async {
    _user = await _auth.login(email, password);
    _status = AuthStatus.signedIn;
    _startupError = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _setSignedOut();
  }

  /// ApiClient saw a 401 with a token: it is already cleared.
  void handleUnauthorized() {
    if (_status == AuthStatus.signedIn) _setSignedOut();
  }

  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  void _setSignedOut() {
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
