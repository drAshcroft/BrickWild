class_name CastleKeepPlan
extends RefCounted
## The occupied keep and its outer silhouette share these polygons. Rooms,
## openings, stairs and furniture are all planned on the clear inner faces.

const SIDES := 14
const TOP_SCALE := 0.62
const MIN_TOP_SIDE := 6.4
const COMPACT_FACET_JAMB := 0.25
const COMPACT_FACET_WINDOW_MIN := 0.3


static func outer_outline(spec: CastleSpec, level: int, levels: int) -> PackedVector2Array:
	var box := CastleGeometry.keep_aabb(spec)
	var side := minf(box.size.x, box.size.z)
	if spec.keep_shape in [&"round", &"shell"]:
		var poly := PackedVector2Array()
		for i in range(SIDES):
			var angle := TAU * float(i) / float(SIDES)
			poly.append(Vector2(cos(angle), sin(angle)) * side * 0.5)
		return poly
	if spec.keep_shape == &"tiered":
		var top := maxf(side * TOP_SCALE, minf(side, MIN_TOP_SIDE))
		var width := lerpf(side, top, float(level) / float(maxi(levels - 1, 1)))
		return Poly.from_rect(Rect2(Vector2.ONE * -width * 0.5, Vector2.ONE * width))
	return Poly.from_rect(Rect2(Vector2(-box.size.x, -box.size.z) * 0.5,
		Vector2(box.size.x, box.size.z)))


## Access geometry asks for a structural plan only. Furnishing the same large
## keep for every forebuilding query repeats measured placement to learn one
## doorway. CastleInteriors.primary adds the minimum programme to the one
## occupied plan that is actually emitted.
static func generate(spec: CastleSpec, with_furniture := true) -> HousePlan:
	var plan := HousePlan.new()
	if not spec.keep or CastleGeometry.is_motte(spec):
		return plan
	var box := CastleGeometry.keep_aabb(spec)
	if minf(box.size.x, box.size.z) <= 0.0:
		return plan
	var levels := clampi(int(box.size.y / CastleInteriorPlans.KEEP_STOREY_H), 3,
		HouseGeometry.MAX_STOREYS)
	var hs := CastleInteriorPlans._keep_spec(spec, box, levels)
	var shaped := spec.keep_shape in [&"round", &"shell", &"tiered"]
	hs.porch = false
	hs.chimney = false # The castle owns flues and roof joins.
	hs.exterior_props = false
	var floor_rect := HouseGeometry.interior_rect(hs)
	if minf(floor_rect.size.x, floor_rect.size.y) < CastleInteriorPlans.MIN_KEEP_SIDE \
			or floor_rect.get_area() < CastleInteriorPlans.MIN_KEEP_AREA \
			or maxf(floor_rect.size.x, floor_rect.size.y) > CastleInteriorPlans.MAX_KEEP_SIDE:
		return plan
	plan.spec = hs
	for level in range(levels):
		var room := {"kind": hs.kind_on(level), "rect": floor_rect, "storey": level}
		if shaped:
			var outer := outer_outline(spec, level, levels)
			# The shapes are regular convex polygons: a radial inset preserves
			# exactly one edge per outside face instead of rounding the corners.
			var inset := HouseGeometry.wall_thickness(hs)
			var scale := 1.0
			if spec.keep_shape in [&"round", &"shell"]:
				scale -= inset / (minf(box.size.x, box.size.z) * 0.5 * cos(PI / SIDES))
			else:
				scale -= 2.0 * inset / Poly.bounding_rect(outer).size.x
			var clear := PackedVector2Array()
			for point in outer:
				clear.append(point * scale)
			room.outline = clear
			room.rect = Poly.bounding_rect(clear)
		plan.rooms.append(room)
	for room_index in range(plan.room_count()):
		if not HouseGeometry.room_suits(plan, room_index, plan.kind_of(room_index)):
			return HousePlan.new()
	var entry_level := 1 if CastleGeometry.is_enclosed(spec) \
		and spec.plan_kind != &"terraced" and not spec.terraced_fallback else 0
	hs.entry_storey = entry_level
	var walls := HouseGeometry.room_walls(plan, entry_level)
	var entry_inward := Vector2(-1, 0) if spec.plan_kind == &"bergfried" \
		else (Vector2(1, 0) if spec.plan_kind == &"terraced" else Vector2(0, 1))
	var front := _facing_wall(walls, entry_inward)
	var front_wall: Dictionary = walls[front]
	plan.doors.append({"a": entry_level, "b": -1,
		"pos": (Vector2(front_wall.from) + Vector2(front_wall.to)) * 0.5,
		"normal": -Vector2(front_wall.normal), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": entry_level,
		"sill": HouseGeometry.FLOOR_T, "head": 2.35})
	for level in range(1, levels):
		if not HouseGeometry.is_habitable(hs.kind_on(level)):
			continue
		if shaped:
			_windows(plan, level)
		else:
			CastleInteriorPlans._keep_windows(plan, floor_rect, level, hs,
				3 if hs.kind_on(level) == &"lords_chamber" else -1)
	# The raised entrance owns its opening interval on this wall. Other
	# facets retain daylight, including on receding and circular keeps.
	var door: Dictionary = plan.doors[0]
	plan.windows = plan.windows.filter(func(w): return HousePlan.record_storey(w) != entry_level \
		or Vector2(w.normal).dot(door.normal) < 0.95 \
		or Vector2(w.pos).distance_to(door.pos) > (float(w.width) + float(door.width)) * 0.5 + 0.35)
	for level in range(levels - 1):
		if shaped:
			_add_stair(plan, level, level + 1)
		else:
			var before := plan.stairs.size()
			HousePlanLevels.add_stair(plan, level, level + 1, level, level + 1)
			# The house planner can leave a slender keep's flight climbing into
			# the far wall; this planner knows to land its walker on floor.
			if plan.stairs.size() == before + 1 and _climbs_into_wall(plan, plan.stairs[-1]):
				var kept: Dictionary = plan.stairs.pop_back()
				var hard: Array[PackedVector2Array] = []
				# the flight that starts on the doorway's storey leaves it clear
				if level == entry_level:
					hard.append(_door_footprint(plan.doors[0]))
				var count := plan.stairs.size()
				_add_stair(plan, level, level + 1, Rect2(), hard)
				if plan.stairs.size() == count:
					plan.stairs.append(kept)
	var top_walls := HouseGeometry.room_walls(plan, levels - 1)
	plan.hearth = {"room": levels - 1, "wall": _facing_wall(top_walls, Vector2(1, 0))}
	if with_furniture:
		CastleRoomTopUp.furnish(plan, hs)
	return plan


