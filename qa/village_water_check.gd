class_name VillageWaterCheck
extends RefCounted
## Is a water village (VTER-FORM-WATER, VillageWaterForm) standing in its
## water? The plan's rules, and -- through VillageGroundCheck, on the emitted
## ground mesh -- the piles'.
##
##   PILES       every pile lot lies wholly on the ground's water, over a bed
##               no deeper than the piles reach (HousePiles.MAX_WATER_M), fronts
##               a boardwalk, and its building was asked for exactly that: piles,
##               that depth, a landing from its wall to the boardwalk
##   BOARDWALKS  every boardwalk over the water is carried by a crossing of kind
##               `boardwalk` the width of its verged ribbon, and joins the rest
##               of the roads (VillageRoadCheck's `connected` sees them too)
##   DRY_THINGS  nothing the dresser sets down stands in the water (a boat, a
##               reed and the mill's own race excepted): a barrel set on a pile
##               lot would stand on the lake bed
##   SHARE       `over_water_share` (VillageShape, the survey's definition)
##
## On the mesh (`ground`, called by VillageGroundCheck.check):
##
##   pile house  stands at its deck level; under its footprint and landing the
##               ground is under the water's surface (no ground over the water
##               beneath it), and above its piles' feet (they reach the bed)
##   boardwalk   the same, under every metre of every boardwalk crossing

const TOL := 0.05
const SAMPLE_M := 1.0

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


func check(plan: VillagePlan) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	_piles(plan)
	_boardwalks(plan)
	_dry_things(plan)
	var shape := VillageShape.measure(plan)
	stats["over_water_share"] = float(shape.get("over_water_share", 0.0))
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings, "stats": stats}


func _piles(plan: VillagePlan) -> void:
	var piled := 0
	for bi in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[bi]
		var li: int = int(b["lot"])
		var lot: Dictionary = plan.lots[li]
		if not lot.has("piles"):
			continue
		piled += 1
		var p: Dictionary = lot["piles"]
		var req: BuildingRequest = b["request"]
		if not VillageWaterForm.wholly_wet(plan, lot["poly"]):
			failures.append("piles: lot %d is not wholly on the water" % li)
		if float(p["water_m"]) > HousePiles.MAX_WATER_M + 1e-6:
			failures.append("piles: lot %d stands in %.2f m of water, past the piles' %.1f" % [li, float(p["water_m"]), HousePiles.MAX_WATER_M])
		if not VillageWaterForm.is_boardwalk(plan.roads[int(lot["road"])]):
			failures.append("piles: lot %d fronts %s %d, not a boardwalk" % [li, String(plan.roads[int(lot["road"])]["class"]), int(lot["road"])])
		if req.foundation != &"piles" or absf(req.pile_water_m - float(p["water_m"])) > 1e-6 \
				or absf(req.pile_deck_m - float(p["reach_m"])) > 0.002:
			failures.append("piles: building %d was not asked for its lot's piles (%s, %.2f m deep, landing %.2f m)"
				% [bi, req.foundation, req.pile_water_m, req.pile_deck_m])
		if not BuildingLibrary.validate(req).is_empty():
			failures.append("piles: building %d's request is refused: %s" % [bi, BuildingLibrary.validate(req)])
	stats["pile_buildings"] = piled


func _boardwalks(plan: VillagePlan) -> void:
	var walks := 0
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		if not VillageWaterForm.is_boardwalk(road):
			continue
		walks += 1
		if road["class"] != &"path":
			failures.append("boardwalks: road %d is a boardwalk of class %s" % [r, String(road["class"])])
		var wet := 0.0
		for w in plan.water:
			if w["kind"] == &"race":
				continue
			for piece in Geometry2D.intersect_polygons(VillageSitePlanner.road_ribbon(road, false), w["poly"]):
				wet += Poly.area(piece)
		var carried := 0
		for c in plan.water_crossings:
			if int(c["road"]) != r:
				continue
			carried += 1
			if c["kind"] != &"boardwalk" or absf(float(c["width"]) - VillageWaterPlan.crossing_width(road)) > 1e-6:
				failures.append("boardwalks: road %d's crossing is a %s %.2f m wide" % [r, String(c["kind"]), float(c["width"])])
		if wet > 0.05 and carried == 0:
			failures.append("boardwalks: road %d is %.1f m2 over the water with no boardwalk under it" % [r, wet])
	stats["boardwalks"] = walks


