import 'party.dart';
import 'player.dart';

/// Outcome of resting one party member, used by the menu flow to pick
/// the right console message. Domain rules don't pick the wording —
/// they just classify what happened.
enum RestOutcome {
  /// Party is out of food; no rest possible.
  noFood,

  /// Member is permanently dead — no change.
  alreadyDead,

  /// Was unconscious (no poison); regained consciousness this round.
  unconsciousRecovered,

  /// Was unconscious; not enough rest yet to come back.
  unconsciousStillOut,

  /// Unconscious *and* poisoned — poison blocks recovery.
  unconsciousPoisoned,

  /// Awake but poisoned — poison blocks healing.
  poisoned,

  /// HP capped at the per-level max — fully healed.
  fullyHealed,

  /// HP rose but not yet at max.
  partiallyHealed,
}

class RestEntryResult {
  final HDPlayer player;
  final RestOutcome outcome;
  const RestEntryResult(this.player, this.outcome);
}

/// Game rules for "여기서 쉰다" (rest at the field). Mirrors the
/// original Hadar mechanics:
///
/// - food blocks all healing.
/// - dead members don't recover.
/// - poison blocks both consciousness and HP recovery.
/// - unconscious members tick down by sum of all levels per round.
/// - awake members heal by `(L0+L1+L2) * 2` HP, capped at
///   `endurance * level[0]`. Healing consumes one food.
/// - SP/ESP fully refresh from level + stats every round.
/// - Party-wide magic effects decay (`magicTorch--`, others reset).
class HDPartyActions {
  /// Applies the rest rules to one member and returns the classification.
  /// Mutates [p] and [party] (food / SP / ESP / HP).
  static RestEntryResult restPlayer(HDPlayer p, HDParty party) {
    RestOutcome outcome;

    if (party.food <= 0) {
      outcome = RestOutcome.noFood;
    } else if (p.dead > 0) {
      outcome = RestOutcome.alreadyDead;
    } else if (p.unconscious > 0 && p.poison == 0) {
      p.unconscious -= (p.level[0] + p.level[1] + p.level[2]);
      if (p.unconscious <= 0) {
        p.unconscious = 0;
        if (p.hp <= 0) p.hp = 1;
        party.food--;
        outcome = RestOutcome.unconsciousRecovered;
      } else {
        outcome = RestOutcome.unconsciousStillOut;
      }
    } else if (p.unconscious > 0 && p.poison > 0) {
      outcome = RestOutcome.unconsciousPoisoned;
    } else if (p.poison > 0) {
      outcome = RestOutcome.poisoned;
    } else {
      final int recovery = (p.level[0] + p.level[1] + p.level[2]) * 2;
      final int maxHp = p.endurance * p.level[0];

      final bool fullHp = p.hp >= maxHp;

      p.hp += recovery;
      if (p.hp >= maxHp) {
        p.hp = maxHp;
        outcome = RestOutcome.fullyHealed;
      } else {
        outcome = RestOutcome.partiallyHealed;
      }

      if (!fullHp) {
        party.food--;
      }
    }

    // SP/ESP refresh + cap regardless of branch.
    p.sp = p.mentality * p.level[1];
    p.esp = p.concentration * p.level[2];
    if (p.sp > p.maxSp) p.sp = p.maxSp;
    if (p.esp > p.maxEsp) p.esp = p.maxEsp;
    if (p.hp > p.maxHp) p.hp = p.maxHp;

    return RestEntryResult(p, outcome);
  }

  /// Decay party-wide magic effects after a rest cycle.
  static void applyRestHousekeeping(HDParty party) {
    if (party.magicTorch > 0) party.magicTorch--;
    party.levitation = 0;
    party.walkOnWater = 0;
    party.walkOnSwamp = 0;
    party.mindControl = 0;
  }

  /// Swap two valid party members and renumber `order`. Indices refer to
  /// `party.players` directly (not the filtered "valid" list).
  static void swapMembers(HDParty party, int srcIdx, int destIdx) {
    final tmp = party.players[srcIdx];
    party.players[srcIdx] = party.players[destIdx];
    party.players[destIdx] = tmp;
    for (int i = 0; i < party.players.length; i++) {
      party.players[i].order = i;
    }
  }

  /// Mark a member as dismissed (clear name → invalid), then bubble
  /// invalid entries to the end and renumber `order`.
  static void dismissMember(HDParty party, int idx) {
    party.players[idx].name = "";
    // Bubble invalid entries to the back.
    for (int i = 0; i < party.players.length - 1; i++) {
      for (int j = 0; j < party.players.length - 1; j++) {
        if (!party.players[j].isValid() && party.players[j + 1].isValid()) {
          final tmp = party.players[j];
          party.players[j] = party.players[j + 1];
          party.players[j + 1] = tmp;
        }
      }
    }
    for (int i = 0; i < party.players.length; i++) {
      party.players[i].order = i;
    }
  }
}
