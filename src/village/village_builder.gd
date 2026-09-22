class_name VillageBuilder
extends MassBuilder
## Everything of a village that is MESH rather than model (VIL-018).
##
## The ground it stands on and the road surfaces on it; the water and the
## bridges over it; the hedge, palisade or wall round its edge and the gates
## through that; and the ten small props no art pack ships, emitted by
## `PropKit` -- the well on the common, the signpost and lamps at the gates,
## the haystacks behind the farms, the mill wheel in the race, the boats and
## drying racks on the strand.
##
## The split is the family split: this file emits geometry and never loads a
## model, and `VillageAssembler` is the only place a model is loaded. It is
## what lets the whole village harness run headless.
##
## Like `ChurchBuilder` and `CastleBuilder` it extends `MassBuilder`, so
## every mass it raises goes into `mass_log` and the checks measure what was
## actually emitted rather than what the plan asked for.

const SURF_GROUND := 0
const SURF_ROAD := 1
const SURF_COMMON := 2
const SURF_WATER := 3
const SURF_STONE := 4
const SURF_WOOD := 5
const SURF_ROOF := 6
const SURF_DARK := 7
const SURFACES := 8

## What each surface is, for the assembler's materials.
const COLOURS := {
	SURF_GROUND: "6f7a4a", SURF_ROAD: "8a7b62", SURF_COMMON: "5f8a3f",
	SURF_WATER: "3e6a8a", SURF_STONE: "8f8b82", SURF_WOOD: "6b5238",
	SURF_ROOF: "7a6340", SURF_DARK: "2a2622",
}

## How the ground is layered, so a road reads over the field and the common
## over both. Millimetres apart: enough to beat z-fighting, far too little to
## trip over.
const Y_GROUND := 0.005
const Y_ROAD := 0.02
const Y_COMMON := 0.03
const Y_WATER := 0.01

## §5's edge, by enclosure kind. A hedge is planted, not built, so it is the
## dresser's business and not this file's.
const WALL_HEIGHT := 3.6
const WALL_THICK := 0.9
const PALISADE_HEIGHT := 2.4
## A gate is this wide, and the enclosure is left open across it.
const GATE_WIDTH := 4.0
## A bridge deck is this much wider than the road it carries.
const BRIDGE_MARGIN := 0.8
const BRIDGE_RAIL := 0.5


func build(plan: VillagePlan) -> ArrayMesh:
	begin(SURFACES)
	if plan == null:
		return commit()
	tag("ground")
	_ground(plan)
	tag("water")
	_water(plan)
	tag("edge")
	_enclosure(plan)
	tag("props")
	_built_props(plan)
	return commit()


# ----------------------------------------------------------------- ground

## The site, the lots, the road surfaces and the commons, as flat layers. The
## site slab has real thickness so the mesh's own AABB is the ground a camera
## frames rather than a plane of zero height.
func _ground(plan: VillagePlan) -> void:
	var site: Rect2 = plan.site
	box(Vector3(site.size.x, 0.2, site.size.y),
		Vector3(site.get_center().x, -0.1, site.get_center().y), SURF_GROUND)
	_log_mass("ground", AABB(Vector3(site.position.x, -0.2, site.position.y),
		Vector3(site.size.x, 0.2, site.size.y)))
	for lot in plan.lots:
		_flat(lot["poly"], Y_GROUND, SURF_GROUND)
	for road in plan.roads:
		_flat(VillageSitePlanner.road_ribbon(road, true), Y_GROUND, SURF_GROUND)
		_flat(VillageSitePlanner.road_ribbon(road, false), Y_ROAD, SURF_ROAD)
	for c in plan.commons:
		_flat(c["poly"], Y_COMMON, SURF_COMMON)


## The water, and a bridge wherever a road crosses it. §9.2's `crossings`
## rule looks for a `bridge` mass whose centre is on the road's centreline,
## and this is where one comes from.
func _water(plan: VillagePlan) -> void:
	for w in plan.water:
		_flat(w["poly"], Y_WATER, SURF_WATER)
	var made := 0
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var pts: PackedVector2Array = road["points"]
		for w2 in plan.water:
			var crossings: Array[Vector2] = []
			for i in range(pts.size() - 1):
				var poly: PackedVector2Array = w2["poly"]
				var span: Variant = _water_span(pts[i], pts[i + 1], poly)
				if span == null:
					continue
				crossings.append(Vector2(span[0]))
				crossings.append(Vector2(span[1]))
			if crossings.size() < 2:
				continue
			var crossing_a := crossings[0]
			var crossing_b := crossings[0]
			for point in crossings:
				if _road_path_t(pts, point) < _road_path_t(pts, crossing_a): crossing_a = point
				if _road_path_t(pts, point) > _road_path_t(pts, crossing_b): crossing_b = point
			if w2.get("kind", &"river") == &"stream":
				_ford(crossing_a, crossing_b, float(road["width"]), made)
			else:
				_bridge(crossing_a, crossing_b, float(road["width"]), made)
			made += 1


