class_name HouseWitchProps
extends RefCounted
## The Witch's Hut hand-made props (WITCH-PROPS): brooms.
##
## A broom is a plan record, not a catalogue model. A procedural broom (a
## handle plus a bound bristle cone) needs no licence and no catalogue rebuild.
## It leans on a wall: the bristle flare stands on the floor, the handle's top
## touches the wall face, so both ends have real contact.
##
## One broom stands by the entrance door; a second by the stove (or, where the
## stove wall is full, the nearest free wall to it).

const HANDLE_LENGTH := 1.25
const HANDLE_RADIUS := 0.012
const LEAN := 0.157            # radians, about 9 degrees
const BRISTLE_RADIUS := 0.10
const BRISTLE_HEIGHT := 0.34
const FOOT_DEPTH := 0.32       # wall face to the far edge of the bristle flare
const FOOT_WIDTH := 0.22
const STEP := 0.05


static func plan_props(plan: HousePlan) -> void:
	plan.witch_props.clear()
	add_stove_bay(plan)
	if plan.spec.style != &"witch_hut" or plan.spec.trade != &"none":
		return
	var entrance := plan.entrance()
	if entrance < 0:
		return
	var door: Dictionary = plan.doors[entrance]
	var hall := plan.entrance_room()
	var by_door := _place(plan, hall, Vector2(door["pos"]), "door")
	if not by_door.is_empty():
		plan.witch_props.append(by_door)
	var stove: Dictionary = HouseGeometry.hearth_breast(plan).get("stove", {})
	var near: Vector2 = Vector2(stove["centre"]) if not stove.is_empty() \
		else Vector2(door["pos"])
	var stove_room := plan.hearth_room() if plan.hearth_room() >= 0 else hall
	var by_stove := _place(plan, stove_room, near, "stove")
	if not by_stove.is_empty():
		plan.witch_props.append(by_stove)


## The stove joins the cooking recess AFTER the room is furnished: widening the
## breast while the furniture search runs took the Hall's work bench and prep
## group out of three frozen huts (the compact Hall has no floor to spare), so
## the search keeps the plain recess and the bay is added on whichever side the
## finished room leaves clear. The walk is re-checked; a bay that closes a
## route is withdrawn.
static func add_stove_bay(plan: HousePlan) -> void:
	if plan.spec.style != &"witch_hut" or plan.spec.trade != &"none":
		return
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	if breast.is_empty() or String(breast.get("kind", "")) != "witch_cauldron_recess" 			or not Dictionary(breast.get("stove", {})).is_empty():
		return
	var room := int(breast["room"])
	var cauldron := -1
	for i in plan.furniture_of(room):
		if String(plan.furniture[i].get("key", "")) == "Cauldron":
			cauldron = i
			break
	if cauldron < 0:
		return
	var blocked: Array[Rect2] = []
	var zones: Array[Rect2] = []
	for i in plan.furniture_of(room):
		if i == cauldron or bool(plan.furniture[i].get("mounted", false)):
			continue
		blocked.append(Rect2(plan.furniture[i]["rect"]))
		var z: Rect2 = plan.furniture[i].get("zone", Rect2())
		if z.has_area():
			zones.append(z)
	zones.append_array(plan.zones_of(room))
	for di in plan.doors_of(room):
		for side in [-1.0, 1.0]:
			zones.append(HouseGeometry.door_clear_rect(plan.doors[di], side))
	var floor_rect := HouseGeometry.room_floor_rect(plan, room)
	var plain: Dictionary = breast
	for side in [1.0, -1.0]:
		var wide := HouseGeometry.breast_for_hearth(plan, room, plan.furniture[cauldron],
			int(breast["wall"]), float(side))
		var moves := _torch_moves(plan, room, wide, blocked, zones, floor_rect, cauldron)
		if moves.has("fail"):
			continue
		var kept: Dictionary = {}
		for i in moves:
			kept[i] = plan.furniture[i].duplicate(true)
			plan.furniture[i] = moves[i]
		var fits := HouseFurnishPlacement._breast_fits(plan, room, wide, floor_rect, blocked, zones)
		if fits:
			plan.hearth["breast"] = wide
			var nav: Dictionary = HouseNavCheck.new().check(plan)
			if bool(nav.get("ok", false)):
				return
			plan.hearth["breast"] = plain
		for i in kept:
			plan.furniture[i] = kept[i]


