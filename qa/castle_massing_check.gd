class_name CastleMassingCheck
extends RefCounted
## Correctness checks over a CASTLE's structural masses. The three structural
## rules come from MassRules; what lives here is the castle's joint table, the
## dimensions its spec asked for, and the one rule a fortification adds:
##
##   ENCLOSED    a walled tier must actually be walled -- four runs of curtain,
##               a gate through them, and every ward tied to the one outside it
##   GREAT_TOWER when the spec names one, exactly one tower of the outer ring
##               stands head and shoulders over the rest (CAS-002)
##   RANGES      the hall looks into the bailey and not through its curtain;
##               the chapel has its apse (CAS-003)
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := MassRules.TOL
## Mass name prefixes that fold to a family for the joint table below.
const FAMILIES := ["wall", "tower", "gate", "barbican", "keep", "hall", "chapel",
	"apse", "wing", "range", "porch", "chimney", "annexe", "link", "storey",
	"platform", "motte", "climb"]

## The rules, in the order they run; a family may replace one through
## `check(spec, builder, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"no_gaps", &"no_overlap", &"grounded",
	&"size_match", &"enclosed", &"great_tower", &"ranges", &"motte"]
const METHODS := {&"no_gaps": "_check_gaps", &"no_overlap": "_check_overlaps",
	&"enclosed": "_check_enclosure"}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


## Designed interpenetration per joint, in metres of penetration depth. A pair
## absent from this table is expected NOT to overlap at all; INF marks a
## crossing meant to pass fully through.
static func _allowance(a: String, b: String, polygonal := false, tower_lap := -1.0,
		ridge := false) -> float:
	var key: String = "|".join(PackedStringArray([a, b]) if a < b else PackedStringArray([b, a]))
	# a motte and bailey (CAS-005): the mound is a cone logged as the box
	# round it, so everything it touches -- the keep on it, the curtain up it,
	# the bailey's back wall and towers at its toe -- meets that box; the
	# `motte` rule is what proves the keep stands on the top and nothing else
	# stands on the slope
	if a == "motte" or b == "motte":
		return INF
	match key:
		"climb|keep", "climb|wall", "climb|tower":
			return INF
	if ridge:
		# a ridge castle (CAS-007): every range is a rotated box logged as
		# the box round it, and consecutive ranges meet inside the tower at
		# their shared vertex. The towers resolve those joints; the voxel
		# sweep proves the ridge is continuous.
		match key:
			"range|range", "hall|range", "hall|tower", "range|tower":
				return INF
			"tower|tower":
				return 0.0
	if tower_lap >= 0.0:
		# a tower house (CAS-006): the shaft is logged whole as the hall and
		# storey by storey inside it, the platform sits on the top storey and
		# the jog laps the shaft like a wing -- deeper into the foot storeys,
		# which are wider than the shaft by the thickening of their walls
		match key:
			"hall|storey", "hall|platform":
				return INF
			"storey|storey", "platform|storey":
				return 0.0
			"hall|wing":
				return CastleGeometry.WING_LAP
			"storey|wing":
				return tower_lap
			"platform|wing", "wing|wing":
				return 0.0
	if polygonal:
		# A slanted run is a rotated box, and the AABB the mass log has to
		# record for it is a box round a box. Two runs meeting at a vertex, and
		# a range built against a run, therefore "interpenetrate" in a way that
		# says nothing about the masonry -- the vertex towers are what actually
		# resolve those joints, and the voxel sweep is what proves the wall line
		# is continuous. Only these AABB-of-a-diagonal pairs are relaxed.
		match key:
			"wall|wall":
				return INF
			"hall|wall", "chapel|wall", "keep|wall", "apse|wall":
				return INF
			"keep|tower", "chapel|tower", "hall|tower":
				# a vertex tower IS part of the run it stands on, so a range built
				# against that run meets the tower along with it
				return INF
	match key:
		# --- the enceinte: walls die into the towers and gate that stud them ---
		"tower|wall", "gate|wall", "gate|tower":
			return INF
		"barbican|gate", "barbican|tower":
			return INF                        # the outwork ties into the gate
		"gate|link", "link|tower", "link|wall":
			return INF                        # the causeway lands on both gates

		# --- ranges built against a curtain lap it, and its towers with it ---
		"keep|wall", "hall|wall", "chapel|wall":
			return CastleGeometry.RANGE_LAP
		"apse|chapel":
			return INF                        # the apse springs from inside the chapel
		"keep|tower", "hall|tower", "chapel|tower":
			return CastleGeometry.RANGE_LAP

		# --- house and manor: one range laps the next ---
		"hall|wing", "range|wing", "annexe|hall", "chimney|hall", "hall|porch":
			return CastleGeometry.WING_LAP
		"hall|range", "chimney|range", "annexe|wing":
			return CastleGeometry.WING_LAP
		"porch|range", "porch|wing":
			return INF                        # the passage runs through the range
		"hall|tower", "tower|wing", "range|tower":
			return INF                        # a manor tower is built into its range

		# --- everything below must stand clear ---
		"wall|wall":
			return 0.0                        # runs meet at their faces
		"tower|tower":
			return 0.0                        # towers must not collide
		"gate|gate":
			return 0.0                        # outer and inner gatehouses are apart
		"hall|keep", "chapel|keep", "chapel|hall":
			return 0.0                        # ranges touch, they do not merge
		"link|link", "wing|wing":
			return 0.0
	return 0.0


