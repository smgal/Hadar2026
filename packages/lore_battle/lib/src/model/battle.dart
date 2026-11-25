import '../contract/battle_command.dart';
import '../contract/battle_event.dart';
import '../contract/battle_result_code.dart';
import '../contract/battle_setup.dart';
import '../contract/vocabulary.dart';
import '../data/enemy_data.dart';
import '../data/enemy_tables.dart';
import '../rules/affinity.dart';
import '../rules/attack_magic.dart';
import '../rules/battle_item.dart';
import '../rules/condition.dart';
import '../rules/cure.dart';
import '../rules/enemy_ai.dart';
import '../rules/escape.dart';
import '../rules/esp.dart';
import '../rules/initiative.dart';
import '../rules/physical.dart';
import '../rules/position.dart';
import '../rules/preset.dart';
import '../rules/rng.dart';
import '../rules/settle.dart';
import '../rules/skillbook.dart';
import '../rules/special_magic.dart';
import '../rules/summon.dart';
import '../rules/weapon.dart';
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
  /// enemy, in initiative order.
  resolvingRound,

  /// `outcome` is available.
  finished,
}

/// What one party member decided to do this round.
class _Plan {
  BattleAction action = BattleAction.skip;
  int magicId = 0;
  String itemKey = '';
  int allySlot = -1;

  /// Enemy index, or -1 for "whoever is first".
  int target = -1;
}

/// What the battle is waiting to be told, during
/// [BattlePhase.collecting].
enum _Ask {
  action,

  /// An enemy to strike — the fallen count, when the option allows.
  enemyTarget,

  /// An enemy that is still standing — special magic and ESP pass over
  /// the fallen.
  standingEnemyTarget,
  spell,
  item,
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
/// ## Whose rules these are
///
/// The shape is `hd_battle`'s: everyone is asked first, then the round
/// plays out in initiative order; every combatant has a rank and the two
/// sides share a gap; being out of reach costs accuracy and never the
/// turn. **The numbers are the Lore trilogy's Part 3 system** (design
/// chapters 7 to 9 and 12) — one level, eight abilities, six skills, one
/// magic pool, an assistant member in the sixth seat who fights on its
/// own. `rules/` holds each formula next to the line of the document it
/// comes from; this file only decides who does what to whom, and when.
class Battle {
  /// [rng] exists for tests that need a scripted draw sequence; leave it
  /// out and the battle seeds itself from `setup.seed`.
  Battle(this.setup, {BattleRng? rng}) : _rng = rng ?? SeededRng(setup.seed) {
    if (setup.episode < 1 || setup.episode > 3) {
      throw ArgumentError('episode must be 1, 2 or 3: ${setup.episode}');
    }
    for (final snapshot in setup.party) {
      _party.add(Combatant.fromSnapshot(snapshot));
    }
    for (var i = 0; i < setup.enemyKeys.length; i++) {
      final key = setup.enemyKeys[i];
      final resolved = resolveEnemy(setup.episode, key);
      if (resolved == null) {
        throw ArgumentError(
          'unknown enemy key for episode ${setup.episode}: "$key"',
        );
      }
      final extra = setup.enemyOverrides[i];
      final override = resolved.override == null
          ? extra
          : resolved.override!.mergedWith(extra);
      _enemies.add(
        EnemyInstance(
          resolved.data,
          episode: setup.episode,
          override: override,
          rank: i < setup.enemyRanks.length
              ? clampRank(setup.enemyRanks[i])
              : null,
        ),
      );
    }
    _gap = clampGap(
      setup.initialGap ??
          // An ambush is already on top of the party.
          (setup.enemyActsFirst
              ? 0
              : openingGap(
                  partyAgility: [for (final c in _party) c.snapshot.agility],
                  partyLevel: [for (final c in _party) c.snapshot.level],
                  enemyAgility: [for (final e in _enemies) e.agility],
                  enemyLevel: [for (final e in _enemies) e.level],
                )),
    );
  }

  final BattleSetup setup;
  final BattleRng _rng;
  final List<Combatant> _party = [];
  final List<EnemyInstance> _enemies = [];

  /// Party members taking part, in seat order.
  List<Combatant> get party => List.unmodifiable(_party);

  /// Enemies, in the order they were registered. Indices in events refer
  /// to this list, and **stay put**: an enemy that dies keeps its line.
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
  late final Map<String, int> _held = {...setup.consumables};
  final Map<String, int> _spent = {};
  late int _arrows = setup.arrows;
  int _arrowsUsed = 0;
  final List<int> _departedSlots = [];

  /// How far apart the two sides stand. One number for both sides: "we
  /// advance" and "they advance" are the same event.
  int get gap => _gap;
  int _gap = 0;

  /// Arrows left in the party's quiver.
  int get arrows => _arrows;

  /// What is left of the consumables the setup handed over.
  Map<String, int> get consumables => Map.unmodifiable(_held);

  /// What the formation phase did this round, for the view.
  ({int from, int to, FormationOrder party, FormationOrder enemy})?
  _formationChange;

  final Map<int, _Plan> _plans = {};

  /// Who is asked this round, in order: **leader first, then by rank**
  /// (front to back), seat breaking ties. Indices into [_party]. The
  /// assistant member is never in it.
  List<int> _askOrder = const [];
  int _collectIx = 0;
  _Ask _ask = _Ask.action;

  /// How many times each member has come back to the action menu this
  /// round. A person never notices; a headless policy that keeps
  /// cancelling would loop forever without it.
  final Map<int, int> _returns = {};
  static const int _maxReturns = 8;
  bool _autoBattle = false;

  /// The leader ordered a retreat this round. Nobody else is asked; if
  /// the roll fails the round is lost.
  bool _escaping = false;

  /// The enemy has the first round to itself (ch.8.3).
  bool _partySitsOut = false;

  /// The sixth seat has already attacked this round, so a creature
  /// summoned into it now waits for the next.
  bool _assistantActed = false;

  List<Turn> _order = [];
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
        return EnemyTargetDecision(c.slot, _strikeTargets());
      case _Ask.standingEnemyTarget:
        return EnemyTargetDecision(c.slot, _standingTargets());
      case _Ask.item:
        return ItemDecision(c.slot, _itemsFor(c));
      case _Ask.allyTarget:
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
    switch (_ask) {
      case _Ask.action:
        return _answerAction(c, plan, command);
      case _Ask.enemyTarget:
      case _Ask.standingEnemyTarget:
        return _answerEnemyTarget(c, plan, command);
      case _Ask.spell:
        return _answerSpell(c, plan, command);
      case _Ask.item:
        return _answerItem(c, plan, command);
      case _Ask.allyTarget:
        return _answerAllyTarget(c, plan, command);
      case _Ask.order:
        return _answerOrder(c, plan, command);
    }
  }

  // --- collection ---------------------------------------------------

  /// The battle menu — six lines.
  ///
  /// ```
  /// attack · castSkill · useItem · [charge] · brace · [escape · orders]
  /// ```
  ///
  /// Nothing that cannot be done is offered: a charge needs a weapon
  /// that charges, the skill line needs something learned, the item line
  /// needs something this member can use, and flight needs a battle that
  /// allows it. The last two lines are the **leader's** — whoever is
  /// able to act and lowest in seat order among the five who take
  /// commands.
  List<BattleAction> _actionOptions(Combatant c) => [
    BattleAction.attack,
    if (_skillsFor(c).isNotEmpty) BattleAction.castSkill,
    if (_itemsFor(c).isNotEmpty) BattleAction.useItem,
    if (c.weapon.canCharge && canAdvance(c.rank)) BattleAction.charge,
    BattleAction.brace,
    if (_isLeader(c)) ...[
      if (setup.canEscape) BattleAction.escape,
      BattleAction.orders,
    ],
  ];

  /// The leader's orders that make sense right now.
  List<BattleAction> _orderOptions() => [
    BattleAction.autoBattle,
    if (_gap > 0) BattleAction.advanceFormation,
    if (_gap < maxGap) BattleAction.retreatFormation,
  ];

  /// The leader: the lowest seat that can act, among seats 0..4. Null
  /// when only the assistant is left standing.
  int? get leaderSlot {
    int? best;
    for (final c in _party) {
      if (c.isAssistant || !c.isConscious) continue;
      if (best == null || c.slot < best) best = c.slot;
    }
    return best;
  }

  bool _isLeader(Combatant c) => c.slot == leaderSlot;

  List<SkillOption> _skillsFor(Combatant c) =>
      skillOptions(c.snapshot, mp: c.mp, episode: setup.episode);

  List<String> _itemsFor(Combatant c) =>
      usableItems(_held, holdsMagic: c.snapshot.holdsMagic);

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

