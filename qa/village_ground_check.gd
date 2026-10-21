class_name VillageGroundCheck
extends RefCounted
## Does every model the village set down stand on the ground? (walk QA,
## Wolfmarch Green pins 1 and 3: a bush with daylight under it, a cart in the
## air beside a farmhouse.)
##
## The only village check that loads models, because the question is about the
## MODEL: the plan says where a thing stands, the catalogue says how far below
## its origin its feet are, and the assembler adds the two. Both defects were in
## the second number -- a cart measured on its declared box, 1.32 m deeper than
## its wheels, and a bush measured on a buried stem stub -- so no plan-level
## check could see them. This one measures the vertices of the assembled scene.
##
## Three kinds of model, one rule each:
##
##   prop    the village dresser's catalogue props: the lowest vertex is on the
##           ground (VillageBuilder.ground_height, or the prop's own elevation)
##   plant   the dresser's plants: the plant's ground line -- the lower of its
##           origin and the height under which 1% of its vertices lie
##           (SceneBounds.base_heights) -- is on the ground; a plant may bury its
##           stem but not itself
##   yard    each house's yard and facade models, against the height its own
##           HousePlan row says it stands at (VillageAssembler records those
##           rows on the building node as `stands`); wall, ceiling and mounted
##           pieces hang and are not asked
##
## "On" means within FLOAT_TOL above and SINK_TOL below. The ground line, not
## the lowest vertex, is what catches the bush: its lowest vertex WAS on the
## ground, and its leaves were a quarter of a metre up.
##
## ON GIVEN GROUND (VTER-GROUND-MESH) "the ground" is the emitted Ground mesh
## itself, read triangle by triangle from the scene (`GroundProbe`), never the
## field the builder laid it from. A prop or a yard model stands on the LOWEST
## ground under its footprint (its centre and eight points round its rim), so
## on a slope its downhill edge is on the ground: one set down at its centre's
## height floats on the downhill side and is caught. A plant stands at its
## origin. And the ground itself is judged:
##
##   building  stands at its lot's platform (ground_fit.platform_m), and the
##             mesh under its footprint is the family's own ground model there
##             (the platform less GroundFall's plane), within SEAM_TOL
##   seam      along every lot's edge and every road's verge, metre by metre:
##             where the mesh either side differs by more than SEAM_TOL a
##             vertical riser of the mesh closes the step (no gap), and nowhere
##             do two ground layers lie more than SEAM_TOL apart (no overlap)
##   terrace   every terrace wall a lot records, where the mesh steps across
##             it, has a `terrace_wall` component hosted by its lot
##   water     inside natural water no ground stands over the water's own
##             surface (the bank shelves under it rather than poking through)

## A model's feet this far above where it stands: it floats.
const FLOAT_TOL := 0.06
## A prop's lowest point this far under where it stands: it is buried.
const SINK_TOL := 0.06
## A plant's ground line this far under the ground: the plant, not its stem,
## is buried.
const PLANT_BURY := 0.35
## On given ground: the most a pad, a road bed and the terrain may part
## unclosed, or stack, and the most a building's ground may leave its pad.
const SEAM_TOL := 0.05
## A building's floor this far off its platform.
const PLATFORM_TOL := 0.01
## Along an edge, a seam sample every this many metres.
const SEAM_STEP := 1.0
## The ground slots of VillageBuilder (everything walked on; not water, and
## not the stone and timber of walls, bridges and props).
const GROUND_SLOTS := [VillageBuilder.SURF_GROUND, VillageBuilder.SURF_ROAD, VillageBuilder.SURF_COMMON,
	VillageBuilder.SURF_YARD, VillageBuilder.SURF_VERGE, VillageBuilder.SURF_WEAR, VillageBuilder.SURF_TREAD,
	VillageBuilder.SURF_FIELD, VillageBuilder.SURF_BANK, VillageBuilder.SURF_BED]

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var _probe: GroundProbe = null


