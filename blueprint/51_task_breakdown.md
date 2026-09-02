# 태스크 분해 (T-nnn) · 의존성 · 규모

> `상태: 대체됨` — **현재 노선과 모순된다. 이 장의 순서·판정을 따르면 잘못된 일을 하게 된다.**
> 정본은 [`issues/MILESTONES.md`](../issues/MILESTONES.md) 와 [`issues/DECISION-LOG.md`](../issues/DECISION-LOG.md) 의 2차 판정.
> 내용은 "왜 그 길이 아닌가" 의 기록으로 보존한다.

> **문서 ID**: BP-51 · **상태**: 초안 · **선행 문서**: [BP-50](50_roadmap.md) · [BP-27](27_runtime_engine.md) · [BP-28](28_migration_and_coexistence.md) · [BP-32](32_generation_harness.md) · [BP-33](33_validation_and_lint.md) · [BP-34](34_headless_sim_and_solver.md) · [BP-35](35_ci_and_build.md)
> **독자**: 구현 착수자 · 작업 배정자 · **한 줄 요약**: 22개 장이 흘려 놓은 태스크와 검수 보고서 12건이 남긴
> 미해결 결함을, **부록 A~K 34행 전수 대응표**를 포함해 **167개의 실행 가능한 태스크**로 통합하고
> **임계 경로를 선행 열에서 기계로 산출**한 문서. 2차 개정에서 **D-26(솔버 2축·발행 지점 레지스트리)·D-27(앵커는
> 타일 비트에 의존하지 않는다)·부록 H(장비가 전투에 반영되지 않는다)** 를 태스크로 착지시키고,
> [BP-52](52_risks.md) 의 리스크 41건 전량에 완화 태스크를 배정했다(§7.2).

**파이프라인 구획(D-01)**: 이 장은 구획을 가리지 않는 **실행 문서**다. 각 태스크는 자기가 속한 구획을
"근거" 열의 소유 장으로 표시한다. 설계 내용을 재서술하지 않는다(**D-18**) — 태스크는 소유 장을 **가리킬 뿐**이다.

**이 장이 다루지 않는 것**

| 주제 | 소관 |
|---|---|
| 마일스톤 정의·완료 판정·가드레일·롤백 | [BP-50](50_roadmap.md) |
| 리스크 등록부 | [BP-52](52_risks.md) |
| 수용 기준 수치 정본 | [BP-53](53_acceptance_criteria.md) |
| 스키마·시그니처·알고리즘 | BP-21 ~ BP-43 (D-18 소유표) |
| 사람-시간 추정 | **하지 않는다**([BP-50 §2.9](50_roadmap.md)) |

---

## 1. 태스크 표기 규약

### 1.1 번호 체계

| 항목 | 규약 |
|---|---|
| **형식** | `T-<3자리>` — 전 기획서 통합 일련번호. 장별 번호(`T-28-1`, `T-34-7`, `T-35-5`)는 **원출처 표기로만** 남기고, 실행은 통합 번호로 한다 |
| **불변성** | 부여된 번호는 **재사용하지 않는다.** 취소된 태스크는 표에 `취소` 로 남긴다(D-04 의 ID 불변 원칙을 문서 ID 에도 적용) |
| **구간 배정** | A 기반복구 `T-001~034` · B 콘텐츠코어 `T-035~058` · C 런타임통합 `T-059~070` · D 검증 `T-071~084` · E 시뮬레이터 `T-085~098` · F 게임시스템 `T-099~114` · G 저작도구 `T-115~126` · H 생성파이프라인 `T-127~138` · I CI/빌드 `T-139~148` · J 규모·운영 `T-149~156` · **K 2차 개정 신설분 `T-157~167`**(§3.11) |
| **원출처 대응** | `T-28-*`, `T-34-*`, `T-35-*`, `DT-*`, `T-22-1` 은 §7 의 원출처 대응표로 추적 |

> **주의** — [BP-25 §10](25_world_state_and_save.md) 과 [BP-27 §10](27_runtime_engine.md) 의 `T-25-01~27`·`T-27-01~31` 은
> **태스크가 아니라 테스트 케이스 ID** 다. 본 장은 그것들을 각각 하나의 "테스트 구현 태스크" 로 묶어 참조한다(T-058·T-070).

### 1.2 각 태스크의 8항목

| 열 | 뜻 |
|---|---|
| **ID** | `T-nnn` |
| **제목** | 무엇을 하는가. 동사로 끝낸다 |
| **M** | 소속 마일스톤([BP-50 §2](50_roadmap.md)) |
| **선행** | 이 태스크 착수 전에 끝나야 하는 태스크. `—` 은 즉시 착수 가능 |
| **대상 파일** | **실제 존재하는 경로.** 신규는 `(신규)` 표기. **축약 표기 규약**: `<contentRoot>/…` 는 **T-035(Q-20-1)가 확정하는 루트**를 뜻한다 — `packages/hadar_content/lib/src/`(물리 분리) 또는 `hadar2026_app/lib/domain/content/`(D-11 그대로) 중 하나다. §3 의 `.../content/…` 표기는 전부 이 치환 변수로 읽는다. 첫 경로에만 `hadar2026_app/` 접두를 쓰고 둘째부터 생략한 셀은 **같은 접두를 이어받는다** |
| **완료 조건** | 테스트·게이트·grep 등 **기계 판정 가능한 조건** |
| **규모** | S(단일 파일·수십 줄) / M(여러 파일·수백 줄) / L(설계 판단 포함·수백~천 줄) |
| **근거** | 부록 ID · BP 문서 절 · 결정 ID. **관련 리스크 `RK-nn` 을 함께 병기**한다([BP-52](52_risks.md) 와의 양방향 연결. 전량 대응은 §7.2) |

### 1.3 규모 정의

| 규모 | 기준 | 예 |
|---|---|---|
| **S** | 파일 1~2개, 기존 구조 안에서의 수정, 새 개념 없음 | `clearRuntimeState()` 호출 추가 |
| **M** | 파일 3개 이상 또는 신규 클래스 1개, 인터페이스 변경 포함 | `PartyMovementController` 신설 |
| **L** | 설계 판단이 남아 있거나 다수 파일에 걸친 신규 서브시스템 | 린트 규칙 152개, 솔버 |

---

## 2. 부록 A~K 전수 대응표

> **개수에 관한 정정 (2차)** — 부록 **G-1** 이 확정한 "검증된 결함" 집계는
> `A-1~A-4`(4) + `B-1~B-4`(4) + `C-1~C-4`(4) + `D-1~D-2`(2) + `E-1~E-3`(3) + `F-1~F-4`(4) = **21건**이다
> (`F-0` 은 버그가 아니라 §9 재확인이므로 제외). 이 중 **19건이 코드·데이터 결함**,
> **2건(E-1·E-3)이 기획서 서술 정정**이다. 통칭 "잠복 버그 20건" 은 E-2(레거시 변환 규칙)를
> 코드 결함으로 셀지에 따라 갈리는 수치다.
>
> **그러나 초판의 "21건 전부 배정 · 누락 0건" 은 G-1 의 범위 안에서만 참이었다.**
> 부록에는 G-1 이 세지 않은 배치 대상이 **10건** 더 있다 —
> `B-5`(웹 페이로드 실측) · `G-2`(TOWN2 도달 불가) · `H-1~H-4`(장비·전투 실측) ·
> `I-1`(region 충돌 실측) · `J-1~J-3`(region 레이어 사망) · `K-1~K-3`(진입점 게이트 비대칭).
> 여기에 **부록 K**(타일 이벤트 진입점 3개의 게이트 비대칭, 2026-08-30 추가)의 3건이 더해진다.
> 아래 표는 **A-1~K-3 전수 34행**이며, 그중 **완전 누락이었던 3건(B-5·H-1·H-2)과 부분 누락 3건(G-2·H-3·H-4)**
> 에 대한 태스크를 이번 개정에서 신설했다(T-157~T-167 중 해당분).
> 마일스톤 배치의 정본은 [BP-50 §4.2](50_roadmap.md) 이며 본 표는 그것을 태스크로 받는다.

| 부록 | 결함 요약 | 대응 태스크 | M | 검증 태스크 |
|---|---|---|---|---|
| **A-1** | 모든 등록 맵에 존재하지 않는 cm2 경로가 무조건 부여 | **T-005** | M0 | T-009 |
| **A-2** | cm2 로드 실패가 엔진 상태를 누수 | **T-010** | M0 | T-013 |
| **A-3** | `HDMapScript` 플래그 API 가 미구현 스텁 | **T-033**(진단 고정) → **T-111**(해소) | M0 → M3 | T-033 · T-111 |
| **A-4** | `flutter.assets` 선언이 비재귀 | **T-069** | M1 | T-069 |
| **B-1** | 적 `id 0` 이 영구 소환 불가 (실사용 74종) | **T-028** | M0 | T-028 |
| **B-2** | 전투 결과 코드가 cm2 상수와 정반대 | **T-025**(정본 확정) → **T-026** | M0 | T-026 |
| **B-3** | 이동·상호작용이 Bonfire 스프라이트 폴링 안에 있음 | **T-086** · T-087 · T-088 · T-089 · T-090 | M2 | T-085(추출 **전** 작성) |
| **B-4** | `application/` 이 `dart:io` 를 쓰고 `exit(0)` 호출 | **T-022** · **T-023** · T-024 | M0 | T-139 · T-140 · T-145 |
| **C-1** | 세이브가 `map.events` 를 저장하지 않음 | **T-014** | M0 | T-016 |
| **C-2** | 세이브 로드가 네이티브 맵 스크립트를 안 붙임 | **T-015** | M0 | T-016 |
| **C-3** | 맵 스냅샷이 웹 저장 한계에 근접(~570KB) | **T-064** · **T-065** | M1 | T-064 |
| **C-4** | 벽시계 데미지 1곳 + 무시드 `Random()` 14곳 | **T-017** · **T-018** · **T-019** · **T-020** | M0 | T-021 · T-141 · T-142 |
| **D-1** | 등록 이름 15개 중 7개가 없는 파일로 해석 | **T-004** · **T-005** | M0 | **T-009** |
| **D-2** | 로드 실패가 실패로 보고되지 않음 | **T-006** · **T-007** | M0 | T-009 |
| **E-1** | `code 101` 을 "텍스트 헤더" 로 오인한 서술 | **T-031** | M0 | T-031 |
| **E-2** | MV `pages` 선택 규칙이 `entry` 와 정반대 | **T-113**(레거시 변환기) · T-149 · T-150 | M3 | T-113 |
| **E-3** | "cm2 는 튜링 완전" 논거 오류 | **T-032** | M0 | T-032 |
| **F-1** | 등록 커맨드의 범위 밖 인자가 조용히 무시됨 | **T-029** | M0 | T-029 |
| **F-2** | 네이티브 스크립트가 지오메트리 없는 맵에 부착 | **T-012** | M0 | T-013 |
| **F-3** | `Battle::Result()` 가 전투 없이 승리를 반환 | **T-027** | M0 | T-027 |
| **F-4** | `ORIGIN.json` 만 정상 로드 — D-1 의 역설 확증 | **T-009**(회귀 테스트로 편입) | M0 | T-009 |
| **F-0** | cm2 등록 심볼은 커맨드 40 / 함수 12(43/11 은 오류) — **버그가 아니라 재확인** | **T-030** | M0 | T-030 (골든 diff 0) |
| **G-1** | 부록의 검증 사실은 20건이 아니라 **21건** | 본 §2 서문(집계 규칙) | — | 이 표의 행 수가 검증 수단 |
| **B-5** | 웹 페이로드 **45MB 실측**(canvaskit 31MB + 게임 자산 9.7MB + NOTICES 1.3MB + 나머지 ~3MB) | **T-166**(신규) · T-069 | M1 | T-166 |
| **G-2** | `TOWN2` 는 맵도 등록도 없는 **도달 불가 코드** | **T-149**(처분 판정) | M6 | T-149 · Q-51-2 |
| **H-1** | `powOfShield`/`powOfArmor` 만 죽은 필드(`powOfWeapon` 은 `battle.dart:439` 가 읽는다). 방어는 `ac` 하나뿐 | **T-102**(1차 스코프는 이것만으로 충분) · T-160(선택 갈래) | M3 | T-102 |
| **H-2** | `ac` 척도가 `books.json` 과 불일치 — 10/20 → **2/5 재척도** | **T-099**(완료 조건 강화) | M3 | T-099 · T-160 |
| **H-3** | `books.json` id 공간과 `HDPlayer.weapon` 정수가 **무관** | **T-161**(신규 — 매핑표 + `_legacy` 이동) · T-102 | M3 | T-161 |
| **H-4** | 맵 에디터 `registerAs` 는 **이미 `json` 필드를 쓴다** | **T-004**(범위 한정 근거) | M0 | T-009 |
| **I-1** | `Map001.json` (2,3) 이 이미 `region=255` | **태스크 없음 (D-27 로 무의미)** | — | — |
| **J-1** | region 값은 **타일 액션을 만들 수 없다**(`map_loader.dart:44` 하위 바이트 ↔ `tile_properties.dart:187` 상위 바이트) | **T-059**(완료 조건) · **T-165**(신규 — 테스트로 고정) | M1 | T-165 |
| **J-2** | region 예약안을 전제한 검증·편집 기능이 **무효화**된다 | **T-075**(정합 규칙 WARN 강등) · T-124(오버레이 전용) | M2 · M4 | T-075 · T-124 |
| **J-3** | 타일 액션의 실제 출처는 **3개뿐** — step-on 도 타일 액션 없이 발화해야 한다 | **T-165**(신규) | M1 | T-165 |
| **K-1** | D-27 은 진입점 **3개 중 2개**(step-on `:193` · 확인키 `:405`)에서 **코드 변경 없이 성립**한다 | **T-165**(확인만 — 새 코드 없음) | M1 | T-165 |
| **K-2** | **bump 경로만** presentation 게이트가 남아 비대칭(`player_sprite.dart:359-366` 의 `if (action.isInteractive)`) | **T-167**(신규 — 1줄 변경) | M1 | T-165(3경로 일치 단언) |
| **K-3** | `:193` 은 **fire-and-forget** 이고 `_lastInteractedX/Y` 중복 방지도 presentation 소유 | **T-059**(재진입 가드 규약) · T-087(추출 시 이관) | M1 · M2 | T-165 · T-085 |

### 2.0 누락 판정의 근거 (자기 점검)

| 판정 | 건수 | 항목 |
|---|---:|---|
| ✅ 태스크가 결함을 직접 닫는다 | **31** | A-1~A-4 · B-1~B-5 · C-1~C-4 · D-1·D-2 · E-1~E-3 · F-0~F-4 · G-2 · H-1~H-4 · J-1~J-3 · **K-1~K-3** |
| ⊘ 태스크가 불필요하다(근거 있음) | **2** | **G-1**(집계 규칙 — 표 자체가 대응) · **I-1**(D-27 이 예약안을 폐기해 충돌이 존재하지 않게 됨. 게다가 I-1 자신이 "`Map001.json` 은 타일 액션 경계를 훑는 테스트 픽스처로 보이므로 함부로 정리하지 말 것" 이라고 경고했다 — **정리 태스크를 만드는 것이 오히려 위험**하다) |
| **합계** | **34** | — |

> **초판이 놓친 이유** — §2 가 `A-1~F-4` 로 범위를 고정한 상태에서 부록에 `G`~`J` 가 추가되었고,
> 그 추가분이 본 장으로 수신되지 않았다. 같은 원인으로 [BP-50 §4.2](50_roadmap.md)·[BP-52 §52.2](52_risks.md) 도
> 같은 항목을 빠뜨렸으며 **세 장을 같은 개정에서 함께 고쳤다**(RK-12 의 "인용한 모든 장을 grep 으로 찾아 동시에 고친다" 절차).

> **E-2 의 대응 태스크는 `T-113`(LORE_EP 이관)과 `T-149`~`T-150`(잔여 이관)이 쓰는 **레거시 변환기**다.
> 변환기는 MV `pages` 를 `Dialogue.entry[]` 로 옮길 때 **순서를 뒤집어야** 한다(MV: 번호 큰 것 우선 / 본 기획: 위에서 첫 true).
> 현재 레포의 모든 이벤트는 `pages` 가 1개뿐이라 당장의 차이는 없으나, 변환기에 **규칙과 테스트를 못 박아 두는 것**이 대응이다.
> 이 규칙은 **T-113 의 완료 조건**에 포함된다.

### 2.1 부록 항목의 마일스톤 분포

**(가) G-1 집계 21건**

| M | 부록 건수 | 항목 |
|---|---|---|
| **M0** | **17** | A-1 · A-2 · A-3(진단) · B-1 · B-2 · B-4 · C-1 · C-2 · C-4 · D-1 · D-2 · E-1 · E-3 · F-1 · F-2 · F-3 · F-4 |
| **M1** | 2 | A-4 · C-3 |
| **M2** | 1 | B-3 |
| **M3** | 2 | A-3(해소) · E-2 |
| **합계** | 21 (**A-3 은 M0·M3 양쪽에 계상**되어 행 합은 22) | — |

**(나) G-1 이 세지 않은 추가 10건**

| M | 부록 건수 | 항목 | 비고 |
|---|---|---|---|
| **M0** | 2 | F-0 · H-4 | 둘 다 기존 태스크의 **근거·범위**로 흡수(T-030 · T-004) |
| **M1** | 3 | B-5 · J-1 · J-3 | B-5 → T-166(신규), J-1·J-3 → T-165(신규) |
| **M2** | 1 | J-2(린트 쪽) | T-075 완료 조건 개정 |
| **M3** | 3 | H-1 · H-2 · H-3 | H-1 → T-160(신규), H-2 → T-099 강화, H-3 → T-161(신규) |
| **M4** | 1 | J-2(에디터 쪽) | T-124 — 앵커를 **오버레이로만** 표시, 맵 데이터 미변경 |
| **M6** | 1 | G-2 | T-149 처분 판정 |
| **배치 불필요** | 2 | G-1 · I-1 | §2.0 의 ⊘ 판정 |
| **합계** | 13행 (J-2 는 M2·M4 양쪽에 계상, G-1·I-1 포함) | — | — |

---

## 3. 태스크 전수 목록

### 3.1 A. 기반 복구 — M0 (T-001 ~ T-034)

