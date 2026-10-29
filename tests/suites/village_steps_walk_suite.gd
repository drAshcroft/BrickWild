extends RefCounted
## The village walk in 3D on real hillsides (VTER-STEPS-NAV), read the way a
## consumer reads it: the `walk` key out of JSON, handed to Godot's own
## NavigationServer3D. Manarola, Positano, Hallstatt and Monpazier (real30), 50 people, the green
## form (Manarola one stair street, Positano two, Hallstatt one; Monpazier none, only access flights).
##
##   the stairs: every `steps` road and access flight is stepped in the
##     emitted ground and named (VillageGroundCheck, `stairs` and the rest)
##   one island: every gate and every door's 3D point on the gates' island
##   paths: NavigationServer3D finds a path from the first gate to every door
##   heights: the mesh's vertices on the emitted ground, and the mesh under
##     every path within 0.1 m of the emitted ground (read back from the
##     Ground mesh, and the houses' entry flights)
##   the same plan writes the same bytes
##   control: without the access flights the same bake strands doors
##
## And a hillside's `stepped` through road (`_stepped_case`): built with treads
## and stair stones, and the 3D walk climbs it from one gate to the other.
## Nothing else about the hillside form on the walk is asked here: its steep
## cross-lanes (a stair's going under 0.28 m) and the doors off them are the
## open items in docs/VILLAGE_TERRAIN.md.

const VTP := preload("res://tests/suites/village_terrain_plan_suite.gd")
## [ground, form, options]. Options: "street" false where the village has no stair street (only
## access flights, as Monpazier's bastide), and "known" for ground-seam
## defects open under VTER-GROUND-SEAM, each a CEILING: a regression past it,
## or a fixed one still listed, is a failure.
const CASES := [
	["real30/manarola", &"green", {}],
	["real30/positano", &"green", {}],
	["real30/hallstatt", &"green", {"known": {"open": 1, "layers": 1}}],
	["real30/monpazier", &"green", {"street": false, "known": {"layers": 1}}],
]
## The stair street the hillside form makes of a through road too steep for a cart
## (HILLS-GENERAL): Masouleh planned as a hillside, its `stepped` through road.
const STEPPED_CASES := ["real30/masouleh"]
const ARRIVE := 0.05
const VERTICAL := 0.1
const SAMPLE := 0.25
const BUCKET := 2.5


