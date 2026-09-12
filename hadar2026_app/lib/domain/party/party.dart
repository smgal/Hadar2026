import 'package:flutter/foundation.dart';
import 'package:hd_world/hd_world.dart';

import 'starting_party.dart';

/// 일행이 지도 위에서 어디에 있는가.
class PartyPosition {
  int x = 0;
  int y = 0;
  int xPrev = 0;
  int yPrev = 0;
  int faced = 0; // 0: 아래, 1: 위, 2: 오른쪽, 3: 왼쪽
  bool isMoving = false;
}

/// 마법으로 걸어 둔 것의 남은 분량.
///
/// ## 두 출처 중 하나다
///
/// 통행 능력과 불은 **장비**로도 오고 **마법**으로도 온다(BP-47 §1). 장비 쪽은
/// `World` 를 훑어 계산하고, 이 클래스는 마법 쪽 잔량만 들고 있다. 「지금
/// 되는가」는 둘을 합쳐 답한다 — [HDParty.canWalkOnWater] 등.
///
/// 이전 모델은 이것을 **저장값 넷**으로 두었고 그중 셋이 썩었다: 물 위를 걷는
/// 값은 세우는 곳이 코드에도 cm2 에도 없어 0을 벗어날 수 없었고(부록 Z-4),
/// 부양과 늪은 읽는 규칙이 없었다.
class PartySpells {
  int magicTorch = 0;
  int levitation = 0;
  int walkOnWater = 0;
  int walkOnSwamp = 0;
  int mindControl = 0;
  int penetration = 0;
  bool canUseEsp = false;
  bool canUseSpecialMagic = false;

  Map<String, dynamic> toJson() => {
    'magicTorch': magicTorch,
    'levitation': levitation,
    'walkOnWater': walkOnWater,
    'walkOnSwamp': walkOnSwamp,
    'mindControl': mindControl,
    'penetration': penetration,
    'canUseEsp': canUseEsp,
    'canUseSpecialMagic': canUseSpecialMagic,
  };

  void fromJson(Map<String, dynamic> json) {
    magicTorch = json['magicTorch'] ?? 0;
    levitation = json['levitation'] ?? 0;
    walkOnWater = json['walkOnWater'] ?? 0;
    walkOnSwamp = json['walkOnSwamp'] ?? 0;
    mindControl = json['mindControl'] ?? 0;
    penetration = json['penetration'] ?? 0;
    canUseEsp = json['canUseEsp'] ?? false;
    canUseSpecialMagic = json['canUseSpecialMagic'] ?? false;
  }
}

