# S3-02 생성 프롬프트 — 개요 → cm2 + 맵 편집 지시 + 플래그

- **상태**: BLOCKED (S3-01 · S2 대기)
- **구간**: S3
- **규모**: M
- **선행**: [S3-01](S3-01-quest-spec-format.md) · [S2-01](../S2-enablers/S2-01-flag-registry.md) · [S2-02](../S2-enablers/S2-02-cm2-override-chain.md) · [S2-03](../S2-enablers/S2-03-cm2-linter.md)
- **설계 근거**: [MILESTONES §4](../MILESTONES.md) · [`GROUND_TRUTH` §9 · 부록 B-1 · B-2 · F-1](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-43 §7.5](../../blueprint/43_content_style_guide.md)

## 착수 조건

- [S3-01](S3-01-quest-spec-format.md) 이 `DONE` — 입력 서식이 없으면 프롬프트를 쓸 수 없다.
- [S2-01](../S2-enablers/S2-01-flag-registry.md) 이 `DONE` 또는 `DROPPED` 판정 — **플래그 인덱스를 누가 주는지**가 확정되어야 한다.
  `DROPPED` 면 사람이 준 값을 프롬프트에 직접 박는다.
- [S2-03](../S2-enablers/S2-03-cm2-linter.md) 이 `DONE` — §자기수정 루프가 린터 출력에 의존한다.
- [S2-02](../S2-enablers/S2-02-cm2-override-chain.md) 판정 — 출력 파일 이름 규약이 갈린다(맵 cm2 에 섞는가, 별 파일인가).

## 문제

AI 가 cm2 를 쓸 때 **틀리는 방식이 세 가지**이고 셋 다 조용하다.

| 틀리는 방식 | 결과 | 근거 |
|---|---|---|
| 그럴듯한 미등록 심볼을 만든다 | 커맨드는 스킵, **함수는 0 반환 → 오분기** | `cm2_script.dart:204` · `:335-336` |
| 플래그 인덱스를 스스로 고른다 | 기존 상태를 조용히 망친다 | 부록 F-1 · [S2-01](../S2-enablers/S2-01-flag-registry.md) |
| 현대어·외래어로 쓴다 | 사람이 전부 다시 쓴다 → AI 가 도움이 안 된다 | [BP-43 §3](../../blueprint/43_content_style_guide.md) |

사람이 쓴 콘텐츠에서도 미등록 심볼이 **6종·9곳** 나왔다([S2-03](../S2-enablers/S2-03-cm2-linter.md) §문제).
AI 는 더 많이 만든다. **프롬프트가 심볼 목록을 전량 제시하는 것이 유일한 방어**다.

## 실물 프롬프트

`content/prompts/quest_gen.ko.md` 로 커밋한다. 변수는 `{{...}}`.

````
당신은 1990년대 한국 PC RPG "또 다른 지식의 성전(Hadar)" 의 시나리오 작가 겸 스크립터다.
아래 퀘스트 개요를 읽고, **이 게임이 실제로 실행할 수 있는 파일들**을 만든다.
새 시스템을 발명하지 말고, 이미 있는 것만으로 표현한다.

# 1. 퀘스트 개요 (입력)

{{quest_spec_yaml}}

# 2. 배정된 플래그 인덱스 (이 값만 쓴다)

{{flag_assignment}}
예: Q1_ACCEPTED=60, Q1_FOUND_BLOCK=61, Q1_CLEARED=62, Q1_DONE=63

**이 표에 없는 인덱스를 쓰면 실패다.** 새 플래그가 필요하다고 판단되면 만들지 말고,
출력 맨 끝의 `## 요청` 절에 "플래그 N개 추가 필요 — 용도" 를 적고 멈춘다.

# 3. 배치할 맵 정보

{{map_summary}}
NPC 를 놓을 수 있는 칸과 그 좌표는 이미 정해져 있다. 좌표를 새로 만들지 말고 이 목록에서 고른다.

