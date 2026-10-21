class_name VillageWalk3D
extends RefCounted
## The village's walk on given ground, in three dimensions (VTER-STEPS-NAV;
## docs/VILLAGE_TERRAIN.md "Steps and the 3D walk"). VillageWalk's flat mesh
## says where a person may stand; on a hillside that is not enough, because a
## pad a metre and a half over its road is floor in plan and a wall in fact.
##
## So the floor is baked again, by Godot's own NavigationServer3D baker
## (Recast), from what was BUILT: the emitted ground's upward triangles in
## every floor region (road, verge, lot, common, the stairs of `steps` roads
## and access flights), each house's entry flights (landing and treads, from
## HouseSlope via the lot's `entry_flights`) and every crossing's deck and
## ramps; obstructed by the same outlines the flat walk uses
## (`VillageNavCheck.sources`) and by the footprints of the terrace, retaining
## and cheek walls. A step over MAX_CLIMB is a wall to the baker; a stair's
## risers are under it, so a stair is walked, not linked.
##
## Recast's own heights are quantised to its cell height and sit a few
## centimetres high, so every baked vertex is set on the source surface
## nearest it: the polygon heights ARE the emitted ground at every vertex.
## Plain data out: {"vertices": PackedVector3Array, "polygons":
## Array[PackedInt32Array], "stats"}; vertices snapped to the millimetre,
## numbered in (x, z, y) order, polygons rotated to their lowest index and
## sorted, so the same plan writes the same bytes.

const CELL := 0.25
const CELL_HEIGHT := 0.02
const AGENT_HEIGHT := 1.8
## a person steps 0.24 m (12 of the 2 cm cells): every stair riser (0.15) and every earth
## seam under it; a pad's edge over it is a wall
const MAX_CLIMB := 0.24
const MAX_SLOPE_DEG := 46.0
## The baker's detail pass: a sample every 5 m, more where its own height
## raster is off by more than its cell height (a finer bound only chases the
## raster's 5 cm quantisation and quadruples the polygons). Every vertex is
## set on the emitted ground afterwards; the suite measures the polygons'
## insides against it.
const DETAIL_SAMPLE := 5.0
const DETAIL_ERROR := 0.04
## How far (in cells) the baker may simplify an outline: under the half-cell
## erosion's reach, so no outline leaves the floor it traced (the default
## 1.3 cells put vertices over the land beside a cutting).
const EDGE_ERROR := 0.5
## And how long an outline's edge may run: a 12 m edge along a road sags off
## its curved profile by a decimetre.
const EDGE_LENGTH := 4.0
const PLACES := 0.001
## Every vertex on a centimetre grid, in plan and in height. Godot's map joins
## polygons by rasterising their vertices (cell size x merge scale): a
## consumer that sets MERGE_SCALE (5 mm in plan, 1 mm in height on these
## cells) keeps every two vertices of this grid apart and every shared one
## together. Height to a centimetre is half a centimetre of error at most.
const GRID := 0.01
const MERGE_SCALE := 0.02
## An access flight (K_STAIR) is not baked: 0.36 m treads on 0.25 m cells
## come out as smears and islands, so like a house's entry flight it is a
## link along its pitch (entry_links), and its strip is no floor.
const FLOOR_KINDS := [VillageGroundSurface.K_WEAR, VillageGroundSurface.K_ROAD,
	VillageGroundSurface.K_VERGE, VillageGroundSurface.K_LOT, VillageGroundSurface.K_COMMON]
const WALL_ROLES := ["terrace_wall", "retaining_wall", "stair_cheek"]
## the source surfaces bucketed on this plan grid, for the height snap
const BUCKET := 2.5


## The agent the mesh is baked for (a person; the radius rounded up to the
## baker's cell, which it would do anyway).
static func agent_radius() -> float:
	return ceilf(VillageWalk.AGENT_RADIUS / CELL - 1e-6) * CELL


