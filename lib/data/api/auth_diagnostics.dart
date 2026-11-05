import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/auth_models.dart';

/// The login-service endpoints shown in Auth diagnostics, in flow order.
const authEndpoints = ['login', 'verify-totp', 'verify-otp', 'refresh', 'me', 'roles', 'logout'];

/// One call to the login service, as received. Secrets are already shortened ([redactSecrets]);
/// raw tokens never get here.
class AuthCallRecord {
  const AuthCallRecord({
    required this.endpoint,
    required this.at,
    required this.method,
    required this.url,
    this.status,
    this.request,
    this.response,
    this.error,
    this.note,
  });

  final String endpoint;
  final DateTime at;
  final String method;
  final String url;

  /// HTTP status; null when no answer came (timeout, no network).
  final int? status;
  final Object? request;
  final Object? response;
  final String? error;

  /// What the app made of the reply ("tokens found (JWT exp)", "no access token found" …).
  final String? note;
}

/// Auth diagnostics (works in release builds): the last call of each endpoint.
class AuthDiagnosticsNotifier extends Notifier<Map<String, AuthCallRecord>> {
  @override
  Map<String, AuthCallRecord> build() => const {};

  void record(AuthCallRecord r) => state = {...state, r.endpoint: r};

  /// Adds what the app understood to the last record of [endpoint].
  void note(String endpoint, String note) {
    final r = state[endpoint];
    if (r == null) return;
    state = {
      ...state,
      endpoint: AuthCallRecord(
        endpoint: r.endpoint,
        at: r.at,
        method: r.method,
        url: r.url,
        status: r.status,
        request: r.request,
        response: r.response,
        error: r.error,
        note: note,
      ),
    };
  }

  void clear() => state = const {};

  /// The whole report as text (Copy button).
  String report() {
    const pretty = JsonEncoder.withIndent('  ');
    final b = StringBuffer()
      ..writeln('Asset360 – Auth diagnostics')
      ..writeln('USE_API: $apiMode')
      ..writeln(
        [
          for (final s in BackendService.values) '${s.define}: ${s.baseUrl.isEmpty ? '(not set)' : s.baseUrl}',
        ].join('\n'),
      )
      ..writeln('Secrets are shortened to their first 6 characters.');
    for (final e in authEndpoints) {
      final r = state[e];
      b.writeln('\n== $e');
      if (r == null) {
        b.writeln('(not called yet)');
        continue;
      }
      b
        ..writeln('${r.at.toIso8601String()}  ${r.method} ${r.url}')
        ..writeln('HTTP ${r.status ?? '—'}${r.error == null ? '' : '  error: ${r.error}'}');
      if (r.note != null) b.writeln('App: ${r.note}');
      if (r.request != null) b.writeln('Request: ${pretty.convert(r.request)}');
      b.writeln('Response: ${r.response == null ? '(empty)' : pretty.convert(r.response)}');
    }
    return b.toString();
  }
}

final authDiagnosticsProvider = NotifierProvider<AuthDiagnosticsNotifier, Map<String, AuthCallRecord>>(
  AuthDiagnosticsNotifier.new,
);

/// JSON-safe, redacted copy of a reply body (strings that are not JSON are kept as text, cut at 2,000 chars).
Object? diagnosticBody(Object? body) {
  if (body is String) {
    try {
      return redactSecrets(jsonDecode(body));
    } catch (_) {
      // A bare token (no spaces, long) is a secret too.
      if (!body.contains(RegExp(r'\s')) && body.length > 24) return redactValue(body);
      return body.length > 2000 ? '${body.substring(0, 2000)}…' : body;
    }
  }
  return redactSecrets(body);
}
