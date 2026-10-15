class_name VillageGarden
extends RefCounted
## The garden village (`VillageSpec.garden`): a compact display planted the way
## a painter of cottages plants one -- flowers on every open metre, beds along
## every house front and both verges of every path, flowering shrubs and the
## odd tree in the gaps, lamp posts down the paths, and a pond or two dug in
## the leftover ground with the water host's banks round them.
##
## It is planting, not planning. The compact layout is finished before this
## runs and nothing here reads back into it: buildings, lots, roads and the
## common are exactly what they are at `garden == 0`. Every piece goes through
## `VillageDressPlacement.place`, so it is held to the same trunk, canopy,
## door and road tests `DressCheck` re-derives -- a garden that does not fit
## is simply a smaller garden.
##
## Deterministic, and isolated: each pass draws from its own RNG named from
## the spec's seed, and `garden == 0` never reaches any of them, so the
## default plan is byte-identical to the plan before this file existed.

## Ponds: the water is a wobbled ellipse whose every vertex keeps POND_BANK
## of open bank to the nearest lot, road verge, building or the common, so the
## water host's rocks, bank plants and reeds have somewhere to stand.
const POND_BANK := 1.2
const POND_MIN := 1.6          ## the narrower half-axis, at least
const POND_MAX := 6.5          ## the longer half-axis, at most
const POND_ASPECT := 2.6       ## how much longer than wide a pond may run
const POND_SPACING := 6.0      ## open ground between two ponds' banks
const POND_REACH := 9.0        ## how far past the buildings a pond may lie
const POND_SIDES := 22

## Planting, all in metres.
const BED_PITCH := 0.85        ## along a house front or a path verge
const LAMP_PITCH_MIN := 7.0    ## lamp spacing along a path at garden 1.0...
const LAMP_PITCH_MAX := 15.0   ## ...and at the faintest garden
const LAMP_SPACING := 4.5      ## no two lamps closer, across roads too
const LAMP_SLIDES: Array[float] = [0.0, 1.2, -1.2, 2.4, -2.4]
const SCATTER_DENSE := 1.05    ## scatter pitch at garden 1.0...
const SCATTER_SPARSE := 2.4    ## ...and at the faintest garden
const SCATTER_REACH := 3.5     ## the planted display ends this far past the buildings


static func active(spec: VillageSpec) -> bool:
	return spec != null and spec.compact_display and spec.garden > 0.0


# ------------------------------------------------------------------ ponds

