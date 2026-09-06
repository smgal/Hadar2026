/// 원작의 16색 팔레트와 `@` 색 표기, 그리고 그것을 터미널 색으로 옮기는 renderer.
///
/// 색은 이 콘솔이 지어낸 것이 아니라 **원작에 이미 있던 규격**이다.
/// 근거는 세 곳이다.
///
/// | 무엇 | 원작 위치 |
/// |---|---|
/// | 16색 표 | `REF_hadar/src/hadar/hd_base_gfx.cpp:19-25` `COLOR_TABLE` |
/// | 줄 단위 색 | `hd_base_extern.cpp:241` `writeConsole(색번호, 인자수, ...)` |
/// | 글자 단위 색 | `hd_base_gfx.cpp:107-158` `drawFormatedText` 의 `@` 처리 |
///
/// 색 번호는 게임 데이터에도 들어 있다 — `hadar2026_app/assets/*.cm2` 의
/// `Talk("@7...")` · `Talk("@B[황금 방패 +1]@@")` 가 같은 표를 쓴다.
library;

export 'package:hd_battle_text/hd_battle_text.dart'
    show conditionColor, enemyNameColor;

/// 팔레트 색 번호에 이름을 붙인 것.
///
/// 표의 순서가 DOS 시절 색 번호(검정·파랑·초록·청록·빨강·자홍·갈색·밝은회색,
/// 그리고 밝은 8색)와 같다. 그래서 ANSI 16색과 **번호 하나 어긋남 없이**
/// 맞아떨어지고, 원작의 색을 터미널에 그대로 옮길 수 있다.
abstract final class HDColor {
  static const int black = 0;
  static const int blue = 1;
  static const int green = 2;
  static const int cyan = 3;
  static const int red = 4;
  static const int magenta = 5;
  static const int brown = 6;
  static const int lightGray = 7;
  static const int darkGray = 8;
  static const int lightBlue = 9;
  static const int lightGreen = 10;
  static const int lightCyan = 11;
  static const int lightRed = 12;
  static const int lightMagenta = 13;
  static const int yellow = 14;
  static const int white = 15;
}

/// 원작 팔레트 그 자체.
abstract final class HDPalette {
  /// `hd_base_gfx.cpp:19-25` 의 `COLOR_TABLE` 을 그대로 옮긴 것.
  ///
  /// 값은 0xAARRGGBB. 터미널에서는 쓰지 않지만, 이 표가 정본이라는 것을
  /// 남겨 두려고 같이 둔다 — B4 의 Flutter view 가 이 값을 쓴다.
  static const List<int> argb = [
    0xFF000000, 0xFF000080, 0xFF008000, 0xFF008080, //
    0xFF800000, 0xFF800080, 0xFF808000, 0xFF808080, //
    0xFF404040, 0xFF0000FF, 0xFF00FF00, 0xFF00FFFF, //
    0xFFFF0000, 0xFFFF00FF, 0xFFFFFF00, 0xFFFFFFFF, //
  ];

  /// 같은 번호의 ANSI SGR 전경색 코드.
  ///
  /// 0~7 은 기본 8색(30~37), 8~15 는 밝은 8색(90~97)이다.
  static const List<int> ansi = [
    30, 34, 32, 36, 31, 35, 33, 37, //
    90, 94, 92, 96, 91, 95, 93, 97, //
  ];

  static const int size = 16;

  static bool isValid(int index) => index >= 0 && index < size;

  /// 색 번호를 `@` 뒤에 오는 글자로.
  ///
  /// 0~9 는 `'0'`~`'9'`, 10 이상은 `'A'`~. 원작 파서와 같은 규칙이다.
  static String codeOf(int index) {
    if (!isValid(index)) {
      throw ArgumentError.value(index, 'index', '팔레트 범위 밖이다 (0~15)');
    }
    return index < 10
        ? String.fromCharCode(0x30 + index)
        : String.fromCharCode(0x41 + index - 10);
  }

  /// `@` 뒤 글자를 색 번호로. 색 번호가 아니면 -1.
  ///
  /// `drawFormatedText` 의 분기를 그대로 옮겼다. **소문자 분기는 원작의
  /// 버그다** — `index_char - 'A' + 10` 이라 `'a'` 가 42 가 되고, 표 범위를
  /// 벗어나 기본색으로 떨어진다. 값을 의심하고 고치는 자리가 아니라
  /// 입력 해석이라 그대로 두었다. 그래서 `@a` 는 실질적으로 `@@` 와 같다.
  static int indexOfCode(int charCode) {
    if (charCode >= 0x30 && charCode <= 0x39) return charCode - 0x30;
    if (charCode >= 0x41 && charCode <= 0x5A) return charCode - 0x41 + 10;
    if (charCode >= 0x61 && charCode <= 0x7A) return charCode - 0x41 + 10;
    return -1;
  }
}

