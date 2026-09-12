import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_world/hd_world.dart' as hw;

import 'consumables.dart';

/// What a finished battle asks the world to do about it.
///
/// ## Returned, not applied
///
/// Vitals are written straight onto the members, because a battle's job
/// is to leave the party in the state it fought its way into and there
/// is no rule to consult. Everything the **world has rules about** —
/// spending what was used up — comes back as commands, so it goes
/// through the one door and a refusal is visible.
///
/// Experience is reported and never applied: levelling is the world's
/// business and the battle deliberately carries no table for it.
class Settlement {
  const Settlement({
    required this.commands,
    required this.experience,
    required this.departed,
    required this.worldEffects,
  });

  /// Changes that have to go through `World.apply`.
  final List<hw.WorldCommand> commands;

  /// Experience earned, per member reference.
  final Map<hw.MemberRef, int> experience;

  /// Members the battle took away for good. The world has to clear
  /// them, and this bridge does not decide how.
  final List<hw.MemberRef> departed;

  /// Requests the battle could not carry out itself.
  final List<String> worldEffects;

  bool get isEmpty =>
      commands.isEmpty &&
      experience.isEmpty &&
      departed.isEmpty &&
      worldEffects.isEmpty;
}

/// Writes the fight's vitals back and reports the rest.
///
/// A result finds its member by **seat number**, which is what
/// `toBattleSetup` sent. A seat outside the roster is skipped rather
/// than throwing — a recruit taken on mid-battle has no member yet, and
/// that is the recruit path's problem, not this one's.
Settlement settle(hw.World world, hb.BattleOutcome outcome) {
  final members = world.members;
  final experience = <hw.MemberRef, int>{};
  final departed = <hw.MemberRef>[];

  for (final result in outcome.combatants) {
    if (result.slot < 0 || result.slot >= members.length) continue;
    final member = members[result.slot];
    member
      ..hitPoints = result.hp
      ..spellPoints = result.sp
      ..espPoints = result.esp
      ..poison = result.poison
      ..unconscious = result.unconscious
      ..dead = result.dead;
    if (result.experienceGained > 0) {
      experience[member.ref] = result.experienceGained;
      // Accumulated here because the world owns the total; whether that
      // total crosses a threshold is a levelling rule and there is no
      // ladder yet, which is why this adds and does not compare.
      member.experience += result.experienceGained;
    }
  }

  for (final slot in outcome.departedSlots) {
    if (slot >= 0 && slot < members.length) departed.add(members[slot].ref);
  }

  return Settlement(
    commands: spendCommands(outcome.consumedItems),
    experience: experience,
    departed: departed,
    worldEffects: outcome.worldEffects,
  );
}
