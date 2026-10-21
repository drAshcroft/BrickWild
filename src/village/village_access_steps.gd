class_name VillageAccessSteps
extends RefCounted
## The way up (or down) from a road to a lot that stands off it (VTER-STEPS-NAV,
## docs/VILLAGE_TERRAIN.md "Steps and the 3D walk").
##
## On falling ground a lot's platform meets its road with a step: the graded
## pad is half cut, half fill, and the road bed follows its own profile. Where
## that step at the lot's front, opposite the door, is more than a person
## steps (STEP_FREE), the lot gets an ACCESS FLIGHT: a strip ACCESS_WIDTH wide
## inside the lot, from its road edge, either straight in toward the door or
## along the front edge (then from a landing level with the road), of level
## treads at most RISER_MAX apart and GOING deep, from one riser off the road
## to the pad's own level. The
## strip is reserved in the lot's `entry_parts`, so the dresser keeps off it as
## it keeps off a house's entry flights, and recorded as
## `ground_fit.access` = {"road", "poly", "treads": [{"poly", "h"}], "rise_m",
## "riser_m", "going_m", "foot_m", "head_m", "layout"}; a lot with no room for
## one records {"refused": why, "rise_m"} and stays cut off, which the walk
## export says. A lot level with its road at the door records {"layout":
## "level", "at", "width_m"}: VillageBuilder leaves that much of the terrace
## and retaining walls along its front open, so its way in is not walled.
##
## Runs only on a plan with ground, after the lots are final and before the
## dresser. VillageGroundSurface cuts the treads into the ground as regions of
## their own; VillageBuilder emits them as `stair_tread` / `stair_riser`
## components, host `lot<i>_steps`.

## A step a person takes without a stair (the walk's agent climbs 0.24 m).
const STEP_FREE := 0.2
const RISER_MAX := 0.15
## At least the diagonal of the walk's 0.25 m baking cell (0.354 m): a cell
## then never touches three treads, whatever way the flight turns, and the
## baked walk never reads two risers as one step.
const GOING := 0.36
const ACCESS_WIDTH := 1.2
## where a lot's walls stand within a metre of its front, a garden flight
const ACCESS_NARROW := 0.75
## clear of the building's walls by this much (its eaves are over head)
const CLEAR := 0.1
## and this much level pad beyond the head of the flight
const EXIT := 0.6
const SLIDE := 0.25


static func plan(p: VillagePlan) -> void:
	if p.ground == null:
		return
	VillageGroundSurface.forget()
	var surface := VillageGroundSurface.of(p)
	var any := false
	for bi in range(p.buildings.size()):
		var b: Dictionary = p.buildings[bi]
		var li: int = int(b.get("lot", -1))
		if li < 0 or li >= p.lots.size() or not p.lots[li].has("ground_fit"):
			continue
		var lot: Dictionary = p.lots[li]
		var access := _access(p, surface, b, lot)
		if access.is_empty():
			continue
		lot["ground_fit"]["access"] = access
		if access.has("poly"):
			(lot["ground_fit"]["entry_parts"] as Array).append(access["poly"])
		any = true
	if any:
		VillageGroundSurface.forget()


