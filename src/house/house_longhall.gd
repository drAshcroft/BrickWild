class_name HouseLonghall
extends RefCounted
## HS-LONGHALL: the plain `longhall` house is ONE long open hall with a room at
## each end, not a front hall with rooms stacked behind it.
##
##   - the footprint is at least 2.6 times as long as it is wide, one storey,
##     the long side along X (the front door is in the middle of a long wall);
##   - the hall fills the middle and takes the whole depth; a fire burns on its
##     floor, half way along, under a smoke hole in the ridge;
##   - nothing is slung over the hall: no ceiling, the principal trusses and the
##     common rafters are seen from the floor (HouseBuilder._build_longhall_*);
##   - fixed benches run along both long walls; the private rooms (the sleeping
##     room, the store and the work room) stand only at the two ends, each
##     behind a partition that rises to the roof.
## A longhall that carries a trade, or belongs to a shop or a world family, is
## left to the ordinary planner.

const BASE_HOUSE_SPEC := preload("house_spec.gd")
const MIN_RATIO := 2.8
const MIN_SHORT := 5.5
const MAX_SHORT := 8.0
## Kerb of the fire, a square of stones on the floor.
const HEARTH_SIZE := 1.3
const BENCH_DEPTH := 0.55
const BENCH_SEAT_Y := 0.46
## Keep a bench this far from a door's swing and from an end partition.
const BENCH_END_GAP := 0.35
const BENCH_MIN_RUN := 1.2
const SMOKE_ACROSS := 1.1
const SMOKE_ALONG := 1.7
## The louvre over the smoke hole stands this far above the ridge line.
const LOUVRE_TOP := 1.05
const HOOD_TILT := 0.42
const HOOD_W := 1.15
const HOOD_T := 0.07
const BENCH_KEY := "Bench"


static func applies(spec: HouseSpec, world_family: StringName = &"") -> bool:
	return spec != null and spec.style == &"longhall" \
		and spec.get_script() == BASE_HOUSE_SPEC and spec.trade == &"none" \
		and world_family == &"" \
		and not spec.has_method("room_program") and not spec.has_method("custom_room_rects") \
		and not spec.has_method("landmark_footprint")


static func plan_applies(plan: HousePlan) -> bool:
	return plan != null and not plan.longhall.is_empty()


## Bring a request to a longhall's proportions: one storey, the long side on X,
## at least MIN_RATIO to one (2.8: the trait asks for 2.5). The long side is never shortened below what was
## asked for; a short side that is too fat is narrowed first, then the long
## side is lengthened. Pure arithmetic: no random draw.
static func clamp_size(spec: HouseSpec) -> void:
	if not applies(spec):
		return
	var long_side := maxf(spec.width, spec.length)
	var short_side := minf(spec.width, spec.length)
	short_side = clampf(minf(short_side, long_side / MIN_RATIO), MIN_SHORT, MAX_SHORT)
	long_side = maxf(long_side, short_side * MIN_RATIO)
	spec.width = long_side
	spec.length = short_side
	spec.storeys = 1
	spec.cellars = 0


## The rooms, tiled exactly over the interior. Returns false (and adds nothing)
## when the interior cannot hold a hall between two end rooms.
static func layout(p: HousePlan, spec: HouseSpec) -> bool:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	if inner.size.x < inner.size.y * 2.0:
		return false
	var mirror: bool = posmod(spec.seed, 2) == 1

	var sleep_w := clampf(inner.size.x * 0.24, 3.6, 4.8)
	var work_w := clampf(inner.size.x * 0.22, 3.6, 4.4)
	var hall_w := inner.size.x - sleep_w - work_w
	if hall_w < 6.0:
		return false
	var x0 := inner.position.x
	var west_w := work_w if mirror else sleep_w
	var east_w := sleep_w if mirror else work_w
	var rows: Array[Dictionary] = []
	rows.append(_row(&"hall", Rect2(x0 + west_w, inner.position.y, hall_w, inner.size.y)))
	var west := Rect2(x0, inner.position.y, west_w, inner.size.y)
	var east := Rect2(inner.end.x - east_w, inner.position.y, east_w, inner.size.y)
	var sleep_rect: Rect2 = east if mirror else west
	var work_rect: Rect2 = west if mirror else east
	rows.append(_row(&"bedroom", sleep_rect))
	# The work end is split front and back: the work room on the lit front wall,
	# the store behind it.
	var front_d := inner.size.y * 0.56
	rows.append(_row(&"workshop", Rect2(work_rect.position, Vector2(work_rect.size.x, front_d))))
	rows.append(_row(&"store", Rect2(work_rect.position + Vector2(0.0, front_d),
		Vector2(work_rect.size.x, work_rect.size.y - front_d))))
	var tiled := 0.0
	for row in rows:
		tiled += Rect2(row["rect"]).get_area()
		p.rooms.append(row)
	var fits := absf(tiled - inner.get_area()) < 0.05
	for i in range(rows.size()):
		fits = fits and HouseGeometry.room_suits(p, i, rows[i]["kind"]) \
			and HouseGeometry.room_aspect(p, i) <= HouseGeometry.aspect_max(rows[i]["kind"])
	if not fits:
		for _i in rows.size():
			p.rooms.pop_back()
		return false
	p.domestic_layout = {
		"status": &"planned", "style": spec.style, "requested_rooms": maxi(spec.room_count, 1),
		"planned_rooms": rows.size(),
		"ground_activities": [&"hall", &"bedroom", &"workshop", &"store"],
		"merged_activities": [&"kitchen"], "capacity_expanded": false, "omitted_rooms": 0,
		"omitted_activities": [], "rejected_candidates": [], "reason": "",
		"mirror": mirror, "hall_role": &"communal_hall", "shared_cooking": true,
		"longhall": true,
	}
	return true


