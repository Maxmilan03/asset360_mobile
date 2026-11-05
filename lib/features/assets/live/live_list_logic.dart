import 'package:intl/intl.dart';

import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';

/// Pure helpers of the live Assets list (apiMode = true). The server does the searching, filtering
/// and sorting of the list; these only cover Favorites, which are fetched one by one
/// (GET /api/asset-registrations/{id}) because the backend has no favorites query.

final _count = NumberFormat.decimalPattern('en_US');

String formatLiveCount(num n) => _count.format(n);

bool _same(String? value, String? wanted) =>
    wanted == null || (value != null && value.trim().toLowerCase() == wanted.trim().toLowerCase());

/// Same rules as the server's list: search on name, tag, serial, barcode, RFID, NFC and registration
/// ID (contains, any case); every other filter is an exact match; locationId matches at or below.
bool registrationMatches(AssetRegistration r, AssetListQuery q) {
  final b = r.basicInformation, c = r.classification;
  final l = r.locationAssignment.location, a = r.locationAssignment.assignment;
  final s = q.search?.trim().toLowerCase() ?? '';
  if (s.isNotEmpty) {
    final fields = [b.assetName, b.assetTag, b.serialNumber, b.barcode, b.rfidTagId, b.nfcUid, r.assetRegistrationId];
    if (!fields.any((f) => f != null && f.toLowerCase().contains(s))) return false;
  }
  if (q.locationId != null &&
      ![l.countryId, l.siteId, l.buildingId, l.floorId, l.zoneId, l.roomId].contains(q.locationId)) {
    return false;
  }
  return _same(c.category, q.category) &&
      _same(c.assetType, q.assetType) &&
      _same(b.status, q.status) &&
      _same(c.department, q.department) &&
      _same(a.assignedToUserId, q.custodianUserId) &&
      _same(c.criticality ?? b.criticality, q.criticality) &&
      _same(r.purchaseWarranty.purchase.manufacturer ?? b.manufacturer, q.manufacturer) &&
      _same(b.condition, q.condition);
}

/// The status cards for a set of assets (other statuses count as Other).
AssetStatusSummary summarize(Iterable<AssetListItem> items) {
  var active = 0, maintenance = 0, repair = 0, disposed = 0, other = 0;
  for (final i in items) {
    switch (AssetStatus.bucketOf(i.status ?? '')) {
      case AssetStatus.active:
        active++;
      case AssetStatus.underMaintenance:
        maintenance++;
      case AssetStatus.inRepair:
        repair++;
      case AssetStatus.disposed:
        disposed++;
      default:
        other++;
    }
  }
  return AssetStatusSummary(
    total: active + maintenance + repair + disposed + other,
    active: active,
    underMaintenance: maintenance,
    inRepair: repair,
    disposed: disposed,
    other: other,
  );
}

/// Sorts like the server: [AssetSortKeys] key (default createdAt, newest first), empty values last.
int Function(AssetListItem, AssetListItem) itemComparator(String? sortBy, String? sortDirection) {
  final key = sortBy ?? 'createdAt';
  final desc = (sortDirection ?? (sortBy == null ? 'desc' : 'asc')) == 'desc';
  Comparable<dynamic>? value(AssetListItem i) => switch (key) {
    'assetName' => i.assetName?.toLowerCase(),
    'assetTag' => i.assetTag?.toLowerCase(),
    'category' => i.category?.toLowerCase(),
    'assetType' => i.assetType?.toLowerCase(),
    'location' => i.locationPath?.toLowerCase(),
    'custodian' => i.custodianName?.toLowerCase(),
    'status' => i.status?.toLowerCase(),
    'criticality' => i.criticality?.toLowerCase(),
    'nextMaintenance' => i.nextMaintenanceDate,
    _ => i.createdAt,
  };
  return (x, y) {
    final a = value(x), b = value(y);
    if (a == null || b == null) return a == null ? (b == null ? 0 : 1) : -1;
    final r = a.compareTo(b);
    return desc ? -r : r;
  };
}

/// "UAE > Main Site > Block A", from the path or the location names.
String? locationLine(AssetListItem i) {
  final path = i.locationPath?.trim();
  if (path != null && path.isNotEmpty) return path;
  final parts = [i.siteName, i.buildingName, i.floorName, i.zoneName, i.roomName].nonNulls.where((p) => p.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' > ');
}
