import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/media_auth.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/auth_api.dart';
import 'package:asset360_mobile/data/api/auth_models.dart';
import 'package:asset360_mobile/data/api/token_store.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';

/// API-mode sign-in (USE_API=true). Mock mode keeps using [SessionNotifier] alone.
///
///   signedOut → twoFactorPending → signedIn (→ [AuthNotifier.enterApp] opens Home)
///
/// The router still reads [sessionProvider] (loggedIn / passwordVerified); this notifier keeps
/// those flags in step, so the router, Login and every screen showing the user work in both modes.
sealed class AuthState {
  const AuthState();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.notice});

  /// One-time message for Login ("Your session expired …").
  final String? notice;
}

class AuthTwoFactorPending extends AuthState {
  const AuthTwoFactorPending({
    required this.userName,
    required this.method,
    required this.expiresAt,
    required this.rememberMe,
    this.loginToken,
    this.setupRequired = false,
    this.qrCodeImage,
    this.manualEntryKey,
    this.maskedEmail,
  });

  final String userName;

  /// Needed by verify-totp (not by verify-otp).
  final String? loginToken;

  /// "totp" or "otp".
  final String method;
  final bool setupRequired;
  final String? qrCodeImage;
  final String? manualEntryKey;
  final String? maskedEmail;

  /// When the login token / emailed code stops working (otpExpiresInSeconds after login).
  final DateTime expiresAt;
  final bool rememberMe;

  bool get isEmailOtp => method.toLowerCase() == 'otp';
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn({required this.user, required this.tokens, required this.rememberMe});

  final CurrentUser user;
  final TokenPair tokens;
  final bool rememberMe;
}

/// What the Sign in button leads to.
enum LoginStep { setupAuthenticator, enterCode, signedIn }

class AuthNotifier extends Notifier<AuthState> {
  /// The login token / code lifetime when login does not send otpExpiresInSeconds.
  static const defaultCodeLifetime = Duration(minutes: 5);
  static const sessionExpiredMessage = 'Your session expired. Please sign in again.';
  static const codeExpiredMessage = 'Code expired – sign in again';
  static const signInAgainMessage = 'Please sign in again';

  /// Refresh this long before the access token expires.
  static const refreshAhead = Duration(minutes: 1);

  Timer? _refreshTimer;
  Future<String?>? _refreshing;
  List<AuthRole>? _roles;

  AuthApi get _api => ref.read(authApiProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);
  SessionNotifier get _session => ref.read(sessionProvider.notifier);

  @override
  AuthState build() {
    ref.onDispose(() => _refreshTimer?.cancel());
    // Images load outside Riverpod (Image providers): keep the token where they can read it.
    listenSelf((_, s) => MediaAuth.token = s is AuthSignedIn ? s.tokens.accessToken : null);
    MediaAuth.token = null;
    return const AuthSignedOut();
  }

  /// The Bearer token for the Asset / Media services: the signed-in user's, else the optional DEV_TOKEN override.
  String? get accessToken => switch (state) {
    AuthSignedIn(:final tokens) => tokens.accessToken,
    _ => kDevToken.isEmpty ? null : kDevToken,
  };

  bool get isSignedIn => state is AuthSignedIn;

  /// [accessToken], refreshed first when it expires within [refreshAhead] (the timer missed it,
  /// e.g. the phone slept).
  Future<String?> validAccessToken() async {
    final s = state;
    if (s is AuthSignedIn && s.tokens.expiresAt.subtract(refreshAhead).isBefore(DateTime.now())) {
      return refreshAccessToken();
    }
    return accessToken;
  }

  // ---------------------------------------------------------------- sign in

  /// Step 1. Throws [ApiException] with the server's message (or "not recognised").
  Future<LoginStep> login(String userName, String password, {required bool rememberMe}) async {
    final user = userName.trim();
    final r = await _api.login(user, password);
    if (r.twoFactorRequired) {
      final method = (r.method ?? 'totp').toLowerCase();
      if (method != 'otp' && r.loginToken == null) {
        throw const ApiException(ApiErrorKind.unknown, AuthApi.unrecognisedMessage);
      }
      final lifetime = (r.otpExpiresInSeconds ?? 0) > 0
          ? Duration(seconds: r.otpExpiresInSeconds!)
          : defaultCodeLifetime;
      state = AuthTwoFactorPending(
        userName: user,
        loginToken: r.loginToken,
        method: method,
        setupRequired: r.setupRequired,
        qrCodeImage: r.qrCodeImage,
        manualEntryKey: r.manualEntryKey,
        maskedEmail: r.maskedEmail,
        expiresAt: DateTime.now().add(lifetime),
        rememberMe: rememberMe,
      );
      _session.apiPasswordVerified(rememberMe: rememberMe);
      return r.setupRequired ? LoginStep.setupAuthenticator : LoginStep.enterCode;
    }
    final tokens = r.tokens;
    if (tokens == null) throw const ApiException(ApiErrorKind.unknown, AuthApi.unrecognisedMessage);
    await _signedIn(tokens, userName: user, rememberMe: rememberMe);
    return LoginStep.signedIn;
  }

