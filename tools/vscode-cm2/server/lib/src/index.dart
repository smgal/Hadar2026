import 'package:cm2_script/cm2_script.dart';

/// Where a name appears: 0-based line, start column, end column.
class Span {
  const Span(this.line, this.start, this.end);

  final int line;
  final int start;
  final int end;

  bool contains(int l, int c) => l == line && c >= start && c <= end;
}

/// One call of a verb, with what the engine will see.
class CallUse {
  CallUse({
    required this.name,
    required this.span,
    required this.args,
    required this.isCommand,
  });

  final String name;
  final Span span;
  final List<String> args;

  /// A statement on its own line (true) or a value inside parentheses.
  final bool isCommand;
}

class VarDecl {
  VarDecl(this.name, this.span, this.depth);

  final String name;
  final Span span;

  /// 0 = top level of the file. The engine only skips `variable` on re-runs
  /// at the top level; a nested one resets its variable every time.
  final int depth;

  bool get isTopLevel => depth == 0;
}

class VarWrite {
  VarWrite({
    required this.name,
    required this.span,
    required this.rawValue,
    required this.isAdd,
    required this.depth,
  });

  final String name;
  final Span span;
  final String rawValue;
  final bool isAdd;
  final int depth;

  bool get isTopLevel => depth == 0;
}

class IncludeUse {
  IncludeUse(this.path, this.span, this.depth);

  final String path;

  /// The string literal, quotes included.
  final Span span;
  final int depth;
}

/// A bare identifier the engine will look up as a variable
/// (`if (temp)`, `Equal(temp, 1)`, the left side of `temp.Equal(1)`).
class NameRead {
  NameRead(this.name, this.span);

  final String name;
  final Span span;
}

/// An argument that is not a literal, not a name and not a call — a missed
/// comma, a hyphen for an underscore, an unclosed `On(1`. The engine hands
/// such text on as a string and the branch goes quietly dead.
class MalformedArg {
  MalformedArg(this.raw, this.span);

  final String raw;
  final Span span;
}

/// An `if (On(...))` / `if (OnArea(...))` block — what the tile dispatcher
/// treats as "this script handled the tile".
class HandlerBlock {
  HandlerBlock({
    required this.condition,
    required this.line,
    required this.endLine,
    required this.bodyCommands,
  });

  final String condition;
  final int line;
  final int endLine;

  /// Every command name inside the block, nested ifs included.
  final Set<String> bodyCommands;

  bool get hasOverride => bodyCommands.contains('Event::Override');

  /// Anything at all besides the override itself means the script handled
  /// the tile, so the JSON fallback dialogue would be a duplicate.
  bool get doesSomething => bodyCommands.any((c) => c != 'Event::Override');
}

/// An `if` worth showing in the outline.
class OutlineNode {
  OutlineNode({
    required this.label,
    required this.kind,
    required this.line,
    required this.endLine,
    required this.children,
  });

  final String label;

  /// `mode` · `handler` · `branch`
  final String kind;
  final int line;
  final int endLine;
  final List<OutlineNode> children;
}

/// Everything the server wants to know about one cm2 file, computed once
/// per edit. Positions come from the source text; meaning comes from the
/// same parser the game runs (`packages/cm2_script`).
class Cm2Index {
  Cm2Index._(this.text, this.lines, this.statements);

