class_name VillageLotGround
extends RefCounted
## How a lot and its building meet sloping ground (VTER-LOTS,
## docs/VILLAGE_TERRAIN.md "Lots on the ground"). Only ever called when the
## plan has ground; a flat plan never reaches this file.
##
## THE MODEL. Every building on given ground stands on a PLATFORM: the
## balanced cut-and-fill level of the ground under its requested width x
## length rectangle (the least-squares plane's height at the building's
## origin, which over a symmetric lattice is the mean). The building's floor is
## at the platform, which is local y = 0 of `GroundFall`: the ground at the
## uphill-most point of the footprint. Below the floor the lot is GRADED to
## the family's own ground model -- level at the platform uphill of the
## footprint (the bank is cut back), falling across the footprint and on
## downhill past it at
##
##     fall_m / extent  (GroundFall's plane)
##
## where `fall_m` is the least fall that keeps that plane at or below the
## natural ground everywhere under the footprint (so no foundation is ever
## hung over a hollow: the graded ground is cut, never filled, under the
## walls). On a plane of natural fall N that is N / 2: half the fall is cut
## away uphill, half is the foundation and the steps downhill. The request
## carries `fall_m` and `downhill_deg` (`BuildingRequest.ground_fall_m`,
## `ground_downhill_deg`), each on a fixed lattice (FALL_STEP, DEG_STEP) so a
## church or a castle measured once on it serves every lot that asks the same.
##
## Because the lot is graded to exactly the plane the family plans its entry
## flights on, every flight ends on the lot's ground. Where the graded ground
## leaves the natural ground by more than TERRACE_MIN at the lot's edge, the
## lot is held by a TERRACE WALL there (`terraces`): a polyline with its
## height and whether it holds a cut bank or a fill, for VTER-GROUND-MESH to
## emit. The plan records all of it; nothing here builds geometry.

## The lattice the request's fall and direction are snapped to.
const FALL_STEP := 0.25
const DEG_STEP := 15.0
## Less fall than this under the platform and the building is asked for flat:
## the platform alone levels it.
const MIN_FALL := 0.05
## A front door this far above its graded ground is still taken, but only
## where no lot on the same search has its door nearer the ground: seven
## risers, GroundFall's plinth band. A house set front-downhill over a storey
## of fall climbs twenty steps to its door (docs/VILLAGE_TERRAIN.md).
const DOOR_RISE_PREFERRED := GroundFall.PLINTH_MAX
## Graded ground this far from the natural ground at a lot's edge is a wall.
const TERRACE_MIN := 0.6
## A family that stands on no fall at all (a temple, a mill...) stands on a
## level pad; the pad may cut or fill this much at most.
const LEVEL_PAD_MAX := 1.2
## Sample spacing under a footprint.
const SAMPLE_M := 1.5
## Samples this close to the uphill edge do not set the fall: the natural
## ground there is a bank above the platform, cut back to it.
const UPHILL_T := 0.3
## Along a lot edge, for the terrace walls.
const EDGE_STEP_M := 1.0


## The most fall the family stands on in a village. A house or a shop stands
## on up to one storey (a raised floor with entry steps, HouseSlope band 2);
## the family itself takes two (a bank storey), but that digs a cellar and
## moves the plan, and a village moves the lot instead. A church on its
## terrace, a castle on its platform: their own ceilings. 0 for a family that
## stands on no fall (then the platform is a level pad).
static func fall_limit(request: BuildingRequest) -> float:
	if request == null:
		return 0.0
	match request.kind:
		&"house", &"shop":
			return request.height
		&"church":
			return BuildingLibrary.CHURCH_MAX_FALL
		&"castle":
			if request.style == &"sky" \
					and CastleSpec.tier_for(request.width, request.length) in [&"castle", &"fortress"]:
				return 0.0
			return CastleGeometry.SLOPE_MAX_FALL
	return 0.0


