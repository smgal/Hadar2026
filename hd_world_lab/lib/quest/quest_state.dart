import 'flag_def.dart';
import 'flag_registry.dart';

/// 플래그 256 칸과 변수 256 칸.
///
/// 게임 쪽 `HDGameOption` 과 **같은 모양**이다 — `List<bool> flags` 와
/// `List<int> variables`. 크기도 `HDConfig.maxFlags` · `maxVariables` 와
/// 같은 256 이다. 같은 모양이어야 게임의 세이브를 그대로 읽고 쓴다.
///
/// ## 정의는 갖지 않는다
///
/// 이 클래스는 번호만 안다. 무엇이 무슨 뜻인지는 [flagRegistry] 가 알고,
/// 둘은 번호로만 만난다 — 게임과 정확히 같은 관계다. 그래서 정의가
/// 틀려도 값은 멀쩡하고, 정의를 고쳐도 세이브는 안 바뀐다.
class QuestState {
  QuestState({List<bool>? flags, List<int>? variables})
    : flags = List<bool>.filled(size, false),
      variables = List<int>.filled(size, 0) {
    if (flags != null) {
      for (var i = 0; i < flags.length && i < size; i++) {
        this.flags[i] = flags[i];
      }
    }
    if (variables != null) {
      for (var i = 0; i < variables.length && i < size; i++) {
        this.variables[i] = variables[i];
      }
    }
  }

  /// 원작이 잡아 둔 칸 수. 게임 쪽 `HDConfig.maxFlags` 와 같아야 한다.
  static const int size = 256;

  final List<bool> flags;
  final List<int> variables;

  bool isSet(int index) => _inRange(index) && flags[index];
  int value(int index) => _inRange(index) ? variables[index] : 0;

  bool _inRange(int index) => index >= 0 && index < size;

  /// 한 칸을 세운다. 범위 밖이면 아무 일도 없고 false 를 준다 —
  /// **throw 하지 않는다.** 거절이 값인 것은 `hd_world` 와 같은 규칙이다.
  bool set(int index, bool on) {
    if (!_inRange(index)) return false;
    flags[index] = on;
    return true;
  }

  bool setValue(int index, int v) {
    if (!_inRange(index) || v < 0) return false;
    variables[index] = v;
    return true;
  }

  void reset() {
    flags.fillRange(0, size, false);
    variables.fillRange(0, size, 0);
  }

  /// 시나리오가 연 통행 능력.
  ///
  /// ## 세 번째 출처다
  ///
  /// 물 위를 걷는 것은 원래 둘에서 왔다 — **부적**(차고 있는 동안)과
  /// **마법**(남은 칸 수만큼). 시나리오로 배우는 것은 셋째이고 앞의
  /// 둘과 성질이 다르다: 한 번 켜지면 꺼지지 않고, 쉬어도 줄지 않고,
  /// 누가 무엇을 차고 있는지와 무관하다.
  ///
  /// 그래서 `hd_world` 에 넣지 않았다. 그쪽은 사람과 장비만 알고
  /// 플래그를 모르며, 몰라야 한다 — 알게 되는 순간 모델이 시나리오에
  /// 매인다. 합치는 것은 읽는 쪽의 일이다(게임에서는
  /// `HDParty.canWalkOnWater` 가 이미 같은 일을 한다).
  Set<String> get granted {
    final out = <String>{};
    for (final def in flagRegistry) {
      if (def.grants.isEmpty) continue;
      final on = def.isStep ? value(def.index) > 0 : isSet(def.index);
      if (on) out.addAll(def.grants);
    }
    return out;
  }

  Map<String, Object?> toJson() => {
    // 256칸을 통째로 싣지 않는다. 켜진 것만 적으면 읽는 사람이
    // 무엇이 켜져 있는지를 바로 본다 — 게임 쪽 세이브는 배열을
    // 통째로 싣지만 그쪽은 사람이 읽을 것이 아니다.
    'flags': [
      for (var i = 0; i < size; i++)
        if (flags[i]) i,
    ],
    'variables': {
      for (var i = 0; i < size; i++)
        if (variables[i] != 0) '$i': variables[i],
    },
  };

