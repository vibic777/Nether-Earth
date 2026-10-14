#!/usr/bin/env python3
# Контрибьютор: vibic777
# Генератор симметричных карт схватки -> data/maps/*.json.
# Карты — обычные данные: после генерации их можно править руками (docs/MAPS.md).
import json, random, os

OUT = os.path.join(os.path.dirname(__file__), '..', 'data', 'maps')

def T(w, h, name):
    # Преобразования клетки (x, y) для групп симметрии.
    return {
        'id': lambda x, y: (x, y),
        'mx': lambda x, y: (w - 1 - x, y),
        'mz': lambda x, y: (x, h - 1 - y),
        'r180': lambda x, y: (w - 1 - x, h - 1 - y),
        'r90': lambda x, y: (w - 1 - y, x),
        'r270': lambda x, y: (y, h - 1 - x),
        'tr': lambda x, y: (y, x),
        'atr': lambda x, y: (w - 1 - y, h - 1 - x),
    }[name]

GROUPS = {
    'r2': ['id', 'r180'],
    'c4': ['id', 'r90', 'r180', 'r270'],
    'd2': ['id', 'mx', 'mz', 'r180'],
    'd4': ['id', 'r90', 'r180', 'r270', 'mx', 'mz', 'tr', 'atr'],
}

GAME = json.load(open(os.path.join(os.path.dirname(__file__), '..', 'data', 'game.json'), encoding='utf-8'))
SIZES = GAME['skirmish']['map_sizes']

# Состав ресурсной зоны: смещения узлов от флага (терминал — клетка под узлом).
ZONE_KIT = {
    'OIL': [('DERRICK', 'Нефтевышка', -2, -1), ('DERRICK', 'Нефтевышка', 2, -1), ('OIL_STORAGE', 'Нефтехранилище', 0, 2)],
    'GAS': [('GAS_WELL', 'Газовая скважина', -2, 0), ('GAS_WELL', 'Газовая скважина', 2, 0)],
    'URANIUM': [('URANIUM_MINE', 'Урановый рудник', -2, 0), ('URANIUM_MINE', 'Урановый рудник', 2, 0)],
    'COAL': [('COAL_MINE', 'Угольная шахта', -2, 0), ('COAL_MINE', 'Угольная шахта', 2, 0)],
}
ZONE_TITLE = {'OIL': 'Нефть', 'GAS': 'Газ', 'URANIUM': 'Уран', 'COAL': 'Уголь'}

def scaled(players, bw, bh):
    w, h = SIZES[str(players)]
    return w, h, w / bw, h / bh

