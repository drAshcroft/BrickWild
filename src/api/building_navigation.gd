class_name BuildingNavigation
extends RefCounted
## Where a person can walk inside a generated building, for a consumer that
## wants to send people upstairs by the stairs and not through the ceiling.
##
## Each storey's floor is the floor `HouseNavCheck` walks -- its rooms, courts
## and doorways, less the furniture, columns and hearth it walks round -- baked
## into a navigation mesh; each stair is a link between the two landings the
## check climbs between. Building-local frame: metres, the building's own axes
## (front -Z), y up; it moves with the instanced building.
##
## Families that keep a HousePlan (houses, shops, hotels) are walked, and so is
## any family whose adapter publishes `walk_sources` / `walk_frame` (temples:
## the floor and obstruction `TempleRiteCheck` walks). Churches, castles,
## windmills, bridges and trees report `supported: false`: their walks live in
## their own checks and are not yet published (see docs/VILLAGES.md,
## "Walking inside").

const SCHEMA := "brickwild.building_walk"
const SCHEMA_VERSION := 1
const PLACES := 0.001
const AGENT_RADIUS := HouseGeometry.PERSON_RADIUS
## A link end further than this from its storey's mesh is reported unlinked.
const LINK_REACH := 1.0


static func of(building) -> Dictionary:
	if building == null or not building.is_ok():
		return {"schema": SCHEMA, "schema_version": SCHEMA_VERSION, "supported": false}
	if not (building.plan is HousePlan):
		return _of_family(building)
	var plan: HousePlan = building.plan
	var sources: Dictionary = HouseWalkSources.sources(plan)
	var meshes := {}
	var storeys: Array = []
	for level in HouseWalkSources.levels_of(plan):
		var mesh: Dictionary = NavBake.bake(sources[level]["floor"], sources[level]["obstacles"], AGENT_RADIUS)
		meshes[level] = mesh
		var vertices: Array = []
		for v in mesh["vertices"]:
			vertices.append([_n(v.x), _n(v.y)])
		var polygons: Array = []
		for p in mesh["polygons"]:
			polygons.append(Array(p))
		storeys.append({"storey": level, "floor_y_m": _n(floor_y(plan, level)),
			"navmesh": {"vertices_m": vertices, "polygons": polygons, "area_m2": _n(NavBake.area(mesh))}})
	return {
		"schema": SCHEMA,
		"schema_version": SCHEMA_VERSION,
		"supported": true,
		"frame": "building local: metres, front -Z, y up",
		"agent_radius_m": _n(AGENT_RADIUS),
		"storeys": storeys,
		"stairs": _stairs(plan, meshes),
		"doors": _doors(plan, meshes),
		"furniture": _furniture(plan, meshes),
	}


## A family that is not a HousePlan: its adapter's walk sources, baked the same
## way, with the front door and the focus (altar, ...) in the shapes the house
## walk uses so one reader serves both.
static func _of_family(building) -> Dictionary:
	var adapter: BuildingFamilyAdapter = BuildingFamilyAdapter.for_building(building)
	var sources: Dictionary = adapter.walk_sources(building) if adapter != null else {}
	if sources.is_empty():
		return {"schema": SCHEMA, "schema_version": SCHEMA_VERSION, "supported": false}
	var frame: Dictionary = adapter.walk_frame(building)
	var floor_ys: Dictionary = frame.get("floor_y", {})
	var levels: Array = sources.keys()
	levels.sort()
	var meshes := {}
	var storeys: Array = []
	for level in levels:
		var mesh: Dictionary = NavBake.bake(sources[level]["floor"], sources[level]["obstacles"], AGENT_RADIUS)
		meshes[level] = mesh
		var vertices: Array = []
		for v in mesh["vertices"]:
			vertices.append([_n(v.x), _n(v.y)])
		var polygons: Array = []
		for p in mesh["polygons"]:
			polygons.append(Array(p))
		storeys.append({"storey": level, "floor_y_m": _n(float(floor_ys.get(level, 0.0))),
			"navmesh": {"vertices_m": vertices, "polygons": polygons, "area_m2": _n(NavBake.area(mesh))}})
	var stairs: Array = []
	for link in frame.get("links", []):
		var lo: int = int(link["from_storey"])
		var hi: int = int(link["to_storey"])
		if not meshes.has(lo) or not meshes.has(hi):
			continue
		var lower_on: Vector2 = NavBake.closest_point(meshes[lo], link["lower"])
		var upper_on: Vector2 = NavBake.closest_point(meshes[hi], link["upper"])
		stairs.append({
			"from_storey": lo, "to_storey": hi,
			"lower_m": [_n(lower_on.x), _n(float(floor_ys.get(lo, 0.0))), _n(lower_on.y)],
			"upper_m": [_n(upper_on.x), _n(float(floor_ys.get(hi, 0.0))), _n(upper_on.y)],
			"width_m": _n(float(link.get("width", 0.0))),
			"linked": lower_on.distance_to(link["lower"]) <= LINK_REACH and upper_on.distance_to(link["upper"]) <= LINK_REACH,
		})
	var doors: Array = []
	for i in frame.get("doors", []).size():
		var d: Dictionary = frame["doors"][i]
		var pos: Vector2 = d["pos"]
		var normal: Vector2 = d["normal"]
		var level: int = int(d.get("storey", 0))
		if not meshes.has(level):
			continue
		var y: float = float(floor_ys.get(level, 0.0))
		var inside: Vector2 = NavBake.closest_point(meshes[level], pos - normal * 0.5)
		var outside: Vector2 = pos + normal * 0.3
		doors.append({
			"door": i, "storey": level, "front": bool(d.get("front", false)),
			"door_m": [_n(pos.x), _n(y), _n(pos.y)],
			"inside_m": [_n(inside.x), _n(y), _n(inside.y)],
			"outside_m": [_n(outside.x), _n(y), _n(outside.y)],
		})
	var focus: Array = []
	for i in frame.get("focus", []).size():
		var f: Dictionary = frame["focus"][i]
		var level: int = int(f.get("storey", 0))
		if not meshes.has(level):
			continue
		var use: Vector2 = NavBake.closest_point(meshes[level], f["pos"])
		focus.append({"item": i, "key": String(f["key"]), "room": -1, "storey": level,
			"use_m": [_n(use.x), _n(float(floor_ys.get(level, 0.0))), _n(use.y)]})
	return {
		"schema": SCHEMA,
		"schema_version": SCHEMA_VERSION,
		"supported": true,
		"frame": "building local: metres, front -Z, y up",
		"agent_radius_m": _n(AGENT_RADIUS),
		"storeys": storeys,
		"stairs": stairs,
		"doors": doors,
		"furniture": focus,
	}