## Fortress rooms are deliberately kept out of the full decorative search.
## They still receive the small set of props that makes their room names true.
## HouseFurnishPlacement applies the same measured footprints, access zones,
## wall rules and collision checks as the ordinary furnisher, with a fixed seed
## and at most one placement attempt per required category.
## Rooms wider than this furnish their guardroom table against a wall.
const WIDE_ROOM_AREA := 24.0

## What a watch room keeps: somewhere to sit the watch, the arms rack, the
## post's stores and a light. Placed under the ordinary rules, with the room's
## own door, stair and window reservations.
const WATCH_ROOM := [
	{"cat": "bench", "rule": &"wall"},
	{"cat": "stand", "key": "WeaponStand", "rule": &"wall"},
	{"cat": "chest", "rule": &"wall"},
	{"cat": "storage", "rule": &"wall"},
	{"cat": "sconce", "rule": &"mounted"},
]


static func furnish_minimum_programme(plan: HousePlan, spec: HouseSpec) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.seed) ^ 0x4B_45_45_50
	for room in range(plan.room_count()):
		var kind: StringName = plan.kind_of(room)
		var required: Array = HouseFurnishCheck.REQUIRED.get(kind, [])
		if kind == &"hall" and not HouseFurnishProgrammeCheck._anybody_sleeps(plan):
			required = required + ["bed"]
		var blocked: Array[Rect2] = HouseFurnishPlacement.initial_blocked(plan, room)
		var zones: Array[Rect2] = []
		for cat_value in required:
			var cat := String(cat_value)
			var rule: StringName = &"wall" if cat in HouseFurnishPlacement.WALL_ESSENTIAL else &"free"
			# The free-floor hunt probes the room on a grid and costs seconds in
			# a wide tower room. A guardroom's table against a wall is as true to
			# the room, and the wall search is linear in its perimeter.
			var wide := HouseGeometry.room_floor_rect(plan, room).get_area() > WIDE_ROOM_AREA
			if kind == &"guardroom" and cat == "table" and wide:
				rule = &"wall"
			HouseFurnishPlacement.place_one(plan, spec, room, cat, rule,
				blocked, zones, rng, {"opt": 1.0})
		# The shared programme check requires somewhere to sit when a hall has a
		# table. This deterministic single seat fulfils that contract.
		if kind == &"hall" or kind == &"parlour":
			var has_table := false
			var has_seat := false
			for index in plan.furniture_of(room):
				var placed: Dictionary = plan.furniture[index]
				var category := PropCatalog.category(String(placed["key"]))
				has_table = has_table or category == "table"
				has_seat = has_seat or category in ["seat", "bench"]
			if has_table and not has_seat:
				HouseFurnishPlacement.place_one(plan, spec, room, "seat", &"around",
					blocked, zones, rng, {"opt": 1.0})
	# The minimum names each room truly; the walk QA also wants its tables laid
	# for two and a large room not left bare. CastleRoomTopUp does both under
	# the same placement rules, keeping only what leaves a room no worse.
	CastleRoomTopUp.apply(plan, spec)
	# A table nobody can sit at is not a dining table. A mural tower's storey
	# often cannot take one -- the stair owns the long side a chair is drawn up
	# to -- so the post becomes the watch room it is. Measured from the
	# placements above, not guessed from the floor area.
	_demote_unseated_guardrooms(plan, spec)


