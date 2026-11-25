# lore2026_app 맵 스크립트 작성 안내 (cm2)

로어 3부작의 사건·대사는 맵마다 한 개씩 있는 cm2 스크립트가 맡는다. 엔진은 hadar2026_app 과
같고(`packages/cm2_script`), **로어 쪽에서 달라진 것은 넷**이다.

| | hadar2026_app | lore2026_app |
|---|---|---|
| 좌표 | 0부터 | **1부터** — 기획서·공략집의 (x,y) 를 그대로 쓴다 |
| 플래그·변수 | 번호 (`Flag::Set(51)`) | **이름** (`Flag::Set("ORC_KING_DEAD")`) — 번호 충돌이 없다 |
| 타일 바꾸기 | 새 타일 번호 | **원작 타일 번호**(0~55) — 엔진이 그 맵 유형의 그림·통행으로 풀어 준다 |
| 스크립트 자리 | `assets/*.cm2` | `assets/ep1|ep2|ep3/<맵 키>.cm2` + `assets/common/const.cm2` |

동사 표의 정본은 `assets/common/cm2_symbols.json` 이다. **표에 없는 동사는 없다** — cm2 는 모르는
명령을 건너뛰고 모르는 함수에 0 을 돌려주므로, 지어낸 이름은 조용히 틀린 갈래를 탄다.

검사:

```bash
cd tools/lore_cm2_check
dart run bin/check.dart --assets ../../lore2026_app/assets ../../lore2026_app/assets/ep3/Lore.cm2
dart run bin/check.dart --assets ../../lore2026_app/assets      # 전부 + 플래그 이름 짝 맞추기
```

## 1. 문법

```
# 주석
include("common/const.cm2")        # 맨 위 한 번
variable(temp)                     # 이 스크립트 안에서만 쓰는 임시 변수
if (Equal(ScriptMode(), FLAG_TALK))
	if (On(27, 32))
		Say("광산 감독", "오, {주인공}.")
	else
		Talk("...")
```

- **들여쓰기는 탭 한 가지로.** 블록은 들여쓰기로 정해진다. `else` 는 짝이 되는 `if` 와 같은 깊이에 혼자 쓴다. `elseif` · 반복문은 없다.
- 한 줄에 명령 하나: `명령(인자, ...)`. 조건은 `if (함수(...))` 하나 — 여러 조건은 `And(a, b)` · `Or(a, b)` · `Not(a)` 로 묶는다.
- 문자열은 큰따옴표. **본문 안에 큰따옴표를 쓰지 않는다** (작은따옴표나 「」로 바꾼다). 쉼표·괄호는 따옴표 안이면 괜찮다.
- 내장 함수: `Equal` `Less` `Add` `Not` `And` `Or` `Random(n)`(0~n-1) `JoinString(a, b, ...)` `ScriptMode()`.
  덧붙인 것: `Greater` `GreaterEqual` `LessEqual` `NotEqual` `Sub` `Mul` `Div` `Mod`.
- 임시 변수: `temp.assign(값)` · `temp.add(1)`. **맨 바깥(들여쓰기 없는 자리)의 `.assign` 은 스크립트가 불릴 때마다 다시 실행된다** — 바깥에는 `variable(...)` 만 두고 `.assign` 은 블록 안에서 쓴다.
- `halt` 는 이번 실행을 거기서 끝낸다.

## 2. 스크립트가 불리는 때 — `ScriptMode()`

| 값 | 때 | 사건이 일어난 칸 |
|---|---|---|
| `FLAG_MAP` | 맵에 들어온 직후 (플래그에 따라 맵을 고친다 · 조우 표 · 음악) | — |
| `FLAG_TALK` | 사람 칸으로 걸어 부딪혔다 | 그 사람 칸 |
| `FLAG_SIGN` | 푯말 칸에 부딪혔다 (머리글 「푯말에 써 있기를:」이 자동으로 붙는다) | 그 푯말 칸 |
| `FLAG_ENTER` | 입구 칸에 부딪혔다 | 그 입구 칸 |
| `FLAG_EVENT` | 이벤트 칸(숨은 칸 포함)을 **밟았다** | 밟은 칸 |
| `FLAG_ITEM` | 이 맵에서 이야기용 물건(크로매틱 크리스탈 · 크리스탈 볼)을 썼다 | 서 있는 칸 |
| `FLAG_TIMER` | 예약한 시각이 됐다 — **`episode.cm2` 만** 불린다 | — |
| `FLAG_START` | 그 편을 새로 시작했다 — **`episode.cm2` 만** | — |
| `FLAG_PROPHECY` | 초능력 「예언」을 썼다 — **`episode.cm2` 만** | — |
| `FLAG_OPENING` | 편을 고른 직후, 캐릭터를 만들기 전 — **`episode.cm2` 만**. 여는 글. `{주인공}` 은 아직 없다 | — |

