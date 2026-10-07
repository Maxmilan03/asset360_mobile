import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/wip_mock.dart';
import '../../data/models/wip.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/wip_repository.dart';
import '../common/scan_capture.dart';
import 'wip_widgets.dart';

enum UnitTab {
  overview('Overview'),
  flow('Process Flow'),
  location('Location History'),
  documents('Documents');

  const UnitTab(this.label);
  final String label;
}

/// WIP Tracking (middle screen of design/13_wip_operations.jpg) for one unit serial.
class WipUnitScreen extends ConsumerStatefulWidget {
  const WipUnitScreen({super.key, required this.serial});

  final String serial;

  @override
  ConsumerState<WipUnitScreen> createState() => _WipUnitScreenState();
}

class _WipUnitScreenState extends ConsumerState<WipUnitScreen> {
  UnitTab _tab = UnitTab.overview;

  Future<void> _scanStation(ProductionOrder o) async {
    final code = await showScanCapture(
      context,
      title: 'Scan Station Tag',
      suggestions: [
        '$stationTagPrefix${o.currentStation}',
        for (final op in o.operations.take(2)) '$stationTagPrefix${op.location}',
      ],
    );
    if (code == null || !mounted) return;
    final station = stationFromTag(code);
    if (station.isEmpty) return;
    ref.read(wipProvider.notifier).recordScan(o.id, station);
    context.showSnack(
      station == o.currentStation
          ? 'Scan recorded at $station'
          : '${o.unitSerial} scanned at $station (expected ${o.currentStation})',
    );
  }

