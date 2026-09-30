/// Quick actions on Home, in default order. The first 7 enabled ones are shown,
/// followed by "More Actions". Customize can reorder and toggle them.
const defaultQuickActions = [
  ('scan', true),
  ('reportIssue', true),
  ('moveAsset', true),
  ('createWorkOrder', true),
  ('startInspection', true),
  ('assetAudit', true),
  ('inventoryIssue', true),
  ('registerAsset', false),
  ('trackAsset', false),
  ('documents', false),
  ('offlineSync', false),
];

/// Assets the user opened recently (Home "Recent Assets"), newest first.
const seedRecentAssetIds = ['CNC-00123', 'GEN-00045'];

/// Last 6 months of the maintenance KPIs (Apr … Sep 2026); the last value is the current one.
const kpiMonths = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'];
const kpiTrends = {
  'pm': [86.0, 88.0, 87.0, 90.0, 91.0, 92.0],
  'mttr': [2.6, 2.4, 2.3, 2.1, 1.9, 1.8],
  'closure': [93.0, 94.0, 96.0, 95.0, 97.0, 98.0],
  'downtime': [19.0, 17.0, 16.0, 15.0, 13.0, 12.0],
};
