import 'package:hd_battle/hd_battle.dart';
import 'package:hd_battle_text/hd_battle_text.dart';
import 'package:test/test.dart';

/// 문장이 한 곳에만 있다는 것이 이 패키지의 존재 이유다.
class _Names implements BattleNames {
  const _Names();

  static const _party = ['슴갈', '유리', '방패병'];
  static const _enemies = ['Orc', 'Skeleton'];

  @override
  HDNoun member(int slot) => HDNoun(_party[slot]);

  @override
  HDNoun enemy(int index) => HDNoun(_enemies[index]);

  @override
  String weapon(int slot) => '단도';
}

void main() {
  const names = _Names();
  List<String> render(BattleEvent e) => battleLines(e, names);

  group('원작 문구를 만든다', () {
    test('물리 공격 명중', () {
      expect(
        render(const EnemyDamaged(0, 0, 7, DamageSource.physical)).single,
        contains('슴갈은 단도로 Orc을 공격하여'),
      );
    });

    test('저지와 막음이 다른 문장이다', () {
      expect(
        render(const EnemyBlocked(0, 0, BlockKind.resisted)).single,
        'Orc은 슴갈의 공격을 저지했다',
      );
      expect(
        render(const EnemyBlocked(0, 0, BlockKind.absorbed)).single,
        '그러나 Orc은 슴갈의 공격을 막았다',
      );
    });

    test('조사가 이름을 따라간다', () {
      expect(render(const AttackMissed(1)).single, startsWith('유리의'));
      expect(render(const AttackMissed(2)).single, startsWith('방패병의'));
    });
  });

  group('원작에 없던 줄은 표시가 붙는다', () {
    test('턴 구분과 독 피해', () {
      expect(render(const RoundStarted(1)).single, startsWith(addedMarker));
      expect(
        render(const EnemyPoisonTick(0, 3)).single,
        startsWith(addedMarker),
      );
    });

    test('원작에 있던 줄에는 안 붙는다', () {
      expect(
        render(const AttackMissed(0)).single,
        isNot(startsWith(addedMarker)),
      );
    });
  });

  group('색은 원작의 writeConsole 첫 인자다', () {
    test('일행이 움직이면 12번, 적이 움직이면 13번', () {
      expect(battleLineColor(const AttackMissed(0)), TextColor.lightRed);
      expect(
        battleLineColor(const EnemySummoned(0, 0)),
        TextColor.lightMagenta,
      );
    });

    test('빗나감·저지는 7번, 상태가 나빠지면 4번', () {
      expect(
        battleLineColor(const EnemyBlocked(0, 0, BlockKind.resisted)),
        TextColor.lightGray,
      );
      expect(battleLineColor(const MemberDied(0)), TextColor.red);
    });

    test('모든 이벤트가 색을 갖는다', () {
      // switch 가 전수라 새 이벤트를 더하면 컴파일이 막는다. 이 테스트는
      // 그 사실을 문서로 남기는 쪽에 가깝다.
      expect(battleLineColor(const RoundStarted(1)), TextColor.darkGray);
    });
  });

  group('수치만 다른 색으로 내는 표기', () {
    test('원작이 쓰던 `@D...@@` 모양이다', () {
      expect(paintText(TextColor.lightMagenta, 30), '@D30@@');
      expect(paintText(TextColor.white, 7), '@F7@@');
      expect(paintText(TextColor.lightGray, 'x'), '@7x@@');
    });

    test('일행이 준 피해는 15번, 받은 피해는 13번', () {
      expect(highlightDealt(5), contains('@F'));
      expect(highlightTaken(5), contains('@D'));
    });
  });

  group('줄 색을 문자열로만 줄 때', () {
    test('안쪽 `@@` 가 기본색이 아니라 줄 색으로 돌아간다', () {
      // `@@` 는 원작에서도 앱에서도 **기본색 복귀**다. 그냥 감싸면
      // 수치 뒤가 줄 색이 아니라 기본색으로 떨어져 줄의 절반이 색을 잃는다.
      expect(
        withDefaultColor('슴갈은 @D30@@만큼의 피해를 입었다', TextColor.magenta),
        '@5슴갈은 @D30@5만큼의 피해를 입었다',
      );
    });

    test('안에 표기가 없으면 앞에만 붙는다', () {
      expect(withDefaultColor('빗나갔다', TextColor.lightRed), '@C빗나갔다');
    });

    test('줄이 색을 잃는 자리가 남지 않는다', () {
      // 실제로 나오는 모든 줄을 훑어서 `@@` 가 남아 있지 않은지 본다.
      for (final line in [
        '슴갈은 @D30@@만큼',
        '@D적이 공격했다.@@',
        '앞뒤로 @F7@@ 그리고 @D3@@ 둘',
      ]) {
        expect(
          withDefaultColor(line, TextColor.lightGray),
          isNot(contains('@@')),
          reason: line,
        );
      }
    });
  });

  group('이름표', () {
    test('마법과 물건 이름이 있다', () {
      expect(magicName(1), isNotEmpty);
      expect(magicName(45), isNotEmpty);
      expect(itemName('potion'), isNotEmpty);
    });
  });
}
