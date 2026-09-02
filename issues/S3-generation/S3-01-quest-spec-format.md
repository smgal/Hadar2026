# S3-01 퀘스트 개요 서식 (AI 입력 형식)

- **상태**: BLOCKED (S1-04 대기)
- **구간**: S3
- **규모**: S
- **선행**: [S1-04](../S1-sample-quest/S1-04-playthrough.md)
- **설계 근거**: [MILESTONES §4](../MILESTONES.md) · [DECISION-LOG 2차 판정](../DECISION-LOG.md) · [BP-43 문체](../../blueprint/43_content_style_guide.md)

## 착수 조건

[S1-04](../S1-sample-quest/S1-04-playthrough.md) 가 `DONE` 이어야 한다.
**서식은 완성된 실례를 담을 수 있어야 검증된다.** 설계만 있고 플레이로 확인되지 않은 것을 서식화하면
서식이 담지 못하는 항목을 발견하지 못한 채 [S3-02](S3-02-generation-prompt.md) 로 넘어간다.

## 문제

[S3-02](S3-02-generation-prompt.md) 의 프롬프트는 **입력이 무엇인지** 정해져야 쓸 수 있다.
지금 사람이 퀘스트를 구상하면 그 결과는 머릿속이나 자유 서술이다. 자유 서술을 프롬프트에 넣으면
- 어떤 항목이 빠졌는지 알 수 없고(예: 완료 후 대사를 안 적으면 AI 가 만들어 낸다)
- 같은 개요를 두 번 넣었을 때 같은 종류의 산출물이 나오지 않는다.

## 서식 — `content/quests/<id>.yaml`

YAML 을 택한다. 이유: 사람이 손으로 쓰고 diff 로 리뷰하며, `#` 주석으로 톤 메모를 남길 수 있다.
마크다운은 항목 누락을 기계가 잡지 못한다.

```yaml
id: Q1                        # 필수. 플래그 이름 접두사·파일명에 쓰인다
title: 잃어버린 물통           # 필수. 저널·로그에 안 쓰인다(사람용 이름)
map:
  name: SPRINGWELL            # 필수. MapInfos.json 에 등록할 논리 이름
  new: true                   # true 면 S3-03 이 맵을 새로 만든다
  displayName: 샘마을          # 화면 표시명. 한글(부록 O-9)
  size: [40, 30]              # new: true 일 때만
  type: TOWN                  # TOWN / KEEP / GROUND / DEN
client:                       # 필수. 의뢰인
  name: 우물지기 노인
  role: commoner              # BP-43 §5 의 화자 유형 → 화계가 결정된다
  where: 우물 옆              # 배치 의도. 좌표는 AI 가 정한다
beats:                        # 필수. 정확히 3단계
  - id: accept
    what: 우물이 마르는 이유를 알아봐 달라 청한다
    trigger: 노인에게 말을 건다
  - id: acquire
    what: 마을 뒤 물길이 돌에 막힌 것을 발견하고 치운다
    trigger: 막힌 물길 칸을 조사한다
  - id: deliver
    what: 노인에게 돌아가 알린다
    trigger: 노인에게 다시 말을 건다
cast:                         # 의뢰인 외 등장인물. 0~3명
  - name: 물 나르는 아이
    role: commoner
    where: 마을 입구
    knows: [accept]           # 이 비트 이후에만 관련된 말을 한다
  - name: 마을 위병
    role: soldier
    where: 마을 입구 반대편
    knows: []                 # 퀘스트를 모른다 — 분위기 담당
reward:
  gold: 80                    # Party::PlusGold
  world: 우물에서 다시 물이 나온다   # Map::ChangeTile 로 표현될 변화
  none_else: true             # 아이템 보상 없음을 명시(인벤토리가 없으므로)
requires:
  flags: []                   # 전제 플래그. 이름으로만 쓴다(인덱스 금지)
flags:
  count: 4                    # 필요한 플래그 개수만 적는다. 인덱스는 S2-01 이 준다
  names: [Q1_ACCEPTED, Q1_FOUND_BLOCK, Q1_CLEARED, Q1_DONE]
tone:                         # 톤 메모. 자유 서술 허용
  register: 노인은 하게체(~네/~게나). 아이는 합쇼체
  mood: 마르는 우물에 대한 체념. 위협이나 음모는 없다
  avoid: 물의 정령 같은 초자연 요소를 끌어오지 말 것
completed_line: 우물 소리가 다시 들리네. 고맙네.   # 필수. 완료 후 대사 1줄
```

### 필드 규칙

| 필드 | 필수 | 왜 이 형태인가 |
|---|---|---|
| `beats` | **정확히 3** | 원작 퀘스트 구조(`flag4ep1.cm2` 의 d0: 수락→열쇠→검문)와 같다. 3보다 많으면 서식을 늘리기 전에 퀘스트를 쪼갠다 |
| `client.role` / `cast[].role` | 필수 | [BP-43 §5](../../blueprint/43_content_style_guide.md) 의 7유형(`soldier`/`merchant`/`innkeeper`/`scholar`/`commoner`/`noble`/`boss`) 중 하나. **화계가 여기서 결정**되므로 자유 문자열이면 안 된다 |
| `flags.count` + `names` | 필수 | **인덱스를 사람도 AI 도 쓰지 않는다.** [S2-01](../S2-enablers/S2-01-flag-registry.md) 의 `flag_alloc alloc --quest Q1 --count 4` 가 값을 준다 |
| `reward.none_else` | 필수 | 인벤토리가 `food`/`gold` 정수 2개뿐이다(부록 §10). 아이템 보상을 **쓸 수 없다는 사실을 서식이 강제**한다 |
| `completed_line` | 필수 | S1 완료 판정의 "완료 상태의 대사" 를 서식이 요구한다. 없으면 AI 가 만들어 낸다 |
| `cast[].knows` | 필수 | 비트 id 목록. **액터가 모르는 것을 말하지 않게** 하는 유일한 기계적 장치([BP-43 F-15](../../blueprint/43_content_style_guide.md)) |

