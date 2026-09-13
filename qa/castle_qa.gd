class_name CastleQA
extends RefCounted
## Voxel-level quality harness for castles: the checks that measure the MESH
## rather than the mass log, so a builder that logs a wall it never emitted is
## caught rather than believed.
##
## Checks:
##   1. no_nan             all vertices finite and inside sane bounds
##   2. grounded           nothing hangs below y = 0
##   3. connected_mass     flood fill: every solid voxel reachable from the
##                         anchor mass -- or from a building standing on its
##                         own in the bailey -- so nothing floats detached
##   4. openings_embedded  painted slits have masonry behind them; planned
##                         window apertures have jambs, a head and a sill
##   5. enceinte_closed    the wall line is continuous the whole way round,
##                         except where the gate is meant to be
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const EPS := 0.05
## How far off the wall centre-line a perimeter sample may find its masonry.
const WALL_PROBE := 1

## The rules, in order; a family may replace one through
## `check(spec, mesh, builder, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"no_nan", &"grounded", &"connected_mass",
	&"openings_embedded", &"enceinte_closed", &"interiors", &"lords_walk"]
const METHODS := {&"no_nan": "_check_vertices", &"grounded": "_check_ground",
	&"openings_embedded": "_check_openings", &"enceinte_closed": "_check_enceinte"}

var spec: CastleSpec
var mesh: ArrayMesh
var builder: CastleBuilder
var failures: Array = []
var warnings: Array = []
var stats: Dictionary = {}
var replaced: Dictionary = {}
var buildings: Dictionary = {}

var _grid: VoxelGrid


func check(p_spec: CastleSpec, p_mesh: ArrayMesh, p_builder: CastleBuilder,
		overrides: Dictionary = {}) -> Dictionary:
	spec = p_spec
	mesh = p_mesh
	builder = p_builder
	failures.clear()
	warnings.clear()
	stats.clear()
	buildings.clear()

	_grid = VoxelGrid.new()
	_grid.rasterize(mesh, CastleBuilder.SURF_OPEN, _voxel_size())
	replaced = RuleSet.run(self, RULES, METHODS, overrides, [],
		[spec, mesh, builder], failures, warnings)

	stats["parts"] = builder.part_log.size()
	stats["voxels_solid"] = _grid.count_solid()
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced, "buildings": buildings}


func _check_interiors() -> void:
	for error in builder.interior_errors:
		failures.append("interiors: " + error)
	for row in builder.interiors:
		# The castle owns the joined roofs; the local HouseBuilder emits only
		# the occupied shell. Passing it would falsely demand a house roof.
		var report := HouseQA.new().check(row.plan, null)
		buildings[row.id] = report
		for failure in report.failures:
			failures.append("interiors[%s]: %s" % [row.id, failure])
		for warning in report.warnings:
			warnings.append("interiors[%s]: %s" % [row.id, warning])
	stats["interior_buildings"] = buildings.size()


func _check_lords_walk() -> void:
	var report := lords_walk(spec, builder, mesh)
	stats["lords_walk"] = report
	for failure in report.failures:
		failures.append("lords_walk: " + failure)


