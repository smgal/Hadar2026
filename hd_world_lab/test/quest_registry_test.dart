import 'dart:io';

import 'package:hd_world_lab/quest/flag_def.dart';
import 'package:hd_world_lab/quest/flag_registry.dart';
import 'package:hd_world_lab/quest/quest_state.dart';
import 'package:test/test.dart';

/// 레지스트리가 **실제 스크립트와 맞는지**.
///
/// 설명은 사람이 손으로 적는 것이라 언제든 틀릴 수 있다. 틀리지 않게
/// 하는 방법은 하나뿐이다 — `flag4ep1.cm2` 를 진짜로 읽어 대 보는 것.
/// 그래서 이 시험은 파일을 연다.
///
/// 게임 쪽 폴더를 읽으므로 그 폴더가 없으면 건너뛴다. 실험실만 떼어
/// 내도 돌아가야 하고, 없는 것을 없다고 말하는 편이 통째로 빨간 것보다
/// 낫다.
void main() {
  final assets = File('../hadar2026_app/assets/flag4ep1.cm2');
  final hasGame = assets.existsSync();

  /// `variable(NAME)` 다음 줄의 `NAME.assign(N)` 을 짝지어 읽는다.
  Map<String, int> readCm2Names() {
    final text = assets.readAsStringSync();
    final out = <String, int>{};
    final pattern = RegExp(r'([A-Z][A-Z0-9_]*)\s*\.\s*assign\(\s*(\d+)\s*\)');
    for (final m in pattern.allMatches(text)) {
      out[m.group(1)!] = int.parse(m.group(2)!);
    }
    return out;
  }

  group('flag4ep1.cm2 와 맞는가', () {
    test('이름이 적힌 칸은 전부 그 파일에 그 번호로 있다', () {
      final cm2 = readCm2Names();
      for (final def in flagRegistry) {
        if (def.cm2Name.isEmpty) continue;
        expect(
          cm2[def.cm2Name],
          isNotNull,
          reason: '${def.id} 가 적은 ${def.cm2Name} 이 flag4ep1.cm2 에 없다',
        );
        expect(
          cm2[def.cm2Name],
          def.index,
          reason: '${def.id}: ${def.cm2Name} 의 번호가 다르다',
        );
      }
    }, skip: hasGame ? null : '게임 쪽 assets 이 없다');

    test('그 파일의 이름은 전부 레지스트리에 있다', () {
      // 이쪽이 더 중요하다. 스크립트에 플래그를 더하고 설명을 안 적으면
      // 그 칸은 영영 번호로만 남는다.
      final cm2 = readCm2Names();
      final known = {
        for (final d in flagRegistry)
          if (d.cm2Name.isNotEmpty) d.cm2Name,
      };
      final missing = cm2.keys.where((n) => !known.contains(n)).toList();
      expect(
        missing,
        isEmpty,
        reason: 'flag4ep1.cm2 에 있는데 설명이 없다: ${missing.join(', ')}',
      );
    }, skip: hasGame ? null : '게임 쪽 assets 이 없다');

    test('스크립트가 번호로 쓰는 칸이 레지스트리에 다 있다', () {
      // 이름 없이 숫자로 쓰는 것들 — 이것이 제일 위험하다. 이름이
      // 없으므로 앞 시험 둘 다 못 잡는다.
      final dir = Directory('../hadar2026_app/assets');
      final used = <int>{};
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.cm2')) continue;
        final text = file.readAsStringSync();
        for (final m in RegExp(
          r'Flag::(?:Set|Reset|IsSet)\(\s*(\d+)\s*\)',
        ).allMatches(text)) {
          used.add(int.parse(m.group(1)!));
        }
      }
      final known = {
        for (final d in flagRegistry)
          if (d.kind == FlagKind.toggle) d.index,
      };
      final missing = used.where((i) => !known.contains(i)).toList()..sort();
      expect(
        missing,
        isEmpty,
        reason: '스크립트가 쓰는데 설명이 없는 번호: ${missing.join(', ')}',
      );
    }, skip: hasGame ? null : '게임 쪽 assets 이 없다');

    test('단계로 세는 칸이 레지스트리에 다 있다', () {
      final dir = Directory('../hadar2026_app/assets');
      final used = <int>{};
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.cm2')) continue;
        for (final m in RegExp(
          r'Variable::(?:Set|Add|Get)\(\s*(\d+)',
        ).allMatches(file.readAsStringSync())) {
          used.add(int.parse(m.group(1)!));
        }
      }
      final known = {
        for (final d in flagRegistry)
          if (d.kind == FlagKind.step) d.index,
      };
      expect(used.difference(known), isEmpty);
    }, skip: hasGame ? null : '게임 쪽 assets 이 없다');
  });

  group('레지스트리 자체', () {
    test('같은 갈래 안에서 번호가 겹치지 않는다', () {
      final seen = <String>{};
      for (final def in flagRegistry) {
        final key = '${def.kind.name}:${def.index}';
        expect(seen.add(key), isTrue, reason: '${def.id} 의 번호가 겹친다');
      }
    });

    test('사람이 읽는 번호가 서로 다르다', () {
      final ids = flagRegistry.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('단계짜리는 단계 설명을 갖고 토글은 갖지 않는다', () {
      for (final def in flagRegistry) {
        if (def.kind == FlagKind.step) {
          expect(def.steps.length, greaterThanOrEqualTo(2), reason: def.id);
        } else {
          expect(def.steps, isEmpty, reason: def.id);
        }
      }
    });

    test('모든 칸에 제목과 설명이 있다', () {
      for (final def in flagRegistry) {
        expect(def.title.trim(), isNotEmpty, reason: def.id);
        expect(def.detail.trim(), isNotEmpty, reason: def.id);
      }
    });

    test('아직 없는 칸만 scripts 가 비어 있다', () {
      for (final def in flagRegistry) {
        if (def.status == FlagStatus.planned) {
          expect(def.scripts, isEmpty, reason: '${def.id} 는 아직 없는 칸이다');
        } else {
          expect(def.scripts, isNotEmpty, reason: '${def.id} 를 쓰는 곳이 없다');
        }
      }
    });

    test('열어 주는 능력의 이름이 hd_world 의 것이다', () {
      // 여기서 오타가 나면 플래그를 켜도 아무 일이 안 일어나고, 그것이
      // 화면에서는 「기능이 없다」 로 보인다.
      const known = {
        'walkOnWater',
        'walkOnSwamp',
        'levitate',
        'carryLight',
        'senseWeakness',
      };
      for (final def in flagRegistry) {
        for (final g in def.grants) {
          expect(known, contains(g), reason: '${def.id} 의 $g');
        }
      }
    });

    test('겹치는 번호를 실제로 찾아낸다', () {
      // 지금 실제로 셋이다 — 10 · 31 · 50. lore_ep1.cm2 · town2.cm2 ·
      // menace.cm2 가 flag4ep1.cm2 를 include 하지 않고 번호를 직접
      // 쓰기 때문이다. 고쳐지면 이 시험이 먼저 알려 준다.
      final found = collisions();
      expect(found, isNotEmpty);
      final indexes = found.map((c) => c['index']).toSet();
      expect(indexes, containsAll([10, 31, 50]));
    });
  });

  group('값', () {
    test('단계는 끝난 것 · 하는 중 · 아직으로 갈린다', () {
      final state = QuestState();
      final lordAhn = flagRegistry.firstWhere((d) => d.id == 'W-010');
      state.setValue(lordAhn.index, 3);

      final view = flagView(lordAhn, state);
      expect(view['value'], 3);
      expect(view['on'], isTrue);
      final states = view['stepStates']! as List;
      expect(states[0], 'done');
      expect(states[1], 'done');
      expect(states[2], 'done');
      expect(states[3], 'current');
      expect(states[4], 'ahead');
    });

    test('날값과 사람 말이 같이 나온다', () {
      final state = QuestState()..set(41, true);
      final water = flagRegistry.firstWhere((d) => d.index == 41);
      final view = flagView(water, state);
      expect(view['raw'], 'Flag::IsSet(41) = 1');
      expect(view['title'], contains('물의 정령'));
      expect(view['cm2Name'], 'GFD4_JOINNED_SOUL_OF_WATER');
    });

    test('시나리오가 통행 능력을 연다', () {
      final state = QuestState();
      expect(state.granted, isEmpty);

      final learn = flagRegistry.firstWhere((d) => d.id == 'W-060');
      state.set(learn.index, true);
      expect(state.granted, contains('walkOnWater'));

      // 마법과 다르다. 쉬어도 줄지 않고 꺼지지 않는다.
      expect(state.granted, contains('walkOnWater'));
    });

    test('범위 밖은 거절이고 throw 가 아니다', () {
      final state = QuestState();
      expect(state.set(-1, true), isFalse);
      expect(state.set(QuestState.size, true), isFalse);
      expect(state.setValue(10, -1), isFalse);
      expect(state.isSet(9999), isFalse);
    });

    test('정의가 없는데 켜진 칸이 드러난다', () {
      final state = QuestState()
        ..set(200, true)
        ..setValue(201, 5);
      final out = questJson(state);
      final unknown = out['unknown']! as Map<String, Object?>;
      expect(unknown['flags'], contains(200));
      expect((unknown['variables']! as Map)['201'], 5);
    });

    test('게임 쪽 세이브의 256칸 배열도 읽는다', () {
      // `HDGameOption.toJson` 은 불린 배열을 통째로 싣는다. 그것을
      // 그대로 넣어도 읽혀야 게임의 세이브를 열어 볼 수 있다.
      final flags = List<bool>.filled(256, false);
      flags[41] = true;
      final variables = List<int>.filled(256, 0);
      variables[10] = 3;

      final state = QuestState.fromJson({
        'flags': flags,
        'variables': variables,
      });
      expect(state.isSet(41), isTrue);
      expect(state.value(10), 3);
    });

    test('스스로 쓴 것도 그대로 다시 읽는다', () {
      final before = QuestState()
        ..set(41, true)
        ..set(51, true)
        ..setValue(10, 2);
      final after = QuestState.fromJson(before.toJson());
      expect(after.isSet(41), isTrue);
      expect(after.isSet(51), isTrue);
      expect(after.isSet(42), isFalse);
      expect(after.value(10), 2);
    });
  });
}
