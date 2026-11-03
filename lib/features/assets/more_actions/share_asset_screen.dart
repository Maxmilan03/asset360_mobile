import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/platform/app_launcher.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Parts of the asset that can be included in the shared text.
enum ShareInfo {
  basic('Basic Details', Icons.info_outline_rounded),
  location('Location', Icons.location_on_outlined),
  custodian('Custodian', Icons.person_outline_rounded),
  photos('Photos', Icons.photo_outlined),
  documents('Documents', Icons.description_outlined),
  maintenance('Maintenance History', Icons.build_outlined);

  const ShareInfo(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Share via Email / Link / QR Code / More, with switches for what is included.
class ShareAssetScreen extends ConsumerStatefulWidget {
  const ShareAssetScreen({super.key, required this.assetId});

  final String? assetId;

  /// Tests replace the system share sheet and the email app.
  @visibleForTesting
  static Future<void> Function(ShareParams params)? debugShare;
  @visibleForTesting
  static Future<bool> Function(String url)? debugOpenUrl;

  @override
  ConsumerState<ShareAssetScreen> createState() => _ShareAssetScreenState();
}

class _ShareAssetScreenState extends ConsumerState<ShareAssetScreen> {
  final _on = {ShareInfo.basic, ShareInfo.location, ShareInfo.custodian};

  String _subject(Asset a) => 'Asset ${a.id} – ${a.name}';

  /// The shared text: only the switched-on parts, then the link.
  String _summary(Asset a) {
    final b = StringBuffer('${a.id} – ${a.name}\n');
    void section(String title, List<String> lines) {
      b.writeln('\n$title');
      for (final l in lines) {
        b.writeln('• $l');
      }
    }

    if (_on.contains(ShareInfo.basic)) {
      section('Basic Details', [
        'Type: ${a.type} (${a.category})',
        'Manufacturer / Model: ${a.manufacturerModel}',
        if (a.serialNo != null) 'Serial No.: ${a.serialNo}',
        'Status: ${a.status} · Condition: ${a.condition}',
      ]);
    }
    if (_on.contains(ShareInfo.location)) section('Location', ['${a.site} › ${a.location}']);
    if (_on.contains(ShareInfo.custodian)) section('Custodian', [a.custodian]);
    if (_on.contains(ShareInfo.photos)) {
      section('Photos', ['${a.gallery.length} photo${a.gallery.length == 1 ? '' : 's'} (main photo attached)']);
    }
    if (_on.contains(ShareInfo.documents)) {
      final docs = ref.read(documentsProvider).forAsset(a.id);
      section('Documents', docs.isEmpty ? ['None'] : [for (final d in docs) '${d.name} (${d.type})']);
    }
    if (_on.contains(ShareInfo.maintenance)) {
      final wos = ref.read(workOrdersProvider).forAsset(a.id)..sort((x, y) => y.openedAt.compareTo(x.openedAt));
      section('Maintenance History', [
        if (wos.isEmpty) 'No work orders',
        for (final w in wos.take(5)) '${w.id} · ${w.title} · ${w.status} · ${DemoClock.formatDate(w.openedAt)}',
      ]);
    }
    b.write('\n${assetShareLink(a.id)}');
    return b.toString();
  }

  /// The main photo as a share attachment (bundled photos are read from the app bundle).
  Future<XFile?> _photoFile(Asset a) async {
    final path = a.gallery.firstOrNull;
    if (path == null) return null;
    if (!path.startsWith('assets/')) return XFile(path);
    try {
      final data = await rootBundle.load(path);
      final name = '${a.id}_${path.split('/').last}';
      return XFile.fromData(data.buffer.asUint8List(), name: name, mimeType: 'image/webp');
    } catch (_) {
      return null;
    }
  }

  Future<void> _systemShare(Asset a) async {
    final photo = _on.contains(ShareInfo.photos) ? await _photoFile(a) : null;
    final params = ShareParams(
      subject: _subject(a),
      title: _subject(a),
      text: _summary(a),
      files: photo == null ? null : [photo],
    );
    try {
      if (ShareAssetScreen.debugShare != null) {
        await ShareAssetScreen.debugShare!(params);
      } else {
        await SharePlus.instance.share(params);
      }
      if (!mounted) return;
      ref.read(assetsProvider.notifier).addEvent(a.id, 'Asset details shared', note: _included);
      finishAction(context, '${a.id} details shared');
    } catch (_) {
      if (mounted) context.showSnack('Sharing is not available on this device');
    }
  }

  String get _included => [
    for (final i in ShareInfo.values)
      if (_on.contains(i)) i.label,
  ].join(', ');

  Future<void> _email(Asset a) async {
    final url = Uri(
      scheme: 'mailto',
      query: 'subject=${Uri.encodeComponent(_subject(a))}&body=${Uri.encodeComponent(_summary(a))}',
    ).toString();
    final ok = await (ShareAssetScreen.debugOpenUrl ?? AppLauncher.openUrl)(url);
    if (!mounted) return;
    if (ok) {
      context.showSnack('Email app opened');
    } else {
      await Clipboard.setData(ClipboardData(text: _summary(a)));
      if (mounted) context.showSnack('No email app found – the details were copied instead');
    }
  }

  Future<void> _copyLink(Asset a) async {
    await Clipboard.setData(ClipboardData(text: assetShareLink(a.id)));
    if (mounted) context.showSnack('Link copied: ${assetShareLink(a.id)}');
  }

  Future<void> _qr(Asset a) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => sheetFrame(context, [
      SheetTitle('${a.id} QR Code', subtitle: 'Scan to open ${a.name}'),
      Center(child: QrCode(data: assetShareLink(a.id), size: 200)),
      const SizedBox(height: 10),
      SelectableText(assetShareLink(a.id), textAlign: TextAlign.center, style: AppText.caption),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _copyLink(a),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Copy Link'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ),
        ],
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return MoreActionPage(
      action: MoreAction.share,
      assetId: widget.assetId,
      button: (a) => FilledButton.icon(
        onPressed: _on.isEmpty ? null : () => _systemShare(a),
        icon: const Icon(Icons.share_rounded),
        label: const Text('Share'),
      ),
      builder: (context, a) => [
        Text('Share via', style: AppText.sectionTitle),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (icon, label, tone, onTap) in [
              (Icons.email_outlined, 'Email', TileTone.sky, () => _email(a)),
              (Icons.link_rounded, 'Link', TileTone.mint, () => _copyLink(a)),
              (Icons.qr_code_2_rounded, 'QR Code', TileTone.lavender, () => _qr(a)),
              (Icons.more_horiz_rounded, 'More', TileTone.peach, () => _systemShare(a)),
            ]) ...[
              Expanded(
                child: ActionTile(icon: icon, label: label, tone: tone, onTap: onTap, labelSize: 11.5, height: 80),
              ),
              if (label != 'More') const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Include Information',
          child: Column(
            children: [
              for (final i in ShareInfo.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  secondary: Icon(i.icon, color: AppColors.primary),
                  title: Text(i.label, style: AppText.body),
                  value: _on.contains(i),
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => setState(() => v ? _on.add(i) : _on.remove(i)),
                ),
            ],
          ),
        ),
        if (_on.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Switch on at least one item to share', style: AppText.caption.copyWith(color: AppColors.red)),
          ),
      ],
    );
  }
}
