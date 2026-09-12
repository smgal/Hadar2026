import '../contract/battle_command.dart';
import '../contract/battle_event.dart';
import '../contract/battle_result_code.dart';
import '../contract/battle_setup.dart';
import '../data/enemy_table.dart';
import '../rules/affinity.dart';
import '../rules/battle_item.dart';
import '../rules/attack_magic.dart';
import '../rules/coating.dart';
import '../rules/collapse.dart';
import '../rules/condition.dart';
import '../rules/cure.dart';
import '../rules/enemy_action.dart';
import '../rules/enemy_ai.dart';
import '../rules/esp.dart';
import '../rules/initiative.dart';
import '../rules/escape.dart';
import '../rules/physical.dart';
import '../rules/position.dart';
import '../rules/preset.dart';
import '../rules/weapon.dart';
import '../rules/rng.dart';
import '../rules/settle.dart';
import '../rules/superhuman.dart';
import '../rules/spellbook.dart';
import '../rules/vitals.dart';
import 'combatant.dart';
import 'enemy_instance.dart';

/// Where the battle is in its cycle.
enum BattlePhase {
  /// Nothing has happened yet. One `advance()` announces the enemies and
  /// opens the first round.
  intro,

  /// A decision is pending. `pendingDecision` says what, and
  /// `applyCommand` is the only legal call.
  collecting,

  /// Commands are in; each `advance()` resolves one combatant, party or
  /// enemy, in initiative order (B2-05).
  resolvingRound,

  /// `outcome` is available.
  finished,
}

/// What one party member decided to do this round. Mirrors the
/// `playerCommands[order] = [cmd, arg1, arg2]` triple the original kept
/// (`battle.dart:120`).
class _Plan {
  BattleAction action = BattleAction.skip;
  int magicId = 0;

  /// B2-06: which item, and which ally it lands on.
  String itemKey = '';
  int allySlot = -1;

  /// B6-03: for a coating vial, on the blade or at an enemy.
  ItemUse itemUse = ItemUse.coat;

  /// Enemy index, or -1 for every enemy.
  int target = 0;
}

/// What the battle is waiting to be told, during [BattlePhase.collecting].
enum _Ask {
  action,
  enemyTarget,
  spell,
  spellEnemyTarget,
  item,
  itemUse,
  allyTarget,
  order,
}

/// One battle, as a state machine.
///
/// The battle never calls out. It exposes what it is waiting for
/// ([pendingDecision]), takes the answer ([applyCommand]), and otherwise
/// moves one step at a time ([advance]), reporting what happened as
/// [BattleEvent]s. A console view and a Flutter view drive it the same
/// way; neither is visible from in here.
///
/// The original was the opposite shape: `HDBattle.start()` was one
/// `async` loop that awaited `showWindowMenu` and `waitForAnyKey` in the
/// middle of the rules (`battle.dart:112-243`), which is why the rules
/// could not run without a UI.
///
/// **Rules are unchanged from that original.** Every formula, draw order
/// and quirk is ported as it was; B1's job is the shape, not the
/// balance. The quirks that look like bugs are documented where they
/// live and are picked up by B2.
class Battle {
  /// [rng] exists for tests that need a scripted draw sequence; leave it
  /// out and the battle seeds itself from `setup.seed`.
  Battle(this.setup, {BattleRng? rng}) : _rng = rng ?? SeededRng(setup.seed) {
    for (final snapshot in setup.party) {
      _party.add(Combatant.fromSnapshot(snapshot));
    }
    for (var i = 0; i < setup.enemyKeys.length; i++) {
      final key = setup.enemyKeys[i];
      final data = enemyByKey[key];
      if (data == null) {
        throw ArgumentError('unknown enemy key: "$key"');
      }
      _enemies.add(
        EnemyInstance(
          data,
          rank: i < setup.enemyRanks.length
              ? clampRank(setup.enemyRanks[i])
              : null,
        ),
      );
    }
    _gap = clampGap(
      setup.initialGap ??
          openingGap(
            // BP-45: a heavy weapon has to be brought to bear and a crossbow
      // has to be wound, so the style shifts where in the round a member
      // acts. Folded into agility rather than given its own roll — one
      // source of order, as B2-05 argued.
      partyAgility: [
        for (final c in _party)
          c.snapshot.agility + c.snapshot.initiativeBonus,
      ],
            partyLevel: [for (final c in _party) c.snapshot.levelPhysical],
            enemyAgility: [for (final e in _enemies) e.agility],
            enemyLevel: [for (final e in _enemies) e.level],
          ),
    );
  }

  final BattleSetup setup;
  final BattleRng _rng;
  final List<Combatant> _party = [];
  final List<EnemyInstance> _enemies = [];

  /// Party members taking part, in slot order.
  List<Combatant> get party => List.unmodifiable(_party);

  /// Enemies, in the order they were registered. Indices in events refer
  /// to this list.
  List<EnemyInstance> get enemies => List.unmodifiable(_enemies);

  /// Exposed so a test can assert that a change did not add or drop a
  /// random draw.
  BattleRng get rng => _rng;

  BattlePhase get phase => _phase;
  BattlePhase _phase = BattlePhase.intro;

  /// 1-based; 0 before the first round opens.
  int get round => _round;
  int _round = 0;

  bool get isFinished => _phase == BattlePhase.finished;

  /// Null until the battle finishes.
  BattleOutcome? get outcome => _outcome;
  BattleOutcome? _outcome;

  BattleResultCode _result = BattleResultCode.none;
  int _goldGained = 0;
  final List<CombatantSnapshot> _recruits = [];
  late final Map<String, int> _held = {...setup.consumables};
  final Map<String, int> _spent = {};
  final List<int> _departedSlots = [];
  late final int _startingEnemies = _enemies.length;

  /// How far apart the two sides stand (B5-01).
  ///
  /// One number for both sides: "we advance" and "they advance" are the
  /// same event. Only formation orders move it, and both sides' orders
  /// are resolved together at the top of the round.
  int get gap => _gap;
  int _gap = 0;

  /// What the formation phase did this round, for the view.
  ({int from, int to, FormationOrder party, FormationOrder enemy})?
  _formationChange;

  final Map<int, _Plan> _plans = {};

  /// Who is asked this round, in order: **leader first, then by rank**
  /// (front to back), slot breaking ties. Indices into [_party].
  ///
  /// The original asked in slot order. Slot order is rank order at the
  /// start of a fight (`rankOf` derives one from the other), but after a
  /// charge or a knockback the two drift apart and the questions stop
  /// matching the picture. Asking front to back keeps top-to-bottom on
  /// screen equal to first-to-last in the menu (B6-07).
  List<int> _askOrder = const [];
  int _collectIx = 0;
  _Ask _ask = _Ask.action;

  /// How many times each member has come back to the action menu this
  /// round (cancelling a sub-question, picking an unaffordable skill).
  /// A person never notices; a headless policy that keeps cancelling
  /// would loop forever without it — past [_maxReturns] the turn is skipped.
  final Map<int, int> _returns = {};
  static const int _maxReturns = 8;
  bool _autoBattle = false;

  /// The leader ordered a retreat this round (B6-04). Nobody else is
  /// asked; if the roll fails the round is lost.
  bool _escaping = false;
  List<Turn> _order = const [];
  int _turnIx = 0;

  // --- driving ------------------------------------------------------

  /// What has to be answered before the battle can go on, or null when
  /// the caller should [advance] instead.
  BattleDecision? get pendingDecision {
    if (_phase != BattlePhase.collecting) return null;
    final c = _current;
    switch (_ask) {
      case _Ask.action:
        return ActionDecision(c.slot, _actionOptions(c));
      case _Ask.enemyTarget:
      case _Ask.spellEnemyTarget:
        return EnemyTargetDecision(c.slot, _aliveEnemyIndices());
      case _Ask.item:
        return ItemDecision(c.slot, usableItems(_held));
      case _Ask.itemUse:
        return ItemUseDecision(c.slot, _plans[c.slot]!.itemKey, const [
          ItemUse.coat,
          ItemUse.throwAtEnemy,
        ]);
      case _Ask.allyTarget:
        // Neediest first, so the first entry is what "whoever needs it
        // most" would have picked (B6-07).
        return AllyTargetDecision(c.slot, _presentSlotsByNeed());
      case _Ask.spell:
        return SpellDecision(c.slot, _skillsFor(c));
      case _Ask.order:
        return OrderDecision(c.slot, _orderOptions());
    }
  }

  /// Moves the battle forward by one step: the opening announcement, one
  /// party member's action, or one enemy's turn.
  ///
  /// Throws if a decision is pending — check [pendingDecision] first.
  List<BattleEvent> advance() {
    switch (_phase) {
      case BattlePhase.intro:
        final events = <BattleEvent>[
          EnemiesAppeared([for (var i = 0; i < _enemies.length; i++) i]),
        ];
        events.addAll(_beginRound());
        return events;
      case BattlePhase.collecting:
        throw StateError(
          'a decision is pending for slot ${_current.slot}; '
          'call applyCommand',
        );
      case BattlePhase.resolvingRound:
        return _resolveTurn();
      case BattlePhase.finished:
        return const [];
    }
  }

  /// Answers the pending decision.
  List<BattleEvent> applyCommand(BattleCommand command) {
    if (_phase != BattlePhase.collecting) {
      throw StateError('no decision is pending');
    }
    final c = _current;
    if (command.slot != c.slot) {
      throw ArgumentError(
        'command is for slot ${command.slot}, but slot ${c.slot} was asked',
      );
    }
    final plan = _plans.putIfAbsent(c.slot, _Plan.new);
    final events = <BattleEvent>[];

    switch (_ask) {
      case _Ask.action:
        events.addAll(_answerAction(c, plan, command));
      case _Ask.enemyTarget:
      case _Ask.spellEnemyTarget:
        events.addAll(_answerEnemyTarget(c, plan, command));
      case _Ask.spell:
        events.addAll(_answerSpell(c, plan, command));
      case _Ask.item:
        events.addAll(_answerItem(c, plan, command));
      case _Ask.itemUse:
        events.addAll(_answerItemUse(c, plan, command));
      case _Ask.allyTarget:
        events.addAll(_answerAllyTarget(c, plan, command));
      case _Ask.order:
        events.addAll(_answerOrder(c, plan, command));
    }
    return events;
  }

  // --- collection ---------------------------------------------------

  /// The battle menu — six lines (B6-01).
  ///
  /// ```
  /// attack · castSkill · useItem · [charge] · brace · [escape · orders]
  /// ```
  ///
  /// The original had a line per spell category, five of them, and
  /// treated slot 0 specially (auto-battle where everyone else got
  /// flight, `hd_base_game_main.cpp:1289`). Now every spell is under one
  /// line and the special lines belong to the **leader** — whoever is
  /// conscious and lowest in slot order, so a fallen slot 0 does not
  /// leave the party unable to move or run (B6-04).
  ///
  /// Nothing that cannot be done is offered — a charge needs a weapon
  /// that charges, the skill list needs something learned, the item line
  /// needs something in the pack. That is what keeps a wasted turn from
  /// ever being reachable through the menu.
  List<BattleAction> _actionOptions(Combatant c) => [
    BattleAction.attack,
    if (_skillsFor(c).isNotEmpty) BattleAction.castSkill,
    if (usableItems(_held).isNotEmpty) BattleAction.useItem,
    if (c.weapon.canCharge && canAdvance(c.rank)) BattleAction.charge,
    BattleAction.brace,
    if (_isLeader(c)) ...[BattleAction.escape, BattleAction.orders],
  ];

