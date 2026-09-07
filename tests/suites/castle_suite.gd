class_name CastleSuite
extends RefCounted
## 6. Contract: user inputs survive generation, the footprint picks the right
##    KIND of building, meshes are well formed, and the same seed rebuilds the
##    identical fortification.
##
## The tier assertion is the one that matters most here. "Small is a house,
## huge is a fortress" is the whole premise of this generator, so it is checked
## against CastleSpec.tier_for rather than against whatever the generator
## happened to feel like.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle")
	for style in CastleSweep.styles():
		for tier in CastleSweep.tiers():
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var row: Dictionary = CastleSweep.SIZES[tier][i]
				var sd: int = CastleSweep.seed_at(tier, i)
				var where := "style=%s tier=%s seed=%d" % [String(style), String(tier), sd]
				res.checked += 1

				if spec.style != style or not is_equal_approx(spec.width, float(row["w"])) \
						or not is_equal_approx(spec.length, float(row["l"])) \
						or not is_equal_approx(spec.height, float(row["h"])):
					res.fail("user inputs mutated, " + where)
					continue
				if spec.tier != tier:
					res.fail("%s: a %.0f x %.0fm site generated as a %s, not a %s"
						% [where, spec.width, spec.length, String(spec.tier), String(tier)])
					continue

				var builder := CastleBuilder.new()
				var before := _fingerprint(spec)
				var mesh: ArrayMesh = builder.build(spec)
				# build() must be a pure function of its spec
				if _fingerprint(spec) != before:
					res.fail("build() mutated its spec, " + where)
				if mesh == null or mesh.get_surface_count() != 4:
					res.fail("bad mesh, " + where)
					continue
				var verts := 0
				for s in range(mesh.get_surface_count()):
					verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
						as PackedVector3Array).size()
				if verts < 100:
					res.fail("too few verts (%d), %s" % [verts, where])
				if builder.mass_log.is_empty():
					res.fail("no structural masses logged, " + where)

	# determinism: same seed, same geometry
	var a := CastleSpec.new(); a.style = &"edwardian"; a.width = 60.0; a.length = 90.0
	var b := CastleSpec.new(); b.style = &"edwardian"; b.width = 60.0; b.length = 90.0
	CastleGenerator.generate(a, 4242)
	CastleGenerator.generate(b, 4242)
	res.checked += 1
	var ma: PackedVector3Array = CastleBuilder.new().build(a).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mb: PackedVector3Array = CastleBuilder.new().build(b).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if ma != mb:
		res.fail("same seed produced different geometry")

	# idempotence: building the same spec twice must not drift
	var c: CastleSpec = CastleSweep.spec_at(&"norman", &"castle", 1)
	res.checked += 1
	var bb := CastleBuilder.new()
	var m1: PackedVector3Array = bb.build(c).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var m2: PackedVector3Array = bb.build(c).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if m1 != m2:
		res.fail("rebuilding the same spec produced different geometry")

	# ---- the plan ----
	# enceinte_rect() is the contract every rectangle-shaped rule in
	# CastleGeometry is written against, so a polygonal plan is only allowed to
	# exist if its bounding box is still exactly that rectangle.
	for n in range(CastleGeometry.POLY_MIN_SIDES, CastleGeometry.POLY_MAX_SIDES + 1):
		var ps := CastleSpec.new()
		ps.style = &"edwardian"
		ps.width = 70.0
		ps.length = 95.0
		ps.height = 16.0
		ps.plan_override = &"polygon"
		ps.sides_override = n
		CastleGenerator.generate(ps, 7700 + n)
		res.checked += 1
		if ps.plan_kind != &"polygon" or ps.sides != n:
			res.fail("plan_override did not hold: got %s/%d, asked for polygon/%d"
				% [String(ps.plan_kind), ps.sides, n])
			continue
		for ring in CastleGeometry.rings(ps):
			var poly: PackedVector2Array = CastleGeometry.enceinte_polygon(ps, ring)
			if poly.size() != n:
				res.fail("N=%d: enceinte_polygon returned %d vertices" % [n, poly.size()])
				continue
			var bounds: Rect2 = CastleGeometry.polygon_bbox(poly)
			var rect: Rect2 = CastleGeometry.enceinte_rect(ps, ring)
			if not (bounds.position.is_equal_approx(rect.position)
					and bounds.size.is_equal_approx(rect.size)):
				res.fail("N=%d ring %d: polygon bounds %s, enceinte_rect %s"
					% [n, ring, str(bounds), str(rect)])
			# the gate edge: flat, facing -Z, and at the front of the site
			if not is_equal_approx(poly[0].y, poly[1].y) 					or not is_equal_approx(poly[0].y, rect.position.y):
				res.fail("N=%d ring %d: edge 0 is not the flat facing -Z" % [n, ring])
		# a polygonal castle is still a castle: walls, towers, a way in
		var pb := CastleBuilder.new()
		pb.build(ps)
		if not pb.has_mass("wall_0_front_left") or not pb.has_mass("wall_0_back") 				or not pb.has_mass("gate_0") or not pb.has_mass("tower_0_corner_%d" % (n - 1)):
			res.fail("N=%d: the polygonal enceinte is missing a wall, a gate or a tower" % n)

	# a forced rectangle is the four-sided case of the same construction
	var rs := CastleSpec.new()
	rs.style = &"edwardian"
	rs.width = 70.0
	rs.length = 95.0
	rs.plan_override = &"rect"
	CastleGenerator.generate(rs, 7711)
	res.checked += 1
	if CastleGeometry.plan_sides(rs) != 4 			or CastleGeometry.enceinte_polygon(rs, 0).size() != 4:
		res.fail("plan_override = rect did not produce the four-sided plan")

	# the tier rule itself, at the boundaries it is defined by
	res.checked += 1
	var bands := [[10.0, 10.0, &"house"], [20.0, 20.0, &"manor"],
		[50.0, 50.0, &"castle"], [120.0, 120.0, &"fortress"]]
	for band in bands:
		var got: StringName = CastleSpec.tier_for(band[0], band[1])
		if got != band[2]:
			res.fail("tier_for(%.0f, %.0f) = %s, expected %s"
				% [band[0], band[1], String(got), String(band[2])])

	_great_hall(res)
	_keep(res)
	_chapel(res)
	return res