## Dig the garden's ponds into `plan.water`, replacing any an earlier dressing
## of the same plan dug. Runs before the hosts, so the `water` and `reeds`
## places dress their banks like any other water.
static func dig_ponds(plan: VillagePlan) -> void:
	for i in range(plan.water.size() - 1, -1, -1):
		if bool(plan.water[i].get("garden", false)):
			plan.water.remove_at(i)
	if not active(plan.spec):
		return
	var wanted: int = 1 if plan.spec.garden < 0.5 else 2
	var blockers := _pond_blockers(plan)
	var boxes: Array[Rect2] = []
	for poly in blockers:
		boxes.append(Poly.bounding_rect(poly))
	var region := _occupied(plan).grow(POND_REACH).intersection(plan.site.grow(-1.0))
	var cap := POND_MAX + POND_BANK
	var scored: Array = []
	var z: float = region.position.y + 0.5
	while z < region.end.y:
		var x: float = region.position.x + 0.5
		while x < region.end.x:
			var p := Vector2(x, z)
			var clear := _clearance(p, blockers, boxes, cap, region)
			if clear - POND_BANK >= POND_MIN:
				scored.append([clear, p])
			x += 1.0
		z += 1.0
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(a[0], b[0]):
			return a[0] > b[0]
		if not is_equal_approx(a[1].y, b[1].y):
			return a[1].y < b[1].y
		return a[1].x < b[1].x)
	var dug: Array[Dictionary] = []
	for row in scored:
		if dug.size() >= wanted:
			break
		var centre: Vector2 = row[1]
		var narrow: float = minf(float(row[0]) - POND_BANK, POND_MAX / POND_ASPECT * 1.4)
		var best := {}
		for long_x in [true, false]:
			var fit := _fit_pond(centre, narrow, long_x, blockers, boxes, region)
			if fit.is_empty():
				continue
			if best.is_empty() or float(fit["area"]) > float(best["area"]):
				best = fit
		if best.is_empty():
			continue
		var apart := true
		for other in dug:
			var reach: float = float(best["long"]) + float(other["long"]) + POND_BANK * 2.0 + POND_SPACING
			if centre.distance_to(other["centre"]) < reach:
				apart = false
				break
		if not apart:
			continue
		best["centre"] = centre
		dug.append(best)
	for k in range(dug.size()):
		var fit: Dictionary = dug[k]
		var rng := VillageDressPlacement.rng(plan, "garden|pond|%d" % k)
		var poly := PackedVector2Array()
		var centre: Vector2 = fit["centre"]
		var phase := rng.randf_range(0.0, TAU)
		for i in range(POND_SIDES):
			var a: float = TAU * float(i) / float(POND_SIDES)
			# the wobble only ever pulls the shore IN, so the measured bank holds
			var wobble: float = 0.86 + 0.07 * (1.0 + sin(a * 3.0 + phase)) * rng.randf_range(0.6, 1.0)
			var rx: float = float(fit["rx"]) * wobble
			var rz: float = float(fit["rz"]) * wobble
			poly.append(Vector2(snappedf(centre.x + cos(a) * rx, 0.001),
				snappedf(centre.y + sin(a) * rz, 0.001)))
		plan.water.append({"poly": poly, "kind": &"pond", "garden": true})


## Everything a pond keeps its bank clear of: every lot (and so every yard),
## every road with its verge, every building's architecture and the common.
static func _pond_blockers(plan: VillagePlan) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for lot in plan.lots:
		out.append(lot["poly"])
	for road in plan.roads:
		out.append(VillageSitePlanner.road_ribbon(road, true))
	for c in plan.commons:
		out.append(c["poly"])
	for b in plan.buildings:
		out.append(VillageMeasure.bounds_poly(b))
		for yard in VillageMeasure.yard_polys(b):
			out.append(yard)
	if plan.landmark_site.has("poly"):
		out.append(plan.landmark_site["poly"])
	for w in plan.water:
		out.append(w["poly"])
	return out


## Distance from `p` to the nearest blocker or the region's edge, capped.
static func _clearance(p: Vector2, blockers: Array[PackedVector2Array], boxes: Array[Rect2],
		cap: float, region: Rect2) -> float:
	var clear: float = minf(cap, minf(minf(p.x - region.position.x, region.end.x - p.x),
		minf(p.y - region.position.y, region.end.y - p.y)))
	if clear <= 0.0:
		return 0.0
	for k in range(blockers.size()):
		if not boxes[k].grow(clear).has_point(p):
			continue
		if Poly.contains_point(blockers[k], p):
			return 0.0
		clear = minf(clear, VillageMeasure.point_to_poly(p, blockers[k]))
	return clear


## The largest ellipse about `centre` whose shore keeps POND_BANK clear, its
## long axis along X or Z. Empty when not even the minimum pond fits.
static func _fit_pond(centre: Vector2, narrow: float, long_x: bool,
		blockers: Array[PackedVector2Array], boxes: Array[Rect2], region: Rect2) -> Dictionary:
	var long_r: float = minf(POND_MAX, narrow * POND_ASPECT)
	while long_r >= narrow - 0.001:
		var rx: float = long_r if long_x else narrow
		var rz: float = narrow if long_x else long_r
		if _ellipse_clear(centre, rx, rz, blockers, boxes, region):
			return {"rx": rx, "rz": rz, "long": long_r, "area": rx * rz}
		long_r -= 0.25
	return {}


