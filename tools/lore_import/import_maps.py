#!/usr/bin/env python3
"""로어 3부작의 원작 맵 68개를 lore2026_app 의 맵 형식으로 옮긴다.

들어오는 것 (기획 저장소 SMG_GameDesignVault/LORE_TRILOGY/Walkthrough):
  <편>/maps/maps.json   맵별 크기·유형·칸 번호(0~55)·"항상 밝음" 표시
  <편>/maps/<맵>.png    원작 타일로 그린 맵 그림 — 새 타일 그림을 여기서 잘라 낸다

나가는 것 (lore2026_app/assets):
  maps/MapInfos.json    맵 목록. 하다르 앱과 같은 자리에 같은 모양이고, 로어 쪽 항목이 붙는다
  maps/MapNNN.json      RPG Maker MV 형식 6층 (바닥 · 바닥 장식 · 물체 · 윗물체 · 그림자 · 구역)
  maps/tiletable.json   (편, 맵 유형, 원작 타일 번호) → 층별 번호. 실행 중 `Map::ChangeTile` 이 쓴다
  images/Lore_A5.png    하다르 앱의 것 + 아래로 덧붙인 쪽
  images/Lore_B.png     하다르 앱의 것 그대로

## 타일을 옮기는 규칙

원작은 칸마다 번호 하나(0~55)이고 같은 번호라도 맵 유형(마을·요새·필드·동굴)과
편에 따라 뜻이 다르다(`classify`). 하다르 앱은 그것을 바닥(Lore_A5)과 물체(Lore_B)로
나눠 놓았고, **번호가 어느 띠에 있느냐로 통행을 정한다**(바닥 0~55 통행 · 56~59 물 …).

1. 하다르 앱이 이미 옮겨 둔 번호(`known_tiles.json`)는 그 묶음을 그대로 쓴다.
2. 물·늪·용암은 하다르 앱의 56 · 61 · 63 을 쓴다.
3. 나머지는 원작 그림을 2배로 키워 Lore_A5 의 **새 쪽**에 넣는다. 쪽은 128칸이고
   띠 배치는 첫 쪽과 같다 — 그래서 통행 판정식이 `번호 % 128` 하나로 남는다.
   새 쪽의 첫 칸(128)은 검은 칸이다 (투시가 쓴다).
4. 띠만으로 뜻이 안 나오는 칸(숨은 이벤트 · 사람 · 편마다 뜻이 다른 번호)은
   **구역 층**(z5)에 적는다: 1 이벤트 · 2 대화 · 3 푯말 · 4 입구 · 5 막힘 · 6 통행 ·
   7 물 · 8 늪 · 9 용암. 구역이 있으면 구역이 이긴다.
5. 0번(숨은 이벤트 칸)은 그 맵의 기본 타일 그림으로 그리고 구역 1 을 적는다.

사용법:
  python3 import_maps.py <Walkthrough 폴더> <hadar2026_app/assets> <lore2026_app/assets> [--preview <폴더>]
"""
import argparse
import hashlib
import json
import os
import shutil

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TILE = 48
PAGE = 128
A5_COLS = 8

# (편 번호, 공략집 폴더, 맵 키 순서). 번호는 발매 순으로 매긴다.
EPISODES = [
    (1, '1st', ['Lore', 'Gaia', 'Water', 'Swamp', 'Lava', 'CastleLore', 'LastDitch', 'Valiant',
                'GaiaCastle', 'WaterField', 'Pyramid', 'EvilSeal', 'SwampGate', 'Menace', 'Quake',
                'Wivern', 'Notice', 'Lockup', 'EvilGod', 'Muddy', 'SwampKeep', 'Imperium',
                'EvilConc', 'LastShelter', 'DungeonEvil', 'Chamber', 'AnotherLore']),
    (2, '2nd', ['Lore', 'Pyramid', 'Underworld1', 'Underworld2', 'CastleLore', 'LastDitch', 'Dome',
                'Regulus', 'Menace', 'Evidence', 'Clue', 'LightTemple', 'Mortal', 'Belial',
                'Moloch', 'Asmodeus', 'Mephisto']),
    (3, '3rd', ['Ground1', 'Ground2', 'Ground3', 'Ground4', 'Ground5', 'UnderGrd', 'Lore', 'Dark',
                'LastDtch', 'Menace', 'Valiant', 'Light', 'Gaea', 'OrcTown', 'Vesper', 'TrolTown',
                'Kobold', 'Ancient', 'Hut', 'DracTown', 'Tomb', 'Imperium', 'HdsGate', 'Dome']),
]

