# 구간 계획 — sample-first

> 설계 참고: [`blueprint/`](../blueprint/00_README.md) (34개 장, 유효하되 **일부는 보류 노선**)
> 판정 이력: [DECISION-LOG.md](DECISION-LOG.md) — **1차 판정은 2차에서 정정되었다. 2차를 따른다.**

---

## 0. 전제 — 퀘스트는 이미 저작 가능하다

1차 계획은 "퀘스트를 만들 수 있게 만드는 것" 부터 시작했다. **틀렸다.**
원작 방식이 이미 작동한다 — `assets/flag4ep1.cm2`(플래그 정의) + `assets/L1_ep1d0~d5_1.cm2`(**2,441줄**).

| 필요한 것 | 원작이 하는 방법 | 코드 변경 |
|---|---|---|
| 퀘스트 상태 | `Flag::Set/IsSet` → `HDGameOption.flags` 256칸, **세이브에 저장됨** | 없음 |
| 퀘스트 아이템 | **플래그로 표현** (`GFD0_GET_KEY_FOR_D1` = 열쇠 소지) | 없음 |
| 조건부 대사 | `if (Not(Flag::IsSet(X)))` — 복합 조건도 `And`/`Or`/`Not` 으로 | 없음 |
| 선택지 | `Select::Init/Add/Run` + `Select::Result()` | 없음 |
| 월드 변화 | `Map::ChangeTile(x,y,tile)` | 없음 |
| 전투 | `Battle::Init/RegisterEnemy/ShowEnemy/Start` | 없음 |
| 새 맵 | `MapInfos.json` 항목 + `Map0NN.json` (다음 빈 id = **16**) | 없음 |
| 새 등장인물 | 맵 objUpper 에 TALK 오브젝트(B 128~143) + cm2 `On(x,y)` 핸들러 | 없음 |
| JSON 폴백 억제 | `Event::Override()` — `Map002.cm2` 에 데모 존재 | 없음 |

**즉 샘플 퀘스트 = 파일 2개 + MapInfos 한 줄.**
그래서 "만들 수 있게 만드는" 구간이 필요 없고, **바로 만들고 걸림돌을 찾는다.**

## 1. 구간

```
G1 아이템·장비 이식 ─▶ G2 전투 정합 ─▶ S1 샘플 퀘스트 ─▶ S2 걸림돌 제거 ─▶ S3 AI 생성
(재미 + 부채 방지)      (퀘스트 전투 전제)   (진짜 아이템 사용)   (S1이 확인한 것만)   (정답지 = S1 산출물)
                                                                      ▲
                                                          P0 백로그에서 필요한 것만 끌어옴
```

| 구간 | 목표 | 자동화와 무관하게 필요한가 |
|---|---|---|
| **G1** | 원작 아이템·장비 시스템을 **이식**한다 (`ObjItem.cs` 877줄 기준) | **예** — 게임이 미완성이고 `"무기1"` 이 플레이어에게 보인다 |
| **G2** | 전투 결과·방어 계산을 정합시킨다 | **예** — 지금 결과 코드가 cm2 상수와 반대다 |
| **S1** | 새 맵 1개 + NPC 3명 + 퀘스트 1개를 **손으로** 완성 | 부분적 — 자동화의 정답지를 얻는 것이 주 목적 |
| **S2** | S1 이 **실제로 걸림돌이었다고 확인된 것만** 고친다 | 아니오 |
| **S3** | AI 가 S1 과 **같은 형태의 산출물**을 만든다 | 아니오 |

**왜 G1 이 S1 보다 먼저인가** — 플래그로 "열쇠 소지" 를 표현해 퀘스트를 만들면
나중에 인벤토리가 생길 때 **그 퀘스트를 전부 다시 써야 한다.** 자동화로 물량을 늘린 뒤라면 더 크다.
게다가 원작은 부위 개념(`HEAD`/`LEG`/`ORNAMENT`)을 갖는데 현재 Dart 는 3칸뿐이라 지금 만들면 두 번 어긋난다.

