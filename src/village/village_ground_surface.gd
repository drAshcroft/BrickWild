class_name VillageGroundSurface
extends RefCounted
## The village's finished ground on given terrain (VTER-GROUND-MESH,
## docs/VILLAGE_TERRAIN.md "The ground mesh"). Only ever made for a plan with
## `plan.ground`; a flat village never reaches this file, which is how a flat
## village stays mesh-identical.
##
## THE FIELD. The ground is a partition of the site into REGIONS, each with
## its own height function, claimed in priority order:
##
##   water    natural water's bed           the natural ground, carved
##   road     each road by rank (through first): its worn line, carriageway
##            and verges, all on its BED -- level across, following the
##            natural profile along its centreline (smoothed), eased over
##            JUNCTION_TAPER metres to the bed of the road it meets
##   lot      each lot's PLATFORM, graded exactly as VillageLotGround records
##            it (level uphill of the building, GroundFall's plane on down):
##            split along the plane's crease, so each half is planar
##   common, field, bank (the ring round natural water), land
##                                          the natural ground, carved
##
## The NATURAL ground is the terrain sampled at CELL metres and carved by the
## water (a bank shelving into the bed, as on the flat village, set on the
## terrain), interpolated linearly over the cell's two triangles -- so it is
## linear inside each triangle and the mesh is exactly it, not an
## approximation of it.
##
## THE MESH. Every grid triangle is clipped against the regions that reach it,
## highest priority first; each piece is triangulated and its vertices set on
## its own region's height. Where two regions meet at different heights the
## higher-priority piece drops a vertical RISER to the lower one along the
## shared edge, so the ground is closed: a pad meets the terrain and a road
## bed meets a pad without a gap or an overlap, by construction and not by a
## skirt. Pieces are stitched by moving vertices onto heights, never by CSG
## of solids. A riser over TERRACE_MIN is held by a terrace or retaining wall,
## which VillageBuilder emits as named components.
##
## `height_at(p)` answers the field without building the mesh (cheap, cached
## on the plan): what a prop, a plant, a yard model or a gate stands on.

const CELL := 2.5
## Road bed stations along a centreline, and how far either side the profile
## is averaged (a bilinear grid's kinks are not a road's).
const STATION := 2.0
const SMOOTH_STATIONS := 2
## Over this many metres a road's bed eases to the bed of the road it meets.
const JUNCTION_TAPER := 8.0
## A riser lower than this is not emitted (the pieces meet).
const RISER_MIN := 0.002
const SEAM_EPS := 0.002
## A shore of ground water hands back to the natural ground over this much.
const SHORE_BLEND := 1.5
## A `steps` road's bed is a stair (VTER-STEPS-NAV): level treads, each
## RISER_STEPS above or below the last, a tread starting wherever the smoothed
## profile has left the tread's level by STEP_SWITCH risers -- so a tread is
## never more than STEP_SWITCH x RISER_STEPS (9 cm) off the profile the ramp
## had, and the lots and verges beside it meet it as they met the ramp.
const RISER_STEPS := 0.15
const STEP_SWITCH := 0.6
## the profile is read this finely along the centreline for the treads
const STEP_SAMPLE := 0.05
## an edge's far side is read at least this often for the regions there
## (narrower than any tread, so a flight beside a long edge is all seen)
const RISER_SAMPLE := 0.25
## Regions, by kind. K_STAIR: an access flight cut into (or built onto) a
## lot where its pad stands off its road (VillageAccessSteps).
enum { K_WATER, K_WEAR, K_ROAD, K_VERGE, K_LOT, K_COMMON, K_FIELD, K_BANK, K_LAND, K_STAIR }

var plan: VillagePlan
var terrain: VillageTerrain
var rect: Rect2
var nx := 1
var ny := 1
var sx := 1.0
var sy := 1.0
## the finished natural ground (carved) and the raw terrain at each node
var node_h := PackedFloat32Array()
var node_raw := PackedFloat32Array()
## {"poly", "box", "kind", "surf", "owner", "tint"}; index = priority
var regions: Array[Dictionary] = []
var _buckets: Array = []
var beds: Array[Dictionary] = []
var waters: Array[Dictionary] = []
var _lots: Dictionary = {}   # lot index -> {"r", "inv", "g", "building"}
var stats := {}

static var _cache: Dictionary = {}


## The surface of `plan`, cached on the plan's identity and its shape (lots,
## roads, water, commons), so the dresser, the builder and the assembler all
## read one field. Null for a flat plan.
static func of(p_plan: VillagePlan) -> VillageGroundSurface:
	if p_plan == null or p_plan.ground == null:
		return null
	var key := "%d|%d|%d|%d|%d|%d|%d" % [p_plan.get_instance_id(), p_plan.lots.size(), p_plan.roads.size(),
		p_plan.water.size(), p_plan.commons.size(), p_plan.buildings.size(), p_plan.fields.size()]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() >= 6:
		_cache.clear()
	var s := VillageGroundSurface.new()
	s._make(p_plan)
	_cache[key] = s
	return s


## Forget every cached surface: a plan whose ground changed under the same
## shape (VillageAccessSteps reserves its flights after the lots) reads anew.
static func forget() -> void:
	_cache.clear()


func _make(p_plan: VillagePlan) -> void:
	var t0 := Time.get_ticks_usec()
	plan = p_plan
	terrain = p_plan.ground
	rect = p_plan.site
	nx = maxi(1, int(ceil(rect.size.x / CELL)))
	ny = maxi(1, int(ceil(rect.size.y / CELL)))
	sx = rect.size.x / float(nx)
	sy = rect.size.y / float(ny)
	_waters()
	_nodes()
	_beds()
	_regions()
	stats["field_ms"] = (Time.get_ticks_usec() - t0) / 1000.0


