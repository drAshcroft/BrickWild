class_name CastleLandmarkSuite
extends RefCounted
## 9. The famous fortifications this generator must be able to build.
##
## docs/CASTLES.md lists eleven real buildings with their footprint and the
## features that define them. CastleGenerator is probabilistic, so after
## generate() runs we FORCE the defining flags a real landmark demands -- a coin
## flip should never be the reason Bodiam loses its drum towers -- then check
## that CastleBuilder actually produced structural geometry for them, and that
## CastleMassingCheck still finds the result sound.
##
## Each row keeps its tier pinned while the footprint scales, so the sweep asks
## "does a fortress still hold together at 40% and at 150% of Krak?" rather than
## quietly turning into a manor on the way down.

const SCALES: Array[float] = [0.4, 0.7, 1.0, 1.5]

## One row per landmark: real dimensions from docs/CASTLES.md.
const LANDMARKS: Array[Dictionary] = [
	{"key": "longhouse", "style": &"norman", "tier": &"house",
		"width": 6.5, "length": 18.0, "height": 4.5},
	{"key": "stokesay", "style": &"norman", "tier": &"manor",
		"width": 30.0, "length": 24.0, "height": 10.0},
	{"key": "hampton_range", "style": &"french_chateau", "tier": &"manor",
		"width": 40.0, "length": 28.0, "height": 11.0},
	{"key": "bodiam", "style": &"edwardian", "tier": &"castle",
		"width": 55.0, "length": 50.0, "height": 18.0},
	{"key": "caernarfon", "style": &"edwardian", "tier": &"castle",
		"width": 170.0, "length": 60.0, "height": 12.0},
	{"key": "neuschwanstein", "style": &"bavarian", "tier": &"castle",
		"width": 150.0, "length": 40.0, "height": 25.0},
	{"key": "himeji", "style": &"japanese", "tier": &"castle",
		"width": 60.0, "length": 50.0, "height": 15.0},
	{"key": "chambord", "style": &"french_chateau", "tier": &"fortress",
		"width": 156.0, "length": 117.0, "height": 32.0},
	{"key": "krak", "style": &"crusader", "tier": &"fortress",
		"width": 300.0, "length": 140.0, "height": 20.0},
	{"key": "alhambra", "style": &"moorish", "tier": &"fortress",
		"width": 200.0, "length": 70.0, "height": 16.0},
	{"key": "windsor", "style": &"norman", "tier": &"fortress",
		"width": 200.0, "length": 120.0, "height": 18.0},
	# WORLD_BUILDINGS 5: the Merchant's tower, a Bologna tower house
	{"key": "merchants_tower", "style": &"norman", "tier": &"house",
		"width": 8.0, "length": 8.0, "height": 45.0},
	# CAS-011: ten more, each forcing a feature the generator could not make
	{"key": "tower_of_london", "style": &"norman", "tier": &"fortress",
		"width": 130.0, "length": 110.0, "height": 10.0},
	{"key": "conwy", "style": &"edwardian", "tier": &"castle",
		"width": 100.0, "length": 40.0, "height": 15.0},
	{"key": "carcassonne", "style": &"french_chateau", "tier": &"fortress",
		"width": 300.0, "length": 180.0, "height": 10.0},
	{"key": "malbork", "style": &"norman", "tier": &"fortress",
		"width": 320.0, "length": 140.0, "height": 15.0},
	{"key": "castel_del_monte", "style": &"crusader", "tier": &"castle",
		"width": 56.0, "length": 56.0, "height": 24.0},
	{"key": "edinburgh", "style": &"edwardian", "tier": &"castle",
		"width": 200.0, "length": 100.0, "height": 15.0},
	{"key": "eilean_donan", "style": &"norman", "tier": &"castle",
		"width": 60.0, "length": 50.0, "height": 12.0},
	{"key": "caerphilly", "style": &"edwardian", "tier": &"fortress",
		"width": 240.0, "length": 200.0, "height": 12.0},
	{"key": "dover", "style": &"norman", "tier": &"fortress",
		"width": 200.0, "length": 150.0, "height": 15.0},
	{"key": "mont_saint_michel", "style": &"french_chateau", "tier": &"fortress",
		"width": 120.0, "length": 80.0, "height": 40.0},
]

