/*
  적 76 종을 눈으로 가르는 표.

  ## 왜 글리프 하나로는 모자란가

  적이 76 이고 칸은 44 픽셀이다. 그 크기에 알아볼 수 있게 그릴 수 있는
  선화는 스무 남짓이고, 76 개를 다 다르게 그리면 절반은 서로 구별되지
  않는 낙서가 된다.

  그래서 **둘을 겹친다.**

      모양(24 종)  무엇에 가까운가 — 사람꼴 · 짐승 · 뱀 · 벌레 · 뼈 ·
                   혼 · 용 · 돌 · 진흙 · 기계 …
      색(고유)     그 종류의 것. 같은 모양이라도 색이 다르면 갈린다

  둘을 곱하면 76 이 넉넉히 들어가고, 하나만 봐도 반은 맞힌다 — 붉은
  용과 푸른 용은 같은 모양이지만 같은 것이 아니고, 해골과 망령은 색이
  비슷해도 모양이 다르다.

  ## 같은 종류가 둘이면 번호를 붙인다

  오크 둘은 같은 모양에 같은 색이다. 그때만 왼쪽 위에 1 · 2 가 붙는다.
  늘 붙이면 혼자 있는 적에게도 「1」 이 달려 읽을 것이 하나 늘어난다.
  번호를 매기는 것은 서버다 — 같은 판에 몇이 있는지는 서버가 안다.

  ## 이름은 여기 없다

  적 이름은 `hd_battle` 의 표에서 오고 화면은 받아 적기만 한다.
*/
(function (global) {
  'use strict';

  // 모양 24. 글리프 자체는 index.html 의 sprite 에 있다.
  const S = {
    HUMANOID: 'f-humanoid',   // 사람 꼴 — 오크 · 고블린 · 드워프
    BIG: 'f-big',             // 거인 · 오우거 · 미노타우로스
    BEAST: 'f-beast',         // 네발 짐승 — 늑대 · 쥐 · 고양이
    SERPENT: 'f-serpent',     // 뱀 · 이무기 · 히드라
    WORM: 'f-worm',           // 지렁이 · 굼벵이
    BUG: 'f-bug',             // 벌레 · 거미
    BAT: 'f-bat',             // 박쥐
    BONE: 'f-bone',           // 해골 · 미라 · 썩은 시체
    SKULL: 'f-skull',         // 두개골 하나 — 데스 스컬 · 리치
    GHOST: 'f-ghost',         // 유령 · 망령
    WISP: 'f-wisp',           // 도깨비불 · 혼
    EYE: 'f-eye',             // 게이저 · 바실리스크
    SLIME: 'f-slime',         // 슬라임 · 진흙
    ROCK: 'f-rock',           // 바위 사람 · 가고일
    FLAME: 'f-flame',         // 샐러맨더 · 지옥불 · 용암
    DRAGON: 'f-dragon',       // 용 · 와이번
    WING: 'f-wing',           // 그리핀 · 드라코니안
    FAIRY: 'f-fairy',         // 스프라이트 · 임프
    KNIGHT: 'f-knight',       // 갑주 — 데스 나이트 · 블랙 나이트
    SWORD: 'f-sword',         // 춤추는 검
    SCYTHE: 'f-scythe',       // 사신 · 그림 데스
    MAGE: 'f-mage',           // 마법사 꼴 — 아키메이지 · 네크로맨서
    CRAB: 'f-crab',           // 게
    ROBO: 'f-robo',           // 기계 · 수호자
  };

  /**
   * 적 종류 → [모양, 색].
   *
   * 색은 그 종류가 무엇인지를 거든다 — 언데드는 창백하고, 불은 주황,
   * 독은 초록, 기계는 강철빛. 같은 모양 안에서는 반드시 다른 색이다.
   */
  const FOE = {
    orc:             [S.HUMANOID, '#7fae5a'],
    goblin:          [S.HUMANOID, '#9dc470'],
    kobold:          [S.HUMANOID, '#c49a5a'],
    dwarf:           [S.HUMANOID, '#c47a4a'],
    gremlin:         [S.HUMANOID, '#6fae8f'],
    headless:        [S.HUMANOID, '#8f7fae'],
    crazy_one:       [S.HUMANOID, '#d9708f'],
    devil_hunter:    [S.HUMANOID, '#d95a5a'],
    mutant:          [S.HUMANOID, '#aec45a'],
    rampager:        [S.HUMANOID, '#e08a4f'],

    troll:           [S.BIG, '#6f9e6f'],
    giant:           [S.BIG, '#c4a87a'],
    ogre:            [S.BIG, '#b0785a'],
    cyclops:         [S.BIG, '#d9b45a'],
    minotaur:        [S.BIG, '#a0522d'],
    archi_monk:      [S.BIG, '#e0c05c'],

    wolf:            [S.BEAST, '#9aa3b3'],
    giant_rat:       [S.BEAST, '#a08a6f'],
    hell_cat:        [S.BEAST, '#d9603f'],
    griffin:         [S.WING, '#d9b45a'],
    wivern:          [S.WING, '#7f9ed9'],
    draconian:       [S.WING, '#8fc46f'],
    archi_draconian: [S.WING, '#e0805c'],

    serpent:         [S.SERPENT, '#6fc78f'],
    python:          [S.SERPENT, '#8fae5a'],
    hydra:           [S.SERPENT, '#5aaec4'],
    panzer_viper:    [S.SERPENT, '#9aa3b3'],
    kelpie:          [S.SERPENT, '#5a8fd9'],
    stheno:          [S.SERPENT, '#c48fd9'],
    euryale:         [S.SERPENT, '#d98fc4'],
    medusa:          [S.SERPENT, '#8f5ad9'],

    earth_worm:      [S.WORM, '#c49a8f'],
    insects:         [S.BUG, '#8fae5a'],
    giant_spider:    [S.BUG, '#8f6fae'],
    buzz_bug:        [S.BUG, '#d9c45a'],
    crab_god:        [S.CRAB, '#e0705a'],
    blood_bat:       [S.BAT, '#c45a6f'],

    skeleton:        [S.BONE, '#d9d3c4'],
    mummy:           [S.BONE, '#c4b48f'],
    rotten_corpse:   [S.BONE, '#8fae7f'],
    death_skull:     [S.SKULL, '#e0e0e0'],
    great_lich:      [S.SKULL, '#9fd9c4'],
    ancient_evil:    [S.SKULL, '#c45ad9'],

    phantom:         [S.GHOST, '#9fc4d9'],
    ghost:           [S.GHOST, '#cfe0e8'],
    wraith:          [S.GHOST, '#7f8fae'],
    evil_soul:       [S.WISP, '#c45ad9'],
    dark_soul:       [S.WISP, '#6f5a9e'],
    wisp:            [S.WISP, '#e0d95c'],

    gazer:           [S.EYE, '#d95a9e'],
    basilisk:        [S.EYE, '#8fc45a'],

    slime:           [S.SLIME, '#6fc4ae'],
    mud_man:         [S.SLIME, '#a08a5a'],
    astral_mud:      [S.SLIME, '#8f6fd9'],

    rock_man:        [S.ROCK, '#9aa3b3'],
    gagoyle:         [S.ROCK, '#7f8f9e'],
    molten_monster:  [S.ROCK, '#e0703f'],

    salamander:      [S.FLAME, '#e08a3f'],
    hell_fire:       [S.FLAME, '#e05a3f'],
    imp:             [S.FAIRY, '#d9705a'],
    sprite:          [S.FAIRY, '#8fd9c4'],

    dragon:          [S.DRAGON, '#d9603f'],
    frost_dragon:    [S.DRAGON, '#7fc4e0'],

    dancing_swd:     [S.SWORD, '#c4cfe0'],
    death_knight:    [S.KNIGHT, '#8f7f9e'],
    black_knight:    [S.KNIGHT, '#6f7280'],
    guardian_lft:    [S.ROBO, '#8fc4d9'],
    guardian_rgt:    [S.ROBO, '#d9c48f'],
    mega_robo:       [S.ROBO, '#9aa3b3'],

    reaper:          [S.SCYTHE, '#9f8fae'],
    grim_death:      [S.SCYTHE, '#c45a5a'],
    vampire:         [S.MAGE, '#c45a7f'],
    archi_mage:      [S.MAGE, '#5a9ed9'],
    neo_necromancer: [S.MAGE, '#8f3fc4'],
    lord_ahn:        [S.MAGE, '#e0c05c'],
  };

  /** 표에 없는 적. 있으면 안 되지만 있어도 화면이 죽지는 않는다. */
  const UNKNOWN = [S.HUMANOID, '#7d8494'];

  global.FOES = {
    of(key) {
      return FOE[key] || UNKNOWN;
    },
    glyph(key) {
      return (FOE[key] || UNKNOWN)[0];
    },
    tint(key) {
      return (FOE[key] || UNKNOWN)[1];
    },
    /** 표에 빠진 것이 있는지. 시작할 때 한 번 확인한다. */
    missing(keys) {
      return keys.filter((k) => !FOE[k]);
    },
  };
})(window);
