# cm2_script CUI Sample

범용 스크립트 엔진 **cm2_script**의 모든 기능을 한 번씩 사용하는 CUI 데모입니다.  
인터랙티브 스토리 + 미니 퀴즈로, ASCII 아트와 이모지로 표현합니다.

## 실행 방법

```bash
cd cm2_script_sample
dart pub get
dart run bin/run.dart
```

선택지는 터미널에서 번호(1, 2, …)를 입력하면 됩니다.

## 스크립트별로 사용하는 기능

| 스크립트 | 사용 기능 |
|----------|-----------|
| **main.script** | `variable`, `Context::SetCurrent`, `include("path")`, `halt` |
| **intro.script** | `variable`, `.assign`, `Context::SetCurrent`/`Set`/`Get`/`GetCurrent`, 씬 메타(Location) 저장·조회, 선택 결과를 main context에 `intro_choice`로 저장 |
| **quiz.script** | `Context::SetCurrent`/`Set`/`Get`/`GetCurrent`, main context에서 `intro_choice` 조회(컨텍스트 간 데이터 전달), `question_count` 저장·조회, `.add`, `Equal`, `choice.Equal(1)`, `Less`, `Or`, `And`, `Not`, `Add`, `Random`, `JoinString`, `Print`, `halt` |

## 호스트에서 등록한 커맨드/함수

- **Print(msg)** — CUI에 한 줄 출력
- **Choice(prompt, "옵션1", "옵션2")** — 번호 선택 입력, 결과는 변수 `choice`에 저장
- **Wait(ms)** — 밀리초 대기
- **SetMode(n)** — `ScriptMode()` 값 설정 (0=스토리, 1=퀴즈 등)
- **GetChoice()** — 마지막 선택 값 반환 (등록 함수)

스크립트는 `scripts/` 디렉터리의 `.script` 파일이며, `include("파일명")`으로 불러옵니다.