## A guardroom whose table holds nobody has an unusable table in it: an 11.8 m2
## tower storey with a stair across it takes a 2.85 m table but no chair beside
## it. Plan the post as a watch room instead -- a bench, an arms rack, stores
## and a light, and no dining table -- and say so in the room's own kind, so the
## programme, sparse, lamp and seat rules all judge what the room really is.
static func _demote_unseated_guardrooms(plan: HousePlan, spec: HouseSpec) -> void:
	for room in range(plan.room_count()):
		if plan.kind_of(room) != &"guardroom":
			continue
		var table := -1
		for index in plan.furniture_of(room):
			var piece: Dictionary = plan.furniture[index]
			if PropCatalog.category(String(piece["key"])) == "table" \
					and not bool(piece.get("mounted", false)) \
					and String(piece.get("row", "")) == "":
				table = index
				break
		# A trestle row seats itself with benches and is judged elsewhere. A
		# table seats two where the walker needs the floor goes too: a 4.7 m
		# tower storey is a landing between two flights, and a table with its
		# chairs across it leaves 0.5 m to squeeze past (CASTLE-FURNISH-WALK).
		if table < 0 or (CastleRoomTopUp._holds_at(plan, room, table) >= 2
				and not walkway_blockers(plan, room).has(table)):
			continue
		# Take the table and the one chair that came with it out of the room.
		# A seat's host index can be stale by now (earlier removals shift the
		# list), so every seat drawn up to this room's one table goes with it:
		# a chair left standing with no table is the "seating" fault.
		var mine := plan.furniture_of(room)
		var leaving: Array[Dictionary] = []
		for index in range(plan.furniture.size()):
			var piece: Dictionary = plan.furniture[index]
			var hosted_seat: bool = mine.has(index) and int(piece.get("host", -1)) >= 0 					and PropCatalog.category(String(piece["key"])) == "seat"
			if index == table or int(piece.get("host", -1)) == table or hosted_seat:
				leaving.append(piece)
		# One at a time, renumbering the host index of every piece after it: a
		# bare remove_at left other rooms' seats pointing at the wrong table, or
		# past the end of the list (the checks threw at seats 49 and 50).
		for piece in leaving:
			var at := -1
			for index in range(plan.furniture.size()):
				if is_same(plan.furniture[index], piece):
					at = index
					break
			if at >= 0:
				plan.furniture.remove_at(at)
				HouseFurnishRepair.reindex_hosts(plan, at)
		plan.rooms[room]["kind"] = &"watch_room"
		if room < spec.program.size() and spec.program[room] == &"guardroom":
			spec.program[room] = &"watch_room"
		# A guardroom may hang an outdoor lantern; a watch room may not (the
		# arrangement rule calls it an outdoor fitting in a domestic room), so
		# what does not suit the post comes out and the post is dressed afresh.
		var unsuited: Array[int] = []
		for index in plan.furniture_of(room):
			if not PropCatalog.suits_room(String(plan.furniture[index]["key"]), &"watch_room"):
				unsuited.append(index)
		unsuited.reverse()
		for index in unsuited:
			plan.furniture.remove_at(index)
			HouseFurnishRepair.reindex_hosts(plan, index)
		_dress_watch_room(plan, spec, room)
		# whatever still stands on the walkway between the flights goes
		var in_the_way := walkway_blockers(plan, room)
		in_the_way.sort()
		in_the_way.reverse()
		for index in in_the_way:
			plan.furniture.remove_at(index)
			HouseFurnishRepair.reindex_hosts(plan, index)
		# A storey the stair takes whole has no wall for a bench. It is not a
		# watch room then, but the store the stair leaves it as.
		var benched := false
		for index in plan.furniture_of(room):
			benched = benched or PropCatalog.category(String(plan.furniture[index]["key"])) == "bench"
		if not benched:
			plan.rooms[room]["kind"] = &"store"
			if room < spec.program.size():
				spec.program[room] = &"store"