static func _ellipse_clear(centre: Vector2, rx: float, rz: float,
		blockers: Array[PackedVector2Array], boxes: Array[Rect2], region: Rect2) -> bool:
	for i in range(POND_SIDES * 2):
		var a: float = TAU * float(i) / float(POND_SIDES * 2)
		var p := centre + Vector2(cos(a) * rx, sin(a) * rz)
		if _clearance(p, blockers, boxes, POND_BANK + 0.01, region) < POND_BANK:
			return false
	return true


# ---------------------------------------------------------------- planting

## The garden itself. Runs after every host has dressed, so the well, the
## benches and the bank dressing of the ponds keep the ground they took.
static func plant(plan: VillagePlan, ctx: Dictionary) -> void:
	if not active(plan.spec):
		return
	_lamps(plan, ctx)
	_front_beds(plan, ctx)
	_verges(plan, ctx)
	_pond_borders(plan, ctx)
	_scatter(plan, ctx)


## Lamp posts down every road, alternating sides at a pitch the garden sets,
## just off the verge. The catalogue's `lamp_post`, built like a gate's.
static func _lamps(plan: VillagePlan, ctx: Dictionary) -> void:
	var g: float = plan.spec.garden
	var pitch: float = lerpf(LAMP_PITCH_MAX, LAMP_PITCH_MIN, g)
	var size: Vector2 = VillageDressCatalog.BUILT["lamp_post"]["size"]
	var rng := VillageDressPlacement.rng(plan, "garden|lamps")
	var lamps: Array[Vector2] = []
	for road in plan.roads:
		var points: PackedVector2Array = road["points"]
		var off: float = float(road["width"]) * 0.5 + float(road["verge"]) \
			+ VillageDressCatalog.ROAD_CLEAR + size.x * 0.5 + 0.1
		var walked := 0.0
		var next := pitch * 0.5
		var side := 1.0
		for k in range(points.size() - 1):
			var a: Vector2 = points[k]
			var b: Vector2 = points[k + 1]
			var span: float = a.distance_to(b)
			if span < 0.01:
				continue
			var along: Vector2 = (b - a) / span
			var normal := Vector2(-along.y, along.x)
			while next <= walked + span:
				var station: Vector2 = a + along * (next - walked)
				var first_side := side
				side = -side
				next += pitch
				# A compact street runs close past its houses: a station that
				# lands on a porch slides along the road, then tries the far side.
				for s in [first_side, -first_side]:
					var placed := false
					for slide in LAMP_SLIDES:
						var at: Vector2 = station + along * float(slide) + normal * float(s) * off
						var spaced := true
						for other in lamps:
							if at.distance_to(other) < LAMP_SPACING:
								spaced = false
								break
						if not spaced:
							continue
						var step := {"built": true, "yaw": PropCatalog.yaw_facing(-normal * float(s))}
						if VillageDressPlacement.place(plan, ctx, step, "lamp_post", at, rng, -1):
							lamps.append(at)
							placed = true
							break
					if placed:
						break
			walked += span


## Beds along each building's front, either side of the door (the door's own
## swing stays clear by the placement rules), and at a fuller garden along its
## sides as well, with a second row behind the first.
static func _front_beds(plan: VillagePlan, ctx: Dictionary) -> void:
	var g: float = plan.spec.garden
	var keys: Array[String] = VillageDressRules.palette_keys(ctx, "garden")
	if keys.is_empty():
		return
	var small := _small_first(keys)
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var rng := VillageDressPlacement.rng(plan, "garden|beds|%d" % i)
		var poly: PackedVector2Array = VillageMeasure.bounds_poly(b)
		var front: Vector2 = VillageMeasure.front_dir(b)
		var centre: Vector2 = VillageMeasure.centre(poly)
		for e in range(poly.size()):
			var a: Vector2 = poly[e]
			var c: Vector2 = poly[(e + 1) % poly.size()]
			var run: float = a.distance_to(c)
			if run < 0.5:
				continue
			var normal := Vector2(-(c - a).y, (c - a).x).normalized()
			if normal.dot((a + c) * 0.5 - centre) < 0.0:
				normal = -normal
			var facing: float = normal.dot(front)
			var rows := 0
			if facing > 0.7:
				rows = 2 if g >= 0.5 else 1
			elif facing > -0.7 and g >= 0.35:
				rows = 1
			for r in range(rows):
				var n: int = int(run / BED_PITCH)
				for k in range(n):
					var t: float = (float(k) + 0.5 + float(r) * 0.5) / float(n)
					if t >= 1.0:
						continue
					var key: String = small[rng.randi() % small.size()] if r == 0 \
						else keys[rng.randi() % keys.size()]
					var off: float = VillageDressCatalog.TRUNK_CLEAR + PropCatalog.trunk(key) + 0.06 \
						+ float(r) * 0.75
					_flower(plan, ctx, key, a.lerp(c, t) + normal * off, rng)


