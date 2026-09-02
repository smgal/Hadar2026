# 검수 보고서 — BP-21 Content Pack 포맷·매니페스트·ID 체계

- **검수자**: R6 · **대상 파일**: blueprint/21_content_pack_spec.md (1039줄)
- **판정**: **수정 필요**
- **점수**: A3 B3 C2 D3 E3 F5 G5 = **24/35** (합격선 26, C축 2점)

## 0. 검수 범위와 방법

| 항목 | 수행 내용 |
|---|---|
| 기계적 검사 1 (분량) | `wc -l` = 1039줄. 최소 250줄 충족 ✅ |
| 기계적 검사 2 (코드 인용) | 14곳 직접 대조 (아래 §0.1) |
| 기계적 검사 3 (링크) | 13개 상대 링크 전량 검사 — 실재 7 / OUTLINE 계획 6 / 깨짐 **0** ✅ |
| 기계적 검사 4 (식별자) | D-05 의 op 18 + do 22 를 **문자 단위** 대조 (§1 전수 감사표) |
| 기계적 검사 5 (중복) | 전 blueprint 에서 `"op":`/`"do":` 사용값 수집 → BP-21 외 재정의 여부 확인 |
| 기계적 검사 6 (미확정 표현) | `적절히|추후|등등|TBD|TODO|나중에|필요시|알아서` grep → 1건(§6.3 C17 서술, 무해) ✅ |
| 추가 검사 | 문서 안 **모든 예시 ID 를 문서 자신의 정규식에 대입**하는 스크립트 실행 (§3) |

### 0.1 코드·데이터 인용 대조 결과 (직접 확인 14곳)

| # | 문서 주장 | 대조 대상 | 결과 |
|---|---|---|---|
| 1 | `assets/lore_ep1.cm2` 는 어디서도 로드되지 않는 고아 (grep 0건) | `grep -rn "lore_ep1" assets/ lib/` | ✅ 0건 |
| 2 | `HDConfig.maxLinesPerPage = 13` | `hd_config.dart:52` | ✅ |
| 3 | 콘솔 512×320, 폰트 16px, 행높이 1.2 | `hd_config.dart:14-17` (`consoleWidth 512.0` / `consoleHeight 320.0` / `consoleFontSize 16.0` / `consoleLineHeight 1.2`) | ✅ |
| 4 | `HDTextUtils.parseRichText` 가 렌더 시 해석 | `lib/utils/hd_text_utils.dart:26` | ✅ (단 문서는 경로 미표기) |
| 5 | `lib/domain/console/console_log.dart` 가 원문 보관 | 파일 존재 확인 | ✅ |
| 6 | `assets/lore_ep1.cm2` 의 `@B…@@` | `grep -c "@B"` = 5 | ✅ |
| 7 | `assets/menace.cm2` 의 `@7…@@` | `menace.cm2:33` | ✅ |
| 8 | `REF_UNITY_LoreEp1/src_as_cs/NpcWeaponShop.cs:47` 의 `@F…@@` | 45~49행에 `@F여기는 무기상점입니다.@@` | ✅ (±2행) |
| 9 | C11 `HDPlayer.getClassName` | `player.dart:78` | ✅ |
| 10 | C11 `HDPlayer.isAvailable()` | `player.dart:54` | ✅ |
| 11 | C12 `HDPlayer.level.physical` | `player.dart:38,140` | ✅ |
| 12 | C13/E7 `HDParty.gold`, E8 `food` | `party.dart:58,56` (`gold=500`, `food=100`) | ✅ |
| 13 | E16 `HDParty.maxEnemy`(기본 3) | `party.dart:78` | ✅ |
| 14 | §6.7 `_isScriptRunning` at `tile_event_dispatcher.dart:34` | `tile_event_dispatcher.dart:34 bool _isScriptRunning = false;` | ✅ |
| 15 | §8 "원본 `books.json` 은 탭을 쓴다" | `assets/maps/books.json` 실제 탭 들여쓰기 | ✅ |
| 16 | §2.2 R-21-7 등록 이름 15개 | `MapInfos.json` 파싱 결과와 순서·철자 전량 일치 | ✅ |

→ 인용 자체의 정확도는 매우 높다. A축 감점은 인용이 아니라 **사실 판단**(색상 태그 집합·레벨 상한·부록 D 미반영)에서 발생한다.

---

## 1. DSL 40항목 전수 감사표 (D-05 문자 단위 대조)

판정 기호: ✅ 문제 없음 / ⚠ 부분 결함 / ❌ 결함

### 1.1 Condition op 18개

