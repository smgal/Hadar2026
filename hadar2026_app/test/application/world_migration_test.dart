import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/game_session.dart';
import 'package:hadar2026_app/domain/party/level_up.dart' as rule;
import 'package:hadar2026_app/domain/party/member_display.dart';
import 'package:hadar2026_app/domain/party/party.dart';
import 'package:hadar2026_app/domain/party/party_actions.dart';
import 'package:hadar2026_app/domain/party/starting_party.dart';
import 'package:hd_bridge/hd_bridge.dart' as bridge;
import 'package:hd_world/hd_world.dart';
import 'package:hd_world_legacy/hd_world_legacy.dart' as legacy;

/// W1-09 — 앱이 새 모델 위에서 도는지.
///
/// 화면 없이 확인할 수 있는 것만 본다: 명부·가방·장비·통행 능력·전투 다리·
/// 세이브. 눈으로만 확인되는 것은 상태 패널의 배치뿐이다.
BaseStats m0(HDParty party) => party.members.first.stats;

void main() {
  test('시작 파티는 자리 여섯에 두 사람이다', () {
    final party = HDParty();
    expect(party.members.length, partyCapacity);
    expect(party.present.length, 2);
    // **빈 자리를 접지 않는다** — 출하 스크립트가 여섯째 자리를 미리 손본다.
    expect(party.members.last.isPresent, isFalse);
    expect(party.seat(5), isNotNull);
  });

  test('직업 번호가 원작 것이다 (부록 Z-7)', () {
    final party = HDParty();
    // 이전 모델은 0 = 에스퍼였고 출하 스크립트는 8 을 쓴다. 8 이 에스퍼다.
    expect(party.members.first.clazz, CharacterClass.esper);
    expect(party.members.first.clazz.wire, 8);
    expect(party.members.first.getClassName(), '에스퍼');
    // 그리고 이제 cm2 가 정한 직업이 「알 수 없음」이 되지 않는다.
    final r = legacy.writeAttribute(party.members[2], 'class', 9);
    expect(r.verdict, legacy.AttributeVerdict.applied);
    expect(party.members[2].getClassName(), '검사');
  });

  test('시작 장비와 가방이 새 카탈로그에서 온다', () {
    final party = HDParty();
    final seumgal = party.members.first;
    expect(seumgal.getWeaponName(), '단도');
    expect(seumgal.getArmorName(), '가죽 갑옷');
    // 방어는 타고난 것 + 입은 것이다. `baseAc` 가 `baseDefence` 로 왔다.
    expect(seumgal.defence, 5 + 1);
    expect(party.countOf(const ItemRef('consumable.potion')), 3);
  });

  test('장비를 바꾸면 최종 수치가 바로 따라온다', () {
    final party = HDParty();
    final m = party.members.first;
    expect(party.give(const ItemRef('bodyArmour.gold')), isTrue);
    expect(party.equip(m, EquipSlot.body, const ItemRef('bodyArmour.gold')),
        isNull);
    expect(m.defence, 5 + 5);
    // 벗은 것이 가방으로 돌아온다 — 사라지지 않는다.
    expect(party.has(const ItemRef('bodyArmour.leather')), isTrue);
  });

  test('양손 무기를 들면 왼손이 잠기고 이유가 나온다', () {
    final party = HDParty();
    final m = party.members.first;
    party.give(const ItemRef('weapon.long_sword'));
    party.give(const ItemRef('shield.leather'));
    expect(party.equip(m, EquipSlot.leftHand, const ItemRef('shield.leather')),
        isNull);
    expect(
      party.equip(m, EquipSlot.rightHand, const ItemRef('weapon.long_sword')),
      isNull,
    );
    // 방패가 가방으로 돌아가고 칸이 잠긴다.
    expect(m.at(EquipSlot.leftHand), isNull);
    expect(isOffHandLocked(m, party.catalog), isTrue);
    expect(
      party.equip(m, EquipSlot.leftHand, const ItemRef('shield.leather')),
      RefusalReason.offHandLocked,
    );
    expect(m.weaponKindName, '대검');
  });

  test('직업 부적은 남의 것을 거절하고 자리 오류와 다른 답이다', () {
    final party = HDParty();
    final m = party.members.first; // 에스퍼
    party.give(const ItemRef('classAmulet.oath_crest')); // 기사 것
    expect(
      party.equip(m, EquipSlot.classAmulet1,
          const ItemRef('classAmulet.oath_crest')),
      RefusalReason.wrongClass,
    );
    expect(
      party.equip(m, EquipSlot.commonAmulet,
          const ItemRef('classAmulet.oath_crest')),
      RefusalReason.wrongSlot,
    );
  });

  test('통행 능력은 부적과 마법 두 출처를 합친다 (BP-47 §7.2)', () {
    final party = HDParty();
    expect(party.canWalkOnWater, isFalse);

    // 마법 쪽 — 칸 수로 센다.
    party.walkOnWater = 3;
    expect(party.canWalkOnWater, isTrue);
    party.walkOnWater = 0;
    expect(party.canWalkOnWater, isFalse);

    // 장비 쪽 — 한 사람이 차면 전체가 얻는다.
    party.give(const ItemRef('commonAmulet.water'));
    expect(
      party.equip(party.members[1], EquipSlot.commonAmulet,
          const ItemRef('commonAmulet.water')),
      isNull,
    );
    expect(party.canWalkOnWater, isTrue);
    expect(party.canWalkOnSwamp, isFalse, reason: '다른 부적은 다른 지형이다');
  });

  test('횃불은 든 사람 수만큼 밝아진다', () {
    final party = HDParty();
    expect(party.light.radius, 1);
    for (final m in party.present) {
      party.give(const ItemRef('light.torch'));
      expect(party.equip(m, EquipSlot.leftHand, const ItemRef('light.torch')),
          isNull);
    }
    expect(party.abilities.lightBearers, 2);
    expect(party.light.radius, 4);
    expect(party.light.moonlight, isTrue);
    // 마법의 횃불은 그보다 약하다.
    party.magicTorch = 10;
    expect(party.light.radius, 4, reason: '큰 쪽을 쓰고 더하지 않는다');
  });

  test('전투 다리가 파티를 개시 입력으로 바꾼다', () {
    final party = HDParty();
    final setup = bridge.toBattleSetup(
      party.world,
      enemyKeys: const ['orc'],
      seed: 1,
    );
    // 앉아 있는 두 사람만 나가고 자리 번호는 그대로다.
    expect(setup.party.length, 2);
    expect([for (final p in setup.party) p.slot], [0, 1]);
    expect(setup.party.first.weaponKey, 'dagger');
    expect(setup.party.first.powOfWeapon, 10);
    expect(setup.partyCapacity, partyCapacity);
    // 가방의 소비품이 투영된다.
    expect(setup.consumables['potion'], 3);
  });

  test('쉬면 낫고 마법 잔량만 줄어든다', () {
    final party = HDParty()..food = 10;
    final m = party.members.first..hitPoints = 10;
    party.give(const ItemRef('commonAmulet.water'));
    party.equip(party.members[1], EquipSlot.commonAmulet,
        const ItemRef('commonAmulet.water'));
    party.magicTorch = 3;
    party.walkOnWater = 2;

    for (final member in party.present) {
      rule.checkLevelUp(member, catalog: party.catalog);
    }
    final result = HDPartyActions.restMember(m, party);
    expect(result.outcome, isNot(RestOutcome.noFood));
    expect(m.hitPoints, greaterThan(10));

    HDPartyActions.applyRestHousekeeping(party);
    expect(party.magicTorch, 2, reason: '마법은 준다');
    expect(party.walkOnWater, 0, reason: '마법은 지워진다');
    expect(party.canWalkOnWater, isTrue, reason: '부적은 쉬어도 그대로다');
  });

  test('레벨이 올라도 최대 체력이 줄지 않는다 (부록 Z-8)', () {
    // 원작 공식은 `인내력 × 레벨` 이고 슴갈의 시작값 150 은 그것과 맞지
    // 않는다(15 × 1 = 15). 그대로 덮어쓰면 처음 레벨 2가 되는 순간
    // 150 이 34 로 떨어졌다 — 레벨을 올리면 약해지는 것은 결함이다.
    final party = HDParty();
    final m = party.members.first..experience = 1500;
    final before = m.maxHitPoints;
    expect(before, 150);
    final r = rule.checkLevelUp(m, catalog: party.catalog);
    expect(r.leveledUp, isTrue);
    expect(r.toLevel, 2);
    expect(m.maxHitPoints, greaterThanOrEqualTo(before));
    expect(m.hitPoints, m.maxHitPoints, reason: '오르면 가득 찬다');
  });

  test('공식이 시작값을 넘으면 그때부터 공식이 자란다', () {
    // 낮은 값에서 시작한 사람은 공식대로 자란다 — 상한을 막은 것이
    // 성장을 막은 것은 아니다.
    final party = HDParty();
    final m = party.members.first
      ..baseMaxHitPoints = 10
      ..stats = m0(party).copyWith(endurance: 20)
      ..experience = 1500;
    rule.checkLevelUp(m, catalog: party.catalog);
    expect(m.maxHitPoints, 22 * 2, reason: '인내력 22 × 레벨 2');
  });

  test('세이브가 명부와 가방을 왕복한다', () {
    final party = HDParty()
      ..food = 42
      ..gold = 7
      ..magicTorch = 5;
    party.give(const ItemRef('light.torch'));
    party.equip(party.members.first, EquipSlot.leftHand,
        const ItemRef('light.torch'));

    final json = party.toJson();
    final back = HDParty();
    final issues = back.fromJson(json);
    expect(issues, isEmpty, reason: '$issues');
    expect(back.food, 42);
    expect(back.gold, 7);
    expect(back.magicTorch, 5);
    expect(back.members.first.at(EquipSlot.leftHand)?.value, 'light.torch');
    expect(back.members.length, partyCapacity);
    expect(back.light.radius, 3);
  });

  test('옛 세이브는 새 파티로 시작하고 그것을 알린다', () {
    // v1·v2 페이로드에는 'world' 가 없다. 조용히 빈 파티가 되지 않는다.
    final back = HDParty();
    final issues = back.fromJson({'x': 3, 'y': 4, 'food': 9});
    expect(issues, isNotEmpty);
    expect(back.x, 3);
    expect(back.present.length, 2, reason: '새 게임의 파티로 시작한다');
  });

  test('세션이 파티 하나를 들고 있다', () {
    expect(HDGameSession().party.present.length, greaterThanOrEqualTo(1));
    expect(HDGameSession().party.world.catalog.length, greaterThan(80));
  });
}
