import '../../core/checklist/checklist.dart';
import '../models/common.dart';
import '../models/inspection.dart';
import 'people_mock.dart';
import 'seed_utils.dart';

CheckItem _choice(String code, String label, List<String> options, [String? value]) => CheckItem(
  code: code,
  label: label,
  type: options.length == 2 ? CheckType.yesNo : CheckType.choice,
  options: options,
  value: value,
);

CheckItem _number(String code, String label, String unit, double min, double max, [String? value]) =>
    CheckItem(code: code, label: label, type: CheckType.number, unit: unit, min: min, max: max, value: value);

/// The 12-item checklist of design/09_inspection.jpg, answered 4/4, 3/4, 1/3, 0/1.
List<CheckSection> fireAndPumpChecklist() => [
  CheckSection(
    title: 'Visual Inspection',
    items: [
      _choice('1.1', 'Check for physical damage', ['Good', 'Minor Issue', 'Major Issue'], 'Good'),
      _choice('1.2', 'Check for leakage', ['No', 'Yes'], 'No'),
      _choice('1.3', 'Check foundation bolts', ['Good', 'Loose', 'Damaged'], 'Good'),
      _choice('1.4', 'Cleanliness around equipment', ['Clean', 'Needs Cleaning', 'Not Acceptable'], 'Clean'),
    ],
  ),
  CheckSection(
    title: 'Performance Check',
    items: [
      _number('2.1', 'Check discharge pressure', 'bar', 6, 9, '7.5'),
      _number('2.2', 'Check flow rate', 'LPM', 400, 600),
      _number('2.3', 'Check motor current', 'A', 10, 14, '12.8'),
      _choice('2.4', 'Check vibration', ['Normal', 'High', 'Excessive'], 'Normal'),
    ],
    photos: const ['assets/images/fire_pump.jpg', 'assets/images/pump_unit.jpg'],
  ),
  CheckSection(
    title: 'Electrical Check',
    items: [
      _choice('3.1', 'Check control panel indicators', ['OK', 'Faulty'], 'OK'),
      _choice('3.2', 'Check cable condition and terminations', ['Good', 'Worn', 'Damaged']),
      _choice('3.3', 'Earthing / grounding intact', ['Yes', 'No']),
    ],
  ),
  CheckSection(
    title: 'Safety & Compliance',
    items: [
      _choice('4.1', 'Safety signage and guards in place', ['Yes', 'No']),
    ],
  ),
];

/// Create Inspection templates: name → (type, title suffix, blank checklist).
final inspectionTemplates = <String, (String, String, List<CheckSection> Function())>{
  'Fire Pump Routine': ('Routine', 'Routine Inspection', () => [for (final s in fireAndPumpChecklist()) s.blank]),
  'HVAC': (
    'HVAC',
    'HVAC Inspection',
    () => [
      CheckSection(
        title: 'Filters & Coils',
        items: [
          _choice('1.1', 'Filter condition', ['Clean', 'Dirty', 'Clogged']),
          _choice('1.2', 'Coil condition', ['Clean', 'Needs Cleaning', 'Damaged']),
          _choice('1.3', 'Drain pan leakage', ['No', 'Yes']),
        ],
      ),
      CheckSection(
        title: 'Performance',
        items: [
          _number('2.1', 'Supply air temperature', '°C', 12, 16),
          _number('2.2', 'Fan motor current', 'A', 4, 7),
          _choice('2.3', 'Fan vibration', ['Normal', 'High', 'Excessive']),
        ],
      ),
      const CheckSection(
        title: 'Photos & Remarks',
        items: [
          CheckItem(code: '3.1', label: 'Photo of the unit', type: CheckType.photo),
          CheckItem(code: '3.2', label: 'Remarks', type: CheckType.text, required: false),
        ],
      ),
    ],
  ),
  'Generator Safety': (
    'Safety',
    'Safety Inspection',
    () => [
      CheckSection(
        title: 'Engine',
        items: [
          _choice('1.1', 'Engine oil level', ['OK', 'Low']),
          _choice('1.2', 'Coolant level', ['OK', 'Low']),
          _choice('1.3', 'Exhaust leakage', ['No', 'Yes']),
        ],
      ),
      CheckSection(
        title: 'Electrical',
        items: [
          _number('2.1', 'Starter battery voltage', 'V', 12.4, 13.2),
          _choice('2.2', 'Emergency stop test', ['Pass', 'Fail']),
        ],
      ),
      const CheckSection(
        title: 'Sign-off',
        items: [CheckItem(code: '3.1', label: 'Remarks', type: CheckType.text, required: false)],
      ),
    ],
  ),
  'Forklift Safety': (
    'Safety',
    'Safety & Compliance',
    () => [
      CheckSection(
        title: 'Pre-use Check',
        items: [
          _choice('1.1', 'Horn and lights', ['Working', 'Not Working']),
          _choice('1.2', 'Brakes', ['Good', 'Weak', 'Failed']),
          _choice('1.3', 'Forks and chains', ['Good', 'Worn', 'Damaged']),
          _number('1.4', 'Battery charge', '%', 20, 100),
        ],
      ),
      CheckSection(
        title: 'Operator',
        items: [
          _choice('2.1', 'Seat belt fitted and working', ['Yes', 'No']),
          const CheckItem(code: '2.2', label: 'Operator acknowledgement', type: CheckType.signature),
        ],
      ),
    ],
  ),
  'Fire Extinguisher Monthly': (
    'Monthly',
    'Monthly Check',
    () => [
      CheckSection(
        title: 'Extinguisher',
        items: [
          _choice('1.1', 'Pressure gauge in green zone', ['Yes', 'No']),
          _choice('1.2', 'Safety pin and seal intact', ['Yes', 'No']),
          _choice('1.3', 'Hose and nozzle condition', ['Good', 'Cracked', 'Blocked']),
          _number('1.4', 'Gross weight', 'kg', 9.5, 10.5),
          const CheckItem(code: '1.5', label: 'Photo of the inspection tag', type: CheckType.photo),
        ],
      ),
    ],
  ),
};

