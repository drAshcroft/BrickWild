class_name HouseWalkSources
extends RefCounted
## The house's walkable floor as plain geometry: the levels, the doorways, the
## stair landings and the outlines `HouseNavCheck` rasterises. Kept apart from
## the check so the public API can read it without joining the check's import
## cycle, which a cold import meets half-parsed.


## Every level the plan has, cellars included (INT-016).
static func levels_of(plan: HousePlan) -> Array[int]:
	var out: Array[int] = []
	var lowest := 0
	if plan.spec.has_method("lowest_storey"):
		lowest = int(plan.spec.lowest_storey())
	for level in range(lowest, clampi(int(plan.spec.storeys), 1, plan.spec.max_storeys())):
		out.append(level)
	# HS-PUEBLO: the topmost roof of a stepped house is a terrace people walk on
	for terrace in plan.terraces:
		if not out.has(int(terrace["storey"])):
			out.append(int(terrace["storey"]))
	return out


## The floor `HouseNavCheck._rasterize` lays and the obstruction it cuts, per
## storey, as outlines a navigation baker can union: {storey: {"floor": [...],
## "obstacles": [...]}}. Secret doors are left shut. A dais a person can step
## onto is floor already; one they cannot is an obstacle. Change one, change
## the other.
static func sources(plan: HousePlan) -> Dictionary:
	var out := {}
	for level in levels_of(plan):
		out[level] = _layer()
	for i in range(plan.room_count()):
		var level := HousePlan.record_storey(plan.rooms[i])
		if out.has(level):
			out[level]["floor"].append(plan.outline_of(i) if plan.is_polygonal(i)
				else Poly.from_rect(HouseGeometry.room_floor_rect(plan, i)))
	for level in out:
		for ci in plan.courts_on(level):
			out[level]["floor"].append(plan.court_outline(ci) if plan.courts[ci].has("outline")
				else Poly.from_rect(Rect2(plan.courts[ci]["rect"])))
	for d in plan.doors:
		var level := HousePlan.record_storey(d)
		if out.has(level) and not bool(d.get("secret", false)):
			out[level]["floor"].append(Poly.from_rect(door_gap(d)))
	# HS-PUEBLO: the terraces, the doorways through the thick wall onto them and the
	# ground at the foot of the first ladder (HousePueblo.walk_floor, one list for
	# this and for the check)
	if not plan.terraces.is_empty():
		for level in out:
			for r in HousePueblo.walk_floor(plan, level):
				out[level]["floor"].append(Poly.from_rect(r))
	var dais_room: int = plan.dais_room()
	if dais_room >= 0 and dais_room < plan.room_count() and plan.dais_rise() > WalkGrid.MAX_STEP:
		var level := HousePlan.record_storey(plan.rooms[dais_room])
		if out.has(level):
			out[level]["obstacles"].append(Poly.from_rect(plan.dais_rect()))
	for p in plan.furniture:
		if p.get("mounted", false) or not PropCatalog.blocks_floor(String(p["key"])):
			continue
		var level := HousePlan.record_storey(p)
		if out.has(level):
			out[level]["obstacles"].append(Poly.from_rect(p["rect"]))
	for column in plan.columns:
		var level := int(column.get("storey", 0))
		var size: Vector2 = column.get("size", Vector2.ZERO)
		if out.has(level) and size.x > 0.0 and size.y > 0.0:
			out[level]["obstacles"].append(Poly.from_rect(Rect2(Vector2(column.get("pos", Vector2.ZERO)) - size * 0.5, size)))
	var breast := HouseGeometry.hearth_breast(plan)
	if not breast.is_empty() and out.has(int(breast["storey"])):
		out[int(breast["storey"])]["obstacles"].append(breast["outline"])
	return out


static func _layer() -> Dictionary:
	var floor: Array[PackedVector2Array] = []
	var obstacles: Array[PackedVector2Array] = []
	return {"floor": floor, "obstacles": obstacles}


static func stair_rect(stair: Dictionary, upper: bool) -> Rect2:
	var key := "upper_rect" if upper else "lower_rect"
	if stair.has(key):
		return Rect2(stair[key])
	return Rect2(stair.get("rect", Rect2()))


## The hole a door makes: its width, right through the wall it is cut into.
static func door_gap(d: Dictionary) -> Rect2:
	var n: Vector2 = d["normal"]
	var along := Vector2(n.y, -n.x).abs()
	var c: Vector2 = d["pos"]
	var half: Vector2 = along * (float(d["width"]) / 2.0)
	var deep: Vector2 = n.abs() * (HouseGeometry.WALL_T * 0.6 + 0.1)
	var a: Vector2 = c - half - deep
	var b: Vector2 = c + half + deep
	return Rect2(a.min(b), (b - a).abs())
