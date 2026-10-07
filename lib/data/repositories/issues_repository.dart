import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/issues_mock.dart';
import '../models/common.dart';
import '../models/alert.dart';
import '../models/issue.dart';
import 'alerts_repository.dart';
import 'assets_repository.dart';
import 'maintenance_repository.dart';
import 'repo_utils.dart';
import 'session_repository.dart';
import 'sync_repository.dart';
import '../models/sync_item.dart';

class IssuesNotifier extends Notifier<List<Issue>> {
  @override
  List<Issue> build() => seedIssues();

  String get _me => ref.read(currentUserProvider).name;
  LogEntry _log(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  Issue? byId(String id) => state.firstWhereOrNull((i) => i.id == id);

  /// Every change also goes into the sync queue while offline.
  void _update(String id, Issue Function(Issue) f, {String change = 'Updated', bool queue = true}) {
    state = replaceWhere(state, id, (i) => i.id, f);
    if (queue) _queue(id, change);
  }

  void _queue(String id, String change) {
    final i = byId(id);
    if (i != null) ref.queueOffline(SyncKind.issue, id, '${i.title} · $change', refId: id);
  }

  /// Report Issue / Defect. Returns the new ID.
  String report({
    required String assetId,
    required String title,
    required String type,
    required String priority,
    required String description,
    required String location,
    List<String> photos = const [],
    List<Attachment> attachments = const [],
    String? reporterId,
  }) {
    final id = nextId('ISS-2026-', state.map((i) => i.id));
    final reporter = reporterId ?? ref.read(currentUserProvider).id;
    state = [
      Issue(
        id: id,
        assetId: assetId,
        title: title,
        type: type,
        priority: priority,
        status: IssueStatus.open,
        reporterId: reporter,
        reportedAt: DemoClock.now,
        location: location,
        description: description,
        photos: photos,
        attachments: attachments,
        timeline: [
          _log(
            'Issue reported',
            reporter == ref.read(currentUserProvider).id
                ? null
                : 'On behalf of ${ref.read(personByIdProvider(reporter))?.name}',
          ),
        ],
      ),
      ...state,
    ];
    ref.read(assetsProvider.notifier).addEvent(assetId, 'Issue $id reported', note: title);
    // Critical issues raise an alert, which also posts a notification (bell badge).
    if (priority == 'Critical') {
      ref
          .read(alertsProvider.notifier)
          .raise(
            type: 'Critical Issue Reported',
            severity: Severity.critical,
            assetId: assetId,
            message: '$id: $title ($assetId)',
            location: location,
          );
    }
    _queue(id, 'Reported');
    for (final p in byId(id)?.photos ?? const <String>[]) {
      ref.queueOffline(SyncKind.photo, syncFileName(p), 'Issue Photo', refId: id);
    }
    return id;
  }

  /// The asset moved: open issues that showed its old location show the new one.
  void followAsset(String assetId, String from, String to) => state = [
    for (final i in state) i.assetId == assetId && i.isOpen && i.location == from ? i.copyWith(location: to) : i,
  ];

  void updateStatus(String id, String status, {String? note}) => _update(
    id,
    (i) => i.copyWith(
      status: status,
      resolvedAt: status == IssueStatus.resolved || status == IssueStatus.closed ? DemoClock.now : null,
      clearResolved: IssueStatus.isOpen(status),
      timeline: [...i.timeline, _log('Status changed to $status', note)],
    ),
  );

  void edit(String id, {String? title, String? description, String? priority, String? type, String? location}) =>
      _update(
        id,
        (i) => i.copyWith(
          title: title,
          description: description,
          priority: priority,
          type: type,
          location: location,
          timeline: [...i.timeline, _log('Issue details edited')],
        ),
      );

  void assign(String id, String personId, {String team = 'Maintenance Team'}) {
    final p = ref.read(personByIdProvider(personId));
    _update(
      id,
      (i) => i.copyWith(
        assigneeId: personId,
        assignedTeam: team,
        timeline: [...i.timeline, _log('Assigned to ${p?.name}')],
      ),
    );
  }

  /// Close Issue: resolution notes, status Closed.
  void close(String id, String resolution) => _update(
    id,
    (i) => i.copyWith(
      status: IssueStatus.closed,
      resolution: resolution,
      resolvedAt: DemoClock.now,
      timeline: [...i.timeline, _log('Issue closed', resolution)],
    ),
  );

  void addComment(String id, String text) =>
      _update(id, (i) => i.copyWith(timeline: [...i.timeline, _log('Comment', text)]));

  void addAttachments(String id, List<Attachment> files) => _update(
    id,
    (i) => i.copyWith(
      attachments: [...i.attachments, ...files],
      timeline: [...i.timeline, _log('${files.length} attachment${files.length == 1 ? '' : 's'} added')],
    ),
  );

  /// Links a WO created from the Create Work Order form.
  void linkWorkOrder(String id, String woId) => _update(
    id,
    (i) => i.copyWith(
      workOrderIds: [...i.workOrderIds, woId],
      status: i.status == IssueStatus.open ? IssueStatus.inProgress : i.status,
      timeline: [...i.timeline, _log('Work order $woId created')],
    ),
  );

  void addPhoto(String id, String path) {
    _update(id, (i) => i.copyWith(photos: [...i.photos, path]), queue: false);
    ref.queueOffline(SyncKind.photo, syncFileName(path), 'Issue Photo', refId: id);
  }

  void removePhoto(String id, int index) => _update(id, (i) => i.copyWith(photos: [...i.photos]..removeAt(index)));

  /// Creates a breakdown WO from the issue and links it. Returns the WO ID.
  String createWorkOrder(String id) {
    final issue = byId(id)!;
    final asset = ref.read(assetByIdProvider(issue.assetId));
    final woId = ref
        .read(workOrdersProvider.notifier)
        .create(
          assetId: issue.assetId,
          title: '${asset?.type ?? issue.assetId} – ${issue.title}',
          priority: issue.priority,
          category: 'Corrective Maintenance',
          workType: issue.type == 'Breakdown' ? 'Breakdown' : 'Corrective',
          dueAt: DemoClock.now.add(Duration(hours: issue.priority == 'Critical' ? 4 : 24)),
          description: 'Created from $id. ${issue.description}',
          assigneeId: issue.assigneeId,
          issueId: id,
        );
    _update(
      id,
      (i) => i.copyWith(
        workOrderIds: [...i.workOrderIds, woId],
        status: i.status == IssueStatus.open ? IssueStatus.inProgress : i.status,
        timeline: [...i.timeline, _log('Work order $woId created')],
      ),
    );
    return woId;
  }
}

final issuesProvider = NotifierProvider<IssuesNotifier, List<Issue>>(IssuesNotifier.new);

final issueByIdProvider = Provider.family<Issue?, String>(
  (ref, id) => ref.watch(issuesProvider).firstWhereOrNull((i) => i.id == id),
);

extension IssueQueries on List<Issue> {
  List<Issue> mine(String userId) => where((i) => i.reporterId == userId).toList();

  /// "Open" tab: Open + In Progress.
  List<Issue> get open => where((i) => i.isOpen).toList();
  List<Issue> get inProgress => where((i) => i.status == IssueStatus.inProgress).toList();
  List<Issue> get resolved => where((i) => !i.isOpen).toList();

  /// Search by issue number, asset, location, title or description.
  List<Issue> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return this;
    return where(
      (i) => '${i.id} ${i.assetId} ${i.location} ${i.title} ${i.description}'.toLowerCase().contains(s),
    ).toList();
  }

  List<Issue> forAsset(String assetId) => where((i) => i.assetId == assetId).toList();
}
