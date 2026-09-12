import '../data/item_catalog.dart';
import '../domain/capability.dart';
import '../domain/member.dart';
import 'stat_resolution.dart';

/// What the party can do, read off what its members are wearing.
///
/// ## Computed, never stored
///
/// The predecessor kept four counters for this and three of them were
/// written by nothing, read by nothing, or both — a walk-on-water field
/// whose only writer had been lost, so shallow water was unreachable by
/// any route. A function cannot rot that way: delete the amulet and the
/// answer changes on the next call.
class PartyAbilities {
  const PartyAbilities({
    required this.capabilities,
    required this.lightBearers,
    required this.magicLight,
  });

  /// Everything at least one member's gear grants that reaches the whole
  /// party.
  final Set<Capability> capabilities;

  /// How many members are holding a light. **This one counts** — see
  /// [Capability.stacksAcrossMembers].
  final int lightBearers;

  /// Whether a spell is lighting the way as well.
  final bool magicLight;

  bool can(Capability c) => capabilities.contains(c);
}

/// Reads the party.
///
/// [magicLight] comes from outside because a spell's remaining duration
/// is not equipment — it belongs to whatever tracks spell effects, and
/// this package deliberately does not.
PartyAbilities readAbilities({
  required Iterable<Member> members,
  required ItemCatalog catalog,
  bool magicLight = false,
}) {
  final caps = <Capability>{};
  var bearers = 0;
  for (final m in members) {
    final resolved = resolveStats(member: m, catalog: catalog);
    for (final c in resolved.granted) {
      if (c.isPartyWide) caps.add(c);
    }
    if (carriesLight(member: m, catalog: catalog)) bearers++;
  }
  return PartyAbilities(
    capabilities: caps,
    lightBearers: bearers,
    magicLight: magicLight,
  );
}

/// How far the party sees, and whether the far tiles are dim or black.
class LightLevel {
  const LightLevel({required this.radius, required this.moonlight});

  final int radius;
  final bool moonlight;
}

/// The brightest sight radius, and the dimmest.
const int maxSightRadius = 5;
const int darkSightRadius = 1;

/// What a spell-lit party sees. **Below one real light on purpose** —
/// the spell costs no hand, so it must not also be as good.
const int magicLightRadius = 2;

/// Sight in the dark.
///
/// | held lights | radius | far tiles |
/// |---|---|---|
/// | 0 | 1 | black |
/// | 1 | 3 | black |
/// | 2 | 4 | dim |
/// | 3 or more | 5 | dim |
///
/// A spell alone gives 2 and never dims the distance. Whichever source
/// is brighter wins; they do not add.
LightLevel lightInDarkness(PartyAbilities abilities) {
  var radius = darkSightRadius;
  var moonlight = false;
  if (abilities.lightBearers > 0) {
    radius = 2 + abilities.lightBearers;
    if (radius > maxSightRadius) radius = maxSightRadius;
    moonlight = abilities.lightBearers >= 2;
  }
  if (abilities.magicLight && radius < magicLightRadius) {
    radius = magicLightRadius;
  }
  return LightLevel(radius: radius, moonlight: moonlight);
}
