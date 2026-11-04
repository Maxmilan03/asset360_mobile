/// Dropdown values of the Register Asset form, matching the web app's Register Asset screens.
/// Kept in one file so each list can be swapped for an API lookup later
/// (e.g. GET /api/asset-categories, /api/asset-category-types, /api/asset-models).
///
/// TO CHECK: design/web_registration/*.png was not in the repo when this was written; only the
/// Generator path (Machinery & Equipment › Power Generation › Generator, Diesel / Gas / UPS / Solar
/// sub types) is known from the web. Compare every list here with the screenshots.
library;

import 'package:asset360_mobile/data/mock/registration_mock.dart' as mock;

/// An asset sub type picture card (icon key → icon in the widget).
class AssetSubType {
  const AssetSubType(this.name, this.icon);

  final String name;
  final String icon;
}

class AssetTypeOption {
  const AssetTypeOption(this.name, {required this.prefix, this.subTypes = const []});

  final String name;

  /// Asset ID prefix suggested for this type (GEN-00047).
  final String prefix;
  final List<AssetSubType> subTypes;
}

class SubCategoryOption {
  const SubCategoryOption(this.name, this.types);

  final String name;
  final List<AssetTypeOption> types;
}

class CategoryOption {
  const CategoryOption(this.name, this.subCategories);

  final String name;
  final List<SubCategoryOption> subCategories;
}

/// Category › Sub Category › Asset Type. Sub category names match the categories of the asset
/// register (IT Equipment, HVAC …), so a registered asset groups like the seed assets.
const assetCategories = [
  CategoryOption('Machinery & Equipment', [
    SubCategoryOption('Power Generation', [
      AssetTypeOption(
        'Generator',
        prefix: 'GEN',
        subTypes: [
          AssetSubType('Diesel Generator', 'diesel'),
          AssetSubType('Gas Generator', 'gas'),
          AssetSubType('UPS Generator', 'ups'),
          AssetSubType('Solar Generator', 'solar'),
        ],
      ),
      AssetTypeOption('UPS', prefix: 'UPS'),
    ]),
    SubCategoryOption('Production Equipment', [
      AssetTypeOption(
        'CNC Machine',
        prefix: 'CNC',
        subTypes: [
          AssetSubType('CNC Lathe', 'lathe'),
          AssetSubType('CNC Milling', 'milling'),
          AssetSubType('Machining Centre', 'machining'),
        ],
      ),
      AssetTypeOption(
        'Electric Motor',
        prefix: 'MTR',
        subTypes: [
          AssetSubType('AC Induction', 'motor'),
          AssetSubType('Servo Motor', 'servo'),
          AssetSubType('DC Motor', 'dc'),
        ],
      ),
      AssetTypeOption('Air Compressor', prefix: 'CMP'),
      AssetTypeOption('Welding Machine', prefix: 'WLD'),
    ]),
    SubCategoryOption('Material Handling Equipment', [
      AssetTypeOption(
        'Forklift',
        prefix: 'FL',
        subTypes: [
          AssetSubType('Electric Forklift', 'electric'),
          AssetSubType('Diesel Forklift', 'diesel'),
          AssetSubType('LPG Forklift', 'gas'),
          AssetSubType('Reach Truck', 'reach'),
        ],
      ),
      AssetTypeOption('Conveyor', prefix: 'CNV'),
    ]),
  ]),
  CategoryOption('Building Services', [
    SubCategoryOption('HVAC', [
      AssetTypeOption(
        'Air Handling Unit',
        prefix: 'AHU',
        subTypes: [
          AssetSubType('Packaged AHU', 'hvac'),
          AssetSubType('Modular AHU', 'modular'),
          AssetSubType('Rooftop AHU', 'rooftop'),
        ],
      ),
      AssetTypeOption(
        'Chiller',
        prefix: 'CH',
        subTypes: [AssetSubType('Air-Cooled Chiller', 'air'), AssetSubType('Water-Cooled Chiller', 'water')],
      ),
    ]),
    SubCategoryOption('Fire Safety', [
      AssetTypeOption(
        'Fire Pump',
        prefix: 'FP',
        subTypes: [
          AssetSubType('Electric Fire Pump', 'electric'),
          AssetSubType('Diesel Fire Pump', 'diesel'),
          AssetSubType('Jockey Pump', 'pump'),
        ],
      ),
      AssetTypeOption('Fire Extinguisher', prefix: 'FE'),
    ]),
    SubCategoryOption('Electrical', [AssetTypeOption('Electrical Cabinet', prefix: 'CAB')]),
    SubCategoryOption('Building Services', [AssetTypeOption('Lift', prefix: 'LFT')]),
  ]),
  CategoryOption('IT & Electronics', [
    SubCategoryOption('IT Equipment', [
      AssetTypeOption(
        'Laptop',
        prefix: 'LAP',
        subTypes: [
          AssetSubType('Standard Laptop', 'laptop'),
          AssetSubType('Rugged Laptop', 'rugged'),
          AssetSubType('Workstation Laptop', 'workstation'),
        ],
      ),
      AssetTypeOption('Printer', prefix: 'PRN'),
      AssetTypeOption('Projector', prefix: 'PRJ'),
      AssetTypeOption('Camera', prefix: 'CAM'),
    ]),
  ]),
  CategoryOption('Tools & Vehicles', [
    SubCategoryOption('Tools', [AssetTypeOption('Tool Box', prefix: 'TL'), AssetTypeOption('Drill Machine', prefix: 'DRL')]),
    SubCategoryOption('Vehicles', [AssetTypeOption('Vehicle', prefix: 'VEH')]),
  ]),
];

