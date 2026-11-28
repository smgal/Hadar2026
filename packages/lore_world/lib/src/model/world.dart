import 'dart:collection';
import 'dart:math';

import '../contract/events.dart';
import '../contract/outcome.dart';
import '../data/equipment_table.dart';
import '../data/item_table.dart';
import '../data/level_table.dart';
import '../domain/calendar.dart';
import '../domain/enums.dart';
import '../domain/member.dart';

part '../rules/party.dart';

/// 저장 형식의 판.
const int loreSaveVersion = 1;

/// 불러오기가 지키지 못한 것의 종류.
enum LoadIssueKind {
  /// 저장 데이터가 맵이 아니다.
  notAMap,

  /// 이 빌드보다 새 판에서 저장했다.
  newerVersion,

  /// 모르는 편 번호다. 제3부로 읽었다.
  unknownEpisode,

  /// 이 빌드에 없는 물품·크리스탈·장비 열쇠다. 버렸다.
  unknownItem,

  /// 대원이 이 빌드에 없는 장비를 들고 있다. 그 칸을 비웠다.
  unknownEquipment,
}

/// 불러오기가 지키지 못한 것 하나.
///
/// 불러오기는 던지지 않고, 조용히 버리지도 않는다. 이 빌드에 없는 물건을
/// 가리키는 저장은 실제로 일어난 일이므로 알린다.
final class LoadIssue {
  const LoadIssue(this.kind, {this.seat, this.key});

  final LoadIssueKind kind;
  final int? seat;
  final String? key;

  @override
  String toString() =>
      'LoadIssue(${kind.name}'
      '${seat == null ? '' : ', seat: $seat'}'
      '${key == null ? '' : ', key: $key'})';
}

final class LoadResult {
  const LoadResult(this.world, this.issues);

  final LoreWorld world;
  final List<LoadIssue> issues;

  bool get isClean => issues.isEmpty;
}

/// 저장 한 칸의 RPG 상태. 지도·플래그·위치는 여기 없다 — 그것은 앱과
/// 스크립트의 것이다.
///
/// ## 바꾸는 길
///
/// 규칙이 있는 변화(훈련·장비·상점·마법·휴식·걸음·일행 관리)는 전부
/// 이 클래스의 **명령**(확장 메서드)을 거치고, 명령은 던지지 않고
/// `Outcome` 을 돌려준다. 이야기가 주는 보상처럼 규칙이 없는 변화는
/// [give] · [addGold] 같은 손잡이나 필드를 직접 쓴다.
class LoreWorld {
  LoreWorld({
    required this.episode,
    List<Member?>? seats,
    this.gold = 0,
    this.food = 0,
    this.arrows = 0,
    Map<String, int>? consumables,
    Map<String, int>? crystals,
    Map<String, int>? backpack,
    LoreCalendar? calendar,
    int torch = 0,
    FieldBuffs? buffs,
    GameOptions? options,
    bool? espTrainingUnlocked,
    bool? specialMagicUnlocked,
  }) : _seats = List<Member?>.filled(Seat.count, null),
       _consumables = _initialCounts(
         consumables,
         (k) => consumableByKey(k) != null,
       ),
       _crystals = _initialCounts(crystals, (k) => crystalByKey(k) != null),
       _backpack = _initialCounts(backpack, (k) => equipSlotOf(k) != null),
       _torch = torch.clamp(0, torchLimit),
       calendar = calendar ?? LoreCalendar.startOf(episode),
       buffs = buffs ?? FieldBuffs(),
       options = options ?? GameOptions(),
       espTrainingUnlocked = espTrainingUnlocked ?? episode != Episode.ep1,
       specialMagicUnlocked = specialMagicUnlocked ?? episode != Episode.ep1 {
    if (seats != null) {
      for (var i = 0; i < Seat.count && i < seats.length; i++) {
        _seats[i] = seats[i];
      }
    }
  }

  /// 새 게임. 편마다 시작 시각과 소지품이 다르다.
  ///
  /// * 제3부 — 673년 11월 27일 16:00, 횃불 4, 빈손.
  /// * 제1부 — 771년 3월 1일 09:00, 식량 20 · 금화 2000.
  /// * 제2부 — 774년 1월 19일 10:10, 빈손.
  factory LoreWorld.newGame(Episode episode, Member protagonist) {
    final world = LoreWorld(episode: episode);
    world._seats[Seat.protagonist] = protagonist;
    switch (episode) {
      case Episode.ep1:
        world.food = 20;
        world.gold = 2000;
      case Episode.ep2:
        break;
      case Episode.ep3:
        world.setTorch(4);
    }
    return world;
  }