/// 일행.
///
/// ## 명부와 가방은 이 클래스의 것이 아니다
///
/// 사람과 물건은 [world] 가 갖는다(`packages/hd_world`, 순수 Dart). 이 클래스가
/// 갖는 것은 **지도 위의 상태**다 — 위치 · 식량 · 돈 · 조우 설정 · 마법 잔량.
///
/// 장비를 바꾸는 것은 [world] 에 **명령**을 넣는 것이고, 최종 수치는 읽을 때
/// 계산된다. 그래서 여기에 능력치 필드가 하나도 없다.
class HDParty extends ChangeNotifier {
  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) {
        super.notifyListeners();
      }
    });
  }

  /// 명부와 가방. 자리 여섯이고 빈 자리는 이름이 비어 있다.
  World world = buildStartingWorld();

  final PartyPosition _position = PartyPosition();
  final PartySpells _spells = PartySpells();

  int food = 100;
  int gold = 500;
  int maxEnemy = 3;
  int encounter = 3;

  // ---- 명부 -----------------------------------------------------------

  /// 자리 여섯. 빈 자리도 들어 있다 — 자리 번호가 곧 신원이라
  /// 접으면 cm2 가 손보는 사람이 옮겨진다.
  List<Member> get members => world.members;

  /// 실제로 앉아 있는 사람만.
  Iterable<Member> get present => members.where((m) => m.isPresent);

  /// 그 자리의 사람. 범위를 벗어나면 null.
  Member? seat(int index) =>
      index >= 0 && index < members.length ? members[index] : null;

  ItemCatalog get catalog => world.catalog;

  // ---- 가방 -----------------------------------------------------------

  Pack get pack => world.pack;

  int get itemCapacity => pack.capacity;
  int get itemCount => pack.kindCount;

  bool has(ItemRef ref) => pack.has(ref);
  int countOf(ItemRef ref) => pack.countOf(ref);

  /// 물건을 넣는다. 가방이 가득 차면 false 이고 아무것도 버리지 않는다.
  bool give(ItemRef ref, [int count = 1]) {
    final events = world.apply(GiveItem(item: ref, count: count));
    final ok = events.whereType<CommandRefused>().isEmpty;
    if (ok) notifyListeners();
    return ok;
  }

  /// 물건을 뺀다. 없으면 false 이고 아무것도 바뀌지 않는다.
  bool take(ItemRef ref, [int count = 1]) {
    final events = world.apply(TakeItem(item: ref, count: count));
    final ok = events.whereType<CommandRefused>().isEmpty;
    if (ok) notifyListeners();
    return ok;
  }

  /// 장비를 바꾼다. 거절 이유가 있으면 그것을 돌려준다.
  RefusalReason? equip(Member member, EquipSlot slot, ItemRef ref) {
    final events = world.apply(
      EquipFromPack(member: member.ref, slot: slot, item: ref),
    );
    final refused = events.whereType<CommandRefused>().firstOrNull;
    if (refused == null) notifyListeners();
    return refused?.reason;
  }

  /// 장비를 벗긴다. 거절 이유가 있으면 그것을 돌려준다.
  RefusalReason? unequip(Member member, EquipSlot slot) {
    final events = world.apply(
      UnequipToPack(member: member.ref, slot: slot),
    );
    final refused = events.whereType<CommandRefused>().firstOrNull;
    if (refused == null) notifyListeners();
    return refused?.reason;
  }

  /// 그 자리에 채울 수 있는 것.
  List<ItemRef> candidates(Member member, EquipSlot slot) =>
      world.candidates(member.ref, slot);

  // ---- 마법 잔량과 「지금 되는가」 ---------------------------------------

  PartySpells get spells => _spells;

  int get magicTorch => _spells.magicTorch;
  set magicTorch(int value) => _spells.magicTorch = value;
  int get levitation => _spells.levitation;
  set levitation(int value) => _spells.levitation = value;
  int get walkOnWater => _spells.walkOnWater;
  set walkOnWater(int value) => _spells.walkOnWater = value;
  int get walkOnSwamp => _spells.walkOnSwamp;
  set walkOnSwamp(int value) => _spells.walkOnSwamp = value;
  int get mindControl => _spells.mindControl;
  set mindControl(int value) => _spells.mindControl = value;
  int get penetration => _spells.penetration;
  set penetration(int value) => _spells.penetration = value;
  bool get canUseEsp => _spells.canUseEsp;
  set canUseEsp(bool value) => _spells.canUseEsp = value;
  bool get canUseSpecialMagic => _spells.canUseSpecialMagic;
  set canUseSpecialMagic(bool value) => _spells.canUseSpecialMagic = value;

  /// 장비가 주는 것. 한 사람이 차면 전체가 얻는다.
  PartyAbilities get abilities => readAbilities(
    members: present,
    catalog: catalog,
    magicLight: _spells.magicTorch > 0,
  );

  /// 얕은 물을 지날 수 있는가 — 부적이든 마법이든.
  bool get canWalkOnWater =>
      _spells.walkOnWater > 0 || abilities.can(Capability.walkOnWater);

  /// 늪의 독을 견디는가.
  bool get canWalkOnSwamp =>
      _spells.walkOnSwamp > 0 || abilities.can(Capability.walkOnSwamp);

  /// 절벽에 들어갈 수 있는가.
  bool get canLevitate =>
      _spells.levitation > 0 || abilities.can(Capability.levitate);

  /// 어둠 속 시야와 달빛.
  LightLevel get light => lightInDarkness(abilities);

  // ---- 위치 -----------------------------------------------------------

  int get x => _position.x;
  set x(int value) => _position.x = value;
  int get y => _position.y;
  set y(int value) => _position.y = value;
  int get xPrev => _position.xPrev;
  set xPrev(int value) => _position.xPrev = value;
  int get yPrev => _position.yPrev;
  set yPrev(int value) => _position.yPrev = value;
  int get faced => _position.faced;
  set faced(int value) => _position.faced = value;
  bool get isMoving => _position.isMoving;
  set isMoving(bool value) => _position.isMoving = value;

  void setPosition(int newX, int newY) {
    xPrev = x;
    yPrev = y;
    x = newX;
    y = newY;
    notifyListeners();
  }

  void move(int dx, int dy) {
    xPrev = x;
    yPrev = y;
    x += dx;
    y += dy;
    setFace(dx, dy);
  }

  void setFace(int dx, int dy) {
    if (dy > 0) {
      faced = 0;
    } else if (dy < 0) {
      faced = 1;
    } else if (dx > 0) {
      faced = 2;
    } else if (dx < 0) {
      faced = 3;
    }
    notifyListeners();
  }

  void warpToPrev() {
    x = xPrev;
    y = yPrev;
    notifyListeners();
  }

  // ---- 세이브 ---------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'xPrev': xPrev,
    'yPrev': yPrev,
    'faced': faced,
    'maxEnemy': maxEnemy,
    'encounter': encounter,
    'food': food,
    'gold': gold,
    ..._spells.toJson(),
    // ---- v3: 명부와 가방은 hd_world 가 쓴다 ----
    'world': saveWorld(world),
  };

  /// 되읽는다. 읽지 못한 것은 [issues] 로 나온다 — 조용히 빠지지 않는다.
  List<LoadIssue> fromJson(Map<String, dynamic> json) {
    x = json['x'] ?? 0;
    y = json['y'] ?? 0;
    xPrev = json['xPrev'] ?? 0;
    yPrev = json['yPrev'] ?? 0;
    faced = json['faced'] ?? 0;
    maxEnemy = json['maxEnemy'] ?? 3;
    encounter = json['encounter'] ?? 3;
    food = json['food'] ?? 100;
    gold = json['gold'] ?? 500;
    _spells.fromJson(json);

    final issues = <LoadIssue>[];
    final raw = json['world'];
    if (raw is Map) {
      final result = loadWorld(raw.cast<String, Object?>());
      world = result.world;
      issues.addAll(result.issues);
    } else {
      // v1·v2 페이로드다. 명부를 옮기는 것은 세이브 관리자의 일이고
      // (`save_manager.dart`), 여기서는 새 게임으로 시작한다.
      issues.add(
        const LoadIssue('the save predates the roster format; a new party'),
      );
      world = buildStartingWorld();
    }
    notifyListeners();
    return issues;
  }

  // ---- 시간 -----------------------------------------------------------

  void timeGoes() {
    if (mindControl > 0) mindControl--;
    if (levitation > 0) levitation--;
    if (penetration > 0) penetration--;

    for (final member in present) {
      if (member.poison > 0) {
        member.poison++;
        if (member.poison > 10) {
          member.poison = 1;
          member.hitPoints -= 1;
          if (member.hitPoints <= 0) {
            member.hitPoints = 0;
            member.unconscious = 1;
          }
        }
      }
    }

    notifyListeners();
  }
}
