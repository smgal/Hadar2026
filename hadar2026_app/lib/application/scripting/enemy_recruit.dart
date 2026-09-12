import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_world/hd_world.dart';

/// 적의 능력치를 사람에게 옮긴다 — cm2 `Player::AssignFromEnemyData`.
///
/// 원작의 동작 그대로다. 자리 하나를 적 데이터로 채우는 것이고, 이야기 안에서
/// 적이 일행이 되는 장면에 쓰인다.
///
/// **직업은 「불확실함」이다.** 이전 모델은 0 을 넣었고 그 번호가 「에스퍼」를
/// 뜻했는데, 원작 번호에서 0 은 `UNKNOWN` 이다(부록 Z-7). 정체를 모르는 것이
/// 맞는 답이므로 번호를 바꾸면서 뜻이 제자리를 찾는다.
///
/// 경험치 식은 원작 것이다 — `(id + 1)³ ÷ 8`.
/// 표는 **전투 쪽 것 하나**를 쓴다. RPG 가 75행을 따로 들고 있으면 두 표가
/// 갈린다 — B4-03 이 지운 중복이다.
bool assignFromEnemyData(Member m, int enemyId) {
  final data = hb.enemyTable
      .where((e) => e.legacyId == enemyId)
      .firstOrNull;
  if (data == null) return false;

  m
    ..name = data.name
    ..gender = 1
    ..clazz = CharacterClass.unknown
    ..stats = BaseStats(
      strength: data.strength,
      mentality: data.mentality,
      concentration: 0,
      endurance: data.endurance,
      // 원작이 절반으로 깎는다 — 적의 저항은 100 을 상대로 굴리고
      // 사람의 저항은 50 을 상대로 굴리기 때문이다(부록 O).
      resistance: data.resistance ~/ 2,
      agility: data.agility,
      luck: 10,
    )
    ..levels = Levels(
      physical: data.level,
      magic: data.castLevel * 3 == 0 ? 1 : data.castLevel * 3,
      esp: 1,
    )
    ..accuracy = Accuracy(
      physical: data.accuracy.isNotEmpty ? data.accuracy[0] : 0,
      magic: data.accuracy.length > 1 ? data.accuracy[1] : 0,
    )
    ..baseDefence = data.ac
    ..poison = 0
    ..unconscious = 0
    ..dead = 0
    ..experience = _experienceFor(enemyId);

  m
    ..baseMaxHitPoints = m.stats.endurance * m.levels.physical
    ..baseMaxSpellPoints = m.stats.mentality * m.levels.magic
    ..baseMaxEspPoints = m.stats.concentration * m.levels.esp;

  m
    ..hitPoints = m.baseMaxHitPoints
    ..spellPoints = m.baseMaxSpellPoints
    ..espPoints = m.baseMaxEspPoints;

  // 맨손으로 들어온다. 장비는 이야기가 준다.
  m.equipment.clear();
  return true;
}

/// 원작의 경험치 식.
int _experienceFor(int enemyId) {
  final n = enemyId + 1;
  return n * n * n ~/ 8;
}
