extends RefCounted
## Every rule the walkers taught (HouseFurnishWalkCheck), each proven twice:
## it FAILS on the furniture a human pinned, reproduced in a real room, and it
## is SILENT on the same room put right. A rule that cannot fail is the
## seating rule that passed every backwards chair for a week.
##
## The rooms are real: the pinned cottage (house cottage seed 1) for the hall,
## bedroom and kitchen, and the pinned domus (world courtyard_house seed 1)
## for the big rooms. Their furniture is cleared and only the fixture placed,
## so a change to the furnisher cannot make a fixture pass or fail.
##   godot --headless --path . --script res://tests/run_all.gd -- walkpins


static func run() -> SuiteResult:
	var res := SuiteResult.new("walk pins")
	var cottage := _bare(&"house", &"cottage")
	var domus := _bare(&"world", &"courtyard_house")
	if cottage == null or domus == null:
		res.fail("the pinned buildings no longer generate")
		return res
	_hall(res, cottage)
	_bedroom(res, cottage)
	_kitchen(res, cottage)
	_big_room(res, domus)
	_corridor(res, domus)
	_stairs(res)
	_zfight(res)
	return res


## The pinned building through the public path, with its furniture cleared.
static func _bare(kind: StringName, style: StringName) -> HousePlan:
	var req := BrickWild.default_request(kind, 1)
	req.style = style
	var b := BrickWild.generate(req)
	var plan := b.plan as HousePlan
	if plan != null:
		plan.furniture.clear()
	return plan


static func _room(plan: HousePlan, kind: StringName) -> int:
	var rooms: Array = plan.rooms_of(kind)
	return int(rooms[0]) if not rooms.is_empty() else -1


static func _put(plan: HousePlan, room: int, key: String, at: Vector2, yaw := 0.0,
		host := -1) -> int:
	var p := HouseFurnishGeometry.candidate(key, at, yaw)
	p["room"] = room
	p["storey"] = plan.storey_of_room(room)
	p["host"] = host
	if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED):
		p["mounted"] = true
	plan.furniture.append(p)
	return plan.furniture.size() - 1


## Runs one rule on the plan and says whether it complained.
## Every other room of the bare plan is empty too, and honestly so: only the
## complaints about the fixture's own room count.
static func _fires(plan: HousePlan, rule: String, room: int) -> bool:
	for f in _said(plan, rule):
		if f.begins_with(rule + ":") and (room < 0 or ("room %d " % room) in f):
			return true
	return false


static func _said(plan: HousePlan, rule: String) -> PackedStringArray:
	var report := {"failures": [], "warnings": []}
	HouseFurnishWalkCheck.new(report).call("check_" + rule, plan)
	return PackedStringArray(report["failures"])


static func _expect(res: SuiteResult, plan: HousePlan, rule: String, want: bool, what: String,
		room := -1) -> void:
	res.checked += 1
	var got := _fires(plan, rule, room)
	if got != want:
		var said := _said(plan, rule)
		res.fail("%s: %s %s%s" % [rule, what, "was not flagged" if want else "was flagged",
			"" if said.is_empty() else " (%s)" % "; ".join(said)])
	plan.furniture.clear()


## A long table down the middle of the hall, as the cottage has it.
static func _table(plan: HousePlan, room: int) -> int:
	var r := HouseGeometry.room_floor_rect(plan, room)
	return _put(plan, room, "Table_Large", r.get_center(), PI / 2.0)


