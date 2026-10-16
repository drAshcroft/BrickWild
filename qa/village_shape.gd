class_name VillageShape
extends RefCounted
## The arrangement of a village, measured exactly as the world survey measures
## a real one (docs/SETTLEMENT_TESTSET.md). This is a PORT of `measure()` in
## tools/settlements/survey.py, key for key and definition for definition, so
## a generated village can be set against the 109 real distributions without
## a second idea of what "elongation" or "contour-following" means.
##
##   survey.py measure-plan --plan p.json [--terrain t.json] --out m.json
##
## measures the same plan in Python; tools/shape_parity.gd holds the two to
## the same numbers. Change a definition HERE and THERE, never one alone.
##
## Everything is worked in the SURVEY frame: x east, y NORTH. A plan point
## (x, z) with +z south is (x, -z) here, so a bearing (0 = north, clockwise)
## means the same thing on both sides.
##
## The ground: `plan.spec.terrain` when there is one, flat zero otherwise.
## Heights are `VillageTerrain.height_at` (the survey's Dem is the same
## bilinear surface). Slopes are NOT `gradient_at`: the survey takes
## `np.gradient` over the grid NODES (central inside, one-sided at the edge)
## and interpolates that field bilinearly, which on real ground differs from a
## central difference of the interpolated surface. The node-field gradient is
## reproduced here, because the definition is the survey's.

const NEAR_CENTRE_M := 250.0      ## buildings this close to the origin count triple for the body
const CLUSTER_LINK_M := 45.0      ## closer than this: one settlement body
const BODY_ZONE_M := 40.0         ## streets, squares, worship this near the body's hull are its own
const WATER_ZONE_M := 60.0        ## standing water this near the hull is adjacent
const FRONTAGE_REACH_M := 40.0    ## a house farther than this from any way has no street
const FRONTAGE_TOL_DEG := 15.0
const STEEP_GRADE := 0.08         ## 8 %: steep ground for the contour rules
const STEEP_STREET_M := 100.0     ## street length on steep ground before contour share means anything
const STEEP_HOUSES := 10
const CONTOUR_TOL_DEG := 30.0
const MIN_FOOTPRINT_M2 := 6.0     ## parse_site's floor
const NODE_TOL_M := 0.5           ## survey.py PLAN_NODE_TOL_M
const BINS := 36
const WORSHIP: Array[StringName] = [&"church", &"temple"]   # a shrine is a small church request
## survey.py MINOR_PATH: a way of these classes is a path, not a street
const MINOR_PATH: Array[String] = ["footway", "path", "steps", "cycleway", "bridleway", "pedestrian"]


## Every survey metric of one plan, the survey's keys.
static func measure(plan: VillagePlan) -> Dictionary:
	var terrain: VillageTerrain = plan.spec.terrain if plan.spec != null else null
	return measure_geo(geo_of(plan), Ground.new(terrain))


## The plan as the survey's `geo`: buildings (polygons), roads and paths
## (polyline, node ids, class, bridge, steps), water, worship points, squares,
## a city wall. Survey frame.
static func geo_of(plan: VillagePlan) -> Dictionary:
	var buildings: Array[PackedVector2Array] = []
	var worship: Array[Vector2] = []
	for b in plan.buildings:
		var poly := _flip(Placement.world_rect(b["placement"], b["transform"], true))
		var req: BuildingRequest = b["request"]
		if req != null and req.kind in WORSHIP:
			worship.append(_centroid(poly))
		if absf(_area(poly)) >= MIN_FOOTPRINT_M2:
			buildings.append(poly)
	var water: Array[PackedVector2Array] = []
	for w in plan.water:
		if (w["poly"] as PackedVector2Array).size() >= 3:
			water.append(_flip(w["poly"]))
	var lines: Array = []
	var classes: Array[String] = []
	for r in plan.roads:
		var pts: PackedVector2Array = r["points"]
		if pts.size() >= 2:
			lines.append(_flip(pts))
			classes.append(String(r["class"]))
	var net := road_network(lines)
	var roads: Array[Dictionary] = []
	var paths: Array[Dictionary] = []
	for i in range(lines.size()):
		var hw := "steps" if classes[i].contains("steps") else classes[i]
		var line: PackedVector2Array = net["points"][i]
		var bridge := false
		for w in water:
			if _dist_line_poly(line, w) <= 0.0:
				bridge = true
				break
		var item := {"line": line, "nodes": net["ids"][i], "hw": hw, "bridge": bridge,
			"tunnel": false, "steps": hw == "steps"}
		if hw in MINOR_PATH:
			paths.append(item)
		else:
			roads.append(item)
	var squares: Array[PackedVector2Array] = []
	for c in plan.commons:
		if (c["poly"] as PackedVector2Array).size() >= 3:
			squares.append(_flip(c["poly"]))
	var wall := plan.spec != null and plan.spec.enclosure == &"wall"
	return {"buildings": buildings, "roads": roads, "paths": paths, "water_poly": water,
		"worship": worship, "squares": squares, "city_wall": wall}


