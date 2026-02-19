import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _userKey = 'cached_user_info';

  static Future<void> saveUserSession(String key, String userId) async {
    await _storage.write(key: 'auth_key', value: key);
    await _storage.write(key: 'user_id', value: userId);
  }

  static Future<Map<String?, String?>> getUserSession() async {
    final auth_key = await _storage.read(key: 'auth_key');
    final user_id = await _storage.read(key: 'user_id');

    return {'auth_key': auth_key, 'user_id': user_id};
  }

  static Future<void> deleteUserSession() async {
    await _storage.delete(key: 'auth_key');
    await _storage.delete(key: 'user_id');
  }

  static Future<void> saveUserProfile(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.toJsonString());
  }

  static Future<AppUser?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    return AppUser.fromJson(jsonDecode(userJson));
  }

  static Future<void> deleteAll() async {
    await _storage.delete(key: 'auth_key');
    await _storage.delete(key: 'user_id');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
