import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/audits_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/features/work/audit/audit_widgets.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';

/// Asset Found (right screen of design/15_asset_audit.jpg). Pops the saved result.
class AuditAssetScreen extends ConsumerStatefulWidget {
  const AuditAssetScreen({super.key, required this.auditId, required this.assetId, this.method});

  final String auditId;
  final String assetId;

  /// How the asset was identified (QR, Barcode, RFID, Search, Manual Entry).
  final String? method;

  @override
  ConsumerState<AuditAssetScreen> createState() => _AuditAssetScreenState();
}

class _AuditAssetScreenState extends ConsumerState<AuditAssetScreen> {
  String _result = AuditResult.verified;
  String? _location;

  /// The dropdowns while a location is being picked (it is recorded once a floor is chosen).
  LocationValue? _picking;
  String _condition = 'Good';
  bool _updateLocation = false;
  final _remarks = TextEditingController();
  final _photos = <String>[];
  bool _init = false;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  void _initFrom(Asset asset, Audit audit) {
    if (_init) return;
    _init = true;
    // Blind count: the auditor records where the asset is without seeing the register.
    _location = audit.blindCount ? null : asset.location;
    _condition = AssetOptions.conditions.contains(asset.condition) ? asset.condition : 'Good';
  }

  void _setLocation(String? l, Asset asset) {
    if (l == null) return setState(() => _location = null);
    setState(() {
      _location = l;
      // A different place than the register → Wrong Location (a Verified result would be wrong).
      if (l != asset.location && _result == AuditResult.verified) _result = AuditResult.wrongLocation;
      if (l == asset.location && _result == AuditResult.wrongLocation) _result = AuditResult.verified;
    });
  }

  void _select(String r, Asset asset) {
    if (r == AuditResult.unregistered) {
      context.showSnack('${asset.id} is in the register. Use Unregistered for tags that are not.');
      return;
    }
    setState(() {
      _result = r;
      if (r != AuditResult.wrongLocation) _updateLocation = false;
    });
  }

  void _save(Asset asset, Audit audit) {
    if (_result == AuditResult.wrongLocation && (_location == null || _location == asset.location)) {
      context.showSnack('Pick the scanned location (where the asset actually is)');
      return;
    }
    if (_result == AuditResult.verified && _location == null) {
      context.showSnack('Pick the scanned location');
      return;
    }
    ref
        .read(auditsProvider.notifier)
        .record(
          audit.id,
          AuditEntry(
            assetId: asset.id,
            result: _result,
            at: DemoClock.now,
            location: _result == AuditResult.notFound ? null : _location,
            expectedLocation: asset.location,
            condition: _result == AuditResult.notFound ? null : _condition,
            remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
            photos: List.of(_photos),
            method: widget.method,
            by: ref.read(currentUserProvider).name,
          ),
          updateLocation: _result == AuditResult.wrongLocation && _updateLocation,
        );
    context.pop(_result);
  }

