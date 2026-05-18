import '../battle/enemy_data.dart';
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
  int ac = 0;

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

  int weapon = 0;
  int shield = 0;
  int armor = 0;

  int powOfWeapon = 0;
  int powOfShield = 0;
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

  String getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon";
  String getShieldName() => shield == 0 ? "없음" : "방패$shield";
  String getArmorName() => armor == 0 ? "평상복" : "갑옷$armor";

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

    powOfWeapon = 0;
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
      case 'pow_of_weapon':
        powOfWeapon = intVal;
        break;
      case 'pow_of_shield':
        powOfShield = intVal;
        break;
      case 'pow_of_armor':
        powOfArmor = intVal;
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
    };
  }

  factory HDPlayer.fromJson(Map<String, dynamic> json) {
    return HDPlayer()
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
      ..ac = json['ac'] ?? 0
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
      ..weapon = json['weapon'] ?? 0
      ..shield = json['shield'] ?? 0
      ..armor = json['armor'] ?? 0
      ..powOfWeapon = json['powOfWeapon'] ?? 0
      ..powOfShield = json['powOfShield'] ?? 0
      ..powOfArmor = json['powOfArmor'] ?? 0;
  }
}
