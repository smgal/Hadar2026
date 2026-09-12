# hd_world — 인물 · 파티 · 아이템 · 장비

순수 Dart. Flutter 도 `dart:io` 도 화면도 한국어도 스크립트 언어도 없다.
[BP-44](../../blueprint/44_bestiary.md) · [BP-45](../../blueprint/45_party_weapons.md) ·
[BP-46](../../blueprint/46_preset_logic.md) · [BP-47](../../blueprint/47_equipment_and_traversal.md)
이 정한 것을 코드로 옮긴 첫 조각이다.

## 세 가지 약속

**독립성** — 이 레포의 어떤 패키지도 import 하지 않는다. 전투 모델·Flutter 앱·
레거시 cm2 가 전부 밖에서 이쪽에 맞춘다. `test/flow/purity_test.dart` 가
`dart:io` · `DateTime.now` · `print` 까지 막는다.

**안정성** — 경계를 넘는 모든 정체성이 명시적 정수(`wire`)를 갖고 테스트가
그 숫자를 문자로 못박는다. **파생값은 저장하지 않는다** — 무기 종류·최종 수치·
파티가 지날 수 있는 지형·어둠 속 시야는 읽을 때 계산되므로 무효화할 캐시가 없다.

**확장성** — 아이템·직업·효과가 데이터다. 새 부적은 **줄 하나**고 분기가 아니다.

## 무엇이 들어 있나

| | |
|---|---|
| 부위 여덟 | 두 손이 각각 실제 칸. 저장 번호 0~5 는 이전 모델 값 그대로 |
| 아이템 | 원작 `WEAPON_LIST` 31종 + 방패·갑옷·투구·신발 + 부적 + 횃불 |
| 직업 17 | 원작 `_CLASS_ABILITY` 이식. 기술 12칸의 하한·상한이 직업의 정의다 |
| 무기 종류 15 | **두 손에서 유도된다.** 필드가 아니고 고르는 칸도 없다 |
| 상시 지시 7 | 직업 표에서 **기계적으로** 나온다. 손으로 쓴 목록이 아니다 |
| 통행 능력 | 부적이 파티 전체에 준다. 불만 사람 수로 겹친다 |

## 한 문으로만 바뀐다

```dart
final events = world.apply(EquipFromPack(
  member: MemberRef('knight'),
  slot: EquipSlot.rightHand,
  item: ItemRef('weapon.long_sword'),
));
```

`apply` 는 **throw 하지 않고 빈 목록을 주지도 않는다.** 거절은
`CommandRefused` 이벤트에 닫힌 열거 `RefusalReason` 으로 실려 온다. 그래서
터미널·브라우저·테스트·재생 기록이 같은 모양을 쓴다.

**자리가 틀린 것과 직업이 틀린 것은 다른 이유다.** 하나의 참거짓으로 뭉치면
화면이 설명할 수 없다.

## 만져 보려면

```bash
cd ../../hd_world_lab && dart run bin/serve.dart
```

마우스로 장비를 갈아 끼우는 화면과 OpenAPI 표면이 함께 뜬다.
[hd_world_lab/RUN.md](../../hd_world_lab/RUN.md).

```bash
dart pub get && dart test        # 103개
```
