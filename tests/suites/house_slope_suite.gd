extends RefCounted
## A building on falling ground (VTER-HOUSE-SLOPE): house, shop and church at
## falls 0, 1.0, 2.5 and 4.0 m, downhill sideways (toward +X) and front-to-back
## (toward the front, -Z, where the door is).
##
##   the request contract: flat is omitted from to_dict, a fall round-trips,
##     a 10 m fall is REFUSED with `ground_too_steep`, a castle refuses any fall
##   fall 0 is vertex-identical to a request that never heard of the field
##   below a storey of fall the flat building is all still there, triangle for
##     triangle: the slope only adds what stands under it
##   nothing is under the ground on the uphill side, and nothing anywhere is
##     buried deeper than a slab plus a metre of the slope's own fall
##   the downhill foundation (or terrace) reaches the ground: its lowest vertex
##     at the downhill edge is within 0.05 m of the ground line
##   component_check: every logged part is in the mesh
##   every exterior door is reachable: within a riser of the ground, or down
##     a flight whose risers, treads and foot GroundFall's rules accept, and
##     the walk export publishes that route; the plan's own nav check passes
##   more than a storey of fall gives the house a bank storey with its own
##     door on the downhill wall

const FALLS := [1.0, 2.5, 4.0]
const DIRECTIONS := {"sideways": 90.0, "front-to-back": 0.0}
const EDGE_TOL := 0.05


static func run() -> SuiteResult:
	var res := SuiteResult.new("hslope")
	_contract(res)
	for kind in [&"house", &"shop", &"church"]:
		_family(res, kind)
	_castle_note(res)
	return res


static func _request(kind: StringName) -> BuildingRequest:
	match kind:
		&"house":
			return BuildingRequest.house(8102, &"cottage", &"none", 8.0, 10.0, 2.6, 1)
		&"shop":
			return BuildingRequest.shop(4410, &"general_store", &"townhouse", 11.0, 14.0, 2.8, 1)
	return BuildingRequest.church(77, &"romanesque", 10.0, 20.0, 12.0)


# ------------------------------------------------------------- the contract

static func _contract(res: SuiteResult) -> void:
	var plain := _request(&"house")
	var zero := _request(&"house")
	zero.ground_fall_m = 0.0
	res.checked += 1
	if plain.to_json() != zero.to_json() or plain.to_json().contains("ground"):
		res.fail("contract: a flat request must serialise exactly as before, without ground fields")
	var sloped := _request(&"house")
	sloped.ground_fall_m = 2.5
	sloped.ground_downhill_deg = 90.0
	var back := BuildingRequest.from_json(sloped.to_json())
	res.checked += 1
	if not back._decode_errors.is_empty() or back.ground_fall_m != 2.5 \
			or back.ground_downhill_deg != 90.0 or back.to_json() != sloped.to_json():
		res.fail("contract: ground_fall_m / ground_downhill_deg do not round-trip")
	var copy := sloped.copy()
	res.checked += 1
	if copy.ground_fall_m != 2.5 or copy.ground_downhill_deg != 90.0:
		res.fail("contract: copy() drops the ground")
	# the failure control: 10 m is refused, with its reason
	for kind in [&"house", &"shop", &"church"]:
		var steep := _request(kind)
		steep.ground_fall_m = 10.0
		steep.ground_downhill_deg = 90.0
		var made := BrickWild.generate(steep)
		res.checked += 1
		if made.is_ok() or not _has_code(made.errors, &"ground_too_steep"):
			res.fail("contract: a 10 m fall under a %s must be refused with ground_too_steep, got %s"
				% [kind, made.errors])
		else:
			res.note("%s at 10 m refused: %s" % [kind, made.errors[0]["message"]])
	var castle := BuildingRequest.castle(5)
	castle.ground_fall_m = 1.0
	res.checked += 1
	if not _has_code(BuildingLibrary.validate(castle), &"unsupported_option"):
		res.fail("contract: a castle must refuse ground_fall_m (unsupported_option)")
	var negative := _request(&"house")
	negative.ground_fall_m = -1.0
	res.checked += 1
	if not _has_code(BuildingLibrary.validate(negative), &"invalid_ground"):
		res.fail("contract: a negative fall must be refused with invalid_ground")


static func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if StringName(e.get("code", "")) == code:
			return true
	return false


# -------------------------------------------------------------- the family

static func _family(res: SuiteResult, kind: StringName) -> void:
	var flat := _build(_request(kind))
	if flat.is_empty():
		res.fail("%s: flat request did not generate" % kind)
		return
	# fall 0 with a direction set is the flat building, vertex for vertex
	var zero_req := _request(kind)
	zero_req.ground_fall_m = 0.0
	zero_req.ground_downhill_deg = 90.0
	var zero := _build(zero_req)
	res.checked += 1
	if zero.is_empty() or not _same_mesh(flat["mesh"], zero["mesh"]):
		res.fail("%s: fall 0 is not vertex-identical to a request without the field" % kind)
	for dname in DIRECTIONS:
		for fall in FALLS:
			var req := _request(kind)
			req.ground_fall_m = fall
			req.ground_downhill_deg = DIRECTIONS[dname]
			var label := "%s %s %.1f m" % [kind, dname, fall]
			var t0 := Time.get_ticks_msec()
			var built := _build(req)
			res.checked += 1
			if built.is_empty():
				res.fail("%s: did not generate" % label)
				continue
			_case(res, label, kind, built, flat)
			res.note("%s: %d ms" % [label, Time.get_ticks_msec() - t0])


