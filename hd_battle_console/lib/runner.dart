import 'dart:io';

import 'package:hd_battle/hd_battle.dart';
import 'package:hd_battle_text/hd_battle_text.dart' as tx;

import 'fixture.dart';
import 'palette.dart';
import 'view.dart';

/// 명령을 어디서 가져올지.
typedef CommandSource =
    BattleCommand? Function(BattleDecision decision, BattleView view);

/// 전투 하나를 끝까지 돌리고 출력한다.
///
/// 이 파일이 하는 일은 `pendingDecision` → 물어보기 → `applyCommand`,
/// 물을 것이 없으면 `advance()` 를 반복하는 것뿐이다. 규칙은 전부
/// `hd_battle` 안에 있고 이쪽에서는 보이지 않는다.
class BattleRunner {
  BattleRunner({
    required this.fixture,
    required this.source,
    this.showStatus = true,
    this.sink,
    this.ansi = HDAnsi.plain,
  });

  final Fixture fixture;
  final CommandSource source;
  final bool showStatus;

  /// 색을 어떻게 낼지. 기본값은 색 없음이라 파이프·테스트 경로가
  /// 예전과 똑같은 맨 문자열을 받는다.
  final HDAnsi ansi;

  /// 출력 대상. 비우면 stdout.
  final void Function(String line)? sink;

  /// 실제로 쓰인 명령 열. `--record` 가 이걸 파일로 남긴다.
  final List<BattleCommand> used = [];

  void _out(String text) {
    if (sink != null) {
      for (final line in text.split('\n')) {
        sink!(line);
      }
    } else {
      stdout.writeln(text);
    }
  }

  BattleOutcome run({int stepLimit = 10000}) {
    final battle = Battle(fixture.setup);
    final view = BattleView(battle, ansi: ansi);

    _out(ansi.render('=== ${fixture.name} ===', defaultColor: HDColor.yellow));
    if (fixture.note.isNotEmpty) {
      _out(ansi.render(fixture.note, defaultColor: HDColor.lightGray));
    }
    _out(
      ansi.render(
        '시드 ${paint(HDColor.white, fixture.setup.seed)} · '
        '적 ${paint(HDColor.white, fixture.setup.enemyKeys.join(", "))}',
        defaultColor: HDColor.darkGray,
      ),
    );

    var steps = 0;
    var lastRound = 0;
    while (!battle.isFinished) {
      if (steps++ > stepLimit) {
        throw StateError('전투가 $stepLimit 걸음 안에 끝나지 않았다');
      }
      final decision = battle.pendingDecision;
      if (decision == null) {
        for (final event in battle.advance()) {
          for (final line in view.render(event)) {
            _out(line);
          }
        }
        continue;
      }

      if (showStatus && battle.round != lastRound) {
        _out(view.statusTable());
        lastRound = battle.round;
      }
      final command = source(decision, view) ?? CancelChoice(decision.slot);
      used.add(command);
      for (final event in battle.applyCommand(command)) {
        for (final line in view.render(event)) {
          _out(line);
        }
      }
    }

    _out(view.statusTable());
    _out(view.outcomeReport(battle.outcome!));
    return battle.outcome!;
  }
}