## The wall torches that flank the recess stand where the bay would go. Each is
## slid along the wall to just clear the widened breast; anything else mounted
## there, or no room to slide, rules that side out ({"fail": true}).
static func _torch_moves(plan: HousePlan, room: int, wide: Dictionary, blocked: Array[Rect2],
		zones: Array[Rect2], floor_rect: Rect2, cauldron: int) -> Dictionary:
	var out := {}
	var wide_rect: Rect2 = wide["rect"]
	var yaw: float = float(wide["yaw"])
	var axis := Vector2(cos(yaw), -sin(yaw))
	var centre: Vector2 = wide["centre"]
	for i in plan.furniture_of(room):
		var f: Dictionary = plan.furniture[i]
		if i == cauldron or not bool(f.get("mounted", false)):
			continue
		var r := Rect2(f["rect"])
		if not r.intersects(wide_rect):
			continue
		if String(f.get("key", "")) != "Torch_Metal":
			return {"fail": true}
		var along := (r.get_center() - centre).dot(axis)
		var dir := 1.0 if along >= 0.0 else -1.0
		var delta := dir * (float(wide["width"]) * 0.5 + 0.14) - along
		var moved := f.duplicate(true)
		var shift := axis * delta
		moved["rect"] = Rect2(r.position + shift, r.size)
		var p: Vector3 = moved["pos"]
		moved["pos"] = Vector3(p.x + shift.x, p.y, p.z + shift.y)
		var mr: Rect2 = moved["rect"]
		if not floor_rect.grow(0.25).encloses(mr) or mr.intersects(wide_rect):
			return {"fail": true}
		for w in plan.windows_of(room):
			if mr.intersects(HouseGeometry.window_clear_rect(plan.windows[w])):
				return {"fail": true}
		for di in plan.doors_of(room):
			for sd in [-1.0, 1.0]:
				if mr.intersects(HouseGeometry.door_clear_rect(plan.doors[di], sd)):
					return {"fail": true}
		for j in plan.furniture_of(room):
			if j != i and j != cauldron and bool(plan.furniture[j].get("mounted", false)) 					and mr.intersects(Rect2(plan.furniture[j]["rect"]).grow(0.05)):
				return {"fail": true}
		out[i] = moved
	return out


