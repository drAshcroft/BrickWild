extends RefCounted
## Production integration checks for tower-house raised doors and slit windows.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle tower house openings")
	for row in [
		{"name": "Bologna 8803", "w": 8.0, "l": 8.0, "h": 45.0, "seed": 8803},
		{"name": "Scottish 8804", "w": 14.0, "l": 12.0, "h": 34.0, "seed": 8804},
	]:
		var spec := CastleSpec.new()
		spec.style = &"norman"
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		spec.plan_override = &"tower_house"
		CastleGenerator.generate(spec, int(row.seed))
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var who: String = row.name
		NormalsSuite.check_mesh(res, mesh, who)
		NormalsSuite.check_openings(res, builder, who)
		var doors: Array = builder.part_log.filter(func(p: Dictionary) -> bool:
			return String(p.get("tag", "")) == "tower_house" and String(p.get("opening_kind", "")) == "door")
		_expect(res, doors.size() == 1, who + ": expected one emitted planned entrance")
		var door_sill := -INF
		if not doors.is_empty():
			var door: Dictionary = doors[0]
			door_sill = (door.pos as Vector3).y - (door.size as Vector3).y * 0.5
		_expect(res, door_sill >= 2.0, who + ": entrance sill is below the raised-entry limit")
		var tower := TowerCheck.new().check(spec, builder)
		_expect(res, tower.ok, who + ": TowerCheck failed: " + "; ".join(tower.failures))
		var windows: Array = builder.part_log.filter(func(p: Dictionary) -> bool:
			return String(p.get("tag", "")) == "tower_house" and String(p.get("opening_kind", "")) == "window")
		var planned := CastleTowerPlan.generate(spec, false)
		_expect(res, windows.size() == planned.windows.size(),
			who + ": emitted window count differs from the actual tower plan")
		_expect(res, windows.all(func(p: Dictionary) -> bool:
			return bool(p.get("planned_opening", false))),
			who + ": an emitted tower-house window has no planned opening record")
		for storey in range(1, spec.tower_storeys):
			var low := storey * CastleGeometry.tower_storey_height(spec)
			var high := low + CastleGeometry.tower_storey_height(spec)
			var found := false
			for window in windows:
				var p: Vector3 = window.pos
				var h := float(window.size.y)
				var sill := p.y - h * 0.5
				if sill >= low - 0.05 and sill + h <= high + 0.05:
					found = true
					break
			_expect(res, found, who + ": occupied storey %d has no emitted window inside its height band" % storey)
		var massing := CastleMassingCheck.new().check(spec, builder)
		var facade_failures: Array = massing.failures.filter(func(message: String) -> bool:
			return message.begins_with("facade: tower_house occupied storey"))
		_expect(res, facade_failures.is_empty(), who + ": facade check failed: " + "; ".join(facade_failures))
		# Negative control: the production facade rule must reject the same builder
		# when its actual tower-house window records are removed.
		var original_parts := builder.part_log
		builder.part_log = original_parts.filter(func(p: Dictionary) -> bool:
			return not (String(p.get("tag", "")) == "tower_house" and String(p.get("opening_kind", "")) == "window"))
		var negative := CastleMassingCheck.new().check(spec, builder)
		var caught: bool = negative.failures.any(func(message: String) -> bool:
			return message.begins_with("facade: tower_house occupied storey"))
		_expect(res, caught, who + ": missing-window negative control was not caught")
		builder.part_log = original_parts
		builder.part_log = original_parts.filter(func(p: Dictionary) -> bool:
			return not (String(p.get("tag", "")) == "tower_house" and String(p.get("opening_kind", "")) == "door"))
		var missing_door := TowerCheck.new().check(spec, builder)
		_expect(res, not missing_door.ok, who + ": missing-door negative control was not caught")
		builder.part_log = original_parts
	_platform_entry_contract(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


## The roof platform is open sky over the top chamber, and the raised entrance
## and its steps stand clear of the jogs (CASTLE-INTERIOR-FORMS, 14 Oct). Each
## contract is also run on a mesh built to break it, so the probes are not
## tautologies.
static func _platform_entry_contract(res: SuiteResult) -> void:
	for row in [
		{"name": "L jog 8x8", "w": 8.0, "l": 8.0, "h": 45.0, "seed": 8804, "jog": &"l"},
		{"name": "Z jog 14x12", "w": 14.0, "l": 12.0, "h": 34.0, "seed": 8804, "jog": &"z"},
		{"name": "wizard", "w": 8.0, "l": 8.0, "h": 40.0, "seed": 8803, "style": &"wizard"},
	]:
		var who: String = row.name
		var spec := CastleSpec.new()
		spec.style = row.get("style", &"norman")
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		spec.plan_override = &"tower_house"
		CastleGenerator.generate(spec, int(row.seed))
		if row.has("jog"):
			spec.jog = row.jog
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var tower: Dictionary = {}
		for interior in builder.interiors:
			if String(interior.id) == "tower_house":
				tower = interior
		_expect(res, not tower.is_empty(), who + ": no tower_house interior")
		if tower.is_empty():
			continue
		var plan: HousePlan = tower.plan
		var xf: Transform3D = tower.transform
		var deck := plan.rooms.size() - 1
		_expect(res, plan.kind_of(deck) == &"roof_platform"
			and bool(plan.rooms[deck].get("open_air", false)),
			who + ": the roof platform is not planned as open air")
		# The deck is the top chamber's clear floor, so the tiling rule and the
		# stair landings hold on the room it really is.
		_expect(res, Poly.intersection_area(plan.outline_of(deck), plan.outline_of(deck - 1))
			> Poly.area(plan.outline_of(deck - 1)) * 0.99,
			who + ": the deck is not the top chamber's clear floor")
		var plan_failures: Array = HousePlanCheck.new().check(plan).failures.filter(
			func(m) -> bool:
				var text := str(m)
				return text.begins_with("tiling") or text.begins_with("privacy") \
					or text.begins_with("way in") or text.begins_with("stairs"))
		_expect(res, plan_failures.is_empty(), who + ": plan rules: " + "; ".join(plan_failures))

		# The stair well up to the deck stays open: no stone from 0.3 m to 3 m
		# above the deck floor over the landing.
		var top_stair: Dictionary = plan.stairs[plan.stairs.size() - 1]
		var landing: Vector2 = Rect2(top_stair.upper_rect).get_center()
		var world: Vector3 = xf * Vector3(landing.x, 0.0, landing.y)
		var deck_y: float = spec.height
		var from_p := Vector3(world.x, deck_y + 3.0, world.z)
		var to_p := Vector3(world.x, deck_y + 0.3, world.z)
		_expect(res, not _stone_between(mesh, from_p, to_p),
			who + ": stone fills the stair well on the roof deck")
		# Standing room on the deck, away from the well: head clearance 1.7 m.
		var stand := _deck_standing_point(plan, deck, top_stair, xf, deck_y)
		_expect(res, stand != Vector3.INF
			and not _stone_between(mesh, stand + Vector3.UP * 0.15, stand + Vector3.UP * 1.85),
			who + ": no standing clearance on the roof deck")
		# No storey of walls above the deck: nothing rises past the logged height.
		_expect(res, _max_y(mesh) <= builder.total_height + 0.5,
			who + ": masonry stands above the finished roof (%.2f > %.2f)" % [_max_y(mesh), builder.total_height])

		# Negative controls: the old solid platform slab, and the old walled storey.
		var slab := _with_box(mesh, AABB(Vector3(-spec.width * 0.5 - 0.3, deck_y, -spec.length * 0.5 - 0.3),
			Vector3(spec.width + 0.6, 0.6, spec.length + 0.6)))
		_expect(res, _stone_between(slab, from_p, to_p),
			who + ": control failed: a solid slab on the deck was not seen in the well")
		_expect(res, stand == Vector3.INF or _stone_between(slab, stand + Vector3.UP * 0.15, stand + Vector3.UP * 1.85),
			who + ": control failed: a slab on the deck left standing clearance")
		var walled := _with_box(mesh, AABB(Vector3(-spec.width * 0.5, deck_y, -spec.length * 0.5),
			Vector3(spec.width, builder.total_height - deck_y + 1.0, 0.6)))
		_expect(res, _max_y(walled) > builder.total_height + 0.5,
			who + ": control failed: a walled platform storey was not seen above the roof")

		# The entrance and its steps keep clear of every jog.
		var door: Dictionary = plan.doors[plan.entrance()]
		var door_x: float = (xf * Vector3(door.pos.x, 0.0, door.pos.y)).x
		var steps := preload("res://src/castle/castle_manor_plan.gd").tower_approach_box(spec, Vector2(door_x, -spec.length * 0.5))
		steps.size.y = 1.0
		var jogs := CastleGeometry.tower_jog_aabbs(spec)
		if not jogs.is_empty():
			var front_jog: AABB = jogs[0]
			front_jog.size.y = 1.0
			_expect(res, not steps.intersects(front_jog), who + ": the approach steps cross the front jog")
			_expect(res, absf(door_x) > 0.1, who + ": a jogged tower kept its entrance mid-front")
			var middle := preload("res://src/castle/castle_manor_plan.gd").tower_approach_box(spec, Vector2(0.0, -spec.length * 0.5))
			middle.size.y = 1.0
			_expect(res, middle.intersects(front_jog),
				who + ": control failed: a mid-front entrance did not meet the jog")
		var occupancy: Dictionary = CastleOccupancyCheck.check(spec, builder, mesh)
		var shell_failures: Array = occupancy.failures.filter(func(m) -> bool:
			var text := str(m)
			return text.begins_with("occupied_shells[tower_house]") \
				or text.begins_with("occupied_shells[wing_jog"))
		_expect(res, shell_failures.is_empty(), who + ": emitted shell: " + "; ".join(shell_failures))


static func _triangles(mesh: ArrayMesh) -> Array:
	var out: Array = []
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index = arrays[Mesh.ARRAY_INDEX]
		if index == null or index.size() == 0:
			index = PackedInt32Array(range(verts.size()))
		for i in range(0, index.size(), 3):
			out.append([surface, verts[index[i]], verts[index[i + 1]], verts[index[i + 2]]])
	return out


## Whether stone (anything but the dark-opening and ground slots) crosses a segment.
static func _stone_between(mesh: ArrayMesh, a: Vector3, b: Vector3) -> bool:
	for t in _triangles(mesh):
		if int(t[0]) in [CastleBuilder.SURF_OPEN, CastleBuilder.SURF_GROUND]:
			continue
		if Geometry3D.segment_intersects_triangle(a, b, t[1], t[2], t[3]) != null:
			return true
	return false


static func _max_y(mesh: ArrayMesh) -> float:
	var top := -INF
	for t in _triangles(mesh):
		top = maxf(top, maxf(t[1].y, maxf(t[2].y, t[3].y)))
	return top


## A copy of `mesh` with one extra box of stone, folded into surface 0 (the
## stone slot, which a committed castle mesh always has first).
static func _with_box(mesh: ArrayMesh, box: AABB) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if surface != 0:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			continue
		var verts := PackedVector3Array()
		var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index = arrays[Mesh.ARRAY_INDEX]
		if index == null or index.size() == 0:
			verts.append_array(source)
		else:
			for i in index:
				verts.append(source[i])
		var c := [box.position, box.position + Vector3(box.size.x, 0, 0),
			box.position + Vector3(box.size.x, 0, box.size.z), box.position + Vector3(0, 0, box.size.z)]
		var up := Vector3(0, box.size.y, 0)
		for quad in [[c[0], c[1], c[2], c[3]], [c[0] + up, c[1] + up, c[2] + up, c[3] + up]]:
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for k in tri:
					verts.append(quad[k])
		for i in range(4):
			var p0: Vector3 = c[i]
			var p1: Vector3 = c[(i + 1) % 4]
			for tri in [[p0, p1, p1 + up], [p0, p1 + up, p0 + up]]:
				for v in tri:
					verts.append(v)
		var stone := []
		stone.resize(Mesh.ARRAY_MAX)
		stone[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stone)
	return out


## A point on the deck inside its outline and well away from the stair landing.
static func _deck_standing_point(plan: HousePlan, deck: int, stair: Dictionary,
		xf: Transform3D, deck_y: float) -> Vector3:
	var outline: PackedVector2Array = plan.outline_of(deck)
	var rect := Poly.bounding_rect(outline)
	var well := Rect2(stair.upper_rect).grow(0.6)
	var best := Vector3.INF
	var best_d := -1.0
	for u in range(1, 8):
		for v in range(1, 8):
			var q := rect.position + rect.size * Vector2(u / 8.0, v / 8.0)
			if not Poly.contains_point(outline, q) or well.has_point(q):
				continue
			var d := q.distance_to(well.get_center())
			if d > best_d:
				best_d = d
				best = xf * Vector3(q.x, deck_y + 0.12, q.y)
	return best
