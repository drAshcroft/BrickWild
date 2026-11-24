extends RefCounted
## How near a village's 3D walk comes to what each building BUILT at the
## ground (BG-015-STREET-PLINTH; docs/VILLAGE_TERRAIN.md "The 3D walk").
##
## The walk keeps each building off by its OUTLINE (VillageWalk3D
## .built_outlines). This check does not read that outline: it builds each
## house and shop as it stands on its lot (its request's fall set, so the
## foundation and the entry flights are in it), takes every triangle of the
## shell below a standing person's head (BAND_TOP over the floor), and
## measures the plan distance from every polygon edge of the baked mesh and
## every `gap` link to those triangles. That is what a body walking the mesh
## bumps into: the consumer that found BG-015 cast its walkers' steps at knee
## and chest height against the same shells.
##
##   clear   no mesh edge and no gap link within `clear` metres of a
##           building's built geometry (VillageWalk3D.gap_clear(): the
##           agent's radius less the half cell's diagonal the baker's raster
##           may give away), outside the door's approach; no walk polygon
##           inside its walls
##
## The door's approach is the building's own entry flights (landing and
## treads, `ground_fit.entry_flights`): the flight's prisms are not counted as
## the building, and a point within the agent's radius and a cell of a flight
## is not judged against its building (a landing is floor up to the wall it
## stands against).
##
## Only the plan families (house, shop) are measured: their buildings are
## built here from the measured job the plan was made from. Anything else is
## counted in `skipped`.

## A standing person's head over the building's floor: what is under it can
## be walked into; eaves and jetties above it cannot.
const BAND_TOP := 1.8
## The measured geometry is bucketed on this plan grid.
const BUCKET := 1.0
## How far past the rule's distance the nearest approach is still reported.
const REPORT_REACH := 0.5


## What each building of `plan` built, from `jobs` (the measured jobs the plan
## was made from: VillageLotPlanner.measure_all). Per building index:
## {"polys": Array[PackedVector2Array] (world plan, each a clipped triangle),
## "buckets": {Vector2i: [poly index]}, "box": Rect2, "flights":
## Array[PackedVector2Array], "skipped": String}.
static func built(plan: VillagePlan, jobs: Array) -> Array:
	var by_key := {}
	for job in jobs:
		by_key[_key(job["request"])] = job
	var out: Array = []
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var req: BuildingRequest = b["request"]
		var row := {"polys": [], "buckets": {}, "box": Rect2(), "flights": [], "skipped": ""}
		out.append(row)
		var job: Dictionary = by_key.get(_key(req), {})
		var building: Variant = job.get("building")
		if building == null or not building.is_ok() or not (building.plan is HousePlan):
			row["skipped"] = "%s: not a plan family, or no measured building" % String(req.kind)
			continue
		row["plinth_m"] = float(building.plan.spec.plinth_height)
		var fit: Dictionary = plan.lots[int(b["lot"])].get("ground_fit", {})
		var flights: Array[PackedVector2Array] = []
		for f in fit.get("entry_flights", []):
			for t in f["treads"]:
				flights.append(t["poly"])
		row["flights"] = flights
		# inside the ground storey's walls (a rectangular shell's): its
		# partitions, floors and stairs are not measured, they are behind the
		# walls; a walk that got in there is caught by `inside` instead
		var plan_b: HousePlan = building.plan
		row["xf"] = b["transform"]
		row["inner"] = Rect2() if HouseGeometry.is_shaped(plan_b) \
			else HouseGeometry.interior_rect(plan_b.spec).grow(-INNER_MARGIN)
		var mesh := _as_built(building, req)
		if mesh == null:
			row["skipped"] = "%s: no mesh" % String(req.kind)
			continue
		_collect(row, mesh, b["transform"], flights)
	return out


## A triangle this far inside the walls' inner face, or further, is inside.
const INNER_MARGIN := 0.02


