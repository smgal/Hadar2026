@TestOn('vm')
library;

import 'dart:io';

import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// Compares the seeded table against the RPG-side source it came from,
/// row by row.
///
/// The seed conversion (`tools/battle/convert_enemy_table.py`) is a
/// one-shot, so this is what stops a hand edit from drifting away from
/// the original data. It reads the Dart source as text rather than
/// importing it — `hd_battle` must not depend on the Flutter app.
///
/// Once the RPG side deletes its table (B4-03) this test goes with it.
void main() {
  final source = File('../../hadar2026_app/lib/domain/battle/enemy_data.dart');

  test('every row matches the RPG-side table', () {
    if (!source.existsSync()) {
      markTestSkipped('RPG-side table not present at ${source.path}');
      return;
    }

    final row = RegExp(
      r"HDEnemyData\(id:\s*(\d+),\s*name:\s*'([^']*)',\s*strength:\s*(-?\d+),"
      r"\s*mentality:\s*(-?\d+),\s*endurance:\s*(-?\d+),"
      r"\s*resistance:\s*(-?\d+),\s*agility:\s*(-?\d+),"
      r"\s*accuracy:\s*\[(-?\d+),\s*(-?\d+)\],\s*ac:\s*(-?\d+),"
      r"\s*special:\s*(-?\d+),\s*castLevel:\s*(-?\d+),"
      r"\s*specialCastLevel:\s*(-?\d+),\s*level:\s*(-?\d+)\)",
    );
    final matches = row.allMatches(source.readAsStringSync()).toList();

    expect(matches.length, enemyTable.length, reason: 'row count drifted');

    for (final m in matches) {
      final id = int.parse(m.group(1)!);
      final e = enemyByLegacyId[id];
      expect(e, isNotNull, reason: 'legacy id $id is missing');
      expect(e!.name, m.group(2), reason: 'id $id name');
      expect(e.strength, int.parse(m.group(3)!), reason: '${e.key} strength');
      expect(e.mentality, int.parse(m.group(4)!), reason: '${e.key} mentality');
      expect(e.endurance, int.parse(m.group(5)!), reason: '${e.key} endurance');
      expect(
        e.resistance,
        int.parse(m.group(6)!),
        reason: '${e.key} resistance',
      );
      expect(e.agility, int.parse(m.group(7)!), reason: '${e.key} agility');
      expect(e.accuracy[0], int.parse(m.group(8)!), reason: '${e.key} acc0');
      expect(e.accuracy[1], int.parse(m.group(9)!), reason: '${e.key} acc1');
      expect(e.ac, int.parse(m.group(10)!), reason: '${e.key} ac');
      expect(e.special, int.parse(m.group(11)!), reason: '${e.key} special');
      expect(e.castLevel, int.parse(m.group(12)!), reason: '${e.key} cast');
      expect(
        e.specialCastLevel,
        int.parse(m.group(13)!),
        reason: '${e.key} specialCast',
      );
      expect(e.level, int.parse(m.group(14)!), reason: '${e.key} level');
    }
  });
}