TITLES = {
    1: dict(Lore='로어 대륙', Gaia='가이아 테라', Water='물의 대륙', Swamp='늪의 대륙', Lava='용암의 대륙',
            CastleLore='로어성', LastDitch='라스트디치성', Valiant='배리언트 피플즈성',
            GaiaCastle='가이아 테라성', WaterField='워터 필드', Pyramid='피라미드', EvilSeal='이블 실',
            SwampGate='스왐프 게이트', Menace='메너스', Quake='퀘이크', Wivern='와이번 동굴',
            Notice='노티스', Lockup='록업', EvilGod='이블 갓', Muddy='머디', SwampKeep='스왐프 킵',
            Imperium='임페리엄 마이너', EvilConc='이블 컨센트레이션', LastShelter='라스트 셸터',
            DungeonEvil='던전 오브 이블', Chamber='네크로만서의 방', AnotherLore='또 다른 지식의 성전'),
    2: dict(Lore='로어 대륙', Pyramid='알 수 없는 피라미드', Underworld1='지하 세계 1',
            Underworld2='지하 세계 2', CastleLore='로어성', LastDitch='라스트디치성', Dome='빛의 지붕',
            Regulus='레굴루스의 오두막', Menace='메너스', Evidence='흉성의 증거', Clue='흉성의 단서',
            LightTemple='빛의 사원', Mortal='필멸의 생존', Belial='베리알의 동굴', Moloch='몰록의 동굴',
            Asmodeus='아스모데우스의 동굴', Mephisto='메피스토펠레스의 요새'),
    3: dict(Ground1='로어 대륙', Ground2='가이아 테라', Ground3='아프로디테 테라', Ground4='이쉬도 테라',
            Ground5='우라누스 테라', UnderGrd='하데스 테라', Lore='로어성', Dark='로어성 (795년)',
            LastDtch='라스트디치성', Menace='메너스 금광', Valiant='배리언트 피플즈성', Light='빛의 성',
            Gaea='가이아 테라성', OrcTown='오크 마을', Vesper='베스퍼성', TrolTown='트롤 마을',
            Kobold='코볼트성', Ancient='에인션트 이블의 신전', Hut='오두막', DracTown='드라코니안 마을',
            Tomb='17대 드라콘 제왕의 지하 묘', Imperium='임페리엄 마이너성', HdsGate='하데스 게이트',
            Dome='빛의 지붕'),
}

# 원작이 맵을 불러올 때 그림을 바꿔 끼우는 칸 (공략집 render_maps*.py 와 같은 목록).
# 그 맵에서만 다른 그림이므로 맵별 항목으로 따로 둔다.
MAP_ART = {
    (3, 'OrcTown'): [53, 54, 34], (3, 'Ground3'): [21], (3, 'Vesper'): [53, 54],
    (3, 'TrolTown'): [53, 54], (3, 'Ground4'): [52, 54], (3, 'Kobold'): [35, 52],
    (3, 'Ancient'): [53, 22, 3, 4], (3, 'Hut'): [53],
    (3, 'DracTown'): [53, 52, 49, 8, 9, 14, 19], (3, 'Tomb'): [37, 38, 54, 53],
    (3, 'Light'): [53], (3, 'Dome'): [54], (2, 'Pyramid'): [52],
}

# 제3부 11.2 의 맵별 예외: 푯말·입구 번호 자리에 사람이 서 있는 맵.
MAP_CLASS = {
    (3, 'OrcTown'): {53: 'npc'}, (3, 'Tomb'): {53: 'npc'},
    (3, 'Vesper'): {53: 'npc', 54: 'npc'}, (3, 'TrolTown'): {53: 'npc', 54: 'npc'},
}