/// 사람이 stdin 으로 답한다.
///
/// 메뉴는 [BattleView] 가 이미 색을 입혀서 준다. 여기서 물들이는 것은
/// 입력 표시와 되묻는 말뿐이다.
CommandSource interactive({HDAnsi ansi = HDAnsi.plain}) => (decision, view) {
  stdout.writeln();
  stdout.writeln(view.menuFor(decision));
  // 기술 목록이 길면 첫 화면은 묶음이다. 묶음을 고르면 그 안 목록을 다시
  // 보이고, 그 다음 숫자가 답이 된다. 0 은 어느 화면에서나 취소.
  tx.SkillGroup? group;
  final folds =
      decision is SpellDecision && tx.skillListFolds(decision.options);
  while (true) {
    stdout.write(ansi.render('> ', defaultColor: HDColor.lightCyan));
    final line = stdin.readLineSync();
    if (line == null) {
      stdout.writeln(
        ansi.render('(입력이 끊겼다 — 취소로 처리)', defaultColor: HDColor.darkGray),
      );
      return CancelChoice(decision.slot);
    }
    final choice = int.tryParse(line.trim());
    if (choice == null) {
      stdout.writeln(
        ansi.render('숫자를 입력하십시오.', defaultColor: HDColor.lightRed),
      );
      continue;
    }
    if (choice == 0) return CancelChoice(decision.slot);
    if (folds && group == null) {
      final groups = tx.skillGroups(decision.options);
      if (choice < 1 || choice > groups.length) {
        stdout.writeln(
          ansi.render('그런 항목이 없습니다.', defaultColor: HDColor.lightRed),
        );
        continue;
      }
      group = groups[choice - 1];
      stdout.writeln();
      stdout.writeln(view.spellMenu(decision, group: group));
      continue;
    }
    final command = _commandFor(decision, choice, group: group);
    if (command == null) {
      stdout.writeln(
        ansi.render('그런 항목이 없습니다.', defaultColor: HDColor.lightRed),
      );
      continue;
    }
    return command;
  }
};

/// 기록된 명령 열을 순서대로 먹인다.
CommandSource replay(List<BattleCommand> commands) {
  var index = 0;
  return (decision, view) {
    if (index >= commands.length) {
      throw StateError(
        '기록된 명령 열이 ${commands.length}개에서 떨어졌다 — '
        '슬롯 ${decision.slot} 의 ${decision.runtimeType} 에 답할 것이 없다. '
        '시드나 규칙이 바뀌었으면 --record 로 다시 만들어야 한다.',
      );
    }
    return commands[index++];
  };
}

/// 대화 없이 정해진 방침으로 답한다. `--record` 가 명령 열을 만들 때 쓴다.
///
/// ```
/// attack                기본 방침 하나 — 전원이 그대로 한다
/// heal:21               `:` 뒤는 고를 마법 id
/// attack@3              `@` 뒤는 노릴 적 번호 (0부터). 없으면 첫 적
/// attack,4=heal:21      슬롯 4 만 다르게. 나머지는 앞의 기본 방침
/// magic:2,2=attack@3,4=heal
/// ```
///
/// `@` 는 **뒷열의 보스를 일부러 노리는** fixture 를 만들 때 쓴다 —
/// 사거리가 모자라면 벌점이 붙고 앞의 졸개가 대신 맞는다(B5-01).
///
/// **슬롯별 방침이 필요한 이유**: 파티가 5인이 되면서 전원에게 같은 행동을
/// 시키면 시연이 망가진다 — 다섯이 다 치료하면 아무도 적을 못 잡는다.
/// 실제 파티도 치유사만 치료하고 나머지는 때린다.
CommandSource policy(String spec) {
  final parts = spec.split(',');
  final fallback = _SlotPolicy.parse(parts.first);
  final bySlot = <int, _SlotPolicy>{};
  for (final part in parts.skip(1)) {
    final eq = part.indexOf('=');
    if (eq < 0) {
      throw ArgumentError('슬롯별 방침은 `슬롯=방침` 형식이다: $part');
    }
    final slot = int.tryParse(part.substring(0, eq).trim());
    if (slot == null) {
      throw ArgumentError('슬롯 번호가 정수가 아니다: $part');
    }
    bySlot[slot] = _SlotPolicy.parse(part.substring(eq + 1).trim());
  }

  return (decision, view) =>
      (bySlot[decision.slot] ?? fallback).answer(decision, view.battle);
}

/// 한 사람의 방침.
///
/// B6-01 이후 마법은 한 목록이라, `magic` · `magic-all` · `special` · `heal` ·
/// `esp` 는 **그 목록에서 무엇을 고를지**(범위 필터)가 됐다. 이름은 fixture
/// 의 `record` 가 그대로 쓰고 있어서 남겨 두었다. 지시(`auto` · `advance` ·
/// `fallback`)는 `orders` 를 먼저 열고 그 안에서 고른다.
class _SlotPolicy {
  const _SlotPolicy(
    this.action,
    this.wanted,
    this.target,
    this.pick, {
    this.throws = false,
  });

