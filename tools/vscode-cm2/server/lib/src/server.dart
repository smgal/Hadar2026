import 'dart:io';

import 'package:lsp_server/lsp_server.dart';
import 'package:path/path.dart' as p;

import 'analyzer.dart';
import 'index.dart';
import 'symbol_table.dart';
import 'workspace.dart';

/// The LSP face of the analyzer. Everything the editor sees comes through
/// here; everything that decides what is wrong lives in `analyzer.dart`.
///
/// Logging goes to stderr only — stdout is the protocol channel.
class Cm2Server {
  Cm2Server(this.connection, this.symbols, {String assetsDir = ''})
      : workspace = Workspace(assetsDir: assetsDir);

  final Connection connection;
  final SymbolTable symbols;
  final Workspace workspace;
  AnalyzeOptions options = const AnalyzeOptions();

  /// The URI the client used for each open file, so diagnostics go back
  /// under the same spelling.
  final Map<String, Uri> _uriOf = {};

  /// Live text per open file. The index may lag behind when the last edit
  /// did not parse; the text never does.
  final Map<String, String> _text = {};

  void register() {
    connection.onInitialize((params) async {
      final init = params.initializationOptions;
      if (init is Map) {
        final assets = init['assetsDir'];
        // An empty string clears a folder set earlier — it is not "unset".
        if (assets is String) workspace.assetsDir = assets;
        final hint = init['eventOverrideHint'];
        if (hint is bool) options = AnalyzeOptions(eventOverrideHint: hint);
      }
      _log('initialized (assetsDir: "${workspace.assetsDir}")');
      return InitializeResult(
        capabilities: ServerCapabilities(
          textDocumentSync: Either2.t2(
            TextDocumentSyncOptions(
              openClose: true,
              change: TextDocumentSyncKind.Incremental,
            ),
          ),
          completionProvider: CompletionOptions(triggerCharacters: [':', '.', '(', '"']),
          hoverProvider: Either2.t1(true),
          definitionProvider: Either2.t1(true),
          documentSymbolProvider: Either2.t1(true),
        ),
        serverInfo: InitializeResultServerInfo(name: 'cm2_lsp', version: '0.1.0'),
      );
    });
    connection.onInitialized((_) async {});
    connection.onShutdown(() async {});
    connection.onExit(() async {
      exit(0);
    });

    connection.onDidOpenTextDocument((params) async {
      final uri = params.textDocument.uri;
      final path = _pathOf(uri);
      _uriOf[path] = uri;
      _update(path, params.textDocument.text);
    });
    connection.onDidChangeTextDocument((params) async {
      final path = _pathOf(params.textDocument.uri);
      var text = _text[path] ?? workspace.indexFor(path)?.text ?? '';
      for (final change in params.contentChanges) {
        text = change.map(
          (incremental) => _applyEdit(text, incremental),
          (full) => full.text,
        );
      }
      _update(path, text);
    });
    connection.onDidCloseTextDocument((params) async {
      final uri = params.textDocument.uri;
      final path = _pathOf(uri);
      workspace.close(path);
      _uriOf.remove(path);
      _text.remove(path);
      connection.sendDiagnostics(PublishDiagnosticsParams(uri: uri, diagnostics: const []));
    });
    // `const.cm2` or a `flag*.cm2` saved outside the editor changes what
    // every open script may read. The disk cache is by mtime, so running
    // the analysis again is all it takes.
    connection.onNotification('workspace/didChangeWatchedFiles', (_) async {
      _publishAll();
    });

    // These may answer `null`, which the typed helpers on Connection cannot
    // express, so they go straight to the peer with the same decoding.
    connection.peer.registerMethod('textDocument/hover', (params) async {
      final position = TextDocumentPositionParams.fromJson(params.value);
      return _guard(() => hover(position));
    });
    connection.peer.registerMethod('textDocument/completion', (params) async {
      final position = TextDocumentPositionParams.fromJson(params.value);
      return _guard(() => completion(position)) ??
          CompletionList(isIncomplete: false, items: const []);
    });
    connection.peer.registerMethod('textDocument/definition', (params) async {
      final position = TextDocumentPositionParams.fromJson(params.value);
      return _guard(() => definition(position));
    });
    connection.peer.registerMethod('textDocument/documentSymbol', (params) async {
      final request = DocumentSymbolParams.fromJson(params.value);
      return _guard(() => documentSymbols(request)) ?? const <DocumentSymbol>[];
    });
  }

  // ------------------------------------------------------------ diagnostics

  /// Re-indexes one file and republishes every open file — includes and
  /// flag files change what their readers see. Text the parser rejects
  /// keeps the previous index and is reported as one diagnostic; nothing
  /// is left silent.
  void _update(String path, String text) {
    _text[path] = text;
    try {
      workspace.open(path, text);
    } catch (e) {
      _log('parse failed for $path: $e');
      final uri = _uriOf[path];
      if (uri != null) {
        _send(uri, [
          _single('parse-error', '파서가 이 파일을 읽지 못했습니다. 고치는 동안 이전 진단은 잠시 멈춥니다. ($e)'),
        ]);
      }
      return;
    }
    _publishAll();
  }

