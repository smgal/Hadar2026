import 'enemy_data.dart';

class HDEnemy {
  final HDEnemyData data;

  String name = "";
  String josaSub1 = ""; // 은/는
  String josaSub2 = ""; // 이/가
  String josaObj = ""; // 을/를
  String josaWith = ""; // 와/과

  int strength = 0;
  int mentality = 0;
  int endurance = 0;
  int resistance = 0;
  int agility = 0;
  List<int> accuracy = [0, 0];
  int ac = 0;
  int special = 0;
  int castLevel = 0;
  int specialCastLevel = 0;
  int level = 0;

  int hp = 0;
  int poison = 0;
  int unconscious = 0;
  int dead = 0;

  HDEnemy(this.data) {
    name = data.name;

    // Apply Jongsung rule for enemy names
    bool hasJongsung = _hasJongsung(name);
    josaSub1 = hasJongsung ? "은" : "는";
    josaSub2 = hasJongsung ? "이" : "가";
    josaObj = hasJongsung ? "을" : "를";
    josaWith = hasJongsung ? "과" : "와";

    strength = data.strength;
    mentality = data.mentality;
    endurance = data.endurance;
    resistance = data.resistance;
    agility = data.agility;
    accuracy = List.from(data.accuracy);
    ac = data.ac;
    special = data.special;
    castLevel = data.castLevel;
    specialCastLevel = data.specialCastLevel;
    level = data.level;

    hp = endurance * level;
    if (hp <= 0) hp = 1;
  }

  bool _hasJongsung(String str) {
    if (str.isEmpty) return false;

    // English names parsing rough approximation
    // Usually names ending in consonants have jongsung equivalent in Korean mapping
    // But since original C++ mapped English names as "은/는" via a complex byte mapping of the localized text.
    // Wait, the enemy names are in English in the source code ("Skeleton", "Orc"),
    // but maybe they were rendered internally with Korean translations?
    // Actually `town1.cm2` has Korean. The enemy table has English. Let's assume standard ASCII mapping if it's ascii.
    int lastCode = str.runes.last;

    // Hangul Check
    if (lastCode >= 0xAC00 && lastCode <= 0xD7A3) {
      return (lastCode - 0xAC00) % 28 > 0;
    }

    // English heuristic (if ending with a, e, i, o, u -> no jongsung, else yes)
    String lower = String.fromCharCode(lastCode).toLowerCase();
    if ("aeiouw".contains(lower)) return false;
    return true; // ends in consonant
  }

  bool isConscious() {
    return hp > 0 && unconscious == 0 && dead == 0;
  }

  dynamic getAttribute(String attr) {
    switch (attr.toLowerCase()) {
      case 'hp':
        return hp;
      case 'strength':
        return strength;
      case 'mentality':
        return mentality;
      case 'endurance':
        return endurance;
      case 'resistance':
        return resistance;
      case 'agility':
        return agility;
      case 'accuracy':
        return accuracy[0];
      case 'accuracy(magic)':
        return accuracy[1];
      case 'ac':
        return ac;
      case 'level':
        return level;
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

  void changeAttribute(String attr, dynamic value) {
    if (value is String) return;
    int intVal = value is int ? value : (value as num).toInt();

    switch (attr.toLowerCase()) {
      case 'hp':
        hp = intVal;
        break;
      case 'strength':
        strength = intVal;
        break;
      case 'mentality':
        mentality = intVal;
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
      case 'accuracy':
        accuracy[0] = intVal;
        break;
      case 'accuracy(magic)':
        accuracy[1] = intVal;
        break;
      case 'ac':
        ac = intVal;
        break;
      case 'level':
        level = intVal;
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
}
