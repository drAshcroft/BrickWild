extends SceneTree
## Walk the walk rig's body through a building's doors, headless, and say
## whether it got through. Same capsule, floor snap and step-up as
## visualQA/walk/walk_qa.gd, against the same trimesh collision the rig uses
## (BrickWild.instantiate with collision).
##
##   godot --headless --path . --script res://tools/walk_doors.gd -- '<request json>'
##   godot --headless --path . --script res://tools/walk_doors.gd -- '<request json>' sx,sz,ex,ez ...
##
## With no routes it walks IN through every exterior ground-floor door of a
## plan family (house, shop, hotel), from 2 m outside to 2 m inside along the
## door's normal. Prints one line per route and a closing verdict:
##   walk_doors: N routes, M blocked
## A church with no routes walks in AND out at every west door leaf.
## `--rig-step` uses the rig's old single 0.4 m lift, to reproduce a refusal.
## `--trace` prints every frame: position, the test_move hit, which step-up
## lift was tried and why it was refused, and the collision tree at start.
## Godot names the NEAREST contact as a test_move's collider, so a body jammed
## on a mesh edge while standing on the ground reports the ground: read the
## step-up refusals, not the collider name.
##
## Written for WALK-QA, 6 Oct: "door is impossible to pass" was the rig
## lifting a 1.75 m body a full 0.4 m under a 2.02 m door head, not the door.

const GRAVITY := 12.0
const STEP := 0.4
const RADIUS := 0.28
const BODY_H := 1.75
const WALK_SPEED := 2.2
const TIMEOUT := 6.0

var _routes: Array = []
var _player: CharacterBody3D
var _route := -1
var _t := 0.0
var _blocked := 0
var _rig_step := false
var _trace := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var req := BuildingRequest.from_json(args[0])
	for k in range(1, args.size()):
		if args[k] == "--rig-step":
			_rig_step = true
			continue
		if args[k] == "--trace":
			_trace = true
			continue
		var f := args[k].split(",")
		_routes.append([Vector2(float(f[0]), float(f[1])), Vector2(float(f[2]), float(f[3]))])
	var b := BrickWild.generate(req)
	if not b.is_ok():
		print("walk_doors: not generated: %s" % [b.errors])
		quit(1)
		return
	if _routes.is_empty() and b.plan != null:
		for d in b.plan.doors:
			if not d["exterior"] or HousePlan.record_storey(d) != 0:
				continue
			var pos: Vector2 = d["pos"]
			var n: Vector2 = d["normal"]
			_routes.append([pos + n * 2.0, pos - n * 2.0])
	if _routes.is_empty() and b.spec is ChurchSpec:
		# a church walks in at every west leaf, from 2.5 m outside its west
		# front to 2.5 m inside the nave
		var cs := b.spec as ChurchSpec
		var west := -cs.length / 2.0
		for r in ChurchGeometry.floor_rects(cs):
			west = minf(west, r.position.y)
		for leaf in ChurchGeometry.west_door_layout(cs):
			var x: float = leaf["x"]
			_routes.append([Vector2(x, west - 2.5), Vector2(x, -cs.length / 2.0 + 2.5)])
			_routes.append([Vector2(x, -cs.length / 2.0 + 2.5), Vector2(x, west - 2.5)])
	root.add_child(BrickWild.instantiate(b, false, true))
	var ground := StaticBody3D.new()
	var gshape := CollisionShape3D.new()
	gshape.shape = WorldBoundaryShape3D.new()
	ground.add_child(gshape)
	ground.position.y = -0.02
	root.add_child(ground)
	_player = CharacterBody3D.new()
	_player.floor_snap_length = STEP
	_player.floor_max_angle = deg_to_rad(50)
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = BODY_H
	body.shape = capsule
	body.position.y = BODY_H / 2.0
	_player.add_child(body)
	root.add_child(_player)
	if _trace:
		_dump(root, 0)


func _dump(n: Node, depth: int) -> void:
	if depth > 6:
		return
	var extra := ""
	if n is CollisionShape3D:
		var sh: Shape3D = (n as CollisionShape3D).shape
		extra = " shape=%s" % sh
		if sh is ConcavePolygonShape3D:
			var f := (sh as ConcavePolygonShape3D).get_faces()
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for v in f:
				lo = lo.min(v)
				hi = hi.max(v)
			extra += " faces=%d backface=%s aabb=%s..%s" % [f.size() / 3,
				(sh as ConcavePolygonShape3D).backface_collision, lo, hi]
		extra += " xf=%s" % (n as Node3D).global_transform.origin
	if n is CollisionObject3D:
		extra += " layer=%d mask=%d" % [(n as CollisionObject3D).collision_layer, (n as CollisionObject3D).collision_mask]
	if n is CollisionObject3D or n is CollisionShape3D or depth < 2:
		print("%s%s (%s)%s" % ["  ".repeat(depth), n.name, n.get_class(), extra])
	for c in n.get_children():
		_dump(c, depth + 1)


