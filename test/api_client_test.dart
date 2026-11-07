import 'dart:convert';
import 'dart:typed_data';

import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/media_api.dart';
import 'package:asset360_mobile/data/repositories/connection_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [status] / [body] (or throws [error]) and remembers the request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.status = 200, this.body, this.error});

  final int status;
  final Object? body;
  final DioExceptionType? error;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (error != null) throw DioException(requestOptions: options, type: error!);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/problem+json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter adapter, {String token = 'test-token'}) => Dio(BaseOptions(baseUrl: 'http://backend.test:5296'))
  ..httpClientAdapter = adapter
  ..interceptors.add(AuthInterceptor(token: () async => token));

Future<ApiException> _fail(_FakeAdapter adapter) async {
  try {
    await ApiClient(_dio(adapter), checkConfig: false).get<Object?>('/api/asset-categories');
  } on ApiException catch (e) {
    return e;
  }
  fail('expected an ApiException');
}

void main() {
  test('every request carries the Bearer token', () async {
    final adapter = _FakeAdapter(body: []);
    await ApiClient(_dio(adapter), checkConfig: false).get<Object?>('/api/asset-categories');
    expect(adapter.last!.headers['Authorization'], 'Bearer test-token');
    expect(adapter.last!.uri.toString(), 'http://backend.test:5296/api/asset-categories');
  });

  test('400 ValidationProblem → field errors keyed by the backend field path', () async {
    final e = await _fail(
      _FakeAdapter(
        status: 400,
        body: {
          'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
          'title': 'One or more validation errors occurred.',
          'status': 400,
          'errors': {
            'Purchase.PurchaseCost': ['Purchase Cost must be 0 or more.', 'second message'],
            'AssetTag': ["An asset with tag 'GEN-00045' is already registered."],
          },
        },
      ),
    );
    expect(e.kind, ApiErrorKind.validation);
    expect(e.statusCode, 400);
    expect(e.message, 'One or more validation errors occurred.');
    expect(e.fieldErrors, {
      'Purchase.PurchaseCost': 'Purchase Cost must be 0 or more.',
      'AssetTag': "An asset with tag 'GEN-00045' is already registered.",
    });
  });

  test('401 / 403 / 404 / 409 / 500 have clear messages', () async {
    expect(
      (await _fail(_FakeAdapter(status: 401))).message,
      'Token expired or invalid – ask backend for a new dev token',
    );
    expect((await _fail(_FakeAdapter(status: 403))).kind, ApiErrorKind.forbidden);
    expect((await _fail(_FakeAdapter(status: 404))).message, 'Not found on the server.');
    final conflict = await _fail(_FakeAdapter(status: 409, body: {'title': 'Conflict', 'detail': 'Tag already used.'}));
    expect(conflict.kind, ApiErrorKind.conflict);
    expect(conflict.message, 'Tag already used.');
    expect((await _fail(_FakeAdapter(status: 503))).kind, ApiErrorKind.server);
  });

  test('timeouts and no network', () async {
    expect((await _fail(_FakeAdapter(error: DioExceptionType.connectionTimeout))).kind, ApiErrorKind.timeout);
    expect((await _fail(_FakeAdapter(error: DioExceptionType.receiveTimeout))).kind, ApiErrorKind.timeout);
    final offline = await _fail(_FakeAdapter(error: DioExceptionType.connectionError));
    expect(offline.kind, ApiErrorKind.noNetwork);
    expect(offline.message, contains('http://backend.test:5296'));
  });

  test('without dart-defines the client refuses to call and says what is missing', () async {
    expect(kApiBaseUrl, isEmpty, reason: 'tests run without --dart-define');
    final adapter = _FakeAdapter(body: []);
    try {
      await ApiClient(_dio(adapter)).get<Object?>('/api/asset-categories');
      fail('expected notConfigured');
    } on ApiException catch (e) {
      expect(e.kind, ApiErrorKind.notConfigured);
      expect(e.message, contains('API_BASE_URL'));
    }
    expect(adapter.last, isNull, reason: 'no request was sent');
  });

  test('a missing token does not block the call (no Authorization header)', () async {
    for (final token in <Future<String?> Function()>[() async => null, () async => throw StateError('no session')]) {
      final adapter = _FakeAdapter(body: []);
      final dio = Dio(BaseOptions(baseUrl: 'http://asset.test:5401'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(token: token));
      final res = await ApiClient(dio, checkConfig: false).get<Object?>('/api/asset-categories');
      expect(res.statusCode, 200);
      expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
    }
  });

  test('MEDIA_BASE_URL has its own config problem; the media client checks it', () async {
    expect(mediaConfigProblem, contains('MEDIA_BASE_URL'));
    expect(mediaConfigProblem, contains('5300'));
    expect(apiConfigProblem, contains('5401'));
    final adapter = _FakeAdapter(body: {});
    try {
      await ApiClient(_dio(adapter), service: BackendService.media).post<Object?>(MediaApi.uploadPath);
      fail('expected notConfigured');
    } on ApiException catch (e) {
      expect(e.kind, ApiErrorKind.notConfigured);
      expect(e.message, contains('MEDIA_BASE_URL'));
    }
    expect(adapter.last, isNull);
  });

  test('upload posts multipart to /api/media/upload with the token and rewrites a localhost URL', () async {
    final adapter = _FakeAdapter(body: {'url': 'http://localhost:5300/uploads/2026/a.jpg'});
    final dio = Dio(BaseOptions(baseUrl: 'http://media.test:5300'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(token: () async => 'test-token'));
    final api = MediaApi(ApiClient(dio, checkConfig: false, service: BackendService.media));
    final up = await api.upload(fileName: 'a.jpg', category: 'asset-images', bytes: [1, 2, 3]);
    expect(adapter.last!.uri.toString(), 'http://media.test:5300/api/media/upload');
    final form = adapter.last!.data as FormData;
    expect({for (final f in form.fields) f.key: f.value}, {'category': 'asset-images'});
    expect(form.files.single.key, 'file');
    expect(adapter.last!.headers['Authorization'], 'Bearer test-token');
    // Tests run without MEDIA_BASE_URL, so the URL is left as returned.
    expect(up.url, 'http://localhost:5300/uploads/2026/a.jpg');
  });

  test('resolveMediaUrl: localhost / 127.0.0.1 / relative → MEDIA_BASE_URL + same path', () {
    const media = 'http://172.16.100.26:5300';
    expect(
      resolveMediaUrl('http://localhost:5300/uploads/a.jpg?v=2', mediaBase: media),
      'http://172.16.100.26:5300/uploads/a.jpg?v=2',
    );
    expect(
      resolveMediaUrl('https://127.0.0.1:7000/uploads/x/b.png', mediaBase: media),
      'http://172.16.100.26:5300/uploads/x/b.png',
    );
    expect(resolveMediaUrl('/uploads/c.pdf', mediaBase: media), 'http://172.16.100.26:5300/uploads/c.pdf');
    expect(
      resolveMediaUrl('http://cdn.example.com/uploads/d.jpg', mediaBase: media),
      'http://cdn.example.com/uploads/d.jpg',
    );
    expect(resolveMediaUrl('http://localhost/uploads/e.jpg', mediaBase: ''), 'http://localhost/uploads/e.jpg');
    expect(
      MediaUpload.fromJson({
        'data': {'filePath': '/uploads/f.jpg'},
      }).url,
      '/uploads/f.jpg',
    );
  });

  test('Test connection: GET /health on AUTH, ASSET, MEDIA, MASTER DATA and DASHBOARD, one result each', () async {
    final adapter = _HealthAdapter();
    final c = ProviderContainer(
      overrides: [
        healthDioProvider.overrideWithValue(Dio()..httpClientAdapter = adapter),
        serviceTargetsProvider.overrideWithValue({
          BackendService.auth: (baseUrl: 'http://h.test:5018', problem: null),
          BackendService.asset: (baseUrl: 'http://h.test:5401/', problem: null),
          BackendService.media: (baseUrl: '', problem: 'MEDIA_BASE_URL is not set.'),
          BackendService.masterData: (baseUrl: 'http://h.test:5500', problem: null),
          BackendService.dashboard: (baseUrl: 'http://h.test:5470', problem: null),
        }),
      ],
    );
    addTearDown(c.dispose);
    final future = c.read(connectionTestProvider.notifier).run();
    expect(c.read(connectionTestProvider).isLoading, isTrue);
    await future;
    final r = c.read(connectionTestProvider).value!;
    expect(r.map((e) => e.service), BackendService.values);
    expect(r[0].ok, isTrue);
    expect(r[0].url, 'http://h.test:5018/health');
    expect(r[0].status, 'Healthy');
    expect(r[1].ok, isFalse, reason: 'the fake answers 503 for 5401');
    expect(r[1].url, 'http://h.test:5401/health');
    expect(r[1].error, contains('503'));
    expect(r[2].ok, isFalse);
    expect(r[2].error, contains('MEDIA_BASE_URL'));
    expect(r[3].ok, isTrue);
    expect(r[3].url, 'http://h.test:5500/health');
    expect(r[4].ok, isTrue);
    expect(r[4].url, 'http://h.test:5470/health');
    expect(adapter.calls, [
      'http://h.test:5018/health',
      'http://h.test:5401/health',
      'http://h.test:5500/health',
      'http://h.test:5470/health',
    ]);
  });
}

/// /health on port 5018 → Healthy; anything else → 503.
class _HealthAdapter implements HttpClientAdapter {
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o.uri.toString());
    final ok = o.uri.port == 5018 || o.uri.port == 5500 || o.uri.port == 5470;
    return ResponseBody.fromString(
      ok ? jsonEncode({'status': 'Healthy', 'service': 'UserAccount'}) : '',
      ok ? 200 : 503,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
