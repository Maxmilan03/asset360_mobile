import 'package:dio/dio.dart';

/// What went wrong with a backend call.
enum ApiErrorKind {
  validation,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
  timeout,
  noNetwork,
  notConfigured,
  expired,
  unknown,
}

/// Every failed backend call is turned into one of these, with a message a user can read.
/// [fieldErrors] holds a 400 ValidationProblem's `errors`, keyed by the backend field path
/// ("Purchase.PurchaseCost"), the same keys RegistrationValidator uses.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode, this.fieldErrors = const {}, this.path});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  /// Request path, for logs ("/api/asset-categories").
  final String? path;

  static const unauthorizedMessage = 'Token expired or invalid – ask backend for a new dev token';

  /// Any error from a repository call → ApiException (already one: returned as is).
  static ApiException from(Object error) => switch (error) {
    final ApiException e => e,
    final DioException e => fromDio(e),
    _ => ApiException(ApiErrorKind.unknown, 'Something went wrong: $error'),
  };

  /// [serverMessage401]: the login service answers a wrong password / code with 401 and a
  /// `{"message"}`; show that instead of the "token expired" text.
  static ApiException fromDio(DioException e, {bool serverMessage401 = false}) {
    final path = e.requestOptions.path;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          ApiErrorKind.timeout,
          'The server did not answer in time. Check that the backend is running and try again.',
          path: path,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          ApiErrorKind.noNetwork,
          'Cannot reach the server at ${e.requestOptions.baseUrl}. Check Wi-Fi and that the phone and backend '
          'are on the same network.',
          path: path,
        );
      case DioExceptionType.badCertificate:
        return ApiException(ApiErrorKind.noNetwork, 'The server certificate is not trusted.', path: path);
      case DioExceptionType.cancel:
        return ApiException(ApiErrorKind.unknown, 'The request was cancelled.', path: path);
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        final status = e.response?.statusCode;
        if (status == null) {
          return ApiException(
            ApiErrorKind.noNetwork,
            'No connection to the server (${e.message ?? e.error}).',
            path: path,
          );
        }
        return fromResponse(status, e.response?.data, path: path, serverMessage401: serverMessage401);
    }
  }

  /// Maps an HTTP error status and body (RFC 7807 problem details when the server sends them).
  static ApiException fromResponse(int status, Object? body, {String? path, bool serverMessage401 = false}) {
    final problem = body is Map ? body : const {};
    // The login service sends {"message": "..."}; ASP.NET problem details send title / detail.
    final message = _text(problem['message']);
    final detail =
        message ??
        _text(problem['detail']) ??
        _text(problem['title']) ??
        (body is String && body.isNotEmpty && body.length < 300 ? body : null);
    return switch (status) {
      400 => ApiException(
        ApiErrorKind.validation,
        message ?? _text(problem['title']) ?? 'Some values were not accepted. Check the highlighted fields.',
        statusCode: status,
        fieldErrors: _fieldErrors(problem['errors']),
        path: path,
      ),
      401 => ApiException(
        ApiErrorKind.unauthorized,
        serverMessage401 && message != null ? message : unauthorizedMessage,
        statusCode: status,
        path: path,
      ),
      403 => ApiException(
        ApiErrorKind.forbidden,
        message ?? 'You are not allowed to do that (403). Ask your administrator for the right permissions.',
        statusCode: status,
        path: path,
      ),
      404 => ApiException(ApiErrorKind.notFound, detail ?? 'Not found on the server.', statusCode: status, path: path),
      409 => ApiException(
        ApiErrorKind.conflict,
        detail ?? 'This conflicts with existing data (for example a duplicate value).',
        statusCode: status,
        path: path,
      ),
      >= 500 => ApiException(
        ApiErrorKind.server,
        'The server had a problem ($status). Try again later or tell the backend developer.',
        statusCode: status,
        path: path,
      ),
      _ => ApiException(
        ApiErrorKind.unknown,
        detail ?? 'Unexpected response ($status).',
        statusCode: status,
        path: path,
      ),
    };
  }

  /// ValidationProblem `errors`: {"Purchase.PurchaseCost": ["…", "…"]} → first message per key.
  static Map<String, String> _fieldErrors(Object? errors) {
    if (errors is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in errors.entries)
        if (key is String)
          key: switch (value) {
            final List l when l.isNotEmpty => '${l.first}',
            final String s => s,
            _ => 'Invalid value',
          },
    };
  }

  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  @override
  String toString() =>
      'ApiException(${kind.name}${statusCode == null ? '' : ' $statusCode'}${path == null ? '' : ' $path'}): $message';
}