## How the ground lies under the building `request` placed by `xf` (the lot
## planner's transform; the requested rectangle is centred on its origin):
##   platform_m    the floor's height on the ground (balanced cut and fill)
##   fall_m        the fall the building is asked to stand on (snapped up)
##   downhill_deg  its direction in the building's LOCAL frame (snapped)
##   downhill      the same direction in the plan's frame, a unit Vector2
##   natural_m     the natural ground's fall across the rectangle
##   slope         the natural ground's slope there (rise over run)
##   cut_m, fill_m the most the graded ground is below / above the natural
##                 ground under the footprint
static func reading(ground: VillageTerrain, request: BuildingRequest, xf: Transform3D) -> Dictionary:
	var w: float = maxf(request.width, 0.5)
	var l: float = maxf(request.length, 0.5)
	var nx: int = maxi(2, int(ceil(w / SAMPLE_M)) + 1)
	var nz: int = maxi(2, int(ceil(l / SAMPLE_M)) + 1)
	var locals: Array[Vector2] = []
	var hs := PackedFloat64Array()
	var mean := 0.0
	for iz in range(nz):
		for ix in range(nx):
			var lp := Vector2(-w * 0.5 + w * float(ix) / float(nx - 1), -l * 0.5 + l * float(iz) / float(nz - 1))
			var wp: Vector3 = xf * Vector3(lp.x, 0.0, lp.y)
			var h: float = ground.height_at(Vector2(wp.x, wp.z))
			locals.append(lp)
			hs.append(h)
			mean += h
	mean /= float(hs.size())
	# the least-squares plane over a lattice symmetric about the origin
	var sxx := 0.0
	var szz := 0.0
	var sxh := 0.0
	var szh := 0.0
	for i in range(hs.size()):
		var lp: Vector2 = locals[i]
		sxx += lp.x * lp.x
		szz += lp.y * lp.y
		sxh += lp.x * (hs[i] - mean)
		szh += lp.y * (hs[i] - mean)
	var grad := Vector2(sxh / maxf(sxx, 1e-9), szh / maxf(szz, 1e-9))
	var lo := INF
	var hi := -INF
	for h in hs:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	var out := {"platform_m": mean, "fall_m": 0.0, "downhill_deg": 0.0, "downhill": Vector2.ZERO,
		"natural_m": hi - lo, "slope": grad.length(), "cut_m": maxf(0.0, hi - mean),
		"fill_m": maxf(0.0, mean - lo), "width": w, "length": l}
	if grad.length() < 1e-5:
		return out
	var down := -grad.normalized()
	var deg: float = fposmod(snappedf(fposmod(rad_to_deg(atan2(down.x, -down.y)), 360.0), DEG_STEP), 360.0)
	var dq := GroundFall.downhill_vector(deg)
	var s0 := INF
	var s1 := -INF
	for c in GroundFall.corners(Rect2(Vector2(-w * 0.5, -l * 0.5), Vector2(w, l))):
		s0 = minf(s0, c.dot(dq))
		s1 = maxf(s1, c.dot(dq))
	var need := 0.0
	for i in range(hs.size()):
		var t: float = (locals[i].dot(dq) - s0) / maxf(s1 - s0, 1e-6)
		need = maxf(need, (mean - hs[i]) / maxf(t, UPHILL_T))
	var fall := 0.0
	if need >= MIN_FALL:
		fall = ceil(need / FALL_STEP - 1e-6) * FALL_STEP
	var cut := 0.0
	var fill := 0.0
	for i in range(hs.size()):
		var t: float = (locals[i].dot(dq) - s0) / maxf(s1 - s0, 1e-6)
		var graded: float = mean - fall * t
		cut = maxf(cut, hs[i] - graded)
		fill = maxf(fill, graded - hs[i])
	var world_down: Vector3 = xf.basis * Vector3(dq.x, 0.0, dq.y)
	out["fall_m"] = fall
	out["downhill_deg"] = deg if fall > 0.0 else 0.0
	out["downhill"] = Vector2(world_down.x, world_down.z).normalized()
	out["cut_m"] = cut
	out["fill_m"] = fill
	return out


