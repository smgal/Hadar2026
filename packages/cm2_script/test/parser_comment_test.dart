import 'package:cm2_script/cm2_script.dart';
import 'package:test/test.dart';

/// 줄 끝 주석과 반쯤 친 줄. 둘 다 편집기가 매 키 입력마다 파서를 부르게
/// 되면서 드러난 것이고, 첫째는 실행에도 영향을 준다.
void main() {
  group('stripComment', () {
    test('괄호가 든 주석을 인자에서 떼어 낸다', () {
      final stmt = parseScript('Flag::Set(10) # 문(door)\n').single as CommandStatement;
      expect(stmt.command, 'Flag::Set');
      expect(stmt.args, ['10']);
    });

    test('문자열 안의 # 은 그대로 둔다', () {
      final stmt = parseScript('Talk("### Grocery # 1")\n').single as CommandStatement;
      expect(stmt.args, ['"### Grocery # 1"']);
      expect(stripComment('Map::SetTile("#", 5) # 벽'), 'Map::SetTile("#", 5) ');
    });

    test('if 조건 뒤의 주석이 조건을 망가뜨리지 않는다', () {
      final stmt = parseScript('if (On(3, 4)) # (임시)\n\tTalk("x")\n').single as IfStatement;
      expect(stmt.conditionFunc, 'On');
      expect(stmt.conditionArgs, ['3', '4']);
      expect(stmt.body, hasLength(1));
    });

    test('else 뒤에 주석이 있어도 else 로 읽는다', () {
      final stmt = parseScript(
        'if (On(3, 4))\n\tTalk("a")\nelse # 아니면\n\tTalk("b")\n',
      ).single as IfStatement;
      expect(stmt.body, hasLength(1));
      expect(stmt.elseBody, hasLength(1));
      expect(stmt.elseLine, 2);
    });

    test('주석만 있는 줄과 빈 줄은 예전처럼 건너뛴다', () {
      expect(parseScript('# 주석\n\n   # 들여쓴 주석\n'), isEmpty);
    });
  });

  group('반쯤 친 줄', () {
    test('닫는 괄호 없는 if 는 예외를 내지 않는다', () {
      final stmts = parseScript('if (On(1\n\tTalk("x")\n');
      expect(stmts.single, isA<IfStatement>());
      // 조건은 뭐가 됐든 상관없다 — 예외 없이 문장 하나로 읽히면 된다.
      // 어디가 안 닫혔는지는 편집기 쪽 진단(unclosed-condition)이 말한다.
      expect((stmts.single as IfStatement).body, hasLength(1));
    });

    test('if ( 만 있어도 예외를 내지 않고 조건이 빈 if 가 된다', () {
      final stmt = parseScript('if (\n').single as IfStatement;
      expect(stmt.conditionFunc, '');
      expect(stmt.conditionArgs, isEmpty);
    });

    test('줄 번호는 그대로 붙는다', () {
      final stmts = parseScript('Talk("a")\n\nif (On(1, 2))\n\tTalk("b")\nelse\n\tTalk("c")\n');
      expect((stmts[0] as CommandStatement).line, 0);
      final ifStmt = stmts[1] as IfStatement;
      expect(ifStmt.line, 2);
      expect(ifStmt.elseLine, 4);
      expect((ifStmt.body.single as CommandStatement).line, 3);
      expect((ifStmt.elseBody.single as CommandStatement).line, 5);
    });
  });
}
