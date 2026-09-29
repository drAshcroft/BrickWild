class_name VillageDressSpots
extends RefCounted
## Candidate locations for exterior dressing rules.

## in a fixed order; `_place` is what refuses the illegal ones.
static func spots_for(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		rng: RandomNumberGenerator, host: int, role: StringName,
		count: int) -> Array[Vector2]:
	match StringName(step["rule"]):
		&"wall":
			return _along_front(plan, host, count, 0.0)
		&"light":
			# ON the wall, not out in front of it. A shop's setback is
			# six-tenths of a metre, so the ground a `wall` step steps out
			# into is the road, and a lamp that wants ground has nowhere to
			# hang -- which is how a village came out unlit.
			return _along_front(plan, host, count, -0.4)
		&"verge":
			return _along_front(plan, host, count, _verge_offset(plan, host))
		&"yard":
			return _in_yard(plan, host, count, rng)
		&"corner":
			return _lot_corners(plan, host, count)
		&"row":
			return _row(plan, ctx, step, host, role, count)
		&"on":
			return _on_props(plan, host, count)
		&"centre":
			return _common_centre(plan, ctx, count)
		&"scatter":
			return scatter(ctx["common"], rng, count)
		&"ring":
			return _ring(plan, host, count)
		&"beside":
			return _beside_gates(plan, count)
		&"bank":
			if role == &"strand":
				return _strand_bank(plan, ctx)
			return _along_water(plan, rng, count)
		&"band":
			return _edge_band(plan, rng, count)
	return []


