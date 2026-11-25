import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart' show Flame;
import 'package:flutter/material.dart';
import '../../domain/window/game_window.dart';
import '../../domain/window/letter_window_data.dart';
import '../../domain/window/map_overview_window_data.dart';
import '../../domain/window/scenery_window_data.dart';
import '../../domain/window/message_window_data.dart';
import '../../domain/window/selection_window_data.dart';
import '../../domain/window/text_input_window_data.dart';
import '../../application/window_manager.dart';
import '../host/flutter_ui_host.dart';
import '../../hd_config.dart';
import '../../utils/hd_text_utils.dart';

class HDWindowLayer extends StatelessWidget {
  const HDWindowLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HDWindowManager(),
      builder: (context, child) {
        final windows = HDWindowManager().windows;
        return Stack(
          fit: StackFit.expand,
          children: windows.map((w) => HDWindowWidget(window: w)).toList(),
        );
      },
    );
  }
}

class HDWindowWidget extends StatelessWidget {
  final HDWindow window;

  const HDWindowWidget({super.key, required this.window});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: window,
      builder: (context, child) {
        if (!window.isVisible) {
          // print("Window ${window.hashCode} is not visible");
          return const SizedBox.shrink();
        }

        // 편지 화면은 틀 없이 화면 전체를 쓴다.
        if (window is HDLetterWindow) {
          return Positioned.fill(child: _LetterBody(window: window as HDLetterWindow));
        }

        // Convert game coordinates to logical pixels?
        // Assuming 1:1 for now or 800x600 fixed container.
        var left = window.x.toDouble();
        var width = window.w.toDouble();
        if (window is HDSelectionWindow) {
          (left, width) = selectionBox(
            window as HDSelectionWindow,
            base: DefaultTextStyle.of(context).style,
            scaler: MediaQuery.textScalerOf(context),
          );
        }
        return Positioned(
          left: left,
          top: window.y.toDouble(),
          width: width,
          height: window.h.toDouble(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(8),
            child: _buildContent(window),
          ),
        );
      },
    );
  }

  /// 선택 창의 (왼쪽, 너비). 정해 둔 너비(400)에 가장 긴 줄이 안 들어가면 넓히고,
  /// 화면(800) 오른쪽을 넘으면 왼쪽으로 옮긴다.
  ///
  /// 예: 주인공 만들기 6번 질문의 「1번과 같은 불확실한 도전을 하는 것보다는 확실한
  /// 탈출구인 이 문을 끝까지 열려 한다」는 400 픽셀 창 밖으로 잘려 나갔다.
  /// 그래도 넘치는 줄은 끝을 「…」로 줄인다 (`_buildSelection`).
  ///
  /// [base] 는 그 자리의 기본 글씨(`DefaultTextStyle`)다 — 테마가 글자 사이를 띄워서,
  /// 글꼴과 크기만으로 재면 그리는 것보다 짧게 나왔다.
  @visibleForTesting
  static (double, double) selectionBox(
    HDSelectionWindow window, {
    TextStyle base = const TextStyle(fontFamily: 'DungGeunMo'),
    TextScaler scaler = TextScaler.noScaling,
  }) {
    // 고른 줄은 굵게 그리므로 굵은 글씨로 잰다.
    final style = base.merge(const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
    // 창 테두리 2·2 + 창 여백 8·8 = 20. 줄은 여백 8·8 + 화살표 16 + 사이 8 = 32,
    // 머리글은 여백 4·4 + 테두리 1·1 = 10. 재는 값과 그리는 값의 오차로 여유 8.
    const frame = 20.0, row = 32.0, head = 10.0, slack = 8.0;
    var need = window.w.toDouble();
    for (var i = 0; i < window.choices.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: window.choices[i], style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      need = math.max(need, tp.width + frame + (i == 0 ? head : row) + slack);
    }
    const margin = 8.0;
    final width = math.min(need, HDConfig.gameScreenWidth - margin * 2);
    final left = math.max(margin, math.min(window.x.toDouble(), HDConfig.gameScreenWidth - margin - width));
    return (left, width);
  }

  Widget _buildContent(HDWindow window) {
    if (window is HDMessageWindow) {
      // Fixed-size box: top-aligned so multi-line signs read naturally
      // and overlong text clips at the bottom rather than re-centering.
      // Footer reuses the console-side wording ("계속하려면 누르십시오 ...")
      // so the dismiss affordance reads the same across both paths.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                window.text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const _BlinkingDismissHint(),
        ],
      );
    }
    if (window is HDTextInputWindow) {
      // 창마다 새 State — 같은 자리에 다시 묻는 창이 오면(빈 이름 등) 옛 State 를
      // 다시 쓰면서 입력 포커스를 잃는다.
      return _TextInputBody(key: ObjectKey(window), window: window);
    }
    if (window is HDMapOverviewWindow) {
      return _MapOverviewBody(window: window);
    }
    if (window is HDSceneryWindow) {
      return _SceneryBody(window: window);
    }
    if (window is HDSelectionWindow) {
      return _buildSelection(window);
    }
    return const SizedBox.shrink();
  }

  /// Overlays ▲/▼ chevrons on the right edge of a scrolling list to signal
  /// that more items exist above or below the current viewport. Used by every
  /// selection-style popup so the affordance stays consistent.
  Widget _wrapWithScrollIndicators({
    required Widget child,
    required bool hasMoreAbove,
    required bool hasMoreBelow,
  }) {
    return Stack(
      children: [
        child,
        if (hasMoreAbove)
          const Positioned(
            top: 0,
            right: 4,
            child: Icon(
              Icons.keyboard_arrow_up,
              color: Colors.yellow,
              size: 18,
            ),
          ),
        if (hasMoreBelow)
          const Positioned(
            bottom: 0,
            right: 4,
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.yellow,
              size: 18,
            ),
          ),
      ],
    );
  }

  Widget _buildSelection(HDSelectionWindow window) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (window.choices.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade900,
              border: Border.all(color: Colors.blue.shade400),
            ),
            width: double.infinity,
            child: Text(
              window.choices[0],
              style: const TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _wrapWithScrollIndicators(
            hasMoreAbove: window.hasMoreAbove,
            hasMoreBelow: window.hasMoreBelow,
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(
                window.choices.length - 1,
                window.maxVisibleItems,
              ),
              itemBuilder: (context, index) {
                int actualIndex = window.displayStartIndex + index;
                if (actualIndex >= window.choices.length) {
                  return const SizedBox.shrink();
                }
                String label = window.choices[actualIndex];
                bool isSelected = (actualIndex == window.selectedIndex);

                return Container(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.play_arrow : null,
                        color: Colors.yellow,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.yellow : Colors.white,
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Footer hint shown at the bottom of [HDMessageWindow]: a yellow
/// "계속하려면 누르십시오 ..." that fades in and out to signal that the
/// popup waits for a keypress. Matches the wording used by the console
/// dialogue's key-wait state.
class _BlinkingDismissHint extends StatefulWidget {
  const _BlinkingDismissHint();

  @override
  State<_BlinkingDismissHint> createState() => _BlinkingDismissHintState();
}

class _BlinkingDismissHintState extends State<_BlinkingDismissHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
        child: Text(
          "계속하려면 누르십시오 ...",
          style: TextStyle(
            color: Colors.yellow.shade600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}


/// The body of an [HDTextInputWindow]: a prompt and one text field.
///
/// It takes focus as soon as it appears. The global key handler steps
/// aside while this window is on top (`HDInputDispatcher._handleWindow`),
/// so Enter and Backspace reach the field.
class _TextInputBody extends StatefulWidget {
  const _TextInputBody({super.key, required this.window});

  final HDTextInputWindow window;

  @override
  State<_TextInputBody> createState() => _TextInputBodyState();
}

class _TextInputBodyState extends State<_TextInputBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.window.initial,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            border: Border.all(color: Colors.blue.shade400),
          ),
          width: double.infinity,
          child: Text(
            widget.window.prompt,
            style: const TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            maxLength: widget.window.maxLength,
            autofocus: true,
            cursorColor: Colors.yellow,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              isDense: true,
              counterStyle: TextStyle(color: Colors.white54, fontSize: 12),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.yellow),
              ),
            ),
            onSubmitted: widget.window.submit,
          ),
        ),
      ],
    );
  }
}


