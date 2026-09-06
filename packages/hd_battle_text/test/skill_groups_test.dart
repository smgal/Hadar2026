import 'package:hd_battle/hd_battle.dart';
import 'package:hd_battle_text/hd_battle_text.dart';
import 'package:test/test.dart';

/// 기술 목록이 길면 범위로 한 번 접는다 — 세 view 가 같은 규칙을 쓴다.
void main() {
  List<SkillOption> listFor(int magic, int esp) =>
      skillOptions(levelMagic: magic, levelEsp: esp, sp: 999, esp: 999);

  test('8줄까지는 접지 않는다', () {
    expect(skillListFolds(listFor(1, 0)), isFalse); // 5줄
    expect(listFor(1, 0).length, lessThanOrEqualTo(skillFoldThreshold));
  });

  test('레벨 20 술사는 접힌다 — 37줄', () {
    final list = listFor(20, 5);
    expect(list.length, 37);
    expect(skillListFolds(list), isTrue);
  });

  test('묶음은 7개 이하이고 목록 순서를 지킨다', () {
    final groups = skillGroups(listFor(20, 5));
    expect(groups.length, lessThanOrEqualTo(7));
    expect(groups.map((g) => g.scope).toList(), [
      SkillScope.oneEnemy,
      SkillScope.allEnemies,
      SkillScope.selfWeapon,
      SkillScope.curse,
      SkillScope.oneAlly,
      SkillScope.allAllies,
      SkillScope.oneEnemy, // 초능력 — 같은 범위, 다른 자원
    ]);
    expect(groups.last.resource, SkillResource.esp);
    // 묶음을 다 합치면 원래 목록이다 — 빠지는 것이 없다.
    final all = [for (final g in groups) ...g.options];
    expect(all.length, 37);
  });

  test('묶음 이름에 글자와 개수가 붙고, 못 쓰는 것이 있으면 분수로', () {
    final groups = skillGroups(
      skillOptions(levelMagic: 20, levelEsp: 5, sp: 0, esp: 0),
    );
    final curse = groups.firstWhere((g) => g.scope == SkillScope.curse);
    expect(skillGroupLabel(curse), contains('☠ 약화'));
    expect(skillGroupLabel(curse), contains('0/4'), reason: 'SP 0 이라 전부 부족');
    expect(skillGroupHeader(curse), '☠ 약화 ===>');
    final esp = groups.last;
    expect(skillGroupLabel(esp), contains('🔮 초능력'));
  });
}