static func _row(kind: StringName, rect: Rect2) -> Dictionary:
	if kind == &"hall":
		var functions: Array[StringName] = [&"entry", &"circulation", &"dining",
			&"common_living", &"cooking"]
		return {"kind": kind, "rect": rect, "storey": 0, "domestic_role": &"communal_hall",
			"domestic_functions": functions, "meal_room": true, "shared_cooking": true,
			"domestic_layout_storey": 0}
	var role := HousePlanRooms._activity_role(kind)
	return {"kind": kind, "rect": rect, "storey": 0, "domestic_role": role,
		"domestic_functions": [role], "domestic_layout_storey": 0}


## After the doors and windows are fitted: the fire, the smoke hole and the
## benches, written to `plan.longhall`. Keep-clear zones (the fire's, and each
## bench's) go to `plan.zones` so the furnisher leaves them alone. The wall
## hearth and its focus are cancelled: this hall has no fireplace in a wall.
static func prepare(p: HousePlan, spec: HouseSpec) -> void:
	p.longhall = {}
	if not applies(spec, p.world_family) or not bool(p.domestic_layout.get("longhall", false)):
		return
	var halls := p.rooms_of(&"hall")
	if halls.is_empty():
		return
	var hall: int = halls[0]
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(p, hall)
	p.hearth = {}
	p.focus = {}
	spec.chimney = false
	spec.dormers = false
	var centre := floor_rect.get_center()
	var kerb := Rect2(centre - Vector2.ONE * HEARTH_SIZE * 0.5, Vector2.ONE * HEARTH_SIZE)
	var ends: Array[int] = []
	for i in range(p.rooms.size()):
		if i != hall:
			ends.append(i)
	var benches: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var line := floor_rect.position.y if side < 0.0 else floor_rect.end.y
		var normal := Vector2(0.0, -side)
		var blocked: Array[Vector2] = []
		var strip := Rect2(floor_rect.position.x, line if side < 0.0 else line - BENCH_DEPTH,
			floor_rect.size.x, BENCH_DEPTH)
		for d in p.doors_of(hall):
			var door: Dictionary = p.doors[d]
			# The floor a door needs, on either side of it, is no place for a bench.
			for door_side in [-1.0, 1.0]:
				var clear := HouseGeometry.door_clear_rect(door, door_side).grow(0.05)
				if clear.intersects(strip):
					blocked.append(Vector2(clear.position.x, clear.end.x))
		var lo := floor_rect.position.x + BENCH_END_GAP
		var hi := floor_rect.end.x - BENCH_END_GAP
		for run in _free_runs(lo, hi, blocked):
			if run.y - run.x < BENCH_MIN_RUN:
				continue
			var rect := Rect2(run.x, line if side < 0.0 else line - BENCH_DEPTH,
				run.y - run.x, BENCH_DEPTH)
			benches.append({"wall": 0 if side < 0.0 else 1, "rect": rect,
				"normal": normal})
			p.zones.append({"room": hall, "rect": rect, "why": "hall bench"})
	var smoke_zone := kerb.grow(0.45)
	p.zones.append({"room": hall, "rect": smoke_zone, "why": "open hearth"})
	p.longhall = {"room": hall, "hearth": kerb, "benches": benches, "ends": ends,
		"smoke": centre}


