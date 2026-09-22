class_name CourtCheck
extends RefCounted
## Is this a building round a yard, or a building with a hole in it?
##
## A courtyard is the oldest plan there is -- the monastery, the caravanserai,
## the inn with a yard, the Roman house -- and what makes one is not that it
## has a hole. Four things do, and each is a sentence and a measurement
## (WORLD 1.1):
##
##   SKY         the court is open: nothing is roofed over it, and it is big
##               enough that the sky reaches the ground in it
##   INWARD      the ranges LOOK IN. More of the windows onto the court than
##               away from it, which is the whole idea: a courtyard building
##               turns its back on the street
##   RING        you can walk right round. Every range that touches the court
##               has a door onto it, and the court joins them all
##   PROPORTION  the court is a room, not a light well and not a field: its
##               narrow side is no less than the ranges are tall, and it takes
##               a real share of the footprint
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

## Every rule, in the order it runs. A family may replace one through
## `check(plan, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"sky", &"inward", &"ring", &"proportion"]
## WLD-001 keeps the four original courtyard rules and adds the architectural
## claims that distinguish a domus, riad and palazzo.
const WORLD_RULES: Array[StringName] = [&"sky", &"inward", &"blind_entry",
	&"view_through", &"ring", &"water", &"proportion", &"shops", &"water_gate"]
const METHODS := {}

## A court narrower than this is a light well, not a yard.
const MIN_SIDE := 3.0
## And it has to be at least this much of the footprint to be the thing the
## building is arranged around.
const MIN_SHARE := 0.04
## How tall the ranges may stand for a court of a given width: a yard you
## cannot see the sky out of is a shaft.
const MAX_HEIGHT_RATIO := 1.35

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(plan: HousePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["courts"] = plan.courts.size()
	if plan.has_court():
		var rules := WORLD_RULES if plan.world_subkind != &"" else RULES
		replaced = RuleSet.run(self, rules, METHODS, overrides, [plan], [plan],
			failures, warnings)
		var builder: Variant = overrides.get("builder")
		if builder is HouseBuilder:
			_check_roof_sky(plan, builder)
			_check_roof_support(plan, builder)
			if plan.blind_entry:
				var screen_emitted := false
				for mass in builder.mass_log:
					if String(mass.get("name", "")) == "blind_screen":
						screen_emitted = true
						break
				if not screen_emitted:
					failures.append("blind_entry: authored screen was not emitted")
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats, "replaced": replaced}


## Nothing is built in the court and nothing is roofed over it.
##
## The plan check already says no ROOM stands in a court; what this adds is the
## furniture, because a court filled with the hall's tables is a hall with the
## roof off rather than a yard.
func _check_sky(plan: HousePlan) -> void:
	for ci in range(plan.courts.size()):
		var poly: PackedVector2Array = plan.court_outline(ci)
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or int(p.get("host", -1)) >= 0:
				continue
			if not PropCatalog.blocks_floor(String(p["key"])):
				continue
			var water_key: String = String(p.get("key", "")).to_lower()
			var water_at := Rect2(p.get("rect", Rect2())).get_center()
			if (p.get("world_water", false) or water_key.contains("well") or water_key.contains("fountain")) \
					and _inside_impluvium(plan, water_at):
				continue
			if Poly.contains_point(poly, Rect2(p["rect"]).get_center()):
				failures.append("sky: %s stands in court %d, which is open ground"
					% [String(p["key"]), ci])
		for si in range(plan.stairs.size()):
			var r: Rect2 = plan.stairs[si].get("rect", Rect2())
			if r.size.x > 0.0 and Poly.contains_point(poly, r.get_center()):
				failures.append("sky: stair %d is built in court %d" % [si, ci])


