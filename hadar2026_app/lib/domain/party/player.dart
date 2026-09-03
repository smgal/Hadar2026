import 'package:flutter/foundation.dart';

import '../battle/enemy_data.dart';
import '../item/item_data.dart';
import '../item/item_id.dart';
import '../item/item_names.dart';
import '../item/item_type.dart';
import '../text/noun.dart';
import 'skill_stats.dart';

class HDPlayer {
  HDPlayer();

  HDNoun _name = HDNoun.empty;

  HDNoun get name => _name;

  set name(String value) {
    _name = HDNoun(value);
  }

  int order = 0;
  int gender = 0; // 0: Male, 1: Female
  int characterClass = 0;

  int strength = 0;
  int mentality = 0;
  int concentration = 0;
  int endurance = 0;
  int resistance = 0;
  int agility = 0;
  int luck = 0;
  /// 캐릭터 소양의 방어도 — 종족·직업에서 오는 값이다
  /// (`hd_class_pc_player.cpp:402` `ac = data.ac;`). 장비분은 [ac] 가 더한다.
  ///
  /// 분리하지 않고 `ac` 를 장비 합산으로 덮으면 이 값이 **조용히 사라진다.**
  int baseAc = 0;

  int hp = 0;
  int maxHp = 0;
  int sp = 0;
  int maxSp = 0;
  int esp = 0;
  int maxEsp = 0;
  int experience = 0;

  SkillStats accuracy = SkillStats();
  SkillStats level = SkillStats();

  int poison = 0;
  int unconscious = 0;
  int dead = 0;

  /// 부위별 장비. `null` 은 빈 칸.
  ///
  /// 원작 `ObjPlayer.cs:152` `Equiped[] equip = new Equiped[EQUIP.MAX]`.
  /// C++ 세대는 정수 3칸이었고(`hd_class_pc_player.h:60-62`) Unity 포트에서
  /// 6부위로 늘었다. 원작의 `Equiped.IsValid()` 자리는 `null` 이 대신한다.
  final List<HDItemId?> equip = List<HDItemId?>.filled(
    HDEquipSlot.values.length,
    null,
  );

  /// [slot] 에 장착된 아이템. 없으면 `null`.
  HDItemId? equippedAt(HDEquipSlot slot) => equip[slot.wire];

  /// [id] 를 [slot] 에 장착한다 — `ObjPlayer.SetEquipment`
  /// (`ObjPlayer.cs:390-420`). 부위가 맞지 않으면 **아무것도 바꾸지 않고**
  /// `false`.
  bool equipItem(HDEquipSlot slot, HDItemId id) {
    if (id.kind.equipSlot != slot) return false;
    equip[slot.wire] = id;
    return true;
  }

  /// [slot] 을 비우고 벗은 아이템을 돌려준다. 비어 있거나 벗을 수 없으면
  /// `null` — 맨손은 벗을 수 없다(`GameEventEquipment.cs:122`).
  HDItemId? unequip(HDEquipSlot slot) {
    final id = equip[slot.wire];
    if (id == null) return null;
    if (slot == HDEquipSlot.hand && id.index == 0) return null;
    equip[slot.wire] = null;
    return id;
  }

  // ---- 레거시 정수 3칸 -------------------------------------------------
  //
  // 필드가 아니라 슬롯에서 유도한다. 지우지 않는 이유: cm2 가 실제로 쓴다
  // (`menace.cm2:48` `Player::ChangeAttribute(6, "armor", 0)`). 필드를
  // 없애면 changeAttribute 의 case 가 사라져 **조용히 무시**된다 —
  // GROUND_TRUTH 부록 F-1 과 같은 침묵 실패다.

  int get weapon => _legacyIndex(HDEquipSlot.hand, legacyWeaponIds, 'weapon');
  set weapon(int value) =>
      _setLegacy(HDEquipSlot.hand, value, legacyWeaponIds, 'weapon');

