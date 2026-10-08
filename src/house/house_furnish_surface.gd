class_name HouseFurnishSurface
extends RefCounted

# Mounted, ceiling, and hosted surface placements.

## How far the foot of a hanging piece (a banner) clears the floor.
const HANG_CLEAR := 0.45

## A shelf, rack or sconce on a wall, above the furniture already there.
static func place_mounted(plan: HousePlan, room: int, key: String,
		r: RandomNumberGenerator) -> void:
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var y: float = HouseGeometry.SCONCE_HEIGHT if PropCatalog.category(key) == "sconce" \
		else HouseGeometry.SHELF_HEIGHT
	# A mount height is not the top of the mesh. In particular Lantern_Wall
	# extends 1.419m ABOVE its pivot, and used to project through low roofs.
	# Fit its measured body above head height and below the ceiling; scoring
	# and assembly receive that same scale, rather than just clamping light.
	var ceiling := plan.spec.height - HouseGeometry.FLOOR_T - 0.03
	var scale := 1.0
	if PropCatalog.category(key) == "sconce":
		scale = minf(1.0, maxf(0.1, ceiling - 1.7) / maxf(PropCatalog.height(key), 0.01))
	var top := (PropCatalog.floor_offset(key) + PropCatalog.height(key)) * scale
	# A banner hangs from its pivot: its measured floor is BELOW the pivot
	# (Banner_1_Cloth by 2.25 m). Hung at shelf height its cloth ran through
	# the floor -- a walker's "what is this?" in the domus fauces. Lift it so
	# its foot clears the floor, then let the ceiling have the last word.
	if PropCatalog.floor_offset(key) < 0.0:
		y = maxf(y, HANG_CLEAR - PropCatalog.floor_offset(key) * scale)
	y = minf(y, ceiling - top)
	if PropCatalog.category(key) == "sconce":
		y = maxf(y, 1.7 - PropCatalog.floor_offset(key) * scale)
	var width: float = PropCatalog.size(key).x * scale
	var lamp := PropCatalog.category(key) == "sconce"
	var shelf := PropCatalog.category(key) == "shelf"
	# Worked out once, not once per candidate: where a pair of these hangs is
	# a fact about the room, and HouseFurnishScore._flank_anchor() scans the walls to find it.
	# Leaving it inside the scoring loop made the house suites four times as
	# slow for an answer that never changed.
	var pair_clearance: Callable = func(pos: Vector2, normal: Vector2) -> bool:
		var target_yaw: float = HouseFurnishGeometry.yaw_facing(normal)
		return not _blocks_domestic_threshold(plan, room, key, pos, target_yaw, y, scale)
	var anchor: Dictionary = HouseFurnishScore._flank_anchor(plan, room,
		HouseFurnishScore._widest_of(PropCatalog.category(key)), PropCatalog.category(key),
		pair_clearance) \
		if PropCatalog.affinity(key).has("flank") else {}
	# A two-lamp recipe is a preference for a balanced pair, not permission to
	# put the second lamp on another wall. If this room has no safe mirrored
	# station, keep its already placed useful lamp and record the optional
	# second member as unavailable. A first lamp may still be placed below.
	if lamp and anchor.is_empty() and HouseFurnishingRecipes.is_ordinary_house(plan) \
			and plan.kind_of(room) == &"hall":
		for existing_index in plan.furniture_of(room):
			var existing: Dictionary = plan.furniture[existing_index]
			if bool(existing.get("mounted", false)) \
					and PropCatalog.category(String(existing.get("key", ""))) == "sconce":
				plan.note_compromise(room, "sconce_pair:no_safe_mirrored_station")
				return
	var best_pos := Vector2.ZERO
	var best_yaw := 0.0
	var best_score := -INF
	var best_over_cover := -1.0
	# Every clear stretch of every wall is scored. A shelf wants the wall
	# above the bench it serves and a sconce wants to mirror its mate about
	# the door; neither is findable by trying six positions at random.
	for wi in range(walls.size()):
		var wall: Dictionary = walls[wi]
		var n: Vector2 = wall["normal"]
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		var run: float = (b - a).length()
		var along: Vector2 = (b - a) / maxf(run, 0.01)
		if run < width + 0.4:
			continue
		var lo: float = width / 2.0 + 0.2
		var hi: float = run - width / 2.0 - 0.2
		# Keep the same fixed probe phase as HouseFurnishCheck's availability
		# search. Re-dividing the run into `steps` almost-0.06m intervals can
		# skip a narrow but valid station between two openings (seed 60068 has
		# 4cm of wall where the shelf can cover its workbench).
		var steps: int = maxi(int((hi - lo) / HouseFurnishScore.MOUNT_STEP), 0)
		for s in range(steps + 1):
			var t: float = lo + float(s) * HouseFurnishScore.MOUNT_STEP
			var pos: Vector2 = a + along * t
			if _blocks_domestic_threshold(plan, room, key, pos,
					HouseFurnishGeometry.yaw_facing(n), y, scale):
				continue
			if HouseFurnishScore._on_opening(plan, room, pos, n, width):
				continue
			if HouseFurnishScore._crowds_mounted(plan, room, pos, width):
				continue
			if lamp and _near_lamp(plan, room, pos):
				continue
			var cand := {
				"key": key, "pos": Vector3(pos.x, 0.0, pos.y),
				"yaw": HouseFurnishGeometry.yaw_facing(n), "scale": scale,
				"rect": Rect2(pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
				"host": -1, "mounted": true, "flank_anchor": anchor,
			}
			var score: float = HouseFurnishScore._affinity(plan, room, cand) + r.randf() * HouseFurnishScore.JITTER
			var over_cover := _mounted_over_coverage(plan, room, cand) if shelf else -1.0
			var better_relation := shelf and over_cover > best_over_cover + 0.0001
			var tied_relation := not shelf or absf(over_cover - best_over_cover) <= 0.0001
			if better_relation or (tied_relation and score > best_score):
				best_score = score
				best_over_cover = over_cover
				best_pos = pos
				best_yaw = HouseFurnishGeometry.yaw_facing(n)
	if best_score == -INF:
		return
	plan.furniture.append({
		"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
		"pos": Vector3(best_pos.x, HouseFurnishGeometry.storey_base(plan, room) + y, best_pos.y),
		"yaw": best_yaw,
		"rect": Rect2(best_pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category(key),
		"mounted": true, "scale": scale,
	})


## A shelf's primary job is to hang over the work surface it serves. Rank by
## the mounted model's measured, rotated footprint first; aesthetic affinities
## and seeded jitter only choose between equally useful stations.
static func _mounted_over_coverage(plan: HousePlan, room: int,
		candidate: Dictionary) -> float:
	var wall := HouseFurnishScore._back_wall_index(plan, room,
		Rect2(candidate["rect"]), candidate)
	if wall < 0:
		return 0.0
	var normal: Vector2 = HouseGeometry.room_walls(plan, room)[wall]["normal"]
	var along := Vector2(normal.y, -normal.x)
	var shelf_span := HouseFurnishSpatialCheck.fs_projection(
		Rect2(candidate["rect"]), along, candidate)
	var shelf_width := maxf(shelf_span.y - shelf_span.x, 0.05)
	var best := 0.0
	for index in plan.furniture_of(room):
		var host: Dictionary = plan.furniture[index]
		if PropCatalog.category(String(host["key"])) not in ["workbench", "counter"] \
				or bool(host.get("mounted", false)) or int(host.get("host", -1)) >= 0:
			continue
		if HouseFurnishSpatialCheck.fs_back_wall(plan, room,
				Rect2(host["rect"]), host) != wall:
			continue
		var host_span := HouseFurnishSpatialCheck.fs_projection(
			Rect2(host["rect"]), along, host)
		var host_width := maxf(host_span.y - host_span.x, 0.05)
		var overlap := minf(shelf_span.y, host_span.y) - maxf(shelf_span.x, host_span.x)
		best = maxf(best, clampf(overlap / minf(shelf_width, host_width), 0.0, 1.0))
	return best


## A mount point can miss an opening while the shelf body projects into its
## approach from the adjoining wall. Use the same measured pose as assembly.
static func _blocks_domestic_threshold(plan: HousePlan, room: int, key: String,
		pos: Vector2, yaw: float, y: float, scale: float) -> bool:
	if plan.world_family != &"" or not HousePlanLevels._is_plain_house_spec(plan.spec):
		return false
	var model_yaw := yaw + PropCatalog.face_offset(key)
	var placement := {"key": key, "pos": Vector3(pos.x, y, pos.y),
		"yaw": yaw, "scale": scale}
	var origin := PropCatalog.house_origin(placement)
	var bottom := origin.y + PropCatalog.floor_offset(key) * scale
	var centre := PropCatalog.plan_centre(key, origin, model_yaw, scale)
	var size := PropCatalog.footprint_rotated(key, model_yaw) * scale
	var body := Rect2(centre - size * 0.5, size)
	if bottom < HouseGeometry.FLOOR_T + 2.0:
		for di in plan.doors_of(room):
			for side in [-1.0, 1.0]:
				if body.intersects(HouseGeometry.door_clear_rect(plan.doors[di], side)):
					return true
	var level := plan.storey_of_room(room)
	var world_bottom := bottom + float(level) * plan.spec.height
	for stair in plan.stairs:
		if not bool(stair.get("satisfied", true)):
			continue
		var lower := int(stair.get("storey", 0))
		var upper := int(stair.get("to_storey", lower + 1))
		if level != lower and level != upper:
			continue
		for end in [{"rect": stair.get("foot_landing", Rect2()), "level": lower},
				{"rect": stair.get("head_landing", Rect2()), "level": upper}]:
			var landing_floor := float(end["level"]) * plan.spec.height + HouseGeometry.FLOOR_T
			if body.intersects(Rect2(end["rect"])) and world_bottom < landing_floor + 2.0:
				return true
		var flight := Rect2(stair.get("lower_rect", Rect2()))
		var overlap := body.intersection(flight)
		if not overlap.has_area():
			continue
		var along_x := flight.size.x > flight.size.y
		var run := maxf(flight.size.x, flight.size.y)
		var reach := overlap.end.x - flight.position.x if along_x else overlap.end.y - flight.position.y
		if HouseGeometry.stair_climb(plan, stair) < 0.0:
			reach = flight.end.x - overlap.position.x if along_x else flight.end.y - overlap.position.y
		var steps := maxi(1, int(stair.get("steps", 10)))
		var tread := ceilf(reach / run * float(steps)) / float(steps) * plan.spec.height
		var walking_y := float(lower) * plan.spec.height + HouseGeometry.FLOOR_T + tread
		if world_bottom < walking_y + 2.0:
			return true
	return false


## How close two wall lamps may hang. A third torch thirty-six centimetres
## from the second is not lighting more of the hall, it is a cluster.
const LAMP_SPACING := HouseFurnishScore.FLANK_MIN_PAIR_SEPARATION

static func _near_lamp(plan: HousePlan, room: int, pos: Vector2) -> bool:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if not bool(p.get("mounted", false)) or PropCatalog.category(String(p["key"])) != "sconce":
			continue
		if Vector2(p["pos"].x, p["pos"].z).distance_to(pos) < LAMP_SPACING:
			return true
	return false


static func place_ceiling(plan: HousePlan, room: int, key: String) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	if minf(floor_rect.size.x, floor_rect.size.y) < 2.6:
		return                                   # no room to hang anything
	# The middle of the room, unless there is a table to hang over -- which
	# is what a chandelier is for, and is decided by the same scorer as
	# everything else rather than by a special case here.
	var spots: Array[Vector2] = [floor_rect.get_center()]
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var pc: Vector2 = Rect2(p["rect"]).get_center()
		if floor_rect.grow(0.05).has_point(pc):
			spots.append(pc)
	var c: Vector2 = spots[0]
	var best_score := -INF
	# Ordinary-house chandeliers hang below the slab, with measured standing clearance.
	var scale := 1.0
	var mount_height := plan.spec.height
	if PropCatalog.category(key) == "chandelier" and HouseFurnishingRecipes.is_ordinary_house(plan):
		var highest_storey := 0
		for candidate_room in range(plan.room_count()):
			highest_storey = maxi(highest_storey, plan.storey_of_room(candidate_room))
		if plan.storey_of_room(room) < highest_storey:
			mount_height -= HouseBuilder.SLAB_TUCK
		scale = minf(1.0, (mount_height - HouseGeometry.FLOOR_T - 2.1) / maxf(PropCatalog.height(key), 0.01))
		if scale < 0.1:
			return
	for spot in spots:
		if PropCatalog.category(key) == "chandelier" and HouseFurnishingRecipes.is_ordinary_house(plan):
			var placement := {"key": key,
				"pos": Vector3(spot.x, HouseFurnishGeometry.storey_base(plan, room) + mount_height, spot.y),
				"yaw": 0.0, "scale": scale}
			var origin := PropCatalog.house_origin(placement)
			var model_yaw := PropCatalog.face_offset(key)
			var centre := PropCatalog.plan_centre(key, origin, model_yaw, scale)
			var footprint := PropCatalog.footprint_rotated(key, model_yaw) * scale
			var body := Rect2(centre - footprint * 0.5, footprint)
			if not floor_rect.encloses(body):
				continue
		if _blocks_domestic_threshold(plan, room, key, spot, 0.0, mount_height, scale):
			continue
		var cand := {
			"key": key, "pos": Vector3(spot.x, 0.0, spot.y),
			"rect": Rect2(spot - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
			"host": -1, "mounted": true, "scale": scale,
		}
		var score: float = HouseFurnishScore._affinity(plan, room, cand)
		if score > best_score:
			best_score = score
			c = spot
	if best_score == -INF:
		return
	plan.furniture.append({
		"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
		"pos": Vector3(c.x, HouseFurnishGeometry.storey_base(plan, room) + mount_height, c.y),
		"yaw": 0.0, "rect": Rect2(c - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category(key),
		"mounted": true, "scale": scale,
	})


## A mug, a candle, a stack of books -- set ON something, never on the floor.
static func place_on_surface(plan: HousePlan, room: int, key: String,
		r: RandomNumberGenerator, prefer_row_hosts := false) -> void:
	var hosts: Array[int] = []
	for f in plan.furniture_of(room):
		var host_key: String = plan.furniture[f]["key"]
		if PropCatalog.has_tag(host_key, PropCatalog.SURFACE) \
				and not plan.furniture[f].get("mounted", false):
			hosts.append(f)
	if hosts.is_empty():
		return
	if prefer_row_hosts:
		var row_hosts: Array[int] = []
		for index in hosts:
			if String(plan.furniture[index].get("row", "")) != "":
				row_hosts.append(index)
		if not row_hosts.is_empty():
			hosts = row_hosts
		# Distribute small tools over the eligible benches rather than piling
		# every bottle on the first work surface. A row-only recipe narrows the
		# hosts above; a distributed recipe can use separately placed benches.
		# The stable index tie-break keeps a seeded recipe deterministic.
		hosts.sort_custom(func(a: int, b: int) -> bool:
			var count_a := 0
			var count_b := 0
			for f in plan.furniture_of(room):
				if int(plan.furniture[f].get("host", -1)) == a: count_a += 1
				if int(plan.furniture[f].get("host", -1)) == b: count_b += 1
			if count_a != count_b:
				return count_a < count_b
			return a < b)
	var host: int = hosts[0] if prefer_row_hosts else hosts[r.randi_range(0, hosts.size() - 1)]
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var top: float = float(plan.furniture[host]["pos"].y) \
		+ PropCatalog.surface_height(plan.furniture[host]["key"]) \
		* PropCatalog.placement_height_scale(plan.furniture[host])
	var foot: Vector2 = PropCatalog.footprint(key)
	var margin := 0.06
	var lo := Vector2(host_rect.position.x + foot.x / 2.0 + margin,
		host_rect.position.y + foot.y / 2.0 + margin)
	var hi := Vector2(host_rect.end.x - foot.x / 2.0 - margin,
		host_rect.end.y - foot.y / 2.0 - margin)
	if lo.x > hi.x or lo.y > hi.y:
		return
	for tries in range(10):
		var p := Vector2(lerpf(lo.x, hi.x, r.randf()), lerpf(lo.y, hi.y, r.randf()))
		var rect := Rect2(p - foot / 2.0, foot)
		var clash := false
		for f2 in plan.furniture_of(room):
			if plan.furniture[f2]["host"] != host:
				continue
			if plan.furniture[f2]["rect"].intersects(rect):
				clash = true
				break
		if clash:
			continue
		plan.furniture.append({
			"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
			"pos": Vector3(p.x, top, p.y),
			"yaw": r.randf() * TAU, "rect": rect, "zone": Rect2(), "host": host,
			"cat": PropCatalog.category(key), "mounted": false, "scale": 1.0,
		})
		return
