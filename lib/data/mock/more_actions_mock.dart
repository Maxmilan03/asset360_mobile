/// Options for the asset More Actions forms (features/assets/more_actions/).
library;

/// Check Out → Purpose.
const checkOutPurposes = ['Project Work', 'Site Visit', 'Field Service', 'Training', 'Temporary Use', 'Other'];

/// Add to Favorites → Favorite Group (users can add more; kept in memory).
const defaultFavoriteGroups = ['My Assets', 'Critical Equipment', 'IT Equipment'];

/// Print Asset Tag → Tag Type.
const tagTypes = ['Standard Asset Tag', 'Small Label', 'QR Only'];

/// Print Asset Tag → Printer. The first prints through the system print dialog;
/// the Zebra label printer is simulated.
const labelPrinters = ['Office Printer (Default)', 'Zebra ZD421 (demo)'];
const zebraPrinter = 'Zebra ZD421 (demo)';
const maxTagCopies = 20;

/// Share Asset Details → demo link to the asset.
String assetShareLink(String assetId) => 'https://asset360.purpleiq.ae/a/$assetId';

/// Postal address of each site (View on Map → Current Location).
const siteAddresses = {
  'Dubai Factory': 'Plot 598-1074, Dubai Investments Park 2, Dubai, UAE',
  'Dubai Office': 'Head Office, Al Saqr Business Tower, Sheikh Zayed Road, Dubai, UAE',
  'Education City': 'Education City Campus, Al Ruwais Street, Dubai, UAE',
};

/// Create Disposal Request → Disposal Reason ("Other" asks for the reason).
const disposalReasons = ['End of Life', 'Damaged / Not Repairable', 'Upgrade / Replacement', 'Lost / Missing', 'Other'];
const disposalOtherReason = 'Other';

/// Add Photo / Video → longest video.
const maxVideoSeconds = 60;
