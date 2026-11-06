import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_repository.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_common.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// API mode Assign Custodian, Check Out and Move Asset.
///
/// Assign Custodian and Check Out: POST /api/asset-assignments with AssignTo = "Employee" and the
/// Master Data employee (record id, employee number, name, designation, department), the way the
/// web's Assign Asset wizard does. The server copies the employee onto the asset's assignment
/// (assignedToUserId / assignedToName / custodianDepartment) and sets its status to "Assigned".
/// Check In and Move have no backend yet ("Not available yet").

/// Status the Asset service gives an asset while it is in an active assignment.
const assignedStatus = 'Assigned';

/// The chosen employee and their details card.
class _EmployeePicker extends ConsumerWidget {
  const _EmployeePicker({required this.label, required this.employeeId, required this.onChanged, this.error});

  final String label;
  final String? employeeId;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = employeeById(ref, employeeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        formField(
          label,
          required: true,
          PersonField(
            personId: employeeId,
            title: 'Select $label',
            hint: 'Search by name or employee ID',
            error: error,
            onChanged: onChanged,
          ),
        ),
        if (e != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SectionCard(
              title: 'Employee Details',
              child: Column(
                children: [
                  InfoRow(label: 'Employee ID', value: e.employeeCode.isEmpty ? '—' : e.employeeCode, labelWidth: 96),
                  InfoRow(label: 'Designation', value: e.designation ?? '—', labelWidth: 96),
                  InfoRow(label: 'Department', value: e.department?.name ?? '—', labelWidth: 96),
                  if (e.phone != null) InfoRow(label: 'Phone', value: e.phone!, labelWidth: 96),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The Master Data employee with record id [id] (null while loading or unknown). [watch] = false
/// in tap handlers.
MdEmployee? employeeById(WidgetRef ref, String? id, {bool watch = true}) {
  if (id == null) return null;
  final list = watch ? ref.watch(mdEmployeesProvider) : ref.read(mdEmployeesProvider);
  return list.value?.where((e) => e.id == id).firstOrNull;
}

/// Builds the request for [employee] (all its Master Data facts are copied, as the web does).
CreateAssetAssignmentRequest assignmentFor(
  AssetRegistration r,
  MdEmployee employee, {
  required String type,
  required DateTime from,
  DateTime? to,
  String? purpose,
  String? remarks,
}) => CreateAssetAssignmentRequest(
  assetRegistrationIds: [r.assetRegistrationId],
  assignmentType: type,
  fromDate: from,
  toDate: to,
  employeeId: employee.id,
  employeeCode: blankToNull(employee.employeeCode),
  employeeName: employee.name,
  designation: employee.designation,
  departmentId: employee.department?.id,
  departmentName: employee.department?.name,
  purpose: purpose,
  remarks: remarks,
);

/// Mixin for the two assignment forms: sends the request and maps the server's field errors.
mixin _AssignmentSubmit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final errors = <String, String>{};
  bool busy = false;

  Future<void> submit(AssetRegistration r, CreateAssetAssignmentRequest request, String done) async {
    setState(() => busy = true);
    try {
      final a = await ref.read(assetsApiProvider).createAssignment(request);
      invalidateLiveAsset(ref, r.assetRegistrationId);
      ref.invalidate(liveAssetListProvider);
      if (mounted) finishAction(context, '$done${a.assignmentNumber.isEmpty ? '' : ' (${a.assignmentNumber})'}');
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.from(e);
      setState(() {
        busy = false;
        errors.addAll(err.fieldErrors);
      });
      context.showSnack(err.message);
    }
  }

  /// "In assignment ASG-… already" notice when the asset is assigned.
  Widget? assignedNotice(AssetRegistration r) {
    if (r.basicInformation.status != assignedStatus) return null;
    final who = r.locationAssignment.assignment.assignedToName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: IconLine(
        icon: Icons.info_outline_rounded,
        text:
            '${r.title} is already assigned${who == null ? '' : ' to $who'}. '
            'The server accepts one active assignment per asset.',
      ),
    );
  }
}

// ---------------------------------------------------------------- Assign Custodian

class LiveAssignCustodianScreen extends ConsumerStatefulWidget {
  const LiveAssignCustodianScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<LiveAssignCustodianScreen> createState() => _LiveAssignCustodianScreenState();
}

class _LiveAssignCustodianScreenState extends ConsumerState<LiveAssignCustodianScreen>
    with _AssignmentSubmit<LiveAssignCustodianScreen> {
  String? _employeeId;
  DateTime? _from = liveToday();
  DateTime? _to;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save(AssetRegistration r) {
    errors.clear();
    final e = employeeById(ref, _employeeId, watch: false);
    if (e == null) errors['Employee.EmployeeId'] = 'Choose the custodian';
    if (_from == null) errors['FromDate'] = 'Choose the effective date';
    if (_from != null && _to != null && _to!.isBefore(_from!)) {
      errors['ToDate'] = 'The end date cannot be before the start';
    }
    setState(() {});
    if (errors.isNotEmpty) return;
    submit(
      r,
      assignmentFor(
        r,
        e!,
        type: CreateAssetAssignmentRequest.custodian,
        from: _from!,
        to: _to,
        remarks: blankToNull(_notes.text),
      ),
      '${r.title}: custodian set to ${e.name}',
    );
  }

  @override
  Widget build(BuildContext context) => LiveActionPage(
    action: MoreAction.assignCustodian,
    assetId: widget.assetId,
    button: (r) => busyButton(busy: busy, onPressed: () => _save(r), label: 'Assign Custodian', icon: Icons.person_add),
    builder: (context, r) {
      final current = r.locationAssignment.assignment.assignedToName;
      return [
        ?assignedNotice(r),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text('Current custodian: ${current ?? 'none'}', style: AppText.caption),
        ),
        _EmployeePicker(
          label: 'Custodian',
          employeeId: _employeeId,
          error: errors['Employee.EmployeeId'],
          onChanged: (id) => setState(() {
            _employeeId = id;
            errors.remove('Employee.EmployeeId');
          }),
        ),
        formField(
          'Effective Date',
          required: true,
          DateBox(
            value: _from,
            error: errors['FromDate'],
            onPicked: (d) => setState(() {
              _from = d;
              errors.remove('FromDate');
            }),
          ),
        ),
        formField(
          'End Date (empty = open ended)',
          DateBox(
            value: _to,
            firstDate: _from,
            error: errors['ToDate'],
            hint: 'Open ended',
            onPicked: (d) => setState(() {
              _to = d;
              errors.remove('ToDate');
            }),
          ),
        ),
        formField(
          'Notes',
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: inputStyle,
            decoration: InputDecoration(hintText: 'Why this person is responsible', errorText: errors['Remarks']),
          ),
        ),
      ];
    },
  );
}

// ---------------------------------------------------------------- Check Out / Check In

class LiveCheckInOutScreen extends ConsumerStatefulWidget {
  const LiveCheckInOutScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<LiveCheckInOutScreen> createState() => _LiveCheckInOutScreenState();
}

class _LiveCheckInOutScreenState extends ConsumerState<LiveCheckInOutScreen>
    with _AssignmentSubmit<LiveCheckInOutScreen> {
  int _tab = 0;
  String? _employeeId;
  DateTime? _return;
  final _purpose = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _purpose.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _checkOut(AssetRegistration r) {
    errors.clear();
    final e = employeeById(ref, _employeeId, watch: false);
    if (e == null) errors['Employee.EmployeeId'] = 'Choose who takes the asset';
    setState(() {});
    if (errors.isNotEmpty) return;
    submit(
      r,
      assignmentFor(
        r,
        e!,
        type: CreateAssetAssignmentRequest.checkOut,
        from: liveToday(),
        to: _return,
        purpose: blankToNull(_purpose.text),
        remarks: blankToNull(_notes.text),
      ),
      '${r.title} checked out to ${e.name}${_return == null ? '' : ' until ${liveDate(_return)}'}',
    );
  }

  @override
  Widget build(BuildContext context) => LiveActionPage(
    action: MoreAction.checkInOut,
    assetId: widget.assetId,
    button: (r) => _tab == 0
        ? busyButton(busy: busy, onPressed: () => _checkOut(r), label: 'Check Out', icon: Icons.logout_rounded)
        : FilledButton(onPressed: () => showNotAvailableYet(context, 'Check In'), child: const Text('Check In')),
    builder: (context, r) => [
      SegmentTabs(
        tabs: const [SegmentTab('Check Out'), SegmentTab('Check In')],
        selected: _tab,
        onChanged: (i) => setState(() {
          _tab = i;
          errors.clear();
        }),
      ),
      const SizedBox(height: 14),
      if (_tab == 1)
        const NotAvailableYet(feature: 'Check In', icon: Icons.login_rounded)
      else ...[
        ?assignedNotice(r),
        _EmployeePicker(
          label: 'Assign To',
          employeeId: _employeeId,
          error: errors['Employee.EmployeeId'],
          onChanged: (id) => setState(() {
            _employeeId = id;
            errors.remove('Employee.EmployeeId');
          }),
        ),
        formField(
          'Expected Return Date',
          DateBox(
            value: _return,
            firstDate: liveToday(),
            hint: 'Open ended',
            error: errors['ToDate'],
            onPicked: (d) => setState(() {
              _return = d;
              errors.remove('ToDate');
            }),
          ),
        ),
        formField(
          'Purpose',
          TextField(
            controller: _purpose,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: inputStyle,
            decoration: InputDecoration(hintText: 'e.g. Site visit, project work', errorText: errors['Purpose']),
          ),
        ),
        formField(
          'Notes',
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: inputStyle,
            decoration: InputDecoration(hintText: 'Anything to know', errorText: errors['Remarks']),
          ),
        ),
      ],
    ],
  );
}

// ---------------------------------------------------------------- Move Asset

/// API mode Move Asset: the new location from the Master Data tree (cascading Country → Room or a
/// scanned location tag). No service can move an asset yet, so Move says "Not available yet" and
/// nothing is saved.
class LiveMoveScreen extends ConsumerStatefulWidget {
  const LiveMoveScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<LiveMoveScreen> createState() => _LiveMoveScreenState();
}

class _LiveMoveScreenState extends ConsumerState<LiveMoveScreen> {
  MdLocationPath _to = MdLocationPath.empty;
  String? _error;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _move() {
    final ok = (_to.level?.index ?? -1) >= MdLocationLevel.floor.index;
    setState(() => _error = ok ? null : 'Choose at least the country, site, building and floor');
    if (ok) showNotAvailableYet(context, 'Move Asset');
  }

  @override
  Widget build(BuildContext context) => LiveActionPage.titled(
    title: 'Move Asset',
    subtitle: 'Move the asset to another location',
    assetId: widget.assetId,
    button: (_) =>
        FilledButton.icon(onPressed: _move, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('Move')),
    builder: (context, r) => [
      const FieldLabel('Current Location'),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: IconLine(
          icon: Icons.location_on_outlined,
          text: r.locationAssignment.location.locationPath ?? 'No location yet',
        ),
      ),
      const FieldLabel('New Location', required: true),
      MasterLocationField(value: _to, errorText: _error, onChanged: (v) => setState(() => _to = v)),
      const SizedBox(height: 14),
      formField(
        'Reason',
        TextField(
          controller: _reason,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          style: inputStyle,
          decoration: const InputDecoration(hintText: 'Why the asset moves'),
        ),
      ),
      Text(
        'Moving assets is not connected to the server yet; nothing is saved.',
        style: AppText.caption.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}
