import 'package:hd_world_legacy/hd_world_legacy.dart' as legacy;
import 'package:path/path.dart' as p;

import 'index.dart';
import 'symbol_table.dart';
import 'workspace.dart';

enum Severity { error, warning, information, hint }

/// One thing to tell the author about one place in the file.
class Finding {
  Finding(this.span, this.severity, this.code, this.message);

  final Span span;
  final Severity severity;

  /// Stable id, e.g. `unknown-function`. Shows in the Problems panel.
  final String code;
  final String message;

  @override
  String toString() => '${span.line + 1}:${span.start + 1} [$code] $message';
}

class AnalyzeOptions {
  const AnalyzeOptions({this.eventOverrideHint = true});

  final bool eventOverrideHint;
}

/// Runs every check on one file. Pure apart from what [Workspace] reads
/// from disk for includes and flag files.
List<Finding> analyze({
  required String path,
  required Cm2Index index,
  required SymbolTable symbols,
  required Workspace workspace,
  AnalyzeOptions options = const AnalyzeOptions(),
}) {
  final here = Workspace.canonical(path);
  final out = <Finding>[];
  final scope = workspace.scopeFor(here, index);

  _structure(index, out);
  _includes(scope, out);
  _calls(index, symbols, out);
  _names(index, scope, symbols, out);
  _variables(index, scope, out);
  _attributes(index, out);
  _flags(here, index, symbols, workspace, out);
  _battle(index, out);
  _handlers(index, options, out);
  _indentation(index, out);

  out.sort((a, b) {
    final byLine = a.span.line.compareTo(b.span.line);
    return byLine != 0 ? byLine : a.span.start.compareTo(b.span.start);
  });
  return out;
}

/// Lines the parser could only half read.
void _structure(Cm2Index index, List<Finding> out) {
  for (final line in index.unclosedIfLines) {
    out.add(
      Finding(
        _lineSpan(index, line),
        Severity.error,
        'unclosed-condition',
        'if 의 조건이 닫히지 않았습니다. 엔진은 이 조건을 거짓으로 보고 블록을 건너뜁니다.',
      ),
    );
  }
  for (final line in index.elseCommandLines) {
    out.add(
      Finding(
        _lineSpan(index, line),
        Severity.error,
        'else-not-recognized',
        '이 else 는 위 if 와 들여쓰기가 달라 else 로 읽히지 않습니다. '
            '아래 블록이 조건 없이 항상 실행됩니다.',
      ),
    );
  }
  for (final arg in index.malformedArgs) {
    out.add(
      Finding(
        arg.span,
        Severity.error,
        'malformed-argument',
        '인자 「${arg.raw}」 를 읽을 수 없습니다. 쉼표가 빠졌거나 이름에 쓸 수 없는 글자가 있거나 '
            '괄호가 닫히지 않았습니다. 엔진은 이 글자를 문자열 그대로 넘겨 조건이 조용히 거짓이 됩니다.',
      ),
    );
  }
}

void _includes(Scope scope, List<Finding> out) {
  for (final inc in scope.unresolved) {
    out.add(
      Finding(
        inc.span,
        Severity.error,
        'include-not-found',
        '"${inc.path}" 파일을 찾지 못했거나 읽을 수 없습니다. 이 문서의 폴더와 cm2.assetsDir 설정을 봤습니다. '
            '실행 중에는 include 가 조용히 실패하고 그 상수들이 전부 문자열이 됩니다.',
      ),
    );
  }
}

void _calls(Cm2Index index, SymbolTable symbols, List<Finding> out) {
  for (final call in index.calls) {
    final symbol = call.isCommand ? symbols.command(call.name) : symbols.function(call.name);
    if (symbol == null) {
      if (call.isCommand) {
        final asFunction = symbols.function(call.name);
        out.add(
          Finding(
            call.span,
            Severity.error,
            'unknown-command',
            asFunction != null
                ? '"${call.name}" 은 값을 돌려주는 함수라 줄 하나로 쓰면 아무 일도 하지 않습니다. '
                    '조건이나 대입 안에서 쓰세요.'
                : '모르는 명령 "${call.name}" 입니다. 실행 중에는 "Unknown command" 한 줄만 찍고 건너뜁니다.',
          ),
        );
      } else {
        final asCommand = symbols.command(call.name);
        out.add(
          Finding(
            call.span,
            Severity.error,
            'unknown-function',
            asCommand != null
                ? '"${call.name}" 은 명령이라 값이 없습니다. 조건 안에서 쓰면 0 으로 읽힙니다.'
                : '모르는 함수 "${call.name}" 입니다. 실행 중에는 0 을 돌려줘 조건이 조용히 반대로 갑니다.',
          ),
        );
      }
      continue;
    }
    final n = call.args.where((a) => a.trim().isNotEmpty).length;
    if (n < symbol.minArgs) {
      out.add(
        Finding(
          call.span,
          Severity.error,
          'too-few-arguments',
          '${symbol.signature} 는 인자가 ${symbol.minArgs}개 필요한데 $n개입니다.',
        ),
      );
    } else if (symbol.maxArgs != null && n > symbol.maxArgs!) {
      out.add(
        Finding(
          call.span,
          Severity.warning,
          'too-many-arguments',
          '${symbol.signature} 는 인자를 ${symbol.maxArgs}개까지 받는데 $n개입니다. 나머지는 무시됩니다.',
        ),
      );
    }
  }
}

