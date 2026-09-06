import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// Formulas 16-18. No randomness in any of them.
///
/// The poison rule moved to `collapse_test.dart` when B2-03 folded it
/// into the shared collapse rule.
void main() {
  group('formula 16 - victory experience (battle.dart:276-280)', () {
    test('reads the table index, not the level', () {
      // id 0 -> (1*1*1)~/8 == 0 -> clamped to 1
      expect(victoryExperience([0]), 1);
      // id 1 -> (2^3)~/8 == 1
      expect(victoryExperience([1]), 1);
      // id 7 -> (8^3)~/8 == 64
      expect(victoryExperience([7]), 64);
      // id 25 -> (26^3)~/8 == 2197
      expect(victoryExperience([25]), 2197);
    });

    test('sums over every enemy', () {
      expect(victoryExperience([7, 7]), 128);
      expect(victoryExperience([]), 0);
    });

    test('the floor is 1 per enemy, never 0', () {
      expect(victoryExperience([0, 0, 0]), 3);
    });

    test('the reward tracks table position, which is the original quirk', () {
      // Orc (id 0, level 1) is worth 1; Earth Worm (id 3, level 1) is
      // worth 8. Same level, eight times the reward.
      expect(victoryExperience([enemyByKey['orc']!.legacyId]), 1);
      expect(victoryExperience([enemyByKey['earth_worm']!.legacyId]), 8);
      expect(enemyByKey['orc']!.level, enemyByKey['earth_worm']!.level);
    });
  });

  group('formula 17 - gold (battle.dart:294)', () {
    test('is five times the level, summed', () {
      expect(goldReward([1, 2, 30]), 165);
      expect(goldReward([]), 0);
    });
  });

  group('formula 18 - enemy starting hit points (enemy.dart:41-42)', () {
    test('is endurance x level', () {
      expect(enemyInitialHp(endurance: 8, level: 1), 8);
      expect(enemyInitialHp(endurance: 60, level: 30), 1800);
    });

    test('a zero product still starts at 1', () {
      expect(enemyInitialHp(endurance: 0, level: 5), 1);
      expect(enemyInitialHp(endurance: 5, level: 0), 1);
    });
  });
}
