# HDParty 구조 분석

`HDParty`는 플레이어 파티의 현재 위치, 자원, 시간 상태 및 파티원 구성 등 게임 전반의 파티 상태를 관리하는 핵심 클래스입니다.

## 1. 주요 구조 (Flutter)

`lib/models/hd_party.dart`에 위치하며, Flutter의 상태 관리를 위해 `ChangeNotifier`를 확장하여 구현되었습니다.

### 주요 속성
| 속성명 | 타입 | 설명 |
| :--- | :--- | :--- |
| `x`, `y` | `int` | 맵 상의 현재 좌표. |
| `faced` | `int` | 현재 바라보는 방향 (0: 아래, 1: 위, 2: 오른쪽, 3: 왼쪽). |
| `food` | `int` | 남은 식량 (시간 경과나 이동 시 감소). |
| `gold` | `int` | 현재 보유 중인 골드. |
| `players` | `List<HDPlayer>` | 최대 6명의 파티원 리스트. |
| `year` ~ `sec` | `int` | 게임 세계의 현재 시간 상태. |
| `magicTorch` | `int` | 마법의 횃불 지속 시간 타이머. |
| `levitation` | `int` | 공중 부양 지속 시간 타이머. |
| `walkOnWater` | `int` | 수상 보행 지속 시간 타이머. |
| `mindControl` | `int` | 정신 지배 관련 효과 타이머. |

### 주요 메서드
- `move(int dx, int dy)`: 그리드 기반의 이동을 처리하고 `faced` 방향을 업데이트합니다.
- `passTime(int h, int m, int s)`: 게임 내 시간을 경과시키고 `timeGoes`를 호출합니다.
- `timeGoes()`: 마법 효과 타이머를 감소시키고 독(poison) 상태 확인 등 주기적인 상태 변화를 처리합니다.
- `toJson() / fromJson()`: 세이브/로드 시스템을 위한 직렬화 처리를 담당합니다.

---

## 2. Unity 원본(`ObjParty.cs`)과의 비교

Flutter 구현은 원작의 설계를 현대적인 관점에서 단순화하고 평탄화(Flattening)한 구조를 가집니다.

### 구조적 차이점
- **메모리 레이아웃**: 
  - **Unity**: 직렬화 데이터용 `ObjPartyCore`와 런타임 상태용 `ObjPartyAux`로 구조를 분리했습니다. 또한 이진 호환성을 위해 수많은 `reserved` 배열을 포함하고 있었습니다.
  - **Flutter**: 단일 클래스로 평탄화되었습니다. `in_moving`과 같은 상태도 복잡한 카운터 대신 단순한 불리언 필드로 관리됩니다.
- **좌표 관리**:
  - **Unity**: 이동 중 부드러운 보간을 위해 `Pos<float>`를 사용했습니다.
  - **Flutter**: 논리적인 그리드 좌표는 `int`로 관리하며, 부드러운 이동 연출은 UI 레이어(`AnimatedContainer` 등)에서 처리합니다.
- **인벤토리**:
  - **Unity**: `PARTY_ITEM`, `PARTY_CRYSTAL`, `PARTY_RELIC` 등 명확한 열거형과 배열로 구분되었고, 복잡한 `Equiped` 구조의 백팩 시스템을 가졌습니다.
  - **Flutter**: 현재는 단순화된 플래그나 별도 리스트로 관리되며, 원작의 복잡한 장비 객체 시스템은 점진적으로 마이그레이션 중입니다.

### 기능적 변천
- **시간 로직**: 두 버전 모두 유사한 `timeGoes` 패턴을 공유합니다. Unity 버전에서는 `TimeGoes` 내에서 전멸 확인(`DetectGameOver`)을 호출했으나, Flutter 버전은 이를 좀 더 느슨하게 결합(Decouple)하여 관리합니다.
- **특수 지형 이동**: 원작의 `EnterWater`, `EnterSwamp` 등의 지형 로직은 `ObjParty.cs` 내부에 깊게 박혀 있었습니다. Flutter 버전에서는 이를 이동 흐름 상의 타일 속성 체크 로직으로 분리하여 마이그레이션하고 있습니다.

> [!NOTE]
> Flutter 버전은 코드의 가독성과 상태 바인딩의 효율성을 최우선으로 하며, Unity 버전은 이진 직렬화와 서브 픽셀 단위의 정밀한 이동 처리에 최적화되어 있었습니다.
