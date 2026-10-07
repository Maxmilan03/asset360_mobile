import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/registration_mock.dart';

/// "Building / Floor – Zone", the format registered locations use.
String treeLocation(String building, String floor, String zone) => '$building / $floor – $zone';

/// Location tree sheet (Site → Building → Floor → Room / Zone). Returns "Building / Floor – Zone".
/// [site] limits the tree to one site.
Future<String?> showLocationPicker(BuildContext context, {String? site, String? selected}) {
  final sites = site != null && locationTree.containsKey(site) ? [site] : locationTree.keys.toList();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: false,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SheetTitle('Select Location', subtitle: sites.length == 1 ? sites.first : 'Site › Building › Floor › Zone'),
          for (final s in sites)
            _Node(
              label: s,
              icon: Icons.location_city_rounded,
              initiallyExpanded: sites.length == 1,
              children: [
                for (final MapEntry(key: building, value: floors) in locationTree[s]!.entries)
                  _Node(
                    label: building,
                    icon: Icons.apartment_rounded,
                    initiallyExpanded: selected?.startsWith('$building /') ?? false,
                    children: [
                      for (final MapEntry(key: floor, value: zones) in floors.entries)
                        _Node(
                          label: floor,
                          icon: Icons.layers_outlined,
                          initiallyExpanded: selected?.startsWith('$building / $floor') ?? false,
                          children: [
                            for (final zone in zones)
                              ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.only(left: 12, right: 4),
                                leading: Icon(Icons.place_outlined, size: 20, color: AppColors.primary),
                                title: Text(zone, style: AppText.body),
                                trailing: selected == treeLocation(building, floor, zone)
                                    ? Icon(Icons.check_rounded, color: AppColors.primary)
                                    : null,
                                onTap: () => Navigator.pop(context, treeLocation(building, floor, zone)),
                              ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _Node extends StatelessWidget {
  const _Node({required this.label, required this.icon, required this.children, this.initiallyExpanded = false});

  final String label;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    tilePadding: const EdgeInsets.only(right: 4),
    childrenPadding: const EdgeInsets.only(left: 16),
    shape: const Border(),
    leading: Icon(icon, size: 20, color: AppColors.textSecondary),
    title: Text(label, style: AppText.bodyStrong),
    children: children,
  );
}
