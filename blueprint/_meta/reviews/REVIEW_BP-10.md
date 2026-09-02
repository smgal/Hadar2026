# 검수 보고서 — BP-10 현행 구조 정밀 감사

- **검수자**: R3 · **대상 파일**: blueprint/10_current_architecture_audit.md (1233줄)
- **판정**: **수정 필요**
- **점수**: A2 B4 C4 D2 E3 F5 G5 = **25/35** (합격선 26점 미달, 축 A·D 가 2점)

## 0. 총평

이 문서는 **조사의 밀도로 보면 상위권**이다. 맵 파일 13개의 크기·차원·이벤트 수·대사 줄 수·md5 중복,
cm2 자산 17개의 줄 수 합계(4,056), 테스트 9개 파일의 줄 수(합계 1,157), `battle.dart` 의 `Random()` 호출 14곳의
줄 번호 전량 — 이런 것들을 **하나도 틀리지 않고** 실측했다. 이 정도로 숫자를 맞춘 감사 문서는 드물다.

그런데 **판정은 "수정 필요"** 다. 이유는 두 가지다.

1. **축 A** — 인용 검증 76곳 중 **13곳이 틀렸고**, 그중 4건은 줄 번호 오차가 아니라 **사실 자체가 다르다**.
   루브릭 기계검사 2번("하나라도 틀리면 A 는 3점 이하")과 검수 지시("3곳 이상 틀리면 A 는 2점 이하")를
   기계적으로 적용하면 A=2 다. 이 장은 기획서 전체의 사실 기반이므로 이 규칙을 완화할 수 없다.
2. **축 D** — `_meta/GROUND_TRUTH.md` **부록 A-2 가 문서 어디에도 반영되지 않았다.**
   A-2 는 이 장의 §5.4 · §7.2 결론을 통째로 뒤집는 사실이며, 빠짐으로써 §7.2 의 "실동작" 열이
   실제 런타임 거동과 어긋난다(F-01). 여기에 `HDMagicSystem`·`HDBattle` 흐름·`HDMenuFlows`·
   `world_map_renderer`·`sight_calculator` 가 **한 줄도 서술되지 않았다**.

고칠 것은 많지 않고 전부 국소적이다. F-01·F-02 두 건과 인용 13곳을 손보면 이 장은 합격 수준으로 올라간다.

---

## 1. 코드 인용 검증표 (36행)

전부 실제 파일을 열어 대조했다. 판정 기호: ✅ 정확 · ⚠ 줄 번호 오차(내용은 그 근처에 존재) · ❌ 사실 불일치.