## Rows whose defining feature needs a plan kind the generator does not have
## yet, and the task that would add it. They are built at every scale so a
## crash is still caught, and their feature assertion is reported as an
## expected failure rather than a defect; when the task lands and the row
## passes, it comes off this list.
const EXPECTED_FAIL := {
	"conwy": "two wards side by side (no backlog task yet)",
	"malbork": "three wards in a line, brick (no backlog task yet)",
	"edinburgh": "terraced baileys (INT-016)",
	"mont_saint_michel": "a church on a terraced ring (INT-016, WLD church composition)",
}


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle landmark")
	for landmark in LANDMARKS:
		var key: String = landmark["key"]
		var defects := 0
		for scale in SCALES:
			if OS.get_environment("BIG_GLADE_TEST_TRACE") == "1":
				print("castle landmark: %s scale=%.2f seed=%d" % [key, scale, _seed_for(key, scale)])
			var spec := CastleSpec.new()
			spec.style = landmark["style"]
			spec.tier_override = landmark["tier"]
			spec.width = float(landmark["width"]) * scale
			spec.length = float(landmark["length"]) * scale
			spec.height = float(landmark["height"]) * scale
			CastleGenerator.generate(spec, _seed_for(key, scale))
			_force_features(key, spec)

			var builder := CastleBuilder.new()
			builder.build(spec)
			res.checked += 1
			var who := "%s scale=%.2f" % [key, scale]
			var before_fail: int = res.failures.size()

			if spec.tier != landmark["tier"]:
				res.fail("%s: tier_override did not hold (%s)" % [who, String(spec.tier)])
			if EXPECTED_FAIL.has(key):
				# the massing still has to be sound; only the feature is excused
				var probe := SuiteResult.new("probe")
				_check_required_masses(key, spec, builder, who, probe, scale)
				if probe.failures.is_empty():
					res.note("  %s: expected to fail (%s) and passed -- take it off EXPECTED_FAIL"
						% [who, String(EXPECTED_FAIL[key])])
				elif is_equal_approx(scale, 1.0):
					res.note("  %s: expected-fail, blocked by %s" % [key, String(EXPECTED_FAIL[key])])
			else:
				_check_required_masses(key, spec, builder, who, res, scale)
			var rep: Dictionary = CastleMassingCheck.new().check(spec, builder)
			for f in rep["failures"]:
				res.fail("%s: %s" % [who, str(f)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])

			if res.failures.size() > before_fail:
				defects += 1
		res.note("  %-15s %d scales, %d defects" % [key, SCALES.size(), defects])
	_check_castel_del_monte(res)
	return res


## Castel del Monte: a regular octagon with an identical tower at every one of
## its eight angles. It is here because it is the one plan whose correctness is
## VISIBLE -- if the enceinte is really regular, every tower has a mirror twin
## across both axes, and any drift in how a vertex or a batter is placed shows
## up as a tower that has none.
static func _check_castel_del_monte(res: SuiteResult) -> void:
	for scale in SCALES:
		var spec := CastleSpec.new()
		spec.style = &"crusader"
		spec.tier_override = &"castle"
		spec.width = 56.0 * scale
		spec.length = 56.0 * scale
		spec.height = 24.0 * scale
		CastleGenerator.generate(spec, _seed_for("castel_del_monte", scale))
		# a square site, so the octagon is regular and the mirrors are exact;
		# eight towers of one size, so no great tower (CAS-002)
		spec.corner_towers = true
		spec.gate_towers = false
		spec.great_tower = -1
		spec.great_tower_scale = 1.0
		_force_plan(spec, &"polygon", 8)

		var builder := CastleBuilder.new()
		builder.build(spec)
		res.checked += 1
		var who := "castel_del_monte scale=%.2f" % scale
		if CastleGeometry.plan_sides(spec) != 8:
			res.fail("%s: the octagon did not survive onto the spec" % who)
			continue
		var towers: Array[AABB] = []
		for m in builder.mass_log:
			if (m["name"] as String).begins_with("tower_0_corner_"):
				towers.append(m["aabb"])
		if towers.size() != 8:
			res.fail("%s: %d towers on an eight-sided plan" % [who, towers.size()])
		for i in range(towers.size()):
			var a: AABB = towers[i]
			if not _has_mirror(towers, a, Vector3(-1.0, 1.0, 1.0)):
				res.fail("%s: tower at %s has no mirror across x" % [who, str(a.position)])
			if not _has_mirror(towers, a, Vector3(1.0, 1.0, -1.0)):
				res.fail("%s: tower at %s has no mirror across z" % [who, str(a.position)])
			if not is_equal_approx(a.size.x, towers[0].size.x) 					or not is_equal_approx(a.size.y, towers[0].size.y):
				res.fail("%s: the towers are not all the same size" % who)
		for f in (CastleMassingCheck.new().check(spec, builder))["failures"]:
			res.fail("%s: %s" % [who, str(f)])


