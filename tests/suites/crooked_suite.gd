extends RefCounted
## HNT-040/041: the crooked warp. The map's own algebra, the request field,
## every kind's warped mesh against CrookedCheck, the scene leaning with the
## mesh, and the negative controls that keep the check honest.
##
## Hotels are left out of the per-kind sweep: a hotel is a plan family like
## the house and costs ~45 s to generate. The house here has two storeys, so
## the plan-family floor lines are exercised.

const SEEDS := [3, 41, 977, 8102, 23001]


static func run() -> SuiteResult:
	var res := SuiteResult.new("crooked")
	_algebra(res)
	_request(res)
	_negative_controls(res)
	for kind in [&"house", &"shop", &"church", &"castle", &"temple", &"world", &"windmill"]:
		_kind(res, kind)
	# Foundations that came after the warp: its floor lines must still be the
	# floors on a sloped plinth and over a pile deck.
	_kind(res, &"house", {"ground_fall_m": 1.5, "ground_downhill_deg": 90.0}, "house on a slope")
	_kind(res, &"house", {"foundation": &"piles", "pile_water_m": 1.2}, "house on piles")
	_scene(res)
	return res


# ------------------------------------------------------------------ the map

static func _algebra(res: SuiteResult) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for s in SEEDS:
		var keys: Array[float] = [0.0, 2.7, 5.4, 8.1]
		var w := CrookedWarp.make(keys, 1.0, s)
		for failure in CrookedCheck.check_warp(w, "seed %d" % s):
			res.fail(failure)
		res.checked += 1
		for i in range(200):
			var p := Vector3(r.randf_range(-8, 8), r.randf_range(-1, 12), r.randf_range(-8, 8))
			var q := w.point(p)
			_expect(res, is_equal_approx(q.y, p.y), "the warp changed a height (seed %d)" % s)
			_expect(res, (w.affine(w.slab_of(p.y)) * p).distance_to(q) < 1e-4,
				"the storey affine disagrees with the map at %s (seed %d)" % [p, s])
		for k in keys:
			var below := w.point(Vector3(1, k - 1e-6, 1))
			var above := w.point(Vector3(1, k + 1e-6, 1))
			_expect(res, below.distance_to(above) < 1e-4,
				"the map tears at the floor line y=%.2f (seed %d)" % [k, s])
		_expect(res, w.point(Vector3(3, -0.5, 2)) == Vector3(3, -0.5, 2),
			"a cellar below the first floor line moved (seed %d)" % s)
		_expect(res, w.max_lean_deg() > 0.5 * CrookedWarp.MAX_LEAN_DEG,
			"jank 1 barely leaned: %.1f degrees (seed %d)" % [w.max_lean_deg(), s])
		var a := CrookedWarp.make(keys, 1.0, s)
		_expect(res, a.shears == w.shears, "the same seed leaned differently")
		var half := CrookedWarp.make(keys, 0.5, s)
		_expect(res, half.max_lean_deg() <= 0.5 * CrookedWarp.MAX_LEAN_DEG + 0.5,
			"jank 0.5 leaned %.1f degrees" % half.max_lean_deg())


# ------------------------------------------------------------------ the request

static func _request(res: SuiteResult) -> void:
	var plain := BuildingRequest.house(4413, &"cottage")
	_expect(res, not plain.to_json().contains("jank"),
		"a plumb request now writes a jank field: old documents would change bytes")
	var crooked := plain.copy()
	crooked.jank = 0.6
	_expect(res, crooked.copy().jank == 0.6, "copy() dropped jank")
	var back := BuildingRequest.from_json(crooked.to_json())
	_expect(res, back.jank == 0.6 and back._decode_errors.is_empty(),
		"jank did not survive a JSON round trip")
	for bad in [1.5, -0.1, NAN]:
		var r := plain.copy()
		r.jank = bad
		_expect(res, _has_code(BuildingLibrary.validate(r), &"invalid_jank"),
			"jank %s was accepted" % str(bad))
	var village := BuildingLibrary.defaults(&"village", 1)
	village.jank = 0.3
	_expect(res, _has_code(BuildingLibrary.validate(village), &"jank_unsupported"),
		"a crooked village was accepted")
	_expect(res, BrickWild.describe_kind(&"house").has("jank")
		and not BrickWild.describe_kind(&"village").has("jank"),
		"describe_kind does not publish jank where it works, or publishes it where it does not")


# ------------------------------------------------------------------ the fakes

## The check must fail a warp that leans too far, and a mesh warped without
## being cut at the floor lines -- or it is a tautology.
static func _negative_controls(res: SuiteResult) -> void:
	var keys: Array[float] = [0.0, 3.0, 6.0]
	var steep := CrookedWarp.make(keys, 1.0, 5)
	steep.shears[1] = Vector2(0.84, 0.0)    # about forty degrees
	steep._rebase()
	_expect(res, not CrookedCheck.check_warp(steep).is_empty(),
		"a forty-degree storey passed the lean cap")

	var wall := _wall_mesh(0.0, 6.0)
	var w := CrookedWarp.make(keys, 1.0, 9)
	var naive := _naive(w, wall)
	_expect(res, not CrookedCheck.check_one_storey(w, naive).is_empty(),
		"a wall warped without cutting at the floor line passed")
	var proper := w.warp_mesh(wall)
	var failures := CrookedCheck.check(w, wall, proper, "two-storey wall")
	_expect(res, failures.is_empty(), "the real warp of a plain wall failed: %s" % [failures])
	_expect(res, _triangles(proper) > _triangles(wall),
		"a wall spanning a floor line was not cut there")

	var lifted := w.warp_mesh(wall)
	var arrays: Array = lifted.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	v[0].y += 0.25
	arrays[Mesh.ARRAY_VERTEX] = v
	var moved := ArrayMesh.new()
	moved.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_expect(res, not CrookedCheck.check_levels(w, wall, moved).is_empty(),
		"a vertex lifted off its level passed")


