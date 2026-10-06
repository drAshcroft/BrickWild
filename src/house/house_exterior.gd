class_name HouseExterior
extends RefCounted
## Measured exterior dressing, separate from room furniture. No model loads:
## the plan owns origin, bounds, facade host and keep-clear reservations.


static func dress(plan: HousePlan) -> void:
	plan.exterior.clear()
	plan.exterior_omissions.clear()
	plan.yard.clear()
	plan.yard_pieces.clear()
	if not plan.spec.exterior_props:
		return
	if HouseGeometry.is_shaped(plan) or plan.has_court():
		plan.exterior_omissions.append("Exterior recipes currently require a rectangular house facade.")
		return
	var s := plan.spec
	var service := 3 if posmod(s.seed, 2) == 0 else 2
	var trade_recipe := false
	var recipe: Array = [["Lantern_Wall", 0.45, 0, "entrance_light"],
		["Bench", 0.8, 0, "entrance_seat"],
		["Barrel", 1.0, service, "storage"], ["Bucket_Wooden_1", 1.0, service, "storage"]]
	if s.trade == &"farmer" or s.style == &"farmhouse":
		recipe = [["Lantern_Wall", 0.45, 0, "entrance_light"], ["Bench", 0.8, 0, "entrance_seat"],
			["Barrel_Apples", 1.0, service, "produce"], ["FarmCrate_Carrot", 1.0, service, "produce"],
			["Bag", 0.9, service, "produce"]]
		trade_recipe = true
	if s.trade == &"smith":
		recipe = [["Lantern_Wall", 0.45, 0, "entrance_light"], ["Bench", 0.7, 0, "entrance_seat"],
			["Anvil_Log", 1.0, service, "smith_work"], ["Crate_Wooden", 0.8, service, "smith_work"]]
		trade_recipe = true
	elif s.trade == &"alchemist" or s.style == &"witch_hut":
		recipe = [["Lantern_Wall", 0.45, 0, "entrance_light"], ["Cauldron", 0.7, service, "herb_work"],
			["Pot_1", 1.4, service, "herb_work"], ["Bucket_Wooden_1", 1.0, service, "herb_work"]]
		trade_recipe = true
	elif s.trade == &"innkeeper":
		recipe.append(["Barrel_Holder", 0.85, service, "inn_storage"])
		trade_recipe = true
	if HouseSpec.STYLES.get(s.style, {}).has("culture") and not trade_recipe:
		# HOUSE-CULTURE. A trade still wins -- a smith's mud hut is a smith's --
		# but a household with none keeps what its kind of house keeps: a lamp
		# by the door, a bench in the shade, and the water and the storage.
		recipe = [["Lantern_Wall", 0.45, 0, "entrance_light"],
			["Bench", 0.8, 0, "entrance_seat"],
			["Pot_1", 1.2, service, "storage"], ["Barrel", 1.0, service, "storage"],
			["Bucket_Wooden_1", 1.0, service, "water"]]
	for item in recipe:
		var key: String = item[0]
		var scale: float = item[1]
		var size := PropCatalog.size(key)
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			plan.exterior_omissions.append("%s: missing measured catalogue dimensions" % key)
			continue
		var accepted := false
		var reason := "no clear facade slot"
		var walls: Array[int] = [int(item[2])]
		if int(item[2]) != 0:
			walls.append(1)
		for wall in walls:
			for fraction in [0.22, 0.78, 0.38, 0.62, 0.5, 0.12, 0.88]:
				var placement := _candidate(plan, key, scale, wall, fraction, item[3])
				reason = conflict(plan, placement, plan.exterior)
				if not reason.is_empty():
					continue
				placement["id"] = "exterior_%d" % plan.exterior.size()
				plan.exterior.append(placement)
				accepted = true
				break
			if accepted:
				break
		if not accepted:
			plan.exterior_omissions.append("%s: %s" % [key, reason])
	while not plan.exterior.is_empty() and not access_clear(plan):
		var removed: Dictionary = plan.exterior.pop_back()
		plan.exterior_omissions.append("%s: removed to preserve exterior access" % removed["key"])
	# Then the ground beyond the facade: the yard (HouseYard), planned after the
	# wall pieces so it never moves them.
	HouseYard.plan(plan)


