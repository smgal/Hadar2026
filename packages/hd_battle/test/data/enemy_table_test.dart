import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// Pins the seeded table (B1-02).
///
/// The row values are checked against the RPG-side table in
/// `enemy_table_parity_test.dart`, which reads that file directly. This
/// file pins the shape: 75 rows, unique snake_case keys, complete legacy
/// index coverage.
void main() {
  test('has 75 rows', () {
    expect(enemyTable.length, 75);
  });

  test('legacy ids cover 0..74 exactly once', () {
    final ids = enemyTable.map((e) => e.legacyId).toList()..sort();
    expect(ids, List.generate(75, (i) => i));
  });

  test('keys are unique', () {
    final keys = enemyTable.map((e) => e.key).toSet();
    expect(keys.length, enemyTable.length);
  });

  test('keys are snake_case', () {
    final pattern = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');
    for (final e in enemyTable) {
      expect(
        pattern.hasMatch(e.key),
        isTrue,
        reason: '"${e.key}" (from "${e.name}")',
      );
    }
  });

  test('both lookups reach every row', () {
    expect(enemyByKey.length, enemyTable.length);
    expect(enemyByLegacyId.length, enemyTable.length);
    for (final e in enemyTable) {
      expect(enemyByKey[e.key], same(e));
      expect(enemyByLegacyId[e.legacyId], same(e));
    }
  });

  test('accuracy is always a pair', () {
    for (final e in enemyTable) {
      expect(e.accuracy.length, 2, reason: e.key);
    }
  });

  test('the ids the shipped scripts summon all resolve', () {
    // Battle::RegisterEnemy arguments found across assets/*.cm2.
    for (final id in [1, 3, 5, 7, 26, 69, 71]) {
      expect(enemyByLegacyId[id], isNotNull, reason: 'legacy id $id');
    }
  });

  test('id 0 is Orc and is summonable', () {
    // P0-15: the old guard read `<= 0` and made this row unreachable.
    expect(enemyByLegacyId[0]!.name, 'Orc');
    expect(enemyByLegacyId[0]!.key, 'orc');
  });
}
