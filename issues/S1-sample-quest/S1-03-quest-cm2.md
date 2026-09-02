# [S1-03] `Map016.cm2` 와 `flag4quest1.cm2` 를 쓴다

- **상태**: TODO · **구간**: S1 · **규모**: M · **선행**: [S1-02](S1-02-new-map.md)
- **설계 근거**: [MILESTONES §0](../MILESTONES.md) · [DECISION-LOG 2차 판정](../DECISION-LOG.md) ·
  [`GROUND_TRUTH`](../../blueprint/_meta/GROUND_TRUTH.md) §9 (등록 커맨드 40 / 함수 12) · 부록 F-0 · 부록 F-1 ·
  문체 [`blueprint/43_content_style_guide.md`](../../blueprint/43_content_style_guide.md) §2·§3·§6.3

## 문제

퀘스트 로직을 담을 파일이 없다. 형식은 이미 정해져 있다 —
`hadar2026_app/assets/flag4ep1.cm2`(플래그 정의 110줄) + `hadar2026_app/assets/L1_ep1d0.cm2:26-46`(퀘스트 로직) +
`hadar2026_app/assets/Map002.cm2`(per-map cm2 의 작동 예, `Event::Override()` 데모 포함).
[S1-01](S1-01-quest-design.md) 이 확정한 설계를 **이 형식으로 옮겨 적기만** 하면 된다.

## 왜 지금 해야 하는가

[S1-04](S1-04-playthrough.md) 의 플레이 완주가 이 두 파일에 전적으로 의존한다.
그리고 이 두 파일이 [S3](../MILESTONES.md) 생성 프롬프트의 **few-shot 정답지**가 된다.

## 무엇을 할 것인가

### 1. `hadar2026_app/assets/flag4quest1.cm2` (신규)

`flag4ep1.cm2` 의 형식을 **그대로** 따른다 — `variable(NAME)` 한 줄, `NAME.assign(정수)` 한 줄, 주석은 `#`.

```cm2
####### 퀘스트 1 「석문의 봉화」 플래그 ########
#
# 대역: 60~69 (퀘스트 1 전용 · 63~69 예약)
# 사용 중인 인덱스와의 충돌 없음 — 근거는 S1-01 §3 의 전수 조사표
#   flag4ep1.cm2 이름 상수 : 0~6, 10~14, 20~31, 40~47, 50
#   lore_ep1/town2.cm2 생 숫자 : 31, 32, 50~55
#   menace.cm2 생 숫자 : 10

# 의뢰 수락 — 파수 대장 두람에게서 봉화 기름 심부름을 받음
variable(QF1_ACCEPTED)
QF1_ACCEPTED.assign(60)

# 물건 획득 — 창고지기 가른에게서 봉화 기름을 받음
variable(QF1_GOT_OIL)
QF1_GOT_OIL.assign(61)

# 전달·보상 완료 — 봉화대 문이 열림
variable(QF1_DONE)
QF1_DONE.assign(62)
```

> **`include` 되는 파일에는 선언만 둔다.** `packages/cm2_script/lib/src/cm2_script.dart:209-221`
> (`_executeInclude`)은 포함된 파일의 **모든 문장을 실행**한다 — `Talk` 이나 `if` 를 넣으면 맵을 열 때마다 실행된다.
> `const.cm2` 와 `flag4ep1.cm2` 가 선언만 갖고 있는 이유가 이것이다.

### 2. `hadar2026_app/assets/Map016.cm2` (신규) — 골격 코드

`MapInfos.json` 에 `cm2` 필드가 없어도 `map_navigation.dart:44-45` 가 id 16 → `Map016.cm2` 를 **자동 부여**한다.
들여쓰기는 **탭**이다(`Map002.cm2`·`L1_ep1d0.cm2` 와 동일).