| # | op | D-05 존재 | 인자·타입 명시 | 검증규칙 명시 | **빌드** 실패동작 | **런타임** 미정의 입력 동작 | 부작용 | 판정 |
|---|---|---|---|---|---|---|---|---|
| C1 | `true` | ✅ 동일 | 인자 없음 명시 | — | — | — | 없음 | ✅ |
| C2 | `false` | ✅ 동일 | 인자 없음 명시 | 린트 경고(죽은 분기) | — | — | 없음 | ✅ |
| C3 | `and` | ✅ 동일 | `args: Condition[]` | 1~16개, 깊이 ≤8 (R-21-28/29) | 하드 실패 | 단축평가 R-21-27 | 없음 | ⚠ R-21-27 이 `chance` 예외를 두는데 §6.5 와 모순(F-03) |
| C4 | `or` | ✅ 동일 | 동상 | 동상 | 하드 실패 | 동상 | 없음 | ⚠ 동상 |
| C5 | `not` | ✅ 동일 | `arg: Condition` | 필수 | 하드 실패 | — | 없음 | ✅ |
| C6 | `flag` | ✅ 동일 | flag key | ID 문법·팩 가시성 | 하드 실패 | **명시됨**: 없는 플래그 → `false` | 없음 | ✅ |
| C7 | `var_cmp` | ✅ 동일 (`cmp` 6종·`value:int` 일치) | var key/enum/int32 | cmp 집합, int32 | 하드 실패 | **명시됨**: 없는 변수 → `0` | 없음 | ✅ |
| C8 | `has_item` | ✅ 동일 (`count?=1` 일치) | item id, int≥1 | 비스택 아이템 `count>1` 하드 실패 | 하드 실패 | 미보유 → 0 (암묵) | 없음 | ⚠ 미보유 시 동작 문언 없음 |
| C9 | `quest_state` | ✅ 동일 (state 4종 일치) | quest id, enum | 상태 집합 | 하드 실패 | 미시작 → `inactive` (D-08 암묵, 본문 무언급) | 없음 | ⚠ |
| C10 | `quest_stage` | ✅ 동일 | quest id, stage id | 스테이지 존재 | 하드 실패 | **미정의** — 퀘스트가 `inactive`/`completed` 일 때 무엇을 돌려주는지 서술 없음 | 없음 | ❌ (F-11) |
| C11 | `party_has_class` | ✅ 동일 | int 0..2 | `isAvailable()` 기준 명시 | 하드 실패 | 전원 사망 시 자동 `false` (자명) | 없음 | ✅ |
| C12 | `party_level_cmp` | ✅ 동일 | enum, int | **`value` 1..21** | 하드 실패 | 파티 공백 시 최댓값 정의 없음 | 없음 | ❌ 실제 도달 최대 레벨은 **20** (F-07) |
| C13 | `gold_cmp` | ✅ 동일 | enum, int≥0 | — | 하드 실패 | — | 없음 | ✅ |
| C14 | `map_is` | ✅ 동일 | string | `MapInfos.json#name` 에 존재 | 하드 실패 | — | 없음 | ❌ 부록 D 미반영 — 이름 존재가 곧 로드 성공이 아님 (F-05) |
| C15 | `visited` | ✅ 동일 | place id | place 존재 | 하드 실패 | 미방문 → false (암묵) | 없음 | ⚠ |
| C16 | `npc_state` | ✅ 동일 | npc id, string | BP-22 `states[]` 선언 필요 | 하드 실패 | **미정의** — 액터 상태가 아직 세팅 안 된 경우(초기값은 BP-22 `initialState`) 를 BP-21 이 언급 안 함 | 없음 | ⚠ |
| C17 | `time_of_day` | ✅ 동일 (`{day,night}` 일치) | enum | 집합 | 하드 실패 | **명시됨**: v1 은 항상 `day` + 린트 경고 | 없음 | ✅ |
| C18 | `chance` | ✅ 동일 | int **1..99** | 0/100 금지 | 하드 실패 | §6.5 유도식 명시 | **있음(난수 소비 주장)** | ❌ 시드 규약이 D-08a·BP-27 과 불일치, 문서 내부에서도 모순 (F-03) |

**Condition 집계**: D-05 이탈(이름 추가/변경/누락) **0건**. 이름 18개 전부 문자 단위 일치. 결함은 전부 **인자 제약·실패 동작** 층에서 발생.

### 1.2 Effect do 22개

| # | do | D-05 존재 | 인자·타입 명시 | 부작용 대상 명시 | 검증규칙 | **런타임** 실패/경계 동작 | 판정 |
|---|---|---|---|---|---|---|---|
| E1 | `set_flag` | ✅ 동일 | flag key | `WorldState.flags` | ID 문법·가시성 | 자명 | ✅ |
| E2 | `clear_flag` | ✅ 동일 | flag key | 동상 | 동상 | 자명 | ✅ |
| E3 | `set_var` | ✅ 동일 | var key, int | `WorldState.vars` | int32 | 자명 | ✅ |
| E4 | `add_var` | ✅ 동일 (`delta`) | var key, int | 동상 | `delta != 0` 권장 | **오버플로 시 동작 미정의**(int32 라 했으나 클램프/랩 미지정) | ⚠ |
| E5 | `give_item` | ✅ 동일 | item id, int≥1 | `WorldState.inventory` | 비스택 중복 경고 | `maxStack`(BP-22) 초과 시 동작 미정의 | ⚠ |
| E6 | `take_item` | ✅ 동일 | item id, int≥1 | 동상 | — | **명시됨**: 0 클램프 + 경고 로그 | ✅ |
| E7 | `add_gold` | ✅ 동일 | int | `HDParty.gold` | — | **명시됨**: 음수면 0 클램프 | ✅ |
| E8 | `add_food` | ✅ 동일 | int | `HDParty.food` | — | **명시됨**: 0 클램프 | ✅ |
| E9 | `start_quest` | ✅ 동일 | quest id | `WorldState.quests` | — | **명시됨**: 이미 active/completed 면 무시+경고 | ✅ |
| E10 | `advance_quest` | ✅ 동일 | quest id, stage id | 동상 | 역행 전이 하드 실패 | 빌드 하드. 런타임 동작 미기재(BP-23 T12 는 "무시+ERR") | ⚠ 강도 불일치 |
| E11 | `complete_quest` | ✅ 동일 | quest id | 동상 | — | **명시됨**: active 아니면 무시+경고. 단 `onComplete`+`rewards` **중첩 배열**의 꼬리 호출 규칙 미정의 | ❌ (F-02) |
| E12 | `fail_quest` | ✅ 동일 | quest id | 동상 | `failConditions`/`onFail` 존재 필요 | 미기재 | ⚠ |
| E13 | `set_npc_state` | ✅ 동일 | npc id, string | `WorldState.npcStates` | BP-22 `states[]` | 런타임 미선언 상태 시 동작 미기재 | ⚠ |
| E14 | `warp` | ✅ 동일 (`map,x,y`) | string, int, int | 세션(맵·파티 위치) | 맵 존재·좌표 범위·**도착 타일 통행 가능** | 꼬리 호출만(R-21-40). 런타임 맵 로드 실패 시 동작 미기재 | ❌ 부록 D 미반영 (F-05) |
| E15 | `change_tile` | ✅ 동일 (`map?,x,y,tile`) | string?, int, int, int | 맵 런타임 상태 | `tile` A5 0..127 | 좌표 범위 밖 동작 미기재 | ❌ objUpper 를 못 바꾸는 사실 누락 + `tileOverrides` 명칭 충돌 (F-12) |
| E16 | `start_battle` | ✅ 동일 (`encounterId`) | enc id | 전투 서브시스템 | 인카운터 존재, 적 ≤ `maxEnemy` | 전투 **결과**를 콘텐츠가 볼 수단이 DSL 에 없음 | ⚠ 부록 B-2 미언급 |
| E17 | `play_dialogue` | ✅ 동일 | dlg id | UI(대화 런타임) | 재진입 금지, 체인 ≤4 | **명시됨**: 초과 시 런타임이 체인 절단 + 경고 | ❌ 배열 단위 규칙만 → 중첩 우회 가능 (F-02) |
| E18 | `journal` | ✅ 동일 (`entryKey`) | string key | `WorldState.journal` | 문자열 키 존재 | — | ❌ §6.9 예시의 `entryKey` 가 자기 STRING_KEY 정규식 불통과 (F-01) |
| E19 | `heal_party` | ✅ 동일 (`percent`) | int 1..100 | 파티 | 의식불명/사망 제외 | 명시됨 | ✅ |
| E20 | `grant_exp` | ✅ 동일 (`amount`) | int≥1 | 파티 | 균등 분배, 나머지 버림 | 명시됨 | ✅ |
| E21 | `set_encounter` | ✅ 동일 (`rate`) | int 0..10 | 파티 | 0 = 조우 없음 | 상한 10의 근거 미제시(`HDParty.encounter` 기본 3, 코드 상 상한 없음) | ⚠ |
| E22 | `unlock_place` | ✅ 동일 | place id | `WorldState` | place 존재 | 이미 해금 시 동작 미기재 | ⚠ |

