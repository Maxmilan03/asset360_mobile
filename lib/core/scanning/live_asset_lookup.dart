import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/scanning/scan_event.dart';
import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/assets/assets_api.dart';
import 'package:asset360_mobile/data/api/assets/json_read.dart';

/// API mode: what the Asset service says about a scanned code.
enum LiveLookupStatus { found, notFound, ambiguous }

class LiveLookup {
  const LiveLookup._(this.status, {this.id, this.label, this.matchedBy, this.message, this.ids = const []});

  const LiveLookup.found({required String id, required String label, String? matchedBy})
    : this._(LiveLookupStatus.found, id: id, label: label, matchedBy: matchedBy);

  static const notFound = LiveLookup._(LiveLookupStatus.notFound);

  const LiveLookup.ambiguous(String message, List<String> ids)
    : this._(LiveLookupStatus.ambiguous, message: message, ids: ids);

  final LiveLookupStatus status;

  /// assetRegistrationId of the match.
  final String? id;

  /// "AR000001 – Diesel Generator 500 kVA".
  final String? label;

  /// assetTag | barcode | rfid | nfc | assetRegistrationId (lookup), or "search" (fallback).
  final String? matchedBy;

  /// The server's 409 message.
  final String? message;

  /// The 409's assetRegistrationIds.
  final List<String> ids;
}

/// Resolves scanned codes against the Asset service:
/// GET /api/asset-registrations/lookup?code=&type= (exact, case-insensitive: assetTag, barcode,
/// rfidTagId, nfcUid, assetRegistrationId). When that endpoint is missing (an older server: 404
/// WITHOUT "No asset matches…", or 405) it falls back to GET ?search=code with an exact match on
/// assetTag / assetRegistrationId, then the detail of each candidate for barcode / rfidTagId / nfcUid.
/// Network and server errors are thrown as [ApiException].
class LiveAssetLookup {
  LiveAssetLookup(this.client) : api = AssetsApi(client);

  final ApiClient client;
  final AssetsApi api;

  /// Start of the server's "nothing matches" 404 message (AssetRegistrationEndpoints.cs).
  static const notFoundMessage = 'No asset matches the scanned code';

  /// Most fallback candidates whose detail is fetched to compare barcode / RFID / NFC.
  static const fallbackDetails = 5;

  static String labelOf(String id, String? name) => name == null || name.trim().isEmpty ? id : '$id – $name';

  /// The (code, type) pairs tried for [e], in order.
  static List<(String, String?)> attemptsFor(ScanEvent e) {
    final value = e.value.trim();
    final out = <(String, String?)>[];
    void add(String code, String? type) {
      if (code.isNotEmpty && !out.contains((code, type))) out.add((code, type));
    }

    if (e.isNfc) {
      // An NDEF text / URI record may carry the asset tag; the chip's UID is matched as nfcUid,
      // both as read ("04:A2:…") and compact ("04A2…").
      if (e.nfcUid == null || value != nfcTagKey(e.nfcUid!)) add(value, null);
      if (e.nfcUid case final uid?) {
        add(uid.replaceAll(':', ''), LookupCodeType.nfc);
        add(uid, LookupCodeType.nfc);
      }
      return out;
    }
    final type = switch (e.format.toLowerCase()) {
      'rfid' => LookupCodeType.rfid,
      // Retail barcodes are never asset tags.
      'ean8' || 'ean13' || 'upca' || 'upce' => LookupCodeType.barcode,
      _ => null,
    };
    add(value, type);
    return out;
  }

  /// Tries every code of [e] until one is found or ambiguous.
  Future<LiveLookup> findEvent(ScanEvent e) async {
    for (final (code, type) in attemptsFor(e)) {
      final r = await find(code, type: type);
      if (r.status != LiveLookupStatus.notFound) return r;
    }
    return LiveLookup.notFound;
  }

  Future<LiveLookup> find(String code, {String? type}) async {
    final c = code.trim();
    if (c.isEmpty) return LiveLookup.notFound;
    final problem = client.checkConfig ? client.service.configProblem : null;
    if (problem != null) throw ApiException(ApiErrorKind.notConfigured, problem);
    final Response<Object?> res;
    try {
      res = await client.dio.get<Object?>(
        '${AssetsApi.registrations}/lookup',
        queryParameters: {'code': c, 'type': ?type},
        options: Options(validateStatus: (s) => s != null && (s < 300 || s == 404 || s == 405 || s == 409)),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    final body = jMap(res.data);
    switch (res.statusCode) {
      case 409:
        return LiveLookup.ambiguous(
          jStr(body['message']) ?? "The scanned code '$c' matches more than one asset.",
          jStrings(body['assetRegistrationIds']),
        );
      case 404 when (jStr(body['message']) ?? '').toLowerCase().contains(notFoundMessage.toLowerCase()):
        return LiveLookup.notFound;
      case 404 || 405:
        return _fallback(c, type);
    }
    final r = AssetLookupResult.fromJson(res.data);
    return LiveLookup.found(
      id: r.asset.assetRegistrationId,
      label: labelOf(r.asset.assetRegistrationId, r.asset.basicInformation.assetName),
      matchedBy: r.matchedBy,
    );
  }

  /// No /lookup on this server: search, then exact matches only.
  Future<LiveLookup> _fallback(String code, String? type) async {
    final u = code.toUpperCase();
    bool same(String? v) => v != null && v.trim().toUpperCase() == u;
    final page = await api.list(AssetListQuery(search: code), pageSize: AssetListQuery.pageSize);
    if (type == null || type == LookupCodeType.assetTag || type == LookupCodeType.assetRegistrationId) {
      final hits = {
        for (final i in page.items)
          if (same(i.assetTag) || same(i.assetRegistrationId)) i.assetRegistrationId: i,
      };
      if (hits.length > 1) {
        return LiveLookup.ambiguous("The scanned code '$code' matches more than one asset.", hits.keys.toList());
      }
      if (hits.values.firstOrNull case final i?) {
        return LiveLookup.found(
          id: i.assetRegistrationId,
          label: labelOf(i.assetRegistrationId, i.assetName),
          matchedBy: 'search',
        );
      }
    }
    final found = <AssetRegistration>[];
    for (final i in page.items.take(fallbackDetails)) {
      final r = await api.get(i.assetRegistrationId);
      final b = r.basicInformation;
      final match = switch (type) {
        LookupCodeType.barcode || LookupCodeType.qr => same(b.barcode),
        LookupCodeType.rfid => same(b.rfidTagId),
        LookupCodeType.nfc => same(b.nfcUid),
        _ => same(b.barcode) || same(b.rfidTagId) || same(b.nfcUid),
      };
      if (match) found.add(r);
    }
    if (found.length > 1) {
      return LiveLookup.ambiguous("The scanned code '$code' matches more than one asset.", [
        for (final r in found) r.assetRegistrationId,
      ]);
    }
    if (found.firstOrNull case final r?) {
      return LiveLookup.found(
        id: r.assetRegistrationId,
        label: labelOf(r.assetRegistrationId, r.basicInformation.assetName),
        matchedBy: 'search',
      );
    }
    return LiveLookup.notFound;
  }
}

final liveAssetLookupProvider = Provider<LiveAssetLookup>((ref) => LiveAssetLookup(ref.watch(apiClientProvider)));