## S1-01 설계를 이 서식으로 다시 쓴 예시

[S1-01](../S1-sample-quest/S1-01-quest-design.md) 의 설계(새 맵 `Map016` + NPC 3명 + 수락·획득·전달 3단계 +
플래그 기록 + 완료 대사)를 위 서식으로 옮긴 것이 **`content/quests/S1.yaml`** 이며,
그것을 이 이슈의 산출물로 함께 커밋한다.

```yaml
id: S1
title: 샘플 — 의뢰와 보상
map: { name: <S1-01 이 정한 이름>, new: true, displayName: <표시명>, size: [<w>, <h>], type: TOWN }
client: { name: <의뢰인>, role: <7유형 중 하나>, where: <배치 의도> }
beats:
  - { id: accept,  what: <의뢰 내용>,        trigger: <의뢰인에게 말을 건다> }
  - { id: acquire, what: <물건을 구하는 방법>, trigger: <어떤 칸/누구> }
  - { id: deliver, what: <전달>,             trigger: <의뢰인에게 다시 말을 건다> }
cast:
  - { name: <NPC2>, role: <유형>, where: <위치>, knows: [accept] }
  - { name: <NPC3>, role: <유형>, where: <위치>, knows: [] }
reward: { gold: <액수>, world: <월드 변화>, none_else: true }
requires: { flags: [] }
flags: { count: <S1-03 이 실제로 쓴 개수>, names: [<S1-03 의 flag4quest1.cm2 이름 그대로>] }
tone: { register: <화계>, mood: <분위기>, avoid: <피할 것> }
completed_line: <S1-03 의 완료 대사 1줄>
```

**꺾쇠 자리를 S1 산출물의 실제 값으로 채우는 것이 이 이슈의 실작업이다.**
채우다 막히는 자리가 나오면 **서식을 고친다** — 그것이 이 절의 목적이다.
`flags.names` 는 `flag4quest1.cm2` 의 선언 이름을 **그대로** 베낀다. 다르면 서식이 아니라 개요가 틀렸다.

## 서식이 담지 못하는 것 (명시)

| 담지 못하는 것 | 누가 정하는가 |
|---|---|
| **맵 지형 세부** — 어느 칸이 벽이고 어디에 우물이 있는지 | [S3-03](S3-03-map-generation.md) 이 맵 에디터 API 로 만든다. `where` 는 의도만 |
| **좌표** — `On(x,y)` 의 실제 숫자 | S3-03 이 NPC 를 배치한 뒤 결정. 서식에 좌표를 쓰면 맵보다 개요가 앞서게 된다 |
| **전투 밸런스** — 적 조합·난이도 | 서식에 `battle` 필드를 두지 않는다. 전투를 넣으려면 개요에 문장으로 적고 **사람이 `Battle::RegisterEnemy` 를 직접 쓴다** (부록 B-2: 전투 결과 코드가 cm2 상수와 반대라 AI 에게 맡길 수 없다) |
| **플래그 인덱스** | [S2-01](../S2-enablers/S2-01-flag-registry.md) 의 CLI |
| **대사 원문** | [S3-02](S3-02-generation-prompt.md) 의 생성물. 개요는 **내용**만 적고 문장을 쓰지 않는다 |
| **실패 경로·시한** | 서식에 없다. 3단계 선형만 다룬다. 필요해지면 그때 서식을 확장한다 |
| **다중 맵 원정** | `map` 이 단수다. 맵을 넘나드는 퀘스트는 이 서식으로 못 쓴다 |

## 완료 판정 기준

- [ ] `content/quests/S1.yaml` 이 S1 산출물의 실제 값으로 **전부 채워져** 있다(꺾쇠 자리 0개)
- [ ] 그 파일의 `flags.names` 가 `assets/flag4quest1.cm2` 의 선언 이름과 **문자 단위로 일치**한다
- [ ] `beats` 3개가 S1 의 플래그 기록 지점과 1:1 대응한다
- [ ] 필수 필드가 빠지면 실패하는 스키마 검사가 있다(`content/quests/schema.json` + CI)
- [ ] 위 §담지 못하는 것 7항목이 문서에 남아 있고, 각각 담당 이슈가 링크되어 있다
- [ ] 서식을 채우는 과정에서 고친 항목이 있으면 그 변경 이유가 이 이슈 안에 기록되어 있다

## 하지 않을 것

- 선언적 퀘스트 모델(`objectives`/`conditions`/`effects`) — [deferred/P1-08](../deferred/P1-08-quest-runtime.md) 소관.
  이 서식은 **런타임이 읽지 않는다.** AI 프롬프트의 입력이고, 최종 산출물은 cm2 다.
- 월드 바이블·세계관 스키마 — [deferred/P1-15](../deferred/P1-15-world-bible-seed.md). 세계관은 [BP-43](../../blueprint/43_content_style_guide.md) 발췌를 프롬프트에 붙여 쓴다.
- 저널·목표 UI 를 위한 필드 — [deferred/P1-13](../deferred/P1-13-journal-ui.md).
- 아이템·인벤토리 필드. `reward.none_else` 가 그 부재를 명시하는 것이 이 서식의 태도다.
- 서식 편집 GUI. 텍스트 파일 하나다.
