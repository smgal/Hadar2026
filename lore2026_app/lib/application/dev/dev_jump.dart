import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart' as wt;

import '../game_reload_exception.dart';
import '../game_session.dart';
import '../ports/host_binding.dart';
import '../ports/ui_host.dart';
import '../scripting/script_engine_adapter.dart';
import '../window_manager.dart';
import 'dev_mode.dart';
import 'dev_scenes.dart';

/// 개발자 모드 — 시나리오 중간의 장면으로 건너뛰고, 게임 중에 손볼 것들.
///
/// 장면 자료는 `assets/dev/ep<N>.json` ([DevSceneBook]). 건너뛰면 그 장면까지
/// 쌓은 플래그·변수·일행으로 **새 판**을 만들고 그 맵의 그 자리로 보낸다 —
/// 세이브를 불러오는 것과 달리 맵의 `FLAG_MAP` 이 돈다(맵이 플래그를 보고 문을
/// 열어 두는 등). 도착하면 글 창에 「무엇을 확인하면 되는지」가 나온다.
class HDDevJump {
  static final HDDevJump _instance = HDDevJump._internal();
  factory HDDevJump() => _instance;
  HDDevJump._internal();

  UiHost get _ui => HDHosts().ui;
  HDGameSession get _session => HDGameSession();

  final Map<int, DevSceneBook> _books = {};

  static const List<String> _episodeNames = [
    '제1부 또 다른 지식의 성전',
    '제2부 다크 메이지',
    '제3부 비전 속으로',
  ];

  /// 편의 장면 자료. 없거나 읽을 수 없으면 null.
  Future<DevSceneBook?> book(int episode) async {
    final cached = _books[episode];
    if (cached != null) return cached;
    try {
      final text = await HDHosts().assets.loadString('assets/dev/ep$episode.json');
      return _books[episode] = DevSceneBook.parse(text);
    } catch (e) {
      await _ui.addLog('@C장면 자료를 읽지 못했습니다: ep$episode.json ($e)@@');
      return null;
    }
  }

  /// 시험이 자료를 바꿔 다시 읽게 할 때.
  void forget() => _books.clear();

  // ─────────────────────────────────────────────── 고르기

  /// 편 → 장 → 장면을 차례로 묻고 건너뛴다. 건너뛰었으면 true.
  /// [episode] 를 주면 편은 묻지 않는다.
  Future<bool> pickAndJump({int? episode}) async {
    var ep = episode;
    while (true) {
      if (ep == null) {
        final picked = await _ui.showWindowMenu([
          '[개발] 어느 편으로 갈까요?',
          ..._episodeNames,
        ], x: 260, y: 90);
        if (picked <= 0) return false;
        ep = picked;
      }
      final b = await book(ep);
      if (b == null) return false;
      final chapters = b.chapters;
      while (true) {
        final c = await _ui.showWindowMenu([
          '[개발] 제$ep부 — 장을 고르십시오',
          for (final ch in chapters) '$ch (${b.inChapter(ch).length})',
        ], x: 200, y: 60);
        if (c <= 0) break;
        final scenes = b.inChapter(chapters[c - 1]);
        final s = await _ui.showWindowMenu([
          '[개발] ${chapters[c - 1]}',
          for (final sc in scenes) sc.label,
        ], x: 200, y: 60);
        if (s <= 0) continue;
        await jump(b, scenes[s - 1].id);
        return true;
      }
      if (episode != null) return false;
      ep = null;
    }
  }

  // ─────────────────────────────────────────────── 건너뛰기

  /// [id] 장면으로 간다. 맵으로 가는 길만 정해 두고 돌아온다 — 실제 이동은
  /// 셸이 「맵이 없는데 갈 곳이 있다」를 보고 한다(시작할 때와 같은 길).
  /// 시험은 이어서 `HDScriptEngine().executePendingNavigation()` 을 부른다.
  Future<void> jump(DevSceneBook book, String id) async {
    final state = book.resolve(id);
    final scene = state.scene;
    final engine = HDScriptEngine();

    HDWindowManager().clear();
    _session.resetToTitle();
    await engine.loadEpisode(book.episode);

    _session.party.world = buildWorld(book.episode, state);
    final option = _session.gameOption;
    for (final f in state.flags) {
      option.flags[f] = true;
    }
    final calendar = _session.party.world.calendar;
    state.vars.forEach((name, value) {
      option.variables[name] = value is int ? value : _relative(calendar, value as String);
    });
    final t = state.timer;
    if (t != null && t.length >= 2) _session.setTimer(t[0], t[1]);

    _session.sessionId++;
    _session.party.notifyListeners();
    _ui.clearLogs();

    engine.arrivalLines
      ..clear()
      ..add('@B[개발] ${scene.id} ${scene.title}@@')
      ..addAll([if (scene.check != null) '확인할 것 : ${scene.check}']);
    engine.navigationRequests++;
    engine.pendingNavigation = (
      path: scene.map,
      hasExplicit: true,
      nx: scene.at[0] - 1,
      ny: scene.at[1] - 1,
    );
    _session.clearCurrentMap();
  }