## Points along the building's own front. `front_dir` points OUT of the
## building, so `off` is measured away from its wall: 0 is against it and the
## lot's setback less a stride is out on the verge.
##
## Candidates step BOTH ways -- along the front either side of the door, and
## progressively further out from the wall -- because the near ones are often
## under the eaves. `bounds` covers the roof overhang and `front_mid` is on
## the walls, so a barrel a metre off the wall can still be inside the
## building as far as every check is concerned; without the outward steps
## most houses got no barrel at all.
static func _along_front(plan: VillagePlan, host: int, count: int,
		off: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var b: Dictionary = plan.buildings[host]
	var mid: Vector2 = VillageMeasure.front_mid(b)
	var dir: Vector2 = VillageMeasure.front_dir(b)
	var across := Vector2(-dir.y, dir.x)
	# A fixed spread of candidates, not `count` of them. Every `wall` step of
	# the same host is offered the same list, so a list only two long meant
	# the anvil and the barrel took both places and the smithy's own lamp had
	# nowhere left -- and a village with nothing lit is a village at night.
	for step_out in range(3):
		for k in range(VillageDressCatalog.FRONT_SPOTS):
			var side: float = 1.0 if k % 2 == 0 else -1.0
			var reach: float = 1.4 + float(k / 2) * 1.1
			out.append(mid + across * (side * reach)
				+ dir * (off + 0.8 + float(step_out) * 0.7))
	return out


## How far out the verge is: the lot's own setback, less a stride so the
## bench stands on the verge and not in the road.
static func _verge_offset(plan: VillagePlan, host: int) -> float:
	if host < 0:
		return 0.0
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return 0.0
	return maxf(float(plan.lots[lot].get("setback", 2.0)) - 1.6, 0.0)


## In the lot, behind the front line of the building: the yard.
static func _in_yard(plan: VillagePlan, host: int, count: int,
		rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return out
	var poly: PackedVector2Array = plan.lots[lot]["poly"]
	var b: Dictionary = plan.buildings[host]
	var behind: Vector2 = -VillageMeasure.front_dir(b)
	var bounds: PackedVector2Array = VillageMeasure.bounds_poly(b)
	var back: Vector2 = VillageMeasure.centre(bounds) + behind * 4.0
	for k in range(count * 3):
		var jitter := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		var p: Vector2 = back + jitter
		if Poly.contains_point(poly, p):
			out.append(p)
	return out


static func _lot_corners(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return out
	var poly: PackedVector2Array = plan.lots[lot]["poly"]
	var centre: Vector2 = VillageMeasure.centre(poly)
	for p in poly:
		if out.size() >= count:
			break
		out.append(Vector2(p).lerp(centre, 0.15))
	return out


## N copies along an axis at a pitch: the orchard behind a farm, the rows of
## stalls on the square.
static func _row(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		host: int, role: StringName, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var pitch: float = float(step.get("pitch", 4.0))
	if role == &"market":
		var common: PackedVector2Array = ctx["common"]
		if common.is_empty():
			return out
		var rect: Rect2 = Poly.bounding_rect(common)
		# rows along the square's longer axis, the aisle between them
		var along: Vector2 = Vector2(1, 0) if rect.size.x >= rect.size.y else Vector2(0, 1)
		var across := Vector2(-along.y, along.x)
		var mid: Vector2 = rect.get_center()
		var columns: int = maxi(3, int(ceil(float(count) / 2.0)))
		# Offer spare places at the ends so a well or bench cannot silently
		# reduce an earned market's eight stalls. Two rows leave an open aisle.
		# Keep side aisles as well as the central aisle. A full-width row
		# leaves no way round its end once cart footprints and a person's
		# radius are accounted for, stranding benches beyond the market.
		columns = mini(columns + 2, int(floor((maxf(rect.size.x, rect.size.y) - 4.0) / pitch)))
		for slot in range(columns):
			for row in range(2):
				out.append(mid + along * ((float(slot) - float(columns - 1) * 0.5) * pitch)
					+ across * ((float(row) - 0.5) * 8.0))
		return out
	if host < 0:
		return out
	var b: Dictionary = plan.buildings[host]
	var behind: Vector2 = -VillageMeasure.front_dir(b)
	var bounds := VillageMeasure.bounds_poly(b)
	var centre := VillageMeasure.centre(bounds)
	var reach := 0.0
	for point in bounds:
		reach = maxf(reach, (point - centre).dot(behind))
	var crown := 0.0
	for key in VillageDressRules.keys_for(ctx, step):
		crown = maxf(crown, PropCatalog.canopy(key))
	var start := centre + behind * (reach + crown + VillageDressCatalog.TRUNK_CLEAR)
	var across2 := Vector2(-behind.y, behind.x)
	for k in range(count):
		out.append(start + across2 * ((float(k) - float(count - 1) * 0.5) * pitch))
	return out


## On something that has a top: a stall, a cart, a bench already placed.
static func _on_props(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in plan.props:
		if out.size() >= count:
			break
		if PropCatalog.has_tag(String(p["key"]), PropCatalog.SURFACE):
			out.append(p["pos"])
	return out


static func _common_centre(plan: VillagePlan, ctx: Dictionary,
		count: int) -> Array[Vector2]:
	var common: PackedVector2Array = ctx["common"]
	if common.is_empty():
		return []
	var centre: Vector2 = VillageMeasure.centre(common)
	var bounds: Rect2 = Poly.bounding_rect(common)
	# The geometric centre can be occupied by a road ribbon on a bowed or
	# ringed street form.  Keep it as the first candidate, but offer measured
	# in-common fallbacks so the required well is not silently lost to that
	# incidental overlap.  `_apply` walks candidates until one is legal.
	var step_x: float = maxf(1.5, bounds.size.x * 0.28)
	var step_y: float = maxf(1.5, bounds.size.y * 0.28)
	var candidates: Array[Vector2] = [centre,
		centre + Vector2(step_x, 0.0), centre - Vector2(step_x, 0.0),
		centre + Vector2(0.0, step_y), centre - Vector2(0.0, step_y)]
	var out: Array[Vector2] = []
	for p in candidates:
		if Poly.contains_point(common, p):
			out.append(p)
	# Anything after the first stands off the middle, so the green tree does
	# not try to grow out of the well.  The common recipe normally asks for one
	# tree, but retaining a few measured candidates keeps optional trees from
	# consuming the well's fallback slot.
	for k in range(1, count):
		var p := centre + Vector2(VillageDressCatalog.GREEN_TREE_CLEAR + float(k), 0.0)
		if Poly.contains_point(common, p):
			out.append(p)
	return out


static func scatter(poly: PackedVector2Array, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if poly.is_empty():
		return out
	var rect: Rect2 = Poly.bounding_rect(poly)
	for k in range(count * 4):
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y))
		if Poly.contains_point(poly, p):
			out.append(p)
	return out


## Round the churchyard: the yews of Â§7, on a ring outside the church's own
## bounds.
static func _ring(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var bounds: PackedVector2Array = VillageMeasure.bounds_poly(plan.buildings[host])
	var rect: Rect2 = Poly.bounding_rect(bounds)
	var radius: float = maxf(rect.size.x, rect.size.y) * 0.5 + 3.0
	var centre: Vector2 = rect.get_center()
	for k in range(count):
		var a: float = TAU * float(k) / float(maxi(count, 1))
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out


static func _beside_gates(plan: VillagePlan, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g in VillageMeasure.gates(plan):
		for side in [1.0, -1.0]:
			if out.size() >= count * 2:
				break
			out.append(g + Vector2(0.0, side * 5.0))
	return out


static func _along_water(plan: VillagePlan, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w in plan.water:
		var poly: PackedVector2Array = w["poly"]
		var grown: PackedVector2Array = Poly.offset(poly, 1.5)
		for p in grown:
			if out.size() >= count * 2:
				break
			out.append(p)
	return out


## Boats belong beside reachable shore yards. Polygon corners alone put
## them beyond the last lot, with no ground a person could stand on.
static func _strand_bank(plan: VillagePlan, ctx: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var walk: WalkGrid = ctx["strand_walk"]
	for water in plan.water:
		if water["kind"] != &"coast":
			continue
		# The working strand includes rear yards within the documented
		# eighteen-metre bank reach, not only the water polygon's corners.
		for setback in [1.5, 3.5, 5.5, 7.5, 9.5, 11.5, 13.5, 15.5]:
			var bank := Poly.offset(water["poly"], setback)
			for edge in bank.size():
				var a: Vector2 = bank[edge]
				var b: Vector2 = bank[(edge + 1) % bank.size()]
				var steps := maxi(1, int(ceil(a.distance_to(b) / 2.0)))
				for i in range(steps):
					var point := a.lerp(b, (float(i) + 0.5) / steps)
					if walk.reached(Rect2(point, Vector2.ZERO), 8.0):
						out.append(point)
	return out


## A short, emitted working apron connects the shore to an actual reached
## yard. It never bridges water or crosses a building, tree or another prop.
static func strand_apron(plan: VillagePlan, ctx: Dictionary, rect: Rect2) -> PackedVector2Array:
	var walk: WalkGrid = ctx["strand_walk"]
	var options: Array[Dictionary] = []
	for lot in plan.lots:
		var poly: PackedVector2Array = lot["poly"]
		var centre := Poly.bounding_rect(poly).get_center()
		for edge in poly.size():
			var near := Geometry2D.get_closest_point_to_segment(rect.get_center(), poly[edge], poly[(edge + 1) % poly.size()])
			var anchor := near + (centre - near).normalized()
			var finish := Vector2(clampf(anchor.x, rect.position.x, rect.end.x),
				clampf(anchor.y, rect.position.y, rect.end.y))
			var distance := anchor.distance_to(finish)
			if distance > 8.0 or distance < 0.1 or not walk.reached(Rect2(anchor, Vector2.ZERO), 0.2):
				continue
			options.append({"anchor": anchor, "finish": finish, "distance": distance})
	options.sort_custom(func(a, b) -> bool: return float(a["distance"]) < float(b["distance"]))
	for option in options:
		var apron := Poly.ribbon(PackedVector2Array([option["anchor"], option["finish"]]), 1.0)
		var clear := true
		for point in apron:
			clear = clear and plan.site.has_point(point)
		for water in plan.water:
			clear = clear and VillageLotPlanner.overlap_area(apron, water["poly"]) <= VillageLotPlanner.AREA_EPS
		for bounds in ctx["bounds"]:
			clear = clear and VillageLotPlanner.overlap_area(apron, bounds) <= VillageLotPlanner.AREA_EPS
		for prop in plan.props:
			clear = clear and VillageLotPlanner.overlap_area(apron, Poly.from_rect(prop["rect"])) <= VillageLotPlanner.AREA_EPS
		for plant in plan.plants:
			var trunk := float(plant.get("trunk", 0.0))
			if trunk <= 0.0 or not PropCatalog.blocks_floor(String(plant["key"])):
				continue
			clear = clear and VillageMeasure.point_to_poly(plant["pos"], apron) > trunk + 0.1
		if clear:
			return apron
	return PackedVector2Array()


## The band outside the enclosure, or just inside the site edge when there is
## no enclosure: where the village is bounded by something.
static func _edge_band(plan: VillagePlan, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var band: float = float(VillageDressCatalog.EDGE_BAND.get(plan.spec.enclosure, 4.0))
	var site: Rect2 = plan.site
	var inner: Rect2 = site.grow(-band - 1.0)
	var want: int = count
	if plan.spec.purpose == &"forest":
		want = int(float(count) * VillageDressCatalog.FOREST_DENSITY)
	# WALKED along the edge at a pitch, not scattered near it. Â§9.6 walks the
	# same perimeter and refuses a run longer than twenty-five metres with
	# nothing within six of it; scattering `want` trees over a site hundreds
	# of metres round left a hundred and fourteen metres of it bare.
	#
	# `want` is a floor, not a cap: the band is as long as the village is
	# round, and the recipe's count says how densely, not how many.
	var ring: PackedVector2Array = Poly.from_rect(site.grow(-0.5))
	if plan.spec.enclosure != &"none":
		var derived: Dictionary = VillageEnclosurePlan.build(plan)
		var derived_edge: PackedVector2Array = derived["edge"]
		if derived_edge.size() >= 3:
			ring = derived_edge
	var perimeter: float = Poly.polyline_length(ring) + ring[0].distance_to(ring[ring.size() - 1])
	var pitch: float = VillageDressCatalog.EDGE_PITCH
	if plan.spec.purpose == &"forest":
		pitch *= 0.5
	var steps: int = maxi(int(perimeter / pitch), want)
	var n: int = ring.size()
	for k in range(steps):
		var t: float = float(k) / float(steps) * float(n)
		var seg: int = int(t) % n
		var a: Vector2 = ring[seg]
		var b: Vector2 = ring[(seg + 1) % n]
		var along: Vector2 = a.lerp(b, t - floorf(t))
		# a little way in from the boundary, and jittered so a planted edge
		# does not read as a fence of trees
		var inward: Vector2 = (site.get_center() - along).normalized()
		var depth: float = rng.randf_range(0.5, maxf(band, 1.5))
		var jitter := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
		var p: Vector2 = along + inward * depth + jitter
		if plan.spec.form == &"strand" and not site.has_point(p):
			# A long shore site gives the inward vector little depth near its
			# far corners. Jitter must not discard several clear edge stations
			# in a row. Offer the same inner band; normal plant checks still
			# reject roads, roofs, water and occupied ground there.
			p = VillageDressRules.inside_edge(site, p, 1.5)
		if inner.has_point(p) or not site.has_point(p):
			continue          # inside the village, not at its edge
		out.append(p)
	return out