/// 색 번호를 붙인 문자열 조각을 만든다.
///
/// 원작 데이터가 쓰던 표기 그대로다 — `paint(HDColor.lightCyan, '[열쇠 +1]')`
/// 이 `'@B[열쇠 +1]@@'` 를 낸다.
String paint(int index, Object text) => '@${HDPalette.codeOf(index)}$text@@';

/// `@` 표기가 붙은 문자열을 실제 출력으로 바꾼다.
///
/// [enabled] 가 거짓이면 표기만 떼고 맨 문자열을 낸다. 파이프로 넘길 때,
/// 테스트에서 문장만 비교할 때 그 경로를 쓴다.
class HDAnsi {
  const HDAnsi({this.enabled = true, this.substituteBlack = true});

  /// 색을 끈 renderer. 표기를 떼기만 한다.
  static const HDAnsi plain = HDAnsi(enabled: false);

  final bool enabled;

  /// 0번(검정)을 8번(진한 회색)으로 바꿔서 낼지.
  ///
  /// 원작은 **죽은 적의 이름을 검정으로 그려서 지웠다**
  /// (`hd_class_window_battle.h:47`) — 배경이 항상 검정이었기 때문에
  /// 그것이 "목록에서 사라진다" 는 뜻이었다. 터미널은 배경색을 고를 수
  /// 없으므로 그대로 옮기면 글자가 사라지거나 남거나 둘 중 하나가 된다.
  /// 규칙(`enemyNameColor`)은 원작대로 0을 내고, **바꿔치기는 여기서만**
  /// 한다 — 규격이 아니라 터미널 사정이라서 그렇다.
  final bool substituteBlack;

  static const String _reset = '\x1b[0m';

  /// 표기를 떼고 맨 문자열만.
  static String strip(String markup) {
    final out = StringBuffer();
    _walk(markup, (text, _) => out.write(text));
    return out.toString();
  }

  /// 표기를 ANSI 로. [defaultColor] 는 `@@` 가 돌아갈 색이자 시작 색이다.
  String render(String markup, {int defaultColor = HDColor.white}) {
    if (!enabled) return strip(markup);

    final out = StringBuffer();
    var painted = false;
    _walk(markup, (text, index) {
      out.write(_sgr(index < 0 ? defaultColor : index));
      out.write(text);
      painted = true;
    });
    if (painted) out.write(_reset);
    return out.toString();
  }

  String _sgr(int index) {
    var i = HDPalette.isValid(index) ? index : HDColor.white;
    if (substituteBlack && i == HDColor.black) i = HDColor.darkGray;
    return '\x1b[${HDPalette.ansi[i]}m';
  }

  /// `@` 표기를 훑으며 (조각, 색 번호) 를 [onSegment] 로 넘긴다.
  ///
  /// 빈 조각은 넘기지 않는다. 색 번호 -1 은 "기본색" 이다.
  /// 분기는 `drawFormatedText` 와 같다.
  /// - `@0`~`@9`, `@A`~`@Z` : 그 번호로
  /// - `@@` : 기본색으로 되돌림
  /// - 범위 밖 번호(`@G` 이상) : 기본색으로 떨어짐 — 원작과 같다
  /// - 줄 끝의 외톨이 `@` : 아무 일도 하지 않고 버린다
  static void _walk(
    String markup,
    void Function(String text, int index) onSegment,
  ) {
    var current = -1;
    var start = 0;
    var i = 0;

    void flush(int end) {
      if (end > start) onSegment(markup.substring(start, end), current);
    }

    while (i < markup.length) {
      if (markup.codeUnitAt(i) != 0x40) {
        i++;
        continue;
      }
      flush(i);
      i++;
      if (i >= markup.length) {
        start = i; // 줄 끝의 외톨이 '@' 는 버린다
        break;
      }
      final code = markup.codeUnitAt(i);
      if (code == 0x40) {
        current = -1;
      } else {
        final index = HDPalette.indexOfCode(code);
        current = HDPalette.isValid(index) ? index : -1;
      }
      i++;
      start = i;
    }
    flush(markup.length);
  }
}

// --- 원작이 정해 둔 두 가지 색 규칙 -------------------------------------

// `enemyNameColor` · `conditionColor` 는 `hd_battle_text` 로 옮겼다 —
// **콘솔과 Flutter view 가 같은 색을 써야** 하기 때문이다. 여기서 다시
// export 해 두어 부르는 쪽은 그대로다.
