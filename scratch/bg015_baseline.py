"""BG-015 baseline: how close does an exported navmesh_3d come to each
house/shop's walls+plinth outline (request w x l grown by the plinth's 0.06 m)?
Read-only over a site.json. Usage: python bg015_baseline.py <site.json>"""
import json, sys, math

def seg_seg_dist(p, q, a, b):
    def pt_seg(p, a, b):
        ax, ay = a; bx, by = b; px, py = p
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy
        t = 0.0 if L < 1e-12 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L))
        return math.hypot(px - ax - t * dx, py - ay - t * dy)
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    d1, d2 = cross(a, b, p), cross(a, b, q)
    d3, d4 = cross(p, q, a), cross(p, q, b)
    if ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0)):
        return 0.0
    return min(pt_seg(p, a, b), pt_seg(q, a, b), pt_seg(a, p, q), pt_seg(b, p, q))

def inside(pt, poly):
    x, y = pt; c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c

def seg_poly(p, q, poly):
    if inside(p, poly) or inside(q, poly):
        return 0.0
    return min(seg_seg_dist(p, q, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))

d = json.load(open(sys.argv[1]))
m3 = d['walk']['navmesh_3d']
V = m3['vertices_m']; P = m3['polygons']
R = m3['agent']['radius_m']
count = {}
for poly in P:
    for k in range(len(poly)):
        a, b = poly[k], poly[(k + 1) % len(poly)]
        key = (min(a, b), max(a, b))
        count[key] = count.get(key, 0) + 1
edges = [k for k, c in count.items() if c == 1]
links = m3['links']
outl = {}
for b in d['buildings']:
    if b['kind'] not in ('house', 'shop'):
        continue
    r = b['request']; xf = b['transform']; o = xf['origin']; bx = xf['basis'][0]; bz = xf['basis'][2]
    hw, hl = r['width'] / 2 + 0.06, r['length'] / 2 + 0.06
    pts = []
    for lx, lz in ((-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl)):
        pts.append((o[0] + bx[0] * lx + bz[0] * lz, o[2] + bx[2] * lx + bz[2] * lz))
    outl[b['building_id']] = pts
# the door approach: within 1.2 m of an entry link's upper end or a door's outside_3d point
appro = []
for l in links:
    if l['kind'] == 'entry':
        appro.append((l['to_m'][0], l['to_m'][2]))
for dd in d['walk']['doors']:
    if dd.get('outside_3d_m'):
        appro.append((dd['outside_3d_m'][0], dd['outside_3d_m'][2]))
def near_door(p, q):
    return any(seg_seg_dist(p, q, a, a) < 1.2 for a in appro)
tot_in = tot_r = 0
for bid, poly in outl.items():
    bad_in = bad_r = 0; worst = 9
    box = (min(x for x, _ in poly) - 1, max(x for x, _ in poly) + 1, min(z for _, z in poly) - 1, max(z for _, z in poly) + 1)
    for a, b in edges:
        p = (V[a][0], V[a][2]); q = (V[b][0], V[b][2])
        if max(p[0], q[0]) < box[0] or min(p[0], q[0]) > box[1] or max(p[1], q[1]) < box[2] or min(p[1], q[1]) > box[3]:
            continue
        dist = seg_poly(p, q, poly)
        if dist >= R:
            continue
        if near_door(p, q):
            continue
        worst = min(worst, dist)
        bad_r += 1
        if dist <= 1e-9:
            bad_in += 1
    gaps = sum(1 for l in links if l['kind'] == 'gap' and seg_poly((l['from_m'][0], l['from_m'][2]), (l['to_m'][0], l['to_m'][2]), poly) < R)
    if bad_r or gaps:
        print(f"{bid}: edges<radius {bad_r} (into the outline {bad_in}), worst {worst:.3f} m; gap links<radius {gaps}")
    tot_in += bad_in; tot_r += bad_r
print('boundary edges', len(edges), 'radius', R, 'total edges<radius', tot_r, 'into', tot_in)