## Start outside the outer gate (and barbican), traverse every ring and its
## causeway, then chain the keep's storeys through HouseNavCheck. Structural
## triangles at body height block the exterior grid: a painted doorway on a
## solid gatehouse cannot pass this check. There is no second pathfinder here.
static func lords_walk(s: CastleSpec, b: CastleBuilder, emitted: ArrayMesh = null) -> Dictionary:
	var out := {"failures": [], "applicable": false}
	var keep := {}
	for row in b.interiors:
		if row.id == "keep":
			keep = row
	if keep.is_empty() or not CastleGeometry.is_enclosed(s):
		return out
	out.applicable = true
	var p: HousePlan = keep.plan
	var entrance := p.entrance()
	if entrance < 0:
		out.failures.append("keep has no entrance")
		return out
	var d: Dictionary = p.doors[entrance]
	if not bool(d.get("exterior", false)) or HousePlan.record_storey(d) != 0:
		out.failures.append("keep entrance is not a ground exterior door")
		return out
	var xf: Transform3D = keep.transform
	# HousePlan records exterior doors on the inner wall face.
	var local := Vector2(d.pos) + Vector2(d.normal) * (HouseGeometry.wall_thickness(p.spec) + HouseGeometry.PERSON_RADIUS + 0.2)
	var point := xf * Vector3(local.x, 0, local.y)
	var gate := CastleGeometry.gatehouse_aabb(s, 0)
	if gate.size.x <= 0.0:
		out.failures.append("enclosed keep has no outer gate passage")
		return out
	var outer := CastleGeometry.enceinte_polygon(s, 0)
	var barbican := CastleGeometry.barbican_aabb(s)
	var front := minf(gate.position.z, barbican.position.z) if barbican.size.x > 0 else gate.position.z
	var approach := Rect2(-gate.size.x * 0.5, front - 2.0, gate.size.x, gate.position.z - front + 2.5)
	var bounds := CastleGeometry.polygon_bbox(outer).merge(approach).grow(1.0)
	var actual := emitted if emitted != null else b.commit()
	var start := Vector2(0, front - 1.0)
	var goal := Vector2(point.x, point.z)
	var inside_local := Vector2(d.pos) - Vector2(d.normal) * (HouseGeometry.wall_thickness(p.spec) * 0.5 + HouseGeometry.PERSON_RADIUS + 0.2)
	var inside_world := xf * Vector3(inside_local.x, 0, inside_local.y)
	var inside_point := Vector2(inside_world.x, inside_world.z)
	out["start"] = start
	out["keep_approach"] = goal
	out["door_inside"] = inside_point
	out["rings"] = CastleGeometry.rings(s).size()
	# Most castles deliberately keep a clear gate axis. A route found in this
	# subset also exists in the full site; a blocked subset proves nothing,
	# so failures always fall back to the entire bailey. Snap to the full
	# grid's cell origin so both passes rasterize the exact same world cells.
	var corridor := _walk_corridor(bounds, start, goal, inside_point)
	var scope := "full" if corridor.is_equal_approx(bounds) else "corridor"
	var trial := _walk_trial(corridor, outer, approach, actual, b.prop_log, start, goal, inside_point)
	var grid: WalkGrid = trial.grid
	trial.erase("grid")
	trial["scope"] = scope
	var trials: Array[Dictionary] = [trial]
	if not trial.ok and scope != "full":
		trial = _walk_trial(bounds, outer, approach, actual, b.prop_log, start, goal, inside_point)
		grid = trial.grid
		trial.erase("grid")
		trial["scope"] = "full"
		trials.append(trial)
	out["exterior_trials"] = trials
	out["exterior_grid"] = trial.scope
	out["exterior_ok"] = trial.ok
	out["obstacle_triangles"] = trial.obstacle_triangles
	out["obstacle_props"] = trial.obstacle_props
	if not trial.approach_reached:
		out.failures.append("gate approach %s cannot reach keep door approach %s" % [start, point])
		if grid.nx * grid.nz < 160000:
			out["exterior_map"] = grid.ascii_map({start: "G", goal: "K"})
	# An approach outside the wall is insufficient: the emitted doorway must
	# also let a body reach the same inside point used by HouseNavCheck.
	if not trial.threshold_reached:
		out.failures.append("emitted keep entrance is blocked at %s" % inside_world)
	var nav := HouseNavCheck.new()
	var inside := nav.check(p)
	var lords := p.rooms_of(&"lords_chamber")
	if lords.is_empty():
		out.failures.append("keep has no lord's chamber")
	for room in lords:
		if room in nav.unreached_rooms or not inside.ok:
			out.failures.append("keep entrance cannot reach/use lord's chamber %d: %s" % [room, inside.failures])
	return out


static func _walk_corridor(full: Rect2, start: Vector2, goal: Vector2, inside: Vector2) -> Rect2:
	var wanted := Rect2(start, Vector2.ZERO).expand(goal).expand(inside).grow(2.0).intersection(full)
	var cell := HouseGeometry.NAV_CELL
	var first := ((wanted.position - full.position) / cell).floor()
	var last := ((wanted.end - full.position) / cell).ceil()
	return Rect2(full.position + first * cell, (last - first) * cell).intersection(full)


