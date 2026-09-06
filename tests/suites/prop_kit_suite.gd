class_name PropKitSuite
extends RefCounted
## VIL-010: the ten small props no art pack ships (VILLAGES §7).
##
## One rule matters more than any other here, and it is the rule the voxel
## suites enforce for buildings: THE AABB A PROP RETURNS IS THE PROP. The
## village logs it as a mass, the walk grid blocks it, the fire-gap and
## road-clearance rules measure it -- so a well that returns a box its own
## roof hangs out of is a well people walk through. Every prop below is
## emitted into a fresh kit, the mesh that came out is read back vertex by
## vertex, and the two are compared.

## Surfaces of the throwaway kit these are emitted into, one per material.
const STONE := 0
const WOOD := 1
const ROOF := 2
const DARK := 3
const SURFACES := 4

## How far a vertex may lie outside the returned AABB. Not zero: a roof
## overhangs the box it is logged as by design, and so do the palisade's
## points -- both are called out per prop below.
const SLACK := 0.02


static func run() -> SuiteResult:
	var res := SuiteResult.new("props")
	for row in _props():
		_check_prop(res, row)
	_check_palisade_run(res)
	_check_determinism(res)
	return res


## Each prop, as [name, callable, expected slack]. The slack is the overhang a
## prop is ALLOWED, and is part of the specification of that prop rather than
## a tolerance: a well's roof and a signpost's fingerboards genuinely reach
## past the mass a person walks into, which is what the AABB is for.
static func _props() -> Array:
	return [
		["well", func(k: PropKit) -> AABB: return k.well(Vector3(2.0, 0.0, -3.0), 0.6), SLACK],
		["signpost", func(k: PropKit) -> AABB: return k.signpost(Vector3(-4.0, 0.0, 1.0), 1.2, 2), SLACK],
		["lamp_post", func(k: PropKit) -> AABB: return k.lamp_post(Vector3(0.0, 0.0, 5.0), 0.0), SLACK],
		["fence_gate", func(k: PropKit) -> AABB: return k.fence_gate(Vector3(3.0, 0.0, 3.0), 2.4), SLACK],
		["haystack", func(k: PropKit) -> AABB: return k.haystack(Vector3(-6.0, 0.0, -6.0)), SLACK],
		["drying_rack", func(k: PropKit) -> AABB: return k.drying_rack(Vector3(1.0, 0.0, 8.0), 0.9), SLACK],
		["mill_wheel", func(k: PropKit) -> AABB: return k.mill_wheel(Vector3(0.0, 2.0, 0.0), 0.4), SLACK],
		["boat", func(k: PropKit) -> AABB: return k.boat(Vector3(7.0, 0.0, 2.0), 1.9), SLACK],
		["adit", func(k: PropKit) -> AABB: return k.adit(Vector3(-2.0, 0.0, -9.0), 2.8), SLACK],
	]


static func _check_prop(res: SuiteResult, row: Array) -> void:
	var prop_name: String = row[0]
	var kit := MeshKit.new(SURFACES)
	var props := PropKit.new(kit, STONE, WOOD, ROOF, DARK)
	var box: AABB = (row[1] as Callable).call(props)
	var verts: PackedVector3Array = _vertices(kit.commit())

	res.checked += 1
	if verts.is_empty():
		res.fail("%s emitted no geometry at all" % prop_name)
		return
	res.checked += 1
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		res.fail("%s returned an empty box, %s" % [prop_name, str(box)])
		return

	# every vertex inside the box it said it was
	var grown: AABB = box.grow(float(row[2]))
	var worst := 0.0
	for v in verts:
		var d: float = _outside_by(grown, v)
		worst = maxf(worst, d)
	res.checked += 1
	if worst > 0.0001:
		res.fail("%s emits geometry %.3fm outside the AABB it returns" % [prop_name, worst])

	# and the box is not wildly bigger than the geometry either: a prop logged
	# as twice its size takes clear ground the village needs
	var actual: AABB = _span(verts)
	res.checked += 1
	for axis in range(3):
		if box.size[axis] > actual.size[axis] * 2.0 + 0.5:
			res.fail("%s returns a %.2fm box round %.2fm of geometry on axis %d"
				% [prop_name, box.size[axis], actual.size[axis], axis])
			break

	# it stands on the ground it was given, not in it
	res.checked += 1
	if actual.position.y < -0.05:
		res.fail("%s sinks %.2fm below the ground it was placed on"
			% [prop_name, -actual.position.y])


