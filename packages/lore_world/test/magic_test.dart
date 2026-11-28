import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

/// 치료 능력치가 [cure] 인 마법사.
Member healer({
  int cure = 100,
  int level = 5,
  int change = 100,
  int esp = 100,
}) {
  final m = mage(level: level, skills: [10, change, cure, 10, esp, 10]);
  return m;
}

void main() {
  group('who may cast', () {
    test('fighters other than the paladin belong to no magic family', () {
      final w = worldWith(fighter());
      expect(w.castCure(0, 1).reason, RefusalReason.notMagicFamily);
      expect(w.castChange(0, 1).reason, RefusalReason.notMagicFamily);
      expect(
        w.castFieldEsp(0, FieldEsp.prophecy).reason,
        RefusalReason.notMagicFamily,
      );
    });

    test('a paladin heals with the second skill slot and nothing else', () {
      final p = fighter(
        classId: ClassId.paladin,
        level: 5,
        skills: [25, 20, 5, 0, 20, 10],
      )..hp = 10;
      final w = worldWith(p);
      expect(w.availableCureSpells(0), [1, 2]);
      expect(w.castCure(0, 1).ok, isTrue);
      expect(p.hp, 110);
      expect(p.mp, 5 * 10 * 5 - 10);
      expect(w.castCure(0, 3).reason, RefusalReason.spellLocked);
      expect(w.castChange(0, 1).reason, RefusalReason.notMagicFamily);
    });

    test('a caster who cannot act cannot cast', () {
      final w = worldWith(healer()..unconscious = 1);
      expect(w.castCure(0, 1).reason, RefusalReason.casterCannotAct);
      expect(w.castChange(0, 1).reason, RefusalReason.casterCannotAct);
    });

    test('tiers unlock every ten points', () {
      expect(unlockedTiers(9), 0);
      expect(unlockedTiers(10), 1);
      expect(unlockedTiers(59), 5);
      expect(unlockedTiers(100), 10);
      expect(unlockedTiers(140), 10);
      final w = worldWith(healer(cure: 59));
      expect(w.availableCureSpells(0), [1, 2, 3, 4, 5]);
      expect(w.castCure(0, 6).reason, RefusalReason.spellLocked);
    });
  });

  group('cure magic on one', () {
    test('heal: level × 2 MP for level × 20 HP', () {
      final h = healer(level: 5);
      final w = worldWith(h);
      final hurt = fighter(level: 10)..hp = 1;
      w.join(hurt);
      final mp = h.mp;
      final out = w.castCure(0, 1, target: 1);
      expect(out.first<SpellCast>()!.mpSpent, 10);
      expect(out.first<HpRestored>()!.amount, 100);
      expect(hurt.hp, 101);
      expect(h.mp, mp - 10);
    });

    test(
      'heal refuses the poisoned, the unconscious, the dead and the healthy',
      () {
        final w = worldWith(healer());
        final t = fighter();
        w.join(t);
        expect(
          w.castCure(0, 1, target: 1).reason,
          RefusalReason.noTreatmentNeeded,
        );
        t.hp = 10;
        t.poison = 1;
        expect(
          w.castCure(0, 1, target: 1).reason,
          RefusalReason.targetNotCurable,
        );
        t.poison = 0;
        t.unconscious = 1;
        expect(
          w.castCure(0, 1, target: 1).reason,
          RefusalReason.targetNotCurable,
        );
        t.dead = 1;
        expect(
          w.castCure(0, 1, target: 1).reason,
          RefusalReason.targetNotCurable,
        );
      },
    );

    test('a refused spell costs nothing', () {
      final h = healer();
      final w = worldWith(h);
      final mp = h.mp;
      expect(w.castCure(0, 2).reason, RefusalReason.notPoisoned);
      expect(w.castCure(0, 3).reason, RefusalReason.notUnconscious);
      expect(w.castCure(0, 4).reason, RefusalReason.notDead);
      expect(h.mp, mp);
    });

    test('cure poison: 15 MP, not on the unconscious', () {
      final h = healer();
      final w = worldWith(h);
      final t = fighter()..poison = 6;
      w.join(t);
      final mp = h.mp;
      expect(w.castCure(0, 2, target: 1).has<PoisonCured>(), isTrue);
      expect(h.mp, mp - 15);
      t.poison = 2;
      t.unconscious = 1;
      expect(
        w.castCure(0, 2, target: 1).reason,
        RefusalReason.targetNotCurable,
      );
    });

    test('wake: 10 × the unconscious counter', () {
      final h = healer();
      final w = worldWith(h);
      final t = fighter()
        ..hp = 0
        ..unconscious = 7;
      w.join(t);
      final mp = h.mp;
      expect(w.castCure(0, 3, target: 1).has<Awakened>(), isTrue);
      expect(h.mp, mp - 70);
      expect(t.hp, 1);
      t.unconscious = 3;
      t.dead = 1;
      expect(
        w.castCure(0, 3, target: 1).reason,
        RefusalReason.targetNotCurable,
      );
    });

    test('revive: 30 × the death counter, back as unconscious', () {
      final h = healer(level: 10);
      final w = worldWith(h);
      final t = fighter()
        ..hp = 0
        ..unconscious = 99
        ..dead = 4;
      w.join(t);
      final mp = h.mp;
      expect(w.castCure(0, 4, target: 1).has<Revived>(), isTrue);
      expect(h.mp, mp - 120);
      expect(t.dead, 0);
      expect(t.unconscious, 10);
    });

    test('not enough MP is refused and nothing changes', () {
      final h = healer(level: 1)..mp = 20;
      final w = worldWith(h);
      final t = fighter()
        ..hp = 0
        ..unconscious = 3;
      w.join(t);
      expect(w.castCure(0, 3, target: 1).reason, RefusalReason.notEnoughMp);
      expect(t.unconscious, 3);
      expect(h.mp, 20);
    });

    test('the full cure goes deepest first and charges each step', () {
      final h = healer(level: 10);
      final w = worldWith(h);
      final t = fighter(level: 2)
        ..hp = 0
        ..poison = 5
        ..unconscious = 8
        ..dead = 3;
      w.join(t);
      final mp = h.mp;
      final out = w.castCure(0, 5, target: 1);
      expect(out.ok, isTrue);
      expect(out.events.map((e) => e.kind).toList(), [
        'spellCast',
        'revived',
        'awakened',
        'poisonCured',
        'hpRestored',
      ]);
      // 부활 30×3 + 의식 10×8 + 독 15 + 치료 10×2.
      expect(mp - h.mp, 90 + 80 + 15 + 20);
      expect(t.condition, Condition.good);
      // 깨어난 HP 1 + 시전자 레벨 × 20 = 201 이지만 최대치(200)에서 멈춘다.
      expect(t.hp, 200);
    });

    test('the full cure stops where the MP runs out', () {
      final h = healer(level: 10)..mp = 100;
      final w = worldWith(h);
      final t = fighter()
        ..hp = 0
        ..unconscious = 5
        ..dead = 3;
      w.join(t);
      // 부활 90 은 되고, 의식 돌림 50 은 모자란다.
      final out = w.castCure(0, 5, target: 1);
      expect(out.ok, isTrue);
      expect(out.has<Revived>(), isTrue);
      expect(out.has<Awakened>(), isFalse);
      expect(h.mp, 10);
      expect(t.condition, Condition.unconscious);
    });

    test('the full cure on the healthy has nothing to do', () {
      final w = worldWith(healer());
      expect(w.castCure(0, 5).reason, RefusalReason.noTreatmentNeeded);
    });
  });

  group('cure magic on all', () {
    test('needs a cure level of six or more', () {
      final w = worldWith(healer(cure: 59));
      expect(w.castCure(0, 6).reason, RefusalReason.spellLocked);
    });

    test('charges per target and skips those it cannot help', () {
      final h = healer(level: 5)..hp = 10;
      final w = worldWith(h);
      w.join(fighter()..hp = 50);
      w.join(fighter()..poison = 1);
      w.setAssistant(fighter(name: 'Aide')..hp = 1);
      final mp = h.mp;
      final out = w.castCure(0, 6);
      expect(out.ok, isTrue);
      // 시전자·1번·보조 일원이 치료되고, 중독된 2번은 건너뛴다.
      expect(out.of<HpRestored>().map((e) => e.seat), [0, 1, 5]);
      expect(out.of<NoEffect>().single.seat, 2);
      expect(out.of<NoEffect>().single.reason, RefusalReason.targetNotCurable);
      expect(mp - h.mp, 30);
    });

    test('the full cure for all reaches the dead assistant too', () {
      final h = healer(level: 20);
      final w = worldWith(h);
      w.setAssistant(
        fighter(name: 'Aide')
          ..hp = 0
          ..unconscious = 2
          ..dead = 1,
      );
      final out = w.castCure(0, 10);
      expect(out.of<Revived>().single.seat, 5);
      expect(w.assistant!.condition, Condition.good);
    });
  });

  group('change magic', () {
    test('MP costs and unlock thresholds match the table', () {
      expect(
        [for (var i = 1; i <= 10; i++) spellAt(SpellSchool.change, i)!.mp],
        [1, 5, 5, 10, 20, 25, 30, 50, 30, 60],
      );
      expect(
        [for (var i = 1; i <= 10; i++) spellAt(SpellSchool.change, i)!.unlock],
        [for (var i = 1; i <= 10; i++) i * 10],
      );
    });

    test('the magic torch adds change skill ÷ 10', () {
      final w = worldWith(healer(change: 70));
      final mp = w.protagonist!.mp;
      final out = w.castChange(0, 1);
      expect(out.first<TorchChanged>()!.delta, 7);
      expect(w.torch, 11);
      expect(w.protagonist!.mp, mp - 1);
      w.setTorch(252);
      w.castChange(0, 1);
      expect(w.torch, 255);
    });

    test('levitation, water walk and swamp walk switch on a party effect', () {
      final w = worldWith(healer());
      expect(w.castChange(0, 3).first<BuffsGranted>()!.buffs, [
        FieldBuff.levitation,
      ]);
      expect(w.castChange(0, 4).first<BuffsGranted>()!.buffs, [
        FieldBuff.waterWalk,
      ]);
      expect(w.castChange(0, 5).first<BuffsGranted>()!.buffs, [
        FieldBuff.swampWalk,
      ]);
      expect(w.buffs.levitation, 255);
      expect(w.buffs.waterWalk, 255);
      expect(w.buffs.swampWalk, 255);
    });

    test('map spells only say what should happen', () {
      final w = worldWith(healer());
      expect(w.castChange(0, 2).mapAction!.action, MapAction.showMap);
      expect(w.castChange(0, 6).mapAction!.action, MapAction.etherealMove);
      expect(w.castChange(0, 7).mapAction!.action, MapAction.terraform);
      expect(w.castChange(0, 10).mapAction!.action, MapAction.greatTerraform);
      final t = w.castChange(0, 8);
      expect(t.mapAction!.action, MapAction.teleport);
      expect(t.mapAction!.distance, 5);
      expect(w.castChange(0, 8, distance: 1).mapAction!.distance, 1);
      expect(
        w.castChange(0, 8, distance: 0).reason,
        RefusalReason.invalidAmount,
      );
      expect(
        w.castChange(0, 8, distance: 10).reason,
        RefusalReason.invalidAmount,
      );
    });

    test('create food adds one per member, up to 255', () {
      final w = worldWith(healer());
      w.join(fighter());
      w.setAssistant(fighter(name: 'Aide'));
      final out = w.castChange(0, 9);
      expect(out.first<FoodCreated>()!.added, 3);
      expect(w.food, 3);
      w.food = 254;
      expect(w.castChange(0, 9).first<FoodCreated>()!.added, 1);
      expect(w.food, 255);
    });

    test('checking changes nothing; casting pays', () {
      final w = worldWith(healer());
      final mp = w.protagonist!.mp;
      expect(w.checkChange(0, 8), isNull);
      expect(w.protagonist!.mp, mp);
      w.castChange(0, 8);
      expect(w.protagonist!.mp, mp - 50);
    });

    test('refusals: locked tier, no MP, bad number', () {
      final w = worldWith(healer(change: 59));
      expect(w.availableChangeSpells(0), [1, 2, 3, 4, 5]);
      expect(w.castChange(0, 6).reason, RefusalReason.spellLocked);
      w.protagonist!.mp = 19;
      expect(w.castChange(0, 5).reason, RefusalReason.notEnoughMp);
      expect(w.buffs.canWalkOnSwamp, isFalse);
      expect(w.castChange(0, 0).reason, RefusalReason.invalidAmount);
      expect(w.castChange(0, 11).reason, RefusalReason.invalidAmount);
    });
  });

  group('field ESP', () {
    test(
      'thresholds: prophecy 10, mind reading 40, far sight 55, clairvoyance 70',
      () {
        RefusalReason? at(int esp, FieldEsp p) =>
            worldWith(healer(esp: esp)).checkFieldEsp(0, p);
        expect(at(9, FieldEsp.prophecy), RefusalReason.espTooWeak);
        expect(at(10, FieldEsp.prophecy), isNull);
        expect(at(39, FieldEsp.mindReading), RefusalReason.espTooWeak);
        expect(at(40, FieldEsp.mindReading), isNull);
        expect(at(54, FieldEsp.farSight), RefusalReason.espTooWeak);
        expect(at(55, FieldEsp.farSight), isNull);
        expect(at(69, FieldEsp.clairvoyance), RefusalReason.espTooWeak);
        expect(at(70, FieldEsp.clairvoyance), isNull);
      },
    );

    test('mind reading really spends 20 MP and lasts three steps', () {
      final w = worldWith(healer());
      final mp = w.protagonist!.mp;
      final out = w.castFieldEsp(0, FieldEsp.mindReading);
      expect(out.first<MindReadingStarted>()!.steps, 3);
      expect(w.protagonist!.mp, mp - 20);
      expect(w.buffs.mindReadSteps, 3);
      expect(w.isMindReading, isTrue);
    });

    test('far sight costs level × 5 and looks level tiles ahead', () {
      final w = worldWith(healer(level: 8));
      final mp = w.protagonist!.mp;
      final out = w.castFieldEsp(0, FieldEsp.farSight);
      expect(out.mapAction!.action, MapAction.farSight);
      expect(out.mapAction!.distance, 8);
      expect(w.protagonist!.mp, mp - 40);
    });

    test('clairvoyance and prophecy are handed to the map side', () {
      final w = worldWith(healer());
      final mp = w.protagonist!.mp;
      expect(
        w.castFieldEsp(0, FieldEsp.clairvoyance).mapAction!.action,
        MapAction.revealHidden,
      );
      expect(
        w.castFieldEsp(0, FieldEsp.prophecy).mapAction!.action,
        MapAction.prophecy,
      );
      expect(w.protagonist!.mp, mp - 15);
    });

    test('telekinesis is for battle only', () {
      final w = worldWith(healer());
      expect(
        w.castFieldEsp(0, FieldEsp.telekinesis).reason,
        RefusalReason.battleOnly,
      );
    });

    test('no MP, no power', () {
      final w = worldWith(healer()..mp = 4);
      expect(
        w.castFieldEsp(0, FieldEsp.prophecy).reason,
        RefusalReason.notEnoughMp,
      );
    });

    test('anyoneHasEsp answers the Part 1 join condition', () {
      final w = worldWith(fighter());
      expect(w.anyoneHasEsp(40), isFalse);
      w.join(healer(esp: 40));
      expect(w.anyoneHasEsp(40), isTrue);
      expect(w.anyoneHasEsp(41), isFalse);
    });
  });

  group('spell data', () {
    test('ten per school', () {
      for (final school in [
        SpellSchool.attackOne,
        SpellSchool.attackAll,
        SpellSchool.change,
        SpellSchool.cure,
        SpellSchool.summon,
      ]) {
        expect(spellsOf(school).length, 10, reason: school.name);
      }
      // 특수 마법은 열 가지 + 제1부 전용 「독」.
      expect(spellsOf(SpellSchool.special).length, 11);
      expect(spellByKey('magic.poison')!.onlyIn, Episode.ep1);
      expect(spellsOf(SpellSchool.esp).length, 9);
    });

    test('keys are unique', () {
      final keys = [for (final s in spellTable) s.key];
      expect(keys.toSet().length, keys.length);
    });

    test('attack magic: MP = skill × j² ÷ 10, damage = j² × skill × 3', () {
      expect(attackMagicMp(100, 1), 10);
      expect(attackMagicMp(100, 10), 1000);
      expect(attackMagicMp(15, 1), 2);
      expect(attackMagicMp(14, 1), 1);
      expect(attackMagicDamage(100, 10), 30000);
      expect(attackMagicDamage(100, 4), 4800);
    });

    test(
      'special magic costs 200 / 50 / 100 / 150 / 400, the same for all',
      () {
        expect(
          [for (var i = 1; i <= 10; i++) spellAt(SpellSchool.special, i)!.mp],
          [200, 50, 100, 150, 400, 200, 50, 100, 150, 400],
        );
      },
    );

    test('ESP thresholds and costs', () {
      SpellDef s(String k) => spellByKey(k)!;
      expect(s('esp.mind_reading').mp, 20);
      expect(s('esp.mind_reading').battleMp, 15);
      expect(s('esp.hydrogen_fusion').unlock, 20);
      expect(s('esp.fear').unlock, 30);
      expect(s('esp.illusion').mp, 300);
      expect(s('esp.metabolism').mp, 500);
      expect(s('esp.astral_projection').unlock, 100);
      expect(s('esp.astral_projection').mp, 1000);
    });

    test('summon cost follows the attack formula; level is skill ÷ 5', () {
      expect(summonMagicMp(100, 10), 1000);
      expect(summonLevel(100), 20);
      expect(summonLevel(10), 2);
    });

    test('telekinesis choices by ESP', () {
      expect(telekinesisChoices(19), 0);
      expect(telekinesisChoices(20), 1);
      expect(telekinesisChoices(30), 2);
      expect(telekinesisChoices(79), 2);
      expect(telekinesisChoices(80), 3);
      expect(telekinesisChoices(90), 4);
      expect(telekinesisChoices(100), 5);
    });
  });
}
