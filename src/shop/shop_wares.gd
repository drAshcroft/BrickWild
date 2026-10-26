extends RefCounted
## A trade's own goods, set on the furniture the plan already holds
## (LIVE-SHOPS, SHOP-<KIND>-TRAITS).
##
## The blind review could not tell a butcher from a tailor from the door: the
## catalogue has counters, shelves and racks but no bread, meat, cloth, jars or
## horseshoes, so every shop showed the same empty boards. These are small
## procedural meshes, like the witch's broom: no licence, no catalogue rebuild.
##
## They are DRESSING, not plan records. Every piece stands on a board the plan
## already measured (a counter top, a shelf, a bench) or hangs from a fitting
## it already placed (a stall canopy, a peg rack), so no floor is taken, no
## walk changes and the furnishing checks see the same plan. One exception is a
## swap, not an addition: the bakery's sales-floor fire is drawn as a domed
## bread oven over the cauldron's own footprint.
##
## Local frames: a piece is built with its front (toward the customer, or into
## the room off a wall) on -Z and its length on X, then turned by the plan's
## yaw, which carries -Z onto (-sin yaw, -cos yaw) -- the plan's facing.

const TRADES: Array[StringName] = [&"bakery", &"butcher", &"apothecary", &"tailor",
	&"general_store", &"tavern", &"blacksmith", &"carpenter", &"alchemist_laboratory"]

## Measured board tops, model-local metres above the origin (up-facing faces of
## the glTF, artifacts/SHOP-TRAITS/boards.log): the stall's counter board, the
## three boards of the arched wall shelf, the plain shelf, the work tops.
const STALL_TOP := 0.82
const STALL_RAIL := 2.22
const ARCH_BOARDS: Array[float] = [-0.42, 0.12, 0.64]
const SIMPLE_BOARD := 0.10
const WORKBENCH_TOP := 0.88
const BENCH_TOP := 0.50
const CABINET_TOP := 1.00
const SHELF_DEPTH := 0.15     # wall face to the middle of a shelf board

static var _mats: Dictionary = {}


static func trade_of(plan: HousePlan) -> StringName:
	if plan.spec is ShopSpec:
		return (plan.spec as ShopSpec).business
	return &""


## The bakery's oven: the plan's fire on the sales floor is a cauldron in the
## catalogue, which read as a soup kitchen. It is drawn as a bread oven.
static func replaces(plan: HousePlan, p: Dictionary) -> bool:
	return trade_of(plan) == &"bakery" and String(p.get("key", "")) == "Cauldron"


static func oven_node(p: Dictionary) -> Node3D:
	var rect: Rect2 = p["rect"]
	var pos: Vector3 = p["pos"]
	var root := Node3D.new()
	root.name = "BreadOven"
	root.set_meta("plan_role", "shop_bread_oven")
	root.position = Vector3(rect.get_center().x, pos.y, rect.get_center().y)
	root.rotation.y = float(p["yaw"])
	var w: float = minf(rect.size.x, rect.size.y) - 0.04
	var brick := _mat("brick", Color(0.62, 0.33, 0.22))
	var dark := _mat("soot", Color(0.08, 0.06, 0.05))
	var stone := _mat("stone", Color(0.55, 0.52, 0.48))
	# a stone plinth, the brick floor of the oven, then the dome
	_box(root, Vector3(w, 0.62, w), Vector3(0, 0.31, 0), stone)
	_box(root, Vector3(w, 0.08, w), Vector3(0, 0.66, 0), brick)
	var dome := SphereMesh.new()
	dome.radius = w * 0.5
	dome.height = w * 0.62
	dome.is_hemisphere = true
	_mesh(root, dome, Vector3(0, 0.70, 0), brick)
	# the mouth: a dark arch on the front, embers inside, a stone sill
	_box(root, Vector3(w * 0.42, 0.22, 0.04), Vector3(0, 0.81, -w * 0.47), dark)
	var glow := _mat("ember", Color(1.0, 0.42, 0.10), true)
	_box(root, Vector3(w * 0.30, 0.06, 0.02), Vector3(0, 0.74, -w * 0.49), glow)
	_box(root, Vector3(w * 0.55, 0.05, 0.14), Vector3(0, 0.665, -w * 0.5 - 0.02), stone)
	# the flue at the back and a peel leaning against the plinth
	var flue := CylinderMesh.new()
	flue.top_radius = 0.08
	flue.bottom_radius = 0.10
	flue.height = 0.45
	_mesh(root, flue, Vector3(0, 1.05, w * 0.25), brick)
	var wood := _mat("wood", Color(0.55, 0.38, 0.22))
	var peel := Node3D.new()
	peel.position = Vector3(w * 0.5 + 0.03, 0.0, -w * 0.3)
	peel.rotation.z = 0.18
	_box(peel, Vector3(0.03, 1.1, 0.03), Vector3(0, 0.75, 0), wood)
	_box(peel, Vector3(0.02, 0.26, 0.22), Vector3(0, 0.13, 0), wood)
	root.add_child(peel)
	for i in 3:
		_add(root, _loaf(i), Vector3(-w * 0.25 + i * w * 0.25, 0.685, -w * 0.5 - 0.02), 0.0)
	return root


