# HDEnemy 구조 분석

`HDEnemy`는 게임 내에 배치된 개별 몬스터 인스턴스를 나타내며, `HDEnemyData`는 모든 몬스터 종류에 대한 정의(템플릿)를 제공합니다.

## 1. 주요 구조 (Flutter)

`lib/models/hd_enemy.dart` 및 `lib/models/hd_enemy_data.dart`에 위치합니다.

### 주요 속성 (HDEnemy)
| 속성명 | 타입 | 설명 |
| :--- | :--- | :--- |
| `data` | `HDEnemyData` | 몬스터의 정적 템플릿 정보에 대한 참조. |
| `name` | `String` | 몬스터 이름 (조사 처리를 위한 종성 판별 포함). |
| `strength` ~ `agility` | `int` | 템플릿으로부터 할당받은 실제 전투 능력치. |
| `accuracy` | `List<int>` | [물리 명중률, 마법 명중률]. |
| `hp` | `int` | `지구력 * 레벨` 공식으로 산출된 체력. |
| `castLevel` | `int` | 마법 사용 시의 위력 결정 레벨. |
| `special` | `int` | 적 특수 행동 또는 공격 타입 번호. |
| `poison` ~ `dead` | `int` | 상태 이상 관련 타이머. |

### 주요 메서드
- `isConscious()`: 체력이 있고 행동 가능한 상태인지 확인합니다.
- `getAttribute(String attr)`: 스크립트 엔진(예: `Enemy::GetHP`)과 연동하기 위한 속성 조회 인터페이스입니다.
- `changeAttribute(String attr, value)`: 스크립트 엔진(예: `Enemy::SetHP`)에서 능력을 수정하기 위한 인터페이스입니다.

### 몬스터 테이블 (`HDEnemyData`)
`hd_enemy_data.dart`에는 오크(Orc), 드래곤(Dragon) 등 총 75종의 몬스터 데이터가 상수로 정의되어 있으며, 원작의 능력치를 그대로 계승합니다.

---

## 2. Unity 원본(`ObjEnemy.cs`)과의 비교

Flutter의 `HDEnemy`는 원작의 `ObjEnemy`보다 더 독립적이고 객체 지향적인 구조를 가지고 있습니다.

### 구조적 차이점
- **메모리 구성**:
  - **Unity**: `CreatureAttribOld`와 `CreatureState`를 보유하는 얇은 래퍼 구조였습니다. 속성 조회를 위해 매번 템플릿을 참조해야 했습니다.
  - **Flutter**: 각 `HDEnemy` 인스턴스가 런타임에 필요한 속성(`strength` 등)을 직접 필드로 보유하여, 스크립트 도중의 개별적인 능력치 변조가 용이합니다.
- **HP 산출 방식**:
  - **Unity**: `GetMaxHp()` 공식은 `지구력 * 레벨 * 10` 이었습니다.
  - **Flutter**: `hp` 산출 시 `지구력 * 레벨`로 밸런스가 소폭 상향 조정되었습니다.
- **명칭 및 조사 처리**:
  - **Unity**: `ObjNameBase`를 통해 처리했습니다.
  - **Flutter**: 영어로 된 몬스터 이름("Orc")과 한글 조사("은/는")를 결합할 때 자연스럽게 출력되도록 전용 종성 판별 휴리스틱(`_hasJongsung`)이 포함되어 있습니다.

### 기능적 변천
- **상태 관리**:
  - **Unity**: `CreatureState` 구조체에서 HP와 독, 죽음 상태 등을 별도로 관리했습니다.
  - **Flutter**: 이러한 상태들이 `HDEnemy` 클래스의 직접적인 멤버 필드로 통합되었습니다.
- **스크립트 엔진 연동**: 현재 Flutter 버전은 `HDScriptEngine`(cm2_script 패키지 기반)에서 동적 쿼리가 가능하도록 문자열 기반의 접근자(`getAttribute`)가 강력하게 구현되어 있습니다. 원작에서는 주로 직접 멤버 접근이나 명시적 메서드를 통해 처리되었습니다.

> [!NOTE]
> Flutter 버전의 적 설계는 전투 스크립트 및 이벤트 시스템과의 높은 호환성을 목표로 하며, 런타임에 유연하게 속성을 변경할 수 있는 구조를 취하고 있습니다.