**Effect 집계**: D-05 이탈 **0건**. 이름 22개 전부 문자 단위 일치. `do` enum(§6.8 라인 833-837)도 D-05 목록과 순서까지 동일.

### 1.3 감사 총평

| 지표 | 값 |
|---|---|
| D-05 목록 대비 **임의 추가** | **0** |
| D-05 목록 대비 **이름 변경** | **0** |
| D-05 목록 대비 **누락** | **0** |
| 인자 이름 불일치 | **0** (`count?`/`delta`/`percent`/`amount`/`rate`/`entryKey`/`encounterId`/`classId`/`mapName`/`placeId` 전량 일치) |
| 타입 명시 | 40/40 ✅ |
| 빌드 실패동작 명시 | 40/40 ✅ |
| **런타임 미정의 입력 동작 명시** | **11/40** (C6, C7, C17, C18, E6, E7, E8, E9, E11, E17, E19/E20 부분) → **결함** |
| 부작용 유무 명시 | Condition 40 전량 "부작용 없음" 선언 ✅ / Effect 22 전량 부작용 대상 열 존재 ✅ |

**결론**: 이름 층위에서 D-05 이탈은 **0건**이며 이 부분은 만점이다. 결함은 전부 (a) 런타임 미정의 동작, (b) 꼬리 호출 규칙의 적용 범위, (c) `chance` 시드 규약의 타 문서 불일치, (d) 문자열 키 문법 자기모순에 집중되어 있다.

---

## 2. 치명 결함 (반드시 고쳐야 함)

### F-01 문자열 키 정규식과 §5.3 슬롯표·§5.4 예시가 상호 모순 — 문서가 자기 문법을 통과하지 못한다

- 위치: 21_content_pack_spec.md:321-323(EBNF), :330(STRING_KEY 정규식), :529-548(표준 슬롯표), :564-572(예시), :869(E18 예시)
- 문서 주장:
  - EBNF `string-key = "str" "." pack "." type "." slug "." slot ;` — **5 세그먼트 고정**, `slot = slug`
  - 정규식 `^str\.[a-z][a-z0-9_]{2,31}\.(npc|quest|…|ui)\.[a-z][a-z0-9_]{2,47}\.[a-z][a-z0-9_]{2,47}$`
  - 그런데 §5.3 표준 슬롯은 `default_line.<n>`, `stage.<stageId>.journal`, `objective.<objId>.desc`, `node.<nodeId>.line.<n>`, `node.<nodeId>.header`, `choice.<nodeId>.<choiceId>` 처럼 **점을 포함**하고, R-21-23 은 `<n>` 을 **0-based 정수**로 못박는다.
- 검증(스크립트로 전 예시 대입): 문서 안 문자열 키 예시 **9개 중 8개가 불통과**.

| 줄 | 키 | 불통과 사유 |
|---|---|---|
| 564 | `str.gen_ep1.npc.lore_gate_guard.about_scholar.0` | 6세그먼트 + 마지막이 숫자 |
| 565 | `str.gen_ep1.npc.lore_gate_guard.about_scholar.1` | 동상 |
| 568 | `str.gen_ep1.quest.missing_scholar.stage.find_trail.journal` | 7세그먼트 |
| 569 | `str.gen_ep1.dlg.wife_plea.node.intro.header` | 7세그먼트 |
| 570 | `str.gen_ep1.dlg.wife_plea.node.intro.line.0` | 8세그먼트 + 숫자 |
| 571 | `str.gen_ep1.dlg.wife_plea.choice.intro.accept` | 7세그먼트 |
| 572 | `str.gen_ep1.dlg.wife_plea.choice.intro.decline` | 7세그먼트 |
| 869 | `str.gen_ep1.quest.missing_scholar.stage.deliver.journal` (E18 `entryKey`) | 7세그먼트 |
| 348 | `str.core.npc.lore_gate_guard.name` | **유일하게 통과** |

- 파급: 이 결함은 BP-26 §8.2 6단계(`str.<pack>.dlg.<slug>.node.intro.line.<n>` 를 **생성하라**는 이관 규칙)와 §8.3 산출 예시(`str.core.dlg.lore_ep_lord_ahn_idle.node.intro.line.0`)까지 그대로 전파되어 있다. 즉 이관 도구가 만드는 키가 100% 하드 실패한다.
- 요구 조치: 셋 중 하나로 확정하라.
  1. STRING_KEY 를 `^str\.<pack>\.<type>\.<slug>(\.<seg>)+$` 로 확장하고 `<seg>` 에 `[0-9]+` 를 허용,
  2. 슬롯 구분자를 `.` 대신 `_`/`-` 로 바꿔 5세그먼트 고정 유지,
  3. 슬롯 세그먼트를 별도 문법(`slot-path`)으로 분리 정의.
  어느 쪽이든 §4.1 EBNF·§4.1 정규식·§5.3 표·§5.4 예시·§6.9 예시를 **동시에** 고쳐야 한다.

