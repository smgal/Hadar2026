import 'dart:convert';

/// 개발자 모드의 「장면」 — 시나리오 중간의 한 시점을 다시 만드는 자료.
///
/// 편마다 `assets/dev/ep<N>.json` 하나. 장면은 **순서대로 쌓인다**: 장면 N 으로
/// 건너뛰면 처음부터 N 까지 각 장면이 적은 변화(켠 플래그 · 바꾼 변수 · 일행 ·
/// 레벨 · 소지품 · 시각)를 차례로 적용한 상태가 된다. 그래서 장면마다 **그 사이에
/// 바뀐 것만** 적는다. 갈래(3편의 충성·반역)는 `from` 으로 앞의 다른 장면에서
/// 이어 쌓는다.
///
/// 장면 하나의 모양 (모든 열쇠가 선택이다. `id` · `title` · `map` · `at` 만 꼭 쓴다):
///
/// ```json
/// {
///   "id": "1-12", "chapter": "3장 황금의 봉인", "title": "이블 실 입구",
///   "map": "E1_EvilSeal", "at": [25, 70],
///   "check": "문 퍼즐 · 리겔 · 패스코드",
///   "from": "1-10",
///   "level": 6, "party": ["hercules", "titan", "merlin", "betelgeuse"],
///   "assistant": "skeleton", "gear": true, "skills": "auto",
///   "flags": ["CHALLENGE_ACCEPTED", "-SOME_FLAG"],
///   "vars": {"LORD_STAGE": 6, "ECLIPSE_DAY": "day+20"},
///   "items": {"item.hp_potion": 3}, "gold": 5000, "food": 50,
///   "unlock": ["esp"], "demigod": true, "hidden": false,
///   "time": [771, 3, 2, 9, 0], "timer": [1, 10]
/// }
/// ```
///
/// * `chapter` 을 빼면 앞 장면의 장을 이어 쓴다.
/// * `flags` 의 `-이름` 은 끈다(원정 기록을 지우는 2편의 `Flag::Reset` 같은 자리).
/// * `vars` 의 글자 값 `day+N` · `year+N` · `month+N` · `date+N` 은 그 장면의
///   시각에서 N 일 뒤의 날 번호 · 연 · 월 · 일이다 (2편 월식 날짜).
/// * `timer` 는 그 장면에만 걸린다 — 다음 장면으로 이어 쌓지 않는다.
/// * `torch` 는 횃불 세기 — 기본 10(5 이상이면 가장 밝다). 어둠을 시험하는 장면은 0 으로 끈다.
/// * `hidden` 은 동료(2~5번)를 숨긴 상태 — 3편 반역 루트에서 떠났다가 재회 때 돌아온다.
/// * `ending` 이 true 면 도착하자마자 엔딩으로 넘어가는 장면이다(즉위식) — 시험이 자리를 보지 않는다.
/// * `at` 은 스크립트 좌표(1부터)다. `LoadScript` 와 같다.
class DevSceneBook {
  DevSceneBook({required this.episode, required this.hero, required this.time, required this.scenes});

  final int episode;

  /// 이 편의 기본 주인공 — `{"name", "gender", "family", "class"}`.
  final Map<String, dynamic> hero;

  /// 이 편의 시작 시각 `[연, 월, 일, 시, 분]`.
  final List<int> time;

  final List<DevScene> scenes;

  factory DevSceneBook.parse(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    final scenes = <DevScene>[];
    String chapter = '';
    for (final raw in (json['steps'] as List).cast<Map<String, dynamic>>()) {
      chapter = (raw['chapter'] as String?) ?? chapter;
      scenes.add(DevScene(raw, chapter, scenes.isEmpty ? null : scenes.last.id));
    }
    return DevSceneBook(
      episode: json['episode'] as int,
      hero: (json['hero'] as Map?)?.cast<String, dynamic>() ?? const {},
      time: _ints(json['time']) ?? const [771, 1, 1, 9, 0],
      scenes: scenes,
    );
  }

