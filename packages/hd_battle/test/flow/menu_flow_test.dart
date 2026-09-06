import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B6-07 — how the battle asks, after the menu audit.
///
/// Four things a person tripped over: asking in slot order while the
/// picture is in rank order; a cancelled sub-menu costing the turn; a
/// one-answer question still being asked; cures not asking who.
void main() {
  CombatantSnapshot member(int slot, int rank, {int levelMagic = 0}) =>
      CombatantSnapshot(
        slot: slot,
        name: 'm$slot',
        hp: 100,
        maxHp: 100,
        sp: 50,
        maxSp: 50,
        strength: 12,
        powOfWeapon: 10,
        levelPhysical: 1,
        levelMagic: levelMagic,
        accuracyPhysical: 15,
        weaponKey: 'dagger',
        rank: rank,
      );

  group('asking order is leader, then front to back', () {
    test('a back-rank leader is still asked first, then rank 1, 2, 3', () {
      // Slot 0 (leader) stands at the back; slot 1 is up front.
      final battle = Battle(
        BattleSetup(
          party: [member(0, 3), member(1, 1), member(2, 2), member(3, 1)],
          enemyKeys: const ['orc', 'orc'],
          seed: 1,
        ),
      );
      battle.advance();
      final asked = <int>[];
      while (battle.pendingDecision is ActionDecision) {
        final d = battle.pendingDecision! as ActionDecision;
        asked.add(d.slot);
        battle.applyCommand(ChooseAction(d.slot, BattleAction.brace));
      }
      expect(asked, [0, 1, 3, 2], reason: 'leader · rank1 (slot 1, 3) · rank2');
    });

    test('the order follows the ranks as they are now, not at setup', () {
      final battle = Battle(
        BattleSetup(
          party: [member(0, 1), member(1, 2)],
          enemyKeys: const ['orc', 'orc'],
          initialGap: 0,
          seed: 1,
        ),
      );
      battle.advance();
      // Round 1: slot 0 leads, slot 1 second.
      expect((battle.pendingDecision! as ActionDecision).slot, 0);
    });
  });

  group('a cancelled sub-question goes back, it does not cost the turn', () {
    Battle twoOrcs() => Battle(
      BattleSetup(
        party: [member(0, 1)],
        enemyKeys: const ['orc', 'orc'],
        seed: 1,
      ),
    )..advance();

    test('cancelling the target question re-asks the action', () {
      final battle = twoOrcs();
      battle.applyCommand(const ChooseAction(0, BattleAction.attack));
      expect(battle.pendingDecision, isA<EnemyTargetDecision>());
      final events = battle.applyCommand(const CancelChoice(0));
      expect(events.whereType<ActionSkipped>(), isEmpty, reason: 'not lost');
      expect(battle.pendingDecision, isA<ActionDecision>());
      expect(battle.pendingDecision!.slot, 0);
    });

    test('cancelling the action menu itself still skips the turn', () {
      final battle = twoOrcs();
      final events = battle.applyCommand(const CancelChoice(0));
      expect(events.whereType<ActionSkipped>(), hasLength(1));
    });

    test('a policy that only ever cancels is cut off, not looped forever', () {
      final battle = twoOrcs();
      var rounds = 0;
      while (battle.pendingDecision is ActionDecision && rounds < 50) {
        battle.applyCommand(const ChooseAction(0, BattleAction.attack));
        battle.applyCommand(const CancelChoice(0));
        rounds++;
      }
      expect(rounds, lessThan(50), reason: 'the guard skipped the turn');
      expect(battle.pendingDecision, isNull, reason: 'the round moved on');
    });

    test('picking an unaffordable skill says so and comes back', () {
      final battle = Battle(
        BattleSetup(
          party: [
            CombatantSnapshot(
              slot: 0,
              name: 'broke',
              hp: 100,
              maxHp: 100,
              sp: 0,
              maxSp: 50,
              levelMagic: 20,
              accuracyMagic: 15,
              weaponKey: 'dagger',
              rank: 1,
            ),
          ],
          enemyKeys: const ['orc', 'orc'],
          seed: 1,
        ),
      )..advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.castSkill));
      final d = battle.pendingDecision! as SpellDecision;
      final curse = d.options.firstWhere((o) => o.scope == SkillScope.curse);
      expect(curse.affordable, isFalse);
      final events = battle.applyCommand(ChooseSpell(0, curse.magicId));
      expect(events.whereType<NotEnoughSpellPoints>(), hasLength(1));
      expect(events.whereType<ActionSkipped>(), isEmpty);
      expect(battle.pendingDecision, isA<ActionDecision>());
    });
  });

  group('a question with one answer is not asked', () {
    test('one enemy: attack goes straight through', () {
      final battle = Battle(
        BattleSetup(party: [member(0, 1)], enemyKeys: const ['orc'], seed: 1),
      )..advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.attack));
      expect(battle.pendingDecision, isNull, reason: 'nobody left to ask');
    });

    test('two enemies: the target is asked, nearest first', () {
      final battle = Battle(
        BattleSetup(
          party: [member(0, 1)],
          enemyKeys: const ['orc', 'orc'],
          enemyRanks: const [3, 1],
          seed: 1,
        ),
      )..advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.attack));
      final d = battle.pendingDecision! as EnemyTargetDecision;
      expect(d.enemyIndices, [1, 0], reason: 'rank 1 before rank 3');
    });
  });

  group('cures ask who, neediest first', () {
    test('a single-target cure asks, and the hurt one is listed first', () {
      final battle = Battle(
        BattleSetup(
          party: [member(0, 1, levelMagic: 5), member(1, 1), member(2, 2)],
          enemyKeys: const ['orc'],
          seed: 1,
        ),
      )..advance();
      // Hurt slot 2 so it is the one in need.
      battle.party[2].hp = 10;
      battle.applyCommand(const ChooseAction(0, BattleAction.castSkill));
      final skills = battle.pendingDecision! as SpellDecision;
      expect(skills.magicIds, contains(19));
      battle.applyCommand(const ChooseSpell(0, 19));
      final d = battle.pendingDecision;
      expect(d, isA<AllyTargetDecision>(), reason: 'items asked; cures now do');
      expect((d! as AllyTargetDecision).slots.first, 2);
    });

    test('with one member there is nothing to ask', () {
      final battle = Battle(
        BattleSetup(
          party: [member(0, 1, levelMagic: 5)],
          enemyKeys: const ['orc'],
          seed: 1,
        ),
      )..advance();
      battle.party[0].hp = 10;
      battle.applyCommand(const ChooseAction(0, BattleAction.castSkill));
      battle.applyCommand(const ChooseSpell(0, 19));
      expect(battle.pendingDecision, isNull);
    });
  });
}
