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
## The ground is more than one ground (EVAL-B05). Slots 0-7 keep their
## numbers because the crossing checks name slots 4 and 5.
const SURF_YARD := 8   # lots and yards: worked earth and grass, tinted per lot
const SURF_VERGE := 9  # the grass shoulder along a road
const SURF_WEAR := 10  # the darker line down a road where the carts run
const SURF_TREAD := 11 # bare trodden earth round the well and at each door
const SURF_FIELD := 12 # ploughland outside the edge
const SURFACES := 13

## What each surface is, for the assembler's materials.
const COLOURS := {
	SURF_GROUND: "6a7447", SURF_ROAD: "a08d6b", SURF_COMMON: "7aa34a",
	SURF_WATER: "3e6a8a", SURF_STONE: "8f8b82", SURF_WOOD: "6b5238",
	SURF_ROOF: "7a6340", SURF_DARK: "2a2622",
	SURF_YARD: "857649", SURF_VERGE: "6f8b45", SURF_WEAR: "8b7959",
	SURF_TREAD: "a38c64", SURF_FIELD: "86724a",
}

## How the ground is layered, so a road reads over the field and the common
## over both. Millimetres apart: enough to beat z-fighting, far too little to
## trip over.
const Y_GROUND := 0.005
const Y_FIELD := 0.006
const Y_YARD := 0.008
const Y_VERGE := 0.012
const Y_ROAD := 0.02
const Y_WEAR := 0.025
const Y_COMMON := 0.03
const Y_TREAD := 0.034
const Y_WATER := 0.01
## How wide the worn centre line is, as a share of the road, and the bare
## patches: round the well, and at each door.
const WEAR_SHARE := 0.38
const WELL_TREAD := 2.4
const DOOR_TREAD := 1.2

## §5's edge, by enclosure kind. A hedge is planted, not built, so it is the
## dresser's business and not this file's.
const WALL_HEIGHT := 3.6
const WALL_THICK := 0.9
const PALISADE_HEIGHT := 2.4
## A gate is this wide, and the enclosure is left open across it.
const GATE_WIDTH := 4.0
## A bridge deck is this much wider than the road it carries.
const BRIDGE_MARGIN := 0.8
const BRIDGE_RAIL := 0.9


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


## Godot omits empty streams. A village without a common, water or stone
## must still colour its remaining streams by their authored material slot.
func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var slots := {}
	for surface in SURFACES:
		var before := mesh.get_surface_count()
		_kit.surface(surface).commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_name(before, "material_slot:%d" % surface)
			slots[surface] = before
	for row in component_log:
		row["surface"] = slots.get(int(row["surface"]), -1)
	return mesh


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
	for field in plan.fields:
		_field(plan, field)
	for i in plan.lots.size():
		_flat(plan.lots[i]["poly"], Y_YARD, SURF_YARD, _lot_tint(plan, i))
	for road in plan.roads:
		_flat(VillageSitePlanner.road_ribbon(road, true), Y_VERGE, SURF_VERGE)
		_flat(VillageSitePlanner.road_ribbon(road, false), Y_ROAD, SURF_ROAD)
		_flat(Poly.ribbon(road["points"], float(road["width"]) * 0.5 * WEAR_SHARE),
			Y_WEAR, SURF_WEAR)
	for c in plan.commons:
		_flat(c["poly"], Y_COMMON, SURF_COMMON)
	_trodden(plan)


## Each lot is its own bit of worked ground: a small, deterministic shift in
## lightness and warmth, so a row of yards is not one stamped colour.
func _lot_tint(plan: VillagePlan, index: int) -> Color:
	var h := fposmod(sin(float(index) * 12.9898 + float(plan.spec.seed) * 0.0137) * 43758.5453, 1.0)
	var k := fposmod(sin(float(index) * 78.233 + float(plan.spec.seed) * 0.0291) * 24634.6345, 1.0)
	var light := 0.90 + h * 0.18
	return Color(light * (1.0 + (k - 0.5) * 0.10), light, light * (1.0 - (k - 0.5) * 0.10))


## Ploughland and pasture, which the plan holds and the ground never drew. A
## field that touches water is left as the plain ground: the bank is the
## water's business.
func _field(plan: VillagePlan, field: Dictionary) -> void:
	var poly: PackedVector2Array = field["poly"]
	for w in plan.water:
		if not Geometry2D.intersect_polygons(poly, w["poly"]).is_empty():
			return
	var surf := SURF_FIELD if field.get("kind", &"field") == &"field" else SURF_VERGE
	_flat(poly, Y_FIELD, surf)