static func bake(plan: VillagePlan, opts: Dictionary = {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var surface := VillageGroundSurface.of(plan)
	surface.build_mesh()
	var faces := source_faces(plan)
	var src := NavigationMeshSourceGeometryData3D.new()
	src.add_faces(faces, Transform3D.IDENTITY)
	var lo := INF
	for v in faces:
		lo = minf(lo, v.y)
	var obstacles := obstacle_outlines(plan)
	for poly in obstacles:
		var v3 := PackedVector3Array()
		for p in poly:
			v3.append(Vector3(p.x, 0.0, p.y))
		src.add_projected_obstruction(v3, lo - 10.0, 2000.0, false)
	var nm := NavigationMesh.new()
	nm.cell_size = CELL
	nm.cell_height = CELL_HEIGHT
	nm.agent_radius = agent_radius()
	nm.agent_height = AGENT_HEIGHT
	nm.agent_max_climb = MAX_CLIMB
	nm.agent_max_slope = MAX_SLOPE_DEG
	nm.detail_sample_distance = float(opts.get("detail_sample", DETAIL_SAMPLE))
	nm.detail_sample_max_error = float(opts.get("detail_error", DETAIL_ERROR))
	nm.edge_max_error = EDGE_ERROR
	nm.edge_max_length = EDGE_LENGTH
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var index := _bucket(faces)
	var verts := nm.vertices
	var moved := 0.0
	var beside := 0
	var flights := _flight_rows(plan)
	var pitched := 0
	for i in verts.size():
		var h := stair_pitch(plan, surface, flights, verts[i])
		if not is_nan(h):
			pitched += 1
		else:
			h = _nearest(index, faces, verts[i])
			# a vertex the raster set a little past a pad's edge has only the
			# ground below the edge under it: the edge it belongs to is nearer
			if is_nan(h) or absf(h - verts[i].y) > SNAP_FAR:
				var edge := _beside_scored(index, faces, verts[i])
				# the edge's score counts its plan distance as well as height
				if not edge.is_empty() and (is_nan(h) or float(edge["score"]) < absf(h - verts[i].y)):
					h = float(edge["h"])
					beside += 1
			# within a cell of a stair, a vertex the raster gave the stair's
			# height belongs to its pitch (the foot of a flight on a verge)
			var near := _pitch_near(plan, surface, flights, verts[i])
			if not is_nan(near) and (is_nan(h) or absf(near - verts[i].y) < absf(h - verts[i].y)):
				h = near
				pitched += 1
		if is_nan(h):
			# Recast's contour may lie a centimetre or two outside the floor
			# it traced: the nearest floor's edge, at its height there
			h = _nearest_beside(index, faces, verts[i])
			beside += 1
		if not is_nan(h):
			moved = maxf(moved, absf(h - verts[i].y))
			verts[i].y = h
	var polygons: Array[PackedInt32Array] = []
	for i in nm.get_polygon_count():
		polygons.append(nm.get_polygon(i))
	var out := canonical(verts, polygons)
	var removed := remove_overlaps(out)
	var triangles: int = (out["polygons"] as Array).size()
	merge_coplanar(out, float(opts.get("merge_flat", MERGE_FLAT)))
	var inserted := refine_edges(out, index, faces)
	out = canonical(out["vertices"], out["polygons"])
	out["links"] = entry_links(plan, out)
	out["stats"] = {"faces": faces.size() / 3, "obstacles": obstacles.size(),
		"snap_worst_m": snappedf(moved, PLACES), "snapped_beside": beside, "pitched": pitched,
		"overlaps_removed": removed, "overfull_edges": overfull_edges(out), "triangles": triangles,
		"edge_vertices_added": inserted,
		"polygons": (out["polygons"] as Array).size(), "ms": (Time.get_ticks_usec() - t0) / 1000.0}
	return out


## A vertex whose nearest layer is this far from the baker's own height
## looks for an edge beside it.
const SNAP_FAR := 0.3
## GroundFall's tread, for a flight of one step.
const GROUND_FALL_GOING := 0.30


## A house's entry flight as a LINK, foot to landing. Baked, a flight 1 m
## wide, turned off the baker's grid, with 0.30 m goings on 0.25 m cells,
## loses a tread to the raster now and then (its upper half an island) and is
## smeared into slopes a riser or more off its treads; so only its landing is
## floor, its treads are an obstacle, and the link says what the house's own
## walk export says (`route_m`): from the foot on the ground, up the flight,
## to the landing.
##
## A link is a straight line, and a straight line over a stair is its PITCH:
## the line through the treads' middles, never more than half a riser off a
## tread. It meets the upper level half a going in from the top nosing, at
## that level's own height, and the lower ground where it has come down to
## it; those are the link's two ends.
## [{"kind": "entry" | "access", "building": int, "door": int, "from":
##   Vector3 (the lower end), "to": Vector3 (the upper)}].
static func entry_links(plan: VillagePlan, mesh: Dictionary) -> Array:
	var out: Array = []
	for bi in plan.buildings.size():
		var li: int = int(plan.buildings[bi].get("lot", -1))
		if li < 0 or li >= plan.lots.size():
			continue
		for f in plan.lots[li].get("ground_fit", {}).get("entry_flights", []):
			var link := entry_pitch(f["route"])
			if link.is_empty():
				continue
			link["kind"] = "entry"
			link["building"] = bi
			link["door"] = int(f["door"])
			out.append(link)
		# a lot's access flight: its treads are ground and baked too, but a
		# 1.2 m flight turned off the grid can come out in pieces
		var access: Dictionary = plan.lots[li].get("ground_fit", {}).get("access", {})
		if access.has("treads"):
			var link := access_pitch(access)
			if not link.is_empty():
				link["kind"] = "access"
				link["building"] = bi
				link["door"] = -1
				out.append(link)
	return out


## The pitch of a house's entry flight (route: threshold, landing, each
## tread's middle, foot): {"from", "to"}, or {} for a flight with no tread.
static func entry_pitch(route: Array) -> Dictionary:
	if route.size() < 4:
		return {}
	var landing: Vector3 = route[1]
	var first: Vector3 = route[2]
	var riser: float = landing.y - first.y
	if absf(riser) < 0.01:
		return {}
	var going: float = Vector2(route[2].x, route[2].z).distance_to(Vector2(route[3].x, route[3].z)) \
		if route.size() > 4 else GROUND_FALL_GOING
	var down := Vector2(first.x - landing.x, first.z - landing.z).normalized()
	# the top nosing, and s measured from it down the flight
	var nosing := Vector2(first.x, first.z) - down * (going * 0.5)
	var foot: Vector3 = route[route.size() - 1]
	# pitch(s) = landing.y - riser / 2 - riser * s / going
	var s_foot: float = (landing.y - riser * 0.5 - foot.y) * going / riser
	var top := nosing - down * (going * 0.5)
	var low := nosing + down * s_foot
	return {"from": Vector3(low.x, foot.y, low.y), "to": Vector3(top.x, landing.y, top.y)}


## The pitch of a lot's access flight, from the ground before its first
## riser to the middle of its top tread.
static func access_pitch(access: Dictionary) -> Dictionary:
	var treads: Array = access["treads"]
	var origin: Vector2 = access["origin"]
	var dir: Vector2 = access["dir"]
	var foot_h: float = (access["foot_m"] as Vector3).y
	# the rising treads: past a level landing at the foot
	var k0 := 0
	if absf(float(treads[0]["h"]) - foot_h) < 0.01 and treads.size() > 1:
		k0 = 1
	var going: float = float(access["going_m"])
	var first_nosing: float = float(treads[k0]["d"]) - float(treads[k0]["len"]) * 0.5
	var last: Dictionary = treads[treads.size() - 1]
	# the top tread may be long (a landing on a verge): its first going
	var last_mid: float = float(last["d"]) - float(last["len"]) * 0.5 + going * 0.5
	var a := origin + dir * (first_nosing - going * 0.5)
	var b := origin + dir * last_mid
	return {"from": Vector3(a.x, foot_h, a.y), "to": Vector3(b.x, float(last["h"]), b.y)}


## An edge whose middle sags (or humps) more than REFINE_TOL off the ground
## under it gets a vertex there, at the ground's height, in every polygon
## that has the edge -- so the mesh stays conforming, each polygon stays
## convex (the vertex is on a straight edge), the polygon count stays under
## Godot's search cap, and a path crossing the edge (or the polygon's fan
## from its first vertex) follows a road's curved profile. Three rounds;
## an edge under REFINE_MIN is left. Returns the vertices added.
const REFINE_TOL := 0.03
const REFINE_MIN := 0.5


static func refine_edges(mesh: Dictionary, index: Dictionary, faces: PackedVector3Array) -> int:
	var verts: PackedVector3Array = mesh["vertices"]
	var polys: Array = mesh["polygons"]
	var added := 0
	for _round in range(3):
		var edges := {}
		for i in polys.size():
			var poly: PackedInt32Array = polys[i]
			for k in poly.size():
				var a: int = poly[k]
				var b: int = poly[(k + 1) % poly.size()]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not edges.has(key):
					edges[key] = []
				(edges[key] as Array).append(i)
		var split := {}   # edge key -> new vertex index
		var keys := edges.keys()
		keys.sort()
		for key in keys:
			var a: Vector3 = verts[key.x]
			var b: Vector3 = verts[key.y]
			if Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) < REFINE_MIN:
				continue
			var mid := (a + b) * 0.5
			var g := _nearest(index, faces, mid)
			if is_nan(g) or absf(g - mid.y) <= REFINE_TOL or absf(g - mid.y) > SNAP_FAR:
				continue
			split[key] = verts.size()
			verts.append(Vector3(snappedf(mid.x, GRID), g, snappedf(mid.z, GRID)))
		if split.is_empty():
			break
		added += split.size()
		for i in polys.size():
			var poly: PackedInt32Array = polys[i]
			var out := PackedInt32Array()
			for k in poly.size():
				var a: int = poly[k]
				var b: int = poly[(k + 1) % poly.size()]
				out.append(a)
				var key := Vector2i(mini(a, b), maxi(a, b))
				if split.has(key):
					out.append(split[key])
			polys[i] = out
	mesh["vertices"] = verts
	return added


## Adjacent polygons merged while the union stays convex in plan and flat
## (every vertex within MERGE_FLAT of one plane): the baker's detail
## triangles are a hundred to a hectare, and Godot's path search gives up
## after 4096 polygons (NavigationPathQueryParameters3D
## .path_search_max_polygons) -- a long walk across a village on raw
## triangles stops halfway. Heights are untouched.
const MERGE_FLAT := 0.03
const MERGE_MAX_VERTS := 12


static func merge_coplanar(mesh: Dictionary, flat: float = MERGE_FLAT) -> void:
	var verts: PackedVector3Array = mesh["vertices"]
	var polys: Array = (mesh["polygons"] as Array).duplicate()
	for _pass in range(10):
		var edge_of := {}
		for i in polys.size():
			var poly: PackedInt32Array = polys[i]
			for k in poly.size():
				var a: int = poly[k]
				var b: int = poly[(k + 1) % poly.size()]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not edge_of.has(key):
					edge_of[key] = []
				(edge_of[key] as Array).append(i)
		var dead := {}
		var made: Array = []
		var keys := edge_of.keys()
		keys.sort()
		for key in keys:
			var list: Array = edge_of[key]
			if list.size() != 2 or dead.has(list[0]) or dead.has(list[1]):
				continue
			var merged := _merged(verts, polys[list[0]], polys[list[1]], key, flat)
			if merged.is_empty():
				continue
			dead[list[0]] = true
			dead[list[1]] = true
			made.append(merged)
		if made.is_empty():
			break
		var next: Array = []
		for i in polys.size():
			if not dead.has(i):
				next.append(polys[i])
		next.append_array(made)
		polys = next
	var typed: Array[PackedInt32Array] = []
	for p in polys:
		typed.append(p)
	mesh["polygons"] = typed


## A and B joined across their shared edge, or empty when the union is not
## convex in plan, not flat, or too big.
static func _merged(verts: PackedVector3Array, pa: PackedInt32Array, pb: PackedInt32Array, key: Vector2i, flat: float = MERGE_FLAT) -> PackedInt32Array:
	if pa.size() + pb.size() - 2 > MERGE_MAX_VERTS:
		return PackedInt32Array()
	var ia := -1
	for k in pa.size():
		var a: int = pa[k]
		var b: int = pa[(k + 1) % pa.size()]
		if Vector2i(mini(a, b), maxi(a, b)) == key:
			ia = k
	var ib := -1
	for k in pb.size():
		var a: int = pb[k]
		var b: int = pb[(k + 1) % pb.size()]
		if Vector2i(mini(a, b), maxi(a, b)) == key:
			ib = k
	if ia < 0 or ib < 0 or pa[ia] != pb[(ib + 1) % pb.size()]:
		return PackedInt32Array() # not wound the same way round
	# A from the edge's far end round to its near end, then B's other vertices
	var out := PackedInt32Array()
	for m in pa.size():
		out.append(pa[(ia + 1 + m) % pa.size()])
	for m in range(2, pb.size()):
		out.append(pb[(ib + m) % pb.size()])
	# convex in plan, every turn the same way (straight runs allowed)
	var sign := 0.0
	for k in out.size():
		var p: Vector3 = verts[out[k]]
		var q: Vector3 = verts[out[(k + 1) % out.size()]]
		var r: Vector3 = verts[out[(k + 2) % out.size()]]
		var cross := (q.x - p.x) * (r.z - q.z) - (q.z - p.z) * (r.x - q.x)
		if absf(cross) < 1e-7:
			continue
		if sign == 0.0:
			sign = signf(cross)
		elif signf(cross) != sign:
			return PackedInt32Array()
	# flat: the plane of A's first three vertices holds every vertex
	var a0: Vector3 = verts[pa[0]]
	var n := (verts[pa[1]] - a0).cross(verts[pa[2]] - a0)
	if absf(n.y) < 1e-9:
		return PackedInt32Array()
	for k in out:
		var v: Vector3 = verts[k]
		# the plane's height over v: n.(x - a0) = 0
		var h := a0.y - (n.x * (v.x - a0.x) + n.z * (v.z - a0.z)) / n.y
		if absf(h - v.y) > flat:
			return PackedInt32Array()
	return out


## Godot's conversion of Recast's detail triangles now and then lays two
## triangles over each other along an edge, so three share it -- and the map
## drops that edge, cutting the walk there (Manarola's through road, once).
## Of the triangles on one side of such an edge the largest is kept. Returns
## how many were removed.
static func remove_overlaps(mesh: Dictionary) -> int:
	var verts: PackedVector3Array = mesh["vertices"]
	var polygons: Array[PackedInt32Array] = mesh["polygons"]
	var removed := 0
	for _round in range(4):
		var uses := {}
		for i in polygons.size():
			var poly: PackedInt32Array = polygons[i]
			for k in poly.size():
				var key := Vector2i(mini(poly[k], poly[(k + 1) % poly.size()]), maxi(poly[k], poly[(k + 1) % poly.size()]))
				if not uses.has(key):
					uses[key] = []
				(uses[key] as Array).append(i)
		var drop := {}
		for key in uses:
			var list: Array = uses[key]
			if list.size() <= 2:
				continue
			var a := Vector2(verts[key.x].x, verts[key.x].z)
			var d := Vector2(verts[key.y].x, verts[key.y].z) - a
			var sides := {}
			for i in list:
				if drop.has(i):
					continue
				var c := Vector2.ZERO
				for k in polygons[i]:
					c += Vector2(verts[k].x, verts[k].z)
				c /= float(polygons[i].size())
				var side := 1 if d.cross(c - a) > 0.0 else -1
				if not sides.has(side):
					sides[side] = []
				(sides[side] as Array).append(i)
			for side in sides:
				var same: Array = sides[side]
				if same.size() < 2:
					continue
				same.sort_custom(func(p: int, q: int) -> bool:
					return _area(verts, polygons[p]) > _area(verts, polygons[q]) \
						or (_area(verts, polygons[p]) == _area(verts, polygons[q]) and p < q))
				for m in range(1, same.size()):
					drop[same[m]] = true
		if drop.is_empty():
			break
		var kept: Array[PackedInt32Array] = []
		for i in polygons.size():
			if not drop.has(i):
				kept.append(polygons[i])
		removed += drop.size()
		polygons = kept
	mesh["polygons"] = polygons
	return removed


static func _area(verts: PackedVector3Array, poly: PackedInt32Array) -> float:
	var s := 0.0
	for k in poly.size():
		var p: Vector3 = verts[poly[k]]
		var q: Vector3 = verts[poly[(k + 1) % poly.size()]]
		s += p.x * q.z - q.x * p.z
	return absf(s) * 0.5


## Over a stair the walk is not the treads but the line through their
## middles -- a person's feet go from tread to tread, and a mesh over a
## stair is a slope -- so a vertex there is set on that PITCH: the treads'
## heights at their middles, straight between. Within a tread the pitch is at
## most half a riser off it (0.075 m on a stair street, 0.085 m on an access
## or entry flight). NAN where `v` is over no stair.
static func stair_pitch(plan: VillagePlan, surface: VillageGroundSurface, flights: Array, v: Vector3, at_p: Vector2 = Vector2.INF) -> float:
	var p := Vector2(v.x, v.z)
	var e: Vector2 = at_p if at_p.is_finite() else p
	# a house's entry flight stands over the ground, its lowest treads a
	# riser or two above it -- closer than Recast's own heights are good
	# for -- so a vertex there cannot be told to be on the flight: entry
	# flights keep their treads (the nearest layer), not a pitch
	for f in flights:
		if (f["box"] as Rect2).has_point(p):
			return NAN
	var ri := surface.region_at(p)
	if ri >= surface.regions.size():
		return NAN
	var r: Dictionary = surface.regions[ri]
	if r.has("tread"):
		var i: int = int(r["owner"])
		var bed: Dictionary = surface.road_bed(i)
		var treads: Array = bed["treads"]
		var sv: PackedFloat32Array = bed["s"]
		var length: float = sv[sv.size() - 1]
		var at := surface.along(i, e)
		var xs := PackedFloat32Array()
		var hs := PackedFloat32Array()
		for t in treads:
			_knots(xs, hs, maxf(float(t["s0"]), -1.0), minf(float(t["s1"]), length + 1.0), float(t["h"]), PITCH_HALF)
		return _agreed(_interp(xs, hs, at), v)
	# an access flight is not baked (FLOOR_KINDS): a vertex over one is the
	# raster straddling its edge, and takes the ground it came from; the
	# flight's own pitch is its link (access_pitch)
	return NAN


## The pitch of a stair within one cell of `v` (read at four points a cell
## off), NAN when there is none.
static func _pitch_near(plan: VillagePlan, surface: VillageGroundSurface, flights: Array, v: Vector3) -> float:
	var best := NAN
	for d in [Vector2(CELL, 0.0), Vector2(-CELL, 0.0), Vector2(0.0, CELL), Vector2(0.0, -CELL)]:
		var q: Vector2 = Vector2(v.x, v.z) + d
		var ri := surface.region_at(q)
		if ri >= surface.regions.size():
			continue
		var r: Dictionary = surface.regions[ri]
		if not r.has("tread"):
			continue
		# the stair's pitch carried to v itself, along the stair
		var h := stair_pitch(plan, surface, flights, Vector3(q.x, v.y, q.y), Vector2(v.x, v.z))
		if not is_nan(h) and (is_nan(best) or absf(h - v.y) < absf(best - v.y)):
			best = h
	return best


## Half the stretch over which a stair street's pitch climbs a nosing: a
## tread longer than two of these is level between them (a landing).
const PITCH_HALF := 0.25


## A tread [s0, s1] at height h on the pitch: level over its middle, the
## climb to the next tread taken within `half` of each nosing. Within any
## tread the pitch is then at most half a riser off it.
static func _knots(xs: PackedFloat32Array, hs: PackedFloat32Array, s0: float, s1: float, h: float, half: float) -> void:
	var q := minf((s1 - s0) * 0.5, half)
	xs.append(s0 + q)
	hs.append(h)
	if s1 - q > s0 + q + 1e-4:
		xs.append(s1 - q)
		hs.append(h)


## The pitch when the baker put the vertex near it: a vertex it set on the
## pad over a flight's cut edge belongs to the pad, not the flight.
static func _agreed(pitch: float, v: Vector3) -> float:
	return pitch if absf(pitch - v.y) <= SNAP_FAR else NAN


static func _route_pitch(route: Array, p: Vector2) -> float:
	var best := INF
	var out := NAN
	for k in range(route.size() - 1):
		var a: Vector3 = route[k]
		var b: Vector3 = route[k + 1]
		var a2 := Vector2(a.x, a.z)
		var d := Vector2(b.x, b.z) - a2
		var t := 0.0 if d.length_squared() < 1e-12 else clampf((p - a2).dot(d) / d.length_squared(), 0.0, 1.0)
		var dist := p.distance_to(a2 + d * t)
		if dist < best:
			best = dist
			out = lerpf(a.y, b.y, t)
	return out


static func _interp(xs: PackedFloat32Array, hs: PackedFloat32Array, x: float) -> float:
	if x <= xs[0]:
		return hs[0]
	for k in range(xs.size() - 1):
		if x <= xs[k + 1]:
			var span: float = xs[k + 1] - xs[k]
			return hs[k] if span < 1e-6 else lerpf(hs[k], hs[k + 1], (x - xs[k]) / span)
	return hs[hs.size() - 1]


static func _centre(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	return c / float(poly.size())


## Each house's entry flight with its plan box, for stair_pitch.
static func _flight_rows(plan: VillagePlan) -> Array:
	var out: Array = []
	for lot in plan.lots:
		for f in lot.get("ground_fit", {}).get("entry_flights", []):
			var box := Rect2()
			var first := true
			for t in f["treads"]:
				var b := Poly.bounding_rect(t["poly"])
				box = b if first else box.merge(b)
				first = false
			out.append({"box": box.grow(0.05), "treads": f["treads"], "route": f["route"]})
	return out


## What stands in the walk in 3D: the flat walk's obstacles, except that a
## building is its WALLS (VillageMeasure.footprint_poly, less a manor's arrival
## court), not its eaves -- an eave is over head, and over a house's entry
## landing -- and the footprints of the terrace, retaining and cheek walls.
static func obstacle_outlines(plan: VillagePlan) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for row in VillageNavCheck.sources(plan)["obstacles"]:
		if row["kind"] != "building":
			out.append(row["poly"])
	for b in plan.buildings:
		var walls: Array[PackedVector2Array] = [VillageMeasure.footprint_poly(b)]
		if b["placement"].has("approach"):
			var court := PackedVector2Array()
			var xf: Transform3D = b["transform"]
			for point in Poly.from_rect(b["placement"]["approach"]):
				var p: Vector3 = xf * Vector3(point.x, 0.0, point.y)
				court.append(Vector2(p.x, p.z))
			walls = VillageNavCheck._minus(walls, [court])
		out.append_array(walls)
	out.append_array(wall_footprints(plan))
	for lot in plan.lots:
		for f in lot.get("ground_fit", {}).get("entry_flights", []):
			# every tread but one flush with the ground at its foot
			var foot_y: float = (f["route"][(f["route"] as Array).size() - 1] as Vector3).y
			for k in range(1, (f["treads"] as Array).size()):
				if float(f["treads"][k]["top"]) - foot_y > 0.05:
					out.append(f["treads"][k]["poly"])
	return out


## Edges three or more polygons share: what Godot's map cannot connect.
static func overfull_edges(mesh: Dictionary) -> int:
	var count := {}
	for poly in mesh["polygons"]:
		for k in poly.size():
			var a: int = poly[k]
			var b: int = poly[(k + 1) % poly.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = int(count.get(key, 0)) + 1
	var out := 0
	for key in count:
		if int(count[key]) > 2:
			out += 1
	return out


## The surfaces a person walks on, as Godot-front-up triangles (clockwise
## seen from above): the emitted ground in the floor regions, the houses'
## entry flights, the crossings.
static func source_faces(plan: VillagePlan) -> PackedVector3Array:
	var surface := VillageGroundSurface.of(plan)
	surface.build_mesh()
	var faces := PackedVector3Array()
	for cell in surface._tops:
		var tops: Array = cell
		for k in range(0, tops.size(), 3):
			var a: Vector3 = tops[k]
			var b: Vector3 = tops[k + 1]
			var c: Vector3 = tops[k + 2]
			var mid := Vector2((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
			if surface.kind_of(surface.region_at(mid)) in FLOOR_KINDS:
				_tri(faces, a, b, c)
	# a working prop's apron over open land is floor in the flat walk too
	var aprons: Array[PackedVector2Array] = []
	for p in plan.props:
		if p.has("approach"):
			aprons.append(p["approach"])
	if not aprons.is_empty():
		for cell in surface._tops:
			var tops: Array = cell
			for k in range(0, tops.size(), 3):
				var a: Vector3 = tops[k]
				var b: Vector3 = tops[k + 1]
				var c: Vector3 = tops[k + 2]
				var tri := PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
				var mid := (tri[0] + tri[1] + tri[2]) / 3.0
				if surface.kind_of(surface.region_at(mid)) in FLOOR_KINDS:
					continue
				for apron in aprons:
					for piece in Geometry2D.intersect_polygons(tri, apron):
						if Geometry2D.is_polygon_clockwise(piece):
							continue
						var idx := Geometry2D.triangulate_polygon(piece)
						for t in range(0, idx.size(), 3):
							var q := [piece[idx[t]], piece[idx[t + 1]], piece[idx[t + 2]]]
							_tri(faces, Vector3(q[0].x, VillageGroundSurface.tri_height(a, b, c, q[0]), q[0].y),
								Vector3(q[1].x, VillageGroundSurface.tri_height(a, b, c, q[1]), q[1].y),
								Vector3(q[2].x, VillageGroundSurface.tri_height(a, b, c, q[2]), q[2].y))
	# a house's entry flight: its landing is floor; its treads are the link
	# (entry_links) and stand in the walk as an obstacle (obstacle_outlines)
	for lot in plan.lots:
		for f in lot.get("ground_fit", {}).get("entry_flights", []):
			var landing: Dictionary = f["treads"][0]
			_quad(faces, landing["poly"], float(landing["top"]))
	for crossing in plan.water_crossings:
		_crossing(faces, surface, crossing)
	return faces


## The deck and its two ramps, as VillageBuilder._crossing lays them.
static func _crossing(faces: PackedVector3Array, surface: VillageGroundSurface, crossing: Dictionary) -> void:
	var points: PackedVector2Array = crossing["points"]
	if points.size() < 2:
		return
	var bridge: bool = crossing["kind"] == &"bridge"
	var half: float = (float(crossing["width"]) + VillageBuilder.BRIDGE_MARGIN) * 0.5
	var ribbon := Poly.ribbon(points, half)
	var top: float = (0.15 if bridge else 0.08) + maxf(surface.height_at(points[0]),
		surface.height_at(points[points.size() - 1])) + (0.25 if bridge else 0.12) * 0.5
	for i in range(points.size() - 1):
		_quad(faces, PackedVector2Array([ribbon[i], ribbon[i + 1], ribbon[ribbon.size() - 2 - i],
			ribbon[ribbon.size() - 1 - i]]), top)
	for end in [0, points.size() - 1]:
		var inside: int = 1 if end == 0 else points.size() - 2
		var d: Vector2 = (points[end] - points[inside]).normalized()
		var across := Vector2(-d.y, d.x) * half
		var near: Vector2 = points[end]
		var far: Vector2 = near + d * (1.5 if bridge else 0.8)
		var foot := surface.height_at(far) + VillageBuilder.Y_ROAD
		var a := Vector3(near.x + across.x, top, near.y + across.y)
		var b := Vector3(far.x + across.x, foot, far.y + across.y)
		var c := Vector3(far.x - across.x, foot, far.y - across.y)
		var e := Vector3(near.x - across.x, top, near.y - across.y)
		_tri(faces, a, b, c)
		_tri(faces, a, c, e)


## The plan footprint of every wall panel VillageBuilder stands on the ground.
static func wall_footprints(plan: VillagePlan) -> Array[PackedVector2Array]:
	var builder := VillageBuilder.new()
	builder.build(plan)
	var out: Array[PackedVector2Array] = []
	for row in builder.component_log:
		if not String(row["role"]) in WALL_ROLES or row["form"] != "slab":
			continue
		var pts: PackedVector3Array = row["points"]
		var a := Vector2(pts[0].x, pts[0].z)
		var b := Vector2(pts[1].x, pts[1].z)
		if a.distance_to(b) < 1e-3:
			continue
		out.append(Poly.ribbon(PackedVector2Array([a, b]), float(row["depth"]) * 0.5))
	return out


## Every upward triangle, wound for Godot (front face clockwise from above).
static func _tri(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	if is_nan(a.y) or is_nan(b.y) or is_nan(c.y):
		return
	var n := (c - a).cross(b - a)
	if absf(n.y) < 1e-9:
		return
	if n.y > 0.0:
		faces.append_array([a, b, c])
	else:
		faces.append_array([a, c, b])


static func _quad(faces: PackedVector3Array, poly: PackedVector2Array, y: float) -> void:
	for k in range(1, poly.size() - 1):
		_tri(faces, Vector3(poly[0].x, y, poly[0].y), Vector3(poly[k].x, y, poly[k].y),
			Vector3(poly[k + 1].x, y, poly[k + 1].y))


## The source triangles by plan cell.
static func _bucket(faces: PackedVector3Array) -> Dictionary:
	var out := {}
	for k in range(0, faces.size(), 3):
		var lo := Vector2(minf(faces[k].x, minf(faces[k + 1].x, faces[k + 2].x)),
			minf(faces[k].z, minf(faces[k + 1].z, faces[k + 2].z)))
		var hi := Vector2(maxf(faces[k].x, maxf(faces[k + 1].x, faces[k + 2].x)),
			maxf(faces[k].z, maxf(faces[k + 1].z, faces[k + 2].z)))
		for j in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
			for i in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
				var key := Vector2i(i, j)
				if not out.has(key):
					out[key] = []
				(out[key] as Array).append(k)
	return out


## The heights of every source surface over (x, z), within 2 mm of the plan
## point (a vertex on a seam belongs to the triangles either side).
static func layers(index: Dictionary, faces: PackedVector3Array, p: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in index.get(Vector2i(floori(p.x / BUCKET), floori(p.y / BUCKET)), []):
		var h := _height_near(faces[k], faces[k + 1], faces[k + 2], p)
		if not is_nan(h):
			out.append(h)
	return out


static func _nearest(index: Dictionary, faces: PackedVector3Array, v: Vector3) -> float:
	var best := NAN
	for h in layers(index, faces, Vector2(v.x, v.z)):
		if is_nan(best) or absf(h - v.y) < absf(best - v.y):
			best = h
	return best


## The height of the source surface nearest `v` in plan within BESIDE metres,
## at its nearest point (an edge point carries its edge's height); NAN when
## there is none.
const BESIDE := 0.3


static func _nearest_beside(index: Dictionary, faces: PackedVector3Array, v: Vector3) -> float:
	var r := _beside_scored(index, faces, v)
	return NAN if r.is_empty() else float(r["h"])


## The nearest source edge point beside v, scored by plan distance plus
## height difference: {"h", "score"}, or {} when none is within BESIDE.
static func _beside_scored(index: Dictionary, faces: PackedVector3Array, v: Vector3) -> Dictionary:
	var p := Vector2(v.x, v.z)
	var best := NAN
	var best_d := INF
	var c0 := Vector2i(floori(p.x / BUCKET), floori(p.y / BUCKET))
	var seen := {}
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			for k in index.get(c0 + Vector2i(di, dj), []):
				if seen.has(k):
					continue
				seen[k] = true
				for e in 3:
					var a: Vector3 = faces[k + e]
					var b: Vector3 = faces[k + (e + 1) % 3]
					var q := Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.z), Vector2(b.x, b.z))
					var d := q.distance_to(p)
					if d > BESIDE:
						continue
					var span := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
					var t := 0.0 if span < 1e-9 else Vector2(a.x, a.z).distance_to(q) / span
					var h := lerpf(a.y, b.y, t)
					# near in plan AND in height: beside a flight, the ground
					# and the flight's edge are both a few centimetres away
					var score := d + absf(h - v.y)
					if score < best_d - 1e-6:
						best_d = score
						best = h
	return {} if is_nan(best) else {"h": best, "score": best_d}


## The triangle's plane height over p, when p is over it or within 2 mm.
static func _height_near(a: Vector3, b: Vector3, c: Vector3, p: Vector2) -> float:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(p.x - a.x, p.y - a.z)
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-12:
		return NAN
	var u := (v2.x * v1.y - v1.x * v2.y) / den
	var w := (v0.x * v2.y - v2.x * v0.y) / den
	var tol := 0.002 / maxf(1e-3, sqrt(absf(den)))
	if u < -tol or w < -tol or u + w > 1.0 + tol:
		return NAN
	return a.y + u * (b.y - a.y) + w * (c.y - a.y)


## Snap, merge, number in (x, z, y) order, rotate each polygon to its lowest
## index (winding kept), sort the polygons.
static func canonical(vertices: PackedVector3Array, polygons: Array[PackedInt32Array]) -> Dictionary:
	var snapped := PackedVector3Array()
	for v in vertices:
		snapped.append(Vector3(snappedf(v.x, GRID), snappedf(v.y, GRID), snappedf(v.z, GRID)))
	var order: Array = range(snapped.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var p: Vector3 = snapped[a]
		var q: Vector3 = snapped[b]
		if p.x != q.x:
			return p.x < q.x
		if p.z != q.z:
			return p.z < q.z
		return p.y < q.y)
	var remap := PackedInt32Array()
	remap.resize(snapped.size())
	var out_v := PackedVector3Array()
	for i in order:
		if out_v.is_empty() or out_v[out_v.size() - 1] != snapped[i]:
			out_v.append(snapped[i])
		remap[i] = out_v.size() - 1
	var out_p: Array[PackedInt32Array] = []
	for poly in polygons:
		var mapped := PackedInt32Array()
		for k in poly:
			var j: int = remap[k]
			if mapped.is_empty() or mapped[mapped.size() - 1] != j:
				mapped.append(j)
		if mapped.size() >= 2 and mapped[0] == mapped[mapped.size() - 1]:
			mapped.remove_at(mapped.size() - 1)
		if mapped.size() < 3:
			continue
		var area := 0.0
		for k in mapped.size():
			var p: Vector3 = out_v[mapped[k]]
			var q: Vector3 = out_v[mapped[(k + 1) % mapped.size()]]
			area += p.x * q.z - q.x * p.z
		if absf(area) < 1e-6:
			continue
		var start := 0
		for k in range(1, mapped.size()):
			if mapped[k] < mapped[start]:
				start = k
		var rotated := PackedInt32Array()
		for k in mapped.size():
			rotated.append(mapped[(start + k) % mapped.size()])
		out_p.append(rotated)
	out_p.sort_custom(func(a: PackedInt32Array, b: PackedInt32Array) -> bool:
		for k in mini(a.size(), b.size()):
			if a[k] != b[k]:
				return a[k] < b[k]
		return a.size() < b.size())
	return {"vertices": out_v, "polygons": out_p}


## A Godot NavigationMesh of the data, baked for the same agent.
static func to_navigation_mesh(mesh: Dictionary) -> NavigationMesh:
	var out := NavigationMesh.new()
	out.cell_size = CELL
	out.cell_height = CELL_HEIGHT
	out.agent_radius = agent_radius()
	out.agent_height = AGENT_HEIGHT
	out.agent_max_climb = MAX_CLIMB
	out.agent_max_slope = MAX_SLOPE_DEG
	out.vertices = mesh["vertices"]
	for poly in mesh["polygons"]:
		out.add_polygon(poly)
	return out


## Each polygon's island (polygons sharing an edge are one).
static func islands(mesh: Dictionary) -> PackedInt32Array:
	var polygons: Array = mesh["polygons"]
	var parent: Array[int] = []
	for i in polygons.size():
		parent.append(i)
	var edges := {}
	for i in polygons.size():
		var poly: PackedInt32Array = polygons[i]
		for k in poly.size():
			var a: int = poly[k]
			var b: int = poly[(k + 1) % poly.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if edges.has(key):
				NavBake._union(parent, i, edges[key])
			else:
				edges[key] = i
	# a link joins the polygons its two ends stand on
	for link in mesh.get("links", []):
		var a := closest(mesh, link["from"])
		var b := closest(mesh, link["to"])
		if int(a["polygon"]) >= 0 and int(b["polygon"]) >= 0:
			NavBake._union(parent, int(a["polygon"]), int(b["polygon"]))
	var out := PackedInt32Array()
	for i in polygons.size():
		out.append(NavBake._find(parent, i))
	return out


## The polygon under `p` whose surface is nearest its height, and the point on
## it: {"polygon", "point"}; else the nearest point on any edge, by 3D
## distance. {"polygon": -1} on an empty mesh.
static func closest(mesh: Dictionary, p: Vector3) -> Dictionary:
	var verts: PackedVector3Array = mesh["vertices"]
	var polygons: Array = mesh["polygons"]
	var best := -1
	var best_pt := Vector3.INF
	var best_d := INF
	var q := Vector2(p.x, p.z)
	for i in polygons.size():
		var poly: PackedInt32Array = polygons[i]
		for k in range(1, poly.size() - 1):
			var h := _height_near(verts[poly[0]], verts[poly[k]], verts[poly[k + 1]], q)
			if not is_nan(h) and absf(h - p.y) < best_d:
				best_d = absf(h - p.y)
				best = i
				best_pt = Vector3(p.x, h, p.z)
	# straight under (or over) it and near in height; else the nearest point
	# in 3D -- a landing's edge, not the lot a storey below it
	if best >= 0 and best_d <= 0.3:
		return {"polygon": best, "point": best_pt}
	for i in polygons.size():
		var poly: PackedInt32Array = polygons[i]
		for k in poly.size():
			var a: Vector3 = verts[poly[k]]
			var b: Vector3 = verts[poly[(k + 1) % poly.size()]]
			var c := Geometry3D.get_closest_point_to_segment(p, a, b)
			if c.distance_to(p) < best_d:
				best_d = c.distance_to(p)
				best = i
				best_pt = c
	return {"polygon": best, "point": best_pt}