void _names(Cm2Index index, Scope scope, SymbolTable symbols, List<Finding> out) {
  final written = index.writes.map((w) => w.name).toSet();
  for (final read in index.reads) {
    if (scope.constants.containsKey(read.name)) continue;

    if (symbols.any(read.name) != null) {
      out.add(
        Finding(
          read.span,
          Severity.error,
          'missing-parentheses',
          '"${read.name}" 을 괄호 없이 썼습니다. "${read.name}()" 로 써야 값이 옵니다. '
              '지금은 이름 글자가 문자열로 넘어갑니다.',
        ),
      );
      continue;
    }

    if (written.contains(read.name)) {
      // The engine does create a variable on `.assign`, with a warning. The
      // script runs once the assign has run; the write itself is flagged.
      out.add(
        Finding(
          read.span,
          Severity.warning,
          'undeclared-name',
          '"${read.name}" 은 variable() 없이 .assign 으로만 만든 이름입니다. 대입이 실행된 뒤에는 돌지만, '
              '그 전에 읽으면 문자열 그대로입니다. variable(${read.name}) 을 위에 두세요.',
        ),
      );
      continue;
    }

    out.add(
      Finding(
        read.span,
        scope.complete ? Severity.error : Severity.information,
        'undeclared-name',
        '"${read.name}" 은 선언되지 않은 이름입니다. 엔진은 이 글자를 문자열 그대로 값으로 씁니다. '
            'include("const.cm2") 나 include("flag4ep1.cm2") 가 빠졌거나 오타입니다.',
      ),
    );
  }
}

void _variables(Cm2Index index, Scope scope, List<Finding> out) {
  final written = index.writes.map((w) => w.name).toSet();
  final read = index.reads.map((r) => r.name).toSet();

  // Writes that look like the other half of a typo: to an undeclared name,
  // or a second top-level `.assign` to a name that already has one (that is
  // how `flag4ep1.cm2:42` looked — the left side of one line was wrong).
  final stray = index.writes.where((w) => !scope.constants.containsKey(w.name)).toList();
  final topLevelAssigns = <String, int>{};
  for (final w in index.writes) {
    if (w.isTopLevel && !w.isAdd) topLevelAssigns[w.name] = (topLevelAssigns[w.name] ?? 0) + 1;
  }
  final suspects = [
    ...stray,
    ...index.writes.where((w) => w.isTopLevel && !w.isAdd && (topLevelAssigns[w.name] ?? 0) > 1),
  ];

  for (final decl in index.decls) {
    if (!decl.isTopLevel) {
      out.add(
        Finding(
          decl.span,
          Severity.warning,
          'nested-variable',
          '블록 안의 variable() 은 이 갈래가 실행될 때마다 "${decl.name}" 을 0 으로 되돌립니다. '
              '엔진은 최상위의 variable() 만 다시 실행하지 않습니다. 선언을 파일 맨 위로 옮기세요.',
        ),
      );
    }
    if (written.contains(decl.name)) continue;
    if (suspects.isNotEmpty) {
      // The wrong line usually follows its declaration, so a write below
      // wins over one the same distance above.
      int rank(VarWrite w) {
        final d = w.span.line - decl.span.line;
        return d >= 0 ? d * 2 : -d * 2 + 1;
      }
      var nearest = suspects.first;
      for (final w in suspects) {
        if (rank(w) < rank(nearest)) nearest = w;
      }
      out.add(
        Finding(
          decl.span,
          Severity.warning,
          'unassigned-variable',
          '"${decl.name}" 은 선언만 하고 값을 주지 않았습니다. 엔진은 조용히 0 으로 둡니다. '
              '${nearest.span.line + 1}행의 "${nearest.name}.${nearest.isAdd ? 'add' : 'assign'}" 이 이 이름의 오타일 수 있습니다.',
        ),
      );
    } else if (read.contains(decl.name)) {
      out.add(
        Finding(
          decl.span,
          Severity.warning,
          'unassigned-variable',
          '"${decl.name}" 은 값을 주지 않고 읽기만 합니다. 이 파일에서는 항상 0 입니다.',
        ),
      );
    } else {
      out.add(
        Finding(
          decl.span,
          Severity.hint,
          'unused-variable',
          '"${decl.name}" 은 선언만 있고 이 파일 어디에서도 쓰지 않습니다.',
        ),
      );
    }
  }
  for (final write in stray) {
    out.add(
      Finding(
        write.span,
        Severity.warning,
        'assign-undeclared',
        '"${write.name}" 은 variable() 로 선언하지 않은 이름입니다. 선언한 이름과 글자가 다른지 보세요.',
      ),
    );
  }

  final topLevel = index.writes.where((w) => w.isTopLevel && !w.isAdd);
  final nested = index.writes.where((w) => !w.isTopLevel).map((w) => w.name).toSet();
  for (final write in topLevel) {
    if (!nested.contains(write.name)) continue;
    out.add(
      Finding(
        write.span,
        Severity.warning,
        'top-level-assign-resets',
        '최상위의 .assign 은 상호작용마다 다시 실행됩니다. "${write.name}" 은 블록 안에서도 바뀌므로 '
            '그 값이 매번 여기서 지워집니다. 남길 상태는 Flag::Set 이나 Variable::Set 으로 기록하세요.',
      ),
    );
  }
}

