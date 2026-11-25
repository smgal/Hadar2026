import 'dart:math';

import 'package:lore_world/lore_world.dart';

/// 정해 둔 값을 차례로 내는 난수. 규칙의 한 줄 한 줄을 겨냥해 시험한다.
class ScriptedRandom implements Random {
  ScriptedRandom(this.values);

  final List<int> values;
  int _next = 0;

  /// 지금까지 몇 번 굴렸는가.
  int get draws => _next;

  @override
  int nextInt(int max) {
    final v = values.isEmpty ? 0 : values[_next % values.length];
    _next++;
    return v % max;
  }

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => 0;
}

/// 전투사 계열 대원. 능력치는 전부 10, 레벨 1, HP 가득.
Member fighter({
  String name = 'Hero',
  int classId = ClassId.fighter,
  int level = 1,
  List<int>? abilities,
  List<int>? skills,
  String? weapon,
  String? shield,
  String? armour,
  int exp = 0,
  int trainedExp = 0,
}) {
  final m = Member(
    name: name,
    family: Family.fighter,
    classId: classId,
    level: level,
    abilities: abilities ?? [10, 10, 10, 10, 10, 10, 10, 10],
    skills: skills ?? [10, 10, 10, 10, 10, 10],
    weapon: weapon,
    shield: shield,
    armour: armour,
    baseAc: 2,
    exp: exp,
    trainedExp: trainedExp,
  );
  m.hp = m.maxHp;
  m.mp = m.maxMp;
  return m;
}

/// 마법사 계열 대원. 능력치는 전부 10, 레벨 1, HP·MP 가득.
Member mage({
  String name = 'Wiz',
  int classId = ClassId.mage,
  int level = 1,
  List<int>? abilities,
  List<int>? skills,
  int exp = 0,
  int trainedExp = 0,
}) {
  final m = Member(
    name: name,
    gender: Gender.female,
    family: Family.mage,
    classId: classId,
    level: level,
    abilities: abilities ?? [10, 10, 10, 10, 10, 10, 10, 10],
    skills: skills ?? [10, 10, 10, 10, 10, 10],
    exp: exp,
    trainedExp: trainedExp,
  );
  m.hp = m.maxHp;
  m.mp = m.maxMp;
  return m;
}

/// 주인공 한 명으로 시작하는 제3부 세계.
LoreWorld worldWith(Member protagonist, {Episode episode = Episode.ep3}) =>
    LoreWorld.newGame(episode, protagonist);
