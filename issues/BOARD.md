# 이슈 보드

> 상태 규약은 [README.md](README.md), 구간 정의는 [MILESTONES.md](MILESTONES.md), 판정 이력은 [DECISION-LOG.md](DECISION-LOG.md).
> **노선: sample-first + cm2.** 선언적 콘텐츠 팩 노선은 [deferred/](deferred/) 로 보류되었다.

## W1 — RPG 핵심 재작성 (**완료** 2026-09-09 · 9/9 · [10차 판정](DECISION-LOG.md))

> 인물·파티·아이템·장비를 **새 순수 Dart 패키지로 다시 쓴다.** 기존 코드를 고치지 않는다.
> 전투가 간 길(`application/battle.dart` → `packages/hd_battle`)과 같다.
> 자세한 것은 [W1 _README](W1-world-core/_README.md) · 만져 보려면
> [hd_world_lab/RUN.md](../hd_world_lab/RUN.md).

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [W1-01](W1-world-core/W1-01-package-skeleton.md) | 패키지 셋 · 독립성 게이트 · CI | **DONE** | M | 없음 |
| [W1-02](W1-world-core/W1-02-slots-and-items.md) | 부위 여덟 · 아이템 31종 · 자격 검사 | **DONE** | L | W1-01 ✅ |
| [W1-03](W1-world-core/W1-03-derived-values.md) | 파생값 무저장 — 무기 종류 · 수치 · 통행 · 시야 | **DONE** | L | W1-02 ✅ |
| [W1-04](W1-world-core/W1-04-classes-and-styles.md) | 직업 17 이식 · 상시 지시 7 유도 | **DONE** | M | W1-01 ✅ |
| [W1-05](W1-world-core/W1-05-openapi-lab.md) | OpenAPI 표면 · 마우스 화면 | **DONE** | L | W1-03 ✅ |
| [W1-06](W1-world-core/W1-06-battle-bridge.md) | 전투 다리 — `hd_world` → `hd_battle` (**규격 v4**) | **DONE** | M | W1-03 ✅ |
| [W1-07](W1-world-core/W1-07-save-format.md) | 세이브 — 부위 여덟을 싣는 포맷 | **DONE** | M | W1-02 ✅ |
| [W1-08](W1-world-core/W1-08-cm2-adapter.md) | cm2 어댑터 — 속성 15개 · 아이템 명령 | **DONE** | M | W1-02 ✅ |
| [W1-09](W1-world-core/W1-09-app-swap.md) | 앱 교체 — 포트 뒤에서 옛 모델을 뺀다 | **DONE** | L | W1-06·07·08 ✅ |

> **W1 은 B7·B8·B9 를 대신한다.** BP-44~47 이 요구하는 변경이 전부 같은 파일 여섯 개를
> 만지므로, 세 트랙으로 나누어 같은 파일을 세 번 고치는 대신 한 번 다시 쓴다.
> 적 명세(BP-44 §1~§6)는 `hd_battle` 쪽이라 **여전히 별개**다.

## G1 — 아이템·장비 이식 (**완료** 2026-09-03 · 10/10)