## A plan-level court can be sound while the emitter accidentally roofs its
## column. When a built shell is supplied, inspect the structural roof masses
## the builder actually logged, not an AABB derived from the plan. Authored
## opening rows are evidence and are deliberately not solids.
func _check_roof_sky(plan: HousePlan, builder: HouseBuilder) -> void:
	var eave := plan.spec.height * maxi(int(plan.spec.storeys), 1)
	var blocked := 0
	for m in builder.mass_log:
		var name := String(m.get("name", ""))
		if not name.begins_with("roof") or name.begins_with("roof_opening"):
			continue
		var a: AABB = m["aabb"]
		if a.position.y + a.size.y < eave - 0.05:
			continue
		var footprint := Rect2(Vector2(a.position.x, a.position.z),
			Vector2(a.size.x, a.size.z))
		for ci in range(plan.courts.size()):
			var court := Rect2(plan.courts[ci]["rect"])
			var overlap := footprint.intersection(court)
			if overlap.size.x > 0.02 and overlap.size.y > 0.02:
				blocked += 1
				failures.append("sky: roof mass %s covers court %d above eave" %
					[name, ci])
	stats["roof_masses_over_court"] = blocked


## A courtyard roof must sit on the outer wall head. A plan-level sky check can
## pass while a sloping plate floats above the wall, so compare the emitted
## roof masses against the emitted exterior wall/fascia masses that support
## their outer edge.
## The same rule catches accidental duplicate roof rings on multi-storey plans.
func _check_roof_support(plan: HousePlan, builder: HouseBuilder) -> void:
	var roofs: Array[AABB] = []
	var supports: Array[AABB] = []
	for raw in builder.mass_log:
		var name := String(raw.get("name", ""))
		var aabb: AABB = raw.get("aabb", AABB())
		if name.begins_with("roof_court_"):
			roofs.append(aabb)
		elif name.begins_with("court_roof_fascia_") or name.begins_with("wall_"):
			supports.append(aabb)
	if roofs.is_empty():
		return
	if roofs.size() != 4:
		failures.append("roof_support: expected four top-level court roof bands, found %d" % roofs.size())
	for ri in range(roofs.size()):
		var roof: AABB = roofs[ri]
		var supported := false
		for wall in supports:
			var overlap_x := minf(roof.end.x, wall.end.x) - maxf(roof.position.x, wall.position.x)
			var overlap_z := minf(roof.end.z, wall.end.z) - maxf(roof.position.z, wall.position.z)
			if overlap_x > 0.08 and overlap_z > 0.08 \
					and wall.end.y >= roof.position.y + roof.size.y * 0.7:
				supported = true
				break
		if not supported:
			failures.append("roof_support: court roof band %d has no supporting outer wall/fascia" % ri)
	var roof_parts := builder.components("roof_court_")
	if roof_parts.size() == 4:
		var site := HouseGeometry.site_rect(plan.spec)
		var court := Rect2(plan.courts.back()["rect"])
		var outer_corners := [
			Vector2(site.position.x, site.position.y), Vector2(site.end.x, site.position.y),
			Vector2(site.end.x, site.end.y), Vector2(site.position.x, site.end.y)]
		var inner_corners := [
			Vector2(court.position.x, court.position.y), Vector2(court.end.x, court.position.y),
			Vector2(court.end.x, court.end.y), Vector2(court.position.x, court.end.y)]
		for part in roof_parts:
			var pts: PackedVector3Array = part.get("points", PackedVector3Array())
			var outer_hits := 0
			var inner_hits := 0
			for p in pts:
				var p2 := Vector2(p.x, p.z)
				for corner in outer_corners:
					if p2.distance_to(corner) < 0.02:
						outer_hits += 1
				for corner2 in inner_corners:
					if p2.distance_to(corner2) < 0.02:
						inner_hits += 1
			if outer_hits < 2 or inner_hits < 2:
				failures.append("roof_support: court roof face does not share outer/court corner endpoints")
		var endpoint_y: Dictionary = {}
		for part2 in roof_parts:
			var pts2: PackedVector3Array = part2.get("points", PackedVector3Array())
			for p2v in pts2:
				var p2xz := Vector2(p2v.x, p2v.z)
				for oi in range(outer_corners.size()):
					if p2xz.distance_to(outer_corners[oi]) < 0.02:
						var ok := "outer_%d" % oi
						if not endpoint_y.has(ok):
							endpoint_y[ok] = []
						endpoint_y[ok].append(p2v.y)
				for ii in range(inner_corners.size()):
					if p2xz.distance_to(inner_corners[ii]) < 0.02:
						var ik := "inner_%d" % ii
						if not endpoint_y.has(ik):
							endpoint_y[ik] = []
						endpoint_y[ik].append(p2v.y)
		for heights in endpoint_y.values():
			var min_h := INF
			var max_h := -INF
			for h in heights:
				min_h = minf(min_h, float(h))
				max_h = maxf(max_h, float(h))
			if heights.size() > 1 and max_h - min_h > 0.02:
				failures.append("roof_support: shared court roof corner heights disagree")
				break
	stats["court_roof_bands"] = roofs.size()
	stats["court_roof_supports"] = supports.size()


