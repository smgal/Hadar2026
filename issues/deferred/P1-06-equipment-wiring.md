# P1-06 장비 배선 — `powOfWeapon` 덮어쓰기 · `ac` 합산 · `books.json` 재척도

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-05 대기)
- **구간**: P1
- **규모**: M
- **선행**: P1-05
- **설계 근거**: [BP-42 §4](../../blueprint/42_item_and_inventory.md)(**소유 장**, 특히 §4.3·§4.5 **A 갈래**) · `GROUND_TRUTH` 부록 **H-1 정정판** · **H-2 정정판** · H-3

## 문제

장비 정수 3개(`player.dart:44-46`)에 이름이 없고(`:91` 의 `"무기$weapon"`),
아이템 성능을 흘려 넣을 자리가 배선되어 있지 않다. **다만 실측이 초판 서술을 두 번 정정했으므로 정확한 사실부터 적는다.**

**① `powOfWeapon` 은 죽은 필드가 아니다 — 전투식이 실제로 읽는다** (부록 H-1 **정정판**)
```dart
// hadar2026_app/lib/application/battle.dart:439-441
int damage = (p.strength * p.powOfWeapon * p.level.physical) ~/ 20;
damage -= (damage * Random().nextInt(50)) ~/ 100;
damage -= (t.ac * t.level * (Random().nextInt(10) + 1)) ~/ 10;
```
**죽은 필드는 `powOfShield`/`powOfArmor` 2개뿐**이다(`player.dart:49-50`). 읽는 곳이 0곳이고,
등장하는 곳은 전부 대입·직렬화·속성 스위치다(`player.dart:134,136,293,294,358,361,426,427`).

**② 방어는 양쪽 모두 `ac` 하나로만 계산된다**
```dart
// hadar2026_app/lib/application/battle.dart:513-514  (파티가 맞을 때)
int damage = (e.strength * e.level * (Random().nextInt(10) + 1)) ~/ 10;
damage -= (t.ac * t.level.physical * (Random().nextInt(10) + 1)) ~/ 10;
```
즉 **아이템 성능을 `powOfWeapon` 과 `ac` 에 넣으면 전투식을 고치지 않아도 반영된다.**

**③ `books.json` 의 ac 척도가 파티 스탯 대역과 어긋난다** (부록 H-2 **정정판**)
`assets/maps/books.json` 의 `armor` 는 `두꺼운옷 ac 10.0` / `가죽갑옷 ac 20.0` 이다.
그런데 원작 파티의 초기 `ac` 는 **3~5** 다 — `party.dart:108`(슴갈 `ac = 5`), `party.dart:130`(유리 `ac = 3`).
**재척도의 근거는 "전투가 무효화되기 때문" 이 아니다.** 부록 H-2 초판의 그 서술은 과장이었고 정정되었다
(ac 20 에서도 16% 턴에 최대 7 피해가 들어간다 — 무효화가 아니라 강한 감쇠다).
**진짜 근거는 기존 파티 스탯 대역(3~5)과 맞추기 위해서**다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** P1-05 가 아이템을 만들어도 장비가 배선되지 않으면
"좋은 검을 보상으로 준다" 가 **관측 불가능한 보상**이 된다. 플레이어가 장착해도 아무 변화가 없으면
퀘스트 보상 티어표([BP-23 §23.9.3](../../blueprint/23_quest_model.md))가 의미를 잃고,
저작자는 보상 밸런스를 조정할 근거를 갖지 못한다.

또 하나: 이 이슈는 **작업량이 매우 작은데 효과가 즉시 보인다.** 전투식을 건드리지 않기 때문이다.

## 무엇을 할 것인가

**[BP-42 §4.5](../../blueprint/42_item_and_inventory.md) 의 A 갈래를 채택한다. B 갈래(전투식 변경)는 범위 밖이다.**

1. **`HDPlayer` 필드 확장** — [BP-42 §4.1](../../blueprint/42_item_and_inventory.md).
   `weapon`/`shield`/`armor` 정수 옆에 **아이템 ID 필드**를 추가한다. 정수 필드는 레거시 cm2 의
   `Player::GetAttribute`/`ChangeAttribute` 호환을 위해 남긴다.
2. **`power` → `powOfWeapon` 덮어쓰기** (R-42-29).
   장착 시 아이템의 `equip.power` 를 `HDPlayer.powOfWeapon` 에 **대입**한다. 가산이 아니다 —
   `battle.dart:439` 가 이 값을 곱셈 인자로 쓰므로 누적하면 밸런스가 폭주한다.
   해제 시 맨손 값으로 되돌린다.