func _dry_things(plan: VillagePlan) -> void:
	var wet: Array[String] = []
	for p in plan.props:
		var key := String(p["key"])
		if key in ["boat"]:
			continue
		if _in_water(plan, p["pos"]):
			wet.append(key)
	for t in plan.plants:
		if bool(t.get("marginal", false)):
			continue
		if _in_water(plan, t["pos"]) and float(t.get("trunk", 0.0)) > 0.0:
			wet.append(String(t["key"]))
	stats["things_in_water"] = wet.size()
	if not wet.is_empty():
		failures.append("dry_things: %d props or trees stand in the water: %s" % [wet.size(), ", ".join(wet.slice(0, 6))])


static func _in_water(plan: VillagePlan, p: Vector2) -> bool:
	for w in plan.water:
		if w["kind"] == &"race":
			continue
		if Poly.contains_point(w["poly"], p):
			return true
	return false


# ------------------------------------------------------------------ the mesh

## The pile houses and the boardwalks against the emitted ground (`probe`:
## VillageGroundCheck.GroundProbe over the scene's Ground mesh). Appends to
## the ground check's own failures and stats.
static func ground(plan: VillagePlan, scene: Node3D, probe: Object, failures: Array[String],
		stats: Dictionary) -> void:
	var level: float = plan.ground.water_level_m if plan.ground != null else NAN
	if is_nan(level):
		return
	var parent := scene.get_node_or_null("Buildings")
	var houses := 0
	var faults: Array[String] = []
	var worst_over := -INF
	var worst_short := -INF
	if parent != null:
		for node in parent.get_children():
			var bi := _index_of(node)
			if bi < 0 or bi >= plan.buildings.size():
				continue
			var b: Dictionary = plan.buildings[bi]
			var lot: Dictionary = plan.lots[int(b["lot"])]
			if not lot.has("piles"):
				continue
			houses += 1
			var p: Dictionary = lot["piles"]
			var deck: float = float(p["deck_m"])
			var y: float = (node as Node3D).transform.origin.y
			if absf(y - deck) > 0.01:
				faults.append("%s stands at %.2f m, its deck is at %.2f m" % [node.name, y, deck])
				continue
			var foot: float = deck - float(p["freeboard_m"]) - float(p["water_m"]) - HousePiles.EMBED_M
			var under: Array[PackedVector2Array] = [VillageMeasure.footprint_poly(b), p["landing"]]
			for poly in under:
				for q in _lattice(poly):
					var top: float = probe.top(q)
					if is_nan(top):
						continue
					worst_over = maxf(worst_over, top - level)
					worst_short = maxf(worst_short, foot - top)
					if top > level + TOL:
						faults.append("%s: ground %.2f m over the water under it at (%.1f, %.1f)" % [node.name, top - level, q.x, q.y])
						break
					if foot > top + TOL:
						faults.append("%s: its piles stop %.2f m above the bed at (%.1f, %.1f)" % [node.name, foot - top, q.x, q.y])
						break
	var walks := 0
	for c in plan.water_crossings:
		if c["kind"] != &"boardwalk":
			continue
		walks += 1
		var ribbon := Poly.ribbon(c["points"], (float(c["width"]) + VillageBuilder.BRIDGE_MARGIN) * 0.5)
		for q in _lattice(ribbon):
			var top: float = probe.top(q)
			if is_nan(top):
				continue
			var sw: float = probe.water_top(q)
			if is_nan(sw):
				continue
			worst_over = maxf(worst_over, top - level)
			if top > level + TOL:
				faults.append("boardwalk on road %d: ground %.2f m over the water under its deck at (%.1f, %.1f)"
					% [int(c["road"]), top - level, q.x, q.y])
				break
	stats["pile_houses"] = houses
	stats["boardwalk_crossings"] = walks
	stats["pile_ground_over_water"] = snappedf(worst_over, 0.001) if worst_over > -INF else 0.0
	stats["pile_foot_short"] = snappedf(worst_short, 0.001) if worst_short > -INF else 0.0
	for f in faults.slice(0, 8):
		failures.append("piles: " + f)
	if faults.size() > 8:
		failures.append("piles: and %d more" % (faults.size() - 8))


static func _lattice(poly: PackedVector2Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var box := Poly.bounding_rect(poly)
	var y := box.position.y + 0.25
	while y < box.end.y:
		var x := box.position.x + 0.25
		while x < box.end.x:
			var q := Vector2(x, y)
			if Poly.contains_point(poly, q):
				out.append(q)
			x += SAMPLE_M
		y += SAMPLE_M
	return out


static func _index_of(node: Node) -> int:
	var parts := String(node.name).split("_")
	if parts.size() < 2 or not parts[parts.size() - 1].is_valid_int():
		return -1
	return int(parts[parts.size() - 1])
