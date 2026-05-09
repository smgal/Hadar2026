import '../text/noun.dart';

class HDMagic {
  final int index;
  final HDNoun name;

  HDMagic(this.index, String name) : name = HDNoun(name);
}

class HDMagicMap {
  static final List<HDMagic> _magics = [
    // Attack Spells (1~18)
    HDMagic(1, "마법 화살"),
    HDMagic(2, "마법 화구"),
    HDMagic(3, "마법 단창"),
    HDMagic(4, "독 바늘"),
    HDMagic(5, "맥동 광선"),
    HDMagic(6, "직격 뇌전"),
    HDMagic(7, "공기 폭풍"),
    HDMagic(8, "열선 파동"),
    HDMagic(9, "초음파"),
    HDMagic(10, "초냉기"),
    HDMagic(11, "인공 지진"),
    HDMagic(12, "차원 이탈"),
    HDMagic(13, "독"),
    HDMagic(14, "기술 무력화"),
    HDMagic(15, "방어 무력화"),
    HDMagic(16, "능력 저하"),
    HDMagic(17, "마법 불능"),
    HDMagic(18, "탈 초인화"),

    // Heal Spells (19~32)
    HDMagic(19, "한명 치료"),
    HDMagic(20, "한명 독 제거"),
    HDMagic(21, "한명 치료와 독제거"),
    HDMagic(22, "한명 의식 돌림"),
    HDMagic(23, "한명 부활"),
    HDMagic(24, "한명 치료와 독제거와 의식돌림"),
    HDMagic(25, "한명 복합 치료"),
    HDMagic(26, "모두 치료"),
    HDMagic(27, "모두 독 제거"),
    HDMagic(28, "모두 치료와 독제거"),
    HDMagic(29, "모두 의식 돌림"),
    HDMagic(30, "모두 치료와 독제거와 의식돌림"),
    HDMagic(31, "모두 부활"),
    HDMagic(32, "모두 복합 치료"),

    // Phenomenon Spells (33~39)
    HDMagic(33, "마법의 횃불"),
    HDMagic(34, "공중 부상"),
    HDMagic(35, "물위를 걸음"),
    HDMagic(36, "늪위를 걸음"),
    HDMagic(37, "기화 이동"),
    HDMagic(38, "지형 변화"),
    HDMagic(39, "공간 이동"),

    // ESP abilities (40~45)
    HDMagic(40, "식량 제조"),
    HDMagic(41, "투시"),
    HDMagic(42, "예언"),
    HDMagic(43, "독심"),
    HDMagic(44, "천리안"),
    HDMagic(45, "염력"),
  ];

  static HDMagic getMagic(int index) {
    return _magics.firstWhere(
      (m) => m.index == index,
      orElse: () => HDMagic(index, "알 수 없는 마법"),
    );
  }
}