## survey.py `plan_road_network`: junction vertices where a vertex lies on
## another road or two segments cross, then one node per cluster of vertices
## within NODE_TOL_M. {"points": [PackedVector2Array], "ids": [Array[int]]}.
static func road_network(lines: Array, tol := NODE_TOL_M) -> Dictionary:
	var ins: Array = []
	for _l in lines:
		ins.append([])
	for i in range(lines.size()):
		var li: PackedVector2Array = lines[i]
		for j in range(lines.size()):
			if i == j:
				continue
			var lj: PackedVector2Array = lines[j]
			for v in li:
				for k in range(lj.size() - 1):
					var hit := _seg_closest(v, lj[k], lj[k + 1])
					var q: Vector2 = hit[0]
					if q.distance_to(v) <= tol:
						ins[j].append([k, hit[1], q])
			if j > i:
				for a in range(li.size() - 1):
					for b2 in range(lj.size() - 1):
						var x := _seg_cross(li[a], li[a + 1], lj[b2], lj[b2 + 1])
						if not x.is_empty():
							ins[i].append([a, x[1], x[0]])
							ins[j].append([b2, x[2], x[0]])
	var out_pts: Array = []
	for i in range(lines.size()):
		var li: PackedVector2Array = lines[i]
		var pts := PackedVector2Array([li[0]])
		for k in range(li.size() - 1):
			var here: Array = (ins[i] as Array).filter(func(e): return int(e[0]) == k)
			here.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
			for e in here:
				var q: Vector2 = e[2]
				if q.distance_to(pts[pts.size() - 1]) > tol and q.distance_to(li[k + 1]) > tol:
					pts.append(q)
			pts.append(li[k + 1])
		out_pts.append(pts)
	var nodes: Array[Vector2] = []
	var out_ids: Array = []
	for pts in out_pts:
		var ids: Array[int] = []
		for p in pts:
			var nid := -1
			for n in range(nodes.size()):
				if nodes[n].distance_to(p) <= tol:
					nid = n
					break
			if nid < 0:
				nid = nodes.size()
				nodes.append(p)
			if ids.is_empty() or ids[ids.size() - 1] != nid:
				ids.append(nid)
		out_ids.append(ids)
	return {"points": out_pts, "ids": out_ids}


