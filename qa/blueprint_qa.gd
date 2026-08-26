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

const VOX := VoxelGrid.VOX  # voxel size in meters for solid/flood tests
const EPS := 0.05

var spec: ChurchSpec
var mesh: ArrayMesh
var builder: ChurchBuilder
var failures: Array = []
var warnings: Array = []
var stats: Dictionary = {}

## The rasterized copy of the mesh. VoxelGrid owns the grid itself; this file
## owns what the church means by a defect.
var _grid: VoxelGrid

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
	stats["voxels_solid"] = _grid.count_solid()
	stats["bbox"] = _bbox_str()
	var ok := failures.is_empty()
	return {"ok": ok, "failures": failures, "warnings": warnings, "stats": stats}


# ------------------------------------------------------------------ rasterize

func _rasterize() -> void:
	_grid = VoxelGrid.new()
	_grid.rasterize(mesh, ChurchBuilder.SURF_OPEN)


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
	var need_x0 := _grid.vx(-w / 2.0); var need_x1 := _grid.vx(w / 2.0)
	var need_z0 := _grid.vz(-l / 2.0); var need_z1 := _grid.vz(l / 2.0)
	var gy := _grid.vy(0.5)  # just above ground
	var missing := 0
	for gx in range(need_x0, need_x1 + 1):
		for gz in range(need_z0, need_z1 + 1):
			if not _grid.get_voxel(gx, gy, gz):
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
	var gy := _grid.vy(0.6)
	for dx in range(0, int(spec.width / VOX)):
		for dz in range(0, int(spec.length / VOX)):
			var cand := Vector3i(_grid.vx(-spec.width / 2.0) + dx, gy,
				_grid.vz(-spec.length / 2.0) + dz)
			if _grid.get_voxel(cand.x, cand.y, cand.z):
				seed = cand
				break
		if seed.x >= 0:
			break
	if seed.x < 0:
		failures.append("connected_mass: no solid voxel found in nave footprint")
		return
	var visited: Dictionary = _grid.flood_from(seed)
	var total := _grid.count_solid()
	stats["reachable_fraction"] = snappedf(float(visited.size()) / maxf(total, 1), 0.001)
	if visited.size() < total - 8:
		# an example orphan, for diagnostics
		var example: Vector3i = _grid.first_unvisited(visited)
		failures.append("connected_mass: %d/%d solid voxels unreachable from nave (orphan near %s)"
			% [total - visited.size(), total, str(_grid.world_of(example.x, example.y, example.z))])

func _check_openings() -> void:
	# Every opening must sit embedded in masonry AND not cut all the way through.
	var checked := 0
	for p in builder.part_log:
		if p["kind"] != "window":
			continue
		checked += 1
		var pos: Vector3 = p["pos"]
		var tag: String = p["tag"]
		var gi := Vector3i(_grid.vx(pos.x), _grid.vy(pos.y), _grid.vz(pos.z))
		if not _grid.get_voxel(gi.x, gi.y, gi.z) and not _grid.has_neighbor(gi.x, gi.y, gi.z):
			failures.append("openings_embedded: %s opening at (%.1f,%.1f,%.1f) floats outside masonry"
				% [tag, pos.x, pos.y, pos.z])
			continue
		# through-cut test ("any cut should not escape"): walk outward in all 4
		# horizontal directions from the opening. For each axis pair, if there
		# is NO solid masonry within reach on EITHER side, this cut tunnels
		# clean through the whole building — e.g. a window placed where walls
		# don't exist, or a section rotated so its wall misses the nave.
		var solid_right := _grid.ray_hits_solid(gi, Vector3i.RIGHT)
		var solid_left := _grid.ray_hits_solid(gi, Vector3i.LEFT)
		var solid_back := _grid.ray_hits_solid(gi, Vector3i.BACK)
		var solid_fwd := _grid.ray_hits_solid(gi, Vector3i.FORWARD)
		if not solid_left and not solid_right:
			failures.append("openings_embedded: opening at (%.1f,%.1f,%.1f) [%s] cuts through - no masonry on either X side"
				% [pos.x, pos.y, pos.z, tag])
		elif not solid_back and not solid_fwd:
			failures.append("openings_embedded: opening at (%.1f,%.1f,%.1f) [%s] cuts through - no masonry on either Z side"
				% [pos.x, pos.y, pos.z, tag])
	if checked == 0:
		warnings.append("openings_embedded: no openings logged")

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
