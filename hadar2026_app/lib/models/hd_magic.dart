class HDMagic {
  final int index;
  final String name;
  final String josaSub1; // 은/는
  final String josaObj; // 을/를
  final String josaWith; // 과/와

  const HDMagic(
    this.index,
    this.name,
    this.josaSub1,
    this.josaObj,
    this.josaWith,
  );
}

class HDMagicMap {
  static final List<HDMagic> _magics = [
    // Attack Spells (1~18)
    const HDMagic(1, "마법 화살", "은", "을", "과"),
    const HDMagic(2, "마법 화구", "는", "를", "와"),
    const HDMagic(3, "마법 단창", "은", "을", "과"),
    const HDMagic(4, "독 바늘", "은", "을", "과"),
    const HDMagic(5, "맥동 광선", "은", "을", "과"),
    const HDMagic(6, "직격 뇌전", "은", "을", "과"),
    const HDMagic(7, "공기 폭풍", "은", "을", "과"),
    const HDMagic(8, "열선 파동", "은", "을", "과"),
    const HDMagic(9, "초음파", "는", "를", "와"),
    const HDMagic(10, "초냉기", "는", "를", "와"),
    const HDMagic(11, "인공 지진", "은", "을", "과"),
    const HDMagic(12, "차원 이탈", "은", "을", "과"),
    const HDMagic(13, "독", "은", "을", "과"),
    const HDMagic(14, "기술 무력화", "는", "를", "와"),
    const HDMagic(15, "방어 무력화", "는", "를", "와"),
    const HDMagic(16, "능력 저하", "는", "를", "와"),
    const HDMagic(17, "마법 불능", "은", "을", "과"),
    const HDMagic(18, "탈 초인화", "는", "를", "와"),

    // Heal Spells (19~32)
    const HDMagic(19, "한명 치료", "는", "를", "와"),
    const HDMagic(20, "한명 독 제거", "는", "를", "와"),
    const HDMagic(21, "한명 치료와 독제거", "는", "를", "와"),
    const HDMagic(22, "한명 의식 돌림", "은", "을", "과"),
    const HDMagic(23, "한명 부활", "은", "을", "과"),
    const HDMagic(24, "한명 치료와 독제거와 의식돌림", "은", "을", "과"),
    const HDMagic(25, "한명 복합 치료", "는", "를", "와"),
    const HDMagic(26, "모두 치료", "는", "를", "와"),
    const HDMagic(27, "모두 독 제거", "는", "를", "와"),
    const HDMagic(28, "모두 치료와 독제거", "는", "를", "와"),
    const HDMagic(29, "모두 의식 돌림", "은", "을", "과"),
    const HDMagic(30, "모두 치료와 독제거와 의식돌림", "은", "을", "과"),
    const HDMagic(31, "모두 부활", "은", "을", "과"),
    const HDMagic(32, "모두 복합 치료", "는", "를", "와"),

    // Phenomenon Spells (33~39)
    const HDMagic(33, "마법의 횃불", "은", "을", "과"),
    const HDMagic(34, "공중 부상", "은", "을", "과"),
    const HDMagic(35, "물위를 걸음", "은", "을", "과"),
    const HDMagic(36, "늪위를 걸음", "은", "을", "과"),
    const HDMagic(37, "기화 이동", "은", "을", "과"),
    const HDMagic(38, "지형 변화", "는", "를", "와"),
    const HDMagic(39, "공간 이동", "은", "을", "과"),

    // ESP abilities (40~44, technically "식량 제조" is 40? Let's check: 33 is Magic Torch, so 40 is 식량 제조. Let's list exactly 40-45)
    const HDMagic(40, "식량 제조", "는", "를", "와"),
    const HDMagic(41, "투시", "는", "를", "와"),
    const HDMagic(42, "예언", "은", "을", "과"),
    const HDMagic(43, "독심", "은", "을", "과"),
    const HDMagic(44, "천리안", "은", "을", "과"),
    const HDMagic(45, "염력", "은", "을", "과"),
  ];

  static HDMagic getMagic(int index) {
    return _magics.firstWhere(
      (m) => m.index == index,
      orElse: () => HDMagic(index, "알 수 없는 마법", "은", "을", "과"),
    );
  }
}
