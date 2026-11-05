import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_upload.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

// ---------------------------------------------------------------- Action grid

/// One tile of an asset's action grid: icon, label, tone and what it opens.
/// A null onTap = the target module is switched off (tile stays visible, inert).
typedef AssetAction = (IconData icon, String label, TileTone tone, VoidCallback? onTap);

/// The actions shared by the Asset 360° grid and Scan → Asset Identified, each prefilled with [asset].
/// API mode: [liveAssetActions] for [registrationId] (else [Asset.id]); nothing touches mock data.
List<AssetAction> assetActions(BuildContext context, WidgetRef ref, Asset asset, {String? registrationId}) {
  if (apiMode) return liveAssetActions(context, ref, registrationId ?? asset.id);
  final plain = TileTone(AppColors.tileGrey, AppColors.text);
  final id = asset.id;
  return [
    (
      Icons.build_rounded,
      'Create Work Order',
      TileTone.sky,
      DemoGuard.push(context, Routes.createWorkOrder(assetId: id)),
    ),
    (
      Icons.assignment_outlined,
      'Create Inspection',
      TileTone.lavender,
      DemoGuard.push(context, Routes.withAsset(Routes.createInspection, id)),
    ),
    (
      Icons.swap_horiz_rounded,
      'Move Asset',
      TileTone.mint,
      DemoGuard.tap(DemoAction.assetMove, DemoGuard.push(context, Routes.withAsset(Routes.transferAsset, id))),
    ),
    (
      Icons.warning_rounded,
      'Report Issue',
      TileTone.peach,
      DemoGuard.push(context, Routes.withAsset(Routes.reportIssue, id)),
    ),
    (
      Icons.person_rounded,
      'Check Out',
      plain,
      DemoGuard.tap(DemoAction.assetCheckOut, () => showCheckOutSheet(context, ref, asset)),
    ),
    (Icons.location_on_rounded, 'View on Map', plain, DemoGuard.push(context, Routes.trackAsset(id))),
    (
      Icons.photo_camera_rounded,
      'Add Photo',
      plain,
      DemoGuard.tap(DemoAction.assetAddPhoto, () async {
        final path = await pickPhoto(context);
        if (path == null || !context.mounted) return;
        ref.read(assetsProvider.notifier).addPhoto(id, path);
        context.showSnack('Photo added (${asset.gallery.length + 1} in gallery)');
      }),
    ),
    (
      Icons.more_horiz_rounded,
      'More Actions',
      plain,
      DemoGuard.tap(DemoAction.assetMoreActions, () => openMoreActions(context, assetId: id)),
    ),
  ];
}

/// API mode grid for asset [registrationId]: Add Photo uploads to the Asset service, More Actions
/// opens the live More Actions; the other modules have no backend yet.
List<AssetAction> liveAssetActions(BuildContext context, WidgetRef ref, String registrationId) {
  final plain = TileTone(AppColors.tileGrey, AppColors.text);
  VoidCallback notYet(String feature) =>
      () => showNotAvailableYet(context, feature);
  return [
    (Icons.build_rounded, 'Create Work Order', TileTone.sky, notYet('Create Work Order')),
    (Icons.assignment_outlined, 'Create Inspection', TileTone.lavender, notYet('Create Inspection')),
    (Icons.swap_horiz_rounded, 'Move Asset', TileTone.mint, notYet('Move Asset')),
    (Icons.warning_rounded, 'Report Issue', TileTone.peach, notYet('Report Issue')),
    (Icons.person_rounded, 'Check Out', plain, notYet('Check Out')),
    (Icons.location_on_rounded, 'View on Map', plain, notYet('View on Map')),
    (Icons.photo_camera_rounded, 'Add Photo', plain, () => addLivePhoto(context, ref, registrationId)),
    (Icons.more_horiz_rounded, 'More Actions', plain, () => openMoreActions(context, assetId: registrationId)),
  ];
}

// ---------------------------------------------------------------- Health score

