import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/scans_mock.dart';
import '../models/scan_record.dart';
import 'repo_utils.dart';

class ScanHistoryNotifier extends Notifier<List<ScanRecord>> {
  @override
  List<ScanRecord> build() => seedScans();

  /// Every scan in the app goes to the top of the history.
  void add(ScanKind kind, String refId, {String method = 'QR'}) => state = [
    ScanRecord(
      id: nextId('SCN-', state.map((s) => s.id), width: 3),
      kind: kind,
      refId: refId,
      at: DemoClock.now,
      method: method,
    ),
    ...state,
  ];

  void remove(String id) => state = state.where((s) => s.id != id).toList();
  void clear() => state = const [];
}

final scanHistoryProvider = NotifierProvider<ScanHistoryNotifier, List<ScanRecord>>(ScanHistoryNotifier.new);
