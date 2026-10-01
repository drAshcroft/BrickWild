class_name CastleMassingCheck
extends RefCounted
## Correctness checks over a CASTLE's structural masses. The three structural
## rules come from MassRules; what lives here is the castle's joint table, the
## dimensions its spec asked for, and the one rule a fortification adds:
##
##   ENCLOSED    a walled tier must actually be walled -- four runs of curtain,
##               a gate through them, and every ward tied to the one outside it
##   GREAT_TOWER when the spec names one, exactly one tower of the outer ring
##               stands head and shoulders over the rest (CAS-002)
##   RANGES      the hall looks into the bailey and not through its curtain;
##               the chapel has its apse (CAS-003)
##   BAILEY_CLEAR what stands in the yard keeps its distance: BAILEY_CLEAR from
##               the curtain and from everything already built, and nothing
##               across the way from the gate to the keep (CAS-012)
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := MassRules.TOL
## Mass name prefixes that fold to a family for the joint table below.
const FAMILIES := ["wall_stair", "wall", "tower", "portcullis", "forebuilding", "drawbridge", "gate", "barbican", "keep", "hall", "chapel",
	"apse", "wing", "range", "porch", "chimney", "annexe", "link", "storey",
	"platform", "balcony", "motte", "climb", "rock", "sky_tower", "sky_bridge"]

## The rules, in the order they run; a family may replace one through
## `check(spec, builder, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"no_gaps", &"no_overlap", &"grounded",
	&"size_match", &"enclosed", &"great_tower", &"ranges", &"motte", &"sky",
	&"bailey_clear", &"facade", &"wall_stairs", &"forebuilding", &"bergfried",
	&"terraced"]
const METHODS := {&"no_gaps": "_check_gaps", &"no_overlap": "_check_overlaps",
	&"enclosed": "_check_enclosure", &"bergfried": "_check_bergfried",
	&"terraced": "_check_terraced"}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


## Designed interpenetration per joint, in metres of penetration depth. A pair
## absent from this table is expected NOT to overlap at all; INF marks a
## crossing meant to pass fully through.
static func _allowance(a: String, b: String, polygonal := false, tower_lap := -1.0,
		ridge := false, terraced := false) -> float:
	var key: String = "|".join(PackedStringArray([a, b]) if a < b else PackedStringArray([b, a]))
	if terraced:
		if a == "terrace" or b == "terrace":
			# The polygon fill is an earthwork envelope, not a solid box. Its AABB
			# intentionally contains the nested rings and structures on the terrace.
			return INF
		if key in ["gate|terrace_stair_1", "link|terrace_stair_1"]:
			# The single flight crosses only the logged gate passage and its link.
			# cterrace checks emitted passage rays and stair body clearance before
			# accepting this AABB-only joint. Other stair intersections stay strict.
			return INF
	# On a receding keep, the forebuilding landing rests on the exposed
	# ground-storey shoulder. Physical access QA checks the hollow stair route.
	if key == "forebuilding|keep":
		return INF
	# a motte and bailey (CAS-005): the mound is a cone logged as the box
	# round it, so everything it touches -- the keep on it, the curtain up it,
	# the bailey's back wall and towers at its toe -- meets that box; the
	# `motte` rule is what proves the keep stands on the top and nothing else
	# stands on the slope
	if a == "motte" or b == "motte":
		return INF
	if a.begins_with("sky_") or b.begins_with("sky_"):
		return INF
	match key:
		"climb|keep", "climb|wall", "climb|tower":
			return INF
	if ridge:
		# a ridge castle (CAS-007): every range is a rotated box logged as
		# the box round it, and consecutive ranges meet inside the tower at
		# their shared vertex. The towers resolve those joints; the voxel
		# sweep proves the ridge is continuous.
		match key:
			"range|range", "hall|range", "hall|tower", "range|tower", "hall|keep", "keep|range", "keep|tower":
				return INF
			"tower|tower":
				return 0.0
	if tower_lap >= 0.0:
		# a tower house (CAS-006): the shaft is logged whole as the hall and
		# storey by storey inside it, the platform sits on the top storey and
		# the jog laps the shaft like a wing -- deeper into the foot storeys,
		# which are wider than the shaft by the thickening of their walls
		match key:
			"hall|storey", "hall|platform", "balcony|hall":
				return INF
			"balcony|storey":
				return INF
			"storey|storey", "platform|storey":
				return 0.0
			"hall|wing":
				return CastleGeometry.WING_LAP
			"storey|wing":
				return tower_lap
			"platform|wing", "wing|wing":
				return 0.0
	if polygonal:
		# A slanted run is a rotated box, and the AABB the mass log has to
		# record for it is a box round a box. Two runs meeting at a vertex, and
		# a range built against a run, therefore "interpenetrate" in a way that
		# says nothing about the masonry -- the vertex towers are what actually
		# resolve those joints, and the voxel sweep is what proves the wall line
		# is continuous. Only these AABB-of-a-diagonal pairs are relaxed.
		match key:
			"wall|wall":
				return INF
			"hall|wall", "chapel|wall", "keep|wall", "apse|wall":
				return INF
			"keep|tower", "chapel|tower", "hall|tower":
				# a vertex tower IS part of the run it stands on, so a range built
				# against that run meets the tower along with it
				return INF
	match key:
		"gate|portcullis":
			return INF # The guide is recessed inside the gatehouse masonry.
		"wall|wall_stair":
			# Rotated stair and curtain AABBs overlap although their actual
			# solids meet at the inner face. The access rule measures treads.
			return INF
		# --- the enceinte: walls die into the towers and gate that stud them ---
		"tower|wall", "gate|wall", "gate|tower":
			return INF
		"barbican|gate", "barbican|tower":
			return INF                        # the outwork ties into the gate
		"gate|link", "link|tower", "link|wall":
			return INF                        # the causeway lands on both gates
		"causeway|drawbridge":
			return INF                        # the stone approach meets its timber span

		# --- ranges built against a curtain lap it, and its towers with it ---
		"keep|wall", "hall|wall", "chapel|wall":
			return CastleGeometry.RANGE_LAP
		"apse|chapel":
			return INF                        # the apse springs from inside the chapel
		"keep|tower", "hall|tower", "chapel|tower":
			return CastleGeometry.RANGE_LAP

		# --- house and manor: one range laps the next ---
		"hall|wing", "range|wing", "annexe|hall", "chimney|hall", "hall|porch":
			return CastleGeometry.WING_LAP
		"hall|range", "chimney|range", "annexe|wing":
			return CastleGeometry.WING_LAP
		"porch|range", "porch|wing":
			return INF                        # the passage runs through the range
		"hall|tower", "tower|wing", "range|tower":
			return INF                        # a manor tower is built into its range

		# --- everything below must stand clear ---
		"wall|wall":
			return 0.0                        # runs meet at their faces
		"tower|tower":
			return 0.0                        # towers must not collide
		"gate|gate":
			return 0.0                        # outer and inner gatehouses are apart
		"hall|keep", "chapel|keep", "chapel|hall":
			return 0.0                        # ranges touch, they do not merge
		"link|link", "wing|wing":
			return 0.0
	return 0.0


