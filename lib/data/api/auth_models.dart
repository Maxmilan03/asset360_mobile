import 'dart:convert';
import 'dart:typed_data';

/// Models for the UserAccount (login) service. docs/api/useraccount_swagger.json documents the
/// request bodies only, so every reply is read TOLERANTLY: several likely field names, nested
/// "data" / "tokens" objects, and wrong types are ignored instead of thrown. Every guess is a
/// question in docs/questions_for_backend.md.

/// Access tokens last 30 minutes when the reply says nothing about expiry.
const defaultAccessTokenLifetime = Duration(minutes: 30);

/// POST /api/auth/login reply.
class LoginResult {
  const LoginResult({
    required this.twoFactorRequired,
    this.method,
    this.message,
    this.otpExpiresInSeconds,
    this.maskedEmail,
    this.loginToken,
    this.setupRequired = false,
    this.qrCodeImage,
    this.manualEntryKey,
    this.tokens,
  });

  final bool twoFactorRequired;

  /// "totp" (authenticator app) or "otp" (code sent by email).
  final String? method;
  final String? message;
  final int? otpExpiresInSeconds;
  final String? maskedEmail;
  final String? loginToken;

  /// True the first time: the user must add the account to an authenticator app.
  final bool setupRequired;

  /// "data:image/png;base64,…".
  final String? qrCodeImage;
  final String? manualEntryKey;

  /// Set when the server signs the user in without a second step.
  final TokenPair? tokens;

  bool get isEmailOtp => (method ?? '').toLowerCase() == 'otp';

  factory LoginResult.fromJson(Object? json, {DateTime? now}) {
    final j = _root(json);
    final tokens = TokenPair.tryParse(json, now: now);
    final twoFactor =
        _bool(j, ['twoFactorRequired', 'requiresTwoFactor', 'twoFactor']) ??
        (tokens == null && _str(j, ['loginToken']) != null);
    return LoginResult(
      twoFactorRequired: twoFactor,
      method: _str(j, ['method', 'twoFactorMethod']),
      message: _str(j, ['message']),
      otpExpiresInSeconds: _int(j, ['otpExpiresInSeconds', 'expiresInSeconds']),
      maskedEmail: _str(j, ['maskedEmail']),
      loginToken: _str(j, ['loginToken']),
      setupRequired: _bool(j, ['setupRequired']) ?? false,
      qrCodeImage: _str(j, ['qrCodeImage', 'qrCode']),
      manualEntryKey: _str(j, ['manualEntryKey', 'secretKey']),
      tokens: twoFactor ? null : tokens,
    );
  }
}

/// Access + refresh token from verify-totp / verify-otp / refresh (or a one-step login).
class TokenPair {
  const TokenPair({required this.accessToken, this.refreshToken, required this.expiresAt, this.expirySource = ''});

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  /// How [expiresAt] was found ("expiresIn", "expiresAt", "JWT exp", "assumed 30 min"), for Auth diagnostics.
  final String expirySource;

  static const _accessKeys = ['accessToken', 'token', 'access_token', 'jwt', 'jwtToken', 'idToken'];
  static const _refreshKeys = ['refreshToken', 'refresh_token'];

  /// Finds the tokens at the top level or inside "data" / "tokens" / "result" (any depth up to 3);
  /// null when no access token is there.
  static TokenPair? tryParse(Object? json, {DateTime? now}) {
    final at = now ?? DateTime.now();
    // A reply that is just the JWT.
    if (json is String && jwtClaims(json.trim()) != null) {
      final (expires, source) = _expiry(const {}, json.trim(), at);
      return TokenPair(accessToken: json.trim(), expiresAt: expires, expirySource: source);
    }
    for (final m in _candidates(json)) {
      final access = _str(m, _accessKeys);
      if (access == null) continue;
      final refresh = _str(m, _refreshKeys) ?? _candidates(json).map((x) => _str(x, _refreshKeys)).nonNulls.firstOrNull;
      final (expires, source) = _expiry(m, access, at);
      return TokenPair(accessToken: access, refreshToken: refresh, expiresAt: expires, expirySource: source);
    }
    return null;
  }

  static (DateTime, String) _expiry(Map<String, dynamic> m, String access, DateTime now) {
    final seconds = _int(m, ['expiresIn', 'expires_in', 'accessTokenExpiresIn', 'expiresInSeconds']);
    if (seconds != null && seconds > 0) return (now.add(Duration(seconds: seconds)), 'expiresIn');
    final at = _str(m, ['expiresAt', 'accessTokenExpiresAt', 'expiration', 'expires']);
    final parsed = at == null ? null : DateTime.tryParse(at);
    if (parsed != null) return (parsed.toLocal(), 'expiresAt');
    final exp = jwtClaims(access)?['exp'];
    if (exp is num) return (DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000), 'JWT exp');
    return (now.add(defaultAccessTokenLifetime), 'assumed 30 min');
  }

  /// Same refresh token kept when a refresh reply does not send a new one.
  TokenPair withFallbackRefresh(String? fallback) => refreshToken != null || fallback == null
      ? this
      : TokenPair(accessToken: accessToken, refreshToken: fallback, expiresAt: expiresAt, expirySource: expirySource);
}

