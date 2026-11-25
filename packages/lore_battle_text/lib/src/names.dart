/// 키를 이름으로 푸는 곳.
///
/// model 은 한국어를 갖지 않으므로, 전투가 **스스로 만든** 것들 — 소환수,
/// 설득되어 넘어온 적, 이름을 바꿔 나온 적 — 은 이름 대신 키를 싣고 나온다.
/// 그 키를 여기서 푼다.
library;

import 'package:lore_battle/lore_battle.dart';

import 'enemy_names.dart';
import 'item_names.dart';
import 'noun.dart';

/// 이름을 바꿔 쓰는 적 — `EnemyOverride.nameKey`.
///
/// 원작은 다른 칸의 적 데이터를 불러와 이름만 바꿔 보스로 쓴다(제3부
/// 12.2 비고, 제1부·제2부 8.1 "이름을 바꿔 쓰는 적"). 편마다 따로다.
const Map<int, Map<String, String>> enemyAliasNames = {
  1: {
    'major_mummy': '메이저 미라',
    'sphinx': '스핑크스',
    'camp_soldier': '수용소 병사',
    'zombie': '좀비',
    'archi_gagoyle': '아키가고일',
    'hydra_head': '히드라의 머리',
    'huge_dragon': '휴즈 드래곤',
    'dragon_tail': '드래곤의 꼬리',
    'necromancer': '네크로만서',
  },
  2: {
    'soldier': '병사',
    'guard': '경비병',
    'bank_guard': '은행 경비원',
    'giant_cyclops': '거대 사이클롭스',
    'last_guardian': '최후의 가디안',
    'sirian_caminus': '실리안 카미너스',
  },
  3: {
    'draconian_believer': '드라코니안 신도',
    'troll_magic_user': '트롤매직유저',
    'dracon_emperor_17': '17대 드라콘제왕',
    'dracon_guardian_spirit': '드라콘 수호령',
  },
};

/// 그 편의 적 이름표.
Map<String, String> enemyNamesFor(int episode) => switch (episode) {
  1 => enemyNamesEp1,
  2 => enemyNamesEp2,
  _ => enemyNamesEp3,
};

/// 적의 이름. **편이 같이 와야 한다** — 같은 키(`draconian` · `vampire`)라도
/// 편이 다르면 다른 적이다.
///
/// 별칭 표를 먼저 보고, 없으면 그 편의 적 목록, 그것도 없으면 키를 그대로
/// 돌려준다(빈 칸보다는 키가 보이는 편이 고치기 쉽다).
String enemyName(int episode, String key) =>
    enemyAliasNames[episode]?[key] ?? enemyNamesFor(episode)[key] ?? key;

/// `summon.ifrit` · `enemy.3.orc_soldier` 같은 이름 키를 푼다.
String resolveNameKey(String nameKey) {
  if (nameKey.startsWith('summon.')) {
    final key = nameKey.substring('summon.'.length);
    return summonNames[key] ?? key;
  }
  if (nameKey.startsWith('enemy.')) {
    final parts = nameKey.split('.');
    if (parts.length >= 3) {
      final episode = int.tryParse(parts[1]) ?? 3;
      return enemyName(episode, parts.sublist(2).join('.'));
    }
  }
  return nameKey;
}

/// 일행 한 사람의 표시 이름. RPG 가 준 이름이 있으면 그것, 없으면 키.
String memberDisplayName(CombatantSnapshot member) =>
    member.name.isNotEmpty ? member.name : resolveNameKey(member.nameKey);

/// 그 사람이 든 무기의 표시 이름.
String weaponDisplayName(CombatantSnapshot member) {
  if (member.weaponName.isNotEmpty) return member.weaponName;
  if (member.weaponNameKey.isNotEmpty) {
    return weaponNameKeys[member.weaponNameKey] ?? member.weaponNameKey;
  }
  return member.weaponKind == WeaponKind.bare ? '맨손' : '무기';
}

/// 적 하나의 표시 이름.
///
/// 정신 지배로 넘어간 보조 일원은 `summon.…` 같은 이름 키를 그대로 들고
/// 적 목록에 서므로, 점이 든 키는 [resolveNameKey] 로 푼다.
String enemyDisplayName(EnemyInstance enemy) {
  final literal = enemy.displayName;
  if (literal != null && literal.isNotEmpty) return literal;
  return enemy.nameKey.contains('.')
      ? resolveNameKey(enemy.nameKey)
      : enemyName(enemy.episode, enemy.nameKey);
}

/// 슬롯·적 번호를 이름으로 바꾸는 방법.
///
/// 문장을 만드는 쪽([battleLines])이 `Battle` 을 들고 있지 않아도 되게
/// 하려고 인터페이스로 뺐다 — 호출자가 자기 방식으로 이름을 찾는다.
abstract interface class BattleNames {
  /// 파티 슬롯의 이름 (조사까지).
  HDNoun member(int slot);

  /// 적 번호의 이름.
  HDNoun enemy(int index);

  /// 그 슬롯이 든 무기의 표시 이름.
  String weapon(int slot);
}

/// 원작 문장을 더 가깝게 내고 싶을 때 [BattleNames] 에 얹는 것.
///
/// 원작은 결과 줄에서 이름 대신 "그/그녀" 를 쓰고(부록 E.7), 무기 계통에
/// 따라 동사를 바꾼다(공격했다 · 내려쳤다 · 찔렀다 · 쏘았다). 둘 다 전투
/// 이벤트에는 없는 정보라 호출자가 안다. 구현하지 않으면 이름과
/// "공격했다" 로 나간다.
abstract interface class BattleNarration {
  /// "그" 또는 "그녀". 보조 일원은 원작도 이름을 쓴다 — 그때는 이름을 준다.
  String pronoun(int slot);

  /// 그 슬롯이 든 무기의 계통.
  WeaponKind weaponKind(int slot);
}

/// `Battle` 하나에서 이름을 찾는 기본 구현.
///
/// 콘솔 드라이버와 앱이 같은 것을 쓴다. 성별은 전투가 모르므로
/// [pronounOf] 로 받는다 — 안 주면 이름을 쓴다.
class LoreBattleNames implements BattleNames, BattleNarration {
  LoreBattleNames(this.battle, {this.pronounOf});

  final Battle battle;

  /// 슬롯 → "그"/"그녀". null 을 돌려주면 이름을 쓴다.
  final String? Function(int slot)? pronounOf;

  Combatant? _member(int slot) {
    for (final c in battle.party) {
      if (c.slot == slot) return c;
    }
    return null;
  }

  @override
  HDNoun member(int slot) {
    final c = _member(slot);
    return HDNoun(c == null ? '?' : memberDisplayName(c.snapshot));
  }

  @override
  HDNoun enemy(int index) {
    if (index < 0 || index >= battle.enemies.length) return HDNoun('적');
    return HDNoun(enemyDisplayName(battle.enemies[index]));
  }

  @override
  String weapon(int slot) {
    final c = _member(slot);
    return c == null ? '무기' : weaponDisplayName(c.snapshot);
  }

  @override
  String pronoun(int slot) {
    // 보조 일원은 원작도 이름으로 부른다.
    if (slot != assistantSeat) {
      final given = pronounOf?.call(slot);
      if (given != null && given.isNotEmpty) return given;
    }
    return member(slot).text;
  }

  @override
  WeaponKind weaponKind(int slot) =>
      _member(slot)?.snapshot.weaponKind ?? WeaponKind.bare;
}
