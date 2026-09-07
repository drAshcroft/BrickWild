import io

p = 'qa/castle_massing_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''##   RANGES      the hall looks into the bailey and not through its curtain;
##               the chapel has its apse (CAS-003)'''
new = '''##   RANGES      the hall looks into the bailey and not through its curtain;
##               the chapel has its apse (CAS-003)
##   BAILEY_CLEAR what stands in the yard keeps its distance: BAILEY_CLEAR from
##               the curtain and from everything already built, and nothing
##               across the way from the gate to the keep (CAS-012)'''
assert old in s, 'doc'
s = s.replace(old, new, 1)

# add the rule to the list, after ranges
old_rules = '&"great_tower", &"ranges", &"motte"]'
assert old_rules in s, 'rules'
s = s.replace(old_rules, '&"great_tower", &"ranges", &"motte", &"bailey_clear"]', 1)

old = '''func _check_gaps(spec: CastleSpec, builder: CastleBuilder) -> void:'''
new = '''## What stands in the bailey keeps its distance (CAS-012).
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
			"walk_", "crenel", "causeway"]:
		if name.begins_with(p):
			return true
	return false


## Distance from a point to the nearest edge of a rectangle; 0 inside it.
static func _rect_distance(rect: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0)
	var dy: float = maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0)
	return Vector2(dx, dy).length()


func _check_gaps(spec: CastleSpec, builder: CastleBuilder) -> void:'''
assert old in s, 'gaps anchor'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('check ok')
