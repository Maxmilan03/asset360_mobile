import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Photo tab: large preview, camera button, ✕, thumbnail strip with "+". Video tab: record or pick
/// (max 60 s) with a play / pause preview. Both save to the asset (gallery / videos) with a caption.
class AddMediaScreen extends ConsumerStatefulWidget {
  const AddMediaScreen({super.key, required this.assetId});

  final String? assetId;

  /// Tests replace the camera / gallery pickers.
  @visibleForTesting
  static Future<String?> Function(BuildContext)? debugPickPhoto;
  @visibleForTesting
  static Future<String?> Function(BuildContext)? debugPickVideo;

  @override
  ConsumerState<AddMediaScreen> createState() => _AddMediaScreenState();
}

class _AddMediaScreenState extends ConsumerState<AddMediaScreen> {
  int _tab = 0; // 0 = Photo, 1 = Video
  List<String> _photos = [];
  int _current = 0;
  String? _video;
  final _caption = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final path = await (AddMediaScreen.debugPickPhoto ?? pickPhoto)(context);
    if (path == null || !mounted) return;
    setState(() {
      _photos = [..._photos, path];
      _current = _photos.length - 1;
      _error = null;
    });
  }

  void _removePhoto() => setState(() {
    _photos = [..._photos]..removeAt(_current);
    _current = _current.clamp(0, _photos.isEmpty ? 0 : _photos.length - 1);
  });

  Future<void> _pickVideo(ImageSource source) async {
    String? path;
    if (AddMediaScreen.debugPickVideo != null) {
      path = await AddMediaScreen.debugPickVideo!(context);
    } else {
      try {
        final file = await ImagePicker().pickVideo(
          source: source,
          maxDuration: const Duration(seconds: maxVideoSeconds),
        );
        path = file?.path;
      } catch (_) {
        if (mounted) {
          context.showSnack(
            source == ImageSource.camera
                ? 'Camera is not available. Allow camera access in Settings.'
                : 'Gallery is not available. Allow photo access in Settings.',
          );
        }
      }
    }
    if (path == null || !mounted) return;
    setState(() {
      _video = path;
      _error = null;
    });
  }

  /// A picked video longer than the limit is refused (the camera already stops at 60 s).
  void _checkDuration(Duration d) {
    if (d.inMilliseconds <= (maxVideoSeconds + 1) * 1000 || !mounted) return;
    setState(() {
      _video = null;
      _error = 'The video is ${d.inSeconds} s long – the limit is $maxVideoSeconds seconds';
    });
  }

  void _save(Asset a) {
    final caption = _caption.text.trim().isEmpty ? null : _caption.text.trim();
    final assets = ref.read(assetsProvider.notifier);
    if (_tab == 0) {
      if (_photos.isEmpty) {
        setState(() => _error = 'Add at least one photo');
        return;
      }
      for (final p in _photos) {
        assets.addPhoto(a.id, p, caption: caption);
      }
      finishAction(context, '${_photos.length} photo${_photos.length == 1 ? '' : 's'} added to ${a.id}');
    } else {
      if (_video == null) {
        setState(() => _error = 'Record or choose a video');
        return;
      }
      assets.addVideo(a.id, _video!, caption: caption);
      finishAction(context, 'Video added to ${a.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MoreActionPage(
      action: MoreAction.addMedia,
      assetId: widget.assetId,
      button: (a) => FilledButton(onPressed: () => _save(a), child: Text(_tab == 0 ? 'Save Photo' : 'Save Video')),
      builder: (context, a) => [
        SegmentTabs(
          tabs: const [SegmentTab('Photo'), SegmentTab('Video')],
          selected: _tab,
          onChanged: (i) => setState(() {
            _tab = i;
            _error = null;
          }),
        ),
        const SizedBox(height: 14),
        if (_tab == 0) ..._photoTab() else ..._videoTab(),
        fieldError(_error),
        const SizedBox(height: 14),
        formField(
          'Caption (optional)',
          TextField(
            controller: _caption,
            maxLength: 120,
            style: inputStyle,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Front panel after cleaning'),
          ),
        ),
        Text('${a.gallery.length} photos · ${a.videos.length} videos on ${a.id}', style: AppText.caption),
      ],
    );
  }

  List<Widget> _photoTab() => [
    Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.tileGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_photos.isEmpty)
            InkWell(
              onTap: _addPhoto,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 44, color: AppColors.textMuted),
                  const SizedBox(height: 6),
                  Text('Take or choose a photo', style: AppText.link),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () => openPhotoViewer(context, _photos, initialIndex: _current),
              child: Image(image: photoProvider(_photos[_current]), errorBuilder: photoError, fit: BoxFit.cover),
            ),
          if (_photos.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: 'Remove photo',
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: _removePhoto,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          Positioned(
            right: 10,
            bottom: 10,
            child: FloatingActionButton.small(
              heroTag: null,
              tooltip: 'Camera',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: _addPhoto,
              child: const Icon(Icons.photo_camera_rounded),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 10),
    SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == _photos.length) {
            return InkWell(
              onTap: _addPhoto,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 64,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: Tooltip(
                  message: 'Add photo',
                  child: Icon(Icons.add_rounded, color: AppColors.primary),
                ),
              ),
            );
          }
          return GestureDetector(
            onTap: () => setState(() => _current = i),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: i == _current ? AppColors.primary : AppColors.divider, width: 2),
                image: DecorationImage(image: photoProvider(_photos[i]), fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    ),
  ];

  List<Widget> _videoTab() => [
    if (_video != null)
      Stack(
        children: [
          VideoPreview(path: _video!, onDuration: _checkDuration),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              tooltip: 'Remove video',
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => setState(() => _video = null),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      )
    else
      Container(
        height: 160,
        decoration: BoxDecoration(color: AppColors.tileGrey, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_outlined, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 6),
            Text('Up to $maxVideoSeconds seconds', style: AppText.secondary),
          ],
        ),
      ),
    const SizedBox(height: 10),
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickVideo(ImageSource.camera),
            icon: const Icon(Icons.videocam_rounded, size: 18),
            label: const Text('Record Video'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickVideo(ImageSource.gallery),
            icon: const Icon(Icons.video_library_outlined, size: 18),
            label: const Text('Choose Video'),
          ),
        ),
      ],
    ),
  ];
}
