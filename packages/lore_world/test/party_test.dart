import 'dart:math';

import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('seats', () {
    test('six seats: protagonist, four companions, one assistant', () {
      expect(Seat.count, 6);
      expect(Seat.protagonist, 0);
      expect(Seat.firstCompanion, 1);
      expect(Seat.lastCompanion, 4);
      expect(Seat.assistant, 5);
      final w = worldWith(fighter());
      expect(w.seats.length, 6);
      expect(w.presentSeats, [0]);
    });

    test('a companion takes the first free seat', () {
      final w = worldWith(fighter());
      expect(w.join(mage(name: 'A')).first<MemberJoined>()!.seat, 1);
      expect(w.join(mage(name: 'B')).first<MemberJoined>()!.seat, 2);
      w.dismiss(1);
      expect(w.join(mage(name: 'C')).first<MemberJoined>()!.seat, 1);
    });

    test(
      'a full party refuses; the assistant seat is not a companion seat',
      () {
        final w = worldWith(fighter());
        for (var i = 0; i < 4; i++) {
          expect(w.join(mage()).ok, isTrue);
        }
        expect(w.seats[Seat.assistant], isNull);
        expect(w.join(mage()).reason, RefusalReason.partyFull);
        expect(w.firstFreeCompanionSeat, isNull);
      },
    );

    test('the assistant is overwritten by the next one', () {
      final w = worldWith(fighter());
      expect(
        w.setAssistant(fighter(name: 'One')).first<AssistantSet>()!.replaced,
        isFalse,
      );
      expect(
        w.setAssistant(fighter(name: 'Two')).first<AssistantSet>()!.replaced,
        isTrue,
      );
      expect(w.assistant!.name, 'Two');
    });

    test('dismissal is for seats 1..5 and is permanent', () {
      final w = worldWith(fighter());
      w.join(mage(name: 'Vega'));
      w.setAssistant(fighter(name: 'Aide'));
      expect(w.dismiss(0).reason, RefusalReason.cannotDismissProtagonist);
      expect(w.dismiss(3).reason, RefusalReason.noSuchMember);
      expect(w.dismiss(9).reason, RefusalReason.invalidSeat);
      final gone = w.dismiss(1).first<MemberDismissed>()!;
      expect(gone.name, 'Vega');
      expect(w.member(1), isNull);
      expect(w.dismiss(5).ok, isTrue);
      expect(w.assistant, isNull);
    });

    test('reordering swaps two occupied companion seats', () {
      final w = worldWith(fighter());
      w.join(mage(name: 'A'));
      w.join(mage(name: 'B'));
      expect(w.swapSeats(1, 2).first<SeatsSwapped>(), isNotNull);
      expect(w.member(1)!.name, 'B');
      expect(w.member(2)!.name, 'A');
      expect(w.swapSeats(0, 1).reason, RefusalReason.invalidSeat);
      expect(w.swapSeats(1, 5).reason, RefusalReason.invalidSeat);
      expect(w.swapSeats(1, 1).reason, RefusalReason.invalidSeat);
      expect(w.swapSeats(1, 3).reason, RefusalReason.noSuchMember);
    });

    test('replace swaps a newcomer into a seat (Part 1 join)', () {
      final w = worldWith(fighter(), episode: Episode.ep1);
      for (final key in ['hercules', 'titan', 'merlin', 'betelgeuse']) {
        w.join(rosterEp1[key]!.build());
      }
      expect(
        w.join(rosterEp1['polaris']!.build()).reason,
        RefusalReason.partyFull,
      );
      final out = w.replace(2, rosterEp1['polaris']!.build());
      expect(out.first<MemberDismissed>()!.nameKey, 'companion.titan');
      expect(out.first<MemberJoined>()!.seat, 2);
      expect(w.hasRosterMember('polaris'), isTrue);
      expect(w.hasRosterMember('titan'), isFalse);
      expect(
        w.replace(0, fighter()).reason,
        RefusalReason.cannotDismissProtagonist,
      );
      // 비어 있는 5번 자리에 두는 것도 된다.
      expect(
        w
            .replace(5, rosterEp1['skeleton']!.build())
            .first<AssistantSet>()!
            .replaced,
        isFalse,
      );
    });
  });

  group('hidden companions', () {
    test('are kept but treated as absent everywhere', () {
      final w = worldWith(fighter())..food = 9;
      final vega = mage(name: 'Vega')..hp = 1;
      w.join(vega);
      w.setAssistant(fighter(name: 'Aide'));
      final out = w.hideCompanions();
      expect(out.first<CompanionsHidden>()!.seats, [1]);
      expect(w.member(1), isNull);
      expect(w.presentSeats, [0, 5]);
      // 숨은 동안 쉬어도 회복되지 않는다.
      w.rest(6, rng: Random(1));
      expect(vega.hp, 1);
      // 돌아올 사람의 자리는 빈자리가 아니다.
      expect(w.join(mage(name: 'New')).first<MemberJoined>()!.seat, 2);
      w.restoreCompanions();
      expect(w.member(1)!.name, 'Vega');
    });

    test('the assistant is not hidden', () {
      final w = worldWith(fighter());
      w.setAssistant(fighter(name: 'Aide'));
      w.hideCompanions();
      expect(w.assistant, isNotNull);
    });
  });

  group('game over', () {
    test('only when all six seats cannot act', () {
      final w = worldWith(fighter()..dead = 1);
      expect(w.isGameOver, isTrue);
      w.setAssistant(fighter(name: 'Aide'));
      // 보조 일원만 행동할 수 있어도 끝이 아니다.
      expect(w.isGameOver, isFalse);
      w.assistant!.unconscious = 1;
      expect(w.isGameOver, isTrue);
    });

    test('a hidden companion cannot save the party', () {
      final w = worldWith(fighter());
      w.join(mage());
      w.hideCompanions();
      w.protagonist!.hp = 0;
      expect(w.isGameOver, isTrue);
    });

    test('harm reports it', () {
      final w = worldWith(fighter());
      final out = w.harm(0, 100);
      expect(out.first<MemberHarmed>()!.result, DamageResult.fellUnconscious);
      expect(out.gameOver, isTrue);
    });
  });

  group('enemy → assistant', () {
    const draconian = EnemyStatBlock(
      nameKey: 'enemy.draconian',
      level: 12,
      strength: 30,
      mentality: 20,
      endurance: 30,
      agility: 18,
      physicalResist: 40,
      physicalAccuracy: 18,
      defence: 4,
    );

    test('follows the conversion table of chapter 7.8', () {
      final m = assistantFromEnemy(draconian);
      expect(m.nameKey, 'enemy.draconian');
      expect(m.level, 12);
      expect(m.gender, Gender.neutral);
      expect(m.family, Family.unknown);
      expect(m.attackMode, AttackMode.single);
      expect(m.strength, 30);
      expect(m.mentality, 20);
      expect(m.concentration, 0);
      expect(m.endurance, 30);
      expect(m.resistance, 20);
      expect(m.agility, 18);
      expect(m.accuracy, 18);
      expect(m.luck, 10);
      expect(m.hp, 30 * 12 * 10);
      expect(m.mp, 20 * 12 * 10);
      expect(m.ac, 4);
      expect(m.weaponPower, 12 * 2 + 10);
      expect(m.weaponKind, WeaponKind.special);
      expect(m.trainedExp, trainedExpForLevel(12));
    });

    test(
      'the family is always unknown — never inherited from the last assistant',
      () {
        final w = worldWith(fighter());
        w.setAssistant(buildSummon(crystalGolem, skill: 0, rng: Random(1)));
        expect(w.assistant!.attackMode, AttackMode.all);
        w.setAssistant(assistantFromEnemy(draconian));
        expect(w.assistant!.family, Family.unknown);
        expect(w.assistant!.attackMode, AttackMode.single);
      },
    );

    test('an odd resistance halves downward', () {
      final m = assistantFromEnemy(
        const EnemyStatBlock(
          nameKey: 'enemy.orc_soldier',
          level: 3,
          strength: 10,
          mentality: 0,
          endurance: 12,
          agility: 8,
          physicalResist: 5,
          physicalAccuracy: 9,
          defence: 2,
        ),
      );
      expect(m.resistance, 2);
      expect(m.mp, 0);
    });
  });

  group('battle settlement', () {
    test('writes back what the battle left', () {
      final w = worldWith(fighter(level: 3))..arrows = 20;
      w.give(ItemKey.hpPotion, 3);
      w.join(mage(level: 2));
      final out = w.settleBattle(
        const BattleSettlement(
          seats: [
            SeatSettlement(0, hp: 120, expGained: 343, acLoss: 1),
            SeatSettlement(1, hp: 0, mp: 15, unconscious: 4, poison: 2),
          ],
          goldGained: 1029,
          arrowsUsed: 7,
          itemsUsed: {ItemKey.hpPotion: 2},
        ),
      );
      expect(out.ok, isTrue);
      expect(w.protagonist!.hp, 120);
      expect(w.protagonist!.exp, 343);
      expect(w.protagonist!.ac, 1);
      expect(w.member(1)!.condition, Condition.unconscious);
      expect(w.member(1)!.mp, 15);
      expect(w.member(1)!.poison, 2);
      expect(w.gold, 1029);
      expect(w.arrows, 13);
      expect(w.countOf(ItemKey.hpPotion), 1);
      expect(out.first<ExpGained>()!.amount, 343);
      expect(out.first<GoldGained>()!.amount, 1029);
      expect(out.gameOver, isFalse);
    });

    test(
      'battle experience is unspent — the level waits for training and rest',
      () {
        final w = worldWith(fighter());
        w.settleBattle(
          const BattleSettlement(seats: [SeatSettlement(0, expGained: 99999)]),
        );
        w.rest(1, rng: Random(1));
        expect(w.protagonist!.level, 1);
      },
    );

    test('values are clamped to what the member can hold', () {
      final w = worldWith(fighter());
      w.settleBattle(
        const BattleSettlement(seats: [SeatSettlement(0, hp: 99999, mp: 500)]),
      );
      expect(w.protagonist!.hp, 100);
      expect(w.protagonist!.mp, 0);
    });

    test('a summon or a persuaded enemy takes the assistant seat', () {
      final w = worldWith(fighter());
      w.setAssistant(fighter(name: 'Old'));
      final out = w.settleBattle(
        BattleSettlement(newAssistant: fighter(name: 'New')),
      );
      expect(out.first<AssistantSet>()!.replaced, isTrue);
      expect(w.assistant!.name, 'New');
    });

    test('mind control takes the assistant away', () {
      final w = worldWith(fighter());
      w.setAssistant(fighter(name: 'Aide'));
      w.settleBattle(const BattleSettlement(assistantLost: true));
      expect(w.assistant, isNull);
    });

    test('a wipe-out is reported', () {
      final w = worldWith(fighter());
      final out = w.settleBattle(
        const BattleSettlement(
          seats: [SeatSettlement(0, hp: 0, unconscious: 1)],
        ),
      );
      expect(out.gameOver, isTrue);
    });

    test('story rewards go to those who can act in seats 0..4', () {
      final w = worldWith(fighter());
      w.join(mage()..dead = 1);
      w.setAssistant(fighter(name: 'Aide'));
      final out = w.grantExp(500000);
      expect(out.of<ExpGained>().map((e) => e.seat), [0]);
      expect(w.protagonist!.exp, 500000);
      expect(w.grantExp(10000, to: [0, 1, 5]).of<ExpGained>().length, 3);
      expect(w.grantExp(0).reason, RefusalReason.invalidAmount);
    });
  });

  group('party figures', () {
    test('averages run over everyone present, rounded down', () {
      final w = worldWith(fighter(abilities: [10, 10, 10, 10, 10, 15, 10, 20]));
      w.join(mage(abilities: [10, 10, 10, 10, 10, 10, 10, 11]));
      w.setAssistant(
        Member(
          family: Family.unknown,
          abilities: [10, 10, 10, 10, 10, 0, 10, 10],
        )..hp = 5,
      );
      expect(w.average(Ability.luck), 13);
      expect(w.average(Ability.agility), 8);
    });

    test('command seats are 0..4 who can act', () {
      final w = worldWith(fighter(level: 4));
      w.join(mage(level: 9)..unconscious = 1);
      w.join(mage(level: 7));
      w.setAssistant(fighter(name: 'Aide', level: 30));
      expect(w.commandSeats, [0, 2]);
      expect(w.averageCommandLevel, 5);
    });
  });

  group('new game', () {
    test('Part 3: empty-handed, torch 4, 673-11-27 16:00', () {
      final w = LoreWorld.newGame(Episode.ep3, fighter());
      expect([w.gold, w.food, w.arrows, w.torch], [0, 0, 0, 4]);
      expect(w.consumables, isEmpty);
      expect(w.crystals, isEmpty);
      expect(w.backpack, isEmpty);
      expect(w.options.encounterTendency, 2);
      expect(w.options.maxEnemies, 5);
      expect(w.options.attackUnconscious, isTrue);
      expect(w.specialMagicUnlocked, isTrue);
    });

    test(
      'Part 1: food 20, gold 2000, special magic and ESP training locked',
      () {
        final w = LoreWorld.newGame(Episode.ep1, fighter());
        expect([w.gold, w.food, w.torch], [2000, 20, 0]);
        expect(w.specialMagicUnlocked, isFalse);
        expect(w.espTrainingUnlocked, isFalse);
      },
    );

    test('Part 2: alone and empty-handed on 774-1-19', () {
      final w = LoreWorld.newGame(Episode.ep2, fighter());
      expect([w.gold, w.food], [0, 0]);
      expect(w.calendar.toString(), '774-1-19 10:10:00');
      expect(w.presentSeats, [0]);
    });

    test('promoting the party to demigod keeps each family', () {
      final w = LoreWorld.newGame(Episode.ep1, fighter());
      w.join(mage());
      w.setAssistant(rosterEp1['skeleton']!.build());
      final out = w.promoteAllToDemigod();
      expect(out.of<ClassChanged>().map((e) => e.seat), [0, 1]);
      expect(w.protagonist!.classDef!.key, 'class.demigod');
      expect(w.protagonist!.family, Family.fighter);
      expect(w.member(1)!.family, Family.mage);
      expect(w.assistant!.classId, ClassId.none);
    });
  });
}