## The great hall has an inside (CAS-010).
##
## The hall used to be a logged mass with nothing in it. It is now a
## single-room HousePlan, which means the whole house harness judges it: the
## plan check for the room and its openings, the furnishing check for what
## stands in it, the nav check for whether a person can walk it. So the
## assertions below are only the ones the house harness has no name for -- the
## things that make a hall a HALL rather than a large room:
##
##   the room IS the hall range, less its walls
##   the dais is at the end away from the door, a step high, a fifth deep
##   the high table stands on the dais and is what the plan is arranged around
##   nobody sits between the high table and the hall
##   the trestles are rows, and there is a screens passage inside the door
##
## Everything else is delegated, on purpose. A hall that failed `tiling` or
## `row` or `steps` should be reported by the rule that owns those words.
static func _great_hall(res: SuiteResult) -> void:
	var halls := 0
	var two_rows := 0
	var ranges: Array[Dictionary] = CastleSweep.each()
	for e in ranges:
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], e["index"])
		var plan: HousePlan = CastleGenerator.hall_plan(spec)
		var who := "great hall: %s %s %d" % [String(e["style"]), String(e["tier"]),
			int(e["index"])]
		res.checked += 1
		if plan.spec == null:
			# a range too small to feast in gets no plan rather than a bad one
			continue
		halls += 1

		if plan.room_count() != 1 or plan.kind_of(0) != &"great_hall":
			res.fail("%s: %d rooms, first is %s -- a hall is one room"
				% [who, plan.room_count(), String(plan.kind_of(0))])
			continue
		# the room is the hall range, less the wall it is inside
		var box: AABB = CastleGeometry.hall_aabb(spec)
		var want := Vector2(box.size.x, box.size.z) - Vector2.ONE * HouseGeometry.WALL_T * 2.0
		var floor_rect: Rect2 = plan.rooms[0]["rect"]
		if not floor_rect.size.is_equal_approx(want):
			res.fail("%s: the room is %.2f x %.2fm, the range inside its walls is %.2f x %.2fm"
				% [who, floor_rect.size.x, floor_rect.size.y, want.x, want.y])

		# the dais: at the far end from the door, a step up, a fifth of the hall
		var lengthwise: bool = floor_rect.size.y >= floor_rect.size.x
		var up := Vector2(0, 1) if lengthwise else Vector2(1, 0)
		var run: float = floor_rect.size.y if lengthwise else floor_rect.size.x
		var dais: Rect2 = plan.dais_rect()
		var rise: float = plan.dais_rise()
		if dais.size.x <= 0.0:
			res.fail("%s: no dais" % who)
			continue
		if rise < 0.3 or rise > 0.6:
			res.fail("%s: the dais rises %.2fm -- that is a stair, or nothing"
				% [who, rise])
		if rise > WalkGrid.MAX_STEP:
			res.fail("%s: the dais rises %.2fm and WalkGrid walks up %.2fm"
				% [who, rise, WalkGrid.MAX_STEP])
		var depth: float = dais.size.y if lengthwise else dais.size.x
		if depth < run * 0.2 - 0.01:
			res.fail("%s: the dais is %.2fm of a %.2fm hall -- under a fifth"
				% [who, depth, run])
		var door: Vector2 = plan.doors[plan.entrance()]["pos"]
		if (dais.get_center() - door).dot(up) < run * 0.4:
			res.fail("%s: the dais is at the same end of the hall as the door" % who)

		# the high table stands ON it, and is what the hall is arranged around
		if plan.focus_cat() != "table" or plan.focus_room() != 0:
			res.fail("%s: the hall is not arranged around a table" % who)
			continue
		# the high table is the piece the focus records, the same way
		# HouseFurnishCheck finds it: the nearest table to where the plan
		# pinned one. Picking "a table on the dais" would find a trestle.
		var high := -1
		var best := INF
		for f in range(plan.furniture.size()):
			var q: Dictionary = plan.furniture[f]
			if PropCatalog.category(String(q["key"])) != "table":
				continue
			var d: float = Rect2(q["rect"]).get_center().distance_to(plan.focus_pos())
			if d < best:
				best = d
				high = f
		if high < 0 or best > 0.3:
			if not plan.was_dropped(0, "table"):
				res.fail("%s: no high table where the plan pinned one" % who)
			continue
		if not dais.has_point(Rect2(plan.furniture[high]["rect"]).get_center()):
			res.fail("%s: the high table stands off the dais" % who)
		var hc: Vector2 = Rect2(plan.furniture[high]["rect"]).get_center()
		# on the dais means ON it: the piece is lifted by the rise
		var lifted: float = float(plan.furniture[high]["pos"].y)
		if not is_equal_approx(lifted, rise):
			res.fail("%s: the high table stands at y=%.2f on a %.2fm dais"
				% [who, lifted, rise])
		# and nobody sits between it and the hall
		for f2 in range(plan.furniture.size()):
			var seat: Dictionary = plan.furniture[f2]
			var cat: String = PropCatalog.category(String(seat["key"]))
			if cat != "seat" and cat != "bench":
				continue
			var sc: Vector2 = Rect2(seat["rect"]).get_center()
			if sc.distance_to(hc) > HIGH_TABLE_REACH:
				continue
			if (sc - hc).dot(up) < -0.05:
				res.fail("%s: a %s sits between the high table and the hall"
					% [who, String(seat["key"])])
				break

		# the trestles are rows
		var groups := {}
		for q2 in plan.furniture:
			var g: String = String(q2.get("row", ""))
			if g != "":
				groups[g] = int(groups.get(g, 0)) + 1
		if groups.is_empty() and not plan.was_dropped(0, "table"):
			res.fail("%s: no trestle row and no note of why not" % who)
		for g2 in groups:
			if int(groups[g2]) < 2:
				res.fail("%s: row %s is one table -- that is not a row" % [who, g2])
		if groups.size() >= 2:
			two_rows += 1

		# the fire is on a long wall, where the flue can rise
		var long_walls := [2, 3] if lengthwise else [0, 1]
		if not plan.hearth_wall() in long_walls:
			res.fail("%s: the fire is on wall %d, an end wall of the hall"
				% [who, plan.hearth_wall()])

		# and the screens passage is inside the door, and empty
		var strip := Rect2()
		for z in plan.zones:
			if String(z.get("why", "")) == "screens passage":
				strip = Rect2(z["rect"])
		if strip.size.x <= 0.0:
			res.fail("%s: no screens passage" % who)
		else:
			var deep: float = strip.size.y if lengthwise else strip.size.x
			if deep < HouseGeometry.PATH_MIN:
				res.fail("%s: the screens passage is %.2fm -- you cannot walk it"
					% [who, deep])
			if (strip.get_center() - door).dot(up) > run * 0.5:
				res.fail("%s: the screens passage is not by the door" % who)

		# and the house harness has its say
		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), HouseNavCheck.new().check(plan)]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
	res.note("great hall  %2d of %d ranges furnished, %d with two trestle rows"
		% [halls, ranges.size(), two_rows])


