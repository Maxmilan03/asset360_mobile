import 'package:asset360_mobile/data/api/api_config.dart';

/// The Bearer token for loading media files (/uploads/...). Image providers live outside Riverpod,
/// so AuthNotifier keeps [token] up to date (signed-in user's access token, else DEV_TOKEN).
abstract final class MediaAuth {
  static String? token;

  /// Headers for a media request: Authorization when there is a token (harmless if the Media
  /// service does not need it), otherwise none.
  static Map<String, String> get headers {
    final t = token ?? (kDevToken.isEmpty ? null : kDevToken);
    return t == null || t.isEmpty ? const {} : {'Authorization': 'Bearer $t'};
  }
}
