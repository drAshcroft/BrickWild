class_name VillageBridge
extends RefCounted
## A bridge measured from the ground it crosses (VTER-CROSSINGS,
## docs/VILLAGE_TERRAIN.md "Bridges on the ground").
##
## `VillageWaterPlan.crossings` says WHERE a road meets water: a route that
## starts and ends on dry banks. On given ground the bridge is then fitted to
## what the ground really does there: the height of both landings, the water
## under the span, and the earth each end stands on. Everything is read from
## the finished ground (`VillageGroundSurface`), never from a number the spec
## drew, so the builder, the checks and the valley form all see one answer.
##
## Only called with a `VillageGroundSurface`; a flat village never reaches this
## file and its bridge is the old level deck.

## The deck's centre stands this far over the higher landing.
const DECK_RISE := 0.15
## The deck slab's thickness (the builder's, kept here so the soffit is exact).
const DECK_DEPTH := 0.25
## The underside of the deck clears the highest water under the span by this.
const CLEARANCE := 0.45
## An abutment is this long along the road, under the end of the deck, and
## stands this far beyond each edge of the deck.
const ABUTMENT_LEN := 1.2
const ABUTMENT_SIDE := 0.25
## The ramp from the deck's end down to the road: at most this steep, at
## least and at most this long.
const RAMP_GRADE := 0.12
const RAMP_MIN := 1.5
const RAMP_MAX := 6.0
## The width the builder adds to the road's for the deck (VillageBuilder).
const MARGIN := 0.8
## The span is read every this many metres.
const STEP := 1.0


## What the ground says about crossing `crossing`:
##   span_m       the length of the route, the measured channel plus its banks
##   wet_m        the length of it that is over water
##   banks        [landing 0 ground, landing 1 ground]
##   water_y      the highest water surface under the span (-INF when none)
##   deck_y       the deck slab's centre height
##   rise         [deck top over landing 0, over landing 1]
##   ramp         [ramp 0 length, ramp 1 length]
##   abutments    [{pos, dir, size: Vector3 (along, up, across), base_y, top_y}]
##                dir points from the span OUT to the bank
static func measure(surface: VillageGroundSurface, crossing: Dictionary) -> Dictionary:
	var points: PackedVector2Array = crossing["points"]
	var n := points.size()
	var half := (float(crossing["width"]) + MARGIN) * 0.5
	var banks: Array[float] = [surface.height_at(points[0]), surface.height_at(points[n - 1])]
	var span := Poly.polyline_length(points)
	var water_y := -INF
	var wet := 0.0
	var s := 0.0
	while s <= span + 0.0001:
		var p := _at(points, minf(s, span))
		var w := surface.water_at(p)
		if not w.is_empty():
			wet += STEP
			var level := surface.water_surface(w, p)
			if level > water_y:
				water_y = level
		s += STEP
	var deck_y := maxf(banks[0], banks[1]) + DECK_RISE
	if water_y > -INF:
		deck_y = maxf(deck_y, water_y + CLEARANCE + DECK_DEPTH * 0.5)
	var top_y := deck_y + DECK_DEPTH * 0.5
	var rise: Array[float] = [top_y - banks[0], top_y - banks[1]]
	var ramp: Array[float] = []
	for r in rise:
		ramp.append(clampf(r / RAMP_GRADE, RAMP_MIN, RAMP_MAX))
	var soffit := deck_y - DECK_DEPTH * 0.5
	var abutments: Array[Dictionary] = []
	for end in [0, n - 1]:
		var inside: int = 1 if end == 0 else n - 2
		var dir := (points[end] - points[inside]).normalized()
		var centre: Vector2 = points[end] - dir * ABUTMENT_LEN * 0.5
		var across := Vector2(-dir.y, dir.x)
		var base := INF
		for u in [-0.5, 0.0, 0.5]:
			for v in [-1.0, 0.0, 1.0]:
				var q: Vector2 = centre + dir * (ABUTMENT_LEN * u) + across * ((half + ABUTMENT_SIDE) * v)
				base = minf(base, surface.ground_at(q))
		abutments.append({"pos": centre, "dir": dir, "base_y": base, "top_y": maxf(soffit + 0.05, base + 0.1),
			"size": Vector3(ABUTMENT_LEN, maxf(soffit + 0.05, base + 0.1) - base, (half + ABUTMENT_SIDE) * 2.0)})
	return {"span_m": span, "wet_m": wet, "banks": banks, "water_y": water_y, "deck_y": deck_y,
		"rise": rise, "ramp": ramp, "abutments": abutments, "soffit": soffit}


static func _at(pts: PackedVector2Array, s: float) -> Vector2:
	var run := 0.0
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if run + seg >= s:
			return pts[i].lerp(pts[i + 1], clampf((s - run) / maxf(seg, 1e-9), 0.0, 1.0))
		run += seg
	return pts[pts.size() - 1]