| # | 인용 위치 | 문서 주장 | 실제 | 판정 |
|---:|---|---|---|:--:|
| 1 | `ports/ui_host.dart:10` | `abstract class UiHost` | 10행이 `abstract class UiHost {` | ✅ |
| 2 | `ports/movement_host.dart:7` | `PartyMovementHost` / `animatePartyMove` | 7행 `abstract class PartyMovementHost {`, 10행 메서드 | ✅ |
| 3 | `ports/asset_source.dart:12` | `AssetSource.loadString` | 12행 `abstract class AssetSource {`, 18행 `loadString` | ✅ |
| 4 | `ports/host_binding.dart:16` | `HDHosts` 합성 루트 | 16행 `class HDHosts {` | ✅ |
| 5 | `ports/host_binding.dart:31` | 고치는 법을 알려주는 `StateError` | 31~35행, 인용 문자열 **문자 단위 일치** | ✅ |
| 6 | `hd_game_main.dart:38` | `class HDGameMain with ChangeNotifier implements UiHost, PartyMovementHost` | 38행 동일 | ✅ |
| 7 | `hd_game_main.dart:172` | `HDHosts().bind(ui:_host, movement:_host, assets:HDBundleAssetSource())` | 172~176행 동일 | ✅ |
| 8 | `hd_game_main.dart:189` | `_onSessionChanged` 가 mapVersion 비교 후 `clearProgress()` | 189~195행 동일 | ✅ |
| 9 | `hd_game_main.dart:201` | `notifyListeners()` 를 `Future.microtask` 로 지연 | 201~205행 동일 | ✅ |
| 10 | `hd_game_main.dart:159` | 입력 모드 우선순위 window>menu>dialogue>map | 159~164행 동일 | ✅ |
| 11 | `presentation/host/bundle_asset_source.dart:23` | `if (!kIsWeb && await File(path).exists())` | 23~26행 동일 | ✅ |
| 12 | `.github/workflows/ci.yml:50` | "Check layering invariants" 잡 | 50행 `- name: Check layering invariants 🧱` | ✅ |
| 13 | `.github/workflows/ci.yml:68` / `:72` | grep 2종 원문 | 68·72행 동일 | ✅ |
| 14 | `application/menu_flows.dart:2` / `:504` | `import 'dart:io';` / `exit(0)` | 2행·504·522·540행 동일 | ✅ |
| 15 | `application/tile_event_dispatcher.dart:44` | `if (map == null) return;` | **45행**. 44행은 `}) async {` | ⚠ |
| 16 | `tile_event_dispatcher.dart:58` / `:62` / `:73` / `:98` | isScriptedAction / beginNarrative / switch / endNarrative | 58·62·73·98행 전부 일치 | ✅ |
| 17 | `tile_event_dispatcher.dart:116` `:126` `:137` `:152` `:159` | 3티어 분기 전 구간 | 116·126·137·152·159행 전부 일치, 코드도 축약 외 일치 | ✅ |
| 18 | `domain/map/tile_properties.dart:183` | `getUnitAction` 3단 폴백 | 183~205행, 인용 코드 일치 | ✅ |
| 19 | `tile_properties.dart:172` / `:208` | `_getTileAction` / `_getObjectAction` 범위표 | 172·208행, 범위값 전부 일치 | ✅ |
| 20 | `tile_properties.dart:107` | `if (action == none \|\| action.isInteractive) return false;` | 107행 동일 | ✅ |
| 21 | `HDTileAction` 열거값 `none(0)`…`move(9)` | scriptMode 는 와이어 값 | 16~40행, 값 전부 일치. `debugTag`(61~70) 도 일치 | ✅ |
| 22 | `application/map_loader.dart:57` | `int eventType = 0;` + 4분기 | 57~67행 동일. NPC 분기 없음도 사실 | ✅ |
| 23 | `domain/map/map_event.dart:54` | `_parseTypeString` 접두사 판정 | 54~61행 동일 | ✅ |
| 24 | `map_event.dart:12` / `:18` / `:79` | `HadarEvent` / fromJson / `code==401` | 12·18·79행 전부 일치 | ✅ |
| 25 | `application/map_navigation.dart:41` | `Map$idStr` 규칙이 이름 폴백을 덮어씀 | 41~46행 동일 | ✅ |
| 26 | `map_navigation.dart:60~74` | JSON 실패해도 cm2 있으면 번들 반환 | 60·63~67·70~74행 동일 | ✅ |
| 27 | `application/game_session.dart:68/69/76/97/107` | 부팅·맵 로드 순서 | 68·69·76·97·107행 전부 일치 | ✅ |
| 28 | `scripting/script_engine_adapter.dart:39/45/52~63` | executePendingNavigation, 시작 위치 우선순위 | 39·45·52~63행 전부 일치 | ✅ |
| 29 | `script_engine_adapter.dart:103` / `:124` / `:144` / `:287` / `:297` | clearRuntimeState / GameReloadException / _applyEntryFacing / LoadScript / 지연 전환 | 전부 일치 | ✅ |
| 30 | `script_engine_adapter.dart` 커맨드 **43개** | §5.2 | 실제 **40개**(`registerCommand` 40회). 문서가 나열한 이름도 **40개** | ❌ |
| 31 | `script_engine_adapter.dart` 함수 **11개** | §5.2 | 실제 **12개**. 문서가 나열한 이름도 **12개** | ❌ |
| 32 | `script_engine_adapter.dart:418/:419/:445/:458` | 스텁 4종 | 418·419(빈 본문), 445·458(print) 전부 일치 | ✅ |
| 33 | `packages/cm2_script/lib/src/cm2_script.dart:198` | 미등록 커맨드 → print 후 스킵 | 198~205행 동일 | ✅ |
| 34 | `cm2_script.dart:330` | 미등록 함수 → print 후 `return 0` | 330~336행 동일 | ✅ |
| 35 | `cm2_script.dart:80` | init 단계 `for (var stmt in currentScript)` | 80행은 `_executeRootInitialization` 시그니처, for 는 **81행** | ⚠ |
| 36 | `cm2_script.dart:99` / `:311` | run 이 variable/include 만 skip / `Random().nextInt` | 99·311행 동일 | ✅ |
| 37 | `packages/cm2_script/lib/src/parser.dart:111` | 괄호 없으면 인자 없는 커맨드 | 111~113행 동일 | ✅ |
| 38 | `scripting/native_script_runner.dart:25` / `:91` / `:95` | mapScriptFactory 4종 / isFlagSet / setFlag | 25~30·91·95행 전부 일치 | ✅ |
| 39 | `scripting/map_script.dart:41` / `:17` | 플래그 헬퍼 스텁 / `Future<bool>` 훅 | 41~48·17행 일치 | ✅ |
| 40 | `scripting/maps/town1_map_script.dart:76` | `isOn(45,8)` 분기 전문 | 76~87행 **문자 단위 일치** | ✅ |
| 41 | `domain/game_option.dart:9` | `flags = List.filled(maxFlags,false)` | 일치 | ✅ |
| 42 | `application/save_manager.dart:18` | 세이브 페이로드 5필드 | 18~24행 동일 | ✅ |
| 43 | `save_manager.dart:79` | `run()` 생략 주석 | 79~80행 동일 | ✅ |
| 44 | `save_manager.dart` 전체에 `data['version']` 0건 | §6.4 | 37~106행 실독 결과 참조 0건 | ✅ |
| 45 | `application/game_reload_exception.dart:9` | 클래스 선언 | 9행 동일 | ✅ |
| 46 | `application/battle.dart:42` | `registerEnemy` 의 `<= 0` 가드 | 메서드 **43행**, 가드 **44행**. 42행은 빈 줄 | ⚠ |
| 47 | `battle.dart:241` | `int totExp = enemies.fold(...)` | **243행**. 241행은 `// Win` 주석 | ⚠ |
| 48 | `battle.dart:261` | `_party.gold += ... e.level*5` | 261행 동일 | ✅ |
| 49 | `battle.dart:29` (§9.7) | `int _battleResult = 1; // 1:Win, 0:Lose, 2:Run away` | **27행**. 29행은 `selectedEnemyIndex` | ⚠ |
| 50 | `battle.dart` Random 14곳 155/174/389/427/432/440/441/474/478/479/488/503/513/514 | §9.6 | **14곳 전부 정확** | ✅ |
| 51 | `battle.dart:453` | 무기 이름이 전투 로그에 노출 | 453행 문자 단위 일치 | ✅ |
| 52 | `domain/party/player.dart:91` | `getWeaponName/ShieldName/ArmorName` 3줄 | 91~93행 문자 단위 일치 | ✅ |
| 53 | `player.dart:167` 21개 / `:250` 20개 | expTable 두 번 하드코딩, 길이 다름 | 실측 21개·20개 **정확** | ✅ |
| 54 | `player.dart:193~206` | 레벨업 성장식 | 193~207행, 수식 전부 일치 | ✅ |
| 55 | `player.dart:71` | 독 피해가 벽시계 기반 | 71행 문자 단위 일치 | ✅ |
| 56 | `domain/party/party.dart:13` | `PartyInventory{food=100, gold=500}` | 13~16행 동일 | ✅ |
| 57 | `party.dart:81~133` / `:234` | players 6칸, 0 슴갈 / 1 유리 / timeGoes | 81·84·110·234행 일치 | ✅ |
| 58 | `domain/magic/magic.dart:11` 45종 | §7.7 | `HDMagic(n,...)` 45개, index 1~45 **정확** | ✅ |
| 59 | `application/magic_system.dart:54` | `spCost = (magicId>=33) ? 10 : 5` | **56행**. 54행은 빈 줄 | ⚠ |
| 60 | `domain/battle/enemy_data.dart:33` 75종(id 0~74) | §7.5 | 33행 `const List<HDEnemyData> enemyTable = [`, 엔트리 **75개**, 최대 id 74 | ✅ |
| 61 | `hd_config.dart:45` 블록 | maxFlags/maxVariables/maxLinesPerPage/maxProgressLines 4줄 연속 | maxFlags 45·maxVariables 46 는 맞으나 maxLinesPerPage **52**, maxProgressLines **58**. 연속 아님 | ⚠ |
| 62 | `hd_config.dart` 값 자체 (256/256/13/200, startupScript) | §8.2 | 값 전부 일치 | ✅ |
| 63 | `presentation/host/flutter_ui_host.dart:120` / `:137` / `:63` | 13줄 페이지 넘김 / 10ms 지연 / 랩 폭 480 | 120·137·63행 전부 일치 | ✅ |
| 64 | `domain/console/console_log.dart:27` | 파라미터 이름이 `maxLinesPerPage` 인 혼동 | 27행 동일 | ✅ |
| 65 | `utils/hd_text_utils.dart:4` **18색** | §8.2 | `colorTable` 엔트리 **17개**(`0`~`F` 16 + `G` 1) | ❌ |
| 66 | `presentation/input/input_dispatcher.dart:149` | "Action (Enter/E) is handled by HDPlayerSprite" | 149~151행 **문자 단위 일치** | ✅ |
| 67 | `input_dispatcher.dart:55/:86/:114/:127~147` | 모드별 소비 정책 | 55·86·114·127~147행 전부 일치 | ✅ |
| 68 | `presentation/panels/player_sprite.dart:122` | 액션 키 폴링 | 122~127행 일치 | ✅ |
| 69 | `player_sprite.dart:193` / `:362` / `:405` | 이벤트 발화 3지점 | 193·362·405행 **전부 정확** | ✅ |
| 70 | `player_sprite.dart:182` | `final mapType = ...` | 블록은 **181** 행부터. 182행은 `if (mapType == TYPE_GROUND)` | ⚠ |
| 71 | `main.dart:13~38` / `:166~171` | 부팅·하단 2패널 | 13~38·166~171행 일치 | ✅ |
| 72 | `main.dart:84` | `void _onGameChanged() {` | **83행**. 84행은 그 안의 `if` | ⚠ |
| 73 | `main.dart:131` | `FittedBox(fit: BoxFit.contain)` | **133행**. 131행은 `Flexible(` | ⚠ |
| 74 | `assets/startup.cm2:2~:6` | 6줄 전문 | 일치(1행은 빈 줄) | ✅ |
| 75 | `assets/const.cm2:53` / `:64~:68` | BATTLERESULT / FLAG_* | 53~55·64~68행 전부 일치 | ✅ |
| 76 | `assets/Map002.cm2:5~:21` | TALK 블록, `Event::Override()` 유무 | 5~21행 문자 단위 일치 | ✅ |
| 77 | §7.1 맵 13개 표 (크기·w×h·events·401줄·displayName) | 전 행 | **13행 전부 정확**. 총계 38 이벤트 / 31 대사줄도 정확 | ✅ |
| 78 | §7.1 md5 중복 3중/2중 | TOWN1=ORIGIN=Map014, GROUND1=Map013 | md5 실측 일치 | ✅ |
| 79 | §7.2 MapInfos 15개 이름·id | 전 행 | `MapInfos.json` 전문과 일치, `cm2`/`json` 필드 0건도 사실 | ✅ |
| 80 | §7.3 cm2 자산 17개 줄 수 / 총 4,056 / 부팅 134줄 | 전 행 | `wc -l` 실측 **전부 정확** | ✅ |
| 81 | §9.1 테스트 9개 줄 수 / 총 1,157 / lib 8,904 | 전 행 | `wc -l` 실측 **전부 정확** | ✅ |
| 82 | §1.2 파일별 줄 수 14행 표 | 582/544/538/466/424/335/304/280/257/255/249/227/180/152 | **14행 전부 정확** | ✅ |
| 83 | `tools/mapEditor/server/ai_api.ts:345` / `:370` / `:480` | validateMap / 경고 문구 / 라우팅 진입 | 전부 일치 | ✅ |
| 84 | `pubspec.yaml:65` assets 4줄 | §7.10 | 65~69행 동일 | ✅ |
| 85 | §4.5 `Map002.cm2` (30,20) 대화가 **JSON 과 중복 출력**된다 | — | `Map002.json` 의 18개 이벤트 좌표에 **(30,20) 없음**. `_emitJsonDialog` 은 아무것도 출력하지 않음 → 중복 없음 | ❌ |
| 86 | §7.1/§7.2/§10.1 `ORIGIN.json` 은 어떤 경로로도 로드 불가한 사문 자산 | — | `loadByName("ORIGIN")` 은 MapInfos 미등록이므로 **이름 폴백 `ORIGIN.json` 이 살아** 정상 로드됨(cm2Path=null → 레거시 티어) | ❌ |
| 87 | §10.1-8 "15개 중 **6개**가 존재하지 않는 파일로 해석" | — | §7.2 표와 BP-11 G-22 는 **7개**(Map004/005/006/007/008/009/012). 내부 모순 | ❌ |

