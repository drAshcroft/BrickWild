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
const SURF_BANK := 13  # the shelving bank, coloured per vertex from dry to wet
const SURF_BED := 14   # the river bed, seen through shallow water
const SURFACES := 15

## What each surface is, for the assembler's materials.
const COLOURS := {
	SURF_GROUND: "6a7447", SURF_ROAD: "a08d6b", SURF_COMMON: "7aa34a",
	SURF_WATER: "36607e", SURF_STONE: "8f8b82", SURF_WOOD: "6b5238",
	SURF_ROOF: "7a6340", SURF_DARK: "2a2622",
	SURF_YARD: "857649", SURF_VERGE: "6f8b45", SURF_WEAR: "8b7959",
	SURF_TREAD: "a38c64", SURF_FIELD: "86724a",
	SURF_BANK: "7a6a48", SURF_BED: "2f332f",
}

## A river with a bank (EVAL-B05). Natural water (everything but a mill race)
## lies below the land: its surface at WATER_LEVEL, a bank that shelves from
## BANK_CREST at BANK_WIDTH metres out down to the water's edge and on to the
## bed, which the water, a little clear at the margin, lets show through.
## The ground is cut away where the bank is, so the pit is real geometry.
const WATER_LEVEL := -0.14
const BANK_WIDTH := 2.6
const BANK_CREST := 0.004
const BED_LEVEL := -0.55
## How far under the water the bank keeps shelving before it is bed.
const BANK_SHELF := 2.4
const BANK_CELL := 0.6
## What the ground is cut back to: a little inside the bank's crest, so the
## bank sheet overlaps the land and never leaves a hairline.
const BANK_CUT := 2.3
const SKIRT := 0.08

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

## On given ground (VTER-GROUND-MESH): a terrace or retaining wall is this
## thick, its coping stands this far over the ground it holds, its footing
## this far under the ground in front of it, and its face this far proud of
## the riser it covers.
const TERRACE_THICK := 0.45
const TERRACE_COPING := 0.1
const TERRACE_FOOTING := 0.25
const TERRACE_PROUD := 0.02
## A stair's stone (VTER-STEPS-NAV): treads this thick, their tops this far
## over the stepped ground, risers this thick at each nosing.
const STAIR_TREAD_T := 0.08
const STAIR_PROUD := 0.02
const STAIR_RISER_T := 0.04
## The overlays draped on given ground, this far over it.
const DRAPE_TREAD := 0.012
const DRAPE_APPROACH := 0.015
## A run of edge on given ground is cut into pieces this long, each on its
## own ground.
const EDGE_PIECE := 3.0

## The finished ground when the plan has ground; null on a flat village, and
## then nothing below that reads it runs.
var _surface: VillageGroundSurface = null


func build(plan: VillagePlan) -> ArrayMesh:
	begin(SURFACES)
	if plan == null:
		return commit()
	_surface = VillageGroundSurface.of(plan)
	tag("ground")
	if _surface != null:
		_ground_on_terrain(plan)
	else:
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
	for surface in SURFACES:
		var before := mesh.get_surface_count()
		_kit.surface(surface).commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_name(before, "material_slot:%d" % surface)
	# a component's `surface` stays the LOGICAL slot, which is what the named
	# surfaces carry and what ComponentCheck looks up. It was the surface's
	# position in the mesh, which is the slot only when every slot before it is
	# present: a village without water has its stone at position 3, slot 4
	# (VTER-VISUAL-DOOR-ISLAND, Monpazier "components claim surface 3, mesh has 10").
	return mesh


# ----------------------------------------------------------------- ground