static func _candidate(plan: HousePlan, key: String, scale: float, wall: int,
		fraction: float, role: String) -> Dictionary:
	var run: Dictionary = HouseGeometry.exterior_runs(plan.spec)[wall]
	var normal: Vector2 = run["normal"]
	var a: Vector2 = run["from"]
	var b: Vector2 = run["to"]
	var yaw := atan2(-normal.x, -normal.y)
	var rotation := Basis(Vector3.UP, yaw + PropCatalog.face_offset(key))
	var raw := PropCatalog.size(key) * scale
	var foot := PropCatalog.footprint_rotated(key, yaw + PropCatalog.face_offset(key)) * scale
	var mounted := PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED)
	var deep := foot.dot(normal.abs())
	# Out from the wall FACE, and the face is half of this house's own wall --
	# 0.35 m for a timber frame and rather more for a mud-brick one.
	var outward := HouseGeometry.wall_thickness(plan.spec) * 0.5 + deep * 0.5 + (-0.005 if mounted else 0.16)
	var center := a.lerp(b, fraction) + normal * outward
	var center_y := minf(1.85, plan.spec.height - raw.y * 0.5 - 0.12) if mounted else raw.y * 0.5
	var off: Vector3 = rotation * (PropCatalog.centre_offset(key) * scale)
	var pos := Vector3(center.x - off.x, center_y - off.y if mounted else 0.0, center.y - off.z)
	var bounds := AABB(Vector3(center.x - foot.x * 0.5, center_y - raw.y * 0.5, center.y - foot.y * 0.5),
		Vector3(foot.x, raw.y, foot.y))
	return {"key": key, "pos": pos, "yaw": yaw, "scale": scale, "role": role,
		"host": wall, "storey": 0, "mounted": mounted, "bounds": bounds,
		"rect": Rect2(Vector2(bounds.position.x, bounds.position.z), foot)}


## Derive measured bounds from the actual origin used by HouseAssembler.
static func bounds_of(p: Dictionary) -> AABB:
	var key: String = p["key"]
	var scale: float = p["scale"]
	var yaw: float = p["yaw"] + PropCatalog.face_offset(key)
	var pos: Vector3 = p["pos"]
	if not PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED):
		# the same ground line HouseAssembler sits the model on (a plant's seat)
		pos.y -= PropCatalog.seat_offset(key) * scale
	var center: Vector3 = pos + Basis(Vector3.UP, yaw) * (PropCatalog.centre_offset(key) * scale)
	var foot := PropCatalog.footprint_rotated(key, yaw) * scale
	var size := Vector3(foot.x, PropCatalog.height(key) * scale, foot.y)
	return AABB(center - size * 0.5, size)


static func _opening_box(pos: Vector2, normal: Vector2, width: float,
		bottom: float, top: float, depth: float, thick: float) -> AABB:
	var along := Vector2(normal.y, -normal.x).abs() * width
	var size := along + normal.abs() * depth
	var center := pos + normal * (thick + depth * 0.5)
	return AABB(Vector3(center.x - size.x * 0.5, bottom, center.y - size.y * 0.5),
		Vector3(size.x, top - bottom, size.y))


## THE shared facade clearance rule, for the wall dressing and the yard alike
## (HouseYard.clear_reason calls it for every box it plans): nothing within a
## door's swing and approach, nothing under or before a window that is taller
## than the sill allows or that blocks a shutter or hood, nothing in the
## chimney. `bounds` is a measured world box. Empty when clear.
static func facade_clear(plan: HousePlan, bounds: AABB) -> String:
	for door in plan.doors:
		if not door["exterior"] or HousePlan.record_storey(door) != 0:
			continue
		var reserved := _opening_box(door["pos"], door["normal"], float(door["width"]) + 1.1,
			-0.1, HouseGeometry.DOOR_H + 0.25, 3.2, HouseGeometry.wall_thickness(plan.spec))
		if bounds.intersects(reserved):
			return "blocks a door approach or porch"
	for win in plan.windows:
		var level := HousePlan.record_storey(win) * plan.spec.height
		var width: float = win["width"] * (2.0 if plan.spec.window_shutters else 1.0) + 0.22
		if bounds.intersects(_opening_box(win["pos"], win["normal"], width,
			level + float(win["sill"]) - 0.1, level + float(win["head"]) + 0.25, 0.8,
			HouseGeometry.wall_thickness(plan.spec))):
			return "obstructs glazing, shutters or a window hood"
	if plan.spec.chimney:
		var c := HouseGeometry.chimney_center(plan)
		var size := HouseGeometry.chimney_size(plan.spec) + HouseGeometry.CHIMNEY_BASE_EXTRA + 0.12
		if bounds.intersects(AABB(Vector3(c.x - size * 0.5, 0, c.y - size * 0.5),
			Vector3(size, 30, size))):
			return "intersects the chimney"
	return ""


static func conflict(plan: HousePlan, p: Dictionary, placed: Array) -> String:
	if int(p.get("host", -1)) < 0 or int(p.get("host", -1)) >= 4:
		return "invalid exterior facade host"
	var bounds := bounds_of(p)
	var site := HouseGeometry.site_rect(plan.spec)
	var building := AABB(Vector3(site.position.x, 0, site.position.y),
		Vector3(site.size.x, plan.spec.height * plan.spec.storeys, site.size.y))
	# A mounted bracket can enter the wall by 5 mm; floor props cannot.
	if bounds.intersects(building.grow(-0.01)):
		return "intersects the house wall"
	var host: Dictionary = HouseGeometry.exterior_runs(plan.spec)[int(p["host"])]
	var normal: Vector2 = host["normal"]
	var tangent := Vector2(normal.y, -normal.x).abs()
	var center := Vector2(bounds.get_center().x, bounds.get_center().z)
	var span := Vector2(bounds.size.x, bounds.size.z).dot(tangent)
	var host_center: Vector2 = (host["from"] + host["to"]) * 0.5
	var host_length: float = (host["to"] - host["from"]).length()
	if absf((center - host_center).dot(tangent)) + span * 0.5 > host_length * 0.5 - 0.06:
		return "extends beyond its facade"
	var why := facade_clear(plan, bounds)
	if not why.is_empty():
		return why
	for other in placed:
		if bounds.grow(0.08).intersects(bounds_of(other)):
			return "overlaps another exterior prop"
	return ""


