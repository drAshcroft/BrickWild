class_name CastleQA
extends RefCounted
## Voxel-level quality harness for castles: the checks that measure the MESH
## rather than the mass log, so a builder that logs a wall it never emitted is
## caught rather than believed.
##
## Checks:
##   1. no_nan             all vertices finite and inside sane bounds
##   2. grounded           nothing hangs below y = 0
##   3. connected_mass     flood fill: every solid voxel reachable from the
##                         anchor mass -- or from a building standing on its
##                         own in the bailey -- so nothing floats detached
##   4. openings_embedded  painted slits have masonry behind them; planned
##                         window apertures have jambs, a head and a sill
##   5. enceinte_closed    the wall line is continuous the whole way round,
##                         except where the gate is meant to be
##   loops_reachable       every through-cut curtain loop has a floor and a
##                         clear body's height behind its skin (CastleLoopCheck)
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const EPS := 0.05
## How far off the wall centre-line a perimeter sample may find its masonry.
const WALL_PROBE := 1

## The rules, in order; a family may replace one through
## `check(spec, mesh, builder, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"no_nan", &"grounded", &"connected_mass",
	&"openings_embedded", &"enceinte_closed", &"interiors", &"occupied_shells", &"access_routes", &"lords_walk", &"gate_access",
	&"loops_reachable"]
const METHODS := {&"no_nan": "_check_vertices", &"grounded": "_check_ground",
	&"openings_embedded": "_check_openings", &"enceinte_closed": "_check_enceinte"}

var spec: CastleSpec
var mesh: ArrayMesh
var builder: CastleBuilder
var failures: Array = []
var warnings: Array = []
var stats: Dictionary = {}
var replaced: Dictionary = {}
var buildings: Dictionary = {}

var _grid: VoxelGrid


func check(p_spec: CastleSpec, p_mesh: ArrayMesh, p_builder: CastleBuilder,
		overrides: Dictionary = {}) -> Dictionary:
	spec = p_spec
	mesh = p_mesh
	builder = p_builder
	failures.clear()
	warnings.clear()
	stats.clear()
	buildings.clear()

	_grid = VoxelGrid.new()
	_grid.rasterize(mesh, [CastleBuilder.SURF_OPEN, CastleBuilder.SURF_WATER], _voxel_size())
	replaced = RuleSet.run(self, RULES, METHODS, overrides, [],
		[spec, mesh, builder], failures, warnings)

	stats["parts"] = builder.part_log.size()
	stats["voxels_solid"] = _grid.count_solid()
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced, "buildings": buildings}


func _check_interiors() -> void:
	for error in builder.interior_errors:
		failures.append("interiors: " + error)
	for row in builder.interiors:
		# The castle owns the joined roofs; the local HouseBuilder emits only
		# the occupied shell. Passing it would falsely demand a house roof.
		var report := HouseQA.new().check(row.plan, null)
		buildings[row.id] = report
		for failure in report.failures:
			failures.append("interiors[%s]: %s" % [row.id, failure])
		for warning in report.warnings:
			warnings.append("interiors[%s]: %s" % [row.id, warning])
	stats["interior_buildings"] = buildings.size()


func _check_lords_walk() -> void:
	var report := lords_walk(spec, builder, mesh)
	stats["lords_walk"] = report
	for failure in report.failures:
		failures.append("lords_walk: " + failure)


func _check_occupied_shells() -> void:
	var report := CastleOccupancyCheck.check(spec, builder, mesh)
	stats["occupied_shells"] = report.stats
	failures.append_array(report.failures)


## Every through-cut curtain loop has somewhere for its archer to stand.
func _check_loops_reachable() -> void:
	failures.append_array(CastleLoopCheck.check(spec, builder, mesh))


func _check_gate_access() -> void:
	var report := gate_access_report(spec, builder, mesh)
	failures.append_array(report.failures)


func _check_access_routes() -> void:
	var report := CastleRouteCheck.check(builder, mesh)
	stats["access_routes"] = {"routes": report.routes, "ok": report.ok,
		"wall_stairs": report.wall_stairs, "courtyard_routes": report.courtyard_routes}
	failures.append_array(report.failures)


static func gate_access_report(s: CastleSpec, b: CastleBuilder, actual: ArrayMesh) -> Dictionary:
	var out := {"failures": []}
	if not CastleGeometry.is_enclosed(s):
		return out
	var triangles: Array = []
	for surface in actual.get_surface_count():
		if surface != CastleBuilder.SURF_OPEN and surface != CastleBuilder.SURF_WATER:
			triangles.append_array(HouseQA._mesh_triangles(actual, surface))
	for ring in CastleGeometry.rings(s):
		var gate := CastleGeometry.gatehouse_aabb(s, ring)
		var half := minf(gate.size.x * 0.4, 4.0) * 0.5
		var slot_z := gate.position.z + gate.size.z * 0.3
		var count := 0
		for mass in b.mass_log:
			if String(mass.name).begins_with("portcullis_%d_" % ring):
				count += 1
		if count != 2:
			out.failures.append("gate_access: ring %d needs a logged portcullis guide pair" % ring)
		var ground: float = CastleGeometry.ring_ground_y(s, ring)
		for side in [-1.0, 1.0]:
			var start := Vector3(float(side) * (half - 0.15), ground + 1.0, slot_z)
			var slot := Vector3(float(side) * (half + 0.1), ground + 1.0, slot_z)
			var back := Vector3(float(side) * (half + 0.22), ground + 1.0, slot_z)
			if _access_ray_hits(triangles, start, slot) or not _access_ray_hits(triangles, start, back):
				out.failures.append("gate_access: ring %d has no open recessed groove with a solid guide" % ring)
			if not _access_ray_hits(triangles, start + Vector3.FORWARD * 0.3,
					slot + Vector3.FORWARD * 0.3):
				out.failures.append("gate_access: ring %d groove has no adjacent passage masonry" % ring)
	var bridge := CastleGeometry.drawbridge_aabb(s)
	if bridge.size.z > 0.0:
		if not b.mass_log.any(func(m): return m.name == "drawbridge"):
			out.failures.append("gate_access: ditch or moat gate has no logged drawbridge")
		var boards := maxi(2, int(ceil(bridge.size.z / 0.28)))
		for index in boards:
			var point := Vector3(0, bridge.end.y, bridge.position.z + (index + 0.5) * bridge.size.z / boards)
			if not _access_ray_hits(triangles, point + Vector3.UP * 0.04, point - Vector3.UP * 0.04):
				out.failures.append("gate_access: drawbridge is missing emitted walking deck")
		var from := Vector3(0, 1.0, bridge.position.z - 0.1)
		var to := Vector3(0, 1.0, bridge.end.z + 0.1)
		if _access_ray_hits(triangles, from, to):
			out.failures.append("gate_access: lowered drawbridge route is obstructed")
	if s.plan_kind == &"water":
		var road: AABB = CastleGeometry.causeway_aabb(s)
		var road_mass := b.mass_log.any(func(m): return m.name == "causeway")
		if road.size.z <= 0.0 or not road_mass:
			out.failures.append("gate_access: water plan has no logged causeway")
		else:
			var samples := maxi(2, int(ceil(road.size.z / 1.0)))
			for step in range(1, samples):
				var z: float = road.position.z + road.size.z * float(step) / float(samples)
				var above := Vector3(0, 0.45, z)
				var deck := Vector3(0, 0.20, z)
				if not _access_ray_hits(triangles, above, deck):
					out.failures.append("gate_access: causeway has a missing emitted tread at z=%.2f" % z)
					break
	return out


