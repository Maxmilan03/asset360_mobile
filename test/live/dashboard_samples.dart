/// Contract-shaped replies of the Dashboard service (MobileDashboardContracts.cs /
/// NetworkStatusContracts.cs, camelCase), with values that never appear in the mock data, so
/// tests can tell live numbers from mock ones. Shapes match what the DEV server on 5470 returns.
library;

const _breakdownStatus = [
  {'key': 'operational', 'label': 'Operational', 'count': 1, 'percent': 50},
  {'key': 'under-maintenance', 'label': 'Under Maintenance', 'count': 1, 'percent': 50},
  {'key': 'out-of-service', 'label': 'Out of Service', 'count': 0, 'percent': 0},
  {'key': 'retired', 'label': 'Retired', 'count': 0, 'percent': 0},
];

const dashLocatedAsset = {
  'assetRegistrationId': 'AR000001',
  'assetTag': 'TAG-0001',
  'assetName': 'Diesel Generator 500 kVA',
  'model': 'C15',
  'assetType': 'Generator',
  'status': 'Active',
  'statusGroup': 'operational',
  'locationLabel': 'Block A - Ground',
  'latitude': 25.0657,
  'longitude': 55.1713,
  'imageUrl': null,
};

const dashHomeJson = {
  'greeting': {
    'salutation': 'Good Afternoon',
    'userName': 'max.milan',
    'message': "Here's what's happening today",
    'generatedAtUtc': '2026-11-07T10:15:00Z',
  },
  'quickActions': {'openWorkOrders': 37, 'pendingInspections': 29, 'pendingApprovals': 17, 'criticalAlerts': 13},
  'assetOverview': {'totalAssets': 2, 'breakdown': _breakdownStatus},
  'maintenancePerformance': {
    'plannedPercent': 57.1,
    'months': 6,
    'breakdown': [
      {'key': 'planned', 'label': 'Planned', 'count': 4, 'percent': 57.1},
      {'key': 'unplanned', 'label': 'Unplanned', 'count': 2, 'percent': 28.6},
      {'key': 'overdue', 'label': 'Overdue', 'count': 1, 'percent': 14.3},
    ],
  },
  'upcomingActivities': [
    {'type': 'WorkOrder', 'label': 'Work Orders', 'count': 1, 'when': 'Today'},
    {'type': 'Inspection', 'label': 'Inspections', 'count': 0, 'when': 'Today'},
    {'type': 'Approval', 'label': 'Approvals', 'count': 17, 'when': 'Pending'},
  ],
  'recentAlerts': [
    {
      'id': '6650aa000000000000000001',
      'source': 'IoT',
      'title': 'High Temperature',
      'reference': 'TAG-0001 - Diesel Generator 500 kVA',
      'assetId': 'TAG-0001',
      'assetName': 'Diesel Generator 500 kVA',
      'severity': 'Critical',
      'status': 'Open',
      'occurredAtUtc': '2026-11-07T09:00:00Z',
    },
  ],
  'assetLocation': {
    'assetsWithLocation': 1,
    'center': {'latitude': 25.0657, 'longitude': 55.1713},
    'assets': [dashLocatedAsset],
  },
  'assetHealth': {
    'totalAssets': 2,
    'healthyPercent': 50,
    'breakdown': [
      {'key': 'healthy', 'label': 'Healthy', 'count': 1, 'percent': 50},
      {'key': 'warning', 'label': 'Warning', 'count': 0, 'percent': 0},
      {'key': 'critical', 'label': 'Critical', 'count': 1, 'percent': 50},
    ],
  },
};

const dashAssetOverviewJson = {
  'totalAssets': 2,
  'byStatus': _breakdownStatus,
  'byType': [
    {'key': 'generator', 'label': 'Generator', 'count': 1, 'percent': 50},
    {'key': 'chiller', 'label': 'Chiller', 'count': 1, 'percent': 50},
  ],
  'byLocation': [
    {'key': 'main-site', 'label': 'Main Site', 'count': 1, 'percent': 50},
    {'key': 'north-plant', 'label': 'North Plant', 'count': 1, 'percent': 50},
  ],
};

