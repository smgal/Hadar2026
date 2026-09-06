import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B2-02. The four cure primitives and the composition table.
void main() {
  CureApplied run(
    CureStep step, {
    int hp = 20,
    int maxHp = 100,
    int poison = 0,
    int unconscious = 0,
    int dead = 0,
    int deathThreshold = 15,
    int casterSp = 999,
    int casterMagicLevel = 10,
  }) => applyCureStep(
    step,
    hp: hp,
    maxHp: maxHp,
    poison: poison,
    unconscious: unconscious,
    dead: dead,
    deathThreshold: deathThreshold,
    casterSp: casterSp,
    casterMagicLevel: casterMagicLevel,
  );

  group('heal', () {
    test('restores 3x the caster magic level, costing 2x', () {
      final r = run(CureStep.heal, hp: 20, casterMagicLevel: 10);
      expect(r.spSpent, 20);
      expect(r.amount, 30);
      expect(r.hp, 50);
    });

    test('never overshoots the maximum', () {
      final r = run(CureStep.heal, hp: 95, maxHp: 100, casterMagicLevel: 10);
      expect(r.hp, 100);
      expect(r.amount, 5);
      expect(r.spSpent, 20, reason: 'the cost is paid in full anyway');
    });

    test('refuses someone already at full health', () {
      final r = run(CureStep.heal, hp: 100, maxHp: 100);
      expect(r.applied, isFalse);
      expect(r.spSpent, 0);
    });

    test('**refuses a poisoned target** — this is why the order matters', () {
      final r = run(CureStep.heal, hp: 20, poison: 3);
      expect(r.applied, isFalse);
      expect(r.hp, 20);
    });

    test('refuses the collapsed and the dead', () {
      expect(run(CureStep.heal, hp: 0, unconscious: 1).applied, isFalse);
      expect(run(CureStep.heal, hp: 0, dead: 1).applied, isFalse);
    });

    test('a caster with no magic level cannot heal at all', () {
      // Cost 2x0 = 0 and restore 0x3/2 = 0: the C++ menu still offers
      // this and it reports success while doing nothing.
      final r = run(CureStep.heal, hp: 20, casterMagicLevel: 0);
      expect(r.applied, isFalse);
      expect(r.shortOfSp, isFalse, reason: 'not a money problem');
      expect(r.hp, 20);
    });

    test('reports being short of spell points separately', () {
      final r = run(CureStep.heal, casterSp: 5, casterMagicLevel: 10);
      expect(r.applied, isFalse);
      expect(r.shortOfSp, isTrue);
    });
  });

  group('antidote', () {
    test('clears poison for a flat 15', () {
      final r = run(CureStep.antidote, poison: 4);
      expect(r.poison, 0);
      expect(r.spSpent, 15);
    });

    test('does nothing to the unpoisoned', () {
      expect(run(CureStep.antidote, poison: 0).applied, isFalse);
    });

    test('cannot reach through a collapse', () {
      final r = run(CureStep.antidote, poison: 4, hp: 0, unconscious: 2);
      expect(
        r.applied,
        isFalse,
        reason: 'the collapsed have to be woken first',
      );
    });
  });

  group('recover consciousness', () {
    test('costs 10x the accumulator', () {
      // B2-03 made `unconscious` an accumulator; this is its second use.
      expect(
        run(CureStep.recoverConsciousness, hp: 0, unconscious: 1).spSpent,
        10,
      );
      expect(
        run(CureStep.recoverConsciousness, hp: 0, unconscious: 7).spSpent,
        70,
      );
    });

    test('a deep collapse can be unaffordable', () {
      final r = run(
        CureStep.recoverConsciousness,
        hp: 0,
        unconscious: 12,
        casterSp: 100,
      );
      expect(r.applied, isFalse);
      expect(r.shortOfSp, isTrue);
    });

    test('leaves them standing on at least 1 hit point', () {
      final r = run(CureStep.recoverConsciousness, hp: 0, unconscious: 2);
      expect(r.unconscious, 0);
      expect(r.hp, 1);
    });

    test('will not touch the dead', () {
      expect(
        run(
          CureStep.recoverConsciousness,
          hp: 0,
          unconscious: 5,
          dead: 1,
        ).applied,
        isFalse,
      );
    });
  });

  group('revitalize', () {
    test('costs a flat 30 and brings them back collapsed, not standing', () {
      final r = run(
        CureStep.revitalize,
        hp: 0,
        unconscious: 40,
        dead: 1,
        deathThreshold: 15,
      );
      expect(r.spSpent, 30);
      expect(r.dead, 0);
      expect(
        r.unconscious,
        15,
        reason: 'clamped to the threshold so they do not die again at once',
      );
      expect(r.hp, 0, reason: 'still needs waking');
    });

    test('never comes back with a zero accumulator', () {
      final r = run(CureStep.revitalize, hp: 0, unconscious: 0, dead: 1);
      expect(r.unconscious, 1);
    });

    test('does nothing to the living', () {
      expect(run(CureStep.revitalize, dead: 0).applied, isFalse);
    });
  });

  group('the composition table', () {
    test('every cure id maps to steps', () {
      for (var id = 19; id <= 32; id++) {
        expect(cureStepsFor(id), isNotEmpty, reason: 'id $id');
      }
      expect(cureStepsFor(18), isEmpty);
      expect(cureStepsFor(33), isEmpty);
    });

    test('the antidote always runs before the heal', () {
      for (var id = 19; id <= 32; id++) {
        final steps = cureStepsFor(id);
        final antidote = steps.indexOf(CureStep.antidote);
        final heal = steps.indexOf(CureStep.heal);
        if (antidote >= 0 && heal >= 0) {
          expect(antidote, lessThan(heal), reason: 'id $id');
        }
      }
    });

    test('the full recovery runs all four, deepest first', () {
      expect(cureStepsFor(25), [
        CureStep.revitalize,
        CureStep.recoverConsciousness,
        CureStep.antidote,
        CureStep.heal,
      ]);
      expect(cureStepsFor(32), cureStepsFor(25));
    });

    test('the two halves put revive in different places', () {
      // Not a slip: the name table is asymmetric and the C++ switches
      // each match their own half.
      expect(cureStepsFor(23), [CureStep.revitalize]);
      expect(cureStepsFor(31), [CureStep.revitalize]);
      expect(cureStepsFor(24).length, 3);
      expect(cureStepsFor(30).length, 3);
    });

    test('26..32 hit the whole party, 19..25 one member', () {
      for (var id = 19; id <= 25; id++) {
        expect(cureTargetsAll(id), isFalse, reason: 'id $id');
      }
      for (var id = 26; id <= 32; id++) {
        expect(cureTargetsAll(id), isTrue, reason: 'id $id');
      }
    });
  });

  group('the full recovery actually recovers', () {
    test('dead and poisoned to standing and clean', () {
      final r = applyCure(
        25,
        hp: 0,
        maxHp: 100,
        poison: 3,
        unconscious: 40,
        dead: 1,
        deathThreshold: 15,
        casterSp: 999,
        casterMagicLevel: 10,
      );
      expect(r.dead, 0);
      expect(r.unconscious, 0);
      expect(r.poison, 0);
      expect(r.hp, greaterThan(1), reason: 'and healed on the way');
      // 30 revive + 150 wake (10 x 15) + 15 antidote + 20 heal
      expect(r.spSpent, 30 + 150 + 15 + 20);
      expect(r.steps.every((s) => s.applied), isTrue);
    });

    test('running out of points partway leaves the earlier steps done', () {
      final r = applyCure(
        25,
        hp: 0,
        maxHp: 100,
        poison: 3,
        unconscious: 40,
        dead: 1,
        deathThreshold: 15,
        casterSp: 100,
        casterMagicLevel: 10,
      );
      expect(r.dead, 0, reason: 'the revive was affordable');
      expect(r.unconscious, 15, reason: 'the wake was not (150 > 70 left)');
      expect(r.poison, 3, reason: 'and nothing after it could reach');
    });
  });

  group('which cures a caster may pick', () {
    test('single-target opens at magic level 0 and caps at 7', () {
      expect(cureSpellsEnabled(magicLevel: 0).single, 1);
      expect(cureSpellsEnabled(magicLevel: 2).single, 2);
      expect(cureSpellsEnabled(magicLevel: 12).single, 7);
      expect(cureSpellsEnabled(magicLevel: 30).single, 7);
    });

    test('party-wide needs magic level 8', () {
      expect(cureSpellsEnabled(magicLevel: 7).all, 0);
      expect(cureSpellsEnabled(magicLevel: 8).all, 1);
      expect(cureSpellsEnabled(magicLevel: 20).all, 7);
      expect(cureSpellsEnabled(magicLevel: 30).all, 7);
    });

    test('the offered list is single-target first', () {
      expect(castableCures(magicLevel: 2), [19, 20]);
      expect(castableCures(magicLevel: 20), [
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
      ]);
    });

    test('the skill list routes cures through this gate', () {
      final cures = castableSkills(
        levelMagic: 2,
        levelEsp: 0,
      ).where((id) => id >= 19 && id <= 32);
      expect(cures, [19, 20]);
    });

    test('cures are never blocked at selection time', () {
      // Their cost depends on the target, so it is checked per step.
      expect(skillAffordable(19, levelMagic: 2, sp: 0, esp: 0), isTrue);
      expect(skillAffordable(26, levelMagic: 20, sp: 0, esp: 0), isTrue);
    });
  });

  group('cureWouldHelp', () {
    test('sees what each step needs', () {
      expect(
        cureWouldHelp(
          const [CureStep.heal],
          hp: 100,
          maxHp: 100,
          poison: 0,
          unconscious: 0,
          dead: 0,
        ),
        isFalse,
      );
      expect(
        cureWouldHelp(
          const [CureStep.heal],
          hp: 50,
          maxHp: 100,
          poison: 0,
          unconscious: 0,
          dead: 0,
        ),
        isTrue,
      );
      expect(
        cureWouldHelp(
          const [CureStep.antidote],
          hp: 100,
          maxHp: 100,
          poison: 1,
          unconscious: 0,
          dead: 0,
        ),
        isTrue,
      );
      expect(
        cureWouldHelp(
          const [CureStep.revitalize],
          hp: 0,
          maxHp: 100,
          poison: 0,
          unconscious: 5,
          dead: 1,
        ),
        isTrue,
      );
    });
  });
}