## `scene` is what VillageAssembler.build(plan) returned.
func check(plan: VillagePlan, scene: Node3D) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats = {"props": 0, "plants": 0, "yard": 0, "worst": 0.0}
	_probe = null
	if plan != null and plan.ground != null:
		var ground := scene.get_node_or_null("Ground") as MeshInstance3D
		if ground == null or ground.mesh == null:
			failures.append("ground: the village has ground but the scene has no Ground mesh")
		else:
			_probe = GroundProbe.of(ground.mesh as ArrayMesh)
	_props(plan, scene)
	_plants(plan, scene)
	_yards(scene)
	if _probe != null:
		_buildings(plan, scene)
		_seams(plan)
		_terraces(plan, scene)
		_water(plan)
		_stairs(plan, scene)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats}


## Where a model stands: the ground mesh's lowest point under its footprint on
## given ground, VillageBuilder.ground_height on a flat village.
func _stand(plan: VillagePlan, p: Vector2, radius: float) -> float:
	if _probe == null:
		return VillageBuilder.ground_height(plan, p)
	return _probe.lowest(p, radius)


func _props(plan: VillagePlan, scene: Node3D) -> void:
	var props := scene.get_node_or_null("Props")
	if props == null:
		return
	for node in props.get_children():
		var i := _index_of(node)
		if i < 0 or i >= plan.props.size() or not node is Node3D:
			continue
		var p: Dictionary = plan.props[i]
		var stand: float = float(p["elevation"]) if p.has("elevation") \
			else _stand(plan, p["pos"], VillageBuilder.prop_radius(p))
		_judge(node as Node3D, scene, String(p["key"]), stand, "prop %s" % node.name)
		stats["props"] = int(stats["props"]) + 1


func _plants(plan: VillagePlan, scene: Node3D) -> void:
	var plants := scene.get_node_or_null("Plants")
	if plants == null:
		return
	for node in plants.get_children():
		var j := _index_of(node)
		if j < 0 or j >= plan.plants.size() or not node is Node3D:
			continue
		var t: Dictionary = plan.plants[j]
		_judge(node as Node3D, scene, String(t["key"]),
			_stand(plan, t["pos"], 0.0), "plant %s" % node.name)
		stats["plants"] = int(stats["plants"]) + 1


func _yards(scene: Node3D) -> void:
	var buildings := scene.get_node_or_null("Buildings")
	if buildings == null:
		return
	for b in buildings.get_children():
		var rows: Array = b.get_meta(&"stands", [])
		var exterior := b.get_node_or_null("Exterior")
		if rows.is_empty() or exterior == null:
			continue
		for row in rows:
			var key: String = String(row.get("key", ""))
			if bool(row.get("mounted", false)) or PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) \
					or PropCatalog.has_tag(key, PropCatalog.CEILING):
				continue
			var node := exterior.get_node_or_null(String(row.get("id", "")))
			if node == null or not node is Node3D:
				continue
			# the stand height in the building's own frame, carried to the scene's
			var local: Vector3 = (node as Node3D).position
			local.y = float(row["y"])
			var at: Vector3 = _to_scene(exterior as Node3D, scene) * local
			var stand: float = at.y
			if _probe != null and float(row["y"]) <= VillageAssembler.YARD_ON_DECK:
				# on the yard, not a deck: the ground under it, measured
				var radius := 0.0
				if PropCatalog.known(key):
					var size: Vector3 = PropCatalog.size(key)
					radius = 0.5 * maxf(size.x, size.z) * absf((node as Node3D).scale.x)
				stand = _probe.lowest(Vector2(at.x, at.z), radius)
			_judge(node as Node3D, scene, key, stand, "%s yard %s" % [b.name, node.name])
			stats["yard"] = int(stats["yard"]) + 1


