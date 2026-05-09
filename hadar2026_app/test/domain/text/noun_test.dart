import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/domain/text/noun.dart';

void main() {
  group('HDNoun (Korean jongsung)', () {
    test('한글 종성 있는 명사: 은/이/을/과', () {
      final n = HDNoun('슴갈');
      expect(n.sub1, '은');
      expect(n.sub2, '이');
      expect(n.obj, '을');
      expect(n.conj, '과');
    });

    test('한글 종성 없는 명사: 는/가/를/와', () {
      final n = HDNoun('유리');
      expect(n.sub1, '는');
      expect(n.sub2, '가');
      expect(n.obj, '를');
      expect(n.conj, '와');
    });

    test('빈 문자열은 모든 조사가 빈 문자열', () {
      final n = HDNoun('');
      expect(n.text, '');
      expect(n.isEmpty, true);
      expect(n.isNotEmpty, false);
      expect(n.sub1, '');
      expect(n.sub2, '');
      expect(n.obj, '');
      expect(n.conj, '');
    });

    test('한 글자 명사도 종성 규칙 적용', () {
      expect(HDNoun('곰').sub1, '은'); // 종성 ㅁ
      expect(HDNoun('소').sub1, '는'); // 종성 없음
    });

    test('영어 자음 어미는 종성 있음으로 추정', () {
      final n = HDNoun('Orc');
      expect(n.sub1, '은');
      expect(n.sub2, '이');
      expect(n.obj, '을');
      expect(n.conj, '과');
    });

    test('영어 모음 어미는 종성 없음으로 추정', () {
      final n = HDNoun('Goblin');
      // 'n' → 자음
      expect(n.sub1, '은');

      final m = HDNoun('Salamander');
      // 'r' → 자음
      expect(m.sub1, '은');

      final v = HDNoun('Mummy');
      // 'y' → 자음 휴리스틱(아닌 값) — 'y'는 모음 목록에 없으므로 자음 처리
      expect(v.sub1, '은');

      final ko = HDNoun('Kobo');
      // 'o' → 모음
      expect(ko.sub1, '는');
    });

    test('toString은 text를 반환', () {
      expect(HDNoun('슴갈').toString(), '슴갈');
      expect('${HDNoun('유리')}', '유리');
    });

    test('동일 text는 동치이며 같은 hashCode', () {
      final a = HDNoun('곰');
      final b = HDNoun('곰');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('empty 상수는 빈 명사', () {
      expect(HDNoun.empty.text, '');
      expect(HDNoun.empty.isEmpty, true);
      expect(HDNoun.empty, equals(HDNoun('')));
    });
  });
}
