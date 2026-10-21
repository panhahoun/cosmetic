import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the session. The access token lives in [FlutterSecureStorage]
/// (Keychain / EncryptedSharedPreferences); non-secret profile fields stay in
/// SharedPreferences because widgets read them synchronously.
class SessionStore {
  SessionStore({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  static const _tokenKey = 'access_token';
  static const _idKey = 'id';
  static const _nameKey = 'name';
  static const _emailKey = 'email';
  static const _roleKey = 'role';

  final FlutterSecureStorage _secure;

  String? _cachedToken;
  bool _tokenLoaded = false;

  Future<String?> readToken() async {
    if (_tokenLoaded) return _cachedToken;
    try {
      _cachedToken = await _secure.read(key: _tokenKey);
    } catch (_) {
      // A corrupt keystore entry should log the user out, not crash startup.
      _cachedToken = null;
    }
    _tokenLoaded = true;
    return _cachedToken;
  }

  /// Synchronous accessor for the Dio interceptor, which cannot await.
  /// Returns null until [prime] has completed.
  String? get cachedToken => _tokenLoaded ? _cachedToken : null;

  Future<void> prime() async {
    await readToken();
  }

  Future<void> saveSession({
    required String token,
    required int id,
    required String name,
    required String email,
    String role = 'user',
  }) async {
    _cachedToken = token;
    _tokenLoaded = true;
    await _secure.write(key: _tokenKey, value: token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_idKey, id);
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_roleKey, role);
  }

  Future<void> clear() async {
    _cachedToken = null;
    _tokenLoaded = true;
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {
      // In-memory token is already cleared; the next login overwrites it.
    }
    // Separate guard: a prefs failure must not undo the token clear.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_idKey);
      await prefs.remove(_nameKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_roleKey);
    } catch (_) {
      // Display fields only.
    }
  }

  Future<int?> currentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_idKey);
    } catch (_) {
      return null;
    }
  }
}

final sessionStore = SessionStore();
