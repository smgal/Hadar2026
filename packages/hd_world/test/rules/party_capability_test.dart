import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

Member who(String ref, Map<EquipSlot, String> wearing) => Member(
  ref: MemberRef(ref),
  name: ref,
  clazz: CharacterClass.knight,
  baseMaxHitPoints: 50,
  equipment: {for (final e in wearing.entries) e.key: ItemRef(e.value)},
);

PartyAbilities read(List<Member> ms, {bool magic = false}) => readAbilities(
  members: ms,
  catalog: ItemCatalog.builtIn,
  magicLight: magic,
);

void main() {
  test('one amulet is enough for the whole party', () {
    final abilities = read([
      who('a', {EquipSlot.commonAmulet: 'commonAmulet.water'}),
      who('b', const {}),
      who('c', const {}),
    ]);
    expect(abilities.can(Capability.walkOnWater), isTrue);
    expect(abilities.can(Capability.walkOnSwamp), isFalse);
  });

  test('a second copy of the same amulet adds nothing', () {
    final one = read([
      who('a', {EquipSlot.commonAmulet: 'commonAmulet.marsh'}),
    ]);
    final two = read([
      who('a', {EquipSlot.commonAmulet: 'commonAmulet.marsh'}),
      who('b', {EquipSlot.commonAmulet: 'commonAmulet.marsh'}),
    ]);
    expect(two.capabilities, one.capabilities);
  });

  test('a fallen member still carries what is round their neck', () {
    // Losing water-walking mid-lake because the wearer was knocked out
    // is not a rule anyone would want to live with.
    final fallen = who('a', {EquipSlot.commonAmulet: 'commonAmulet.water'})
      ..hitPoints = 0;
    expect(fallen.isConscious, isFalse);
    expect(read([fallen]).can(Capability.walkOnWater), isTrue);
  });

  test('lights are the one thing that stacks', () {
    List<Member> bearers(int n) => [
      for (var i = 0; i < n; i++)
        who('m$i', {
          EquipSlot.rightHand: 'weapon.sabre',
          EquipSlot.leftHand: 'light.torch',
        }),
    ];
    expect(read(bearers(0)).lightBearers, 0);
    expect(read(bearers(3)).lightBearers, 3);
  });

  test('the brightness table', () {
    LightLevel forBearers(int n, {bool magic = false}) => lightInDarkness(
      read([
        for (var i = 0; i < n; i++)
          who('m$i', {
            EquipSlot.rightHand: 'weapon.sabre',
            EquipSlot.leftHand: 'light.torch',
          }),
        who('other', const {}),
      ], magic: magic),
    );

    expect(forBearers(0).radius, 1);
    expect(forBearers(1).radius, 3);
    expect(forBearers(2).radius, 4);
    expect(forBearers(3).radius, 5);
    expect(forBearers(5).radius, 5, reason: 'never brighter than daylight');

    expect(forBearers(0).moonlight, isFalse);
    expect(forBearers(1).moonlight, isFalse);
    expect(forBearers(2).moonlight, isTrue);
  });

  test('a spell is dimmer than one real light and never dims the distance', () {
    // It costs no hand, so it must not also be as good.
    final spellOnly = lightInDarkness(read([who('a', const {})], magic: true));
    expect(spellOnly.radius, magicLightRadius);
    expect(spellOnly.radius, lessThan(3));
    expect(spellOnly.moonlight, isFalse);
  });

  test('the brighter source wins; they do not add', () {
    final both = lightInDarkness(
      read([
        who('a', {
          EquipSlot.rightHand: 'weapon.sabre',
          EquipSlot.leftHand: 'light.torch',
        }),
      ], magic: true),
    );
    expect(both.radius, 3);
  });

  test('a two-handed weapon means no light, however many are carried', () {
    final abilities = read([
      who('a', {
        EquipSlot.rightHand: 'weapon.long_sword',
        EquipSlot.leftHand: 'light.torch',
      }),
    ]);
    expect(abilities.lightBearers, 0);
    expect(lightInDarkness(abilities).radius, 1);
  });

  test('a wearer-only capability does not reach the party', () {
    expect(Capability.senseWeakness.isPartyWide, isFalse);
    for (final c in const [
      Capability.walkOnWater,
      Capability.walkOnSwamp,
      Capability.levitate,
    ]) {
      expect(c.isPartyWide, isTrue, reason: c.name);
      expect(c.stacksAcrossMembers, isFalse, reason: c.name);
    }
  });
}