/// GET /api/auth/me.
class CurrentUser {
  const CurrentUser({
    this.id,
    required this.fullName,
    this.userName,
    this.email,
    this.roleId,
    this.roleName,
    this.phone,
  });

  final String? id;
  final String fullName;
  final String? userName;
  final String? email;
  final String? roleId;

  /// Sent by /me, or looked up in GET /api/auth/roles.
  final String? roleName;
  final String? phone;

  static const placeholderName = 'Asset360 User';

  /// Never throws; missing values stay null (screens show neutral placeholders).
  factory CurrentUser.fromJson(Object? json, {String? fallbackUserName}) {
    final j = _root(json, nested: const ['user', 'data', 'result']);
    final role = j['role'];
    final userName = _str(j, ['userName', 'username', 'unique_name', 'preferred_username']) ?? fallbackUserName;
    return CurrentUser(
      id: _str(j, ['id', 'userId', 'sub']),
      fullName: _str(j, ['fullName', 'name', 'shortName', 'displayName']) ?? userName ?? placeholderName,
      userName: userName,
      email: _str(j, ['email', 'emailAddress']),
      roleId:
          _str(j, ['userRoleId', 'roleId']) ??
          (role is Map ? _str(Map<String, dynamic>.from(role), ['roleId', 'id']) : null),
      roleName:
          _str(j, ['roleName', 'userRoleName']) ??
          (role is String ? role : (role is Map ? _str(Map<String, dynamic>.from(role), ['roleName', 'name']) : null)),
      phone: _str(j, ['contactNo', 'phone', 'phoneNumber']),
    );
  }

  CurrentUser withRoleName(String? name) => name == null || roleName != null
      ? this
      : CurrentUser(
          id: id,
          fullName: fullName,
          userName: userName,
          email: email,
          roleId: roleId,
          roleName: name,
          phone: phone,
        );
}

/// GET /api/auth/roles item: {roleId, roleName, description}.
class AuthRole {
  const AuthRole({required this.roleId, required this.roleName, this.description});

  final String roleId;
  final String roleName;
  final String? description;

  static List<AuthRole> listFromJson(Object? json) {
    final list = json is List ? json : (json is Map ? (json['items'] ?? json['data']) : null);
    if (list is! List) return const [];
    return [
      for (final r in list)
        if (r is Map)
          if ((
                _str(Map<String, dynamic>.from(r), ['roleId', 'id']),
                _str(Map<String, dynamic>.from(r), ['roleName', 'name']),
              )
              case (final id?, final name?))
            AuthRole(roleId: id, roleName: name, description: _str(Map<String, dynamic>.from(r), ['description'])),
    ];
  }
}

/// The payload of a JWT (no signature check: the app only reads exp / name), or null.
Map<String, dynamic>? jwtClaims(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final m = jsonDecode(payload);
    return m is Map ? Map<String, dynamic>.from(m) : null;
  } catch (_) {
    return null;
  }
}

/// PNG bytes of a "data:image/png;base64,…" URI (also accepts bare base64), or null.
Uint8List? decodeDataUri(String? uri) {
  if (uri == null || uri.isEmpty) return null;
  final comma = uri.indexOf(',');
  final data = uri.startsWith('data:') && comma > 0 ? uri.substring(comma + 1) : uri;
  try {
    return base64.decode(base64.normalize(data.replaceAll(RegExp(r'\s'), '')));
  } catch (_) {
    return null;
  }
}

/// Keys whose string values are secrets: shown as their first 6 characters + "…".
final _secretKey = RegExp('token|key|qrcode|password|secret|otp', caseSensitive: false);

/// A copy of [json] with secret values shortened (diagnostics, never sent anywhere).
Object? redactSecrets(Object? json) => switch (json) {
  final Map m => {
    for (final MapEntry(:key, :value) in m.entries)
      '$key': value is String && _secretKey.hasMatch('$key') ? redactValue(value) : redactSecrets(value),
  },
  final List l => [for (final v in l) redactSecrets(v)],
  _ => json,
};

String redactValue(String v) => v.length <= 6 ? '${'*' * v.length}…' : '${v.substring(0, 6)}…';

// ---- tolerant readers

Map<String, dynamic> _root(Object? json, {List<String> nested = const ['data', 'result']}) {
  if (json is! Map) return const {};
  final m = Map<String, dynamic>.from(json);
  for (final k in nested) {
    final inner = m[k];
    if (inner is Map && inner.isNotEmpty) return {...m, ...Map<String, dynamic>.from(inner)};
  }
  return m;
}

/// The reply and its nested objects ("data", "tokens", "result" …), breadth first, 3 levels.
Iterable<Map<String, dynamic>> _candidates(Object? json) sync* {
  var level = <Map<String, dynamic>>[if (json is Map) Map<String, dynamic>.from(json)];
  for (var depth = 0; depth < 3 && level.isNotEmpty; depth++) {
    yield* level;
    level = [
      for (final m in level)
        for (final v in m.values)
          if (v is Map) Map<String, dynamic>.from(v),
    ];
  }
}

String? _str(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v is num && k.toLowerCase().contains('id')) return '$v';
  }
  return null;
}

int? _int(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toInt();
    if (v is String && int.tryParse(v) != null) return int.parse(v);
  }
  return null;
}

bool? _bool(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is bool) return v;
    if (v is String && (v == 'true' || v == 'false')) return v == 'true';
  }
  return null;
}