**마법 효과 구현은 별 트랙**이다 — 선택 UI 와 이름만 있고 효과가 레벨 기반 공식 2개로 뭉쳐 있다
(`battle.dart:155,174`). 재미에는 크지만 퀘스트 자동화의 전제가 아니라 이 순서에 넣지 않았다.

`P0-foundation/` 은 **선행 구간이 아니라 백로그**다. 각 구간이 필요할 때 끌어온다.

## 1.5 G1 — 아이템·장비 이식

**목표**: 아이템을 얻고 가방에서 보고 장비하면 전투가 달라진다. 이름이 실제 이름으로 보인다.

**이식 원본** (설계하지 말고 옮긴다)
- `REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs` (877줄) — `Item`/`ItemSub`/`ResId`
- `REF_UNITY_LoreEp1/src_as_cs/GameEventEquipment.cs` (448줄) — 장비 화면·흐름
- `REF_UNITY_LoreEp1/src_as_cs/ObjTypes.cs` — `ITEM_TYPE` 열거

**완료 판정 기준**
- [ ] 전투 로그와 상태 메뉴에 `"무기1"` 대신 **실제 이름**이 나온다 (노출 4곳)
- [ ] 아이템을 **소지·장비·해제**할 수 있고 화면에서 목록을 본다
- [ ] 장비를 바꾸면 **전투 피해량이 실제로 달라진다** (단위 테스트가 고정)
- [ ] cm2 에서 `Item::Give/Take/Has` 로 아이템을 다룰 수 있다 → **퀘스트가 진짜 아이템을 쓴다**
- [ ] 세이브·로드 후 소지품과 장비가 유지된다

**하지 않을 것**: 상점·무게·제작·강화. 선언적 콘텐츠 팩(그건 [deferred/](deferred/) 노선이다).

## 1.6 G2 — 전투 정합

**목표**: 전투 결과가 cm2 와 같은 의미를 갖고 방어구가 실제로 작동한다.

**완료 판정 기준**
- [ ] `Battle::Result()` 의 값이 `const.cm2` 상수와 **같은 의미**다
- [ ] 전투를 하지 않고 `Battle::Result()` 를 읽으면 **승리가 아니다**
- [ ] 방어 계산이 **장비에서 온 `ac`** 를 읽는다
- [ ] `Battle::RegisterEnemy` 의 유효 범위(1~74)가 문서·검사에 반영된다
- [ ] 미등록 cm2 심볼 6종이 **등록되거나 스크립트에서 제거**된다

**하지 않을 것**: 마법 45종 효과 구현(별 트랙), 밸런스 재설계.

## 2. S1 — 샘플 퀘스트

**목표**: 플레이어가 새 마을에 들어가 의뢰를 받고, 물건을 구해 오고, 보상을 받는다. 세이브·로드해도 진행이 남는다.

**G1 이후이므로 "물건" 은 플래그가 아니라 실제 아이템이다.** 이것이 순서를 바꾼 이유다(3차 판정).

**산출물** (전부 데이터, 코드 0줄)
- `hadar2026_app/assets/maps/Map016.json` — 새 맵
- `hadar2026_app/assets/Map016.cm2` — 퀘스트 로직
- `hadar2026_app/assets/maps/MapInfos.json` — 항목 1줄 추가
- `hadar2026_app/assets/flag4quest1.cm2` — 플래그 정의 (`flag4ep1.cm2` 형식)
- 기존 맵에서 새 맵으로 가는 `LoadScript` 연결 1곳

**완료 판정 기준**
- [ ] 새 맵을 **이름으로** 진입할 수 있다
- [ ] NPC 3명이 각각 말한다. 그중 최소 1명은 **퀘스트 상태에 따라 다른 말**을 한다
- [ ] 의뢰 수락 → 물건 획득 → 전달 → 보상의 **전 과정이 플레이로 완주**된다
- [ ] 각 단계가 플래그로 기록되고, **중간에 세이브·로드해도 진행이 유지**된다
- [ ] 완료 후 다시 말을 걸면 **완료 상태의 대사**가 나온다
- [ ] **저작 중 막힌 지점을 전부 기록**했다 → [S1-99](S1-sample-quest/S1-99-friction-log.md)

