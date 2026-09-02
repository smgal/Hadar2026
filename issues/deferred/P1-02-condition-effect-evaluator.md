# P1-02 Condition/Effect 모델과 평가기 (op 18 / do 25)

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-01 대기)
- **구간**: P1
- **규모**: L
- **선행**: P1-01
- **설계 근거**: [BP-21 §6](../../blueprint/21_content_pack_spec.md)(**DSL 소유 장**) · [D-05 · D-21 · D-29a · D-30 · D-31](../../blueprint/_meta/DECISIONS.md) · [BP-27 §2.4 · §9.2](../../blueprint/27_runtime_engine.md) · [BP-42 §1.7](../../blueprint/42_item_and_inventory.md)

## 문제

조건 분기와 상태 변경을 **데이터로 표현할 수단이 하나도 없다.** 현재 있는 것은 셋뿐이고 전부 부족하다.

- **cm2** — `packages/cm2_script/lib/src/parser.dart` 에 루프도 함수 정의도 없고, 산술은 `Add` 뿐이다.
  더 나쁜 것은 침묵 실패다: 미등록 함수는 "Unknown function" 을 찍고 **0을 반환**해 조건문이 조용히 오분기한다
  (GROUND_TRUTH §9). 정상 심볼이라도 범위 밖 값은 조용히 무시된다 —
  `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:362-391` 의
  `Flag::Set`/`Flag::Reset`/`Variable::Set`/`Variable::Add` 는 **범위 검사에 `else` 가 없다**(부록 F-1).
- **네이티브 Dart** — `hadar2026_app/lib/application/scripting/map_script.dart:41-48` 의 `isFlagSet` 이
  `return false;` 스텁이라 조건 분기가 **한 번도 동작한 적이 없다**(부록 A-3).
- **JSON 티어** — `hadar2026_app/lib/application/tile_event_dispatcher.dart:166-178` 이
  좌표 일치하는 **첫 이벤트**의 `dialogLines` 를 무조건 순서대로 출력한다. 조건도 상태 참조도 없다.

즉 "플래그가 켜져 있으면 다른 말을 한다" 를 표현할 문법이 **레포 전체에 없다.**

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** 퀘스트의 정의 자체가 조건과 효과다 —
전제조건(`prerequisites`), 목표 판정, 단계 전이(`next`), 보상(`rewards`)이 전부 Condition/Effect 로 표현된다
([BP-23 §23.2](../../blueprint/23_quest_model.md)). 이것이 없으면 P1-07(대화)·P1-08(퀘스트)·P1-12(검증)이
표현할 대상을 갖지 못한다. P1 의 사실상 첫 실질 작업이다.

그리고 이 평가기는 **런타임과 CLI 검증기가 공유하는 유일한 구현**이다(D-12 · BP-33 §9.2).
두 벌로 갈라지면 손 저작자가 "검증 통과 → 플레이 시 다른 분기" 를 만나고, 그 원인은 추적하기 매우 어렵다.

## 무엇을 할 것인가

**설계는 [BP-21 §6](../../blueprint/21_content_pack_spec.md) 이 소유한다. op/do 시그니처를 이 이슈에 재서술하지 않는다.**
구현 단위만 적는다.

1. `packages/hadar_content/lib/condition.dart`
   - `Condition` 모델 + `fromJson`, `ConditionOp` 열거(**18종** — [BP-21 §6.3](../../blueprint/21_content_pack_spec.md) 표 C1~C18).
   - `ConditionEvaluator.evaluate(Condition, WorldStateView)` — **부작용 없음**. `WorldStateMutator` 를 받지 않는다.
   - 미정의 입력의 기본값(없는 플래그 → `false`, 없는 변수 → `0` 등)은 BP-21 §6.3 표의 마지막 열이 정본이다.
   - 중첩 상한(`and`/`or` 1~16개, 깊이 ≤8)을 파싱 시점에 검사한다.
