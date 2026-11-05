import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/auth_api.dart';
import 'package:asset360_mobile/data/api/auth_diagnostics.dart';
import 'package:asset360_mobile/data/api/auth_models.dart';
import 'package:asset360_mobile/data/api/token_store.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A JWT whose payload is [claims] (signature is not checked by the app).
String _jwt(Map<String, dynamic> claims) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.c2lnbmF0dXJl';
}

/// Answers by path: [routes] maps "POST /api/auth/login" → a handler returning (status, body).
class _Server implements HttpClientAdapter {
  _Server(this.routes);

  final Map<String, (int, Object?) Function(RequestOptions o, Map<String, dynamic> body)> routes;
  final calls = <String>[];
  final bodies = <String, Map<String, dynamic>>{};

  int count(String route) => calls.where((c) => c == route).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final route = '${o.method} ${o.path}';
    calls.add(route);
    final body = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : <String, dynamic>{};
    bodies[route] = body;
    final handler = routes[route];
    final (status, reply) = handler == null ? (404, {'message': 'No route $route'}) : handler(o, body);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return ResponseBody.fromString(
      reply is String ? reply : jsonEncode(reply),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _exp = DateTime.now().add(const Duration(minutes: 30));
final _access = _jwt({'exp': _exp.millisecondsSinceEpoch ~/ 1000, 'iss': 'A360.UserAccount', 'sub': 'u-1'});
const _refresh = 'refresh-token-0123456789';

Map<String, dynamic> _loginTotp({bool setup = true, int seconds = 300}) => {
  'twoFactorRequired': true,
  'method': 'totp',
  'message': 'Enter the code from your authenticator app.',
  'otpExpiresInSeconds': seconds,
  'loginToken': 'login-token-abcdef123456',
  'setupRequired': setup,
  'qrCodeImage':
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'manualEntryKey': 'JBSWY3DPEHPK3PXP',
};

Map<String, (int, Object?) Function(RequestOptions, Map<String, dynamic>)> _routes({
  Map<String, dynamic>? login,
  String goodCode = '123456',
  Object? Function()? tokens,
}) => {
  'POST /api/auth/login': (_, b) =>
      b['password'] == 'secret' ? (200, login ?? _loginTotp()) : (401, {'message': 'Invalid username or password.'}),
  'POST /api/auth/verify-totp': (_, b) => b['code'] == goodCode && b['loginToken'] == 'login-token-abcdef123456'
      ? (200, tokens?.call() ?? {'accessToken': _access, 'refreshToken': _refresh})
      : (400, {'message': 'Invalid authenticator code.'}),
  'POST /api/auth/verify-otp': (_, b) => b['otp'] == goodCode
      ? (200, tokens?.call() ?? {'accessToken': _access, 'refreshToken': _refresh})
      : (400, {'message': 'Invalid or expired OTP.'}),
  'POST /api/auth/refresh': (_, b) => b['refreshToken'] == _refresh
      ? (200, {'accessToken': 'new-access', 'refreshToken': _refresh, 'expiresIn': 1800})
      : (401, {'message': 'Invalid refresh token.'}),
  'POST /api/auth/logout': (_, _) => (200, {'message': 'Logged out.'}),
  'GET /api/auth/me': (o, _) => (o.headers['Authorization'] as String?)?.startsWith('Bearer ') == true
      ? (
          200,
          {
            'id': 'u-1',
            'fullName': 'Ahmed Basim',
            'userName': 'ahmed',
            'email': 'ahmed@purpleiq.ae',
            'userRoleId': 'R2',
          },
        )
      : (401, {'message': 'Unauthorized'}),
  'GET /api/auth/roles': (_, _) => (
    200,
    [
      {'roleId': 'R1', 'roleName': 'Administrator', 'description': 'All'},
      {'roleId': 'R2', 'roleName': 'Maintenance Engineer', 'description': ''},
    ],
  ),
};

({ProviderContainer c, _Server server, MemoryTokenStore store}) _setup(_Server server, {String? storedRefresh}) {
  final store = MemoryTokenStore(storedRefresh);
  final dio = Dio(BaseOptions(baseUrl: 'http://auth.test:5018', responseType: ResponseType.plain))
    ..httpClientAdapter = server;
  final c = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authApiProvider.overrideWith(
        (ref) => AuthApi(dio, ref.read(authDiagnosticsProvider.notifier), checkConfig: false),
      ),
    ],
  );
  addTearDown(c.dispose);
  return (c: c, server: server, store: store);
}

