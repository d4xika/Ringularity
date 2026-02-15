import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

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
}