## Both verges of every road and path, edged with flowers.
static func _verges(plan: VillagePlan, ctx: Dictionary) -> void:
	var keys: Array[String] = VillageDressRules.palette_keys(ctx, "garden")
	if keys.is_empty():
		return
	var small := _small_first(keys)
	var step_m: float = lerpf(BED_PITCH * 2.2, BED_PITCH, plan.spec.garden)
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var rng := VillageDressPlacement.rng(plan, "garden|verge|%d" % r)
		var points: PackedVector2Array = road["points"]
		var edge: float = float(road["width"]) * 0.5 + float(road["verge"]) \
			+ VillageDressPlacement.BED_ROAD_CLEAR
		for k in range(points.size() - 1):
			var a: Vector2 = points[k]
			var b: Vector2 = points[k + 1]
			var span: float = a.distance_to(b)
			if span < 0.01:
				continue
			var along: Vector2 = (b - a) / span
			var normal := Vector2(-along.y, along.x)
			var n: int = int(span / step_m)
			for i in range(n):
				var on: Vector2 = a + along * ((float(i) + 0.5) * span / float(maxi(n, 1)))
				for side in [1.0, -1.0]:
					var key: String = small[rng.randi() % small.size()]
					var at: Vector2 = on + normal * float(side) * (edge + PropCatalog.trunk(key) + 0.04)
					_flower(plan, ctx, key, at, rng)


## A ring of flowers round each garden pond, outside the bank the water host
## dressed.
static func _pond_borders(plan: VillagePlan, ctx: Dictionary) -> void:
	var keys: Array[String] = VillageDressRules.palette_keys(ctx, "garden")
	if keys.is_empty():
		return
	var index := 0
	for w in plan.water:
		if not bool(w.get("garden", false)):
			continue
		var rng := VillageDressPlacement.rng(plan, "garden|pondside|%d" % index)
		index += 1
		for reach in [0.9, 1.7]:
			var ring: PackedVector2Array = Poly.offset(w["poly"], reach)
			for p in ring:
				_flower(plan, ctx, keys[rng.randi() % keys.size()], p, rng)


## Every open gap: a jittered grid over the planted display. Off the lots and
## the common the garden grows trees where a canopy fits and flowering shrubs
## where a shrub does; everywhere it can, flowers. Shrubs and trees take floor
## in the walk grid, so they stay off the lots, where people walk to doors.
static func _scatter(plan: VillagePlan, ctx: Dictionary) -> void:
	var g: float = plan.spec.garden
	var flowers: Array[String] = VillageDressRules.palette_keys(ctx, "garden")
	var shrubs: Array[String] = _small_first(VillageDressRules.palette_keys(ctx, "bloom"))
	var petals: Array[String] = VillageDressRules.palette_keys(ctx, "petal")
	var trees: Array[String] = []
	for key in VillageDressRules.palette_keys(ctx, "edge"):
		if VillageDressPlacement.plant_kind(key) == &"tree":
			trees.append(key)
	trees = _small_first(trees)
	if flowers.is_empty():
		return
	var region := _occupied(plan).grow(SCATTER_REACH)
	for w in plan.water:
		if bool(w.get("garden", false)):
			region = region.merge(Poly.bounding_rect(w["poly"]).grow(SCATTER_REACH))
	region = region.intersection(plan.site.grow(-1.0))
	var pitch: float = lerpf(SCATTER_SPARSE, SCATTER_DENSE, g)
	var common: PackedVector2Array = ctx["common"]
	# A full garden sows twice, the second grid staggered half a pitch, so
	# what the first left between its jittered points fills too.
	var passes: int = 2 if g >= 0.75 else 1
	for sowing in range(passes):
		var rng := VillageDressPlacement.rng(plan, "garden|scatter|%d" % sowing)
		var shift: float = pitch * 0.5 * float(sowing)
		_sow(plan, ctx, region.grow(-shift), pitch, rng, common,
			flowers, shrubs, petals, trees, g)


