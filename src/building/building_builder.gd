class_name BuildingBuilder
extends RefCounted
## Builds an ArrayMesh from a BuildingSpec.
##
## One ArrayMesh with 4 surfaces:
##   0 = walls/plaster, 1 = timber frame, 2 = roof, 3 = trim/details.
## Everything is a transformed box appended to a SurfaceTool per surface.
## Chunky low-poly look in the TinyGlade spirit.

const SURF_WALL := 0
const SURF_TIMBER := 1
const SURF_ROOF := 2
const SURF_TRIM := 3

var spec: BuildingSpec
var _sts: Array = []          # one SurfaceTool per surface
var _rng := RandomNumberGenerator.new()

func build(p_spec: BuildingSpec) -> ArrayMesh:
	spec = p_spec
	# Re-seed from the spec so a given spec always builds the same mesh, no
	# matter how many times it has been built before.
	_rng.seed = p_spec.seed
	_sts.clear()
	for i in range(4):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sts.append(s)

	var w := spec.width
	var d := spec.depth
	var fh := spec.floor_height
	var total_h := fh * spec.floors

	# --- foundation plinth ---
	box(Vector3(w * 0.5 + 0.25, 0.35, d * 0.5 + 0.25), Vector3(0, 0.175, 0), SURF_WALL)

	# --- walls per floor, jettied floors for EU townhouses ---
	for f in range(spec.floors):
		var fw := w
		var fd := d
		if spec.style == &"european" and f > 0 and spec.subtype != "tower_house":
			var jet := minf(0.35, _rand() * 0.3)
			fw = w + jet * 2.0
			fd = d + jet * 2.0
		var y0 := 0.3 + f * fh
		var cy := y0 + fh * 0.5
		var t := 0.18
		box(Vector3(fw, fh, t), Vector3(0, cy, -fd / 2.0), SURF_WALL)
		box(Vector3(fw, fh, t), Vector3(0, cy, fd / 2.0), SURF_WALL)
		box(Vector3(t, fh, fd - t * 2), Vector3(-fw / 2.0, cy, 0), SURF_WALL)
		box(Vector3(t, fh, fd - t * 2), Vector3(fw / 2.0, cy, 0), SURF_WALL)

		# corner posts + band beams (timber framing)
		var post_t := 0.22
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				box(Vector3(post_t, fh + 0.05, post_t),
					Vector3(sx * (fw / 2.0 - post_t / 2.0), cy, sz * (fd / 2.0 - post_t / 2.0)), SURF_TIMBER)
		box(Vector3(fw + 0.15, 0.16, fd + 0.15), Vector3(0, y0 + 0.08, 0), SURF_TIMBER)
		box(Vector3(fw + 0.06, 0.1, fd + 0.06), Vector3(0, y0 + fh * 0.62, 0), SURF_TIMBER)

		add_windows_for_floor(f, fw, fd, y0, fh)

	add_door(w, d)

	if spec.porch:
		add_porch(w, d)

	if spec.chimney:
		var cx := w * 0.32 * (1.0 if _rand() < 0.5 else -1.0)
		var ch := total_h + spec.roof_pitch * minf(w, d) * 0.6 + _rand_range(0.4, 1.0)
		box(Vector3(0.7, ch, 0.7), Vector3(cx, ch / 2.0, d * 0.28), SURF_WALL)
		box(Vector3(0.95, 0.22, 0.95), Vector3(cx, ch + 0.11, d * 0.28), SURF_TRIM)

	match spec.roof_type:
		&"tiered":
			build_tiered_roof(w, d, total_h)
		&"hip":
			build_roof(w, d, total_h, true, false)
		&"pyramidal":
			build_roof(w, d, total_h, true, false, true)
		&"hipped_gable":
			build_roof(w, d, total_h, true, true)
		_:
			build_roof(w, d, total_h, false, false)

	if spec.dormer_count > 0:
		for i in range(spec.dormer_count):
			add_dormer(w, d, total_h, i)

	var mesh := ArrayMesh.new()
	for s in _sts:
		s.generate_normals()
		s.commit(mesh)
	return mesh

# ---------------------------------------------------------------- helpers

## Build-time randomness comes from the builder's OWN generator, re-seeded from
## the spec on every build. Drawing from spec.rng instead advanced the spec's
## stream, so building the same spec twice produced different meshes -- and
## shadowed @GlobalScope.randf while doing it.
func _rand() -> float:
	return _rng.randf()

func _rand_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)