Future<void> showHealthScoreSheet(BuildContext context, WidgetRef ref, Asset a) {
  final wos = ref.read(workOrdersProvider).forAsset(a.id);
  final open = wos.where((w) => w.isActive).length;
  final overdue = wos.where((w) => w.isActive && DemoClock.isOverdue(w.dueAt)).length;
  final (band, color) = switch (a.healthScore) {
    >= 80 => ('Good', AppColors.green),
    >= 60 => ('Fair', AppColors.amber),
    _ => ('Poor', AppColors.red),
  };
  final lifeUsed = (a.ageYears / a.usefulLifeYears * 100).clamp(0, 100).round();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => sheetFrame(context, [
      Row(
        children: [
          ProgressRing(
            value: a.healthScore / 100,
            size: 64,
            strokeWidth: 7,
            color: color,
            center: Text('${a.healthScore}%', style: AppText.bodyStrong),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Score', style: AppText.sectionTitle),
                const SizedBox(height: 4),
                StatusChip(band, tone: ChipTone.forStatus(band == 'Poor' ? 'critical' : band)),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        'The health score (0–100%) combines the asset\'s condition, maintenance record, inspection results, '
        'IoT sensor readings and age. 80% and above is Good, 60–79% is Fair and below 60% needs attention.',
        style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.45, fontSize: 13),
      ),
      const SizedBox(height: 12),
      InfoRow(label: 'Condition', value: a.condition),
      InfoRow(label: 'Open work orders', value: '$open${overdue > 0 ? ' ($overdue overdue)' : ''}'),
      InfoRow(label: 'IoT status', value: a.iot == null ? 'No device' : (a.iot!.online ? 'Online' : 'Offline')),
      InfoRow(label: 'Life used', value: '$lifeUsed% of ${a.usefulLifeYears} years'),
      const SizedBox(height: 16),
      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
    ]),
  );
}

// ---------------------------------------------------------------- Check out

Future<void> showCheckOutSheet(BuildContext context, WidgetRef ref, Asset a) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CheckOutSheet(asset: a),
  );
}

class _CheckOutSheet extends ConsumerStatefulWidget {
  const _CheckOutSheet({required this.asset});

  final Asset asset;

  @override
  ConsumerState<_CheckOutSheet> createState() => _CheckOutSheetState();
}

