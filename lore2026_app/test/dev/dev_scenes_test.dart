import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore2026_app/application/dev/dev_jump.dart';
import 'package:lore2026_app/application/dev/dev_scenes.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/domain/map/tile_properties.dart';

import '../flow/fake_hosts.dart';

/// 개발자 모드의 장면 자료(`assets/dev/ep<N>.json`)를 실제로 건너뛰어 본다.
///
/// 장면마다:
/// * 적은 플래그 · 변수 이름이 그 편의 대본에 실제로 있는가 (오타는 조용히 꺼진 플래그가 된다)
/// * 동료 · 보조 일원 · 물건 열쇠가 있는가
/// * 그 맵이 올라오고, 서는 칸이 걸을 수 있는 칸인가 — 아니면 가까운 걸을 수 있는 칸을 알려 준다
/// * `goal` 을 적었으면 그 칸(또는 그 옆 칸)까지 걸어서 닿는가
/// * 맵의 시작 스크립트가 모르는 이름을 만나지 않는가
void main() {
  late List<String> logs;
  final original = debugPrint;

  setUp(() {
    logs = [];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() {
    debugPrint = original;
    HDHosts().reset();
  });

  final infos = jsonDecode(File('assets/maps/MapInfos.json').readAsStringSync()) as List;
  final mapNames = {
    for (final e in infos)
      if (e != null) e['name'] as String,
  };

  for (final episode in [1, 2, 3]) {
    final file = File('assets/dev/ep$episode.json');
    if (!file.existsSync()) continue;
    final book = DevSceneBook.parse(file.readAsStringSync());

    // 그 편의 대본이 쓰는 이름
    final scripts = [
      for (final f in Directory('assets/ep$episode').listSync().whereType<File>())
        if (f.path.endsWith('.cm2')) f.readAsStringSync(),
    ].join('\n');
    final knownFlags = {
      for (final m in RegExp(r'Flag::(?:Set|IsSet|Reset)\("(\w+)"\)').allMatches(scripts)) m.group(1)!,
    };
    final knownVars = {
      for (final m in RegExp(r'Variable::(?:Set|Get|Add)\("(\w+)"').allMatches(scripts)) m.group(1)!,
    };

    test('제$episode부 장면 ${book.scenes.length}개 — 자료', () {
      final ids = <String>{};
      final problems = <String>[];
      final roster = rosterOf(Episode.fromNumber(episode)!);
      expect(book.episode, episode);
      for (final s in book.scenes) {
        if (!ids.add(s.id)) problems.add('${s.id}: id 가 겹친다');
        if (!mapNames.contains(s.map)) problems.add('${s.id}: 맵 ${s.map} 이(가) MapInfos 에 없다');
        late DevSceneState st;
        try {
          st = book.resolve(s.id);
        } catch (e) {
          problems.add('${s.id}: $e');
          continue;
        }
        for (final raw in (s.raw['flags'] as List? ?? const []).cast<String>()) {
          final f = raw.startsWith('-') ? raw.substring(1) : raw;
          if (!knownFlags.contains(f)) problems.add('${s.id}: 플래그 $f 를 대본이 쓰지 않는다');
        }
        for (final v in (s.raw['vars'] as Map? ?? const {}).keys) {
          if (!knownVars.contains(v)) problems.add('${s.id}: 변수 $v 를 대본이 쓰지 않는다');
        }
        for (final k in st.party) {
          if (roster[k]?.seat != RosterSeat.companion) problems.add('${s.id}: 동료 $k 이(가) 명부에 없다');
        }
        final a = st.assistant;
        if (a != null && roster[a]?.seat != RosterSeat.assistant) {
          problems.add('${s.id}: 보조 일원 $a 이(가) 명부에 없다');
        }
        if (st.party.length > 4) problems.add('${s.id}: 동료가 넷보다 많다');
        for (final key in st.items.keys) {
          if (consumableByKey(key) == null && crystalByKey(key) == null && equipSlotOf(key) == null) {
            problems.add('${s.id}: 물건 $key 이(가) 없다');
          }
        }
        for (final v in st.vars.values) {
          if (v is String && DevSceneState.relative.firstMatch(v) == null) {
            problems.add('${s.id}: 변수 값 "$v" 을(를) 읽을 수 없다');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('제$episode부 장면 ${book.scenes.length}개 — 건너뛰어 본다', () async {
      final ui = ScriptedUi((items) {
        final attack = items.skip(1).toList().indexWhere((o) => o.contains('공격'));
        return attack >= 0 ? attack + 1 : 1;
      });
      final session = HDGameSession();
      final engine = HDScriptEngine();
      HDHosts().bind(
        ui: ui,
        movement: InstantMovement(session.party.move),
        assets: DiskAssets(),
      );
      await session.init();
      HDDevJump().forget();

      final failures = <String>[];
      for (final s in book.scenes) {
        // 도착하자마자 엔딩으로 넘어가는 장면은 건너뛰지 않는다 — 엔딩이 제목 화면 흐름을 뒤에서
        // 다시 띄워(returnToTitle) 다음 장면을 흔든다. 자료 검사는 위에서 했다.
        if (s.raw['ending'] == true) continue;
        logs.clear();
        try {
          await runZoned(
            () async {
              await HDDevJump().jump(book, s.id);
              await engine.executePendingNavigation().timeout(const Duration(seconds: 20));
            },
            zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, line) => logs.add(line),
            ),
          );
        } catch (e) {
          failures.add('${s.id}: $e');
          continue;
        }
        if (session.mapInfo?.name != s.map) {
          failures.add('${s.id}: ${s.map} 이 아니라 ${session.mapInfo?.name} 에 있다 (시작 스크립트가 옮겼다?)');
          continue;
        }
        final bad = logs.where((l) => l.contains('Unknown') || l.contains('[cm2]'));
        if (bad.isNotEmpty) failures.add('${s.id}: ${bad.take(2).join(' | ')}');

        // 시작 스크립트가 일행을 걸려 옮겼을 수 있다(Chamber 의 입장) — 지금 선 자리를 본다
        final x = session.party.x, y = session.party.y;
        bool walkable(int cx, int cy) =>
            session.isInsideWalkRange(cx, cy) &&
            HDTileProperties.isUnitPassable(session.map!.getUnit(cx, cy));
        if (!walkable(x, y)) {
          failures.add('${s.id}: ${s.map} (${x + 1},${y + 1}) 에 설 수 없다 — 가까운 칸: ${_near(walkable, x, y)}');
          continue;
        }
        final goal = s.raw['goal'] as List?;
        if (goal != null) {
          final gx = (goal[0] as num).toInt() - 1, gy = (goal[1] as num).toInt() - 1;
          if (!_reaches(walkable, x, y, gx, gy)) {
            failures.add('${s.id}: (${x + 1},${y + 1}) 에서 goal (${gx + 1},${gy + 1}) 까지 걸어서 닿지 않는다');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}

/// 가까운 걸을 수 있는 칸 다섯 (스크립트 좌표).
String _near(bool Function(int, int) ok, int x, int y) {
  final found = <String>[];
  for (var r = 1; r <= 6 && found.length < 5; r++) {
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        if (dx.abs() != r && dy.abs() != r) continue;
        if (ok(x + dx, y + dy)) found.add('(${x + dx + 1},${y + dy + 1})');
      }
    }
  }
  return found.take(5).join(' ');
}

/// (x,y) 에서 걸어서 (gx,gy) 나 그 옆 칸에 닿는가.
bool _reaches(bool Function(int, int) ok, int x, int y, int gx, int gy) {
  final seen = <int>{};
  final queue = Queue<(int, int)>()..add((x, y));
  seen.add(y * 10000 + x);
  while (queue.isNotEmpty) {
    final (cx, cy) = queue.removeFirst();
    if ((cx - gx).abs() + (cy - gy).abs() <= 1) return true;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = cx + dx, ny = cy + dy;
      if (!ok(nx, ny) || !seen.add(ny * 10000 + nx)) continue;
      queue.add((nx, ny));
    }
  }
  return false;
}
