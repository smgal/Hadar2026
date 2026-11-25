/// Character, party, item, equipment, time and field rules for the Lore
/// trilogy remake.
///
/// Pure Dart: no Flutter, no `dart:io`, no clock, no console, no display
/// text. All three parts run on the Part 3 game system; the episode only
/// selects data (Part-1-only classes and weapon, the starting calendar,
/// the companion roster).
///
/// Build a [LoreWorld], call a command on it, read the [Outcome] it
/// returns. Commands never throw: a refusal comes back as a closed
/// [RefusalReason], and everything that happened comes back as
/// [LoreEvent]s. Korean lives in `lore_world_text`.
library;

export 'src/contract/events.dart';
export 'src/contract/outcome.dart';
export 'src/data/class_table.dart';
export 'src/data/equipment_table.dart';
export 'src/data/item_table.dart';
export 'src/data/level_table.dart';
export 'src/data/roster.dart';
export 'src/data/spell_table.dart';
export 'src/data/summon_table.dart';
export 'src/domain/calendar.dart';
export 'src/domain/enums.dart';
export 'src/domain/member.dart';
export 'src/model/world.dart';
export 'src/rules/attributes.dart';
export 'src/rules/creation.dart';
export 'src/rules/equipment.dart';
export 'src/rules/field.dart';
export 'src/rules/items.dart';
export 'src/rules/magic.dart';
export 'src/rules/party.dart';
export 'src/rules/town.dart';
export 'src/rules/training.dart';