func check(spec: CastleSpec, builder: CastleBuilder, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()

	var masses: Array[Dictionary] = builder.mass_log
	stats["masses"] = masses.size()
	stats["tier"] = String(spec.tier)
	if masses.is_empty():
		failures.append("massing: builder logged no structural masses")
		return _report()
	replaced = RuleSet.run(self, RULES, METHODS, overrides, [spec, builder],
		[spec, builder], failures, warnings)
	return _report()


func _check_gaps(spec: CastleSpec, builder: CastleBuilder) -> void:
	var g: Dictionary = MassRules.gaps(builder.mass_log, _anchor(spec))
	_add(g["failures"])
	stats["masses_joined"] = g["joined"]


func _check_overlaps(spec: CastleSpec, builder: CastleBuilder) -> void:
	var polygonal: bool = CastleGeometry.is_polygonal(spec)
	var tower_lap := -1.0
	if CastleGeometry.is_tower_house(spec):
		tower_lap = CastleGeometry.WING_LAP \
			+ spec.wall_thickness * (CastleGeometry.TOWER_FOOT_RATIO - 1.0)
	var ridge: bool = CastleGeometry.is_ridge(spec)
	var o: Dictionary = MassRules.overlaps(builder.mass_log,
		func(a: String, b: String) -> float: return _allowance(a, b, polygonal, tower_lap, ridge),
		FAMILIES)
	_add(o["failures"])
	stats["worst_penetration"] = o["worst"]


func _check_grounded(spec: CastleSpec, builder: CastleBuilder) -> void:
	var carried: Array = []
	if CastleGeometry.is_motte(spec):
		carried.append("keep_shell")     # it stands on the mound
	if CastleGeometry.is_tower_house(spec):
		# the upper storeys and the platform stand on the storey below
		carried.append("platform")
		for m in builder.mass_log:
			var nm: String = m["name"]
			if nm.begins_with("storey_") and nm != "storey_0":
				carried.append(nm)
	_add(MassRules.grounded(builder.mass_log, carried))


## The mass everything else must be reachable from. A walled tier is anchored
## on its outer curtain; an unwalled one on the hall, which IS the building.
static func _anchor(spec: CastleSpec) -> String:
	return "wall_0_back" if CastleGeometry.is_enclosed(spec) else "hall"


func _add(msgs) -> void:
	for m in msgs:
		failures.append(str(m))


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats, "replaced": replaced}


# ------------------------------------------------------------- size match