# 4. 쓸 수 있는 커맨드 — 이 40개 전부이며, 이 밖은 존재하지 않는다

{{command_list}}
Talk, Log, SetHeader, Answer, PressAnyKey, Map::Init, Map::SetTile, Map::SetRow,
Select::Init, Select::Add, Select::Run, LoadScript, Map::LoadFromFile,
Battle::Init, Battle::RegisterEnemy, Battle::ShowEnemy, Battle::Start,
Map::SetStartPos, Map::ChangeTile, WarpPrevPos, Flag::Set, Flag::Reset,
Variable::Set, Variable::Add, Player::ChangeAttribute, Enemy::ChangeAttribute,
Player::AssignFromEnemyData, Party::PosX, Party::PosY, Party::PlusGold, Party::Move,
Map::SetType, Map::SetEncounter, DisplayMap, DisplayStatus, Wait, TextAlign,
Tile::CopyTile, Tile::CopyToDefaultTile, Tile::CopyToDefaultSprite
엔진 내장 커맨드 7개도 쓸 수 있다: variable, include, halt, Event::Override, Context::SetCurrent/Set/Delete

# 5. 쓸 수 있는 함수 — 이 12개 + 내장 11개 전부이며, 이 밖은 존재하지 않는다

{{function_list}}
Flag::IsSet, Variable::Get, On, OnArea, Battle::Result, Select::Result,
Party::PosX, Party::PosY, Player::GetName, Player::GetGenderName,
Player::GetAttribute, Player::IsAvailable
내장: Not, Or, And, Equal, Less, Add, Random, ScriptMode, JoinString, Context::Get, Context::GetCurrent

**주의**: `Party::CheckIf` 는 const.cm2 에 상수가 있지만 **함수가 등록되어 있지 않다.** 쓰지 마라.
미등록 함수는 오류를 내지 않고 0을 반환해 조건문을 조용히 반대로 태운다.

# 6. cm2 언어 규칙

- 들여쓰기로 블록을 만든다. 탭 1개 = 8칸. **탭과 스페이스를 섞지 마라.**
- `if (조건함수(인자))` 와 `else` 만 있다. **while·for·함수 정의·산술은 없다.** 덧셈은 `Add(a,b)` 뿐이다.
- 주석은 `#`.
- 변수는 `variable(이름)` 으로 선언하고 `이름.assign(값)` 으로 대입한다. 선언하지 않은 이름을 쓰면 안 된다.
- `variable(X)` 와 `X.assign(n)` 의 **이름이 반드시 같아야 한다.** 실제 원작 파일에 이 오타가 있고,
  그 결과 다른 던전의 플래그를 켜는 버그가 지금도 남아 있다.
- 파일 맨 위에 `include("const.cm2")` 를 둔다. `FLAG_TALK`/`FLAG_SIGN`/`FLAG_EVENT`/`FLAG_ENTER`/`FLAG_MAP`
  상수가 거기 있다.
- **최상위 `.assign(...)` 은 상호작용마다 재실행된다.** 초기값을 최상위에 두면 매번 지워진다.
  퀘스트 상태는 반드시 `Flag::Set` 으로만 기록한다.
- 타일 상호작용은 `if (Equal(ScriptMode(), FLAG_TALK))` 로 감싸고, 그 안에서 `if (On(x,y))` 로 칸을 고른다.
- 처리한 블록의 **맨 앞에 `Event::Override()`** 를 둔다. 없으면 맵 JSON 의 정적 대사가 중복 출력된다.

# 7. 문체 규칙 (반드시 지킬 것)

{{style_guide}}
- 화계: 기사·귀족은 하오체(~오/~소), 병사·상인·촌민은 합쇼체(~습니다/~십시오),
  나이든 남자가 젊은이에게는 하게체(~네/~게나). 한 인물 안에서 섞지 말 것.
