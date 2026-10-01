class_name VillageDressRules
extends RefCounted
## Resolves recipe steps into keys, counts, and candidate spots.

# -------------------------------------------------------------- the rules

## One recipe step: roll the die, work out how many, and place them by the
## step's own rule. Anything that finds nowhere legal is simply not placed --
## an outdoor recipe is a description of a full village, and a hamlet is not
## a failure for having one bench instead of two.
static func apply(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		rng: RandomNumberGenerator, host: int, role: StringName) -> void:
	var opt: float = float(step.get("opt", 1.0))
	if opt < 1.0 and rng.randf() > opt:
		return
	var span: Array = step["n"]
	var count: int = rng.randi_range(int(span[0]), int(span[1]))
	if role == &"market" and step["cat"] == "stall" and plan.spec.form == &"planted":
		count = maxi(count, 8)
	if count <= 0:
		return
	var keys: Array[String] = keys_for(ctx, step)
	if keys.is_empty():
		return
	# Walk the candidates until `count` pieces are down, rather than trying
	# the first `count` of them: a rule offers several places on purpose --
	# either side of the door, then further out from the wall -- and taking
	# only the first meant one blocked spot lost the piece entirely.
	var spots: Array[Vector2] = VillageDressSpots.spots_for(plan, ctx, step, rng, host, role, count)
	if bool(step.get("fill", false)):
		count = spots.size()
	var placed := 0
	for spot in spots:
		if placed >= count:
			break
		var key: String = keys[rng.randi() % keys.size()]
		if role == &"edge" and bool(step.get("fill", false)) and bool(step.get("plant", false)):
			key = _edge_kind(plan, ctx, key, spot)
		var placement_step: Dictionary = step
		if role == &"market" and step["rule"] == &"row":
			placement_step = step.duplicate()
			var common_rect := Poly.bounding_rect(ctx["common"])
			var along_x: bool = common_rect.size.x >= common_rect.size.y
			# Rows share an orientation and face the aisle, rather than each
			# stall looking diagonally toward the village centre.
			var across: float = spot.y - common_rect.get_center().y if along_x else spot.x - common_rect.get_center().x
			placement_step["yaw"] = (0.0 if across > 0.0 else PI) if along_x else (PI * 0.5 if across > 0.0 else -PI * 0.5)
		var accepted := VillageDressPlacement.place(plan, ctx, placement_step, key, spot, rng, host)
		if not accepted and role == &"edge" and bool(step.get("fill", false)) \
				and bool(step.get("plant", false)):
			# A randomly chosen broad crown is not proof that no tree fits.
			# Try smaller members of the same cultural palette before leaving
			# a long hole beside a roof or another mature tree.
			var alternatives: Array[String] = keys.duplicate()
			alternatives.sort_custom(func(a: String, b: String) -> bool:
				return PropCatalog.canopy(a) < PropCatalog.canopy(b))
			for alternative in alternatives:
				if alternative == key: continue
				if VillageDressPlacement.place(plan, ctx, placement_step, alternative, spot, rng, host):
					accepted = true
					break
			if not accepted and plan.spec.enclosure == &"none":
				# A track can graze the boundary for tens of metres. Offer the
				# inner side of the same visible edge band, rather than either
				# planting in the track or silently leaving that whole side bare.
				var inward_spot := inside_edge(plan.site, spot, 5.0)
				for alternative in alternatives:
					if VillageDressPlacement.place(plan, ctx, placement_step, alternative, inward_spot, rng, host):
						accepted = true
						break
		if accepted:
			if bool(step.get("orchard", false)):
				plan.plants[-1]["row"] = "orchard:%d" % host
				plan.plants[-1]["host"] = host
			placed += 1


## A planted edge is mostly the culture's own tree, with the odd bush where
## a hedge grew up between two, and the odd dead or broken tree an old edge
## always has. Drawn from the spot, not from `rng`; a blighted village is
## already all dead wood and keeps its row as it is.
static func _edge_kind(plan: VillagePlan, ctx: Dictionary, key: String, spot: Vector2) -> String:
	if plan.spec.culture == &"blighted":
		return key
	var roll := fposmod(sin(spot.x * 12.9898 + spot.y * 78.233 + float(plan.spec.seed) * 0.173) * 43758.5453, 1.0)
	var slot := ""
	if roll < 0.14:
		slot = "hedge"
	elif roll < 0.21:
		slot = "wild"
	if slot.is_empty():
		return key
	var options := palette_keys(ctx, slot)
	if options.is_empty():
		return key
	return options[int(roll * 10000.0) % options.size()]


static func inside_edge(site: Rect2, spot: Vector2, depth: float) -> Vector2:
	var edge := Poly.from_rect(site.grow(-1.0))
	var nearest := Vector2.ZERO
	var inward := Vector2.ZERO
	var distance := INF
	for i in edge.size():
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % edge.size()]
		var projected := Geometry2D.get_closest_point_to_segment(spot, a, b)
		if spot.distance_to(projected) >= distance: continue
		distance = spot.distance_to(projected)
		nearest = projected
		inward = Vector2(-(b-a).y, (b-a).x).normalized()
		if inward.dot(site.get_center()-projected) < 0: inward = -inward
	return nearest + inward * depth


## Which catalogue keys a step may draw from: a palette slot for a plant, the
## VillageDressCatalog.BUILT table for a built prop, a category otherwise.
static func keys_for(ctx: Dictionary, step: Dictionary) -> Array[String]:
	if bool(step.get("built", false)):
		var made: Array[String] = []
		if VillageDressCatalog.BUILT.has(String(step["cat"])):
			made.append(String(step["cat"]))
		return made
	if bool(step.get("plant", false)):
		var slot: String = String(step.get("palette", ""))
		if slot.is_empty():
			slot = _slot_for(String(step["cat"]))
		return palette_keys(ctx, slot)
	return PropCatalog.of_category(String(step["cat"]))


## Which palette slot a plant category comes out of when the step does not
## name one.
static func _slot_for(cat: String) -> String:
	match cat:
		"tree", "dead_tree":
			return "edge"
		"bush":
			return "hedge"
		"ground", "grass", "flower", "pebble", "rock", "plant", "mushroom":
			return "ground"
	return "ground"


## The catalogue keys of one palette slot, expanding the `*` patterns. Only
## keys the catalogue actually knows are returned, so a palette naming a pack
## that is not installed plants nothing rather than crashing.
static func palette_keys(ctx: Dictionary, slot: String) -> Array[String]:
	var out: Array[String] = []
	var palette: Dictionary = ctx["palette"]
	for pattern in palette.get(slot, []):
		var text: String = String(pattern)
		if text.ends_with("*"):
			var prefix: String = text.substr(0, text.length() - 1)
			for key in PropCatalog.plants():
				if key.begins_with(prefix) and PropCatalog.known(key):
					out.append(key)
		elif PropCatalog.known(text):
			out.append(text)
	return out


## Where a step's pieces go, by its rule. Every rule returns candidate points