class _CheckOutSheetState extends ConsumerState<_CheckOutSheet> {
  String? _custodian;
  late DateTime _due = DemoClock.today.add(const Duration(days: 7));
  final _remarks = TextEditingController();

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_custodian == null) {
      context.showSnack('Choose who is taking the asset');
      return;
    }
    final a = widget.asset;
    final place = MovePlace(a.location);
    ref
        .read(movementsProvider.notifier)
        .submit(
          assetId: a.id,
          type: MoveType.checkOut,
          from: place,
          to: place,
          newCustodian: _custodian,
          requiredDate: _due,
          reason: 'Check Out',
          remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
        );
    Navigator.pop(context);
    context.showSnack('${a.id} checked out to $_custodian until ${DemoClock.formatDate(_due)}');
  }

  @override
  Widget build(BuildContext context) {
    final options = custodianOptions(ref).where((c) => c != widget.asset.custodian && c != 'Unassigned').toList();
    return sheetFrame(context, [
      SheetTitle('Check Out ${widget.asset.id}', subtitle: 'Current custodian: ${widget.asset.custodian}'),
      DropdownButtonFormField<String>(
        initialValue: _custodian,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Check out to *'),
        items: [
          for (final c in options)
            DropdownMenuItem(
              value: c,
              child: Text(c, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => _custodian = v),
      ),
      const SizedBox(height: 12),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final d = await showDatePicker(
            useRootNavigator: false,
            context: context,
            initialDate: _due,
            firstDate: DemoClock.today,
            lastDate: DemoClock.today.add(const Duration(days: 365)),
          );
          if (d != null) setState(() => _due = d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Due back',
            suffixIcon: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
          ),
          child: Text(DemoClock.formatDate(_due), style: AppText.body),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _remarks,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Remarks', hintText: 'Purpose, condition at hand-over …'),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: _confirm, child: const Text('Confirm')),
          ),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Link IoT device

Future<void> showLinkIotSheet(BuildContext context, WidgetRef ref, Asset a) async {
  if (a.iot != null) {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('IoT device linked'),
        content: Text(
          '${a.id} already reports through ${a.iot!.model} (IMEI ${a.iot!.imei}). '
          'Open the IoT tab to see live telemetry.',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return;
  }
  final devices = ref.read(unlinkedIotDevicesProvider);
  if (devices.isEmpty) {
    context.showSnack('No unlinked IoT devices in the store');
    return;
  }
  final device = await showIotDevicePicker(context, devices, title: 'Link IoT Device to ${a.id}');
  if (device == null || !context.mounted) return;
  ref.read(assetsProvider.notifier).linkIot(a.id, device.copyWith(lastSeen: DemoClock.now));
  context.showSnack('${device.model} linked to ${a.id}');
}

/// Sheet listing store devices that are not paired yet. Returns the chosen one.
Future<IotDevice?> showIotDevicePicker(
  BuildContext context,
  List<IotDevice> devices, {
  String title = 'Link IoT Device',
}) {
  return showModalBottomSheet<IotDevice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SheetTitle(title, subtitle: '${devices.length} unlinked devices in the store'),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (_, i) => ListTile(
                  leading: IconSquare(icon: Icons.sensors_rounded, tone: TileTone.sky, size: 38),
                  title: Text(
                    '${devices[i].model} · ${devices[i].type}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  subtitle: Text('IMEI ${devices[i].imei}', style: AppText.caption),
                  onTap: () => Navigator.pop(context, devices[i]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- Duplicate

Future<void> duplicateAsset(BuildContext context, WidgetRef ref, Asset a) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Duplicate asset?',
    message: 'A copy of ${a.id} is created with a new ID, serial and tag. Photos and history are not copied.',
    confirmLabel: 'Duplicate',
  );
  if (!ok || !context.mounted) return;
  final id = ref.read(assetsProvider.notifier).duplicate(a.id);
  context.showSnack('Created $id from ${a.id}');
  context.push(Routes.assetDetail(id));
}

// ---------------------------------------------------------------- More actions

/// Opens More Actions on the current tab, with [assetId] selected (null = choose one there).
void openMoreActions(BuildContext context, {String? assetId}) =>
    context.push(Routes.moreActionsFrom(GoRouterState.of(context).uri.path, assetId: assetId));

/// Opens one More Actions screen (Print Asset Tag, Share …) for [assetId] on the current tab.
void openMoreAction(BuildContext context, MoreAction action, String assetId) =>
    context.push(Routes.moreActionFrom(GoRouterState.of(context).uri.path, action.slug, assetId));

/// Retire (confirm) → status "Retired": kept as the raw value, shown grey and counted as Other.
Future<void> retireAsset(BuildContext context, WidgetRef ref, Asset a) async {
  if (AssetStatus.bucketOf(a.status) == AssetStatus.other || a.status == AssetStatus.disposed) {
    context.showSnack('${a.id} is already out of service (${a.status})');
    return;
  }
  final ok = await showConfirmDialog(
    context,
    title: 'Retire ${a.id}?',
    message: 'The asset is taken out of service. Its status becomes Retired (counted as Other).',
    confirmLabel: 'Retire',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  ref.read(assetsProvider.notifier).setStatus(a.id, AssetStatus.retired, note: 'Retired from asset detail');
  context.showSnack('${a.id} retired');
}

/// Delete (confirm) → removed from the register, back to the list.
Future<void> deleteAsset(BuildContext context, WidgetRef ref, Asset a) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Delete ${a.id}?',
    message: 'The asset is removed from the register. This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.assets);
  }
  ref.read(assetsProvider.notifier).delete(a.id);
  messenger.showSnackBar(SnackBar(content: Text('${a.id} deleted')));
}
