extends RefCounted
## VillageShape (qa/village_shape.gd): the world survey's arrangement metrics
## on a generated plan. Synthetic plans with answers known in advance:
##
##   one straight street of houses        elongation > 4, frontage_aligned ~ 1
##   a 4 x 4 grid of streets (3 x 3 blocks) orientation_order > 0.8, no dead ends,
##                                        the 12 junctions found
##   houses on a 20 % plane                slope_median_pct within 1 of 20
##   a street along that plane's contour   street_contour_share ~ 1
##   a street up its fall line             street_contour_share ~ 0
##   flat ground                           no slope, no relief
##
## Parity with survey.py itself is tools/shape_parity.gd, not this suite: it
## needs Python and real plans.


static func run() -> SuiteResult:
	var res := SuiteResult.new("vshape")
	_row(res)
	_grid(res)
	_plane(res)
	_contour(res)
	return res


# ------------------------------------------------------------------ fixtures

static func _plan(terrain: VillageTerrain = null) -> VillagePlan:
	var spec := VillageSpec.new(1)
	spec.terrain = terrain
	return VillagePlan.new(spec)


static func _road(plan: VillagePlan, a: Vector2, b: Vector2, cls := &"street") -> void:
	plan.roads.append({"points": PackedVector2Array([a, b]), "class": cls, "width": 5.0, "verge": 1.0})


## A house centred at plan point `c`, `w` along its local x, `d` along z,
## turned `yaw` radians about +Y.
static func _house(plan: VillagePlan, c: Vector2, w := 10.0, d := 6.0, yaw := 0.0) -> void:
	var req := BuildingRequest.new()
	req.kind = &"house"
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, 0.0, c.y))
	plan.buildings.append({"lot": -1, "request": req, "kind": &"house", "class": &"cottage",
		"placement": {"footprint": Rect2(-w * 0.5, -d * 0.5, w, d)}, "transform": xf,
		"door": xf * Vector3(0, 0, -d * 0.5)})


static func _near(res: SuiteResult, label: String, m: Dictionary, key: String, want: float, tol: float) -> void:
	res.checked += 1
	if not m.has(key) or m[key] == null:
		res.fail("%s: no %s (%s)" % [label, key, m])
		return
	if absf(float(m[key]) - want) > tol:
		res.fail("%s: %s is %s, expected %s +- %s" % [label, key, m[key], want, tol])


static func _above(res: SuiteResult, label: String, m: Dictionary, key: String, floor_v: float) -> void:
	res.checked += 1
	if not m.has(key) or m[key] == null or float(m[key]) <= floor_v:
		res.fail("%s: %s is %s, expected > %s" % [label, key, m.get(key), floor_v])


# --------------------------------------------------------------------- cases

## One east-west street, houses both sides, long side to the street.
static func _row(res: SuiteResult) -> void:
	var plan := _plan()
	_road(plan, Vector2(-160, 0), Vector2(160, 0))
	for i in range(21):
		_house(plan, Vector2(-140 + i * 14, 9.0 if i % 2 == 0 else -9.0))
	var m := VillageShape.measure(plan)
	_above(res, "row", m, "elongation", 4.0)
	_near(res, "row", m, "frontage_aligned", 1.0, 0.001)
	_near(res, "row", m, "road_reached", 1.0, 0.001)
	_near(res, "row", m, "setback_median_m", 6.0, 0.05)
	_near(res, "row", m, "body_share", 1.0, 0.001)
	# one street, two ends, no junction
	_near(res, "row", m, "dead_end_ratio", 1.0, 0.001)
	# flat: no terrain, so nothing slopes and nothing stands above anything
	_near(res, "row flat", m, "slope_median_pct", 0.0, 0.001)
	_near(res, "row flat", m, "relief_disc_m", 0.0, 0.001)
	res.checked += 1
	if m.has("street_contour_share") or m.has("house_contour_share"):
		res.fail("row flat: contour shares on flat ground: %s" % m)
	# the survey folds by 90 degrees: gable-on is aligned too. Turned 45
	# degrees, the same houses face nothing
	var across := _plan()
	_road(across, Vector2(-160, 0), Vector2(160, 0))
	for i in range(21):
		_house(across, Vector2(-140 + i * 14, 9.0 if i % 2 == 0 else -9.0), 10.0, 6.0, PI * 0.25)
	var ma := VillageShape.measure(across)
	_near(res, "row at 45 deg", ma, "frontage_aligned", 0.0, 0.001)