  void _publishAll() {
    for (final entry in _uriOf.entries.toList()) {
      _publish(entry.key, entry.value);
    }
  }

  void _publish(String path, Uri uri) {
    final index = workspace.indexFor(path);
    if (index == null) return;
    List<Finding> findings;
    try {
      findings = analyze(
        path: path,
        index: index,
        symbols: symbols,
        workspace: workspace,
        options: options,
      );
    } catch (e, s) {
      _log('analyze failed for $path: $e\n$s');
      _send(uri, [_single('analyzer-error', '검사기가 이 파일에서 멈췄습니다. 서버 로그를 보세요. ($e)')]);
      return;
    }
    _send(uri, findings.map(_diagnostic).toList());
  }

  void _send(Uri uri, List<Diagnostic> diagnostics) {
    connection.sendDiagnostics(PublishDiagnosticsParams(uri: uri, diagnostics: diagnostics));
  }

  Diagnostic _single(String code, String message) => Diagnostic(
        range: _range(const Span(0, 0, 0)),
        message: message,
        code: code,
        source: 'cm2',
        severity: DiagnosticSeverity.Error,
      );

  Diagnostic _diagnostic(Finding f) => Diagnostic(
        range: _range(f.span),
        message: f.message,
        code: f.code,
        source: 'cm2',
        severity: switch (f.severity) {
          Severity.error => DiagnosticSeverity.Error,
          Severity.warning => DiagnosticSeverity.Warning,
          Severity.information => DiagnosticSeverity.Information,
          Severity.hint => DiagnosticSeverity.Hint,
        },
      );

  // ------------------------------------------------------------------ hover

  Hover? hover(TextDocumentPositionParams params) {
    final path = _pathOf(params.textDocument.uri);
    final index = workspace.indexFor(path);
    if (index == null) return null;
    final word = _wordAt(index, params.position);
    if (word == null) return null;

    // `x.Equal(` — the member form, not the two-argument `Equal(a, b)`.
    final line = index.lines[word.span.line];
    if (word.span.start > 0 && line[word.span.start - 1] == '.') {
      final form = symbols.memberForm(word.text);
      if (form != null) {
        return _hoverMarkdown('```cm2\n${form.signature}\n```\n\n${form.doc}', word.span);
      }
    }

    final symbol = symbols.any(word.text);
    if (symbol != null) return _hoverMarkdown(symbol.markdown, word.span);

    final def = workspace.scopeFor(path, index).constants[word.text];
    if (def != null) {
      final value = def.rawValue == null ? '(값 없음 — 0 으로 읽힘)' : '= ${def.rawValue}';
      final where = '${p.basename(def.file)}:${def.span.line + 1}';
      return _hoverMarkdown('```cm2\n${def.name} $value\n```\n\n정의: $where', word.span);
    }
    return null;
  }

  Hover _hoverMarkdown(String markdown, Span span) => Hover(
        contents: Either2.t1(MarkupContent(kind: MarkupKind.Markdown, value: markdown)),
        range: _range(span),
      );

  // ------------------------------------------------------------- completion

  CompletionList completion(TextDocumentPositionParams params) {
    final path = _pathOf(params.textDocument.uri);
    final index = workspace.indexFor(path);
    if (index == null) return CompletionList(isIncomplete: false, items: const []);
    final lineNo = params.position.line;
    final line = lineNo < index.lines.length ? index.lines[lineNo] : '';
    final before = line.substring(0, params.position.character.clamp(0, line.length));

    // `temp.` → the three member forms and nothing else.
    if (RegExp(r'[A-Za-z_][A-Za-z0-9_]*\.$').hasMatch(before)) {
      return CompletionList(
        isIncomplete: false,
        items: [
          for (final m in symbols.memberForms)
            CompletionItem(
              label: m.suffix,
              kind: CompletionItemKind.Method,
              detail: m.signature,
              documentation: _md(m.doc),
              insertText: '${m.suffix}(\$1)\$0',
              insertTextFormat: InsertTextFormat.Snippet,
            ),
        ],
      );
    }

    final atLineStart = RegExp(r'^\s*[A-Za-z_:]*$').hasMatch(before);
    final items = <CompletionItem>[];

    for (final s in symbols.all) {
      // A command belongs at the start of a line; a function inside parens.
      if (s.isCommand != atLineStart) continue;
      items.add(
        CompletionItem(
          label: s.name,
          kind: s.isCommand ? CompletionItemKind.Function : CompletionItemKind.Method,
          detail: s.signature,
          documentation: _md(s.markdown),
          insertText: s.params.isEmpty ? '${s.name}()' : '${s.name}(\$1)\$0',
          insertTextFormat: InsertTextFormat.Snippet,
          sortText: '1${s.name}',
        ),
      );
    }

    if (atLineStart) {
      items.addAll([
        _keyword('if', 'if (\$1)\n\t\$0', 'if (조건) 다음 줄을 한 단 들여 쓴다'),
        _keyword('else', 'else\n\t\$0', '바로 위 if 와 같은 깊이에 둔다'),
        _keyword('variable', 'variable(\$1)\n\$1.assign(\$2)', '선언과 첫 대입'),
        _keyword('include', 'include("\$1.cm2")', '다른 cm2 파일을 이 자리에서 실행'),
        _keyword('halt', 'halt()', '이번 실행을 여기서 끝낸다'),
      ]);
    }

    final scope = workspace.scopeFor(path, index);
    for (final def in scope.constants.values) {
      final isConstant = def.rawValue != null && def.file != Workspace.canonical(path);
      items.add(
        CompletionItem(
          label: def.name,
          kind: isConstant ? CompletionItemKind.Constant : CompletionItemKind.Variable,
          detail: def.rawValue == null ? '변수' : '= ${def.rawValue}',
          documentation: _md('정의: ${p.basename(def.file)}:${def.span.line + 1}'),
          insertText: def.name,
          sortText: '2${def.name}',
        ),
      );
    }
    return CompletionList(isIncomplete: false, items: items);
  }

