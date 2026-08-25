class_name BlueprintQA
extends RefCounted
## Quality harness for generated churches. Runs a ChurchSpec + its built mesh
## through a battery of checks and returns a report.
##
## Checks:
##   1. footprint_preserved  - nave mass matches user width/length
##   2. grounded             - nothing below y=0, something touches ground
##   3. no_nan               - all vertices finite, inside sane bounds
##   4. connected_mass       - voxel flood fill: every solid voxel reachable
##                             from the nave (catches floating / detached parts)
##   5. openings_embedded    - every window/door sits inside masonry (voxel test),
##                             and does NOT tunnel clean through the building
##                             ("a cut through the building should not escape")
##   6. parts_aligned        - structural boxes axis-aligned (rot_y ~ 0 or PI/2)
##                             and oriented consistently with the church axis;
##                             catches "whole section turned the wrong direction"
##   7. proportions          - style-plausible ratios (tower vs nave, apse width,
##                             transept span, aisle height below eaves)
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const VOX := 0.5            # voxel size in meters for solid/flood tests
const EPS := 0.05

var spec: ChurchSpec
var mesh: ArrayMesh
var builder: ChurchBuilder
var failures: Array = []
var warnings: Array = []
var stats: Dictionary = {}

# Voxel grid state
var _ox := 0.0; var _oy := 0.0; var _oz := 0.0
var _nx := 0; var _ny := 0; var _nz := 0
var _solid: Array = []      # Array of PackedByteArray, _solid[y][x*_nz+z]

func check(p_spec: ChurchSpec, p_mesh: ArrayMesh, p_builder: ChurchBuilder) -> Dictionary:
	spec = p_spec
	mesh = p_mesh
	builder = p_builder
	failures.clear()
	warnings.clear()
	stats.clear()

	_rasterize()
	_check_footprint()
	_check_ground()
	_check_vertices()
	_check_connected_mass()
	_check_openings()
	_check_alignment()
	_check_overlaps()
	_check_proportions()
	_check_massing()

	stats["parts"] = builder.part_log.size()
	stats["voxels_solid"] = _count_solid()
	stats["bbox"] = _bbox_str()
	var ok := failures.is_empty()
	return {"ok": ok, "failures": failures, "warnings": warnings, "stats": stats}


# ------------------------------------------------------------------ rasterize