## The site, the lots, the road surfaces and the commons, as flat layers. The
## site slab has real thickness so the mesh's own AABB is the ground a camera
## frames rather than a plane of zero height.
func _ground(plan: VillagePlan) -> void:
	var site: Rect2 = plan.site
	var waters := natural_water(plan)
	if waters.is_empty():
		box(Vector3(site.size.x, 0.2, site.size.y),
			Vector3(site.get_center().x, -0.1, site.get_center().y), SURF_GROUND)
		_log_mass("ground", AABB(Vector3(site.position.x, -0.2, site.position.y),
			Vector3(site.size.x, 0.2, site.size.y)))
	else:
		# The slab is sunk to the river bed, walled round at the site's edge,
		# and the land is a sheet laid over it with the water and its bank cut out.
		box(Vector3(site.size.x, 0.2, site.size.y),
			Vector3(site.get_center().x, BED_LEVEL - 0.1, site.get_center().y), SURF_BED)
		var skirt_height := -BED_LEVEL - 0.003
		for side in [Rect2(site.position, Vector2(site.size.x, SKIRT)),
				Rect2(Vector2(site.position.x, site.end.y - SKIRT), Vector2(site.size.x, SKIRT)),
				Rect2(site.position, Vector2(SKIRT, site.size.y)),
				Rect2(Vector2(site.end.x - SKIRT, site.position.y), Vector2(SKIRT, site.size.y))]:
			box(Vector3(side.size.x, skirt_height, side.size.y),
				Vector3(side.get_center().x, -skirt_height * 0.5 - 0.003, side.get_center().y), SURF_GROUND)
		_log_mass("ground", AABB(Vector3(site.position.x, BED_LEVEL - 0.2, site.position.y),
			Vector3(site.size.x, 0.2 - BED_LEVEL, site.size.y)))
		for piece in _land_pieces(Poly.from_rect(site), _holes(waters, BANK_CUT)):
			_flat(piece, 0.0, SURF_GROUND)
	var dry := _holes(waters, BANK_WIDTH)
	for field in plan.fields:
		_field(plan, field)
	for i in plan.lots.size():
		_flat_clipped(plan.lots[i]["poly"], Y_YARD, SURF_YARD, dry, _lot_tint(plan, i))
	for road in plan.roads:
		_flat_clipped(VillageSitePlanner.road_ribbon(road, true), Y_VERGE, SURF_VERGE, dry)
		_flat(VillageSitePlanner.road_ribbon(road, false), Y_ROAD, SURF_ROAD)
		_flat(Poly.ribbon(road["points"], float(road["width"]) * 0.5 * WEAR_SHARE),
			Y_WEAR, SURF_WEAR)
	for c in plan.commons:
		_flat_clipped(c["poly"], Y_COMMON, SURF_COMMON, dry)
	_trodden(plan)


## Each lot is its own bit of worked ground: a small, deterministic shift in
## lightness and warmth, so a row of yards is not one stamped colour.
static func _lot_tint(plan: VillagePlan, index: int) -> Color:
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
	if _surface != null:
		_water_on_terrain(plan)
		return
	for w in plan.water:
		if w["kind"] == &"race":
			_flat(w["poly"], Y_WATER, SURF_WATER)
			_race_banks(plan, w)
		else:
			_flat(w["poly"], WATER_LEVEL, SURF_WATER)
			_bank(w["poly"])
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
	var measured := {}
	if _surface != null:
		if bridge:
			# on given ground the bridge is fitted to what the ground does
			# there (VTER-CROSSINGS): the deck over the higher landing and the
			# water under it, abutments on the earth at both ends
			measured = VillageBridge.measure(_surface, crossing)
			height = float(measured["deck_y"])
		else:
			# a ford is level with the higher of its landings
			height += maxf(_gy(points[0]), _gy(points[points.size() - 1]))
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
		var reach := 1.5 if bridge else 0.8
		if not measured.is_empty():
			reach = float(measured["ramp"][0 if end == 0 else 1])
		var far := near + direction * reach
		var ramp := PackedVector3Array()
		var top := height + depth * 0.5
		var foot := Y_ROAD
		if _surface != null:
			foot = _gy(far) + Y_ROAD
		for corner in [Vector3(near.x + across.x, top - 0.03, near.y + across.y),
			Vector3(far.x + across.x, foot, far.y + across.y),
			Vector3(far.x - across.x, foot, far.y - across.y),
			Vector3(near.x - across.x, top - 0.03, near.y - across.y)]:
			ramp.append(corner)
		var row := component_slab("crossing_ramp", ramp, 0.06, surface)
		bounds = bounds.merge(component_aabb(row))
	if not measured.is_empty():
		# the abutments: stone from the earth they stand on to the deck
		for a in measured["abutments"]:
			var at: Vector2 = a["pos"]
			var dir: Vector2 = a["dir"]
			var size: Vector3 = a["size"]
			var xf := Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)),
				Vector3(at.x, float(a["base_y"]) + size.y * 0.5, at.y))
			bounds = bounds.merge(component_aabb(component_box("bridge_abutment", size, xf, SURF_STONE)))
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
		var y := 0.08
		if _surface != null:
			y += _gy(mid)
		box(Vector3(0.12, 0.18, d.length()), Vector3(mid.x, y, mid.y),
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
	if _surface != null:
		_enclosure_on_terrain(plan, kind, edge, gates, kit)
		return
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
	# on given ground each post stands on its own ground and the lintel is
	# level over the higher of them
	var lift := 0.0
	if _surface != null:
		lift = maxf(_gy(at), maxf(_gy(at - tangent * (span * 0.5 + 0.2)), _gy(at + tangent * (span * 0.5 + 0.2))))
	host("gate%d" % index)
	for side in [-1.0, 1.0]:
		var centre: Vector2 = at + tangent * side * (span * 0.5 + 0.2)
		var post_xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(centre.x, height * 0.5, centre.y))
		var post_size := Vector3(0.4, height, 0.55)
		if _surface != null:
			var foot := _gy(centre)
			post_size.y = lift + height - foot
			post_xf.origin.y = (lift + height + foot) * 0.5
		var row := component_box("gate_post", post_size, post_xf, surface)
		bounds = component_aabb(row) if side < 0.0 else bounds.merge(component_aabb(row))
	var lintel := component_box("gate_lintel", Vector3(span + 0.95, 0.3, 0.6),
		Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, lift + height - 0.15, at.y)), SURF_WOOD)
	bounds = bounds.merge(component_aabb(lintel))
	# A contrasting cap makes the entrance legible above the hedge or stakes.
	var cap := component_box("gate_cap", Vector3(span + 1.2, 0.12, 0.8),
		Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, lift + height + 0.06, at.y)), SURF_ROOF)
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
		Transform3D(Basis(Vector3.UP, atan2(-run.y, run.x)), Vector3(mid.x, (height + 0.6) * 0.5 + _gy(mid), mid.y)), surface)
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
		at.y = float(p["elevation"]) if p.has("elevation") else ground_height(plan, p["pos"])
		if _surface != null and not p.has("elevation"):
			at.y = _surface.stand_height(p["pos"], prop_radius(p))
		var yaw: float = float(p.get("yaw", 0.0))
		var box_of := AABB()
		if p.has("approach"):
			if _surface != null:
				var over := {}
				_surface.drape(p["approach"], DRAPE_APPROACH, SURF_ROAD, over)
				_emit_tris(over)
			else:
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