static func _walk_trial(bounds: Rect2, outer: PackedVector2Array, approach: Rect2,
		mesh: ArrayMesh, props: Array[Dictionary], start: Vector2, goal: Vector2, inside: Vector2) -> Dictionary:
	var grid := WalkGrid.new()
	grid.setup(bounds, HouseGeometry.NAV_CELL)
	grid.add_floor_poly(outer)
	grid.add_floor(approach)
	var triangles := _walk_obstacles(grid, mesh)
	var prop_count := _walk_props(grid, props)
	grid.build(HouseGeometry.PERSON_RADIUS)
	# Limit the shared walker's start search to one cell, so it cannot hop
	# across a thin blocker at the gate approach.
	var started := grid.flood_from(start, grid.cell)
	var goal_probe := Rect2(goal - Vector2.ONE * grid.cell, Vector2.ONE * grid.cell * 2.0)
	var approach_reached := started and grid.reached(goal_probe)
	var threshold_reached := true
	var samples: Array[Dictionary] = []
	var steps := maxi(int(ceil(goal.distance_to(inside) / grid.cell)), 1)
	for step in range(steps + 1):
		var point := goal.lerp(inside, float(step) / float(steps))
		var probe := Rect2(point - Vector2.ONE * grid.cell * 0.5, Vector2.ONE * grid.cell)
		var reached := started and grid.reached(probe)
		samples.append({"point": point, "probe": probe, "reached": reached})
		threshold_reached = threshold_reached and reached
	return {"grid": grid, "bounds": bounds, "cell": grid.cell,
		"grid_cells": grid.nx * grid.nz, "start": start, "start_cell": grid.cell_of(start),
		"start_search": grid.cell, "started": started, "approach_probe": goal_probe,
		"approach_reached": approach_reached, "threshold_samples": samples,
		"threshold_reached": threshold_reached, "reached_cells": grid.reached_cells(),
		"obstacle_triangles": triangles, "obstacle_props": prop_count,
		"ok": approach_reached and threshold_reached}


## Project the actual solid surfaces onto the walk grid over standing body
## height. Clip before projecting: a roof well overhead must not become a
## ground obstacle. Low thresholds below WalkGrid.MAX_STEP remain walkable.
static func _walk_obstacles(grid: WalkGrid, actual: ArrayMesh) -> int:
	var count := 0
	for surface in actual.get_surface_count():
		if surface == CastleBuilder.SURF_OPEN:
			continue
		var arrays := actual.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var size := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, size - 2, 3):
			var tri := PackedVector3Array()
			for j in 3:
				tri.append(vertices[indices[i + j] if not indices.is_empty() else i + j])
			tri = _clip_walk_height(tri, WalkGrid.MAX_STEP + 0.01, true)
			tri = _clip_walk_height(tri, 1.8, false)
			if tri.size() < 3:
				continue
			var points := PackedVector2Array()
			# A vertical triangle projects to a line. Give it one cell's raster
			# coverage so a zero-thickness sealed face still blocks a person.
			var pad := grid.cell * 0.5
			for vertex in tri:
				for dx in [-pad, pad]:
					for dz in [-pad, pad]:
						points.append(Vector2(vertex.x + dx, vertex.z + dz))
			var hull := Geometry2D.convex_hull(points)
			# Geometry2D closes its hull by repeating the first vertex. Normalize
			# that convention before handing it to the shared polygon routines,
			# so every boundary edge has a real geometric length.
			if hull.size() > 1 and hull[0].distance_squared_to(hull[hull.size() - 1]) < 1e-10:
				hull.resize(hull.size() - 1)
			grid.add_obstacle_poly(hull)
			count += 1
	return count


