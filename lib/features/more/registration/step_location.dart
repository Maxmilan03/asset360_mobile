import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_repository.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:asset360_mobile/data/db/location_seed.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/data/models/asset_registration_mapping.dart';
import 'package:asset360_mobile/features/more/registration/live_options.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Step 3 Location & Assignment (AssetLocationAssignmentDto). [errors] by backend field path.
///
/// Mock mode: Country, then Site › Building › Floor › Zone from the local tree (LocationField),
/// stored as IDs (location codes) + names, plus a free-text Room.
///
/// API mode: Country › Site › Building › Floor › Zone › Room from the Master Data location tree
/// (MasterLocationField: cascading dropdowns or a scanned location tag), stored as the real
/// Master Data ids AND names, plus locationPath. Custodian / Department, Responsible Team and
/// Assigned To (employees) come from Master Data; Ownership Type from the Asset service.
class StepLocation extends ConsumerWidget {
  const StepLocation({super.key, required this.form, required this.edit, required this.errors});

  final AssetRegistration form;
  final FormEdit edit;
  final Map<String, String> errors;

  /// Writes the picked location's names and IDs.
  static void setLocation(AssetLocation l, LocationValue v) {
    l
      ..siteName = v.site
      ..siteId = locationCodeOf(v.site)
      ..buildingName = v.building
      ..buildingId = locationCodeOf(v.site, v.building)
      ..floorName = v.floor
      ..floorId = locationCodeOf(v.site, v.building, v.floor)
      ..zoneName = v.room
      ..zoneId = locationCodeOf(v.site, v.building, v.floor, v.room);
  }

  /// Mock mode: Country, the local Site › Building › Floor › Zone tree, and a free-text Room.
  List<Widget> _localLocation(AssetLocation l, String? locationError) {
    final sites = countries[l.countryId]?.sites ?? const <String>[];
    return [
      RegDropdown(
        label: 'Country',
        required: true,
        value: l.countryId,
        options: countries.keys.toList(),
        labelOf: (id) => countries[id]?.name ?? id,
        error: errors['Location.CountryId'],
        onChanged: (v) => edit(() {
          l
            ..countryId = v
            ..countryName = countries[v]?.name;
          if (!(countries[v]?.sites ?? const []).contains(l.siteName)) setLocation(l, LocationValue.empty);
        }),
      ),
      if (l.countryId != null && sites.isNotEmpty) ...[
        LocationField(
          value: LocationValue(site: l.siteName, building: l.buildingName, floor: l.floorName, room: l.zoneName),
          roomLabel: 'Zone / Area',
          errorText: locationError,
          onChanged: (v) => edit(() => setLocation(l, v)),
        ),
        regGap,
      ],
      RegTextField(
        label: 'Room / Location',
        value: l.roomName,
        hint: 'e.g. Generator Room GR-01, Bay 3',
        onChanged: (v) => edit(() => l.roomName = v),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = form.locationAssignment.location, a = form.locationAssignment.assignment;
    final lists = RegLists(ref);
    final departments = lists.departments;
    final locationError = errors['Location.SiteId'] ?? errors['Location.BuildingId'] ?? errors['Location.FloorId'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (apiMode) ...[
          MasterLocationField(
            value: ref.watch(mdLocationTreeProvider).value?.pathOf(l) ?? MdLocationPath.empty,
            errorText: errors['Location.CountryId'] ?? locationError,
            onChanged: (path) => edit(() => path.writeTo(l)),
          ),
          regGap,
        ] else
          ..._localLocation(l, locationError),
        const FieldLabel('Location Path'),
        RegBreadcrumb(parts: l.parts, icon: Icons.location_on_outlined, empty: 'Choose the site, building and floor'),
        const RegSection('Assignment'),
        RegDropdown.source(
          departments,
          label: 'Custodian / Department',
          required: true,
          value: a.custodianDepartment,
          error: errors['Assignment.CustodianDepartment'],
          onChanged: (v) => edit(() => a.custodianDepartment = v),
        ),
        LabeledField(
          label: 'Assigned To',
          child: Row(
            children: [
              Expanded(
                child: PersonField(
                  personId: a.assignedToUserId,
                  fallbackLabel: a.assignedToName,
                  hint: 'Select person (optional)',
                  title: 'Assigned To',
                  onChanged: (id) {
                    final p = apiMode ? ref.read(masterPersonProvider(id)) : ref.read(personByIdProvider(id));
                    edit(() {
                      a
                        ..assignedToUserId = id
                        ..assignedToName = p?.name;
                      if (p?.department != null && departments.options.contains(p!.department)) {
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
        RegDropdown.source(
          lists.ownershipTypes,
          label: 'Ownership Type',
          value: a.ownershipType,
          onChanged: (v) => edit(() => a.ownershipType = v),
        ),
        RegDropdown.source(
          lists.costCenters,
          label: 'Cost Center',
          value: a.costCenter,
          onChanged: (v) => edit(() => a.costCenter = v),
        ),
        RegDropdown.source(
          lists.responsibleTeams,
          label: 'Responsible Team',
          value: a.responsibleTeam,
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
          error: errors['Assignment.AssignmentEndDate'],
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

  final AssetRegistration form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = form.locationAssignment.location, a = form.locationAssignment.assignment;
    final person = personOf(ref, a.assignedToUserId);
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
          IconLine(icon: Icons.location_on_outlined, text: l.locationPath ?? 'No location yet'),
          const SizedBox(height: 6),
          InfoRow(label: 'Ownership', value: a.ownershipType ?? '—', labelWidth: 110),
          InfoRow(label: 'Responsible Team', value: a.responsibleTeam ?? '—', labelWidth: 110),
          InfoRow(
            label: 'Assignment',
            value:
                '${date(a.assignmentStartDate)} – ${a.assignmentEndDate == null ? 'Open' : date(a.assignmentEndDate)}',
            labelWidth: 110,
          ),
        ],
      ),
    );
  }
}
