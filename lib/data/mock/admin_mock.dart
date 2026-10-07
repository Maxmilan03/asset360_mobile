/// Roles a user can hold (Administration → user detail).
const appRoles = [
  'Administrator',
  'DCS',
  'Operations',
  'Production',
  'Production Supervisor',
  'Maintenance Technician',
  'Warehouse Operator',
  'Warehouse',
  'AOI Operator',
  'IT',
  'Finance',
  'Viewer',
];

/// Permission levels in the Roles & Permissions matrix.
abstract final class Perm {
  static const full = 'Full';
  static const edit = 'Edit';
  static const view = 'View';
  static const none = '—';
}

const permissionModules = [
  'Assets',
  'Maintenance',
  'Inspection',
  'Inventory',
  'Movement',
  'Audit',
  'Financial',
  'Admin',
];

/// Role → one level per [permissionModules] entry (view-only matrix).
const permissionMatrix = <String, List<String>>{
  'Administrator': [Perm.full, Perm.full, Perm.full, Perm.full, Perm.full, Perm.full, Perm.full, Perm.full],
  'DCS': [Perm.edit, Perm.edit, Perm.edit, Perm.view, Perm.edit, Perm.edit, Perm.view, Perm.none],
  'Production Supervisor': [Perm.view, Perm.edit, Perm.edit, Perm.view, Perm.edit, Perm.view, Perm.none, Perm.none],
  'Maintenance Technician': [Perm.view, Perm.edit, Perm.edit, Perm.view, Perm.view, Perm.none, Perm.none, Perm.none],
  'Warehouse Operator': [Perm.view, Perm.none, Perm.none, Perm.edit, Perm.edit, Perm.view, Perm.none, Perm.none],
  'Finance': [Perm.view, Perm.view, Perm.none, Perm.view, Perm.none, Perm.view, Perm.full, Perm.none],
  'Viewer': [Perm.view, Perm.view, Perm.view, Perm.view, Perm.view, Perm.view, Perm.none, Perm.none],
};
