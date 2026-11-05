import 'package:drift/drift.dart';

import 'package:asset360_mobile/data/db/app_database.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';

/// Short, printable code for one location name: "Building A" → BLD-A, "Floor 2" → F2,
/// "Ground Floor" → GF, "Production Floor 1" → PF1, "Line 3" → L3, "Roof" → ROOF.
String locationAbbr(String name) {
  final n = name.trim();
  final building = RegExp(r'^Building\s+(\w+)$', caseSensitive: false).firstMatch(n);
  if (building != null) return 'BLD-${building[1]!.toUpperCase()}';
  final floor = RegExp(r'^(?:Floor\s+(\d+)|(\d+)(?:st|nd|rd|th)\s+Floor)$', caseSensitive: false).firstMatch(n);
  if (floor != null) return 'F${floor[1] ?? floor[2]}';
  if (n.toLowerCase() == 'ground floor') return 'GF';
  final words = n.split(RegExp(r'[\s/–-]+')).where((w) => w.isNotEmpty).toList();
  if (words.length == 1) {
    final w = words.single.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    return w.length <= 4 ? w : w.substring(0, 4);
  }
  return [
    for (final w in words)
      if (RegExp(r'^\d+$').hasMatch(w)) w else if (RegExp('[A-Za-z]').hasMatch(w)) w[0].toUpperCase(),
  ].join();
}

/// Every node of [locationTree] (Site → Building → Floor → Room) with a unique code:
/// site "DF", building "BLD-A", floor "BLD-A-F2", room "BLD-A-F2-O".
List<LocationsCompanion> seedLocationRows() {
  final used = <String>{};
  String unique(String code) {
    var c = code;
    for (var i = 2; used.contains(c); i++) {
      c = '$code$i';
    }
    used.add(c);
    return c;
  }

  final rows = <LocationsCompanion>[];
  for (final MapEntry(key: site, value: buildings) in locationTree.entries) {
    final siteCode = unique(locationAbbr(site));
    rows.add(LocationsCompanion.insert(code: siteCode, site: site, level: LocationLevel.site));
    for (final MapEntry(key: building, value: floors) in buildings.entries) {
      final b = unique(locationAbbr(building));
      rows.add(
        LocationsCompanion.insert(code: b, site: site, building: Value(building), level: LocationLevel.building),
      );
      for (final MapEntry(key: floor, value: rooms) in floors.entries) {
        final f = unique('$b-${locationAbbr(floor)}');
        rows.add(
          LocationsCompanion.insert(
            code: f,
            site: site,
            building: Value(building),
            floor: Value(floor),
            level: LocationLevel.floor,
          ),
        );
        for (final room in rooms) {
          rows.add(
            LocationsCompanion.insert(
              code: unique('$f-${locationAbbr(room)}'),
              site: site,
              building: Value(building),
              floor: Value(floor),
              room: Value(room),
              level: LocationLevel.room,
            ),
          );
        }
      }
    }
  }
  return rows;
}

extension DbLocationX on DbLocation {
  /// "Floor 2 – Building A", "Offices – Floor 2 – Building A", "Building A – Dubai Factory".
  String get label => switch (level) {
    LocationLevel.site => site,
    LocationLevel.building => '$building – $site',
    LocationLevel.floor => '$floor – $building',
    LocationLevel.room => '$room – $floor – $building',
  };
}

extension DbLocationPath on DbLocation {
  /// The location text the app's records use: "Building / Floor – Room", "Building / Floor", "Building", or the site.
  String get path => switch (level) {
    LocationLevel.site => site,
    LocationLevel.building => building!,
    LocationLevel.floor => '$building / $floor',
    LocationLevel.room => '$building / $floor – $room',
  };
}

/// Location code of a [locationTree] node by names (the same codes the Locations table is seeded
/// with); null when the path is not in the tree. Registration stores these as the *Id fields.
String? locationCodeOf(String? site, [String? building, String? floor, String? room]) {
  if (site == null) return null;
  final key = [site, building, floor, room].join('|');
  return (_codeByPath ??= {
    for (final r in seedLocationRows())
      [r.site.value, r.building.value, r.floor.value, r.room.value].join('|'): r.code.value,
  })[key];
}

Map<String, String>? _codeByPath;