/// The body of an [HDMapOverviewWindow]: the whole map, one colour per
/// cell, with the party's cell blinking.
class _MapOverviewBody extends StatefulWidget {
  const _MapOverviewBody({required this.window});

  final HDMapOverviewWindow window;

  @override
  State<_MapOverviewBody> createState() => _MapOverviewBodyState();
}

class _MapOverviewBodyState extends State<_MapOverviewBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.window.title.isNotEmpty)
          Text(
            widget.window.title,
            style: const TextStyle(color: Colors.yellow, fontSize: 14),
          ),
        Expanded(
          child: AnimatedBuilder(
            animation: _blink,
            builder: (context, _) => CustomPaint(
              painter: _MapOverviewPainter(widget.window, _blink.value > 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapOverviewPainter extends CustomPainter {
  _MapOverviewPainter(this.window, this.partyLit);

  final HDMapOverviewWindow window;
  final bool partyLit;

  static const List<Color> _colors = [
    Color(0xFF000000), // 통로
    Color(0xFFE8E8E8), // 벽
    Color(0xFF55FF55), // 입구
    Color(0xFF55FFFF), // 푯말
    Color(0xFF2040E0), // 물
    Color(0xFF109090), // 늪
    Color(0xFFE02020), // 용암
    Color(0xFFFF80D0), // 사람
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / window.columns;
    final ch = size.height / window.rows;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < window.rows; y++) {
      for (var x = 0; x < window.columns; x++) {
        final kind = window.cells[y * window.columns + x];
        if (kind == HDOverviewCell.path) continue; // 바탕이 검다
        paint.color = _colors[kind < _colors.length ? kind : 0];
        canvas.drawRect(Rect.fromLTWH(x * cw, y * ch, cw + 0.5, ch + 0.5), paint);
      }
    }
    if (partyLit) {
      paint.color = const Color(0xFFFFFF40);
      final r = cw < 4 ? 2.0 : cw / 2;
      canvas.drawCircle(
        Offset((window.partyX + 0.5) * cw, (window.partyY + 0.5) * ch),
        r + 1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MapOverviewPainter old) =>
      old.partyLit != partyLit || old.window != window;
}

/// The body of an [HDSceneryWindow]: another map's cells, drawn with the
/// same sheets as the map view (`Lore_A5` ground, `Lore_B` decor/objects).
class _SceneryBody extends StatelessWidget {
  const _SceneryBody({required this.window});

  final HDSceneryWindow window;

  /// 지도와 같은 시트를 한 번만 읽어 둔다 — 다시 그릴 때마다 읽으면 깜빡인다.
  static Future<(ui.Image, ui.Image)>? _sheets;

  static Future<(ui.Image, ui.Image)> _loadSheets() async =>
      (await Flame.images.load('Lore_A5.png'), await Flame.images.load('Lore_B.png'));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(ui.Image, ui.Image)>(
      future: _sheets ??= _loadSheets(),
      builder: (context, snap) {
        final sheets = snap.data;
        if (sheets == null) return const SizedBox.shrink();
        return CustomPaint(painter: _SceneryPainter(window, sheets.$1, sheets.$2));
      },
    );
  }
}

class _SceneryPainter extends CustomPainter {
  _SceneryPainter(this.window, this.a5, this.b);

  final HDSceneryWindow window;
  final ui.Image a5;
  final ui.Image b;

  static const double _src = 48;

  void _draw(Canvas canvas, ui.Image sheet, int row, int col, Rect dst, Paint paint) {
    final src = Rect.fromLTWH(col * _src, row * _src, _src, _src);
    if (src.right > sheet.width || src.bottom > sheet.height) return;
    canvas.drawImageRect(sheet, src, dst, paint);
  }

  /// `Lore_B` 의 번호 → (행, 열). 왼쪽 반 128개, 오른쪽 반 128개 (지도와 같다).
  (int, int) _bCell(int id) => id < 128
      ? (id ~/ 8, id % 8)
      : ((id - 128) ~/ 8, 8 + (id - 128) % 8);

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / window.columns;
    final ch = size.height / window.rows;
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false;
    final a5Cols = (a5.width / _src).floor();
    for (var y = 0; y < window.rows; y++) {
      for (var x = 0; x < window.columns; x++) {
        final unit = window.units[y * window.columns + x];
        if (unit == null) continue; // 맵 밖 — 바탕이 검다
        final dst = Rect.fromLTWH(x * cw, y * ch, cw + 0.5, ch + 0.5);
        final id = window.tileOverrides[unit.ixTile] ?? unit.ixTile;
        if (a5Cols > 0) _draw(canvas, a5, id ~/ a5Cols, id % a5Cols, dst, paint);
        for (final bId in [unit.ixDecor, unit.ixObj0, unit.ixObj1]) {
          if (bId <= 0) continue;
          final (row, col) = _bCell(bId);
          _draw(canvas, b, row, col, dst, paint);
        }
      }
    }
    if (window.dark) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xB0000000));
    }
  }

  @override
  bool shouldRepaint(covariant _SceneryPainter old) => old.window != window;
}