## A wall the naive way: every vertex through the map, no cuts.
static func _naive(w: CrookedWarp, mesh: ArrayMesh) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(v.size()):
		v[i] = w.point(v[i])
	arrays[Mesh.ARRAY_VERTEX] = v
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## One wall, 4 m wide, facing -Z, wound the Godot way (clockwise front).
static func _wall_mesh(y0: float, y1: float) -> ArrayMesh:
	var a := Vector3(-2, y0, 0)
	var b := Vector3(2, y0, 0)
	var c := Vector3(2, y1, 0)
	var d := Vector3(-2, y1, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [a, d, c, a, c, b]:
		st.set_normal(MeshKit._face_normal(a, d, c))
		st.set_uv(Vector2(p.x, p.y))
		st.add_vertex(p)
	return st.commit()


# ------------------------------------------------------------------ the kinds

static func _kind(res: SuiteResult, kind: StringName, fields := {}, label := "") -> void:
	var request := BuildingLibrary.defaults(kind, 8102)
	if kind == &"house":
		request.storeys = 2
	for field in fields:
		request.set(field, fields[field])
	if not label.is_empty():
		kind = StringName(label)
	var plumb := BrickWild.generate(request)
	if not plumb.is_ok():
		res.fail("%s did not generate: %s" % [kind, plumb.errors])
		return
	var family := BuildingFamilyAdapter.for_building(plumb)
	var before: ArrayMesh = family.build_mesh(plumb)
	# jank 0: the public mesh is the family's own mesh, not a copy of it
	_expect(res, _same_vertices(BrickWild.build_mesh(plumb), before),
		"%s at jank 0 is not the building as built" % kind)

	request.jank = 1.0
	var crooked := BrickWild.generate(request)
	var warp := CrookedWarp.for_building(crooked)
	if warp == null:
		res.fail("%s at jank 1 has no warp" % kind)
		return
	var after: ArrayMesh = BrickWild.build_mesh(crooked)
	for failure in CrookedCheck.check(warp, before, after, String(kind)):
		res.fail(failure)
	_expect(res, _same_vertices(after, BrickWild.build_mesh(crooked)),
		"%s: the same crooked request built two different meshes" % kind)
	_expect(res, not _same_vertices(after, before),
		"%s at jank 1 did not move" % kind)
	_expect(res, after.get_surface_count() == before.get_surface_count(),
		"%s: the warp changed the surface count, so slot materials would shift" % kind)
	res.note("%s: %d -> %d triangles, lean %.1f deg" % [kind, _triangles(before),
		_triangles(after), warp.max_lean_deg()])


# ------------------------------------------------------------------ the scene

## The assembled house leans exactly as its mesh does, and its furniture
## leans with the storey it stands in.
static func _scene(res: SuiteResult) -> void:
	var request := BuildingRequest.house(8102, &"cottage", &"none", 8.0, 10.0, 2.6, 2)
	request.jank = 1.0
	var building := BrickWild.generate(request)
	var warp := CrookedWarp.for_building(building)
	var root := BrickWild.instantiate(building)
	if root == null or warp == null:
		res.fail("the crooked house did not instantiate")
		return
	var shell := root.get_node_or_null("Shell") as MeshInstance3D
	_expect(res, shell != null and _same_vertices(shell.mesh, BrickWild.build_mesh(building)),
		"the scene's shell is not the crooked mesh")
	var props := 0
	var leaning := 0
	for node in _loaded(root):
		props += 1
		var slab := warp.slab_of(_root_xf(node, root).origin.y + CrookedWarp.PROP_LIFT)
		if slab < 0:
			continue
		var s: Vector2 = warp.shears[slab]
		var y: Vector3 = _root_xf(node, root).basis.y
		# the prop's up axis carries its storey's shear (scaled with the prop)
		if absf(y.x / maxf(y.y, 1e-6) - s.x) < 1e-3 and absf(y.z / maxf(y.y, 1e-6) - s.y) < 1e-3:
			leaning += 1
	_expect(res, props > 0, "the crooked house has no loaded props to lean")
	_expect(res, leaning == props,
		"%d of %d props do not lean with their storey" % [props - leaning, props])
	root.free()


static func _loaded(node: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in node.get_children():
		if child is Node3D and child.scene_file_path != "":
			out.append(child)
		else:
			out.append_array(_loaded(child))
	return out


static func _root_xf(node: Node3D, root: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


# ------------------------------------------------------------------ helpers

static func _same_vertices(a: Mesh, b: Mesh) -> bool:
	if a == null or b == null or a.get_surface_count() != b.get_surface_count():
		return false
	for si in range(a.get_surface_count()):
		if a.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] != b.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			return false
	return true


static func _triangles(mesh: ArrayMesh) -> int:
	var n := 0
	for si in range(mesh.get_surface_count()):
		n += (mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


static func _has_code(errors: Array[Dictionary], code: StringName) -> bool:
	for e in errors:
		if e["code"] == code:
			return true
	return false


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