# ------------------------------------------------------------------ water

func _waters() -> void:
	var level: float = terrain.water_level_m
	for wi in range(plan.water.size()):
		var w: Dictionary = plan.water[wi]
		if w["kind"] == &"race":
			continue
		var poly: PackedVector2Array = w["poly"]
		var ground_water: bool = bool(w.get("ground", false)) and not is_nan(level)
		var reach := VillageBuilder.BANK_WIDTH + (SHORE_BLEND if ground_water else 0.0) + CELL
		# the polygon's edges bucketed on the grid, so a distance reads only
		# the edges near it (a shore rastered at 2.5 m has hundreds)
		var edges := {}
		for e in range(poly.size()):
			var a: Vector2 = poly[e]
			var b: Vector2 = poly[(e + 1) % poly.size()]
			var lo := _cell_of(Vector2(minf(a.x, b.x) - reach, minf(a.y, b.y) - reach))
			var hi := _cell_of(Vector2(maxf(a.x, b.x) + reach, maxf(a.y, b.y) + reach))
			for j in range(lo.y, hi.y + 1):
				for i in range(lo.x, hi.x + 1):
					var k := j * nx + i
					if not edges.has(k):
						edges[k] = []
					(edges[k] as Array).append(e)
		waters.append({"poly": poly, "box": Poly.bounding_rect(poly), "ground": ground_water,
			"level": level if ground_water else NAN, "edges": edges, "index": wi})


## Signed distance to water `w`'s edge (negative inside), exact within the
## bank's reach and +/- a large number beyond it.
func water_distance(w: Dictionary, p: Vector2) -> float:
	var c := _cell_of(p)
	var edges: Dictionary = w["edges"]
	var poly: PackedVector2Array = w["poly"]
	var best := INF
	var list: Variant = edges.get(c.y * nx + c.x)
	if list != null:
		for e in (list as Array):
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(
				p, poly[e], poly[(e + 1) % poly.size()])))
	var inside := (w["box"] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, poly)
	if best == INF:
		best = 1.0e4
	return -best if inside else best


## The natural ground at a point, carved by the water: a bank shelving from
## its crest into the bed, as VillageBuilder.bank_height lays it on a flat
## village, set on the terrain (a river or pond the spec drew) or on the
## water's own level (ground water, VillageGroundWater).
func _carve(p: Vector2, h: float) -> float:
	for w in waters:
		if not (w["box"] as Rect2).grow(VillageBuilder.BANK_WIDTH + SHORE_BLEND).has_point(p):
			continue
		var d := water_distance(w, p)
		if bool(w["ground"]):
			var level: float = w["level"]
			if d < VillageBuilder.BANK_WIDTH:
				h = minf(h, level + VillageBuilder.bank_height(d) - VillageBuilder.WATER_LEVEL)
			elif d < VillageBuilder.BANK_WIDTH + SHORE_BLEND:
				var crest := level + VillageBuilder.BANK_CREST - VillageBuilder.WATER_LEVEL
				h = lerpf(minf(h, crest), h, (d - VillageBuilder.BANK_WIDTH) / SHORE_BLEND)
		elif d < VillageBuilder.BANK_WIDTH:
			h = minf(h, h + VillageBuilder.bank_height(d) - VillageBuilder.BANK_CREST)
	return h


## The water's surface at a point: its level (ground water) or the terrain
## less the flat village's depth to the water (a river the spec drew, which
## follows the ground: a sheet, not a stair of pools).
func water_surface(w: Dictionary, p: Vector2) -> float:
	if bool(w["ground"]):
		return float(w["level"])
	return _raw(p) + VillageBuilder.WATER_LEVEL - VillageBuilder.BANK_CREST


func _nodes() -> void:
	node_h.resize((nx + 1) * (ny + 1))
	node_raw.resize((nx + 1) * (ny + 1))
	for j in range(ny + 1):
		for i in range(nx + 1):
			var p := node_pos(i, j)
			var h: float = terrain.height_at(p)
			node_raw[j * (nx + 1) + i] = h
			node_h[j * (nx + 1) + i] = _carve(p, h)


func node_pos(i: int, j: int) -> Vector2:
	return rect.position + Vector2(float(i) * sx, float(j) * sy)


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x - rect.position.x) / sx)), 0, nx - 1),
		clampi(int(floor((p.y - rect.position.y) / sy)), 0, ny - 1))


## Linear over the cell's two triangles (split on the (i, j)-(i+1, j+1)
## diagonal): exactly what the mesh is.
func _interp(values: PackedFloat32Array, p: Vector2) -> float:
	var c := _cell_of(p)
	var u := (p.x - rect.position.x) / sx - float(c.x)
	var v := (p.y - rect.position.y) / sy - float(c.y)
	var w := nx + 1
	var h00: float = values[c.y * w + c.x]
	var h10: float = values[c.y * w + c.x + 1]
	var h01: float = values[(c.y + 1) * w + c.x]
	var h11: float = values[(c.y + 1) * w + c.x + 1]
	if u >= v:
		return h00 + u * (h10 - h00) + v * (h11 - h10)
	return h00 + v * (h01 - h00) + u * (h11 - h01)


## The natural ground, carved by the water.
func natural_at(p: Vector2) -> float:
	return _interp(node_h, p)


func _raw(p: Vector2) -> float:
	return _interp(node_raw, p)


# ------------------------------------------------------------------ roads

