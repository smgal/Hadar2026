# G2-02 미등록 cm2 심볼 6종·9곳을 정리한다 (전부 **등록**이 답이다)

- **상태**: TODO
- **구간**: G2
- **규모**: M
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` §9 · 부록 M-3 · F-0 · F-1](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.6](../MILESTONES.md)
- **관련**: [G1-08](../G1-items/G1-08-cm2-item-commands.md) (같은 파일에 등록) · [S2-03](../S2-enablers/S2-03-cm2-linter.md) (빌드 시 검출)

## 문제

### 전수 확인 — 6종·9곳

`grep -rn` 으로 `hadar2026_app/assets/` 와 `lib/` 를 직접 뒤졌다. 호출 지점 **정확히 9곳**이다
(`assets/const.cm2:35` 은 주석, `:36-46` 은 상수 정의이므로 호출이 아니다):

| # | 심볼 | 위치 | 인자 |
|---|---|---|---|
| 1 | `Party::CheckIf` | `assets/L1_ep1d4.cm2:45` | `CHECKIF_MAGICTORCH` |
| 2 | `Party::CheckIf` | `assets/L1_ep1d4.cm2:51` | `Not(...)` 안 |
| 3 | `Party::CheckIf` | `assets/L1_ep1d2.cm2:200` | `Not(CHECKIF_LEVITATION)` |
| 4 | `GameOver` | `assets/L1_ep1d0.cm2:441` | 없음 |
| 5 | `Player::ApplyAttribute` | `assets/L1_ep1d0.cm2:580` | `1` |
| 6 | `Player::ReviseAttribute` | `assets/menace.cm2:54` | `6` |
| 7 | `Map::SetLightArea` | `assets/L1_ep1d1.cm2:331` | `8,10, 14,15` |
| 8 | `Map::SetLightArea` | `assets/L1_ep1d4.cm2:480` | `12,16, 12,16` |
| 9 | `Map::ResetLightArea` | `assets/L1_ep1d4.cm2:73` | `12,16, 12,16` |

등록 현황(직접 세었다, 부록 F-0 과 일치): `registerCommand` **40**, `registerFunction` **12** —
위 6종은 어느 쪽에도 없다.

### `Party::CheckIf` — 부양 마법 분기가 **반대로 동작 중**이다

§9: 미등록 **함수**는 `"Unknown function"` 을 출력하고 **0을 반환**한다. 미등록 커맨드는 건너뛰기만 한다.
`Party::CheckIf` 는 조건식 안에 있으므로 함수 취급이고, 그래서 **항상 0** 이다.

`assets/L1_ep1d2.cm2:199-202` (직접 확인):
```cm2
if (Not(flag_event_hit))
    if (Not(Party::CheckIf(CHECKIF_LEVITATION)))
        Talk("@7일행들은 절벽으로 떨어질뻔 했다.")
        WarpPrevPos()
