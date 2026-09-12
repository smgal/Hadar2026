import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

World sample() => World(
  members: [for (final t in sampleParty) t.build()],
  pack: Pack(
    capacity: 40,
    counts: {for (final e in samplePack.entries) ItemRef(e.key): e.value},
  ),
);

void main() {
  test('a world survives the round trip whole', () {
    final before = sample();
    before.apply(
      const EquipFromPack(
        member: MemberRef('knight'),
        slot: EquipSlot.leftHand,
        item: ItemRef('light.torch'),
      ),
    );
    before.apply(
      const SetStyle(
        member: MemberRef('magician'),
        style: FightingStyle.mend,
        thrift: true,
      ),
    );
    before.magicLight = true;

    final result = loadWorld(saveWorld(before));
    expect(result.isClean, isTrue, reason: '${result.issues}');
    // The derived answers have to come out the same, which is the real
    // test: the save carries none of them.
    expect(saveWorld(result.world).toString(), saveWorld(before).toString());
    expect(
      result.world.view.toJson().toString(),
      before.view.toJson().toString(),
    );
  });

  test('nothing derived is written down', () {
    final json = saveWorld(sample());
    final member = (json['members'] as List).first as Map<String, Object?>;
    for (final forbidden in const [
      'weaponKind',
      'attackPower',
      'stats.defence',
      'allowedStyles',
      'grants',
      'offHandLocked',
    ]) {
      expect(member.containsKey(forbidden), isFalse, reason: forbidden);
    }
    // Nor party-level answers.
    expect(json.containsKey('party'), isFalse);
    expect(json['version'], saveVersion);
  });

  test('an item this build has no row for empties the slot and says so', () {
    final json = saveWorld(sample());
    final member = (json['members'] as List).first as Map<String, Object?>;
    (member['equipment']! as Map)['${EquipSlot.head.wire}'] =
        'helmet.crown_of_a_later_build';

    final result = loadWorld(json);
    expect(result.isClean, isFalse);
    expect(result.issues.first.item, 'helmet.crown_of_a_later_build');
    expect(result.issues.first.member, 'knight');
    // Emptied, not folded into something else.
    expect(result.world.members.first.at(EquipSlot.head), isNull);
    // And the rest of the member came through.
    expect(result.world.members.first.at(EquipSlot.body), isNotNull);
  });

  test('a pack item this build lacks is reported, not carried', () {
    final json = saveWorld(sample());
    (((json['pack']! as Map)['counts'])! as Map)['weapon.moonrazor'] = 2;
    final result = loadWorld(json);
    expect(result.issues.map((i) => i.item), contains('weapon.moonrazor'));
    expect(result.world.pack.has(const ItemRef('weapon.moonrazor')), isFalse);
    expect(result.world.pack.has(const ItemRef('weapon.dagger')), isTrue);
  });

  test('a wrong version loads anyway and mentions it', () {
    final json = saveWorld(sample())..['version'] = 99;
    final result = loadWorld(json);
    expect(result.issues.first.message, contains('version'));
    expect(result.world.members.length, 5);
  });

  test('a truncated save loses only what is missing', () {
    // Throwing here would lose the rest of the party, which is worse.
    final result = loadWorld({
      'version': saveVersion,
      'members': [
        {'ref': 'lonely', 'name': 'Lonely', 'class': 2},
      ],
    });
    expect(result.world.members.length, 1);
    final m = result.world.members.single;
    expect(m.clazz, CharacterClass.knight);
    expect(m.levels.physical, 1, reason: 'a sensible default, not zero');
    expect(m.style, FightingStyle.assault);
    expect(result.world.pack.kindCount, 0);
  });

  test('an empty save is an issue rather than a crash', () {
    final result = loadWorld(const {});
    expect(result.world.members, isEmpty);
    expect(result.issues, isNotEmpty);
  });

  test('a slot number this build does not have is reported', () {
    final json = saveWorld(sample());
    final member = (json['members'] as List).first as Map<String, Object?>;
    (member['equipment']! as Map)['99'] = 'helmet.hood';
    final result = loadWorld(json);
    expect(result.issues.map((i) => i.message).join(), contains('slot'));
  });
}