## The well and each door wear the grass through to earth.
func _trodden(plan: VillagePlan) -> void:
	for p in plan.props:
		if String(p["key"]) == "well":
			_flat(_disc(p["pos"], WELL_TREAD), Y_TREAD, SURF_TREAD)
	for b in plan.buildings:
		var door: Vector3 = b.get("door", Vector3.INF)
		if door.is_finite():
			_flat(_disc(Vector2(door.x, door.z), DOOR_TREAD), Y_TREAD, SURF_TREAD)


static func _disc(centre: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		out.append(centre + Vector2(cos(a), sin(a)) * radius * (1.0 + 0.12 * sin(float(i) * 2.3)))
	return out


## Emit the final, serialized crossing routes. Each bend shares its mitered
## edge with the next deck panel, so neither holes nor shortcut chords appear.
func _water(plan: VillagePlan) -> void:
	for w in plan.water:
		_flat(w["poly"], Y_WATER, SURF_WATER)
		if w["kind"] == &"race":
			_race_banks(plan, w)
	for index in plan.water_crossings.size():
		_crossing(plan.water_crossings[index], index)


func _crossing(crossing: Dictionary, index: int) -> void:
	var points: PackedVector2Array = crossing["points"]
	if points.size() < 2:
		return
	var bridge: bool = crossing["kind"] == &"bridge"
	var name := "%s%d" % [crossing["kind"], index]
	var ribbon := Poly.ribbon(points, (float(crossing["width"]) + BRIDGE_MARGIN) * 0.5)
	var height := 0.15 if bridge else 0.08
	var depth := 0.25 if bridge else 0.12
	var surface := SURF_WOOD if bridge else SURF_STONE
	host(name)
	var bounds := AABB()
	var first := true
	for i in range(points.size() - 1):
		var panel := PackedVector3Array()
		for vertex in [ribbon[i], ribbon[i + 1], ribbon[ribbon.size() - 2 - i], ribbon[ribbon.size() - 1 - i]]:
			panel.append(Vector3(vertex.x, height, vertex.y))
		var row := component_slab("crossing_deck", panel, depth, surface)
		var emitted := component_aabb(row)
		bounds = emitted if first else bounds.merge(emitted)
		first = false
		if bridge:
			# Fine board joints and repeated uprights give the bridge a readable
			# timber scale; all dressing remains outside the road's clear width.
			var centre_run := points[i + 1] - points[i]
			var board_count := maxi(1, int(ceil(centre_run.length() / 0.55)))
			for board in range(1, board_count):
				var t := float(board) / float(board_count)
				var left := ribbon[i].lerp(ribbon[i + 1], t)
				var right := ribbon[ribbon.size() - 1 - i].lerp(ribbon[ribbon.size() - 2 - i], t)
				var across := right - left
				var middle := (left + right) * 0.5
				var joint := Transform3D(Basis(Vector3.UP, atan2(-across.y, across.x)),
					Vector3(middle.x, height + depth * 0.5 + 0.001, middle.y))
				var detail := component_box("bridge_board_joint", Vector3(across.length(), 0.002, 0.014), joint, SURF_DARK)
				bounds = bounds.merge(component_aabb(detail))
			for side in [0, 1]:
				var a := ribbon[i] if side == 0 else ribbon[ribbon.size() - 1 - i]
				var b := ribbon[i + 1] if side == 0 else ribbon[ribbon.size() - 2 - i]
				var run := b - a
				var centre := (a + b) * 0.5
				var rail_top := height + depth * 0.5 + BRIDGE_RAIL
				var xf := Transform3D(Basis(Vector3.UP, atan2(-run.y, run.x)),
					Vector3(centre.x, rail_top - 0.06, centre.y))
				var rail := component_box("bridge_rail", Vector3(run.length(), 0.12, 0.14), xf, SURF_WOOD)
				bounds = bounds.merge(component_aabb(rail))
				xf.origin.y -= 0.4
				component_box("bridge_midrail", Vector3(run.length(), 0.08, 0.10), xf, SURF_WOOD)
				var posts := maxi(1, int(ceil(run.length() / 1.8)))
				for post in range(posts + 1):
					if post == 0 and i > 0:
						continue # adjacent panels share their corner post
					var at := a.lerp(b, float(post) / float(posts))
					var upright := Transform3D(Basis.IDENTITY, Vector3(at.x, rail_top - BRIDGE_RAIL * 0.5, at.y))
					var pillar := component_box("bridge_post", Vector3(0.18, BRIDGE_RAIL + 0.08, 0.18), upright, SURF_WOOD)
					bounds = bounds.merge(component_aabb(pillar))
	# Shallow ramps join the raised deck to the road on either bank.
	for end in [0, points.size() - 1]:
		var inside: int = 1 if end == 0 else points.size() - 2
		var direction := (points[end] - points[inside]).normalized()
		var across := Vector2(-direction.y, direction.x) * (float(crossing["width"]) + BRIDGE_MARGIN) * 0.5
		var near := points[end]
		var far := near + direction * (1.5 if bridge else 0.8)
		var ramp := PackedVector3Array()
		var top := height + depth * 0.5
		for corner in [Vector3(near.x + across.x, top - 0.03, near.y + across.y),
			Vector3(far.x + across.x, Y_ROAD, far.y + across.y),
			Vector3(far.x - across.x, Y_ROAD, far.y - across.y),
			Vector3(near.x - across.x, top - 0.03, near.y - across.y)]:
			ramp.append(corner)
		var row := component_slab("crossing_ramp", ramp, 0.06, surface)
		bounds = bounds.merge(component_aabb(row))
	_log_mass(name, bounds)
	host_end()


## Low timber retaining edges make the working channel readable at street
## height. The mouth in natural water remains open, rather than a closed dam.
func _race_banks(plan: VillagePlan, race: Dictionary) -> void:
	var poly: PackedVector2Array = race["poly"]
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var mid := (a + b) * 0.5
		var mouth := false
		for water in plan.water:
			if water["kind"] != &"race" and Poly.contains_point(water["poly"], mid):
				mouth = true
		if mouth:
			continue
		var d := b - a
		box(Vector3(0.12, 0.18, d.length()), Vector3(mid.x, 0.08, mid.y),
			SURF_WOOD, atan2(d.x, d.y))


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
	var gates: Array[Dictionary] = plan.gate_crossings if plan.enclosure.size() >= 3 else derived["gates"]
	var kit := PropKit.new(_kit, SURF_STONE, SURF_WOOD, SURF_ROOF, SURF_DARK)
	var n: int = edge.size()
	var made := 0
	for i in range(n):
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % n]
		for run in _keep_fraction(_minus_gates(a, b, gates), plan.enclosure_kept_fraction):
			for part in _water_edge_runs(plan, run[0], run[1]):
				if part["natural"]:
					continue # The water itself is the boundary; never dam a river or coast.
				elif part["wet"]:
					_mill_culvert(part["a"], part["b"], made, kind)
				elif kind == &"hedge":
					_hedge(part["a"], part["b"], made)
				elif kind == &"palisade":
					_log_mass("palisade%d" % made,
						kit.palisade(part["a"], part["b"], 0.0, PALISADE_HEIGHT))
				else:
					var along: Vector2 = (part["b"] - part["a"]).normalized()
					var inside := Vector2(-along.y, along.x)
					if not Poly.contains_point(edge, (part["a"] + part["b"]) * 0.5 + inside * 0.1):
						inside = -inside
					_wall(part["a"], part["b"], made, inside)
				made += 1
	# An open portal, aligned to the actual boundary. A closed fence panel
	# across this gap would visually and physically undo the road opening.
	for g in gates.size():
		_gate(gates[g], g, kind)