2. `packages/hadar_content/lib/effect.dart`
   - `Effect` 모델 + `EffectDo` 열거(**25종** — [BP-21 §6.6](../../blueprint/21_content_pack_spec.md) 표 E1~E25).
     D-31 이 22 → 25 로 확장했고(`restore`·`cure`·`grant_buff`) `schemaVersion` 이 1 → 2 로 올랐다.
   - `EffectApplier.apply(Effect, WorldStateMutator)` — 순서대로 적용.
   - `DeferredEffect` — 도메인이 표현만 하고 실행 못 하는 do(`warp`·`start_battle`·`play_dialogue`·`change_tile`·`set_encounter` 계열)를
     지연 목록으로 반환한다. 실제 실행은 P1-11 이 만드는 `HDEffectBridge` 가 한다
     ([BP-27 §2.8](../../blueprint/27_runtime_engine.md)).
   - `grant_buff` 의 **buff 화이트리스트는 3종뿐**이다 — `magicTorch`·`walkOnWater`·`canUseEsp`.
     근거는 [BP-42 §1.7](../../blueprint/42_item_and_inventory.md) 의 실측:
     `hadar2026_app/lib/domain/party/party.dart:18-27` 의 `PartyBuffs` 8필드 중 5개는 읽는 곳이 0곳이다
     (`levitation`·`walkOnSwamp`·`mindControl`·`penetration`·`canUseSpecialMagic`).
     **화이트리스트 밖은 하드 실패**로 거부한다.
3. `packages/hadar_content/lib/world_rng.dart`
   - `WorldRng` — 커서 기반 시드 난수. **Effect·전투 등 쓰기 경로 전용**.
   - `mix([...])` — 무커서 해시. 구현은 [BP-27 §9.2](../../blueprint/27_runtime_engine.md) 소유
     (웹 정수 제약 때문에 32비트 2워드로 고정).
4. **`chance` 는 커서를 밀지 않는다**(D-21). 정본 유도식은 D-30 의
   `chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p` 다.
   - `chanceSeedId` 는 **빌드가 계산해 번들에 굽는 정수**이고, 런타임은 `Condition.chanceSeedId` 를 **읽기만** 한다(D-29a).
     문자열 키 `chanceKey`(형식 `<contextId>#<evalPath>`)의 소유는 BP-21 §6.5 다. `siteId` 표기는 폐기다.
   - `step` 이 시드에 들어가므로 같은 세이브·같은 위치라도 **스텝이 다르면 결과가 다르다**(D-30).
     영구 결과를 원하면 Effect 의 `set_flag` 로 래치하는 것이 정본 패턴이다.

계층: 두 파일 모두 `packages/hadar_content/lib/` (순수 Dart, D-12 · [BP-30 R-30-13](../../blueprint/30_toolchain_overview.md)).
`hadar2026_app/lib/domain/content/condition.dart`·`effect.dart` 는 P1-01 이 만든 **배럴 1줄**을 유지한다.

## 완료 판정 기준

- [ ] `ConditionOp` 이 **정확히 18개**, `EffectDo` 가 **정확히 25개**이고, 그 밖의 `op`/`do` 문자열은 파싱에서 **예외**를 던진다 (조용히 무시하지 않는다)
- [ ] `chance` 평가가 `WorldStateMutator` 를 인자로 받지 않는다 — 시그니처로 강제된다 (컴파일 타임 보장)
- [ ] 같은 `(seed, step, chanceSeedId)` 로 100회 평가하면 100회 같은 값이 나온다
- [ ] `grant_buff` 에 `levitation` 을 넣으면 파싱이 실패한다 (화이트리스트 3종 밖)
- [ ] `restore` 에 `resource: "hp"` 를 넣으면 파싱이 실패한다 (E19 `heal_party` 와 중복 정의 금지)
- [ ] **테스트 1**: `packages/hadar_content/test/condition_test.dart` — 18 op 전량의 참/거짓 각 1케이스 +
      미정의 입력 기본값(없는 플래그·없는 변수·`quest_state` 미등록 → `inactive`) + 중첩 깊이 상한
- [ ] **테스트 2**: `packages/hadar_content/test/effect_test.dart` — 25 do 전량의 적용 결과 +
      경계 동작(`take_item` 부족분 0 클램프, `add_var` int32 클램프, `advance_quest` 역행 거부)
- [ ] **테스트 3**: `packages/hadar_content/test/chance_test.dart` — D-30 유도식을 고정한다.
      `step` 이 바뀌면 결과가 바뀌고, 같은 `step` 안에서는 몇 번 평가해도 같다는 두 명제를 함께 고정
- [ ] `dart analyze`(warning fatal) · `dart test` 통과

## 하지 않을 것

- `WorldStateView`/`WorldStateMutator` 의 **구현체** — P1-03 이 만든다. 이 이슈는 인터페이스에만 의존한다.
- 지연 효과의 **실제 실행**(`warp` 로 맵을 옮기는 것 등) — P1-11 의 `HDEffectBridge`.
- `chanceSeedId` 를 **굽는** 빌드 규칙 — P1-12(빌드 쪽 소유는 BP-35).
- 검증 규칙 `CV-nn` 카탈로그 구현 — P1-12 (L1).
- 솔버의 `chance` 양분기 탐색 — **P2**.
