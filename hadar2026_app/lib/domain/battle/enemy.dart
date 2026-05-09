import '../text/noun.dart';
import 'enemy_data.dart';

class HDEnemy {
  final HDEnemyData data;

  late final HDNoun name;

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
    name = HDNoun(data.name);

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
