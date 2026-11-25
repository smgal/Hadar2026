import 'dart:math';

import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final rng = Random(1);

  group('herbs and potions', () {
    test('the HP potion gives up to 1000 to the user', () {
      final m = fighter(level: 20)..hp = 100;
      final w = worldWith(m)..give(ItemKey.hpPotion, 2);
      final out = w.useConsumable(ItemKey.hpPotion, user: 0, rng: rng);
      expect(out.first<HpRestored>()!.amount, 1000);
      expect(m.hp, 1100);
      expect(out.first<ItemUsed>()!.remaining, 1);
      expect(w.countOf(ItemKey.hpPotion), 1);
    });

    test('the MP potion works for mages and paladins only', () {
      final wiz = mage(level: 20)..mp = 0;
      final w = worldWith(fighter())..give(ItemKey.mpPotion, 3);
      w.join(wiz);
      w.join(fighter(classId: ClassId.paladin, level: 4)..mp = 0);

      final refused = w.useConsumable(ItemKey.mpPotion, user: 0, rng: rng);
      expect(refused.reason, RefusalReason.notMagicUser);
      expect(w.countOf(ItemKey.mpPotion), 3);

      expect(w.useConsumable(ItemKey.mpPotion, user: 1, rng: rng).ok, isTrue);
      expect(wiz.mp, 1000);
      // 전사의 한도는 정신력 × 레벨 × 5.
      expect(w.useConsumable(ItemKey.mpPotion, user: 2, rng: rng).ok, isTrue);
      expect(w.member(2)!.mp, 200);
    });

    test('the antidote clears the user', () {
      final m = fighter()..poison = 7;
      final w = worldWith(m)..give(ItemKey.antidoteHerb);
      expect(
        w
            .useConsumable(ItemKey.antidoteHerb, user: 0, rng: rng)
            .has<PoisonCured>(),
        isTrue,
      );
      expect(m.poison, 0);
    });

    test('the awakening herb is used on someone else', () {
      final w = worldWith(fighter())..give(ItemKey.awakeningHerb, 2);
      final fallen = mage()
        ..hp = 0
        ..unconscious = 50;
      w.join(fallen);
      final out = w.useConsumable(
        ItemKey.awakeningHerb,
        user: 0,
        target: 1,
        rng: rng,
      );
      expect(out.first<Awakened>()!.seat, 1);
      expect(fallen.unconscious, 0);
      expect(fallen.hp, 1);

      fallen.dead = 1;
      final refused = w.useConsumable(
        ItemKey.awakeningHerb,
        user: 0,
        target: 1,
        rng: rng,
      );
      expect(refused.reason, RefusalReason.alreadyDead);
      expect(w.countOf(ItemKey.awakeningHerb), 1);
    });

    test('the revival herb works below a death count of 10000', () {
      final w = worldWith(fighter())..give(ItemKey.revivalHerb, 2);
      final corpse = mage()
        ..hp = 0
        ..dead = 9999;
      w.join(corpse);
      final out = w.useConsumable(
        ItemKey.revivalHerb,
        user: 0,
        target: 1,
        rng: rng,
      );
      expect(out.has<Revived>(), isTrue);
      expect(corpse.dead, 0);
      expect(corpse.condition, Condition.unconscious);

      corpse.dead = 10000;
      expect(
        w
            .useConsumable(ItemKey.revivalHerb, user: 0, target: 1, rng: rng)
            .reason,
        RefusalReason.beyondRevival,
      );
      expect(w.countOf(ItemKey.revivalHerb), 1);
    });

    test('an item with no effect is still used up, and says so', () {
      final w = worldWith(fighter())..give(ItemKey.hpPotion);
      expect(
        w.consumableWouldBeWasted(ItemKey.hpPotion, user: 0),
        RefusalReason.noTreatmentNeeded,
      );
      final out = w.useConsumable(ItemKey.hpPotion, user: 0, rng: rng);
      expect(out.ok, isTrue);
      expect(out.first<NoEffect>()!.reason, RefusalReason.noTreatmentNeeded);
      expect(w.countOf(ItemKey.hpPotion), 0);
    });

    test('the preview says nothing when the item would work', () {
      final m = fighter()..hp = 1;
      final w = worldWith(m);
      expect(w.consumableWouldBeWasted(ItemKey.hpPotion, user: 0), isNull);
      expect(
        w.consumableWouldBeWasted(ItemKey.antidoteHerb, user: 0),
        RefusalReason.notPoisoned,
      );
      expect(
        w.consumableWouldBeWasted(ItemKey.revivalHerb, user: 0),
        RefusalReason.notDead,
      );
    });

    test('who may use', () {
      final w = worldWith(fighter())..give(ItemKey.hpPotion);
      w.join(mage()..unconscious = 1);
      w.setAssistant(fighter(name: 'Aide'));
      expect(
        w.useConsumable(ItemKey.hpPotion, user: 1, rng: rng).reason,
        RefusalReason.userCannotAct,
      );
      expect(
        w.useConsumable(ItemKey.hpPotion, user: 5, rng: rng).reason,
        RefusalReason.invalidSeat,
      );
      expect(
        w.useConsumable(ItemKey.hpPotion, user: 3, rng: rng).reason,
        RefusalReason.noSuchMember,
      );
      expect(
        w.useConsumable(ItemKey.mpPotion, user: 0, rng: rng).reason,
        RefusalReason.noneOwned,
      );
      expect(
        w.useConsumable('item.nope', user: 0, rng: rng).reason,
        RefusalReason.unknownItem,
      );
    });
  });

  group('goods', () {
    test('the big torch adds 10, up to 255', () {
      final w = worldWith(fighter())..give(ItemKey.bigTorch, 2);
      expect(w.torch, 4);
      final out = w.useConsumable(ItemKey.bigTorch, user: 0, rng: rng);
      expect(out.first<TorchChanged>()!.value, 14);
      w.torch = 250;
      w.useConsumable(ItemKey.bigTorch, user: 0, rng: rng);
      expect(w.torch, 255);
    });

    test('the flying boots switch on all three until the next rest', () {
      final w = worldWith(fighter())..give(ItemKey.flyingBoots);
      final out = w.useConsumable(ItemKey.flyingBoots, user: 0, rng: rng);
      expect(out.first<BuffsGranted>()!.buffs, FieldBuff.values);
      expect(w.buffs.canLevitate, isTrue);
      expect(w.buffs.canWalkOnWater, isTrue);
      expect(w.buffs.canWalkOnSwamp, isTrue);
      expect(w.hasBuff(FieldBuff.waterWalk), isTrue);
    });

    test('the seeing orb asks the map side to show the map', () {
      final w = worldWith(fighter())..give(ItemKey.seeingOrb);
      final out = w.useConsumable(ItemKey.seeingOrb, user: 0, rng: rng);
      expect(out.mapAction!.action, MapAction.showMap);
      expect(w.countOf(ItemKey.seeingOrb), 0);
    });

    test('the warp orb teleports 1 to 9 tiles, 5 by default, without MP', () {
      final w = worldWith(fighter())..give(ItemKey.warpOrb, 3);
      final out = w.useConsumable(ItemKey.warpOrb, user: 0, rng: rng);
      expect(out.mapAction!.action, MapAction.teleport);
      expect(out.mapAction!.distance, 5);
      expect(
        w
            .useConsumable(ItemKey.warpOrb, user: 0, distance: 9, rng: rng)
            .mapAction!
            .distance,
        9,
      );
      expect(
        w
            .useConsumable(ItemKey.warpOrb, user: 0, distance: 10, rng: rng)
            .reason,
        RefusalReason.invalidAmount,
      );
      expect(w.countOf(ItemKey.warpOrb), 1);
    });

    test(
      'the summon scroll calls an other-dimension creature of the party level',
      () {
        final w = worldWith(fighter(level: 6))..give(ItemKey.summonScroll);
        w.join(mage(level: 9));
        w.join(fighter(level: 30)..unconscious = 1);
        final out = w.useConsumable(
          ItemKey.summonScroll,
          user: 0,
          rng: Random(5),
        );
        final set = out.first<AssistantSet>()!;
        expect(set.summoned, isTrue);
        expect(set.replaced, isFalse);
        final a = w.assistant!;
        // 행동 가능한 0~4번의 평균 레벨: (6 + 9) ÷ 2 = 7.
        expect(a.level, 7);
        expect(a.family, Family.unknown);
        expect(a.gender, Gender.neutral);
        expect(a.agility, 0);
        expect(a.hp, a.maxHp);
        expect(a.weaponKind, WeaponKind.special);
        expect(otherDimensionCreatures.map((c) => c.key), contains(a.nameKey));
      },
    );

    test('a new summon overwrites the assistant', () {
      final w = worldWith(fighter())..give(ItemKey.summonScroll, 2);
      w.useConsumable(ItemKey.summonScroll, user: 0, rng: Random(1));
      final out = w.useConsumable(
        ItemKey.summonScroll,
        user: 0,
        rng: Random(2),
      );
      expect(out.first<AssistantSet>()!.replaced, isTrue);
    });
  });

  group('crystals on the field', () {
    test(
      'the energy crystal restores everyone and raises the dead to 1 HP',
      () {
        final w = worldWith(fighter(level: 3)..hp = 5)..give(CrystalKey.energy);
        final out1 = mage()
          ..hp = 0
          ..unconscious = 9;
        final dead = fighter()
          ..hp = 0
          ..unconscious = 10
          ..dead = 40000;
        w.join(out1);
        w.join(dead);
        final out = w.useCrystal(CrystalKey.energy, rng: rng);
        expect(out.ok, isTrue);
        expect(w.protagonist!.hp, 300);
        expect(out1.unconscious, 0);
        expect(out1.hp, out1.maxHp);
        expect(dead.dead, 0);
        expect(dead.unconscious, 0);
        expect(dead.hp, 1);
        expect(out.of<Revived>().single.seat, 2);
        expect(w.countOf(CrystalKey.energy), 0);
      },
    );

    test(
      'the summon crystal calls a level-30 assistant immune to mind control',
      () {
        final seen = <String>{};
        for (var seed = 0; seed < 40; seed++) {
          final w = worldWith(fighter())..give(CrystalKey.summon);
          final out = w.useCrystal(CrystalKey.summon, rng: Random(seed));
          expect(out.first<AssistantSet>()!.summoned, isTrue);
          final a = w.assistant!;
          expect(a.level, 30);
          expect(a.mindControlImmune, isTrue);
          expect(a.hp, a.endurance * 300);
          seen.add(a.nameKey!);
        }
        expect(seen, {
          'summon.crystal_dragon',
          'summon.crystal_golem',
          'summon.archangel',
        });
      },
    );

    test('crystal summons carry the table numbers', () {
      final dragon = buildSummon(crystalDragon, skill: 0, rng: rng);
      expect(dragon.abilities, [25, 20, 20, 30, 20, 0, 20, 20]);
      expect(dragon.weaponPower, 255);
      expect(dragon.ac, 4);
      expect(dragon.attackMode, AttackMode.single);
      final golem = buildSummon(crystalGolem, skill: 0, rng: rng);
      expect(golem.abilities, [20, 0, 0, 40, 25, 0, 13, 0]);
      expect(golem.weaponPower, 150);
      expect(golem.attackMode, AttackMode.all);
      final angel = buildSummon(archangel, skill: 0, rng: rng);
      expect(angel.abilities, [20, 20, 20, 30, 19, 20, 20, 20]);
      expect(angel.weaponPower, 200);
      expect(angel.ac, 5);
      expect(angel.attackMode, AttackMode.all);
    });

    test('field odds are roughly 40 / 40 / 20', () {
      final counts = <String, int>{};
      final r = Random(99);
      for (var i = 0; i < 5000; i++) {
        final key = rollCrystalSummonOnField(r).key;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      expect(counts['summon.crystal_dragon'], inInclusiveRange(1850, 2150));
      expect(counts['summon.crystal_golem'], inInclusiveRange(1850, 2150));
      expect(counts['summon.archangel'], inInclusiveRange(880, 1120));
    });

    test('story crystals only report, and are not used up', () {
      for (final key in [CrystalKey.chromatic, CrystalKey.ball]) {
        final w = worldWith(fighter())..give(key);
        final out = w.useCrystal(key, rng: rng);
        expect(out.first<StoryCrystalUsed>()!.key, key);
        expect(w.countOf(key), 1);
      }
    });

    test('the five battle crystals are refused on the field', () {
      for (final key in [
        CrystalKey.flame,
        CrystalKey.frost,
        CrystalKey.dark,
        CrystalKey.ebony,
        CrystalKey.spirit,
      ]) {
        final w = worldWith(fighter())..give(key);
        expect(w.useCrystal(key, rng: rng).reason, RefusalReason.battleOnly);
        expect(w.countOf(key), 1);
      }
    });

    test('a crystal one does not have', () {
      final w = worldWith(fighter());
      expect(
        w.useCrystal(CrystalKey.energy, rng: rng).reason,
        RefusalReason.noneOwned,
      );
      expect(
        w.useCrystal('crystal.nope', rng: rng).reason,
        RefusalReason.unknownItem,
      );
    });
  });

  group('item tables', () {
    test('ten consumables and nine crystals in the original order', () {
      expect(
        [for (final c in consumableTable) c.key],
        [
          'item.hp_potion',
          'item.mp_potion',
          'item.antidote_herb',
          'item.awakening_herb',
          'item.revival_herb',
          'item.summon_scroll',
          'item.big_torch',
          'item.seeing_orb',
          'item.flying_boots',
          'item.warp_orb',
        ],
      );
      expect(
        [for (final c in crystalTable) c.key],
        [
          'crystal.flame',
          'crystal.frost',
          'crystal.dark',
          'crystal.ebony',
          'crystal.spirit',
          'crystal.summon',
          'crystal.energy',
          'crystal.chromatic',
          'crystal.ball',
        ],
      );
      expect(
        [for (final c in consumableTable) c.legacyId],
        [for (var i = 1; i <= 10; i++) i],
      );
      expect(
        [for (final c in crystalTable) c.legacyId],
        [for (var i = 1; i <= 9; i++) i],
      );
    });

    test('only herbs and potions are usable in battle', () {
      expect(
        [
          for (final c in consumableTable)
            if (c.usableInBattle) c.legacyId,
        ],
        [1, 2, 3, 4, 5],
      );
    });

    test('legacy numbers resolve to keys', () {
      expect(LoreWorld.legacyKey('weapon', 6), 'weapon.long_sword');
      expect(LoreWorld.legacyKey('shield', 4), 'shield.chromatic');
      expect(LoreWorld.legacyKey('armour', 5), 'armour.brigandine');
      expect(LoreWorld.legacyKey('item', 10), 'item.warp_orb');
      expect(LoreWorld.legacyKey('crystal', 7), 'crystal.energy');
      expect(LoreWorld.legacyKey('weapon', 99), isNull);
      expect(LoreWorld.legacyKey('nope', 1), isNull);
      final w = worldWith(fighter());
      expect(w.giveLegacy('weapon', 12), 1);
      expect(w.countOf('weapon.mace'), 1);
    });

    test('give and take respect the limits', () {
      final w = worldWith(fighter());
      expect(w.give(ItemKey.hpPotion, 300), 255);
      expect(w.give(ItemKey.hpPotion), 0);
      expect(w.take(ItemKey.hpPotion, 256), isFalse);
      expect(w.take(ItemKey.hpPotion, 255), isTrue);
      expect(w.countOf(ItemKey.hpPotion), 0);
      expect(w.give('nope.thing'), 0);
      expect(w.give(SupplyKey.food, 999), 255);
      expect(w.give(SupplyKey.arrows, 70000), 65535);
      expect(w.give(SupplyKey.gold, 5), 5);
      expect(w.limitOf(SupplyKey.food), 255);
      expect(w.limitOf(SupplyKey.gold), isNull);
      expect(w.limitOf('crystal.flame'), 255);
    });
  });
}