  final BattleAction action;

  /// `throw` — 병을 바르지 않고 던진다.
  final bool throws;

  /// `:` 뒤에 붙은 마법 id. 고를 수 없으면 [pick] 이 정한 첫 번째로 떨어진다.
  final int? wanted;

  /// `@` 뒤에 붙은 적 번호. 고를 수 없으면 첫 번째로 떨어진다.
  final int? target;

  /// 기술 목록에서 무엇을 고를지 — 방침 이름이 정한다.
  final bool Function(SkillOption option) pick;

  static bool _any(SkillOption o) => true;

  static _SlotPolicy parse(String spec) {
    final at = spec.indexOf('@');
    final target = at < 0 ? null : int.tryParse(spec.substring(at + 1).trim());
    final bits = (at < 0 ? spec : spec.substring(0, at)).split(':');
    final name = bits.first.trim();
    final wanted = bits.length > 1 ? int.tryParse(bits[1]) : null;
    final (action, pick) = switch (name) {
      'attack' => (BattleAction.attack, _any),
      'auto' => (BattleAction.autoBattle, _any),
      'escape' => (BattleAction.escape, _any),
      'skill' => (BattleAction.castSkill, _any),
      'magic' => (
        BattleAction.castSkill,
        (SkillOption o) =>
            o.scope == SkillScope.oneEnemy && o.resource == SkillResource.sp,
      ),
      'magic-all' => (
        BattleAction.castSkill,
        (SkillOption o) => o.scope == SkillScope.allEnemies,
      ),
      'special' => (
        BattleAction.castSkill,
        (SkillOption o) => o.scope == SkillScope.curse,
      ),
      'coat' => (
        BattleAction.castSkill,
        (SkillOption o) => o.scope == SkillScope.selfWeapon,
      ),
      'heal' => (
        BattleAction.castSkill,
        (SkillOption o) =>
            o.scope == SkillScope.oneAlly || o.scope == SkillScope.allAllies,
      ),
      'esp' => (
        BattleAction.castSkill,
        (SkillOption o) => o.resource == SkillResource.esp,
      ),
      'item' => (BattleAction.useItem, _any),
      'throw' => (BattleAction.useItem, _any),
      'charge' => (BattleAction.charge, _any),
      'brace' => (BattleAction.brace, _any),
      'advance' => (BattleAction.advanceFormation, _any),
      'fallback' => (BattleAction.retreatFormation, _any),
      'skip' => (BattleAction.skip, _any),
      _ => throw ArgumentError('알 수 없는 방침: $name'),
    };
    return _SlotPolicy(action, wanted, target, pick, throws: name == 'throw');
  }

  BattleCommand answer(BattleDecision decision, [Battle? battle]) =>
      switch (decision) {
        ActionDecision() => ChooseAction(
          decision.slot,
          _topLevel(decision, battle),
        ),
        OrderDecision() => ChooseAction(
          decision.slot,
          decision.options.contains(action) ? action : decision.options.first,
        ),
        EnemyTargetDecision() => ChooseEnemyTarget(
          decision.slot,
          target != null && decision.enemyIndices.contains(target)
              ? target!
              : decision.enemyIndices.first,
        ),
        SpellDecision() => _skill(decision),
        ItemDecision() => ChooseItem(decision.slot, _itemFor(decision)),
        // `throw` 방침이면 던지고, 아니면 바른다.
        ItemUseDecision() => ChooseItemUse(
          decision.slot,
          throws ? ItemUse.throwAtEnemy : ItemUse.coat,
        ),
        AllyTargetDecision() => ChooseAllyTarget(
          decision.slot,
          decision.slots.first,
        ),
      };