#### A-1군: 기준선 (RP-3 — 변경 *전에* 뜬다)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-001** | `RecordingUiHost` 최소판을 만든다 (UiHost 11메서드 호출을 순서대로 기록) | M0 | — | `hadar2026_app/test/harness/recording_ui_host.dart`(신규) | 11개 메서드 전부 구현, 호출 순서·인자를 JSONL 로 덤프 | M | [BP-28 §4.2](28_migration_and_coexistence.md) · R-28-6 |
| **T-002** | 16개 맵(등록 15 + ORIGIN)의 선행 골든 트레이스를 채취한다 | M0 | T-001 | `hadar2026_app/test/golden/maps/`(신규) | 16개 골든 파일이 커밋되고 2회 실행 결과가 동일 | M | **T-28-0** |
| **T-003** | `approvedDeltas` 목록 파일을 신설한다 | M0 | T-002 | `hadar2026_app/test/golden/approved_deltas.json`(신규) | T-005·T-010·T-012·T-014 의 의도된 변화가 각각 `taskId` 로 등재 | S | [BP-28 R-28-15](28_migration_and_coexistence.md) · INV-20-05b |
| **T-004** | `MapInfos.json` 15엔트리에 `json` 필드를 명시한다 | M0 | T-002 | `hadar2026_app/assets/maps/MapInfos.json` | `TOWN1→TOWN1.json` 등 실재 파일로 해석. 실재하지 않는 4개(Template_TOWN·Prolog·Template_DUNGEON)는 **엔트리 제거 또는 파일 신설** 중 하나를 선택해 기록. **수리 범위는 기존 15엔트리로 한정한다** — `tools/mapEditor/server/ai_api.ts:592` 가 이미 `json: file` 을 넣으므로 신규 맵 경로는 고칠 것이 없다(부록 H-4) | S | **부록 D-1 · H-4** · T-28-2 · RK-01 |
| **T-005** | 맵 이름 해석의 폴백 우선순위를 반전하고 `Map%03d.cm2` 무조건 기본값을 제거한다 | M0 | T-004 | `hadar2026_app/lib/application/map_navigation.dart` | `cm2` 필드가 없으면 `cm2Path == null`. `json` 필드가 없으면 `<name>.json` 폴백이 살아남는다 | S | **부록 A-1 · D-1** · T-28-2 |
| **T-006** | `loadByName` 의 실패 규약을 고친다 — JSON 로드 실패는 항상 실패다 | M0 | T-005 | `hadar2026_app/lib/application/map_navigation.dart` | `json == null` 인 `MapBundle` 이 "성공" 으로 반환되지 않는다 | S | **부록 D-2** |
| **T-007** | `loadMapFromFile` 의 반환값 계약을 고친다 — 맵 교체 성공만 `true` | M0 | T-006 | `hadar2026_app/lib/application/game_session.dart` | 존재하지 않는 맵 이름으로 호출 시 `false` | S | **부록 D-2** |
| **T-008** | `HDGameSession.currentMapName` 을 신설한다 (로드 성공 확정 후에만 갱신) | M0 | T-007 | `hadar2026_app/lib/application/game_session.dart` | 실패한 전환 후에도 이전 이름이 유지됨을 테스트가 고정 | S | **T-28-3** · D-22 |
| **T-009** | 맵 이름 해석 회귀 테스트를 쓴다 (등록 15 + ORIGIN 16케이스) | M0 | T-008 | `hadar2026_app/test/application/map_navigation_test.dart` | 16케이스 전부 `displayName` 이 기대값과 일치. `ORIGIN` 은 **등록 후에도** 로드된다 | M | **부록 D-1 · F-4** |

