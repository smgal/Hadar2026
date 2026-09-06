import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

/// B6-03 — a vial goes on the blade or at an enemy, and the battle asks
/// which. Before this the vial asked for an enemy and then coated the
/// weapon anyway.
void main() {
  // Two orcs: with one, the target question is skipped (B6-07) and the
  // "throwing asks for an enemy" test would have nothing to see.
  Battle vialBattle({int seed = 3}) => Battle(
    BattleSetup(
      party: [seumgal()],
      enemyKeys: const ['orc', 'orc'],
      initialGap: 0,
      seed: seed,
      consumables: const {'fire_vial': 1, 'poison_vial': 1},
    ),
  );

  /// Walks to the point where the vial's use is asked.
  ItemUseDecision pickVial(Battle battle, String key) {
    battle.advance();
    battle.applyCommand(const ChooseAction(0, BattleAction.useItem));
    expect(battle.pendingDecision, isA<ItemDecision>());
    battle.applyCommand(ChooseItem(0, key));
    final d = battle.pendingDecision;
    expect(d, isA<ItemUseDecision>(), reason: '어떻게 쓸지를 먼저 묻는다');
    return d! as ItemUseDecision;
  }

  test('a vial asks how, and offers both ways', () {
    final d = pickVial(vialBattle(), 'fire_vial');
    expect(d.itemKey, 'fire_vial');
    expect(d.uses, [ItemUse.coat, ItemUse.throwAtEnemy]);
  });

  test('coating asks no target and lays the coating', () {
    final battle = vialBattle();
    pickVial(battle, 'fire_vial');
    battle.applyCommand(const ChooseItemUse(0, ItemUse.coat));
    expect(
      battle.pendingDecision,
      isNull,
      reason: 'nothing left to ask this round',
    );
    final events = <BattleEvent>[];
    while (!battle.isFinished && battle.pendingDecision == null) {
      events.addAll(battle.advance());
    }
    expect(events.whereType<WeaponCoated>(), hasLength(1));
    expect(events.whereType<WeaponCoated>().single.coating, Coating.fire);
    expect(events.whereType<EnemyTargetDecision>(), isEmpty);
    expect(battle.party.single.coating?.kind, Coating.fire);
  });

  test('throwing asks for an enemy and fires through the chart', () {
    final battle = vialBattle();
    pickVial(battle, 'fire_vial');
    battle.applyCommand(const ChooseItemUse(0, ItemUse.throwAtEnemy));
    expect(battle.pendingDecision, isA<EnemyTargetDecision>());
    battle.applyCommand(const ChooseEnemyTarget(0, 0));
    final events = <BattleEvent>[];
    while (!battle.isFinished && battle.pendingDecision == null) {
      events.addAll(battle.advance());
    }
    expect(events.whereType<VialThrown>(), hasLength(1));
    expect(events.whereType<WeaponCoated>(), isEmpty);
    expect(battle.party.single.coating, isNull, reason: 'nothing on the blade');
    // The orc took fire damage (or was blocked/absorbed — either way it
    // went through the damage path, not the coating path).
    expect(events.any((e) => e is EnemyDamaged || e is EnemyBlocked), isTrue);
    expect(battle.outcome?.consumedItems['fire_vial'] ?? 1, 1);
  });

  test('a thrown poison vial poisons once — what one coated hit would do', () {
    // Find a seed where it takes hold; the roll is resistance only.
    var poisoned = false;
    for (var seed = 0; seed < 30 && !poisoned; seed++) {
      final battle = vialBattle(seed: seed);
      pickVial(battle, 'poison_vial');
      battle.applyCommand(const ChooseItemUse(0, ItemUse.throwAtEnemy));
      battle.applyCommand(const ChooseEnemyTarget(0, 0));
      final events = <BattleEvent>[];
      while (!battle.isFinished && battle.pendingDecision == null) {
        events.addAll(battle.advance());
      }
      if (events.whereType<EnemyPoisoned>().isNotEmpty) {
        poisoned = true;
        expect(battle.enemies.first.poison, coatingPoisonPerHit);
      } else {
        expect(events.whereType<CoatingResisted>(), hasLength(1));
      }
    }
    expect(poisoned, isTrue, reason: 'an orc has little resistance');
  });

  test('the vial is spent either way', () {
    final battle = vialBattle();
    pickVial(battle, 'fire_vial');
    battle.applyCommand(const ChooseItemUse(0, ItemUse.coat));
    runBattle(battle, alwaysAttack);
    expect(battle.outcome!.consumedItems['fire_vial'], 1);
  });

  test('the command round-trips through JSON', () {
    const c = ChooseItemUse(2, ItemUse.throwAtEnemy);
    final back = BattleCommand.fromJson(c.toJson());
    expect(back.toJson(), c.toJson());
  });
}
