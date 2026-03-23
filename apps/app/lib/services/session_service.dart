import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 本地会话：Bearer token + 展示用用户名（与后端 /auth/me 一致时可再刷新）
class SessionService extends ChangeNotifier {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _kToken = 'auth_token';
  static const _kUsername = 'auth_username';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  String? _username;

  String? get token => _token;
  String? get username => _username;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> hydrate() async {
    _token = await _storage.read(key: _kToken);
    _username = await _storage.read(key: _kUsername);
    notifyListeners();
  }

  Future<void> setSession({required String token, String? username}) async {
    _token = token;
    if (username != null) {
      _username = username;
      await _storage.write(key: _kUsername, value: username);
    }
    await _storage.write(key: _kToken, value: token);
    notifyListeners();
  }

  Future<void> setUsername(String username) async {
    _username = username;
    await _storage.write(key: _kUsername, value: username);
    notifyListeners();
  }

  Future<void> clearSession() async {
    _token = null;
    _username = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUsername);
    notifyListeners();
  }
}