/// [HDLetterWindow] — 검은 화면 한 장의 글. 흘러 올라오거나, 번개가 번쩍인다.
class _LetterBody extends StatefulWidget {
  const _LetterBody({required this.window});

  final HDLetterWindow window;

  @override
  State<_LetterBody> createState() => _LetterBodyState();
}

class _LetterBodyState extends State<_LetterBody> with TickerProviderStateMixin {
  static const double _side = 48;
  static const double _gap = 14;
  static const double _scrollSpeed = 36; // 초당 픽셀

  late final AnimationController _scroll = AnimationController(vsync: this);
  double _flash = 0;
  Timer? _lightning;
  final math.Random _rng = math.Random();

  // 1편 엔딩 — 오른쪽 가장자리를 걸어 내려가는 제작자 (LOREEND.PAS:182~210).
  // 그림은 24 → 21 → 24 → 20 을 되풀이하고, 0.2초마다 화면 높이의 2/350 씩 내려간다.
  static const List<int> _walkFrames = [24, 21, 24, 20];
  Timer? _walker;
  int _walkFrame = 0;
  double _walkY = 0; // 0~1 (화면 높이에 대한 비율)

  TextStyle get _style => TextStyle(
    fontFamily: 'DungGeunMo',
    fontSize: 18,
    height: 1.6,
    color: HDTextUtils.colorTable[widget.window.color] ?? Colors.white,
  );

