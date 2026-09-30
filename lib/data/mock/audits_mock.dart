import '../models/audit.dart';
import 'people_mock.dart';
import 'seed_utils.dart';

/// My Audits 3 (all Rex's), Assigned 2 (not completed), Completed 1.
List<Audit> seedAudits() => [
  Audit(
    id: 'AUD-2026-001',
    name: 'Annual Asset Audit 2026',
    site: 'Dubai Factory',
    start: sep(1),
    end: sep(30),
    totalAssets: 1500,
    status: AuditStatus.inProgress,
    auditorId: PersonIds.rex,
    verified: 850,
    wrongLocation: 25,
    notFound: 15,
    unregistered: 10,
    imagePath: 'assets/images/building_factory.jpg',
  ),
  Audit(
    id: 'AUD-2026-002',
    name: 'IT Equipment Audit',
    site: 'Dubai Office',
    start: sep(10),
    end: sep(20),
    totalAssets: 450,
    status: AuditStatus.pending,
    auditorId: PersonIds.rex,
    imagePath: 'assets/images/building_office.jpg',
  ),
  Audit(
    id: 'AUD-2026-003',
    name: 'Campus Asset Audit',
    site: 'Education City',
    start: on(2026, 8, 20),
    end: on(2026, 8, 31),
    totalAssets: 320,
    status: AuditStatus.completed,
    auditorId: PersonIds.rex,
    verified: 312,
    wrongLocation: 5,
    notFound: 3,
    imagePath: 'assets/images/building_campus.jpg',
  ),
];