static func _inside_impluvium(plan: HousePlan, p: Vector2) -> bool:
	for raw in plan.roof_openings:
		if StringName(raw.get("kind", &"")) == &"compluvium" \
				and raw.has("impluvium") and Rect2(raw["impluvium"]).has_point(p):
			return true
	return false


## The domus water rule is opt-in: a normal courtyard has no impluvium claim.
## A compluvium row may carry an `impluvium` rect and the authored plan must
## place a well/fountain in that pool. Kept separate from `check()` so generic
## courtyards are not forced to invent water.
func water(plan: HousePlan) -> Dictionary:
	var out: Array[String] = []
	for raw in plan.roof_openings:
		if StringName(raw.get("kind", &"")) != &"compluvium":
			continue
		if not raw.has("impluvium"):
			continue
		var pool := Rect2(raw["impluvium"])
		var op_poly := PackedVector2Array()
		if raw.has("rect"):
			op_poly = Poly.from_rect(Rect2(raw["rect"]))
		elif raw.has("polygon"):
			for p in raw["polygon"]:
				op_poly.append(Vector2(p))
		for corner in [pool.position, Vector2(pool.end.x, pool.position.y),
				pool.end, Vector2(pool.position.x, pool.end.y)]:
			if not Poly.contains_point(op_poly, corner, 0.001):
				out.append("water: impluvium corner %s lies outside compluvium" % corner)
				break
		var found := false
		var centre := pool.get_center()
		for p in plan.furniture:
			var key := String(p.get("key", "" )).to_lower()
			if not (p.get("world_water", false) or key.contains("well") or key.contains("fountain")):
				continue
			var at := Vector2(Vector3(p.get("pos", Vector3.ZERO)).x,
				Vector3(p.get("pos", Vector3.ZERO)).z)
			if at.distance_to(centre) <= maxf(pool.size.x, pool.size.y) * 0.15:
				found = true
		if not found:
			out.append("water: no fountain/well in impluvium")
	return {"ok": out.is_empty(), "failures": out}


## The ranges look IN.
##
## Counted over the windows, because that is what looking means. A courtyard
## building that put its glass on the street and its blank walls on the yard
## has the plan inside out -- it is a terrace with a hole in it.
func _check_inward(plan: HousePlan) -> void:
	if plan.world_subkind != &"":
		_check_world_inward(plan)
		return
	var inward := 0
	var outward := 0
	for wi in range(plan.windows.size()):
		var w: Dictionary = plan.windows[wi]
		if _onto_court(plan, Vector2(w["pos"]), Vector2(w["normal"])):
			inward += 1
		else:
			outward += 1
	stats["windows_inward"] = inward
	stats["windows_outward"] = outward
	if inward == 0:
		failures.append("inward: not one window looks into the court")
	elif inward < outward:
		failures.append("inward: %d windows look into the court and %d away from it -- the plan is inside out"
			% [inward, outward])