**하지 않을 것**: 코드 변경, 인벤토리, 저널 UI, 선언적 스키마, 검증기, AI. 전부 뒤 구간이다.

## 3. S2 — 실측된 걸림돌 제거

**S1 의 마찰 기록이 이 구간의 입력이다.** 지금 예상되는 것(확정 아님):

| 예상 걸림돌 | 왜 | 후보 이슈 |
|---|---|---|
| 플래그 인덱스 수동 할당 | 256칸을 손으로 배분. AI 가 생성하면 **충돌이 조용히 상태를 망친다**. `lore_ep1.cm2` 는 `Flag::IsSet(51)` 처럼 **생 숫자**도 쓴다 | [S2-01](S2-enablers/S2-01-flag-registry.md) |
| 한 맵에 퀘스트 여러 개 | cm2 는 맵당 1개. `include` 는 **init 전용**이라 per-tile 핸들러를 못 담는다 | [S2-02](S2-enablers/S2-02-cm2-override-chain.md) |
| cm2 침묵 실패 | 미등록 함수 → **0 반환** → 조용한 오분기. AI 오타에 치명적 | [S2-03](S2-enablers/S2-03-cm2-linter.md) |
| 좌표 ↔ NPC 배치 | `On(x,y)` 가 좌표 하드코딩. 맵을 고치면 깨진다 | [S2-04](S2-enablers/S2-04-map-editor-cm2-support.md) |

**원칙**: S1 이 실제로 겪지 않은 문제는 **이 표에서 지운다.** 짐작으로 만들지 않는다.

## 4. S3 — AI 생성

**생성 타깃은 S1 이 만든 것과 같은 형태의 파일들**이다. 선언적 콘텐츠 팩이 아니다.

few-shot 정답지: S1 산출물 + `flag4ep1.cm2` + `L1_ep1d0.cm2` + `Map002.cm2`.

| 이슈 | 내용 |
|---|---|
| [S3-01](S3-generation/S3-01-quest-spec-format.md) | 사람이 쓰는 **퀘스트 개요 서식** (AI 입력) |
| [S3-02](S3-generation/S3-02-generation-prompt.md) | 생성 프롬프트 — 개요 → cm2 + 맵 + 플래그 |
| [S3-03](S3-generation/S3-03-map-generation.md) | 맵·NPC 배치 생성 (기존 맵 에디터 API 활용) |
| [S3-04](S3-generation/S3-04-minimal-validation.md) | **최소** 검증 — 심볼·플래그 충돌·좌표 존재. 솔버 아님 |
| [S3-05](S3-generation/S3-05-pilot-batch.md) | 파일럿: 퀘스트 3개 배치 생성 후 사람이 플레이 검수 |

**완료 판정 기준**
- [ ] 퀘스트 개요 1장을 넣으면 **플레이 가능한 퀘스트**가 나온다
- [ ] 생성물이 기존 콘텐츠를 **깨뜨리지 않는다** (플래그 충돌 0, 기존 맵 미변경)
- [ ] 사람이 **읽고 고칠 수 있는** cm2 다 (원작 문체·구조를 따름)

## 5. 보류된 노선

[deferred/](deferred/) — 선언적 콘텐츠 팩(WorldState·인벤토리·저널·퀘스트 모델) **+ 무거운 생성 파이프라인**(콘텐츠 서버·MCP·솔버·퍼저·8단계 하네스). 총 26건.
**폐기가 아니라 보류**다. cm2 노선이 실제로 막히는 지점이 오면 꺼내 쓴다.
설계는 [`blueprint/`](../blueprint/00_README.md) 에 완결되어 있다.

**꺼내야 하는 신호**:
- 플래그 256칸이 부족해진다
- cm2 에서 표현 불가능한 퀘스트 구조가 반복해서 나온다
- 생성물의 오류를 사람이 감당 못 하는 물량이 된다

## 6. 진행 현황