## Dress every counter, shelf, rack and work top of a trade the review names.
static func dress(props: Node3D, plan: HousePlan) -> void:
	var trade := trade_of(plan)
	if not trade in TRADES:
		return
	var wares := Node3D.new()
	wares.name = "ShopWares"
	wares.set_meta("plan_role", "shop_wares")
	var r := RandomNumberGenerator.new()
	r.seed = int(plan.spec.seed) * 7919 + String(trade).hash()
	for i in plan.furniture.size():
		var p: Dictionary = plan.furniture[i]
		var key := String(p.get("key", ""))
		var cat := PropCatalog.category(key)
		var taken := _taken(plan, i)
		match cat:
			"counter":
				_on_counter(wares, trade, p, taken, r)
			"shelf":
				if key != "Shelf_Small_Bottles":
					_on_shelf(wares, trade, p, key, taken, r)
			"rack":
				_on_rack(wares, trade, p, r)
			"workbench":
				_on_top(wares, trade, p, WORKBENCH_TOP, taken, r, "workbench")
			"bench":
				if trade == &"carpenter":
					_on_top(wares, trade, p, BENCH_TOP, taken, r, "bench")
			"storage":
				if key == "Cabinet":
					_on_top(wares, trade, p, CABINET_TOP, taken, r, "cabinet")
	if wares.get_child_count() == 0:
		wares.free()
		return
	props.add_child(wares)


# ------------------------------------------------------------------ hosts

