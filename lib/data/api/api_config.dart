/// Backend settings, passed at run time only (never hard-coded). The app calls each service
/// DIRECTLY (the API Gateway on 5296 is not used for now):
///
/// ```sh
/// flutter run --dart-define=USE_API=true \
///   --dart-define=API_BASE_URL=http://<backend-ip>:5401 \
///   --dart-define=MEDIA_BASE_URL=http://<backend-ip>:5300 \
///   --dart-define=AUTH_BASE_URL=http://<backend-ip>:5018 \
///   --dart-define=MASTER_DATA_BASE_URL=http://<backend-ip>:5500 \
///   --dart-define=DASHBOARD_BASE_URL=http://<backend-ip>:5470
/// ```
///
/// See README → "Connecting to the backend".
library;

import 'package:flutter/foundation.dart';

/// True: sign-in and repositories use the backend; false (default): the mock data in lib/data/mock/
/// and the demo login (rex.kumar / Asset@360 / 123456). Code reads [apiMode], which tests can override.
const bool kUseApi = bool.fromEnvironment('USE_API');

/// Asset service root, e.g. http://192.168.1.20:5401 (no trailing /api): every /api/asset-* call.
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Media service root, e.g. http://192.168.1.20:5300: POST /api/media/upload and the /uploads/... files.
const String kMediaBaseUrl = String.fromEnvironment('MEDIA_BASE_URL');

/// UserAccount (login) service root, e.g. http://192.168.1.20:5018.
const String kAuthBaseUrl = String.fromEnvironment('AUTH_BASE_URL');

/// Master Data Management service root (dropdown lists, locations, employees).
///
/// DEV default: the shared test server, so dropdowns work without the extra define. Override it
/// with --dart-define=MASTER_DATA_BASE_URL=... (env/api_dev.json sets it) before any release build.
const String kMasterDataBaseUrl = String.fromEnvironment(
  'MASTER_DATA_BASE_URL',
  defaultValue: 'http://172.16.100.26:5500',
);

/// Dashboard service root (Home dashboard, GET /api/dashboards/mobile/*, network status + its WebSocket).
///
/// DEV default: the shared test server, like [kMasterDataBaseUrl]. Override it with
/// --dart-define=DASHBOARD_BASE_URL=... (env/api_dev.json sets it) before any release build.
const String kDashboardBaseUrl = String.fromEnvironment(
  'DASHBOARD_BASE_URL',
  defaultValue: 'http://172.16.100.26:5470',
);

/// Optional debug override: a Bearer token for the Asset / Media services, used only while nobody is signed in.
const String kDevToken = String.fromEnvironment('DEV_TOKEN');

/// Tests set this to run the API sign-in flow without --dart-define.
@visibleForTesting
bool? debugApiMode;

/// True when the app talks to the backend ([kUseApi], or a test override).
bool get apiMode => debugApiMode ?? kUseApi;

String? _urlProblem(String name, String value, String port) => switch (value) {
  '' => '$name is not set. Run with --dart-define=$name=http://<backend-ip>:$port',
  _ when Uri.tryParse(value)?.hasScheme != true => '$name "$value" must start with http:// or https://',
  _ => null,
};

/// What is missing to call the Asset service, or null when API_BASE_URL is usable.
String? get apiConfigProblem => _urlProblem('API_BASE_URL', kApiBaseUrl, '5401');

/// What is missing to call the Media service, or null when MEDIA_BASE_URL is usable.
String? get mediaConfigProblem => _urlProblem('MEDIA_BASE_URL', kMediaBaseUrl, '5300');

/// What is missing to call the login service, or null when AUTH_BASE_URL is usable.
String? get authConfigProblem => _urlProblem('AUTH_BASE_URL', kAuthBaseUrl, '5018');

/// What is missing to call the Master Data service, or null when MASTER_DATA_BASE_URL is usable.
String? get masterDataConfigProblem => _urlProblem('MASTER_DATA_BASE_URL', kMasterDataBaseUrl, '5500');

/// What is missing to call the Dashboard service, or null when DASHBOARD_BASE_URL is usable.
String? get dashboardConfigProblem => _urlProblem('DASHBOARD_BASE_URL', kDashboardBaseUrl, '5470');

/// The backend services the app calls directly.
enum BackendService {
  auth('AUTH', 'AUTH_BASE_URL', 'Login service'),
  asset('ASSET', 'API_BASE_URL', 'Asset service'),
  media('MEDIA', 'MEDIA_BASE_URL', 'Media service'),
  masterData('MASTER DATA', 'MASTER_DATA_BASE_URL', 'Master Data service'),
  dashboard('DASHBOARD', 'DASHBOARD_BASE_URL', 'Dashboard service');

  const BackendService(this.code, this.define, this.label);

  /// Short name in the connection test ("ASSET").
  final String code;

  /// The --dart-define that sets [baseUrl].
  final String define;
  final String label;

  String get baseUrl => switch (this) {
    auth => kAuthBaseUrl,
    asset => kApiBaseUrl,
    media => kMediaBaseUrl,
    masterData => kMasterDataBaseUrl,
    dashboard => kDashboardBaseUrl,
  };

  String? get configProblem => switch (this) {
    auth => authConfigProblem,
    asset => apiConfigProblem,
    media => mediaConfigProblem,
    masterData => masterDataConfigProblem,
    dashboard => dashboardConfigProblem,
  };
}