  /// The leader's orders that make sense right now (B6-01).
  List<BattleAction> _orderOptions() => [
    BattleAction.autoBattle,
    if (_gap > 0) BattleAction.advanceFormation,
    if (_gap < maxGap) BattleAction.retreatFormation,
  ];

  /// The leader is whoever is conscious and lowest in slot order (B6-04).
  ///
  /// Slot 0 by default, exactly as the original had it — but when slot 0
  /// is down the line still has to be able to move, run and hand over
  /// to auto-battle, and before B6 it could not.
  int? get _leaderSlot {
    int? best;
    for (final c in _party) {
      if (!c.isConscious) continue;
      if (best == null || c.slot < best) best = c.slot;
    }
    return best;
  }

  bool _isLeader(Combatant c) => c.slot == _leaderSlot;

  List<BattleEvent> _answerAction(
    Combatant c,
    _Plan plan,
    BattleCommand command,
  ) {
    if (command is CancelChoice) return _skip(c, plan);
    if (command is! ChooseAction) {
      throw ArgumentError('expected an action choice, got $command');
    }
    final action = command.action;
    if (!_actionOptions(c).contains(action)) {
      throw ArgumentError('action $action is not offered to slot ${c.slot}');
    }
    plan.action = action;

    if (action == BattleAction.orders) {
      _ask = _Ask.order;
      return const [];
    }
    if (action == BattleAction.escape) {
      // A party action: nobody else is asked this round (B6-04).
      _escaping = true;
      _nextMember();
      return const [];
    }
    if (action == BattleAction.brace) {
      _nextMember();
      return const [];
    }
    if (action == BattleAction.charge || action == BattleAction.attack) {
      return _askEnemyTarget(c, plan, _Ask.enemyTarget);
    }
    if (action == BattleAction.useItem) {
      if (usableItems(_held).isEmpty) return _skip(c, plan);
      _ask = _Ask.item;
      return const [];
    }
    // castSkill
    if (_skillsFor(c).isEmpty) {
      final events = <BattleEvent>[NoSpellAvailable(c.slot, action)];
      events.addAll(_skip(c, plan));
      return events;
    }
    _ask = _Ask.spell;
    return const [];
  }

  /// One of the leader's orders, answered with a [ChooseAction] (B6-01).
  List<BattleEvent> _answerOrder(
    Combatant c,
    _Plan plan,
    BattleCommand command,
  ) {
    if (command is CancelChoice) return _backToAction(c, plan);
    if (command is! ChooseAction) {
      throw ArgumentError('expected an order, got $command');
    }
    final action = command.action;
    if (!_orderOptions().contains(action)) {
      throw ArgumentError('order $action is not available to slot ${c.slot}');
    }
    plan.action = action;
    if (action == BattleAction.autoBattle) {
      _autoBattle = true;
      _planAutoAttack(c, plan);
    }
    _nextMember();
    return const [];
  }

  /// The skill list this member sees (B6-01), after B5-09's capacity
  /// check.
  ///
  /// Mind control (43) adds a party member. With the party full there
  /// is nowhere to put one, and offering it anyway would spend a turn
  /// on nothing — the one thing this whole track refuses to allow. So
  /// it comes out of the list.
  List<SkillOption> _skillsFor(Combatant c) {
    final options = skillOptions(
      levelMagic: c.snapshot.levelMagic,
      levelEsp: c.snapshot.levelEsp,
      sp: c.sp,
      esp: c.esp,
    );
    if (hasRoomToJoin) return options;
    return [
      for (final o in options)
        if (o.magicId != mindControlMagicId) o,
    ];
  }

  List<BattleEvent> _answerEnemyTarget(
    Combatant c,
    _Plan plan,
    BattleCommand command,
  ) {
    if (command is CancelChoice) return _backToAction(c, plan);
    if (command is! ChooseEnemyTarget) {
      throw ArgumentError('expected an enemy target, got $command');
    }
    // The original treated "no selection" as -1 and skipped the turn
    // (`battle.dart:105`, `:347-349`). Now it is a step back (B6-07).
    if (command.enemyIndex < 0) return _backToAction(c, plan);
    if (!_aliveEnemyIndices().contains(command.enemyIndex)) {
      throw ArgumentError('enemy ${command.enemyIndex} is not a valid target');
    }
    plan.target = command.enemyIndex;
    _nextMember();
    return const [];
  }

  List<BattleEvent> _answerSpell(
    Combatant c,
    _Plan plan,
    BattleCommand command,
  ) {
    if (command is CancelChoice) return _backToAction(c, plan);
    if (command is! ChooseSpell) {
      throw ArgumentError('expected a spell choice, got $command');
    }
    final options = _skillsFor(c);
    final chosen = options.where((o) => o.magicId == command.magicId);
    if (chosen.isEmpty) {
      throw ArgumentError(
        'skill ${command.magicId} is not castable by slot ${c.slot}',
      );
    }
    final option = chosen.first;
    // Unaffordable skills stay in the list so the player can see them;
    // picking one is refused here, not hidden (B6-01).
    if (!option.affordable) {
      // Say so and go back — a wrong pick is not a lost turn (B6-07).
      return [
        NotEnoughSpellPoints(
          c.slot,
          usesEsp: option.resource == SkillResource.esp,
        ),
        ..._backToAction(c, plan),
      ];
    }
    plan.magicId = command.magicId;

    switch (targetingFor(command.magicId)) {
      case SpellTargeting.singleEnemy:
        return _askEnemyTarget(c, plan, _Ask.spellEnemyTarget);
      case SpellTargeting.allEnemies:
      case SpellTargeting.allAllies:
        plan.target = -1;
        _nextMember();
        return const [];
      case SpellTargeting.singleAlly:
        // The original asked ("to whom"), the port dropped it and healed
        // whoever needed it most. Items ask; cures now ask too, with the
        // neediest listed first so the top entry is that default (B6-07).
        return _askAllyTarget(c, plan);
      case SpellTargeting.selfWeapon:
        plan.target = -1;
        _nextMember();
        return const [];
    }
  }

  List<BattleEvent> _answerItem(
    Combatant c,
    _Plan plan,
    BattleCommand command,
  ) {
    if (command is CancelChoice) return _backToAction(c, plan);
    if (command is! ChooseItem) {
      throw ArgumentError('expected an item choice, got \$command');
    }
    if (!usableItems(_held).contains(command.itemKey)) {
      throw ArgumentError('the party has no "\${command.itemKey}"');
    }
    plan.itemKey = command.itemKey;
    final item = battleItems[command.itemKey]!;
    if (item.targetsSelf) {
      // A vial: on the blade, or thrown? (B6-03). Before this branch the
      // vial fell through to the enemy-target question and then coated
      // the weapon anyway — the question it asked was not the one it
      // answered.
      plan.itemUse = ItemUse.coat;
      _ask = _Ask.itemUse;
      return const [];
    }
    if (item.targetsAlly) return _askAllyTarget(c, plan);
    if (!item.hitsAll) return _askEnemyTarget(c, plan, _Ask.enemyTarget);
    plan.target = -1;
    _nextMember();
    return const [];
  }

  /// Asks for an enemy — unless there is only one to pick, in which case
  /// the question would have one answer and is not asked (B6-07).
  List<BattleEvent> _askEnemyTarget(Combatant c, _Plan plan, _Ask ask) {
    final alive = _aliveEnemyIndices();
    if (alive.isEmpty) return _skip(c, plan);
    if (alive.length == 1) {
      plan.target = alive.single;
      _nextMember();
      return const [];
    }
    _ask = ask;
    return const [];
  }

  /// Asks which ally — unless there is only one present.
  List<BattleEvent> _askAllyTarget(Combatant c, _Plan plan) {
    final present = _presentSlotsByNeed();
    if (present.length == 1) {
      plan.allySlot = present.single;
      _nextMember();
      return const [];
    }
    _ask = _Ask.allyTarget;
    return const [];
  }

  /// On the weapon or at an enemy (B6-03).
  List<BattleEvent> _answerItemUse(
    Combatant c,
    _Plan plan,
    BattleCommand command,
  ) {
    if (command is CancelChoice) return _backToAction(c, plan);
    if (command is! ChooseItemUse) {
      throw ArgumentError('expected an item use, got $command');
    }
    plan.itemUse = command.use;
    if (command.use == ItemUse.throwAtEnemy) {
      return _askEnemyTarget(c, plan, _Ask.enemyTarget);
    }
    plan.target = -1;
    _nextMember();
    return const [];
  }

  List<BattleEvent> _answerAllyTarget(
    Combatant c,
    _Plan plan,
    BattleCommand command,
  ) {
    if (command is CancelChoice) return _backToAction(c, plan);
    if (command is! ChooseAllyTarget) {
      throw ArgumentError('expected an ally target, got \$command');
    }
    final present = _presentSlotsByNeed();
    if (!present.contains(command.allySlot)) {
      throw ArgumentError('slot \${command.allySlot} is not in the party');
    }
    plan.allySlot = command.allySlot;
    _nextMember();
    return const [];
  }

  /// Auto-battle: attack the first conscious enemy, decided now rather
  /// than at resolution time (`battle.dart:377-382`). The original also
  /// stored the weapon index in arg1; no rule ever read it.
  /// What a member does when the leader hands the round over (B5-08).
  ///
  /// **Automatic is blind.** It never picks a target — it takes the
  /// nearest thing standing. A preset that is simply better than
  /// playing makes not playing optimal, which is how Final Fantasy
  /// XII's gambits ended up running the game; Dragon Quest IV's AI
  /// failed the other way by being weak. Strong on average, no eyes.
  void _planAutoAttack(Combatant c, _Plan plan) {
    final preset = presetOf(c.snapshot.preset);
    final target = _firstAliveEnemy();
    if (target == -1) {
      plan.action = BattleAction.skip;
      return;
    }
    final distance = distanceBetween(
      gap: _gap,
      attackerRank: c.rank,
      targetRank: _enemies[target].rank,
    );
    if (presetWantsToCharge(
          preset: preset,
          weapon: c.weapon,
          distance: distance,
        ) &&
        canAdvance(c.rank)) {
      plan.action = BattleAction.charge;
      plan.target = target;
      return;
    }
    if (preset.bracesWhenHurt && c.hp * 2 < c.snapshot.maxHp) {
      plan.action = BattleAction.brace;
      return;
    }
    plan.action = BattleAction.attack;
    plan.target = target;
  }

  List<BattleEvent> _skip(Combatant c, _Plan plan) {
    plan.action = BattleAction.skip;
    _nextMember();
    return [ActionSkipped(c.slot)];
  }

  void _nextMember() {
    _collectIx++;
    _moveToNextAsk();
  }

  /// Walks the party to the next member that needs asking, planning the
  /// auto-battlers on the way. Switches to resolution once nobody is
  /// left to ask.
  Combatant get _current => _party[_askOrder[_collectIx]];