## Probe each emitted terrace tread vertically and keep a standing body clear
## from the outer gate approach to the raised inner gate. Also checks the
## terrace cap under the actual inner curtain footing, using emitted triangles.
static func terrace_route_report(s: CastleSpec, b: CastleBuilder,
		actual: ArrayMesh) -> Dictionary:
	var out := {"failures": [], "floor_samples": 0, "support_samples": 0}
	if s.plan_kind != &"terraced":
		return out
	var triangles: Array = []
	for surface in actual.get_surface_count():
		if surface != CastleBuilder.SURF_OPEN:
			triangles.append_array(HouseQA._mesh_triangles(actual, surface))
	var stair := b.mass_aabb("terrace_stair_1")
	var rise: float = CastleGeometry.ring_ground_y(s, 1)
	if stair.size.z <= 0.0:
		out.failures.append("terrace access: connecting stair mass is missing")
		return out
	var count := maxi(int(ceil(stair.size.z / 0.25)), 2)
	var previous_floor := -INF
	for i in range(count):
		var f: float = (float(i) + 0.5) / float(count)
		var z: float = stair.position.z + stair.size.z * f
		var expected: float = rise * f
		var floor_y: float = _walk_floor_y(triangles, Vector2(0.0, z),
			expected + 0.3, expected - 0.35)
		if floor_y == -INF:
			out.failures.append("terrace access: emitted stair floor is missing at z=%.2f" % z)
			continue
		out.floor_samples += 1
		if (i == 0 and floor_y > WalkGrid.MAX_STEP + 0.03) \
				or (i > 0 and (floor_y - previous_floor > WalkGrid.MAX_STEP + 0.03 \
					or floor_y < previous_floor - 0.03)):
			out.failures.append("terrace access: stair has a discontinuity at z=%.2f (floor %.2f after %.2f)" \
				% [z, floor_y, previous_floor])
		previous_floor = floor_y
		if i == count - 1 and rise - floor_y > WalkGrid.MAX_STEP + 0.03:
			out.failures.append("terrace access: last emitted tread misses raised landing")
		if _access_ray_hits(triangles, Vector3(0.0, floor_y + 0.08, z),
				Vector3(0.0, floor_y + 1.8, z)):
			out.failures.append("terrace access: emitted treads block body clearance at z=%.2f" % z)
	for seg in CastleGeometry.wall_segments(s, 1):
		var a: Vector2 = seg["a"]
		var c: Vector2 = seg["b"]
		var outward: Vector3 = seg["outward"]
		var midpoint: Vector2 = (a + c) * 0.5
		var inner_foot := Vector2(midpoint.x - outward.x
			* (CastleGeometry.wall_thickness(s, 1) + 0.1),
			midpoint.y - outward.z * (CastleGeometry.wall_thickness(s, 1) + 0.1))
		if _walk_floor_y(triangles, inner_foot, rise + 0.25, rise - 0.25) < rise - 0.02:
			out.failures.append("terrace support: cap misses inner curtain base at %s" % inner_foot)
		else:
			out.support_samples += 1
	return out


static func _walk_floor_y(triangles: Array, point: Vector2, top: float,
		bottom: float) -> float:
	var a := Vector3(point.x, top, point.y)
	var c := Vector3(point.x, bottom, point.y)
	var highest := -INF
	for tri in triangles:
		var hit: Variant = Geometry3D.segment_intersects_triangle(a, c,
			tri[0], tri[1], tri[2])
		if hit is Vector3:
			highest = maxf(highest, hit.y)
	return highest