## Each road's bed: stations along its centreline, their distance along it
## and the bed's height there. Graded in rank order, so a lesser road is eased
## onto the bed of the greater one it meets.
func _beds() -> void:
	var order: Array[int] = []
	for i in range(plan.roads.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra: int = int(VillageLotPlanner.ROAD_RANK.get(plan.roads[a]["class"], 9))
		var rb: int = int(VillageLotPlanner.ROAD_RANK.get(plan.roads[b]["class"], 9))
		return ra < rb if ra != rb else a < b)
	beds.resize(plan.roads.size())
	var done: Array[int] = []
	for i in order:
		beds[i] = _bed_of(i, done)
		done.append(i)
	stats["road_order"] = order


func _bed_of(i: int, greater: Array[int]) -> Dictionary:
	var road: Dictionary = plan.roads[i]
	var pts: PackedVector2Array = road["points"]
	var st := PackedVector2Array()
	var s := PackedFloat32Array()
	var run := 0.0
	for k in range(pts.size()):
		if k == 0:
			st.append(pts[0])
			s.append(0.0)
			continue
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		var n := maxi(1, int(ceil(a.distance_to(b) / STATION)))
		for m in range(1, n + 1):
			st.append(a.lerp(b, float(m) / float(n)))
			s.append(run + a.distance_to(b) * float(m) / float(n))
		run += a.distance_to(b)
	var raw := PackedFloat32Array()
	for p in st:
		raw.append(terrain.height_at(p))
	var h := PackedFloat32Array()
	h.resize(raw.size())
	for k in range(raw.size()):
		var sum := 0.0
		var cnt := 0
		for m in range(maxi(0, k - SMOOTH_STATIONS), mini(raw.size(), k + SMOOTH_STATIONS + 1)):
			sum += raw[m]
			cnt += 1
		h[k] = sum / float(cnt)
	# eased onto the bed of every greater road it runs into: where its
	# centreline leaves a greater road's ribbon, the step between the two
	# beds is spread over JUNCTION_TAPER metres outside it
	var ribbons: Array[PackedVector2Array] = []
	for j in greater:
		ribbons.append(VillageSitePlanner.road_ribbon(plan.roads[j], true))
	var inside := PackedInt32Array()
	for p in st:
		var hit := -1
		for g in range(greater.size()):
			if Geometry2D.is_point_in_polygon(p, ribbons[g]):
				hit = greater[g]
				break
		inside.append(hit)
	var offset := PackedFloat32Array()
	offset.resize(st.size())
	offset.fill(0.0)
	for k in range(st.size() - 1):
		for pair in [[k, k + 1], [k + 1, k]]:
			var a: int = pair[0]
			var b: int = pair[1]
			if inside[a] < 0 or inside[b] >= 0:
				continue
			var target := bed_at(inside[a], st[a])
			var delta := target - h[a]
			var s_edge: float = s[b]
			for m in range(st.size()):
				var away: float = (s[m] - s_edge) * (1.0 if b > a else -1.0)
				if inside[m] >= 0 and away < 0.0:
					offset[m] += delta
				elif away >= 0.0 and away < JUNCTION_TAPER:
					offset[m] += delta * (1.0 - away / JUNCTION_TAPER)
	for k in range(h.size()):
		h[k] += offset[k]
	var bed := {"stations": st, "s": s, "h": h, "class": road["class"], "width": float(road["width"])}
	if (road["class"] == &"steps" or bool(road.get("stepped", false))) and st.size() >= 2:
		bed["treads"] = treads_of(s, h)
	return bed


