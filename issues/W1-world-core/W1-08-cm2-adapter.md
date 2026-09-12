# W1-08 cm2 어댑터 — 속성 15개와 아이템 명령

- **상태**: DONE (2026-09-09)
- **구간**: W1 ([_README](_README.md))
- **규모**: M
- **선행**: [W1-02](W1-02-slots-and-items.md)

## 문제

출하 cm2 4,267줄이 인물과 아이템을 만진다. 그런데 **표면이 좁다** (10차 판정 실측):

| 심볼 | 호출 |
|---|---|
| `Player::ChangeAttribute` | 75 — 속성 이름 **15종**뿐 |
| `Player::GetAttribute` | 26 |
| `Player::IsAvailable` · `GetName` · `AssignFromEnemyData` | 28 |
| `Item::Give` / `Take` / `Has` | G1-08 이 넣은 것 |

`Player::ChangeAttribute` 가 쓰는 이름 전부:
`name` 30 · `special` 23 · `castlevel` 23 · `E_number` 23 · `weapon` 6 · `shield` 5 ·
`pow_of_weapon` 5 · `pow_of_shield` 5 · `pow_of_armor` 5 · `class` 5 · `armor` 5 ·
`ac` 3 · `level` 1 · `endurance` 1 · `accuracy` 1.

앞의 넷은 **적**의 것이고(`Enemy::ChangeAttribute`) BP-44 의 개체 층이 흡수한다.
사람 쪽은 열한 개다.

## 무엇을 할 것인가

전투에서 `cm2_battle_adapter.dart` 218줄이 한 일과 같은 크기다. **어댑터가 밖에 있고
`hd_world` 는 cm2 를 모른다.**

- 속성 이름 11개를 명령으로 옮긴다. `weapon`/`shield`/`armor` 정수는 `legacyIndex` 로 ref 를 찾는다
- `pow_of_shield` · `pow_of_armor` 는 **죽은 필드**였다(P0-19). 새 모델에 자리가 없다 —
  cm2 가 쓰면 **경고하고 무시**한다. 조용히 받아 두면 다시 자기기만이다
- 모르는 속성 이름은 **경고한다.** 옛 `changeAttribute` 는 `default:` 로 조용히 넘겼다

## 무엇을 했나

`packages/hd_world_legacy` — 옛 어휘만 아는 순수 Dart 패키지다. cm2 엔진은
앱에 남고, **번역표가 따로 있어서 테스트가 표면 전체를 걸을 수 있다.**

### 답이 넷이다, 참거짓이 아니다

`writeAttribute` 는 `applied` · `derived` · `dead` · `unknown` 중 하나를 돌려준다.
이전 모델은 `default:` 로 흘려보내서 **오타가 몇 년을 살아 있었다.**

- `derived` — 이름은 real 인데 이제 장비에서 계산된다(`ac` · `max_hp` · `pow_of_weapon`).
  무엇을 대신 하라고까지 말한다
- `dead` — 읽는 곳이 0곳이던 필드(`pow_of_shield` · `pow_of_armor`)
- `unknown` — 없는 이름. 콘텐츠 버그다

읽기도 마찬가지다. 모르는 이름은 **null** 이고, 부르는 쪽이 반드시 알린다 —
모르는 심볼에 0 을 주고 조용히 오분기한 것이 부록 M-3 의 결함이었다.

### 무기 정수는 자기 공간이다

스크립트의 `weapon 4` 는 **원작 열 개 이름 사다리**의 넷째이지 「넷째 베는 무기」가
아니다. 방패와 갑옷만 두 공간이 0~5 로 겹친다. 사다리를 따로 두고 테스트가
그것을 못박는다.

### 상태 소유가 정정되었다

처음에 `poison`·`unconscious`·`dead` 를 「전투의 것」으로 두었는데 **틀렸다** —
독은 쉬면 줄고 죽음은 전투 사이에도 남는다. 파티의 것이고 전투가 빌려 갔다
돌려준다. `Member` 에 넷(+`experience`)이 들어가고 다리가 양방향으로 옮긴다.

### 상수 파일을 다시 만들었다

`assets/item4ep1.cm2` 는 옛 카탈로그에서 생성된 것이라 어긋났다.
`packages/hd_world_legacy/tool/make_item_constants.dart` 가 새 카탈로그에서
91개를 만든다. **출하 cm2 중 `Item::*` 를 부르는 것은 0곳**이라 콘텐츠 영향은 없다.

## 완료 판정 기준

- [x] 출하 cm2 가 쓰는 속성 이름 전부가 답을 갖는다 (`cm2_assets_audit_test`)
- [x] 모르는 속성 이름이 조용히 무시되지 않는다
- [x] `hd_world` 가 `cm2_script` 를 import 하지 않는다 (CI 가 확인)
- [x] 무기 정수 사다리가 원작 이름표와 같다