static func run() -> SuiteResult:
	var res := SuiteResult.new("vstepswalk")
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(VTP.spec_for(&"street", null)))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for c in CASES:
		_case(res, jobs, c[0], c[1], c[2])
	for g in STEPPED_CASES:
		_stepped_case(res, jobs, g)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func _case(res: SuiteResult, jobs: Array[Dictionary], ground_name: String, form: StringName, opts: Dictionary = {}) -> void:
	var label := "%s/%s" % [ground_name, form]
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(VTP.spec_for(form, VTP.terrain(ground_name)), jobs)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	if plan.ground == null or plan.buildings.is_empty():
		res.fail("%s: not planned on its ground" % label)
		return
	# --- the ground, as built
	t0 = Time.get_ticks_msec()
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	var scene := Node3D.new()
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	var rows: Array = []
	for row in builder.component_log:
		rows.append({"role": String(row["role"]), "host": String(row["host"]), "id": String(row["id"])})
	ground.set_meta(&"components", rows)
	scene.add_child(ground)
	var check := VillageGroundCheck.new()
	var report: Dictionary = check.check(plan, scene)
	var st: Dictionary = report["stats"]
	res.checked += 1
	var known: Dictionary = opts.get("known", {})
	var seen := {}
	for f in (report["failures"] as Array).slice(0, 8):
		var kind := ""
		if "are open by more than" in String(f):
			kind = "open"
		elif "two ground layers more than" in String(f):
			kind = "layers"
		var count := int(String(f).get_slice(": ", 1).get_slice(" ", 0))
		if kind != "" and known.has(kind) and count <= int(known[kind]):
			seen[kind] = true
			res.warn("%s: known ground seam (VTER-GROUND-SEAM, ceiling %d): %s" % [label, int(known[kind]), f])
			continue
		res.fail("%s: %s" % [label, f])
	for kind in known:
		res.checked += 1
		if not seen.has(kind):
			res.fail("%s: the known ground-seam defect '%s' is gone; take it off the case's `known` list" % [label, kind])
	res.checked += 1
	var streets := 0
	for i in plan.roads.size():
		if VillageGroundSurface.of(plan).road_bed(i).has("treads"):
			streets += 1
	if (streets == 0 and bool(opts.get("street", true))) or builder.components("stair_tread").is_empty():
		res.fail("%s: no stair street was built (%d steps roads, %d tread stones)" % [label, streets,
			builder.components("stair_tread").size()])
	res.checked += 1
	var comp: Dictionary = ComponentCheck.check(builder, mesh)
	if not comp["ok"]:
		res.fail("%s: the stairs' components differ from their triangles: %s" % [label, str(comp.get("failures", comp)).left(300)])
	var build_s := (Time.get_ticks_msec() - t0) / 1000.0
	var probe: VillageGroundCheck.GroundProbe = VillageGroundCheck.GroundProbe.of(mesh)
	var flights: Array = []
	for lot in plan.lots:
		for f in lot.get("ground_fit", {}).get("entry_flights", []):
			flights.append_array(f["treads"])
	var access_made := 0
	var access_refused: Array[String] = []
	for li in plan.lots.size():
		var a: Dictionary = plan.lots[li].get("ground_fit", {}).get("access", {})
		if a.has("treads"):
			access_made += 1
		elif a.has("refused"):
			access_refused.append("lot%d (%.2f m)" % [li, float(a["rise_m"])])
	# --- the walk, as a consumer receives it
	t0 = Time.get_ticks_msec()
	var text := JSON.stringify(VillageWalk.projection(plan, "c"), "", true)
	var walk_s := (Time.get_ticks_msec() - t0) / 1000.0
	var again := JSON.stringify(VillageWalk.projection(plan, "c"), "", true)
	res.checked += 1
	if text != again:
		res.fail("%s: the same plan wrote two different walks" % label)
	var walk: Dictionary = JSON.parse_string(text)
	res.checked += 1
	if not walk.has("navmesh_3d") or (walk["navmesh_3d"]["polygons"] as Array).is_empty():
		res.fail("%s: no 3D navigation mesh" % label)
		scene.free()
		return
	var m3 := _mesh(walk["navmesh_3d"])
	var islands := VillageWalk3D.islands(m3)
	var index := _index(m3)
	# heights: every vertex on the emitted ground
	var vworst := 0.0
	for v in (m3["vertices"] as PackedVector3Array):
		vworst = maxf(vworst, _error(probe, flights, v, true))
	res.checked += 1
	if vworst > VERTICAL:
		res.fail("%s: a navigation vertex stands %.3f m off the emitted ground" % [label, vworst])
	# one island
	var gate_islands := {}
	for g in walk["gates"]:
		res.checked += 1
		if g["nav_3d_m"] == null:
			res.fail("%s: %s is not on the 3D mesh" % [label, g["gate_id"]])
			continue
		var at := _poly_at(m3, index, _v3(g["nav_3d_m"]))
		if at >= 0:
			gate_islands[islands[at]] = true
	res.checked += 1
	if gate_islands.size() != 1:
		res.fail("%s: the %d gates stand on %d islands" % [label, walk["gates"].size(), gate_islands.size()])
	var stranded: Array[String] = []
	for d in walk["doors"]:
		res.checked += 1
		if d["outside_3d_m"] == null:
			stranded.append("%s (no 3D point)" % d["building_id"])
			continue
		var at := _poly_at(m3, index, _v3(d["outside_3d_m"]))
		if at < 0 or not gate_islands.has(islands[at]) or not bool(d["reachable_3d"]):
			stranded.append("%s (island %d%s)" % [d["building_id"], islands[at] if at >= 0 else -1,
				"" if bool(d["reachable_3d"]) else ", not reachable_3d"])
	if not stranded.is_empty():
		res.fail("%s: %d of %d doors are not on the gates' island: %s" % [label, stranded.size(),
			walk["doors"].size(), ", ".join(stranded.slice(0, 6))])
	# paths, by NavigationServer3D
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, VillageWalk3D.CELL)
	NavigationServer3D.map_set_cell_height(map, VillageWalk3D.CELL_HEIGHT)
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, float(walk["navmesh_3d"]["merge_rasterizer_cell_scale"]))
	NavigationServer3D.map_set_use_async_iterations(map, false)
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_use_async_iterations(region, false)
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, VillageWalk3D.to_navigation_mesh(m3))
	var link_rids: Array[RID] = []
	for link in m3["links"]:
		var rid := NavigationServer3D.link_create()
		NavigationServer3D.link_set_map(rid, map)
		NavigationServer3D.link_set_bidirectional(rid, true)
		NavigationServer3D.link_set_start_position(rid, link["from"])
		NavigationServer3D.link_set_end_position(rid, link["to"])
		link_rids.append(rid)
	NavigationServer3D.map_force_update(map)
	var from := _v3(walk["gates"][0]["nav_3d_m"])
	var arrived := 0
	var failed: Array[String] = []
	var pworst := 0.0
	var sworst := 0.0
	var chord := 0.0
	var climbed := 0.0
	var sworst_at := Vector3.ZERO
	# without the one-cell allowance at any riser, for the record
	var strict := 0.0
	var samples := 0
	for d in walk["doors"]:
		if d["outside_3d_m"] == null:
			continue
		var to := _v3(d["outside_3d_m"])
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		res.checked += 1
		if path.is_empty() or path[path.size() - 1].distance_to(to) > ARRIVE:
			failed.append("%s (ends %s)" % [d["building_id"], str(path[path.size() - 1]) if not path.is_empty() else "nowhere"])
			continue
		arrived += 1
		var lo := INF
		var hi := -INF
		for k in path.size():
			lo = minf(lo, path[k].y)
			hi = maxf(hi, path[k].y)
			pworst = maxf(pworst, _error(probe, flights, path[k], true))
			strict = maxf(strict, _error(probe, flights, path[k]))
			samples += 1
			if k == 0:
				continue
			var a: Vector3 = path[k - 1]
			var b: Vector3 = path[k]
			var linked := _is_link(m3["links"], a, b)
			var n := maxi(1, int(ceil(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) / SAMPLE)))
			for m in range(1, n):
				var q := a.lerp(b, float(m) / float(n))
				chord = maxf(chord, _error(probe, flights, q))
				# over a flight the walk is the link itself: its straight line
				# against the treads; elsewhere the mesh under the path
				var at3 := q
				if not linked:
					var on := _height_on(m3, index, q)
					if is_nan(on):
						continue
					at3 = Vector3(q.x, on, q.z)
				samples += 1
				var e := _error(probe, flights, at3, true)
				strict = maxf(strict, _error(probe, flights, at3))
				if e > sworst:
					sworst = e
					sworst_at = at3
		climbed = maxf(climbed, hi - lo)
	for rid in link_rids:
		NavigationServer3D.free_rid(rid)
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	if not failed.is_empty():
		res.fail("%s: NavigationServer3D found no path from the gate to %d doors: %s" % [label, failed.size(),
			", ".join(failed.slice(0, 5))])
	res.checked += 1
	if pworst > VERTICAL or sworst > VERTICAL:
		res.fail("%s: a path stands off the ground: %.3f m at its points, %.3f m on the mesh along it (at %s)"
			% [label, pworst, sworst, str(sworst_at)])
	# control: the same bake without the access flights strands doors
	var control := _without_access(plan)
	res.checked += 1
	if access_made > 0 and control == 0:
		res.fail("%s: control -- without its %d access flights no door was stranded; the island check sees nothing" % [label, access_made])
	var stairs: Array = walk.get("stairs", [])
	res.note("%s: plan %.1f s, build+check %.1f s, walk %.1f s; %d buildings, %d stair streets (%d treads, riser max %.3f, going min %.2f, mesh worst %.3f), access flights %d (refused %s), entry flights %d; navmesh %d vertices / %d polygons (%d KB as JSON); doors on the gates' island %d/%d, paths %d/%d, climbed up to %.1f m; vertical error: vertices %.3f, path points %.3f, mesh along paths %.3f over %d samples (strict, no riser cell: %.3f; straight chords %.3f); control: %d doors stranded without access flights"
		% [label, plan_s, build_s, walk_s, plan.buildings.size(), streets, int(st.get("stair_treads", 0)),
			float(st.get("stair_riser_max", 0.0)), float(st.get("stair_going_min", 0.0)), float(st.get("stair_mesh_worst", 0.0)),
			access_made, ", ".join(access_refused) if not access_refused.is_empty() else "none", stairs.filter(func(s: Dictionary) -> bool: return s["kind"] == "entry").size(),
			(m3["vertices"] as PackedVector3Array).size(), (m3["polygons"] as Array).size(), text.length() / 1024,
			walk["doors"].size() - stranded.size(), walk["doors"].size(), arrived, walk["doors"].size(), climbed,
			vworst, pworst, sworst, samples, strict, chord, control])
	scene.free()


