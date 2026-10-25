class_name HouseTraitMeasure
extends RefCounted
## HS-* style traits, measured from the plan, mass_log and component_log (not
## from a picture). One call builds one house and returns plain numbers; each
## style's focused test states its own thresholds over them. Later HS-* tasks
## extend `measure()` with the keys they need rather than writing a second
## builder harness.
##
## Keys: storeys, eave_top (wall top above the floor, m), ridge_top (highest
## main-roof vertex), chimney_count, chimney_top, chimney_on_hearth_wall,
## chimney_clearance (m over the ridge), chimney_above_ridge, door_sheltered (a porch roof, posts and step all stand
## over the entrance door), porch_roof_count.
## HS-LONGHALL keys are listed on `_longhall_keys`.


static func make_spec(style: StringName, width: float, length: float, height: float,
		storeys := 1) -> HouseSpec:
	var spec := HouseSpec.new()
	spec.style = style
	spec.width = width
	spec.length = length
	spec.height = height
	spec.storeys = storeys
	return spec


## `tweak` (optional) runs on the generated plan before building: a negative
## control removes one trait there and the measure must notice.
static func measure(spec: HouseSpec, p_seed: int, tweak := Callable(),
		furnished := false) -> Dictionary:
	var plan := HouseGenerator.generate(spec, p_seed, furnished)
	if tweak.is_valid():
		tweak.call(plan)
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var out := {"storeys": plan.spec.storeys}
	out["eave_top"] = plan.spec.height * float(maxi(plan.spec.storeys, 1))
	out["ridge_top"] = _ridge_top(mesh, plan)
	var stacks: Array = []
	for m in builder.mass_log:
		if str(m.get("name", "")) == "chimney":
			stacks.append(m["aabb"])
	out["chimney_count"] = stacks.size()
	out["chimney_top"] = -INF
	out["chimney_on_hearth_wall"] = false
	if stacks.size() > 0:
		var a: AABB = stacks[0]
		out["chimney_top"] = a.position.y + a.size.y
		out["chimney_on_hearth_wall"] = _on_hearth_wall(plan, a)
	out["chimney_clearance"] = out["chimney_top"] - out["ridge_top"]
	out["chimney_above_ridge"] = out["chimney_top"] > out["ridge_top"] + 0.05
	var roofs := 0
	for part in builder.component_log:
		if str(part.get("role", "")) == "porch_roof":
			roofs += 1
	out["porch_roof_count"] = roofs
	out["door_sheltered"] = _door_sheltered(plan, builder, roofs)
	_farm_keys(plan, builder, out)
	_town_keys(plan, out)
	_longhall_keys(plan, builder, out)
	_rich_keys(plan, builder, out)
	return out


## HS-TOWNHOUSE keys: `frontage` and `depth` (the entrance facade's length and
## the house's depth behind it, m), `frontage_narrower`, `room_storeys`,
## `ground_bedrooms`, `ground_work` (a work room on the ground floor: office,
## workshop or shop), `upper_bedrooms`, and the stair spine walked from the
## entrance room: `spine_storeys` (storeys reached by satisfied stairs),
## `spine_landings` (storeys whose foot or head landing is a real rectangle) and
## `spine_lit` (storeys whose landing room has a window).
static func _town_keys(plan: HousePlan, out: Dictionary) -> void:
	var r := HouseGeometry.site_rect(plan.spec)
	var e := plan.entrance()
	var along_x := true
	if e >= 0:
		along_x = absf(Vector2(plan.doors[e]["normal"]).y) > 0.5
	out["frontage"] = r.size.x if along_x else r.size.y
	out["depth"] = r.size.y if along_x else r.size.x
	out["frontage_narrower"] = out["frontage"] < out["depth"]
	var top := 0
	var ground_bed := 0
	var upper_bed := 0
	var work := false
	for i in range(plan.rooms.size()):
		var st := plan.storey_of_room(i)
		top = maxi(top, st)
		var kind := plan.kind_of(i)
		if st == 0 and kind in [&"office", &"workshop", &"shop"]:
			work = true
		if kind in [&"bedroom", &"guest_room", &"suite"]:
			if st == 0:
				ground_bed += 1
			elif st > 0:
				upper_bed += 1
	out["room_storeys"] = top + 1
	out["ground_bedrooms"] = ground_bed
	out["upper_bedrooms"] = upper_bed
	out["ground_work"] = work
	var here := plan.entrance_room()
	var reached := 1 if here >= 0 else 0
	var landings := 0
	var lit := 0
	var spent := {}
	if here >= 0 and not plan.windows_of(here).is_empty():
		lit += 1
	var guard := 0
	while here >= 0 and guard < 6:
		guard += 1
		var next := -1
		for k in range(plan.stairs.size()):
			var s: Dictionary = plan.stairs[k]
			if spent.has(k) or int(s["a"]) != here or int(s["to_storey"]) != int(s["storey"]) + 1:
				continue
			if not bool(s.get("satisfied", true)):
				continue
			spent[k] = true
			next = int(s["b"])
			if Rect2(s.get("foot_landing", Rect2())).has_area() 					and Rect2(s.get("head_landing", Rect2())).has_area():
				landings += 1
			break
		if next < 0:
			break
		reached += 1
		if not plan.windows_of(next).is_empty():
			lit += 1
		here = next
	out["spine_storeys"] = reached
	out["spine_landings"] = landings
	out["spine_lit"] = lit