/// A short generic checklist; [answered] items get their "good" answer.
List<CheckSection> _generic(String type, {int answered = 0}) {
  const texts = [
    (
      'General Condition',
      [
        ('1.1', 'Check for physical damage', ['Good', 'Minor Issue', 'Major Issue']),
        ('1.2', 'Check for leakage', ['No', 'Yes']),
        ('1.3', 'Labels and tags readable', ['Yes', 'No']),
      ],
    ),
    (
      'Operation',
      [
        ('2.1', 'Runs without abnormal noise', ['Yes', 'No']),
        ('2.2', 'Controls and indicators working', ['OK', 'Faulty']),
      ],
    ),
    (
      'Safety & Compliance',
      [
        ('3.1', 'Safety devices in place', ['Yes', 'No']),
        ('3.2', 'Area clean and accessible', ['Clean', 'Needs Cleaning', 'Not Acceptable']),
      ],
    ),
  ];
  var n = 0;
  return [
    for (final s in texts)
      CheckSection(
        title: s.$1,
        items: [for (final q in s.$2) _choice(q.$1, q.$2, q.$3, n++ < answered ? q.$3.first : null)],
      ),
  ];
}

Inspection _ins(
  String id,
  String assetId,
  String title,
  String type,
  String status,
  DateTime due,
  String inspector, {
  int answered = 0,
  List<Finding> findings = const [],
  DateTime? completedAt,
  bool offline = false,
}) {
  final sections = _generic(type, answered: status == InspectionStatus.completed ? 99 : answered);
  return Inspection(
    id: id,
    assetId: assetId,
    title: title,
    type: type,
    status: status,
    dueAt: due,
    inspectorId: inspector,
    sections: sections,
    findings: findings,
    completedAt: completedAt,
    savedOffline: offline,
    history: [
      LogEntry(at: due.subtract(const Duration(days: 5)), title: 'Inspection scheduled', by: 'System (Schedule)'),
      if (completedAt != null) LogEntry(at: completedAt, title: 'Inspection completed', by: 'Inspector'),
    ],
  );
}

