import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';

/// The Dio instance for the Asset service (API_BASE_URL, every /api/asset-* call). Only repositories
/// and API classes use it; screens never call HTTP directly. Tests override this provider with a fake adapter.
final dioProvider = Provider<Dio>((ref) => _serviceDio(ref, kApiBaseUrl));

/// The Dio instance for the Media service (MEDIA_BASE_URL: uploads and /uploads/... files).
final mediaDioProvider = Provider<Dio>((ref) => _serviceDio(ref, kMediaBaseUrl));

/// The Dio instance for the Master Data service (MASTER_DATA_BASE_URL: dropdown lists, locations,
/// employees). Same Bearer handling as the others.
final masterDataDioProvider = Provider<Dio>((ref) => _serviceDio(ref, kMasterDataBaseUrl));

/// Every service reads the Bearer token (for CreatedBy) but a missing token never blocks a call.
Dio _serviceDio(Ref ref, String baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );
  final auth = ref.read(authProvider.notifier);
  dio.interceptors.add(
    AuthInterceptor(token: auth.validAccessToken, onUnauthorized: auth.refreshAccessToken, retry: dio.fetch),
  );
  if (kDebugMode) dio.interceptors.add(DebugLogInterceptor());
  ref.onDispose(dio.close);
  return dio;
}

/// Thin wrapper the API classes use: every error comes out as an [ApiException].
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));

/// The same wrapper for the Media service.
final mediaClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(mediaDioProvider), service: BackendService.media),
);

/// The same wrapper for the Master Data service.
final masterDataClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(masterDataDioProvider), service: BackendService.masterData),
);

class ApiClient {
  const ApiClient(this.dio, {this.checkConfig = true, this.service = BackendService.asset});

  final Dio dio;

  /// Which base URL must be configured before a call ([BackendService.configProblem]).
  final BackendService service;

  /// False in tests, which talk to a fake adapter without dart-defines.
  final bool checkConfig;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _guard(() => dio.get<T>(path, queryParameters: query));

  Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? query}) =>
      _guard(() => dio.post<T>(path, data: data, queryParameters: query));

  Future<Response<T>> put<T>(String path, {Object? data, Map<String, dynamic>? query}) =>
      _guard(() => dio.put<T>(path, data: data, queryParameters: query));

  Future<Response<T>> delete<T>(String path, {Object? data, Map<String, dynamic>? query}) =>
      _guard(() => dio.delete<T>(path, data: data, queryParameters: query));

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() call) async {
    final problem = checkConfig ? service.configProblem : null;
    if (problem != null) throw ApiException(ApiErrorKind.notConfigured, problem);
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Service auth: adds "Authorization: Bearer `token`" (the signed-in user's access token, or the
/// optional DEV_TOKEN while nobody is signed in). No token (or a failed token lookup) = the request
/// goes without the header; nothing is blocked. On a 401 it refreshes ONCE (concurrent requests
/// share that refresh, see AuthNotifier.refreshAccessToken) and retries the request; when the
/// refresh fails the session is signed out and the 401 is passed on.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.token, this.onUnauthorized, this.retry});

  /// The access token to send (may refresh first when it is about to expire).
  final Future<String?> Function() token;

  /// A new access token after a 401, or null when the session could not be refreshed.
  final Future<String?> Function()? onUnauthorized;

  /// Sends a request again (the service Dio's `fetch`).
  final Future<Response<dynamic>> Function(RequestOptions)? retry;

  static const _retriedKey = 'auth.retried';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    String? t;
    try {
      t = await token();
    } catch (_) {
      t = null;
    }
    if (t != null && t.isNotEmpty) options.headers['Authorization'] = 'Bearer $t';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    if (err.response?.statusCode != 401 || o.extra[_retriedKey] == true || onUnauthorized == null || retry == null) {
      return handler.next(err);
    }
    final fresh = await onUnauthorized!();
    if (fresh == null) return handler.next(err);
    o
      ..headers['Authorization'] = 'Bearer $fresh'
      ..extra[_retriedKey] = true;
    try {
      handler.resolve(await retry!(o));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Debug builds only: one line per request / response, with the token hidden.
class DebugLogInterceptor extends Interceptor {
  final _started = <RequestOptions, DateTime>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _started[options] = DateTime.now();
    debugPrint('[API] → ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint('[API] ← ${response.statusCode} ${response.requestOptions.uri} ${_ms(response.requestOptions)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final body = '${err.response?.data ?? ''}';
    debugPrint(
      '[API] ✗ ${err.response?.statusCode ?? err.type.name} ${err.requestOptions.uri} ${_ms(err.requestOptions)} '
      '${body.length > 500 ? '${body.substring(0, 500)}…' : body}',
    );
    handler.next(err);
  }

  String _ms(RequestOptions o) {
    final start = _started.remove(o);
    return start == null ? '' : '(${DateTime.now().difference(start).inMilliseconds} ms)';
  }
}
