import '../models/common.dart';
import '../models/inspection.dart';
import 'people_mock.dart';
import 'seed_utils.dart';

/// The 12-item checklist of design/09_inspection.jpg, answered 4/4, 3/4, 1/3, 0/1.
List<ChecklistSection> fireAndPumpChecklist() => const [
  ChecklistSection(
    title: 'Visual Inspection',
    questions: [
      ChecklistQuestion(
        code: '1.1',
        text: 'Check for physical damage',
        type: QuestionType.choice,
        options: ['Good', 'Minor Issue', 'Major Issue'],
        answer: 'Good',
      ),
      ChecklistQuestion(
        code: '1.2',
        text: 'Check for leakage',
        type: QuestionType.yesNo,
        options: ['No', 'Yes'],
        answer: 'No',
      ),
      ChecklistQuestion(
        code: '1.3',
        text: 'Check foundation bolts',
        type: QuestionType.choice,
        options: ['Good', 'Loose', 'Damaged'],
        answer: 'Good',
      ),
      ChecklistQuestion(
        code: '1.4',
        text: 'Cleanliness around equipment',
        type: QuestionType.choice,
        options: ['Clean', 'Needs Cleaning', 'Not Acceptable'],
        answer: 'Clean',
      ),
    ],
  ),
  ChecklistSection(
    title: 'Performance Check',
    questions: [
      ChecklistQuestion(
        code: '2.1',
        text: 'Check discharge pressure',
        type: QuestionType.number,
        unit: 'bar',
        min: 6,
        max: 9,
        answer: '7.5',
      ),
      ChecklistQuestion(code: '2.2', text: 'Check flow rate', type: QuestionType.number, unit: 'LPM'),
      ChecklistQuestion(
        code: '2.3',
        text: 'Check motor current',
        type: QuestionType.number,
        unit: 'A',
        min: 10,
        max: 14,
        answer: '12.8',
      ),
      ChecklistQuestion(
        code: '2.4',
        text: 'Check vibration',
        type: QuestionType.choice,
        options: ['Normal', 'High', 'Excessive'],
        answer: 'Normal',
      ),
    ],
  ),
  ChecklistSection(
    title: 'Electrical Check',
    questions: [
      ChecklistQuestion(
        code: '3.1',
        text: 'Check control panel indicators',
        type: QuestionType.choice,
        options: ['OK', 'Faulty'],
        answer: 'OK',
      ),
      ChecklistQuestion(
        code: '3.2',
        text: 'Check cable condition and terminations',
        type: QuestionType.choice,
        options: ['Good', 'Worn', 'Damaged'],
      ),
      ChecklistQuestion(
        code: '3.3',
        text: 'Earthing / grounding intact',
        type: QuestionType.yesNo,
        options: ['Yes', 'No'],
      ),
    ],
  ),
  ChecklistSection(
    title: 'Safety & Compliance',
    questions: [
      ChecklistQuestion(
        code: '4.1',
        text: 'Safety signage and guards in place',
        type: QuestionType.yesNo,
        options: ['Yes', 'No'],
      ),
    ],
  ),
];

/// A short generic checklist; [answered] questions get their "good" answer.
List<ChecklistSection> _generic(String type, {int answered = 0}) {
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
      ChecklistSection(
        title: s.$1,
        questions: [
          for (final q in s.$2)
            ChecklistQuestion(
              code: q.$1,
              text: q.$2,
              type: q.$3.length == 2 ? QuestionType.yesNo : QuestionType.choice,
              options: q.$3,
              answer: n++ < answered ? q.$3.first : null,
            ),
        ],
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
    photos: const ['assets/images/fire_pump.jpg', 'assets/images/pump_unit.jpg'],
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
