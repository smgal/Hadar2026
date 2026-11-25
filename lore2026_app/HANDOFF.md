# 인계 문서 — lore2026_app

2026-11-21 기준. 다음 작업을 이어받는 사람(또는 다음 Claude 세션)이 이 문서 하나로 상태를 잡을 수 있게 적었다.

## 지금 상태

- **무엇:** 로어 3부작(1993 「또 다른 지식의 성전」 · 1994 「다크 메이지 실리안 카미너스」 · 1995 「비전 속으로」) 복각. Flutter 앱이고, 사건은 `assets/ep1` · `ep2` · `ep3` 의 cm2 대본에 있다.
- **정본은 원작 Pascal 소스다.** https://github.com/smgal/LoreTrilogy_1993
  - 기획서·공략집·기억과 다르면 소스를 따른다. 사용자가 확인한 원칙이다.
  - 파일은 **조합형** 한글이다. `iconv -f cp949` 는 깨지고 Python `bytes.decode('johab')` 로 읽힌다.
  - 이 Mac 에는 사본이 없다. 필요하면 `git clone --depth 1` 로 임시 폴더에 받는다.
  - 1부 `LORE_1993_src`, 2부 `DARK_1994_src`, 3부 `MYST_1995_src`.
- **설계 자료:** `~/_GIT/SMG_GameDesignVault/LORE_TRILOGY` — `GameDesign`(기획서, 편마다 부록 A) · `Walkthrough`(공략집).
- **커밋한 것이 없다.** `lore2026_app/`, `packages/lore_*`(4개), `tools/lore_cm2_check`, `tools/lore_import` 가 모두 git 에 올라가지 않은 상태다. 사용자가 요청하기 전에는 커밋하지 않는다.
- **확인한 숫자 (2026-11-21):**
  - 앱 시험 69개 모두 통과 (`flutter test`)
  - `flutter analyze` 정보 22건 — 예전부터 있던 것이고 이 숫자가 기준값이다
  - cm2 검사기: 파일 72개 · 오류 0 · 경고 2. 경고 2건(`COMPANIONS_MET` · `JOINED_POLLUX`)은 알려진 것이다
- **꺼져 있는 것:** 웹 서버(5320)와 헤드리스 크롬(9333)은 지난 세션이 끝나며 멈췄다. 아래 「작업 환경」대로 다시 띄운다.

## 최근에 끝낸 일

### 1부 연출 2개 (원작 소스 순서대로)
- 판저 바이퍼를 이긴 뒤의 반신반인 장면 (`ep1/DungeonEvil.cm2`, LORESPEC.PAS:2045~2065)
  - 지도 칸에 「로드안」「에인션트 이블」 이름만 띄운다. 새 동사 `Battle::ShowEnemyNames` · `Battle::HideEnemyNames`.
- 엔딩 「이 게임의 끝마무리에 공헌한 인물」 (`ep1/Chamber.cm2`, LOREEND.PAS:127~212)
  - 줄마다 1부 인물 그림을 붙인다(`Letter::AddPicture`, 방식 `LETTER_CREDITS`). 원작과 다른 곳 하나: 배경이 바닥 무늬가 아니라 검은 바탕이다.
- 이로써 cm2 대본에 남은 TODO 표시는 0건이다.

### 개발자 모드 — 시나리오 중간에서 시작하기
- 사용법과 장면 자료 쓰는 법은 [README.md](README.md) 에 있다.
- 장면 165개: 1부 60 · 2부 45 · 3부 60(충성 · 반역 · 795년 갈래 포함). 자료는 `assets/dev/ep1.json` ~ `ep3.json`.
- 켜는 법:
  - 제목 화면 맨 아래 「[개발] 개발자 모드 켜기」. 고른 값은 다음 실행에도 기억한다.
  - 웹 주소에 `?dev=1`, 또는 데스크톱 실행 옵션 `--dart-define=LORE_DEV=true`.
- 코드: `lib/application/dev/` (`dev_mode.dart` 스위치 · `dev_scenes.dart` 자료 해석 · `dev_jump.dart` 건너뛰기와 메뉴)
- 일행을 맞추는 규칙:
  - 기술치는 「20 + 레벨 × 5」다.
  - 레벨 8 이상이면 마법사 계열 동료를 대마법사로 올린다.
  - 장비는 레벨에 맞는 값(500 × 레벨² + 500) 안에서 가장 비싼 것을 고른다.
  - 횃불은 기본 10 이다.