## You can walk right round: every room on the court has a door onto it.
func _check_ring(plan: HousePlan) -> void:
	var touching: Array[int] = []
	for i in range(plan.room_count()):
		if _touches_court(plan, i):
			touching.append(i)
	stats["rooms_on_court"] = touching.size()
	if touching.is_empty():
		failures.append("ring: no room stands on the court")
		return
	var doored := 0
	for i2 in touching:
		var has := false
		for d in plan.doors_of(i2):
			var door: Dictionary = plan.doors[d]
			if _onto_court(plan, Vector2(door["pos"]), Vector2(door["normal"])) \
					or _onto_court(plan, Vector2(door["pos"]), -Vector2(door["normal"])):
				has = true
				break
		if has:
			doored += 1
	stats["doors_onto_court"] = doored
	if doored == 0:
		failures.append("ring: %d rooms stand on the court and not one opens onto it"
			% touching.size())
	if plan.world_subkind != &"":
		var missing := 0
		for room in _world_habitable(plan):
			if _is_shop(plan, room):
				continue
			if _touches_court(plan, room) and not _room_has_court_opening(plan, room):
				missing += 1
		if missing > 0:
			failures.append("ring: %d habitable court rooms have no court opening" % missing)


## The court is a room, not a light well and not a field.
func _check_proportion(plan: HousePlan) -> void:
	if plan.world_subkind != &"":
		var eave := float(plan.world_meta.get("eave_height", plan.spec.height))
		for ci_world in range(plan.courts.size()):
			var c_world := Rect2(plan.courts[ci_world]["rect"])
			var narrow_world := minf(c_world.size.x, c_world.size.y)
			var ratio := narrow_world / maxf(eave, 0.01)
			if ratio < 0.6 or ratio > 2.5:
				failures.append("proportion: court %d has %.2fx eave height (wanted 0.6..2.5)"
					% [ci_world, ratio])
		stats["world_court_eave_ratio"] = minf(2.5, minf(99.0,
			float(plan.courts[0]["rect"].size.x) / maxf(eave, 0.01))) if not plan.courts.is_empty() else 0.0
		return
	var site: Rect2 = HouseGeometry.site_rect(plan.spec)
	var footprint: float = site.size.x * site.size.y
	var tall: float = plan.spec.height * maxi(int(plan.spec.storeys), 1)
	for ci in range(plan.courts.size()):
		var rect: Rect2 = plan.courts[ci]["rect"]
		var narrow: float = minf(rect.size.x, rect.size.y)
		if narrow < MIN_SIDE:
			failures.append("proportion: court %d is %.2fm across -- that is a light well"
				% [ci, narrow])
			continue
		var share: float = (rect.size.x * rect.size.y) / maxf(footprint, 0.01)
		if share < MIN_SHARE:
			failures.append("proportion: court %d is %.1f%% of the footprint -- too little to arrange a building round"
				% [ci, share * 100.0])
		if narrow < tall / MAX_HEIGHT_RATIO:
			warnings.append("proportion: court %d is %.1fm across between %.1fm ranges -- little sky reaches the ground"
				% [ci, narrow, tall])


func _check_world_inward(plan: HousePlan) -> void:
	var inward := 0
	var outward := 0
	var missing := 0
	for room in _world_habitable(plan):
		if _is_shop(plan, room):
			continue
		var has_inward := false
		for d in plan.doors_of(room):
			var door := plan.doors[d]
			if _onto_court(plan, Vector2(door["pos"]), Vector2(door["normal"])):
				has_inward = true
		for w in plan.windows_of(room):
			var win := plan.windows[w]
			if _onto_court(plan, Vector2(win["pos"]), Vector2(win["normal"])):
				has_inward = true
				inward += 1
			else:
				outward += 1
		if not has_inward:
			missing += 1
	for win in plan.windows:
		var p := Vector2(win["pos"])
		if p.y <= HouseGeometry.interior_rect(plan.spec).position.y + 0.02 \
				and float(win.get("sill", 0.0)) < 2.2 \
				and not _is_shop(plan, int(win.get("room", -1))):
			failures.append("inward: street window below 2.2m")
	if missing > 0:
		failures.append("inward: %d habitable rooms lack a court door/window" % missing)
	var front := 0
	for door in plan.doors:
		if bool(door.get("front", false)):
			front += 1
	if front != 1:
		failures.append("inward: expected exactly one street house door, found %d" % front)
	stats["world_inward_windows"] = inward
	stats["world_outward_windows"] = outward


