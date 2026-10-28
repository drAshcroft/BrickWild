class_name ShopPlanner
extends RefCounted
## Adapts the domestic subdivision engine to a public-first workplace plan.


static func plan(spec: ShopSpec) -> HousePlan:
	var out: HousePlan = HousePlanner.plan(spec)
	if spec.business == &"palace":
		_plan_palace(out)
		return out
	# HousePlanner needs a hall while it establishes the entrance and stair
	# spine. Once that topology is fixed, the public room takes its real role.
	var front := -1
	if spec.business == &"prison":
		# The domestic name pass intentionally de-duplicates repeated programme
		# kinds. A prison has many identical cells and corridors, so restore its
		# authored room roles from the stable custom-rectangle order.
		var layout := spec.prison_layout(HouseGeometry.interior_rect(spec))
		var rects := spec.prison_room_rects(HouseGeometry.interior_rect(spec))
		var aisle_n: int = (layout["aisles"] as Array).size() if not layout.is_empty() else 0
		if rects.size() != out.rooms_on_storey(0).size():
			push_error("ShopPlanner: prison custom room count does not match its authored layout")
		else:
			for i in rects.size():
				if i == 0:
					out.rooms[i]["kind"] = &"guardroom"
				elif i <= aisle_n:
					out.rooms[i]["kind"] = &"corridor"
				else:
					out.rooms[i]["kind"] = &"cell"
			for i in rects.size():
				if i > 0 and i <= aisle_n:
					for lower in out.rooms_on_storey(-1):
						if Rect2(out.rooms[lower]["rect"]).is_equal_approx(rects[i]):
							out.rooms[lower]["kind"] = &"corridor"
		front = 0
	else:
		for i in range(out.room_count()):
			if out.kind_of(i) == &"hall":
				out.rooms[i]["kind"] = spec.front_room()
				if front < 0:
					front = i
	# The public room is the one the street door opens into. When the house
	# planner had to put the door somewhere other than its hall, the room it
	# chose becomes the front room and the hall takes that room's kind -- a
	# stable whose stall room is not on the street is not a stable (LAY-009).
	var entrance: int = out.entrance_room()
	var street_front: bool = spec.door_w() >= 1.2 or not spec.front_open().is_empty()
	if spec.business != &"prison" and street_front and front >= 0 and entrance >= 0 and entrance != front \
			and out.storey_of_room(entrance) == 0 \
			and HouseGeometry.room_suits(out, entrance, spec.front_room()):
		var was: StringName = out.kind_of(entrance)
		out.rooms[entrance]["kind"] = spec.front_room()
		out.rooms[front]["kind"] = was
		front = entrance
	if front >= 0:
		_cut_shopfront(out, spec, front)
		_light_workshops(out, spec)
		_hold_the_fire_wall(out, spec, front)
		_choose_focus(out, spec, front)
		if spec.business == &"library":
			_pin_library_focus_to_daylight(out, front)
	if spec.business == &"prison":
		_plan_prison_access(out)
		_walk_the_cellar_stair(out)
	if spec.business == &"market_hall" and front >= 0:
		_plan_market_colonnade(out, front)
	if spec.business == &"thieves_den":
		_plan_thieves_den(out)
	_open_up_lodging(out)
	_join_store_to_work_room(out, spec)
	_cut_yard_door(out, spec)
	return out


## SHOP-ARCHETYPE-RED. The house planner digs a prison's cellar with the legacy
## 2.4 m flight, which over a 2.9 m drop is a ladder: no step count, no head
## landing, no rails. Re-lay each cellar stair as the walkable flight a keep
## gets (CastleKeepPlan.walkable_flight), on the domestic rail profile; where
## no flight fits the legacy record stays and the check says so.
static func _walk_the_cellar_stair(plan: HousePlan) -> void:
	for i in range(plan.stairs.size()):
		var old: Dictionary = plan.stairs[i]
		if int(old.get("storey", 0)) >= 0 or bool(old.get("domestic_profile", false)):
			continue
		var kept: Array[Dictionary] = plan.stairs.duplicate()
		plan.stairs.remove_at(i)
		var flight := CastleKeepPlan.walkable_flight(plan, int(old["a"]), int(old["b"]),
			int(old["storey"]), int(old["to_storey"]))
		if flight.is_empty() or not flight.has("head_landing"):
			plan.stairs.assign(kept)
			continue
		flight["domestic_profile"] = true
		plan.stairs.insert(i, flight)


## The rooms a trade is worked in, and the rooms its stock is kept in.
const WORK_ROOM_KINDS: Array[StringName] = [&"workshop", &"kitchen", &"laboratory", &"bakehouse"]
const STORE_ROOM_KINDS: Array[StringName] = [&"store", &"storeroom", &"pantry", &"stock_room"]


## SHOP-STORE-JOIN. The house planner hangs every leaf off the first public
## room that touches it, so an apothecary's, butcher's or tailor's store can
## open only off the sales floor while the workshop that fills it has no door
## to it: stock is then carried out through the shop. Where a work room and a
## store touch along a usable wall and nothing joins them, cut that door. A
## shop with no touching pair is left as it is.
static func _join_store_to_work_room(out: HousePlan, spec: ShopSpec) -> void:
	if spec.business in [&"palace", &"prison", &"thieves_den", &"barracks", &"market_hall"]:
		return
	var need: float = HousePlanOpenings._inner_door_width(out) + HouseGeometry.DOOR_CORNER_MARGIN * 2.0
	var best := []
	var best_run := 0.0
	for w in out.rooms_on_storey(0):
		if not out.kind_of(w) in WORK_ROOM_KINDS:
			continue
		for s in out.rooms_on_storey(0):
			if not out.kind_of(s) in STORE_ROOM_KINDS:
				continue
			if HousePlanOpenings._door_between(out, w, s):
				return   # a store already opens off a work room
			var edge: Array = HousePlanOpenings.shared_edge(out, w, s)
			if edge.is_empty():
				continue
			var run: float = float(edge[3]) - float(edge[2])
			if run >= need and run > best_run:
				best_run = run
				best = [w, s, edge]
	if not best.is_empty():
		HousePlanOpenings.add_inner_door(out, best[0], best[1], best[2])