## A hillside's `stepped` through road, built and walked. The plan is the
## hillside form on the ground; the road is checked to have treads in its bed and
## stair stones in the mesh (host `road<i>`), and NavigationServer3D finds a path
## from the first gate to the second along it that climbs the bed's rise.
static func _stepped_case(res: SuiteResult, jobs: Array[Dictionary], ground_name: String) -> void:
	var label := "%s/hillside (stepped through road)" % ground_name
	var plan := VillageLotPlanner.plan_measured(VTP.spec_for(&"hillside", VTP.terrain(ground_name)), jobs)
	res.checked += 1
	var through: Array[int] = plan.roads_of_class(&"through")
	if plan.ground == null or through.is_empty() or not bool(plan.roads[through[0]].get("stepped", false)):
		res.fail("%s: the plan has no `stepped` through road" % label)
		return
	var road: int = through[0]
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	var bed: Dictionary = VillageGroundSurface.of(plan).road_bed(road)
	var named := 0
	for row in builder.components("stair_tread"):
		if String(row["host"]) == "road%d" % road:
			named += 1
	var treads: Array = bed.get("treads", [])
	var h: PackedFloat32Array = bed["h"]
	var h_lo := INF
	var h_hi := -INF
	for v in h:
		h_lo = minf(h_lo, v)
		h_hi = maxf(h_hi, v)
	var rise: float = h_hi - h_lo
	res.checked += 1
	if treads.size() < 2 or named < treads.size() - 1:
		res.fail("%s: road %d is `stepped` but has %d treads and %d stair stones" % [label, road, treads.size(), named])
	res.checked += 1
	if rise < 1.0:
		res.fail("%s: the through road's bed ranges %.2f m, not a stair street" % [label, rise])
	var comp: Dictionary = ComponentCheck.check(builder, mesh)
	res.checked += 1
	if not comp["ok"]:
		res.fail("%s: the stairs' components differ from their triangles: %s" % [label, str(comp.get("failures", comp)).left(300)])
	var walk: Dictionary = JSON.parse_string(JSON.stringify(VillageWalk.projection(plan, "c"), "", true))
	res.checked += 1
	if not walk.has("navmesh_3d") or (walk["navmesh_3d"]["polygons"] as Array).is_empty() or walk["gates"].size() < 2:
		res.fail("%s: no 3D navigation mesh or fewer than two gates" % label)
		return
	var m3 := _mesh(walk["navmesh_3d"])
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, VillageWalk3D.CELL)
	NavigationServer3D.map_set_cell_height(map, VillageWalk3D.CELL_HEIGHT)
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, float(walk["navmesh_3d"]["merge_rasterizer_cell_scale"]))
	NavigationServer3D.map_set_use_async_iterations(map, false)
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_use_async_iterations(region, false)
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, VillageWalk3D.to_navigation_mesh(m3))
	var link_rids: Array[RID] = []
	for link in m3["links"]:
		var rid := NavigationServer3D.link_create()
		NavigationServer3D.link_set_map(rid, map)
		NavigationServer3D.link_set_bidirectional(rid, true)
		NavigationServer3D.link_set_start_position(rid, link["from"])
		NavigationServer3D.link_set_end_position(rid, link["to"])
		link_rids.append(rid)
	NavigationServer3D.map_force_update(map)
	var from := _v3(walk["gates"][0]["nav_3d_m"])
	var to := _v3(walk["gates"][1]["nav_3d_m"])
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var lo := INF
	var hi := -INF
	for p in path:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	for rid in link_rids:
		NavigationServer3D.free_rid(rid)
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	res.checked += 1
	if path.is_empty() or path[path.size() - 1].distance_to(to) > ARRIVE:
		res.fail("%s: NavigationServer3D finds no path along the stair street from gate 0 to gate 1 (ends %s)" % [
			label, str(path[path.size() - 1]) if not path.is_empty() else "nowhere"])
	res.checked += 1
	if hi - lo < rise * 0.8:
		res.fail("%s: the path climbs %.2f m, the bed ranges %.2f" % [label, hi - lo, rise])
	res.note("%s: road %d %.0f m long, ranges %.1f m in %d treads (%d stair stones); gate to gate %d path points, climbs %.1f m" % [
		label, road, float(bed["s"][bed["s"].size() - 1]), rise, treads.size(), named, path.size(), hi - lo])
	VillageGroundSurface.forget()