ACTION = dict(block='none', walk='move', npc='talk', entrance='enter', sign='sign', event='event',
              water='water', swamp='swamp', lava='lava')
REGION = dict(event=1, talk=2, sign=3, enter=4, none=5, move=6, water=7, swamp=8, lava=9)

MV_HEAD = dict(autoplayBgm=False, autoplayBgs=False, battleback1Name='', battleback2Name='',
               bgm=dict(name='', pan=0, pitch=100, volume=90), bgs=dict(name='', pan=0, pitch=100, volume=90),
               disableDashing=False, displayName='', encounterList=[], encounterStep=30, height=0, note='',
               parallaxLoopX=False, parallaxLoopY=False, parallaxName='', parallaxShow=True, parallaxSx=0,
               parallaxSy=0, scrollType=0, specifyBattleback=False, tilesetId=7, width=0)


def classify(ep, typ, t):
    """원작의 칸 해석. 제1부 LOREMAIN · 제3부 MYSTMAIN; 제2부는 동굴만 제1부와 같다."""
    lore = ep == 1 or (ep == 2 and typ == 'den')
    if typ == 'town':
        if t == 0 or (t == 19 and not lore): return 'event'
        if 1 <= t <= 21: return 'block'
        return {22: 'entrance', 23: 'sign', 24: 'water', 25: 'swamp', 26: 'lava'}.get(
            t, 'walk' if 27 <= t <= 47 else 'npc')
    if typ == 'ground':
        if t == 0 or (t == 20 and not lore): return 'event'
        if 1 <= t <= (21 if lore else 19): return 'block'
        if t == 22: return 'sign'
        if t == 48: return 'water'
        if t in (23, 49): return 'swamp'
        if t == 50: return 'lava'
        return 'walk' if 24 <= t <= 47 else 'entrance'
    if typ == 'den':
        if t in (0, 52): return 'event'
        if lore and 1 <= t <= 40: return 'block'
        if 1 <= t <= 19 or 22 <= t <= 40 or t == 51: return 'block'
        return {53: 'sign', 48: 'water', 49: 'swamp', 50: 'lava', 54: 'entrance'}.get(
            t, 'walk' if 41 <= t <= 47 else 'npc')
    # keep
    if t in (0, 52): return 'event'
    if 1 <= t <= 39 or t == 51: return 'block'
    return {53: 'sign', 48: 'water', 49: 'swamp', 50: 'lava', 54: 'entrance'}.get(
        t, 'walk' if 40 <= t <= 47 else 'npc')


def a5_action(ix):
    l = ix % PAGE
    if l < 56: return 'move'
    if l < 60: return 'water'
    if l < 62: return 'swamp'
    if l < 64: return 'lava'
    if l < 70: return 'enter'
    if l < 72: return 'cliff'
    return 'none'


def b_action(i):
    if i <= 0: return 'move'
    if i < 64: return 'none'
    if i < 96: return 'move'
    if i < 112: return 'none'
    if i < 124: return 'sign'
    if i < 128: return 'enter'
    if i < 144: return 'talk'
    return 'move'


def unit_action(e):
    for k in ('obj1', 'obj0'):
        a = b_action(e[k])
        if a != 'move':
            return a
    return a5_action(e['a5'])


BANDS = dict(move=(0, 56), water=(56, 60), swamp=(60, 62), lava=(62, 64), enter=(64, 70), none=(72, 128))


