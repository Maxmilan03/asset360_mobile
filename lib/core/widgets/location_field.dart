import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/feedback.dart';
import 'package:asset360_mobile/core/widgets/form_fields.dart';
import 'package:asset360_mobile/core/widgets/scan_capture.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';

export 'package:asset360_mobile/data/db/app_database.dart' show LocationLevel, DbLocation;

/// Site → Building → Floor → Room picked in a [LocationField] (any level may be empty).
class LocationValue {
  const LocationValue({this.site, this.building, this.floor, this.room});

  static const empty = LocationValue();

  final String? site;
  final String? building;
  final String? floor;
  final String? room;

  factory LocationValue.of(DbLocation l) =>
      LocationValue(site: l.site, building: l.building, floor: l.floor, room: l.room);

  bool get isEmpty => site == null;

  /// "Building / Floor – Room" (the format the app's records use), or null without a building.
  String? get path => building == null
      ? null
      : floor == null
      ? building
      : room == null
      ? '$building / $floor'
      : '$building / $floor – $room';

  /// The deepest [Locations] row this value names.
  DbLocation? rowIn(List<DbLocation> rows) {
    for (final l in rows) {
      if (l.site == site && l.building == building && l.floor == floor && l.room == room) return l;
    }
    return null;
  }

  /// The value whose [path] is [path] (e.g. an asset's location), or null.
  static LocationValue? parse(String? path, List<DbLocation> rows, {String? site}) {
    final p = path?.trim().toLowerCase();
    if (p == null || p.isEmpty) return null;
    for (final l in rows) {
      if (l.level == LocationLevel.site || (site != null && l.site != site)) continue;
      if (l.path.toLowerCase() == p) return LocationValue.of(l);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is LocationValue &&
      other.site == site &&
      other.building == building &&
      other.floor == floor &&
      other.room == room;

  @override
  int get hashCode => Object.hash(site, building, floor, room);
}

enum _Level { site, building, floor, room }

/// Cascading Site → Building → Floor → Room dropdowns from the Locations table.
class LocationSelector extends ConsumerWidget {
  const LocationSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.site,
    this.required = const {LocationLevel.site, LocationLevel.building, LocationLevel.floor},
    this.roomLabel = 'Room / Zone',
    this.highlight = const {},
  });

  final LocationValue value;
  final ValueChanged<LocationValue> onChanged;

  /// Limits the choice to one site.
  final String? site;

  /// Levels marked with *.
  final Set<LocationLevel> required;
  final String roomLabel;

  /// Levels just filled from a tag (shown tinted).
  final Set<LocationLevel> highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(locationsProvider).value ?? const <DbLocation>[];
    List<String> names(_Level level) => [
      for (final l in rows)
        if (l.level.index == level.index &&
            (level == _Level.site ? (site == null || l.site == site) : l.site == value.site) &&
            (level.index < 2 || l.building == value.building) &&
            (level.index < 3 || l.floor == value.floor))
          [l.site, l.building, l.floor, l.room][level.index]!,
    ];
    Widget dd(LocationLevel level, String label, String? selected, ValueChanged<String?> onPick) {
      final options = names(_Level.values[level.index]);
      final lit = highlight.contains(level);
      return LabeledField(
        label: label,
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
            key: ValueKey('$label-$selected-${options.length}-${value.site}-${value.building}-${value.floor}'),
            initialValue: options.contains(selected) ? selected : null,
            isExpanded: true,
            hint: Text(options.isEmpty ? '—' : 'Select', style: hintStyle),
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: options.isEmpty ? null : onPick,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldPair(
          dd(LocationLevel.site, 'Site', value.site, (v) => onChanged(LocationValue(site: v))),
          dd(
            LocationLevel.building,
            'Building',
            value.building,
            (v) => onChanged(LocationValue(site: value.site, building: v)),
          ),
        ),
        FieldPair(
          dd(
            LocationLevel.floor,
            'Floor',
            value.floor,
            (v) => onChanged(LocationValue(site: value.site, building: value.building, floor: v)),
          ),
          dd(
            LocationLevel.room,
            roomLabel,
            value.room,
            (v) => onChanged(LocationValue(site: value.site, building: value.building, floor: value.floor, room: v)),
          ),
        ),
      ],
    );
  }
}

/// [LocationSelector] plus scan-to-fill: while visible it receives location scans from the
/// camera / NFC (its scan button) and from the HHT trigger, and fills every level the tag gives.
/// With [onAsset] it also takes asset scans (the form's asset field).
class LocationField extends ConsumerStatefulWidget {
  const LocationField({
    super.key,
    required this.value,
    required this.onChanged,
    this.site,
    this.required = const {LocationLevel.site, LocationLevel.building, LocationLevel.floor},
    this.roomLabel = 'Room / Zone',
    this.errorText,
    this.onAsset,
  });

  final LocationValue value;
  final ValueChanged<LocationValue> onChanged;
  final String? site;
  final Set<LocationLevel> required;
  final String roomLabel;
  final String? errorText;

  /// Called with the asset ID when an asset tag is scanned while this field is visible (the form fills
  /// its asset field and tells the user).
  final ValueChanged<String>? onAsset;

  @override
  ConsumerState<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends ConsumerState<LocationField> {
  Set<LocationLevel> _lit = const {};
  Timer? _litTimer;
  late final _target = ScanTarget(
    accepts: {MatchType.location, if (widget.onAsset != null) MatchType.asset},
    onScan: _onScan,
    debugLabel: 'LocationField',
  );

  @override
  void dispose() {
    _litTimer?.cancel();
    super.dispose();
  }

  void _onScan(ScanResult r) {
    if (!mounted) return;
    if (r.matchType == MatchType.asset && widget.onAsset != null) {
      widget.onAsset!(r.matchId!);
      return;
    }
    final loc = r.location;
    if (r.matchType != MatchType.location || loc == null) return;
    if (widget.site != null && loc.site != widget.site) {
      context.showSnack('${loc.label} is in ${loc.site}, not ${widget.site}');
      return;
    }
    widget.onChanged(LocationValue.of(loc));
    _litTimer?.cancel();
    setState(
      () => _lit = {
        for (final l in LocationLevel.values)
          if (l.index <= loc.level.index) l,
      },
    );
    _litTimer = Timer(const Duration(milliseconds: 1600), () => mounted ? setState(() => _lit = const {}) : null);
    context.showSnack('Location filled from tag: ${loc.label}');
  }

  Future<void> _scan(_ScanVia via) async {
    final ScanEvent? event;
    if (via == _ScanVia.camera) {
      final rows = ref.read(locationsProvider).value ?? const <DbLocation>[];
      final floors = [
        for (final l in rows)
          if (l.level == LocationLevel.floor && (widget.site == null || l.site == widget.site)) l,
      ];
      final code = await captureScan(
        context,
        title: 'Scan Location Tag',
        suggestions: [for (final l in floors.take(2)) '$locPrefix${l.code}'],
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
  Widget build(BuildContext context) {
    return ScanTargetScope(
      target: _target,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LocationSelector(
            value: widget.value,
            onChanged: widget.onChanged,
            site: widget.site,
            required: widget.required,
            roomLabel: widget.roomLabel,
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
}

void _noop() {}

enum _ScanVia { camera, nfc }