  int get shield =>
      _legacyIndex(HDEquipSlot.handSub, legacyShieldIds, 'shield');
  set shield(int value) =>
      _setLegacy(HDEquipSlot.handSub, value, legacyShieldIds, 'shield');

  int get armor => _legacyIndex(HDEquipSlot.armor, legacyArmorIds, 'armor');
  set armor(int value) =>
      _setLegacy(HDEquipSlot.armor, value, legacyArmorIds, 'armor');

  int _legacyIndex(HDEquipSlot slot, List<HDItemId> legacy, String name) {
    final id = equip[slot.wire];
    if (id == null) return 0;
    final i = legacy.indexOf(id);
    if (i >= 0) return i;
    // 레거시 10칸 밖의 아이템이 끼워져 있다. cm2 는 "장비 없음(0)" 과
    // 구분해야 하므로 0 을 줄 수 없고, 왕복은 보장되지 않는다.
    debugPrint(
      '[equip] $name: ${id.kind.name}:${id.index} is outside the legacy '
      'index space; reporting ${id.index}, which will not round-trip',
    );
    return id.index;
  }

  void _setLegacy(
    HDEquipSlot slot,
    int value,
    List<HDItemId> legacy,
    String name,
  ) {
    // 0 은 "벗는다" 다 — `menace.cm2:48-52` 가 장비를 0 으로 만들어
    // 잃는 연출을 한다.
    if (value == 0) {
      equip[slot.wire] = null;
      return;
    }
    if (value < 0 || value >= legacy.length) {
      debugPrint(
        '[equip] $name index $value is outside 0..${legacy.length - 1} — '
        'slot left unchanged',
      );
      return;
    }
    equip[slot.wire] = legacy[value];
  }

  /// 전투식이 읽는 방어도 — `battle.dart:431,505`.
  ///
  /// **방어의 유일한 축이다.** 플레이어가 맞을 때도(`:505`) 적이 맞을 때도
  /// (`:431`) 이 값 하나만 쓰인다 — 부위별 감쇠도, 방패 별도 항도 없다
  /// (부록 H-1 정정판).
  ///
  /// `baseAc` + 착용 중인 6칸의 `param.ac` 합. 파생값이므로 장착·해제
  /// 직후 재계산할 것이 없다.
  int get ac => baseAc + equipmentAc;

  /// cm2 `ChangeAttribute('ac', n)` 과 파티 초기화가 쓰는 경로.
  /// **소양값**([baseAc])을 바꾼다 — 장비분은 그대로 얹힌다.
  set ac(int value) => baseAc = value;

  /// 착용 중인 슬롯들의 `param.ac` 합.
  ///
  /// 원작은 갑옷(`ObjPlayer.cs:585-595`)과 방패(`:597-610`)를 따로 계산하고
  /// 방패에는 방패 스킬을 곱하지만, Dart 에는 스킬 시스템이 없다
  /// (`HDPlayer` 에 `skill` 이 없고 `accuracy`/`level` 뿐이다).
  /// 스킬까지 이식하면 이 작업이 스킬 시스템 이식으로 부풀므로 **단순 합산**
  /// 으로 시작한다 — 부위별 감쇠는 필요해질 때 꺼낸다(부록 H-1).
  int get equipmentAc {
    var sum = 0;
    for (final id in equip) {
      if (id == null) continue;
      sum += itemById(id)?.param.ac ?? 0;
    }
    return sum;
  }