static func _free_runs(lo: float, hi: float, blocked: Array[Vector2]) -> Array[Vector2]:
	var runs: Array[Vector2] = [Vector2(lo, hi)]
	for cut in blocked:
		var next: Array[Vector2] = []
		for r in runs:
			if cut.y <= r.x or cut.x >= r.y:
				next.append(r)
				continue
			if cut.x > r.x:
				next.append(Vector2(r.x, cut.x))
			if cut.y < r.y:
				next.append(Vector2(cut.y, r.y))
		runs = next
	return runs


## How far the tilted hood slab reaches above its own centre.
static func hood_extent() -> float:
	return HOOD_W * 0.5 * sin(HOOD_TILT) + HOOD_T * 0.5 * cos(HOOD_TILT)


## After the furnisher: the benches, as real Bench props, one or more to each
## free run along a long wall of the hall, seats toward the fire. Their keep-clear
## strips in `plan.zones` are lifted first (a bench IS the thing the strip kept
## the floor for).
static func seat(plan: HousePlan) -> void:
	if not plan_applies(plan):
		return
	for i in range(plan.zones.size() - 1, -1, -1):
		if String(plan.zones[i].get("why", "")) == "hall bench":
			plan.zones.remove_at(i)
	var hall := int(plan.longhall["room"])
	# Nothing hangs from the open roof: a chandelier needs a ceiling to hang from.
	for i in range(plan.furniture.size() - 1, -1, -1):
		if int(plan.furniture[i].get("room", -1)) == hall 				and String(plan.furniture[i].get("key", "")) == "Chandelier":
			plan.furniture.remove_at(i)
			# `host` and `support` rows are indices into the list: close the gap.
			for item in plan.furniture:
				for field in ["host"]:
					var h := int(item.get(field, -1))
					if h == i:
						item[field] = -1
					elif h > i:
						item[field] = h - 1
	var blocked: Array[Rect2] = []
	var zones: Array[Rect2] = []
	var foot := PropCatalog.footprint(BENCH_KEY)
	var placed: Array[Dictionary] = []
	for b in plan.longhall["benches"]:
		var rect: Rect2 = b["rect"]
		var n: Vector2 = b["normal"]
		var count := 0
		var best := INF
		for c in [maxi(1, int(floor(rect.size.x / foot.x))), maxi(1, int(ceil(rect.size.x / foot.x)))]:
			var s: float = rect.size.x / (float(c) * foot.x)
			if s >= 0.82 and s <= 1.2 and absf(s - 1.0) < best:
				best = absf(s - 1.0)
				count = c
		if count == 0:
			continue
		var scale := rect.size.x / (float(count) * foot.x)
		var depth := foot.y * scale
		var wall_y := rect.position.y if n.y > 0.0 else rect.end.y
		for k in range(count):
			var cx := rect.position.x + (float(k) + 0.5) * foot.x * scale
			var cand := HouseFurnishGeometry.candidate(BENCH_KEY,
				Vector2(cx, wall_y + n.y * depth * 0.5), HouseFurnishGeometry.yaw_facing(n),
				1.0, scale)
			cand["zone"] = Rect2()
			cand["zone_strip"] = PackedVector2Array()
			cand["longhall_bench"] = int(b["wall"])
			HouseFurnishGeometry.commit(plan, hall, cand, blocked, zones)
			placed.append({"wall": int(b["wall"]), "rect": cand["rect"]})
	plan.longhall["placed_benches"] = placed


## The smoke hole as a roof opening, in the roof's own local XZ frame. Derived
## each call (never cached: see HousePlan.roof_openings). `xf` is
## HouseGeometry.roof_layout(plan)["transform"].
static func smoke_opening(plan: HousePlan, xf: Transform3D) -> Dictionary:
	if not plan_applies(plan):
		return {}
	var w: Vector2 = plan.longhall["smoke"]
	var local := xf.affine_inverse() * Vector3(w.x, 0.0, w.y)
	var rect := Rect2(local.x - SMOKE_ACROSS * 0.5, local.z - SMOKE_ALONG * 0.5,
		SMOKE_ACROSS, SMOKE_ALONG)
	return {"id": "longhall_smoke_hole", "kind": &"open",
		"storey": 0, "face": -1, "room": int(plan.longhall["room"]),
		"polygon": Poly.from_rect(rect)}