## One bridge deck with its two rails, spanning a segment of road.
func _bridge(a: Vector2, b: Vector2, width: float, index: int) -> void:
	var run: Vector2 = b - a
	var length: float = run.length()
	if length < 0.5:
		return
	var mid: Vector2 = (a + b) * 0.5
	var yaw: float = atan2(-run.y, run.x)
	var deck: float = width + BRIDGE_MARGIN
	box(Vector3(length, 0.25, deck), Vector3(mid.x, 0.15, mid.y), SURF_WOOD, yaw)
	for side in [-1.0, 1.0]:
		var across: Vector2 = Vector2(-run.y, run.x).normalized() * (side * deck * 0.5)
		box(Vector3(length, BRIDGE_RAIL, 0.12),
			Vector3(mid.x + across.x, 0.15 + BRIDGE_RAIL * 0.5, mid.y + across.y),
			SURF_WOOD, yaw)
	_log_mass("bridge%d" % index,
		AABB(Vector3(mid.x - length * 0.5, 0.0, mid.y - deck * 0.5),
			Vector3(length, 0.25 + BRIDGE_RAIL, deck)))

func _ford(a: Vector2, b: Vector2, width: float, index: int) -> void:
	var run: Vector2 = b - a
	var length: float = maxf(run.length(), width)
	var mid := (a + b) * 0.5
	var yaw := atan2(-run.y, run.x)
	box(Vector3(length, 0.12, width + BRIDGE_MARGIN),
		Vector3(mid.x, 0.08, mid.y), SURF_STONE, yaw)
	_log_mass("ford%d" % index,
		AABB(Vector3(mid.x - length * 0.5, 0.0, mid.y - width * 0.5),
			Vector3(length, 0.12, width)))

func _water_span(a: Vector2, b: Vector2, poly: PackedVector2Array) -> Variant:
	var run := b - a
	var length_sq := maxf(run.length_squared(), 0.0001)
	var ts: Array[float] = []
	for p in [a, b]:
		if Poly.contains_point(poly, p):
			ts.append(clampf((p - a).dot(run) / length_sq, 0.0, 1.0))
	for i in range(poly.size()):
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b,
			poly[i], poly[(i + 1) % poly.size()])
		if hit != null:
			ts.append(clampf((Vector2(hit) - a).dot(run) / length_sq, 0.0, 1.0))
	if ts.size() < 2:
		return null
	ts.sort()
	return [a + run * ts[0], a + run * ts[ts.size() - 1]]


func _road_path_t(points: PackedVector2Array, point: Vector2) -> float:
	var travelled := 0.0
	var nearest_distance := INF
	var best_path := INF
	for i in range(points.size() - 1):
		var edge := points[i + 1] - points[i]
		var length := edge.length()
		var t := clampf((point - points[i]).dot(edge) / maxf(edge.length_squared(), 0.001), 0.0, 1.0)
		var distance := point.distance_to(points[i] + edge * t)
		if distance < nearest_distance:
			nearest_distance = distance
			best_path = travelled + length * t
		travelled += length
	return best_path


# ------------------------------------------------------------------- edge

## The edge of the settlement: a palisade of stakes or a wall of masonry,
## following `plan.enclosure`, left open at every gate. A `hedge` edge is
## planted rather than built and belongs to the dresser; `none` builds
## nothing, and the backs of the outer houses are the edge.
func _enclosure(plan: VillagePlan) -> void:
	var kind: StringName = plan.spec.enclosure
	var derived: Dictionary = VillageEnclosurePlan.build(plan)
	var edge: PackedVector2Array = plan.enclosure if plan.enclosure.size() >= 3 else derived["edge"]
	if not kind in [&"hedge", &"palisade", &"wall"] or edge.size() < 3:
		return
	var gates: Array[Vector2] = VillageMeasure.gates(plan)
	if gates.is_empty():
		for g in derived["gates"]:
			gates.append(g["pos"])
	var kit := PropKit.new(_kit, SURF_STONE, SURF_WOOD, SURF_ROOF, SURF_DARK)
	var n: int = edge.size()
	var made := 0
	for i in range(n):
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % n]
		for run in _minus_gates(a, b, gates):
			if kind == &"hedge":
				_hedge(run[0], run[1], made)
			elif kind == &"palisade":
				_log_mass("palisade%d" % made,
					kit.palisade(run[0], run[1], 0.0, PALISADE_HEIGHT))
			else:
				_wall(run[0], run[1], made)
			made += 1
	# and a gate in the gap
	for g in range(gates.size()):
		_log_mass("gate%d" % g, kit.fence_gate(Vector3(gates[g].x, 0.0, gates[g].y),
			0.0, GATE_WIDTH, PALISADE_HEIGHT * 0.8))