## One model against the height it stands at.
func _judge(node: Node3D, scene: Node3D, key: String, stand: float, label: String) -> void:
	var parent_xf: Transform3D = _to_scene(node.get_parent() as Node3D, scene)
	var heights: Vector2 = SceneBounds.base_heights(node, parent_xf)
	if heights == Vector2.ZERO and _is_empty(node):
		return
	if is_nan(stand):
		warnings.append("ground: %s (%s) stands off the ground mesh" % [label, key])
		return
	if PropCatalog.has_tag(key, PropCatalog.PLANT):
		var origin_y: float = (parent_xf * node.transform).origin.y
		var line: float = minf(heights.y, origin_y)
		_worst(line - stand)
		if line > stand + FLOAT_TOL:
			failures.append("ground: %s (%s) floats, its ground line %.2fm above the ground"
				% [label, key, line - stand])
		elif heights.y < stand - PLANT_BURY:
			failures.append("ground: %s (%s) is buried, its ground line %.2fm under the ground"
				% [label, key, stand - heights.y])
		return
	_worst(heights.x - stand)
	if heights.x > stand + FLOAT_TOL:
		failures.append("ground: %s (%s) floats, its lowest point %.2fm above where it stands"
			% [label, key, heights.x - stand])
	elif heights.x < stand - SINK_TOL:
		failures.append("ground: %s (%s) is sunk %.2fm under where it stands"
			% [label, key, stand - heights.x])


func _worst(gap: float) -> void:
	if absf(gap) > absf(float(stats["worst"])):
		stats["worst"] = snappedf(gap, 0.001)


# ------------------------------------------------------- on given ground

## Every building at its lot's platform, on its pad.
func _buildings(plan: VillagePlan, scene: Node3D) -> void:
	var parent := scene.get_node_or_null("Buildings")
	if parent == null:
		return
	var worst := 0.0
	var checked := 0
	for node in parent.get_children():
		var bi := _index_of(node)
		if bi < 0 or bi >= plan.buildings.size():
			continue
		var b: Dictionary = plan.buildings[bi]
		var li: int = int(b.get("lot", -1))
		if li < 0 or li >= plan.lots.size() or not plan.lots[li].has("ground_fit"):
			continue
		var fit: Dictionary = plan.lots[li]["ground_fit"]
		var platform: float = float(fit["platform_m"])
		var y: float = (node as Node3D).transform.origin.y
		checked += 1
		if absf(y - platform) > PLATFORM_TOL:
			failures.append("ground: %s stands at %.2f m, its platform is at %.2f m" % [node.name, y, platform])
			continue
		var req: BuildingRequest = b["request"]
		var w: float = maxf(req.width, 0.5)
		var l: float = maxf(req.length, 0.5)
		var g := VillageLotGround.ground_model({"fall_m": float(fit["fall_m"]),
			"downhill_deg": float(fit["downhill_deg"]), "width": w, "length": l})
		var xf: Transform3D = b["transform"]
		var bad := 0
		var off_by := 0.0
		for c in _ring(Rect2(Vector2(-w * 0.5, -l * 0.5), Vector2(w, l)).grow(-0.1), SEAM_STEP):
			var wp: Vector3 = xf * Vector3(c.x, 0.0, c.y)
			var have := _probe.top(Vector2(wp.x, wp.z))
			if is_nan(have):
				continue
			var want: float = platform + (g.ground_y(c) if g != null else 0.0)
			var d := have - want
			worst = maxf(worst, absf(d))
			if absf(d) > SEAM_TOL:
				bad += 1
				if absf(d) > absf(off_by):
					off_by = d
		if bad > 0:
			failures.append("ground: the ground under %s leaves its pad at %d points (by up to %.2f m)"
				% [node.name, bad, off_by])
	stats["buildings"] = checked
	stats["pad_worst"] = snappedf(worst, 0.001)