## Plan rects of what already stands on piece `host`: no ware lands on them.
static func _taken(plan: HousePlan, host: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for q in plan.furniture:
		if int(q.get("host", -1)) == host:
			out.append(Rect2(q["rect"]).grow(0.04))
	return out


static func _frame(p: Dictionary, y: float) -> Node3D:
	var rect: Rect2 = p["rect"]
	var frame := Node3D.new()
	frame.position = Vector3(rect.get_center().x, y, rect.get_center().y)
	frame.rotation.y = float(p["yaw"])
	return frame


## The run of a floor piece along its own X: the longer side of its rect when
## it stands square, as every shop piece does.
static func _run(p: Dictionary) -> Vector2:
	var key := String(p["key"])
	var scale := float(p.get("scale", 1.0))
	var f: Vector2 = PropCatalog.footprint(key) * scale
	return f


## Slots along a board of half-length `half`, `pitch` apart, skipping any whose
## plan point lands on a piece already there.
static func _slots(frame: Node3D, half: float, pitch: float, z: float,
		taken: Array[Rect2]) -> Array[float]:
	var out: Array[float] = []
	var n := int(floor(half * 2.0 / pitch))
	if n < 1:
		return out
	var start := -pitch * float(n - 1) * 0.5
	var basis := Basis(Vector3.UP, frame.rotation.y)
	for k in n:
		var x := start + pitch * k
		var w: Vector3 = frame.position + basis * Vector3(x, 0, z)
		var hit := false
		for t in taken:
			if t.has_point(Vector2(w.x, w.z)):
				hit = true
				break
		if not hit:
			out.append(x)
	return out


static func _on_counter(parent: Node3D, trade: StringName, p: Dictionary,
		taken: Array[Rect2], r: RandomNumberGenerator) -> void:
	if String(p["key"]) != "Stall_Empty":
		return
	var hs: float = PropCatalog.placement_height_scale(p)
	var pos: Vector3 = p["pos"]
	var frame := _frame(p, pos.y + STALL_TOP * hs)
	frame.name = "CounterWares"
	var run := _run(p)
	var half: float = run.x * 0.5 - 0.22
	var slots := _slots(frame, half, 0.30, 0.0, taken)
	# the trade's station first, in the middle of the board, then goods
	var station := _station(trade)
	if station != null and not slots.is_empty():
		var mid := slots[slots.size() / 2]
		slots.erase(mid)
		_add(frame, station, Vector3(mid, 0, 0.0), 0.0)
	for x in slots:
		var piece := _counter_good(trade, r)
		if piece != null:
			_add(frame, piece, Vector3(x, 0, r.randf_range(-0.12, 0.12)), r.randf_range(-0.3, 0.3))
	# what hangs from the canopy rail over the customer's side
	var hang := _hanging(trade)
	if hang != "":
		var rail := _frame(p, pos.y + STALL_RAIL * hs)
		rail.name = "CanopyHang"
		var depth: float = run.y * 0.5 - 0.12
		var n := maxi(int(run.x / 0.32) - 1, 1)
		for k in n:
			var x := -run.x * 0.5 + 0.3 + k * ((run.x - 0.6) / maxf(n - 1, 1))
			_add(rail, _hanging_piece(hang, k, r), Vector3(x, 0, -depth), 0.0)
		parent.add_child(rail)
	if frame.get_child_count() > 0:
		parent.add_child(frame)
	else:
		frame.free()


static func _on_shelf(parent: Node3D, trade: StringName, p: Dictionary, key: String,
		taken: Array[Rect2], r: RandomNumberGenerator) -> void:
	var pos: Vector3 = p["pos"]
	var scale := float(p.get("scale", 1.0))
	var boards: Array[float] = [SIMPLE_BOARD]
	if key == "Shelf_Arch":
		boards = ARCH_BOARDS
	var half: float = PropCatalog.size(key).x * scale * 0.5 - 0.12
	for b in boards:
		var frame := Node3D.new()
		frame.name = "ShelfWares"
		frame.position = Vector3(pos.x, pos.y + b * scale, pos.z)
		frame.rotation.y = float(p["yaw"])
		for x in _slots(frame, half, 0.2, -SHELF_DEPTH, taken):
			var piece := _shelf_good(trade, r)
			if piece != null:
				_add(frame, piece, Vector3(x, 0, -SHELF_DEPTH), r.randf_range(-0.2, 0.2))
		if trade == &"blacksmith" and key == "Shelf_Simple":
			# horseshoes on nails along the wall under the board
			for k in 4:
				_add(frame, _horseshoe(), Vector3(-0.36 + k * 0.24, -0.30, -0.02), 0.0)
			# and the tools hung upright at either end, where the door can see them
			var ends: Array[Node3D] = [_tongs(), _hammer()]
			for k in ends.size():
				var tool := ends[k]
				tool.rotation.z = -PI / 2.0
				_add(frame, tool, Vector3(-0.72 + k * 1.44, -0.45, -0.03), 0.0)
		if frame.get_child_count() > 0:
			parent.add_child(frame)
		else:
			frame.free()


static func _on_rack(parent: Node3D, trade: StringName, p: Dictionary,
		r: RandomNumberGenerator) -> void:
	var pos: Vector3 = p["pos"]
	var frame := Node3D.new()
	frame.name = "RackWares"
	frame.position = Vector3(pos.x, pos.y - 0.02, pos.z)
	frame.rotation.y = float(p["yaw"])
	for k in 3:
		var x := -0.38 + k * 0.38
		var piece: Node3D = null
		match trade:
			&"tailor":
				piece = _garment(r)
			&"carpenter":
				piece = _saw() if k != 1 else _square()
			_:
				piece = null
		if piece != null:
			_add(frame, piece, Vector3(x, 0, -0.06), 0.0)
	if frame.get_child_count() > 0:
		parent.add_child(frame)
	else:
		frame.free()


static func _on_top(parent: Node3D, trade: StringName, p: Dictionary, top: float,
		taken: Array[Rect2], r: RandomNumberGenerator, what: String) -> void:
	var hs: float = PropCatalog.placement_height_scale(p)
	var pos: Vector3 = p["pos"]
	var frame := _frame(p, pos.y + top * hs)
	frame.name = "TopWares"
	var run := _run(p)
	var pieces: Array[Node3D] = []
	match [trade, what]:
		[&"carpenter", "bench"]:
			pieces = [_plank(minf(run.x - 0.3, 1.6)), _handsaw()]
		[&"carpenter", "workbench"]:
			pieces = [_plane(), _mallet(), _bowl(r), _chisel()]
		[&"tailor", "workbench"]:
			pieces = [_cloth_spread(r), _shears(), _bolt(r)]
		[&"apothecary", "workbench"], [&"alchemist_laboratory", "workbench"]:
			pieces = [_alembic(), _mortar(), _jar(r), _flask(r)]
		[&"butcher", "workbench"]:
			pieces = [_block(), _joint(r)]
		[&"bakery", "workbench"]:
			pieces = [_dough(), _loaf(1), _loaf(2)]
		[&"blacksmith", "workbench"]:
			pieces = [_hammer(), _tongs(), _blade()]
		[_, "cabinet"]:
			if trade in [&"apothecary", &"alchemist_laboratory"]:
				pieces = [_jar(r), _jar(r), _flask(r)]
			elif trade == &"bakery":
				pieces = [_basket(), _loaf(0)]
			elif trade == &"tailor":
				pieces = [_folded(r), _bolt(r)]
			elif trade == &"general_store":
				pieces = [_crock(r), _cheese()]
	if pieces.is_empty():
		frame.free()
		return
	var half: float = run.x * 0.5 - 0.2
	var slots := _slots(frame, half, maxf(half * 2.0 / pieces.size(), 0.25), 0.0, taken)
	for k in mini(slots.size(), pieces.size()):
		_add(frame, pieces[k], Vector3(slots[k], 0, 0.0), 0.0)
	for k in range(mini(slots.size(), pieces.size()), pieces.size()):
		pieces[k].free()
	if frame.get_child_count() > 0:
		parent.add_child(frame)
	else:
		frame.free()


# ------------------------------------------------------------------ what each trade shows

## The piece that says "work is done here", on the counter where the customer
## sees it: the butcher's block, the apothecary's mortar and still, the
## tailor's cutting cloth, the grocer's scales, the tapster's cask.
static func _station(trade: StringName) -> Node3D:
	match trade:
		&"butcher":
			return _block()
		&"apothecary", &"alchemist_laboratory":
			return _alembic()
		&"tailor":
			return _cloth_spread(null)
		&"general_store":
			return _scales()
		&"tavern":
			return _keg()
		&"bakery":
			return _basket()
	return null


static func _counter_good(trade: StringName, r: RandomNumberGenerator) -> Node3D:
	match trade:
		&"bakery":
			return _loaf(r.randi_range(0, 2))
		&"butcher":
			return _joint(r) if r.randf() < 0.6 else _sausages()
		&"apothecary", &"alchemist_laboratory":
			match r.randi_range(0, 2):
				0: return _mortar()
				1: return _jar(r)
			return _flask(r)
		&"tailor":
			return _bolt(r) if r.randf() < 0.55 else _folded(r)
		&"general_store":
			match r.randi_range(0, 3):
				0: return _crock(r)
				1: return _cheese()
				2: return _sack_small()
			return _ledger()
		&"tavern":
			return _mug()
		&"carpenter":
			return _bowl(r) if r.randf() < 0.5 else _mallet()
	return null


static func _shelf_good(trade: StringName, r: RandomNumberGenerator) -> Node3D:
	match trade:
		&"bakery":
			return _loaf(r.randi_range(0, 2))
		&"butcher":
			return _sausages() if r.randf() < 0.5 else _joint(r)
		&"apothecary", &"alchemist_laboratory":
			return _jar(r) if r.randf() < 0.7 else _flask(r)
		&"tailor":
			return _bolt(r) if r.randf() < 0.5 else _folded(r)
		&"general_store":
			match r.randi_range(0, 3):
				0: return _crock(r)
				1: return _cheese()
				2: return _sack_small()
			return _jar(r)
		&"tavern":
			return _mug() if r.randf() < 0.6 else _crock(r)
		&"blacksmith":
			match r.randi_range(0, 2):
				0: return _hammer()
				1: return _tongs()
			return _blade()
		&"carpenter":
			match r.randi_range(0, 3):
				0: return _bowl(r)
				1: return _mallet()
				2: return _plane()
			return _chisel()
	return null


static func _hanging(trade: StringName) -> String:
	match trade:
		&"butcher":
			return "ham"
		&"tailor":
			return "cloth"
		&"apothecary":
			return "herbs"
		&"general_store":
			return "herbs"
	return ""


# ------------------------------------------------------------------ pieces

static func _loaf(kind: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Loaf"
	var crust := _mat("crust", Color(0.72, 0.46, 0.20))
	var s := SphereMesh.new()
	match kind % 3:
		0: # a long loaf
			s.radius = 0.06
			s.height = 0.10
			var m := _mesh(n, s, Vector3(0, 0.05, 0), crust)
			m.scale = Vector3(2.4, 1.0, 1.0)
		1: # a round cob
			s.radius = 0.09
			s.height = 0.11
			_mesh(n, s, Vector3(0, 0.055, 0), crust)
		_: # a plaited loaf: three buns in a row
			s.radius = 0.05
			s.height = 0.08
			for k in 3:
				_mesh(n, s, Vector3(-0.07 + k * 0.07, 0.04, 0), crust)
	return n


static func _dough() -> Node3D:
	var n := Node3D.new()
	n.name = "Dough"
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.10
	_mesh(n, s, Vector3(0, 0.05, 0), _mat("dough", Color(0.93, 0.88, 0.74)))
	return n


static func _basket() -> Node3D:
	var n := Node3D.new()
	n.name = "BreadBasket"
	var c := CylinderMesh.new()
	c.top_radius = 0.17
	c.bottom_radius = 0.13
	c.height = 0.12
	_mesh(n, c, Vector3(0, 0.06, 0), _mat("wicker", Color(0.66, 0.52, 0.30)))
	var bun := SphereMesh.new()
	bun.radius = 0.05
	bun.height = 0.07
	var crust := _mat("crust", Color(0.72, 0.46, 0.20))
	for k in 5:
		var a := TAU * k / 5.0
		_mesh(n, bun, Vector3(cos(a) * 0.08, 0.13, sin(a) * 0.08), crust)
	_mesh(n, bun, Vector3(0, 0.15, 0), crust)
	return n


static func _block() -> Node3D:
	var n := Node3D.new()
	n.name = "ChoppingBlock"
	var c := CylinderMesh.new()
	c.top_radius = 0.17
	c.bottom_radius = 0.18
	c.height = 0.16
	_mesh(n, c, Vector3(0, 0.08, 0), _mat("endgrain", Color(0.78, 0.62, 0.42)))
	# a cleaver bitten into the block
	var cleaver := Node3D.new()
	cleaver.position = Vector3(0.02, 0.16, 0)
	cleaver.rotation.z = 0.25
	_box(cleaver, Vector3(0.16, 0.09, 0.008), Vector3(0, 0.03, 0), _mat("steel", Color(0.70, 0.72, 0.75)))
	_box(cleaver, Vector3(0.12, 0.025, 0.025), Vector3(0.14, 0.05, 0), _mat("wood_dark", Color(0.32, 0.20, 0.12)))
	n.add_child(cleaver)
	return n


static func _joint(r: RandomNumberGenerator) -> Node3D:
	# a leg of mutton: a tapering dark-red joint, a rind of fat along its back
	# and the bone standing out of the shank end
	var n := Node3D.new()
	n.name = "Joint"
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.11
	var meat := _mat("meat", Color(0.55, 0.11, 0.09))
	var body := _mesh(n, s, Vector3(0, 0.05, 0), meat)
	body.scale = Vector3(1.7 if r == null else r.randf_range(1.5, 1.9), 1.0, 1.05)
	var shank := CylinderMesh.new()
	shank.top_radius = 0.025
	shank.bottom_radius = 0.045
	shank.height = 0.10
	var sm := _mesh(n, shank, Vector3(0.14, 0.045, 0), meat)
	sm.rotation.z = PI / 2.0
	var bone := CylinderMesh.new()
	bone.top_radius = 0.014
	bone.bottom_radius = 0.014
	bone.height = 0.06
	var bm := _mesh(n, bone, Vector3(0.21, 0.045, 0), _mat("bone", Color(0.94, 0.91, 0.84)))
	bm.rotation.z = PI / 2.0
	_box(n, Vector3(0.16, 0.012, 0.05), Vector3(-0.01, 0.10, 0.0), _mat("fat", Color(0.93, 0.86, 0.78)))
	return n


static func _sausages() -> Node3D:
	var n := Node3D.new()
	n.name = "Sausages"
	var c := CapsuleMesh.new()
	c.radius = 0.022
	c.height = 0.13
	var skin := _mat("sausage", Color(0.55, 0.22, 0.14))
	for k in 4:
		var m := _mesh(n, c, Vector3(-0.07 + k * 0.045, 0.022, 0), skin)
		m.rotation.x = PI / 2.0
	return n


static func _hanging_piece(kind: String, k: int, r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "Hanging_" + kind
	var string_len := 0.18 + 0.06 * float(k % 2)
	_box(n, Vector3(0.01, string_len, 0.01), Vector3(0, -string_len * 0.5, 0), _mat("twine", Color(0.80, 0.74, 0.58)))
	match kind:
		"ham":
			var s := SphereMesh.new()
			s.radius = 0.08
			s.height = 0.30
			_mesh(n, s, Vector3(0, -string_len - 0.15, 0), _mat("ham", Color(0.52, 0.18, 0.12)))
		"cloth":
			var col := _cloth_colour(r)
			_box(n, Vector3(0.24, 0.55, 0.012), Vector3(0, -string_len - 0.27, 0), _mat_c(col))
		"herbs":
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 0.06
			c.height = 0.22
			_mesh(n, c, Vector3(0, -string_len - 0.11, 0), _mat("herb", Color(0.36, 0.48, 0.22)))
	return n


static func _jar(r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "Jar"
	var h := 0.12 if r == null else r.randf_range(0.09, 0.16)
	var c := CylinderMesh.new()
	c.top_radius = 0.045
	c.bottom_radius = 0.05
	c.height = h
	var glaze := [Color(0.28, 0.40, 0.58), Color(0.86, 0.82, 0.70), Color(0.42, 0.26, 0.18),
		Color(0.30, 0.48, 0.34)]
	_mesh(n, c, Vector3(0, h * 0.5, 0), _mat_c(glaze[0 if r == null else r.randi_range(0, 3)]))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.03
	lid.bottom_radius = 0.035
	lid.height = 0.025
	_mesh(n, lid, Vector3(0, h + 0.012, 0), _mat("cork", Color(0.70, 0.56, 0.38)))
	_box(n, Vector3(0.05, 0.035, 0.004), Vector3(0, h * 0.5, -0.05), _mat("label", Color(0.96, 0.94, 0.86)))
	return n


static func _flask(r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "Flask"
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	var tints := [Color(0.20, 0.70, 0.35), Color(0.55, 0.20, 0.65), Color(0.85, 0.30, 0.20)]
	var glass := _mat_c(tints[0 if r == null else r.randi_range(0, 2)], true)
	_mesh(n, s, Vector3(0, 0.06, 0), glass)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.014
	neck.bottom_radius = 0.018
	neck.height = 0.09
	_mesh(n, neck, Vector3(0, 0.15, 0), _mat("glass", Color(0.75, 0.85, 0.85)))
	return n


static func _mortar() -> Node3D:
	var n := Node3D.new()
	n.name = "MortarAndPestle"
	var c := CylinderMesh.new()
	c.top_radius = 0.08
	c.bottom_radius = 0.06
	c.height = 0.08
	var stone := _mat("marble", Color(0.80, 0.78, 0.74))
	_mesh(n, c, Vector3(0, 0.04, 0), stone)
	var pestle := CylinderMesh.new()
	pestle.top_radius = 0.012
	pestle.bottom_radius = 0.02
	pestle.height = 0.17
	var pm := _mesh(n, pestle, Vector3(0.03, 0.12, 0), stone)
	pm.rotation.z = -0.45
	return n


static func _alembic() -> Node3D:
	var n := Node3D.new()
	n.name = "Alembic"
	var copper := _mat("copper", Color(0.78, 0.45, 0.25))
	var iron := _mat("iron", Color(0.20, 0.20, 0.22))
	# a little brazier ring, the copper pot, its head and the spout to a flask
	var ring := CylinderMesh.new()
	ring.top_radius = 0.10
	ring.bottom_radius = 0.10
	ring.height = 0.07
	_mesh(n, ring, Vector3(0, 0.035, 0), iron)
	_box(n, Vector3(0.08, 0.02, 0.003), Vector3(0, 0.035, -0.101), _mat("ember", Color(1.0, 0.42, 0.10), true))
	var pot := SphereMesh.new()
	pot.radius = 0.10
	pot.height = 0.18
	_mesh(n, pot, Vector3(0, 0.15, 0), copper)
	var head := CylinderMesh.new()
	head.top_radius = 0.025
	head.bottom_radius = 0.06
	head.height = 0.10
	_mesh(n, head, Vector3(0, 0.28, 0), copper)
	var spout := CylinderMesh.new()
	spout.top_radius = 0.008
	spout.bottom_radius = 0.012
	spout.height = 0.22
	var sm := _mesh(n, spout, Vector3(0.10, 0.27, 0), copper)
	sm.rotation.z = -1.1
	var f := _flask(null)
	f.position = Vector3(0.21, 0.0, 0)
	f.scale = Vector3(0.8, 0.8, 0.8)
	n.add_child(f)
	return n


static func _scales() -> Node3D:
	var n := Node3D.new()
	n.name = "Scales"
	var brass := _mat("brass", Color(0.80, 0.64, 0.28))
	_box(n, Vector3(0.20, 0.02, 0.10), Vector3(0, 0.01, 0), _mat("wood_dark", Color(0.32, 0.20, 0.12)))
	_box(n, Vector3(0.015, 0.30, 0.015), Vector3(0, 0.17, 0), brass)
	_box(n, Vector3(0.36, 0.012, 0.012), Vector3(0, 0.31, 0), brass)
	var pan := CylinderMesh.new()
	pan.top_radius = 0.07
	pan.bottom_radius = 0.05
	pan.height = 0.02
	for sx in [-1.0, 1.0]:
		_box(n, Vector3(0.004, 0.16, 0.004), Vector3(sx * 0.17, 0.23, 0), brass)
		_mesh(n, pan, Vector3(sx * 0.17, 0.15, 0), brass)
	return n


static func _ledger() -> Node3D:
	var n := Node3D.new()
	n.name = "Ledger"
	_box(n, Vector3(0.30, 0.02, 0.22), Vector3(0, 0.01, 0), _mat("leather", Color(0.36, 0.18, 0.10)))
	_box(n, Vector3(0.13, 0.012, 0.20), Vector3(-0.07, 0.026, 0), _mat("label", Color(0.96, 0.94, 0.86)))
	_box(n, Vector3(0.13, 0.012, 0.20), Vector3(0.07, 0.026, 0), _mat("label", Color(0.96, 0.94, 0.86)))
	return n


static func _crock(r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "Crock"
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.075
	c.height = 0.16
	var tones := [Color(0.55, 0.40, 0.26), Color(0.80, 0.74, 0.60), Color(0.36, 0.30, 0.26)]
	_mesh(n, c, Vector3(0, 0.08, 0), _mat_c(tones[0 if r == null else r.randi_range(0, 2)]))
	return n


static func _cheese() -> Node3D:
	var n := Node3D.new()
	n.name = "CheeseWheel"
	var c := CylinderMesh.new()
	c.top_radius = 0.10
	c.bottom_radius = 0.10
	c.height = 0.07
	_mesh(n, c, Vector3(0, 0.035, 0), _mat("cheese", Color(0.93, 0.76, 0.32)))
	return n


static func _sack_small() -> Node3D:
	var n := Node3D.new()
	n.name = "SmallSack"
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.18
	_mesh(n, s, Vector3(0, 0.09, 0), _mat("hessian", Color(0.76, 0.66, 0.46)))
	var neck := CylinderMesh.new()
	neck.top_radius = 0.03
	neck.bottom_radius = 0.02
	neck.height = 0.05
	_mesh(n, neck, Vector3(0, 0.19, 0), _mat("hessian", Color(0.76, 0.66, 0.46)))
	return n


static func _mug() -> Node3D:
	var n := Node3D.new()
	n.name = "Tankard"
	var c := CylinderMesh.new()
	c.top_radius = 0.04
	c.bottom_radius = 0.045
	c.height = 0.12
	var wood := _mat("stave", Color(0.50, 0.32, 0.18))
	_mesh(n, c, Vector3(0, 0.06, 0), wood)
	_box(n, Vector3(0.015, 0.08, 0.04), Vector3(0.05, 0.06, 0), wood)
	return n


static func _keg() -> Node3D:
	var n := Node3D.new()
	n.name = "TappedCask"
	var wood := _mat("stave", Color(0.50, 0.32, 0.18))
	var iron := _mat("iron", Color(0.20, 0.20, 0.22))
	_box(n, Vector3(0.05, 0.06, 0.26), Vector3(-0.14, 0.03, 0), wood)
	_box(n, Vector3(0.05, 0.06, 0.26), Vector3(0.14, 0.03, 0), wood)
	var c := CylinderMesh.new()
	c.top_radius = 0.13
	c.bottom_radius = 0.13
	c.height = 0.36
	var cask := _mesh(n, c, Vector3(0, 0.18, 0), wood)
	cask.rotation.x = PI / 2.0
	var hoop := CylinderMesh.new()
	hoop.top_radius = 0.135
	hoop.bottom_radius = 0.135
	hoop.height = 0.025
	for z in [-0.12, 0.12]:
		var hm := _mesh(n, hoop, Vector3(0, 0.18, z), iron)
		hm.rotation.x = PI / 2.0
	# the spigot on the customer's end
	_box(n, Vector3(0.025, 0.025, 0.07), Vector3(0, 0.14, -0.21), _mat("brass", Color(0.80, 0.64, 0.28)))
	return n


static func _bolt(r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "ClothBolt"
	var c := CylinderMesh.new()
	c.top_radius = 0.065
	c.bottom_radius = 0.065
	c.height = 0.18 if r == null else r.randf_range(0.16, 0.20)
	var m := _mesh(n, c, Vector3(0, 0.065, 0), _mat_c(_cloth_colour(r)))
	m.rotation.x = PI / 2.0
	m.scale = Vector3(1, 1, 1)
	return n


static func _folded(r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "FoldedCloth"
	for k in 3:
		_box(n, Vector3(0.16, 0.035, 0.14), Vector3(0, 0.018 + k * 0.036, 0), _mat_c(_cloth_colour(r)))
	return n


static func _cloth_spread(r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "CuttingCloth"
	_box(n, Vector3(0.55, 0.006, 0.40), Vector3(0, 0.003, 0), _mat_c(_cloth_colour(r) if r != null else Color(0.24, 0.32, 0.58)))
	var chalk := _mat("label", Color(0.96, 0.94, 0.86))
	_box(n, Vector3(0.40, 0.002, 0.006), Vector3(0, 0.007, 0.08), chalk)
	_box(n, Vector3(0.006, 0.002, 0.25), Vector3(0.15, 0.007, 0), chalk)
	var shears := _shears()
	shears.position = Vector3(-0.15, 0.006, -0.06)
	n.add_child(shears)
	return n


static func _shears() -> Node3D:
	var n := Node3D.new()
	n.name = "Shears"
	var steel := _mat("steel", Color(0.70, 0.72, 0.75))
	for a in [-0.18, 0.18]:
		var blade := Node3D.new()
		blade.rotation.y = a
		_box(blade, Vector3(0.20, 0.008, 0.018), Vector3(0, 0.006, 0), steel)
		n.add_child(blade)
	return n


static func _garment(r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "Garment"
	var cloth := _mat_c(_cloth_colour(r))
	_box(n, Vector3(0.008, 0.06, 0.008), Vector3(0, -0.03, 0), _mat("twine", Color(0.80, 0.74, 0.58)))
	_box(n, Vector3(0.36, 0.62, 0.025), Vector3(0, -0.37, 0), cloth)
	_box(n, Vector3(0.58, 0.14, 0.024), Vector3(0, -0.13, 0), cloth)
	return n


static func _horseshoe() -> Node3D:
	var n := Node3D.new()
	n.name = "Horseshoe"
	var iron := _mat("iron", Color(0.20, 0.20, 0.22))
	_box(n, Vector3(0.022, 0.12, 0.012), Vector3(-0.045, 0.0, 0), iron)
	_box(n, Vector3(0.022, 0.12, 0.012), Vector3(0.045, 0.0, 0), iron)
	_box(n, Vector3(0.11, 0.022, 0.012), Vector3(0, -0.06, 0), iron)
	return n


static func _hammer() -> Node3D:
	var n := Node3D.new()
	n.name = "Hammer"
	_box(n, Vector3(0.30, 0.025, 0.025), Vector3(0, 0.013, 0), _mat("wood", Color(0.55, 0.38, 0.22)))
	_box(n, Vector3(0.05, 0.05, 0.11), Vector3(0.14, 0.025, 0), _mat("iron", Color(0.20, 0.20, 0.22)))
	return n


static func _tongs() -> Node3D:
	var n := Node3D.new()
	n.name = "Tongs"
	var iron := _mat("iron", Color(0.20, 0.20, 0.22))
	for a in [-0.08, 0.08]:
		var arm := Node3D.new()
		arm.rotation.y = a
		_box(arm, Vector3(0.42, 0.015, 0.015), Vector3(0, 0.008, 0), iron)
		n.add_child(arm)
	return n


static func _blade() -> Node3D:
	var n := Node3D.new()
	n.name = "Blade"
	_box(n, Vector3(0.62, 0.01, 0.045), Vector3(0.08, 0.02, 0), _mat("steel", Color(0.70, 0.72, 0.75)))
	_box(n, Vector3(0.025, 0.02, 0.16), Vector3(-0.24, 0.02, 0), _mat("brass", Color(0.80, 0.64, 0.28)))
	_box(n, Vector3(0.14, 0.03, 0.03), Vector3(-0.33, 0.02, 0), _mat("leather", Color(0.36, 0.18, 0.10)))
	return n


static func _plank(length: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Plank"
	_box(n, Vector3(maxf(length, 0.6), 0.04, 0.24), Vector3(0, 0.02, 0), _mat("pine", Color(0.86, 0.72, 0.50)))
	return n


static func _handsaw() -> Node3D:
	var n := Node3D.new()
	n.name = "Handsaw"
	_box(n, Vector3(0.50, 0.004, 0.11), Vector3(0, 0.045, 0), _mat("steel", Color(0.70, 0.72, 0.75)))
	_box(n, Vector3(0.12, 0.03, 0.06), Vector3(-0.30, 0.05, 0), _mat("wood_dark", Color(0.32, 0.20, 0.12)))
	return n


static func _saw() -> Node3D:
	# a saw hung by its handle from a peg, blade down along the wall
	var n := Node3D.new()
	n.name = "HungSaw"
	_box(n, Vector3(0.06, 0.12, 0.03), Vector3(0, -0.06, 0), _mat("wood_dark", Color(0.32, 0.20, 0.12)))
	_box(n, Vector3(0.11, 0.48, 0.004), Vector3(0, -0.36, 0), _mat("steel", Color(0.70, 0.72, 0.75)))
	return n


static func _square() -> Node3D:
	var n := Node3D.new()
	n.name = "TrySquare"
	var wood := _mat("pine", Color(0.86, 0.72, 0.50))
	_box(n, Vector3(0.03, 0.34, 0.012), Vector3(0, -0.20, 0), wood)
	_box(n, Vector3(0.24, 0.03, 0.012), Vector3(0.105, -0.355, 0), wood)
	return n


static func _plane() -> Node3D:
	var n := Node3D.new()
	n.name = "Plane"
	_box(n, Vector3(0.26, 0.06, 0.07), Vector3(0, 0.03, 0), _mat("wood", Color(0.55, 0.38, 0.22)))
	_box(n, Vector3(0.05, 0.06, 0.03), Vector3(-0.07, 0.09, 0), _mat("wood_dark", Color(0.32, 0.20, 0.12)))
	return n


static func _mallet() -> Node3D:
	var n := Node3D.new()
	n.name = "Mallet"
	var wood := _mat("wood", Color(0.55, 0.38, 0.22))
	_box(n, Vector3(0.26, 0.025, 0.025), Vector3(0.05, 0.04, 0), wood)
	var c := CylinderMesh.new()
	c.top_radius = 0.05
	c.bottom_radius = 0.05
	c.height = 0.14
	var head := _mesh(n, c, Vector3(-0.12, 0.05, 0), _mat("pine", Color(0.86, 0.72, 0.50)))
	head.rotation.x = PI / 2.0
	return n


static func _chisel() -> Node3D:
	var n := Node3D.new()
	n.name = "Chisels"
	for k in 3:
		_box(n, Vector3(0.10, 0.02, 0.02), Vector3(-0.05, 0.01, -0.04 + k * 0.04), _mat("wood", Color(0.55, 0.38, 0.22)))
		_box(n, Vector3(0.10, 0.006, 0.016), Vector3(0.05, 0.006, -0.04 + k * 0.04), _mat("steel", Color(0.70, 0.72, 0.75)))
	return n


static func _bowl(r: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.name = "TurnedBowl"
	var c := CylinderMesh.new()
	c.top_radius = 0.09 if r == null else r.randf_range(0.07, 0.11)
	c.bottom_radius = 0.05
	c.height = 0.07
	_mesh(n, c, Vector3(0, 0.035, 0), _mat("pine", Color(0.86, 0.72, 0.50)))
	return n


static func _cloth_colour(r: RandomNumberGenerator) -> Color:
	var dyes := [Color(0.62, 0.14, 0.12), Color(0.20, 0.30, 0.58), Color(0.86, 0.74, 0.30),
		Color(0.90, 0.86, 0.76), Color(0.26, 0.46, 0.26), Color(0.42, 0.22, 0.42)]
	return dyes[0 if r == null else r.randi_range(0, dyes.size() - 1)]


# ------------------------------------------------------------------ mesh helpers

static func _add(parent: Node3D, child: Node3D, at: Vector3, yaw: float) -> void:
	child.position = at
	child.rotation.y += yaw
	parent.add_child(child)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, pos, mat)


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


static func _mat(name_: String, colour: Color, glow := false) -> StandardMaterial3D:
	var k := "%s/%s/%s" % [name_, colour.to_html(), glow]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.85
	if glow:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 1.5
	_mats[k] = m
	return m


static func _mat_c(colour: Color, glassy := false) -> StandardMaterial3D:
	var m := _mat("c", colour)
	if glassy:
		m = _mat("glassy", colour)
		m.roughness = 0.2
		m.metallic_specular = 0.8
	return m
