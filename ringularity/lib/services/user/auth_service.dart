import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_user.dart';

class AuthService {
  AppUser? currentUser;

  Future<void> saveUserLocally(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', user.toJsonString());
    currentUser = user;
  }

  Future<void> loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('cached_user');
    if (userJson != null) {
      currentUser = AppUser.fromJson(jsonDecode(userJson));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user');
    currentUser = null;
  }
}
