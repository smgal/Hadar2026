# P0-17 CI 에 `dart:io` 계층 검사와 웹 빌드 스모크를 추가한다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: P0-16
- **설계 근거**: [D-23 CI 계층 검사에 `dart:io`/`dart:html` 추가](../../blueprint/_meta/DECISIONS.md) · [`GROUND_TRUTH` 부록 B-4 (정정판) · B-5 · §2](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-35 CI·빌드](../../blueprint/35_ci_and_build.md)

## 문제

`.github/workflows/ci.yml:50-75` 의 "Check layering invariants" 스텝은 **확장 가능한 `check()` 헬퍼**를 갖고 있다
(본인 확인, 실제 형태):

```yaml
          check() {
            local label="$1"; shift
            local hits
            hits="$(grep -rn "$@" lib/application/ lib/domain/ || true)"
            if [ -n "$hits" ]; then
              echo "::error::layering violation — $label"; echo "$hits"; fail=1
            else
              echo "ok: $label"
            fi
          }

          check "application/domain must not import presentation/ or hd_game_main.dart" \
            -E "^import .*(presentation/|hd_game_main\.dart)"
          check "application/domain must not import material/bonfire/flame" \
            -E "package:flutter/material|package:bonfire|package:flame"

          exit $fail
```

즉 `check "<라벨>" <grep 인자…>` 형태로 **호출 한 줄만 추가하면 검사가 늘어난다.**

빠진 검사 둘:
1. **`dart:io`/`dart:html` 검사가 없다.** CLAUDE.md 와 부록 §2 가 금지를 선언했지만 위 두 grep 은 잡지 못한다.
   그래서 `menu_flows.dart:2` 의 위반이 **CI 를 통과해 왔다**([P0-16](P0-16-dart-io-and-exit.md)).
2. **웹 빌드가 CI 에 없다.** `flutter build web --release` 는 `deploy_web.yml` 의
   수동 `workflow_dispatch` 에서만 돈다. 부록 B-4 정정판의 성공 확인은 **로컬 1회**였고 회귀 장치가 없다.

## 왜 지금 고쳐야 하는가

- [D-23](../../blueprint/_meta/DECISIONS.md) 이 **순서를 못박았다**: 이 검사 추가와 `exit(0)` 제거는 **같은 변경으로 함께** 가야 한다.
  먼저 추가하면 CI 가 즉시 빨개진다. 그래서 [P0-16](P0-16-dart-io-and-exit.md) 이 선행이다.
- [MILESTONES.md §2](../MILESTONES.md) 의 P0 완료 기준 7·8번이 이 항목을 직접 지목한다:
  "계층 grep(+`dart:io`) 전부 통과", "`flutter build web --release` 가 **CI 에서** 성공한다".
- 검사가 없으면 P1 의 새 코드가 같은 위반을 반복한다. P1 은 `application/` 아래에
  콘텐츠 런타임(퀘스트·대화 엔진)을 새로 얹는 구간이다 — 지금이 가장 싸다.

## 무엇을 할 것인가

### 1. `dart:io`/`dart:html` 검사 추가 (D-23 의 형태 그대로)

`ci.yml` 의 두 번째 `check` 호출 뒤에 세 번째를 추가한다.

```diff
    # 렌더링 라이브러리는 presentation/ 전용
    check "application/domain must not import material/bonfire/flame" \
      -E "package:flutter/material|package:bonfire|package:flame"

+   # 플랫폼 I/O 는 presentation/ 전용 (D-23 · 부록 B-4)
+   check "application/domain must not import dart:io or dart:html" \
+     -E "^import 'dart:(io|html)'"
+
    exit $fail
```

**정규식 제약 (반드시 지킬 것)**:
- **ERE lookahead(`(?=`, `(?!`)를 쓰지 말 것.** [D-23](../../blueprint/_meta/DECISIONS.md) 이 명시했다 —
  과거 이 문제로 검사가 실행 불가였다. `grep -E` 는 lookahead 를 지원하지 않는다.
- 쌍따옴표·`as io` 형태까지 잡으려면 `-E "^import ['\"]dart:(io|html)['\"]"` 로 쓰고,
  YAML 안의 인용 처리를 **실제로 돌려 확인**할 것.

### 2. 웹 빌드 스모크 추가

`app` 잡의 마지막 스텝으로 추가한다.

| # | 안 | 장점 | 단점 |
|---|---|---|---|
| A | **`app` 잡에 스텝 추가** | 캐시된 `pub get` 재사용, 설정 최소 | 잡 시간 증가 (부록 B-4 실측 컴파일 16.5초 + 오버헤드) |
| B | 별도 `web_build` 잡 | 병렬로 총 시간 단축 | Flutter 설치·`pub get` 중복 |
| C | `main` 푸시에만 | 가장 빠르다 | PR 에서 회귀를 못 잡아 게이트 취지에 반한다 |

**권고: A.**

```diff
      - name: Check layering invariants 🧱
        ...
+
+     # 웹 빌드는 실제로 성공한다(부록 B-4 정정판). 이 스텝은 그 사실을
+     # 회귀 게이트로 고정하는 것이며, "지금 깨져 있다" 는 뜻이 아니다.
+     - name: Web build smoke 🌐
+       run: flutter build web --base-href "/Hadar2026/" --release
```

`--base-href` 는 `deploy_web.yml` 과 같은 값을 쓴다.

### 3. 순서 (중요)

[D-23](../../blueprint/_meta/DECISIONS.md) 에 따라 **[P0-16](P0-16-dart-io-and-exit.md) 의 `dart:io` 제거와 1번 검사 추가를 하나의 PR 로 묶는다.** 2번은 독립적이다.

## 완료 판정 기준

- [ ] `ci.yml` 의 layering 스텝이 **3개의 `check` 호출**을 갖는다
- [ ] 세 번째 검사가 `lib/application/` 에 `import 'dart:io';` 를 일부러 넣은 브랜치에서 **실패한다**
      (검사가 실제로 동작함을 반대 방향으로 증명)
- [ ] 정규식에 lookahead(`(?=`/`(?!`)가 없다 — `grep -E` 로 로컬에서 실행해 확인
- [ ] `main` 에서 CI 가 **초록**이다 ([P0-16](P0-16-dart-io-and-exit.md) 이 함께 들어갔으므로)
- [ ] `flutter build web --base-href "/Hadar2026/" --release` 스텝이 CI 에서 성공한다
- [ ] 테스트 파일 추가는 없다 — 검증 대상이 CI 설정 자체다

## 하지 않을 것

- `dart:io` 위반 코드의 실제 수정 — [P0-16](P0-16-dart-io-and-exit.md) 소관 (같은 PR 로 묶되 이슈는 분리).
- `dart format` 게이트 추가. `ci.yml:37-39` 의 주석대로 레포가 format-clean 이 아니며,
  일괄 포맷은 별건이다.
- `--no-fatal-infos` 제거 (info 77건 정리가 선행) · `sim`/`solve` CI 통합([P2-09](../deferred/P2-09-ci-and-editor.md)).
- 번들 크기 예산 게이트 — [BP-35](../../blueprint/35_ci_and_build.md) 소관. 부록 B-5 의 기준선(45MB) 위에서 P1 이후 판단.
- `check()` 헬퍼의 대상 경로 파라미터화 — 필요해질 때 한다.
