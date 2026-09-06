import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B2-06 · B2-08 · B2-09 — the three with no original to port.
void main() {
  group('B2-06 items', () {
    test('the table splits into medical, crystal and coating', () {
      expect(battleItems, isNotEmpty);
      for (final item in battleItems.values) {
        switch (item.kind) {
          case BattleItemKind.medical:
            // A medical item either runs cure steps or restores spell
            // points (B6-05's tonic) — one or the other, never neither.
            expect(
              item.cureSteps.isNotEmpty || item.spRestore > 0,
              isTrue,
              reason: item.key,
            );
            expect(item.targetsAlly, isTrue);
          case BattleItemKind.crystal:
            expect(item.damage, greaterThan(0), reason: item.key);
            expect(item.targetsAlly, isFalse);
          case BattleItemKind.coating:
            // B6-03: laid on the user's own weapon, nothing to aim.
            expect(item.coating, isNotNull, reason: item.key);
            expect(item.targetsSelf, isTrue);
            expect(item.targetsAlly, isFalse);
        }
      }
    });

    test('medical items obey the same ordering rule as the spells', () {
      for (final item in battleItems.values) {
        final antidote = item.cureSteps.indexOf(CureStep.antidote);
        final heal = item.cureSteps.indexOf(CureStep.heal);
        if (antidote >= 0 && heal >= 0) {
          expect(antidote, lessThan(heal), reason: item.key);
        }
      }
    });

    test('items cost no spell points - that is why they are carried', () {
      expect(itemSpellPointCost, 0);
      // A cure spell refuses a caster with no magic level (appendix R-5);
      // a potion does not care.
      final r = applyCureStep(
        CureStep.heal,
        hp: 10,
        maxHp: 100,
        poison: 0,
        unconscious: 0,
        dead: 0,
        deathThreshold: 10,
        casterSp: 1 << 30,
        casterMagicLevel: battleItems['potion']!.healPower,
      );
      expect(r.applied, isTrue);
      expect(r.amount, greaterThan(0));
    });

    test('only what is held and known is offered', () {
      expect(usableItems({'potion': 2, 'antidote': 0}), ['potion']);
      expect(usableItems({'nonsense': 5}), isEmpty);
      expect(usableItems(const {}), isEmpty);
    });

    test('the offered order is stable', () {
      expect(usableItems({'potion': 1, 'elixir': 1, 'antidote': 1}), [
        'antidote',
        'elixir',
        'potion',
      ]);
    });
  });

  group('B2-08 armour by slot', () {
    test('worn armour is the sum of the four body slots', () {
      const a = ArmourPieces(
        body: 3,
        head: 1,
        leg: 1,
        ornament: 2,
        shieldBlock: 30,
      );
      expect(a.worn, 7);
      expect(a.shieldBlock, 30);
    });

    test('an unsplit snapshot behaves exactly as before', () {
      const c = CombatantSnapshot(slot: 0, name: 'A', hp: 10, maxHp: 10, ac: 6);
      expect(c.armour.isEmpty, isTrue);
      expect(c.effectiveArmour, 6, reason: 'falls back to the single ac');
      expect(c.shieldBlock, 0);
    });

    test('a split snapshot uses the pieces, not the total', () {
      const c = CombatantSnapshot(
        slot: 0,
        name: 'A',
        hp: 10,
        maxHp: 10,
        ac: 99,
        armour: ArmourPieces(body: 2, head: 1, shieldBlock: 40),
      );
      expect(c.effectiveArmour, 3);
      expect(c.shieldBlock, 40);
    });

    test('the shield rolls a percentage', () {
      expect(shieldBlocks(shieldBlock: 0, rng: ScriptedRng(const [])), isFalse);
      expect(shieldBlocks(shieldBlock: 40, rng: ScriptedRng([39])), isTrue);
      expect(shieldBlocks(shieldBlock: 40, rng: ScriptedRng([40])), isFalse);
    });

    test('no shield is a wall', () {
      var blocked = 0;
      for (var draw = 0; draw < 100; draw++) {
        if (shieldBlocks(shieldBlock: 100, rng: ScriptedRng([draw]))) {
          blocked++;
        }
      }
      expect(blocked, maxShieldBlock);
      expect(maxShieldBlock, lessThan(100));
    });

    test('the same points buy more as a shield than as armour', () {
      // 30 armour points would flatten the damage formula; 30 block
      // points stop three blows in ten. Both are meant to be worth
      // taking, which is the whole reason for splitting them.
      expect(maxShieldBlock, greaterThan(0));
      const spread = ArmourPieces(body: 8, head: 8, leg: 8, ornament: 6);
      expect(spread.worn, 30);
      expect(spread.shieldBlock, 0);
    });
  });

  group('B2-09 affinity', () {
    test('most spells carry no element', () {
      var elemental = 0;
      for (var id = 1; id <= 18; id++) {
        if (spellElement(id) != Element.none) elemental++;
      }
      expect(
        elemental,
        lessThan(18),
        reason: 'the table is deliberately thin - this is invented data',
      );
      expect(elemental, greaterThan(0));
    });

    test('the named ones read off their names', () {
      expect(spellElement(10), Element.ice); // 초냉기
      expect(spellElement(6), Element.lightning); // 직격 뇌전
      expect(spellElement(11), Element.force); // 인공 지진
      expect(spellElement(1), Element.none); // 마법 화살
    });

    test('weakness doubles and resistance halves', () {
      const weak = Affinity(weakTo: {Element.fire});
      const tough = Affinity(resists: {Element.fire});
      expect(
        applyAffinity(damage: 50, element: Element.fire, affinity: weak),
        100,
      );
      expect(
        applyAffinity(damage: 50, element: Element.fire, affinity: tough),
        25,
      );
      expect(
        applyAffinity(damage: 50, element: Element.ice, affinity: tough),
        50,
      );
    });

    test('an unelemental attack is never modified', () {
      const weak = Affinity(weakTo: {Element.fire});
      expect(
        applyAffinity(damage: 50, element: Element.none, affinity: weak),
        50,
      );
    });

    test('every affinity key is a real enemy', () {
      for (final key in enemyAffinities.keys) {
        expect(enemyByKey[key], isNotNull, reason: key);
      }
    });

    test('most enemies have no affinity at all', () {
      expect(enemyAffinities.length, lessThan(enemyTable.length ~/ 2));
      expect(affinityOf('orc').resists, isEmpty);
      expect(affinityOf('orc').weakTo, isEmpty);
    });

    test('the assignments read from what the creature is', () {
      // The undead shrug off poison; things made of fire hate cold.
      expect(affinityOf('mummy').resists, contains(Element.poison));
      expect(affinityOf('mummy').weakTo, contains(Element.fire));
      expect(affinityOf('salamander').resists, contains(Element.fire));
      expect(affinityOf('salamander').weakTo, contains(Element.ice));
      expect(affinityOf('frost_dragon').weakTo, contains(Element.fire));
    });

    test('nothing both resists and is weak to the same element', () {
      for (final entry in enemyAffinities.entries) {
        final both = entry.value.resists.intersection(entry.value.weakTo);
        expect(both, isEmpty, reason: entry.key);
      }
    });
  });
}
