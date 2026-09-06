/// One choice a party member can make on their turn.
///
/// [wire] is a stable identity for saves and fixtures, **not** a menu
/// index. The values up to 13 are the ones the original menu used
/// (`battle.dart:311-325`), kept so the port stays traceable; B6 added
/// 14 and 15 and retired the five per-category spell entries.
///
/// ## B6 — the menu is six lines
///
/// Before B6 the top-level menu had a line per spell category, five of
/// them, because the original's category numbering (1-6 / 7-12 / 13-18
/// / 19-32 / 41-45) had leaked straight into the menu. Now every spell
/// and ESP ability sits under one [castSkill], and the view tells them
/// apart by [SkillScope] rather than by which menu they came from.
enum BattleAction {
  /// The member does nothing this round. The original reached this by
  /// cancelling out of a submenu (`battle.dart:349` sets the command
  /// back to 0).
  skip(0),

  attack(1),

  /// Open the one skill list — every castable spell and ESP ability,
  /// tagged by scope and resource (B6-01). Replaces the five
  /// per-category entries the menu used to have.
  castSkill(14),

  /// Makes every remaining member attack without asking
  /// (`battle.dart:339-342`). Offered under [orders], to the leader.
  autoBattle(8),

  /// Run from the fight. **A party action, taken by the leader** (B6-04).
  ///
  /// The original offered flight to everyone but slot 0 and ended the
  /// battle as soon as any one roll succeeded, which with five members
  /// was very nearly automatic. Now there is one roll for the party, and
  /// the gap between the lines makes it easier (`rules/escape.dart`).
  escape(7),

  /// Use a carried item (B2-06).
  ///
  /// **Not in the original menu** — the C++ battle offers eight choices
  /// and none of them is an item (appendix R). Wire value 9 sits past
  /// everything the original used, so nothing collides.
  useItem(9),

  /// Move the whole formation (B5-03). Offered under [orders].
  ///
  /// It costs the leader's turn, which in a five-member party is one
  /// action in twenty across a fight — affordable, and paid for.
  advanceFormation(10),
  retreatFormation(11),

  /// Step forward and strike in one action (B5-03).
  ///
  /// Only some weapons can. It needs no penalty of its own: stepping to
  /// the front is what the targeting weights punish.
  charge(12),

  /// Step forward and hold (B5-03).
  ///
  /// Raises the shield's chance sharply for the next blow, less for the
  /// second in the same round, and refuses to be pushed. Combined with
  /// rank-weighted targeting this is what makes a tank possible: before
  /// B5-04 a shield only ever protected the person holding it, because
  /// nothing made the enemy swing at them.
  brace(13),

  /// The leader's standing orders — auto-battle and formation moves —
  /// folded into one line so the top menu stays six long (B6-01). Opens
  /// an [OrderDecision]; the answer is one of [autoBattle],
  /// [advanceFormation], [retreatFormation].
  orders(15);

  const BattleAction(this.wire);

  final int wire;

  /// Whether this action opens the skill list.
  bool get isSpell => this == castSkill;

  /// Whether this is one of the leader's orders (answers to [orders]).
  bool get isOrder =>
      this == autoBattle ||
      this == advanceFormation ||
      this == retreatFormation;
}

/// Who or what a skill is aimed at (B6-01).
///
/// The view turns this into a glyph in front of the skill's name so the
/// one list reads at a glance. The model only ever emits the value.
enum SkillScope {
  /// One enemy, chosen next.
  oneEnemy,

  /// Every enemy.
  allEnemies,

  /// One enemy, and what it does is take something away for good —
  /// the special magic 14 · 15 · 17 · 18 (B6-02).
  curse,

  /// One party member.
  oneAlly,

  /// The whole party.
  allAllies,

  /// The caster's own weapon — the poison coating spell, 13 (B6-02).
  selfWeapon,
}

/// Which pool a skill spends from.
enum SkillResource { sp, esp }

/// One line of the skill list (B6-01).
///
/// Carries everything the view needs to draw the line and everything the
/// model needs to accept the answer. [cost] is `-1` when it depends on
/// the target (the cures) or is charged per enemy (area magic).
class SkillOption {
  const SkillOption({
    required this.magicId,
    required this.scope,
    required this.resource,
    required this.cost,
    required this.affordable,
  });

  final int magicId;
  final SkillScope scope;
  final SkillResource resource;

  /// Fixed cost, or -1 when it cannot be known before casting.
  final int cost;

  /// Whether the caster can pay right now. **Unaffordable skills stay in
  /// the list** — before B6 they vanished, and nobody could tell why.
  /// Choosing one is refused with `NotEnoughSpellPoints`.
  final bool affordable;

  Map<String, dynamic> toJson() => {
    'magicId': magicId,
    'scope': scope.name,
    'resource': resource.name,
    'cost': cost,
    'affordable': affordable,
  };
}

/// What the battle is waiting for. `null` from
/// `Battle.pendingDecision` means nothing needs asking and the caller
/// should `advance()` instead.
sealed class BattleDecision {
  const BattleDecision(this.slot);

  /// The party slot being asked.
  final int slot;
}

/// Pick an action for this member's turn.
final class ActionDecision extends BattleDecision {
  const ActionDecision(super.slot, this.options);

