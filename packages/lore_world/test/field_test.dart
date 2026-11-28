import 'dart:math';

import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

const walk = StepInput();
const swamp = StepInput(terrain: Terrain.swamp);
const lava = StepInput(terrain: Terrain.lava);

/// 조우가 절대 일어나지 않게 굴리는 난수(0 이 아닌 값만 낸다).
ScriptedRandom noEncounter() => ScriptedRandom([1]);

void main() {
  group('level table', () {
    test('forty levels, strictly rising', () {
      expect(levelTable.length, 40);
      expect(levelTable.first, 0);
      for (var i = 1; i < levelTable.length; i++) {
        expect(levelTable[i], greaterThan(levelTable[i - 1]));
      }
      expect(levelTable.last, 70000000);
    });

    test('thresholds from chapter 7.6', () {
      expect(trainedExpForLevel(2), 1500);
      expect(trainedExpForLevel(5), 50000);
      expect(trainedExpForLevel(10), 1050000);
      expect(trainedExpForLevel(20), 5100000);
      expect(trainedExpForLevel(30), 20000000);
      expect(trainedExpForLevel(40), 70000000);
    });

    test('a level is reached exactly at its threshold', () {
      expect(levelForTrainedExp(0), 1);
      expect(levelForTrainedExp(1499), 1);
      expect(levelForTrainedExp(1500), 2);
      expect(levelForTrainedExp(5999), 2);
      expect(levelForTrainedExp(6000), 3);
      expect(levelForTrainedExp(1049999), 9);
      expect(levelForTrainedExp(1050000), 10);
      expect(levelForTrainedExp(69999999), 39);
      expect(levelForTrainedExp(70000000), 40);
      expect(levelForTrainedExp(999999999), 40);
    });
  });

  group('rest: recovery', () {
    test('a healthy member gains level × hours and eats one', () {
      final m = fighter(level: 3)..hp = 10;
      final w = worldWith(m)..food = 5;
      final out = w.rest(6, rng: Random(1));
      final e = out.of<RestMember>().single;
      expect(e.result, RestResult.healed);
      expect(e.amount, 18);
      expect(e.foodUsed, 1);
      expect(m.hp, 28);
      expect(w.food, 4);
    });

    test('reaching the maximum is reported as fully recovered', () {
      final m = fighter()..hp = 95;
      final w = worldWith(m)..food = 5;
      final e = w.rest(6, rng: Random(1)).of<RestMember>().single;
      expect(e.result, RestResult.fullyRecovered);
      expect(e.amount, 5);
      expect(m.hp, 100);
    });

    test('someone already at full health eats nothing', () {
      final w = worldWith(fighter())..food = 5;
      final e = w.rest(6, rng: Random(1)).of<RestMember>().single;
      expect(e.result, RestResult.fullyRecovered);
      expect(e.foodUsed, 0);
      expect(w.food, 5);
    });

    test('no food, no recovery', () {
      final m = fighter()..hp = 10;
      final w = worldWith(m);
      final e = w.rest(24, rng: Random(1)).of<RestMember>().single;
      expect(e.result, RestResult.noFood);
      expect(m.hp, 10);
    });

    test('food runs out part way down the party', () {
      final w = worldWith(fighter()..hp = 1)..food = 1;
      w.join(fighter()..hp = 1);
      final results = [
        for (final e in w.rest(1, rng: Random(1)).of<RestMember>()) e.result,
      ];
      expect(results, [RestResult.healed, RestResult.noFood]);
      expect(w.food, 0);
    });

    test('the dead stay dead', () {
      final m = fighter()..dead = 5;
      final w = worldWith(m)..food = 5;
      w.join(fighter());
      final e = w.rest(24, rng: Random(1)).of<RestMember>().first;
      expect(e.result, RestResult.dead);
      expect(m.dead, 5);
      expect(w.food, 5);
    });

    test('the unconscious counter drops by level × (hours ÷ 2)', () {
      final m = fighter(level: 2)
        ..hp = 0
        ..unconscious = 15;
      final w = worldWith(m)..food = 5;
      w.join(fighter());
      // 2 × (6 ÷ 2) = 6.
      var e = w.rest(6, rng: Random(1)).of<RestMember>().first;
      expect(e.result, RestResult.stillUnconscious);
      expect(e.amount, 6);
      expect(m.unconscious, 9);
      expect(w.food, 5);
      // 2 × (10 ÷ 2) = 10 ≥ 9 → 깨어난다.
      e = w.rest(10, rng: Random(1)).of<RestMember>().first;
      expect(e.result, RestResult.regainedConsciousness);
      expect(m.unconscious, 0);
      expect(m.hp, 1);
      expect(w.food, 4);
    });

    test('an hour of rest wakes nobody — the hours are halved downward', () {
      final m = fighter(level: 30)
        ..hp = 0
        ..unconscious = 1;
      final w = worldWith(m)..food = 5;
      w.join(fighter());
      final e = w.rest(1, rng: Random(1)).of<RestMember>().first;
      expect(e.result, RestResult.stillUnconscious);
      expect(m.unconscious, 1);
    });

    test('poison blocks recovery of health and of consciousness', () {
      final sick = fighter()
        ..hp = 10
        ..poison = 3;
      final out = fighter()
        ..hp = 0
        ..poison = 1
        ..unconscious = 2;
      final w = worldWith(sick)..food = 9;
      w.join(out);
      final results = [
        for (final e in w.rest(24, rng: Random(1)).of<RestMember>()) e.result,
      ];
      expect(results, [RestResult.poisoned, RestResult.unconsciousAndPoisoned]);
      expect(sick.hp, 10);
      expect(out.unconscious, 2);
      expect(w.food, 9);
    });

    test('the assistant rests too', () {
      final w = worldWith(fighter())..food = 9;
      w.setAssistant(fighter(name: 'Aide', level: 2)..hp = 1);
      final seats = [
        for (final e in w.rest(5, rng: Random(1)).of<RestMember>()) e.seat,
      ];
      expect(seats, [0, 5]);
      expect(w.assistant!.hp, 11);
    });

    test('hours outside 1..24 are refused', () {
      final w = worldWith(fighter());
      expect(w.rest(0, rng: Random(1)).reason, RefusalReason.invalidAmount);
      expect(w.rest(25, rng: Random(1)).reason, RefusalReason.invalidAmount);
    });

    test('the last choice of hours is remembered', () {
      final w = worldWith(fighter());
      expect(w.options.restHours, 6);
      w.rest(9, rng: Random(1));
      expect(w.options.restHours, 9);
    });
  });

  group('rest: what follows', () {
    test('MP is refilled for those who can act', () {
      final wiz = mage(level: 3)..mp = 0;
      final out = mage(level: 3)
        ..mp = 0
        ..hp = 0
        ..unconscious = 99;
      final w = worldWith(wiz)..food = 9;
      w.join(out);
      w.rest(1, rng: Random(1));
      expect(wiz.mp, 300);
      expect(out.mp, 0);
    });

    test('MP comes back even without food', () {
      final wiz = mage()..mp = 0;
      final w = worldWith(wiz);
      w.rest(1, rng: Random(1));
      expect(wiz.mp, 100);
    });

    test('levitation, water walk and swamp walk end', () {
      final w = worldWith(fighter())..food = 9;
      w.buffs
        ..grant(FieldBuff.levitation)
        ..grant(FieldBuff.waterWalk)
        ..grant(FieldBuff.swampWalk);
      final out = w.rest(1, rng: Random(1));
      expect(out.first<BuffsExpired>()!.buffs, FieldBuff.values);
      expect(w.buffs.canLevitate, isFalse);
      expect(w.buffs.canWalkOnWater, isFalse);
      expect(w.buffs.canWalkOnSwamp, isFalse);
    });

    test('the torch burns down by hours ÷ 3 + 1', () {
      final w = worldWith(fighter())..setTorch(10);
      final out = w.rest(6, rng: Random(1));
      expect(out.first<TorchChanged>()!.delta, -3);
      expect(w.torch, 7);
      w.rest(24, rng: Random(1));
      expect(w.torch, 0);
      expect(w.rest(1, rng: Random(1)).has<TorchChanged>(), isFalse);
    });

    test('time passes', () {
      final w = worldWith(fighter());
      expect(w.calendar.toString(), '673-11-27 16:00:00');
      w.rest(10, rng: Random(1));
      expect(w.calendar.toString(), '673-11-28 02:00:00');
    });

    test('the clock does not run past a scheduled moment', () {
      final w = worldWith(fighter());
      final due = w.calendar.copy()..advance(minutes: 90);
      w.rest(6, rng: Random(1), notAfter: due);
      expect(w.calendar.toString(), '673-11-27 17:30:00');
    });

    test('no enemy appears while resting', () {
      final w = worldWith(fighter())..options.encounterTendency = 1;
      for (var i = 0; i < 50; i++) {
        expect(w.rest(1, rng: ScriptedRandom([0])).encounterStarted, isFalse);
      }
    });
  });

  group('rest: level-up', () {
    test('is judged from the trained total, at rest', () {
      final m = fighter(trainedExp: 6000);
      final w = worldWith(m);
      expect(m.level, 1);
      final out = w.rest(1, rng: Random(1));
      expect(out.first<LevelUp>()!.level, 3);
      expect(m.level, 3);
    });

    test('training and then resting is the whole road to a level', () {
      final m = fighter(exp: 1500);
      final w = worldWith(m);
      w.train(0, TrainingFacility.military, FighterSkill.slash);
      expect(m.level, 1);
      expect(w.rest(1, rng: Random(1)).first<LevelUp>()!.level, 2);
    });

    test('HP does not rise with the level; MP was filled at the old level', () {
      final m = mage(trainedExp: 1500);
      final w = worldWith(m);
      w.rest(1, rng: Random(1));
      expect(m.level, 2);
      expect(m.maxHp, 200);
      expect(m.hp, 100);
      expect(m.maxMp, 200);
      expect(m.mp, 100);
    });

    test('nobody below the threshold moves, nobody ever drops', () {
      final a = fighter(trainedExp: 1499);
      final b = fighter(level: 12, trainedExp: 0);
      final w = worldWith(a);
      w.join(b);
      expect(w.rest(1, rng: Random(1)).has<LevelUp>(), isFalse);
      expect(a.level, 1);
      expect(b.level, 12);
    });

    test('the unconscious are not judged', () {
      final m = fighter(trainedExp: 99999)
        ..hp = 0
        ..unconscious = 500;
      final w = worldWith(m);
      w.join(fighter());
      expect(w.rest(2, rng: Random(1)).has<LevelUp>(), isFalse);
      expect(m.level, 1);
    });

    test('level 40 is the ceiling', () {
      final m = fighter(trainedExp: 2000000000);
      final w = worldWith(m);
      expect(w.rest(1, rng: Random(1)).first<LevelUp>()!.level, 40);
      expect(w.rest(1, rng: Random(1)).has<LevelUp>(), isFalse);
    });

    test('a demigod gains +1 in six abilities per level, never past 20', () {
      final m = fighter(
        classId: ClassId.demigod,
        abilities: [19, 10, 10, 10, 10, 10, 10, 10],
        trainedExp: 6000,
      );
      final w = worldWith(m, episode: Episode.ep1);
      final out = w.rest(1, rng: Random(1));
      expect(m.level, 3);
      // 두 레벨: 체력은 20 에서 멈추고, 저항력·행운은 그대로.
      expect(m.abilities, [20, 12, 12, 12, 10, 12, 12, 10]);
      expect(out.of<AbilityRaised>().length, 6);
    });

    test('an esper gains one ability on a passed luck check, in order', () {
      Member esper() => mage(
        classId: ClassId.esper,
        abilities: [10, 10, 20, 10, 10, 10, 19, 10],
        trainedExp: 1500,
      );
      // 행운 10: 굴림 9 는 통과, 10 은 실패.
      final lucky = esper();
      final out = worldWith(
        lucky,
        episode: Episode.ep1,
      ).rest(1, rng: ScriptedRandom([9]));
      // 집중력은 이미 20 이라 다음 차례인 정확성이 오른다.
      expect(out.first<AbilityRaised>()!.ability, Ability.accuracy);
      expect(lucky.accuracy, 20);

      final unlucky = esper();
      final none = worldWith(
        unlucky,
        episode: Episode.ep1,
      ).rest(1, rng: ScriptedRandom([10]));
      expect(none.has<AbilityRaised>(), isFalse);
      expect(unlucky.level, 2);
    });
  });

  group('step: time', () {
    test('two minutes on the field, five seconds elsewhere', () {
      final w = worldWith(fighter());
      w.step(walk, rng: noEncounter());
      expect(w.calendar.toString(), '673-11-27 16:02:00');
      w.step(const StepInput(mapKind: MapKind.town), rng: noEncounter());
      w.step(const StepInput(mapKind: MapKind.cave), rng: noEncounter());
      w.step(const StepInput(mapKind: MapKind.fortress), rng: noEncounter());
      expect(w.calendar.toString(), '673-11-27 16:02:15');
    });

    test('thirty field steps make an hour; 720 make a day', () {
      final w = worldWith(fighter());
      for (var i = 0; i < 30; i++) {
        w.step(walk, rng: noEncounter());
      }
      expect(w.calendar.hour, 17);
      for (var i = 0; i < 720; i++) {
        w.step(walk, rng: noEncounter());
      }
      expect(w.calendar.toString(), '673-11-28 17:00:00');
    });

    test('event tiles, swamp and lava take no time', () {
      final w = worldWith(fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 20]));
      final before = w.calendar.totalSeconds;
      w.step(const StepInput(terrain: Terrain.event), rng: noEncounter());
      w.step(swamp, rng: ScriptedRandom([0]));
      w.step(lava, rng: ScriptedRandom([0]));
      expect(w.calendar.totalSeconds, before);
    });
  });

  group('step: encounters', () {
    test('one in 20 × tendency', () {
      final w = worldWith(fighter());
      // 성향 2 → rand(40) == 0 일 때만.
      expect(
        w.step(walk, rng: ScriptedRandom([0, 2])).encounterStarted,
        isTrue,
      );
      expect(w.step(walk, rng: ScriptedRandom([1])).encounterStarted, isFalse);
      expect(w.step(walk, rng: ScriptedRandom([39])).encounterStarted, isFalse);
      // 40 은 rand(40) 에서 0 이 된다.
      expect(
        w.step(walk, rng: ScriptedRandom([40, 0])).encounterStarted,
        isTrue,
      );
    });

    test('the tendency really changes the rate', () {
      int count(int tendency) {
        final w = worldWith(fighter())..options.encounterTendency = tendency;
        final rng = Random(42);
        var n = 0;
        for (var i = 0; i < 20000; i++) {
          if (w.step(walk, rng: rng).encounterStarted) n++;
        }
        return n;
      }

      // 1/20 → 1000, 1/100 → 200.
      expect(count(1), inInclusiveRange(850, 1150));
      expect(count(5), inInclusiveRange(130, 270));
    });

    test('the number of enemies is rand(max) + 1', () {
      final w = worldWith(fighter())..options.maxEnemies = 8;
      expect(
        w
            .step(walk, rng: ScriptedRandom([0, 7]))
            .first<EncounterStarted>()!
            .enemyCount,
        8,
      );
      expect(
        w
            .step(walk, rng: ScriptedRandom([0, 0]))
            .first<EncounterStarted>()!
            .enemyCount,
        1,
      );
    });

    test('never in a town, never where the map says no', () {
      final w = worldWith(fighter());
      final always = ScriptedRandom([0]);
      expect(
        w
            .step(const StepInput(mapKind: MapKind.town), rng: always)
            .encounterStarted,
        isFalse,
      );
      expect(
        w
            .step(const StepInput(encounters: false), rng: always)
            .encounterStarted,
        isFalse,
      );
      expect(
        w
            .step(const StepInput(mapKind: MapKind.cave), rng: always)
            .encounterStarted,
        isTrue,
      );
    });

    test('same seed, same walk', () {
      List<bool> run() {
        final w = worldWith(fighter());
        final rng = Random(2026);
        return [
          for (var i = 0; i < 300; i++) w.step(walk, rng: rng).encounterStarted,
        ];
      }

      expect(run(), run());
    });
  });

  group('step: poison', () {
    test('every tenth step costs one HP', () {
      final m = fighter()..poison = 1;
      final w = worldWith(m);
      for (var i = 0; i < 9; i++) {
        expect(w.step(walk, rng: noEncounter()).has<MemberHarmed>(), isFalse);
      }
      expect(m.hp, 100);
      expect(m.poison, 10);
      final out = w.step(walk, rng: noEncounter());
      final e = out.first<MemberHarmed>()!;
      expect(e.cause, HarmCause.poison);
      expect(e.amount, 1);
      expect(m.hp, 99);
      // 10 을 넘으면 1 로 돌아간다.
      expect(m.poison, 1);
    });

    test('the healthy are not touched', () {
      final m = fighter();
      final w = worldWith(m);
      for (var i = 0; i < 50; i++) {
        w.step(walk, rng: noEncounter());
      }
      expect(m.hp, 100);
      expect(m.poison, 0);
    });

    test(
      'at zero HP the member falls unconscious, then dies past the limit',
      () {
        final m = fighter()
          ..hp = 1
          ..poison = 10;
        final w = worldWith(m);
        w.join(fighter());
        expect(
          w.step(walk, rng: noEncounter()).first<MemberHarmed>()!.result,
          DamageResult.fellUnconscious,
        );
        expect(m.unconscious, 1);
        // 한계 10: 의식불명 수치가 11 이 되는 순간 죽는다.
        for (var tick = 0; tick < 9; tick++) {
          m.poison = 10;
          w.step(walk, rng: noEncounter());
        }
        expect(m.unconscious, 10);
        expect(m.dead, 0);
        m.poison = 10;
        expect(
          w.step(walk, rng: noEncounter()).first<MemberHarmed>()!.result,
          DamageResult.died,
        );
        expect(m.dead, 1);
      },
    );

    test('the dead keep counting, but only below 100 on the field', () {
      final m = fighter()
        ..hp = 0
        ..dead = 99
        ..poison = 10;
      final w = worldWith(m);
      w.join(fighter());
      w.step(walk, rng: noEncounter());
      expect(m.dead, 100);
      m.poison = 10;
      expect(w.step(walk, rng: noEncounter()).has<MemberHarmed>(), isFalse);
      expect(m.dead, 100);
    });

    test('poison alone can end the game', () {
      final m = fighter()
        ..hp = 1
        ..poison = 10;
      final w = worldWith(m);
      final out = w.step(walk, rng: ScriptedRandom([0]));
      expect(out.gameOver, isTrue);
      // 전멸했으면 조우도 시간도 없다.
      expect(out.encounterStarted, isFalse);
      expect(w.calendar.toString(), '673-11-27 16:00:00');
    });

    test('swamp steps advance the poison too', () {
      final m = fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 20])
        ..poison = 10;
      final w = worldWith(m);
      w.buffs.grant(FieldBuff.swampWalk);
      final out = w.step(swamp, rng: noEncounter());
      expect(out.first<MemberHarmed>()!.cause, HarmCause.poison);
      expect(m.hp, 99);
    });
  });

  group('step: swamp', () {
    test('rand(20) + 1 ≥ luck poisons', () {
      // 행운 10: 굴림 8 → 9 < 10 안전, 굴림 9 → 10 ≥ 10 중독.
      final safe = fighter();
      var out = worldWith(safe).step(swamp, rng: ScriptedRandom([8]));
      expect(out.first<EnteredSwamp>()!.protected, isFalse);
      expect(out.has<MemberPoisoned>(), isFalse);
      expect(safe.poison, 0);

      final caught = fighter();
      out = worldWith(caught).step(swamp, rng: ScriptedRandom([9]));
      expect(out.first<MemberPoisoned>()!.seat, 0);
      expect(caught.poison, 1);
    });

    test('luck 20 is safe against all but the highest roll', () {
      final m = fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 20]);
      final w = worldWith(m);
      for (var roll = 0; roll < 19; roll++) {
        w.step(swamp, rng: ScriptedRandom([roll]));
      }
      expect(m.poison, 0);
      w.step(swamp, rng: ScriptedRandom([19]));
      expect(m.poison, 1);
    });

    test('each member rolls for themselves', () {
      final w = worldWith(fighter());
      w.join(fighter());
      w.join(fighter());
      final out = w.step(swamp, rng: ScriptedRandom([0, 19, 0]));
      expect(out.of<MemberPoisoned>().map((e) => e.seat), [1]);
    });

    test('swamp walk protects and wears down by one per step', () {
      final m = fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 0]);
      final w = worldWith(m);
      w.buffs.swampWalk = 2;
      expect(
        w
            .step(swamp, rng: ScriptedRandom([19]))
            .first<EnteredSwamp>()!
            .protected,
        isTrue,
      );
      expect(
        w
            .step(swamp, rng: ScriptedRandom([19]))
            .first<EnteredSwamp>()!
            .protected,
        isTrue,
      );
      expect(m.poison, 0);
      expect(w.buffs.swampWalk, 0);
      expect(
        w.step(swamp, rng: ScriptedRandom([19])).has<MemberPoisoned>(),
        isTrue,
      );
    });

    test('no encounter in a swamp', () {
      final w = worldWith(fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 20]));
      for (var i = 0; i < 100; i++) {
        expect(
          w.step(swamp, rng: ScriptedRandom([0])).encounterStarted,
          isFalse,
        );
      }
    });
  });

  group('step: lava', () {
    test('damage = (rand(40) + 40 − 2 × rand(luck)) × 10', () {
      // 굴림: rand(luck=10) → 3, rand(40) → 5: (5 + 40 − 6) × 10 = 390.
      final m = fighter(level: 10);
      final out = worldWith(m).step(lava, rng: ScriptedRandom([3, 5]));
      expect(out.has<EnteredLava>(), isTrue);
      final e = out.first<MemberHarmed>()!;
      expect(e.cause, HarmCause.lava);
      expect(e.amount, 390);
      expect(m.hp, 1000 - 390);
    });

    test('with no luck the full 400..790 lands', () {
      final m = fighter(level: 20, abilities: [10, 10, 10, 10, 10, 10, 10, 0]);
      final w = worldWith(m);
      expect(
        w.step(lava, rng: ScriptedRandom([0])).first<MemberHarmed>()!.amount,
        400,
      );
      expect(
        w.step(lava, rng: ScriptedRandom([39])).first<MemberHarmed>()!.amount,
        790,
      );
    });

    test('great luck can cancel it altogether', () {
      // 행운 30: rand(30) → 29, rand(40) → 0: (0 + 40 − 58) × 10 < 0.
      final m = fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 30]);
      final out = worldWith(m).step(lava, rng: ScriptedRandom([29, 0]));
      expect(out.has<MemberHarmed>(), isFalse);
      expect(m.hp, 100);
    });

    test(
      'goes HP → unconscious → dead, and the death count stops at 30000',
      () {
        final m = fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 0]);
        final w = worldWith(m);
        w.join(fighter(level: 30, abilities: [10, 10, 10, 10, 10, 10, 10, 0]));
        final rng = ScriptedRandom([0]);
        expect(
          w.step(lava, rng: rng).first<MemberHarmed>()!.result,
          DamageResult.fellUnconscious,
        );
        expect(
          w.step(lava, rng: rng).first<MemberHarmed>()!.result,
          DamageResult.died,
        );
        expect(
          w.step(lava, rng: rng).first<MemberHarmed>()!.result,
          DamageResult.deeperDead,
        );
        expect(m.dead, 401);
        m.dead = 29900;
        w.step(lava, rng: rng);
        expect(m.dead, 30000);
      },
    );

    test('lava can end the game', () {
      final m = fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 0]);
      expect(
        worldWith(m).step(lava, rng: ScriptedRandom([0])).gameOver,
        isTrue,
      );
    });
  });

  group('step: water and mind reading', () {
    test('water needs the water-walk effect', () {
      final w = worldWith(fighter());
      const water = StepInput(terrain: Terrain.water);
      final refused = w.step(water, rng: noEncounter());
      expect(refused.reason, RefusalReason.waterBlocked);
      expect(w.calendar.toString(), '673-11-27 16:00:00');
      w.buffs.grant(FieldBuff.waterWalk);
      expect(w.step(water, rng: noEncounter()).ok, isTrue);
      expect(w.calendar.minute, 2);
      // 제3부 체계: 물을 걸어도 효과 수치는 줄지 않는다.
      expect(w.buffs.waterWalk, 255);
    });

    test('mind reading lasts three ordinary steps', () {
      final w = worldWith(fighter());
      w.startMindReading();
      w.step(walk, rng: noEncounter());
      w.step(walk, rng: noEncounter());
      expect(w.isMindReading, isTrue);
      final out = w.step(walk, rng: noEncounter());
      expect(out.has<MindReadingEnded>(), isTrue);
      expect(w.isMindReading, isFalse);
    });

    test('event tiles, swamp and lava do not count as steps', () {
      final w = worldWith(fighter(abilities: [10, 10, 10, 10, 10, 10, 10, 20]));
      w.startMindReading();
      w.step(const StepInput(terrain: Terrain.event), rng: noEncounter());
      w.step(swamp, rng: ScriptedRandom([0]));
      w.step(lava, rng: ScriptedRandom([19, 0]));
      expect(w.buffs.mindReadSteps, 3);
    });
  });

  group('sight', () {
    LoreWorld at(int hour, int minute, {int day = 1, int torch = 0}) =>
        worldWith(fighter())
          ..setTorch(torch)
          ..calendar = LoreCalendar(
            year: 673,
            month: 1,
            day: day,
            hour: hour,
            minute: minute,
          );

    test('daylight from 7:00 to 17:59', () {
      expect(at(7, 0).sight(MapKind.field).isFull, isTrue);
      expect(at(17, 59).sight(MapKind.field).isFull, isTrue);
      expect(at(6, 59).sight(MapKind.field).isFull, isFalse);
      expect(at(18, 0).sight(MapKind.field).isFull, isFalse);
    });

    test('dusk narrows every twenty minutes, dawn widens', () {
      int r(int h, int m) => at(h, m).sight(MapKind.field).radius!;
      expect(
        [r(18, 0), r(18, 19), r(18, 20), r(18, 39), r(18, 40), r(18, 59)],
        [4, 4, 3, 3, 2, 2],
      );
      expect([r(19, 0), r(0, 0), r(5, 59)], [1, 1, 1]);
      expect([r(6, 0), r(6, 20), r(6, 40), r(6, 59)], [2, 3, 4, 4]);
    });

    test('the moon is up from the 10th to the 20th', () {
      expect(at(22, 0, day: 9).sight(MapKind.field).dimBeyond, isFalse);
      expect(at(22, 0, day: 10).sight(MapKind.field).dimBeyond, isTrue);
      expect(at(22, 0, day: 20).sight(MapKind.field).dimBeyond, isTrue);
      expect(at(22, 0, day: 21).sight(MapKind.field).dimBeyond, isFalse);
    });

    test(
      'towns always have moonlight; caves never, and are always radius 1',
      () {
        expect(at(22, 0).sight(MapKind.town).dimBeyond, isTrue);
        expect(
          at(12, 0, day: 15).sight(MapKind.cave),
          const Sight(radius: 1, dimBeyond: false),
        );
      },
    );

    test(
      'the torch widens the dark: 1–2 → 2, 3–4 → 3, 5+ → 3 and dim beyond',
      () {
        Sight s(int torch) => at(23, 0, torch: torch).sight(MapKind.cave);
        expect(s(0), const Sight(radius: 1, dimBeyond: false));
        expect(s(1), const Sight(radius: 2, dimBeyond: false));
        expect(s(2), const Sight(radius: 2, dimBeyond: false));
        expect(s(3), const Sight(radius: 3, dimBeyond: false));
        expect(s(4), const Sight(radius: 3, dimBeyond: false));
        expect(s(5), const Sight(radius: 3, dimBeyond: true));
        expect(s(255), const Sight(radius: 3, dimBeyond: true));
      },
    );

    test('a torch never narrows what dusk still shows', () {
      expect(at(18, 0, torch: 1).sight(MapKind.field).radius, 4);
    });

    test('the darkness zone beats everything', () {
      expect(
        at(12, 0, torch: 255).sight(MapKind.fortress, darknessZone: true),
        const Sight(radius: 0, dimBeyond: false),
      );
    });
  });

  group('calendar', () {
    test('twelve months of thirty days', () {
      final c = LoreCalendar(
        year: 673,
        month: 12,
        day: 30,
        hour: 23,
        minute: 59,
      );
      c.advance(minutes: 1);
      expect(c.toString(), '674-1-1 00:00:00');
      expect(LoreCalendar.daysPerYear, 360);
    });

    test('day of year: 673-11-27 is day 326', () {
      expect(LoreCalendar.startOf(Episode.ep3).dayOfYear, 326);
    });

    test('each part starts on its own date', () {
      expect(
        LoreCalendar.startOf(Episode.ep3).toString(),
        '673-11-27 16:00:00',
      );
      expect(LoreCalendar.startOf(Episode.ep1).toString(), '771-3-1 09:00:00');
      expect(LoreCalendar.startOf(Episode.ep2).toString(), '774-1-19 10:10:00');
    });

    test('a week of language lessons', () {
      final c = LoreCalendar.startOf(Episode.ep3)..advance(days: 7);
      expect(c.toString(), '673-12-4 16:00:00');
    });

    test('negative advances are ignored', () {
      final c = LoreCalendar.startOf(Episode.ep3)..advance(hours: -5);
      expect(c.toString(), '673-11-27 16:00:00');
    });
  });
}