## How much of each end of a walkway is left to the wall: a flight's landing
## sits against the wall and its bench or chest is meant to be there.
const PITCH_TARGET := 41.0   # degrees; HouseStairCheck.PITCH_MAX is 42
const MIN_RUN := 2.4
const SHORT_RUNS: Array[float] = [2.0, 1.6]
## What a long flight needs of its room besides the run: the head landing and a
## foot to stand on. The plan check asks the same of the room it judges.
const LANDING_ALLOWANCE := 1.3
const WALKABLE_RISER := 0.2
const WALKWAY_ENDS := 0.6
## Half a person, and a little: what must stay clear either side of the line.
const WALKWAY_HALF := 0.4
## A room wider than this has floor to walk round a table on; only the tight
## ones (a tower storey, 4.7 m across) make the straight way the only way.
const WALKWAY_ROOM_MAX := 6.0


## The pieces of floor furniture standing on the way a person takes through a
## room: from where the flight below lets them off (or the door they came in
## by) to the foot of the flight above (or the door out), the end that is against
## the wall left aside. A tower storey is a landing, not a room to dine in.
## Indices into `plan.furniture`; the check and the furnisher both ask this.
static func walkway_blockers(plan: HousePlan, room: int) -> Array[int]:
	var starts: Array[Vector2] = []
	var ends: Array[Vector2] = []
	var floor := HouseGeometry.room_floor_rect(plan, room)
	if minf(floor.size.x, floor.size.y) > WALKWAY_ROOM_MAX:
		return []
	for st in plan.stairs:
		if int(st.get("b", -1)) == room and Rect2(st.get("head_landing", Rect2())).has_area():
			starts.append(Rect2(st["head_landing"]).get_center())
		if int(st.get("a", -1)) == room and Rect2(st.get("foot_landing", Rect2())).has_area():
			ends.append(Rect2(st["foot_landing"]).get_center())
	for door in plan.doors:
		if int(door.get("a", -1)) == room and bool(door.get("exterior", false)):
			var inward := Vector2(door["pos"]) - Vector2(door["normal"]) * 0.8
			starts.append(inward)
			ends.append(inward)
	var out: Array[int] = []
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if bool(piece.get("mounted", false)) or not PropCatalog.blocks_floor(String(piece["key"])):
			continue
		var rect := Rect2(piece["rect"]).grow(WALKWAY_HALF)
		for from in starts:
			for to in ends:
				var span := from.distance_to(to)
				if span < 2.0 * WALKWAY_ENDS + 0.5:
					continue
				var way := (to - from) / span
				var a := from + way * WALKWAY_ENDS
				var b := to - way * WALKWAY_ENDS
				if _segment_hits(rect, a, b):
					if not out.has(index):
						out.append(index)
	return out


static func _segment_hits(rect: Rect2, a: Vector2, b: Vector2) -> bool:
	var lo := 0.0
	var hi := 1.0
	var d := b - a
	for axis in 2:
		var origin := a[axis]
		var delta := d[axis]
		var near := rect.position[axis]
		var far := rect.end[axis]
		if absf(delta) < 0.000001:
			if origin < near or origin > far:
				return false
			continue
		var t0 := (near - origin) / delta
		var t1 := (far - origin) / delta
		lo = maxf(lo, minf(t0, t1))
		hi = minf(hi, maxf(t0, t1))
		if lo > hi:
			return false
	return true


