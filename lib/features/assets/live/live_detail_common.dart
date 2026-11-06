import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/platform/app_launcher.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/media_api.dart' show resolveMediaUrl;
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/asset_registration_mapping.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Shared pieces of the live (apiMode) Asset 360° screens and their More Actions.

// ---------------------------------------------------------------- resolving an asset

final _registrationId = RegExp(r'^AR\d+$', caseSensitive: false);

/// The assetRegistrationId for any code (registration ID, asset tag, barcode, RFID, NFC UID):
/// a registration ID is used as is, anything else goes through GET …/lookup. Null = no match.
final liveAssetIdProvider = FutureProvider.autoDispose.family<String?, String>((ref, code) async {
  final c = code.trim();
  if (_registrationId.hasMatch(c)) return c.toUpperCase();
  return (await ref.watch(assetsApiProvider).lookup(c))?.asset.assetRegistrationId;
});

/// True when [error] is a 404 from the server.
bool isNotFound(Object error) => ApiException.from(error).kind == ApiErrorKind.notFound;

/// Re-reads everything shown for asset [id] (images, documents, tree, condition, criticality).
void invalidateLiveAsset(WidgetRef ref, String id) {
  for (final p in liveAssetProviders(id)) {
    ref.invalidate(p);
  }
}

/// The register [Asset] built from a live record, for the shared screens that only need its
/// name, tag, barcode and photos (Print Asset Tag, Share). ID = asset tag, else the registration ID.
Asset liveAsAsset(AssetRegistration r) {
  final a = r.toAsset(by: r.createdBy ?? '');
  return a.id.isEmpty ? a.copyWith(id: r.assetRegistrationId) : a;
}

// ---------------------------------------------------------------- formatting

/// Live dates are real dates (the backend checks them against UTC now), so live screens use the
/// device clock, not DemoClock.
DateTime liveToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String? liveDate(DateTime? d) => d == null ? null : DemoClock.formatDate(d.isUtc ? d : d.toLocal());

final _money = NumberFormat('#,##0.##');
final _number = NumberFormat('#,##0.##');

/// "AED 105,000" ("AED - UAE Dirham" → AED).
String? liveMoney(double? v, String? currency) {
  if (v == null) return null;
  final code = (currency ?? '').split(' ').first.trim();
  return code.isEmpty ? _money.format(v) : '$code ${_money.format(v)}';
}

/// "4.2", "2" …
String? liveNum(num? v, [String? unit]) => v == null ? null : [_number.format(v), ?unit].join(' ');

/// "12 KB" / "1.4 MB".
String? liveSize(int? bytes) {
  if (bytes == null) return null;
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String? blankToNull(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

// ---------------------------------------------------------------- feedback

/// The server's message for [error]; 400 field errors are appended when the screen has no field for them.
String liveErrorMessage(Object error) {
  final e = ApiException.from(error);
  if (e.fieldErrors.isEmpty) return e.message;
  return '${e.message}\n${e.fieldErrors.values.join('\n')}';
}

/// Runs [task] behind a small "Uploading …" dialog (on the tab's navigator). Rethrows its error.
Future<T> runWithProgress<T>(BuildContext context, String label, Future<T> Function() task) async {
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: AppText.body)),
          ],
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    nav.pop();
  }
}

/// Opens a server file: photos in the zoomable viewer, anything else (PDF) in the app that handles
/// the URL. When no app can, the link is copied.
Future<void> openLiveFile(BuildContext context, String url, {String? fileName}) async {
  final name = (fileName ?? url).toLowerCase();
  if (AssetFileRules.imageExtensions.contains(AssetFileRules.extensionOf(name))) {
    openPhotoViewer(context, [url]);
    return;
  }
  final full = resolveMediaUrl(url);
  final ok = await (debugOpenUrl ?? AppLauncher.openUrl)(full);
  if (ok || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: full));
  if (context.mounted) context.showSnack('No app can open this file – the link was copied');
}