  static int _relative(LoreCalendar now, String spec) {
    final m = DevSceneState.relative.firstMatch(spec);
    if (m == null) return 0;
    final days = int.parse(m.group(2)!);
    final later = now.copy()..advance(hours: 24 * days);
    return switch (m.group(1)) {
      'day' => now.totalSeconds ~/ 86400 + days,
      'year' => later.year,
      'month' => later.month,
      _ => later.day,
    };
  }

  /// 장면 상태로 새 세계를 만든다 — 주인공 · 동료 · 레벨 · 기술치 · 장비 · 소지품 · 시각.
  static LoreWorld buildWorld(int episode, DevSceneState state) {
    final ep = Episode.fromNumber(episode)!;
    final world = LoreWorld.newGame(ep, _hero(state.hero));
    final roster = rosterOf(ep);

    for (final key in state.party) {
      final entry = roster[key];
      if (entry == null) continue;
      world.join(entry.build());
    }
    final assistant = state.assistant == null ? null : roster[state.assistant];
    if (assistant != null) world.setAssistant(assistant.build());

    for (final seat in world.presentSeats) {
      final m = world.seats[seat]!;
      _raise(m, state.level, maxSkills: state.skills == 'max');
    }
    if (state.gear) _equipForLevel(world, ep, state.level);
    if (state.demigod) world.promoteAllToDemigod();
    if (state.hidden) world.hideCompanions();

    if (state.gold != null) world.gold = state.gold!;
    if (state.food != null) world.food = state.food!.clamp(0, foodLimit);
    world.setTorch(state.torch);
    state.items.forEach((key, count) => world.give(key, count));
    if (state.unlock.contains('esp')) world.espTrainingUnlocked = true;
    if (state.unlock.contains('special_magic')) world.specialMagicUnlocked = true;

    final t = state.time;
    world.calendar
      ..year = t[0]
      ..month = t.length > 1 ? t[1] : 1
      ..day = t.length > 2 ? t[2] : 1
      ..hour = t.length > 3 ? t[3] : 9
      ..minute = t.length > 4 ? t[4] : 0
      ..second = 0;
    return world;
  }

  static Member _hero(Map<String, dynamic> h) {
    final family = h['family'] == 'mage' ? Family.mage : Family.fighter;
    final classId = (h['class'] as num?)?.toInt() ??
        (family == Family.fighter ? ClassId.knight : ClassId.mage);
    final abilities = (h['abilities'] as List?)?.cast<num>().map((n) => n.toInt()).toList() ??
        List<int>.filled(8, 17);
    final m = Member(
      name: (h['name'] as String?) ?? '슴갈',
      gender: h['gender'] == 'female' ? Gender.female : Gender.male,
      family: family,
      classId: classId,
      abilities: abilities,
      skills: List<int>.of(classOf(family, classId)?.requirements ?? const [0, 0, 0, 0, 0, 0]),
      baseAc: family == Family.fighter ? 2 : 0,
    );
    m.hp = m.maxHp;
    return m;
  }

  /// 레벨을 [level] 로 올리고(이미 높으면 그대로) 기술치를 레벨에 맞춘다.
  /// 기술치는 「20 + 레벨 × 5」(계급의 상한까지) — 레벨 8 이면 60 으로 기화 이동이,
  /// 12 면 80 으로 공간 이동이 열린다. [maxSkills] 면 상한까지.
  ///
  /// 레벨 8 이상이면 마법사 계열을 대마법사로 올린다 — 메이지·주술사 같은 계급은 변화
  /// 마법이 20~50 에서 막혀 기화 이동(60)·공간 이동(80)을 못 쓴다. 그 시점의 플레이어라면
  /// 마법 학교에서 전직해 두었을 것이다. 에스퍼·반신반인은 그대로 둔다.
  static void _raise(Member m, int level, {bool maxSkills = false}) {
    if (m.level < level) {
      m.level = level.clamp(1, maxLevel);
      m.trainedExp = trainedExpForLevel(m.level);
    }
    if (m.family == Family.mage &&
        m.level >= 8 &&
        m.classId != ClassId.esper &&
        m.classId != ClassId.demigod &&
        (classOf(m.family, m.classId)?.caps[MageSkill.change] ?? 0) < 100) {
      m.classId = ClassId.archmage;
    }
    final c = classOf(m.family, m.classId);
    if (c != null) {
      final target = 20 + m.level * 5;
      for (var i = 0; i < 6; i++) {
        final cap = c.caps[i];
        if (cap <= 0) continue;
        final want = maxSkills ? cap : target.clamp(c.requirements[i], cap);
        if (m.skills[i] < want) m.skills[i] = want;
      }
    }
    m.hp = m.maxHp;
    m.mp = m.maxMp;
    m.poison = 0;
    m.unconscious = 0;
    m.dead = 0;
  }