class Sheets:
    """Lore_A5 에 새 그림을 띠에 맞춰 덧붙인다. 같은 그림은 한 칸만 쓴다."""

    def __init__(self, base_a5):
        self.base = Image.open(base_a5).convert('RGBA')
        assert self.base.size == (A5_COLS * TILE, (PAGE // A5_COLS) * TILE), self.base.size
        self.added = {}      # 번호 → 그림
        self.by_hash = {}    # (그림 해시, 띠) → 번호
        self.next = {}       # (쪽, 띠) → 다음 빈 자리

    def put(self, img, band):
        h = (hashlib.md5(img.tobytes()).hexdigest(), band)
        if h in self.by_hash:
            return self.by_hash[h]
        lo, hi = BANDS[band]
        page = 1
        while True:
            n = self.next.get((page, band), lo)
            if n < hi:
                self.next[(page, band)] = n + 1
                ix = page * PAGE + n
                self.added[ix] = img
                self.by_hash[h] = ix
                return ix
            page += 1

    def image(self, ix):
        """[ix] 번 칸의 그림 (첫 쪽이면 하다르의 그림에서 잘라 온다)."""
        if ix in self.added:
            return self.added[ix]
        if ix < PAGE:
            x, y = (ix % A5_COLS) * TILE, (ix // A5_COLS) * TILE
            return self.base.crop((x, y, x + TILE, y + TILE))
        return None

    def save(self, path):
        pages = 1 + max([ix // PAGE for ix in self.added] or [0])
        out = Image.new('RGBA', (A5_COLS * TILE, pages * (PAGE // A5_COLS) * TILE), (0, 0, 0, 255))
        out.paste(self.base, (0, 0))
        for ix, img in self.added.items():
            out.paste(img, ((ix % A5_COLS) * TILE, (ix // A5_COLS) * TILE))
        out.convert('RGB').save(path, optimize=True)
        return pages


class Walk:
    def __init__(self, root):
        self.root = root
        self.meta = {ep: json.load(open(os.path.join(root, d, 'maps', 'maps.json'), encoding='utf-8'))
                     for ep, d, _ in EPISODES}
        self.dir = {ep: d for ep, d, _ in EPISODES}
        self._png = {}

    def png(self, ep, key):
        if (ep, key) not in self._png:
            self._png[(ep, key)] = Image.open(
                os.path.join(self.root, self.dir[ep], 'maps', key + '.png')).convert('RGB')
        return self._png[(ep, key)]

    def art(self, ep, key, t):
        """맵 (ep, key) 에서 t 번 칸의 그림 하나. 없으면 None."""
        m = self.meta[ep][key]
        T = m.get('tile', 24)
        for y, row in enumerate(m['cells']):
            for x, v in enumerate(row):
                if v == t:
                    im = self.png(ep, key).crop((x * T, y * T, x * T + T, y * T + T))
                    return im.resize((TILE, TILE), Image.NEAREST).convert('RGBA')
        return None

    def common_art(self, typ, t):
        """세 편 공통 그림. 제3부 → 제2부 → 제1부 순으로 찾고, 맵별로 바꿔 끼운 칸은 피한다."""
        for ep in (3, 2, 1):
            for key, m in self.meta[ep].items():
                if m['type'] != typ or t in MAP_ART.get((ep, key), ()):
                    continue
                im = self.art(ep, key, t)
                if im is not None:
                    return im
        return None


def build_tables(walk, sheets, known):
    """(편, 유형) → 56칸 표, 그리고 맵별 덮어쓰기."""
    common = {}

    def common_entry(typ, t):
        if (typ, t) in common:
            return common[(typ, t)]
        k = known.get(typ, {}).get(str(t))
        cls3 = classify(3, typ, t)
        # 하다르 앱이 사람·푯말·입구를 다른 그림(바닥)으로 바꿔 둔 번호가 있다
        # (메너스의 사람 21번 — 하다르는 그 자리를 이벤트로 옮겼다). 물려받은
        # 그림의 띠가 원작의 뜻과 다르면 물려받지 않고 원작 그림을 쓴다.
        if k is not None and cls3 in ('npc', 'sign', 'entrance'):
            if unit_action(dict(a5=k['a5'], obj0=k['obj0'], obj1=k['obj1'])) != ACTION[cls3]:
                k = None
        if k is not None:
            e = dict(a5=k['a5'], decor=k['decor'], obj0=k['obj0'], obj1=k['obj1'])
        elif cls3 == 'water':
            e = dict(a5=56, decor=0, obj0=0, obj1=0)
        elif cls3 == 'swamp':
            e = dict(a5=61, decor=0, obj0=0, obj1=0)
        elif cls3 == 'lava':
            e = dict(a5=63, decor=0, obj0=0, obj1=0)
        else:
            img = walk.common_art(typ, t)
            if img is None:
                e = None
            else:
                band = {'walk': 'move', 'event': 'move', 'entrance': 'enter'}.get(cls3, 'none')
                e = dict(a5=sheets.put(img, band), decor=0, obj0=0, obj1=0)
        common[(typ, t)] = e
        return e

    episodes = {}
    for ep, _, _ in EPISODES:
        episodes[str(ep)] = {}
        for typ in ('town', 'keep', 'ground', 'den'):
            row = [None]
            for t in range(1, 56):
                e = common_entry(typ, t)
                if e is None:
                    row.append(None)
                    continue
                row.append(dict(e, action=ACTION[classify(ep, typ, t)]))
            episodes[str(ep)][typ] = row

    maps = {}
    for ep, _, keys in EPISODES:
        for key in keys:
            m = walk.meta[ep][key]
            typ = m['type']
            over = {}
            for t in MAP_ART.get((ep, key), ()):
                img = walk.art(ep, key, t)
                if img is None:
                    continue
                cls = MAP_CLASS.get((ep, key), {}).get(t, classify(ep, typ, t))
                band = {'walk': 'move', 'event': 'move', 'entrance': 'enter'}.get(cls, 'none')
                over[str(t)] = dict(a5=sheets.put(img, band), decor=0, obj0=0, obj1=0, action=ACTION[cls])
            for t, cls in MAP_CLASS.get((ep, key), {}).items():
                if str(t) not in over and episodes[str(ep)][typ][t] is not None:
                    over[str(t)] = dict(episodes[str(ep)][typ][t], action=ACTION[cls])
            maps[f'E{ep}_{key}'] = dict(episode=ep, key=key, type=typ, default=m['default'], tiles=over)
    return episodes, maps


class ActorSheet:
    """원작 사람 그림에서 바닥을 뺀 투명한 인물 그림 — `Lore_C.png`.

    원작의 사람 칸은 바닥까지 한 그림이라, 맵 칸과 따로 걷게 하면(배우)
    다른 바닥 위에 원래 바닥 네모가 따라다닌다. 같은 맵 유형의 바닥 그림
    가운데 사람 그림과 가장 많이 겹치는 것을 찾아, 그 바닥과 같은 점을
    투명하게 한다. 원작 그림은 16색을 2배로 키운 것이라 같은 점은 정확히 같다.
    """

    COLS = 8

    def __init__(self):
        self.images = []
        self.by_hash = {}

    def put(self, img):
        h = hashlib.md5(img.tobytes()).hexdigest()
        if h not in self.by_hash:
            self.by_hash[h] = len(self.images)
            self.images.append(img)
        return self.by_hash[h]

    def save(self, path):
        rows = max(1, (len(self.images) + self.COLS - 1) // self.COLS)
        out = Image.new('RGBA', (self.COLS * TILE, rows * TILE), (0, 0, 0, 0))
        for i, img in enumerate(self.images):
            out.paste(img, ((i % self.COLS) * TILE, (i // self.COLS) * TILE))
        out.save(path, optimize=True)


def cut_out(person, floors):
    """[person] 에서 [floors] 중 가장 많이 겹치는 바닥을 빼 투명하게 한다."""
    p = person.convert('RGBA')
    pd = list(p.getdata())
    best, best_same = None, -1
    for f in floors:
        fd = list(f.convert('RGBA').getdata())
        same = sum(1 for a, b in zip(pd, fd) if a == b)
        if same > best_same:
            best, best_same = fd, same
    if best is None or best_same < len(pd) // 5:
        return None  # 바닥을 알아볼 수 없다 — 칸 그림을 그대로 쓴다
    out = [(0, 0, 0, 0) if a == b else a for a, b in zip(pd, best)]
    img = Image.new('RGBA', p.size)
    img.putdata(out)
    return img


def add_actor_sprites(episodes, maps, sheets, actors, walk):
    """사람 칸마다 투명한 인물 그림을 만들어 `actor` 번호로 적는다.

    바닥 후보는 **원작 바닥 그림**이다 — 원작 사람 그림은 원작 바닥 위에
    그려져 있다(하다르가 다시 그린 바닥과는 점이 맞지 않는다). 맵마다 그림을
    바꿔 끼운 사람은 그 맵의 바닥을 본다. 하다르의 투명한 인물(`Lore_B`
    128~143)을 물려받은 칸은 이미 투명하므로 건너뛴다.
    """
    cache = {}

    def floors(ep, typ, key=None):
        ck = (ep, typ, key)
        if ck in cache:
            return cache[ck]
        out = []
        for t in range(1, 56):
            if classify(int(ep), typ, t) != 'walk':
                continue
            img = walk.art(int(ep), key, t) if key else walk.common_art(typ, t)
            if img is not None:
                out.append(img)
        cache[ck] = out
        return out

    def fill(e, ep, typ, key=None):
        if e is None or e['action'] != 'talk' or e['obj0'] or e['obj1']:
            return
        img = sheets.image(e['a5'])
        if img is None:
            return
        cut = cut_out(img, floors(ep, typ, key))
        if cut is not None:
            e['actor'] = actors.put(cut)

    for ep in episodes:
        for typ in episodes[ep]:
            for e in episodes[ep][typ]:
                fill(e, ep, typ)
    for info in maps.values():
        key = info.get('key')
        for e in info['tiles'].values():
            fill(e, str(info['episode']), info['type'], key)


def entry_for(episodes, maps, name, t):
    """맵 `name` 의 t 번 칸이 어떻게 그려지고 무엇을 하는지."""
    info = maps[name]
    ep, typ = str(info['episode']), info['type']
    if t == 0:
        d = info['default']
        base = info['tiles'].get(str(d)) or (episodes[ep][typ][d] if 0 < d < 56 else None)
        if base is None:  # 기본 타일이 0 이거나 그림이 없으면 검은 바닥
            base = dict(a5=0, decor=0, obj0=0, obj1=0)
        return dict(base, action='event')
    e = info['tiles'].get(str(t)) or (episodes[ep][typ][t] if t < 56 else None)
    if e is None:
        return dict(a5=0, decor=0, obj0=0, obj1=0, action='none')
    return e


def convert_map(walk, episodes, maps, ep, key):
    m = walk.meta[ep][key]
    name = f'E{ep}_{key}'
    w, h = m['w'], m['h']
    n = w * h
    layers = [[0] * n for _ in range(6)]
    lit = m.get('lit')
    cache = {}
    for y in range(h):
        for x in range(w):
            t = m['cells'][y][x]
            if t not in cache:
                cache[t] = entry_for(episodes, maps, name, t)
            e = cache[t]
            i = y * w + x
            layers[0][i] = 1536 + e['a5']
            layers[1][i] = e['decor']
            layers[2][i] = e['obj0']
            layers[3][i] = e['obj1']
            layers[4][i] = 0 if (lit and lit[y][x]) else 15
            layers[5][i] = 0 if unit_action(e) == e['action'] else REGION[e['action']]
    doc = dict(MV_HEAD, displayName=TITLES[ep][key], width=w, height=h)
    doc['data'] = [v for layer in layers for v in layer]
    doc['events'] = [None]
    return doc


def preview(doc, a5, b, path):
    """변환 결과를 앱이 그리는 방식대로 그려 본다 (칸당 24px)."""
    w, h = doc['width'], doc['height']
    n = w * h
    out = Image.new('RGBA', (w * 24, h * 24))
    tiles = {}

    def a5tile(ix):
        if ('a', ix) not in tiles:
            tiles[('a', ix)] = a5.crop(((ix % 8) * 48, (ix // 8) * 48, (ix % 8) * 48 + 48, (ix // 8) * 48 + 48)
                                       ).resize((24, 24), Image.NEAREST)
        return tiles[('a', ix)]

    def btile(i):
        if ('b', i) not in tiles:
            r, c = (i // 8, i % 8) if i < 128 else ((i - 128) // 8, 8 + (i - 128) % 8)
            tiles[('b', i)] = b.crop((c * 48, r * 48, c * 48 + 48, r * 48 + 48)).resize((24, 24), Image.NEAREST)
        return tiles[('b', i)]

    for i in range(n):
        x, y = i % w, i // w
        out.paste(a5tile(doc['data'][i] - 1536), (x * 24, y * 24))
        for layer in (1, 2, 3):
            v = doc['data'][layer * n + i]
            if v > 0:
                out.alpha_composite(btile(v), (x * 24, y * 24))
    out.convert('RGB').save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('walkthrough')
    ap.add_argument('hadar_assets')
    ap.add_argument('lore_assets')
    ap.add_argument('--preview')
    a = ap.parse_args()

    walk = Walk(a.walkthrough)
    known = json.load(open(os.path.join(HERE, 'known_tiles.json'), encoding='utf-8'))
    sheets = Sheets(os.path.join(a.hadar_assets, 'images', 'Lore_A5.png'))
    # 검은 칸 하나를 맨 먼저 넣는다 — 새 쪽의 첫 자리(128)에 온다.
    # 투시가 숨은 이벤트 칸을 드러낼 때 이 칸으로 덮는다.
    dark = sheets.put(Image.new('RGBA', (TILE, TILE), (0, 0, 0, 255)), 'move')
    assert dark == PAGE, dark
    episodes, maps = build_tables(walk, sheets, known)
    actors = ActorSheet()
    add_actor_sprites(episodes, maps, sheets, actors, walk)

    out_maps = os.path.join(a.lore_assets, 'maps')
    out_img = os.path.join(a.lore_assets, 'images')
    os.makedirs(out_maps, exist_ok=True)
    os.makedirs(out_img, exist_ok=True)
    a5_path = os.path.join(out_img, 'Lore_A5.png')
    pages = sheets.save(a5_path)
    b_path = os.path.join(out_img, 'Lore_B.png')
    shutil.copyfile(os.path.join(a.hadar_assets, 'images', 'Lore_B.png'), b_path)
    actors.save(os.path.join(out_img, 'Lore_C.png'))

    infos = [None]
    mid = 0
    docs = {}
    for ep, _, keys in EPISODES:
        for key in keys:
            mid += 1
            m = walk.meta[ep][key]
            name = f'E{ep}_{key}'
            doc = convert_map(walk, episodes, maps, ep, key)
            docs[name] = doc
            json.dump(doc, open(os.path.join(out_maps, f'Map{mid:03d}.json'), 'w', encoding='utf-8'),
                      ensure_ascii=False, separators=(',', ':'))
            info = dict(id=mid, expanded=False, name=name, order=mid, parentId=0, scrollX=0, scrollY=0,
                        cm2=f'ep{ep}/{key}.cm2', episode=ep, key=key, title=TITLES[ep][key],
                        type=m['type'], default=m['default'])
            if ep == 3:  # 제3부 맵 파일의 머리 정보: 조우 여부와 나가는 곳·들어가는 곳
                info['encounter'] = bool(m['encounter'])
                info['start'] = m['start']
                for side in ('exit', 'enter'):
                    target = m[side + '_map']
                    if target and target != 'Genius':  # 'Genius' 는 "연결 없음" 자리의 서명이다
                        info[side] = dict(map=f'E3_{target}', x=m[side][0], y=m[side][1])
            infos.append(info)
    with open(os.path.join(out_maps, 'MapInfos.json'), 'w', encoding='utf-8') as f:
        f.write('[\n' + ',\n'.join(json.dumps(i, ensure_ascii=False) for i in infos) + '\n]\n')

    table = dict(version=1, pageSize=PAGE, darkTile=dark, regions=REGION, episodes=episodes, maps=maps)
    json.dump(table, open(os.path.join(out_maps, 'tiletable.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))

    missing = sorted({(ep, typ, t) for ep in episodes for typ in episodes[ep]
                      for t in range(1, 55) if episodes[ep][typ][t] is None and any(
                          t in row for k, m in walk.meta[int(ep)].items() if m['type'] == typ
                          for row in m['cells'])})
    print(f'맵 {mid}개 · 새 타일 그림 {len(sheets.added)}칸 · Lore_A5 {pages}쪽 · 투명한 인물 {len(actors.images)}개')
    print('그림을 못 찾은 칸:', missing or '없음')

    if a.preview:
        os.makedirs(a.preview, exist_ok=True)
        a5 = Image.open(a5_path).convert('RGBA')
        b = Image.open(b_path).convert('RGBA')
        for name, doc in docs.items():
            preview(doc, a5, b, os.path.join(a.preview, name + '.png'))


if __name__ == '__main__':
    main()