func _next() -> void:
	_route += 1
	_t = 0.0
	if _route >= _routes.size():
		print("walk_doors: %d routes, %d blocked" % [_routes.size(), _blocked])
		quit(1 if _blocked > 0 else 0)
		return
	var s: Vector2 = _routes[_route][0]
	_player.global_position = Vector3(s.x, 0.6, s.y)
	_player.velocity = Vector3.ZERO


func _physics_process(delta: float) -> bool:
	if _route < 0:
		_next()   # the body is in the tree now
		return false
	if _route >= _routes.size():
		return true
	_t += delta
	var s: Vector2 = _routes[_route][0]
	var e: Vector2 = _routes[_route][1]
	var dir := (e - s).normalized()
	var p := _player.global_position
	var to_go := (e - Vector2(p.x, p.z)).dot(dir)
	# a long route gets the time to walk it, plus the 6 s grace a short one had
	if _t > TIMEOUT + (e - s).length() / WALK_SPEED or to_go < 0.05:
		var through := to_go < 0.3
		if not through:
			_blocked += 1
			# what the body is pressed against, so a refusal names its cause
			for i in range(_player.get_slide_collision_count()):
				var c := _player.get_slide_collision(i)
				print("    against %s at (%.2f, %.2f, %.2f) normal %s" % [
					(c.get_collider() as Node).get_parent().name if c.get_collider() is Node else "?",
					c.get_position().x, c.get_position().y, c.get_position().z, c.get_normal()])
		print("route %d %s -> %s: %s at (%.2f, %.2f, %.2f), %.2f m short" % [_route, s, e,
			"THROUGH" if through else "BLOCKED", p.x, p.y, p.z, maxf(to_go, 0.0)])
		_next()
		return false
	var wish := Vector3(dir.x, 0, dir.y) * WALK_SPEED
	_player.velocity.x = wish.x
	_player.velocity.z = wish.z
	if not _player.is_on_floor():
		_player.velocity.y -= GRAVITY * delta
	var motion := Vector3(wish.x, 0, wish.z) * delta
	if _trace:
		var blk := KinematicCollision3D.new()
		var hit := _player.test_move(_player.global_transform, motion, blk)
		print("t=%.2f p=(%.3f, %.3f, %.3f) floor=%s vy=%.2f%s" % [_t, p.x, p.y, p.z,
			_player.is_on_floor(), _player.velocity.y,
			"" if not hit else " test_move hit %s at (%.2f, %.2f, %.2f) n=%s" % [
				_collider_name(blk.get_collider()), blk.get_position().x, blk.get_position().y,
				blk.get_position().z, blk.get_normal()]])
	if _player.is_on_floor() and motion.length() > 0.0005 and _step_up(motion):
		return false
	_player.move_and_slide()
	if _trace:
		for i in range(_player.get_slide_collision_count()):
			var c := _player.get_slide_collision(i)
			print("  slide %s n=%s" % [_collider_name(c.get_collider()), c.get_normal()])
	return false


func _collider_name(o: Object) -> String:
	if o is Node:
		return "%s/%s" % [(o as Node).get_parent().name, (o as Node).name]
	return "?"


## visualQA/walk/walk_qa.gd's step-up, lowest lift first.
func _step_up(motion: Vector3) -> bool:
	var xf := _player.global_transform
	if not _player.test_move(xf, motion):
		return false
	var lifts: Array = [STEP] if _rig_step else [STEP * 0.25, STEP * 0.5, STEP * 0.75, STEP]
	for h in lifts:
		var lift := Vector3(0, h, 0)
		var why := KinematicCollision3D.new()
		if _player.test_move(xf, lift, why):
			_trace_line("  step %.2f refused: no headroom, %s" % [h, _hit_text(why)])
			continue
		var raised := xf.translated(lift)
		if _player.test_move(raised, motion, why):
			_trace_line("  step %.2f refused: raised motion blocked, %s" % [h, _hit_text(why)])
			continue
		var ahead := raised.translated(motion)
		var col := KinematicCollision3D.new()
		if not _player.test_move(ahead, -lift, col):
			_trace_line("  step %.2f refused: nothing to land on" % h)
			continue
		# the rig's tread probe: judge the tread a body radius ahead, not at the
		# front edge one frame's motion reaches (walk_qa.gd _step_up)
		var probe := raised.translated(motion.normalized() * maxf(motion.length(), RADIUS))
		var tread := KinematicCollision3D.new()
		if _player.test_move(raised, probe.origin - raised.origin):
			probe = ahead
		if not _player.test_move(probe, -lift, tread) 				or tread.get_normal().y < cos(_player.floor_max_angle):
			_trace_line("  step %.2f refused: tread normal %s" % [h, tread.get_normal()])
			continue
		_trace_line("  step %.2f taken" % h)
		_player.global_transform = ahead.translated(col.get_travel())
		_player.velocity.y = 0.0
		return true
	return false


func _hit_text(c: KinematicCollision3D) -> String:
	return "%s at (%.2f, %.2f, %.2f) n=%s" % [_collider_name(c.get_collider()),
		c.get_position().x, c.get_position().y, c.get_position().z, c.get_normal()]


func _trace_line(s: String) -> void:
	if _trace:
		print(s)