# ------------------------------------------------------------------ banks

## The polygons of natural water: a river, a stream, a pond or the coast.
static func natural_water(plan: VillagePlan) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if plan == null:
		return out
	for w in plan.water:
		if w["kind"] != &"race":
			out.append(w["poly"])
	return out


## Signed distance to a polygon: positive outside, negative within.
static func signed_distance(poly: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in poly.size():
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(
			p, poly[i], poly[(i + 1) % poly.size()])))
	return -best if Poly.contains_point(poly, p) else best


## The height of the land at signed distance `d` from natural water's edge:
## the crest at BANK_WIDTH, the water level at the edge, the bed BANK_SHELF
## metres under the water. Smoothly shelving, so it shades as a slope.
static func bank_height(d: float) -> float:
	if d >= BANK_WIDTH:
		return BANK_CREST
	if d >= 0.0:
		return lerpf(WATER_LEVEL, BANK_CREST, smoothstep(0.0, 1.0, d / BANK_WIDTH))
	return lerpf(WATER_LEVEL, BED_LEVEL, smoothstep(0.0, 1.0, minf(-d / BANK_SHELF, 1.0)))


## Where the ground really is at a point, for whatever stands on it: the bank
## where there is water, level land everywhere else.
static func ground_height(plan: VillagePlan, p: Vector2) -> float:
	var surface := VillageGroundSurface.of(plan)
	if surface != null:
		return surface.ground_at(p)
	var h := 0.0
	var found := false
	for poly in natural_water(plan):
		if not Poly.bounding_rect(poly).grow(BANK_WIDTH).has_point(p):
			continue
		var d := signed_distance(poly, p)
		if d < BANK_WIDTH:
			h = minf(h, bank_height(d)) if found else bank_height(d)
			found = true
	return h


## The colour of the bank at signed distance `d`: ground at the crest, the
## earth of the slope, wet and dark at the water line, then pale shallows
## going to the dark of the bed.
static func bank_colour(d: float) -> Color:
	var ground := Color(String(COLOURS[SURF_GROUND]))
	var slope := Color("86775a")
	var wet := Color("4c4130")
	var sand := Color("a69d7c")
	var bed := Color("2b2f2c")
	if d >= BANK_WIDTH:
		return ground
	if d >= BANK_WIDTH * 0.45:
		return slope.lerp(ground, smoothstep(BANK_WIDTH * 0.45, BANK_WIDTH, d))
	if d >= 0.0:
		return wet.lerp(slope, smoothstep(0.0, BANK_WIDTH * 0.45, d))
	if d >= -0.5:
		return wet.lerp(sand, smoothstep(0.0, 1.0, -d / 0.5))
	return sand.lerp(bed, smoothstep(0.0, 1.0, (-d - 0.5) / (BANK_SHELF - 0.5)))