func _check_blind_entry(plan: HousePlan) -> void:
	if not plan.blind_entry:
		return
	var street := Vector2(plan.world_meta.get("street_door", Vector2.ZERO))
	var court := Rect2(plan.world_meta.get("court_rect", Rect2())).get_center()
	var screen := Rect2(plan.world_meta.get("blind_screen", Rect2()))
	var fauces := -1
	for i in range(plan.rooms.size()):
		if plan.rooms[i].get("role", &"") == &"fauces" and plan.storey_of_room(i) == 0:
			fauces = i
			break
	if fauces < 0 or not HouseGeometry.room_floor_rect(plan, fauces).encloses(screen):
		failures.append("blind_entry: screen is not an authored obstruction inside the fauces")
	var boxes: Array[AABB] = []
	if screen.has_area():
		boxes.append(AABB(Vector3(screen.position.x, 0.0, screen.position.y),
			Vector3(screen.size.x, plan.spec.height, screen.size.y)))
	if not Sightline.blocked(Vector3(street.x, 1.2, street.y),
			Vector3(court.x, 1.2, court.y), boxes):
		failures.append("blind_entry: street door has a direct sightline to the court")


func _check_view_through(plan: HousePlan) -> void:
	if not plan.view_through:
		return
	var street := Vector2(plan.world_meta.get("street_door", Vector2.ZERO))
	var tablinum := -1
	for i in range(plan.rooms.size()):
		if plan.rooms[i].get("role", &"") == &"tablinum" and plan.storey_of_room(i) == 0:
			tablinum = i
			break
	if tablinum < 0:
		failures.append("view_through: no ground tablinum")
		return
	var target := HouseGeometry.room_floor_rect(plan, tablinum).get_center()
	var blockers: Array[AABB] = []
	# Use authored plan furniture as the obstruction source. This keeps the
	# rule tied to emitted floor geometry instead of a QA-only blocker list.
	for placement in plan.furniture:
		if placement.get("mounted", false) or int(placement.get("host", -1)) >= 0:
			continue
		var raw_rect: Variant = placement.get("rect", Rect2())
		if not (raw_rect is Rect2) or not (raw_rect as Rect2).has_area():
			continue
		var box: Rect2 = raw_rect
		blockers.append(AABB(Vector3(box.position.x, 0.0, box.position.y),
			Vector3(box.size.x, plan.spec.height, box.size.y)))
	if not Sightline.clear(Vector3(street.x, 1.2, street.y),
			Vector3(target.x, 1.2, target.y), blockers):
		failures.append("view_through: fauces-to-tablinum axis is blocked")


func _check_water(plan: HousePlan) -> void:
	var report := water(plan)
	for f in report["failures"]:
		failures.append(str(f))
	var pool := Rect2(plan.world_meta.get("water_rect", Rect2()))
	var court := Rect2(plan.world_meta.get("court_rect", Rect2()))
	if plan.world_subkind != &"" and (not pool.has_area() or not court.encloses(pool)):
		failures.append("water: feature is not inside the court")
	if pool.has_area():
		var centre := pool.get_center()
		var found := false
		for p in plan.furniture:
			var key := String(p.get("key", "")).to_lower()
			if (key.contains("well") or key.contains("fountain")) \
					and Vector2(Vector3(p.get("pos", Vector3.ZERO)).x,
					Vector3(p.get("pos", Vector3.ZERO)).z).distance_to(centre) \
					<= maxf(court.size.x, court.size.y) * 0.15:
				found = true
		if not found:
			var authored := Vector2(plan.world_meta.get("water_pos", Vector2(INF, INF)))
			found = authored.is_finite() and authored.distance_to(centre) \
				<= maxf(court.size.x, court.size.y) * 0.15
		if not found:
			failures.append("water: fountain/well is not near court centre")


