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
static func measure(spec: HouseSpec, p_seed: int, tweak := Callable()) -> Dictionary:
	var plan := HouseGenerator.generate(spec, p_seed, false)
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