const dashMaintenanceJson = {
  'period': {'label': 'Last 6 Months', 'fromUtc': '2026-06-01T00:00:00Z', 'toUtc': '2026-11-07T10:15:00Z'},
  'plannedPercent': 57.1,
  'counts': {'total': 7, 'planned': 4, 'unplanned': 2, 'overdue': 1},
  'breakdown': [
    {'key': 'planned', 'label': 'Planned', 'count': 4, 'percent': 57.1},
    {'key': 'unplanned', 'label': 'Unplanned', 'count': 2, 'percent': 28.6},
    {'key': 'overdue', 'label': 'Overdue', 'count': 1, 'percent': 14.3},
  ],
  'trend': [
    {'month': '2026-06', 'label': 'Jun', 'planned': 1, 'unplanned': 0, 'overdue': 0},
    {'month': '2026-07', 'label': 'Jul', 'planned': 0, 'unplanned': 1, 'overdue': 0},
    {'month': '2026-08', 'label': 'Aug', 'planned': 1, 'unplanned': 0, 'overdue': 0},
    {'month': '2026-09', 'label': 'Sep', 'planned': 1, 'unplanned': 1, 'overdue': 0},
    {'month': '2026-10', 'label': 'Oct', 'planned': 1, 'unplanned': 0, 'overdue': 1},
    {'month': '2026-11', 'label': 'Nov', 'planned': 0, 'unplanned': 0, 'overdue': 0},
  ],
  'mttr': {'value': 5.5, 'unit': 'hrs', 'changePercent': -12.5, 'isImprovement': true},
  'mtbf': {'value': 41.3, 'unit': 'days', 'changePercent': null, 'isImprovement': null},
  'byAssetType': [
    {'assetType': 'Generator', 'total': 4, 'planned': 3, 'unplanned': 1, 'overdue': 0, 'plannedPercent': 75},
    {'assetType': 'Chiller', 'total': 3, 'planned': 1, 'unplanned': 1, 'overdue': 1, 'plannedPercent': 33.3},
  ],
};

const dashActivitiesJson = {
  'from': '2026-11-01',
  'to': '2026-12-26',
  'totalCount': 2,
  'days': [
    {'date': '2026-11-09', 'workOrders': 1, 'inspections': 0, 'approvals': 0, 'total': 1},
    {'date': '2026-11-10', 'workOrders': 0, 'inspections': 1, 'approvals': 0, 'total': 1},
  ],
  'items': [
    {
      'id': '6650bb000000000000000001',
      'type': 'WorkOrder',
      'reference': 'WO-7781',
      'title': 'Generator load bank test',
      'assetId': 'TAG-0001',
      'assetName': 'Diesel Generator 500 kVA',
      'location': 'Block A - Ground',
      'startUtc': '2026-11-09T05:00:00Z',
      'endUtc': '2026-11-09T07:00:00Z',
      'date': '2026-11-09',
      'status': 'Scheduled',
      'priority': 'High',
      'assignedTo': 'Sara Ali',
    },
    {
      'id': '6650bb000000000000000002',
      'type': 'Inspection',
      'reference': 'INS-3304',
      'title': 'Chiller quarterly inspection',
      'assetId': 'TAG-0002',
      'assetName': 'Chiller Unit 2',
      'location': null,
      'startUtc': '2026-11-10T06:00:00Z',
      'endUtc': null,
      'date': '2026-11-10',
      'status': 'Open',
      'priority': null,
      'assignedTo': null,
    },
  ],
};

const _alertCritical = {
  'id': '6650aa000000000000000001',
  'source': 'IoT',
  'title': 'High Temperature',
  'reference': 'TAG-0001 - Diesel Generator 500 kVA',
  'assetId': 'TAG-0001',
  'assetName': 'Diesel Generator 500 kVA',
  'severity': 'Critical',
  'status': 'Open',
  'occurredAtUtc': '2026-11-07T09:00:00Z',
};

const _alertWarning = {
  'id': '6650aa000000000000000002',
  'source': 'WorkOrder',
  'title': 'Work Order Overdue',
  'reference': 'WO-7700',
  'assetId': 'TAG-9999',
  'assetName': 'Chiller Unit 2',
  'severity': 'Warning',
  'status': 'In Progress',
  'occurredAtUtc': '2026-11-05T12:00:00Z',
};

