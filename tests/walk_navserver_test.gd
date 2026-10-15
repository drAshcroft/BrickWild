extends SceneTree
## The walk as a consumer receives it, handed to Godot's own NavigationServer3D
## and asked for paths: from the first gate to every door in each exported
## SitePlan, and in a two-storey house from the front door to every piece of
## furniture upstairs. Exit 0 when every path arrives.
##
##   godot --headless --path . --script res://tests/walk_navserver_test.gd \
##       -- out/walk/wuunafu.json out/walk/thaannafu.json

const ARRIVE := 0.05
## The map's vertex-merge grid as a share of its cell: 1 cm on a 0.25 m map,
## the grid the walk is baked on.
const MERGE_SCALE := 0.04

var _failures: Array[String] = []
var _checked := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	for path in paths:
		await _check_site(path)
	await _check_house()
	await _check_churches()
	await _check_temples()
	await _check_castles()
	print("walk navserver: %d paths, %d failures" % [_checked, _failures.size()])
	for f in _failures:
		print("  FAIL ", f)
	quit(0 if _failures.is_empty() else 1)


func _check_site(path: String) -> void:
	var site: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var walk: Dictionary = site["walk"]
	var vertices := PackedVector2Array()
	for v in walk["navmesh"]["vertices_m"]:
		vertices.append(Vector2(v[0], v[1]))
	var polygons: Array[PackedInt32Array] = []
	for p in walk["navmesh"]["polygons"]:
		polygons.append(PackedInt32Array(p))
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, 0.25)
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, MERGE_SCALE)
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region,
		NavBake.to_navigation_mesh({"vertices": vertices, "polygons": polygons}))
	await _settle(map)
	var gate: Array = walk["gates"][0]["nav_m"]
	var from := Vector3(gate[0], 0.0, gate[1])
	for d in walk["doors"]:
		_arrive(map, from, Vector3(d["outside_m"][0], 0.0, d["outside_m"][1]), "%s %s" % [path.get_file(), d["building_id"]])
	for f in walk["furniture"]:
		_arrive(map, from, Vector3(f["use_m"][0], 0.0, f["use_m"][1]), "%s %s" % [path.get_file(), f["prop_id"]])
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)


func _check_house() -> void:
	var building: GeneratedBuilding = BrickWild.generate(
		BuildingRequest.house(32102, &"townhouse", &"innkeeper", 13.0, 16.0, 2.9, 2))
	var data: Dictionary = BrickWild.navigation(building)
	var nav: Node3D = BrickWild.navigation_node(building)
	root.add_child(nav)
	var map: RID = root.get_world_3d().navigation_map
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, MERGE_SCALE)
	await _settle(map)
	var door: Array = data["doors"].filter(func(d: Dictionary) -> bool: return d["front"])[0]["inside_m"]
	var from := Vector3(door[0], door[1], door[2])
	var upstairs := 0
	for f in data["furniture"]:
		if int(f["storey"]) < 1:
			continue
		upstairs += 1
		var path: PackedVector3Array = _arrive(map, from, Vector3(f["use_m"][0], f["use_m"][1], f["use_m"][2]),
			"townhouse %s %d" % [f["key"], f["item"]])
		if path.size() >= 2 and path[path.size() - 1].y < float(f["use_m"][1]) - 0.1:
			_failures.append("townhouse %s %d: the path ends on the wrong floor" % [f["key"], f["item"]])
	if upstairs == 0:
		_failures.append("townhouse: no furniture upstairs to walk to")
	nav.queue_free()


func _check_temples() -> void:
	for c in [[&"basilica", &"blood", 26.0, 44.0, 12.0, 11], [&"pylon", &"flame", 24.0, 46.0, 12.0, 21],
			[&"rotunda", &"void", 26.0, 26.0, 13.0, 41]]:
		var building: GeneratedBuilding = BrickWild.generate(
			BuildingRequest.temple(c[5], c[0], c[1], c[2], c[3], c[4]))
		var data: Dictionary = BrickWild.navigation(building)
		var nav: Node3D = BrickWild.navigation_node(building)
		root.add_child(nav)
		var map: RID = root.get_world_3d().navigation_map
		NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, MERGE_SCALE)
		await _settle(map)
		var gate: Array = data["doors"].filter(func(d: Dictionary) -> bool: return d["front"])[0]["inside_m"]
		var from := Vector3(gate[0], gate[1], gate[2])
		var altars := 0
		for f in data["furniture"]:
			altars += 1
			_arrive(map, from, Vector3(f["use_m"][0], f["use_m"][1], f["use_m"][2]),
				"temple %s %s" % [c[0], f["key"]])
		if altars == 0:
			_failures.append("temple %s: no altar to walk to" % c[0])
		nav.queue_free()
		await physics_frame