**집계**: 검증 87행 중 ✅ 70 · ⚠ 9 · ❌ 8. **틀린 인용 = 13곳**(⚠ 9 + 사실 불일치 중 인용 대상이 있는 4곳).
사실 자체가 다른 항목은 30·31·65·85·86·87 의 **6건**이다.

---

## 2. 치명 결함 (반드시 고쳐야 함)

### F-01 부록 A-2(“cm2 로드 실패가 엔진 상태를 누수시킨다”)가 문서에 **한 줄도 없다** — §5.4·§7.2 의 결론이 뒤집힌다

- 위치: 10_current_architecture_audit.md §5.4(664~672행), §7.2(838~860행), §10.1-8(1202행)
- 문서 주장:
  - §5.4 — “`loadScript` 는 맵 전환마다 호출된다. 따라서 cm2 의 `variable` 전역은 맵 하나 안에서만 유효”
  - §7.2 표 — `Test`/`Prolog_B1`/`Prolog_B2`/`LoreContinent`/`CastleLore`/`LastDitch` 의 실동작 = **“JSON 만”**
- 실제: `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:92`~`:99`
  ```dart
  Future<void> loadScript(String assetPath) async {
    String content;
    try {
      content = await HDHosts().assets.loadString(assetPath);
    } catch (e) {
      print("ScriptEngine: [ERROR] Failed to load $assetPath: $e");
      return;                      // ← 103행의 clearRuntimeState() 에 도달하지 못함
    }
  ```
  `clearRuntimeState()` 는 **로드에 성공했을 때만** 실행된다. `MapInfos.json` 에 `cm2` 필드가 하나도 없으므로
  15개 이름 중 **13개**가 존재하지 않는 `MapNNN.cm2` 를 페어 cm2 로 갖고, 그 13개 맵으로 이동할 때마다
  **직전 맵의 파싱된 스크립트와 `variables`/`_contexts` 가 그대로 남는다.**
  동시에 `HDGameSession.currentMapCm2Path` 는 non-null 이므로
  `_dispatchScripted` 의 **티어 2(cm2)가 선택되고, 직전 맵의 핸들러가 새 맵 좌표에 대해 실행된다.**
  즉 §7.2 표의 “JSON 만” 은 틀렸고(정확히는 “직전 맵 cm2 실행 → `handled==false` 일 때만 JSON”),
  §5.4 의 “맵 전환마다 엔진 전역이 지워진다” 도 **로드 성공 시에만** 참이다.