| 구간 | 이슈 | 상태 |
|---|---|---|
| S1 | 4 | 착수 가능 |
| S2 | 4 | S1 걸림돌 기록 대기 |
| S3 | 5 | S2 이후 |
| **B1 전투 분리** | 6 | **완료** 2026-09-04 (§7.3) |
| **B2 전투 확장** | 12 | **완료** 2026-09-05 · 규격 v1 확정 |
| B3 RPG 연결 | 5 | **착수 가능** (규격 v1) |
| B4 Flutter view | 3 | B3 이후 |
| P0 백로그 | 20 | 필요 시 끌어옴 |
| deferred | 26 | 보류 |

정본은 [BOARD.md](BOARD.md).

---

## 7. B 트랙 — 전투 분리·확장·재통합

> 판정: [DECISION-LOG 4차](DECISION-LOG.md) (2026-09-04). **S 트랙(S1→S2→S3)과 별개 트랙**이고
> 3차 판정의 노선을 뒤집지 않는다. **S1 과 B1 의 선후는 아직 정하지 않았다.**

**목표**: 전투를 RPG 에서 완전히 떼어 별도 실행으로 만들고, 제약 없이 확장한 뒤 되붙인다.

G2(전투 정합)는 결함 5건을 고쳤고 전투를 다시 만들지 않았다. 남은 것은 결함이 아니라
**미완성**이다 — 마법 45종이 공식 2개로 뭉쳐 있고, 치료가 회복시키지 않고, 상태이상 자리가
정수 3개뿐이고, 민첩이 행동 순서에 안 쓰이고, 전투 중 아이템 사용이 없다(실측은 4차 판정에).

```
B1 전투 분리 ─▶ B2 전투 확장 ─▶ B3 RPG 연결 ─▶ B4 Flutter view
(규칙 무변경)    (제약 없이)      (되붙임)         (model 무변경)
```

### 7.1 산출물 — 독립 실행되는 디렉토리 2개

| 새로 생기는 것 | 성격 | 실행 | 선례 |
|---|---|---|---|
| `packages/hd_battle/` | model. 라이브러리 | `dart test` | `packages/cm2_script/` |
| `hd_battle_console/` | view + control. 실행체 | `dart run bin/battle.dart <fixture>` | `cm2_script_sample/` |

**`flutter run` 이 아니라 `dart run` 이다.** Flutter SDK 없이 돌고, "Flutter 의존 0" 이
선택이 아니라 구조가 된다. 둘로 나누는 이유는 `hd_battle` 이 공개 API 만 export 하면
콘솔 쪽이 `lib/src/` 에 손을 못 대기 때문이다.

### 7.2 모드 인계 — 전투 mode 에 넣는 것과 받는 것

| 방향 | 이름 | 담는 것 |
|---|---|---|
| RPG → 전투 | **전투 개시 입력** (`BattleSetup`) | 파티 스냅샷(이름·능력치·level·hp/sp/esp·장착 상태) + 적 키 목록 + 난수 시드 |
| view ↔ model | `BattleCommand` / `BattleEvent` | 명령과, 구조화된 사실. **문자열·조사는 model 에 없다** |
| 전투 → RPG | **전투 정산 결과** (`BattleOutcome`) | 파티 슬롯 인덱스(`order` 0~5)별 hp/sp/esp·상태이상 최종값 + 경험치 + 골드 + 소비 아이템 + 전투 밖 효과 요청 + 종료 코드 |

**규격은 B2 동안 자유롭게 깨고, B2 종료 시점에 확정한다** ([B2-99](B2-battle-expand/B2-99-freeze-contract.md)).
B3 는 확정된 규격 위에서만 시작하므로 항목마다 규격을 닫아 나가는 것은 낭비다.

**fixture** — 파일 하나에 전투 개시 입력 + 명령 열 + 난수 시드를 담은 JSON.
셋이 고정되면 결과가 결정적이라 **콘솔 시연용이 그대로 회귀 테스트 입력**이 된다.

### 7.3 B1 — 전투 분리 (**완료** 2026-09-04)

