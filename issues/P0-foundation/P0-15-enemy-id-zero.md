# P0-15 적 id 0(`Orc`)이 영구 소환 불가 — 테이블 75 중 실사용 74

- **상태**: DONE
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 B-1 · F-1 · H-2](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-42 아이템·인벤토리](../../blueprint/42_item_and_inventory.md)

## 문제

`hadar2026_app/lib/domain/battle/enemy_data.dart:33` 의 `const List<HDEnemyData> enemyTable` 은
**75개 엔트리(id 0~74)** 를 갖는다. 본인 재검증:

```
$ python3 -c "... body.count('HDEnemyData(')"   # 'enemyTable' 이후만 카운트
75
```

(`grep -c "HDEnemyData("` 가 76을 반환하는 것은 `:16` 의 생성자 선언이 함께 잡히기 때문이다.)

`:34` 의 첫 엔트리:

```dart
HDEnemyData(id: 0, name: 'Orc', strength: 8, mentality: 0, endurance: 8, ... level: 1),
```

그런데 `hadar2026_app/lib/application/battle.dart:43-46`:

```dart
void registerEnemy(int enemyTableId) {
  if (enemyTableId <= 0 || enemyTableId >= enemyTable.length) return;
  enemies.add(HDEnemy(enemyTable[enemyTableId]));
}
```

**`<= 0` 가드 때문에 id 0 (`Orc`) 은 cm2·콘텐츠에서 영원히 소환할 수 없다.**
실제 사용 가능한 적은 **id 1~74, 74종**이다.

cm2 노출 지점 — `script_engine_adapter.dart:334-337`:

```dart
e.registerCommand('Battle::RegisterEnemy', (stmt, eng) async {
  final enemyId = (eng.getVal(stmt.args[0]) as num).toInt();
  HDBattle().registerEnemy(enemyId);
});
```

즉 스크립트가 `Battle::RegisterEnemy(0)` 을 쓰면 **적이 등록되지 않은 채 조용히 진행**된다.
이어서 `Battle::Start` 를 하면 적 없는 전투가 되고, [P0-13](P0-13-battle-result-defaults-win.md) 의 기본값 문제와 겹친다.

## 왜 지금 고쳐야 하는가

- [MILESTONES.md §2](../MILESTONES.md) 의 P0 완료 기준 6번이 `Battle::RegisterEnemy(0)` 를 **이름으로 지목**한다.
- 부록 B-1 이 "BP-21/22/23/42 는 **74종(id 1~74)** 기준으로 쓸 것" 을 지시했다.
  즉 설계 문서들이 이미 74 를 가정하고 있다 — **코드와 문서 중 어느 쪽을 고칠지 결정이 필요하다.**
- [P1-05](../deferred/P1-05-inventory.md)·[BP-42](../../blueprint/42_item_and_inventory.md) 의 적 드롭·보상 티어표가 적 id 공간을 참조한다.
  경계가 애매하면 그 표가 한 칸씩 밀린다.

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 변경 | 장점 | 단점 |
|---|---|---|---|---|
| A | **`<= 0` → `< 0` 으로 고쳐 id 0 을 살린다** | `battle.dart:44` 1글자 | 테이블 75종 전부가 사용 가능해진다. 데이터와 코드가 일치 | id 0 을 "없음/취소" 센티넬로 쓰는 cm2 가 있으면 동작이 바뀐다 (아래 조사에서 **없음** 확인) |
| B | 테이블에서 id 0 을 제거하고 1부터 재번호 | `enemy_data.dart` 전체 + 참조 | 경계가 하나로 정리된다 | 기존 cm2 의 적 id 가 한 칸 밀린다. **가장 위험** |
| C | **id 0 을 예약값으로 확정하고 그 사실을 코드·문서에 명시** | `battle.dart:44` 에 사유 주석 + `enemyTable` 의 id 0 엔트리에 `// reserved` | 변경 위험 0. 부록 B-1 의 "74종" 서술과 일치 | `Orc` 데이터가 계속 죽어 있다 |
| D | **A + 침묵 제거** — id 0 을 살리고, 범위 밖 인자는 경고 로그 | `battle.dart:43-46` | 완료 기준의 "침묵하지 않는다" 를 충족 | 없음 |

### 실사용 인자 전수 조사 (본인 수행 — `grep -rhn "RegisterEnemy" assets/`)

| 인자 | 횟수 |
|---|---|
| 26 | 23회 |
| 1 · 3 · 5 · 7 · 69 · 71 | 각 1 |
| **75** | 1 — `town1.cm2:50`, **주석 처리(`#`)** |

