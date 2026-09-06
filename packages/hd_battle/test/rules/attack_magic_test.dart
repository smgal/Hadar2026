import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B2-01. Per-spell damage and cost, and the six stat-drains.
void main() {
  group('per-spell damage and cost', () {
    test('damage is index squared x magic level x 2', () {
      expect(attackSpellPower(spellIndex: 1, magicLevel: 5), 10);
      expect(attackSpellPower(spellIndex: 3, magicLevel: 5), 90);
      expect(attackSpellPower(spellIndex: 6, magicLevel: 5), 360);
    });

    test('the last spell in a category hits 36x the first', () {
      final first = attackSpellPower(spellIndex: 1, magicLevel: 10);
      final last = attackSpellPower(spellIndex: 6, magicLevel: 10);
      expect(last, first * 36);
    });

    test('cost is (index squared x magic level + 1) / 2', () {
      expect(attackSpellCost(spellIndex: 1, magicLevel: 5), 3);
      expect(attackSpellCost(spellIndex: 3, magicLevel: 5), 23);
      expect(attackSpellCost(spellIndex: 6, magicLevel: 5), 90);
    });

    test('a stronger caster pays more for the same spell', () {
      expect(
        attackSpellCost(spellIndex: 2, magicLevel: 20),
        greaterThan(attackSpellCost(spellIndex: 2, magicLevel: 5)),
      );
    });

    test('every spell in a category is distinct - the port had two', () {
      final damages = {
        for (var i = 1; i <= 6; i++)
          attackSpellPower(spellIndex: i, magicLevel: 7),
      };
      expect(damages.length, 6);
    });
  });

  group('magic rolls', () {
    test('the accuracy roll uses >= where the physical one uses >', () {
      // At accuracy 15, magic misses on 15..19 and a weapon on 16..19.
      var magicMisses = 0;
      var physicalMisses = 0;
      for (var draw = 0; draw < 20; draw++) {
        if (magicAttackMisses(accuracyMagic: 15, rng: ScriptedRng([draw]))) {
          magicMisses++;
        }
        if (physicalAttackMisses(
          accuracyPhysical: 15,
          rng: ScriptedRng([draw]),
        )) {
          physicalMisses++;
        }
      }
      expect(magicMisses, 5);
      expect(physicalMisses, 4);
    });

    test('accuracy 20 never misses', () {
      for (var draw = 0; draw < 20; draw++) {
        expect(
          magicAttackMisses(accuracyMagic: 20, rng: ScriptedRng([draw])),
          isFalse,
        );
      }
    });

    test('the magic defence term rounds where the physical one truncates', () {
      // ac 1, level 1, draw 4 -> (1*1*5 + 5) / 10 = 1, where the physical
      // term gives (1*1*5) ~/ 10 = 0.
      expect(magicDefence(enemyAc: 1, enemyLevel: 1, rng: ScriptedRng([4])), 1);
    });

    test('resistance is a straight percentage', () {
      expect(
        enemyResistsMagic(enemyResistance: 70, rng: ScriptedRng([69])),
        isTrue,
      );
      expect(
        enemyResistsMagic(enemyResistance: 70, rng: ScriptedRng([70])),
        isFalse,
      );
    });
  });

  group('the six stat-drains (13-18)', () {
    const stats = EnemyStats(
      ac: 4,
      resistance: 20,
      level: 5,
      castLevel: 3,
      specialCastLevel: 2,
      special: 1,
      poison: 0,
    );

    /// Default draws pass the resist roll (99, above any resistance
    /// used here), land the accuracy roll (0), and take the armour side
    /// of 방어 무력화's coin flip (0).
    DebuffResult cast(
      int id, {
      EnemyStats? on,
      List<int>? draws,
      int sp = 99,
    }) => castDebuff(
      id,
      stats: on ?? stats,
      accuracyMagic: 19,
      casterSp: sp,
      rng: ScriptedRng(draws ?? const [99, 0, 0]),
    );

    test('13 독 stacks the poison value', () {
      final r = cast(13);
      expect(r.outcome, DebuffOutcome.applied);
      expect(r.stats.poison, 1);
      expect(cast(13, on: r.stats).stats.poison, 2);
      expect(r.spSpent, 10);
    });

    test('14 기술 무력화 removes the special ability outright', () {
      final r = cast(14);
      expect(r.stats.special, 0);
      expect(r.spSpent, 30);
    });

    test('15 방어 무력화 lowers armour on a lightly resistant target', () {
      final r = cast(15);
      expect(r.stats.ac, 3);
      expect(r.stats.resistance, 20, reason: 'resistance under 31 -> armour');
    });

    test('15 hits resistance instead on a very resistant target', () {
      const tough = EnemyStats(
        ac: 4,
        resistance: 70,
        level: 5,
        castLevel: 3,
        specialCastLevel: 2,
        special: 1,
        poison: 0,
      );
      // draws: resist roll 0 (passes), accuracy 0 (hits), coin 1 -> resistance
      final r = cast(15, on: tough, draws: [99, 0, 1]);
      expect(r.stats.resistance, 60);
      expect(r.stats.ac, 4);
    });

    test('16 능력 저하 takes a level and some resistance', () {
      final r = cast(16);
      expect(r.stats.level, 4);
      expect(r.stats.resistance, 10);
    });

    test('16 never takes a level below 1', () {
      const frail = EnemyStats(
        ac: 1,
        resistance: 0,
        level: 1,
        castLevel: 0,
        specialCastLevel: 0,
        special: 0,
        poison: 0,
      );
      expect(cast(16, on: frail).stats.level, 1);
    });

    test('17 마법 불능 and 18 탈 초인화 step their levels down', () {
      expect(cast(17).stats.castLevel, 2);
      expect(cast(18).stats.specialCastLevel, 1);
    });

    test('resistance never goes negative - the C++ tree lets it', () {
      const barely = EnemyStats(
        ac: 4,
        resistance: 5,
        level: 5,
        castLevel: 1,
        specialCastLevel: 1,
        special: 1,
        poison: 0,
      );
      expect(cast(16, on: barely).stats.resistance, 0);
    });

    test('a resisted cast still costs', () {
      const resistant = EnemyStats(
        ac: 4,
        resistance: 99,
        level: 5,
        castLevel: 1,
        specialCastLevel: 1,
        special: 1,
        poison: 0,
      );
      final r = cast(13, on: resistant, draws: [0]);
      expect(r.outcome, DebuffOutcome.resisted);
      expect(r.spSpent, 10);
      expect(r.stats.poison, 0);
    });

    test('a missed cast still costs', () {
      // 17 rolls accuracy against 100, so accuracy 19 usually misses.
      final r = castDebuff(
        17,
        stats: stats,
        accuracyMagic: 19,
        casterSp: 99,
        rng: ScriptedRng([50, 80]),
      );
      expect(r.outcome, DebuffOutcome.missed);
      expect(r.spSpent, 15);
      expect(r.stats.castLevel, 3);
    });

    test('being broke costs nothing and changes nothing', () {
      final r = cast(14, sp: 5);
      expect(r.outcome, DebuffOutcome.notAffordable);
      expect(r.spSpent, 0);
      expect(r.stats.special, 1);
    });

    test('every one of 13-18 has its own cost and rolls', () {
      final costs = {for (final s in debuffSpells.values) s.cost};
      expect(debuffSpells.keys.toList()..sort(), [13, 14, 15, 16, 17, 18]);
      expect(costs.length, greaterThan(1), reason: 'not one flat cost');
      // 능력 저하 rolls resistance against 200, halving its effect.
      expect(debuffSpells[16]!.resistRange, 200);
      expect(debuffSpells[13]!.resistRange, 100);
    });
  });
}