## The fewest metres between the walk and what was built, and where it is
## too near: {"edges": int, "links": int (pieces of PIECE metres of mesh edge
## and of gap link nearer than `clear`), "inside": int (walk polygons whose
## middle is inside a building's walls), "worst_m": float (the nearest, within
## `clear` + REPORT_REACH), "measured": int, "skipped": int, "rows": [String]
## (the worst few)}.
static func measure(mesh: Dictionary, buildings: Array, clear: float, approach: float) -> Dictionary:
	var verts: PackedVector3Array = mesh["vertices"]
	var seen := {}
	var segs: Array = []
	for poly in mesh["polygons"]:
		for k in poly.size():
			var a: int = poly[k]
			var b: int = poly[(k + 1) % poly.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if seen.has(key):
				continue
			seen[key] = true
			_pieces(segs, Vector2(verts[a].x, verts[a].z), Vector2(verts[b].x, verts[b].z), false)
	for link in mesh.get("links", []):
		if String(link.get("kind", "")) != "gap":
			continue
		var p: Vector3 = link["from"]
		var q: Vector3 = link["to"]
		_pieces(segs, Vector2(p.x, p.z), Vector2(q.x, q.z), true)
	var out := {"edges": 0, "links": 0, "inside": 0, "worst_m": INF, "measured": 0, "skipped": 0, "rows": []}
	var found: Array = []
	for bi in buildings.size():
		var row: Dictionary = buildings[bi]
		if String(row["skipped"]) != "":
			out["skipped"] = int(out["skipped"]) + 1
			continue
		out["measured"] = int(out["measured"]) + 1
		# a polygon of the walk standing inside the walls
		var inner: Rect2 = row.get("inner", Rect2())
		if inner.has_area():
			var inv: Transform3D = (row["xf"] as Transform3D).affine_inverse()
			for poly in mesh["polygons"]:
				var c := Vector3.ZERO
				for k in poly:
					c += verts[k]
				c /= float(poly.size())
				var local: Vector3 = inv * Vector3(c.x, 0.0, c.z)
				if inner.has_point(Vector2(local.x, local.z)):
					out["inside"] = int(out["inside"]) + 1
					found.append({"d": 0.0, "building": bi, "poly": -1, "at": Vector2(c.x, c.z),
						"text": "b-%03d a walk polygon inside its walls at (%.2f, %.2f)" % [bi, c.x, c.z]})
		# looked for a little past `clear`, so `worst_m` says how near it came
		var reach := clear + REPORT_REACH
		var box: Rect2 = (row["box"] as Rect2).grow(reach)
		for s in segs:
			var a: Vector2 = s["a"]
			var b: Vector2 = s["b"]
			if not box.intersects(Rect2(a, Vector2.ZERO).expand(b), true):
				continue
			var near := _nearest(row, a, b, reach)
			if near.is_empty():
				continue
			var d: float = near["d"]
			# the door's approach: a point on the walk by the building's flight
			var at: Vector2 = near["at"]
			var by_door := false
			for f in row["flights"]:
				if VillageMeasure.point_to_poly(at, f) <= approach:
					by_door = true
					break
			if by_door:
				continue
			out["worst_m"] = minf(float(out["worst_m"]), d)
			if d < clear:
				out["links" if bool(s["link"]) else "edges"] = int(out["links" if bool(s["link"]) else "edges"]) + 1
				var h: Vector2 = row["heights"][int(near["poly"])]
				found.append({"d": d, "building": bi, "poly": int(near["poly"]), "at": at,
					"text": "b-%03d %s %.3f m at (%.2f, %.2f) from built geometry %.2f-%.2f m over its floor" % [
					bi, "gap link" if bool(s["link"]) else "edge", d, at.x, at.y, h.x, h.y]})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["d"]) < float(y["d"]))
	for f in found.slice(0, 6):
		(out["rows"] as Array).append(f["text"])
	out["near"] = found.slice(0, 12)
	return out


## Segment a-b in pieces no longer than PIECE, so a piece by the door's
## approach does not excuse the rest of its edge.
const PIECE := 0.5


static func _pieces(segs: Array, a: Vector2, b: Vector2, link: bool) -> void:
	var n := maxi(1, int(ceil(a.distance_to(b) / PIECE)))
	for k in n:
		segs.append({"a": a.lerp(b, float(k) / float(n)), "b": a.lerp(b, float(k + 1) / float(n)), "link": link})


## The building's shell as it stands on its lot: the measured (flat) plan with
## the request's fall set, as VillageLotGround._house_parts reads it (below a
## storey the plan does not move), its yard pieces put aside as
## BrickWild.placement does (the walk goes round `yard_blocks`).
static func _as_built(building, req: BuildingRequest) -> ArrayMesh:
	var spec = building.plan.spec
	var keep_fall: float = float(spec.ground_fall)
	var keep_deg: float = float(spec.ground_downhill_deg)
	var held: Array[Dictionary] = building.plan.yard_pieces.duplicate()
	building.plan.yard_pieces.clear()
	spec.ground_fall = req.ground_fall_m
	spec.ground_downhill_deg = req.ground_downhill_deg
	var mesh: ArrayMesh = BrickWild.build_mesh(building)
	spec.ground_fall = keep_fall
	spec.ground_downhill_deg = keep_deg
	building.plan.yard_pieces.assign(held)
	return mesh


