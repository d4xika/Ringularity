import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';

/// A centralized persistence wrapper managing both secure credentials and general app state.
///
/// Uses `flutter_secure_storage` to encrypt sensitive session keys (Auth Token),
/// and standard `SharedPreferences` for less critical UI state like the user's name.
class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _userKey = 'cached_user_info';

  /// Securely encrypts and saves the backend authorization token to the device keychain/keystore.
  static Future<void> saveUserSession(String key, String userId) async {
    await _storage.write(key: 'auth_key', value: key);
    await _storage.write(key: 'user_id', value: userId);
  }

  /// Decrypts and retrieves the active authorization token.
  static Future<Map<String?, String?>> getUserSession() async {
    final authKey = await _storage.read(key: 'auth_key');
    final userId = await _storage.read(key: 'user_id');

    return {'auth_key': authKey, 'user_id': userId};
  }

  /// Safely destroys the authorization token from the keychain.
  static Future<void> deleteUserSession() async {
    await _storage.delete(key: 'auth_key');
    await _storage.delete(key: 'user_id');
  }

  /// Caches the user's non-sensitive profile (Name, Email) to render the UI before network calls finish.
  static Future<void> saveUserProfile(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.toJsonString());
  }

  /// Retrieves the cached profile. Returns null if the user is completely logged out.
  static Future<AppUser?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    return AppUser.fromJson(jsonDecode(userJson));
  }

  /// Called upon user logout to wipe absolutely all local traces of the session and profile.
  static Future<void> deleteAll() async {
    await _storage.delete(key: 'auth_key');
    await _storage.delete(key: 'user_id');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