## Open ground: not the common and not anybody's lot.
static func _open(plan: VillagePlan, common: PackedVector2Array, at: Vector2) -> bool:
	if not common.is_empty() and Poly.contains_point(common, at):
		return false
	for lot in plan.lots:
		if Poly.contains_point(lot["poly"], at):
			return false
	return true


static func _sow(plan: VillagePlan, ctx: Dictionary, region: Rect2, pitch: float,
		rng: RandomNumberGenerator, common: PackedVector2Array, flowers: Array[String],
		shrubs: Array[String], petals: Array[String], trees: Array[String], g: float) -> void:
	var z: float = region.position.y + pitch * 0.5
	while z < region.end.y:
		var x: float = region.position.x + pitch * 0.5
		while x < region.end.x:
			var at := Vector2(x, z) + Vector2(rng.randf_range(-0.38, 0.38),
				rng.randf_range(-0.38, 0.38)) * pitch
			var roll: float = rng.randf()
			var pick: int = rng.randi()
			x += pitch
			if _open(plan, common, at):
				if roll < 0.07 * g and not trees.is_empty():
					if _plant_any(plan, ctx, trees, pick, "edge", at, rng):
						continue
				if roll < 0.30 and not shrubs.is_empty():
					if _plant_any(plan, ctx, shrubs, pick, "bloom", at, rng):
						continue
			var pool: Array[String] = petals if (roll > 0.92 and not petals.is_empty()) else flowers
			_flower(plan, ctx, pool[pick % pool.size()], at, rng)
		z += pitch


## Try `keys` starting at `pick`, then each smaller one, until one fits.
static func _plant_any(plan: VillagePlan, ctx: Dictionary, keys: Array[String], pick: int,
		palette: String, at: Vector2, rng: RandomNumberGenerator) -> bool:
	var first: int = pick % keys.size()
	for k in range(first, -1, -1):
		if VillageDressPlacement.place(plan, ctx, {"plant": true, "palette": palette},
				keys[k], at, rng, -1):
			plan.plants[-1]["zone"] = &"garden"
			return true
	return false


static func _flower(plan: VillagePlan, ctx: Dictionary, key: String, at: Vector2,
		rng: RandomNumberGenerator) -> bool:
	if VillageDressPlacement.place(plan, ctx, {"plant": true, "palette": "garden", "bed": true},
			key, at, rng, -1):
		plan.plants[-1]["zone"] = &"garden"
		return true
	return false


## Keys ordered by canopy, smallest first, ties by name: the order every
## fallback walks.
static func _small_first(keys: Array[String]) -> Array[String]:
	var out: Array[String] = keys.duplicate()
	out.sort_custom(func(a: String, b: String) -> bool:
		var ca: float = PropCatalog.canopy(a)
		var cb: float = PropCatalog.canopy(b)
		if not is_equal_approx(ca, cb):
			return ca < cb
		return a < b)
	return out


## The buildings' architecture, merged: what the display is of.
static func _occupied(plan: VillagePlan) -> Rect2:
	var occupied := Rect2()
	for building in plan.buildings:
		var rect := Poly.bounding_rect(VillageMeasure.bounds_poly(building))
		occupied = rect if occupied.size == Vector2.ZERO else occupied.merge(rect)
	return occupied
