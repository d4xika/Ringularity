import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ringularity/services/api/api_service.dart';

/// Centralized reactive service that tracks whether the backend API is reachable.
///
/// Operates a background polling mechanism to proactively detect when the device
/// drops into or recovers from an offline state. This allows the UI to degrade gracefully
/// (e.g., disabling Cloud Sync buttons) without throwing exceptions.
class NetworkStatusService extends ChangeNotifier {
  final ApiService _apiService;

  /// Optimistic default — the splash screen corrects this immediately before navigating to the home screen.
  bool _isOnline = true;

  /// True if the last API ping was successful.
  bool get isOnline => _isOnline;

  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 30);

  /// Creates a new [NetworkStatusService], optionally injecting an [ApiService] for testing.
  NetworkStatusService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  /// Manually set the online state. Notifies UI listeners only when the state flips.
  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    debugPrint('NetworkStatusService: isOnline = $value');
    notifyListeners();
  }

  /// Forces an immediate asynchronous ping to the backend, updating the global state.
  Future<bool> checkNow() async {
    final alive = await _apiService.checkIfAlive();
    setOnline(alive);
    return alive;
  }

  /// Starts a recurring timer (every 30s) to ping the backend.
  /// Safe to call multiple times as it cancels existing timers first.
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => checkNow());
    debugPrint(
      'NetworkStatusService: polling started (${_pollInterval.inSeconds}s interval)',
    );
  }

  /// Halts the recurring ping. Should be called when the app enters the background to save battery.
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
