# G1-02 아이템 실데이터를 확보한다 (`books.json` 은 무기5·방어구3 샘플뿐)

- **상태**: TODO
- **구간**: G1
- **규모**: M
- **선행**: [G1-01](G1-01-item-model-port.md)
- **설계 근거**: [`GROUND_TRUTH` 부록 H-2(정정판) · H-3](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.5](../MILESTONES.md)
- **참고만**: [BP-42 §7.4 카탈로그 20종 초안](../../blueprint/42_item_and_inventory.md) — 보류 노선의 산출물이므로 **수치 감각만** 참고한다.

## 문제

### `books.json` 은 실데이터가 아니다

`hadar2026_app/assets/maps/books.json` 을 직접 읽었다. `weapon` **5개**(맨손·단도·단검·단창·작은도끼), `armor` **3개**(맨몸·두꺼운옷·가죽갑옷). 방패는 아예 없다.
`REF_UNITY_LoreEp1/map_as_text/books.json` 과 **바이트 동일**하다 → 이식 과정에서 그대로 복사된 샘플이다.

두 가지를 더 확인했다:
- **앱이 이 파일을 읽지 않는다.** `grep -rn "books" hadar2026_app/lib/ hadar2026_app/pubspec.yaml` → **0건**.
- 원작의 로더도 죽어 있다 — `REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs:260-357` `LoadItemListFromJson()` 은 **전체가 주석 처리**되어 있고, 실제로 도는 것은 `:613-666` `LoadItemList()` — **소스에 하드코딩된 4개 테이블**이다.

부록 H-3: `books.json` 의 `weapon[].id` 는 `HDPlayer.weapon` 정수와 **별개 공간**이다. 두 공간을 같다고 가정한 근거는 없다.

### 원작의 실데이터는 두 곳에 하드코딩되어 있다

**(1) C++ 원본** — `REF_hadar/src/hadar/hd_res_string.cpp:38-88` (CP949, `iconv` 로 읽음):

```cpp
HanString hadar::resource::getWeaponName(int index) {
    const char* NAME_UNKNOWN = "불확실한 무기";
    const char* NAME[] = { "맨손","단도","곤봉","미늘창","장검","철퇴","기병창","도끼창","삼지창","화염검" };
    RETURN_HAN_STRING("0,2..4,6..9", false)      // ← 조사 정보까지 테이블에 있다
}
```
같은 파일 `:58-72` 방패 6종(없음·가죽·청동·강철·은제·금제), `:74-88` 갑옷 6종(없음·가죽·청동·강철·은제·금제).

**이 인덱스 공간이 현재 Dart 정수 3칸의 공간이다.** `REF_hadar/src/hadar/hd_class_pc_player.cpp:302-315`:
```cpp
const char* hadar::PcPlayer::getWeaponName(void) const { return resource::getWeaponName(weapon).sz_name; }
```
`hd_class_pc_player.h:60-62` 이 `int weapon; int shield; int armor;` — Dart `player.dart:44-46` 과 1:1 대응이다.

**(2) Unity 포트** — `REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs` 에 수치가 있다:

| 테이블 | 줄 | 항목 수 | 담긴 값 |
|---|---|---|---|
| `WEAPON_LIST` | `:384-468` | 51 | `index` · 이름 · `power`(1.0~90.0) · `ITEM_TYPE` |
| `SHIELD_LIST` | `:487-497` | 6 | `index` · 이름 · `ac` **0~5** |
| `ARMOR_LIST` | `:515-529` | 12 | `index` · 이름 · `ac` **0~10** (+ 흑요석 갑옷 20) |
| `PROPS_LIST` | `:564-601` | 33 | `HEAD` 11 · `LEG` 11 · `ORNAMENT` 11, `annex` 문자열 |

## 왜 지금 고쳐야 하는가

