# G1-08 cm2 커맨드 `Item::Give` / `Item::Take` 와 **함수** `Item::Has` 를 등록한다

- **상태**: TODO
- **구간**: G1
- **규모**: S
- **선행**: [G1-03](G1-03-party-inventory.md)
- **설계 근거**: [`GROUND_TRUTH` §9 · 부록 F-0 · F-1 · M-2 · M-3](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.5](../MILESTONES.md)
- **관련**: [G2-02](../G2-combat/G2-02-unregistered-cm2-symbols.md) (미등록 심볼 6종) · [S1-03](../S1-sample-quest/S1-03-quest-cm2.md) (이 이슈를 선행으로 잡고 있다 — [BOARD](../BOARD.md))

## 문제

### cm2 에는 아이템을 다룰 심볼이 없다

`hadar2026_app/lib/application/scripting/script_engine_adapter.dart` 의 등록 현황을 직접 세었다
(부록 F-0 의 수치와 일치):

```
grep -c "e.registerCommand('" → 40
grep -c "e.registerFunction('" → 12
```

`Item::` 으로 시작하는 심볼은 **0개**다. 등록 예시는 `:362`(`Flag::Set`)·`:503`(`Flag::IsSet`)·`:394`(`Player::ChangeAttribute`).

### 그래서 퀘스트가 플래그로 아이템을 흉내낸다

2차 판정이 확인한 원작 방식 — `assets/flag4ep1.cm2` 의 `GFD0_GET_KEY_FOR_D1` 이 **곧 "열쇠 소지"** 다.
3차 판정이 이것을 부채로 판정했다([DECISION-LOG](../DECISION-LOG.md)): *"플래그로 만든 퀘스트 20개는 나중에 인벤토리가 생기면 전부 다시 써야 한다."*

## 왜 지금 고쳐야 하는가

- **재미** — MILESTONES §1.5: *"cm2 에서 `Item::Give/Take/Has` 로 아이템을 다룰 수 있다 → 퀘스트가 진짜 아이템을 쓴다."* [S1](../S1-sample-quest/S1-01-quest-design.md) 의 "물건을 구해 오라" 가 실제 물건이 되는 지점이다.
- **부채 방지** — [S1-03](../S1-sample-quest/S1-03-quest-cm2.md) 가 이 이슈를 선행으로 잡고 있다. 없으면 S1 이 플래그로 쓰이고, 그 뒤 [S3](../S3-generation/S3-02-generation-prompt.md) 의 few-shot 정답지가 **플래그 흉내 방식**으로 굳는다.

## ⚠ `Item::Has` 는 **반드시 함수로** 등록해야 한다

cm2 의 침묵 실패는 두 갈래이고(§9 · 부록 F-1) 그중 하나가 치명적이다:

| 갈래 | 증상 |
|---|---|
| 미등록 **커맨드** | `"Unknown command"` 출력 후 **건너뛴다** — 아무 일도 안 일어난다 |
| 미등록 **함수** | `"Unknown function"` 출력 후 **0을 반환한다** — 조건식이 조용히 오분기한다 |

`Item::Has` 를 커맨드로 잘못 등록하거나 등록을 빠뜨리면:
```cm2
if (Item::Has(ITEM_KEY_D1))          # 항상 0 → 이 블록은 절대 실행되지 않는다
    Talk("열쇠로 문을 열었다")
if (Not(Item::Has(ITEM_KEY_D1)))     # 항상 참 → 열쇠가 있어도 "없다" 로 처리된다
    Talk("열쇠가 없다")
```
**퀘스트가 아이템 없이도 완료되거나, 아이템을 가져도 완료되지 않는다.** 어느 쪽이든 로그는 한 줄뿐이다.

이것은 가정이 아니라 **지금 벌어지고 있는 일**이다 — 부록 M-3: `Party::CheckIf` 가 미등록 함수라
`assets/L1_ep1d2.cm2:200` 의 `Not(Party::CheckIf(CHECKIF_LEVITATION))` 이 **항상 참**이고,
부양 마법 중에도 절벽에서 떨어진다. 정리는 [G2-02](../G2-combat/G2-02-unregistered-cm2-symbols.md).

## 무엇을 할 것인가

### 인자 형태 — **정수 1개 + 이름 상수 파일**

3인자(`type`, `detail`, `index`)는 스크립트에서 읽을 수 없다. 대신 [G1-01](G1-01-item-model-port.md) 의
`HDItemId.wire`(= `ResId` 하위 24비트 배치) 정수 하나를 받고, 이름은 cm2 상수로 준다:

```cm2
# assets/item4ep1.cm2   (형식은 assets/flag4ep1.cm2 를 따른다)
variable(ITEM_WIELD_DAGGER)
ITEM_WIELD_DAGGER.assign(1)          # WIELD(0) detail 0 index 1 → 0x000001
```

근거: `flag4ep1.cm2` 가 이미 이름 상수 방식이고, 부록 M-2 가 그 **반대 사례**(생 숫자 플래그 40건)를
"이름 레지스트리를 우회하므로 충돌 검출이 불가능" 하다고 기록했다. 아이템에서 같은 실수를 반복하지 않는다.
상수 파일은 `include` 로 읽는다 — cm2 의 `include` 는 **init 단계 전용**이므로(§9) 상수 정의에 적합하다.

