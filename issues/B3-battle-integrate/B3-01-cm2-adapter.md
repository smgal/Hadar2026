# B3-01 cm2 동사 5개를 호환 adapter 로 흡수한다 (기존 콘텐츠 53곳 무변경)

- **상태**: DONE
- **구간**: B3
- **규모**: M
- **선행**: [B5-99](../B5-battle-position/B5-99-freeze-contract-v2.md) (규격 v2)
- **설계 근거**: [DECISION-LOG 4차 판정](../DECISION-LOG.md) · [`GROUND_TRUTH` 부록 B-2 · F-3](../../blueprint/_meta/GROUND_TRUTH.md)

## 문제 — cm2 는 구현이 아니라 **이미 저작된 콘텐츠**다

`Battle::` 호출 지점이 **53곳**, 파일 **5개**다 (`const.cm2` 의 상수 정의 제외).

| 파일 | 성격 |
|---|---|
| `assets/L1_ep1d0.cm2` | 원작 이식 퀘스트 (2,441줄 계열) |
| `assets/lore_ep1.cm2` | 원작 이식 |
| `assets/town1.cm2` · `town2.cm2` | 마을 |
| `assets/Map002.cm2` | `Event::Override` 데모 |

등록된 동사는 5개다 — `application/scripting/script_engine_adapter.dart:360`(`Battle::Init`) ·
`:363`(`RegisterEnemy`) · `:365`(`ShowEnemy`) · `:368`(`Start`) · `:753`(`Battle::Result`).
`:509-510` 은 `Enemy::ChangeAttribute` 가 `HDBattle().enemies[i]` 를 직접 만진다.

**이 53곳을 고치는 것은 확장이 아니라 치환이다.** 4차 판정이 어댑터를 택한 이유다.

## 무엇을 할 것인가

- `hd_battle` 에는 확정 규격의 풍부한 API 를 두고, 5개 동사는 그 위에 얹는 **호환 계층**으로 구현한다.
- `RegisterEnemy(int)` → [B1-02](../B1-battle-extract/B1-02-enemy-table.md) 의 `legacyId` 표로
  문자열 키를 찾는다. 범위 밖 인자는 지금처럼 경고를 남기고 무시한다(P0-15 의 판정 유지).
- `Battle::Result()` 의 와이어 값을 **그대로 유지**한다 — `evade 0 / win 1 / lose 2 / 미결 -1`.
  `assets/const.cm2:53-55` 가 정본이고, `domain/battle/battle_result.dart` 가 그것을 이미 고정하고 있다.
  부록 B-2·F-3 이 해소한 것을 되돌리지 않는다.
- `Enemy::ChangeAttribute` 는 전투 model 내부를 직접 만지지 못하므로, 어댑터가 중개한다.

## 결과 (2026-09-05)

`hadar2026_app/lib/application/battle_bridge/cm2_battle_adapter.dart`.

### 동사 다섯 개가 새 model 위에 얹혔다

```
Battle::Init            판을 비운다
Battle::RegisterEnemy   legacyId → 문자열 키 (hb.enemyByLegacyId)
Battle::ShowEnemy       "…이 나타났다 !" — 싸울지 묻기 전에 알린다
Battle::Start(mode)     조립 → 진행 → 정산 반영
Battle::Result()        evade 0 / win 1 / lose 2 / 미결 -1
```

**`assets/*.cm2` 는 한 줄도 안 고쳤다.**

### `ShowEnemy` 는 **싸울지 묻기 전에** 알려야 한다 (2026-09-05 정정)

처음에는 비워 뒀다 — 새 model 이 개시하며 `EnemiesAppeared` 로 같은 줄을
내므로 둘 다 두면 두 번 찍히기 때문이었다. **그런데 순서가 뒤집힌다.**
`Map002.cm2` 는 `ShowEnemy` 와 `Battle::Start` 사이에서
"적과 교전한다 / 도망간다" 를 묻는다. model 이 내는 줄은 `Start` 안이라,
비워 두면 **누가 나왔는지 모른 채 싸울지 말지를 고르게 된다.**
원작이 이 동사를 따로 둔 이유가 그것이다.