static func _hall(res: SuiteResult, plan: HousePlan) -> void:
	var hall := _room(plan, &"hall")
	if hall < 0:
		res.fail("the pinned cottage has no hall")
		return
	var c := HouseGeometry.room_floor_rect(plan, hall).get_center()
	var t := 0
	var stool := PropCatalog.footprint("Stool")

	# pin 1a113a/1 "collides with table": a stool 0.15 m into the trestle end
	t = _table(plan, hall)
	var tr: Rect2 = plan.furniture[t]["rect"]
	_put(plan, hall, "Stool", Vector2(c.x, tr.position.y - stool.y / 2.0 + 0.15), PI, t)
	_expect(res, plan, "tuck", true, "a stool pushed into the end of its table")
	t = _table(plan, hall)
	_put(plan, hall, "Stool", Vector2(c.x, tr.position.y - stool.y / 2.0 - 0.02), PI, t)
	_expect(res, plan, "tuck", false, "a stool drawn up to the end of its table")

	# a seat inside a cupboard is not tucked in, it is in the cupboard
	t = _table(plan, hall)
	var side := Vector2(tr.position.x - 0.3, c.y)
	_put(plan, hall, "Chair_1", side, -PI / 2.0, t)
	_put(plan, hall, "Cabinet", side + Vector2(-0.2, 0.0))
	_expect(res, plan, "tuck", true, "a chair standing in a cabinet")

	# 1a113e/2 "light is right in the way of the table"
	t = _table(plan, hall)
	_put(plan, hall, "CandleStick_Stand", Vector2(tr.end.x + 0.2 + 0.37, c.y))
	_expect(res, plan, "table_band", true, "a candle stand along the table's long side")
	t = _table(plan, hall)
	_put(plan, hall, "CandleStick_Stand", Vector2(tr.end.x + 0.55 + 0.37, c.y))
	_expect(res, plan, "table_band", false, "a candle stand clear of the table")

	# 1a113e/3 "why two kinds of chairs?"
	t = _table(plan, hall)
	_put(plan, hall, "Chair_1", Vector2(tr.position.x - 0.3, c.y - 0.6), -PI / 2.0, t)
	_put(plan, hall, "Stool", Vector2(tr.end.x + 0.25, c.y + 0.6), PI / 2.0, t)
	_expect(res, plan, "seat_kinds", true, "a chair and a stool at one table")
	t = _table(plan, hall)
	_put(plan, hall, "Chair_1", Vector2(tr.position.x - 0.3, c.y - 0.6), -PI / 2.0, t)
	_put(plan, hall, "Chair_1", Vector2(tr.end.x + 0.3, c.y + 0.6), PI / 2.0, t)
	_expect(res, plan, "seat_kinds", false, "two chairs at one table")

	# 6#4 / 15#4 "one bench, just a table": a table with one seat
	t = _table(plan, hall)
	_put(plan, hall, "Chair_1", Vector2(tr.position.x - 0.3, c.y), -PI / 2.0, t)
	_expect(res, plan, "seat_count", true, "a hall table with one chair")
	t = _table(plan, hall)
	_put(plan, hall, "Chair_1", Vector2(tr.position.x - 0.3, c.y - 0.6), -PI / 2.0, t)
	_put(plan, hall, "Chair_1", Vector2(tr.position.x - 0.3, c.y + 0.6), -PI / 2.0, t)
	_expect(res, plan, "seat_count", false, "a hall table with two chairs")

	# 16#12 "tables do not go right in front of main entrances"
	var d := plan.entrance()
	if plan.doors[d]["a"] == hall or plan.doors[d]["b"] == hall:
		var door: Dictionary = plan.doors[d]
		var n: Vector2 = door["normal"]
		if (c - Vector2(door["pos"])).dot(n) < 0.0:
			n = -n
		_put(plan, hall, "Stool", Vector2(door["pos"]) + n * 0.8)
		_expect(res, plan, "front_door", true, "a stool 0.8 m inside the front door")
		_put(plan, hall, "Stool", Vector2(door["pos"]) + n * (HouseFurnishPlacement.DOOR_APPROACH + 0.4))
		_expect(res, plan, "front_door", false, "a stool past the way in")
	else:
		res.fail("front_door: the pinned cottage's front door is not in its hall")