> 원본: `REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs`(877줄) · `GameEventEquipment.cs`(448줄) · `ObjTypes.cs`
> **설계가 아니라 이식이다.**

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [G1-01](G1-items/G1-01-item-model-port.md) | `Item`/`ItemSub`/`ITEM_TYPE` 을 `domain/item/` 으로 이식 | **DONE** | M | 없음 |
| [G1-02](G1-items/G1-02-item-data.md) | 아이템 실데이터 확보 (`books.json` 은 무기5·방어구3 샘플뿐) | **DONE** | M | G1-01 |
| [G1-03](G1-items/G1-03-party-inventory.md) | 파티 소지품 — `HDParty` 에 아이템 목록 | **DONE** | M | G1-01 |
| [G1-04](G1-items/G1-04-equipment-slots.md) | 장비 슬롯 재편 — 정수 3칸 → 부위별(`ARMOR`/`HEAD`/`LEG`/`ORNAMENT` 포함) | **DONE** | M | G1-01 |
| [G1-05](G1-items/G1-05-equipment-effect.md) | 장비 효과 배선 — `powOfWeapon ← atta_pow` · `ac` 합산 | **DONE** | M | G1-04 |
| [G1-06](G1-items/G1-06-item-names.md) | `"무기1"` → 실제 이름 (노출 4곳) | **DONE** | S | G1-02 |
| [G1-07](G1-items/G1-07-inventory-ui.md) | 소지품·장비 화면 (`GameEventEquipment.cs` 참조) | **DONE** | L | G1-03·G1-04 |
| [G1-08](G1-items/G1-08-cm2-item-commands.md) | cm2 커맨드 `Item::Give/Take/Has` | **DONE** | S | G1-03 |
| [G1-09](G1-items/G1-09-item-save.md) | 세이브에 소지품·장비 포함 | **DONE** | M | G1-03·G1-04 |
| [P0-19](P0-foundation/P0-19-dead-equipment-fields.md) | `powOfShield`/`powOfArmor` 죽은 필드 정리 | **DONE** | S | G1-05 |
| [G1-10](G1-items/G1-10-flame-sword-power.md) | `화염검` 공격력이 자리표시값 — **원작에 값이 없음** (현재 도달 불가라 무해) | TODO | S | 없음 |

> **G1-10 은 G1 완료 후 발견된 사후 항목**이다. 실플레이 영향이 0이므로 구간 완료를 막지 않는다.
> 화염검을 실제로 주는 콘텐츠를 만들 때 꺼낸다.

## G2 — 전투 정합 (**완료** 2026-09-03 · 5/5)

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [G2-01](G2-combat/G2-01-defense-reads-equipment.md) | 방어 계산이 장비에서 온 `ac` 를 읽게 한다 | **DONE** | M | G1-05 |
| [G2-02](G2-combat/G2-02-unregistered-cm2-symbols.md) | 미등록 cm2 심볼 6종 9곳 정리 (`Party::CheckIf` 등) | **DONE** | M | 없음 |
| [P0-12](P0-foundation/P0-12-battle-result-inverted.md) | 전투 결과 코드가 cm2 상수와 반대 | **DONE** | S | 없음 |
| [P0-13](P0-foundation/P0-13-battle-result-defaults-win.md) | `Battle::Result()` 가 전투 없이 승리 반환 | **DONE** | S | P0-12 |
| [P0-15](P0-foundation/P0-15-enemy-id-zero.md) | 적 id 0 영구 소환 불가 — 유효 범위 1~74 | **DONE** | S | 없음 |

## S1 — 샘플 퀘스트 (**착수 가능** — G1 이 2026-09-03 완료 · 코드 변경 0)

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [S1-01](S1-sample-quest/S1-01-quest-design.md) | 샘플 퀘스트를 설계한다 (원작 톤·3단계·플래그 배분) | TODO | S | G1 ✅ |

> **G1 이후 변경**: "물건을 구해 오라" 를 **플래그가 아니라 실제 아이템**으로 표현한다(3차 판정).
> S1-01·S1-03 의 플래그 배분표는 **퀘스트 진행 상태에만** 쓰고, 아이템 소지는 `Item::Has` 로 판정한다.
| [S1-02](S1-sample-quest/S1-02-new-map.md) | 새 맵 `Map016.json` 과 NPC 3명을 배치한다 | BLOCKED | M | S1-01 |
| [S1-03](S1-sample-quest/S1-03-quest-cm2.md) | `Map016.cm2` 와 `flag4quest1.cm2` 를 쓴다 | BLOCKED | M | S1-02 · G1-08 |
| [S1-04](S1-sample-quest/S1-04-playthrough.md) | 플레이로 완주하고 세이브·로드를 확인한다 | BLOCKED | S | S1-03 |
| [S1-99](S1-sample-quest/S1-99-friction-log.md) | **저작 중 막힌 지점을 기록한다** (S2 의 입력) | BLOCKED | S | S1-01 |

