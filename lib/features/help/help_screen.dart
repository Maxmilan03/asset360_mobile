import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';

/// Help & Support FAQ (question, answer).
const helpFaqs = [
  (
    'How do I scan an asset tag?',
    'Tap the violet Scan button in the bottom bar. Point the camera at the QR code or barcode on the tag; the '
        'asset opens as soon as it is read. Use the NFC, RFID or BLE tabs for those tags, or Manual Entry to type '
        'the asset ID. Torch and "scan from gallery" are on the camera view.',
  ),
  (
    'What happens when I scan a tag that is not registered?',
    'Asset360 shows "Tag not registered" with the code it read. Tap Register Asset to open Asset Registration '
        'with the barcode or RFID tag already filled in, or Scan again.',
  ),
  (
    'How do I complete a work order?',
    'Open the work order from Work → Maintenance (or Home → My Tasks). Work through the tasks in order, tick each '
        'checklist item and tap Complete Task. When every task is done, change the status to Completed, or Closed '
        'to record the resolution, labour hours, parts used and your signature.',
  ),
  (
    'Why can\'t I close a work order?',
    'A work order can only be completed or closed when every task is done. Tasks that are still open are listed '
        'in the message; finish them first. On Hold always asks for a reason.',
  ),
  (
    'Can I work without an internet connection?',
    'Yes. When the phone is offline a bar under the header says "You\'re offline". Everything you do is saved on '
        'the device straight away and added to the sync queue (More → Offline Sync → Pending Sync).',
  ),
  (
    'When do my offline changes upload?',
    'As soon as the phone is back online, if Automatic Sync allows that connection (Wi-Fi on by default, mobile '
        'data off). You can also tap Sync Now. Failed items stay in the queue with a Retry button.',
  ),
  (
    'How do I report a problem with an asset?',
    'Open the asset and tap Report Issue, or use Work → Issues → +. Add a title, priority and photos. Critical '
        'issues also raise an alert and notify the team; you can create a work order from the issue.',
  ),
  (
    'How do I move an asset to another location?',
    'Open the asset (or scan it) and tap Move Asset. Choose the destination, reason and date, then submit. '
        'Transfers need approval; once received, the asset\'s location updates everywhere, including Tracking.',
  ),
];

const supportEmail = 'asset360-support@purpleiq.ai';
const supportPhone = '+971 4 555 0360';

/// Help & Support (not in the designs; built in the style of the module screens).
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    context.showSnack('$label copied: $value');
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final faqs = helpFaqs
        .where((f) => q.isEmpty || f.$1.toLowerCase().contains(q) || f.$2.toLowerCase().contains(q))
        .toList();
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(title: 'Help & Support', subtitle: 'FAQs, contact support and report a bug'),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search help (e.g. offline, scan, work order)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(tooltip: 'Clear search', onPressed: _clearSearch, icon: const Icon(Icons.close_rounded)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Frequently Asked Questions (${faqs.length})',
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: LoadingGate(
              rows: 4,
              card: false,
              child: faqs.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No answers found',
                      message: 'Nothing matches "${_query.trim()}". Try another word or contact support below.',
                      actionLabel: 'Clear search',
                      onAction: _clearSearch,
                    )
                  : Column(
                      children: [
                        for (final (question, answer) in faqs)
                          ExpansionTile(
                            key: PageStorageKey(question),
                            shape: const Border(),
                            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                            leading: Icon(Icons.help_outline_rounded, color: AppColors.primary),
                            title: Text(question, style: AppText.bodyStrong),
                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(answer, style: AppText.body.copyWith(height: 1.45))],
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Contact Support',
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Column(
              children: [
                for (final (icon, label, value) in [
                  (Icons.email_outlined, 'Email', supportEmail),
                  (Icons.phone_outlined, 'Phone', supportPhone),
                ])
                  ListTile(
                    leading: IconSquare(icon: icon, tone: TileTone.lavender, size: 40),
                    title: Text(label, style: AppText.caption),
                    subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                    trailing: IconButton(
                      tooltip: 'Copy $label',
                      onPressed: () => _copy(label, value),
                      icon: Icon(Icons.copy_rounded, color: AppColors.primary),
                    ),
                    onTap: () => _copy(label, value),
                  ),
                ListTile(
                  leading: IconSquare(icon: Icons.schedule_rounded, tone: TileTone.mint, size: 40),
                  title: Text('Hours', style: AppText.caption),
                  subtitle: Text('Sun–Thu, 8 AM – 6 PM (Gulf Standard Time)', style: AppText.bodyStrong),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => context.push(Routes.reportBug),
            child: Row(
              children: [
                IconSquare(icon: Icons.bug_report_outlined, tone: TileTone.pink, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Report a bug', style: AppText.bodyStrong),
                      Text('Tell us what went wrong; attach a screenshot', style: AppText.caption),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Report a bug: what happened, steps, severity and a screenshot.
class ReportBugScreen extends StatefulWidget {
  const ReportBugScreen({super.key});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  static const _areas = ['Scanning', 'Work Orders', 'Inspections', 'Offline Sync', 'Assets', 'Other'];
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _shots = <String>[];
  String? _area;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _sending = false);
    final ref =
        'BUG-${DemoClock.now.year}-${(DemoClock.now.millisecondsSinceEpoch ~/ 1000 % 10000).toString().padLeft(4, '0')}';
    await showSuccessSheet(
      context,
      title: 'Bug report sent',
      message:
          'Thank you. Reference $ref${_shots.isEmpty ? '' : ' with ${_shots.length} screenshot${_shots.length == 1 ? '' : 's'}'}. '
          'Support will reply to your email within one working day.',
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomActions: Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('Send Report'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: context.pagePadding,
          children: [
            const PageTitle(title: 'Report a Bug', subtitle: 'Help us fix it quickly'),
            const SizedBox(height: 12),
            const FieldLabel('What went wrong?', required: true),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Sync stops at 50%'),
              validator: (v) => (v ?? '').trim().length < 5 ? 'Describe the problem in a few words' : null,
            ),
            const SizedBox(height: 12),
            const FieldLabel('Area', required: true),
            DropdownButtonFormField<String>(
              initialValue: _area,
              isExpanded: true,
              hint: const Text('Select the area'),
              items: [for (final a in _areas) DropdownMenuItem(value: a, child: Text(a))],
              validator: (v) => v == null ? 'Select the area' : null,
              onChanged: (v) => setState(() => _area = v),
            ),
            const SizedBox(height: 12),
            const FieldLabel('Steps to reproduce'),
            TextFormField(
              controller: _details,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: '1. Open …  2. Tap …  3. See …'),
            ),
            const SizedBox(height: 4),
            PhotoStrip(
              photos: _shots,
              addLabel: 'Attach Screenshot',
              onAdd: (p) => setState(() => _shots.add(p)),
              onRemove: (i) => setState(() => _shots.removeAt(i)),
            ),
          ],
        ),
      ),
    );
  }
}
