import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../widgets/widgets.dart';
import 'checklist.dart';

/// "Checklist Progress  8 / 12" with a bar.
class ChecklistProgress extends StatelessWidget {
  const ChecklistProgress({
    super.key,
    required this.done,
    required this.total,
    this.title = 'Checklist Progress',
    this.color,
  });

  final int done;
  final int total;
  final String title;
  final Color? color;
  Color get _color => color ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppText.bodyStrong)),
              Text('$done / $total', style: AppText.bodyStrong),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              color: _color,
              backgroundColor: AppColors.greyBg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Accordion header: number circle, "1. Visual Inspection", "answered / total" and a chevron.
class CheckSectionHeader extends StatelessWidget {
  const CheckSectionHeader({
    super.key,
    required this.number,
    required this.section,
    required this.expanded,
    required this.onTap,
  });

  final int number;
  final CheckSection section;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = section.complete;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: expanded ? AppColors.primarySoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: expanded ? AppColors.primary : (complete ? AppColors.green : AppColors.textMuted),
              ),
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('$number. ${section.title}', style: AppText.bodyStrong.copyWith(fontSize: 13.5))),
            Text('${section.answered} / ${section.items.length}', style: AppText.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(width: 6),
            Icon(
              expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// One checklist item, rendered by its [CheckItem.type]. Every change is reported as the updated item.
class CheckItemView extends StatefulWidget {
  const CheckItemView({
    super.key,
    required this.item,
    required this.onChanged,
    this.enabled = true,
    this.showCode = true,
    this.onAddFinding,
  });

  final CheckItem item;
  final ValueChanged<CheckItem> onChanged;
  final bool enabled;
  final bool showCode;

  /// Offered next to an out-of-range number ("Add Finding").
  final VoidCallback? onAddFinding;

  @override
  State<CheckItemView> createState() => _CheckItemViewState();
}

class _CheckItemViewState extends State<CheckItemView> {
  late final _text = TextEditingController(text: _fieldValue(widget.item));
  final _focus = FocusNode();

  static String _fieldValue(CheckItem i) => (i.type == CheckType.tick ? i.reading : i.value) ?? '';

  @override
  void didUpdateWidget(CheckItemView old) {
    super.didUpdateWidget(old);
    final v = _fieldValue(widget.item);
    if (!_focus.hasFocus && _text.text != v) _text.text = v;
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  CheckItem get _i => widget.item;

  @override
  Widget build(BuildContext context) {
    if (_i.type == CheckType.tick) return _tick();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.showCode)
                SizedBox(width: 30, child: Text(_i.code, style: AppText.body.copyWith(fontSize: 12.5))),
              Expanded(
                child: Text(
                  _i.required ? _i.label : '${_i.label} (optional)',
                  style: AppText.body.copyWith(fontSize: 12.5, color: AppColors.text),
                ),
              ),
              if (_i.answered)
                Icon(
                  _i.negative ? Icons.error_rounded : Icons.check_circle_rounded,
                  size: 20,
                  color: _i.negative ? AppColors.red : AppColors.green,
                ),
            ],
          ),
          const SizedBox(height: 8),
          switch (_i.type) {
            CheckType.choice || CheckType.yesNo => _choices(),
            CheckType.number => _number(),
            CheckType.text => TextField(
              controller: _text,
              focusNode: _focus,
              enabled: widget.enabled,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Type here'),
              onChanged: (v) => widget.onChanged(_i.copyWith(value: v)),
            ),
            CheckType.photo => PhotoStrip(
              photos: _i.photos,
              thumbWidth: 96,
              thumbHeight: 72,
              onAdd: widget.enabled ? (p) => widget.onChanged(_i.copyWith(photos: [..._i.photos, p])) : null,
              onRemove: widget.enabled
                  ? (n) => widget.onChanged(_i.copyWith(photos: [..._i.photos]..removeAt(n)))
                  : null,
            ),
            CheckType.signature =>
              widget.enabled
                  ? SignaturePad(onChanged: (s) => widget.onChanged(_i.copyWith(signature: s)), height: 120)
                  : Container(
                      height: 90,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CustomPaint(painter: SignaturePainter.saved(_i.signature)),
                    ),
            CheckType.tick => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }

  /// Checkbox, label and an optional reading with its unit (work-order task style).
  Widget _tick() {
    void toggle() => widget.onChanged(_i.answered ? _i.copyWith(clearValue: true) : _i.copyWith(value: CheckItem.done));
    return Row(
      children: [
        Checkbox(value: _i.answered, onChanged: widget.enabled ? (_) => toggle() : null),
        Expanded(
          child: GestureDetector(
            onTap: widget.enabled ? toggle : null,
            child: Text(_i.label, style: AppText.body.copyWith(fontSize: 12.5)),
          ),
        ),
        if (_i.unit != null) ...[
          SizedBox(
            width: 80,
            child: TextField(
              controller: _text,
              focusNode: _focus,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.all(8),
                errorText: _i.inRange == false ? '' : null,
                errorStyle: const TextStyle(height: 0, fontSize: 0),
              ),
              onChanged: (v) => widget.onChanged(_i.copyWith(reading: v.trim())),
            ),
          ),
          SizedBox(width: 40, child: Text('  ${_i.unit}', style: AppText.caption)),
        ],
      ],
    );
  }

  Widget _choices() {
    return Row(
      children: [
        for (final (n, o) in _i.options.indexed) ...[
          if (n > 0) const SizedBox(width: 8),
          Expanded(
            child: RadioChip(
              label: o,
              selected: _i.value == o,
              negative: n > 0,
              onTap: widget.enabled ? () => widget.onChanged(_i.copyWith(value: o)) : null,
            ),
          ),
        ],
        // Two options leave room on the right, like the design's yes/no rows.
        if (_i.options.length == 2) const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  Widget _number() {
    final inRange = _i.inRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 5,
              child: TextField(
                controller: _text,
                focusNode: _focus,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(
                  hintText: 'Enter value',
                  isDense: true,
                  suffixIcon: _i.unit == null
                      ? null
                      : Container(
                          width: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: AppColors.border)),
                          ),
                          child: Text(_i.unit!, style: AppText.caption.copyWith(color: AppColors.text)),
                        ),
                ),
                onChanged: (v) =>
                    widget.onChanged(v.trim().isEmpty ? _i.copyWith(clearValue: true) : _i.copyWith(value: v.trim())),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.centerLeft,
                child: !_i.hasRange
                    ? const SizedBox.shrink()
                    : inRange == null
                    ? IconButton(
                        tooltip: 'Expected range: ${_i.rangeLabel}',
                        onPressed: () => context.showSnack('Expected range: ${_i.rangeLabel}'),
                        icon: Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
                      )
                    : StatusChip(
                        inRange ? 'Normal Range: ${_i.rangeLabel}' : 'Out of range (${_i.rangeLabel})',
                        tone: inRange ? ChipTone.green : ChipTone.red,
                      ),
              ),
            ),
          ],
        ),
        if (inRange == false && widget.onAddFinding != null && widget.enabled)
          TextButton.icon(
            onPressed: widget.onAddFinding,
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Add Finding'),
          ),
      ],
    );
  }
}

/// Radio chip: circle + label; selected = green with a check (red for a negative option).
class RadioChip extends StatelessWidget {
  const RadioChip({super.key, required this.label, required this.selected, this.onTap, this.negative = false});

  final String label;
  final bool selected;
  final bool negative;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = negative ? ChipTone.red : ChipTone.green;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? tone.background : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? tone.foreground.withValues(alpha: .5) : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: selected ? tone.foreground : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? tone.foreground : AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
