/*
  장비 화면.

  ## 무엇이 어디를 말하는가

    글리프  그것이 무엇인가        — icons.js
    색      지금 그것이 어떤가      — 아래 tileState()
    이름    한국어는 GET /api/text  — 이 파일에 도메인 어휘는 없다

  ## 규칙은 여기 없다

  무엇이 어디에 들어가는지는 `checkEquip` 하나가 정하고, 그 답은
  `GET /api/eligibility` 로 통째 온다. 화면이 같은 판단을 다시 쓰면
  모델과 갈라지는 날이 오고, 그 갈라짐은 색으로만 보이므로 아무도
  눈치채지 못한다. 그래서 여기서는 **받아온 판정을 색으로 옮기기만**
  한다.

  ## 미리보기

  끼워 보고 되돌리는 대신 `POST /api/preview` 가 사본에 굴려 차이만
  돌려준다. 이 화면을 여는 이유가 "바꾸면 뭐가 달라지나" 하나이므로,
  그 답은 누르기 전에 나와야 한다.
*/
'use strict';

const $ = (id) => document.getElementById(id);
const el = (html) => {
  const t = document.createElement('template');
  t.innerHTML = html.trim();
  return t.content.firstElementChild;
};
const esc = (s) => String(s ?? '').replace(/[&<>"]/g,
  (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

// ── 받아 둔 것 ─────────────────────────────────────────────
let TEXT = null;      // 이름표 전부
let CATALOG = null;   // 물건 59
let STATE = null;     // 지금의 세계
let ELIG = null;      // 누가 · 무엇을 · 어디에 = true 또는 거절 이유
let SETS = [];        // 장비 모음
let QUEST = null;     // 플래그의 뜻과 지금 값

let DEFS = new Map(); // ref → 정의

// ── 지금 보고 있는 것 ──────────────────────────────────────
//
// 탭 넷. 앞의 셋은 **고치는** 곳이고 마지막은 **읽는** 곳이다.
// 장비는 사람에게 입히고, 가방은 무엇이 있나, 플래그는 시나리오가
// 어디까지 왔나, 기록은 그 셋을 한 장으로.
const TABS = ['gear', 'pack', 'fight', 'flags', 'record'];

const SEARCH_HINT = {
  gear: '이름/갈래, is:착용 is:겹침 is:맞는것 kind:slash -is:양손',
  pack: '이름/갈래, is:가진것 is:없는것 slot:leftHand power>40',
  fight: '적 이름으로 거른다 — 판이 열려 있으면 안 쓴다',
  flags: '이름/장소/스크립트, is:켜짐 is:단계 is:이름없음 is:미구현',
  record: '읽는 탭이다 — 거를 것이 없다',
};

let tab = 'gear';
let focusMember = null;
let focusSlot = 'rightHand';
let pick = null;      // 가방에서 집은 물건 ref
let hoverItem = null; // 지금 가리키는 물건 ref
let query = '';
let kindFilter = null;
let dragging = null;  // {from:'pack'|'slot', item, member, slot}

const t = (table, key) =>
  (TEXT && TEXT[table] && TEXT[table][key] != null) ? TEXT[table][key] : key;
const itemName = (ref) => (TEXT && TEXT.item[ref]) || ref || '';
const defOf = (ref) => DEFS.get(ref) || null;
const member = (ref) => STATE && STATE.members.find((m) => m.ref === ref);
const carried = (ref) => (ELIG && ELIG.carried[ref]) || 0;

// ── 왕복 ───────────────────────────────────────────────────
async function get(path) {
  const r = await fetch(path);
  if (!r.ok) throw new Error(path + ' → ' + r.status);
  return r.json();
}
async function post(path, body) {
  const r = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  return r.json();
}

function log(line, cls) {
  const d = document.createElement('div');
  if (cls) d.className = cls;
  d.textContent = line;
  $('log').prepend(d);
  while ($('log').childElementCount > 200) $('log').lastElementChild.remove();
}

function describeEvent(e) {
  const who = e.member ? (member(e.member)?.name ?? e.member) : '';
  switch (e.kind) {
    case 'equipped': return `${who} ${t('slot', e.slot)} ← ${itemName(e.item)}`;
    case 'unequipped': return `${who} ${t('slot', e.slot)} → 가방 (${itemName(e.item)})`;
    case 'offHandCleared': return `${who} 양손 무기라 ${itemName(e.item)}이 가방으로`;
    case 'handsSwapped': return `${who} 두 손을 바꿔 들었다`;
    case 'styleSet': return `${who} 지시 ${t('style', e.style)}${e.thrift ? ' (절약)' : ''}`;
    case 'gained': return `＋ ${itemName(e.item)} ×${e.count}`;
    case 'lost': return `－ ${itemName(e.item)} ×${e.count}`;
    case 'reordered': return '대열을 바꿨다';
    case 'refused': return `거절 — ${t('refusal', e.reason)}`;
    default: return e.kind;
  }
}

/** 명령 하나를 보내고 새 상태로 갈아 끼운다. */
async function apply(command) {
  const out = await post('/api/command', { command });
  if (out.error) { log('요청이 잘못됐다 — ' + out.error, 'no'); return out; }
  for (const e of out.events) {
    log(describeEvent(e), e.kind === 'refused' ? 'no' : 'ok');
  }
  STATE = out.state;
  ELIG = await get('/api/eligibility');
  render();
  return out;
}

// ── 색을 정하는 곳 ─────────────────────────────────────────
//
// 이 함수 하나가 화면의 모든 색을 정한다. 여섯 상태 말고는 없다.
//
//   s-empty       없다        검은 칸에 유령 글리프
//   s-equipped    차고 있다   파랑
//   s-elsewhere   남이 찼다   보라
//   s-eligible    채울 수 있다 초록
//   s-ineligible  채울 수 없다 빨강
//   s-locked      잠겼다/해당 없다  회색
//
// 회색과 빨강을 가르는 선이 요점이다. **못 채우는 것**은 빨강이고
// **물을 수조차 없는 칸**은 회색이다 — 양손 무기에 막힌 왼손, 부위가
// 아예 없는 소비품이 그렇다.

const VERDICT_DISABLED = new Set(['offHandLocked']);

function verdict(memberRef, itemRef, slot) {
  if (!ELIG) return null;
  const rows = ELIG.members[memberRef];
  if (!rows) return null;
  const row = rows[itemRef];
  if (!row) return null;
  return row[slot];
}

/** 부위 칸 하나의 상태. [상태, 설명] */
function slotState(m, s) {
  const probe = pick || hoverItem;

  if (probe && probe !== s.item) {
    const v = verdict(m.ref, probe, s.slot);
    if (v === true) return ['s-eligible', `${itemName(probe)} — 여기 채울 수 있다`];
    if (VERDICT_DISABLED.has(v)) return ['s-locked', t('refusal', v)];
    if (typeof v === 'string') return ['s-ineligible', t('refusal', v)];
  }

  if (s.locked) return ['s-locked', '양손 무기라 잠겼다'];
  if (s.item) return ['s-equipped', itemName(s.item)];
  return ['s-empty', '비어 있음'];
}

/** 가방/목록 칸 하나의 상태. */
function itemState(ref) {
  const def = defOf(ref);
  const n = carried(ref);
  const worn = (ELIG && ELIG.equippedBy[ref]) || [];

  if (worn.some((w) => w.member === focusMember)) {
    return ['s-equipped', '이 사람이 차고 있다'];
  }
  if (n === 0 && worn.length === 0) return ['s-empty', '가지고 있지 않다'];
  if (worn.length > 0 && n === 0) {
    return ['s-elsewhere', worn.map((w) => member(w.member)?.name).join(', ') + ' 착용 중'];
  }

  if (def && def.slots.length === 0) return ['s-locked', '차는 것이 아니다'];

  if (focusMember) {
    if (focusSlot) {
      const v = verdict(focusMember, ref, focusSlot);
      if (v === true) return ['s-eligible', `${t('slot', focusSlot)}에 채울 수 있다`];
      if (VERDICT_DISABLED.has(v)) return ['s-locked', t('refusal', v)];
      if (typeof v === 'string') return ['s-ineligible', t('refusal', v)];
    } else {
      const any = (def?.slots || []).some(
        (sl) => verdict(focusMember, ref, sl) === true);
      if (any) return ['s-eligible', '어딘가에 채울 수 있다'];
      return ['s-ineligible', '이 사람에게는 맞지 않는다'];
    }
  }
  return ['s-locked', ''];
}

// ── 칸 하나 그리기 ─────────────────────────────────────────
function tile(opts) {
  const b = el(
    `<button class="tile ${opts.state}${opts.selected ? ' sel' : ''}" ` +
    `title="${esc(opts.title || '')}">` +
    ICONS.svg(opts.glyph) +
    (opts.count > 1 ? `<span class="n">${opts.count}</span>` : '') +
    (opts.corner ? `<span class="p">${esc(opts.corner)}</span>` : '') +
    `</button>`);
  return b;
}

// ── 파티 기둥 ──────────────────────────────────────────────
function renderParty() {
  const box = $('party');
  box.innerHTML = '';

  for (const m of STATE.members) {
    const col = el(`<div class="col${m.ref === focusMember ? ' sel' : ''}"></div>`);

    const head = el(
      `<header><span class="who">${esc(m.name)}</span>` +
      `<span class="job">${t('class', m.class)} ${m.levels.physical}</span>` +
      `<span class="kind">${t('weaponKind', m.weaponKind)}</span></header>`);
    head.onclick = () => { focusMember = m.ref; render(); };
    col.append(head);

    const slots = el('<div class="slots"></div>');
    for (const s of m.slots) {
      const [state, why] = slotState(m, s);
      const def = s.item ? defOf(s.item) : null;
      const glyph = s.locked && !s.item
        ? 'g-lock'
        : (s.item ? ICONS.forItem(def) : ICONS.ghostFor(s.slot));

      const b = tile({
        glyph, state,
        selected: m.ref === focusMember && s.slot === focusSlot,
        title: `${t('slot', s.slot)} — ${why}`,
        corner: def && def.attackPower > 1 ? def.attackPower : null,
      });

      b.onclick = () => onSlotClick(m, s);
      b.oncontextmenu = (ev) => {
        ev.preventDefault();
        if (s.item) apply({ kind: 'unequip', member: m.ref, slot: s.slot });
      };
      // 가리키는 것만으로 고른 곳을 옮기지 않는다. 색이 상태를 말하는
      // 화면에서 마우스가 지나간 자리마다 기준이 바뀌면 무엇에 대한
      // 색인지 알 수 없게 된다.
      b.onmouseenter = () => {
        if (pick) previewEquip(m.ref, s.slot, pick);
        else if (s.item) showDetail(s.item, m.ref, s.slot);
      };

      bindDrop(b, m, s);
      if (s.item) bindDrag(b, { from: 'slot', item: s.item, member: m.ref, slot: s.slot });
      slots.append(b);
    }
    col.append(slots);

    col.append(vitals(m));
    col.append(styles(m));
    box.append(col);
  }
}

function onSlotClick(m, s) {
  focusMember = m.ref;
  focusSlot = s.slot;
  if (pick) {
    const p = pick;
    pick = null;
    apply({ kind: 'equip', member: m.ref, slot: s.slot, item: p });
    return;
  }
  if (s.item) showDetail(s.item, m.ref, s.slot);
  render();
}

function bar(label, now, max, color) {
  const pct = max > 0 ? Math.max(0, Math.min(100, (now / max) * 100)) : 0;
  return `<div class="meter"><span>${label}</span>` +
    `<span class="track"><span class="fill" style="width:${pct}%;background:${color}"></span></span>` +
    `<span class="v">${now}/${max}</span></div>`;
}

function vitals(m) {
  const v = m.vitals;
  const box = el('<div class="vit"></div>');
  box.innerHTML =
    bar('체력', v.hitPoints, v.maxHitPoints, 'var(--st-ineligible)') +
    (v.maxSpellPoints > 0
      ? bar('마법', v.spellPoints, v.maxSpellPoints, 'var(--st-equipped)') : '') +
    (v.maxEspPoints > 0
      ? bar('초능', v.espPoints, v.maxEspPoints, 'var(--st-elsewhere)') : '');
  return box;
}

function styles(m) {
  const box = el('<div class="styles"></div>');
  for (const s of CATALOG.styles) {
    if (!m.allowedStyles.includes(s.style)) continue;
    const b = el(`<button class="${m.style === s.style ? 'on' : ''}" ` +
      `title="${esc(s.hint)}">${esc(s.name)}</button>`);
    b.onclick = () => apply({ kind: 'setStyle', member: m.ref, style: s.style });
    box.append(b);
  }
  const th = el(`<button class="${m.thrift ? 'on' : ''}" ` +
    `title="마법 지수가 절반 아래면 기술을 쓰지 않는다">절약</button>`);
  th.onclick = () =>
    apply({ kind: 'setStyle', member: m.ref, style: m.style, thrift: !m.thrift });
  box.append(th);
  return box;
}

// ── 가방 격자 ──────────────────────────────────────────────
//
// 두 곳에 나온다. 장비 탭에서는 **가진 것만**, 가방 탭에서는 **전량**.
// 전량 쪽에서 안 가진 것은 검은 칸으로 남는다 — 그것이 "없음" 의 색이고,
// 무엇이 이 세계에 있는지를 보여 주는 것이 도감의 일이다.

function renderGrid(box, refs) {
  box.innerHTML = '';
  const groups = new Map();
  for (const ref of refs) {
    const def = defOf(ref);
    const k = def ? def.kind : 'consumable';
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(ref);
  }

  for (const kind of ICONS.KIND_ORDER) {
    const rows = groups.get(kind);
    if (!rows || rows.length === 0) continue;
    const g = el('<div class="group"></div>');
    g.append(el(
      `<h3><span class="dot" style="background:${ICONS.KIND_TINT[kind] || '#888'}"></span>` +
      `${t('itemKind', kind)}<span class="c">${rows.length}</span></h3>`));
    const grid = el('<div class="grid"></div>');

    rows.sort((a, b) => {
      const da = defOf(a), db = defOf(b);
      return (db?.attackPower ?? 0) - (da?.attackPower ?? 0) ||
        itemName(a).localeCompare(itemName(b), 'ko');
    });

    for (const ref of rows) grid.append(packTile(ref));
    g.append(grid);
    box.append(g);
  }

  if (box.childElementCount === 0) {
    box.append(el('<div class="note">찾는 것이 없다.</div>'));
  }
}

function packTile(ref) {
  const def = defOf(ref);
  const [state, why] = itemState(ref);
  const b = tile({
    glyph: ICONS.forItem(def),
    state,
    selected: pick === ref,
    count: carried(ref),
    corner: def && def.attackPower > 1 ? def.attackPower : null,
    title: `${itemName(ref)}${why ? ' — ' + why : ''}`,
  });

  b.onclick = (ev) => {
    if (ev.shiftKey) { apply({ kind: 'give', item: ref, count: 1 }); return; }
    if (ev.altKey) { apply({ kind: 'take', item: ref, count: 1 }); return; }
    pick = (pick === ref) ? null : ref;
    showDetail(ref);
    render();
  };
  b.oncontextmenu = (ev) => { ev.preventDefault(); apply({ kind: 'take', item: ref, count: 1 }); };
  b.onmouseenter = () => {
    hoverItem = ref;
    showDetail(ref);
    if (focusMember && focusSlot) previewEquip(focusMember, focusSlot, ref);
    paintSlotsOnly();
  };
  b.onmouseleave = () => { hoverItem = null; paintSlotsOnly(); };
  bindDrag(b, { from: 'pack', item: ref });
  return b;
}

/** 가리키기만 해도 부위 칸이 물드는 곳. 상태 전체를 다시 그리지는 않는다. */
function paintSlotsOnly() {
  if (tab !== 'gear') { renderParty(); return; }
  renderParty();
}

// ── 검색 ───────────────────────────────────────────────────
//
// DIM 의 질의어를 이 도메인으로 옮긴 것. 59개는 눈으로 훑을 수 있지만
// "지금 이 사람 왼손에 들어가는 것" 은 눈으로 못 고른다.

const IS_ALIASES = {
  착용: 'equipped', worn: 'equipped', equipped: 'equipped',
  겹침: 'dupe', dupe: 'dupe',
  양손: 'twohanded', twohanded: 'twohanded', 'two-handed': 'twohanded',
  한손: 'onehanded', onehanded: 'onehanded',
  무기: 'weapon', weapon: 'weapon',
  방어구: 'armour', armour: 'armour', armor: 'armour',
  부적: 'amulet', amulet: 'amulet',
  가진것: 'carried', carried: 'carried',
  없는것: 'missing', missing: 'missing',
  맞는것: 'fits', fits: 'fits',
};

const ARMOUR_KINDS = new Set(['shield', 'bodyArmour', 'helmet', 'boots']);
const WEAPON_KINDS = new Set(['slashWeapon', 'chopWeapon', 'pierceWeapon',
  'bluntWeapon', 'missileWeapon', 'summonSingle', 'summonMulti']);

function parseQuery(q) {
  return q.trim().toLowerCase().split(/\s+/).filter(Boolean).map((raw) => {
    const neg = raw.startsWith('-');
    const body = neg ? raw.slice(1) : raw;
    const i = body.indexOf(':');
    if (i > 0) return { neg, key: body.slice(0, i), value: body.slice(i + 1) };
    return { neg, key: 'text', value: body };
  });
}

function termMatches(ref, term) {
  const def = defOf(ref);
  const v = term.value;
  switch (term.key) {
    case 'text': {
      const hay = [
        itemName(ref), ref,
        def ? t('itemKind', def.kind) : '',
        def && def.shape ? t('shape', def.shape) : '',
      ].join(' ').toLowerCase();
      return hay.includes(v);
    }
    case 'kind': case '갈래':
      return !!def && (def.kind.toLowerCase().includes(v) ||
        t('itemKind', def.kind).toLowerCase().includes(v));
    case 'shape': case '모양':
      return !!def && !!def.shape && (def.shape.toLowerCase().includes(v) ||
        t('shape', def.shape).toLowerCase().includes(v));
    case 'slot': case '부위':
      return !!def && def.slots.some((s) => s.toLowerCase().includes(v) ||
        t('slot', s).toLowerCase().includes(v));
    case 'power': case '공격력': {
      const m = /^([<>]=?)?(\d+)$/.exec(v);
      if (!m || !def) return false;
      const n = Number(m[2]);
      switch (m[1]) {
        case '>': return def.attackPower > n;
        case '>=': return def.attackPower >= n;
        case '<': return def.attackPower < n;
        case '<=': return def.attackPower <= n;
        default: return def.attackPower === n;
      }
    }
    case 'is': {
      const what = IS_ALIASES[v] || v;
      const worn = (ELIG && ELIG.equippedBy[ref]) || [];
      switch (what) {
        case 'equipped': return worn.length > 0;
        case 'dupe': return carried(ref) > 1;
        case 'twohanded': return !!def && def.hands === 2;
        case 'onehanded': return !!def && def.hands === 1;
        case 'weapon': return !!def && WEAPON_KINDS.has(def.kind);
        case 'armour': return !!def && ARMOUR_KINDS.has(def.kind);
        case 'amulet': return !!def &&
          (def.kind === 'commonAmulet' || def.kind === 'classAmulet');
        case 'carried': return carried(ref) > 0;
        case 'missing': return carried(ref) === 0 && worn.length === 0;
        case 'fits': return !!focusMember && !!focusSlot &&
          verdict(focusMember, ref, focusSlot) === true;
        default: return false;
      }
    }
    default:
      return false;
  }
}

function filtered(refs) {
  const terms = parseQuery(query);
  return refs.filter((ref) => {
    const def = defOf(ref);
    if (kindFilter && (!def || def.kind !== kindFilter)) return false;
    return terms.every((term) => termMatches(ref, term) !== term.neg);
  });
}

// ── 오른쪽: 물건 하나 자세히 ───────────────────────────────
function showDetail(ref, forMember, forSlot) {
  const def = defOf(ref);
  const box = $('detail');
  if (!def) { box.innerHTML = '<div class="note">물건을 가리키시오.</div>'; return; }

  const n = carried(ref);
  const worn = (ELIG && ELIG.equippedBy[ref]) || [];

  const rows = [];
  if (def.attackPower > 1) rows.push(['공격력', def.attackPower]);
  for (const mod of def.modifiers) {
    rows.push([t('stat', mod.stat),
      (mod.value >= 0 ? '+' : '') + mod.value + (mod.op === 'percent' ? '%' : '')]);
  }

  const tags = [];
  tags.push(`<span class="tag">${t('itemKind', def.kind)}</span>`);
  if (def.shape) tags.push(`<span class="tag">${t('shape', def.shape)}</span>`);
  if (def.hands === 2) tags.push('<span class="tag info">양손</span>');
  if (!def.removable) tags.push('<span class="tag">벗을 수 없다</span>');
  for (const a of def.immunities) tags.push(`<span class="tag good">${t('ailment', a)} 면역</span>`);
  for (const c of def.grants) tags.push(`<span class="tag good">${t('capability', c)}</span>`);
  if (def.annexKey) tags.push(`<span class="tag">${t('annex', def.annexKey)}</span>`);
  if (def.classes) {
    tags.push(`<span class="tag">${def.classes.map((c) => t('class', c)).join(' · ')} 전용</span>`);
  }
  for (const s of def.slots) tags.push(`<span class="tag">${t('slot', s)}</span>`);

  // 사람마다 되는지 안 되는지를 한 줄로. 어느 기둥을 봐야 하는지가
  // 여기서 정해진다.
  const per = STATE.members.map((m) => {
    const fits = (def.slots || []).filter((s) => verdict(m.ref, ref, s) === true);
    const cls = fits.length ? 'good' : 'bad';
    return `<span class="tag ${cls}">${esc(m.name)}` +
      (fits.length ? ' ' + fits.map((s) => t('slot', s)).join('/') : ' ✕') + '</span>';
  }).join('');

  box.innerHTML =
    `<div class="dhead">${ICONS.svg(ICONS.forItem(def))}` +
    `<div><div class="nm">${esc(itemName(ref))}</div>` +
    `<div class="sub">${esc(ref)}</div></div></div>` +
    (rows.length ? `<div class="kv">${rows.map(([k, v]) =>
      `<div class="k">${esc(k)}</div><div class="v">${esc(v)}</div>`).join('')}</div>` : '') +
    `<div class="tags">${tags.join('')}</div>` +
    `<hr class="rule"><div class="tags">${per}</div>` +
    `<hr class="rule"><div class="kv">` +
    `<div class="k">가방</div><div class="v">${n}</div>` +
    `<div class="k">착용</div><div class="v">${worn.length}</div></div>` +
    `<div class="tags" id="detailActions"></div>`;

  const act = $('detailActions');
  const give = el('<button>＋ 하나 넣는다</button>');
  give.onclick = () => apply({ kind: 'give', item: ref, count: 1 });
  const take = el('<button>－ 하나 뺀다</button>');
  take.disabled = n === 0;
  take.onclick = () => apply({ kind: 'take', item: ref, count: 1 });
  act.append(give, take);

  if (forMember && forSlot) {
    const off = el('<button>벗는다</button>');
    off.onclick = () => apply({ kind: 'unequip', member: forMember, slot: forSlot });
    act.append(off);
  }
  if (focusMember && focusSlot && n > 0) {
    const on = el(`<button>${t('slot', focusSlot)}에 채운다</button>`);
    on.disabled = verdict(focusMember, ref, focusSlot) !== true;
    on.onclick = () =>
      apply({ kind: 'equip', member: focusMember, slot: focusSlot, item: ref });
    act.append(on);
  }
}

// ── 오른쪽: 바꾸면 뭐가 달라지나 ───────────────────────────
let previewTimer = null;
let previewKey = null;

function previewEquip(memberRef, slot, item) {
  const key = `${memberRef}|${slot}|${item}`;
  if (key === previewKey) return;
  previewKey = key;
  clearTimeout(previewTimer);
  previewTimer = setTimeout(async () => {
    const out = await post('/api/preview',
      { command: { kind: 'equip', member: memberRef, slot, item } });
    if (previewKey !== key) return; // 그 사이 다른 곳으로 갔다
    renderDiff(out, item, memberRef, slot);
  }, 90);
}

function clearPreview() {
  previewKey = null;
  clearTimeout(previewTimer);
  $('diff').hidden = true;
}

function renderDiff(out, item, memberRef, slot) {
  const box = $('diff');
  box.hidden = false;

  if (!out.ok) {
    const why = (out.refused[0] || {}).reason;
    box.innerHTML = `<h3>채우면</h3>` +
      `<div class="tag bad">${esc(t('refusal', why))}</div>`;
    return;
  }

  const parts = [];
  for (const m of out.changes.members) {
    const rows = [];
    for (const s of m.slots) {
      const from = s.from ? itemName(s.from) : '없음';
      const to = s.to ? itemName(s.to) : '없음';
      rows.push(`<div class="r"><span class="k">${t('slot', s.slot)}</span>` +
        `<span class="${s.to ? 'up' : 'dn'}">${esc(from)} → ${esc(to)}</span></div>`);
    }
    for (const c of m.changes) {
      const label = c.table ? t(c.table, c.key) : c.key;
      const numeric = typeof c.from === 'number' && typeof c.to === 'number';
      const delta = numeric ? c.to - c.from : null;
      if (numeric && delta === 0) continue;
      const show = numeric
        ? `${c.from} → ${c.to} (${delta > 0 ? '+' : ''}${delta})`
        : `${esc(fmt(c.table, c.from))} → ${esc(fmt(c.table, c.to))}`;
      const cls = numeric ? (delta > 0 ? 'up' : 'dn') : 'up';
      rows.push(`<div class="r"><span class="k">${esc(label)}</span>` +
        `<span class="${cls}">${show}</span></div>`);
    }
    for (const g of m.grantsGained) {
      rows.push(`<div class="r"><span class="k">얻는다</span>` +
        `<span class="up">${t('capability', g)}</span></div>`);
    }
    for (const g of m.grantsLost) {
      rows.push(`<div class="r"><span class="k">잃는다</span>` +
        `<span class="dn">${t('capability', g)}</span></div>`);
    }
    if (rows.length) {
      parts.push(`<div class="who">${esc(m.name)}</div>` + rows.join(''));
    }
  }

  for (const c of out.changes.party) {
    const label = c.key === 'capability'
      ? (c.to ? '파티가 얻는다' : '파티가 잃는다')
      : t('stat', c.key);
    const val = c.key === 'capability'
      ? t('capability', c.to || c.from)
      : `${fmt(null, c.from)} → ${fmt(null, c.to)}`;
    parts.push(`<div class="r"><span class="k">${esc(label)}</span>` +
      `<span class="${c.to ? 'up' : 'dn'}">${esc(val)}</span></div>`);
  }

  box.innerHTML = `<h3>${esc(itemName(item))} → ${t('slot', slot)}</h3>` +
    (parts.length
      ? `<div class="delta">${parts.join('')}</div>`
      : '<div class="note">달라지는 것이 없다.</div>');
}

function fmt(table, v) {
  if (v === true) return '있음';
  if (v === false) return '없음';
  if (v == null) return '없음';
  return table ? t(table, v) : v;
}

// ── 끌어다 놓기 ────────────────────────────────────────────
function bindDrag(node, payload) {
  node.draggable = true;
  node.ondragstart = (ev) => {
    dragging = payload;
    ev.dataTransfer.effectAllowed = 'move';
    ev.dataTransfer.setData('text/plain', payload.item);
  };
  node.ondragend = () => { dragging = null; render(); };
}

function bindDrop(node, m, s) {
  node.ondragover = (ev) => {
    if (!dragging) return;
    const v = verdict(m.ref, dragging.item, s.slot);
    if (v !== true) return;
    ev.preventDefault();
    node.classList.add('drop');
  };
  node.ondragleave = () => node.classList.remove('drop');
  node.ondrop = async (ev) => {
    ev.preventDefault();
    node.classList.remove('drop');
    if (!dragging) return;
    const d = dragging;
    dragging = null;
    // 남의 손에서 온 것은 먼저 가방을 거친다. 모델에 "옮긴다" 는 명령이
    // 없는 것은 실수가 아니라 설계다 — 가방을 거치지 않는 이동은
    // 가방이 꽉 찼을 때 물건을 없앨 수 있다.
    if (d.from === 'slot' && (d.member !== m.ref || d.slot !== s.slot)) {
      await apply({ kind: 'unequip', member: d.member, slot: d.slot });
    }
    await apply({ kind: 'equip', member: m.ref, slot: s.slot, item: d.item });
  };
}

// ── 위쪽 요약 줄 ───────────────────────────────────────────
function renderBar() {
  const p = STATE.party;
  // 통행 능력은 출처가 셋이다 — 부적(차고 있는 동안) · 마법(칸 수) ·
  // 시나리오(한 번 배우면 영영). 앞의 둘은 `hd_world` 가 답하고 셋째는
  // 플래그가 답한다. 섞어서 보이되 **어디서 왔는지는 남긴다** — ★ 가
  // 시나리오다. 왜 안 꺼지는지를 묻게 되는 자리이기 때문이다.
  const fromQuest = new Set((QUEST && QUEST.granted) || []);
  const all = [...new Set([...p.capabilities, ...fromQuest])];
  const caps = all.length
    ? all.map((c) => `<span class="pill on">${fromQuest.has(c) ? '★ ' : ''}` +
        `${t('capability', c)}</span>`).join('')
    : '<span class="pill">지형을 여는 것이 없다</span>';

  $('bar').innerHTML =
    `<span class="pill">어둠 속 시야 <b>${p.sightInDarkness}</b></span>` +
    `<span class="pill">횃불 <b>${p.lightBearers}</b></span>` +
    `<span id="magicSlot"></span>` +
    (p.moonlight ? '<span class="pill on">달빛</span>' : '') +
    caps +
    `<span class="grow"></span>` +
    `<span class="pill">가방 <b>${ELIG.packKinds}</b>/${ELIG.packCapacity} 종` +
    ` · <b>${ELIG.packUnits}</b>개</span>` +
    (tab === 'gear' && focusMember
      ? `<span class="pill">고른 곳 <b>${esc(member(focusMember)?.name ?? '')}</b>` +
        ` · ${t('slot', focusSlot)}</span>`
      : '');

  // 마법의 횃불은 머리글이 아니라 여기 있다. 이 줄에 있는 것 셋
  // (시야 · 횃불 든 사람 · 달빛)이 바로 이것이 바꾸는 값이고, 단추가
  // 저 위에 혼자 있으면 무엇을 건드리는 것인지 안 보인다.
  const magic = el(
    `<button class="pill toggle ${p.magicLight ? 'on' : ''}" ` +
    `title="손을 안 쓰는 대신 시야가 2 밖에 안 된다. 횃불은 3부터다">` +
    ICONS.svg('g-light', 'sm') + `마법의 횃불</button>`);
  magic.onclick = toggleMagicLight;
  $('magicSlot').replaceWith(magic);
}

async function toggleMagicLight() {
  const out = await post('/api/magicLight', { on: !STATE.party.magicLight });
  STATE = out.state;
  ELIG = await get('/api/eligibility');
  log('마법의 횃불을 ' + (out.magicLight ? '켰다' : '껐다') + '.', 'ok');
  render();
}

// ── 장비 모음 ──────────────────────────────────────────────
function renderLoadouts() {
  const box = $('loadouts');
  box.innerHTML = '';
  for (const l of SETS) {
    const row = el(`<div class="row"><span class="nm">${esc(l.name)}</span></div>`);
    const on = el('<button>입힌다</button>');
    on.onclick = async () => {
      const out = await post('/api/loadouts', { op: 'apply', name: l.name });
      // 거절이 있었는가와 제자리에 갔는가는 다른 물음이다 — 전원을
      // 벗기면 가방 종류 한도에 걸려 거절이 나지만, 그때 물건은
      // 원래 팔에 그대로 남아 결과는 맞는다.
      if (out.landed) {
        log(`「${l.name}」 대로 입혔다.`, 'ok');
      } else {
        log(`「${l.name}」 일부가 제자리에 못 갔다.`, 'no');
        for (const m of out.mismatch || []) {
          log(`  ${member(m.member)?.name ?? m.member} ${t('slot', m.slot)} — ` +
            `${itemName(m.wanted) || '없음'} 대신 ${itemName(m.got) || '없음'}`, 'no');
        }
      }
      STATE = out.state; ELIG = await get('/api/eligibility'); render();
    };
    const rm = el('<button class="ghost">✕</button>');
    rm.onclick = async () => {
      const out = await post('/api/loadouts', { op: 'delete', name: l.name });
      SETS = out.loadouts || []; renderLoadouts();
    };
    row.append(on, rm);
    box.append(row);
  }
  const add = el('<button>지금 것을 담아 둔다</button>');
  add.onclick = async () => {
    const name = prompt('이 구성의 이름은?', '구성 ' + (SETS.length + 1));
    if (!name) return;
    const out = await post('/api/loadouts', { op: 'capture', name });
    SETS = out.loadouts || [];
    log(`「${name}」 으로 담았다.`, 'ok');
    renderLoadouts();
  };
  box.append(add);
}

// 범례도 탭을 따라간다. 같은 색이 두 탭에서 다른 것을 뜻하므로
// (파랑이 장비에서는 「차고 있다」 이고 단계에서는 「끝났다」)
// 한 벌로 합치면 둘 다 흐려진다.
const LEGENDS = {
  fight: ['격자가 말하는 것', [
    ['var(--st-equipped)', '지금 고르고 있는 사람'],
    ['var(--st-eligible)', '누를 수 있다 — 이 물음의 답'],
    ['var(--st-locked)', '쓰러졌다'],
    ['#e0a94f', '아이콘 색은 적의 **종류**다. 상태가 아니다'],
  ], 'y 축이 거리다. 아군 줄에서 적 줄까지 줄을 세면 그것이 사거리와 견주는 값'],

  gear: ['색이 말하는 것', [
    ['var(--dim2)', '없다 — 가지고 있지 않거나 빈 칸'],
    ['var(--st-equipped)', '차고 있다'],
    ['var(--st-elsewhere)', '다른 사람이 차고 있다'],
    ['var(--st-eligible)', '채울 수 있다'],
    ['var(--st-ineligible)', '채울 수 없다 — 까닭은 칸에'],
    ['var(--st-locked)', '잠겼다 · 차는 것이 아니다'],
  ], '가방 칸: 누르면 집는다 · Shift 넣기 · Alt 빼기 · 오른쪽 단추로 벗기기'],

  flags: ['플래그가 말하는 것', [
    ['var(--st-equipped)', '켜져 있다 · 끝난 단계'],
    ['var(--st-eligible)', '지금 하는 중인 단계'],
    ['var(--dim2)', '아직 — 꺼졌거나 오지 않은 단계'],
    ['var(--st-ineligible)', '이름 없음 — cm2 가 번호로만 쓴다'],
    ['var(--st-locked)', '아직 없음 — 어느 스크립트도 안 쓴다'],
  ], '단계 줄을 누르면 거기로 옮긴다. 켜고 끄는 것은 오른쪽 스위치'],
};

function renderLegend() {
  const spec = LEGENDS[tab];
  if (!spec) return;
  const [title, rows, hint] = spec;
  $('legendTitle').textContent = title;
  $('legend').innerHTML = rows.map(([c, text]) =>
    `<div class="r"><span class="sw" style="color:${c};background:${c}22"></span>` +
    `${esc(text)}</div>`).join('') +
    `<div class="r" style="margin-top:4px">${esc(hint)}</div>`;
}

/// 오른쪽 기둥에서 이 탭이 쓰지 않는 칸을 접는다.
function syncSide() {
  for (const card of $('side').children) {
    const forTabs = card.dataset.for;
    if (!forTabs) continue;              // 늘 보이는 것
    const wanted = forTabs.split(' ').includes(tab);
    card.classList.toggle('off', !wanted);
    // `#diff` 는 스스로 접히기도 한다. 그쪽 뜻을 덮지 않는다.
    if (!wanted) card.hidden = true;
    else if (card.id !== 'diff') card.hidden = false;
  }
}

// ── 가방 탭 ────────────────────────────────────────────────
function renderPackTab() {
  const box = $('packFull');
  box.innerHTML = '';

  const chips = el('<div class="packbar"></div>');
  const allChip = el(`<button class="chip${kindFilter ? '' : ' on'}">전부</button>`);
  allChip.onclick = () => { kindFilter = null; render(); };
  chips.append(allChip);
  for (const kind of ICONS.KIND_ORDER) {
    const c = el(`<button class="chip${kindFilter === kind ? ' on' : ''}">` +
      `${t('itemKind', kind)}</button>`);
    c.onclick = () => { kindFilter = kindFilter === kind ? null : kind; render(); };
    chips.append(c);
  }
  box.append(chips);

  const grid = el('<div></div>');
  renderGrid(grid, filtered(CATALOG.items.map((i) => i.ref)));
  box.append(grid);
}

// ── 전투 탭 ────────────────────────────────────────────────
//
// ## 격자가 규칙이다
//
// B5 의 위치는 좌표가 아니라 **각자의 열(1~3)과 양측 공통의 간격(0~2)**
// 이고, 거리는 `gap + (내 열-1) + (상대 열-1)` 이다. 그 식을 읽게 하는
// 대신 그리기로 했다 — y 축을 거리로 두면 아군 줄에서 적 줄까지 **줄을
// 세는 것**이 곧 거리다.
//
//     적 3열  ← 멀다
//     적 2열
//     적 1열
//     ┄ 간격 ┄   gap 만큼
//     아군 1열
//     아군 2열
//     아군 3열  ← 뒤
//
// 간격이 줄면 줄이 빠지고 모두가 가까워진다. 「우리가 나아간다」 와
// 「그들이 다가온다」 가 같은 사건인 것이 눈으로 보인다.
//
// ## 색은 여기서도 상태다
//
// 적 아이콘의 색만 다르다 — 종류를 말하는 고유색이다(`foes.js`). 칸의
// 테두리가 상태를 말하는 것은 장비 탭과 같다: 고를 수 있으면 초록,
// 지금 묻고 있는 사람은 파랑, 쓰러진 것은 회색.

// 원작 16색 팔레트(부록 V). `hd_battle_text` 는 번호만 주고 그리는 것은
// 읽는 쪽의 일이라고 못박아 두었다 — 콘솔의 `palette.dart` 가 같은 표를
// 자기 몫으로 갖는다.
const PALETTE = [
  '#000000', '#3a56c8', '#2f9e4f', '#2f9e9e',
  '#c03a3a', '#a03aa0', '#a07a2f', '#b0b6c0',
  '#6a7180', '#6f9bff', '#5fe07f', '#5fe0e0',
  '#ff6f6f', '#ff7fe0', '#ffe05f', '#ffffff',
];
const paletteColor = (i) => PALETTE[i] ?? 'var(--ink)';

/** `@C…@@` 표기를 그린다. 원작 파서와 같게 — `@@` 는 기본색 복귀다. */
function paintHtml(text, base) {
  if (text == null) return '';
  let out = '', color = base || null, i = 0;
  while (i < text.length) {
    if (text[i] === '@' && i + 1 < text.length) {
      const c = text[i + 1];
      if (c === '@') {
        if (color !== null) out += '</span>';
        color = base || null;
        if (color !== null) out += `<span style="color:${color}">`;
        i += 2; continue;
      }
      const n = c >= '0' && c <= '9' ? c.charCodeAt(0) - 48
        : (c >= 'A' && c <= 'F' ? c.charCodeAt(0) - 55 : -1);
      if (n >= 0) {
        if (color !== null) out += '</span>';
        color = paletteColor(n);
        out += `<span style="color:${color}">`;
        i += 2; continue;
      }
    }
    out += esc(text[i]); i += 1;
  }
  if (color !== null) out += '</span>';
  return out;
}
const plain = (text) => String(text ?? '').replace(/@[0-9A-F@]/g, '');

let FIGHT = null;     // 지금 열려 있는 판
let ROSTER = null;    // 적 76
// 간격 0 으로 연다. 모델이 「0 이나 1 로 시작하고 2 는 먼저 발견했을
// 때」 라고 적어 두었고, 0 이 붙어서 시작하는 보통의 조우다. 1 로 열면
// 사거리 1 짜리가 겨우 닿는 자리에서 시작해 무엇이 규칙이고 무엇이
// 우연인지 가려진다.
let setup = { keys: ['orc', 'orc', 'wolf'], gap: 0, seed: 7 };

async function fightPost(path, body) {
  const out = await post('/api/battle/' + path, body || {});
  if (out.error) log('전투 — ' + out.error, 'no');
  if (out.open !== undefined) FIGHT = out;
  return out;
}

function unitTile(opts) {
  const b = el(
    `<button class="unit ${opts.state}" title="${esc(opts.title || '')}">` +
    `<svg class="ico" viewBox="0 0 24 24" style="color:${opts.tint}">` +
    `<use href="#${opts.glyph}"/></svg>` +
    (opts.ordinal ? `<span class="ord">${opts.ordinal}</span>` : '') +
    `<span class="nm" style="color:${opts.nameColor}">${esc(opts.name)}</span>` +
    `<span class="hpbar"><span style="width:${opts.hpPct}%;` +
    `background:${opts.hpColor}"></span></span>` +
    (opts.foot ? `<span class="ft">${opts.foot}</span>` : '') +
    `</button>`);
  if (opts.onClick) b.onclick = opts.onClick;
  else b.disabled = true;
  return b;
}

/**
 * 한 줄(열) 을 그린다.
 *
 * 왼쪽 난간이 **거리를 숫자로** 말한다. 줄을 세게 하지 않는 것은 빈
 * 열이 땅처럼 읽히기 때문이다 — 적이 전부 1열에 있어도 위의 두 줄이
 * 거리처럼 보인다. 그래서 빈 줄은 실선 하나로 접고 숫자를 적는다.
 */
function rankRow(label, units, cls, note) {
  const row = el(`<div class="grow-row ${cls || ''}"></div>`);
  row.append(el(`<span class="rl">${esc(label)}` +
    (note ? `<b>${esc(note)}</b>` : '') + `</span>`));
  const cells = el('<div class="cells"></div>');
  for (const u of units) cells.append(u);
  row.append(cells);
  return row;
}

function renderFight() {
  const box = $('fightBoard');
  box.innerHTML = '';

  if (!FIGHT || !FIGHT.open) { box.append(encounterCard()); return; }

  const d = FIGHT.decision;
  const enemyPick = d && d.kind === 'enemy' ? new Set(d.enemyIndices) : null;
  const allyPick = d && d.kind === 'ally' ? new Set(d.slots) : null;

  // ── 머리줄
  const head = el('<div class="fbar"></div>');
  head.innerHTML =
    `<span class="pill">${FIGHT.round} 라운드</span>` +
    `<span class="pill">간격 <b>${FIGHT.gap}</b>/${FIGHT.maxGap}</span>` +
    `<span class="pill">씨앗 <b>${FIGHT.seed}</b></span>` +
    (FIGHT.finished
      ? `<span class="pill ${FIGHT.result === 'win' ? 'on' : 'warn'}">` +
        `${{ win: '이겼다', lose: '전멸했다', escape: '도망쳤다' }[FIGHT.result] || FIGHT.result}</span>`
      : '');
  head.append(el('<span class="grow"></span>'));
  if (FIGHT.finished && !FIGHT.settled) {
    const s = el('<button>결과를 파티에 얹는다</button>');
    s.onclick = async () => {
      const out = await post('/api/battle/settle');
      if (out.error) { log('정산 — ' + out.error, 'no'); return; }
      for (const m of out.members) {
        const dmg = m.hitPointsBefore - m.hitPointsAfter;
        log(`  ${m.name} 체력 ${m.hitPointsBefore}→${m.hitPointsAfter}` +
          (dmg > 0 ? ` (−${dmg})` : '') +
          (m.experience ? ` · 경험치 +${m.experience}` : ''), 'ok');
      }
      STATE = out.state;
      ELIG = await get('/api/eligibility');
      FIGHT = (await fightPost('state')) || FIGHT;
      FIGHT = await get('/api/battle/state');
      render();
    };
    head.append(s);
  }
  const quit = el('<button class="ghost">판을 접는다</button>');
  quit.onclick = async () => { await fightPost('abandon'); render(); };
  head.append(quit);
  box.append(head);

  // ── 격자
  const grid = el('<div class="grid-field"></div>');

  // 거리는 **누구에게서인지**가 있어야 뜻이 된다. 지금 묻고 있는 사람이
  // 기준이고, 그 사람이 몇 열에서 얼마나 닿는지를 먼저 못박는다 —
  // 이것 없이 적 칸에 「거리 3」 만 적히면 1열에서 1열이 3인 줄 안다.
  const asker = FIGHT.party.find((c) => c.asking) || null;
  if (asker) {
    grid.append(el(
      `<div class="asker-note">` +
      `<b>${esc(asker.name)}</b> 기준 — ${asker.rank}열 · 사거리 ` +
      `<b>${asker.reach}</b>. 아래 거리는 전부 이 사람에게서 잰 것이다.` +
      `</div>`));
  }

  for (let rank = 3; rank >= 1; rank--) {
    const here = FIGHT.enemies.filter((e) => e.rank === rank);
    const dist = asker ? FIGHT.gap + (asker.rank - 1) + (rank - 1) : null;
    const units = here
      .map((e) => {
        const [glyph, tint] = FOES.of(e.key);
        const pickable = enemyPick && enemyPick.has(e.index);
        return unitTile({
          glyph,
          tint: e.conscious ? tint : 'var(--st-locked)',
          state: !e.conscious ? 'down' : (pickable ? 'pick' : ''),
          ordinal: e.ordinal,
          name: e.name,
          nameColor: paletteColor(e.colorIndex),
          hpPct: 100,
          hpColor: paletteColor(e.colorIndex),
          foot: e.hp > 0 ? `체력 ${e.hp}` : '쓰러짐',
          title: `${e.name} — 체력 ${e.hp} · ${rank}열` +
            (e.distance != null ? ` · 거리 ${e.distance} · ${plain(e.reachVerdict)}` : ''),
          onClick: pickable
            ? () => sendFight({ type: 'target', slot: d.slot, enemyIndex: e.index })
            : null,
        });
      });
    // 닿는 줄과 안 닿는 줄을 줄 단위로 가른다. 「왜 못 때리지」 의 답이
    // 칸 하나가 아니라 **줄 하나**이기 때문이다 — 같은 열은 다 같다.
    const inReach = asker && dist != null && dist <= asker.reach;
    const row = rankRow(
      `적 ${rank}열`,
      units,
      'foe' + (here.length ? '' : ' empty') +
        (dist == null ? '' : (inReach ? ' reach' : ' far')),
      dist == null ? null : ` 거리 ${dist}`,
    );
    if (dist != null && here.length) {
      row.append(el(`<span class="verdict ${inReach ? 'ok' : 'no'}">` +
        (inReach ? '닿는다' : `${dist - asker.reach}칸 부족`) + `</span>`));
    }
    grid.append(row);
  }

  // 간격 — 줄 수가 곧 간격이다. 0 이면 두 줄이 맞붙는다.
  for (let i = 0; i < FIGHT.gap; i++) {
    grid.append(el('<div class="gap-row"><span class="rl">' +
      (i === 0 ? `간격 ${FIGHT.gap}` : '') + '</span>' +
      '<div class="cells"><span class="gapline"></span></div></div>'));
  }

  for (let rank = 1; rank <= 3; rank++) {
    const here = FIGHT.party.filter((c) => c.rank === rank);
    const units = here
      .map((c) => {
        const pickable = allyPick && allyPick.has(c.slot);
        const pct = c.maxHp > 0 ? Math.max(0, (c.hp / c.maxHp) * 100) : 0;
        return unitTile({
          glyph: 'g-blade',
          tint: c.asking ? 'var(--st-equipped)'
            : (c.conscious ? 'var(--ink)' : 'var(--st-locked)'),
          state: !c.conscious ? 'down'
            : (pickable ? 'pick' : (c.asking ? 'asking' : '')),
          name: c.name,
          nameColor: paletteColor(c.colorIndex),
          hpPct: pct,
          hpColor: pct > 50 ? 'var(--st-eligible)'
            : (pct > 20 ? '#e0a94f' : 'var(--st-ineligible)'),
          foot: `${c.hp}/${c.maxHp}` + (c.braced ? ' 🛡' : '') +
            (c.staggered ? ' ↯' : ''),
          title: `${c.name} — ${rank}열 · 사거리 ${c.reach}` +
            (c.coatings.length
              ? ' · ' + c.coatings.map((x) => `${x.kind} ${x.rounds}`).join(', ')
              : ''),
          onClick: pickable
            ? () => sendFight({ type: 'ally', slot: d.slot, allySlot: c.slot })
            : null,
        });
      });
    grid.append(rankRow(
      `아군 ${rank}열`,
      units,
      'ally' + (here.length ? '' : ' empty') +
        (asker && asker.rank === rank ? ' asker' : ''),
    ));
  }
  box.append(grid);

  // ── 무엇을 묻고 있나
  box.append(decisionCard(d));

  // ── 일어난 일
  const logCard = el('<div class="card"><h3>이 판에 일어난 일</h3>' +
    '<div class="blog"></div></div>');
  const lines = logCard.querySelector('.blog');
  for (const line of FIGHT.log.slice(-60).reverse()) {
    lines.insertAdjacentHTML('beforeend',
      `<div>${paintHtml(line, PALETTE[7])}</div>`);
  }
  box.append(logCard);
}

async function sendFight(command) {
  await fightPost('command', { command });
  render();
}

function decisionCard(d) {
  const card = el('<div class="card hi"></div>');
  if (!d) {
    card.className = 'card';
    card.innerHTML = FIGHT.finished
      ? '<h3>끝났다</h3><div class="note">위의 단추로 결과를 파티에 얹는다.</div>'
      : '<h3>굴리는 중</h3>';
    return card;
  }

  card.append(el(`<h3>${esc(d.who)} — ${DECISION_HEAD[d.kind] || d.kind}</h3>`));

  if (d.kind === 'enemy' || d.kind === 'ally') {
    card.append(el(`<div class="note">${d.kind === 'enemy'
      ? '위 격자에서 <b>초록 테두리</b>가 난 적을 누르시오.'
      : '아래 격자에서 <b>초록 테두리</b>가 난 사람을 누르시오.'}</div>`));
  } else {
    const list = el('<div class="choices"></div>');
    for (const o of d.options || []) {
      const b = el(`<button class="choice">${paintHtml(o.label, null)}</button>`);
      if (o.affordable === false) b.classList.add('poor');
      b.onclick = () => sendFight(
        d.kind === 'action' || d.kind === 'order'
          ? { type: 'action', slot: d.slot, action: o.action }
          : d.kind === 'spell'
            ? { type: 'spell', slot: d.slot, magicId: o.magicId }
            : d.kind === 'item'
              ? { type: 'item', slot: d.slot, itemKey: o.itemKey }
              : { type: 'itemUse', slot: d.slot, use: o.use });
      list.append(b);
    }
    card.append(list);
  }

  const cancel = el(`<button class="ghost" style="margin-top:7px">` +
    `${esc(d.cancelLabel)}</button>`);
  cancel.onclick = () => sendFight({ type: 'cancel', slot: d.slot });
  card.append(cancel);
  return card;
}

const DECISION_HEAD = {
  action: '무엇을 할까',
  order: '어떤 지시를',
  enemy: '누구를 칠까',
  ally: '누구에게',
  spell: '어떤 기술을',
  item: '무엇을 쓸까',
  itemUse: '어떻게 쓸까',
};

/** 판을 짜는 곳. 적을 고르고 열과 간격을 정한다. */
function encounterCard() {
  const card = el('<div class="card"></div>');
  card.append(el('<h3>판을 짠다</h3>'));

  const chosen = el('<div class="chosen"></div>');
  const redraw = () => {
    chosen.innerHTML = '';
    if (!setup.keys.length) {
      chosen.append(el('<span class="note">적을 고르시오.</span>'));
    }
    setup.keys.forEach((key, i) => {
      const [glyph, tint] = FOES.of(key);
      const name = (ROSTER.find((r) => r.key === key) || {}).name || key;
      const b = el(`<button class="foechip" title="빼려면 누르시오">` +
        `<svg class="ico sm" viewBox="0 0 24 24" style="color:${tint}">` +
        `<use href="#${glyph}"/></svg>${esc(name)}</button>`);
      b.onclick = () => { setup.keys.splice(i, 1); redraw(); };
      chosen.append(b);
    });
  };
  card.append(chosen);

  const row = el('<div class="packbar" style="margin-top:8px"></div>');
  row.innerHTML =
    `<label class="note" title="0 붙어서 · 1 한 칸 · 2 먼저 발견했을 때">` +
    `간격 <input id="fGap" type="number" min="0" max="2" ` +
    `value="${setup.gap}" style="width:46px"></label>` +
    `<label class="note">씨앗 <input id="fSeed" type="number" ` +
    `value="${setup.seed}" style="width:80px"></label>`;
  const go = el('<button>싸운다</button>');
  go.onclick = async () => {
    setup.gap = Number($('fGap').value);
    setup.seed = Number($('fSeed').value);
    if (!setup.keys.length) { log('적이 없다.', 'no'); return; }
    await fightPost('start', {
      enemyKeys: setup.keys, initialGap: setup.gap, seed: setup.seed,
    });
    render();
  };
  const rnd = el('<button class="ghost">씨앗을 바꾼다</button>');
  rnd.onclick = () => { $('fSeed').value = Date.now() % 100000; };
  // 판단이 필요 없을 때의 길. 전부 「가장 가까운 것을 친다」 로 답하고
  // 끝을 본다 — 장비가 낸 숫자만 보고 싶을 때 쓴다.
  const auto = el('<button class="ghost" title="전부 가장 가까운 것을 친다">' +
    '자동으로 끝까지</button>');
  auto.onclick = async () => {
    setup.gap = Number($('fGap').value);
    setup.seed = Number($('fSeed').value);
    if (!setup.keys.length) { log('적이 없다.', 'no'); return; }
    await autoFight();
  };
  row.append(go, rnd, auto);
  card.append(row);

  // 적 76 — 눌러서 담는다
  const pickBox = el('<div style="margin-top:10px"></div>');
  pickBox.append(el('<h3>적 ' + ROSTER.length + '종</h3>'));
  const grid = el('<div class="foegrid"></div>');
  for (const r of ROSTER) {
    if (query.trim() && !(`${r.key} ${r.name}`.toLowerCase()
      .includes(query.trim().toLowerCase()))) continue;
    const [glyph, tint] = FOES.of(r.key);
    const b = el(`<button class="foepick" title="Lv ${r.level} · ${esc(r.key)}">` +
      `<svg class="ico" viewBox="0 0 24 24" style="color:${tint}">` +
      `<use href="#${glyph}"/></svg>` +
      `<span class="fn">${esc(r.name)}</span>` +
      `<span class="fl">${r.level}</span></button>`);
    b.onclick = () => {
      if (setup.keys.length >= 8) { log('여덟이 넘는다.', 'no'); return; }
      setup.keys.push(r.key);
      redraw();
    };
    grid.append(b);
  }
  pickBox.append(grid);
  card.append(pickBox);
  redraw();
  return card;
}

// ── 플래그 탭 — 시나리오 판 ────────────────────────────────
//
// 칸 하나가 플래그 하나다. **날값과 사람 말이 늘 같이** 나온다 —
// `Flag::IsSet(41) = 1` 만 보면 고칠 수 있어도 뜻을 모르고, 「물의
// 정령과 합류했다」만 보면 무엇을 고치는지 모른다.
//
// 갈래가 둘인 것은 원작이 그렇기 때문이다. 켜짐/꺼짐은 `Flag::` 이고,
// 몇 번째 단계인지는 `Variable::` 이다. 값 3 이 1·2 를 끝냈다는 뜻까지
// 담으므로 켜짐 셋으로 쪼개지 않는다.

const STATUS_LABEL = {
  live: ['', '스크립트가 쓴다'],
  unnamed: ['이름 없음', 'cm2 가 번호로만 쓴다 — flag4ep1.cm2 에 상수가 없다'],
  planned: ['아직 없음', '어느 스크립트도 쓰지 않는다. 기획만 있다'],
};

async function setFlag(body) {
  const out = await post('/api/quest', body);
  if (out.error) { log('플래그를 못 바꿨다 — ' + out.error, 'no'); return; }
  QUEST = out;
  render();
}

function flagMatches(f) {
  if (!query.trim()) return true;
  const hay = [f.id, f.title, f.detail, f.cm2Name, f.where,
    f.note, (f.scripts || []).join(' '), f.status,
    ...(f.steps || [])].join(' ').toLowerCase();
  return parseQuery(query).every((term) => {
    if (term.key === 'is') {
      const v = { 켜짐: 'on', on: 'on', 꺼짐: 'off', off: 'off',
        단계: 'step', step: 'step', 이름없음: 'unnamed', unnamed: 'unnamed',
        미구현: 'planned', planned: 'planned' }[term.value] || term.value;
      const hit = v === 'on' ? f.on
        : v === 'off' ? !f.on
        : v === 'step' ? f.kind === 'step'
        : f.status === v;
      return hit !== term.neg;
    }
    return hay.includes(term.value) !== term.neg;
  });
}

function stepRow(f) {
  const box = el('<div class="steps"></div>');
  f.steps.forEach((text, i) => {
    const state = f.stepStates[i];
    const row = el(
      `<button class="step ${state}">` +
      `<span class="i">${i}</span>` +
      `<span class="tx">${esc(text)}</span></button>`);
    row.title = `여기로 옮긴다 — Variable::Set(${f.index}, ${i})`;
    row.onclick = () => setFlag({ id: f.id, kind: 'step', value: i });
    box.append(row);
  });
  return box;
}

function flagCard(f) {
  const card = el(`<div class="flag ${f.on ? 'on' : ''} st-${f.status}"></div>`);

  const head = el('<div class="fhead"></div>');
  head.innerHTML =
    `<code class="fid">${esc(f.id)}</code>` +
    `<span class="ftitle">${esc(f.title)}</span>` +
    (STATUS_LABEL[f.status][0]
      ? `<span class="tag ${f.status === 'unnamed' ? 'bad' : ''}" ` +
        `title="${esc(STATUS_LABEL[f.status][1])}">` +
        `${STATUS_LABEL[f.status][0]}</span>` : '') +
    (f.kind === 'step' ? '<span class="tag info">단계</span>' : '');

  // 켜고 끄는 것. 단계짜리는 아래 목록에서 옮긴다.
  if (f.kind === 'toggle') {
    const sw = el(`<button class="sw ${f.on ? 'on' : ''}">` +
      `<span class="knob"></span></button>`);
    sw.title = f.on ? `끈다 — Flag::Reset(${f.index})`
                    : `켠다 — Flag::Set(${f.index})`;
    sw.onclick = () => setFlag({ id: f.id, on: !f.on });
    head.append(sw);
  } else {
    const n = el(`<span class="fval">${f.value} / ${f.stepCount - 1}</span>`);
    head.append(n);
  }
  card.append(head);

  // 날값은 늘 보인다. 접어 두면 아무도 안 편다.
  card.append(el(`<code class="raw">${esc(f.raw)}` +
    (f.cm2Name ? `   <span class="cm2">${esc(f.cm2Name)}</span>` : '') +
    `</code>`));

  card.append(el(`<div class="fdetail">${esc(f.detail)}</div>`));

  if (f.kind === 'step') card.append(stepRow(f));

  const tags = [];
  if (f.where) tags.push(`<span class="tag">${esc(f.where)}</span>`);
  for (const g of f.grants) {
    tags.push(`<span class="tag good">열어 준다 — ${t('capability', g)}</span>`);
  }
  for (const s of f.scripts) tags.push(`<span class="tag">${esc(s)}</span>`);
  if (tags.length) card.append(el(`<div class="tags">${tags.join('')}</div>`));

  if (f.note) {
    card.append(el(`<div class="fnote${f.note.startsWith('⚠') ? ' warn' : ''}">` +
      `${esc(f.note)}</div>`));
  }
  return card;
}

function renderFlags() {
  const box = $('flags');
  box.innerHTML = '';
  if (!QUEST) { box.append(el('<div class="note">읽는 중.</div>')); return; }

  const s = QUEST.summary;

  // ── 머리: 이 세계가 어디까지 왔나
  const top = el('<div class="card"></div>');
  top.innerHTML =
    `<h3>시나리오</h3>` +
    `<div class="bar" style="padding:0;background:none;border:none">` +
    `<span class="pill">켜짐 <b>${s.on}</b>/${s.total}</span>` +
    `<span class="pill">스크립트가 쓴다 <b>${s.live}</b></span>` +
    `<span class="pill${s.unnamed ? ' warn' : ''}">이름 없음 <b>${s.unnamed}</b></span>` +
    `<span class="pill">아직 없음 <b>${s.planned}</b></span>` +
    `</div>`;
  const off = el('<button style="margin-top:8px">전부 끈다</button>');
  off.onclick = () => setFlag({ op: 'reset' });
  top.append(off);
  box.append(top);

  // ── 시나리오가 연 것. 이것이 플래그가 세계에 닿는 자리다.
  const caps = el('<div class="card"></div>');
  caps.innerHTML = `<h3>시나리오가 연 통행 능력</h3>` +
    (QUEST.granted.length
      ? `<div class="tags">${QUEST.granted.map((c) =>
          `<span class="tag good">${t('capability', c)}</span>`).join('')}</div>` +
        `<div class="note" style="margin-top:6px">부적·마법과 달리 ` +
        `<b>꺼지지 않고 줄지 않는다.</b> 파티 요약 줄에 ★ 로 나온다.</div>`
      : `<div class="note">아직 없다. <code>W-060</code> 을 켜면 파티가 ` +
        `물 위를 걷는다 — 마법처럼 칸 수가 줄지 않고 부적처럼 누가 차고 ` +
        `있어야 하지도 않는다.</div>`);
  box.append(caps);

  // ── 번호가 겹치는 곳. 이것이 이 표를 만든 이유 중 하나다.
  if (QUEST.collisions.length) {
    const col = el('<div class="card warn"></div>');
    col.innerHTML = `<h3>⚠ 같은 번호를 두 곳이 쓴다</h3>` +
      `<div class="note">게임이 아는 것은 번호뿐이다. 갈래가 달라도 ` +
      `<b>저장된 파일에는 한 칸</b>이라 한쪽이 켜면 다른 쪽도 켜진 것으로 ` +
      `본다.</div>` +
      QUEST.collisions.map((c) =>
        `<div class="crow"><code>${c.kind === 'step' ? 'Variable' : 'Flag'} ` +
        `${c.index}</code> ${esc((c.titles || []).join(' · '))}` +
        (c.note ? `<div class="fnote warn">${esc(c.note)}</div>` : '') +
        `</div>`).join('');
    box.append(col);
  }

  // ── 정의가 없는데 켜져 있는 칸
  const uf = QUEST.unknown.flags, uv = Object.entries(QUEST.unknown.variables);
  if (uf.length || uv.length) {
    const un = el('<div class="card warn"></div>');
    un.innerHTML = `<h3>설명이 없는데 값이 있다</h3>` +
      `<div class="note">세이브에는 있는데 이 표가 모르는 칸이다. ` +
      `스크립트가 쓰는 것이면 표에 적어야 한다.</div>` +
      `<code class="raw">` +
      uf.map((i) => `Flag ${i}`).concat(uv.map(([i, v]) => `Var ${i}=${v}`))
        .join('   ') + `</code>`;
    box.append(un);
  }

  // ── 갈래별로
  const shown = QUEST.flags.filter(flagMatches);
  for (const scope of QUEST.scopeOrder) {
    const rows = shown.filter((f) => f.scope === scope);
    if (!rows.length) continue;
    const g = el('<div class="group"></div>');
    g.append(el(`<h3>${esc(QUEST.scopeNames[scope] || scope)}` +
      `<span class="c">${rows.filter((f) => f.on).length}/${rows.length}</span></h3>`));
    const list = el('<div class="flags"></div>');
    for (const f of rows) list.append(flagCard(f));
    g.append(list);
    box.append(g);
  }

  if (!shown.length) {
    box.append(el('<div class="note">찾는 것이 없다. ' +
      '<code>is:켜짐</code> <code>is:단계</code> <code>is:이름없음</code> ' +
      '같은 것도 된다.</div>'));
  }
}

// ── 기록 탭 — 이 세이브 하나를 통째로 ──────────────────────
//
// 앞의 세 탭이 **고치는** 곳이라면 여기는 **읽는** 곳이다. 지금 열려
// 있는 세계가 무엇인지 한 장으로 보고, 파일로 내보내고 들여온다.
//
// 고치는 단추를 여기 두지 않는 것은 일부러다. 무엇을 바꾸든 그것을
// 하는 자리가 따로 있고, 두 곳에서 같은 것을 고칠 수 있으면 어느 쪽이
// 진짜인지 헷갈린다.
function renderRecord() {
  const box = $('record');
  box.innerHTML = '';

  const p = STATE.party;
  const fromQuest = new Set((QUEST && QUEST.granted) || []);
  const caps = [...new Set([...p.capabilities, ...fromQuest])];

  const world = el('<div class="card"></div>');
  world.innerHTML = `<h3>이 세계</h3><div class="kv">` +
    `<div class="k">일행</div><div class="v">${STATE.members.length}</div>` +
    `<div class="k">가방</div><div class="v">${ELIG.packKinds} / ${ELIG.packCapacity} 종 · ${ELIG.packUnits} 개</div>` +
    `<div class="k">물건 도감</div><div class="v">${CATALOG.items.length}</div>` +
    `<div class="k">어둠 속 시야</div><div class="v">${p.sightInDarkness}</div>` +
    `<div class="k">횃불 든 사람</div><div class="v">${p.lightBearers}${p.moonlight ? ' · 달빛' : ''}</div>` +
    `<div class="k">마법의 횃불</div><div class="v">${p.magicLight ? '켜짐' : '꺼짐'}</div>` +
    `</div>` +
    `<div class="tags">` +
    (caps.length
      ? caps.map((c) => `<span class="tag good">${fromQuest.has(c) ? '★ ' : ''}` +
          `${t('capability', c)}</span>`).join('')
      : '<span class="tag">지형을 여는 것이 없다</span>') +
    `</div>` +
    (fromQuest.size
      ? `<div class="note" style="margin-top:6px">★ 는 시나리오가 연 것이다. ` +
        `부적·마법과 달리 꺼지지 않는다.</div>` : '');
  box.append(world);

  // ── 사람마다
  const who = el('<div class="card"></div>');
  who.innerHTML = `<h3>일행</h3>` +
    `<table class="tbl"><thead><tr>` +
    `<th>이름</th><th>직업</th><th>Lv 물/마/초</th>` +
    `<th>체력</th><th>무기</th><th>지시</th><th>경험치</th>` +
    `</tr></thead><tbody>` +
    STATE.members.map((m) =>
      `<tr><td>${esc(m.name)}</td>` +
      `<td class="dim">${t('class', m.class)}</td>` +
      `<td class="num">${m.levels.physical} / ${m.levels.magic} / ${m.levels.esp}</td>` +
      `<td class="num">${m.vitals.hitPoints} / ${m.vitals.maxHitPoints}</td>` +
      `<td class="dim">${t('weaponKind', m.weaponKind)}</td>` +
      `<td class="dim">${t('style', m.style)}${m.thrift ? ' · 절약' : ''}</td>` +
      `<td class="num">${m.experience}</td></tr>`).join('') +
    `</tbody></table>`;
  box.append(who);

  // ── 시나리오는 저쪽에서 고친다. 여기서는 어디까지 왔는지만.
  if (QUEST) {
    const s = QUEST.summary;
    const done = QUEST.flags.filter((f) => f.on);
    const q = el('<div class="card"></div>');
    q.innerHTML = `<h3>시나리오</h3>` +
      `<div class="kv">` +
      `<div class="k">켜진 칸</div><div class="v">${s.on} / ${s.total}</div>` +
      `<div class="k">스크립트가 쓴다</div><div class="v">${s.live}</div>` +
      `<div class="k">이름 없음</div><div class="v">${s.unnamed}</div>` +
      `<div class="k">아직 없음</div><div class="v">${s.planned}</div>` +
      `</div>` +
      (done.length
        ? `<div class="tags">${done.slice(0, 12).map((f) =>
            `<span class="tag info" title="${esc(f.title)}">${esc(f.id)}` +
            (f.kind === 'step' ? ` ${f.value}` : '') + `</span>`).join('')}` +
          (done.length > 12 ? `<span class="tag">…${done.length - 12}</span>` : '') +
          `</div>`
        : `<div class="note">아무것도 켜지 않았다.</div>`);
    const go = el('<button style="margin-top:8px">플래그 탭에서 고친다</button>');
    go.onclick = () => selectTab('flags');
    q.append(go);
    box.append(q);
  }

  // ── 담아 둔 구성
  if (SETS.length) {
    const l = el('<div class="card"></div>');
    l.innerHTML = `<h3>담아 둔 구성</h3><div class="tags">` +
      SETS.map((x) => `<span class="tag">${esc(x.name)}</span>`).join('') +
      `</div>`;
    box.append(l);
  }

  // ── 파일
  const file = el('<div class="card"></div>');
  file.innerHTML = `<h3>세이브 파일</h3>` +
    `<div class="note">머리글의 <b>내려받기</b>·<b>불러오기</b>. ` +
    `<code>hd_world</code> 의 저장 형식에 <code>quest</code> 를 하나 더 얹은 ` +
    `것이라 <b>장비와 플래그가 한 파일에 같이</b> 간다. 다시 계산할 수 있는 ` +
    `것은 하나도 안 들어간다 — 무기 종류도 최종 수치도 통행 능력도 읽을 때 ` +
    `계산된다.</div>` +
    `<div class="note" style="margin-top:6px">이 빌드에 없는 물건을 가리키는 ` +
    `칸은 <b>조용히 빠지지 않는다.</b> 비워지고 오른쪽 기록창에 남는다. ` +
    `설명이 없는 플래그도 플래그 탭에 드러난다.</div>`;
  box.append(file);

  // ── 아직 없는 것. 없는 것을 있는 척하지 않는다.
  const gap = el('<div class="card"></div>');
  gap.innerHTML = `<h3>아직 여기 없는 것</h3>` +
    `<ul class="gaps">` +
    `<li><b>지도 · 위치 · 소지금</b> — 게임 쪽 세이브(<code>hadar_save_N</code>)에 ` +
    `있고 아직 안 온다. 플래그와 변수는 온다: 그 파일의 <code>gameOption</code> 을 ` +
    `<code>POST /api/load</code> 의 <code>quest</code> 칸에 넣으면 읽는다.</li>` +
    `<li><b>인물의 레벨 · 능력치 · 직업</b> — 고치는 명령이 ` +
    `<code>hd_world</code> 에 없다. 장비 · 가방 · 지시만 고칠 수 있다.</li>` +
    `<li><b>되돌리기</b> — 모든 변경이 이미 값이라 쌓기만 하면 된다.</li>` +
    `<li><b>대열 바꾸기</b> — API 에는 있고 화면에 없다. 자리 번호가 곧 ` +
    `신원이라 cm2 가 손보는 사람이 옮겨진다.</li>` +
    `</ul>`;
  box.append(gap);
}

// ── 다 그린다 ──────────────────────────────────────────────
function render() {
  if (!STATE || !ELIG) return;
  renderBar();

  for (const name of TABS) $('tab-' + name).hidden = tab !== name;

  switch (tab) {
    case 'gear': {
      renderParty();
      let strip = $('gearPack');
      if (!strip) {
        strip = el('<div id="gearPack" style="margin-top:14px"></div>');
        $('tab-gear').append(strip);
      }
      const owned = CATALOG.items.map((i) => i.ref)
        .filter((r) => carried(r) > 0);
      renderGrid(strip, filtered(owned));
      break;
    }
    case 'pack': renderPackTab(); break;
    case 'fight': renderFight(); break;
    case 'flags': renderFlags(); break;
    case 'record': renderRecord(); break;
  }

  syncSide();
  renderLegend();
  if (tab === 'gear' || tab === 'pack') renderLoadouts();
}

async function autoFight() {
  const out = await post('/api/battle',
    { enemyKeys: setup.keys, seed: setup.seed, initialGap: setup.gap });
  if (out.error) { log('전투가 끝나지 않았다 — ' + out.error, 'no'); return; }
  const label = { win: '이겼다', lose: '전멸했다', escape: '도망쳤다' }[out.result] || out.result;
  log(`${out.rounds}라운드, ${label}. (${out.enemies.length}마리, 씨앗 ${out.seed})`, out.result === 'win' ? 'ok' : 'no');
  for (const m of out.members) {
    const d = m.hitPointsBefore - m.hitPointsAfter;
    log(`  ${m.name} ${t('weaponKind', m.weaponKind)}(사거리 ${m.reach}) ` +
      `체력 ${m.hitPointsBefore}→${m.hitPointsAfter}${d > 0 ? ` (−${d})` : ''}` +
      (m.experience ? ` · 경험치 +${m.experience}` : ''), 'note');
  }
  STATE = out.state;
  ELIG = await get('/api/eligibility');
  render();
}

// ── 머리글의 단추들 ────────────────────────────────────────
function selectTab(name) {
  if (!TABS.includes(name)) return;
  tab = name;
  for (const b of $('tabs').children) {
    b.classList.toggle('on', b.dataset.tab === name);
  }
  // 검색은 탭마다 찾는 것이 다르다. 장비 탭에서 친 `is:양손` 을 들고
  // 플래그 탭으로 가면 아무것도 안 나오고, 그것이 화면이 비어 있는
  // 것처럼 보인다.
  $('q').placeholder = SEARCH_HINT[name] || '';
  // 기록 탭은 읽는 곳이라 거를 것이 없다. 아무 일도 안 하는 칸을
  // 열어 두느니 닫아 둔다.
  $('q').disabled = name === 'record' || (name === 'fight' && FIGHT && FIGHT.open);
  // 다른 탭으로 가면 집은 것과 미리보기를 놓는다. 장비에서 집은 물건을
  // 든 채로 플래그 탭에 가 있으면 돌아왔을 때 왜 칸이 물들어 있는지
  // 모른다.
  if (name !== 'gear' && name !== 'pack') {
    pick = null;
    hoverItem = null;
    clearPreview();
  }
  render();
}

$('tabs').onclick = (ev) => {
  const b = ev.target.closest('button');
  if (b) selectTab(b.dataset.tab);
};

$('q').oninput = (ev) => { query = ev.target.value; render(); };
$('qClear').onclick = () => { query = ''; $('q').value = ''; render(); };

$('reset').onclick = async () => {
  const out = await post('/api/reset');
  STATE = out.state;
  QUEST = out.quest;
  ELIG = await get('/api/eligibility');
  pick = null;
  log('처음 상태로 되돌렸다. 플래그도 전부 껐다.', 'ok');
  render();
};

$('save').onclick = async () => {
  const data = await get('/api/save');
  const url = URL.createObjectURL(
    new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = 'hd_world_save.json';
  a.click();
  URL.revokeObjectURL(url);
  log('세이브를 내려받았다.', 'ok');
};

$('loadBtn').onclick = () => $('loadFile').click();
$('loadFile').onchange = async (ev) => {
  const file = ev.target.files[0];
  if (!file) return;
  ev.target.value = '';
  let parsed;
  try {
    parsed = JSON.parse(await file.text());
  } catch (e) {
    log('읽을 수 없는 파일이다 — ' + e.message, 'no');
    return;
  }
  const out = await post('/api/load', parsed);
  if (out.error) { log('불러오지 못했다 — ' + out.error, 'no'); return; }
  // 빠진 것은 조용히 사라지지 않는다. 모델이 그렇게 만들어져 있으므로
  // 화면도 그것을 지킨다.
  for (const issue of out.issues || []) {
    log('빠짐 — ' + issue.message +
      (issue.member ? ` (${issue.member})` : '') +
      (issue.item ? ` · ${issue.item}` : ''), 'no');
  }
  STATE = out.state;
  QUEST = out.quest || await get('/api/quest');
  ELIG = await get('/api/eligibility');
  focusMember = STATE.members[0]?.ref ?? null;
  pick = null;
  log(`${file.name} 을 불러왔다. 플래그 ${QUEST.summary.on}칸이 켜져 있다.`, 'ok');
  const unknown = QUEST.unknown.flags.length +
    Object.keys(QUEST.unknown.variables).length;
  if (unknown) log(`  설명이 없는 칸 ${unknown}개 — 기록 탭에 있다.`, 'no');
  render();
};

document.addEventListener('keydown', (ev) => {
  if (ev.key === 'Escape') { pick = null; clearPreview(); render(); }
  if (ev.key === '/' && document.activeElement !== $('q')) {
    ev.preventDefault(); $('q').focus();
  }
});
// 미리보기는 스스로 사라지지 않는다. 읽으려고 눈을 옮기는 순간 지워지면
// 읽을 수 없다 — 다음 물건을 가리킬 때 바뀌고, Esc 로 닫는다.

// ── 시작 ───────────────────────────────────────────────────
(async () => {
  const [text, catalog, state, elig, sets, quest, foes, fight] =
    await Promise.all([
      get('/api/text'), get('/api/catalog'), get('/api/state'),
      get('/api/eligibility'), get('/api/loadouts'), get('/api/quest'),
      get('/api/enemies'), get('/api/battle/state'),
    ]);
  TEXT = text; CATALOG = catalog; STATE = state; ELIG = elig; QUEST = quest;
  SETS = sets.loadouts || [];
  ROSTER = foes.enemies;
  FIGHT = fight;

  // 적이 늘면 아이콘 표에 빠진 것이 생긴다. 조용히 회색 사람꼴로
  // 떨어지므로 여기서 말해 준다.
  const missing = FOES.missing(ROSTER.map((r) => r.key));
  if (missing.length) {
    log(`아이콘이 없는 적 ${missing.length}종 — ${missing.join(', ')}`, 'no');
  }
  DEFS = new Map(CATALOG.items.map((i) => [i.ref, i]));
  focusMember = STATE.members[0]?.ref ?? null;
  selectTab('gear');
  log('불러왔다. 가방에서 하나 집고 부위 칸을 누르시오.', 'ok');
  if (QUEST.collisions.length) {
    log(`플래그 탭에 경고 ${QUEST.collisions.length}건 — 같은 번호를 두 곳이 쓴다.`, 'no');
  }
})();