## A shop of this many rooms (15 m2 of interior each, so 75 m2 and up) is a
## working yard's worth of business: goods and fuel come in by a door that is
## not the customers'. The 11 x 14 m shops of the walk are 6 rooms; the 9 x 12
## m ones are 5.
const YARD_DOOR_ROOMS := 5


## SHOP-SECOND-DOOR (walk pin WALK-1a17a581-1, "only one door on a giant
## house"). The house planner's back door is a 70 percent draw, wants a store
## or kitchen on the rear wall and ignores the work room. A large shop with no
## door but the street's gets a yard door on a store that opens off its work
## room, or on the work room itself (a side wall by
## preference, then the rear), at the end of the wall farthest from the street
## door. Windows it lands on give way, as for the shopfront hatch.
static func _cut_yard_door(out: HousePlan, spec: ShopSpec) -> void:
	if spec.business in [&"palace", &"prison", &"thieves_den", &"barracks", &"market_hall"] \
		or spec.room_count < YARD_DOOR_ROOMS:
		return
	var work: Array[int] = []
	for i in out.rooms_on_storey(0):
		if out.kind_of(i) in WORK_ROOM_KINDS:
			work.append(i)
	if work.is_empty():
		return
	# a yard door the work room already has, or has through its store
	for w in work:
		for di in out.doors_of(w):
			var d: Dictionary = out.doors[di]
			var other := int(d["b"]) if int(d["a"]) == w else int(d["a"])
			if bool(d.get("exterior", false)):
				if not bool(d.get("front", false)):
					return
			elif other >= 0 and out.kind_of(other) in STORE_ROOM_KINDS:
				for dj in out.doors_of(other):
					var e: Dictionary = out.doors[dj]
					if bool(e.get("exterior", false)) and not bool(e.get("front", false)):
						return
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var width: float = HousePueblo.door_w(spec)
	var m: float = HouseGeometry.DOOR_CORNER_MARGIN + width * 0.5
	var street: Vector2 = Vector2(out.doors[out.entrance()]["pos"]) if out.entrance() >= 0 else inner.get_center()
	# A store that opens off the work room is the better host: goods and fuel
	# come in by it, and a smithy's or joiner's floor keeps the walk-clear
	# metres of door for the fire and the bench.
	var hosts: Array[int] = []
	var store_hosts := {}
	for w in work:
		for di in out.doors_of(w):
			var d: Dictionary = out.doors[di]
			var other := int(d["b"]) if int(d["a"]) == w else int(d["a"])
			if not bool(d.get("exterior", false)) and other >= 0 and out.kind_of(other) in STORE_ROOM_KINDS \
		and out.storey_of_room(other) == 0 and not hosts.has(other):
				hosts.append(other)
				store_hosts[other] = true
	for w in work:
		hosts.append(w)
	var best := {}
	var best_score := -INF
	for w in hosts:
		var r: Rect2 = out.rooms[w]["rect"]
		# [normal, wall line, lo, hi] for each wall the room shares with the outside
		var walls: Array = []
		if absf(r.position.x - inner.position.x) < 0.01:
			walls.append([Vector2(-1, 0), inner.position.x, r.position.y, r.end.y, 1.0])
		if absf(r.end.x - inner.end.x) < 0.01:
			walls.append([Vector2(1, 0), inner.end.x, r.position.y, r.end.y, 1.0])
		if absf(r.end.y - inner.end.y) < 0.01:
			walls.append([Vector2(0, 1), inner.end.y, r.position.x, r.end.x, 0.0])
		for wall in walls:
			var normal: Vector2 = wall[0]
			var line: float = wall[1]
			var lo: float = float(wall[2]) + m
			var hi: float = float(wall[3]) - m
			if hi < lo:
				continue
			# the end farthest from the street door, then the middle, then the nearer end
			var along_street: float = street.y if absf(normal.x) > 0.5 else street.x
			var ends: Array = [lo, hi]
			ends.sort_custom(func(a: float, b: float) -> bool: return absf(a - along_street) > absf(b - along_street))
			ends.insert(1, (lo + hi) * 0.5)
			for t in ends:
				var pos: Vector2 = Vector2(line, t) if absf(normal.x) > 0.5 else Vector2(t, line)
				if _yard_door_clear(out, spec, pos, normal, width):
					var score: float = (100.0 if store_hosts.has(w) else 0.0) + float(wall[4]) * 10.0 + absf(t - along_street) + float(wall[3]) - float(wall[2])
					if score > best_score:
						best_score = score
						best = {"room": w, "pos": pos, "normal": normal}
					break
	if best.is_empty():
		return
	var pos: Vector2 = best["pos"]
	var normal: Vector2 = best["normal"]
	var keep: Array[Dictionary] = []
	for win in out.windows:
		if HousePlan.record_storey(win) == 0 and absf(Vector2(win["normal"]).x) == absf(normal.x) 				and (Vector2(win["pos"]) - pos).length() < (float(win["width"]) + width) * 0.5 + 0.15 \
		and not bool(win.get("hatch", false)):
			continue
		keep.append(win)
	out.windows = keep
	var door := {"a": int(best["room"]), "b": -1, "pos": pos, "normal": normal,
		"width": width, "exterior": true, "front": false, "storey": 0, "yard": true}
	HousePlanOpenings._set_domestic_door_head(out, door)
	out.doors.append(door)


## Is there room for a yard door at `pos`: clear of every other door, of the
## chimney flue, and of the street wall's hatch?
static func _yard_door_clear(out: HousePlan, spec: ShopSpec, pos: Vector2, normal: Vector2,
		width: float) -> bool:
	if HousePlanner.flue_blocks(out, pos, normal, 0):
		return false
	var opening := HouseGeometry.door_opening_rect(spec, {"pos": pos, "normal": normal, "width": width})
	for d in out.doors:
		if HousePlan.record_storey(d) != 0:
			continue
		# an inner door within a metre of the line the yard door opens onto
		if (Vector2(d["pos"]) - pos).length() < (float(d["width"]) + width) * 0.5 + 0.5:
			return false
		if HouseGeometry.door_opening_rect(spec, d).grow(0.1).intersects(opening):
			return false
	return true


