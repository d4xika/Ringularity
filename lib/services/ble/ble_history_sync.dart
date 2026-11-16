import 'dart:async';

import 'ble_data_processor.dart';

/// Serializes ring history requests and waits for verified protocol completion.
///
/// Missing packets, rejected writes and disconnects fail the request. One retry
/// repeats the same date before the queue advances to another measurement.
class BleHistorySync {
  /// Parser reporting completion and integrity failures for the active transfer.
  final BleDataProcessor processor;

  /// Maximum duration of one transfer attempt, including all expected packets.
  final Duration timeout;

  /// Clock used to resolve day offsets when a queued request actually starts.
  final DateTime Function() now;
  Future<void> _queue = Future.value();
  Completer<void>? _response;
  int _generation = 0;

  /// Creates a request queue with an injectable clock and transfer deadline.
  BleHistorySync({
    required this.processor,
    this.timeout = const Duration(seconds: 20),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    processor.onHistoryComplete = (_) {
      if (_response != null && !_response!.isCompleted) {
        _response!.complete();
      }
    };
    processor.onHistoryError = cancel;
  }

  /// Queues a dated request, with [send] selecting the appropriate BLE channel.
  Future<void> request({
    required int command,
    required DateTime date,
    required Future<void> Function(int attempt, DateTime reference) send,
  }) {
    final generation = _generation;
    final result = _queue.then((_) async {
      if (generation != _generation) {
        throw StateError('History request cancelled');
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        final response = Completer<void>();
        _response = response;
        final reference = now();
        processor.beginHistoryRequest(command, date, reference);
        final completed = response.future.timeout(timeout);
        try {
          await Future.wait([
            completed,
            Future.sync(() => send(attempt, reference)),
          ], eagerError: true);
          return;
        } catch (_) {
          if (generation != _generation || attempt == 1) {
            rethrow;
          }
        } finally {
          if (!response.isCompleted) {
            response.complete();
          }
          _response = null;
          processor.cancelHistoryRequest();
        }
      }
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

  void cancelAll() {
    _generation++;
    cancel(StateError('History session ended'));
    processor.cancelHistoryRequest();
  }

  /// Rejects an in-flight transfer when its connection or packet integrity fails.
  void cancel(Object error) {
    final response = _response;
    if (response != null && !response.isCompleted) {
      response.completeError(error);
    }
  }
}