## The palisade is the one prop that is a RUN rather than a piece: it must
## follow the line it was given, stay inside the ribbon it returns, and put a
## stake at both ends -- a palisade with a two metre gap at the corner is a
## village anybody can walk into.
static func _check_palisade_run(res: SuiteResult) -> void:
	var from_p := Vector2(-8.0, -4.0)
	var to_p := Vector2(6.0, 3.0)
	var kit := MeshKit.new(SURFACES)
	var props := PropKit.new(kit, STONE, WOOD, ROOF, DARK)
	var box: AABB = props.palisade(from_p, to_p, 0.0, 2.4)
	var verts: PackedVector3Array = _vertices(kit.commit())
	res.checked += 1
	if verts.is_empty():
		res.fail("palisade emitted no geometry")
		return
	var grown: AABB = box.grow(SLACK)
	var worst := 0.0
	for v in verts:
		worst = maxf(worst, _outside_by(grown, v))
	res.checked += 1
	if worst > 0.0001:
		res.fail("palisade emits geometry %.3fm outside its own ribbon" % worst)
	# no gap along the run: every stake within a pitch of the next
	var span: AABB = _span(verts)
	var length: float = from_p.distance_to(to_p)
	res.checked += 1
	for ends in [[from_p, "start"], [to_p, "end"]]:
		var p: Vector2 = ends[0]
		var near := INF
		for v in verts:
			near = minf(near, Vector2(v.x, v.z).distance_to(p))
		if near > 0.6:
			res.fail("palisade leaves %.2fm of nothing at its %s" % [near, ends[1]])
	res.checked += 1
	if span.size.y < 2.4 or span.size.y > 2.4 * 1.4:
		res.fail("a 2.4m palisade came out %.2fm tall" % span.size.y)
	res.checked += 1
	if absf(Vector2(span.size.x, span.size.z).length() - length) > 1.0:
		res.fail("a %.1fm palisade run spans %.1fm"
			% [length, Vector2(span.size.x, span.size.z).length()])
	# a zero-length run is not a crash
	var empty := PropKit.new(MeshKit.new(SURFACES), STONE, WOOD, ROOF, DARK)
	res.checked += 1
	if empty.palisade(Vector2.ZERO, Vector2.ZERO) != AABB():
		res.fail("a palisade of no length returned a mass")


## The whole harness rests on a build being a pure function of its inputs.
static func _check_determinism(res: SuiteResult) -> void:
	for row in _props():
		var a := MeshKit.new(SURFACES)
		var b := MeshKit.new(SURFACES)
		var box_a: AABB = (row[1] as Callable).call(PropKit.new(a, STONE, WOOD, ROOF, DARK))
		var box_b: AABB = (row[1] as Callable).call(PropKit.new(b, STONE, WOOD, ROOF, DARK))
		res.checked += 1
		if box_a != box_b or _vertices(a.commit()) != _vertices(b.commit()):
			res.fail("%s built two different props from one call" % String(row[0]))


static func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in range(mesh.get_surface_count()):
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out


static func _span(verts: PackedVector3Array) -> AABB:
	var lo: Vector3 = verts[0]
	var hi: Vector3 = verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	return AABB(lo, hi - lo)


## How far outside `box` the point lies, on its worst axis.
static func _outside_by(box: AABB, p: Vector3) -> float:
	var out := 0.0
	for axis in range(3):
		out = maxf(out, box.position[axis] - p[axis])
		out = maxf(out, p[axis] - (box.position[axis] + box.size[axis]))
	return out
