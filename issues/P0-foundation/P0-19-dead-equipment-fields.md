# P0-19 `powOfShield`/`powOfArmor` 가 죽은 필드임을 코드에 명시한다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 H-1 (**정정판**) · H-2 · H-3](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-42 아이템·인벤토리](../../blueprint/42_item_and_inventory.md)

## ⚠ 근거 주의 — 죽은 필드는 **2개**다

부록 H-1 은 **정정판**이다. 초판은 `powOfWeapon`/`powOfShield`/`powOfArmor` **3개 모두**가
죽은 필드라고 적었으나 **틀렸다**(검색하지 않은 것을 결론에 포함한 오류).
**`powOfWeapon` 은 실제로 읽힌다.** 죽은 필드는 `powOfShield`·`powOfArmor` **2개뿐이다.**

## 문제

### `powOfWeapon` — 살아 있다

`hadar2026_app/lib/application/battle.dart:439-441` (본인 확인):

```dart
int damage = (p.strength * p.powOfWeapon * p.level.physical) ~/ 20;
damage -= (damage * Random().nextInt(50)) ~/ 100;                 // :440  0~49% 감쇠
damage -= (t.ac * t.level * (Random().nextInt(10) + 1)) ~/ 10;    // :441  적 방어
```

즉 **플레이어 공격력의 핵심 인자**다. 초기값은 `party.dart:105`(12), `:127`(8).

### `powOfShield` / `powOfArmor` — 읽는 곳이 0곳

본인 전수 확인(`grep -rn "powOfShield" lib/ assets/`, 같은 방식으로 `powOfArmor`):

| 필드 | 등장 지점 | 성격 |
|---|---|---|
| `powOfShield` | `player.dart:49`(선언) `:134`(속성 읽기 스위치) `:293`(리셋) `:358`(속성 쓰기 스위치) `:426`(직렬화) `:463`(역직렬화) | **전부 대입·직렬화·속성 스위치** |
| `powOfArmor` | `player.dart:50, 136, 294, 361, 427, 464` + `party.dart:107`(5), `:129`(3) | 같음 |

**전투식에서 읽는 곳은 한 곳도 없다.** `assets/` 의 cm2 에서도 등장하지 않는다.

### 방어는 `ac` 하나로만 계산된다

플레이어가 맞을 때 `battle.dart:514`, 적이 맞을 때 `:441` — 둘 다 `t.ac * t.level… ` 형태이며
방패·방어구 필드는 등장하지 않는다 (플레이어는 `level.physical`, 적은 `level` 로 타입이 다르다).

`player.dart:133-136`·`:357-361` 의 속성 스위치는 cm2 의 `Player::GetAttribute`/`ChangeAttribute` 로 노출되므로
**스크립트가 값을 쓸 수는 있지만 어떤 효과도 없다.** 침묵 실패의 한 형태다.

## 왜 지금 고쳐야 하는가

- **P0 이 이 필드를 배선하지 않는다.** 배선은 [P1-06](../deferred/P1-06-equipment-wiring.md) 소관이다.
  P0 이 해야 하는 것은 **"쓰면 효과가 있다" 는 오해를 코드에서 없애는 것**뿐이다.
- 부록 H-1 정정판의 핵심 파급이 이것이다: **"장비를 쓰려면 전투식 변경이 선행" 이라는 초판 서술은 과장**이었다.
  무기는 이미 작동하고, 방어구는 `ac` 로 합산하는 방식이면 전투식 변경이 **불필요**하다.
  [P1-06](../deferred/P1-06-equipment-wiring.md) 이 설계 갈래를 고를 때 이 사실이 코드 주석으로 남아 있어야 한다.
- [P0-14](P0-14-silent-out-of-range.md) 와 같은 계열의 침묵이다 — 정상 심볼인데 아무 일도 하지 않는다.

## 무엇을 할 것인가

코드 동작을 바꾸지 않는다. **주석과 로그만** 추가한다.

### 선택지 비교

| # | 안 | 장점 | 단점 |
|---|---|---|---|
| A | **필드 선언·스위치에 `@Deprecated` 대신 주석 표기** | 변경 위험 0. 세이브 호환 유지 | 컴파일러가 강제하지 않는다 |
| B | Dart `@Deprecated('...')` 애노테이션 | 사용처에 경고가 뜬다 | 직렬화·리셋 등 **정당한 사용처에도** 경고가 떠서 `flutter analyze` 가 시끄러워진다. `--no-fatal-infos` 라 통과는 하지만 노이즈 |
| C | 필드를 **삭제**한다 | 가장 깔끔 | 세이브 호환이 깨진다(`player.dart:426-427, 463-464`). [P1-06](../deferred/P1-06-equipment-wiring.md) 이 되살릴 가능성 |

