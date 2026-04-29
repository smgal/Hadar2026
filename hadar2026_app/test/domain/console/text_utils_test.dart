import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/utils/hd_text_utils.dart';

/// Re-serializes a tagged string through the wrap → spanToRaw round trip
/// and asserts the result preserves the originally-tagged segments.
///
/// Calls [splitToLines] with a width large enough that no wrap actually
/// happens, isolating the *color tag* round-trip from the wrap algorithm.
void main() {
  // Color-less base style — required for spanToRaw to distinguish
  // "no color" from the default text color.
  const baseStyle = TextStyle(fontSize: 16);

  group('HDTextUtils round-trip (splitToLines + spanToRaw)', () {
    test('plain ASCII text round-trips identically', () {
      final lines = HDTextUtils.splitToLines(
        'Hello world',
        10000,
        baseStyle,
      );
      expect(lines, hasLength(1));
      expect(HDTextUtils.spanToRaw(lines.first), 'Hello world');
    });

    test('a single colored segment is preserved with @X..@@', () {
      final lines = HDTextUtils.splitToLines(
        '@CRed text@@',
        10000,
        baseStyle,
      );
      expect(lines, hasLength(1));
      expect(HDTextUtils.spanToRaw(lines.first), '@CRed text@@');
    });

    test('mixed colored and uncolored segments preserve boundaries', () {
      const original = 'plain @AGreen@@ middle @CRed@@ end';
      final lines = HDTextUtils.splitToLines(original, 10000, baseStyle);
      expect(lines, hasLength(1));
      expect(HDTextUtils.spanToRaw(lines.first), original);
    });

    test('empty string yields no lines', () {
      final lines = HDTextUtils.splitToLines('', 10000, baseStyle);
      expect(lines, isEmpty);
    });
  });

  group('HDTextUtils.parseRichText', () {
    test('parses tagged text into spans matching the color table', () {
      final span = HDTextUtils.parseRichText('@CRed@@', baseStyle: baseStyle);
      // Expect at least one child colored red.
      final reds = (span.children ?? const <InlineSpan>[])
          .whereType<TextSpan>()
          .where((s) => s.style?.color == HDTextUtils.colorTable['C']);
      expect(reds, isNotEmpty);
    });

    test('plain text becomes a single span with no color override', () {
      final span = HDTextUtils.parseRichText(
        'plain',
        baseStyle: baseStyle,
      );
      final children = span.children ?? const <InlineSpan>[];
      expect(children, hasLength(1));
      expect(children.first, isA<TextSpan>());
      expect((children.first as TextSpan).text, 'plain');
    });
  });
}
