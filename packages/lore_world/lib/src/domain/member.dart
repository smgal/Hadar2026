import '../data/class_table.dart';
import '../data/equipment_table.dart';
import 'enums.dart';

/// 피해 한 번이 대원을 어디까지 밀었는지.
enum DamageResult {
  /// 아무 일도 없었다(피해 0, 또는 상한에 막혔다).
  none,

  /// HP 만 줄었다.
  hurt,

  /// 이번 피해로 의식을 잃었다.
  fellUnconscious,

  /// 이미 의식불명인데 더 맞았다.
  deeperUnconscious,

  /// 이번 피해로 죽었다.
  died,

  /// 이미 죽었는데 더 맞았다.
  deeperDead,
}

/// 대원 한 명(주인공·동료·보조 일원 공통).
///
/// ## 저장하는 것과 계산하는 것
///
/// 여기 필드는 **다시 계산할 수 없는 것**뿐이다. 최대 생명력·최대 마법
/// 지수·방어력·무기 공격력·방패 방어력·무기 계통·상태 표시는 전부
/// 읽을 때 계산한다. 원작은 장비를 바꿔도 공격력을 다시 계산하지 않아
/// 주인공의 장비가 전직할 때까지 효과가 없었다(부록 A #1) — 값을 저장하지
/// 않으면 그 종류의 어긋남이 생길 자리가 없다.
class Member {
  Member({
    this.name = '',
    this.nameKey,
    this.rosterKey,
    this.gender = Gender.male,
    required this.family,
    this.classId = ClassId.none,
    this.level = 1,
    required List<int> abilities,
    List<int>? skills,
    this.hp = 0,
    this.mp = 0,
    this.exp = 0,
    this.trainedExp = 0,
    this.poison = 0,
    this.unconscious = 0,
    this.dead = 0,
    this.weapon,
    this.shield,
    this.armour,
    this.baseAc = 0,
    this.acPenalty = 0,
    this.naturalWeapon,
    this.naturalPower,
    this.attackModeOverride,
    this.mindControlImmune = false,
    this.hidden = false,
    this.weaponBlessed = false,
  }) : abilities = List<int>.of(abilities, growable: false),
       skills = List<int>.of(
         skills ?? const [0, 0, 0, 0, 0, 0],
         growable: false,
       ) {
    assert(this.abilities.length == 8);
    assert(this.skills.length == 6);
  }

  /// 플레이어가 지은 이름. 명부에서 온 인물은 비어 있고 [nameKey] 가 있다.
  String name;

  /// `companion.canopus` 같은 이름표. 한국어는 `lore_world_text` 가 붙인다.
  String? nameKey;

  /// 명부에서 만들어졌으면 그 열쇠(`canopus`). 「카노푸스가 일행에 있는가」를
  /// 이름이 아니라 이것으로 답한다 — 이름은 바뀔 수 있고 겹칠 수 있다.
  String? rosterKey;

  Gender gender;
  Family family;

  /// 계열 안의 계급 번호(1~7, 제1부 전용 8·9, 없으면 0).
  int classId;
  int level;

  /// 여덟 능력치. 순서는 [Ability.index8].
  final List<int> abilities;

  /// 여섯 기술치. 뜻은 계열과 계급이 정한다(`skillKey`).
  final List<int> skills;

  int hp;
  int mp;

  /// 아직 쓰지 않은 경험치. 훈련소·마법 학교에서 기술치에 쓴다.
  int exp;

  /// 누적 수련치. **레벨은 이 값으로만 정해진다.**
  int trainedExp;

  /// 상태 카운터 셋. 0 이면 그 상태가 아니다.
  int poison;
  int unconscious;
  int dead;

  /// 장착한 장비의 열쇠. 없으면 null.
  String? weapon;
  String? shield;
  String? armour;

  /// 기본 방어. 전투사 2, 마법사 0, 동료는 저마다.
  int baseAc;

  /// 적의 갑옷 파괴로 깎인 방어력. 갑옷을 갈아입거나 전직하면 0 으로
  /// 돌아간다(원작의 「다시 계산」에 해당한다).
  int acPenalty;

