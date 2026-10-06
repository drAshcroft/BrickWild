class_name WorldCourtyardGenerator
extends RefCounted
## Shared planner for the WLD-001 courtyard family.
##
## The three historic sub-kinds differ in procession and water, not in shell
## topology: a rectangular ring of ranges around a sky court.  Keeping this
## here (rather than teaching HousePlanner a fourth programme) means the
## ordinary HouseBuilder, HouseFurnisher and HouseNavCheck all judge exactly
## what is emitted.

const FAMILY := &"courtyard_house"

static func generate(kind: StringName, p_seed: int, width: float, length: float,
		total_height: float, with_furniture := true) -> Dictionary:
	var storeys := 1 if kind == &"domus" else (2 if kind == &"riad" else 3)
	var floor_height := maxf(2.6, total_height / float(storeys))
	var spec := HouseSpec.new(p_seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = maxf(width, 12.0)
	spec.length = maxf(length, 15.0)
	spec.height = floor_height
	spec.storeys = storeys
	spec.trade = &"none"
	spec.wall_thickness_override = 0.6
	spec.roof_type = &"hipped"
	spec.roof_pitch = 0.55
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.plinth_height = 0.35
	spec.wall_color = Color("b9a98e")
	spec.trim_color = Color("665340")
	spec.roof_color = Color("4b3d32")
	spec.floor_color = Color("88785d")
	spec.clutter = 0.18
	spec.variant_name = _variant_name(kind)

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = kind
	plan.view_through = kind == &"domus"
	plan.blind_entry = kind == &"riad"
	plan.canal_wall = &"front" if kind == &"palazzo" else &""
	var inner := HouseGeometry.interior_rect(spec)
	# The palazzo's front fauces is also its portego. At the smallest
	# canonical scale the ordinary court lower bound leaves the front range a
	# fraction short of the far-wall run required by CourtCheck.water_gate.
	# Reserve a little more depth for this physical processional axis.
	var court := _court_rect(inner, floor_height, kind == &"palazzo")
	var room_ids: Array[Dictionary] = []
	for level in range(storeys):
		var rows := _add_ring_rooms(plan, inner, court, level, kind)
		room_ids.append(rows)
		plan.courts.append({"rect": court, "storey": level,
			"id": "court_%d" % level})

	_add_doors_and_windows(plan, inner, court, room_ids, kind, spec)
	_add_stairs(plan, room_ids, inner, storeys)
	_add_water(plan, court, kind, spec)
	plan.world_meta["court_rect"] = court
	plan.world_meta["street_door"] = _street_door_position(spec)
	plan.world_meta["shop_rooms"] = _shop_rooms(room_ids[0], kind)
	plan.world_meta["habitable_rooms"] = _habitable_rooms(plan)
	plan.world_meta["eave_height"] = floor_height
	plan.world_meta["water_gate"] = kind == &"palazzo"
	plan.world_meta["portego_room"] = int(room_ids[0][&"fauces"]) if kind == &"palazzo" else -1
	if kind == &"riad":
		# A low screen is the bent entrance: it blocks the direct street-to-yard
		# segment while the hall still opens into the court from the side.
		var fauces: Rect2 = plan.rooms[int(room_ids[0][&"fauces"])]["rect"]
		var screen_size := Vector2(maxf(0.35, fauces.size.x * 0.7),
			maxf(0.25, fauces.size.y * 0.12))
		plan.world_meta["blind_screen"] = Rect2(
			Vector2(fauces.get_center().x - screen_size.x * 0.5,
				fauces.position.y + fauces.size.y * 0.56), screen_size)

	if with_furniture:
		HouseFurnisher.furnish(plan, spec)
	if plan.view_through:
		_clear_view_axis(plan)
	# The family water feature is authored after furnishing so the furnisher
	# cannot mistake the open court for a room.  It is deliberately a floor
	# blocker only inside the impluvium, where CourtCheck.water permits it.
	_add_water_feature(plan, court, kind)
	for placement in plan.furniture:
		var room := int(placement.get("room", -1))
		placement["storey"] = plan.storey_of_room(room) if room >= 0 and room < plan.rooms.size() else 0
	return {"spec": spec, "plan": plan}


static func _variant_name(kind: StringName) -> String:
	match kind:
		&"domus": return "Merchant's Domus"
		&"riad": return "Riad of the Spice Road"
		&"palazzo": return "Canal Palazzo"
	return "Courtyard House"


static func _court_rect(inner: Rect2, eave: float, palazzo_portego := false) -> Rect2:
	var lower_bound := eave * (0.8 if palazzo_portego else 0.9)
	var side := clampf(minf(inner.size.x, inner.size.y) * 0.28,
		maxf(3.4, lower_bound), minf(inner.size.x, inner.size.y) * 0.42)
	var x := (inner.size.x - side) * 0.5
	var z := (inner.size.y - side) * 0.5
	return Rect2(inner.position + Vector2(x, z), Vector2(side, side))


## Six non-overlapping rectangles: three on the street range and three on the
## far/side ranges.  Their union plus the court is exactly the interior.
static func _add_ring_rooms(plan: HousePlan, inner: Rect2, court: Rect2,
		level: int, kind: StringName) -> Dictionary:
	var z0 := inner.position.y
	var z1 := court.position.y
	var z2 := court.end.y
	var z3 := inner.end.y
	var x0 := inner.position.x
	var x1 := court.position.x
	var x2 := court.end.x
	var x3 := inner.end.x
	var roles: Array[StringName] = [&"taberna_left", &"fauces", &"taberna_right",
		&"atrium", &"tablinum", &"peristyle"]
	var rects: Array[Rect2] = [
		Rect2(Vector2(x0, z0), Vector2(x1 - x0, z1 - z0)),
		Rect2(Vector2(x1, z0), Vector2(x2 - x1, z1 - z0)),
		Rect2(Vector2(x2, z0), Vector2(x3 - x2, z1 - z0)),
		Rect2(Vector2(x0, z1), Vector2(x1 - x0, z3 - z1)),
		Rect2(Vector2(x2, z1), Vector2(x3 - x2, z3 - z1)),
		Rect2(Vector2(x1, z2), Vector2(x2 - x1, z3 - z2)),
	]
	var ids: Dictionary = {}
	for i in range(rects.size()):
		var room_kind := _room_kind(kind, roles[i], level)
		ids[roles[i]] = plan.rooms.size()
		plan.rooms.append({"kind": room_kind, "role": roles[i],
			"rect": rects[i], "storey": level})
	return ids


## What each range of the ring is FOR, by sub-kind and storey. A role missing
## from a storey's row stays a gallery.
##
## Every range used to be a "gallery", whose recipe is a bookcase, banners and
## sconces -- so a walker found the Merchant's Domus "empty": three rooms of
## 60 to 115 square metres holding two lanterns between them. A courtyard house
## is a house. The domus ranges are a reception room, the triclinium (dining,
## its tables along the far wall, where the fauces-to-tablinum view axis
## `_clear_view_axis` keeps clear does not run -- a free table in the middle of
## the tablinum stood on that axis and was cleared away) and the cubicula
## (sleeping); the riad's are its
## reception and dining rooms below and its chambers above; the palazzo keeps
## its blind ground floor for the business and stores and lives on the piano
## nobile. The FAUCES -- the street passage, the palazzo's portego -- stays a
## gallery on every storey: it is the processional axis the view-through and
## water-gate rules walk, and furniture does not belong on it. A riad's upper
## peristyle range stays a gallery too; the galleries are what make it a riad.
const PROGRAMME := {
	&"domus": [
		{&"atrium": &"parlour", &"tablinum": &"dining_room", &"peristyle": &"bedroom"},
	],
	&"riad": [
		{&"atrium": &"parlour", &"tablinum": &"dining_room", &"peristyle": &"store"},
		{&"atrium": &"bedroom", &"tablinum": &"bedroom"},
	],
	&"palazzo": [
		{&"atrium": &"store", &"tablinum": &"office", &"peristyle": &"store"},
		# the sala of the piano nobile is a parlour: HousePlanCheck keeps a
		# "hall" (the entrance hall) on the ground floor
		{&"atrium": &"parlour", &"tablinum": &"bedroom", &"peristyle": &"dining_room"},
		{&"atrium": &"bedroom", &"tablinum": &"bedroom", &"peristyle": &"store"},
	],
}


static func _room_kind(kind: StringName, role: StringName, level: int) -> StringName:
	if role in [&"taberna_left", &"taberna_right"]:
		return &"sales_floor" if kind == &"domus" and level == 0 else &"store"
	var rows: Array = PROGRAMME.get(kind, [])
	if level < rows.size():
		return StringName((rows[level] as Dictionary).get(role, &"gallery"))
	return &"gallery"


static func _add_doors_and_windows(plan: HousePlan, inner: Rect2, court: Rect2,
		room_ids: Array[Dictionary], kind: StringName, spec: HouseSpec) -> void:
	var front := _street_door_position(spec)
	var ground: Dictionary = room_ids[0]
	var fauces := int(ground[&"fauces"])
	plan.doors.append({"a": fauces, "b": -1, "pos": front,
		"normal": Vector2(0, -1), "width": street_door_width(kind),
		"exterior": true, "front": true, "storey": 0,
		"role": "water_gate" if kind == &"palazzo" else "street_entry",
		"wall": "canal" if kind == &"palazzo" else "street",
		"sill": 0.12 if kind == &"palazzo" else 0.0})
	if kind == &"domus":
		for role in [&"taberna_left", &"taberna_right"]:
			var shop := int(ground[role])
			var rect: Rect2 = plan.rooms[shop]["rect"]
			var pair := taberna_openings(rect, inner.position.y, 2.1, 2.2)
			plan.doors.append({"a": shop, "b": -1, "pos": pair["door"],
				"normal": Vector2(0, -1), "width": 2.1,
				"exterior": true, "front": false, "storey": 0,
				"role": "taberna"})
			if float(pair["window_w"]) > 0.0:
				plan.windows.append({"room": shop, "pos": pair["window"],
					"normal": Vector2(0, -1), "width": float(pair["window_w"]),
					"sill": 2.25, "head": minf(spec.height - 0.25, 3.8),
					"storey": 0, "role": "taberna_display"})
		_add_high_side_windows(plan, inner, court, ground, spec)
	for level in range(room_ids.size()):
		var ids_for_level: Dictionary = room_ids[level]
		var fauces_for_level := int(ids_for_level[&"fauces"])
		for role in [&"taberna_left", &"taberna_right"]:
			# Domus tabernae open to the street only; a service door into the
			# residence would violate the shop's independent public programme.
			if kind == &"domus" and level == 0:
				continue
			var side_room := int(ids_for_level[role])
			var rect_side: Rect2 = plan.rooms[side_room]["rect"]
			var side_normal := Vector2(1, 0) if role == &"taberna_left" else Vector2(-1, 0)
			plan.doors.append({"a": side_room, "b": fauces_for_level, "pos":
				Vector2(rect_side.end.x if role == &"taberna_left" else rect_side.position.x,
					rect_side.get_center().y), "normal": side_normal,
				"width": 1.0, "exterior": false, "front": false,
				"storey": level, "role": "service_entry"})
	# Court openings are outward-facing from the range, but are not street
	# entrances.  b=-1 is intentional: the court is the shared outdoors.
	for level in range(room_ids.size()):
		var ids: Dictionary = room_ids[level]
		var rows := [[&"fauces", Vector2(0, 1)], [&"atrium", Vector2(1, 0)],
			[&"tablinum", Vector2(-1, 0)], [&"peristyle", Vector2(0, -1)]]
		for row in rows:
			var role: StringName = row[0]
			var n: Vector2 = row[1]
			var room := int(ids[role])
			var p := _court_edge(court, n)
			plan.doors.append({"a": room, "b": -1, "pos": p, "normal": n,
				"width": HouseGeometry.DOOR_W, "exterior": false,
				"front": false, "storey": level, "role": "court_entry"})
			var along := Vector2(n.y, -n.x)
			var span := court.size.x if absf(n.y) > 0.5 else court.size.y
			for t in [-0.28, 0.28]:
				plan.windows.append({"room": room, "pos": p + along * span * t,
					"normal": n, "width": HouseGeometry.WINDOW_W,
					"sill": HouseGeometry.WINDOW_SILL,
					"head": minf(spec.height - 0.25,
						HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H),
					"storey": level, "role": "court_window"})


## The street door's width. A domus's fauces is the house's one public
## entrance and was built wide -- a pair of leaves, often two metres and more
## -- where a 0.95 m cottage door left a walker squeezing past the jambs.
static func street_door_width(kind: StringName) -> float:
	match kind:
		&"domus": return 1.5
		&"palazzo": return 1.6     # a water gate takes a boat's cargo
	return HouseGeometry.DOOR_W   # a riad's bent entry is deliberately mean


## A shop front's door and its display window, SIDE BY SIDE on the street wall.
##
## They used to share one centre, the window over the door. `HouseBuilder`
## cuts a wall run as one opening per span, so the second opening on a span
## refilled the first: the walker found a door frame and a window frame round
## plain plaster ("what is this?"). The door goes on the side nearer the
## building's axis; a room too narrow for both keeps the door alone.
## `CourtCheck.shops` fails a stacked pair.
static func taberna_openings(rect: Rect2, wall_z: float, door_w: float,
		window_w: float) -> Dictionary:
	var gap := 0.6
	var margin := 0.45
	var c := rect.get_center().x
	var ww := minf(window_w, rect.size.x - margin * 2.0 - door_w - gap)
	if ww < 0.8:
		return {"door": Vector2(c, wall_z), "window": Vector2(c, wall_z), "window_w": 0.0}
	var total := door_w + gap + ww
	var toward_axis := 1.0 if c < 0.0 else -1.0
	return {"door": Vector2(c + toward_axis * (total / 2.0 - door_w / 2.0), wall_z),
		"window": Vector2(c - toward_axis * (total / 2.0 - ww / 2.0), wall_z),
		"window_w": ww}


## High windows in the domus's side and back walls, one every few metres of
## each room's run. A domus turns inward, so they stand above head height --
## light and air under the eaves, not a view in -- but a thirty-metre wall with
## nothing in it read as "really big empty wall?". These are the small high
## openings Pompeian houses do have on their flanks.
const SIDE_WINDOW_W := 0.7
const SIDE_WINDOW_SILL := 3.0
const SIDE_WINDOW_PITCH := 3.6

static func _add_high_side_windows(plan: HousePlan, inner: Rect2, _court: Rect2,
		ground: Dictionary, spec: HouseSpec) -> void:
	var head := minf(spec.height - 0.6, SIDE_WINDOW_SILL + 0.8)
	if head - SIDE_WINDOW_SILL < 0.5:
		return
	# (room role, wall, outward normal)
	var runs := [
		[&"taberna_left", Vector2(-1, 0)], [&"atrium", Vector2(-1, 0)],
		[&"taberna_right", Vector2(1, 0)], [&"tablinum", Vector2(1, 0)],
		[&"atrium", Vector2(0, 1)], [&"peristyle", Vector2(0, 1)],
		[&"tablinum", Vector2(0, 1)],
	]
	for run in runs:
		var room := int(ground[run[0]])
		var n: Vector2 = run[1]
		var rect: Rect2 = plan.rooms[room]["rect"]
		var along_x := absf(n.y) > 0.5
		var lo := rect.position.x if along_x else rect.position.y
		var hi := rect.end.x if along_x else rect.end.y
		var usable := hi - lo - 1.2
		if usable < SIDE_WINDOW_W:
			continue
		var count := int(floor(usable / SIDE_WINDOW_PITCH)) + 1
		for i in range(count):
			var t := lo + (hi - lo) * (float(i) + 0.5) / float(count)
			var pos := Vector2(t, inner.end.y) if along_x \
				else Vector2(inner.position.x if n.x < 0.0 else inner.end.x, t)
			plan.windows.append({"room": room, "pos": pos, "normal": n,
				"width": SIDE_WINDOW_W, "sill": SIDE_WINDOW_SILL, "head": head,
				"storey": 0, "role": "high_side_window"})


static func _court_edge(court: Rect2, n: Vector2) -> Vector2:
	if absf(n.x) > 0.5:
		return Vector2(court.end.x if n.x < 0.0 else court.position.x,
			court.get_center().y)
	return Vector2(court.get_center().x,
		court.end.y if n.y < 0.0 else court.position.y)


static func _add_stairs(plan: HousePlan, ids: Array[Dictionary], inner: Rect2,
		storeys: int) -> void:
	for level in range(storeys - 1):
		var lower := int(ids[level][&"tablinum"])
		var upper := int(ids[level + 1][&"tablinum"])
		var room: Rect2 = plan.rooms[lower]["rect"]
		var w := minf(1.4, room.size.x * 0.35)
		var d := minf(3.0, room.size.y * 0.45)
		var r := Rect2(Vector2(room.end.x - w - 0.03, room.position.y + 0.3),
			Vector2(w, d))
		plan.stairs.append({"a": lower, "b": upper, "storey": level,
			"to_storey": level + 1, "pos": r.get_center(),
			"lower_pos": r.get_center(), "upper_pos": r.get_center(),
			"rect": r, "lower_rect": r, "upper_rect": r,
			"width": w, "run": d, "steps": maxi(10, int(spec_steps(plan.spec)))})


static func spec_steps(spec: HouseSpec) -> float:
	return maxf(10.0, spec.height / 0.28)


static func _add_water(plan: HousePlan, court: Rect2, kind: StringName,
		spec: HouseSpec) -> void:
	var pool := Rect2(court.get_center() - court.size * 0.16, court.size * 0.32)
	plan.water_plane = 0.04
	plan.roof_openings.append({"id": "%s_compluvium" % String(kind),
		"kind": &"compluvium", "storey": plan.spec.storeys - 1,
		"face": -1, "rect": court, "room": -1, "impluvium": pool})
	plan.world_meta["water_rect"] = pool
	plan.world_meta["water_pos"] = pool.get_center()
	plan.world_meta["water_kind"] = &"fountain" if kind == &"riad" else &"well"
	if kind == &"palazzo":
		plan.world_meta["canal_wall"] = &"front"
		plan.world_meta["water_gate_sill"] = 0.12
		plan.world_meta["portego_axis"] = Vector2(0, 1)


static func _add_water_feature(plan: HousePlan, court: Rect2, kind: StringName) -> void:
	var pool: Rect2 = Rect2(plan.world_meta.get("water_rect", court))
	var centre := pool.get_center()
	var water_room := -1
	for i in range(plan.rooms.size()):
		if plan.rooms[i].get("role", &"") == &"fauces" and plan.storey_of_room(i) == 0:
			water_room = i
			break
	plan.furniture.append({"key": "Barrel",
		"room": water_room, "pos": Vector3(centre.x, plan.water_plane, centre.y),
		"yaw": 0.0, "rect": pool.grow(-0.18), "zone": pool,
		"host": -1, "cat": "barrel", "storey": 0, "mounted": true,
		"world_water": true, "water_kind": "fountain" if kind == &"riad" else "well"})


static func _clear_view_axis(plan: HousePlan) -> void:
	var street := Vector2(plan.world_meta.get("street_door", Vector2.ZERO))
	var target := Vector2.ZERO
	for i in range(plan.rooms.size()):
		if plan.rooms[i].get("role", &"") == &"tablinum" and plan.storey_of_room(i) == 0:
			target = HouseGeometry.room_floor_rect(plan, i).get_center()
			break
	# A placement that stands ON another (the plates on a table) goes with its
	# host, and every surviving `host` index is renumbered. Keeping hosted
	# pieces unconditionally left the parlour's plates and candlestick
	# floating at table height over the floor where the table had been, and
	# pointed every later host index at the wrong piece.
	var removed := {}
	for i in range(plan.furniture.size()):
		var placement: Dictionary = plan.furniture[i]
		if placement.get("mounted", false) or int(placement.get("host", -1)) >= 0:
			continue
		# the same continuous ray `CourtCheck.view_through` casts, not 25
		# samples along it: a long thin table can lie between two samples
		var rect: Rect2 = placement.get("rect", Rect2())
		if not rect.has_area():
			continue
		var box := AABB(Vector3(rect.position.x, 0.0, rect.position.y),
			Vector3(rect.size.x, plan.spec.height, rect.size.y))
		if not Sightline.clear(Vector3(street.x, 1.2, street.y),
				Vector3(target.x, 1.2, target.y), [box]):
			removed[i] = true
	var changed := true
	while changed:
		changed = false
		for i in range(plan.furniture.size()):
			var host := int(plan.furniture[i].get("host", -1))
			if not removed.has(i) and host >= 0 and removed.has(host):
				removed[i] = true
				changed = true
	var renumber := {}
	var kept: Array[Dictionary] = []
	for i in range(plan.furniture.size()):
		if removed.has(i):
			continue
		renumber[i] = kept.size()
		kept.append(plan.furniture[i])
	for placement in kept:
		var host := int(placement.get("host", -1))
		if host >= 0:
			placement["host"] = int(renumber.get(host, -1))
	plan.furniture = kept


static func _street_door_position(spec: HouseSpec) -> Vector2:
	var inner := HouseGeometry.interior_rect(spec)
	return Vector2(inner.get_center().x, inner.position.y)


static func _shop_rooms(ground: Dictionary, kind: StringName) -> Array[int]:
	if kind != &"domus":
		return []
	return [int(ground[&"taberna_left"]), int(ground[&"taberna_right"])]


static func _habitable_rooms(plan: HousePlan) -> Array[int]:
	var out: Array[int] = []
	for i in range(plan.rooms.size()):
		if HouseGeometry.is_habitable(plan.kind_of(i)):
			out.append(i)
	return out