`On(x, y)` · `OnArea(x1, y1, x2, y2)` 가 「사건이 일어난 칸」을 본다. 맵 스크립트의 뼈대:

```
include("common/const.cm2")
variable(temp)

if (Equal(ScriptMode(), FLAG_MAP))
	Music::Play("town")
	if (Flag::IsSet("JOINED_ALCOR"))
		Map::ChangeTile(22, 50, 47)       # 가입한 동료의 자리를 빈 바닥으로

if (Equal(ScriptMode(), FLAG_TALK))
	if (On(12, 49))
		Say("여관 주인", "어서 오십시오.")

if (Equal(ScriptMode(), FLAG_SIGN))
	if (On(51, 84))
		Talk("여기는 로어성의 입구")

if (Equal(ScriptMode(), FLAG_EVENT))
	if (OnArea(5, 95, 96, 95))             # 출구 줄
		Ask("여기서 나가기를 원합니까 ?")
		if (Equal(Select::Result(), 1))
			LoadScript("E3_Ground1", 20, 12)
		else
			WarpPrevPos()
```

- 이벤트 칸을 밟았는데 스크립트가 아무것도 하지 않으면 그냥 바닥이다.
- **맵은 들어올 때마다 원본에서 새로 시작한다.** 가입·격파·개방으로 바뀐 칸은 `FLAG_MAP` 에서 플래그를 보고 다시 고친다 (기획서 부록 B.3).
- 사건이 그 자리에서 맵을 바꿀 때는 `Map::ChangeTile` 뒤에 `DisplayMap()`.

## 3. 글

| 명령 | 쓰임 |
|---|---|
| `Talk("...")` | 서술, 화자를 따로 적지 않은 글. 기획서의 `> 문장` |
| `Say("화자", "...")` | 대사. 기획서의 `> **이름** : 문장` |
| `Notice("황금 + 4")` | 시스템 알림. 기획서의 `> *[ ... ]*` (대괄호는 빼고 쓴다) |
| `Answer("...")` | 플레이어 쪽이 하는 말 한 줄 |
| `PressAnyKey()` | 키를 기다리고 창을 지운다 — 장면이 넘어가는 자리 |
| `ClearText()` | 기다리지 않고 지운다 |
| `SetHeader("...")` | 대화 창 머리글 |
| `Log("...")` | 오른쪽 아래 진행 기록에 한 줄 (대화 창을 쓰지 않는 짧은 알림) |
| `Letter::Clear()` · `Letter::Add("문단")` · `Letter::Show(색, 방식)` | **검은 화면 한 장**에 글을 보인다 — 오프닝 편지와 엔딩 글. 색은 원작 16색 번호(12 빨강 · 14 노랑 · 15 흰색 · 7 회색), 방식은 `LETTER_STILL`(한 번에) · `LETTER_SCROLL`(아래에서 위로 흐름, 첫 키는 끝으로 건너뜀) · `LETTER_LIGHTNING`(키를 누를 때까지 드물게 번개) · `LETTER_CREDITS`(번개 → 첫 키에 오른쪽 가장자리를 1부 인물이 걸어 내려감 → 다음 키에 닫힘, 1편 엔딩) |
| `Letter::AddPicture("10 14 18 / 11 15 19", "문단")` | 문단 왼쪽에 **1부 인물 그림**(`lore1_chara.png` 번호)을 붙인다. 한 줄은 빈칸으로, 줄 바꿈은 `/` 로 가른다. 한 칸짜리는 가운데에 선다 |
| `Arrival::Talk("...")` · `Arrival::Say("화자", "...")` | **다음 맵에 들어선 뒤에** 낼 글을 쌓는다. `LoadScript` 바로 앞에 쓴다 |

- `Screen::FadeOut()` 은 **지도 화면만** 어둡게 한다 — 원작처럼 오른쪽 글 창의 `Talk` 는 그대로 보인다
  (「화면이 어두워지고 30분이 흐른다」 → `Talk("그로부터 30분이 지났다.")`). 화면 전체가 검어지는 글은 `Letter::Show` 로 쓴다.
- 편지 화면의 색은 색 규칙(고유한 물건·지명 강조에만)의 **예외**다 — 엔딩 글은 본 게임이 아니다(원작자 확인).

  ```
  Letter::Clear()
  Letter::Add("새로운 로드안이 된 당신에게.")
  Letter::Add("역시 당신은 나의 기대를 저버리지 않았소. ...")
  Letter::Add("— 타임워커 알비레오로부터.")
  Letter::Show(12, LETTER_SCROLL)    # 엔딩 B — 검은 바탕에 붉은 글씨가 위로 흐른다
  ```