- 왜 치명인가: 이 장은 기획서의 사실 기반이고, BP-11 G-22 · D-10(티어 재정의) · BP-28(공존 전략) 이
  전부 “티어 판정은 `currentMapCm2Path` 로 결정된다” 를 전제로 서 있다. A-2 를 빼면
  **“cm2 티어가 사실상 항상, 그것도 엉뚱한 스크립트로 선택된다”** 는 핵심 사실이 기획서 전체에서 사라진다.
- 요구 조치:
  1. §5.4 에 A-2 인용(`script_engine_adapter.dart:92~99`)과 “실패 시 이전 스크립트 잔존” 을 명시.
  2. §7.2 표의 “실동작” 열을 재작성 — cm2 파일이 없는 13행은 “**직전 맵 cm2 잔존 실행 → 폴백 JSON**”.
  3. §4.4 3티어 표의 “cm2 페어 맵” 행에 “페어 cm2 가 실제로 로드되었는지는 보장되지 않음” 각주 추가.

### F-02 §4.5 의 “JSON 중복 출력” 사례가 실제 데이터에 존재하지 않는다

- 위치: 10_current_architecture_audit.md §4.5(552~571행)
- 문서 주장: “(30, 20) 대화는 cm2 가 다 처리하고도 `handled == false` 이므로 **JSON `dialogLines` 가 그 뒤에 중복 출력**된다.”
- 실제: `assets/maps/Map002.json` 의 이벤트 18개 좌표는
  (11,16) (12,31) (10,31) (28,28) (30,25) (10,26) (12,24) (10,22) (12,20) (10,18) (12,17) (19,11) (18,16) (20,27) (13,37) (34,25) (33,40) (30,28) 이며
  **(30,20) 은 없다.** `_emitJsonDialog` 은 선형 탐색에서 매치 실패로 아무것도 출력하지 않는다. 중복은 일어나지 않는다.