## The watch room's furniture. In the smallest tower storey -- 11.8 m2 in a
## hexagon, with a 2.4 x 1.0 stair across it -- the bench and a cupboard stand
## and the arms rack, a metre deep, does not; the pieces are placed in the
## WATCH_ROOM order and a piece that does not fit is simply absent. Each one is
## judged against the room's own walk and taken back out if it closes floor the
## room had.
static func _dress_watch_room(plan: HousePlan, spec: HouseSpec, room: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.seed) ^ 0x57_41_54_43
	var blocked: Array[Rect2] = HouseFurnishPlacement.initial_blocked(plan, room)
	var zones: Array[Rect2] = []
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if bool(piece.get("mounted", false)):
			continue
		blocked.append(Rect2(piece["rect"]))
		var zone: Rect2 = piece.get("zone", Rect2())
		if zone.size != Vector2.ZERO:
			zones.append(zone)
	var walk := CastleRoomTopUp.room_walk_faults(plan, room)
	var mark := plan.furniture.size()
	for step in WATCH_ROOM:
		var row: Dictionary = step.duplicate()
		row["opt"] = 1.0
		row["wall_only"] = String(step["rule"]) == "wall"
		HouseFurnishPlacement.place_one(plan, spec, room, String(step["cat"]),
			StringName(step["rule"]), blocked, zones, rng, row)
	# A big post wants a pair of lights (a guardroom's lantern used to make the
	# second before it was demoted and stripped of outdoor fittings).
	var missing := CastleRoomTopUp._lights_wanted(plan, room) - CastleRoomTopUp._lights(plan, room)
	for extra in range(maxi(missing, 0)):
		var count := plan.furniture.size()
		HouseFurnishPlacement.place_one(plan, spec, room, "sconce", &"mounted",
			blocked, zones, rng, {"opt": 1.0})
		if plan.furniture.size() == count:
			break
	while plan.furniture.size() > mark \
			and CastleRoomTopUp.room_walk_faults(plan, room) > walk:
		plan.furniture.resize(plan.furniture.size() - 1)


static func _facing_wall(walls: Array[Dictionary], inward: Vector2) -> int:
	var best := 0
	var score := -INF
	for index in range(walls.size()):
		var dot := Vector2(walls[index].normal).dot(inward)
		if dot > score:
			score = dot
			best = index
	return best


static func _windows(plan: HousePlan, level: int) -> void:
	var walls := HouseGeometry.room_walls(plan, level)
	# A round keep's cardinal X direction falls between two diagonal facets.
	# Keep its front horizontal facet solid for the bed and its side access;
	# the far side is already reserved for the stair landing.
	var blind := _facing_wall(walls, Vector2(0, 1) if walls.size() > 4 else Vector2(-1, 0))
	var head := minf(CastleInteriorPlans.WINDOW_SILL + CastleInteriorPlans.WINDOW_H,
		plan.spec.height - 0.2)
	# FEW AND TALL, the same rule the rectangular keep follows, measured along
	# the perimeter instead of counted per wall. A fourteen-sided drum 15 m
	# across has facets 3.5 m long; a window at the middle of every one leaves
	# a metre of wall on either side of it, which is less than a chest or a
	# cupboard stands on, and the only clean facets are the ones the stair
	# takes. The battered keep's 187 m2 parlour could then take no wall piece
	# at all, and failed "sparse" at 1% (CASTLE-CHANGE-17). One window every
	# keep pitch leaves whole facets of wall on a small drum, and still puts
	# one on every facet of a large one.
	var across := 0.0
	var last := -INF
	for wi in range(walls.size()):
		var wall: Dictionary = walls[wi]
		var length := Vector2(wall.from).distance_to(wall.to)
		var centre := across + length * 0.5
		across += length
		if plan.kind_of(level) == &"lords_chamber" and wi == blind:
			continue
		if centre - last < CastleInteriorPlans.KEEP_WINDOW_PITCH:
			continue
		var width := minf(CastleInteriorPlans.WINDOW_W,
			length - 2.0 * HouseGeometry.WINDOW_CORNER_MARGIN)
		if width < COMPACT_FACET_WINDOW_MIN:
			# Small round keeps have real, short masonry facets. Keep the normal
			# jamb when it leaves a usable aperture; compact facets use a narrower
			# light while preserving a quarter-metre stone return at each corner.
			# 45 cm jamb when it leaves a usable aperture; only compact facets
			# fall back to a 25 cm stone jamb and a narrow 30 cm light.
			width = minf(CastleInteriorPlans.WINDOW_W,
				length - 2.0 * COMPACT_FACET_JAMB)
			if width < COMPACT_FACET_WINDOW_MIN:
				continue
		var count := maxi(1, int(length / CastleInteriorPlans.KEEP_WINDOW_PITCH))
		for i in range(count):
			plan.windows.append({"room": level,
				"pos": Vector2(wall.from).lerp(wall.to, (float(i) + 0.5) / float(count)),
				"normal": -Vector2(wall.normal), "width": width,
				"sill": CastleInteriorPlans.WINDOW_SILL, "head": head, "storey": level})
		last = centre


