import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/scan_record.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';

/// Scan History (right screen of design/05_scan_identify.jpg): every scan in the app, newest
/// first, filtered by kind. Swipe a row left to remove it; Clear All empties the list.
class ScanHistoryScreen extends ConsumerStatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  ConsumerState<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends ConsumerState<ScanHistoryScreen> {
  /// Null = All.
  ScanKind? _kind;

  Future<void> _clearAll() async {
    final count = ref.read(scanHistoryProvider).length;
    if (count == 0) {
      context.showSnack('Scan history is already empty');
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Clear scan history?',
      message: 'All $count scans are removed from this device. The assets themselves are not changed.',
      confirmLabel: 'Clear All',
      destructive: true,
    );
    if (!ok || !mounted) return;
    ref.read(scanHistoryProvider.notifier).clear();
    context.showSnack('Scan history cleared');
  }

  void _remove(ScanRecord s) {
    final notifier = ref.read(scanHistoryProvider.notifier);
    final index = ref.read(scanHistoryProvider).indexOf(s);
    notifier.remove(s.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          margin: context.snackMargin,
          content: Text('${s.refId} removed from history'),
          action: SnackBarAction(label: 'Undo', onPressed: () => notifier.restore(s, index)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(scanHistoryProvider);
    final rows = _kind == null ? all : all.ofKind(_kind!);
    final filters = <(ScanKind?, String)>[
      (null, 'All'),
      (ScanKind.asset, 'Assets (${all.count(ScanKind.asset)})'),
      (ScanKind.part, 'Parts (${all.count(ScanKind.part)})'),
      (ScanKind.location, 'Locations (${all.count(ScanKind.location)})'),
    ];
    return AppScaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: PageTitle(
              title: 'Scan History',
              subtitle: 'Recently scanned assets',
              trailing: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Clear All'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (kind, label) in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconFilterChip(
                      label: label,
                      selected: _kind == kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LoadingGate(
              rows: 5,
              card: false,
              child: rows.isEmpty
                  ? ListView(
                      padding: EdgeInsets.only(bottom: 24 + context.bottomInset),
                      children: [
                        EmptyState(
                          icon: Icons.qr_code_scanner_rounded,
                          title: all.isEmpty
                              ? 'No scans yet'
                              : 'No ${filters.firstWhere((f) => f.$1 == _kind).$2.split(' ').first.toLowerCase()} scanned',
                          message: 'Everything you scan with QR, NFC, RFID or BLE shows up here.',
                          actionLabel: 'Scan now',
                          onAction: () => context.pop(),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(bottom: 24 + context.bottomInset),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(indent: 92, height: 1),
                      itemBuilder: (context, i) => Dismissible(
                        key: ValueKey(rows[i].id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                        onDismissed: (_) => _remove(rows[i]),
                        child: _HistoryRow(record: rows[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One scan: photo, ID, name, location, time scanned and status, like the asset rows.
class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.record});

  final ScanRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = TagLabel(DemoClock.formatDateTime(record.at), icon: Icons.schedule_rounded);
    final time = Align(alignment: Alignment.centerLeft, child: at);
    switch (record.kind) {
      case ScanKind.asset:
        final a = ref.watch(assetsProvider).byCode(record.refId);
        if (a == null) return _missing(context);
        return AssetListTile(
          title: a.id,
          subtitle: a.name,
          location: a.location,
          imagePath: a.imagePath,
          fallbackIcon: assetIcon(a),
          details: [time],
          trailingTop: StatusChip(a.status),
          onTap: () => context.push(Routes.assetDetail(a.id)),
        );
      case ScanKind.part:
        final p = ref.watch(inventoryProvider).part(record.refId);
        if (p == null) return _missing(context);
        return AssetListTile(
          title: p.id,
          subtitle: p.name,
          location: p.warehouse,
          imagePath: p.imagePath,
          fallbackIcon: Icons.settings_outlined,
          details: [time],
          trailingTop: StatusChip(p.status),
          onTap: () => context.push(Routes.partDetail(p.id)),
        );
      case ScanKind.location:
        final (place, zone) = switch (record.refId.split(' – ')) {
          [final p, final z] => (p, z),
          _ => (record.refId, record.refId),
        };
        return AssetListTile(
          title: zone,
          subtitle: 'Location',
          location: place,
          fallbackIcon: Icons.place_outlined,
          details: [time],
          onTap: () => context.push(Routes.tracking),
        );
    }
  }

  Widget _missing(BuildContext context) => AssetListTile(
    title: record.refId,
    subtitle: 'No longer in the register',
    fallbackIcon: Icons.help_outline_rounded,
    details: [TagLabel(DemoClock.formatDateTime(record.at), icon: Icons.schedule_rounded)],
    showChevron: false,
    onTap: () => context.showSnack('${record.refId} was deleted from the register'),
  );
}
