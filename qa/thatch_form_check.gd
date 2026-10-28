class_name ThatchFormCheck
extends RefCounted
## WITCH-THATCH-FORM: does the thatch read as thatch? A walker called the witch
## roof "something with thatch that does not make sense: thatch has round
## corners and a brush end". Four measurable traits, read off the component log:
##  1. every eave bundle is a round section (>= MIN_ROUND_POINTS vertices, no
##     vertex turning more than MAX_TURN_DEG): the old five-point hump turned
##     by 90 degrees and more at its corners;
##  2. every ridge roll crowns smoothly (the highest vertex turns at most
##     MAX_TURN_DEG): the old tent had a sharp apex that read as a spike;
##  3. a gable roof has a rolled bundle up each of its four rakes;
##  4. the reed ends are brushed: many `thatch_brush` pieces under the edges, of
##     many different lengths (a regular fringe is a dentil course, not reeds).

const MIN_ROUND_POINTS := 12
const MAX_TURN_DEG := 45.0
const MIN_BRUSH := 24
const MIN_BRUSH_LENGTHS := 6


## {ok, failures:PackedStringArray, eaves:int, rolls:int, verges:int, brush:int}
static func check(builder: MassBuilder, expect_verges := true) -> Dictionary:
	var failures := PackedStringArray()
	var eaves := 0
	var rolls := 0
	var verges := 0
	var brush := 0
	var lengths := {}
	for row in builder.component_log:
		var role := String(row["role"]).split("#")[0]
		if row["form"] == "slab":
			var points: PackedVector3Array = row["points"]
			if role == "thatch_eave":
				eaves += 1
				if points.size() < MIN_ROUND_POINTS or max_turn_deg(points) > MAX_TURN_DEG:
					failures.append("%s is not round: %d points, sharpest corner %.0f deg" % [
						row["id"], points.size(), max_turn_deg(points)])
			elif role.begins_with("thatch_roll_"):
				rolls += 1
				var crown := crown_turn_deg(points)
				if crown > MAX_TURN_DEG:
					failures.append("%s has a sharp apex: %.0f deg turn at the crown" % [
						row["id"], crown])
			elif role == "thatch_verge":
				verges += 1
				if points.size() < MIN_ROUND_POINTS or max_turn_deg(points) > MAX_TURN_DEG:
					failures.append("%s is not round" % row["id"])
		elif row["form"] == "box" and role == "thatch_brush":
			brush += 1
			lengths[snappedf(float((row["size"] as Vector3).y), 0.01)] = true
	if expect_verges and verges != 4:
		failures.append("%d rolled verges, wanted 4 (two rakes on each of two gables)" % verges)
	if brush < MIN_BRUSH:
		failures.append("only %d brushed reed ends (wanted %d)" % [brush, MIN_BRUSH])
	elif lengths.size() < MIN_BRUSH_LENGTHS:
		failures.append("the brushed ends come in only %d lengths (wanted %d)" % [
			lengths.size(), MIN_BRUSH_LENGTHS])
	return {"ok": failures.is_empty(), "failures": failures, "eaves": eaves,
		"rolls": rolls, "verges": verges, "brush": brush}


## The largest turn, in degrees, at any vertex of a closed polygon.
static func max_turn_deg(points: PackedVector3Array) -> float:
	var worst := 0.0
	var n := points.size()
	for i in range(n):
		worst = maxf(worst, _turn(points[(i + n - 1) % n], points[i], points[(i + 1) % n]))
	return worst


## The turn at the highest vertex of a profile (the crown of a roll).
static func crown_turn_deg(points: PackedVector3Array) -> float:
	var n := points.size()
	if n < 3:
		return 180.0
	var top := 0
	for i in range(n):
		if points[i].y > points[top].y:
			top = i
	return _turn(points[(top + n - 1) % n], points[top], points[(top + 1) % n])


static func _turn(a: Vector3, b: Vector3, c: Vector3) -> float:
	var u := (b - a).normalized()
	var v := (c - b).normalized()
	return rad_to_deg(acos(clampf(u.dot(v), -1.0, 1.0)))
