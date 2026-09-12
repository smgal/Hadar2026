# W1 — RPG 핵심 재작성 (인물 · 파티 · 아이템 · 장비)

> **신설 (2026-09-08, [10차 판정](../DECISION-LOG.md))**
> 기존 코드를 고치지 않고 **새 순수 Dart 패키지로 다시 쓴다.** 전투가 간 길
> (`application/battle.dart` 572줄 → `packages/hd_battle`)을 그대로 간다.

설계 근거는 [BP-44](../../blueprint/44_bestiary.md) ·
[BP-45](../../blueprint/45_party_weapons.md) ·
[BP-46](../../blueprint/46_preset_logic.md) ·
[BP-47](../../blueprint/47_equipment_and_traversal.md), 실측은
[`GROUND_TRUTH` 부록 Z](../../blueprint/_meta/GROUND_TRUTH.md).

## 산출물 셋

| | 무엇 | 규칙 |
|---|---|---|
| `packages/hd_world` | 모델 | 순수 Dart. **이 레포의 어떤 패키지도 import 하지 않는다** |
| `packages/hd_world_text` | 한국어 이름표 | 모델은 키만 든다 |
| `hd_world_lab` | OpenAPI 서버 + 마우스 화면 | 규칙을 하나도 갖지 않는다 |

## 왜 콘솔이 아닌가

전투는 한 번에 한 물음이라 터미널이 맞았다. 장비는 다르다 —

- 부위가 여덟이고 **동시에 보여야** 한다. 왼손을 채우면 오른손이 잠긴다
- 고칠 때마다 **최종 수치가 다시 계산**되고, 그 차이를 보려고 만지는 것이다
- 후보가 스무 개를 넘는다. 번호를 외워 누르는 일이 아니다

그래서 화면 하나와 API 하나다. 모델이 이미 명령과 사실로 말하므로 둘이 같은 문을 쓴다.

## 이슈

| ID | 제목 | 상태 | 규모 |
|---|---|---|---|
| [W1-01](W1-01-package-skeleton.md) | 패키지 셋 · 독립성 게이트 · CI | **DONE** | M |
| [W1-02](W1-02-slots-and-items.md) | 부위 여덟 · 아이템 31종 · 자격 검사 | **DONE** | L |
| [W1-03](W1-03-derived-values.md) | 파생값 무저장 — 무기 종류 · 최종 수치 · 통행 능력 · 시야 | **DONE** | L |
| [W1-04](W1-04-classes-and-styles.md) | 직업 17 이식 · 상시 지시 7 유도 | **DONE** | M |
| [W1-05](W1-05-openapi-lab.md) | OpenAPI 표면 · 마우스 화면 | **DONE** | L |
| [W1-06](W1-06-battle-bridge.md) | 전투 다리 — `hd_world` → `hd_battle` (**규격 v4**) | **DONE** | M |
| [W1-07](W1-07-save-format.md) | 세이브 — 부위 여덟을 싣는 포맷 | **DONE** | M |
| [W1-08](W1-08-cm2-adapter.md) | cm2 어댑터 — 속성 15개 · 아이템 명령 | **DONE** | M |
| [W1-09](W1-09-app-swap.md) | 앱 교체 — 포트 뒤에서 옛 모델을 뺀다 | **DONE** | L |

**W1-01~05 는 2026-09-08 에, W1-06~09 는 2026-09-09 에 들어갔다.**
첫 조각이 스스로 돌아가는 것까지가 한 덩어리였기 때문이다 — 모델만 있고 만져 볼 수
없으면 판정을 확인할 수 없다.

## 이 구간이 찾아낸 결함 셋

다시 쓰는 동안 **한 번도 발동한 적 없는 결함 셋**이 드러났다. 전부
[`GROUND_TRUTH` 부록 Z](../../blueprint/_meta/GROUND_TRUTH.md) 에 있다.

| | 무엇 | 왜 안 보였나 |
|---|---|---|
| Z-7 | 출하 스크립트가 원작의 17직업 번호를 쓰는데 앱은 안 썼다 — cm2 가 직업을 정하면 「알 수 없음」이 나왔다 | 직업을 읽는 곳이 표시뿐이었다 |
| Z-8 | **레벨이 오르면 최대 체력이 줄었다** (슴갈 150 → 34) | `checkLevelUp` 호출처가 죽은 코드뿐이라 발동한 적이 없다 |
| Z-9 | 초능력 41·42·44 가 전투 메뉴에 있고 **아무 일도 하지 않았다** — B5 불변식 위반 | 마법 33~40 은 같은 이유로 빠졌는데 셋만 남아 있었다 |

## 이 구간에 **들어 있지 않은 것**

지도 · 대화 · 스크립트 · 세계 진행. 전투는 입력·출력이 명확했지만 RPG 는 자연 경계가
없어서 "전체 재작성" 으로 번지기 쉽다. 그래서 **패키지를 빼는 것으로 정의했다** —
Flutter 없음 · 렌더링 없음 · cm2 없음 · 에셋 없음. 첫 조각이 증명한 뒤에 별개로 판정한다.

## 지금 상태 (2026-09-09)

```
packages/hd_world         모델 · 시험 112개
packages/hd_world_text    이름표 · 시험 4개
packages/hd_world_legacy  옛 어휘(속성·아이템 번호) · 시험 23개
packages/hd_bridge        전투 다리 · 시험 18개
hd_world_lab              서버 + 화면 + 전투 한 판 · 시험 14개
hadar2026_app             새 모델 위에서 돈다 · 시험 180개
```

**앱이 새 모델 위에서 돈다.** `HDPlayer`(735줄) · `domain/item/*`(약 640줄) ·
`equipment_flow.dart` · `setup_assembly.dart` · `weapon_mapping.dart` 를 지웠고,
`presentation/` 은 손대지 않았다 — 겉은 그대로다.

```bash
cd hd_world_lab && dart pub get && dart run bin/serve.dart
# http://127.0.0.1:5330/
```

무엇을 눌러 볼지는 [hd_world_lab/RUN.md](../../hd_world_lab/RUN.md).