  /// A cm2 name: `temp`, `GFD0_IS_FIRST`, `Flag::IsSet`. Anchored.
  static final RegExp identifier =
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)*$');

  /// The same shape, unanchored — for the word under a cursor.
  static final RegExp identifierAnywhere =
      RegExp(r'[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)*');

  final String text;
  final List<String> lines;
  final List<ScriptStatement> statements;

  final List<CallUse> calls = [];
  final List<VarDecl> decls = [];
  final List<VarWrite> writes = [];
  final List<IncludeUse> includes = [];
  final List<NameRead> reads = [];
  final List<MalformedArg> malformedArgs = [];
  final List<HandlerBlock> handlers = [];
  final List<OutlineNode> outline = [];

  /// `if` lines whose condition never closes — `if (On(1`.
  final List<int> unclosedIfLines = [];

  /// Lines the parser read as a command called `else…`: an `else` whose
  /// indentation does not match its `if`. The block under it then runs
  /// unconditionally.
  final List<int> elseCommandLines = [];

  /// Lines whose leading whitespace mixes tabs and spaces.
  final List<int> mixedIndentLines = [];

  /// Indented lines that use spaces only / tabs only.
  final List<int> spaceIndentedLines = [];
  final List<int> tabIndentedLines = [];

  Iterable<CallUse> get commandCalls => calls.where((c) => c.isCommand);
  Iterable<CallUse> get functionCalls => calls.where((c) => !c.isCommand);

  static Cm2Index build(String text) {
    final lines = text.split('\n');
    final index = Cm2Index._(text, lines, ScriptEngine.parse(text));
    index._scanIndentation();
    index._walk(index.statements, 0, index.outline);
    return index;
  }

  /// Where [literal] sits on [line], searching from column [after].
  Span? literalSpan(int line, String literal, {int after = 0}) {
    if (line < 0 || line >= lines.length || literal.isEmpty) return null;
    final col = lines[line].indexOf(literal, after.clamp(0, lines[line].length));
    if (col < 0) return null;
    return Span(line, col, col + literal.length);
  }

  // ---------------------------------------------------------------- walk

  void _walk(List<ScriptStatement> statements, int depth, List<OutlineNode> outlineSink) {
    for (final stmt in statements) {
      if (stmt is CommandStatement) {
        _command(stmt, depth);
      } else if (stmt is IfStatement) {
        _ifStatement(stmt, depth, outlineSink);
      }
    }
  }

  void _command(CommandStatement stmt, int depth) {
    final line = stmt.line;
    if (line < 0 || line >= lines.length) return;
    final cursor = _LineCursor(line, _masked(lines[line]));
    final name = stmt.command;

    if (name == 'else' || name.startsWith('else ')) {
      elseCommandLines.add(line);
      return;
    }

    if (name.endsWith('.assign') || name.endsWith('.add')) {
      final varName = name.substring(0, name.lastIndexOf('.'));
      writes.add(
        VarWrite(
          name: varName,
          span: cursor.find(varName) ?? Span(line, 0, 0),
          rawValue: stmt.args.isNotEmpty ? stmt.args.first.trim() : '',
          isAdd: name.endsWith('.add'),
          depth: depth,
        ),
      );
      for (final arg in stmt.args) {
        _expression(arg, line, cursor);
      }
      return;
    }

    final span = cursor.find(name) ?? Span(line, 0, 0);
    calls.add(CallUse(name: name, span: span, args: stmt.args, isCommand: true));

    if (name == 'variable') {
      if (stmt.args.isNotEmpty) {
        final v = stmt.args.first.trim();
        decls.add(VarDecl(v, cursor.find(v) ?? span, depth));
      }
      return;
    }
    if (name == 'include') {
      if (stmt.args.isNotEmpty) {
        final raw = stmt.args.first.trim();
        includes.add(IncludeUse(_unquote(raw), literalSpan(line, raw) ?? span, depth));
      }
      return;
    }
    for (final arg in stmt.args) {
      _expression(arg, line, cursor);
    }
  }

  void _ifStatement(IfStatement stmt, int depth, List<OutlineNode> outlineSink) {
    final line = stmt.line;
    final children = <OutlineNode>[];
    if (line >= 0 && line < lines.length) {
      final masked = _masked(lines[line]);
      final cursor = _LineCursor(line, masked);
      if (!masked.trimRight().endsWith(')')) unclosedIfLines.add(line);

      if (stmt.conditionArgs.isEmpty) {
        // `if (temp)` — a variable read, not a call. The engine does the same.
        final span = cursor.find(stmt.conditionFunc);
        if (span != null && !_isLiteral(stmt.conditionFunc)) {
          reads.add(NameRead(stmt.conditionFunc, span));
        }
      } else if (stmt.conditionFunc.endsWith('.Equal')) {
        _equalRead(stmt.conditionFunc, cursor);
        for (final arg in stmt.conditionArgs) {
          _expression(arg, line, cursor);
        }
      } else {
        calls.add(
          CallUse(
            name: stmt.conditionFunc,
            span: cursor.find(stmt.conditionFunc) ?? Span(line, 0, 0),
            args: stmt.conditionArgs,
            isCommand: false,
          ),
        );
        for (final arg in stmt.conditionArgs) {
          _expression(arg, line, cursor);
        }
      }
    }

    _walk(stmt.body, depth + 1, children);
    final elseChildren = <OutlineNode>[];
    _walk(stmt.elseBody, depth + 1, elseChildren);

    final endLine = _lastLine(stmt);
    final label = _outlineLabel(stmt);
    if (label != null) {
      outlineSink.add(
        OutlineNode(
          label: label.$1,
          kind: label.$2,
          line: line,
          endLine: endLine,
          children: [...children, ...elseChildren],
        ),
      );
    } else {
      outlineSink
        ..addAll(children)
        ..addAll(elseChildren);
    }

    if (stmt.conditionFunc == 'On' || stmt.conditionFunc == 'OnArea') {
      handlers.add(
        HandlerBlock(
          condition: _conditionLabel(stmt),
          line: line,
          endLine: endLine,
          bodyCommands: _commandNames(stmt.body),
        ),
      );
    }
  }

  /// Nested calls inside an argument — `Not(Flag::IsSet(x))` — bare names
  /// the engine will read as variables, and text it can do nothing with.
  void _expression(String raw, int line, _LineCursor cursor) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.startsWith('"')) return;

    if (!trimmed.contains('(')) {
      if (_isLiteral(trimmed)) return;
      if (identifier.hasMatch(trimmed)) {
        final span = cursor.find(trimmed);
        if (span != null) reads.add(NameRead(trimmed, span));
        return;
      }
      malformedArgs.add(MalformedArg(trimmed, _rawSpan(line, trimmed)));
      return;
    }

    final parsed = parseCommand(trimmed);
    if (parsed.command == trimmed) {
      // Has a `(` but never closes — `On(1`.
      malformedArgs.add(MalformedArg(trimmed, _rawSpan(line, trimmed)));
      return;
    }
    if (parsed.command.endsWith('.Equal')) {
      _equalRead(parsed.command, cursor);
    } else {
      calls.add(
        CallUse(
          name: parsed.command,
          span: cursor.find(parsed.command) ?? Span(line, 0, 0),
          args: parsed.args,
          isCommand: false,
        ),
      );
    }
    for (final arg in parsed.args) {
      _expression(arg, line, cursor);
    }
  }

  /// `x.Equal(v)` — the engine answers by suffix; the left side is a read.
  void _equalRead(String name, _LineCursor cursor) {
    final varName = name.substring(0, name.lastIndexOf('.'));
    final span = cursor.find(varName);
    if (span != null) reads.add(NameRead(varName, span));
  }

  // ------------------------------------------------------------- helpers

  static bool _isLiteral(String s) =>
      num.tryParse(s) != null || (s.startsWith('"') && s.endsWith('"'));

  static String _unquote(String s) =>
      s.length >= 2 && s.startsWith('"') && s.endsWith('"') ? s.substring(1, s.length - 1) : s;

  Span _rawSpan(int line, String raw) =>
      literalSpan(line, raw) ?? Span(line, 0, lines[line].length);

  int _lastLine(IfStatement stmt) {
    var last = stmt.line;
    void visit(List<ScriptStatement> list) {
      for (final s in list) {
        if (s is CommandStatement) {
          if (s.line > last) last = s.line;
        } else if (s is IfStatement) {
          if (s.line > last) last = s.line;
          if (s.elseLine > last) last = s.elseLine;
          visit(s.body);
          visit(s.elseBody);
        }
      }
    }

    visit(stmt.body);
    if (stmt.elseLine > last) last = stmt.elseLine;
    visit(stmt.elseBody);
    return last;
  }

  static Set<String> _commandNames(List<ScriptStatement> list) {
    final names = <String>{};
    void visit(List<ScriptStatement> l) {
      for (final s in l) {
        if (s is CommandStatement) {
          names.add(s.command);
        } else if (s is IfStatement) {
          visit(s.body);
          visit(s.elseBody);
        }
      }
    }

    visit(list);
    return names;
  }

  /// `On(14, 30)` — the condition as the outline and the hint both print it.
  static String _conditionLabel(IfStatement stmt) =>
      '${stmt.conditionFunc}(${stmt.conditionArgs.map((s) => s.trim()).join(', ')})';

  /// `(label, kind)` for the outline, or null when the `if` is plumbing.
  (String, String)? _outlineLabel(IfStatement stmt) {
    final f = stmt.conditionFunc;
    final a = stmt.conditionArgs;
    if (f == 'Equal' && a.length == 2) {
      if (a[0].replaceAll(' ', '') == 'ScriptMode()') return ('ScriptMode = ${a[1].trim()}', 'mode');
      if (a[1].replaceAll(' ', '') == 'ScriptMode()') return ('ScriptMode = ${a[0].trim()}', 'mode');
    }
    if (f == 'On' || f == 'OnArea') return (_conditionLabel(stmt), 'handler');
    if (f == 'Not' && a.length == 1 && a[0].trim().startsWith('Flag::IsSet')) {
      return ('처음: ${a[0].trim()}', 'branch');
    }
    if (f == 'Flag::IsSet') return ('켜짐: ${a.join(', ')}', 'branch');
    return null;
  }

  void _scanIndentation() {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty || line.trim().startsWith('#')) continue;
      var j = 0;
      var tabs = false;
      var spaces = false;
      while (j < line.length && (line[j] == ' ' || line[j] == '\t')) {
        if (line[j] == '\t') tabs = true;
        if (line[j] == ' ') spaces = true;
        j++;
      }
      if (j == 0) continue;
      if (tabs && spaces) {
        mixedIndentLines.add(i);
      } else if (tabs) {
        tabIndentedLines.add(i);
      } else {
        spaceIndentedLines.add(i);
      }
    }
  }

  /// The line with string contents and the comment tail blanked out, so a
  /// name search never lands inside `"..."`. Lengths are preserved.
  static String _masked(String line) {
    final out = StringBuffer();
    var inString = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inString = !inString;
        out.write(ch);
      } else if (inString) {
        out.write(' ');
      } else if (ch == '#') {
        out.write(' ' * (line.length - i));
        break;
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }
}

/// Finds successive occurrences of names in one masked line, left to
/// right, so `Equal(temp, temp2)` resolves both reads to their own columns.
class _LineCursor {
  _LineCursor(this._line, this.masked);

  final int _line;
  final String masked;
  final Set<int> _taken = {};

  // `.` is deliberately not a word character: `temp.assign` must let us
  // find `temp`. `:` stays so that `Set` is not found inside `Flag::Set`.
  static final RegExp _word = RegExp(r'[A-Za-z0-9_:]');

  Span? find(String name) {
    if (name.isEmpty) return null;
    var from = 0;
    while (from <= masked.length) {
      final at = masked.indexOf(name, from);
      if (at < 0) return null;
      final end = at + name.length;
      final beforeOk = at == 0 || !_word.hasMatch(masked[at - 1]);
      final afterOk = end >= masked.length || !_word.hasMatch(masked[end]);
      if (beforeOk && afterOk && !_taken.contains(at)) {
        _taken.add(at);
        return Span(_line, at, end);
      }
      from = at + 1;
    }
    return null;
  }
}