- `LoadScript` 에서 스크립트가 끝나므로 그 뒤에 쓴 `Talk` 는 나오지 않는다. 도착한 자리에서 들어야 하는 말은
  `Arrival::Say` 로 쌓는다. 도착한 맵의 `FLAG_MAP` 이 끝난 뒤에 나오고, 다 나오면 키를 기다린다.

  ```
  Variable::Set("DOME_STAGE", 2)
  Arrival::Say("에인션트 이블", "휴... 저의 염력을 총동원하여 ... 도시를 건설해 보았습니다.")
  LoadScript("E3_Dome", 25, 50)      # 세워진 도시에 서서 이 말을 듣는다
  ```

- 창이 가득 차면 엔진이 알아서 멈췄다 넘긴다. 긴 글을 손으로 쪼갤 필요가 없다.
- **문단 하나가 `Talk` 하나.** 원작 화면 폭에 맞춘 줄바꿈은 넣지 않는다.
- 색: `@C빨강@@` `@A초록@@` `@9파랑@@` `@E노랑@@` `@B하늘@@` `@D자주@@` `@F흰색@@` `@G주황@@` — 원작의 16색 번호(16진수 한 글자)이고 `@@` 로 닫는다. 고유한 물건·지명 강조에만 쓴다.

### 이름과 조사 넣기

글 안의 `{...}` 를 엔진이 바꿔 넣는다 (`Talk` `Say` `Notice` `Answer` `Log` `Select::Add` `Ask`).

| 쓰기 | 나오는 것 |
|---|---|
| `{주인공}` · `{1}` | 1번 대원 이름 |
| `{3}` | 3번 자리 대원 이름 (1~6) |
| `{주인공:은/는}` · `{2:이/가}` · `{1:을/를}` · `{1:와/과}` · `{1:으로/로}` | 이름 + 받침에 맞는 조사 |
| `{$temp}` · `{$temp:을/를}` | cm2 변수의 값 (+ 조사) |

기획서의 `{주인공}{은/는}` 은 `{주인공:은/는}` 으로 옮긴다. 식으로 만들 때는
`JoinString(Player::GetName(2), "의 검")` · `Josa(Player::GetName(2), "이/가")`.

### 고쳐 쓰기

원작자가 허락했다: **띄어쓰기 · 맞춤법 · 손으로 넣은 줄바꿈은 고친다.** 뜻·말투·농담·고유명사·
원작 특유의 어휘는 건드리지 않는다. 기획서 제14장은 원문을 오타까지 그대로 실었으므로, 옮기면서
`할수있는` → `할 수 있는`, `있읍니다` → `있습니다`, `? ` 앞의 불필요한 공백(`합니까 ?` → `합니까?`) 같은 것을 바로잡는다.

## 4. 고르기

```
Select::Init()
Select::Add("어떻게 하겠습니까?")          # 첫 줄은 물음
Select::Add("돈을 준다")                    # 1
Select::Add("싸운다")                       # 2
Select::Run()
if (Equal(Select::Result(), 1))            # 0 = 취소(Esc)
	...
```

예/아니오는 `Ask("들어가기를 원합니까?")` 한 줄 — `Select::Result()` 가 1 이면 예, 2 면 아니오, 0 이면 취소.

## 5. 진행 상태

```
Flag::Set("ORC_KING_DEAD")      Flag::IsSet("ORC_KING_DEAD")
Variable::Set("MAIN_STAGE", 3)  Variable::Get("MAIN_STAGE")   Variable::Add("SPIRITS_SEALED")
```

- 이름은 기획서 부록 B(제3부 `16_부록B`, 제1부·제2부 `12_부록B`)의 영문 대문자 이름을 **그대로** 쓴다.
- 부록에 없는 기록이 필요하면 `맵키_뜻` 꼴로 짓는다 (`LORE_INN_GREETED`). 다른 맵과 함께 쓰는 이름은 부록의 것만.
- `1~8` 처럼 묶여 있는 이름은 `ORC_RESIDENT_1_DEAD` … `ORC_RESIDENT_8_DEAD` 로 푼다.
- 언어: `ORC_SCRIPT` `ORC_SPEECH` 같은 플래그를 `Flag::IsSet` 으로 본다. 독심 중인지는 `Party::CheckIf(CHECKIF_MINDCONTROL)`.

## 6. 맵