## Four streets each way, 120 m square: 3 x 3 blocks, every street a T or a
## crossing at each end, 4 houses a block.
static func _grid(res: SuiteResult) -> void:
	var plan := _plan()
	for v in [-60.0, -20.0, 20.0, 60.0]:
		_road(plan, Vector2(-60, v), Vector2(60, v))
		_road(plan, Vector2(v, -60), Vector2(v, 60))
	for bx in [-40.0, 0.0, 40.0]:
		for bz in [-40.0, 0.0, 40.0]:
			for o in [Vector2(-9, -9), Vector2(9, -9), Vector2(-9, 9), Vector2(9, 9)]:
				_house(plan, Vector2(bx, bz) + o, 8.0, 6.0)
	var m := VillageShape.measure(plan)
	_above(res, "grid", m, "orientation_order", 0.8)
	_near(res, "grid", m, "dead_end_ratio", 0.0, 0.001)
	# 16 nodes: 4 corners (degree 2), 8 edge Ts and 4 crossings
	var hull_ha: float = float(m.get("body_hull_ha", 0.0))
	_near(res, "grid", m, "intersections_per_ha", 12.0 / maxf(hull_ha, 0.01), 0.05 * 12.0 / maxf(hull_ha, 0.01))
	_near(res, "grid", m, "clusters_ge5", 1.0, 0.001)
	# the same street net at 30 degrees: still a grid
	var turned := _plan()
	var rot := Transform2D(deg_to_rad(30.0), Vector2.ZERO)
	for r in plan.roads:
		var pts: PackedVector2Array = r["points"]
		_road(turned, rot * pts[0], rot * pts[1])
	for b in plan.buildings:
		var o: Vector3 = (b["transform"] as Transform3D).origin
		_house(turned, rot * Vector2(o.x, o.z), 8.0, 6.0, -deg_to_rad(30.0))
	_above(res, "grid at 30 deg", VillageShape.measure(turned), "orientation_order", 0.8)


## h = 0.2 x: a 20 % fall to the west, contours running north-south.
static func _plane_ground() -> VillageTerrain:
	return VillageTerrain.from_sampler(func(x: float, _z: float) -> float: return 0.2 * x + 100.0,
		Rect2(-200, -200, 400, 400), 10.0)


static func _plane(res: SuiteResult) -> void:
	var plan := _plan(_plane_ground())
	for i in range(6):
		for j in range(6):
			_house(plan, Vector2(-75 + i * 30, -75 + j * 30))
	_road(plan, Vector2(-100, 0), Vector2(100, 0))
	var m := VillageShape.measure(plan)
	_near(res, "plane", m, "slope_median_pct", 20.0, 1.0)
	_near(res, "plane", m, "slope_p90_pct", 20.0, 1.0)
	# 6 columns 30 m apart: 150 m of x, 30 m of rise between the 5th and 95th
	_near(res, "plane", m, "elev_span_m", 0.2 * (_pct_span(150.0)), 0.5)
	_near(res, "plane", m, "relief_disc_m", 80.0, 0.01)


## The 5th..95th percentile span of 6 evenly spaced columns `width` wide,
## each column 6 houses: numpy's linear percentile over 36 values.
static func _pct_span(width: float) -> float:
	var xs := PackedFloat64Array()
	for i in range(6):
		for _j in range(6):
			xs.append(-width * 0.5 + i * width / 5.0)
	xs.sort()
	var at := func(q: float) -> float:
		var pos := q / 100.0 * (xs.size() - 1)
		var lo := int(floor(pos))
		return xs[lo] + (xs[mini(lo + 1, xs.size() - 1)] - xs[lo]) * (pos - lo)
	return at.call(95.0) - at.call(5.0)


static func _contour(res: SuiteResult) -> void:
	var along := _plan(_plane_ground())
	_road(along, Vector2(0, -150), Vector2(0, 150))
	var up := _plan(_plane_ground())
	_road(up, Vector2(-150, 0), Vector2(150, 0))
	for i in range(20):
		var t := -133.0 + i * 14.0
		var side := 9.0 if i % 2 == 0 else -9.0
		# houses with their ridge along the street, both cases
		_house(along, Vector2(side, t), 10.0, 6.0, PI * 0.5)
		_house(up, Vector2(t, side))
	var ma := VillageShape.measure(along)
	var mu := VillageShape.measure(up)
	_near(res, "contour street", ma, "street_contour_share", 1.0, 0.01)
	_near(res, "contour street", ma, "street_steep_share", 1.0, 0.01)
	_near(res, "contour houses", ma, "house_contour_share", 1.0, 0.01)
	_near(res, "fall-line street", mu, "street_contour_share", 0.0, 0.01)
	_near(res, "fall-line houses", mu, "house_contour_share", 0.0, 0.01)
	_near(res, "contour street", ma, "frontage_aligned", 1.0, 0.001)