## S2 — 실측된 걸림돌만 제거 (S1 걸림돌 기록 대기)

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [S2-01](S2-enablers/S2-01-flag-registry.md) | 플래그 인덱스 레지스트리 — 충돌을 기계가 막는다 | BLOCKED | M | S1-99 |
| [S2-02](S2-enablers/S2-02-cm2-override-chain.md) | cm2 override 체인 — 한 맵에 퀘스트 여러 개 | BLOCKED | M | S1-99 |
| [S2-03](S2-enablers/S2-03-cm2-linter.md) | cm2 린터 — 침묵 실패를 빌드 시 잡는다 | BLOCKED | M | S1-99 |
| [S2-04](S2-enablers/S2-04-map-editor-cm2-support.md) | 맵 에디터가 cm2·플래그를 인지한다 | BLOCKED | M | S1-99 |

## S3 — AI 생성 (S2 이후)

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [S3-01](S3-generation/S3-01-quest-spec-format.md) | 퀘스트 개요 서식 (AI 입력 형식) | BLOCKED | S | S1-04 |
| [S3-02](S3-generation/S3-02-generation-prompt.md) | 생성 프롬프트 — 개요 → cm2 + 플래그 | BLOCKED | M | S3-01 · S2 |
| [S3-03](S3-generation/S3-03-map-generation.md) | 맵·NPC 배치 생성 (맵 에디터 API 활용) | BLOCKED | M | S3-01 |
| [S3-04](S3-generation/S3-04-minimal-validation.md) | 최소 검증 — 심볼·플래그 충돌·좌표 존재 | BLOCKED | M | S2-03 |
| [S3-05](S3-generation/S3-05-pilot-batch.md) | 파일럿 3개 배치 생성 + 사람 플레이 검수 | BLOCKED | M | S3-02·03·04 |

## B 트랙 — 전투 분리·확장·재통합 (**B1 완료** 2026-09-04 · 6/6)

> 판정: [DECISION-LOG 4차](DECISION-LOG.md) (2026-09-04) · 구간 정의: [MILESTONES §7](MILESTONES.md)
> **S 트랙과 별개 트랙이다.** S1 과 B1 의 선후는 아직 정하지 않았다.
> 산출물은 독립 실행되는 디렉토리 2개 — `packages/hd_battle/`(model) + `hd_battle_console/`(콘솔 view).

### B1 — 전투 분리 (**완료** 2026-09-04 · 규칙 무변경 이식 + 호출 방향 뒤집기 + 시드 주입)

> 산출물: [`packages/hd_battle/`](../packages/hd_battle/) (model, 순수 Dart) +
> [`hd_battle_console/`](../hd_battle_console/) (콘솔 view, `dart run bin/battle.dart`)

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [B1-01](B1-battle-extract/B1-01-package-skeleton.md) | `packages/hd_battle` 골격과 모드 인계 규격 초안 | **DONE** | M | 없음 |
| [B1-02](B1-battle-extract/B1-02-enemy-table.md) | 적 테이블 75행을 snake_case 문자열 키로 이식 | **DONE** | S | B1-01 |
| [B1-03](B1-battle-extract/B1-03-formula-port.md) | **전투식 19개**를 시드 주입 순수 함수로 이식 | **DONE** | L | B1-01 · B1-02 |
| [B1-04](B1-battle-extract/B1-04-invert-call-direction.md) | 호출 방향 뒤집기 — model 이 view 를 부르지 않게 | **DONE** | L | B1-03 |
| [B1-05](B1-battle-extract/B1-05-console-view.md) | 콘솔 view 와 fixture 러너 (fixture 7개) | **DONE** | M | B1-04 |
| [B1-06](B1-battle-extract/B1-06-ci-guard.md) | CI 가 불변조건 4개를 강제 | **DONE** | S | B1-01 |

### B2 — 전투 확장 (**완료** 2026-09-05 · 12/12)

