import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';

/// Plays a local video file with a play / pause button and a progress bar.
/// [onDuration] reports the length once the file is loaded (e.g. to enforce a maximum).
class VideoPreview extends StatefulWidget {
  const VideoPreview({super.key, required this.path, this.onDuration, this.height = 220});

  final String path;
  final ValueChanged<Duration>? onDuration;
  final double height;

  /// Tests: skip the platform player (it has no implementation in widget tests).
  @visibleForTesting
  static bool debugDisablePlayer = false;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VideoPreview old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (VideoPreview.debugDisablePlayer) {
      setState(() => _failed = true);
      return;
    }
    final c = VideoPlayerController.file(File(widget.path));
    _controller = c;
    try {
      await c.initialize();
      if (!mounted || _controller != c) return;
      c.addListener(_tick);
      widget.onDuration?.call(c.value.duration);
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _tick() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _controller?.removeListener(_tick);
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ready)
            AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))
          else if (_failed)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_rounded, color: Colors.white70, size: 40),
                const SizedBox(height: 6),
                Text(
                  widget.path.split(RegExp(r'[/\\]')).last,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            )
          else
            const CircularProgressIndicator(color: Colors.white),
          if (ready)
            IconButton.filled(
              tooltip: c.value.isPlaying ? 'Pause' : 'Play',
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              iconSize: 36,
              onPressed: _toggle,
              icon: Icon(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
            ),
          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                colors: VideoProgressColors(playedColor: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
