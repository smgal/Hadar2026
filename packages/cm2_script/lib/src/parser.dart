import 'ast.dart';

/// Parses script text into a list of [ScriptStatement]s (commands and if/else blocks).
List<ScriptStatement> parseScript(String content) {
  final lines = content.split('\n');
  final statements = <ScriptStatement>[];
  _parseBlock(lines, 0, 0, statements);
  return statements;
}

int _parseBlock(
  List<String> lines,
  int currentLineIndex,
  int parentIndent,
  List<ScriptStatement> targetList,
) {
  int i = currentLineIndex;
  while (i < lines.length) {
    String line = lines[i];
    if (line.trim().isEmpty || line.trim().startsWith('#')) {
      i++;
      continue;
    }

    int indent = _countIndent(line);
    if (indent < parentIndent) return i;

    String trimmed = stripComment(line).trim();

    if (trimmed.startsWith("if ") ||
        (trimmed.startsWith("if") && trimmed.contains("("))) {
      final ifLine = i;
      var elseLine = -1;
      int startParen = trimmed.indexOf('(');
      int endParen = trimmed.lastIndexOf(')');
      // A half-typed `if (On(1` has no closing paren yet. Take what is
      // there instead of throwing: an editor parses on every keystroke,
      // and the engine reads an empty condition as false.
      String conditionContent = endParen > startParen
          ? trimmed.substring(startParen + 1, endParen)
          : trimmed.substring(startParen + 1);
      var parsedCond = _parseCommand(conditionContent);

      List<ScriptStatement> ifBody = [];
      int nextLineIdx = i + 1;
      int nextIndent = -1;

      while (nextLineIdx < lines.length &&
          (lines[nextLineIdx].trim().isEmpty ||
              lines[nextLineIdx].trim().startsWith('#'))) {
        nextLineIdx++;
      }

      if (nextLineIdx < lines.length) {
        nextIndent = _countIndent(lines[nextLineIdx]);
      }

      if (nextIndent > indent && nextIndent > parentIndent) {
        i = _parseBlock(lines, nextLineIdx, nextIndent, ifBody);
      } else {
        i = nextLineIdx;
      }

      List<ScriptStatement> elseBody = [];
      if (i < lines.length) {
        int elseLineIdx = i;
        while (elseLineIdx < lines.length &&
            (lines[elseLineIdx].trim().isEmpty ||
                lines[elseLineIdx].trim().startsWith('#'))) {
          elseLineIdx++;
        }

        if (elseLineIdx < lines.length) {
          String nextLine = stripComment(lines[elseLineIdx]).trim();
          int elseLineIndent = _countIndent(lines[elseLineIdx]);
          if (nextLine == 'else' && elseLineIndent == indent) {
            elseLine = elseLineIdx;
            int elseBodyIdx = elseLineIdx + 1;
            int elseIndent = -1;

            while (elseBodyIdx < lines.length &&
                (lines[elseBodyIdx].trim().isEmpty ||
                    lines[elseBodyIdx].trim().startsWith('#'))) {
              elseBodyIdx++;
            }

            if (elseBodyIdx < lines.length) {
              elseIndent = _countIndent(lines[elseBodyIdx]);
            }

            if (elseIndent > indent && elseIndent > parentIndent) {
              i = _parseBlock(lines, elseBodyIdx, elseIndent, elseBody);
            } else {
              i = elseBodyIdx;
            }
          }
        }
      }

      targetList.add(
        IfStatement(parsedCond.command, parsedCond.args, ifBody, elseBody)
          ..line = ifLine
          ..elseLine = elseLine,
      );
      continue;
    } else {
      targetList.add(_parseCommand(trimmed)..line = i);
      i++;
    }
  }
  return i;
}

/// Parses a single command line into [CommandStatement] (used by parser and expression evaluator).
CommandStatement parseCommand(String line) => _parseCommand(line);

/// Drops a trailing `# comment`, leaving a `#` inside "quotes" alone.
///
/// A comment after the closing paren used to fall outside `lastIndexOf(')')`
/// by luck, until the comment itself held a `)`: `Flag::Set(10) # 문(door)`
/// handed the engine the argument `10) # 문(door`, and `else # 참고` was an
/// unknown command whose indented block then ran unconditionally.
String stripComment(String line) {
  var inString = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      inString = !inString;
    } else if (ch == '#' && !inString) {
      return line.substring(0, i);
    }
  }
  return line;
}

CommandStatement _parseCommand(String line) {
  line = line.trim();
  int startParen = line.indexOf('(');
  if (startParen == -1) {
    return CommandStatement(line, []);
  }

  int lastParen = line.lastIndexOf(')');
  if (lastParen == -1 || lastParen <= startParen) {
    return CommandStatement(line, []);
  }

  String cmd = line.substring(0, startParen).trim();
  String argsStr = line.substring(startParen + 1, lastParen);

  List<String> args = [];
  String buffer = "";
  bool inString = false;

  int parenDepth = 0;
  for (int j = 0; j < argsStr.length; j++) {
    String char = argsStr[j];
    if (char == '"') {
      inString = !inString;
      buffer += char;
    } else if (char == '(' && !inString) {
      parenDepth++;
      buffer += char;
    } else if (char == ')' && !inString) {
      parenDepth--;
      buffer += char;
    } else if (char == ',' && !inString && parenDepth == 0) {
      args.add(buffer.trim());
      buffer = "";
    } else {
      buffer += char;
    }
  }
  if (buffer.isNotEmpty) args.add(buffer.trim());

  return CommandStatement(cmd, args);
}

int _countIndent(String line) {
  int count = 0;
  for (int i = 0; i < line.length; i++) {
    if (line[i] == ' ') {
      count++;
    } else if (line[i] == '\t') {
      count += 8;
    } else {
      break;
    }
  }
  return count;
}
