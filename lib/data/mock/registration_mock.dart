import '../models/asset.dart';
import 'seed_utils.dart';

/// Site → Building → Floor → Rooms / Zones (Registration step 3 cascading dropdowns).
/// A registered location reads "Building / Floor – Zone", like the seed assets.
const locationTree = <String, Map<String, Map<String, List<String>>>>{
  'Dubai Factory': {
    'Main Plant': {
      'Production Floor 1': ['Line 1', 'Line 2', 'CNC Bay', 'Assembly'],
      'Production Floor 2': ['Line 3', 'Paint Shop', 'Quality Lab'],
      'Floor 2': ['Mezzanine', 'Control Room'],
      'Roof': ['Chiller Deck', 'Plant Room'],
    },
    'Building A': {
      'Ground Floor': ['Generator Room GR-01', 'Electrical Room'],
      'Floor 2': ['Offices', 'Corridor'],
      'Roof': ['AHU Deck'],
    },
    'Building B': {
      'Ground Floor': ['Pump Room', 'Workshop'],
      'Floor 1': ['Tool Crib', 'Stores'],
    },
    'Main Warehouse': {
      'Ground Floor': ['Receiving', 'Zone A', 'Zone B', 'Dispatch'],
      'Mezzanine': ['Spares Store'],
    },
  },
  'Dubai Office': {
    'Head Office': {
      'Building A': ['Room 101', 'Room 102', 'IT Store', 'Reception'],
      'Building B': ['Marketing', 'Finance', 'Board Room'],
    },
  },
  'Education City': {
    'Admin Block': {
      'Ground Floor': ['Lobby', 'Security'],
      '2nd Floor': ['Meeting Room 3', 'Staff Room'],
    },
    'Admin Building': {
      'Core': ['Lift Lobby', 'Plant Room'],
    },
  },
};

const departments = [
  'Production',
  'Maintenance',
  'Facilities',
  'Warehouse',
  'Operations',
  'IT',
  'Finance',
  'Marketing',
  'Admin',
];

/// Asset types that are not in the seed register yet, with their ID prefix and category.
const extraAssetTypes = <String, (String prefix, String category)>{
  'Air Compressor': ('CMP', 'Production Equipment'),
  'Conveyor': ('CNV', 'Material Handling Equipment'),
  'Welding Machine': ('WLD', 'Production Equipment'),
  'UPS': ('UPS', 'Power Equipment'),
  'Printer': ('PRN', 'IT Equipment'),
  'Vehicle': ('VEH', 'Vehicles'),
};

const suppliers = [
  'Al Futtaim Engineering',
  'Emirates Industrial Supplies',
  'Haas Middle East',
  'Siemens LLC',
  'Dell Gulf',
];

/// IoT devices in the store, not yet paired with an asset (Registration step 4, Link IoT Device).
List<IotDevice> seedSpareIotDevices() => [
  for (final (i, (model, type)) in const [
    ('Teltonika TRB245', 'Industrial Gateway'),
    ('Teltonika TRB245', 'Industrial Gateway'),
    ('Teltonika FMB140', 'Vehicle Tracker'),
    ('Teltonika EYE Sensor', 'Temperature Sensor'),
    ('Siemens SIMOTICS Connect 400', 'Motor Sensor'),
    ('Minew E8 BLE Tag', 'BLE Beacon'),
  ].indexed)
    IotDevice(
      model: model,
      type: type,
      imei: '35678912900${(701 + i).toString().padLeft(4, '0')}',
      iccid: '899710205678990${(701 + i).toString().padLeft(4, '0')}',
      batteryPct: 100,
      signalDbm: -58 - i * 2,
      firmware: 'v1.2.5',
      online: true,
      lastSeen: sep(25, 10, 0),
    ),
];

/// Bulk Registration CSV columns, in template order.
const bulkCsvColumns = [
  'asset_id',
  'name',
  'category',
  'type',
  'manufacturer',
  'model',
  'serial_no',
  'tag_id',
  'barcode',
  'site',
  'location',
  'custodian',
  'status',
  'criticality',
  'purchase_date',
  'purchase_cost',
  'warranty_expiry',
];

/// A ready-made CSV so Bulk Registration can be tried without a file (row 4 is invalid on purpose:
/// it reuses CNC-00123's tag).
const sampleBulkCsv =
    '''asset_id,name,category,type,manufacturer,model,serial_no,tag_id,barcode,site,location,custodian,status,criticality,purchase_date,purchase_cost,warranty_expiry
CMP-00001,Air Compressor – 55 kW,Production Equipment,Air Compressor,Atlas Copco,GA 55,AC-GA55-2026-0001,RFID-A360-000801,CMP-00001,Dubai Factory,Main Plant / Production Floor 1 – Line 1,Production,Active,High,2026-03-12,98000,2029-03-12
CNV-00001,Belt Conveyor – Line 2,Material Handling Equipment,Conveyor,Interroll,BC-600,IR-BC600-2026-0014,RFID-A360-000802,CNV-00001,Dubai Factory,Main Plant / Production Floor 1 – Line 2,Production,Active,Medium,2026-04-02,42000,2028-04-02
PRN-00001,"Printer – HP LaserJet M507",IT Equipment,Printer,HP,M507dn,HP-M507-2026-0031,,PRN-00001,Dubai Office,Head Office / Building A – Room 101,IT,Active,Low,2026-05-20,2400,2027-05-20
UPS-00001,UPS – 10 kVA,Power Equipment,UPS,APC,SRT10K,APC-SRT10K-2026-0002,RFID-A360-000123,UPS-00001,Dubai Factory,Building A / Ground Floor – Electrical Room,Facilities,Active,High,2026-06-01,18500,2028-06-01
''';