static func _access(p: VillagePlan, surface: VillageGroundSurface, b: Dictionary, lot: Dictionary) -> Dictionary:
	var front: PackedVector2Array = lot["front"]
	var n: Vector2 = lot["normal"]
	var door := VillageMeasure.door(b)
	var a: Vector2 = front[0]
	var c: Vector2 = front[1]
	var t: Vector2 = (c - a).normalized()
	var flen: float = a.distance_to(c)
	var e: Vector2 = Geometry2D.get_closest_point_to_segment(door, a, c)
	var step := _pad(surface, e, n) - _road(surface, e, n)
	if absf(step) <= STEP_FREE:
		# level with its road at the door: an opening in whatever wall the
		# builder stands along the frontage, and nothing else
		return {"layout": "level", "at": e, "width_m": ACCESS_WIDTH, "rise_m": step,
			"road": int(lot.get("road", -1))}
	var poly: PackedVector2Array = lot["poly"]
	var blocks: Array[PackedVector2Array] = []
	for g in Geometry2D.offset_polygon(VillageMeasure.footprint_poly(b), CLEAR):
		if not Geometry2D.is_polygon_clockwise(g):
			blocks.append(g)
	blocks.append_array(VillageMeasure.yard_polys(b))
	for part in lot["ground_fit"].get("entry_parts", []):
		blocks.append(part)
	# what a flight may stand on outside the lot: its own road's verge,
	# never a carriageway (the lot planner's rule for entry flights too)
	var road_i: int = int(lot.get("road", -1))
	var verge := PackedVector2Array()
	var ways: Array[PackedVector2Array] = []
	for r in range(p.roads.size()):
		ways.append(VillageSitePlanner.road_ribbon(p.roads[r], false))
	if road_i >= 0 and road_i < p.roads.size():
		verge = VillageSitePlanner.road_ribbon(p.roads[road_i], true)
	for other in p.lots:
		if other != lot:
			blocks.append(other["poly"])
	var why := {"outside_lot": 0, "on_building": 0, "level": 0}
	for width in [ACCESS_WIDTH, ACCESS_NARROW]:
		var best := {}
		var best_score := INF
		# [origin, run, across, layout]: straight in from the front toward
		# the door; along the front edge, inside the lot or on the verge
		# outside it, from each start, either way
		var cands: Array = [[e - t * width * 0.5, n, t, "straight"]]
		var u := 0.0
		while u <= flen + 1e-3:
			for sigma in [1.0, -1.0]:
				cands.append([a + t * u, t * sigma, n, "along"])
				cands.append([a + t * u, t * sigma, -n, "verge"])
			u += SLIDE
		for cand in cands:
			var f := _fit(surface, cand[0], cand[1], cand[2], n, cand[3], width)
			if f.is_empty():
				why["level"] += 1
				continue
			var score: float = (f["head_m"] as Vector3).distance_to(Vector3(door.x, (f["head_m"] as Vector3).y, door.y))
			if score >= best_score:
				continue
			var clear := _clear(f, poly, blocks, verge, ways)
			if clear != "":
				why[clear] += 1
				continue
			best = f
			best_score = score
		if not best.is_empty():
			best["road"] = road_i
			best.erase("exit")
			return best
	return {"refused": "no room for a flight between the road and the building", "rise_m": step,
		"tried": why, "front_m": flen}


## A flight whose strip starts on the front edge at `origin`, runs along
## `dir` and is ACCESS_WIDTH across along `width_dir`; `n` is the lot's
## inward normal. A straight flight is entered across its first tread's
## width from the road; one along the front edge starts with a LANDING level
## with the road, ACCESS_WIDTH long, so the road meets it as wide as the
## flight is (a person does not step on sideways across a 0.36 m tread).
## Each tread records its "poly", "h", its middle's distance along the run
## "d" and its length "len"; the flight its "origin" and "dir".
static func _fit(surface: VillageGroundSurface, origin: Vector2, dir: Vector2, width_dir: Vector2,
		n: Vector2, layout: String, width: float) -> Dictionary:
	var side: bool = layout != "straight"
	# along the edge a landing at each end, `width` long: stepped on from the
	# road, and (on the verge) stepped off into the lot, across its length
	var landing: float = width if side else 0.0
	var head_landing: float = maxf(width - GOING, 0.0) if layout == "verge" else 0.0
	var foot_at: Vector2 = origin + width_dir * width * 0.5 if layout == "straight" \
		else origin + dir * landing * 0.5 + width_dir * width * 0.5
	var foot_h := _road(surface, foot_at, n)
	var length := landing + GOING + head_landing
	var head_h := foot_h
	var risers := 1
	for _i in range(3):
		var end: Vector2 = origin + dir * length
		if layout == "verge":
			# the pad beside the head landing, across the front edge
			head_h = surface.height_at(end - dir * (landing * 0.5) + n * 0.3)
		else:
			head_h = surface.height_at(end + width_dir * width * 0.5 + dir * 0.1)
		risers = maxi(1, int(ceil(absf(head_h - foot_h) / RISER_MAX)))
		var want := landing + float(risers) * GOING + head_landing
		if is_equal_approx(want, length):
			break
		length = want
	if absf(head_h - foot_h) <= STEP_FREE:
		return {}
	var rise: float = (head_h - foot_h) / float(risers)
	var treads: Array = []
	var cuts: Array[float] = []
	if landing > 0.0:
		cuts.append(0.0)
	for k in range(risers + 1):
		cuts.append(landing + GOING * float(k))
	cuts[cuts.size() - 1] += head_landing
	for m in range(cuts.size() - 1):
		var p0: Vector2 = origin + dir * cuts[m]
		var p1: Vector2 = origin + dir * cuts[m + 1]
		var step_k: int = m if landing <= 0.0 else m - 1
		treads.append({"poly": _wound(PackedVector2Array([p0, p1, p1 + width_dir * width,
			p0 + width_dir * width])), "h": foot_h + rise * float(step_k + 1),
			"d": (cuts[m] + cuts[m + 1]) * 0.5, "len": cuts[m + 1] - cuts[m]})
	var end: Vector2 = origin + dir * length
	var strip := _wound(PackedVector2Array([origin, end, end + width_dir * width, origin + width_dir * width]))
	# the level pad a person steps off onto
	var exit := PackedVector2Array()
	var head2 := Vector2.ZERO
	var mid_w: Vector2 = width_dir * width * 0.5
	if layout == "verge":
		var e0: Vector2 = end - dir * landing
		exit = _wound(PackedVector2Array([e0, end, end + n * EXIT, e0 + n * EXIT]))
		head2 = end - dir * (landing * 0.5) + n * 0.3
	else:
		exit = _wound(PackedVector2Array([end, end + dir * EXIT, end + dir * EXIT + width_dir * width,
			end + width_dir * width]))
		head2 = end + mid_w + dir * 0.3
	var foot: Vector2 = foot_at - n * (0.3 + (width * 0.5 if layout == "verge" else 0.0))
	return {"road": -1, "poly": strip, "exit": exit, "treads": treads, "rise_m": head_h - foot_h,
		"riser_m": absf(rise), "going_m": GOING, "layout": layout, "width_m": width,
		"origin": origin + mid_w, "dir": dir,
		"foot_m": Vector3(foot.x, foot_h, foot.y), "head_m": Vector3(head2.x, head_h, head2.y)}