  /// 주 무기의 공격력 — **살아 있는 값**이다. `battle.dart:429` 가
  /// `strength * powOfWeapon * level.physical ~/ 20` 으로 읽는다.
  ///
  /// 부록 H-1 **초판은 이 필드까지 죽었다고 적었고 틀렸다.** 정정판이
  /// 확인한 대로 죽은 것은 [powOfShield]·[powOfArmor] 둘뿐이다.
  /// 같은 오해가 반복되지 않도록 여기 적어 둔다.
  ///
  /// 빈손이면 원작의 맨손 항(`attaPow` = 1).
  ///
  /// **파생 전용이라 대입할 수 없다.** cm2 의
  /// `Player::ChangeAttribute('pow_of_weapon', n)`(`menace.cm2:49`,
  /// `L1_ep1d0.cm2:169`)은 [changeAttribute] 가 경고를 남기고 무시한다 —
  /// 장비가 결정하는 값을 스크립트가 몰래 덮으면 둘이 갈린다(부록 H-5).
  int get powOfWeapon {
    final id = equip[HDEquipSlot.hand.wire];
    final item = id == null ? null : itemById(id);
    return item?.param.attaPow ?? _bareHandAttaPow;
  }

  static final int _bareHandAttaPow =
      itemById(const HDItemId(HDItemType.wield, index: 0))?.param.attaPow ?? 1;

  /// **죽은 필드** — 전투식에서 읽는 곳이 **0곳**이다(부록 H-1 정정판을
  /// 전수 확인). 방어는 [ac] 하나로만 계산되고, 장비의 방패 `ac` 는
  /// [equipmentAc] 를 거쳐 그리로 들어간다.
  ///
  /// 여기에 값을 써도 **아무 효과가 없다.** cm2 의
  /// `Player::ChangeAttribute('pow_of_shield', n)` 은 경고를 남기고
  /// 무시된다([changeAttribute]).
  ///
  /// 지우지 않는 이유는 세이브 호환뿐이다 — `toJson`/`fromJson` 이
  /// 아직 담는다.
  int powOfShield = 0;

  /// **죽은 필드** — [powOfShield] 와 같다. 부록 H-1 정정판.
  int powOfArmor = 0;

  bool isValid() => name.isNotEmpty;

  bool isAvailable() => isValid() && unconscious == 0 && dead == 0 && hp > 0;

  bool isConscious() => isAvailable();

  void damaged(int damage) {
    if (damage <= 0) return;
    if (hp > 0) {
      hp -= damage;
      if (hp <= 0) {
        hp = 0;
        if (dead == 0) unconscious = 1;
      }
    }
  }

  void damagedByPoison() {
    // 20 ~ 39 damage
    damaged(20 + (DateTime.now().millisecondsSinceEpoch % 20));
  }

  String getGenderName() {
    return gender == 0 ? "남성" : "여성";
  }

  String getClassName() {
    switch (characterClass) {
      case 0:
        return "에스퍼";
      case 1:
        return "싸이보그";
      case 2:
        return "초능력자";
      default:
        return "알 수 없음";
    }
  }

  String getWeaponName() => _slotName(
    HDEquipSlot.hand,
    legacyWeaponName(0),
    legacyUnknownWeaponName,
  );
  String getShieldName() => _slotName(
    HDEquipSlot.handSub,
    legacyShieldName(0),
    legacyUnknownShieldName,
  );
  String getArmorName() => _slotName(
    HDEquipSlot.armor,
    legacyArmorName(0),
    legacyUnknownArmorName,
  );

  /// 슬롯의 표시 이름. 빈 칸이면 [empty], 카탈로그에 없는 id 면 [unknown].
  /// 조용히 빈 문자열이 되지 않는 것이 요점이다(부록 F-1).
  String _slotName(HDEquipSlot slot, String empty, String unknown) {
    final id = equip[slot.wire];
    if (id == null) return empty;
    final item = itemById(id);
    if (item != null) return item.name;
    debugPrint('[equip] no catalog row for ${id.kind.name}:${id.index}');
    return unknown;
  }

