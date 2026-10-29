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
	var out := {
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
	if plan.ground != null:
		_add_3d(plan, city_id, out)
	return out


## On given ground (VTER-STEPS-NAV): the same village baked in 3D from what
## was built (VillageWalk3D), the gates and doors on it, and the stairs. The
## flat keys above are unchanged; a consumer that knows only them still walks
## the plan view. Every 3D point is [x, y, z] in the site frame, y the height
## of the ground (or the stair, or the landing) a walker stands on there.
static func _add_3d(plan: VillagePlan, city_id: String, out: Dictionary) -> void:
	var m3: Dictionary = VillageWalk3D.bake(plan)
	var surface := VillageGroundSurface.of(plan)
	var islands: PackedInt32Array = VillageWalk3D.islands(m3)
	var vertices: Array = []
	for v in m3["vertices"]:
		vertices.append([_n(v.x), _n(v.y), _n(v.z)])
	var polygons: Array = []
	for poly in m3["polygons"]:
		polygons.append(Array(poly))
	var links: Array = []
	for link in m3["links"]:
		links.append({"kind": link["kind"], "building_id": ("%s/b-%03d" % [city_id, int(link["building"])]) if int(link["building"]) >= 0 else "",
			"door": int(link["door"]), "from_m": _triple(link["from"]), "to_m": _triple(link["to"]),
			"bidirectional": true})
	out["navmesh_3d"] = {
		"frame": "site: metres, +X east, +Y up, +Z south; polygons wound as Godot's NavigationMesh",
		"vertices_m": vertices,
		"polygons": polygons,
		"cell_size_m": VillageWalk3D.CELL,
		"cell_height_m": VillageWalk3D.CELL_HEIGHT,
		"merge_rasterizer_cell_scale": VillageWalk3D.MERGE_SCALE,
		# Godot's path search stops after 4096 polygons by default; a
		# consumer allows at least this many (NavigationPathQueryParameters3D
		# or NavigationAgent3D .path_search_max_polygons; 0 is no limit)
		"path_search_max_polygons": maxi(4096, polygons.size()),
		"agent": {"radius_m": VillageWalk3D.agent_radius(), "height_m": VillageWalk3D.AGENT_HEIGHT,
			"max_climb_m": VillageWalk3D.MAX_CLIMB, "max_slope_deg": VillageWalk3D.MAX_SLOPE_DEG},
		"links": links,
	}
	var gate_islands := {}
	for g in out["gates"]:
		var at := Vector2(float(g["nav_m"][0]), float(g["nav_m"][1]))
		var c := VillageWalk3D.closest(m3, Vector3(at.x, surface.ground_at(at), at.y))
		g["nav_3d_m"] = _triple(c["point"]) if int(c["polygon"]) >= 0 else null
		if int(c["polygon"]) >= 0:
			gate_islands[islands[int(c["polygon"])]] = true
	for i in out["doors"].size():
		var d: Dictionary = out["doors"][i]
		var b: Dictionary = plan.buildings[i]
		var target := Vector3.INF
		var flight := _entry_flight(plan, b)
		if not flight.is_empty():
			var route: Array = flight["route"]
			target = route[0]
			d["route_m"] = route.map(func(q: Vector3) -> Array: return _triple(q))
		elif d["outside_m"] != null:
			var o := Vector2(float(d["outside_m"][0]), float(d["outside_m"][1]))
			target = Vector3(o.x, surface.ground_at(o), o.y)
		d["outside_3d_m"] = null
		d["reachable_3d"] = false
		if target.is_finite():
			var c := VillageWalk3D.closest(m3, target)
			if int(c["polygon"]) >= 0:
				d["outside_3d_m"] = _triple(c["point"])
				d["reachable_3d"] = gate_islands.has(islands[int(c["polygon"])]) \
					and (c["point"] as Vector3).distance_to(target) <= DOOR_SNAP_3D
	out["stairs"] = _stairs(plan, city_id, surface)


## How far a door's 3D target may be from the mesh and still be at the door.
const DOOR_SNAP_3D := 1.0


## The entry flight of building `b`'s front door on its lot, or {}.
static func _entry_flight(plan: VillagePlan, b: Dictionary) -> Dictionary:
	var li: int = int(b.get("lot", -1))
	if li < 0 or li >= plan.lots.size():
		return {}
	var door := VillageMeasure.door(b)
	var best := {}
	var best_d := 1.5
	for f in plan.lots[li].get("ground_fit", {}).get("entry_flights", []):
		var r: Vector3 = f["route"][0]
		var d := Vector2(r.x, r.z).distance_to(door)
		if d < best_d:
			best_d = d
			best = f
	return best


## Every stair the village built: the treads of each `steps` road (its own,
## not those under a greater road), each lot's access flight (or why it has
## none), each house's entry flights.
static func _stairs(plan: VillagePlan, city_id: String, surface: VillageGroundSurface) -> Array:
	var out: Array = []
	for i in plan.roads.size():
		var bed: Dictionary = surface.road_bed(i)
		if not bed.has("treads"):
			continue
		var ts: Array = bed["treads"]
		var sv: PackedFloat32Array = bed["s"]
		var length: float = sv[sv.size() - 1]
		var going := INF
		for k in range(1, ts.size() - 1):
			going = minf(going, float(ts[k]["s1"]) - float(ts[k]["s0"]))
		out.append({"kind": "street", "road_id": "%s-%03d" % [String(plan.roads[i]["class"]), i],
			"treads": ts.size(), "riser_m": VillageGroundSurface.RISER_STEPS,
			"going_min_m": _n(going) if going < INF else null, "length_m": _n(length),
			"rise_m": _n(float(ts[ts.size() - 1]["h"]) - float(ts[0]["h"]))})
	for b in plan.buildings.size():
		var li: int = int(plan.buildings[b].get("lot", -1))
		if li < 0 or li >= plan.lots.size():
			continue
		var fit: Dictionary = plan.lots[li].get("ground_fit", {})
		var access: Dictionary = fit.get("access", {})
		if not access.is_empty():
			var row := {"kind": "access", "lot_id": "l-%03d" % li, "building_id": "%s/b-%03d" % [city_id, b],
				"rise_m": _n(float(access["rise_m"]))}
			if access.has("refused"):
				row["refused"] = access["refused"]
			elif access.get("layout", "") == "level":
				row["layout"] = "level"
				row["at_m"] = [_n((access["at"] as Vector2).x), _n((access["at"] as Vector2).y)]
				row["width_m"] = _n(float(access["width_m"]))
			else:
				row["treads"] = (access["treads"] as Array).size()
				row["riser_m"] = _n(float(access["riser_m"]))
				row["going_m"] = _n(float(access["going_m"]))
				row["layout"] = access["layout"]
				row["foot_m"] = _triple(access["foot_m"])
				row["head_m"] = _triple(access["head_m"])
			out.append(row)
		for f in fit.get("entry_flights", []):
			out.append({"kind": "entry", "building_id": "%s/b-%03d" % [city_id, b], "door": int(f["door"]),
				"treads": (f["treads"] as Array).size() - 1,
				"route_m": (f["route"] as Array).map(func(q: Vector3) -> Array: return _triple(q))})
	return out


static func _triple(p: Vector3) -> Array:
	return [_n(p.x), _n(p.y), _n(p.z)]


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
