import 'rng.dart';

/// Armour by slot, and the shield as its own axis (B2-08).
///
/// ## This is a decision, not a port
///
/// The original defends with a single number. `t.ac` is the only thing
/// the damage formula reads, and `powOfShield` / `powOfArmor` are read
/// **nowhere** — appendix H-1's corrected edition confirmed it and P0-19
/// filed them as dead fields.
///
/// H-1 also recorded what would have to change first: *"putting the
/// shield on its own axis, or introducing per-slot mitigation, needs a
/// change to the damage formula — and only then."* This is that change.
///
/// ## How it works
///
/// Worn armour splits in two:
///
/// * **[worn]** — body, head, legs and trinkets. Summed, and subtracted
///   the way `ac` always was. Being spread across four slots is what
///   makes each piece worth finding.
/// * **[shieldBlock]** — a **chance to stop the blow outright**, rolled
///   before damage. A shield is not more armour; it is a different
///   answer to being hit. This is what brings `powOfShield` back to
///   life.
class ArmourPieces {
  const ArmourPieces({
    this.body = 0,
    this.head = 0,
    this.leg = 0,
    this.ornament = 0,
    this.shieldBlock = 0,
  });

  final int body;
  final int head;
  final int leg;
  final int ornament;

  /// Percentage chance to block, from the shield's `powOfShield`.
  final int shieldBlock;

  /// The armour that subtracts from damage.
  int get worn => body + head + leg + ornament;

  bool get isEmpty =>
      body == 0 && head == 0 && leg == 0 && ornament == 0 && shieldBlock == 0;

  /// Falls back to a single total, so a snapshot that has not been split
  /// yet keeps behaving exactly as it did.
  factory ArmourPieces.fromTotal(int ac) => ArmourPieces(body: ac);

  Map<String, dynamic> toJson() => {
    'body': body,
    'head': head,
    'leg': leg,
    'ornament': ornament,
    'shieldBlock': shieldBlock,
  };

  factory ArmourPieces.fromJson(Map<String, dynamic> j) => ArmourPieces(
    body: j['body'] as int? ?? 0,
    head: j['head'] as int? ?? 0,
    leg: j['leg'] as int? ?? 0,
    ornament: j['ornament'] as int? ?? 0,
    shieldBlock: j['shieldBlock'] as int? ?? 0,
  );
}

/// Whether the shield turns the blow aside — `random(100) < shieldBlock`.
///
/// **No longer on the battle's path (B5-05).** Once the graze
/// multiplier existed this was the same idea twice: a shield block is a
/// graze of zero. The shield now feeds `evasionOf` instead, and a graze
/// that lands on zero is reported as a block. Kept because it states
/// the original B2-08 shape plainly and the tests still pin it.
///
/// Rolled before damage, so a good shield is worth more than the same
/// number of armour points: it stops the whole hit rather than shaving
/// it. Capped so no shield is a wall.
bool shieldBlocks({required int shieldBlock, required BattleRng rng}) {
  if (shieldBlock <= 0) return false;
  final chance = shieldBlock > maxShieldBlock ? maxShieldBlock : shieldBlock;
  return rng.next(100) < chance;
}

/// A shield never stops more than three blows in four.
const int maxShieldBlock = 75;