## survey.py `measure()`, line for line.
static func measure_geo(geo: Dictionary, dem: Ground) -> Dictionary:
	var B: Array[PackedVector2Array] = geo["buildings"]
	var m := {"osm_buildings": B.size()}
	if B.is_empty():
		m["usable"] = false
		return m
	m["usable"] = true
	var n := B.size()
	var cent := PackedVector2Array()
	var area := PackedFloat64Array()
	for p in B:
		cent.append(_centroid(p))
		area.append(absf(_area(p)))
	var lab := _clusters(cent, CLUSTER_LINK_M)
	var k := 0
	for l in lab:
		k = maxi(k, l + 1)
	var sizes := PackedInt32Array()
	sizes.resize(k)
	var score := PackedFloat64Array()
	score.resize(k)
	for i in range(n):
		sizes[lab[i]] += 1
		score[lab[i]] += 1.0 + (2.0 if cent[i].length() < NEAR_CENTRE_M else 0.0)
	var main := 0
	for c in range(k):
		if score[c] > score[main]:
			main = c
	var mc := PackedVector2Array()
	var ma := PackedFloat64Array()
	var mb: Array[PackedVector2Array] = []
	for i in range(n):
		if lab[i] == main:
			mc.append(cent[i])
			ma.append(area[i])
			mb.append(B[i])
	m["body_buildings"] = mc.size()
	m["body_share"] = _r(float(mc.size()) / n, 3)
	var ge5 := 0
	for s in sizes:
		if s >= 5:
			ge5 += 1
	m["clusters_ge5"] = ge5
	m["footprint_median_m2"] = _r(_pct(ma, 50.0), 1)
	m["footprint_p90_m2"] = _r(_pct(ma, 90.0), 1)
	var mean_a := _mean(ma)
	var var_a := 0.0
	for a in ma:
		var_a += (a - mean_a) * (a - mean_a)
	m["footprint_cv"] = _r(sqrt(var_a / ma.size()) / mean_a, 3)
	var hull := _hull(mc)
	var hull_area := absf(_area(hull)) if hull.size() >= 3 else 0.0
	var hull_a := maxf(hull_area, 1.0)
	m["body_hull_ha"] = _r(hull_a / 1e4, 2)
	m["coverage"] = _r(_sum(ma) / hull_a, 3)
	m["compactness"] = _r(4.0 * PI * hull_a / pow(maxf(_hull_length(hull), 1.0), 2), 3)
	if mc.size() >= 3:
		var d := PackedFloat64Array()
		for i in range(mc.size()):
			var best := INF
			for j in range(mc.size()):
				if i != j:
					best = minf(best, mc[i].distance_to(mc[j]))
			d.append(best)
		m["clark_evans"] = _r(_mean(d) / (0.5 / sqrt(mc.size() / hull_a)), 3)
		m["nn_median_m"] = _r(_pct(d, 50.0), 1)
		# np.cov (ddof 1) eigenvalues; only their ratio is used
		var c0 := _mean2(mc)
		var sxx := 0.0
		var syy := 0.0
		var sxy := 0.0
		for p in mc:
			var q := p - c0
			sxx += q.x * q.x
			syy += q.y * q.y
			sxy += q.x * q.y
		var dn := float(mc.size() - 1)
		sxx /= dn
		syy /= dn
		sxy /= dn
		var mid := (sxx + syy) * 0.5
		var rad := sqrt(pow((sxx - syy) * 0.5, 2) + sxy * sxy)
		m["elongation"] = _r(sqrt((mid + rad) / maxf(mid - rad, 1e-6)), 2)
	var centre := _mean2(mc)
	m["body_offset_m"] = _r(centre.length(), 1)

	# --- streets
	var seg_b := PackedFloat64Array()
	var seg_w := PackedFloat64Array()
	var seg_mid := PackedVector2Array()
	var deg := {}
	var road_len := 0.0
	var roads: Array[Dictionary] = geo["roads"]
	var paths: Array[Dictionary] = geo["paths"]
	for r in roads:
		var c: PackedVector2Array = r["line"]
		var nds: Array = r["nodes"]
		for i in range(nds.size()):
			var add := 1 if i == 0 or i == nds.size() - 1 else 2
			deg[nds[i]] = int(deg.get(nds[i], 0)) + add
		for i in range(c.size() - 1):
			var dxy := c[i + 1] - c[i]
			var mpt := (c[i] + c[i + 1]) * 0.5
			if _dist_point_hull(mpt, hull) <= BODY_ZONE_M:
				seg_b.append(_bearing(dxy.x, dxy.y))
				seg_w.append(dxy.length())
				seg_mid.append(mpt)
				road_len += dxy.length()
	var hull_ha := maxf(hull_a / 1e4, 0.01)
	m["road_km_per_ha"] = _r(road_len / 1000.0 / hull_ha, 3)
	m["orientation_order"] = _r(orientation_order(seg_b, seg_w), 3) if seg_b.size() > 0 else null
	var ends := 0
	var inter := 0
	for v in deg.values():
		if int(v) == 1:
			ends += 1
		elif int(v) >= 3:
			inter += 1
	m["dead_end_ratio"] = _r(float(ends) / maxi(ends + inter, 1), 3)
	m["intersections_per_ha"] = _r(inter / hull_ha, 3)
	var steps := 0
	var bridges := 0
	for r in paths:
		if r["steps"]:
			steps += 1
	for r in roads + paths:
		if r["bridge"]:
			bridges += 1
	m["steps_ways"] = steps
	m["bridges"] = bridges
	m["tunnels"] = 0

	# --- frontage: is a house turned toward its street?
	var all_lines: Array[PackedVector2Array] = []
	for r in roads + paths:
		all_lines.append(r["line"])
	var align := PackedFloat64Array()
	var setback := PackedFloat64Array()
	if not all_lines.is_empty():
		for p in mb:
			var ax := _long_axis(p)
			var pc := _centroid(p)
			var j := 0
			var best := INF
			for li in range(all_lines.size()):
				var dd := _dist_point_line(pc, all_lines[li])
				if dd < best:
					best = dd
					j = li
			var ln: PackedVector2Array = all_lines[j]
			var dist := _dist_line_poly(ln, p)
			if dist > FRONTAGE_REACH_M:
				continue
			var s := _project(ln, pc)
			var a0 := _interpolate(ln, maxf(s - 3.0, 0.0))
			var a1 := _interpolate(ln, minf(s + 3.0, _length(ln)))
			var rb := _bearing(a1.x - a0.x, a1.y - a0.y)
			var hb := _bearing(ax.x, ax.y)
			align.append(_angle_mod(hb - rb, 90.0))
			setback.append(dist)
	if not align.is_empty():
		var ok := 0
		for a in align:
			if a < FRONTAGE_TOL_DEG:
				ok += 1
		m["frontage_aligned"] = _r(float(ok) / align.size(), 3)
		m["setback_median_m"] = _r(_pct(setback, 50.0), 1)
		m["road_reached"] = _r(float(align.size()) / mb.size(), 3)

	# --- terrain under the body
	var hz := PackedFloat64Array()
	var gxs := PackedFloat64Array()
	var gys := PackedFloat64Array()
	var slope := PackedFloat64Array()
	for p in mc:
		hz.append(dem.height(p))
		var g := dem.grad(p)
		gxs.append(g.x)
		gys.append(g.y)
		slope.append(Vector2(g.x, g.y).length() * 100.0)
	var med_h := _pct(hz, 50.0)
	m["elev_body_m"] = _r(med_h, 1)
	m["elev_span_m"] = _r(_pct(hz, 95.0) - _pct(hz, 5.0), 1)
	m["slope_median_pct"] = _r(_pct(slope, 50.0), 2)
	m["slope_p90_pct"] = _r(_pct(slope, 90.0), 2)
	m["relief_disc_m"] = _r(dem.z_max() - dem.z_min(), 1)
	m["body_elev_pctile"] = _r(float(dem.count_below(med_h)) / dem.z.size(), 3)
	if seg_mid.size() > 0:
		var steep_w := 0.0
		var along := 0.0
		for i in range(seg_mid.size()):
			var sg := dem.grad(seg_mid[i])
			if Vector2(sg.x, sg.y).length() > STEEP_GRADE:
				steep_w += seg_w[i]
				var contour_b := _bearing(-sg.y, sg.x)
				if _angle_mod(seg_b[i] - contour_b, 180.0) < CONTOUR_TOL_DEG:
					along += seg_w[i]
		if steep_w > STEEP_STREET_M:
			m["street_contour_share"] = _r(along / steep_w, 3)
			m["street_steep_share"] = _r(steep_w / maxf(_sum(seg_w), 1.0), 3)
	var steep_n := 0
	var follow := 0
	for i in range(mc.size()):
		if slope[i] > STEEP_GRADE * 100.0:
			steep_n += 1
			var ax2 := _long_axis(mb[i])
			var cb := _bearing(-gys[i], gxs[i])
			if _angle_mod(_bearing(ax2.x, ax2.y) - cb, 180.0) < CONTOUR_TOL_DEG:
				follow += 1
	if steep_n >= STEEP_HOUSES:
		m["house_contour_share"] = _r(float(follow) / steep_n, 3)

	# --- water
	var water: Array[PackedVector2Array] = geo["water_poly"]
	if not water.is_empty():
		var wd := PackedFloat64Array()
		var near := 0
		for p in mc:
			var best := INF
			for w in water:
				best = minf(best, _dist_point_poly(p, w))
			wd.append(best)
			if best < 30.0:
				near += 1
		m["water_within_30m"] = _r(float(near) / mc.size(), 3)
		m["water_median_m"] = _r(_pct(wd, 50.0), 1)
		var adj := 0.0
		for w in water:
			if _dist_poly_hull(w, hull) <= WATER_ZONE_M:
				adj = maxf(adj, absf(_area(w)))
		m["adjacent_water_ha"] = _r(adj / 1e4, 2)
		var over := 0
		for p in mb:
			var wet := 0.0
			for w in water:
				for piece in Geometry2D.intersect_polygons(p, w):
					wet += absf(_area(piece))
			if wet > 0.5 * absf(_area(p)):
				over += 1
		m["over_water_share"] = _r(float(over) / mb.size(), 3)
	else:
		m["water_within_30m"] = 0.0
		m["over_water_share"] = 0.0
	m["coast_in_disc"] = false
	m["waterway_kinds"] = []
	m["piers"] = 0

	# --- landmarks and edges
	m["city_wall"] = bool(geo["city_wall"])
	var sq := 0
	for s in (geo["squares"] as Array):
		if _dist_poly_hull(s, hull) <= BODY_ZONE_M:
			sq += 1
	m["squares"] = sq
	var w_in: Array[Vector2] = []
	for p in (geo["worship"] as Array):
		if _dist_point_hull(p, hull) < BODY_ZONE_M:
			w_in.append(p)
	m["worship"] = w_in.size()
	if not w_in.is_empty():
		var wz := -INF
		for p in w_in:
			wz = maxf(wz, dem.height(p))
		var below := 0
		for h in hz:
			if h < wz:
				below += 1
		m["worship_elev_pctile"] = _r(float(below) / hz.size(), 3)
		var rg := sqrt(hull_a / PI)
		var dmin := INF
		for p in w_in:
			dmin = minf(dmin, p.distance_to(centre))
		m["worship_centrality"] = _r(dmin / rg, 3)
	return m


