import 'dart:io';

import 'package:hd_world/hd_world.dart';
import 'package:hd_world_legacy/hd_world_legacy.dart';

/// Regenerates `hadar2026_app/assets/item4ep1.cm2`.
///
/// The constants file is what a script is supposed to use instead of a
/// raw number — bypassing the names is what makes a collision
/// undetectable. It has to be generated, because the catalogue is where
/// the numbers come from and a hand-kept copy drifts.
///
///     dart run tool/make_item_constants.dart ../../hadar2026_app/assets
///
/// Names are not written: this package holds no Korean. A comment gives
/// the reference so a human can find the row.
void main(List<String> args) {
  final dir = args.isEmpty ? '../../hadar2026_app/assets' : args.first;
  final catalog = ItemCatalog.builtIn;
  final out = StringBuffer()
    ..writeln('####### 아이템 상수 ########')
    ..writeln('#')
    ..writeln('# GENERATED — packages/hd_world_legacy/tool/'
        'make_item_constants.dart 가 만든다.')
    ..writeln('# 손으로 고치지 말 것. 형식은 flag4ep1.cm2 를 따른다.')
    ..writeln('# 최상위 include 로 읽을 것.')
    ..writeln('#')
    ..writeln('# 값은 kind << 16 | index 다 (ResId 하위 24비트와 같은 배치).')
    ..writeln('# 생 숫자를 쓰지 말고 이 이름을 쓸 것 — 이름을 우회하면')
    ..writeln('# 충돌을 기계가 잡을 수 없다(부록 M-2).')
    ..writeln('#')
    ..writeln('# 이 빌드가 만든 것(부적·새 무기)은 번호가 없어 여기 없다.')
    ..writeln();

  final used = <int>{};
  ItemKind? lastKind;
  for (final def in catalog.all) {
    final wire = itemWireOf(def.ref, catalog: catalog);
    if (wire < 0) continue;
    if (!used.add(wire)) {
      stderr.writeln('collision: ${def.ref.value} shares wire $wire');
      exitCode = 1;
      continue;
    }
    if (def.kind != lastKind) {
      out.writeln('# ${def.kind.name}');
      lastKind = def.kind;
    }
    final name = _constantName(def);
    out
      ..writeln('variable($name)')
      ..writeln('$name.assign($wire)   # ${def.ref.value}')
      ..writeln();
  }

  final file = File('$dir/item4ep1.cm2');
  file.writeAsStringSync(out.toString());
  stdout.writeln('${file.path}: ${used.length} constants');
}

String _constantName(ItemDef def) {
  final kind = switch (def.kind) {
    ItemKind.slashWeapon => 'WIELD',
    ItemKind.chopWeapon => 'CHOP',
    ItemKind.pierceWeapon => 'STAB',
    ItemKind.bluntWeapon => 'HIT',
    ItemKind.missileWeapon => 'SHOOT',
    ItemKind.summonSingle => 'SUMMON1',
    ItemKind.summonMulti => 'SUMMONN',
    ItemKind.shield => 'SHIELD',
    ItemKind.bodyArmour => 'ARMOR',
    ItemKind.helmet => 'HEAD',
    ItemKind.boots => 'LEG',
    ItemKind.commonAmulet => 'ORNAMENT',
    ItemKind.consumable => 'CONSUMABLE',
    ItemKind.light => 'LIGHT',
    ItemKind.classAmulet => 'CLASSAMULET',
  };
  return 'ITEM_${kind}_${def.legacyIndex}';
}
