@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// The independence claim, asserted rather than promised.
///
/// The battle package keeps the same guard and it is what let that
/// rewrite land without dragging the app along. Four things stay true
/// here no matter how the rules grow.
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
    expect(sources.length, greaterThan(10));
  });

  test('nothing imports Flutter', () {
    for (final file in sources) {
      expect(code(file).contains('package:flutter'), isFalse, reason: file.path);
    }
  });

  test('nothing imports another package from this repository', () {
    // Independence is the point: the app, the battle model and the
    // scripting language all adapt to this package, never the reverse.
    for (final file in sources) {
      final text = code(file);
      for (final forbidden in const [
        'package:hd_battle',
        'package:hd_battle_text',
        'package:cm2_script',
        'package:hadar2026_app',
        'package:hd_world_lab',
      ]) {
        expect(text.contains(forbidden), isFalse, reason: '${file.path} $forbidden');
      }
    }
  });

  test('nothing reaches for the machine', () {
    // No files, no clock, no sockets, no console. A model that cannot
    // touch the outside world can be driven from anywhere.
    for (final file in sources) {
      final text = code(file);
      for (final forbidden in const [
        "dart:io",
        "dart:isolate",
        "dart:ffi",
        "DateTime.now",
        "print(",
      ]) {
        expect(text.contains(forbidden), isFalse, reason: '${file.path} $forbidden');
      }
    }
  });

  test('no unseeded Random is constructed', () {
    final bare = RegExp(r'Random\(\s*\)');
    for (final file in sources) {
      expect(bare.hasMatch(code(file)), isFalse, reason: file.path);
    }
  });

  test('no display text in code', () {
    // Sentences and names belong to whatever renders them. Comments are
    // out of scope on purpose: naming a weapon next to the rule that
    // implements it is what makes the port auditable.
    final hangul = RegExp(r'[가-힣]');
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
    // The predecessor kept four party-ability counters and three of them
    // rotted. If any of these names appears as a field again, the same
    // failure is back.
    final member = File('lib/src/domain/member.dart').readAsStringSync();
    for (final forbidden in const [
      'weaponKind ',
      'defence ',
      'walkOnWater',
      'walkOnSwamp',
      'levitation',
      'magicTorch',
    ]) {
      expect(member.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}