  @override
  Widget build(BuildContext context) {
    final audit = ref.watch(auditByIdProvider(widget.auditId));
    final asset = ref.watch(assetByIdProvider(widget.assetId));
    if (audit == null || asset == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Asset not found',
          message: '${widget.assetId} is not in the register.',
          actionLabel: 'Back to the audit',
          onAction: () => context.pop(),
        ),
      );
    }
    _initFrom(asset, audit);
    final saved = audit.entryFor(asset.id);
    final (line1, line2) = locationLines(asset.location);
    final rfid = widget.method == AuditMethod.rfid;
    final scannedQr = widget.method == AuditMethod.qr || widget.method == AuditMethod.barcode;
    final blind = audit.blindCount;
    return AppScaffold(
      bottomActions: Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Close')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _save(asset, audit),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Save & Next', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: context.pagePadding,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.green,
                  child: Icon(Icons.check_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Asset Found', style: AppText.sectionTitle),
                      Text('Asset details loaded successfully', style: AppText.secondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => context.push(Routes.assetDetail(asset.id)),
            child: Row(
              children: [
                AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 84),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              asset.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sectionTitle,
                            ),
                          ),
                          if (saved != null) StatusChip(saved.result),
                        ],
                      ),
                      Text(asset.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                      const SizedBox(height: 4),
                      if (blind)
                        const IconLine(icon: Icons.location_on_outlined, text: 'Location hidden (blind count)')
                      else ...[
                        IconLine(icon: Icons.location_on_outlined, text: line1),
                        if (line2 != null) IconLine(icon: Icons.location_on_outlined, text: line2),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InfoRow(label: 'Asset Type', value: asset.type),
          InfoRow(label: 'Serial Number', value: asset.serialNo ?? '—'),
          // The label names the technology that identified the asset.
          InfoRow(
            label: rfid ? 'Tag ID (RFID)' : (scannedQr ? 'Tag ID (${widget.method})' : 'Tag ID'),
            value: rfid ? asset.tagId ?? '—' : (scannedQr ? asset.barcode ?? asset.id : asset.tagId ?? '—'),
          ),
          InfoRow(label: 'Status', value: asset.status),
          InfoRow(label: 'Current Location', value: blind ? 'Hidden (blind count)' : asset.location),
          InfoRow(label: 'Custodian', value: blind ? 'Hidden (blind count)' : asset.custodian),
          if (saved != null)
            InfoRow(
              label: 'Last audited',
              value: '${saved.result} · ${auditTime(saved.at)}',
              valueColor: AppColors.textSecondary,
            ),
          const SizedBox(height: 14),
          Text('Audit Action', style: AppText.sectionTitle),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, r) in AuditResult.all.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _ActionCard(result: r, selected: _result == r, onTap: () => _select(r, asset)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text('Audit Details', style: AppText.sectionTitle),
          const SizedBox(height: 8),
          if (_result != AuditResult.notFound) ...[
            Text('Scanned Location', style: AppText.secondary),
            const SizedBox(height: 6),
            // Pick it, or scan the location tag (QR, NFC or the scanner trigger) to fill it.
            Builder(
              builder: (context) {
                final rows = ref.watch(locationsProvider).value ?? const <DbLocation>[];
                final site = rows.any((l) => l.site == audit.site) ? audit.site : null;
                final value = _picking ?? LocationValue.parse(_location, rows, site: site) ?? LocationValue.empty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LocationField(
                      value: value.isEmpty && site != null ? LocationValue(site: site) : value,
                      site: site,
                      onChanged: (v) {
                        setState(() => _picking = v);
                        if (v.floor != null) _setLocation(v.path, asset);
                      },
                    ),
                    if (_location != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Recorded: $_location', style: AppText.caption),
                      ),
                  ],
                );
              },
            ),
            if (_result == AuditResult.wrongLocation)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _updateLocation,
                onChanged: (v) => setState(() => _updateLocation = v ?? false),
                title: Text('Update asset location to scanned location', style: AppText.body),
                subtitle: Text('Adds a movement record', style: AppText.caption),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(width: 110, child: Text('Condition', style: AppText.secondary)),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _condition,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [for (final c in AssetOptions.conditions) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _condition = v ?? _condition),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Text('Remarks', style: AppText.secondary),
          const SizedBox(height: 6),
          TextField(
            controller: _remarks,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Add remarks (optional)'),
          ),
          const SizedBox(height: 10),
          PhotoStrip(
            photos: _photos,
            onAdd: (p) => setState(() => _photos.add(p)),
            onRemove: (i) => setState(() => _photos.removeAt(i)),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.result, required this.selected, required this.onTap});

  final String result;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = auditResultLook(result);
    return Material(
      color: look.tone.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? look.color : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? Icons.check_circle_rounded : look.icon, color: look.color, size: 22),
              const SizedBox(height: 4),
              Text(
                result.replaceFirst(' ', '\n'),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppText.caption.copyWith(color: AppColors.text, fontSize: 11, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
