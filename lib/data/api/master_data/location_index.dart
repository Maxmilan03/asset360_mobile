import 'package:asset360_mobile/data/api/master_data/master_data_models.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';

/// The levels of the Master Data location tree, by depth: roots are countries, their children
/// sites, and so on. The service's `type` is free text, so depth decides (see
/// docs/questions_for_backend.md).
enum MdLocationLevel {
  country('Country'),
  site('Site'),
  building('Building'),
  floor('Floor'),
  zone('Zone'),
  room('Room');

  const MdLocationLevel(this.label);

  final String label;
}

/// A picked location: the nodes from the country down to the deepest level chosen.
class MdLocationPath {
  const MdLocationPath([this.nodes = const []]);

  static const empty = MdLocationPath();

  final List<MdLocationNode> nodes;

  bool get isEmpty => nodes.isEmpty;

  MdLocationNode? at(MdLocationLevel level) => level.index < nodes.length ? nodes[level.index] : null;

  MdLocationNode? get deepest => nodes.isEmpty ? null : nodes.last;

  MdLocationLevel? get level => nodes.isEmpty ? null : MdLocationLevel.values[nodes.length - 1];

  /// The path up to and including [level] with [node] at that level (levels below are dropped).
  MdLocationPath pick(MdLocationLevel level, MdLocationNode? node) =>
      MdLocationPath([...nodes.take(level.index), ?node]);

  /// "UAE > Dubai Factory > Building A > Floor 2".
  String get label => [for (final n in nodes) n.name].join(' > ');

  /// Writes every level's id + name (levels not picked are cleared) and the path into [l].
  void writeTo(AssetLocation l) {
    String? id(MdLocationLevel v) => at(v)?.id;
    String? name(MdLocationLevel v) => at(v)?.name;
    l
      ..countryId = id(MdLocationLevel.country)
      ..countryName = name(MdLocationLevel.country)
      ..siteId = id(MdLocationLevel.site)
      ..siteName = name(MdLocationLevel.site)
      ..buildingId = id(MdLocationLevel.building)
      ..buildingName = name(MdLocationLevel.building)
      ..floorId = id(MdLocationLevel.floor)
      ..floorName = name(MdLocationLevel.floor)
      ..zoneId = id(MdLocationLevel.zone)
      ..zoneName = name(MdLocationLevel.zone)
      ..roomId = id(MdLocationLevel.room)
      ..roomName = name(MdLocationLevel.room)
      ..serverLocationPath = isEmpty ? null : label;
  }

  @override
  bool operator ==(Object other) =>
      other is MdLocationPath &&
      other.nodes.length == nodes.length &&
      [for (var i = 0; i < nodes.length; i++) other.nodes[i].id == nodes[i].id].every((e) => e);

  @override
  int get hashCode => Object.hashAll(nodes.map((n) => n.id));
}

/// Lookups over the location tree: by id, by code, children, and the path of a node.
class MdLocationIndex {
  MdLocationIndex(this.roots) {
    void walk(MdLocationNode n, MdLocationNode? parent) {
      _byId[n.id] = n;
      if (parent != null) _parent[n.id] = parent;
      final code = n.code.trim().toLowerCase();
      if (code.isNotEmpty) _byCode.putIfAbsent(code, () => n);
      for (final c in n.children) {
        walk(c, n);
      }
    }

    for (final r in roots) {
      walk(r, null);
    }
  }

  final List<MdLocationNode> roots;
  final _byId = <String, MdLocationNode>{};
  final _byCode = <String, MdLocationNode>{};
  final _parent = <String, MdLocationNode>{};

  bool get isEmpty => roots.isEmpty;

  int get length => _byId.length;

  MdLocationNode? byId(String? id) => id == null ? null : _byId[id];

  /// Case-insensitive match on the location's `code` (printed as "LOC:<code>").
  MdLocationNode? byCode(String? code) => code == null ? null : _byCode[code.trim().toLowerCase()];

  /// Roots for [parent] == null, else the parent's children.
  List<MdLocationNode> childrenOf(MdLocationNode? parent) => parent == null ? roots : parent.children;

  /// Root → [node]; empty for an unknown node. Paths deeper than six levels are cut at Room.
  MdLocationPath pathTo(MdLocationNode? node) {
    if (node == null || !_byId.containsKey(node.id)) return MdLocationPath.empty;
    final chain = <MdLocationNode>[node];
    for (var p = _parent[node.id]; p != null; p = _parent[p.id]) {
      chain.insert(0, p);
    }
    return MdLocationPath(chain.take(MdLocationLevel.values.length).toList());
  }

  /// The deepest saved level of [l] that is in the tree (ids first, then names under the parent).
  MdLocationPath pathOf(AssetLocation l) {
    final ids = [l.countryId, l.siteId, l.buildingId, l.floorId, l.zoneId, l.roomId];
    for (final id in ids.reversed) {
      final n = byId(id);
      if (n != null) return pathTo(n);
    }
    final names = [l.countryName, l.siteName, l.buildingName, l.floorName, l.zoneName, l.roomName];
    MdLocationNode? at;
    for (final name in names) {
      if (name == null) break;
      final next = childrenOf(at).where((c) => c.name == name).firstOrNull;
      if (next == null) break;
      at = next;
    }
    return pathTo(at);
  }
}