지금은 어댑터가 등록된 키만으로 그 줄을 찍고(문장은 `hd_battle_text`,
콘솔과 같은 것), `HDBattleRunner(suppressAppearance: true)` 가 model 쪽
같은 줄을 버린다.

### `Enemy::ChangeAttribute` 는 아직 중개하지 못한다 — **쓰는 곳이 23곳 있다**

새 model 은 개시 입력을 받아 **자기 안에서** 적 인스턴스를 만들므로 밖에서 만질 수
없다. 지금은 경고만 남긴다 — 조용히 무시하면 부록 F-1 과 같은 침묵 실패가 된다.

**"출하된 cm2 에서 쓰는 곳이 없다" 고 적었던 것은 틀렸다**(2026-09-05 정정).
세어 보면 **23곳**이다.

| 파일 | 무엇을 |
|---|---|
| `L1_ep1d0.cm2:325~407` | 경비병 9명 — 이름 `경비병1`~`경비병7`, `special`·`castlevel` 을 0 으로 |
| `lore_ep1.cm2:301~341` · `town2.cm2` 동일 | 병사 7명 — 같은 방식 |

전부 `RegisterEnemy(26)` 로 **같은 적을 여러 번** 넣고 이름으로만 가른다. 그래서 지금은
**같은 이름의 적이 여럿 나오고, 눌러 두려던 특수 능력도 그대로 산다.**
고치려면 `BattleSetup` 에 적별 덮어쓰기 항목이 필요하고, 그건 규격 변경이라 판정을
받아야 한다. 인덱스는 **1-base** 다(`Enemy::ChangeAttribute(1, ...)` 가 첫 적).

## 완료 판정 기준

- [x] `assets/*.cm2` 를 **한 줄도 고치지 않고** 5개 동사가 새 전투를 구동한다
- [x] `Battle::Result()` 의 4개 값이 `const.cm2` 와 같다 — 전투 전에는 **-1(미결)**
      이고 승리가 기본값이 아니다(P0-13)
- [x] `RegisterEnemy` 의 `0~74` 유효 범위와 범위 밖 경고가 유지된다 —
      id 0(Orc)도 등록되고(P0-15), 같은 적 중복 등록이 정상이다
- [x] 원작 스크립트가 실제로 쓰는 id(1·3·5·7·26·69·71)가 전부 산다
      → `test/application/battle_bridge/cm2_adapter_test.dart`
- [x] `ShowEnemy` 가 조우를 알리고, 그 줄이 두 번 찍히지 않는다

**사람이 앱을 띄워 실제로 플레이한 것이 이 두 가지를 잡았다**(2026-09-05):
조우 알림 순서와, 아래 "이긴 싸움이 다시 시작된다". 이제
`test/application/battle_bridge/map002_encounter_test.dart` 가 **출하되는
`assets/Map002.cm2` 를 그대로** 두 번 굴려 둘 다 확인한다.

### 이긴 싸움이 다시 시작되던 것은 **스크립트가 결과를 안 받아서**였다

`Map002.cm2` 는 `Battle::Start(1)` 만 부르고 `Battle::Result()` 를 읽지
않았다. 그래서 이기든 지든 타일은 그대로였고, 같은 자리에 다시 말을 걸면
"적과 교전한다 / 도망간다" 가 또 나왔다 — 엔진이 아니라 **콘텐츠** 쪽 구멍이다.
`town1.cm2` 가 `Flag::IsSet` 으로 하던 것을 그대로 넣었다: 이기면
`Flag::Set(200)`, 다음부터는 쓰러진 것들만 보인다.

## 하지 않을 것

cm2 콘텐츠 수정 · 새 cm2 동사 추가(필요하면 별 이슈) · `application/battle.dart` 삭제(B4-03).
