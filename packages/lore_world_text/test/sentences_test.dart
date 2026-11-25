import 'dart:math';

import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart';
import 'package:test/test.dart';

Member _hero({String name = '슴갈', int hp = -1}) {
  final m = Member(
    name: name,
    family: Family.fighter,
    classId: ClassId.fighter,
    abilities: [10, 10, 10, 10, 10, 10, 10, 10],
    skills: [10, 10, 10, 10, 10, 10],
    baseAc: 2,
  );
  m.hp = hp < 0 ? m.maxHp : hp;
  return m;
}

/// 늘 0 을 내는 난수 — 확률 판정이 늘 「걸리는」 쪽으로 간다.
class _Zero implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  test('거절마다 문장이 있고 자리표가 남지 않는다', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero());
    for (final reason in RefusalReason.values) {
      final line = refusalLine(
        Refusal(reason, seat: 0, key: 'item.hp_potion'),
        world: world,
      );
      expect(line, isNotEmpty, reason: reason.name);
      expect(line, isNot(contains('{')), reason: reason.name);
      expect(line, isNot(contains('null')), reason: reason.name);
    }
  });

  test('사람이 들어가는 거절은 이름과 조사가 붙는다', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero());
    expect(
      refusalLine(Refusal(RefusalReason.alreadyDead, seat: 0), world: world),
      '슴갈은 이미 죽은 상태입니다.',
    );
    expect(
      refusalLine(const Refusal(RefusalReason.noneOwned, key: 'item.hp_potion')),
      '하지만 체력 회복약이 없습니다.',
    );
    expect(
      refusalLine(const Refusal(RefusalReason.battleOnly, key: 'esp.telekinesis')),
      '염력은 전투에서만 사용됩니다.',
    );
  });

  test('휴식 — 식량이 없으면 한 번만 말한다', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero(hp: 1))
      ..food = 0;
    world.join(rosterEp3['alcor']!.build()..name = '알코르');
    final lines = outcomeLines(world.rest(6, rng: _Zero()), world);
    expect(lines.where((l) => l.contains('식량이 바닥났다')).length, 1);
  });

  test('휴식 — 회복 문장', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero(hp: 1))..food = 10;
    final lines = outcomeLines(world.rest(1, rng: _Zero()), world);
    expect(lines.first, anyOf('슴갈은 치료되었다.', '슴갈은 모든 건강이 회복되었다.'));
  });

  test('용암 — 경고와 피해', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero());
    final outcome = world.step(
      const StepInput(terrain: Terrain.lava),
      rng: _Zero(),
    );
    final lines = outcomeLines(outcome, world);
    expect(lines.first, '@C일행은 용암 지대로 들어섰다!!!@@');
    expect(lines.any((l) => l.startsWith('슴갈은 ') && l.contains('피해')), isTrue);
  });

  test('병원 — 치료 결과', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero(hp: 1))..gold = 100000;
    final lines = outcomeLines(world.hospitalTreat(0, Treatment.wounds), world);
    expect(lines, contains('슴갈은 모든 건강이 회복되었다.'));
  });

  test('합류 — 동료 이름이 들어간다', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero());
    final lines = outcomeLines(world.join(rosterEp3['vega']!.build()), world);
    expect(lines, ['베가가 일행에 참가했다.']);
  });

  test('거절된 결과는 까닭 한 줄', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero())..gold = 0;
    final lines = outcomeLines(world.buyEquipment('weapon.long_sword'), world);
    expect(lines, ['당신은 충분한 돈이 없습니다.']);
  });

  test('식량 제조는 세 줄', () {
    final lines = eventLines(
      const FoodCreated(3, 45),
      LoreWorld(episode: Episode.ep3),
    );
    expect(lines, [
      '식량 제조 마법은 성공적으로 수행되었습니다.',
      '3개의 식량이 증가됨',
      '일행의 현재 식량은 45개입니다.',
    ]);
  });

  test('레벨업은 노란 글씨', () {
    final world = LoreWorld.newGame(Episode.ep3, _hero());
    expect(eventLines(const LevelUp(0, 5), world), ['@E슴갈의 레벨은 5입니다.@@']);
  });
}
