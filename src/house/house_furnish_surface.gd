class_name HouseFurnishSurface
extends RefCounted

# Mounted, ceiling, and hosted surface placements.

## How far the foot of a hanging piece (a banner) clears the floor.
const HANG_CLEAR := 0.45
const ACTIVITY_TASK_LIGHT_REACH := 1.9

## A shelf, rack or sconce on a wall, above the furniture already there.
static func place_mounted(plan: HousePlan, room: int, key: String,
		r: RandomNumberGenerator, activity_group := "") -> void:
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
	var compact_witch_work: bool = HouseFurnishingRecipes.is_ordinary_house(plan) \
			and plan.spec.style == &"witch_hut" and plan.spec.trade == &"none" \
			and bool(plan.rooms[room].get("shared_witchwork", false)) \
			and plan.rooms[room].get("activity_regions", {}).has(&"witchwork") \
			and activity_group == "witchwork"
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
					and PropCatalog.category(String(existing.get("key", ""))) == "sconce" \
					and (not compact_witch_work or String(existing.get("activity_group", "")) == activity_group):
				plan.note_compromise(room, "sconce_pair:no_safe_mirrored_station")
				return
	var best_pos := Vector2.ZERO
	var best_yaw := 0.0
	var best_score := -INF
	var best_task_light_score := -INF
	var best_task_light_pos := Vector3.ZERO
	var best_task_light_yaw := 0.0
	var best_task_light_pose: Dictionary = {}
	var best_mount_pose: Dictionary = {}
	var task_prep_zones: Array[Dictionary] = []
	var best_task_light_rank := 100
	var best_over_cover := -1.0
	# First ordinary-house lamps serve measured cooking or sleep tasks. Existing and later lamps keep flank-pair scoring.
	if lamp and plan.spec.trade == &"none" and HouseFurnishingRecipes.is_ordinary_house(plan):
		var has_existing_lamp := false
		for existing_index in plan.furniture_of(room):
			var existing: Dictionary = plan.furniture[existing_index]
			if bool(existing.get("mounted", false)) \
					and PropCatalog.category(String(existing.get("key", ""))) == "sconce" \
					and (not compact_witch_work or String(existing.get("activity_group", "")) == activity_group):
				has_existing_lamp = true
				break
		if not has_existing_lamp:
			for existing_index in plan.furniture_of(room):
				var existing: Dictionary = plan.furniture[existing_index]
				if String(existing.get("activity_group", "")) == ("witchwork" if compact_witch_work else "cooking") \
						and String(existing.get("cat", "")) == "workbench":
					var prep := Rect2(existing.get("zone", Rect2()))
					if not prep.has_area(): prep = Rect2(existing.get("rect", Rect2()))
					if prep.has_area(): task_prep_zones.append({"rank": 0, "rect": prep, "source": existing_index})
					break
			if task_prep_zones.is_empty() and plan.kind_of(room) == &"bedroom":
				var sleep_targets: Array[Dictionary] = []
				for existing_index in plan.furniture_of(room):
					var existing: Dictionary = plan.furniture[existing_index]
					if String(existing.get("activity_group", "")) != "sleep": continue
					var category := String(existing.get("cat", PropCatalog.category(String(existing.get("key", "")))))
					var key_name := String(existing.get("key", ""))
					var rank := 100
					if key_name == "Nightstand_Shelf": rank = 0
					elif category == "chest" and String(existing.get("activity_host_anchor", "")) != "head_end": rank = 1
					elif category == "bed": rank = 2
					if rank >= 100: continue
					var prep := Rect2(existing.get("zone", Rect2()))
					if not prep.has_area(): prep = Rect2(existing.get("rect", Rect2()))
					if prep.has_area(): sleep_targets.append({"rank": rank, "rect": prep, "source": existing_index})
				sleep_targets.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
					if int(left["rank"]) != int(right["rank"]): return int(left["rank"]) < int(right["rank"])
					return int(left["source"]) < int(right["source"]))
				task_prep_zones = sleep_targets
	if lamp and compact_witch_work and task_prep_zones.is_empty():
		return
	var task_light_clear_spans: Dictionary = {}
	if not task_prep_zones.is_empty():
		for wi in range(walls.size()):
			var wall: Dictionary = walls[wi]
			var model_yaw := HouseFurnishGeometry.yaw_facing(wall["normal"]) + PropCatalog.face_offset(key)
			var dimensions := PropCatalog.footprint_rotated(key, model_yaw) * scale
			var horizontal := absf(Vector2(wall["normal"]).y) > 0.5
			var body_depth := dimensions.y if horizontal else dimensions.x
			task_light_clear_spans[wi] = HousePlanFeatures.clear_wall_spans(plan, room, wi, body_depth)
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
			var mount_yaw := HouseFurnishGeometry.yaw_facing(n)
			var wall_along := pos.x if absf(n.y) > 0.5 else pos.y
			var mount_pose := HousePlanFeatures._wall_fixture_pose(key, wall, wall_along,
				HouseFurnishGeometry.storey_base(plan, room) + y, scale)
			var mount_body: Rect2 = Rect2(mount_pose["rect"])
			if compact_witch_work:
				var activity_regions: Dictionary = plan.rooms[room].get("activity_regions", {})
				var mounted_inside_floor := mount_body.intersection(HouseGeometry.room_floor_rect(plan, room))
				if not activity_regions.has(StringName(activity_group)) \
						or not mounted_inside_floor.has_area() \
						or not Rect2(activity_regions[StringName(activity_group)]).grow(0.01).encloses(mounted_inside_floor):
					continue
			var cand := {
				"key": key, "pos": Vector3(pos.x, 0.0, pos.y),
				"yaw": HouseFurnishGeometry.yaw_facing(n), "scale": scale,
				"rect": mount_body if compact_witch_work else Rect2(pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
				"host": -1, "mounted": true, "flank_anchor": anchor,
			}
			var score: float = HouseFurnishScore._affinity(plan, room, cand) + r.randf() * HouseFurnishScore.JITTER
			if not task_prep_zones.is_empty():
				var base := HouseFurnishGeometry.storey_base(plan, room)
				var pose := mount_pose
				var body_rect: Rect2 = pose["rect"]
				var candidate_task_rank := 100
				for task_variant in task_prep_zones:
					var task: Dictionary = task_variant
					if HousePlanFeatures._rect_distance(body_rect, Rect2(task["rect"])) <= ACTIVITY_TASK_LIGHT_REACH:
						candidate_task_rank = mini(candidate_task_rank, int(task["rank"]))
				if candidate_task_rank < 100:
					var floor_y := base + HouseGeometry.FLOOR_T
					var ceiling_y := base + plan.spec.height - HouseGeometry.FLOOR_T - 0.03
					var body_bottom := float(pose["bottom"])
					var body_top := float(pose["top"])
					var task_pose_clear := body_bottom >= floor_y + 0.9 and body_top <= ceiling_y \
							and HousePlanFeatures._wall_mount_clear_of_furniture(plan, room,
								body_rect, body_bottom, body_top)
					var horizontal := absf(n.y) > 0.5
					var body_lo := body_rect.position.x if horizontal else body_rect.position.y
					var body_hi := body_rect.end.x if horizontal else body_rect.end.y
					var fits_clear_wall_span := false
					for span_variant in task_light_clear_spans.get(wi, []):
						var span: Vector2 = span_variant
						if body_lo >= span.x - 0.01 and body_hi <= span.y + 0.01:
							fits_clear_wall_span = true
							break
					task_pose_clear = task_pose_clear and fits_clear_wall_span
					for zone_variant in plan.zones:
						var zone: Dictionary = zone_variant
						if int(zone.get("room", -1)) == room \
								and String(zone.get("why", "")) in ["stair access route", "stair foot landing", "stair head landing"] \
								and body_rect.intersects(Rect2(zone.get("rect", Rect2()))):
							task_pose_clear = false
					if task_pose_clear and (candidate_task_rank < best_task_light_rank \
							or (candidate_task_rank == best_task_light_rank and score > best_task_light_score)):
						best_task_light_rank = candidate_task_rank
						best_task_light_score = score
						best_task_light_pos = Vector3(pose["pos"])
						best_task_light_yaw = float(pose["yaw"])
						best_task_light_pose = pose.duplicate(true)
			var over_cover := _mounted_over_coverage(plan, room, cand) if shelf else -1.0
			var better_relation := shelf and over_cover > best_over_cover + 0.0001
			var tied_relation := not shelf or absf(over_cover - best_over_cover) <= 0.0001
			if better_relation or (tied_relation and score > best_score):
				best_score = score
				best_over_cover = over_cover
				best_pos = pos
				best_yaw = mount_yaw
				best_mount_pose = mount_pose.duplicate(true)
	if lamp and compact_witch_work and best_task_light_pose.is_empty():
		return
	if best_task_light_score > -INF:
		best_pos = Vector2(best_task_light_pos.x, best_task_light_pos.z)
		best_yaw = best_task_light_yaw
		best_score = best_task_light_score
	if best_score == -INF:
		return
	var committed_position := Vector3(best_pos.x, HouseFurnishGeometry.storey_base(plan, room) + y, best_pos.y)
	var committed_rect: Rect2 = Rect2(best_mount_pose.get("rect", Rect2(best_pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1))) if compact_witch_work else Rect2(best_pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1)
	if not best_task_light_pose.is_empty() and best_task_light_score > -INF:
		committed_position = Vector3(best_task_light_pose["pos"])
		best_yaw = float(best_task_light_pose["yaw"])
		if compact_witch_work:
			committed_rect = Rect2(best_task_light_pose["rect"])
	plan.furniture.append({
		"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
		"pos": committed_position,
		"yaw": best_yaw,
		"rect": committed_rect,
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