## The assembler loads these separately from the shell, so they have no
## triangles in `mesh`. Recompute measured footprints from the actual pose;
## a stale authored rect must not hide a cart moved across the entrance.
static func _walk_props(grid: WalkGrid, placements: Array[Dictionary]) -> int:
	var count := 0
	for prop in placements:
		var key := String(prop.key)
		if not PropCatalog.blocks_floor(key):
			continue
		var scale := float(prop.scale)
		var size := PropCatalog.size(key) * scale
		var centre := Vector3(prop.pos) + PropCatalog.centre_offset(key) * scale
		if centre.y + size.y * 0.5 <= WalkGrid.MAX_STEP or centre.y - size.y * 0.5 >= 1.8:
			continue
		var span := PropCatalog.footprint_rotated(key, float(prop.yaw)) * scale
		var plan_centre := PropCatalog.plan_centre(key, Vector3(prop.pos), float(prop.yaw), scale)
		grid.add_obstacle(Rect2(plan_centre - span * 0.5, span))
		count += 1
	return count


static func _clip_walk_height(poly: PackedVector3Array, height: float, above: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	if poly.is_empty():
		return out
	var prev := poly[poly.size() - 1]
	var prev_inside := prev.y >= height if above else prev.y <= height
	for cur in poly:
		var cur_inside := cur.y >= height if above else cur.y <= height
		if cur_inside != prev_inside:
			out.append(prev.lerp(cur, (height - prev.y) / (cur.y - prev.y)))
		if cur_inside:
			out.append(cur)
		prev = cur
		prev_inside = cur_inside
	return out


## Voxel size for this design: coarse enough that a 300 m fortress rasterizes
## into about the same number of cells as a cottage, fine enough to still fall
## inside the thinnest wall the design has.
func _voxel_size() -> float:
	var span: float = maxf(spec.width, spec.length)
	var thinnest: float = spec.wall_thickness if CastleGeometry.is_enclosed(spec) 		else CastleGeometry.CHIMNEY_W
	return clampf(span / 90.0, VoxelGrid.VOX, maxf(thinnest * 0.8, VoxelGrid.VOX))


func _check_vertices() -> void:
	var total := 0
	var limit: float = maxf(spec.width, spec.length) * 3.0 + 200.0
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		total += verts.size()
		for v in verts:
			if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)):
				failures.append("no_nan: NaN/Inf vertex on surface %d" % s)
				return
			if absf(v.x) > limit or absf(v.z) > limit or v.y > limit:
				warnings.append("no_nan: vertex far outside expected bounds (%s)" % v)
				return
	if total < 100:
		failures.append("no_nan: only %d vertices" % total)


func _check_ground() -> void:
	var mn := INF
	for s in range(mesh.get_surface_count()):
		for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			mn = minf(mn, v.y)
	if mn < -0.5:
		failures.append("grounded: geometry dips %.2fm below ground" % (-mn))
	elif mn < -EPS:
		warnings.append("grounded: eaves/trim dips %.2fm below ground" % (-mn))


## Flood fill from inside the anchor mass. Any solid voxel it cannot reach is a
## detached part -- a tower standing off its wall, a range in mid-air.
func _check_connected_mass() -> void:
	var anchor: AABB = builder.mass_aabb(_anchor_name())
	if anchor.size.y <= 0.0:
		failures.append("connected_mass: no %s mass to seed from" % _anchor_name())
		return
	var seed := _seed_inside(anchor)
	if seed.x < 0:
		failures.append("connected_mass: no solid voxel found inside the %s"
			% _anchor_name())
		return
	var visited: Dictionary = _grid.flood_from(seed)
	# A building standing on its own in the courtyard is its OWN grounded
	# component. A stable is not attached to the curtain and is not meant to
	# be (CAS-012), so the flood is seeded from each of those as well. The rule
	# keeps its teeth either way: geometry attached to nothing at all is still
	# unreachable from every seed, and `grounded` is what says a free-standing
	# building has to stand on the ground.
	var independent := {}
	for row in builder.interiors:
		independent[row.id] = true
	for m in builder.mass_log:
		var nm: String = m["name"]
		if not (nm.begins_with("yard_") or nm == "well" or independent.has(nm)):
			continue
		var box: AABB = m["aabb"]
		# An independently seeded house must have real masonry at its foot.
		# Looking in the middle of a hollow shell misses its walls, while
		# accepting a roof high above its logged base would bless a floater.
		var foot := AABB(box.position, Vector3(box.size.x, minf(box.size.y, _grid.vox * 1.5), box.size.z))
		var extra: Vector3i = _seed_inside(foot)
		if extra.x < 0:
			continue
		# Ranges usually already touch the curtain's component. Re-flooding
		# that same component for each range adds no newly reachable voxels.
		if visited.has(extra):
			continue
		for k in _grid.flood_from(extra):
			visited[k] = true
	var total: int = _grid.count_solid()
	stats["reachable_fraction"] = snappedf(float(visited.size()) / maxf(total, 1), 0.001)
	if visited.size() < total - 8:
		var example: Vector3i = _grid.first_unvisited(visited)
		failures.append("connected_mass: %d/%d solid voxels unreachable from the %s (orphan near %s)"
			% [total - visited.size(), total, _anchor_name(),
				str(_grid.world_of(example.x, example.y, example.z))])