**규칙을 바꾸지 않는다.** 계산식을 같이 바꾸면 "규칙이 달라진 것" 과 "옮기다 깨진 것" 을
구분할 수 없게 된다. 규칙 변경은 전부 B2 다.

| ID | 제목 |
|---|---|
| [B1-01](B1-battle-extract/B1-01-package-skeleton.md) | 패키지 골격과 모드 인계 규격 초안 |
| [B1-02](B1-battle-extract/B1-02-enemy-table.md) | 적 테이블을 문자열 키로 이식 (일회성 seed 변환) |
| [B1-03](B1-battle-extract/B1-03-formula-port.md) | **전투식 19개**를 시드 주입 순수 함수로 이식 |
| [B1-04](B1-battle-extract/B1-04-invert-call-direction.md) | 호출 방향 뒤집기 (model 이 view 를 부르지 않게) |
| [B1-05](B1-battle-extract/B1-05-console-view.md) | 콘솔 view 와 fixture 러너 |
| [B1-06](B1-battle-extract/B1-06-ci-guard.md) | CI 가 Flutter 의존 0 을 강제 |

**완료 판정 기준** — 전부 충족 (2026-09-04)
- [x] 전투식 19개가 각각 단위 테스트로 고정된다 (시드 주입, **수식을 테스트에 복사하지 않는다**)
- [x] 같은 fixture + 같은 명령 열 + 같은 시드 → 같은 전투 정산 결과
- [x] `packages/hd_battle` 의 Flutter 의존 0 (`foundation.dart` 포함)
- [x] 콘솔에서 전투 한 판이 끝까지 돌아간다

`hadar2026_app/test/application/defense_scale_test.dart:14-18` 이 *"the real formula cannot be
driven from a test"* 라고 적고 수식을 복사해 검증하는 이유가 무시드 `Random()` 14곳이다.
새 패키지는 시드를 받으니 **원본을 직접 구동**한다 — 그 취약점이 B1 에서 같이 해소된다.

**하지 않을 것**: 전투식 수정 · 밸런스 · RPG 쪽 변경 · `application/battle.dart` 삭제(B4-03).

### 7.4 B2 — 전투 확장 (**완료** 2026-09-05 · 12/12)

**확장 항목 9개 전부**가 이 구간에 있다. 관문으로 쪼개지 않는다 — 최소 상태로 조기 통합하면
전투를 뗀 이유(제약을 끊는 것)가 무효가 된다.

**목록 자체가 잠정이다.** 개념이 없어지거나 바뀌면 이슈를 `DROPPED` 로 닫고 새로 만든다.

**[5차 판정](DECISION-LOG.md) 정정 — 절반은 이식이다.** C++ 원작에 완성 구현이 있다:
`hd_class_pc_player.cpp`(2,242줄, 마법·치료 8종·상태 표현) ·
`hd_class_pc_enemy.cpp`(1,079줄, 적 AI 6종, **적이 서로 치료한다**). 소재는
[`GROUND_TRUTH` 부록 P](../blueprint/_meta/GROUND_TRUTH.md).
**⚠ Unity 포트 `OldStyleBattle.cs`(3,248줄)는 쓰지 말 것** — 마법 번호가 1~20 이고
적 테이블 인덱스가 +1 밀려 있어 cm2 와 어긋난다(부록 P-3).

순서는 **이식 5개(B2-04 → B2-03 → B2-02 → B2-01 → B2-07) → 판단 4개(B2-05 → B2-06 →
B2-08 → B2-09)** 다. 원작 전투가 실제로 어떻게 굴렀는지 보고 나서 새 것을 얹는다.

