import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B2-10 and B2-11. ESP in battle, and the superhuman tiers.
void main() {
  group('ESP is not a fourth attack category', () {
    test('three of the five do nothing in combat', () {
      for (final id in [41, 42, 44]) {
        expect(espAbilityFor(id), EspAbility.inert, reason: 'id $id');
        expect(espCost(EspAbility.inert), 0);
      }
    });

    test('43 recruits and 45 rolls a table', () {
      expect(espAbilityFor(43), EspAbility.mindControl);
      expect(espAbilityFor(45), EspAbility.psychokinesis);
      expect(espCost(EspAbility.mindControl), 15);
      expect(espCost(EspAbility.psychokinesis), 20);
    });

    test('nothing outside 41-45 is an ESP ability', () {
      expect(espAbilityFor(40), isNull);
      expect(espAbilityFor(46), isNull);
    });
  });

  group('mind control (43)', () {
    MindControlOutcome attempt({
      required int legacyId,
      int enemyLevel = 5,
      int espLevel = 20,
      int accuracyEsp = 15,
      int casterEsp = 99,
      List<int> draws = const [1, 0],
    }) => resolveMindControl(
      enemyLegacyId: legacyId,
      enemyLevel: enemyLevel,
      espLevel: espLevel,
      accuracyEsp: accuracyEsp,
      casterEsp: casterEsp,
      rng: ScriptedRng(draws),
    );

    test('the whitelist is table indices, and reads coherently', () {
      // Phantom, Python, Gazer, Kobold, Crazy One, Headless, Basilisk,
      // Vampire, Rotten Corpse, Dancing-Swd, Dragon, Death Knight.
      expect(mindControllableLegacyIds.length, 12);
      for (final id in mindControllableLegacyIds) {
        expect(enemyByLegacyId[id], isNotNull, reason: 'id $id');
      }
    });

    test('an enemy off the list is immune', () {
      expect(attempt(legacyId: 0), MindControlOutcome.immune);
      expect(attempt(legacyId: 6), isNot(MindControlOutcome.immune));
    });

    test('too little ESP stops it before anything else', () {
      expect(
        attempt(legacyId: 6, casterEsp: 10),
        MindControlOutcome.notAffordable,
      );
    });

    test('a stronger enemy shrugs it off half the time', () {
      expect(
        attempt(legacyId: 6, enemyLevel: 30, espLevel: 5, draws: [0]),
        MindControlOutcome.outmatched,
      );
      // The coin going the other way lets it continue to the persuasion.
      expect(
        attempt(legacyId: 6, enemyLevel: 30, espLevel: 5, draws: [1, 59]),
        MindControlOutcome.unmoved,
      );
    });

    test('the level gap counts double toward persuasion', () {
      // espLevel 20 vs level 5 -> (20-5)*2 + 15 = 45, so a draw of 44
      // persuades and 46 does not.
      expect(attempt(legacyId: 6, draws: [44]), MindControlOutcome.recruited);
      expect(attempt(legacyId: 6, draws: [46]), MindControlOutcome.unmoved);
    });

    test('Death Knight is judged at level 17, not its own', () {
      // Its real level is far higher; without the exception the
      // strongest recruitable enemy would be unrecruitable.
      expect(deathKnightLegacyId, 62);
      expect(deathKnightEffectiveLevel, 17);
      expect(enemyByLegacyId[62]!.level, greaterThan(17));
      // espLevel 20 vs 17 -> not outmatched, so no coin is drawn.
      expect(
        attempt(legacyId: 62, enemyLevel: 99, espLevel: 20, draws: [20]),
        MindControlOutcome.recruited,
      );
    });
  });

  group('psychokinesis (45)', () {
    test('the effect table maps by roll', () {
      expect(psychokineticEffect(1), PsychokineticEffect.strikeOne);
      expect(psychokineticEffect(6), PsychokineticEffect.strikeOne);
      expect(psychokineticEffect(7), PsychokineticEffect.strikeAll);
      expect(psychokineticEffect(10), PsychokineticEffect.strikeAll);
      expect(psychokineticEffect(11), PsychokineticEffect.terrify);
      expect(psychokineticEffect(13), PsychokineticEffect.poison);
      expect(psychokineticEffect(15), PsychokineticEffect.stopHeart);
      expect(psychokineticEffect(18), PsychokineticEffect.illusion);
      expect(psychokineticEffect(30), PsychokineticEffect.illusion);
    });

    test('the ceiling rises with the ESP level', () {
      // Below 11 only the striking effects can come up.
      for (var level = 1; level <= 10; level++) {
        for (var draw = 0; draw < level; draw++) {
          final roll = rollPsychokinesis(
            espLevel: level,
            rng: ScriptedRng([draw]),
          );
          expect(roll, lessThanOrEqualTo(10));
        }
      }
    });

    test('ESP level 0 does not throw', () {
      // `random(0)` returns 0 in C and throws in Dart.
      expect(rollPsychokinesis(espLevel: 0, rng: ScriptedRng(const [])), 1);
    });

    test('damage differs between single and area', () {
      expect(psychokineticDamage(6), 60);
      expect(psychokineticDamage(10), 50, reason: 'x5 when it hits all');
    });

    test('failed rolls still leave a mark', () {
      expect(
        psychokineticConsolation(PsychokineticEffect.terrify, resisted: true),
        PsychokineticConsolation.resistanceDown,
      );
      expect(
        psychokineticConsolation(PsychokineticEffect.terrify, resisted: false),
        PsychokineticConsolation.enduranceDown,
      );
      expect(
        psychokineticConsolation(
          PsychokineticEffect.stopHeart,
          resisted: false,
        ),
        PsychokineticConsolation.chipDamage,
      );
      expect(
        psychokineticConsolation(
          PsychokineticEffect.strikeOne,
          resisted: false,
        ),
        PsychokineticConsolation.none,
      );
    });
  });

  group('superhuman tiers (B2-11)', () {
    test('tiers stack with the cast level', () {
      expect(tiersFor(specialCastLevel: 0), isEmpty);
      expect(tiersFor(specialCastLevel: 1), [SuperhumanTier.summon]);
      expect(tiersFor(specialCastLevel: 3).length, 3);
    });

    test('summoning needs a thinned-out group', () {
      // threshold = random(3) + 2; 5 not-dead never triggers.
      expect(summonFires(notDeadEnemies: 5, rng: ScriptedRng([2])), isFalse);
      expect(summonFires(notDeadEnemies: 1, rng: ScriptedRng([2, 0])), isTrue);
    });

    test('the summon is twenty rows below the caller', () {
      final id = summonedLegacyId(
        casterLegacyId: 50,
        tableSize: 75,
        rng: ScriptedRng([2]),
      );
      expect(id, 32);
    });

    test('a caller under id 20 summons nothing - the C++ indexes negative', () {
      expect(
        summonedLegacyId(
          casterLegacyId: 5,
          tableSize: 75,
          rng: ScriptedRng([0]),
        ),
        isNull,
      );
    });

    test('there is a summon limit, and reinforcements are worth nothing', () {
      expect(summonLimit(startingEnemies: 1), 8);
      expect(summonLimit(startingEnemies: 4), 12);
      expect(
        summonsCountTowardSpoils,
        isFalse,
        reason:
            'otherwise a caster that summons every round pays out '
            'forever',
      );
    });

    test('abduction needs a member and room on the enemy side', () {
      expect(
        abductFires(
          hasValidMember: false,
          notDeadEnemies: 1,
          rng: ScriptedRng(const []),
        ),
        isFalse,
      );
      expect(
        abductFires(
          hasValidMember: true,
          notDeadEnemies: 7,
          rng: ScriptedRng(const []),
        ),
        isFalse,
      );
      expect(
        abductFires(
          hasValidMember: true,
          notDeadEnemies: 2,
          rng: ScriptedRng([0]),
        ),
        isTrue,
      );
    });

    test('the mass slay needs an innate special as well', () {
      expect(massSlayFires(special: 0, rng: ScriptedRng(const [])), isFalse);
      expect(massSlayFires(special: 2, rng: ScriptedRng([0])), isTrue);
      expect(massSlayFires(special: 2, rng: ScriptedRng([1])), isFalse);
    });
  });
}