  /// Leader first, then front to back, then slot (B6-07).
  List<int> _buildAskOrder() {
    final leader = _leaderSlot;
    final order = [
      for (var i = 0; i < _party.length; i++)
        if (_party[i].isConscious) i,
    ];
    order.sort((a, b) {
      final ca = _party[a];
      final cb = _party[b];
      if (ca.slot == leader) return -1;
      if (cb.slot == leader) return 1;
      final byRank = ca.rank.compareTo(cb.rank);
      return byRank != 0 ? byRank : ca.slot.compareTo(cb.slot);
    });
    return order;
  }

  /// A cancelled sub-question goes back to the action menu instead of
  /// costing the turn (B6-07). The original skipped the turn on every
  /// cancel (`battle.dart:349`); that made opening the wrong menu a
  /// mistake you paid for.
  List<BattleEvent> _backToAction(Combatant c, _Plan plan) {
    final n = (_returns[c.slot] ?? 0) + 1;
    _returns[c.slot] = n;
    if (n > _maxReturns) return _skip(c, plan);
    plan
      ..action = BattleAction.skip
      ..magicId = 0
      ..itemKey = ''
      ..allySlot = -1
      ..target = 0;
    _ask = _Ask.action;
    return const [];
  }

  /// Present party members, the one most in need first: dead, then
  /// collapsed, then poisoned, then hurt, then whole; slot breaks ties.
  List<int> _presentSlotsByNeed() {
    int need(Combatant t) => switch (t.condition) {
      Condition.dead => 4,
      Condition.unconscious => 3,
      Condition.poisoned => 2,
      Condition.good => t.hp < t.snapshot.maxHp ? 1 : 0,
    };
    final present = [
      for (final t in _party)
        if (t.isPresent) t,
    ];
    present.sort((a, b) {
      final byNeed = need(b).compareTo(need(a));
      return byNeed != 0 ? byNeed : a.slot.compareTo(b.slot);
    });
    return [for (final t in present) t.slot];
  }

  void _moveToNextAsk() {
    while (_collectIx < _askOrder.length) {
      final c = _party[_askOrder[_collectIx]];
      if (!c.isConscious) {
        _collectIx++;
        continue;
      }
      if (_escaping) {
        // The leader is taking everyone out; nobody else acts (B6-04).
        _plans.putIfAbsent(c.slot, _Plan.new).action = BattleAction.skip;
        _collectIx++;
        continue;
      }
      if (_autoBattle) {
        _planAutoAttack(c, _plans.putIfAbsent(c.slot, _Plan.new));
        _collectIx++;
        continue;
      }
      _ask = _Ask.action;
      return;
    }
    _beginResolution();
  }

  // --- rounds -------------------------------------------------------

  /// The round guard, `battle.dart:122`:
  /// `while (isBattleActive && _enemiesAlive() && _playersAlive())`.
  List<BattleEvent> _beginRound() {
    if (!_enemiesAlive || !_partyAlive) return _finish();
    _round++;
    _plans.clear();
    _autoBattle = false;
    _escaping = false;
    final events = <BattleEvent>[RoundStarted(_round)];
    // Being off balance is worth one round of follow-up, no more.
    for (final e in _enemies) {
      e.staggered = false;
    }
    for (final c in _party) {
      c.staggered = false;
      c.braced = false;
      c.hitsThisRound = 0;
      // Coatings count down at the top of each round after the one they
      // were laid in, so `coatingRounds` is the number of rounds the
      // weapon actually swings coated (B6-03).
      if (_round > 1) {
        for (final coating in [...c.coatings]) {
          if (coating.rounds <= 0) {
            c.coatings.remove(coating);
            events.add(CoatingExpired(c.slot, coating.kind));
          } else {
            coating.rounds--;
          }
        }
      }
    }
    // The party's poison bites at the top of the round, before anyone
    // chooses — so a member who succumbs does not get a turn.
    events.addAll(_tickPartyPoison());
    if (!_partyAlive) {
      _result = BattleResultCode.lose;
      events.addAll(_finish());
      return events;
    }
    _phase = BattlePhase.collecting;
    _askOrder = _buildAskOrder();
    _returns.clear();
    _collectIx = 0;
    _moveToNextAsk();
    return events;
  }

  /// Resolves both sides' formation orders, then rolls initiative.
  ///
  /// The formation moves **before anyone acts** (B5-03), so the gap is
  /// settled when the round plays out and a command can be made with
  /// the distance known. That is also why it is not a turn in the
  /// initiative order — putting it there would have meant the leader
  /// had to be fastest, which would have undone B2-05.
  void _beginResolution() {
    events0:
    {
      final partyOrder = _partyFormationOrder();
      final enemyOrder = _enemyFormationOrder();
      final next = resolveFormation(
        gap: _gap,
        party: partyOrder,
        enemy: enemyOrder,
      );
      if (next != _gap ||
          partyOrder != FormationOrder.hold ||
          enemyOrder != FormationOrder.hold) {
        _formationChange = (
          from: _gap,
          to: next,
          party: partyOrder,
          enemy: enemyOrder,
        );
        _gap = next;
      } else {
        _formationChange = null;
      }
      break events0;
    }
    _order = orderOfBattle(
      partyAgility: [for (final c in _party) c.snapshot.agility],
      partyActive: [for (final c in _party) c.isConscious],
      enemyAgility: [for (final e in _enemies) e.agility],
      enemyActive: [for (final e in _enemies) e.dead == 0],
      rng: _rng,
    );
    _turnIx = 0;
    _phase = BattlePhase.resolvingRound;
  }

  /// The formation event, emitted once at the top of resolution.
  List<BattleEvent> _drainFormation() {
    final change = _formationChange;
    if (change == null) return const [];
    _formationChange = null;
    return [
      FormationResolved(
        from: change.from,
        to: change.to,
        partyAdvanced: change.party == FormationOrder.advance,
        partyRetreated: change.party == FormationOrder.retreat,
        enemyAdvanced: change.enemy == FormationOrder.advance,
        enemyRetreated: change.enemy == FormationOrder.retreat,
      ),
    ];
  }

  /// What the leader ordered, if anything.
  FormationOrder _partyFormationOrder() {
    for (final entry in _plans.entries) {
      if (entry.value.action == BattleAction.advanceFormation) {
        return FormationOrder.advance;
      }
      if (entry.value.action == BattleAction.retreatFormation) {
        return FormationOrder.retreat;
      }
    }
    return FormationOrder.hold;
  }

  /// What the enemy side wants, read off the two sides' reach.
  FormationOrder _enemyFormationOrder() {
    final alive = [
      for (final e in _enemies)
        if (e.isConscious) e,
    ];
    if (alive.isEmpty) return FormationOrder.hold;
    int longest(Iterable<int> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a > b ? a : b);
    return formationWant(
      myReach: longest([for (final e in alive) reachOf(e.weapon)]),
      theirReach: longest([
        for (final c in _party)
          if (c.isConscious) reachOf(c.weapon),
      ]),
      gap: _gap,
    );
  }

  /// Resolves one combatant's turn, whoever is next on initiative.
  ///
  /// The inherited battle ran the whole party in slot order and then
  /// every enemy — `agility` was read nowhere but the escape formula
  /// (appendix O). Now both sides are in one list.
  List<BattleEvent> _resolveTurn() {
    final opening = _drainFormation();
    if (opening.isNotEmpty) return opening;
    while (_turnIx < _order.length) {
      final turn = _order[_turnIx];
      _turnIx++;
      final events = <BattleEvent>[];

      if (turn.side == Side.party) {
        final c = _party[turn.index];
        if (!c.isConscious) continue;
        final plan = _plans[c.slot];
        if (plan == null || plan.action == BattleAction.skip) continue;
        switch (plan.action) {
          case BattleAction.advanceFormation:
          case BattleAction.retreatFormation:
            // Already spent in the formation phase; the leader has no
            // swing left this round.
            continue;
          case BattleAction.brace:
            c.braced = true;
            if (canAdvance(c.rank)) c.rank = clampRank(c.rank - 1);
            events.add(Braced(c.slot, c.rank));
          case BattleAction.charge:
            if (canAdvance(c.rank)) c.rank = clampRank(c.rank - 1);
            events.add(Charged(c.slot, c.rank));
            events.addAll(_executeAttack(c, plan.target));
          case BattleAction.attack:
          case BattleAction.autoBattle:
            events.addAll(_executeAttack(c, plan.target));
          case BattleAction.escape:
            events.addAll(_tryEscape(c));
          case BattleAction.useItem:
            events.addAll(_useItem(c, plan));
          default:
            events.addAll(_castSpell(c, plan));
        }
      } else {
        final index = turn.index;
        final e = _enemies[index];
        events.addAll(_enemyPoisonTick(index, e));
        if (e.unconscious == 0 && e.dead == 0) {
          if (e.paralyzed) {
            // A paralytic coating took hold: this turn is gone (B6-03).
            e.paralyzed = false;
            events.add(EnemyLostTurn(index));
          } else {
            events.addAll(_enemyAttack(index, e));
          }
        }
      }

      if (_result == BattleResultCode.evade) {
        events.addAll(_finish());
        return events;
      }
      if (!_enemiesAlive || !_partyAlive) {
        events.addAll(_finish());
        return events;
      }
      if (events.isEmpty) continue;
      return events;
    }

    return _beginRound();
  }

  /// One enemy's poison, at the start of its own turn.
  List<BattleEvent> _enemyPoisonTick(int index, EnemyInstance e) {
    if (e.poison <= 0) return const [];
    final wasUnconscious = e.unconscious > 0;
    final tick = applyPoisonTick(
      hp: e.hp,
      poison: e.poison,
      unconscious: e.unconscious,
      dead: e.dead,
      deathThreshold: e.deathThreshold,
    );
    e.hp = tick.hp;
    e.unconscious = tick.unconscious;
    e.dead = tick.dead;
    if (wasUnconscious) {
      return tick.outcome == CollapseOutcome.finished
          ? [EnemyDiedFromPoison(index)]
          : [EnemyPoisonTick(index, tick.damageApplied)];
    }
    return [
      EnemyPoisonTick(index, tick.damageApplied),
      if (tick.outcome == CollapseOutcome.collapsed)
        EnemyCollapsedFromPoison(index),
    ];
  }

  /// Poison on the party, once per round, before the enemies act.
  ///
  /// The inherited battle never read the party's `poison` field during
  /// combat (only the enemies'). Once collapsing became recoverable that
  /// left the party unable to die at all, so this is where the death
  /// path comes from — poison on someone already collapsed finishes
  /// them, the same rule enemies have always had.
  List<BattleEvent> _tickPartyPoison() {
    final events = <BattleEvent>[];
    for (final c in _party) {
      if (c.poison <= 0 || c.dead > 0) continue;
      final wasDown = c.unconscious > 0;
      final change = applyPoisonTick(
        hp: c.hp,
        poison: c.poison,
        unconscious: c.unconscious,
        dead: c.dead,
        deathThreshold: c.deathThreshold,
      );
      c.hp = change.hp;
      c.unconscious = change.unconscious;
      c.dead = change.dead;
      if (wasDown) {
        if (change.outcome == CollapseOutcome.finished) {
          events.add(MemberDiedFromPoison(c.slot));
        } else {
          events.add(MemberPoisonTick(c.slot, change.damageApplied));
        }
      } else {
        events.add(MemberPoisonTick(c.slot, change.damageApplied));
        if (change.outcome == CollapseOutcome.collapsed) {
          events.add(MemberCollapsedFromPoison(c.slot));
        }
      }
    }
    return events;
  }

