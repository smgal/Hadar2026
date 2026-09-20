@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The server as VS Code will drive it: a child process on stdio, LSP
/// framing, real JSON. Proves the wiring, not the analysis — that is
/// `analyzer_test.dart`.
void main() {
  late Process proc;
  late _Lsp lsp;
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('cm2_lsp_stdio_');
    File(p.join(dir.path, 'const.cm2')).writeAsStringSync(
      'variable(FLAG_TALK)\nFLAG_TALK.assign(1)\n',
    );
    proc = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/cm2_lsp.dart', '--symbols', 'lib/data/cm2_symbols.json'],
    );
    proc.stderr.transform(utf8.decoder).listen((s) => stderr.write('[server] $s'));
    lsp = _Lsp(proc);
    final init = await lsp.request('initialize', {
      'processId': pid,
      'rootUri': Uri.file(dir.path).toString(),
      'capabilities': <String, Object?>{},
      'initializationOptions': {'assetsDir': dir.path, 'eventOverrideHint': true},
    });
    expect(init['capabilities']['hoverProvider'], isTrue);
    lsp.notify('initialized', {});
  });

  tearDownAll(() async {
    await lsp.request('shutdown', null);
    lsp.notify('exit', null);
    await proc.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      proc.kill();
      return -1;
    });
    dir.deleteSync(recursive: true);
  });

  test('파일을 열면 진단이 온다 — 모르는 명령이 그 줄에', () async {
    final uri = Uri.file(p.join(dir.path, 'a.cm2')).toString();
    final published = lsp.nextNotification('textDocument/publishDiagnostics');
    lsp.notify('textDocument/didOpen', {
      'textDocument': {
        'uri': uri,
        'languageId': 'cm2',
        'version': 1,
        'text': 'include("const.cm2")\nTallk("x")\nif (Equal(ScriptMode(), FLAG_TALK))\n\tTalk("y")\n',
      },
    });
    final params = await published;
    expect(params['uri'], uri);
    final diags = (params['diagnostics'] as List).cast<Map<String, dynamic>>();
    final codes = diags.map((d) => d['code']).toList();
    expect(codes, contains('unknown-command'));
    final unknown = diags.firstWhere((d) => d['code'] == 'unknown-command');
    expect(unknown['range']['start']['line'], 1);
    expect(unknown['severity'], 1);
  });

  test('고치면 진단이 사라진다 (전체 텍스트 동기화)', () async {
    final uri = Uri.file(p.join(dir.path, 'a.cm2')).toString();
    final published = lsp.nextNotification('textDocument/publishDiagnostics');
    lsp.notify('textDocument/didChange', {
      'textDocument': {'uri': uri, 'version': 2},
      'contentChanges': [
        {'text': 'include("const.cm2")\nTalk("x")\nif (Equal(ScriptMode(), FLAG_TALK))\n\tTalk("y")\n'},
      ],
    });
    final params = await published;
    final diags = (params['diagnostics'] as List).cast<Map<String, dynamic>>();
    expect(diags.where((d) => d['severity'] == 1), isEmpty, reason: diags.toString());
  });

  test('부분 편집(범위)으로도 같은 진단이 온다', () async {
    final uri = Uri.file(p.join(dir.path, 'a.cm2')).toString();
    // 1행은 `Talk("x")`. 0~4열의 `Talk` 만 `Tallk` 로 바꾼다.
    final broke = lsp.nextNotification('textDocument/publishDiagnostics');
    lsp.notify('textDocument/didChange', {
      'textDocument': {'uri': uri, 'version': 3},
      'contentChanges': [
        {
          'range': {'start': {'line': 1, 'character': 0}, 'end': {'line': 1, 'character': 4}},
          'text': 'Tallk',
        },
      ],
    });
    final p1 = (await broke)['diagnostics'] as List;
    expect(p1.map((d) => d['code']), contains('unknown-command'));

    final fixed = lsp.nextNotification('textDocument/publishDiagnostics');
    lsp.notify('textDocument/didChange', {
      'textDocument': {'uri': uri, 'version': 4},
      'contentChanges': [
        {
          'range': {'start': {'line': 1, 'character': 0}, 'end': {'line': 1, 'character': 5}},
          'text': 'Talk',
        },
      ],
    });
    final p2 = (await fixed)['diagnostics'] as List;
    expect(p2.where((d) => d['severity'] == 1), isEmpty, reason: p2.toString());
  });

  test('밖에서 파일이 바뀌었다는 알림이 오면 다시 진단한다', () async {
    final uri = Uri.file(p.join(dir.path, 'a.cm2')).toString();
    final published = lsp.nextNotification('textDocument/publishDiagnostics');
    lsp.notify('workspace/didChangeWatchedFiles', {
      'changes': [
        {'uri': Uri.file(p.join(dir.path, 'const.cm2')).toString(), 'type': 2},
      ],
    });
    expect((await published)['uri'], uri);
  });

  test('동사 위에서 도움말, 상수 위에서 값과 정의 위치', () async {
    final uri = Uri.file(p.join(dir.path, 'a.cm2')).toString();
    final onTalk = await lsp.request('textDocument/hover', {
      'textDocument': {'uri': uri},
      'position': {'line': 1, 'character': 2},
    });
    expect(onTalk['contents']['value'], contains('Talk('));

    final onConst = await lsp.request('textDocument/hover', {
      'textDocument': {'uri': uri},
      'position': {'line': 2, 'character': 26},
    });
    expect(onConst['contents']['value'], contains('FLAG_TALK = 1'));
    expect(onConst['contents']['value'], contains('const.cm2:1'));

    final def = await lsp.request('textDocument/definition', {
      'textDocument': {'uri': uri},
      'position': {'line': 2, 'character': 26},
    });
    expect(def['uri'], Uri.file(p.join(dir.path, 'const.cm2')).toString());
    expect(def['range']['start']['line'], 0);
  });

  test('줄 처음에서는 명령을, 괄호 안에서는 함수와 상수를 권한다', () async {
    final uri = Uri.file(p.join(dir.path, 'a.cm2')).toString();
    final atStart = await lsp.request('textDocument/completion', {
      'textDocument': {'uri': uri},
      'position': {'line': 3, 'character': 1},
    });
    final startLabels = (atStart['items'] as List).map((i) => i['label']).toSet();
    expect(startLabels, contains('Talk'));
    expect(startLabels, contains('if'));
    expect(startLabels, isNot(contains('Flag::IsSet')));

    final inParens = await lsp.request('textDocument/completion', {
      'textDocument': {'uri': uri},
      'position': {'line': 2, 'character': 10},
    });
    final innerLabels = (inParens['items'] as List).map((i) => i['label']).toSet();
    expect(innerLabels, contains('Flag::IsSet'));
    expect(innerLabels, contains('FLAG_TALK'));
    expect(innerLabels, isNot(contains('Talk')));
  });

  test('개요에 ScriptMode 블록이 나온다', () async {
    final uri = Uri.file(p.join(dir.path, 'a.cm2')).toString();
    final symbols = await lsp.request('textDocument/documentSymbol', {
      'textDocument': {'uri': uri},
    });
    final names = (symbols as List).map((s) => s['name']).toList();
    expect(names, contains('ScriptMode = FLAG_TALK'));
  });
}