## HS-RICH keys (a furnished plan is needed for the seats):
##   door_room_kind      kind of the room the front door opens into
##   hall_holds_stair    that room is a hall AND the ground-to-first stair starts in it
##                       (satisfied, foot landing and well inside the hall's floor)
##   parlour_rooms / dining_rooms   ground rooms of kind parlour / dining_room
##   parlour_seating     seat + bench pieces in the first ground parlour ; parlour_settles
##                       (Bench) and parlour_chairs (Chair_1): a group is a settle with 2 chairs
##   dining_stools       Stool pieces at the table (chairs are counted by key, not category)
##   dining_tables / dining_chairs  table and seat pieces in the first ground dining room
##   rooms_distinct      hall, parlour and dining room are three different rooms
##   dining_table_elsewhere   a table stands in the hall or parlour as well
##   trim_count          cornice_* and string_course components
##   trim_worst          the largest distance (m) from any of them to the nearest
##                       floor line or the eave (see `trim_off_level`)
##   cornice_top_gap     m between the highest cornice part's top and the eave
static func _rich_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var door_room := plan.entrance_room()
	out["door_room_kind"] = plan.kind_of(door_room) if door_room >= 0 else &""
	var holds := false
	if door_room >= 0 and plan.kind_of(door_room) == &"hall":
		var hall_rect := HouseGeometry.room_floor_rect(plan, door_room)
		for s in plan.stairs:
			if int(s["a"]) != door_room or int(s["storey"]) != 0 or not bool(s.get("satisfied", true)):
				continue
			var foot := Rect2(s.get("foot_landing", Rect2()))
			if foot.has_area() and hall_rect.has_point(foot.get_center()):
				holds = true
	out["hall_holds_stair"] = holds
	var parlours: Array[int] = []
	var dinings: Array[int] = []
	for i in plan.rooms_on_storey(0):
		if plan.kind_of(i) == &"parlour":
			parlours.append(i)
		elif plan.kind_of(i) == &"dining_room":
			dinings.append(i)
	out["parlour_rooms"] = parlours.size()
	out["dining_rooms"] = dinings.size()
	out["parlour_seating"] = _count_cats(plan, parlours[0], ["seat", "bench"]) if not parlours.is_empty() else 0
	out["parlour_settles"] = _count_keys(plan, parlours[0], ["Bench"]) if not parlours.is_empty() else 0
	out["parlour_chairs"] = _count_keys(plan, parlours[0], ["Chair_1"]) if not parlours.is_empty() else 0
	out["dining_tables"] = _count_cats(plan, dinings[0], ["table"]) if not dinings.is_empty() else 0
	out["dining_chairs"] = _count_keys(plan, dinings[0], ["Chair_1"]) if not dinings.is_empty() else 0
	out["dining_stools"] = _count_keys(plan, dinings[0], ["Stool"]) if not dinings.is_empty() else 0
	out["rooms_distinct"] = door_room >= 0 and not parlours.is_empty() and not dinings.is_empty() 		and door_room != parlours[0] and door_room != dinings[0] and parlours[0] != dinings[0]
	var elsewhere := 0
	if door_room >= 0:
		elsewhere += _count_cats(plan, door_room, ["table"])
	if not parlours.is_empty():
		elsewhere += _count_cats(plan, parlours[0], ["table"])
	out["dining_table_elsewhere"] = elsewhere > 0
	out["component_log"] = builder.component_log
	out["storey_height"] = plan.spec.height
	var trim := trim_off_level(builder.component_log, plan.spec.height, plan.spec.storeys)
	out["trim_count"] = trim["count"]
	out["trim_worst"] = trim["worst"]
	out["cornice_top_gap"] = trim["cornice_top_gap"]


