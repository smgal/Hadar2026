/// 명사 + 위치별 조사 묶음.
///
/// 위치별로 4종의 조사를 미리 만들어 둔다.
/// - [sub1] : 보조사 (은/는)
/// - [sub2] : 주격조사 (이/가)
/// - [obj]  : 목적격조사 (을/를)
/// - [conj] : 접속/공동격조사 (와/과)
///
/// 지금은 한국어 종성 규칙만 구현돼 있다. 비-한글로 끝나는 명사는
/// 영어 어미가 자음/모음 중 어느 쪽인지로 종성을 추정한다.
/// 시스템 언어 개념이 들어오면 이 클래스의 내부 규칙만 갈아끼운다.
class HDNoun {
  final String text;
  final String sub1;
  final String sub2;
  final String obj;
  final String conj;

  HDNoun(this.text)
      : sub1 = _pick(text, '은', '는'),
        sub2 = _pick(text, '이', '가'),
        obj = _pick(text, '을', '를'),
        conj = _pick(text, '과', '와');

  const HDNoun._raw(this.text, this.sub1, this.sub2, this.obj, this.conj);

  static const HDNoun empty = HDNoun._raw('', '', '', '', '');

  bool get isEmpty => text.isEmpty;
  bool get isNotEmpty => text.isNotEmpty;

  @override
  String toString() => text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is HDNoun && other.text == text);

  @override
  int get hashCode => text.hashCode;

  static String _pick(String text, String withJong, String withoutJong) {
    if (text.isEmpty) return '';
    return _hasJongsung(text) ? withJong : withoutJong;
  }

  static bool _hasJongsung(String s) {
    final last = s.runes.last;

    // 한글 음절 (가 ~ 힣) 종성 비트.
    if (last >= 0xAC00 && last <= 0xD7A3) {
      return ((last - 0xAC00) % 28) > 0;
    }

    // 비-한글: 영어 어미 휴리스틱. 모음(+w)으로 끝나면 종성 없음으로 간주.
    final lower = String.fromCharCode(last).toLowerCase();
    if ('aeiouw'.contains(lower)) return false;
    return true;
  }
}