  Episode episode;

  final List<Member?> _seats;

  /// 읽기 전용 자리 목록. 0 주인공, 1~4 동료, 5 보조 일원, 빈 자리는 null.
  late final List<Member?> seats = UnmodifiableListView(_seats);

  int gold;
  int food;
  int arrows;

  final Map<String, int> _consumables;
  final Map<String, int> _crystals;
  final Map<String, int> _backpack;

  /// 물품 10종의 개수(열쇠 → 개수).
  late final Map<String, int> consumables = UnmodifiableMapView(_consumables);

  /// 크리스탈 9종의 개수.
  late final Map<String, int> crystals = UnmodifiableMapView(_crystals);

  /// 장비 배낭. **장착 중인 것은 여기 없다.**
  late final Map<String, int> backpack = UnmodifiableMapView(_backpack);

  LoreCalendar calendar;

  /// 횃불 세기(0~255).
  int get torch => _torch;
  int _torch;
  FieldBuffs buffs;
  GameOptions options;

  /// 초자연력 기술치를 올릴 수 있는가. 제1부는 스피카를 만나야 열린다.
  bool espTrainingUnlocked;

  /// 특수 마법을 쓸 수 있는가. 제1부는 레드 안타레스에게 배워야 열린다.
  /// 전투 쪽이 읽는다.
  bool specialMagicUnlocked;

  static const int torchLimit = 255;

  // ── 사람 ──────────────────────────────────────────────────

  /// 그 자리에 **지금 있는** 대원. 비었거나 숨겨졌으면 null.
  Member? member(int seat) {
    if (!Seat.isValid(seat)) return null;
    final m = seats[seat];
    if (m == null || m.hidden) return null;
    return m;
  }

  Member? get protagonist => member(Seat.protagonist);
  Member? get assistant => member(Seat.assistant);

  /// 지금 있는 대원의 자리 번호(0~5).
  List<int> get presentSeats => [
    for (var i = 0; i < Seat.count; i++)
      if (member(i) != null) i,
  ];

  /// 지금 있는 대원.
  List<Member> get presentMembers => [
    for (final seat in presentSeats) seats[seat]!,
  ];

  /// 명령을 받는 대원의 자리 — 0~4 중 행동 가능한 사람.
  List<int> get commandSeats => [
    for (var i = Seat.protagonist; i <= Seat.lastCompanion; i++)
      if (member(i)?.canAct ?? false) i,
  ];

  /// 명부의 그 인물이 앉은 자리. 일행에 없으면 null.
  ///
  /// 숨겨진 동료는 기본으로 **없는 사람**이다. [includeHidden] 을 주면
  /// 데이터가 남아 있는지까지 본다.
  int? seatOfRoster(String rosterKey, {bool includeHidden = false}) {
    for (var i = 0; i < Seat.count; i++) {
      final m = seats[i];
      if (m == null || m.rosterKey != rosterKey) continue;
      if (m.hidden && !includeHidden) continue;
      return i;
    }
    return null;
  }

  /// 명부의 그 인물이 지금 일행에 있는가(「카노푸스가 일행에 있는가」).
  bool hasRosterMember(String rosterKey, {bool includeHidden = false}) =>
      seatOfRoster(rosterKey, includeHidden: includeHidden) != null;

  /// 동료 빈자리 중 가장 앞 번호. 없으면 null.
  ///
  /// 숨겨진 동료의 자리는 **빈자리가 아니다** — 돌아올 사람의 자리다.
  int? get firstFreeCompanionSeat {
    for (var i = Seat.firstCompanion; i <= Seat.lastCompanion; i++) {
      if (seats[i] == null) return i;
    }
    return null;
  }

  /// 일행 전원(보조 일원 포함)이 행동할 수 없는가.
  bool get isGameOver {
    for (final m in presentMembers) {
      if (m.canAct) return false;
    }
    return true;
  }

  /// 지금 있는 대원 전원의 평균(내림). 도망은 행운, 선제는 민첩성.
  int average(Ability ability) {
    final members = presentMembers;
    if (members.isEmpty) return 0;
    var sum = 0;
    for (final m in members) {
      sum += m.ability(ability);
    }
    return sum ~/ members.length;
  }

  /// 0~4 중 행동 가능한 대원의 평균 레벨(내림). 아무도 없으면 0.
  int get averageCommandLevel {
    final list = commandSeats;
    if (list.isEmpty) return 0;
    var sum = 0;
    for (final seat in list) {
      sum += seats[seat]!.level;
    }
    return sum ~/ list.length;
  }

