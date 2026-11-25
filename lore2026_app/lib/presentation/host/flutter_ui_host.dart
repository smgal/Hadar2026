import 'dart:async';

import 'package:bonfire/bonfire.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/game_session.dart';
import '../../application/ports/movement_host.dart';
import '../../application/ports/ui_host.dart';
import '../../domain/console/console_log.dart';
import '../../hd_config.dart';
import '../../utils/hd_text_utils.dart';
import '../../domain/window/letter_window_data.dart';
import '../../domain/window/message_window_data.dart';
import '../../domain/window/selection_window_data.dart';
import '../../domain/window/text_input_window_data.dart';
import '../../application/window_manager.dart';
import '../panels/player_sprite.dart';

/// One-shot menu request: a title row plus N selectable choices.
/// Lives in the host because it is purely a render/input artifact —
/// domain code talks to [UiHost.showMenu] and never sees this type.
class HDMenu {
  final List<String> items; // Index 0 is title, items 1+ are choices
  int selectedIndex;
  int enabledCount;
  final bool clearLogs;
  final Completer<int> completer = Completer<int>();

  HDMenu(
    this.items, {
    int initialChoice = 1,
    int enabledCount = -1,
    this.clearLogs = true,
  }) : selectedIndex = initialChoice,
       enabledCount = (enabledCount == -1) ? items.length - 1 : enabledCount;
}