## Boeing's street-orientation order over 36 bins of 0..180 (both directions
## folded); the perfect-grid entropy there is 2 bins, not Boeing's 4 of 360.
static func orientation_order(bearings: PackedFloat64Array, weights: PackedFloat64Array) -> float:
	var total := _sum(weights)
	if bearings.is_empty() or total <= 0.0:
		return NAN
	var hist := PackedFloat64Array()
	hist.resize(BINS)
	for i in range(bearings.size()):
		var b := fposmod(bearings[i], 180.0)
		hist[mini(int(floor(b / (180.0 / BINS))), BINS - 1)] += weights[i]
	var hsum := _sum(hist)
	var h := 0.0
	for v in hist:
		if v > 0.0:
			var p := v / hsum
			h -= p * log(p)
	var hmax := log(float(BINS))
	var hg := log(2.0)
	return 1.0 - pow((h - hg) / (hmax - hg), 2) if h > hg else 1.0


# ------------------------------------------------------------------ ground

## The survey's Dem: heights and the node-gradient field, survey frame.
class Ground:
	var terrain: VillageTerrain = null
	var x0 := 0.0
	var y0 := 0.0
	var step := 10.0
	var nx := 2
	var ny := 2
	var z := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])   # north-up rows; flat = zeros
	var gx := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var gy := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var _sorted := PackedFloat64Array()

	func _init(t: VillageTerrain) -> void:
		if t == null or not t.valid():
			_sorted = z.duplicate()
			return
		terrain = t
		nx = t.cols
		ny = t.rows
		step = t.cell_m
		x0 = t.origin.x
		y0 = -(t.origin.y + (ny - 1) * step)
		z.resize(nx * ny)
		for k in range(ny):
			for c in range(nx):
				z[k * nx + c] = t.heights[(ny - 1 - k) * nx + c]
		gx.resize(nx * ny)
		gy.resize(nx * ny)
		for k in range(ny):
			for c in range(nx):
				gx[k * nx + c] = _diff(z, k * nx + c, c, nx, 1)
				gy[k * nx + c] = _diff(z, k * nx + c, k, ny, nx)
		_sorted = z.duplicate()
		_sorted.sort()

	## np.gradient along one axis: central inside, one-sided at the ends.
	func _diff(f: PackedFloat64Array, i: int, at: int, count: int, stride: int) -> float:
		if at == 0:
			return (f[i + stride] - f[i]) / step
		if at == count - 1:
			return (f[i] - f[i - stride]) / step
		return (f[i + stride] - f[i - stride]) / (2.0 * step)

	## Dem.height. Inside the grid VillageTerrain.height_at is the same
	## bilinear surface, and it is the plan's own reader, so it answers.
	func height(p: Vector2) -> float:
		if terrain == null:
			return 0.0
		return terrain.height_at(Vector2(p.x, -p.y))

	## Dem.grad: (dh/dx east, dh/dy north).
	func grad(p: Vector2) -> Vector2:
		if terrain == null:
			return Vector2.ZERO
		return Vector2(_bil(gx, p), _bil(gy, p))

	func _bil(field: PackedFloat64Array, p: Vector2) -> float:
		var fx := clampf((p.x - x0) / step, 0.0, nx - 1.001)
		var fy := clampf((p.y - y0) / step, 0.0, ny - 1.001)
		var i0 := int(fy)
		var j0 := int(fx)
		var ty := fy - i0
		var tx := fx - j0
		var i := i0 * nx + j0
		return (field[i] * (1 - tx) * (1 - ty) + field[i + 1] * tx * (1 - ty)
			+ field[i + nx] * (1 - tx) * ty + field[i + nx + 1] * tx * ty)

	func z_max() -> float:
		return _sorted[_sorted.size() - 1]

	func z_min() -> float:
		return _sorted[0]

	## np.searchsorted(sorted z, v), left side: nodes strictly below v.
	func count_below(v: float) -> int:
		return _sorted.bsearch(v, true)