## The strip and the level pad past its head clear of the building, its
## yards, its entry flights and the other lots, and inside the lot -- or, for
## the part outside it, on its own road's verge and off every carriageway:
## "" when it is, else what it hit ("outside_lot", "on_building").
static func _clear(f: Dictionary, lot: PackedVector2Array, blocks: Array[PackedVector2Array],
		verge: PackedVector2Array, ways: Array[PackedVector2Array]) -> String:
	for shape in [f["poly"], f["exit"]]:
		for off in Geometry2D.clip_polygons(shape, lot):
			if absf(Poly.area(off)) <= 0.01:
				continue
			if verge.size() < 3:
				return "outside_lot"
			for out in Geometry2D.clip_polygons(off, verge):
				if absf(Poly.area(out)) > 0.01:
					return "outside_lot"
			for way in ways:
				for over in Geometry2D.intersect_polygons(off, way):
					if absf(Poly.area(over)) > 0.01:
						return "outside_lot"
		for blk in blocks:
			for over in Geometry2D.intersect_polygons(shape, blk):
				if absf(Poly.area(over)) > 0.001:
					return "on_building"
	return ""


static func _pad(surface: VillageGroundSurface, p: Vector2, n: Vector2) -> float:
	return surface.height_at(p + n * 0.1)


## The road a person comes from, outside the front edge at p: the first
## road ground (worn line, carriageway or verge) within ROAD_REACH out along
## the lot's outward normal -- a front edge need not touch its road's verge
## exactly -- else the ground just outside the edge.
const ROAD_REACH := 2.0


static func _road(surface: VillageGroundSurface, p: Vector2, n: Vector2) -> float:
	var d := 0.1
	while d <= ROAD_REACH:
		var q := p - n * d
		var ri := surface.region_at(q)
		if surface.kind_of(ri) in [VillageGroundSurface.K_WEAR, VillageGroundSurface.K_ROAD,
				VillageGroundSurface.K_VERGE]:
			return surface.height_in(ri, q)
		d += 0.1
	return surface.height_at(p - n * 0.1)


static func _wound(poly: PackedVector2Array) -> PackedVector2Array:
	if Geometry2D.is_polygon_clockwise(poly):
		var out := poly.duplicate()
		out.reverse()
		return out
	return poly


## A house's entry flights (HouseSlope.flights, local to the building) in the
## plan's frame: [{"door", "route": [Vector3] threshold first, foot last,
## "treads": [{"poly": PackedVector2Array, "top": float}] landing first}],
## heights on the building's platform. For the walk: these are floor too.
static func entry_flights(flights: Array, xf: Transform3D, platform: float) -> Array:
	var out: Array = []
	for f in flights:
		if f.is_empty():
			continue
		var treads: Array = []
		var parts: Array = [f["landing"]]
		parts.append_array(f["steps"])
		for k in range(parts.size()):
			var s: Dictionary = parts[k]
			var top: float = float(s["top"])
			var rects := GroundFall.flight_rects({"landing": s, "steps": []})
			var world := PackedVector2Array()
			for q in Poly.from_rect(rects[0]):
				var w: Vector3 = xf * Vector3(q.x, 0.0, q.y)
				world.append(Vector2(w.x, w.z))
			treads.append({"poly": _wound(world), "top": platform + top})
		var route: Array = []
		for q in f["route"]:
			var w: Vector3 = xf * Vector3(q.x, 0.0, q.z)
			route.append(Vector3(w.x, platform + float(q.y), w.z))
		out.append({"door": int(f["door"]), "route": route, "treads": treads})
	return out