## Doors whose 3D point is off the gates' island when the plan has no access
## flights (they are taken out, baked, and put back). -1 when there were none.
static func _without_access(plan: VillagePlan) -> int:
	var kept := {}
	for li in plan.lots.size():
		var fit: Dictionary = plan.lots[li].get("ground_fit", {})
		if fit.has("access"):
			kept[li] = fit["access"]
			fit.erase("access")
	if kept.is_empty():
		return -1
	VillageGroundSurface.forget()
	var walk: Dictionary = VillageWalk.projection(plan, "c")
	var out := 0
	for d in walk["doors"]:
		if not bool(d["reachable_3d"]):
			out += 1
	for li in kept:
		plan.lots[li]["ground_fit"]["access"] = kept[li]
	VillageGroundSurface.forget()
	return out


## Vertical distance from `p` to the nearest ground at its plan point: the
## emitted Ground mesh's layers and the houses' entry flight treads. A step is
## a discontinuity no mesh can follow, and a voxel bake resolves an edge to
## its cell (a cell straddling a pad's edge takes the pad). So a point within
## STEP_BAND (a baking cell's diagonal) of one of the Ground mesh's risers, or of an
## entry flight's tread edge, and between that riser's foot and top, is ON the
## step -- for every riser when `any_riser` (what the suite gates on), else
## only for a riser the walk climbs and within EDGE_TOL of a taller one (the
## strict figure the suite reports beside it). A stair is not excused beyond
## the band: its tread middles are measured.
const STEP_BAND := VillageWalk3D.CELL * 1.4143
const EDGE_TOL := 0.03


