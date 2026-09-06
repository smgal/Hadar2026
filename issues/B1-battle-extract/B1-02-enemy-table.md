# B1-02 적 테이블을 문자열 키로 이식한다 (일회성 seed 변환)

- **상태**: DONE
- **구간**: B1
- **규모**: S
- **선행**: [B1-01](B1-01-package-skeleton.md)
- **설계 근거**: [`GROUND_TRUTH` §10](../../blueprint/_meta/GROUND_TRUTH.md) · [DECISION-LOG 4차 판정](../DECISION-LOG.md)

## 문제

`hadar2026_app/lib/domain/battle/enemy_data.dart:33` 의 `const List<HDEnemyData> enemyTable` 은
**75행**(id 0~74, 부록 B-1)이고 정체성이 배열 인덱스다. `Battle::RegisterEnemy(26)` 처럼 **생 정수**로 지칭된다
(`assets/L1_ep1d0.cm2:324` 등).

4차 판정으로 전투는 **자기 테이블**을 갖는다. 그런데 새 테이블도 정수 id 로 만들면
RPG 의 75종 id 공간과 전투의 id 공간이 **둘 다 정수인데 의미가 다른** 상태가 되고,
[B3-01](../B3-battle-integrate/B3-01-cm2-adapter.md) 에서 "어느 쪽 26인지" 를 헷갈리는 결함이 생긴다.

## 왜 지금 해야 하는가

[B1-03](B1-03-formula-port.md) 의 전투식 단위 테스트가 이 테이블을 입력으로 쓴다.

## 무엇을 할 것인가

- `packages/hd_battle/lib/src/data/enemy_table.dart` 를 만든다. 정체성은 **snake_case 문자열 키**다
  (`'orc'`, `'earth_worm'`, `'phantom'`).
- **손으로 재입력하지 않는다.** `enemy_data.dart` 를 **일회성 seed** 로 변환해 넣는다.
  그 표는 `tools/` 의 레거시 바이너리 추출 + CP949 디코드 산물이라 재입력하면 오타가 섞인다.
  변환 스크립트는 `tools/` 에 남겨 재현 가능하게 한다.
- 원래 인덱스는 `legacyId` 필드로 **보존**한다 — B3-01 의 `int → 문자열 키` 표가 이걸 읽는다.
- 필드는 현재와 동일하게 시작한다: `strength · mentality · endurance · resistance · agility ·
  accuracy[2] · ac · special · castLevel · specialCastLevel · level`.
  확장은 B2 에서 한다.

## 완료 판정 기준

- [x] 새 테이블의 행 수가 **75** 이고, 각 행의 11개 수치가 `enemy_data.dart` 와 **전부 일치**한다
      → `packages/hd_battle/test/data/enemy_table_test.dart` 가 전수 비교로 고정
- [x] 모든 키가 snake_case 이고 **중복이 없다**
- [x] `legacyId` 가 0~74 를 빠짐없이 한 번씩 덮는다
- [x] 변환 스크립트가 `tools/` 에 있고, 다시 돌려도 같은 파일이 나온다

## 결과 (2026-09-04)

변환 스크립트는 `tools/battle/convert_enemy_table.py` 다. 75행이 그대로 옮겨졌고
`test/data/enemy_table_parity_test.dart` 가 **RPG 쪽 원본 파일을 직접 읽어** 14개 수치를
행마다 비교한다(텍스트로 읽는다 — `hd_battle` 은 Flutter 앱에 의존할 수 없다).

키 충돌은 없었다. `ArchiMage` → `archi_mage` 처럼 camelCase 경계에서 `_` 를 넣는다.
`Jr./Red Antares` → `jr_red_antares`.

## 하지 않을 것

적 데이터 필드 확장(B2) · 밸런스 조정 · `enemy_data.dart` 삭제(B4-03) ·
`Battle::RegisterEnemy` 의 인자 해석 변경(B3-01).