static func _bedroom(res: SuiteResult, plan: HousePlan) -> void:
	var room := _room(plan, &"bedroom")
	if room < 0:
		res.fail("the pinned cottage has no bedroom")
		return
	var r := HouseGeometry.room_floor_rect(plan, room)
	var bed := PropCatalog.footprint_rotated("Bed_Twin1", 0.0)
	var d: int = plan.doors_of(room)[0]
	var door: Dictionary = plan.doors[d]
	var dp: Vector2 = door["pos"]
	# the corner of the room furthest from its door
	var far := r.get_center()
	for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		var inset: Vector2 = corner + (r.get_center() - corner).sign() * (bed / 2.0 + Vector2(0.05, 0.05))
		if inset.distance_to(dp) > far.distance_to(dp):
			far = inset
	var inward := Vector2(signf(r.get_center().x - far.x), 0.0)

	# 1a1030/3 "feng sui is bad to put bed right by door"
	var n: Vector2 = door["normal"]
	if (r.get_center() - dp).dot(n) < 0.0:
		n = -n
	var along := Vector2(n.y, -n.x)
	if (r.get_center() - dp).dot(along) < 0.0:
		along = -along
	var foot := bed if absf(n.y) > 0.5 else Vector2(bed.y, bed.x)
	var beside := dp + n * (foot.y / 2.0 + 0.1) + along * (float(door["width"]) / 2.0 + foot.x / 2.0 + 0.1)
	_put(plan, room, "Bed_Twin1", beside, 0.0 if absf(n.y) > 0.5 else PI / 2.0)
	_expect(res, plan, "bed_door", true, "a bed beside the bedroom door")
	_put(plan, room, "Bed_Twin1", far)
	_expect(res, plan, "bed_door", false, "a bed in the corner furthest from the door")

	# 15#3 the domus nightstand 2.3 m from its bed
	_put(plan, room, "Bed_Twin1", far)
	_put(plan, room, "Nightstand_Shelf", far + inward * (bed.x / 2.0 + 1.0))
	_expect(res, plan, "bedside", true, "a nightstand a metre from the bed")
	_put(plan, room, "Bed_Twin1", far)
	_put(plan, room, "Nightstand_Shelf", far + inward * (bed.x / 2.0 + 0.25))
	_expect(res, plan, "bedside", false, "a nightstand at the bedside")

	# 11#2 "give the barracks some dressers": beds and nothing to keep things in
	_put(plan, room, "Bed_Twin1", far)
	_put(plan, room, "Bed_Twin1", far + inward * (bed.x + 0.2))
	_expect(res, plan, "stowage", true, "two beds and no chest")
	_put(plan, room, "Bed_Twin1", far)
	_put(plan, room, "Bed_Twin1", far + inward * (bed.x + 0.2))
	_put(plan, room, "Chest_Wood", r.position + Vector2(0.7, 0.4))
	_expect(res, plan, "stowage", false, "two beds and a chest")


static func _kitchen(res: SuiteResult, plan: HousePlan) -> void:
	var room := _room(plan, &"kitchen")
	if room < 0:
		res.fail("the pinned cottage has no kitchen")
		return
	var r := HouseGeometry.room_floor_rect(plan, room)
	# 1a113a/3 "need to get some kitchen furniture": a fire and barrels
	_put(plan, room, "Cauldron", r.get_center())
	_put(plan, room, "Barrel", r.position + Vector2(0.4, 0.4))
	_expect(res, plan, "worktop", true, "a kitchen with a fire and a barrel")
	_put(plan, room, "Cauldron", r.get_center())
	_put(plan, room, "Workbench", r.position + Vector2(1.0, 0.5))
	_expect(res, plan, "worktop", false, "a kitchen with a workbench")