## The treads of a stair laid on profile (s, h): [{"s0", "s1", "h"}] in order
## along it, the first from -INF and the last to +INF. Each is level; the
## next starts where the profile has left this one's level by STEP_SWITCH
## risers, one RISER_STEPS up or down. Static and pure: a consumer can lay
## the same stair from the exported profile.
static func treads_of(s: PackedFloat32Array, h: PackedFloat32Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var h0: float = h[0]
	var level := 0
	var start := -INF
	var length: float = s[s.size() - 1]
	var n := maxi(1, int(ceil(length / STEP_SAMPLE)))
	var k := 0
	for m in range(n + 1):
		var sv: float = length * float(m) / float(n)
		while k < s.size() - 2 and s[k + 1] < sv:
			k += 1
		var span: float = s[k + 1] - s[k]
		var hv: float = lerpf(h[k], h[k + 1], clampf((sv - s[k]) / span, 0.0, 1.0)) if span > 1e-6 else h[k]
		var x := (hv - h0) / RISER_STEPS
		while x > float(level) + STEP_SWITCH or x < float(level) - STEP_SWITCH:
			out.append({"s0": start, "s1": sv, "h": h0 + float(level) * RISER_STEPS})
			start = sv
			level += 1 if x > float(level) else -1
	out.append({"s0": start, "s1": INF, "h": h0 + float(level) * RISER_STEPS})
	return out


## The height of the tread at `sv` metres along.
static func tread_height(treads: Array, sv: float) -> float:
	var lo := 0
	var hi := treads.size() - 1
	while lo < hi:
		var mid := (lo + hi) / 2
		if sv >= float(treads[mid]["s1"]):
			lo = mid + 1
		else:
			hi = mid
	return float(treads[lo]["h"])


## The point `sv` metres along road `i`'s centreline (its bed stations),
## carried straight on past either end.
func point_along(i: int, sv: float) -> Vector2:
	var st: PackedVector2Array = beds[i]["stations"]
	var s: PackedFloat32Array = beds[i]["s"]
	var k := 0
	while k < s.size() - 2 and s[k + 1] < sv:
		k += 1
	var a: Vector2 = st[k]
	var b: Vector2 = st[k + 1]
	var span: float = s[k + 1] - s[k]
	if span < 1e-6:
		return a
	return a + (b - a) * ((sv - s[k]) / span)


## The centreline of road `i` from s0 to s1 (the stations between kept).
func centre_between(i: int, s0: float, s1: float) -> PackedVector2Array:
	var st: PackedVector2Array = beds[i]["stations"]
	var s: PackedFloat32Array = beds[i]["s"]
	var out := PackedVector2Array([point_along(i, s0)])
	for k in range(st.size()):
		if s[k] > s0 + 0.01 and s[k] < s1 - 0.01:
			out.append(st[k])
	out.append(point_along(i, s1))
	return out


## Metres along road `i` of the point of its centreline nearest `p`.
func along(i: int, p: Vector2) -> float:
	var st: PackedVector2Array = beds[i]["stations"]
	var s: PackedFloat32Array = beds[i]["s"]
	if st.size() == 1:
		return 0.0
	var best := INF
	var out := 0.0
	for k in range(st.size() - 1):
		var a: Vector2 = st[k]
		var d: Vector2 = st[k + 1] - a
		var len2 := d.length_squared()
		var t := 0.0 if len2 < 1e-12 else clampf((p - a).dot(d) / len2, 0.0, 1.0)
		var dist := p.distance_squared_to(a + d * t)
		if dist < best:
			best = dist
			out = lerpf(s[k], s[k + 1], t)
	return out


## The bed of road `i` at a point: the profile at the point's projection on
## the centreline, level across.
func bed_at(i: int, p: Vector2) -> float:
	var bed: Dictionary = beds[i]
	var st: PackedVector2Array = bed["stations"]
	var h: PackedFloat32Array = bed["h"]
	if st.size() == 1:
		return h[0]
	if bed.has("treads"):
		return tread_height(bed["treads"], along(i, p))
	var best := INF
	var out: float = h[0]
	for k in range(st.size() - 1):
		var a: Vector2 = st[k]
		var d: Vector2 = st[k + 1] - a
		var len2 := d.length_squared()
		var t := 0.0 if len2 < 1e-12 else clampf((p - a).dot(d) / len2, 0.0, 1.0)
		var q := a + d * t
		var dist := p.distance_squared_to(q)
		if dist < best:
			best = dist
			out = lerpf(h[k], h[k + 1], t)
	return out


## The road bed of road `i` for whatever stands on it (VTER-STEPS-NAV's treads
## on a `steps` road): {"stations": centreline points every <= STATION m,
## "s": metres along, "h": the bed's height there, "class", "width"}.
func road_bed(i: int) -> Dictionary:
	return beds[i]


# ------------------------------------------------------------------- lots

func _lot_records() -> void:
	for bi in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[bi]
		var li: int = int(b.get("lot", -1))
		if li < 0 or li >= plan.lots.size() or not plan.lots[li].has("ground_fit"):
			continue
		var fit: Dictionary = plan.lots[li]["ground_fit"]
		var req: BuildingRequest = b["request"]
		var r := {"platform_m": float(fit["platform_m"]), "fall_m": float(fit["fall_m"]),
			"downhill_deg": float(fit["downhill_deg"]), "width": maxf(req.width, 0.5),
			"length": maxf(req.length, 0.5)}
		var xf: Transform3D = b["transform"]
		_lots[li] = {"r": r, "xf": xf, "inv": xf.affine_inverse(),
			"g": VillageLotGround.ground_model(r), "building": bi}


## The platform of lot `li` at a point: VillageLotGround.graded_at.
func pad_at(li: int, p: Vector2) -> float:
	var rec: Dictionary = _lots[li]
	var platform: float = float(rec["r"]["platform_m"])
	var g: GroundFall = rec["g"]
	if g == null:
		return platform
	var local: Vector3 = (rec["inv"] as Transform3D) * Vector3(p.x, 0.0, p.y)
	return platform + g.ground_y(Vector2(local.x, local.z))


## The floor height of building `bi` (its lot's platform), or NAN.
func platform_of(bi: int) -> float:
	var li: int = int(plan.buildings[bi].get("lot", -1))
	if not _lots.has(li):
		# a house on piles stands on its deck (VTER-FORM-WATER)
		if li >= 0 and li < plan.lots.size() and plan.lots[li].has("piles"):
			return float(plan.lots[li]["piles"]["deck_m"])
		return NAN
	return float(_lots[li]["r"]["platform_m"])


## The two planar halves of a lot: uphill of GroundFall's crease (level at
## the platform) and downhill of it (the plane).
func _lot_halves(li: int, poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var g: GroundFall = _lots[li]["g"]
	if g == null:
		out.append(poly)
		return out
	var xf: Transform3D = _lots[li]["xf"]
	var c: Vector2 = g.dir * g._s0
	var u := Vector2(-g.dir.y, g.dir.x)
	var big := 2000.0
	var up := PackedVector2Array()
	for q in [c + u * big, c - u * big, c - u * big - g.dir * big, c + u * big - g.dir * big]:
		var wp: Vector3 = xf * Vector3(q.x, 0.0, q.y)
		up.append(Vector2(wp.x, wp.z))
	for piece in Geometry2D.intersect_polygons(poly, up):
		if not Geometry2D.is_polygon_clockwise(piece):
			out.append(piece)
	for piece in Geometry2D.clip_polygons(poly, up):
		if not Geometry2D.is_polygon_clockwise(piece):
			out.append(piece)
	if out.is_empty():
		out.append(poly)
	return out


# ---------------------------------------------------------------- regions

func _add(poly: PackedVector2Array, kind: int, surf: int, owner := -1, tint := Color(0, 0, 0, 0)) -> Dictionary:
	if poly.size() < 3:
		return {}
	regions.append({"poly": poly, "box": Poly.bounding_rect(poly), "kind": kind, "surf": surf,
		"owner": owner, "tint": tint})
	return regions[regions.size() - 1]


## A stair road's treads as regions, each level at its own height, ahead of
## the road's own ribbons (which keep whatever a tread's slab misses). A
## tread's slab is the ribbon of its stretch of centreline, so two treads
## meet on the square cut between them.
func _tread_regions(i: int) -> void:
	var road: Dictionary = plan.roads[i]
	var ribbons := [
		[Poly.ribbon(road["points"], float(road["width"]) * 0.5 * VillageBuilder.WEAR_SHARE), K_WEAR, VillageBuilder.SURF_WEAR],
		[VillageSitePlanner.road_ribbon(road, false), K_ROAD, VillageBuilder.SURF_ROAD],
		[VillageSitePlanner.road_ribbon(road, true), K_VERGE, VillageBuilder.SURF_VERGE]]
	var half: float = float(road["width"]) * 0.5 \
		+ float(VillageSitePlanner.road_rule(road["class"], plan.spec)["verge"]) + 1.0
	var sv: PackedFloat32Array = beds[i]["s"]
	var length: float = sv[sv.size() - 1]
	var treads: Array = beds[i]["treads"]
	for k in range(treads.size()):
		var t: Dictionary = treads[k]
		var s0: float = maxf(float(t["s0"]), -3.0)
		var s1: float = minf(float(t["s1"]), length + 3.0)
		if s1 - s0 < 1e-3:
			continue
		var slab := Poly.ribbon(centre_between(i, s0, s1), half)
		for rb in ribbons:
			if (rb[0] as PackedVector2Array).size() < 3 or slab.size() < 3:
				continue
			for piece in Geometry2D.intersect_polygons(rb[0], slab):
				if not Geometry2D.is_polygon_clockwise(piece):
					var r := _add(piece, rb[1], rb[2], i)
					if not r.is_empty():
						r["h"] = float(t["h"])
						r["tread"] = k


func _regions() -> void:
	_lot_records()
	for w in waters:
		_add(w["poly"], K_WATER, VillageBuilder.SURF_BANK, int(w["index"]))
	# the access flights (VillageAccessSteps), cut into or built onto the
	# lots, or standing on their own road's verge -- never a carriageway, so
	# ahead of the roads they claim only lot and verge
	for li in range(plan.lots.size()):
		var access: Dictionary = plan.lots[li].get("ground_fit", {}).get("access", {})
		for t in access.get("treads", []):
			var r := _add(t["poly"], K_STAIR, VillageBuilder.SURF_ROAD, li)
			if not r.is_empty():
				r["h"] = float(t["h"])
	for i in stats["road_order"]:
		var road: Dictionary = plan.roads[i]
		if beds[i].has("treads"):
			_tread_regions(i)
		_add(Poly.ribbon(road["points"], float(road["width"]) * 0.5 * VillageBuilder.WEAR_SHARE),
			K_WEAR, VillageBuilder.SURF_WEAR, i)
		_add(VillageSitePlanner.road_ribbon(road, false), K_ROAD, VillageBuilder.SURF_ROAD, i)
		_add(VillageSitePlanner.road_ribbon(road, true), K_VERGE, VillageBuilder.SURF_VERGE, i)
	for li in range(plan.lots.size()):
		var tint := VillageBuilder._lot_tint(plan, li)
		if not _lots.has(li):
			_add(plan.lots[li]["poly"], K_COMMON, VillageBuilder.SURF_YARD, li, tint)
			continue
		for half in _lot_halves(li, plan.lots[li]["poly"]):
			_add(half, K_LOT, VillageBuilder.SURF_YARD, li, tint)
	for c in plan.commons:
		_add(c["poly"], K_COMMON, VillageBuilder.SURF_COMMON)
	for f in plan.fields:
		var poly: PackedVector2Array = f["poly"]
		var wet := false
		for w in plan.water:
			wet = wet or not Geometry2D.intersect_polygons(poly, w["poly"]).is_empty()
		if not wet:
			_add(poly, K_FIELD, VillageBuilder.SURF_FIELD if f.get("kind", &"field") == &"field" \
				else VillageBuilder.SURF_VERGE)
	for w in waters:
		for grown in Geometry2D.offset_polygon(w["poly"], VillageBuilder.BANK_WIDTH, Geometry2D.JOIN_ROUND):
			if not Geometry2D.is_polygon_clockwise(grown):
				_add(grown, K_BANK, VillageBuilder.SURF_BANK, int(w["index"]))
	_buckets.resize(nx * ny)
	for k in range(nx * ny):
		_buckets[k] = []
	for ri in range(regions.size()):
		var box: Rect2 = regions[ri]["box"]
		var lo := _cell_of(box.position)
		var hi := _cell_of(box.end)
		for j in range(lo.y, hi.y + 1):
			for i in range(lo.x, hi.x + 1):
				(_buckets[j * nx + i] as Array).append(ri)


## The region that owns a point: the highest-priority one containing it, or
## regions.size() for the open land.
func region_at(p: Vector2) -> int:
	var c := _cell_of(p)
	for ri in (_buckets[c.y * nx + c.x] as Array):
		var r: Dictionary = regions[ri]
		if (r["box"] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, r["poly"]):
			return ri
	return regions.size()


func kind_of(ri: int) -> int:
	return K_LAND if ri >= regions.size() else int(regions[ri]["kind"])


## Region `ri`'s own height at a point.
func height_in(ri: int, p: Vector2) -> float:
	if ri >= regions.size():
		return natural_at(p)
	var r: Dictionary = regions[ri]
	if r.has("h"):
		return float(r["h"])
	match int(r["kind"]):
		K_WEAR, K_ROAD, K_VERGE:
			return bed_at(int(r["owner"]), p)
		K_LOT:
			return pad_at(int(r["owner"]), p)
	return natural_at(p)


## The finished ground at a point.
func height_at(p: Vector2) -> float:
	return height_in(region_at(p), p)


## The ground as emitted at a point: the highest ground triangle over it
## (builds the mesh once). The same answer as the field except ON an edge
## between two regions at different heights, where both triangles hold the
## point and a thing set there stands on the upper one -- a bush planted on a
## lot's edge over a terrace wall stands on the wall's top, not in its face.
func ground_at(p: Vector2) -> float:
	build_mesh()
	var t := top_at(p)
	return height_at(p) if is_nan(t) else t


## Where a thing `radius` across its middle stands: the lowest ground under
## it (its centre and eight points round its rim), so on a slope its downhill
## edge is on the ground and its uphill edge sits into it.
func stand_height(p: Vector2, radius: float) -> float:
	var h := ground_at(p)
	if radius <= 0.01:
		return h
	for k in range(8):
		var a := TAU * float(k) / 8.0
		h = minf(h, ground_at(p + Vector2(cos(a), sin(a)) * radius))
	return h


## The water at a point, or {}.
func water_at(p: Vector2) -> Dictionary:
	for w in waters:
		if (w["box"] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, w["poly"]):
			return w
	return {}


# ------------------------------------------------------------------- mesh

## The ground as triangles, per surface: {surf: {"v": [Vector3], "n":
## [Vector3], "c": [Color] (empty when uncoloured)}};
## "tops" (every non-vertical triangle, for draping) and "risers" separately
## counted in `stats`.
var mesh_tris: Dictionary = {}
var _tops: Array = []   # per cell: [Vector3] of the cell's top triangles


func build_mesh() -> void:
	if not mesh_tris.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	stats["pieces"] = 0
	stats["risers"] = 0
	stats["holes"] = 0
	stats["untriangulated"] = 0
	stats["riser_max"] = 0.0
	_tops.resize(nx * ny)
	for j in range(ny):
		for i in range(nx):
			var cell := j * nx + i
			var tops: Array = []
			var p00 := node_pos(i, j)
			var p10 := node_pos(i + 1, j)
			var p01 := node_pos(i, j + 1)
			var p11 := node_pos(i + 1, j + 1)
			var cands: Array = _buckets[cell]
			for tri in [PackedVector2Array([p00, p10, p11]), PackedVector2Array([p00, p11, p01])]:
				if cands.is_empty():
					_emit_piece(tri, regions.size(), tops)
				else:
					_partition(tri, cands, tops, 0)
			_tops[cell] = tops
	_skirt()
	stats["mesh_ms"] = (Time.get_ticks_usec() - t0) / 1000.0


func _partition(tri: PackedVector2Array, cands: Array, tops: Array, depth: int) -> void:
	var tb := Poly.bounding_rect(tri)
	var left: Array[PackedVector2Array] = [tri]
	var claimed: Array = []   # [piece, region]
	for ri in cands:
		if left.is_empty():
			break
		var r: Dictionary = regions[ri]
		if not (r["box"] as Rect2).intersects(tb, true):
			continue
		var next: Array[PackedVector2Array] = []
		for piece in left:
			var inter := Geometry2D.intersect_polygons(piece, r["poly"])
			if inter.is_empty():
				next.append(piece)
				continue
			var rest := Geometry2D.clip_polygons(piece, r["poly"])
			for q in inter + rest:
				if Geometry2D.is_polygon_clockwise(q):
					# the region lies wholly inside the piece: a hole the
					# triangulation cannot take. Split the triangle and retry.
					if depth < 3:
						var m01 := (tri[0] + tri[1]) * 0.5
						var m12 := (tri[1] + tri[2]) * 0.5
						var m20 := (tri[2] + tri[0]) * 0.5
						for sub in [PackedVector2Array([tri[0], m01, m20]), PackedVector2Array([m01, tri[1], m12]),
								PackedVector2Array([m20, m12, tri[2]]), PackedVector2Array([m01, m12, m20])]:
							_partition(sub, cands, tops, depth + 1)
						return
					stats["holes"] = int(stats["holes"]) + 1
			for q in inter:
				if not Geometry2D.is_polygon_clockwise(q):
					claimed.append([q, ri])
			for q in rest:
				if not Geometry2D.is_polygon_clockwise(q):
					next.append(q)
		left = next
	for c in claimed:
		_emit_piece(c[0], c[1], tops)
	for q in left:
		_emit_piece(q, regions.size(), tops)


func _emit_piece(q: PackedVector2Array, ri: int, tops: Array) -> void:
	if q.size() < 3 or absf(Poly.area(q)) < 1e-7:
		return
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(q)
	if idx.is_empty():
		stats["untriangulated"] = int(stats["untriangulated"]) + 1
		idx = PackedInt32Array()
		for k in range(1, q.size() - 1):
			idx.append_array([0, k, k + 1])
	stats["pieces"] = int(stats["pieces"]) + 1
	var surf: int = VillageBuilder.SURF_GROUND
	var tint := Color(0, 0, 0, 0)
	var bank: Dictionary = {}
	if ri < regions.size():
		var r: Dictionary = regions[ri]
		surf = int(r["surf"])
		tint = r["tint"]
		if int(r["kind"]) == K_BANK or int(r["kind"]) == K_WATER:
			for w in waters:
				if int(w["index"]) == int(r["owner"]):
					bank = w
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for p in q:
		verts.append(Vector3(p.x, height_in(ri, p), p.y))
		if not bank.is_empty():
			cols.append(VillageBuilder.bank_colour(water_distance(bank, p)))
		elif tint.a > 0.0:
			cols.append(tint)
	for t in range(0, idx.size(), 3):
		var ia: int = idx[t]
		var ib: int = idx[t + 1]
		var ic: int = idx[t + 2]
		var a := verts[ia]
		var b := verts[ib]
		var c := verts[ic]
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-14:
			continue
		if n.y < 0.0:
			var sw := ib
			ib = ic
			ic = sw
			b = verts[ib]
			c = verts[ic]
			n = -n
		_push(surf, [a, b, c], n.normalized(), [] if cols.is_empty() else [cols[ia], cols[ib], cols[ic]], mesh_tris)
		tops.append(a)
		tops.append(b)
		tops.append(c)
	# a common, a field or a bank stands on the natural ground, as does
	# everything of lower priority than it: it has no step to drop
	if ri < regions.size() and not int(regions[ri]["kind"]) in [K_COMMON, K_FIELD, K_BANK]:
		_risers(q, ri)


## Plain Arrays, not Packed ones: a Packed array read out of a Dictionary is
## a copy, and appending to it appends to nothing.
func _push(surf: int, vs: Array, n: Vector3, cs: Array, into: Dictionary) -> void:
	if not into.has(surf):
		into[surf] = {"v": [], "n": [], "c": []}
	var m: Dictionary = into[surf]
	var mv: Array = m["v"]
	var mn: Array = m["n"]
	var mc: Array = m["c"]
	for k in range(vs.size()):
		mv.append(vs[k])
		mn.append(n)
		if not cs.is_empty():
			mc.append(cs[k])


## Along each edge of piece `q` of region `ri`: wherever the ground on the
## other side belongs to a region of lower priority, a vertical riser from
## this piece's edge down (or up) to that region's ground. Each boundary is
## dropped once, by the higher of the two regions.
func _risers(q: PackedVector2Array, ri: int) -> void:
	for e in range(q.size()):
		var a: Vector2 = q[e]
		var b: Vector2 = q[(e + 1) % q.size()]
		var d := b - a
		if d.length_squared() < 1e-10:
			continue
		var n := Vector2(d.y, -d.x).normalized()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + n * SEAM_EPS, q):
			n = -n
		var ha := height_in(ri, a)
		var hb := height_in(ri, b)
		# the regions across the edge, with the points where they change
		var ts: Array[float] = [0.0]
		var rs: Array[int] = []
		# at least every RISER_SAMPLE metres: a stair's treads (0.28 m and
		# more) along a road's or a lot's edge are each read, not stepped over
		var samples := [0.02, 0.26, 0.5, 0.74, 0.98]
		var dense := int(ceil(d.length() / RISER_SAMPLE))
		if dense > 4:
			samples = [0.02]
			for m in range(1, dense):
				samples.append(float(m) / float(dense))
			samples.append(0.98)
		var prev := region_at(a.lerp(b, samples[0]) + n * SEAM_EPS)
		rs.append(prev)
		var t_prev: float = samples[0]
		for k in range(1, samples.size()):
			var t: float = samples[k]
			var here := region_at(a.lerp(b, t) + n * SEAM_EPS)
			if here != prev:
				var lo := t_prev
				var hi := t
				for _m in range(8):
					var mid := (lo + hi) * 0.5
					if region_at(a.lerp(b, mid) + n * SEAM_EPS) == prev:
						lo = mid
					else:
						hi = mid
				ts.append((lo + hi) * 0.5)
				rs.append(here)
				prev = here
			t_prev = t
		ts.append(1.0)
		for k in range(rs.size()):
			var other: int = rs[k]
			if other <= ri:
				continue
			var t0: float = ts[k]
			var t1: float = ts[k + 1]
			var pa := a.lerp(b, t0)
			var pb := a.lerp(b, t1)
			var top_a := lerpf(ha, hb, t0)
			var top_b := lerpf(ha, hb, t1)
			var bot_a := height_in(other, pa)
			var bot_b := height_in(other, pb)
			var step := maxf(absf(top_a - bot_a), absf(top_b - bot_b))
			if step < RISER_MIN:
				continue
			stats["risers"] = int(stats["risers"]) + 1
			stats["riser_max"] = maxf(float(stats["riser_max"]), step)
			_quad(VillageBuilder.SURF_GROUND, Vector3(pa.x, top_a, pa.y), Vector3(pb.x, top_b, pb.y),
				Vector3(pb.x, bot_b, pb.y), Vector3(pa.x, bot_a, pa.y))


## A vertical quad, both faces: a riser is seen from above and below the step.
func _quad(surf: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0])
		if n.length_squared() < 1e-14:
			continue
		n = n.normalized()
		_push(surf, tri, n, [], mesh_tris)
		_push(surf, [tri[0], tri[2], tri[1]], -n, [], mesh_tris)


