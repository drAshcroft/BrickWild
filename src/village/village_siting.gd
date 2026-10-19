class_name VillageSiting
extends RefCounted
## Where on the given ground the village stands, and which way it faces
## (VTER-SITING, docs/VILLAGE_TERRAIN.md "Siting").
##
## Only called when `spec.terrain` is given. The planners keep their own
## axis-aligned frame -- the through road runs west to east across an
## axis-aligned site, the common sits north of it -- and this file chooses
## where that frame is laid on the caller's grid: an ANCHOR (the site centre,
## in the grid's own metres) and a YAW (the frame's +X, counter-clockwise from
## the grid's +X in its (x, y)). It then resamples the ground into the frame
## (`VillageTerrain.sited_view`), so every later reading of a plan point needs
## no transform. A plan point p stands on the caller's ground at
## `anchor + p.rotated(yaw)`.
##
## The choice is a score over candidate frames, lower is better, read off the
## FLAT plan of the same spec (its site, common, landmark slot and through
## road -- the form's own layout, before the ground moves anything):
##
##   cliff     share of the site lattice's neighbour pairs steeper than a
##             footpath (PATH_MAX): a lot must not cross a cliff band
##   wet       share of the site lattice on standing water
##   steep     share of neighbour pairs steeper than a house plot (PLOT_MAX)
##   road      the through road's grade above 10 % (the cart cap less a
##             margin), length-weighted, and a little of its mean grade: the
##             through road runs along the frame's X, so this turns the frame
##             until X is the contour
##   common    the common's slope above 4 %, and any of it wet or cliff
##   water     how far the nearest water is, when the programme wants water
##   landmark  the landmark slot's height ranked among the site lattice's,
##             short of the world set's median church (VTER-PLACE): the
##             church on the high side of its village, its common below it
##   centre    how far the anchor is from the caller's own centre
##
## If the grid is larger than the site (with its corners free to turn) the
## anchor is searched on a lattice and refined; if the grid only just covers
## the site -- a consumer that fixes the centre -- only the yaw is chosen and
## the anchor is the grid's origin. Deterministic: a pure function of the
## spec and the ground's fingerprint, cached on both.

const YAW_STEPS := 24               ## 15 degrees, refined twice
const LATTICE := 11                 ## site samples per side
const VIEW_PAD_M := 160.0           ## the view reaches past the largest site, for the analysis padding
const VIEW_CELL_MAX := 5.0
const ANCHOR_STEP_MIN := 20.0
const ANCHOR_STEP_MAX := 60.0
const CORNER_MARGIN := 10.0
const REACH_M := 400.0              ## the anchor stays this near the caller's centre: the survey's disc
const ROAD_STRETCH := 2.0           ## the retries stretch the site along its road; score the road that long
const ROAD_FREE := 0.10
const COMMON_FREE := 0.04
const WATER_REACH_M := 120.0
const CACHE_MAX := 16

const W_CLIFF := 20.0
const W_WET := 200.0             ## nothing is planned on wet ground, if there is any dry
const W_STEEP := 4.0
const W_ROAD_OVER := 20.0
const W_ROAD_MEAN := 2.0
const W_COMMON := 30.0
const W_COMMON_BAD := 10.0
const W_WATER := 2.0
const W_CENTRE := 1.0               ## per 400 m
## VTER-PLACE: per unit of rank short of the world's median church
## (VillagePlaceCheck.WORLD_WORSHIP_ELEV_MEDIAN). Small beside the road and
## the common: it decides between frames that are otherwise alike -- above
## all the two ways round a contour road, the common's side uphill or down.
const W_LANDMARK := 2.0
## Below this much relief across the lattice the rank is noise.
const LANDMARK_RELIEF_M := 3.0

static var _cache := {}
static var _order: Array[String] = []


## {"anchor": Vector2, "yaw": float, "score": float, "terms": {...},
##  "fixed_centre": bool, "ground": VillageTerrain (the village-frame view)}
static func site(spec: VillageSpec) -> Dictionary:
	var t: VillageTerrain = spec.terrain
	var flat: VillagePlan = VillageSitePlanner.plan_flat(spec)
	var key := "%s|%d|%s|%s|%s|%s|%d" % [t.fingerprint(), spec.seed, spec.form, flat.site,
		spec.water, spec.purpose, spec.households]
	if _cache.has(key):
		return _cache[key]
	var out := choose(t, flat, spec.water != &"none")
	var w: float = VillageSitePlanner.SITE_MAX_SIDE * 0.5 + VIEW_PAD_M
	out["ground"] = t.sited_view(out["anchor"], out["yaw"], Rect2(-w, -w, 2.0 * w, 2.0 * w),
		minf(t.cell_m, VIEW_CELL_MAX))
	_cache[key] = out
	_order.append(key)
	while _order.size() > CACHE_MAX:
		_cache.erase(_order.pop_front())
	return out


static func clear_cache() -> void:
	_cache.clear()
	_order.clear()