  /// 레벨에 맞는 값(500 × 레벨² + 500 이하)의 가장 좋은 장비를 입힌다. 이미 든 것이
  /// 더 비싸면 그대로 둔다.
  static void _equipForLevel(LoreWorld world, Episode ep, int level) {
    final budget = 500 * level * level + 500;
    for (final seat in world.presentSeats) {
      if (seat == Seat.assistant) continue;
      final m = world.seats[seat]!;
      final options = <EquipSlot, List<(String, int)>>{
        EquipSlot.weapon: [
          for (final w in weaponTable)
            if (w.onlyIn == null || w.onlyIn == ep) (w.key, w.price),
        ],
        EquipSlot.shield: [for (final s in shieldTable) (s.key, s.price)],
        EquipSlot.armour: [
          for (final a in armourTable)
            if (a.price != null) (a.key, a.price!),
        ],
      };
      options.forEach((slot, list) {
        list.sort((a, b) => b.$2.compareTo(a.$2));
        final current = world.equippedIn(seat, slot);
        final currentPrice = current == null ? -1 : (equipmentPrice(current) ?? 0);
        for (final (key, price) in list) {
          if (price > budget || price <= currentPrice) continue;
          if (checkUsable(m, key) != null) continue;
          if (current != null) {
            world.unequip(seat, slot);
            world.take(current);
          }
          world.give(key);
          world.equip(seat, key);
          break;
        }
      });
    }
  }

  // ─────────────────────────────────────────────── 게임 중 메뉴

  /// 주 메뉴의 「개발자 메뉴」. 장면으로 건너뛰면 [GameReloadException] 으로
  /// 돌던 흐름을 접는다.
  Future<void> showDevMenu() async {
    final dev = HDDevMode();
    final world = _session.party.world;
    final picked = await _ui.showWindowMenu([
      '[개발] 무엇을 할까요?',
      '장면으로 건너뛰기 (이 편)',
      '장면으로 건너뛰기 (다른 편)',
      '일행 완전 회복',
      '무작위 조우 ${dev.noEncounters ? '켜기 (지금 꺼짐)' : '끄기 (지금 켜짐)'}',
      '기술치를 계급 상한까지',
      '레벨 바꾸기',
      '켜진 플래그 · 변수 보기',
      '지금 자리 보기',
    ], x: 200, y: 60);
    switch (picked) {
      case 1:
        if (await pickAndJump(episode: _session.episode)) throw GameReloadException();
      case 2:
        if (await pickAndJump()) throw GameReloadException();
      case 3:
        for (final seat in world.presentSeats) {
          final m = world.seats[seat]!;
          m
            ..poison = 0
            ..unconscious = 0
            ..dead = 0
            ..hp = m.maxHp
            ..mp = m.maxMp;
        }
        _changed();
        await _ui.addLog('[개발] 일행이 완전히 회복되었다.');
      case 4:
        dev.noEncounters = !dev.noEncounters;
        await _ui.addLog('[개발] 무작위 조우를 ${dev.noEncounters ? '껐다' : '켰다'}.');
      case 5:
        for (final seat in world.presentSeats) {
          _raise(world.seats[seat]!, 1, maxSkills: true);
        }
        _changed();
        await _ui.addLog('[개발] 기술치를 계급 상한까지 올렸다.');
      case 6:
        final levels = [1, 3, 5, 8, 10, 12, 15, 18, 20, 25, 30, 40];
        final l = await _ui.showWindowMenu([
          '[개발] 몇 레벨로 할까요? (낮추지는 않습니다)',
          for (final n in levels) '레벨 $n',
        ]);
        if (l > 0) {
          for (final seat in world.presentSeats) {
            _raise(world.seats[seat]!, levels[l - 1]);
          }
          _changed();
          await _ui.addLog('[개발] 레벨 ${levels[l - 1]} 로 맞췄다.');
        }
      case 7:
        final o = _session.gameOption;
        final on = [
          for (final e in o.flags.entries)
            if (e.value) e.key,
        ]..sort();
        await _ui.addLog('[개발] 플래그 ${on.length}개: ${on.join(' · ')}');
        final vars = o.variables.entries.map((e) => '${e.key}=${e.value}').toList()..sort();
        await _ui.addLog('[개발] 변수: ${vars.join(' · ')}');
        await _ui.waitForAnyKey();
      case 8:
        final p = _session.party;
        await _ui.addLog(
          '[개발] ${_session.mapInfo?.name ?? '?'} (${p.x + 1}, ${p.y + 1}) · '
          '${world.calendar.year}년 ${world.calendar.month}월 ${world.calendar.day}일 '
          '${world.calendar.hour}:${world.calendar.minute.toString().padLeft(2, '0')} · '
          '일행 ${[for (final m in world.presentMembers) wt.memberName(m, episode: world.episode)].join(', ')}',
        );
        await _ui.waitForAnyKey();
    }
  }

  void _changed() {
    _session.party.notifyListeners();
    _ui.refresh();
  }
}
