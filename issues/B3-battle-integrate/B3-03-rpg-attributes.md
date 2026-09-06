# B3-03 RPG 아이템·적 정의에 속성 개념을 추가한다

- **상태**: DONE (부분 — 아래 「남긴 것」)
- **구간**: B3
- **규모**: L
- **선행**: [B2-09](../B2-battle-expand/B2-09-elemental-affinity.md) · [B2-99](../B2-battle-expand/B2-99-freeze-contract.md)
- **설계 근거**: [DECISION-LOG 4차 판정](../DECISION-LOG.md)

## 문제

[B2-09](../B2-battle-expand/B2-09-elemental-affinity.md) 가 전투에 속성 상성을 넣는다.
그런데 RPG 쪽에는 속성이 없다 — `domain/item/item.dart` 의 `param` 은 `attaPow`·`ac`·`itemType`
뿐이고 `domain/battle/enemy_data.dart` 의 11개 필드에도 없다.

그래서 개시 입력 조립이 **없는 정보를 채워야** 한다. 기본값으로 채우면
제대로 만든 상성이 붙으면서 반쪽만 살아남는다.

**이것이 4차 판정의 "RPG mode 나 스크립트도 기능을 확장하는 식" 의 첫 구체적 항목이다.**

## 무엇을 할 것인가

- `domain/item/` 의 아이템 정의와 `domain/battle/enemy_data.dart` 에 속성을 추가한다.
  G1 이 이식한 원작 구조(`ObjItem.cs` 의 `param`)를 깨지 않는 형태로 얹는다.
- 세이브 호환을 지킨다 — G1-09 가 만든 페이로드에 속성이 없으므로,
  없으면 기본값으로 읽는 방식이어야 한다(`player.dart:620-621` 이 같은 판정을 이미 한다).
- cm2 에서 속성을 지정할 수 있게 할지는 이 이슈에서 결정해 적는다.

## 완료 판정 기준

- [ ] 아이템과 적이 속성을 갖고, 개시 입력 조립이 기본값으로 채우지 않는다
- [ ] 속성이 없는 기존 세이브를 읽어도 깨지지 않는다
- [ ] 장비 화면·상태 메뉴에서 속성을 볼 수 있다
- [ ] 같은 마법이 속성이 다른 적에게 다른 피해를 준다 — **RPG 를 통해서** 확인된다
      → `hadar2026_app/test/domain/item/item_attribute_test.dart`

## 하지 않을 것

상성표 자체(B2-09 가 소유) · 속성 저항 장비 · 새 아이템 추가.


## 결과 (2026-09-05)

`hadar2026_app/lib/application/battle_bridge/` 의 `weapon_mapping.dart` ·
`setup_assembly.dart`.

### 무기는 두 세계가 나눠 갖는다 (규격 v2)

**RPG 는 `attaPow`(얼마나 센지), 전투는 `weaponKey`(어떻게 닿는지).**
대응은 **이름으로** 한다 — 원작 무기 10종의 이름이 양쪽에 그대로 있어서
이름이 가장 곧은 다리다. 이름이 바뀌면 `HDItemType` 에서 유도한다
(`chop`→도끼창 · `stab`→단도 · `hit`→철퇴 …).

테스트가 **10종 전부 맨손으로 떨어지지 않는 것**을 확인한다 — 대응이 빠지면
그 무기는 조용히 맨손이 되고, 그건 부록 F-1 과 같은 침묵 실패다.

### 부위별 방어구와 방패

`equip[]` 의 몸·머리·다리·장식 ac 를 합쳐 넘기고, 방패는 **막을 확률**로 바꾼다
(ac × 5, 상한 75). 슬롯이 다 비어 있으면 빈 값을 줘서 전투가 `ac` 하나로
되돌아간다 — 부위를 모르는 저장 파일에서 올라와도 그대로 싸워진다.

### 대열

슬롯에서 유도한다 (0-1 앞 · 2-3 중 · 4-5 뒤). **대열 화면은 B4** 이고,
생기면 `rankOf` 가 그 값을 읽게 된다.

## 남긴 것

- **속성** — 적 상성은 전투가 체질에서 유도하므로(B5-06) RPG 쪽에 넣을 것이 없다.
  **무기 속성은 공격 방식이 정한다**(B5-02) — 아이템에 속성 칸이 필요 없어졌다.
  B2-09 시점의 이 이슈 설계가 B5 로 바뀐 부분이다
- **소비 아이템 대응** — `consumedItems` 의 키가 RPG 아이템과 아직 안 이어져 있다.
  조용히 틀리게 빼는 것보다 안 빼는 것이 나아서 `_consume` 을 비워 뒀다

## 2026-09-06 추가 — 남긴 것이 닫혔다

`consumedItems` 키 ↔ RPG 아이템 대응은 **B6-05** 가 만들었다
(`domain/item/consumable_data.dart`, `setup_assembly.dart` 의 `heldConsumables` /
`_consume`). 이 이슈에서 비워 두었던 `_consume` 은 이제 실제로 가방에서 뺀다.