  /// Step 2: the authenticator code (verify-totp) or emailed code (verify-otp). Throws
  /// [ApiException] with the server message for a wrong code; an expired code signs out.
  Future<void> verifyCode(String code) async {
    final p = state;
    if (p is! AuthTwoFactorPending) throw const ApiException(ApiErrorKind.expired, codeExpiredMessage);
    if (DateTime.now().isAfter(p.expiresAt)) {
      expireCode();
      throw const ApiException(ApiErrorKind.expired, codeExpiredMessage);
    }
    final tokens = p.isEmailOtp
        ? await _api.verifyOtp(userName: p.userName, otp: code)
        : await _api.verifyTotp(userName: p.userName, loginToken: p.loginToken ?? '', code: code);
    await _signedIn(tokens, userName: p.userName, rememberMe: p.rememberMe);
  }

  /// The code screen's countdown ran out.
  void expireCode() => _signOutLocally(notice: codeExpiredMessage);

  /// Back from the code / setup screen.
  void cancelSecondFactor() => _signOutLocally();

  /// After the success animation: opens Home (the router follows the session flag).
  void enterApp() {
    if (state is AuthSignedIn) _session.apiSignedIn();
  }

  Future<void> _signedIn(TokenPair tokens, {required String userName, required bool rememberMe}) async {
    final user = await _loadUser(tokens.accessToken, userName);
    if (rememberMe && tokens.refreshToken != null) {
      await _store.writeRefreshToken(tokens.refreshToken!);
    } else {
      await _store.clear();
    }
    state = AuthSignedIn(user: user, tokens: tokens, rememberMe: rememberMe);
    _scheduleRefresh(tokens);
  }

  /// /me, plus the role name from /roles (cached). A failing /me still signs in with the user
  /// name as a placeholder (except 401: the token itself was refused).
  Future<CurrentUser> _loadUser(String accessToken, String userName) async {
    final fallback = userName.isEmpty ? null : userName;
    CurrentUser user;
    try {
      user = await _api.me(accessToken, fallbackUserName: fallback);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) rethrow;
      user = CurrentUser(fullName: fallback ?? CurrentUser.placeholderName, userName: fallback);
    }
    if (user.roleName == null && user.roleId != null) {
      try {
        _roles ??= await _api.roles(accessToken);
        for (final r in _roles!) {
          if (r.roleId == user.roleId) return user.withRoleName(r.roleName);
        }
      } on ApiException {
        // Role stays a placeholder.
      }
    }
    return user;
  }

  // ---------------------------------------------------------------- app start

  /// Splash: a stored refresh token → refresh → /me → Home. Returns true when signed in.
  Future<bool> restore() async {
    final stored = await _store.readRefreshToken();
    if (stored == null) return false;
    try {
      final tokens = (await _api.refresh(stored)).withFallbackRefresh(stored);
      await _signedIn(tokens, userName: '', rememberMe: true);
      enterApp();
      return true;
    } catch (_) {
      await _store.clear();
      _signOutLocally(notice: signInAgainMessage);
      return false;
    }
  }

  // ---------------------------------------------------------------- refresh

  /// New access token from the refresh token. Concurrent callers share ONE refresh. Returns
  /// the new token, or null after signing out with "Your session expired …".
  Future<String?> refreshAccessToken() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<String?> _refresh() async {
    final s = state;
    final refresh = s is AuthSignedIn ? s.tokens.refreshToken : null;
    if (s is! AuthSignedIn || refresh == null) {
      if (s is AuthSignedIn) await _expireSession();
      return null;
    }
    try {
      final tokens = (await _api.refresh(refresh)).withFallbackRefresh(refresh);
      if (s.rememberMe && tokens.refreshToken != null) await _store.writeRefreshToken(tokens.refreshToken!);
      if (state is! AuthSignedIn) return null; // signed out meanwhile
      state = AuthSignedIn(user: s.user, tokens: tokens, rememberMe: s.rememberMe);
      _scheduleRefresh(tokens);
      return tokens.accessToken;
    } catch (_) {
      await _expireSession();
      return null;
    }
  }

  void _scheduleRefresh(TokenPair tokens) {
    _refreshTimer?.cancel();
    final wait = tokens.expiresAt.subtract(refreshAhead).difference(DateTime.now());
    if (wait.isNegative || tokens.refreshToken == null) return;
    _refreshTimer = Timer(wait, refreshAccessToken);
  }

  Future<void> _expireSession() async {
    await _store.clear();
    _signOutLocally(notice: sessionExpiredMessage);
  }

  // ---------------------------------------------------------------- logout

  /// POST logout {refreshToken}, then clear everything locally, even if the call fails.
  Future<void> logout() async {
    final s = state;
    final refresh = s is AuthSignedIn ? s.tokens.refreshToken : await _store.readRefreshToken();
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {
        // Local sign-out still happens.
      }
    }
    await _store.clear();
    _signOutLocally();
  }

  void _signOutLocally({String? notice}) {
    _refreshTimer?.cancel();
    state = AuthSignedOut(notice: notice);
    _session.apiSignedOut(notice: notice);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