  // ── 소지품 ────────────────────────────────────────────────

  /// 그 열쇠를 몇 개 갖고 있는가. 장비는 **배낭의** 개수다.
  int countOf(String key) {
    if (key == SupplyKey.gold) return gold;
    if (key == SupplyKey.food) return food;
    if (key == SupplyKey.arrows) return arrows;
    return consumables[key] ?? crystals[key] ?? backpack[key] ?? 0;
  }

  /// 그 열쇠의 한도.
  int? limitOf(String key) {
    if (key == SupplyKey.gold) return null;
    if (key == SupplyKey.food) return foodLimit;
    if (key == SupplyKey.arrows) return arrowLimit;
    if (_bucket(key) != null) return stackLimit;
    return null;
  }

  Map<String, int>? _bucket(String key) {
    if (consumableByKey(key) != null) return _consumables;
    if (crystalByKey(key) != null) return _crystals;
    if (equipSlotOf(key) != null) return _backpack;
    return null;
  }

  /// 준다. **실제로 늘어난 개수**를 돌려준다(한도에 걸리면 적다, 모르는
  /// 열쇠면 0). 보물 상자와 이야기 보상이 쓴다.
  int give(String key, [int count = 1]) {
    if (count <= 0) return 0;
    if (key == SupplyKey.gold) {
      gold += count;
      return count;
    }
    if (key == SupplyKey.food) {
      final before = food;
      food = (food + count).clamp(0, foodLimit);
      return food - before;
    }
    if (key == SupplyKey.arrows) {
      final before = arrows;
      arrows = (arrows + count).clamp(0, arrowLimit);
      return arrows - before;
    }
    final bucket = _bucket(key);
    if (bucket == null) return 0;
    final before = bucket[key] ?? 0;
    final after = (before + count).clamp(0, stackLimit);
    bucket[key] = after;
    return after - before;
  }

  /// 뺀다. 모자라면 아무것도 빼지 않고 false.
  bool take(String key, [int count = 1]) {
    if (count <= 0) return true;
    if (countOf(key) < count) return false;
    if (key == SupplyKey.gold) {
      gold -= count;
      return true;
    }
    if (key == SupplyKey.food) {
      food -= count;
      return true;
    }
    if (key == SupplyKey.arrows) {
      arrows -= count;
      return true;
    }
    final bucket = _bucket(key);
    if (bucket == null) return false;
    final after = (bucket[key] ?? 0) - count;
    if (after <= 0) {
      bucket.remove(key);
    } else {
      bucket[key] = after;
    }
    return true;
  }

  /// 원작 번호로 준다(맵 스크립트용). `kind` 는 `weapon` · `shield` ·
  /// `armour` · `item` · `crystal`.
  int giveLegacy(String kind, int legacyId, [int count = 1]) {
    final key = legacyKey(kind, legacyId);
    return key == null ? 0 : give(key, count);
  }

  /// 원작 번호를 열쇠로 바꾼다. 없으면 null.
  static String? legacyKey(String kind, int legacyId) => switch (kind) {
    'weapon' => weaponByLegacyId(legacyId)?.key,
    'shield' => shieldByLegacyId(legacyId)?.key,
    'armour' => armourByLegacyId(legacyId)?.key,
    'item' => consumableByLegacyId(legacyId)?.key,
    'crystal' => crystalByLegacyId(legacyId)?.key,
    _ => null,
  };

  void addGold(int amount) {
    gold += amount;
    if (gold < 0) gold = 0;
  }

  void addFood(int amount) => food = (food + amount).clamp(0, foodLimit);

  void addArrows(int amount) => arrows = (arrows + amount).clamp(0, arrowLimit);

  void setTorch(int value) => _torch = value.clamp(0, torchLimit);

  static Map<String, int> _initialCounts(
    Map<String, int>? counts,
    bool Function(String) known,
  ) => {
    if (counts != null)
      for (final e in counts.entries)
        if (e.value > 0 && known(e.key)) e.key: e.value.clamp(1, stackLimit),
  };

  // ── 저장 ──────────────────────────────────────────────────

  /// 저장할 모양. **다시 계산할 수 있는 것은 하나도 없다.**
  Map<String, Object?> toJson() => {
    'version': loreSaveVersion,
    'episode': episode.number,
    'seats': [for (final m in seats) m?.toJson()],
    'gold': gold,
    'food': food,
    'arrows': arrows,
    'consumables': _positive(consumables),
    'crystals': _positive(crystals),
    'backpack': _positive(backpack),
    'calendar': calendar.toJson(),
    'torch': torch,
    'buffs': buffs.toJson(),
    'options': options.toJson(),
    'espTrainingUnlocked': espTrainingUnlocked,
    'specialMagicUnlocked': specialMagicUnlocked,
  };

