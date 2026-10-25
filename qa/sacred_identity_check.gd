class_name SacredIdentityCheck
extends RefCounted
## SACRED-IDENTITY: the named traits of a rotunda and of a pylon temple,
## measured from the builder's own mass_log and component_log (never from a
## picture). Each trait returns {ok, note}. A trait is only worth reporting if
## the same measure FAILS on a log with that trait removed -- see
## tests/suites/sacred_identity_suite.gd for the removal controls.
##
## Rotunda: drum (a closed ring of wall panels on one radius), roof (a ring
## roof with an open centre), colonnade (a ring of arcade piers and an inner
## ring of columns, with piers standing either side of the door).
## Pylon: towers (twin, mirrored, battered, flanking the gate), hypostyle (a
## grid of columns behind the towers).

const ROTUNDA_TRAITS := ["drum", "roof", "colonnade"]
const PYLON_TRAITS := ["towers", "hypostyle"]
const DOOR_FLANK := 0.6981317  # 40 degrees either side of the door


static func traits_for(form: StringName) -> Array:
	return ROTUNDA_TRAITS if form == &"rotunda" else PYLON_TRAITS


## `masses` and `comps` normally come from the builder; controls pass copies.
static func measure(spec: TempleSpec, masses: Array, comps: Array) -> Dictionary:
	if spec.form == &"rotunda":
		return {"drum": _drum(spec, masses), "roof": _roof(spec, comps),
			"colonnade": _colonnade(spec, masses)}
	if spec.form == &"pylon":
		return {"towers": _towers(spec, masses, comps), "hypostyle": _hypostyle(spec, masses)}
	# any other form carries none of these traits
	var out := {}
	for t in ROTUNDA_TRAITS + PYLON_TRAITS:
		out[t] = _ok(false, "not a rotunda or pylon")
	return out


static func _ok(ok: bool, note: String) -> Dictionary:
	return {"ok": ok, "note": note}


static func _named(masses: Array, prefix: String) -> Array:
	var out: Array = []
	for m in masses:
		if (m["name"] as String).begins_with(prefix):
			out.append(m)
	return out


## (radius, angle) of a mass about the temple centre; angle 0 is the door (-z).
static func _polar(aabb: AABB) -> Vector2:
	var c := aabb.get_center()
	return Vector2(Vector2(c.x, c.z).length(), atan2(c.x, -c.z))


## (1) a round drum plan.
static func _drum(spec: TempleSpec, masses: Array) -> Dictionary:
	var panels: Array = []
	for m in _named(masses, "wall_rotunda_"):
		if not (m["name"] as String).begins_with("wall_rotunda_gate"):
			panels.append(m)
	if panels.size() < 12:
		return _ok(false, "%d drum panels (need 12)" % panels.size())
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var lo := INF
	var hi := -INF
	var angles: Array = []
	for m in panels:
		var p := _polar(m["aabb"])
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
		angles.append(p.y)
	if hi > outer + 0.05 or lo < outer * 0.75 or (hi - lo) > outer * 0.12:
		return _ok(false, "panel centres span r %.2f..%.2f against outer %.2f" % [lo, hi, outer])
	angles.sort()
	var gap := 0.0
	for i in range(angles.size()):
		var nxt: float = float(angles[i + 1]) if i < angles.size() - 1 else float(angles[0]) + TAU
		gap = maxf(gap, nxt - float(angles[i]))
	if gap > deg_to_rad(70.0):
		return _ok(false, "largest gap in the drum %.0f deg" % rad_to_deg(gap))
	return _ok(true, "%d panels on r %.1f..%.1f (outer %.1f), largest gap %.0f deg" % [
		panels.size(), lo, hi, outer, rad_to_deg(gap)])


## (2) a ring roof: a revolved annulus on the drum with an open centre.
static func _roof(spec: TempleSpec, comps: Array) -> Dictionary:
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	for c in comps:
		if c["role"] != "rotunda_drum_crown":
			continue
		var prof: PackedVector2Array = c["profile"]
		var r_lo := INF
		var r_hi := -INF
		for p in prof:
			r_lo = minf(r_lo, p.x)
			r_hi = maxf(r_hi, p.x)
		var y: float = (c["center"] as Vector3).y
		var full: bool = absf(float(c["arc"]) - TAU) < 0.001
		if full and r_hi >= outer and r_lo > 0.5 and r_lo < r_hi * 0.9 and y >= spec.height - 0.01:
			return _ok(true, "ring roof r %.1f..%.1f at y %.1f, open centre" % [r_lo, r_hi, y])
		return _ok(false, "crown r %.1f..%.1f arc %.2f y %.1f is not an open ring on the drum" % [
			r_lo, r_hi, float(c["arc"]), y])
	return _ok(false, "no rotunda_drum_crown")