## True when `a` reflected through the origin by `sign` is one of `boxes`.
static func _has_mirror(boxes: Array[AABB], a: AABB, sign: Vector3) -> bool:
	var c: Vector3 = a.position + a.size / 2.0
	var want := Vector3(c.x * sign.x, c.y, c.z * sign.z)
	for b in boxes:
		if (b.position + b.size / 2.0).distance_to(want) < MassRules.TOL:
			return true
	return false


## Deterministic per-(landmark, scale) seed, distinct across the whole table.
static func _seed_for(key: String, scale: float) -> int:
	return 3000 + absi(key.hash()) % 1000 + int(scale * 100.0)


# ------------------------------------------------------------ feature forcing

## Set the flags a real landmark demands, overriding the generator's coin
## flips. Sizes the generator already chose are left alone; only the features
## that MAKE the building what it is are forced.
static func _force_features(key: String, spec: CastleSpec) -> void:
	match key:
		"longhouse":
			spec.chimneys = maxi(spec.chimneys, 1)
			spec.wings = 0
		"stokesay":
			# a hall between two towers, inside a low curtain: the earliest
			# fortified manor houses in England
			spec.wings = maxi(spec.wings, 2)
			spec.corner_towers = true
			spec.courtyard = false
		"hampton_range":
			spec.wings = 2
			spec.courtyard = true
			spec.chimneys = maxi(spec.chimneys, 3)
		"bodiam":
			# Four drum towers and a twin-towered gatehouse on a rectangular
			# island enclosed by water.
			_force_plan(spec, &"water", 4)
			spec.ditch_width = clampf(spec.width * 0.16, 8.0, 25.0)
			spec.moat_count = 1
			spec.corner_towers = true
			spec.gate_towers = true
			spec.side_towers = maxi(spec.side_towers, 1)
			# Bodiam's defining fabric has no freestanding keep. Its hall range
			# remains in the courtyard; small scales cannot support a keep stair.
			spec.keep = false
		"caernarfon":
			# the polygonal enceinte itself: a walled circuit that turns at every
			# tower rather than at four corners -- and the Eagle Tower at the
			# west end, 28 m to the parapet at full size (CAS-002)
			_force_plan(spec, &"polygon", 7)
			spec.tower_shape = &"polygonal"
			spec.corner_towers = true
			spec.gate_towers = true
			spec.great_tower = 1
			spec.great_tower_scale = 1.6
			spec.tower_height = 28.0 * (spec.height / 12.0) \
				/ CastleGeometry.great_tower_height_factor(spec.great_tower_scale)
			CastleGenerator.refit(spec)
		"neuschwanstein":
			# a ridge of ranges (CAS-007), the northern tower to 65 m at
			# full size, spires and dormers
			_force_plan(spec, &"ridge", 0)
			spec.tower_roof = &"cone"
			spec.corner_towers = true
			spec.dormers = true
			spec.great_tower = CastleGeometry.spine(spec).size() - 1
			spec.great_tower_scale = 2.0
			spec.tower_height = 65.0 * (spec.height / 25.0) \
				/ CastleGeometry.great_tower_height_factor(spec.great_tower_scale)
		"himeji":
			spec.keep_shape = &"tiered"
			spec.tower_roof = &"tiered"
			spec.corner_towers = true
		"chambord":
			spec.tower_shape = &"round"
			spec.tower_roof = &"cone"
			spec.corner_towers = true
			spec.dormers = true
		"krak":
			_force_concentric(spec)
		"alhambra":
			_force_plan(spec, &"rect", 4)
			spec.tower_shape = &"square"
			spec.tower_roof = &"flat"
			spec.side_towers = maxi(spec.side_towers, 2)
			# the Torre de la Vela: 16 x 16 m in plan and 26.8 m high, at the
			# back corner of the alcazaba (CAS-002)
			spec.great_tower = 3
			spec.great_tower_scale = 2.0
			spec.tower_size = 8.0 * (spec.height / 16.0) / spec.great_tower_scale
			spec.tower_height = 26.8 * (spec.height / 16.0) \
				/ CastleGeometry.great_tower_height_factor(spec.great_tower_scale)
			CastleGenerator.refit(spec)
		"windsor":
			# a motte and bailey (CAS-005): the Round Tower, 30.5 x 27.5 m
			# inside its shell, on the mound behind the upper ward
			_force_plan(spec, &"motte_bailey", 4)
			spec.keep_shape = &"shell"
			spec.corner_towers = true
			var sc: float = spec.height / 18.0
			# the motte itself is 15 m; the refit keeps the mound as given and
			# only pulls the keep in when the site cannot hold the two
			spec.motte_height = 15.0 * sc
			spec.motte_batter = 35.0
			spec.keep_w = 30.5 * sc + 2.0 * spec.shell_thickness
			spec.keep_l = 27.5 * sc + 2.0 * spec.shell_thickness
			spec.keep_height = maxf(spec.keep_height, 20.0 * sc - spec.motte_height)
			CastleGenerator.refit(spec)
		"merchants_tower":
			spec.plan_kind = &"tower_house"
			spec.jog = &"l"
			CastleGenerator.refit(spec)
		"tower_of_london":
			# concentric, with the White Tower -- a great square keep -- in
			# the south-east of the inner ward rather than on the axis
			_force_plan(spec, &"rect", 4)
			_force_concentric(spec)
			spec.keep_shape = &"square"
			spec.chapel = false
			_square_keep(spec)
			spec.keep_offset = CastleGeometry.bailey_rect(spec).size.x * 0.2
			CastleGenerator.refit(spec)
		"conwy":
			# eight towers, two wards side by side
			_force_plan(spec, &"rect", 4)
			spec.tower_shape = &"round"
			spec.corner_towers = true
			spec.side_towers = maxi(spec.side_towers, 2)
		"carcassonne":
			# a double wall with a town inside: the inner ward is most of
			# the outer
			_force_plan(spec, &"rect", 4)
			_force_concentric(spec)
			spec.keep = false
		"malbork":
			_force_plan(spec, &"rect", 4)
			spec.keep_shape = &"square"
		"castel_del_monte":
			spec.corner_towers = true
			spec.gate_towers = false
			spec.great_tower = -1
			spec.great_tower_scale = 1.0
			spec.tower_shape = &"polygonal"
			_force_plan(spec, &"polygon", 8)
		"edinburgh":
			_force_plan(spec, &"ridge", 0)
			spec.corner_towers = true
		"eilean_donan":
			_force_plan(spec, &"water", 4)
			spec.ditch_width = clampf(spec.width * 0.16, 8.0, 25.0)
			spec.moat_count = 1
			spec.keep_shape = &"square"
		"caerphilly":
			_force_plan(spec, &"water", 4)
			spec.ditch_width = clampf(spec.width * 0.16, 8.0, 25.0)
			spec.moat_count = 2
			_force_concentric(spec)
		"dover":
			# concentric, with a great square keep on the axis
			_force_plan(spec, &"rect", 4)
			_force_concentric(spec)
			spec.keep_shape = &"square"
			_square_keep(spec)
			spec.keep_height = maxf(spec.keep_height, CastleGeometry.wall_height(spec, 0) * 1.5)
			CastleGenerator.refit(spec)
		"mont_saint_michel":
			_force_plan(spec, &"rect", 4)


