class_name BlueprintMatchSuite
extends RefCounted
## 3. The blueprint must be a drawing OF the mesh.
##
## BlueprintView draws from ChurchGeometry. So this suite asserts that what
## ChurchGeometry says equals what ChurchBuilder actually emitted -- for each
## structural mass, for the overall envelope, and for the mesh's real vertices.
## When the view derived its own positions instead, plan and model drifted by
## metres with nothing to catch it.

const TOL := 0.05
## Roofs legitimately overhang the masses they cover (eaves, spire flares).
const MAX_OVERHANG := 0.6


static func run() -> SuiteResult:
	var res := SuiteResult.new("blueprint")
	for style in TestSweep.styles():
		for i in range(TestSweep.COUNT):
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var who := "%s seed=%d" % [String(style), TestSweep.seed_at(i)]
			res.checked += 1
			_check_masses_match_geometry(spec, builder, who, res)
			_check_envelope(spec, builder, who, res)
			_check_mesh_within_drawn_extents(spec, mesh, who, res)
			_check_finite(spec, who, res)
	return res


## Every mass the builder emitted must sit exactly where ChurchGeometry says.
static func _check_masses_match_geometry(spec: ChurchSpec, builder: ChurchBuilder,
		who: String, res: SuiteResult) -> void:
	for m in builder.mass_log:
		var name: String = m["name"]
		var got: AABB = m["aabb"]
		# Flying-buttress piers and arches are structural but have no single
		# declared position function in ChurchGeometry -- they are placed from
		# per-tier spans derived at build time, not one AABB. Skip them.
		if name.begins_with("flyer_"):
			continue
		var want: AABB
		match name:
			"nave":
				want = ChurchGeometry.nave_aabb(spec)
			"tower":
				want = ChurchGeometry.tower_aabb(spec, 0.0)
			"tower_left":
				want = ChurchGeometry.tower_aabb(spec, -1.0)
			"tower_right":
				want = ChurchGeometry.tower_aabb(spec, 1.0)
			"apse":
				want = ChurchGeometry.apse_aabb(spec)
			"transept":
				want = ChurchGeometry.transept_aabb(spec)
			"ambulatory":
				want = ChurchGeometry.ambulatory_aabb(spec)
			"crossing_tower":
				want = ChurchGeometry.crossing_tower_aabb(spec)
			"pendentive":
				want = ChurchGeometry.pendentive_aabb(spec)
			"dome_drum":
				want = ChurchGeometry.dome_drum_aabb(spec)
			"narthex":
				want = ChurchGeometry.narthex_aabb(spec)
			var n when n.begins_with("aisle_left_"):
				want = ChurchGeometry.aisle_aabb(spec, -1.0, n.get_slice("_", 2).to_int())
			var n when n.begins_with("aisle_right_"):
				want = ChurchGeometry.aisle_aabb(spec, 1.0, n.get_slice("_", 2).to_int())
			var n when n.begins_with("chapel_"):
				want = ChurchGeometry.chapel_aabb(spec, n.get_slice("_", 1).to_int())
			_:
				res.fail("%s: mass '%s' has no ChurchGeometry counterpart" % [who, name])
				continue
		if not _aabb_close(got, want):
			res.fail("%s: %s drawn at %s but built at %s"
				% [who, name, _fmt(want), _fmt(got)])


## The drawn envelope must match the union of what was built.
static func _check_envelope(spec: ChurchSpec, builder: ChurchBuilder,
		who: String, res: SuiteResult) -> void:
	if builder.mass_log.is_empty():
		return
	var u: AABB = builder.mass_log[0]["aabb"]
	for m in builder.mass_log:
		u = u.merge(m["aabb"])
	var zext: Vector2 = ChurchGeometry.mass_length_extent(spec)
	if absf(u.position.z - zext.x) > TOL or absf(u.position.z + u.size.z - zext.y) > TOL:
		res.fail("%s: masses should span [%.2f,%.2f] but span [%.2f,%.2f]"
			% [who, zext.x, zext.y, u.position.z, u.position.z + u.size.z])
	var wext: float = ChurchGeometry.width_extent(spec)
	if u.size.x - wext > TOL:
		res.fail("%s: built width %.2f exceeds drawn width extent %.2f"
			% [who, u.size.x, wext])


## The real mesh must live inside the extents the sheet advertises, allowing
## for roof overhang, and must actually reach the height the sheet dimensions.
static func _check_mesh_within_drawn_extents(spec: ChurchSpec, mesh: ArrayMesh,
		who: String, res: SuiteResult) -> void:
	var mn := Vector3(INF, INF, INF)
	var mx := -Vector3(INF, INF, INF)
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			mn = mn.min(v)
			mx = mx.max(v)
	var zext: Vector2 = ChurchGeometry.length_extent(spec)
	if mn.z < zext.x - MAX_OVERHANG:
		res.fail("%s: mesh reaches z=%.2f, west of drawn extent %.2f"
			% [who, mn.z, zext.x])
	if mx.z > zext.y + MAX_OVERHANG:
		res.fail("%s: mesh reaches z=%.2f, east of drawn extent %.2f"
			% [who, mx.z, zext.y])
	var drawn_h: float = ChurchGeometry.total_height(spec)
	if mx.y > drawn_h + MAX_OVERHANG:
		res.fail("%s: mesh is %.2fm tall but the sheet dimensions %.2fm"
			% [who, mx.y, drawn_h])
	if mx.y < drawn_h - MAX_OVERHANG:
		res.warn("%s: sheet dimensions %.2fm but mesh only reaches %.2fm"
			% [who, drawn_h, mx.y])


## A blueprint that divides by zero draws nothing; catch it as data, not paint.
static func _check_finite(spec: ChurchSpec, who: String, res: SuiteResult) -> void:
	var vals := {
		"total_height": ChurchGeometry.total_height(spec),
		"width_extent": ChurchGeometry.width_extent(spec),
		"door_height": ChurchGeometry.door_height(spec),
		"transept_depth": ChurchGeometry.transept_depth(spec),
	}
	for k in vals:
		var v: float = vals[k]
		if not is_finite(v) or v <= 0.0:
			res.fail("%s: ChurchGeometry.%s is %s" % [who, k, str(v)])
	if ChurchGeometry.nave_window_count(spec) < 1:
		res.fail("%s: nave_window_count is 0, window spacing would divide by zero" % who)


static func _aabb_close(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) <= TOL and a.size.distance_to(b.size) <= TOL


static func _fmt(a: AABB) -> String:
	return "[%.2f,%.2f,%.2f]+%.2fx%.2fx%.2f" % [a.position.x, a.position.y, a.position.z,
		a.size.x, a.size.y, a.size.z]
