import 'dart:async';

import 'package:cm2_script/cm2_script.dart';
import 'package:flutter/foundation.dart';

import '../../domain/lighting/sight_calculator.dart';
import '../../domain/map/actor.dart';
import '../../domain/map/map_unit.dart';
import '../../domain/window/scenery_window_data.dart';
import '../../domain/map/tile_properties.dart';
import '../../hd_config.dart';
import 'package:lore_world_text/lore_world_text.dart' show josa;
import '../audio.dart';
import '../field_rules.dart';
import '../game_reload_exception.dart';
import '../game_session.dart';
import '../map_navigation.dart';
import '../ports/host_binding.dart';
import '../select.dart';
import '../tile_event_dispatcher.dart';
import '../window_manager.dart';
import 'text_template.dart';
import 'world_verbs.dart';

/// `ScriptMode()` 값 — `assets/common/const.cm2` 의 `FLAG_*` 와 같다.
///
/// 0~4 는 [HDTileAction.scriptMode] 가 정하고(타일이 부른 까닭), 나머지는
/// 타일과 무관하게 엔진이 부르는 까닭이다.
abstract final class HDScriptMode {
  static const int map = 0;
  static const int timer = 5;
  static const int item = 6;
  static const int start = 7;
  static const int prophecy = 8;

  /// 편을 고른 직후, 캐릭터를 만들기 전. 여는 글을 낸다 — 주인공이 아직
  /// 없으므로 `{주인공}` 을 쓰지 않는다.
  static const int opening = 9;
}

/// cm2 엔진 둘을 굴리는 어댑터.
///
/// ## 엔진이 둘인 이유
///
/// 맵 스크립트는 맵을 옮길 때마다 갈린다(`loadScript` 가 변수까지 비운다).
/// 그런데 예언 · 예약한 사건 · 새 게임 시작은 **어느 맵에 서 있든** 같은
/// 스크립트가 받아야 한다. 그래서 편마다 `assets/epN/episode.cm2` 를 따로
/// 올려 둔다. 동사 표는 둘이 같다.
///
/// ## hadar2026_app 과 다른 점
///
/// * **좌표가 1부터다.** 기획서와 공략집의 (x,y) 를 그대로 옮겨 쓰게 하려는
///   것이고, 0부터 세는 엔진 안쪽과의 환산은 이 파일이 전부 맡는다([_cx]).
/// * **플래그·변수는 이름이다** (`HDGameOption`).
/// * **`Map::ChangeTile` 은 원작 타일 번호를 받는다** (`TileTable`).
/// * 글에 `{주인공:은/는}` 을 쓸 수 있다 (`expandTemplate`).
class HDScriptEngine {
  static final HDScriptEngine _instance = HDScriptEngine._internal();
  factory HDScriptEngine() => _instance;

  late final ScriptEngine _map;
  late final ScriptEngine _episode;

  /// 지금 돌고 있는 엔진. 글 치환이 변수를 찾을 때 본다.
  late ScriptEngine _running;

  /// 지금 올라와 있는 episode.cm2 의 편 (0 = 없음).
  int _episodeLoaded = 0;

  /// Pending map transition stored by the `LoadScript` handler. Consumed by
  /// [executePendingNavigation]; the shell notices `map == null` with a
  /// pending transition and calls it.
  ({String path, bool hasExplicit, int nx, int ny})? pendingNavigation;

  /// `LoadScript` 가 불린 횟수. 맵 이동은 셸이 바로 처리해서 [pendingNavigation]
  /// 이 금방 비므로, 「이동을 요청했는가」는 이 수가 늘었는지로 본다.
  int navigationRequests = 0;

  /// 다음 맵에 들어선 뒤에 낼 문장 (`Arrival::Talk` · `Arrival::Say`).
  /// 그 맵의 `FLAG_MAP` 이 끝나면 [executePendingNavigation] 이 내고 비운다.
  /// 제목으로 돌아가거나 불러오면 비운다.
  final List<String> arrivalLines = [];

  /// `Letter::Add` 로 쌓는 편지 문단. `Letter::Show` 가 보이고 비운다.
  final List<String> letterParagraphs = [];

  /// 문단마다 붙일 1부 인물 그림 (`Letter::AddPicture`). 그림이 없는 문단은 null.
  final List<List<List<int>>?> letterPictures = [];

  /// `Event::StepAgain()` 이 불렸는가 — 칸 사건 실행기가 스크립트가 끝난 뒤
  /// 일행이 선 칸을 밟은 것으로 다시 본다.
  bool stepAgainRequested = false;

  /// `Party::Join` 이 방금 앉혔는가 — `Party::Joined()` 가 읽는다.
  bool lastJoinSucceeded = false;

  /// 방금 합류한 사람이 앉은 대원 번호(1~6). 없으면 0 — `Party::JoinedSeat()` 가 읽는다.
  int lastJoinSeat = 0;

  /// `FLAG_ITEM` 으로 불렀을 때 쓴 물건의 키 — `Item::Used()` 가 읽는다.
  String usedItemKey = '';

  /// `FLAG_TIMER` 로 불렀을 때 울린 예약의 번호 — `Timer::Id()` 가 읽는다.
  int firedTimerId = 0;

  HDScriptEngine._internal() {
    Future<String> loader(String path) {
      final assetPath = path.startsWith('assets/') ? path : 'assets/$path';
      return HDHosts().assets.loadString(assetPath);
    }

    _map = ScriptEngine(contentLoader: loader);
    _episode = ScriptEngine(contentLoader: loader);
    _running = _map;
    for (final e in [_map, _episode]) {
      _registerCoreCommands(e);
      _registerCoreFunctions(e);
      registerWorldVerbs(e, this);
    }
  }

  Map<String, dynamic> get variables => _map.variables;

  List<ScriptStatement> get currentScript => _map.currentScript;

