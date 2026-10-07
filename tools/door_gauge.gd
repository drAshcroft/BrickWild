extends SceneTree
## measure every exterior entrance on the EMITTED collision.
##   godot --headless --path . --script res://tools/door_gauge.gd -- '<request json>' [x,z,nx,nz ...]
## Without explicit doors: plan exterior storey-0 doors, or a church's west leaves.
## Per door: clear width (min over depth through the wall) at several heights,
## shell-only (mask 1) and with props solid (mask 3), clear head, floor profile
## along the normal (max step), then walks the rig body through at lateral
## offsets 0, +-0.2 and +-0.3 m, with props solid, like the walker.

const RADIUS := 0.28
const BODY_H := 1.75
const STEP := 0.4
const GRAVITY := 12.0
const WALK_SPEED := 2.2

var _doors: Array = []   # {c: Vector2, n: Vector2, w: float, label}
var _routes: Array = []  # [start, end, label]
var _player: CharacterBody3D
var _route := -1
var _t := 0.0
var _frames := 0
var _space: PhysicsDirectSpaceState3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var req := BuildingRequest.from_json(args[0])
	var b := BrickWild.generate(req)
	if not b.is_ok():
		print("gauge: not generated %s" % [b.errors])
		quit(1)
		return
	for k in range(1, args.size()):
		var f := args[k].split(",")
		_doors.append({"c": Vector2(float(f[0]), float(f[1])), "n": Vector2(float(f[2]), float(f[3])).normalized(),
			"w": float(f[4]) if f.size() > 4 else 1.0, "label": "arg%d" % k})
	if _doors.is_empty() and b.plan != null:
		for i in range(b.plan.doors.size()):
			var d: Dictionary = b.plan.doors[i]
			if not d["exterior"] or HousePlan.record_storey(d) != 0:
				continue
			_doors.append({"c": d["pos"], "n": (d["normal"] as Vector2).normalized(), "w": float(d["width"]),
				"label": "door %d" % i})
	if _doors.is_empty() and b.spec is ChurchSpec:
		var cs := b.spec as ChurchSpec
		for leaf in ChurchGeometry.west_door_layout(cs):
			_doors.append({"c": Vector2(leaf["x"], -cs.length / 2.0), "n": Vector2(0, -1), "w": float(leaf["width"]),
				"label": "west leaf x=%.2f" % leaf["x"]})
	var root := BrickWild.instantiate(b, false, true)
	var shell_bodies := {}
	for n in root.find_children("*", "StaticBody3D", true, false):
		shell_bodies[n] = true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var has := false
		for c in mi.get_children():
			if c is StaticBody3D:
				has = true
		if not has:
			mi.create_trimesh_collision()
	for n in root.find_children("*", "StaticBody3D", true, false):
		if not shell_bodies.has(n):
			(n as StaticBody3D).collision_layer = 2
	root_add(root)
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	gs.shape = WorldBoundaryShape3D.new()
	ground.add_child(gs)
	ground.position.y = -0.02
	get_root().add_child(ground)
	_player = CharacterBody3D.new()
	_player.collision_mask = 3
	_player.floor_snap_length = STEP
	_player.floor_max_angle = deg_to_rad(50)
	var body := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = BODY_H
	body.shape = cap
	body.position.y = BODY_H / 2.0
	_player.add_child(body)
	get_root().add_child(_player)


func root_add(n: Node) -> void:
	get_root().add_child(n)


func _ray(a: Vector3, b: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, mask)
	q.hit_back_faces = true
	q.hit_from_inside = true
	return _space.intersect_ray(q)


