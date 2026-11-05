import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/auth_diagnostics.dart';
import 'package:asset360_mobile/data/api/auth_models.dart';

/// Dio for the UserAccount (login) service at AUTH_BASE_URL. No Bearer interceptor: only /me and
/// /roles send a token, passed per call. No request logging (bodies hold passwords and tokens).
final authDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kAuthBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
      // Plain text, decoded here: a reply that is not JSON still shows in Auth diagnostics.
      responseType: ResponseType.plain,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(authDioProvider), ref.read(authDiagnosticsProvider.notifier)),
);

/// POST /api/auth/login, verify-totp, verify-otp, refresh, logout; GET /api/auth/me, /roles
/// (request bodies from docs/api/useraccount_swagger.json). Replies are parsed tolerantly
/// (auth_models.dart); every call is recorded, redacted, in Auth diagnostics.
class AuthApi {
  AuthApi(this.dio, this.diagnostics, {this.checkConfig = true});

  final Dio dio;
  final AuthDiagnosticsNotifier diagnostics;

  /// False in tests, which use a fake adapter without dart-defines.
  final bool checkConfig;

  Future<LoginResult> login(String userName, String password) async {
    final body = await _call('login', 'POST', '/api/auth/login', data: {'userName': userName, 'password': password});
    final r = LoginResult.fromJson(body);
    diagnostics.note(
      'login',
      r.twoFactorRequired
          ? 'two-factor: method=${r.method ?? '?'}, setupRequired=${r.setupRequired}, '
                'loginToken ${r.loginToken == null ? 'MISSING' : 'found'}, expires in ${r.otpExpiresInSeconds ?? '?'} s'
          : (r.tokens == null ? 'no access token found' : 'signed in directly (${r.tokens!.expirySource})'),
    );
    return r;
  }

  Future<TokenPair> verifyTotp({required String userName, required String loginToken, required String code}) =>
      _tokens('verify-totp', '/api/auth/verify-totp', {'userName': userName, 'loginToken': loginToken, 'code': code});

  Future<TokenPair> verifyOtp({required String userName, required String otp}) =>
      _tokens('verify-otp', '/api/auth/verify-otp', {'userName': userName, 'otp': otp});

  Future<TokenPair> refresh(String refreshToken) =>
      _tokens('refresh', '/api/auth/refresh', {'refreshToken': refreshToken});

  Future<void> logout(String refreshToken) =>
      _call('logout', 'POST', '/api/auth/logout', data: {'refreshToken': refreshToken});

  Future<CurrentUser> me(String accessToken, {String? fallbackUserName}) async {
    final body = await _call('me', 'GET', '/api/auth/me', bearer: accessToken);
    final user = CurrentUser.fromJson(body, fallbackUserName: fallbackUserName);
    diagnostics.note(
      'me',
      'name="${user.fullName}", userName=${user.userName ?? '—'}, email=${user.email ?? '—'}, '
          'roleId=${user.roleId ?? '—'}, roleName=${user.roleName ?? '—'}',
    );
    return user;
  }

  Future<List<AuthRole>> roles(String? accessToken) async {
    final body = await _call('roles', 'GET', '/api/auth/roles', bearer: accessToken);
    final roles = AuthRole.listFromJson(body);
    diagnostics.note('roles', '${roles.length} roles read');
    return roles;
  }

  Future<TokenPair> _tokens(String endpoint, String path, Map<String, dynamic> data) async {
    final body = await _call(endpoint, 'POST', path, data: data);
    final tokens = TokenPair.tryParse(body);
    if (tokens == null) {
      diagnostics.note(endpoint, 'no access token found in the reply');
      throw const ApiException(ApiErrorKind.unknown, unrecognisedMessage);
    }
    diagnostics.note(
      endpoint,
      'access token found, refresh token ${tokens.refreshToken == null ? 'MISSING' : 'found'}, '
      'expires ${tokens.expiresAt.toIso8601String()} (${tokens.expirySource})',
    );
    return tokens;
  }

  static const unrecognisedMessage = 'Login response not recognised – see Auth diagnostics';

  /// One request; returns the decoded JSON (or the text when it is not JSON).
  Future<Object?> _call(String endpoint, String method, String path, {Object? data, String? bearer}) async {
    final problem = checkConfig ? authConfigProblem : null;
    if (problem != null) throw ApiException(ApiErrorKind.notConfigured, problem);
    final url = '${dio.options.baseUrl}$path';
    final at = DateTime.now();
    try {
      final res = await dio.request<String>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: {if (bearer != null && bearer.isNotEmpty) 'Authorization': 'Bearer $bearer'},
        ),
      );
      final body = _decode(res.data);
      diagnostics.record(
        AuthCallRecord(
          endpoint: endpoint,
          at: at,
          method: method,
          url: url,
          status: res.statusCode,
          request: redactSecrets(data),
          response: diagnosticBody(body),
        ),
      );
      return body;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final responseBody = _decode(e.response?.data);
      // Error bodies are {"message": "..."}: the server's text is shown to the user.
      final error = status == null
          ? ApiException.fromDio(e)
          : ApiException.fromResponse(status, responseBody, path: path, serverMessage401: true);
      diagnostics.record(
        AuthCallRecord(
          endpoint: endpoint,
          at: at,
          method: method,
          url: url,
          status: status,
          request: redactSecrets(data),
          response: diagnosticBody(responseBody),
          error: error.message,
        ),
      );
      throw error;
    }
  }

  static Object? _decode(Object? text) {
    if (text is! String || text.trim().isEmpty) return text is String ? null : text;
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }
}