## Points every `step` metres round a rectangle.
static func _ring(r: Rect2, step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for e in range(4):
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var n := maxi(1, int(ceil(a.distance_to(b) / step)))
		for k in range(n):
			out.append(a.lerp(b, float(k) / float(n)))
	return out


## Along every lot's edge and every road's verge: closed and single.
func _seams(plan: VillagePlan) -> void:
	var edges: Array[PackedVector2Array] = []
	for lot in plan.lots:
		edges.append(lot["poly"])
	for road in plan.roads:
		edges.append(VillageSitePlanner.road_ribbon(road, true))
	var samples := 0
	var gaps := 0
	var overlaps := 0
	var worst_gap := 0.0
	var worst_layer := 0.0
	var steps := 0
	var first_gap := ""
	var first_overlap := ""
	for poly in edges:
		for e in range(poly.size()):
			var a: Vector2 = poly[e]
			var b: Vector2 = poly[(e + 1) % poly.size()]
			var len := a.distance_to(b)
			if len < 0.2:
				continue
			var n := Vector2(b.y - a.y, a.x - b.x) / len
			var count := maxi(1, int(round(len / SEAM_STEP)))
			for k in range(count):
				var p := a.lerp(b, (float(k) + 0.5) / float(count))
				var hi_side := _probe.top(p + n * 0.03)
				var lo_side := _probe.top(p - n * 0.03)
				if is_nan(hi_side) or is_nan(lo_side):
					continue
				samples += 1
				for q in [p + n * 0.03, p - n * 0.03]:
					var spread := _probe.spread(q)
					worst_layer = maxf(worst_layer, spread)
					if spread > SEAM_TOL:
						overlaps += 1
						if first_overlap.is_empty():
							first_overlap = "(%.1f, %.1f) %.2f m" % [q.x, q.y, spread]
				var top := maxf(hi_side, lo_side)
				var bottom := minf(hi_side, lo_side)
				if top - bottom <= SEAM_TOL:
					continue
				steps += 1
				var open := _probe.uncovered(p, bottom, top)
				worst_gap = maxf(worst_gap, open)
				if open > SEAM_TOL:
					gaps += 1
					if first_gap.is_empty():
						first_gap = "(%.1f, %.1f) %.2f m of a %.2f m step" % [p.x, p.y, open, top - bottom]
	stats["seam_samples"] = samples
	stats["seam_steps"] = steps
	stats["seam_gap_worst"] = snappedf(worst_gap, 0.001)
	stats["layer_worst"] = snappedf(worst_layer, 0.001)
	if gaps > 0:
		failures.append("ground: %d of %d seams between a pad, a road bed and the terrain are open by more than %.2f m (first at %s)"
			% [gaps, samples, SEAM_TOL, first_gap])
	if overlaps > 0:
		failures.append("ground: %d seam samples have two ground layers more than %.2f m apart (first at %s)"
			% [overlaps, SEAM_TOL, first_overlap])


## Every recorded terrace wall the mesh steps across has a terrace_wall
## component hosted by its lot.
func _terraces(plan: VillagePlan, scene: Node3D) -> void:
	var ground := scene.get_node_or_null("Ground")
	var rows: Array = ground.get_meta(&"components", []) if ground != null else []
	var walled := {}
	for row in rows:
		if String(row["role"]) == "terrace_wall":
			walled[String(row["host"])] = int(walled.get(String(row["host"]), 0)) + 1
	var recorded := 0
	var stepped := 0
	var named := 0
	var missing: Array[String] = []
	for li in range(plan.lots.size()):
		var lot: Dictionary = plan.lots[li]
		if not lot.has("ground_fit"):
			continue
		var walls: Array = lot["ground_fit"].get("terraces", [])
		recorded += walls.size()
		var steps := false
		for t in walls:
			var pts: PackedVector2Array = t["points"]
			for k in range(pts.size() - 1):
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[k + 1]
				var mid := (a + b) * 0.5
				var n := Vector2(b.y - a.y, a.x - b.x).normalized()
				var h1 := _probe.top(mid + n * 0.05)
				var h2 := _probe.top(mid - n * 0.05)
				if not is_nan(h1) and not is_nan(h2) and absf(h1 - h2) > 2.0 * SEAM_TOL:
					steps = true
		if not steps:
			continue
		stepped += 1
		if walled.has("lot%d" % li):
			named += 1
		else:
			missing.append("lot%d" % li)
	stats["terraces"] = recorded
	stats["terraced_lots"] = stepped
	stats["terrace_named"] = named
	stats["terrace_panels"] = 0
	for h in walled:
		stats["terrace_panels"] = int(stats["terrace_panels"]) + int(walled[h])
	if not missing.is_empty():
		failures.append("ground: %d terraced lots have no terrace_wall component: %s"
			% [missing.size(), ", ".join(missing.slice(0, 8))])


## The stairs (VTER-STEPS-NAV): every tread of a `steps` road its own regions
## hold, and every tread of a lot's access flight, is in the MESH at its level
## (within SEAM_TOL at its middle), its riser is at most STAIR_RISER_MAX, an
## inner tread of a stair street is at least STAIR_GOING_MIN deep, and each
## has its `stair_tread` component (host `road<i>`, `lot<i>_steps`).
const STAIR_RISER_MAX := 0.18
const STAIR_GOING_MIN := 0.28


func _stairs(plan: VillagePlan, scene: Node3D) -> void:
	var ground := scene.get_node_or_null("Ground")
	var rows: Array = ground.get_meta(&"components", []) if ground != null else []
	var named := {}
	for row in rows:
		if String(row["role"]) == "stair_tread":
			named[String(row["host"])] = int(named.get(String(row["host"]), 0)) + 1
	var surface := VillageGroundSurface.of(plan)
	var stairs := 0
	var treads := 0
	var worst := 0.0
	var riser_max := 0.0
	var going_min := INF
	var off: Array[String] = []
	var short: Array[String] = []
	var unnamed: Array[String] = []
	for i in range(plan.roads.size()):
		var bed: Dictionary = surface.road_bed(i)
		if not bed.has("treads"):
			continue
		stairs += 1
		var ts: Array = bed["treads"]
		var sv: PackedFloat32Array = bed["s"]
		var length: float = sv[sv.size() - 1]
		var owned := 0
		for k in range(ts.size()):
			var s0: float = maxf(float(ts[k]["s0"]), 0.0)
			var s1: float = minf(float(ts[k]["s1"]), length)
			if s1 - s0 < 0.02:
				continue
			var mid := surface.point_along(i, (s0 + s1) * 0.5)
			var ri := surface.region_at(mid)
			if ri >= surface.regions.size() or int(surface.regions[ri]["owner"]) != i \
					or int(surface.regions[ri].get("tread", -1)) != k:
				continue
			owned += 1
			treads += 1
			var top := _probe.top(mid)
			if not is_nan(top):
				worst = maxf(worst, absf(top - float(ts[k]["h"])))
				if absf(top - float(ts[k]["h"])) > SEAM_TOL and off.size() < 4:
					off.append("road%d tread %d at (%.1f, %.1f): mesh %.2f, tread %.2f" % [i, k, mid.x, mid.y, top, float(ts[k]["h"])])
			if k > 0:
				riser_max = maxf(riser_max, absf(float(ts[k]["h"]) - float(ts[k - 1]["h"])))
			# an inner tread: both its ends inside the stair
			if k > 0 and k < ts.size() - 1 and float(ts[k]["s0"]) > 0.0 and float(ts[k]["s1"]) < length:
				going_min = minf(going_min, s1 - s0)
				if s1 - s0 < STAIR_GOING_MIN and short.size() < 4:
					short.append("road%d tread %d %.2f m" % [i, k, s1 - s0])
		if owned > 0 and int(named.get("road%d" % i, 0)) < owned:
			unnamed.append("road%d (%d of %d)" % [i, int(named.get("road%d" % i, 0)), owned])
	for li in range(plan.lots.size()):
		var access: Dictionary = plan.lots[li].get("ground_fit", {}).get("access", {})
		var ts: Array = access.get("treads", [])
		if ts.is_empty():
			continue
		stairs += 1
		var below: float = (access["foot_m"] as Vector3).y
		for k in range(ts.size()):
			var poly: PackedVector2Array = ts[k]["poly"]
			var mid: Vector2 = (poly[0] + poly[1] + poly[2] + poly[3]) * 0.25
			var h: float = float(ts[k]["h"])
			treads += 1
			riser_max = maxf(riser_max, absf(h - below))
			below = h
			var top := _probe.top(mid)
			if not is_nan(top):
				worst = maxf(worst, absf(top - h))
				if absf(top - h) > SEAM_TOL and off.size() < 4:
					off.append("lot%d step %d: mesh %.2f, tread %.2f" % [li, k, top, h])
		if int(named.get("lot%d_steps" % li, 0)) < ts.size():
			unnamed.append("lot%d_steps (%d of %d)" % [li, int(named.get("lot%d_steps" % li, 0)), ts.size()])
	stats["stairs"] = stairs
	stats["stair_treads"] = treads
	stats["stair_mesh_worst"] = snappedf(worst, 0.001)
	stats["stair_riser_max"] = snappedf(riser_max, 0.001)
	stats["stair_going_min"] = snappedf(going_min, 0.001) if going_min < INF else 0.0
	if not off.is_empty():
		failures.append("stairs: the mesh is not at a tread's level: %s" % "; ".join(off))
	if riser_max > STAIR_RISER_MAX + 1e-3:
		failures.append("stairs: a riser of %.2f m (at most %.2f)" % [riser_max, STAIR_RISER_MAX])
	if not short.is_empty():
		failures.append("stairs: treads shallower than %.2f m: %s" % [STAIR_GOING_MIN, "; ".join(short)])
	if not unnamed.is_empty():
		failures.append("stairs: treads without their stair_tread component: %s" % ", ".join(unnamed))


## Inside natural water the ground is under the water's surface: a 2 m
## lattice over each water polygon (a bridge or a ford is timber or stone, not
## ground, and is not asked).
func _water(plan: VillagePlan) -> void:
	var samples := 0
	var pokes := 0
	var worst := 0.0
	var first := ""
	for w in plan.water:
		if w["kind"] == &"race":
			continue
		var poly: PackedVector2Array = w["poly"]
		var box := Poly.bounding_rect(poly)
		var y := box.position.y + 1.0
		while y < box.end.y:
			var x := box.position.x + 1.0
			while x < box.end.x:
				var p := Vector2(x, y)
				x += 2.0
				if not Geometry2D.is_point_in_polygon(p, poly):
					continue
				var top := _probe.top(p)
				var surface := _probe.water_top(p)
				if is_nan(top) or is_nan(surface):
					continue
				samples += 1
				worst = maxf(worst, top - surface)
				if top > surface + SEAM_TOL:
					pokes += 1
					if first.is_empty():
						first = "(%.1f, %.1f) %.2f m" % [p.x, p.y, top - surface]
			y += 2.0
	stats["water_samples"] = samples
	stats["water_worst"] = snappedf(worst, 0.001)
	if pokes > 0:
		failures.append("ground: %d of %d points inside the water have ground over its surface (first at %s)"
			% [pokes, samples, first])


## The transform from `node`'s frame to the scene root's, walked by hand: a
## checked scene need not be in a tree, so global_transform is not available.
static func _to_scene(node: Node3D, scene: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != scene:
		if at is Node3D:
			xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


static func _index_of(node: Node) -> int:
	var name := String(node.name)
	var cut := name.rfind("_")
	if cut < 0 or not name.substr(cut + 1).is_valid_int():
		return -1
	return int(name.substr(cut + 1))


static func _is_empty(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return false
	for c in node.get_children():
		if not _is_empty(c):
			return false
	return true


## The emitted ground, read back from the mesh: its upward triangles (what
## is stood on) and its vertical ones (the risers that close a step), each
## bucketed on a plan grid.
class GroundProbe:
	const CELL := 2.5
	var origin := Vector2.ZERO
	var nx := 1
	var ny := 1
	var tops: Array = []     # per cell: [Vector3, ...] in threes
	var risers: Array = []   # per cell: [Vector3, ...] in threes
	var water: Array = []    # per cell: the water's surface triangles

	static func of(mesh: ArrayMesh) -> GroundProbe:
		var g := GroundProbe.new()
		var box := mesh.get_aabb()
		g.origin = Vector2(box.position.x, box.position.z) - Vector2.ONE * CELL
		g.nx = maxi(1, int(ceil(box.size.x / CELL)) + 3)
		g.ny = maxi(1, int(ceil(box.size.z / CELL)) + 3)
		g.tops.resize(g.nx * g.ny)
		g.risers.resize(g.nx * g.ny)
		g.water.resize(g.nx * g.ny)
		for k in range(g.nx * g.ny):
			g.tops[k] = []
			g.risers[k] = []
			g.water[k] = []
		for s in range(mesh.get_surface_count()):
			var slot := int(mesh.surface_get_name(s).trim_prefix("material_slot:"))
			var is_water := slot == VillageBuilder.SURF_WATER
			if not slot in GROUND_SLOTS and not is_water:
				continue
			var arrays := mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			var order := PackedInt32Array()
			if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty():
				order = idx
			else:
				order.resize(vs.size())
				for k in range(vs.size()):
					order[k] = k
			for t in range(0, order.size() - 2, 3):
				var a := vs[order[t]]
				var b := vs[order[t + 1]]
				var c := vs[order[t + 2]]
				var n := (c - a).cross(b - a)
				if n.length_squared() < 1e-14:
					continue
				n = n.normalized()
				if is_water:
					if n.y > 0.2:
						g._put(g.water, a, b, c, 0.0)
				elif n.y > 0.2:
					g._put(g.tops, a, b, c, 0.0)
				elif absf(n.y) < 0.05:
					g._put(g.risers, a, b, c, 0.05)
		return g

	func _cell(p: Vector2) -> Vector2i:
		return Vector2i(clampi(int(floor((p.x - origin.x) / CELL)), 0, nx - 1),
			clampi(int(floor((p.y - origin.y) / CELL)), 0, ny - 1))

	func _put(into: Array, a: Vector3, b: Vector3, c: Vector3, grow: float) -> void:
		var lo := _cell(Vector2(minf(a.x, minf(b.x, c.x)) - grow, minf(a.z, minf(b.z, c.z)) - grow))
		var hi := _cell(Vector2(maxf(a.x, maxf(b.x, c.x)) + grow, maxf(a.z, maxf(b.z, c.z)) + grow))
		for j in range(lo.y, hi.y + 1):
			for i in range(lo.x, hi.x + 1):
				var list: Array = into[j * nx + i]
				list.append(a)
				list.append(b)
				list.append(c)

	## The heights of every upward ground triangle over a point.
	func heights(p: Vector2) -> Array[float]:
		var out: Array[float] = []
		var c := _cell(p)
		var list: Array = tops[c.y * nx + c.x]
		for k in range(0, list.size(), 3):
			var h := VillageGroundSurface.tri_height(list[k], list[k + 1], list[k + 2], p)
			if not is_nan(h):
				out.append(h)
		return out

	## The ground at a point: the highest upward triangle over it (NAN off it).
	func top(p: Vector2) -> float:
		var best := NAN
		for h in heights(p):
			if is_nan(best) or h > best:
				best = h
		return best

	## The water's surface over a point (NAN where there is none).
	func water_top(p: Vector2) -> float:
		var best := NAN
		var c := _cell(p)
		var list: Array = water[c.y * nx + c.x]
		for k in range(0, list.size(), 3):
			var h := VillageGroundSurface.tri_height(list[k], list[k + 1], list[k + 2], p)
			if not is_nan(h) and (is_nan(best) or h > best):
				best = h
		return best

	## How far apart the ground layers over a point lie: the least of three
	## readings a few millimetres apart, because a point ON an edge between
	## two triangles at different heights (a riser's top and foot) is held by
	## both and is not two layers.
	func spread(p: Vector2) -> float:
		var least := INF
		for d in [Vector2.ZERO, Vector2(0.007, 0.003), Vector2(-0.004, 0.008)]:
			var hs := heights(p + d)
			least = minf(least, 0.0 if hs.size() < 2 else hs.max() - hs.min())
		return least

	## The lowest ground under a footprint `radius` across its middle.
	func lowest(p: Vector2, radius: float) -> float:
		var h := top(p)
		if radius <= 0.01:
			return h
		for k in range(8):
			var a := TAU * float(k) / 8.0
			var q := top(p + Vector2(cos(a), sin(a)) * radius)
			if not is_nan(q):
				h = q if is_nan(h) else minf(h, q)
		return h

	## How much of the step from `bottom` to `top_y` at plan point p no
	## vertical triangle closes (the longest open stretch), in metres.
	func uncovered(p: Vector2, bottom: float, top_y: float) -> float:
		var spans: Array = []
		var c := _cell(p)
		var list: Array = risers[c.y * nx + c.x]
		for k in range(0, list.size(), 3):
			var span := _span_at(list[k], list[k + 1], list[k + 2], p)
			if span.x <= span.y:
				spans.append(span)
		spans.sort_custom(func(u: Vector2, v: Vector2) -> bool: return u.x < v.x)
		var reach := bottom
		var open := 0.0
		for s in spans:
			if s.x > reach:
				open = maxf(open, minf(s.x, top_y) - reach)
			reach = maxf(reach, s.y)
			if reach >= top_y:
				break
		if reach < top_y:
			open = maxf(open, top_y - reach)
		return open

	## The vertical extent of a vertical triangle over plan point p, or
	## (1, 0) when p is not within 4 cm of its plan line.
	static func _span_at(a: Vector3, b: Vector3, c: Vector3, p: Vector2) -> Vector2:
		var pts := [a, b, c]
		# the triangle's plan line: its two plan-farthest vertices
		var u0 := Vector2(a.x, a.z)
		var u1 := Vector2(b.x, b.z)
		var best := u0.distance_squared_to(u1)
		for pair in [[a, c], [b, c]]:
			var q0 := Vector2(pair[0].x, pair[0].z)
			var q1 := Vector2(pair[1].x, pair[1].z)
			if q0.distance_squared_to(q1) > best:
				best = q0.distance_squared_to(q1)
				u0 = q0
				u1 = q1
		if best < 1e-10:
			return Vector2(1, 0)
		var d := u1 - u0
		var t := (p - u0).dot(d) / d.length_squared()
		if t < -0.01 or t > 1.01:
			return Vector2(1, 0)
		if p.distance_to(u0 + d * t) > 0.04:
			return Vector2(1, 0)
		t = clampf(t, 0.0, 1.0)
		# the triangle in its own vertical plane: (s along the line, y)
		var lo := INF
		var hi := -INF
		for e in range(3):
			var v0: Vector3 = pts[e]
			var v1: Vector3 = pts[(e + 1) % 3]
			var s0 := (Vector2(v0.x, v0.z) - u0).dot(d) / d.length_squared()
			var s1 := (Vector2(v1.x, v1.z) - u0).dot(d) / d.length_squared()
			if absf(s1 - s0) < 1e-9:
				if absf(s0 - t) < 1e-4:
					lo = minf(lo, minf(v0.y, v1.y))
					hi = maxf(hi, maxf(v0.y, v1.y))
				continue
			var f := (t - s0) / (s1 - s0)
			if f < -1e-6 or f > 1.0 + 1e-6:
				continue
			var y := lerpf(v0.y, v1.y, clampf(f, 0.0, 1.0))
			lo = minf(lo, y)
			hi = maxf(hi, y)
		if lo > hi:
			return Vector2(1, 0)
		return Vector2(lo, hi)