## Grow each water polygon by `by`, as the polygons of the pit.
static func _holes(waters: Array[PackedVector2Array], by: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly in waters:
		for grown in Geometry2D.offset_polygon(poly, by, Geometry2D.JOIN_ROUND):
			out.append(grown)
	return out


## `poly` with the holes cut from it, as polygons without holes: where a
## hole is wholly inside (a pond) the polygon is split down a vertical line
## through it first, so each half has a notch and no island.
static func _land_pieces(poly: PackedVector2Array, holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [poly]
	for hole in holes:
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			var cut := Geometry2D.clip_polygons(piece, hole)
			var islands := false
			for c in cut:
				islands = islands or Geometry2D.is_polygon_clockwise(c)
			if not islands:
				for c in cut:
					next.append(c)
				continue
			var box_of := Poly.bounding_rect(piece)
			var x_mid := Poly.bounding_rect(hole).get_center().x
			for half in [Rect2(box_of.position, Vector2(x_mid - box_of.position.x, box_of.size.y)),
					Rect2(Vector2(x_mid, box_of.position.y), Vector2(box_of.end.x - x_mid, box_of.size.y))]:
				for part in Geometry2D.intersect_polygons(piece, Poly.from_rect(half)):
					for c in Geometry2D.clip_polygons(part, hole):
						if not Geometry2D.is_polygon_clockwise(c):
							next.append(c)
		pieces = next
	return pieces


## A flat layer with the pit cut out of it.
func _flat_clipped(poly: PackedVector2Array, y: float, surf: int,
		holes: Array[PackedVector2Array], tint := Color(0, 0, 0, 0)) -> void:
	var pieces: Array = _land_pieces(poly, holes) if not holes.is_empty() else [poly]
	for piece in pieces:
		_flat(piece, y, surf, tint)


## The bank: a grid of the ground heights over the pit, coloured per vertex
## from `bank_colour`, with normals from the slope. Cells wholly deep under
## the water or wholly beyond the crest are left to the bed and the land.
func _bank(poly: PackedVector2Array) -> void:
	var area := Poly.bounding_rect(poly).grow(BANK_WIDTH + BANK_CELL)
	var nx := maxi(1, int(ceil(area.size.x / BANK_CELL)))
	var ny := maxi(1, int(ceil(area.size.y / BANK_CELL)))
	var sx := area.size.x / float(nx)
	var sy := area.size.y / float(ny)
	var dist := PackedFloat32Array()
	dist.resize((nx + 1) * (ny + 1))
	for j in ny + 1:
		for i in nx + 1:
			dist[j * (nx + 1) + i] = signed_distance(poly, area.position + Vector2(i * sx, j * sy))
	var st: SurfaceTool = _kit.surface(SURF_BANK)
	for j in ny:
		for i in nx:
			var ds := [dist[j * (nx + 1) + i], dist[j * (nx + 1) + i + 1],
				dist[(j + 1) * (nx + 1) + i + 1], dist[(j + 1) * (nx + 1) + i]]
			var lo := minf(minf(ds[0], ds[1]), minf(ds[2], ds[3]))
			var hi := maxf(maxf(ds[0], ds[1]), maxf(ds[2], ds[3]))
			if lo > BANK_WIDTH or hi < -BANK_SHELF:
				continue
			var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var verts: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var colours: Array[Color] = []
			for k in 4:
				var c: Vector2i = corners[k]
				var d: float = ds[k]
				verts.append(Vector3(area.position.x + c.x * sx, bank_height(d), area.position.y + c.y * sy))
				colours.append(bank_colour(d))
				# slope: finite difference of the height field across the cell
				var dx := bank_height(dist[c.y * (nx + 1) + mini(c.x + 1, nx)]) \
					- bank_height(dist[c.y * (nx + 1) + maxi(c.x - 1, 0)])
				var dz := bank_height(dist[mini(c.y + 1, ny) * (nx + 1) + c.x]) \
					- bank_height(dist[maxi(c.y - 1, 0) * (nx + 1) + c.x])
				normals.append(Vector3(-dx / (2.0 * sx), 1.0, -dz / (2.0 * sy)).normalized())
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = verts[tri[0]]
				var b: Vector3 = verts[tri[1]]
				var c3: Vector3 = verts[tri[2]]
				var order: Array = tri if (c3 - a).cross(b - a).y > 0.0 else [tri[0], tri[2], tri[1]]
				for k in order:
					st.set_normal(normals[k])
					st.set_color(colours[k])
					st.set_uv(Vector2.ZERO)
					st.add_vertex(verts[k])


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


# ---------------------------------------------------- on given ground

## The ground on given terrain (VTER-GROUND-MESH): VillageGroundSurface's
## partition -- lots on their platforms, roads on their beds, the natural
## ground carved by the water, risers wherever two of them meet at different
## heights -- then the trodden patches draped over it, and the walls that
## hold every riser over VillageLotGround.TERRACE_MIN as named components.
func _ground_on_terrain(plan: VillagePlan) -> void:
	_surface.build_mesh()
	_emit_tris(_surface.mesh_tris)
	var over := {}
	for p in plan.props:
		if String(p["key"]) == "well":
			_surface.drape(_disc(p["pos"], WELL_TREAD), DRAPE_TREAD, SURF_TREAD, over)
	for b in plan.buildings:
		var door: Vector3 = b.get("door", Vector3.INF)
		if door.is_finite():
			_surface.drape(_disc(Vector2(door.x, door.z), DOOR_TREAD), DRAPE_TREAD, SURF_TREAD, over)
	_emit_tris(over)
	_log_mass("ground", _surface.bounds())
	_terrace_walls(plan)
	_retaining_walls(plan)
	_stairs(plan)


## Triangles the surface laid out, per surface, into the kit.
func _emit_tris(tris: Dictionary) -> void:
	for surf in tris:
		var st: SurfaceTool = _kit.surface(int(surf))
		var vs: Array = tris[surf]["v"]
		var ns: Array = tris[surf]["n"]
		var cs: Array = tris[surf]["c"]
		for k in range(vs.size()):
			st.set_normal(ns[k])
			if not cs.is_empty():
				st.set_color(cs[k])
			st.set_uv(Vector2.ZERO)
			st.add_vertex(vs[k])


## The finished ground at a plan point (0 on a flat village).
func _gy(p: Vector2) -> float:
	return 0.0 if _surface == null else _surface.height_at(p)


## Half the larger side of what a prop covers on the ground: its recorded
## rect, else the catalogue's measured size.
static func prop_radius(p: Dictionary) -> float:
	var rect: Variant = p.get("rect")
	if rect is Rect2:
		return 0.5 * maxf((rect as Rect2).size.x, (rect as Rect2).size.y)
	var key := String(p.get("key", ""))
	if PropCatalog.known(key):
		var size: Vector3 = PropCatalog.size(key)
		return 0.5 * maxf(size.x, size.z) * float(p.get("scale", 1.0))
	return 0.0


## Every terrace wall the lot planner recorded (lots[i].ground_fit.terraces),
## host `lot<i>`, role `terrace_wall`: one panel per metre of its polyline,
## standing on the riser between the lot's platform and the ground beside it.
## A stretch where the two grounds meet (under a road bed) gets no panel.
func _terrace_walls(plan: VillagePlan) -> void:
	for li in range(plan.lots.size()):
		var lot: Dictionary = plan.lots[li]
		if not lot.has("ground_fit"):
			continue
		var walls: Array = lot["ground_fit"].get("terraces", [])
		if walls.is_empty():
			continue
		host("lot%d" % li)
		var poly: PackedVector2Array = lot["poly"]
		for t in walls:
			var pts: PackedVector2Array = t["points"]
			for k in range(pts.size() - 1):
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[k + 1]
				var n := Vector2(b.y - a.y, a.x - b.x).normalized()
				if Geometry2D.is_point_in_polygon((a + b) * 0.5 + n * 0.05, poly):
					n = -n # n points out of the lot
				# an access flight's edge is held by its own cheeks, and a
				# level way in is left open
				if _surface.kind_of(_surface.region_at((a + b) * 0.5 - n * 0.05)) == VillageGroundSurface.K_STAIR \
						or _in_gate(plan, (a + b) * 0.5) or _in_entry_flight(plan, (a + b) * 0.5):
					continue
				_wall_panel("terrace_wall", a, b, n)
		host_end()


## Whether plan point p stands on a house's entry flight (its landing or a
## tread): a terrace or road retaining wall panel there would stand across
## the way down from the door, a wall the walk cannot pass (VTER-VISUAL-DOOR-
## ISLAND, Monpazier c/b-003: three panels of road 0's retaining wall over the
## landing's front).
static func _in_entry_flight(plan: VillagePlan, p: Vector2) -> bool:
	for lot in plan.lots:
		for f in lot.get("ground_fit", {}).get("entry_flights", []):
			for t in f["treads"]:
				if Geometry2D.is_point_in_polygon(p, t["poly"]):
					return true
	return false


## The retaining walls of the road beds: along each road's verge, wherever
## its bed stands more than TERRACE_MIN over or under the ground beside it
## (and that ground is not another road's), host `road<i>`.
func _retaining_walls(plan: VillagePlan) -> void:
	for i in range(plan.roads.size()):
		var ribbon := VillageSitePlanner.road_ribbon(plan.roads[i], true)
		var opened := false
		for e in range(ribbon.size()):
			var a0: Vector2 = ribbon[e]
			var b0: Vector2 = ribbon[(e + 1) % ribbon.size()]
			var steps := maxi(1, int(ceil(a0.distance_to(b0) / 1.0)))
			var n := Vector2(b0.y - a0.y, a0.x - b0.x).normalized()
			if Geometry2D.is_point_in_polygon((a0 + b0) * 0.5 + n * 0.05, ribbon):
				n = -n
			for k in range(steps):
				var a := a0.lerp(b0, float(k) / float(steps))
				var b := a0.lerp(b0, float(k + 1) / float(steps))
				var mid := (a + b) * 0.5
				var mine := _surface.region_at(mid - n * 0.05)
				var there := _surface.region_at(mid + n * 0.05)
				if not _is_road_of(mine, i) or there <= mine or _surface.kind_of(there) in [
						VillageGroundSurface.K_WEAR, VillageGroundSurface.K_ROAD,
						VillageGroundSurface.K_VERGE, VillageGroundSurface.K_WATER,
						VillageGroundSurface.K_STAIR]:
					continue
				var step := maxf(absf(_surface.height_in(mine, a) - _surface.height_in(there, a)),
					absf(_surface.height_in(mine, b) - _surface.height_in(there, b)))
				if step <= VillageLotGround.TERRACE_MIN or _in_gate(plan, mid) or _in_entry_flight(plan, mid):
					continue
				if not opened:
					host("road%d" % i)
					opened = true
				_wall_panel("retaining_wall", a, b, n)
		if opened:
			host_end()


## The stairs on given ground (VTER-STEPS-NAV): on every tread of a `steps`
## road's bed (VillageGroundSurface.treads_of), a stone `stair_tread` across
## its carriageway, STAIR_PROUD over the ground, and a `stair_riser` at each
## nosing, host `road<i>`; on every access flight (VillageAccessSteps) the
## same, host `lot<i>_steps`, with a `stair_cheek` panel wherever a tread
## stands more than TERRACE_MIN off the ground beside it. Only treads the
## road's own regions hold are dressed: under a greater road's ribbon the
## bed is that road's.
func _stairs(plan: VillagePlan) -> void:
	for i in range(plan.roads.size()):
		var bed: Dictionary = _surface.road_bed(i)
		if not bed.has("treads"):
			continue
		var treads: Array = bed["treads"]
		var sv: PackedFloat32Array = bed["s"]
		var length: float = sv[sv.size() - 1]
		var width: float = float(plan.roads[i]["width"])
		var opened := false
		for k in range(treads.size()):
			var t: Dictionary = treads[k]
			var s0: float = maxf(float(t["s0"]), 0.0)
			var s1: float = minf(float(t["s1"]), length)
			if s1 - s0 < 0.02 or not _tread_owned(i, k, _surface.point_along(i, (s0 + s1) * 0.5)):
				continue
			if not opened:
				host("road%d" % i)
				opened = true
			var line := _surface.centre_between(i, s0, s1)
			for m in range(line.size() - 1):
				var a: Vector2 = line[m]
				var b: Vector2 = line[m + 1]
				if a.distance_to(b) < 0.01:
					continue
				_stair_box("stair_tread", a, b, width, float(t["h"]) - STAIR_TREAD_T, float(t["h"]) + STAIR_PROUD)
			if k == 0 or float(t["s0"]) <= 0.0:
				continue
			var at: Vector2 = _surface.point_along(i, float(t["s0"]))
			var dir: Vector2 = (_surface.point_along(i, float(t["s0"]) + 0.05) - at).normalized()
			if not _tread_owned(i, k - 1, at - dir * 0.05):
				continue
			var lo := minf(float(t["h"]), float(treads[k - 1]["h"]))
			var hi := maxf(float(t["h"]), float(treads[k - 1]["h"]))
			_stair_box("stair_riser", at - dir * STAIR_RISER_T * 0.5, at + dir * STAIR_RISER_T * 0.5, width,
				lo - STAIR_TREAD_T, hi + STAIR_PROUD - 0.005)
		if opened:
			host_end()
	for li in range(plan.lots.size()):
		var access: Dictionary = plan.lots[li].get("ground_fit", {}).get("access", {})
		var treads: Array = access.get("treads", [])
		if treads.is_empty():
			continue
		host("lot%d_steps" % li)
		var foot_h: float = (access["foot_m"] as Vector3).y
		var run: Vector2 = access["dir"]
		var origin: Vector2 = access["origin"]
		for k in range(treads.size()):
			var poly: PackedVector2Array = treads[k]["poly"]
			var h: float = float(treads[k]["h"])
			var c: Vector2 = origin + run * float(treads[k]["d"])
			var going: float = float(treads[k]["len"])
			var across: float = float(access.get("width_m", VillageAccessSteps.ACCESS_WIDTH))
			_stair_box("stair_tread", c - run * going * 0.5, c + run * going * 0.5, across,
				h - STAIR_TREAD_T, h + STAIR_PROUD)
			var below: float = foot_h if k == 0 else float(treads[k - 1]["h"])
			var nose: Vector2 = c - run * going * 0.5
			if absf(h - below) > 0.01:
				_stair_box("stair_riser", nose - run * STAIR_RISER_T * 0.5, nose + run * STAIR_RISER_T * 0.5, across,
					minf(h, below) - STAIR_TREAD_T, maxf(h, below) + STAIR_PROUD - 0.005)
			for e in range(4):
				var a: Vector2 = poly[e]
				var b: Vector2 = poly[(e + 1) % 4]
				var mid := (a + b) * 0.5
				var out := (mid - c).normalized()
				out = Vector2(b.y - a.y, a.x - b.x).normalized() * signf(Vector2(b.y - a.y, a.x - b.x).dot(out))
				var there := _surface.region_at(mid + out * 0.05)
				# no cheek on a road: a flight on a verge drops to its road open
				if _surface.kind_of(there) in [VillageGroundSurface.K_STAIR, VillageGroundSurface.K_WATER,
						VillageGroundSurface.K_WEAR, VillageGroundSurface.K_ROAD, VillageGroundSurface.K_VERGE]:
					continue
				var step := maxf(absf(h - _surface.height_in(there, a + out * 0.05)),
					absf(h - _surface.height_in(there, b + out * 0.05)))
				if step > VillageLotGround.TERRACE_MIN:
					_wall_panel("stair_cheek", a, b, out, true)
		host_end()


## Whether tread k of road i is the ground at p (not a greater road's).
func _tread_owned(i: int, k: int, p: Vector2) -> bool:
	var ri := _surface.region_at(p)
	if ri >= _surface.regions.size():
		return false
	var r: Dictionary = _surface.regions[ri]
	return int(r["owner"]) == i and int(r.get("tread", -1)) == k and int(r["kind"]) in [
		VillageGroundSurface.K_WEAR, VillageGroundSurface.K_ROAD, VillageGroundSurface.K_VERGE]


## A stone box on the line a-b, `across` wide, from `bottom` to `top`.
func _stair_box(role: String, a: Vector2, b: Vector2, across: float, bottom: float, top: float) -> void:
	var run := b - a
	var mid := (a + b) * 0.5
	component_box(role, Vector3(run.length(), top - bottom, across),
		Transform3D(Basis(Vector3.UP, atan2(-run.y, run.x)), Vector3(mid.x, (top + bottom) * 0.5, mid.y)), SURF_STONE)


## Whether plan point p is in a lot's level way in (VillageAccessSteps,
## layout "level"): its width, and a panel's half-length either side.
func _in_gate(plan: VillagePlan, p: Vector2) -> bool:
	for lot in plan.lots:
		var access: Dictionary = lot.get("ground_fit", {}).get("access", {})
		if access.get("layout", "") != "level":
			continue
		if p.distance_to(access["at"]) <= float(access["width_m"]) * 0.5 + 0.5:
			return true
	return false


func _is_road_of(ri: int, road: int) -> bool:
	if ri >= _surface.regions.size():
		return false
	var r: Dictionary = _surface.regions[ri]
	return int(r["owner"]) == road and int(r["kind"]) in [VillageGroundSurface.K_WEAR,
		VillageGroundSurface.K_ROAD, VillageGroundSurface.K_VERGE]


## One panel of wall on the line a-b, `out` the side away from what it
## bounds: from TERRACE_FOOTING under the lower ground to TERRACE_COPING over
## the higher, its body on the higher (held) side and its face TERRACE_PROUD
## in front of the riser. Nothing where the two grounds meet.
func _wall_panel(role: String, a: Vector2, b: Vector2, out: Vector2, body_out := false) -> void:
	var in_a := _surface.height_at(a - out * 0.03)
	var in_b := _surface.height_at(b - out * 0.03)
	var out_a := _surface.height_at(a + out * 0.03)
	var out_b := _surface.height_at(b + out * 0.03)
	if maxf(absf(in_a - out_a), absf(in_b - out_b)) < 0.05:
		return
	var high_side := -out if in_a + in_b >= out_a + out_b else out
	if body_out:
		# a stair's cheek stands beside the flight, never on its treads
		high_side = out
	var shift := high_side * (TERRACE_THICK * 0.5 - TERRACE_PROUD)
	var pa := a + shift
	var pb := b + shift
	var panel := PackedVector3Array([
		Vector3(pa.x, minf(in_a, out_a) - TERRACE_FOOTING, pa.y),
		Vector3(pb.x, minf(in_b, out_b) - TERRACE_FOOTING, pb.y),
		Vector3(pb.x, maxf(in_b, out_b) + TERRACE_COPING, pb.y),
		Vector3(pa.x, maxf(in_a, out_a) + TERRACE_COPING, pa.y)])
	component_slab(role, panel, TERRACE_THICK, SURF_STONE, false)


## Natural water on given ground: its sheet at its own surface (the level of
## ground water; the terrain less the flat depth for a river the spec drew),
## the bank already in the ground's partition; a mill race draped over the
## ground; the crossings on their landings.
func _water_on_terrain(plan: VillagePlan) -> void:
	var over := {}
	for wi in range(plan.water.size()):
		var w: Dictionary = plan.water[wi]
		if w["kind"] == &"race":
			_surface.drape(w["poly"], Y_WATER, SURF_WATER, over)
			_race_banks(plan, w)
			continue
		for sw in _surface.waters:
			if int(sw["index"]) == wi:
				_surface.water_sheet(sw, SURF_WATER, over)
	_emit_tris(over)
	for index in plan.water_crossings.size():
		if plan.water_crossings[index]["kind"] != &"boardwalk":
			_crossing(plan.water_crossings[index], index)
	# boardwalks on piles over the shallows (VTER-FORM-WATER)
	VillageBoardwalk.emit(self, plan)


## The edge on given ground: each run cut into EDGE_PIECE pieces, each piece
## standing on the lowest ground under it and as much taller as the ground
## under it rises; a gate's posts each on their own ground.
func _enclosure_on_terrain(plan: VillagePlan, kind: StringName, edge: PackedVector2Array,
		gates: Array[Dictionary], kit: PropKit) -> void:
	var n: int = edge.size()
	var made := 0
	for i in range(n):
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % n]
		for run in _keep_fraction(_minus_gates(a, b, gates), plan.enclosure_kept_fraction):
			for part in _water_edge_runs(plan, run[0], run[1]):
				if part["natural"]:
					continue
				var pa: Vector2 = part["a"]
				var pb: Vector2 = part["b"]
				if part["wet"]:
					_mill_culvert(pa, pb, made, kind)
					made += 1
					continue
				var pieces := maxi(1, int(ceil(pa.distance_to(pb) / EDGE_PIECE)))
				var bounds := AABB()
				var label := ("hedge%d" if kind == &"hedge" else ("palisade%d" if kind == &"palisade" else "wall%d")) % made
				for k in range(pieces):
					var qa := pa.lerp(pb, float(k) / float(pieces))
					var qb := pa.lerp(pb, float(k + 1) / float(pieces))
					var lo := minf(minf(_gy(qa), _gy(qb)), _gy((qa + qb) * 0.5))
					var hi := maxf(maxf(_gy(qa), _gy(qb)), _gy((qa + qb) * 0.5))
					var piece := AABB()
					if kind == &"hedge":
						piece = _edge_box("hedge_bank", label, qa, qb, lo - 0.1, hi + 0.45, 0.5, SURF_COMMON)
					elif kind == &"palisade":
						piece = kit.palisade(qa, qb, lo - 0.1, PALISADE_HEIGHT + (hi - lo) + 0.1)
					else:
						piece = _edge_box("enclosure_wall", label, qa, qb, lo - 0.3, hi + WALL_HEIGHT,
							WALL_THICK, SURF_STONE)
					bounds = piece if k == 0 else bounds.merge(piece)
				_log_mass(label, bounds)
				made += 1
	for g in gates.size():
		_gate(gates[g], g, kind)


func _edge_box(role: String, host_name: String, a: Vector2, b: Vector2, bottom: float, top: float,
		thick: float, surf: int) -> AABB:
	var run := b - a
	var mid := (a + b) * 0.5
	host(host_name)
	var row := component_box(role, Vector3(run.length(), top - bottom, thick),
		Transform3D(Basis(Vector3.UP, atan2(-run.y, run.x)), Vector3(mid.x, (top + bottom) * 0.5, mid.y)), surf)
	host_end()
	return component_aabb(row)