  static Map<String, int> _positive(Map<String, int> counts) => {
    for (final e in counts.entries)
      if (e.value > 0) e.key: e.value,
  };

  /// 저장에서 되살린다. 문제가 있어도 던지지 않고 읽을 수 있는 만큼 읽는다.
  /// 무엇을 못 지켰는지 알아야 하면 [load] 를 쓴다.
  factory LoreWorld.fromJson(Map<String, Object?> json) => load(json).world;

  /// 저장에서 되살리고, 지키지 못한 것을 함께 돌려준다.
  static LoadResult load(Object? source) {
    final issues = <LoadIssue>[];
    if (source is! Map) {
      issues.add(const LoadIssue(LoadIssueKind.notAMap));
      return LoadResult(LoreWorld(episode: Episode.ep3), issues);
    }
    final json = <String, Object?>{
      for (final e in source.entries) e.key.toString(): e.value,
    };

    int n(String key, [int fallback = 0]) {
      final v = json[key];
      return v is num ? v.toInt() : fallback;
    }

    Map<String, Object?> sub(String key) {
      final v = json[key];
      if (v is! Map) return const {};
      return {for (final e in v.entries) e.key.toString(): e.value};
    }

    if (n('version', loreSaveVersion) > loreSaveVersion) {
      issues.add(const LoadIssue(LoadIssueKind.newerVersion));
    }

    var episode = Episode.fromNumber(n('episode', Episode.ep3.number));
    if (episode == null) {
      issues.add(const LoadIssue(LoadIssueKind.unknownEpisode));
      episode = Episode.ep3;
    }

    final world = LoreWorld(
      episode: episode,
      gold: n('gold') < 0 ? 0 : n('gold'),
      food: n('food').clamp(0, foodLimit),
      arrows: n('arrows').clamp(0, arrowLimit),
      calendar: json['calendar'] is Map
          ? LoreCalendar.fromJson(sub('calendar'))
          : null,
      torch: n('torch').clamp(0, torchLimit),
      buffs: FieldBuffs.fromJson(sub('buffs')),
      options: GameOptions.fromJson(sub('options')),
      espTrainingUnlocked: json['espTrainingUnlocked'] is bool
          ? json['espTrainingUnlocked']! as bool
          : null,
      specialMagicUnlocked: json['specialMagicUnlocked'] is bool
          ? json['specialMagicUnlocked']! as bool
          : null,
    );

    void counts(
      String key,
      Map<String, int> into,
      bool Function(String) known,
    ) {
      for (final e in sub(key).entries) {
        final v = e.value;
        if (v is! num || v <= 0) continue;
        if (!known(e.key)) {
          issues.add(LoadIssue(LoadIssueKind.unknownItem, key: e.key));
          continue;
        }
        into[e.key] = v.toInt().clamp(0, stackLimit);
      }
    }

    counts(
      'consumables',
      world._consumables,
      (k) => consumableByKey(k) != null,
    );
    counts('crystals', world._crystals, (k) => crystalByKey(k) != null);
    counts('backpack', world._backpack, (k) => equipSlotOf(k) != null);

    final rawSeats = json['seats'];
    if (rawSeats is List) {
      for (var i = 0; i < Seat.count && i < rawSeats.length; i++) {
        final raw = rawSeats[i];
        if (raw is! Map) continue;
        final m = Member.fromJson({
          for (final e in raw.entries) e.key.toString(): e.value,
        });
        if (m.weapon != null && weaponByKey(m.weapon) == null) {
          issues.add(
            LoadIssue(LoadIssueKind.unknownEquipment, seat: i, key: m.weapon),
          );
          m.weapon = null;
        }
        if (m.shield != null && shieldByKey(m.shield) == null) {
          issues.add(
            LoadIssue(LoadIssueKind.unknownEquipment, seat: i, key: m.shield),
          );
          m.shield = null;
        }
        if (m.armour != null && armourByKey(m.armour) == null) {
          issues.add(
            LoadIssue(LoadIssueKind.unknownEquipment, seat: i, key: m.armour),
          );
          m.armour = null;
        }
        world._seats[i] = m;
      }
    }
    return LoadResult(world, issues);
  }

  /// 값은 같고 서로 영향을 주지 않는 사본. 저장 왕복으로 만든다 —
  /// 저장 형식이 곧 「복사가 실어야 할 것」의 정의다.
  LoreWorld copy() => LoreWorld.fromJson(toJson());
}
