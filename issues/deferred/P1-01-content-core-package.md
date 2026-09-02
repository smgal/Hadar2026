# P1-01 `packages/hadar_content` 순수 Dart 패키지 신설

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P0 완료 대기)
- **구간**: P1
- **규모**: M
- **선행**: P0 완료
- **설계 근거**: [BP-30 §4.3~4.7 · §5.1~5.3](../../blueprint/30_toolchain_overview.md) · [D-11 · D-12](../../blueprint/_meta/DECISIONS.md) · `GROUND_TRUTH` 부록 A-4 · B-5

## 문제

D-11 은 콘텐츠 모델을 `hadar2026_app/lib/domain/content/` 에 두라고 정했고, D-12 는 순수 Dart CLI 가
**그 평가기를 그대로 import** 해야 한다고 정했다. 두 결정이 물리적으로 양립하지 않는다.

- `hadar2026_app/pubspec.yaml:31-32` 이 `flutter: sdk: flutter` 를 직접 의존한다. 따라서 CLI 가
  `hadar2026_app` 을 path dep 으로 가리키면 `flutter: sdk` 가 **전이로 딸려온다**
  ([BP-30 §4.3](../../blueprint/30_toolchain_overview.md) 이 프로브 패키지로 실측했다).
- 같은 실측이 더 나쁜 것을 잡았다: `dependency_overrides` 는 **루트 패키지에만** 적용되므로
  `hadar2026_app/pubspec.yaml:37` 이 고정한 bonfire 3.16.1 / flame 1.35.1 핀이 CLI 쪽에서 조용히 깨진다.
  CLAUDE.md 가 금지한 flame 승격이 여기서 일어난다.
- 선례는 이미 있다. `packages/cm2_script/pubspec.yaml` 은 **10줄**이고
  `dev_dependencies: test` 하나뿐인 Flutter 무의존 패키지이며, 앱(`hadar2026_app/pubspec.yaml:40-41`)과
  CUI 데모(`cm2_script_sample`) 양쪽이 path dep 으로 소비한다. 정확히 필요한 형태다.
- `hadar2026_app/pubspec.yaml:65-69` 의 `flutter.assets` 는 `assets/`·`assets/images/`·`assets/maps/`·`assets/fonts/`
  4개를 열거한다. Flutter 의 디렉토리 선언은 **하위 디렉토리를 포함하지 않는다**(부록 A-4).

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** 손으로 퀘스트를 만들어도 `hadar_content validate`(P1-12)를 돌려야 하고,
그 검증기가 **런타임과 같은 평가기**를 써야 한다(D-12 · [BP-33 §9.2](../../blueprint/33_validation_and_lint.md)).
평가기가 두 벌이 되면 "검증은 통과했는데 게임에서 다르게 분기한다" 는 실패가 생기고,
이는 손 저작에서 가장 비싼 종류의 버그다(발견이 플레이 시점으로 밀린다).

또한 이 패키지가 없으면 P1-02·P1-03 이 코드를 둘 곳이 없다. P1 전체의 물리적 선행이다.

## 무엇을 할 것인가

설계는 [BP-30 §4.5~§5.3](../../blueprint/30_toolchain_overview.md) 에 있다. 구현 단위만 적는다.

1. **`packages/hadar_content/`** 생성.
   - `pubspec.yaml` — [BP-30 §4.6](../../blueprint/30_toolchain_overview.md) 의 최소 형태 그대로
     (`dependencies: meta`, `dev_dependencies: test`). `cm2_script/pubspec.yaml` 과 같은 골격.
   - `analysis_options.yaml` — warning fatal (cm2_script 잡과 같은 강도).
   - `lib/src/build_mode.dart` — `kDebugMode` 대체 상수. `flutter/foundation` 을 쓰지 않기 위한 것.
   - `lib/` 에 [BP-30 §5.1](../../blueprint/30_toolchain_overview.md) 트리의 파일 **골격만** 생성:
     `content_ids.dart` `condition.dart` `effect.dart` `quest.dart` `stage.dart` `objective.dart`
     `dialogue.dart` `node.dart` `choice.dart` `actor.dart` `item.dart` `place.dart` `anchor.dart`
     `world_state.dart` `world_event.dart` `world_rng.dart` `strings.dart` + 공개 배럴 `hadar_content.dart`.
   - 이 이슈가 실제로 **구현**하는 것은 `content_ids.dart`(ID 문법 파싱/검증, [BP-21 §4.1·§4.3](../../blueprint/21_content_pack_spec.md))
     하나다. 나머지는 타입 선언 뼈대이고 본체는 P1-02·P1-03·P1-05·P1-07·P1-08·P1-10 이 채운다.