## Start outside the outer gate (and barbican), traverse every ring and its
## causeway, then chain the keep's storeys through HouseNavCheck. Structural
## triangles at body height block the exterior grid: a painted doorway on a
## solid gatehouse cannot pass this check. There is no second pathfinder here.
static func lords_walk(s: CastleSpec, b: CastleBuilder, emitted: ArrayMesh = null) -> Dictionary:
	var out := {"failures": [], "applicable": false}
	var special_id := _special_interior_id(s, b)
	if not special_id.is_empty():
		return _lords_walk_special(s, b, emitted, special_id)
	var keep := {}
	for row in b.interiors:
		if row.id == "keep":
			keep = row
	if keep.is_empty() or not CastleGeometry.is_enclosed(s):
		return out
	out.applicable = true
	var p: HousePlan = keep.plan
	var entrance := p.entrance()
	if entrance < 0:
		out.failures.append("keep has no entrance")
		return out
	var d: Dictionary = p.doors[entrance]
	var expected_storey := 0 if s.terraced_fallback else 1
	if not bool(d.get("exterior", false)) \
			or HousePlan.record_storey(d) != expected_storey:
		out.failures.append("keep entrance is not at its protected expected storey")
		return out
	var xf: Transform3D = keep.transform
	# HousePlan records exterior doors on the inner wall face.
	var local := Vector2(d.pos) + Vector2(d.normal) * (HouseGeometry.wall_thickness(p.spec) + HouseGeometry.PERSON_RADIUS + 0.2)
	var point := xf * Vector3(local.x, 0, local.y)
	var gate := CastleGeometry.gatehouse_aabb(s, 0)
	if gate.size.x <= 0.0:
		out.failures.append("enclosed keep has no outer gate passage")
		return out
	var outer := CastleGeometry.enceinte_polygon(s, 0)
	var barbican := CastleGeometry.barbican_aabb(s)
	var front := minf(gate.position.z, barbican.position.z) if barbican.size.x > 0 else gate.position.z
	var approach := Rect2(-gate.size.x * 0.5, front - 2.0, gate.size.x, gate.position.z - front + 2.5)
	var bounds := CastleGeometry.polygon_bbox(outer).merge(approach).grow(1.0)
	var actual := emitted if emitted != null else b.commit()
	var access := {"failures": []} if s.terraced_fallback \
		else forebuilding_report(s, b, actual, keep)
	out["forebuilding"] = access
	out.failures.append_array(access.failures)
	var start := Vector2(0, front - 1.0)
	var goal := Vector2(point.x, point.z)
	var inside_local := Vector2(d.pos) - Vector2(d.normal) * (HouseGeometry.wall_thickness(p.spec) * 0.5 + HouseGeometry.PERSON_RADIUS + 0.2)
	var inside_world := xf * Vector3(inside_local.x, 0, inside_local.y)
	var inside_point := Vector2(inside_world.x, inside_world.z)
	var fore := CastleGeometry.forebuilding(s)
	if not fore.is_empty() and not s.terraced_fallback:
		# The ground grid reaches the toe. The emitted tread chain and raised
		# threshold are verified separately at their actual elevations.
		# Probe the compact Bergfried's open toe strip before the Palas wall
		# claims body clearance at the far edge of the same gap.
		var toe_offset := 0.25 if s.plan_kind == &"bergfried" else 0.8
		goal = Vector2(fore.front) + Vector2(fore.normal) * toe_offset
		inside_point = goal
	out["start"] = start
	out["keep_approach"] = goal
	out["door_inside"] = inside_point
	out["rings"] = CastleGeometry.rings(s).size()
	# Most castles deliberately keep a clear gate axis. A route found in this
	# subset also exists in the full site; a blocked subset proves nothing,
	# so failures always fall back to the entire bailey. Snap to the full
	# grid's cell origin so both passes rasterize the exact same world cells.
	var corridor := _walk_corridor(bounds, start, goal, inside_point)
	var scope := "full" if corridor.is_equal_approx(bounds) else "corridor"
	var trial := _walk_trial(corridor, outer, approach, actual, b.prop_log, start, goal, inside_point)
	var grid: WalkGrid = trial.grid
	trial.erase("grid")
	trial["scope"] = scope
	var trials: Array[Dictionary] = [trial]
	if not trial.ok and scope != "full":
		trial = _walk_trial(bounds, outer, approach, actual, b.prop_log, start, goal, inside_point)
		grid = trial.grid
		trial.erase("grid")
		trial["scope"] = "full"
		trials.append(trial)
	out["exterior_trials"] = trials
	out["exterior_grid"] = trial.scope
	out["exterior_ok"] = trial.ok
	out["obstacle_triangles"] = trial.obstacle_triangles
	out["obstacle_props"] = trial.obstacle_props
	if not trial.approach_reached:
		out.failures.append("gate approach %s cannot reach keep door approach %s" % [start, point])
		if grid.nx * grid.nz < 160000:
			out["exterior_map"] = grid.ascii_map({start: "G", goal: "K"})
	# An approach outside the wall is insufficient: the emitted doorway must
	# also let a body reach the same inside point used by HouseNavCheck.
	if not trial.threshold_reached:
		out.failures.append("emitted keep entrance is blocked at %s" % inside_world)
	var nav := HouseNavCheck.new()
	var inside := nav.check(p)
	var lords := p.rooms_of(&"lords_chamber")
	if lords.is_empty():
		out.failures.append("keep has no lord's chamber")
	for room in lords:
		if room in nav.unreached_rooms or not inside.ok:
			out.failures.append("keep entrance cannot reach/use lord's chamber %d: %s" % [room, inside.failures])
	return out


## Probe the emitted stair at body width, not just its bounding envelope.
## This catches an omitted tread, a filled stair hall, and a low roof while
## the plan and mass log can still look perfectly plausible.
static func forebuilding_report(s: CastleSpec, b: CastleBuilder, actual: ArrayMesh,
		keep: Dictionary) -> Dictionary:
	var out := {"failures": [], "treads": 0}
	var plan: HousePlan = keep.plan
	if plan.entrance() < 0:
		out.failures.append("forebuilding: keep has no door")
		return out
	var door: Dictionary = plan.doors[plan.entrance()]
	var door_report := _special_door_report("keep", keep, b, actual, plan, door)
	out.failures.append_array(door_report.failures)
	var triangles: Array = []
	for surface in actual.get_surface_count():
		if surface != CastleBuilder.SURF_OPEN:
			triangles.append_array(HouseQA._mesh_triangles(actual, surface))
	var previous := 0.0
	var last_box := AABB()
	var landed := false
	var fore := CastleGeometry.forebuilding(s)
	var normal: Vector2 = fore.normal
	var lateral := Vector3(-normal.y, 0.0, normal.x)
	var previous_point := Vector3(float(fore.front.x), 0.0, float(fore.front.y)) \
		+ Vector3(normal.x, 0.0, normal.y) * 0.4
	for row in b.component_log:
		if row.host != "forebuilding" or row.role not in ["forebuilding_tread", "forebuilding_landing"]:
			continue
		var box := MassBuilder.component_aabb(row)
		var centre := box.get_center()
		centre.y = box.end.y
		if row.role == "forebuilding_tread":
			out.treads += 1
			if box.end.y - previous > 0.201 or box.end.y <= previous:
				out.failures.append("forebuilding: missing or unwalkable riser")
			previous = box.end.y
		else:
			landed = absf(box.end.y - previous) < 0.01
		if last_box.size.x > 0 and not last_box.grow(0.005).intersects(box):
			out.failures.append("forebuilding: disconnected tread or landing")
		last_box = box
		for offset in [-0.4, 0.0, 0.4]:
			var point := centre + lateral * float(offset)
			var from := Vector3(previous_point.x, point.y + 0.9, previous_point.z) \
				+ lateral * float(offset)
			if _access_ray_hits(triangles, from, point + Vector3.UP * 0.9):
				out.failures.append("forebuilding: approach blocked between treads at %s" % point)
			if not _access_ray_hits(triangles, point + Vector3.UP * 0.04, point - Vector3.UP * 0.04):
				out.failures.append("forebuilding: emitted stair floor missing at %s" % point)
			if _access_ray_hits(triangles, point + Vector3.UP * 0.05, point + Vector3.UP * 1.95):
				out.failures.append("forebuilding: headroom blocked at %s" % point)
		previous_point = centre
	if out.treads < 2 or not landed or absf(previous - plan.spec.height - HouseGeometry.FLOOR_T) > 0.01:
		out.failures.append("forebuilding: no continuous stair to first-floor landing")
	return out


