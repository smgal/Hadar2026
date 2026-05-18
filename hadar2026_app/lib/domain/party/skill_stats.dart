class SkillStats {
  int physical;
  int magic;
  int esp;

  SkillStats({this.physical = 0, this.magic = 0, this.esp = 0});

  Map<String, dynamic> toJson() =>
      {'physical': physical, 'magic': magic, 'esp': esp};

  factory SkillStats.fromJson(Map<String, dynamic> j) => SkillStats(
        physical: j['physical'] ?? 0,
        magic: j['magic'] ?? 0,
        esp: j['esp'] ?? 0,
      );
}
