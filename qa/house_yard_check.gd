class_name HouseYardCheck
extends RefCounted
## Is the yard fit to stand in? (EVAL-B06)
##
## Four rules over what `HouseYard` planned, each a sentence and a measurement.
## The planner tries to place well; this refuses to believe it did, and
## re-derives every box from the records alone:
##
##   KNOWN     every yard prop is a catalogue key with measured dimensions, and
##             every built piece is a known kind whose every part is a logged
##             `component_log` row on host "yard" (when a builder is given)
##   CLEAR     nothing stands in a door approach, under a window's drip and
##             shutter, in the chimney or on the porch: the SAME function the
##             facade recipes use (HouseExterior.facade_clear)
##   ENVELOPE  everything lies inside the yard envelope, the shell footprint
##             grown by the apron; the lot owns the rest
##   ACCESS    a person can walk from the road edge to the front door (and every
##             other ground-floor exterior door) round the yard's own props, on
##             WalkGrid -- the one distance transform, not a second copy
##
## `HouseYardCheck.check()` returns failure strings that name the record:
## "yard <id> role=<role> host=<host> key=<key>: <reason>".

const RULES: Array[StringName] = [&"known", &"clear", &"envelope", &"access"]


static func check(plan: HousePlan, builder = null) -> Array[String]:
	var out: Array[String] = []
	if not plan.spec.exterior_props:
		return out
	out.append_array(known(plan, builder))
	out.append_array(clear(plan))
	out.append_array(envelope(plan))
	out.append_array(access(plan))
	return out


static func _who(kind: String, rec: Dictionary) -> String:
	return "yard %s role=%s host=%s %s" % [rec.get("id", "?"), rec.get("role", "?"),
		rec.get("host", "?"), ("key=%s" % rec["key"]) if rec.has("key") else ("kind=%s" % rec.get("kind", "?"))]


## Rule 1: known keys and logged components.
static func known(plan: HousePlan, builder = null) -> Array[String]:
	var out: Array[String] = []
	for p in plan.yard:
		var key: String = str(p.get("key", ""))
		var size := PropCatalog.size(key)
		if not PropCatalog.known(key) or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			out.append(_who("prop", p) + ": known: not a measured catalogue key")
			continue
		var measured := HouseExterior.bounds_of(p)
		var recorded: AABB = p.get("bounds", AABB())
		if measured.position.distance_to(recorded.position) > 0.005 \
				or measured.size.distance_to(recorded.size) > 0.005:
			out.append(_who("prop", p) + ": known: recorded bounds differ from measured placement")
	var logged: Array[Dictionary] = []
	if builder != null:
		for row in builder.component_log:
			if row["host"] == "yard":
				logged.append(row)
	var expected := 0
	for piece in plan.yard_pieces:
		if str(piece.get("kind", "")) not in HouseYard.KINDS:
			out.append(_who("piece", piece) + ": known: not a built yard kind")
		for part in piece["parts"]:
			expected += 1
			if builder == null:
				continue
			if not _logged(logged, piece, part):
				out.append(_who("piece", piece) + ": known: part %s has no logged yard component" % part["role"])
	if builder != null and logged.size() != expected:
		out.append("yard: %d logged yard components for %d planned parts" % [logged.size(), expected])
	return out


static func _logged(rows: Array[Dictionary], piece: Dictionary, part: Dictionary) -> bool:
	for row in rows:
		if str(row["role"]) != str(part["role"]) or str(row.get("piece", "")) != str(piece["id"]):
			continue
		var xf: Transform3D = row["xf"]
		if xf.origin.distance_to(part["centre"]) < 0.002 \
				and (row["size"] as Vector3).distance_to(part["size"]) < 0.002:
			return true
	return false


## Every measured box in the yard with the record it came from.
static func boxes(plan: HousePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in plan.yard:
		out.append({"who": _who("prop", p), "box": HouseExterior.bounds_of(p)})
	for piece in plan.yard_pieces:
		for part in piece["parts"]:
			out.append({"who": _who("piece", piece) + " part=%s" % part["role"],
				"box": HouseYard.part_aabb(part)})
	return out


## Rule 2: nothing in a door approach or a window's drip, shutter or hood.
static func clear(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	var env := HouseGeometry.yard_rect(plan)
	for item in boxes(plan):
		var box: AABB = item["box"]
		var why := HouseYard.clear_reason(plan, env, box)
		if why.is_empty() or why == "outside the yard envelope":
			continue
		out.append("%s: clear: %s" % [item["who"], why])
	return out


## Rule 3: inside the envelope.
static func envelope(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	var env := HouseGeometry.yard_rect(plan)
	for item in boxes(plan):
		if HouseYard.clear_reason(plan, env, item["box"]) == "outside the yard envelope":
			out.append("%s: envelope: outside the yard envelope %s" % [item["who"], env])
	return out


## Rule 4: the road reaches every ground exterior door, round the yard's props.
static func access(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	if plan.entrance() < 0:
		return out
	if not HouseYard.access_ok(plan):
		out.append("yard: access: a ground-floor exterior door cannot be reached from the road edge")
	return out