static func _access_ray_hits(triangles: Array, a: Vector3, z: Vector3) -> bool:
	for tri in triangles:
		if Geometry3D.segment_intersects_triangle(a, z, tri[0], tri[1], tri[2]) != null:
			return true
	return false


## Tower houses and occupied motte shell-keeps do not have the enclosed keep's
## gate/causeway route.  Their entrances are still a physical contract: the
## authored door must survive the local-to-world transform, a named chain of
## approach steps must reach its threshold, and every occupied storey must be
## usable.  Keep this dispatch here rather than weakening HousePlanCheck for
## ordinary houses; these are castle-family exceptions with stable ids.
static func _special_interior_id(s: CastleSpec, b: CastleBuilder) -> String:
	var wanted := "tower_house" if CastleGeometry.is_tower_house(s) else ("keep_shell" if CastleGeometry.is_motte(s) else "")
	if wanted.is_empty():
		return ""
	return wanted


static func _lords_walk_special(s: CastleSpec, b: CastleBuilder,
		emitted: ArrayMesh, building_id: String) -> Dictionary:
	var out := {"failures": [], "applicable": true, "building_id": building_id}
	var row := {}
	for candidate in b.interiors:
		if String(candidate.get("id", "")) == building_id:
			row = candidate
			break
	if row.is_empty():
		out.failures.append("%s: missing interior record" % building_id)
		return out
	var plan: HousePlan = row.get("plan")
	if plan == null or plan.spec == null:
		out.failures.append("%s: missing occupied HousePlan" % building_id)
		return out
	var entrance := plan.entrance()
	if entrance < 0:
		out.failures.append("%s: no exterior entrance" % building_id)
		return out
	var door: Dictionary = plan.doors[entrance]
	var actual := emitted if emitted != null else b.commit()
	var door_report := _special_door_report(building_id, row, b, actual, plan, door)
	for failure in door_report.failures:
		out.failures.append(failure)
	out["door"] = door_report
	var route := _special_approach_report(building_id, b, row, door, actual)
	for failure in route.failures:
		out.failures.append(failure)
	out["approach"] = route
	var stairs := _special_stair_report(building_id, plan, actual, row)
	for failure in stairs.failures:
		out.failures.append(failure)
	out["stairs"] = stairs
	var nav := HouseNavCheck.new().check(plan)
	out["house_nav"] = nav
	if not bool(nav.get("ok", false)):
		for failure in nav.failures:
			out.failures.append("%s: HouseNavCheck: %s" % [building_id, failure])
	return out


static func _special_door_report(building_id: String, row: Dictionary,
		b: CastleBuilder, actual: ArrayMesh, plan: HousePlan, door: Dictionary) -> Dictionary:
	var out := {"failures": [], "matched": false, "clear": false}
	if not bool(door.get("exterior", false)):
		out.failures.append("%s: entrance is not exterior" % building_id)
		return out
	var level := HousePlan.record_storey(door)
	if level < 0 or level >= plan.spec.storeys:
		out.failures.append("%s: entrance storey %d is outside the occupied shaft" % [building_id, level])
		return out
	var sill := float(door.get("sill", 0.0))
	var head := float(door.get("head", HouseGeometry.DOOR_H))
	if head <= sill or sill < -0.001 or head > plan.spec.height + 0.001:
		out.failures.append("%s: authored door vertical interval is invalid (%.2f..%.2f)" % [building_id, sill, head])
		return out
	var local_y := float(level) * plan.spec.height + (sill + head) * 0.5
	var xf: Transform3D = row.transform
	var door_position: Vector2 = door["pos"]
	var door_normal: Vector2 = door["normal"]
	var room_thickness := HouseGeometry.wall_thickness(plan.spec)
	if level >= 0 and level < plan.rooms.size():
		room_thickness = float(plan.rooms[level].get("wall_thickness", room_thickness))
	var wall_offset := door_normal * room_thickness * 0.5
	var expected_local := door_position + wall_offset
	var expected := xf * Vector3(expected_local.x, local_y, expected_local.y)
	var expected_facing := (xf.basis * Vector3(door_normal.x, 0.0, door_normal.y)).normalized()
	if not _door_on_plan_surface(plan, level, door_position, door_normal):
		out.failures.append("%s: authored entrance is off its room-wall surface" % building_id)
	var matched_part := {}
	for part in b.part_log:
		if String(part.get("tag", "")) != building_id:
			continue
		if String(part.get("opening_kind", "")) != "door":
			continue
		if not Vector3(part.get("pos", Vector3.ZERO)).is_equal_approx(expected):
			continue
		if not Vector3(part.get("facing", Vector3.ZERO)).is_equal_approx(expected_facing):
			continue
		var size: Vector3 = part.get("size", Vector3.ZERO)
		if not is_equal_approx(size.x, float(door.width)) or not is_equal_approx(size.y, head - sill):
			continue
		matched_part = part
		break
	if matched_part.is_empty():
		out.failures.append("%s: emitted doorway does not match authored world pose/height/surface" % building_id)
	else:
		out.matched = true
	var clear := _door_ray_clear(actual, expected, expected_facing, room_thickness)
	out.clear = clear
	if not clear:
		out.failures.append("%s: emitted doorway is filled at its authored height" % building_id)
	return out


static func _door_on_plan_surface(plan: HousePlan, level: int, point: Vector2,
		normal: Vector2) -> bool:
	var walls := HouseGeometry.room_walls(plan, level)
	if walls.is_empty():
		return false
	for wall in walls:
		var a: Vector2 = wall["from"]
		var z: Vector2 = wall["to"]
		var edge := z - a
		var t := clampf((point - a).dot(edge) / maxf(edge.length_squared(), 0.0001), 0.0, 1.0)
		var nearest := a + edge * t
		var wall_normal := -Vector2(wall["normal"])
		if nearest.distance_to(point) <= 0.18 and wall_normal.dot(normal.normalized()) >= 0.92:
			return true
	return false


static func _door_ray_clear(actual: ArrayMesh, point: Vector3, facing: Vector3,
		wall_thickness: float) -> bool:
	var reach := maxf(wall_thickness + HouseGeometry.PERSON_RADIUS + 0.3, 1.0)
	var a := point - facing * reach
	var z := point + facing * reach
	for surface in actual.get_surface_count():
		var arrays := actual.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count - 2, 3):
			var p0 := vertices[indices[i] if not indices.is_empty() else i]
			var p1 := vertices[indices[i + 1] if not indices.is_empty() else i + 1]
			var p2 := vertices[indices[i + 2] if not indices.is_empty() else i + 2]
			if Geometry3D.segment_intersects_triangle(a, z, p0, p1, p2) != null:
				return false
	return true