### 권고안: **A + 속성 스위치에 경고 로그**

1. `player.dart:49-50` 의 선언에 사실을 적는다:

   ```diff
   + /// DEAD FIELD — no combat formula reads this. Defence is computed
   + /// from `ac` alone (battle.dart:441, :514). 부록 H-1(정정판).
   + /// Wiring is P1-06's call; do not assume writing it has any effect.
     int powOfShield = 0;
   + /// DEAD FIELD — same as [powOfShield]. 부록 H-1(정정판).
     int powOfArmor = 0;
   ```

2. `powOfWeapon`(`:48`)에는 **반대 사실**을 적는다 — 초판 오류가 재발하지 않게:

   ```diff
   + /// LIVE FIELD — read as the player's attack power at
   + /// battle.dart:439. Item weapon power can be written here and it
   + /// takes effect without changing the combat formula (부록 H-1 정정판).
     int powOfWeapon = 0;
   ```

3. `player.dart:357-361` 의 쓰기 스위치(`'pow_of_shield'`/`'pow_of_armor'`)에 **경고 로그**를 추가한다
   — 형식은 [P0-14](P0-14-silent-out-of-range.md) 의 `_warnOutOfRange` 와 같게.
4. `ac` 필드에도 "**방어의 유일한 축**" 임을 주석으로 남긴다 — [P1-06](../deferred/P1-06-equipment-wiring.md) 이 여기에 합산할 것이므로.

부수 사실도 기록한다(부록 H-3): `books.json` 의 `weapon[].id` 와 `HDPlayer.weapon` 은 **별개 정수 공간**이다.
두 공간이 같다고 가정한 주석이 있으면 그 자리에 "근거 없음" 을 명시한다.

## 완료 판정 기준

- [ ] `powOfShield`·`powOfArmor` 선언에 **"전투식에서 읽지 않는다"** 는 사실과 부록 H-1 참조가 적혀 있다
- [ ] `powOfWeapon` 선언에 **"battle.dart:439 가 읽는다"** 는 사실이 적혀 있다 (초판 오류 재발 방지)
- [ ] `Player::ChangeAttribute('pow_of_shield'|'pow_of_armor')` 호출이 **경고 로그를 남긴다**
- [ ] 필드가 삭제되지 않았고 직렬화 왕복이 그대로 동작한다 (기존 세이브 호환)
- [ ] `flutter analyze --no-fatal-infos` 통과, 새 경고/에러 0건
- [ ] 테스트 추가: `hadar2026_app/test/domain/party/equipment_fields_test.dart` —
      ① `powOfWeapon` 을 바꾸면 `getAttribute('pow_of_weapon')` 이 따라 변함
      ② `powOfShield`/`powOfArmor` 를 바꿔도 **`ac` 가 변하지 않음**(= 방어에 무관)
      ③ `toJson`/`fromJson` 왕복에서 3필드가 보존됨을 고정한다.
      테스트 주석에 "이 테스트는 [P1-06](../deferred/P1-06-equipment-wiring.md) 이 배선하면 갱신되어야 한다" 를 명시

## 하지 않을 것

- **장비 배선** — `powOfWeapon` 덮어쓰기 · `ac` 합산 · `books.json` 재척도는 전부
  [P1-06](../deferred/P1-06-equipment-wiring.md) 소관이다.
- 전투식 변경(`battle.dart:439-441`, `:513-514`).
- `books.json` 의 `ac` 10/20 재척도 — 부록 H-2 정정판이 "무효화가 아니라 강한 감쇠" 임을 실측했고,
  재척도 근거는 "기존 파티 스탯 대역(초기 `ac` 3~5)과 맞추기" 다. [BP-42](../../blueprint/42_item_and_inventory.md) 소관.
- `books.json` 을 앱에서 로드하기 (현재 참조 0건, 부록 §6) · 필드 삭제나 이름 변경.
- `HDPlayer.weapon` ↔ `books.json#weapon[].id` 매핑 — [BP-42](../../blueprint/42_item_and_inventory.md) 마이그레이션 소관.