## Retain a centered share of each side after real gate openings have been
## cut. This gives fractional walls actual gaps and keeps the fraction stable
## if a road adds or removes a gate.
static func _keep_fraction(runs: Array, fraction: float) -> Array:
	var out: Array = []
	var keep: float = clampf(fraction, 0.0, 1.0)
	if keep <= 0.0:
		return out
	for run in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var margin: float = (1.0 - keep) * 0.5
		out.append([a.lerp(b, margin), a.lerp(b, 1.0 - margin)])
	return out


func _gate(gate: Dictionary, index: int, kind: StringName) -> void:
	var at: Vector2 = gate["pos"]
	var tangent: Vector2 = gate.get("tangent", Vector2.RIGHT)
	var span := float(gate.get("opening", GATE_WIDTH))
	var main: bool = gate.get("kind", &"gate") == &"gate"
	var height := 3.8 if main else 2.8
	var surface := SURF_STONE if kind == &"wall" else SURF_WOOD
	var yaw := atan2(-tangent.y, tangent.x)
	var bounds := AABB()
	host("gate%d" % index)
	for side in [-1.0, 1.0]:
		var centre: Vector2 = at + tangent * side * (span * 0.5 + 0.2)
		var row := component_box("gate_post", Vector3(0.4, height, 0.55),
			Transform3D(Basis(Vector3.UP, yaw), Vector3(centre.x, height * 0.5, centre.y)), surface)
		bounds = component_aabb(row) if side < 0.0 else bounds.merge(component_aabb(row))
	var lintel := component_box("gate_lintel", Vector3(span + 0.95, 0.3, 0.6),
		Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, height - 0.15, at.y)), SURF_WOOD)
	bounds = bounds.merge(component_aabb(lintel))
	# A contrasting cap makes the entrance legible above the hedge or stakes.
	var cap := component_box("gate_cap", Vector3(span + 1.2, 0.12, 0.8),
		Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, height + 0.06, at.y)), SURF_ROOF)
	bounds = bounds.merge(component_aabb(cap))
	_log_mass("gate%d" % index, bounds)
	total_height = maxf(total_height, bounds.end.y)


