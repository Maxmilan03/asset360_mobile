import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/media_auth.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';

/// Media service (MEDIA_BASE_URL): file uploads and the /uploads/... files they produce.
class MediaApi {
  const MediaApi(this.client);

  final ApiClient client;

  static const uploadPath = '/api/media/upload';

  /// POST /api/media/upload (multipart: `file` + `category`, both required; MediaEndpoints.cs).
  /// [category] is the folder under /uploads/ ("asset-images", "asset-documents").
  /// Give a local [filePath] or [bytes]. The server accepts only jpg, jpeg, png, webp and pdf.
  ///
  /// [MediaUpload.storedUrl] is the URL exactly as the server returned it (store that in records);
  /// [MediaUpload.url] is the same file made loadable on the phone ([resolveMediaUrl]).
  Future<MediaUpload> upload({
    required String fileName,
    required String category,
    String? filePath,
    List<int>? bytes,
  }) async {
    assert(filePath != null || bytes != null, 'pass filePath or bytes');
    final file = filePath != null
        ? await MultipartFile.fromFile(filePath, filename: fileName)
        : MultipartFile.fromBytes(bytes!, filename: fileName);
    final res = await client.post<Object?>(uploadPath, data: FormData.fromMap({'file': file, 'category': category}));
    return MediaUpload.fromJson(res.data);
  }
}

final mediaApiProvider = Provider<MediaApi>((ref) => MediaApi(ref.watch(mediaClientProvider)));

/// The upload reply: MediaUploadResponse `{"url": "http://localhost:5300/uploads/<category>/<file>"}`.
/// Read tolerantly (`url`, `fileUrl`, `filePath`, `path`, `location`, optionally inside `data`).
class MediaUpload {
  const MediaUpload({required this.url, this.storedUrl = '', this.raw});

  /// Absolute URL to load the file from ([resolveMediaUrl] applied); empty when the reply had none.
  final String url;

  /// The URL as the server returned it: what asset images / documents store.
  final String storedUrl;
  final Object? raw;

  factory MediaUpload.fromJson(Object? body) {
    String? pick(Object? m) {
      if (m is String && m.trim().isNotEmpty) return m.trim();
      if (m is! Map) return null;
      for (final k in const ['url', 'fileUrl', 'mediaUrl', 'filePath', 'path', 'location']) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return m['data'] == null ? null : pick(m['data']);
    }

    final url = pick(body);
    return MediaUpload(url: url == null ? '' : resolveMediaUrl(url), storedUrl: url ?? '', raw: body);
  }
}

/// A media URL from the server, made loadable on the phone:
/// - host localhost / 127.0.0.1 (the server's own view) → MEDIA_BASE_URL + the same path and query;
/// - a relative path ("/uploads/a.jpg") → MEDIA_BASE_URL + path;
/// - anything else is returned unchanged.
/// [mediaBase] defaults to [kMediaBaseUrl] (tests pass their own).
String resolveMediaUrl(String url, {String? mediaBase}) {
  final base = Uri.tryParse(mediaBase ?? kMediaBaseUrl);
  final u = Uri.tryParse(url.trim());
  if (u == null || base == null || !base.hasScheme) return url;
  final local = u.hasScheme && const {'localhost', '127.0.0.1'}.contains(u.host.toLowerCase());
  if (u.hasScheme && !local) return url;
  final path = u.path.startsWith('/') ? u.path : '/${u.path}';
  return base
      .replace(path: path, query: u.hasQuery ? u.query : null, fragment: u.hasFragment ? u.fragment : null)
      .toString();
}

/// Headers for loading a media file (e.g. `Image.network(url, headers: ...)`): see [MediaAuth.headers].
final mediaHeadersProvider = Provider<Map<String, String>>((ref) {
  ref.watch(authProvider);
  return MediaAuth.headers;
});