func _check_shops(plan: HousePlan) -> void:
	if plan.world_subkind != &"domus":
		return
	var shops := 0
	for door in plan.doors:
		if String(door.get("role", "")) != "taberna":
			continue
		shops += 1
		if float(door.get("width", 0.0)) < 2.0:
			failures.append("shops: taberna street opening is under 2m")
		var room := int(door.get("a", -1))
		if not _is_shop(plan, room):
			failures.append("shops: street opening leads to a non-shop room")
		for attached in plan.doors:
			if int(attached.get("a", -1)) != room and int(attached.get("b", -1)) != room:
				continue
			if attached == door:
				continue
			failures.append("shops: taberna has an additional door into the house")
	if shops != 2:
		failures.append("shops: expected two tabernae, found %d" % shops)


func _check_water_gate(plan: HousePlan) -> void:
	if plan.world_subkind != &"palazzo":
		return
	var found := false
	for door in plan.doors:
		if String(door.get("role", "")) != "water_gate":
			continue
		found = true
		if float(door.get("sill", plan.world_meta.get("water_gate_sill", 99.0))) > 0.3:
			failures.append("water_gate: sill is above the water plane")
		if String(door.get("wall", "")) != "canal":
			failures.append("water_gate: door is not on the canal wall")
	if plan.canal_wall != &"front":
		failures.append("water_gate: plan canal wall is not the front wall")
	if not found:
		failures.append("water_gate: no canal door")
	var portego := int(plan.world_meta.get("portego_room", -1))
	if portego < 0 or portego >= plan.rooms.size():
		failures.append("water_gate: portego is missing")
	else:
		var r: Rect2 = plan.rooms[portego]["rect"]
		if r.size.y < plan.spec.length * 0.35:
			failures.append("water_gate: portego does not run to the far wall")


func _world_habitable(plan: HousePlan) -> Array[int]:
	var out: Array[int] = []
	for i in range(plan.rooms.size()):
		if HouseGeometry.is_habitable(plan.kind_of(i)):
			out.append(i)
	return out


func _is_shop(plan: HousePlan, room: int) -> bool:
	if room < 0 or room >= plan.rooms.size():
		return false
	return String(plan.rooms[room].get("role", "")).begins_with("taberna")


func _room_has_court_opening(plan: HousePlan, room: int) -> bool:
	for d in plan.doors_of(room):
		var door := plan.doors[d]
		if _onto_court(plan, Vector2(door["pos"]), Vector2(door["normal"])):
			return true
	for w in plan.windows_of(room):
		var win := plan.windows[w]
		if _onto_court(plan, Vector2(win["pos"]), Vector2(win["normal"])):
			return true
	return false


# ------------------------------------------------------------------ helpers

## Does an opening at `pos`, facing `n`, look into a court?
static func _onto_court(plan: HousePlan, pos: Vector2, n: Vector2) -> bool:
	var outside: Vector2 = pos + n * (HouseGeometry.WALL_T + 0.05)
	for ci in range(plan.courts.size()):
		if Poly.contains_point(plan.court_outline(ci), outside, 0.01):
			return true
	return false


## Does this room have a wall on a court?
static func _touches_court(plan: HousePlan, room: int) -> bool:
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	for ci in range(plan.courts.size()):
		if HousePlan.record_storey(plan.courts[ci]) > plan.storey_of_room(room):
			continue
		var court: Rect2 = plan.courts[ci]["rect"]
		if f.grow(HouseGeometry.WALL_T + 0.1).intersects(court):
			return true
	return false
