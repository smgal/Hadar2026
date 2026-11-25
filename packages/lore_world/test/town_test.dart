import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('grocery', () {
    test('ten portions for 100 gold', () {
      final w = worldWith(fighter())..gold = 500;
      final out = w.buyFood(3);
      final e = out.first<Purchased>()!;
      expect(e.key, SupplyKey.food);
      expect(e.count, 30);
      expect(e.cost, 300);
      expect(w.food, 30);
      expect(w.gold, 200);
    });

    test('only 10 to 50 portions are on the menu', () {
      final w = worldWith(fighter())..gold = 9999;
      expect(w.buyFood(0).reason, RefusalReason.invalidAmount);
      expect(w.buyFood(6).reason, RefusalReason.invalidAmount);
    });

    test('not enough gold changes nothing', () {
      final w = worldWith(fighter())..gold = 99;
      final out = w.buyFood(1);
      expect(out.reason, RefusalReason.notEnoughGold);
      expect(out.refusal!.amount, 1);
      expect(w.food, 0);
      expect(w.gold, 99);
    });

    test('food stops at 255 and only what fits is paid for', () {
      final w = worldWith(fighter())
        ..gold = 1000
        ..food = 250;
      final out = w.buyFood(5);
      expect(out.first<Purchased>()!.count, 5);
      expect(out.first<Purchased>()!.cost, 50);
      expect(w.food, 255);
      expect(w.gold, 950);
      expect(w.buyFood(1).reason, RefusalReason.atLimit);
      expect(w.gold, 950);
    });
  });

  group('weapon shop', () {
    test('sells one piece into the backpack', () {
      final w = worldWith(fighter())..gold = 6000;
      expect(w.buyEquipment('weapon.sabre').ok, isTrue);
      expect(w.gold, 1000);
      expect(w.countOf('weapon.sabre'), 1);
      expect(w.protagonist!.weapon, isNull);
      expect(
        w.buyEquipment('weapon.sabre').reason,
        RefusalReason.notEnoughGold,
      );
    });

    test('prices come from chapter 10', () {
      final w = worldWith(fighter());
      expect(w.priceOf('weapon.dagger'), 100);
      expect(w.priceOf('weapon.halberd'), 100000);
      expect(w.priceOf('shield.platinum'), 150000);
      expect(w.priceOf('armour.platinum'), 500000);
      expect(w.priceOf('item.revival_herb'), 10000);
    });

    test('the obsidian armour is not for sale', () {
      final w = worldWith(fighter())..gold = 9999999;
      expect(w.isForSale('armour.obsidian'), isFalse);
      expect(w.priceOf('armour.obsidian'), isNull);
      expect(
        w.buyEquipment('armour.obsidian').reason,
        RefusalReason.notForSale,
      );
    });

    test('the flame sword is sold in Part 1 only', () {
      final ep3 = worldWith(fighter())..gold = 200000;
      expect(
        ep3.buyEquipment('weapon.flame_sword').reason,
        RefusalReason.notForSale,
      );
      final ep1 = worldWith(fighter(), episode: Episode.ep1)..gold = 200000;
      expect(ep1.buyEquipment('weapon.flame_sword').ok, isTrue);
      expect(ep1.gold, 100000);
    });

    test('a stack of 255 is the limit', () {
      final w = worldWith(fighter())
        ..gold = 1000
        ..give('weapon.dagger', 255);
      expect(w.buyEquipment('weapon.dagger').reason, RefusalReason.atLimit);
      expect(w.gold, 1000);
    });

    test('an unknown key is refused', () {
      final w = worldWith(fighter())..gold = 1000;
      expect(w.buyEquipment('weapon.nope').reason, RefusalReason.unknownItem);
      expect(
        w.buyEquipment('item.hp_potion').reason,
        RefusalReason.unknownItem,
      );
    });
  });

  group('herb and goods shops', () {
    test('one to ten at a time', () {
      final w = worldWith(fighter())..gold = 50000;
      final out = w.buyConsumable(ItemKey.hpPotion, 10, shop: ShopKind.herb);
      expect(out.first<Purchased>()!.cost, 20000);
      expect(w.countOf(ItemKey.hpPotion), 10);
      expect(
        w.buyConsumable(ItemKey.hpPotion, 11).reason,
        RefusalReason.invalidAmount,
      );
      expect(
        w.buyConsumable(ItemKey.hpPotion, 0).reason,
        RefusalReason.invalidAmount,
      );
    });

    test('each shop sells its own five', () {
      expect(
        [
          for (final c in consumableTable)
            if (c.shop == ShopKind.herb) c.legacyId,
        ],
        [1, 2, 3, 4, 5],
      );
      expect(
        [
          for (final c in consumableTable)
            if (c.shop == ShopKind.goods) c.legacyId,
        ],
        [6, 7, 8, 9, 10],
      );
      final w = worldWith(fighter())..gold = 50000;
      expect(
        w.buyConsumable(ItemKey.warpOrb, 1, shop: ShopKind.herb).reason,
        RefusalReason.wrongShop,
      );
      expect(
        w.buyConsumable(ItemKey.warpOrb, 1, shop: ShopKind.goods).ok,
        isTrue,
      );
    });

    test('prices of the ten', () {
      expect(
        [for (final c in consumableTable) c.price],
        [2000, 3000, 1000, 5000, 10000, 4000, 300, 500, 1000, 5000],
      );
    });

    test('a stack stops at 255 and only what fits is paid for', () {
      final w = worldWith(fighter())
        ..gold = 10000
        ..give(ItemKey.bigTorch, 250);
      final out = w.buyConsumable(ItemKey.bigTorch, 10);
      expect(out.first<Purchased>()!.count, 5);
      expect(out.first<Purchased>()!.cost, 1500);
      expect(w.countOf(ItemKey.bigTorch), 255);
      expect(
        w.buyConsumable(ItemKey.bigTorch, 1).reason,
        RefusalReason.atLimit,
      );
    });

    test('arrows come in tens for 500, up to a hundred at once', () {
      final w = worldWith(fighter())..gold = 5000;
      final out = w.buyArrows(10);
      expect(out.first<Purchased>()!.count, 100);
      expect(out.first<Purchased>()!.cost, 5000);
      expect(w.arrows, 100);
      expect(w.buyArrows(11).reason, RefusalReason.invalidAmount);
      expect(w.buyArrows(1).reason, RefusalReason.notEnoughGold);
    });

    test('arrows stop at 65,535 instead of wrapping round', () {
      final w = worldWith(fighter())
        ..gold = 100000
        ..arrows = 65530;
      final out = w.buyArrows(10);
      expect(out.first<Purchased>()!.count, 5);
      expect(w.arrows, 65535);
      expect(w.buyArrows(1).reason, RefusalReason.atLimit);
    });
  });

  group('hospital', () {
    test('wounds: round((max − hp) × level ÷ 10) + 1', () {
      final m = fighter(level: 3)..hp = 100;
      final w = worldWith(m)..gold = 1000;
      // (300 − 100) × 3 ÷ 10 + 1 = 61.
      expect(w.hospitalFee(0, Treatment.wounds), 61);
      final out = w.hospitalTreat(0, Treatment.wounds);
      expect(out.first<HospitalTreated>()!.fee, 61);
      expect(m.hp, 300);
      expect(w.gold, 939);
    });

    test('wounds fee rounds half up', () {
      final m = fighter(level: 1)..hp = 95;
      final w = worldWith(m);
      // 5 × 1 ÷ 10 = 0.5 → 1, +1.
      expect(w.treatmentFee(m, Treatment.wounds), 2);
      m.hp = 96;
      expect(w.treatmentFee(m, Treatment.wounds), 1);
    });

    test('poison: level × 10', () {
      final m = fighter(level: 7)..poison = 4;
      final w = worldWith(m)..gold = 100;
      expect(w.hospitalFee(0, Treatment.poison), 70);
      expect(w.hospitalTreat(0, Treatment.poison).has<PoisonCured>(), isTrue);
      expect(m.poison, 0);
      expect(w.gold, 30);
    });

    test('consciousness: counter × 2, back with 1 HP', () {
      final m = fighter()
        ..hp = 0
        ..unconscious = 9;
      final w = worldWith(m)..gold = 100;
      expect(w.hospitalFee(0, Treatment.consciousness), 18);
      expect(
        w.hospitalTreat(0, Treatment.consciousness).has<Awakened>(),
        isTrue,
      );
      expect(m.unconscious, 0);
      expect(m.hp, 1);
      expect(w.gold, 82);
    });

    test('revival: counter × 100 + 400, back as unconscious', () {
      final m = fighter()
        ..hp = 0
        ..unconscious = 30
        ..dead = 6;
      final w = worldWith(m)..gold = 1000;
      expect(w.hospitalFee(0, Treatment.revival), 1000);
      expect(w.hospitalTreat(0, Treatment.revival).has<Revived>(), isTrue);
      expect(m.dead, 0);
      // 의식불명 수치는 인내력 × 레벨로 제한된다.
      expect(m.unconscious, 10);
      expect(m.condition, Condition.unconscious);
      expect(w.gold, 0);
    });

    test('deepest first — each treatment refuses a graver state', () {
      final w = worldWith(fighter());
      final m = w.protagonist!;

      m.dead = 1;
      expect(
        w.hospitalTreat(0, Treatment.wounds).reason,
        RefusalReason.alreadyDead,
      );
      expect(
        w.hospitalTreat(0, Treatment.poison).reason,
        RefusalReason.alreadyDead,
      );
      expect(
        w.hospitalTreat(0, Treatment.consciousness).reason,
        RefusalReason.alreadyDead,
      );

      m.dead = 0;
      m.unconscious = 2;
      expect(
        w.hospitalTreat(0, Treatment.wounds).reason,
        RefusalReason.alreadyUnconscious,
      );
      expect(
        w.hospitalTreat(0, Treatment.poison).reason,
        RefusalReason.alreadyUnconscious,
      );

      m.unconscious = 0;
      m.poison = 1;
      m.hp = 10;
      expect(
        w.hospitalTreat(0, Treatment.wounds).reason,
        RefusalReason.poisonSpreading,
      );
    });

    test('nothing to treat is said so, and costs nothing', () {
      final w = worldWith(fighter())..gold = 500;
      for (final t in Treatment.values) {
        expect(w.hospitalTreat(0, t).reason, RefusalReason.noTreatmentNeeded);
        expect(w.hospitalFee(0, t), isNull);
      }
      expect(w.gold, 500);
    });

    test('no gold, no treatment', () {
      final m = fighter()..dead = 1;
      final w = worldWith(m)..gold = 499;
      final out = w.hospitalTreat(0, Treatment.revival);
      expect(out.reason, RefusalReason.notEnoughGold);
      expect(out.refusal!.amount, 1);
      expect(m.dead, 1);
    });

    test('the whole road back: revive, wake, cure, heal', () {
      final m = fighter(level: 2)
        ..hp = 0
        ..poison = 3
        ..unconscious = 5
        ..dead = 2;
      final w = worldWith(m)..gold = 100000;
      expect(w.hospitalTreat(0, Treatment.revival).ok, isTrue);
      expect(w.hospitalTreat(0, Treatment.consciousness).ok, isTrue);
      expect(w.hospitalTreat(0, Treatment.poison).ok, isTrue);
      expect(w.hospitalTreat(0, Treatment.wounds).ok, isTrue);
      expect(m.condition, Condition.good);
      expect(m.hp, m.maxHp);
    });
  });
}