사용 파일: `L1_ep1d0.cm2`(9) `lore_ep1.cm2`(7) `town2.cm2`(7) `town1.cm2`(5) `Map002.cm2`(2).
**`RegisterEnemy(0)` 은 한 군데도 없다** → 센티넬 용도가 없으므로 **A 가 안전하다.**
주석 처리된 `RegisterEnemy(75)` 는 테이블 밖 id(유효 0~74)를 의도했던 흔적 — 침묵 가드가 감춰 온 실수다.

### 권고안: **D**

1. A 를 적용하고 침묵을 제거한다:

   ```diff
     void registerEnemy(int enemyTableId) {
   -   if (enemyTableId <= 0 || enemyTableId >= enemyTable.length) return;
   +   if (enemyTableId < 0 || enemyTableId >= enemyTable.length) {
   +     print('HDBattle: [WARN] registerEnemy($enemyTableId) out of range '
   +           '[0, ${enemyTable.length}) — ignored');
   +     return;
   +   }
       enemies.add(HDEnemy(enemyTable[enemyTableId]));
     }
   ```

   경고 형식은 [P0-14](P0-14-silent-out-of-range.md) 의 `_warnOutOfRange` 와 같은 모양으로 맞춘다.
2. **`enemyTable` 의 실사용 범위를 테스트로 고정**한다.
   그것이 [BP-42](../../blueprint/42_item_and_inventory.md) 의 보상 티어표가 참조할 정본이 된다.
3. A 를 채택하면 실사용 종수가 74 → 75 로 바뀐다. 부록 B-1 이 "BP-21/22/23/42 는 74종 기준" 을
   지시했으므로 **`GROUND_TRUTH` 를 먼저 고쳐야 한다**
   ([README.md](../README.md) 워크플로 5번). C 로 후퇴하면 문서 수정은 필요 없다.

## 완료 판정 기준

- [x] `registerEnemy` 에 범위 밖 인자를 넘기면 **경고 로그가 남는다** (침묵하지 않는다)
- [x] 채택안(A/C)이 코드 주석으로 명시되어 있다 — 왜 그 경계인지 읽고 알 수 있다
- [x] A 채택 시 `registerEnemy(0)` 후 `HDBattle().enemies.length == 1` 이고 이름이 `Orc` 다
- [x] 테스트 추가: `hadar2026_app/test/domain/battle/enemy_table_test.dart` —
      ① `enemyTable.length == 75` ② `enemyTable[0].name == 'Orc'` ③ 모든 엔트리의 `id` 가
      배열 인덱스와 같음(id 와 인덱스의 동일성이 `battle.dart:244` 의 경험치 식 전제다)을 고정한다

## 하지 않을 것

- `enemyTable` 의 스탯 값 조정·엔트리 추가·삭제.
- 적 데이터를 콘텐츠 팩으로 외부화 — [BP-22](../../blueprint/22_world_bible_model.md)·[P1-01](../deferred/P1-01-content-core-package.md) 소관.
- 경험치 식(`battle.dart:244`) · 인카운터 테이블 변경.
- `Flag::Set` 계열의 범위 침묵 — [P0-14](P0-14-silent-out-of-range.md) 소관.

## 구현 기록 (2026-09-03)

**권고안 D**(A + 침묵 제거)를 채택했다.

```diff
- if (enemyTableId <= 0 || enemyTableId >= enemyTable.length) return;
+ if (enemyTableId < 0 || enemyTableId >= enemyTable.length) {
+   debugPrint('HDBattle: [WARN] registerEnemy($enemyTableId) is outside '
+              '[0, ${enemyTable.length}) — ignored');
+   return;
+ }
```

- 실사용 인자 재확인 — `1, 3, 5, 7, 26, 69, 71` 과 주석 처리된 `75`. **0 은 0건**이라 센티넬 용도가 없다.
- 경계를 고른 이유를 코드 주석에 남겼다.
- 테스트: `test/domain/battle/enemy_table_test.dart` — ① 75행 ② `enemyTable[0].name == 'Orc'`
  ③ 모든 행의 `id` 가 인덱스와 같음 ④ `registerEnemy(0)` 이 실제로 등록됨 ⑤ 범위 밖은 거부
- `GROUND_TRUTH` 부록 B-1 을 **[해소됨]** 으로 갱신하고,
  **BP-21/22/23/42 의 "74종" 서술을 75종으로 고쳐야 함**을 그 항목에 적어 뒀다.
