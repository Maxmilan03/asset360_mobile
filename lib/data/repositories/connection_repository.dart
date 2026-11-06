import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';

/// One line of Administration → Backend API → Test connection.
class ServiceHealth {
  const ServiceHealth({
    required this.service,
    required this.url,
    this.statusCode,
    this.elapsed,
    this.status,
    this.error,
  });

  final BackendService service;

  /// The URL called ("http://…:5401/health"), or empty when the base URL is not set.
  final String url;
  final int? statusCode;
  final Duration? elapsed;

  /// The reply's `status` ("Healthy"), or the plain-text body.
  final String? status;

  /// Why the check failed (not configured, no network, HTTP error, unhealthy); null = OK.
  final String? error;

  bool get ok => error == null;
}

/// A plain Dio for the health checks (no token: /health is public). Tests override it.
final healthDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Base URL and config problem of each service (tests override it).
final serviceTargetsProvider = Provider<Map<BackendService, ({String baseUrl, String? problem})>>(
  (ref) => {for (final s in BackendService.values) s: (baseUrl: s.baseUrl, problem: s.configProblem)},
);

/// Test connection: GET /health on AUTH, ASSET, MEDIA and MASTER DATA (in parallel), one result each.
/// State: null = not tested yet; loading while the calls run. Never an error: failures are per service.
class ConnectionTestNotifier extends AsyncNotifier<List<ServiceHealth>?> {
  static const healthPath = '/health';

  @override
  List<ServiceHealth>? build() => null;

  Future<void> run() async {
    state = const AsyncLoading();
    final results = await Future.wait(BackendService.values.map(check));
    state = AsyncData(results);
  }

  Future<ServiceHealth> check(BackendService service) async {
    final (:baseUrl, :problem) = ref.read(serviceTargetsProvider)[service]!;
    if (problem != null) return ServiceHealth(service: service, url: '', error: problem);
    final base = baseUrl;
    final url = '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$healthPath';
    final watch = Stopwatch()..start();
    try {
      final res = await ref.read(healthDioProvider).get<Object?>(url);
      final data = res.data;
      final status = data is Map ? '${data['status'] ?? ''}' : (data is String ? data.trim() : '');
      final unhealthy = status.isNotEmpty && status.toLowerCase() != 'healthy';
      return ServiceHealth(
        service: service,
        url: url,
        statusCode: res.statusCode,
        elapsed: watch.elapsed,
        status: status.isEmpty ? null : status,
        error: unhealthy ? 'Service reports "$status"' : null,
      );
    } catch (e) {
      final err = ApiException.from(e);
      return ServiceHealth(
        service: service,
        url: url,
        statusCode: err.statusCode,
        elapsed: watch.elapsed,
        error: err.statusCode == null ? err.message : 'HTTP ${err.statusCode}: ${err.message}',
      );
    }
  }
}

final connectionTestProvider = AsyncNotifierProvider<ConnectionTestNotifier, List<ServiceHealth>?>(
  ConnectionTestNotifier.new,
);