## The emitted masses must have the dimensions the spec and the tier asked for.
func _check_size_match(spec: CastleSpec, builder: CastleBuilder) -> void:
	var masses: Array[Dictionary] = builder.mass_log
	var by_name := {}
	for m in masses:
		by_name[m["name"]] = m["aabb"]

	if spec.keep and by_name.has("keep"):
		var k: AABB = by_name["keep"]
		_expect("keep width", k.size.x, spec.keep_w)
		_expect("keep depth", k.size.z, spec.keep_l)
		_expect("keep height", k.size.y, spec.keep_height)

	if CastleGeometry.is_enclosed(spec):
		for r in CastleGeometry.rings(spec):
			var h: float = CastleGeometry.wall_height(spec, r)
			for which in CastleGeometry.wall_names(spec, r):
				var key: String = "wall_%d_%s" % [r, String(which)]
				if by_name.has(key):
					_expect("%s height" % key, by_name[key].size.y, h)
			for m2 in masses:
				var nm: String = m2["name"]
				if not nm.begins_with("tower_%d" % r):
					continue
				# a vertex tower is sized for its vertex, which is how the
				# great tower is bigger than the rest
				var vi := -1
				var corner := "tower_%d_corner_" % r
				if nm.begins_with(corner):
					vi = int(nm.substr(corner.length()))
				var th: float = CastleGeometry.tower_height_at(spec, r, vi)
				var s2: float = CastleGeometry.tower_base_half_at(spec, r, vi) * 2.0
				var a: AABB = m2["aabb"]
				_expect("%s height" % nm, a.size.y, th)
				_expect("%s plan" % nm, a.size.x, s2)
	elif CastleGeometry.is_ridge(spec):
		# the ranges are as tall as the wall height; their plan is rotated
		# and measured by the ridge rule below
		if by_name.has("hall"):
			_expect("hall height", by_name["hall"].size.y, spec.height)
		var ti := 0
		for tc in CastleGeometry.ridge_tower_centers(spec):
			var key2 := "tower_0_corner_%d" % ti
			if by_name.has(key2):
				_expect("%s height" % key2, by_name[key2].size.y,
					CastleGeometry.tower_height_at(spec, 0, ti))
			ti += 1
	else:
		var host: AABB = CastleGeometry.house_range_aabb(spec)
		if by_name.has("hall"):
			_expect("hall width", by_name["hall"].size.x, host.size.x)
			_expect("hall height", by_name["hall"].size.y, spec.height)

	# The footprint the user asked for is the one the design must occupy: the
	# enceinte (or the house block) spans the whole site, no more and no less.
	var span := AABB()
	var first := true
	for m3 in masses:
		var b: AABB = m3["aabb"]
		span = b if first else span.merge(b)
		first = false
	stats["plan"] = "%.1f x %.1f" % [span.size.x, span.size.z]
	var want: Rect2 = CastleGeometry.plan_extent(spec)
	if span.size.x > want.size.x + TOL or span.size.z > want.size.y + TOL:
		failures.append("size_match: masses span %.2f x %.2fm, past the %.2f x %.2fm the plan allows"
			% [span.size.x, span.size.z, want.size.x, want.size.y])


# --------------------------------------------------------------- enclosure

## A castle is a wall with something inside it. This is the rule that catches a
## "castle" that generated as four towers and a keep standing in open ground.
func _check_enclosure(spec: CastleSpec, builder: CastleBuilder) -> void:
	if CastleGeometry.is_ridge(spec):
		_check_ridge(spec, builder)
		return
	if not CastleGeometry.is_enclosed(spec):
		if not builder.has_mass("hall"):
			failures.append("enclosed: a %s must have a hall block" % String(spec.tier))
		return
	for r in CastleGeometry.rings(spec):
		var runs := 0
		for which in CastleGeometry.wall_names(spec, r):
			if builder.has_mass("wall_%d_%s" % [r, String(which)]):
				runs += 1
		if runs < 4:
			failures.append("enclosed: ring %d has %d wall runs, not a closed circuit" % [r, runs])
		if spec.gatehouse and not builder.has_mass("gate_%d" % r):
			failures.append("enclosed: ring %d has no gatehouse to get in by" % r)
	if spec.inner_ward:
		if not (builder.has_mass("link_left") or builder.has_mass("link_right")):
			failures.append("enclosed: inner ward has no causeway joining it to the outer gate")


func _expect(what: String, got: float, want: float) -> void:
	if absf(got - want) > TOL:
		failures.append("size_match: %s is %.2fm, spec asked for %.2fm" % [what, got, want])


