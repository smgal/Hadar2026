@TestOn('vm')
library;

import 'dart:io';

import 'package:lore_battle/lore_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

/// The invariants that stay fixed no matter how the rules change later:
/// no Flutter, no other package of this repo, no unseeded randomness, no
/// presentation text, no level table — and no turn spent on nothing.
///
/// Everything outside comments. The formula docs quote the design
/// documents in Korean next to the rule that implements them, which is
/// what makes the port auditable, so a raw grep over the file would flag
/// the very comments that matter.
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

  test('nothing imports Flutter or another package of this repo', () {
    final foreign = RegExp(
      r'''package:(flutter|hd_battle|hd_world|hd_bridge|lore_world|lore_battle_text|cm2_script)''',
    );
    for (final file in sources) {
      expect(foreign.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('only the generator imports dart:math, and nothing imports dart:io', () {
    for (final file in sources) {
      final text = code(file);
      expect(text.contains('dart:io'), isFalse, reason: file.path);
      if (!file.path.endsWith('rng.dart')) {
        expect(text.contains('dart:math'), isFalse, reason: file.path);
      }
    }
  });

  test('no unseeded Random() is constructed', () {
    final bare = RegExp(r'Random\(\s*\)');
    for (final file in sources) {
      expect(bare.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('no Korean in code - presentation belongs to the view', () {
    final hangul = RegExp(r'[가-힣]');
    for (final file in sources) {
      expect(
        hangul.hasMatch(code(file)),
        isFalse,
        reason:
            '${file.path} carries display text in code; the view '
            'owns sentences, names and particles',
      );
    }
  });

  test('no emoji in code - glyphs belong to the view', () {
    final emoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}]',
      unicode: true,
    );
    for (final file in sources) {
      expect(emoji.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('no level table - levelling is the RPG side', () {
    for (final file in sources) {
      final text = code(file);
      expect(text.contains('checkLevelUp'), isFalse, reason: file.path);
      // Two thresholds of ch.7.6's table that no stat or hit-point
      // figure could be. Their presence would mean the battle had
      // started deciding levels.
      expect(RegExp(r'\b1320000\b').hasMatch(text), isFalse, reason: file.path);
      expect(RegExp(r'\b3570000\b').hasMatch(text), isFalse, reason: file.path);
    }
  });

  test('the contract says lore-1', () {
    expect(contractVersion, 'lore-1');
  });

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
        setupFor(
          party: [
            for (var i = 0; i < 3; i++)
              knight(slot: i, name: 'far$i', rank: 3, accuracy: 19),
          ],
          enemyKeys: const ['orc_soldier', 'orc_soldier'],
          enemyRanks: const [3, 3],
          initialGap: 2,
          seed: 11,
        ),
      );
      final result = runBattle(
        battle,
        (d) => switch (d) {
          ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
          EnemyTargetDecision() => ChooseEnemyTarget(
            d.slot,
            d.enemyIndices.last,
          ),
          _ => CancelChoice(d.slot),
        },
      );
      expect(
        result.events.whereType<AttackStrained>(),
        isNotEmpty,
        reason: 'the distance has to be reported',
      );
      expect(
        result.events.any((e) => e is EnemyDamaged || e is EnemyCollapsed),
        isTrue,
        reason: 'and something still has to land',
      );
    });

    test('the skill list never offers a field-only ability', () {
      // 투시 · 예언 · 천리안 only say "not in battle". They are not ids.
      final everything = mage(skill: 100);
      for (final episode in const [1, 2, 3]) {
        for (final id in castableSkills(everything, episode: episode)) {
          expect(categoryOfSkill(id), isNotNull, reason: '$id');
        }
      }
      expect(espSpecs, hasLength(6));
    });

    test('the menu offers nothing the member cannot do', () {
      final battle = Battle(
        setupFor(
          party: [knight(), mage(slot: 1, mp: 0, skill: 0)],
          consumables: const {ItemKey.mpPotion: 1},
        ),
      )..advance();
      // A knight holds no magic: no skill line, and the magic potion is
      // not on his item list — so no item line either.
      final first = battle.pendingDecision! as ActionDecision;
      expect(first.slot, 0);
      expect(first.options, isNot(contains(BattleAction.castSkill)));
      expect(first.options, isNot(contains(BattleAction.useItem)));
      // A one-handed sword does not charge.
      expect(first.options, isNot(contains(BattleAction.charge)));
      battle.applyCommand(const ChooseAction(0, BattleAction.brace));
      // The mage has learned nothing, but can drink the potion.
      final second = battle.pendingDecision! as ActionDecision;
      expect(second.slot, 1);
      expect(second.options, isNot(contains(BattleAction.castSkill)));
      expect(second.options, contains(BattleAction.useItem));
    });
  });
}