- 청자는 "당신"/"당신들", 파티는 "일행". "그대"/"너"/"여러분" 금지.
- 지문은 @7…@@ 로 감싸고 평서 과거 완료(~하였다/~였다)로 끝낸다. 감정을 대신 서술하지 않는다.
- 한 줄 28자 이내를 권하고 45자를 넘기지 말 것. 두 문장이면 줄을 나눌 것.
- 공백 없이 30자가 이어지면 화면 밖으로 잘린다. 긴 한자어 복합어를 붙여 쓰지 말 것.
- 선택지는 18자 이내.
- 말줄임은 마침표 세 개(...). … 문자 금지. ?/! 앞에 공백 금지.
- 대사 안의 수는 한글 수사(사흘, 다섯). 수량 표시는 아라비아 숫자.
- 강조는 @B…@@ 하나만, 한 줄에 2구간 이하.
- 금지: 이모지, ㅋㅋ/ㅠㅠ, 현대 기술·시사·브랜드, 게임/저장/플레이어 같은 메타어,
  퀘스트·아이템·인벤토리·리워드·레벨업·포션 같은 외래어, HP/MP 약어.
- 없는 신·조직·인물을 만들지 말 것. 개요의 `cast[].knows` 에 없는 비트를 그 인물이 알게 하지 말 것.
- 악역은 위협하되 욕하지 않는다.

# 8. 세계관 발췌 (이 안에서만 쓴다)

{{world_excerpt}}
고유명사 정본 표기: LORE(성·대륙) / MENACE(던전) / LASTDITCH / Lord Ahn / Necromancer.
맵 표시명은 한글(로어성·로어 대륙·메너스·라스트디치). 새 고유명사는 개요에 있는 것만 쓴다.

# 9. 정답지 — 이 형태를 따른다

## 9.1 플래그 정의 파일 (`flag4ep1.cm2` 발췌)
{{example_flag_file}}

## 9.2 퀘스트 로직 (`L1_ep1d0.cm2` 발췌 — 여관 방 빌리기, 조건부 분기 + 선택지 + 월드 변화)
{{example_quest_script}}

## 9.3 짧은 맵 스크립트 (`Map002.cm2` 전문 — Event::Override 와 ScriptMode 분기의 최소 예)
{{example_map_script}}

## 9.4 손으로 만든 샘플 퀘스트 (S1 산출물 — **가장 가까운 정답지**)
{{example_s1_quest}}

# 10. 출력 형식

아래 5개 절을 **이 순서로, 이 제목 그대로** 낸다. 다른 설명·머리말·맺음말을 붙이지 않는다.

## flag4{{quest_id}}.cm2
```cm2
(§2 의 배정 인덱스만 사용. flag4ep1.cm2 형식: variable(NAME) 다음 줄에 NAME.assign(N))
```

## {{quest_script_name}}
```cm2
(퀘스트 로직. include("const.cm2") 로 시작. 필요하면 include("flag4{{quest_id}}.cm2"))
```

## 맵 편집 지시
```json
{"ops":[ ... ]}
```
맵 에디터 API 의 `POST /api/ai/maps/{file}/edit` 에 그대로 넣을 배열이다.
NPC 는 objUpper 에 B 타일 **128~143**(TALK) 을 놓는다. 좌표는 §3 목록에서 고른 것과 일치해야 한다.

## MapInfos 항목
```json
{"name":"...","json":"...","cm2":[...]}
```

## 요청
(플래그 추가 요청 등 사람이 처리해야 할 것. 없으면 "없음")

# 11. 금칙 — 하나라도 위반하면 출력을 폐기한다