## Append an axis-aligned box at pos (center) with size into surface surf.
## rot_y: rotation around Y. shear: z += y * shear (for upturned eaves).
func box(size: Vector3, pos: Vector3, surf: int, rot_y := 0.0, shear := 0.0) -> void:
	var hx := size.x / 2.0
	var hy := size.y / 2.0
	var hz := size.z / 2.0
	var local := [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
		Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz),
	]
	var basis := Basis(Vector3.UP, rot_y)
	var pts: Array = []
	for c in local:
		var p: Vector3 = c
		p.z += p.y * shear
		pts.append(pos + basis * p)
	# faces as quads (indices into pts), outward normals
	var quads := [
		[0, 1, 2, 3], [4, 5, 6, 7],      # -z, +z
		[1, 4, 7, 2], [5, 0, 3, 6],      # +x, -x
		[3, 2, 7, 6], [0, 5, 4, 1],      # top, bottom
	]
	var normals := [
		Vector3(0, 0, -1), Vector3(0, 0, 1),
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
	]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var s: SurfaceTool = _sts[surf]
	for qi in range(quads.size()):
		var q: Array = quads[qi]
		var n: Vector3 = normals[qi]
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for vi in range(3):
				s.set_normal(n)
				s.set_uv(uvs[vi] if vi < 2 else uvs[0])
				s.add_vertex(pts[tri[vi]])

# ---------------------------------------------------------------- parts

func add_windows_for_floor(f: int, fw: float, fd: float, y0: float, fh: float) -> void:
	if spec.subtype == "barn" and f == 0:
		return
	var wy := y0 + fh * 0.55
	var cols: int = spec.window_cols
	var spacing := fw / float(cols + 1)
	for side in range(2):
		var zc := (fd / 2.0 + 0.02) if side == 0 else -(fd / 2.0 + 0.02)
		for c in range(cols):
			window(-fw / 2.0 + spacing * (c + 1), wy, zc, side == 1)
	if f >= 1:
		for sx in [-1.0, 1.0]:
			window(sx * (fw / 2.0 + 0.02), wy, 0.0, sx < 0)

func window(x: float, y: float, z: float, flip: bool) -> void:
	var ww := _rand_range(0.55, 0.85)
	var wh := _rand_range(0.8, 1.2)
	var rot := PI if flip else 0.0
	box(Vector3(ww, wh, 0.06), Vector3(x, y, z), SURF_TRIM, rot)
	var ft := 0.09
	box(Vector3(ww + ft * 2, ft, 0.1), Vector3(x, y + wh / 2.0 + ft / 2.0, z), SURF_TIMBER, rot)
	box(Vector3(ww + ft * 2, ft, 0.1), Vector3(x, y - wh / 2.0 - ft / 2.0, z), SURF_TIMBER, rot)
	box(Vector3(ft, wh, 0.1), Vector3(x - ww / 2.0 - ft / 2.0, y, z), SURF_TIMBER, rot)
	box(Vector3(ft, wh, 0.1), Vector3(x + ww / 2.0 + ft / 2.0, y, z), SURF_TIMBER, rot)
	box(Vector3(0.06, wh, 0.1), Vector3(x, y, z), SURF_TIMBER, rot)

func add_door(w: float, d: float) -> void:
	var offs := [
		[Vector3(0, 0, d / 2.0), 0.0],
		[Vector3(w / 2.0, 0, 0), PI / 2.0],
		[Vector3(0, 0, -d / 2.0), PI],
		[Vector3(-w / 2.0, 0, 0), -PI / 2.0],
	]
	var o: Array = offs[spec.door_side]
	var pos: Vector3 = o[0]
	var rot: float = o[1]
	var dh := minf(spec.floor_height * 0.75, 2.3)
	var dw := _rand_range(0.95, 1.25)
	var y := dh / 2.0 + 0.3
	var fwd := Vector3(0, 1, 0).rotated(Vector3.RIGHT, PI / 2.0) # unused placeholder
	fwd = Vector3(0, 0, 1)
	box(Vector3(dw, dh, 0.08), pos + Vector3(0, y, 0), SURF_TRIM, rot)
	box(Vector3(dw + 0.5, 0.14, 0.16), pos + Vector3(0, dh + 0.37, 0), SURF_TIMBER, rot)
	for sx in [-1.0, 1.0]:
		var off := Vector3(sx * (dw / 2.0 + 0.07), y, 0).rotated(Vector3.UP, rot)
		box(Vector3(0.13, dh + 0.1, 0.16), pos + off, SURF_TIMBER, rot)

func add_porch(w: float, d: float) -> void:
	var pd := _rand_range(1.2, 2.0)
	var pw := w * _rand_range(0.5, 0.8)
	var zc := d / 2.0 + pd / 2.0 - 0.1
	box(Vector3(pw + 0.6, 0.25, pd + 0.3), Vector3(0, 0.42, zc), SURF_TIMBER)
	box(Vector3(pw + 0.9, 0.14, pd + 0.5), Vector3(0, spec.floor_height * 0.62, zc), SURF_ROOF)
	for sx in [-1.0, 1.0]:
		box(Vector3(0.12, spec.floor_height * 0.6, 0.12),
			Vector3(sx * pw / 2.0, 0.3 + spec.floor_height * 0.3, d / 2.0 + pd - 0.25), SURF_TIMBER)