## A common footprint touches a real wall on either landing and fits BOTH
## floors. Sampling against polygon faces avoids placing stairs in AABB corners.
## `hard` are polygons the flight may not touch at all (a sky tower's door, whose
## threshold the final mesh must keep clear); `soft` penalties still apply.
static func _add_stair(plan: HousePlan, lower: int, upper: int, avoid := Rect2(),
		hard: Array[PackedVector2Array] = []) -> void:
	var record := walkable_flight(plan, lower, upper, lower, upper, avoid, hard)
	if not record.is_empty():
		plan.stairs.append(record)


## The flight record `_add_stair` appends, or {} when no flight fits. `lower`
## and `upper` are rooms; `lower_storey` / `upper_storey` are their storeys
## (a keep numbers both alike, a shop cellar does not). Shops share it for a
## cellar stair (SHOP-ARCHETYPE-RED).
static func walkable_flight(plan: HousePlan, lower: int, upper: int,
		lower_storey: int, upper_storey: int, avoid := Rect2(),
		hard: Array[PackedVector2Array] = []) -> Dictionary:
	var floor := HouseGeometry.room_floor_rect(plan, upper)
	var cap := maxf(HouseGeometry.PATH_MIN, maxf(floor.size.x, floor.size.y) - 0.3)
	var width := minf(1.0, maxf(HouseGeometry.PATH_MIN, minf(floor.size.x, floor.size.y) - 0.3))
	var walls := HouseGeometry.room_walls(plan, upper)
	walls.append_array(HouseGeometry.room_walls(plan, lower))
	# The run a person can climb: the storey's height over the steepest pitch
	# HouseStairCheck allows. A 3.6 m storey on a 2.4 m run is 56 degrees, a
	# ladder (CASTLE-STAIR-PITCH). Try the walkable run first where the room
	# is long enough for it and its landings, else the old 2.4 m run. A room
	# under about 5 m cannot take a walkable straight flight at all: those
	# towers and keeps need a newel stair, which the plan cannot yet draw.
	var walkable := plan.spec.height / tan(deg_to_rad(PITCH_TARGET))
	var runs: Array[float] = []
	# A shorter run that is still too steep gains nothing and only crowds the
	# floor, so the walkable run is tried whole or not at all.
	if walkable <= cap:
		runs.append(walkable)
	runs.append(minf(MIN_RUN, cap))
	# A slender keep (3.8 m clear) cannot take 2.4 m of flight with a landing
	# beyond it. A steeper flight that lets its walker off on floor beats a
	# gentler one that climbs into a wall (stair_head).
	for shorter in SHORT_RUNS:
		if shorter < runs[-1] - 0.05:
			runs.append(shorter)
	var pick := {}
	var run := runs[-1]
	for attempt in range(runs.size()):
		run = runs[attempt]
		pick = _pick_run(plan, lower, upper, run, width, floor, walls, avoid, hard)
		if float(pick.get("climb", 0.0)) != 0.0:
			break
	var best: Rect2 = pick.get("rect", Rect2())
	if best.size.x <= 0.0:
		return {} # Missing transition remains a QA failure, never invented floor.
	if float(pick.score) < -100.0:
		plan.note_compromise(lower, "stair")
	var centre := best.get_center()
	var record := {"a": lower, "b": upper,
		"storey": lower_storey, "to_storey": upper_storey,
		"pos": centre, "lower_pos": centre, "upper_pos": centre,
		"rect": best, "lower_rect": best, "upper_rect": best,
		"width": width, "run": run}
	# A walkable run is climbed in steps a person can take: the storey over a
	# 0.2 m riser, not the ten the plan check assumes unless told.
	if run >= walkable - 0.01:
		record["steps"] = ceili(plan.spec.height / WALKABLE_RISER)
	if float(pick.climb) != 0.0:
		record.merge(pick.landings)
	if bool(pick.get("free_standing", false)):
		record["free_standing"] = true
	return record