## A great square keep is square: the generator sizes a keep off the ward's
## two sides, which makes an oblong one, so the landmarks that are square in
## plan take the smaller side for both.
static func _square_keep(spec: CastleSpec) -> void:
	var cap: Vector2 = CastleGeometry.max_keep_size(spec)
	var side: float = minf(minf(spec.keep_w, spec.keep_l), minf(cap.x, cap.y))
	spec.keep_w = side
	spec.keep_l = side


## Force the plan kind a real landmark has, then settle the sizes that depend
## on it. Towers are fitted to the run they stand on, and a polygon's runs are
## shorter than its site is wide, so the plan cannot be changed without asking
## the generator to fit the design to it again.
static func _force_plan(spec: CastleSpec, kind: StringName, sides: int) -> void:
	spec.plan_kind = kind
	spec.sides = sides
	CastleGenerator.refit(spec)


## A concentric castle is two enceintes with a walled causeway between the
## gates. It only exists when there is room for it, so this hands the job to
## CastleGenerator and then asks the spec what it got: at small scales Krak is
## simply a large castle.
static func _force_concentric(spec: CastleSpec) -> void:
	spec.corner_towers = true
	CastleGenerator.force_inner_ward(spec)


# --------------------------------------------------------- geometry assertions

## For each landmark, confirm the forced feature actually produced structural
## geometry -- not just a flag flipped on a spec nobody read.
static func _check_required_masses(key: String, spec: CastleSpec,
		builder: CastleBuilder, who: String, res: SuiteResult, scale: float) -> void:
	match key:
		"longhouse":
			_require(builder, who, res, "hall", "hall block")
			_require(builder, who, res, "chimney_0", "chimney stack")
		"stokesay":
			_require(builder, who, res, "hall", "hall range")
			_require(builder, who, res, "wing_left", "cross wing")
			_require(builder, who, res, "tower_manor_0", "defensible tower")
		"hampton_range":
			_require(builder, who, res, "range_front", "range closing the courtyard")
			_require(builder, who, res, "chimney_0", "chimney stack")
		"bodiam":
			_assert_water_plan(spec, builder, who, res, 1)
			_require(builder, who, res, "wall_0_back", "curtain wall")
			_require(builder, who, res, "tower_0_corner_3", "four corner drum towers")
			_require(builder, who, res, "tower_0_gate_0", "twin-towered gatehouse")
			_require(builder, who, res, "hall", "residential hall in the courtyard")
		"caernarfon":
			_require(builder, who, res, "tower_0_corner_6", "a tower at every angle of the circuit")
			var eagle: AABB = builder.mass_aabb("tower_0_corner_1")
			if absf(eagle.size.y - 28.0 * scale) > 0.1:
				res.fail("%s: the Eagle Tower is %.1fm to the parapet, wants %.1f" % [who, eagle.size.y, 28.0 * scale])
			for seg in CastleGeometry.wall_segments(spec, 0):
				_require(builder, who, res, "wall_0_%s" % String(seg["name"]),
					"curtain following the polygon")
			_require(builder, who, res, "gate_0", "gatehouse")
		"neuschwanstein":
			_require(builder, who, res, "tower_0_corner_0", "corner towers with spires")
			_require(builder, who, res, "hall", "palas range")
			if spec.plan_kind != &"ridge":
				res.fail("%s: the plan is %s, not a ridge" % [who, String(spec.plan_kind)])
			var run: float = CastleGeometry.spine_length(spec)
			if run < 120.0 * scale - 0.1:
				res.fail("%s: the spine runs %.1fm, wants %.0f" % [who, run, 120.0 * scale])
			var north: AABB = builder.mass_aabb("tower_0_corner_%d" % (CastleGeometry.spine(spec).size() - 1))
			if absf(north.size.y - 65.0 * scale) > 0.1:
				res.fail("%s: the northern tower is %.1fm, wants %.1f" % [who, north.size.y, 65.0 * scale])
			for banned in ["wall_0", "gate_0", "keep", "chapel"]:
				if builder.has_mass(banned):
					res.fail("%s: a ridge castle has a %s mass" % [who, banned])
		"himeji":
			_require(builder, who, res, "keep", "tiered tenshu")
		"chambord":
			_require(builder, who, res, "tower_0_corner_0", "corner drum towers")
			_require(builder, who, res, "keep", "central keep")
		"krak":
			_require(builder, who, res, "wall_0_back", "outer curtain")
			if spec.inner_ward:
				_require(builder, who, res, "wall_1_back", "inner curtain")
				_require(builder, who, res, "link_left", "causeway between the gates")
			elif is_equal_approx(scale, 1.0):
				res.fail("%s: at full size Krak must be concentric, and is not" % who)
		"alhambra":
			_require(builder, who, res, "tower_0_side_0", "square mural towers")
			_require(builder, who, res, "tower_0_corner_3", "the Torre de la Vela")
			var vela: AABB = builder.mass_aabb("tower_0_corner_3")
			if absf(vela.size.y - 26.8 * scale) > 0.1:
				res.fail("%s: the Torre de la Vela is %.1fm high, wants %.1f" % [who, vela.size.y, 26.8 * scale])
			var side: float = CastleGeometry.tower_half_at(spec, 0, 3) * 2.0
			if absf(side - 16.0 * scale) > 0.1:
				res.fail("%s: the Torre de la Vela is %.1fm square, wants %.1f" % [who, side, 16.0 * scale])
		"windsor":
			_require(builder, who, res, "keep", "shell keep")
			_require(builder, who, res, "motte", "the mound")
			_require(builder, who, res, "climb", "the curtain up the mound")
			var shell: AABB = builder.mass_aabb("keep_shell")
			var inner_w: float = shell.size.x - 2.0 * spec.shell_thickness
			var inner_l: float = shell.size.z - 2.0 * spec.shell_thickness
			if absf(inner_w - 30.5 * scale) > 0.1 or absf(inner_l - 27.5 * scale) > 0.1:
				res.fail("%s: the Round Tower is %.1f x %.1fm inside, wants %.1f x %.1f"
					% [who, inner_w, inner_l, 30.5 * scale, 27.5 * scale])
		"tower_of_london":
			_require(builder, who, res, "wall_1_back", "the inner curtain")
			_require(builder, who, res, "keep", "the White Tower")
			var white: AABB = builder.mass_aabb("keep")
			if absf(white.size.x - white.size.z) > white.size.x * 0.25:
				res.fail("%s: the White Tower is not square (%.1f x %.1f)" % [who, white.size.x, white.size.z])
			var off: float = white.position.x + white.size.x / 2.0
			if absf(off) < CastleGeometry.bailey_rect(spec).size.x * 0.1:
				res.fail("%s: the keep stands on the axis (x=%.1f); the White Tower is off it" % [who, off])
		"conwy":
			var towers := 0
			for m in builder.mass_log:
				if String(m["name"]).begins_with("tower_0_"):
					towers += 1
			if towers < 8:
				res.fail("%s: %d towers, Conwy has eight" % [who, towers])
			# two wards side by side: not nested, and not one
			if not builder.has_mass("wall_1_back") or spec.inner_ward:
				res.fail("%s: the wards are nested or single; Conwy's stand side by side" % who)
		"carcassonne":
			_require(builder, who, res, "wall_1_back", "the inner wall")
			var outer: Rect2 = CastleGeometry.enceinte_rect(spec, 0)
			var inner_r: Rect2 = CastleGeometry.enceinte_rect(spec, 1)
			var ratio: float = (inner_r.size.x * inner_r.size.y) / maxf(outer.size.x * outer.size.y, 1.0)
			if ratio < 0.4:
				res.fail("%s: the inner area is %.0f%% of the outer, wants 40%%" % [who, ratio * 100.0])
		"malbork":
			res.fail("%s: three wards in a line are not a plan kind yet" % who)
		"castel_del_monte":
			_require(builder, who, res, "tower_0_corner_7", "eight vertex towers")
			if CastleGeometry.plan_sides(spec) != 8:
				res.fail("%s: not an octagon" % who)
		"edinburgh":
			if spec.plan_kind != &"ridge":
				res.fail("%s: not a ridge" % who)
			res.fail("%s: terraced baileys are not built yet (INT-016)" % who)
		"eilean_donan":
			_assert_water_plan(spec, builder, who, res, 1)
		"caerphilly":
			_assert_water_plan(spec, builder, who, res, 2)
		"dover":
			_require(builder, who, res, "wall_1_back", "the inner curtain")
			_require(builder, who, res, "keep", "the great keep")
			var great: AABB = builder.mass_aabb("keep")
			if absf(great.size.x - great.size.z) > great.size.x * 0.25:
				res.fail("%s: the keep is not square" % who)
			if great.size.y < CastleGeometry.wall_height(spec, 0) * 1.5 - 0.1:
				res.fail("%s: the keep is %.1fm over a %.1fm curtain; a great keep is 1.5x" % [who, great.size.y, CastleGeometry.wall_height(spec, 0)])
		"mont_saint_michel":
			res.fail("%s: a church on a terraced ring is not built yet" % who)
		"merchants_tower":
			_require(builder, who, res, "storey_3", "four storeys and more")
			_require(builder, who, res, "platform", "a roof platform")
			_require(builder, who, res, "wing_jog_0", "the L jog")
			var doors := 0
			for p in builder.part_log:
				var opening_kind := String(p.get("opening_kind", ""))
				if opening_kind.is_empty():
					opening_kind = String(p.get("kind", ""))
				if opening_kind != "door" or String(p.get("tag", "")) != "tower_house":
					continue
				var pos: Vector3 = p.get("pos", Vector3.ZERO)
				var size: Vector3 = p.get("size", Vector3.ZERO)
				var sill := pos.y - size.y * 0.5
				if sill < TowerCheck.LIFT_MIN - 0.01:
					res.fail("%s: tower-house door sill %.2fm is below the raised threshold" % [who, sill])
				else:
					doors += 1
			if doors != 1:
				res.fail("%s: %d raised doors, wants one" % [who, doors])
			for f in TowerCheck.new().check(spec, builder)["failures"]:
				res.fail("%s: %s" % [who, str(f)])
			# the Bologna type at full size, Scottish once the base passes 10 m
			var want: StringName = &"bologna" if spec.width <= 10.0 else &"scottish"
			if spec.tower_type != want:
				res.fail("%s: a %.0fm base should be the %s type, got %s"
					% [who, spec.width, String(want), String(spec.tower_type)])


