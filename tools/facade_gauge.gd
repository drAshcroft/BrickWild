extends SceneTree
## how blank is each elevation of the EMITTED shell?
##   godot --headless --path . --script res://tools/facade_gauge.gd -- '<request json>' [label]
## For each of the four sides of the shell AABB, cast horizontal rays inward on
## a 0.2 m grid. A hit on a wall-like face (|n.y| < 0.25, facing the viewer) at
## one of the side's dominant depths (a bin holding >= 10 % of hits) is PLAIN
## wall; any other wall hit (proud trim, recessed opening, glass, frame,
## pilaster side) is FEATURE. Up-facing hits (roof) and misses are not wall.
## Reports per side: wall area, feature fraction, the largest axis-aligned
## rectangle of PLAIN cells, and the longest plain horizontal run per 1 m band.

const CELL := 0.2

var _b
var _frames := 0
var _label := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_b = BrickWild.generate(BuildingRequest.from_json(args[0]))
	_label = args[1] if args.size() > 1 else ""
	if not _b.is_ok():
		print("not generated")
		quit(1)
		return
	get_root().add_child(BrickWild.instantiate(_b, false, true))


func _physics_process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	if _frames == 3:
		_measure()
		quit(0)
	return false


func _ray(space, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.hit_back_faces = false
	return space.intersect_ray(q)


func _measure() -> void:
	var space := (get_root().get_child(get_root().get_child_count() - 1) as Node3D).get_world_3d().direct_space_state
	var aabb := AABB()
	var first := true
	for n in get_root().find_children("*", "CollisionShape3D", true, false):
		var sh = (n as CollisionShape3D).shape
		if sh is ConcavePolygonShape3D:
			var xf := (n as Node3D).global_transform
			for v in (sh as ConcavePolygonShape3D).get_faces():
				var w: Vector3 = xf * v
				if first:
					aabb = AABB(w, Vector3.ZERO)
					first = false
				else:
					aabb = aabb.expand(w)
	print("## %s  %s  aabb %s" % [_label, _b.name(), aabb])
	if _b.plan != null and _b.plan is HousePlan:
		var plan: HousePlan = _b.plan
		for wi in range(plan.windows.size()):
			var w: Dictionary = plan.windows[wi]
			if not bool(w.get("balcony", false)) and wi != 73:
				continue
			var st := HousePlan.record_storey(w)
			var pos: Vector2 = w["pos"]
			var nrm: Vector2 = w["normal"]
			var room: int = int(w["room"])
			var y0: float = st * plan.spec.height + HouseGeometry.FLOOR_T
			# can a body pass the window? ray at 1.0 m from 1 m inside to 1 m outside
			var a := Vector3(pos.x, y0 + 1.0, pos.y) - Vector3(nrm.x, 0, nrm.y) * 1.0
			var e := Vector3(pos.x, y0 + 1.0, pos.y) + Vector3(nrm.x, 0, nrm.y) * 1.0
			var hit := _ray(space, a, e)
			var hit2 := _ray(space, e, a)
			var near := PackedStringArray()
			for f in plan.furniture:
				if HousePlan.record_storey(f) == st and int(f["room"]) == room:
					var fr: Rect2 = f["rect"]
					if fr.grow(0.6).has_point(pos - nrm * 0.3):
						near.append(String(f["key"]))
			print("  window %d storey %d room %d (%s) pos %s normal %s width %.2f sill %.2f head %.2f balcony=%s | ray in->out %s, out->in %s | furniture before it %s" % [
				wi, st, room, plan.kind_of(room), pos, nrm, float(w["width"]), float(w["sill"]), float(w["head"]),
				w.get("balcony", false), "clear" if hit.is_empty() else "hit %.2f m" % (hit["position"] - a).length(),
				"clear" if hit2.is_empty() else "hit %.2f m" % (hit2["position"] - e).length(), near])
	var sides := [["-Z", Vector3(0, 0, -1)], ["+Z", Vector3(0, 0, 1)], ["-X", Vector3(-1, 0, 0)], ["+X", Vector3(1, 0, 0)]]
	var top: float = minf(aabb.end.y, 30.0)
	for side in sides:
		var nrm: Vector3 = side[1]
		var along := Vector3(-nrm.z, 0, nrm.x)  # horizontal tangent
		var lo: float
		var hi: float
		var face_d: float
		if absf(nrm.x) > 0.5:
			lo = aabb.position.z; hi = aabb.end.z
			face_d = aabb.end.x if nrm.x > 0 else aabb.position.x
		else:
			lo = aabb.position.x; hi = aabb.end.x
			face_d = aabb.end.z if nrm.z > 0 else aabb.position.z
		var cols := int((hi - lo) / CELL)
		var rows := int(top / CELL)
		var depth := []   # per cell: -1 miss/not wall, else depth from face
		var hist := {}
		var nhits := 0
		for r in range(rows):
			var row := []
			for c in range(cols):
				var u: float = lo + (float(c) + 0.5) * CELL
				var y: float = (float(r) + 0.5) * CELL
				var p := Vector3(u, y, face_d + 2.0) if absf(nrm.z) > 0.5 else Vector3(face_d + 2.0, y, u)
				if absf(nrm.z) > 0.5:
					p.z = face_d + nrm.z * 2.0
				else:
					p.x = face_d + nrm.x * 2.0
				var hit := _ray(space, p, p - nrm * 6.0)
				if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.25 or (hit["normal"] as Vector3).dot(nrm) < 0.2:
					row.append(-1.0 if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.25 else -2.0)
					continue
				var d: float = (p - hit["position"]).length() - 2.0
				var feat := (hit["normal"] as Vector3).dot(nrm) < 0.97
				row.append(-3.0 - d if feat else d)
				if not feat:
					var k := snappedf(d, 0.04)
					hist[k] = int(hist.get(k, 0)) + 1
					nhits += 1
			depth.append(row)
		var planes := []
		for k in hist:
			if hist[k] >= 0.10 * nhits:
				planes.append(k)
		var plain := 0
		var feature := 0
		var grid := []   # 1 plain, 0 otherwise
		for r in range(rows):
			var g := []
			for c in range(cols):
				var d: float = depth[r][c]
				var v := 0
				if d == -1.0:
					v = 0
				elif d <= -3.0 or d == -2.0:
					feature += 1
				else:
					var on := false
					for k in planes:
						if absf(d - k) <= 0.03:
							on = true
					if on:
						plain += 1
						v = 1
					else:
						feature += 1
				g.append(v)
			grid.append(g)
		var wall := plain + feature
		if wall == 0:
			continue
		var best := _max_rect(grid, rows, cols)
		# longest plain horizontal run within each 1 m band (5 rows all plain)
		var bands := PackedStringArray()
		var worst_run := 0.0
		for r0 in range(0, rows - 4, 5):
			var run := 0
			var mx := 0
			for c in range(cols):
				var all_plain := true
				for r in range(r0, r0 + 5):
					if grid[r][c] != 1:
						all_plain = false
				run = run + 1 if all_plain else 0
				mx = maxi(mx, run)
			if mx > 0:
				bands.append("%.0f:%.1f" % [r0 * CELL, mx * CELL])
			worst_run = maxf(worst_run, mx * CELL)
		print("  %s: wall %.1f m2, feature %.1f%%, planes %s, largest blank rect %.1f x %.1f m = %.1f m2 (at u=%.1f y=%.1f), longest blank 1m-band run %.1f m" % [
			side[0], wall * CELL * CELL, 100.0 * feature / wall, planes, best[0] * CELL, best[1] * CELL,
			best[0] * best[1] * CELL * CELL, lo + best[2] * CELL, best[3] * CELL, worst_run])
		print("     bands y:run %s" % " ".join(bands))


## Largest rectangle of 1s: [w_cells, h_cells, col, row].
func _max_rect(grid: Array, rows: int, cols: int) -> Array:
	var heights := []
	heights.resize(cols)
	heights.fill(0)
	var best := [0, 0, 0, 0]
	for r in range(rows):
		for c in range(cols):
			heights[c] = heights[c] + 1 if grid[r][c] == 1 else 0
		var stack := []
		for c in range(cols + 1):
			var h: int = heights[c] if c < cols else 0
			var start := c
			while not stack.is_empty() and stack[-1][1] >= h:
				var top: Array = stack.pop_back()
				var area: int = top[1] * (c - top[0])
				if area > best[0] * best[1]:
					best = [c - top[0], top[1], top[0], r - top[1] + 1]
				start = top[0]
			stack.append([start, h])
	return best