static func _count_keys(plan: HousePlan, room: int, keys: Array) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		if str(plan.furniture[f].get("key", "")) in keys:
			n += 1
	return n


static func _count_cats(plan: HousePlan, room: int, cats: Array) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		if str(plan.furniture[f].get("cat", "")) in cats:
			n += 1
	return n


## How far the ornament strays from the floor lines. A cornice or string-course
## part is a box; its distance to a level is zero when the level lies inside its
## height and the gap to its nearer face otherwise. The levels are the floors
## (0, h, 2h ...) and the eave (storeys * h). Returns {count, worst,
## cornice_top_gap} (the last: eave minus the highest cornice top, -INF when none).
static func trim_off_level(log: Array, height: float, storeys: int) -> Dictionary:
	var count := 0
	var worst := 0.0
	var top := -INF
	for c in log:
		var role := str(c.get("role", ""))
		if not (role.begins_with("cornice") or role == "string_course"):
			continue
		var xf: Transform3D = c["xf"]
		var size: Vector3 = c["size"]
		var lo := xf.origin.y - size.y * 0.5
		var hi := xf.origin.y + size.y * 0.5
		var nearest := INF
		for k in range(storeys + 1):
			var level := height * float(k)
			nearest = minf(nearest, 0.0 if lo <= level and level <= hi else minf(absf(lo - level), absf(hi - level)))
		worst = maxf(worst, nearest)
		count += 1
		if role.begins_with("cornice"):
			top = maxf(top, hi)
	return {"count": count, "worst": worst,
		"cornice_top_gap": height * float(storeys) - top if top > -INF else INF}