1. §4·§5 에 없는 커맨드·함수를 쓰는 것
2. §2 에 없는 플래그 인덱스를 쓰는 것
3. `Flag::Set(60)` 처럼 **생 숫자**로 플래그를 지정하는 것 — 반드시 §2 의 이름을 쓴다
4. `Battle::RegisterEnemy` 의 인자가 1~74 밖인 것 (0 은 코드 가드 때문에 영구히 소환 불가)
5. `Flag::*`/`Variable::*` 인덱스가 0~255 밖인 것
6. `Battle::Result()` 로 분기하는 것 — 결과 코드가 상수와 반대로 매핑되어 있다. 전투 분기는 사람이 쓴다
7. 현대어·외래어·이모지·메타 언급 (§7)
8. 기존 파일을 수정하는 지시를 내는 것 — **새 파일만** 만든다
9. `Map::SetStartPos` 를 퀘스트 스크립트에 쓰는 것 — 맵 상주 로직이라 맵 cm2 소관이다
10. 개요에 없는 인물·장소·물건을 등장시키는 것
````

## 자기수정 루프

1. 출력을 파일로 저장 → `cm2_lint --json` 실행.
2. 위반이 있으면 **린터 출력을 그대로** 다음 프롬프트에 붙인다:

````
앞서 만든 파일에 아래 오류가 있다. **틀린 부분만** 고쳐 §10 형식으로 전체를 다시 낸다.
설명하지 말고 파일만 낸다.

{{linter_output}}

예: quest_Q1.cm2:14: [L2] Unknown function: Party::CheckIf
    quest_Q1.cm2:22: [L9] On(14,30) 은 TALK 타일이 아니다 (Map016.json: MOVE)
````

3. 최대 **3회** 재시도. 3회 후에도 error 가 남으면 **사람에게 넘긴다**(자동 폐기하지 않는다 — 부분적으로 쓸 만할 수 있다).
4. warn 만 남은 것은 통과로 본다.

재시도 횟수와 각 회차의 위반 목록은 [S3-05](S3-05-pilot-batch.md) 의 측정값이므로 반드시 기록한다.

## 완료 판정 기준

- [ ] `content/prompts/quest_gen.ko.md` 가 존재하고 `{{...}}` 변수 13개(재시도 프롬프트의 `{{linter_output}}` 포함)가 전부 채워지는 스크립트가 있다
- [ ] `{{command_list}}`/`{{function_list}}` 가 **코드에서 자동 추출**된다([S2-03](../S2-enablers/S2-03-cm2-linter.md) 이 노출하는 상수 집합) — 프롬프트에 손으로 적은 목록이 정본이 아니다
- [ ] [S3-01](S3-01-quest-spec-format.md) 의 `content/quests/S1.yaml` 을 넣으면 §10 의 5개 절이 그 제목 그대로 나온다
- [ ] 그 출력이 `cm2_lint` 에서 **error 0** 이다 (재시도 3회 이내)
- [ ] 출력의 플래그 인덱스가 `{{flag_assignment}}` 로 준 값과 **완전히 일치**한다(생 숫자 0건, 범위 밖 0건)
- [ ] 출력에 기존 파일을 수정하는 지시가 **0건**이다
- [ ] 금칙 10개 각각에 대해 **위반을 유발하는 개요**를 넣어 본 기록이 있다(프롬프트가 실제로 막는지 확인)

## 하지 않을 것

- 프롬프트 계약 프레임워크·다단계 하네스 — [deferred/P2-07](../deferred/P2-07-generation-pipeline.md) · [P2-08](../deferred/P2-08-prompt-contracts.md).
  **단일 프롬프트 + 린터 되먹임 3회**가 이 구간의 전부다.
- Critic·StyleEditor 같은 역할 분리 에이전트. 문체는 프롬프트 §7 과 사람 검수([S3-05](S3-05-pilot-batch.md))가 맡는다.
- 문체 자동 검사([BP-43 §7.2](../../blueprint/43_content_style_guide.md) 의 12건). 린터는 심볼만 본다.
- 전투를 AI 에게 맡기는 것. 금칙 6번이 그것이다(부록 B-2).
- 런타임에 AI 를 두는 것. [D-01](../../blueprint/_meta/DECISIONS.md) 이 금지했다.
- 맵 지형 생성. [S3-03](S3-03-map-generation.md) 소관이며, 이 프롬프트는 **이미 만들어진 맵의 좌표 목록**을 입력으로 받는다.
