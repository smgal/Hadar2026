@TestOn('vm')
library;

import 'dart:io';

import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// The invariants B1-06 also enforces in CI, asserted here so a local
/// `dart test` catches them before a push.
///
/// These are the four things that stay fixed no matter how the rules
/// change later: no Flutter, no unseeded randomness, no presentation
/// text, no level table.
/// Everything outside comments. The formula docs quote the original
/// source verbatim — `Random().nextInt(50)` and the rest — so a raw grep
/// over the file would flag the very comments that make the port
/// auditable.
String code(File file) => file
    .readAsLinesSync()
    .map((line) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) return '';
      final marker = line.indexOf('//');
      return marker == -1 ? line : line.substring(0, marker);
    })
    .join('\n');

void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('there are sources to check', () {
    expect(sources, isNotEmpty);
  });

  test('nothing imports Flutter', () {
    for (final file in sources) {
      expect(
        code(file).contains('package:flutter'),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('no unseeded Random() is constructed', () {
    // `SeededRng` builds `Random(seed)`; a bare `Random()` is what made
    // the original impossible to reproduce (P0-11).
    final bare = RegExp(r'Random\(\s*\)');
    for (final file in sources) {
      expect(bare.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('no Korean in code - presentation belongs to the view', () {
    // The invariant is **no display text in the model**: B1-04 phrased it
    // as "zero Korean sentence literals". Comments are checked out of
    // scope on purpose — naming a spell 마법 화살 next to the rule that
    // implements it is what makes the port auditable, and a comment is
    // never rendered. Everything the machine executes is English.
    final hangul = RegExp(r'[가-힣]');
    for (final file in sources) {
      expect(
        hangul.hasMatch(code(file)),
        isFalse,
        reason:
            '${file.path} carries display text in code; the view '
            'owns sentences and particles',
      );
    }
  });

  test('no emoji in code - glyphs belong to the view (B6-01)', () {
    // The skill list is tagged by `SkillScope`, an enum. The view turns
    // it into a glyph; the model never holds one.
    final emoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}]',
      unicode: true,
    );
    for (final file in sources) {
      expect(emoji.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('no experience table - level-up is the RPG side (B3-05)', () {
    for (final file in sources) {
      final text = code(file);
      expect(text.contains('checkLevelUp'), isFalse, reason: file.path);
      // The RPG table's first non-zero tier. Its presence would mean the
      // battle had started deciding levels.
      expect(RegExp(r'\b1500\b').hasMatch(text), isFalse, reason: file.path);
    }
  });
  _noWastedTurns();
}

/// B5-99 — the invariant the whole position track rests on.
void _noWastedTurns() {
  group('no path spends a turn on nothing', () {
    test('every weapon answers at every distance', () {
      for (final weapon in weaponTable.values) {
        for (var d = 0; d <= longestPossibleReach; d++) {
          expect(
            chooseAttack(weapon, d).power,
            greaterThan(0),
            reason: '${weapon.key} at $d',
          );
        }
      }
    });

    test('interception is never certain', () {
      for (var short = 1; short <= 8; short++) {
        expect(reachPenalty(short).interception, lessThan(100));
      }
    });

    test('a battle fought at maximum distance still produces damage', () {
      // Everyone in the back rank, everything in the back rank, the gap
      // as wide as it goes: as far out of reach as the game can be.
      final battle = Battle(
        BattleSetup(
          party: [
            for (var i = 0; i < 3; i++)
              CombatantSnapshot(
                slot: i,
                name: 'far$i',
                hp: 300,
                maxHp: 300,
                rank: 3,
                strength: 16,
                powOfWeapon: 16,
                levelPhysical: 3,
                accuracyPhysical: 19,
                weaponKey: 'dagger',
              ),
          ],
          enemyKeys: const ['orc', 'orc'],
          enemyRanks: const [3, 3],
          initialGap: 2,
          seed: 11,
        ),
      );
      final events = <BattleEvent>[];
      var guard = 0;
      while (!battle.isFinished && guard++ < 4000) {
        final d = battle.pendingDecision;
        if (d == null) {
          events.addAll(battle.advance());
          continue;
        }
        battle.applyCommand(switch (d) {
          ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
          EnemyTargetDecision() => ChooseEnemyTarget(
            d.slot,
            d.enemyIndices.last,
          ),
          _ => CancelChoice(d.slot),
        });
      }
      expect(
        events.whereType<AttackStrained>(),
        isNotEmpty,
        reason: 'the distance has to be reported',
      );
      expect(
        events.any((e) => e is EnemyDamaged || e is EnemyCollapsed),
        isTrue,
        reason: 'and something still has to land',
      );
    });

    test('no skill the menu offers spends a turn on nothing', () {
      // The invariant the whole position track rests on, checked where
      // it was actually broken: three ESP abilities were offered and
      // did nothing at all (appendix Z-9). Spells 33-40 were left out
      // for the same reason; these were the same case.
      for (var level = 0; level <= 20; level++) {
        for (final id in castableSkills(levelMagic: level, levelEsp: level)) {
          if (id < 41) continue;
          expect(
            espAbilityFor(id),
            isNot(EspAbility.inert),
            reason: 'skill $id is offered at esp level $level and is inert',
          );
        }
      }
    });

    test('the contract says v4', () {
      expect(contractVersion, 'v4');
    });
  });
}
