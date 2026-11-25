#!/usr/bin/env python3
"""하다르 앱에 이미 변환돼 있는 맵에서 (맵 유형, 원작 타일 번호) → 층별 번호 대응을 뽑는다.

하다르 앱의 로어성·라스트디치·로어 대륙·메너스는 원작 맵을 손으로 옮긴 것이고,
같은 원작 번호가 늘 같은 (바닥, 장식, 물체, 윗물체) 묶음으로 옮겨져 있다.
그 묶음을 그대로 물려받으면 lore2026_app 이 같은 그림을 쓴다.

한 번만 돌리면 된다. 결과는 known_tiles.json 에 얼려 둔다 — 하다르 쪽 맵이
나중에 바뀌어도 로어 쪽 변환이 따라 흔들리지 않게 하려는 것이다.

사용법: python3 derive_known.py <공략집 Walkthrough 폴더> <hadar2026_app/assets/maps>
"""
import collections
import json
import os
import sys

PAIRS = [  # (하다르 맵, 편, 원작 맵 키)
    ('Map014', '1st', 'CastleLore'),
    ('Map015', '2nd', 'LastDitch'),
    ('GROUND1', '2nd', 'Lore'),
    ('DEN1', '3rd', 'Menace'),
]


def main(walk, hadar_maps):
    src = {p: json.load(open(os.path.join(walk, p, 'maps', 'maps.json'), encoding='utf-8'))
           for p in ('1st', '2nd', '3rd')}
    table = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
    for hname, part, key in PAIRS:
        d = json.load(open(os.path.join(hadar_maps, hname + '.json'), encoding='utf-8'))
        w, h = d['width'], d['height']
        n = w * h
        m = src[part][key]
        assert (m['w'], m['h']) == (w, h), (hname, key)
        layer = [d['data'][i * n:(i + 1) * n] for i in range(4)]
        for y in range(h):
            for x in range(w):
                i = y * w + x
                t = m['cells'][y][x]
                tup = (layer[0][i] - 1536, layer[1][i], layer[2][i], layer[3][i])
                table[m['type']][t][tup] += 1
    out = {}
    for typ, tiles in table.items():
        out[typ] = {}
        for t, c in sorted(tiles.items()):
            if t == 0:
                continue  # 숨은 이벤트 칸은 맵의 기본 타일 그림을 쓴다
            tup, cnt = c.most_common(1)[0]
            out[typ][str(t)] = {'a5': tup[0], 'decor': tup[1], 'obj0': tup[2], 'obj1': tup[3], 'seen': cnt}
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(out, open(os.path.join(here, 'known_tiles.json'), 'w', encoding='utf-8'), indent=1)
    print({k: len(v) for k, v in out.items()})


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
