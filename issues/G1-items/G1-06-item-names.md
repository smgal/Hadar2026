# G1-06 `"무기1"` 을 실제 이름으로 바꾼다 (노출 4곳)

- **상태**: TODO
- **구간**: G1
- **규모**: S
- **선행**: [G1-02](G1-02-item-data.md)
- **설계 근거**: [`GROUND_TRUTH` 부록 H-3](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.5](../MILESTONES.md) · [DECISION-LOG 3차 판정](../DECISION-LOG.md)

## 문제

### 플레이스홀더가 플레이어에게 보인다

`hadar2026_app/lib/domain/party/player.dart:91-93`:
```dart
String getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon";
String getShieldName() => shield == 0 ? "없음" : "방패$shield";
String getArmorName() => armor == 0 ? "평상복" : "갑옷$armor";
```

파티 초기값이 `weapon = 1`(`party.dart:104`, `:126`)이므로 **게임을 켜면 바로 `"무기1"` 이 보인다.**

### 노출 4곳 (전수 확인)

| # | 위치 | 문장 |
|---|---|---|
| 1 | `lib/application/battle.dart:285-286` | `String wName = p.getWeaponName();` → `"한 명의 적을 $wName${_getJosaRo(wName)} 공격"` — **전투 메뉴 2번째 항목** |
| 2 | `lib/application/battle.dart:453` | `"${p.name}${p.name.sub1} ${p.getWeaponName()}${_getJosaRo(p.getWeaponName())} ${t.name}${t.name.obj} 공격하여 $damage 데미지!"` — **매 턴 전투 로그** |
| 3 | `lib/application/menu_flows.dart:275` | `"사용 무기 - ${player.getWeaponName()}"` — 개인 상황 화면 |
| 4 | `lib/application/menu_flows.dart:277` | `"방패 - ${player.getShieldName().padRight(12)} 갑옷 - ${player.getArmorName()}"` — 같은 화면 |

### 원작에는 이름 테이블과 **조사 정보**가 함께 있다

`REF_hadar/src/hadar/hd_res_string.cpp:38-88` — 무기 10 / 방패 6 / 갑옷 6 이름 + `RETURN_HAN_STRING` 매크로(`:10-35`)가
항목별로 조사 4종(`은/는`·`이/가`·`을/를`·`으/∅`)을 함께 돌려준다. 종성 유무를 **비트셋으로 명시**한다:
`getWeaponName` 은 `"0,2..4,6..9"`, `getArmorName` 은 `"0..5"` + 기본 종성 있음.

## 왜 지금 고쳐야 하는가

- **재미** — 3차 판정이 이 4곳을 "플레이어에게 보이는 미완성" 으로 지목했다. G1 에서 **가장 눈에 보이는 성과**다.
- **부채 방지** — `_getJosaRo` 가 `getWeaponName()` 을 **두 번 호출**하고(`battle.dart:453`) 문자열을 재파싱한다. 아이템 이름이 실데이터가 되면 조사가 실제로 갈리기 시작하므로(`활` → `로`, `장검` → `으로`) 여기서 정리하지 않으면 오조사가 로그마다 남는다.

## 무엇을 할 것인가

### 이식 대응표

| 원작 | Dart |
|---|---|
| `hd_res_string.cpp:38-56` 무기 이름 표 | [G1-02](G1-02-item-data.md) 의 `item_data.dart` 조회 |
| `hd_class_pc_player.cpp:302-315` `getWeaponName()` | `player.dart:91-93` 을 `equip[hand]` 조회로 교체 |
| `hd_res_string.cpp:16` `NAME_UNKNOWN` ("불확실한 무기") | 조회 실패 시 폴백 문자열. **침묵하지 않는다** — 부록 F-1 계열의 재발 방지 |
| `RETURN_HAN_STRING` `:18-33` 조사 4종 | `HDNoun`(`lib/domain/text/noun.dart:12-27`) 재사용 |

### 조사 처리 — `_getJosaRo` 를 `HDNoun` 으로 흡수한다

`battle.dart:71-80` 을 읽었다. 규칙은 종성 인덱스 기반이다:
```dart
int jongsung = (lastCode - 0xAC00) % 28;
if (jongsung == 8) return "로";        // ㄹ 받침 → "로"
return jongsung > 0 ? "으로" : "로";
```
실데이터로 검산했다 — `활`(ㄹ) → `로`, `장검`(ㅁ) → `으로`, `철퇴`(무받침) → `로`, `삼지창`(ㅇ) → `으로`, `블로우 파이프`(무받침) → `로`. 규칙은 맞다.