static func _require(builder: CastleBuilder, who: String, res: SuiteResult,
		prefix: String, feature: String) -> void:
	if not builder.has_mass(prefix):
		res.fail("%s: %s did not produce a mass starting with '%s'" % [who, feature, prefix])


static func _assert_water_plan(spec: CastleSpec, builder: CastleBuilder,
		who: String, res: SuiteResult, wanted_rings: int) -> void:
	if spec.plan_kind != &"water":
		res.fail("%s: plan kind is %s, wants water" % [who, String(spec.plan_kind)])
	var rings := {}
	var segments_by_ring := {}
	for mass in builder.mass_log:
		var name: String = mass.name
		if not name.begins_with("moat_"):
			continue
		if not MassRules.is_negative(mass) or mass.get("kind", &"") != &"water":
			res.fail("%s: %s is not a negative water mass" % [who, name])
		if float(mass.get("depth", 0.0)) < 2.0 or float(mass.get("depth", 0.0)) > 4.0:
			res.fail("%s: %s depth %.2fm is outside 2-4m" % [who, name, float(mass.get("depth", 0.0))])
		if float(mass.get("width", 0.0)) < 8.0 or float(mass.get("width", 0.0)) > 25.0:
			res.fail("%s: %s width %.2fm is outside 8-25m" % [who, name, float(mass.get("width", 0.0))])
		rings[int(mass.get("ring", -1))] = true
		var ring: int = int(mass.get("ring", -1))
		if not segments_by_ring.has(ring):
			segments_by_ring[ring] = []
		segments_by_ring[ring].append(mass)
		var a2: AABB = mass.aabb
		var trench_plan := Rect2(a2.position.x, a2.position.z, a2.size.x, a2.size.z)
		if trench_plan.intersects(CastleGeometry.enceinte_rect(spec, 0)):
			res.fail("%s: %s trench overlaps the curtain island" % [who, name])
		if name == ("moat_%d_front_axis" % ring):
			var road: AABB = CastleGeometry.causeway_aabb(spec)
			var road_plan := Rect2(road.position.x, road.position.z, road.size.x, road.size.z)
			var bridge: AABB = CastleGeometry.drawbridge_aabb(spec)
			var bridge_plan := Rect2(bridge.position.x, bridge.position.z,
				bridge.size.x, bridge.size.z)
			if absf(a2.end.y) > 0.01 or (not trench_plan.intersects(road_plan)
					and not trench_plan.intersects(bridge_plan)):
				res.fail("%s: front trench does not continue beneath the gate crossing at ground level" % who)
	if rings.size() != wanted_rings:
		res.fail("%s: %d moat rings, wants %d" % [who, rings.size(), wanted_rings])
	for ring_index in range(wanted_rings):
		if not _water_ring_valid(spec, segments_by_ring.get(ring_index, []), ring_index):
			res.fail("%s: moat ring %d does not cover all four sides outside the island, with a gate-axis opening" % [who, ring_index])
	if not builder.has_mass("causeway"):
		res.fail("%s: water plan has no emitted causeway mass" % who)
	if not builder.has_mass("drawbridge"):
		res.fail("%s: water plan has no emitted drawbridge" % who)