## Gate to hall, chapel and lord's chamber in a walled castle: across the ward,
## through a range's door (a link), and up the keep by its forebuilding and its
## stairs (more links), the last of them 24 m above the ground it began on.
func _check_castles() -> void:
	for c in [[&"norman", 55.0, 50.0, 18.0, 202, ["hall", "chapel", "lords_chamber"]],
			[&"edwardian", 55.0, 50.0, 14.0, 1, ["lords_chamber"]]]:
		var building: GeneratedBuilding = BrickWild.generate(
			BuildingRequest.castle(c[4], c[0], c[1], c[2], c[3]))
		var data: Dictionary = BrickWild.navigation(building)
		var label := "castle %s %d" % [c[0], c[4]]
		if not data["supported"]:
			_failures.append("%s: not supported" % label)
			continue
		var nav: Node3D = BrickWild.navigation_node(building)
		root.add_child(nav)
		var map: RID = root.get_world_3d().navigation_map
		NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, MERGE_SCALE)
		await _settle(map)
		var gate: Array = data["doors"].filter(func(d: Dictionary) -> bool: return d["front"])[0]["inside_m"]
		var from := Vector3(gate[0], gate[1], gate[2])
		var walked := {}
		for f in data["furniture"]:
			if not String(f["key"]) in c[5]:
				continue
			walked[String(f["key"])] = true
			var path: PackedVector3Array = _arrive(map, from,
				Vector3(f["use_m"][0], f["use_m"][1], f["use_m"][2]), "%s gate to %s" % [label, f["key"]])
			if path.size() >= 2 and path[path.size() - 1].y < float(f["use_m"][1]) - 0.1:
				_failures.append("%s gate to %s: the path ends on the wrong floor" % [label, f["key"]])
		for key in c[5]:
			if not walked.has(key):
				_failures.append("%s: no %s to walk to" % [label, key])
		nav.queue_free()
		await physics_frame


## Door to altar, and door to the point furthest from the axis (an aisle where
## the church has one, reached only through the arcade), from every west door.
func _check_churches() -> void:
	for c in [[&"romanesque", 12.0, 28.0, 11.0, 7], [&"gothic", 16.0, 44.0, 18.0, 3],
			[&"gothic", 20.0, 58.0, 22.0, 21], [&"byzantine", 16.0, 30.0, 14.0, 12],
			[&"renaissance", 14.0, 34.0, 15.0, 5], [&"russian", 12.0, 26.0, 13.0, 9],
			[&"nordic_stave", 9.0, 20.0, 9.0, 4]]:
		var building: GeneratedBuilding = BrickWild.generate(
			BuildingRequest.church(c[4], c[0], c[1], c[2], c[3]))
		var data: Dictionary = BrickWild.navigation(building)
		var nav: Node3D = BrickWild.navigation_node(building)
		root.add_child(nav)
		var map: RID = root.get_world_3d().navigation_map
		NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, MERGE_SCALE)
		await _settle(map)
		var label := "church %s %d" % [c[0], c[4]]
		var far := Vector3.ZERO
		for v in data["storeys"][0]["navmesh"]["vertices_m"]:
			if absf(v[0]) > absf(far.x):
				far = Vector3(v[0], data["storeys"][0]["floor_y_m"], v[1])
		var altars := 0
		for d in data["doors"]:
			var from := Vector3(d["inside_m"][0], d["inside_m"][1], d["inside_m"][2])
			for f in data["furniture"]:
				altars += 1
				_arrive(map, from, Vector3(f["use_m"][0], f["use_m"][1], f["use_m"][2]),
					"%s door %d to %s" % [label, d["door"], f["key"]])
			_arrive(map, from, NavigationServer3D.map_get_closest_point(map, far),
				"%s door %d to the far side" % [label, d["door"]])
		if altars == 0:
			print("  note: %s has no nave altar" % label)
		nav.queue_free()
		await physics_frame


func _arrive(map: RID, from: Vector3, to: Vector3, label: String) -> PackedVector3Array:
	_checked += 1
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > ARRIVE:
		_failures.append("%s: no path from %v to %v (ends %s)" % [label, from, to,
			str(path[path.size() - 1]) if not path.is_empty() else "nowhere"])
	return path


func _settle(map: RID) -> void:
	var start: int = NavigationServer3D.map_get_iteration_id(map)
	for i in 240:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > start + 1:
			for j in 20:
				await physics_frame
			return