> 판정: [7차 — 붙인다](DECISION-LOG.md) · 규격: `packages/hd_battle/CONTRACT.md` **v1**
> 근거는 [`GROUND_TRUTH` 부록 O·Q·R·S·T·U](../blueprint/_meta/GROUND_TRUTH.md).
> **목록이 두 번 늘었다** — B2-10 · B2-11 은 착수 중에 발견해 뗀 것이다(규격 영향).

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [B2-04](B2-battle-expand/B2-04-unconscious-stage.md) | 의식불명 단계 — 세 경로를 한 규칙으로 | **DONE** | S | B1 ✅ |
| [B2-03](B2-battle-expand/B2-03-status-effects.md) | 상태 모델 — 누적값 + 능력치 감소 | **DONE** | L | B2-04 |
| [B2-02](B2-battle-expand/B2-02-heal-applies.md) | 치료 4갈래 조합 + SP 차감 | **DONE** | M | B2-03 |
| [B2-01](B2-battle-expand/B2-01-magic-effects.md) | 공격 마법 1~18 — **카테고리 경계 정정** | **DONE** | L | B2-02 |
| [B2-10](B2-battle-expand/B2-10-esp-abilities.md) | 초능력 41~45 — **독심이 적을 영입한다** | **DONE** | L | B2-01 |
| [B2-07](B2-battle-expand/B2-07-enemy-behavior.md) | 적 AI 사다리 — **동료 치료·부활** · 행운 방어 | **DONE** | M | B2-01·B2-03 |
| [B2-11](B2-battle-expand/B2-11-superhuman-casting.md) | 초자연 시전 — **적 소환 · 파티원 탈취** | **DONE** | L | B2-07 |
| [B2-05](B2-battle-expand/B2-05-turn-order.md) | 행동 순서가 민첩을 읽는다 | **DONE** | M | B2-07 |
| [B2-06](B2-battle-expand/B2-06-battle-items.md) | 전투 중 물건 — 마법 지수를 쓰지 않는다 | **DONE** | M | B2-07 |
| [B2-08](B2-battle-expand/B2-08-slot-mitigation.md) | 부위별 감쇠 + **방패는 다른 축** | **DONE** | M | B2-07 |
| [B2-09](B2-battle-expand/B2-09-elemental-affinity.md) | 속성 상성 — 얇게 | **DONE** | L | B2-01 |
| [B2-99](B2-battle-expand/B2-99-freeze-contract.md) | **모드 인계 규격 v1 확정** | **DONE** | M | B2 전체 |

### B5 — 위치 전투 (**완료** 2026-09-05 · 11/11 · [8차 판정](DECISION-LOG.md))

> 전투에 **위치**를 넣는다 — 각자의 `rank`(1~3) + 양측 공통 `gap`(0~2). 좌표가 아니다.
> 근간은 드래곤 퀘스트로 둔다. [B5 _README](B5-battle-position/_README.md) 를 먼저 읽을 것.
>
> **불변식**: 사거리 밖은 **벌점이지 무효가 아니다.** 헛턴이 나오는 경로가 없어야 한다.
>
> **⚠ 파티는 5인 + 소환수가 기본이다.** 착수 시점에 fixture 17개 중 14개가 2인이라
> 밸런스 측정이 대표성이 없었다 — B5-00 이 그것을 고쳤다
> ([부록 W](../blueprint/_meta/GROUND_TRUTH.md)).
>
> 실측은 [부록 X](../blueprint/_meta/GROUND_TRUTH.md), 규격은
> `packages/hd_battle/CONTRACT.md` **v2**.

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [B5-00](B5-battle-position/B5-00-five-member-fixtures.md) | fixture 를 5인 기준으로 재작성 + **한 줄 재생성** | **DONE** | M | 없음 |
| [B5-01](B5-battle-position/B5-01-rank-and-gap.md) | `rank` 와 `gap` — 위치의 뼈대 (**규격**) | **DONE** | L | B5-00 ✅ |
| [B5-04](B5-battle-position/B5-04-rank-weighted-targeting.md) | 적의 대상 선택을 열 가중으로 — **탱커가 성립한다** | **DONE** | S | B5-01 ✅ |
| [B5-02](B5-battle-position/B5-02-weapon-reach.md) | 무기 표 — 사거리와 공격 방식 (**규격**) | **DONE** | L | B5-01 ✅ |
| [B5-03](B5-battle-position/B5-03-advance.md) | 이동 — 대열 전진 · 전진 공격 · 전진 방어 | **DONE** | L | B5-02 ✅ |
| [B5-05](B5-battle-position/B5-05-damage-chain.md) | 피해 사슬 재편 — 회피 배율 · 종족 면역 | **DONE** | L | B5-00 ✅ |
| [B5-06](B5-battle-position/B5-06-physical-elements.md) | 물리 속성 — 베기/찌르기/타격 (**규격**) | **DONE** | L | B5-02 ✅ · B5-05 ✅ |
| [B5-07](B5-battle-position/B5-07-knockback.md) | 밀어내기 — 넉백 · 방패 밀쳐냄 · 회피 후퇴 | **DONE** | M | B5-03 ✅ · B5-06 ✅ |
| [B5-08](B5-battle-position/B5-08-presets.md) | preset — 아군·적의 상시 지시 (**규격**) | **DONE** | M | B5-03 ✅ · B5-06 ✅ |
| [B5-09](B5-battle-position/B5-09-join-mid-battle.md) | 전투 중 합류 — 슬롯 정원 (**규격**) | **DONE** | M | B5-01 ✅ |
| [B5-99](B5-battle-position/B5-99-freeze-contract-v2.md) | **모드 인계 규격 v2 확정** | **DONE** | M | B5 전체 |

