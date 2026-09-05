class_name TowerCheck
extends RefCounted
## Is it a tower house? (CAS-006; WORLD_BUILDINGS 1.3)
##
## A tower house is the house tier grown up instead of out: one tall block,
## an L or Z jog off it, no curtain. Four rules say what makes it one, each
## measured from the masses and openings the builder logged, never from the
## spec's intentions alone:
##
##   SLENDER   it is a tower: the block stands at least four times as tall as
##             its longer side (the Bologna type, whose base is 10 m or less),
##             or twice as tall for the broader Scottish type
##   LIFT      the only way in is a raised door, its sill 2 m or more above
##             the ground, and no opening at all sits lower than that
##   FOOT      the walls at the foot are half as thick again as at the top
##   NO GAPS / GROUNDED  the structural rules every building gets
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := MassRules.TOL
const LIFT_MIN := 2.0
const FOOT_RATIO := 1.5
const BOLOGNA_BASE_MAX := 10.0
const SLENDER := {&"bologna": 4.0, &"scottish": 2.0}

const RULES: Array[StringName] = [&"slender", &"lift", &"foot", &"no_gaps", &"grounded"]
const METHODS := {&"no_gaps": "_check_gaps"}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(spec: CastleSpec, builder: CastleBuilder, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	if not CastleGeometry.is_tower_house(spec):
		failures.append("tower: the plan is %s, not a tower house" % String(spec.plan_kind))
		return _report()
	replaced = RuleSet.run(self, RULES, METHODS, overrides, [spec, builder],
		[spec, builder], failures, warnings)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


func _check_slender(spec: CastleSpec, builder: CastleBuilder) -> void:
	var hall: AABB = builder.mass_aabb("hall")
	if hall.size.y <= 0.0:
		failures.append("slender: no hall mass to measure")
		return
	var base: float = maxf(hall.size.x, hall.size.z)
	var want: float = float(SLENDER.get(spec.tower_type, 4.0))
	stats["slenderness"] = snappedf(hall.size.y / maxf(base, 0.01), 0.01)
	if hall.size.y < want * base - TOL:
		failures.append("slender: a %s tower %.1fm high on a %.1fm base is %.1fx, wants %.0fx"
			% [String(spec.tower_type), hall.size.y, base, hall.size.y / maxf(base, 0.01), want])
	if spec.tower_type == &"bologna" and base > BOLOGNA_BASE_MAX + TOL:
		failures.append("slender: a Bologna tower on a %.1fm base; they are %.0fm or less"
			% [base, BOLOGNA_BASE_MAX])


func _check_lift(_spec: CastleSpec, builder: CastleBuilder) -> void:
	var doors := 0
	var lowest := INF
	for p in builder.part_log:
		if p["kind"] != "window":
			continue
		var sill: float = float((p["pos"] as Vector3).y) - float((p["size"] as Vector3).y) / 2.0
		if p["tag"] == "door":
			doors += 1
			if sill < LIFT_MIN - TOL:
				failures.append("lift: the door sill is %.2fm up; a tower house is entered at %.0fm or more"
					% [sill, LIFT_MIN])
		lowest = minf(lowest, sill)
	stats["lowest_opening"] = snappedf(lowest, 0.01) if lowest < INF else 0.0
	if doors != 1:
		failures.append("lift: %d doors; a tower house has one raised door" % doors)
	if lowest < LIFT_MIN - TOL:
		failures.append("lift: an opening %.2fm from the ground, below the %.0fm a ladder reaches"
			% [lowest, LIFT_MIN])


func _check_foot(spec: CastleSpec, builder: CastleBuilder) -> void:
	var hall: AABB = builder.mass_aabb("hall")
	var interior: float = hall.size.x - 2.0 * spec.wall_thickness
	var lowest := AABB()
	var highest := AABB()
	for m in builder.mass_log:
		if not String(m["name"]).begins_with("storey_"):
			continue
		var a: AABB = m["aabb"]
		if lowest.size.y <= 0.0 or a.position.y < lowest.position.y:
			lowest = a
		if highest.size.y <= 0.0 or a.position.y > highest.position.y:
			highest = a
	if lowest.size.y <= 0.0:
		failures.append("foot: no storey masses to measure the walls from")
		return
	var t_foot: float = (lowest.size.x - interior) / 2.0
	var t_top: float = (highest.size.x - interior) / 2.0
	stats["wall_foot"] = snappedf(t_foot, 0.01)
	stats["wall_top"] = snappedf(t_top, 0.01)
	if t_foot < t_top * FOOT_RATIO - TOL:
		failures.append("foot: the walls are %.2fm at the foot and %.2fm at the top; the foot wants %.1fx"
			% [t_foot, t_top, FOOT_RATIO])


func _check_gaps(_spec: CastleSpec, builder: CastleBuilder) -> void:
	var g: Dictionary = MassRules.gaps(builder.mass_log, "hall")
	for f in g["failures"]:
		failures.append(str(f))
	stats["masses_joined"] = g["joined"]


## The upper storeys and the roof platform are carried by the storey below.
func _check_grounded(_spec: CastleSpec, builder: CastleBuilder) -> void:
	var carried: Array = ["platform"]
	for m in builder.mass_log:
		var nm: String = m["name"]
		if nm.begins_with("storey_") and nm != "storey_0":
			carried.append(nm)
	for f in MassRules.grounded(builder.mass_log, carried):
		failures.append(str(f))
