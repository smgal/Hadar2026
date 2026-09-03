#!/usr/bin/env python3
"""Extract the original Hadar item tables into hadar2026_app/lib/domain/item/item_data.dart.

Same job as convert_enemy.py: the original's data lives in *source* tables, not
in a data file, so it is parsed out of the reference implementations and emitted
as a Dart table. Re-running must produce a byte-identical file.

Two sources, each authoritative for a different thing:

  REF_hadar/src/hadar/hd_res_string.cpp   (CP949, the C++ original)
      getWeaponName / getShieldName / getArmorName -- the NAME lists.
      This is the *name* index space that HDPlayer.weapon/shield/armor still
      hold today and that live cm2 content writes (Player::ChangeAttribute).
      It carries NO power value: the C++ original sets pow_of_weapon
      independently (hd_class_pc_player.cpp:212,451) and the shipped scripts
      give the same weapon index different powers -- weapon=3 gets
      pow_of_weapon 9 in L1_ep1d2.cm2:147 and 100 in L1_ep1d0.cm2:168.

  REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs  (UTF-8, the Unity port)
      WEAPON_LIST / SHIELD_LIST / ARMOR_LIST / PROPS_LIST -- the numbers
      (power, ac) and the HEAD/LEG/ORNAMENT rows the C++ build never had.

Names come from the C++ build, numbers from the Unity port, joined by name.
See WEAPON_JOIN below for the three names where that join is not literal.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CPP = os.path.join(ROOT, 'REF_hadar', 'src', 'hadar', 'hd_res_string.cpp')
CS = os.path.join(ROOT, 'REF_UNITY_LoreEp1', 'src_as_cs', 'ObjItem.cs')
OUT = os.path.join(ROOT, 'hadar2026_app', 'lib', 'domain', 'item', 'item_data.dart')
OUT_CM2 = os.path.join(ROOT, 'hadar2026_app', 'assets', 'item4ep1.cm2')

# ITEM_TYPE member -> the Dart HDItemType member name (ObjTypes.cs:32-49).
KIND = {
    'WIELD': 'wield', 'CHOP': 'chop', 'STAB': 'stab', 'HIT': 'hit',
    'SHOOT': 'shoot', 'SUMMON_SINGLE': 'summonSingle',
    'SUMMON_MULTI': 'summonMulti', 'SHIELD': 'shield', 'ARMOR': 'armor',
    'HEAD': 'head', 'LEG': 'leg', 'ORNAMENT': 'ornament',
}

# C++ weapon name -> the WEAPON_LIST row it takes its numbers from.
# Only the rows that are not a literal name match are listed; everything else
# is looked up by name and must be unique.
WEAPON_JOIN = {
    # The Unity port renamed 미늘창 to 핼버드 (CHOP index 7, power 80).
    # The C++ name wins, the Unity number comes along.
    '미늘창': ('CHOP', 7),
    # 화염검 has NO weapon row in the Unity port. Its only occurrence is a
    # summon skill (SUMMON_SINGLE index 8), and every summon power in that
    # table is the placeholder 10.0 the original itself flagged as TODO
    # (ObjItem.cs:603-611). Filed at the next free WIELD index so it lands in
    # the right equipment slot; the power is that placeholder, NOT a balanced
    # value. G1-05 must not read it as one.
    '화염검': ('SUMMON_SINGLE', 8),
}
# Where a joined weapon is filed, when that differs from where its numbers
# came from.
WEAPON_REFILE = {'화염검': ('WIELD', 8)}

# Extra provenance appended to a generated row's trailing comment.
NOTES = {
    ('chop', 7): "Unity 는 '핼버드' 로 개명 — 이름은 C++ 을 따름",
    ('wield', 8): '무기 표에 대응 항 없음 — SUMMON_SINGLE:8 의 '
                  '자리표시 10.0(원작 TODO). 밸런스 값 아님',
}


def read_cpp_names(text):
    """{'weapon'|'shield'|'armor': (unknown_name, [names], first_name_line)}"""
    out = {}
    for slot, fn in (('weapon', 'getWeaponName'),
                     ('shield', 'getShieldName'),
                     ('armor', 'getArmorName')):
        start = text.index('HanString hadar::resource::%s(' % fn)
        end = text.index('\n}', start)
        body = text[start:end]
        base_line = text.count('\n', 0, start) + 1
        unknown = re.search(r'NAME_UNKNOWN\s*=\s*"([^"]+)"', body).group(1)
        arr = body.index('const char* NAME[]')
        # Stop at the array's own `};` -- the RETURN_HAN_STRING line that
        # follows carries a quoted josa spec that is not a name.
        block = body[arr:body.index('};', arr)]
        names = re.findall(r'"([^"]+)"', block)
        first = base_line + body.count('\n', 0, arr) + 2
        out[slot] = (unknown, names, first)
    return out


def read_cs_table(text, name, pattern, fields):
    """Rows of one ObjItem.cs table, each with its 1-based source line."""
    start = text.index('%s =' % name)
    end = text.index('};', start)
    rows = []
    for m in re.finditer(pattern, text[start:end]):
        line = text.count('\n', 0, start + m.start()) + 1
        rows.append(dict(zip(fields, m.groups()), line=line))
    return rows


def dart_str(s):
    return "'%s'" % s.replace('\\', '\\\\').replace("'", "\\'")


def main():
    with open(CPP, encoding='cp949') as f:
        cpp = f.read()
    with open(CS, encoding='utf-8') as f:
        cs = f.read()

    cpp_names = read_cpp_names(cpp)

    weapons = read_cs_table(
        cs, 'WEAPON_LIST',
        r'new _WeaponStruct\(\s*(\d+),\s*"([^"]+)",\s*([\d.]+),'
        r'\s*Yunjr\.ITEM_TYPE\.(\w+)\)',
        ('index', 'name', 'power', 'type'))
    shields = read_cs_table(
        cs, 'SHIELD_LIST',
        r'new _ShieldStruct\(\s*(\d+),\s*"([^"]+)",\s*([\d.]+)\)',
        ('index', 'name', 'ac'))
    armors = read_cs_table(
        cs, 'ARMOR_LIST',
        r'new _ArmorStruct\(\s*(\d+),\s*"([^"]+)",\s*([\d.]+)\)',
        ('index', 'name', 'ac'))
    props = read_cs_table(
        cs, 'PROPS_LIST',
        r'new _PropsStruct\(\s*(\d+),\s*Yunjr\.ITEM_TYPE\.(\w+),\s*"([^"]+)",'
        r'\s*"([^"]*)"\)',
        ('index', 'type', 'name', 'annex'))

    # Counts are pinned so a change to the reference tables is loud rather
    # than silently regenerating a different catalog. (G1-02 quoted 51 weapon
    # rows; the table actually holds 59 -- 38 weapons plus 21 summon skills.)
    assert len(weapons) == 59, len(weapons)
    assert len(shields) == 6, len(shields)
    assert len(armors) == 12, len(armors)
    assert len(props) == 33, len(props)

    def find_weapon(kind, index):
        hits = [w for w in weapons
                if w['type'] == kind and int(w['index']) == index]
        assert len(hits) == 1, (kind, index, hits)
        return hits[0]

    def join_weapon(name):
        if name in WEAPON_JOIN:
            kind, index = WEAPON_JOIN[name]
            return find_weapon(kind, index)
        hits = [w for w in weapons if w['name'] == name]
        assert len(hits) == 1, 'ambiguous or missing weapon name %r' % name
        return hits[0]

    rows = []          # (kind, index, name, attaPow, ac, annex, source_line)
    empty_hand = []    # index-0 weapon rows, one per weapon kind

    for w in weapons:
        if int(w['index']) != 0:
            continue
        empty_hand.append((KIND[w['type']], 0, w['name'],
                           int(float(w['power'])), 0, '', w['line']))
    rows.extend(empty_hand)

    weapon_ids = []
    for i, name in enumerate(cpp_names['weapon'][1]):
        if i == 0:
            # 맨손 is already in the table once per weapon kind; the legacy
            # integer has no skill class, so it points at the WIELD row.
            weapon_ids.append(('wield', 0))
            continue
        src = join_weapon(name)
        kind, index = WEAPON_REFILE.get(
            name, (src['type'], int(src['index'])))
        rows.append((KIND[kind], index, name,
                     int(float(src['power'])), 0, '', src['line']))
        weapon_ids.append((KIND[kind], index))

    ac_by_index = {int(s['index']): s for s in shields}
    shield_ids = []
    for i, name in enumerate(cpp_names['shield'][1]):
        src = ac_by_index[i]
        rows.append(('shield', i, name, 0, int(float(src['ac'])), '',
                     src['line']))
        shield_ids.append(('shield', i))

    armor_by_index = {int(a['index']): a for a in armors}
    armor_names = list(cpp_names['armor'][1])
    # Only documented deviation from the C++ names: index 0 keeps the Unity /
    # current-Dart wording (player.dart:93 already shows "평상복").
    armor_names[0] = armor_by_index[0]['name']
    armor_ids = []
    for i, name in enumerate(armor_names):
        src = armor_by_index[i]
        rows.append(('armor', i, name, 0, int(float(src['ac'])), '',
                     src['line']))
        armor_ids.append(('armor', i))

    # PROPS_LIST leads with the three "없음" rows, so sort by kind then index
    # to keep each body part contiguous in the generated table.
    prop_order = {'HEAD': 0, 'LEG': 1, 'ORNAMENT': 2}
    for p in sorted(props, key=lambda r: (prop_order[r['type']],
                                          int(r['index']))):
        rows.append((KIND[p['type']], int(p['index']), p['name'], 0, 0,
                     p['annex'], p['line']))

    seen = {}
    for kind, index, name, _, _, _, _ in rows:
        key = (kind, index)
        assert key not in seen, 'duplicate id %s -> %r / %r' % (
            key, seen[key], name)
        seen[key] = name

    def id_expr(kind, index):
        return 'HDItemId(HDItemType.%s, index: %d)' % (kind, index)

    def names_block(varname, doc, names, source):
        out = ['/// %s' % doc, '///', '/// 출처: %s' % source,
               'const List<String> %s = [' % varname]
        for i, n in enumerate(names):
            out.append('  %s, // %d' % (dart_str(n), i))
        out.append('];')
        return '\n'.join(out)

    def ids_block(varname, doc, ids):
        out = ['/// %s' % doc,
               'const List<HDItemId> %s = [' % varname]
        for i, (kind, index) in enumerate(ids):
            out.append('  %s, // %d' % (id_expr(kind, index), i))
        out.append('];')
        return '\n'.join(out)

    body = []
    body.append(HEADER)
    body.append(names_block(
        'legacyWeaponNames',
        '무기 이름 — `HDPlayer.weapon` 이 담는 정수의 이름 공간.',
        cpp_names['weapon'][1],
        'hd_res_string.cpp:%d' % cpp_names['weapon'][2]))
    body.append("/// 범위 밖 인덱스의 이름.\nconst String legacyUnknownWeaponName = %s;"
                % dart_str(cpp_names['weapon'][0]))
    body.append(names_block(
        'legacyShieldNames',
        '방패 이름 — `HDPlayer.shield` 가 담는 정수의 이름 공간.',
        cpp_names['shield'][1],
        'hd_res_string.cpp:%d' % cpp_names['shield'][2]))
    body.append("/// 범위 밖 인덱스의 이름.\nconst String legacyUnknownShieldName = %s;"
                % dart_str(cpp_names['shield'][0]))
    body.append(names_block(
        'legacyArmorNames',
        '갑옷 이름 — `HDPlayer.armor` 가 담는 정수의 이름 공간.\n'
        '///\n'
        "/// index 0 만 C++ 의 '없음' 이 아니라 '평상복' 이다 — Unity 포트와\n"
        '/// 현행 Dart(`player.dart:93`)가 이미 그 표기를 쓴다.',
        armor_names,
        'hd_res_string.cpp:%d' % cpp_names['armor'][2]))
    body.append("/// 범위 밖 인덱스의 이름.\nconst String legacyUnknownArmorName = %s;"
                % dart_str(cpp_names['armor'][0]))

    table = ['/// 아이템 카탈로그.',
             '///',
             '/// `detail` 은 이 표에서 전부 0 이다. 원작은 `ResId` 의 타입 바이트가',
             '/// 거친 태그(무기/방패/갑옷/장식)라 정확한 종류를 detail 로 되찾아야',
             '/// 했지만(`ObjItem.cs:477,507,545-560` 이 각각 0 / 0 / HEAD=1 · LEG=2 를',
             '/// 넣는다), 여기서는 `HDItemId.kind` 가 이미 정확하다. detail 은 향후',
             '/// 세분류를 위해 비워 둔다.',
             'final List<HDItem> itemTable = [']
    group = None
    for kind, index, name, atta, ac, annex, line in rows:
        head = _group_of(kind)
        if head != group:
            group = head
            table.append('  // ---- %s ----' % head)
        table.append(
            '  HDItem(id: %s, name: %s, '
            'param: HDItemParam(attaPow: %d, ac: %d, type: HDItemType.%s)%s), '
            '// ObjItem.cs:%d%s'
            % (id_expr(kind, index), dart_str(name), atta, ac, kind,
               (', annex: %s' % dart_str(annex)) if annex else '', line,
               ('  ' + NOTES[(kind, index)]) if (kind, index) in NOTES
               else ''))
    table.append('];')
    body.append('\n'.join(table))

    body.append('''final Map<int, HDItem> _byWire = {
  for (final item in itemTable) item.id.wire: item,
};

/// 카탈로그에서 [id] 의 항을 찾는다. 없으면 null.
HDItem? itemById(HDItemId id) => _byWire[id.wire];''')

    body.append(ids_block(
        'legacyWeaponIds',
        '`HDPlayer.weapon` 정수 → 카탈로그 항.\n'
        '///\n'
        '/// index 0(맨손)은 다섯 무기 계열 모두에 있으나 정수 공간에는 계열이\n'
        '/// 없으므로 `wield` 항을 대표로 가리킨다.',
        weapon_ids))
    body.append(ids_block('legacyShieldIds',
                          '`HDPlayer.shield` 정수 → 카탈로그 항.', shield_ids))
    body.append(ids_block('legacyArmorIds',
                          '`HDPlayer.armor` 정수 → 카탈로그 항.', armor_ids))

    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n\n'.join(body) + '\n')

    _write_cm2_constants(rows)

    print('%s: %d items (무기 %d · 방패 %d · 갑옷 %d · 장신구 %d)' % (
        os.path.relpath(OUT, ROOT), len(rows),
        len(empty_hand) + len(cpp_names['weapon'][1]) - 1,
        len(shield_ids), len(armor_ids), len(props)))


def _write_cm2_constants(rows):
    """The cm2 name constants for Item::Give/Take/Has.

    Named after (kind, index) rather than an English word: the original
    tables have Korean names only, and translating 61 of them would be
    inventing content. The Korean name rides along as a comment.
    """
    out = [
        '####### 아이템 상수 ########',
        '#',
        '# GENERATED — tools/convert_item.py 가 만든다. 손으로 고치지 말 것.',
        '# 형식은 flag4ep1.cm2 를 따른다. 최상위 include 로 읽을 것.',
        '#',
        '# 값은 HDItemId.wire = kind << 16 | detail << 8 | index 다',
        '# (ResId 하위 24비트와 같은 배치). 생 숫자를 쓰지 말고 이 이름을',
        '# 쓸 것 — 이름을 우회하면 충돌을 기계가 잡을 수 없다(부록 M-2).',
        '',
    ]
    group = None
    for kind, index, name, _, _, _, _ in rows:
        head = _group_of(kind)
        if head != group:
            group = head
            out.append('# %s' % head)
        wire = _WIRE[kind] * 0x10000 + index
        const = 'ITEM_%s_%d' % (_CM2_KIND[kind], index)
        out.append('variable(%s)' % const)
        out.append('%s.assign(%d)   # %s' % (const, wire, name))
        out.append('')
    with open(OUT_CM2, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out))


_WIRE = {
    'wield': 0, 'chop': 1, 'stab': 2, 'hit': 3, 'shoot': 4,
    'summonSingle': 5, 'summonMulti': 6, 'shield': 7, 'armor': 8,
    'head': 9, 'leg': 10, 'ornament': 11,
}

_CM2_KIND = {
    'wield': 'WIELD', 'chop': 'CHOP', 'stab': 'STAB', 'hit': 'HIT',
    'shoot': 'SHOOT', 'summonSingle': 'SUMMON_SINGLE',
    'summonMulti': 'SUMMON_MULTI', 'shield': 'SHIELD', 'armor': 'ARMOR',
    'head': 'HEAD', 'leg': 'LEG', 'ornament': 'ORNAMENT',
}


def _group_of(kind):
    if kind in ('wield', 'chop', 'stab', 'hit', 'shoot',
                'summonSingle', 'summonMulti'):
        return '무기'
    if kind == 'shield':
        return '방패'
    if kind == 'armor':
        return '갑옷'
    return {'head': '머리', 'leg': '다리', 'ornament': '장식'}[kind]


HEADER = '''// GENERATED — tools/convert_item.py 가 만든다. 손으로 고치지 말 것.
//
// 이름은 C++ 원작(`REF_hadar/src/hadar/hd_res_string.cpp`, CP949)에서,
// 수치는 Unity 포트(`REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs`)에서 온다.
// `assets/maps/books.json` 은 출처가 아니다 — 무기 5·방어구 3짜리 샘플이고
// 앱이 읽지도 않는다(GROUND_TRUTH 부록 H-3).
//
// **이름 공간과 수치는 원작에서 묶여 있지 않다.** C++ 은 `weapon` 정수를
// 이름 인덱스로만 쓰고 공격력은 `pow_of_weapon` 에 따로 넣는다
// (`hd_class_pc_player.cpp:212,451`). 실제로 배포된 스크립트가 같은
// `weapon=3` 에 `pow_of_weapon` 9(`L1_ep1d2.cm2:148`)와
// 100(`L1_ep1d0.cm2:169`)을 각각 넣는다. 아래 `attaPow` 는 **Unity 포트가
// 그 이름에 붙인 값**이지 C++ 이 정한 값이 아니다.

import 'item.dart';
import 'item_id.dart';
import 'item_type.dart';'''


if __name__ == '__main__':
    sys.exit(main())