## HS-LONGHALL keys (a furnished plan is needed for the benches):
##   long_ratio          outer footprint, long side over short side
##   hall_fraction       the hall's share of the interior floor
##   hall_full_depth     the hall spans the whole interior depth ; hall_length (m)
##   main_roofs          masses named "roof" (one storey under ONE main roof: 1)
##   rooms_off_ends      rooms (not the hall) that overlap the hall's length
##   end_sides           how many of the two ends carry a private room (0..2)
##   private_kinds       kinds of the rooms at the ends
##   hearth_gap          least distance (m) from the fire's kerb to a hall wall
##   hearth_mid_offset   fire's offset from the hall's middle, share of its length
##   hearth_kerb_count   kerb stones emitted (4) ; hearth_wall_fire: a wall hearth exists
##   smoke_over_hearth   the roof opening's centre stands over the fire (<= 0.3 m)
##   smoke_hole          a roof opening called longhall_smoke_hole was cut
##   louvre_over_ridge   m the louvre's highest part stands over the ridge
##   ceiling_over_hall   a ceiling slab covers part of the hall floor
##   ceiling_over_ends   share of the end rooms' floor under a ceiling slab
##   truss_count         principal trusses (collars) in view ; rafter_count ; has_ridge_beam
##   bench_walls         how many long walls carry a bench (0..2)
##   bench_front_len / bench_back_len   metres of bench on each long wall
static func _longhall_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var r := HouseGeometry.site_rect(plan.spec)
	out["long_ratio"] = maxf(r.size.x, r.size.y) / minf(r.size.x, r.size.y)
	var hall_rooms := plan.rooms_of(&"hall")
	var hall_rect := Rect2()
	if not hall_rooms.is_empty():
		hall_rect = HouseGeometry.room_floor_rect(plan, hall_rooms[0])
	var inner := HouseGeometry.interior_rect(plan.spec)
	out["hall_fraction"] = hall_rect.get_area() / maxf(inner.get_area(), 0.01)
	out["hall_full_depth"] = absf(hall_rect.size.y - inner.size.y) < 0.05
	out["hall_length"] = hall_rect.size.x
	var main_roofs := 0
	for m in builder.mass_log:
		if str(m.get("name", "")) == "roof":
			main_roofs += 1
	out["main_roofs"] = main_roofs
	var off := 0
	var west := false
	var east := false
	var kinds: Array = []
	for i in range(plan.rooms.size()):
		if not hall_rooms.is_empty() and i == hall_rooms[0]:
			continue
		var rr: Rect2 = plan.rooms[i]["rect"]
		if rr.end.x <= hall_rect.position.x + 0.2:
			west = true
		elif rr.position.x >= hall_rect.end.x - 0.2:
			east = true
		else:
			off += 1
		kinds.append(str(plan.kind_of(i)))
	out["rooms_off_ends"] = off
	out["end_sides"] = int(west) + int(east)
	out["private_kinds"] = kinds
	# the fire
	var kerb_rect: Rect2 = plan.longhall.get("hearth", Rect2())
	out["hearth_gap"] = -INF
	out["hearth_mid_offset"] = INF
	if kerb_rect.has_area() and hall_rect.has_area():
		out["hearth_gap"] = minf(minf(kerb_rect.position.x - hall_rect.position.x,
			hall_rect.end.x - kerb_rect.end.x), minf(kerb_rect.position.y - hall_rect.position.y,
			hall_rect.end.y - kerb_rect.end.y))
		out["hearth_mid_offset"] = absf(kerb_rect.get_center().x - hall_rect.get_center().x) 			/ hall_rect.size.x
	var kerbs := 0
	var truss := 0
	var rafters := 0
	var ridge_beam := false
	var ceilings: Array[Rect2] = []
	var louvre_top := -INF
	for part in builder.component_log:
		var role := str(part.get("role", ""))
		match role:
			"hearth_kerb": kerbs += 1
			"hall_truss_collar": truss += 1
			"hall_rafter": rafters += 1
			"hall_ridge_beam": ridge_beam = true
			"ceiling":
				var xf: Transform3D = part["xf"]
				var a := HouseYard.part_aabb({"basis": xf.basis, "centre": xf.origin, "size": part["size"]})
				ceilings.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
			"louvre_hood", "louvre_post", "louvre_end":
				var xf2: Transform3D = part["xf"]
				var a2 := HouseYard.part_aabb({"basis": xf2.basis, "centre": xf2.origin, "size": part["size"]})
				louvre_top = maxf(louvre_top, a2.position.y + a2.size.y)
	out["hearth_kerb_count"] = kerbs
	out["hearth_wall_fire"] = plan.hearth_room() >= 0
	out["truss_count"] = truss
	out["rafter_count"] = rafters
	out["has_ridge_beam"] = ridge_beam
	var over_hall := false
	for c in ceilings:
		over_hall = over_hall or c.grow(-0.05).intersects(hall_rect)
	out["ceiling_over_hall"] = over_hall
	var covered := 0.0
	var ends_area := 0.0
	for i in range(plan.rooms.size()):
		if not hall_rooms.is_empty() and i == hall_rooms[0]:
			continue
		var fr := HouseGeometry.room_floor_rect(plan, i)
		ends_area += fr.get_area()
		for c in ceilings:
			covered += c.intersection(fr).get_area()
	out["ceiling_over_ends"] = covered / maxf(ends_area, 0.01)
	out["smoke_hole"] = false
	out["smoke_over_hearth"] = false
	for op in builder.roof_opening_log:
		if str(op["id"]) == "longhall_smoke_hole":
			out["smoke_hole"] = true
			var ctr: Vector3 = op["center"]
			out["smoke_over_hearth"] = kerb_rect.has_area() 				and Vector2(ctr.x, ctr.z).distance_to(kerb_rect.get_center()) <= 0.3
	out["louvre_over_ridge"] = louvre_top - (plan.spec.height * float(maxi(plan.spec.storeys, 1))
		+ HouseGeometry.roof_rise(plan.spec)) if louvre_top > -INF else -INF
	# the benches
	var front_len := 0.0
	var back_len := 0.0
	for f in plan.furniture:
		if str(f.get("key", "")) != "Bench" or hall_rooms.is_empty() or int(f.get("room", -1)) != hall_rooms[0]:
			continue
		var br: Rect2 = f["rect"]
		if absf(br.position.y - hall_rect.position.y) < 0.12:
			front_len += br.size.x
		elif absf(br.end.y - hall_rect.end.y) < 0.12:
			back_len += br.size.x
	out["bench_front_len"] = front_len
	out["bench_back_len"] = back_len
	out["bench_walls"] = int(front_len > 0.0) + int(back_len > 0.0)


