class_name TempleQA
extends RefCounted
## The whole temple harness in one call: does it stand up, and does it work as
## a temple.
##
## The first half is MassRules, the same three structural rules the churches
## and castles are held to, with a joint table saying which of a temple's
## masses are allowed to interpenetrate. The second half is TempleRiteCheck,
## which is where everything that makes this generator different lives.
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const FAMILIES := ["floor", "wall", "column", "dais", "altar", "idol", "cell",
	"bridge", "terrace", "stair", "pylon", "obelisk"]


## Designed interpenetration, in metres of penetration depth. INF marks a
## joint meant to pass fully through: a temple is a pile of masonry standing on
## and inside other masonry, and writing that down here is what leaves the
## check able to catch the pairs that are NOT supposed to touch -- a column
## through the altar, two columns in the same square metre.
##
## A pair absent from the table must not touch at all.
const JOINTS := {
	# things that stand on the floor, and the floor they stand on
	"altar|floor": INF, "column|floor": INF, "dais|floor": INF, "floor|idol": INF,
	"bridge|floor": INF, "cell|floor": INF, "floor|stair": INF, "floor|obelisk": INF,
	"floor|pylon": INF, "floor|wall": INF, "floor|terrace": INF, "floor|floor": INF,
	# the sanctuary group: the altar and the god stand ON the dais
	"altar|dais": INF, "dais|idol": INF,
	# a stepped mountain is terraces inside terraces, with a stair up it, and
	# the chamber inside its lowest terrace holds everything a temple holds
	"terrace|terrace": INF, "stair|terrace": INF, "stair|wall": INF,
	"column|terrace": INF, "dais|terrace": INF, "altar|terrace": INF,
	"idol|terrace": INF, "cell|terrace": INF, "bridge|terrace": INF,
	"stair|stair": 0.0,
	# an alcove is cut INTO the wall it opens off
	"cell|wall": INF, "pylon|wall": INF, "obelisk|wall": INF, "bridge|dais": INF,
	# and the pairs that must stand clear of one another
	"column|column": 0.0, "altar|column": 0.0, "column|idol": 0.0,
	"altar|idol": 0.0, "cell|cell": 0.0, "cell|column": 0.0,
	"column|dais": 0.0, "wall|wall": 0.0,
}


static func _allowance(a: String, b: String) -> float:
	var key: String = "|".join(PackedStringArray([a, b]) if a < b else PackedStringArray([b, a]))
	return float(JOINTS.get(key, 0.0))


## `overrides` lets a family replace one of the rite's rules by name
## (RuleSet, INT-020); the report says which under "replaced".
func check(spec: TempleSpec, builder: TempleBuilder, overrides: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = []
	var warnings: Array[String] = []
	var stats := {}
	for bad in RuleSet.unknown(overrides, [TempleRiteCheck.RULES]):
		failures.append("rules: no temple rule is called %s" % bad)

	var masses: Array[Dictionary] = builder.mass_log
	stats["masses"] = masses.size()
	stats["props"] = builder.prop_log.size()
	if masses.is_empty():
		failures.append("massing: the builder logged no structural masses")
		return {"ok": false, "failures": failures, "warnings": warnings, "stats": stats}

	var gaps: Dictionary = MassRules.gaps(masses, "floor")
	for f in gaps["failures"]:
		failures.append(str(f))
	var over: Dictionary = MassRules.overlaps(masses,
		func(a: String, b: String) -> float: return _allowance(a, b), FAMILIES)
	for o in over["failures"]:
		failures.append(str(o))
	stats["worst_penetration"] = over["worst"]
	# the pit throat and the bridge deck are the only things below the floor,
	# and neither is a mass; everything else stands on the ground
	for g in MassRules.grounded(masses, ["bridge"]):
		failures.append(str(g))

	var rite: Dictionary = TempleRiteCheck.new().check(spec, builder, overrides)
	for f2 in rite["failures"]:
		failures.append(str(f2))
	for w in rite["warnings"]:
		warnings.append(str(w))
	for k in rite["stats"]:
		stats[k] = rite["stats"][k]

	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": rite.get("replaced", {})}