#### A-2군: cm2 상태 누수와 네이티브 부착

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-010** | `loadScript` 실패 시 `clearRuntimeState()` 를 호출한다 | M0 | T-002 | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart` | 맵 전환 후 `_engine.currentScript.length == 0` | S | **부록 A-2** · T-28-1 |
| **T-011** | cm2 부재 맵의 티어 판정을 `currentMapCm2Path == null` 로 정직하게 만든다 | M0 | T-005·T-010 | `hadar2026_app/lib/application/game_session.dart`, `lib/application/tile_event_dispatcher.dart` | 13개 맵이 티어 2 → 티어 3 으로 이동하고 그 이동이 `approvedDeltas` 와 일치 | S | [BP-28 §2.4](28_migration_and_coexistence.md) B-2 |
| **T-012** | 네이티브 맵 스크립트 부착에 가드를 건다 — `bundle.json == null` 이면 부착하지 않는다 | M0 | T-007 | `hadar2026_app/lib/application/game_session.dart` | 로드 실패한 맵 이름에 대해 `native.currentMapScript == null` | S | **부록 F-2** |
| **T-013** | 네이티브 부착·스크립트 누수 회귀 테스트를 쓴다 | M0 | T-010·T-012 | `hadar2026_app/test/application/native_binding_test.dart`(신규) | 실패 전환 후 직전 맵 스크립트가 살아 있지 않음을 단언 | S | 부록 A-2 · F-2 |

#### A-3군: 세이브 복원 (v1 수준에서 먼저)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-014** | `MapModel.toJson`/`fromJson` 에 `events` 를 포함한다 | M0 | T-002 | `hadar2026_app/lib/domain/map/map_model.dart` | 저장→로드 후 `map.events.length` 가 저장 전과 동일 | S | **부록 C-1** |
| **T-015** | 세이브 로드 경로가 네이티브 스왑과 `currentMapCm2Path` 를 갱신하게 한다 | M0 | T-008·T-012 | `hadar2026_app/lib/application/save_manager.dart`, `lib/application/game_session.dart` | 로드 후 `currentMapScript` 가 **현재 맵**의 것 | M | **부록 C-2** · Q-20-10 |
| **T-016** | 세이브 왕복 회귀 테스트를 쓴다 | M0 | T-014·T-015 | `hadar2026_app/test/application/save_roundtrip_test.dart`(신규) | Map002(18이벤트) 저장→로드 후 같은 좌표에서 같은 대사가 나온다 | S | 부록 C-1 · C-2 |

#### A-4군: 결정론 (코드 교정만. 게이트 점등은 M2 — RP-4)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-017** | `WorldRng` 최소판을 도입한다 (splitmix64 계열, `seed`+`cursor` 무상태 재계산) | M0 | — | `hadar2026_app/lib/domain/content/world_rng.dart`(신규) | 같은 `(seed, cursor)` 가 항상 같은 값. 단위 테스트 | M | [BP-27 §9.2](27_runtime_engine.md) |
| **T-018** | `damagedByPoison()` 이 난수를 **인자로 받게** 바꾼다 | M0 | T-017 | `hadar2026_app/lib/domain/party/player.dart`, `lib/domain/party/party.dart` | `player.dart` 에 `DateTime.now()` 0건. 주어진 roll 로만 데미지 결정 | S | **부록 C-4** · **DT-1** |
| **T-019** | `battle.dart` 의 무시드 `Random()` 14곳을 `WorldRng` 필드로 교체한다 | M0 | T-017 | `hadar2026_app/lib/application/battle.dart` | `grep -c "Random()" lib/application/battle.dart` == 0 | M | **부록 C-4** · **DT-2** |
| **T-020** | `menu_flows.dart` 의 도주 판정 난수를 `WorldRng` 로 교체한다 | M0 | T-017 | `hadar2026_app/lib/application/menu_flows.dart` | 같은 시드에서 도주 성공 여부가 재현 | S | **부록 C-4** · **DT-3** |
| **T-021** | 결정론 재현 테스트를 쓴다 (같은 시드·같은 입력열 2회 → 동일 로그) | M0 | T-018·T-019·T-020 | `hadar2026_app/test/application/determinism_test.dart`(신규) | 파티 HP·전투 로그가 바이트 동일 | S | [BP-50](50_roadmap.md) G0-3 · **T-35-4** |

#### A-5군: 종료 흐름과 `dart:io` (D-23 에 따라 CI 검사와 한 묶음)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-022** | `UiHost` 에 종료 요청 메서드를 추가한다 | M0 | — | `hadar2026_app/lib/application/ports/ui_host.dart` | 시그니처가 [BP-27](27_runtime_engine.md) 확정본과 일치. 기존 구현체 전부 컴파일 | S | **T-34-7** · T-35-5 |
| **T-023** | `menu_flows.dart` 에서 `import 'dart:io'` 와 `exit(0)` 3곳을 제거한다 | M0 | T-022 | `hadar2026_app/lib/application/menu_flows.dart` | 해당 파일에 `dart:io`·`exit(` 0건. `kIsWeb` 분기도 제거 | S | **부록 B-4** · T-35-5 |
| **T-024** | `HDFlutterUiHost` 에 종료 구현을 넣는다 (웹/데스크톱 분기는 presentation 소유) | M0 | T-022 | `hadar2026_app/lib/presentation/host/flutter_ui_host.dart`, `lib/hd_game_main.dart` | 데스크톱에서 종료, 웹에서 안내 로그 + `waitForAnyKey`. **추가**: 웹 빌드를 브라우저에서 띄워 그 메뉴를 **실제로 눌러** 동작을 확인하고 결과를 기록한다 — 부록 **B-4-4** 는 **미확인** 항목이며 빌드 성공이 이를 보증하지 않는다([BP-50](50_roadmap.md) G0-8 · WS-0-5) | S | [BP-34 §2.3](34_headless_sim_and_solver.md) · **부록 B-4-4** · RK-08 |

#### A-6군: 전투 계약

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-025** | 전투 결과 코드의 **정본을 확정한다** (Dart 0/2 vs `const.cm2` 0/2) — 결정 태스크 | M0 | T-002 | `blueprint/` 결정 기록 + `hadar2026_app/assets/const.cm2` | Q-20-11 이 종결되고 선택 근거가 문서화됨 | S | **부록 B-2** · Q-20-11 |
| **T-026** | 확정된 정본을 코드·cm2 상수에 반영하고 상수를 이름 있는 열거로 승격한다 | M0 | T-025 | `hadar2026_app/lib/application/battle.dart`, `assets/const.cm2` | `Battle::Result()` 의 0/1/2 의미가 양쪽에서 일치. 골든 diff 가 `approvedDeltas` 와 일치 | M | **부록 B-2** |
| **T-027** | 전투를 실행하지 않은 상태의 `Battle::Result()` 반환 규약을 정한다 | M0 | T-026 | `hadar2026_app/lib/application/battle.dart` | `Battle::Start` 없이 읽으면 "미실행" 값이 나오고 승리로 오독되지 않는다 | S | **부록 F-3** |
| **T-028** | `registerEnemy` 의 범위 밖 인자에 경고를 남기고 유효 범위를 상수화한다 | M0 | — | `hadar2026_app/lib/application/battle.dart`, `lib/domain/battle/enemy_data.dart` | `registerEnemy(0)` 이 경고를 남긴다. 상수 `1..74` 가 INV-20-20 의 근거로 노출됨 | S | **부록 B-1** |

#### A-7군: 침묵 실패와 잔재

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-029** | `Flag::Set/Reset` · `Variable::Set/Add` 의 범위 밖 인자에 경고 로그를 남긴다 | M0 | — | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart` | `Flag::Set(300)` 이 경고를 출력. 4개 커맨드 전부 `else` 분기 보유 | S | **부록 F-1** |
| **T-030** | 커맨드로 중복 등록된 빈 `Party::PosX`/`Party::PosY` 등록을 제거한다 | M0 | T-002 | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart` | 함수 등록만 남고 동작 변화 0(골든 diff 없음) | S | **부록 F-0** · T-28-9 |
| **T-031** | RPG Maker `code 101` 을 "텍스트 헤더" 로 서술한 3곳을 정정한다 | M0 | — | `blueprint/12_reference_designs.md`, `blueprint/92_appendix_reference_index.md` | "101 → `Node.header`" 서술이 0건. `map_event.dart` 가 101 을 버리는 것이 **옳은 동작**임을 명시 | S | **부록 E-1** |
| **T-032** | D-02 의 근거 문장에서 "cm2 는 튜링 완전" 논거를 제거하고 실측 근거로 대체한다 | M0 | — | `blueprint/12_reference_designs.md`, `blueprint/11_gap_analysis.md` | "튜링 완전" 을 근거로 쓴 문장 0건. 결정 D-02 자체는 **유지** | S | **부록 E-3** |
| **T-033** | 네이티브 맵 플래그 스텁이 **항상 `false`** 임을 고정하는 진단 테스트를 쓴다 | M0 | — | `hadar2026_app/test/application/map_script_flag_test.dart`(신규) | 현행 동작을 단언. T-111 이 이 테스트를 **의도적으로 뒤집는다** | S | **부록 A-3** |
| **T-034** | M0 종료 점검 — 골든 diff 를 `approvedDeltas` 와 1:1 대조한다 | M0 | T-005~T-033 전부 | `hadar2026_app/test/golden/**` | 설명되지 않은 diff 0건. [BP-50](50_roadmap.md) G0-1~G0-7 전부 green | M | INV-20-05b · WS-0-2 |

### 3.2 B. 콘텐츠 코어 — M1 (T-035 ~ T-058)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-035** | **Q-20-1 을 결정한다** — 순수 Dart CLI 가 `domain/content/` 를 공유하는 수단(물리 분리 `packages/hadar_content` / pub workspace / 복사) | M1 | — | `blueprint/` 결정 기록 | 3안 비교와 선택 근거가 문서화됨. [BP-34 R-34-6](34_headless_sim_and_solver.md)("`foundation` 조차 금지")과 양립 | S | **Q-20-1** · Q-50-2 |
| **T-036** | 결정된 배치로 콘텐츠 도메인 패키지를 신설한다 | M1 | T-035 | `packages/hadar_content/`(신규) **또는** `hadar2026_app/lib/domain/content/`(신규) | `dart analyze` 통과. `grep -rn "package:flutter"` 빈 결과(INV-20-04) | M | D-11 · R-20-2 |
| **T-037** | `content_ids.dart` — ID 타입·문법 검증을 구현한다 | M1 | T-036 | `.../content/content_ids.dart`(신규) | D-04 슬러그 규칙(3~48자, 숫자 시작 금지) 위반을 거부. 단위 테스트 | S | D-04 · [BP-21](21_content_pack_spec.md) |
| **T-038** | `condition.dart` — Condition 모델과 파서를 구현한다 | M1 | T-037 | `.../content/condition.dart`(신규) | D-05 의 허용 op 전량 파싱, 미지 op 는 **하드 실패**(R-33-1) | M | D-05 · [BP-21](21_content_pack_spec.md) |
| **T-039** | Condition 평가기를 구현한다 (`WorldStateView` 만 받는 순수 함수) | M1 | T-038·T-047 | `.../content/condition.dart` | 부작용 없음을 스냅샷 해시로 검증. `WorldStateMutator` 를 받지 않는다 | M | D-05 · **D-21** · R-25-5 |
| **T-040** | `effect.dart` — Effect 모델과 파서를 구현한다 | M1 | T-037 | `.../content/effect.dart`(신규) | D-05 의 허용 do 전량 파싱, 미지 do 는 하드 실패 | M | D-05 |
| **T-041** | Effect 적용기를 구현한다 (즉시 효과) | M1 | T-040·T-047 | `.../content/effect.dart` | 배열 순서대로 적용. 이벤트는 큐에 넣기만 하고 여기서 드레인하지 않는다(EV-1) | M | D-05 · [BP-25 §4](25_world_state_and_save.md) |
| **T-042** | `chance` op 을 **무커서 해시**로 평가한다 (`splitmix64(seed, step, siteId)`) | M1 | T-039·T-017 | `.../content/condition.dart`, `.../content/world_rng.dart` | 같은 `(seed, step, key)` 가 항상 같은 결과. `rngCursor` 불변. **이름 규약(D-21a)**: `siteId` 는 **폐기된 이름**이고 정본은 [BP-21 §6.5](21_content_pack_spec.md) 의 `key = "<contextId>#<evalPath>"` 다 | S | **D-21 · D-21a** · RK-34 |
| **T-043** | `quest.dart` · `stage.dart` · `objective.dart` 를 구현한다 | M1 | T-038·T-040 | `.../content/quest.dart` 외 2(신규) | D-06 필드 전량. `Objective.kind` 9종 파싱 | M | D-06 · [BP-23](23_quest_model.md) |
| **T-044** | `dialogue.dart` · `node.dart` · `choice.dart` 를 구현한다 | M1 | T-038·T-040 | `.../content/dialogue.dart` 외 2(신규) | D-07 필드 전량. `entry[]` 는 **위에서 첫 true** | M | D-07 · [BP-24](24_dialogue_model.md) |
| **T-045** | `actor.dart` · `item.dart` · `place.dart` · `anchor.dart` 를 구현한다 | M1 | T-037 | `.../content/` 4파일(신규) | 앵커 kind 6종 파싱. [BP-26](26_entity_registry_and_anchors.md) 필드와 일치 | M | D-09 · [BP-22](22_world_bible_model.md) · [BP-26](26_entity_registry_and_anchors.md) |
| **T-046** | `world_state.dart` — `WorldState` 와 **정규 직렬화**를 구현한다 | M1 | T-037 | `.../content/world_state.dart`(신규) | 삽입 순서와 무관하게 같은 바이트열(`flags`/`vars`/`quests`/`inventory` 정렬 출력) | M | D-08 · **D-08a** · **DT-4** |
| **T-047** | `WorldStateView` / `WorldStateMutator` 를 분리한다 | M1 | T-046 | `.../content/world_state.dart` | View 만 넘긴 평가기가 상태를 바꿀 수 없음을 스냅샷 해시로 검증 | S | R-25-5 · **D-21** |
| **T-048** | `partySnapshot` 을 도입한다 (`gold_cmp`/`party_level_cmp`/`party_has_class` 평가원) | M1 | T-047 | `.../content/world_state.dart`, `hadar2026_app/lib/application/content/`(신규) | 5개 op 이 `WorldStateView` 만으로 평가된다 | S | **Q-27-3** · REVIEW_BP-25 F-10 |
| **T-049** | `WorldRng` 를 콘텐츠 도메인으로 이관하고 `rngCursor` 를 `WorldState` 에 싣는다 | M1 | T-017·T-046 | `.../content/world_rng.dart` | 세이브/로드를 끼워도 난수 수열이 이어진다 | S | [BP-27 §9.2](27_runtime_engine.md) · R-25-7 |
| **T-050** | `world_event_bus.dart` — 발행·FIFO 큐·드레인·cascade 상한을 구현한다 | M1 | T-041 | `hadar2026_app/lib/application/content/world_event_bus.dart`(신규) | EV-1~EV-7 전부 테스트로 고정. 자기 재발행이 8단계에서 멈춘다 | M | [BP-25 §4.3](25_world_state_and_save.md) |
| **T-051** | 월드 이벤트 **12종의 타입과 payload** 를 정의한다 (D-20 정본) | M1 | T-050 | `.../content/world_event.dart`(신규) | **이름 12종**이 D-20 목록과 **문자 단위로 일치**. 변형 이름(`talked_to`/`entered_place`/`choice_made`) 0건. **payload 는 D-20 이 아니라 소유 장 [BP-23 §23.11.1](23_quest_model.md) 의 12행 표를 정본으로 삼는다**(D-20 개정 + D-25 — D-20 에는 payload 열이 존재하지 않는다) | S | **D-20 · D-20a · D-25** · RK-32 |
| **T-052** | `content_repository.dart` — 번들 로드(AssetSource 경유)와 조회를 구현한다 | M1 | T-043·T-044·T-045 | `hadar2026_app/lib/application/content/content_repository.dart`(신규) | 번들 부재 시 **예외 대신 비활성**. `schemaVersion` 초과는 거부. 미지 id 는 `null` | M | R-27-4 · [BP-27 §3.4](27_runtime_engine.md) |
| **T-053** | `trigger_index.dart` — `(map,x,y,kind)` O(1) 조회와 이벤트 역인덱스를 구현한다 | M1 | T-052 | `.../content/trigger_index.dart`(신규) | 다른 맵과 섞이지 않음. 역인덱스가 목표를 정확히 모음 | M | [BP-26](26_entity_registry_and_anchors.md) · [BP-27 §2.2](27_runtime_engine.md) |
| **T-054** | `dialogue_runtime.dart` — 노드 순회와 `UiHost` 출력을 구현한다 | M1 | T-044·T-052 | `.../content/dialogue_runtime.dart`(신규) | `UiHost` 호출 순서가 [BP-24](24_dialogue_model.md)·[BP-27 §5.2](27_runtime_engine.md) 규약과 일치. `once` 선택지가 두 번째에 사라진다 | L | D-07 · [BP-27 §5](27_runtime_engine.md) |
| **T-055** | `quest_runtime.dart` — 목표 판정·스테이지 전이·저널 기록을 구현한다 | M1 | T-043·T-050 | `.../content/quest_runtime.dart`(신규) | `completion` all/any, `next` 조건 배열, 비활성 퀘스트 미검사 | L | D-06 · [BP-27 §6](27_runtime_engine.md) |
| **T-056** | `content_runtime.dart` — `handleTile` 과 부팅을 구현한다 | M1 | T-053·T-054·T-055 | `.../content/content_runtime.dart`(신규) | 앵커 있으면 `true`, 없으면 `false`. 조건이 전부 거짓이어도 `true` + `fallback` 출력 | L | **D-10** · R-20-3 · R-27-6 |
| **T-057** | `HDEffectBridge` — 지연 효과(`warp`/`play_dialogue`/`start_battle`)의 실행 경로를 구현한다 | M1 | T-041·T-056 | `.../content/effect_bridge.dart`(신규) | 드레인 완료 후 지연 효과 **1건만** 실행. 24종 do 중 브리지 경유분이 표로 명시됨 | M | REVIEW_BP-27 **F-10** · REVIEW_BP-20 F-04 |
| **T-058** | 픽스처 팩 A/B 와 `domain/content` 테스트 일습을 쓴다 (`T-25-01~27`·`T-27-01~06,12~23` 대응) | M1 | T-036~T-057 | `hadar2026_app/test/domain/content/`(신규), `test/fixtures/packs/`(신규) | **INV-20-01** 통과 — 같은 바이너리가 팩 교체만으로 다른 퀘스트를 완주 | L | INV-20-01 · [BP-25 §10](25_world_state_and_save.md) · [BP-27 §10](27_runtime_engine.md) |

### 3.3 C. 런타임 통합 — M1 (T-059 ~ T-070)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-059** | 디스패처에 **티어 0** 을 삽입한다 (`check` 의 타일 액션 게이트 **앞에서** 트리거 인덱스 선조회 + `_dispatchScripted` 상단 1블록) | M1 | **T-056 · T-061** | `hadar2026_app/lib/application/tile_event_dispatcher.dart` | 앵커 있으면 JSON 대사가 나오지 않고, **앵커 0개 맵은 M0 골든과 동일**(INV-20-05). **D-27 반영**: 조회 키는 `(map, x, y)` 뿐이며 `HDTileAction` 이 scripted 인지와 **무관**하게 처리한다(`tile_event_dispatcher.dart:51-61` 의 게이트보다 앞). **선행에 T-061 이 있는 이유**: D-19 는 "`pendingNavigation` 승격 없이는 D-10 의 '티어 0 이 처리했으면 아래로 내려가지 않는다' 규약이 **맵 이동 시 성립하지 않는다**" 고 명시했다. 티어 0 이 먼저 들어가면 `warp` 경로에서 `endNarrative(autoFlush:)` 가 여전히 cm2 엔진 내부 상태(`tile_event_dispatcher.dart:99`)에 묶여 **narrative 를 잘못 flush** 하고, 그 상태의 골든·INV-20-05 판정은 전부 재작업 대상이 된다 | M | **D-10 · D-19 · D-27** · R-27-5 · RK-26 |
| **T-060** | `pendingNavigation` 을 세션/런타임 공용 개념으로 **승격**한다 | M1 | T-057 | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart`, `lib/application/game_session.dart`, `lib/hd_game_main.dart` | cm2 `LoadScript` 경로와 콘텐츠 `warp` 경로가 **같은 예약 저장소**를 쓴다 | M | **D-19** · T-28-8 |
| **T-061** | `endNarrative` 의 `autoFlush` 를 "전환 대기가 하나라도 있으면 flush 안 함" 술어로 바꾼다 | M1 | T-060 | `hadar2026_app/lib/application/tile_event_dispatcher.dart` | **INV-20-19** 통과. cm2·콘텐츠 양쪽 경로에서 동일 단언 | S | **R-20-14** · D-19 |
| **T-062** | 부팅 순서를 배선한다 (`bind` → `ContentRuntime.boot()` → `HDGameSession.init()` → `onMapEntered`) | M1 | T-056 | `hadar2026_app/lib/hd_game_main.dart`, `lib/application/ports/host_binding.dart` | bind 전 boot 시 `StateError`. 세이브 복원은 boot **이후** | S | **R-27-3** |
| **T-063** | 세이브 v2 봉투를 구현한다 (`worldState` + `currentMapName` 포함) | M1 | T-046·T-008 | `hadar2026_app/lib/application/save_manager.dart` | `currentMapName` 없이 저장되지 않는다. v1 도 계속 읽힌다 | M | [BP-25 §5](25_world_state_and_save.md) · D-08 |
| **T-064** | 맵 저장을 `base` 종류로 나눈다 (`asset:<path>` 델타 / `generated` 스냅샷) | M1 | T-063 | `hadar2026_app/lib/application/save_manager.dart`, `lib/domain/map/map_model.dart` | 100×100 맵 3칸 변경 세이브가 **50KB 미만**. `Map::Init` 생성 맵은 `generated` | M | **D-22** · **부록 C-3** |
| **T-065** | `generated` 스냅샷을 5필드 평행 배열 + RLE 로 인코딩한다 | M1 | T-064 | `hadar2026_app/lib/domain/map/map_unit.dart`, `lib/domain/map/map_model.dart` | 현행 키 반복 JSON 대비 크기 감소가 테스트로 측정됨 | M | **D-22** · 부록 C-3 |
| **T-066** | v1 → v2 마이그레이션과 `legacyFlagMap` 역참조를 구현한다 | M1 | T-063 | `hadar2026_app/lib/application/save_manager.dart` | **INV-20-15** 통과. 알 수 없는 정수 플래그는 `orphans` 로 보존. 값 0 인 변수는 옮기지 않음 | M | D-08 · [BP-25 §6](25_world_state_and_save.md) |
| **T-067** | 세이브 쓰기를 **2단계 커밋**으로 만든다 (실패 시 세션 상태 불변) | M1 | T-063 | `hadar2026_app/lib/application/save_manager.dart` | 4단계에서 던지는 페이크로 party/map 불변 확인. 스테이징 키는 부팅 시 폐기 | M | [BP-25 §8.2](25_world_state_and_save.md) · WS-1-3 |
| **T-068** | `hadar_content build` 최소 구현 (discover/normalize/link/emit/lock) | M1 | T-036 | `tools/content_cli/`(신규) | 3산출물 생성. **별도 프로세스 2회 빌드 해시 일치**(INV-20-02) | L | D-12 · [BP-35 §1](35_ci_and_build.md) |
| **T-069** | `assets/content/build/` 를 만들고 **하위 디렉토리를 명시 열거**해 pubspec 에 선언한다 | M1 | T-068 | `hadar2026_app/pubspec.yaml`, `hadar2026_app/assets/content/build/`(신규) | 웹 빌드 번들에 3파일이 실린다. 소스 폴더는 싣지 않는다(R-20-7). **단 "싣지 않는다" 의 이득은 T-166 이 부록 B-5 의 45MB 기준선에 비추어 측정한 뒤 확정한다** | S | **부록 A-4 · B-5** · R-30-19 · RK-09 |
| **T-070** | M1 종료 점검 — INV-20-01·02·04·05·06·15·19·21 을 전부 green 으로 만든다 | M1 | T-058~T-069 | `hadar2026_app/test/`, `.github/workflows/ci.yml` | [BP-50](50_roadmap.md) G1-1~G1-7 통과 | M | [BP-20 §9](20_target_architecture.md) |

### 3.4 D. 검증·린트 — M2 (T-071 ~ T-084)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-071** | L1 스키마 규칙 30개를 구현한다 | M2 | T-068 | `tools/content_cli/lib/src/lint/l1_schema.dart`(신규) | 30규칙 전부 ID·심각도·메시지 보유. L1 실패 시 하위 계층 스킵 | L | [BP-33 §4](33_validation_and_lint.md) |
| **T-072** | L2 참조무결성 규칙 26개를 구현한다 (**Condition 안의 참조 포함**) | M2 | T-071 | `.../lint/l2_reference.dart`(신규) | `V-L2-018` 적 id 범위 `1..74`. **Condition 내부 id 도 검사**(REVIEW_BP-23 F-02b) | L | [BP-33](33_validation_and_lint.md) · 부록 B-1 |
| **T-073** | L3 그래프 도달성 규칙 20개를 구현한다 | M2 | T-072 | `.../lint/l3_graph.dart`(신규) | 대화 도달 불가 노드 0, 퀘스트 스테이지 사이클 0(INV-20-11·12) | M | [BP-33](33_validation_and_lint.md) |
| **T-074** | L4 정합 규칙 38개를 구현한다 (문체·길이·지식 범위 포함) | M2 | T-072 | `.../lint/l4_consistency.dart`(신규) | 줄당 **30자** 임계 채택(Q-33-1). 저널 길이 `JV-01~07` 포함 | L | [BP-33](33_validation_and_lint.md) · [BP-41](41_journal_ui_spec.md) |
| **T-075** | MAP 규칙 22개를 구현한다 (앵커-통행 충돌, warp 도착 통행) | M2 | T-072·T-053 | `.../lint/map_rules.dart`(신규) | **심각도가 둘로 갈린다(D-27)** — ① **하드 유지**: 앵커의 맵 참조 해소, 좌표가 맵 범위 안, `warp` **도착 지점의 통행 가능성**. ② **WARN 강등**: 앵커 kind ↔ 권장 타일 정합(actor 앵커가 통행 가능 타일 위 등). D-27 이 "정합은 런타임 동작 조건이 아니라 **저작 품질 문제**" 로 확정했고 [BP-26 R-26-7a](26_entity_registry_and_anchors.md) 가 이를 받았다. 규칙별 최종 심각도의 소유는 [BP-33](33_validation_and_lint.md) 이므로 본 태스크는 **ERROR→WARN 조정이 반영되었는지만** 확인한다. `V-MAP-018` 은 승격된 `pendingNavigation` 을 전제 | M | [BP-33](33_validation_and_lint.md) · [BP-26 §3.3](26_entity_registry_and_anchors.md) · **D-27 · 부록 J-2** · RK-26 |
| **T-076** | DET 규칙 10개를 구현한다 (결정론 정적 검사) | M2 | T-071 | `.../lint/det_rules.dart`(신규) | `V-DET-*` 전량. 억제 불가 | M | [BP-33](33_validation_and_lint.md) |
| **T-077** | L5 규칙 6개를 배선한다 (시뮬레이터·솔버 호출) | M2 | T-096 | `.../lint/l5_exec.dart`(신규) | ERROR 0 일 때만 실행. 예산 초과는 **실패가 아니라 미확정**(FP-3) | M | [BP-33](33_validation_and_lint.md) · [BP-34 §5.9](34_headless_sim_and_solver.md) |
| **T-078** | 심각도 체계와 승격 4규칙·강등 2예외를 구현한다 | M2 | T-071 | `.../lint/severity.dart`(신규) | L1·L2·DET 은 억제 불가. 승격/강등이 테스트로 고정 | S | [BP-33 §5](33_validation_and_lint.md) |
| **T-079** | 출력 3포맷을 구현한다 (사람/기계/**AI 재시도 프롬프트**) | M2 | T-078 | `.../lint/report.dart`(신규) | AI 포맷이 R-33-18~24 의 7규약을 지킨다 | M | [BP-33 §7](33_validation_and_lint.md) |
| **T-080** | `--fix` 자동 수정 12건을 구현한다 | M2 | T-079 | `.../lint/autofix.dart`(신규) | 소스만 고치고 맵은 API 경유. 적용 후 **재검증** | M | R-33-13~15 |
| **T-081** | 증분 검증 범위표를 구현한다 (성능 예산 준수) | M2 | T-074 | `.../lint/incremental.dart`(신규) | 대 규모에서 L1~L3 < 3s, L1~L4 < 25s. 병렬 후 재정렬로 결정론 보존 | M | R-33-25~31 |
| **T-082** | JSON Schema 원문을 확정한다 (기존 부록의 스키마를 L1 이 소비 가능한 형태로) | M2 | T-071 | `blueprint/90_appendix_schemas.md` — **기존 파일이다**(초판의 `(신규)` 표기는 오류였다. R-51-2 는 실존 경로를 요구한다) | `"type":"number"` 0건(INV-20-09). L1 이 이 스키마를 소비 | M | INV-20-09 · [BP-90](90_appendix_schemas.md) |
| **T-083** | `ChanceOracle` 주입으로 평가기 단일 구현을 증명한다 (`T-33-A~F`) | M2 | T-042·T-071 | `tools/content_cli/test/`(신규) | 런타임과 검증기가 같은 평가기를 쓰고, 유일한 합법적 차이가 `ChanceOracle` 임을 6테스트가 고정 | M | R-33-32~38 · D-12 |
| **T-084** | Hard gate 8종 ↔ 규칙 ID 대응표를 게이트로 배선한다 | M2 | T-071~T-077 | `tools/content_cli/lib/src/gates.dart`(신규) | 8종 전부 대응 규칙이 있고 **빈칸 0**. [BP-50](50_roadmap.md) G2-1 | S | D-15 · [BP-33 §5.4](33_validation_and_lint.md) |

### 3.5 E. 시뮬레이터·솔버 — M2 (T-085 ~ T-098)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-085** | 이동·상호작용 통합 테스트 6종을 **추출 전에** 쓴다 | M2 | T-034 | `hadar2026_app/test/application/movement/`(신규) | 현행 동작(이동 1칸·마주보기·확인키·차단·step-on·warp)을 단언 | M | **T-34-4** · Q-34-3 |
| **T-086** | `PartyMovementController` 를 신설하고 12개 책임을 이관한다 | M2 | T-085 | `hadar2026_app/lib/application/movement/party_movement_controller.dart`(신규) | T-085 6종이 전부 통과. `application/` 계층 grep 통과 | L | **부록 B-3** · **T-34-1** |
| **T-087** | `player_sprite.dart` 를 재작성한다 (판정 제거, 표현만) | M2 | T-086 | `hadar2026_app/lib/presentation/panels/player_sprite.dart` | `grep -n "checkTileEvent" lib/presentation/panels/player_sprite.dart` **0건** | M | **T-34-2** · [BP-50](50_roadmap.md) G2-5 |
| **T-088** | `PartyMovementHost` 에 `showFacing`/`snapTo` 를 추가하고 `animatePartyMove` 계약을 바꾼다 | M2 | T-086 | `hadar2026_app/lib/application/ports/movement_host.dart`, `lib/presentation/host/flutter_ui_host.dart`, `lib/hd_game_main.dart` | 3개 구현체가 전부 컴파일. 헤드리스 구현이 애니메이션을 즉시 완료 | S | **T-34-3** |
| **T-089** | cm2 `Party::Move` 를 컨트롤러의 `scriptMove` 로 배선한다 | M2 | T-086 | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart` | cm2 이동이 컨트롤러를 거친다. 골든 diff 0 | S | **T-34-5** |
| **T-090** | 확인키를 폴링에서 `HDInputDispatcher` 이벤트로 바꾼다 | M2 | T-086 | `hadar2026_app/lib/presentation/input/input_dispatcher.dart` | 폴링 참조 0건. 입력 정책 문서(`docs/key_input_policy.md`)와 일치 | S | **T-34-6** |
| **T-091** | `HeadlessUiHost` 를 구현한다 (12메서드 + 관측 상태) | M2 | T-022·T-001 | `hadar2026_app/test/harness/headless_ui_host.dart`(신규) | 12메서드 전부. `requestQuit` 이 `SimQuitSignal` 을 던진다 | M | **D-13** · [BP-34 §3.2](34_headless_sim_and_solver.md) |
| **T-092** | `MemoryAssetSource` 와 `ScriptedMovementHost` 를 구현한다 | M2 | T-088 | `hadar2026_app/test/harness/memory_asset_source.dart`, `.../headless_movement_host.dart`(신규) | `map_navigation_test.dart` 의 페이크 패턴을 재사용. 파일시스템 0 | S | D-13 · GROUND_TRUTH §3 |
| **T-093** | `SimDriver` 와 `SimTrace` 를 구현한다 | M2 | T-091·T-092·T-086 | `hadar2026_app/test/harness/sim_driver.dart`, `.../sim_trace.dart`, `hadar2026_app/tool/sim_main.dart`(신규) | 같은 입력열 2회 실행 트레이스 해시 동일 | L | D-13 · [BP-34 §3](34_headless_sim_and_solver.md) |
| **T-094** | `SimPolicy` 3종(`scripted`/`greedy`/`random`)을 구현한다 | M2 | T-093·T-095 | `hadar2026_app/test/harness/sim_policy.dart`(신규) | `random` 은 시드 고정. `greedy` 는 목표를 향해 수렴 | L | **D-13** · [BP-34 §4](34_headless_sim_and_solver.md) |
| **T-095** | `map_graph.dart` — 통행 그래프와 경로 탐색을 구현한다 | M2 | T-086 | `hadar2026_app/test/harness/map_graph.dart`(신규) | `reach` 목표의 경로 존재 검사가 성립. F-1(물리적 도달 불가) 검출 | M | [BP-34 §4.3](34_headless_sim_and_solver.md) |
| **T-096** | `QuestSolver` — 상태 추상화·가지치기 P-1~P-5·탐색을 구현한다 | M2 | T-058 | `tools/content_cli/lib/src/solver/`(신규 4파일) | 픽스처 퀘스트의 완주 경로 **2개 이상** 증명. **이동 추출을 기다리지 않는다** | L | **D-13** · [BP-34 §5](34_headless_sim_and_solver.md) · §2.5 Phase 0 |
| **T-097** | witness 교차 검증을 배선한다 (solve → sim 재생) | M2 | T-093·T-096 | `tools/content_cli/lib/src/sim/sim_invoker.dart`(신규) | 솔버 해가 `SimDriver` 로 재생됨. 재생 실패는 **솔버의 버그**로 분류 | M | **R-34-7** · WS-2-1 |
| **T-098** | 하네스 자기 테스트 S-01~S-12 를 쓴다 | M2 | T-093·T-094 | `hadar2026_app/test/harness/harness_self_test.dart`(신규) | 12케이스 전부 통과. 실패 시 **콘텐츠가 아니라 하네스** 문제로 판정 | M | [BP-34 §9](34_headless_sim_and_solver.md) · FP-1 |

### 3.6 F. 게임 시스템 — M3 (T-099 ~ T-114)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-099** | 아이템 카탈로그 도메인을 구현한다 | M3 | T-045 | `.../content/item.dart`, `hadar2026_app/assets/content/core/items/items.json`(신규) | ID 문법 통과. **`assets/maps/books.json` 의 `ac` 를 2/5 로 재척도해 옮긴다**([BP-42 R-42-34](42_item_and_inventory.md)) — 원값 `10`/`20` 이 `items.json` 에 그대로 남아 있지 않음을 테스트가 단언한다. **근거(부록 H-2)**: 레벨 1 캐릭터의 피해 감소량은 `ac × (0.1~1.0)` 이고 레벨 1 적(`Orc` str 8)의 공격력은 `0.8~8` 이므로 **`ac 10` 은 초반 전투를 통째로 무효화**한다. `power` 는 그대로 옮긴다. (초판 완료 조건의 "참조원으로 **검토**" 는 기계 판정이 불가능해 폐기) | M | **D-16-2 · 부록 H-2** · [BP-42 R-42-34](42_item_and_inventory.md) · RK-40 |
| **T-100** | 인벤토리 자료구조를 `HDParty` 에 통합한다 | M3 | T-099·T-046 | `hadar2026_app/lib/domain/party/party.dart`, `.../content/world_state.dart` | `inventory: Map<itemId,count>` 가 세이브에 실린다. `takeItem` 이 0에서 클램프하고 키를 제거 | M | D-16-2 · [BP-25](25_world_state_and_save.md) INV-3 |
| **T-101** | `give_item`/`take_item` 효과와 `item_gained`/`item_lost` **발행 지점**을 만든다 | M3 | T-100·T-051 | `.../content/effect.dart`, `.../content/world_event_bus.dart` | **측정 수단이 붙은 형태**: `event_publishers.json`(T-157)에서 `item_gained`·`item_lost` 의 `status` 가 `unpublished` → **`published`** 로 바뀌고 `sites` 가 실제 심볼을 가리킨다(CI 의 `Event publisher drift` 스텝이 대조 — [BP-35 R-35-11e](35_ci_and_build.md)). 그 결과 M2 에서 `PROVEN + UNSUPPORTED` 로 **미활성** 처리된 팩이 재판정으로 활성화된다. `acquire` 목표가 진행됨 | M | **D-20 · D-26** · D-16-6 · RK-39 |
| **T-102** | 장비 정수 ID(`weapon`/`shield`/`armor`)를 아이템 ID 로 마이그레이션한다 | M3 | T-099 | `hadar2026_app/lib/domain/party/player.dart`, `lib/application/save_manager.dart` | `getWeaponName()` 하드코딩 플레이스홀더 제거. v1 세이브의 정수 장비가 이름을 얻는다. **추가**: 장착·해제 시 `powOfWeapon ← equip.power`(덮어쓰기)와 **`ac ← armor.ac + shield.ac`(합산)** 을 배선한다([BP-42 R-42-29~R-42-31·R-42-33](42_item_and_inventory.md)). **장비 교체가 `battle.dart` 의 피해 감소량을 실제로 바꾸는 것**을 단위 테스트가 고정한다 — 이 단언이 없으면 "이름은 예쁘지만 장착해도 아무 효과가 없는 장비" 가 만들어지고, 그 상태로도 G3-2 는 통과한다(목표 판정은 소지 여부만 보므로) | M | [BP-42 R-42-29~33](42_item_and_inventory.md) · **부록 H-1** · GROUND_TRUTH §10 · RK-40 |
| **T-103** | 소지품 창을 구현한다 (저널과 프레임 공유) | M3 | T-100 | `hadar2026_app/lib/presentation/panels/inventory_window_view.dart`(신규), `lib/domain/window/`(신규 1) | (144,40) 512×400 프레임. 새 `HDInputMode` 0개 | M | [BP-41 R-41-8](41_journal_ui_spec.md) · [BP-42](42_item_and_inventory.md) |
| **T-104** | 저널 뷰 도메인(`journal_view.dart`)을 구현한다 | M3 | T-055 | `.../content/journal_view.dart`(신규) | 정렬이 `step` 내림차순 → `questId` 사전순으로 **결정적** | S | [BP-41 §41.10](41_journal_ui_spec.md) · Q-41-1 |
| **T-105** | `HDJournalWindow` 와 presenter 를 구현한다 | M3 | T-104 | `hadar2026_app/lib/domain/window/journal_window_data.dart`(신규), `lib/presentation/panels/journal_window_view.dart`(신규), `lib/application/content/journal_flows.dart`(신규) | 목록/상세 2화면 × 탭 3종. 콘텐츠 팩이 없어도 창이 열린다(R-41-13) | L | [BP-41](41_journal_ui_spec.md) · **D-16-1** |
| **T-106** | `HDWindowKeyDispatcher` 에 저널·소지품 분기를 추가한다 | M3 | T-103·T-105 | `hadar2026_app/lib/presentation/input/window_key_dispatcher.dart` | 분기 순서 message → journal → inventory → magic → selection. **신규 전역 키 0개** | S | [BP-41 R-41-9](41_journal_ui_spec.md) · R-40-14 |
| **T-107** | 메인 메뉴를 7항목 → 9항목으로 확장하고 `maxVisible` 을 추가한다 | M3 | T-105 | `hadar2026_app/lib/application/menu_flows.dart`, `lib/domain/window/selection_window_data.dart`, `lib/application/ports/ui_host.dart` | 신규 7번 `소지품을 살핀다`, 8번 `임무를 확인한다`. `h = 60+9*34 = 366`. 기존 인덱스 불변 | M | **R-40-12** · R-41-10 |
| **T-108** | `HDTrackerBar` 를 구현한다 (미지정 시 0px) | M3 | T-105 | `hadar2026_app/lib/presentation/panels/console_panel.dart`, `.../tracker_bar.dart`(신규) | 추적 미지정 시 화면이 변경 전과 **픽셀 동일**(R-40-17) | S | [BP-41](41_journal_ui_spec.md) · R-41-11 |
| **T-109** | `enter_place` 발행 지점을 만든다 (places 영역 판정) | M3 | T-045·T-051·T-086 | `.../content/content_runtime.dart`, `hadar2026_app/lib/application/movement/party_movement_controller.dart` | `event_publishers.json` 에서 `enter_place` 의 `status` 가 **`published`** 로 바뀌고 `sites` 가 실제 심볼을 가리킨다(T-157). `visited` 가 채워진다 | M | **D-20 · D-26** · [BP-22](22_world_bible_model.md) · RK-39 |
| **T-110** | `time_of_day` 를 구현하고 `sight_calculator` 와 경계값을 공유한다 | M3 | T-039 | `hadar2026_app/lib/domain/lighting/sight_calculator.dart`, `.../content/condition.dart` | `isDaytime` 이 한 곳에 있고 두 쪽이 같은 값을 본다 | S | R-40-16 · Q-40-4 |
| **T-111** | `HDMapScript.isFlagSet`/`setFlag` 를 `HDNativeScriptRunner` 에 위임한다 | M3 | T-033·T-002 | `hadar2026_app/lib/application/scripting/map_script.dart`, `.../native_script_runner.dart` | T-033 의 진단 테스트가 **뒤집힌다**. 변화가 `approvedDeltas` 에 등재됨 | S | **부록 A-3** · **T-28-7** |
| **T-112** | 네이티브 티어를 정비한다 — `bool` 반환값 소비 / JSON 선-방출 게이트 / `onPostEvent` 처분 | M3 | T-059 | `hadar2026_app/lib/application/tile_event_dispatcher.dart`, `.../native_script_runner.dart`, `.../map_script.dart` | 한 상호작용당 JSON 방출 **1회**. `onPostEvent` 는 호출되거나 제거됨(Q-20-4 종결) | M | **T-28-4·5·6** · REVIEW_BP-28 F-02 |
| **T-113** | **LORE_EP(Map002)** 를 콘텐츠 팩으로 이관한다 (레거시 변환기 포함) | M3 | T-070·T-098 | `hadar2026_app/assets/content/core/`(신규), `tools/content_cli/lib/src/migrate/`(신규) | 부팅→대화→이동 전 경로 회귀 골든 통과. **변환기가 MV `pages` 순서를 뒤집는다**(부록 E-2) | L | [BP-28 §9.1](28_migration_and_coexistence.md) 2번 · **부록 E-2** |
| **T-114** | **TOWN1** 을 콘텐츠 팩으로 이관한다 | M3 | T-111·T-113 | `hadar2026_app/assets/content/core/anchors/TOWN1.json`(신규) | shadow diff 가 `approvedDeltas` 와 일치. 티어 0 이 네이티브를 가리는 것이 **의도된 동작**임을 기록 | L | [BP-28 §9.1](28_migration_and_coexistence.md) 3번 · Q-27-6 |

### 3.7 G. 저작 도구 — M4 (T-115 ~ T-126)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-115** | 콘텐츠 API 라우터 골격을 만든다 (기존 맵 API 와 같은 프로세스·같은 에러 규약) | M4 | T-068 | `tools/mapEditor/server/content_api.ts`(신규), `tools/mapEditor/vite.config.ts` | `GET /api/content` 가 가이드를 반환. 에러가 `{error, hint}` | M | **D-12-1** · [BP-31](31_content_server_api.md) |
| **T-116** | 읽기 엔드포인트를 구현한다 (packs/quests/dialogues/actors/items/anchors 조회) | M4 | T-115 | `tools/mapEditor/server/content_api.ts` | 요약·전문 두 수준. 미지 id 는 404 + hint | M | [BP-31](31_content_server_api.md) |
| **T-117** | 쓰기 엔드포인트를 구현한다 (배치 편집 ops, 스키마 정규화) | M4 | T-116·T-080 | `tools/mapEditor/server/content_api.ts`, `tools/mapEditor/server/store.ts` | 응답에 **L1/L2 진단 동봉**. 잘못된 쓰기는 파일을 건드리지 않는다 | L | D-12-4 · [BP-33 §7](33_validation_and_lint.md) |
| **T-118** | 앵커 CRUD 를 구현한다 | M4 | T-117 | `tools/mapEditor/server/content_api.ts` | 앵커 좌표 변경 시 통행 충돌을 **즉시** 보고 | M | [BP-26](26_entity_registry_and_anchors.md) · [BP-31](31_content_server_api.md) |
| **T-119** | `validate`/`build` 트리거 엔드포인트를 구현한다 | M4 | T-084 | `tools/mapEditor/server/content_api.ts` | CLI 와 **같은 규칙 ID·같은 판정**. 증분 빌드 지원 | M | [BP-31](31_content_server_api.md) · [BP-35](35_ci_and_build.md) |
| **T-120** | 컨텍스트 조립 `GET /api/content/context?for=` 를 구현한다 | M4 | T-116 | `tools/mapEditor/server/content_api.ts` | P0~P7 블록 배정, 총 **60,000 토큰** 예산 준수, P0~P2 절단 불가 | L | [BP-32 §32.5](32_generation_harness.md) |
| **T-121** | 문자열 키 발급 `POST /api/content/strings/mint` 를 구현한다 | M4 | T-117 | `tools/mapEditor/server/content_api.ts` | 키 문법(BP-21) 통과. 충돌 시 거부 | S | [BP-31](31_content_server_api.md) · [BP-32](32_generation_harness.md) |
| **T-122** | 퀘스트/대화 그래프 PNG 미리보기를 구현한다 | M4 | T-116 | `tools/mapEditor/server/content_preview.ts`(신규), `tools/mapEditor/server/preview.ts` 참조 | 스테이지 DAG·대화 그래프가 렌더됨. 조건 분기는 점선 | M | [BP-31](31_content_server_api.md) |
| **T-123** | MCP 래퍼에 `content_*` 도구를 추가한다 | M4 | T-117·T-119 | `tools/mapEditor/mcp/server.mjs` | 도구 이름이 전부 `content_` 접두. 기존 맵 도구와 같은 서버 | M | **D-12-3** |
| **T-124** | 맵 에디터 UI 에 앵커 오버레이를 추가한다 | M4 | T-118 | `tools/mapEditor/src/`(기존), `tools/mapEditor/AI_GUIDE.md` | 앵커가 지도 위에 보이고 드래그로 이동. 충돌 시 즉시 경고 | M | [BP-36](36_map_editor_extension.md) |
| **T-125** | CLI `new` / `diff` 를 구현한다 | M4 | T-068 | `tools/content_cli/bin/hadar_content.dart` | `new` 가 스캐폴딩 생성, `diff` 가 팩 버전 승격을 **기계 판정** | M | D-12-2 · [BP-35 §7.1](35_ci_and_build.md) |
| **T-126** | CLI `stats` / `migrate` 를 구현한다 | M4 | T-068·T-066 | `tools/content_cli/bin/hadar_content.dart` | `stats` 가 팩 규모·중복도 보고. `migrate` 가 세이브/팩 버전 승격 적용 | M | D-12-2 |

### 3.8 H. 생성 파이프라인 — M5 (T-127 ~ T-138)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-127** | `content_gen/` 디렉토리 규약과 `runId` 형식을 구현한다 | M5 | — | `content_gen/`(신규) | `runs/<runId>/NN_<stage>/` 구조. 시도 번호 보존 | S | [BP-32 §32.2](32_generation_harness.md) R-32-6~9 |
| **T-128** | Orchestrator 와 `manifest.json` 을 구현한다 | M5 | T-127 | `content_gen/orchestrator/`(신규) | 모델·프롬프트 해시·입력 해시·단계별 시도·승인·메트릭 기록. 재개 가능 | L | [BP-32 §32.7.2](32_generation_harness.md) |
| **T-129** | 1단계 `context` 를 구현한다 | M5 | T-120·T-128·**T-164** | `content_gen/stages/01_context/`(신규) | 컨텍스트 팩이 예산 안. 서버 `context` 엔드포인트 경유 | M | D-14-1 |
| **T-130** | 2단계 `outline` (Planner) 를 구현한다 | M5 | T-129·T-137 | `content_gen/stages/02_outline/`(신규) | `QuestOutline` 스키마 통과. 금지 사항 5종 위반 0 | M | D-14-2 · [BP-32 §32.4.1](32_generation_harness.md) |
| **T-131** | 3단계 `draft` (Writer, 구조→문장 2패스) 를 구현한다 | M5 | T-130 | `content_gen/stages/03_draft/`(신규) | 패스 A 키 집합 == 패스 B 키 집합(양방향 일치). **인라인 한국어 0건** | L | D-14-3 · [BP-32 §32.3](32_generation_harness.md) |
| **T-132** | 4단계 `bind` (Binder) 를 구현한다 | M5 | T-131·T-118·T-124 | `content_gen/stages/04_bind/`(신규) | 모든 `talk_to`/`reach`/`deliver` 목표가 좌표를 갖는 앵커로 해소. 앵커-타일 정합 위반 0 | L | D-14-4 |
| **T-133** | 5단계 `lint` 를 배선한다 | M5 | T-132·T-084 | `content_gen/stages/05_lint/`(신규) | Hard 위반 시 정지. Repair 프롬프트가 **경로 단위 교체값**만 요구 | M | D-14-5 · [BP-32 §32.3](32_generation_harness.md) |
| **T-134** | 6단계 `sim` 을 배선한다 | M5 | T-133·T-097 | `content_gen/stages/06_sim/`(신규) | 솔버 완주 경로 ≥ 1, `chance` **양 분기 모두** 완주, 골든 회귀 0 | M | D-14-6 · R-32-20 |
| **T-135** | 7단계 `critic` 을 구현한다 | M5 | T-134·T-137 | `content_gen/stages/07_critic/`(신규) | `CriticReport.verdict` 가 pass/conditional, 모든 축 ≥ 3. **Critic 은 Hard gate 권한 없음** | M | D-14-7 · R-32-38 |
| **T-136** | 8단계 `commit` 을 구현한다 (맵 ops 적용 + lock 갱신) | M5 | T-135·T-117 | `content_gen/stages/08_commit/`(신규) | `manifest.status == "committed"`. `content.lock.json` 갱신. 커밋·PR 은 사람 또는 워크플로가 함 | M | D-14-8 |
| **T-137** | 프롬프트 6종과 출력 스키마 5종을 작성한다 | M5 | — | `content_gen/prompts/`(신규), `blueprint/37_prompt_contracts.md` | 버전 태그 부착. `QuestOutline`·`QuestDraft`·`DialogueDraft`·`StringsDraft`·`CriticReport` | L | [BP-37](37_prompt_contracts.md) |
| **T-138** | `core` 팩 최소 바이블을 작성한다 (`lore.json`·`places.json`·액터 3인) — **파일럿 선결 P-5** | **M2** | T-070 | `hadar2026_app/assets/content/core/world/`(신규) | `validate` 통과. 1단계 컨텍스트 팩이 비지 않는다 | M | [BP-22](22_world_bible_model.md) · [BP-32](32_generation_harness.md) P-5 |

### 3.9 I. CI·빌드 (M0~M2 분산) (T-139 ~ T-148)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-139** | 계층 grep 에 `dart:io`/`dart:html` 검사를 추가한다 (**T-023 과 같은 PR**) | M0 | **T-023** | `.github/workflows/ci.yml` | `check "... must not import dart:io or dart:html" -E "^import 'dart:(io\|html)'"` 가 green(표 안에서는 파이프를 이스케이프했다. 실제 정규식은 `dart:(io\|html)` 형태의 단순 ERE 이며 **lookahead 는 금지**) | S | **D-23** · 부록 B-4 |
| **T-140** | `exit(` 검사를 추가한다 | M0 | T-023 | `.github/workflows/ci.yml` | `lib/application/`·`lib/domain/` 에 `exit(` 0건 | S | [BP-35 §4.3](35_ci_and_build.md) |
| **T-141** | `DateTime.now()` 금지 grep 을 추가한다 (`lib/domain/`, 콘텐츠 계층) | M0 | T-018 | `.github/workflows/ci.yml` | `save_manager.dart` 의 세이브 메타데이터는 검사 범위 밖 | S | **DT-7** |
| **T-142** | 결정론 grep `V-DET-009`/`V-DET-010` 을 **점등한다** | M2 | T-019·T-020 | `.github/workflows/ci.yml` | `continue-on-error` **없이** green. RP-4 준수 | S | **T-35-3·T-35-6** · R-35-18 |
| **T-143** | CI 에 `content` 잡(순수 Dart)을 신설한다 | M1 | T-068 | `.github/workflows/ci.yml` | `build` 2회 해시 비교(INV-20-02) + `git diff --exit-code`(INV-20-06) | M | **R-20-12** · [BP-35 §4.4](35_ci_and_build.md) |
| **T-144** | CI 에 `determinism` 잡을 신설한다 | M2 | T-093·T-142 | `.github/workflows/ci.yml` | 같은 시드 2회 트레이스 해시 일치 | S | [BP-35 §4.5](35_ci_and_build.md) |
| **T-145** | CI 에 `web_smoke` 잡을 신설한다 | M0 | T-023 | `.github/workflows/ci.yml` | `flutter build web --release` 성공. 2차 방어선(필수 검사는 아님 — R-35-33). **근거의 정정**: 초판은 부록 B-4-2("`dart:io` 때문에 웹 빌드가 깨진다")를 근거로 들었으나 **그 추정은 실빌드로 반증되었다**(부록 B-4 정정본: Flutter 3.41.4, 16.5초, exit 0). 유효한 근거는 **"웹 빌드가 CI 에서 전혀 돌지 않아 회귀 감지 구조가 없다"**(수동 `workflow_dispatch` 뿐)이며, 따라서 이 잡의 성격은 "파손 수리" 가 아니라 **회귀 방지**다 | S | 부록 **B-4(정정본)** · Q-35-3 · RK-09 |
| **T-146** | 골든 3종(산출물·진단·트레이스)과 `--update-golden --reason` 을 구현한다 | M2 | T-093·T-079 | `tools/content_cli/lib/src/trace/golden.dart`(신규), `.github/workflows/ci.yml` | 이유 없는 골든 갱신 거부. "손대지 않은 퀘스트의 골든 파손" 은 **자동 회귀 판정** | M | [BP-35 §6](35_ci_and_build.md) R-35-39 |
| **T-147** | `flutter analyze` baseline 을 만들고 `--no-fatal-infos` 를 제거한다 | M2 | T-070 | `.github/workflows/ci.yml`, `hadar2026_app/analysis_options.yaml` | 기존 77 infos 를 해소하거나 baseline 화. 신규 info 는 실패 | M | [BP-35 §8](35_ci_and_build.md) |
| **T-148** | `dart format` 게이트를 추가하고 포맷 전용 커밋을 `.git-blame-ignore-revs` 에 넣는다 | M2 | T-147 | `.github/workflows/ci.yml`, `.git-blame-ignore-revs`(신규) | `dart format --output=none --set-exit-if-changed lib test` 가 두 패키지에서 green | S | [BP-35 §8](35_ci_and_build.md) · CLAUDE.md |

### 3.10 J. 규모 확대·운영 — M6 (T-149 ~ T-156)

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-149** | GROUND1·DEN1 을 이관한다 (**TOWN2 는 로드 불가이므로 제외 판정 먼저**) | M6 | T-114 | `hadar2026_app/assets/content/core/anchors/`(신규) | shadow diff 가 승인 목록과 일치. TOWN2 는 `MapInfos.json` 미등재·파일 부재로 **이관 대상에서 제외**하거나 맵을 신설. **부록 G-2 근거**: `native_script_runner.dart:25-30` 이 `Town2MapScript` 를 등록하지만 `mapScriptFactory[bundle.mapName]` 조회에 걸릴 수 없어 **한 번도 실행된 적이 없는 코드**다(부록 F-2 와 달리 이쪽은 **이름 자체가 도달 불가**) | L | [BP-28 §9.1](28_migration_and_coexistence.md) 4번 · **부록 G-2** · REVIEW_BP-28 **F-09** |
| **T-150** | Prolog_B1·Prolog_B2(Map010/011, JSON 8·9이벤트)를 이관한다 | M6 | T-113 | `hadar2026_app/assets/content/core/`(신규) | 앵커 + Dialogue 로 1:1 변환. cm2 관여 0 | M | [BP-28 §9.1](28_migration_and_coexistence.md) 5번 |
| **T-151** | MAP003·LORE_EP 를 `frozen` 으로 승격한다 | M6 | T-150 | `hadar2026_app/assets/content/core/anchors/*.json` | `migrated` 2 마일스톤 유지 확인 후 승격. 해당 맵의 cm2 참조 grep **0건** | S | **R-28-9** · [BP-28 §9.3](28_migration_and_coexistence.md) |
| **T-152** | `L1_ep1d*` 7파일과 도달 불가 cm2 5종의 처분을 결정·집행한다 | M6 | T-151 | `hadar2026_app/assets/*.cm2` | Q-28-4 종결. 보존(frozen) 또는 삭제 중 하나가 근거와 함께 기록됨 | S | **Q-28-4** · REVIEW_BP-28 F-01 |
| **T-153** | 아크 1개(퀘스트 3·맵 2)를 생성한다 | M6 | T-136 | `content_gen/orders/`, `hadar2026_app/assets/content/gen_ep1/` | 혼합 배치 전략(R-32-52) 검증. 8기준 통과 | L | [BP-32 §32.11.4](32_generation_harness.md) |
| **T-154** | 배치 10건을 생성한다 | M6 | T-153 | 동일 | 격리·예산 검증. Hard 0 커밋 비율이 지표에 기록 | L | [BP-32 §32.11.4](32_generation_harness.md) |
| **T-155** | 병렬 3 run 과 ID 예약 락을 검증한다 | M6 | T-154 | `content_gen/orchestrator/` | **ID 충돌 0건**. 병렬 상한 3 준수 | M | R-32-56~59 · WS-6-2 |
| **T-156** | 지표 임계를 실측으로 재설정한다 (Q-32-1·Q-32-2·Q-32-6·Q-33-6) | M6 | T-154 | `content_gen/metrics/runs.jsonl`, `blueprint/` 해당 장 | 근거 없는 초기값 4건이 실측값으로 대체됨 | S | [BP-32 §32.10](32_generation_harness.md) · Q-33-6 |

### 3.11 K. 2차 개정 신설분 — D-26 · D-27 · 부록 B-5/G-2/H-1~H-4 대응 (T-157 ~ T-167)

> **번호 규약(R-51-1)** — 기존 156개의 번호는 **재사용하지 않는다.** 신설분은 `T-157` 부터 붙이고
> 구간 배정(§1.1)은 **K 구간 `T-157~167`** 으로 확장한다. 소속 마일스톤은 번호 구간과 무관하게 `M` 열이 정본이다.

#### K-1군: D-26 — 발행 지점 레지스트리와 2축 판정

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-157** | **이벤트 → 발행 지점 레지스트리**를 굽는다 (선언 파일 신설 + `build` 가 `content.index.json#eventPublishers` 생성 + CI 대조 스텝) | M2 | T-051·T-068 | `tools/content_cli/event_publishers.json`(신규), `tools/content_cli/lib/src/build/`(신규 1), `.github/workflows/ci.yml` | D-20 **12종 전량**에 대해 `status`(`published`/`unpublished`)·`sites`·`blockedBy` 가 산출된다. **12종 중 하나라도 선언이 빠지면 빌드 ERROR**(`V-DET-011`). **M2 시점에 `item_gained`·`item_lost`·`enter_place` 3종이 `unpublished` 로 나오는 것을 테스트가 고정**한다(D-20 말미). 선언 파일 해시가 `buildInputHash` 에 포함되고, 선언 ↔ 코드 괴리는 **빌드가 아니라 CI 가** 대조한다(산출물 해시 불변) | M | **D-26** · [BP-35 §1.5.1 R-35-11c~g](35_ci_and_build.md) · RK-39 |
| **T-158** | `QuestSolver` 에 **실행 가능 축**을 추가한다 (경로가 소비하는 이벤트를 레지스트리와 대조) | M2 | T-096·T-157 | `tools/content_cli/lib/src/solver/`(기존 4파일에 1파일 추가) | 판정이 **2축**으로 나온다 — 모델 증명(`PROVEN`/`REFUTED`/`UNKNOWN`) × 실행 가능(`SUPPORTED`/`UNSUPPORTED`). 하나라도 `unpublished` 면 `UNSUPPORTED`. **픽스처 퀘스트가 `PROVEN + UNSUPPORTED` 로 판정되고 그것이 `hadar_content solve` 의 리포트와 종료 코드에 반영됨**을 테스트가 고정한다. 축의 정의·폐기어 대조(`UNREACHABLE`→`REFUTED`, `INCONCLUSIVE`→`UNKNOWN`)는 **[BP-34 §5.1·§5.10](34_headless_sim_and_solver.md) 소유**이며 이 태스크는 그것을 구현만 한다 | M | **D-26** · [BP-34 §5.10 R-34-20](34_headless_sim_and_solver.md) · RK-39 |
| **T-159** | `gates.dart` 가 **`PROVEN + UNSUPPORTED` 팩을 "미활성" 으로 표시하고 릴리스에서 차단**하게 한다 | M2 | T-084·T-158 | `tools/content_cli/lib/src/gates.dart`(T-084 이 만든 파일), `.github/workflows/ci.yml` | **커밋은 허용**되고(마일스톤 진행 중 미리 만들어 두는 것을 막지 않는다) 팩이 `미활성` 으로 표시되며, **릴리스 태그 빌드에서는 실패**한다. 릴리스 로그에 `UNSUPPORTED` 퀘스트 목록과 각각의 `blockedBy` 가 표로 남는다. 게이트의 층위·수치 정의는 **[BP-53](53_acceptance_criteria.md) H-13·N-74 소유**(D-26 이 게이트 반영을 BP-53 에 지정), 릴리스 잡 구성은 [BP-35 R-35-33b/c](35_ci_and_build.md) 소유 | S | **D-26** · [BP-53](53_acceptance_criteria.md) · RK-39 |

#### K-2군: 부록 H — 장비가 전투에 반영되게 만드는 선행 과제

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-160** | **[선택 · 1차 스코프 밖]** 전투식을 바꾼다 — 방패를 별개 축으로 두거나 부위별 감쇠·속성 상성을 도입할 때만 필요하다. `ac` 합산만으로 가는 1차 스코프에서는 **불필요**하다(부록 H-1 정정판). 방어 계산이 장비에서 온 `ac` 를 읽게 하고, `powOfArmor`/`powOfShield` 에 폐기 예정 주석을 단다 | M3 | T-102 | `hadar2026_app/lib/application/battle.dart`, `hadar2026_app/lib/domain/party/player.dart` | `battle.dart:513-514` 의 피해 감소 항이 **장비 합산 `ac`(R-42-30)를 반영**하고, 방어구/방패 교체가 피해량을 바꾸는 것을 단위 테스트가 고정한다. `player.dart` 의 `powOfArmor`/`powOfShield` 선언 옆에 `// deprecated: 어떤 전투 규칙도 읽지 않음 (BP-42 §1.3)` 주석이 붙는다(R-42-32 = 원출처 **T-42-2**). **`powOfWeapon` 은 폐기 대상이 아니다** — `battle.dart:439` 가 읽는 살아 있는 필드다. 골든 diff 는 `approvedDeltas` 에 **의도된 동작 변경**으로 등재 | M | **부록 H-1** · [BP-42 R-42-29~33](42_item_and_inventory.md) · **T-42-2** · RK-40 |
| **T-161** | `books.json` 을 레거시로 옮기고 **id ↔ `HDPlayer.weapon` 정수 매핑표**를 산출한다 | M3 | T-099 | `hadar2026_app/assets/maps/books.json` → `hadar2026_app/assets/_legacy/books.json`(이동), `hadar2026_app/lib/application/save_manager.dart` | 매핑표가 **파일로 산출**되고(정수 → `item.core.*` id), v1 세이브의 정수 장비가 그 표를 통해서만 해석된다. **근거(부록 H-3)**: `books.json` 의 `weapon[].id` 는 1부터 시작하는 자체 번호이고 `HDPlayer.weapon` 은 `getWeaponName()` 에서만 쓰이는 별개 정수다 — 두 공간을 같다고 가정한 코드 주석이 있으나 **근거가 없다.** 이동 후 `assets/maps/` 참조 grep 0건 | S | **부록 H-3** · **T-42-5** · RK-40 |

#### K-3군: D-27 — 앵커는 타일 비트에 의존하지 않는다

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-165** | 앵커 발화가 **타일 비트와 무관**함을 테스트로 고정한다 (region 무관 · step-on 포함) | M1 | T-059 | `hadar2026_app/test/application/content_tier_test.dart`(신규) | ① 같은 앵커를 `region` 값이 `0`/`64`/`128`/**`255`** 인 칸에 두어도 발화 결과가 **동일**하다. ② **`step_on` 앵커가 타일 액션(`HDTileAction`)이 없는 칸에서도 발화**한다. ③ 앵커 kind ↔ 권장 타일 정합 위반이 **빌드 실패가 아니라 WARN** 임을 린트 테스트가 확인한다. ④ **진입점 3개의 동작이 일치한다**(부록 **K**) — 같은 앵커를 step-on(`player_sprite.dart:193`) · bump(`:359-366`) · 확인키(`:405`) 로 접근해도 같게 발화한다. **K-1 에 따르면 3개 중 2개는 선검사가 없어 코드 변경 없이 성립하므로, 이 단언은 T-167 이 bump 게이트를 제거했는지의 검증이 된다.** **근거(부록 J-1)**: `map_loader.dart:44` 가 region(0~255)을 `ixEvent` **하위 바이트**에 넣는데 `tile_properties.dart:186-187` 은 **상위 바이트**(`& 0x00FF0000`)만 보므로 `200 & 0x00FF0000 == 0` — **어떤 region 값도 타일 액션을 만들지 못한다.** 부록 **I-1**(Map001 (2,3) region=255)은 예약을 하지 않으므로 **정리 대상이 아니며**, I-1 자신이 그 맵을 "타일 액션 경계를 훑는 테스트 픽스처" 로 보고 정리를 경고했다 — 오히려 **이 테스트의 입력 픽스처로 쓴다** | S | **D-27 · 부록 J-1·J-3·I-1** · [BP-26 R-26-5a](26_entity_registry_and_anchors.md) · RK-26 |

#### K-4군: 부록 B-5 — 번들 기준선, 그리고 흘러온 타 장 태스크

| ID | 제목 | M | 선행 | 대상 파일 | 완료 조건 | 규모 | 근거 |
|---|---|---|---|---|---|---|---|
| **T-167** | **bump 경로의 presentation 게이트를 제거한다** — `if (action.isInteractive)` 보다 콘텐츠 조회를 앞세운다 | M1 | T-059 | `hadar2026_app/lib/presentation/panels/player_sprite.dart` | 같은 앵커가 **step-on · bump · 확인키 3경로 전부**에서 같게 발화한다(T-165 ④가 단언). **근거(부록 K-2)**: `:359-366` 의 `if (action.isInteractive)` 는 **presentation 계층이 콘텐츠 발화 여부를 결정하는 유일한 지점**이고, 이대로면 벽을 향해 걸어 부딪힐 때는 통행 불가 타일 위의 앵커만 잡히고 확인키로는 잡힌다 — **같은 앵커가 조작 방식에 따라 다르게 동작한다.** 변경 규모는 **1줄 수준**이다(BP-27 `Q-27-10` 이 등록). **주의**: T-087(M2)이 이 파일을 재작성할 때 이 규약을 유지해야 한다 | S | **부록 K-2 · D-27** · [BP-27](27_runtime_engine.md) Q-27-10 · RK-26 |
| **T-166** | **웹 산출물 크기 기준선을 실측·기록**하고 "소스 팩을 싣지 않는" 선택의 이득을 판정한다 | M1 | T-069 | `hadar2026_app/tool/measure_web_payload.sh`(신규), `blueprint/` 기록 | `flutter build web --release` 산출물을 구성별로 집계한 표가 산출된다. **기준선은 부록 B-5 의 45MB**(canvaskit **31MB** · 게임 자산 **9.7MB** · NOTICES 1.3MB · 나머지 ~3MB). 판정 명제: **소스 팩을 제외해 줄어드는 양이 게임 자산 9.7MB 대비 몇 % 인가.** B-5 는 "소스가 수 MB 가 아니라면 이득이 작다" 고 명시했으므로, 이득이 작다면 [BP-53](53_acceptance_criteria.md) HC-7 을 하드로 유지할지 여부를 Q-53-7 로 되돌린다. **canvaskit 31MB 는 콘텐츠와 무관**하므로 최적화 표면에서 제외한다 | S | **부록 B-5** · [BP-53](53_acceptance_criteria.md) N-59~N-63 · RK-30 |
| **T-162** | `tools/mapEditor` 에 `pnpm test`(vitest)를 신설하고 CI 잡에 넣는다 | M2 | T-034 | `tools/mapEditor/package.json`, `tools/mapEditor/vitest.config.ts`(신규), `tools/mapEditor/server/*.test.ts`(신규), `.github/workflows/ci.yml` | 최소 세트가 green: 통행/액션 계산 · `MapInfos.json` 왕복 · 배치 편집 ops. **원출처 T-36-3** 이 흘렸으나 [BP-35](35_ci_and_build.md) 의 CI 잡 목록에도 없어 **두 장이 함께 놓쳤다** | M | **T-36-3** · RK-27 |
| **T-163** | `tools/mapEditor` 의 3-way merge 착수 여부를 판정한다 | M6 | T-124 | `tools/mapEditor/server/store.ts`, `blueprint/` 결정 기록 | 판정 근거가 기록된다 — 앵커가 **별도 파일**이므로(D-09·D-27) 맵 JSON 충돌면이 줄어들고, T-36-4 자신이 "그렇다면 우선순위가 오히려 내려가는가" 를 열어 두었다. **착수/보류 중 하나를 근거와 함께 확정**한다 | S | **T-36-4** · Q-36-3 · RK-27 |
| **T-164** | **M5 착수 전 파일럿 선결 P-1~P-7 점검 게이트** | M5 | T-004·T-005(P-1) · T-068·T-084(P-2) · T-039·T-041(P-3) · T-096(P-4) · T-138(P-5) · **T-101(P-6)** · **T-105(P-7)** · T-159 | `hadar2026_app/test/` 또는 `content_gen/orchestrator/`(선행 점검 스크립트, 신규) | P-1~P-7 **7항목 전부**가 각자의 완료 확인 게이트를 통과했음을 스크립트가 확인하고, 하나라도 미통과면 **8단계 실행기가 착수를 거부**한다. **이 태스크의 존재 이유**: [BP-50 R-50-1](50_roadmap.md) 이 "P-1~P-7 이 전부 끝나기 전에 파일럿을 시작하지 않는다" 를 강하게 선언했는데 **초판의 태스크 그래프는 그것을 막지 않았다** — T-129 의 선행이 `T-120·T-128` 뿐이어서 **저널·인벤토리 없이 파일럿을 시작할 수 있었다.** 규칙을 문서에만 두지 않고 그래프로 강제한다 | S | **[BP-50 R-50-1](50_roadmap.md)** · [BP-50 §7.4](50_roadmap.md) 동기화 지점 ④ · RK-28 |

---

## 4. 태스크 의존 그래프와 임계 경로

### 4.1 임계 경로 (Critical Path) — **§3 의 `선행` 열에서 기계로 산출**

> **초판의 오류와 그 정정** — 초판 §4.1 은 "임계 경로 24 태스크" 를 선언했으나 **그 사슬은 §3 의 `선행` 열에서
> 도출되지 않았다.** 선언된 24연쇄의 간선 23개 중 **9개가 실제 선행 관계에 존재하지 않았다** —
> `T-034→T-063`(T-063 선행은 T-046·T-008) · `T-064→T-066`(T-066 선행은 T-063) · `T-070→T-096`(T-096 선행은 T-058) ·
> `T-097→T-084`(T-084 선행은 T-071~T-077) · `T-084→T-100`(T-100 선행은 T-099·T-046) ·
> `T-101→T-105`(T-105 선행은 T-104) · `T-105→T-120`(T-120 선행은 T-116) ·
> `T-129→T-131`(T-131 선행은 T-130) · `T-132→T-136`(T-136 선행은 T-135·T-117).
> 즉 초판의 사슬은 임계 경로가 아니라 **마일스톤 서술 순서**였고, 그 위에서 계산된 §4.2 의 단축 수치도 근거가 없었다.
>
> **산출 방법(재현 가능)** — §3 의 167행에서 `선행` 열을 파싱해 방향 그래프를 만들고
> (범위 표기 `T-005~T-033` 은 그 구간 전체로 전개, dangling 참조 **0건**), **최장 경로를 DP 로 계산**한다.
> 이번 개정에서 추가된 간선은 셋이다 — **T-059 ← T-061**(D-19 순서 역전 교정),
> **T-129 ← T-164**(R-50-1 선결 강제), 그리고 신설 태스크 T-157~T-167 의 선행.

**결과**

| 종점 | 최장 사슬 길이 | 의미 |
|---|---:|---|
| **T-136**(8단계 commit = **M5 파일럿 성공**) | **24 태스크** | R-51-5 가 확정하는 값 |
| **T-155**(병렬 3 run = M6 종료) | **27 태스크** | 계획 전체의 최장 사슬 |
| T-034(M0 종료) | 10 | M0 는 깊이가 얕고 폭이 넓다 |
| T-070(M1 종료) | 14 | 콘텐츠 코어 내부 사슬이 지배적 |
| T-159(D-26 게이트 배선) | 15 | 신설분은 임계 경로 위에 **없다** |

**T-136 까지의 실제 최장 사슬 (24)**

```
T-035 → T-036 → T-037 → T-046 → T-047 → T-041 → T-050 → T-055 → T-056 → T-057
  → T-060 → T-061 → T-059 → T-070
  → T-138 → T-164
  → T-129 → T-130 → T-131 → T-132 → T-133 → T-134 → T-135 → T-136
```

> **결과에서 나온 사실 하나** — 최장 경로가 **M0 를 지나가지 않는다.** M0 의 최장 사슬은 10(T-001…T-034)인데
> M1 콘텐츠 코어의 내부 사슬이 14 로 더 길기 때문이다. 이것은 **CP-1(`domain/content/` 를 M0 와 병렬 착수)을
> 전제한 그래프**에서만 참이다 — T-035 의 선행이 `—` 이므로 그래프가 병렬을 허용한다.
> 병렬을 포기하면(T-035 ← T-034) 최장 경로는 **34**(T-136 종점) / **37**(T-155 종점)이 된다.
> **즉 CP-1 의 실제 이득은 −10 이다**(§4.2).

**T-155 까지의 최장 사슬 (27)** — 위 24연쇄에 `T-153 → T-154 → T-155` 가 이어진다.

| 구간 | 태스크 수 | 왜 직렬인가 |
|---|---:|---|
| 배치 결정 → 모델 → `WorldState`/`View` (T-035~T-047) | 5 | Q-20-1 결론이 경로를 정하고, View/Mutator 분리가 평가기의 입력 |
| 효과 → 이벤트 버스 → 퀘스트 런타임 → 콘텐츠 런타임 (T-041~T-056) | 4 | EV-1(큐에 넣기만 한다) → 드레인 → 목표 판정 → `handleTile` |
| 브리지 → `pendingNavigation` 승격 → `autoFlush` → **티어 0** (T-057~T-059) | 4 | **D-19 가 못박은 순서.** 티어 0 이 마지막이다 |
| M1 종료 → `core` 팩 → **선결 점검** (T-070·T-138·T-164) | 3 | R-50-1 을 그래프로 강제한 결과 |
| 1→2→3→4→5→6→7→8단계 (T-129~T-136) | 8 | D-14: "실패는 그 단계에서 멈추고 다음으로 넘어가지 않는다" |

```mermaid
graph LR
  T035["T-035 Q-20-1 결정"] --> T036["T-036 콘텐츠 패키지"] --> T037["T-037 content_ids"]
  T037 --> T046["T-046 WorldState"] --> T047["T-047 View/Mutator"] --> T041["T-041 Effect 적용기"]
  T041 --> T050["T-050 이벤트 버스"] --> T055["T-055 quest_runtime"] --> T056["T-056 content_runtime"]
  T056 --> T057["T-057 HDEffectBridge"] --> T060["T-060 pendingNavigation 승격"]
  T060 --> T061["T-061 autoFlush 술어"] --> T059["T-059 티어 0 삽입<br/>(D-19 순서)"]
  T059 --> T070["T-070 M1 종료"] --> T138["T-138 core 팩"] --> T164["T-164 P-1~P-7 점검"]
  T164 --> T129["T-129 1단계"] --> T130["T-130 2단계"] --> T131["T-131 3단계"] --> T132["T-132 4단계"]
  T132 --> T133["T-133 5단계"] --> T134["T-134 6단계"] --> T135["T-135 7단계"] --> T136["T-136 8단계 commit"]
  T136 --> T153["T-153 아크 1개"] --> T154["T-154 배치 10건"] --> T155["T-155 병렬 3 run"]
```

**M0 사슬은 임계 경로가 아니지만 여전히 모든 것의 전제다** —
`T-001 → T-002 → T-004 → T-005 → T-006 → T-007 → T-008 → T-015 → T-016 → T-034`(10).
길이가 짧다는 것은 "빨리 끝난다" 가 아니라 **"폭이 넓다"** 는 뜻이며, M0 태스크 38개 중 30개가 S 인 것과
같은 사실의 다른 표현이다(§6.2). 그리고 **`T-002` 는 여전히 `T-004` 보다 먼저여야 한다**(R-51-7 · WS-0-1) —
임계 경로에서 벗어났다는 사실이 그 순서 규칙을 완화하지 않는다.


### 4.2 임계 경로를 줄이는 방법 5가지 — **전부 그래프로 재계산**

각 항목의 "줄어드는 길이" 는 **해당 가정만 뒤집은 그래프의 최장 경로 차이**다.
기준값은 §4.1 의 **T-136 종점 24 / T-155 종점 27** 이다. 근거 없는 추정치를 쓰지 않는다.

| # | 방법 | 줄어드는 길이 (T-136 / T-155) | 산출 방식 | 대가·조건 |
|---|---|---|---|---|
| **CP-1** | **`domain/content/`(T-035~T-058)를 M0 와 완전 병렬로 착수한다** | **−10 / −10** (34→24, 37→27) | `T-035 ← T-034` 간선을 넣은 그래프와의 차이 | 기존 코드와 파일이 겹치지 않으므로 대가 없음. 다인 개발의 **T-B 트랙**([BP-50 §7.4](50_roadmap.md)). **가장 효과가 크고 위험이 없는 단축이며, §4.1 의 그래프는 이미 이것을 전제한다** |
| **CP-2** | 솔버(T-096)를 이동 추출(T-086)보다 먼저 만든다 — 이미 반영됨 | **−4 / −4** (28→24, 31→27) | `T-096 ← T-093` 간선을 넣은 그래프와의 차이 | 초판의 "−5" 는 근거가 없었다. 또한 **이득의 성격이 다르다** — [BP-34 §2.5](34_headless_sim_and_solver.md) 의 "반례 재생(solve → sim)" 행은 Phase 2 에서만 ✅ 이므로 **G2-2 의 witness 재생은 여전히 이동 추출을 요구**한다. 즉 얻는 것은 **솔버 착수의 병렬화**이고, 위 −4 는 "솔버를 sim 뒤로 미뤘을 때 늘어나는 양" 이다. 대신 F-1(물리적 도달 불가)은 M2 후반까지 못 잡는다 |
| **CP-3** | 인벤토리·저널(T-099~T-108)을 M2 와 병렬로 착수한다 — 이미 반영됨 | **−2 / −2** (26→24, 29→27) | `T-099 ← T-084` 간선을 넣은 그래프와의 차이 | T-100 이 `WorldState`(T-046)에만 의존하므로 M2 전체를 기다릴 필요가 없다. 단 G3-2(시뮬 확인)는 M2 완료 후로 미뤄지고, **부록 H-1 의 순서(T-160 전투식 → 인벤토리 UI)는 지켜야 한다**([BP-50 R-50-16](50_roadmap.md)) |
| **CP-4** | 파일럿 무대를 `TOWN1` → 이벤트 0개인 `Map013~015` 로 바꾼다 | **−0 / −0** | T-114 는 최장 경로 위에 **없다**(T-114 종점 사슬 19) | 초판의 "−2" 는 근거가 없었다. **임계 경로는 줄지 않는다.** 줄어드는 것은 T-113→T-114 이관 사슬의 위험이며, 그 대가로 [BP-32 §32.11.1](32_generation_harness.md) 이 TOWN1 을 고른 근거(바이블 예시·좌표 실측)를 잃는다. **[BP-50](50_roadmap.md) Q-50-4 로 열어 둠** |
| **CP-5** | 골든 채취(T-002)를 16개 맵으로 쪼개 병렬화한다 | **−0 / −0** (벽시계만 단축) | 태스크 수 불변 | T-002 는 애초에 최장 경로 위에 없다. 1인 개발에서는 효과 없음 |

> **줄일 수 없는 것** — `T-004 → T-005 → T-006 → T-007 → T-008` 5연쇄와
> `T-129 → T-130 → T-131 → T-132 → T-133 → T-134 → T-135 → T-136` 8연쇄,
> 그리고 **`T-057 → T-060 → T-061 → T-059` 4연쇄**(D-19 가 못박은 순서)는 **본질적 직렬**이다.
> 첫째는 하나의 데이터 해석 규칙이 단계적으로 정직해지는 과정이고,
> 둘째는 D-14 가 "실패는 그 단계에서 멈추고 다음으로 넘어가지 않는다" 로 못 박은 파이프라인이며,
> 셋째는 "티어 0 을 먼저 넣으면 콘텐츠 티어의 맵 이동이 narrative 를 잘못 flush 한다" 는 D-19 의 결론이다.

### 4.3 착수 가능 태스크 (선행 `—`)

즉시 시작할 수 있는 태스크는 **11개**다: T-001 · T-017 · T-022 · T-028 · T-029 · T-031 · T-032 · T-033 · T-035 · T-127 · T-137.
(신설 태스크 T-157~T-167 은 전부 선행이 있으므로 이 목록은 개정 후에도 11개다.)
이 중 T-127·T-137 은 M5 소속이지만 선행이 없어 **유휴 시간의 대피처**로 쓸 수 있다([BP-50 §7.3](50_roadmap.md)).

> **주의 — "즉시 착수 가능" 은 "파일럿을 시작할 수 있다" 가 아니다.** T-127(디렉토리 규약)·T-137(프롬프트 6종)은
> M5 소속이지만 **파일럿 실행 자체는 T-164 가 막는다.** T-164 는 P-1~P-7 **7항목 전부**의 완료를 요구하며,
> T-129(1단계 context)의 선행이 되었다. 초판 그래프에서는 T-129 선행이 `T-120·T-128` 뿐이라
> **저널·인벤토리 없이 파일럿을 시작할 수 있었고**, 그것은 [BP-50 R-50-1](50_roadmap.md) 이
> "성공 기준 7번에서 **반드시 실패**한다" 고 경고한 상태였다.

---

## 5. 첫 10개 태스크 — 지금 당장 시작할 수 있는 것

각 항목은 **무엇을 열고 / 무엇을 하고 / 무엇을 확인하면 끝인지**를 명시한다.

| # | 태스크 | 무엇을 여는가 | 무엇을 하는가 | 무엇을 확인하면 끝인가 |
|---|---|---|---|---|
| **1** | **T-001** `RecordingUiHost` | `hadar2026_app/lib/application/ports/ui_host.dart` 로 11개 메서드 시그니처 확인 → `test/harness/recording_ui_host.dart` 신규 | 11개 메서드를 전부 구현해 **호출 이름·인자·순서**를 JSONL 로 기록. `showMenu`/`showWindowMenu` 는 고정 선택값 반환 | `flutter test` 로 임의 대화 1개를 돌려 JSONL 이 나오고, **2회 실행 결과가 동일**하다 |
| **2** | **T-017** `WorldRng` | `hadar2026_app/lib/domain/` 아래 신규 `content/world_rng.dart` | `splitmix64` 계열 무상태 함수로 `(seed, cursor) → int` 구현. `nextInt(maxExclusive)` 사전/사후조건 명시 | 단위 테스트에서 같은 `(seed, cursor)` 가 **항상 같은 값**, 분포가 균등, `maxExclusive <= 0` 이 assert |
| **3** | **T-022** `UiHost` 종료 요청 | `hadar2026_app/lib/application/ports/ui_host.dart` | 종료 요청 메서드 1개 추가([BP-27](27_runtime_engine.md) 확정 시그니처). `HDFlutterUiHost`·`HDGameMain` 에 스텁 구현 | `flutter analyze` 통과 + 기존 테스트 9개 green (아직 `exit(0)` 는 남아 있어도 됨) |
| **4** | **T-023 + T-139** `dart:io` 제거와 CI 검사 | `hadar2026_app/lib/application/menu_flows.dart:2,504,522,540` 과 `.github/workflows/ci.yml` | `import 'dart:io'` 삭제, `exit(0)` 3곳을 T-022 의 메서드 호출로, `kIsWeb` 분기 삭제. **같은 PR 에서** ci.yml `check()` 에 `-E "^import 'dart:(io\|html)'"` 추가(표 안에서만 이스케이프) | ① `grep -rn "dart:io" lib/application/ lib/domain/` **빈 결과** ② CI 신규 검사 green ③ `flutter build web --release` 성공 — **이것은 회귀 확인이다.** 부록 B-4 정정본이 현재 성공을 실측했으므로 "고쳐서 통과시키는" 대상이 아니다 (**D-23 이 요구한 한 묶음**) |
| **5** | **T-028** 적 등록 가드 | `hadar2026_app/lib/application/battle.dart:43-46`, `lib/domain/battle/enemy_data.dart:33` | `<= 0` 가드에 경고 로그 추가. 유효 범위를 상수(`1..74`)로 노출 | `registerEnemy(0)` 호출이 경고를 남기고, 상수가 `enemyTable.length` 와 일치함을 테스트가 단언 |
| **6** | **T-029** 침묵 실패 로깅 | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:362-391` | `Flag::Set`/`Flag::Reset`/`Variable::Set`/`Variable::Add` 4곳의 범위 검사에 `else` 분기와 경고를 추가 | `Flag::Set(300)` 이 담긴 cm2 를 돌렸을 때 경고가 나오고, 정상 범위 동작은 **골든 diff 0** |
| **7** | **T-033** 플래그 스텁 진단 | `hadar2026_app/lib/application/scripting/map_script.dart:41-48` | 현재 동작(`isFlagSet` 이 항상 `false`)을 **단언하는** 테스트를 쓴다. 고치지 않는다 | 테스트가 green. 이 테스트는 T-111 에서 **의도적으로 뒤집힐 것**임을 주석에 명시 |
| **8** | **T-031 + T-032** 문서 정정 2건 | `blueprint/12_reference_designs.md`, `blueprint/92_appendix_reference_index.md`, `blueprint/11_gap_analysis.md` | ① "code 101 = 텍스트 헤더" 서술 3곳 제거·정정 ② "cm2 는 튜링 완전" 논거를 §9 실측 근거로 대체 | `grep -rn "튜링 완전\|101.*헤더" blueprint/` 가 정정된 문맥에서만 나온다. **D-02 결정 자체는 유지**됨을 확인 |
| **9** | **T-035** Q-20-1 결정 | `blueprint/20_target_architecture.md` Q-20-1, [BP-34 R-34-6](34_headless_sim_and_solver.md), `hadar2026_app/pubspec.yaml`, `packages/cm2_script/pubspec.yaml`(선례) | 3안(물리 분리 `packages/hadar_content` / pub workspace / 복사)을 **실제로 시험 빌드**해 비교. `packages/cm2_script` 가 이미 로컬 path dep 선례임을 활용 | 선택안으로 빈 패키지를 만들어 `dart analyze`(Flutter 없이)와 `flutter test`(앱에서 import) **둘 다** 통과. 결정과 근거가 문서화됨 |
| **10** | **T-002** 선행 골든 채취 | T-001 산출물 + `hadar2026_app/assets/maps/MapInfos.json` 15엔트리 + `ORIGIN` | 16개 맵 각각에 대해 **대표 상호작용 좌표 몇 곳**을 훑는 시나리오를 짜고 `UiHost` 호출 시퀀스를 골든으로 커밋 | 16개 골든 파일 커밋 + 2회 실행 동일 + **이 시점 이후 어떤 M0 동작 변경도 이 골든과 대조된다**(WS-0-1) |

> **순서에 관한 경고** — 4번(T-023+T-139)과 9번(T-035)은 다른 것들과 독립이지만,
> **10번(T-002)은 반드시 T-004 이전에 끝나야 한다.** 맵 이름 해석을 먼저 고치면 기준선이 무효가 된다(RP-3 · WS-0-1).
> 1~9 번을 먼저 하더라도 **T-004 를 건드리는 순간부터는 골든이 있어야 한다.**

---

## 6. 규모 합계

### 6.1 마일스톤별 S/M/L 분포

| M | 태스크 수 | S | M | L | 상대 총량(S=1, M=3, L=7) | 신설분 |
|---|---:|---:|---:|---:|---:|---|
| **M0** | 38 | 30 | 8 | 0 | 54 | — |
| **M1** | **40** | 13 | 22 | 5 | **114** | T-165 · T-166 · T-167 |
| **M2** | **38** | 10 | 21 | 7 | **122** | T-157 · T-158 · T-159 · T-162 |
| **M3** | **18** | 6 | 9 | 3 | **54** | T-160 · T-161 |
| **M4** | 12 | 1 | 9 | 2 | 42 | — |
| **M5** | **12** | 2 | 6 | 4 | **48** | T-164 |
| **M6** | **9** | 4 | 2 | 3 | **31** | T-163 |
| **합계** | **167** | **66** | **77** | **24** | **465** | **11** |

> **집계 주의** — 태스크 수는 **§3 의 `M` 열 기준**이며 번호 구간과 일치하지 않는다.
> 구간과 다른 마일스톤에 계상된 것은 5건이다: `T-138`(H 구간 → **M2**), `T-139`·`T-140`·`T-141`·`T-145`(I 구간 → **M0**).
> 신설 K 구간(`T-157~167`)도 소속이 흩어진다 — M1 **3** · M2 4 · M3 2 · M5 1 · M6 1.
> 번호 총수와 태스크 총수는 둘 다 **167** 으로 같다(결번 0 · 중복 0).
> 검산: `66×1 + 77×3 + 24×7 = 66 + 231 + 168 = 465`.

### 6.2 읽는 법

| 관찰 | 함의 |
|---|---|
| **M0 는 태스크 수가 가장 많은데(38) L 이 하나도 없다** | 30개가 S 다. "많은 작은 수정" 이며, 개별 난이도가 아니라 **순서와 골든 대조**가 어려움의 본체다. 이것이 M0 를 1번에 두는 비용이 생각보다 낮은 이유다 |
| **M2 의 총량이 가장 크다(122)** | 린트 규칙 구현의 L 3개(T-071·T-072·T-074)와 하네스·솔버의 L 4개(T-086·T-093·T-094·T-096)가 몰려 있고, D-26 신설분 3개가 더해졌다. [BP-50 §7.3](50_roadmap.md) 이 1인 개발에서 **Hard gate 대응 규칙만 먼저** 만들라고 한 이유 |
| **M1(114)과 M2(122)는 사실상 같은 규모로 읽어야 한다** | 가중치 `S=1,M=3,L=7` 이 **근거 없는 관행값**(Q-51-5)이므로 **9 차이는 유의미하지 않다.** 초판이 "112 vs 111" 을 1·2위로 서술한 것은 관행값에 없는 해상도를 부여한 것이었다. 두 구간의 성격 차이가 더 중요하다 — 콘텐츠 코어는 신규 코드라 L 이 많지만 **기존 코드와 충돌이 없어** 병렬화가 잘 된다(CP-1: −10) |
| **L 태스크 24개 중 12개가 M1·M2 에 있다**(신설분에 L 은 0개다) | 위험이 앞쪽에 몰려 있다. 이는 의도적이다 — **판정 수단이 뒤에 있으면 앞의 실수를 늦게 안다**(RP-1) |
| **M6 는 태스크 8개인데 L 이 3개** | 이관과 배치 생성은 개수가 적어도 각각이 무겁다 |

### 6.3 왜 사람-시간이 없는가

[BP-50 §2.9](50_roadmap.md) 와 같은 이유다 — 근거가 없다. 상대 총량(`S=1, M=3, L=7`)은
**마일스톤 간 비교**에만 쓰고 절대 일정으로 환산하지 말 것. 가중치 자체도 근거 없는 관행값이며,
[BP-32](32_generation_harness.md) 의 `metrics/runs.jsonl` 이 실측을 쌓은 뒤 재설정 대상이다.

---

## 7. 원출처 대응표

각 장이 흘려 놓은 태스크 ID 가 본 장의 어느 통합 번호가 되었는가.

| 원출처 ID | 출처 | 통합 번호 |
|---|---|---|
| `T-22-1` | [BP-22](22_world_bible_model.md) · [BP-40](40_gameplay_changes.md) 선결 과제 | **T-004 · T-005** |
| `T-28-0` | [BP-28 §2.5](28_migration_and_coexistence.md) | **T-001 · T-002 · T-003** |
| `T-28-1` | [BP-28](28_migration_and_coexistence.md) | **T-010** |
| `T-28-2` | [BP-28](28_migration_and_coexistence.md) | **T-004 · T-005 · T-006 · T-011** |
| `T-28-3` | [BP-28](28_migration_and_coexistence.md) | **T-008** |
| `T-28-4 · T-28-5 · T-28-6` | [BP-28 §6.2](28_migration_and_coexistence.md) | **T-112** |
| `T-28-7` | [BP-28 §6.3](28_migration_and_coexistence.md) | **T-111** |
| `T-28-8` | [BP-28](28_migration_and_coexistence.md) (D-19) | **T-060 · T-061** |
| `T-28-9` | [BP-28 §5.1](28_migration_and_coexistence.md) | **T-030** |
| `T-34-1 ~ T-34-6` | [BP-34 §2.6](34_headless_sim_and_solver.md) | **T-086 · T-087 · T-088 · T-085 · T-089 · T-090** |
| `T-34-7` | [BP-34 §2.3](34_headless_sim_and_solver.md) | **T-022 · T-023 · T-024** |
| `T-34-8` | [BP-34 §2.6](34_headless_sim_and_solver.md) | **T-139** |
| `T-35-1 ~ T-35-4` | [BP-35 §2.4](35_ci_and_build.md) | **T-018 · T-019 · T-142 · T-021** |
| `T-35-5 · T-35-6` | [BP-35 §4.3](35_ci_and_build.md) | **T-023 · T-142** |
| `DT-1 ~ DT-7` | [BP-27 §9.3](27_runtime_engine.md) | **T-018 · T-019 · T-020 · T-046 · T-052 · T-068 · T-141** |
| `T-25-01 ~ T-25-27` (테스트) | [BP-25 §10](25_world_state_and_save.md) | **T-058**(도메인) · **T-070**(세이브) |
| `T-27-01 ~ T-27-31` (테스트) | [BP-27 §10](27_runtime_engine.md) | **T-058** · **T-070** · T-021 |
| `T-33-A ~ T-33-F` | [BP-33 §9](33_validation_and_lint.md) | **T-083** |
| `P-1 ~ P-5` (파일럿 선결) | [BP-32 §32.11.2](32_generation_harness.md) | **T-004/T-005 · T-068/T-084 · T-039/T-041 · T-096 · T-138** |
| `P-6 · P-7` (본 기획 추가) | [BP-50 §5.2](50_roadmap.md) | **T-100/T-101 · T-105** (선결 점검은 **T-164**) |
| `T-42-1` | [BP-42 §11](42_item_and_inventory.md) | **T-102** |
| `T-42-2` | 동상 (R-42-32 폐기 예정 주석) | **T-160**(신설) |
| `T-42-3` | 동상 (메뉴 7번 항목) | **T-107** · T-103 |
| `T-42-4` | 동상 (`items.json` 20종 + `strings/ko.json` 40개) | **T-099**(카탈로그) · T-138(문자열 배선) |
| `T-42-5` | 동상 (`books.json` → `assets/_legacy/`) | **T-161**(신설) |
| `T-42-6` | 동상 (`giveItem`/`takeItem` 규칙 단위 테스트 — 스택 상한·**48종 상한**·EQ-2 해제 순서·이벤트 미발행 조건) | **T-100** |
| `T-36-1` | [BP-36 §…](36_map_editor_extension.md) (`Map001.json` region 255 → 0 정리) | **흡수하지 않는다 — D-27 로 폐기.** region 예약을 하지 않으므로 충돌이 없고, 부록 I-1 자신이 그 맵을 "타일 액션 경계를 훑는 테스트 픽스처" 로 보아 정리를 경고했다. 대신 **T-165 의 입력 픽스처**로 쓴다 |
| `T-36-2` | 동상 (MCP 커버리지 구멍 2개) | **T-123** |
| `T-36-3` | 동상 (`pnpm test`/vitest 신설) | **T-162**(신설) |
| `T-36-4` | 동상 (3-way merge 착수 후보) | **T-163**(신설) |

> **초판이 두 장을 통째로 빠뜨렸다** — `T-42-1~6`(`42_item_and_inventory.md:858-863`)과
> `T-36-1~4`(`36_map_editor_extension.md:395, 563, 775, 810`)가 §7 대응표에 없었다.
> §7 의 존재 이유가 "각 장이 흘려 놓은 태스크를 통합한다" 이므로 이것은 완결성 결함이었고,
> 그중 **T-42-2·T-42-5 는 부록 H-1·H-3 과 직결**된다. 이번 개정에서 미흡수 6건에 통합 번호를 부여했고
> 1건(T-36-1)은 **폐기 근거를 기록**했다.

### 7.1 검수 보고서가 남긴 미해결 결함 → 태스크

검수 보고서 12건이 지적한 결함 중 **문서 수정이 아니라 코드·설계 작업을 요구하는 것**만 추린다.
(문서 문장 수정은 해당 장의 제작 에이전트 소관이며 본 장의 태스크가 아니다.)

| 검수 결함 | 요구 작업 | 태스크 |
|---|---|---|
| REVIEW_BP-20 **F-03** `currentEncounterId` 가 존재하지 않는 식별자 | `HDBattle` 에 인카운터 식별 구조 신설(자유 조우는 `null`) | **T-026** · T-101(이벤트 payload) |
| REVIEW_BP-20 **F-04** Effect 24종 중 8종이 `WorldStateMutator` 로 적용 불가 | 실행기(Effect executor)의 자리를 만든다 | **T-057** |
| REVIEW_BP-20 **F-05** `enemyIds` 문자열↔정수 다리 부재 | `legacyEnemyMap` 을 빌드가 굽고 `1..74` 를 강제 | **T-068** · T-072 |
| REVIEW_BP-23 **F-02b** 참조 무결성이 Condition 내부를 검사 안 함 | L2 가 Condition 안의 id 도 순회 | **T-072** |
| REVIEW_BP-23 **F-05** `step_tile` 발행원이 presentation 에만 존재 | 발행원을 `application/` 으로 옮긴다 | **T-086** · T-109 |
| REVIEW_BP-24 **F-04** 선택지 메뉴 제목 행(`items[0]`) 필드 부재 | 대화 런타임이 제목 행을 만드는 규약 확정 | **T-054** |
| REVIEW_BP-24 **F-13** `WorldState` 확장 3종이 어느 장에도 없음 | `WorldState` 구현 시 필드 확정 | **T-046** |
| REVIEW_BP-25 **F-05** `nextRandom` 이 조건 순수성을 깬다 | `chance` 무커서 해시(D-21) | **T-042** · T-047 |
| REVIEW_BP-25 **F-08** `orphans` 가 어느 스키마에도 없음 | 마이그레이션 산출물에 `orphans` 를 정식 필드로 | **T-066** |
| REVIEW_BP-25 **F-11** 원자성 규약과 복원 규약이 조합 불가 | 2단계 커밋 재설계 | **T-067** |
| REVIEW_BP-27 **F-09** `WorldRng.stream(label)` 이 단일 커서 위에서 구현 불가 | 스트림 분기 방식 확정(라벨 해시 혼합) | **T-049** |
| REVIEW_BP-27 **F-10** `HDEffectBridge` 가 이름만 있고 API 전무 | 브리지 API 구현 | **T-057** |
| REVIEW_BP-27 **F-14** 이중 재진입 가드가 R-28-2 와 충돌 | 가드 동치성을 테스트로 고정(Q-27-2 잠정안) | **T-059** |
| REVIEW_BP-27 **F-19 · F-20** 부록 B-3·B-4 미대응 | 이동 추출 · `dart:io` 제거 | **T-086** · **T-023** |
| REVIEW_BP-28 **F-02** "변경 후" 코드가 JSON 을 두 번 방출 | `emitJsonOnce()` 로 상호작용당 1회 보장 | **T-112** |
| REVIEW_BP-28 **F-09** TOWN2 가 로드 불가인데 이관 대상에 편성됨 | 이관 대상에서 제외하거나 맵 신설 | **T-149** |
| REVIEW_BP-22 **F-02**, REVIEW_BP-23 **F-03** 적 `id 0` 을 유효로 취급 | 범위 `1..74` 강제 | **T-028** · T-072 |
| REVIEW_BP-33 **Q-33-1** 줄당 글자수 30 vs 31 | 위젯 테스트 렌더 실측으로 확정 | **T-074**(임계 30 채택) · T-105 |

### 7.2 리스크 → 완화 태스크 대응표 (**BP-52 와의 양방향 연결**)

[BP-52 §52.9.2](52_risks.md) 는 "완화책의 **태스크화(T-nnn)·의존성·추정** → BP-51" 로 넘겼으나
**그 인수인계는 수신되지 않았다** — 초판 BP-51 에 `RK-nn` 참조가 **0건**, BP-52 에 통합 번호 `T-nnn` 참조가
**0건**이었다. 즉 **38개 리스크의 완화책 중 어느 것도 156개 태스크에 연결되어 있지 않았고**,
리스크 리뷰에서 "이 완화는 누가 언제 하는가" 에 답할 수 없었다. 아래 표가 그 연결의 **정본**이며,
[BP-52 §52.8](52_risks.md) 이 같은 대응을 리스크 쪽에서 받는다(41행 × 특유성·관측 신호·완화 태스크). §3 의 각 태스크 `근거` 열에도
해당 `RK-nn` 을 병기했다(신설분과 개정된 행 우선).

| 리스크 | 완화 태스크 | 마일스톤 |
|---|---|---|
| **RK-01** 맵 이름 해석 | T-004 · T-005 · T-006 · T-007 · T-008 · T-009 | M0 |
| **RK-02** cm2 상태 누수 | T-010 · T-011 · T-013 | M0 |
| **RK-03** 네이티브 스크립트 스텁·부착 | T-012 · T-013 · T-033 → T-111 | M0 → M3 |
| **RK-04** 세이브가 상태를 버린다 | T-014 · T-015 · T-016 · T-063 · T-066 | M0 → M1 |
| **RK-05** 결정론 붕괴 | T-017 · T-018 · T-019 · T-020 · T-021 · T-141 · T-142 · T-144 | M0 → M2 |
| **RK-06** 범위 밖 인자 침묵 실패 | T-029 · T-037(이름 있는 키) | M0 → M1 |
| **RK-07** 전투 결과 계약 3갈래 | T-025 · T-026 · T-027 · T-028 · T-072 | M0 → M2 |
| **RK-08** 헤드리스 구동 불가 | T-022 · T-023 · T-024 · T-085 ~ T-090 · T-091 · T-092 | M0 → M2 |
| **RK-09** 에셋 선언 비재귀 | T-069 · T-145 · T-166 | M1 · M0 · M1 |
| **RK-10** 세이브 크기 한계 | T-064 · T-065 · T-067 | M1 |
| **RK-11** 레거시 변환의 분기 역전 | T-113(변환기) · T-149 · T-150 | M3 · M6 |
| **RK-12** 인용한 코드 사실 오류 | T-030 · T-031 · T-032 | M0 |
| **RK-13** 재빌드 해시 불일치 | T-046 · T-068 · T-143 | M1 |
| **RK-14** 골든 습관적 갱신 | T-002 · T-003 · T-034 · T-146 | M0 → M2 |
| **RK-15** 열거값 발명 | T-038 · T-040 · T-071 · T-082 · T-137 | M1 · M2 · M5 |
| **RK-16** 환각 참조 | T-072 · T-120(P7 카탈로그) · T-130(ID 예약) | M2 · M4 · M5 |
| **RK-17** 세계관 이탈 | T-074 · T-135 · T-137 · T-138 | M2 · M5 |
| **RK-18** 문체 붕괴 | T-074 · T-135 · T-137 | M2 · M5 |
| **RK-19** 난이도·보상 인플레 | T-074 · T-099(보상 범위 데이터) · T-133 | M2 · M3 · M5 |
| **RK-20** 중복·균질 서사 | T-120(P6 색인) · T-126(`stats`) · T-135 | M4 · M5 |
| **RK-21** 린트 통과했는데 재미 없음 | T-135(Critic) · T-136(HG-3) · **T-164**(선결 점검) | M5 |
| **RK-22** 솔버가 증명했는데 클리어 불가 | T-096 · T-097 · T-134 · T-146 | M2 · M5 |
| **RK-23** 커버리지가 목표가 된다 | T-079 · T-098 · T-146 | M2 |
| **RK-24** 인벤토리·저널의 원작 이질감 | T-103 · T-105 · T-106 · T-107 · T-108 | M3 |
| **RK-25** 스코프 누출 | T-110(`time_of_day`) · T-107(변경 예산) | M3 |
| **RK-26** 4티어 예측 불가 | T-011 · **T-059**(선행 T-061) · T-061 · T-112 · **T-165** | M1 · M3 |
| **RK-27** 서버·CLI·MCP 3중 유지보수 | T-083 · T-115 · T-119 · T-123 · **T-162** | M2 · M4 |
| **RK-28** 파이프라인이 게임보다 커진다 | T-138(`core` 팩에 새 대화 1개 — [BP-50 R-50-15](50_roadmap.md)) · **T-164** · T-156 | M2 · M5 · M6 |
| **RK-29** 팩 버전 상승이 세이브를 죽인다 | T-066 · T-126(`migrate`) · T-151 | M1 · M4 · M6 |
| **RK-30** 웹 페이로드 예산 초과 | T-069 · **T-166** · T-125(`diff`) | M1 · M4 |
| **RK-31** CI 시간 예산 초과 | T-081 · T-143 · T-144 · T-147 · T-148 | M1 · M2 |
| **RK-32** 병렬 제작의 SSoT 붕괴 | T-051(이름 12종) · T-082 · T-031 · T-032 | M0 · M1 · M2 |
| **RK-33** 미반영 검수 결함 전파 | §7.1 의 18건 전량 · T-035 · T-098 | 상시 |
| **RK-34** 결정 재검토 요청 미종결 | T-025(Q-20-11) · T-035(Q-20-1) · **T-042**(D-21a) · T-112(Q-20-4) · T-152(Q-28-4) · T-156 | M0 → M6 |
| **RK-35** 브랜치 보호 부재 | T-139 ~ T-145(필수 검사 4종의 실체) | M0 → M2 |
| **RK-36** 순수 Dart CLI 가 평가기를 공유 못함 | **T-035** · T-036 · T-083 | M1 · M2 |
| **RK-37** 억제가 썩는다 | T-078 · T-080 · T-146 | M2 |
| **RK-38** LLM 비용·처리량 | T-128 · T-129 · T-133 · T-137 | M5 |
| **RK-39** (신설) `PROVEN + UNSUPPORTED` | **T-157 · T-158 · T-159** + T-101 · T-109(발행 지점 생성) | M2 → M3 |
| **RK-40** (신설) 장비가 전투에 반영되지 않는다 | **T-160 · T-161** + T-099 · T-102 | M3 |
| **RK-41** (신설) 죽은 필드·레이어를 재활용한다 | **T-165** + T-075(WARN 강등) · T-124(오버레이 전용) | M1 · M2 · M4 |

> **읽는 법** — 이 표는 **양방향 인덱스**다. "이 리스크의 완화는 누가 하는가" 는 행으로,
> "이 태스크는 어떤 리스크를 막는가" 는 §3 의 `근거` 열과 이 표의 역방향 조회로 답한다.
> 완화 태스크가 **없는 리스크는 한 건도 없다** — [BP-52 R-52-2](52_risks.md) 가
> "완화만 있고 대응이 없는 리스크는 등록을 거부한다" 고 했으므로, 그 대칭으로
> **"태스크로 착지하지 않는 완화는 완화가 아니다"** 를 R-51-12 로 확정한다.


---

## 8. 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 8.1 확정한 것

| ID | 확정 사항 |
|---|---|
| **R-51-1** | 통합 번호 체계 `T-<3자리>` 와 구간 배정 10군(§1.1). 장별 번호는 §7 대응표로만 추적한다 |
| **R-51-2** | 태스크 8항목 계약(ID/제목/M/선행/**실존 파일 경로**/완료 조건/규모/근거). 완료 조건은 **기계 판정 가능**해야 한다 |
| **R-51-3** (개정) | **부록 A~K 전수 대응표**(§2) — **34행**. 부록 G-1 집계 **21건** + G-1 이 세지 않은 **10건**(B-5·G-2·H-1~H-4·I-1·J-1~J-3). 31행은 태스크가 결함을 닫고, 2행(G-1·I-1)은 **태스크가 불필요한 근거를 기록**한다(§2.0). 초판의 "누락 0건" 은 **A-1~F-4 범위 안에서만 참**이었다 |
| **R-51-4** (개정) | 태스크 **167개**를 §3 에 전수 열거(초판 156 + 2차 개정 신설 11, 결번 0 · 중복 0). 마일스톤별 분포는 §6.1 |
| **R-51-5** (개정) | **임계 경로를 §3 의 `선행` 열에서 기계로 산출**한다 — **M5 파일럿 성공(T-136) 종점 24 태스크 · 계획 전체(T-155) 종점 27 태스크.** 초판의 "24" 는 값은 우연히 같으나 **경로가 달랐고 23간선 중 9개가 존재하지 않았다.** 단축안 5개(CP-1~CP-5)의 수치도 전부 그래프 재계산으로 대체했다(CP-1 **−10** · CP-2 −4 · CP-3 −2 · CP-4 **−0** · CP-5 −0). **줄일 수 없는 3연쇄**를 명시 |
| **R-51-6** | 즉시 착수 가능 태스크 **11개**를 식별하고, 그중 10개의 착수 절차를 §5 에 확정 |
| **R-51-7** | **T-002(골든 채취)는 T-004(맵 이름 수정)보다 반드시 먼저**다. 순서 위반은 기준선을 무효화한다(RP-3 · WS-0-1) |
| **R-51-8** | **T-023(`exit(0)` 제거)과 T-139(CI 검사 추가)는 같은 PR** 이다(D-23 의 명시적 요구) |
| **R-51-9** | 검수 보고서 12건의 **코드·설계 요구 결함 18건**을 태스크로 흡수(§7.1). 문장 수정은 태스크가 아니다 |
| **R-51-10** | 규모는 S/M/L 과 상대 총량(`S=1,M=3,L=7`)으로만 표현한다. **사람-시간 환산 금지** |
| **R-51-11** | `T-25-*`·`T-27-*` 은 **태스크가 아니라 테스트 케이스 ID** 이며 T-058·T-070 으로 묶인다 |
| **R-51-12** | **태스크로 착지하지 않는 완화는 완화가 아니다.** §7.2 가 RK-01~RK-41 전량에 완화 태스크를 배정하며, [BP-52](52_risks.md) 와 **양방향**으로 유지한다 |
| **R-51-13** | **D-19 순서를 그래프로 강제한다** — `T-059`(티어 0 삽입)의 선행에 **T-061** 을 넣었다. 초판 그래프는 `T-056` 이 끝나는 순간 티어 0 착수를 허용해 **`pendingNavigation` 승격보다 짧은 경로로 만들었다**(순서 역전). [BP-50 §7.2](50_roadmap.md) 에도 "절대 병렬 불가" 쌍으로 추가했다 |
| **R-51-14** | **R-50-1(파일럿 선결 P-1~P-7)을 그래프로 강제한다** — `T-164` 를 신설해 `T-129` 의 선행으로 넣었다. 문서의 선언만으로는 태스크 그래프가 저널·인벤토리 없는 파일럿 착수를 막지 못했다 |
| **R-51-15** | **D-26 을 태스크로 착지시켰다** — T-157(레지스트리) · T-158(실행 가능 축) · T-159(미활성 팩 차단)를 **솔버 태스크(T-096)와 같은 마일스톤(M2) 안에** 배치했다. 판정 축 정의는 [BP-34](34_headless_sim_and_solver.md), 레지스트리 생성 규칙은 [BP-35 §1.5.1](35_ci_and_build.md), 게이트는 [BP-53](53_acceptance_criteria.md) 소유이며 본 장은 **구현 태스크만** 갖는다 |
| **R-51-16** | **부록 H-1 의 선행 관계를 완료 조건으로 못박았다** — 장비가 게임에 영향을 주려면 **전투식 변경이 선행**이다(T-160). T-099 는 `ac` **재척도**(10→2, 20→5)를, T-102 는 `ac` **합산 배선**과 "장비 교체가 피해량을 바꾼다" 는 단위 테스트를 완료 조건으로 갖는다. 이것이 없으면 "이름은 예쁘지만 효과가 없는 장비" 가 만들어지고 **G3-2 는 그대로 통과한다** |
| **R-51-18** | **부록 K 를 반영했다** — D-27 은 진입점 3개 중 **2개에서 코드 변경 없이 성립**하고(K-1), **bump 경로 1곳만** 게이트가 남아 비대칭이다(K-2 → **T-167**, 1줄 변경). T-165 의 완료 조건 ④가 **3경로 동작 일치**를 단언한다. `:193` 이 fire-and-forget 이라는 사실(K-3)은 **재진입 가드가 유일한 보호막**임을 뜻하므로 T-059 의 가드 규약 테스트로 흡수했다 |
| **R-51-17** | **D-27 을 반영했다** — 앵커는 타일 비트에 의존하지 않으므로(부록 J-1) T-059 가 **타일 액션 게이트보다 앞에서** 트리거 인덱스를 조회하고, T-165 가 그것을 테스트로 고정한다. 앵커-타일 정합은 T-075 에서 **ERROR → WARN**. 원출처 `T-36-1`(Map001 region 정리)은 **폐기**한다 |

