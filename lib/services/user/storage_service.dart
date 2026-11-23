import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';

/// Signals that asynchronous work no longer belongs to the active account.
class SessionExpired implements Exception {}

/// Captures account credentials and the generation used to reject stale work.
class AccountSession {
  /// Account identifier used for backend requests and local cache namespaces.
  final String userId;

  /// Authorization key captured when this session was created.
  final String authKey;

  /// Account generation invalidated by logout or switching accounts.
  final int revision;

  /// Creates an account snapshot for session-bound asynchronous work.
  const AccountSession(this.userId, this.authKey, this.revision);

  /// Whether this snapshot still belongs to the current account generation.
  bool get isCurrent =>
      StorageService.revision == revision &&
      StorageService.currentSession?.userId == userId;

  /// Throws [SessionExpired] after logout or an account change.
  void check() {
    if (!isCurrent) {
      throw SessionExpired();
    }
  }

  /// Builds a preferences key scoped to this account.
  String key(String name) => 'account:$userId:$name';
}

/// Persists secure credentials and coordinates account-specific cache access.
///
/// Session generations and authentication attempts prevent delayed work from
/// restoring a signed-out account or writing into another account’s cache.
class StorageService {
  static const _storage = FlutterSecureStorage();

  /// Notifies account services when the active account generation changes.
  static final changes = ValueNotifier<int>(0);

  /// Current account credentials, or null while signed out.
  static AccountSession? currentSession;

  /// Generation shared by account snapshots and authentication guards.
  static int get revision => changes.value;
  static Future<void>? _initialization;
  static Future<void> _writes = Future.value();
  static int _authAttempt = 0;
  static final Object _sessionZone = Object();

  /// Restores secure credentials once and sanitizes previously cached profiles.
  static Future<void> initialize() => _initialization ??= _initialize();

  /// Restores credentials only if no newer session decision was made while loading.
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

  /// Rewrites cached profiles to the current schema, removing retired birthdate fields.
  /// Malformed cached profiles are discarded instead of being restored.
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

  /// Returns the session bound to this asynchronous task, rejecting stale ownership.
  static AccountSession requireSession() {
    final session =
        Zone.current[_sessionZone] as AccountSession? ?? currentSession;
    if (session == null) {
      throw SessionExpired();
    }
    session.check();
    return session;
  }

  /// Binds asynchronous work to one account so later checks retain its original owner.
  static Future<T> inSession<T>(
    Future<T> Function() action, {
    AccountSession? session,
  }) {
    session ??= requireSession();
    session.check();
    return runZoned(action, zoneValues: {_sessionZone: session});
  }

  /// Starts a login or registration attempt and supersedes older authentication attempts.
  static int beginAuthentication() => ++_authAttempt;

  /// Checks that an authentication response belongs to the latest attempt and account generation.
  static bool authenticationIsCurrent(int attempt, int version) =>
      attempt == _authAttempt && version == revision;

  /// Publishes current credentials and queues their secure persistence.
  /// Switching accounts advances the generation; rotating the same account’s key does not.
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

  /// Serializes secure-storage writes so later logout or login decisions take precedence.
  static Future<void> _enqueue(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.catchError((Object _) {});
    return result;
  }

  /// Restores initialization and returns credentials for the task’s current session.
  static Future<Map<String?, String?>> getUserSession() async {
    await initialize();
    final session =
        Zone.current[_sessionZone] as AccountSession? ?? currentSession;
    session?.check();
    return {'auth_key': session?.authKey, 'user_id': session?.userId};
  }

  /// Immediately invalidates pending work, then removes persisted login credentials.
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

  /// Caches a profile only under its owning account after checking session validity.
  static Future<void> saveUserProfile(AppUser user) async {
    final session = requireSession();
    if (user.id.toString() != session.userId) {
      throw SessionExpired();
    }
    final prefs = await SharedPreferences.getInstance();
    session.check();
    await prefs.setString(session.key('cached_user_info'), user.toJsonString());
  }

  /// Reads the active account’s cached profile without using another account’s data.
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

  /// Signs out and clears credentials while retaining account-specific disk caches.
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

/// Provides typed preferences access within a captured account namespace.
/// Every read or write rejects a session invalidated by logout or an account switch.
class AccountPreferences {
  final SharedPreferences _prefs;
  final AccountSession _session;

  /// Wraps preferences with the account snapshot captured when they were opened.
  AccountPreferences._(this._prefs, this._session);

  /// Opens preferences for the current task and rechecks ownership after loading.
  static Future<AccountPreferences> getInstance() async {
    final session = StorageService.requireSession();
    final prefs = await SharedPreferences.getInstance();
    session.check();
    return AccountPreferences._(prefs, session);
  }

  /// Validates account ownership before resolving a preferences key.
  String _key(String key) {
    _session.check();
    return _session.key(key);
  }

  /// Reads a string from this account’s preferences.
  String? getString(String key) => _prefs.getString(_key(key));

  /// Reads an integer from this account’s preferences.
  int? getInt(String key) => _prefs.getInt(_key(key));

  /// Reads a decimal value from this account’s preferences.
  double? getDouble(String key) => _prefs.getDouble(_key(key));

  /// Reads a boolean from this account’s preferences.
  bool? getBool(String key) => _prefs.getBool(_key(key));

  /// Persists a string while this account snapshot remains valid.
  Future<bool> setString(String key, String value) =>
      _prefs.setString(_key(key), value);

  /// Persists an integer while this account snapshot remains valid.
  Future<bool> setInt(String key, int value) => _prefs.setInt(_key(key), value);

  /// Persists a decimal value while this account snapshot remains valid.
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(_key(key), value);

  /// Persists a boolean while this account snapshot remains valid.
  Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(_key(key), value);

  /// Removes one preference belonging to this account.
  Future<bool> remove(String key) => _prefs.remove(_key(key));
}

/// Resets observable state on account changes and restores only the new account’s cache.
abstract class AccountService extends ChangeNotifier {
  /// Completes when the current account’s initial cache load finishes.
  Future<void> ready = Future.value();
  bool _disposed = false;

  /// Subscribes to account changes and starts the initial account load.
  void bindAccount() {
    StorageService.changes.addListener(_accountChanged);
    _accountChanged();
  }

  /// Clears previous state before loading data in the new account’s asynchronous context.
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

  /// Clears in-memory account data without deleting persisted caches.
  void resetAccount();

  /// Restores the current account’s state within its captured session.
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