  dynamic getAttribute(String attr) {
    switch (attr.toLowerCase()) {
      case 'max_hp':
        return maxHp;
      case 'max_sp':
        return maxSp;
      case 'max_esp':
        return maxEsp;
      case 'hp':
        return hp;
      case 'sp':
        return sp;
      case 'esp':
        return esp;
      case 'experience':
        return experience;
      case 'strength':
        return strength;
      case 'mentality':
        return mentality;
      case 'concentration':
        return concentration;
      case 'endurance':
        return endurance;
      case 'resistance':
        return resistance;
      case 'agility':
        return agility;
      case 'luck':
        return luck;
      case 'weapon':
        return weapon;
      case 'shield':
        return shield;
      case 'armor':
        return armor;
      case 'pow_of_weapon':
        return powOfWeapon;
      case 'pow_of_shield':
        return powOfShield;
      case 'pow_of_armor':
        return powOfArmor;
      case 'ac':
        return ac;
      case 'level':
        return level.physical;
      case 'level(magic)':
        return level.magic;
      case 'level(esp)':
        return level.esp;
      case 'accuracy':
        return accuracy.physical;
      case 'accuracy(magic)':
        return accuracy.magic;
      case 'accuracy(esp)':
        return accuracy.esp;
      case 'name':
        return _name.text;
      case 'poison':
        return poison;
      case 'unconscious':
        return unconscious;
      case 'dead':
        return dead;
      default:
        return 0;
    }
  }

  bool checkLevelUp() {
    bool leveledUp = false;
    // Exp table matches original game (0 to 19+). level.physical is the current tier.
    final expTable = [
      0,
      0,
      1500,
      6000,
      20000,
      50000,
      150000,
      250000,
      500000,
      800000,
      1050000,
      1320000,
      1620000,
      1950000,
      2310000,
      2700000,
      3120000,
      3570000,
      4050000,
      4560000,
      5100000,
    ];

    while (level.physical < expTable.length - 1 &&
        experience >= expTable[level.physical + 1]) {
      level.physical++;

      // Calculate stat growth
      strength += 1 + (strength ~/ 10);
      endurance += 2;
      agility += 1;
      accuracy.physical += 1;

      if (mentality > 0) mentality += 1;
      if (concentration > 0) concentration += 1;

      // Update Max HP / SP
      maxHp = endurance * level.physical;
      maxSp = mentality * level.magic;
      maxEsp = concentration * level.esp;

      hp = maxHp; // Heal on level up
      sp = maxSp;
      esp = maxEsp;

      leveledUp = true;
    }
    return leveledUp;
  }

  void assignFromEnemyData(int enemyId) {
    if (enemyId < 0 || enemyId >= enemyTable.length) return;

    final data = enemyTable[enemyId];

    name = data.name;
    gender = 0; // Male
    characterClass = 0;

    strength = data.strength;
    mentality = data.mentality;
    concentration = 0;
    endurance = data.endurance;
    resistance = data.resistance ~/ 2;
    agility = data.agility;
    luck = 10;
    ac = data.ac;

    level.physical = data.level;
    level.magic = data.castLevel * 3;
    if (level.magic == 0) level.magic = 1;
    level.esp = 1;

    maxHp = endurance * level.physical;
    maxSp = mentality * level.magic;
    maxEsp = concentration * level.esp;

    hp = maxHp;
    sp = maxSp;
    esp = maxEsp;

    // Experience calculation matching original game
    final expTable = [
      0,
      0,
      1500,
      6000,
      20000,
      50000,
      150000,
      250000,
      500000,
      800000,
      1050000,
      1320000,
      1620000,
      1950000,
      2310000,
      2700000,
      3120000,
      3570000,
      4050000,
      4560000,
    ];

    if (level.physical < expTable.length) {
      experience = expTable[level.physical];
    } else {
      experience = 5100000;
    }

    final accuracyData = data.accuracy;
    accuracy.physical = accuracyData[0];
    accuracy.magic = accuracyData[1];
    accuracy.esp = 0;

    poison = 0;
    unconscious = 0;
    dead = 0;

    weapon = 0;
    shield = 0;
    armor = 0;

    powOfShield = 0;
    powOfArmor = 0;
  }

