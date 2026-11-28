@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// 독립성은 약속이 아니라 시험이다.
///
/// 주석은 뺀다 — 규칙 옆에 그 규칙이 옮긴 기획서의 낱말을 적어 두는 것이
/// 이식을 검토할 수 있게 하는 것이기 때문이다.
String code(File file) => file
    .readAsLinesSync()
    .map((line) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('///') || trimmed.startsWith('//')) return '';
      final marker = line.indexOf('//');
      return marker == -1 ? line : line.substring(0, marker);
    })
    .join('\n');

void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('there are sources to check', () {
    expect(sources.length, greaterThan(15));
  });

  test('nothing imports Flutter', () {
    for (final file in sources) {
      expect(
        code(file).contains('package:flutter'),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('nothing imports another package at all', () {
    // 이 레포의 패키지는 물론이고, 바깥 패키지도 쓰지 않는다. 허용되는
    // 것은 자체 라이브러리와 순수 Dart 표준 라이브러리뿐이다.
    final import = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    for (final file in sources) {
      for (final m in import.allMatches(code(file))) {
        final target = m.group(1)!;
        final ok =
            target == 'dart:math' ||
            target == 'dart:collection' ||
            target.startsWith('package:lore_world/') ||
            !target.contains(':');
        expect(ok, isTrue, reason: '${file.path} imports $target');
      }
    }
  });

  test('the pubspec has no runtime dependencies', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'^dependencies:', multiLine: true).hasMatch(pubspec),
      isFalse,
    );
  });

  test('nothing reaches for the machine', () {
    for (final file in sources) {
      final text = code(file);
      for (final forbidden in const [
        'dart:io',
        'dart:isolate',
        'dart:ffi',
        'dart:html',
        'DateTime.now',
        'Stopwatch',
        'print(',
      ]) {
        expect(
          text.contains(forbidden),
          isFalse,
          reason: '${file.path} $forbidden',
        );
      }
    }
  });

  test('no Random is constructed — every one is injected', () {
    // 시드 없는 Random() 뿐 아니라 Random(n) 도 만들지 않는다. 난수는
    // 부르는 쪽이 건네준다.
    final constructed = RegExp(r'\bRandom(?:\.secure)?\s*\(');
    for (final file in sources) {
      expect(constructed.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('no display text in code', () {
    final hangul = RegExp(r'[ᄀ-ᇿ㄰-㆏가-힣]');
    for (final file in sources) {
      expect(hangul.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('no emoji in code', () {
    final emoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}]',
      unicode: true,
    );
    for (final file in sources) {
      expect(emoji.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('nothing derived is stored on a member', () {
    // 원작은 무기 공격력·방어력을 저장했고, 장비를 바꿔도 다시 계산하지
    // 않아 썩었다(부록 A #1). 이 이름들이 필드로 돌아오면 같은 일이 난다.
    final member = code(File('lib/src/domain/member.dart'));
    for (final name in const [
      'maxHp',
      'maxMp',
      'ac',
      'weaponPower',
      'shieldPower',
      'armourPower',
      'weaponKind',
      'condition',
      'canAct',
      'attackMode',
    ]) {
      // 필드 선언: `타입 이름;` 또는 `타입 이름 =`. getter(`get 이름`)는 된다.
      final field = RegExp(
        '^\\s*(?:final\\s+)?[A-Za-z<>?]+\\s+$name\\s*[;=]',
        multiLine: true,
      );
      expect(field.hasMatch(member), isFalse, reason: name);
      expect(
        member.contains('get $name'),
        isTrue,
        reason: '$name should be a getter',
      );
      expect(
        member.contains("'$name'"),
        isFalse,
        reason: '$name must not be saved',
      );
    }
  });

  test('commands do not throw', () {
    // 거절은 값으로 돌아온다. `throw` 가 규칙 안에 생기면 그 약속이 깨진다.
    for (final file in sources) {
      expect(
        RegExp(r'\bthrow\b').hasMatch(code(file)),
        isFalse,
        reason: file.path,
      );
    }
  });
}
