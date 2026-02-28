# Hadar 2026 Scripting Language (CM2) Manual

CM2 스크립트는 Hadar 2026 게임 엔진에서 사용하는 절차적 스크립트 언어입니다. 원작의 기능을 현대적인 Dart 기반 엔진으로 이식하였으며, 강력한 재귀적 표현식 평가 시스템을 갖추고 있습니다.

## 1. 기본 구조

- **라인 기반:** 세미콜론 없이 줄바꿈으로 명령을 구분합니다.
- **들여쓰기(Indentation):** `if` 문 등의 블록 구조는 탭(Tab) 또는 공백 들여쓰기를 통해 구분합니다.
- **주석:** `#` 기호로 시작하는 라인은 무시됩니다.
- **대소문자:** 함수 이름과 예약어는 대소문자를 구분합니다.

---

## 2. 표현식 및 변수 (Expressions & Variables)

### 2.1 값의 판별 (Truthiness)
스크립트의 모든 값은 `bool`로 변환될 수 있습니다.
- **거짓(False):** 숫자 `0`, 문자열 `"0"`, 빈 문자열 `""`, `null`.
- **참(True):** 그 외의 모든 값 (일반적으로 `1` 사용).

### 2.2 재귀적 평가 (Recursive Evaluation)
모든 함수의 인자 자리에 다른 함수를 중첩해서 사용할 수 있습니다.
- 예: `if (Not(Flag::IsSet(32)))`
- 예: `Talk(Player::GetName(Add(1, 0)))`

### 2.3 변수 정의 및 할당
- `variable(name)`: 새 변수를 정의합니다.
- `name.assign(value)`: 변수에 값을 할당합니다.

---

## 3. 제어문 (Control Flow)

### 3.1 if 문
```python
if (Condition)
    # 참일 때 실행
else
    # 거짓일 때 실행
```

---

## 4. 예약 함수 레퍼런스

### 4.1 논리 연산
- `Not(val)`: 값을 반전시킵니다 (0 -> 1, 1 -> 0).
- `Or(v1, v2, ...)`: 인자 중 하나라도 참이면 1을 반환합니다.
- `And(v1, v2, ...)`: 모든 인자가 참이면 1을 반환합니다.
- `Equal(v1, v2)`: 두 값이 같으면 1을 반환합니다.
- `Less(v1, v2)`: v1 < v2 이면 1을 반환합니다.

### 4.2 수치 및 랜덤
- `Add(v1, v2, ...)`: 모든 인자의 합을 반환합니다.
- `Random(max)`: 0부터 (max-1) 사이의 정수를 반환합니다.

### 4.3 플래그 및 시스템 변수
- `Flag::Set(id)`: 해당 번호의 플래그를 켭니다.
- `Flag::Reset(id)`: 플래그를 끕니다.
- `Flag::IsSet(id)`: 플래그가 켜져 있는지 확인합니다.
- `Variable::Set(id, val)`: 시스템 전역 변수 배열에 값을 저장합니다.
- `Variable::Get(id)`: 시스템 전역 변수 값을 가져옵니다.
- `ScriptMode()`: 현재 실행 모드(FLAG_TALK, FLAG_EVENT 등)를 반환합니다.

### 4.4 맵 및 이동 판정
- `On(x, y)`: 주인공이 해당 좌표에 있으면 1을 반환합니다.
- `OnArea(x1, y1, x2, y2)`: 주인공이 해당 영역 내에 있으면 1을 반환합니다.
- `Party::PosX()`, `Party::PosY()`: 현재 파티의 X, Y 좌표를 반환합니다.
- `Map::LoadFromFile("path")`: 맵 데이터를 로드합니다.
- `Map::SetType(type)`: 맵의 타일셋 타입을 설정합니다 (TOWN, KEEP, GROUND, DEN).
- `Map::ChangeTile(x, y, tileId)`: 특정 좌표의 타일을 동적으로 변경합니다.
- `DisplayMap()`: 변경된 맵 상태를 화면에 갱신합니다.

### 4.5 캐릭터 및 대화
- `Talk("message")`: 메시지 박스에 대화를 출력합니다.
- `Player::GetName(id)`: n번 캐릭터의 이름을 반환합니다 (1부터 시작).
- `Player::GetGenderName(id)`: 캐릭터의 성별 호칭(군/양 등)을 반환합니다.
- `PushString("str")`: 문자열 스택에 값을 넣습니다.
- `PopString(count)`: 스택에서 n개의 문자열을 합쳐서 가져오고 비웁니다.

---

## 5. 고급 기능

### 5.1 타일 복사 (Visual Overrides)
- `Tile::CopyTile(targetId, sourceId)`: 타일셋의 특정 번호 타일을 다른 타일 이미지로 대체합니다. 주로 이벤트 발생 후 지역의 외관을 바꿀 때 사용합니다.

### 5.2 선택지 시스템
```python
Select::Init()
Select::Add("예")
Select::Add("아니오")
Select::Run()
if (Equal(Select::Result(), 1))
    # '예' 선택 시
```
