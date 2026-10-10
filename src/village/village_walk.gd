class_name VillageWalk
extends RefCounted
## Where a person can walk in a village, for a consumer that will never run
## BrickWild: the site's ground as floor and obstacle outlines, the same ground
## baked into a navigation mesh, and the points a walker heads for -- the gates,
## both sides of every door, and the furniture meant to be used.
##
## It is the ground `VillageNavCheck` judges, not a second opinion of it:
## `VillageNavCheck.sources()` lists the outlines `build_grid()` paints, and
## every door's outside point is the check's own threshold. A door the check
## cannot reach is written with `"reachable": false`, not left out.
##
## Plain JSON data in the site frame (metres, +X east, +Z south, ground at
## y = 0), every float snapped to a millimetre, every list in a fixed order.

const SCHEMA := "brickwild.walk"
const SCHEMA_VERSION := 1
const PLACES := 0.001
const AGENT_RADIUS := HouseGeometry.PERSON_RADIUS
## How far behind the door plane a walker stands once through it: past the
## wall, on the first floor inside.
const INSIDE := 0.6


static func projection(plan: VillagePlan, city_id: String) -> Dictionary:
	var src: Dictionary = VillageNavCheck.sources(plan)
	var floor: Array[PackedVector2Array] = []
	var obstacles: Array[PackedVector2Array] = []
	for row in src["floor"]:
		floor.append(row["poly"])
	for row in src["obstacles"]:
		obstacles.append(row["poly"])
	var mesh: Dictionary = NavBake.bake(floor, obstacles, AGENT_RADIUS)
	var grid: WalkGrid = VillageNavCheck.reached_grid(plan)
	return {
		"schema": SCHEMA,
		"schema_version": SCHEMA_VERSION,
		"frame": "site: metres, +X east, +Z south, ground y 0",
		"agent_radius_m": _n(AGENT_RADIUS),
		"floor": _outlines(plan, city_id, src["floor"]),
		"obstacles": _outlines(plan, city_id, src["obstacles"]),
		"navmesh": _mesh(mesh),
		"gates": _gates(plan, mesh),
		"doors": _doors(plan, city_id, mesh, grid),
		"furniture": _furniture(plan, mesh),
	}


static func _outlines(plan: VillagePlan, city_id: String, rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		out.append({"kind": row["kind"], "ref": _ref(plan, city_id, row["kind"], int(row["id"])),
			"poly_m": _points(row["poly"])})
	return out


## The id the rest of the SitePlan already gives the thing an outline is of.
static func _ref(plan: VillagePlan, city_id: String, kind: String, i: int) -> String:
	match kind:
		"road":
			return "%s-%03d" % [String(plan.roads[i]["class"]), i]
		"lot":
			return "l-%03d" % i
		"building", "yard", "court":
			return "%s/b-%03d" % [city_id, i]
		"prop", "approach":
			return "prop-%03d" % i
		"trunk":
			return "plant-%03d" % i
	return "%s-%03d" % [kind, i]


static func _mesh(mesh: Dictionary) -> Dictionary:
	var vertices: Array = []
	for v in mesh["vertices"]:
		vertices.append([_n(v.x), _n(v.y)])
	var polygons: Array = []
	for poly in mesh["polygons"]:
		polygons.append(Array(poly))
	return {"vertices_m": vertices, "polygons": polygons, "area_m2": _n(NavBake.area(mesh))}


## Where a walker comes in: each gate in the enclosure, or the two ends of the
## through road when there is none. `nav_m` is the nearest navigable point.
static func _gates(plan: VillagePlan, mesh: Dictionary) -> Array:
	var out: Array = []
	if not plan.gate_crossings.is_empty():
		for g in plan.gate_crossings.size():
			var gate: Dictionary = plan.gate_crossings[g]
			var road: int = int(gate["road"])
			out.append(_gate("gate-%02d" % g, "gate", plan, road, gate["pos"], mesh))
		return out
	if plan.spec.enclosure != &"none":
		return out
	for r in plan.roads_of_class(&"through"):
		var pts: PackedVector2Array = plan.roads[r]["points"]
		if pts.size() < 2:
			continue
		for p in [pts[0], pts[pts.size() - 1]]:
			out.append(_gate("gate-%02d" % out.size(), "road_end", plan, r, p, mesh))
	return out


static func _gate(id: String, kind: String, plan: VillagePlan, road: int, pos: Vector2,
		mesh: Dictionary) -> Dictionary:
	var valid: bool = road >= 0 and road < plan.roads.size()
	return {
		"gate_id": id,
		"kind": kind,
		"road_id": "%s-%03d" % [String(plan.roads[road]["class"]), road] if valid else null,
		"width_m": _n(float(plan.roads[road]["width"])) if valid else null,
		"pos_m": _pair(pos),
		"nav_m": _pair(NavBake.closest_point(mesh, pos)),
	}


## Both sides of every door. `outside_m` is the first ground outside it the
## village check can stand on, moved onto the mesh; `inside_m` is a stride
## behind the door plane. The straight step between them is the doorway, and
## it crosses the building's own outline by design.
static func _doors(plan: VillagePlan, city_id: String, mesh: Dictionary, grid: WalkGrid) -> Array:
	var out: Array = []
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var door: Vector2 = VillageMeasure.door(b)
		var threshold: Vector2 = VillageNavCheck.threshold_on(plan, grid, i)
		var row := {
			"building_id": "%s/b-%03d" % [city_id, i],
			"level": 0,
			"door_m": _pair(door),
			"inside_m": _pair(door - VillageMeasure.front_dir(b) * INSIDE),
			"outside_m": null,
			"reachable": false,
		}
		if threshold != Vector2.INF:
			row["outside_m"] = _pair(NavBake.closest_point(mesh, threshold))
			row["reachable"] = grid.reached(Rect2(threshold, Vector2.ZERO), VillageNavCheck.DOOR_REACH)
		out.append(row)
	return out


## What is placed to be used -- the well, the stalls, the benches: every prop
## with a use zone, which is the set `VillageNavCheck` asks about. `use_m` is
## the nearest navigable point to it.
static func _furniture(plan: VillagePlan, mesh: Dictionary) -> Array:
	var out: Array = []
	for i in plan.props.size():
		var p: Dictionary = plan.props[i]
		var zone: Rect2 = p.get("zone", Rect2())
		if zone.size.x <= 0.0:
			continue
		var rect: Rect2 = p.get("rect", Rect2(p["pos"], Vector2.ZERO))
		out.append({
			"prop_id": "prop-%03d" % i,
			"key": String(p["key"]),
			"pos_m": _pair(p["pos"]),
			"rect_m": [_n(rect.position.x), _n(rect.position.y), _n(rect.size.x), _n(rect.size.y)],
			"use_m": _pair(NavBake.closest_point(mesh, rect.get_center())),
		})
	return out


static func _points(poly: PackedVector2Array) -> Array:
	var out: Array = []
	for p in poly:
		out.append(_pair(p))
	return out


static func _pair(p: Vector2) -> Array:
	return [_n(p.x), _n(p.y)]


static func _n(v: float) -> float:
	return snappedf(v, PLACES)