```cm2
include("const.cm2")
include("flag4quest1.cm2")

variable(temp)

############ 대화 ############

if (Equal(ScriptMode(), FLAG_TALK))
	# 파수 대장 두람 — 의뢰인. 상태에 따라 4가지 대사
	if (On(10,8))
		Event::Override()
		SetHeader("파수 대장 두람")
		if (Flag::IsSet(QF1_DONE))
			Talk("봉화는 어젯밤부터 잘 오르고 있습니다.")
			Talk("석문은 당신에게 빚을 하나 졌습니다.")
		else
			if (Flag::IsSet(QF1_GOT_OIL))
				Talk("그 기름을 받아 두겠습니다.")
				Talk("@7일행은 @B봉화 기름@@@7을 두람에게 건넸다.@@")
				Talk("")
				Talk("@B[GOLD +80]@@")
				Party::PlusGold(80)
				Map::ChangeTile(10,6,8)
				Flag::Set(QF1_DONE)
				Talk("봉화대 문을 열어 두었습니다.")
				PressAnyKey()
			else
				if (Flag::IsSet(QF1_ACCEPTED))
					Talk("창고지기 가른에게 가 보십시오.")
					Talk("기름 없이는 봉화를 올릴 수 없습니다.")
				else
					Talk("석문 초소의 파수 대장입니다.")
					Talk("봉화대에 올릴 기름이 떨어졌습니다.")
					Talk("창고에 남은 것이 있는데, 창고지기가 내주지 않습니다.")
					PressAnyKey()
					Select::Init()
					Select::Add("기름을 받아다 주시겠습니까?")
					Select::Add("그렇게 하겠소")
					Select::Add("지금은 어렵소")
					Select::Run()
					temp.assign(Select::Result())
					if (Equal(temp, 1))
						Talk("고맙습니다. 창고는 서쪽입니다.")
						Flag::Set(QF1_ACCEPTED)
					else
						Talk("마음이 바뀌면 다시 오십시오.")

	# 창고지기 가른 — 물건 지급. 하게체
	if (On(5,14))
		Event::Override()
		SetHeader("창고지기 가른")
		if (Flag::IsSet(QF1_GOT_OIL))
			Talk("남은 기름은 그것이 마지막이었네.")
		else
			if (Flag::IsSet(QF1_ACCEPTED))
				Talk("대장이 보냈다고 하는군.")
				Talk("그러면 내주어야지.")
				Talk("")
				Talk("@7일행은 @B봉화 기름@@@7을 받았다.@@")
				Flag::Set(QF1_GOT_OIL)
				PressAnyKey()
			else
				Talk("창고는 공무가 아니면 열지 않네.")
				Talk("대장의 말을 받아 오게나.")

	# 우물가의 아이 — 힌트. 완료 후 대사가 바뀐다
	if (On(15,14))
		Event::Override()
		SetHeader("우물가의 아이")
		if (Flag::IsSet(QF1_DONE))
			Talk("어젯밤에 봉화가 올랐습니다.")
			Talk("아버지가 그걸 보고 돌아왔습니다.")
		else
			Talk("가른 할아버지는 고집이 셉니다.")
			Talk("대장님 말이 아니면 창고를 안 엽니다.")

############ 푯말 ############

if (Equal(ScriptMode(), FLAG_SIGN))
	# 봉화대 안의 푯말 — 문이 열린 뒤에만 닿을 수 있다
	if (On(10,3))
		Event::Override()
		TextAlign(ALIGN_CENTER)
		Talk("석문 봉화대")
		Talk("")
		Talk("불은 라스트디치까지 이어진다")
		TextAlign(ALIGN_LEFT)
		PressAnyKey()

############ 출입구 ############

if (Equal(ScriptMode(), FLAG_ENTER))
	# 남문 — LORE_EP 의 (35,27) 로 되돌아간다
	if (On(10,20))
		Event::Override()
		Select::Init()
		Select::Add("초소를 나가시겠습니까?")
		Select::Add("예")
		Select::Add("아니오")
		Select::Run()
		temp.assign(Select::Result())
		if (Equal(temp, 1))
			LoadScript("LORE_EP", 35, 27)

############ 맵 진입 ############

if (Equal(ScriptMode(), FLAG_MAP))
	Map::SetStartPos(10,19)
	# 맵을 다시 들어오면 JSON 원본이 다시 로드되므로 문 개방을 재적용한다
	if (Flag::IsSet(QF1_DONE))
		Map::ChangeTile(10,6,8)
```

### 3. 반드시 지킬 규약 (근거 포함)

| # | 규약 | 근거 |
|---|---|---|
| 1 | **`Event::Override()` 는 매칭된 타일 블록의 최상단**에 둔다 — "이 블록이 JSON 을 대체한다" 는 선언으로 읽히게 | [CLAUDE.md](../../CLAUDE.md) 규약 · `Map002.cm2:21,40,54` |
| 2 | **`else if` 를 쓰지 말 것.** cm2 에 없다. 평면 `if` 를 나열하면 앞 블록이 세운 플래그를 뒤 블록이 **같은 실행에서 다시 읽어** 두 대사가 한 번에 나온다. `if/else` 중첩으로 쓴다 | `cm2_script.dart:114-131` (`executeStatement` 의 `IfStatement` 처리) |
| 3 | **`Map::ChangeTile` 은 ground(`ixTile`)만 바꾼다.** 문은 반드시 ground BLOCK 타일이어야 한다 | `script_engine_adapter.dart:350-355` → `map_model.dart:37-42` |
| 4 | **`FLAG_MAP` 블록에서 타일 변화를 재적용**한다. 맵 재진입 시 JSON 원본이 다시 로드된다 | `lore_ep1.cm2:511-528` 이 정확히 이 패턴 |
| 5 | 등록 심볼 **밖의 것을 쓰지 않는다** — 커맨드 40종 / 함수 12종. 목록은 `GROUND_TRUTH` §9, 개수는 부록 F-0 에서 재확인됨 | — |
| 6 | 대사는 45자 이하, 선택지 18자 이하, `...` 은 마침표 3개, `?` 앞 공백 없음 | `43_content_style_guide.md` R-43-4·R-43-18·R-43-19 |