  /// 보조 일원의 타고난 무기 이름표(`natural.fang`). 있으면 무기 계통이
  /// [WeaponKind.special] 이 된다.
  String? naturalWeapon;

  /// 보조 일원의 고정 공격력. 있으면 표 대신 이 값을 쓴다.
  int? naturalPower;

  /// 계열이 정하는 공격 방식을 덮어쓸 때(불의 정령은 정령인데 한 명만 친다).
  AttackMode? attackModeOverride;

  /// 적의 정신 지배에 면역(크리스탈 소환수·대천사장).
  bool mindControlImmune;

  /// 데이터는 남긴 채 일행에서 숨겨졌는가(부록 B.4). 숨은 대원은 모든
  /// 처리에서 없는 사람으로 친다.
  bool hidden;

  /// 지금 든 무기가 「신의 축복」을 받았는가(1편 리겔, 1st/05 S8) — 무기
  /// 공격력 ×1.2. 무기를 바꾸면 끝난다(원작은 장착할 때 공격력을 새로 계산했다).
  /// 축복받은 것은 사실이므로 저장한다 — 공격력은 여전히 읽을 때 계산한다.
  bool weaponBlessed;

  // ── 능력치 읽기 ────────────────────────────────────────────

  int ability(Ability a) => abilities[a.index8];
  void setAbility(Ability a, int value) => abilities[a.index8] = value;

  int get strength => abilities[0];
  int get mentality => abilities[1];
  int get concentration => abilities[2];
  int get endurance => abilities[3];
  int get resistance => abilities[4];
  int get agility => abilities[5];
  int get accuracy => abilities[6];
  int get luck => abilities[7];

  // ── 계급 ──────────────────────────────────────────────────

  ClassDef? get classDef => classOf(family, classId);

  bool get isFighterFamily => family == Family.fighter;
  bool get isMageFamily => family == Family.mage;
  bool get isPaladin => family == Family.fighter && classId == ClassId.paladin;
  bool get isDemigod => classId == ClassId.demigod;

  /// 마법 지수를 갖는가. 마법사 계열, 전사, 반신반인, 그리고 계급 없는
  /// 보조 일원(적 데이터의 정신력을 그대로 갖고 온다).
  bool get hasMagicPool => _mpFactor > 0;

  int get _mpFactor {
    if (family == Family.fighter) {
      if (classId == ClassId.paladin) return 5;
      if (classId == ClassId.demigod) return 10;
      return 0;
    }
    return 10;
  }

  /// 치료 마법 능력치. 마법사는 셋째 자리, 전사는 둘째 자리, 그 밖은 0.
  int get cureSkill {
    if (family == Family.mage) return skills[MageSkill.cure];
    if (isPaladin) return skills[FighterSkill.chop];
    return 0;
  }

  /// 치료 마법을 쓸 수 있는 계열인가.
  bool get canUseCureMagic => family == Family.mage || isPaladin;

  // ── 파생값 (저장하지 않는다) ──────────────────────────────

  /// 최대 생명력 = 인내력 × 레벨 × 10.
  int get maxHp => endurance * level * 10;

  /// 최대 마법 지수. 마법사 ×10, 전사 ×5, 그 외 전투사 0.
  int get maxMp => mentality * level * _mpFactor;

  /// 의식불명 한계. 이 값을 넘으면 죽는다.
  int get unconsciousLimit => endurance * level;

  /// 갑옷 방어력. 계급이 입을 수 없는 갑옷은 0 이다.
  int get armourPower {
    final def = armourByKey(armour);
    if (def == null) return 0;
    final clazz = classDef;
    if (clazz == null || !clazz.canWearArmour(def.legacyId)) return 0;
    return def.defence;
  }

  /// 방어력 = 기본 방어 + 갑옷 방어력 − 갑옷 파괴로 깎인 값.
  int get ac {
    final value = baseAc + armourPower - acPenalty;
    return value < 0 ? 0 : value;
  }

  /// 그 무기를 이 계급이 쓸 수 있는가.
  bool get _weaponUsable {
    final def = weaponByKey(weapon);
    final clazz = classDef;
    return def != null && clazz != null && clazz.weapons.contains(def.kind);
  }