| 명령·함수 | |
|---|---|
| `LoadScript("E3_Lore", x, y)` | 맵을 옮긴다. 좌표를 빼면 그 맵의 시작 위치. **이 줄에서 스크립트가 끝난다** |
| `Map::ChangeTile(x, y, 타일)` | 그 칸을 원작 타일 번호로 바꾼다 (그림 · 통행 · 사람/푯말/입구 여부가 함께 바뀐다) |
| `Map::ChangeTileArea(x1, y1, x2, y2, 타일)` | 사각형 전체 |
| `DisplayMap()` | 바꾼 것을 화면에 반영 |
| `WarpPrevPos()` | 한 걸음 전 자리로 (출구에서 「아니오」) |
| `Party::Warp(x, y)` · `Party::Move(dx, dy)` · `Party::Face(FACE_UP)` | 같은 맵 안 이동 · 한 칸 걷기 · 방향 |
| `Party::Hide()` · `Party::Show()` | 일행 그림만 감추고 다시 보인다. 감춘 채 `Party::Warp` 하면 카메라만 옮겨 간다 — 주인공 없이 화면이 흘러가는 장면(3편 결말 A 의 에필로그) |
| `Party::PosX()` · `Party::PosY()` · `Party::Faced()` | 지금 자리 |
| `Map::SetHandicap(HANDICAP_TELEPORT, 1)` | 이 맵에서 막히는 마법 (`TILECHANGING` `BIGTILECHANGING` `ETHEREAL` `TELEPORT` `EAGLEEYE` `SEETHROUGH` `CLAIRVOYANCE`). `TELEPORT` 는 이동 구슬을, `EAGLEEYE` 는 수정 구슬을 함께 막는다 |
| `Screen::ShowScenery("E3_Ground1", 44, 50)` | 그 맵의 그 칸을 가운데로 한 9×11칸을 그 맵의 그림 그대로 창에 비춘다 (3편 크리스탈 볼). 그 맵의 스크립트는 돌지 않는다 — 맵 파일의 처음 모습이다. 밤이고 달빛이 없으면 어둡다. 아무 키나 누르면 닫힌다 |
| `Map::SetMagicBarrier(x1, y1, x2, y2)` | 이 사각형을 공간 이동·기화 이동(이동 구슬 포함)이 건너지 못한다 — 지나가는 칸이든 내려서는 칸이든. 걸어서 지나가야 하는 줄(이블 실의 문 줄, 와이번 줄)을 지킨다. `FLAG_MAP` 에서 걸고, 맵을 옮기면 풀린다 |
| `Map::SetLightArea(x1, y1, x2, y2)` · `Map::SetDark(1)` · `Party::SetTorch(n)` | 조명 |
| `Map::Is("E1_LastDitch")` | 지금 그 맵인가 (1/0). 맵과 무관하게 불리는 `episode.cm2` 의 예언이 쓴다 |
| `Map::ChangeHiddenTiles(x1, y1, x2, y2, 타일)` | 사각형 안의 **숨은 칸(0)만** 바꾼다 (이블 컨센트레이션의 성이 떠오르는 자리) |
| `Map::ReplaceTile(x1, y1, x2, y2, 원래 타일, 새 타일)` | 사각형 안에서 그 타일로 깔린 칸만 바꾼다 (호수 → 용암) |
| `Map::ScatterTile(x1, y1, x2, y2, 타일, 백분율)` | 사각형 안의 칸마다 그 확률로 그 타일로 바꾼다 (원작의 「모든 칸을 10분의 1 확률로 45번」) |
| `Map::IsTile(x, y, 타일)` | 그 칸이 지금 그 타일로 깔려 있는가 (1/0). 「(58,100) 이 아직 늪이 아니면」 같은 조건에 쓴다 |
| `Map::GetTile(x, y)` | 그 칸에 지금 깔린 원작 타일 번호. 맵 밖이면 -1 |
| `Map::IsPassable(x, y)` | 일행이 걸어서 그 칸에 들어설 수 있는가 (1/0). 걷기와 같은 판정 — 벽·사람·푯말·입구는 0, 물은 물 위를 걷는 동안만 1 |
| `Event::StepAgain()` | 이 스크립트가 끝나면 일행이 지금 선 칸을 밟은 것으로 다시 본다. `Party::Warp` · `Party::Move` 는 내려선 칸의 사건을 일으키지 않으므로, 미끄럼처럼 내려선 칸의 사건도 일어나야 할 때 쓴다 (베리알의 동굴) |