static func _special_approach_report(building_id: String, b: CastleBuilder,
		row: Dictionary, door: Dictionary, actual: ArrayMesh = null) -> Dictionary:
	var out := {"failures": [], "steps": 0, "contiguous": false, "monotonic": false}
	var kind := "tower_approach_step" if building_id == "tower_house" else "motte_approach_step"
	var steps: Array[Dictionary] = []
	for part in b.part_log:
		if String(part.get("kind", "")) == kind:
			steps.append(part)
	out.steps = steps.size()
	if steps.is_empty():
		out.failures.append("%s: no %s chain emitted" % [building_id, kind])
		return out
	var xf: Transform3D = row.transform
	var door_world := xf * Vector3(float(door.pos.x), 0.0, float(door.pos.y))
	var previous := INF
	var previous_top := 0.0
	var contiguous := true
	var monotonic := true
	var walkable_risers := true
	for i in range(steps.size()):
		var centre: Vector3 = steps[i].get("pos", Vector3.ZERO)
		var size: Vector3 = steps[i].get("size", Vector3.ZERO)
		var top := centre.y + size.y * 0.5
		# A landing can be level; steps must not descend or exceed a usable rise.
		if size.y <= 0.0 or top < previous_top - 0.001 or top - previous_top > 0.30 + 0.001:
			walkable_risers = false
		previous_top = top
		var distance := Vector2(centre.x, centre.z).distance_to(Vector2(door_world.x, door_world.z))
		if distance >= previous - 0.001:
			monotonic = false
		previous = distance
		if i > 0:
			var prior: Vector3 = steps[i - 1].get("pos", Vector3.ZERO)
			var a: Vector2 = Vector2(prior.x, prior.z)
			var c: Vector2 = Vector2(centre.x, centre.z)
			var pa: Vector3 = steps[i - 1].get("size", Vector3.ZERO)
			var pc: Vector3 = steps[i].get("size", Vector3.ZERO)
			var reach := Vector2(pa.x, pa.z).length() * 0.5 + Vector2(pc.x, pc.z).length() * 0.5 + HouseGeometry.NAV_CELL
			if a.distance_to(c) > reach:
				contiguous = false
	var last: Vector3 = steps[steps.size() - 1].get("pos", Vector3.ZERO)
	var last_size: Vector3 = steps[steps.size() - 1].get("size", Vector3.ZERO)
	if Vector2(last.x, last.z).distance_to(Vector2(door_world.x, door_world.z)) > Vector2(last_size.x, last_size.z).length() * 0.5 + 1.0:
		contiguous = false
	out.contiguous = contiguous
	out.monotonic = monotonic
	out.walkable_risers = walkable_risers
	if not contiguous:
		out.failures.append("%s: %s chain is not contiguous to the door threshold" % [building_id, kind])
	if not monotonic:
		out.failures.append("%s: %s chain is not monotonic toward the door" % [building_id, kind])
	if not walkable_risers:
		out.failures.append("%s: %s chain has a missing or non-walkable riser" % [building_id, kind])
	var physical := _approach_mesh_report(steps, actual if actual != null else b.commit(),
		minf(float(door.width) - 0.12, HouseGeometry.PATH_MIN))
	out["mesh"] = physical
	for failure in physical.failures:
		out.failures.append("%s: %s" % [building_id, failure])
	return out


## Step records locate the probes; only the final mesh can prove that the
## treads exist and the body corridor is free of other castle masonry.
static func _approach_mesh_report(steps: Array[Dictionary], actual: ArrayMesh,
		clear_width: float) -> Dictionary:
	var out := {"failures": [], "treads_checked": 0}
	var triangles: Array = []
	for surface in actual.get_surface_count():
		if surface not in [CastleBuilder.SURF_OPEN, CastleBuilder.SURF_WATER]:
			triangles.append_array(HouseQA._mesh_triangles(actual, surface))
	var previous := Vector3.ZERO
	for i in steps.size():
		var step: Dictionary = steps[i]
		var size: Vector3 = step.size
		var top: Vector3 = step.pos + Vector3.UP * size.y * 0.5
		var yaw := float(step.get("rot_y", 0.0))
		var lateral := Vector3(cos(yaw), 0.0, -sin(yaw))
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		if i == 0:
			previous = top - direction * (size.z * 0.5 + 0.12)
			previous.y = 0.0
		var radius := minf(clear_width, size.x - 0.12) * 0.5
		var region := AABB(top, Vector3.ZERO).expand(previous).grow(2.1)
		var nearby: Array = []
		for tri in triangles:
			var bounds := AABB(tri[0], Vector3.ZERO).expand(tri[1]).expand(tri[2])
			if region.intersects(bounds.grow(0.001)):
				nearby.append(tri)
		var floor_missing := false
		var obstructed := false
		for offset in [-radius, 0.0, radius]:
			var point := top + lateral * float(offset)
			# A broad downward ray can mistake the mound beneath an omitted
			# tread for the tread itself. Measure the named top to 4 mm.
			if not _access_ray_hits(nearby, point + Vector3.UP * 0.004,
					point - Vector3.UP * 0.004):
				floor_missing = true
			if _access_ray_hits(nearby, point + Vector3.UP * 0.05,
					point + Vector3.UP * 1.95):
				obstructed = true
			for height in [0.12, 0.9, 1.9]:
				var end := point + Vector3.UP * float(height)
				var start := Vector3(previous.x, end.y, previous.z) + lateral * float(offset)
				if _access_ray_hits(nearby, start, end):
					obstructed = true
		if floor_missing:
			out.failures.append("approach mesh: tread %d has no emitted walking surface" % i)
		if obstructed:
			out.failures.append("approach mesh: tread %d has blocked body clearance or headroom" % i)
		out.treads_checked += 1
		previous = top
	return out