- 시험 `test/dev/` (21개): 장면 165개를 모두 실제로 건너뛰어 맵 · 서는 칸 · 사건 칸까지 걸어서 닿는지 · 플래그 이름이 대본에 있는지를 본다.

### 버그 수정 (2026-11-18)
| 증상 | 고친 곳 | 시험 |
|---|---|---|
| 전투 중 아래 상태 창 생명력이 안 바뀜 | `presentation/panels/status_panel.dart` — 전투 중에는 `HDCm2BattleAdapter().active` 의 값을 보인다 | 웹에서 확인 |
| 머리글이 있는 긴 글(1부 오프닝)의 마지막 줄이 「계속하려면 누르십시오」를 덮음 | `presentation/host/flutter_ui_host.dart` `linesPerPage` — 머리글이 없으면 13줄, 한 줄 머리글이면 10줄 | `test/presentation/host/dialog_page_test.dart` |
| 주인공 만들기 6번 질문의 긴 선택지가 잘림 | `presentation/panels/window_view.dart` `selectionBox` — 가장 긴 줄에 맞춰 창을 넓히고 화면 안으로 옮긴다 | `test/presentation/panels/selection_box_test.dart` |
| 맵에서 짧게 누른 키(걷기 · 말 걸기)가 무시됨 | `presentation/input/input_dispatcher.dart` 가 키가 내려간 순간을 `virtual_input_state.dart` 에 적고, `panels/player_sprite.dart` 가 다음 화면에서 한 번 쓴다 | 웹에서 확인 |
| 상태 칸에 「의식 불명」이 「의식 늘」로 잘림 | `status_panel.dart` — 칸보다 긴 글은 줄여서 보인다 | 웹에서 확인 |

- 「안 영기」 띄어쓰기는 **고치지 않았다.** 원작 1부 오프닝이 「제작자  안 영기  드림」으로 쓴다(LOREHELP.PAS:27). 3부 원작은 「안영기」와 「안 영기」를 둘 다 쓰고, 대본은 줄마다 원작대로다.

## 다음 할 일 (사용자와 정한 순서)

1. **개발자 모드로 장면을 직접 돌려 보기 — 1부부터.**
   - 지금까지 끝까지 돌려 본 장면은 1-54(판저 바이퍼 앞)와 3-47(반역 직후) 두 장면뿐이다. 나머지는 시험이 맵 · 서는 칸 · 닿는지만 봤고, 사건이 실제로 일어나는지는 모른다.
   - 장마다 대표 장면을 웹에서 돌려 보고, 막히는 곳을 고친다.
   - 이미 보인 것 (원인은 아직 보지 않음):
     - 1-54 판저 바이퍼 전투의 결과가 판마다 크게 다르다. 한 판은 이기고, 한 판은 6턴 넘게 공격이 거의 다 막혔다(「적은 그의 공격을 저지했다」).
     - 레벨 22 마법사 머린(생명력 1100)이 매번 먼저 쓰러진다.
     - 1-54 에서 베텔규스가 「맨손으로 메가 로보를 공격했다」. 개발자 모드의 장비 고르기가 그를 빠뜨렸는지 확인할 것.
2. **기획 결정이 필요한 항목 (부록 A).** 사용자가 「나중에 전체적으로 보자」고 미뤘다. 2번을 하다 막히는 항목부터 사용자에게 묻는다.
   - 1부 21건 · 2부 15건 · 3부 20건, 모두 56건 (`GameDesign/1st|2nd/11_부록A_원작동작과_버그.md`, 3부는 `GameDesign/15_부록A_원작동작과_버그.md`).
   - 이미 정한 것:
     - 3부 트롤킹 협상 금액은 금화 20,000 이다.
     - 1부 수용소 병사가 다시 덤비는 것은 원작대로 둔다.
     - 3부 하데스 테라로 가는 동굴(HdsGate) 출구는 원작대로 없다. 반역 루트가 아닐 때 입구를 막을지는 아직 정하지 않았다.
   - 게임을 끝낼 수 없게 되는 것이 먼저다. 3부 예:
     - 빛의 성에 걸어서 들어갈 수 없다.
     - 이동 구슬만 가지고 신전 섬에 건너가면 돌아올 수 없다.
     - 코볼트킹 탈출 전투에서 주인공이 혼자면 도망칠 수 없다.
3. **최종 배포 전에** `lib/application/dev/dev_mode.dart` 의 `HDDevMode.switchOnTitle` 을 `false` 로 바꾼다. 제목 화면의 켜기 · 끄기 줄이 사라진다.

## 작업 환경