## Every triangle of `mesh` under BAND_TOP, clipped there, in the plan's frame,
## less the prisms of the building's own flights.
static func _collect(row: Dictionary, mesh: ArrayMesh, xf: Transform3D, flights: Array[PackedVector2Array]) -> void:
	var grown: Array[PackedVector2Array] = []
	for f in flights:
		for g in Geometry2D.offset_polygon(f, 0.02, Geometry2D.JOIN_MITER):
			if not Geometry2D.is_polygon_clockwise(g):
				grown.append(g)
	var polys: Array = row["polys"]
	var heights := PackedVector2Array()
	var buckets: Dictionary = row["buckets"]
	var inner: Rect2 = row.get("inner", Rect2())
	var box := Rect2()
	var first := true
	var dedupe := {}
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		var n: int = (idx as PackedInt32Array).size() if idx != null else v.size()
		for t in range(0, n - 2, 3):
			var p0: Vector3 = v[idx[t]] if idx != null else v[t]
			var p1: Vector3 = v[idx[t + 1]] if idx != null else v[t + 1]
			var p2: Vector3 = v[idx[t + 2]] if idx != null else v[t + 2]
			if minf(p0.y, minf(p1.y, p2.y)) > BAND_TOP:
				continue
			if inner.has_area() and inner.has_point(Vector2(p0.x, p0.z)) \
					and inner.has_point(Vector2(p1.x, p1.z)) and inner.has_point(Vector2(p2.x, p2.z)):
				continue
			var plan := PackedVector2Array()
			for q in _clip_below([p0, p1, p2], BAND_TOP):
				var w: Vector3 = xf * Vector3(q.x, 0.0, q.z)
				plan.append(Vector2(snappedf(w.x, 0.001), snappedf(w.z, 0.001)))
			if plan.size() < 2:
				continue
			var mid := Vector2.ZERO
			for q in plan:
				mid += q
			mid /= float(plan.size())
			var flight := false
			for g in grown:
				if Geometry2D.is_point_in_polygon(mid, g):
					flight = true
					break
			if flight:
				continue
			var key := str(plan)
			if dedupe.has(key):
				continue
			dedupe[key] = true
			var pb := Poly.bounding_rect(plan)
			box = pb if first else box.merge(pb)
			first = false
			var pi := polys.size()
			polys.append(plan)
			heights.append(Vector2(minf(p0.y, minf(p1.y, p2.y)), maxf(p0.y, maxf(p1.y, p2.y))))
			for j in range(floori(pb.position.y / BUCKET), floori(pb.end.y / BUCKET) + 1):
				for i in range(floori(pb.position.x / BUCKET), floori(pb.end.x / BUCKET) + 1):
					var k := Vector2i(i, j)
					if not buckets.has(k):
						buckets[k] = []
					(buckets[k] as Array).append(pi)
	row["box"] = box
	# each polygon's triangle's height range over the floor, for a report
	row["heights"] = heights


## The part of triangle `tri` at or under height `top`.
static func _clip_below(tri: Array, top: float) -> Array:
	var out: Array = []
	for k in 3:
		var a: Vector3 = tri[k]
		var b: Vector3 = tri[(k + 1) % 3]
		var ain := a.y <= top
		var bin := b.y <= top
		if ain:
			out.append(a)
		if ain != bin:
			out.append(a.lerp(b, (top - a.y) / (b.y - a.y)))
	return out


## The nearest built polygon to segment a-b within `reach`: {"d", "at" (the
## point on a-b)}, or {} when nothing is that near.
static func _nearest(row: Dictionary, a: Vector2, b: Vector2, reach: float) -> Dictionary:
	var span := Rect2(a, Vector2.ZERO).expand(b).grow(reach)
	var polys: Array = row["polys"]
	var buckets: Dictionary = row["buckets"]
	var tried := {}
	var best := {}
	for j in range(floori(span.position.y / BUCKET), floori(span.end.y / BUCKET) + 1):
		for i in range(floori(span.position.x / BUCKET), floori(span.end.x / BUCKET) + 1):
			for pi in buckets.get(Vector2i(i, j), []):
				if tried.has(pi):
					continue
				tried[pi] = true
				var r := _segment_poly(a, b, polys[pi])
				r["poly"] = pi
				if float(r["d"]) <= reach and (best.is_empty() or float(r["d"]) < float(best["d"])):
					best = r
	return best


## Plan distance from segment a-b to a polygon (a clipped triangle, or the
## line a wall's face projects to), and the point on a-b where it is least.
static func _segment_poly(a: Vector2, b: Vector2, poly: PackedVector2Array) -> Dictionary:
	if poly.size() >= 3 and absf(Poly.signed_area(poly)) > 1e-6:
		for p in [a, b]:
			if Geometry2D.is_point_in_polygon(p, poly):
				return {"d": 0.0, "at": p}
	var best := {"d": INF, "at": a}
	for k in poly.size():
		var c: Vector2 = poly[k]
		var d: Vector2 = poly[(k + 1) % poly.size()]
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
		if hit != null:
			return {"d": 0.0, "at": hit}
		var pair := Geometry2D.get_closest_points_between_segments(a, b, c, d)
		var dist: float = (pair[0] as Vector2).distance_to(pair[1])
		if dist < float(best["d"]):
			best = {"d": dist, "at": pair[0]}
	return best


## A request's identity without the fall the lot gave it (VillageLotGround
## .request_for copies it with the fall set).
static func _key(req: BuildingRequest) -> String:
	var d: Dictionary = req.to_dict()
	d.erase("ground_fall_m")
	d.erase("ground_downhill_deg")
	return JSON.stringify(d, "", true)