static func _special_stair_report(building_id: String, plan: HousePlan,
		actual: ArrayMesh, row: Dictionary) -> Dictionary:
	var out := {"failures": [], "expected": maxi(plan.spec.storeys - 1, 0), "actual": plan.stairs.size()}
	var expected := int(out.expected)
	if plan.stairs.size() != expected:
		out.failures.append("%s: missing upper stair (expected %d, got %d)" % [building_id, expected, plan.stairs.size()])
	for stair in plan.stairs:
		var lower := int(stair.get("storey", stair.get("a", 0)))
		var upper := int(stair.get("to_storey", stair.get("b", lower + 1)))
		if upper != lower + 1:
			out.failures.append("%s: upper stair transition %d -> %d is invalid" % [building_id, lower, upper])
			continue
		if bool(stair.get("filled", false)) or bool(stair.get("blocked", false)):
			out.failures.append("%s: upper stair %d -> %d is filled" % [building_id, lower, upper])
		for key in ["lower_rect", "upper_rect"]:
			var rect := Rect2(stair.get(key, stair.get("rect", Rect2())))
			if not rect.has_area() or lower < 0 or upper >= plan.rooms.size():
				out.failures.append("%s: upper stair %d -> %d has an invalid %s landing" % [building_id, lower, upper, key])
				continue
			var room_index := lower if key == "lower_rect" else upper
			if not Poly.contains_point(plan.outline_of(room_index), rect.position, 0.001) \
				or not Poly.contains_point(plan.outline_of(room_index), rect.end, 0.001):
				out.failures.append("%s: upper stair %d -> %d %s landing is outside its floor" % [building_id, lower, upper, key])
		if upper >= 0 and upper < plan.spec.storeys:
			var upper_rect := Rect2(stair.get("upper_rect", stair.get("rect", Rect2())))
			if upper_rect.has_area():
				if not _stair_landing_clear(actual, upper_rect, row.transform,
					float(upper) * plan.spec.height):
					out.failures.append("%s: upper stair %d -> %d opening is filled" % [building_id, lower, upper])
	return out


static func _stair_landing_clear(actual: ArrayMesh, rect: Rect2,
		xf: Transform3D, y: float) -> bool:
	# A stair flight deliberately occupies part of its upper opening. Probe a
	# small interior lattice rather than the centreline, which commonly lands on
	# the final tread. A real opening needs at least one clear point; a filled
	# landing volume blocks every point.
	for u in [0.2, 0.5, 0.8]:
		for v in [0.2, 0.5, 0.8]:
			var local := rect.position + rect.size * Vector2(float(u), float(v))
			var world: Vector3 = xf * Vector3(local.x, y, local.y)
			if _vertical_probe_clear(actual, world):
				return true
	return false


static func _vertical_probe_clear(actual: ArrayMesh, centre: Vector3) -> bool:
	# Probe just ABOVE the upper floor plane and through the first-riser band.
	# The final tread reaches the plane itself, so a symmetric ray falsely
	# treats an intended stair as filled; the next flight must nevertheless not
	# occupy the same opening, or it seals this landing on the way up.
	var a := centre + Vector3.UP * 0.12
	var z := centre + Vector3.UP * 0.95
	for surface in actual.get_surface_count():
		var arrays := actual.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count - 2, 3):
			var p0 := vertices[indices[i] if not indices.is_empty() else i]
			var p1 := vertices[indices[i + 1] if not indices.is_empty() else i + 1]
			var p2 := vertices[indices[i + 2] if not indices.is_empty() else i + 2]
			if Geometry3D.segment_intersects_triangle(a, z, p0, p1, p2) != null:
				return false
	return true


static func _walk_corridor(full: Rect2, start: Vector2, goal: Vector2, inside: Vector2) -> Rect2:
	var wanted := Rect2(start, Vector2.ZERO).expand(goal).expand(inside).grow(2.0).intersection(full)
	var cell := HouseGeometry.NAV_CELL
	var first := ((wanted.position - full.position) / cell).floor()
	var last := ((wanted.end - full.position) / cell).ceil()
	return Rect2(full.position + first * cell, (last - first) * cell).intersection(full)


static func _walk_trial(bounds: Rect2, outer: PackedVector2Array, approach: Rect2,
		mesh: ArrayMesh, props: Array[Dictionary], start: Vector2, goal: Vector2, inside: Vector2) -> Dictionary:
	var grid := WalkGrid.new()
	grid.setup(bounds, HouseGeometry.NAV_CELL)
	grid.add_floor_poly(outer)
	grid.add_floor(approach)
	var triangles := _walk_obstacles(grid, mesh)
	var prop_count := _walk_props(grid, props)
	grid.build(HouseGeometry.PERSON_RADIUS)
	# Limit the shared walker's start search to one cell, so it cannot hop
	# across a thin blocker at the gate approach.
	var started := grid.flood_from(start, grid.cell)
	var goal_probe := Rect2(goal - Vector2.ONE * grid.cell, Vector2.ONE * grid.cell * 2.0)
	var approach_reached := started and grid.reached(goal_probe)
	var threshold_reached := true
	var samples: Array[Dictionary] = []
	var steps := maxi(int(ceil(goal.distance_to(inside) / grid.cell)), 1)
	for step in range(steps + 1):
		var point := goal.lerp(inside, float(step) / float(steps))
		var probe := Rect2(point - Vector2.ONE * grid.cell * 0.5, Vector2.ONE * grid.cell)
		var reached := started and grid.reached(probe)
		samples.append({"point": point, "probe": probe, "reached": reached})
		threshold_reached = threshold_reached and reached
	return {"grid": grid, "bounds": bounds, "cell": grid.cell,
		"grid_cells": grid.nx * grid.nz, "start": start, "start_cell": grid.cell_of(start),
		"start_search": grid.cell, "started": started, "approach_probe": goal_probe,
		"approach_reached": approach_reached, "threshold_samples": samples,
		"threshold_reached": threshold_reached, "reached_cells": grid.reached_cells(),
		"obstacle_triangles": triangles, "obstacle_props": prop_count,
		"ok": approach_reached and threshold_reached}


## Project the actual solid surfaces onto the walk grid over standing body
## height. Clip before projecting: a roof well overhead must not become a
## ground obstacle. Low thresholds below WalkGrid.MAX_STEP remain walkable.
static func _walk_obstacles(grid: WalkGrid, actual: ArrayMesh) -> int:
	var count := 0
	for surface in actual.get_surface_count():
		if surface in [CastleBuilder.SURF_OPEN, CastleBuilder.SURF_WATER]:
			continue
		var arrays := actual.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var size := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, size - 2, 3):
			var tri := PackedVector3Array()
			for j in 3:
				tri.append(vertices[indices[i + j] if not indices.is_empty() else i + j])
			tri = _clip_walk_height(tri, WalkGrid.MAX_STEP + 0.01, true)
			tri = _clip_walk_height(tri, 1.8, false)
			if tri.size() < 3:
				continue
			var points := PackedVector2Array()
			# A vertical triangle projects to a line. Give it one cell's raster
			# coverage so a zero-thickness sealed face still blocks a person.
			var pad := grid.cell * 0.5
			for vertex in tri:
				for dx in [-pad, pad]:
					for dz in [-pad, pad]:
						points.append(Vector2(vertex.x + dx, vertex.z + dz))
			var hull := Geometry2D.convex_hull(points)
			# Geometry2D closes its hull by repeating the first vertex. Normalize
			# that convention before handing it to the shared polygon routines,
			# so every boundary edge has a real geometric length.
			if hull.size() > 1 and hull[0].distance_squared_to(hull[hull.size() - 1]) < 1e-10:
				hull.resize(hull.size() - 1)
			grid.add_obstacle_poly(hull)
			count += 1
	return count