  // --- actions ------------------------------------------------------

  /// One attack action.
  ///
  /// A pair of weapons lands **two blows**, each rolling its own accuracy
  /// and its own graze — so the style is steadier rather than harder.
  /// Summing the two powers instead would have paid for the same thing
  /// twice, which is why the RPG hands over the average and the count
  /// separately.
  ///
  /// A blow that finds nothing left to hit stops the sequence: a second
  /// swing at a dead enemy is not something the screen could explain.
  List<BattleEvent> _executeAttack(Combatant c, int requestedTarget) {
    if (c.strikes <= 1) return _executeOneBlow(c, requestedTarget);
    final events = <BattleEvent>[];
    for (var blow = 0; blow < c.strikes; blow++) {
      if (_firstAliveEnemy() == -1) break;
      events.addAll(_executeOneBlow(c, requestedTarget));
    }
    return events;
  }

  List<BattleEvent> _executeOneBlow(Combatant c, int requestedTarget) {
    var targetIx = requestedTarget;
    // `battle.dart:428-433` retargeted whenever the chosen enemy was not
    // conscious, which skipped past collapsed ones and made the finishing
    // blow below unreachable (appendix O-3). Now a collapsed target is
    // kept — only a dead or out-of-range one is replaced.
    if (targetIx < 0 ||
        targetIx >= _enemies.length ||
        _enemies[targetIx].dead > 0) {
      targetIx = _firstAliveEnemy();
      if (targetIx == -1) return const [];
    }
    final t = _enemies[targetIx];

    // A collapsed target cannot dodge or resist, so both rolls are
    // skipped and the blow lands for full damage — which piles onto the
    // accumulator rather than hit points (`rules/collapse.dart`).
    //
    // The inherited code had a special branch here that killed outright
    // (`battle.dart:437-447`) and nothing could reach it (appendix O-3).
    // With `unconscious` an accumulator there is no need for a special
    // case: finishing something off is just damage that crosses the
    // threshold. Skipping the two rolls is our judgment — an
    // unconscious enemy blocking an attack reads wrong.
    if (t.unconscious > 0 && t.dead == 0) {
      final damage = physicalDamage(
        strength: c.snapshot.strength,
        powOfWeapon: c.snapshot.powOfWeapon,
        levelPhysical: c.snapshot.levelPhysical,
        enemyAc: t.ac,
        enemyLevel: t.level,
        rng: _rng,
      );
      return _damageEnemy(
        c,
        targetIx,
        damage < 1 ? 1 : damage,
        DamageSource.physical,
      );
    }

    // How far the blow had to stretch, and whether something nearer
    // stepped into it (B5-01). Never voids the turn — see
    // `rules/position.dart`.
    final events = <BattleEvent>[];
    var attack = _pickAttack(c, _enemies[targetIx].rank);
    var reach = _strain(c.rank, _enemies[targetIx].rank, attack);
    if (!reach.penalty.isNone) {
      events.add(AttackStrained(c.slot, targetIx, reach.shortBy));
      final blocker = _nearerEnemyThan(_enemies[targetIx].rank);
      if (blocker != null && intercepts(penalty: reach.penalty, rng: _rng)) {
        events.add(AttackIntercepted(c.slot, targetIx, blocker));
        targetIx = blocker;
        // The blow lands somewhere else, so the weapon may be a better
        // fit for it — the shaft instead of the point, and so on.
        attack = _pickAttack(c, _enemies[targetIx].rank);
        reach = _strain(c.rank, _enemies[targetIx].rank, attack);
      }
    }
    final target = _enemies[targetIx];

    if (physicalAttackMisses(
      accuracyPhysical: c.snapshot.accuracyPhysical - reach.penalty.accuracy,
      rng: _rng,
    )) {
      return [...events, AttackMissed(c.slot)];
    }
    // B5-05: no more probabilistic resistance. Either the creature is
    // one of the handful weapons cannot touch, or the blow lands and
    // the graze roll decides how much of it does.
    if (immunityFor(resistance: target.resistance) == Immunity.physical) {
      return [...events, EnemyBlocked(c.slot, targetIx, BlockKind.resisted)];
    }
    final scale = grazeScale(
      accuracy: c.snapshot.accuracyPhysical - reach.penalty.accuracy,
      evasion: evasionOf(agility: target.agility, luck: 0),
      rng: _rng,
    );
    final damage = physicalDamage(
      strength: c.snapshot.strength,
      // B5-02: a weapon's close-in method is deliberately weaker than
      // its primary. That is what the shaft of a spear is worth.
      powOfWeapon:
          c.snapshot.powOfWeapon * attack.power * physicalPowerScale ~/ 100,
      levelPhysical: c.snapshot.levelPhysical,
      enemyAc: target.ac,
      enemyLevel: target.level,
      rng: _rng,
      graze: scale,
    );
    if (damage <= 0) {
      return [...events, EnemyBlocked(c.slot, targetIx, BlockKind.absorbed)];
    }

    // B5-06: the weapon's method is an element, so a physical blow goes
    // through the same chart a spell does. B6-03: a fire coating replaces
    // the method's element for the chart; poison and paralysis add their
    // effect after the blow lands.
    //
    // A pair of weapons carries a coating each, so **all of them land**.
    // Fire is the one that changes what the chart is asked; the others
    // add their effect afterwards, and a blade with poison on one edge
    // and fire on the other does both.
    final fire = c.coatings.any((x) => x.kind == Coating.fire);
    final element = fire ? Element.fire : attack.element;
    events.addAll(
      _damageEnemyWithElement(
        c,
        targetIx,
        damage,
        element,
        source: DamageSource.physical,
      ),
    );
    for (final coating in c.coatings) {
      if (coating.kind == Coating.fire) continue;
      events.addAll(_applyCoatingOnHit(c, targetIx, coating.kind));
    }
    return events;
  }

  /// Lays a coating on, and says what it pushed off.
  ///
  /// A single weapon has one slot, so a new coating replaces the old one
  /// exactly as before. A pair has two, so poison and fire can be
  /// carried at once — that is the reason for the style, and the screen
  /// already reports the second slot, so the rules have to honour it.
  List<BattleEvent> _layCoating(Combatant c, Coating kind) {
    final evicted = c.applyCoating(kind);
    return [
      if (evicted != null) CoatingExpired(c.slot, evicted.kind),
      WeaponCoated(c.slot, kind, rounds: coatingRounds),
    ];
  }

  /// What a poisoned or paralytic edge does once it has cut (B6-03).
  List<BattleEvent> _applyCoatingOnHit(Combatant c, int index, Coating kind) {
    final t = _enemies[index];
    if (t.dead > 0) return const [];
    if (!coatingTakesHold(kind: kind, resistance: t.resistance, rng: _rng)) {
      return [CoatingResisted(c.slot, index, kind)];
    }
    switch (kind) {
      case Coating.poison:
        t.poison += coatingPoisonPerHit;
        return [EnemyPoisoned(index)];
      case Coating.paralysis:
        t.paralyzed = true;
        return [EnemyStunned(c.slot, index)];
      case Coating.fire:
        return const [];
    }
  }

  // --- reach (B5-01) ------------------------------------------------

  /// The way this member's weapon is best used against that rank.
  ///
  /// Always returns something — a long weapon that cannot be brought to
  /// bear still has its shaft, which is the whole reason weapons carry
  /// a second method instead of a sidearm slot in an equipment screen.
  WeaponAttack _pickAttack(Combatant c, int targetRank) => chooseAttack(
    c.weapon,
    distanceBetween(gap: _gap, attackerRank: c.rank, targetRank: targetRank),
  );

  /// How far outside its band a chosen attack is, and what that costs.
  ({int shortBy, ReachPenalty penalty}) _strain(
    int attackerRank,
    int targetRank,
    WeaponAttack attack,
  ) {
    final distance = distanceBetween(
      gap: _gap,
      attackerRank: attackerRank,
      targetRank: targetRank,
    );
    final shortBy = attack.shortfall(distance);
    return (shortBy: shortBy, penalty: reachPenalty(shortBy));
  }

  /// A conscious enemy standing nearer than [rank], if there is one.
  ///
  /// Nearest first, so clearing the front is what opens the way in.
  int? _nearerEnemyThan(int rank) {
    int? best;
    for (var i = 0; i < _enemies.length; i++) {
      final e = _enemies[i];
      if (!e.isConscious || e.rank >= rank) continue;
      if (best == null || e.rank < _enemies[best].rank) best = i;
    }
    return best;
  }

  /// A conscious party member standing nearer than [rank].
  Combatant? _nearerMemberThan(int rank) {
    Combatant? best;
    for (final c in _party) {
      if (!c.isConscious || c.rank >= rank) continue;
      if (best == null || c.rank < best.rank) best = c;
    }
    return best;
  }

  /// Applies damage to one enemy through the shared collapse rule and
  /// reports it. Both the weapon and the spell paths go through here, so
  /// they cannot drift apart again the way they had (appendix O-4).
  List<BattleEvent> _damageEnemy(
    Combatant c,
    int index,
    int damage,
    DamageSource source,
  ) {
    final t = _enemies[index];
    final wasDown = t.unconscious > 0;
    final change = applyDamage(
      hp: t.hp,
      unconscious: t.unconscious,
      dead: t.dead,
      amount: damage,
      deathThreshold: t.deathThreshold,
    );
    t.hp = change.hp;
    t.unconscious = change.unconscious;
    t.dead = change.dead;

    final events = <BattleEvent>[
      EnemyDamaged(
        c.slot,
        index,
        change.damageApplied,
        source,
        whileCollapsed: wasDown,
      ),
    ];
    if (change.outcome == CollapseOutcome.collapsed) {
      events.add(EnemyCollapsed(c.slot, index, source));
      // Awarded when the enemy stops fighting, not when it dies. The
      // inherited battle paid it on a weapon kill and paid nothing at
      // all for a spell kill (appendix O-4); a target left collapsed at
      // the end of a battle would have been worth nothing.
      c.experienceGained += killExperience(enemyLevel: t.level);
    } else if (change.outcome == CollapseOutcome.finished) {
      events.add(EnemyFinished(c.slot, index));
    }
    return events;
  }

  /// Dispatches whatever spell was chosen.
  ///
  /// B2-01 replaced the two catch-all formulas the port shipped with
  /// (`rules/magic.dart`) — every attack spell now has its own damage
  /// and its own cost, and the special six take capabilities away
  /// instead of dealing damage. ESP (41-45) is still on the old formula
  /// until B2-10.
  List<BattleEvent> _castSpell(Combatant c, _Plan plan) {
    final id = plan.magicId;
    final events = <BattleEvent>[SpellCast(c.slot, id)];

    // Dispatch is by id now, not by which menu opened (B6-01).
    if (id == coatingSpellId) {
      events.addAll(_castCoating(c));
    } else if (id >= 19 && id <= 32) {
      events.addAll(_castCure(c, id, allySlot: plan.allySlot));
    } else if (isCurse(id) || id == abilityDrainSpellId) {
      events.addAll(_castDebuff(c, plan));
    } else if (id >= 1 && id <= 12) {
      events.addAll(_castAttackMagic(c, plan));
    } else {
      events.addAll(_castEsp(c, plan));
    }
    return events;
  }