func check(spec: CastleSpec, builder: CastleBuilder, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()

	var masses: Array[Dictionary] = builder.mass_log
	stats["masses"] = masses.size()
	stats["tier"] = String(spec.tier)
	if masses.is_empty():
		failures.append("massing: builder logged no structural masses")
		return _report()
	replaced = RuleSet.run(self, RULES, METHODS, overrides, [spec, builder],
		[spec, builder], failures, warnings)
	return _report()


## A raised ward is sound only when its mass, ground metadata, connecting
## stair and Himeji height relationship agree with the built geometry.
func _check_terraced(spec: CastleSpec, builder: CastleBuilder) -> void:
	if spec.plan_kind != &"terraced":
		return
	if not spec.inner_ward:
		failures.append("terrace: inner polygon ring is missing")
		return
	var rise: float = CastleGeometry.ring_ground_y(spec, 1)
	var terrace := builder.mass_aabb("terrace")
	if terrace.size.y < 3.0 - TOL or absf(terrace.position.y) > TOL \
			or absf(terrace.end.y - rise) > TOL:
		failures.append("terrace: logged fill does not span ground to raised floor")
	var inner_count := 0
	for mass in builder.mass_log:
		var nm: String = mass["name"]
		if nm.begins_with("wall_1_") or nm.begins_with("gate_1") \
				or nm.begins_with("tower_1_"):
			inner_count += 1
			if absf(float(mass.get("ground", -INF)) - rise) > TOL \
					or absf((mass["aabb"] as AABB).position.y - rise) > TOL:
				failures.append("terrace: %s is not grounded on the raised floor" % nm)
	if inner_count == 0:
		failures.append("terrace: no elevated curtain mass was logged")
	var stair := builder.mass_aabb("terrace_stair_1")
	var outer_gate: AABB = CastleGeometry.gatehouse_aabb(spec, 0)
	var inner_gate: AABB = CastleGeometry.gatehouse_aabb(spec, 1)
	if stair.size.z <= 0.0 or stair.position.z < outer_gate.position.z - 0.15 \
			or stair.position.z > outer_gate.end.z + 0.15 \
			or absf(stair.end.z - inner_gate.position.z) > 0.15 \
			or absf(stair.end.y - rise) > TOL:
		failures.append("terrace: connecting stair does not continuously join the two gate approaches")
	if spec.keep:
		var keep: AABB = builder.mass_aabb("keep")
		var curtain_top := 0.0
		for mass in builder.mass_log:
			var nm2: String = mass["name"]
			if nm2.begins_with("wall_") or nm2.begins_with("gate_"):
				curtain_top = maxf(curtain_top, (mass["aabb"] as AABB).end.y)
		var keep_top: float = keep.end.y + CastleGeometry.roof_rise(spec, keep)
		if absf(keep.position.y - rise) > TOL or keep_top < curtain_top + 10.0 - TOL:
			failures.append("terrace: keep is not on top and 10 m clear of every curtain")
	for mass in builder.mass_log:
		var yard_name: String = mass["name"]
		if yard_name.begins_with("yard_"):
			var yard_box: AABB = mass["aabb"]
			if absf(float(mass.get("ground", -INF)) - rise) > TOL \
					or absf(yard_box.position.y - rise) > TOL:
				failures.append("terrace: %s is not grounded on the raised floor" % yard_name)


## Count occupied HEIGHT BANDS, not windows: a hundred ground-floor slits
## cannot stand in for the missing upper rows of a three-storey range.
## Planned openings here are the child builder's forwarded emission records.
func _check_facade(spec: CastleSpec, builder: CastleBuilder) -> void:
	var bands := 0
	for row in builder.interiors:
		var plan: HousePlan = row.plan
		var xf: Transform3D = row.transform
		var levels: Dictionary = {}
		for room in plan.rooms:
			if room.kind in HouseGeometry.HABITABLE:
				levels[HousePlan.record_storey(room)] = true
		for level in levels:
			var bottom := xf.origin.y + int(level) * plan.spec.height
			var top := bottom + plan.spec.height
			var found := false
			for part in builder.part_log:
				if String(part.get("tag", "")) != String(row.id) or not _facade_window(part):
					continue
				var y: float = Vector3(part.pos).y
				if y > bottom + 0.05 and y < top - 0.05:
					found = true
					break
			bands += 1
			if not found:
				failures.append("facade: %s occupied storey %d has no emitted window in height band %.2f..%.2f" % [row.id, int(level), bottom, top])
	# Ridge ranges retain a tall outer facade above their shorter furnished
	# plan. Those upper rows belong to the castle emitter and must survive too.
	if CastleGeometry.is_ridge(spec):
		var count := CastleGeometry.ridge_storeys(spec)
		for segment in CastleGeometry.ridge_ranges(spec):
			var center: Vector2 = (Vector2(segment.from) + Vector2(segment.to)) * 0.5
			var along: Vector2 = segment.dir
			var normal: Vector2 = segment.normal
			var height: float = float(segment.height) / count
			for level in range(count):
				var found := false
				for part in builder.part_log:
					var label := String(part.get("tag", ""))
					if not label in [String(segment.name), "range", "hall"] or not _facade_window(part):
						continue
					var position: Vector3 = part.pos
					var offset := Vector2(position.x, position.z) - center
					if absf(offset.dot(along)) > float(segment.length) * 0.5 + 0.1 \
							or absf(offset.dot(normal)) > float(segment.width) * 0.5 + 0.2:
						continue
					if position.y > level * height + 0.05 and position.y < (level + 1) * height - 0.05:
						found = true
						break
				bands += 1
				if not found:
					failures.append("facade: ridge %s storey %d has no emitted window in its height band" % [segment.name, level])
	stats["facade_bands"] = bands


static func _facade_window(part: Dictionary) -> bool:
	return String(part.get("kind", "")) == "window" and not bool(part.get("door", false))


func _check_forebuilding(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_enclosed(spec) or not spec.keep or CastleGeometry.is_motte(spec) \
			or spec.plan_kind == &"terraced" or spec.terraced_fallback:
		return
	# Only a first-floor exterior keep entrance needs this stair. Some small
	# occupied shells cannot fit a keep plan at all; an unplanned solid keep has
	# no doorway to protect, so a missing forebuilding is not an access defect.
	var raised_entry := false
	for interior in builder.interiors:
		if interior.id != "keep":
			continue
		var plan: HousePlan = interior.plan
		var entrance := plan.entrance()
		if entrance >= 0 and HousePlan.record_storey(plan.doors[entrance]) == 1:
			raised_entry = true
			break
	if not raised_entry:
		return
	# The stair protects a raised, occupied keep entrance. A tiny keep with no
	# emitted first-floor door has no stair to require or measure.
	if not _has_emitted_raised_keep_door(builder):
		return
	var keep := CastleGeometry.keep_aabb(spec)
	var found := false
	for mass in builder.mass_log:
		if mass.name != "forebuilding":
			continue
		found = true
		var box: AABB = mass.aabb
		if absf(box.position.y) > 0.05 or not box.grow(0.05).intersects(keep):
			failures.append("forebuilding: protected stair must be grounded and contact the keep")
		var top := 0.0
		var tread_count := 0
		for row in builder.component_log:
			if row.host == "forebuilding" and row.role == "forebuilding_tread":
				tread_count += 1
				top = maxf(top, MassBuilder.component_aabb(row).end.y)
		if tread_count < 2 or absf(top - float(mass.get("entry_height", -1.0))) > 0.01:
			failures.append("forebuilding: treads do not reach the protected first-floor entrance")
	if not found:
		failures.append("forebuilding: enclosed keep is missing its protected entrance stair")


func _has_emitted_raised_keep_door(builder: CastleBuilder) -> bool:
	for interior in builder.interiors:
		if String(interior.get("id", "")) != "keep":
			continue
		var plan: HousePlan = interior.get("plan") as HousePlan
		if plan == null or plan.spec == null or plan.room_count() == 0:
			continue
		var entrance := plan.entrance()
		if entrance < 0:
			continue
		var planned_door: Dictionary = plan.doors[entrance]
		if not bool(planned_door.get("exterior", false)) \
				or HousePlan.record_storey(planned_door) != 1:
			continue
		for part in builder.part_log:
			if String(part.get("tag", "")) != "keep":
				continue
			var opening_kind := String(part.get("opening_kind", ""))
			if opening_kind.is_empty():
				opening_kind = String(part.get("kind", ""))
			if opening_kind != "door":
				continue
			var pos: Vector3 = part.get("pos", Vector3.ZERO)
			var size: Vector3 = part.get("size", Vector3.ZERO)
			if pos.y - size.y * 0.5 > 0.05:
				return true
	return false
## CAS-009: the Bergfried is the tallest, the Palas owns the greater volume,
## and the only keep door is raised and faces the Palas roof.
func _check_bergfried(spec: CastleSpec, builder: CastleBuilder) -> void:
	if spec.plan_kind != &"bergfried":
		return
	var keep := builder.mass_aabb("keep")
	var hall := builder.mass_aabb("hall")
	if not _aabb_finite(keep) or not _aabb_finite(hall):
		failures.append("bergfried: keep or Palas bounds contain nonfinite coordinates")
		return
	if keep.size.x <= 0.0 or hall.size.x <= 0.0:
		failures.append("bergfried: keep or Palas mass is missing")
		return
	var ward: PackedVector2Array = CastleGeometry.inner_polygon(spec, CastleGeometry.inner_ring(spec))
	if not _footprint_inside(ward, keep) or not _footprint_inside(ward, hall):
		failures.append("bergfried: keep or Palas base corners lie outside the inner ward")
	if keep.size.x > 10.0 + TOL or keep.size.z > 10.0 + TOL:
		failures.append("bergfried: keep footprint %.1fx%.1fm exceeds 10x10m" % [keep.size.x, keep.size.z])
	if keep.size.y < 3.0 * maxf(keep.size.x, keep.size.z) - TOL:
		failures.append("bergfried: keep height %.1fm is under three times its %.1fm width" % [keep.size.y, maxf(keep.size.x, keep.size.z)])
	var keep_volume: float = keep.size.x * keep.size.y * keep.size.z
	var hall_volume: float = hall.size.x * hall.size.y * hall.size.z
	if hall_volume < 2.0 * keep_volume - TOL:
		failures.append("bergfried: Palas volume %.0fm3 (%.1fx%.1fx%.1fm) is under twice the keep's %.0fm3 (%.1fx%.1fx%.1fm)" % [hall_volume, hall.size.x, hall.size.y, hall.size.z, keep_volume, keep.size.x, keep.size.y, keep.size.z])
	var tallest_other := 0.0
	var largest_other := 0.0
	for mass in builder.mass_log:
		var bounds: AABB = mass.aabb
		if mass.name != "keep":
			tallest_other = maxf(tallest_other, bounds.end.y)
		if mass.name != "hall":
			largest_other = maxf(largest_other, bounds.size.x * bounds.size.y * bounds.size.z)
	tallest_other = maxf(tallest_other, hall.end.y + CastleGeometry.roof_rise(spec, hall))
	if keep.end.y <= tallest_other + TOL:
		failures.append("bergfried: keep does not top every other mass")
	if hall_volume <= largest_other + TOL:
		failures.append("bergfried: Palas is not the largest mass by volume")
	var doors: Array[Dictionary] = []
	for part in builder.part_log:
		if part.get("tag", "") == "keep" and (part.get("kind", "") == "door" or bool(part.get("door", false))):
			doors.append(part)
	if doors.size() != 1:
		failures.append("bergfried: keep has %d exterior door records, wants one" % doors.size())
		return
	var door: Dictionary = doors[0]
	var sill: float = Vector3(door.pos).y - Vector3(door.size).y * 0.5
	var to_hall := Vector3(hall.get_center().x - keep.get_center().x, 0.0,
		hall.get_center().z - keep.get_center().z).normalized()
	var facing: Vector3 = Vector3(door.get("facing", Vector3.ZERO)).normalized()
	if sill < 4.0 - TOL:
		failures.append("bergfried: sole keep door sill %.2fm is below 4m" % sill)
	if facing.dot(to_hall) < 0.8:
		failures.append("bergfried: raised keep door does not face the Palas roof")
	if hall.end.y + CastleGeometry.roof_rise(spec, hall) < sill - TOL:
		failures.append("bergfried: Palas roof is below the raised keep door")


static func _footprint_inside(poly: PackedVector2Array, bounds: AABB) -> bool:
	var corners := [Vector2(bounds.position.x, bounds.position.z),
		Vector2(bounds.end.x, bounds.position.z), Vector2(bounds.end.x, bounds.end.z),
		Vector2(bounds.position.x, bounds.end.z)]
	return corners.all(func(point: Vector2) -> bool: return Poly.contains_point(poly, point, 0.01))


static func _aabb_finite(bounds: AABB) -> bool:
	return [bounds.position.x, bounds.position.y, bounds.position.z,
		bounds.size.x, bounds.size.y, bounds.size.z].all(
		func(value: float) -> bool: return is_finite(value))


func _check_wall_stairs(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_enclosed(spec):
		return
	for ring in CastleGeometry.rings(spec):
		var count := 0
		var near_gate := false
		var gate := CastleGeometry.gatehouse_aabb(spec, ring)
		var target := CastleGeometry.wall_height(spec, ring) + CastleGeometry.PARAPET_RISE
		for mass in builder.mass_log:
			if not String(mass.name).begins_with("wall_stair_") or int(mass.get("ring", -1)) != ring:
				continue
			count += 1
			var box: AABB = mass.aabb
			if absf(box.position.y) > 0.05:
				failures.append("wall_stairs: %s is not grounded" % mass.name)
			var rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			var gate_rect := Rect2(gate.position.x, gate.position.z, gate.size.x, gate.size.z)
			near_gate = near_gate or VillageMeasure.poly_distance(Poly.from_rect(rect), Poly.from_rect(gate_rect)) <= 15.0
			var top := -INF
			var grounded := false
			var touches := false
			for row in builder.component_log:
				if row.host != mass.name or row.role not in ["wall_stair_tread", "wall_stair_landing"]:
					continue
				var emitted := MassBuilder.component_aabb(row)
				top = maxf(top, emitted.end.y)
				grounded = grounded or absf(emitted.position.y) <= 0.05
				if absf(emitted.end.y - target) <= 0.01:
					for wall in builder.mass_log:
						if String(wall.name).begins_with("wall_%d_" % ring):
							touches = touches or emitted.grow(0.16).intersects(wall.aabb)
			if absf(top - target) > 0.01 or not grounded or not touches:
				failures.append("wall_stairs: %s has no grounded tread chain contacting the %.2fm curtain walk" % [mass.name, target])
		if count < 2:
			failures.append("wall_stairs: ring %d has %d stairs, needs two" % [ring, count])
		if not near_gate:
			failures.append("wall_stairs: ring %d has no stair within 15m of its gate" % ring)


## What stands in the bailey keeps its distance (CAS-012).
##
## Measured over the LOGGED masses, not over the layout that produced them: a
## layout pass that agreed with itself and disagreed with the builder is
## exactly what this is here to catch. Four things are asked of every yard
## mass -- it is inside the bailey, it keeps BAILEY_CLEAR from the curtain and
## from everything else built, and it is not across the way in.
func _check_bailey_clear(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_enclosed(spec):
		return
	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	var axis: Rect2 = CastleGeometry.gate_axis_strip(spec)
	var clear: float = CastleGeometry.BAILEY_CLEAR
	var yards: Array[Dictionary] = []
	for m in builder.mass_log:
		if String(m["name"]).begins_with("yard_"):
			yards.append(m)
	stats["yard_buildings"] = yards.size()
	for m in yards:
		var name: String = m["name"]
		var a: AABB = m["aabb"]
		var rect := Rect2(a.position.x, a.position.z, a.size.x, a.size.z)
		if not yard.grow(0.05).encloses(rect):
			failures.append("bailey_clear: %s stands outside the bailey" % name)
		elif not yard.grow(-clear).grow(0.05).encloses(rect):
			failures.append("bailey_clear: %s stands within %.2fm of the curtain"
				% [name, clear])
		if rect.intersects(axis):
			failures.append("bailey_clear: %s stands across the way from the gate"
				% name)
		for other in builder.mass_log:
			if other["name"] == name:
				continue
			# The terraced mass is earthwork supporting the inner ward. Yard
			# buildings stand on its top surface by design; its logged AABB spans
			# the entire fill and is not a clearance obstacle.
			if spec.plan_kind == &"terraced" and other["name"] == "terrace":
				continue
			var ob: AABB = other["aabb"]
			var orect := Rect2(ob.position.x, ob.position.z, ob.size.x, ob.size.z)
			if not orect.intersects(rect.grow(clear)):
				continue
			# the curtain and its towers are the yard's edge, already measured
			if _is_fabric(String(other["name"])):
				continue
			failures.append("bailey_clear: %s is within %.2fm of %s"
				% [name, clear, other["name"]])
	# and the well is out of everybody's way
	for m2 in builder.mass_log:
		if String(m2["name"]) != "well":
			continue
		var w: AABB = m2["aabb"]
		var wc := Vector2(w.position.x + w.size.x / 2.0, w.position.z + w.size.z / 2.0)
		for b in yards:
			var ba: AABB = b["aabb"]
			var brect := Rect2(ba.position.x, ba.position.z, ba.size.x, ba.size.z)
			var d: float = _rect_distance(brect, wc)
			if d < CastleGenerator.WELL_CLEAR - 0.05:
				failures.append("bailey_clear: the well is %.2fm from %s, and wants %.2fm"
					% [d, b["name"], CastleGenerator.WELL_CLEAR])


## Is this mass part of the fortification itself rather than of the yard?
static func _is_fabric(name: String) -> bool:
	for p in ["wall_", "tower_", "gate", "barbican", "link_", "moat", "talus",
			"walk_", "crenel", "causeway", "rock"]:
		if name.begins_with(p):
			return true
	return false


## Distance from a point to the nearest edge of a rectangle; 0 inside it.
static func _rect_distance(rect: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0)
	var dy: float = maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0)
	return Vector2(dx, dy).length()


func _check_gaps(spec: CastleSpec, builder: CastleBuilder) -> void:
	# A yard building and the well stand on their own in the bailey: they are
	# buildings in a courtyard, not part of the fortification (CAS-012).
	var g: Dictionary = MassRules.gaps(builder.mass_log, _anchor(spec),
		["yard_", "well"])
	_add(g["failures"])
	stats["masses_joined"] = g["joined"]


func _check_overlaps(spec: CastleSpec, builder: CastleBuilder) -> void:
	var polygonal: bool = CastleGeometry.is_polygonal(spec)
	var tower_lap := -1.0
	if CastleGeometry.is_tower_house(spec):
		tower_lap = CastleGeometry.WING_LAP \
			+ spec.wall_thickness * (CastleGeometry.TOWER_FOOT_RATIO - 1.0)
	var ridge: bool = CastleGeometry.is_ridge(spec)
	var terraced: bool = spec.plan_kind == &"terraced"
	var o: Dictionary = MassRules.overlaps(builder.mass_log,
		func(a: String, b: String) -> float:
			return _allowance(a, b, polygonal, tower_lap, ridge, terraced),
		FAMILIES)
	_add(o["failures"])
	stats["worst_penetration"] = o["worst"]


func _check_grounded(spec: CastleSpec, builder: CastleBuilder) -> void:
	var carried: Array = []
	if CastleGeometry.is_sky(spec):
		for m in builder.mass_log:
			var sky_name: String = m["name"]
			if sky_name.begins_with("sky_tower_") or sky_name.begins_with("sky_bridge_"):
				carried.append(sky_name)
	if CastleGeometry.is_motte(spec):
		carried.append("keep_shell")     # it stands on the mound
	if CastleGeometry.is_tower_house(spec):
		# the upper storeys and the platform stand on the storey below
		carried.append("platform")
		for m in builder.mass_log:
			var nm: String = m["name"]
			if nm.begins_with("storey_") and nm != "storey_0":
				carried.append(nm)
			elif nm.begins_with("balcony_"):
				carried.append(nm)
	_add(MassRules.grounded(builder.mass_log, carried))


## The mass everything else must be reachable from. A walled tier is anchored
## on its outer curtain; an unwalled one on the hall, which IS the building.
static func _anchor(spec: CastleSpec) -> String:
	if CastleGeometry.is_sky(spec):
		return "rock"
	return "wall_0_back" if CastleGeometry.is_enclosed(spec) else "hall"


func _add(msgs) -> void:
	for m in msgs:
		failures.append(str(m))


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats, "replaced": replaced}


# ------------------------------------------------------------- size match

## The emitted masses must have the dimensions the spec and the tier asked for.
func _check_size_match(spec: CastleSpec, builder: CastleBuilder) -> void:
	var masses: Array[Dictionary] = builder.mass_log
	var by_name := {}
	for m in masses:
		by_name[m["name"]] = m["aabb"]

	if spec.keep and by_name.has("keep"):
		var k: AABB = by_name["keep"]
		_expect("keep width", k.size.x, spec.keep_w)
		_expect("keep depth", k.size.z, spec.keep_l)
		_expect("keep height", k.size.y, spec.keep_height)

	if CastleGeometry.is_enclosed(spec):
		for r in CastleGeometry.rings(spec):
			var h: float = CastleGeometry.wall_height(spec, r)
			for which in CastleGeometry.wall_names(spec, r):
				var key: String = "wall_%d_%s" % [r, String(which)]
				if by_name.has(key):
					_expect("%s height" % key, by_name[key].size.y, h)
			for m2 in masses:
				var nm: String = m2["name"]
				if not nm.begins_with("tower_%d" % r):
					continue
				# a vertex tower is sized for its vertex, which is how the
				# great tower is bigger than the rest
				var vi := -1
				var corner := "tower_%d_corner_" % r
				if nm.begins_with(corner):
					vi = int(nm.substr(corner.length()))
				var th: float = CastleGeometry.tower_height_at(spec, r, vi)
				var s2: float = CastleGeometry.tower_base_half_at(spec, r, vi) * 2.0
				var a: AABB = m2["aabb"]
				_expect("%s height" % nm, a.size.y, th)
				_expect("%s plan" % nm, a.size.x, s2)
	elif CastleGeometry.is_ridge(spec):
		# the ranges are as tall as the wall height; their plan is rotated
		# and measured by the ridge rule below
		if by_name.has("hall"):
			_expect("hall height", by_name["hall"].size.y, spec.height)
		var ti := 0
		for tc in CastleGeometry.ridge_tower_centers(spec):
			var key2 := "tower_0_corner_%d" % ti
			if by_name.has(key2):
				_expect("%s height" % key2, by_name[key2].size.y,
					CastleGeometry.tower_height_at(spec, 0, ti))
			ti += 1
	else:
		var host: AABB = CastleGeometry.house_range_aabb(spec)
		if by_name.has("hall"):
			_expect("hall width", by_name["hall"].size.x, host.size.x)
			_expect("hall height", by_name["hall"].size.y, spec.height)

	# The footprint the user asked for is the one the design must occupy: the
	# enceinte (or the house block) spans the whole site, no more and no less.
	var span := AABB()
	var first := true
	for m3 in masses:
		var b: AABB = m3["aabb"]
		span = b if first else span.merge(b)
		first = false
	stats["plan"] = "%.1f x %.1f" % [span.size.x, span.size.z]
	var want: Rect2 = CastleGeometry.plan_extent(spec)
	if span.size.x > want.size.x + TOL or span.size.z > want.size.y + TOL:
		failures.append("size_match: masses span %.2f x %.2fm, past the %.2f x %.2fm the plan allows"
			% [span.size.x, span.size.z, want.size.x, want.size.y])


# --------------------------------------------------------------- enclosure

## A castle is a wall with something inside it. This is the rule that catches a
## "castle" that generated as four towers and a keep standing in open ground.
func _check_enclosure(spec: CastleSpec, builder: CastleBuilder) -> void:
	if CastleGeometry.is_sky(spec):
		return
	if CastleGeometry.is_ridge(spec):
		_check_ridge(spec, builder)
		return
	if not CastleGeometry.is_enclosed(spec):
		if not builder.has_mass("hall"):
			failures.append("enclosed: a %s must have a hall block" % String(spec.tier))
		return
	for r in CastleGeometry.rings(spec):
		var runs := 0
		for which in CastleGeometry.wall_names(spec, r):
			if builder.has_mass("wall_%d_%s" % [r, String(which)]):
				runs += 1
		if runs < 4:
			failures.append("enclosed: ring %d has %d wall runs, not a closed circuit" % [r, runs])
		if spec.gatehouse and not builder.has_mass("gate_%d" % r):
			failures.append("enclosed: ring %d has no gatehouse to get in by" % r)
	if spec.inner_ward:
		if not (builder.has_mass("link_left") or builder.has_mass("link_right")):
			failures.append("enclosed: inner ward has no causeway joining it to the outer gate")


func _expect(what: String, got: float, want: float) -> void:
	if absf(got - want) > TOL:
		failures.append("size_match: %s is %.2fm, spec asked for %.2fm" % [what, got, want])


# ------------------------------------------------------------- great tower

## When the spec names a great tower, the outer ring has exactly one tower
## that is the tallest by a clear margin -- and it is a vertex tower, not the
## gatehouse drum. Measured from the masses: a spec flag nobody built is
## exactly what this catches.
const GREAT_TOWER_RATIO := 1.3

func _check_great_tower(spec: CastleSpec, builder: CastleBuilder) -> void:
	if CastleGeometry.great_tower_index(spec) < 0:
		return
	var masses: Array[Dictionary] = builder.mass_log
	var tallest := 0.0
	var tallest_name := ""
	var second := 0.0
	var at_top := 0
	for m in masses:
		var nm: String = m["name"]
		if not nm.begins_with("tower_0_"):
			continue
		var h: float = (m["aabb"] as AABB).size.y
		if h > tallest + TOL:
			second = tallest
			tallest = h
			tallest_name = nm
			at_top = 1
		elif absf(h - tallest) <= TOL:
			at_top += 1
		elif h > second:
			second = h
	if tallest_name == "":
		failures.append("great_tower: the spec asks for a great tower and the ring has no towers")
		return
	if at_top != 1:
		failures.append("great_tower: %d towers share the greatest height (%.1fm); a great tower stands alone"
			% [at_top, tallest])
	elif second > 0.0 and tallest < second * GREAT_TOWER_RATIO - TOL:
		failures.append("great_tower: the tallest tower (%s, %.1fm) is only %.2fx the next (%.1fm), wants %.1fx"
			% [tallest_name, tallest, tallest / second, second, GREAT_TOWER_RATIO])
	if "gate" in tallest_name:
		failures.append("great_tower: the tallest tower is the gatehouse drum %s" % tallest_name)
	stats["great_tower"] = tallest_name


# ------------------------------------------------------------------ ranges

## The hall and the chapel look into the bailey (CAS-003): the hall has a row
## of windows on its courtyard face and none through the curtain behind it,
## and a chapel has its apse. Read from the parts and masses the builder
## logged, so a window it placed on the wrong face is counted on that face.
func _check_ranges(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_enclosed(spec) or CastleGeometry.is_sky(spec):
		return
	if spec.hall:
		var hall: AABB = CastleGeometry.hall_aabb(spec)
		var into := 0
		var through := 0
		for p in builder.part_log:
			if p["kind"] != "window" or p["tag"] != "hall":
				continue
			var f: Vector3 = p["facing"]
			if f.x > 0.9:
				into += 1
			elif f.x < -0.9:
				through += 1
		var want: int = mini(3, int(hall.size.z / CastleBuilder.RANGE_BAY))
		if into < want:
			failures.append("hall_windows: the hall has %d windows on its bailey face, wants %d" % [into, want])
		if through > 0:
			failures.append("hall_windows: the hall has %d windows through the curtain it stands against" % through)
	if spec.chapel:
		if CastleGeometry.apse_aabb(spec).size.x <= 0.0:
			warnings.append("chapel_apse: the ward closes in too fast toward the gate for an apse")
		elif not builder.has_mass("apse"):
			failures.append("chapel_apse: the chapel has no apse")
		var chapel_out := 0
		for p2 in builder.part_log:
			if p2["kind"] == "window" and p2["tag"] == "chapel" and (p2["facing"] as Vector3).x > 0.9:
				chapel_out += 1
		if chapel_out > 0:
			failures.append("chapel_apse: the chapel has %d windows through the curtain it stands against" % chapel_out)


# ------------------------------------------------------------------- ridge

## A ridge castle (CAS-007) is a spine with a range on every segment and a
## tower at every vertex, bending 15-45 degrees at each bend, with no bailey,
## gate or freestanding keep, hall or chapel.
func _check_ridge(spec: CastleSpec, builder: CastleBuilder) -> void:
	var pts: PackedVector2Array = CastleGeometry.spine(spec)
	if pts.size() < 3 or pts.size() > 6:
		failures.append("ridge: the spine has %d points, wants 3 to 6" % pts.size())
	for i in range(1, pts.size() - 1):
		var bend: float = rad_to_deg(CastleGeometry.spine_bend(spec, i))
		if bend < 15.0 - 0.5 or bend > 45.0 + 0.5:
			failures.append("ridge: the spine bends %.0f degrees at vertex %d, wants 15 to 45" % [bend, i])
	var ranges: int = 0
	for seg in CastleGeometry.ridge_ranges(spec):
		if builder.has_mass(String(seg["name"])):
			ranges += 1
	if ranges != pts.size() - 1:
		failures.append("ridge: %d ranges on a spine of %d segments" % [ranges, pts.size() - 1])
	for i2 in range(pts.size()):
		var spire_vertex: bool = spec.style == &"dark" and i2 == pts.size() / 2 \
			and builder.has_mass("keep")
		if not spire_vertex and not builder.has_mass("tower_0_corner_%d" % i2):
			failures.append("ridge: no tower at vertex %d of the spine" % i2)
	var banned_names := ["wall_", "gate_", "chapel", "barbican", "link_"]
	if spec.style != &"dark":
		banned_names.append("keep")
	for banned in banned_names:
		if builder.has_mass(banned):
			failures.append("ridge: a ridge castle has no %s mass" % banned)
	if spec.style == &"dark":
		var spire: AABB = builder.mass_aabb("keep")
		if spire.size.y <= 0.0:
			failures.append("ridge: dark fortress has no spire keep")
		elif spire.size.y < spec.height * 2.0 - TOL:
			failures.append("ridge: dark spire is %.1fm high, wants at least twice the %.1fm curtain"
				% [spire.size.y, spec.height])
	stats["spine_length"] = snappedf(CastleGeometry.spine_length(spec), 0.1)


# ------------------------------------------------------------------- motte

## A motte and bailey (CAS-005): the shell keep stands on the mound's flat
## top and nothing else stands on the mound; the keep is the size the spec
## asked for and tops the bailey's curtain by KEEP_DOMINANCE; the climbing
## curtain joins the bailey's back wall to the keep.
func _check_motte(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_motte(spec):
		return
	var mound: AABB = builder.mass_aabb("motte")
	var keep: AABB = builder.mass_aabb("keep_shell")
	if mound.size.y <= 0.0:
		failures.append("motte: no mound was built")
		return
	if keep.size.y <= 0.0:
		failures.append("motte: no shell keep on the mound")
		return
	var c: Vector2 = CastleGeometry.motte_center(spec)
	var rt: float = CastleGeometry.motte_top_radius(spec)
	var top := Rect2(Vector2(c.x - rt, c.y - rt), Vector2(2.0 * rt, 2.0 * rt))
	var foot := Rect2(Vector2(keep.position.x, keep.position.z), Vector2(keep.size.x, keep.size.z))
	if not top.grow(TOL).encloses(foot):
		failures.append("motte: the shell keep stands off the mound's top (%s outside %s)" % [str(foot), str(top)])
	if absf(keep.position.y - mound.size.y) > TOL:
		failures.append("motte: the shell keep's foot is at %.2fm, the mound's top at %.2fm"
			% [keep.position.y, mound.size.y])
	_expect("shell keep width", keep.size.x, spec.keep_w)
	_expect("shell keep depth", keep.size.z, spec.keep_l)
	_expect("shell keep height", keep.size.y, spec.keep_height)
	var want: float = CastleGeometry.wall_height(spec, 0) * CastleGeometry.KEEP_DOMINANCE
	if keep.end.y < want - TOL:
		failures.append("motte: the keep tops out at %.1fm over a %.1fm curtain, wants %.1fx"
			% [keep.end.y, CastleGeometry.wall_height(spec, 0), CastleGeometry.KEEP_DOMINANCE])
	var slope := Rect2(Vector2(mound.position.x, mound.position.z), Vector2(mound.size.x, mound.size.z))
	for m in builder.mass_log:
		var nm: String = m["name"]
		if nm == "motte" or nm == "keep_shell" or nm == "climb":
			continue
		var a: AABB = m["aabb"]
		var mc := Vector2(a.position.x + a.size.x / 2.0, a.position.z + a.size.z / 2.0)
		if a.position.y > TOL and slope.has_point(mc):
			failures.append("motte: %s stands on the mound" % nm)
	var climb: AABB = builder.mass_aabb("climb")
	if climb.size.y <= 0.0:
		failures.append("motte: no curtain climbs from the bailey to the keep")
	else:
		var back: AABB = builder.mass_aabb("wall_0_back")
		if MassRules.separation(climb, back) > MassRules.JOIN_TOL:
			failures.append("motte: the climbing curtain does not meet the bailey's back wall")
		if MassRules.separation(climb, keep) > MassRules.JOIN_TOL:
			failures.append("motte: the climbing curtain does not reach the keep")


# --------------------------------------------------------------------- sky

func _check_sky(spec: CastleSpec, builder: CastleBuilder) -> void:
	if not CastleGeometry.is_sky(spec):
		return
	var rock: AABB = builder.mass_aabb("rock")
	var ground: float = CastleGeometry.sky_ground_level(spec)
	if rock.size.y <= 0.0:
		failures.append("sky: no inverted rock was built under the citadel")
		return
	if absf(rock.end.y - ground) > TOL:
		failures.append("sky: rock top is at %.2fm, building ground is %.2fm"
			% [rock.end.y, ground])
	var minimum_depth: float = maxf(spec.width, spec.length) * 0.5
	if rock.size.y < minimum_depth - TOL:
		failures.append("sky: rock tapers %.1fm from citadel to point, wants at least %.1fm"
			% [rock.size.y, minimum_depth])
	if absf(rock.position.y) > TOL:
		failures.append("sky: floating rock point is at y=%.2f, wants world ground at the point only"
			% rock.position.y)
	for mass in builder.mass_log:
		if mass["name"] == "rock":
			continue
		var a: AABB = mass["aabb"]
		if a.position.y <= TOL:
			failures.append("sky: %s reaches y=%.2f; only the rock may touch world ground"
				% [mass["name"], a.position.y])
		if absf(a.position.y - ground) <= TOL \
				and absf(float(mass.get("ground", 0.0)) - ground) > TOL:
			failures.append("sky: %s is not grounded on the rock top" % mass["name"])