# ---------------------------------------------------------------- geometry

static func _flip(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(Vector2(p.x, -p.y))
	return out


static func _r(v: float, places: int) -> float:
	return snappedf(v, pow(10.0, -places))


static func _bearing(dx: float, dy: float) -> float:
	return rad_to_deg(atan2(dx, dy))


static func _angle_mod(a: float, period: float) -> float:
	var x := fposmod(a, period)
	return minf(x, period - x)


static func _sum(a: PackedFloat64Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s


static func _mean(a: PackedFloat64Array) -> float:
	return _sum(a) / a.size()


static func _mean2(a: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for p in a:
		s += p
	return s / a.size()


## np.percentile, linear interpolation.
static func _pct(a: PackedFloat64Array, q: float) -> float:
	var s := a.duplicate()
	s.sort()
	var pos := q / 100.0 * (s.size() - 1)
	var lo := int(floor(pos))
	var hi := mini(lo + 1, s.size() - 1)
	return s[lo] + (s[hi] - s[lo]) * (pos - lo)


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in range(poly.size()):
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## The area centroid (shapely's), the vertex mean for a degenerate polygon.
static func _centroid(poly: PackedVector2Array) -> Vector2:
	var a := _area(poly)
	if absf(a) < 1e-9:
		var s := Vector2.ZERO
		for p in poly:
			s += p
		return s / poly.size()
	var cx := 0.0
	var cy := 0.0
	for i in range(poly.size()):
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var cr := p.x * q.y - q.x * p.y
		cx += (p.x + q.x) * cr
		cy += (p.y + q.y) * cr
	return Vector2(cx, cy) / (6.0 * a)


## The long edge of a footprint's rectangle (minimum_rotated_rectangle of a
## rectangle is itself): e1 unless e2 is strictly longer, as survey.py.
static func _long_axis(poly: PackedVector2Array) -> Vector2:
	var e1 := poly[1] - poly[0]
	var e2 := poly[2] - poly[1]
	return e1 if e1.length() >= e2.length() else e2


## Components of "closer than `link`", labelled in index order (scipy's
## connected_components numbering).
static func _clusters(cent: PackedVector2Array, link: float) -> PackedInt32Array:
	var n := cent.size()
	var lab := PackedInt32Array()
	lab.resize(n)
	lab.fill(-1)
	var label_n := 0
	for s in range(n):
		if lab[s] >= 0:
			continue
		lab[s] = label_n
		var stack: Array[int] = [s]
		while not stack.is_empty():
			var i: int = stack.pop_back()
			for j in range(n):
				if lab[j] < 0 and cent[i].distance_to(cent[j]) <= link:
					lab[j] = label_n
					stack.append(j)
		label_n += 1
	return lab


## Convex hull, open (no repeated first point). A line for collinear points,
## one point for one.
static func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts.duplicate()
	var h := Geometry2D.convex_hull(pts)
	if h.size() >= 2 and h[0].is_equal_approx(h[h.size() - 1]):
		h.remove_at(h.size() - 1)
	return h


## shapely's hull length: the perimeter of a polygon, the length of a line.
static func _hull_length(h: PackedVector2Array) -> float:
	if h.size() < 2:
		return 0.0
	if h.size() == 2 or absf(_area(h)) < 1e-9:
		var far := 0.0
		for p in h:
			for q in h:
				far = maxf(far, p.distance_to(q))
		return far
	var s := 0.0
	for i in range(h.size()):
		s += h[i].distance_to(h[(i + 1) % h.size()])
	return s


static func _seg_closest(p: Vector2, a: Vector2, b: Vector2) -> Array:
	var d := b - a
	var l2 := d.length_squared()
	var t := 0.0 if l2 <= 0.0 else clampf((p - a).dot(d) / l2, 0.0, 1.0)
	return [a + d * t, t]


static func _seg_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Array:
	var r := b - a
	var s := d - c
	var den := r.x * s.y - r.y * s.x
	if absf(den) < 1e-12:
		return []
	var qp := c - a
	var t := (qp.x * s.y - qp.y * s.x) / den
	var u := (qp.x * r.y - qp.y * r.x) / den
	if t > 0.0 and t < 1.0 and u > 0.0 and u < 1.0:
		return [a + r * t, t, u]
	return []


static func _dist_point_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var q: Vector2 = _seg_closest(p, a, b)[0]
	return p.distance_to(q)


static func _dist_point_line(p: Vector2, line: PackedVector2Array) -> float:
	if line.size() == 1:
		return p.distance_to(line[0])
	var best := INF
	for i in range(line.size() - 1):
		best = minf(best, _dist_point_seg(p, line[i], line[i + 1]))
	return best


static func _ring(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	if poly.size() >= 3:
		out.append(poly[0])
	return out


## Distance from a point to a polygon's area (0 inside).
static func _dist_point_poly(p: Vector2, poly: PackedVector2Array) -> float:
	if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	return _dist_point_line(p, _ring(poly))


## The hull may be a polygon, a line or a point; a point's distance to it.
static func _dist_point_hull(p: Vector2, hull: PackedVector2Array) -> float:
	return _dist_point_poly(p, hull)


static func _segs_cross_or_touch(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return Geometry2D.segment_intersects_segment(a, b, c, d) != null


## Distance between a polyline (or point) and a polygon's area (or line).
static func _dist_line_poly(line: PackedVector2Array, poly: PackedVector2Array) -> float:
	if poly.size() >= 3:
		for v in line:
			if Geometry2D.is_point_in_polygon(v, poly):
				return 0.0
	var ring := _ring(poly)
	for i in range(line.size() - 1):
		for j in range(ring.size() - 1):
			if _segs_cross_or_touch(line[i], line[i + 1], ring[j], ring[j + 1]):
				return 0.0
	var best := INF
	for v in line:
		best = minf(best, _dist_point_line(v, ring))
	for v in ring:
		best = minf(best, _dist_point_line(v, line))
	return best


## Distance between two areas (either may be the hull: a polygon, a line, a point).
static func _dist_poly_hull(poly: PackedVector2Array, hull: PackedVector2Array) -> float:
	if hull.size() >= 3:
		for v in poly:
			if Geometry2D.is_point_in_polygon(v, hull):
				return 0.0
	return _dist_line_poly(_ring(hull) if hull.size() >= 3 else hull, poly)


static func _length(line: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(line.size() - 1):
		s += line[i].distance_to(line[i + 1])
	return s


## shapely `project`: distance along the line to its point nearest p.
static func _project(line: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	var at := 0.0
	var run := 0.0
	for i in range(line.size() - 1):
		var hit := _seg_closest(p, line[i], line[i + 1])
		var d := p.distance_to(hit[0])
		var seg := line[i].distance_to(line[i + 1])
		if d < best:
			best = d
			at = run + seg * float(hit[1])
		run += seg
	return at


## shapely `interpolate`: the point `s` metres along the line.
static func _interpolate(line: PackedVector2Array, s: float) -> Vector2:
	var run := 0.0
	for i in range(line.size() - 1):
		var seg := line[i].distance_to(line[i + 1])
		if run + seg >= s and seg > 0.0:
			return line[i].lerp(line[i + 1], (s - run) / seg)
		run += seg
	return line[line.size() - 1]