`Map::GetTile` 은 칸의 그림과 행동을 보고 번호를 거꾸로 찾는다. 그림과 행동이 똑같은 번호가 있는 맵에서는
작은 번호를 돌려준다 — 들판의 23·49, 동굴·성채 몇 곳(제1부 피라미드 · 제2부 베리알의 동굴 · 제3부 메너스 금광 등)의
0·52. 그래서 **조건에는 `Map::IsTile` 을 쓴다**. `Equal(Map::GetTile(x, y), 52)` 는 그런 맵에서 언제나 0 이다.
번호를 잠시 기억했다가 `Map::ChangeTile` 로 되돌려 놓는 데는 `Map::GetTile` 을 써도 된다 — 짝은 그림도 행동도 같다.

```
if (On(8, 30))
	if (Map::IsTile(9, 30, 53))   # 이미 푯말이 솟았다
		halt
	Map::ChangeTile(9, 30, 53)
	DisplayMap()
	Talk("갑자기 땅에서 푯말이 솟아 나왔다.")
```

맵 이름은 `E<편>_<키>` 다: `E3_Ground1` `E3_Lore` `E1_CastleLore` `E2_Pyramid` … (`assets/maps/MapInfos.json`).

**타일 번호의 뜻은 맵 유형마다 다르다** (기획서 제11장 11.2). 자주 쓰는 것:

| 유형 | 빈 바닥으로 | 비고 |
|---|---|---|
| 마을형 | 그 맵의 기본 바닥 (`MapInfos.json` 의 `default`; 로어성 44, 라스트디치 47 …) | 27~47 이 통행 |
| 요새형 | 43 (맵의 `default`) | 40~47 이 통행 |
| 동굴형 | 맵의 `default` (41~47) | |
| 필드형 | 41 | 24~47 이 통행 |

「사람이 사라진다」는 `Map::ChangeTile(x, y, <그 맵의 기본 바닥>)`. 「숨은 이벤트 칸으로 만든다」는 타일 0.

### 장면 속 인물 — 배우

사람이 걸어 나오거나 떠나는 장면은 **칸을 바꾸지 말고 배우로** 한다. 칸을 바꾸면 지나간 자리의
바닥(양탄자 같은)이 지워지고, 사람은 칸 단위로 뚝뚝 움직이는데 주인공은 칸 사이를 미끄러져 서로 어긋난다.

```
Actor::Show("병사1", 53, 50, 36)      # 원작 타일 53 번의 인물을 (50,36) 에 세운다 (칸은 그대로)
Actor::Show("병사2", 53, 52, 36)
Actor::Move("병사1", 0, -1)            # 걷기 시작 — 기다리지 않는다
Actor::Move("병사2", 0, -1)
Party::Move(0, -1)                     # 주인공도 함께 — 이것은 끝날 때까지 기다린다
Actor::Wait()                          # 배우들이 다 설 때까지
Actor::Hide("병사1")
```

- 배우는 주인공과 같은 빠르기로 걷는다(한 칸 0.16초). 천천히 걷게 하려면 걸음 사이에 `Wait(…)`.
- 배우는 장면 동안만 있다 — 맵을 옮기면 사라지고 세이브에 들어가지 않는다. 계속 서 있어야 하는 사람은 칸(`Map::ChangeTile`)으로 둔다.
- 배우는 길을 막지 않는다. 말을 걸 수 있는 사람도 칸이다.
- 타일 표에 없는 그림은 `Actor::ShowSprite("이름", 번호, x, y)` 로 3부 스프라이트 띠(24px 28칸)에서 세운다.
  번호는 원작 소스(MYST_1995_src 의 PutSprite)와 같다: 에너지 공 20 · 네크로만서 25(위)·26(아래) · 드라코니안킹의 큰 모습 14·16·18(윗줄)
  / 15·17·19(아랫줄) — 그 전에 왕 칸에 작은 모습 12 · 제작자 24. 여러 칸짜리 그림은 조각마다 배우를 하나씩 세운다.

  ```
  Party::Hide()                                   # 주인공이 네크로만서로 변한다
  Actor::ShowSprite("네크로만서 위", 25, 51, 30)
  Actor::ShowSprite("네크로만서 아래", 26, 51, 31)
  ```

## 7. 일행