    switch (action) {
      case BattleAction.orders:
        _ask = _Ask.order;
        return const [];
      case BattleAction.escape:
        // A party action: nobody else is asked this round.
        _escaping = true;
        _nextMember();
        return const [];
      case BattleAction.brace:
        _nextMember();
        return const [];
      case BattleAction.charge:
      case BattleAction.attack:
        return _askEnemyTarget(c, plan, _Ask.enemyTarget);
      case BattleAction.useItem:
        _ask = _Ask.item;
        return const [];
      case BattleAction.castSkill:
        _ask = _Ask.spell;
        return const [];
      case BattleAction.skip:
      case BattleAction.autoBattle:
      case BattleAction.advanceFormation:
      case BattleAction.retreatFormation:
        // Never in [_actionOptions]; rejected above.
        return _skip(c, plan);
    }
  }

  /// One of the leader's orders, answered with a [ChooseAction].
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
      _planAuto(c, plan);
    }
    _nextMember();
    return const [];
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
    if (command.enemyIndex < 0) return _backToAction(c, plan);
    final offered = _ask == _Ask.standingEnemyTarget
        ? _standingTargets()
        : _strikeTargets();
    if (!offered.contains(command.enemyIndex)) {
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
    final chosen = _skillsFor(c).where((o) => o.magicId == command.magicId);
    if (chosen.isEmpty) {
      throw ArgumentError(
        'skill ${command.magicId} is not castable by slot ${c.slot}',
      );
    }
    final option = chosen.first;
    // Unaffordable skills stay in the list so the player can see them;
    // picking one is refused here, and a wrong pick is not a lost turn.
    if (!option.affordable) {
      return [NotEnoughSpellPoints(c.slot), ..._backToAction(c, plan)];
    }
    plan.magicId = command.magicId;

    switch (targetingOf(command.magicId)) {
      case SkillTargeting.singleEnemy:
        // Attack magic finishes the fallen as a weapon does; the rest
        // only work on something still standing.
        return _askEnemyTarget(
          c,
          plan,
          option.category == SkillCategory.attackOne
              ? _Ask.enemyTarget
              : _Ask.standingEnemyTarget,
        );
      case SkillTargeting.singleAlly:
        return _askAllyTarget(c, plan);
      case SkillTargeting.allEnemies:
      case SkillTargeting.allAllies:
      case SkillTargeting.none:
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
      throw ArgumentError('expected an item choice, got $command');
    }
    if (!_itemsFor(c).contains(command.itemKey)) {
      throw ArgumentError(
        'slot ${c.slot} cannot use "${command.itemKey}" right now',
      );
    }
    plan.itemKey = command.itemKey;
    switch (battleItems[command.itemKey]!.target) {
      case ItemTarget.ally:
        return _askAllyTarget(c, plan);
      case ItemTarget.enemy:
        return _askEnemyTarget(
          c,
          plan,
          // The spirit crystal halves what is left of something alive.
          command.itemKey == ItemKey.spiritCrystal
              ? _Ask.standingEnemyTarget
              : _Ask.enemyTarget,
        );
      case ItemTarget.self:
      case ItemTarget.allEnemies:
      case ItemTarget.none:
        plan.target = -1;
        _nextMember();
        return const [];
    }
  }

  /// Asks for an enemy — unless there is only one to pick, in which case
  /// the question would have one answer and is not asked.
  List<BattleEvent> _askEnemyTarget(Combatant c, _Plan plan, _Ask ask) {
    final offered = ask == _Ask.standingEnemyTarget
        ? _standingTargets()
        : _strikeTargets();
    if (offered.isEmpty) return _skip(c, plan);
    if (offered.length == 1) {
      plan.target = offered.single;
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

  List<BattleEvent> _answerAllyTarget(
    Combatant c,
    _Plan plan,
    BattleCommand command,
  ) {
    if (command is CancelChoice) return _backToAction(c, plan);
    if (command is! ChooseAllyTarget) {
      throw ArgumentError('expected an ally target, got $command');
    }
    if (!_presentSlotsByNeed().contains(command.allySlot)) {
      throw ArgumentError('slot ${command.allySlot} is not in the party');
    }
    plan.allySlot = command.allySlot;
    _nextMember();
    return const [];
  }

  /// What a member does when the leader hands the round over.
  ///
  /// Ch.8.4's rule, read through the member's preset: a caster with an
  /// attack skill and magic points to spare throws its first-tier spell
  /// at the first enemy, and everyone else swings at it.
  ///
  /// **Automatic is blind.** It never picks a target — it takes the
  /// first thing standing, as the original's does.
  void _planAuto(Combatant c, _Plan plan) {
    final target = _firstStandingEnemy();
    if (target == -1) {
      plan.action = BattleAction.skip;
      return;
    }
    final preset = presetOf(c.snapshot.preset);
    if (autoCasts(
      preset: preset,
      attackSkill: c.snapshot.attackSkill,
      mp: c.mp,
    )) {
      plan
        ..action = BattleAction.castSkill
        ..magicId = skillId(SkillCategory.attackOne, 1)
        ..target = target;
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
      plan
        ..action = BattleAction.charge
        ..target = target;
      return;
    }
    if (preset.bracesWhenHurt && c.hp * 2 < c.snapshot.maxHp) {
      plan.action = BattleAction.brace;
      return;
    }
    plan
      ..action = BattleAction.attack
      ..target = target;
  }

  /// "{이름}는 잠시 주저했다" — the turn is given up.
  List<BattleEvent> _skip(Combatant c, _Plan plan) {
    plan.action = BattleAction.skip;
    _nextMember();
    return [ActionSkipped(c.slot)];
  }

  void _nextMember() {
    _collectIx++;
    _moveToNextAsk();
  }

  Combatant get _current => _party[_askOrder[_collectIx]];

  /// Leader first, then front to back, then seat. Seats 0..4 only — the
  /// assistant is never asked (ch.7.8).
  List<int> _buildAskOrder() {
    final leader = leaderSlot;
    final order = [
      for (var i = 0; i < _party.length; i++)
        if (_party[i].isConscious && !_party[i].isAssistant) i,
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
  /// costing the turn. The original could not back out of a target
  /// choice at all (appendix E.6).
  List<BattleEvent> _backToAction(Combatant c, _Plan plan) {
    final n = (_returns[c.slot] ?? 0) + 1;
    _returns[c.slot] = n;
    if (n > _maxReturns) return _skip(c, plan);
    plan
      ..action = BattleAction.skip
      ..magicId = 0
      ..itemKey = ''
      ..allySlot = -1
      ..target = -1;
    _ask = _Ask.action;
    return const [];
  }

  /// Present party members, the one most in need first: dead, then
  /// unconscious, then poisoned, then hurt, then whole; seat breaks ties.
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

  /// Walks the party to the next member that needs asking, planning the
  /// auto-battlers on the way. Switches to resolution once nobody is
  /// left to ask.
  void _moveToNextAsk() {
    while (_collectIx < _askOrder.length) {
      final c = _party[_askOrder[_collectIx]];
      if (!c.isConscious) {
        _collectIx++;
        continue;
      }
      if (_escaping) {
        // The leader is taking everyone out; nobody else acts.
        _plans.putIfAbsent(c.slot, _Plan.new).action = BattleAction.skip;
        _collectIx++;
        continue;
      }
      if (_autoBattle) {
        _planAuto(c, _plans.putIfAbsent(c.slot, _Plan.new));
        _collectIx++;
        continue;
      }
      _ask = _Ask.action;
      return;
    }
    _beginResolution();
  }

  // --- rounds -------------------------------------------------------

  List<BattleEvent> _beginRound() {
    if (!_enemiesAlive || !_partyAlive) return _finish();
    _round++;
    _plans.clear();
    _autoBattle = false;
    _escaping = false;
    _assistantActed = false;
    // An ambush: the first round has no party phase at all (ch.8.3).
    _partySitsOut = _round == 1 && setup.enemyActsFirst;
    final events = <BattleEvent>[
      RoundStarted(_round, enemyActsFirst: _partySitsOut),
    ];
    // Being off balance is worth one round of follow-up, no more.
    for (final e in _enemies) {
      e.staggered = false;
    }
    for (final c in _party) {
      c
        ..staggered = false
        ..braced = false
        ..hitsThisRound = 0;
    }
    if (_partySitsOut) {
      _beginResolution();
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
  /// The formation moves **before anyone acts**, so the gap is settled
  /// when the round plays out. That is also why it is not a turn in the
  /// initiative order — putting it there would have meant the leader had
  /// to be fastest.
  void _beginResolution() {
    final partyOrder = _partySitsOut
        ? FormationOrder.hold
        : _partyFormationOrder();
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
    _order = orderOfBattle(
      partyAgility: [for (final c in _party) c.snapshot.agility],
      partyActive: [for (final c in _party) c.isConscious && !_partySitsOut],
      enemyAgility: [for (final e in _enemies) e.agility],
      // The unconscious are listed too: their turn is where their poison
      // finishes them.
      enemyActive: [for (final e in _enemies) e.acts && e.isPresent],
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
    for (final plan in _plans.values) {
      if (plan.action == BattleAction.advanceFormation) {
        return FormationOrder.advance;
      }
      if (plan.action == BattleAction.retreatFormation) {
        return FormationOrder.retreat;
      }
    }
    return FormationOrder.hold;
  }

  /// What the enemy side wants, read off the two sides' reach.
  FormationOrder _enemyFormationOrder() {
    final standing = [
      for (final e in _enemies)
        if (e.acts && e.isConscious) e,
    ];
    if (standing.isEmpty) return FormationOrder.hold;
    int longest(Iterable<int> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a > b ? a : b);
    return formationWant(
      myReach: longest([for (final e in standing) reachOf(e.weapon)]),
      theirReach: longest([
        for (final c in _party)
          if (c.isConscious) reachOf(c.weapon),
      ]),
      gap: _gap,
    );
  }

  /// Resolves one combatant's turn, whoever is next on initiative.
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
        if (c.isAssistant) {
          _assistantActed = true;
          events.addAll(_assistantAttack(c));
        } else {
          events.addAll(_memberTurn(c));
        }
      } else {
        final e = _enemies[turn.index];
        if (!e.acts || !e.isPresent) continue;
        events.addAll(_enemyTurn(turn.index, e));
      }

      if (_result == BattleResultCode.evade || !_enemiesAlive || !_partyAlive) {
        events.addAll(_finish());
        return events;
      }
      if (events.isEmpty) continue;
      return events;
    }

    // Everyone has moved. The party's poison bites once a round, here.
    final events = _tickPartyPoison();
    events.addAll(_beginRound());
    return events;
  }

  /// One commanded member's turn.
  List<BattleEvent> _memberTurn(Combatant c) {
    final plan = _plans[c.slot];
    if (plan == null) return const [];
    switch (plan.action) {
      case BattleAction.skip:
      case BattleAction.orders:
      case BattleAction.autoBattle:
      // Formation orders were spent in the formation phase; the leader
      // has no swing left this round.
      case BattleAction.advanceFormation:
      case BattleAction.retreatFormation:
        return const [];
      case BattleAction.brace:
        c.braced = true;
        if (canAdvance(c.rank)) c.rank = clampRank(c.rank - 1);
        return [Braced(c.slot, c.rank)];
      case BattleAction.charge:
        if (canAdvance(c.rank)) c.rank = clampRank(c.rank - 1);
        return [Charged(c.slot, c.rank), ..._memberAttack(c, plan.target)];
      case BattleAction.attack:
        return _memberAttack(c, plan.target);
      case BattleAction.escape:
        return _tryEscape(c);
      case BattleAction.useItem:
        return _useItem(c, plan);
      case BattleAction.castSkill:
        return _castSkill(c, plan);
    }
  }

  /// One enemy's poison, at the start of its own turn (ch.8.3): hit
  /// points drop, at zero it falls unconscious, and one that is already
  /// unconscious dies of it.
  List<BattleEvent> _enemyPoisonTick(int index, EnemyInstance e) {
    if (e.poison <= 0) return const [];
    if (e.unconscious > 0) {
      e.dead = 1;
      return [EnemyDiedFromPoison(index)];
    }
    final amount = enemyPoisonTick(setup.episode);
    e.hp -= amount;
    if (e.hp > 0) return [EnemyPoisonTick(index, amount)];
    e
      ..hp = 0
      ..unconscious = 1;
    return [EnemyPoisonTick(index, amount), EnemyCollapsedFromPoison(index)];
  }

  /// Poison on the party, once per round, after everyone has moved.
  ///
  /// Each poisoned member takes **their poison counter** in damage
  /// (ch.7.7), routed the way any damage is: hit points, then the
  /// unconscious counter, then the death counter — which stops growing
  /// from poison at 10000.
  List<BattleEvent> _tickPartyPoison() {
    final events = <BattleEvent>[];
    for (final c in _party) {
      if (!c.isPresent || c.poison <= 0) continue;
      final wasDead = c.dead > 0;
      final change = applyMemberDamage(
        hp: c.hp,
        unconscious: c.unconscious,
        dead: c.dead,
        amount: c.poison,
        deathThreshold: c.deathThreshold,
        deadCap: battlePoisonDeadCap,
      );
      c
        ..hp = change.hp
        ..unconscious = change.unconscious
        ..dead = change.dead;
      if (wasDead) continue;
      events.add(MemberPoisonTick(c.slot, c.poison));
      if (change.outcome == VitalsOutcome.collapsed) {
        events.add(MemberCollapsedFromPoison(c.slot));
      } else if (change.outcome == VitalsOutcome.died) {
        events.add(MemberDiedFromPoison(c.slot));
      }
    }
    return events;
  }

  // --- the party strikes --------------------------------------------

  /// A commanded member's weapon attack — ch.8.5.
  List<BattleEvent> _memberAttack(Combatant c, int requestedTarget) {
    final target = _resolveStrikeTarget(requestedTarget);
    if (target < 0) return const [];
    // A shooting weapon spends an arrow per attack and cannot attack
    // without one (ch.8.4). Only the attack costs — the original charged
    // an arrow for any action at all (appendix A #35).
    if (c.snapshot.weaponKind == WeaponKind.shoot) {
      if (_arrows <= 0) return [OutOfArrows(c.slot)];
      _arrows--;
      _arrowsUsed++;
    }
    return _strike(
      c,
      target,
      baseDamage: memberBaseDamage(
        strength: c.snapshot.strength,
        weaponPower: c.snapshot.weaponPower,
        skill: c.snapshot.weaponSkill,
        fixedCoefficient: c.snapshot.usesFixedCoefficient,
      ),
      canBeIntercepted: true,
    );
  }

  /// The assistant member's automatic attack — ch.8.5.
  ///
  /// One enemy (the first standing) or all of them in turn, by what the
  /// creature is. A sweep is not intercepted: it is aimed at everyone.
  List<BattleEvent> _assistantAttack(Combatant c) {
    final base = assistantBaseDamage(
      strength: c.snapshot.strength,
      weaponPower: c.snapshot.weaponPower,
      level: c.snapshot.level,
    );
    if (!c.snapshot.attacksAll) {
      final target = _resolveStrikeTarget(-1);
      if (target < 0) return const [];
      return _strike(c, target, baseDamage: base, canBeIntercepted: true);
    }
    final events = <BattleEvent>[];
    for (var i = 0; i < _enemies.length; i++) {
      if (!_canBeStruck(_enemies[i])) continue;
      events.addAll(_strike(c, i, baseDamage: base, canBeIntercepted: false));
    }
    return events;
  }

  /// One weapon blow at one enemy: the document's steps 2 to 8, with the
  /// position layer where it belongs.
  ///
  /// ```
  /// unconscious target      -> finished outright, everyone is paid
  /// [reach]                 -> out of band: accuracy drops, a nearer
  ///                            enemy may step in
  /// rand(20) > accuracy     -> missed
  /// base x weapon method %  -> the close-in method of a long weapon is
  ///                            weaker
  /// deviation 51..100%
  /// rand(100) < resistance  -> stopped
  /// - ac x level x (1..10)  -> absorbed at zero or less
  /// [affinity, knockback]   -> the element of the weapon's method
  /// ```
  List<BattleEvent> _strike(
    Combatant c,
    int targetIx, {
    required int baseDamage,
    required bool canBeIntercepted,
  }) {
    final events = <BattleEvent>[];
    var ix = targetIx;
    var t = _enemies[ix];

    if (t.unconscious > 0) {
      events.add(AttackDeclared(c.slot, ix));
      events.addAll(_finishEnemy(c, ix, DamageSource.physical));
      return events;
    }

    var attack = _pickAttack(c, t.rank);
    var reach = _strain(c.rank, t.rank, attack);
    if (!reach.penalty.isNone) {
      events.add(AttackStrained(c.slot, ix, reach.shortBy));
      if (canBeIntercepted) {
        final blocker = _nearerEnemyThan(t.rank);
        if (blocker != null && intercepts(penalty: reach.penalty, rng: _rng)) {
          events.add(AttackIntercepted(c.slot, ix, blocker));
          ix = blocker;
          t = _enemies[ix];
          // The blow lands somewhere else, so the weapon may fit better.
          attack = _pickAttack(c, t.rank);
          reach = _strain(c.rank, t.rank, attack);
        }
      }
    }

    events.add(AttackDeclared(c.slot, ix));
    if (memberAttackMisses(
      accuracy: c.snapshot.accuracy - reach.penalty.accuracy,
      rng: _rng,
    )) {
      events.add(AttackMissed(c.slot));
      return events;
    }
    var damage = applyDeviation(baseDamage * attack.power ~/ 100, _rng);
    if (enemyBlocksBlow(physicalResistance: t.physicalResistance, rng: _rng)) {
      events.add(EnemyBlocked(c.slot, ix, BlockKind.resisted));
      return events;
    }
    damage -= enemyDefence(ac: t.ac, level: t.level, rng: _rng);
    if (damage <= 0) {
      events.add(EnemyBlocked(c.slot, ix, BlockKind.absorbed));
      return events;
    }
    events.addAll(
      _damageEnemyWithElement(
        c,
        ix,
        damage,
        attack.element,
        source: DamageSource.physical,
      ),
    );
    return events;
  }

  // --- reach --------------------------------------------------------

  /// The way this member's weapon is best used against that rank.
  /// Always returns something.
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

  /// A standing enemy nearer than [rank], nearest first.
  int? _nearerEnemyThan(int rank) {
    int? best;
    for (var i = 0; i < _enemies.length; i++) {
      final e = _enemies[i];
      if (!e.isConscious || e.rank >= rank) continue;
      if (best == null || e.rank < _enemies[best].rank) best = i;
    }
    return best;
  }

  /// A member able to act standing nearer than [rank].
  Combatant? _nearerMemberThan(int rank) {
    Combatant? best;
    for (final c in _party) {
      if (!c.isConscious || c.rank >= rank) continue;
      if (best == null || c.rank < best.rank) best = c;
    }
    return best;
  }

  // --- what falling pays --------------------------------------------

  /// Pays one member `level³` for an enemy.
  List<BattleEvent> _pay(Combatant c, EnemyInstance t) {
    if (!t.paysExperience) return const [];
    final amount = knockOutExperience(enemyLevel: t.experienceLevel);
    if (amount <= 0) return const [];
    c.experienceGained += amount;
    return [ExperienceGained(c.slot, amount)];
  }

  /// Hit points to zero: unconscious, and whoever did it is paid.
  List<BattleEvent> _knockOut(
    Combatant c,
    int index,
    DamageSource source, {
    bool announce = true,
  }) {
    final t = _enemies[index];
    t
      ..hp = 0
      ..unconscious = 1;
    return [if (announce) EnemyCollapsed(c.slot, index, source), ..._pay(c, t)];
  }

  /// An unconscious enemy is finished: dead, and **every member still
  /// able to act** is paid again (ch.8.8).
  List<BattleEvent> _finishEnemy(Combatant c, int index, DamageSource source) {
    final t = _enemies[index];
    t
      ..hp = 0
      ..dead = 1;
    final events = <BattleEvent>[
      EnemyFinished(
        c.slot,
        index,
        source: source,
        flavour: source == DamageSource.physical
            ? _rng.next(finishingFlavours)
            : 0,
      ),
    ];
    for (final m in _party) {
      if (m.isConscious) events.addAll(_pay(m, t));
    }
    return events;
  }

  /// Takes hit points off one enemy and reports it. Weapons, spells,
  /// crystals and ESP all end here.
  List<BattleEvent> _damageEnemy(
    Combatant c,
    int index,
    int damage,
    DamageSource source,
  ) {
    final t = _enemies[index];
    if (t.unconscious > 0) return _finishEnemy(c, index, source);
    t.hp -= damage;
    final events = <BattleEvent>[EnemyDamaged(c.slot, index, damage, source)];
    if (t.hp <= 0) events.addAll(_knockOut(c, index, source));
    return events;
  }

  /// Applies damage after elemental affinity — the inherited layer.
  ///
  /// Hitting a weakness with weight moves the line: the target is driven
  /// back a rank, or pays extra if it has nowhere to go.
  List<BattleEvent> _damageEnemyWithElement(
    Combatant c,
    int index,
    int damage,
    Element element, {
    DamageSource source = DamageSource.spell,
  }) {
    final t = _enemies[index];
    final affinity = t.affinity;
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
          _elementKind(element),
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
      // Off balance from an earlier push. State, not sequence.
      landed += moved * staggerBonusPercent ~/ 100;
    }
    events.addAll(_damageEnemy(c, index, landed, source));
    return events;
  }

  static ElementKind _elementKind(Element element) => switch (element) {
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
  };

  // --- skills -------------------------------------------------------

  /// Dispatches whatever skill was chosen, by its category.
  List<BattleEvent> _castSkill(Combatant c, _Plan plan) {
    final id = plan.magicId;
    switch (categoryOfSkill(id)) {
      case SkillCategory.attackOne:
        final target = _resolveStrikeTarget(plan.target);
        if (target < 0) return const [];
        return _attackMagicOn(c, id, target, area: false).events;
      case SkillCategory.attackAll:
        return _castAreaMagic(c, id);
      case SkillCategory.special:
        return _castSpecial(c, plan);
      case SkillCategory.cure:
        return _castCure(c, plan);
      case SkillCategory.esp:
        return _castEsp(c, plan);
      case SkillCategory.summon:
        return _castSummon(c, id);
      case null:
        return const [];
    }
  }

  /// Attack magic on every enemy — the single spell, once per enemy.
  ///
  /// **Magic points are paid per enemy** (ch.8.5), so it is expensive
  /// and can run the caster dry partway through. The fallen are finished
  /// for nothing, as a single spell would.
  List<BattleEvent> _castAreaMagic(Combatant c, int id) {
    final events = <BattleEvent>[];
    for (var i = 0; i < _enemies.length; i++) {
      if (!_canBeStruck(_enemies[i])) continue;
      final cast = _attackMagicOn(c, id, i, area: true);
      events.addAll(cast.events);
      if (cast.ranDry) break;
    }
    return events;
  }

  /// One attack spell at one enemy — ch.8.5.
  ///
  /// ```
  /// unconscious target         -> removed outright, no cost
  /// cost = skill x tier² / 10  -> short: "마법 지수가 부족했다"
  /// rand(20) >= accuracy       -> missed
  /// rand(100) < magic resist   -> stopped
  /// tier² x skill x 3 - ac x level x (1..10)
  /// ```
  ({List<BattleEvent> events, bool ranDry}) _attackMagicOn(
    Combatant c,
    int id,
    int index, {
    required bool area,
  }) {
    final t = _enemies[index];
    final tier = tierOfSkill(id);
    final skill = c.snapshot.attackSkill;
    final events = <BattleEvent>[SpellCast(c.slot, id, enemyIndex: index)];

    if (t.unconscious > 0) {
      events.addAll(_finishEnemy(c, index, DamageSource.spell));
      return (events: events, ranDry: false);
    }
    final cost = attackMagicCost(skill: skill, tier: tier);
    if (c.mp < cost) {
      events.add(NotEnoughSpellPoints(c.slot));
      return (events: events, ranDry: true);
    }
    c.mp -= cost;

    if (magicAttackMisses(accuracy: c.snapshot.accuracy, rng: _rng)) {
      events.add(SpellMissed(c.slot, id, index));
      return (events: events, ranDry: false);
    }
    if (enemyResistsMagic(magicResistance: t.magicResistance, rng: _rng)) {
      events.add(
        EnemyBlocked(
          c.slot,
          index,
          BlockKind.resisted,
          source: DamageSource.spell,
        ),
      );
      return (events: events, ranDry: false);
    }
    final damage =
        attackMagicDamage(skill: skill, tier: tier) -
        enemyDefence(ac: t.ac, level: t.level, rng: _rng);
    if (damage <= 0) {
      events.add(
        EnemyBlocked(
          c.slot,
          index,
          BlockKind.absorbed,
          source: DamageSource.spell,
        ),
      );
      return (events: events, ranDry: false);
    }
    events.addAll(
      _damageEnemyWithElement(
        c,
        index,
        damage,
        attackMagicElement(tier: tier, area: area),
      ),
    );
    return (events: events, ranDry: false);
  }

  /// Special magic — ch.9.5. Takes a capability away rather than hit
  /// points; `rules/special_magic.dart` holds the rolls.
  ///
  /// The every-enemy tiers pay per enemy and pass over the fallen — the
  /// original charged for those too (appendix A #37).
  List<BattleEvent> _castSpecial(Combatant c, _Plan plan) {
    final id = plan.magicId;
    final kind = specialKindOfSkill(id);
    final cost = specialSpells[kind]!.cost;
    final targets = specialTierHitsAll(tierOfSkill(id))
        ? [
            for (var i = 0; i < _enemies.length; i++)
              if (_enemies[i].isConscious) i,
          ]
        : [_resolveStandingTarget(plan.target)];

    final events = <BattleEvent>[];
    for (final index in targets) {
      if (index < 0) continue;
      if (c.mp < cost) {
        events.add(NotEnoughSpellPoints(c.slot));
        break;
      }
      // Paid before the rolls: a stopped spell still costs.
      c.mp -= cost;
      events.add(SpellCast(c.slot, id, enemyIndex: index));
      final cast = castSpecial(
        kind,
        target: _enemies[index],
        accuracy: c.snapshot.accuracy,
        rng: _rng,
      );
      switch (cast.outcome) {
        case SpecialOutcome.resisted:
          events.add(DebuffFailed(c.slot, id, index, resisted: true));
        case SpecialOutcome.missed:
          events.add(DebuffFailed(c.slot, id, index, resisted: false));
        case SpecialOutcome.applied:
          events.add(
            DebuffApplied(c.slot, id, index, switch (cast.effect) {
              SpecialEffect.specialRemoved => DebuffDetail.specialRemoved,
              SpecialEffect.defenceLowered => DebuffDetail.defenceLowered,
              SpecialEffect.abilityLowered => DebuffDetail.abilityLowered,
              SpecialEffect.castingLowered => DebuffDetail.castingLowered,
              SpecialEffect.castingRemoved => DebuffDetail.castingRemoved,
              SpecialEffect.superhumanLowered => DebuffDetail.superhumanLowered,
              SpecialEffect.superhumanRemoved => DebuffDetail.superhumanRemoved,
              SpecialEffect.poisoned ||
              SpecialEffect.none => DebuffDetail.poisoned,
            }),
          );
      }
    }
    return events;
  }

  /// Cure magic — ch.9.4. `rules/cure.dart` holds the steps and what
  /// each costs.
  ///
  /// The original runs a cure the moment it is chosen, before the round
  /// plays out. Here it takes its place in the round like any other
  /// action — the skeleton asks everyone first and resolves afterwards.
  List<BattleEvent> _castCure(Combatant c, _Plan plan) {
    final id = plan.magicId;
    final tier = tierOfSkill(id);
    final targets = cureTierTargetsAll(tier)
        ? [
            for (final t in _party)
              if (t.isPresent) t,
          ]
        : [_memberAt(plan.allySlot) ?? c];

    final events = <BattleEvent>[SpellCast(c.slot, id)];
    var helped = false;
    var shortOfMp = false;

    for (final t in targets) {
      final result = applyCure(
        tier,
        hp: t.hp,
        maxHp: t.snapshot.maxHp,
        poison: t.poison,
        unconscious: t.unconscious,
        dead: t.dead,
        deathThreshold: t.deathThreshold,
        casterMp: c.mp,
        casterLevel: c.snapshot.level,
      );
      t
        ..hp = result.hp
        ..poison = result.poison
        ..unconscious = result.unconscious
        ..dead = result.dead;
      c.mp -= result.mpSpent;

      for (final step in result.steps) {
        if (!step.applied) {
          if (step.shortOfMp) shortOfMp = true;
          continue;
        }
        helped = true;
        events.add(_cureEvent(step.step, t.slot, step.amount));
      }
    }

    if (!helped) {
      events.add(
        shortOfMp ? NotEnoughSpellPoints(c.slot) : CureHadNoEffect(c.slot),
      );
    }
    return events;
  }

  static BattleEvent _cureEvent(CureStep step, int slot, int amount) =>
      switch (step) {
        CureStep.heal => MemberHealed(slot, amount),
        CureStep.antidote => MemberCured(slot),
        CureStep.recoverConsciousness => MemberRevived(slot),
        CureStep.revitalize => MemberResurrected(slot),
      };

  /// ESP — ch.9.6. `rules/esp.dart` holds the rolls.
  List<BattleEvent> _castEsp(Combatant c, _Plan plan) {
    final id = plan.magicId;
    final ability = espAbilityOfSkill(id);
    final cost = espSpecOf(ability).cost;
    if (c.mp < cost) return [NotEnoughSpellPoints(c.slot)];
    final concentration = c.snapshot.concentration;

    if (ability == EspAbility.fusion) {
      c.mp -= cost;
      final events = <BattleEvent>[
        SpellCast(c.slot, id),
        FusionUnleashed(c.slot, _rng.next(fusionFlavours)),
      ];
      final damage = fusionDamage(
        concentration: concentration,
        level: c.snapshot.level,
      );
      // No roll to hit and none to resist: it simply lands, and the
      // fallen die of it whatever the option says.
      for (var i = 0; i < _enemies.length; i++) {
        if (!_enemies[i].isPresent) continue;
        events.addAll(_damageEnemy(c, i, damage, DamageSource.spell));
      }
      return events;
    }

    final index = _resolveStandingTarget(plan.target);
    if (index < 0) return const [];
    final t = _enemies[index];
    c.mp -= cost;
    final events = <BattleEvent>[SpellCast(c.slot, id, enemyIndex: index)];

    switch (ability) {
      case EspAbility.persuade:
        final outcome = resolvePersuade(
          // An image has no mind to change.
          persuadable: t.persuadable && !t.isClone,
          enemyLevel: t.levelForPersuasion,
          casterLevel: c.snapshot.level,
          concentration: concentration,
          rng: _rng,
        );
        switch (outcome) {
          case PersuadeOutcome.recruited:
            // It leaves the fight and takes the sixth seat, whoever was
            // in it (ch.7.8).
            final joined = recruitFromEnemy(t);
            t.recruited = true;
            events.add(EnemyRecruited(c.slot, index));
            events.addAll(_seatAssistant(joined, AssistantSource.persuasion));
          case PersuadeOutcome.immune:
            events.add(
              MindControlFailed(c.slot, index, MindControlFailure.immune),
            );
          case PersuadeOutcome.outmatched:
            events.add(
              MindControlFailed(c.slot, index, MindControlFailure.outmatched),
            );
          case PersuadeOutcome.unmoved:
            events.add(
              MindControlFailed(c.slot, index, MindControlFailure.unmoved),
            );
        }
      case EspAbility.fear:
        final effect = castFear(
          target: t,
          concentration: concentration,
          rng: _rng,
        );
        if (effect == EspEffect.fled) {
          // Off the field, and the caster is paid as for a knock-out.
          t.fled = true;
          events.add(EnemyFled(index));
          events.addAll(_pay(c, t));
        } else {
          events.addAll(_espEffectEvents(c, id, index, effect));
        }
      case EspAbility.illusion:
        events.addAll(
          _espEffectEvents(
            c,
            id,
            index,
            castIllusion(target: t, concentration: concentration, rng: _rng),
          ),
        );
      case EspAbility.metabolism:
        events.addAll(
          _espEffectEvents(
            c,
            id,
            index,
            castMetabolism(target: t, concentration: concentration, rng: _rng),
          ),
        );
      case EspAbility.astral:
        events.addAll(
          _espEffectEvents(
            c,
            id,
            index,
            castAstral(target: t, concentration: concentration, rng: _rng),
          ),
        );
      case EspAbility.fusion:
        break;
    }
    return events;
  }

  /// Reports — and where it is damage, applies — what an ESP ability
  /// left on its target.
  List<BattleEvent> _espEffectEvents(
    Combatant c,
    int id,
    int index,
    EspEffect effect,
  ) => switch (effect) {
    EspEffect.none => [EspHadNoEffect(c.slot, id, index)],
    EspEffect.resistanceLowered => [
      EnemyWeakened(index, WeakenedStat.resistance),
    ],
    EspEffect.enduranceLowered => [
      EnemyWeakened(index, WeakenedStat.endurance),
    ],
    EspEffect.accuracyLowered => [EnemyWeakened(index, WeakenedStat.accuracy)],
    EspEffect.agilityLowered => [EnemyWeakened(index, WeakenedStat.agility)],
    EspEffect.accuracyAndAgilityLowered => [
      EnemyWeakened(index, WeakenedStat.accuracy),
      EnemyWeakened(index, WeakenedStat.agility),
    ],
    EspEffect.poisoned => [EnemyPoisoned(index)],
    EspEffect.heavyDamage => _damageEnemy(
      c,
      index,
      espHeavyDamage,
      DamageSource.spell,
    ),
    EspEffect.struckDown => [
      EnemyStruckDown(c.slot, index),
      ..._knockOut(c, index, DamageSource.spell, announce: false),
    ],
    EspEffect.fled => [EnemyFled(index)],
  };

  /// Summoning — ch.9.7. Whatever answers takes the sixth seat.
  List<BattleEvent> _castSummon(Combatant c, int id) {
    final tier = tierOfSkill(id);
    final skill = c.snapshot.summonSkill;
    final cost = summonCost(skill: skill, tier: tier);
    if (c.mp < cost) return [NotEnoughSpellPoints(c.slot)];
    c.mp -= cost;
    final pick = pickSummon(tier, _rng);
    final summoned = rollSummon(
      spec: pick.spec,
      form: pick.form,
      summonSkill: skill,
      rng: _rng,
    );
    return [
      SpellCast(c.slot, id),
      ..._seatAssistant(summoned, AssistantSource.summon),
    ];
  }

  /// Puts someone in the sixth seat, over whoever was there.
  List<BattleEvent> _seatAssistant(
    CombatantSnapshot snapshot,
    AssistantSource source,
  ) {
    final fresh = Combatant.fromSnapshot(snapshot, joinedInBattle: true);
    var index = _party.indexWhere((m) => m.isAssistant);
    var replaced = false;
    if (index >= 0) {
      replaced = _party[index].isPresent;
      _party[index] = fresh;
    } else {
      _party.add(fresh);
      index = _party.length - 1;
    }
    _departedSlots.remove(assistantSeat);
    // The assistant moves after the members in the original, so one
    // called this round still gets its attack — once.
    final hasTurnComing = _order
        .skip(_turnIx)
        .any((t) => t.side == Side.party && t.index == index);
    if (!_assistantActed && !hasTurnComing) {
      _order.add(Turn(Side.party, index, 0));
    }
    return [AssistantJoined(source, replaced: replaced)];
  }

  // --- items --------------------------------------------------------

  void _consume(String key) {
    _held[key] = (_held[key] ?? 0) - 1;
    _spent[key] = (_spent[key] ?? 0) + 1;
  }

  /// Uses a herb, a potion or a crystal — ch.9.8 and ch.10.5.
  ///
  /// An item that finds nothing to do is still used up, as in the
  /// original; the two exceptions are the ones the documents word as
  /// "does not react" — the Dark and Ebony crystals without their pair
  /// or without their target.
  List<BattleEvent> _useItem(Combatant c, _Plan plan) {
    final key = plan.itemKey;
    if ((_held[key] ?? 0) <= 0) return const [];

    switch (key) {
      case ItemKey.hpPotion:
        _consume(key);
        final before = c.hp;
        final next = c.hp + potionRestore;
        c.hp = next > c.snapshot.maxHp ? c.snapshot.maxHp : next;
        if (c.hp < before) c.hp = before;
        return [
          ItemUsed(c.slot, key),
          c.hp > before
              ? MemberHealed(c.slot, c.hp - before)
              : CureHadNoEffect(c.slot),
        ];

      case ItemKey.mpPotion:
        _consume(key);
        final before = c.mp;
        final next = c.mp + potionRestore;
        c.mp = next > c.snapshot.maxMp ? c.snapshot.maxMp : next;
        if (c.mp < before) c.mp = before;
        return [
          ItemUsed(c.slot, key),
          c.mp > before
              ? MemberMpRestored(c.slot, c.mp - before)
              : CureHadNoEffect(c.slot),
        ];

      case ItemKey.antidoteHerb:
        _consume(key);
        if (c.poison <= 0) {
          return [ItemUsed(c.slot, key), CureHadNoEffect(c.slot)];
        }
        c.poison = 0;
        return [ItemUsed(c.slot, key), MemberCured(c.slot)];

      case ItemKey.awakeningHerb:
      case ItemKey.revivalHerb:
        _consume(key);
        final t = _memberAt(plan.allySlot) ?? c;
        final step = key == ItemKey.awakeningHerb
            ? CureStep.recoverConsciousness
            : CureStep.revitalize;
        // The revival herb gives up on someone too far gone.
        if (step == CureStep.revitalize && t.dead >= revivalHerbDeadLimit) {
          return [ItemUsed(c.slot, key), CureHadNoEffect(c.slot)];
        }
        final result = applyCureStep(
          step,
          hp: t.hp,
          maxHp: t.snapshot.maxHp,
          poison: t.poison,
          unconscious: t.unconscious,
          dead: t.dead,
          deathThreshold: t.deathThreshold,
          casterMp: 0,
          casterLevel: c.snapshot.level,
          free: true,
        );
        t
          ..hp = result.hp
          ..unconscious = result.unconscious
          ..dead = result.dead;
        return [
          ItemUsed(c.slot, key),
          result.applied
              ? _cureEvent(step, t.slot, 0)
              : CureHadNoEffect(c.slot),
        ];

      case ItemKey.flameCrystal:
        final index = _resolveStrikeTarget(plan.target);
        if (index < 0) return const [];
        _consume(key);
        return [
          ItemUsed(c.slot, key),
          ..._crystalDamage(c, index, flameCrystalDamage, Element.fire),
        ];

      case ItemKey.frostCrystal:
        _consume(key);
        final events = <BattleEvent>[ItemUsed(c.slot, key)];
        for (var i = 0; i < _enemies.length; i++) {
          if (!_canBeStruck(_enemies[i])) continue;
          events.addAll(_crystalDamage(c, i, frostCrystalDamage, Element.ice));
        }
        return events;

      case ItemKey.darkCrystal:
      case ItemKey.ebonyCrystal:
        return _useAgingCrystals(c, key);

      case ItemKey.spiritCrystal:
        final index = _resolveStandingTarget(plan.target);
        if (index < 0) return const [];
        _consume(key);
        final t = _enemies[index];
        // Half of what is left. It cannot take the last point — the
        // crystal withers, it does not kill.
        final left = t.hp ~/ 2 < 1 ? 1 : t.hp ~/ 2;
        final taken = t.hp - left;
        t.hp = left;
        return [ItemUsed(c.slot, key), EnemySoulWithered(index, taken)];

      case ItemKey.summonCrystal:
        _consume(key);
        final spec = pickCrystalSummon(_rng);
        final summoned = rollSummon(
          spec: spec,
          form: spec.forms.first,
          summonSkill: 0,
          rng: _rng,
        );
        return [
          ItemUsed(c.slot, key),
          ..._seatAssistant(summoned, AssistantSource.crystal),
        ];

      case ItemKey.energyCrystal:
        _consume(key);
        // The living wake at full health; the dead come back with one
        // hit point. Poison is not its business.
        for (final m in _party) {
          if (!m.isPresent) continue;
          final wasDead = m.dead > 0;
          m
            ..dead = 0
            ..unconscious = 0
            ..hp = wasDead ? 1 : m.snapshot.maxHp;
        }
        return [ItemUsed(c.slot, key), PartyRestored(c.slot)];

      default:
        return const [];
    }
  }

  /// A crystal's fixed damage on one enemy: no roll to hit, but magic
  /// resistance and armour still apply (ch.9.8).
  List<BattleEvent> _crystalDamage(
    Combatant c,
    int index,
    int amount,
    Element element,
  ) {
    final t = _enemies[index];
    if (t.unconscious > 0) return _finishEnemy(c, index, DamageSource.spell);
    if (enemyResistsMagic(magicResistance: t.magicResistance, rng: _rng)) {
      return [
        EnemyBlocked(
          c.slot,
          index,
          BlockKind.resisted,
          source: DamageSource.spell,
        ),
      ];
    }
    final damage = amount - enemyDefence(ac: t.ac, level: t.level, rng: _rng);
    if (damage <= 0) {
      return [
        EnemyBlocked(
          c.slot,
          index,
          BlockKind.absorbed,
          source: DamageSource.spell,
        ),
      ];
    }
    return _damageEnemyWithElement(c, index, damage, element);
  }

  /// The Dark and Ebony crystals, used together on the one enemy they
  /// answer to: every number it has is halved (ch.9.8).
  List<BattleEvent> _useAgingCrystals(Combatant c, String key) {
    final hasBoth =
        (_held[ItemKey.darkCrystal] ?? 0) > 0 &&
        (_held[ItemKey.ebonyCrystal] ?? 0) > 0;
    if (!hasBoth) {
      return [CrystalDidNotReact(c.slot, key, CrystalSilence.needsItsPair)];
    }
    final index = _enemies.indexWhere(
      (e) => e.isConscious && !e.isClone && e.data.agedByCrystals,
    );
    if (index < 0) {
      return [CrystalDidNotReact(c.slot, key, CrystalSilence.wrongEnemy)];
    }
    _consume(ItemKey.darkCrystal);
    _consume(ItemKey.ebonyCrystal);
    final t = _enemies[index];
    t
      ..level = t.level ~/ 2 < 1 ? 1 : t.level ~/ 2
      ..strength = t.strength ~/ 2
      ..mentality = t.mentality ~/ 2
      ..endurance = t.endurance ~/ 2
      ..physicalResistance = t.physicalResistance ~/ 2
      ..magicResistance = t.magicResistance ~/ 2
      ..agility = t.agility ~/ 2
      ..accuracyPhysical = t.accuracyPhysical ~/ 2
      ..accuracyMagic = t.accuracyMagic ~/ 2
      ..ac = t.ac ~/ 2;
    return [ItemUsed(c.slot, key), EnemyAged(index)];
  }

  // --- flight -------------------------------------------------------

  /// The party runs, on the leader's word.
  ///
  /// The document's roll (`rand(50) > agility` fails) on the leader's
  /// agility, with the gap between the lines counting for it. Failure
  /// costs the whole round — the others were never asked.
  List<BattleEvent> _tryEscape(Combatant c) {
    final events = <BattleEvent>[EscapeAttempted(c.slot, gap: _gap)];
    if (escapeSucceeds(agility: c.snapshot.agility, gap: _gap, rng: _rng)) {
      _result = BattleResultCode.evade;
      events.add(EscapeSucceeded(c.slot));
    } else {
      events.add(EscapeFailed(c.slot));
    }
    return events;
  }

  // --- the enemy's turn ---------------------------------------------

  /// One enemy's turn — ch.8.6.
  ///
  /// Poison first; then, if it is still standing: one supernatural
  /// ability, then a special attack, a weapon blow or a spell.
  List<BattleEvent> _enemyTurn(int startIndex, EnemyInstance e) {
    final events = <BattleEvent>[..._enemyPoisonTick(startIndex, e)];
    if (!e.isConscious || !_partyAlive) return events;

    var index = startIndex;
    if (e.hasSupernatural) {
      final used = e.abilities.isNotEmpty
          ? _useAbility(index, e)
          : _useGrade(index, e);
      events.addAll(used.events);
      index = used.index;
      if (used.endsTurn || !_partyAlive) return events;
    }

    final intent = chooseEnemyIntent(
      special: e.special,
      castLevel: e.castLevel,
      strength: e.strength,
      agility: e.agility,
      accuracyPhysical: e.accuracyPhysical,
      accuracyMagic: e.accuracyMagic,
      actingEnemies: _actingEnemyCount,
      rng: _rng,
    );
    switch (intent) {
      case EnemyIntent.special:
        events.addAll(_enemySpecialAttack(index, e));
      case EnemyIntent.weapon:
        events.addAll(_enemyWeapon(index, e));
      case EnemyIntent.cast:
        events.addAll(_enemyCast(index, e));
      case EnemyIntent.idle:
        break;
    }
    return events;
  }

  /// Part 3: tries **one** of its abilities, picked at random (ch.8.6
  /// step 2). The pick indexes the set in declaration order.
  ({List<BattleEvent> events, int index, bool endsTurn}) _useAbility(
    int index,
    EnemyInstance e,
  ) {
    final abilities = e.abilities.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final ability = abilities.length == 1
        ? abilities.single
        : abilities[_rng.next(abilities.length)];
    final events = <BattleEvent>[];
    var at = index;
    var endsTurn = false;

    switch (ability) {
      case EnemyAbility.clone:
        at = _shuffleClones(index, e, events);
      case EnemyAbility.mindControl:
        if (_assistantCanBeTaken && mindControlFires(_rng)) {
          events.addAll(_takeAssistant(index));
        }
      case EnemyAbility.armourBreak:
        if (armourBreakFires(averagePartyAc: _averagePartyAc, rng: _rng)) {
          events.addAll(_breakArmour(index));
        }
      case EnemyAbility.summonAlly:
        if (_enemies.length < maxEnemies &&
            summonAllyFires(actingEnemies: _actingEnemyCount, rng: _rng)) {
          final data = enemyByLegacyId(
            setup.episode,
            pickSummonedAlly(e.key, _rng),
          );
          if (data != null) events.addAll(_callIn(index, data));
        }
      case EnemyAbility.massPoison:
      case EnemyAbility.massStun:
      case EnemyAbility.massDeath:
        if (massStatusFires(ableMembers: _ableMembers.length, rng: _rng)) {
          events.addAll(_massStatus(index, ability));
        }
      case EnemyAbility.healAll:
        events.addAll(
          _healEnemySide(
            index,
            healAllAmount(level: e.level, mentality: e.mentality),
          ),
        );
        endsTurn = e.data.endsTurnAfterHealAll;
    }
    return (events: events, index: at, endsTurn: endsTurn);
  }

  /// Parts 1 and 2: the supernatural grade. Each tier it has reached
  /// rolls in turn, and none of them ends the turn.
  ({List<BattleEvent> events, int index, bool endsTurn}) _useGrade(
    int index,
    EnemyInstance e,
  ) {
    final events = <BattleEvent>[];
    final notDead = _enemies.where((x) => x.acts && x.isPresent).length;

    if (e.superLevel >= 1 &&
        _enemies.length < maxEnemies &&
        gradeSummonFires(notDeadEnemies: notDead, rng: _rng)) {
      final id = gradeSummonedLegacyId(
        casterLegacyId: e.data.legacyId,
        rng: _rng,
      );
      final data = id == null ? null : enemyByLegacyId(setup.episode, id);
      if (data != null) events.addAll(_callIn(index, data));
    }
    if (e.superLevel >= 2 &&
        _assistantCanBeTaken &&
        gradeAbductFires(notDeadEnemies: notDead, rng: _rng)) {
      events.addAll(_takeAssistant(index));
    }
    if (e.superLevel >= 3 &&
        gradeMassSlayFires(special: e.special, rng: _rng)) {
      for (final m in _party) {
        if (!m.isPresent || m.dead > 0) continue;
        final outcome = resolveSpecialAttack(
          EnemySpecial.slay,
          enemyAgility: e.agility,
          targetLuck: m.snapshot.luck,
          rng: _rng,
        );
        if (outcome == SpecialAttackOutcome.applied) {
          _afflict(m, EnemySpecial.slay);
          events.add(
            MemberAfflicted(
              m.slot,
              EnemySpecial.slay,
              enemyIndex: index,
              mass: true,
            ),
          );
        } else if (outcome == SpecialAttackOutcome.evaded) {
          events.add(MemberEvadedAbility(m.slot, EnemySpecial.slay));
        }
      }
    }
    return (events: events, index: index, endsTurn: false);
  }

  /// 분신 — the real one hides among copies of itself.
  ///
  /// Every use puts the images back (a fallen image stands again) and
  /// fills the enemy list up to its eight lines, then moves the real one
  /// to a random place among them. The original prints nothing; the
  /// event only tells a view to redraw, **without saying which is
  /// real**. Returns where the real one stands now.
  int _shuffleClones(int index, EnemyInstance e, List<BattleEvent> events) {
    final group = <int>[index];
    for (var i = 0; i < _enemies.length; i++) {
      final other = _enemies[i];
      if (other.isClone && identical(other.cloneOwner, e)) {
        other.resetClone();
        group.add(i);
      }
    }
    while (_enemies.length < maxEnemies) {
      _enemies.add(EnemyInstance.cloneOf(e));
      group.add(_enemies.length - 1);
    }
    group.sort();
    events.add(EnemyClonesShifted(List.unmodifiable(group)));
    if (group.length < 2) return index;
    final to = group[_rng.next(group.length)];
    if (to == index) return index;
    final image = _enemies[to];
    // They change places on the list and on the field alike.
    final rank = image.rank;
    image.rank = e.rank;
    e.rank = rank;
    _enemies[to] = e;
    _enemies[index] = image;
    return to;
  }

  /// Whether 정신 지배 has anything to take and anywhere to put it.
  bool get _assistantCanBeTaken {
    final assistant = _assistant;
    return assistant != null &&
        assistant.isPresent &&
        _enemies.length < maxEnemies;
  }

  Combatant? get _assistant {
    for (final c in _party) {
      if (c.isAssistant) return c;
    }
    return null;
  }

  /// 정신 지배 — the assistant goes over to the enemy.
  ///
  /// Crystal creatures and the Archangel are immune; the roll has been
  /// made by then, so an immune assistant simply costs the enemy its
  /// attempt.
  List<BattleEvent> _takeAssistant(int index) {
    final a = _assistant!;
    if (a.snapshot.immuneToMindControl) return const [];
    final data = EnemyData(
      key: 'assistant',
      legacyId: 0,
      level: a.snapshot.level,
      hp: a.hp < 0 ? 0 : a.hp,
      strength: a.snapshot.strength,
      mentality: a.snapshot.mentality,
      endurance: a.snapshot.endurance,
      physicalResistance: a.snapshot.resistance,
      magicResistance: a.snapshot.resistance,
      agility: a.snapshot.agility,
      accuracyPhysical: a.snapshot.accuracy,
      accuracyMagic: a.snapshot.accuracy,
      ac: a.ac,
    );
    final turned = EnemyInstance(
      data,
      episode: setup.episode,
      override: EnemyOverride(
        displayName: a.name.isEmpty ? null : a.name,
        nameKey: a.name.isEmpty ? a.snapshot.nameKey : null,
        poison: a.poison > 0 ? 1 : 0,
        unconscious: a.unconscious > 0 || a.hp <= 0 ? 1 : 0,
        dead: a.dead > 0 ? 1 : 0,
      ),
      rank: a.rank,
    )..wasAssistant = true;
    _enemies.add(turned);
    a.departed = true;
    if (!_departedSlots.contains(a.slot)) _departedSlots.add(a.slot);
    return [MemberAbducted(index, a.slot, _enemies.length - 1)];
  }

  /// 갑옷 파괴 — each member's luck against `rand(21)`, and whoever
  /// fails loses a point of armour class for good.
  List<BattleEvent> _breakArmour(int index) {
    final events = <BattleEvent>[];
    for (final m in _party) {
      if (!m.isPresent) continue;
      final resisted = armourBreakResisted(luck: m.snapshot.luck, rng: _rng);
      final broken = !resisted && m.ac > 0;
      if (broken) {
        m.ac--;
        m.acLoss++;
      }
      events.add(ArmourBreakAttempted(index, m.slot, broken: broken));
    }
    return events;
  }

  /// Adds one enemy to the fight.
  List<BattleEvent> _callIn(int callerIndex, EnemyData data) {
    _enemies.add(EnemyInstance(data, episode: setup.episode)..summoned = true);
    return [EnemySummoned(callerIndex, _enemies.length - 1)];
  }

  /// 전체 중독 · 기절 · 즉사 — every member's luck against the roll.
  List<BattleEvent> _massStatus(int index, EnemyAbility ability) {
    final special = switch (ability) {
      EnemyAbility.massPoison => EnemySpecial.poison,
      EnemyAbility.massStun => EnemySpecial.knockOut,
      _ => EnemySpecial.slay,
    };
    final events = <BattleEvent>[];
    for (final m in _party) {
      if (!m.isPresent || m.dead > 0) continue;
      if (special == EnemySpecial.knockOut && m.unconscious > 0) continue;
      if (!massStatusCatches(
        ability: ability,
        luck: m.snapshot.luck,
        rng: _rng,
      )) {
        continue;
      }
      _afflict(m, special);
      events.add(
        MemberAfflicted(m.slot, special, enemyIndex: index, mass: true),
      );
    }
    return events;
  }

  /// What a special attack does once it lands.
  void _afflict(Combatant m, EnemySpecial special) {
    switch (special) {
      case EnemySpecial.poison:
        // Cumulative: each dose is one more point a round (ch.8.6).
        m.poison += 1;
      case EnemySpecial.knockOut:
        m.hp = 0;
        if (m.unconscious == 0) m.unconscious = 1;
      case EnemySpecial.slay:
        m.hp = 0;
        if (m.dead == 0) m.dead = 1;
      case EnemySpecial.none:
        break;
    }
  }

  /// 전체 회복, and the casting ladder's "heal everyone": the standing
  /// gain [amount] up to their ceiling, the unconscious wake with at
  /// least one hit point, and the dead come back **unconscious** — one
  /// stage per cast (appendix A.4).
  List<BattleEvent> _healEnemySide(int casterIndex, int amount) {
    final events = <BattleEvent>[];
    for (var i = 0; i < _enemies.length; i++) {
      final t = _enemies[i];
      if (t.isClone || t.hasLeft) continue;
      if (t.dead > 0) {
        t
          ..dead = 0
          ..unconscious = 1
          ..hp = 0;
        events.add(EnemyRevivedAlly(casterIndex, i, fromDeath: true));
      } else if (t.unconscious > 0) {
        t.unconscious = 0;
        if (t.hp < 1) t.hp = 1;
        events.add(EnemyRevivedAlly(casterIndex, i, fromDeath: false));
      } else {
        final gained = _raiseEnemyHp(t, amount);
        if (gained <= 0) continue;
        events.add(
          i == casterIndex
              ? EnemyHealedSelf(casterIndex, gained)
              : EnemyHealedAlly(casterIndex, i, gained),
        );
      }
    }
    return events;
  }

  /// Adds hit points up to the enemy's ceiling; returns what was gained.
  int _raiseEnemyHp(EnemyInstance t, int amount) {
    final ceiling = t.maxHp;
    if (t.hp >= ceiling || amount <= 0) return 0;
    final before = t.hp;
    t.hp = t.hp + amount > ceiling ? ceiling : t.hp + amount;
    return t.hp - before;
  }

  /// The single-target special attack — poison, knock-out or death.
  List<BattleEvent> _enemySpecialAttack(int index, EnemyInstance e) {
    final special = e.special;
    final pool = [
      for (final m in _party)
        if (switch (special) {
          // Someone who is not poisoned yet.
          EnemySpecial.poison => m.isPresent && m.dead == 0 && m.poison == 0,
          // Someone who can still act.
          EnemySpecial.knockOut => m.isConscious,
          // Anyone alive — the unconscious are not safe from it.
          EnemySpecial.slay => m.isPresent && m.dead == 0,
          EnemySpecial.none => false,
        })
          m,
    ];
    if (pool.isEmpty) return [EnemyAbilityUsed(index, special, -1)];
    final target = pool[_rng.next(pool.length)];
    final events = <BattleEvent>[EnemyAbilityUsed(index, special, target.slot)];
    switch (resolveSpecialAttack(
      special,
      enemyAgility: e.agility,
      targetLuck: target.snapshot.luck,
      rng: _rng,
    )) {
      case SpecialAttackOutcome.failed:
        events.add(EnemyAbilityMissed(index, special));
      case SpecialAttackOutcome.evaded:
        events.add(MemberEvadedAbility(target.slot, special));
      case SpecialAttackOutcome.applied:
        _afflict(target, special);
        events.add(MemberAfflicted(target.slot, special, enemyIndex: index));
    }
    return events;
  }

  /// An enemy's weapon blow — ch.8.6, with the position layer.
  ///
  /// ```
  /// [who]                     -> nearer is likelier
  /// [reach]                   -> out of band: accuracy drops, someone
  ///                              in front may take it
  /// rand(20) >= accuracy      -> missed
  /// strength x level x (1..10) / 5
  /// rand(550) < skill x shield -> the shield stops it whole
  /// - ac x level x (1..10) / 10 -> absorbed at zero or less
  /// ```
  List<BattleEvent> _enemyWeapon(int index, EnemyInstance e) {
    final able = _ableMembers;
    if (able.isEmpty) return const [];
    final weapon = e.weapon;
    var t =
        able[pickByRank(
          candidateRanks: [for (final c in able) c.rank],
          attackerRank: e.rank,
          gap: _gap,
          reach: reachOf(weapon),
          rng: _rng,
        )];

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

    if (enemyAttackMisses(
      accuracyPhysical: e.accuracyPhysical - reach.penalty.accuracy,
      rng: _rng,
    )) {
      events.add(EnemyAttackMissed(index));
      return events;
    }
    var damage = enemyWeaponDamage(
      // The close-in method of a long weapon is weaker for them too.
      strength: e.strength * attack.power ~/ 100,
      level: e.level,
      rng: _rng,
    );

    // The shield is a fighter's, and only with one on the arm. Bracing
    // adds to the same roll — and gives a guard, of a lesser kind, to
    // someone with no shield at all.
    final hasShield =
        t.snapshot.family == Family.fighter && t.snapshot.shieldPower > 0;
    if (hasShield || t.braced) {
      final blocked = shieldBlocks(
        shieldSkill: hasShield ? t.snapshot.shieldSkill : 0,
        shieldPower: hasShield ? t.snapshot.shieldPower : 0,
        bonus: t.braced
            ? braceBonus(t.hitsThisRound) * shieldBlockRange ~/ 100
            : 0,
        rng: _rng,
      );
      if (blocked) {
        t.hitsThisRound++;
        if (!hasShield) {
          events.add(MemberBlocked(index, t.slot, BlockKind.resisted));
          return events;
        }
        events.add(ShieldBlocked(index, t.slot));
        // The shield turns the attacker away, not its holder.
        if (pushBack(e.rank) == PushResult.moved) {
          e.rank = clampRank(e.rank + 1);
          e.staggered = true;
          events.add(AttackerShovedBack(t.slot, index, e.rank));
        }
        return events;
      }
    }

    damage -= memberDefence(ac: t.ac, level: t.snapshot.level, rng: _rng);
    if (damage <= 0) {
      events.add(MemberBlocked(index, t.slot, BlockKind.absorbed));
      return events;
    }
    t.hitsThisRound++;

    // Give ground rather than be dropped. Only they move, and only while
    // there is a rank behind them — which is what keeps this from being
    // an extra life.
    if (t.snapshot.dodgesBack &&
        !t.braced &&
        canRetreat(t.rank) &&
        damage >= t.hp &&
        t.unconscious == 0) {
      t.rank = clampRank(t.rank + 1);
      events.add(DodgedBack(t.slot, t.rank));
      return events;
    }

    var landed = damage;
    final weak = t.snapshot.weakTo.contains(attack.element);
    // Bracing refuses to give ground.
    if (!t.braced && knocksBack(attack.element, hitWeakness: weak)) {
      if (pushBack(t.rank) == PushResult.moved) {
        t.rank = clampRank(t.rank + 1);
        t.staggered = true;
        events.add(MemberPushedBack(t.slot, t.rank));
      } else {
        final extra = damage * corneredBonusPercent ~/ 100;
        landed += extra;
        events.add(MemberCornered(t.slot, extra));
      }
    } else if (t.staggered) {
      landed += damage * staggerBonusPercent ~/ 100;
    }
    events.addAll(_damageMember(index, t, landed, DamageSource.physical));
    return events;
  }

  /// The casting ladder — `rules/enemy_ai.dart` decides, this applies.
  List<BattleEvent> _enemyCast(int index, EnemyInstance e) {
    final able = _ableMembers;
    if (able.isEmpty) return const [];
    var enemyCount = 0;
    var totalHp = 0;
    var totalMaxHp = 0;
    for (final other in _enemies) {
      if (!other.acts || !other.isPresent) continue;
      enemyCount++;
      totalHp += other.hp < 0 ? 0 : other.hp;
      totalMaxHp += other.maxHp;
    }

    final plan = chooseEnemySpell(
      castLevel: e.castLevel,
      hp: e.hp,
      maxHp: e.maxHp,
      level: e.level,
      mentality: e.mentality,
      ableMembers: able.length,
      enemyCount: enemyCount,
      totalEnemyHp: totalHp,
      totalEnemyMaxHp: totalMaxHp,
      averagePartyAc: _averagePartyAc,
      rng: _rng,
    );

    switch (plan) {
      case NoSpell():
        return const [];
      case HealSelf(:final amount):
        return [EnemyHealedSelf(index, _raiseEnemyHp(e, amount))];
      case HealAllies(:final amount):
        return _healEnemySide(index, amount);
      case BreakArmour():
        return _breakArmour(index);
      case CastAtAll():
        final spell = enemyAreaSpell(e.mentality);
        final events = <BattleEvent>[EnemyCastSpell(index, spell.kind, -1)];
        for (final m in able) {
          events.addAll(_enemySpellOn(index, e, m, spell.coefficient));
        }
        return events;
      case CastAtOne(:final target):
        final m = _pickSpellTarget(target);
        if (m == null) return const [];
        final spell = enemySingleSpell(e.mentality);
        return [
          EnemyCastSpell(index, spell.kind, m.slot),
          ..._enemySpellOn(index, e, m, spell.coefficient),
        ];
    }
  }

  /// Who the ladder's choice resolves to.
  Combatant? _pickSpellTarget(EnemySpellTarget target) {
    switch (target) {
      case EnemySpellTarget.anyPresent:
        // Cast level 1 does not look: any occupied seat, standing or
        // not. A spell that lands on someone already down goes onto
        // their counters.
        final present = [
          for (final c in _party)
            if (c.isPresent) c,
        ];
        return present.isEmpty ? null : present[_rng.next(present.length)];
      case EnemySpellTarget.randomConscious:
        final able = _ableMembers;
        return able.isEmpty ? null : able[_rng.next(able.length)];
      case EnemySpellTarget.weakestConscious:
        Combatant? best;
        for (final c in _ableMembers) {
          if (best == null || c.hp < best.hp) best = c;
        }
        return best;
    }
  }

  /// One enemy spell on one member: aim, the member's resistance, then
  /// power less its spread and the member's armour.
  List<BattleEvent> _enemySpellOn(
    int index,
    EnemyInstance e,
    Combatant m,
    int coefficient,
  ) {
    if (enemySpellMisses(accuracyMagic: e.accuracyMagic, rng: _rng)) {
      return [EnemySpellMissed(index, m.slot)];
    }
    if (memberResistsSpell(resistance: m.snapshot.resistance, rng: _rng)) {
      return [
        MemberBlocked(
          index,
          m.slot,
          BlockKind.resisted,
          source: DamageSource.spell,
        ),
      ];
    }
    final damage = enemySpellDamage(
      power: enemySpellPower(coefficient: coefficient, level: e.level),
      memberAc: m.ac,
      memberLevel: m.snapshot.level,
      rng: _rng,
    );
    if (damage <= 0) {
      return [
        MemberBlocked(
          index,
          m.slot,
          BlockKind.absorbed,
          source: DamageSource.spell,
        ),
      ];
    }
    return _damageMember(index, m, damage, DamageSource.spell);
  }

  /// Applies damage to one party member — hit points, or the counter of
  /// whichever state they are already in (ch.8.6).
  List<BattleEvent> _damageMember(
    int enemyIndex,
    Combatant t,
    int damage,
    DamageSource source,
  ) {
    final wasDown = t.unconscious > 0 || t.dead > 0;
    final change = applyMemberDamage(
      hp: t.hp,
      unconscious: t.unconscious,
      dead: t.dead,
      amount: damage,
      deathThreshold: t.deathThreshold,
    );
    t
      ..hp = change.hp
      ..unconscious = change.unconscious
      ..dead = change.dead;
    return [
      MemberDamaged(enemyIndex, t.slot, damage, source, whileDown: wasDown),
      if (change.outcome == VitalsOutcome.collapsed) MemberCollapsed(t.slot),
      if (change.outcome == VitalsOutcome.died) MemberDied(t.slot),
    ];
  }

  // --- settlement ---------------------------------------------------

  /// Decides the result, pays a win, and seals the outcome.
  ///
  /// Gold is the only thing left to hand out — experience was paid as
  /// each enemy fell. Game over and levelling belong to the RPG.
  List<BattleEvent> _finish() {
    if (!_partyAlive) {
      _result = BattleResultCode.lose;
    } else if (!_enemiesAlive && _result != BattleResultCode.evade) {
      _result = BattleResultCode.win;
    }

    final events = <BattleEvent>[];
    var gold = 0;
    if (_result == BattleResultCode.win) {
      for (final e in _enemies) {
        // The fallen pay, and so does one that was frightened off — it
        // is as beaten as the rest. A persuaded enemy, an image, and an
        // assistant the enemy turned do not (ch.8.8).
        final beaten = e.unconscious > 0 || e.dead > 0 || e.fled;
        if (!beaten || !e.paysGold) continue;
        gold += goldFor(enemyLevel: e.experienceLevel, enemyAc: e.goldAc);
      }
      events.add(GoldSettled(gold));
    }
    events.add(BattleEnded(_result));

    final assistant = _assistant;
    final seated = [
      for (final c in _party)
        if (c.isPresent) c,
    ];
    _outcome = BattleOutcome(
      resultCode: _result,
      combatants: [for (final c in seated) c.toResult()],
      goldGained: gold,
      consumedItems: Map.unmodifiable(_spent),
      arrowsUsed: _arrowsUsed,
      newAssistant:
          assistant != null && assistant.isPresent && assistant.joinedInBattle
          ? assistant.toSnapshot()
          : null,
      departedSlots: List.unmodifiable([
        for (final slot in _departedSlots)
          if (!seated.any((c) => c.slot == slot)) slot,
      ]),
      enemies: List.unmodifiable([for (final e in _enemies) e.toState()]),
    );
    _phase = BattlePhase.finished;
    return events;
  }

  // --- queries ------------------------------------------------------

  /// An image standing alone is not an enemy left to beat.
  bool get _enemiesAlive => _enemies.any((e) => e.acts && e.isConscious);

  /// The sixth seat counts: while the assistant can act the party has
  /// not lost (ch.7.8).
  bool get _partyAlive => _party.any((c) => c.isConscious);

  int get _actingEnemyCount =>
      _enemies.where((e) => e.acts && e.isConscious).length;

  List<Combatant> get _ableMembers => [
    for (final c in _party)
      if (c.isConscious) c,
  ];

  int get _averagePartyAc {
    var sum = 0;
    var count = 0;
    for (final c in _party) {
      if (!c.isPresent) continue;
      sum += c.ac;
      count++;
    }
    return count == 0 ? 0 : sum ~/ count;
  }

  Combatant? _memberAt(int slot) {
    for (final c in _party) {
      if (c.slot == slot && c.isPresent) return c;
    }
    return null;
  }

  /// Whether a blow may land on this enemy at all: on the field, and
  /// either standing or — when the option allows — unconscious, which
  /// finishes it (ch.8.5 step 1).
  bool _canBeStruck(EnemyInstance e) =>
      e.isPresent && (e.unconscious == 0 || setup.attackUnconscious);

  List<int> _byRank(bool Function(EnemyInstance e) test) {
    final found = [
      for (var i = 0; i < _enemies.length; i++)
        if (test(_enemies[i])) i,
    ];
    found.sort((a, b) {
      final byRank = _enemies[a].rank.compareTo(_enemies[b].rank);
      return byRank != 0 ? byRank : a.compareTo(b);
    });
    return found;
  }

  /// Enemies still standing, nearest rank first.
  List<int> _standingTargets() => _byRank((e) => e.isConscious);

  /// What a blow may be aimed at: the standing, and after them the
  /// unconscious when the option allows finishing them.
  List<int> _strikeTargets() => [
    ..._standingTargets(),
    if (setup.attackUnconscious)
      ..._byRank((e) => e.isPresent && e.unconscious > 0),
  ];

  int _firstStandingEnemy() => _enemies.indexWhere((e) => e.isConscious);

  /// The enemy a blow lands on: the one asked for, or — if that one is
  /// gone — "the next number" (ch.8.5 step 1), wrapping round the list.
  int _resolveTarget(int requested, bool Function(EnemyInstance e) test) {
    final count = _enemies.length;
    final start = requested < 0 || requested >= count ? 0 : requested;
    for (var step = 0; step < count; step++) {
      final index = (start + step) % count;
      if (test(_enemies[index])) return index;
    }
    return -1;
  }

  int _resolveStrikeTarget(int requested) =>
      _resolveTarget(requested, _canBeStruck);

  int _resolveStandingTarget(int requested) =>
      _resolveTarget(requested, (e) => e.isConscious);
}