| ID | 항목 | 규격 영향 |
|---|---|---|
| [B2-01](B2-battle-expand/B2-01-magic-effects.md) | 마법 개별 효과 (**이식**) | **있음** |
| [B2-02](B2-battle-expand/B2-02-heal-applies.md) | 치료 실제 적용 (**이식**) | 있음 |
| [B2-03](B2-battle-expand/B2-03-status-effects.md) | 상태이상 모델 (**이식** + 판단) | **있음** |
| [B2-04](B2-battle-expand/B2-04-unconscious-stage.md) | 의식불명 단계 (**이식**) | 있음 |
| [B2-05](B2-battle-expand/B2-05-turn-order.md) | 행동 순서 | 없음 |
| [B2-06](B2-battle-expand/B2-06-battle-items.md) | 전투 중 아이템 | **있음** |
| [B2-07](B2-battle-expand/B2-07-enemy-behavior.md) | 적 행동 선택 (**이식**) | 없음 |
| [B2-08](B2-battle-expand/B2-08-slot-mitigation.md) | 부위별 감쇠 | 없음 |
| [B2-09](B2-battle-expand/B2-09-elemental-affinity.md) | 속성 상성 | 없음 — 단 **B3 작업량을 늘린다** |
| [B2-99](B2-battle-expand/B2-99-freeze-contract.md) | 규격 확정 (구간 종료) | — |

"규격 영향 없음" 인 항목은 전투 내부에서 끝난다 — RPG 는 최종 수치만 받으므로 계산 방식을
알 필요가 없고, 나중에 늘어나도 B3 를 다시 하지 않는다.

**완료 판정 기준** — 전부 충족 (2026-09-05, [7차 판정](DECISION-LOG.md))
- [x] Flutter 의존 0 · 시드 없는 난수 0 · 코드에 한국어 0 · 경험치 표 0
- [x] 같은 fixture + 같은 명령 열 + 같은 시드 → 같은 정산 결과 (fixture 17개)
- [x] 확장 항목마다 fixture 1개
- [x] 새 피해 대역 실측표 → `GROUND_TRUTH` **부록 U**, H-2 는 구 전투식 기준으로 표시
- [x] `packages/hd_battle/CONTRACT.md` **v1**
- [x] "붙인다" 판단 → [7차 판정](DECISION-LOG.md)

**목록이 두 번 늘었다** — B2-10(초능력)·B2-11(초자연 시전)은 착수 중에 발견해 뗀 것이다.
둘 다 파티 구성을 바꿔서 규격에 영향이 있었고, 규격을 구간 끝에 확정한 판단(4차)이 그것을 흡수했다.

**하지 않을 것**: RPG 쪽 연결(B3) · Flutter view(B4) · cm2 어댑터(B3-01).
`hadar2026_app` 은 이 구간에서 **한 줄도 고치지 않는다.**

### 7.5 B5 — 위치 전투 (**완료** 2026-09-05 · 11/11 · [8차 판정](DECISION-LOG.md))

전투를 굴려 보니 **1990년식**이었다. 무엇이 문제인지 코드로 확인하고 위치를 넣기로 했다.

```
각자의 rank (자기 진영 안에서 1~3)  +  양측 공통의 gap (0~2)
거리 = gap + (내 rank - 1) + (상대 rank - 1)
```

근간은 **드래곤 퀘스트**다 — 라운드 시작에 전원 명령 → 일괄 해결, 자유 이동 없음.
좌표가 아니므로 격자 게임이 되지 않는다. 자세한 것은 [B5 _README](B5-battle-position/_README.md).

**불변식 하나** — 사거리 밖은 **벌점이지 무효가 아니다.** 헛턴이 나오는 경로가 없어야 한다.

**⚠ 전제가 하나 틀려 있었다** — 파티는 **5인 + 소환수**가 기본인데
fixture 17개 중 14개가 2인이었다([부록 W](../blueprint/_meta/GROUND_TRUTH.md)).
5인이면 라운드가 절반(9→4)이고, **적의 특수 능력이 처음으로 발동한다**(0회→10회).
그래서 B5-00 이 첫 이슈다.