static func _build(req: BuildingRequest) -> Dictionary:
	var made := BrickWild.generate(req)
	if not made.is_ok():
		return {}
	if req.kind == &"church":
		var cb := ChurchBuilder.new()
		return {"building": made, "builder": cb, "mesh": cb.build(made.spec)}
	var hb := HouseBuilder.new()
	return {"building": made, "builder": hb, "mesh": hb.build(made.plan)}


static func _case(res: SuiteResult, label: String, kind: StringName,
		built: Dictionary, flat: Dictionary) -> void:
	var building: GeneratedBuilding = built["building"]
	var mesh: ArrayMesh = built["mesh"]
	var builder: MassBuilder = built["builder"]
	var spec: Object = building.spec
	var g := GroundFall.of_spec(spec)
	res.checked += 1
	if g == null:
		res.fail("%s: the spec did not receive the ground" % label)
		return
	var verts := _vertices(mesh)
	var bank := kind != &"church" and HouseSlope.band(spec) >= 3
	var storey_h: float = float(spec.get("height"))
	var foot: Rect2 = g.footprint
	# what the ground is met over: the footprint, or the church's terrace
	var meet: Rect2 = foot
	if kind == &"church":
		meet = (builder as ChurchBuilder).terrace_rect
		res.checked += 1
		if not meet.has_area():
			res.fail("%s: no terrace" % label)
			return

	# 1. the flat building is all still there below a storey of fall
	if not bank:
		res.checked += 1
		var missing := 0
		for s in mesh.get_surface_count():
			if s >= flat["mesh"].get_surface_count():
				break
			var want := ComponentCheck._triangle_vertices(flat["mesh"].surface_get_arrays(s))
			var have := ComponentCheck._triangle_vertices(mesh.surface_get_arrays(s))
			missing += ComponentCheck.missing_triangles(have, want)
		if missing > 0:
			res.fail("%s: %d triangles of the flat building are gone" % [label, missing])

	# 2. nothing under the ground uphill; nothing deeper than a slab and a
	#    metre of the slope anywhere (the bank storey excepted, dug on purpose)
	var tol: float = g.gradient() * 1.0 + 0.16
	var worst := 0.0
	var worst_at := Vector3.ZERO
	var uphill_worst := 0.0
	for v in verts:
		var p := Vector2(v.x, v.z)
		var gy := g.ground_y(p)
		if bank and foot.grow(0.7).has_point(p) and v.y >= -storey_h - 0.05:
			continue
		var under := gy - v.y
		if under > worst:
			worst = under
			worst_at = v
		if foot.has_point(p) and gy >= -0.05:
			uphill_worst = maxf(uphill_worst, under)
	res.checked += 2
	if worst > tol:
		res.fail("%s: geometry %.3f m under the ground at %s (allowed %.3f)" % [label, worst, worst_at, tol])
	if uphill_worst > 0.05:
		res.fail("%s: geometry %.3f m under the ground on the uphill side" % [label, uphill_worst])

	# 3. the downhill edge meets the ground
	var lowest_ground := INF
	for c in GroundFall.corners(meet):
		lowest_ground = minf(lowest_ground, g.ground_y(c))
	var low_y := INF
	var low_gap := INF
	for v in verts:
		var p := Vector2(v.x, v.z)
		if not meet.grow(0.1).has_point(p) or g.ground_y(p) > lowest_ground + 0.15:
			continue
		if v.y < low_y - 0.001:
			low_y = v.y
			low_gap = absf(v.y - g.ground_y(p))
		elif absf(v.y - low_y) <= 0.001:
			low_gap = minf(low_gap, absf(v.y - g.ground_y(p)))
	res.checked += 1
	if low_gap > EDGE_TOL:
		res.fail("%s: lowest vertex at the downhill edge is %.3f m from the ground (y %.3f)"
			% [label, low_gap, low_y])

	# 4. every logged part is in the mesh
	var comp := ComponentCheck.check(builder, mesh)
	res.checked += 1
	if not comp["ok"]:
		res.fail("%s: component_check: %s" % [label, comp["failures"]])
	var parts := builder.components("foundation_course").size() \
		+ builder.components("terrace_wall").size()
	res.checked += 1
	if parts == 0:
		res.fail("%s: no foundation or terrace courses were emitted" % label)

	# 5. every door reachable from the ground
	if kind == &"church":
		_church_doors(res, label, g, builder as ChurchBuilder, building)
	else:
		_house_doors(res, label, g, building, builder, bank)