  /// The poison spell as a weapon coating (B6-02 · B6-03).
  ///
  /// Same effect as a vial of poison, paid for in spell points instead of
  /// an item — two roads to one place, which is what makes "poison on the
  /// blade" a category rather than a single spell.
  List<BattleEvent> _castCoating(Combatant c) {
    if (c.sp < coatingSpellCost) {
      return [NotEnoughSpellPoints(c.slot, usesEsp: false)];
    }
    c.sp -= coatingSpellCost;
    return _layCoating(c, Coating.poison);
  }

  /// Single-target and area attack magic (1-12).
  ///
  /// Area magic charges and rolls **per enemy**, because the original
  /// implemented it as a loop over `castSpellToOne`
  /// (`hd_class_pc_player.cpp` `castSpellToAll`). So it is expensive and
  /// can run the caster dry partway through — which is the trade for
  /// hitting everything.
  ///
  /// It also reaches enemies that have already collapsed (anything not
  /// dead), where a single target would too. They take the damage on the
  /// accumulator like any other blow (`rules/collapse.dart`).
  List<BattleEvent> _castAttackMagic(Combatant c, _Plan plan) {
    final group = magicGroupOf(plan.magicId);
    if (group == null) return const [];
    final category = attackMagicCategories[group]!;
    final index = category.indexOf(plan.magicId);
    if (index == 0) return const [];

    final targets = group == MagicGroup.area
        ? [
            for (var i = 0; i < _enemies.length; i++)
              if (_enemies[i].dead == 0) i,
          ]
        : [_resolveSpellTarget(plan.target)];

    final events = <BattleEvent>[];
    for (final targetIx in targets) {
      if (targetIx < 0) continue;
      final cost = attackSpellCost(
        spellIndex: index,
        magicLevel: c.snapshot.levelMagic,
      );
      if (c.sp < cost) {
        events.add(NotEnoughSpellPoints(c.slot, usesEsp: false));
        break;
      }
      c.sp -= cost;

      if (magicAttackMisses(
        accuracyMagic: c.snapshot.accuracyMagic,
        rng: _rng,
      )) {
        events.add(SpellMissed(c.slot, plan.magicId, targetIx));
        continue;
      }
      final t = _enemies[targetIx];
      if (enemyResistsMagic(enemyResistance: t.resistance, rng: _rng)) {
        events.add(
          EnemyBlocked(
            c.slot,
            targetIx,
            BlockKind.resisted,
            source: DamageSource.spell,
          ),
        );
        continue;
      }
      final damage =
          attackSpellPower(
            spellIndex: index,
            magicLevel: c.snapshot.levelMagic,
          ) -
          magicDefence(enemyAc: t.ac, enemyLevel: t.level, rng: _rng);
      if (damage <= 0) {
        events.add(
          EnemyBlocked(
            c.slot,
            targetIx,
            BlockKind.absorbed,
            source: DamageSource.spell,
          ),
        );
        continue;
      }
      events.addAll(
        _damageEnemyWithElement(
          c,
          targetIx,
          damage,
          spellElement(plan.magicId),
        ),
      );
    }
    return events;
  }

  /// Special magic (13-18): takes a capability away rather than hit
  /// points. `rules/attack_magic.dart` holds the per-spell rolls.
  List<BattleEvent> _castDebuff(Combatant c, _Plan plan) {
    final targetIx = _resolveSpellTarget(plan.target);
    if (targetIx < 0) return const [];
    final t = _enemies[targetIx];

    // 능력 저하 (16) is ESP after B6-02: same rolls, other pool.
    final usesEsp = plan.magicId == abilityDrainSpellId;
    final result = castDebuff(
      plan.magicId,
      stats: EnemyStats(
        ac: t.ac,
        resistance: t.resistance,
        level: t.level,
        castLevel: t.castLevel,
        specialCastLevel: t.specialCastLevel,
        special: t.special,
        poison: t.poison,
      ),
      accuracyMagic: usesEsp
          ? c.snapshot.accuracyEsp
          : c.snapshot.accuracyMagic,
      casterSp: usesEsp ? c.esp : c.sp,
      rng: _rng,
    );
    if (usesEsp) {
      c.esp -= result.spSpent;
    } else {
      c.sp -= result.spSpent;
    }

    switch (result.outcome) {
      case DebuffOutcome.notAffordable:
        return [NotEnoughSpellPoints(c.slot, usesEsp: usesEsp)];
      case DebuffOutcome.resisted:
        return [DebuffFailed(c.slot, plan.magicId, targetIx, resisted: true)];
      case DebuffOutcome.missed:
        return [DebuffFailed(c.slot, plan.magicId, targetIx, resisted: false)];
      case DebuffOutcome.applied:
        final before = t.ac;
        final beforeCast = t.castLevel;
        final beforeSuper = t.specialCastLevel;
        t.ac = result.stats.ac;
        t.resistance = result.stats.resistance;
        t.level = result.stats.level;
        t.castLevel = result.stats.castLevel;
        t.specialCastLevel = result.stats.specialCastLevel;
        t.special = result.stats.special;
        t.poison = result.stats.poison;

        final detail = switch (plan.magicId) {
          13 => DebuffDetail.poisonStacked,
          14 => DebuffDetail.specialRemoved,
          15 =>
            t.ac < before
                ? DebuffDetail.armourLowered
                : DebuffDetail.resistanceLowered,
          16 => DebuffDetail.abilityLowered,
          17 =>
            t.castLevel < beforeCast && t.castLevel == 0
                ? DebuffDetail.castingRemoved
                : DebuffDetail.castingLowered,
          _ =>
            t.specialCastLevel < beforeSuper && t.specialCastLevel == 0
                ? DebuffDetail.superhumanRemoved
                : DebuffDetail.superhumanLowered,
        };
        return [DebuffApplied(c.slot, plan.magicId, targetIx, detail)];
    }
  }

  /// ESP in battle (B2-10) — magic 41-45.
  ///
  /// Three of the five do nothing in combat, one recruits, one rolls a
  /// table. `rules/esp.dart` holds the rules.
  List<BattleEvent> _castEsp(Combatant c, _Plan plan) {
    final ability = espAbilityFor(plan.magicId);
    if (ability == null) return const [];

    switch (ability) {
      case EspAbility.inert:
        return [EspHadNoEffect(c.slot, plan.magicId)];
      case EspAbility.mindControl:
        return _mindControl(c, plan);
      case EspAbility.psychokinesis:
        return _psychokinesis(c, plan);
    }
  }

  List<BattleEvent> _mindControl(Combatant c, _Plan plan) {
    final targetIx = _resolveSpellTarget(plan.target);
    if (targetIx < 0) return const [];
    final t = _enemies[targetIx];

    final outcome = resolveMindControl(
      enemyLegacyId: t.data.legacyId,
      enemyLevel: t.level,
      espLevel: c.snapshot.levelEsp,
      accuracyEsp: c.snapshot.accuracyEsp,
      casterEsp: c.esp,
      rng: _rng,
    );
    if (outcome != MindControlOutcome.notAffordable) {
      c.esp -= espCost(EspAbility.mindControl);
    }
    switch (outcome) {
      case MindControlOutcome.recruited:
        // B5-09 seats them instead of wiping them. B2-10 handed over a
        // `slot: -1` snapshot and left the RPG to find room, which made
        // "the party is full" impossible to decide while the fight was
        // still running — and being full is why a capacity exists.
        final seat = _freeSlot()!;
        final joined = _snapshotOfEnemy(t, slot: seat, rank: t.rank);
        _party.add(Combatant.fromSnapshot(joined));
        _recruits.add(joined);
        // Gone from the other side of the line, not dead.
        t.dead = 1;
        t.unconscious = 1;
        t.hp = 0;
        t.level = 0;
        return [EnemyRecruited(c.slot, targetIx)];
      case MindControlOutcome.immune:
        return [MindControlFailed(c.slot, targetIx, MindControlFailure.immune)];
      case MindControlOutcome.outmatched:
        return [
          MindControlFailed(c.slot, targetIx, MindControlFailure.outmatched),
        ];
      case MindControlOutcome.unmoved:
        return [
          MindControlFailed(c.slot, targetIx, MindControlFailure.unmoved),
        ];
      case MindControlOutcome.notAffordable:
        return [
          MindControlFailed(c.slot, targetIx, MindControlFailure.notAffordable),
        ];
    }
  }

  /// Turns a recruited enemy into a party snapshot the RPG can install.
  ///
  /// Enemies carry no spell points, weapon or accuracy split, so those
  /// come out as zeroes — the RPG decides what a recruit is worth when
  /// it finds them a slot (B3).
  /// The free slots, recomputed each time — a member dragged away
  /// (`departedSlots`) gives theirs back.
  int? _freeSlot() {
    final taken = {
      for (final c in _party)
        if (!c.departed) c.slot,
    };
    for (var i = 0; i < setup.partyCapacity; i++) {
      if (!taken.contains(i)) return i;
    }
    return null;
  }

  /// Whether anyone else can join. Read before the menu offers an
  /// ability that would add someone, so a full party never turns a turn
  /// into nothing.
  bool get hasRoomToJoin => _freeSlot() != null;

  CombatantSnapshot _snapshotOfEnemy(
    EnemyInstance e, {
    int slot = -1,
    int rank = 1,
  }) => CombatantSnapshot(
    slot: slot,
    rank: rank,
    name: e.name,
    strength: e.strength,
    mentality: e.mentality,
    endurance: e.endurance,
    resistance: e.resistance,
    agility: e.agility,
    ac: e.ac,
    hp: e.hp <= 0 ? 1 : e.hp,
    maxHp: e.endurance * e.level,
    accuracyPhysical: e.accuracy[0],
    accuracyMagic: e.accuracy[1],
    levelPhysical: e.level,
    powOfWeapon: 1,
  );

