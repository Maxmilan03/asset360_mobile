import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:asset360_mobile/features/more/tracking/tracking_map.dart';
import 'package:asset360_mobile/features/more/tracking/tracking_widgets.dart';

/// Recent Activity → View All: every movement event, newest first (grows with the live simulation).
class TrackingActivityScreen extends ConsumerWidget {
  const TrackingActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(trackingLiveProvider);
    final activity = ref.watch(trackingProvider).activity;
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: PageTitle(title: 'Activity Log', subtitle: '${activity.length} movement events today'),
          ),
          Expanded(
            child: LoadingGate(
              rows: 4,
              child: activity.isEmpty
                  ? const SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.timeline_rounded,
                        title: 'No movement yet today',
                        message: 'Zone entries and exits of tracked assets appear here.',
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + context.bottomInset),
                      itemCount: activity.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          child: TrackActivityRow(activity: activity[i]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Geofencing → + Add Zone: name the zone and drag a rectangle on the floor plan.
class AddGeofenceScreen extends ConsumerStatefulWidget {
  const AddGeofenceScreen({super.key});

  @override
  ConsumerState<AddGeofenceScreen> createState() => _AddGeofenceScreenState();
}

class _AddGeofenceScreenState extends ConsumerState<AddGeofenceScreen> {
  final _name = TextEditingController();
  Offset? _start;
  Rect? _rect;
  String? _nameError;
  String? _rectError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Offset _frac(Offset local, Size size) =>
      Offset((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));

  void _save() {
    final name = _name.text.trim();
    final r = _rect;
    setState(() {
      _nameError = name.isEmpty
          ? 'Enter a zone name'
          : ref.read(trackingProvider).geofences.any((g) => g.name.toLowerCase() == name.toLowerCase())
          ? 'A zone with this name already exists'
          : null;
      _rectError = r == null || r.width < .05 || r.height < .05 ? 'Drag on the floor plan to draw the zone' : null;
    });
    if (_nameError != null || _rectError != null) return;
    ref.read(trackingProvider.notifier).addGeofence(name, left: r!.left, top: r.top, width: r.width, height: r.height);
    context.showSnack('Zone "$name" added with entry alerts on');
    context.pop();
  }

  Widget _canvas(TrackingState t) => LayoutBuilder(
    builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        key: const ValueKey('zone-canvas'),
        onPanStart: (d) => setState(() {
          _rectError = null;
          _start = _frac(d.localPosition, size);
          _rect = Rect.fromPoints(_start!, _start!);
        }),
        onPanUpdate: (d) => setState(() => _rect = Rect.fromPoints(_start!, _frac(d.localPosition, size))),
        child: SizedBox(
          height: size.height,
          child: TrackingMap(
            entities: t.entities,
            geofences: t.geofences,
            draft: _rect,
            pinSize: 20,
            interactive: false,
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trackingProvider);
    return AppScaffold(
      bottomActions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _rect == null ? null : () => setState(() => _rect = null),
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: _save, child: const Text('Save Zone')),
          ),
        ],
      ),
      // Not scrollable while there is room: a scroll view would take the drag that draws the zone.
      // When the keyboard leaves too little height (small phones), the page scrolls with a fixed-height plan.
      body: LayoutBuilder(
        builder: (context, box) {
          final roomy = box.maxHeight >= 420;
          final page = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageTitle(title: 'Add Zone', subtitle: 'Name the geofence and drag to draw it'),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Zone name',
                  required: true,
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(hintText: 'e.g. Loading Bay', errorText: _nameError),
                    onChanged: (_) => _nameError == null ? null : setState(() => _nameError = null),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Draw the zone', style: AppText.bodyStrong),
                const SizedBox(height: 6),
                if (roomy) Expanded(child: _canvas(t)) else SizedBox(height: 260, child: _canvas(t)),
                const SizedBox(height: 6),
                Text(
                  _rectError ??
                      (_rect == null
                          ? 'Touch and drag across the plan. Existing zones are shown dashed.'
                          : 'Zone covers ${(_rect!.width * 100).round()}% × ${(_rect!.height * 100).round()}% of the floor'),
                  style: AppText.caption.copyWith(color: _rectError == null ? AppColors.textSecondary : AppColors.red),
                ),
              ],
            ),
          );
          return roomy ? page : SingleChildScrollView(child: page);
        },
      ),
    );
  }
}