### 4. cm2 함정 — 이 이슈를 하는 동안 반드시 의심할 것

> **① 미등록 함수는 `0` 을 반환한다.** `Flag::IsSet` 을 `Flag::isSet` 으로 잘못 쓰면 "Unknown function" 을
> **콘솔에만** 찍고 `0` 을 돌려준다 → 조건이 조용히 거짓이 되어 **NPC 가 초기 대사만 반복한다.**
> 미등록 커맨드는 "Unknown command" 를 찍고 **건너뛴다** → `Flag::Set` 오타는 진행이 저장되지 않는 형태로 나타난다
> (`GROUND_TRUTH` §9 침묵 실패 모드).
>
> **② 범위 밖 인자는 침묵 no-op 이다.** `Flag::Set` / `Flag::Reset` / `Variable::Set` / `Variable::Add` 는
> 범위 검사에 `else` 가 없다(부록 F-1, `script_engine_adapter.dart:362-391`). `Flag::Set(600)` 은
> **아무 일도 하지 않고 아무 로그도 남기지 않는다.** 플래그 상한은 256(`hd_config.dart:45`).
>
> **③ `.assign` 은 `run()` 마다 재실행된다.** `cm2_script.dart:92-103` 은 `variable`/`include` 만 건너뛰고
> **모든 `.assign` 을 매 실행마다 다시 실행**한다. 그래서 초기값 대입을 **메인 스크립트 상단에 두면 매 대화마다
> 초기화된다.** 위 골격이 플래그 상수 대입을 전부 `flag4quest1.cm2`(=`include` 대상)에 둔 이유가 이것이다.
> 반대로 `variable(temp)` 처럼 **런타임 임시값**은 메인에 두어도 안전하다(대입이 없으므로).
>
> **④ 맵 전환은 엔진 전역을 날린다.** `game_session.dart:101-107` 이 맵마다 `loadScript` 를 부르고
> 그것이 `clearRuntimeState()` 로 `variables`/컨텍스트를 비운다. 맵을 넘어 살아남는 것은
> **`Flag::Set` 으로 쓴 `HDGameOption.flags` 256칸뿐**이다(`GROUND_TRUTH` §8 — 저장됨).
>
> **⑤ cm2 로드 실패는 이전 스크립트를 남긴다**(부록 A-2 → [P0-03](../P0-foundation/P0-03-cm2-load-state-leak.md)).
> `Map016.cm2` 파일명 오타나 파싱 실패 시 **직전 맵의 스크립트가 계속 돌아** 원인 추적이 어렵다.
> 콘솔에 `ScriptEngine: Loading script content from assets/Map016.cm2` 가 찍히는지 **먼저** 확인할 것.

### 5. 에셋 등록

`pubspec.yaml:65-69` 의 `assets:` 는 `assets/` 를 열거하므로 **`assets/Map016.cm2`·`assets/flag4quest1.cm2` 는
추가 선언 없이 번들에 실린다**(하위 디렉토리만 비재귀 — 부록 A-4). `pubspec.yaml` 을 고칠 필요가 없다.

## 완료 판정 기준

- [ ] `assets/flag4quest1.cm2` 와 `assets/Map016.cm2` 두 파일이 존재하고, 둘 다 `#` 주석 외에는
      `GROUND_TRUTH` §9 의 커맨드 40종 / 함수 12종 안의 심볼만 쓴다 (수동 대조)
- [ ] `Map016.cm2` 의 `On(x,y)` 좌표 5개가 [S1-02 §4](S1-02-new-map.md) 의 배치 표와 **전부 일치**한다
- [ ] 앱 실행 시 콘솔에 `Unknown command` / `Unknown function` / `Warning: Assigning to unregistered variable`
      이 **한 줄도** 찍히지 않는다
- [ ] `flag4quest1.cm2` 에 `variable` / `.assign` / `#` 주석 외의 문장이 없다
- [ ] `Map002.cm2` 의 변경이 §[S1-02 §5](S1-02-new-map.md) 의 `On(36,27)` 블록 **추가 한 곳**뿐이다

## 하지 않을 것

- 코드 변경. cm2 린터 제작(→ [S2-03](../S2-enablers/S2-03-cm2-linter.md)), 플래그 레지스트리(→ [S2-01](../S2-enablers/S2-01-flag-registry.md)).
- `flag4ep1.cm2:42-43` 의 기존 충돌 수리 — [S1-99](S1-99-friction-log.md) 에 기록만 한다.
- 전투(`Battle::*`) 분기 — 부록 B-2·F-3 이 살아 있는 동안 샘플에 넣지 않는다.
- `Variable::Set/Get` 사용, 네이티브 Dart 맵 스크립트, `hadarEvent` 확장.