  DevScene? byId(String id) {
    for (final s in scenes) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 장 이름들 — 처음 나온 순서대로.
  List<String> get chapters => [
    for (final s in scenes)
      if (s == scenes.firstWhere((t) => t.chapter == s.chapter)) s.chapter,
  ];

  List<DevScene> inChapter(String chapter) => [
    for (final s in scenes)
      if (s.chapter == chapter) s,
  ];

  /// 처음부터 [id] 까지 쌓은 상태. 없는 장면이거나 `from` 이 고리를 이루면 [StateError].
  DevSceneState resolve(String id) {
    final chain = <DevScene>[];
    final seen = <String>{};
    DevScene? s = byId(id);
    if (s == null) throw StateError('장면 $id 이(가) 없다');
    while (s != null) {
      if (!seen.add(s.id)) throw StateError('장면 ${s.id} 의 from 이 고리를 이룬다');
      chain.add(s);
      final base = s.from;
      if (base == null) break;
      s = byId(base);
      if (s == null) throw StateError('장면 ${chain.last.id} 의 from "$base" 이(가) 없다');
    }
    final state = DevSceneState(scene: chain.first, hero: Map.of(hero), time: List.of(time));
    for (final step in chain.reversed) {
      state._apply(step);
    }
    return state;
  }

  static List<int>? _ints(dynamic v) => v is List ? v.cast<num>().map((n) => n.toInt()).toList() : null;
}

/// 자료에 적힌 장면 하나 (쌓기 전).
class DevScene {
  DevScene(this.raw, this.chapter, String? previous)
    : id = raw['id'] as String,
      title = raw['title'] as String,
      map = raw['map'] as String,
      at = DevSceneBook._ints(raw['at']) ?? const [0, 0],
      check = raw['check'] as String?,
      from = raw.containsKey('from') ? raw['from'] as String? : previous;

  final Map<String, dynamic> raw;
  final String id;
  final String chapter;
  final String title;
  final String map;

  /// 스크립트 좌표 `[x, y]` (1부터).
  final List<int> at;

  /// 무엇을 확인하면 되는지 — 도착하면 글 창에 나온다.
  final String? check;

  /// 이어 쌓을 앞 장면. 첫 장면이면 null.
  final String? from;

  /// 메뉴에 보일 한 줄.
  String get label => '$id $title';
}

/// 처음부터 한 장면까지 쌓은 상태 — 개발자 모드가 이것으로 세계를 만든다.
class DevSceneState {
  DevSceneState({required this.scene, required this.hero, required this.time});

  /// 도착할 장면 (지도 · 자리 · 확인할 것).
  final DevScene scene;

  Map<String, dynamic> hero;
  List<int> time;
  int level = 1;
  List<String> party = [];
  String? assistant;
  bool gear = true;
  String skills = 'auto';
  int? gold;
  int? food;
  bool demigod = false;
  bool hidden = false;
  int torch = 10;
  final Set<String> flags = {};
  final Map<String, Object> vars = {};
  final Map<String, int> items = {};
  final Set<String> unlock = {};

  /// 이 장면에만 걸린 예약 `[번호, 분]`.
  List<int>? timer;

  void _apply(DevScene s) {
    final r = s.raw;
    if (r['hero'] is Map) hero = {...hero, ...(r['hero'] as Map).cast<String, dynamic>()};
    if (r['time'] != null) time = DevSceneBook._ints(r['time'])!;
    if (r['level'] != null) level = (r['level'] as num).toInt();
    if (r['party'] != null) party = (r['party'] as List).cast<String>();
    if (r.containsKey('assistant')) assistant = r['assistant'] as String?;
    if (r['gear'] != null) gear = r['gear'] as bool;
    if (r['skills'] != null) skills = r['skills'] as String;
    if (r['gold'] != null) gold = (r['gold'] as num).toInt();
    if (r['food'] != null) food = (r['food'] as num).toInt();
    if (r['demigod'] != null) demigod = r['demigod'] as bool;
    if (r['hidden'] != null) hidden = r['hidden'] as bool;
    if (r['torch'] != null) torch = (r['torch'] as num).toInt();
    for (final f in (r['flags'] as List? ?? const []).cast<String>()) {
      f.startsWith('-') ? flags.remove(f.substring(1)) : flags.add(f);
    }
    for (final e in (r['vars'] as Map? ?? const {}).entries) {
      vars[e.key as String] = e.value is num ? (e.value as num).toInt() : e.value as String;
    }
    for (final e in (r['items'] as Map? ?? const {}).entries) {
      items[e.key as String] = (e.value as num).toInt();
    }
    unlock.addAll((r['unlock'] as List? ?? const []).cast<String>());
    timer = identical(s, scene) ? DevSceneBook._ints(r['timer']) : null;
  }

  /// `vars` 의 글자 값(`day+20` …)을 풀 때 쓰는 꼴.
  static final RegExp relative = RegExp(r'^(day|year|month|date)\+(\d+)$');
}