- **재미** — [G1-06](G1-06-item-names.md) 이 `"무기1"` 을 고치려면 이름 표가 있어야 한다. 데이터 없이는 [G1-05](G1-05-equipment-effect.md) 도 배선할 값이 없다.
- **부채 방지** — 손으로 20종을 새로 만들면 그것이 곧 정본이 되고, 나중에 원작 표를 넣을 때 **세이브에 남은 id 를 다시 사상**해야 한다. 원작 인덱스 공간을 처음부터 쓰면 그 마이그레이션이 없다.
- 부록 H-2 정정판이 요구하는 재척도가 **거의 자동으로 풀린다** — 원작 `ac` 대역이 방패 0~5 / 갑옷 0~10 이고, 파티 초기 `ac` 는 3~5(`party.dart:108,130`)다. `books.json` 의 10/20 이 튀는 값이었다.

## 무엇을 할 것인가

### 확보 선택지 비교

| # | 방법 | 비용 | 정확도 | 원작 충실도 | 판정 |
|---|---|---|---|---|---|
| (a) | **원작 바이너리 추출** | — | — | — | **불가.** `REF_hadar/bin/` 을 전수 확인했다: `*.MAP`·`*.cm2`·`gamedat*.sav`·`*.bmp`·`hadar_project.exe` 뿐이고 **아이템 데이터 파일이 없다.** 이름·수치가 실행 파일에 컴파일되어 들어가 있어 추출 대상이 존재하지 않는다 |
| (b) | **소스 하드코딩 테이블 이식** | 낮음 — `tools/convert_enemy.py` 와 **같은 작업**(C++ 소스에서 표를 뜯어 Dart `const` 로) | 높음 — 원문을 그대로 옮김 | **최고** | **권고** |
| (c) | 손으로 작성 | 중간 — 20종에 이름·수치·등급을 창작 | 낮음 — 밸런스를 짐작 | 낮음 | 보조 수단으로만 |

**(a) 가 왜 불가인지 한 번 더**: `tools/` 의 선례를 확인했다. `tools/convert_enemy.py:5-8` 은
`hd_class_pc_enemy.cpp` 의 `static hadar::EnemyData s_enemy_data[75]` 를 **소스에서** 파싱해 `hd_enemy_data.dart` 를 만든다.
즉 이 레포에 이미 있는 "원작 데이터 추출" 선례가 **바이너리 추출이 아니라 소스 테이블 추출**이다. 아이템도 같다.

### 권고안 — (b), 2단계

**1단계: 현행 정수 3칸을 원작 이름으로 채운다** (= [G1-06](G1-06-item-names.md) 가 필요한 최소치)

`hd_res_string.cpp:38-88` 의 무기 10 / 방패 6 / 갑옷 6 을 **이름의 정본**으로 삼고,
`ObjItem.cs` 에서 **수치**를 가져와 결합한다. 이름이 갈리는 곳은 **C++ 우선**(원본이므로):

| 축 | C++ (정본 이름) | Unity (수치 출처) | 처리 |
|---|---|---|---|
| 무기 | 맨손·단도·곤봉·미늘창·장검·철퇴·기병창·도끼창·삼지창·화염검 | 같은 이름이 `WIELD`/`CHOP`/`STAB`/`HIT`/`SHOOT`/`SUMMON_SINGLE` 에 분산 | 이름으로 매칭해 `power` 를 끌어온다. **`미늘창` 은 Unity 에서 `핼버드`(CHOP index 7, power 80)로 개명**되어 있으니 이름은 C++ 을, 수치는 그 항을 쓴다 |
| 방패 | 없음·가죽·청동·강철·은제·금제 | 없음·가죽·소형 강철·대형 강철·크로매틱·플래티움 (`ac` 0~5) | 이름은 C++, `ac` 는 index 대응으로 0~5 |
| 갑옷 | 없음·가죽·청동·강철·은제·금제 | 평상복·가죽·링 메일·체인 메일·미늘·브리간디… (`ac` 0~11) | 이름은 C++, `ac` 는 index 0~5 → 0~5. **index 0 은 현행 Dart 가 이미 `"평상복"`**(`player.dart:93`)이므로 이 하나만 Unity 를 따른다 |

**2단계: 부위 확장분을 Unity 에서 그대로 가져온다** ([G1-04](G1-04-equipment-slots.md) 가 슬롯을 만든 뒤)