## A solid voxel somewhere inside `box`, or (-1, -1, -1) when it holds none.
func _seed_inside(box: AABB) -> Vector3i:
	# Visit raster cells, including the shell boundary. A fixed handful of
	# points through a now-hollow volume may all fall in perfectly legal air.
	for y in range(_grid.vy(box.position.y), _grid.vy(box.end.y) + 1):
		for x in range(_grid.vx(box.position.x), _grid.vx(box.end.x) + 1):
			for z in range(_grid.vz(box.position.z), _grid.vz(box.end.z) + 1):
				if _grid.get_voxel(x, y, z):
					return Vector3i(x, y, z)
	return Vector3i(-1, -1, -1)


## Legacy slits are recesses over solid masonry. HousePlan windows are real
## apertures: measure their surrounding masonry instead of demanding stone
## through the glass. The fine shell tests separately measure aperture clearance.
func _check_openings() -> void:
	var checked := 0
	for p in builder.part_log:
		if p["kind"] != "window":
			continue
		checked += 1
		var pos: Vector3 = p["pos"]
		var tag: String = p["tag"]
		if bool(p.get("planned_opening", false)):
			_check_aperture_surround(p)
			continue
		var cell := (pos - _grid.origin) / _grid.vox
		var gi := Vector3i(floori(cell.x), floori(cell.y), floori(cell.z))
		if not _grid.get_voxel(gi.x, gi.y, gi.z) and not _grid.has_neighbor(gi.x, gi.y, gi.z):
			failures.append("openings_embedded: %s opening at (%.1f,%.1f,%.1f) floats outside masonry"
				% [tag, pos.x, pos.y, pos.z])
			continue
		var solid_x: bool = _grid.ray_hits_solid(gi, Vector3i.RIGHT) \
			or _grid.ray_hits_solid(gi, Vector3i.LEFT)
		var solid_z: bool = _grid.ray_hits_solid(gi, Vector3i.BACK) \
			or _grid.ray_hits_solid(gi, Vector3i.FORWARD)
		if not solid_x:
			failures.append("openings_embedded: opening at (%.1f,%.1f,%.1f) [%s] cuts through - no masonry on either X side"
				% [pos.x, pos.y, pos.z, tag])
		elif not solid_z:
			failures.append("openings_embedded: opening at (%.1f,%.1f,%.1f) [%s] cuts through - no masonry on either Z side"
				% [pos.x, pos.y, pos.z, tag])
	if checked == 0:
		warnings.append("openings_embedded: no openings logged")
	stats["openings_checked"] = checked