### F-02 꼬리 호출 규칙이 "배열 단위" 로만 정의되어 실제 실행 단위를 덮지 못한다 — SSoT 붕괴

- 위치: 21_content_pack_spec.md:774-780 (R-21-38 / R-21-39 / R-21-40)
- 문서 주장: `play_dialogue` 는 Effect 배열의 마지막 원소여야 하고, 한 Effect **배열**에 `warp`/`start_battle`/`play_dialogue` 중 둘 이상이 있으면 하드 실패.
- 실제로 양립하지 않는 사례 (BP-23/BP-24 를 읽고 대조한 결과):

| # | 위반 경로 | 근거 |
|---|---|---|
| V1 | `[{"do":"complete_quest",…},{"do":"play_dialogue",…}]` — R-21-38/40 을 **만족**한다. 그러나 E11(라인 739)에 따라 `complete_quest` 는 `onComplete[]`+`rewards[]` 를 실행하고, BP-23:964 는 "맵을 옮기거나 전투를 시작하는 연출은 **`onComplete` 에 둔다**" 라고 명시적으로 권장한다 → 한 상호작용에 `warp` + `play_dialogue` 두 개가 발생. **빌드 게이트 없음** | 23_quest_model.md:963-964, 21:739 |
| V2 | `[{"do":"advance_quest","stage":"s2"},{"do":"play_dialogue",…}]` — BP-23 Stage 스키마(23:306)는 `onEnter` 에 "D-05 do" 전량을 허용하므로 `s2.onEnter` 가 또 `play_dialogue` 를 가질 수 있다. R-21-39 의 체인 깊이 4 를 무엇이 세는지도 미정의 | 23_quest_model.md:306, 617, 628 |
| V3 | BP-22 R-22-20(22:644-646)이 **아이템 사용 컨텍스트에서 BP-21 의 꼬리 호출 규칙을 만족시킬 수 없다**고 명시하고, `item.core.teleport_ball` 에 대해 **스스로 `warp` 예외를 선언**한다. SSoT 인 BP-21 은 아이템 사용 컨텍스트를 아예 다루지 않는다 | 22_world_bible_model.md:644-646, 749 |

- 그리고 **무엇이 잡는가?** 라는 물음에 대한 답:
  - BP-21 은 "빌드 하드 실패" 라고만 쓰고 **규칙 ID·심각도·검사 위치를 부여하지 않았다**. §9.2 는 "린트 경고 항목" 만 BP-33 으로 넘긴다고 적어, 하드 규칙의 소유자가 공백이다.
  - BP-24 는 같은 제약을 `DV-15`(≤1개) / `DV-16`(마지막 원소) / `DV-17`(`next`/`go` 는 `"end"`) 로 **별도 번호를 붙여 재정의**했다(24:811-813).
  - BP-25 §4.4(25:484-492)는 아예 **다른 규약**을 만들었다 — "지연 효과가 한 상호작용에서 2개 이상이면 **첫 번째만 실행하고 나머지는 경고**". 즉 런타임이 콘텐츠를 조용히 버린다. BP-25 스스로 "빌드 lint 가 hard gate 로 잡는 것이 정답이지만" 이라고 적어, BP-21 에 그 게이트가 없음을 인정한다.
- 요구 조치:
  1. R-21-40 의 적용 단위를 **"한 상호작용에서 실행되는 Effect 배열의 전이적 폐포"** 로 재정의하고, `complete_quest`/`advance_quest`/`start_quest`/`fail_quest` 가 유발하는 중첩 배열을 포함한다고 명시할 것.
  2. 그 정적 검사가 불가능한 케이스(런타임 분기)에 대해 **런타임 규약**(BP-25 의 "첫 개만 실행")을 BP-21 본문에 흡수하고 BP-25 는 참조만 하게 할 것.
  3. 아이템 사용 컨텍스트를 §6.7 에 명시하여 BP-22 R-22-20 의 예외 선언을 회수할 것.

### F-03 `chance` 시드 규약이 D-08a·BP-27 과 3자 불일치이고, 문서 내부에서도 모순이다

- 위치: 21_content_pack_spec.md:634-636 (R-21-27), :701-723 (§6.5)
- 문서 주장(§6.5): `h = fnv1a64("<contextId>#<evalPath>")`, `stream = splitmix64(seed ^ h)`, `value = stream.next() % 100`. **무상태 경로 해시**이며 R-21-34 는 "같은 세이브·같은 위치의 `chance` 는 항상 같은 결과" 를 보장한다고 못박는다.
- 대조 결과:

| 출처 | `chance`/난수 재현 기준 | BP-21 과 일치? |
|---|---|---|
| DECISIONS.md D-08a 말미 | "BP-27 의 `WorldRng` 는 **`seed` + `step`** 으로 재현" | ❌ BP-21 은 `step` 을 전혀 쓰지 않음 |
| 27_runtime_engine.md:36, 1203-1216 | `WorldRng` = `WorldState.seed` + **`rngCursor`**, `nextInt` 이 커서를 **증가**시킴 | ❌ |
| 27_runtime_engine.md:283-285 | `ConditionEvaluator.evaluate(c, state, {WorldRng? rng})` — `chance` 가 `WorldRng` 를 소비 | ❌ 경로 해시가 아님 |
| 27_runtime_engine.md:1551 (Q-27-4) | "`chance` op 이 대화 중 평가되면 **커서가 밀린다**. 세이브를 로드해 같은 대화를 다시 하면 **다른 결과가 나온다**" | ❌ R-21-34 와 **정반대** |
| 25_world_state_and_save.md:160 | `rngCursor` 를 WorldState 필드로 신설 (D-08 골격에 없음) | — |