  /// 무기 공격력. 맨손이거나 쓸 수 없는 무기면 5.
  int get weaponPower {
    final fixed = naturalPower;
    if (fixed != null) return fixed;
    if (!_weaponUsable) return barePower;
    final power = weaponByKey(weapon)!.power[classDef!.powerColumn];
    return weaponBlessed ? power * 6 ~/ 5 : power;
  }

  /// 방패 방어력. 쓸 수 없으면 0.
  int get shieldPower {
    final def = shieldByKey(shield);
    final clazz = classDef;
    if (def == null || clazz == null || !clazz.shield) return 0;
    return def.defence;
  }

  /// 무기 계통. 타고난 무기는 special, 쓸 수 없는 무기는 맨손으로 친다.
  WeaponKind get weaponKind {
    if (naturalWeapon != null) return WeaponKind.special;
    if (!_weaponUsable) return WeaponKind.bare;
    return weaponByKey(weapon)!.kind;
  }

  /// 보조 일원의 자동 공격 방식(제8장 8.5).
  AttackMode get attackMode {
    final forced = attackModeOverride;
    if (forced != null) return forced;
    return switch (family) {
      Family.mage || Family.golem || Family.elemental => AttackMode.all,
      _ => AttackMode.single,
    };
  }

  /// 행동 가능 = 의식불명·죽음이 아니고 HP 가 남았다.
  bool get canAct => unconscious == 0 && dead == 0 && hp > 0;

  /// 표시되는 상태. 죽음 > 의식불명 > 중독 > 좋음.
  Condition get condition {
    if (dead > 0) return Condition.dead;
    if (unconscious > 0) return Condition.unconscious;
    if (poison > 0) return Condition.poisoned;
    return Condition.good;
  }

  bool get isDead => dead > 0;
  bool get isUnconscious => unconscious > 0;
  bool get isPoisoned => poison > 0;

  // ── 상태를 바꾸는 기본 동작 ───────────────────────────────
  //
  // 마법·약초·병원·크리스탈이 전부 이 넷을 부른다. 「깊은 곳부터」라는
  // 순서는 부르는 쪽이 지키고, 여기는 한 단계씩만 안다.

  /// 피해를 준다. HP → 의식불명 → 죽음 순으로 깊어진다(제7장 7.7).
  ///
  /// [deadCap] 은 이미 죽은 대원의 죽음 수치가 이 값 **미만일 때만**
  /// 더 쌓이게 한다(필드 중독 100, 용암 30000). null 이면 상한이 없다.
  DamageResult takeDamage(int amount, {int? deadCap}) {
    if (amount <= 0) return DamageResult.none;
    if (dead > 0) {
      if (deadCap != null) {
        if (dead >= deadCap) return DamageResult.none;
        dead += amount;
        if (dead > deadCap) dead = deadCap;
      } else {
        dead += amount;
      }
      return DamageResult.deeperDead;
    }
    if (unconscious > 0) {
      unconscious += amount;
      if (unconscious > unconsciousLimit) {
        dead = 1;
        return DamageResult.died;
      }
      return DamageResult.deeperUnconscious;
    }
    hp -= amount;
    if (hp <= 0) {
      hp = 0;
      unconscious = 1;
      return DamageResult.fellUnconscious;
    }
    return DamageResult.hurt;
  }

  /// HP 를 채운다. 실제로 오른 양을 돌려준다.
  int healHp(int amount) {
    if (amount <= 0) return 0;
    final before = hp;
    hp += amount;
    if (hp > maxHp) hp = maxHp;
    if (hp < before) hp = before;
    return hp - before;
  }

  /// MP 를 채운다. 실제로 오른 양을 돌려준다.
  int restoreMp(int amount) {
    if (amount <= 0) return 0;
    final before = mp;
    mp += amount;
    if (mp > maxMp) mp = maxMp;
    if (mp < before) mp = before;
    return mp - before;
  }

  /// 중독을 푼다. 중독이었으면 true.
  bool curePoison() {
    if (poison == 0) return false;
    poison = 0;
    return true;
  }