## Round the site's edge, the ground carried down to a common foot, so the
## village reads as a block of ground and its AABB is the ground's.
func _skirt() -> void:
	var lo := INF
	for h in node_h:
		lo = minf(lo, h)
	var foot := lo - 2.0
	stats["foot"] = foot
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var centre := rect.get_center()
	for e in range(4):
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var steps := maxi(1, int(ceil(a.distance_to(b) / 0.5)))
		var inward := (centre - (a + b) * 0.5).normalized() * 0.001
		for k in range(steps):
			var p := a.lerp(b, float(k) / float(steps))
			var q := a.lerp(b, float(k + 1) / float(steps))
			var hp := top_at(p + inward)
			var hq := top_at(q + inward)
			if is_nan(hp):
				hp = height_at(p)
			if is_nan(hq):
				hq = height_at(q)
			_quad(VillageBuilder.SURF_GROUND, Vector3(p.x, hp, p.y), Vector3(q.x, hq, q.y),
				Vector3(q.x, foot, q.y), Vector3(p.x, foot, p.y))


## The emitted ground's own height at a point (the highest top triangle
## over it), NAN where none is (outside the site). After build_mesh().
func top_at(p: Vector2) -> float:
	if _tops.is_empty():
		return NAN
	# a point on a cell's line is over both cells' triangles
	var best := NAN
	var seen := {}
	for d in [Vector2(-1e-4, -1e-4), Vector2(1e-4, -1e-4), Vector2(-1e-4, 1e-4), Vector2(1e-4, 1e-4)]:
		var c := _cell_of(p + d)
		var k := c.y * nx + c.x
		if seen.has(k):
			continue
		seen[k] = true
		var h := top_in(_tops[k], p)
		if not is_nan(h) and (is_nan(best) or h > best):
			best = h
	return best


