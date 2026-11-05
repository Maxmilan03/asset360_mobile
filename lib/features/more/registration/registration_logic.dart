/// Register Asset steps (stepper labels) — the web form's 5 steps plus Review (mobile only).
/// Validation: data/validation/asset_registration_validator.dart; Asset mapping:
/// data/models/asset_registration_mapping.dart.
const registrationSteps = ['Basic', 'Classification', 'Location', 'Purchase', 'Additional', 'Review'];

/// Step titles above each step's fields.
const registrationStepTitles = [
  'Basic Information',
  'Classification',
  'Location & Assignment',
  'Purchase & Warranty',
  'Additional Information',
  'Review',
];

/// Step subtitles, as on the web stepper.
const registrationStepSubtitles = [
  'Asset details and identification',
  'Category and type',
  'Where and with whom',
  'Cost and warranty details',
  'Custom fields and attachments',
  'Check everything, then Submit',
];
