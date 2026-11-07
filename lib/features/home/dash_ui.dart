import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/assets/assets_api.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';

/// Shared pieces of the API-mode Home dashboard and its drill-downs (Dashboard service data).

final dashNumber = NumberFormat('#,###');

/// The Home site filter as text ("All sites" / the site name).
String dashSiteLabel(String? site) => site ?? 'All sites';

/// "83.3" → "83%", "0" → "0%".
String dashPct(double v) => '${v.round()}%';

/// One section's async body: shimmer while loading, the error with Retry, a short empty message
/// when [isEmpty] says there is nothing to show, else [builder].
class DashSection<T> extends ConsumerWidget {
  const DashSection({
    super.key,
    required this.provider,
    required this.onRetry,
    required this.builder,
    this.isEmpty,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing to show',
    this.emptyMessage,
    this.rows = 2,
  });

  final ProviderListenable<AsyncValue<T>> provider;
  final void Function(WidgetRef ref) onRetry;
  final Widget Function(T value) builder;
  final bool Function(T value)? isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final int rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(provider);
    if (v.hasError && !v.isLoading) return LoadErrorState(error: v.error!, onRetry: () => onRetry(ref));
    if (!v.hasValue || v.isLoading) return ListSkeleton(rows: rows, card: false);
    final value = v.requireValue;
    if (isEmpty?.call(value) ?? false) {
      return DashEmpty(icon: emptyIcon, title: emptyTitle, message: emptyMessage);
    }
    return builder(value);
  }
}

/// The short "nothing here" message of a dashboard section (no fake zeros).
class DashEmpty extends StatelessWidget {
  const DashEmpty({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => EmptyState(icon: icon, title: title, message: message);
}

/// Tone of a server status group key: green operational, amber under-maintenance, red
/// out-of-service, grey retired / other / unknown. Chips, legends, donuts and map pins all use it.
ChipTone dashStatusTone(String key) => switch (key) {
  'operational' => ChipTone.green,
  'under-maintenance' => ChipTone.amber,
  'out-of-service' => ChipTone.red,
  _ => ChipTone.grey,
};

/// Colour of a server status group (see [dashStatusTone]).
Color dashStatusColor(String key) => dashStatusTone(key).foreground;

/// A status chip: the server's text, coloured by its status group key.
class DashStatusChip extends StatelessWidget {
  const DashStatusChip({super.key, required this.label, required this.groupKey});

  final String label;
  final String groupKey;

  @override
  Widget build(BuildContext context) => StatusChip(label, tone: dashStatusTone(groupKey));
}

IconData dashStatusIcon(String key) => switch (key) {
  'operational' => Icons.check_circle_rounded,
  'under-maintenance' => Icons.build_circle_rounded,
  'out-of-service' => Icons.power_off_rounded,
  'retired' => Icons.delete_rounded,
  _ => Icons.more_horiz_rounded,
};

/// healthy / warning / critical.
Color dashHealthColor(String key) => switch (key) {
  'healthy' => const Color(0xFF22B35E),
  'warning' => const Color(0xFFF5B800),
  _ => const Color(0xFFEF4444),
};

/// Colours for the type / location donuts (cycled).
const dashPalette = [
  Color(0xFF6C3CE9),
  Color(0xFF2F80ED),
  Color(0xFF22B35E),
  Color(0xFFF5B800),
  Color(0xFFF2711C),
  Color(0xFFEF4444),
  Color(0xFF14A89A),
  Color(0xFFC04BE8),
  Color(0xFF7C8595),
];

/// Severity look of a dashboard alert (Critical / Warning / Info).
(IconData, TileTone, ChipTone) dashSeverityLook(String severity) => switch (severity) {
  DashSeverity.critical => (Icons.warning_rounded, TileTone.pink, ChipTone.red),
  DashSeverity.warning => (Icons.warning_rounded, TileTone.peach, ChipTone.amber),
  _ => (Icons.info_rounded, TileTone.sky, ChipTone.blue),
};

/// Icon + tone + dot colour of a dashboard activity type.
(IconData, TileTone, Color) dashActivityLook(String type) => switch (type) {
  DashActivityType.workOrder => (Icons.build_rounded, TileTone.sky, AppColors.iconBlue),
  DashActivityType.inspection => (Icons.description_rounded, TileTone.mint, AppColors.iconGreen),
  _ => (Icons.check_box_rounded, TileTone.peach, AppColors.iconOrange),
};

String dashActivityLabel(String type) => switch (type) {
  DashActivityType.workOrder => 'Work Order',
  DashActivityType.inspection => 'Inspection',
  DashActivityType.approval => 'Approval',
  _ => type,
};

/// The module behind an activity / alert source, for "Not available yet" (not connected in this phase).
String dashModuleOf(String type) => switch (type) {
  'WorkOrder' => 'Work orders',
  'Inspection' => 'Inspections',
  'Approval' => 'Approvals',
  'SparePart' => 'Inventory',
  'Maintenance' => 'Maintenance',
  _ => 'Alert details',
};

/// A Recent Assets row as the shared live asset tile's item.
AssetListItem dashAssetItem(DashRecentAsset a) => AssetListItem(
  id: a.assetRegistrationId,
  assetRegistrationId: a.assetRegistrationId,
  assetName: a.assetName,
  assetTag: a.assetTag,
  imageUrl: a.imageUrl,
  category: a.category,
  assetType: a.assetType,
  locationPath: a.locationLabel,
  status: a.status,
  manufacturer: a.manufacturer,
  createdAt: a.createdAtUtc,
);

/// "Just now", "5 mins ago", "3 hours ago", "Yesterday", "3 days ago", "12 Sep 2026" for a server
/// timestamp. Server data is real time (API mode), so this compares with the device clock, not
/// DemoClock (which only drives the mock data).
String dashTimeAgo(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final t = at.toLocal(), n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.isNegative) return DateFormat('d MMM, hh:mm a').format(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} ${d.inMinutes == 1 ? 'min' : 'mins'} ago';
  if (d.inHours < 24) return '${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'} ago';
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return DateFormat('d MMM yyyy').format(t);
}

/// "AED 1,250" / "1.25M" style amounts.
String dashMoney(double v) => dashNumber.format(v.round());

/// Opens the live Asset detail of the asset with tag [tag]: GET /api/asset-registrations/lookup
/// ?code=&type=assetTag (dashboard alerts, tasks and activities carry the TAG, not the registration
/// id). No match → a snack; a server error → its message.
Future<void> openAssetByTag(BuildContext context, WidgetRef ref, String tag) async {
  try {
    final found = await ref.read(assetsApiProvider).lookup(tag, type: 'assetTag');
    if (!context.mounted) return;
    if (found == null || found.asset.assetRegistrationId.isEmpty) {
      context.showSnack('No asset with tag $tag was found');
      return;
    }
    await context.push(Routes.assetDetail(found.asset.assetRegistrationId));
  } catch (e) {
    if (context.mounted) context.showSnack(ApiException.from(e).message);
  }
}

/// An asset tag shown as a link ("CHL-30002 ›") that opens the asset via [openAssetByTag].
class AssetTagLink extends ConsumerWidget {
  const AssetTagLink({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    link: true,
    label: 'Open asset $tag',
    child: InkWell(
      onTap: () => openAssetByTag(context, ref, tag),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '$tag ›',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
      ),
    ),
  );
}
