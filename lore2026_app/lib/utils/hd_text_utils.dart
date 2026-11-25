import 'package:flutter/material.dart';

class HDTextUtils {
  static const Map<String, Color> colorTable = {
    '0': Color(0xFF000000), // Black
    '1': Color(0xFF000080), // Dark Blue
    '2': Color(0xFF008000), // Dark Green
    '3': Color(0xFF008080), // Dark Cyan
    '4': Color(0xFF800000), // Dark Red
    '5': Color(0xFF800080), // Dark Magenta
    '6': Color(0xFF808000), // Dark Yellow
    '7': Color(0xFF808080), // Gray
    '8': Color(0xFF404040), // Dark Gray
    '9': Color(0xFF0000FF), // Blue
    'A': Color(0xFF00FF00), // Green
    'B': Color(0xFF00FFFF), // Cyan
    'C': Color(0xFFFF0000), // Red
    'D': Color(0xFFFF00FF), // Magenta
    'E': Color(0xFFFFFF00), // Yellow
    'F': Color(0xFFFFFFFF), // White
    'G': Color(0xFFFFA500), // Amber
  };

  /// Parses a string with @X...@@ tags into a list of TextSpans.
  /// If [baseStyle] is provided, it will be used as the base for all spans.
  static TextSpan parseRichText(String text, {TextStyle? baseStyle}) {
    List<TextSpan> children = [];
    Color? currentColor;

    int i = 0;
    String buffer = "";

    void flushBuffer() {
      if (buffer.isNotEmpty) {
        children.add(
          TextSpan(
            text: buffer,
            style: (currentColor != null)
                ? (baseStyle ?? const TextStyle()).copyWith(color: currentColor)
                : baseStyle,
          ),
        );
        buffer = "";
      }
    }

    while (i < text.length) {
      if (text[i] == '@' && i + 1 < text.length) {
        String next = text[i + 1];
        if (next == '@') {
          // Revert color
          flushBuffer();
          currentColor = null;
          i += 2;
        } else if (colorTable.containsKey(next.toUpperCase())) {
          // Set color
          flushBuffer();
          currentColor = colorTable[next.toUpperCase()];
          i += 2;
        } else {
          // Just an '@' literal
          buffer += text[i];
          i++;
        }
      } else {
        buffer += text[i];
        i++;
      }
    }
    flushBuffer();

    return TextSpan(children: children);
  }