  /// 이 어댑터가 등록해 둔 이름들. **감사가 쓴다** — cm2 는 모르는 이름을
  /// 예외로 만들지 않고 그냥 넘어가므로, 오타를 잡으려면 밖에서 훑어야 한다.
  Set<String> get registeredCommands => _map.registeredCommands;
  Set<String> get registeredFunctions => _map.registeredFunctions;

  void setScriptMode(int mode) => _map.scriptMode = mode;

  /// 사건이 일어난 칸. 엔진 안쪽 좌표(0부터)로 받는다.
  void setTargetPos(int x, int y) {
    _map.targetX = x;
    _map.targetY = y;
  }

  // ---------------------------------------------------------------- 맵 스크립트

  /// Loads [assetPath] into the map engine. Returns whether it succeeded.
  ///
  /// **A failed load leaves nothing behind** — otherwise the previous map's
  /// script keeps running on the new map's tiles (GROUND_TRUTH A-2).
  /// A missing file is normal while a map has not been scripted yet.
  Future<bool> loadScript(String assetPath) async {
    String content;
    try {
      content = await HDHosts().assets.loadString(assetPath);
    } catch (e) {
      debugPrint("ScriptEngine: no script at $assetPath ($e)");
      _resetLoadedScript();
      return false;
    }

    _map.clearRuntimeState();
    await _map.loadFromString(content);
    HDGameSession().gameOption.scriptFile = assetPath;
    return true;
  }

  void _resetLoadedScript() {
    _map.clearRuntimeState();
    _map.currentScript = [];
  }

  @visibleForTesting
  Future<void> loadFromString(String content) async {
    _map.clearRuntimeState();
    await _map.loadFromString(content);
  }

  /// 맵 스크립트를 지금 정해 둔 모드로 한 번 돌린다.
  Future<void> run() => _run(_map);

  Future<void> _run(ScriptEngine engine) async {
    final before = _running;
    _running = engine;
    try {
      await engine.run(
        onError: (e, stack) {
          if (e is GameReloadException) return; // 불러오기 — 조용히 멈춘다
          debugPrint("ScriptEngine Error: $e\n$stack");
        },
      );
    } finally {
      _running = before;
    }
  }

  /// Was `Event::Override` invoked during the most recent map-script run?
  bool get handled => _map.handled;

  // ------------------------------------------------------------- 편 스크립트

  /// `assets/ep<N>/episode.cm2` 를 올린다. 이미 올라와 있으면 그대로 둔다.
  Future<bool> loadEpisode(int episode) async {
    if (_episodeLoaded == episode) return true;
    _episode.clearRuntimeState();
    _episode.currentScript = [];
    _episodeLoaded = 0;
    try {
      final content = await HDHosts().assets.loadString(
        'assets/ep$episode/episode.cm2',
      );
      await _episode.loadFromString(content);
      _episodeLoaded = episode;
      return true;
    } catch (e) {
      debugPrint('ScriptEngine: ep$episode has no episode.cm2 ($e)');
      return false;
    }
  }

  bool get hasEpisodeScript => _episodeLoaded != 0;

  /// 맵 엔진으로 식 하나를 계산한다 — 시험이 `Map::GetTile(9, 30)` 같은
  /// 함수를 스크립트 없이 부를 때 쓴다.
  @visibleForTesting
  dynamic evaluateOnMap(String expression) => _map.getVal(expression);

  /// 편 스크립트를 [mode] 로 한 번 돌린다 (`FLAG_START` · `FLAG_TIMER` ·
  /// `FLAG_PROPHECY`).
  Future<void> runEpisode(int mode) async {
    if (_episodeLoaded == 0) return;
    _episode
      ..scriptMode = mode
      ..targetX = -1
      ..targetY = -1;
    await _run(_episode);
  }

  /// 맵 스크립트를 타일과 무관한 까닭([mode])으로 돌린다 (`FLAG_ITEM`).
  /// 사건 칸은 일행이 서 있는 자리다.
  Future<void> runMapMode(int mode) async {
    final party = HDGameSession().party;
    _map
      ..scriptMode = mode
      ..targetX = party.x
      ..targetY = party.y;
    await _run(_map);
  }

  // ------------------------------------------------------------------ 맵 이동

  /// Executes the pending map transition stored by `LoadScript`:
  /// load → place the party → `FLAG_MAP` → facing.
  ///
  /// **The party is placed before `FLAG_MAP` runs**, unlike hadar2026_app.
  /// A Lore map script re-applies flag-driven changes on entry and some of
  /// them look at where the party arrived (베스퍼성 · 신전 · 오두막 start on
  /// the side the party came from).
  Future<void> executePendingNavigation() async {
    final nav = pendingNavigation;
    if (nav == null) return;
    pendingNavigation = null;

    HDWindowManager().clear();
    HDHosts().ui.showNameList(const []); // 지도 칸의 이름 목록은 맵을 옮기면 걷힌다
    final session = HDGameSession();
    final loaded = await session.loadMapFromFile(nav.path);
    if (!loaded) return;

    final map = session.map;
    final start = session.mapInfo?.start;
    if (nav.hasExplicit) {
      session.party.setPosition(nav.nx, nav.ny);
    } else if (start != null) {
      session.party.setPosition(start.$1 - 1, start.$2 - 1);
    } else if (map != null) {
      session.party.setPosition(map.width ~/ 2, map.height ~/ 2);
    }
    _applyEntryFacing();

    if (session.currentMapCm2Path != null) {
      setScriptMode(HDScriptMode.map);
      setTargetPos(-1, -1);
      await HDTileEventDispatcher().runExclusive(run);
    }
    session.mapVersion++;
    HDHosts().ui.refresh();
    // 앞 맵이 `Screen::FadeOut` 으로 화면을 덮은 채 넘어왔으면 걷는다.
    // 새 맵의 `FLAG_MAP` 이 장면을 위해 덮어 둔 채로 두고 싶으면 그 안에서
    // 다시 덮으면 되지만, 그런 맵은 아직 없다. 덮인 것이 없으면 아무 일도 없다.
    await HDHosts().ui.fade(out: false, milliseconds: 300);
    await _sayArrivalLines();
    // 새 맵의 `FLAG_MAP` 이 `Timer::Set(번호, 0)` 을 걸고 끝났으면(즉위식 ·
    // 돔 에필로그) 지금 울린다. 앞 맵에서 걸어 둔 0분 예약도 여기서 울린다.
    await HDFieldRules().fireDueTimerNow();
  }