static func _big_room(res: SuiteResult, plan: HousePlan) -> void:
	var room := _room(plan, &"parlour")
	if room < 0 or HouseGeometry.room_area(plan, room) < HouseFurnishWalkCheck.LAMP_ROOM:
		res.fail("the pinned domus has no large parlour any more")
		return
	var r := HouseGeometry.room_floor_rect(plan, room)
	var c := r.get_center()
	var area := HouseGeometry.room_area(plan, room)
	var t_size := PropCatalog.footprint_rotated("Table_Large", PI / 2.0)

	# 1a113f/4 "one bench, just a table in a huge room"
	var t := _put(plan, room, "Table_Large", c, PI / 2.0)
	_put(plan, room, "Bench", c - Vector2(t_size.x / 2.0 + 0.3, 0.0), -PI / 2.0, t)
	_expect(res, plan, "sparse", true, "a %.0f m2 parlour with a table and a bench" % area, room)
	var tables := int(ceil(area * HouseFurnishWalkCheck.SPARSE_MIN / (t_size.x * t_size.y))) + 1
	for i in tables:
		_put(plan, room, "Table_Large", r.position + Vector2(0.7 + (i % 3) * 1.6,
			1.6 + int(i / 3) * 3.2), PI / 2.0)
	_expect(res, plan, "sparse", false, "a parlour with %d tables" % tables, room)

	# 1a113f/3 "missing lights"
	_put(plan, room, "CandleStick", c)
	_expect(res, plan, "lamps", true, "a %.0f m2 room lit by one candle" % area, room)
	for i in int(ceil(area / HouseFurnishWalkCheck.LAMP_AREA)):
		_put(plan, room, "Torch_Metal", r.position + Vector2(0.05, 1.0 + i * 2.0), PI / 2.0)
	_expect(res, plan, "lamps", false, "a room with a torch for every %.0f m2"
		% HouseFurnishWalkCheck.LAMP_AREA, room)

	# 1a113a/1 the shop mess: two tables, their benches back to back
	var bench := PropCatalog.footprint_rotated("Bench", PI / 2.0)
	for gap in [0.6, 1.4]:
		var a := _put(plan, room, "Table_Large", c - Vector2(t_size.x / 2.0 + bench.x + gap / 2.0, 0.0), PI / 2.0)
		var b := _put(plan, room, "Table_Large", c + Vector2(t_size.x / 2.0 + bench.x + gap / 2.0, 0.0), PI / 2.0)
		# each bench faces its own table, so their pulled-out floor meets in the gap
		_put(plan, room, "Bench", c - Vector2(bench.x / 2.0 + gap / 2.0, 0.0), PI / 2.0, a)
		_put(plan, room, "Bench", c + Vector2(bench.x / 2.0 + gap / 2.0, 0.0), -PI / 2.0, b)
		_expect(res, plan, "pull_out", gap < 1.0, "benches back to back %.1f m apart" % gap, room)


## 1a113e/5 the hotel gallery: "what is it and why is it right in the way"
static func _corridor(res: SuiteResult, plan: HousePlan) -> void:
	var room := -1
	for i in plan.room_count():
		if HouseFurnishWalkCheck._corridor(HouseGeometry.room_floor_rect(plan, i)):
			room = i
	if room < 0:
		# the domus has none: borrow its gallery and make it one, as the hotel's is
		room = _room(plan, &"gallery")
		var g := HouseGeometry.room_floor_rect(plan, room)
		plan.rooms[room]["rect"] = Rect2(g.position, Vector2(g.size.x, 2.6)) if g.size.x > g.size.y 			else Rect2(g.position, Vector2(2.6, g.size.y))
	var r := HouseGeometry.room_floor_rect(plan, room)
	var long := Vector2(1, 0) if r.size.x >= r.size.y else Vector2(0, 1)
	var across := Vector2(long.y, long.x)
	var stand := PropCatalog.footprint("BookStand")
	_put(plan, room, "BookStand", r.position + long * 2.0 + across * (0.8 + stand.y / 2.0))
	_expect(res, plan, "corridor", true, "a lectern standing loose in a corridor", room)
	_put(plan, room, "BookStand", r.position + long * 2.0 + across * (0.05 + stand.y / 2.0))
	_expect(res, plan, "corridor", false, "a lectern against the corridor wall", room)


## Wolfmarch Green's house_9, the village's request for it frozen here, so it
## builds in seconds: "cannot climb stairs", "stairs go directly into the
## wall", "bench on stairs" (a shelf), "no railing" (16#3-6; 7#5 in round 1).
## These assert the PINNED building is still flagged; when its stair is put
## right they will fail, and the control half below is what must then hold.
const HOUSE_9 := {"enclosure": "none", "height": 2.6, "kind": "house", "length": 9.3,
	"material": "timber", "orientation": 0.0, "period": 1200, "purpose": "farmer",
	"schema": "brickwild.request", "schema_version": 1, "seed": "4276917608",
	"storeys": 2, "style": "cottage", "water": "none", "width": 7.2}