- 부수 피해: BP-11 G-07 이 이 문장을 근거로 재인용하고 있다(11_gap_analysis.md 302~303행).
- 요구 조치: `Event::Override()` 누락이 **메커니즘상** 중복을 만든다는 서술은 유지하되,
  “현재 자산에서 실제로 중복이 관측되는 좌표는 없다(이벤트가 없는 좌표라서)” 로 정정하거나,
  실제 중복이 나는 좌표를 찾아 교체할 것. 후보 검증 방법: `map.events` 좌표 ∩ cm2 `On(...)` 좌표 교집합.

### F-03 `ORIGIN.json` 을 “사문 자산” 으로 단정한 것이 틀렸다 — 이름 폴백 경로가 살아 있다

- 위치: §7.1 표 820행(“❌ (MapInfos 미등록)”), §7.2 결론 860행, §10.1-8
- 문서 주장: “`assets/maps/TOWN1.json` 등 이름 기반 파일 4개와 `ORIGIN.json` 은 현재 **어떤 경로로도 로드되지 않는 사문 자산**”
- 실제: `hadar2026_app/lib/application/map_navigation.dart:29`
  ```dart
  String resolvedJsonName = '$searchName.json'; // Fallback
  ```
  MapInfos 루프에서 **이름이 매치되지 않으면 이 폴백이 그대로 살아남는다.**
  `ORIGIN` 은 MapInfos 미등록이므로 `assets/maps/ORIGIN.json` 이 정상 로드되고,
  `cm2Path == null` 이라 디스패치는 **레거시 티어(티어 3)** 를 탄다.
  즉 `LoadScript("ORIGIN")` 은 **지금 당장 동작한다.**
  반대로 `TOWN1`/`GROUND1`/`DEN1`/`DEN2` 가 죽은 이유는 **등록되어 있기 때문**이며,
  이 아이러니(등록이 자산을 죽인다)는 문서가 §7.2 에서 정확히 짚었으면서 결론에서 놓쳤다.
- 왜 중요한가: BP-11 §2.4 의 저비용 수리 G-22 가 “`MapInfos.json` 에 `json`/`cm2` override 명시” 만 제시하는데,
  **“해당 엔트리를 MapInfos 에서 지운다”** 도 동등하게 유효한(그리고 더 싼) 수리다. 선택지 하나가 통째로 누락됐다.
- 요구 조치: §7.1 표의 `ORIGIN.json` 행을 “✅ 이름 폴백으로 로드 가능(단 레거시 티어)” 로,
  §7.2 결론과 §10.1-8 을 그에 맞게 정정. Q-10-01 에 “등록 해제” 선택지를 추가.

### F-04 §10.1-8 의 “6개” 가 §7.2 표(7개) 및 BP-11 G-22(7개) 와 모순

- 위치: 1202행
- 실제: `Map004/005/006/007/008/009/012` = **7개**.
- 요구 조치: 7개로 통일.

---

## 3. 중요 결함

### F-05 cm2 등록 심볼 개수가 틀렸다 (커맨드 43→40, 함수 11→12)

- 위치: §5.2(575~597행)
- 실제: `grep -c "registerCommand("` = **40**, `grep -c "registerFunction("` = **12**.
  아이러니하게도 **문서가 나열한 이름 목록 자체는 40개·12개로 정확**하다. 숫자 주석만 틀렸다.
