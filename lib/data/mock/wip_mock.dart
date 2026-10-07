import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/models/wip.dart';
import 'package:asset360_mobile/data/mock/people_mock.dart';
import 'package:asset360_mobile/data/mock/seed_utils.dart';

const _img = 'assets/images';
const _doc = 'assets/docs/sample_document.pdf';

WipSummary seedWipSummary() => const WipSummary(inProcess: 78, completedToday: 82, delayed: 16, onHold: 6, queued: 24);

Operation _done(String name, String station, String location, int mins, DateTime at, {int? good, int? scrap}) =>
    Operation(
      name: name,
      station: station,
      location: location,
      status: OpStatus.completed,
      expectedMins: mins,
      actualMins: mins,
      startedAt: at.subtract(Duration(minutes: mins)),
      completedAt: at,
      goodQty: good,
      scrapQty: scrap,
      qcPassed: true,
    );

Operation _pending(String name, String station, String location, int mins) =>
    Operation(name: name, station: station, location: location, status: OpStatus.pending, expectedMins: mins);

const _instructions = [
  Attachment(name: 'Work Instruction – Assembly.pdf', sizeKb: 860, path: _doc),
  Attachment(name: 'Quality Checklist.pdf', sizeKb: 240, path: _doc),
];

/// Sample production orders (the plant-wide counts come from [WipSummary]).
List<ProductionOrder> seedProductionOrders() => [
  ProductionOrder(
    id: 'MO-2026-0018',
    product: 'PCB Assembly – Model A',
    unitSerial: 'PCB-A-4587',
    batch: 'BATCH-2026-0915',
    customer: 'Internal Production',
    status: MoStatus.inProcess,
    plannedQty: 500,
    completedQty: 320,
    dueDate: sep(25),
    imagePath: '$_img/pcb.jpg',
    photos: const ['$_img/pcb.jpg', '$_img/aoi_machine.jpg'],
    scans: [
      UnitScan(at: sep(12, 11, 38), location: 'AOI Line 1', by: 'John Smith', device: 'Station-AOI-01'),
      UnitScan(at: sep(12, 11, 20), location: 'AOI Line 1', by: 'Alex Mathew', device: 'Station-AOI-01'),
      UnitScan(at: sep(12, 9, 10), location: 'SMT Line 1', by: 'John Smith', device: 'Station-SMT-01'),
      UnitScan(at: sep(12, 8, 25), location: 'SMT Line 1', by: 'John Smith', device: 'Station-SMT-01'),
    ],
    components: const [
      BomLine(name: 'Control PCB – Model A', partId: 'CT-4587', required: 10, issued: 6),
      BomLine(name: 'Relay 24V DC', partId: 'RL-24V', required: 20, issued: 12),
      BomLine(name: 'Connector 12-pin', required: 30, issued: 30),
    ],
    quality: [QualityCheck(at: sep(12, 9, 10), operation: 'SMT (Surface Mount)', passed: true, by: 'John Smith')],
    notes: [LogEntry(at: sep(12, 8, 20), title: 'AOI program v3.2 loaded for Model A.', by: 'John Smith')],
    documents: const [
      Attachment(name: 'Work Instruction – PCB Model A.pdf', sizeKb: 1240, path: _doc),
      Attachment(name: 'AOI Program Sheet v3.2.pdf', sizeKb: 310, path: _doc),
    ],
    operations: [
      Operation(
        name: 'SMT (Surface Mount)',
        station: 'SMT',
        location: 'SMT Line 1',
        status: OpStatus.completed,
        expectedMins: 45,
        actualMins: 45,
        startedAt: sep(12, 8, 25),
        completedAt: sep(12, 9, 10),
        operatorId: PersonIds.john,
        goodQty: 496,
        scrapQty: 4,
        qcPassed: true,
      ),
      Operation(
        name: 'AOI Inspection',
        station: 'AOI',
        location: 'AOI Line 1',
        status: OpStatus.inProgress,
        expectedMins: 30,
        actualMins: 18,
        startedAt: sep(12, 11, 20),
        operatorId: PersonIds.alex,
      ),
      _pending('Manual Assembly', 'Assembly', 'Assembly Station 3', 60),
      _pending('Functional Testing', 'Testing', 'Test Bench 1', 45),
      _pending('Packing & Labeling', 'Packing', 'Packing Line 1', 20),
    ],
  ),
  ProductionOrder(
    id: 'MO-2026-0017',
    product: 'Control Panel – Type B',
    unitSerial: 'CPB-3201',
    batch: 'BATCH-2026-0912',
    status: MoStatus.delayed,
    plannedQty: 120,
    completedQty: 64,
    dueDate: sep(24),
    area: 'Assembly Hall',
    imagePath: '$_img/control_panel.jpg',
    scans: [
      UnitScan(at: sep(25, 9, 12), location: 'Test Bench 2', by: 'John Smith', device: 'Station-TST-02'),
      UnitScan(at: sep(24, 15, 0), location: 'Wiring Bay 1', by: 'John Smith', device: 'Station-WIR-01'),
    ],
    components: const [
      BomLine(name: 'Circuit Breaker 15A', partId: 'CB-15A', required: 4, issued: 2),
      BomLine(name: 'Fuse 10A', partId: 'FU-10A', required: 8, issued: 8),
    ],
    quality: [
      QualityCheck(
        at: sep(25, 9, 10),
        operation: 'Functional Testing',
        passed: false,
        note: 'Insulation resistance below limit on terminal X4',
        by: 'John Smith',
      ),
    ],
    documents: _instructions,
    operations: [
      _done('Panel Assembly', 'Assembly', 'Assembly Station 2', 90, sep(24, 11, 0), good: 118, scrap: 2),
      _done('Wiring', 'Wiring', 'Wiring Bay 1', 120, sep(24, 15, 0), good: 116, scrap: 2),
      Operation(
        name: 'Functional Testing',
        station: 'Testing',
        location: 'Test Bench 2',
        status: OpStatus.failed,
        expectedMins: 45,
        actualMins: 60,
        startedAt: sep(25, 8, 10),
        operatorId: PersonIds.john,
        qcPassed: false,
      ),
      _pending('Packing & Labeling', 'Packing', 'Packing Line 2', 20),
    ],
  ),
  ProductionOrder(
    id: 'MO-2026-0016',
    product: 'Pump Unit – Model X',
    unitSerial: 'PU-7789',
    batch: 'BATCH-2026-0910',
    status: MoStatus.inProcess,
    plannedQty: 80,
    completedQty: 52,
    dueDate: sep(28),
    area: 'Pump Line',
    imagePath: '$_img/pump_unit.jpg',
    scans: [
      UnitScan(at: sep(25, 10, 5), location: 'Testing Station 1', by: 'Ramesh Kumar', device: 'Station-TST-01'),
      UnitScan(at: sep(25, 8, 30), location: 'Assembly Station 1', by: 'Ramesh Kumar', device: 'Station-ASM-01'),
    ],
    documents: _instructions,
    operations: [
      _done('Pump Assembly', 'Assembly', 'Assembly Station 1', 75, sep(25, 8, 30), good: 80, scrap: 0),
      Operation(
        name: 'Pressure Testing',
        station: 'Testing',
        location: 'Testing Station 1',
        status: OpStatus.inProgress,
        expectedMins: 40,
        actualMins: 25,
        startedAt: sep(25, 9, 40),
        operatorId: PersonIds.ramesh,
      ),
      _pending('Quality Check', 'Quality Check', 'QC Bay 1', 20),
      _pending('Packing & Labeling', 'Packing', 'Packing Line 1', 20),
    ],
  ),
  ProductionOrder(
    id: 'MO-2026-0015',
    product: 'Chiller Module',
    unitSerial: 'CHM-1045',
    batch: 'BATCH-2026-0905',
    status: MoStatus.completed,
    plannedQty: 40,
    completedQty: 40,
    dueDate: sep(24),
    scans: [UnitScan(at: sep(24, 16, 30), location: 'Dispatch', by: 'Rakesh Kumar', device: 'Station-DSP-01')],
    documents: _instructions,
    operations: [
      _done('Module Assembly', 'Assembly', 'Assembly Station 4', 120, sep(23, 12, 0), good: 40, scrap: 0),
      _done('Brazing', 'Brazing', 'Brazing Booth 1', 90, sep(23, 15, 0), good: 40, scrap: 0),
      _done('Leak Testing', 'Testing', 'Leak Test Rig', 60, sep(24, 10, 0), good: 40, scrap: 0),
      _done('Packing & Labeling', 'Packing', 'Packing Line 2', 30, sep(24, 16, 0), good: 40, scrap: 0),
    ],
  ),
  ProductionOrder(
    id: 'MO-2026-0014',
    product: 'Motor Housing – M250',
    unitSerial: 'MH-2250',
    batch: 'BATCH-2026-0903',
    status: MoStatus.onHold,
    plannedQty: 200,
    completedQty: 110,
    dueDate: sep(30),
    area: 'Production Floor 1',
    holdReason: 'CNC-021 coolant leak (WO-2026-0028)',
    scans: [UnitScan(at: sep(22, 10, 0), location: 'CNC-021', by: 'Ramesh Kumar', device: 'Station-CNC-02')],
    notes: [LogEntry(at: sep(22, 10, 5), title: 'On hold: CNC-021 coolant leak (WO-2026-0028).', by: 'Ramesh Kumar')],
    documents: _instructions,
    operations: [
      _done('Casting Inspection', 'Inspection', 'Inspection Bench', 20, sep(21, 9, 0), good: 198, scrap: 2),
      Operation(
        name: 'CNC Machining',
        station: 'CNC',
        location: 'CNC-021',
        status: OpStatus.paused,
        expectedMins: 35,
        actualMins: 20,
        startedAt: sep(22, 9, 40),
        operatorId: PersonIds.ramesh,
      ),
      _pending('Deburring', 'Deburr', 'Deburr Station', 15),
      _pending('Packing & Labeling', 'Packing', 'Packing Line 1', 15),
    ],
  ),
];

/// Station tags that can be scanned on the shop floor ("Scan to Move" / location scan).
const stationTagPrefix = 'STATION:';
