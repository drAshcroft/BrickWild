extends SceneTree
## CULTURE-FURNISH-VOCAB: the furnished interiors of the minka (asian), the
## Sahel courtyard house (african) and the roundhouse, on each style's three
## frozen requests (tests/fixtures/family_style_requests.json), contain no
## model from the deny list (trestle table, goblet, tankard, chandelier, torch)
## and no plank floor; the furnish and nav checks on the same plans are green;
## every culture look stands inside its row's rect, on its floor or on its
## host's top. Control: a cottage keeps the trestle table and the planks, and
## the same deny check reports them.
##   godot --headless --path . --script res://tests/culture_furnish_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const CULTURE := preload("res://src/house/house_culture_furnish.gd")
const STYLES := [&"asian", &"african", &"roundhouse"]
var failures: Array[String] = []
var warnings: Array[String] = []
var checks := 0


func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for style in STYLES:
		var n := 0
		for c in parsed["cases"]:
			if str(c["id"]).begins_with("house/%s/" % style):
				n += 1
				_check_case(str(c["id"]), c["request"], style)
		_expect(n == 3, "fixture holds 3 house/%s requests, found %d" % [style, n])
	_control()
	for w in warnings:
		print("WARN " + w)
	for f in failures:
		printerr("FAIL " + f)
	print("CULTURE-FURNISH-VOCAB: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _plan(style: StringName, req: Dictionary) -> HousePlan:
	var spec := HouseTraitMeasure.make_spec(style, float(req["width"]), float(req["length"]),
		float(req["height"]), int(req["storeys"]))
	return HouseGenerator.generate(spec, int(req["seed"]), true)


## Denied models found in the assembled furniture, and the floor finish.
func _denied(plan: HousePlan, house: Node3D) -> Array[String]:
	var out: Array[String] = []
	var paths := {}
	for key in CULTURE.DENY:
		paths[PropCatalog.scene_path(key)] = key
	var stack: Array[Node] = [house.get_node("Furniture")]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if paths.has(node.scene_file_path):
			out.append(String(paths[node.scene_file_path]))
		elif String(node.name) in CULTURE.DENY:
			out.append(String(node.name))
		stack.append_array(node.get_children())
	if CULTURE.floor_finish(plan) == "planks":
		out.append("plank floor")
	return out


func _check_case(id: String, req: Dictionary, style: StringName) -> void:
	var plan := _plan(style, req)
	var furnish: Dictionary = HouseFurnishCheck.new().check(plan)
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	# The vocabulary changes no plan row, so a furnish complaint here is the
	# plan's own (the known harchetype reds: a hall with no table while the
	# parlour dines, a workbench off its wall); reported, not counted.
	if not furnish["ok"]:
		warnings.append("%s furnish check, plan-level (%s)" % [id, furnish["failures"]])
	_expect(nav["ok"], "%s nav check (%s)" % [id, nav["failures"]])
	var house: Node3D = HouseAssembler.build(plan, false)
	var denied := _denied(plan, house)
	_expect(denied.is_empty(), "%s furnished interior holds no denied prop (%s)" % [id, denied])
	var want_finish := "tatami" if style == &"asian" else "earth"
	_expect(CULTURE.floor_finish(plan) == want_finish, "%s floor is %s (%s)" % [id, want_finish, CULTURE.floor_finish(plan)])
	var looks: Dictionary = CULTURE.looks(plan)
	_expect(not looks.is_empty(), "%s takes the %s vocabulary (%d looks)" % [id, style, looks.size()])
	var furniture := house.get_node("Furniture")
	var by_row := {}
	var looked := 0
	for child in furniture.get_children():
		if child.has_meta("culture_look"):
			looked += 1
	_expect(looked == looks.size(), "%s one look node per looked row (%d of %d)" % [id, looked, looks.size()])
	# geometry of each look against its row
	var raise := HouseGeometry.floor_raise(plan.spec)
	var idx := 0
	var nodes := furniture.get_children()
	for i in range(plan.furniture.size()):
		if not looks.has(i):
			continue
		var row: Dictionary = plan.furniture[i]
		var node: Node3D = null
		while idx < nodes.size():
			var cand: Node = nodes[idx]
			idx += 1
			if cand.has_meta("culture_look"):
				node = cand
				break
		if node == null:
			break
		var box := _aabb(node)
		box.position.y -= raise
		var look := String(looks[i])
		var rect := Rect2(row["rect"])
		var pos: Vector3 = row["pos"]
		var mounted := bool(row.get("mounted", false)) or PropCatalog.has_tag(String(row["key"]), PropCatalog.CEILING)
		var hosted := int(row.get("host", -1)) >= 0 and PropCatalog.has_tag(String(row["key"]), PropCatalog.ON_SURFACE)
		if not mounted and not hosted:
			var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			_expect(rect.grow(0.03).encloses(foot), "%s row %d %s inside its rect (%s in %s)" % [id, i, look, foot, rect])
		if not mounted and not hosted:
			_expect(absf(box.position.y - pos.y) < 0.02, "%s row %d %s stands on the floor (bottom %.3f, floor %.3f)" % [id, i, look, box.position.y, pos.y])
		if hosted:
			var host_look := String(looks.get(int(row["host"]), ""))
			if host_look in CULTURE.TOPS:
				var top := pos.y + CULTURE.host_shift(plan, i, looks).y
				_expect(absf(box.position.y - top) < 0.02, "%s row %d %s sits on its %s (bottom %.3f, top %.3f)" % [id, i, look, host_look, box.position.y, top])
	house.free()


## The cottage control: no vocabulary, so the deny check must see its stock.
func _control() -> void:
	var req := {"width": 8.0, "length": 10.0, "height": 2.6, "storeys": 1, "seed": 8102}
	var plan := _plan(&"cottage", req)
	var house: Node3D = HouseAssembler.build(plan, false)
	var denied := _denied(plan, house)
	_expect(CULTURE.looks(plan).is_empty(), "control: a cottage takes no culture looks")
	_expect(denied.has("plank floor"), "control: a cottage's plank floor is reported (%s)" % [denied])
	_expect(denied.size() >= 2, "control: a cottage's European stock is reported (%s)" % [denied])
	house.free()


## The node's mesh bounds in the house's frame (the tree is not live in _init,
## so transforms are composed by hand from the house root down).
func _aabb(node: Node3D) -> AABB:
	var xf := Transform3D.IDENTITY
	var up: Node = node
	while up != null and up is Node3D:
		xf = (up as Node3D).transform * xf
		if up.name == "House":
			break
		up = up.get_parent()
	var got = _walk(node, xf, null)
	return got if got != null else AABB()


func _walk(n: Node, xf: Transform3D, acc):
	var out = acc
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
		out = b if out == null else (out as AABB).merge(b)
	for c in n.get_children():
		if c is Node3D:
			var r = _walk(c, xf * (c as Node3D).transform, out)
			out = r
	return out


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)