static func _error(probe: VillageGroundCheck.GroundProbe, flights: Array, p: Vector3, any_riser := false) -> float:
	var q := Vector2(p.x, p.z)
	var best := INF
	for h in _layers(probe, flights, q):
		best = minf(best, absf(h - p.y))
	if best <= VERTICAL * 0.5:
		return best
	if _on_step(probe, p, flights, any_riser):
		return 0.0
	return best


static func _on_step(probe: VillageGroundCheck.GroundProbe, p: Vector3, flights: Array = [], any_riser := false) -> bool:
	var q := Vector2(p.x, p.z)
	# an entry flight's nosings are risers too (in the house's mesh, not the
	# ground's): each tread's edges, between its top and the next one down
	for k in range(flights.size()):
		var t: Dictionary = flights[k]
		var top: float = float(t["top"])
		# a tread's edge is a riser down to the next tread or (any riser) to
		# the ground under it
		var bottom: float = top - VillageWalk3D.MAX_CLIMB
		if any_riser:
			for h in probe.heights(q):
				bottom = minf(bottom, h)
		if p.y > top + 0.01 or p.y < bottom - 0.01:
			continue
		var poly: PackedVector2Array = t["poly"]
		for e in poly.size():
			if Geometry2D.get_closest_point_to_segment(q, poly[e], poly[(e + 1) % poly.size()]).distance_to(q) <= STEP_BAND:
				return true
	var c := probe._cell(q)
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			var i: int = c.x + di
			var j: int = c.y + dj
			if i < 0 or j < 0 or i >= probe.nx or j >= probe.ny:
				continue
			var list: Array = probe.risers[j * probe.nx + i]
			for k in range(0, list.size(), 3):
				var a: Vector3 = list[k]
				var b: Vector3 = list[k + 1]
				var e: Vector3 = list[k + 2]
				var lo := minf(a.y, minf(b.y, e.y))
				var hi := maxf(a.y, maxf(b.y, e.y))
				if p.y < lo - 0.01 or p.y > hi + 0.01:
					continue
				# a climbable step: within a cell; any riser: within EDGE_TOL
				# (the baker traces an edge to a centimetre or two)
				var band := STEP_BAND if any_riser or hi - lo <= VillageWalk3D.MAX_CLIMB + 0.05 else EDGE_TOL
				for pair in [[a, b], [b, e], [e, a]]:
					var u := Vector2(pair[0].x, pair[0].z)
					var w := Vector2(pair[1].x, pair[1].z)
					if u.distance_to(w) < 1e-4:
						continue
					if Geometry2D.get_closest_point_to_segment(q, u, w).distance_to(q) <= band:
						return true
	return false