## How near the high table a seat has to be before it counts as being AT it.
const HIGH_TABLE_REACH := 2.5


## The keep has an inside (CAS-011).
##
## Like the great hall it is a HousePlan, so the plan, furnishing and walking
## checks judge it and are not repeated here. What IS here is the handful of
## things that make it a keep rather than a tall house:
##
##   a blind foot -- no windows on storey 0, which is the point of a keep
##   the hall UP a stair over that store, which no dwelling is allowed
##   the lord at the top, with a bed and a fire of his own
##   one stairwell, against a wall, chaining every storey
static func _keep(res: SuiteResult) -> void:
	var built := 0
	var ranges: Array[Dictionary] = CastleSweep.each()
	for e in ranges:
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], e["index"])
		var plan: HousePlan = CastleGenerator.keep_plan(spec)
		var who := "keep: %s %s %d" % [String(e["style"]), String(e["tier"]),
			int(e["index"])]
		res.checked += 1
		if plan.spec == null:
			continue                    # no keep, or too small to stack
		built += 1

		var levels: int = plan.spec.storeys
		if levels < 3 or levels > HouseGeometry.MAX_STOREYS:
			res.fail("%s: %d storeys -- a keep is three or four" % [who, levels])
			continue
		if plan.room_count() != levels:
			res.fail("%s: %d rooms over %d storeys -- one room to a storey"
				% [who, plan.room_count(), levels])
			continue
		if plan.kind_of(0) != &"store":
			res.fail("%s: the foot is a %s, not a store"
				% [who, String(plan.kind_of(0))])
		if plan.kind_of(1) != &"hall":
			res.fail("%s: the first floor is a %s, not the hall"
				% [who, String(plan.kind_of(1))])
		if plan.kind_of(levels - 1) != &"lords_chamber":
			res.fail("%s: the top is a %s, not the lord's chamber"
				% [who, String(plan.kind_of(levels - 1))])

		# blind at the foot, lit above
		for w in plan.windows:
			if HousePlan.record_storey(w) == 0:
				res.fail("%s: a window at the foot of a keep" % who)
				break
		for i in range(1, levels):
			if not HouseGeometry.is_habitable(plan.kind_of(i)):
				continue
			if plan.windows_of(i).is_empty():
				res.fail("%s: room %d (%s) has no window"
					% [who, i, String(plan.kind_of(i))])

		# one stairwell, chaining every storey, against a wall
		var joined := {}
		for st in plan.stairs:
			joined[int(st.get("storey", 0))] = true
			var rect: Rect2 = st["rect"]
			var f: Rect2 = HouseGeometry.room_floor_rect(plan, int(st["a"]))
			var touches: bool = absf(rect.position.x - f.position.x) < WALL_TOL \
				or absf(rect.end.x - f.end.x) < WALL_TOL \
				or absf(rect.position.y - f.position.y) < WALL_TOL \
				or absf(rect.end.y - f.end.y) < WALL_TOL
			if not touches:
				res.fail("%s: the stair from storey %d stands off every wall"
					% [who, int(st.get("storey", 0))])
		for level in range(levels - 1):
			if not joined.has(level):
				res.fail("%s: nothing joins storey %d to %d"
					% [who, level, level + 1])

		# the lord has a bed and a fire, and the fire is on the flue's wall
		var top: int = levels - 1
		if plan.hearth_room() != top:
			res.fail("%s: the chimney serves room %d, not the lord's chamber"
				% [who, plan.hearth_room()])
		var beds := 0
		var fires := 0
		for f2 in plan.furniture_of(top):
			match PropCatalog.category(String(plan.furniture[f2]["key"])):
				"bed":
					beds += 1
				"hearth":
					fires += 1
		if beds == 0 and not plan.was_dropped(top, "bed"):
			res.fail("%s: nobody sleeps in the lord's chamber" % who)
		if fires == 0 and not plan.was_dropped(top, "hearth"):
			res.fail("%s: no fire in the lord's chamber" % who)

		# and the house harness has its say -- including that the walk from
		# the keep door reaches everything the lord uses
		var nav := HouseNavCheck.new()
		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), nav.check(plan)]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
			for w2 in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w2)])
		if not nav.unreachable_items.is_empty():
			res.fail("%s: %d pieces cannot be reached from the keep door"
				% [who, nav.unreachable_items.size()])
	res.note("keep        %2d of %d castles have one" % [built, ranges.size()])