func _gauge() -> void:
	for d in _doors:
		var c: Vector2 = d["c"]
		var n: Vector2 = d["n"]
		var t := Vector2(-n.y, n.x)
		var n3 := Vector3(n.x, 0, n.y)
		var t3 := Vector3(t.x, 0, t.y)
		print("== %s at (%.2f, %.2f) normal (%.2f, %.2f) nominal width %.2f" % [d["label"], c.x, c.y, n.x, n.y, d["w"]])
		# floor profile along the normal through the centre, from y=1.2 down
		var prof := PackedStringArray()
		var prev := NAN
		var max_step := 0.0
		var floor_at_door := 0.0
		for i in range(-30, 31):
			var s := float(i) * 0.1
			var p := Vector3(c.x, 0, c.y) + n3 * s
			var hit := _ray(p + Vector3.UP * 1.2, p + Vector3.DOWN * 0.5, 1)
			var y: float = hit["position"].y if not hit.is_empty() else -0.02
			if i == 0:
				floor_at_door = y
			if not is_nan(prev):
				max_step = maxf(max_step, absf(y - prev))
			prev = y
			prof.append("%.2f" % y)
		print("   floor (outside +n .. inside -n, 0.1 m): %s   max step %.2f" % [" ".join(prof), max_step])
		for mask in [1, 3]:
			var line := PackedStringArray()
			var worst := INF
			for h in [0.05, 0.15, 0.3, 0.6, 1.0, 1.4, 1.7, 1.9]:
				var wmin := INF
				var at := 0.0
				for j in range(-8, 9):
					var s := float(j) * 0.075
					var p := Vector3(c.x, floor_at_door + h, c.y) + n3 * s
					var l := _ray(p, p + t3 * 1.5, mask)
					var r := _ray(p, p - t3 * 1.5, mask)
					var wl: float = 1.5 if l.is_empty() else (l["position"] - p).length()
					var wr: float = 1.5 if r.is_empty() else (r["position"] - p).length()
					# only count depths where BOTH sides are bounded: inside the reveal
					if l.is_empty() or r.is_empty():
						continue
					if wl + wr < wmin:
						wmin = wl + wr
						at = s
				line.append("h%.2f:%s" % [h, ("open" if wmin == INF else "%.2f@%+.2f" % [wmin, at])])
				if h <= BODY_H and wmin < worst:
					worst = wmin
			print("   width %s: %s   min<=1.75: %s" % ["shell" if mask == 1 else "shell+props", " ".join(line),
				"n/a" if worst == INF else "%.2f" % worst])
		var head := INF
		for j in range(-8, 9):
			var p := Vector3(c.x, floor_at_door + 0.05, c.y) + n3 * (float(j) * 0.075)
			var u := _ray(p, p + Vector3.UP * 4.0, 1)
			if not u.is_empty():
				head = minf(head, u["position"].y - floor_at_door)
		print("   clear head over the threshold: %s" % ("open" if head == INF else "%.2f" % head))
		for ang in [-40.0, -25.0, 25.0, 40.0]:
			# a person comes at a door at an angle, aimed at its middle
			var dirv: Vector2 = n.rotated(deg_to_rad(ang))
			_routes.append([c + dirv * 2.5, c - dirv * 1.5, "%s angle %+.0f in" % [d["label"], ang]])
			_routes.append([c - dirv * 1.5, c + dirv * 2.5, "%s angle %+.0f out" % [d["label"], ang]])
		for off in [0.0, -0.15, 0.15, -0.3, 0.3]:
			var a: Vector2 = c + n * 2.0 + t * off
			var e: Vector2 = c - n * 2.0 + t * off
			_routes.append([a, e, "%s off %+.1f in" % [d["label"], off]])
			_routes.append([e, a, "%s off %+.1f out" % [d["label"], off]])


func _next() -> void:
	_route += 1
	_t = 0.0
	if _route >= _routes.size():
		print("gauge: done")
		quit(0)
		return
	var s: Vector2 = _routes[_route][0]
	_player.global_position = Vector3(s.x, 0.6, s.y)
	_player.velocity = Vector3.ZERO


func _physics_process(delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	if _route < 0:
		_space = _player.get_world_3d().direct_space_state
		_gauge()
		_next()
		return false
	if _route >= _routes.size():
		return true
	_t += delta
	var s: Vector2 = _routes[_route][0]
	var e: Vector2 = _routes[_route][1]
	var dir := (e - s).normalized()
	var p := _player.global_position
	var to_go := (e - Vector2(p.x, p.z)).dot(dir)
	if _t > 6.0 + (e - s).length() / WALK_SPEED or to_go < 0.05:
		var through := to_go < 0.3
		var why := ""
		if not through:
			for i in range(_player.get_slide_collision_count()):
				var col := _player.get_slide_collision(i)
				var o := col.get_collider()
				why += " against %s/%s L%d at (%.2f,%.2f,%.2f)" % [(o as Node).get_parent().name if o is Node else "?",
					(o as Node).name if o is Node else "?", (o as CollisionObject3D).collision_layer if o is CollisionObject3D else -1,
					col.get_position().x, col.get_position().y, col.get_position().z]
		print("   walk %s: %s%s" % [_routes[_route][2], "THROUGH" if through else "BLOCKED %.2f m short" % to_go, why])
		_next()
		return false
	var wish := Vector3(dir.x, 0, dir.y) * WALK_SPEED
	_player.velocity.x = wish.x
	_player.velocity.z = wish.z
	if not _player.is_on_floor():
		_player.velocity.y -= GRAVITY * delta
	var motion := Vector3(wish.x, 0, wish.z) * delta
	if _player.is_on_floor() and motion.length() > 0.0005 and _step_up(motion):
		return false
	_player.move_and_slide()
	return false


func _step_up(motion: Vector3) -> bool:
	var xf := _player.global_transform
	if not _player.test_move(xf, motion):
		return false
	for h in [STEP * 0.25, STEP * 0.5, STEP * 0.75, STEP]:
		var lift := Vector3(0, h, 0)
		if _player.test_move(xf, lift):
			continue
		var raised := xf.translated(lift)
		if _player.test_move(raised, motion):
			continue
		var ahead := raised.translated(motion)
		var col := KinematicCollision3D.new()
		if not _player.test_move(ahead, -lift, col):
			continue
		var probe := raised.translated(motion.normalized() * maxf(motion.length(), RADIUS))
		var tread := KinematicCollision3D.new()
		if _player.test_move(raised, probe.origin - raised.origin):
			probe = ahead
		if not _player.test_move(probe, -lift, tread) or tread.get_normal().y < cos(_player.floor_max_angle):
			continue
		_player.global_transform = ahead.translated(col.get_travel())
		_player.velocity.y = 0.0
		return true
	return false