static func _layers(probe: VillageGroundCheck.GroundProbe, flights: Array, q: Vector2) -> Array[float]:
	var out: Array[float] = probe.heights(q)
	for t in flights:
		if Geometry2D.is_point_in_polygon(q, t["poly"]):
			out.append(float(t["top"]))
	return out


static func _mesh(data: Dictionary) -> Dictionary:
	var verts := PackedVector3Array()
	for v in data["vertices_m"]:
		verts.append(_v3(v))
	var polygons: Array[PackedInt32Array] = []
	for p in data["polygons"]:
		polygons.append(PackedInt32Array(p))
	var links: Array = []
	for l in data.get("links", []):
		links.append({"from": _v3(l["from_m"]), "to": _v3(l["to_m"])})
	return {"vertices": verts, "polygons": polygons, "links": links}


static func _is_link(links: Array, a: Vector3, b: Vector3) -> bool:
	for l in links:
		var f: Vector3 = l["from"]
		var t: Vector3 = l["to"]
		if (a.distance_to(f) < 0.05 and b.distance_to(t) < 0.05) or (a.distance_to(t) < 0.05 and b.distance_to(f) < 0.05):
			return true
	return false


static func _index(m: Dictionary) -> Dictionary:
	var out := {}
	var verts: PackedVector3Array = m["vertices"]
	var polygons: Array = m["polygons"]
	for i in polygons.size():
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for k in polygons[i]:
			lo = Vector2(minf(lo.x, verts[k].x), minf(lo.y, verts[k].z))
			hi = Vector2(maxf(hi.x, verts[k].x), maxf(hi.y, verts[k].z))
		for j in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
			for c in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
				var key := Vector2i(c, j)
				if not out.has(key):
					out[key] = []
				(out[key] as Array).append(i)
	return out


## The polygon under p whose surface is nearest p's height, or -1.
static func _poly_at(m: Dictionary, index: Dictionary, p: Vector3) -> int:
	var best := -1
	var best_d := 0.05
	var verts: PackedVector3Array = m["vertices"]
	for i in index.get(Vector2i(floori(p.x / BUCKET), floori(p.z / BUCKET)), []):
		var poly: PackedInt32Array = m["polygons"][i]
		for k in range(1, poly.size() - 1):
			var h := VillageWalk3D._height_near(verts[poly[0]], verts[poly[k]], verts[poly[k + 1]], Vector2(p.x, p.z))
			if not is_nan(h) and absf(h - p.y) < best_d:
				best_d = absf(h - p.y)
				best = i
	return best


## The mesh's height under p nearest p's own, NAN off the mesh.
static func _height_on(m: Dictionary, index: Dictionary, p: Vector3) -> float:
	var best := NAN
	var verts: PackedVector3Array = m["vertices"]
	for i in index.get(Vector2i(floori(p.x / BUCKET), floori(p.z / BUCKET)), []):
		var poly: PackedInt32Array = m["polygons"][i]
		for k in range(1, poly.size() - 1):
			var h := VillageWalk3D._height_near(verts[poly[0]], verts[poly[k]], verts[poly[k + 1]], Vector2(p.x, p.z))
			if not is_nan(h) and (is_nan(best) or absf(h - p.y) < absf(best - p.y)):
				best = h
	return best


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
