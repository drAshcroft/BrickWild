class_name DungeonRoomCheck
extends RefCounted
## Is a realised dungeon room a room a person can use?
##
## Judged from the CARVE, not from what the planner says it meant: the floor,
## the headroom and the obstructions are sampled out of the op list, so a
## planner that logs a doorway and carves it somewhere else is caught here.
## Rules, each named in its failure:
##
##   budget     every op inside the block of rock, with rock to spare
##   floor      most of the chamber floor stands at y = 0
##   headroom   a person with a torch fits over every walked cell
##   mouth      each doorway is open at the wall and out to its tunnel's end
##   doors      doorways on one wall are apart and on the wall
##   walk       from the first doorway, every other doorway and every floor
##              socket is reached, every wall socket is within arm's reach
##   sockets    floor sockets stand on rock with air above; wall sockets
##              have rock behind and air in front
##   pit        from the bottom of every pit a person can climb back to its rim
##   bands      every surface band names a material

const STEP := 0.5          # sampling grid, metres
const BODY := 0.3          # a person's half-width
const REACH := 1.6         # arm's length to a wall socket
const FLOOR_SHARE := 0.5


static func check(room: Dictionary, geo: DungeonGeometry) -> Dictionary:
	var failures: Array[String] = []
	var warnings: Array[String] = []
	var key := String(room["key"])
	var ops: Array = room["carve"]
	var half := Vector2(float(room["size"]["half"][0]), float(room["size"]["half"][1]))

	# budget
	var inner := geo.budget().grow(-DungeonGeometry.ROCK_MARGIN)
	for op: Dictionary in ops:
		if String(op["op"]) != "carve":
			continue
		var b := DungeonCarve.bounds(op)
		if not inner.encloses(b):
			failures.append("budget: %s %s carves outside the rock (%s)" % [key, op["tag"], b])

	# floor, headroom, and the walk grid, sampled
	var x0 := -half.x - geo.tunnel_reach - 1.0
	var z0 := -half.y - geo.tunnel_reach - 1.0
	var area := Rect2(x0, z0, -x0 * 2.0, -z0 * 2.0)
	var grid := WalkGrid.new()
	grid.setup(area, 0.25)
	var chamber_cells := 0
	var floor_cells := 0
	var low: Array[String] = []
	var footprints: Array[Rect2] = []
	for op: Dictionary in ops:
		var b := DungeonCarve.bounds(op)
		footprints.append(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
	var x := x0 + STEP * 0.5
	while x < -x0:
		var z := z0 + STEP * 0.5
		while z < -z0:
			var in_chamber := absf(x) < half.x and absf(z) < half.y
			if in_chamber:
				chamber_cells += 1
			var here: Array = []
			for i in range(ops.size()):
				if footprints[i].has_point(Vector2(x, z)):
					here.append(ops[i])
			if here.is_empty():
				z += STEP
				continue
			var h := _floor_height(here, x, z)
			if h != INF:
				if in_chamber and absf(h) < 0.05:
					floor_cells += 1
				var clear := _clear_above(here, x, z, h)
				if clear >= DungeonGeometry.HEADROOM:
					grid.add_floor(Rect2(x - STEP * 0.5, z - STEP * 0.5, STEP, STEP), h)
				elif clear > 0.6 and in_chamber and low.size() < 4:
					low.append("(%.1f, %.1f) %.1fm" % [x, z, clear])
			z += STEP
		x += STEP
	if chamber_cells > 0 and float(floor_cells) / float(chamber_cells) < FLOOR_SHARE \
			and String(room["grammar"]["floor"]) != "pit":
		failures.append("floor: %s only %d of %d chamber cells stand at y 0"
			% [key, floor_cells, chamber_cells])
	if not low.is_empty():
		failures.append("headroom: %s has floor under %.1fm of clear height at %s"
			% [key, DungeonGeometry.HEADROOM, ", ".join(low)])
	grid.build(BODY)

	# mouths and doors
	var doors: Array = room["doorways"]
	var by_wall := {}
	for d: Dictionary in doors:
		var wall := StringName(String(d["wall"]))
		var n := DungeonGeometry.normal(wall)
		var m := Vector2(float(d["mouth"][0]), float(d["mouth"][2]))
		var expect := geo.mouth(Vector2i(int(room["span"][0]), int(room["span"][1])), wall,
			float(d["along"]))
		if m.distance_to(expect) > 0.01:
			failures.append("doors: %s %s mouth %s is not on its wall at along %.2f"
				% [key, d["portal"], m, float(d["along"])])
		var reach := geo.wall_reach(Vector2i(int(room["span"][0]), int(room["span"][1])), wall)
		if absf(float(d["along"])) > reach + 0.01:
			failures.append("doors: %s %s sits %.2fm along a wall that allows %.2fm"
				% [key, d["portal"], float(d["along"]), reach])
		var rise := float(d.get("rise", 0.0))
		for probe in [[-0.5, 1.5], [0.5, 1.5], [geo.tunnel_reach - 0.5, 1.5 + maxf(rise, 0.0)]]:
			var p := m + n * float(probe[0])
			if DungeonCarve.solid_at(ops, Vector3(p.x, float(probe[1]), p.y)):
				failures.append("mouth: %s %s is shut %.1fm from the wall" % [key, d["portal"], probe[0]])
				break
		if not by_wall.has(wall):
			by_wall[wall] = []
		(by_wall[wall] as Array).append(float(d["along"]))
	for wall in by_wall:
		var alongs: Array = by_wall[wall]
		alongs.sort()
		for i in range(1, alongs.size()):
			if float(alongs[i]) - float(alongs[i - 1]) < geo.door_min_gap:
				failures.append("doors: %s has two doorways %.2fm apart on its %s wall"
					% [key, float(alongs[i]) - float(alongs[i - 1]), wall])

	# walk
	if not doors.is_empty():
		var first := _inside(doors[0])
		if not grid.flood_from(first, 1.0):
			failures.append("walk: %s has nowhere to stand inside %s" % [key, doors[0]["portal"]])
		else:
			for d: Dictionary in doors.slice(1):
				var p := _inside(d)
				if grid.distance_to(p, 1.0) == INF:
					failures.append("walk: %s cannot reach %s from %s"
						% [key, d["portal"], doors[0]["portal"]])
			for s: Dictionary in room["sockets"]["fixtures"]:
				var q := Vector2(float(s["position"][0]), float(s["position"][2]))
				var limit := REACH if String(s["on"]) == "wall" else 1.0
				if grid.distance_to(q, limit) == INF:
					failures.append("walk: %s cannot reach %s %s" % [key, s["kind"], s["id"]])

	# sockets on their surfaces
	for group in ["fixtures", "set_pieces", "lights"]:
		for s: Dictionary in room["sockets"][group]:
			var p := Vector3(float(s["position"][0]), float(s["position"][1]), float(s["position"][2]))
			var why := _off_surface(ops, s, p)
			if why != "":
				failures.append("sockets: %s %s %s %s" % [key, group, s.get("kind", ""), why])

	# pits: somebody who falls in can climb out
	for op: Dictionary in ops:
		if String(op["tag"]) == "pit" and not _climbable(ops, DungeonCarve.bounds(op)):
			failures.append("pit: %s has a pit nobody can climb out of" % key)

	for band in ["floor", "wainscot", "upper", "ceiling"]:
		if String((room["bands"] as Dictionary).get(band, "")) == "":
			failures.append("bands: %s has no %s material" % [key, band])
	return {"failures": failures, "warnings": warnings}


## Height of the walked surface at (x, z): the first rock found coming down
## from head height, if it is a floor a person could be on. INF over a pit.
static func _floor_height(ops: Array, x: float, z: float) -> float:
	if DungeonCarve.solid_at(ops, Vector3(x, 1.0, z)):
		return INF
	for y in [0.75, 0.6, 0.45, 0.3, 0.15, -0.05]:
		if DungeonCarve.solid_at(ops, Vector3(x, float(y), z)):
			return 0.0 if float(y) < 0.0 else _surface(ops, x, z, float(y))
	return INF


## The top of the rock found at `y`, to within a few centimetres.
static func _surface(ops: Array, x: float, z: float, y: float) -> float:
	var top := y
	while top < 1.0 and DungeonCarve.solid_at(ops, Vector3(x, top + 0.02, z)):
		top += 0.02
	return snappedf(top, 0.05)


## From the bottom of the pit in `b` to its rim, over floor sampled out of the carve, in steps
## no taller than WalkGrid.MAX_STEP. Width is not asked; a stair a person cannot fit on is a
## different defect, and the pit's own flight is two metres wide.
static func _climbable(ops: Array, b: AABB) -> bool:
	var cell := 0.25
	var nx := int(b.size.x / cell)
	var nz := int(b.size.z / cell)
	var near: Array = ops.filter(func(op): return DungeonCarve.bounds(op).intersects(b.grow(0.5)))
	var feet: Array[Rect2] = []
	for op: Dictionary in near:
		var ob := DungeonCarve.bounds(op)
		feet.append(Rect2(ob.position.x, ob.position.z, ob.size.x, ob.size.z))
	var height := PackedFloat32Array()
	height.resize(nx * nz)
	var lowest := INF
	for i in range(nx):
		for k in range(nz):
			var x := b.position.x + (float(i) + 0.5) * cell
			var z := b.position.z + (float(k) + 0.5) * cell
			var here: Array = []
			for j in range(near.size()):
				if feet[j].has_point(Vector2(x, z)):
					here.append(near[j])
			var h := -INF
			var y := 0.2
			while y > b.position.y - 0.5:
				if DungeonCarve.solid_at(here, Vector3(x, y, z)):
					h = y
					break
				y -= 0.125
			height[i * nz + k] = h
			lowest = minf(lowest, h)
	var queue: Array[Vector2i] = []
	var seen := {}
	for i in range(nx):
		for k in range(nz):
			if height[i * nz + k] <= lowest + 0.3:
				queue.append(Vector2i(i, k))
				seen[Vector2i(i, k)] = true
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var hc := height[c.x * nz + c.y]
		if hc >= -0.4:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz or seen.has(n):
				continue
			if absf(height[n.x * nz + n.y] - hc) <= WalkGrid.MAX_STEP:
				seen[n] = true
				queue.append(n)
	return false


static func _clear_above(ops: Array, x: float, z: float, h: float) -> float:
	var y := h + 0.1
	while y < h + DungeonGeometry.HEADROOM + 0.05:
		if DungeonCarve.solid_at(ops, Vector3(x, y, z)):
			return y - h
		y += 0.2
	return DungeonGeometry.HEADROOM + 0.05


static func _inside(d: Dictionary) -> Vector2:
	var n := DungeonGeometry.normal(StringName(String(d["wall"])))
	return Vector2(float(d["mouth"][0]), float(d["mouth"][2])) - n * 1.5


static func _off_surface(ops: Array, s: Dictionary, p: Vector3) -> String:
	if String(s.get("on", "floor")) == "wall" or s.has("wall"):
		var n := DungeonGeometry.normal(StringName(String(s["wall"])))
		var back := Vector3(p.x + n.x * 0.4, p.y, p.z + n.y * 0.4)
		var front := Vector3(p.x - n.x * 0.3, p.y, p.z - n.y * 0.3)
		if not DungeonCarve.solid_at(ops, back):
			return "at %s has no wall behind it" % p
		if DungeonCarve.solid_at(ops, front):
			return "at %s is buried in rock" % p
		return ""
	if not DungeonCarve.solid_at(ops, p - Vector3(0, 0.1, 0)):
		return "at %s stands on nothing" % p
	if DungeonCarve.solid_at(ops, p + Vector3(0, 0.3, 0)):
		return "at %s is buried in rock" % p
	return ""