문제는 **위치**다. `HDNoun` 은 이미 `sub1`/`sub2`/`obj`/`conj` 4종을 갖는데(`noun.dart:14-23`) `으로/로` 만 없어서
`battle.dart` 가 사설 함수를 들고 있고, `getWeaponName()` 을 두 번 호출한다.
원작은 이것을 `sz_josa_with`(`hd_res_string.cpp:25`, `:32`)로 **같은 테이블에** 둔다.

→ `HDNoun` 에 `withJosa`(`으로`/`로`, ㄹ 받침 예외 포함)를 추가하고 `_getJosaRo` 를 폐기한다.
아이템 이름은 `HDItem.name` 을 `HDNoun` 으로 감싸 제공한다.

### `menu_flows.dart:277` 의 `padRight(12)` — 실데이터에서 깨진다

현행 값 12 는 `"방패1"`(3자)·`"없음"`(2자) 기준이다. 실데이터 최장은 `"불확실한 방패"`(7자) / 확장분 `"양날 전투 도끼"`(8자)다.
게다가 콘솔 폰트는 한글이 2배폭이므로(`hd_config.dart:14-16` 콘솔 512×320 / 폰트 16) **문자 수 기준 패딩 자체가 근사값**이다.

→ 두 가지 중 하나를 고른다. 판정 기준은 "정렬이 깨지지 않는다" 뿐이다.
- **A(권고)**: 한 줄에 하나씩 — `"방패 - X"` / `"갑옷 - Y"` 두 줄. 부위가 6칸으로 늘면([G1-04](G1-04-equipment-slots.md)) 어차피 한 줄에 못 담는다.
- B: `padRight` 값을 실데이터 최장 이름 + 1 로 재산정. 부위 확장 때 또 손대야 한다.

## 완료 판정 기준

- [ ] `getWeaponName()`/`getShieldName()`/`getArmorName()` 이 [G1-02](G1-02-item-data.md) 의 표에서 이름을 가져온다
- [ ] 위 노출 4곳에서 **`"무기N"`/`"방패N"`/`"갑옷N"` 형태가 하나도 나오지 않는다** — `grep -rn '무기\$\|방패\$\|갑옷\$' lib/` 0건
- [ ] 표에 없는 index 는 `"불확실한 무기"` 계열 폴백을 내고 **경고 로그**를 남긴다 (조용히 빈 문자열이 되지 않는다)
- [ ] `HDNoun.withJosa` 가 추가되고 `battle.dart:71-80` `_getJosaRo` 가 **삭제**되었으며, `:286`·`:453` 이 `HDNoun` 을 쓴다
- [ ] `battle.dart:453` 이 `getWeaponName()` 을 **한 번만** 호출한다
- [ ] `menu_flows.dart:277` 이 실데이터 최장 이름에서도 정렬이 깨지지 않는다 (A 안이면 두 줄로 분리)
- [ ] 테스트 추가:
      `hadar2026_app/test/domain/text/noun_test.dart` (기존 파일 확장) — `withJosa` 를 `활`/`장검`/`철퇴`/`삼지창`/`블로우 파이프`/빈 문자열/비한글 로 고정. **ㄹ 받침 예외**를 별 케이스로 고정한다
      `hadar2026_app/test/domain/item/item_name_test.dart` — 무기 10종 이름을 리터럴로 고정, 범위 밖 index 가 폴백을 내는 것을 고정
- [ ] 기존 `test/domain/console/text_utils_test.dart` 통과

## 하지 않을 것

- 전투 로그 문장 자체의 재작성 — 조사만 고치고 문구는 그대로 둔다.
- `HDNoun` 의 다국어화 — `noun.dart:9-11` 이 이미 "시스템 언어 개념이 들어오면" 을 남겨 뒀다. 지금은 한국어 규칙만.
- 원작 조사 비트셋(`"0,2..4,6..9"`)의 **수동 표 이식** — `HDNoun` 이 종성으로 자동 판정하므로 불필요하다. 다만 자동 판정과 원작 표가 어긋나는 항목이 있으면 그 항목만 예외로 적는다.
- 부위 6칸 표시(`HEAD`/`LEG`/`ORNAMENT`) — [G1-07](G1-07-inventory-ui.md) 소관.
- 이름 색상 코드(`@7` 등)·아이콘·설명문.
- 상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI.