- 게다가 **BP-21 내부 모순**: R-21-27 은 "`chance` 는 시드 난수를 **소비**하므로 단축 평가의 예외" 라고 쓰는데, §6.5 의 유도식은 커서를 쓰지 않는 순수 함수이므로 **소비할 상태가 없다**. 두 서술은 동시에 참일 수 없다.
- 부수 문제: `evalPath` 예시 `"dlg.gen_ep1.guard_intro#node.intro.entry[2].args[1]"`(라인 707)은 구조적으로 성립하지 않는다. `entry` 는 Dialogue 최상위 필드(D-07)이지 노드 하위가 아니다.
- 요구 조치: BP-21 이 SSoT 이므로 **여기서 하나를 확정**하고 BP-25/BP-27 이 따르게 하라. 세 안의 트레이드오프를 §6.5 에 표로 남길 것.
  - (a) 경로 해시(현행 BP-21): 세이브 스커밍 차단, 대화 수정 시 기존 세이브 분기 변동(Q-21-3 이 이미 인지).
  - (b) `seed`+`rngCursor`(BP-25/27): 커서 저장으로 수열 연속, 세이브 스커밍 가능.
  - (c) `seed`+`step`(D-08a 문언): 논리 시각 기반.
  어느 쪽이든 R-21-27 의 "소비" 문언을 그에 맞게 정정해야 한다.

### F-04 §6.8 JSON Schema 발췌가 §6.1 "타입 오류는 스키마 단계에서 잡는다" 를 지탱하지 못한다

- 위치: 21_content_pack_spec.md:630 (§6.1 "타입 오류 | 스키마 단계에서 잡는다"), :786-858 (§6.8 발췌)
- 실제:

| 관찰 | 결과 |
|---|---|
| `condition.allOf` 가 필수 인자를 강제하는 op | `and`, `or`, `not`, `flag`, `var_cmp`, `has_item`, `chance` — **7개뿐** |
| 강제되지 않는 op | `quest_state`, `quest_stage`, `party_has_class`, `party_level_cmp`, `gold_cmp`, `map_is`, `visited`, `npc_state`, `time_of_day` — **9개**. `{"op":"quest_state"}` 가 스키마를 통과한다 |
| `effect` 의 `allOf` | **전무**. `{"do":"warp"}`(map/x/y 없음), `{"do":"var_cmp"}` 류 오타 do 만 아니면 인자 0개도 전부 통과 |
| `effect` 의 `id` 패턴 참조 | 없음 (`{"type":"string"}` 뿐). `{"do":"give_item","id":"헬로"}` 통과 |
| `time_of_day` 의 `value` | 최상위에 `{"type":["integer","string"]}` 로만 존재. `{day,night}` enum 이 어디에도 없음 |

- "전문은 BP-90" 이라는 완충이 있으나, §6.1 이 **런타임 타입 캐스팅 실패는 발생할 수 없어야 한다**고 단언하는 근거가 이 발췌이므로, 발췌가 그 주장의 반례가 되어 있다.
- 요구 조치: 발췌를 (a) 전 op/do 의 `allOf` 를 담거나, (b) "필수 인자 강제는 BP-90 전문에만 있다" 를 명시하되 §6.1 의 단언을 완화하라. 최소한 `effect` 에 대표 3~4개의 `allOf` 는 실어야 한다.

### F-05 부록 D(맵 이름 해석 파손) 미반영 — `map_is`/`warp`/앵커 파일명 규칙이 잘못된 전제 위에 있다

- 위치: 21_content_pack_spec.md:114-116 (R-21-7), :665 (C14), :742 (E14)
- 문서 주장:
  - R-21-7 "`anchors/<MAPNAME>.json` 의 `MAPNAME` 이 `MapInfos.json` 에 **없으면** 하드 실패" + 15개 이름 나열(TOWN1/GROUND1/DEN1/DEN2 포함)
  - C14 `map_is` 검증규칙 = "`MapInfos.json#name` 에 존재"
  - E14 `warp` 검증규칙 = "맵 존재"
- 실제(부록 D 및 직접 재확인):
  - `map_navigation.dart:29` 이 폴백 `'$searchName.json'` 을 먼저 세우고, :43 이 이름을 찾으면 `'Map$idStr.json'` 으로 **덮어쓴다**. `MapInfos.json` 의 15 엔트리에 `json` 필드가 **하나도 없음**(직접 파싱 확인).
  - 따라서 `TOWN1`→`Map004.json`(부재), `GROUND1`→`Map005.json`(부재), `DEN1`→`Map006.json`(부재), `DEN2`→`Map007.json`(부재). **이름이 등록되어 있다는 사실 자체가 로드를 깨뜨린다.**
  - `map_navigation.dart:63` 은 `cm2Path != null` 이면 실패를 삼키고 `json: null` 인 `MapBundle` 을 "성공" 으로 돌려준다.
- 결과: C14/E14/R-21-7 의 검증은 "이름이 인덱스에 있는가" 만 확인하므로, **정확히 로드 불가능한 4개 맵을 유효하다고 통과시킨다.** BP-22 는 같은 문제를 G-22-1 / R-22-11("실제 파일로 해석되는지 검사") / T-22-1 로 정면 처리했고, BP-26 도 A-26-03 에서 그 형태를 채택했다. SSoT 인 BP-21 만 구형 전제를 쓴다.
- 요구 조치: C14/E14/R-21-7 의 검증규칙을 "`MapInfos.json#name` 에 존재하고 **실제 파일로 해석**된다"([BP-22 §4.7 G-22-1] 참조)로 교체하고, T-22-1 을 선행 의존으로 명시하라.

---

## 3. 중요 결함

### F-06 상태 키 예시가 자기 STATE_KEY 정규식 위반

- 위치: 21_content_pack_spec.md:927 (§7.3 마이그레이션 예시)
- `flag.gen_ep1.quest.a.met` / `flag.gen_ep1.quest.a.met_client` — 세그먼트 `a` 는 1글자라 `[a-z][a-z0-9_]{2,47}`(최소 3자)를 만족하지 않는다. `rename_id` 예시가 문법 위반 ID 를 다루는 형태가 된다.
- 요구 조치: 예시를 `flag.gen_ep1.quest.missing_scholar.met` 같은 유효 키로 교체.

### F-07 C12 `party_level_cmp` 의 값 범위 1..21 이 실제 도달 가능 레벨과 다르다

- 위치: 21_content_pack_spec.md:663
- 문서: "`value` 1..21 (exp 테이블 21단계)"
- 실제: `player.dart:167-193` 의 `expTable` 은 **엔트리 21개(index 0..20)** 이고 승급 루프가 `while (level.physical < expTable.length - 1 && …)` 이므로 **도달 가능 최대 레벨은 20**. 값 21 은 영원히 참이 될 수 없는 조건을 허용한다.
- 요구 조치: 범위를 1..20 으로 정정하거나, "21 은 상한 초과 판정용" 이라는 의도를 명시.