## (3) a ring colonnade at the door: arcade piers on one circle with a pier
## either side of the door, mirrored about the axis, and the inner column ring.
static func _colonnade(spec: TempleSpec, masses: Array) -> Dictionary:
	var piers := _named(masses, "rotunda_arcade_pier_")
	if piers.size() < 8:
		return _ok(false, "%d arcade piers (need 8)" % piers.size())
	var lo := INF
	var hi := -INF
	var left := 0
	var right := 0
	var xs: Array = []
	for m in piers:
		var c: Vector3 = (m["aabb"] as AABB).get_center()
		var p := _polar(m["aabb"])
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
		xs.append(c.x)
		if absf(p.y) <= DOOR_FLANK and c.z < 0.0:
			if c.x < 0.0:
				left += 1
			else:
				right += 1
	if hi - lo > hi * 0.12:
		return _ok(false, "piers span r %.2f..%.2f: not one ring" % [lo, hi])
	if left < 1 or right < 1:
		return _ok(false, "piers flank the door %d left / %d right" % [left, right])
	for x in xs:
		var found := false
		for y in xs:
			if absf(float(x) + float(y)) < 0.06:
				found = true
				break
		if not found:
			return _ok(false, "pier at x %.2f has no mirror twin" % float(x))
	var cols := _named(masses, "column_")
	if cols.size() < 8:
		return _ok(false, "%d inner columns (need 8)" % cols.size())
	var cl := INF
	var ch := -INF
	for m in cols:
		var r := _polar(m["aabb"]).x
		cl = minf(cl, r)
		ch = maxf(ch, r)
	if ch - cl > 0.6:
		return _ok(false, "inner columns span r %.2f..%.2f: not a ring" % [cl, ch])
	var peri := _peristyle(spec, masses)
	if not peri["ok"]:
		return peri
	return _ok(true, "%d piers r %.1f, %d columns r %.1f, door flanked %d/%d; %s" % [
		piers.size(), hi, cols.size(), ch, left, right, peri["note"]])


## SACRED-ROTUNDA-PERISTYLE: a ring of columns standing on the ground OUTSIDE
## the drum, mirrored about the gate axis, below the drum top, with the door
## between the two nearest columns (a clear bay at least a gate wide).
static func _peristyle(spec: TempleSpec, masses: Array) -> Dictionary:
	var cols := _named(masses, "rotunda_peristyle_column_")
	if cols.size() < 8:
		return _ok(false, "%d door-level peristyle columns (need 8)" % cols.size())
	var outer := TempleGeometry.rotunda_outer_radius(spec)
	var lower := TempleGeometry.rotunda_lower_drum_height(spec)
	var lo := INF
	var hi := -INF
	var left_x := -INF  # nearest column left of the axis (x < 0), at the door
	var right_x := INF
	var xs: Array = []
	for m in cols:
		var box: AABB = m["aabb"]
		var p := _polar(box)
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
		if box.position.y > 0.05:
			return _ok(false, "peristyle column %s does not stand on the ground" % m["name"])
		if box.end.y > lower:
			return _ok(false, "peristyle column %s rises above the drum (%.1f > %.1f)" % [
				m["name"], box.end.y, lower])
		var c := box.get_center()
		xs.append(c.x)
		if c.z < 0.0 and absf(p.y) <= DOOR_FLANK:
			if c.x < 0.0:
				left_x = maxf(left_x, c.x + box.size.x * 0.5)
			else:
				right_x = minf(right_x, c.x - box.size.x * 0.5)
	if lo <= outer:
		return _ok(false, "peristyle r %.2f is not outside the drum (r %.2f)" % [lo, outer])
	if hi - lo > 0.3:
		return _ok(false, "peristyle columns span r %.2f..%.2f: not one ring" % [lo, hi])
	if left_x == -INF or right_x == INF:
		return _ok(false, "no peristyle column either side of the door")
	if right_x - left_x < TempleGeometry.GATE_W:
		return _ok(false, "door bay %.2f m is narrower than the gate" % (right_x - left_x))
	for x in xs:
		var found := false
		for y in xs:
			if absf(float(x) + float(y)) < 0.06:
				found = true
				break
		if not found:
			return _ok(false, "peristyle column at x %.2f has no mirror twin" % float(x))
	return _ok(true, "%d peristyle columns r %.1f, door bay %.1f m" % [
		cols.size(), hi, right_x - left_x])