static func _house_doors(res: SuiteResult, label: String, g: GroundFall,
		building: GeneratedBuilding, builder: MassBuilder, bank: bool) -> void:
	var plan: HousePlan = building.plan
	var spec: HouseSpec = plan.spec
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	res.checked += 1
	if not (nav["failures"] as Array).is_empty():
		res.fail("%s: nav: %s" % [label, nav["failures"]])
	var flights := {}
	for f in HouseSlope.flights(plan):
		flights[int(f["door"])] = f
	var walk: Dictionary = BrickWild.navigation(building)
	var routes := {}
	for d in walk.get("doors", []):
		if d.has("route_m"):
			routes[int(d["door"])] = d["route_m"]
	var wall_t := HouseGeometry.wall_thickness(spec)
	var undercroft := 0
	for i in plan.doors.size():
		var door: Dictionary = plan.doors[i]
		if not bool(door.get("exterior", false)) or bool(door.get("secret", false)):
			continue
		if bool(door.get("undercroft", false)):
			undercroft += 1
			res.checked += 1
			if HousePlan.record_storey(door) != -1 or Vector2(door["normal"]).dot(g.dir) < 0.3:
				res.fail("%s: the bank storey's door is not on the downhill wall of the lower storey" % label)
		var outer: Vector2 = Vector2(door["pos"]) + Vector2(door["normal"]) * wall_t
		var rise: float = HouseSlope.threshold_y(spec, door) - g.ground_y(outer)
		res.checked += 1
		if rise <= GroundFall.RISER + 0.02:
			continue
		if not flights.has(i):
			res.fail("%s: door %d is %.2f m above the ground with no way down" % [label, i, rise])
			continue
		var f: Dictionary = flights[i]
		var faults := HouseSlope.flight_faults(g, f)
		if not bool(f["feasible"]):
			faults.append("no clear direction for the flight")
		if not faults.is_empty():
			res.fail("%s: door %d flight: %s" % [label, i, ", ".join(faults)])
		var emitted := builder.components_of("entry_%d" % i).size()
		res.checked += 2
		if emitted < (f["steps"] as Array).size():
			res.fail("%s: door %d flight has %d steps but %d parts emitted"
				% [label, i, (f["steps"] as Array).size(), emitted])
		if not routes.has(i) or (routes[i] as Array).size() != (f["route"] as Array).size():
			res.fail("%s: door %d route is not in the walk export" % [label, i])
		if i == plan.entrance():
			res.note("%s: front door rise %.2f m, %d steps %s" % [label, rise,
				(f["steps"] as Array).size(), f["direction"]])
	if bank:
		res.checked += 2
		if spec.cellars < 1 or plan.rooms_on_storey(-1).is_empty():
			res.fail("%s: more than a storey of fall but no bank storey" % label)
		if undercroft != 1:
			res.fail("%s: the bank storey has %d doors of its own, want 1" % [label, undercroft])


static func _church_doors(res: SuiteResult, label: String, g: GroundFall,
		builder: ChurchBuilder, building: GeneratedBuilding) -> void:
	var f: Dictionary = builder.terrace_flight
	var rise: float = ChurchBuilder.TERRACE_TOP - g.ground_y(Vector2(0.0, builder.terrace_rect.position.y))
	res.checked += 1
	if rise <= GroundFall.RISER + 0.02:
		return
	if f.is_empty():
		res.fail("%s: the terrace is %.2f m above the ground at the west door with no steps" % [label, rise])
		return
	var faults := HouseSlope.flight_faults(g, f)
	if not bool(f["feasible"]):
		faults.append("no clear direction for the flight")
	if not faults.is_empty():
		res.fail("%s: west flight: %s" % [label, ", ".join(faults)])
	var walk: Dictionary = BrickWild.navigation(building)
	var routed := false
	for d in walk.get("doors", []):
		routed = routed or d.has("route_m")
	res.checked += 1
	if not routed:
		res.fail("%s: the west flight is not in the walk export" % label)
	res.note("%s: terrace rise %.2f m at the west front, %d steps %s" % [label, rise,
		(f["steps"] as Array).size(), f["direction"]])


# ------------------------------------------------------------------ castle

## Castles take no ground yet. Record how far a castle's own masonry reaches
## below its floor, which is how far a fall it could meet without floating.
static func _castle_note(res: SuiteResult) -> void:
	var made := BrickWild.generate(BuildingRequest.castle(5))
	if not made.is_ok():
		return
	var mesh := BrickWild.build_mesh(made)
	var low := INF
	for v in _vertices(mesh):
		low = minf(low, v.y)
	res.note("castle norman seed 5: lowest masonry at y = %.3f m; any fall beyond that leaves the downhill wall foot in the air" % low)


# ------------------------------------------------------------------ helpers

static func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out


static func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	for s in a.get_surface_count():
		var x: Array = a.surface_get_arrays(s)
		var y: Array = b.surface_get_arrays(s)
		if x[Mesh.ARRAY_VERTEX] != y[Mesh.ARRAY_VERTEX]:
			return false
		if x[Mesh.ARRAY_INDEX] != y[Mesh.ARRAY_INDEX]:
			return false
	return true
