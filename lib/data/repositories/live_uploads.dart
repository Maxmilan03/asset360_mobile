import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/assets/assets_api.dart';
import 'package:asset360_mobile/data/api/media_api.dart';

/// Files for the live backend: check the type and size, upload to the Media service
/// (POST MEDIA_BASE_URL/api/media/upload, file + category), then record the URL with the Asset
/// service (POST /api/asset-images or /api/asset-documents).
///
/// Photos are compressed when picked: [pickPhoto] (photo_strip.dart) asks image_picker for at most
/// 1600 px and quality 80.
class AssetUploader {
  const AssetUploader(this.media, this.assets);

  final MediaApi media;
  final AssetsApi assets;

  static String fileNameOf(String path) => path.split(Platform.pathSeparator).last.split('/').last;

  /// Uploads one local file to the Media service. Throws [ApiException] (validation) before any
  /// request when the type or size is not accepted.
  Future<UploadedFile> upload(String path, {required String category, bool imageOnly = false, String? fileName}) async {
    final name = fileName ?? fileNameOf(path);
    final file = File(path);
    final size = await file.exists() ? await file.length() : null;
    final problem = AssetFileRules.check(name, size: size, imageOnly: imageOnly);
    if (problem != null) throw ApiException(ApiErrorKind.validation, problem, fieldErrors: {'file': problem});
    final up = await media.upload(fileName: name, category: category, filePath: path);
    if (up.storedUrl.isEmpty) {
      throw const ApiException(ApiErrorKind.unknown, 'The media service did not return a file URL.');
    }
    return UploadedFile(
      fileName: name,
      url: up.storedUrl,
      contentType: AssetFileRules.contentTypeOf(name),
      fileSize: size,
    );
  }

  /// Uploads [paths] (category "asset-images") and adds them to the asset's images.
  Future<List<AssetImageRecord>> addPhotos(
    String assetRegistrationId,
    List<String> paths, {
    required String imageType,
    String? description,
    String? remarks,
    List<String> tags = const [],
  }) async {
    final files = [for (final p in paths) await upload(p, category: AssetFileRules.imageCategory, imageOnly: true)];
    return assets.createImages(
      CreateAssetImagesRequest(
        assetRegistrationIds: [assetRegistrationId],
        images: [
          for (final f in files)
            AssetImageFile(fileName: f.fileName, fileUrl: f.url, contentType: f.contentType, fileSize: f.fileSize),
        ],
        imageType: imageType,
        description: description,
        remarks: remarks,
        tags: tags,
      ),
    );
  }

  /// Uploads [path] (category "asset-documents") and adds it to the asset's documents.
  Future<AssetDocumentRecord?> addDocument(
    String assetRegistrationId,
    String path, {
    required String documentName,
    required String documentType,
    required String lifecycleStage,
    required String version,
    DateTime? expiryDate,
    String? description,
    String? fileName,
  }) async {
    final f = await upload(path, category: AssetFileRules.documentCategory, fileName: fileName);
    final created = await assets.createDocument(
      CreateAssetDocumentRequest(
        assetRegistrationIds: [assetRegistrationId],
        documentName: documentName,
        documentType: documentType,
        lifecycleStage: lifecycleStage,
        version: version,
        expiryDate: expiryDate,
        description: description,
        fileName: f.fileName,
        fileUrl: f.url,
        contentType: f.contentType,
        fileSize: f.fileSize,
      ),
    );
    return created.firstOrNull;
  }
}

/// A file stored by the Media service; [url] is the server's URL as returned (store it as is;
/// display through `photoProvider` / [resolveMediaUrl]).
class UploadedFile {
  const UploadedFile({required this.fileName, required this.url, required this.contentType, this.fileSize});

  final String fileName, url, contentType;
  final int? fileSize;

  /// For the registration's Invoice & Documents / Attachments (AssetDocumentDto).
  AssetDocument toAssetDocument() => AssetDocument(
    fileName: fileName,
    url: url,
    contentType: contentType,
    fileSize: fileSize,
    uploadedAt: DateTime.now(),
  );
}

final assetUploaderProvider = Provider<AssetUploader>(
  (ref) => AssetUploader(ref.watch(mediaApiProvider), ref.watch(assetsApiProvider)),
);