  Future<void> _editCurrent(ProductionOrder o, int i) async {
    final op = o.operations[i];
    final people = ref.read(peopleProvider);
    String? operatorId = op.operatorId;
    final expected = TextEditingController(text: '${op.expectedMins}');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setS) => sheetFrame(sheet, [
          SheetTitle('Edit ${op.name}', subtitle: op.location),
          DropdownButtonFormField<String>(
            initialValue: operatorId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Operator'),
            items: [for (final p in people) DropdownMenuItem(value: p.id, child: Text(p.labelWithRole))],
            onChanged: (v) => setS(() => operatorId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: expected,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Expected duration', suffixText: 'minutes'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Save')),
        ]),
      ),
    );
    final mins = int.tryParse(expected.text.trim());
    expected.dispose();
    if (saved != true || !mounted) return;
    final n = ref.read(wipProvider.notifier);
    if (operatorId != null && operatorId != op.operatorId) n.setOperator(o.id, i, operatorId!);
    if (mins != null && mins > 0 && mins != op.expectedMins) n.setExpected(o.id, i, mins);
    context.showSnack('${op.name} updated');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final o = ref.watch(wipProvider).byUnit(widget.serial);
    if (o == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Unit not found', message: widget.serial),
      );
    }
    final active = o.isActive;
    return AppScaffold(
      bottomActions: !active
          ? null
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => moveToNextFlow(context, ref, o),
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Move to Next Operation')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => reportProductionIssue(context, o),
                    icon: const Icon(Icons.warning_rounded, size: 18),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Report Issue')),
                  ),
                ),
              ],
            ),
      body: ListView(
        padding: active ? const EdgeInsets.fromLTRB(16, 16, 16, 24) : context.pagePadding,
        children: [
          const PageTitle(
            title: 'WIP Tracking',
            subtitle: 'Track real-time position and process status',
            help: 'Move the unit to the next operation, scan station tags to record where it is, and report problems.',
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => context.push(Routes.productionOrder(o.id)),
            child: Row(
              children: [
                AssetThumb(imagePath: o.imagePath, fallbackIcon: Icons.memory_rounded, size: 84),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              o.unitSerial,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.cardTitle,
                            ),
                          ),
                          Flexible(child: StatusChip(o.status, tone: moTone(o.status))),
                        ],
                      ),
                      InfoRow(label: 'Production Order', value: o.id, labelWidth: 96),
                      InfoRow(label: 'Product', value: o.product, labelWidth: 96),
                      InfoRow(label: 'Batch No.', value: o.batch ?? '—', labelWidth: 96),
                      InfoRow(label: 'Current Station', value: o.currentStation, labelWidth: 96),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SegmentTabs(
            tabs: [for (final t in UnitTab.values) SegmentTab(t.label)],
            selected: _tab.index,
            onChanged: (i) => setState(() => _tab = UnitTab.values[i]),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            UnitTab.overview => _overview(o),
            UnitTab.flow => _flow(o),
            UnitTab.location => LoadingGate(key: const ValueKey('locations'), rows: 3, child: _locations(o)),
            UnitTab.documents => LoadingGate(key: const ValueKey('documents'), rows: 2, child: _documents(o)),
          },
        ],
      ),
    );
  }

  Widget _overview(ProductionOrder o) {
    final i = o.currentOpIndex;
    final op = i < 0 ? null : o.operations[i];
    final operator = ref.watch(personByIdProvider(op?.operatorId));
    final scan = o.lastScan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(child: StationProgress(operations: o.operations, size: 26, showTimes: true)),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Current Operation',
          actionLabel: op == null || !o.isActive ? null : 'Edit',
          actionIcon: Icons.edit_outlined,
          onAction: () => _editCurrent(o, i),
          child: op == null
              ? Text(o.allOpsDone ? 'All operations completed' : 'No operation running', style: AppText.secondary)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          InfoRow(label: 'Operation', value: op.name, labelWidth: 96),
                          InfoRow(
                            label: 'Start Time',
                            value: op.startedAt == null ? '—' : DemoClock.formatDateTime(op.startedAt!),
                            labelWidth: 96,
                          ),
                          InkWell(
                            onTap: operator == null ? null : () => context.push(Routes.adminUser(operator.id)),
                            child: InfoRow(
                              label: 'Operator',
                              value: operator?.name ?? '—',
                              valueColor: AppColors.primary,
                              labelWidth: 96,
                            ),
                          ),
                          InfoRow(
                            label: 'Status',
                            value: op.status,
                            valueColor: op.status == OpStatus.failed ? AppColors.red : AppColors.primary,
                            labelWidth: 96,
                          ),
                          InfoRow(label: 'Expected', value: '${op.expectedMins} minutes', labelWidth: 96),
                          InfoRow(
                            label: 'Actual',
                            value: '${liveMinutes(op)} minutes',
                            valueColor: liveMinutes(op) > op.expectedMins ? AppColors.red : null,
                            labelWidth: 96,
                          ),
                        ],
                      ),
                    ),
                    if (o.photos.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image(image: photoProvider(o.photos.last), width: 96, height: 96, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: IconButton.filledTonal(
                              tooltip: 'Zoom photo',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => openPhotoViewer(context, o.photos, initialIndex: o.photos.length - 1),
                              icon: const Icon(Icons.zoom_in_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Location Details',
          actionLabel: 'View on Map',
          actionIcon: Icons.location_on_outlined,
          onAction: () => context.push(Routes.tracking),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconLine(icon: Icons.location_on_rounded, text: o.locationPath, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ScanSuffix(onTap: () => _scanStation(o), tooltip: 'Scan station tag'),
                ],
              ),
              const SizedBox(height: 8),
              InfoRow(
                label: 'Last Scanned',
                value: scan == null ? '—' : DemoClock.formatDateTime(scan.at),
                labelWidth: 96,
              ),
              InfoRow(label: 'Scanned By', value: scan?.by ?? '—', labelWidth: 96),
              InfoRow(label: 'Scan Device', value: scan?.device ?? '—', labelWidth: 96),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: PhotoStrip(
            title: 'Photos',
            photos: o.photos,
            onAdd: (p) {
              ref.read(wipProvider.notifier).addPhoto(o.id, p);
              context.showSnack('Photo added to ${o.unitSerial}');
            },
          ),
        ),
      ],
    );
  }

  Widget _flow(ProductionOrder o) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < o.operations.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      SizedBox(width: 26, child: StationProgress(operations: [o.operations[i]], size: 22)),
                      if (i < o.operations.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: o.operations[i].isDone ? AppColors.primary : AppColors.border,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(o.operations[i].name, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                              ),
                              StatusChip(o.operations[i].status),
                            ],
                          ),
                          Text(o.operations[i].location, style: AppText.caption),
                          const SizedBox(height: 2),
                          Text(
                            'Standard ${o.operations[i].expectedMins} min · Actual '
                            '${o.operations[i].status == OpStatus.pending ? '—' : '${liveMinutes(o.operations[i])} min'}',
                            style: AppText.caption.copyWith(
                              color: liveMinutes(o.operations[i]) > o.operations[i].expectedMins
                                  ? AppColors.red
                                  : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _locations(ProductionOrder o) {
    if (o.scans.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.location_off_outlined,
          title: 'No scans yet',
          message: 'Scan a station tag to record where the unit is.',
          actionLabel: 'Scan station tag',
          onAction: () => _scanStation(o),
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final s in o.scans)
            ListTile(
              leading: Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
              title: Text(s.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
              subtitle: Text('${DemoClock.formatDateTime(s.at)} · ${s.by} · ${s.device}', style: AppText.caption),
            ),
        ],
      ),
    );
  }

  Widget _documents(ProductionOrder o) {
    if (o.documents.isEmpty) {
      return const AppCard(
        child: EmptyState(icon: Icons.description_outlined, title: 'No work instructions'),
      );
    }
    return Column(
      children: [
        for (final d in o.documents)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AttachmentTile(attachment: d),
          ),
      ],
    );
  }
}
