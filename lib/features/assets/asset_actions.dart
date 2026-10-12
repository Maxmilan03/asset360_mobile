import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';

// ---------------------------------------------------------------- Action grid

/// One tile of an asset's action grid: icon, label, tone and what it opens.
/// A null onTap = the target module is switched off (tile stays visible, inert).
typedef AssetAction = (IconData icon, String label, TileTone tone, VoidCallback? onTap);

/// The actions shared by the Asset 360° grid and Scan → Asset Identified, each prefilled with [asset].
List<AssetAction> assetActions(BuildContext context, WidgetRef ref, Asset asset) {
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
      DemoGuard.tap(DemoAction.assetMoreActions, () => showMoreActionsSheet(context, ref, asset)),
    ),
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

// ---------------------------------------------------------------- Transfer ownership

Future<void> showTransferOwnershipSheet(BuildContext context, WidgetRef ref, Asset a) async {
  final options = custodianOptions(ref).where((c) => c != a.custodian).toList();
  final chosen = await showModalBottomSheet<String>(
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
              child: SheetTitle('Transfer Ownership', subtitle: 'Current custodian: ${a.custodian}'),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) => ListTile(
                  leading: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                  title: Text(options[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
                  onTap: () => Navigator.pop(context, options[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;
  ref
      .read(movementsProvider.notifier)
      .submit(
        assetId: a.id,
        type: MoveType.assign,
        from: MovePlace(a.location),
        to: MovePlace(a.location),
        newCustodian: chosen,
        reason: 'Transfer Ownership',
      );
  context.showSnack('Custodian changed to $chosen');
}

// ---------------------------------------------------------------- Print tag

Future<void> showPrintTagSheet(BuildContext context, Asset a) {
  const printers = ['Zebra ZD421 – Store', 'Zebra ZT411 – Main Plant', 'Brother QL-820 – Office'];
  var printer = printers.first;
  var copies = 1;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => sheetFrame(context, [
        const SheetTitle('Print Asset Tag', subtitle: 'QR / barcode label for the asset'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Image.asset('assets/images/logo_on_light.webp', width: 36, height: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.id, style: AppText.cardTitle),
                    Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                    const SizedBox(height: 6),
                    Code39Barcode(data: a.barcode ?? a.id, height: 36),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              QrCode(data: a.id, size: 72),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: printer,
          decoration: const InputDecoration(labelText: 'Printer'),
          items: [for (final p in printers) DropdownMenuItem(value: p, child: Text(p))],
          onChanged: (v) => setState(() => printer = v ?? printer),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text('Copies', style: AppText.bodyStrong)),
            IconButton(
              tooltip: 'Fewer',
              onPressed: copies > 1 ? () => setState(() => copies--) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text('$copies', style: AppText.bodyStrong),
            IconButton(
              tooltip: 'More',
              onPressed: copies < 10 ? () => setState(() => copies++) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.showSnack('$copies tag${copies > 1 ? 's' : ''} for ${a.id} sent to $printer (demo)');
          },
          icon: const Icon(Icons.print_rounded),
          label: const Text('Print'),
        ),
      ]),
    ),
  );
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

// ---------------------------------------------------------------- Duplicate / share

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

Future<void> shareAsset(BuildContext context, Asset a) async {
  await Clipboard.setData(
    ClipboardData(
      text: '${a.id} – ${a.name}\n${a.location}\nStatus: ${a.status}\nhttps://asset360.purpleiq.ae/assets/${a.id}',
    ),
  );
  if (context.mounted) context.showSnack('Asset link copied. The share sheet would open here (demo).');
}

// ---------------------------------------------------------------- More actions

Future<void> showMoreActionsSheet(BuildContext context, WidgetRef ref, Asset a) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('More Actions', style: AppText.sectionTitle),
          ),
          for (final (key, icon, label) in const [
            ('print', Icons.qr_code_2_rounded, 'Print QR Tag'),
            ('owner', Icons.swap_horizontal_circle_outlined, 'Transfer Ownership'),
            ('iot', Icons.sensors_rounded, 'Link IoT Device'),
            ('clone', Icons.copy_all_rounded, 'Clone'),
          ])
            ListTile(
              leading: Icon(icon, color: AppColors.primary),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, key),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'print':
      await showPrintTagSheet(context, a);
    case 'owner':
      await showTransferOwnershipSheet(context, ref, a);
    case 'iot':
      await showLinkIotSheet(context, ref, a);
    case 'clone':
      await duplicateAsset(context, ref, a);
  }
}

/// Retire (confirm) → status Retired.
Future<void> retireAsset(BuildContext context, WidgetRef ref, Asset a) async {
  if (a.status == AssetStatus.retired) {
    context.showSnack('${a.id} is already retired');
    return;
  }
  final ok = await showConfirmDialog(
    context,
    title: 'Retire ${a.id}?',
    message: 'The asset is taken out of service and its status changes to Retired.',
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
