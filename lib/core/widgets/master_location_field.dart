import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/feedback.dart';
import 'package:asset360_mobile/core/widgets/form_fields.dart';
import 'package:asset360_mobile/core/widgets/live_states.dart';
import 'package:asset360_mobile/core/widgets/scan_capture.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_repository.dart';

/// The levels the Asset service requires (Location.CountryId / SiteId / BuildingId / FloorId).
const requiredLocationLevels = {
  MdLocationLevel.country,
  MdLocationLevel.site,
  MdLocationLevel.building,
  MdLocationLevel.floor,
};

/// API mode: cascading Country → Site → Building → Floor → Zone → Room dropdowns over the Master
/// Data location tree. Picking a level clears the levels below; a level appears once its parent
/// is picked and has children. Loading / error / empty states come with Retry.
class MasterLocationSelector extends ConsumerWidget {
  const MasterLocationSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = requiredLocationLevels,
    this.highlight = const {},
  });

  final MdLocationPath value;
  final ValueChanged<MdLocationPath> onChanged;

  /// Levels marked with *.
  final Set<MdLocationLevel> required;

  /// Levels just filled from a tag (shown tinted).
  final Set<MdLocationLevel> highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(mdLocationTreeProvider);
    final status = serverListStatus(
      tree.whenData((t) => t.roots),
      what: 'locations',
      onRetry: () => ref.invalidate(mdLocationTreeProvider),
    );
    if (status != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [const FieldLabel('Location', required: true), status, const SizedBox(height: 8)],
      );
    }
    final index = tree.requireValue;
    // Re-resolve the value against the current tree (a reload may have changed names).
    final path = value.isEmpty ? value : index.pathTo(index.byId(value.deepest!.id));

    final fields = <Widget>[];
    for (final level in MdLocationLevel.values) {
      final parent = level.index == 0 ? null : path.at(MdLocationLevel.values[level.index - 1]);
      if (level.index > 0 && parent == null) break;
      final options = index.childrenOf(parent);
      if (options.isEmpty) break;
      fields.add(_dropdown(level, options, path));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < fields.length; i += 2)
          i + 1 < fields.length ? FieldPair(fields[i], fields[i + 1]) : fields[i],
      ],
    );
  }

  Widget _dropdown(MdLocationLevel level, List<MdLocationNode> options, MdLocationPath path) {
    final selected = path.at(level)?.id;
    final lit = highlight.contains(level);
    return LabeledField(
      label: level.label,
      required: required.contains(level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: lit ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: lit
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: 0, spreadRadius: 2)]
              : null,
        ),
        child: DropdownButtonFormField<String>(
          key: ValueKey('${level.label}#$selected#${options.length}#${path.at(level)?.parentId}'),
          initialValue: options.any((o) => o.id == selected) ? selected : null,
          isExpanded: true,
          hint: Text('Select', style: hintStyle),
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o.id,
                child: Text(o.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            // The same value again keeps the levels below.
            if (id == selected) return;
            onChanged(path.pick(level, options.where((o) => o.id == id).firstOrNull));
          },
        ),
      ),
    );
  }
}

/// [MasterLocationSelector] plus scan-to-fill: while visible it takes location scans (camera / NFC
/// via its button, or the HHT trigger). A tag linked to a location, or a "LOC:<code>" label whose
/// code is a Master Data location code, fills every level down to that location.
class MasterLocationField extends ConsumerStatefulWidget {
  const MasterLocationField({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = requiredLocationLevels,
    this.errorText,
  });

  final MdLocationPath value;
  final ValueChanged<MdLocationPath> onChanged;
  final Set<MdLocationLevel> required;
  final String? errorText;

  @override
  ConsumerState<MasterLocationField> createState() => _MasterLocationFieldState();
}

class _MasterLocationFieldState extends ConsumerState<MasterLocationField> {
  Set<MdLocationLevel> _lit = const {};
  Timer? _litTimer;
  late final _target = ScanTarget(accepts: {MatchType.location}, onScan: _onScan, debugLabel: 'MasterLocationField');

  @override
  void dispose() {
    _litTimer?.cancel();
    super.dispose();
  }

  void _onScan(ScanResult r) {
    final path = r.masterLocation;
    if (!mounted || r.matchType != MatchType.location || path == null || path.isEmpty) return;
    widget.onChanged(path);
    _litTimer?.cancel();
    setState(
      () => _lit = {
        for (final l in MdLocationLevel.values)
          if (l.index <= path.level!.index) l,
      },
    );
    _litTimer = Timer(const Duration(milliseconds: 1600), () => mounted ? setState(() => _lit = const {}) : null);
    context.showSnack('Location filled from tag: ${path.label}');
  }

  Future<void> _scan(_ScanVia via) async {
    final ScanEvent? event;
    if (via == _ScanVia.camera) {
      final tree = ref.read(mdLocationTreeProvider).value;
      final code = await captureScan(
        context,
        title: 'Scan Location Tag',
        suggestions: [
          for (final n in tree?.roots.expand((r) => r.children).take(2) ?? const <MdLocationNode>[])
            if (n.code.isNotEmpty) '$locPrefix${n.code}',
        ],
      );
      event = code == null
          ? null
          : ScanEvent(
              value: code.code,
              format: code.format,
              source: code.format == 'manual' ? ScanSource.manual : ScanSource.camera,
            );
    } else {
      event = await readNfcWithSheet(context, ref);
    }
    if (event == null || !mounted) return;
    await handleScanEvent(context, ref, event, requester: _target);
  }

  @override
  Widget build(BuildContext context) => ScanTargetScope(
    target: _target,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MasterLocationSelector(
          value: widget.value,
          onChanged: widget.onChanged,
          required: widget.required,
          highlight: _lit,
        ),
        Row(
          children: [
            Icon(Icons.sell_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text('Scan a location tag (QR, NFC or scanner trigger) to fill', style: AppText.caption)),
            PopupMenuButton<_ScanVia>(
              tooltip: 'Scan location tag',
              onSelected: _scan,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ScanVia.camera,
                  child: ListTile(leading: Icon(Icons.qr_code_scanner_rounded), title: Text('Camera (QR / barcode)')),
                ),
                PopupMenuItem(
                  value: _ScanVia.nfc,
                  child: ListTile(leading: Icon(Icons.nfc_rounded), title: Text('NFC tag')),
                ),
              ],
              child: const IgnorePointer(
                child: ScanSuffix(onTap: _noop, tooltip: 'Scan location tag'),
              ),
            ),
          ],
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(widget.errorText!, style: AppText.caption.copyWith(color: AppColors.red)),
          ),
      ],
    ),
  );
}

void _noop() {}

enum _ScanVia { camera, nfc }
