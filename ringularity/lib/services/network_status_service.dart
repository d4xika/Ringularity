import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ringularity/services/api/api_service.dart';

/// Centralized reactive service that tracks whether the backend API is reachable.
///
/// - [isOnline] is updated by [checkNow], by [setOnline], and by the periodic poll.
/// - Call [startPolling] when the app is foregrounded and [stopPolling] when backgrounded.
/// - [BleApiSync] reads [isOnline] before attempting any upload/download, and calls
///   [setOnline] / [checkNow] after each sync attempt to keep the state up to date.
class NetworkStatusService extends ChangeNotifier {
  final ApiService _apiService;

  /// Optimistic default — the splash screen corrects this before navigating.
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 30);

  NetworkStatusService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // ---------------------------------------------------------------------------
  // State management
  // ---------------------------------------------------------------------------

  /// Manually set the online state. Notifies listeners only when the value changes.
  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    debugPrint('NetworkStatusService: isOnline = $value');
    notifyListeners();
  }

  /// Immediately pings the backend, updates [isOnline], and returns the result.
  Future<bool> checkNow() async {
    final alive = await _apiService.checkIfAlive();
    setOnline(alive);
    return alive;
  }

  // ---------------------------------------------------------------------------
  // Background polling
  // ---------------------------------------------------------------------------

  /// Starts a periodic 30-second connectivity poll.
  /// Safe to call multiple times — cancels the previous timer first.
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => checkNow());
    debugPrint(
      'NetworkStatusService: polling started (${_pollInterval.inSeconds}s interval)',
    );
  }

  /// Stops the periodic poll (e.g. when the app is backgrounded).
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    debugPrint('NetworkStatusService: polling stopped');
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