## Keep the street-facing shop ordinary. The only route from it into the
## marked private rooms crosses one explicitly secret interior door.
static func _plan_thieves_den(plan: HousePlan) -> void:
	var bays: Array[int] = plan.rooms_on_storey(0)
	bays.sort_custom(func(a: int, b: int) -> bool:
		return Rect2(plan.rooms[a]["rect"]).get_center().x \
			< Rect2(plan.rooms[b]["rect"]).get_center().x)
	if bays.size() != 3:
		push_error("ShopPlanner: thieves' den needs three adjoining bays")
		return
	# HousePlanRooms assigns a service-hungry dormitory before the store. In
	# this authored left-to-right topology the roles themselves are spatial:
	# street sales -> concealed store -> private dormitory.
	var sales: int = bays[0]
	var store: int = bays[1]
	var dormitory: int = bays[2]
	plan.rooms[sales]["kind"] = &"sales_floor"
	plan.rooms[store]["kind"] = &"store"
	plan.rooms[dormitory]["kind"] = &"dormitory"
	for i in range(plan.doors.size() - 1, -1, -1):
		if not bool(plan.doors[i].get("exterior", false)):
			plan.doors.remove_at(i)
	plan.rooms[store]["secret"] = true
	plan.rooms[dormitory]["secret"] = true
	plan.windows = plan.windows.filter(func(window: Dictionary) -> bool:
		return int(window.get("room", -1)) != store and int(window.get("room", -1)) != dormitory)
	var hidden_edge := HousePlanOpenings.shared_edge(plan, sales, store)
	var rear_edge := HousePlanOpenings.shared_edge(plan, store, dormitory)
	if hidden_edge.is_empty() or rear_edge.is_empty():
		push_error("ShopPlanner: thieves' den bays do not form a continuous route")
		return
	HousePlanOpenings.add_inner_door(plan, sales, store, hidden_edge)
	plan.doors.back()["secret"] = true
	HousePlanOpenings.add_inner_door(plan, store, dormitory, rear_edge)


## Give the throne hall its declared chain and rear branch doors. The generic
## house planner supplies shell openings; the palace owns this interior graph.
static func _plan_palace(plan: HousePlan) -> void:
	if plan.room_count() != 4:
		push_error("ShopPlanner: palace needs exactly four authored rooms")
		return
	var kinds: Array[StringName] = [&"antechamber", &"throne_room", &"treasury", &"royal_chamber"]
	for i in kinds.size():
		plan.rooms[i]["kind"] = kinds[i]
	# The throne axis stays centred on the actual entrance, including the case
	# where rounding in the exterior wall left it a few centimetres off-centre.
	var entrance := plan.entrance()
	if entrance < 0:
		push_error("ShopPlanner: palace has no entrance")
		return
	var entrance_x: float = plan.doors[entrance]["pos"].x
	for d in range(plan.doors.size() - 1, -1, -1):
		if not bool(plan.doors[d].get("exterior", false)):
			plan.doors.remove_at(d)
	for branch in [2, 3]:
		var edge: Array = HousePlanOpenings.shared_edge(plan, 1, branch)
		if edge.is_empty():
			push_error("ShopPlanner: palace rear branch does not meet its throne room")
			continue
		HousePlanOpenings.add_inner_door(plan, 1, branch, edge)
	var entry_edge: Array = HousePlanOpenings.shared_edge(plan, 0, 1)
	if entry_edge.is_empty():
		push_error("ShopPlanner: palace antechamber does not meet its throne room")
	else:
		HousePlanOpenings.add_inner_door(plan, 0, 1, entry_edge)
	# Treasury is secure and deliberately unglazed. The royal chamber retains
	# its outside windows and is a leaf in the room graph.
	plan.windows = plan.windows.filter(func(w: Dictionary) -> bool:
		return int(w["room"]) != 2)
	plan.hearth = {}
	var throne_room := HouseGeometry.room_floor_rect(plan, 1)
	var dais_width := minf(4.2, throne_room.size.x - 1.0)
	var dais_depth := minf(3.0, throne_room.size.y * 0.48)
	var dais := Rect2(Vector2(entrance_x - dais_width * 0.5,
		throne_room.end.y - dais_depth - 0.75), Vector2(dais_width, dais_depth))
	plan.dais = {"room": 1, "rect": dais, "rise": 0.25}
	plan.focus = {"room": 1, "cat": "seat",
		"pos": Vector2(entrance_x, dais.get_center().y),
		"facing": 0.0, "faces_door": false}