void main() {
  group('tolerant parsing', () {
    test('tokens at the top level, nested under "data" / "tokens", or a bare JWT', () {
      final now = DateTime(2026, 9, 25, 10);
      final flat = TokenPair.tryParse({'accessToken': 'a', 'refreshToken': 'r', 'expiresIn': 60}, now: now)!;
      expect(
        (flat.accessToken, flat.refreshToken, flat.expiresAt, flat.expirySource),
        ('a', 'r', now.add(const Duration(seconds: 60)), 'expiresIn'),
      );
      final nested = TokenPair.tryParse({
        'success': true,
        'data': {'token': 'a2', 'refresh_token': 'r2'},
      }, now: now)!;
      expect((nested.accessToken, nested.refreshToken, nested.expirySource), ('a2', 'r2', 'assumed 30 min'));
      expect(nested.expiresAt, now.add(const Duration(minutes: 30)));
      final deep = TokenPair.tryParse({
        'result': {
          'tokens': {'access_token': 'a3', 'expiresAt': '2026-09-25T11:00:00Z'},
        },
        'refreshToken': 'r3',
      }, now: now)!;
      expect((deep.accessToken, deep.refreshToken, deep.expirySource), ('a3', 'r3', 'expiresAt'));
    });

    test('a token only as a JWT: the "exp" claim gives the expiry', () {
      final exp = DateTime(2026, 9, 25, 11, 15);
      final jwt = _jwt({'exp': exp.millisecondsSinceEpoch ~/ 1000});
      final t = TokenPair.tryParse({'jwt': jwt})!;
      expect(t.expiresAt, exp);
      expect(t.expirySource, 'JWT exp');
      expect(TokenPair.tryParse(jwt)!.accessToken, jwt, reason: 'a reply that is just the JWT');
      expect(TokenPair.tryParse({'message': 'ok'}), isNull);
      expect(TokenPair.tryParse(null), isNull);
    });

    test('login, /me and /roles replies with other names and missing fields never throw', () {
      final l = LoginResult.fromJson({'data': _loginTotp()});
      expect((l.twoFactorRequired, l.method, l.setupRequired, l.otpExpiresInSeconds), (true, 'totp', true, 300));
      expect(decodeDataUri(l.qrCodeImage), isNotNull);
      final direct = LoginResult.fromJson({'accessToken': 'a', 'refreshToken': 'r'});
      expect((direct.twoFactorRequired, direct.tokens?.accessToken), (false, 'a'));
      expect(LoginResult.fromJson('not json').tokens, isNull);

      final me = CurrentUser.fromJson({
        'user': {
          'name': 'Rex K',
          'role': {'roleId': 'R9', 'roleName': 'Supervisor'},
        },
      });
      expect((me.fullName, me.roleId, me.roleName, me.email), ('Rex K', 'R9', 'Supervisor', null));
      expect(CurrentUser.fromJson(null, fallbackUserName: 'rex').fullName, 'rex');
      expect(CurrentUser.fromJson(<String, dynamic>{}).fullName, CurrentUser.placeholderName);
      expect(
        AuthRole.listFromJson([
          {'roleId': 'R1', 'roleName': 'Admin'},
          {'x': 1},
        ]).single.roleName,
        'Admin',
      );
    });

    test('diagnostics shorten every secret to 6 characters', () {
      final r =
          redactSecrets({
                'accessToken': 'eyJhbGciOiJIUzI1NiJ9.abc',
                'nested': {
                  'refreshToken': 'abcdefghijkl',
                  'manualEntryKey': 'JBSWY3DPEHPK3PXP',
                  'qrCodeImage': 'data:image/png;base64,xx',
                },
                'otp': '123456',
                'otpExpiresInSeconds': 300,
                'maskedEmail': 'a***@x.ae',
                'password': 'pw',
              })
              as Map;
      expect(r['accessToken'], 'eyJhbG…');
      expect((r['nested'] as Map)['refreshToken'], 'abcdef…');
      expect((r['nested'] as Map)['manualEntryKey'], 'JBSWY3…');
      expect((r['nested'] as Map)['qrCodeImage'], 'data:i…');
      expect(r['otp'], '******…');
      expect(r['otpExpiresInSeconds'], 300, reason: 'numbers are not secrets');
      expect(r['maskedEmail'], 'a***@x.ae');
      expect(r['password'], '**…');
    });
  });

  group('session flows', () {
    setUp(() => debugApiMode = true);
    tearDown(() => debugApiMode = null);

    test('login → setupRequired → verify-totp → signed in; /me + role name; refresh token stored', () async {
      final t = _setup(_Server(_routes()));
      final auth = t.c.read(authProvider.notifier);
      expect(await auth.login(' ahmed ', 'secret', rememberMe: true), LoginStep.setupAuthenticator);
      final p = t.c.read(authProvider) as AuthTwoFactorPending;
      expect((p.userName, p.manualEntryKey, p.method), ('ahmed', 'JBSWY3DPEHPK3PXP', 'totp'));
      expect(t.c.read(sessionProvider).passwordVerified, isTrue);

      await auth.verifyCode('123456');
      expect(t.server.bodies['POST /api/auth/verify-totp'], {
        'userName': 'ahmed',
        'loginToken': 'login-token-abcdef123456',
        'code': '123456',
      });
      final s = t.c.read(authProvider) as AuthSignedIn;
      expect(s.user.fullName, 'Ahmed Basim');
      expect(s.user.roleName, 'Maintenance Engineer');
      expect(s.tokens.expirySource, 'JWT exp');
      expect(t.store.refreshToken, _refresh);
      expect(t.c.read(sessionProvider).loggedIn, isFalse, reason: 'Home opens after the success animation');
      auth.enterApp();
      expect(t.c.read(sessionProvider).loggedIn, isTrue);
      final user = t.c.read(currentUserProvider);
      expect(
        (user.name, user.username, user.email, user.role),
        ('Ahmed Basim', 'ahmed', 'ahmed@purpleiq.ae', 'Maintenance Engineer'),
      );
      expect(auth.accessToken, _access);
    });

    test('method otp → verify-otp {userName, otp}; Remember me off stores nothing', () async {
      final t = _setup(
        _Server(
          _routes(
            login: {
              'twoFactorRequired': true,
              'method': 'otp',
              'maskedEmail': 'a***@purpleiq.ae',
              'otpExpiresInSeconds': 120,
            },
          ),
        ),
      );
      final auth = t.c.read(authProvider.notifier);
      expect(await auth.login('ahmed', 'secret', rememberMe: false), LoginStep.enterCode);
      expect((t.c.read(authProvider) as AuthTwoFactorPending).maskedEmail, 'a***@purpleiq.ae');
      await auth.verifyCode('123456');
      expect(t.server.bodies['POST /api/auth/verify-otp'], {'userName': 'ahmed', 'otp': '123456'});
      expect(t.c.read(authProvider), isA<AuthSignedIn>());
      expect(t.store.refreshToken, isNull);
    });

    test('wrong password and wrong code show the server message; still pending after a wrong code', () async {
      final t = _setup(_Server(_routes()));
      final auth = t.c.read(authProvider.notifier);
      await expectLater(
        auth.login('ahmed', 'nope', rememberMe: true),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid username or password.')),
      );
      await auth.login('ahmed', 'secret', rememberMe: true);
      await expectLater(
        auth.verifyCode('000000'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid authenticator code.')),
      );
      expect(t.c.read(authProvider), isA<AuthTwoFactorPending>());
    });

    test('an expired login token → back to Login with "Code expired – sign in again"', () async {
      final t = _setup(_Server(_routes(login: _loginTotp(seconds: 1))));
      final auth = t.c.read(authProvider.notifier);
      await auth.login('ahmed', 'secret', rememberMe: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await expectLater(
        auth.verifyCode('123456'),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.expired)),
      );
      expect(t.c.read(authProvider), isA<AuthSignedOut>());
      expect(t.c.read(sessionProvider).passwordVerified, isFalse);
      expect(t.c.read(sessionProvider).notice, AuthNotifier.codeExpiredMessage);
      expect(t.server.count('POST /api/auth/verify-totp'), 0);
    });

    test('tokens nested under "data", login without 2-step, and an unrecognised reply', () async {
      final t = _setup(
        _Server(
          _routes(
            login: {
              'twoFactorRequired': false,
              'data': {'token': _access, 'refreshToken': _refresh},
            },
          ),
        ),
      );
      final auth = t.c.read(authProvider.notifier);
      expect(await auth.login('ahmed', 'secret', rememberMe: true), LoginStep.signedIn);
      expect(auth.accessToken, _access);

      final bad = _setup(_Server(_routes(login: {'message': 'Welcome'})));
      await expectLater(
        bad.c.read(authProvider.notifier).login('ahmed', 'secret', rememberMe: true),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', AuthApi.unrecognisedMessage)),
      );
      final diag = bad.c.read(authDiagnosticsProvider)['login']!;
      expect(diag.status, 200);
      expect(diag.note, 'no access token found');
      expect(
        bad.c.read(authDiagnosticsProvider.notifier).report(),
        isNot(contains('secret')),
        reason: 'password redacted',
      );
    });

    test('a 401 from the gateway triggers exactly ONE refresh, then every request is retried', () async {
      final t = _setup(_Server(_routes()));
      final auth = t.c.read(authProvider.notifier);
      await auth.login('ahmed', 'secret', rememberMe: true);
      await auth.verifyCode('123456');
      final gateway = _Server({
        'GET /api/asset-categories': (o, _) =>
            o.headers['Authorization'] == 'Bearer new-access' ? (200, []) : (401, null),
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test:5296'))..httpClientAdapter = gateway;
      dio.interceptors.add(
        AuthInterceptor(token: auth.validAccessToken, onUnauthorized: auth.refreshAccessToken, retry: dio.fetch),
      );
      final api = ApiClient(dio, checkConfig: false);
      final results = await Future.wait([for (var i = 0; i < 3; i++) api.get<Object?>('/api/asset-categories')]);
      expect(results.map((r) => r.statusCode), [200, 200, 200]);
      expect(t.server.count('POST /api/auth/refresh'), 1);
      expect(gateway.count('GET /api/asset-categories'), 6, reason: '3 refused + 3 retried');
      expect(auth.accessToken, 'new-access');
    });

    test('a failed refresh signs out with "Your session expired …" and clears storage', () async {
      final t = _setup(_Server(_routes(tokens: () => {'accessToken': _access, 'refreshToken': 'revoked'})));
      final auth = t.c.read(authProvider.notifier);
      await auth.login('ahmed', 'secret', rememberMe: true);
      await auth.verifyCode('123456');
      auth.enterApp();
      expect(t.store.refreshToken, 'revoked');
      expect(await auth.refreshAccessToken(), isNull);
      expect(t.c.read(authProvider), isA<AuthSignedOut>());
      expect(t.c.read(sessionProvider).loggedIn, isFalse);
      expect(t.c.read(sessionProvider).notice, AuthNotifier.sessionExpiredMessage);
      expect(t.store.refreshToken, isNull);
    });

    test('app start: a stored refresh token → refresh → /me → signed in; a bad one → "Please sign in again"', () async {
      final ok = _setup(_Server(_routes()), storedRefresh: _refresh);
      expect(await ok.c.read(authProvider.notifier).restore(), isTrue);
      expect(ok.c.read(sessionProvider).loggedIn, isTrue);
      expect(ok.c.read(currentUserProvider).name, 'Ahmed Basim');

      final bad = _setup(_Server(_routes()), storedRefresh: 'old');
      expect(await bad.c.read(authProvider.notifier).restore(), isFalse);
      expect(bad.c.read(sessionProvider).notice, AuthNotifier.signInAgainMessage);
      expect(bad.store.refreshToken, isNull);

      final none = _setup(_Server(_routes()));
      expect(await none.c.read(authProvider.notifier).restore(), isFalse);
      expect(none.server.calls, isEmpty);
    });

    test('logout posts the refresh token and clears storage, even when the call fails', () async {
      for (final failing in [false, true]) {
        final routes = _routes();
        if (failing) routes['POST /api/auth/logout'] = (_, _) => (500, {'message': 'down'});
        final t = _setup(_Server(routes));
        final auth = t.c.read(authProvider.notifier);
        await auth.login('ahmed', 'secret', rememberMe: true);
        await auth.verifyCode('123456');
        auth.enterApp();
        await auth.logout();
        expect(t.server.bodies['POST /api/auth/logout'], {'refreshToken': _refresh});
        expect(t.store.refreshToken, isNull);
        expect(t.c.read(authProvider), isA<AuthSignedOut>());
        expect(t.c.read(sessionProvider).loggedIn, isFalse);
      }
    });
  });

  testWidgets('API mode on screen: Sign in → Set up your Authenticator → code → Home with the /me name', (
    tester,
  ) async {
    debugApiMode = true;
    addTearDown(() => debugApiMode = null);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final server = _Server(_routes());
    final dio = Dio(BaseOptions(baseUrl: 'http://auth.test:5018', responseType: ResponseType.plain))
      ..httpClientAdapter = server;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          authApiProvider.overrideWith(
            (ref) => AuthApi(dio, ref.read(authDiagnosticsProvider.notifier), checkConfig: false),
          ),
        ],
        child: const Asset360App(),
      ),
    );
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsNothing, reason: 'hidden in API mode');
    expect(find.text('Diagnostics'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'ahmed');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid username or password.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your Authenticator'), findsOneWidget);
    expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
    expect(find.text('Using another device? Scan this QR'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Enter Authenticator Code'), findsOneWidget);
    expect(find.textContaining('Code expires in'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '000000');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Invalid authenticator code.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '123456');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Signed in'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ahmed'), findsWidgets, reason: 'Home greeting uses the /me name');

    // Diagnostics recorded every call, with the secrets shortened.
    final container = ProviderScope.containerOf(tester.element(find.byType(Asset360App)));
    final report = container.read(authDiagnosticsProvider.notifier).report();
    expect(report, contains('== verify-totp'));
    expect(report, isNot(contains(_access)));
    expect(report, isNot(contains('JBSWY3DPEHPK3PXP')));
    await tester.pumpWidget(const SizedBox());
  });
}