  List<BattleEvent> _psychokinesis(Combatant c, _Plan plan) {
    if (c.esp < espCost(EspAbility.psychokinesis)) {
      return [NotEnoughSpellPoints(c.slot, usesEsp: true)];
    }
    c.esp -= espCost(EspAbility.psychokinesis);

    final roll = rollPsychokinesis(espLevel: c.snapshot.levelEsp, rng: _rng);
    final effect = psychokineticEffect(roll);
    final kind = switch (effect) {
      PsychokineticEffect.strikeOne => PsychokinesisKind.strikeOne,
      PsychokineticEffect.strikeAll => PsychokinesisKind.strikeAll,
      PsychokineticEffect.terrify => PsychokinesisKind.terrify,
      PsychokineticEffect.poison => PsychokinesisKind.poison,
      PsychokineticEffect.stopHeart => PsychokinesisKind.stopHeart,
      PsychokineticEffect.illusion => PsychokinesisKind.illusion,
    };
    final events = <BattleEvent>[PsychokinesisRolled(c.slot, roll, kind)];

    if (effect == PsychokineticEffect.strikeAll) {
      final damage = psychokineticDamage(roll);
      for (var i = 0; i < _enemies.length; i++) {
        if (_enemies[i].dead > 0) continue;
        events.addAll(_damageEnemy(c, i, damage, DamageSource.spell));
      }
      return events;
    }

    final targetIx = _resolveSpellTarget(plan.target);
    if (targetIx < 0) return events;
    final t = _enemies[targetIx];

    if (effect == PsychokineticEffect.strikeOne) {
      events.addAll(
        _damageEnemy(
          c,
          targetIx,
          psychokineticDamage(roll),
          DamageSource.spell,
        ),
      );
      return events;
    }

    final rolls = psychokineticRolls(effect);
    final resisted = _rng.next(rolls.resistRange) < t.resistance;
    final missed =
        !resisted && _rng.next(rolls.accuracyRange) > c.snapshot.accuracyEsp;

    if (resisted || missed) {
      // The failure branches still leave a mark — that is what keeps a
      // bad roll from wasting the turn.
      switch (psychokineticConsolation(effect, resisted: resisted)) {
        case PsychokineticConsolation.none:
          break;
        case PsychokineticConsolation.resistanceDown:
          t.resistance = reduceStat(t.resistance, 5);
          events.add(EnemyWeakened(targetIx, WeakenedStat.resistance));
        case PsychokineticConsolation.enduranceDown:
          t.endurance = reduceStat(t.endurance, 5);
          events.add(EnemyWeakened(targetIx, WeakenedStat.endurance));
        case PsychokineticConsolation.agilityDown:
          t.agility = reduceStat(t.agility, 5);
          events.add(EnemyWeakened(targetIx, WeakenedStat.agility));
        case PsychokineticConsolation.chipDamage:
          events.addAll(_damageEnemy(c, targetIx, 10, DamageSource.spell));
      }
      return events;
    }

    switch (effect) {
      case PsychokineticEffect.terrify:
        t.dead = 1;
        events.add(EnemyFled(targetIx));
      case PsychokineticEffect.poison:
        t.poison += 1;
        events.add(EnemyPoisoned(targetIx));
      case PsychokineticEffect.stopHeart:
        // Adds straight to the accumulator without touching hit points,
        // so a standing enemy collapses with its health intact (B2-03).
        t.unconscious += 1;
        events.add(EnemyWeakened(targetIx, WeakenedStat.heart));
      case PsychokineticEffect.illusion:
        for (var i = 0; i < t.accuracy.length; i++) {
          t.accuracy[i] = reduceStat(t.accuracy[i], 1);
        }
        events.add(EnemyWeakened(targetIx, WeakenedStat.accuracy));
      case PsychokineticEffect.strikeOne:
      case PsychokineticEffect.strikeAll:
        break;
    }
    return events;
  }

  /// The extra turn a superhuman caster takes (B2-11).
  ///
  /// Three tiers that all keep rolling at the higher levels. Two of them
  /// change the party roster, which is why the outcome carries
  /// `recruits` and `departedSlots`.
  List<BattleEvent> _superhumanCast(int index, EnemyInstance e) {
    final events = <BattleEvent>[EnemyUsedSpecial(index)];
    final tiers = tiersFor(specialCastLevel: e.specialCastLevel);
    final notDead = _enemies.where((x) => x.dead == 0).length;

    if (tiers.contains(SuperhumanTier.summon) &&
        _enemies.length < summonLimit(startingEnemies: _startingEnemies) &&
        summonFires(notDeadEnemies: notDead, rng: _rng)) {
      final id = summonedLegacyId(
        casterLegacyId: e.data.legacyId,
        tableSize: enemyTable.length,
        rng: _rng,
      );
      final data = id == null ? null : enemyByLegacyId[id];
      if (data != null) {
        _enemies.add(EnemyInstance(data)..summoned = true);
        events.add(EnemySummoned(index, _enemies.length - 1));
      }
    }

    if (tiers.contains(SuperhumanTier.abduct)) {
      final present = [
        for (final c in _party)
          if (c.isPresent) c,
      ];
      if (abductFires(
        hasValidMember: present.isNotEmpty,
        notDeadEnemies: notDead,
        rng: _rng,
      )) {
        // The original takes the **last** valid member.
        final victim = present.last;
        victim.departed = true;
        _departedSlots.add(victim.slot);
        events.add(MemberAbducted(index, victim.slot));
      }
    }

    if (tiers.contains(SuperhumanTier.massSlay) &&
        massSlayFires(special: e.special, rng: _rng)) {
      for (final c in _party) {
        if (!c.isPresent || c.dead > 0) continue;
        final outcome = resolveSpecialAbility(
          EnemySpecial.slay,
          enemyAgility: e.agility,
          targetLuck: c.snapshot.luck,
          rng: _rng,
        );
        switch (outcome) {
          case SpecialAbilityOutcome.applied:
            c.dead = 1;
            if (c.hp > 0) c.hp = 0;
            events.add(MemberStruckDown(c.slot, killed: true));
          case SpecialAbilityOutcome.luckSaved:
            events.add(MemberLuckSaved(c.slot));
          case SpecialAbilityOutcome.missed:
          case SpecialAbilityOutcome.noTarget:
            break;
        }
      }
    }
    return events;
  }

  /// Keeps a collapsed target, replaces a dead or out-of-range one.  /// Keeps a collapsed target, replaces a dead or out-of-range one.
  int _resolveSpellTarget(int requested) {
    if (requested < 0 ||
        requested >= _enemies.length ||
        _enemies[requested].dead > 0) {
      return _firstAliveEnemy();
    }
    return requested;
  }

  /// Uses a carried item (B2-06).
  ///
  /// Medical items run the same cure steps the spells do, so the
  /// ordering rule holds — an antidote before a heal. Crystals deal
  /// elemental damage. Neither costs spell points, which is why an
  /// item is worth carrying: a character with no magic can still act
  /// (appendix R-5 is the case where a cure spell refuses).
  List<BattleEvent> _useItem(Combatant c, _Plan plan) {
    final item = battleItems[plan.itemKey];
    if (item == null) return const [];
    final held = _held[plan.itemKey] ?? 0;
    if (held <= 0) return const [];
    _held[plan.itemKey] = held - 1;
    _spent[plan.itemKey] = (_spent[plan.itemKey] ?? 0) + 1;

    final events = <BattleEvent>[ItemUsed(c.slot, plan.itemKey)];

    if (item.targetsSelf) {
      final kind = item.coating!;
      if (plan.itemUse == ItemUse.throwAtEnemy) {
        // Thrown: the effect once, right now (B6-03). Fire is damage
        // through the chart; poison and paralysis are what one coated hit
        // would have done.
        final ix = _resolveSpellTarget(plan.target);
        if (ix < 0) return events;
        events.add(VialThrown(c.slot, ix, kind));
        if (kind == Coating.fire) {
          events.addAll(
            _damageEnemyWithElement(c, ix, vialThrowDamage, Element.fire),
          );
        } else {
          events.addAll(_applyCoatingOnHit(c, ix, kind));
        }
        return events;
      }
      // On the blade. A pair of weapons holds one each.
      events.addAll(_layCoating(c, kind));
      return events;
    }

    if (item.targetsAlly) {
      final target = _party.firstWhere(
        (t) => t.slot == plan.allySlot,
        orElse: () => c,
      );
      if (item.spRestore > 0) {
        // B6-05: spell points back. Capped at the maximum, reported as
        // what actually came back.
        final before = target.sp;
        target.sp = (target.sp + item.spRestore).clamp(
          0,
          target.snapshot.maxSp,
        );
        final gained = target.sp - before;
        events.add(
          gained > 0
              ? MemberSpRestored(target.slot, gained)
              : CureHadNoEffect(c.slot, 0),
        );
        return events;
      }
      for (final step in item.cureSteps) {
        final result = applyCureStep(
          step,
          hp: target.hp,
          maxHp: target.snapshot.maxHp,
          poison: target.poison,
          unconscious: target.unconscious,
          dead: target.dead,
          deathThreshold: target.deathThreshold,
          // Items pay nothing, so the affordability gate is out of the
          // way; the potency comes from the item.
          casterSp: 1 << 30,
          casterMagicLevel: item.healPower,
        );
        target.hp = result.hp;
        target.poison = result.poison;
        target.unconscious = result.unconscious;
        target.dead = result.dead;
        if (!result.applied) continue;
        switch (step) {
          case CureStep.heal:
            events.add(MemberHealed(target.slot, result.amount));
          case CureStep.antidote:
            events.add(MemberCured(target.slot));
          case CureStep.recoverConsciousness:
            events.add(MemberRevived(target.slot));
          case CureStep.revitalize:
            events.add(MemberResurrected(target.slot));
        }
      }
      if (events.length == 1) events.add(CureHadNoEffect(c.slot, 0));
      return events;
    }

    final targets = item.hitsAll
        ? [
            for (var i = 0; i < _enemies.length; i++)
              if (_enemies[i].dead == 0) i,
          ]
        : [_resolveSpellTarget(plan.target)];
    for (final ix in targets) {
      if (ix < 0) continue;
      events.addAll(_damageEnemyWithElement(c, ix, item.damage, Element.fire));
    }
    return events;
  }

  /// The whole affinity chart for one enemy — magical and physical
  /// merged (B5-06). One chart, not two.
  Affinity _affinityOf(EnemyInstance t) => fullAffinityOf(
    key: t.key,
    strength: t.data.strength,
    ac: t.data.ac,
    agility: t.data.agility,
    endurance: t.data.endurance,
  );

  /// Applies damage after elemental affinity (B2-09, extended by B5-06).
  List<BattleEvent> _damageEnemyWithElement(
    Combatant c,
    int index,
    int damage,
    Element element, {
    DamageSource source = DamageSource.spell,
  }) {
    final t = _enemies[index];
    final affinity = _affinityOf(t);
    final moved = applyAffinity(
      damage: damage,
      element: element,
      affinity: affinity,
    );
    final events = <BattleEvent>[];
    final result = affinityResult(element: element, affinity: affinity);
    if (result != AffinityResult.neutral) {
      events.add(
        AffinityApplied(
          index,
          switch (element) {
            Element.fire => ElementKind.fire,
            Element.ice => ElementKind.ice,
            Element.lightning => ElementKind.lightning,
            Element.force => ElementKind.force,
            Element.mind => ElementKind.mind,
            Element.poison => ElementKind.poison,
            Element.slash => ElementKind.slash,
            Element.pierce => ElementKind.pierce,
            Element.blunt => ElementKind.blunt,
            Element.none => ElementKind.force,
          },
          result == AffinityResult.weak
              ? AffinityKind.weak
              : AffinityKind.resisted,
        ),
      );
    }
    if (moved <= 0) {
      events.add(
        EnemyBlocked(c.slot, index, BlockKind.absorbed, source: source),
      );
      return events;
    }

    // B5-06: hitting a weakness moves the line. Without a press-turn to
    // hand out, extra damage is arithmetic — driving something back a
    // rank is an event, and it is what makes elements and position one
    // system instead of two bolted together.
    var landed = moved;
    if (knocksBack(element, hitWeakness: result == AffinityResult.weak)) {
      if (pushBack(t.rank) == PushResult.moved) {
        t.rank = clampRank(t.rank + 1);
        t.staggered = true;
        events.add(EnemyPushedBack(index, t.rank));
      } else {
        final extra = moved * corneredBonusPercent ~/ 100;
        landed += extra;
        events.add(EnemyCornered(index, extra));
      }
    } else if (t.staggered) {
      // Off balance from an earlier push. State, not sequence — see
      // `staggerBonusPercent`.
      landed += moved * staggerBonusPercent ~/ 100;
    }
    events.addAll(_damageEnemy(c, index, landed, source));
    return events;
  }