  /// 의식을 돌린다(HP 최소 1). 의식불명이었으면 true.
  bool awaken() {
    if (unconscious == 0) return false;
    unconscious = 0;
    if (hp < 1) hp = 1;
    return true;
  }

  /// 되살린다. 죽음 수치를 지우고 **의식불명 상태로** 돌아온다 —
  /// 의식불명 수치는 1 ~ 인내력×레벨 사이로 맞춘다.
  bool revive() {
    if (dead == 0) return false;
    dead = 0;
    final limit = unconsciousLimit < 1 ? 1 : unconsciousLimit;
    if (unconscious < 1) unconscious = 1;
    if (unconscious > limit) unconscious = limit;
    if (hp < 0) hp = 0;
    return true;
  }

  /// 값은 같고 서로 영향을 주지 않는 사본.
  Member copy() => Member.fromJson(toJson());

  // ── 저장 ──────────────────────────────────────────────────

  Map<String, Object?> toJson() => {
    'name': name,
    if (nameKey != null) 'nameKey': nameKey,
    if (rosterKey != null) 'rosterKey': rosterKey,
    'gender': gender.wire,
    'family': family.wire,
    'class': classId,
    'level': level,
    'abilities': List<int>.of(abilities),
    'skills': List<int>.of(skills),
    'hp': hp,
    'mp': mp,
    'exp': exp,
    'trainedExp': trainedExp,
    'poison': poison,
    'unconscious': unconscious,
    'dead': dead,
    if (weapon != null) 'weapon': weapon,
    if (shield != null) 'shield': shield,
    if (armour != null) 'armour': armour,
    'baseAc': baseAc,
    if (acPenalty != 0) 'acPenalty': acPenalty,
    if (naturalWeapon != null) 'naturalWeapon': naturalWeapon,
    if (naturalPower != null) 'naturalPower': naturalPower,
    if (attackModeOverride != null)
      'attackModeOverride': attackModeOverride!.name,
    if (mindControlImmune) 'mindControlImmune': true,
    if (hidden) 'hidden': true,
    if (weaponBlessed) 'weaponBlessed': true,
  };

  /// 저장된 모양에서 되살린다. 빠진 칸은 기본값으로 채우고 던지지 않는다.
  factory Member.fromJson(Map<String, Object?> json) {
    int n(String key, [int fallback = 0]) {
      final v = json[key];
      return v is num ? v.toInt() : fallback;
    }

    String? s(String key) {
      final v = json[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    List<int> list(String key, int length) {
      final v = json[key];
      final out = List<int>.filled(length, 0);
      if (v is List) {
        for (var i = 0; i < length && i < v.length; i++) {
          final e = v[i];
          if (e is num) out[i] = e.toInt();
        }
      }
      return out;
    }

    final mode = s('attackModeOverride');
    return Member(
      name: json['name'] is String ? json['name']! as String : '',
      nameKey: s('nameKey'),
      rosterKey: s('rosterKey'),
      gender: Gender.fromWire(n('gender', Gender.neutral.wire)),
      family: Family.fromWire(n('family', Family.unknown.wire)),
      classId: n('class'),
      level: n('level', 1),
      abilities: list('abilities', 8),
      skills: list('skills', 6),
      hp: n('hp'),
      mp: n('mp'),
      exp: n('exp'),
      trainedExp: n('trainedExp'),
      poison: n('poison'),
      unconscious: n('unconscious'),
      dead: n('dead'),
      weapon: s('weapon'),
      shield: s('shield'),
      armour: s('armour'),
      baseAc: n('baseAc'),
      acPenalty: n('acPenalty'),
      naturalWeapon: s('naturalWeapon'),
      naturalPower: json['naturalPower'] is num
          ? (json['naturalPower']! as num).toInt()
          : null,
      attackModeOverride: mode == null
          ? null
          : AttackMode.values
                .where((m) => m.name == mode)
                .cast<AttackMode?>()
                .firstWhere((_) => true, orElse: () => null),
      mindControlImmune: json['mindControlImmune'] == true,
      hidden: json['hidden'] == true,
      weaponBlessed: json['weaponBlessed'] == true,
    );
  }
}