## The assembler loads these separately from the shell, so they have no
## triangles in `mesh`. Recompute measured footprints from the actual pose;
## a stale authored rect must not hide a cart moved across the entrance.
static func _walk_props(grid: WalkGrid, placements: Array[Dictionary]) -> int:
	var count := 0
	for prop in placements:
		var key := String(prop.key)
		if not PropCatalog.blocks_floor(key):
			continue
		var scale := float(prop.scale)
		var size := PropCatalog.size(key) * scale
		var centre := Vector3(prop.pos) + PropCatalog.centre_offset(key) * scale
		if centre.y + size.y * 0.5 <= WalkGrid.MAX_STEP or centre.y - size.y * 0.5 >= 1.8:
			continue
		var span := PropCatalog.footprint_rotated(key, float(prop.yaw)) * scale
		var plan_centre := PropCatalog.plan_centre(key, Vector3(prop.pos), float(prop.yaw), scale)
		grid.add_obstacle(Rect2(plan_centre - span * 0.5, span))
		count += 1
	return count


static func _clip_walk_height(poly: PackedVector3Array, height: float, above: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	if poly.is_empty():
		return out
	var prev := poly[poly.size() - 1]
	var prev_inside := prev.y >= height if above else prev.y <= height
	for cur in poly:
		var cur_inside := cur.y >= height if above else cur.y <= height
		if cur_inside != prev_inside:
			out.append(prev.lerp(cur, (height - prev.y) / (cur.y - prev.y)))
		if cur_inside:
			out.append(cur)
		prev = cur
		prev_inside = cur_inside
	return out


## Voxel size for this design: coarse enough that a 300 m fortress rasterizes
## into about the same number of cells as a cottage, fine enough to still fall
## inside the thinnest wall the design has.
func _voxel_size() -> float:
	var span: float = maxf(spec.width, spec.length)
	var thinnest: float = spec.wall_thickness if CastleGeometry.is_enclosed(spec) 		else CastleGeometry.CHIMNEY_W
	return clampf(span / 90.0, VoxelGrid.VOX, maxf(thinnest * 0.8, VoxelGrid.VOX))


func _check_vertices() -> void:
	var total := 0
	var limit: float = maxf(spec.width, spec.length) * 3.0 + 200.0
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		total += verts.size()
		for v in verts:
			if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)):
				failures.append("no_nan: NaN/Inf vertex on surface %d" % s)
				return
			if absf(v.x) > limit or absf(v.z) > limit or v.y > limit:
				warnings.append("no_nan: vertex far outside expected bounds (%s)" % v)
				return
	if total < 100:
		failures.append("no_nan: only %d vertices" % total)


func _check_ground() -> void:
	var mn := INF
	for s in range(mesh.get_surface_count()):
		for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			mn = minf(mn, v.y)
	if CastleGeometry.is_sky(spec):
		if mn < -EPS or mn > 0.5:
			failures.append("grounded: sky rock point is at %.2fm, wants world y=0" % mn)
	elif mn < -0.5:
		failures.append("grounded: geometry dips %.2fm below ground" % (-mn))
	elif mn < -EPS:
		warnings.append("grounded: eaves/trim dips %.2fm below ground" % (-mn))


## Flood fill from inside the anchor mass. Any solid voxel it cannot reach is a
## detached part -- a tower standing off its wall, a range in mid-air.
func _check_connected_mass() -> void:
	var anchor: AABB = builder.mass_aabb(_anchor_name())
	if anchor.size.y <= 0.0:
		failures.append("connected_mass: no %s mass to seed from" % _anchor_name())
		return
	var seed := _seed_inside(anchor)
	if seed.x < 0:
		failures.append("connected_mass: no solid voxel found inside the %s"
			% _anchor_name())
		return
	var visited: Dictionary = _grid.flood_from(seed)
	# A building standing on its own in the courtyard is its OWN grounded
	# component. A stable is not attached to the curtain and is not meant to
	# be (CAS-012), so the flood is seeded from each of those as well. The rule
	# keeps its teeth either way: geometry attached to nothing at all is still
	# unreachable from every seed, and `grounded` is what says a free-standing
	# building has to stand on the ground.
	var independent := {}
	for row in builder.interiors:
		independent[row.id] = true
	for m in builder.mass_log:
		var nm: String = m["name"]
		if not (nm.begins_with("yard_") or nm.begins_with("yardwork_") or nm.begins_with("revetment_") or nm == "well" or independent.has(nm)):
			continue
		var box: AABB = m["aabb"]
		# An independently seeded house must have real masonry at its foot.
		# Looking in the middle of a hollow shell misses its walls, while
		# accepting a roof high above its logged base would bless a floater.
		var foot := AABB(box.position, Vector3(box.size.x, minf(box.size.y, _grid.vox * 1.5), box.size.z))
		var extra: Vector3i = _seed_inside(foot)
		if extra.x < 0:
			continue
		# Ranges usually already touch the curtain's component. Re-flooding
		# that same component for each range adds no newly reachable voxels.
		if visited.has(extra):
			continue
		for k in _grid.flood_from(extra):
			visited[k] = true
	var total: int = _grid.count_solid()
	stats["reachable_fraction"] = snappedf(float(visited.size()) / maxf(total, 1), 0.001)
	if visited.size() < total - 8:
		var example: Vector3i = _grid.first_unvisited(visited)
		failures.append("connected_mass: %d/%d solid voxels unreachable from the %s (orphan near %s)"
			% [total - visited.size(), total, _anchor_name(),
				str(_grid.world_of(example.x, example.y, example.z))])


## A solid voxel somewhere inside `box`, or (-1, -1, -1) when it holds none.
func _seed_inside(box: AABB) -> Vector3i:
	# Visit raster cells, including the shell boundary. A fixed handful of
	# points through a now-hollow volume may all fall in perfectly legal air.
	for y in range(_grid.vy(box.position.y), _grid.vy(box.end.y) + 1):
		for x in range(_grid.vx(box.position.x), _grid.vx(box.end.x) + 1):
			for z in range(_grid.vz(box.position.z), _grid.vz(box.end.z) + 1):
				if _grid.get_voxel(x, y, z):
					return Vector3i(x, y, z)
	return Vector3i(-1, -1, -1)