static func _water_ring_valid(spec: CastleSpec, masses: Array, ring: int) -> bool:
	var found := {}
	var site: Rect2 = CastleGeometry.enceinte_rect(spec, 0)
	var gate_lane: float = CastleGeometry.gate_width(spec, 0) * 0.5 + 1.0
	var trench_width: float = clampf(spec.ditch_width, 8.0, 25.0)
	var expected_front := site.position.y - (CastleGeometry.tower_base_half(spec, 0) + 1.5) \
		- float(ring) * (trench_width + 2.0) - trench_width
	var expected_front_end := expected_front + trench_width
	var road: AABB = CastleGeometry.causeway_aabb(spec)
	var road_plan := Rect2(road.position.x, road.position.z, road.size.x, road.size.z)
	var bridge: AABB = CastleGeometry.drawbridge_aabb(spec)
	var bridge_plan := Rect2(bridge.position.x, bridge.position.z,
		bridge.size.x, bridge.size.z)
	for mass in masses:
		var name: String = String(mass.name)
		if int(mass.get("ring", -1)) != ring:
			continue
		var prefix := "moat_%d_" % ring
		if not name.begins_with(prefix):
			return false
		var side := name.trim_prefix(prefix)
		var a: AABB = mass.aabb
		var plan := Rect2(a.position.x, a.position.z, a.size.x, a.size.z)
		if plan.intersects(site):
			return false
		if side not in ["back", "left", "right", "front_left", "front_right", "front_axis"] \
				or found.has(side):
			return false
		found[side] = true
		match side:
			"back":
				if a.position.z < site.end.y or a.position.x > site.position.x \
						or a.end.x < site.end.x:
					return false
			"left":
				if a.end.x > site.position.x or a.position.z > site.position.y \
						or a.end.z < site.end.y:
					return false
			"right":
				if a.position.x < site.end.x or a.position.z > site.position.y \
						or a.end.z < site.end.y:
					return false
			"front_left":
				if a.end.z > site.position.y or a.end.x > -gate_lane + 0.05 \
						or absf(a.position.z - expected_front) > 0.05 \
						or absf(a.end.z - expected_front_end) > 0.05:
					return false
			"front_right":
				if a.end.z > site.position.y or a.position.x < gate_lane - 0.05 \
						or absf(a.position.z - expected_front) > 0.05 \
						or absf(a.end.z - expected_front_end) > 0.05:
					return false
			"front_axis":
				if a.end.z > site.position.y \
						or absf(a.position.x + gate_lane) > 0.05 \
						or absf(a.end.x - gate_lane) > 0.05 \
						or absf(a.position.z - expected_front) > 0.05 \
						or absf(a.end.z - expected_front_end) > 0.05 \
						or (not plan.intersects(road_plan) and not plan.intersects(bridge_plan)):
					return false
	return found.size() == 6
