import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart';
import 'package:test/test.dart';

void main() {
  test('질문은 열 개, 판은 둘, 답은 셋', () {
    expect(personalityQuestions.length, questionCount);
    for (var i = 0; i < questionCount; i++) {
      expect(personalityQuestions[i].length, 2, reason: '질문 ${i + 1}');
      for (var v = 0; v < 2; v++) {
        expect(questionChoices(i, v).length, 3, reason: '질문 ${i + 1}${'AB'[v]}');
      }
    }
  });

  test('원작 화면의 줄바꿈과 겹친 빈칸이 남아 있지 않다', () {
    for (final pair in personalityQuestions) {
      for (final q in pair) {
        for (final s in [q.text, ...q.choices]) {
          expect(s, isNot(contains('\n')));
          expect(s, isNot(contains('  ')));
          expect(s, isNot(contains(' ?')), reason: s);
          expect(s.trim(), s);
        }
      }
    }
  });

  test('원작 오타를 고쳤다', () {
    expect(questionText(0, 1), contains('길 앞을'));
    expect(questionChoices(0, 1)[2], contains('치울'));
    expect(questionChoices(4, 0)[0], contains('당황한'));
    expect(questionText(5, 1), contains('행동'));
  });
}
