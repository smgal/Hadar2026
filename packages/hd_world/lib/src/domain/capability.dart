import 'wire.dart';

/// Something the party can do that it otherwise could not.
///
/// ## Why capabilities and modifiers are different things
///
/// A modifier moves a number for its wearer. A capability answers a
/// yes-or-no question, and three of them answer it **for the whole
/// party** — the party is one token on a map, so one member walking on
/// water while the rest sink is not a state anything can draw.
///
/// So the scope is a property of the capability, not of the slot it
/// came from. [isPartyWide] says which.
enum Capability implements Wired {
  /// Cross shallow water.
  walkOnWater(0),

  /// Cross poisoned ground without taking the poison.
  walkOnSwamp(1),

  /// Enter a cliff tile, drift across it, and land from a fall unhurt.
  levitate(2),

  /// Hold a light. Unlike the three above this stacks — see
  /// [stacksAcrossMembers].
  carryLight(3),

  /// Read what a creature is before striking it.
  senseWeakness(4);

  const Capability(this.wire);

  @override
  final int wire;

  static Capability? fromWire(int wire) => byWire(values, wire);

  /// Whether one member having it is enough for everyone.
  bool get isPartyWide => this != senseWeakness;

  /// Whether a second holder adds anything.
  ///
  /// Only light does. Two water amulets are one water amulet; two
  /// torches are a wider circle. That asymmetry is deliberate and is
  /// the one thing that makes carrying a torch a per-member decision
  /// rather than a party-level one.
  bool get stacksAcrossMembers => this == carryLight;
}
