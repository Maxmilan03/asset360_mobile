import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/core/widgets/dialogs.dart';
import 'package:asset360_mobile/core/widgets/feedback.dart';
import 'package:asset360_mobile/core/widgets/photo_strip.dart';

bool _isImage(String name) {
  final n = name.toLowerCase();
  return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.webp');
}

/// File row: type icon, name, size and a chevron (or a remove button). Tap → preview.
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({super.key, required this.attachment, this.onRemove});

  final Attachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final pdf = a.name.toLowerCase().endsWith('.pdf');
    return InkWell(
      onTap: () => showAttachmentPreview(context, a),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              pdf
                  ? Icons.picture_as_pdf_rounded
                  : _isImage(a.name)
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
              color: pdf ? AppColors.red : AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(a.sizeLabel, style: AppText.caption),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove ${a.name}',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Preview sheet: photos are shown; other files show their details (no in-app PDF viewer offline).
Future<void> showAttachmentPreview(BuildContext context, Attachment a) {
  final image = _isImage(a.name) && a.path != null;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => sheetFrame(context, [
      SheetTitle(a.name, subtitle: a.sizeLabel),
      if (image)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(image: photoProvider(a.path!), errorBuilder: photoError, height: 260, fit: BoxFit.cover),
        )
      else
        Container(
          height: 200,
          decoration: BoxDecoration(color: AppColors.greyBg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                a.name.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.description_outlined,
                size: 64,
                color: a.name.toLowerCase().endsWith('.pdf') ? AppColors.red : AppColors.primary,
              ),
              const SizedBox(height: 10),
              Text(a.name, textAlign: TextAlign.center, style: AppText.bodyStrong),
            ],
          ),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () {
          Navigator.pop(context);
          context.showSnack('${a.name} would open in the device viewer (demo)');
        },
        icon: const Icon(Icons.open_in_new_rounded),
        label: const Text('Open'),
      ),
    ]),
  );
}