## The obstructions a broom's footprint has to stay out of.
static func _blocked(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for f in plan.furniture:
		if int(f.get("room", -1)) == room and not bool(f.get("mounted", false)):
			out.append(Rect2(f["rect"]).grow(0.04))
			var z: Rect2 = f.get("zone", Rect2())
			if z.has_area():
				out.append(z)
	for z in plan.zones_of(room):
		out.append(z)
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	if not breast.is_empty() and int(breast.get("room", -1)) == room:
		out.append(Rect2(breast["rect"]))
	for di in plan.doors_of(room):
		for side in [-1.0, 1.0]:
			out.append(HouseGeometry.door_clear_rect(plan.doors[di], side))
	for wi in plan.windows_of(room):
		out.append(HouseGeometry.window_clear_rect(plan.windows[wi]))
	return out


static func _place(plan: HousePlan, room: int, near: Vector2, why: String) -> Dictionary:
	if room < 0:
		return {}
	var blocked := _blocked(plan, room)
	var floor_rect := HouseGeometry.room_floor_rect(plan, room)
	var best := {}
	var best_d := INF
	for wall: Dictionary in HouseGeometry.room_walls(plan, room):
		if String(wall.get("kind", "solid")) != "solid":
			continue
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		var n: Vector2 = wall["normal"]
		if absf(n.x) + absf(n.y) < 0.99 or (absf(n.x) > 0.01 and absf(n.y) > 0.01):
			continue # leaning against a diagonal facet is not supported
		var along := (b - a).normalized()
		var length := a.distance_to(b)
		var t := 0.2
		while t <= length - 0.2:
			var foot_centre := a + along * t + n * (FOOT_DEPTH * 0.5)
			var size := Vector2(FOOT_DEPTH, FOOT_WIDTH) if absf(n.x) > 0.5 \
				else Vector2(FOOT_WIDTH, FOOT_DEPTH)
			var rect := Rect2(foot_centre - size * 0.5, size)
			var t_here := t
			t += STEP
			if not floor_rect.grow(0.01).encloses(rect):
				continue
			var hit := false
			for o in blocked:
				if o.intersects(rect):
					hit = true
					break
			if hit:
				continue
			var d := foot_centre.distance_to(near)
			if d < best_d:
				best_d = d
				best = {"kind": "broom", "why": why, "room": room,
					"storey": plan.storey_of_room(room), "rect": rect,
					"wall_point": a + along * t_here, "normal": n,
					"floor_y": float(plan.storey_of_room(room)) * plan.spec.height + HouseGeometry.FLOOR_T,
					"length": HANDLE_LENGTH}
	return best


## World node for one broom record. Lean direction is toward the wall.
static func broom_node(rec: Dictionary, node_name: String) -> Node3D:
	var n: Vector2 = rec["normal"]
	var wp: Vector2 = rec["wall_point"]
	var root := Node3D.new()
	root.name = node_name
	root.set_meta("plan_role", "witch_broom")
	root.set_meta("why", String(rec["why"]))
	var length: float = float(rec["length"])
	var base_h := HANDLE_RADIUS + length * sin(LEAN)
	var y0 := float(rec["floor_y"]) + BRISTLE_RADIUS * sin(LEAN)
	var base := Vector3(wp.x + n.x * base_h, y0, wp.y + n.y * base_h)
	var toward := Vector3(-n.x, 0.0, -n.y)
	var axis := (Vector3.UP * cos(LEAN) + toward * sin(LEAN)).normalized()
	# A basis whose Y is the handle axis.
	var x_axis := axis.cross(Vector3(n.y, 0.0, -n.x)).normalized()
	if x_axis.length() < 0.01:
		x_axis = Vector3.RIGHT
	var z_axis := x_axis.cross(axis).normalized()
	var basis := Basis(x_axis, axis, z_axis)
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.62, 0.50, 0.26)
	straw.roughness = 0.95
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.24, 0.13)
	wood.roughness = 0.85
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.22, 0.15, 0.09)
	# bristle flare: narrow at the binding, wide at the floor
	var flare := CylinderMesh.new()
	flare.top_radius = HANDLE_RADIUS * 1.6
	flare.bottom_radius = BRISTLE_RADIUS
	flare.height = BRISTLE_HEIGHT
	flare.radial_segments = 14
	var flare_node := MeshInstance3D.new()
	flare_node.name = "Bristles"
	flare_node.mesh = flare
	flare_node.material_override = straw
	flare_node.transform = Transform3D(basis, base + axis * (BRISTLE_HEIGHT * 0.5))
	root.add_child(flare_node)
	var handle := CylinderMesh.new()
	handle.top_radius = HANDLE_RADIUS
	handle.bottom_radius = HANDLE_RADIUS
	handle.height = length - BRISTLE_HEIGHT * 0.6
	handle.radial_segments = 8
	var handle_node := MeshInstance3D.new()
	handle_node.name = "Handle"
	handle_node.mesh = handle
	handle_node.material_override = wood
	handle_node.transform = Transform3D(basis,
		base + axis * (BRISTLE_HEIGHT * 0.6 + handle.height * 0.5))
	root.add_child(handle_node)
	var band := CylinderMesh.new()
	band.top_radius = HANDLE_RADIUS * 2.1
	band.bottom_radius = HANDLE_RADIUS * 2.1
	band.height = 0.05
	var band_node := MeshInstance3D.new()
	band_node.name = "Binding"
	band_node.mesh = band
	band_node.material_override = cord
	band_node.transform = Transform3D(basis, base + axis * (BRISTLE_HEIGHT * 0.7))
	root.add_child(band_node)
	root.set_meta("foot", base)
	root.set_meta("tip", base + axis * length)
	return root
