# lore2026_app

또 다른 지식의 성전 3부작 복각 (Lore Trilogy 2026)

## 개발자 모드 — 시나리오 중간에서 시작하기

제목 화면 맨 아래 **「[개발] 개발자 모드 켜기」** 를 고르면 켜진다. 같은 자리가 「끄기」로 바뀌고, 한 번 바꾼 값은 다음 실행에도 기억한다.
웹은 주소에 `?dev=1`(끄려면 `?dev=0`), 데스크톱은 `flutter run --dart-define=LORE_DEV=true` 로도 켜진다.

> **최종 배포 전에** `lib/application/dev/dev_mode.dart` 의 `HDDevMode.switchOnTitle` 을 `false` 로 바꾼다 — 제목 화면의 켜기·끄기 줄이 사라진다.

- 제목 화면 맨 아래 **「[개발] 시나리오 중간에서 시작」** → 편 → 장 → 장면을 고르면 그 시점의 플래그·변수·일행·레벨·장비로
  새 판이 만들어지고 그 자리에 선다. 글 창에 「확인할 것」이 나온다.
- 게임 중 주 메뉴(Space) 맨 아래 **「[개발] 개발자 메뉴」** — 장면으로 건너뛰기 · 일행 완전 회복 · 무작위 조우 끄기/켜기 ·
  기술치를 계급 상한까지 · 레벨 바꾸기 · 켜진 플래그·변수 보기 · 지금 자리 보기.
- 장면은 1편 60개 · 2편 45개 · 3편 60개(충성·반역·795년 갈래 포함). 자료는 `assets/dev/ep1.json` ~ `ep3.json`.

장면 하나는 **앞 장면에서 바뀐 것만** 적는다 — 건너뛰면 처음부터 그 장면까지 차례로 쌓는다.

```json
{"id": "1-43", "title": "크랩 갓의 왕 — 봉인의 길",
 "map": "E1_EvilGod", "at": [22, 14], "goal": [22, 6],
 "flags": ["EVILGOD_LEVER_W"], "vars": {"EVILGOD_SEAL": 6},
 "check": "봉인은 x=22 길 끝(22,6). 병사 칸을 지나 크랩 갓의 왕"}
```

- `at` · `goal` 은 스크립트 좌표(1부터). `goal` 을 적으면 시험이 그 칸까지 걸어서 닿는지 본다.
- 일행은 `level` · `party` · `assistant` · `gear` · `skills`("auto" 는 기술치 20 + 레벨 × 5, "max" 는 계급 상한).
  레벨 8 이상이면 마법사 계열 동료를 대마법사로 올린다(변화 마법 80 — 공간 이동).
- `flags` 의 `-이름` 은 끈다. `vars` 의 `"day+20"` · `"year+20"` · `"month+20"` · `"date+20"` 은 그 장면 시각의 20일 뒤.
- 갈래는 `from` 으로 앞의 다른 장면에서 이어 쌓는다. 전체 열쇠는 `lib/application/dev/dev_scenes.dart` 머리 주석.
- 장면을 고치면 `flutter test test/dev/` — 모든 장면을 실제로 건너뛰어 맵·서는 칸·플래그 이름(대본에 있는지)을 본다.
  서는 칸이 틀리면 가까운 걸을 수 있는 칸을 알려 준다.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