  /// 앞 맵의 스크립트가 `Arrival::*` 로 쌓아 둔 문장을 낸다 — 도착한 자리에서
  /// 들어야 하는 말(3편 급보의 「지금 당신이 서 있는 곳은 하데스 게이트…」).
  /// 그 사이에 또 맵을 옮기는 중이면 다음 맵까지 미룬다.
  Future<void> _sayArrivalLines() async {
    if (arrivalLines.isEmpty) return;
    if (pendingNavigation != null || HDGameSession().map == null) return;
    final lines = List.of(arrivalLines);
    arrivalLines.clear();
    final host = HDHosts().ui;
    host.beginNarrative();
    try {
      for (final line in lines) {
        await host.addLog(line);
      }
    } finally {
      await host.endNarrative();
    }
  }

  /// Sets player facing after a map transition.
  ///
  /// 1. Adjacent entrance tile → face away from it (stepped through it).
  /// 2. Otherwise face toward the map centre, dominant axis first.
  void _applyEntryFacing() {
    final map = HDGameSession().map;
    final party = HDGameSession().party;
    if (map == null) return;

    final px = party.x, py = party.y;
    for (final (ddx, ddy) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      final unit = map.getUnit(px + ddx, py + ddy);
      if (unit != null &&
          HDTileProperties.getUnitAction(unit) == HDTileAction.enter) {
        party.setFace(-ddx, -ddy);
        return;
      }
    }

    final cx = map.width ~/ 2, cy = map.height ~/ 2;
    final dx = cx - px, dy = cy - py;
    if (dx == 0 && dy == 0) {
      party.setFace(0, 1);
    } else if (dy.abs() >= dx.abs()) {
      party.setFace(0, dy > 0 ? 1 : -1);
    } else {
      party.setFace(dx > 0 ? 1 : -1, 0);
    }
  }

  // ------------------------------------------------------------- 인자 읽기

  /// 크리스탈 볼이 비추는 풍경의 크기 (가로 × 세로 칸).
  static const int sceneryColumns = 9;
  static const int sceneryRows = 11;

  /// 배우가 한 칸 걷는 시간 — 주인공과 같은 빠르기다.
  static final int actorStepMs =
      (HDConfig.tileSize / HDConfig.playerMoveSpeed * 1000).round();

  /// 스크립트 좌표(1부터) → 엔진 좌표(0부터).
  static int _cx(int scriptCoord) => scriptCoord - 1;

  /// 엔진 좌표 → 스크립트 좌표.
  static int scriptCoord(int engineCoord) => engineCoord + 1;