  void changeAttribute(String attr, dynamic value) {
    if (value is String)
      return; // String sets not fully applicable except name, which isn't used usually
    int intVal = value is int ? value : (value as num).toInt();

    switch (attr.toLowerCase()) {
      case 'max_hp':
        maxHp = intVal;
        break;
      case 'max_sp':
        maxSp = intVal;
        break;
      case 'max_esp':
        maxEsp = intVal;
        break;
      case 'hp':
        hp = intVal;
        break;
      case 'sp':
        sp = intVal;
        break;
      case 'esp':
        esp = intVal;
        break;
      case 'experience':
        experience = intVal;
        break;
      case 'strength':
        strength = intVal;
        break;
      case 'mentality':
        mentality = intVal;
        break;
      case 'concentration':
        concentration = intVal;
        break;
      case 'endurance':
        endurance = intVal;
        break;
      case 'resistance':
        resistance = intVal;
        break;
      case 'agility':
        agility = intVal;
        break;
      case 'luck':
        luck = intVal;
        break;
      case 'weapon':
        weapon = intVal;
        break;
      case 'shield':
        shield = intVal;
        break;
      case 'armor':
        armor = intVal;
        break;
      // 셋 다 더 이상 스크립트가 정할 값이 아니지만 이유가 다르다.
      // 조용히 무시하지 않고 어느 쪽인지 알린다.
      case 'pow_of_weapon':
        // 장비에서 유도된다(부록 H-5). 스크립트가 덮으면 둘이 갈린다.
        debugPrint(
          '[equip] pow_of_weapon is derived from the hand slot — ignoring '
          'the write of $intVal. Equip an item instead.',
        );
        break;
      case 'pow_of_shield':
      case 'pow_of_armor':
        // 읽는 곳이 0곳인 죽은 필드다(부록 H-1 정정판). 써도 효과가
        // 없었으므로 무시하는 편이 실제 동작에 더 가깝다.
        debugPrint(
          '[equip] $attr is a dead field — nothing reads it, so the write '
          'of $intVal would have had no effect either way. Defence comes '
          'from ac alone.',
        );
        break;
      case 'ac':
        ac = intVal;
        break;
      case 'level':
        level.physical = intVal;
        break;
      case 'level(magic)':
        level.magic = intVal;
        break;
      case 'level(esp)':
        level.esp = intVal;
        break;
      case 'accuracy':
        accuracy.physical = intVal;
        break;
      case 'accuracy(magic)':
        accuracy.magic = intVal;
        break;
      case 'accuracy(esp)':
        accuracy.esp = intVal;
        break;
      case 'poison':
        poison = intVal;
        break;
      case 'unconscious':
        unconscious = intVal;
        break;
      case 'dead':
        dead = intVal;
        break;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': _name.text,
      'order': order,
      'gender': gender,
      'characterClass': characterClass,
      'strength': strength,
      'mentality': mentality,
      'concentration': concentration,
      'endurance': endurance,
      'resistance': resistance,
      'agility': agility,
      'luck': luck,
      // v1 이 담던 의미 그대로 **유효 방어도**다. v2 는 아래 'baseAc' 를
      // 읽으므로 저장→로드로 장비분이 겹쳐 쌓이지 않는다.
      'ac': ac,
      'hp': hp,
      'maxHp': maxHp,
      'sp': sp,
      'maxSp': maxSp,
      'esp': esp,
      'maxEsp': maxEsp,
      'experience': experience,
      'accuracy': accuracy.toJson(),
      'level': level.toJson(),
      'poison': poison,
      'unconscious': unconscious,
      'dead': dead,
      'weapon': weapon,
      'shield': shield,
      'armor': armor,
      'powOfWeapon': powOfWeapon,
      'powOfShield': powOfShield,
      'powOfArmor': powOfArmor,
      // ---- v2 ----
      // 'equip' 의 존재 여부가 곧 버전 판정이다 — party.toJson 에 버전이
      // 없어서 fromJson 이 `version` 을 볼 수 없다.
      'equip': [for (final id in equip) id?.wire ?? -1],
      'baseAc': baseAc,
    };
  }