## The frame for `flat` on `t`. Separate from `site` so a test can score a
## frame it names itself.
static func choose(t: VillageTerrain, flat: VillagePlan, wants_water: bool) -> Dictionary:
	var samples := _samples(flat)
	var bounds := t.bounds()
	var reach: float = flat.site.size.length() * 0.5 + CORNER_MARGIN
	var free := bounds.grow(-reach)
	var fixed := free.size.x <= 0.0 or free.size.y <= 0.0
	var water := _water_points(t) if wants_water else PackedVector2Array()
	var anchors: Array[Vector2] = []
	var step: float = clampf(minf(flat.site.size.x, flat.site.size.y) * 0.5, ANCHOR_STEP_MIN, ANCHOR_STEP_MAX)
	if fixed:
		anchors.append(Vector2.ZERO if bounds.has_point(Vector2.ZERO) else bounds.get_center())
	else:
		# a lattice through the caller's own origin, over the free ground
		var i0 := int(ceil(free.position.x / step))
		var i1 := int(floor(free.end.x / step))
		var j0 := int(ceil(free.position.y / step))
		var j1 := int(floor(free.end.y / step))
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if (Vector2(i, j) * step).length() <= REACH_M:
					anchors.append(Vector2(i, j) * step)
		if anchors.is_empty():
			anchors.append(free.get_center())
	# a fixed centre turns only as far as the grid still covers the site
	var any_cover := false
	if fixed:
		for k in range(YAW_STEPS):
			any_cover = any_cover or _covered(bounds, flat.site, anchors[0], TAU * float(k) / float(YAW_STEPS))
	var best := {}
	for a in anchors:
		for k in range(YAW_STEPS):
			var yaw := TAU * float(k) / float(YAW_STEPS)
			if fixed and (not _covered(bounds, flat.site, a, yaw) if any_cover else k != 0):
				continue
			var s := _score(t, samples, a, yaw, water)
			if best.is_empty() or float(s["score"]) < float(best["score"]) - 1e-9:
				best = s
	# refine: half and quarter steps of anchor and yaw round the best
	var dyaw := TAU / float(YAW_STEPS)
	var dstep := step
	for _round in range(4):
		dyaw *= 0.5
		dstep *= 0.5
		var centre: Dictionary = best
		for dj in [-1, 0, 1]:
			for di in [-1, 0, 1]:
				if fixed and (di != 0 or dj != 0):
					continue
				var a2: Vector2 = Vector2(centre["anchor"]) + Vector2(di, dj) * dstep
				if not fixed and (not free.has_point(a2) or a2.length() > REACH_M):
					continue
				for dk in [-1, 0, 1]:
					var yaw2: float = float(centre["yaw"]) + dk * dyaw
					if fixed and dk != 0 and not _covered(bounds, flat.site, a2, yaw2):
						continue
					var s2 := _score(t, samples, a2, yaw2, water)
					if float(s2["score"]) < float(best["score"]) - 1e-9:
						best = s2
	best["fixed_centre"] = fixed
	best["yaw"] = fposmod(float(best["yaw"]), TAU)
	return best


## The site's four corners, turned by `yaw` about `anchor`, all on the grid.
static func _covered(bounds: Rect2, site: Rect2, anchor: Vector2, yaw: float) -> bool:
	var b := bounds.grow(0.01)
	for p in [site.position, Vector2(site.end.x, site.position.y), site.end, Vector2(site.position.x, site.end.y)]:
		if not b.has_point(anchor + (p as Vector2).rotated(yaw)):
			return false
	return true


## The flat plan's points the score reads, in the plan's frame.
static func _samples(flat: VillagePlan) -> Dictionary:
	var site: Rect2 = flat.site.grow(-2.0)
	var lattice := PackedVector2Array()
	for j in range(LATTICE):
		for i in range(LATTICE):
			lattice.append(site.position + Vector2(site.size.x * i, site.size.y * j) / float(LATTICE - 1))
	var common := PackedVector2Array()
	if not flat.commons.is_empty():
		var poly: PackedVector2Array = flat.commons[0]["poly"]
		var r := Poly.bounding_rect(poly)
		for j in range(5):
			for i in range(5):
				var p := r.position + Vector2(r.size.x * (i + 0.5), r.size.y * (j + 0.5)) / 5.0
				if Poly.contains_point(poly, p):
					common.append(p)
	var roads: Array[PackedVector2Array] = []
	var cx: float = flat.site.get_center().x
	for r in range(flat.roads.size()):
		if flat.roads[r]["class"] != &"through":
			continue
		var pts: PackedVector2Array = flat.roads[r]["points"]
		if r == 0:
			# the east-west road as the retries will stretch it
			var long := PackedVector2Array()
			for p in pts:
				long.append(Vector2(cx + (p.x - cx) * ROAD_STRETCH, p.y))
			pts = long
		roads.append(pts)
	var out := {"lattice": lattice, "spacing": site.size / float(LATTICE - 1), "common": common, "roads": roads}
	if flat.landmark_reserved():
		out["landmark"] = VillageMeasure.centre(flat.landmark_site["poly"])
	return out