## HS-FARMHOUSE keys: the yard door, the byre, and the working props.
static func _farm_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var e := plan.entrance()
	out["back_door_room"] = ""
	out["back_door_off_front"] = false
	for i in range(plan.doors.size()):
		var d: Dictionary = plan.doors[i]
		if i == e or not d.get("exterior", false) or bool(d.get("secret", false)):
			continue
		var kind := String(plan.rooms[int(d["a"])].get("kind", ""))
		if kind in ["kitchen", "store"]:
			out["back_door_room"] = kind
			var front_n := Vector2(plan.doors[e]["normal"]).normalized() if e >= 0 else Vector2.ZERO
			out["back_door_off_front"] = Vector2(d["normal"]).normalized().dot(front_n) < 0.5
			break
	var roofs := 0
	var top := -INF
	for part in builder.component_log:
		if str(part.get("role", "")) == "byre_roof":
			roofs += 1
			var xf: Transform3D = part["xf"]
			var a := HouseYard.part_aabb({"basis": xf.basis, "centre": xf.origin, "size": part["size"]})
			top = maxf(top, a.position.y + a.size.y)
	out["byre_roof_count"] = roofs
	out["byre_roof_top"] = top
	var r := HouseGeometry.site_rect(plan.spec).grow(0.3)
	var attached := false
	var kinds := {}
	for piece in plan.yard_pieces:
		match str(piece["kind"]):
			"byre":
				attached = attached or r.intersects(piece["rect"])
				for part in piece["parts"]:
					if str(part["role"]) == "hay_bale":
						kinds["hay"] = true
			"trough":
				kinds["trough"] = true
			"cart":
				kinds["cart"] = true
			"fence":
				kinds["fence"] = true
	for prop in plan.yard:
		if str(prop.get("role", "")) == "cart":
			kinds["cart"] = true
		if str(prop.get("key", "")) in ["Bag", "Sack"]:
			kinds["sacks"] = true
	for prop in plan.exterior:
		if str(prop.get("key", "")) in ["Bag", "Sack"]:
			kinds["sacks"] = true
	out["byre_attached"] = attached
	out["byre_lower_than_eave"] = roofs > 0 and top < float(out["eave_top"]) - 0.05
	var list: Array = kinds.keys()
	list.sort()
	out["yard_kinds"] = list


## Highest roof vertex that belongs to the main roof (the porch roof is lower
## by construction and never decides the ridge).
static func _ridge_top(mesh: ArrayMesh, plan: HousePlan) -> float:
	var top := -INF
	if mesh.get_surface_count() > HouseBuilder.SURF_ROOF:
		for v in mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]:
			top = maxf(top, v.y)
	return top


static func _on_hearth_wall(plan: HousePlan, stack: AABB) -> bool:
	var wall := plan.hearth_wall()
	if plan.hearth_room() < 0 or wall < 0:
		return false
	var r := HouseGeometry.site_rect(plan.spec)
	var c := Vector2(stack.position.x + stack.size.x / 2.0, stack.position.z + stack.size.z / 2.0)
	# The stack stands against the outside face of the hearth wall.
	match wall:
		0: return c.y < r.position.y + 0.05
		1: return c.y > r.end.y - 0.05
		2: return c.x < r.position.x + 0.05
		_: return c.x > r.end.x - 0.05


## Roof, both posts and the step exist, and the roof sits over the entrance.
static func _door_sheltered(plan: HousePlan, builder: HouseBuilder, roofs: int) -> bool:
	var d := plan.entrance()
	if d < 0 or roofs != 1:
		return false
	var names := {}
	for m in builder.mass_log:
		names[str(m.get("name", ""))] = m["aabb"]
	if not (names.has("porch_step") and names.has("porch_post_left") and names.has("porch_post_right")):
		return false
	var door: Dictionary = plan.doors[d]
	var p := Vector2(door["pos"])
	var step: AABB = names["porch_step"]
	var foot := Rect2(step.position.x, step.position.z, step.size.x, step.size.z).grow(0.05)
	return foot.has_point(p) or foot.has_point(p + Vector2(door["normal"]).normalized() * 0.6)