void _attributes(Cm2Index index, List<Finding> out) {
  for (final call in index.calls) {
    final isRead = call.name == 'Player::GetAttribute';
    final isWrite = call.name == 'Player::ChangeAttribute';
    if (!isRead && !isWrite) continue;
    if (call.args.length < 2) continue;
    final literal = call.args[1].trim();
    if (!literal.startsWith('"') || !literal.endsWith('"') || literal.length < 2) continue;
    final name = literal.substring(1, literal.length - 1);
    final span = index.literalSpan(call.span.line, literal) ?? call.span;
    if (!legacy.knownAttributes.contains(name)) {
      out.add(
        Finding(
          span,
          Severity.error,
          'unknown-attribute',
          '"$name" 이라는 속성은 없습니다. ${isRead ? '읽으면 0 이 나와 조건이 조용히 어긋납니다' : '쓰면 무시됩니다'}. '
              '쓸 수 있는 이름: ${legacy.knownAttributes.join(', ')}.',
        ),
      );
      continue;
    }
    final retired = legacy.retiredAttributes[name];
    if (isWrite && retired != null) {
      out.add(
        Finding(
          span,
          Severity.warning,
          'retired-attribute',
          '"$name" 은 이제 장비에서 계산되는 값이라 여기서 바꿔도 남지 않습니다. ($retired)',
        ),
      );
    }
  }
}