- 파급: BP-11 G-12 가 “커맨드 43 + 함수 11” 을 그대로 재인용한다. BP-37(프롬프트 계약)이 이 숫자를
  “cm2 심볼 사전” 크기로 쓰면 그대로 전파된다.
- 요구 조치: 40 / 12 로 정정. 가능하면 “이 목록은 `grep -o "registerCommand('[^']*'"` 로 재생성 가능” 을 각주로.

### F-06 색 태그 개수가 틀렸다 (18색 → 17색)

- 위치: §8.2(1092행) — “`@0`~`@F` + `@G`(앰버), 종료 `@@`. 총 18색”
- 실제: `utils/hd_text_utils.dart:4` 의 `colorTable` 엔트리는 **17개**(`'0'`~`'F'` 16개 + `'G'` 1개).
- 파급: BP-11 G-16 이 “18색” 을 재인용.

### F-07 감사 대상에서 통째로 빠진 서브시스템 4종

문서 §1.2 의 트리에는 이름이 있으나, **책임·상태·호출 경로가 한 줄도 서술되지 않은** 것들:

| 대상 | 규모 | 문서 내 언급 | 왜 빠지면 안 되는가 |
|---|---:|---|---|
| `HDMagicSystem` (`application/magic_system.dart`) | 280줄 | §1.2 표 + §7.7 의 `spCost` 한 줄 | §3 싱글턴 지도에 **없다**. 실제로는 싱글턴이 아니라 `static castSpell(...)` 전용 클래스인데(`magic_system.dart:8~9`) 그 사실이 어디에도 없음. D-05 의 `heal_party` Effect 가 착륙할 곳 |
| `HDBattle` 전투 루프 | 538줄 | §3 상태 목록 + §7.5 보상식 + §9.6 난수 | 턴 진행·`playerCommands` 구조·`Battle::Start` 인자 의미가 없음. D-05 `start_battle`, D-06 `defeat` 목표가 여기에 붙는다 |
| `HDMenuFlows` | 544줄 | §3 “없음(전부 포트/세션 조회)” 한 칸 | D-16-1 이 **메인 메뉴에 “임무” 항목 추가**를 요구하는데, 그 메인 메뉴의 구조·항목 수·플로우가 감사에 없다. `processGameOver`/`selectLoadMenu` 는 `GameReloadException` 의 **유일한 throw 지점**(`menu_flows.dart:519`, `:536`) |
| `domain/lighting/sight_calculator.dart` (109줄) + `presentation/panels/world_map_renderer.dart` (228줄) | 337줄 | 각각 §9.1 테스트 표 1회, §1.2 트리 1회 | 야간/광원(§7.9 의 shadow z4 사분면 비트)을 **실제로 소비하는 코드**. D-05 `time_of_day` op 의 런타임 근거가 여기 |

- 요구 조치: §3 싱글턴 표에 `HDMagicSystem` 을 “싱글턴 아님 — static 전용” 으로 추가.
  §5 와 §7 사이에 “전투·마법·메뉴 유스케이스” 절을 신설해 4종의 책임·상태·진입점을 표로 정리.
  §7.9 에 shadow 레이어를 소비하는 코드 경로(`sight_calculator` → `world_map_renderer`)를 연결.

### F-08 `GameReloadException` 의 제어 흐름이 절반만 서술됐다

- 위치: §6.3(795~802행)
- 문서 주장: 클래스 선언(`game_reload_exception.dart:9`)과 “스크립트 엔진은 이 예외를 에러로 로깅하지 않고 조용히 멈춘다(`script_engine_adapter.dart:124`)”.
- 빠진 것(실측 `grep -rn "GameReloadException" lib/`):
  - **throw 지점**: `application/menu_flows.dart:519`, `:536` — 둘 다 `processGameOver` 안, `selectLoadMenu()` 성공 직후.
  - **중간 catch**: `application/battle.dart:229` — `isBattleActive=false; notifyListeners(); rethrow;`
  - 즉 흐름은 `processGameOver → throw → (battle 이 정리 후 rethrow) → script engine 이 조용히 종료` 다.
- 왜 중요한가: D-13 헤드리스 하네스는 이 예외를 **정상 종료 신호로 인식**해야 한다.
  throw 지점을 모르면 `SimDriver` 가 이것을 실패로 오분류한다.
- 요구 조치: §6.3 에 3지점(throw 2 / rethrow 1 / catch 1)을 표로.

### F-09 §7.5 각주가 부록 B-1 의 지시와 어긋난다

- 위치: 925~927행 — “본 기획서의 다른 장은 **75종**을 기준으로 삼는다.”
- 실제: `_meta/GROUND_TRUTH.md` 부록 B-1 은 **“BP-21/22/23/42 는 74종(id 1~74) 기준으로 쓸 것”** 이라고 규범적으로 지시한다.
  문서 자신이 같은 절에서 “`registerEnemy` 가 `enemyTableId <= 0` 을 거부하므로 id 0(Orc) 은 소환 불가” 라고
  써 놓고도 기준을 75로 선언해 **자기 문장과도 어긋난다.**
