import 'dart:math';

import '../contract/outcome.dart';
import '../data/class_table.dart';
import '../domain/enums.dart';
import '../domain/member.dart';

/// 성격 질문은 열 개, 답은 1~3.
const int questionCount = 10;

/// 민첩성·정확성·행운에 나눠 주는 점수.
const int freePoints = 40;

/// 여섯 기술치의 합. 모두 10 에서 시작하고 서로 옮기기만 한다.
const int skillPoints = 60;

const Ability _str = Ability.strength;
const Ability _men = Ability.mentality;
const Ability _con = Ability.concentration;
const Ability _end = Ability.endurance;
const Ability _res = Ability.resistance;

/// 질문마다 답 1·2·3 이 올려 주는 능력치(제7장 7.5).
///
/// 다섯 능력치에서 셋을 고르는 열 가지 조합이 전부 한 번씩 나온다. 그래서
/// 한 능력치가 받을 수 있는 점수는 0~6 이다.
const List<List<Ability>> questionAbilities = [
  [_str, _men, _con],
  [_str, _men, _end],
  [_str, _men, _res],
  [_str, _con, _end],
  [_str, _con, _res],
  [_str, _end, _res],
  [_men, _con, _end],
  [_men, _con, _res],
  [_men, _end, _res],
  [_con, _end, _res],
];

/// 점수(0~6) → 능력치.
const List<int> scoreToAbility = [5, 7, 11, 14, 17, 19, 20];

/// 능력치의 보통 상한. 이야기 사건으로는 넘을 수 있다.
const int abilityCap = 20;

/// 성별 보너스.
const int genderBonus = 4;

/// 질문마다 A·B 중 어느 쪽을 낼지 고른다(0 = A, 1 = B).
List<int> pickQuestionVariants(Random rng) => [
  for (var i = 0; i < questionCount; i++) rng.nextInt(2),
];

/// 답 열 개 → 다섯 능력치의 점수(체력·정신력·집중력·인내력·저항력 순).
///
/// 답이 모자라거나 범위를 벗어나면 null.
List<int>? scoreAnswers(List<int> answers) {
  if (answers.length != questionCount) return null;
  final scores = List<int>.filled(5, 0);
  for (var q = 0; q < questionCount; q++) {
    final a = answers[q];
    if (a < 1 || a > 3) return null;
    scores[questionAbilities[q][a - 1].index8]++;
  }
  return scores;
}

/// 계열 결정. **성별 보너스를 더하기 전의** 값으로 판단한다.
///
/// 체력 > 정신력이면 전투사, 반대면 마법사. 같으면 인내력과 집중력을
/// 견주고, 그것도 같으면 마법사.
Family decideFamily({
  required int strength,
  required int mentality,
  required int concentration,
  required int endurance,
}) {
  if (strength > mentality) return Family.fighter;
  if (mentality > strength) return Family.mage;
  if (endurance > concentration) return Family.fighter;
  return Family.mage;
}

/// 성별 보너스 +4 를 더한다. 20 을 넘는 만큼은 다음 능력치로 흘러간다.
///
/// 남성: 체력 → 인내력 → 저항력. 여성: 정신력 → 집중력 → 저항력.
/// 마지막에도 넘치면 버린다. `five` 는 체력·정신력·집중력·인내력·저항력 순.
List<int> applyGenderBonus(List<int> five, Gender gender) {
  final out = List<int>.of(five);
  final chain = switch (gender) {
    Gender.male => const [0, 3, 4],
    Gender.female => const [1, 2, 4],
    Gender.neutral => const <int>[],
  };
  var carry = genderBonus;
  for (final i in chain) {
    if (carry <= 0) break;
    final room = abilityCap - out[i];
    final add = carry < room ? carry : (room < 0 ? 0 : room);
    out[i] += add;
    carry -= add;
  }
  return out;
}

/// 캐릭터 생성 화면이 보여 주는 것.
final class CreationPreview {
  const CreationPreview({
    required this.scores,
    required this.baseAbilities,
    required this.abilities,
    required this.family,
  });

  /// 다섯 능력치가 받은 점수(0~6, 합 10).
  final List<int> scores;

  /// 성별 보너스를 더하기 전의 다섯 능력치.
  final List<int> baseAbilities;

  /// 성별 보너스를 더한 다섯 능력치.
  final List<int> abilities;
  final Family family;

  /// 화면의 「체력 지수」 = 인내력 × 10.
  int get hp => abilities[Ability.endurance.index8] * 10;

  /// 화면의 「마법 지수」 = 정신력 × 10. 마법사만.
  int get mp =>
      family == Family.mage ? abilities[Ability.mentality.index8] * 10 : 0;