func _check_aperture_surround(part: Dictionary) -> void:
	var pos: Vector3 = part.pos
	var size: Vector3 = part.size
	var normal: Vector3 = part.facing
	if size.x <= 0.0 or size.y <= 0.0 or normal.length_squared() < 0.9 or absf(normal.y) > 0.01:
		failures.append("openings_embedded: %s has invalid planned aperture dimensions/facing" % part.tag)
		return
	var tangent := Vector3(normal.z, 0.0, -normal.x).normalized()
	# Trim is 0.09m wide. Probe its centre at the logged wall centreline,
	# where masonry must be present even when both rooms beyond are empty.
	var samples := {
		"left jamb": pos - tangent * (size.x * 0.5 + 0.045),
		"right jamb": pos + tangent * (size.x * 0.5 + 0.045),
		"head": pos + Vector3.UP * (size.y * 0.5 + 0.045),
		"sill": pos - Vector3.UP * (size.y * 0.5 + 0.045),
	}
	for side in samples:
		# Do not use VoxelGrid.vx/vy/vz here: their boundary clamping would
		# let a log moved outside the entire mesh borrow its boundary voxel.
		var cell: Vector3 = (Vector3(samples[side]) - _grid.origin) / _grid.vox
		if not _grid.get_voxel(floori(cell.x), floori(cell.y), floori(cell.z)):
			failures.append("openings_embedded: %s planned window at %s has no masonry at its %s"
				% [part.tag, pos, side])


## The rule a fortification lives or dies by: walk the wall centre-line the
## whole way round each ring and require masonry under every step of it, except
## across the gate. A curtain with a hole in it is not a curtain, and neither
## the mass log nor a bounding box would ever say so -- both are perfectly happy
## with a wall run that was logged but never emitted.
func _check_enceinte() -> void:
	if not CastleGeometry.is_enclosed(spec):
		return
	for r in CastleGeometry.rings(spec):
		var rect: Rect2 = CastleGeometry.enceinte_rect(spec, r)
		var t: float = CastleGeometry.wall_thickness(spec, r)
		var y: float = CastleGeometry.wall_height(spec, r) * 0.5
		var gw: float = CastleGeometry.gate_width(spec, r)
		var breaks := 0
		var samples := 0
		var step: float = _grid.vox
		# the centre-line of the enceinte, inset half a wall thickness from the
		# outer face. On the rectangular plan that is the site rectangle; on a
		# polygonal one it is the polygon, walked edge by edge.
		var runs := []
		var line: PackedVector2Array = CastleGeometry.offset_polygon(
			CastleGeometry.enceinte_polygon(spec, r), t / 2.0)
		var gate_edge: int = 0
		if not CastleGeometry.is_polygonal(spec):
			var x0: float = rect.position.x + t / 2.0
			var x1: float = rect.end.x - t / 2.0
			var z0: float = rect.position.y + t / 2.0
			var z1: float = rect.end.y - t / 2.0
			line = PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0),
				Vector2(x1, z1), Vector2(x0, z1)])
		for e in range(line.size()):
			var a2: Vector2 = line[e]
			var b2: Vector2 = line[(e + 1) % line.size()]
			runs.append({"from": Vector3(a2.x, y, a2.y),
				"to": Vector3(b2.x, y, b2.y), "gate": e == gate_edge})
		for run in runs:
			var a: Vector3 = run["from"]
			var b: Vector3 = run["to"]
			var n: int = maxi(int(a.distance_to(b) / step), 1)
			for i in range(n + 1):
				var p: Vector3 = a.lerp(b, float(i) / n)
				# the gate is a hole in the wall by design, not a break in it
				if run["gate"] and absf(p.x) <= gw / 2.0 + step:
					continue
				samples += 1
				if not _solid_near(p):
					breaks += 1
		stats["ring_%d_samples" % r] = samples
		if breaks > 0:
			failures.append("enceinte_closed: ring %d has %d/%d points of open air on its wall line"
				% [r, breaks, samples])


## Masonry at p, or within a voxel of it -- the wall line is a nominal centre,
## and a battered wall leans away from it as it rises.
func _solid_near(p: Vector3) -> bool:
	var g := Vector3i(_grid.vx(p.x), _grid.vy(p.y), _grid.vz(p.z))
	for dx in range(-WALL_PROBE, WALL_PROBE + 1):
		for dz in range(-WALL_PROBE, WALL_PROBE + 1):
			if _grid.get_voxel(g.x + dx, g.y, g.z + dz):
				return true
	return false


## The mass the assembly is measured from: the curtain of a walled tier, the
## hall of an unwalled one.
func _anchor_name() -> String:
	return "wall_0_back" if CastleGeometry.is_enclosed(spec) else "hall"
