extends RefCounted
## EVAL-U02: the house sheet must be a drawing OF the house.
##
## HouseSheet.drawing() is the sheet in metres. This suite holds it against the
## HousePlan it came from and against the mesh HouseBuilder emits from that plan:
## every room once and at its clear-floor size, every wall where the builder
## logged a wall mass, every door and window on a wall it pierces, every piece of
## furniture once, the stairs, the front door, the north arrow, the elevation's
## ridge against the builder's own roof slabs, and the page layout against the
## page. `compare()` returns the defects it finds; the positive cases require
## none and the negative controls mutate a copy of the drawing and require the
## right one to be reported, so a comparator that cannot see is not mistaken for
## a drawing that agrees.

const EPS := 0.01
const PAGES: Array[Vector2] = [Vector2(930, 470), Vector2(1500, 800), Vector2(620, 700)]


static func run() -> SuiteResult:
	var res := SuiteResult.new("hblueprint")
	for row in _cases():
		var plan: HousePlan = row["plan"]
		var builder: HouseBuilder = row["builder"]
		builder.build(plan)
		var drawn: Dictionary = HouseSheet.drawing(plan)
		_positive(res, row["who"], plan, builder, drawn)
		_layout(res, row["who"], drawn)
	_roof_kinds(res)
	_controls(res)
	_north(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


# ----------------------------------------------------------------------- cases

static func _house(style: StringName, seed: int, w: float, l: float, h: float,
		storeys: int, cellars := 0) -> HousePlan:
	var s := HouseSpec.new()
	s.style = style
	s.width = w
	s.length = l
	s.height = h
	s.storeys = storeys
	s.cellars = cellars
	return HouseGenerator.generate(s, seed, true)


static func _family(kind: StringName, seed: int) -> HousePlan:
	var made: GeneratedBuilding = BrickWild.generate(BrickWild.default_request(kind, seed))
	return made.plan


static func _cases() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in [["farmhouse one storey", &"farmhouse", 4413, 10.0, 13.0, 2.7, 1, 0],
			["townhouse two storeys", &"townhouse", 4411, 9.0, 12.0, 2.7, 2, 0],
			["cottage", &"cottage", 4412, 7.0, 9.0, 2.5, 1, 0],
			["long hall broad", &"longhall", 4414, 16.0, 12.0, 2.7, 1, 0],
			["three storeys", &"townhouse", 4415, 10.0, 12.0, 2.6, 3, 0],
			["cellar", &"farmhouse", 4416, 10.0, 13.0, 2.7, 2, 1]]:
		out.append({"who": row[0], "plan": _house(row[1], row[2], row[3], row[4], row[5], row[6], row[7]),
			"builder": HouseBuilder.new()})
	out.append({"who": "shop", "plan": _family(&"shop", 42021), "builder": HouseBuilder.new()})
	out.append({"who": "hotel", "plan": _family(&"hotel", 42021), "builder": HotelBuilder.new()})
	return out


# ------------------------------------------------------------------ comparator

## Every way the drawing disagrees with the plan and the mesh. Empty is a match.
static func compare(plan: HousePlan, builder: HouseBuilder, drawn: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var spec: HouseSpec = plan.spec
	var by_level: Dictionary = drawn["by_level"]

	# rooms: once each, on their storey, at the size the plan gives them
	var seen_rooms := {}
	for level in by_level:
		for room in by_level[level]["rooms"]:
			var i: int = room["room"]
			seen_rooms[i] = int(seen_rooms.get(i, 0)) + 1
			if plan.storey_of_room(i) != int(level):
				bad.append("room %d drawn on L%d, plan has it on L%d" % [i, level, plan.storey_of_room(i)])
			var floor_rect: Rect2 = room["floor"]
			var rect: Rect2 = plan.rooms[i]["rect"]
			if not plan.is_polygonal(i):
				# the clear floor is the room's share of the interior less half a
				# partition on a shared edge: inside the rect, never more than a
				# partition smaller
				if not rect.grow(EPS).encloses(floor_rect):
					bad.append("room %d floor %s leaves its rect %s" % [i, floor_rect, rect])
				if rect.size.x - floor_rect.size.x > HouseGeometry.INNER_WALL_T + EPS \
						or rect.size.y - floor_rect.size.y > HouseGeometry.INNER_WALL_T + EPS:
					bad.append("room %d drawn %s, plan rect %s: more than a partition smaller" % [i, floor_rect.size, rect.size])
			if absf(floor_rect.size.x - HouseGeometry.room_floor_rect(plan, i).size.x) > EPS \
					or absf(floor_rect.position.x - HouseGeometry.room_floor_rect(plan, i).position.x) > EPS \
					or absf(floor_rect.position.y - HouseGeometry.room_floor_rect(plan, i).position.y) > EPS \
					or absf(floor_rect.size.y - HouseGeometry.room_floor_rect(plan, i).size.y) > EPS:
				bad.append("room %d drawn at %s, the floor is %s" % [i, floor_rect, HouseGeometry.room_floor_rect(plan, i)])
	for i in range(plan.room_count()):
		if int(seen_rooms.get(i, 0)) != 1:
			bad.append("room %d drawn %d times" % [i, int(seen_rooms.get(i, 0))])

	# walls against the masses the builder logged
	var multi: bool = (drawn["levels"] as Array).size() > 1
	for level in by_level:
		var suffix: String = "_%d" % level if multi else ""
		for wall in by_level[level]["walls"]:
			var quad: Rect2 = _wall_bounds(wall)
			var mass_name := ""
			if wall["kind"] == &"exterior":
				mass_name = "wall_%s%s" % [String(wall["side"]), suffix]
			elif wall["kind"] == &"partition":
				var pair: Vector2i = wall["pair"]
				mass_name = "partition_%d_%d%s" % [pair.x, pair.y, suffix]
			else:
				continue
			if HouseGeometry.is_shaped(plan) or plan.has_court():
				continue
			var found := false
			for m in builder.mass_log:
				if m["name"] == mass_name:
					found = true
					var a: AABB = m["aabb"]
					var r := Rect2(a.position.x, a.position.z, a.size.x, a.size.z)
					if not (absf(r.position.x - quad.position.x) < EPS and absf(r.position.y - quad.position.y) < EPS \
							and absf(r.size.x - quad.size.x) < EPS and absf(r.size.y - quad.size.y) < EPS):
						bad.append("%s drawn %s, built %s" % [mass_name, quad, r])
					break
			if not found and wall["kind"] == &"exterior" and not (spec is HotelSpec):
				bad.append("no mass %s for a drawn exterior wall" % mass_name)

	# doors and windows: once each, on a wall they pierce, as wide as the plan says
	var door_count := 0
	var windows_count := 0
	var fronts := 0
	for level in by_level:
		for door in by_level[level]["doors"]:
			door_count += 1
			var rec: Dictionary = plan.doors[door["door"]]
			if float(door["off"]) > float(door["thick"]) * 0.5 + 0.03 or int(door["wall"]) < 0:
				bad.append("door %d is %.2f m from the nearest wall" % [door["door"], door["off"]])
			if absf(float(door["width"]) - float(rec["width"])) > EPS:
				bad.append("door %d drawn %.2f wide, plan %.2f" % [door["door"], door["width"], rec["width"]])
			if absf(Vector2(door["along"]).dot(Vector2(rec["normal"]))) > 0.02:
				bad.append("door %d is not square to its wall" % door["door"])
			if door["front"]:
				fronts += 1
		for win in by_level[level]["windows"]:
			windows_count += 1
			var rec: Dictionary = plan.windows[win["window"]]
			if float(win["off"]) > float(win["thick"]) * 0.5 + 0.03 or int(win["wall"]) < 0:
				bad.append("window %d is %.2f m from the nearest wall" % [win["window"], win["off"]])
			if absf(float(win["width"]) - float(rec["width"])) > EPS:
				bad.append("window %d drawn %.2f wide, plan %.2f" % [win["window"], win["width"], rec["width"]])
	if door_count != plan.doors.size():
		bad.append("%d doors drawn, plan has %d" % [door_count, plan.doors.size()])
	if windows_count != plan.windows.size():
		bad.append("%d windows drawn, plan has %d" % [windows_count, plan.windows.size()])
	if plan.entrance() >= 0 and fronts != 1:
		bad.append("%d front doors marked, plan has one" % fronts)

	# furniture: every piece once, where the plan has it
	var pieces := 0
	for level in by_level:
		for item in by_level[level]["furniture"]:
			pieces += 1
			var rec: Dictionary = plan.furniture[item["index"]]
			if Rect2(rec["rect"]) != Rect2(item["rect"]):
				bad.append("piece %d drawn at %s, plan has %s" % [item["index"], item["rect"], rec["rect"]])
	if pieces != plan.furniture.size():
		bad.append("%d furniture pieces drawn, plan has %d" % [pieces, plan.furniture.size()])

	# stairs: a flight on the lower storey, a well on the upper
	for si in range(plan.stairs.size()):
		var st: Dictionary = plan.stairs[si]
		var low := 0
		var high := 0
		for level in by_level:
			for d in by_level[level]["stairs"]:
				if d["stair"] != si:
					continue
				if bool(d["up"]) and int(level) == int(st["storey"]):
					low += 1
				elif not bool(d["up"]) and int(level) == int(st["to_storey"]):
					high += 1
		if low != 1 or high != 1:
			bad.append("stair %d drawn %d flights and %d wells" % [si, low, high])

	# elevation
	var e: Dictionary = drawn["elevation"]
	var roof: Dictionary = e["roof"]
	if not plan.has_court():
		if not bool(roof["drawn"]):
			bad.append("no roof drawn")
		else:
			var ridge: float = HouseGeometry.ridge_of(spec)
			if absf(float(roof["ridge_y"]) - ridge) > 0.001:
				bad.append("elevation ridge %.4f, geometry says %.4f" % [roof["ridge_y"], ridge])
			var slab_top := -INF
			for row in builder.component_log:
				if String(row["role"]).begins_with("roof_face") and row["form"] == "slab":
					slab_top = maxf(slab_top, MassBuilder.component_aabb(row).end.y)
			if slab_top > -INF and absf(slab_top - HouseGeometry.RIDGE_SLAB_TOP - ridge) > 0.001 and not (spec is HotelSpec):
				bad.append("the built roof slabs top out at %.4f, the drawn ridge is %.4f (+%.2f slab)" % [slab_top, ridge, HouseGeometry.RIDGE_SLAB_TOP])
	if absf(float(e["wall_top"]) - spec.height * spec.storeys) > EPS:
		bad.append("elevation wall head %.3f, spec says %.3f" % [e["wall_top"], spec.height * spec.storeys])
	if absf(float(e["total_height"]) - builder.total_height) > 0.5 and not (spec is HotelSpec):
		bad.append("elevation height %.2f, builder reports %.2f" % [e["total_height"], builder.total_height])
	var want_windows := 0
	var want_doors := 0
	for w in plan.windows:
		if Vector2(w["normal"]).dot(Vector2(0, -1)) >= 0.5 and HousePlan.record_storey(w) >= 0:
			want_windows += 1
	for d in plan.doors:
		if bool(d["exterior"]) and Vector2(d["normal"]).dot(Vector2(0, -1)) >= 0.5 and HousePlan.record_storey(d) >= 0:
			want_doors += 1
	var got_windows := 0
	var got_doors := 0
	for op in e["openings"]:
		if op["kind"] == &"window":
			got_windows += 1
			var rec: Dictionary = plan.windows[op["index"]]
			var y0: float = float(op["level"]) * spec.height + float(rec["sill"])
			if absf(float(op["y0"]) - y0) > EPS:
				bad.append("window %d sill drawn at %.2f, plan %.2f" % [op["index"], op["y0"], y0])
		else:
			got_doors += 1
	if got_windows != want_windows:
		bad.append("%d front windows in the elevation, plan has %d on the -Z wall" % [got_windows, want_windows])
	if got_doors != want_doors:
		bad.append("%d front doors in the elevation, plan has %d on the -Z wall" % [got_doors, want_doors])
	if spec.chimney != not (e["chimney"] as Dictionary).is_empty():
		bad.append("chimney drawn %s, spec says %s" % [not (e["chimney"] as Dictionary).is_empty(), spec.chimney])
	return bad


static func _wall_bounds(wall: Dictionary) -> Rect2:
	var a: Vector2 = wall["from"]
	var b: Vector2 = wall["to"]
	var t: float = float(wall["thick"]) * 0.5
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(t, t)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(t, t)
	return Rect2(lo, hi - lo)


static func _positive(res: SuiteResult, who: String, plan: HousePlan, builder: HouseBuilder,
		drawn: Dictionary) -> void:
	var bad: Array[String] = compare(plan, builder, drawn)
	res.checked += 1
	for line in bad:
		res.fail("%s: %s" % [who, line])
	if bad.is_empty():
		res.note("%s: %d rooms, %d doors, %d windows, %d pieces, ridge %.2f m" % [who,
			plan.room_count(), plan.doors.size(), plan.windows.size(), plan.furniture.size(),
			float(drawn["elevation"]["roof"]["ridge_y"])])


## The plans fit their cells and their cells fit the page, at every page shape.
static func _layout(res: SuiteResult, who: String, drawn: Dictionary) -> void:
	var ext: Rect2 = drawn["extent"]
	for page in PAGES:
		var lay: Dictionary = HouseSheet.layout(drawn, page)
		var scale: float = lay["scale"]
		_expect(res, scale > 0.0, "%s: no scale on a %s page" % [who, page])
		var area := Rect2(Vector2.ZERO, page)
		for level in drawn["levels"]:
			var cell: Rect2 = lay["cells"][level]
			_expect(res, area.grow(0.01).encloses(cell), "%s: L%d cell %s leaves the %s page" % [who, level, cell, page])
			var to_paper: Callable = HouseSheet.plan_to_paper(cell, ext, scale)
			var a: Vector2 = to_paper.call(ext.position)
			var b: Vector2 = to_paper.call(ext.end)
			var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())
			# the dimension rail and the title sit outside the footprint but in the cell
			_expect(res, cell.grow(0.5).encloses(box),
				"%s: L%d plan %s is not inside its cell %s on a %s page" % [who, level, box, cell, page])
			_expect(res, absf(box.size.x - ext.size.x * scale) < 0.01 and absf(box.size.y - ext.size.y * scale) < 0.01,
				"%s: L%d plan is not drawn at one scale" % [who, level])


## All three roof types and both ridge directions: the drawn ridge is the
## builder's slab top, not a number the sheet kept for itself.
static func _roof_kinds(res: SuiteResult) -> void:
	for size in [Vector2(8, 12), Vector2(12, 8)]:
		var plan: HousePlan = _house(&"cottage", 4412, size.x, size.y, 2.6, 2)
		for kind in [&"gable", &"half_hipped", &"hipped"]:
			plan.spec.roof_type = kind
			var builder := HouseBuilder.new()
			builder.build(plan)
			var drawn: Dictionary = HouseSheet.drawing(plan)
			var bad: Array[String] = compare(plan, builder, drawn)
			res.checked += 1
			for line in bad:
				res.fail("%s %s: %s" % [kind, size, line])
			# a hipped roof has no gable wall to show: its hull is not a triangle
			var hull: PackedVector2Array = drawn["elevation"]["roof"]["hull"]
			res.checked += 1
			if hull.size() < 3:
				res.fail("%s %s: roof silhouette has %d points" % [kind, size, hull.size()])


static func _north(res: SuiteResult) -> void:
	var s := HouseSpec.new()
	_expect(res, HouseSheet.north_local(s).is_equal_approx(Vector2(0, 1)),
		"zero orientation faces south, so north is local +Z")
	s.orientation = PI
	_expect(res, HouseSheet.north_local(s).is_equal_approx(Vector2(0, -1)),
		"turned half way round, north is local -Z")
	s.orientation = PI * 0.5
	_expect(res, HouseSheet.north_local(s).is_equal_approx(Vector2(-1, 0)),
		"a quarter turn puts north on local -X")


# -------------------------------------------------------------------- controls

## Move one thing in a copy of the drawing and the comparator must say so. A
## comparator that cannot see these is not evidence of anything.
static func _controls(res: SuiteResult) -> void:
	var plan: HousePlan = _house(&"townhouse", 4411, 9.0, 12.0, 2.7, 2)
	var builder := HouseBuilder.new()
	builder.build(plan)
	var clean: Dictionary = HouseSheet.drawing(plan)
	_expect(res, compare(plan, builder, clean).is_empty(), "control: the unmoved drawing must match")

	var moved: Dictionary = clean.duplicate(true)
	var room: Dictionary = moved["by_level"][0]["rooms"][0]
	room["floor"] = Rect2(room["floor"]).abs()
	room["floor"] = Rect2(Rect2(room["floor"]).position + Vector2(0.5, 0), Rect2(room["floor"]).size)
	_expect(res, _mentions(compare(plan, builder, moved), "room 0"),
		"control: a room moved 0.5 m is reported")

	var gone: Dictionary = clean.duplicate(true)
	(gone["by_level"][0]["furniture"] as Array).pop_back()
	_expect(res, _mentions(compare(plan, builder, gone), "furniture pieces drawn"),
		"control: a missing piece of furniture is reported")

	var wall: Dictionary = clean.duplicate(true)
	var door: Dictionary = wall["by_level"][0]["doors"][0]
	door["off"] = 0.5
	_expect(res, _mentions(compare(plan, builder, wall), "from the nearest wall"),
		"control: a door half a metre off its wall is reported")

	var tall: Dictionary = clean.duplicate(true)
	tall["elevation"]["roof"]["ridge_y"] = float(tall["elevation"]["roof"]["ridge_y"]) + 0.3
	_expect(res, _mentions(compare(plan, builder, tall), "ridge"),
		"control: a ridge drawn 0.3 m high is reported")

	var shifted: Dictionary = clean.duplicate(true)
	var w0: Dictionary = shifted["by_level"][0]["walls"][0]
	w0["from"] = Vector2(w0["from"]) + Vector2(0.5, 0.5)
	_expect(res, _mentions(compare(plan, builder, shifted), "drawn"),
		"control: a wall moved 0.5 m off the mass the builder logged is reported")

	var lost: Dictionary = clean.duplicate(true)
	(lost["by_level"][0]["windows"] as Array).pop_back()
	_expect(res, _mentions(compare(plan, builder, lost), "windows drawn"),
		"control: a missing window is reported")


static func _mentions(bad: Array[String], needle: String) -> bool:
	for line in bad:
		if line.contains(needle):
			return true
	return false