  CompletionItem _keyword(String label, String snippet, String doc) => CompletionItem(
        label: label,
        kind: CompletionItemKind.Keyword,
        documentation: _md(doc),
        insertText: snippet,
        insertTextFormat: InsertTextFormat.Snippet,
        sortText: '0$label',
      );

  Either2<MarkupContent, String> _md(String value) =>
      Either2.t1(MarkupContent(kind: MarkupKind.Markdown, value: value));

  // ------------------------------------------------------------- definition

  Location? definition(TextDocumentPositionParams params) {
    final path = _pathOf(params.textDocument.uri);
    final index = workspace.indexFor(path);
    if (index == null) return null;
    final pos = params.position;

    for (final inc in index.includes) {
      if (inc.span.contains(pos.line, pos.character)) {
        final target = workspace.resolveInclude(path, inc.path);
        if (target == null) return null;
        return Location(uri: Uri.file(target), range: _range(const Span(0, 0, 0)));
      }
    }

    final word = _wordAt(index, pos);
    if (word == null) return null;
    final def = workspace.scopeFor(path, index).constants[word.text];
    if (def == null) return null;
    return Location(uri: Uri.file(def.file), range: _range(def.span));
  }

  // ------------------------------------------------------- document symbols

  List<DocumentSymbol> documentSymbols(DocumentSymbolParams params) {
    final path = _pathOf(params.textDocument.uri);
    final index = workspace.indexFor(path);
    if (index == null) return const [];
    return index.outline.map((n) => _symbol(n, index)).toList();
  }

  DocumentSymbol _symbol(OutlineNode node, Cm2Index index) {
    final endLine = node.endLine.clamp(0, index.lines.length - 1);
    final ifLine = index.lines[node.line];
    final kind = switch (node.kind) {
      'mode' => SymbolKind.Module,
      'handler' => SymbolKind.Event,
      _ => SymbolKind.Boolean,
    };
    return DocumentSymbol(
      name: node.label,
      kind: kind,
      range: Range(
        start: Position(line: node.line, character: 0),
        end: Position(line: endLine, character: index.lines[endLine].length),
      ),
      selectionRange: Range(
        start: Position(line: node.line, character: ifLine.length - ifLine.trimLeft().length),
        end: Position(line: node.line, character: ifLine.trimRight().length),
      ),
      children: node.children.map((c) => _symbol(c, index)).toList(),
    );
  }

  // ---------------------------------------------------------------- helpers

  ({String text, Span span})? _wordAt(Cm2Index index, Position pos) {
    if (pos.line < 0 || pos.line >= index.lines.length) return null;
    final line = index.lines[pos.line];
    for (final m in Cm2Index.identifierAnywhere.allMatches(line)) {
      if (pos.character >= m.start && pos.character <= m.end) {
        return (text: m.group(0)!, span: Span(pos.line, m.start, m.end));
      }
    }
    return null;
  }

  static Range _range(Span s) => Range(
        start: Position(line: s.line, character: s.start),
        end: Position(line: s.line, character: s.end),
      );

  static String _pathOf(Uri uri) => uri.scheme == 'file' ? uri.toFilePath() : uri.toString();

  /// Applies one ranged edit. Positions count UTF-16 units, as Dart strings do.
  static String _applyEdit(String text, TextDocumentContentChangeEvent1 e) {
    final start = _offset(text, e.range.start);
    final end = _offset(text, e.range.end);
    return text.replaceRange(start, end, e.text);
  }

  static int _offset(String text, Position pos) {
    var line = 0;
    var i = 0;
    while (line < pos.line && i < text.length) {
      if (text[i] == '\n') line++;
      i++;
    }
    return (i + pos.character).clamp(0, text.length);
  }

  T? _guard<T>(T? Function() body) {
    try {
      return body();
    } catch (e, s) {
      _log('request failed: $e\n$s');
      return null;
    }
  }

  static void _log(String message) => stderr.writeln('[cm2_lsp] $message');
}