- 요구 조치: “테이블 엔트리 75개(id 0~74), **콘텐츠에서 참조 가능한 것은 74종(id 1~74)**” 으로 표현을 분리하고,
  후속 장 기준을 74로 명시.

### F-10 부록 B-4 의 세 문제 중 “웹 빌드 파손 가능성” 이 반영되지 않았다

- 위치: §1.4(120~132행)
- 문서 주장: `dart:io` 는 “규칙-강제 사이의 구멍” 이며 BP-11 G-26 으로 넘긴다.
- 빠진 것: `dart:io` 는 **웹에서 컴파일되지 않는다**. `deploy_web.yml` 은 수동 `workflow_dispatch` 이고
  CI 는 `flutter test`(VM) 만 돌리므로, 이 위반은 **배포 시점까지 감지되지 않는 구조**다.
  실제 `menu_flows.dart:503`/`:521`/`:539` 는 `if (!kIsWeb)` 로 런타임 가드를 걸어 두었지만,
  `import 'dart:io';` 자체는 가드 밖이므로 **런타임 가드로는 컴파일 실패를 막지 못한다.**
- 요구 조치: §1.4 또는 §9.5 에 “현재 `flutter build web` 이 성공하는지는 CI 가 검증하지 않는다” 를 명시하고
  열린 질문(실빌드 확인)으로 등록. G-26 의 심각도 재검토 근거가 된다(BP-11 리뷰 F-04 참조).

---

## 4. 개선 제안 (선택)

### S-01 §7.2 “실동작” 열을 3티어 판정 결과로 다시 계산할 것
F-01 을 반영하면 이 열은 (json 존재 여부) × (cm2 존재 여부) × (네이티브 등록 여부) 의 3차원 조합이 된다.
현재는 1차원 요약이라 정보를 잃는다. 열을 `json / cm2 / native / 선택 티어 / 관측 증상` 5칸으로 쪼개면
BP-28 이관 계획이 이 표를 그대로 입력으로 쓸 수 있다.

### S-02 인용 줄 번호에 **앵커 문자열**을 병기할 것
⚠ 판정 9건은 전부 “코드 블록의 첫 줄이 시그니처인가 본문인가” 에서 생긴 1~2줄 오차다.
`script_engine_adapter.dart:92 (loadScript)` 처럼 심볼명을 붙이면 파일이 바뀌어도 추적 가능하고,
BP-35 가 “인용 줄 번호 드리프트 검사” 를 CI 로 자동화할 때 앵커가 있어야 한다.

### S-03 §5.2 의 심볼 목록을 생성 스크립트로 대체
F-05 의 개수 오류는 손으로 센 결과다. 목록 아래에 재생성 명령
(`grep -o "registerCommand('[^']*'" ... | sed ...`)을 코드블록으로 남기면 다음 감사에서 같은 실수가 안 난다.

### S-04 `HDMapNavigation` 의 **이름 폴백 경로**를 §2.3 “LoadScript 의 두 얼굴” 에 3번째 얼굴로 추가
현재 표는 “MapInfos 에 있는 이름” / “파일명” 두 행뿐인데,
실제로는 **“MapInfos 에 없는 이름 + 같은 이름의 json 존재”** 라는 세 번째 경로가 있고 그게 ORIGIN 을 살린다(F-03).

---

## 5. 잘된 점

- **§7.1 맵 자산 표 13행이 크기·차원·이벤트 수·`code=401` 줄 수·displayName·md5 까지 전부 정확하다.**
  총계(38 이벤트 / 31 대사줄)도 재계산 결과와 일치. 이 표 하나가 “게임 전체의 정적 대사 자산은 31줄” 이라는
  BP-11 의 가장 강한 논거를 떠받친다.
- **§9.6 의 `battle.dart` 무시드 난수 14곳 줄 번호가 하나도 안 틀렸다.** 이런 목록은 보통 틀리는데 정확하다.
- §7.3 cm2 17파일 줄 수와 총계 4,056, “부팅 경로 실행분 = 134줄” 산술이 정확하다.
- §1.2 파일 규모 표 14행, §9.1 테스트 9행이 `wc -l` 과 완전 일치.
- **§8.1 이 CLAUDE.md 의 오류(“상태 패널 800×160”)를 실측으로 반박했다.** 상위 문서를 그대로 베끼지 않고
  코드를 확인한 흔적이며, 이 장에 가장 기대하던 태도다.
- §7.5 가 GROUND_TRUTH §10 의 “76종” 을 재검산해 75종으로 정정했다(각주 방향은 F-09 로 손봐야 하지만, 재검산 자체는 옳다).
- 문서 규약 준수도가 높다 — 메타 블록, `경로:줄` 형식, 표/머메이드 비중, Q-10-nn 접두사, 말미 3절 요약이 전부 있다.
- §0 에서 “추측은 ‘미확인’ 으로 표시” 라는 규약을 선언하고 실제로 8곳에서 지켰다. 미확인 표시가
  전부 주변부(레거시 cm2 도달성, 콘솔 스크롤백)에 있고 핵심 명세에는 없다 → 축 C 감점 없음.

---

## 6. 축별 근거