  /// Runs a cure spell — `rules/cure.dart` holds the composition table
  /// and the per-step rules.
  ///
  /// The original resolved cures during command collection rather than
  /// in the resolution phase (`hd_base_game_main.cpp` case 5 calls
  /// `castCureSpell()` on the spot). Here it resolves with everything
  /// else, which changes when it lands but not what it does — and it is
  /// what lets the view render it like any other action.
  List<BattleEvent> _castCure(Combatant c, int magicId, {int allySlot = -1}) {
    final steps = cureStepsFor(magicId);
    if (steps.isEmpty) return const [];

    final targets = cureTargetsAll(magicId)
        ? [
            for (final t in _party)
              if (t.name.isNotEmpty) t,
          ]
        : [
            allySlot >= 0
                ? _party.firstWhere(
                    (t) => t.slot == allySlot,
                    orElse: () => _cureTargetFor(c),
                  )
                : _cureTargetFor(c),
          ];

    final events = <BattleEvent>[];
    var helped = false;
    var shortOfSp = false;

    for (final t in targets) {
      final result = applyCure(
        magicId,
        hp: t.hp,
        maxHp: t.snapshot.maxHp,
        poison: t.poison,
        unconscious: t.unconscious,
        dead: t.dead,
        deathThreshold: t.deathThreshold,
        casterSp: c.sp,
        casterMagicLevel: c.snapshot.levelMagic,
      );

      t.hp = result.hp;
      t.poison = result.poison;
      t.unconscious = result.unconscious;
      t.dead = result.dead;
      c.sp -= result.spSpent;

      for (final step in result.steps) {
        if (!step.applied) {
          if (step.shortOfSp) shortOfSp = true;
          continue;
        }
        helped = true;
        switch (step.step) {
          case CureStep.heal:
            events.add(MemberHealed(t.slot, step.amount));
          case CureStep.antidote:
            events.add(MemberCured(t.slot));
          case CureStep.recoverConsciousness:
            events.add(MemberRevived(t.slot));
          case CureStep.revitalize:
            events.add(MemberResurrected(t.slot));
        }
      }
    }

    if (!helped) {
      events.add(
        shortOfSp
            ? NotEnoughSpellPoints(c.slot, usesEsp: false)
            : CureHadNoEffect(c.slot, magicId),
      );
    }
    return events;
  }

  /// Who a single-target cure lands on.
  ///
  /// The original asked (`castCureSpell` opens with a "to whom" menu)
  /// but the Dart battle never did — it dropped the question and the
  /// heal branch ignored the field entirely. Rather than invent a new
  /// decision step here, the cure goes to **whoever needs it most**:
  /// dead, then collapsed, then poisoned, then most hurt, then the
  /// caster. B2-06 is where an explicit ally-target question belongs,
  /// alongside the item menu.
  Combatant _cureTargetFor(Combatant caster) {
    Combatant? best;
    var bestRank = -1;
    for (final t in _party) {
      if (t.name.isEmpty) continue;
      final rank = switch (t.condition) {
        Condition.dead => 4,
        Condition.unconscious => 3,
        Condition.poisoned => 2,
        Condition.good => t.hp < t.snapshot.maxHp ? 1 : 0,
      };
      if (rank > bestRank) {
        bestRank = rank;
        best = t;
      }
    }
    return best ?? caster;
  }

  /// The party runs, on the leader's word (B6-04).
  ///
  /// One roll for everyone, on the party's average agility and luck, with
  /// the gap between the lines counting for it. Failure costs the whole
  /// round — the others were never asked what they wanted to do.
  List<BattleEvent> _tryEscape(Combatant c) {
    final events = <BattleEvent>[EscapeAttempted(c.slot, gap: _gap)];
    final average = averageEnemyAgility([
      for (final e in _enemies)
        if (e.isConscious) e.agility,
    ]);
    final conscious = [
      for (final m in _party)
        if (m.isConscious) m,
    ];
    if (escapeSucceeds(
      agility: averageOf([for (final m in conscious) m.snapshot.agility]),
      luck: averageOf([for (final m in conscious) m.snapshot.luck]),
      averageEnemyAgility: average,
      gap: _gap,
      rng: _rng,
    )) {
      _result = BattleResultCode.evade;
      events.add(EscapeSucceeded(c.slot));
    } else {
      events.add(EscapeFailed(c.slot));
    }
    return events;
  }

  /// One enemy's turn, following `PcEnemy::attack` (B2-07).
  ///
  /// A `specialCastLevel` enemy gets a superhuman cast **and then** its
  /// normal turn — the original has no `return` between them. The
  /// superhuman cast itself (summoning, abducting a party member) is
  /// B2-11; for now the extra turn is announced and skipped.
  List<BattleEvent> _enemyAttack(int index, EnemyInstance e) {
    final events = <BattleEvent>[];
    final conscious = [
      for (final c in _party)
        if (c.isConscious) c,
    ];
    if (conscious.isEmpty) return events;

    if (hasSuperhumanTurn(specialCastLevel: e.specialCastLevel)) {
      events.addAll(_superhumanCast(index, e));
      if (!_partyAlive) return events;
    }

    // B5-08: a coward that has wandered into something far above it
    // leaves before it has already lost. `EnemyFled` was already there
    // — B2-10's terror effect uses it — so this needed a condition and
    // no new event.
    final preset = e.preset;
    final partyLevel = conscious.isEmpty
        ? 0
        : conscious.fold(0, (a, c) => a + c.snapshot.levelPhysical) ~/
              conscious.length;
    if (presetWantsToFlee(
      preset: preset,
      myLevel: e.level,
      theirLevel: partyLevel,
    )) {
      e.dead = 1;
      return [...events, EnemyFled(index)];
    }

    final intent = chooseEnemyIntent(
      special: e.special,
      castLevel: e.castLevel,
      strength: e.strength,
      agility: e.agility,
      accuracyPhysical: e.accuracy[0],
      accuracyMagical: e.accuracy[1],
      consciousPlayers: conscious.length,
      rng: _rng,
    );

    switch (intent) {
      case EnemyIntent.special:
        events.addAll(_enemyUseAbility(index, e));
      case EnemyIntent.cast:
        events.addAll(_enemyCast(index, e));
      case EnemyIntent.weapon:
        events.addAll(_enemyWeapon(index, e, conscious));
    }
    return events;
  }

  /// A plain weapon swing — the port's whole enemy turn, now one branch.
  List<BattleEvent> _enemyWeapon(
    int index,
    EnemyInstance e,
    List<Combatant> conscious,
  ) {
    // B5-04: nearer is likelier. The uniform draw the port inherited is
    // why the party order screen had no effect on a battle.
    final weapon = e.weapon;
    var t =
        conscious[pickByRank(
          candidateRanks: [for (final c in conscious) c.rank],
          attackerRank: e.rank,
          gap: _gap,
          reach: reachOf(weapon),
          rng: _rng,
        )];

    // The same reach rule the party plays by (B5-01). An enemy that
    // cannot get to the back rank is exactly why standing back is worth
    // something.
    final events = <BattleEvent>[];
    WeaponAttack pick(int rank) => chooseAttack(
      weapon,
      distanceBetween(gap: _gap, attackerRank: e.rank, targetRank: rank),
    );
    var attack = pick(t.rank);
    var reach = _strain(e.rank, t.rank, attack);
    if (!reach.penalty.isNone) {
      events.add(EnemyAttackStrained(index, t.slot, reach.shortBy));
      final blocker = _nearerMemberThan(t.rank);
      if (blocker != null && intercepts(penalty: reach.penalty, rng: _rng)) {
        events.add(EnemyAttackIntercepted(index, t.slot, blocker.slot));
        t = blocker;
        attack = pick(t.rank);
        reach = _strain(e.rank, t.rank, attack);
      }
    }

    if (immunityFor(resistance: t.snapshot.resistance) == Immunity.physical) {
      return [...events, MemberBlocked(index, t.slot, BlockKind.resisted)];
    }
    // B5-05 folded the shield into this roll — a block is a graze of
    // zero, so it was the same idea twice.
    final scale = grazeScale(
      accuracy: e.accuracy[0] - reach.penalty.accuracy,
      evasion: evasionOf(
        agility: t.snapshot.agility,
        luck: t.snapshot.luck,
        // BP-45: a free hand is what makes a light style light. Small
        // against a shield on purpose, so dropping the shield is a
        // decision and not an upgrade.
        styleBonus: t.snapshot.evasionBonus,
        // B5-03: set for the blow, and much less so for the second one
        // in the same round — a tank that cannot be worn down is not a
        // decision either.
        shieldBlock:
            t.snapshot.shieldBlock +
            (t.braced ? braceBonus(t.hitsThisRound) : 0),
      ),
      rng: _rng,
    );
    if (scale == 0 && t.snapshot.shieldBlock > 0) {
      // B5-07: the shield turns the attacker away, not its holder. A
      // block that shoved the blocker out of the front rank would undo
      // the very role a shield exists for.
      final shoved = <BattleEvent>[];
      if (pushBack(e.rank) == PushResult.moved) {
        e.rank = clampRank(e.rank + 1);
        e.staggered = true;
        shoved.add(AttackerShovedBack(t.slot, index, e.rank));
      }
      return [...events, ShieldBlocked(index, t.slot), ...shoved];
    }
    final damage = enemyPhysicalDamage(
      // B5-02: same rule as the party's — the close-in method is weaker.
      enemyStrength: e.strength * attack.power ~/ 100,
      enemyLevel: e.level,
      graze: scale,
      // B2-08: only worn armour subtracts; the shield already had its
      // chance above.
      memberAc: t.snapshot.effectiveArmour,
      memberLevelPhysical: t.snapshot.levelPhysical,
      rng: _rng,
    );
    if (damage <= 0) {
      return [...events, MemberBlocked(index, t.slot, BlockKind.absorbed)];
    }
    // B5-06: the enemy's weapon method is an element too, so the party
    // gets pushed around by the same rule it pushes with.
    final pushEvents = <BattleEvent>[];
    var landed = damage;
    t.hitsThisRound++;

    // B5-07: give ground rather than be finished. Only they move, and
    // only while there is a rank behind them — which is what keeps this
    // from being an extra life. Each use leaves them further from
    // anything their weapon reaches.
    if (t.snapshot.dodgesBack &&
        !t.braced &&
        canRetreat(t.rank) &&
        damage >= t.hp &&
        t.unconscious == 0) {
      t.rank = clampRank(t.rank + 1);
      return [...events, DodgedBack(t.slot, t.rank)];
    }

    final weak = t.snapshot.weakTo.contains(attack.element);
    // Bracing refuses to give ground — the name earns itself, and it
    // means a held front line can keep the gap where the party wants it.
    if (!t.braced && knocksBack(attack.element, hitWeakness: weak)) {
      if (pushBack(t.rank) == PushResult.moved) {
        t.rank = clampRank(t.rank + 1);
        t.staggered = true;
        pushEvents.add(MemberPushedBack(t.slot, t.rank));
      } else {
        final extra = damage * corneredBonusPercent ~/ 100;
        landed += extra;
        pushEvents.add(MemberCornered(t.slot, extra));
      }
    } else if (t.staggered) {
      landed += damage * staggerBonusPercent ~/ 100;
    }
    return [
      ...events,
      ...pushEvents,
      ..._damageMember(index, t, landed, DamageSource.physical),
    ];
  }