## How close a stairwell has to be to a wall to count as standing against it.
const WALL_TOL := 0.35


## The chapel has an inside (CAS-014).
##
## A chapel is a hall with one thing at the end of it, so the plan, furnishing
## and walking checks judge it exactly as they judge the great hall and are not
## repeated here. What IS here is the AXIS -- the way in, the aisle and the
## altar on one line -- which is the temple's own question asked of a nave
## (`TempleRiteCheck.plan_axis_faults`), and the pews either side of it.
static func _chapel(res: SuiteResult) -> void:
	var built := 0
	var ranges: Array[Dictionary] = CastleSweep.each()
	for e in ranges:
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], e["index"])
		var plan: HousePlan = CastleGenerator.chapel_plan(spec)
		var who := "chapel: %s %s %d" % [String(e["style"]), String(e["tier"]),
			int(e["index"])]
		res.checked += 1
		if plan.spec == null:
			continue
		built += 1

		if plan.room_count() != 1 or plan.kind_of(0) != &"nave":
			res.fail("%s: %d rooms, first is %s -- a chapel is one nave"
				% [who, plan.room_count(), String(plan.kind_of(0))])
			continue
		# the altar and the way in on one line, and the altar down the nave
		for m in TempleRiteCheck.plan_axis_faults(plan, 0, plan.entrance()):
			res.fail("%s: %s" % [who, str(m)])
		# the sanctuary is a step, and the altar stands on it
		var sanct: Rect2 = plan.dais_rect()
		if sanct.size.x <= 0.0:
			res.fail("%s: no sanctuary at the altar end" % who)
		var altar := -1
		var best := INF
		for f in range(plan.furniture.size()):
			if PropCatalog.category(String(plan.furniture[f]["key"])) != "table":
				continue
			var d: float = Rect2(plan.furniture[f]["rect"]).get_center() \
				.distance_to(plan.focus_pos())
			if d < best:
				best = d
				altar = f
		if altar < 0 or best > 0.3:
			if not plan.was_dropped(0, "table"):
				res.fail("%s: no altar where the plan pinned one" % who)
		elif sanct.size.x > 0.0 \
				and not sanct.has_point(Rect2(plan.furniture[altar]["rect"]).get_center()):
			res.fail("%s: the altar stands off the sanctuary" % who)

		# the pews: rows either side, with an aisle between them
		var rows := {}
		for q in plan.furniture:
			var g: String = String(q.get("row", ""))
			if g != "":
				rows[g] = int(rows.get(g, 0)) + 1
		if rows.size() < 2 and not plan.was_dropped(0, "bench"):
			res.fail("%s: %d pew rows -- a nave has one each side of the aisle"
				% [who, rows.size()])
		for g2 in rows:
			if int(rows[g2]) < 2:
				res.fail("%s: row %s is one pew -- that is not a row" % [who, g2])

		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), HouseNavCheck.new().check(plan)]:
			for m2 in rep["failures"]:
				res.fail("%s: %s" % [who, str(m2)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
	res.note("chapel      %2d of %d castles have one" % [built, ranges.size()])


## Everything about a spec the builder could plausibly rewrite.
static func _fingerprint(spec: CastleSpec) -> Array:
	return [spec.tier, spec.width, spec.length, spec.height, spec.wall_thickness,
		spec.tower_size, spec.tower_height, spec.side_towers, spec.corner_towers,
		spec.gate_width, spec.gate_depth, spec.inner_ward, spec.ward_gap,
		spec.keep, spec.keep_w, spec.keep_l, spec.keep_height,
		spec.hall, spec.hall_w, spec.hall_l, spec.chapel, spec.wings,
		spec.courtyard, spec.chimneys]