  @override
  void initState() {
    super.initState();
    widget.window.addListener(_onWindow);
    _scroll.addStatusListener((s) {
      if (s == AnimationStatus.completed && !widget.window.settled) {
        widget.window.settled = true;
        setState(() {});
      }
    });
    if (widget.window.mode == HDLetterMode.lightning ||
        widget.window.mode == HDLetterMode.credits) {
      _scheduleLightning();
    }
  }

  void _onWindow() {
    // 첫 키 — 흘러 올라오는 중이면 끝으로 건너뛴다.
    if (widget.window.settled && _scroll.isAnimating) _scroll.value = 1;
    // 엔딩의 첫 키 — 번개가 멎고 제작자가 걷기 시작한다.
    if (widget.window.walking && _walker == null) {
      _lightning?.cancel();
      _flash = 0;
      _walker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() {
          _walkFrame = (_walkFrame + 1) % _walkFrames.length;
          _walkY += 2 / 350;
          if (_walkY > 1) _walkY = 0;
        });
      });
      setState(() {});
    }
  }

  /// 드물게 번개 — 1.5~5초 간격으로 두 번 번쩍인다.
  void _scheduleLightning() {
    _lightning = Timer(Duration(milliseconds: 1500 + _rng.nextInt(3500)), () async {
      for (final level in [0.85, 0.0, 0.6, 0.0]) {
        if (!mounted) return;
        setState(() => _flash = level);
        await Future<void>.delayed(const Duration(milliseconds: 70));
      }
      if (mounted) _scheduleLightning();
    });
  }

  @override
  void dispose() {
    widget.window.removeListener(_onWindow);
    _lightning?.cancel();
    _walker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// 줄은 낱말(어절) 사이에서만 바꾼다 — 한글은 글자마다 줄을 바꿀 수 있어서
  /// 「역사 / 에」처럼 낱말 가운데서 끊긴다. 한 낱말 안의 글자 사이에 보이지 않는
  /// 줄바꿈 금지 표시(U+2060)를 넣는다.
  static String _joinWords(String s) {
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      b.write(s[i]);
      if (i + 1 < s.length && s[i] != ' ' && s[i + 1] != ' ') b.write('\u2060');
    }
    return b.toString();
  }

  static InlineSpan _keepWords(InlineSpan span) => span is TextSpan
      ? TextSpan(
          text: span.text == null ? null : _joinWords(span.text!),
          style: span.style,
          children: span.children?.map(_keepWords).toList(),
        )
      : span;

  TextSpan _paragraph(String p) =>
      _keepWords(HDTextUtils.parseRichText(p, baseStyle: _style)) as TextSpan;

  /// 1부 인물 그림 한 칸의 크기 (원작 20픽셀).
  static const double _cell = 28;

  /// 그림이 붙은 편지는 줄이 열 개라 촘촘히 놓는다 — 원작도 그림 20픽셀에 줄 사이 10픽셀로
  /// 350픽셀 화면 안에 다 들어갔다 (LOREEND.PAS:136~153).
  bool get _dense => widget.window.pictures != null;
  double get _rowGap => _dense ? 9 : _gap;
  double get _top => _dense ? 16 : 40;

  List<List<int>>? _pictureOf(int i) {
    final pics = widget.window.pictures;
    return pics == null || i >= pics.length ? null : pics[i];
  }

  double get _pictureWidth {
    var cols = 0;
    for (final rows in widget.window.pictures ?? const <List<List<int>>?>[]) {
      for (final r in rows ?? const <List<int>>[]) {
        if (r.length > cols) cols = r.length;
      }
    }
    return cols * _cell;
  }

  double _contentHeight(double width) {
    var total = 0.0;
    for (final p in widget.window.paragraphs) {
      final tp = TextPainter(
        text: _paragraph(p),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      total += tp.height + _rowGap;
    }
    return total;
  }

  Widget _paragraphWidget(int i, String p) {
    final text = Text.rich(_paragraph(p));
    final pic = _pictureOf(i);
    if (widget.window.pictures == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _pictureWidth,
          // 한 칸짜리 그림은 세 칸 폭의 가운데에 둔다 — 원작도 x=40 (20·40·60 의 가운데)
          child: pic == null
              ? null
              : Center(child: _CharaPicture(rows: pic, cell: _cell)),
        ),
        const SizedBox(width: 16),
        Expanded(child: text),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth - _side * 2;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.window.paragraphs.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: _rowGap),
                child: _paragraphWidget(i, widget.window.paragraphs[i]),
              ),
          ],
        );
        Widget body;
        if (widget.window.mode == HDLetterMode.scroll) {
          final height = _contentHeight(width);
          final start = box.maxHeight;
          final end = height <= box.maxHeight - 40 ? 20.0 : box.maxHeight - 20 - height;
          if (_scroll.duration == null) {
            _scroll.duration = Duration(
              milliseconds: ((start - end) / _scrollSpeed * 1000).round(),
            );
            if (widget.window.settled) {
              _scroll.value = 1;
            } else {
              _scroll.forward();
            }
          }
          body = AnimatedBuilder(
            animation: _scroll,
            builder: (context, child) => Positioned(
              left: _side,
              width: width,
              top: start + (end - start) * _scroll.value,
              child: child!,
            ),
            child: content,
          );
        } else {
          body = Positioned(left: _side, width: width, top: _top, child: content);
        }
        // 자기 바탕(Material)을 가진다 — 어디에 놓여도 글자 모양이 같다.
        return Material(
          color: Colors.black,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              body,
              if (widget.window.walking)
                Positioned(
                  right: 12,
                  top: _walkY * (box.maxHeight - _cell),
                  child: _CharaPicture(
                    rows: [
                      [_walkFrames[_walkFrame]],
                    ],
                    cell: _cell,
                  ),
                ),
              if (widget.window.settled)
                const Positioned(right: 24, bottom: 12, child: _BlinkingDismissHint()),
              if (_flash > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: Colors.white.withValues(alpha: _flash)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 1부 인물 그림(`lore1_chara.png`, 원작 CHARA.FNT 의 0~27번)을 줄마다 늘어놓는다.
class _CharaPicture extends StatelessWidget {
  const _CharaPicture({required this.rows, required this.cell});

  final List<List<int>> rows;
  final double cell;

  /// 한 번만 읽어 둔다.
  static Future<ui.Image>? _sheet;

  @override
  Widget build(BuildContext context) {
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return SizedBox(
      width: cols * cell,
      height: rows.length * cell,
      child: FutureBuilder<ui.Image>(
        future: _sheet ??= Flame.images.load('lore1_chara.png'),
        builder: (context, snap) {
          final sheet = snap.data;
          if (sheet == null) return const SizedBox.shrink();
          return CustomPaint(painter: _CharaPainter(sheet, rows, cell));
        },
      ),
    );
  }
}

class _CharaPainter extends CustomPainter {
  _CharaPainter(this.sheet, this.rows, this.cell);

  final ui.Image sheet;
  final List<List<int>> rows;
  final double cell;

  static const double _src = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final n = rows[r][c];
        if (n < 0 || (n + 1) * _src > sheet.width) continue;
        canvas.drawImageRect(
          sheet,
          Rect.fromLTWH(n * _src, 0, _src, _src),
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CharaPainter old) =>
      old.sheet != sheet || old.rows != rows;
}

/// 지도 칸을 덮는 이름 목록 (`UiHost.showNameList`) — 1부의 적 목록처럼 검은 바탕에
/// 이름을 한 줄씩 쓴다. 목록이 비면 아무것도 그리지 않는다.
class HDNameListOverlay extends StatelessWidget {
  const HDNameListOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<({String text, int color})>>(
      valueListenable: HDFlutterUiHost().nameList,
      builder: (context, lines, _) {
        if (lines.isEmpty) return const SizedBox.shrink();
        // 자기 바탕(Material)을 가진다 — 어디에 놓여도 글자에 밑줄이 붙지 않는다.
        return Material(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 28, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      l.text,
                      style: TextStyle(
                        fontFamily: 'DungGeunMo',
                        fontSize: 18,
                        color: HDTextUtils.colorTable[l.color.clamp(0, 15).toRadixString(16).toUpperCase()] ??
                            Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