# ------------------------------------------------------------- great tower

## When the spec names a great tower, the outer ring has exactly one tower
## that is the tallest by a clear margin -- and it is a vertex tower, not the
## gatehouse drum. Measured from the masses: a spec flag nobody built is
## exactly what this catches.
const GREAT_TOWER_RATIO := 1.3

func _check_great_tower(spec: CastleSpec, builder: CastleBuilder) -> void:
	if CastleGeometry.great_tower_index(spec) < 0:
		return
	var masses: Array[Dictionary] = builder.mass_log
	var tallest := 0.0
	var tallest_name := ""
	var second := 0.0
	var at_top := 0
	for m in masses:
		var nm: String = m["name"]
		if not nm.begins_with("tower_0_"):
			continue
		var h: float = (m["aabb"] as AABB).size.y
		if h > tallest + TOL:
			second = tallest
			tallest = h
			tallest_name = nm
			at_top = 1
		elif absf(h - tallest) <= TOL:
			at_top += 1
		elif h > second:
			second = h
	if tallest_name == "":
		failures.append("great_tower: the spec asks for a great tower and the ring has no towers")
		return
	if at_top != 1:
		failures.append("great_tower: %d towers share the greatest height (%.1fm); a great tower stands alone"
			% [at_top, tallest])
	elif second > 0.0 and tallest < second * GREAT_TOWER_RATIO - TOL:
		failures.append("great_tower: the tallest tower (%s, %.1fm) is only %.2fx the next (%.1fm), wants %.1fx"
			% [tallest_name, tallest, tallest / second, second, GREAT_TOWER_RATIO])
	if "gate" in tallest_name:
		failures.append("great_tower: the tallest tower is the gatehouse drum %s" % tallest_name)
	stats["great_tower"] = tallest_name


# ------------------------------------------------------------------ ranges