  /// The casting ladder — `rules/enemy_ai.dart` decides, this applies.
  List<BattleEvent> _enemyCast(int index, EnemyInstance e) {
    final events = <BattleEvent>[EnemyUsedSpecial(index)];
    final allies = [for (var i = 0; i < _enemies.length; i++) i];
    var totalHp = 0;
    var totalMaxHp = 0;
    for (final i in allies) {
      totalHp += _enemies[i].hp;
      totalMaxHp += _enemies[i].endurance * _enemies[i].level;
    }
    final valid = [
      for (final c in _party)
        if (c.name.isNotEmpty) c,
    ];
    final averageAc = valid.isEmpty
        ? 0
        : valid.fold(0, (a, c) => a + c.snapshot.ac) ~/ valid.length;

    final plan = chooseEnemySpell(
      castLevel: e.castLevel,
      hp: e.hp,
      endurance: e.endurance,
      level: e.level,
      mentality: e.mentality,
      consciousPlayers: _party.where((c) => c.isConscious).length,
      enemyCount: _enemies.length,
      totalEnemyHp: totalHp,
      totalEnemyMaxHp: totalMaxHp,
      averagePartyAc: averageAc,
      rng: _rng,
    );

    switch (plan) {
      case NoSpell():
        return events;
      case HealSelf(:final amount):
        events.addAll(_enemyCure(index, index, amount, self: true));
      case HealAllies(:final amount):
        for (final i in allies) {
          events.addAll(_enemyCure(index, i, amount, self: false));
        }
      case StripArmour():
        // The C++ averaged the *enemy's own* ac instead of the party's
        // and skipped party slot 0 entirely. Both are bugs (6th
        // decision); here every valid member is at risk and the average
        // is the party's.
        for (final c in valid) {
          if (armourGrindResisted(luck: c.snapshot.luck, rng: _rng)) {
            events.add(MemberLuckSaved(c.slot));
          } else {
            events.add(MemberArmourWorn(index, c.slot));
          }
        }
      case CastAtAll():
        for (final c in _party) {
          if (!c.isConscious) continue;
          events.addAll(_enemySpellDamage(index, e, c));
        }
      case CastAtOne(:final target):
        final t = _pickSpellTarget(target);
        if (t != null) events.addAll(_enemySpellDamage(index, e, t));
    }
    return events;
  }

  /// Who the ladder's target choice resolves to.
  ///
  /// The C++ weakest-target search at `cast_level` 5 seeded itself with
  /// party slot 0 without checking whether that slot was even occupied,
  /// so it could pick an empty or dead member. Level 6 does the same
  /// search correctly, with a sentinel and an `isConscious` test — so
  /// the fixed form is the original's own. Used for both here.
  Combatant? _pickSpellTarget(EnemySpellTarget target) {
    final conscious = [
      for (final c in _party)
        if (c.isConscious) c,
    ];
    if (conscious.isEmpty) return null;
    switch (target) {
      case EnemySpellTarget.anyone:
        // `cast_level` 1 picks blind and retries once.
        final valid = [
          for (final c in _party)
            if (c.name.isNotEmpty) c,
        ];
        if (valid.isEmpty) return null;
        var pick = valid[rngPick(valid.length)];
        if (!pick.isConscious) pick = valid[rngPick(valid.length)];
        return pick.isConscious ? pick : null;
      case EnemySpellTarget.randomConscious:
        return conscious[rngPick(conscious.length)];
      case EnemySpellTarget.weakestConscious:
        var best = conscious.first;
        for (final c in conscious) {
          if (c.hp < best.hp) best = c;
        }
        return best;
      case EnemySpellTarget.everyone:
        return conscious.first;
    }
  }

  /// Draw helper so target picks stay in the battle's single sequence.
  int rngPick(int count) => pickTargetIndex(candidateCount: count, rng: _rng);

  List<BattleEvent> _enemySpellDamage(int index, EnemyInstance e, Combatant t) {
    final damage = enemySpellDamage(enemyLevel: e.level, rng: _rng);
    return _damageMember(index, t, damage, DamageSource.spell);
  }

  /// `enemyCastCureSpell` — clears death first, then unconsciousness,
  /// and only heals hit points on a target that is standing.
  List<BattleEvent> _enemyCure(
    int caster,
    int target,
    int amount, {
    required bool self,
  }) {
    final t = _enemies[target];
    if (t.dead > 0) {
      t.dead = 0;
      return [EnemyRevivedAlly(caster, target, fromDeath: true)];
    }
    if (t.unconscious > 0) {
      t.unconscious = 0;
      if (t.hp <= 0) t.hp = 1;
      return [EnemyRevivedAlly(caster, target, fromDeath: false)];
    }
    final max = t.endurance * t.level;
    final before = t.hp;
    t.hp = (t.hp + amount) > max ? max : t.hp + amount;
    if (t.hp == before) return const [];
    return [
      if (self)
        EnemyHealedSelf(caster, t.hp - before)
      else
        EnemyHealedAlly(caster, target, t.hp - before),
    ];
  }

  /// The three innate abilities — `enemyAttackWithSpecialAbility`.
  ///
  /// Luck is a real defence here (`random(20) < luck`), which is the
  /// first time the stat does anything outside the escape formula.
  List<BattleEvent> _enemyUseAbility(int index, EnemyInstance e) {
    final ability = enemySpecialFor(e.special);
    if (ability == null) return const [];
    final kind = switch (ability) {
      EnemySpecial.poison => EnemySpecialKind.poison,
      EnemySpecial.knockOut => EnemySpecialKind.knockOut,
      EnemySpecial.slay => EnemySpecialKind.slay,
    };

    final pool = specialAbilityHitsDowned(ability)
        ? [
            for (final c in _party)
              if (c.name.isNotEmpty && c.dead == 0) c,
          ]
        : [
            for (final c in _party)
              if (c.isConscious) c,
          ];
    if (pool.isEmpty) {
      return [EnemyAbilityUsed(index, kind, -1)];
    }

    Combatant target = pool[rngPick(pool.length)];
    if (ability == EnemySpecial.poison) {
      // Retries looking for someone not already poisoned.
      for (var i = 0; i < poisonTargetAttempts; i++) {
        if (target.poison == 0) break;
        target = pool[rngPick(pool.length)];
      }
    }

    final events = <BattleEvent>[EnemyAbilityUsed(index, kind, target.slot)];
    final outcome = resolveSpecialAbility(
      ability,
      enemyAgility: e.agility,
      targetLuck: target.snapshot.luck,
      rng: _rng,
    );
    switch (outcome) {
      case SpecialAbilityOutcome.missed:
      case SpecialAbilityOutcome.noTarget:
        events.add(EnemyAbilityMissed(index, kind));
      case SpecialAbilityOutcome.luckSaved:
        events.add(MemberLuckSaved(target.slot));
      case SpecialAbilityOutcome.applied:
        switch (ability) {
          case EnemySpecial.poison:
            target.poison += 1;
            events.add(MemberPoisoned(target.slot));
          case EnemySpecial.knockOut:
            if (target.unconscious == 0) {
              target.unconscious = 1;
              if (target.hp > 0) target.hp = 0;
              events.add(MemberStruckDown(target.slot, killed: false));
            }
          case EnemySpecial.slay:
            if (target.dead == 0) {
              target.dead = 1;
              if (target.hp > 0) target.hp = 0;
              events.add(MemberStruckDown(target.slot, killed: true));
            }
        }
    }
    return events;
  }

  /// Applies damage to one party member through the shared collapse
  /// rule. Collapsing leaves them recoverable; the cure spells are what
  /// bring them back (B2-02).
  List<BattleEvent> _damageMember(
    int enemyIndex,
    Combatant t,
    int damage,
    DamageSource source,
  ) {
    final wasDown = t.unconscious > 0;
    final change = applyDamage(
      hp: t.hp,
      unconscious: t.unconscious,
      dead: t.dead,
      amount: damage,
      deathThreshold: t.deathThreshold,
    );
    t.hp = change.hp;
    t.unconscious = change.unconscious;
    t.dead = change.dead;

    final events = <BattleEvent>[
      MemberDamaged(
        enemyIndex,
        t.slot,
        change.damageApplied,
        source,
        whileCollapsed: wasDown,
      ),
    ];
    if (change.outcome == CollapseOutcome.collapsed) {
      events.add(MemberCollapsed(t.slot));
    } else if (change.outcome == CollapseOutcome.finished) {
      events.add(MemberDied(t.slot));
    }
    return events;
  }

  // --- settlement ---------------------------------------------------

  /// `battle.dart:232-272`. Decides the result, settles a win, and seals
  /// the outcome. The original also ran the game-over flow and printed
  /// the level-up line here; both belong to the RPG now (B3-05).
  List<BattleEvent> _finish() {
    if (!_partyAlive) {
      _result = BattleResultCode.lose;
    } else if (!_enemiesAlive && _result != BattleResultCode.evade) {
      _result = BattleResultCode.win;
    }

    final events = <BattleEvent>[];
    if (_result == BattleResultCode.win) events.addAll(_settleWin());
    events.add(BattleEnded(_result));

    _outcome = BattleOutcome(
      resultCode: _result,
      combatants: [for (final c in _party) c.toResult()],
      goldGained: _goldGained,
      consumedItems: Map.unmodifiable(_spent),
      recruits: List.unmodifiable(_recruits),
      departedSlots: List.unmodifiable(_departedSlots),
    );
    _phase = BattlePhase.finished;
    return events;
  }

  /// `battle.dart:274-297`. The experience total goes to every conscious
  /// member in full; gold is added to the party once.
  List<BattleEvent> _settleWin() {
    // Reinforcements are worth nothing — otherwise a superhuman caster
    // that summons every round pays out forever (B2-11).
    final earned = [
      for (final e in _enemies)
        if (!e.summoned) e,
    ];
    final total = victoryExperience([for (final e in earned) e.data.legacyId]);
    for (final c in _party) {
      if (c.isConscious) c.experienceGained += total;
    }
    _goldGained = goldReward([for (final e in earned) e.level]);
    return [ExperienceSettled(total), GoldSettled(_goldGained)];
  }

  // --- queries ------------------------------------------------------

  bool get _enemiesAlive => _enemies.any((e) => e.isConscious);
  bool get _partyAlive => _party.any((c) => c.isConscious);

  /// Conscious enemies, **nearest rank first** (then registration order),
  /// so a target list reads front to back like the picture (B6-07).
  List<int> _aliveEnemyIndices() {
    final alive = [
      for (var i = 0; i < _enemies.length; i++)
        if (_enemies[i].isConscious) i,
    ];
    alive.sort((a, b) {
      final byRank = _enemies[a].rank.compareTo(_enemies[b].rank);
      return byRank != 0 ? byRank : a.compareTo(b);
    });
    return alive;
  }

  int _firstAliveEnemy() => _enemies.indexWhere((e) => e.isConscious);
}
