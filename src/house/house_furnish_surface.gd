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
	# Worked out once, not once per candidate: where a pair of these hangs is
	# a fact about the room, and HouseFurnishScore._flank_anchor() scans the walls to find it.
	# Leaving it inside the scoring loop made the house suites four times as
	# slow for an answer that never changed.
	var anchor: Dictionary = HouseFurnishScore._flank_anchor(plan, room,
		HouseFurnishScore._widest_of(PropCatalog.category(key)), PropCatalog.category(key)) \
		if PropCatalog.affinity(key).has("flank") else {}
	var best_pos := Vector2.ZERO
	var best_yaw := 0.0
	var best_score := -INF
	var lamp := PropCatalog.category(key) == "sconce"
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
			if score > best_score:
				best_score = score
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


## How close two wall lamps may hang. A third torch thirty-six centimetres
## from the second is not lighting more of the hall, it is a cluster.
const LAMP_SPACING := 0.85  # under the narrowest pair station (FS_PAIR_MIN 0.9)

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
	for spot in spots:
		var cand := {
			"key": key, "pos": Vector3(spot.x, 0.0, spot.y),
			"rect": Rect2(spot - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
			"host": -1, "mounted": true,
		}
		var score: float = HouseFurnishScore._affinity(plan, room, cand)
		if score > best_score:
			best_score = score
			c = spot
	plan.furniture.append({
		"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
		"pos": Vector3(c.x, HouseFurnishGeometry.storey_base(plan, room) + plan.spec.height, c.y),
		"yaw": 0.0, "rect": Rect2(c - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category(key),
		"mounted": true, "scale": 1.0,
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
		* float(plan.furniture[host].get("scale", 1.0))
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
