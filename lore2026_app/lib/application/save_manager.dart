import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/game_option.dart';
import '../domain/map/map_model.dart';
import 'audio.dart';
import 'game_session.dart';
import 'map_navigation.dart';
import 'ports/host_binding.dart';
import 'scripting/script_engine_adapter.dart';

/// 저장 칸 하나의 요약 — 불러오기 메뉴가 「무엇이 들어 있는지」 보여 줄 때 쓴다.
class HDSaveSummary {
  const HDSaveSummary({
    required this.slot,
    required this.episode,
    required this.name,
    required this.mapTitle,
    required this.year,
    required this.month,
    required this.day,
  });

  final int slot;
  final int episode;
  final String name;
  final String mapTitle;
  final int year;
  final int month;
  final int day;
}

/// 저장과 불러오기.
///
/// 세이브 하나에 들어가는 것(부록 B.5):
///
/// * `party` — 자리와 세계 전체(인물 · 소지품 · 달력 · 횃불 · 효과 · 설정)
/// * `gameOption` — 플래그와 변수(이름으로), 지금 맵
/// * `map` — **지금 맵의 칸 배열 전체.** 원작과 같다: 맵 안에서 바뀐 것
///   (연 문 · 사라진 사람 · 마법으로 바꾼 지형)이 그대로 돌아온다
/// * `mapRuntime` — 그 맵의 스크립트가 `FLAG_MAP` 에서 정해 둔 것
///   (조우 표 · 막히는 마법 · 암흑 구역 · 음악)
/// * `timer` — 예약한 사건. 원작은 예약이 있으면 저장을 막았다
///
/// 불러올 때 **`FLAG_MAP` 을 다시 돌리지 않는다** — 돌리면 저장된 맵 위에
/// 입장 때의 변경이 한 번 더 적용된다.
class HDSaveManager {
  static const String _savePrefix = 'lore2026_save_';

  /// 형식 번호. 2 는 hadar2026_app 의 것이므로 건너뛴다.
  static const int _version = 100;

  /// 저장 칸의 수 (본 게임 데이터 + 부 데이터 셋).
  static const int slotCount = 4;

  static Future<bool> saveGame(int index) async {
    final session = HDGameSession();
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {
        'version': _version,
        'episode': session.episode,
        'party': session.party.toJson(),
        'gameOption': session.gameOption.toJson(),
        'map': session.map?.toJson(),
        'mapRuntime': session.mapRuntime.toJson(),
        'lightAreas': session.lightAreas.toJson(),
        if (session.timer != null) 'timer': session.timer!.toJson(),
      };
      await prefs.setString('$_savePrefix$index', jsonEncode(data));
      return true;
    } catch (e) {
      debugPrint("Failed to save game: $e");
      return false;
    }
  }

  /// 칸 [index] 에 무엇이 들어 있는지. 비었거나 읽을 수 없으면 null.
  static Future<HDSaveSummary?> summary(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString('$_savePrefix$index');
      if (text == null || text.isEmpty) return null;
      final data = jsonDecode(text) as Map<String, dynamic>;
      if (data['version'] != _version) return null;
      final world = (data['party'] as Map?)?['world'] as Map?;
      final seats = world?['seats'] as List?;
      final hero = (seats != null && seats.isNotEmpty) ? seats[0] as Map? : null;
      final calendar = world?['calendar'] as Map?;
      final mapName = (data['gameOption'] as Map?)?['mapName'] as String? ?? '';
      final info = await HDMapNavigation().info(mapName);
      return HDSaveSummary(
        slot: index,
        episode: data['episode'] as int? ?? 0,
        name: hero?['name'] as String? ?? '',
        mapTitle: info?.title ?? mapName,
        year: calendar?['year'] as int? ?? 0,
        month: calendar?['month'] as int? ?? 0,
        day: calendar?['day'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('Failed to read save $index: $e');
      return null;
    }
  }

  static Future<bool> loadGame(int index) async {
    final session = HDGameSession();
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('$_savePrefix$index');
      if (jsonString == null || jsonString.isEmpty) {
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(jsonString);
      if (data['version'] != _version || data['party'] == null) return false;

      for (final issue in session.party.fromJson(
        (data['party'] as Map).cast<String, dynamic>(),
      )) {
        debugPrint('[save] $issue');
      }
      final savedX = session.party.x;
      final savedY = session.party.y;
      final savedFaced = session.party.faced;

      final savedOption = HDGameOption.fromJson(
        ((data['gameOption'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
      session.gameOption
        ..flags = savedOption.flags
        ..variables = savedOption.variables
        ..mapType = savedOption.mapType
        ..scriptFile = savedOption.scriptFile
        ..mapName = savedOption.mapName;

      // The map's metadata and both scripts — without running FLAG_MAP.
      session.mapInfo = await HDMapNavigation().info(savedOption.mapName);
      session.currentMapCm2Path = null;
      if (savedOption.scriptFile.isNotEmpty &&
          await HDScriptEngine().loadScript(savedOption.scriptFile)) {
        session.currentMapCm2Path = savedOption.scriptFile;
      }
      await HDScriptEngine().loadEpisode(session.episode);
      HDScriptEngine().pendingNavigation = null;
      HDScriptEngine().arrivalLines.clear();
      session.party.hidden = false;

      session.mapRuntime.fromJson(
        (data['mapRuntime'] as Map?)?.cast<String, dynamic>(),
      );
      session.lightAreas.fromJson(data['lightAreas']);
      session.timer = HDTimer.fromJson(data['timer']);

      if (data['map'] != null) {
        session.setNewMap(
          MapModel.fromJson((data['map'] as Map).cast<String, dynamic>()),
        );
      }

      // Restore position after everything that might have moved it.
      session.party.setPosition(savedX, savedY);
      session.party.faced = savedFaced;

      final music = session.mapRuntime.music;
      music == null ? HDAudio().stopMusic() : HDAudio().playMusic(music);

      session.mapVersion++;
      HDHosts().ui.refresh();
      return true;
    } catch (e) {
      debugPrint("Failed to load game: $e");
      return false;
    }
  }
}
