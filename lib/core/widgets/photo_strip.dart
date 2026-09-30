import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import 'feedback.dart';

/// A photo is either a bundled asset ('assets/images/…') or a picked file path.
ImageProvider photoProvider(String path) =>
    path.startsWith('assets/') ? AssetImage(path) : FileImage(File(path)) as ImageProvider;

/// Horizontal row of photo thumbnails followed by an "Add Photo" box.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.photos,
    required this.onAdd,
    this.onRemove,
    this.title,
    this.thumbWidth = 112,
    this.thumbHeight = 84,
  });

  final List<String> photos;
  final ValueChanged<String> onAdd;
  final ValueChanged<int>? onRemove;

  /// e.g. "Photos" → rendered as "Photos (2)".
  final String? title;
  final double thumbWidth;
  final double thumbHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[Text('$title (${photos.length})', style: AppText.bodyStrong), const SizedBox(height: 8)],
        SizedBox(
          height: thumbHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (i == photos.length) {
                return _AddPhotoBox(
                  width: thumbWidth,
                  onTap: () async {
                    final path = await pickPhoto(context);
                    if (path != null) onAdd(path);
                  },
                );
              }
              return _Thumb(
                path: photos[i],
                width: thumbWidth,
                onTap: () => openPhotoViewer(context, photos, initialIndex: i),
                onRemove: onRemove == null ? null : () => onRemove!(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Lets the user choose Camera or Gallery, then returns the picked file path.
Future<String?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Add Photo', style: AppText.sectionTitle),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    return file?.path;
  } catch (_) {
    if (context.mounted) {
      context.showSnack(
        source == ImageSource.camera
            ? 'Camera is not available. Allow camera access in Settings.'
            : 'Gallery is not available. Allow photo access in Settings.',
      );
    }
    return null;
  }
}

/// Full-screen, pinch-zoomable photo viewer with swipe between photos.
void openPhotoViewer(BuildContext context, List<String> photos, {int initialIndex = 0}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _PhotoViewer(photos: photos, initialIndex: initialIndex),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<String> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.photos.length}', style: const TextStyle(fontSize: 16)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image(image: photoProvider(widget.photos[i]), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, required this.width, required this.onTap, this.onRemove});

  final String path;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(image: photoProvider(path), width: width, height: double.infinity, fit: BoxFit.cover),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 16, color: AppColors.text),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddPhotoBox extends StatelessWidget {
  const _AddPhotoBox({required this.width, required this.onTap});

  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: CustomPaint(
        painter: DashedBorderPainter(color: AppColors.primary.withValues(alpha: .5), radius: 10),
        child: SizedBox(
          width: width,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_camera_rounded, color: AppColors.primary, size: 24),
              SizedBox(height: 6),
              Text(
                'Add Photo',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle outline (Add Photo, upload boxes).
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, this.radius = 10, this.dash = 5, this.gap = 4});

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color || old.radius != radius;
}
