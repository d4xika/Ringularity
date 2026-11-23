import 'dart:async';

import 'package:http/http.dart' as http;

import '../user/consent_service.dart';

/// Central transport for backend requests requiring explicit, current consent.
///
/// Covers authentication and connectivity checks as well as health-data requests.
/// Each request owns its client and lease so withdrawal can abort active work and
/// reject late responses. Data already received by a server cannot be recalled.
class ConsentHttp {
  /// Sends a consent-authorized GET request, including backend connectivity checks.
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _send('GET', url, headers: headers);

  /// Sends a consent-authorized POST request with an optional encoded body.
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    String? body,
  }) => _send('POST', url, headers: headers, body: body);

  /// Sends a consent-authorized PATCH request for profile changes.
  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    String? body,
  }) => _send('PATCH', url, headers: headers, body: body);

  /// Sends a consent-authorized DELETE request, such as deleting a recorded activity.
  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    String? body,
  }) => _send('DELETE', url, headers: headers, body: body);

  /// Checks consent before dispatch and after reading the complete response body.
  /// Invalidated leases abort the request; client and listener cleanup also runs on timeout or failure.
  static Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final consent = ConsentService.instance;
    final lease = consent.requireConsent();
    final client = http.Client();
    final aborted = Completer<void>();

    /// Aborts transport work when consent or its owning account generation is invalidated.
    void cancelIfRevoked() {
      if (!lease.isCurrent) {
        if (!aborted.isCompleted) {
          aborted.complete();
        }
        client.close();
      }
    }

    consent.addListener(cancelIfRevoked);
    try {
      final request = http.AbortableRequest(
        method,
        url,
        abortTrigger: aborted.future,
      );
      request.headers.addAll(headers ?? {});
      if (body != null) {
        request.body = body;
      }
      lease.check();
      final response = await http.Response.fromStream(
        await client.send(request),
      ).timeout(const Duration(seconds: 30));
      lease.check();
      return response;
    } finally {
      consent.removeListener(cancelIfRevoked);
      client.close();
    }
  }
}