/// Concrete [UiHost] backed by the 800×480 Flutter console panel.
///
/// Owns the console log, the active menu, and the "waiting for any key"
/// completer. Word-wrap of dialog lines (which uses [TextPainter]) happens
/// here, so the domain only sees raw `@X..@@` tagged strings — keeping the
/// option open to swap in a different host (headless tester, alternate
/// layout) without touching the domain.
class HDFlutterUiHost extends ChangeNotifier
    implements UiHost, PartyMovementHost {
  static final HDFlutterUiHost _instance = HDFlutterUiHost._internal();
  factory HDFlutterUiHost() => _instance;
  HDFlutterUiHost._internal();

  /// Bonfire game ref captured by the map viewport on `onReady`. Stays
  /// inside the presentation layer so application/script code never
  /// names a Bonfire/Flame type.
  BonfireGameInterface? _bonfireGame;
  BonfireGameInterface? get bonfireGame => _bonfireGame;
  void attachBonfireGame(BonfireGameInterface? game) {
    _bonfireGame = game;
  }

  // --- console wrap settings (view concerns; live with the Flutter host) ---
  static const int _maxLinesPerPage = HDConfig.maxLinesPerPage;
  static const int _maxProgressLines = HDConfig.maxProgressLines;
  // Padding (2 × 16) plus one glyph of slack: a line measured word by
  // word can still come out a hair wider than the panel draws it, and a
  // second wrap on screen pushes the page past the panel's bottom.
  static const double _consoleWidth = HDConfig.consoleWidth - 32.0 - 16.0;
  // **The font must be the one the panels draw with.** Measured in the
  // default font, a line came out shorter than DungGeunMo draws it, so
  // every line wrapped a second time on screen and the page overflowed.
  static const TextStyle _consoleStyle = TextStyle(
    fontFamily: 'DungGeunMo',
    fontSize: HDConfig.consoleFontSize,
    height: HDConfig.consoleLineHeight,
  );

  /// 대화 창 한 쪽에 들어가는 줄 수. 머리글이 있으면 그만큼 줄어든다.
  ///
  /// `HDDialogPanel` 의 배치를 그대로 셈한다 — 위아래 여백 8 · 테두리 1 ·
  /// 아래 「계속하려면 누르십시오 ...」 줄과 그 위 간격 · 머리글 줄과 그 아래 간격.
  /// 머리글이 없으면 13줄, 한 줄짜리 머리글이 있으면 10줄이다. 예전에는 늘 13줄이라
  /// 머리글이 있는 긴 글(1부 오프닝)의 마지막 줄이 「계속하려면」 줄을 덮었다.
  int get linesPerPage {
    const line = HDConfig.consoleFontSize * HDConfig.consoleLineHeight;
    var body = HDConfig.consoleHeight - 16 - 2 - (line + HDConfig.dialogSectionGap);
    if (_header.isNotEmpty) {
      final headerLines = HDTextUtils.splitToRawLines(_header, _consoleWidth, _consoleStyle).length;
      body -= headerLines * line + HDConfig.dialogSectionGap;
    }
    return (body / line).floor().clamp(1, _maxLinesPerPage);
  }

  // --- state ---
  final HDConsoleLog consoleLog = HDConsoleLog();
  HDMenu? activeMenu;

  /// Dialogue header (top line of the dialog panel). Empty string means
  /// "no header" and the dialog panel reserves no space for it.
  String _header = '';
  String get header => _header;

  /// True between [beginNarrative] and [endNarrative]. Holds the overlay
  /// open even when events briefly empty (page flush during a long
  /// dialogue, or a menu→message cycle that hasn't pushed events yet).
  bool _narrativeActive = false;

  Completer<void>? _keyWaitCompleter;
  bool get isWaitingForKey => _keyWaitCompleter != null;

  /// Stack-overlay model: base layer is the progress log; the overlay is
  /// shown when a narrative cycle is active OR a menu is up OR there are
  /// pending event lines.
  HDConsoleViewMode get viewMode =>
      (_narrativeActive || activeMenu != null || consoleLog.events.isNotEmpty)
      ? HDConsoleViewMode.overlay
      : HDConsoleViewMode.progress;

  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) super.notifyListeners();
    });
  }

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async {
    // Wrap with a color-less base style so the raw serializer can tell
    // "no color tag" from "default color".
    List<String> newLines = [];
    if (message.trim().isEmpty) {
      newLines = [''];
    } else {
      newLines = HDTextUtils.splitToRawLines(
        message,
        _consoleWidth,
        _consoleStyle,
      );
      if (newLines.isEmpty) newLines = [''];
    }

    for (final line in newLines) {
      if (isDialogue) {
        if (consoleLog.events.length >= linesPerPage) {
          // Internal page flush within a single dialogue — same speaker,
          // same header. Clear only the event body so the header survives
          // across the PressAnyKey; full clearLogs() (which also wipes the
          // header) is reserved for narrative-cycle boundaries.
          await waitForAnyKey();
          consoleLog.clearEvents();
          notifyListeners();
          await Future.delayed(Duration.zero);
        }
        consoleLog.appendEvent(line);
      } else {
        consoleLog.appendProgress(line, maxLinesPerPage: _maxProgressLines);
      }

      notifyListeners();
      // Allow UI to render the added line
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  Future<int> showMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    bool clearLogs = true,
  }) async {
    if (clearLogs) this.clearLogs();
    final menu = HDMenu(
      items,
      initialChoice: initialChoice,
      enabledCount: enabledCount,
      clearLogs: clearLogs,
    );
    activeMenu = menu;
    notifyListeners();
    return await menu.completer.future;
  }

  @override
  Future<int> showWindowMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    int? x,
    int? y,
  }) async {
    final window = HDSelectionWindow(
      choices: items,
      selectedIndex: initialChoice,
      enabledCount: enabledCount,
      x: x,
      y: y,
    );
    HDWindowManager().addWindow(window);
    try {
      return await window.result;
    } finally {
      HDWindowManager().removeWindow(window);
    }
  }

  @override
  Future<void> showMessageWindow(String text, {int? x, int? y}) async {
    final window = HDMessageWindow(text, x: x, y: y);
    HDWindowManager().addWindow(window);
    try {
      await window.waitForClose();
    } finally {
      HDWindowManager().removeWindow(window);
    }
  }

  @override
  Future<String?> askText(
    String prompt, {
    int maxLength = 8,
    String initial = '',
  }) async {
    final window = HDTextInputWindow(
      prompt: prompt,
      maxLength: maxLength,
      initial: initial,
    );
    HDWindowManager().addWindow(window);
    try {
      return await window.result;
    } finally {
      HDWindowManager().removeWindow(window);
    }
  }

  /// 0 = clear, 1 = fully covered. The shell paints [screenCoverColor]
  /// over everything at this opacity.
  final ValueNotifier<double> screenCover = ValueNotifier<double>(0);
  Color screenCoverColor = const Color(0xFF000000);

  Future<void> _animateCover(double from, double to, int milliseconds) async {
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      screenCover.value = from + (to - from) * i / steps;
      await Future.delayed(Duration(milliseconds: milliseconds ~/ steps));
    }
    screenCover.value = to;
  }

  @override
  Future<void> fade({required bool out, int milliseconds = 600}) async {
    final target = out ? 1.0 : 0.0;
    if (screenCover.value == target) return; // 이미 그 상태
    screenCoverColor = const Color(0xFF000000);
    await _animateCover(screenCover.value, target, milliseconds);
  }

  /// 지도 칸을 덮는 이름 목록 (`showNameList`). 비어 있으면 그리지 않는다.
  final ValueNotifier<List<({String text, int color})>> nameList =
      ValueNotifier(const []);

  @override
  void showNameList(List<({String text, int color})> lines) =>
      nameList.value = List.unmodifiable(lines);

  @override
  Future<void> showLetter(
    List<String> paragraphs, {
    int color = 15,
    int mode = 0,
    List<List<List<int>>?>? pictures,
  }) async {
    final window = HDLetterWindow(
      paragraphs: paragraphs,
      color: color.clamp(0, 15).toRadixString(16).toUpperCase(),
      mode: HDLetterMode.fromWire(mode),
      pictures: pictures,
    );
    HDWindowManager().addWindow(window);
    try {
      await window.waitForClose();
    } finally {
      HDWindowManager().removeWindow(window);
    }
  }

  @override
  Future<void> flash({int milliseconds = 120}) async {
    final before = screenCover.value;
    screenCoverColor = const Color(0xFFFFFFFF);
    screenCover.value = 0.85;
    await Future.delayed(Duration(milliseconds: milliseconds));
    screenCoverColor = const Color(0xFF000000);
    screenCover.value = before;
  }

  @override
  Future<void> waitForAnyKey() {
    if (_keyWaitCompleter != null) return _keyWaitCompleter!.future;
    _keyWaitCompleter = Completer<void>();
    notifyListeners();
    return _keyWaitCompleter!.future;
  }

  @override
  void clearLogs() {
    consoleLog.clearEvents();
    // Header lives with the body it titles — clearing the body clears
    // the header too (covers page-flush, narrative entry, and
    // endNarrative without each caller having to remember).
    _header = '';
    notifyListeners();
  }

  @override
  void setHeader(String text) {
    if (_header == text) return;
    _header = text;
    notifyListeners();
  }

  @override
  void beginNarrative() {
    if (_narrativeActive) return;
    _narrativeActive = true;
    notifyListeners();
  }

  @override
  Future<void> endNarrative({String? summary, bool autoFlush = true}) async {
    // If the script left a one-shot message on screen (e.g. a sign whose
    // dialogLines were rendered without a PressAnyKey), give the user a
    // chance to read it before tearing the overlay down. Skipping this
    // would make the text flash and disappear immediately.
    if (autoFlush && consoleLog.events.isNotEmpty) {
      await waitForAnyKey();
    }
    consoleLog.clearEvents();
    _header = '';
    if (summary != null && summary.isNotEmpty) {
      // Wrap the summary the same way addLog() does, so it survives
      // word-wrap at the panel width and renders identically to other
      // progress lines.
      final lines = HDTextUtils.splitToRawLines(
        summary,
        _consoleWidth,
        _consoleStyle,
      );
      for (final line in lines) {
        consoleLog.appendProgress(line, maxLinesPerPage: _maxProgressLines);
      }
    }
    _narrativeActive = false;
    notifyListeners();
  }

  /// Reset all observable state. Singleton means the fields persist
  /// across tests; this method gives a unit test a clean slate.
  @visibleForTesting
  void resetForTest() {
    consoleLog.clearEvents();
    consoleLog.clearProgress();
    activeMenu = null;
    _header = '';
    _narrativeActive = false;
    _keyWaitCompleter = null;
    _bonfireGame = null;
    screenCover.value = 0;
  }

  @override
  void refresh() => notifyListeners();

  @override
  Future<void> preloadAssets() async {
    try {
      await Flame.images.loadAll([
        HDConfig.mainSpriteSheet,
        HDConfig.mainTileSheet,
      ]);
    } catch (e) {
      debugPrint("Pre-cache error: $e");
    }
  }

  @override
  Future<void> animatePartyMove(int dx, int dy) async {
    final player = _bonfireGame?.player;
    if (player is HDPlayerSprite) {
      // forceMove drives the sprite tween and syncs domain coords on
      // each tile boundary.
      await player.forceMove(dx, dy);
      return;
    }
    // No viewport attached (headless / CLI / pre-onReady): bump domain
    // coordinates directly so script flow stays consistent.
    HDGameSession().party.move(dx, dy);
  }

  /// Called by the input dispatcher when a key arrives during dialogue.
  void dismissKeyWait() {
    if (_keyWaitCompleter != null && !_keyWaitCompleter!.isCompleted) {
      _keyWaitCompleter!.complete();
      _keyWaitCompleter = null;
      notifyListeners();
    }
  }
}
