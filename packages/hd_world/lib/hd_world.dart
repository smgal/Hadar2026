/// Character, party, item and equipment model for Hadar2026.
///
/// Pure Dart: no Flutter, no `dart:io`, no rendering, no display text,
/// no scripting language. Build a [World], hand it a [WorldCommand],
/// read the [WorldEvent]s it returns, and render [World.view] however
/// you like.
///
/// The three claims this package is built to keep:
///
/// * **Independence** — it imports nothing from this repository. The
///   battle package, the Flutter app and the legacy scripts all sit
///   outside it and adapt to it, never the other way round.
/// * **Stability** — every identity that crosses a boundary carries an
///   explicit integer, and nothing derived is ever stored.
/// * **Extensibility** — items, classes and effects are data. A new
///   amulet is a row, not a branch.
library;

export 'src/contract/persistence.dart';
export 'src/contract/views.dart';
export 'src/contract/world_command.dart';
export 'src/contract/world_event.dart';
export 'src/data/class_table.dart';
export 'src/data/item_catalog.dart';
export 'src/data/roster_template.dart';
export 'src/domain/capability.dart';
export 'src/domain/character_class.dart';
export 'src/domain/equip_slot.dart';
export 'src/domain/fighting_style.dart';
export 'src/domain/ids.dart';
export 'src/domain/item_def.dart';
export 'src/domain/item_kind.dart';
export 'src/domain/member.dart';
export 'src/domain/modifier.dart';
export 'src/domain/pack.dart';
export 'src/domain/stats.dart';
export 'src/domain/wire.dart';
export 'src/model/world.dart';
export 'src/rules/eligibility.dart';
export 'src/rules/fighting_style.dart';
export 'src/rules/party_capability.dart';
export 'src/rules/refusal.dart';
export 'src/rules/stat_resolution.dart';
export 'src/rules/weapon_kind.dart';