| ID | 제목 |
|---|---|
| [B5-00](B5-battle-position/B5-00-five-member-fixtures.md) | fixture 를 5인 기준으로 재작성 |
| [B5-01](B5-battle-position/B5-01-rank-and-gap.md) | `rank` 와 `gap` — 위치의 뼈대 |
| [B5-02](B5-battle-position/B5-02-weapon-reach.md) | 무기 표 — 사거리와 공격 방식 |
| [B5-03](B5-battle-position/B5-03-advance.md) | 이동 — 대열 전진 · 전진 공격 · 전진 방어 |
| [B5-04](B5-battle-position/B5-04-rank-weighted-targeting.md) | 적의 대상 선택을 열 가중으로 |
| [B5-05](B5-battle-position/B5-05-damage-chain.md) | 피해 사슬 재편 — 회피 배율 · 종족 면역 |
| [B5-06](B5-battle-position/B5-06-physical-elements.md) | 물리 속성 — 베기 / 찌르기 / 타격 |
| [B5-07](B5-battle-position/B5-07-knockback.md) | 밀어내기 — 넉백 · 방패 밀쳐냄 · 회피 후퇴 |
| [B5-08](B5-battle-position/B5-08-presets.md) | preset — 아군·적의 상시 지시 |
| [B5-09](B5-battle-position/B5-09-join-mid-battle.md) | 전투 중 합류 — 슬롯 정원 |
| [B5-99](B5-battle-position/B5-99-freeze-contract-v2.md) | 규격 **v2** 확정 (구간 종료) |

**왜 B3 보다 먼저인가**
1. **규격이 크게 바뀐다**(v1 → v2). 붙인 뒤에 하면 양쪽을 고쳐야 하고 지금 하면 한쪽이다
2. B1·B2 가 만든 것이 정확히 이걸 위한 물건이다 — 헤드리스 · 시드 고정 · `dart run`
3. 7차 판정이 미룬 밸런스 재설계가 B5-05 에서 같이 풀린다

**결과** — 앞열이 뒷열의 3배를 맞고([부록 X-3](../blueprint/_meta/GROUND_TRUTH.md)),
타격으로 졸개를 밀어내면 뒤의 보스가 드러나고, 긴 무기와 짧은 무기가 서로 다른 간격을
원한다. 규격은 `packages/hd_battle/CONTRACT.md` **v2**.
테스트 351개(model) + 94개(콘솔), fixture 20개.

### 7.6 B3 — RPG 연결 (**3/5** 2026-09-05 — 규격 v2 위에서)

**전투가 실제로 새 model 로 돈다.** cm2 동사 다섯 개가 어댑터를 거치고,
`HDBattleRunner` 가 `UiHost` 로 굴리고, 정산이 끝나고 한 번 반영된다.
`assets/*.cm2` 는 한 줄도 안 고쳤다. 남은 것은 B3-04·B3-05.

그 과정에서 **`packages/hd_battle_text` 가 생겼다** — 이벤트의 한국어 문장이다.
`hd_battle` 은 코드에 한국어 0 이 불변조건이고, 콘솔과 Flutter view 가 같은 문장을
써야 하는데 한쪽에 두면 다른 쪽이 900줄을 베낀다.

| ID | 제목 |
|---|---|
| [B3-01](B3-battle-integrate/B3-01-cm2-adapter.md) | cm2 동사 5개를 호환 adapter 로 흡수 (**콘텐츠 53곳 무변경**) |
| [B3-02](B3-battle-integrate/B3-02-setup-and-settle.md) | 개시 입력 조립 · 정산 결과 반영 |
| [B3-03](B3-battle-integrate/B3-03-rpg-attributes.md) | RPG 아이템·적 정의에 속성 추가 (B2-09 의 결과) |
| [B3-04](B3-battle-integrate/B3-04-world-effects.md) | 전투 밖 효과 요청 해석 (마법 13종) |
| [B3-05](B3-battle-integrate/B3-05-exp-and-levelup.md) | 경험치·레벨업 정산을 RPG 로 |

**cm2 는 구현이 아니라 이미 저작된 콘텐츠다** — `Battle::` 호출 **53곳·파일 5개**
(`L1_ep1d0` · `lore_ep1` · `town1` · `town2` · `Map002`). 고치지 않고 어댑터로 흡수한다.
와이어 값 `evade 0 / win 1 / lose 2 / 미결 -1` 은 `assets/const.cm2:53-55` 가 정본이고
`domain/battle/battle_result.dart` 가 이미 고정하고 있다(부록 B-2·F-3). 되돌리지 않는다.

