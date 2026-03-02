import codecs
import re
import os

text = codecs.open('c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_pc_enemy.cpp', 'r', 'latin-1').read()
start = text.find('static hadar::EnemyData s_enemy_data[75]')
start = text.find('{', start)
end = text.find('};', start)

content = text[start+1:end].strip()

lines = content.split('\n')
out_lines = []
for line in lines:
    line = line.strip()
    if not line or line.startswith('//'): continue
    line = line.replace('{', '[').replace('}', ']')
    out_lines.append(line)

with codecs.open('c:/_GIT_2026/Hadar2026/hadar2026_app/lib/models/hd_enemy_data.dart', 'w', 'utf-8') as f:
    f.write('''class HDEnemyData {
  final int id;
  final String name;
  final int strength;
  final int mentality;
  final int endurance;
  final int resistance;
  final int agility;
  final List<int> accuracy;
  final int ac;
  final int special;
  final int castLevel;
  final int specialCastLevel;
  final int level;

  const HDEnemyData({
    required this.id,
    required this.name,
    required this.strength,
    required this.mentality,
    required this.endurance,
    required this.resistance,
    required this.agility,
    required this.accuracy,
    required this.ac,
    required this.special,
    required this.castLevel,
    required this.specialCastLevel,
    required this.level,
  });
}

const List<HDEnemyData> enemyTable = [
''')
    id = 0
    for l in out_lines:
        if l.endswith(','): l = l[:-1]
        match = re.search(r'\[\s*"([^"]+)",\s*([-0-9]+),\s*([-0-9]+),\s*([-0-9]+),\s*([-0-9]+),\s*([-0-9]+),\s*\[\s*([-0-9]+),\s*([-0-9]+)\s*\],\s*([-0-9]+),\s*([-0-9]+),\s*([-0-9]+),\s*([-0-9]+),\s*([-0-9]+)\s*\]', l)
        if match:
            # name, str, men, end, res, agi, acc1, acc2, ac, spe, clv, scl, lv
            name = match.group(1)
            str_, men, end_, res, agi, acc1, acc2, ac, spe, clv, scl, lv = match.groups()[1:]
            f.write(f"  HDEnemyData(id: {id}, name: '{name}', strength: {str_}, mentality: {men}, endurance: {end_}, resistance: {res}, agility: {agi}, accuracy: [{acc1}, {acc2}], ac: {ac}, special: {spe}, castLevel: {clv}, specialCastLevel: {scl}, level: {lv}),\n")
            id += 1
    f.write('];\n')
