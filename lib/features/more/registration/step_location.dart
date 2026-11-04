import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/features/more/registration/registration_logic.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Step 3 Location & Assignment (AssetLocationAssignmentDto). Site › Building › Floor › Zone come
/// from the location tree (LocationField: dropdowns or a scanned location tag).
class StepLocation extends ConsumerWidget {
  const StepLocation({super.key, required this.form, required this.edit, this.locationError, this.dateError});

  final RegistrationForm form;
  final FormEdit edit;
  final String? locationError;
  final String? dateError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = form.locationAssignment.location, a = form.locationAssignment.assignment;
    final sites = countries[l.countryName] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegDropdown(
          label: 'Country',
          required: true,
          value: l.countryName,
          options: countries.keys.toList(),
          onChanged: (v) => edit(() {
            l.countryName = v;
            if (!(countries[v] ?? const []).contains(l.siteName)) {
              l
                ..siteName = null
                ..buildingName = null
                ..floorName = null
                ..zoneName = null;
            }
          }),
        ),
        if (l.countryName != null && sites.isNotEmpty) ...[
          LocationField(
            value: LocationValue(site: l.siteName, building: l.buildingName, floor: l.floorName, room: l.zoneName),
            roomLabel: 'Zone / Area',
            errorText: locationError,
            onChanged: (v) => edit(() {
              l
                ..siteName = v.site
                ..buildingName = v.building
                ..floorName = v.floor
                ..zoneName = v.room;
            }),
          ),
          regGap,
        ],
        RegTextField(
          label: 'Room / Location',
          value: l.roomName,
          hint: 'e.g. Generator Room GR-01, Bay 3',
          onChanged: (v) => edit(() => l.roomName = v),
        ),
        const FieldLabel('Location Path'),
        RegBreadcrumb(parts: l.parts, icon: Icons.location_on_outlined, empty: 'Choose the site, building and floor'),
        const RegSection('Assignment'),
        RegDropdown(
          label: 'Custodian / Department',
          required: true,
          value: a.custodianDepartment,
          options: departments,
          onChanged: (v) => edit(() => a.custodianDepartment = v),
        ),
        LabeledField(
          label: 'Assigned To',
          child: Row(
            children: [
              Expanded(
                child: PersonField(
                  personId: a.assignedToUserId,
                  hint: 'Select person (optional)',
                  title: 'Assigned To',
                  onChanged: (id) {
                    final p = ref.read(personByIdProvider(id));
                    edit(() {
                      a
                        ..assignedToUserId = id
                        ..assignedToName = p?.name;
                      if (p?.department != null && departments.contains(p!.department)) {
                        a.custodianDepartment ??= p.department;
                      }
                    });
                  },
                ),
              ),
              if (a.assignedToUserId != null)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => edit(() {
                    a
                      ..assignedToUserId = null
                      ..assignedToName = null;
                  }),
                ),
            ],
          ),
        ),
        regGap,
        RegDropdown(
          label: 'Ownership Type',
          value: a.ownershipType,
          options: ownershipTypes,
          onChanged: (v) => edit(() => a.ownershipType = v),
        ),
        RegDropdown(
          label: 'Cost Center',
          value: a.costCenter,
          options: costCenters,
          onChanged: (v) => edit(() => a.costCenter = v),
        ),
        RegDropdown(
          label: 'Responsible Team',
          value: a.responsibleTeam,
          options: responsibleTeams,
          onChanged: (v) => edit(() => a.responsibleTeam = v),
        ),
        RegDateField(
          label: 'Assignment Start Date',
          value: a.assignmentStartDate,
          onPicked: (d) => edit(() => a.assignmentStartDate = d),
        ),
        RegDateField(
          label: 'Assignment End Date',
          value: a.assignmentEndDate,
          error: dateError,
          onPicked: (d) => edit(() => a.assignmentEndDate = d),
        ),
        CheckboxListTile(
          value: a.isCurrent,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Set as current location and assignment', style: AppText.body),
          onChanged: (v) => edit(() => a.isCurrent = v ?? false),
        ),
        const SizedBox(height: 8),
        _AssignmentPreview(form: form),
      ],
    );
  }
}

/// Who holds the asset, where, and for how long.
class _AssignmentPreview extends ConsumerWidget {
  const _AssignmentPreview({required this.form});

  final RegistrationForm form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = form.locationAssignment.location, a = form.locationAssignment.assignment;
    final person = a.assignedToUserId == null ? null : ref.watch(personByIdProvider(a.assignedToUserId));
    String date(DateTime? d) => d == null ? '—' : DemoClock.formatDate(d);
    return SectionCard(
      title: 'Assignment Preview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (person != null)
                PersonAvatar(person: person, size: 40)
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.apartment_rounded, color: AppColors.primary, size: 20),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(registrationCustodian(a), style: AppText.bodyStrong),
                    if (person != null) Text(person.role, style: AppText.caption),
                  ],
                ),
              ),
              if (a.isCurrent) const StatusChip('Current', tone: ChipTone.green),
            ],
          ),
          const SizedBox(height: 10),
          IconLine(icon: Icons.location_on_outlined, text: l.parts.isEmpty ? 'No location yet' : l.parts.join(' › ')),
          const SizedBox(height: 6),
          InfoRow(label: 'Ownership', value: a.ownershipType ?? '—', labelWidth: 110),
          InfoRow(label: 'Responsible Team', value: a.responsibleTeam ?? '—', labelWidth: 110),
          InfoRow(
            label: 'Assignment',
            value: '${date(a.assignmentStartDate)} – ${a.assignmentEndDate == null ? 'Open' : date(a.assignmentEndDate)}',
            labelWidth: 110,
          ),
        ],
      ),
    );
  }
}