## Stepped slab roof: layers of shrinking boxes form a readable pitched silhouette.
func build_roof(w: float, d: float, base_y: float, hipped: bool, hipped_gable: bool, pyramid := false) -> void:
	var run_x := w / 2.0 + spec.roof_overhang
	var run_z := d / 2.0 + spec.roof_overhang
	var rise := maxf(run_x, run_z) * spec.roof_pitch
	var layers := 6
	var slab_t := rise / layers * 1.4

	for i in range(layers):
		var t1 := float(i + 1) / layers
		var y := base_y + rise * t1 - slab_t / 2.0
		var sx: float = lerp(run_x * 2.0, 0.6, pow(t1, 0.9))
		var sz: float = lerp(run_z * 2.0, 0.6, pow(t1, 0.9))
		if not hipped and not pyramid:
			sx = run_x * 2.0 + 0.001     # gable keeps full width
		elif hipped_gable:
			sx = lerp(run_x * 2.0, w * 0.45, pow(t1, 1.6))
		box(Vector3(maxf(sx, 0.3), slab_t, maxf(sz, 0.3)), Vector3(0, y, 0), SURF_ROOF)

	box(Vector3(0.5, 0.3, 0.5), Vector3(0, base_y + rise + 0.05, 0), SURF_TRIM)
	if not pyramid:
		box(Vector3(w * 0.55, 0.22, 0.35), Vector3(0, base_y + rise + 0.02, 0), SURF_TRIM)

	# eave fascia boards
	for szf in [-1.0, 1.0]:
		box(Vector3(run_x * 2.0 + 0.2, 0.12, 0.14),
			Vector3(0, base_y + 0.06, szf * (run_z - 0.07)), SURF_TIMBER)
	if hipped or pyramid:
		for sxf in [-1.0, 1.0]:
			box(Vector3(0.14, 0.12, run_z * 2.0 - 0.2),
				Vector3(sxf * (run_x - 0.07), base_y + 0.06, 0), SURF_TIMBER)

## Pagoda-style: a shallow pyramidal roof per tier, shrinking each level,
## with upturned corner eaves driven by spec.upturned_eaves.
func build_tiered_roof(w: float, d: float, base_y: float) -> void:
	var tiers: int = spec.roof_tiers
	for t in range(tiers):
		var y := base_y + spec.floor_height * t
		var scale := 1.0 - 0.09 * t
		pyramid_slab((w + spec.roof_overhang * 2.0) * scale,
			(d + spec.roof_overhang * 2.0) * scale,
			spec.floor_height * 0.55 * spec.roof_pitch + 0.5, y, spec.upturned_eaves)
	var tip := base_y + spec.floor_height * tiers
	box(Vector3(0.16, 1.1, 0.16), Vector3(0, tip + 0.55, 0), SURF_TRIM)
	box(Vector3(0.5, 0.1, 0.5), Vector3(0, tip + 0.15, 0), SURF_TRIM)
	for i in range(3):
		box(Vector3(0.36 - i * 0.1, 0.07, 0.36 - i * 0.1), Vector3(0, tip + 0.35 + i * 0.18, 0), SURF_TRIM)

func pyramid_slab(w: float, d: float, rise: float, base_y: float, upturn: float) -> void:
	var steps := 4
	for i in range(steps):
		var t1 := float(i + 1) / steps
		var y := base_y + rise * t1 - rise / steps
		var sx: float = lerp(w, 0.4, pow(t1, 0.8))
		var sz: float = lerp(d, 0.4, pow(t1, 0.8))
		var sh := upturn * 0.18 * (1.0 - t1)
		box(Vector3(sx, rise / steps * 1.5, sz), Vector3(0, y + rise / steps * 0.5, 0), SURF_ROOF, 0.0, sh)
	if upturn > 0.05:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				box(Vector3(0.12, 0.1, 0.55),
					Vector3(sx * (w / 2.0 - 0.3), base_y + 0.1, sz * (d / 2.0 - 0.3)), SURF_ROOF,
					PI / 4.0 * sx * sz, upturn * 0.5)

func add_dormer(w: float, d: float, base_y: float, index: int) -> void:
	var x := lerpf(-w * 0.25, w * 0.25, float(index) / maxf(spec.dormer_count - 1, 1))
	var y := base_y + spec.roof_pitch * (d / 2.0) * 0.35
	box(Vector3(0.9, 0.9, 0.9), Vector3(x, y, d / 2.0 + 0.2), SURF_WALL)
	box(Vector3(1.2, 0.12, 1.2), Vector3(x, y + 0.55, d / 2.0 + 0.2), SURF_ROOF)
	box(Vector3(0.5, 0.5, 0.06), Vector3(x, y, d / 2.0 + 0.68), SURF_TRIM)