static func top_in(tops: Array, p: Vector2) -> float:
	var best := NAN
	for k in range(0, tops.size(), 3):
		var h := tri_height(tops[k], tops[k + 1], tops[k + 2], p)
		if not is_nan(h) and (is_nan(best) or h > best):
			best = h
	return best


## The height of triangle (a, b, c) over plan point p, NAN when p is not
## over it.
static func tri_height(a: Vector3, b: Vector3, c: Vector3, p: Vector2) -> float:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(p.x - a.x, p.y - a.z)
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-12:
		return NAN
	var u := (v2.x * v1.y - v1.x * v2.y) / den
	var v := (v0.x * v2.y - v2.x * v0.y) / den
	if u < -1e-5 or v < -1e-5 or u + v > 1.0 + 1e-5:
		return NAN
	return a.y + u * (b.y - a.y) + v * (c.y - a.y)


## Lay `poly` over the emitted ground, `lift` metres above it, on `surf`
## (into the caller's `into`, never the cached ground):
## each piece of it over a ground triangle takes that triangle's plane, so
## an overlay (a worn tread, a mill race's water) lies on the ground exactly.
func drape(poly: PackedVector2Array, lift: float, surf: int, into: Dictionary) -> void:
	if poly.size() < 3:
		return
	build_mesh()
	var box := Poly.bounding_rect(poly)
	var lo := _cell_of(box.position)
	var hi := _cell_of(box.end)
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			var tops: Array = _tops[j * nx + i]
			for k in range(0, tops.size(), 3):
				var a: Vector3 = tops[k]
				var b: Vector3 = tops[k + 1]
				var c: Vector3 = tops[k + 2]
				var tri := PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
				if not Poly.bounding_rect(tri).intersects(box, true):
					continue
				var n := (c - a).cross(b - a).normalized()
				for piece in Geometry2D.intersect_polygons(tri, poly):
					if Geometry2D.is_polygon_clockwise(piece):
						continue
					var idx := Geometry2D.triangulate_polygon(piece)
					for t in range(0, idx.size(), 3):
						var vs: Array = []
						for m in range(3):
							var p: Vector2 = piece[idx[t + m]]
							var h := tri_height(a, b, c, p)
							if is_nan(h):
								h = a.y
							vs.append(Vector3(p.x, h + lift, p.y))
						if (vs[2] - vs[0]).cross(vs[1] - vs[0]).y < 0.0:
							vs = [vs[0], vs[2], vs[1]]
						_push(surf, vs, n, [], into)


