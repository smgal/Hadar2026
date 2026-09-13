import 'package:hd_world/hd_world.dart';

/// What a command *would* do, without doing it.
///
/// ## Why this exists at all
///
/// The reason anyone opens the equipment screen is to see what a swap
/// costs. Making them commit the swap, read the numbers, and undo it
/// turns one question into three actions and loses the before-picture
/// halfway through. A hover should answer it.
///
/// ## How the copy is made
///
/// `saveWorld` → `loadWorld` round trip. Not a hand-written clone: the
/// save format is already defined as "everything that cannot be
/// recomputed", which is exactly the definition of what a copy has to
/// carry. A hand-written one would be a second such list, free to drift
/// from the first.
///
/// It follows that anything the save format forgets, the preview
/// forgets too — and that is the right failure, because the real load
/// would forget it as well.
World cloneWorld(World world) => loadWorld(saveWorld(world)).world;

/// Runs [commands] on a copy and reports only the differences.
///
/// The `table` on a change names which text table the value belongs to,
/// so the screen can render it in Korean without the server holding any
/// Korean. A null `table` means the value is a number and stands alone.
Map<String, Object?> previewJson(World world, List<WorldCommand> commands) {
  final before = world.view.toJson();
  final copy = cloneWorld(world);

  final events = <Map<String, Object?>>[];
  for (final command in commands) {
    for (final event in copy.apply(command)) {
      events.add(event.toJson());
    }
  }
  final after = copy.view.toJson();
  final refused = events.where((e) => e['kind'] == 'refused').toList();

  return {
    'ok': refused.isEmpty,
    'events': events,
    'refused': refused,
    'changes': _diff(before, after),
  };
}

Map<String, Object?> _diff(Map<String, Object?> before, Map<String, Object?> after) {
  final beforeMembers = _membersByRef(before);
  final afterMembers = _membersByRef(after);

  final members = <Map<String, Object?>>[];
  for (final ref in afterMembers.keys) {
    final a = beforeMembers[ref];
    final b = afterMembers[ref]!;
    if (a == null) continue;
    final row = _memberDiff(a, b);
    if (row != null) members.add(row);
  }

  return {
    'members': members,
    'party': _partyDiff(
      (before['party']! as Map).cast<String, Object?>(),
      (after['party']! as Map).cast<String, Object?>(),
    ),
    'pack': _packDiff(before['pack'], after['pack']),
  };
}

Map<String, Map<String, Object?>> _membersByRef(Map<String, Object?> view) => {
  for (final m in (view['members']! as List).cast<Map<String, Object?>>())
    '${m['ref']}': m,
};

/// Which member fields are worth reporting, and which table names them.
///
/// A closed list rather than a walk of every key: a diff that reports
/// `classWire` changed is noise, and noise is what makes a comparison
/// panel get ignored.
const Map<String, String?> _memberScalars = {
  'weaponKind': 'weaponKind',
  'attackPower': null,
  'strikes': null,
  'style': 'style',
  'mainHandKind': 'itemKind',
  'mainHandShape': 'shape',
};

Map<String, Object?>? _memberDiff(
  Map<String, Object?> a,
  Map<String, Object?> b,
) {
  final changes = <Map<String, Object?>>[];

  void note(String key, String? table, Object? from, Object? to) {
    if (from == to) return;
    changes.add({
      'key': key,
      if (table != null) 'table': table,
      'from': from,
      'to': to,
    });
  }

  for (final e in _memberScalars.entries) {
    note(e.key, e.value, a[e.key], b[e.key]);
  }

  final aStats = (a['stats']! as Map).cast<String, Object?>();
  final bStats = (b['stats']! as Map).cast<String, Object?>();
  for (final key in bStats.keys) {
    note(key, 'stat', aStats[key], bStats[key]);
  }

  final aVitals = (a['vitals']! as Map).cast<String, Object?>();
  final bVitals = (b['vitals']! as Map).cast<String, Object?>();
  for (final key in const ['maxHitPoints', 'maxSpellPoints', 'maxEspPoints']) {
    note(key, 'stat', aVitals[key], bVitals[key]);
  }

  final slots = <Map<String, Object?>>[];
  final aSlots = _slotMap(a);
  final bSlots = _slotMap(b);
  for (final slot in bSlots.keys) {
    final from = aSlots[slot];
    final to = bSlots[slot];
    if (from?['item'] == to?['item'] && from?['locked'] == to?['locked']) {
      continue;
    }
    slots.add({
      'slot': slot,
      'from': from?['item'],
      'to': to?['item'],
      'lockedBefore': from?['locked'] ?? false,
      'lockedAfter': to?['locked'] ?? false,
    });
  }

  final gained = _setDiff(b['grants'], a['grants']);
  final lost = _setDiff(a['grants'], b['grants']);
  final immunityGained = _setDiff(b['immunities'], a['immunities']);
  final immunityLost = _setDiff(a['immunities'], b['immunities']);

  if (changes.isEmpty &&
      slots.isEmpty &&
      gained.isEmpty &&
      lost.isEmpty &&
      immunityGained.isEmpty &&
      immunityLost.isEmpty) {
    return null;
  }

  return {
    'ref': a['ref'],
    'name': a['name'],
    'changes': changes,
    'slots': slots,
    'grantsGained': gained,
    'grantsLost': lost,
    'immunitiesGained': immunityGained,
    'immunitiesLost': immunityLost,
  };
}

Map<String, Map<String, Object?>> _slotMap(Map<String, Object?> member) => {
  for (final s in (member['slots']! as List).cast<Map<String, Object?>>())
    '${s['slot']}': s,
};

List<String> _setDiff(Object? from, Object? without) {
  final a = from is List ? from.map((e) => '$e').toSet() : <String>{};
  final b = without is List ? without.map((e) => '$e').toSet() : <String>{};
  return a.difference(b).toList()..sort();
}

List<Map<String, Object?>> _partyDiff(
  Map<String, Object?> a,
  Map<String, Object?> b,
) {
  final out = <Map<String, Object?>>[];
  for (final key in const [
    'sightInDarkness',
    'lightBearers',
    'moonlight',
    'magicLight',
  ]) {
    if (a[key] != b[key]) {
      out.add({'key': key, 'from': a[key], 'to': b[key]});
    }
  }
  final gained = _setDiff(b['capabilities'], a['capabilities']);
  final lost = _setDiff(a['capabilities'], b['capabilities']);
  for (final c in gained) {
    out.add({'key': 'capability', 'table': 'capability', 'from': null, 'to': c});
  }
  for (final c in lost) {
    out.add({'key': 'capability', 'table': 'capability', 'from': c, 'to': null});
  }
  return out;
}

List<Map<String, Object?>> _packDiff(Object? before, Object? after) {
  Map<String, int> counts(Object? raw) => {
    if (raw is List)
      for (final row in raw.cast<Map<String, Object?>>())
        '${row['item']}': (row['count'] as num?)?.toInt() ?? 0,
  };
  final a = counts(before);
  final b = counts(after);
  final keys = {...a.keys, ...b.keys}.toList()..sort();
  return [
    for (final key in keys)
      if ((a[key] ?? 0) != (b[key] ?? 0))
        {'item': key, 'from': a[key] ?? 0, 'to': b[key] ?? 0},
  ];
}
