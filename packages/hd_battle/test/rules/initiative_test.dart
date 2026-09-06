import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B2-05. Initiative order — the first thing in the battle to read
/// `agility` for anything but running away.
void main() {
  List<Turn> order({
    required List<int> party,
    required List<int> enemies,
    List<bool>? partyActive,
    List<bool>? enemyActive,
    required List<int> draws,
  }) => orderOfBattle(
    partyAgility: party,
    partyActive: partyActive ?? List.filled(party.length, true),
    enemyAgility: enemies,
    enemyActive: enemyActive ?? List.filled(enemies.length, true),
    rng: ScriptedRng(draws),
  );

  test('the fastest goes first', () {
    final turns = order(party: [5], enemies: [30], draws: [0, 0]);
    expect(turns.first.side, Side.enemy);
    expect(turns.last.side, Side.party);
  });

  test('both sides are in one list', () {
    final turns = order(
      party: [10, 10],
      enemies: [10, 10],
      draws: [0, 0, 0, 0],
    );
    expect(turns.length, 4);
    expect(turns.where((t) => t.side == Side.party).length, 2);
    expect(turns.where((t) => t.side == Side.enemy).length, 2);
  });

  test('a slow character sometimes gets ahead - the jitter matters', () {
    // Agility 5 rolling 9 beats agility 12 rolling 0.
    final turns = order(party: [5], enemies: [12], draws: [9, 0]);
    expect(turns.first.side, Side.party);
  });

  test('the jitter cannot overturn a wide gap', () {
    for (var slowRoll = 0; slowRoll < initiativeJitter; slowRoll++) {
      for (var fastRoll = 0; fastRoll < initiativeJitter; fastRoll++) {
        final turns = order(
          party: [5],
          enemies: [30],
          draws: [slowRoll, fastRoll],
        );
        expect(
          turns.first.side,
          Side.enemy,
          reason: 'rolls $slowRoll / $fastRoll',
        );
      }
    }
  });

  test('ties go to the party, then to the lower index', () {
    final turns = order(party: [10, 10], enemies: [10], draws: [0, 0, 0]);
    expect(turns[0].side, Side.party);
    expect(turns[0].index, 0);
    expect(turns[1].side, Side.party);
    expect(turns[1].index, 1);
    expect(turns[2].side, Side.enemy);
  });

  test('only those who can act are listed', () {
    final turns = order(
      party: [10, 10],
      enemies: [10, 10],
      partyActive: [true, false],
      enemyActive: [false, true],
      draws: [0, 0],
    );
    expect(turns.length, 2);
    expect(turns.any((t) => t.side == Side.party && t.index == 1), isFalse);
    expect(turns.any((t) => t.side == Side.enemy && t.index == 0), isFalse);
  });

  test('draw order is fixed so the same seed reproduces', () {
    // Party draws first, then enemies - if that flipped, every later
    // draw in the battle would shift.
    final a = orderOfBattle(
      partyAgility: [1, 2],
      partyActive: const [true, true],
      enemyAgility: [3],
      enemyActive: const [true],
      rng: SeededRng(42),
    );
    final b = orderOfBattle(
      partyAgility: [1, 2],
      partyActive: const [true, true],
      enemyAgility: [3],
      enemyActive: const [true],
      rng: SeededRng(42),
    );
    expect(
      [for (final t in b) '${t.side}${t.index}:${t.initiative}'],
      [for (final t in a) '${t.side}${t.index}:${t.initiative}'],
    );
  });

  test('one draw per active combatant, none for the rest', () {
    final rng = SeededRng(1);
    orderOfBattle(
      partyAgility: [1, 2, 3],
      partyActive: const [true, false, true],
      enemyAgility: [4, 5],
      enemyActive: const [true, false],
      rng: rng,
    );
    expect(rng.draws, 3);
  });

  test('agility actually decides most of the time', () {
    // A 15-point gap with a 10-point jitter can never be overturned.
    var fastFirst = 0;
    for (var seed = 0; seed < 100; seed++) {
      final turns = orderOfBattle(
        partyAgility: const [8],
        partyActive: const [true],
        enemyAgility: const [23],
        enemyActive: const [true],
        rng: SeededRng(seed),
      );
      if (turns.first.side == Side.enemy) fastFirst++;
    }
    expect(fastFirst, 100);
  });
}