## The hall and the chapel look into the bailey (CAS-003): the hall has a row
## of windows on its courtyard face and none through the curtain behind it,
## and a chapel has its apse. Read from the parts and masses the builder
## logged, so a window it placed on the wrong face is counted on that face.
func _check_ranges(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_enclosed(spec):
		return
	if spec.hall:
		var hall: AABB = CastleGeometry.hall_aabb(spec)
		var into := 0
		var through := 0
		for p in builder.part_log:
			if p["kind"] != "window" or p["tag"] != "hall":
				continue
			var f: Vector3 = p["facing"]
			if f.x > 0.9:
				into += 1
			elif f.x < -0.9:
				through += 1
		var want: int = mini(3, int(hall.size.z / CastleBuilder.RANGE_BAY))
		if into < want:
			failures.append("hall_windows: the hall has %d windows on its bailey face, wants %d" % [into, want])
		if through > 0:
			failures.append("hall_windows: the hall has %d windows through the curtain it stands against" % through)
	if spec.chapel:
		if CastleGeometry.apse_aabb(spec).size.x <= 0.0:
			warnings.append("chapel_apse: the ward closes in too fast toward the gate for an apse")
		elif not builder.has_mass("apse"):
			failures.append("chapel_apse: the chapel has no apse")
		var chapel_out := 0
		for p2 in builder.part_log:
			if p2["kind"] == "window" and p2["tag"] == "chapel" and (p2["facing"] as Vector3).x > 0.9:
				chapel_out += 1
		if chapel_out > 0:
			failures.append("chapel_apse: the chapel has %d windows through the curtain it stands against" % chapel_out)


# ------------------------------------------------------------------- ridge

## A ridge castle (CAS-007) is a spine with a range on every segment and a
## tower at every vertex, bending 15-45 degrees at each bend, with no bailey,
## gate or freestanding keep, hall or chapel.
func _check_ridge(spec: CastleSpec, builder: CastleBuilder) -> void:
	var pts: PackedVector2Array = CastleGeometry.spine(spec)
	if pts.size() < 3 or pts.size() > 6:
		failures.append("ridge: the spine has %d points, wants 3 to 6" % pts.size())
	for i in range(1, pts.size() - 1):
		var bend: float = rad_to_deg(CastleGeometry.spine_bend(spec, i))
		if bend < 15.0 - 0.5 or bend > 45.0 + 0.5:
			failures.append("ridge: the spine bends %.0f degrees at vertex %d, wants 15 to 45" % [bend, i])
	var ranges: int = 0
	for seg in CastleGeometry.ridge_ranges(spec):
		if builder.has_mass(String(seg["name"])):
			ranges += 1
	if ranges != pts.size() - 1:
		failures.append("ridge: %d ranges on a spine of %d segments" % [ranges, pts.size() - 1])
	for i2 in range(pts.size()):
		if not builder.has_mass("tower_0_corner_%d" % i2):
			failures.append("ridge: no tower at vertex %d of the spine" % i2)
	for banned in ["wall_", "gate_", "keep", "chapel", "barbican", "link_"]:
		if builder.has_mass(banned):
			failures.append("ridge: a ridge castle has no %s mass" % banned)
	stats["spine_length"] = snappedf(CastleGeometry.spine_length(spec), 0.1)


# ------------------------------------------------------------------- motte

## A motte and bailey (CAS-005): the shell keep stands on the mound's flat
## top and nothing else stands on the mound; the keep is the size the spec
## asked for and tops the bailey's curtain by KEEP_DOMINANCE; the climbing
## curtain joins the bailey's back wall to the keep.
func _check_motte(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_motte(spec):
		return
	var mound: AABB = builder.mass_aabb("motte")
	var keep: AABB = builder.mass_aabb("keep_shell")
	if mound.size.y <= 0.0:
		failures.append("motte: no mound was built")
		return
	if keep.size.y <= 0.0:
		failures.append("motte: no shell keep on the mound")
		return
	var c: Vector2 = CastleGeometry.motte_center(spec)
	var rt: float = CastleGeometry.motte_top_radius(spec)
	var top := Rect2(Vector2(c.x - rt, c.y - rt), Vector2(2.0 * rt, 2.0 * rt))
	var foot := Rect2(Vector2(keep.position.x, keep.position.z), Vector2(keep.size.x, keep.size.z))
	if not top.grow(TOL).encloses(foot):
		failures.append("motte: the shell keep stands off the mound's top (%s outside %s)" % [str(foot), str(top)])
	if absf(keep.position.y - mound.size.y) > TOL:
		failures.append("motte: the shell keep's foot is at %.2fm, the mound's top at %.2fm"
			% [keep.position.y, mound.size.y])
	_expect("shell keep width", keep.size.x, spec.keep_w)
	_expect("shell keep depth", keep.size.z, spec.keep_l)
	_expect("shell keep height", keep.size.y, spec.keep_height)
	var want: float = CastleGeometry.wall_height(spec, 0) * CastleGeometry.KEEP_DOMINANCE
	if keep.end.y < want - TOL:
		failures.append("motte: the keep tops out at %.1fm over a %.1fm curtain, wants %.1fx"
			% [keep.end.y, CastleGeometry.wall_height(spec, 0), CastleGeometry.KEEP_DOMINANCE])
	var slope := Rect2(Vector2(mound.position.x, mound.position.z), Vector2(mound.size.x, mound.size.z))
	for m in builder.mass_log:
		var nm: String = m["name"]
		if nm == "motte" or nm == "keep_shell" or nm == "climb":
			continue
		var a: AABB = m["aabb"]
		var mc := Vector2(a.position.x + a.size.x / 2.0, a.position.z + a.size.z / 2.0)
		if a.position.y > TOL and slope.has_point(mc):
			failures.append("motte: %s stands on the mound" % nm)
	var climb: AABB = builder.mass_aabb("climb")
	if climb.size.y <= 0.0:
		failures.append("motte: no curtain climbs from the bailey to the keep")
	else:
		var back: AABB = builder.mass_aabb("wall_0_back")
		if MassRules.separation(climb, back) > MassRules.JOIN_TOL:
			failures.append("motte: the climbing curtain does not meet the bailey's back wall")
		if MassRules.separation(climb, keep) > MassRules.JOIN_TOL:
			failures.append("motte: the climbing curtain does not reach the keep")