static func access_clear(plan: HousePlan) -> bool:
	if plan.entrance() < 0:
		return true
	var reached := reached_doors(plan, true)
	for d in plan.doors.size():
		var door: Dictionary = plan.doors[d]
		if door["exterior"] and HousePlan.record_storey(door) == 0 and d not in reached:
			return false
	return true


## Which ground-floor exterior doors a person walking in from the road reaches,
## round the wall dressing and, with `with_yard`, the yard's props and pieces.
## Where the yard applies the walk starts at the road edge of the yard envelope
## and is confined to it: a route round the outside is the lot's ground, not
## the house's, and cannot stand in for a way in.
static func reached_doors(plan: HousePlan, with_yard: bool) -> Array[int]:
	var out: Array[int] = []
	if plan.entrance() < 0:
		return out
	var site := HouseGeometry.site_rect(plan.spec)
	var yard := HouseYard.applies(plan)
	var ground := site.grow(4.0)
	if yard:
		ground = HouseGeometry.yard_rect(plan).grow(0.3)
	var grid := WalkGrid.new()
	grid.setup(ground, 0.15)
	grid.add_floor(ground)
	grid.add_obstacle(site)
	if plan.spec.chimney:
		var c := HouseGeometry.chimney_center(plan)
		var width := HouseGeometry.chimney_size(plan.spec) + HouseGeometry.CHIMNEY_BASE_EXTRA
		grid.add_obstacle(Rect2(c - Vector2.ONE * width * 0.5, Vector2.ONE * width))
	if plan.spec.porch:
		var door: Dictionary = plan.doors[plan.entrance()]
		var depth := HouseGeometry.porch_depth(plan.spec)
		var width: float = door["width"] + 1.1
		var center: Vector2 = door["pos"] + door["normal"] * (depth - 0.12)
		for side in [-1.0, 1.0]:
			var post := center + Vector2(side * (width * 0.5 - 0.1), 0)
			grid.add_obstacle(Rect2(post - Vector2.ONE * 0.07, Vector2.ONE * 0.14))
	for p in plan.exterior:
		var b := bounds_of(p)
		if b.position.y < HouseGeometry.DOOR_H:
			grid.add_obstacle(Rect2(Vector2(b.position.x,b.position.z), Vector2(b.size.x,b.size.z)))
	if with_yard and plan.spec.exterior_props:
		for rect in HouseYard.obstacles(plan):
			grid.add_obstacle(rect)
	grid.build(HouseGeometry.PERSON_RADIUS)
	var entrance: Dictionary = plan.doors[plan.entrance()]
	var start: Vector2 = entrance["pos"] + entrance["normal"] * 3.5
	if yard:
		start = HouseYard.road_point(plan)
	if not grid.flood_from(start):
		return out
	for d in plan.doors.size():
		var door: Dictionary = plan.doors[d]
		if door["exterior"] and HousePlan.record_storey(door) == 0:
			# Out past THIS house's wall face. The old constant put the probe
			# point inside a mud-brick wall, which is a door no walk can reach.
			var at: Vector2 = door["pos"] + door["normal"] * (HouseGeometry.wall_thickness(plan.spec) + 0.4)
			if grid.reached(Rect2(at - Vector2.ONE * 0.1, Vector2.ONE * 0.2)):
				out.append(d)
	return out


static func check(plan: HousePlan) -> Array[String]:
	var failures: Array[String] = []
	if not plan.spec.exterior_props:
		return failures
	var checked: Array = []
	for p in plan.exterior:
		var who := "exterior %s role=%s host=%s key=%s" % [p.get("id", "?"),
			p.get("role", "?"), p.get("host", "?"), p.get("key", "?")]
		var measured := bounds_of(p)
		var recorded: AABB = p["bounds"]
		if measured.position.distance_to(recorded.position) > 0.005 or measured.size.distance_to(recorded.size) > 0.005:
			failures.append(who + ": recorded bounds differ from measured placement")
		var reason := conflict(plan, p, checked)
		if not reason.is_empty():
			failures.append(who + ": " + reason)
		checked.append(p)
	if not plan.exterior.is_empty() and not access_clear(plan):
		failures.append("exterior: a door cannot be reached from the approach")
	return failures