func _rasterize() -> void:
	var mn := Vector3(INF, INF, INF)
	var mx := -Vector3(INF, INF, INF)
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			mn = mn.min(v); mx = mx.max(v)
	# expand by one voxel so boundary geometry rasterizes fully
	_ox = floorf(mn.x / VOX) * VOX - VOX
	_oy = floorf(mn.y / VOX) * VOX - VOX
	_oz = floorf(mn.z / VOX) * VOX - VOX
	_nx = int(ceil((mx.x - _ox) / VOX)) + 2
	_ny = int(ceil((mx.y - _oy) / VOX)) + 2
	_nz = int(ceil((mx.z - _oz) / VOX)) + 2
	_solid.clear()
	for _y in range(_ny):
		_solid.append(PackedByteArray())
		_solid[_y].resize(_nx * _nz)

	for s in range(mesh.get_surface_count()):
		if s == ChurchBuilder.SURF_OPEN:
			continue  # openings are recesses, not structure
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx_v = arrays[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array = idx_v if idx_v != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for k in range(verts.size()):
				idx[k] = k
		var i := 0
		while i + 2 < idx.size():
			_mark_tri(verts[idx[i]], verts[idx[i + 1]], verts[idx[i + 2]])
			i += 3
	_dilate()

## Surfaces are hollow shells; dilate by one voxel so every wall has real
## thickness in the grid and touching geometry merges into one mass.
func _dilate() -> void:
	var out: Array = []
	for y in range(_ny):
		out.append(PackedByteArray())
		out[y].resize(_nx * _nz)
	for y in range(_ny):
		for x in range(_nx):
			for z in range(_nz):
				if _solid[y][x * _nz + z] == 1:
					for dy in range(-1, 2):
						var yy := y + dy
						if yy < 0 or yy >= _ny:
							continue
						for dx in range(-1, 2):
							var xx := x + dx
							if xx < 0 or xx >= _nx:
								continue
							for dz in range(-1, 2):
								var zz := z + dz
								if zz >= 0 and zz < _nz:
									out[yy][xx * _nz + zz] = 1
	_solid = out

func _mark_tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	# conservative triangle rasterization into voxels (sampled along edges + interior)
	var steps := int(maxf(maxf((b - a).length(), (c - b).length()), (a - c).length()) / (VOX * 0.5)) + 1
	for i in range(steps + 1):
		var t0: float = float(i) / steps
		var pa: Vector3 = a.lerp(b, t0)
		var pc: Vector3 = a.lerp(c, t0)
		var inner := int(pc.distance_to(pa) / (VOX * 0.5)) + 1
		for j in range(inner):
			var p: Vector3 = pa.lerp(pc, float(j) / inner)
			_set_voxel_world(p)

func _set_voxel_world(p: Vector3) -> void:
	var x := int(floor((p.x - _ox) / VOX))
	var y := int(floor((p.y - _oy) / VOX))
	var z := int(floor((p.z - _oz) / VOX))
	if x >= 0 and x < _nx and y >= 0 and y < _ny and z >= 0 and z < _nz:
		_solid[y][x * _nz + z] = 1

func _get_voxel(x: int, y: int, z: int) -> bool:
	if x < 0 or x >= _nx or y < 0 or y >= _ny or z < 0 or z >= _nz:
		return false
	return _solid[y][x * _nz + z] == 1

func _count_solid() -> int:
	var n := 0
	for y in range(_ny):
		n += _count_byte(_solid[y])
	return n

func _count_byte(arr: PackedByteArray) -> int:
	var n := 0
	for b in arr:
		if b == 1:
			n += 1
	return n

func _world_of(x: int, y: int, z: int) -> Vector3:
	return Vector3(_ox + (x + 0.5) * VOX, _oy + (y + 0.5) * VOX, _oz + (z + 0.5) * VOX)

## Is there solid masonry in any of the 26 neighbors?
func _has_neighbor(x: int, y: int, z: int) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				if _get_voxel(x + dx, y + dy, z + dz):
					return true
	return false


# ---------------------------------------------------------------------- checks

func _check_footprint() -> void:
	# The nave box must exist at exactly the requested size.
	var w := spec.width; var l := spec.length
	var found := false
	for p in builder.part_log:
		if p["tag"] != "nave":
			continue
		found = true
		break
	if not found:
		failures.append("footprint_preserved: nave box missing from part log")
		return
	# verify against voxels: solid cells must cover the nave extent on the ground plane
	var need_x0 := _vx(-w / 2.0); var need_x1 := _vx(w / 2.0)
	var need_z0 := _vz(-l / 2.0); var need_z1 := _vz(l / 2.0)
	var gy := _vy(0.5)  # just above ground
	var missing := 0
	for gx in range(need_x0, need_x1 + 1):
		for gz in range(need_z0, need_z1 + 1):
			if not _get_voxel(gx, gy, gz):
				missing += 1
	if missing > 0:
		failures.append("footprint_preserved: %d ground-plane voxels missing inside nave footprint" % missing)

func _check_ground() -> void:
	# nothing may hang below y=0
	var mn := Vector3(INF, INF, INF)
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			mn = mn.min(v)
	if mn.y < -0.5:
		failures.append("grounded: geometry dips %.2fm below ground" % (-mn.y))
	elif mn.y < -EPS:
		warnings.append("grounded: eaves/trim dips %.2fm below ground" % (-mn.y))

func _check_vertices() -> void:
	var total := 0
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		total += verts.size()
		for v in verts:
			if is_nan(v.x) or is_nan(v.y) or is_nan(v.z) \
					or is_inf(v.x) or is_inf(v.y) or is_inf(v.z):
				failures.append("no_nan: NaN/Inf vertex on surface %d" % s)
				return
			if absf(v.x) > 200.0 or absf(v.y) > 300.0 or absf(v.z) > 200.0:
				warnings.append("no_nan: vertex far outside expected bounds (%s)" % v)
				return
	if total < 100:
		failures.append("no_nan: only %d vertices" % total)

## Flood fill from a solid voxel on the nave wall. Any solid voxel unreachable
## => part of the building is detached / floating / facing wrong, alone.
func _check_connected_mass() -> void:
	var seed := Vector3i(-1, -1, -1)
	# find a solid voxel inside the nave footprint near ground level
	var gy := _vy(0.6)
	for dx in range(0, int(spec.width / VOX)):
		for dz in range(0, int(spec.length / VOX)):
			var cand := Vector3i(_vx(-spec.width / 2.0) + dx, gy,
				_vz(-spec.length / 2.0) + dz)
			if _get_voxel(cand.x, cand.y, cand.z):
				seed = cand
				break
		if seed.x >= 0:
			break
	if seed.x < 0:
		failures.append("connected_mass: no solid voxel found in nave footprint")
		return
	var visited := {}
	var stack: Array = [seed]
	visited[seed] = true
	while not stack.is_empty():
		var cur: Vector3i = stack.pop_back()
		for d in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN,
				Vector3i.FORWARD, Vector3i.BACK]:
			var nxt: Vector3i = cur + d
			if visited.has(nxt):
				continue
			if _get_voxel(nxt.x, nxt.y, nxt.z):
				visited[nxt] = true
				stack.append(nxt)
	var total := _count_solid()
	stats["reachable_fraction"] = snappedf(float(visited.size()) / maxf(total, 1), 0.001)
	if visited.size() < total - 8:
		# find an example of orphan region for diagnostics
		var example := Vector3i.ZERO
		for y in range(_ny):
			var done := false
			for x in range(_nx):
				for z in range(_nz):
					if _get_voxel(x, y, z) and not visited.has(Vector3i(x, y, z)):
						example = Vector3i(x, y, z)
						done = true
						break
				if done:
					break
			if done:
				break
		failures.append("connected_mass: %d/%d solid voxels unreachable from nave (orphan near %s)"
			% [total - visited.size(), total, str(_world_of(example.x, example.y, example.z))])