| 명령·함수 | |
|---|---|
| `Party::HasFreeSeat()` → `Party::Join("canopus")` → `Party::Joined()` | 동료 가입 (2~5번 빈 자리). 키는 `packages/lore_world` 의 동료 표 |
| `Party::JoinReplace("polaris")` | 제1부 합류 — 빈 자리가 없으면 「교체 시킬 인물은 누구입니까?」(2~6번). 결과는 `Party::Joined()` |
| `Party::JoinedSeat()` | 방금 합류한 사람의 대원 번호(1~6). `Player::ChangeAttribute(Party::JoinedSeat(), "hp", 1)` 처럼 |
| `Party::PromoteDemigod()` · `Party::Unlock("special_magic" \| "esp")` · `Party::HasEsp(40)` | 제1부: 반신반인 승격 · 특수 마법/초자연력 수련 해금 · 초자연력 기술치 n 이상인 대원이 있는가 |
| `Party::ArmBareHanded("weapon.dagger")` | 무기를 들지 않은 1~5번에게 그 무기를 장착 (로어성 무기고) |
| `Party::ReviveFallen()` · `Party::StripEquipment()` | 쓰러진 대원을 HP 1 로 (제2부 이벤트 패배 전투) · 1~5번의 장비를 모두 잃음 (제2부 은행) |
| `Party::BlessWeapons()` | 제1부 리겔의 「신의 축복」 — 무기를 든 대원마다 행운 판정 두 번(0~19 < 행운)을 모두 통과하면 무기 공격력 ×1.2. 무기를 바꾸면 끝난다. 누가 받았는지는 말하지 않는다 |
| `Party::Has("canopus")` | 그 동료가 지금 일행에 있는가 |
| `Party::SetAssistant("draco_prisoner")` · `Party::SetAssistant("enemy", 적 번호)` | 6번 보조 일원을 앉힌다 (있던 것은 사라진다) |
| `Party::RemoveAssistant()` · `Party::HasAssistant()` | |
| `Party::HideCompanions()` · `Party::RestoreCompanions()` | 2~5번을 잠시 숨겼다 되돌린다 (부록 B.4) |
| `Party::Dismiss(n)` | n번을 영영 내보낸다 |
| `Party::PlusGold(n)` `Party::PlusFood(n)` `Party::PlusArrows(n)` | 음수면 뺀다 |
| `Party::Gold()` `Party::Food()` `Party::Arrows()` `Party::Count()` `Party::AvgLevel()` | |
| `Party::GiveExp(n)` | 행동 가능한 1~5번 각자에게 경험치 n |
| `Party::HealAll()` · `Party::Rest(시간)` | 전원 완전 회복 · 쉰 것으로 처리 |
| `Party::CheckIf(CHECKIF_LEVITATION)` | `MAGICTORCH` `LEVITATION` `WALKONWATER` `WALKONSWAMP` `MINDCONTROL`(독심 중) |
| `Party::SetBuff(CHECKIF_LEVITATION, 0)` | 그 효과를 끄거나 값을 정한다 |
| `Player::GetName(n)` `Player::IsAvailable(n)` `Player::CanAct(n)` | |
| `Player::GetAttribute(n, "luck")` · `Player::ChangeAttribute(n, "hp", 1)` · `Player::AddAttribute(n, "agility", 1, 20)` | 속성 이름은 아래 |
| `Item::Give("item.hp_potion", 5)` · `Item::Take(...)` · `Item::Count(...)` | 물품 `item.*` · 크리스탈 `crystal.*` · 장비 `weapon.*` `shield.*` `armour.*`(배낭으로) |

속성 이름: `strength` `mentality` `concentration` `endurance` `resistance` `agility` `accuracy` `luck`
`level` `hp` `mp` `exp` `poison` `unconscious` `dead` `class` `family` `gender` `ac` `skill1`~`skill6`.

물건 키 — 물품: `item.hp_potion` `item.mp_potion` `item.antidote_herb` `item.awakening_herb` `item.revival_herb`
`item.summon_scroll` `item.big_torch` `item.seeing_orb` `item.flying_boots` `item.warp_orb` ·
크리스탈: `crystal.flame` `crystal.frost` `crystal.dark` `crystal.ebony` `crystal.spirit` `crystal.summon`
`crystal.energy` `crystal.chromatic` `crystal.ball` · 장비 키는 `packages/lore_world/README.md`.

## 8. 시간

`Time::Pass(시간, 분)` · `Time::Set(년, 월, 일, 시, 분)` · `Time::Year()` `Time::Month()` `Time::Day()` `Time::Hour()` `Time::Minute()`.

예약: `Timer::Set(번호, 분)` 은 그만큼 뒤에 `episode.cm2` 를 `FLAG_TIMER` 로 부른다 (`Timer::Id()` 가 번호).
한 번에 하나만 예약된다. `Timer::Clear()` 로 지운다.
분이 0 이면 걸어 둔 스크립트가 끝나는 대로 울린다 — 다음 걸음을 기다리지 않는다.
그 스크립트가 `LoadScript` 로 맵을 옮기면 새 맵의 `FLAG_MAP` 이 끝난 뒤에 울린다.
3편 엔딩이 이렇게 불린다 (엔딩을 일으킨 스크립트가 `Timer::Set(번호, 0)` 을 하고 `halt`).

