/// One choice a party member can make on their turn.
///
/// [wire] is a stable identity for saves and fixtures, **not** a menu
/// index. The values are `hd_battle`'s, kept so a recorded command list
/// reads the same in both packages.
///
/// ## The menu is six lines
///
/// The original's battle menu has nine (ch.8.4) — a line per kind of
/// magic. `hd_battle` folded every spell under one [castSkill] and the
/// fork keeps that shape: the view tells the kinds apart by
/// [SkillScope], not by which menu they came from.
enum BattleAction {
  /// The member does nothing this round — what cancelling out of the
  /// action menu means ("잠시 주저했다").
  skip(0),

  attack(1),

  /// Open the one skill list.
  castSkill(14),

  /// Makes every remaining member act on their standing orders without
  /// being asked. The original's ninth line, for the protagonist only.
  /// Offered under [orders], to the leader.
  autoBattle(8),

  /// Run from the fight. **A party action, taken by the leader.**
  escape(7),

  /// Use a herb, a potion or a crystal.
  useItem(9),

  /// Move the whole formation. Offered under [orders]; costs the
  /// leader's turn.
  advanceFormation(10),
  retreatFormation(11),

  /// Step forward and strike in one action. Only some weapons can.
  charge(12),

  /// Step forward and hold: the guard goes up sharply for the next blow
  /// and they refuse to be pushed.
  brace(13),

  /// The leader's orders — auto-battle and formation moves — folded
  /// into one line. Opens an [OrderDecision].
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

/// The kinds of skill, and the hundreds digit of a skill id.
///
/// A skill id is `category × 100 + tier`: 103 is the third single-target
/// attack spell, 406 the first party-wide cure, 502 수소 핵융합. See
/// `rules/skillbook.dart`.
enum SkillCategory {
  /// 한 명의 적에게 마법 공격 — 101..110.
  attackOne(1),

  /// 모든 적에게 마법 공격 — 201..210.
  attackAll(2),

  /// 특수 마법 — 301..310, and 300 for Part 1's 독.
  special(3),

  /// 치료 마법 — 401..410.
  cure(4),

  /// 초능력 — 501..506.
  esp(5),

  /// 소환 마법 — 601..610.
  summon(6);

  const SkillCategory(this.hundreds);

  final int hundreds;
}

/// Who or what a skill is aimed at.
///
/// The view turns this into a glyph in front of the skill's name so the
/// one list reads at a glance. The model only ever emits the value.
enum SkillScope {
  /// One enemy, chosen next.
  oneEnemy,

  /// Every enemy.
  allEnemies,

  /// One enemy, and what it does is take something away for good.
  curse,

  /// The same, on every enemy.
  curseAll,

  /// One party member.
  oneAlly,

  /// The whole party.
  allAllies,

  /// The sixth seat — something is called into it.
  summon,
}

/// Which discipline a skill is.
///
/// **There is one pool.** Part 3 pays for magic and ESP out of the same
/// magic points, so this no longer says where the cost comes from — it
/// always comes from `mp`. The value survives from `hd_battle` because
/// the list still wants to tell the mind's work from spellcraft, and
/// the view reads it for exactly that.
enum SkillResource { mp, esp }

/// One line of the skill list.
///
/// Carries everything the view needs to draw the line and everything
/// the model needs to accept the answer.
class SkillOption {
  const SkillOption({
    required this.magicId,
    required this.category,
    required this.tier,
    required this.scope,
    required this.resource,
    required this.cost,
    required this.affordable,
    this.perTarget = false,
  });

  /// The skill id — `category × 100 + tier`.
  final int magicId;

  final SkillCategory category;

  /// 1..10 within the category; 0 for Part 1's 독.
  final int tier;

  final SkillScope scope;
  final SkillResource resource;

  /// Magic points, or -1 when it depends on the target (waking and
  /// raising are priced by how far gone the target is).
  final int cost;

  /// True when [cost] is charged **once per target** — every attack
  /// spell that hits all enemies pays for each of them separately.
  final bool perTarget;

  /// Whether the caster can pay right now. **Unaffordable skills stay
  /// in the list**; choosing one is refused with `NotEnoughSpellPoints`.
  final bool affordable;

  Map<String, dynamic> toJson() => {
    'magicId': magicId,
    'category': category.name,
    'tier': tier,
    'scope': scope.name,
    'resource': resource.name,
    'cost': cost,
    'perTarget': perTarget,
    'affordable': affordable,
  };
}

/// What the battle is waiting for. `null` from
/// `Battle.pendingDecision` means nothing needs asking and the caller
/// should `advance()` instead.
sealed class BattleDecision {
  const BattleDecision(this.slot);

  /// The party seat being asked.
  final int slot;
}

/// Pick an action for this member's turn.
final class ActionDecision extends BattleDecision {
  const ActionDecision(super.slot, this.options);

  /// Actions this member may take, in menu order. [BattleAction.skip]
  /// is never listed — cancelling is always allowed and means skip.
  final List<BattleAction> options;
}

/// Pick one enemy to act on.
final class EnemyTargetDecision extends BattleDecision {
  const EnemyTargetDecision(super.slot, this.enemyIndices);

  /// Indices into the battle's enemy list, nearest rank first. With the
  /// "attack the unconscious" option on, unconscious enemies follow the
  /// standing ones — striking one finishes it.
  final List<int> enemyIndices;
}

/// Pick a herb, a potion or a crystal.
final class ItemDecision extends BattleDecision {
  const ItemDecision(super.slot, this.itemKeys);

  /// Keys the party still has and this member can use, in the
  /// original's menu order.
  final List<String> itemKeys;
}

/// Pick which ally a cure or a herb lands on.
final class AllyTargetDecision extends BattleDecision {
  const AllyTargetDecision(super.slot, this.slots);

  /// Party seats that are still present, the one most in need first.
  final List<int> slots;
}

/// Pick a skill from the one list this member has learned.
///
/// Spells, ESP and summons together, in a stable order: single attacks,
/// area attacks, special magic, cures, ESP, summons.
final class SpellDecision extends BattleDecision {
  const SpellDecision(super.slot, this.options);

  final List<SkillOption> options;

  /// Just the ids, in list order.
  List<int> get magicIds => [for (final o in options) o.magicId];

  /// The ids that can be paid for right now.
  List<int> get affordableIds => [
    for (final o in options)
      if (o.affordable) o.magicId,
  ];
}

/// The leader's orders — which of auto-battle / advance / retreat.
///
/// Answered with a [ChooseAction] carrying one of [options].
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

/// Back out of whatever was asked. At the action menu the member skips
/// the turn; at any question below it, the menu comes back and the turn
/// is not lost.
final class CancelChoice extends BattleCommand {
  const CancelChoice(super.slot);

  @override
  Map<String, dynamic> toJson() => {'type': 'cancel', 'slot': slot};
}