## Pylon (1): twin mirrored battered towers either side of the gate, on the front line.
static func _towers(spec: TempleSpec, masses: Array, comps: Array) -> Dictionary:
	var t0 := _named(masses, "pylon_0")
	var t1 := _named(masses, "pylon_1")
	if t0.is_empty() or t1.is_empty():
		return _ok(false, "%d/%d tower masses" % [t0.size(), t1.size()])
	var a: AABB = t0[0]["aabb"]
	var b: AABB = t1[0]["aabb"]
	if a.get_center().x > b.get_center().x:
		var tmp := a
		a = b
		b = tmp
	var gap := b.position.x - a.end.x
	if absf(a.get_center().x + b.get_center().x) > 0.06 or absf(a.size.x - b.size.x) > 0.06 \
			or absf(a.size.y - b.size.y) > 0.06 or absf(a.position.z - b.position.z) > 0.06:
		return _ok(false, "towers are not mirror twins")
	if gap < TempleGeometry.pylon_gate_width(spec) - 0.05 or gap < TempleGeometry.GATE_W - 0.05:
		return _ok(false, "gap %.2f between the towers is narrower than the gate" % gap)
	if a.size.y < spec.height * 1.2:
		return _ok(false, "towers %.1f m do not rise over the %.1f m wall" % [a.size.y, spec.height])
	var site := TempleGeometry.site_rect(spec)
	if a.position.z > site.position.y + 0.1:
		return _ok(false, "towers are not on the front line")
	# battered: the faces are smaller at the top than at the foot
	var worst := 0.0
	for host_i in range(2):
		var ymin := INF
		var ymax := -INF
		var pts: Array = []
		for c in comps:
			if c["role"] == "pylon_battered_face" and c["host"] == "pylon_tower_%d" % host_i:
				for p in (c["points"] as PackedVector3Array):
					pts.append(p)
					ymin = minf(ymin, p.y)
					ymax = maxf(ymax, p.y)
		if pts.is_empty():
			return _ok(false, "tower %d has no battered face" % host_i)
		var foot := _plan_area(pts, ymin)
		var top := _plan_area(pts, ymax)
		var ratio: float = top / maxf(foot, 0.001)
		worst = maxf(worst, ratio)
		if ratio > 0.9:
			return _ok(false, "tower %d top/foot area %.2f: not battered" % [host_i, ratio])
	return _ok(true, "twin towers %.1f x %.1f m, %.1f m high, gate gap %.1f, top/foot area <= %.2f" % [
		a.size.x, a.size.z, a.size.y, gap, worst])


static func _plan_area(pts: Array, y: float) -> float:
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	for p in pts:
		if absf(p.y - y) < 0.02:
			x0 = minf(x0, p.x)
			x1 = maxf(x1, p.x)
			z0 = minf(z0, p.z)
			z1 = maxf(z1, p.z)
	return (x1 - x0) * (z1 - z0)


## Pylon (2): a hypostyle hall -- a grid of columns (>= 2 rows, >= 2 files)
## behind the towers.
static func _hypostyle(_spec: TempleSpec, masses: Array) -> Dictionary:
	var cols := _named(masses, "column_")
	var tower_back := -INF
	for t in _named(masses, "pylon_0") + _named(masses, "pylon_1"):
		tower_back = maxf(tower_back, (t["aabb"] as AABB).end.z)
	if tower_back == -INF:
		return _ok(false, "no gate towers to stand behind")
	if cols.size() < 4:
		return _ok(false, "%d columns (need 4)" % cols.size())
	var rows := {}
	var files := {}
	for m in cols:
		var c: Vector3 = (m["aabb"] as AABB).get_center()
		if c.z < tower_back:
			return _ok(false, "column at z %.1f stands in front of the tower line z %.1f" % [c.z, tower_back])
		rows[snappedf(c.z, 0.1)] = true
		files[snappedf(c.x, 0.1)] = true
	if rows.size() < 2 or files.size() < 2:
		return _ok(false, "%d rows x %d files is not a grid" % [rows.size(), files.size()])
	# a ring of columns also has several z and x values; a hall is not a ring
	var centre := Vector2.ZERO
	for m in cols:
		var cc: Vector3 = (m["aabb"] as AABB).get_center()
		centre += Vector2(cc.x, cc.z)
	centre /= float(cols.size())
	var rlo := INF
	var rhi := -INF
	for m in cols:
		var cc: Vector3 = (m["aabb"] as AABB).get_center()
		var d := Vector2(cc.x, cc.z).distance_to(centre)
		rlo = minf(rlo, d)
		rhi = maxf(rhi, d)
	if rhi - rlo < rhi * 0.15:
		return _ok(false, "the columns stand on one circle (r %.1f): a ring, not a hall" % rhi)
	return _ok(true, "%d columns, %d rows x %d files, all behind z %.1f" % [
		cols.size(), rows.size(), files.size(), tower_back])