  /// 인자를 글자로 읽는다. 따옴표가 남아 있으면 벗긴다.
  static String str(ScriptEngine eng, List<String> args, int i) {
    if (i >= args.length) return '';
    var text = (eng.getVal(args[i]) ?? '').toString();
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      text = text.substring(1, text.length - 1);
    }
    return text;
  }

  /// 인자를 정수로 읽는다. 숫자가 아니면 [fallback] 을 주고 **알린다** —
  /// 조용히 0 이 되는 것이 cm2 에서 가장 찾기 어려운 실수다.
  static int integer(
    ScriptEngine eng,
    List<String> args,
    int i, {
    int fallback = 0,
    String symbol = '',
  }) {
    if (i >= args.length) return fallback;
    final raw = eng.getVal(args[i]);
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse(raw.toString());
    if (parsed == null) {
      debugPrint('[cm2] $symbol: "${args[i]}" 는 숫자가 아니다 — $fallback 으로 읽는다');
      return fallback;
    }
    return parsed;
  }

  /// 함수 인자(이미 값으로 풀려 있다)를 정수로.
  static int num0(List<dynamic> args, int i, {int fallback = 0}) {
    if (i >= args.length) return fallback;
    final v = args[i];
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  /// 글 안의 `{주인공:은/는}` · `{$변수}` 를 푼다.
  String expand(String text) => expandTemplate(
    text,
    nameOf: (seat) => HDGameSession().party.nameOf(seat - 1),
    variable: (name) => _running.variables[name],
  );

  String _text(ScriptEngine eng, List<String> args, int i) =>
      expand(str(eng, args, i));

  // --------------------------------------------------------------- 공통 동사

  void _registerCoreCommands(ScriptEngine e) {
    // ---- 글 ----
    e.registerCommand('Talk', (stmt, eng) async {
      await HDHosts().ui.addLog(_text(eng, stmt.args, 0));
    });

    // 화자가 있는 대사. 이름은 하늘색 — 원작이 이름을 색으로 갈랐다(부록 D.2).
    e.registerCommand('Say', (stmt, eng) async {
      final who = _text(eng, stmt.args, 0);
      final text = _text(eng, stmt.args, 1);
      await HDHosts().ui.addLog(who.isEmpty ? text : '@B$who@@ : $text');
    });

    // 편지 화면 — 오프닝 편지와 엔딩 글 (13 §13.7 · §13.10). 게임 안의 대화 창이
    // 아니라 검은 화면 한 장을 쓴다.
    //   Letter::Clear() → Letter::Add("문단") … → Letter::Show(색, LETTER_SCROLL)
    e.registerCommand('Letter::Clear', (_, _) async {
      letterParagraphs.clear();
      letterPictures.clear();
    });
    e.registerCommand('Letter::Add', (stmt, eng) async {
      letterParagraphs.add(_text(eng, stmt.args, 0));
      letterPictures.add(null);
    });
    // `Letter::AddPicture("10 14 18 / 11 15 19", "문단")` — 문단 왼쪽에 1부 인물 그림을 붙인다.
    // 번호는 원작 CHARA.FNT 의 0~27 (`lore1_chara.png`), 공백으로 나란히, `/` 로 다음 줄.
    e.registerCommand('Letter::AddPicture', (stmt, eng) async {
      final rows = [
        for (final row in str(eng, stmt.args, 0).split('/'))
          [
            for (final n in row.trim().split(RegExp(r'\s+')))
              ?int.tryParse(n),
          ],
      ]..removeWhere((r) => r.isEmpty);
      letterParagraphs.add(_text(eng, stmt.args, 1));
      letterPictures.add(rows);
    });
    e.registerCommand('Letter::Show', (stmt, eng) async {
      final paragraphs = List.of(letterParagraphs);
      final pictures = letterPictures.any((p) => p != null)
          ? List.of(letterPictures)
          : null;
      letterParagraphs.clear();
      letterPictures.clear();
      await HDHosts().ui.showLetter(
        paragraphs,
        color: integer(eng, stmt.args, 0, fallback: 15),
        mode: integer(eng, stmt.args, 1, fallback: 0),
        pictures: pictures,
      );
    });

    // 다음 맵에 들어선 뒤에 낼 말 — `LoadScript` 에서 스크립트가 끝나므로
    // 도착해서 들어야 하는 말은 이렇게 쌓아 둔다. 그 맵의 `FLAG_MAP` 이 끝난
    // 뒤에 나오고, 다 나오면 키를 기다린다.
    e.registerCommand('Arrival::Talk', (stmt, eng) async {
      arrivalLines.add(_text(eng, stmt.args, 0));
    });
    e.registerCommand('Arrival::Say', (stmt, eng) async {
      final who = _text(eng, stmt.args, 0);
      final text = _text(eng, stmt.args, 1);
      arrivalLines.add(who.isEmpty ? text : '@B$who@@ : $text');
    });

    // 시스템 알림 — 획득·능력치 변화. 원작의 하늘색 글자.
    e.registerCommand('Notice', (stmt, eng) async {
      await HDHosts().ui.addLog('@B[ ${_text(eng, stmt.args, 0)} ]@@');
    });

    e.registerCommand('Log', (stmt, eng) async {
      await HDHosts().ui.addLog(_text(eng, stmt.args, 0), isDialogue: false);
    });

    e.registerCommand('SetHeader', (stmt, eng) async {
      final text = _text(eng, stmt.args, 0);
      HDHosts().ui.setHeader(text.isEmpty ? '' : '@B$text:@@');
    });

    e.registerCommand('Answer', (stmt, eng) async {
      await HDHosts().ui.addLog('@A${_text(eng, stmt.args, 0)}@@');
    });

    e.registerCommand('PressAnyKey', (_, _) async {
      await HDHosts().ui.waitForAnyKey();
      HDHosts().ui.clearLogs();
    });

    e.registerCommand('ClearText', (_, _) async => HDHosts().ui.clearLogs());

    e.registerCommand('Wait', (stmt, eng) async {
      final ms = integer(eng, stmt.args, 0, symbol: 'Wait');
      if (ms > 0) await Future.delayed(Duration(milliseconds: ms));
    });

    // ---- 고르기 ----
    e.registerCommand('Select::Init', (_, _) async => HDSelect().init());
    e.registerCommand('Select::Add', (stmt, eng) async {
      HDSelect().add(_text(eng, stmt.args, 0));
    });
    e.registerCommand('Select::Run', (_, _) async => HDSelect().run());

    // 예/아니오. 원작의 「예, 그렇습니다.」「아니오, 원하지 않습니다.」.
    e.registerCommand('Ask', (stmt, eng) async {
      HDSelect()
        ..init()
        ..add(_text(eng, stmt.args, 0))
        ..add('예, 그렇습니다.')
        ..add('아니오, 원하지 않습니다.');
      await HDSelect().run();
    });

    // ---- 진행 상태 (이름으로) ----
    final option = () => HDGameSession().gameOption;

    e.registerCommand('Flag::Set', (stmt, eng) async {
      final name = _stateName(eng, stmt.args, 'Flag::Set');
      if (name != null) option().flags[name] = true;
    });
    e.registerCommand('Flag::Reset', (stmt, eng) async {
      final name = _stateName(eng, stmt.args, 'Flag::Reset');
      if (name != null) option().flags.remove(name);
    });
    e.registerCommand('Variable::Set', (stmt, eng) async {
      final name = _stateName(eng, stmt.args, 'Variable::Set');
      if (name == null) return;
      option().variables[name] = integer(
        eng,
        stmt.args,
        1,
        symbol: 'Variable::Set',
      );
    });
    e.registerCommand('Variable::Add', (stmt, eng) async {
      final name = _stateName(eng, stmt.args, 'Variable::Add');
      if (name == null) return;
      final inc = stmt.args.length > 1
          ? integer(eng, stmt.args, 1, symbol: 'Variable::Add')
          : 1;
      option().variables[name] = option().variable(name) + inc;
    });

    // ---- 맵 ----
    e.registerCommand('LoadScript', (stmt, eng) async {
      final path = str(eng, stmt.args, 0);
      navigationRequests++;
      final hasExplicitPos = stmt.args.length >= 3;
      pendingNavigation = (
        path: path,
        hasExplicit: hasExplicitPos,
        nx: hasExplicitPos ? _cx(integer(eng, stmt.args, 1)) : 0,
        ny: hasExplicitPos ? _cx(integer(eng, stmt.args, 2)) : 0,
      );
      // 지금 맵을 놓는다. 셸이 「맵이 없는데 갈 곳이 있다」를 보고
      // executePendingNavigation 을 부른다 — 시작할 때와 같은 길이다.
      HDWindowManager().clear();
      HDGameSession().clearCurrentMap();
      eng.handled = true;
      eng.halted = true;
    });

    e.registerCommand('Map::ChangeTile', (stmt, eng) async {
      _changeTile(
        _cx(integer(eng, stmt.args, 0)),
        _cx(integer(eng, stmt.args, 1)),
        integer(eng, stmt.args, 2, symbol: 'Map::ChangeTile'),
      );
    });

    e.registerCommand('Map::ChangeTileArea', (stmt, eng) async {
      final x1 = _cx(integer(eng, stmt.args, 0));
      final y1 = _cx(integer(eng, stmt.args, 1));
      final x2 = _cx(integer(eng, stmt.args, 2));
      final y2 = _cx(integer(eng, stmt.args, 3));
      final tile = integer(eng, stmt.args, 4, symbol: 'Map::ChangeTileArea');
      for (var y = y1 < y2 ? y1 : y2; y <= (y1 > y2 ? y1 : y2); y++) {
        for (var x = x1 < x2 ? x1 : x2; x <= (x1 > x2 ? x1 : x2); x++) {
          _changeTile(x, y, tile);
        }
      }
    });

    // `Map::ChangeHiddenTiles(x1, y1, x2, y2, 타일)` — 사각형 안의 **숨은 칸(0)만** 바꾼다.
    // 숨은 칸은 그 맵의 기본 바닥 그림 + 이벤트 행동으로 깔려 있다(tile 0 의 풀이와 같다).
    // 이블 컨센트레이션의 「성 터의 숨은 칸이 모두 성벽이 된다」 같은 자리에 쓴다.
    e.registerCommand('Map::ChangeHiddenTiles', (stmt, eng) async {
      final r = _rect(eng, stmt.args);
      final tile = integer(eng, stmt.args, 4, symbol: 'Map::ChangeHiddenTiles');
      final session = HDGameSession();
      final hidden = session.tileTable.entry(session.gameOption.mapName, 0);
      for (var y = r[1] < r[3] ? r[1] : r[3]; y <= (r[1] > r[3] ? r[1] : r[3]); y++) {
        for (var x = r[0] < r[2] ? r[0] : r[2]; x <= (r[0] > r[2] ? r[0] : r[2]); x++) {
          final unit = session.map?.getUnit(x, y);
          if (unit == null) continue;
          if (unit.ixTile != hidden.a5 || unit.ixObj0 != 0 || unit.ixObj1 != 0) continue;
          if (HDTileProperties.getUnitAction(unit) != HDTileAction.event) continue;
          _changeTile(x, y, tile);
        }
      }
    });

    // `Map::ReplaceTile(x1, y1, x2, y2, 원래 타일, 새 타일)` — 사각형 안에서 지금 「원래 타일」로 깔린 칸만 바꾼다.
    // 그림·통행이 그 타일의 풀이와 같은 칸을 고른다 (제2부 피라미드의 호수가 용암으로 바뀌는 자리 등).
    e.registerCommand('Map::ReplaceTile', (stmt, eng) async {
      final r = _rect(eng, stmt.args);
      final from = integer(eng, stmt.args, 4, symbol: 'Map::ReplaceTile');
      final to = integer(eng, stmt.args, 5, symbol: 'Map::ReplaceTile');
      final session = HDGameSession();
      final mapName = session.gameOption.mapName;
      for (var y = r[1] < r[3] ? r[1] : r[3]; y <= (r[1] > r[3] ? r[1] : r[3]); y++) {
        for (var x = r[0] < r[2] ? r[0] : r[2]; x <= (r[0] > r[2] ? r[0] : r[2]); x++) {
          final unit = session.map?.getUnit(x, y);
          if (unit == null) continue;
          if (!session.tileTable.matches(mapName, unit, from)) continue;
          _changeTile(x, y, to);
        }
      }
    });

    // `Map::ScatterTile(x1, y1, x2, y2, 타일, 백분율)` — 사각형 안의 칸마다 그 확률로
    // 그 타일로 바꾼다. 원작의 「모든 칸을 10분의 1 확률로 45번」(3편 돔의 공사 현장).
    e.registerCommand('Map::ScatterTile', (stmt, eng) async {
      final r = _rect(eng, stmt.args);
      final tile = integer(eng, stmt.args, 4, symbol: 'Map::ScatterTile');
      final percent = integer(eng, stmt.args, 5, symbol: 'Map::ScatterTile');
      final rng = HDFieldRules().rng;
      for (var y = r[1] < r[3] ? r[1] : r[3]; y <= (r[1] > r[3] ? r[1] : r[3]); y++) {
        for (var x = r[0] < r[2] ? r[0] : r[2]; x <= (r[0] > r[2] ? r[0] : r[2]); x++) {
          if (rng.nextInt(100) < percent) _changeTile(x, y, tile);
        }
      }
    });

    e.registerCommand('Map::SetHandicap', (stmt, eng) async {
      final which = integer(eng, stmt.args, 0, symbol: 'Map::SetHandicap');
      final on = integer(eng, stmt.args, 1, fallback: 1) != 0;
      final handicaps = HDGameSession().mapRuntime.handicaps;
      on ? handicaps.add(which) : handicaps.remove(which);
    });

    // `Map::SetMagicBarrier(x1, y1, x2, y2)` — 이 사각형을 공간 이동 · 기화 이동이
    // 건너지 못한다 (지나가는 칸이든 내려서는 칸이든). 맵을 옮기면 풀린다.
    e.registerCommand('Map::SetMagicBarrier', (stmt, eng) async {
      final r = _rect(eng, stmt.args);
      HDGameSession().mapRuntime.magicBarriers.add((
        r[0] < r[2] ? r[0] : r[2],
        r[1] < r[3] ? r[1] : r[3],
        r[0] > r[2] ? r[0] : r[2],
        r[1] > r[3] ? r[1] : r[3],
      ));
    });

    // `Screen::ShowScenery("E3_Ground1", 44, 50)` — 그 맵의 (44,50) 을 가운데로 한
    // 9×11 칸을 그림 그대로 창에 비춘다(크리스탈 볼, 3편 05 §5.4 L2). 그 맵의
    // 스크립트는 돌리지 않는다 — 칸은 맵 파일에 있는 처음 모습이다. 밤이고 달빛이
    // 없으면 어둡게 그린다. 아무 키나 누르면 닫힌다.
    e.registerCommand('Screen::ShowScenery', (stmt, eng) async {
      final name = str(eng, stmt.args, 0);
      final cx = _cx(integer(eng, stmt.args, 1, symbol: 'Screen::ShowScenery'));
      final cy = _cx(integer(eng, stmt.args, 2, symbol: 'Screen::ShowScenery'));
      final map = (await HDMapNavigation().loadByName(name))?.json;
      if (map == null) {
        debugPrint('[cm2] Screen::ShowScenery("$name") — 그런 맵이 없다');
        return;
      }
      const cols = sceneryColumns, rows = sceneryRows;
      final units = <MapUnit?>[
        for (var y = 0; y < rows; y++)
          for (var x = 0; x < cols; x++)
            map.getUnit(cx - cols ~/ 2 + x, cy - rows ~/ 2 + y),
      ];
      final world = HDGameSession().party.world;
      const field = HDTileProperties.TYPE_GROUND;
      final dark =
          HDSightCalculator.sightRangeFor(world: world, mapType: field) <
              HDSightCalculator.fullSight &&
          !HDSightCalculator.isInMoonlight(world: world, mapType: field);
      final window = HDSceneryWindow(
        columns: cols,
        rows: rows,
        units: units,
        tileOverrides: map.tileOverrides,
        dark: dark,
      );
      HDWindowManager().addWindow(window);
      try {
        await window.waitForClose();
      } finally {
        HDWindowManager().removeWindow(window);
      }
    });

    e.registerCommand('Map::SetLightArea', (stmt, eng) async {
      final r = _rect(eng, stmt.args);
      HDGameSession().lightAreas.set(r[0], r[1], r[2], r[3]);
      HDHosts().ui.refresh();
    });
    e.registerCommand('Map::ResetLightArea', (stmt, eng) async {
      final r = _rect(eng, stmt.args);
      HDGameSession().lightAreas.reset(r[0], r[1], r[2], r[3]);
      HDHosts().ui.refresh();
    });

    e.registerCommand('Map::SetDark', (stmt, eng) async {
      HDGameSession().mapRuntime.darkZone =
          integer(eng, stmt.args, 0, fallback: 1) != 0;
      HDHosts().ui.refresh();
    });

    e.registerCommand('DisplayMap', (_, _) async => _refreshDisplay());
    e.registerCommand('DisplayStatus', (_, _) async => _refreshDisplay());

    e.registerCommand(
      'WarpPrevPos',
      (_, _) async => HDGameSession().party.warpToPrev(),
    );

    e.registerCommand('Party::Warp', (stmt, eng) async {
      HDGameSession().party.setPosition(
        _cx(integer(eng, stmt.args, 0)),
        _cx(integer(eng, stmt.args, 1)),
      );
      HDHosts().ui.refresh();
    });

    e.registerCommand('Party::Move', (stmt, eng) async {
      // Presentation-backed hosts play the walk; headless hosts just bump
      // the coordinates. The script doesn't care which.
      await HDHosts().movement.animatePartyMove(
        integer(eng, stmt.args, 0),
        integer(eng, stmt.args, 1),
      );
    });

    // `Event::StepAgain()` — 이 스크립트가 끝나면 일행이 지금 선 칸을 밟은 것으로
    // 다시 본다. `Party::Warp` · `Party::Move` 는 내려선 칸의 사건을 일으키지 않으므로
    // 미끄럼처럼 「내려선 칸의 사건도 일어난다」가 필요할 때 쓴다.
    e.registerCommand('Event::StepAgain', (_, _) async {
      stepAgainRequested = true;
    });

    // `Party::Hide()` · `Party::Show()` — 일행 그림만 감추고 다시 보인다. 감춘 채
    // `Party::Warp` 하면 카메라만 옮겨 간다(주인공 없이 화면이 흘러가는 장면).
    e.registerCommand('Party::Hide', (_, _) async {
      HDGameSession().party
        ..hidden = true
        ..notifyListeners();
      HDHosts().ui.refresh();
    });
    e.registerCommand('Party::Show', (_, _) async {
      HDGameSession().party
        ..hidden = false
        ..notifyListeners();
      HDHosts().ui.refresh();
    });

    e.registerCommand('Party::Face', (stmt, eng) async {
      final party = HDGameSession().party;
      party.faced = integer(eng, stmt.args, 0).clamp(0, 3);
      party.notifyListeners();
    });

    // ---- 장면 속 인물 ----
    //
    // Actor::Show("병사1", 53, 50, 36)   원작 타일 53 번의 인물을 (50,36) 에 세운다
    // Actor::Move("병사1", 0, -1)        한 칸 걷기 시작한다 (기다리지 않는다)
    // Party::Move(0, -1)                 주인공도 걷는다 — 이것은 끝날 때까지 기다린다
    // Actor::Wait()                      배우들이 다 설 때까지 기다린다
    // Actor::Hide("병사1")
    e.registerCommand('Actor::Show', (stmt, eng) async {
      final id = str(eng, stmt.args, 0);
      final tile = integer(eng, stmt.args, 1, symbol: 'Actor::Show');
      final session = HDGameSession();
      final entry = session.tileTable.entry(session.gameOption.mapName, tile);
      session.actors[id] = HDActor(
        id: id,
        a5: entry.a5,
        sprite: entry.obj1 > 0 ? entry.obj1 : entry.obj0,
        cutout: entry.actor,
        x: _cx(integer(eng, stmt.args, 2)),
        y: _cx(integer(eng, stmt.args, 3)),
      );
      HDHosts().ui.refresh();
    });
    // `Actor::ShowSprite("에너지 공", 20, x, y)` — 3부 스프라이트 띠(24px 28칸)의 그림으로
    // 배우를 세운다. 타일 표에 없는 그림(에너지 공 20 · 네크로만서 25·26 ·
    // 드라코니안킹의 큰 모습 14~19 · 제작자 24)이 쓴다. 걷기와 감추기는 Actor::* 그대로.
    e.registerCommand('Actor::ShowSprite', (stmt, eng) async {
      final id = str(eng, stmt.args, 0);
      HDGameSession().actors[id] = HDActor(
        id: id,
        a5: 0,
        sprite: 0,
        strip: integer(eng, stmt.args, 1, symbol: 'Actor::ShowSprite'),
        x: _cx(integer(eng, stmt.args, 2)),
        y: _cx(integer(eng, stmt.args, 3)),
      );
      HDHosts().ui.refresh();
    });
    e.registerCommand('Actor::Move', (stmt, eng) async {
      final id = str(eng, stmt.args, 0);
      final actor = HDGameSession().actors[id];
      if (actor == null) {
        debugPrint('[cm2] Actor::Move("$id") — 그런 배우가 없다 (Actor::Show 먼저)');
        return;
      }
      actor.stepBy(
        integer(eng, stmt.args, 1),
        integer(eng, stmt.args, 2),
        nowMs: HDActorClock.nowMs,
        durationMs: actorStepMs,
      );
    });
    e.registerCommand('Actor::Wait', (_, _) async {
      final now = HDActorClock.nowMs;
      var until = now;
      for (final a in HDGameSession().actors.values) {
        if (a.arrivesAtMs > until) until = a.arrivesAtMs;
      }
      if (until > now) await Future.delayed(Duration(milliseconds: until - now));
    });
    e.registerCommand('Actor::Hide', (stmt, eng) async {
      HDGameSession().actors.remove(str(eng, stmt.args, 0));
      HDHosts().ui.refresh();
    });

    // ---- 예약 ----
    e.registerCommand('Timer::Set', (stmt, eng) async {
      HDGameSession().setTimer(
        integer(eng, stmt.args, 0, symbol: 'Timer::Set'),
        integer(eng, stmt.args, 1, symbol: 'Timer::Set'),
      );
    });
    e.registerCommand('Timer::Clear', (_, _) async {
      HDGameSession().clearTimer();
    });

    // ---- 연출 ----
    e.registerCommand('Music::Play', (stmt, eng) async {
      final name = str(eng, stmt.args, 0);
      HDGameSession().mapRuntime.music = name;
      HDAudio().playMusic(name);
    });
    e.registerCommand('Music::Stop', (_, _) async {
      HDGameSession().mapRuntime.music = null;
      HDAudio().stopMusic();
    });
    e.registerCommand('Sound::Play', (stmt, eng) async {
      HDAudio().playSound(str(eng, stmt.args, 0));
    });

    e.registerCommand('Screen::FadeOut', (stmt, eng) async {
      await HDHosts().ui.fade(
        out: true,
        milliseconds: integer(eng, stmt.args, 0, fallback: 600),
      );
    });
    e.registerCommand('Screen::FadeIn', (stmt, eng) async {
      await HDHosts().ui.fade(
        out: false,
        milliseconds: integer(eng, stmt.args, 0, fallback: 600),
      );
    });
    e.registerCommand('Screen::Flash', (stmt, eng) async {
      await HDHosts().ui.flash(
        milliseconds: integer(eng, stmt.args, 0, fallback: 120),
      );
    });
  }

  /// `Flag::*` · `Variable::*` 의 첫 인자. **번호는 받지 않는다.**
  String? _stateName(ScriptEngine eng, List<String> args, String symbol) {
    if (args.isEmpty) return null;
    final raw = eng.getVal(args[0]);
    if (raw is String && raw.isNotEmpty) return raw;
    debugPrint(
      '[cm2] $symbol(${args[0]}) — lore2026 은 이름을 쓴다 ("NAME"). 무시했다',
    );
    return null;
  }

  void _changeTile(int x, int y, int tile) {
    final session = HDGameSession();
    final unit = session.map?.getUnit(x, y);
    if (unit == null) {
      debugPrint(
        '[cm2] Map::ChangeTile(${scriptCoord(x)}, ${scriptCoord(y)}) 는 맵 밖이다',
      );
      return;
    }
    session.tileTable.entry(session.gameOption.mapName, tile).applyTo(unit);
  }

  List<int> _rect(ScriptEngine eng, List<String> args) => [
    for (var i = 0; i < 4; i++) _cx(integer(eng, args, i)),
  ];

  Future<void> _refreshDisplay() async {
    HDGameSession().mapVersion++;
    HDHosts().ui.refresh();
    HDGameSession().gameOption.refresh();
    await Future.delayed(const Duration(milliseconds: 16));
  }

  void _registerCoreFunctions(ScriptEngine e) {
    e.registerFunction('Flag::IsSet', (args, _) {
      final name = args.isNotEmpty ? args[0] : null;
      if (name is! String) {
        debugPrint('[cm2] Flag::IsSet($name) — 이름을 쓴다. 0 을 돌려준다');
        return 0;
      }
      return HDGameSession().gameOption.flag(name) ? 1 : 0;
    });

    e.registerFunction('Variable::Get', (args, _) {
      final name = args.isNotEmpty ? args[0] : null;
      if (name is! String) {
        debugPrint('[cm2] Variable::Get($name) — 이름을 쓴다. 0 을 돌려준다');
        return 0;
      }
      return HDGameSession().gameOption.variable(name);
    });

    // 「사건이 일어난 칸」. 타일이 부른 게 아니면(FLAG_MAP · FLAG_TIMER …)
    // 일행이 서 있는 자리를 본다.
    (int, int) eventCell(ScriptEngine eng) {
      if (eng.targetX != -1 && eng.targetY != -1) {
        return (eng.targetX, eng.targetY);
      }
      final party = HDGameSession().party;
      return (party.x, party.y);
    }

    // `Map::Is("E1_LastDitch")` — 지금 맵이 그 맵인가. 예언처럼 맵과 무관하게
    // 불리는 스크립트(episode.cm2)가 「어디에 있는가」를 볼 때 쓴다.
    e.registerFunction('Map::Is', (args, _) {
      if (args.isEmpty) return 0;
      return HDGameSession().gameOption.mapName == args[0].toString() ? 1 : 0;
    });

    // `Map::GetTile(x, y)` — 그 칸에 지금 깔린 원작 타일 번호 (`Map::ChangeTile`
    // 이 받는 번호). 그림과 행동이 같은 번호가 둘이면(들판 23·49, 동굴 0·52)
    // 작은 번호다. 맵 밖이거나 표에 없는 칸이면 -1.
    e.registerFunction('Map::GetTile', (args, _) {
      if (args.length < 2) return -1;
      final session = HDGameSession();
      final unit = session.map?.getUnit(_cx(num0(args, 0)), _cx(num0(args, 1)));
      if (unit == null) return -1;
      return session.tileTable.numberOf(session.gameOption.mapName, unit);
    });

    // `Map::IsPassable(x, y)` — 일행이 걸어서 그 칸에 들어설 수 있는가 (1/0).
    // 걷기와 같은 판정이다: 벽·사람·푯말·입구는 아니고, 물은 물 위를 걷는 동안만,
    // 맵 가장자리의 걷기 범위 밖도 아니다.
    e.registerFunction('Map::IsPassable', (args, _) {
      if (args.length < 2) return 0;
      final session = HDGameSession();
      final x = _cx(num0(args, 0)), y = _cx(num0(args, 1));
      final unit = session.map?.getUnit(x, y);
      if (unit == null || !session.isInsideWalkRange(x, y)) return 0;
      return HDTileProperties.isUnitPassable(
            unit,
            walkOnWater: session.party.walkOnWater,
          )
          ? 1
          : 0;
    });

    // `Map::IsTile(x, y, 타일)` — 그 칸이 지금 그 타일로 깔려 있으면 1.
    // 조건에는 이것을 쓴다 — 그림과 행동이 같은 짝이 있어도 틀리지 않는다.
    e.registerFunction('Map::IsTile', (args, _) {
      if (args.length < 3) return 0;
      final session = HDGameSession();
      final unit = session.map?.getUnit(_cx(num0(args, 0)), _cx(num0(args, 1)));
      if (unit == null) return 0;
      return session.tileTable.matches(
            session.gameOption.mapName,
            unit,
            num0(args, 2),
          )
          ? 1
          : 0;
    });

    e.registerFunction('On', (args, eng) {
      if (args.length < 2) return 0;
      final (x, y) = eventCell(eng);
      return (x == _cx(num0(args, 0)) && y == _cx(num0(args, 1))) ? 1 : 0;
    });

    e.registerFunction('OnArea', (args, eng) {
      if (args.length < 4) return 0;
      final (x, y) = eventCell(eng);
      final x1 = _cx(num0(args, 0)), y1 = _cx(num0(args, 1));
      final x2 = _cx(num0(args, 2)), y2 = _cx(num0(args, 3));
      final inX = x >= (x1 < x2 ? x1 : x2) && x <= (x1 > x2 ? x1 : x2);
      final inY = y >= (y1 < y2 ? y1 : y2) && y <= (y1 > y2 ? y1 : y2);
      return (inX && inY) ? 1 : 0;
    });

    e.registerFunction('Select::Result', (_, _) => HDSelect().result());

    e.registerFunction(
      'Party::PosX',
      (_, _) => scriptCoord(HDGameSession().party.x),
    );
    e.registerFunction(
      'Party::PosY',
      (_, _) => scriptCoord(HDGameSession().party.y),
    );
    e.registerFunction('Party::Faced', (_, _) => HDGameSession().party.faced);

    e.registerFunction('Party::Joined', (_, _) => lastJoinSucceeded ? 1 : 0);
    e.registerFunction('Party::JoinedSeat', (_, _) => lastJoinSeat);
    e.registerFunction('Item::Used', (_, _) => usedItemKey);
    e.registerFunction('Timer::Id', (_, _) => firedTimerId);

    // cm2 의 내장 비교는 Equal · Less 뿐이다.
    int cmp(List<dynamic> a) => num0(a, 0).compareTo(num0(a, 1));
    e.registerFunction('Greater', (a, _) => cmp(a) > 0 ? 1 : 0);
    e.registerFunction('GreaterEqual', (a, _) => cmp(a) >= 0 ? 1 : 0);
    e.registerFunction('LessEqual', (a, _) => cmp(a) <= 0 ? 1 : 0);
    e.registerFunction(
      'NotEqual',
      (a, _) => a.length < 2 || a[0].toString() != a[1].toString() ? 1 : 0,
    );
    e.registerFunction('Sub', (a, _) => num0(a, 0) - num0(a, 1));
    e.registerFunction('Mul', (a, _) => num0(a, 0) * num0(a, 1));
    e.registerFunction('Div', (a, _) {
      final d = num0(a, 1);
      if (d == 0) {
        debugPrint('[cm2] Div 의 나누는 수가 0 이다 — 0 을 돌려준다');
        return 0;
      }
      return num0(a, 0) ~/ d;
    });
    e.registerFunction('Mod', (a, _) {
      final d = num0(a, 1);
      return d == 0 ? 0 : num0(a, 0) % d;
    });

    e.registerFunction('Josa', (a, _) {
      if (a.length < 2) return a.isEmpty ? '' : a[0].toString();
      return josa(a[0].toString(), a[1].toString());
    });
  }
}
