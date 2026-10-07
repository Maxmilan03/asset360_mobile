import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/assets_repository.dart';

/// Values handed from the hub tiles to the form (scan, RFID read, photo).
class RegistrationPrefill {
  const RegistrationPrefill({this.photo, this.barcode, this.tagId});

  final String? photo;
  final String? barcode;
  final String? tagId;
}

// ---------------------------------------------------------------- RFID / NFC read

/// "Hold the tag near the phone" sheet: pulses for 2 s, then simulates a read of an
/// unused tag (RFID-A360-000789, …). Returns the tag ID, or null if cancelled.
Future<String?> showRfidReadSheet(BuildContext context, WidgetRef ref) {
  final assets = ref.read(assetsProvider.notifier);
  var n = 789;
  while (assets.ownerOf('RFID-A360-${n.toString().padLeft(6, '0')}') != null) {
    n++;
  }
  final tag = 'RFID-A360-${n.toString().padLeft(6, '0')}';
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _RfidSheet(tag: tag),
  );
}

class _RfidSheet extends StatefulWidget {
  const _RfidSheet({required this.tag});

  final String tag;

  @override
  State<_RfidSheet> createState() => _RfidSheetState();
}

class _RfidSheetState extends State<_RfidSheet> {
  bool _read = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _read = true);
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.pop(context, widget.tag);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_read ? 'Tag read' : 'Hold the tag near the phone', style: AppText.sectionTitle),
            const SizedBox(height: 6),
            Text(
              _read ? widget.tag : 'Keep the RFID / NFC tag against the back of the phone',
              textAlign: TextAlign.center,
              style: _read ? AppText.bodyStrong.copyWith(color: AppColors.primary) : AppText.secondary,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 150,
              height: 150,
              child: _read
                  ? const Icon(Icons.check_circle_rounded, size: 84, color: AppColors.green)
                  : const PulseRings(icon: Icons.contactless_rounded),
            ),
            const SizedBox(height: 16),
            if (!_read)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
          ],
        ),
      ),
    );
  }
}

/// "This tag belongs to MTR-00123 – View asset?" Returns true for View Asset.
Future<bool> confirmViewExisting(BuildContext context, String code, String assetId, String assetName) {
  return showConfirmDialog(
    context,
    title: 'Tag already registered',
    message: '$code belongs to $assetId – $assetName. View asset?',
    confirmLabel: 'View Asset',
  );
}