static func _water_edge_runs(plan: VillagePlan, a: Vector2, b: Vector2) -> Array:
	var length := a.distance_to(b)
	var direction := (b - a).normalized()
	var cuts: Array[float] = [0.0, length]
	var waters: Array[PackedVector2Array] = []
	var natural: Array[PackedVector2Array] = []
	for water in plan.water:
		var poly := Poly.offset(water["poly"], WALL_THICK * 0.5 + 0.1)
		waters.append(poly)
		if water["kind"] != &"race":
			natural.append(poly)
		for i in poly.size():
			var hit = Geometry2D.segment_intersects_segment(a, b, poly[i], poly[(i + 1) % poly.size()])
			if hit != null:
				cuts.append((Vector2(hit) - a).dot(direction))
	cuts.sort()
	var out: Array = []
	for i in range(cuts.size() - 1):
		if cuts[i + 1] - cuts[i] < 0.001:
			continue
		var mid := a + direction * (cuts[i] + cuts[i + 1]) * 0.5
		var wet := waters.any(func(poly: PackedVector2Array) -> bool: return Poly.contains_point(poly, mid))
		var shore := natural.any(func(poly: PackedVector2Array) -> bool: return Poly.contains_point(poly, mid))
		out.append({"a": a + direction * cuts[i], "b": a + direction * cuts[i + 1], "wet": wet, "natural": shore})
	return out


## A small hydraulic opening preserves the wall above it. It is not a road
## gateway, and the hedge simply stops either side of the working channel.
func _mill_culvert(a: Vector2, b: Vector2, index: int, kind: StringName) -> void:
	if kind == &"hedge":
		return
	var height := WALL_HEIGHT if kind == &"wall" else PALISADE_HEIGHT
	var run := b - a
	var mid := (a + b) * 0.5
	var surface := SURF_STONE if kind == &"wall" else SURF_WOOD
	var row := component_box("mill_culvert", Vector3(run.length(), height - 0.6, WALL_THICK),
		Transform3D(Basis(Vector3.UP, atan2(-run.y, run.x)), Vector3(mid.x, (height + 0.6) * 0.5, mid.y)), surface)
	_log_mass("mill_culvert%d" % index, component_aabb(row))

func _hedge(a: Vector2, b: Vector2, index: int) -> void:
	var run := b - a
	var length := run.length()
	if length < 0.5:
		return
	var mid := (a + b) * 0.5
	host("hedge%d" % index)
	var row := component_box("hedge_bank", Vector3(length, 0.45, 0.5),
		Transform3D(Basis(Vector3.UP, atan2(-run.y, run.x)), Vector3(mid.x, 0.225, mid.y)), SURF_COMMON)
	_log_mass("hedge%d" % index, component_aabb(row))