### 시험 · 검사
```bash
cd lore2026_app
flutter test                    # 69개
flutter test test/dev/          # 개발자 모드 장면 165개
flutter analyze                 # 정보 22건이 기준값

cd ../tools/lore_cm2_check
dart run bin/check.dart --assets ../../lore2026_app/assets   # 파일 72 · 오류 0 · 경고 2
```

### 웹 빌드와 서버
Xcode 가 지워져 있어 웹으로 확인한다.
```bash
cd lore2026_app
flutter build web --release
cd build/web && python3 -m http.server 5320 --bind 127.0.0.1   # http://127.0.0.1:5320/?dev=1
```

### 브라우저로 확인하기
- 웨일 카나리아는 원격 디버깅이 꺼져 있다. 사용자의 브라우저를 다시 띄우지 않고 **따로 헤드리스 크롬**을 쓴다.
  ```bash
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
    --remote-debugging-port=9333 --user-data-dir=<임시 폴더>/chrome_prof \
    --window-size=1600,960 http://127.0.0.1:5320/
  ```
- 조종은 [tool/cdp.mjs](tool/cdp.mjs) 로 한다 (Node 25 의 내장 WebSocket 을 쓰고, 설치할 것이 없다).
  ```bash
  node tool/cdp.mjs nav "http://127.0.0.1:5320/?dev=1" 7000 -- key ArrowDown 3 -- key Enter -- sleep 800 -- shot /tmp/a.png
  ```
- **다시 빌드한 뒤에는 캐시를 무시하고 다시 읽는다.** 그냥 열면 브라우저가 예전 `main.dart.js` 를 쓴다.
  ```bash
  node tool/cdp.mjs cdp Network.enable -- cdp Network.setCacheDisabled '{"cacheDisabled":true}' -- cdp Page.reload '{"ignoreCache":true}' -- sleep 7000
  ```
- 개발자 모드에서 1-54 로 가는 키 순서 (제목 화면에서): `ArrowDown 3` → `Enter` → `Enter`(1부) → `ArrowDown 8` → `Enter`(9장) → `ArrowDown 1` → `Enter`.

### 셸
- `grep` 은 셸 함수로 감싸여 있어 결과가 없을 때 아무것도 찍지 않는다. `/usr/bin/grep` 을 쓴다.

## 알아 둘 규칙과 함정

- **좌표:** 대본 좌표는 1부터, 엔진 안(`pendingNavigation`)은 0부터다.
- **맵 상태:** 다른 맵의 칸 변화는 저장하지 않는다. 맵에 들어올 때 `FLAG_MAP` 이 플래그를 보고 다시 칠한다. 그래서 한 시점은 「플래그 + 변수 + 일행 + 자리 + 시각」으로 다시 만들 수 있다. 개발자 모드가 이 성질을 쓴다.
- **개발자 모드 장면의 한계:**
  - 진행 플래그만 넣었고, 보물 상자 플래그는 넣지 않았다. 가진 돈은 어림값이다.
  - 장면마다 켠 플래그 조합은 대본을 읽고 정했다. 원작으로 확인한 것이 아니다.
  - 3-53 즉위식처럼 도착하자마자 엔딩으로 가는 장면(`ending: true`)은 시험이 건너뛰지 않는다. 엔딩이 제목 화면을 다시 띄워 다음 장면을 흔들기 때문이다.
  - 반역 루트의 예약 사건은 1분 뒤로 줄여 두었다 (`timer [1, 1]` 등).
- **대화 창 한 쪽:** 줄 수는 `HDFlutterUiHost.linesPerPage` 가 패널 배치로 셈한다. 패널(`console_panel.dart`)의 여백 · 간격을 바꾸면 이 셈도 맞춘다.
- **선택 창 너비:** 그 자리의 기본 글씨(`DefaultTextStyle`)로 잰다. 테마가 글자 사이를 띄워서, 글꼴과 크기만으로 재면 짧게 나온다.
- **cm2 에 동사를 더하면** `assets/common/cm2_symbols.json` 도 고친다. 검사기와 앱이 이 표 하나를 읽는다. 안내는 [CM2_GUIDE.md](CM2_GUIDE.md).

## 사용자가 정해 둔 것

- 답은 한국어로 한다.
- 새 하위 에이전트(sub agent)를 만들지 않는다.
- 커밋은 요청이 있을 때만 한다.
- 원작 동작을 말할 때는 원작 소스를 열고 줄 번호와 함께 말한다. 찾지 못했으면 「찾지 못했다」고 쓰고, 「없다」고 쓰지 않는다.
- 3부 하데스 테라 입구 같은 부록 A 항목은 「나중에 전체적으로」 보기로 했다.
