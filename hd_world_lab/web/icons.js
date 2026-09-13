/*
  물건 하나에 글리프 하나를 고르는 표.

  ## 왜 갈래가 아니라 생김새로 고르는가

  갈래(`ItemKind`)는 **어떻게 닿는지**를 말한다 — 베다 · 찍다 · 찌르다.
  생김새(`WeaponShape`)는 **무엇인지**를 말한다 — 날 · 도끼 · 활.
  눈이 먼저 보는 것은 뒤쪽이다. 장검과 활을 같은 글리프로 두면 갈래가
  같다는 사실은 맞지만 화면은 못 쓰게 된다.

  갈래는 묶음 머리글의 점과 검색어가 말한다. 타일은 건드리지 않는다.

  ## 이름은 여기 없다

  한국어는 전부 `GET /api/text` 에서 온다. 이 파일은 키만 고른다.
*/
(function (global) {
  'use strict';

  const SHAPE_GLYPH = {
    blade: 'g-blade',
    axe: 'g-axe',
    mace: 'g-mace',
    spear: 'g-spear',
    polearm: 'g-polearm',
    lance: 'g-lance',
    staff: 'g-staff',
    knuckle: 'g-knuckle',
    bow: 'g-bow',
    crossbow: 'g-crossbow',
    arbalest: 'g-arbalest',
    thrown: 'g-thrown',
    blowpipe: 'g-blowpipe',
  };

  const KIND_GLYPH = {
    summonSingle: 'g-summon',
    summonMulti: 'g-summon',
    shield: 'g-shield',
    bodyArmour: 'g-body',
    helmet: 'g-head',
    boots: 'g-legs',
    commonAmulet: 'g-amulet',
    classAmulet: 'g-crest',
    light: 'g-light',
    consumable: 'g-flask',
  };

  /** 빈 칸에 비칠 유령. 그 자리에 무엇이 들어가는지를 미리 말한다. */
  const SLOT_GHOST = {
    rightHand: 'g-blade',
    leftHand: 'g-shield',
    head: 'g-head',
    body: 'g-body',
    legs: 'g-legs',
    commonAmulet: 'g-amulet',
    classAmulet1: 'g-crest',
    classAmulet2: 'g-crest',
  };

  /**
   * 갈래의 표식 색. **타일에는 쓰지 않는다** — 묶음 머리글의 점과
   * 검색 단추에만 쓴다. 타일의 색은 상태의 것이다.
   */
  const KIND_TINT = {
    slashWeapon: '#8fb8e8',
    chopWeapon: '#d9955c',
    pierceWeapon: '#6fc7c2',
    bluntWeapon: '#b58ae0',
    missileWeapon: '#8fc96f',
    summonSingle: '#e0c05c',
    summonMulti: '#e0c05c',
    shield: '#7d94b5',
    bodyArmour: '#9aa3b3',
    helmet: '#9aa3b3',
    boots: '#9aa3b3',
    commonAmulet: '#e08fb8',
    classAmulet: '#e06fa0',
    consumable: '#6fb8a0',
    light: '#e8a24f',
  };

  /** 가방·목록에서 묶는 순서. 손에 드는 것부터, 몸에 걸치는 것, 나머지. */
  const KIND_ORDER = [
    'slashWeapon', 'chopWeapon', 'pierceWeapon', 'bluntWeapon',
    'missileWeapon', 'summonSingle', 'summonMulti',
    'shield', 'light', 'bodyArmour', 'helmet', 'boots',
    'commonAmulet', 'classAmulet', 'consumable',
  ];

  global.ICONS = {
    KIND_TINT,
    KIND_ORDER,

    /** 물건 정의 하나에 글리프 하나. 모르는 것은 빈 원으로 둔다. */
    forItem(def) {
      if (!def) return 'g-void';
      const byKind = KIND_GLYPH[def.kind];
      if (byKind) return byKind;
      if (def.shape && SHAPE_GLYPH[def.shape]) return SHAPE_GLYPH[def.shape];
      return 'g-void';
    },

    ghostFor(slot) {
      return SLOT_GHOST[slot] || 'g-void';
    },

    /** `<svg class="ico"><use href="#…"></svg>` 한 줄. */
    svg(id, cls) {
      return '<svg class="ico ' + (cls || '') + '" viewBox="0 0 24 24">' +
             '<use href="#' + id + '"/></svg>';
    },
  };
})(window);
