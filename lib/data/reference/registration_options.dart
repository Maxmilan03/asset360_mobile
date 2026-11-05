/// Dropdown values of the Register Asset form, matching the web app's Register Asset screens.
/// Kept in one file so each list can be swapped for an API lookup later
/// (e.g. GET /api/asset-categories, /api/asset-category-types, /api/asset-models).
///
/// Value lists (status, lifecycle stage, currencies …) live in asset_options.dart.
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
      // Web Classification Hierarchy: Generator, Transformer, UPS, Switchgear, Control Panel, Others.
      AssetTypeOption('Transformer', prefix: 'TRF'),
      AssetTypeOption('UPS', prefix: 'UPS'),
      AssetTypeOption('Switchgear', prefix: 'SWG'),
      AssetTypeOption('Control Panel', prefix: 'CP'),
      AssetTypeOption('Others', prefix: 'AST'),
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
    SubCategoryOption('Tools', [
      AssetTypeOption('Tool Box', prefix: 'TL'),
      AssetTypeOption('Drill Machine', prefix: 'DRL'),
    ]),
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

// ---- Step 3
/// Country (countryId → countryName) → the sites of the location tree in it. TEMP until the
/// location API: the web shows "UAE".
const countries = {
  'AE': (name: 'UAE', sites: ['Dubai Factory', 'Dubai Office', 'Education City']),
};

// ---- Step 4
const suppliers = mock.suppliers;

/// Largest invoice / document upload.
const maxUploadMb = 10;