## One run length's best flight: against a wall, then anywhere in a polygon
## that lets its walker off on floor, and standing free in the room.
static func _pick_run(plan: HousePlan, lower: int, upper: int, run: float, width: float,
		floor: Rect2, walls: Array[Dictionary], avoid: Rect2,
		hard: Array[PackedVector2Array]) -> Dictionary:
	var sizes: Array[Vector2] = [Vector2(run, width), Vector2(width, run)]
	var along_walls: Array[Rect2] = []
	for size in sizes:
		for wall in walls:
			var normal := Vector2(wall.normal)
			var support := (absf(normal.x) * size.x + absf(normal.y) * size.y) * 0.5
			var length := Vector2(wall.from).distance_to(wall.to)
			var samples := maxi(int(length / 0.2), 1)
			for step in range(samples + 1):
				var centre := Vector2(wall.from).lerp(wall.to, float(step) / float(samples)) + normal * support
				along_walls.append(Rect2(centre - size * 0.5, size))
	var pick := _pick_stair(plan, lower, upper, along_walls, avoid, hard, false)
	if float(pick.get("climb", 0.0)) == 0.0 and plan.is_polygonal(upper):
		# No flight against a wall lets its walker off on floor (a tower's small
		# hexagon, a slender keep): look across the whole room for one that does
		# (WALK-1a17b2b3-3, stairs into the wall).
		var open := wall_touching_rects(walls, sizes)
		var found := _pick_stair(plan, lower, upper, open, avoid, hard, true)
		if float(found.get("climb", 0.0)) != 0.0:
			pick = found
		else:
			# The room is too small for a flight and its landings against any
			# wall (a 12-gon of 7.7 m): the flight stands free, and says so.
			found = _pick_stair(plan, lower, upper, open_rects(floor, sizes), avoid,
				hard, true)
			if float(found.get("climb", 0.0)) != 0.0:
				pick = found
				pick["free_standing"] = true
	return pick


## Rects of each size that touch a wall at one corner, anywhere in the room: a
## flight in a polygon's interior that still "stands against a wall" in the
## sense of the plan check's `stair_line` (a corner within STAIR_WALL_TOL).
static func wall_touching_rects(walls: Array, sizes: Array[Vector2]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for size in sizes:
		var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0.0),
			Vector2(0.0, size.y), size]
		for wall in walls:
			var from: Vector2 = wall["from"]
			var to: Vector2 = wall["to"]
			var samples := maxi(int(from.distance_to(to) / 0.1), 1)
			for step in range(samples + 1):
				# a hair inside the wall: a corner exactly on the outline is not 'inside'
				var point := from.lerp(to, float(step) / float(samples)) + Vector2(wall["normal"]) * 0.03
				for offset in offsets:
					out.append(Rect2(point - offset, size))
	return out