func _hedge(a: Vector2, b: Vector2, index: int) -> void:
	var run := b - a
	var length := run.length()
	if length < 0.5:
		return
	var mid := (a + b) * 0.5
	box(Vector3(length, 1.2, 0.8), Vector3(mid.x, 0.6, mid.y), SURF_COMMON,
		atan2(-run.y, run.x))
	_log_mass("hedge%d" % index,
		AABB(Vector3(mid.x - length * 0.5, 0.0, mid.y - 0.4), Vector3(length, 1.2, 0.8)))


## One run of masonry wall.
func _wall(a: Vector2, b: Vector2, index: int) -> void:
	var run: Vector2 = b - a
	var length: float = run.length()
	if length < 0.5:
		return
	var mid: Vector2 = (a + b) * 0.5
	box(Vector3(length, WALL_HEIGHT, WALL_THICK),
		Vector3(mid.x, WALL_HEIGHT * 0.5, mid.y), SURF_STONE, atan2(-run.y, run.x))
	_log_mass("wall%d" % index,
		AABB(Vector3(minf(a.x, b.x) - WALL_THICK, 0.0, minf(a.y, b.y) - WALL_THICK),
			Vector3(absf(run.x) + WALL_THICK * 2.0, WALL_HEIGHT,
				absf(run.y) + WALL_THICK * 2.0)))


## An edge segment cut into the pieces that are NOT a gateway. §9.2's `gates`
## rule wants roads to cross the edge only at gates and no other opening in
## it, so the openings have to be exactly the gates and nowhere else.
static func _minus_gates(a: Vector2, b: Vector2,
		gates: Array[Vector2]) -> Array:
	var length: float = a.distance_to(b)
	if length < 0.01:
		return []
	var dir: Vector2 = (b - a) / length
	var cuts: Array[Vector2] = []          # [from, to] along the run, in metres
	for g in gates:
		var t: float = (g - a).dot(dir)
		if t < -GATE_WIDTH or t > length + GATE_WIDTH:
			continue
		if (a + dir * t).distance_to(g) > GATE_WIDTH:
			continue
		cuts.append(Vector2(t - GATE_WIDTH * 0.5, t + GATE_WIDTH * 0.5))
	cuts.sort_custom(func(x, y) -> bool: return x.x < y.x)
	var out: Array = []
	var at := 0.0
	for cut in cuts:
		if cut.x - at > 0.5:
			out.append([a + dir * at, a + dir * cut.x])
		at = maxf(at, cut.y)
	if length - at > 0.5:
		out.append([a + dir * at, b])
	return out


# ------------------------------------------------------------------ props

## The ten `PropKit` props the plan asked for. A prop the dresser marked
## `built` names one of them; everything else is a catalogue model and the
## assembler's business.
func _built_props(plan: VillagePlan) -> void:
	var kit := PropKit.new(_kit, SURF_STONE, SURF_WOOD, SURF_ROOF, SURF_DARK)
	for i in range(plan.props.size()):
		var p: Dictionary = plan.props[i]
		if not bool(p.get("built", false)):
			continue
		var at := Vector3(float(p["pos"].x), 0.0, float(p["pos"].y))
		var yaw: float = float(p.get("yaw", 0.0))
		var box_of := AABB()
		match String(p["key"]):
			"well":
				box_of = kit.well(at, yaw)
			"signpost":
				box_of = kit.signpost(at, yaw)
			"lamp_post":
				box_of = kit.lamp_post(at, yaw)
			"haystack":
				box_of = kit.haystack(at)
			"boat":
				box_of = kit.boat(at, yaw)
			"drying_rack":
				box_of = kit.drying_rack(at, yaw)
			"mill_wheel":
				box_of = kit.mill_wheel(at, yaw)
			"adit":
				box_of = kit.adit(at, yaw)
			"fence_gate":
				box_of = kit.fence_gate(at, yaw)
			_:
				continue
		_log_mass("%s%d" % [String(p["key"]), i], box_of)
		total_height = maxf(total_height, box_of.position.y + box_of.size.y)


# -------------------------------------------------------------- internals

## A polygon as a flat double-sided sheet at height `y`. Double-sided because
## a village is looked at from above and from the road, and a one-sided
## ground plane disappears from underneath.
func _flat(poly: PackedVector2Array, y: float, surf: int) -> void:
	if poly.size() < 3:
		return
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	var st: SurfaceTool = _kit.surface(surf)
	for t in range(0, tris.size(), 3):
		var a := Vector3(poly[tris[t]].x, y, poly[tris[t]].y)
		var b := Vector3(poly[tris[t + 1]].x, y, poly[tris[t + 1]].y)
		var c := Vector3(poly[tris[t + 2]].x, y, poly[tris[t + 2]].y)
		for tri in [[a, b, c], [a, c, b]]:
			var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
			for v in tri:
				st.set_normal(n)
				st.set_uv(Vector2.ZERO)
				st.add_vertex(v)
