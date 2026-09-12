import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_bridge/hd_bridge.dart';
import 'package:hd_world/hd_world.dart' as hw;
import 'package:test/test.dart';

hw.World sample() => hw.World(
  members: [for (final t in hw.sampleParty) t.build()],
  pack: hw.Pack(
    capacity: 40,
    counts: {
      for (final e in hw.samplePack.entries) hw.ItemRef(e.key): e.value,
    },
  ),
);

void main() {
  group('every style the world can name has a battle row', () {
    test('nothing falls back to bare hands by accident', () {
      // The gap this closes: the battle had no missile weapons at all,
      // so a hunter holding a bow could not be handed over.
      for (final style in hw.WeaponKind.values) {
        for (final kind in hw.ItemKind.values) {
          for (final shape in [null, ...hw.WeaponShape.values]) {
            final key = weaponKeyFor(
              style: style,
              mainHandKind: kind,
              mainHandShape: shape,
            );
            expect(
              battleKnowsWeapon(key),
              isTrue,
              reason: '${style.name}/${kind.name}/${shape?.name} -> $key',
            );
            // Only two things are allowed to resolve to bare hands: the
            // unarmed style, and a summoned creature's natural attack.
            final naturalWeapon =
                kind == hw.ItemKind.summonSingle ||
                kind == hw.ItemKind.summonMulti;
            if (style != hw.WeaponKind.unarmed &&
                kind.isWeapon &&
                !naturalWeapon) {
              expect(
                key,
                isNot('unarmed'),
                reason: '${style.name}/${kind.name}/${shape?.name}',
              );
            }
          }
        }
      }
    });

    test('every weapon in the catalogue reaches a real battle row', () {
      final catalog = hw.ItemCatalog.builtIn;
      for (final def in catalog.all.where((d) => d.kind.isWeapon)) {
        final style = hw.weaponKindFor(right: def);
        final key = weaponKeyFor(
          style: style,
          mainHandKind: def.kind,
          mainHandShape: def.shape,
        );
        expect(battleKnowsWeapon(key), isTrue, reason: def.ref.value);
        // And the reach it gets is the one the style promises.
        final profile = hb.weaponFor(key);
        expect(profile.attacks, isNotEmpty, reason: def.ref.value);
      }
    });

    test('the missile weapons keep their reach', () {
      int reach(String ref) {
        final def = hw.ItemCatalog.builtIn[hw.ItemRef(ref)]!;
        return hb
            .weaponFor(
              weaponKeyFor(
                style: hw.weaponKindFor(right: def),
                mainHandKind: def.kind,
                mainHandShape: def.shape,
              ),
            )
            .longestReach;
      }

      expect(reach('weapon.bow'), 3);
      expect(reach('weapon.crossbow'), 3);
      expect(reach('weapon.arbalest'), 3);
      expect(reach('weapon.javelin'), 2);
      expect(reach('weapon.dagger'), 1);
      expect(reach('weapon.long_sword'), 2);
      expect(reach('weapon.lancer'), 3);
    });

    test('a shield turns a sword into two ways to strike', () {
      final sword = hw.ItemCatalog.builtIn[const hw.ItemRef('weapon.sabre')]!;
      final shield =
          hw.ItemCatalog.builtIn[const hw.ItemRef('shield.leather')]!;
      final alone = weaponKeyFor(
        style: hw.weaponKindFor(right: sword),
        mainHandKind: sword.kind,
        mainHandShape: sword.shape,
      );
      final paired = weaponKeyFor(
        style: hw.weaponKindFor(right: sword, left: shield),
        mainHandKind: sword.kind,
        mainHandShape: sword.shape,
      );
      expect(hb.weaponFor(alone).attacks.length, 1);
      expect(hb.weaponFor(paired).attacks.length, 2);
      expect(
        hb.weaponFor(paired).attacks.last.method,
        hb.AttackMethod.blunt,
        reason: 'the shield is the answer to bone and stone',
      );
    });
  });

  group('standing orders', () {
    test('every style maps, and the collapses are the documented two', () {
      final byPreset = <hb.PresetKind, List<hw.FightingStyle>>{};
      for (final style in hw.FightingStyle.values) {
        byPreset.putIfAbsent(presetFor(style), () => []).add(style);
      }
      final collapsed = {
        for (final e in byPreset.entries)
          if (e.value.length > 1) e.key: e.value.map((s) => s.name).toSet(),
      };
      expect(collapsed, {
        hb.PresetKind.caster: {'volley', 'firepower'},
        hb.PresetKind.skirmisher: {'skirmish', 'disrupt'},
      });
    });

    test('a class knows exactly the presets its styles map to', () {
      expect(
        knownPresetsFor(hw.CharacterClass.knight),
        {hb.PresetKind.guardian, hb.PresetKind.aggressive, hb.PresetKind.skirmisher},
      );
      expect(
        knownPresetsFor(hw.CharacterClass.monk),
        {hb.PresetKind.aggressive, hb.PresetKind.skirmisher},
      );
    });
  });

  group('consumables', () {
    test('the two catalogues agree, both ways', () {
      // The convention is the reference name. If either side grows a row
      // the other does not have, this is where it shows.
      final worldKeys = {
        for (final d in hw.ItemCatalog.builtIn.ofKind(hw.ItemKind.consumable))
          battleKeyOf(d.ref),
      };
      expect(worldKeys, isNot(contains(null)));
      expect(worldKeys.cast<String>(), hb.battleItems.keys.toSet());
    });

    test('only consumables project, and the count comes along', () {
      final world = sample();
      final held = heldConsumables(world.pack);
      expect(held['potion'], 3);
      expect(held['poison_vial'], 2);
      expect(held.containsKey('sabre'), isFalse);
      expect(held.keys.every(hb.battleItems.containsKey), isTrue);
    });

    test('what was spent comes back as commands, not as a mutation', () {
      final world = sample();
      final commands = spendCommands({'potion': 2});
      expect(world.pack.countOf(const hw.ItemRef('consumable.potion')), 3);
      for (final c in commands) {
        expect(world.apply(c), [isA<hw.ItemLost>()]);
      }
      expect(world.pack.countOf(const hw.ItemRef('consumable.potion')), 1);
    });
  });

  group('empty seats', () {
    test('an absent member does not fight and nobody is renumbered', () {
      // Shipped scripts configure the sixth seat for somebody who joins
      // later, so a filtered list must not shift the seats.
      final world = hw.World(
        members: [
          hw.sampleParty.first.build(),
          hw.Member(ref: const hw.MemberRef('empty1'), name: ''),
          hw.sampleParty[2].build(),
          hw.Member(ref: const hw.MemberRef('empty3'), name: ''),
        ],
      );
      final setup = toBattleSetup(world, enemyKeys: const ['orc'], seed: 1);
      expect([for (final p in setup.party) p.slot], [0, 2]);
      expect(setup.partyCapacity, 4, reason: 'the roster, not the head count');
    });

    test('a result finds its seat even with gaps', () {
      final world = hw.World(
        members: [
          hw.Member(ref: const hw.MemberRef('empty0'), name: ''),
          hw.sampleParty.first.build(),
        ],
      );
      final settlement = settle(
        world,
        const hb.BattleOutcome(
          resultCode: hb.BattleResultCode.win,
          goldGained: 0,
          combatants: [
            hb.CombatantResult(
              slot: 1,
              hp: 7,
              sp: 0,
              esp: 0,
              poison: 0,
              unconscious: 0,
              dead: 0,
              experienceGained: 5,
            ),
          ],
        ),
      );
      expect(world.members[1].hitPoints, 7);
      expect(world.members[1].experience, 5);
      expect(settlement.experience.keys.single.value, 'knight');
    });
  });

  group('what the style adds beyond reach', () {
    test('a pair of weapons crosses over as two blows and two coatings', () {
      final world = sample();
      // 샤벨 in the main hand, dagger in the off hand: same class, so
      // they pair.
      world.apply(
        const hw.EquipFromPack(
          member: hw.MemberRef('knight'),
          slot: hw.EquipSlot.leftHand,
          item: hw.ItemRef('weapon.dagger'),
        ),
      );
      final setup = toBattleSetup(world, enemyKeys: const ['orc'], seed: 1);
      final knight = setup.party.first;
      expect(knight.strikes, 2);
      expect(knight.coatingSlots, 2);
      // Averaged, not summed — the style already strikes twice.
      expect(knight.powOfWeapon, (35 + 15) ~/ 2);
    });

    test('a free hand crosses over as evasion, a crossbow as slowness', () {
      final world = sample();
      // Take the shield off: one weapon, free hand.
      world.apply(
        const hw.UnequipToPack(
          member: hw.MemberRef('knight'),
          slot: hw.EquipSlot.leftHand,
        ),
      );
      world.apply(
        const hw.EquipFromPack(
          member: hw.MemberRef('paladin'),
          slot: hw.EquipSlot.rightHand,
          item: hw.ItemRef('weapon.crossbow'),
        ),
      );
      final setup = toBattleSetup(world, enemyKeys: const ['orc'], seed: 1);
      expect(setup.party.first.evasionBonus, 4);
      expect(setup.party.first.initiativeBonus, 5);
      final crossbow = setup.party[1];
      expect(crossbow.weaponKey, 'crossbow');
      expect(crossbow.initiativeBonus, -2);
    });

    test('a torch fills the hand, so the light style pays for it', () {
      final world = sample();
      world.apply(
        const hw.UnequipToPack(
          member: hw.MemberRef('knight'),
          slot: hw.EquipSlot.leftHand,
        ),
      );
      final free = toBattleSetup(world, enemyKeys: const ['orc'], seed: 1)
          .party
          .first;
      world.apply(
        const hw.EquipFromPack(
          member: hw.MemberRef('knight'),
          slot: hw.EquipSlot.leftHand,
          item: hw.ItemRef('light.torch'),
        ),
      );
      final lit = toBattleSetup(world, enemyKeys: const ['orc'], seed: 1)
          .party
          .first;
      expect(free.evasionBonus, 4);
      expect(lit.evasionBonus, 0, reason: '보는 값을 손으로 낸다');
      expect(lit.strikes, 1);
    });

    test('an amulet and a style add up rather than fighting', () {
      final world = sample();
      world.apply(
        const hw.UnequipToPack(
          member: hw.MemberRef('knight'),
          slot: hw.EquipSlot.leftHand,
        ),
      );
      world.apply(const hw.GiveItem(item: hw.ItemRef('commonAmulet.wind')));
      final events = world.apply(
        const hw.EquipFromPack(
          member: hw.MemberRef('knight'),
          slot: hw.EquipSlot.commonAmulet,
          item: hw.ItemRef('commonAmulet.wind'),
        ),
      );
      expect(events.whereType<hw.CommandRefused>(), isEmpty);
      final setup = toBattleSetup(world, enemyKeys: const ['orc'], seed: 1);
      expect(setup.party.first.evasionBonus, 4 + 3);
    });
  });

  group('a whole fight, end to end', () {
    test('the party becomes an opening input', () {
      final world = sample();
      final setup = toBattleSetup(
        world,
        enemyKeys: const ['orc', 'orc', 'wolf'],
        seed: 7,
      );
      expect(setup.party.length, 5);
      // Slot is the position in the party, and the battle derives the
      // opening rank from it.
      expect([for (final p in setup.party) p.slot], [0, 1, 2, 3, 4]);
      expect([for (final p in setup.party) p.rank], [1, 1, 2, 2, 3]);
      final hunter = setup.party[4];
      expect(hunter.weaponKey, 'bow');
      expect(hunter.powOfWeapon, 45);
      final knight = setup.party.first;
      expect(knight.weaponKey, 'sword_shield');
      expect(knight.shieldBlock, 10);
      expect(knight.preset, hb.PresetKind.guardian);
    });

    test('the fight runs to an end and the party carries the marks', () {
      final world = sample();
      final before = [for (final m in world.members) m.hitPoints];
      final battle = hb.Battle(
        toBattleSetup(
          world,
          enemyKeys: const ['orc', 'orc', 'wolf'],
          seed: 7,
        ),
      );
      var guard = 0;
      while (!battle.isFinished && guard++ < 4000) {
        final decision = battle.pendingDecision;
        if (decision == null) {
          battle.advance();
          continue;
        }
        battle.applyCommand(switch (decision) {
          hb.ActionDecision() => hb.ChooseAction(
            decision.slot,
            hb.BattleAction.attack,
          ),
          hb.EnemyTargetDecision() => hb.ChooseEnemyTarget(
            decision.slot,
            decision.enemyIndices.first,
          ),
          _ => hb.CancelChoice(decision.slot),
        });
      }
      expect(battle.isFinished, isTrue);
      final settlement = settle(world, battle.outcome!);
      final after = [for (final m in world.members) m.hitPoints];
      expect(after, isNot(before), reason: 'a fight has to leave a mark');
      expect(settlement.experience, isNotEmpty);
      expect(settlement.departed, isEmpty);
      for (final command in settlement.commands) {
        expect(world.apply(command).whereType<hw.CommandRefused>(), isEmpty);
      }
    });

    test('a fight the party wins reports experience per member reference', () {
      final world = sample();
      final battle = hb.Battle(
        toBattleSetup(world, enemyKeys: const ['orc'], seed: 3),
      );
      var guard = 0;
      while (!battle.isFinished && guard++ < 2000) {
        final decision = battle.pendingDecision;
        if (decision == null) {
          battle.advance();
          continue;
        }
        battle.applyCommand(switch (decision) {
          hb.ActionDecision() => hb.ChooseAction(
            decision.slot,
            hb.BattleAction.attack,
          ),
          hb.EnemyTargetDecision() => hb.ChooseEnemyTarget(
            decision.slot,
            decision.enemyIndices.first,
          ),
          _ => hb.CancelChoice(decision.slot),
        });
      }
      final settlement = settle(world, battle.outcome!);
      expect(battle.outcome!.resultCode, hb.BattleResultCode.win);
      // Keyed by reference, not by slot: a reordered party must not
      // hand somebody else's experience over.
      expect(settlement.experience.keys, contains(const hw.MemberRef('knight')));
    });
  });
}