## Rects of each size on a 0.2 m grid across the whole floor: a flight that
## stands free of every wall. Taken only when no flight against a wall lets its
## walker off on floor (see `_add_stair`).
static func open_rects(floor: Rect2, sizes: Array[Vector2], pitch := 0.2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for size in sizes:
		var x := floor.position.x
		while x <= floor.end.x - size.x + 0.001:
			var z := floor.position.y
			while z <= floor.end.y - size.y + 0.001:
				out.append(Rect2(Vector2(x, z), size))
				z += pitch
			x += pitch
	return out


## The best of `candidates` for a flight from `lower` to `upper`: {rect, score,
## climb, landings}. A flight with landings at both ends always beats one
## without; with `landed_only` the others are not considered at all.
static func _pick_stair(plan: HousePlan, lower: int, upper: int,
		candidates: Array[Rect2], avoid: Rect2, hard: Array[PackedVector2Array],
		landed_only: bool) -> Dictionary:
	var front := Vector2(plan.doors[plan.entrance()].pos)
	# The flight arriving on `lower` from below: standing in its well, this one
	# would climb out of that flight's solid foot -- the hotel's "stairway to
	# nowhere" (WALK-QA, 6 Oct), which every shaped keep repeated floor on floor.
	var wells: Array[Rect2] = HousePlanLevels.arriving_wells(plan, plan.storey_of_room(lower))
	# Where the flight below lets its walker off, on this storey's floor: the new
	# flight must not stand across it.
	var arrivals := arrival_floors(plan, plan.storey_of_room(lower))
	var best := {"rect": Rect2(), "score": -INF, "climb": 0.0, "landings": {}}
	for rect in candidates:
		var centre := rect.get_center()
		if not _inside(plan, lower, rect) or not _inside(plan, upper, rect):
			continue
		if avoid.size.x > 0.0 and rect.intersects(avoid, true):
			continue
		var in_doorway := false
		for zone in hard:
			for over in Geometry2D.intersect_polygons(Poly.from_rect(rect), zone):
				in_doorway = in_doorway or Poly.area(over) > 0.02
		if in_doorway:
			continue
		var landings := stair_landings(plan, lower, upper, rect, wells, arrivals)
		if landed_only and landings.is_empty():
			continue
		var score := centre.distance_to(front)
		if not landings.is_empty():
			score += 5000.0
		if HousePlanLevels.hits_any(rect, wells):
			score -= 2000.0
		if avoid.size.x > 0.0:
			score += centre.distance_to(avoid.get_center())
		if lower == int(plan.doors[plan.entrance()].a) 				and _overlap(rect, HousePlanLevels.door_line(plan, lower, plan.doors[plan.entrance()])):
			score -= 1000.0
		for door in plan.doors:
			if HousePlan.record_storey(door) == lower:
				if _overlap(rect, HouseGeometry.door_clear_rect(door, -1.0)):
					score -= 1000.0
		if score > float(best.score):
			best = {"rect": rect, "score": score,
				"climb": float(landings.get("climb", 0.0)), "landings": landings}
	return best


## Which way a flight laid on `rect` climbs so that its foot has floor on
## `lower` and its top step lets the walker off onto floor of `upper`, as
## {climb, foot_landing, head_landing}; empty when neither end will do. `wells`
## are the holes of flights arriving on `lower`, `arrivals` the floor the
## flight below lets its walker off on; the new flight stands on neither.
static func stair_landings(plan: HousePlan, lower: int, upper: int, rect: Rect2,
		wells: Array[Rect2], arrivals: Array[Rect2]) -> Dictionary:
	var lower_poly := HouseGeometry.room_floor_poly(plan, lower)
	var upper_poly := HouseGeometry.room_floor_poly(plan, upper)
	var landing_width := minf(rect.size.x, rect.size.y)
	for dir in [1.0, -1.0]:
		var foot := HouseGeometry.stair_approach(rect, dir)
		var head := HouseGeometry.stair_approach(rect, -dir, landing_width)
		if _poly_holds(lower_poly, foot) and _poly_holds(upper_poly, head) 				and not HousePlanLevels.hits_any(head, wells) 				and not HousePlanLevels.hits_any(foot, wells) 				and not HousePlanLevels.hits_any(rect, arrivals) 				and not HousePlanLevels.hits_any(head, arrivals):
			return {"climb": dir, "foot_landing": foot, "head_landing": head}
	return {}


## The floor the flights into storey `storey` let their walkers off on.
static func arrival_floors(plan: HousePlan, storey: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for prior in plan.stairs:
		if int(prior.get("to_storey", -1)) == storey and prior.has("head_landing"):
			out.append(Rect2(prior["head_landing"]))
	return out


## The floor a doorway needs: its width and 1.1 m into the room.
static func _door_footprint(door: Dictionary) -> PackedVector2Array:
	var inward := -Vector2(door["normal"]).normalized()
	var across := Vector2(-inward.y, inward.x) * (float(door["width"]) * 0.5)
	var pos := Vector2(door["pos"])
	return PackedVector2Array([pos - across, pos + across,
		pos + across + inward * 1.1, pos - across + inward * 1.1])


## Does this flight let its walker off into a wall? HouseStairCheck's stair_head
## rule, asked of a record at plan time.
static func _climbs_into_wall(plan: HousePlan, stair: Dictionary) -> bool:
	var rect := Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
	var head := Rect2(stair.get("head_landing", Rect2()))
	if not head.has_area():
		head = HouseGeometry.stair_approach(rect, -HouseGeometry.stair_climb(plan, stair),
			minf(rect.size.x, rect.size.y))
	return not _poly_holds(HouseGeometry.room_floor_poly(plan, int(stair["b"])), head)


static func _poly_holds(poly: PackedVector2Array, rect: Rect2) -> bool:
	if poly.size() < 3 or not rect.has_area():
		return false
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(poly, point, 0.02):
			return false
	return true


static func _inside(plan: HousePlan, room: int, rect: Rect2) -> bool:
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(plan.outline_of(room), point, 0.001):
			return false
	return true


static func _overlap(a: Rect2, b: Rect2) -> bool:
	var overlap := a.intersection(b)
	return overlap.size.x > 0.02 and overlap.size.y > 0.02