### F-08 색상 태그 문법 `0-9A-F` 가 실제 파서보다 좁다 — 유효 콘텐츠를 하드 실패시킨다

- 위치: 21_content_pack_spec.md:590 ("`@` + 태그 1글자(`0-9A-F`) 로 시작 … 하드 실패")
- 실제: `lib/utils/hd_text_utils.dart:4-22` 의 `colorTable` 은 `'0'~'9'`, `'A'~'F'` **그리고 `'G'`(Amber)** 총 **17개** 키를 갖고, 파서는 `next.toUpperCase()` 로 조회하므로 **소문자 태그도 유효**하다.
- 요구 조치: 문법을 `[0-9A-Ga-g]` 로 정정하거나, `G`/소문자를 의도적으로 금지한다면 그 이유를 적을 것.

### F-09 리터럴 `@` 규칙이 실제 파서 동작과 다르다

- 위치: 21_content_pack_spec.md:593 ("리터럴 `@` 는 이스케이프 불가. 본문에 `@` 를 쓰지 말 것" — 린트 경고)
- 실제: `hd_text_utils.dart:60-64` 은 `@` 다음 문자가 태그도 `@` 도 아니면 **`@` 를 리터럴로 버퍼에 넣는다**. 즉 `@가` 같은 표기는 정상 렌더된다.
- 요구 조치: "다음 문자가 `[0-9A-Ga-g@]` 가 아니면 리터럴로 렌더된다" 로 사실 기술을 정정.

### F-10 부록 A-4(에셋 선언 비재귀) 미반영 — 정의한 디렉토리 구조가 번들에 실리지 않는다

- 위치: 21_content_pack_spec.md:61-91 (§2.1 트리), :128-129 (R-21-10)
- 문서는 R-21-10 에서 `pubspec.yaml#flutter/assets` 를 한 줄 언급할 뿐이다.
- 실제: `hadar2026_app/pubspec.yaml:65-69` 의 `assets:` 는 `assets/`, `assets/images/`, `assets/maps/`, `assets/fonts/` 4개뿐이고 Flutter 의 디렉토리 선언은 **하위를 포함하지 않는다**(부록 A-4).
- §2.1 이 정의한 레이아웃은 팩당 `world/`, `actors/`, `items/`, `quests/`, `dialogue/`, `anchors/`, `strings/`, `encounters/` 8개 + 팩 루트 + `build/` 를 요구하므로, **팩이 추가될 때마다 pubspec 에 8줄 이상을 수기로 늘려야** 한다. 이 제약이 레이아웃 설계의 입력이 되어야 했다.
- 요구 조치: §2.1 또는 §8 에 "팩 디렉토리는 pubspec 에 명시 열거가 필요하며, 그 목록 생성은 빌드가 담당한다(BP-35)" 를 R-21-nn 으로 추가.

### F-11 런타임 미정의 동작 (§1.1/§1.2 표 참조)

- 위치: 21_content_pack_spec.md:648-685, :725-764
- C6/C7 만 "없는 플래그 → false", "없는 변수 → 0" 을 명시하고, 나머지 상태 조회 op 의 "대상이 아직 존재하지 않을 때" 가 비어 있다. 특히 **C10 `quest_stage` 가 `inactive`/`completed` 퀘스트에 대해 무엇을 돌려주는가**는 조건부 대화 라우팅(BP-22 §5.5)이 매 상호작용마다 평가하는 값이므로 반드시 정해져야 한다.
- Effect 쪽도 E14(맵 로드 실패), E15(좌표 범위 밖), E16(인카운터 부재), E13(미선언 상태) 의 런타임 동작이 없다. §6.1 은 "만나면 `StateError` 로 즉시 실패" 라고 했으나 이는 **미지의 op/do** 에 대한 규칙이지 인자 오류에 대한 규칙이 아니다.
- 요구 조치: §6.3/§6.6 표에 "런타임 미정의 입력" 열을 추가하고 40개 전량을 채울 것.

### F-12 E15 `change_tile` 의 실효 범위·명칭이 코드와 어긋난다

- 위치: 21_content_pack_spec.md:743, :761-762
- (a) 문서는 `tile` 을 A5 인덱스 0..127 로 정의하는데, 이는 `map_model.dart:37-42 setTile()` 이 `unit.ixTile` 만 바꾸는 것과 일치한다 ✅. 그러나 `tile_properties.dart:196-202 getUnitAction` 은 **`ixObj1` 을 먼저 본다**. 따라서 objUpper 에 오브젝트가 있는 칸은 `change_tile` 로 통행 상태를 바꿀 수 없다. "유골 앞 비밀 통로"(라인 761) 같은 대표 용례가 실제로는 objUpper 조작을 요구할 수 있다.
- (b) "WorldState 의 **타일 오버라이드 맵**에 쌓인다" 는 표현이 기존 `MapModel.tileOverrides`(`map_model.dart:21`)와 이름이 겹치는데, 기존 필드는 **좌표별 오버라이드가 아니라 타일 id → 타일 id 전역 리맵**이다(`world_map_renderer.dart:123` 이 `tileOverrides[logicalTileId] ?? logicalTileId` 로 읽는다. `Tile::CopyTile` 계열이 채운다).
- 요구 조치: (a) objUpper 를 못 건드린다는 제약을 명시하거나 `layer` 인자 추가를 v2 후보로 남길 것. (b) 새 구조의 이름을 `mapDelta` 등으로 바꿔 기존 필드와 구분할 것.

### F-13 §6.5 `evalPath` 예시가 구조적으로 성립하지 않는다

- 위치: 21_content_pack_spec.md:707
- `"dlg.gen_ep1.guard_intro#node.intro.entry[2].args[1]"` — `entry` 는 Dialogue 최상위 필드(D-07)이므로 `node.intro` 아래에 올 수 없다. BP-26 §5.3(26:533-535)이 같은 표기법을 쓴다고 선언하므로 예시 오류가 전파된다.
- 요구 조치: `#entry[2].args[1]` 또는 `#node.intro.onEnter[0]` 형태로 수정.

### F-14 하드 규칙에 검사 ID 가 없어 소유자가 공백이다