3. **갑옷 + 방패 `ac` 합산** (R-42-30).
   `armor.equip.ac + shield.equip.ac` 를 `HDPlayer.ac` 의 장비 기여분으로 더한다.
   방패를 별개 축(막기 확률 등)으로 두지 **않는다** — 그것이 B 갈래이고 전투식 변경이 선행이다.
   대가는 "방패와 갑옷이 서로 대체 가능해진다" 이고, R-42-55(방패 상승 폭 ≤ 갑옷의 절반)가 그 대가를 관리한다.
4. **`powOfArmor`/`powOfShield` 는 표시용 사본만 채운다** (R-42-31).
   전투가 읽지 않는다는 사실을 **코드 주석에 명시**한다. P0-19 가 이미 그 명시를 시작하므로
   그 주석에 "장비 배선은 사본만 쓴다" 를 덧붙인다.
5. **`books.json` ac 재척도** — 10/20 → **2/5**([BP-42 §7.4](../../blueprint/42_item_and_inventory.md) 카탈로그).
   커밋 메시지와 코드 주석의 근거 문장은 반드시 **"원작 파티 초기 `ac` 3~5 대역과 맞추기 위해"** 로 적는다.
   "무효화되기 때문" 이라고 쓰지 않는다(부록 H-2 정정판).
6. **`books.json` → 아이템 ID 매핑표** — [BP-42 §4.2·§4.4](../../blueprint/42_item_and_inventory.md).
   두 id 공간이 다르다는 부록 H-3 을 **선언적 매핑 데이터**로 해소한다. 추측 주석을 남기지 않는다.
7. **`showCharacterStatus()` 반영** — `hadar2026_app/lib/application/menu_flows.dart:228` 의
   `showCharacterStatus()` 가 `getWeaponName()` 대신 아이템 이름을 보여주게 한다
   ([BP-42 §5.5](../../blueprint/42_item_and_inventory.md)).

## 완료 판정 기준

- [ ] 무기를 장착하면 `battle.dart:439` 의 데미지가 실제로 변한다 (장착 전후 같은 시드로 비교해 차이가 관측된다)
- [ ] 갑옷 + 방패를 장착하면 `HDPlayer.ac` 가 두 `equip.ac` 의 합만큼 증가한다
- [ ] 장착·해제를 3회 반복해도 `powOfWeapon` 이 누적되지 않는다 (대입 semantics)
- [ ] `books.json` 의 armor ac 가 2/5 이고, 변경 근거 주석이 "파티 초기 ac 3~5 대역" 을 말한다
- [ ] `battle.dart:439-441` 과 `:513-514` 의 **두 식이 한 글자도 바뀌지 않았다** (A 갈래의 정의)
- [ ] `powOfShield`/`powOfArmor` 가 여전히 어떤 전투 규칙도 읽지 않으며, 그 사실이 주석에 있다
- [ ] `showCharacterStatus()` 가 `"무기1"` 대신 아이템 표시명을 보여준다
- [ ] **테스트 1**: `hadar2026_app/test/domain/party/equipment_test.dart` —
      장착/해제의 `powOfWeapon` 대입·복원, `ac` 합산, 반복 장착 비누적을 고정
- [ ] **테스트 2**: `hadar2026_app/test/application/battle_equipment_test.dart` —
      **회귀** — 시드를 고정하고 장비만 바꿔 데미지 변화가 `powOfWeapon` 한 자리에서만 나온다는 것을 고정.
      P0-11(시드 없는 `Random()` 14곳 제거)이 선행 조건이므로 그 시드 주입 지점을 재사용한다

## 하지 않을 것

- **전투식 변경 — B 갈래 전부**: 방패를 별개 축으로 두기, `weaponType` 상성, 부위별 감쇠, 마법 방어.
  `battle.dart:439-441`·`:513-514` 를 건드리지 않는다([BP-42 §4.5](../../blueprint/42_item_and_inventory.md) R-42-33d).
- `weaponType`·`value`·`grade` 를 런타임이 읽게 만드는 것 — 현행 빌드에서 무효 필드로 남긴다(R-42-33e).
  "이 수치가 전투를 바꾼다" 고 쓰지 않는다.
- 상점·매매(`value` 소비 경로) — 범위 밖.
- 소지품·장비 **UI** — P1-14.
