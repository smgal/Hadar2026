import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B5-08 — standing orders. The enemy side already had one without a
/// name; the party side gets a menu, not an editor.
void main() {
  group('the enemy roster runs more than one behaviour now', () {
    test('the whole table resolves to a preset', () {
      for (final e in enemyTable) {
        expect(
          () => enemyPreset(
            key: e.key,
            strength: e.strength,
            agility: e.agility,
            endurance: e.endurance,
            castLevel: e.castLevel,
            specialCastLevel: e.specialCastLevel,
            level: e.level,
          ),
          returnsNormally,
          reason: e.key,
        );
      }
    });

    test('and not all to the same one — otherwise nothing changed', () {
      final kinds = {
        for (final e in enemyTable)
          enemyPreset(
            key: e.key,
            strength: e.strength,
            agility: e.agility,
            endurance: e.endurance,
            castLevel: e.castLevel,
            specialCastLevel: e.specialCastLevel,
            level: e.level,
          ),
      };
      expect(kinds.length, greaterThan(2));
    });

    test('casters hang back, brutes lead', () {
      expect(
        enemyPreset(
          key: 'x',
          strength: 5,
          agility: 5,
          endurance: 10,
          castLevel: 5,
          specialCastLevel: 0,
          level: 9,
        ),
        PresetKind.caster,
      );
      expect(
        enemyPreset(
          key: 'y',
          strength: 12,
          agility: 8,
          endurance: 12,
          castLevel: 0,
          specialCastLevel: 0,
          level: 3,
        ),
        PresetKind.aggressive,
      );
    });

    test('a named creature keeps the behaviour it was given', () {
      expect(
        enemyPreset(
          key: 'goblin',
          strength: 20,
          agility: 5,
          endurance: 20,
          castLevel: 0,
          specialCastLevel: 0,
          level: 2,
        ),
        PresetKind.coward,
      );
    });
  });

  group('leaving needed no new event', () {
    test('a coward reads the level gap, not its own wounds', () {
      // Reading health would mean it leaves after it has already lost.
      final coward = presetOf(PresetKind.coward);
      expect(
        presetWantsToFlee(preset: coward, myLevel: 2, theirLevel: 20),
        isTrue,
      );
      expect(
        presetWantsToFlee(preset: coward, myLevel: 20, theirLevel: 20),
        isFalse,
      );
    });

    test('everything else stands its ground', () {
      for (final kind in PresetKind.values) {
        if (kind == PresetKind.coward) continue;
        expect(
          presetWantsToFlee(preset: presetOf(kind), myLevel: 1, theirLevel: 99),
          isFalse,
          reason: kind.name,
        );
      }
    });

    test('a coward actually leaves a real battle', () {
      final battle = Battle(
        BattleSetup(
          party: [
            const CombatantSnapshot(
              slot: 0,
              name: 'veteran',
              hp: 400,
              maxHp: 400,
              rank: 1,
              levelPhysical: 20,
              strength: 20,
              powOfWeapon: 20,
              accuracyPhysical: 19,
            ),
          ],
          enemyKeys: const ['goblin'],
          initialGap: 0,
          seed: 2,
        ),
      );
      final events = <BattleEvent>[];
      var guard = 0;
      while (!battle.isFinished && guard++ < 400) {
        final d = battle.pendingDecision;
        if (d == null) {
          events.addAll(battle.advance());
          continue;
        }
        battle.applyCommand(switch (d) {
          ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
          EnemyTargetDecision() => ChooseEnemyTarget(d.slot, 0),
          _ => CancelChoice(d.slot),
        });
      }
      expect(events.whereType<EnemyFled>(), isNotEmpty);
    });
  });

  group('automatic is strong but blind', () {
    test('it never chooses a target — it takes the nearest thing standing', () {
      // A preset that reads the board better than the player makes not
      // playing optimal. Reading the board is what the player is for.
      final battle = Battle(
        BattleSetup(
          party: [
            const CombatantSnapshot(
              slot: 0,
              name: 'leader',
              hp: 200,
              maxHp: 200,
              rank: 1,
              strength: 14,
              powOfWeapon: 14,
              levelPhysical: 2,
              accuracyPhysical: 19,
            ),
            const CombatantSnapshot(
              slot: 1,
              name: 'follower',
              hp: 200,
              maxHp: 200,
              rank: 1,
              strength: 14,
              powOfWeapon: 14,
              levelPhysical: 2,
              accuracyPhysical: 19,
            ),
          ],
          // The weak one is second; a thinking player would finish it.
          enemyKeys: const ['giant', 'orc'],
          enemyRanks: const [1, 1],
          initialGap: 0,
          seed: 4,
        ),
      );
      battle.advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.orders));
      battle.applyCommand(const ChooseAction(0, BattleAction.autoBattle));
      // Nobody else is asked once auto-battle is on.
      expect(battle.pendingDecision, isNull);
    });

    test('a guardian sets itself once it is hurt', () {
      final guardian = presetOf(PresetKind.guardian);
      expect(guardian.bracesWhenHurt, isTrue);
      expect(presetOf(PresetKind.aggressive).bracesWhenHurt, isFalse);
    });

    test('a charging preset only charges with something that charges', () {
      final aggressive = presetOf(PresetKind.aggressive);
      expect(
        presetWantsToCharge(
          preset: aggressive,
          weapon: weaponFor('lance'),
          distance: 5,
        ),
        isTrue,
      );
      expect(
        presetWantsToCharge(
          preset: aggressive,
          weapon: weaponFor('dagger'),
          distance: 5,
        ),
        isFalse,
      );
      expect(
        presetWantsToCharge(
          preset: aggressive,
          weapon: weaponFor('lance'),
          distance: 1,
        ),
        isFalse,
        reason: 'already close enough',
      );
    });
  });

  group('the party carries a preset, not a rule editor', () {
    test('it defaults to the original auto-battle behaviour', () {
      expect(
        const CombatantSnapshot(slot: 0, name: 'a', hp: 1, maxHp: 1).preset,
        PresetKind.aggressive,
      );
    });

    test('learning lengthens a list rather than opening an editor', () {
      const c = CombatantSnapshot(
        slot: 0,
        name: 'a',
        hp: 1,
        maxHp: 1,
        knownPresets: {PresetKind.guardian, PresetKind.skirmisher},
      );
      expect(c.knownPresets.length, 2);
    });

    test('it survives a JSON round trip', () {
      const c = CombatantSnapshot(
        slot: 0,
        name: 'a',
        hp: 1,
        maxHp: 1,
        preset: PresetKind.medic,
        knownPresets: {PresetKind.medic, PresetKind.caster},
      );
      final back = CombatantSnapshot.fromJson(c.toJson());
      expect(back.preset, PresetKind.medic);
      expect(back.knownPresets, {PresetKind.medic, PresetKind.caster});
    });
  });
}