/// GET /recent-alerts, honouring `severity`.
Map<String, Object?> dashAlertsJson(String? severity) {
  final all = [_alertCritical, _alertWarning];
  final items = [
    for (final a in all)
      if (severity == null || severity.toLowerCase() == 'all' || a['severity'] == severity) a,
  ];
  return {
    'counts': {'all': 2, 'critical': 1, 'warning': 1, 'info': 0},
    'page': 1,
    'pageSize': 20,
    'totalCount': items.length,
    'items': items,
  };
}

const dashLocationsJson = {
  'totalCount': 1,
  'center': {'latitude': 25.0657, 'longitude': 55.1713},
  'byStatus': [
    {'key': 'operational', 'label': 'Operational', 'count': 1, 'percent': 100},
    {'key': 'under-maintenance', 'label': 'Under Maintenance', 'count': 0, 'percent': 0},
    {'key': 'out-of-service', 'label': 'Out of Service', 'count': 0, 'percent': 0},
    {'key': 'retired', 'label': 'Retired', 'count': 0, 'percent': 0},
  ],
  'assets': [dashLocatedAsset],
};

/// What the DEV server returns today (no asset has coordinates).
const dashLocationsEmptyJson = {
  'totalCount': 0,
  'center': null,
  'byStatus': [
    {'key': 'operational', 'label': 'Operational', 'count': 0, 'percent': 0},
  ],
  'assets': <Object>[],
};

const dashHealthJson = {
  'totalAssets': 2,
  'healthyPercent': 50,
  'breakdown': [
    {'key': 'healthy', 'label': 'Healthy', 'count': 1, 'percent': 50},
    {'key': 'warning', 'label': 'Warning', 'count': 0, 'percent': 0},
    {'key': 'critical', 'label': 'Critical', 'count': 1, 'percent': 50},
  ],
  'byAssetType': [
    {'key': 'Generator', 'total': 1, 'healthy': 1, 'warning': 0, 'critical': 0, 'healthyPercent': 100},
    {'key': 'Chiller', 'total': 1, 'healthy': 0, 'warning': 0, 'critical': 1, 'healthyPercent': 0},
  ],
  'byLocation': [
    {'key': 'Main Site', 'total': 1, 'healthy': 1, 'warning': 0, 'critical': 0, 'healthyPercent': 100},
    {'key': 'North Plant', 'total': 1, 'healthy': 0, 'warning': 0, 'critical': 1, 'healthyPercent': 0},
  ],
  'criticalAssets': [
    {
      'assetRegistrationId': 'AR000002',
      'assetTag': 'TAG-0002',
      'assetName': 'Chiller Unit 2',
      'assetType': 'Chiller',
      'healthScore': 31.5,
      'issue': 'Compressor vibration high',
    },
  ],
};

const dashCostJson = {
  'currency': 'AED',
  'period': {'label': 'YTD 2026', 'fromUtc': '2026-01-01T00:00:00Z', 'toUtc': '2026-11-07T10:15:00Z'},
  'totalCost': 12500.5,
  'previousPeriodCost': 10000,
  'changePercent': 25,
  'categories': [
    {'key': 'maintenance', 'label': 'Maintenance', 'amount': 7000, 'percent': 56},
    {'key': 'operations', 'label': 'Operations', 'amount': 3000.5, 'percent': 24},
    {'key': 'spare-parts', 'label': 'Spare Parts', 'amount': 2500, 'percent': 20},
  ],
  'monthlyTrend': [
    {'month': '2026-09', 'label': 'Sep', 'maintenance': 4000, 'operations': 1000, 'spareParts': 500, 'total': 5500},
    {
      'month': '2026-10',
      'label': 'Oct',
      'maintenance': 3000,
      'operations': 2000.5,
      'spareParts': 2000,
      'total': 7000.5,
    },
  ],
  'byAssetType': [
    {'assetType': 'Generator', 'amount': 9000, 'percent': 72},
    {'assetType': 'Chiller', 'amount': 3500.5, 'percent': 28},
  ],
};

