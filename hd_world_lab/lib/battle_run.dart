import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_bridge/hd_bridge.dart';
import 'package:hd_world/hd_world.dart' as hw;

/// Runs one fight to the end, choosing nothing.
///
/// ## Why the lab fights at all
///
/// The equipment screen can show that a bow reaches three ranks, but
/// only a fight shows whether that **matters**. This runs the party
/// through `hd_bridge` into `hd_battle` and reports what came back, so
/// swapping a shield for a torch and losing a rank of reach is
/// something you can watch happen rather than reason about.
///
/// Every decision is answered with "attack the nearest thing", which is
/// the one policy that needs no judgement. It is not a good policy and
/// it is not meant to be — the point is the numbers the equipment
/// produced, not the play.
Map<String, Object?> runBattle(
  hw.World world, {
  required List<String> enemyKeys,
  required int seed,
  int? initialGap,
}) {
  final before = {
    for (final m in world.members) m.ref: m.hitPoints,
  };
  final setup = toBattleSetup(
    world,
    enemyKeys: enemyKeys,
    seed: seed,
    initialGap: initialGap,
  );
  final battle = hb.Battle(setup);

  var rounds = 0;
  var guard = 0;
  final counts = <String, int>{};
  void tally(hb.BattleEvent event) {
    final kind = event.runtimeType.toString();
    counts[kind] = (counts[kind] ?? 0) + 1;
    if (event is hb.RoundStarted) rounds = event.round;
  }

  while (!battle.isFinished && guard++ < 6000) {
    final decision = battle.pendingDecision;
    if (decision == null) {
      battle.advance().forEach(tally);
      continue;
    }
    battle
        .applyCommand(switch (decision) {
          hb.ActionDecision() => hb.ChooseAction(
            decision.slot,
            hb.BattleAction.attack,
          ),
          hb.EnemyTargetDecision() => hb.ChooseEnemyTarget(
            decision.slot,
            decision.enemyIndices.first,
          ),
          _ => hb.CancelChoice(decision.slot),
        })
        .forEach(tally);
  }

  final outcome = battle.outcome;
  if (outcome == null) {
    return {'error': 'the fight did not finish', 'rounds': rounds};
  }
  final settlement = settle(world, outcome);
  final refusals = <Map<String, Object?>>[];
  for (final command in settlement.commands) {
    for (final event in world.apply(command)) {
      if (event is hw.CommandRefused) refusals.add(event.toJson());
    }
  }

  return {
    'result': outcome.resultCode.name,
    'rounds': rounds,
    'seed': seed,
    'enemies': enemyKeys,
    'openingGap': setup.initialGap,
    'members': [
      for (final m in world.members)
        () {
          final stats = hw.resolveStats(member: m, catalog: world.catalog);
          return {
            'ref': m.ref.value,
            'name': m.name,
            'weaponKind': stats.weaponKind.name,
            'weaponKey': weaponKeyFor(
              style: stats.weaponKind,
              mainHandKind: stats.mainHandKind,
              mainHandShape: stats.mainHandShape,
            ),
            'reach': hb
                .weaponFor(
                  weaponKeyFor(
                    style: stats.weaponKind,
                    mainHandKind: stats.mainHandKind,
                    mainHandShape: stats.mainHandShape,
                  ),
                )
                .longestReach,
            'hitPointsBefore': before[m.ref],
            'hitPointsAfter': m.hitPoints,
            'experience': settlement.experience[m.ref] ?? 0,
          };
        }(),
    ],
    'spent': outcome.consumedItems,
    'departed': [for (final r in settlement.departed) r.value],
    'worldEffects': settlement.worldEffects,
    'eventCounts': counts,
    'refused': refusals,
    'state': world.view.toJson(),
  };
}
