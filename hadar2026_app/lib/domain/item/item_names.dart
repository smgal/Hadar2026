import 'package:flutter/foundation.dart';

import 'item_data.dart';

/// 레거시 정수 슬롯(`HDPlayer.weapon`/`shield`/`armor`)의 표시 이름.
///
/// 원작 C++ 이 `resource::getWeaponName(weapon)` 으로 하던 일이다
/// (`hd_class_pc_player.cpp:302-315`). 표 밖 인덱스는 원작과 같이
/// '불확실한 …' 을 돌려주되, 조용히 넘어가지 않도록 경고를 남긴다 —
/// 범위 밖 인자를 소리 없이 무시하는 것이 P0-14 가 기록한 실패 방식이다.

/// `HDPlayer.weapon` → 무기 이름.
String legacyWeaponName(int index) => _lookup(
  legacyWeaponNames,
  index,
  legacyUnknownWeaponName,
  'weapon',
);

/// `HDPlayer.shield` → 방패 이름.
String legacyShieldName(int index) => _lookup(
  legacyShieldNames,
  index,
  legacyUnknownShieldName,
  'shield',
);

/// `HDPlayer.armor` → 갑옷 이름.
String legacyArmorName(int index) => _lookup(
  legacyArmorNames,
  index,
  legacyUnknownArmorName,
  'armor',
);

String _lookup(List<String> names, int index, String unknown, String slot) {
  if (index >= 0 && index < names.length) return names[index];
  debugPrint(
    '[item] $slot index $index is outside 0..${names.length - 1} — '
    'falling back to "$unknown"',
  );
  return unknown;
}
