import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';

class SessionExpired implements Exception {}

class AccountSession {
  final String userId;
  final String authKey;
  final int revision;

  const AccountSession(this.userId, this.authKey, this.revision);

  bool get isCurrent =>
      StorageService.revision == revision &&
      StorageService.currentSession?.userId == userId;

  void check() {
    if (!isCurrent) {
      throw SessionExpired();
    }
  }

  String key(String name) => 'account:$userId:$name';
}

class StorageService {
  static const _storage = FlutterSecureStorage();
  static final changes = ValueNotifier<int>(0);
  static AccountSession? currentSession;
  static int get revision => changes.value;
  static Future<void>? _initialization;
  static Future<void> _writes = Future.value();
  static int _authAttempt = 0;
  static final Object _sessionZone = Object();

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    final version = revision;
    await sanitizeUserProfiles();
    if (currentSession != null || version != revision) {
      return;
    }
    final key = await _storage.read(key: 'auth_key');
    final id = await _storage.read(key: 'user_id');
    if (version == revision &&
        currentSession == null &&
        key != null &&
        id != null) {
      currentSession = AccountSession(id, key, version + 1);
      changes.value = version + 1;
    }
  }

  static Future<void> sanitizeUserProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              key == 'cached_user_info' ||
              key == 'cached_user' ||
              key.endsWith(':cached_user_info'),
        )
        .toList();
    for (final key in keys) {
      final AppUser profile;
      try {
        profile = AppUser.fromJson(jsonDecode(prefs.getString(key)!));
      } catch (_) {
        await prefs.remove(key);
        continue;
      }
      await prefs.setString(key, profile.toJsonString());
    }
  }

  static AccountSession requireSession() {
    final session =
        Zone.current[_sessionZone] as AccountSession? ?? currentSession;
    if (session == null) {
      throw SessionExpired();
    }
    session.check();
    return session;
  }

  static Future<T> inSession<T>(
    Future<T> Function() action, {
    AccountSession? session,
  }) {
    session ??= requireSession();
    session.check();
    return runZoned(action, zoneValues: {_sessionZone: session});
  }

  static int beginAuthentication() => ++_authAttempt;

  static bool authenticationIsCurrent(int attempt, int version) =>
      attempt == _authAttempt && version == revision;

  static Future<void> saveUserSession(String key, String userId) {
    _initialization = Future.value();
    final changed = currentSession?.userId != userId;
    final version = revision + (changed ? 1 : 0);
    currentSession = AccountSession(userId, key, version);
    if (changed) {
      changes.value = version;
    }
    final session = currentSession!;
    return _enqueue(() async {
      if (!session.isCurrent) {
        return;
      }
      await _storage.write(key: 'auth_key', value: key);
      await _storage.write(key: 'user_id', value: userId);
    });
  }

  static Future<void> _enqueue(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.catchError((Object _) {});
    return result;
  }

  static Future<Map<String?, String?>> getUserSession() async {
    await initialize();
    final session =
        Zone.current[_sessionZone] as AccountSession? ?? currentSession;
    session?.check();
    return {'auth_key': session?.authKey, 'user_id': session?.userId};
  }

  static Future<void> deleteUserSession() {
    _initialization = Future.value();
    _authAttempt++;
    currentSession = null;
    changes.value++;
    return _enqueue(() async {
      await _storage.delete(key: 'auth_key');
      await _storage.delete(key: 'user_id');
    });
  }

  static Future<void> saveUserProfile(AppUser user) async {
    final session = requireSession();
    if (user.id.toString() != session.userId) {
      throw SessionExpired();
    }
    final prefs = await SharedPreferences.getInstance();
    session.check();
    await prefs.setString(session.key('cached_user_info'), user.toJsonString());
  }

  static Future<AppUser?> getUserProfile() async {
    await initialize();
    final session =
        Zone.current[_sessionZone] as AccountSession? ?? currentSession;
    if (session == null || !session.isCurrent) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!session.isCurrent) {
      return null;
    }
    final json = prefs.getString(session.key('cached_user_info'));
    return json == null ? null : AppUser.fromJson(jsonDecode(json));
  }

  static Future<void> deleteAll() => deleteUserSession();

  /// Invalidates pending work and removes the deleted account's caches and credentials.
  /// Preferences belonging to other accounts and device-wide settings are preserved.
  static Future<void> deleteAccountData(AccountSession owner) async {
    owner.check();
    final signedOut = deleteUserSession();
    await signedOut;
    final prefs = await SharedPreferences.getInstance();
    final prefix = owner.key('');
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      if (!await prefs.remove(key)) {
        throw StateError('Unable to remove local account data');
      }
    }
  }
}

class AccountPreferences {
  final SharedPreferences _prefs;
  final AccountSession _session;

  AccountPreferences._(this._prefs, this._session);

  static Future<AccountPreferences> getInstance() async {
    final session = StorageService.requireSession();
    final prefs = await SharedPreferences.getInstance();
    session.check();
    return AccountPreferences._(prefs, session);
  }

  String _key(String key) {
    _session.check();
    return _session.key(key);
  }

  String? getString(String key) => _prefs.getString(_key(key));
  int? getInt(String key) => _prefs.getInt(_key(key));
  double? getDouble(String key) => _prefs.getDouble(_key(key));
  bool? getBool(String key) => _prefs.getBool(_key(key));
  Future<bool> setString(String key, String value) =>
      _prefs.setString(_key(key), value);
  Future<bool> setInt(String key, int value) => _prefs.setInt(_key(key), value);
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(_key(key), value);
  Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(_key(key), value);
  Future<bool> remove(String key) => _prefs.remove(_key(key));
}

abstract class AccountService extends ChangeNotifier {
  Future<void> ready = Future.value();
  bool _disposed = false;

  void bindAccount() {
    StorageService.changes.addListener(_accountChanged);
    _accountChanged();
  }

  void _accountChanged() {
    resetAccount();
    ready = StorageService.currentSession == null
        ? Future.value()
        : runZoned(
            loadAccount,
            zoneValues: {
              StorageService._sessionZone: StorageService.currentSession,
            },
          ).catchError((Object error) {
            if (error is! SessionExpired) {
              debugPrint('Unable to load account cache: $error');
            }
          });
    notifyListeners();
  }

  void resetAccount();
  Future<void> loadAccount();

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    StorageService.changes.removeListener(_accountChanged);
    super.dispose();
  }
}
