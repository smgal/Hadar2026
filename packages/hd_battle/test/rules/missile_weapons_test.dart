import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// W1-06 — the rows added so a fighting style can always be handed over.
///
/// The gap they close: the original ships seven missile weapons and this
/// table had none, so a hunter with a bow had no key at all.
void main() {
  WeaponProfile w(String key) => weaponTable[key]!;

  test('the four missile styles exist and reach past the front line', () {
    expect(w('bow').longestReach, 3);
    expect(w('crossbow').longestReach, 3);
    expect(w('arbalest').longestReach, 3);
    expect(w('thrown').longestReach, 2);
  });

  test('a bow is helpless up close and a crossbow is not', () {
    // The whole trade between them.
    expect(chooseAttack(w('bow'), 0).power, 40);
    expect(chooseAttack(w('bow'), 2).power, 90);
    expect(chooseAttack(w('crossbow'), 0).power, 85);
    expect(chooseAttack(w('crossbow'), 3).power, 85);
  });

  test('an arbalest hits hardest and only from a distance', () {
    expect(chooseAttack(w('arbalest'), 3).power, 130);
    expect(chooseAttack(w('arbalest'), 1).power, 45);
    // Nothing else in the table hits that hard.
    final strongest = weaponTable.values
        .expand((p) => p.attacks)
        .map((a) => a.power)
        .reduce((a, b) => a > b ? a : b);
    expect(strongest, 130);
  });

  test('a shield is a second way to strike', () {
    // Which is what gives a swordsman an answer to bone and stone.
    final bash = w('sword_shield').attacks.last;
    expect(bash.method, AttackMethod.blunt);
    expect(bash.power, 55);
    expect(chooseAttack(w('sword_shield'), 0).method, AttackMethod.slash);
    expect(chooseAttack(w('sword_shield'), 1).method, AttackMethod.slash);
  });

  test('a one-handed spear holds the line at arm\'s length', () {
    expect(chooseAttack(w('spear'), 2).power, 100);
    expect(chooseAttack(w('spear'), 0).power, 60);
  });

  test('the war hammer charges and the mace does not', () {
    expect(w('war_hammer').canCharge, isTrue);
    expect(w('mace').canCharge, isFalse);
  });

  test('every new row answers at every distance', () {
    // The B5 invariant, restated for the rows just added.
    for (final key in const [
      'one_hand_slash',
      'sword_shield',
      'spear',
      'war_hammer',
      'bow',
      'crossbow',
      'arbalest',
      'thrown',
    ]) {
      for (var d = 0; d <= longestPossibleReach; d++) {
        expect(chooseAttack(w(key), d).power, greaterThan(0), reason: '$key at $d');
      }
    }
  });

  test('nothing that already existed changed', () {
    // The enemy table and every fixture keep the keys they used.
    for (final key in const [
      'unarmed',
      'dagger',
      'club',
      'mace',
      'staff',
      'long_sword',
      'flame_sword',
      'halberd',
      'poleaxe',
      'trident',
      'lance',
      'great_sword',
    ]) {
      expect(weaponTable.containsKey(key), isTrue, reason: key);
    }
    expect(weaponTable.length, 20);
  });
}