### 8.2 다음 장으로 넘긴 것

| 넘긴 것 | 받는 장 |
|---|---|
| 태스크별 리스크 등급과 완화책(RK-nn) | [BP-52](52_risks.md) |
| 완료 조건의 **수치 정본화**(DoD, 커버리지, 성능 임계) | [BP-53](53_acceptance_criteria.md) |
| JSON Schema 원문(T-082 의 산출물) | [BP-90](90_appendix_schemas.md) |
| MAP003 이관을 엔드투엔드로 보여주는 예제 | [BP-91](91_appendix_worked_example.md) |
| 각 태스크가 건드리는 스키마·시그니처의 정의 | D-18 소유표의 각 장 |
| 파일럿 8기준의 수용 기준 승격 | [BP-53](53_acceptance_criteria.md) |
| 태스크 배정(누가 무엇을) | 프로젝트 운영 — 본 장은 **트랙 4개**만 제시([BP-50 §7.4](50_roadmap.md)) |

### 8.3 열린 질문

| ID | 질문 | 왜 지금 못 정하는가 | 잠정 대응 |
|---|---|---|---|
| **Q-51-1** | T-004 에서 `Template_TOWN`·`Prolog`·`Template_DUNGEON` 3엔트리를 **제거할 것인가 맵 파일을 신설할 것인가** | 세 이름 모두 실재 파일이 없고(`Map008/009/012.json` 부재, 동명 파일도 부재) 참조원도 확인되지 않았다. 제거하면 `startup.cm2` 계열이 참조 중일 위험이 있다 | T-004 착수 시 `grep -rn "Template_TOWN\|Prolog\|Template_DUNGEON" hadar2026_app/assets/` 로 참조 조사 후 결정. 조사 결과를 T-004 완료 조건에 기록 |
| **Q-51-2** | T-149 의 **TOWN2** — `mapScriptFactory` 에 `Town2MapScript` 가 등록돼 있으나 `MapInfos.json` 에 없고 `TOWN2.json` 도 없다 | 네이티브 스크립트만 있고 지오메트리가 없다. 이관 대상인지 죽은 코드인지 미판정 | T-149 에서 **제외 판정을 기본값**으로 두고, 맵을 신설할 가치가 있으면 신규 콘텐츠로 취급. REVIEW_BP-28 F-09 가 같은 지적 |
| **Q-51-3** | T-096(솔버)을 `tools/content_cli/` 에 두면 T-035 의 결론에 따라 경로가 바뀌는가 | Q-20-1 미결. 물리 분리를 택하면 솔버가 `packages/hadar_content` 를 의존하게 된다 | T-035 를 M1 **첫 태스크**로 배치해 이 불확실성을 조기에 닫는다 |
| **Q-51-4** | T-138(`core` 팩 바이블)을 M2 에 두는 것이 맞는가 — [BP-32](32_generation_harness.md) 는 파일럿 선결(P-5)로만 규정 | 바이블 없이도 M2 의 린트는 픽스처로 검증 가능하다. 그러나 T-113(LORE_EP 이관)이 `core` 팩을 필요로 한다 | M2 후반 배치 유지. T-113 이 M3 이므로 여유가 있다 |
| **Q-51-5** | 규모 가중치 `S=1, M=3, L=7` 의 근거는 무엇인가 | 없다. 관행값이다 | **마일스톤 간 상대 비교에만** 사용하고 절대 환산 금지(§6.3). 실측 후 재설정. **가중치가 관행값이므로 총량의 한 자리 차이는 유의미하지 않다** — §6.2 는 M1(113)·M2(122)를 순위가 아니라 "같은 급" 으로 읽는다 |
| **Q-51-6** | T-085(추출 전 통합 테스트 6종)로 T-086 의 회귀를 정말 잡을 수 있는가 | [BP-34 Q-34-3](34_headless_sim_and_solver.md) 이 같은 질문을 열어 두었다. 추출 전에는 하네스가 없어 골든을 뜰 수 없다 | 대안으로 2단계 추출(컨트롤러 신설 → 스프라이트가 호출만 → 폴링 제거)을 롤백 지점으로 준비([BP-50 §8](50_roadmap.md)) |
| **Q-51-8** | `T-157` 의 `event_publishers.json` 을 **사람이 갱신**한다는 것은 낡을 수 있다는 뜻이다. "발행 코드가 생겼는데 선언이 `unpublished` 로 남아 있는" 경우를 CI 가 **WARN 으로만** 잡는데, 그러면 D-26 판정이 조용히 보수적으로 틀린다 | 선언과 코드를 완전 자동 대조하려면 발행 호출이 **단일 진입점**(`WorldEventBus.publish(kEvent…)`)이어야 하고 그것은 [BP-27](27_runtime_engine.md) 소관이다([BP-35 Q-35-10](35_ci_and_build.md) 이 같은 질문) | T-050(이벤트 버스) 구현 시 단일 진입점을 강제하고, T-157 의 CI 대조가 심볼 열거로 정확해지는지 M2 에서 확인 |
| **Q-51-9** | `T-160`(전투식 변경)의 골든 diff 를 **어디까지 승인할 것인가** | 방어량이 바뀌면 전투 로그가 바뀌고, 도달 가능한 cm2 의 `Battle::Result()` 분기도 흔들릴 수 있다(Q-50-5 와 같은 구조) | 레벨 1 픽스처 전투 1건을 기준으로 **피해량 변화표**를 `approvedDeltas` 에 등재하고, 그 밖의 diff 는 회귀로 판정 |
| **Q-51-10** | `T-164`(선결 점검)가 **11개 선행**을 갖는 것이 과한가 — 실질적으로 M5 전체가 M1~M3 완료를 기다리게 된다 | 그것이 R-50-1 의 의도다. 그러나 T-127·T-137(프롬프트·디렉토리)은 여전히 병렬 착수 가능하므로 **파일럿 준비 작업은 막히지 않는다** | 유지. 만약 M5 착수를 앞당겨야 한다면 **P-6·P-7 만 필수**로 남기고 나머지를 경고로 강등하는 안을 M4 에서 재평가 |
| **Q-51-7** | 검수 보고서 12건 중 **BP-21·BP-23·BP-24·BP-25·BP-27·BP-28 이 "수정 필요"** 판정이다. 그 장들의 재작성이 태스크 착수 전에 끝나야 하는가 | 문서 수정과 코드 착수는 원칙적으로 독립이지만, `T-054`(대화 런타임)·`T-055`(퀘스트 런타임)는 **해당 장의 스키마 확정에 직접 의존**한다 | M0 태스크는 문서 판정과 **무관하게 즉시 착수**. M1 의 T-043·T-044·T-054·T-055 는 소유 장이 합격 판정을 받은 뒤 착수 |