2. **`hadar2026_app/lib/domain/content/`** 에 배럴 파일 생성 (R-30-14).
   각 파일은 `export 'package:hadar_content/<같은이름>.dart';` **한 줄뿐**이어야 한다(R-30-15).
   D-11 이 정한 경로가 유지되므로 BP-21~28 의 경로 인용이 전부 유효하게 남는다.
3. **`hadar2026_app/pubspec.yaml`** — `:40-41` 의 `cm2_script` 바로 아래에 path dep 추가.
4. **`flutter.assets`** — `:69` 다음 줄에 `assets/content/build/` **한 줄만** 추가.
   소스 트리(`assets/content/core/` 등)는 **의도적으로 미등록**이다(D-01 ③ 구획: 런타임은 소스 JSON 을 읽을 자격이 없다).
   **순서 제약(R-30-19)**: `assets/content/build/` 에 파일이 1개 이상 생긴 **뒤에** 선언을 추가한다.
   빈 디렉토리 선언의 동작은 BP-30 이 스스로 미검증이라 표시한 유일한 주장이므로 T-30-1 로 1회 실측하고 결과를 남긴다.
5. **CI** — `.github/workflows/ci.yml:77` 의 `cm2_script` 잡을 복제해 `hadar_content` 잡 추가.
   `:54-65` 의 `check()` 헬퍼는 검색 경로가 하드코딩(`:57`)되어 있으므로 **경로를 인자로 받는 `check_in` 으로 1줄 일반화**한 뒤
   `packages/hadar_content/lib/` 대상 `package:flutter` 검사와 배럴 검사를 추가한다(R-30-15 · R-30-17).
   `grep … && exit 1` 형태를 쓰지 말 것 — 정상 상태에서 CI 가 빨개진다(BP-30 §4.5 의 F-30-02).

## 완료 판정 기준

- [ ] `cd packages/hadar_content && dart pub get && dart analyze && dart test` 가 **Flutter SDK 없이** 성공한다
- [ ] `grep -rn "package:flutter" packages/hadar_content/lib/` 가 빈 결과다
- [ ] `hadar2026_app/lib/domain/content/` 의 모든 줄이 `export` 문·주석·빈 줄이다 (R-30-15 grep 이 빈 결과)
- [ ] `cd hadar2026_app && flutter pub get && flutter analyze --no-fatal-infos && flutter test` 통과
- [ ] `flutter build web --release` 후 `grep -c "content/core" build/web/assets/AssetManifest.json` 이 `0`,
      `content/build/content.bundle.json` 은 존재한다
- [ ] CI 에 `hadar_content` 잡이 있고 녹색이다. `check_in` 일반화 후 기존 2개 검사도 여전히 `ok:` 를 출력한다
- [ ] **테스트**: `packages/hadar_content/test/content_ids_test.dart` — `<type>.<pack>.<slug>` 문법과
      슬러그 규칙(소문자/숫자/언더스코어, 3~48자, 숫자 시작 금지)의 **경계값**을 고정한다.
      예약어와 상태 키 문법(`flag.<pack>.<domain>.<name>`)도 같은 파일에서 고정한다
- [ ] T-30-1(빈 에셋 디렉토리 선언) 결과가 BP-30 §5.3 각주로 기록되었다

## 하지 않을 것

- op/do 구현 — P1-02.
- `WorldState` 구현 — P1-03.
- `tools/content_cli/` 생성과 `build`/`validate` 구현 — P1-12.
- 콘텐츠 서버 `/api/content/*`, MCP 래퍼, 생성 파이프라인, 프롬프트 — **전부 P2**.
- `assets/content/` 의 실제 콘텐츠 데이터 — P1-15·P1-16.