## Why this reading cannot be built by `request`'s family, or "".
static func refusal(request: BuildingRequest, r: Dictionary) -> String:
	var limit := fall_limit(request)
	if limit <= 0.0:
		if float(r["cut_m"]) > LEVEL_PAD_MAX or float(r["fill_m"]) > LEVEL_PAD_MAX:
			return "a level pad would cut %.1f m and fill %.1f m" % [float(r["cut_m"]), float(r["fill_m"])]
		return ""
	return GroundFall.refusal(float(r["fall_m"]), float(r["width"]), float(r["length"]),
		float(r["downhill_deg"]), limit)


## The request the building is actually asked for on this reading: a copy
## carrying the fall and its direction (or the request itself, untouched,
## when the platform levels it or its family stands on no fall).
static func request_for(request: BuildingRequest, r: Dictionary) -> BuildingRequest:
	if float(r["fall_m"]) <= 0.0 or fall_limit(request) <= 0.0:
		return request
	var out := request.copy()
	out.ground_fall_m = float(r["fall_m"])
	out.ground_downhill_deg = float(r["downhill_deg"])
	return out


## What the building puts on the ground OUTSIDE its flat measured bounds on
## this reading, as local rectangles: a house's or a shop's entry flights
## (landing and treads, `HouseSlope.flights` on the flat plan with the fall
## set, which is exactly the sloped house's: below a storey the plan does not
## move), or a church's terrace and flight and a castle's talus and entrance
## flight (its sloped mesh measured once per lattice point). Also the front
## door's rise above its graded ground. {"rects": Array[Rect2], "rise": float,
## "feasible": bool, "placement": Dictionary (the sloped measurement, castles
## and churches only)}; empty when the building does not generate there.
static func ground_parts(job: Dictionary, r: Dictionary) -> Dictionary:
	var request: BuildingRequest = job["request"]
	var fall: float = float(r["fall_m"])
	if fall <= 0.0 or fall_limit(request) <= 0.0:
		return {"rects": [], "rise": 0.0, "feasible": true}
	var key := "%.2f|%.0f" % [fall, float(r["downhill_deg"])]
	var cache: Dictionary = job.get("slope_cache", {})
	if cache.has(key):
		return cache[key]
	var out := {}
	var building: Variant = job.get("building")
	if building != null and building.plan is HousePlan:
		out = _house_parts(building, fall, float(r["downhill_deg"]))
	else:
		out = _measured_parts(job, request_for(request, r), fall, float(r["downhill_deg"]))
	if job.has("slope_cache"):
		cache[key] = out
	return out


static func _house_parts(building, fall: float, deg: float) -> Dictionary:
	var plan: HousePlan = building.plan
	var spec = plan.spec
	var keep_fall: float = float(spec.ground_fall)
	var keep_deg: float = float(spec.ground_downhill_deg)
	spec.ground_fall = fall
	spec.ground_downhill_deg = deg
	var flights: Array[Dictionary] = HouseSlope.flights(plan)
	spec.ground_fall = keep_fall
	spec.ground_downhill_deg = keep_deg
	var rects: Array[Rect2] = []
	var feasible := true
	var rise := 0.0
	var entrance := plan.entrance()
	for f in flights:
		feasible = feasible and bool(f["feasible"])
		if int(f["door"]) == entrance:
			rise = float(f["rise"])
		rects.append_array(GroundFall.flight_rects(f))
	return {"rects": rects, "rise": rise, "feasible": feasible, "flights": flights.size(),
		"flight_rows": flights}