---

## 부록 A. 이 장이 인용한 코드·데이터 위치

| 참조 | 경로:줄 | 인용 태스크 |
|---|---|---|
| 맵 이름 해석 분기 | `hadar2026_app/lib/application/map_navigation.dart:40-48` | T-004 · T-005 · T-006 |
| cm2 로드 실패 조기 반환 | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:92-99` | T-010 |
| 커맨드 범위 검사(else 부재) | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:362-391` | T-029 |
| 빈 `Party::PosX/PosY` 커맨드 등록 | `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:418-419` | T-030 |
| 네이티브 스왑이 `json` 유무와 무관 | `hadar2026_app/lib/application/game_session.dart:97-128` | T-012 |
| 세이브 직렬화에 `events` 없음 | `hadar2026_app/lib/domain/map/map_model.dart:50-58` | T-014 |
| 세이브 로드가 `setNewMap` 직접 호출 | `hadar2026_app/lib/application/save_manager.dart:86` | T-015 |
| 벽시계 독 데미지 | `hadar2026_app/lib/domain/party/player.dart:69-72` | T-018 |
| `dart:io` import | `hadar2026_app/lib/application/menu_flows.dart:2` | T-023 · T-139 |
| `exit(0)` 3곳 | `hadar2026_app/lib/application/menu_flows.dart:504,522,540` | T-023 |
| 전투 결과 초기값 | `hadar2026_app/lib/application/battle.dart:27` | T-025 · T-026 · T-027 |
| 적 등록 하한 가드 | `hadar2026_app/lib/application/battle.dart:43-46` | T-028 |
| 플래그 스텁 | `hadar2026_app/lib/application/scripting/map_script.dart:41-48` | T-033 · T-111 |
| 네이티브 맵 팩토리 4종(**TOWN2 포함**) | `hadar2026_app/lib/application/scripting/native_script_runner.dart:25-30` | T-149 · Q-51-2 |
| 상호작용 폴링 | `hadar2026_app/lib/presentation/panels/player_sprite.dart:103,193,362,405` | T-085 · T-086 · T-087 |
| 비재귀 에셋 선언 | `hadar2026_app/pubspec.yaml:65-69` | T-069 · T-166 |
| **방어 계산이 `ac` 하나만 읽는다** | `hadar2026_app/lib/application/battle.dart:513-514` | **T-160**(부록 H-1) |
| **죽은 장비 필드** | `hadar2026_app/lib/domain/party/player.dart:50,134,136,293,294,358,361,426,427` · `lib/domain/party/party.dart:107,129` | T-160 (부록 H-1 — 전부 대입·직렬화·`getAttribute` 스위치뿐) |
| **레거시 장비 데이터** | `hadar2026_app/assets/maps/books.json` | T-099 · **T-161**(부록 H-2·H-3) |
| **region 이 하위 바이트로 들어간다** | `hadar2026_app/lib/application/map_loader.dart:44` | **T-165**(부록 J-1 · D-27) |
| **마스크는 상위 바이트만 본다** | `hadar2026_app/lib/domain/map/tile_properties.dart:186-187` | **T-165** (`200 & 0x00FF0000 == 0`) |
| **타일 액션 게이트** | `hadar2026_app/lib/application/tile_event_dispatcher.dart:51-61` | **T-059**(D-27 — 콘텐츠 티어는 이 게이트보다 앞) |
| `autoFlush` 가 cm2 내부 상태에 묶여 있다 | `hadar2026_app/lib/application/tile_event_dispatcher.dart:99` | T-060 · T-061 · **T-059**(선행 근거, D-19) |
| 맵 에디터가 이미 `json` 을 쓴다 | `tools/mapEditor/server/ai_api.ts:592` | T-004 (부록 H-4 — 범위 한정) |
| 레거시 픽스처 맵(타일 액션 경계) | `hadar2026_app/assets/maps/Map001.json` | T-165 (부록 I-1 — **정리하지 않고 픽스처로 쓴다**) |
| 계층 검사 CI | `.github/workflows/ci.yml` | T-139 ~ T-148 |
| 페이크 바인딩 선례 | `hadar2026_app/test/application/map_navigation_test.dart` | T-009 · T-092 |
| 맵 에디터 AI API(복제 대상) | `tools/mapEditor/server/ai_api.ts` | T-115 ~ T-119 |
| MCP 래퍼 | `tools/mapEditor/mcp/server.mjs` | T-123 |
| 로컬 path dep 선례 | `packages/cm2_script/` | T-035 · T-036 |