/// Tests replace the system "open URL".
@visibleForTesting
Future<bool> Function(String url)? debugOpenUrl;

// ---------------------------------------------------------------- small widgets

/// "Label : value" rows of one section; rows without a value are left out.
class LiveInfoRows extends StatelessWidget {
  const LiveInfoRows(this.rows, {super.key, this.empty = 'Not provided'});

  final List<(String, String?)> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final (l, v) in rows)
        if (blankToNull(v) != null) (l, v!),
    ];
    if (shown.isEmpty) return Text(empty, style: AppText.secondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final (l, v) in shown) InfoRow(label: l, value: v, labelWidth: 132)],
    );
  }
}

/// A sub-heading inside a section card ("Warranty", "Specifications").
class LiveSubTitle extends StatelessWidget {
  const LiveSubTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(text, style: AppText.bodyStrong.copyWith(color: AppColors.primary)),
  );
}

/// An [AsyncValue] inside a card: a thin bar while loading, the server's message + Retry on error.
class LiveAsync<T> extends StatelessWidget {
  const LiveAsync({super.key, required this.value, required this.data, required this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: LinearProgressIndicator()),
    error: (e, _) => Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(ApiException.from(e).message, style: AppText.caption)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

/// Text field with tappable suggestions underneath (free text allowed), e.g. Image Type.
class SuggestField extends StatelessWidget {
  const SuggestField({
    super.key,
    required this.controller,
    required this.suggestions,
    this.hint,
    this.error,
    this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String? hint;
  final String? error;
  final int? maxLength;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          maxLength: maxLength,
          style: inputStyle,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint, errorText: error, counterText: ''),
          onChanged: (_) => onChanged?.call(),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in suggestions)
                IconFilterChip(
                  label: s,
                  selected: value.text.trim() == s,
                  onTap: () {
                    controller.text = s;
                    onChanged?.call();
                  },
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// The asset at the top of a live action screen: photo, tag, name, type and status.
class LiveAssetCard extends StatelessWidget {
  const LiveAssetCard({super.key, required this.asset, this.onChange});

  final AssetRegistration asset;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final b = asset.basicInformation;
    return AppCard(
      child: Row(
        children: [
          AssetThumb(imagePath: b.images.firstOrNull, fallbackIcon: Icons.inventory_2_outlined, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blankToNull(b.assetTag) ?? asset.assetRegistrationId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  asset.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  [asset.assetRegistrationId, ?asset.classification.assetType].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                if (blankToNull(b.status) != null) ...[const SizedBox(height: 6), AssetStatusChip(b.status!)],
              ],
            ),
          ),
          if (onChange != null) TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

/// "Asset not found" with the server's message.
class LiveAssetNotFound extends StatelessWidget {
  const LiveAssetNotFound({super.key, required this.message, this.actionLabel = 'Back', this.onAction});

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.inventory_2_outlined,
    title: 'Asset not found',
    message: message,
    actionLabel: actionLabel,
    onAction: onAction ?? () => context.canPop() ? context.pop() : null,
  );
}

/// Loads asset [code] (registration ID or any tag) and builds [builder] with it; shimmer while
/// loading, "Asset not found" on 404, Retry on other errors.
class LiveAssetLoader extends ConsumerWidget {
  const LiveAssetLoader({super.key, required this.code, required this.builder});

  final String code;
  final Widget Function(BuildContext context, AssetRegistration asset) builder;

  static Widget _loading(BuildContext context) => AppScaffold(
    body: ListView(padding: context.pagePadding, children: const [ListSkeleton(rows: 5)]),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget failed(Object e, VoidCallback retry) => AppScaffold(
      body: Center(
        child: SingleChildScrollView(
          child: isNotFound(e)
              ? LiveAssetNotFound(message: ApiException.from(e).message)
              : LoadErrorState(error: e, onRetry: retry),
        ),
      ),
    );
    return ref
        .watch(liveAssetIdProvider(code))
        .when(
          loading: () => _loading(context),
          error: (e, _) => failed(e, () => ref.invalidate(liveAssetIdProvider(code))),
          data: (id) => id == null
              ? AppScaffold(
                  body: Center(child: LiveAssetNotFound(message: 'No asset matches "$code".')),
                )
              : ref
                    .watch(liveAssetProvider(id))
                    .when(
                      loading: () => _loading(context),
                      error: (e, _) => failed(e, () => invalidateLiveAsset(ref, id)),
                      data: (r) => builder(context, r),
                    ),
        );
  }
}

/// Frame of a live More Actions screen: title, the asset card, the form and a sticky [button].
class LiveActionPage extends StatelessWidget {
  const LiveActionPage({super.key, required this.action, required this.assetId, required this.builder, this.button})
    : title = null,
      subtitle = null;

  /// A page that is not one of the More Actions (e.g. Move Asset).
  const LiveActionPage.titled({
    super.key,
    required String this.title,
    required String this.subtitle,
    required this.assetId,
    required this.builder,
    this.button,
  }) : action = null;

  final MoreAction? action;
  final String? title, subtitle;
  final String? assetId;
  final List<Widget> Function(BuildContext context, AssetRegistration asset) builder;
  final Widget Function(AssetRegistration asset)? button;

  @override
  Widget build(BuildContext context) {
    if (assetId == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Select an asset first',
          message: 'Open this action from More Actions.',
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
      );
    }
    return LiveAssetLoader(
      code: assetId!,
      builder: (context, r) => AppScaffold(
        bottomActions: button?.call(r),
        body: ListView(
          padding: button == null ? context.pagePadding : const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            PageTitle(title: title ?? action!.title, subtitle: subtitle ?? action!.subtitle),
            const SizedBox(height: 14),
            LiveAssetCard(asset: r),
            const SizedBox(height: 16),
            ...builder(context, r),
          ],
        ),
      ),
    );
  }
}

/// A FilledButton that shows a spinner while [busy].
Widget busyButton({required bool busy, required VoidCallback onPressed, required String label, IconData? icon}) =>
    FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon ?? Icons.check_rounded),
      label: Text(label),
    );

/// Bottom sheet to choose a live asset (search by name / tag). Returns its assetRegistrationId.
Future<String?> showLiveAssetPicker(BuildContext context) =>
    showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (_) => const _LiveAssetPicker());