static func _stairs(res: SuiteResult) -> void:
	var b := BrickWild.generate(BuildingRequest.from_dict(HOUSE_9))
	var plan := b.plan as HousePlan
	if plan == null or plan.stairs.is_empty():
		res.fail("stairs: village house_9 no longer builds a stair")
		return
	if not bool(plan.stairs[0].get("satisfied", true)) \
			or not Rect2(plan.stairs[0].get("lower_rect", Rect2())).has_area():
		res.fail("stairs: village house_9 is infeasible, so legacy defects cannot be claimed reproduced: %s" \
			% String(plan.stairs[0].get("reason", "no reason")))
		return
	var builder := HouseBuilder.new()
	builder.build(plan)
	var said := HouseStairCheck.check(plan, builder)
	# The pinned, pre-fix flight still reproduces these three real defects.
	# Measured headroom and walker access now have their own valid-plan controls
	# below; do not keep expecting those corrected symptoms on this pin.
	for rule in ["stair_pitch", "stair_head", "stair_guard"]:
		res.checked += 1
		var hit := false
		for m in said:
			hit = hit or String(m).begins_with(rule + ":")
		if not hit:
			res.fail("%s: village house_9 is no longer flagged -- if its stair is fixed, freeze a plan for this fixture" % rule)
	# the controls: a flight long enough for its rise, and nothing over it
	var st: Dictionary = plan.stairs[0]
	var r := Rect2(st["lower_rect"])
	st["steps"] = 13
	plan.furniture = plan.furniture.filter(func(f): return not Rect2(f["rect"]).grow(0.4).intersects(r))
	var along_x := r.size.x > r.size.y
	st["lower_rect"] = Rect2(r.position, Vector2(3.4, r.size.y) if along_x else Vector2(r.size.x, 3.4))
	for m in HouseStairCheck.check(plan):
		res.checked += 1
		if String(m).begins_with("stair_pitch:") or String(m).begins_with("stair_headroom:"):
			res.fail("control: " + String(m))
	_check_headroom_and_approach_controls(res)


