import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// The one skill list (B6-01) and what moved into it (B6-02).
///
/// B2-01 corrected the id boundaries and replaced "one spell per level"
/// with the C++ menu's tiered gates. B6 kept both and dropped the five
/// menu categories: every castable id is in one list, tagged by scope.
void main() {
  group('the attack ranges still hold the ids the C++ menu had', () {
    test('1-6 / 7-12 / 13-18, six each', () {
      // The port had 1-3 / 4-10 / 11-18, which put 독 바늘 among the area
      // spells and 인공 지진 among the debuffs. The C++ menu offsets are
      // 0 / 6 / 12 with six entries each.
      final single = attackMagicCategories[MagicGroup.single]!;
      final area = attackMagicCategories[MagicGroup.area]!;
      final special = attackMagicCategories[MagicGroup.special]!;
      expect((single.minId, single.maxId), (1, 6));
      expect((area.minId, area.maxId), (7, 12));
      expect((special.minId, special.maxId), (13, 18));
      for (final c in attackMagicCategories.values) {
        expect(c.size, 6, reason: '${c.group}');
      }
    });

    test('magicGroupOf reads the range off the id', () {
      expect(magicGroupOf(1), MagicGroup.single);
      expect(magicGroupOf(6), MagicGroup.single);
      expect(magicGroupOf(7), MagicGroup.area);
      expect(magicGroupOf(12), MagicGroup.area);
      expect(magicGroupOf(13), MagicGroup.special);
      expect(magicGroupOf(18), MagicGroup.special);
      expect(magicGroupOf(19), isNull, reason: 'a cure');
      expect(magicGroupOf(45), isNull, reason: 'ESP');
    });

    test('index within a range is the C++ ix_object', () {
      final single = attackMagicCategories[MagicGroup.single]!;
      expect(single.indexOf(1), 1);
      expect(single.indexOf(6), 6);
      expect(single.indexOf(7), 0, reason: 'not in this range');
      final area = attackMagicCategories[MagicGroup.area]!;
      expect(area.indexOf(7), 1);
      expect(area.indexOf(12), 6);
    });
  });

  group('attack magic gates are tiered, not one per level', () {
    test('single target: 2 / 3 / 4 / 5 / 6', () {
      final c = attackMagicCategories[MagicGroup.single]!;
      expect(attackSpellsEnabled(c, 0), 2);
      expect(attackSpellsEnabled(c, 1), 2);
      expect(attackSpellsEnabled(c, 2), 3);
      expect(attackSpellsEnabled(c, 7), 4);
      expect(attackSpellsEnabled(c, 12), 6);
      expect(attackSpellsEnabled(c, 30), 6);
    });

    test('area magic opens with one and needs level 18 for all six', () {
      final c = attackMagicCategories[MagicGroup.area]!;
      expect(attackSpellsEnabled(c, 0), 1);
      expect(attackSpellsEnabled(c, 3), 3);
      expect(attackSpellsEnabled(c, 17), 6);
      expect(attackSpellsEnabled(c, 18), 6);
    });

    test('special magic needs level 5 for the second one', () {
      final c = attackMagicCategories[MagicGroup.special]!;
      expect(attackSpellsEnabled(c, 4), 1);
      expect(attackSpellsEnabled(c, 5), 2);
      expect(attackSpellsEnabled(c, 18), 6);
    });

    test('the gate is monotonic and never exceeds the range', () {
      for (final c in attackMagicCategories.values) {
        var previous = 0;
        for (var level = 0; level <= 30; level++) {
          final count = attackSpellsEnabled(c, level);
          expect(count, greaterThanOrEqualTo(previous));
          expect(count, lessThanOrEqualTo(c.size));
          previous = count;
        }
      }
    });
  });

  group('one list, in a stable order (B6-01)', () {
    test(
      'a fresh caster sees two attacks, one area, the coating, one cure',
      () {
        // 13 opens at level 1 — the special range's first tier is (4, 1),
        // the same gate it had as a special spell.
        expect(castableSkills(levelMagic: 1, levelEsp: 0), [1, 2, 7, 13, 19]);
      },
    );

    test(
      'the order clusters by kind: single, area, coating, curses, cures, ESP',
      () {
        final ids = castableSkills(levelMagic: 20, levelEsp: 5);
        // Kind = scope + resource: a single-target spell and a single-target
        // ESP ability are different clusters though both aim at one enemy.
        // Every kind appears in one contiguous run.
        final scopes = [for (final id in ids) (scopeOf(id), resourceOf(id))];
        final firstSeen = <(SkillScope, SkillResource), int>{};
        final lastSeen = <(SkillScope, SkillResource), int>{};
        for (var i = 0; i < scopes.length; i++) {
          firstSeen.putIfAbsent(scopes[i], () => i);
          lastSeen[scopes[i]] = i;
        }
        for (final a in firstSeen.keys) {
          for (final b in firstSeen.keys) {
            if (a == b) continue;
            final disjoint =
                lastSeen[a]! < firstSeen[b]! || lastSeen[b]! < firstSeen[a]!;
            expect(disjoint, isTrue, reason: '$a and $b interleave');
          }
        }
      },
    );

    test('ids 33-40 are never listed — their effects are outside battle', () {
      final ids = castableSkills(levelMagic: 30, levelEsp: 30);
      for (var id = 33; id <= 40; id++) {
        expect(ids, isNot(contains(id)), reason: 'id $id');
      }
      expect(ids.every((id) => id >= 1 && id <= 45), isTrue);
    });

    test('nothing is listed twice', () {
      final ids = castableSkills(levelMagic: 30, levelEsp: 30);
      expect(ids.toSet().length, ids.length);
    });

    test('skillOptions carries scope, resource, cost and affordability', () {
      final options = skillOptions(levelMagic: 20, levelEsp: 5, sp: 0, esp: 0);
      final byId = {for (final o in options) o.magicId: o};
      expect(byId[1]!.scope, SkillScope.oneEnemy);
      expect(byId[7]!.scope, SkillScope.allEnemies);
      expect(byId[14]!.scope, SkillScope.curse);
      expect(byId[19]!.scope, SkillScope.oneAlly);
      expect(byId[26]!.scope, SkillScope.allAllies);
      expect(byId[45]!.resource, SkillResource.esp);
      expect(byId[1]!.resource, SkillResource.sp);
      // A broke caster still sees the list; the unaffordable are marked.
      expect(byId[14]!.affordable, isFalse, reason: 'fixed cost, no SP');
      expect(byId[19]!.affordable, isTrue, reason: 'variable cost');
    });
  });

  group('two ids changed category (B6-02)', () {
    test('13 독 is a coating laid on the caster\'s own weapon', () {
      expect(coatingSpellId, 13);
      expect(scopeOf(13), SkillScope.selfWeapon);
      expect(targetingFor(13), SpellTargeting.selfWeapon);
      expect(resourceOf(13), SkillResource.sp);
      expect(fixedCostOf(13, levelMagic: 1), coatingSpellCost);
    });

    test('16 능력 저하 is ESP now', () {
      expect(abilityDrainSpellId, 16);
      expect(resourceOf(16), SkillResource.esp);
      expect(scopeOf(16), SkillScope.oneEnemy);
      // It opens with the ESP level, not the magic level.
      expect(castableSkills(levelMagic: 30, levelEsp: 0), isNot(contains(16)));
      expect(
        castableSkills(levelMagic: 0, levelEsp: abilityDrainEspLevel),
        contains(16),
      );
    });

    test('14 · 15 · 17 · 18 stay curses and keep their gate', () {
      for (final id in [14, 15, 17, 18]) {
        expect(isCurse(id), isTrue, reason: 'id $id');
        expect(scopeOf(id), SkillScope.curse);
      }
      expect(isCurse(13), isFalse);
      expect(isCurse(16), isFalse);
      // Level 4 opens one special (13, the coating); 14 needs level 5.
      expect(castableSkills(levelMagic: 4, levelEsp: 0), contains(13));
      expect(castableSkills(levelMagic: 4, levelEsp: 0), isNot(contains(14)));
      expect(castableSkills(levelMagic: 5, levelEsp: 0), contains(14));
    });
  });

  group('cures and ESP keep their own gates', () {
    test('cures come from castableCures', () {
      final cures = castableSkills(
        levelMagic: 2,
        levelEsp: 0,
      ).where((id) => id >= 19 && id <= 32);
      expect(cures, [19, 20]);
    });

    test('ESP opens one ability per level', () {
      final esp = castableSkills(
        levelMagic: 0,
        levelEsp: 2,
      ).where((id) => id >= 41 && id <= 45);
      expect(esp, [41, 42]);
    });
  });

  group('cost', () {
    test('spendsCost records what the port used to do', () {
      expect(
        spendsCost,
        isFalse,
        reason:
            'the flat category cost was checked and never taken '
            '(appendix O-1). B2-01 and B2-02 replaced it with per-spell '
            'costs that are actually spent.',
      );
    });

    test('variable-cost skills are never blocked at selection time', () {
      // Area magic charges per enemy, cures per step — nothing to check
      // until the cast.
      expect(skillAffordable(7, levelMagic: 1, sp: 0, esp: 0), isTrue);
      expect(skillAffordable(19, levelMagic: 1, sp: 0, esp: 0), isTrue);
      expect(fixedCostOf(7, levelMagic: 1), -1);
      expect(fixedCostOf(19, levelMagic: 1), -1);
    });

    test('fixed-cost skills are checked against the right pool', () {
      // Mind control is ESP 15.
      expect(skillAffordable(43, levelMagic: 0, sp: 99, esp: 15), isTrue);
      expect(skillAffordable(43, levelMagic: 0, sp: 99, esp: 14), isFalse);
      // A curse is SP.
      final curse = debuffSpells[14]!.cost;
      expect(skillAffordable(14, levelMagic: 20, sp: curse, esp: 0), isTrue);
      expect(
        skillAffordable(14, levelMagic: 20, sp: curse - 1, esp: 0),
        isFalse,
      );
    });
  });

  group('targeting', () {
    test('single attack, curses and ESP need one enemy', () {
      for (final id in [1, 6, 14, 16, 41, 45]) {
        expect(targetingFor(id), SpellTargeting.singleEnemy, reason: 'id $id');
      }
    });

    test('the area range needs no target', () {
      expect(targetingFor(7), SpellTargeting.allEnemies);
      expect(targetingFor(12), SpellTargeting.allEnemies);
    });

    test('cures split at id 25', () {
      expect(targetingFor(25), SpellTargeting.singleAlly);
      expect(targetingFor(26), SpellTargeting.allAllies);
    });
  });
}