## Legacy slits are recesses over solid masonry. Through slits and HousePlan
## windows are apertures: measure their masonry returns instead of demanding
## stone through the opening. The fine shell tests separately measure clearance.
func _check_openings() -> void:
	var checked := 0
	for p in builder.part_log:
		if p["kind"] != "window":
			continue
		checked += 1
		var pos: Vector3 = p["pos"]
		var tag: String = p["tag"]
		if bool(p.get("planned_opening", false)) or bool(p.get("through_opening", false)):
			_check_aperture_surround(p)
			continue
		var cell := (pos - _grid.origin) / _grid.vox
		var gi := Vector3i(floori(cell.x), floori(cell.y), floori(cell.z))
		if not _grid.get_voxel(gi.x, gi.y, gi.z) and not _grid.has_neighbor(gi.x, gi.y, gi.z):
			failures.append("openings_embedded: %s opening at (%.1f,%.1f,%.1f) floats outside masonry"
				% [tag, pos.x, pos.y, pos.z])
			continue
		var solid_x: bool = _grid.ray_hits_solid(gi, Vector3i.RIGHT) \
			or _grid.ray_hits_solid(gi, Vector3i.LEFT)
		var solid_z: bool = _grid.ray_hits_solid(gi, Vector3i.BACK) \
			or _grid.ray_hits_solid(gi, Vector3i.FORWARD)
		if not solid_x:
			failures.append("openings_embedded: opening at (%.1f,%.1f,%.1f) [%s] cuts through - no masonry on either X side"
				% [pos.x, pos.y, pos.z, tag])
		elif not solid_z:
			failures.append("openings_embedded: opening at (%.1f,%.1f,%.1f) [%s] cuts through - no masonry on either Z side"
				% [pos.x, pos.y, pos.z, tag])
	if checked == 0:
		warnings.append("openings_embedded: no openings logged")
	stats["openings_checked"] = checked


func _check_aperture_surround(part: Dictionary) -> void:
	var pos: Vector3 = part.pos
	var size: Vector3 = part.size
	var normal: Vector3 = part.facing
	if size.x <= 0.0 or size.y <= 0.0 or normal.length_squared() < 0.9 or absf(normal.y) > 0.01:
		failures.append("openings_embedded: %s has invalid planned aperture dimensions/facing" % part.tag)
		return
	var tangent := Vector3(normal.z, 0.0, -normal.x).normalized()
	# Trim is 0.09m wide. Probe its centre at the logged wall centreline,
	# where masonry must be present even when both rooms beyond are empty.
	var samples := {
		"left jamb": pos - tangent * (size.x * 0.5 + 0.045),
		"right jamb": pos + tangent * (size.x * 0.5 + 0.045),
		"head": pos + Vector3.UP * (size.y * 0.5 + 0.045),
		"sill": pos - Vector3.UP * (size.y * 0.5 + 0.045),
	}
	for side in samples:
		# Do not use VoxelGrid.vx/vy/vz here: their boundary clamping would
		# let a log moved outside the entire mesh borrow its boundary voxel.
		var cell: Vector3 = (Vector3(samples[side]) - _grid.origin) / _grid.vox
		if not _grid.get_voxel(floori(cell.x), floori(cell.y), floori(cell.z)):
			failures.append("openings_embedded: %s planned window at %s has no masonry at its %s"
				% [part.tag, pos, side])


## The rule a fortification lives or dies by: walk the wall centre-line the
## whole way round each ring and require masonry under every step of it, except
## across the gate. A curtain with a hole in it is not a curtain, and neither
## the mass log nor a bounding box would ever say so -- both are perfectly happy
## with a wall run that was logged but never emitted.
func _check_enceinte() -> void:
	if not CastleGeometry.is_enclosed(spec):
		return
	for r in CastleGeometry.rings(spec):
		var rect: Rect2 = CastleGeometry.enceinte_rect(spec, r)
		var t: float = CastleGeometry.wall_thickness(spec, r)
		var y: float = CastleGeometry.sky_ground_level(spec) \
			+ CastleGeometry.wall_height(spec, r) * 0.5
		var gw: float = CastleGeometry.gate_width(spec, r)
		var breaks := 0
		var samples := 0
		var step: float = _grid.vox
		# the centre-line of the enceinte, inset half a wall thickness from the
		# outer face. On the rectangular plan that is the site rectangle; on a
		# polygonal one it is the polygon, walked edge by edge.
		var runs := []
		var line: PackedVector2Array = CastleGeometry.offset_polygon(
			CastleGeometry.enceinte_polygon(spec, r), t / 2.0)
		var gate_edge: int = 0
		if not CastleGeometry.is_polygonal(spec):
			var x0: float = rect.position.x + t / 2.0
			var x1: float = rect.end.x - t / 2.0
			var z0: float = rect.position.y + t / 2.0
			var z1: float = rect.end.y - t / 2.0
			line = PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0),
				Vector2(x1, z1), Vector2(x0, z1)])
		for e in range(line.size()):
			var a2: Vector2 = line[e]
			var b2: Vector2 = line[(e + 1) % line.size()]
			runs.append({"from": Vector3(a2.x, y, a2.y),
				"to": Vector3(b2.x, y, b2.y), "gate": e == gate_edge})
		for run in runs:
			var a: Vector3 = run["from"]
			var b: Vector3 = run["to"]
			var n: int = maxi(int(a.distance_to(b) / step), 1)
			for i in range(n + 1):
				var p: Vector3 = a.lerp(b, float(i) / n)
				# the gate is a hole in the wall by design, not a break in it
				if run["gate"] and absf(p.x) <= gw / 2.0 + step:
					continue
				samples += 1
				if not _solid_near(p):
					breaks += 1
		stats["ring_%d_samples" % r] = samples
		if breaks > 0:
			failures.append("enceinte_closed: ring %d has %d/%d points of open air on its wall line"
				% [r, breaks, samples])


## Masonry at p, or within a voxel of it -- the wall line is a nominal centre,
## and a battered wall leans away from it as it rises.
func _solid_near(p: Vector3) -> bool:
	var g := Vector3i(_grid.vx(p.x), _grid.vy(p.y), _grid.vz(p.z))
	for dx in range(-WALL_PROBE, WALL_PROBE + 1):
		for dz in range(-WALL_PROBE, WALL_PROBE + 1):
			if _grid.get_voxel(g.x + dx, g.y, g.z + dz):
				return true
	return false


## The mass the assembly is measured from: the curtain of a walled tier, the
## hall of an unwalled one.
func _anchor_name() -> String:
	if CastleGeometry.is_sky(spec):
		return "rock"
	return "wall_0_back" if CastleGeometry.is_enclosed(spec) else "hall"