### 등록 내용

| 심볼 | 종류 | Dart | 반환/효과 |
|---|---|---|---|
| `Item::Give(id)` | **커맨드** | `HDGameSession().party.give(...)` ([G1-03](G1-03-party-inventory.md)) | 가방이 꽉 차면 **경고 로그** |
| `Item::Take(id)` | **커맨드** | `party.take(...)` | 없는 아이템이면 **경고 로그** |
| `Item::Has(id)` | **함수** | `party.has(...)` | `1` / `0` |

`Item::Has` 는 `e.registerFunction('Item::Has', ...)` 로 등록한다 — `Flag::IsSet`(`:503`)과 같은 자리다.

### 범위 밖 인자를 침묵시키지 않는다

부록 F-1 이 기록한 현행 결함: `Flag::Set`(`:362-391`)·`Variable::Set` 등이 범위 검사에 **`else` 가 없어서**
`Flag::Set(300)` 이 아무 로그도 없이 사라진다. 아이템 3종은 그 패턴을 따르지 않는다 —
표에 없는 `id` 는 **경고 로그를 남기고** `Item::Has` 는 `0` 을 반환한다. `Item::Give` 의 실패도 로그를 남긴다.

### 등록 수치 갱신

| | 현재 | 이 이슈 후 |
|---|---|---|
| 커맨드 | 40 | **42** (`Item::Give`, `Item::Take`) |
| 함수 | 12 | **13** (`Item::Has`) |

[G2-02](../G2-combat/G2-02-unregistered-cm2-symbols.md) 가 별도로 커맨드 5종·함수 1종을 더 늘린다 — 두 이슈가 모두 끝난 뒤 값은 **47 / 14** 다.
`GROUND_TRUTH` §9·부록 F-0 의 40/12 를 갱신하는 것이 이 이슈의 완료 조건에 들어간다
([README](../README.md) 워크플로 5: *"설계와 어긋나는 사실을 발견하면 `GROUND_TRUTH` 를 먼저 고친다"*).

## 완료 판정 기준

- [ ] `Item::Give` · `Item::Take` 가 **커맨드**로, `Item::Has` 가 **함수**로 등록되었다 (`registerFunction` 쪽에 있는지 눈으로 확인)
- [ ] `grep -c "e.registerCommand('"` = **42**, `grep -c "e.registerFunction('"` = **13**
- [ ] `assets/item4ep1.cm2` 가 있고, 등록된 아이템 전량이 **이름 상수**를 갖는다 (생 숫자 사용 0건)
- [ ] 표에 없는 `id` 를 넘기면 **경고 로그**가 남는다 (조용히 무시되지 않는다 — 부록 F-1 재발 방지)
- [ ] 가방이 꽉 찬 상태의 `Item::Give` 가 경고 로그를 남기고 **기존 20칸을 건드리지 않는다**
- [ ] `blueprint/_meta/GROUND_TRUTH.md` §9·부록 F-0 의 40/12 가 갱신되었다
- [ ] `application/` 계층 위반 grep 2종 통과
- [ ] 테스트 추가: `hadar2026_app/test/application/cm2_item_commands_test.dart` —
      `test/application/map_navigation_test.dart:13-28` 의 페이크 바인딩 패턴을 따른다.
      cm2 원문을 `loadFromString` 으로 넣고 실행해
      ① `Item::Give` → `Item::Has` 가 **1** 을 반환
      ② `Item::Take` 후 `Item::Has` 가 **0** 을 반환
      ③ **미등록 오타**(`Item::Hass`)가 0 을 반환함을 고정하고, 테스트 주석에 "이것이 침묵 오분기의 형태다" 를 남긴다
      ④ 범위 밖 `id` 가 경고 로그를 남기고 가방을 바꾸지 않음

## 하지 않을 것

- **다른 미등록 심볼 6종** — `Party::CheckIf`·`GameOver`·`Player::ApplyAttribute`·`Map::SetLightArea`·`Map::ResetLightArea`·`Player::ReviseAttribute` 는 [G2-02](../G2-combat/G2-02-unregistered-cm2-symbols.md) 소관.
- **cm2 린터** — 미등록 심볼을 빌드 시 잡는 것은 [S2-03](../S2-enablers/S2-03-cm2-linter.md)(S1 마찰 기록 이후).
- `Item::Count`·`Item::Equip`·`Item::Sell` — 필요해진 사례가 나오면 그때. 지금은 Give/Take/Has 3종이 MILESTONES §1.5 의 요구 전량이다.
- `Flag::Set` 등 기존 커맨드의 침묵 수정 — [P0-14](../P0-foundation/P0-14-silent-out-of-range.md) 소관.
- 아이템 상수 파일의 **자동 생성** — 손으로 쓴다. 레지스트리 자동화는 [S2-01](../S2-enablers/S2-01-flag-registry.md) 계열이다.
- 상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI.