`ObjItem.cs:564-601` `PROPS_LIST` 33종을 `HEAD`/`LEG`/`ORNAMENT` 에 그대로 넣는다.
`annex` 문자열(`"ATT+1AC-1STR+1"`, `"INT-2"`, `"STR+100"`)은 **문자열로 보관만** 한다(G1-01 결정).
`"다리6"`·`"장식A"` 같은 원작의 미완성 이름도 **그대로 옮긴다** — 창작하지 않는다. 채우는 것은 별건이다.

### 산출 형식 — Dart `const` 테이블

`assets/items.json` 이 아니라 `lib/domain/item/item_data.dart` 의 `const List<HDItem>` 으로 만든다. 근거:

- 선례가 그렇다 — `lib/domain/battle/enemy_data.dart:33` `const List<HDEnemyData> enemyTable` (75종).
- 에셋으로 두면 `AssetSource` 를 경유해야 하고(비동기), 아이템 조회는 `getWeaponName()` 처럼 **동기 호출** 지점이 많다.
- 부록 A-4(에셋 선언 비재귀)·B-5(웹 페이로드) 를 건드리지 않는다.

추출 스크립트는 `tools/convert_item.py` 로 남긴다 — `convert_enemy.py` 와 같은 형식이라 원작 표가 정정되면 재생성이 가능하다.

`books.json` 은 **지우지 않고 그대로 둔다.** 참조 0건이므로 무해하고, 지우면 참조본과의 diff 가 생긴다.
대신 `item_data.dart` 헤더 주석에 "이 표의 출처는 `books.json` 이 아니다(부록 H-3)" 를 남긴다.

## 완료 판정 기준

- [ ] `lib/domain/item/item_data.dart` 에 무기 10 · 방패 6 · 갑옷 6 이 있고, 이름이 `hd_res_string.cpp:38-88` 과 **문자 단위로 일치**한다 (갑옷 index 0 `"평상복"` 만 예외, 근거를 주석으로 남긴다)
- [ ] 각 항의 `attaPow`/`ac` 가 `ObjItem.cs` 의 해당 항 수치와 일치하고, **출처 줄 번호가 주석**에 있다
- [ ] 방패 `ac` 최대 5, 갑옷 `ac` 최대 5 — 파티 초기 `ac` 3~5(`party.dart:108,130`) 대역 안이다 (부록 H-2 정정판의 재척도 근거)
- [ ] `HEAD` 11 · `LEG` 11 · `ORNAMENT` 11 이 `PROPS_LIST` 와 이름·`annex` 문자열까지 일치한다
- [ ] `tools/convert_item.py` 를 다시 돌리면 같은 파일이 나온다 (멱등)
- [ ] 테스트 추가: `hadar2026_app/test/domain/item/item_data_test.dart` —
      ① `HDItemId.wire` 중복 0건 (원작 `RegisterItem` 의 중복 검사(`ObjItem.cs:249-256`)를 테스트로 대체)
      ② 무기 10종 이름 배열을 **리터럴로** 고정 — 원작 표에서 이탈하면 실패
      ③ 모든 `HDItemType` 에 `index == 0` 항("맨손"/"없음"/"평상복")이 존재
      ④ 방패·갑옷 `ac` 가 0~5 범위 안 (재척도 이탈 감지)

## 하지 않을 것

- `books.json` 삭제·수정·앱 로딩. 참조 0건이므로 건드리지 않는다.
- `WEAPON_LIST` 51종 전량 이식 — 1단계는 **원작 C++ 의 10종**이 정본이다. 나머지는 부위 확장(2단계) 이후에도 필요해질 때 꺼낸다.
- 소환수 기술 21종의 `power` — 원작도 `ObjItem.cs:603-611` 에서 TODO 로 남긴 미완성이다. 전부 10.0 인 값을 그대로 옮기고 창작하지 않는다.
- 클래스별 무기 보정치 — `ObjItem.cs:395-406` 의 7×7 표는 주석 상태이고 Dart 에 스킬 시스템이 없다.
- 등급(`grade`)·가격·상점 재고 — 상점은 범위 밖이다.
- 아이콘·설명문(`etc_description`) — 800×480 콘솔 UI 에 그릴 자리가 없다([G1-07](G1-07-inventory-ui.md) 참조).
- 무게·제작·강화·선언적 콘텐츠 팩·저널 UI.