- 위치: 21_content_pack_spec.md:1025 (§9.2 "이 장이 '린트 경고' 로 표시한 항목의 규칙 번호·심각도·메시지" 만 BP-33 에 위임)
- §6 의 하드 실패 규칙(R-21-28/29/38/39/40, ID 문법, `additionalProperties:false`, 색상 태그 균형 등)은 번호도 소유자도 없다. 결과적으로 BP-24 가 `DV-15~DV-20` 으로, BP-22 가 `L-22-08` 로, BP-26 이 `A-26-nn` 으로 **각자 다시 번호를 붙였다**.
- 요구 조치: 하드 규칙에도 검사 ID(`CV-nn` 등)를 부여하고 §9.2 에 "하드 규칙 포함" 을 명시할 것.

---

## 4. 개선 제안 (선택)

### S-01 `chance` 의 `% 100` 은 모듈로 편향을 낳는다
`2^64 mod 100 = 16` 이므로 0..15 구간이 미세하게 더 자주 나온다. 게임 밸런스에 영향은 없으나 "결정론 증빙" 을 표방하는 문서이므로 rejection sampling 또는 `(v * 100) >> 64` 를 쓰는 편이 서술과 어울린다.

### S-02 `enemy` 타입 접두사 부재를 §4.2 에 명시하라
BP-22 R-22-25(22:823-824)가 `enemy.*` 를 **참조 전용 ID** 로 쓰면서 "BP-21 §4.2 타입 접두사 목록에 `enemy` 가 없는 이유" 라고 적는다. 그러나 §4.4 `validateEntityId` 는 `kEntityTypes` 밖의 타입을 `bad_type` 으로 **하드 실패**시키므로, `enc.members[].enemy` 값이 검증을 통과할 수 없다. §4.2 에 "참조 전용 타입(`enemy`)" 행을 추가하거나 별도 문법을 정의하라. (상세는 REVIEW_BP-22 F-01)

### S-03 마이그레이션 DSL 이 두 벌 존재한다
BP-21 §7.3 은 `pack.json#migrations[].steps[].kind` 로 7종(`rename_id`/`rename_field`/`set_default`/`drop_field`/`retire_id`/`remap_enum`/`split_file`)을 닫는다. BP-25:763-770 은 세이브 마이그레이션에 **`op` 필드**로 6종(`rename_flag`/`rename_var`/`rename_item`/`drop_quest`/`remap_stage`/`set_default_var`)을 닫는다. 목적이 다르므로 공존은 정당하나, (a) `op` 라는 필드명이 Condition 의 `op` 와 충돌하고, (b) `rename_id` 와 `rename_flag` 의 관계가 어디에도 없다. §7.3 에 "세이브 상태 마이그레이션은 BP-25 소관이며 별도 어휘를 쓴다" 한 줄을 넣어 구분을 고정하라.

### S-04 `contentBudget.warnLineChars = 31` 의 근거를 Q-21-1 이 스스로 부정한다
문서가 이미 열린 질문으로 처리했으므로 결함은 아니나, `hd_text_utils.dart` 에 `splitToLines(text, maxWidth, baseStyle)` 가 **이미 존재**한다. M1 실측 대신 이 함수를 CLI 에서 재사용해 임계값을 산출하는 편이 D-12(평가기 공유) 원칙과 일관된다.

### S-05 `set_encounter` 의 0..10 상한 근거를 명시하라
`party.dart:79 encounter = 3` 이 기본값이고 코드에 상한이 없다. 원작 `Map::SetEncounter` 호출값 분포를 근거로 남기면 검증 규칙이 자립한다.

---

## 5. 잘된 점

- **D-05 40개 op/do 를 문자 단위로 완전히 지켰다.** 이름 추가 0 · 변경 0 · 누락 0 이고, 인자 이름(`count?`/`delta`/`percent`/`amount`/`rate`/`entryKey`/`encounterId`/`classId`/`mapName`/`placeId`)까지 전량 일치한다. §6.8 의 `do` enum 은 D-05 나열 **순서까지** 같다. SSoT 로서 가장 중요한 조건을 충족했다.
- **cm2 침묵 실패와의 대비를 설계 원리로 승격**했다(§6.1 "닫힌 집합", §6.10 대비표). GROUND_TRUTH §9 를 근거로 삼아 "미지의 이름 → 하드 실패" 를 규범으로 못박은 것은 이 기획 전체의 핵심 판단이며 잘 서술되어 있다.
- **팩 병합에서 재정의 금지(R-21-4)** 는 생성 팩이 원작을 몰래 덮는 사고를 원천 차단하는 강한 선택이고, Q-21-4 에서 그 뻣뻣함까지 자각하고 있다.
- **코드 인용 정확도가 높다.** §5.5 의 콘솔 수치(512/320/16/1.2/13), §6.3 의 `isAvailable()`/`getClassName`/`level.physical`, §6.6 의 `maxEnemy`/`gold`/`food`, §6.7 의 `_isScriptRunning`(라인 34 정확), §8 의 "`books.json` 은 탭" 까지 전부 실측과 맞았다.
- **`take_item` 0 클램프(E6)** 처럼 "하드 실패로 두면 이미 팔아버린 퀘스트 아이템 때문에 게임이 죽는다" 는 운영 감각이 근거와 함께 적혀 있다. 이런 실패 경로 서술이 더 많았다면 C축 점수가 달라졌다.
- **미확정 표현이 사실상 0**이다(`적절히`/`TBD`/`추후` grep 결과 무해한 1건). 산문 대신 표로 밀어붙인 서술 방식이 규약을 잘 따른다.

---

## 6. 다른 장에 전파해야 할 발견