  /// 최상위 메뉴에서 무엇을 누르는가. 지시는 `orders` 를 거친다.
  ///
  /// **바르는 방침은 한 번 바르면 싸운다.** 매 라운드 바르기만 하면 발린
  /// 무기를 휘두르는 라운드가 없다 — 사람도 그렇게는 안 한다.
  BattleAction _topLevel(ActionDecision decision, Battle? battle) {
    if (action.isOrder) {
      return decision.options.contains(BattleAction.orders)
          ? BattleAction.orders
          : BattleAction.attack;
    }
    final me = battle?.party.where((c) => c.slot == decision.slot);
    final coated = me != null && me.isNotEmpty && me.first.coating != null;
    if (coated && _isCoatingPolicy(decision)) return BattleAction.attack;
    // 도망·지시는 리더에게만, 기술은 배운 것이 있을 때만 제안된다.
    // 마법 지수가 말라도 목록은 남지만(B6-01) 항목이 없으면 공격한다.
    return decision.options.contains(action) ? action : BattleAction.attack;
  }

  /// 기술 목록에서 고르기 — 원하는 id, 없으면 필터가 맞는 **쓸 수 있는**
  /// 첫 항목, 그것도 없으면 취소(= 이 턴 건너뜀).
  BattleCommand _skill(SpellDecision decision) {
    final affordable = decision.options.where((o) => o.affordable).toList();
    if (wanted != null && affordable.any((o) => o.magicId == wanted)) {
      return ChooseSpell(decision.slot, wanted!);
    }
    final picks = affordable.where(pick);
    if (picks.isEmpty) return CancelChoice(decision.slot);
    return ChooseSpell(decision.slot, picks.first.magicId);
  }

  /// 이 방침이 무기에 무언가를 바르는 것인가 — `coat`, 또는 도포병이 있는
  /// `item`.
  bool _isCoatingPolicy(ActionDecision decision) {
    if (action == BattleAction.castSkill) {
      return pick(
        const SkillOption(
          magicId: coatingSpellId,
          scope: SkillScope.selfWeapon,
          resource: SkillResource.sp,
          cost: coatingSpellCost,
          affordable: true,
        ),
      );
    }
    return action == BattleAction.useItem;
  }

  /// 물건: `item:` 뒤에 키를 못 쓰니(정수 파서) 도포병이 있으면 그것을 먼저,
  /// 없으면 첫 번째. 시연용이라 단순하게 둔다.
  String _itemFor(ItemDecision decision) {
    for (final key in decision.itemKeys) {
      if (battleItems[key]?.kind == BattleItemKind.coating) return key;
    }
    return decision.itemKeys.first;
  }
}

/// 메뉴의 1-based 선택을 명령으로. [group] 은 접힌 기술 목록에서 고른 묶음.
BattleCommand? _commandFor(
  BattleDecision decision,
  int choice, {
  tx.SkillGroup? group,
}) {
  switch (decision) {
    case ActionDecision():
      if (choice < 1 || choice > decision.options.length) return null;
      return ChooseAction(decision.slot, decision.options[choice - 1]);
    case EnemyTargetDecision():
      if (choice < 1 || choice > decision.enemyIndices.length) return null;
      return ChooseEnemyTarget(
        decision.slot,
        decision.enemyIndices[choice - 1],
      );
    case SpellDecision():
      final options = group?.options ?? decision.options;
      if (choice < 1 || choice > options.length) return null;
      return ChooseSpell(decision.slot, options[choice - 1].magicId);
    case OrderDecision():
      if (choice < 1 || choice > decision.options.length) return null;
      return ChooseAction(decision.slot, decision.options[choice - 1]);
    case ItemDecision():
      if (choice < 1 || choice > decision.itemKeys.length) return null;
      return ChooseItem(decision.slot, decision.itemKeys[choice - 1]);
    case ItemUseDecision():
      if (choice < 1 || choice > decision.uses.length) return null;
      return ChooseItemUse(decision.slot, decision.uses[choice - 1]);
    case AllyTargetDecision():
      if (choice < 1 || choice > decision.slots.length) return null;
      return ChooseAllyTarget(decision.slot, decision.slots[choice - 1]);
  }
}