List<Inspection> seedInspections() => [
  // Detailed record from the design
  Inspection(
    id: 'INS-2026-0045',
    assetId: 'FP-0021',
    title: 'Fire Pump – Routine Inspection',
    type: 'Routine',
    status: InspectionStatus.inProgress,
    dueAt: sep(25, 9, 0),
    inspectorId: PersonIds.rex,
    sections: fireAndPumpChecklist(),
    template: 'Fire Pump Routine',
    findings: [
      Finding(
        id: 'FND-2026-0101',
        title: 'Minor corrosion on suction flange',
        severity: 'Low',
        createdAt: sep(25, 9, 40),
        description: 'Surface rust on the suction flange bolts. Clean and apply anti-corrosion coating.',
      ),
    ],
    documentIds: const ['DOC-2026-0060'],
    history: [
      LogEntry(at: sep(20, 9, 0), title: 'Inspection scheduled', by: 'System (Schedule)'),
      LogEntry(at: sep(25, 9, 20), title: 'Inspection started', by: 'Rex Kumar'),
    ],
  ),
  // Rex's inspections (6 incl. INS-0045)
  _ins(
    'INS-2026-0044',
    'GEN-00045',
    'Generator – Safety Inspection',
    'Safety',
    InspectionStatus.scheduled,
    sep(25, 16, 0),
    PersonIds.rex,
  ),
  _ins(
    'INS-2026-0046',
    'LFT-01',
    'Lift – Safety Inspection',
    'Safety',
    InspectionStatus.scheduled,
    sep(25, 14, 0),
    PersonIds.rex,
  ),
  _ins(
    'INS-2026-0043',
    'AHU-03',
    'AHU-03 – HVAC Inspection',
    'HVAC',
    InspectionStatus.inProgress,
    sep(26, 12, 0),
    PersonIds.rex,
    answered: 3,
    findings: [
      Finding(
        id: 'FND-2026-0102',
        title: 'Clogged pre-filter',
        severity: 'Medium',
        createdAt: sep(25, 8, 50),
        questionCode: '2.1',
      ),
    ],
  ),
  _ins(
    'INS-2026-0042',
    'FE-0042',
    'Fire Extinguisher – Monthly Check',
    'Monthly',
    InspectionStatus.scheduled,
    sep(27, 10, 0),
    PersonIds.rex,
  ),
  _ins(
    'INS-2026-0041',
    'FL-012',
    'Forklift – Safety & Compliance',
    'Safety',
    InspectionStatus.scheduled,
    sep(28, 10, 0),
    PersonIds.rex,
  ),
  // Overdue (with INS-0045: 3)
  _ins(
    'INS-2026-0040',
    'CH-00021',
    'Chiller – Quarterly Inspection',
    'Routine',
    InspectionStatus.inProgress,
    sep(23, 12, 0),
    PersonIds.rafi,
    answered: 4,
    findings: [
      Finding(
        id: 'FND-2026-0100',
        title: 'Refrigerant pressure slightly low',
        severity: 'Medium',
        createdAt: sep(23, 11, 30),
      ),
    ],
  ),
  _ins(
    'INS-2026-0039',
    'CAB-011',
    'Electrical Cabinet – Thermal Scan',
    'Electrical',
    InspectionStatus.scheduled,
    sep(24, 15, 0),
    PersonIds.ahmed,
  ),
  // Due in the next week (with 0044, 0046, 0043, 0042, 0041: 8)
  _ins(
    'INS-2026-0047',
    'CNC-00123',
    'CNC-00123 – Quality Inspection',
    'Quality',
    InspectionStatus.scheduled,
    sep(29, 10, 0),
    PersonIds.rafi,
  ),
  _ins(
    'INS-2026-0048',
    'MTR-007',
    'Motor – Vibration Inspection',
    'Routine',
    InspectionStatus.scheduled,
    sep(30, 10, 0),
    PersonIds.rafi,
  ),
  _ins(
    'INS-2026-0049',
    'CR-001',
    'Cold Room – Temperature Audit',
    'Routine',
    InspectionStatus.scheduled,
    DateTime(2026, 10, 1, 10),
    PersonIds.suresh,
  ),
  // Completed
  _ins(
    'INS-2026-0038',
    'GEN-00046',
    'Generator – Weekly Inspection',
    'Routine',
    InspectionStatus.completed,
    sep(24, 10, 0),
    PersonIds.rafi,
    completedAt: sep(24, 10, 40),
    findings: [
      Finding(id: 'FND-2026-0099', title: 'Starter battery voltage low', severity: 'High', createdAt: sep(24, 10, 30)),
    ],
  ),
  _ins(
    'INS-2026-0037',
    'AHU-02',
    'AHU-02 – HVAC Inspection',
    'HVAC',
    InspectionStatus.completed,
    sep(22, 10, 0),
    PersonIds.rafi,
    completedAt: sep(22, 11, 0),
  ),
  _ins(
    'INS-2026-0036',
    'FP-0021',
    'Fire Pump – Weekly Run Test',
    'Routine',
    InspectionStatus.completed,
    sep(20, 10, 0),
    PersonIds.rafi,
    completedAt: sep(20, 10, 30),
  ),
  _ins(
    'INS-2026-0035',
    'LFT-01',
    'Lift – Monthly Inspection',
    'Monthly',
    InspectionStatus.completed,
    sep(18, 10, 0),
    PersonIds.ahmed,
    completedAt: sep(18, 11, 15),
  ),
  _ins(
    'INS-2026-0034',
    'FL-015',
    'Forklift – Safety & Compliance',
    'Safety',
    InspectionStatus.completed,
    sep(15, 10, 0),
    PersonIds.rakesh,
    completedAt: sep(15, 10, 45),
  ),
  // Completed on the device, waiting for Offline Sync
  _ins(
    'INS-2026-0051',
    'GEN-00046',
    'Generator – Safety Inspection',
    'Safety',
    InspectionStatus.completed,
    sep(22, 15, 0),
    PersonIds.rex,
    completedAt: sep(22, 14, 45),
    offline: true,
  ),
  _ins(
    'INS-2026-0050',
    'CNC-021',
    'CNC Machine – Quality Inspection',
    'Quality',
    InspectionStatus.completed,
    sep(22, 12, 0),
    PersonIds.rex,
    completedAt: sep(22, 11, 5),
    offline: true,
  ),
];
