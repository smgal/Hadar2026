import 'dart:io';

import 'package:cm2_lsp/src/analyzer.dart';
import 'package:cm2_lsp/src/index.dart';
import 'package:cm2_lsp/src/symbol_table.dart';
import 'package:cm2_lsp/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 진단이 실제로 무엇을 잡는지. 각 시험은 잘못된 줄 하나를 심고 그 줄에
/// 그 코드의 진단이 붙는지 본다.
void main() {
  late SymbolTable symbols;
  late Directory dir;
  late Workspace ws;

  setUpAll(() async {
    symbols = SymbolTable.fromJson(
      File('lib/data/cm2_symbols.json').readAsStringSync(),
    );
  });

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cm2_lsp_test_');
    ws = Workspace();
    File(p.join(dir.path, 'const.cm2')).writeAsStringSync('''
variable(FLAG_MAP)
variable(FLAG_TALK)
FLAG_MAP.assign(0)
FLAG_TALK.assign(1)
variable(BATTLERESULT_WIN)
BATTLERESULT_WIN.assign(1)
''');
    File(p.join(dir.path, 'flag4ep1.cm2')).writeAsStringSync('''
variable(GFD0_IS_FIRST)
GFD0_IS_FIRST.assign(0)
variable(GFD1_WALL_REMOVER_USED)
GFD1_WALL_REMOVER_USED.assign(10)
variable(GFD1_KEY_USED)
GFD1_KEY_USED.assign(11)
''');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  List<Finding> run(String name, String text) {
    final path = p.join(dir.path, name);
    File(path).writeAsStringSync(text);
    return analyze(
      path: path,
      index: Cm2Index.build(text),
      symbols: symbols,
      workspace: ws,
    );
  }

  Iterable<Finding> code(List<Finding> f, String c) => f.where((x) => x.code == c);

  test('깨끗한 맵 스크립트에는 오류가 없다', () {
    final f = run('Map016.cm2', '''
include("const.cm2")
include("flag4ep1.cm2")

variable(temp)

if (Equal(ScriptMode(), FLAG_TALK))
\tif (On(14, 30))
\t\tEvent::Override()
\t\tif (Not(Flag::IsSet(GFD0_IS_FIRST)))
\t\t\tTalk("처음 뵙겠소.")
\t\t\tFlag::Set(GFD0_IS_FIRST)
\t\telse
\t\t\tSelect::Init()
\t\t\tSelect::Add("무엇을 하겠소?")
\t\t\tSelect::Add("싸운다")
\t\t\tSelect::Add("돌아간다")
\t\t\tSelect::Run()
\t\t\ttemp.assign(Select::Result())
\t\t\tif (Equal(temp, 1))
\t\t\t\tBattle::Init()
\t\t\t\tBattle::RegisterEnemy(26)
\t\t\t\tBattle::ShowEnemy()
\t\t\t\tBattle::Start(0)
\t\t\t\tif (Equal(Battle::Result(), BATTLERESULT_WIN))
\t\t\t\t\tParty::PlusGold(80)
''');
    expect(f.where((x) => x.severity == Severity.error), isEmpty, reason: f.join('\n'));
    expect(f.where((x) => x.severity == Severity.warning), isEmpty, reason: f.join('\n'));
  });

  test('모르는 명령과 함수를 그 줄에서 잡는다', () {
    final f = run('a.cm2', '''
include("const.cm2")
Tallk("안녕")
if (Flag::IsSett(3))
\tTalk("x")
''');
    final cmd = code(f, 'unknown-command').single;
    expect(cmd.span.line, 1);
    expect(cmd.span.start, 0);
    expect(cmd.span.end, 5);
    final fn = code(f, 'unknown-function').single;
    expect(fn.span.line, 2);
    expect(fn.span.start, 4);
  });

  test('함수를 명령 자리에 쓰면 그렇게 말해 준다', () {
    final f = run('a.cm2', 'Flag::IsSet(3)\n');
    final only = code(f, 'unknown-command').single;
    expect(only.message, contains('함수'));
  });

  test('선언되지 않은 이름은 오류, include 를 못 찾으면 안내로 낮춘다', () {
    final strict = run('a.cm2', '''
include("const.cm2")
if (Equal(ScriptMode(), FLAG_SIGN))
\tTalk("x")
''');
    final u = code(strict, 'undeclared-name').single;
    expect(u.severity, Severity.error);
    expect(u.span.line, 1);
    expect(u.message, contains('"FLAG_SIGN"'));

    final loose = run('b.cm2', '''
include("nowhere.cm2")
if (Equal(ScriptMode(), FLAG_SIGN))
\tTalk("x")
''');
    expect(code(loose, 'include-not-found').single.span.line, 0);
    expect(code(loose, 'undeclared-name').single.severity, Severity.information);
  });

  test('변수 이름 불일치는 두 줄 다 표시된다 (flag4ep1.cm2:42 의 사고)', () {
    final f = run('flag4x.cm2', '''
variable(GFD1_OPEN_DOWN_STAIRS)
GFD1_OPEN_ODD_WALL.assign(15)
''');
    expect(code(f, 'unassigned-variable').single.span.line, 0);
    expect(code(f, 'assign-undeclared').single.span.line, 1);
  });

  test('쓰지 않는 선언은 흐린 표시, 읽기만 하는 선언은 경고', () {
    final f = run('a.cm2', '''
variable(unused)
variable(readonly)
if (Equal(readonly, 1))
\tTalk("x")
''');
    final unused = code(f, 'unused-variable').single;
    expect(unused.span.line, 0);
    expect(unused.severity, Severity.hint);
    final readonly = code(f, 'unassigned-variable').single;
    expect(readonly.span.line, 1);
    expect(readonly.severity, Severity.warning);
  });

  test('flag 파일에서 같은 이름에 두 번 대입하면 값 없는 이웃 선언이 그 오타를 가리킨다', () {
    final f = run('flag4y.cm2', '''
variable(GFD1_OPEN_ODD_WALL)
GFD1_OPEN_ODD_WALL.assign(14)
variable(GFD1_OPEN_DOWN_STAIRS)
GFD1_OPEN_ODD_WALL.assign(15)
''');
    final w = code(f, 'unassigned-variable').single;
    expect(w.span.line, 2);
    expect(w.message, contains('4행의 "GFD1_OPEN_ODD_WALL.assign"'));
  });

  test('.Equal 왼쪽의 선언 없는 이름을 잡는다', () {
    final f = run('a.cm2', '''
if (nosuch.Equal(1))
\tTalk("x")
if (Equal(nosuch2.Equal(2), 1))
\tTalk("y")
''');
    final u = code(f, 'undeclared-name').toList();
    expect(u.map((x) => x.span.line), [0, 2]);
    expect(u.map((x) => x.severity).toSet(), {Severity.error});
  });

  test('괄호 없이 쓴 함수는 그렇게 말해 준다', () {
    final f = run('a.cm2', '''
if (Flag::IsSet)
\tTalk("x")
if (Equal(Party::PosX, 1))
\tTalk("y")
''');
    final m = code(f, 'missing-parentheses').toList();
    expect(m.map((x) => x.span.line), [0, 2]);
    expect(m.first.message, contains('Flag::IsSet()'));
    expect(code(f, 'undeclared-name'), isEmpty);
  });

  test('쉼표 빠짐·하이픈·안 닫힌 괄호는 읽을 수 없는 인자', () {
    final f = run('a.cm2', '''
include("flag4ep1.cm2")
if (Flag::IsSet(GFD0_IS_FIRST GFD0_IS_FIRST))
\tTalk("x")
Flag::Set(GFD0-IS_FIRST)
if (Not(On(1))
\tTalk("z")
''');
    expect(code(f, 'malformed-argument').map((x) => x.span.line), [1, 3, 4]);
    expect(code(f, 'undeclared-name'), isEmpty);
  });

  test('닫히지 않은 if 는 오류이고 예외가 아니다', () {
    final f = run('a.cm2', 'if (On(1\n\tTalk("x")\n');
    expect(code(f, 'unclosed-condition').single.span.line, 0);
  });

  test('들여쓰기가 어긋난 else 는 양쪽이 다 실행된다고 알린다', () {
    final f = run('a.cm2', 'if (On(1, 1))\n\tTalk("a")\n else\n\tTalk("b")\n');
    expect(code(f, 'else-not-recognized').single.span.line, 2);
    expect(code(f, 'unknown-command'), isEmpty);
  });

  test('블록 안의 variable 은 매번 0 으로 돌아간다고 경고한다', () {
    final f = run('a.cm2', 'if (On(1, 1))\n\tvariable(count)\n\tcount.add(1)\n');
    expect(code(f, 'nested-variable').single.span.line, 1);
  });

  test('variable 없이 .assign 만 한 이름을 읽는 것은 오류가 아니라 경고', () {
    final f = run('a.cm2', 'temp.assign(1)\nif (Equal(temp, 1))\n\tTalk("x")\n');
    expect(code(f, 'assign-undeclared').single.span.line, 0);
    final u = code(f, 'undeclared-name').single;
    expect(u.span.line, 1);
    expect(u.severity, Severity.warning);
    expect(f.where((x) => x.severity == Severity.error), isEmpty);
  });

  test('주석 안의 괄호는 인자를 망가뜨리지 않는다', () {
    final f = run(
      'a.cm2',
      'include("flag4ep1.cm2")\nFlag::Set(GFD0_IS_FIRST) # 문(door)\nif (On(3, 4)) # (임시)\n\tEvent::Override()\n\tTalk("x")\n',
    );
    expect(f.where((x) => x.severity != Severity.hint), isEmpty, reason: f.join('\n'));
    final handler = Cm2Index.build('if (On(3, 4)) # (임시)\n\tTalk("x")\n').handlers.single;
    expect(handler.condition, 'On(3, 4)');
  });

  test('Event::Override 힌트는 블록이 무엇이든 하면 낸다', () {
    final f = run('a.cm2', 'include("flag4ep1.cm2")\nif (On(3, 4))\n\tFlag::Reset(GFD0_IS_FIRST)\n\tWarpPrevPos()\n');
    expect(code(f, 'missing-event-override').single.span.line, 1);
  });

  test('블록 안 include 의 상수도 파일 전체에서 보인다 (정해 둔 기본값)', () {
    File(p.join(dir.path, 'quest1.cm2')).writeAsStringSync('variable(Q1_STEP)\nQ1_STEP.assign(60)\n');
    final f = run('a.cm2', '''
if (On(3, 4))
\tinclude("quest1.cm2")
if (On(5, 6))
\tif (Flag::IsSet(Q1_STEP))
\t\tTalk("x")
''');
    expect(code(f, 'undeclared-name'), isEmpty, reason: f.join('\n'));
    expect(code(f, 'include-not-found'), isEmpty);
  });

  test('인자 수가 모자라면 오류, 많으면 경고', () {
    final f = run('a.cm2', '''
Map::ChangeTile(1, 2)
Talk("a", "b")
''');
    expect(code(f, 'too-few-arguments').single.span.line, 0);
    expect(code(f, 'too-many-arguments').single.span.line, 1);
  });

  test('없는 속성 이름은 오류, 장비에서 계산되는 이름에 쓰면 경고', () {
    final f = run('a.cm2', '''
if (Equal(Player::GetAttribute(6, "_name"), "Mad Joe"))
\tPlayer::ChangeAttribute(6, "ac", 0)
''');
    final unknown = code(f, 'unknown-attribute').single;
    expect(unknown.span.line, 0);
    expect(unknown.message, contains('_name'));
    expect(code(f, 'retired-attribute').single.span.line, 1);
  });

  test('생 숫자 플래그: 이름 있는 번호는 경고, 없는 번호는 안내, 범위 밖은 오류', () {
    final f = run('menace.cm2', '''
if (Not(Flag::IsSet(10)))
\tFlag::Set(10)
Flag::Set(77)
Flag::Set(300)
''');
    final collisions = code(f, 'flag-number-collision').toList();
    expect(collisions.map((c) => c.span.line), [0, 1]);
    expect(collisions.first.message, contains('GFD1_WALL_REMOVER_USED'));
    expect(code(f, 'flag-number-unnamed').single.span.line, 2);
    expect(code(f, 'flag-out-of-range').single.span.line, 3);
  });

  test('flag 파일 안에서 같은 번호를 두 이름이 쓰면 둘 다 경고 (다른 flag 파일도 본다)', () {
    final f = run('flag4quest1.cm2', '''
variable(Q1_ACCEPTED)
Q1_ACCEPTED.assign(60)
variable(Q1_DONE)
Q1_DONE.assign(60)
variable(Q1_CLASH)
Q1_CLASH.assign(11)
''');
    final dups = code(f, 'flag-duplicate-number').toList();
    expect(dups.map((d) => d.span.line).toSet(), {1, 3, 5});
    expect(dups.firstWhere((d) => d.span.line == 5).message, contains('GFD1_KEY_USED'));
  });

  test('전투를 시작하고 결과를 안 읽으면 경고', () {
    final f = run('a.cm2', '''
Battle::Init()
Battle::RegisterEnemy(26)
Battle::Start(0)
''');
    expect(code(f, 'battle-result-unread').single.span.line, 2);
  });

  test('On 블록에 Event::Override 가 없으면 흐린 표시', () {
    final f = run('a.cm2', '''
if (On(3, 4))
\tTalk("x")
if (On(5, 6))
\tEvent::Override()
\tTalk("y")
''');
    expect(code(f, 'missing-event-override').single.span.line, 0);
    final off = analyze(
      path: p.join(dir.path, 'a.cm2'),
      index: Cm2Index.build('if (On(3, 4))\n\tTalk("x")\n'),
      symbols: symbols,
      workspace: ws,
      options: const AnalyzeOptions(eventOverrideHint: false),
    );
    expect(code(off, 'missing-event-override'), isEmpty);
  });

  test('최상위 대입이 블록 안에서도 바뀌는 이름이면 경고', () {
    final f = run('a.cm2', '''
variable(stage)
stage.assign(0)
if (On(1, 1))
\tstage.assign(1)
''');
    expect(code(f, 'top-level-assign-resets').single.span.line, 1);
  });

  test('탭과 공백이 섞인 줄과 파일 안의 소수 들여쓰기를 표시한다', () {
    final f = run('a.cm2', '''
if (On(1, 1))
\tTalk("a")
\tTalk("b")
 \tTalk("c")
    Talk("d")
''');
    expect(code(f, 'mixed-indent').single.span.line, 3);
    expect(code(f, 'indent-style-inconsistent').single.span.line, 4);
  });

  test('문자열 안의 괄호와 이름은 코드로 보지 않는다', () {
    final f = run('a.cm2', '''
Talk("Lord Ahn(로어의 주인) 은 Equal(x) 를 모른다")
''');
    expect(code(f, 'unknown-function'), isEmpty);
    expect(code(f, 'undeclared-name'), isEmpty);
  });

  group('출하 스크립트', () {
    final assets = Directory(
      p.normalize(p.join(Directory.current.path, '../../../hadar2026_app/assets')),
    );
    final present = assets.existsSync();

    test('flag4ep1.cm2 의 이름끼리는 번호가 겹치지 않는다 — 상대 경로 assetsDir 로도', () {
      final file = File(p.join(assets.path, 'flag4ep1.cm2'));
      for (final assetsDir in [assets.path, '../../../hadar2026_app/assets']) {
        final findings = analyze(
          path: file.path,
          index: Cm2Index.build(file.readAsStringSync()),
          symbols: symbols,
          workspace: Workspace(assetsDir: assetsDir),
        );
        expect(
          code(findings, 'flag-duplicate-number'),
          isEmpty,
          reason: 'assetsDir=$assetsDir\n${findings.join('\n')}',
        );
      }
    }, skip: present ? false : 'hadar2026_app/assets 가 없다');

    test('menace.cm2 의 플래그 10 번 충돌을 잡는다 (플래그 표가 찾은 그 충돌)', () {
      final file = File(p.join(assets.path, 'menace.cm2'));
      final findings = analyze(
        path: file.path,
        index: Cm2Index.build(file.readAsStringSync()),
        symbols: symbols,
        workspace: Workspace(assetsDir: assets.path),
      );
      final ten = findings.where(
        (f) => f.code == 'flag-number-collision' && f.message.contains('번호 10 '),
      );
      expect(ten, isNotEmpty, reason: findings.join('\n'));
    }, skip: present ? false : 'hadar2026_app/assets 가 없다');
  });
}