/// Minimal LSP client: Content-Length framing over the child's stdio.
class _Lsp {
  _Lsp(this.proc) {
    proc.stdout.listen(_onBytes);
  }

  final Process proc;
  final _buffer = <int>[];
  final _pending = <int, Completer<dynamic>>{};
  final _waiting = <String, List<Completer<Map<String, dynamic>>>>{};
  var _nextId = 1;

  Future<dynamic> request(String method, Object? params) {
    final id = _nextId++;
    final c = Completer<dynamic>();
    _pending[id] = c;
    _send({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    return c.future.timeout(const Duration(seconds: 60));
  }

  void notify(String method, Object? params) {
    _send({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  Future<Map<String, dynamic>> nextNotification(String method) {
    final c = Completer<Map<String, dynamic>>();
    _waiting.putIfAbsent(method, () => []).add(c);
    return c.future.timeout(const Duration(seconds: 60));
  }

  void _send(Map<String, Object?> message) {
    // json_rpc_2 rejects an explicit `params: null`; VS Code omits the key.
    if (message['params'] == null) message.remove('params');
    final body = utf8.encode(jsonEncode(message));
    proc.stdin.add(utf8.encode('Content-Length: ${body.length}\r\n\r\n'));
    proc.stdin.add(body);
  }

  void _onBytes(List<int> bytes) {
    _buffer.addAll(bytes);
    while (true) {
      final headerEnd = _indexOf(_buffer, '\r\n\r\n'.codeUnits);
      if (headerEnd < 0) return;
      final header = ascii.decode(_buffer.sublist(0, headerEnd));
      final length = int.parse(RegExp(r'Content-Length: (\d+)').firstMatch(header)!.group(1)!);
      final bodyStart = headerEnd + 4;
      if (_buffer.length < bodyStart + length) return;
      final body = utf8.decode(_buffer.sublist(bodyStart, bodyStart + length));
      _buffer.removeRange(0, bodyStart + length);
      _dispatch(jsonDecode(body) as Map<String, dynamic>);
    }
  }

  void _dispatch(Map<String, dynamic> message) {
    if (message.containsKey('id') && (message.containsKey('result') || message.containsKey('error'))) {
      final c = _pending.remove(message['id'] as int);
      if (c == null) return;
      if (message.containsKey('error')) {
        c.completeError(StateError(message['error'].toString()));
      } else {
        c.complete(message['result']);
      }
      return;
    }
    final method = message['method'] as String?;
    if (method == null) return;
    final waiters = _waiting[method];
    if (waiters != null && waiters.isNotEmpty) {
      waiters.removeAt(0).complete(message['params'] as Map<String, dynamic>);
    }
  }

  static int _indexOf(List<int> haystack, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}