날 단위 기한(제2부의 월식 · 레굴루스가 돌아오는 날)은 예약 대신 **날 번호**로 적어 두고 비교한다:
`Variable::Set("ECLIPSE_DAY", Add(Time::DayNumber(), 20))` → 그 맵에서 `Greater(Time::DayNumber(), Variable::Get("ECLIPSE_DAY"))`.
글에 날짜를 낼 때는 `Time::YearAfter(n)` · `Time::MonthAfter(n)` · `Time::DayAfter(n)` 을 변수에 담아 `{$y}년 {$m}월 {$d}일`.

## 9. 가게와 시설

사람 칸에서 한 줄로 부른다. 인사말·목록·값·거절 문구는 엔진이 낸다 (기획서 제10장 10.7).

`Shop::Grocery()` 식료품점 · `Shop::Weapon()` 무기상점 · `Shop::Herb()` 약초 가게 · `Shop::Goods()` 물품 가게 ·
`Shop::Hospital()` 병원 · `Shop::Training()` 훈련소·마법 학교·전직 · `Shop::ExpTraining()` 경험치 훈련장.
`Shop::StatTraining("mentality", 30)` — 제2부 고대 유적의 석상: 황금을 받고 1~5번 중 한 명의 능력치를 1 올린다(값은 엔진 표).

## 10. 전투

```
Battle::Init()
Battle::RegisterEnemy(19, 4)                    # 그 편 적 표의 19번을 네 마리
Battle::RegisterEnemy(24)
Enemy::ChangeAttribute(5, "name", "오크킹")      # 등록 순서 5번째의 이름·능력치를 고친다
Battle::RegisterVariant("major_mummy", 1)        # 이름·수치를 바꾼 보스(변형) — 키는 packages/lore_battle/CONTRACT.md
Battle::Start(BATTLE_NO_ESCAPE)
if (Equal(Battle::Result(), BATTLERESULT_WIN))
	Flag::Set("ORC_KING_DEAD")
else
	WarpPrevPos()                                # 도망쳤다 — 사건은 끝나지 않았다
```

- 적 번호는 **그 편의 적 표 번호**다 (제3부 `12_적_데이터` 1~74, 제1부·제2부 `08_적과_전투` 1~75).
- `Battle::Start(값)`: `BATTLE_NORMAL`(「적이 출현했다!!!」→ 교전/도망을 먼저 묻는다) · `BATTLE_NO_ESCAPE`(도망 불가) ·
  `BATTLE_ENEMY_FIRST`(적 선공) · `BATTLE_NO_PRELUDE`(묻지 않고 바로) · `BATTLE_LOSE_OK`(져도 게임 오버가 아니다 — 결과가 `BATTLERESULT_LOSE` 로 돌아온다).
  여럿이면 `Battle::Start(Add(BATTLE_NO_ESCAPE, BATTLE_LOSE_OK))`.
- `BATTLE_REPEAT` — 「반복」. 도망에 성공해도 남은 적(입힌 피해 그대로, 쓰러진 적은 빠진 채)과 곧바로 다시, 적 선공으로 싸운다.
  기획서의 「도망에 성공해도 다시 싸운다」·「이길 때까지 반복」·「도주는 허용되지 않는다」가 이것이다. 다시 붙을 때의 문장은
  `Battle::Init()` 뒤에 `Battle::SetRepeatText("하지만 너무 많은 적들에게 포위되어 도망갈 수가 없었다.")`.
- `BATTLE_RENEW` — 「새 편성」. 이기면 처음 등록한 적이 새로 편성되어 다시 덤벼 온다. 도망에 성공하거나 지면 끝난다.
  - 코볼트성의 탈출(「이기면 새 킹과 다시 싸운다, 도망에 성공해야 끝난다」)은 `Battle::Start(Add(BATTLE_ENEMY_FIRST, BATTLE_RENEW))`.
  - 「도망쳐도 같은 적, 이기면 새 일당, 질 때까지」(2편 메너스의 악마 사냥꾼 · 몰록의 환상)는
    `Add(BATTLE_REPEAT, Add(BATTLE_RENEW, BATTLE_LOSE_OK))` 를 함께 쓴다 — 끝나는 길은 지는 것뿐이다.
  - 새 편성이 덤벼 오기 전의 문장은 `Battle::SetRenewText("@B악마 사냥꾼@@ : 그러나 나는 그렇게 쉽게 죽지는 않는다.")`.
    없으면 아무것도 내지 않는다. 머리말(「적이 출현했다」)이 있는 전투는 판마다 머리말이 다시 나온다.