  /// Actions this member may take, in menu order. [BattleAction.skip] is
  /// never listed — cancelling is always allowed and means skip.
  final List<BattleAction> options;
}

/// Pick one enemy to act on.
final class EnemyTargetDecision extends BattleDecision {
  const EnemyTargetDecision(super.slot, this.enemyIndices);

  /// Indices into the battle's enemy list. Only conscious enemies are
  /// offered.
  final List<int> enemyIndices;
}

/// Pick an item to use (B2-06).
final class ItemDecision extends BattleDecision {
  const ItemDecision(super.slot, this.itemKeys);

  /// Keys the party still has, in a stable order.
  final List<String> itemKeys;
}

/// How a vial is used (B6-03 follow-up).
///
/// A coating vial can go on the blade for three rounds **or** be thrown at
/// one enemy for its effect right now. Throwing is the immediate, weaker
/// road; coating is the patient one.
enum ItemUse { coat, throwAtEnemy }

/// Asked after a coating vial is picked: on the weapon, or at an enemy?
final class ItemUseDecision extends BattleDecision {
  const ItemUseDecision(super.slot, this.itemKey, this.uses);

  final String itemKey;
  final List<ItemUse> uses;
}

/// Pick which ally an item or a cure lands on (B2-06).
///
/// The original asked this for cures (`castCureSpell` opens with a
/// "to whom" menu) and the Dart port dropped the question. B2-02 stood
/// in with "whoever needs it most"; now that items need the same
/// question, both use this.
final class AllyTargetDecision extends BattleDecision {
  const AllyTargetDecision(super.slot, this.slots);

  /// Party slots that are still present.
  final List<int> slots;
}

/// Pick a skill from the one list this member has learned (B6-01).
///
/// Spells and ESP abilities together, in a stable order: single attacks,
/// area attacks, the poison coating, curses, cures, ESP. The scope glyph
/// is what separates them for the reader, not the menu they came from.
final class SpellDecision extends BattleDecision {
  const SpellDecision(super.slot, this.options);

  final List<SkillOption> options;

  /// Just the ids, in list order. Kept for callers that only need to
  /// pick one.
  List<int> get magicIds => [for (final o in options) o.magicId];

  /// The ids that can be paid for right now.
  List<int> get affordableIds => [
    for (final o in options)
      if (o.affordable) o.magicId,
  ];
}

/// The leader's orders — which of auto-battle / advance / retreat (B6-01).
///
/// Answered with a [ChooseAction] carrying one of [options]. Only the
/// leader is ever asked this, and only the orders that make sense right
/// now are listed (no advance at gap 0, no retreat at the maximum).
final class OrderDecision extends BattleDecision {
  const OrderDecision(super.slot, this.options);

  final List<BattleAction> options;
}

/// An answer to a [BattleDecision].
sealed class BattleCommand {
  const BattleCommand(this.slot);

  final int slot;

  Map<String, dynamic> toJson();

  static BattleCommand fromJson(Map<String, dynamic> j) {
    final slot = j['slot'] as int;
    switch (j['type'] as String) {
      case 'action':
        return ChooseAction(
          slot,
          BattleAction.values.firstWhere((a) => a.name == j['action']),
        );
      case 'target':
        return ChooseEnemyTarget(slot, j['enemyIndex'] as int);
      case 'spell':
        return ChooseSpell(slot, j['magicId'] as int);
      case 'item':
        return ChooseItem(slot, j['itemKey'] as String);
      case 'itemUse':
        return ChooseItemUse(
          slot,
          ItemUse.values.firstWhere((u) => u.name == j['use']),
        );
      case 'ally':
        return ChooseAllyTarget(slot, j['allySlot'] as int);
      case 'cancel':
        return CancelChoice(slot);
      default:
        throw ArgumentError('unknown command type: ${j['type']}');
    }
  }
}

final class ChooseAction extends BattleCommand {
  const ChooseAction(super.slot, this.action);

  final BattleAction action;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'action',
    'slot': slot,
    'action': action.name,
  };
}

final class ChooseEnemyTarget extends BattleCommand {
  const ChooseEnemyTarget(super.slot, this.enemyIndex);

  final int enemyIndex;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'target',
    'slot': slot,
    'enemyIndex': enemyIndex,
  };
}

final class ChooseSpell extends BattleCommand {
  const ChooseSpell(super.slot, this.magicId);

  final int magicId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'spell',
    'slot': slot,
    'magicId': magicId,
  };
}

final class ChooseItem extends BattleCommand {
  const ChooseItem(super.slot, this.itemKey);

  final String itemKey;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'item',
    'slot': slot,
    'itemKey': itemKey,
  };
}

final class ChooseItemUse extends BattleCommand {
  const ChooseItemUse(super.slot, this.use);

  final ItemUse use;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'itemUse',
    'slot': slot,
    'use': use.name,
  };
}

final class ChooseAllyTarget extends BattleCommand {
  const ChooseAllyTarget(super.slot, this.allySlot);

  final int allySlot;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'ally',
    'slot': slot,
    'allySlot': allySlot,
  };
}

/// Back out of whatever was asked. The member skips their turn, which is
/// what the original did on every cancel path
/// (`battle.dart:349,364,371`).
final class CancelChoice extends BattleCommand {
  const CancelChoice(super.slot);

  @override
  Map<String, dynamic> toJson() => {'type': 'cancel', 'slot': slot};
}