**착수 순서는 B5-00 → B5-01 → B5-04 → B5-02 → B5-05 → B5-06 → B5-03 → B5-07 →
B5-09 → B5-08 → B5-99** 였다. 최소 프로토타입(01+04)이 먼저 돌아간 덕에
"앞열이 실제로 더 맞는다" 를 확인하고 나머지를 얹었다.

### B3 — RPG 연결 (**완료** 2026-09-09 · 5/5)

> **전투가 실제로 새 model 로 돈다.** cm2 동사 다섯 개가 어댑터를 거치고,
> `HDBattleRunner` 가 `UiHost` 로 굴리고, 정산이 끝나고 한 번 반영된다.
> `assets/*.cm2` 는 한 줄도 안 고쳤다.
>
> ² B3-04 의 답은 **해석할 요청이 없다**는 것이다 — 전투에서 `worldEffects` 를 채우는
> 경로가 하나도 없다. 마법 33~40 은 메뉴에 없고(B6-01), 초능력 41·42·44 도 규격 v4 가
> 뺐다(부록 Z-9 — 셋 다 아무 일도 안 하면서 턴을 먹고 있었다). 필드는 남기되 쓰이지 않는다.
>
> ¹ B3-03 은 **부분 완료**다 — 속성은 B5 가 전투 안으로 흡수해(체질·공격 방식)
> RPG 쪽에 넣을 것이 없어졌고, 소비 아이템 키 대응만 남았다.

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [B3-01](B3-battle-integrate/B3-01-cm2-adapter.md) | cm2 동사 5개 호환 adapter — **콘텐츠 53곳 무변경** | **DONE** | M | B5-99 ✅ |
| [B3-02](B3-battle-integrate/B3-02-setup-and-settle.md) | 개시 입력 조립 · 정산 결과 반영 · **`UiHost` 운전자** | **DONE** | L | B5-99 ✅ · B3-01 ✅ |
| [B3-03](B3-battle-integrate/B3-03-rpg-attributes.md) | RPG → 규격 v2 매핑 (무기 키 · 부위별 방어구 · 열) | **DONE**¹ | L | B5-99 ✅ |
| [B3-04](B3-battle-integrate/B3-04-world-effects.md) | 전투 밖 효과 요청 해석 + `worldEffects` 형식 확정 | **DONE**² | M | B5-99 ✅ · B3-02 ✅ |
| [B3-05](B3-battle-integrate/B3-05-exp-and-levelup.md) | 경험치·레벨업 정산을 RPG 로 — **레벨이 안 오르고 있었다** | **DONE** | S | B3-02 ✅ |

