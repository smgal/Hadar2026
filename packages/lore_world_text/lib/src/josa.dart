/// 받침에 따라 조사를 고른다.
///
/// ```
/// josa('카노푸스', '은/는')  // 카노푸스는
/// josa('알골', '으로/로')    // 알골로   (ㄹ 받침은 '로')
/// josa('Joe', '이/가')       // Joe가
/// ```
///
/// [pair] 의 순서는 상관없다 — 받침 뒤에 오는 꼴은 글자로 알 수 있다.
String josa(String word, String pair) => '$word${particle(word, pair)}';

/// [josa] 의 조사만.
String particle(String word, String pair) {
  final parts = pair.split('/');
  if (parts.length != 2) return pair;
  if (word.isEmpty) return parts[1];
  final a = parts[0], b = parts[1];
  final aAfterConsonant =
      _afterConsonant.contains(a) ||
      (!_afterConsonant.contains(b) && a.length > b.length);
  final afterConsonant = aAfterConsonant ? a : b;
  final afterVowel = aAfterConsonant ? b : a;
  final jong = _jongsung(word);
  if (afterConsonant == '으로' && jong == 8) return afterVowel;
  return jong > 0 ? afterConsonant : afterVowel;
}

/// 받침 뒤에 붙는 꼴. 여기 없는 쌍은 긴 쪽을 받침 뒤 꼴로 본다.
const Set<String> _afterConsonant = {'은', '이', '을', '과', '으로', '아', '이여'};

/// 마지막 글자의 종성 번호(0 = 받침 없음). 한글이 아니면 소리를 어림한다.
int _jongsung(String s) {
  final runes = s.runes.where((r) => r != 0x20 && r != 0x2E).toList();
  if (runes.isEmpty) return 0;
  final last = runes.last;
  if (last >= 0xAC00 && last <= 0xD7A3) return (last - 0xAC00) % 28;
  final ch = String.fromCharCode(last).toLowerCase();
  // 끝의 r 은 소리 나지 않는 쪽으로 읽는다 (Jr. → 주니어).
  if ('aeiouwyr'.contains(ch)) return 0;
  if (ch == 'l') return 8;
  if (RegExp(r'[0-9]').hasMatch(ch)) {
    // 숫자는 읽는 소리를 따른다: 1 일 · 7 칠 · 8 팔 → ㄹ, 0 영 · 3 삼 · 6 육.
    return switch (ch) {
      '1' || '7' || '8' => 8,
      '0' || '3' || '6' => 1,
      _ => 0,
    };
  }
  return 1;
}
