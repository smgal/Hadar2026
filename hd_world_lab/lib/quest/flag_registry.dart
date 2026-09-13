/// 이 에피소드의 플래그 전부.
///
/// ## 어디서 왔는가
///
/// * 이름과 번호 — `hadar2026_app/assets/flag4ep1.cm2` 그대로.
///   `test/quest_registry_test.dart` 가 그 파일을 실제로 읽어 맞춰 본다.
/// * 설명 — 그 번호를 건드리는 스크립트를 읽고 적었다.
/// * `planned` 로 표시된 것 — 아직 어느 스크립트에도 없다. 기획만 있다.
///
/// ## 번호가 신원이다
///
/// `D1-010` 의 `D1` 은 사람이 읽으려고 붙인 것이고 게임은 10만 안다.
/// 그래서 **서로 다른 갈래가 같은 번호를 쓰면 같은 플래그다** — 그것이
/// 아래 `menace.cm2` 가 10번을 쓰는 일이 문제인 까닭이고,
/// [collisions] 가 찾는 것이다.
library;

import 'flag_def.dart';

/// 이름을 가진 칸 34개 + 이름 없이 쓰이는 칸 6개 + 아직 없는 칸.
const List<FlagDef> flagRegistry = [
  // ── D0 · 로어성 지하 0층 ───────────────────────────────────
  FlagDef(
    scope: 'D0',
    index: 0,
    kind: FlagKind.toggle,
    cm2Name: 'GFD0_IS_FIRST',
    title: '이 층에 처음 들어왔다',
    detail: '지하 0층에 처음 발을 들였다. 처음에만 나오는 안내를 가른다.',
    where: 'LORE 지하 0층',
    scripts: ['L1_ep1d0.cm2'],
  ),
  FlagDef(
    scope: 'D0',
    index: 1,
    kind: FlagKind.toggle,
    cm2Name: 'GFD0_GET_WALL_REMOVER',
    title: '벽을 여는 물건을 얻었다',
    detail: '지하 0층에서 벽을 없애는 물건을 손에 넣었다. 이것이 있어야 '
        '지하 1층의 이상한 벽을 열 수 있다.',
    where: 'LORE 지하 0층',
    scripts: ['L1_ep1d0.cm2'],
  ),
  FlagDef(
    scope: 'D0',
    index: 2,
    kind: FlagKind.toggle,
    cm2Name: 'GFD0_GET_KEY_FOR_D1',
    title: '지하 1층 열쇠를 얻었다',
    detail: '지하 1층으로 내려가는 문을 여는 열쇠를 얻었다.',
    where: 'LORE 지하 0층',
    scripts: ['L1_ep1d0.cm2'],
  ),
  FlagDef(
    scope: 'D0',
    index: 3,
    kind: FlagKind.toggle,
    cm2Name: 'GFD0_CHECKED_BY_GUARD',
    title: '경비의 검문을 받았다',
    detail: '경비에게 한 번 붙잡혀 조사를 받았다.',
    where: 'LORE 지하 0층',
    scripts: ['L1_ep1d0.cm2'],
  ),
  FlagDef(
    scope: 'D0',
    index: 4,
    kind: FlagKind.toggle,
    cm2Name: 'GFD0_MET_GUARD_A',
    title: '경비 A 를 만났다',
    detail: '특정 경비와 한 번 이야기했다.',
    where: 'LORE 지하 0층',
    scripts: ['L1_ep1d0.cm2'],
  ),
  FlagDef(
    scope: 'D0',
    index: 5,
    kind: FlagKind.toggle,
    cm2Name: 'GFD0_RENT_ROOM',
    title: '방을 빌렸다',
    detail: '숙소를 빌려 쉴 수 있게 되었다.',
    where: 'LORE 지하 0층',
    scripts: ['L1_ep1d0.cm2'],
  ),
  FlagDef(
    scope: 'D0',
    index: 6,
    kind: FlagKind.toggle,
    cm2Name: 'GFD0_IN_WANTED_LIST',
    title: '수배자 명단에 올랐다',
    detail: '들켜서 쫓기는 몸이 되었다. **꺼지지 않는 쪽으로 쓰이는 칸**이라 '
        '켜 놓고 시험할 때 뒤가 달라진다.',
    where: 'LORE 지하 0층',
    scripts: ['L1_ep1d0.cm2'],
  ),

  // ── D1 · 지하 1층 ─────────────────────────────────────────
  FlagDef(
    scope: 'D1',
    index: 10,
    kind: FlagKind.toggle,
    cm2Name: 'GFD1_WALL_REMOVER_USED',
    title: '벽 여는 물건을 썼다',
    detail: '지하 0층에서 얻은 물건으로 이상한 벽을 없앴다. 한 번 쓰면 사라진다.',
    where: 'LORE 지하 1층',
    scripts: ['L1_ep1d1.cm2', 'menace.cm2'],
    note: '⚠ menace.cm2 가 같은 10번을 이름 없이 쓴다. 같은 칸이다.',
  ),
  FlagDef(
    scope: 'D1',
    index: 11,
    kind: FlagKind.toggle,
    cm2Name: 'GFD1_KEY_FOR_D1_USED',
    title: '지하 1층 열쇠를 썼다',
    detail: '얻은 열쇠로 문을 열었다.',
    where: 'LORE 지하 1층',
    scripts: ['L1_ep1d1.cm2'],
  ),
  FlagDef(
    scope: 'D1',
    index: 12,
    kind: FlagKind.toggle,
    cm2Name: 'GFD1_LOOK_AT_ODD_WALL',
    title: '이상한 벽을 살펴봤다',
    detail: '여느 벽과 다른 벽이 있다는 것을 알아챘다. 여는 것은 다음 칸이다.',
    where: 'LORE 지하 1층',
    scripts: ['L1_ep1d1.cm2'],
  ),
  FlagDef(
    scope: 'D1',
    index: 13,
    kind: FlagKind.toggle,
    cm2Name: 'GFD1_OPEN_ODD_WALL',
    title: '이상한 벽을 열었다',
    detail: '벽 너머로 길이 났다.',
    where: 'LORE 지하 1층',
    scripts: ['L1_ep1d1.cm2'],
  ),
  FlagDef(
    scope: 'D1',
    index: 14,
    kind: FlagKind.toggle,
    cm2Name: 'GFD1_WORK_TRAP_BY_TRICK',
    title: '꾀를 써서 함정을 작동시켰다',
    detail: '직접 밟지 않고 함정을 터뜨렸다.',
    where: 'LORE 지하 1층',
    scripts: ['L1_ep1d1.cm2'],
  ),
  FlagDef(
    scope: 'D1',
    index: 15,
    kind: FlagKind.toggle,
    cm2Name: 'GFD1_OPEN_DOWN_STAIRS',
    title: '아래층 계단을 열었다',
    detail: '지하 2층으로 내려갈 수 있게 되었다.',
    where: 'LORE 지하 1층',
    scripts: ['L1_ep1d1.cm2'],
  ),

  // ── D2 · 지하 2층 ─────────────────────────────────────────
  FlagDef(
    scope: 'D2',
    index: 20,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_READ_MESSAGE_ABOUT_SHIELD',
    title: '방패에 대한 글을 읽었다',
    detail: '금빛 방패가 어디 있는지 알려 주는 글을 읽었다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 21,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_FIND_SECRET_PATH',
    title: '숨은 길을 찾았다',
    detail: '보이지 않던 길이 열렸다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 22,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_TAKE_GOLDED_SHIELD',
    title: '금빛 방패를 가졌다',
    detail: '한 번만 가질 수 있다. 다시 오면 자리가 비어 있다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 23,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_TAKE_USED_KEY',
    title: '쓰던 열쇠를 가졌다',
    detail: '누군가 쓰던 열쇠를 주웠다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 24,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_TAKE_SPEAR',
    title: '창을 가졌다',
    detail: '한 번만 가질 수 있다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 25,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_TAKE_ARMOR',
    title: '갑옷을 가졌다',
    detail: '한 번만 가질 수 있다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 26,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_LOOKED_AT_OBSTACLE',
    title: '막힌 것을 살펴봤다',
    detail: '길을 막은 것이 무엇인지 봤다. 당기는 것은 다음 칸이다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 27,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_PULLED_OBSTACLE',
    title: '막힌 것을 당겼다',
    detail: '길이 났다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 28,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_TAKE_SPEAR_KEY',
    title: '창 모양 열쇠를 가졌다',
    detail: '창처럼 생긴 열쇠를 얻었다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),
  FlagDef(
    scope: 'D2',
    index: 29,
    kind: FlagKind.toggle,
    cm2Name: 'GFD2_USE_SPEAR_KEY',
    title: '창 모양 열쇠를 썼다',
    detail: '그 열쇠로 열리는 것을 열었다.',
    where: 'LORE 지하 2층',
    scripts: ['L1_ep1d2.cm2'],
  ),

  // ── D3 · 지하 3층 ─────────────────────────────────────────
  FlagDef(
    scope: 'D3',
    index: 30,
    kind: FlagKind.toggle,
    cm2Name: 'GFD3_OPEN_FAST_DOOR',
    title: '빠른 문을 열었다',
    detail: '빨리 닫히는 문을 열어 두었다.',
    where: 'LORE 지하 3층',
    scripts: ['L1_ep1d3.cm2'],
  ),
  FlagDef(
    scope: 'D3',
    index: 31,
    kind: FlagKind.toggle,
    cm2Name: 'GFD3_OPEN_WEST_DOOR',
    title: '서쪽 문을 열었다',
    detail: '서쪽으로 가는 문이 열렸다.',
    where: 'LORE 지하 3층',
    scripts: ['L1_ep1d3.cm2', 'lore_ep1.cm2', 'town2.cm2'],
    note: '⚠ lore_ep1.cm2 · town2.cm2 가 같은 31번을 이름 없이 쓴다 '
        '(수련장). 같은 칸이다.',
  ),

  // ── D4 · 지하 4층 ─────────────────────────────────────────
  FlagDef(
    scope: 'D4',
    index: 40,
    kind: FlagKind.toggle,
    cm2Name: 'GFD4_FELT_STRANGE',
    title: '이상한 기운을 느꼈다',
    detail: '이 층에 들어서며 무언가 다르다는 것을 느꼈다.',
    where: 'LORE 지하 4층',
    scripts: ['L1_ep1d4.cm2'],
  ),
  FlagDef(
    scope: 'D4',
    index: 41,
    kind: FlagKind.toggle,
    cm2Name: 'GFD4_JOINNED_SOUL_OF_WATER',
    title: '물의 정령과 합류했다',
    detail: '불을 끄고 (12,16) 에 서면 스스로 빛을 내는 것이 보인다. '
        '호의를 보이면 물의 정령이 일행에 들어온다 — 여섯째 자리에 '
        '들어가고, 그 자리의 빛나는 칸은 사라진다.',
    where: 'LORE 지하 4층 (12,16)',
    scripts: ['L1_ep1d4.cm2'],
    note: '**불을 켜 두면 일어나지 않는다.** 마법의 횃불이 켜져 있으면 '
        '다른 말이 나오고 만날 수 없다.',
  ),
  FlagDef(
    scope: 'D4',
    index: 42,
    kind: FlagKind.toggle,
    cm2Name: 'GFD4_LEVER1_RIGHT',
    title: '첫째 손잡이가 오른쪽',
    detail: '벽을 미는 장치 넷 중 첫째. 넷의 조합이 길을 만든다.',
    where: 'LORE 지하 4층',
    scripts: ['L1_ep1d4.cm2'],
  ),
  FlagDef(
    scope: 'D4',
    index: 43,
    kind: FlagKind.toggle,
    cm2Name: 'GFD4_LEVER2_RIGHT',
    title: '둘째 손잡이가 오른쪽',
    detail: '벽을 미는 장치 넷 중 둘째.',
    where: 'LORE 지하 4층',
    scripts: ['L1_ep1d4.cm2'],
  ),
  FlagDef(
    scope: 'D4',
    index: 44,
    kind: FlagKind.toggle,
    cm2Name: 'GFD4_LEVER3_LEFT',
    title: '셋째 손잡이가 왼쪽',
    detail: '벽을 미는 장치 넷 중 셋째.',
    where: 'LORE 지하 4층',
    scripts: ['L1_ep1d4.cm2'],
  ),
  FlagDef(
    scope: 'D4',
    index: 45,
    kind: FlagKind.toggle,
    cm2Name: 'GFD4_LEVER4_LEFT',
    title: '넷째 손잡이가 왼쪽',
    detail: '벽을 미는 장치 넷 중 넷째.',
    where: 'LORE 지하 4층',
    scripts: ['L1_ep1d4.cm2'],
  ),
  FlagDef(
    scope: 'D4',
    index: 46,
    kind: FlagKind.toggle,
    cm2Name: 'GFD4_BLOCK_MOVED_DOWN',
    title: '돌덩이를 아래로 밀었다',
    detail: '미는 돌이 아래로 갔다.',
    where: 'LORE 지하 4층',
    scripts: ['L1_ep1d4.cm2'],
  ),
  FlagDef(
    scope: 'D4',
    index: 47,
    kind: FlagKind.toggle,
    cm2Name: 'GFD4_BLOCK_MOVED_RIGHT',
    title: '돌덩이를 오른쪽으로 밀었다',
    detail: '미는 돌이 오른쪽으로 갔다.',
    where: 'LORE 지하 4층',
    scripts: ['L1_ep1d4.cm2'],
  ),

  // ── D5 · 지하 5층 ─────────────────────────────────────────
  FlagDef(
    scope: 'D5',
    index: 50,
    kind: FlagKind.toggle,
    cm2Name: 'GFD5_PUSH_BIG_STONE',
    title: '큰 돌을 밀었다',
    detail: '길을 막던 큰 돌이 치워졌다.',
    where: 'LORE 지하 5층',
    scripts: ['L1_ep1d5.cm2', 'lore_ep1.cm2', 'town2.cm2'],
    note: '⚠ lore_ep1.cm2 · town2.cm2 가 같은 50번을 이름 없이 쓴다 '
        '(유골 안치소 (62,75)). 같은 칸이다.',
  ),

  // ── L · 로어성 · 이름 없이 번호로만 쓰인다 ─────────────────
  //
  // 아래 여섯은 `flag4ep1.cm2` 에 이름이 없다. lore_ep1.cm2 와
  // town2.cm2 가 그 파일을 include 하지 않고 숫자를 직접 쓴다.
  FlagDef(
    scope: 'L',
    index: 32,
    kind: FlagKind.toggle,
    status: FlagStatus.unnamed,
    title: '(50,86) 의 일을 겪었다',
    detail: '성의 (50,86) 에서 한 번만 일어나는 일을 겪었다. '
        '523줄이 이 칸을 다시 읽어 지도를 바꾼다.',
    where: 'LORE 성 (50,86)',
    scripts: ['lore_ep1.cm2', 'town2.cm2'],
    note: '이름이 없다. `flag4ep1.cm2` 에 상수를 만들어 두지 않으면 '
        '다음 사람이 32번에 다른 뜻을 얹는다.',
  ),
  FlagDef(
    scope: 'L',
    index: 51,
    kind: FlagKind.toggle,
    status: FlagStatus.unnamed,
    title: '피라밋 이야기를 들었다',
    detail: '성 (50,71) 에서 「이 성 바로 위의 피라밋 — 또다른 지식의 '
        '성전」 이야기를 들었다. 한 번만 나온다.',
    where: 'LORE 성 (50,71)',
    scripts: ['lore_ep1.cm2', 'town2.cm2'],
    note: '이름이 없다.',
  ),
  FlagDef(
    scope: 'L',
    index: 52,
    kind: FlagKind.toggle,
    status: FlagStatus.unnamed,
    title: '죄수에 대한 부탁을 받았다',
    detail: '죄수를 두고 무언가를 부탁받았다. 53번과 짝이다 — 52가 켜진 '
        '뒤에야 (50,11)·(51,11) 에서 53을 묻는다.',
    where: 'LORE 성',
    scripts: ['lore_ep1.cm2', 'town2.cm2'],
    note: '이름이 없다.',
  ),
  FlagDef(
    scope: 'L',
    index: 53,
    kind: FlagKind.toggle,
    status: FlagStatus.unnamed,
    title: '죄수를 풀어 주어 배신자가 되었다',
    detail: '「당신이 우리들을 배신하고 죄수를 풀어주다니」 — 켜지면 '
        '싸움이 된다. 52번이 먼저 켜져 있어야 이 갈래에 들어간다.',
    where: 'LORE 성 (50,11)·(51,11)',
    scripts: ['lore_ep1.cm2', 'town2.cm2'],
    note: '이름이 없다. **되돌릴 수 없는 갈래**다.',
  ),
  FlagDef(
    scope: 'L',
    index: 54,
    kind: FlagKind.toggle,
    status: FlagStatus.unnamed,
    title: 'Joe 를 만났다',
    detail: '(40,78) 의 죄수 Joe 와 이야기했다. 「오랜 수감생활 끝에 미쳐 '
        '버렸으니 일행에 넣지 말라」 는 경고가 먼저 있다.',
    where: 'LORE 성 (40,78) · (41,77)·(41,79)',
    scripts: ['lore_ep1.cm2', 'town2.cm2'],
    note: '이름이 없다.',
  ),
  FlagDef(
    scope: 'L',
    index: 55,
    kind: FlagKind.toggle,
    status: FlagStatus.unnamed,
    title: '그 다음 일을 겪었다',
    detail: '54번 갈래 안에서 한 번 더 갈리는 칸.',
    where: 'LORE 성',
    scripts: ['lore_ep1.cm2', 'town2.cm2'],
    note: '이름이 없다.',
  ),

  // ── W · 단계로 세는 것 ────────────────────────────────────
  FlagDef(
    scope: 'W',
    index: 10,
    kind: FlagKind.step,
    status: FlagStatus.live,
    title: 'Lord Ahn 의 이야기',
    detail: '성주 Lord Ahn 을 (50,27) 에서 만나 이야기를 듣는다. '
        '한 번 만날 때마다 한 단계 오르고, 되돌아가지 않는다.',
    where: 'LORE 성 (50,27) · 안내는 (47,30)~(53,36)',
    scripts: ['lore_ep1.cm2', 'town2.cm2'],
    steps: [
      '아직 성주를 만나지 않았다. 주위 사람들이 「성주님을 만나십시오」 라고 한다.',
      '이름을 들었다 — 「나는 Lord Ahn 이오」. 새 인물로 생을 시작한다는 말까지.',
      '세계의 내력을 들었다 — 푸른 번개, 가라앉은 대륙, LORE 특공대, Necromancer.',
      'MENACE 탐사를 의뢰받았다. 무기고에서 무기를 가져가도 좋다는 허락까지.',
      'MENACE 를 탐사하는 중. 다시 만나면 「남서쪽의 MENACE 를 탐사해 주시오」.',
      'MENACE 탐사가 끝난 뒤. **아직 안 만들었다** — 스크립트에 '
          '「## 이 부분은 MENACE 탐사가 끝나면 발생함」 만 있다.',
    ],
    note: '값 4까지만 스크립트가 올린다. 5는 자리만 있다.',
  ),

  // ── 아직 없는 것 ──────────────────────────────────────────
  //
  // 여기부터는 어느 스크립트도 쓰지 않는다. 모양을 보이려고 둔 것이고,
  // 번호는 지금 쓰이지 않는 자리에서 골랐다.
  FlagDef(
    scope: 'W',
    index: 60,
    kind: FlagKind.toggle,
    status: FlagStatus.planned,
    title: '물의 혼을 받아들여 물 위를 걷는다',
    detail: '물의 정령과 합류한 뒤(D4-041) 그 힘을 몸에 받아들인다. '
        '켜지면 **파티 전체가 물 위를 걷는다** — 마법처럼 칸 수가 '
        '줄지 않고, 부적처럼 누가 차고 있어야 하지도 않는다.',
    where: '아직 정하지 않았다',
    grants: ['walkOnWater'],
    note: '**물 위를 걷는 것의 세 번째 출처다.** 마법(칸 수) · '
        '부적(차고 있는 동안) 에 이어 시나리오(한 번 배우면 영영). '
        '활동 반경을 넓히는 것이 이 갈래의 목적이므로 앞의 둘과 달리 '
        '되돌아가지 않는다.',
  ),
  FlagDef(
    scope: 'W',
    index: 61,
    kind: FlagKind.toggle,
    status: FlagStatus.planned,
    title: '늪을 건너는 법을 배웠다',
    detail: '늪 위를 걷게 된다. W-060 과 같은 갈래의 다른 지형.',
    where: '아직 정하지 않았다',
    grants: ['walkOnSwamp'],
  ),
  FlagDef(
    scope: 'T1',
    index: 70,
    kind: FlagKind.toggle,
    status: FlagStatus.planned,
    title: '프록시마의 이름을 알게 됐다',
    detail: '로어성에서 <프록시마> 라는 사람과 이야기해 이름을 알게 됐다. '
        '켜진 뒤에는 그를 이름으로 부를 수 있다.',
    where: 'LORE 성',
    note: '보기로 둔 것이다. 아직 어느 스크립트에도 없다.',
  ),
  FlagDef(
    scope: 'W',
    index: 71,
    kind: FlagKind.step,
    status: FlagStatus.planned,
    title: '레굴루스 퀘스트',
    detail: '단계로 세는 것의 보기. 값이 3이면 1·2는 끝났고 3을 하는 중이다.',
    where: '아직 정하지 않았다',
    steps: [
      '아직 시작하지 않았다.',
      '레굴루스의 소문을 들었다.',
      '레굴루스를 만났다.',
      '레굴루스가 잃어버린 것을 찾아 달라고 했다 — 하는 중.',
      '찾아서 돌려주었다.',
    ],
    note: '보기로 둔 것이다. 아직 어느 스크립트에도 없다.',
  ),
];

/// 같은 번호를 두 갈래가 쓰는 곳.
///
/// ## 왜 이것이 필요한가
///
/// 게임이 아는 것은 번호뿐이다. `D1-010` 과 `L-010` 은 사람에게만 다르고
/// 저장된 파일에는 한 칸이다. 그래서 `menace.cm2` 가 10번을 켜면 지하
/// 1층은 벽 여는 물건을 이미 쓴 것으로 본다.
///
/// 실제로 세 군데가 그렇다 — 10 · 31 · 50. `lore_ep1.cm2` ·
/// `town2.cm2` · `menace.cm2` 가 `flag4ep1.cm2` 를 include 하지 않고
/// 번호를 직접 쓰기 때문이다.
///
/// 토글과 단계는 **다른 칸**이다(`Flag::` 와 `Variable::` 는 서로 다른
/// 배열을 본다). 그래서 `D1-010` 과 `W-010` 은 겹치지 않는다.
List<Map<String, Object?>> collisions([List<FlagDef> defs = flagRegistry]) {
  final byKey = <String, List<FlagDef>>{};
  for (final def in defs) {
    (byKey['${def.kind.name}:${def.index}'] ??= []).add(def);
  }

  final out = <Map<String, Object?>>[];
  for (final entry in byKey.entries) {
    if (entry.value.length < 2) continue;
    out.add({
      'kind': entry.value.first.kind.name,
      'index': entry.value.first.index,
      'ids': [for (final d in entry.value) d.id],
      'titles': [for (final d in entry.value) d.title],
    });
  }

  // 한 정의 안에 여러 스크립트가 적혀 있으면서 그중 하나가
  // `flag4ep1.cm2` 를 include 하지 않는 경우도 같은 위험이다.
  for (final def in defs) {
    if (def.note.startsWith('⚠')) {
      out.add({
        'kind': def.kind.name,
        'index': def.index,
        'ids': [def.id],
        'titles': [def.title],
        'note': def.note,
      });
    }
  }
  return out;
}

/// `scope` 별로 묶어 화면이 그대로 그릴 수 있는 차례.
///
/// 지하 층을 번호 순으로 먼저, 그 다음 성·마을, 마지막이 세계다.
const List<String> scopeOrder = ['D0', 'D1', 'D2', 'D3', 'D4', 'D5', 'L', 'T1', 'T2', 'M', 'W'];

const Map<String, String> scopeNames = {
  'D0': 'LORE 지하 0층',
  'D1': 'LORE 지하 1층',
  'D2': 'LORE 지하 2층',
  'D3': 'LORE 지하 3층',
  'D4': 'LORE 지하 4층',
  'D5': 'LORE 지하 5층',
  'L': 'LORE 성',
  'T1': '마을 1',
  'T2': '마을 2',
  'M': 'MENACE',
  'W': '세계 · 공용',
};