class _LiveAssetPicker extends ConsumerStatefulWidget {
  const _LiveAssetPicker();

  @override
  ConsumerState<_LiveAssetPicker> createState() => _LiveAssetPickerState();
}

class _LiveAssetPickerState extends ConsumerState<_LiveAssetPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = AssetListQuery(search: _search.trim().isEmpty ? null : _search.trim());
    final list = ref.watch(liveAssetListProvider(query));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: SheetTitle('Select Asset')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: true,
                  style: inputStyle,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or asset tag',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: list.when(
                  loading: () => const Padding(padding: EdgeInsets.all(20), child: ListSkeleton(rows: 3)),
                  error: (e, _) =>
                      LoadErrorState(error: e, onRetry: () => ref.invalidate(liveAssetListProvider(query))),
                  data: (l) => l.items.isEmpty
                      ? const EmptyState(icon: Icons.search_off_rounded, title: 'No assets found')
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: l.items.length + 1,
                          itemBuilder: (_, i) {
                            if (i == l.items.length) {
                              return Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Showing ${l.items.length} of ${l.totalCount}',
                                  textAlign: TextAlign.center,
                                  style: AppText.caption,
                                ),
                              );
                            }
                            final a = l.items[i];
                            return ListTile(
                              leading: AssetThumb(imagePath: a.imageUrl, size: 40),
                              title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text([?a.assetTag, a.assetRegistrationId].join(' · '), style: AppText.caption),
                              onTap: () => Navigator.pop(context, a.assetRegistrationId),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
