import 'package:lore_world_text/lore_world_text.dart' show josa;

/// 스크립트 글 안의 `{...}` 를 풀어 쓴다.
///
/// | 쓰기 | 나오는 것 |
/// |---|---|
/// | `{주인공}` · `{1}` | 1번 대원 이름 |
/// | `{3}` | 3번 자리 대원 이름 |
/// | `{주인공:은/는}` | 이름 + 받침에 맞는 조사 |
/// | `{$temp}` · `{$temp:을/를}` | cm2 변수의 값 (+ 조사) |
///
/// 기획서의 대사 원고가 `{주인공}{은/는}` 으로 적혀 있어서, 옮기는 사람이
/// 문장을 `JoinString` 으로 쪼개지 않아도 되게 한 것이다.
///
/// **모르는 꼴은 그대로 둔다.** `{s}` 처럼 원고에 남아 있던 자리표가 조용히
/// 빈 글자가 되면 빠진 줄을 찾을 수 없다.
String expandTemplate(
  String text, {
  required String Function(int seat) nameOf,
  required Object? Function(String name) variable,
}) {
  if (!text.contains('{')) return text;
  return text.replaceAllMapped(_slot, (m) {
    final key = m[1]!;
    final particle = m[2];
    String? value;
    if (key == '주인공') {
      value = nameOf(1);
    } else if (key.startsWith(r'$')) {
      final v = variable(key.substring(1));
      if (v != null) value = v.toString();
    } else {
      final seat = int.tryParse(key);
      if (seat != null && seat >= 1 && seat <= 6) value = nameOf(seat);
    }
    if (value == null) return m[0]!;
    return particle == null ? value : josa(value, particle);
  });
}

final RegExp _slot = RegExp(r'\{(주인공|[1-6]|\$[A-Za-z_][A-Za-z0-9_]*)(?::([^{}]+))?\}');