## One run of masonry wall.
func _wall(a: Vector2, b: Vector2, index: int, inside: Vector2) -> void:
	var run: Vector2 = b - a
	var length: float = run.length()
	if length < 0.5:
		return
	var mid: Vector2 = (a + b) * 0.5
	var yaw := atan2(-run.y, run.x)
	host("wall%d" % index)
	var wall := component_box("enclosure_wall", Vector3(length, WALL_HEIGHT, WALL_THICK),
		Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, WALL_HEIGHT * 0.5, mid.y)), SURF_STONE)
	_log_mass("wall%d" % index, component_aabb(wall))
	# A real guard walk with a grounded stair. Leave three metres at each
	# entrance so an oblique road never clips the inward-projecting platform.
	if length < 12.0:
		return
	var direction := run / length
	var top := 2.6
	var stair_run := 3.9
	var start := a + direction * 3.0 + inside * 1.0
	for step in 13:
		var height := top * float(step + 1) / 13.0
		var at := start + direction * (float(step) + 0.5) * 0.3
		component_box("wallwalk_stair", Vector3(0.3, height, 1.3),
			Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, height * 0.5, at.y)), SURF_STONE)
	var walk_length := length - 6.0 - stair_run
	var centre := start + direction * (stair_run + walk_length * 0.5)
	component_box("wallwalk_deck", Vector3(walk_length, 0.24, 1.4),
		Transform3D(Basis(Vector3.UP, yaw), Vector3(centre.x, top - 0.12, centre.y)), SURF_WOOD)
	var posts := maxi(1, int(ceil(walk_length / 2.4)))
	for post in range(posts + 1):
		var at := start + direction * (stair_run + walk_length * float(post) / float(posts)) + inside * 0.7
		component_box("wallwalk_post", Vector3(0.16, top + 0.9, 0.16),
			Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, (top + 0.9) * 0.5, at.y)), SURF_WOOD)
	centre += inside * 0.7
	component_box("wallwalk_rail", Vector3(walk_length + 0.16, 0.12, 0.12),
		Transform3D(Basis(Vector3.UP, yaw), Vector3(centre.x, top + 0.84, centre.y)), SURF_WOOD)


## An edge segment cut into the pieces that are NOT a gateway. §9.2's `gates`
## rule wants roads to cross the edge only at gates and no other opening in
## it, so the openings have to be exactly the gates and nowhere else.
static func _minus_gates(a: Vector2, b: Vector2,
		gates: Array[Dictionary]) -> Array:
	var length := a.distance_to(b)
	if length < 0.01:
		return []
	var direction := (b - a) / length
	var cuts: Array[float] = [0.0, length]
	var openings: Array[PackedVector2Array] = []
	for g in gates:
		var point: Vector2 = g["pos"]
		var forward: Vector2 = g.get("direction", Vector2.DOWN)
		var reach := maxf(float(g.get("opening", GATE_WIDTH)), 4.0) + WALL_THICK
		var poly := Poly.ribbon(PackedVector2Array([point - forward * reach, point + forward * reach]),
			float(g.get("width", GATE_WIDTH)) * 0.5 + WALL_THICK * 0.5)
		openings.append(poly)
		for i in poly.size():
			var hit = Geometry2D.segment_intersects_segment(a, b, poly[i], poly[(i + 1) % poly.size()])
			if hit != null:
				cuts.append(clampf((Vector2(hit) - a).dot(direction), 0.0, length))
	cuts.sort()
	var out: Array = []
	for i in range(cuts.size() - 1):
		if cuts[i + 1] - cuts[i] < 0.01:
			continue
		var mid := a + direction * (cuts[i] + cuts[i + 1]) * 0.5
		if openings.any(func(poly): return Poly.contains_point(poly, mid)):
			continue
		out.append([a + direction * cuts[i], a + direction * cuts[i + 1]])
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
		at.y = float(p.get("elevation", 0.0))
		var yaw: float = float(p.get("yaw", 0.0))
		var box_of := AABB()
		if p.has("approach"):
			_flat(p["approach"], 0.035, SURF_ROAD)
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
				box_of = kit.mill_wheel(at, yaw, float(p.get("radius", 1.8)))
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
func _flat(poly: PackedVector2Array, y: float, surf: int, tint := Color(0, 0, 0, 0)) -> void:
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
				if tint.a > 0.0:
					st.set_color(tint)
				st.set_uv(Vector2.ZERO)
				st.add_vertex(v)
