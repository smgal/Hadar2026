/// Standalone battle model for the Lore trilogy.
///
/// A fork of `hd_battle`: the same skeleton — a state machine driven by
/// `pendingDecision` / `applyCommand` / `advance`, events without text,
/// ranks and a gap — carrying the Part 3 rule system and one enemy table
/// per part. Pure Dart: no Flutter, no rendering, no text.
library;

export 'src/contract/battle_command.dart';
export 'src/contract/battle_event.dart';
export 'src/contract/battle_result_code.dart';
export 'src/contract/battle_setup.dart';
export 'src/contract/vocabulary.dart';
export 'src/data/enemy_data.dart';
export 'src/data/enemy_table_ep1.dart';
export 'src/data/enemy_table_ep2.dart';
export 'src/data/enemy_table_ep3.dart';
export 'src/data/enemy_tables.dart';
export 'src/data/summon_table.dart';
export 'src/model/battle.dart' show Battle, BattlePhase;
export 'src/model/combatant.dart';
export 'src/model/enemy_instance.dart';
export 'src/rules/affinity.dart';
export 'src/rules/attack_magic.dart';
export 'src/rules/battle_item.dart';
export 'src/rules/condition.dart';
export 'src/rules/cure.dart';
export 'src/rules/enemy_ai.dart';
export 'src/rules/escape.dart';
export 'src/rules/esp.dart';
export 'src/rules/initiative.dart';
export 'src/rules/physical.dart';
export 'src/rules/position.dart';
export 'src/rules/preset.dart';
export 'src/rules/rng.dart';
export 'src/rules/settle.dart';
export 'src/rules/skillbook.dart';
export 'src/rules/special_magic.dart';
export 'src/rules/summon.dart';
export 'src/rules/weapon.dart';