static func _score(t: VillageTerrain, samples: Dictionary, anchor: Vector2, yaw: float,
		water: PackedVector2Array) -> Dictionary:
	var c := cos(yaw)
	var s := sin(yaw)
	var wl: float = t.water_level_m
	var lattice: PackedVector2Array = samples["lattice"]
	var hs := PackedFloat64Array()
	hs.resize(lattice.size())
	var wet := 0
	for i in range(lattice.size()):
		var p: Vector2 = lattice[i]
		var h := t.height_at(anchor + Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
		hs[i] = h
		if not is_nan(wl) and h <= wl:
			wet += 1
	var spacing: Vector2 = samples["spacing"]
	var edges := 0
	var cliff := 0
	var steep := 0
	for j in range(LATTICE):
		for i in range(LATTICE):
			var h0 := hs[j * LATTICE + i]
			if i + 1 < LATTICE:
				var g := absf(hs[j * LATTICE + i + 1] - h0) / spacing.x
				edges += 1
				cliff += 1 if g > VillageSiteAnalysis.PATH_MAX else 0
				steep += 1 if g > VillageSiteAnalysis.PLOT_MAX else 0
			if j + 1 < LATTICE:
				var g2 := absf(hs[(j + 1) * LATTICE + i] - h0) / spacing.y
				edges += 1
				cliff += 1 if g2 > VillageSiteAnalysis.PATH_MAX else 0
				steep += 1 if g2 > VillageSiteAnalysis.PLOT_MAX else 0
	var over := 0.0
	var mean := 0.0
	var length := 0.0
	for pts in samples["roads"]:
		var prev := NAN
		for k in range(pts.size()):
			var p: Vector2 = pts[k]
			var h := t.height_at(anchor + Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
			if k > 0:
				var d: float = pts[k].distance_to(pts[k - 1])
				var g := absf(h - prev) / maxf(d, 0.01)
				over += maxf(0.0, g - ROAD_FREE) * d
				mean += g * d
				length += d
			prev = h
	var common_ex := 0.0
	var common_bad := 0
	var cpts: PackedVector2Array = samples["common"]
	for p in cpts:
		var q := anchor + Vector2(p.x * c - p.y * s, p.x * s + p.y * c)
		var sl := t.slope_at(q)
		common_ex += maxf(0.0, sl - COMMON_FREE)
		if sl > VillageSiteAnalysis.PATH_MAX or (not is_nan(wl) and t.height_at(q) <= wl):
			common_bad += 1
	var terms := {
		"cliff": W_CLIFF * float(cliff) / maxf(edges, 1),
		"wet": W_WET * float(wet) / maxf(lattice.size(), 1),
		"steep": W_STEEP * float(steep) / maxf(edges, 1),
		"road": W_ROAD_OVER * over / maxf(length, 1.0) + W_ROAD_MEAN * mean / maxf(length, 1.0),
		"common": W_COMMON * common_ex / maxf(cpts.size(), 1) + W_COMMON_BAD * float(common_bad) / maxf(cpts.size(), 1),
		"water": 0.0,
		"centre": W_CENTRE * anchor.length() / 400.0,
		"landmark": 0.0,
	}
	if samples.has("landmark"):
		var lp: Vector2 = samples["landmark"]
		var hl := t.height_at(anchor + Vector2(lp.x * c - lp.y * s, lp.x * s + lp.y * c))
		var lo := INF
		var hi := -INF
		var below := 0
		for h2 in hs:
			lo = minf(lo, h2)
			hi = maxf(hi, h2)
			below += 1 if h2 < hl else 0
		if hi - lo >= LANDMARK_RELIEF_M:
			var rank := float(below) / maxf(hs.size(), 1)
			terms["landmark"] = W_LANDMARK * maxf(0.0, VillagePlaceCheck.WORLD_WORSHIP_ELEV_MEDIAN - rank)
	if not water.is_empty():
		var near := INF
		for w in water:
			near = minf(near, w.distance_to(anchor))
		terms["water"] = W_WATER * clampf((near - WATER_REACH_M) / 300.0, 0.0, 1.0)
	var total := 0.0
	for k2 in terms:
		total += float(terms[k2])
	return {"anchor": anchor, "yaw": yaw, "score": total, "terms": terms}


## Standing water (nodes at or under the water level) or, without a water
## level, the drainage the site analysis reads (streams). Subsampled: the
## score asks only how far the nearest is.
static func _water_points(t: VillageTerrain) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not is_nan(t.water_level_m):
		var stride := maxi(1, int(round(20.0 / t.cell_m)))
		for r in range(0, t.rows, stride):
			for col in range(0, t.cols, stride):
				if t.heights[r * t.cols + col] <= t.water_level_m:
					out.append(t.origin + Vector2(col, r) * t.cell_m)
		return out
	var a := VillageSiteAnalysis.of(t, t.bounds(), maxf(10.0, t.cell_m * 0.5))
	if not a.valid():
		return out
	for line in a.streams():
		for k in range(0, line.size(), 2):
			out.append(line[k])
	return out


## The caller's ground, read back at a plan point.
static func to_ground(plan: VillagePlan, p: Vector2) -> Vector2:
	return plan.site_anchor + p.rotated(plan.site_yaw)