### B4 — Flutter view (model 무변경) — **완료** 2026-09-09 · 3/3

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [B4-01](B4-battle-view/B4-01-flutter-view.md) | Flutter 전투 view — **실험실 모드로 먼저** (`flutter run -t lib/battle_lab_main.dart`) | **DONE** | L | B3-02 ✅ |
| [B4-02](B4-battle-view/B4-02-input-wiring.md) | 게임 안으로 넣기 + 키보드·가상 입력 배선 | **DONE** | M | B4-01 ✅ |
| [B4-03](B4-battle-view/B4-03-remove-old-battle.md) | 구 전투 코드 제거 (`battle.dart` 572줄 등) | **DONE** | M | B4-02 ✅ |

### B6 — 전투 메뉴·행동 현대화 (**완료** 2026-09-06 · 7/7 · [9차 판정](DECISION-LOG.md))

> 원작 메뉴를 고집하지 않는다. 최상위 13줄 → 6줄, 마법 다섯 갈래 → 기술 목록 하나.
> 규격 v2 → v3. 구간 정의: [B6-battle-modernize/_README.md](B6-battle-modernize/_README.md)

| ID | 제목 | 상태 | 규모 | 선행 |
|---|---|---|---|---|
| [B6-01](B6-battle-modernize/B6-01-unified-skill-menu.md) | 최상위 메뉴 6줄 · 기술 목록 통합 (`castSkill`) | **DONE** | L | B5-99 ✅ · B4-01 ✅ |
| [B6-02](B6-battle-modernize/B6-02-spell-reclassification.md) | 특수 마법 재분류 — 독은 무기 도포로, 능력 저하는 염력으로 | **DONE** | M | B6-01 |
| [B6-03](B6-battle-modernize/B6-03-weapon-coating.md) | 무기에 바르기 — 독·마비·화염, 3 라운드 | **DONE** | M | B6-02 · B6-05 |
| [B6-04](B6-battle-modernize/B6-04-escape-rework.md) | 도망을 파티 행동으로 · 리더 = 의식 있는 최소 슬롯 · 간격 보너스 | **DONE** | M | B6-01 |
| [B6-05](B6-battle-modernize/B6-05-party-consumables.md) | `HDItemType.consumable(12)` · 소비품 카탈로그 · 시작 인벤토리 | **DONE** | M | G1-03 ✅ |
| [B6-06](B6-battle-modernize/B6-06-views.md) | 콘솔 · Flutter view 적용 · fixture 재기록 | **DONE** | M | B6-01~05 |
| [B6-99](B6-battle-modernize/B6-99-contract-v3.md) | 규격 v3 동결 | **DONE** | S | B6-06 |
| [B6-07](B6-battle-modernize/B6-07-menu-flow-audit.md) | 메뉴 흐름 감사 — 리더→열 순으로 묻기 · 취소는 한 단계 위로 · 한 답짜리 물음 생략 · 치료 대상 묻기 | **DONE** | M | B6-06 |

## P0 백로그 — 실재하는 버그 (선행 구간이 아니다 · 필요 시 끌어옴)

> 전부 `blueprint/_meta/GROUND_TRUTH.md` 부록 A~K 로 검증된 것이다.
> **S1 을 막지는 않는다.** 다만 아래 표시된 것은 S1 중에 물릴 가능성이 높다.
>
> **2026-09-03**: 「높음」 2건(P0-03 · P0-14)은 S1 착수 전에 해소했다. 남은 것은 전부 낮음/없음이다.

