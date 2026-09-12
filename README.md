### 2026년에 시작하는 "또 다른 지식의 성전" 복각 프로젝트

<img width="602" height="383" alt="image" src="https://github.com/user-attachments/assets/126ebcd9-76ee-4b64-88f7-0b16420d2168" />

1993년 한국 RPG **「또 다른 지식의 성전」** 을 Flutter/Dart 로 다시 만든다.
웹 데모는 [smgal.github.io/Hadar2026](https://smgal.github.io/Hadar2026/) 에서 바로 볼 수 있다.

---

## 직접 돌려 보기

네 가지를 따로 띄울 수 있다. **게임만 Flutter SDK 가 필요하고 나머지 셋은 `dart` 만 있으면 된다.**

| 무엇 | 명령 | 자세히 |
|---|---|---|
| **게임** | `cd hadar2026_app && flutter pub get && flutter run` | [hadar2026_app/README.md](hadar2026_app/README.md) |
| **장비 실험실** — 마우스로 여덟 칸을 갈아 끼우고 그 장비로 한 판 싸운다 | `cd hd_world_lab && dart pub get && dart run bin/serve.dart` → `http://127.0.0.1:5330/` | [hd_world_lab/RUN.md](hd_world_lab/RUN.md) |
| **전투 실험실** — 전투만 띄운다. 한 수 물릴 수 있다 | `cd hadar2026_app && flutter run -t lib/battle_lab_main.dart` | [hd_battle_console/RUN.md §0](hd_battle_console/RUN.md) |
| **전투 콘솔** — 터미널에서 같은 전투를 굴린다 | `cd hd_battle_console && dart pub get && dart run bin/battle.dart` | [hd_battle_console/RUN.md](hd_battle_console/RUN.md) |

두 실험실은 **게임을 켜지 않고** 규칙을 만져 보는 곳이다. 장비를 바꾸면 최종 수치가
바로 다시 계산되고, 전투는 같은 판을 씨앗으로 몇 번이든 다시 굴릴 수 있다.

### 시험 전량

```bash
for p in packages/hd_world packages/hd_world_text packages/hd_world_legacy \
         packages/hd_bridge packages/hd_battle packages/hd_battle_text \
         packages/cm2_script hd_world_lab hd_battle_console; do
  (cd $p && dart pub get > /dev/null && dart test)
done
(cd hadar2026_app && flutter test)
```

---

## 어디에 무엇이 있나

| 디렉토리 | 무엇 |
|---|---|
| `hadar2026_app/` | Flutter 앱. 화면·입력·지도·스크립트 연결 |
| `packages/hd_battle/` | 전투 규칙. 순수 Dart, 화면도 한국어도 없다 |
| `packages/hd_world/` | 인물·파티·아이템·장비. 마찬가지로 순수 Dart |
| `packages/hd_bridge/` | 위 둘을 잇는다. **둘은 서로를 모른다** |
| `packages/hd_world_legacy/` | 출하 스크립트가 쓰는 옛 이름과 번호 |
| `packages/hd_battle_text/` · `hd_world_text/` | 한국어 이름과 문장. 화면이 여기서만 가져온다 |
| `packages/cm2_script/` | 원작 스크립트 언어(cm2) 해석기 |
| `hd_battle_console/` · `hd_world_lab/` | 위 규칙들을 사람이 만져 보는 곳 |
| `tools/mapEditor/` | 지도 편집기 (pnpm). `assets/maps/*.json` 을 그 자리에서 고친다 |
| `REF_hadar/` · `REF_UNITY_LoreEp1/` | 원작 C++ 과 Unity 이식본. **읽기 전용** |

## 문서

| | 무엇 |
|---|---|
| [`issues/BOARD.md`](issues/BOARD.md) | 지금 무엇을 할 수 있는가 |
| [`issues/DECISION-LOG.md`](issues/DECISION-LOG.md) | 왜 이 길로 왔는가 (판정 10건) |
| [`blueprint/`](blueprint/00_README.md) | 설계 문서 38편. 왜 그렇게 만들었는지 |
| [`blueprint/_meta/GROUND_TRUTH.md`](blueprint/_meta/GROUND_TRUTH.md) | 코드를 직접 열어 확인한 사실. 코드에 대한 주장은 여기와 맞아야 한다 |
| [`CLAUDE.md`](CLAUDE.md) | 이 레포에서 일하는 AI 에게 주는 안내 |
