import 'dart:io';

import 'package:lore2026_app/application/ports/asset_source.dart';
import 'package:lore2026_app/application/ports/movement_host.dart';
import 'package:lore2026_app/application/ports/ui_host.dart';

/// 앱의 `assets/` 를 디스크에서 그대로 읽는다 (시험은 앱 폴더에서 돈다).
class DiskAssets implements AssetSource {
  @override
  Future<String> loadString(String path) => File(path).readAsString();
}

/// 메뉴에 정해 둔 답을 넣는 가짜 화면.
///
/// [answer] 가 메뉴의 항목(0번은 물음)을 받아 고를 번호를 돌려준다. 낸 글은
/// [lines] 에, 물은 메뉴는 [menus] 에 쌓인다.
class ScriptedUi implements UiHost {
  ScriptedUi(this.answer, {this.name = '슴갈'});

  final int Function(List<String> items) answer;
  final String name;

  final List<String> lines = [];
  final List<List<String>> menus = [];

  /// 글을 색 표기 없이.
  List<String> get plainLines => [
    for (final l in lines) l.replaceAll(RegExp(r'@[0-9A-G@]'), ''),
  ];

  int _pick(List<String> items) {
    menus.add(items);
    final n = answer(items);
    if (n < 0 || n >= items.length) {
      throw StateError('no scripted answer in range for: ${items.first}');
    }
    return n;
  }

  @override
  Future<int> showMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    bool clearLogs = true,
  }) async => _pick(items);

  @override
  Future<int> showWindowMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    int? x,
    int? y,
  }) async => _pick(items);

  @override
  Future<void> showMessageWindow(String text, {int? x, int? y}) async =>
      lines.add(text);

  /// 글이 나올 때마다 부른다 — 장면 한가운데의 상태를 붙잡는 시험이 쓴다.
  void Function(String line)? onLine;

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async {
    lines.add(message);
    onLine?.call(message);
  }

  @override
  Future<void> waitForAnyKey() async {}

  @override
  void clearLogs() {}

  @override
  void setHeader(String text) {}

  @override
  void beginNarrative() {}

  @override
  Future<void> endNarrative({String? summary, bool autoFlush = true}) async {}

  @override
  void refresh() {}

  @override
  Future<void> preloadAssets() async {}

  @override
  Future<String?> askText(
    String prompt, {
    int maxLength = 8,
    String initial = '',
  }) async => name;

  @override
  Future<void> fade({required bool out, int milliseconds = 600}) async {}

  @override
  Future<void> flash({int milliseconds = 120}) async {}

  /// 편지 화면 — 문단을 글로 남긴다(색 표시는 [plainLines] 가 걷어 낸다).
  final List<({int color, int mode})> letters = [];

  @override
  Future<void> showLetter(
    List<String> paragraphs, {
    int color = 15,
    int mode = 0,
    List<List<List<int>>?>? pictures,
  }) async {
    letters.add((color: color, mode: mode));
    letterPictures.add(pictures);
    lines.addAll(paragraphs);
  }

  /// 편지마다 붙은 그림 (없으면 null).
  final List<List<List<List<int>>?>?> letterPictures = [];

  /// 지도 칸에 띄운 이름 목록 — 띄울 때마다 쌓는다(빈 목록은 걷은 것).
  final List<List<({String text, int color})>> nameLists = [];

  @override
  void showNameList(List<({String text, int color})> lines) => nameLists.add(lines);
}

/// 걷는 연출 없이 자리만 옮긴다.
class InstantMovement implements PartyMovementHost {
  InstantMovement(this.move);

  final void Function(int dx, int dy) move;

  @override
  Future<void> animatePartyMove(int dx, int dy) async => move(dx, dy);
}