  /// 처음의 기술치 — 여섯 모두 10.
  List<int> get startingSkills => const [10, 10, 10, 10, 10, 10];
}

/// 답 열 개와 성별로 능력치와 계열을 낸다. 입력이 틀렸으면 null.
CreationPreview? previewCreation({
  required List<int> answers,
  required Gender gender,
}) {
  if (gender == Gender.neutral) return null;
  final scores = scoreAnswers(answers);
  if (scores == null) return null;
  final base = [for (final s in scores) scoreToAbility[s]];
  return CreationPreview(
    scores: scores,
    baseAbilities: base,
    abilities: applyGenderBonus(base, gender),
    family: decideFamily(
      strength: base[0],
      mentality: base[1],
      concentration: base[2],
      endurance: base[3],
    ),
  );
}

/// 지금 기술치로 고를 수 있는 계급 번호. 화면이 밝게 칠할 줄이다.
List<int> eligibleClassIds(Family family, List<int> skills) =>
    skills.length != 6
    ? const []
    : [for (final c in eligibleClasses(family, skills)) c.id];

/// 캐릭터 생성에 넣는 것 전부.
final class CreationInput {
  const CreationInput({
    required this.name,
    required this.gender,
    required this.answers,
    required this.agility,
    required this.accuracy,
    required this.luck,
    required this.skills,
    required this.classId,
  });

  final String name;
  final Gender gender;

  /// 답 열 개(각 1~3).
  final List<int> answers;

  /// 40점을 셋에 남김없이 나눈다(각 0~20).
  final int agility;
  final int accuracy;
  final int luck;

  /// 기술치 여섯(합 60, 각 0 이상).
  final List<int> skills;
  final int classId;
}

/// 생성 결과. 거절이면 [member] 가 없다.
final class CreationResult {
  const CreationResult.created(Member this.member, CreationPreview this.preview)
    : refusal = null;
  const CreationResult.refused(RefusalReason this.refusal)
    : member = null,
      preview = null;

  final RefusalReason? refusal;
  final Member? member;
  final CreationPreview? preview;

  bool get ok => refusal == null;
}

/// 이름의 폭. 한글 한 자는 2, 영문·기호 한 자는 1 로 센다.
int nameWidth(String name) {
  var width = 0;
  for (final rune in name.runes) {
    width += rune < 0x80 ? 1 : 2;
  }
  return width;
}

/// 이름의 최대 폭 — 한글 4자 또는 영문 8자.
const int maxNameWidth = 8;

/// 주인공을 만든다(제7장 7.5). 던지지 않는다.
///
/// 시작 상태: 레벨 1, HP = 인내력 × 10, MP = 정신력 × 10(마법사) 또는 0,
/// 기본 방어는 전투사 2 · 마법사 0, 맨손, 경험치 0.
CreationResult createCharacter(CreationInput input) {
  final name = input.name.trim();
  if (name.isEmpty) {
    return const CreationResult.refused(RefusalReason.emptyName);
  }
  if (nameWidth(name) > maxNameWidth) {
    return const CreationResult.refused(RefusalReason.nameTooLong);
  }
  if (input.gender == Gender.neutral) {
    return const CreationResult.refused(RefusalReason.invalidGender);
  }
  final preview = previewCreation(answers: input.answers, gender: input.gender);
  if (preview == null) {
    return const CreationResult.refused(RefusalReason.invalidAnswers);
  }

  final three = [input.agility, input.accuracy, input.luck];
  if (three.any((v) => v < 0 || v > abilityCap) ||
      three[0] + three[1] + three[2] != freePoints) {
    return const CreationResult.refused(RefusalReason.invalidPointSplit);
  }

  final skills = input.skills;
  if (skills.length != 6 ||
      skills.any((v) => v < 0) ||
      skills.fold<int>(0, (a, b) => a + b) != skillPoints) {
    return const CreationResult.refused(RefusalReason.invalidSkillSplit);
  }

  final clazz = classOf(preview.family, input.classId);
  if (clazz == null || !clazz.selectable) {
    return const CreationResult.refused(RefusalReason.classNotSelectable);
  }
  if (!clazz.meets(skills)) {
    return const CreationResult.refused(RefusalReason.classRequirementNotMet);
  }

  final member = Member(
    name: name,
    gender: input.gender,
    family: preview.family,
    classId: clazz.id,
    level: 1,
    abilities: [...preview.abilities, ...three],
    skills: skills,
    baseAc: preview.family == Family.fighter ? 2 : 0,
  );
  member.hp = member.endurance * 10;
  member.mp = preview.family == Family.mage ? member.mentality * 10 : 0;
  return CreationResult.created(member, preview);
}