void _flags(String here, Cm2Index index, SymbolTable symbols, Workspace workspace, List<Finding> out) {
  FlagRegistry? registry;
  FlagRegistry load() => registry ??= workspace.flagRegistry(here);
  final maxFlags = symbols.maxFlags;

  for (final call in index.calls) {
    if (call.name != 'Flag::Set' && call.name != 'Flag::Reset' && call.name != 'Flag::IsSet') {
      continue;
    }
    if (call.args.isEmpty) continue;
    final raw = call.args.first.trim();
    final n = int.tryParse(raw);
    if (n == null) continue;
    final span = index.literalSpan(call.span.line, raw, after: call.span.end) ?? call.span;
    if (n < 0 || n >= maxFlags) {
      out.add(
        Finding(
          span,
          Severity.error,
          'flag-out-of-range',
          '플래그는 0~${maxFlags - 1} 칸입니다. $n 은 실행 중에 무시됩니다.',
        ),
      );
      continue;
    }
    final named = load().byNumber[n];
    if (named != null && named.isNotEmpty) {
      final owners = named.map((f) => '${f.name} (${p.basename(f.file)})').join(', ');
      out.add(
        Finding(
          span,
          Severity.warning,
          'flag-number-collision',
          '번호 $n 은 이미 이름이 있는 칸입니다: $owners. 그 이름을 쓰거나, 다른 뜻이면 비어 있는 번호를 고르세요. '
              '같은 칸을 두 뜻으로 쓰면 한쪽 진행이 다른 쪽을 켭니다.',
        ),
      );
    } else {
      out.add(
        Finding(
          span,
          Severity.information,
          'flag-number-unnamed',
          '이름 없는 플래그 번호 $n 입니다. flag4ep1.cm2 같은 flag*.cm2 에 이름을 붙이면 충돌을 편집기가 잡아 줍니다.',
        ),
      );
    }
  }

  if (Workspace.isFlagFile(here)) {
    final byNumber = <int, List<VarWrite>>{};
    for (final write in index.writes) {
      if (write.isAdd) continue;
      final n = int.tryParse(write.rawValue);
      if (n == null) continue;
      byNumber.putIfAbsent(n, () => []).add(write);
    }
    final all = load();
    for (final entry in byNumber.entries) {
      final others =
          (all.byNumber[entry.key] ?? const <FlagDef>[]).where((f) => f.file != here).toList();
      final dupHere = entry.value.length > 1;
      if (!dupHere && others.isEmpty) continue;
      for (final write in entry.value) {
        final names = [
          ...entry.value.where((w) => w != write).map((w) => w.name),
          ...others.map((f) => '${f.name} (${p.basename(f.file)})'),
        ];
        out.add(
          Finding(
            index.literalSpan(write.span.line, write.rawValue, after: write.span.end) ?? write.span,
            Severity.warning,
            'flag-duplicate-number',
            '번호 ${entry.key} 를 ${names.join(', ')} 도 씁니다. 플래그 번호는 파일이 달라도 같은 칸입니다.',
          ),
        );
      }
    }
  }
}

void _battle(Cm2Index index, List<Finding> out) {
  final starts = index.commandCalls.where((c) => c.name == 'Battle::Start').toList();
  final results = index.functionCalls.where((c) => c.name == 'Battle::Result').length;
  if (starts.isEmpty || results >= starts.length) return;
  for (final start in starts) {
    out.add(
      Finding(
        start.span,
        Severity.warning,
        'battle-result-unread',
        '전투를 ${starts.length}번 시작하는데 Battle::Result() 는 $results번 읽습니다. '
            '결과를 읽지 않으면 이겨도 스크립트가 몰라 같은 싸움이 되풀이됩니다.',
      ),
    );
  }
}

void _handlers(Cm2Index index, AnalyzeOptions options, List<Finding> out) {
  if (!options.eventOverrideHint) return;
  for (final h in index.handlers) {
    if (h.hasOverride || !h.doesSomething) continue;
    out.add(
      Finding(
        _lineSpan(index, h.line),
        Severity.hint,
        'missing-event-override',
        '${h.condition} 블록에 Event::Override() 가 없습니다. 맵 JSON 에 이 칸의 대사가 있으면 그것이 이어서 한 번 더 나옵니다.',
      ),
    );
  }
}

void _indentation(Cm2Index index, List<Finding> out) {
  for (final line in index.mixedIndentLines) {
    final text = index.lines[line];
    final width = text.length - text.trimLeft().length;
    out.add(
      Finding(
        Span(line, 0, width),
        Severity.warning,
        'mixed-indent',
        '탭과 공백이 한 줄에 섞였습니다. 파서는 탭을 8칸으로 세므로 이 줄이 어느 블록에 속하는지 뜻과 다르게 잡힐 수 있습니다.',
      ),
    );
  }
  final tabs = index.tabIndentedLines.length;
  final spaces = index.spaceIndentedLines.length;
  if (tabs > 0 && spaces > 0) {
    final minority = spaces < tabs ? index.spaceIndentedLines : index.tabIndentedLines;
    final majorityName = spaces < tabs ? '탭' : '공백';
    for (final line in minority) {
      final text = index.lines[line];
      final width = text.length - text.trimLeft().length;
      out.add(
        Finding(
          Span(line, 0, width),
          Severity.hint,
          'indent-style-inconsistent',
          '이 파일의 다른 줄은 $majorityName으로 들여썼습니다. 한 파일 안에서는 한 가지만 쓰세요.',
        ),
      );
    }
  }
}

/// The visible text of one line, indentation excluded.
Span _lineSpan(Cm2Index index, int line) {
  final text = index.lines[line];
  final start = text.length - text.trimLeft().length;
  return Span(line, start, text.trimRight().length);
}