def build(mid, name, desc, bw, bh, group, base_starts, base_sites, seed, density, zones=()):
    players = len(GROUPS[group]) * len(base_starts) if group != 'd2' else 6
    w, h, kx, ky = scaled(players, bw, bh)
    sc = lambda c: [int(round(c[0] * kx)), int(round(c[1] * ky))]
    def scale_cells(cells):
        a = sc(cells[0])
        return [[a[0] + c[0] - cells[0][0], a[1] + c[1] - cells[0][1]] for c in cells]
    def scale_site(si):
        if si.get('mid'):
            return dict(si, cells=[[w // 2 - 1, h // 2 - 1], [w // 2, h // 2 - 1]], terminal=[w // 2 - 1, h // 2])
        cells = scale_cells(si['cells'])
        t = [cells[0][0] + si['terminal'][0] - si['cells'][0][0], cells[0][1] + si['terminal'][1] - si['cells'][0][1]]
        return dict(si, cells=cells, terminal=t)
    def mid_fix(b):
        # Старт в центре стороны (карта d2): ровно по оси, вместе со своими узлами.
        if not b.get('mid'):
            return b
        dx = (w // 2 - 1) - b['hq'][0][0]
        mv = lambda c: [c[0] + dx, c[1]]
        return dict(b, hq=[mv(c) for c in b['hq']], terminal=mv(b['terminal']),
                    own=[dict(o, cells=[mv(c) for c in o['cells']], terminal=mv(o['terminal'])) for o in b['own']])
    base_starts = [dict(b, hq=scale_cells(b['hq']), terminal=[scale_cells(b['hq'])[0][0] + b['terminal'][0] - b['hq'][0][0], scale_cells(b['hq'])[0][1] + b['terminal'][1] - b['hq'][0][1]],
                        own=[scale_site(o) for o in b.get('own', [])]) for b in base_starts]
    base_starts = [mid_fix(b) for b in base_starts]
    base_sites = [scale_site(si) for si in base_sites]
    # Точки на оси симметрии остаются на оси и после масштаба.
    zc = lambda c: [w // 2 if c[0] == bw // 2 else sc(c)[0], h // 2 if c[1] == bh // 2 else sc(c)[1]]
    zones = [(res, zc(c), r) for (res, c, r) in zones]
    rnd = random.Random(seed)
    fs = [T(w, h, n) for n in GROUPS[group]]
    grid = [['.'] * w for _ in range(h)]
    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            grid[y][x] = c
    # Препятствия: случайные пятна, затем все симметричные копии.
    for _ in range(int(w * h * density / 40 / len(fs))):
        kind = rnd.choice('ttssmb' if w * h > 1200 else 'tts')
        cx, cy = rnd.randrange(w), rnd.randrange(h)
        sw, sh = rnd.randint(1, 3), rnd.randint(1, 3)
        if kind == 'b':
            sw, sh = 2, 2
        for f in fs:
            for dx in range(sw):
                for dy in range(sh):
                    x, y = f(cx + dx, cy + dy)
                    put(x, y, kind)
    # Маленькие пруды.
    for _ in range(max(1, w * h // 900 // len(fs))):
        cx, cy = rnd.randrange(w), rnd.randrange(h)
        for f in fs:
            for dx in range(2):
                for dy in range(2):
                    x, y = f(cx + dx, cy + dy)
                    put(x, y, 'w')
    sites = []
    used = set()
    def add_site(s):
        cells = [tuple(c) for c in s['cells']]
        if any(c in used for c in cells) or tuple(s['terminal']) in used:
            return False
        for c in cells + [tuple(s['terminal'])]:
            used.add(c)
        sites.append(s)
        return True
    starts = []
    for f in fs:
        for b in base_starts:
            hq = [list(f(*c)) for c in b['hq']]
            if any(tuple(c) in used for c in hq):
                continue
            term = list(f(*b['terminal']))
            for c in hq + [term]:
                used.add(tuple(c))
            starts.append({'title': 'Штаб', 'hq': hq, 'terminal': term, 'radius': 28.0, 'metal': 1, 'chips': 1, 'power': 1})
            for s in b.get('own', []):
                extra = {'start': len(starts) - 1} if s['kind'] == 'ROBOT' else {}
                add_site(dict(s, cells=[list(f(*c)) for c in s['cells']], terminal=list(f(*s['terminal'])), **extra))
    zone_list = []
    for f in fs:
        for (res, c, r) in zones:
            fc = list(f(*c))
            if any(abs(z['center'][0] - fc[0]) + abs(z['center'][1] - fc[1]) < 2 * r for z in zone_list):
                if res != 'URANIUM':
                    print('  ВНИМАНИЕ: зона', res, fc, 'слилась с соседней')
                continue
            zid = len(zone_list)
            ok = True
            parts = []
            for (kind, title, dx, dy) in ZONE_KIT[res]:
                # смещение поворачивается вместе с картой: берём образ точки c+d
                p = list(f(c[0] + dx, c[1] + dy))
                q = list(f(c[0] + dx, c[1] + dy + 1))
                parts.append(S(kind, title, [p], q))
            zone = {'id': zid, 'resource': res, 'title': ZONE_TITLE[res], 'center': fc, 'radius': r}
            placed = [x for x in parts if add_site(dict(x, zone=zid))]
            if len(placed) != len(parts):
                print('  ВНИМАНИЕ: зона', res, fc, 'поставлена не полностью', len(placed), '/', len(parts))
            if placed:
                used.add(tuple(fc))
                zone_list.append(zone)
    for f in fs:
        for s in base_sites:
            add_site(dict(s, cells=[list(f(*c)) for c in s['cells']], terminal=list(f(*s['terminal']))))
    # Расчистка вокруг узлов и штабов.
    for (x, y) in list(used):
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                put(x + dx, y + dy, '.')
    for i, st in enumerate(starts):
        st['index'] = i
    # Морское кольцо по краю: вода для флота, сдвиг всех координат на m.
    m = int(SIZES.get('sea', 3))
    W, H = w + 2 * m, h + 2 * m
    rows = []
    for y in range(H):
        row = ''
        for x in range(W):
            ix, iy = x - m, y - m
            row += grid[iy][ix] if 0 <= ix < w and 0 <= iy < h else 'w'
        rows.append(row)
    sh = lambda c: [c[0] + m, c[1] + m]
    for st in starts:
        st['hq'] = [sh(c) for c in st['hq']]
        st['terminal'] = sh(st['terminal'])
    for si in sites:
        si['cells'] = [sh(c) for c in si['cells']]
        si['terminal'] = sh(si['terminal'])
    for z in zone_list:
        z['center'] = sh(z['center'])
    data = {
        'id': mid, 'name': name, 'description': desc, 'players': len(starts),
        'symmetry': group, 'width': W, 'height': H,
        'rows': rows, 'starts': starts, 'sites': sites, 'zones': zone_list,
    }
    with open(os.path.join(OUT, mid + '.json'), 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
    print(mid, len(starts), 'стартов', len(sites), 'узлов')

def S(kind, title, cells, term, radius=0.0, metal=0, chips=0, power=0):
    return {'kind': kind, 'title': title, 'cells': cells, 'terminal': term, 'radius': radius, 'metal': metal, 'chips': chips, 'power': power}

def own(ex, ey, tx, ty, rx, ry, rtx, rty, wx, wy, wtx, wty):
    # У каждого старта: своя жила, вышка и цех (пехота, мото, инженер).
    return [S('EXTRACTOR', 'Жила', [[ex, ey]], [tx, ty], 0.0, 3), S('RELAY', 'Вышка', [[rx, ry]], [rtx, rty], 30.0),
            S('ROBOT', 'Цех', [[wx, wy]], [wtx, wty])]

def classic():
    # Исходная вытянутая карта (тесты опираются на её координаты).
    w, h = 48, 14
    g = [['.'] * w for _ in range(h)]
    def rect(x, y, rw, rh, c):
        for i in range(rw):
            for j in range(rh):
                g[y + j][x + i] = c
    for z in range(h):
        if z < 6 or z > 7:
            g[z][16] = g[z][17] = 'w'
    rect(8, 1, 3, 4, 't'); rect(9, 9, 2, 4, 't'); rect(24, 2, 3, 2, 's'); rect(26, 10, 4, 3, 's')
    rect(34, 0, 4, 5, 'm'); rect(40, 9, 5, 5, 'm'); rect(21, 2, 2, 2, 'b'); rect(29, 5, 2, 2, 'b'); rect(44, 4, 2, 3, 'b')
    data = {
        'id': 'classic', 'name': 'Классика', 'players': 2, 'symmetry': 'нет',
        'description': 'Исходная вытянутая карта 1 на 1: база игрока слева, база противника справа.',
        'width': w, 'height': h, 'rows': [''.join(r) for r in g],
        'starts': [
            {'index': 0, 'title': 'Штаб', 'hq': [[0, 6], [0, 7]], 'terminal': [1, 6], 'radius': 42.0, 'metal': 1, 'chips': 0, 'power': 1,
             'roster': [['WALKER', 2, 2], ['UAV', 2, 4], ['ROTOR', 2, 6], ['TRACK', 2, 8], ['BIKE', 2, 10], ['TROOPER', 2, 12], ['ENGINEER', 4, 7]]},
            {'index': 1, 'title': 'База', 'hq': [[46, 8], [47, 8]], 'terminal': [46, 7], 'radius': 24.0, 'metal': 0, 'chips': 0, 'power': 0,
             'roster': [['TRACK', 43, 7], ['TROOPER', 45, 7], ['BIKE', 41, 7], ['ENGINEER', 40, 7]]},
        ],
        'sites': [
            S('EXTRACTOR', 'Жила', [[12, 8]], [12, 7], 0.0, 3), S('RELAY', 'Вышка', [[19, 8]], [19, 7], 44.0),
            S('AIR', 'Аэродром', [[23, 8]], [23, 7]), S('EXTRACTOR', 'Чипы', [[27, 8]], [27, 7], 0.0, 0, 2),
            S('FACTORY', 'Тяжёлый', [[32, 8], [33, 8]], [31, 7]), S('EXTRACTOR', 'Станция', [[36, 8]], [36, 7], 0.0, 0, 0, 3),
            S('RELAY', 'Вышка', [[38, 8]], [38, 7], 30.0), S('ROBOT', 'Цех', [[42, 8]], [42, 7]),
        ],
    }
    with open(os.path.join(OUT, 'classic.json'), 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
    print('classic 2')

MID = lambda w, h: [
    dict(S('FACTORY', 'Тяжёлый завод', [[w // 2 - 1, h // 2 - 1], [w // 2, h // 2 - 1]], [w // 2 - 1, h // 2]), mid=True),
]

classic()
build('duel', 'Дуэль', 'Симметричная карта 1 на 1 (поворот на 180°).', 44, 28, 'r2',
      [{'hq': [[3, 13], [3, 14]], 'terminal': [4, 13], 'own': own(8, 10, 8, 11, 12, 15, 12, 14, 6, 18, 7, 18)}],
      [S('ROBOT', 'Цех', [[14, 5]], [14, 6]), S('EXTRACTOR', 'Чипы', [[18, 22]], [18, 21], 0.0, 0, 2),
       S('AIR', 'Аэродром', [[20, 9]], [20, 10]), S('RELAY', 'Вышка', [[21, 18]], [21, 17], 30.0),
       S('EXTRACTOR', 'Станция', [[10, 22]], [10, 21], 0.0, 0, 0, 3)] + MID(44, 28), 11, 1.0,
      [('OIL', [12, 7], 3), ('COAL', [16, 21], 3), ('GAS', [30, 4], 3), ('URANIUM', [22, 14], 4)])
build('cross', 'Перекрёсток', 'Четыре угла, поворотная симметрия на 90°. Центр — тяжёлый завод.', 48, 48, 'c4',
      [{'hq': [[4, 4], [5, 4]], 'terminal': [4, 5], 'own': own(9, 4, 9, 5, 11, 11, 11, 12, 4, 10, 5, 10)}],
      [S('ROBOT', 'Цех', [[16, 6]], [16, 7]), S('EXTRACTOR', 'Чипы', [[6, 17]], [7, 17], 0.0, 0, 2),
       S('EXTRACTOR', 'Станция', [[18, 18]], [18, 19], 0.0, 0, 0, 3), S('AIR', 'Аэродром', [[23, 12]], [23, 13]),
       S('RELAY', 'Вышка', [[20, 23]], [20, 22], 30.0)] + MID(48, 48), 22, 1.0,
      [('OIL', [13, 17], 3), ('COAL', [21, 7], 3), ('GAS', [8, 33], 3), ('URANIUM', [24, 24], 4)])
build('six', 'Шестеро', 'Шесть стартов, зеркальная симметрия по обеим осям: четыре угла и два центра длинных сторон.', 66, 40, 'd2',
      [{'hq': [[4, 4], [5, 4]], 'terminal': [4, 5], 'own': own(9, 4, 9, 5, 10, 10, 10, 11, 4, 10, 5, 10)},
       {'mid': True, 'hq': [[32, 3], [33, 3]], 'terminal': [32, 4], 'own': own(27, 4, 27, 5, 28, 10, 28, 11, 38, 5, 38, 6)}],
      [S('ROBOT', 'Цех', [[18, 9]], [18, 10]), S('EXTRACTOR', 'Чипы', [[5, 15]], [6, 15], 0.0, 0, 2),
       S('EXTRACTOR', 'Станция', [[20, 16]], [20, 17], 0.0, 0, 0, 3), S('AIR', 'Аэродром', [[32, 13]], [32, 14]),
       S('RELAY', 'Вышка', [[24, 19]], [25, 19], 30.0)] + MID(66, 40), 33, 0.9,
      [('OIL', [12, 13], 3), ('COAL', [24, 7], 3), ('GAS', [22, 15], 3), ('URANIUM', [33, 20], 4), ('OIL', [33, 9], 3), ('COAL', [26, 14], 3), ('GAS', [40, 14], 3)])
build('eight', 'Восьмёрка', 'Восемь стартов по кругу, полная симметрия квадрата (повороты и отражения).', 64, 64, 'd4',
      [{'hq': [[20, 3], [21, 3]], 'terminal': [20, 4], 'own': own(25, 5, 25, 6, 21, 10, 21, 11, 16, 6, 16, 7)}],
      [S('ROBOT', 'Цех', [[13, 13]], [14, 14]), S('EXTRACTOR', 'Чипы', [[29, 10]], [29, 11], 0.0, 0, 2),
       S('EXTRACTOR', 'Станция', [[22, 19]], [22, 20], 0.0, 0, 0, 3), S('AIR', 'Аэродром', [[27, 22]], [27, 23]),
       S('RELAY', 'Вышка', [[30, 26]], [30, 25], 30.0)] + MID(64, 64), 44, 0.8,
      [('OIL', [15, 21], 3), ('COAL', [27, 15], 3), ('GAS', [10, 30], 3), ('URANIUM', [32, 32], 4)])