  /// Splits a string with @ tags into lines, preserving the color state across lines.
  static List<TextSpan> splitToLines(
    String text,
    double maxWidth,
    TextStyle baseStyle,
  ) {
    // 1. First, parse into chunks to handle word wrapping correctly
    // or we can just split the string into words and maintain the color state.

    List<TextSpan> resultLines = [];
    final words = text.split(' ');

    Color? currentActiveColor;
    List<TextSpan> currentLineChildren = [];
    double currentLineWidth = 0;

    for (int wordIdx = 0; wordIdx < words.length; wordIdx++) {
      String word = words[wordIdx];
      if (wordIdx > 0 && word.isNotEmpty) word = " $word";

      // We need to parse this word to see if it changes color
      // A word can contain multiple color tags: "@AHello@BWorld@@"

      List<_TextChunk> chunks = _parseToChunks(word, currentActiveColor);

      // Calculate width of this word (sum of chunk widths)
      double wordWidth = 0;
      for (var chunk in chunks) {
        final tp = TextPainter(
          text: TextSpan(
            text: chunk.text,
            style: baseStyle.copyWith(color: chunk.color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        wordWidth += tp.width;
      }

      if (currentLineWidth + wordWidth > maxWidth &&
          currentLineChildren.isNotEmpty) {
        // Line break
        resultLines.add(TextSpan(children: List.from(currentLineChildren)));
        currentLineChildren.clear();
        currentLineWidth = 0;

        // When we start a new line, we should remove the leading space if it was added
        if (word.startsWith(" ")) {
          word = word.substring(1);
          // Re-parse and re-calc width without the leading space
          chunks = _parseToChunks(word, currentActiveColor);
          wordWidth = 0;
          for (var chunk in chunks) {
            final tp = TextPainter(
              text: TextSpan(
                text: chunk.text,
                style: baseStyle.copyWith(color: chunk.color),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            wordWidth += tp.width;
          }
        }
      }

      for (var chunk in chunks) {
        currentLineChildren.add(
          TextSpan(
            text: chunk.text,
            style: baseStyle.copyWith(color: chunk.color),
          ),
        );
        currentActiveColor = chunk.color;
      }
      currentLineWidth += wordWidth;
    }

    if (currentLineChildren.isNotEmpty) {
      resultLines.add(TextSpan(children: currentLineChildren));
    }

    return resultLines;
  }

  /// Reverse lookup: ARGB32 color value → tag character.
  static final Map<int, String> _colorReverseTable = {
    for (final entry in colorTable.entries)
      // ignore: deprecated_member_use
      entry.value.value: entry.key,
  };

  /// Serializes a wrapped [TextSpan] line (as produced by [splitToLines])
  /// back to a raw string with `@X..@@` color tags. Pair with
  /// [splitToLines] called using a base style without a `color`, so that a
  /// child's `style.color == null` reliably means "no color tag".
  static String spanToRaw(TextSpan line) {
    final sb = StringBuffer();
    String? lastTag;
    for (final child in line.children ?? const <InlineSpan>[]) {
      if (child is! TextSpan) continue;
      final color = child.style?.color;
      // ignore: deprecated_member_use
      final String? tag = color == null
          ? null
          // ignore: deprecated_member_use
          : _colorReverseTable[color.value];
      if (tag != lastTag) {
        sb.write(tag == null ? '@@' : '@$tag');
        lastTag = tag;
      }
      sb.write(child.text ?? '');
    }
    return sb.toString();
  }

  /// Convenience: wrap [text] to raw lines (raw `@X..@@`-tagged strings),
  /// suitable for storage in a domain-layer console log without bringing
  /// `package:flutter/material.dart` into the domain.
  static List<String> splitToRawLines(
    String text,
    double maxWidth,
    TextStyle baseStyle,
  ) {
    return splitToLines(text, maxWidth, baseStyle).map(spanToRaw).toList();
  }

  static List<_TextChunk> _parseToChunks(String text, Color? startColor) {
    List<_TextChunk> chunks = [];
    Color? currentColor = startColor;
    int i = 0;
    String buffer = "";

    void flush() {
      if (buffer.isNotEmpty) {
        chunks.add(_TextChunk(buffer, currentColor));
        buffer = "";
      }
    }

    while (i < text.length) {
      if (text[i] == '@' && i + 1 < text.length) {
        String next = text[i + 1];
        if (next == '@') {
          flush();
          currentColor = null;
          i += 2;
        } else if (colorTable.containsKey(next.toUpperCase())) {
          flush();
          currentColor = colorTable[next.toUpperCase()];
          i += 2;
        } else {
          buffer += text[i];
          i++;
        }
      } else {
        buffer += text[i];
        i++;
      }
    }
    flush();
    // If the trailing color state differs from the last visible chunk's
    // color, append a zero-width sentinel so callers can still observe
    // the change. Without this, a word ending in `@@` would leave
    // `splitToLines` thinking the last colored chunk is still active and
    // bleed that color into the next word. We compare to the last chunk
    // (or to startColor when there is no chunk) — that way pure plain
    // input and empty input produce no sentinel.
    final Color? trailingObservedColor = chunks.isNotEmpty
        ? chunks.last.color
        : startColor;
    if (currentColor != trailingObservedColor) {
      chunks.add(_TextChunk('', currentColor));
    }
    return chunks;
  }
}

class _TextChunk {
  final String text;
  final Color? color;
  _TextChunk(this.text, this.color);
}
