import 'package:asset360_mobile/core/csv.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';

/// One CSV data row after validation: an [asset] when valid, otherwise the [errors].
class BulkRow {
  const BulkRow({required this.line, required this.id, required this.name, this.asset, this.errors = const []});

  final int line;
  final String id;
  final String name;
  final Asset? asset;
  final List<String> errors;

  bool get valid => errors.isEmpty;
}

const _required = ['asset_id', 'name', 'category', 'type', 'site', 'location'];

/// Thrown when the header row lacks required columns.
class BulkCsvException implements Exception {
  const BulkCsvException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Parses and validates a Bulk Registration CSV. [ownerOf] returns the asset ID that
/// already uses a value (ID / tag / barcode) in the register.
List<BulkRow> validateBulkCsv(String text, String? Function(String value) ownerOf) {
  final rows = parseCsv(text);
  if (rows.isEmpty) throw const BulkCsvException('The file is empty');
  final header = [for (final h in rows.first) h.toLowerCase().replaceAll(' ', '_')];
  final missing = _required.where((c) => !header.contains(c)).toList();
  if (missing.isNotEmpty) throw BulkCsvException('Missing columns: ${missing.join(', ')}');

  final seen = <String, int>{}; // value → CSV line, for duplicates inside the file
  final out = <BulkRow>[];
  for (var r = 1; r < rows.length; r++) {
    final cells = rows[r];
    String v(String col) {
      final i = header.indexOf(col);
      return i < 0 || i >= cells.length ? '' : cells[i];
    }

    final line = r + 1;
    final errors = <String>[];
    final id = v('asset_id').toUpperCase();
    for (final col in _required) {
      if (v(col).isEmpty) errors.add('$col is required');
    }
    if (id.isNotEmpty && !RegExp(r'^[A-Z0-9][A-Z0-9-]{2,19}$').hasMatch(id)) errors.add('invalid asset_id');
    for (final (col, value) in [('asset_id', id), ('tag_id', v('tag_id')), ('barcode', v('barcode'))]) {
      if (value.isEmpty) continue;
      final key = value.toUpperCase();
      final owner = ownerOf(key);
      if (owner != null) {
        errors.add('$col already used by $owner');
      } else if (seen.containsKey(key) && !(col == 'barcode' && key == id)) {
        errors.add('$col repeats line ${seen[key]}');
      }
      seen.putIfAbsent(key, () => line);
    }
    final status = v('status').isEmpty ? AssetStatus.active : v('status');
    if (!AssetStatus.all.contains(status)) errors.add('unknown status "$status"');
    final criticality = v('criticality').isEmpty ? 'Medium' : v('criticality');
    if (!AssetOptions.criticalityLevels.contains(criticality)) errors.add('unknown criticality "$criticality"');
    if (v('site').isNotEmpty && !locationTree.containsKey(v('site'))) errors.add('unknown site "${v('site')}"');
    final purchase = v('purchase_date').isEmpty ? DemoClock.today : DateTime.tryParse(v('purchase_date'));
    if (purchase == null) errors.add('purchase_date must be YYYY-MM-DD');
    final warranty = v('warranty_expiry').isEmpty ? null : DateTime.tryParse(v('warranty_expiry'));
    if (v('warranty_expiry').isNotEmpty && warranty == null) errors.add('warranty_expiry must be YYYY-MM-DD');
    final cost = v('purchase_cost').isEmpty ? 0.0 : double.tryParse(v('purchase_cost').replaceAll(',', ''));
    if (cost == null || cost < 0) errors.add('purchase_cost must be a number');

    out.add(
      BulkRow(
        line: line,
        id: id,
        name: v('name'),
        errors: errors,
        asset: errors.isNotEmpty
            ? null
            : Asset(
                id: id,
                name: v('name'),
                type: v('type'),
                category: v('category'),
                manufacturer: v('manufacturer').isEmpty ? '—' : v('manufacturer'),
                model: v('model').isEmpty ? null : v('model'),
                serialNo: v('serial_no').isEmpty ? null : v('serial_no'),
                tagId: v('tag_id').isEmpty ? null : v('tag_id').toUpperCase(),
                barcode: v('barcode').isEmpty ? id : v('barcode').toUpperCase(),
                site: v('site'),
                location: v('location'),
                custodian: v('custodian').isEmpty ? 'Unassigned' : v('custodian'),
                status: status,
                criticality: criticality,
                healthScore: 100,
                purchaseDate: purchase!,
                warrantyExpiry: warranty ?? DateTime(purchase.year + 1, purchase.month, purchase.day),
                purchaseCost: cost!,
                salvageValue: (cost * .1).roundToDouble(),
              ),
      ),
    );
  }
  return out;
}