/// The type option named [type] (any category), if listed.
AssetTypeOption? assetTypeOption(String? type) {
  for (final c in assetCategories) {
    for (final s in c.subCategories) {
      for (final t in s.types) {
        if (t.name == type) return t;
      }
    }
  }
  return null;
}

/// The category and sub category that list [type].
({String category, String subCategory})? classificationOf(String type) {
  for (final c in assetCategories) {
    for (final s in c.subCategories) {
      if (s.types.any((t) => t.name == type)) return (category: c.name, subCategory: s.name);
    }
  }
  return null;
}

// ---- Step 1 / 2
const departments = mock.departments;
const costCenters = [
  'CC-1001 Production',
  'CC-1002 Maintenance',
  'CC-2001 Facilities',
  'CC-3001 IT',
  'CC-4001 Warehouse',
  'CC-5001 Administration',
];
const businessUnits = ['Manufacturing', 'Facilities Management', 'Corporate IT', 'Logistics', 'Corporate Services'];
const taggingMethods = ['Barcode', 'RFID', 'BLE', 'QR Code'];
const complianceCategories = [
  'Safety Critical',
  'Fire & Life Safety',
  'Electrical Safety',
  'Environmental',
  'Statutory Inspection',
  'Not Applicable',
];
const lifecycleStages = ['Planning', 'Procurement', 'Commissioning', 'In Operation', 'Decommissioning'];

// ---- Step 3
/// Country → the sites of the location tree in it.
const countries = {'United Arab Emirates': ['Dubai Factory', 'Dubai Office', 'Education City']};
const ownershipTypes = ['Owned', 'Leased', 'Rented', 'Customer Owned'];
const responsibleTeams = ['Electrical Team', 'Mechanical Team', 'HVAC Team', 'IT Support', 'Facilities Team', 'Production Team'];

// ---- Step 4
const suppliers = mock.suppliers;
const currencies = ['AED', 'USD', 'EUR', 'SAR'];
const quantityUnits = ['Nos', 'Set', 'Unit', 'Lot'];
const paymentTerms = ['Immediate', 'Net 30', 'Net 60', 'Net 90', '50% Advance / 50% on Delivery'];
const procurementMethods = ['Direct Purchase', 'Quotation (RFQ)', 'Tender', 'Framework Agreement', 'Lease'];
const warrantyTypes = ['Manufacturer Warranty', 'Extended Warranty', 'Vendor Warranty', 'No Warranty'];
const periodUnits = ['Days', 'Months', 'Years'];
const supportCoverages = ['Parts & Labour', 'Parts Only', 'Labour Only', 'Comprehensive (24/7)', 'Business Hours'];
const serviceProviders = ['ABC Engineering', 'Al Futtaim Engineering', 'Siemens LLC', 'Caterpillar Service', 'Dell Gulf'];

/// Largest invoice / document upload.
const maxUploadMb = 10;

// ---- Step 5
const operatingShifts = ['Day Shift', 'Night Shift', '2 Shifts', '24/7'];
const utilizationLevels = ['Standby', 'Low (< 30%)', 'Medium (30–70%)', 'High (> 70%)'];
const maintenanceFrequencyUnits = ['Days', 'Weeks', 'Months', 'Run Hours'];
const complianceStandards = [
  'ISO 8528',
  'ISO 9001',
  'ISO 14001',
  'ISO 45001',
  'NFPA 20',
  'NFPA 110',
  'IEC 60034',
  'ASHRAE 62.1',
  'Dubai Civil Defence',
];
const customFieldTypes = ['Text', 'Number', 'Date', 'Yes / No'];
const dimensionUnits = ['mm', 'cm', 'm'];
const weightUnits = ['kg', 't'];
const lifespanUnits = ['Years', 'Months'];
