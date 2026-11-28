import 'package:flutter/material.dart';
import 'package:lore_battle/lore_battle.dart' as lb;
import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart' as wt;

import '../../application/battle_bridge/cm2_battle_adapter.dart';
import '../../hd_config.dart';
import '../../hd_game_main.dart';

/// Colours for the status panel. The layout is hadar2026_app's; the
/// columns are the Lore originals' (제13장 13.1).
class _StatusPalette {
  static const Color partyBg = Color(0xFF101A2E);
  static const Color partyBorder = Color(0xFF253456);
  static const Color emptyBorder = Color(0xFF1A2030);
  static const Color assistantBg = Color(0xFF1E1438);
  static const Color assistantBgEmpty = Color(0xFF150F26);
  static const Color assistantBorder = Color(0xFF3A2A5A);
  static const Color headerText = Color(0xFF55FFFF); // 원작의 하늘색 머리글
  static const Color rowText = Color(0xFFE8E8E8);
  static const Color badText = Color(0xFFFF5555); // 「좋음」이 아니면 빨강
}

/// 상태 창 — 1~6번 칸의 이름 · 생명력 · 마력 · 상태 (제13장 13.1).
///
/// ```
/// 이름          생명력  마력   상태
/// 슴갈            180     0   좋음
/// 카노푸스        900   150   중독
/// ```
///
/// * 상태는 심각한 순으로 하나 — 죽은 상태 > 의식 불명 > 중독 > 좋음.
///   「좋음」이면 흰색, 아니면 빨간색이다.
/// * 6번은 보조 일원 칸이라 바탕색이 다르다.
/// * 숨겨진 동료(반역 루트 · 지하 묘)는 빈칸으로 보인다.
/// * 마력이 없는 사람(마법사 계열·전사가 아닌 사람)은 마력 칸이 빈다.
/// * 전투 중에는 전투가 가진 값(생명력 · 마력 · 상태)을 보인다. 전투는 자기 사본으로
///   돌다가 끝날 때 한 번 정산하므로, 일행 값만 보면 끝날 때까지 숫자가 그대로다.
class HDStatusPanel extends StatelessWidget {
  const HDStatusPanel({super.key});

  static const double _nameW = 104;
  static const double _numW = 50;
  static const double _stateW = 60;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HDConfig.statusPanelWidth,
      height: HDConfig.statusPanelHeight,
      color: Colors.black,
      child: ListenableBuilder(
        listenable: Listenable.merge([HDGameMain().party, HDCm2BattleAdapter()]),
        builder: (context, child) {
          final world = HDGameMain().party.world;
          final battle = HDCm2BattleAdapter().active;
          final live = <int, lb.CombatantView>{
            if (battle != null)
              for (final c in battle.party)
                if (!c.joinedInBattle) c.snapshot.slot: c,
          };
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    _header('이름', _nameW),
                    _header('생명력', _numW, right: true),
                    _header('마력', _numW, right: true),
                    _header('상태', _stateW, right: true),
                  ],
                ),
              ),
              for (var seat = 0; seat < Seat.count; seat++)
                _row(
                  world.member(seat),
                  live: live[seat],
                  episode: world.episode,
                  isAssistant: seat == Seat.assistant,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String text, double width, {bool right = false}) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(
          color: _StatusPalette.headerText,
          fontSize: 13,
          height: 1.2,
        ),
      ),
    ),
  );

  Widget _row(
    Member? m, {
    lb.CombatantView? live,
    required Episode episode,
    required bool isAssistant,
  }) {
    final filled = m != null;
    final Color? bg = isAssistant
        ? (filled ? _StatusPalette.assistantBg : _StatusPalette.assistantBgEmpty)
        : (filled ? _StatusPalette.partyBg : null);
    final Color border = isAssistant
        ? _StatusPalette.assistantBorder
        : (filled ? _StatusPalette.partyBorder : _StatusPalette.emptyBorder);

    final hp = live?.hp ?? m?.hp ?? 0;
    final mp = live?.mp ?? m?.mp ?? 0;
    final condition = live != null ? _conditionOf(live) : (m?.condition ?? Condition.good);
    final stateColor = condition == Condition.good
        ? _StatusPalette.rowText
        : _StatusPalette.badText;

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _cell(
            filled ? wt.memberName(m, episode: episode) : '',
            _nameW,
            bg: bg,
            border: border,
          ),
          _cell(filled ? '$hp' : '', _numW, right: true, bg: bg, border: border),
          _cell(
            filled && m.hasMagicPool ? '$mp' : '',
            _numW,
            right: true,
            bg: bg,
            border: border,
          ),
          _cell(
            filled ? wt.conditionName(condition) : '',
            _stateW,
            right: true,
            bg: bg,
            border: border,
            color: stateColor,
          ),
        ],
      ),
    );
  }

  /// [Member.condition] 과 같은 순서 — 죽음 > 의식 불명 > 중독 > 좋음.
  static Condition _conditionOf(lb.CombatantView c) {
    if (c.dead > 0) return Condition.dead;
    if (c.unconscious > 0) return Condition.unconscious;
    if (c.poison > 0) return Condition.poisoned;
    return Condition.good;
  }

  Widget _cell(
    String text,
    double width, {
    bool right = false,
    Color? bg,
    Color? border,
    Color color = _StatusPalette.rowText,
  }) {
    return Container(
      width: width,
      height: 20,
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        border: border == null ? null : Border.all(color: border, width: 0.5),
      ),
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // 칸보다 긴 글은 잘라 내지 않고 줄여서 다 보인다 — 상태 칸(60)에 「의식 불명」이
      // 들어가지 않아 「의식 늘」로 잘렸다. 원작 2부도 상태 칸에 「의식 불명」이라 썼다.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          // 줄 높이를 글자 크기와 같게 — 칸 높이(20)보다 커서 짧은 글까지 줄어들었다.
          style: TextStyle(color: color, fontSize: HDConfig.statusFontSize, height: 1.0),
        ),
      ),
    );
  }
}