static func _measured_parts(job: Dictionary, request: BuildingRequest, fall: float, deg: float) -> Dictionary:
	var pl: Dictionary = BrickWild.measure(request)
	if pl.is_empty():
		return {}
	var flat: Dictionary = job["placement"]
	var fb: AABB = flat["bounds"]
	var sb: AABB = pl["bounds"]
	var flat_r := Rect2(Vector2(fb.position.x, fb.position.z), Vector2(fb.size.x, fb.size.z))
	var slope_r := Rect2(Vector2(sb.position.x, sb.position.z), Vector2(sb.size.x, sb.size.z))
	var rects: Array[Rect2] = []
	if not flat_r.encloses(slope_r):
		rects.append(slope_r)
	# the front door's rise above the family's own ground model
	var g := GroundFall.make(fall, deg, Rect2(Vector2(-request.width * 0.5, -request.length * 0.5),
		Vector2(request.width, request.length)))
	var door: Vector3 = flat["door"]
	var rise: float = -g.ground_y(Vector2(door.x, door.z)) if g != null else 0.0
	return {"rects": rects, "rise": rise, "feasible": true, "placement": pl, "outside": flat_r}


## The graded ground's height at plan point `p` for a building at `xf` on
## reading `r`: the platform, less GroundFall's plane below it.
static func graded_at(r: Dictionary, xf: Transform3D, p: Vector2, g: GroundFall) -> float:
	if g == null:
		return float(r["platform_m"])
	var local: Vector3 = xf.affine_inverse() * Vector3(p.x, 0.0, p.y)
	return float(r["platform_m"]) + g.ground_y(Vector2(local.x, local.z))


static func ground_model(r: Dictionary) -> GroundFall:
	var w: float = float(r["width"])
	var l: float = float(r["length"])
	return GroundFall.make(float(r["fall_m"]), float(r["downhill_deg"]),
		Rect2(Vector2(-w * 0.5, -l * 0.5), Vector2(w, l)))


## The terrace walls a lot needs: along each edge of `poly`, the runs where
## the graded ground leaves the natural ground by more than TERRACE_MIN.
## [{"points": PackedVector2Array, "height_m": float (the most it holds),
##   "holds": &"cut" (the natural ground is above: a retaining wall against
##   the bank) or &"fill" (below: a revetment under the lot's edge)}]
static func terraces(ground: VillageTerrain, poly: PackedVector2Array, r: Dictionary,
		xf: Transform3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var g := ground_model(r)
	var n := poly.size()
	for e in range(n):
		var a: Vector2 = poly[e]
		var b: Vector2 = poly[(e + 1) % n]
		var steps: int = maxi(1, int(ceil(a.distance_to(b) / EDGE_STEP_M)))
		var run := PackedVector2Array()
		var holds := &""
		var height := 0.0
		for k in range(steps + 1):
			var p: Vector2 = a.lerp(b, float(k) / float(steps))
			var d: float = ground.height_at(p) - graded_at(r, xf, p, g)
			var kind: StringName = &"cut" if d > 0.0 else &"fill"
			if absf(d) > TERRACE_MIN and (run.is_empty() or kind == holds):
				run.append(p)
				holds = kind
				height = maxf(height, absf(d))
				continue
			if run.size() >= 2:
				out.append({"points": run, "height_m": height, "holds": holds})
			run = PackedVector2Array()
			height = 0.0
			holds = &""
			if absf(d) > TERRACE_MIN:
				run.append(p)
				holds = kind
				height = absf(d)
		if run.size() >= 2:
			out.append({"points": run, "height_m": height, "holds": holds})
	return out


## The lot's ground record (lots[i]["ground_fit"] in the plan, written by the
## lot planner at commit): the reading, the request's fall, the walls.
static func record(ground: VillageTerrain, poly: PackedVector2Array, r: Dictionary,
		xf: Transform3D, parts: Dictionary) -> Dictionary:
	return {
		"platform_m": float(r["platform_m"]),
		"fall_m": float(r["fall_m"]),
		"downhill_deg": float(r["downhill_deg"]),
		"downhill": r["downhill"],
		"natural_m": float(r["natural_m"]),
		"slope": float(r["slope"]),
		"cut_m": float(r["cut_m"]),
		"fill_m": float(r["fill_m"]),
		"door_rise_m": float(parts.get("rise", 0.0)),
		"terraces": terraces(ground, poly, r, xf),
	}