**완료 판정 기준**
- [ ] `assets/*.cm2` 를 한 줄도 고치지 않고 새 전투가 구동된다
- [ ] 전투 후 파티 상태·경험치·골드·소비 아이템이 정확히 한 번 반영된다
- [ ] 전투 model 이 `HDParty` 를 직접 참조하는 곳이 0곳이다
- [ ] `Battle::Result()` 4개 값의 의미가 `const.cm2` 와 같다 (기존 테스트가 계속 통과)

### 7.7 B4 — Flutter view

| ID | 제목 |
|---|---|
| [B4-01](B4-battle-view/B4-01-flutter-view.md) | Flutter 전투 view 신규 작성 |
| [B4-02](B4-battle-view/B4-02-input-wiring.md) | 전투 입력 배선 |
| [B4-03](B4-battle-view/B4-03-remove-old-battle.md) | 구 전투 코드 제거 |

**완료 판정 기준**
- [ ] `packages/hd_battle` 이 한 줄도 바뀌지 않는다 (B4 전체 diff 에 그 경로가 없다)
- [ ] 콘솔 view 가 표현하는 것을 Flutter view 도 전부 표현한다
- [ ] `grep -rn "HDBattle()" hadar2026_app/lib` 가 빈 결과다
- [ ] `flutter analyze` · `flutter test` · `flutter build web` 이 통과한다


### 7.8 B6 — 전투 메뉴·행동 현대화 (**완료** 2026-09-06 · 7/7 · [9차 판정](DECISION-LOG.md))

원작의 전투 메뉴를 더 이상 고집하지 않는다. 규칙(B1·B2·B5)은 그대로, **무엇을 언제
물어보는지**를 다시 짰다. 규격 **v2 → v3**. 자세한 것은 [B6 _README](B6-battle-modernize/_README.md).

| 무엇 | 전 | 후 |
|---|---|---|
| 최상위 메뉴 | 13줄 (마법 5갈래) | **6줄** — ⚔ 공격 · ✨ 기술 · 🎒 물건 · 🛡 버팀 · 🏃 도망 · ⚙ 지시 |
| 기술 | 번호대별 5 목록 | **한 목록**, 글자가 범위를 말한다 (🎯💥☠💚💞🌀🔮). 못 쓰는 것도 보인다 |
| 마법 13 독 · 16 능력 저하 | 특수 마법 | **무기 도포** · **초능력** |
| 무기 도포 | 없음 | 독·마비·화염, 3 라운드. 마법 13 과 병 셋, 두 길이 한 곳으로 |
| 도망 | 슬롯 1~ 각자, 하나만 성공해도 전원 도주 | **리더의 파티 행동**, 간격 +15/칸. 실패하면 전원이 라운드를 잃는다 |
| 리더 | 슬롯 0 고정 | 의식 있는 최소 슬롯 |
| 소비 아이템 | 전투에만 | `HDItemType.consumable(12)` · 카탈로그 10종 · 새 게임 가방 9개 |

| ID | 제목 |
|---|---|
| [B6-01](B6-battle-modernize/B6-01-unified-skill-menu.md) | 최상위 메뉴 6줄 · 기술 목록 통합 |
| [B6-02](B6-battle-modernize/B6-02-spell-reclassification.md) | 특수 마법 재분류 |
| [B6-03](B6-battle-modernize/B6-03-weapon-coating.md) | 무기에 바르기 |
| [B6-04](B6-battle-modernize/B6-04-escape-rework.md) | 도망을 파티 행동으로 |
| [B6-05](B6-battle-modernize/B6-05-party-consumables.md) | 소비 아이템과 시작 인벤토리 |
| [B6-06](B6-battle-modernize/B6-06-views.md) | 콘솔 · Flutter view 적용 |
| [B6-99](B6-battle-modernize/B6-99-contract-v3.md) | 규격 v3 동결 |