| 축 | 점수 | 근거 |
|---|:--:|---|
| A 사실 정확성 | **2** | 검증 87곳 중 틀린 인용 13곳, 사실 불일치 6건(F-01~F-06). 루브릭 기계검사 2 + 검수 지시(3곳 이상 → 2점 이하) 적용 |
| B 결정 정합성 | 4 | D-01 구획 선언, D-03/D-09/D-12 참조, Q-10-nn 접두사 전부 정확. 부록 B-1 의 “74종 기준” 지시와 어긋남(F-09) 으로 -1 |
| C 구현 가능성 | 4 | 현황 장의 목표(“코드를 열지 않고 재현”)를 대체로 달성. 다만 F-07 의 4종은 이 문서만으로 재현 불가 |
| D 완결성 | **2** | 부록 A-2 전면 누락(F-01), 서브시스템 4종 미서술(F-07), `GameReloadException` 흐름 절반(F-08), 부록 B-4-2 누락(F-10) |
| E 검증 가능성 | 3 | §9.1/§9.3/§9.5 로 테스트·CI 현황과 공백을 잘 정리. 다만 개별 주장에 대응하는 검증 수단은 대체로 미명시 |
| F 비중복·연결성 | 5 | 링크 22개가 전부 OUTLINE.md 계획 파일을 가리킴. 스키마 재정의 없음. “왜/어떻게” 를 BP-11/BP-20 으로 정확히 위임 |
| G 문서 규약·분량 | 5 | 1,233줄(최소 250 대비 4.9배), 메타 블록·ID 접두사·표 중심·말미 3절 전부 충족 |

---

## 7. 다른 장에 전파해야 할 발견

| 대상 | 내용 |
|---|---|
| **BP-11** | §4.5 의 “JSON 중복 출력” 을 G-07 이 재인용(11_gap_analysis.md:302). F-02 정정 시 동반 수정 필요 |
| **BP-11** | “커맨드 43 + 함수 11”(G-12)이 F-05 와 동일 오류 |
| **BP-11** | “18색”(G-16)이 F-06 과 동일 오류 |
| **BP-11 G-22** | F-03 에 따라 “MapInfos 등록 해제” 라는 더 싼 수리 선택지가 추가되어야 함 |
| **BP-27 / BP-28** | F-01(A-2 누수) 때문에 “현재 티어 판정은 신뢰할 수 없다” 가 이관 설계의 전제가 되어야 함. D-10 의 Content tier 를 얹기 전에 `loadScript` 실패 경로부터 고쳐야 순서가 맞는다 |
| **BP-34** | F-08 — `GameReloadException` 의 throw 지점이 `menu_flows.dart:519/:536` 이라는 사실이 `SimDriver` 종료 판정에 필요 |
| **BP-35** | F-10 — CI 에 `flutter build web` 이 없다는 사실이 “콘텐츠 CI” 설계의 입력 |
| **BP-21/22/23/42** | F-09 — 적 데이터 기준을 **74종(id 1~74)** 으로 통일할 것 |
| **BP-41** | F-07 — `HDMenuFlows` 의 메인 메뉴가 8줄 리스트 리터럴(`menu_flows.dart:34~43`)이라는 사실이 “임무” 항목 추가 설계의 출발점 |

---

## 8. 결정 재검토 요청

없음. 이 장은 DECISIONS.md 의 결정을 바꾸려 시도하지 않았고, D-01 구획 선언(§0)도 정확하다.

다만 **기록만 남긴다**: 부록 B-1 은 “74종 기준” 을 지시하는 반면 이 장 §7.5 는 “75종 기준” 을 선언했다.
둘 중 하나는 정정되어야 하는데, 부록이 규범이므로 **이 장이 따라야 한다**(F-09).
부록 B-1 자체에 결함이 있다고는 보지 않는다 — `battle.dart:44` 의 `<= 0` 가드를 직접 확인했고 B-1 이 옳다.

---

## 9. 재검수 체크리스트 (제작 에이전트용)

- [ ] F-01 §5.4·§7.2·§4.4 에 A-2(로드 실패 시 `clearRuntimeState` 미도달) 반영
- [ ] F-02 §4.5 의 (30,20) 중복 출력 사례 정정 또는 실제 좌표로 교체
- [ ] F-03 `ORIGIN.json` 을 “로드 가능” 으로 정정, Q-10-01 에 등록 해제 선택지 추가
- [ ] F-04 §10.1-8 “6개” → “7개”
- [ ] F-05 커맨드 40 / 함수 12 로 정정
- [ ] F-06 색 태그 17색으로 정정
- [ ] F-07 `HDMagicSystem`/`HDBattle` 루프/`HDMenuFlows`/lighting·world_map_renderer 절 신설
- [ ] F-08 `GameReloadException` throw/rethrow/catch 3지점 표 추가
- [ ] F-09 적 데이터 기준을 74종(id 1~74)으로 정정
- [ ] F-10 `flutter build web` 미검증 사실 명시
- [ ] ⚠ 9곳(15·35·46·47·49·59·61·70·72·73행 인용) 줄 번호 정정 + S-02 앵커 병기
