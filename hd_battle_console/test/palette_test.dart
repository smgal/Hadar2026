import 'package:hd_battle_console/palette.dart';
import 'package:test/test.dart';

/// 색은 우리가 고른 것이 아니라 **원작에서 캐낸 것**이다.
/// 이 테스트가 그 출처를 못 박는다 — 표가 흔들리면 여기서 걸린다.
void main() {
  group('16색 표 — hd_base_gfx.cpp:19-25 COLOR_TABLE', () {
    test('16칸이고 값이 원작 그대로다', () {
      expect(HDPalette.argb.length, 16);
      expect(HDPalette.ansi.length, 16);
      expect(HDPalette.argb.first, 0xFF000000);
      expect(HDPalette.argb[7], 0xFF808080);
      expect(HDPalette.argb[8], 0xFF404040);
      expect(HDPalette.argb.last, 0xFFFFFFFF);
    });

    test('순서가 DOS 색 번호와 같아서 ANSI 16색과 1:1 로 맞는다', () {
      // 0~7 은 기본 8색, 8~15 는 밝은 8색. 어긋나면 색이 통째로 밀린다.
      expect(HDPalette.ansi.sublist(0, 8), [30, 34, 32, 36, 31, 35, 33, 37]);
      expect(HDPalette.ansi.sublist(8), [90, 94, 92, 96, 91, 95, 93, 97]);
    });

    test('밝은 색은 어두운 색의 짝이다', () {
      // 1 파랑 ↔ 9 밝은 파랑처럼 8칸 차이가 같은 계열이어야 한다.
      for (var dark = 1; dark <= 6; dark++) {
        expect(
          HDPalette.ansi[dark] + 60,
          HDPalette.ansi[dark + 8],
          reason: '$dark 번',
        );
      }
    });

    test('색 번호와 `@` 뒤 글자가 서로 왕복한다', () {
      for (var i = 0; i < HDPalette.size; i++) {
        final code = HDPalette.codeOf(i);
        expect(code.length, 1);
        expect(HDPalette.indexOfCode(code.codeUnitAt(0)), i, reason: '$i');
      }
      expect(HDPalette.codeOf(7), '7');
      expect(HDPalette.codeOf(11), 'B'); // 자산이 실제로 쓰는 `@B`
      expect(HDPalette.codeOf(15), 'F'); // hd_res_string.cpp:237 의 `@F`
    });

    test('소문자는 원작의 버그를 그대로 물려받아 범위 밖이 된다', () {
      // `index_char - 'A' + 10` 이라 'a' 가 42 가 된다. 고치지 않는다 —
      // 값이 아니라 입력 해석이고, 자산이 소문자를 쓰지 않는다.
      expect(HDPalette.indexOfCode('a'.codeUnitAt(0)), 42);
      expect(HDPalette.isValid(42), isFalse);
    });
  });

  group('`@` 표기 — drawFormatedText 와 같은 분기', () {
    const ansi = HDAnsi();

    test('표기를 떼면 원래 문장만 남는다', () {
      expect(HDAnsi.strip('@7이쪽 벽면이 무기고를 향해 있다.'), '이쪽 벽면이 무기고를 향해 있다.');
      expect(HDAnsi.strip('@B[황금 방패 +1]@@'), '[황금 방패 +1]');
      expect(HDAnsi.strip('슴갈은 @D30@@만큼의 피해를 입었다'), '슴갈은 30만큼의 피해를 입었다');
    });

    test('색을 끈 renderer 는 표기만 뗀다', () {
      expect(HDAnsi.plain.render('@C경고@@'), '경고');
    });

    test('줄 색과 글자 색이 섞인다 — hd_class_pc_enemy.cpp:346 의 모양', () {
      expect(
        ansi.render('슴갈은 @D30@@만큼의 피해를 입었다', defaultColor: HDColor.magenta),
        '\x1b[35m슴갈은 \x1b[95m30\x1b[35m만큼의 피해를 입었다\x1b[0m',
      );
    });

    test('`@@` 는 기본색으로 되돌린다', () {
      expect(
        ansi.render('@B가@@나', defaultColor: HDColor.lightGray),
        '\x1b[96m가\x1b[37m나\x1b[0m',
      );
    });

    test('범위 밖 번호는 기본색으로 떨어진다 — Map002.cm2 의 `@G`', () {
      expect(
        ansi.render('@G가', defaultColor: HDColor.lightGray),
        '\x1b[37m가\x1b[0m',
      );
    });

    test('줄 끝의 외톨이 `@` 는 버린다', () {
      expect(HDAnsi.strip('끝에 붙은 골뱅이@'), '끝에 붙은 골뱅이');
    });

    test('빈 문자열에는 아무 코드도 붙지 않는다', () {
      expect(ansi.render(''), '');
    });

    test('paint 는 자산이 쓰던 표기를 그대로 만든다', () {
      expect(paint(HDColor.lightCyan, '[황금 방패 +1]'), '@B[황금 방패 +1]@@');
    });
  });

  group('적 이름 색 — hd_class_window_battle.h:27-47', () {
    int color(int hp, {int unconscious = 0, int dead = 0}) =>
        enemyNameColor(hp: hp, unconscious: unconscious, dead: dead);

    test('비율이 아니라 절대 HP 로 나눈다', () {
      expect(color(301), HDColor.lightGreen);
      expect(color(300), HDColor.green);
      expect(color(201), HDColor.green);
      expect(color(200), HDColor.yellow);
      expect(color(101), HDColor.yellow);
      expect(color(100), HDColor.brown);
      expect(color(51), HDColor.brown);
      expect(color(50), HDColor.red);
      expect(color(21), HDColor.red);
      expect(color(20), HDColor.lightRed);
      expect(color(1), HDColor.lightRed);
      expect(color(0), HDColor.darkGray);
    });

    test('의식불명과 사망이 HP 판정을 덮어쓴다', () {
      expect(color(500, unconscious: 1), HDColor.darkGray);
      expect(color(500, dead: 1), HDColor.black);
      // 둘 다면 사망이 이긴다 — 원작의 대입 순서 그대로.
      expect(color(500, unconscious: 1, dead: 1), HDColor.black);
    });

    test('규칙은 죽은 적에 0번(검정)을 낸다', () {
      // 원작은 배경이 항상 검정이라 이것이 "목록에서 지운다" 는 뜻이었다.
      // 규칙은 그대로 두고, 터미널 사정은 renderer 가 감당한다.
      expect(color(10, dead: 1), HDColor.black);
    });
  });

  group('파티 이름 색 — hd_class_pc_player.cpp:238-256', () {
    int color({
      int hp = 100,
      int poison = 0,
      int unconscious = 0,
      int dead = 0,
    }) => conditionColor(
      hp: hp,
      poison: poison,
      unconscious: unconscious,
      dead: dead,
    );

    test('네 상태가 각각 다른 색이다', () {
      expect(color(), HDColor.white);
      expect(color(poison: 3), HDColor.lightMagenta);
      expect(color(unconscious: 2), HDColor.lightGray);
      expect(color(dead: 1), HDColor.darkGray);
    });

    test('나쁜 상태가 먼저다', () {
      expect(color(poison: 3, unconscious: 1), HDColor.lightGray);
      expect(color(poison: 3, unconscious: 1, dead: 1), HDColor.darkGray);
    });

    test('HP 0 은 플래그가 없어도 의식불명으로 읽는다', () {
      // `checkCondition` 이 hp<=0 을 unconscious 로 올리는 것과 같은 결과.
      expect(color(hp: 0), HDColor.lightGray);
    });
  });

  group('검정 바꿔치기는 터미널 사정이다', () {
    test('기본값은 0번을 8번으로 낸다', () {
      expect(
        const HDAnsi().render('죽은 적', defaultColor: HDColor.black),
        '\x1b[90m죽은 적\x1b[0m',
      );
    });

    test('끄면 진짜 검정으로 낸다', () {
      expect(
        const HDAnsi(
          substituteBlack: false,
        ).render('죽은 적', defaultColor: HDColor.black),
        '\x1b[30m죽은 적\x1b[0m',
      );
    });
  });
}
