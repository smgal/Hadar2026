/// Standalone battle model for Hadar2026.
///
/// Pure Dart: no Flutter, no rendering, no text. Drive it with
/// `pendingDecision` / `applyCommand` / `advance`, render the
/// `BattleEvent`s however you like, and read `outcome` when it finishes.
library;

export 'src/contract/battle_command.dart';
export 'src/contract/battle_event.dart';
export 'src/contract/battle_result_code.dart';
export 'src/contract/battle_setup.dart';
export 'src/data/enemy_table.dart';
export 'src/model/battle.dart' show Battle, BattlePhase;
export 'src/model/combatant.dart';
export 'src/model/enemy_instance.dart';
export 'src/rules/affinity.dart';
export 'src/rules/attack_magic.dart';
export 'src/rules/battle_item.dart';
export 'src/rules/coating.dart';
export 'src/rules/collapse.dart';
export 'src/rules/condition.dart';
export 'src/rules/cure.dart';
export 'src/rules/enemy_action.dart';
export 'src/rules/enemy_ai.dart';
export 'src/rules/esp.dart';
export 'src/rules/initiative.dart';
export 'src/rules/superhuman.dart';
export 'src/rules/escape.dart';
export 'src/rules/magic.dart';
export 'src/rules/mitigation.dart';
export 'src/rules/physical.dart';
export 'src/rules/position.dart';
export 'src/rules/preset.dart';
export 'src/rules/rng.dart';
export 'src/rules/settle.dart';
export 'src/rules/spellbook.dart';
export 'src/rules/vitals.dart';
export 'src/rules/weapon.dart';
