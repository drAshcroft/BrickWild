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
##   4. openings_embedded  every slit and window sits in masonry and does not
##                         tunnel clean through the building
##   5. enceinte_closed    the wall line is continuous the whole way round,
##                         except where the gate is meant to be
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const EPS := 0.05
## How far off the wall centre-line a perimeter sample may find its masonry.
const WALL_PROBE := 1

## The five rules, in order; a family may replace one through
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
		var report := HouseQA.new().check(row.plan, row.builder)
		buildings[row.id] = report
		for failure in report.failures:
			failures.append("interiors[%s]: %s" % [row.id, failure])
		for warning in report.warnings:
			warnings.append("interiors[%s]: %s" % [row.id, warning])
	stats["interior_buildings"] = buildings.size()


func _check_lords_walk() -> void:
	var report := lords_walk(spec, builder)
	stats["lords_walk"] = report
	for failure in report.failures:
		failures.append("lords_walk: " + failure)


## Shared WalkGrid handles the bailey, then HouseNavCheck chains the keep's
## storeys. Logged footprints are obstacles; decorative AABBs are not floors.
static func lords_walk(s: CastleSpec, b: CastleBuilder) -> Dictionary:
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
	var xf: Transform3D = keep.transform
	var local := Vector2(d.pos) + Vector2(d.normal) * (HouseGeometry.wall_thickness(p.spec) + HouseGeometry.PERSON_RADIUS + 0.15)
	var point := xf * Vector3(local.x, 0, local.y)
	var yard := CastleGeometry.bailey_rect(s)
	var grid := WalkGrid.new()
	grid.setup(yard.grow(2), maxf(0.12, minf(s.width, s.length) / 500.0))
	if CastleGeometry.is_polygonal(s):
		grid.add_floor_poly(CastleGeometry.inner_polygon(s, CastleGeometry.inner_ring(s)))
	else:
		grid.add_floor(yard)
	for mass in b.mass_log:
		var name: String = mass.name
		if name == "keep" or name in ["hall", "chapel", "apse", "well"] or name.begins_with("yard_"):
			var a: AABB = mass.aabb
			grid.add_obstacle(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
	var start := Vector2(yard.get_center().x, yard.position.y + HouseGeometry.PERSON_RADIUS + grid.cell * 2)
	grid.build(HouseGeometry.PERSON_RADIUS)
	if not grid.flood_from(start) or not grid.reached(Rect2(Vector2(point.x,point.z) - Vector2.ONE * 0.1, Vector2.ONE * 0.2)):
		out.failures.append("gate approach %s cannot reach keep door approach %s" % [start, point])
	var nav := HouseNavCheck.new()
	var inside := nav.check(p)
	var lords := p.rooms_of(&"lords_chamber")
	if lords.is_empty():
		out.failures.append("keep has no lord's chamber")
	for room in lords:
		if room in nav.unreached_rooms or not inside.ok:
			out.failures.append("keep entrance cannot reach/use lord's chamber %d: %s" % [room, inside.failures])
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
	var seed := Vector3i(-1, -1, -1)
	var c: Vector3 = anchor.position + anchor.size / 2.0
	for step in range(12):
		var p: Vector3 = Vector3(c.x, anchor.position.y + anchor.size.y * 0.5,
			lerpf(anchor.position.z, anchor.position.z + anchor.size.z,
				(float(step) + 0.5) / 12.0))
		var g := Vector3i(_grid.vx(p.x), _grid.vy(p.y), _grid.vz(p.z))
		if _grid.get_voxel(g.x, g.y, g.z):
			seed = g
			break
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
	for m in builder.mass_log:
		var nm: String = m["name"]
		if not (nm.begins_with("yard_") or nm == "well"):
			continue
		var extra: Vector3i = _seed_inside(m["aabb"])
		if extra.x < 0:
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
	for iy in range(4):
		var y: float = box.position.y + box.size.y * (float(iy) + 0.5) / 4.0
		for ix in range(5):
			var x: float = box.position.x + box.size.x * (float(ix) + 0.5) / 5.0
			for iz in range(5):
				var z: float = box.position.z + box.size.z * (float(iz) + 0.5) / 5.0
				var g := Vector3i(_grid.vx(x), _grid.vy(y), _grid.vz(z))
				if _grid.get_voxel(g.x, g.y, g.z):
					return g
	return Vector3i(-1, -1, -1)


## Every opening must sit embedded in masonry AND not cut all the way through.
func _check_openings() -> void:
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
