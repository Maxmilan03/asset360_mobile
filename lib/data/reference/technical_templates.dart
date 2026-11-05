/// TEMP until the category attributes API (GET /api/asset-categories/{id}/attributes).
/// Technical Details fields per asset type (Register Asset step 5). Each spec field is saved as an
/// AssetSpecificationDto {name, value, unit}; dimensions, weight and lifespan have their own
/// AssetTechnicalDetailsDto fields and are switched on per template. Types without a template show
/// only Technical Remarks.
library;

class SpecField {
  const SpecField(this.name, {this.unit, this.options = const [], this.numeric = false, this.hint, this.serverList});

  final String name;

  /// API mode: the list in GET /api/asset-registrations/options → additionalInformation that
  /// replaces [options] ("phases", "fuelTypes", "ipRatings").
  final String? serverList;

  /// Fixed unit shown after the value (kVA, V …); null for none.
  final String? unit;

  /// Non-empty = a dropdown.
  final List<String> options;
  final bool numeric;
  final String? hint;
}

class TechnicalTemplate {
  const TechnicalTemplate({required this.specs, this.dimensions = false, this.weight = false, this.lifespan = false});

  final List<SpecField> specs;
  final bool dimensions;
  final bool weight;
  final bool lifespan;

  /// Types without a template: no specifications, but the backend's own technical fields
  /// (dimensions, weight, lifespan) and Technical Remarks.
  static const remarksOnly = TechnicalTemplate(specs: [], dimensions: true, weight: true, lifespan: true);
}

const _generator = TechnicalTemplate(
  specs: [
    SpecField('Power Rating', unit: 'kVA', numeric: true, hint: 'e.g. 250'),
    SpecField('Voltage', unit: 'V', numeric: true, hint: 'e.g. 400'),
    SpecField('Frequency', unit: 'Hz', options: ['50', '60']),
    SpecField('Phase', options: ['3 Phase', 'Single Phase'], serverList: 'phases'),
    SpecField('Fuel Type', options: ['Diesel', 'Natural Gas', 'Petrol', 'Bi-Fuel', 'Solar'], serverList: 'fuelTypes'),
    SpecField('Fuel Tank Capacity', unit: 'Liters', numeric: true, hint: 'e.g. 500'),
    SpecField('Operating Temperature Range', unit: '°C', hint: 'e.g. -10 to 50'),
    SpecField('IP Rating', options: ['IP23', 'IP44', 'IP54', 'IP55', 'IP65'], serverList: 'ipRatings'),
    SpecField('Noise Level', unit: 'dB(A)', numeric: true, hint: 'e.g. 75'),
  ],
  dimensions: true,
  weight: true,
  lifespan: true,
);

const _laptop = TechnicalTemplate(
  specs: [
    SpecField('Processor', hint: 'e.g. Intel Core i7-1365U'),
    SpecField('RAM', unit: 'GB', options: ['8', '16', '32', '64']),
    SpecField('Storage', unit: 'GB', options: ['256', '512', '1024', '2048']),
    SpecField('Screen Size', unit: 'in', numeric: true, hint: 'e.g. 14'),
    SpecField('Operating System', options: ['Windows 11 Pro', 'Windows 10 Pro', 'macOS', 'Ubuntu']),
  ],
  weight: true,
  lifespan: true,
);

const _hvac = TechnicalTemplate(
  specs: [
    SpecField('Cooling Capacity', unit: 'TR', numeric: true, hint: 'e.g. 30'),
    SpecField('Airflow', unit: 'CFM', numeric: true, hint: 'e.g. 12000'),
    SpecField('Refrigerant', options: ['R-410A', 'R-134a', 'R-32', 'R-407C']),
    SpecField('Power Input', unit: 'kW', numeric: true),
    SpecField('Voltage', unit: 'V', numeric: true, hint: 'e.g. 415'),
  ],
  dimensions: true,
  weight: true,
  lifespan: true,
);

const _forklift = TechnicalTemplate(
  specs: [
    SpecField('Load Capacity', unit: 'kg', numeric: true, hint: 'e.g. 2500'),
    SpecField('Lift Height', unit: 'mm', numeric: true, hint: 'e.g. 4500'),
    SpecField('Power Source', options: ['Electric', 'Diesel', 'LPG']),
    SpecField('Battery Voltage', unit: 'V', numeric: true, hint: 'e.g. 48'),
  ],
  weight: true,
  lifespan: true,
);

const _firePump = TechnicalTemplate(
  specs: [
    SpecField('Rated Flow', unit: 'GPM', numeric: true, hint: 'e.g. 1000'),
    SpecField('Rated Pressure', unit: 'bar', numeric: true, hint: 'e.g. 10'),
    SpecField('Driver Type', options: ['Electric', 'Diesel']),
    SpecField('Power Rating', unit: 'kW', numeric: true),
    SpecField('Listing / Standard', options: ['NFPA 20', 'UL / FM Listed', 'EN 12845']),
  ],
  lifespan: true,
);

/// Asset type → template.
const technicalTemplates = <String, TechnicalTemplate>{
  'Generator': _generator,
  'Laptop': _laptop,
  'Air Handling Unit': _hvac,
  'Chiller': _hvac,
  'Forklift': _forklift,
  'Fire Pump': _firePump,
};

TechnicalTemplate technicalTemplateFor(String? assetType) =>
    technicalTemplates[assetType] ?? TechnicalTemplate.remarksOnly;
