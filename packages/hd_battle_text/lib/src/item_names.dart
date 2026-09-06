/// 전투 중 쓰는 물건 이름표 (B2-06).
///
/// 표시용이므로 view 가 갖는다 — model 은 물건을 키로만 다룬다.
/// 원작 전투 메뉴에는 물건 항목이 **없었다**(부록 R). 그래서 이 목록은
/// 이식이 아니라 우리가 정한 것이다.
library;

import 'package:hd_battle/hd_battle.dart';

const Map<String, String> itemNames = {
  'potion': '치료약',
  'antidote': '해독제',
  'elixir': '만능약',
  'revive_charm': '소생의 부적',
  'sp_tonic': '기력의 약',
  'poison_vial': '독병',
  'paralysis_vial': '마비병',
  'fire_vial': '화염병',
  'fire_crystal': '화염 결정',
  'storm_crystal': '폭풍 결정',
};

/// 물건 앞에 붙는 글자 (B6-06). 무엇을 마시고 무엇을 바르는지 한눈에.
String itemGlyph(String key) {
  final item = battleItems[key];
  if (item == null) return '';
  return switch (item.kind) {
    BattleItemKind.medical => item.spRestore > 0 ? '💙' : '💚',
    BattleItemKind.crystal => item.hitsAll ? '💥' : '🎯',
    BattleItemKind.coating => coatingGlyph(item.coating!),
  };
}

/// 도포 세 가지의 글자와 이름 (B6-03).
String coatingGlyph(Coating kind) => switch (kind) {
  Coating.poison => '🟣',
  Coating.paralysis => '⚡',
  Coating.fire => '🔥',
};

String coatingName(Coating kind) => switch (kind) {
  Coating.poison => '독',
  Coating.paralysis => '마비',
  Coating.fire => '화염',
};

String itemName(String key) => itemNames[key] ?? key;