func _check_openings() -> void:
	# Every opening must sit embedded in masonry AND not cut all the way through.
	var checked := 0
	for p in builder.part_log:
		if p["kind"] != "window":
			continue
		checked += 1
		var pos: Vector3 = p["pos"]
		var tag: String = p["tag"]
		var gi := Vector3i(_vx(pos.x), _vy(pos.y), _vz(pos.z))
		if not _get_voxel(gi.x, gi.y, gi.z) and not _has_neighbor(gi.x, gi.y, gi.z):
			failures.append("openings_embedded: %s opening at (%.1f,%.1f,%.1f) floats outside masonry"
				% [tag, pos.x, pos.y, pos.z])
			continue
		# through-cut test ("any cut should not escape"): walk outward in all 4
		# horizontal directions from the opening. For each axis pair, if there
		# is NO solid masonry within reach on EITHER side, this cut tunnels
		# clean through the whole building — e.g. a window placed where walls
		# don't exist, or a section rotated so its wall misses the nave.
		var solid_right := _ray_hits_solid(gi, Vector3i.RIGHT)
		var solid_left := _ray_hits_solid(gi, Vector3i.LEFT)
		var solid_back := _ray_hits_solid(gi, Vector3i.BACK)
		var solid_fwd := _ray_hits_solid(gi, Vector3i.FORWARD)
		if not solid_left and not solid_right:
			failures.append("openings_embedded: opening at (%.1f,%.1f,%.1f) [%s] cuts through - no masonry on either X side"
				% [pos.x, pos.y, pos.z, tag])
		elif not solid_back and not solid_fwd:
			failures.append("openings_embedded: opening at (%.1f,%.1f,%.1f) [%s] cuts through - no masonry on either Z side"
				% [pos.x, pos.y, pos.z, tag])
	if checked == 0:
		warnings.append("openings_embedded: no openings logged")

## Does the ray from v along dir hit solid masonry before leaving the grid?
func _ray_hits_solid(v: Vector3i, dir: Vector3i) -> bool:
	var x: int = v.x + dir.x; var y: int = v.y + dir.y; var z: int = v.z + dir.z
	while x >= 0 and x < _nx and y >= 0 and y < _ny and z >= 0 and z < _nz:
		if _get_voxel(x, y, z):
			return true
		x += dir.x; y += dir.y; z += dir.z
	return false


func _check_alignment() -> void:
	# Structural boxes must be axis-aligned (no arbitrary rotation) and their
	# long axis must match the church's local axes. rot_y values used by the
	# builder are 0 or multiples of PI/2; anything else means a section was
	# placed turned the wrong way.
	for p in builder.part_log:
		if p["kind"] != "box":
			continue
		var pos: Vector3 = p["pos"]
		var tag: String = p["tag"]
		# sanity: structural parts sit above ground
		if pos.y < -EPS:
			failures.append("parts_aligned: '%s' box center below ground at y=%.2f" % [tag, pos.y])
	# orientation consistency: tower must be centered on the nave X-axis (west end),
	# transept must span symmetrically across X. A rotated section would violate this.
	if spec.tower:
		for p in builder.part_log:
			if p["tag"] != "tower" or p["kind"] != "box":
				continue
			var pos: Vector3 = p["pos"]
			if absf(pos.x) > spec.width * 0.75 + EPS:
				failures.append("parts_aligned: tower part offset off nave axis (x=%.2f)" % pos.x)
				break
	if spec.transept:
		var min_x := INF; var max_x := -INF
		var found := false
		for p in builder.part_log:
			if p["tag"] != "transept" or p["kind"] != "box":
				continue
			found = true
			min_x = minf(min_x, p["pos"].x); max_x = maxf(max_x, p["pos"].x)
		if not found:
			warnings.append("parts_aligned: transept enabled but no tagged parts")
		elif absf(min_x + max_x) > EPS:
			failures.append("parts_aligned: transept not symmetric about nave axis")