- `Battle::EnemyDown(3)` — 마지막 전투에서 등록 3번째 적이 쓰러졌는가(의식불명·죽음) — **도망쳤어도** 본다.
  「메이저 미라만 쓰러뜨려도 성공」은 `Or(Equal(Battle::Result(), BATTLERESULT_WIN), Equal(Battle::EnemyDown(3), 1))`.
  `Battle::Downed()` 는 쓰러뜨린 등록된 적의 수 (와이번 세 마리 중 몇 마리를 잡았나).
- `Battle::RegisterPartyClones(바탕 적, 빈자리 적)` — 일행 여섯 자리의 분신(이름·레벨·능력치·방어 복사). 빈자리 적이 0 이면 비운다.
- `Battle::Result()`: `BATTLERESULT_WIN` · `BATTLERESULT_EVADE`(도망) · `BATTLERESULT_LOSE`. 보통은 지면 엔진이 게임 오버를 처리하고 스크립트는 거기서 끝난다.
- `Battle::ShowEnemyNames()` · `Battle::HideEnemyNames()` — 싸우지 않고 **등록한 적의 이름만** 지도 칸에 띄운다(1부의 적 목록과 같은
  모양, 체력에 따라 색). 원작이 `displayenemies` 로 인물을 등장시키던 자리 — 반신반인 장면의 로드안 · 에인션트 이블:
  `Battle::Init()` → `Battle::RegisterEnemy(68)` → `Battle::RegisterEnemy(67)` → `Battle::ShowEnemyNames()` → `Talk(...)` →
  `Battle::HideEnemyNames()`. `Battle::Start` 와 맵 이동은 목록을 스스로 지운다.
- `Enemy::ChangeAttribute` 의 속성: `name` `level` `strength` `mentality` `endurance` `resistance`(물리) `magic_resistance` `agility` `accuracy` `magic_accuracy` `ac` `special` `cast_level`.
  제3부의 초자연 능력은 `ability_*` 로 하나씩 붙이거나(1) 뗀다(0) — 그 적이 원래 가진 능력은 그대로 둔다:
  `ability_mind_control` `ability_armour_break` `ability_summon_ally` `ability_mass_poison` `ability_mass_stun`
  `ability_mass_death` `ability_heal_all` `ability_clone`. 「17대 드라콘제왕 = 아키드라코니안 + 분신」은
  `Enemy::ChangeAttribute(1, "ability_clone", 1)`.
- 무작위 조우는 `FLAG_MAP` 에서 표를 정한다: `Encounter::Clear()` → `Encounter::Add(18)` · `Encounter::Add(18, 23)`(18~23번) → `Encounter::Enable(1)`. 우두머리를 잡은 뒤에는 `Encounter::Enable(0)`.

## 11. 연출

`Music::Play("이름")` · `Music::Stop()` · `Sound::Play("이름")` — **지금은 소리가 나지 않고 호출만 받는다.**
원작이 음악을 바꾸던 자리에는 그대로 넣어 둔다 (이름은 기획서 제13장의 곡 이름을 영문 소문자로).
`Screen::FadeOut()` · `Screen::FadeIn()` · `Screen::Flash()` · `Wait(밀리초)`.

`Game::Over()` 는 일행 전멸 처리, `Game::Ending("A")` 는 엔딩 글을 다 낸 뒤 제목 화면으로 돌아간다.

## 12. `episode.cm2` — 편 전체의 일

`assets/epN/episode.cm2` 는 맵과 무관하게 불린다.

```
include("common/const.cm2")

if (Equal(ScriptMode(), FLAG_START))        # 캐릭터를 만든 직후
	Time::Set(673, 11, 27, 16, 0)
	LoadScript("E3_Menace", 27, 29)

if (Equal(ScriptMode(), FLAG_PROPHECY))     # 예언 — 진행에 맞는 한 문장
	...

if (Equal(ScriptMode(), FLAG_TIMER))        # 예약한 사건
	if (Equal(Timer::Id(), 1))
		...
```

## 13. 옮길 때 지킬 것

- 좌표·조건·대사는 **기획서와 공략집이 근거**다. 기억이나 추측으로 채우지 않는다. 근거를 못 찾은 칸은 비워 두고 파일 끝에 `# TODO(근거 없음): ...` 으로 적는다.
- 본문의 **의도된 사양**을 옮긴다. `※ 원작 차이`(버그)는 옮기지 않는다.
- 표에 없는 동사가 필요하면 지어 쓰지 말고 파일 끝에 `# NEED: ...` 로 적는다.
- 다 쓰면 검사기를 돌려 오류 0 을 확인한다.
