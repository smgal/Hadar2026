# 이슈 보드

> 상태 규약은 [README.md](README.md), 구간 정의는 [MILESTONES.md](MILESTONES.md), 판정 이력은 [DECISION-LOG.md](DECISION-LOG.md).
> **노선: sample-first + cm2.** 선언적 콘텐츠 팩 노선은 [deferred/](deferred/) 로 보류되었다.

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
| P0 백로그 | 20 | 18 | 0 | 0 |
| deferred | 26 | 0 | 0 | 26 |
| **합계** | **73** | **15** | **15** | **26** |