## Place a measured banner on either side wall at the throne's depth. These
## wall records carry no floor rectangle, so the axis and walking checks read
## them without treating them as obstacles.
static func place_palace_banners(plan: HousePlan) -> bool:
	var room := plan.focus_room()
	if room < 0 or plan.kind_of(room) != &"throne_room":
		return false
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var base: float = HouseFurnishGeometry.storey_base(plan, room)
	var key := "Banner_2"
	var height := PropCatalog.height(key)
	var centre_y := minf(plan.spec.height - height * 0.5, 1.85)
	# Both banners hang on the rear wall, with the throne between them. Their
	# measured width is the span along this wall; test both stations together so
	# a rear-branch door cannot steal one half of the pair.
	var wall: Dictionary = walls[1]
	var normal := Vector2(wall["normal"])
	var lower_x: float = float(wall["from"].x) + PropCatalog.size(key).x * 0.5 + 0.2
	var upper_x: float = float(wall["to"].x) - PropCatalog.size(key).x * 0.5 - 0.2
	var banner_distance := 0.0
	var found := false
	var bw: float = PropCatalog.size(key).x
	# The ordinary furnisher has already hung its wall torches, mirrored about a
	# rear door rather than about the throne. They are movable lighting; the
	# banners are the throne room's declared axis. So the station search ignores
	# sconces (doors, windows and other mounted pieces still veto a station) and
	# the sconces that end up under a banner are re-hung beyond it.
	for step in range(24):
		var distance := 2.4 + float(step) * 0.15
		var left := Vector2(plan.focus_pos().x - distance, float(wall["from"].y))
		var right := Vector2(plan.focus_pos().x + distance, float(wall["from"].y))
		if left.x < lower_x or right.x > upper_x:
			continue
		var clear_pair := true
		for point in [left, right]:
			if HouseFurnishScore._on_opening(plan, room, point, normal, bw) 					or HouseFurnishScore._crowds_mounted(plan, room, point, bw, "sconce"):
				clear_pair = false
		if clear_pair:
			banner_distance = distance
			found = true
			break
	if not found:
		push_error("ShopPlanner: palace cannot find a mirrored banner station")
		return false
	_rehang_sconces_clear_of_banners(plan, room, normal, plan.focus_pos().x,
		float(wall["from"].y), banner_distance, bw, float(wall["from"].x), float(wall["to"].x))
	for side in [-1.0, 1.0]:
		var point := Vector2(plan.focus_pos().x + banner_distance * side,
			float(wall["from"].y)) + normal * 0.02
		var yaw := HouseFurnishGeometry.yaw_facing(normal)
		plan.furniture.append({"key": key, "room": room,
			"storey": HousePlan.record_storey(plan.rooms[room]),
			"pos": Vector3(point.x, base + centre_y, point.y), "yaw": yaw,
			"rect": Rect2(point - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
			"zone": Rect2(), "host": -1, "cat": "banner",
			"mounted": true, "scale": 1.0})
	return true


## Sconces that sit within a banner's span move out beyond the pair, mirrored
## about the throne axis. If no clear mirrored station exists they are dropped
## with a warning: lighting is optional, the axis is not.
static func _rehang_sconces_clear_of_banners(plan: HousePlan, room: int, normal: Vector2,
		axis_x: float, wall_y: float, banner_distance: float, bw: float,
		wall_from_x: float, wall_to_x: float) -> void:
	var template := {}
	var lamp_w := 0.0
	var moved := 0
	for f in range(plan.furniture.size() - 1, -1, -1):
		var p: Dictionary = plan.furniture[f]
		if int(p.get("room", -1)) != room or not bool(p.get("mounted", false)) 				or PropCatalog.category(String(p["key"])) != "sconce":
			continue
		if absf(float(p["pos"].z) - wall_y) > 0.2:
			continue
		lamp_w = maxf(PropCatalog.size(String(p["key"])).x, 0.05)
		if absf(absf(float(p["pos"].x) - axis_x) - banner_distance) < (bw + lamp_w) * 0.5 + 0.1:
			template = p.duplicate(true)
			plan.furniture.remove_at(f)
			moved += 1
	if moved == 0:
		return
	var base_d := banner_distance + (bw + lamp_w) * 0.5 + 0.15
	var d := base_d
	while axis_x - d >= wall_from_x + lamp_w and axis_x + d <= wall_to_x - lamp_w:
		var ok := true
		for side in [-1.0, 1.0]:
			var pt := Vector2(axis_x + d * side, wall_y)
			if HouseFurnishScore._on_opening(plan, room, pt, normal, lamp_w) 					or HouseFurnishScore._crowds_mounted(plan, room, pt, lamp_w):
				ok = false
		if ok:
			for side in [-1.0, 1.0]:
				var lamp: Dictionary = template.duplicate(true)
				var pos3: Vector3 = lamp["pos"]
				pos3.x = axis_x + d * side
				lamp["pos"] = pos3
				var r: Rect2 = lamp["rect"]
				r.position.x = pos3.x - r.size.x * 0.5
				lamp["rect"] = r
				plan.furniture.append(lamp)
			return
		d += HouseFurnishScore.MOUNT_STEP
	push_warning("ShopPlanner: palace sconces displaced by banners found no mirrored station")


## The market hall's open arcade is plan data. Its front doorway remains a
## masonry portal, leaving two visible colonnade spans on that elevation.
static func _plan_market_colonnade(plan: HousePlan, room: int) -> void:
	var walls := HouseGeometry.room_walls(plan, room)
	var kinds: Array[StringName] = []
	for _wall in walls:
		kinds.append(&"colonnade")
	var entrance := plan.entrance()
	if entrance < 0:
		return
	var door: Dictionary = plan.doors[entrance]
	var door_pos: Vector2 = door["pos"]
	var portal_wall := -1
	var portal_at := 0.0
	var portal_distance := INF
	for wi in walls.size():
		var wall: Dictionary = walls[wi]
		var nearest := Geometry2D.get_closest_point_to_segment(door_pos,
			wall["from"], wall["to"])
		var distance := nearest.distance_to(door_pos)
		if distance < portal_distance:
			portal_distance = distance
			portal_wall = wi
			portal_at = (nearest - Vector2(wall["from"])).dot(
				(Vector2(wall["to"]) - Vector2(wall["from"])).normalized())
	if portal_wall < 0 or portal_distance > HouseGeometry.wall_thickness(plan.spec) * 0.6:
		push_error("ShopPlanner: market hall entrance is not on a room wall")
		return
	var portal_width := maxf(float(door["width"]) + 0.9, 2.8)
	var portal := {"centre": portal_at, "width": portal_width,
		"start": maxf(0.35, portal_at - portal_width * 0.5),
		"end": minf(walls[portal_wall]["from"].distance_to(walls[portal_wall]["to"]) - 0.35,
			portal_at + portal_width * 0.5)}
	if float(portal["end"]) <= float(portal["start"]):
		push_error("ShopPlanner: market hall entrance portal does not fit its front wall")
		return
	plan.rooms[room]["wall_kinds"] = kinds
	var wall_portals: Dictionary = {}
	wall_portals[portal_wall] = portal
	plan.rooms[room]["wall_portals"] = wall_portals
	# The arcade walls are open air, not window hosts. Remove openings that the
	# ordinary room planner laid on those spans so neither the mesh nor QA
	# expects glazing trim in a colonnade.
	for wi in range(plan.windows.size() - 1, -1, -1):
		if int(plan.windows[wi].get("room", -1)) == room:
			plan.windows.remove_at(wi)
	plan.columns.clear()
	const POST := 0.30
	const PITCH := 2.6
	for wi in walls.size():
		var wall: Dictionary = walls[wi]
		var from: Vector2 = wall["from"]
		var to: Vector2 = wall["to"]
		var length := from.distance_to(to)
		var spans: Array[Vector2] = []
		if wi == portal_wall:
			spans = [Vector2(0.0, float(portal["start"])),
				Vector2(float(portal["end"]), length)]
		else:
			spans = [Vector2(0.0, length)]
		for span in spans:
			var span_length := span.y - span.x
			if span_length < POST:
				continue
			var bays := maxi(1, ceili(span_length / PITCH))
			for post_index in range(bays + 1):
				var t := lerpf(span.x, span.y, float(post_index) / float(bays))
				var pos := from.lerp(to, t / length) \
					- Vector2(wall["normal"]) * HouseGeometry.wall_thickness(plan.spec) * 0.5
				var duplicate := false
				for existing in plan.columns:
					if Vector2(existing["pos"]).distance_to(pos) < POST * 0.8:
						duplicate = true
						break
				if duplicate:
					continue
				plan.columns.append({"kind": &"colonnade", "room": room, "wall": wi,
					"storey": plan.storey_of_room(room), "pos": pos,
					"size": Vector2(POST, POST), "height": plan.spec.height - 0.26})


## Replace the generic spanning tree with parallel guard passages. Every
## corridor reaches the guardroom without a key; each cell is a locked leaf.
## The cellar clone below one cell is the sealed oubliette, entered only by its
## recorded trapdoor and omitted from ordinary door reachability.
static func _plan_prison_access(plan: HousePlan) -> void:
	var guardroom := -1
	var corridors: Array[int] = []
	var cells: Array[int] = []
	for i in range(plan.room_count()):
		if plan.storey_of_room(i) != 0:
			continue
		match plan.kind_of(i):
			&"guardroom": guardroom = i
			&"corridor": corridors.append(i)
			&"cell": cells.append(i)
	if guardroom < 0 or corridors.is_empty() or cells.size() < 3:
		push_error("ShopPlanner: prison layout is missing its guardroom, corridors, or cells")
		return
	# HousePlanner supplied a valid provisional tree. Replace only its ground
	# floor interior edges; cellar copies keep their independent service route.
	for d in range(plan.doors.size() - 1, -1, -1):
		var door: Dictionary = plan.doors[d]
		if not bool(door.get("exterior", false)) and plan.storey_of_room(int(door["a"])) == 0:
			plan.doors.remove_at(d)
	for corridor in corridors:
		var entry: Array = HousePlanOpenings.shared_edge(plan, guardroom, corridor)
		if entry.is_empty():
			push_error("ShopPlanner: prison corridor does not meet the guardroom")
			continue
		HousePlanOpenings.add_inner_door(plan, guardroom, corridor, entry)
	for cell in cells:
		var best_corridor := -1
		var best_edge: Array = []
		var best_run := 0.0
		for corridor in corridors:
			var edge: Array = HousePlanOpenings.shared_edge(plan, cell, corridor)
			if edge.is_empty():
				continue
			var run := float(edge[3]) - float(edge[2])
			if run > best_run:
				best_run = run
				best_corridor = corridor
				best_edge = edge
		if best_corridor < 0:
			push_error("ShopPlanner: prison cell has no corridor wall")
			continue
		HousePlanOpenings.add_inner_door(plan, best_corridor, cell, best_edge)
		if not plan.doors.is_empty():
			plan.doors.back()["locked"] = true
	# Cellars are cloned before the prison's ground-floor door plan is built.
	# Rebuild their service graph from the same measured rectangles; the generic
	# tree cannot reliably place doors on every narrow aisle partition.
	var lower_by_rect := {}
	for lower in plan.rooms_on_storey(-1):
		lower_by_rect[Rect2(plan.rooms[lower]["rect"])] = lower
	var lower_guard := int(lower_by_rect.get(Rect2(plan.rooms[guardroom]["rect"]), -1))
	var lower_corridors: Array[int] = []
	var lower_stores: Array[int] = []
	for corridor in corridors:
		var lower_corridor := int(lower_by_rect.get(Rect2(plan.rooms[corridor]["rect"]), -1))
		if lower_corridor >= 0:
			plan.rooms[lower_corridor]["kind"] = &"corridor"
			lower_corridors.append(lower_corridor)
	for lower in plan.rooms_on_storey(-1):
		if lower != lower_guard and not lower_corridors.has(lower):
			lower_stores.append(lower)
	for d in range(plan.doors.size() - 1, -1, -1):
		var lower_door: Dictionary = plan.doors[d]
		if not bool(lower_door.get("exterior", false)) \
				and plan.storey_of_room(int(lower_door["a"])) == -1:
			plan.doors.remove_at(d)
	for corridor in lower_corridors:
		var edge: Array = HousePlanOpenings.shared_edge(plan, lower_guard, corridor)
		if not edge.is_empty():
			HousePlanOpenings.add_inner_door(plan, lower_guard, corridor, edge)
	for lower in lower_stores:
		var closest_corridor := -1
		var closest_edge: Array = []
		var longest_run := 0.0
		for corridor in lower_corridors:
			var edge: Array = HousePlanOpenings.shared_edge(plan, lower, corridor)
			if edge.is_empty():
				continue
			var run := float(edge[3]) - float(edge[2])
			if run > longest_run:
				longest_run = run
				closest_corridor = corridor
				closest_edge = edge
		if closest_corridor >= 0:
			HousePlanOpenings.add_inner_door(plan, closest_corridor, lower, closest_edge)
	# The lower storey is a clone, so it still tiles the cellar. Seal one cloned
	# cell behind a floor hatch, removing its ordinary door from the graph.
	var upper_cell := cells[0]
	var target_rect: Rect2 = plan.rooms[upper_cell]["rect"]
	var oubliette := -1
	for i in range(plan.room_count()):
		if plan.storey_of_room(i) == -1 and Rect2(plan.rooms[i]["rect"]).is_equal_approx(target_rect):
			oubliette = i
			break
	if oubliette < 0:
		push_error("ShopPlanner: prison has no cellar cell under its trapdoor")
		return
	plan.rooms[oubliette]["kind"] = &"oubliette"
	plan.rooms[oubliette]["sealed"] = true
	for d in range(plan.doors.size() - 1, -1, -1):
		var door2: Dictionary = plan.doors[d]
		if int(door2["a"]) == oubliette or int(door2["b"]) == oubliette:
			plan.doors.remove_at(d)
	var hatch_size := Vector2(0.70, 0.70)
	var upper_floor := HouseGeometry.room_floor_rect(plan, upper_cell)
	var hatch_rect := Rect2(upper_floor.end - hatch_size - Vector2(0.16, 0.16), hatch_size)
	plan.trapdoors.append({"upper_room": upper_cell, "lower_room": oubliette,
		"upper_storey": 0, "lower_storey": -1, "rect": hatch_rect, "sealed": true})


## A workshop needs useful light across its work area. A small domestic plan
## can meet its glazing-area target with one window beside a broad shop door,
## leaving the only usable bench wall dark. Add cross-light on a free outside
## side before furnishing, using the normal opening clearances.
static func _light_workshops(out: HousePlan, spec: ShopSpec) -> void:
	for room in range(out.room_count()):
		if out.kind_of(room) != &"workshop":
			continue
		_cross_light_workshop(out, spec, room)


static func _cross_light_workshop(out: HousePlan, spec: ShopSpec, room: int) -> void:
	var windows := out.windows_of(room)
	if windows.is_empty():
		return
	var first := Vector2(out.windows[windows[0]].normal)
	for index in windows:
		if absf(Vector2(out.windows[index].normal).dot(first)) < 0.5:
			return # already lit from two sides
	var rect: Rect2 = out.rooms[room].rect
	# The chimney wall was chosen, before this, for the clear run its fire
	# needs. Light the workshop from another wall first, and glaze the
	# chimney wall only if the fire still fits beside the new window: a
	# smithy cross-lit through its forge's wall has no forge (shoptrade
	# blacksmith 11x15 seed 8102; LIVE-SHOPS).
	var walls: Array = HouseGeometry.room_walls(out, room)
	var order: Array[int] = []
	var fire_wall := out.hearth_wall() if out.hearth_room() == room else -1
	for wi in range(walls.size()):
		if wi != fire_wall:
			order.append(wi)
	if fire_wall >= 0:
		order.append(fire_wall)
	for wi in order:
		var wall: Dictionary = walls[wi]
		var normal := -Vector2(wall.normal)
		if absf(normal.dot(first)) > 0.5:
			continue
		var horizontal := absf(normal.y) > 0.5
		var line: float = wall.from.y if horizontal else wall.from.x
		if not HouseGeometry.is_exterior_edge(spec, 1 if horizontal else 0, line):
			continue
		var side := {"normal": normal, "line": line,
			"t0": rect.position.x if horizontal else rect.position.y,
			"t1": rect.end.x if horizontal else rect.end.y}
		var had := out.windows.duplicate()
		HousePlanOpenings.windows_along(out, spec, room, side, INF, windows.size() + 1)
		if wi == fire_wall and HousePlanFeatures._clear_wall_run(out, room, wi) \
				< HousePlanFeatures.hearth_run_needed(spec, out):
			out.windows = had
		if out.windows_of(room).size() > windows.size():
			break


## The fire comes before the workshop's own back door.
##
## A smithy's forge stands on the chimney wall, and the chimney wall is an
## outside wall of the front room. On a small plan that wall can be left with
## no stretch long enough for the fire: the house planner hangs the workshop's
## back door at the corner nearer the street door, and the swing of that door
## eats the last 0.85 m of the only outside wall -- the same wall that already
## carries the room's one window beside the shopfront. The forge then has
## nowhere to stand and the smithy loses its fire (shoptrade blacksmith 9x12
## seed 1; LIVE-SHOPS).
##
## The plan owns the fire, so the plan gives way, not the door's landlord: the
## interior door that crowds the fire wall is re-hung at the far end of its own
## partition, and the hearth is elected again over the new spans. Nothing moves
## unless the shop cannot hold its fire as drawn, so a shop that already works
## keeps the plan it had.
static func _hold_the_fire_wall(out: HousePlan, spec: ShopSpec, front: int) -> void:
	if out.hearth_room() != front or out.hearth_wall() < 0:
		return
	var need := HousePlanFeatures.hearth_run_needed(spec, out)
	var fire_wall := out.hearth_wall()
	var fire: Dictionary = HouseGeometry.room_walls(out, front)[fire_wall]
	var fire_horizontal := absf(Vector2(fire.normal).y) > 0.5
	var fire_line: float = float(fire.from.y) if fire_horizontal else float(fire.from.x)
	var span := HousePlanFeatures.clear_wall_span(out, front, fire_wall)
	if span.y - span.x >= need:
		return
	for door_index in out.doors_of(front).duplicate():
		var door: Dictionary = out.doors[door_index]
		if bool(door.get("exterior", false)) or int(door.get("b", -1)) < 0:
			continue
		# A door in a wall ACROSS the fire wall is the one whose swing can take
		# the end of it; a door in the fire wall's own stretch cannot be slid
		# along it to help.
		if (absf(Vector2(door.normal).y) > 0.5) == fire_horizontal:
			continue
		var across: float = float(door.pos.y) if fire_horizontal else float(door.pos.x)
		if absf(across - fire_line) > HouseGeometry.DOOR_CLEAR + 0.6:
			continue
		var was := Vector2(door.pos)
		if not _rehang_door_away_from(out, door_index, fire_line):
			continue
		HousePlanFeatures.choose_hearth(out, spec)
		if out.hearth_room() == front and out.hearth_wall() >= 0:
			var moved := HousePlanFeatures.clear_wall_span(out, front, out.hearth_wall())
			if moved.y - moved.x >= need:
				return
		# This door was not the obstruction. Put it back and leave the plan
		# exactly as the house planner drew it.
		out.doors[door_index]["pos"] = was
		HousePlanFeatures.choose_hearth(out, spec)


## Re-hang an interior door at the end of its own partition furthest from
## `away_from`, a coordinate measured along that partition's run. The move
## keeps the door on the same two rooms and the same wall, and refuses when
## the partition is too short or another door already holds that end.
static func _rehang_door_away_from(out: HousePlan, door_index: int, away_from: float) -> bool:
	var door: Dictionary = out.doors[door_index]
	var edge := HousePlanOpenings.shared_edge(out, int(door["a"]), int(door["b"]))
	if edge.is_empty():
		return false
	var runs_y: bool = Vector2(edge[0]).x > 0.5
	var t0: float = float(edge[2])
	var t1: float = float(edge[3])
	var width: float = float(door["width"])
	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + width * 0.5 + 0.01
	if t1 - t0 < margin * 2.0:
		return false
	var at: float = float(door.pos.y) if runs_y else float(door.pos.x)
	var across: float = float(door.pos.x) if runs_y else float(door.pos.y)
	var towards_t1: bool = absf(t1 - away_from) > absf(away_from - t0)
	var t: float = (t1 - margin) if towards_t1 else (t0 + margin)
	if absf(t - at) < 0.01:
		return false
	# Another door already on this partition would share the stretch we are
	# moving into.
	for other_index in range(out.doors.size()):
		if other_index == door_index:
			continue
		var other: Dictionary = out.doors[other_index]
		if HousePlan.record_storey(other) != HousePlan.record_storey(door):
			continue
		if Vector2(other.normal).dot(Vector2(door.normal)) < 0.99:
			continue
		var other_at: float = float(other.pos.y) if runs_y else float(other.pos.x)
		var other_across: float = float(other.pos.x) if runs_y else float(other.pos.y)
		if absf(other_across - across) > 0.01:
			continue
		if absf(other_at - t) < (width + float(other.width)) * 0.5 + HouseGeometry.DOOR_CORNER_MARGIN:
			return false
	out.doors[door_index]["pos"] = Vector2(across, t) if runs_y else Vector2(t, across)
	return true


## A reader starts with the book by the light. Pin the first lectern to a
## window-side patch of floor; the second still follows the same daylight
## affinity while the ordinary placer keeps its clearance and navigation rules.
static func _pin_library_focus_to_daylight(out: HousePlan, room: int) -> void:
	var windows := out.windows_of(room)
	if windows.is_empty() or out.focus_room() != room or out.focus_cat() != "lectern":
		return
	var floor := HouseGeometry.room_floor_rect(out, room)
	var hearth := HouseFurnishScore._hearth_point(out, room)
	var chosen := windows[0]
	var best := -INF
	for wi in windows:
		var point := Vector2(out.windows[wi]["pos"])
		var score := point.distance_to(hearth) if hearth.is_finite() else point.distance_to(floor.get_center())
		if score > best:
			best = score
			chosen = wi
	var window_point := Vector2(out.windows[chosen]["pos"])
	var inward := (floor.get_center() - window_point).normalized()
	out.focus["pos"] = window_point + inward * 0.8
	out.focus["placed"] = false


## A trade that lets rooms gives every one of them its own way out (LAY-012).
##
## The inn's programme is a dining room, a kitchen and a chain of guest
## rooms, and a chain is exactly what LAY-007's privacy rule forbids: the
## spanning tree hangs the second guest room off the first, and the only way
## to the far bed is through somebody else's. The hotel met the same problem
## and answered it with a gallery every room opens onto (LAY-008); an inn is
## too small for a gallery of its own, so its programme carries one when it
## has the rooms for it and this pass guarantees the invariant either way:
##
##   EVERY SLEEPING ROOM HAS A DOOR ONTO A ROOM NOBODY SLEEPS IN.
##
## Two remedies, in the order a builder would reach for them. Cut a second
## door from a room you may walk through -- cheap, and what
## `HousePlanOpenings.open_up_privacy` does for a house. Failing that, the room
## the others hang off stops pretending to be a guest room and becomes the
## landing it has been acting as, which is the same demotion
## `_demote_through_bedrooms` makes for a house's own bedroom.
static func _open_up_lodging(out: HousePlan) -> void:
	for guard in range(6):
		var stranded := -1
		for i in range(out.room_count()):
			if out.kind_of(i) in HouseGeometry.SLEEPING and not _has_public_door(out, i):
				stranded = i
				break
		if stranded < 0:
			return
		if _cut_public_door(out, stranded):
			continue
		var culprit: int = _sleeping_neighbour(out, stranded)
		if culprit < 0:
			return
		out.rooms[culprit]["kind"] = &"gallery" \
			if HouseGeometry.room_suits(out, culprit, &"gallery") else &"store"


## Does this room open onto anything but another bed? Its own door to the
## street counts: a room you can walk into from outside is nobody's corridor.
static func _has_public_door(plan: HousePlan, room: int) -> bool:
	for di in plan.doors_of(room):
		var door: Dictionary = plan.doors[di]
		var other: int = int(door["b"]) if int(door["a"]) == room else int(door["a"])
		if other < 0 or not plan.kind_of(other) in HouseGeometry.SLEEPING:
			return true
	return false


## Cut a door from `room` into the widest wall it shares with a room nobody
## sleeps in. False when it shares no such wall wide enough for a door.
static func _cut_public_door(plan: HousePlan, room: int) -> bool:
	var best: Array = []
	var best_run := 0.0
	var best_j := -1
	for j in range(plan.room_count()):
		if j == room or plan.kind_of(j) in HouseGeometry.SLEEPING:
			continue
		var edge: Array = HousePlanOpenings.shared_edge(plan, room, j)
		if edge.is_empty():
			continue
		var run: float = edge[3] - edge[2]
		if run < HouseGeometry.INNER_DOOR_W + HouseGeometry.DOOR_CORNER_MARGIN * 2.0:
			continue
		if run > best_run:
			best_run = run
			best = edge
			best_j = j
	if best_j < 0:
		return false
	HousePlanOpenings.add_inner_door(plan, best_j, room, best)
	return true


## The sleeping room `room` hangs off: the one that has to stop being a
## bedroom for this one to be reachable.
static func _sleeping_neighbour(plan: HousePlan, room: int) -> int:
	for di in plan.doors_of(room):
		var door: Dictionary = plan.doors[di]
		var other: int = int(door["b"]) if int(door["a"]) == room else int(door["a"])
		if other >= 0 and plan.kind_of(other) in HouseGeometry.SLEEPING:
			return other
	return -1


## The shopfront (LAY-009): a hatch in the street wall of the front room,
## beside the door, from counter height to the door head, recorded as a
## window the builder already knows how to cut. It takes the longer stretch
## of wall beside the door and displaces any window it lands on; a front
## wall with no room for it gets none.
static func _cut_shopfront(out: HousePlan, spec: ShopSpec, front: int) -> void:
	var want: Dictionary = spec.front_open()
	if want.is_empty():
		return
	var door: int = out.entrance()
	if door < 0 or int(out.doors[door]["a"]) != front:
		return
	var d: Dictionary = out.doors[door]
	var rect: Rect2 = out.rooms[front]["rect"]
	var w: float = float(want["width"])
	var dx: float = float(d["pos"].x)
	var m: float = HouseGeometry.WINDOW_CORNER_MARGIN
	var gap: float = float(d["width"]) / 2.0 + HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
	var side: float = 1.0 if rect.end.x - dx >= dx - rect.position.x else -1.0
	var x: float = dx + side * gap
	if x - w / 2.0 < rect.position.x + m or x + w / 2.0 > rect.end.x - m:
		side = -side
		x = dx + side * gap
		if x - w / 2.0 < rect.position.x + m or x + w / 2.0 > rect.end.x - m:
			return
	var pos := Vector2(x, rect.position.y)
	var keep: Array[Dictionary] = []
	for win in out.windows:
		if int(win["room"]) == front and Vector2(win["normal"]).dot(Vector2(0, -1)) > 0.9 \
				and absf(float(win["pos"].x) - x) < (float(win["width"]) + w) / 2.0 + 0.1:
			continue
		keep.append(win)
	out.windows = keep
	out.windows.append({"room": front, "pos": pos, "normal": Vector2(0, -1),
		"width": w, "sill": 0.9, "head": HouseGeometry.DOOR_H, "hatch": true,
		"storey": 0})


## The business's focus replaces the house's fire as what the plan is
## arranged around: the counter, the anvil, the bar, in the front room. A
## focus that must face the door is backed to the wall opposite the entrance
## (a wall piece) or stood in the middle of the floor looking at it (a free
## one); one that need not is backed to the front room's best lit wall, which
## is where a bench wants to be anyway.
static func _choose_focus(out: HousePlan, spec: ShopSpec, front: int) -> void:
	var want: Dictionary = spec.focus()
	if want.is_empty():
		return
	var cat: String = String(want["cat"])
	var faces_door: bool = bool(want.get("faces_door", false))
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return
	var door_n := Vector2(0, -1)
	var door_pos := Vector2(INF, INF)
	# Some small shops enter through a service room. The business focus must
	# face the doorway into its own room, rather than an imagined street door.
	var entrance := HouseFurnishScore.focus_door(out, front)
	if entrance >= 0:
		door_pos = out.doors[entrance]["pos"]
		var nearest := INF
		for wall in HouseGeometry.room_walls(out, front):
			var point := Geometry2D.get_closest_point_to_segment(door_pos, wall.from, wall.to)
			var distance := door_pos.distance_to(point)
			if distance < nearest:
				nearest = distance
				door_n = -Vector2(wall.normal)
	if PropCatalog.has_tag(choices[0], PropCatalog.WALL):
		var walls: Array[Dictionary] = HouseGeometry.room_walls(out, front)
		var best := -1
		var best_run := -INF
		for wi in range(walls.size()):
			var n: Vector2 = walls[wi]["normal"]
			var span: Vector2 = HousePlanFeatures.clear_wall_span(out, front, wi)
			var run: float = span.y - span.x
			if faces_door:
				# the wall whose inward normal points the way the door's
				# outward normal does is the one across the room from it
				if n.dot(door_n) < 0.9:
					continue
			else:
				if HouseFurnishScore._wall_has_window(out, front, wi):
					run += 100.0
			if run > best_run:
				best_run = run
				best = wi
		if best < 0:
			best = 0
		var prefer := INF
		if faces_door and door_pos.is_finite():
			prefer = door_pos.x if absf(door_n.y) > 0.5 else door_pos.y
		out.focus = HousePlanFeatures.focus_on_wall(out, front, best, cat, faces_door, prefer)
		return
	var f: Rect2 = HouseGeometry.room_floor_rect(out, front)
	var facing: Vector2 = -door_n
	if faces_door and door_pos.is_finite():
		# square in front of the door, looking straight back at it
		facing = door_n
		out.focus = HousePlanFeatures.focus_in_room(out, front, cat, facing, faces_door)
		var depth: float = f.size.y if absf(door_n.y) > 0.5 else f.size.x
		# The middle of a shallow room is still the way in: a stall set there in
		# a 3.6 m stable stood 0.75 m inside the strip a person walks through
		# from the front door (CASTLE-CHANGE-17). The focus keeps its way in
		# clear, and the furnisher pins the piece to that spot.
		var back: float = maxf(depth / 2.0,
			HouseGeometry.ENTRY_APPROACH + _focus_half_depth(choices))
		var pos: Vector2 = door_pos - door_n * back
		out.focus["pos"] = Vector2(clampf(pos.x, f.position.x + 1.0, f.end.x - 1.0),
			clampf(pos.y, f.position.y + 1.0, f.end.y - 1.0))
		return
	elif out.hearth_room() == front and out.hearth_wall() >= 0:
		facing = HouseGeometry.room_walls(out, front)[out.hearth_wall()]["normal"]
	out.focus = HousePlanFeatures.focus_in_room(out, front, cat, facing, faces_door)


## Half the depth of the deepest model of the focus category, so a shallow
## room can stand the piece clear of its front door whichever key is chosen.
static func _focus_half_depth(choices: Array[String]) -> float:
	var deepest := 0.0
	for key in choices:
		deepest = maxf(deepest, PropCatalog.footprint(key).y)
	return deepest * 0.5