| ID | 제목 | S1 중 물릴 위험 | 근거 |
|---|---|---|---|
| ~~P0-03~~ **DONE** | cm2 로드 실패가 엔진 상태를 누수시킨다 | ~~높음~~ — 2026-09-03 해소 | 부록 A-2 |
| ~~P0-14~~ **DONE** | 범위 밖 인자가 조용히 무시된다 | ~~높음~~ — 2026-09-03 해소 | 부록 F-1 |
| [P0-07](P0-foundation/P0-07-save-drops-map-events.md) | 세이브가 `map.events` 를 유실 | **중간** — S1-04 의 세이브·로드 확인에서 물린다 | 부록 C-1 |
| [P0-08](P0-foundation/P0-08-save-skips-native-attach.md) | 세이브 로드가 네이티브 스크립트 미부착 | 낮음 — 샘플은 cm2 만 씀 | 부록 C-2 |
| ~~P0-12~~ | → **G2 로 이동** | — | 부록 B-2 |
| ~~P0-13~~ | → **G2 로 이동** | — | 부록 F-3 |
| [P0-01](P0-foundation/P0-01-mapinfos-name-resolution.md) | 등록 이름 15개 중 7개 로드 불가 | 낮음 — **새 항목(id 16)은 정상 동작.** 기존 7개만 문제 | 부록 D-1·F-4 |
| [P0-02](P0-foundation/P0-02-map-load-failure-silent.md) | 맵 로드 실패가 성공으로 보고 | 낮음 | 부록 D-2 |
| [P0-04](P0-foundation/P0-04-mapscript-flag-stub.md) | `HDMapScript` 플래그 API 가 빈 스텁 | 없음 — cm2 경로는 무관 | 부록 A-3 |
| [P0-05](P0-foundation/P0-05-native-script-without-geometry.md) | 지오메트리 없는 맵에 네이티브 부착 | 없음 | 부록 F-2 |
| [P0-06](P0-foundation/P0-06-town2-unreachable.md) | `TOWN2` 가 맵 없이 등록 | 없음 | 부록 G-2 |
| [P0-09](P0-foundation/P0-09-save-size-limit.md) | 맵 스냅샷 세이브 용량 (실측 557~664KB) | 낮음 | 부록 C-3 |
| [P0-10](P0-foundation/P0-10-wallclock-poison-damage.md) | 독 데미지가 벽시계로 결정 | 없음 | 부록 C-4 |
| [P0-11](P0-foundation/P0-11-unseeded-random.md) | 전투에 시드 없는 `Random()` 14곳 | 없음 | 부록 C-4 |
| ~~P0-15~~ | → **G2 로 이동** | — | 부록 B-1 |
| [P0-16](P0-foundation/P0-16-dart-io-and-exit.md) | `application/` 이 `dart:io` 사용 (`exit(0)` 는 `kIsWeb` 가드 있음) | 없음 | 부록 B-4 |
| [P0-17](P0-foundation/P0-17-ci-gates.md) | CI 에 `dart:io` 검사·웹 빌드 스모크 추가 | 없음 | D-23 · 부록 B-5 |
| [P0-18](P0-foundation/P0-18-bump-gate-asymmetry.md) | bump 경로만 게이트가 있어 비대칭 | 낮음 | 부록 K-2 |
| ~~P0-19~~ | → **G1 로 이동** | — | 부록 H-1 |
| [P0-00](P0-foundation/P0-00-content-volume-target.md) | 목표 콘텐츠 물량 확정 (결정 이슈) | — | DECISION-LOG |

## deferred — 보류된 노선 (26건)

[deferred/](deferred/) 의 **26개** 이슈는 **폐기가 아니라 보류**다 — P1-01~16(선언적 모델·인벤토리·저널) · GATE-01(측정 게이트) · P2-01~09(콘텐츠 서버·MCP·솔버·퍼저·8단계 하네스).
꺼내야 하는 신호는 [MILESTONES §5](MILESTONES.md) 에 적혀 있다.

## 집계

| 구간 | 이슈 | TODO | BLOCKED | DEFERRED |
|---|---|---|---|---|
| **G1 아이템·장비** | 11 | 1 | 0 | 0 |
| **G2 전투 정합** | 5 | 0 | 0 | 0 |
| S1 | 5 | 1 | 4 | 0 |
| S2 | 4 | 0 | 4 | 0 |
| S3 | 5 | 0 | 5 | 0 |
| **B1 전투 분리** | 6 | 0 | 0 | 0 |
| **B2 전투 확장** | 12 | 0 | 0 | 0 |
| **B3 RPG 연결** | 5 | **1** | 4 | 0 |
| **B4 Flutter view** | 3 | 0 | 3 | 0 |
| P0 백로그 | 20 | 18 | 0 | 0 |
| deferred | 26 | 0 | 0 | 26 |
| **합계** | **99** | **16** | **23** | **26** |