const _recentAsset1 = {
  'assetRegistrationId': 'AR000001',
  'assetTag': 'TAG-0001',
  'assetName': 'Diesel Generator 500 kVA',
  'model': 'C15',
  'manufacturer': 'Cummins',
  'category': 'Machinery & Equipment',
  'assetType': 'Generator',
  'status': 'Active',
  'statusGroup': 'operational',
  'locationLabel': 'Block A - Ground',
  'imageUrl': null,
  'createdAtUtc': '2026-10-01T08:00:00Z',
};

const _recentAsset2 = {
  'assetRegistrationId': 'AR000002',
  'assetTag': 'TAG-0002',
  'assetName': 'Chiller Unit 2',
  'model': null,
  'manufacturer': null,
  'category': 'HVAC',
  'assetType': 'Chiller',
  'status': 'Under Maintenance',
  'statusGroup': 'under-maintenance',
  'locationLabel': 'North Plant',
  'imageUrl': null,
  'createdAtUtc': '2026-09-20T08:00:00Z',
};

/// GET /recent-assets, honouring `status` (group key), `assetType` and `site`.
Map<String, Object?> dashRecentAssetsJson({String? status, String? assetType, String? site}) {
  final items = [
    for (final a in [_recentAsset1, _recentAsset2])
      if ((status == null || status == 'all' || a['statusGroup'] == status) &&
          (assetType == null || a['assetType'] == assetType) &&
          (site == null || (site == 'Main Site') == (a['assetRegistrationId'] == 'AR000001')))
        a,
  ];
  return {
    'counts': [
      {'key': 'all', 'label': 'All', 'count': 2, 'percent': 100},
      ..._breakdownStatus,
    ],
    'page': 1,
    'pageSize': 20,
    'totalCount': items.length,
    'items': items,
  };
}

const dashNetworkStatusJson = {'totalOnline': 12, 'totalOffline': 3};

/// The DEV server now sends assetRegistrationId (assetId is null).
const dashTagsJson = [
  {
    'tagId': 'E2801170000002089A1B',
    'count': 420,
    'assetId': null,
    'assetName': 'Diesel Generator 500 kVA',
    'assetRegistrationId': 'AR000001',
  },
  {'tagId': 'E2801170000002089FFF', 'count': 7, 'assetId': null, 'assetName': null, 'assetRegistrationId': null},
];

/// GET /mobile/my-tasks (MobileMyTasksResponse), honouring `type`.
Map<String, Object?> dashMyTasksJson({String? type}) {
  const items = [
    {
      'id': '6650cc000000000000000001',
      'type': 'WorkOrder',
      'reference': 'WO-8812',
      'title': 'Replace generator air filter',
      'assetId': 'TAG-0001',
      'assetName': 'Diesel Generator 500 kVA',
      'location': 'Block A - Ground',
      'dueUtc': '2026-11-05T08:00:00Z',
      'dueDate': '2026-11-05',
      'isOverdue': true,
      'status': 'In Progress',
      'priority': 'High',
    },
    {
      'id': '6650cc000000000000000002',
      'type': 'Inspection',
      'reference': 'INS-4410',
      'title': 'Chiller monthly checklist',
      'assetId': 'TAG-0002',
      'assetName': 'Chiller Unit 2',
      'location': null,
      'dueUtc': '2026-11-12T06:00:00Z',
      'dueDate': '2026-11-12',
      'isOverdue': false,
      'status': 'Scheduled',
      'priority': null,
    },
    {
      'id': '6650cc000000000000000003',
      'type': 'Approval',
      'reference': '6650cc000000000000000003',
      'title': 'Asset Transfer Approval',
      'assetId': null,
      'assetName': null,
      'location': null,
      'dueUtc': null,
      'dueDate': null,
      'isOverdue': false,
      'status': 'Pending',
      'priority': 'Medium',
    },
  ];
  final shown = [
    for (final i in items)
      if (type == null || i['type'] == type) i,
  ];
  return {
    'userName': 'max.milan',
    'matchedAssigneeNames': ['max.milan', 'Max Milan'],
    'counts': {'total': 3, 'workOrders': 1, 'inspections': 1, 'approvals': 1, 'overdue': 1, 'dueToday': 0},
    'items': shown,
  };
}