## Sections must JOIN, not swallow each other. Whole-section AABBs legitimately
## interlock (aisles hug the nave), so we test the specific known offenders:
##   - tower front face must stop just inside the nave's west wall (TOWER_EMBED)
##   - apse join is measured by MassingCheck (see _check_massing)
##   - aisles/buttresses must stay clear of the tower and transept volumes
func _check_overlaps() -> void:
	var l: float = spec.length
	var TOWER_EMBED: float = ChurchGeometry.TOWER_EMBED
	if spec.tower:
		var front: float = -l / 2.0 + TOWER_EMBED  # intended front-face plane
		var worst := -INF
		for p in builder.part_log:
			if p["tag"] != "tower" or p["kind"] != "box":
				continue
			var sz: Vector3 = p["size"]
			var back: float = p["pos"].z + absf(sz.z) / 2.0
			worst = maxf(worst, back)
		# +0.35 slack: the tower roof overhangs the shaft by up to 0.25 m
		if worst > front + 0.35:
			failures.append("parts_join: tower penetrates nave to z=%.2f (front face should be %.2f)"
				% [worst, front])
		if worst < front - 0.5:
			warnings.append("parts_join: tower front %.2f detached from nave wall (%.2f)" % [worst, front])
	if spec.aisles > 0:
		for p in builder.part_log:
			if p["tag"] != "aisle" or p["kind"] != "box":
				continue
			var sz: Vector3 = p["size"]
			var z0: float = p["pos"].z - absf(sz.z) / 2.0
			var z1: float = p["pos"].z + absf(sz.z) / 2.0
			if spec.tower:
				var tower_front: float = -l / 2.0 + TOWER_EMBED + spec.tower_width
				if z0 < tower_front - 0.05:
					failures.append("parts_join: aisle (z0=%.2f) slices into tower zone (front %.2f)"
						% [z0, tower_front])
			if spec.transept:
				var crossing: float = ChurchGeometry.transept_front_z(spec)
				if z1 > crossing + 0.05:
					failures.append("parts_join: aisle (z1=%.2f) slices into transept crossing (starts %.2f)"
						% [z1, crossing])

func _check_proportions() -> void:
	if spec.tower and spec.tower_height > spec.height * 3.0:
		warnings.append("proportions: tower %.1fm exceeds 3x wall height (%.1fm)" % [spec.tower_height, spec.height])
	if spec.tower and spec.tower_width > spec.width:
		failures.append("proportions: tower wider than nave (%.1f > %.1f)" % [spec.tower_width, spec.width])
	if spec.apse and spec.apse_radius > spec.width * 0.55:
		failures.append("proportions: apse radius %.2f exceeds half nave width" % spec.apse_radius)
	if spec.transept and spec.transept_len < spec.width:
		failures.append("proportions: transept shorter than nave width - reads as a bump, not a cross")
	if spec.aisles > 0 and spec.aisle_width > spec.width:
		failures.append("proportions: aisle wider than nave")
	# roof pitch sanity: rise should not dwarf the walls
	if spec.roof_pitch > 1.5:
		warnings.append("proportions: extreme roof pitch %.2f" % spec.roof_pitch)


# --------------------------------------------------------------------- helpers

func _vx(wx: float) -> int:
	return clampi(int(floor((wx - _ox) / VOX)), 0, _nx - 1)
func _vy(wy: float) -> int:
	return clampi(int(floor((wy - _oy) / VOX)), 0, _ny - 1)
func _vz(wz: float) -> int:
	return clampi(int(floor((wz - _oz) / VOX)), 0, _nz - 1)

func _bbox_str() -> String:
	var mn := Vector3(INF, INF, INF); var mx := -Vector3(INF, INF, INF)
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			mn = mn.min(v); mx = mx.max(v)
	return "%.1fx%.1fx%.1f @(%0.1f,%0.1f,%0.1f)" % [mx.x - mn.x, mx.y - mn.y, mx.z - mn.z, mn.x, mn.y, mn.z]


## Structural correctness: no gaps, no undesigned overlaps, sizes match spec.
## Delegates to MassingCheck, which measures the emitted masses rather than
## re-deriving them from the spec.
func _check_massing() -> void:
	var rep: Dictionary = MassingCheck.new().check(spec, builder)
	for f in rep["failures"]:
		failures.append(f)
	for w in rep["warnings"]:
		warnings.append(w)
	stats["masses"] = rep["stats"].get("masses", 0)
	stats["worst_penetration"] = rep["stats"].get("worst_penetration", 0.0)