```
`Not(0)` = 참 → **부양 마법을 걸어도 절벽에서 떨어지고 되돌려진다.** 마법이 아무 소용이 없다.

`assets/L1_ep1d4.cm2:42-53` 은 짝을 이룬 두 분기가 **둘 다 틀린다**:
- `:45` `if (Party::CheckIf(CHECKIF_MAGICTORCH))` → 항상 거짓. 불을 켜도 "주위가 밝아 확인하기 어렵다" 가 안 나온다.
- `:51` `if (Not(Party::CheckIf(CHECKIF_MAGICTORCH)))` → 항상 참. **불을 켠 상태에서도** 물의 정령 이벤트가 발생한다.

상수는 이미 정의되어 있다 — `assets/const.cm2:36-46`: `CHECKIF_MAGICTORCH` 0 · `LEVITATION` 1 · `WALKONWATER` 2 · `WALKONSWAMP` 3 · `MINDCONTROL` 4.

### 원작에는 6종 **전부** 구현이 있다

`REF_hadar/src/hadar/hd_base_extern.h` 가 cm2 가 부르는 API 면이다. 전수 대조했다:

| cm2 심볼 | 원작 | 의미 |
|---|---|---|
| `Party::CheckIf(n)` | `:132` `bool party::checkIf(CHECKIF)`, enum `:119-126` | **enum 순서가 `const.cm2:42-46` 과 정확히 일치** |
| `GameOver()` | `:33` `void game::proccessGameOver(void)`, 구현 `hd_base_extern.cpp:151-153` | `proccessGameOver(EXITCODE_BY_FORCE)` — **인자 없는 강제 종료** |
| `Player::ReviseAttribute(i)` | `:146`, 본체 `hd_class_pc_player.cpp:369-374` | `hp/sp/esp` 를 최대치로 **클램프**(초과분 깎기) |
| `Player::ApplyAttribute(i)` | `:147`, 본체 `hd_class_pc_player.cpp:376-381` | `hp/sp/esp` 를 최대치로 **채움**(완전 회복) |
| `Map::SetLightArea` | `:44` `void map::setLight(int x, int y)` | **한 칸씩** 밝힘 → cm2 의 4인자는 영역 루프 래퍼 |
| `Map::ResetLightArea` | `:45` `void map::resetLight(int x, int y)` | 같음, 되돌림 |

## 왜 지금 고쳐야 하는가

- **재미** — 부양 마법·마법 횃불이 **지금 작동하지 않는다.** 마법 효과 구현이 별 트랙이라도(MILESTONES §1) 이미 있는 버프가 무시되는 것은 별건이다. `L1_ep1d0.cm2:441` 의 `GameOver()` 는 시나리오의 강제 종료 지점이라, 없으면 그 장면 뒤로 **게임이 계속 진행된다.**
- **부채 방지** — 부록 M-3 이 이것을 "AI 생성의 직접적 위험 근거" 로 든다. 침묵 오분기가 **정상 동작으로 오인되어** 그 위에 콘텐츠가 쌓인다. [G1-08](../G1-items/G1-08-cm2-item-commands.md) 의 `Item::Has` 가 같은 함정을 갖는다.
- MILESTONES §1.6 완료 기준: *"미등록 cm2 심볼 6종이 등록되거나 스크립트에서 제거된다."*

## 무엇을 할 것인가

### 심볼별 판정 — **6종 모두 (a) 등록**

원작에 구현이 전부 있으므로 "(b) 스크립트에서 제거" 를 고를 심볼이 **하나도 없다.**
제거하면 원작 연출이 사라지고, 그것은 이식 실패다.

| 심볼 | 종류 | Dart 대응 | 근거 |
|---|---|---|---|
| `Party::CheckIf(n)` | **함수** | `PartyBuffs`(`party.dart:18-27`)의 `magicTorch`/`levitation`/`walkOnWater`/`walkOnSwamp`/`mindControl` → `> 0` 이면 1 | 5종 전부 이미 필드로 존재. `const.cm2:42-46` 의 0~4 를 그대로 인덱스로 |
| `GameOver()` | **커맨드** | `HDMenuFlows().processGameOver(3)` (`menu_flows.dart:497`) | 원작이 `EXITCODE_BY_FORCE` 다(`hd_base_game_main.h:38-43` 에서 `USER/ACCIDENT/ENEMY/FORCE` = 0/1/2/3). 기존 호출은 `menu_flows.dart:315`(0), `battle.dart:268`(2) |
| `Player::ReviseAttribute(i)` | **커맨드** | `hp = min(hp, maxHp)` 등 3항 | `hd_class_pc_player.cpp:371-373` 를 그대로. Dart 는 `maxHp` 가 저장 필드라 계산이 더 단순하다 |
| `Player::ApplyAttribute(i)` | **커맨드** | `hp = maxHp` 등 3항 | `hd_class_pc_player.cpp:378-380` |
| `Map::SetLightArea(x1,y1,x2,y2)` | **커맨드** | `domain/lighting/` 의 밝힘 오버라이드에 영역 등록 | `map::setLight` 를 영역 루프로 감싼다 |
| `Map::ResetLightArea(x1,y1,x2,y2)` | **커맨드** | 같은 오버라이드에서 제거 | |

**플레이어 인덱스는 1-base 다.** `script_engine_adapter.dart:394-400` 의 `Player::ChangeAttribute` 가
`(args[0]) - 1` 로 변환하고 범위 검사를 한다. `ApplyAttribute`/`ReviseAttribute` 도 **같은 관례**를 따른다
(`L1_ep1d0.cm2:577-580` 이 주인공을 인덱스 1 로 부르는 것이 근거).

`menace.cm2:54` `Player::ReviseAttribute(6)` = 6번째 인물 = `players[5]`. `party.dart:81` 이 6명을 만드므로 범위 안이다.
같은 블록 `:48-52` 가 `armor`/`pow_of_*`/`ac` 를 0 으로 만든 뒤 클램프를 부른다 —
`ac` 를 깎아 최대 HP 가 줄었을 때 현재 HP 를 맞추는 용도다.

### 침묵 실패를 반복하지 않는다

부록 F-1 이 기록한 현행 결함(`Flag::Set` 등이 범위 검사에 `else` 없음)을 따라가지 않는다:
- 범위 밖 플레이어 인덱스 → **경고 로그**
- `Party::CheckIf` 의 범위 밖 인덱스 → **경고 로그** 후 0 반환 (0 을 조용히 돌려주지 않는다)
- 좌표 범위 밖 `SetLightArea` → **경고 로그**

### 등록 수치 갱신

| | 현재 | 이 이슈 후 |
|---|---|---|
| 커맨드 | 40 | **45** (`GameOver`, `Player::ApplyAttribute`, `Player::ReviseAttribute`, `Map::SetLightArea`, `Map::ResetLightArea`) |
| 함수 | 12 | **13** (`Party::CheckIf`) |

[G1-08](../G1-items/G1-08-cm2-item-commands.md) 이 별도로 커맨드 2종·함수 1종을 더한다 — 두 이슈가 모두 끝나면 **47 / 14**.
`GROUND_TRUTH` §9·부록 F-0·M-3 갱신이 완료 조건에 들어간다([README](../README.md) 워크플로 5).

## 완료 판정 기준

- [ ] 6종이 전부 등록되었고, **`Party::CheckIf` 만 `registerFunction`** 쪽에 있다 (나머지 5종은 커맨드)
- [ ] `grep -c "e.registerCommand('"` = **45**, `grep -c "e.registerFunction('"` = **13**
- [ ] `grep -rn` 으로 미등록 심볼 호출이 **0곳**임을 재확인했다 (위 9곳 전량이 해소)
- [ ] `L1_ep1d2.cm2:200` 시나리오: 부양 마법이 걸린 상태에서 절벽 칸에 들어가면 **떨어지지 않는다**
- [ ] `L1_ep1d4.cm2:45,51` 시나리오: 마법 횃불 상태에 따라 **두 분기가 각각 한 번씩만** 성립한다
- [ ] `L1_ep1d0.cm2:441` 의 `GameOver()` 가 실제로 게임 종료 흐름을 탄다 (`exitCode` 3 = 강제)
- [ ] `Player::ApplyAttribute(1)` 이 1번 인물의 hp/sp/esp 를 최대치로 채운다 (1-base 확인)
- [ ] `Player::ReviseAttribute(6)` 이 6번 인물에 적용되고, `menace.cm2:48-54` 블록이 끝난 뒤 `hp <= maxHp` 다
- [ ] `Map::SetLightArea`/`ResetLightArea` 가 영역을 밝히고 되돌린다 (`L1_ep1d4.cm2:73,480` 왕복)
- [ ] 범위 밖 인자 4계열(플레이어 인덱스 · CheckIf 인덱스 · 좌표 · 음수)이 전부 **경고 로그**를 남긴다
- [ ] `blueprint/_meta/GROUND_TRUTH.md` §9 · 부록 F-0 · M-3 이 갱신되었다
- [ ] `application/` 계층 위반 grep 2종 통과
- [ ] 테스트 추가: `hadar2026_app/test/application/cm2_unregistered_symbols_test.dart` —
      `test/application/map_navigation_test.dart:13-28` 의 페이크 바인딩 패턴을 따른다.
      ① `Party::CheckIf(1)` 이 `levitation > 0` 일 때 **1**, 0 일 때 **0** 을 반환
      ② `L1_ep1d2.cm2:199-202` 와 같은 형태의 cm2 조각을 실행해 **부양 중에는 `WarpPrevPos` 가 호출되지 않음**을 고정 (이 이슈의 핵심 회귀 테스트)
      ③ `Player::ApplyAttribute`/`ReviseAttribute` 의 1-base 인덱스와 hp/sp/esp 결과
      ④ 미등록 오타(`Party::CheckIff`)가 0 을 반환함을 고정하고, 주석에 "이것이 침묵 오분기의 형태다" 를 남긴다

## 하지 않을 것

- **`Item::Give/Take/Has` 등록** — [G1-08](../G1-items/G1-08-cm2-item-commands.md) 소관. 같은 파일을 건드리므로 순서를 조율한다.
- **cm2 린터** — 미등록 심볼을 빌드 시 잡는 것은 [S2-03](../S2-enablers/S2-03-cm2-linter.md)(S1 마찰 기록 이후).
- **기존 커맨드의 침묵 수정** — `Flag::Set`/`Variable::Set` 의 `else` 누락은 [P0-14](../P0-foundation/P0-14-silent-out-of-range.md).
- **`Party::PosX`/`PosY` 의 커맨드/함수 중복 등록** 정리 — 부록 F-0 이 기록한 별건이다(`script_engine_adapter.dart:418-419` 가 no-op 커맨드, `:545-546` 이 함수).
- **마법 45종 효과 구현** — 별 트랙이다(MILESTONES §1). 이 이슈는 **이미 있는 버프 필드를 읽게** 하는 것까지다.
- **전투 결과 코드 정합**(부록 B-2·F-3) — [P0-12](../P0-foundation/P0-12-battle-result-inverted.md)·[P0-13](../P0-foundation/P0-13-battle-result-defaults-win.md). MILESTONES §1.6 의 다른 항목이다.
- **`processGameOver` 의 `dart:io`/`exit(0)`** — [P0-16](../P0-foundation/P0-16-dart-io-and-exit.md). `kIsWeb` 가드가 이미 있어 웹 빌드는 성공한다(부록 B-4 정정).
- 플래그 레지스트리 — [S2-01](../S2-enablers/S2-01-flag-registry.md). 부록 M-2(생 숫자 40건)·M-3(인덱스 충돌 10·31·50)은 그쪽 소관이다.
- 밸런스 재설계·상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI.