  static QuestState fromJson(Map<String, Object?> json) {
    final state = QuestState();

    final rawFlags = json['flags'];
    if (rawFlags is List) {
      // 두 꼴을 다 읽는다. 켜진 번호의 목록(이쪽이 쓰는 것)과
      // 256칸 불린 배열(게임 쪽 세이브가 쓰는 것).
      if (rawFlags.isNotEmpty && rawFlags.first is bool) {
        for (var i = 0; i < rawFlags.length && i < size; i++) {
          state.flags[i] = rawFlags[i] == true;
        }
      } else {
        for (final raw in rawFlags) {
          final i = raw is int ? raw : int.tryParse('$raw');
          if (i != null) state.set(i, true);
        }
      }
    }

    final rawVars = json['variables'];
    if (rawVars is List) {
      for (var i = 0; i < rawVars.length && i < size; i++) {
        final v = rawVars[i];
        state.variables[i] = v is int ? v : (int.tryParse('$v') ?? 0);
      }
    } else if (rawVars is Map) {
      for (final e in rawVars.entries) {
        final i = int.tryParse('${e.key}');
        final v = e.value is int ? e.value! as int : int.tryParse('${e.value}');
        if (i != null && v != null) state.setValue(i, v);
      }
    }

    return state;
  }
}

/// 정의 하나 + 지금 값.
///
/// 화면이 한 칸을 그리는 데 필요한 것 전부를 한 덩이로 준다. **날값과
/// 사람 말이 같이** 나오는 것이 요점이다 — 번호만 보면 고칠 수 없고,
/// 설명만 보면 무엇을 고치는지 모른다.
Map<String, Object?> flagView(FlagDef def, QuestState state) {
  final on = def.isStep ? state.value(def.index) > 0 : state.isSet(def.index);
  final value = def.isStep ? state.value(def.index) : (on ? 1 : 0);

  return {
    ...def.toJson(),
    // 날값
    'raw': def.isStep
        ? 'Variable::Get(${def.index}) = $value'
        : 'Flag::IsSet(${def.index}) = ${on ? 1 : 0}',
    'value': value,
    'on': on,
    if (def.isStep) ...{
      'stepCount': def.steps.length,
      // 값 3이면 0·1·2 는 끝났고 3을 하는 중이다. 그 셋을 화면이
      // 다시 계산하지 않도록 여기서 갈라 둔다.
      'stepStates': [
        for (var i = 0; i < def.steps.length; i++)
          if (i < value) 'done' else if (i == value) 'current' else 'ahead',
      ],
      'atEnd': value >= def.steps.length - 1,
    },
  };
}

/// 레지스트리 전체 + 지금 값 + 이 세계의 셈.
Map<String, Object?> questJson(QuestState state) {
  final views = [for (final def in flagRegistry) flagView(def, state)];

  int count(bool Function(Map<String, Object?>) p) => views.where(p).length;

  return {
    'scopeOrder': scopeOrder,
    'scopeNames': scopeNames,
    'flags': views,
    'granted': state.granted.toList()..sort(),
    'collisions': collisions(),
    'summary': {
      'total': views.length,
      'on': count((v) => v['on'] == true),
      'live': count((v) => v['status'] == 'live'),
      'unnamed': count((v) => v['status'] == 'unnamed'),
      'planned': count((v) => v['status'] == 'planned'),
    },
    // 정의가 없는데 켜져 있는 칸. 세이브를 읽어 왔을 때 무엇이
    // 빠졌는지가 여기서 보인다.
    'unknown': {
      'flags': [
        for (var i = 0; i < QuestState.size; i++)
          if (state.flags[i] && !_known(i, FlagKind.toggle)) i,
      ],
      'variables': {
        for (var i = 0; i < QuestState.size; i++)
          if (state.variables[i] != 0 && !_known(i, FlagKind.step))
            '$i': state.variables[i],
      },
    },
  };
}

bool _known(int index, FlagKind kind) =>
    flagRegistry.any((d) => d.index == index && d.kind == kind);