## Lay `poly` as water at each point's water surface (water_surface), on the
## grid's triangles so a river that follows the ground is a sheet over it.
func water_sheet(w: Dictionary, surf: int, into: Dictionary) -> void:
	var poly: PackedVector2Array = w["poly"]
	if bool(w["ground"]):
		var idx := Geometry2D.triangulate_polygon(poly)
		for t in range(0, idx.size(), 3):
			var vs: Array = []
			for m in range(3):
				var p: Vector2 = poly[idx[t + m]]
				vs.append(Vector3(p.x, float(w["level"]), p.y))
			if (vs[2] - vs[0]).cross(vs[1] - vs[0]).y < 0.0:
				vs = [vs[0], vs[2], vs[1]]
			_push(surf, vs, Vector3.UP, [], into)
		return
	var box := Poly.bounding_rect(poly)
	var lo := _cell_of(box.position)
	var hi := _cell_of(box.end)
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			var p00 := node_pos(i, j)
			var p10 := node_pos(i + 1, j)
			var p01 := node_pos(i, j + 1)
			var p11 := node_pos(i + 1, j + 1)
			for tri in [PackedVector2Array([p00, p10, p11]), PackedVector2Array([p00, p11, p01])]:
				for piece in Geometry2D.intersect_polygons(tri, poly):
					if Geometry2D.is_polygon_clockwise(piece):
						continue
					var idx := Geometry2D.triangulate_polygon(piece)
					for t in range(0, idx.size(), 3):
						var vs: Array = []
						for m in range(3):
							var p: Vector2 = piece[idx[t + m]]
							vs.append(Vector3(p.x, water_surface(w, p), p.y))
						var n: Vector3 = (vs[2] - vs[0]).cross(vs[1] - vs[0])
						if n.y < 0.0:
							vs = [vs[0], vs[2], vs[1]]
							n = -n
						if n.length_squared() > 1e-14:
							_push(surf, vs, n.normalized(), [], into)


## The extent of everything emitted (after build_mesh()).
func bounds() -> AABB:
	var out := AABB()
	var first := true
	for surf in mesh_tris:
		for v in (mesh_tris[surf]["v"] as Array):
			if first:
				out = AABB(v, Vector3.ZERO)
				first = false
			else:
				out = out.expand(v)
	return out