## The height a person stands at on a storey: the slab's top.
static func floor_y(plan: HousePlan, level: int) -> float:
	return float(level) * plan.spec.height + HouseGeometry.FLOOR_T


## One region per storey and one two-way link per stair, in the building's
## frame: add it under the instanced building. Null for a family not walked.
static func node(building) -> Node3D:
	var data: Dictionary = of(building)
	if not data["supported"]:
		return null
	var root := Node3D.new()
	root.name = "Navigation"
	for row in data["storeys"]:
		var region := NavigationRegion3D.new()
		region.name = "Storey%d" % int(row["storey"])
		var vertices := PackedVector2Array()
		for v in row["navmesh"]["vertices_m"]:
			vertices.append(Vector2(v[0], v[1]))
		var polygons: Array[PackedInt32Array] = []
		for p in row["navmesh"]["polygons"]:
			polygons.append(PackedInt32Array(p))
		var mesh := {"vertices": vertices, "polygons": polygons}
		region.navigation_mesh = NavBake.to_navigation_mesh(mesh, float(row["floor_y_m"]))
		root.add_child(region)
	for i in data["stairs"].size():
		var stair: Dictionary = data["stairs"][i]
		if not stair["linked"]:
			continue
		var link := NavigationLink3D.new()
		link.name = "Stair%d" % i
		link.bidirectional = true
		link.start_position = _v3(stair["lower_m"])
		link.end_position = _v3(stair["upper_m"])
		root.add_child(link)
	return root


static func _stairs(plan: HousePlan, meshes: Dictionary) -> Array:
	var out: Array = []
	for stair in plan.stairs:
		var lo: int = int(stair.get("storey", 0))
		var hi: int = int(stair.get("to_storey", lo + 1))
		if not meshes.has(lo) or not meshes.has(hi):
			continue
		var lower: Vector2 = HouseWalkSources.stair_rect(stair, false).get_center()
		var upper: Vector2 = HouseWalkSources.stair_rect(stair, true).get_center()
		var lower_on: Vector2 = NavBake.closest_point(meshes[lo], lower)
		var upper_on: Vector2 = NavBake.closest_point(meshes[hi], upper)
		out.append({
			"from_storey": lo,
			"to_storey": hi,
			"lower_m": [_n(lower_on.x), _n(floor_y(plan, lo)), _n(lower_on.y)],
			"upper_m": [_n(upper_on.x), _n(floor_y(plan, hi)), _n(upper_on.y)],
			"width_m": _n(float(stair.get("width", 0.0))),
			"linked": lower_on.distance_to(lower) <= LINK_REACH and upper_on.distance_to(upper) <= LINK_REACH,
		})
	return out


## The exterior doors: where the street's walk meets this one. `inside_m` is
## on the storey's mesh; `outside_m` is a stride out from the wall.
static func _doors(plan: HousePlan, meshes: Dictionary) -> Array:
	var out: Array = []
	var half: float = HouseGeometry.wall_thickness(plan.spec) * 0.5
	for d in plan.doors.size():
		var door: Dictionary = plan.doors[d]
		if not bool(door.get("exterior", false)) or bool(door.get("secret", false)):
			continue
		var level := HousePlan.record_storey(door)
		if not meshes.has(level):
			continue
		var pos: Vector2 = door["pos"]
		var normal: Vector2 = door["normal"]
		var inside: Vector2 = NavBake.closest_point(meshes[level], pos - normal * (half + 0.2))
		var outside: Vector2 = pos + normal * (half + 0.3)
		var y: float = floor_y(plan, level)
		out.append({
			"door": d,
			"storey": level,
			"front": d == plan.entrance(),
			"door_m": [_n(pos.x), _n(y), _n(pos.y)],
			"inside_m": [_n(inside.x), _n(y), _n(inside.y)],
			"outside_m": [_n(outside.x), _n(float(level) * plan.spec.height), _n(outside.y)],
		})
	return out


## Every piece of furniture with a use zone, and the nearest point of its own
## storey's mesh to where a person stands to use it.
static func _furniture(plan: HousePlan, meshes: Dictionary) -> Array:
	var out: Array = []
	for i in plan.furniture.size():
		var p: Dictionary = plan.furniture[i]
		var zone: Rect2 = p.get("zone", Rect2())
		var level := HousePlan.record_storey(p)
		if zone.size.x <= 0.0 or not meshes.has(level):
			continue
		var use: Vector2 = NavBake.closest_point(meshes[level], zone.get_center())
		out.append({
			"item": i,
			"key": String(p["key"]),
			"room": int(p.get("room", -1)),
			"storey": level,
			"use_m": [_n(use.x), _n(floor_y(plan, level)), _n(use.y)],
		})
	return out


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _n(v: float) -> float:
	return snappedf(v, PLACES)