  factory HDPlayer.fromJson(Map<String, dynamic> json) {
    final p = HDPlayer()
      ..name = json['name'] ?? ""
      ..order = json['order'] ?? 0
      ..gender = json['gender'] ?? 0
      ..characterClass = json['characterClass'] ?? 0
      ..strength = json['strength'] ?? 0
      ..mentality = json['mentality'] ?? 0
      ..concentration = json['concentration'] ?? 0
      ..endurance = json['endurance'] ?? 0
      ..resistance = json['resistance'] ?? 0
      ..agility = json['agility'] ?? 0
      ..luck = json['luck'] ?? 0
      ..hp = json['hp'] ?? 0
      ..maxHp = json['maxHp'] ?? 0
      ..sp = json['sp'] ?? 0
      ..maxSp = json['maxSp'] ?? 0
      ..esp = json['esp'] ?? 0
      ..maxEsp = json['maxEsp'] ?? 0
      ..experience = json['experience'] ?? 0
      ..accuracy = SkillStats.fromJson(
          Map<String, dynamic>.from(json['accuracy'] ?? const {}))
      ..level = SkillStats.fromJson(
          Map<String, dynamic>.from(json['level'] ?? const {}))
      ..poison = json['poison'] ?? 0
      ..unconscious = json['unconscious'] ?? 0
      ..dead = json['dead'] ?? 0
      // 죽은 필드지만 세이브 호환을 위해 그대로 나른다(부록 H-1 정정판).
      ..powOfShield = json['powOfShield'] ?? 0
      ..powOfArmor = json['powOfArmor'] ?? 0;

    // powOfWeapon 은 읽지 않는다 — 장비에서 유도되는 값이다.
    final rawEquip = json['equip'];
    if (rawEquip is List) {
      // v2: 슬롯을 그대로 복원한다.
      p._restoreEquip(rawEquip);
      p.baseAc = (json['baseAc'] as num?)?.toInt() ?? json['ac'] ?? 0;
    } else {
      // v1: 정수 3칸이 전부였다. 원작 인덱스 공간으로 해석해 슬롯을
      // 채우고, 머리·다리·장식은 v1 에 없었으므로 빈 칸으로 둔다.
      p.weapon = json['weapon'] ?? 0;
      p.shield = json['shield'] ?? 0;
      p.armor = json['armor'] ?? 0;
      // v1 의 'ac' 는 소양과 장비가 섞이지 않은 값이지만, 위에서 장비를
      // 채웠으므로 그대로 두면 부풀어 오른다. 장비분을 빼서 v1 의 최종
      // ac 를 보존한다.
      final v1Ac = (json['ac'] as num?)?.toInt() ?? 0;
      final base = v1Ac - p.equipmentAc;
      if (base < 0) {
        debugPrint(
          '[save] v1 ac $v1Ac is below the migrated equipment ac '
          '${p.equipmentAc}; clamping baseAc to 0',
        );
      }
      p.baseAc = base < 0 ? 0 : base;
    }
    return p;
  }

  void _restoreEquip(List<dynamic> raw) {
    for (var i = 0; i < equip.length; i++) {
      equip[i] = null;
    }
    for (var i = 0; i < equip.length && i < raw.length; i++) {
      final wire = raw[i];
      if (wire is! num || wire < 0) continue;
      final id = HDItemId.tryFromWire(wire.toInt());
      final slot = HDEquipSlot.fromWire(i);
      if (id == null || slot == null || !equipItem(slot, id)) {
        debugPrint(
          '[save] equip slot $i holds $wire, which does not belong there — '
          'left empty',
        );
      }
    }
  }
}
