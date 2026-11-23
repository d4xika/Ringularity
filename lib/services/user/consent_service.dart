import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

/// Signals missing consent or invalidation of a previously granted request lease.
class ConsentRequired implements Exception {}

/// Captures the consent revision that authorized an asynchronous operation.
///
/// Account changes, acceptance and withdrawal invalidate older leases so delayed
/// responses cannot be reused under a different consent decision.
class ConsentLease {
  /// Consent revision observed when the operation was authorized.
  final int revision;

  /// Creates a lease for one specific consent revision.
  const ConsentLease(this.revision);

  /// Whether consent remains granted for the exact revision captured by this lease.
  bool get isCurrent =>
      ConsentService.instance.hasConsent &&
      ConsentService.instance.revision == revision;

  /// Throws [ConsentRequired] if consent was withdrawn or the revision changed.
  void check() {
    if (!isCurrent) {
      throw ConsentRequired();
    }
  }
}

/// Controls backend access and persists versioned consent separately for each account.
///
/// An anonymous onboarding decision is held in memory and assigned to the account
/// after authentication. Logout clears the active decision, while other accounts
/// can only restore their own receipt for the current [textVersion].
class ConsentService extends ChangeNotifier {
  /// Shared consent state used by onboarding, settings and the backend transport.
  static final instance = ConsentService._();

  /// Version of the displayed consent text; bump it when renewed acceptance is required.
  static const textVersion = '2026-11-23.1';
  static const _storageKey = 'backend_consent';

  /// Creates the shared consent controller before local receipt initialization.
  ConsentService._();

  SharedPreferences? _prefs;
  String? _accountId;
  DateTime? _acceptedAt;
  int _revision = 0;
  bool _listening = false;

  /// Serializes persistence so a later withdrawal cannot be overwritten by an earlier save.
  Future<void> _writes = Future.value();

  /// Whether the active account or anonymous onboarding session has consented.
  bool get hasConsent => _acceptedAt != null;

  /// UTC acceptance time, or null when backend access is not permitted.
  DateTime? get acceptedAt => _acceptedAt;

  /// Generation used to invalidate pending requests when the active decision changes.
  int get revision => _revision;

  /// Restores the current account receipt and subscribes to subsequent session changes.
  Future<void> initialize() async {
    await _writes;
    _prefs = await SharedPreferences.getInstance();
    if (!_listening) {
      StorageService.changes.addListener(_accountChanged);
      _listening = true;
    }
    _accountId = StorageService.currentSession?.userId;
    _acceptedAt = _readRecord(_accountId);
    _revision++;
    notifyListeners();
  }

  /// Builds the account-specific preferences key used for a consent receipt.
  String _key(String accountId) => 'account:$accountId:$_storageKey';

  /// Reads a current-version receipt, treating absent, outdated or malformed data as denial.
  DateTime? _readRecord(String? accountId) {
    if (accountId == null) {
      return null;
    }
    final encoded = _prefs?.getString(_key(accountId));
    if (encoded == null) {
      return null;
    }
    try {
      final record = jsonDecode(encoded) as Map<String, dynamic>;
      if (record['version'] != textVersion) {
        return null;
      }
      return DateTime.tryParse(record['accepted_at'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Transfers fresh onboarding consent after login or restores the next account's receipt.
  /// Logout removes the active decision without deleting another account's saved receipt.
  void _accountChanged() {
    final nextId = StorageService.currentSession?.userId;
    final onboardingConsent = _accountId == null ? _acceptedAt : null;
    _accountId = nextId;
    _acceptedAt = nextId == null
        ? null
        : onboardingConsent ?? _readRecord(nextId);
    _revision++;
    if (nextId != null && onboardingConsent != null) {
      _saveRecord(nextId, onboardingConsent).catchError((Object error) {
        debugPrint('Unable to persist account consent: $error');
      });
    }
    notifyListeners();
  }

  /// Queues a persistence operation and preserves the queue after individual failures.
  Future<void> _enqueue(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.catchError((Object _) {});
    return result;
  }

  /// Stores the text version and UTC acceptance time for the specified account.
  Future<void> _saveRecord(String accountId, DateTime acceptedAt) {
    final prefs = _prefs!;
    return _enqueue(() async {
      final saved = await prefs.setString(
        _key(accountId),
        jsonEncode({
          'version': textVersion,
          'accepted_at': acceptedAt.toUtc().toIso8601String(),
        }),
      );
      if (!saved) {
        throw StateError('Unable to save consent');
      }
    });
  }

  /// Grants explicit consent after saving its receipt when an account is active.
  /// A concurrent account change or withdrawal prevents the pending save from granting access.
  Future<void> accept() async {
    final version = _revision;
    final acceptedAt = DateTime.now().toUtc();
    final accountId = _accountId;
    if (accountId != null) {
      await _saveRecord(accountId, acceptedAt);
    }
    if (version != _revision) {
      throw ConsentRequired();
    }
    _acceptedAt = acceptedAt;
    _revision++;
    notifyListeners();
  }

  /// Immediately denies backend access, then removes the active account's receipt.
  /// Existing local caches, credentials and backend records are not deleted by withdrawal.
  Future<void> revoke() async {
    final accountId = _accountId;
    final prefs = _prefs!;
    _acceptedAt = null;
    _revision++;
    notifyListeners();
    if (accountId != null) {
      await _enqueue(() async {
        if (!await prefs.remove(_key(accountId))) {
          throw StateError('Unable to remove consent');
        }
      });
    }
  }

  /// Returns a lease for the active decision, or throws [ConsentRequired] before a request starts.
  ConsentLease requireConsent() {
    if (!hasConsent) {
      throw ConsentRequired();
    }
    return ConsentLease(_revision);
  }
}