static func _check_headroom_and_approach_controls(res: SuiteResult) -> void:
	res.checked += 7
	var plan := _stair_control_plan()
	HousePlanLevels.add_stair(plan, 0, 1, 0, 1)
	if plan.stairs.is_empty() or not bool(plan.stairs[0].get("satisfied", false)):
		res.fail("stair clearance controls lack a valid domestic flight")
		return
	var stair: Dictionary = plan.stairs[0]
	var headroom_clear: Array[String] = []
	HouseStairCheck._headroom(plan, 0, stair, headroom_clear)
	if not headroom_clear.is_empty():
		res.fail("clear generated flight unexpectedly fails measured headroom: %s" % "; ".join(headroom_clear))
	var approach_clear: Array[String] = []
	HouseStairCheck._approach(plan, 0, stair, approach_clear)
	if not approach_clear.is_empty():
		res.fail("clear generated flight unexpectedly fails 0.9 m walker approach: %s" % "; ".join(approach_clear))

	# Measured chandelier body over the flight must fail; the same body wholly
	# beside it must pass. This uses the production pose-derived headroom check.
	var flight := Rect2(stair["lower_rect"])
	var centre := flight.get_center()
	plan.furniture.append({"key": "Chandelier", "room": 0, "storey": 0,
		"pos": Vector3(centre.x, plan.spec.height, centre.y), "yaw": 0.0,
		"rect": Rect2(centre - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "cat": "chandelier", "mounted": true, "scale": 1.0})
	var headroom_blocked: Array[String] = []
	HouseStairCheck._headroom(plan, 0, stair, headroom_blocked)
	if not _has_rule(headroom_blocked, "stair_headroom"):
		res.fail("measured chandelier over the flight escaped the headroom check")
	var chandelier_size := PropCatalog.footprint_rotated("Chandelier", PropCatalog.face_offset("Chandelier"))
	if flight.size.x > flight.size.y:
		centre.y = flight.end.y + chandelier_size.y * 0.5 + 0.1
	else:
		centre.x = flight.end.x + chandelier_size.x * 0.5 + 0.1
	plan.furniture[0]["pos"] = Vector3(centre.x, plan.spec.height, centre.y)
	plan.furniture[0]["rect"] = Rect2(centre - Vector2.ONE * 0.05, Vector2.ONE * 0.1)
	var headroom_separated: Array[String] = []
	HouseStairCheck._headroom(plan, 0, stair, headroom_separated)
	if not headroom_separated.is_empty():
		res.fail("measured chandelier beside the flight caused false headroom collision")

	# Block the actual entry aperture with a catalogue-measured table body that
	# lies wholly on the room floor. The 0.9 m walker must lose its route.
	var door_index := plan.entrance()
	var door: Dictionary = plan.doors[door_index]
	var normal: Vector2 = door["normal"]
	var tangent := Vector2(-normal.y, normal.x)
	var table_yaw := atan2(-tangent.y, tangent.x)
	var table_size := PropCatalog.footprint_rotated("Table_Large", table_yaw)
	var inside := -normal
	var table_centre := Vector2(door["pos"]) + inside * (
		HouseGeometry.wall_thickness(plan.spec) * 0.5 + table_size.y * 0.5 + 0.05)
	var table_rect := Rect2(table_centre - table_size * 0.5, table_size)
	var floor := HouseGeometry.room_floor_rect(plan, 0)
	if not floor.encloses(table_rect):
		res.fail("measured doorway blocker does not fit wholly on the real room floor")
		return
	plan.furniture.append({"key": "Table_Large", "room": 0, "storey": 0,
		"pos": Vector3(table_centre.x, HouseGeometry.FLOOR_T, table_centre.y), "yaw": table_yaw,
		"rect": table_rect, "zone": Rect2(), "host": -1, "cat": "table",
		"mounted": false, "scale": 1.0})
	var approach_blocked: Array[String] = []
	HouseStairCheck._approach(plan, 0, stair, approach_blocked)
	if not _has_rule(approach_blocked, "stair_approach"):
		res.fail("actual measured doorway table did not block the walker route to the stair")


static func _stair_control_plan() -> HousePlan:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 12.0
	spec.length = 14.0
	spec.height = 2.6
	spec.storeys = 2
	var plan := HousePlan.new()
	plan.spec = spec
	plan.domestic_layout = {"status": &"planned", "style": spec.style}
	var floor := HouseGeometry.interior_rect(spec)
	plan.rooms = [
		{"kind": &"hall", "rect": floor, "storey": 0},
		{"kind": &"bedroom", "rect": floor, "storey": 1},
	]
	plan.doors.append({"a": 0, "b": -1, "storey": 0, "front": true,
		"exterior": true, "width": 0.95, "head": 2.22,
		"pos": Vector2(floor.get_center().x, floor.position.y), "normal": Vector2(0, -1)})
	return plan


static func _has_rule(messages: Array[String], rule: String) -> bool:
	for message in messages:
		if message.begins_with(rule + ":"):
			return true
	return false


## Z-fighting, ratcheted. Fifteen pins said "z ordering"; CoplanarCheck found
## every one and nothing called it. Each pinned building may show no MORE
## visible overlaps than it did on 7 Oct. When a fix lowers a count, lower
## its budget here. The hotel (66, ~8 s) and castle (warning only, ~15 s)
## belong to the scheduled lanes.
const ZFIGHT_BUDGET := {
	"house/cottage": 8,
	"shop/cottage": 0,
	"world/courtyard_house": 24,
	"temple/basilica": 12,
	"church/romanesque": 92,
	"windmill/tower": 40,
}


static func _zfight(res: SuiteResult) -> void:
	for id in ZFIGHT_BUDGET:
		var req := BrickWild.default_request(StringName(id.get_slice("/", 0)), 1)
		req.style = StringName(id.get_slice("/", 1))
		var b := BrickWild.generate(req)
		var found := CoplanarCheck.visible(BrickWild.build_mesh(b), id)
		var budget := int(ZFIGHT_BUDGET[id])
		res.checked += 1
		print("zfight %s: %d visible overlaps (budget %d)" % [id, found.size(), budget])
		if budget >= 0 and found.size() > budget:
			res.fail("zfight: %s shows %d visible overlaps, budget %d; first: %s"
				% [id, found.size(), budget, found[0]])