| # | 대상 | 내용 |
|---|---|---|
| P-01 | **BP-26** | §8.2 6단계가 지시하는 문자열 키 형식(`str.<pack>.dlg.<slug>.node.intro.line.<n>`)과 §8.3 산출 예시가 F-01 의 정규식 위반을 그대로 생성한다. BP-21 문법 확정 전까지 이관 도구를 구현하면 안 된다 |
| P-02 | **BP-25 / BP-27** | F-03 — `chance` 의 재현 기준이 BP-21(경로 해시) / BP-27(`seed`+`rngCursor`) / D-08a 문언(`seed`+`step`) 3자로 갈라져 있다. BP-27 Q-27-4 는 R-21-34 와 **정반대 결론**을 적고 있으므로 반드시 조정 필요 |
| P-03 | **BP-25** | §4.4 의 "지연 효과 2개 이상이면 첫 개만 실행" 은 BP-21 에 없는 규약이다. SSoT 로 흡수하거나 BP-21 이 명시 위임해야 한다 |
| P-04 | **BP-22** | R-22-20 이 BP-21 R-21-40 에 대한 예외(`teleport_ball` 의 `warp`)를 스스로 선언했다. SSoT 침범이므로 BP-21 §6.7 에 아이템 컨텍스트를 추가해 회수할 것 |
| P-05 | **BP-23** | §23.5.2 전이표(T1/T6)가 `startedAt:now` / `updatedAt` 을 쓴다. **D-08a 는 벽시계를 금지하고 `startedStep`/`updatedStep` 을 확정**했다. 용어를 `step` 스냅샷으로 바꿔야 한다 (BP-25 는 이미 `step` 스냅샷으로 해석해 두었으므로 BP-23 만 뒤처져 있다) |
| P-06 | **BP-23** | 23:963-964 가 `warp`/`start_battle`/`play_dialogue` 를 `onComplete` 에 두라고 권장하는데, 이것이 F-02 의 V1 경로를 만든다. BP-21 규칙 확정 후 재검토 필요 |
| P-07 | **BP-22 / BP-33** | F-05 의 맵 이름 해석은 BP-22 R-22-11 · T-22-1 이 이미 정답을 갖고 있다. BP-21 이 그 표현을 채택하면 세 문서가 한 규칙을 공유한다 |
| P-08 | **BP-35** | F-10 — `pubspec.yaml#flutter/assets` 의 비재귀 열거를 빌드가 생성하도록 명시할 것 (부록 A-4) |

---

## 7. 결정 재검토 요청 (기록만 — 결정은 유지)

| # | 대상 결정 | 관측된 문제 | 제안(참고용) |
|---|---|---|---|
| DR-01 | **D-08a** | "BP-27 의 `WorldRng` 는 `seed` + `step` 으로 재현" 이라는 문언이, BP-25/BP-27 이 실제로 채택한 `seed` + `rngCursor` 와 다르다. `step`(월드 이벤트 수)과 `rngCursor`(난수 소비 수)는 증가 시점이 달라 서로를 대체할 수 없다 | D-08a 파급 절에 `rngCursor` 를 명시하거나, `chance` 만 경로 해시를 쓴다는 예외를 D-05 에 부기 |
| DR-02 | **D-05** | 닫힌 집합이 `time_of_day` 를 포함하는데 게임에 시간대가 없다(D-16 선택 항목). BP-21 Q-21-2 가 "D-05 가 확정 목록에 포함시켰으므로 유지" 로 종결했으나, 결과적으로 **v1 스키마에 영원히 `day` 만 반환하는 op** 가 남는다 | 결정 유지. 다만 D-16 의 "시간대" 선택 항목과 D-05 의 `time_of_day` 를 한 줄로 연결해 두면 후속 혼선이 줄어든다 |
| DR-03 | **D-05** | 전투 **결과**를 조건으로 읽는 op 가 없다. 부록 B-2 는 Dart 의 `_battleResult`(1 Win/0 Lose/2 Run)와 `const.cm2` 의 `BATTLERESULT_*`(0 EVADE/1 WIN/2 LOSE)가 **정반대**임을 확인했고 "정본을 먼저 정해야 한다" 고 남겼다. 현재 DSL 로는 콘텐츠가 패배/도주를 구분할 수 없다 | 결정 유지. BP-27 이 `battle_won` 이벤트로 우회하도록 설계했으므로, 그 이벤트의 3값 구분 여부를 BP-27 에서 확정하고 BP-21 이 참조만 하면 된다 |

---

## 8. 판정 근거 요약

| 축 | 점수 | 근거 |
|---|---|---|
| A 사실 정확성 | **3** | 인용 16곳 중 오류 0(±2행 1건). 그러나 색상 태그 집합(F-08), 리터럴 `@`(F-09), 레벨 상한(F-07), 부록 D 전제(F-05)의 4건이 실측과 어긋난다 |
| B 결정 정합성 | **3** | D-05 40개 이름 완전 일치는 만점급. 그러나 D-08a 의 `step` 규약과 `chance` 가 불일치(F-03)하고, 부록 D·부록 A-4 의 확정 사실을 전제에 반영하지 않았다 |
| C 구현 가능성 | **2** | 문자열 키 문법이 자기 예시 8/9 를 거부(F-01) → 이 장만 보고 문자열 시스템을 구현할 수 없다. 스키마 발췌가 필수 인자를 강제하지 못하고(F-04), 40개 중 29개의 런타임 미정의 입력 동작이 비어 있다(F-11). 꼬리 호출 규칙의 적용 단위가 실행 단위와 다르다(F-02) |
| D 완결성 | **3** | 팩·ID·문자열·DSL·버전·포맷까지 담당 절은 모두 있다. 그러나 중첩 Effect 배열, 아이템 사용 컨텍스트, 에셋 번들링(F-10)이 빠졌다 |
| E 검증 가능성 | **3** | 하드/린트 구분은 일관되나 하드 규칙에 검사 ID 가 없어 소유자가 공백(F-14)이고, 대응 테스트가 하나도 지정되지 않았다 |
| F 비중복·연결성 | **5** | 링크 13개 전량 유효. DSL 을 다른 장이 재정의하지 않도록 §0 에서 SSoT 를 선언했고 실제로 BP-22/BP-26 은 참조만 한다 |
| G 문서 규약·분량 | **5** | 1039줄(권장 350~600 초과), 메타 블록·`R-21-nn`/`Q-21-n` 접두사·표 중심 서술·말미 3절 요약 전부 충족 |

**총점 24/35**, C축 2점 → 루브릭 합격선(전 축 3 이상 & 총점 26 이상) 미달. **수정 필요**.

우선순위: **F-01 → F-02 → F-03 → F-05 → F-04** 순으로 처리하면 C축이 4, B축이 4 로 올라가 합격선(28~30)에 도달한다.
