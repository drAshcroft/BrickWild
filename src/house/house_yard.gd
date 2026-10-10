class_name HouseYard
extends RefCounted
## What stands outside a house: the yard (EVAL-B06).
##
## The plan owns it. A house is dressed in two layers:
##
##   * `plan.exterior`  the facade pieces on the wall itself (HouseExterior):
##     a lantern, a bench, a barrel on the service wall;
##   * `plan.yard`      measured catalogue props on the ground beyond them, and
##     `plan.yard_pieces` the BUILT things the catalogue has no model for -- a
##     fence of rails, a woodpile, a washing line, a midden, a charcoal lean-to.
##
## Props are instantiated by HouseAssembler and nowhere else. Pieces are
## emitted by HouseBuilder through `component_box` with host "yard", so exterior
## QA sees them; both are planned here, in metres and rectangles, with no model
## loaded and no RNG shared with the interior (the yard draws from its own
## generator, so dressing the yard can never move a chair).
##
## Hosts: "front" (the entrance's own wall), "side", "rear", "porch", "chimney"
## and "path". The yard ENVELOPE is the shell footprint (porch and chimney
## stack included) grown by `HouseSpec.yard_apron` -- a 2 to 3 m apron, by
## style. Nothing is planned outside it: the lot owns the rest.
##
## One choice a painter made: a yard says who lives here before you reach the
## door. The recipe is one entrance feature (the stepping-stone path and what
## flanks it), then one or two working groups, never a scatter. A smith's yard
## is a quench trough, a cart and a charcoal lean-to; a cottage keeps a fenced
## kitchen garden and a washing line; a farm has its woodpile, its cart and
## its midden; an inn a signpost and its barrels; an alchemist a herb bed and
## drying line; a longhall its weapon stand and training dummy.

## Style apron, metres. A townhouse is tight to its street; a farm sprawls.
const APRON := {&"cottage": 2.6, &"farmhouse": 3.0, &"townhouse": 2.0,
	&"longhall": 2.8, &"witch_hut": 2.6,
	# A Mediterranean house stands in a paved square, a compound in a wide one,
	# and an Asian house gives a slice of its own to the veranda. All three stay
	# inside the 2 to 3 m the apron contract promises: a compound wants more
	# ground, and a compound is what a walled village around it provides.
	&"mediterranean": 2.4, &"asian": 2.9, &"african": 3.0,
	&"thatch_cottage": 2.6, &"mud_hut": 3.0}
const DEFAULT_APRON := 2.5

## A thing this low is a path, not an obstacle: it is walked over, and it may
## lie across a door approach (the path to the door does).
const FLUSH := 0.12
## Walkers: an obstacle must reach above this and start below head height.
const STEP := 0.2
const HEAD := 1.7
## Clearance kept between two things in the yard.
const GAP := 0.05
const WITCH_WORK_CLEARANCE := 2.1
const WITCH_WORK_APPROACH := 0.9

## What the household does, in order of importance. A trade adds its working
## groups; the style contributes the first of its own when there is a trade
## and up to two when there is none.
const STYLE_GROUPS := {
	&"cottage": [&"washing_line", &"garden", &"flowers"],
	&"farmhouse": [&"woodpile", &"cart", &"midden"],
	&"townhouse": [&"crates", &"rain_barrel"],
	&"longhall": [&"woodpile", &"training"],
	&"witch_hut": [&"witch_work_shelter", &"herb_bed", &"drying_line", &"mushrooms", &"midden"],
	# HOUSE-CULTURE. A yard says who lives here, and a household with no trade
	# is judged on its kind of house instead -- water jars and a drying line in
	# the sun, a dung midden and a cart in a compound, pots under the shade.
	&"mediterranean": [&"garden", &"flowers", &"crates"],
	&"asian": [&"garden", &"crates", &"rain_barrel"],
	&"african": [&"midden", &"crates", &"cart"],
	&"thatch_cottage": [&"garden", &"washing_line", &"woodpile"],
	&"mud_hut": [&"midden", &"herb_bed", &"mushrooms"],
}
const TRADE_GROUPS := {
	&"none": [],
	&"smith": [&"trough", &"leanto", &"cart"],
	&"farmer": [&"woodpile", &"cart"],
	&"innkeeper": [&"signpost", &"tap_barrels", &"cart"],
	&"alchemist": [&"herb_bed", &"drying_line"],
	&"scholar": [&"flowers"],
}
## The most working groups a yard takes, besides the path and the porch pail.
const MAX_GROUPS := 3

## Built-piece kinds, for the check.
const KINDS := ["fence", "woodpile", "washing_line", "midden", "leanto", "witch_work_lean_to", "trough",
	"signpost", "bed", "path"]

const HERBS := ["Wild_Plant_7", "Wild_Fern_1", "Wild_Plant_1", "Nature_Flower_3_Clump", "Wild_Fern_1", "Wild_Plant_7"]


# ---------------------------------------------------------------- the envelope

## The apron, metres: the spec's own when it set one, the style's otherwise.
static func apron(spec: HouseSpec) -> float:
	if spec.yard_apron > 0.0:
		return spec.yard_apron
	return float(APRON.get(spec.style, DEFAULT_APRON))


## Does this plan get a yard at all? A rectangular dwelling does. Courts,
## polygon shells, and the shop/hotel/castle families dress their own ground.
static func applies(plan: HousePlan) -> bool:
	var spec := plan.spec
	if not spec.exterior_props or spec.has_method("room_program"):
		return false
	if HouseGeometry.is_shaped(plan) or plan.has_court():
		return false
	return plan.entrance() >= 0


## Does this plan stand on open ground with a road edge to walk from? A house, a
## shop and a hotel do. A courtyard or shaped plan opens its doors onto its own
## court and a castle interior stands inside masonry: there is no road edge to
## reach them from, and the access rule has nothing to say (EVAL-C14).
static func has_road_edge(plan: HousePlan) -> bool:
	return plan.spec.exterior_props and not HouseGeometry.is_shaped(plan) 		and not plan.has_court()


# --------------------------------------------------------------------- planning

## Plan the yard into `plan.yard` and `plan.yard_pieces`. Deterministic: the same
## plan always gets the same yard, from a generator of its own.
static func plan(p: HousePlan) -> void:
	p.yard.clear()
	p.yard_pieces.clear()
	if not applies(p):
		return
	var ctx := _context(p)
	var wanted: Array[StringName] = [&"path"]
	var groups: Array = TRADE_GROUPS.get(p.spec.trade, [])
	var style: Array = STYLE_GROUPS.get(p.spec.style, [])
	if p.spec.style == &"witch_hut" and p.spec.trade != &"none":
		# Explicit trades keep the pre-slice Witch style groups; their own yard
		# recipe takes precedence over the no-trade household craft shelter.
		style = [&"herb_bed", &"drying_line", &"mushrooms", &"midden"]
	var style_slots := 1 if not groups.is_empty() else 2
	if p.spec.style == &"witch_hut" and p.spec.trade == &"none":
		style_slots = 3
	var from_style: Array = style.slice(0, style_slots)
	var group_order: Array = groups + from_style
	if p.spec.style == &"witch_hut" and p.spec.trade == &"none" and not style.is_empty():
		# The shelter is the style's defining work anchor. Give it the first
		# clear service-side slot even when a trade also contributes yard groups.
		group_order = [style[0]] + groups + style.slice(1, style_slots)
		# A porch pail is replaceable. It must not reserve the only measured
		# service-side space before the required Witch work shelter is fitted.
		wanted.append(style[0])
	wanted.append(&"porch_pail")
	for g in group_order:
		if g not in wanted and wanted.size() < MAX_GROUPS + 2:
			wanted.append(g)
	var ingredient_cluster_done := false
	for g in wanted:
		if p.spec.style == &"witch_hut" and p.spec.trade == &"none" \
				and g == &"herb_bed" and ctx.has("witch_service_door"):
			var cluster := _witch_ingredient_cluster(ctx)
			ingredient_cluster_done = true
			for role in [&"herb_bed", &"drying_line"]:
				var ingredient: Dictionary = cluster.get(role, {})
				if ingredient.is_empty():
					p.exterior_omissions.append("yard %s: no clear ground within the Witch service cluster" % role)
				else:
					_accept(ctx, role, ingredient)
			continue
		if p.spec.style == &"witch_hut" and p.spec.trade == &"none" \
				and ingredient_cluster_done and g == &"drying_line":
			continue
		var made := _group(ctx, g)
		if made.is_empty():
			p.exterior_omissions.append("yard %s: no clear ground" % g)
			continue
		_accept(ctx, g, made)
	# The one thing that must survive: a person can walk from the road to the
	# door. Take groups back, last first, until they can.
	while not ctx["order"].is_empty() and not access_ok(p):
		var last: String = ctx["order"].pop_back()
		var kept_props: Array[Dictionary] = []
		for prop in p.yard:
			if str(prop["group"]) != last:
				kept_props.append(prop)
		p.yard = kept_props
		var kept_pieces: Array[Dictionary] = []
		for piece in p.yard_pieces:
			if str(piece["group"]) != last:
				kept_pieces.append(piece)
		p.yard_pieces = kept_pieces
		p.exterior_omissions.append("yard %s: removed to keep the approach open" % last)


static func _context(p: HousePlan) -> Dictionary:
	var spec := p.spec
	var door: Dictionary = p.doors[p.entrance()]
	var n: Vector2 = door["normal"]
	var fwd := Vector2(0, -1)
	if absf(n.x) > absf(n.y):
		fwd = Vector2(signf(n.x), 0)
	else:
		fwd = Vector2(0, signf(n.y))
	var lat := Vector2(-fwd.y, fwd.x)
	var site := HouseGeometry.site_rect(spec)
	var half := site.size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("yard|%d|%s|%s" % [spec.seed, spec.style, spec.trade])
	var ctx := {"plan": p, "fwd": fwd, "lat": lat, "ext_f": half.dot(fwd.abs()),
		"ext_l": half.dot(lat.abs()), "env": HouseGeometry.yard_rect(p),
		"door_u": Vector2(door["pos"]).dot(lat), "door": door, "rng": rng,
		"side_pref": 1.0 if rng.randf() < 0.5 else -1.0,
		"order": [] as Array[String], "counts": {}, "accepted": [] as Array[AABB]}
	for e in p.exterior:
		(ctx["accepted"] as Array).append(HouseExterior.bounds_of(e))
	return ctx


## Record an accepted group in the plan and the ctx.
static func _accept(ctx: Dictionary, name: StringName, made: Dictionary) -> void:
	var p: HousePlan = ctx["plan"]
	var n: int = int(ctx["counts"].get(name, 0))
	ctx["counts"][name] = n + 1
	var tag := "%s#%d" % [name, n]
	ctx["order"].append(tag)
	for prop in made.get("props", []):
		prop["id"] = "yard_%d" % p.yard.size()
		prop["group"] = tag
		prop["bounds"] = HouseExterior.bounds_of(prop)
		prop["rect"] = Rect2(Vector2(prop["bounds"].position.x, prop["bounds"].position.z),
			Vector2(prop["bounds"].size.x, prop["bounds"].size.z))
		p.yard.append(prop)
		(ctx["accepted"] as Array).append(prop["bounds"])
	for piece in made.get("pieces", []):
		piece["id"] = "%s_%d" % [piece["kind"], p.yard_pieces.size()]
		piece["group"] = tag
		piece["rect"] = piece_rect(piece)
		p.yard_pieces.append(piece)
		for part in piece["parts"]:
			(ctx["accepted"] as Array).append(part_aabb(part))
	if name == &"witch_work_shelter":
		# Subsequent garden/drying groups may not claim the standing clearances
		# reserved for working the bench and cauldron. Low path pavers are still
		# permitted because they are flush with the ground.
		for prop in made.get("props", []):
			if not prop.has("operation_zone"):
				continue
			var zone: Rect2 = prop["operation_zone"]
			(ctx["accepted"] as Array).append(AABB(
				Vector3(zone.position.x, 0.0, zone.position.y),
				Vector3(zone.size.x, WITCH_WORK_CLEARANCE, zone.size.y)))


# -------------------------------------------------------------------- the cells

## A cell is a place on one wall: `o` the point on the wall face, `out` the unit
## vector away from it, `tan` the unit vector along it. A thing is described in
## (t, d): t along the wall, d out from it.
static func _cell(ctx: Dictionary, region: String, s: float) -> Dictionary:
	var fwd: Vector2 = ctx["fwd"]
	var lat: Vector2 = ctx["lat"]
	var out := fwd
	var tangent := lat
	var ext: float = ctx["ext_f"]
	match region:
		"rear":
			out = -fwd
		"left":
			out = lat
			tangent = fwd
			ext = ctx["ext_l"]
		"right":
			out = -lat
			tangent = fwd
			ext = ctx["ext_l"]
	var env: Rect2 = ctx["env"]
	var reach := _extent(env, out)
	return {"region": region, "out": out, "tan": tangent,
		"o": out * ext + tangent * s, "room": reach - ext, "s": s,
		"host": _host(ctx, region)}


static func _host(ctx: Dictionary, region: String) -> String:
	match region:
		"front":
			return "front"
		"rear":
			return "rear"
	return "side"


## World point of cell coordinates.
static func _w(cell: Dictionary, t: float, d: float) -> Vector2:
	return (cell["o"] as Vector2) + (cell["tan"] as Vector2) * t + (cell["out"] as Vector2) * d


## The tangent offsets a region offers, nearest `anchor` first.
static func _slots(ctx: Dictionary, region: String, anchor: float) -> Array[float]:
	var reach: float = ctx["ext_l"] + 0.8 if region in ["front", "rear"] else ctx["ext_f"] - 0.4
	var out: Array[float] = []
	var s := -reach
	while s <= reach + 0.001:
		out.append(s)
		s += 0.5
	var pref: float = ctx["side_pref"]
	out.sort_custom(func(a: float, b: float) -> bool:
		return absf(a - anchor) + 0.002 * pref * signf(a - anchor) \
			< absf(b - anchor) + 0.002 * pref * signf(b - anchor))
	return out


# ------------------------------------------------------------------- the groups

static func _group(ctx: Dictionary, name: StringName) -> Dictionary:
	match name:
		&"path":
			return _path(ctx)
		&"porch_pail":
			return _porch_pail(ctx)
		&"garden":
			return _search(ctx, ["rear", "left", "right"], _kitchen_anchor(ctx, 0.0), [0.5, 0.9],
				func(cell: Dictionary, gap: float) -> Dictionary: return _garden(ctx, cell, gap))
		&"washing_line":
			return _search(ctx, ["left", "right", "rear"], 0.0, [0.9, 1.4],
				func(cell: Dictionary, gap: float) -> Dictionary: return _washing_line(cell, gap, 3.0, true))
		&"drying_line":
			var drying_regions: Array = ["left", "right", "rear"]
			var drying_anchor := 0.0
			if ctx.has("witch_service_region"):
				drying_regions = [String(ctx["witch_service_region"]), "rear", "left", "right"]
				drying_anchor = float(ctx["witch_service_anchor"])
			return _search(ctx, drying_regions, drying_anchor, [0.9, 1.3],
				func(cell: Dictionary, gap: float) -> Dictionary:
					var made := _washing_line(cell, gap, 2.0, false)
					if made.is_empty() or not ctx.has("witch_service_door"):
						return made
					return made if _group_within_threshold(ctx, made, 5.0) else {})
		&"flowers":
			return _flowers(ctx)
		&"woodpile":
			return _woodpile(ctx)
		&"cart":
			return _search(ctx, ["left", "right", "rear", "front"], 0.0, [0.5, 1.2],
				func(cell: Dictionary, gap: float) -> Dictionary:
					return _prop_group(ctx, cell, gap, "Dungeon_Cart", 0.4, "cart"))
		&"midden":
			return _search(ctx, ["rear", "left", "right"], ctx["ext_l"] * -ctx["side_pref"], [1.4, 1.1],
				func(cell: Dictionary, gap: float) -> Dictionary: return _midden(cell, gap))
		&"crates":
			return _search(ctx, ["left", "right", "rear"], 0.0, [0.15, 0.6],
				func(cell: Dictionary, gap: float) -> Dictionary: return _crates(ctx, cell, gap))
		&"rain_barrel":
			return _search(ctx, ["left", "right", "rear", "front"], _chimney_anchor(ctx), [0.15, 0.6],
				func(cell: Dictionary, gap: float) -> Dictionary:
					return _prop_group(ctx, cell, gap, "Barrel", 1.0, "rain_barrel"))
		&"training":
			return _search(ctx, ["front", "left", "right"], ctx["door_u"] + 3.5 * ctx["side_pref"], [1.0, 0.5],
				func(cell: Dictionary, gap: float) -> Dictionary: return _training(ctx, cell, gap))
		&"herb_bed":
			var herb_regions: Array = ["front", "left", "right", "rear"]
			var herb_anchor := float(ctx["door_u"]) - 3.0 * float(ctx["side_pref"])
			if ctx.has("witch_service_region"):
				herb_regions = [String(ctx["witch_service_region"]), "rear", "left", "right"]
				herb_anchor = float(ctx["witch_service_anchor"])
			return _search(ctx, herb_regions, herb_anchor, [0.5, 1.0],
				func(cell: Dictionary, gap: float) -> Dictionary: return _herb_bed(ctx, cell, gap, false))
		&"witch_work_shelter":
			var service_normal: Vector2
			var service_region := ""
			var service_anchor := 0.0
			var compact_threshold := false
			var threshold_door: Dictionary = {}
			for door in ctx["plan"].doors:
				if not bool(door.get("witch_workshop_yard", false)):
					continue
				service_normal = Vector2(door["normal"])
				compact_threshold = bool(door.get("witch_compact_service_threshold", false))
				threshold_door = door
				# Every authored Witch threshold gets a doorway-centred work shelter.
				# The compact flag changes the Hall contract, not whether the Workshop
				# shelter is attached to its real door.
				ctx["witch_service_door"] = door
				ctx["witch_compact_service_threshold"] = compact_threshold
				service_region = "left" if service_normal.dot(ctx["lat"]) > 0.0 else "right"
				var service_cell := _cell(ctx, service_region, 0.0)
				var service_layout := _witch_work_shelter_layout(ctx, service_cell)
				service_anchor = Vector2(door["pos"]).dot(Vector2(service_cell["tan"])) \
					+ float(service_layout["center_offset"])
				ctx["witch_service_region"] = service_region
				ctx["witch_service_anchor"] = service_anchor
				break
			if service_normal == Vector2.ZERO:
				var service_wall := 3 if posmod(ctx["plan"].spec.seed, 2) == 0 else 2
				service_normal = HouseGeometry.exterior_runs(ctx["plan"].spec)[service_wall]["normal"]
			if service_region.is_empty():
				service_region = "left" if service_normal.dot(ctx["lat"]) > 0.0 else "right"
			# The ledger and upper roof edge bear on the actual service wall.
			return _search(ctx, [service_region], service_anchor, [0.0],
				func(cell: Dictionary, gap: float) -> Dictionary:
					var made := _witch_work_shelter(ctx, cell, gap)
					if threshold_door.is_empty() or made.is_empty():
						return made
					var piece: Dictionary = made.get("pieces", [])[0]
					if not _witch_shelter_covers_threshold(piece, threshold_door, ctx["plan"].spec):
						return {}
					var body: Vector2 = Vector2(threshold_door["pos"]) \
						+ Vector2(threshold_door["normal"]) * (HouseGeometry.wall_thickness(ctx["plan"].spec) \
						+ HouseGeometry.PERSON_RADIUS + 0.05)
					var local_d := (body - Vector2(cell["o"])).dot(Vector2(cell["out"]))
					var clearance: Dictionary = piece["work_clearance"]
					var roof_bottom := _witch_roof_under(cell, local_d, gap,
						float(clearance["depth"]), float(clearance["wall_y"]),
						float(clearance["drop"]), float(clearance["roof_thickness"]))
					return made if roof_bottom >= HEAD else {})
		&"mushrooms":
			return _search(ctx, ["rear", "left", "right"], 0.0, [0.3, 0.8],
				func(cell: Dictionary, gap: float) -> Dictionary: return _mushrooms(ctx, cell, gap))
		&"trough":
			return _search(ctx, ["left", "right", "front"], 0.0, [0.35, 0.9],
				func(cell: Dictionary, gap: float) -> Dictionary: return _trough(cell, gap))
		&"leanto":
			return _search(ctx, ["left", "right", "rear"], 0.0, [0.0],
				func(cell: Dictionary, gap: float) -> Dictionary: return _leanto(cell))
		&"signpost":
			return _signpost(ctx)
		&"tap_barrels":
			return _search(ctx, ["front", "left", "right"], ctx["door_u"] + 2.4 * ctx["side_pref"], [0.15, 0.6],
				func(cell: Dictionary, gap: float) -> Dictionary: return _tap_barrels(ctx, cell, gap))
	return {}


## A compact side threshold is only accepted when the measured person's
## exterior body point lies under the shelter's plan footprint.
static func _witch_shelter_covers_threshold(shelter: Dictionary, door: Dictionary,
		spec: HouseSpec) -> bool:
	if shelter.is_empty() or door.is_empty():
		return false
	var body: Vector2 = Vector2(door["pos"]) + Vector2(door["normal"]) * \
		(HouseGeometry.wall_thickness(spec) + HouseGeometry.PERSON_RADIUS + 0.05)
	# The authored threshold must be covered by the actual threshold roof part.
	# The piece's union rectangle can include distant work bays separated by open
	# sky, so it is not evidence that the doorstep has a shelter.
	var footprint := Rect2()
	for part in shelter.get("parts", []):
		if String(part.get("role", "")) != "witch_shelter_roof":
			continue
		var bounds: AABB = part_aabb(part)
		footprint = Rect2(Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z))
		break
	return footprint.grow(0.05).has_point(body)


## Try each region, each distance from the wall, each place along it, in a fixed
## order, and take the first group the clearance rules accept.
static func _search(ctx: Dictionary, regions: Array, anchor: float, gaps: Array,
		builder: Callable) -> Dictionary:
	for region in regions:
		for gap in gaps:
			for s in _slots(ctx, region, anchor):
				var cell := _cell(ctx, region, s)
				var made: Dictionary = builder.call(cell, float(gap))
				if made.is_empty():
					continue
				if _group_reason(ctx, made).is_empty():
					return made
	return {}


## Allocate the herb bed and drying line as one service cluster. The old
## one-group-at-a-time search could accept a bed in the only clear near-door
## slot, then leave no room for the line. This considers both valid group
## orders and derives candidate centres from the measured free-space boundaries
## and the five-metre threshold, while retaining the shared clearance rules.
static func _witch_ingredient_cluster(ctx: Dictionary) -> Dictionary:
	var orders: Array = [[&"herb_bed", &"drying_line"], [&"drying_line", &"herb_bed"]]
	for order in orders:
		var first_name: StringName = order[0]
		var second_name: StringName = order[1]
		for first_region in _witch_ingredient_regions(ctx, first_name):
			for first_gap in _witch_ingredient_gaps(first_name):
				var first_probe_cell := _cell(ctx, String(first_region), 0.0)
				var first_probe := _witch_ingredient_candidate(ctx, first_name, first_probe_cell, float(first_gap))
				if first_probe.is_empty():
					continue
				for first_s in _adaptive_cluster_slots(ctx, String(first_region),
						float(ctx["witch_service_anchor"]), first_probe, first_probe_cell, float(first_gap)):
					var first_rect_at_s := _made_ground_rect(first_probe)
					first_rect_at_s.position += Vector2(first_probe_cell["tan"]) * first_s
					if _point_rect_distance(Vector2(ctx["witch_service_door"]["pos"]),
						first_rect_at_s) > 5.0:
						continue
					var first_cell := _cell(ctx, String(first_region), first_s)
					var first_made := _witch_ingredient_candidate(ctx, first_name, first_cell, float(first_gap))
					if first_made.is_empty() or not _group_reason(ctx, first_made).is_empty() \
							or not _group_within_threshold(ctx, first_made, 5.0):
						continue
					var trial: Dictionary = ctx.duplicate()
					trial["accepted"] = (ctx["accepted"] as Array).duplicate()
					_reserve_group(trial, first_made)
					for second_region in _witch_ingredient_regions(ctx, second_name):
						for second_gap in _witch_ingredient_gaps(second_name):
							var second_probe_cell := _cell(trial, String(second_region), 0.0)
							var second_probe := _witch_ingredient_candidate(trial, second_name,
								second_probe_cell, float(second_gap))
							if second_probe.is_empty():
								continue
							for second_s in _adaptive_cluster_slots(trial, String(second_region),
									float(ctx["witch_service_anchor"]), second_probe, second_probe_cell,
									float(second_gap)):
								var second_rect_at_s := _made_ground_rect(second_probe)
								second_rect_at_s.position += Vector2(second_probe_cell["tan"]) * second_s
								if _point_rect_distance(Vector2(ctx["witch_service_door"]["pos"]),
									second_rect_at_s) > 5.0:
									continue
								var second_cell := _cell(trial, String(second_region), second_s)
								var second_made := _witch_ingredient_candidate(trial, second_name,
									second_cell, float(second_gap))
								if second_made.is_empty() or not _group_reason(trial, second_made).is_empty() \
										or not _group_within_threshold(trial, second_made, 5.0):
									continue
								var result := {}
								result[first_name] = first_made
								result[second_name] = second_made
								return result
	return {}


static func _witch_ingredient_regions(ctx: Dictionary, name: StringName) -> Array:
	var result: Array[String] = []
	for region in [String(ctx["witch_service_region"]), "front", "rear", "left", "right"]:
		if region not in result:
			result.append(region)
	return result


static func _witch_ingredient_gaps(name: StringName) -> Array[float]:
	var result: Array[float] = []
	if name == &"herb_bed":
		result.append(0.5)
		result.append(1.0)
	else:
		result.append(0.9)
		result.append(1.3)
	return result


static func _witch_ingredient_candidate(ctx: Dictionary, name: StringName,
		cell: Dictionary, gap: float) -> Dictionary:
	if name == &"herb_bed":
		# Candidate probes use a deterministic local RNG, never the shared yard stream.
		var probe_ctx: Dictionary = ctx.duplicate()
		var probe_rng := RandomNumberGenerator.new()
		var plan: HousePlan = ctx["plan"]
		probe_rng.seed = hash("witch_ingredient|%d|%s|%s|%s|%.3f|%.3f|%.3f" % [
			plan.spec.seed, plan.spec.style, plan.spec.trade, String(name), gap,
			float(cell["o"].x), float(cell["o"].y)])
		probe_ctx["rng"] = probe_rng
		return _herb_bed(probe_ctx, cell, gap, false)
	return _washing_line(cell, gap, 2.0, false)


static func _adaptive_cluster_slots(ctx: Dictionary, region: String, anchor: float,
		probe: Dictionary, base_cell: Dictionary, gap: float) -> Array[float]:
	var candidate_rect := _made_ground_rect(probe)
	var local_probe := _world_rect_to_cell(base_cell, candidate_rect)
	var half_t := local_probe.size.x * 0.5
	var env_local := _world_rect_to_cell(base_cell, ctx["env"])
	var low := env_local.position.x + half_t + GAP
	var high := env_local.end.x - half_t - GAP
	var values: Array[float] = []
	for s in _slots(ctx, region, anchor):
		_add_cluster_slot(values, float(s), low, high)
	_add_cluster_slot(values, anchor, low, high)
	_add_cluster_slot(values, low, low, high)
	_add_cluster_slot(values, high, low, high)
	var tangent: Vector2 = base_cell["tan"]
	var origin: Vector2 = base_cell["o"]
	for obstacle in ctx["accepted"]:
		var box: AABB = obstacle
		var r := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		var local := _world_rect_to_cell(base_cell, r)
		_add_cluster_slot(values, local.position.x - half_t - GAP - 0.01, low, high)
		_add_cluster_slot(values, local.end.x + half_t + GAP + 0.01, low, high)
	var door: Dictionary = ctx["witch_service_door"]
	var door_local := (Vector2(door["pos"]) - origin).dot(tangent)
	# Exact threshold-circle edge for the measured candidate depth interval.
	var point_local := Vector2((Vector2(door["pos"]) - origin).dot(tangent),
		(Vector2(door["pos"]) - origin).dot(Vector2(base_cell["out"])))
	var rect_local := _world_rect_to_cell(base_cell, candidate_rect)
	var perpendicular := maxf(maxf(rect_local.position.y - point_local.y, 0.0),
		point_local.y - rect_local.end.y)
	if perpendicular <= 5.0:
		var tangent_reach := sqrt(maxf(0.0, 25.0 - perpendicular * perpendicular))
		_add_cluster_slot(values, door_local - tangent_reach - half_t, low, high)
		_add_cluster_slot(values, door_local + tangent_reach + half_t, low, high)
	for opening in ctx["plan"].doors + ctx["plan"].windows:
		if Vector2(opening["normal"]).dot(Vector2(base_cell["out"])) < 0.95:
			continue
		var center := (Vector2(opening["pos"]) - origin).dot(tangent)
		var half_opening := float(opening.get("width", 0.0)) * 0.5
		if opening in ctx["plan"].doors:
			half_opening = (float(opening["width"]) + 1.1) * 0.5
		elif ctx["plan"].spec.window_shutters:
			half_opening = float(opening["width"]) + 0.11
		else:
			half_opening += 0.11
		_add_cluster_slot(values, center - half_opening - half_t - GAP - 0.01, low, high)
		_add_cluster_slot(values, center + half_opening + half_t + GAP + 0.01, low, high)
	values.sort_custom(func(a: float, b: float) -> bool:
		if absf(absf(a - anchor) - absf(b - anchor)) > 0.001:
			return absf(a - anchor) < absf(b - anchor)
		return a < b)
	return values


static func _world_rect_to_cell(cell: Dictionary, rect: Rect2) -> Rect2:
	var points: Array[Vector2] = [rect.position, rect.end,
		Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for point in points:
		var delta := point - Vector2(cell["o"])
		var local := Vector2(delta.dot(Vector2(cell["tan"])), delta.dot(Vector2(cell["out"])))
		lo = lo.min(local)
		hi = hi.max(local)
	return Rect2(lo, hi - lo)


static func _made_ground_rect(made: Dictionary) -> Rect2:
	var result := Rect2()
	var first := true
	for piece in made.get("pieces", []):
		var r: Rect2 = piece_rect(piece)
		result = r if first else result.merge(r)
		first = false
	for prop in made.get("props", []):
		var b: AABB = HouseExterior.bounds_of(prop)
		var r := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
		result = r if first else result.merge(r)
		first = false
	return result


static func _add_cluster_slot(values: Array[float], value: float, low: float,
		high: float) -> void:
	if value < low - 0.002 or value > high + 0.002:
		return
	for prior in values:
		if absf(prior - value) < 0.015:
			return
	values.append(clampf(value, low, high))


static func _reserve_group(ctx: Dictionary, made: Dictionary) -> void:
	for prop in made.get("props", []):
		(ctx["accepted"] as Array).append(HouseExterior.bounds_of(prop))
		if prop.has("operation_zone"):
			var zone: Rect2 = prop["operation_zone"]
			(ctx["accepted"] as Array).append(AABB(Vector3(zone.position.x, 0.0, zone.position.y),
				Vector3(zone.size.x, WITCH_WORK_CLEARANCE, zone.size.y)))
	for piece in made.get("pieces", []):
		for part in piece["parts"]:
			(ctx["accepted"] as Array).append(part_aabb(part))


## Why a group cannot stand where it is. Empty when it can.
static func _group_reason(ctx: Dictionary, made: Dictionary) -> String:
	var p: HousePlan = ctx["plan"]
	var env: Rect2 = ctx["env"]
	var seen: Array = ctx["accepted"]
	for prop in made.get("props", []):
		var why := clear_reason(p, env, HouseExterior.bounds_of(prop))
		if why.is_empty():
			why = _overlap_reason(seen, HouseExterior.bounds_of(prop))
		if not why.is_empty():
			return why
	for piece in made.get("pieces", []):
		for part in piece["parts"]:
			var box := part_aabb(part)
			var why := clear_reason(p, env, box)
			if why.is_empty():
				why = _overlap_reason(seen, box)
			if not why.is_empty():
				return why
	return ""


static func _overlap_reason(seen: Array, box: AABB) -> String:
	if _is_flush(box):
		for other in seen:
			if not _is_flush(other) and box.grow(GAP).intersects(other):
				return "overlaps another yard piece"
		return ""
	for other in seen:
		if box.grow(GAP).intersects(other):
			return "overlaps another yard piece"
	return ""


static func _is_flush(box: AABB) -> bool:
	return box.position.y + box.size.y <= FLUSH


## THE shared rule. Whether one measured box may stand in this yard: inside the
## envelope, not in the house, not on the porch, and -- unless it is flush with
## the ground -- not in a door approach, a window's drip and shutter, or the
## chimney. The facade half is HouseExterior.facade_clear, the very function
## the facade recipes use. Empty when clear.
static func clear_reason(plan: HousePlan, env: Rect2, box: AABB) -> String:
	var r := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	if r.position.x < env.position.x - 0.005 or r.position.y < env.position.y - 0.005 \
			or r.end.x > env.end.x + 0.005 or r.end.y > env.end.y + 0.005:
		return "outside the yard envelope"
	var site := HouseGeometry.site_rect(plan.spec)
	var building := AABB(Vector3(site.position.x, 0, site.position.y),
		Vector3(site.size.x, plan.spec.height * plan.spec.storeys, site.size.y))
	if box.intersects(building.grow(-0.01)):
		return "intersects the house wall"
	if _is_flush(box):
		return ""
	var why := HouseExterior.facade_clear(plan, box)
	if not why.is_empty():
		return why
	var porch := HouseGeometry.porch_rect(plan)
	if porch.size.x > 0.0 and box.intersects(AABB(Vector3(porch.position.x, -0.1, porch.position.y),
			Vector3(porch.size.x, HouseGeometry.DOOR_H + 0.6, porch.size.y))):
		return "stands on the porch"
	return ""


# ----------------------------------------------------------- measured prop groups

## One prop standing out from the wall in `cell`, `gap` metres off it, facing out.
static func _prop_at(cell: Dictionary, t: float, gap: float, key: String, scale: float,
		role: String, face: Vector2 = Vector2.ZERO) -> Dictionary:
	var out: Vector2 = cell["out"]
	var dir: Vector2 = out if face == Vector2.ZERO else face
	var yaw := atan2(-dir.x, -dir.y)
	var foot := PropCatalog.footprint_rotated(key, yaw + PropCatalog.face_offset(key)) * scale
	var depth := foot.dot(out.abs())
	var centre := _w(cell, t, gap + depth * 0.5)
	return make_prop(key, centre, yaw, scale, role, str(cell["host"]))


## A prop dropped on a centre. Origin follows the measured centre offset, the
## way the facade pieces do, so bounds_of() and the assembler agree.
static func make_prop(key: String, centre: Vector2, yaw: float, scale: float,
		role: String, host: String) -> Dictionary:
	var rotation := Basis(Vector3.UP, yaw + PropCatalog.face_offset(key))
	var off: Vector3 = rotation * (PropCatalog.centre_offset(key) * scale)
	var prop := {"key": key, "pos": Vector3(centre.x - off.x, 0.0, centre.y - off.z),
		"yaw": yaw, "scale": scale, "role": role, "host": host, "storey": 0,
		"mounted": false}
	prop["bounds"] = HouseExterior.bounds_of(prop)
	return prop


static func _prop_group(ctx: Dictionary, cell: Dictionary, gap: float, key: String,
		scale: float, role: String) -> Dictionary:
	if not PropCatalog.known(key):
		return {}
	return {"props": [_prop_at(cell, 0.0, gap, key, scale, role)]}


static func _porch_pail(ctx: Dictionary) -> Dictionary:
	var door: Dictionary = ctx["door"]
	var w: float = float(door["width"]) + 1.1
	var lean: float = -float(ctx["side_pref"])
	for flip in [1.0, -1.0]:
		var s: float = ctx["door_u"] + lean * flip * (w * 0.5 + 0.45)
		var cell := _cell(ctx, "front", s)
		var made := {"props": [_prop_at(cell, 0.0, 0.15, "Bucket_Wooden_1", 1.0, "porch_pail")]}
		made["props"][0]["host"] = "porch" if ctx["plan"].spec.porch else "front"
		if _group_reason(ctx, made).is_empty():
			return made
	return {}


## The stepping-stone path from the road edge to the door. Flush with the
## ground, so it is walked over and may cross the door approach.
static func _path(ctx: Dictionary) -> Dictionary:
	var env: Rect2 = ctx["env"]
	var cell := _cell(ctx, "front", ctx["door_u"])
	var parts: Array = []
	var d := 0.28
	var porch := HouseGeometry.porch_rect(ctx["plan"])
	# Full walking-width pavers read as an approach, not a tiny scattering of
	# stones. Built geometry also survives a public checkout without Wild art.
	while d < float(cell["room"]) - 0.24:
		var part := _part(cell, "path_paver", 0.0, d, 0.86, 0.46, 0.0, 0.045, "floor")
		var b := part_aabb(part)
		var r := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
		var on_porch: bool = porch.size.x > 0.0 and porch.grow(0.05).intersects(r)
		if not on_porch and clear_reason(ctx["plan"], env, b).is_empty() \
				and _overlap_reason(ctx["accepted"], b).is_empty():
			parts.append(part)
		d += 0.50
	return {"pieces": [_piece("path", "approach", parts, "path")]} if not parts.is_empty() else {}


static func _flowers(ctx: Dictionary) -> Dictionary:
	var door: Dictionary = ctx["door"]
	var w: float = float(door["width"]) + 1.1
	var props: Array = []
	var keys := ["Nature_Flower_3_Clump", "Nature_Flower_5_Clump"]
	for flip in [1.0, -1.0]:
		var s: float = ctx["door_u"] + flip * (w * 0.5 + 0.55 + (0.5 if flip == ctx["side_pref"] else 0.0))
		var cell := _cell(ctx, "front", s)
		var prop := _prop_at(cell, 0.0, 0.2, keys[0 if flip > 0.0 else 1], 1.6, "bed_flowers")
		var probe := {"props": [prop]}
		if _group_reason(ctx, probe).is_empty():
			props.append(prop)
	return {"props": props} if not props.is_empty() else {}


static func _crates(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	if not PropCatalog.known("Crate_Wooden"):
		return {}
	var a := _prop_at(cell, 0.0, gap, "Crate_Wooden", 0.9, "crates")
	var bounds := HouseExterior.bounds_of(a)
	var span := bounds.size.x if absf((cell["tan"] as Vector2).x) > 0.5 else bounds.size.z
	var b := _prop_at(cell, span + 0.1, gap, "Bag", 1.0, "crates")
	return {"props": [a, b]}


static func _tap_barrels(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var a := _prop_at(cell, 0.0, gap, "Barrel", 1.0, "tap_barrel")
	var b := _prop_at(cell, 0.8, gap, "Barrel_Apples" if ctx["plan"].spec.seed % 2 == 0 else "Barrel", 1.0, "tap_barrel")
	var c := _prop_at(cell, 0.4, gap + 0.72, "Barrel", 1.0, "tap_barrel")
	return {"props": [a, b, c]}


static func _training(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var stand := _prop_at(cell, 0.0, gap, "WeaponStand", 1.0, "weapon_stand")
	var dummy := _prop_at(cell, 1.7, gap, "Dummy", 1.0, "training_dummy")
	return {"props": [stand, dummy]}


static func _mushrooms(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var props: Array = []
	var keys := ["Wild_Mushroom_Common", "Wild_Mushroom_Laetiporus", "Wild_Mushroom_Common"]
	var at := [0.0, 0.55, 1.0]
	var depth := [0.0, 0.25, -0.1]
	for i in 3:
		props.append(_prop_at(cell, at[i], gap + depth[i] + 0.2, keys[i], 0.35, "mushrooms"))
	return {"props": props}


# ----------------------------------------------------------------- built pieces

## A box in cell coordinates: `st` along the wall, `sd` out from it, `h` high from
## `y0`, centred at (t, d). World-aligned, so the part carries no rotation.
static func _part(cell: Dictionary, role: String, t: float, d: float, st: float, sd: float,
		y0: float, h: float, surf: String) -> Dictionary:
	var c := _w(cell, t, d)
	var tan_v: Vector2 = cell["tan"]
	var out_v: Vector2 = cell["out"]
	var size := tan_v.abs() * st + out_v.abs() * sd
	return {"role": role, "surf": surf, "size": Vector3(size.x, h, size.y),
		"centre": Vector3(c.x, y0 + h * 0.5, c.y), "basis": Basis()}


static func part_xform(part: Dictionary) -> Transform3D:
	return Transform3D(part["basis"], part["centre"])


static func part_aabb(part: Dictionary) -> AABB:
	var xf := part_xform(part)
	var half: Vector3 = (part["size"] as Vector3) * 0.5
	var out := AABB(xf * -half, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out = out.expand(xf * Vector3(half.x * sx, half.y * sy, half.z * sz))
	return out


static func piece_rect(piece: Dictionary) -> Rect2:
	var r := Rect2()
	var first := true
	for part in piece["parts"]:
		var b := part_aabb(part)
		var pr := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
		r = pr if first else r.merge(pr)
		first = false
	return r


static func _piece(kind: String, role: String, parts: Array, host: String) -> Dictionary:
	return {"kind": kind, "role": role, "host": host, "parts": parts}


## A run of posts and two rails from (t0, d0) to (t1, d1), axis-aligned.
static func _fence_run(cell: Dictionary, t0: float, d0: float, t1: float, d1: float,
		parts: Array, gap_from := 0.0, gap_to := 0.0) -> void:
	var along_t := absf(t1 - t0) > absf(d1 - d0)
	var length := absf(t1 - t0) if along_t else absf(d1 - d0)
	var posts := maxi(int(ceil(length / 1.2)), 1)
	for i in posts + 1:
		var f := float(i) / float(posts)
		var t := lerpf(t0, t1, f)
		var d := lerpf(d0, d1, f)
		parts.append(_part(cell, "fence_post", t, d, 0.09, 0.09, 0.0, 1.05, "trim"))
	# rails, skipping a gateway between gap_from and gap_to along the run
	var spans: Array = [[0.0, length]]
	if gap_to > gap_from:
		spans = [[0.0, gap_from], [gap_to, length]]
	for sp in spans:
		if float(sp[1]) - float(sp[0]) < 0.05:
			continue
		var mid: float = (float(sp[0]) + float(sp[1])) * 0.5
		var run: float = float(sp[1]) - float(sp[0])
		var tc: float = lerpf(t0, t1, mid / length)
		var dc: float = lerpf(d0, d1, mid / length)
		for y in [0.42, 0.82]:
			var st: float = run if along_t else 0.05
			var sd: float = 0.05 if along_t else run
			parts.append(_part(cell, "fence_rail", tc, dc, st, sd, y, 0.07, "trim"))


## A fenced kitchen garden: three sides of rails and the wall's side left open
## as a way in, a raised bed, and plants.
static func _garden(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var room: float = cell["room"]
	var d0 := gap + 0.4
	var depth: float = minf(1.7, room - d0 - 0.12)
	if depth < 1.0:
		return {}
	var w := 3.0
	var d1 := d0 + depth
	var parts: Array = []
	_fence_run(cell, -w * 0.5, d1, w * 0.5, d1, parts)
	_fence_run(cell, -w * 0.5, d0, -w * 0.5, d1, parts)
	_fence_run(cell, w * 0.5, d0, w * 0.5, d1, parts)
	_fence_run(cell, -w * 0.5, d0, w * 0.5, d0, parts, w * 0.5 - 0.5, w * 0.5 + 0.5)
	var bed_d := (d0 + d1) * 0.5
	parts.append(_part(cell, "bed_soil", 0.0, bed_d, w - 0.5, depth - 0.5, 0.0, 0.2, "trim"))
	var made := {"pieces": [_piece("fence", "garden", parts, str(cell["host"]))], "props": []}
	var rng: RandomNumberGenerator = ctx["rng"]
	var base := rng.randi()
	for i in 5:
		var key: String = HERBS[(base + i) % HERBS.size()]
		var tt := -w * 0.5 + 0.5 + float(i) * (w - 1.0) / 4.0
		var prop := make_prop(key, _w(cell, tt, bed_d), 0.0, _fit(key, 0.55), "kitchen_garden", str(cell["host"]))
		made["props"].append(_raised(prop, 0.2))
	return made


## A prop standing on something (a raised bed) rather than the ground.
static func _raised(prop: Dictionary, y: float) -> Dictionary:
	var at: Vector3 = prop["pos"]
	at.y = y
	prop["pos"] = at
	prop["bounds"] = HouseExterior.bounds_of(prop)
	return prop


static func _fit(key: String, target: float) -> float:
	var f := PropCatalog.footprint(key)
	return clampf(target / maxf(maxf(f.x, f.y), 0.01), 0.2, 1.4)


static func _herb_bed(ctx: Dictionary, cell: Dictionary, gap: float, fenced: bool) -> Dictionary:
	var w := 2.2
	var depth := 0.9
	var d := gap + depth * 0.5
	var parts: Array = []
	parts.append(_part(cell, "bed_board", 0.0, gap + 0.03, w, 0.06, 0.0, 0.28, "trim"))
	parts.append(_part(cell, "bed_board", 0.0, gap + depth - 0.03, w, 0.06, 0.0, 0.28, "trim"))
	parts.append(_part(cell, "bed_board", -w * 0.5 + 0.03, d, 0.06, depth - 0.12, 0.0, 0.28, "trim"))
	parts.append(_part(cell, "bed_board", w * 0.5 - 0.03, d, 0.06, depth - 0.12, 0.0, 0.28, "trim"))
	parts.append(_part(cell, "bed_soil", 0.0, d, w - 0.12, depth - 0.12, 0.0, 0.22, "trim"))
	var made := {"pieces": [_piece("bed", "herb_bed", parts, str(cell["host"]))], "props": []}
	var rng: RandomNumberGenerator = ctx["rng"]
	var base := rng.randi()
	for i in 4:
		var key: String = HERBS[(base + i) % HERBS.size()]
		var tt := -w * 0.5 + 0.4 + float(i) * (w - 0.8) / 3.0
		var prop := make_prop(key, _w(cell, tt, d), float(i) * 1.1, _fit(key, 0.5), "herbs", str(cell["host"]))
		made["props"].append(_raised(prop, 0.22))
	return made


## Two posts and a line between them, with linen on it.
static func _washing_line(cell: Dictionary, gap: float, length: float, linen: bool) -> Dictionary:
	var parts: Array = []
	for side in [-1.0, 1.0]:
		parts.append(_part(cell, "line_post", side * length * 0.5, gap, 0.1, 0.1, 0.0, 1.95, "trim"))
	parts.append(_part(cell, "line", 0.0, gap, length, 0.02, 1.85, 0.02, "trim"))
	var sheets := 3 if linen else 4
	for i in sheets:
		var t := -length * 0.5 + (float(i) + 0.75) * length / (float(sheets) + 0.5)
		var h := 0.5 if linen else 0.35
		parts.append(_part(cell, "linen" if linen else "herb_bunch", t, gap, 0.5 if linen else 0.18, 0.02,
			1.85 - h, h, "wall" if linen else "trim"))
	return {"pieces": [_piece("washing_line", "washing_line", parts, str(cell["host"]))]}


## Logs end-on to the eye: a stack of short square logs standing between two
## stakes, against the wall under the eaves.
static func _woodpile(ctx: Dictionary) -> Dictionary:
	var anchor := _chimney_anchor(ctx)
	var regions: Array = [_chimney_region(ctx)] if _chimney_region(ctx) != "" else []
	var kitchen := _kitchen_region(ctx)
	if kitchen != "" and kitchen not in regions:
		regions.append(kitchen)
	for r in ["rear", "left", "right"]:
		if r not in regions:
			regions.append(r)
	var rng: RandomNumberGenerator = ctx["rng"]
	var salt := rng.randi()
	return _search(ctx, regions, anchor, [0.12, 0.3],
		func(cell: Dictionary, gap: float) -> Dictionary: return _logs(cell, gap, salt))


static func _logs(cell: Dictionary, gap: float, salt: int) -> Dictionary:
	var parts: Array = []
	var cols := 7
	var rows := 5
	var size := 0.13
	var width := float(cols) * size
	for r in rows:
		for c in cols:
			var jitter := float(((salt >> (r * cols + c) % 20) & 3)) * 0.03
			var length := 0.46 + jitter
			var t := -width * 0.5 + (float(c) + 0.5) * size
			parts.append(_part(cell, "log", t, gap + length * 0.5, size - 0.012, length,
				float(r) * size, size - 0.012, "trim"))
	for side in [-1.0, 1.0]:
		parts.append(_part(cell, "stake", side * (width * 0.5 + 0.04), gap + 0.3, 0.06, 0.06, 0.0, 0.95, "trim"))
	return {"pieces": [_piece("woodpile", "woodpile", parts, str(cell["host"]))]}


static func _midden(cell: Dictionary, gap: float) -> Dictionary:
	var parts: Array = []
	parts.append(_part(cell, "midden_heap", 0.0, gap + 0.5, 1.4, 1.0, 0.0, 0.26, "trim"))
	parts.append(_part(cell, "midden_heap", 0.1, gap + 0.5, 0.9, 0.7, 0.26, 0.2, "trim"))
	parts.append(_part(cell, "midden_heap", -0.15, gap + 0.45, 0.4, 0.3, 0.46, 0.12, "trim"))
	return {"pieces": [_piece("midden", "midden", parts, str(cell["host"]))]}


## The smith's quench trough: a long open box of boards.
static func _trough(cell: Dictionary, gap: float) -> Dictionary:
	var l := 1.3
	var w := 0.5
	var h := 0.5
	var d := gap + w * 0.5
	var parts: Array = []
	parts.append(_part(cell, "trough_floor", 0.0, d, l, w, 0.0, 0.08, "trim"))
	parts.append(_part(cell, "trough_side", 0.0, d - w * 0.5 + 0.03, l, 0.06, 0.0, h, "trim"))
	parts.append(_part(cell, "trough_side", 0.0, d + w * 0.5 - 0.03, l, 0.06, 0.0, h, "trim"))
	parts.append(_part(cell, "trough_end", -l * 0.5 + 0.03, d, 0.06, w - 0.12, 0.0, h, "trim"))
	parts.append(_part(cell, "trough_end", l * 0.5 - 0.03, d, 0.06, w - 0.12, 0.0, h, "trim"))
	return {"pieces": [_piece("trough", "quench_trough", parts, str(cell["host"]))]}


## The charcoal lean-to: two posts, a plank roof sloping away from the wall, and
## a stepped heap of charcoal under it.
static func _leanto(cell: Dictionary) -> Dictionary:
	var w := 2.4
	var depth := 1.5
	var parts: Array = []
	for side in [-1.0, 1.0]:
		parts.append(_part(cell, "leanto_post", side * (w * 0.5 - 0.06), depth, 0.12, 0.12, 0.0, 1.85, "trim"))
	var tan3 := Vector3((cell["tan"] as Vector2).x, 0.0, (cell["tan"] as Vector2).y)
	var out3 := Vector3((cell["out"] as Vector2).x, 0.0, (cell["out"] as Vector2).y)
	var turn := signf(tan3.cross(out3).y)
	var drop := 0.35
	var slope := atan2(drop, depth)
	var roof := _part(cell, "leanto_roof", 0.0, depth * 0.5 + 0.07, w, depth, 1.97 - drop * 0.5, 0.06, "trim")
	roof["basis"] = Basis(tan3, -turn * slope)
	parts.append(roof)
	parts.append(_part(cell, "charcoal", 0.0, 0.55, 1.7, 0.9, 0.0, 0.55, "trim"))
	parts.append(_part(cell, "charcoal", 0.2, 0.55, 1.0, 0.6, 0.55, 0.3, "trim"))
	parts.append(_part(cell, "charcoal", -0.55, 1.2, 0.5, 0.4, 0.0, 0.3, "trim"))
	return {"pieces": [_piece("leanto", "charcoal_leanto", parts, str(cell["host"]))]}


## A witch's covered processing station, attached to the service wall. The
## wall carries the back edge; the enclosed service wing has its own bearing roof.
## Measured cauldron, pot, bucket and workbench are laid out as a use sequence,
## rather than as four unrelated wall props.
static func _witch_work_shelter(ctx: Dictionary, cell: Dictionary, gap: float) -> Dictionary:
	var threshold_layout := ctx.has("witch_service_door")
	var layout: Dictionary = _witch_work_shelter_layout(ctx, cell) if threshold_layout else {}
	var depth := 2.4
	# The full Workshop has a separate, narrow threshold hood and one measured
	# enclosed work wing. The compact shared Hall keeps its existing canopy.
	var wall_y: float = minf(float(ctx["plan"].spec.height) - 0.02, 2.58) if threshold_layout \
		else minf(float(ctx["plan"].spec.height) - 0.12, 2.5)
	var drop := 0.18 if threshold_layout else 0.28
	var roof_thickness := 0.08
	var props: Array = []
	if not PropCatalog.known("Workbench") or not PropCatalog.known("Cauldron") \
			or not PropCatalog.known("Pot_1") or not PropCatalog.known("Bucket_Wooden_1"):
		return {}
	var bench_t: float = float(layout.get("bench_t", 0.0))
	var cauldron_t: float = float(layout.get("cauldron_t", -1.0))
	var pot_t: float = float(layout.get("pot_t", 0.75))
	var bucket_t: float = float(layout.get("bucket_t", 1.35))
	var pot_d: float = float(layout.get("pot_d", 1.50))
	var bucket_d: float = float(layout.get("bucket_d", 1.50))
	var bench_depth := float(layout.get("bench_d", 0.12))
	props.append(_prop_at(cell, bench_t, gap + bench_depth, "Workbench", 1.0, "witch_prep_bench"))
	props.append(_prop_at(cell, cauldron_t, gap + float(layout.get("cauldron_d", 1.25)), "Cauldron", 1.0, "witch_brewing_heat"))
	props.append(_prop_at(cell, pot_t, gap + pot_d, "Pot_1", 1.0, "witch_cookware"))
	props.append(_prop_at(cell, bucket_t, gap + bucket_d, "Bucket_Wooden_1", 1.0, "witch_water_vessel"))
	var bench_index := _prop_index(props, "witch_prep_bench")
	var cauldron_index := _prop_index(props, "witch_brewing_heat")
	if bench_index < 0 or cauldron_index < 0:
		return {}
	var pot_index := _prop_index(props, "witch_cookware")
	var bucket_index := _prop_index(props, "witch_water_vessel")
	if pot_index < 0 or bucket_index < 0:
		return {}
	# The catalogue AABBs include each model's measured centre offset. Keep the
	# pot and bucket on the same shelf line, but slide the bucket outward until
	# their actual boxes clear by GAP. The small bounded steps also preserve a
	# useful gap when a catalogue measurement changes slightly.
	var pot_bounds: AABB = HouseExterior.bounds_of(props[pot_index])
	var bucket_depth := bucket_d
	var bucket_clear := false
	for attempt in range(16):
		var bucket_bounds: AABB = HouseExterior.bounds_of(props[bucket_index])
		var bucket_local: Rect2 = _prop_cell_rect(cell, bucket_bounds)
		if not pot_bounds.grow(GAP).intersects(bucket_bounds) \
				and bucket_local.end.y <= depth - 0.2:
			bucket_clear = true
			break
		bucket_depth += 0.05
		props[bucket_index] = _prop_at(cell, bucket_t, gap + bucket_depth,
			"Bucket_Wooden_1", 1.0, "witch_water_vessel")
	if not bucket_clear:
		return {}
	bucket_d = bucket_depth
	var bench_local: Rect2 = _prop_cell_rect(cell, HouseExterior.bounds_of(props[bench_index]))
	var cauldron_local: Rect2 = _prop_cell_rect(cell, HouseExterior.bounds_of(props[cauldron_index]))
	# These measured use stances are kept independent of their roof bays.
	var bench_zone_local := Rect2(Vector2(bench_local.get_center().x - WITCH_WORK_APPROACH * 0.5,
		bench_local.end.y + HouseGeometry.PERSON_RADIUS + 0.025),
		Vector2(WITCH_WORK_APPROACH, WITCH_WORK_APPROACH))
	var cauldron_zone_t := cauldron_local.position.x - GAP - WITCH_WORK_APPROACH
	if threshold_layout and not bool(ctx["witch_compact_service_threshold"]):
		# Face the tending stance inward so it stays under the short shed roof.
		# Keep the vessels on the opposite tangent side, clear of the stance.
		if cauldron_local.get_center().x > bench_local.get_center().x:
			cauldron_zone_t = cauldron_local.end.x + GAP
	else:
		if ctx.has("witch_service_door"):
			var door_local_t := (Vector2(ctx["witch_service_door"]["pos"]) - Vector2(cell["o"])) \
				.dot(Vector2(cell["tan"]))
			if cauldron_local.get_center().x < door_local_t:
				cauldron_zone_t = cauldron_local.end.x + GAP
	var cauldron_zone_local := Rect2(Vector2(cauldron_zone_t,
		cauldron_local.get_center().y - WITCH_WORK_APPROACH * 0.5),
		Vector2(WITCH_WORK_APPROACH, WITCH_WORK_APPROACH))
	if threshold_layout and not bool(ctx["witch_compact_service_threshold"]):
		cauldron_zone_local = Rect2(Vector2(cauldron_local.get_center().x - WITCH_WORK_APPROACH * 0.5,
			cauldron_local.position.y - GAP - WITCH_WORK_APPROACH),
			Vector2(WITCH_WORK_APPROACH, WITCH_WORK_APPROACH))
	props[bench_index]["operation_zone"] = _cell_rect(cell, bench_zone_local)
	props[bench_index]["operation_side"] = "outward"
	props[cauldron_index]["operation_zone"] = _cell_rect(cell, cauldron_zone_local)
	props[cauldron_index]["operation_side"] = "inward"
	var threshold_t := 0.0
	if threshold_layout:
		threshold_t = (Vector2(ctx["witch_service_door"]["pos"]) - Vector2(cell["o"])) \
			.dot(Vector2(cell["tan"]))
	var prep_bounds: AABB = HouseExterior.bounds_of(props[bench_index])
	var prep_local: Rect2 = _prop_cell_rect(cell, prep_bounds)
	var brew_min := INF
	var brew_max := -INF
	for index in [_prop_index(props, "witch_brewing_heat"),
			_prop_index(props, "witch_cookware"), _prop_index(props, "witch_water_vessel")]:
		var local: Rect2 = _prop_cell_rect(cell, HouseExterior.bounds_of(props[index]))
		brew_min = minf(brew_min, local.position.x)
		brew_max = maxf(brew_max, local.end.x)
	# The brewing awning protects the tending stance as well as the cookware.
	# Include its measured tangent extent when sizing the little roof bay.
	brew_min = minf(brew_min, cauldron_zone_local.position.x)
	brew_max = maxf(brew_max, cauldron_zone_local.end.x)
	var modules: Array[Dictionary] = []
	var wing_center := 0.0
	var wing_width := 0.0
	var wing_entry_half := 0.0
	var wing_entry_center_d := 0.0
	if threshold_layout and not bool(ctx["witch_compact_service_threshold"]):
		var door_width := float(ctx["witch_service_door"].get("width", HouseGeometry.DOOR_W))
		wing_entry_half = maxf(HouseGeometry.PERSON_RADIUS + 0.09, 0.36)
		wing_entry_center_d = gap + 1.56
		modules.append({"prefix": "witch_shelter", "center": threshold_t,
			# The entry hood remains independently measured around the threshold.
			"width": door_width + 1.5, "wall_y": wall_y, "drop": drop})
		var wing_min := minf(prep_local.position.x, brew_min)
		var wing_max := maxf(prep_local.end.x, brew_max)
		wing_min = minf(wing_min, bench_zone_local.position.x)
		wing_max = maxf(wing_max, bench_zone_local.end.x)
		wing_min = minf(wing_min, cauldron_zone_local.position.x)
		wing_max = maxf(wing_max, cauldron_zone_local.end.x)
		wing_center = (wing_min + wing_max) * 0.5
		# Wall thickness is 0.12 m total; the roof adds another 0.12 m, leaving
		# 0.06 m of eave beyond each wall while keeping the measured bay compact.
		wing_width = wing_max - wing_min + 0.12
		wing_width = maxf(wing_width, 2.0 * wing_entry_half + 0.55)
		modules.append({"prefix": "witch_work_wing", "center": wing_center,
			"width": wing_width, "wall_y": wall_y, "drop": drop})
	else:
		modules.append({"prefix": "witch_shelter", "center": 0.0,
			"width": float(layout.get("width", 4.9)), "wall_y": wall_y, "drop": drop})
	var parts: Array = []
	var roof_rects: Dictionary = {}
	for module in modules:
		var prefix := String(module["prefix"])
		var module_parts := _witch_shelter_module_parts(cell, prefix, float(module["center"]),
			float(module["width"]), gap, depth, float(module["wall_y"]),
			float(module["drop"]), roof_thickness)
		parts.append_array(module_parts)
		for part in module_parts:
			if String(part.get("role", "")) != prefix + "_roof":
				continue
			var bounds: AABB = part_aabb(part)
			roof_rects[prefix] = Rect2(Vector2(bounds.position.x, bounds.position.z),
				Vector2(bounds.size.x, bounds.size.z))
	if threshold_layout and not bool(ctx["witch_compact_service_threshold"]):
		# Timber returns and a closed yard-facing wall turn the measured station
		# roof into a shed. The entry gap faces the actual door approach through
		# the inboard side return; the house wall closes the back.
		var wall_thickness := 0.12
		var front_d := gap + depth - wall_thickness * 0.5
		var wing_left := wing_center - wing_width * 0.5
		var wing_right := wing_center + wing_width * 0.5
		var inner_side := -1.0 if threshold_t <= wing_left else 1.0
		var side_start := gap + 0.04
		var side_end := gap + depth - 0.04
		var entry_start := wing_entry_center_d - wing_entry_half
		var entry_end := wing_entry_center_d + wing_entry_half
		for side in [-1.0, 1.0]:
			var side_t := wing_left + wall_thickness * 0.5 if side < 0.0 \
				else wing_right - wall_thickness * 0.5
			var runs: Array[Vector2] = [Vector2(side_start, side_end)]
			if side == inner_side:
				runs = [Vector2(side_start, entry_start), Vector2(entry_end, side_end)]
			for run in runs:
				var run_length := run.y - run.x
				if run_length <= 0.02:
					continue
				var segment_count := maxi(1, ceili(run_length / 0.3))
				var side_step := run_length / float(segment_count)
				for segment in segment_count:
					var d0 := run.x + float(segment) * side_step
					var d1 := d0 + side_step
					var bearing_y := _witch_roof_under(cell, d1, gap, depth, wall_y, drop, roof_thickness)
					parts.append(_part(cell, "witch_work_wing_wall", side_t,
						(d0 + d1) * 0.5, wall_thickness, side_step + 0.005,
						0.0, bearing_y - 0.008, "trim"))
		# The yard-facing wall has a measured service opening aligned with the prep
		# stance. This leaves body-radius clearance at the work surface while the
		# two side returns and the remaining front panels keep the wing enclosed.
		var front_height := _witch_roof_under(cell, front_d, gap, depth, wall_y, drop, roof_thickness) - 0.008
		var front_open_center := bench_zone_local.get_center().x
		var front_open_half := WITCH_WORK_APPROACH * 0.5 + 0.18
		var front_runs: Array[Vector2] = [Vector2(wing_left, front_open_center - front_open_half),
			Vector2(front_open_center + front_open_half, wing_right)]
		var vent_added := false
		var vent_center_t := NAN
		for run in front_runs:
			var run_width := run.y - run.x
			if run_width <= 0.02:
				continue
			if not vent_added and run_width > 0.95 and front_height > 1.55:
				vent_added = true
				var vent_width := 0.54
				var vent_half := vent_width * 0.5
				var vent_center := (run.x + run.y) * 0.5
				vent_center_t = vent_center
				var vent_left_width := vent_center - vent_half - run.x
				var vent_right_width := run.y - (vent_center + vent_half)
				parts.append(_part(cell, "witch_work_wing_wall", run.x + vent_left_width * 0.5,
					front_d, vent_left_width, wall_thickness, 0.0, front_height, "trim"))
				parts.append(_part(cell, "witch_work_wing_wall", vent_center + vent_half + vent_right_width * 0.5,
					front_d, vent_right_width, wall_thickness, 0.0, front_height, "trim"))
				# Keep the head panel bearing on the shed roof. The lower infill and
				# four short frame pieces make a real high vent in the blank wall.
				var vent_sill := 0.92
				var vent_head := 1.42
				parts.append(_part(cell, "witch_work_wing_wall", vent_center, front_d,
					vent_width, wall_thickness, vent_head, front_height - vent_head, "trim"))
				parts.append(_part(cell, "witch_work_wing_detail", vent_center, front_d,
					vent_width, wall_thickness, 0.0, vent_sill, "trim"))
				for side in [-1.0, 1.0]:
					parts.append(_part(cell, "witch_work_wing_vent_frame",
						vent_center + side * (vent_half - 0.035), front_d,
						0.07, wall_thickness + 0.08, vent_sill, vent_head - vent_sill, "wall"))
				for rail_y in [vent_sill, vent_head - 0.04]:
					parts.append(_part(cell, "witch_work_wing_vent_frame", vent_center, front_d,
						vent_width, wall_thickness + 0.08, rail_y, 0.08, "wall"))
			else:
				parts.append(_part(cell, "witch_work_wing_wall", (run.x + run.y) * 0.5,
					front_d, run_width, wall_thickness, 0.0, front_height, "trim"))
		# Full-height jambs and a bearing lintel frame the yard-facing opening.
		var jamb_center_offset := front_open_half - wall_thickness * 0.5
		for side in [-1.0, 1.0]:
			parts.append(_part(cell, "witch_work_wing_wall",
				front_open_center + side * jamb_center_offset, front_d,
				wall_thickness, wall_thickness, 0.0, front_height, "trim"))
		var lintel_width := WITCH_WORK_APPROACH + 0.12
		parts.append(_part(cell, "witch_work_wing_header", front_open_center, front_d,
			lintel_width, wall_thickness, front_height - 0.16, 0.16, "trim"))
		# Pale timber accents break up the solid wall faces and make the service
		# opening read as a working shed door. Keep them on the wall plane; they do
		# not occupy either measured standing zone.
		var frame_width := 0.075
		var frame_stations: Array[float] = [wing_left + frame_width * 0.5,
			front_open_center - front_open_half - frame_width * 0.5,
			front_open_center + front_open_half + frame_width * 0.5,
			wing_right - frame_width * 0.5]
		for edge_t in frame_stations:
			parts.append(_part(cell, "witch_work_wing_frame", edge_t, front_d,
				frame_width, wall_thickness + 0.02, 0.0, front_height, "wall"))
		for run in front_runs:
			var run_width := run.y - run.x
			if run_width <= 0.18:
				continue
			var rail_center := (run.x + run.y) * 0.5
			parts.append(_part(cell, "witch_work_wing_frame", rail_center, front_d,
					 run_width, wall_thickness + 0.02, 0.28, 0.07, "wall"))
			parts.append(_part(cell, "witch_work_wing_frame", rail_center, front_d,
					 run_width, wall_thickness + 0.02, front_height - 0.12, 0.07, "wall"))
			if run_width > 0.75:
				for fraction in [0.10, 0.90]:
					var batten_t: float = float(run.x) + run_width * float(fraction)
					if is_finite(vent_center_t) and absf(batten_t - vent_center_t) < 0.35:
						continue
					parts.append(_part(cell, "witch_work_wing_batten", batten_t, front_d,
						0.12, wall_thickness + 0.08, 0.08, front_height - 0.16, "wall"))
	var piece := _piece("witch_work_lean_to", "witch_work_shelter", parts, str(cell["host"]))
	var threshold_rect: Rect2 = roof_rects.get("witch_shelter", Rect2())
	var prep_roof: Rect2 = roof_rects.get("witch_work_wing", threshold_rect)
	var brew_roof: Rect2 = roof_rects.get("witch_work_wing", threshold_rect)
	var module_walls := {"witch_shelter": wall_y,
		"witch_work_wing": wall_y}
	var module_drops := {"witch_shelter": drop,
		"witch_work_wing": drop}
	piece["work_clearance"] = {"origin": cell["o"], "out": cell["out"],
		"tangent": cell["tan"], "gap": gap, "depth": depth, "wall_y": wall_y,
		"drop": drop, "roof_thickness": roof_thickness,
		"required_headroom": WITCH_WORK_CLEARANCE, "approach_size": WITCH_WORK_APPROACH,
		"roof_rect": threshold_rect, "threshold_roof_rect": threshold_rect,
		"prep_roof_rect": prep_roof, "brew_roof_rect": brew_roof}
	# Every item is checked against the others with its measured assembled bounds.
	for i in range(props.size()):
		var a: AABB = HouseExterior.bounds_of(props[i])
		for j in range(i + 1, props.size()):
			if a.grow(GAP).intersects(HouseExterior.bounds_of(props[j])):
				return {}
	for prop in props:
		var bounds: AABB = HouseExterior.bounds_of(prop)
		var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z))
		var is_prep := String(prop["role"]) == "witch_prep_bench"
		var assigned_roof := prep_roof if is_prep else brew_roof
		var assigned_prefix := "witch_work_wing"
		if not roof_rects.has(assigned_prefix):
			assigned_roof = threshold_rect
			assigned_prefix = "witch_shelter"
		if not assigned_roof.grow(-0.08).encloses(footprint):
			return {}
		var local: Rect2 = _prop_cell_rect(cell, bounds)
		if bounds.position.y + bounds.size.y > _witch_roof_under(cell, local.end.y, gap, depth,
			float(module_walls[assigned_prefix]), float(module_drops[assigned_prefix]), roof_thickness) - 0.04:
			return {}
	for prop in [props[bench_index], props[cauldron_index]]:
		var zone: Rect2 = prop["operation_zone"]
		var is_prep := String(prop["role"]) == "witch_prep_bench"
		var zone_roof := prep_roof if is_prep else brew_roof
		var zone_prefix := "witch_work_wing"
		if not roof_rects.has(zone_prefix):
			zone_roof = threshold_rect
			zone_prefix = "witch_shelter"
		if not zone_roof.encloses(zone) or _witch_zone_headroom(cell, zone, gap, depth,
			float(module_walls[zone_prefix]), float(module_drops[zone_prefix]), roof_thickness) < WITCH_WORK_CLEARANCE:
			return {}
		if not _witch_zone_clear(ctx, cell, zone, props, piece, String(prop["role"])):
			return {}
	return {"pieces": [piece], "props": props}


static func _witch_shelter_module_parts(cell: Dictionary, prefix: String, center_t: float,
		width: float, gap: float, depth: float, wall_y: float, drop: float,
		roof_thickness: float) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var ledger_y := _witch_roof_under(cell, gap + 0.12, gap, depth, wall_y, drop, roof_thickness)
	var post_d := gap + depth - 0.06
	var post_y := _witch_roof_under(cell, post_d, gap, depth, wall_y, drop, roof_thickness)
	# The work wing has continuous side returns that bear the eaves. Separate
	# corner posts there would occupy the same volume and z-fight against them.
	if prefix != "witch_work_wing":
		for side in [-1.0, 1.0]:
			parts.append(_part(cell, prefix + "_post", center_t + side * (width * 0.5 - 0.06),
				post_d, 0.12, 0.12, 0.0, post_y, "trim"))
	parts.append(_part(cell, prefix + "_ledger", center_t, gap + 0.06,
		width, 0.12, ledger_y - 0.12, 0.12, "trim"))
	var out3 := Vector3((cell["out"] as Vector2).x, 0.0, (cell["out"] as Vector2).y)
	var roof_frame := Basis(Vector3.UP.cross(out3), Vector3.UP, out3)
	var roof := _part(cell, prefix + "_roof", center_t, gap + depth * 0.5,
		width + 0.12, depth, wall_y - drop * 0.5 - roof_thickness * 0.5,
		roof_thickness, "roof")
	roof["size"] = Vector3(width + 0.12, roof_thickness, depth)
	roof["basis"] = roof_frame * Basis(Vector3.RIGHT, atan2(drop, depth))
	parts.append(roof)
	return parts

static func _point_rect_distance(point: Vector2, rect: Rect2) -> float:
	var closest := Vector2(clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(closest)


static func _group_within_threshold(ctx: Dictionary, made: Dictionary,
		max_distance: float) -> bool:
	var door: Dictionary = ctx["witch_service_door"]
	var point := Vector2(door["pos"])
	for piece in made.get("pieces", []):
		if _point_rect_distance(point, piece_rect(piece)) <= max_distance:
			return true
	for prop in made.get("props", []):
		var bounds: AABB = HouseExterior.bounds_of(prop)
		var rect := Rect2(Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z))
		if _point_rect_distance(point, rect) <= max_distance:
			return true
	return false


static func _witch_tangent_half(cell: Dictionary, key: String, scale := 1.0) -> float:
	if not PropCatalog.known(key):
		return 0.0
	var probe := _prop_at(cell, 0.0, 0.0, key, scale, "witch_width_probe")
	return _prop_cell_rect(cell, HouseExterior.bounds_of(probe)).size.x * 0.5


## Lay a clear threshold lane beside the measured Witch stations. The full
## Workshop keeps its stations on one side and groups them into a short wing.
static func _witch_work_shelter_layout(ctx: Dictionary, cell: Dictionary) -> Dictionary:
	var door: Dictionary = ctx.get("witch_service_door", ctx["door"])
	var lane_half := (float(door.get("width", HouseGeometry.DOOR_W)) + 1.1) * 0.5
	# The workshop threshold's measured exterior approach is an axis-aligned
	# 3.2 m deep reservation. Give the work sequence an additional 0.55 m on
	# both tangent sides so its full measured AABBs stay outside that reservation
	# after the half-metre slot snap. This is only needed for the full Workshop
	# grammar; the compact Hall threshold keeps its existing narrow work layout.
	var approach_margin := 0.55 if not bool(door.get("witch_compact_service_threshold", false)) else 0.0
	var clearance := GAP + 0.15 + approach_margin
	var bench_half := _witch_tangent_half(cell, "Workbench")
	var cauldron_half := _witch_tangent_half(cell, "Cauldron")
	var pot_half := _witch_tangent_half(cell, "Pot_1")
	var bucket_half := _witch_tangent_half(cell, "Bucket_Wooden_1")
	var bench_direction := -1.0
	if not bool(door.get("witch_compact_service_threshold", false)):
		bench_direction = _witch_bench_direction(ctx, cell, door, lane_half, clearance, bench_half)
	var bench_from_door := bench_direction * (lane_half + clearance + bench_half)
	var cauldron_from_door := -bench_direction * (lane_half + clearance \
		+ WITCH_WORK_APPROACH + clearance + cauldron_half)
	var pot_from_door := cauldron_from_door
	var bucket_from_door := cauldron_from_door
	var bench_d := 0.12
	var cauldron_d := 1.25
	var pot_d := 0.12
	var bucket_d := 0.67
	if not bool(door.get("witch_compact_service_threshold", false)):
		bench_d = 0.085
		# Place the stations side by side. The measured half-widths and explicit
		# margin leave the required GAP between the Workbench and cauldron.
		var brew_offset := bench_half + cauldron_half + GAP + 0.03
		cauldron_from_door = bench_from_door + bench_direction * brew_offset
		# Move vessels to the other tangent side of the cauldron. This makes room
		# for the inward-facing tending stance without widening its roof bay.
		var vessel_half := maxf(pot_half, bucket_half)
		var vessel_offset := WITCH_WORK_APPROACH * 0.5 + GAP + vessel_half
		pot_from_door = cauldron_from_door + bench_direction * vessel_offset
		bucket_from_door = pot_from_door
		# Place the brew stance inboard across shed depth. Measured AABBs below
		# still decide whether the vessels and stance are truly clear.
		cauldron_d = 1.25
		pot_d = 0.12
		bucket_d = 0.67
	var minimum := minf(bench_from_door - bench_half, cauldron_from_door - cauldron_half)
	var maximum := maxf(bench_from_door + bench_half, cauldron_from_door + cauldron_half)
	minimum = minf(minimum, pot_from_door - pot_half)
	maximum = maxf(maximum, pot_from_door + pot_half)
	minimum = minf(minimum, bucket_from_door - bucket_half)
	maximum = maxf(maximum, bucket_from_door + bucket_half)
	var center_offset := (minimum + maximum) * 0.5
	var span := maximum - minimum
	var width := span + 2.0 * (0.12 + GAP + 0.03)
	return {"width": width, "center_offset": center_offset,
		"bench_t": bench_from_door - center_offset,
		"cauldron_t": cauldron_from_door - center_offset,
		"pot_t": pot_from_door - center_offset,
		"bucket_t": bucket_from_door - center_offset,
		"bench_d": bench_d, "cauldron_d": cauldron_d,
		"pot_d": pot_d, "bucket_d": bucket_d}


## Put the bench on the side of its real service door that keeps its measured
## upper body away from same-wall daylight openings. Facade clearance validates
## every assembled AABB after slot quantization.
static func _witch_bench_direction(ctx: Dictionary, cell: Dictionary, door: Dictionary,
		lane_half: float, clearance: float, bench_half: float) -> float:
	var plan: HousePlan = ctx["plan"]
	var tangent: Vector2 = cell["tan"]
	var outward: Vector2 = cell["out"]
	var door_point := Vector2(door["pos"])
	var best_direction := -1.0
	var best_conflicts := 2147483647
	for direction in [-1.0, 1.0]:
		var bench_offset: float = direction * (lane_half + clearance + bench_half)
		var conflicts := 0
		for window in plan.windows:
			if HousePlan.record_storey(window) != 0 \
					or Vector2(window["normal"]).dot(outward) < 0.95:
				continue
			var window_offset := (Vector2(window["pos"]) - door_point).dot(tangent)
			var window_half := (float(window["width"]) \
				* (2.0 if plan.spec.window_shutters else 1.0) + 0.22) * 0.5
			if absf(window_offset - bench_offset) < window_half + bench_half + GAP:
				conflicts += 1
		if conflicts < best_conflicts:
			best_conflicts = conflicts
			best_direction = direction
	return best_direction


static func _prop_index(props: Array, role: String) -> int:
	for i in props.size():
		if String(props[i].get("role", "")) == role:
			return i
	return -1


static func _prop_cell_rect(cell: Dictionary, bounds: AABB) -> Rect2:
	var centre := Vector2(bounds.position.x + bounds.size.x * 0.5,
		bounds.position.z + bounds.size.z * 0.5)
	var delta: Vector2 = centre - Vector2(cell["o"])
	var tangent: Vector2 = cell["tan"]
	var outward: Vector2 = cell["out"]
	var half_t: float = (bounds.size.x * absf(tangent.x) + bounds.size.z * absf(tangent.y)) * 0.5
	var half_d: float = (bounds.size.x * absf(outward.x) + bounds.size.z * absf(outward.y)) * 0.5
	var t: float = delta.dot(tangent)
	var d: float = delta.dot(outward)
	return Rect2(Vector2(t - half_t, d - half_d), Vector2(half_t * 2.0, half_d * 2.0))


static func _cell_rect(cell: Dictionary, local: Rect2) -> Rect2:
	var points: Array[Vector2] = [
		_w(cell, local.position.x, local.position.y),
		_w(cell, local.end.x, local.position.y),
		_w(cell, local.end.x, local.end.y),
		_w(cell, local.position.x, local.end.y)]
	var lo := points[0]
	var hi := points[0]
	for point in points:
		lo = lo.min(point)
		hi = hi.max(point)
	return Rect2(lo, hi - lo)


static func _witch_roof_under(cell: Dictionary, d: float, gap: float, depth: float,
		wall_y: float, drop: float, thickness: float) -> float:
	# Measure the lower plane through the transform that emits the roof. This
	# includes the horizontal projection of its tilted thickness.
	var outward: Vector2 = cell["out"]
	var out3 := Vector3(outward.x, 0.0, outward.y)
	var roof_basis := Basis(Vector3.UP.cross(out3), Vector3.UP, out3) * Basis(Vector3.RIGHT, atan2(drop, depth))
	var roof_origin_2: Vector2 = _w(cell, 0.0, gap + depth * 0.5)
	var roof_origin := Vector3(roof_origin_2.x, wall_y - drop * 0.5, roof_origin_2.y)
	var sample_2: Vector2 = _w(cell, 0.0, d)
	var inverse := roof_basis.inverse()
	var local_at_floor: Vector3 = inverse * (Vector3(sample_2.x, 0.0, sample_2.y) - roof_origin)
	var local_y_per_world_y: float = (inverse * Vector3.UP).y
	if absf(local_y_per_world_y) < 0.001:
		return -INF
	return (-thickness * 0.5 - local_at_floor.y) / local_y_per_world_y


static func _witch_zone_headroom(cell: Dictionary, zone: Rect2, gap: float,
		depth: float, wall_y: float, drop: float, thickness: float) -> float:
	var local := _prop_cell_rect(cell, AABB(Vector3(zone.position.x, 0.0, zone.position.y),
		Vector3(zone.size.x, 0.0, zone.size.y)))
	return _witch_roof_under(cell, local.end.y, gap, depth, wall_y, drop, thickness)


static func _witch_zone_clear(ctx: Dictionary, cell: Dictionary, zone: Rect2,
		props: Array, shelter: Dictionary, target_role: String) -> bool:
	var zone_box := AABB(Vector3(zone.position.x, 0.0, zone.position.y),
		Vector3(zone.size.x, WITCH_WORK_CLEARANCE, zone.size.y))
	for prop in props:
		if String(prop.get("role", "")) == target_role:
			continue
		if zone.intersects(Rect2(Vector2(HouseExterior.bounds_of(prop).position.x,
			HouseExterior.bounds_of(prop).position.z),
			Vector2(HouseExterior.bounds_of(prop).size.x, HouseExterior.bounds_of(prop).size.z))):
			return false
	for part in shelter["parts"]:
		var part_role := String(part["role"])
		if part_role.ends_with("_roof") or part_role.ends_with("_ledger"):
			continue
		if zone_box.intersects(part_aabb(part)):
			return false
	for accepted in ctx["accepted"]:
		var obstacle: AABB = accepted
		if obstacle.position.y + obstacle.size.y <= STEP or obstacle.position.y >= WITCH_WORK_CLEARANCE:
			continue
		var footprint := Rect2(Vector2(obstacle.position.x, obstacle.position.z),
			Vector2(obstacle.size.x, obstacle.size.z))
		if zone.intersects(footprint):
			return false
	return true


## The inn's signpost, out by the road edge where a rider reads it.
static func _signpost(ctx: Dictionary) -> Dictionary:
	var side: float = ctx["side_pref"]
	for flip in [1.0, -1.0]:
		var s: float = ctx["door_u"] + side * flip * 2.8
		var cell := _cell(ctx, "front", s)
		var d: float = float(cell["room"]) - 0.5
		if d < 1.0:
			continue
		var parts: Array = []
		parts.append(_part(cell, "sign_post", 0.0, d, 0.11, 0.11, 0.0, 2.35, "trim"))
		parts.append(_part(cell, "sign_arm", -side * flip * 0.4, d, 0.8, 0.06, 2.05, 0.06, "trim"))
		parts.append(_part(cell, "sign_board", -side * flip * 0.6, d, 0.62, 0.05, 1.5, 0.45, "trim"))
		var made := {"pieces": [_piece("signpost", "inn_sign", parts, "front")]}
		if _group_reason(ctx, made).is_empty():
			return made
	return {}


# ---------------------------------------------------------------------- anchors

static func _room_of(ctx: Dictionary, kind: StringName) -> int:
	var p: HousePlan = ctx["plan"]
	for i in p.rooms.size():
		if p.rooms[i]["kind"] == kind and HousePlan.record_storey(p.rooms[i]) == 0:
			return i
	return -1


## The wall region a ground-floor room touches, and where along it, preferring
## the back and sides to the front.
static func _kitchen_region(ctx: Dictionary) -> String:
	var info := _kitchen_info(ctx)
	return str(info.get("region", ""))


static func _kitchen_anchor(ctx: Dictionary, fallback: float) -> float:
	return float(_kitchen_info(ctx).get("s", fallback))


static func _kitchen_info(ctx: Dictionary) -> Dictionary:
	var p: HousePlan = ctx["plan"]
	var i := _room_of(ctx, &"kitchen")
	if i < 0:
		return {}
	var rect: Rect2 = p.rooms[i]["rect"]
	var inner := HouseGeometry.site_rect(p.spec).grow(-HouseGeometry.wall_thickness(p.spec))
	for region in ["rear", "left", "right", "front"]:
		var cell := _cell(ctx, region, 0.0)
		var out: Vector2 = cell["out"]
		if absf(_extent(rect, out) - _extent(inner, out)) < 0.4:
			return {"region": region, "s": rect.get_center().dot(cell["tan"] as Vector2)}
	return {}


## How far a rectangle reaches in a direction.
static func _extent(r: Rect2, dir: Vector2) -> float:
	var reach := -INF
	for c in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		reach = maxf(reach, (c as Vector2).dot(dir))
	return reach


static func _chimney_region(ctx: Dictionary) -> String:
	var p: HousePlan = ctx["plan"]
	if not p.spec.chimney:
		return ""
	var c := HouseGeometry.chimney_center(p)
	var site := HouseGeometry.site_rect(p.spec)
	if site.has_point(c):
		return ""
	for region in ["front", "rear", "left", "right"]:
		var cell := _cell(ctx, region, 0.0)
		var out: Vector2 = cell["out"]
		if c.dot(out) > float(ctx["ext_f"] if region in ["front", "rear"] else ctx["ext_l"]) - 0.3:
			return region
	return ""


static func _chimney_anchor(ctx: Dictionary) -> float:
	var region := _chimney_region(ctx)
	if region == "":
		return 0.0
	var c := HouseGeometry.chimney_center(ctx["plan"])
	var cell := _cell(ctx, region, 0.0)
	return c.dot(cell["tan"]) + 1.2 * float(ctx["side_pref"])


# ------------------------------------------------------------------ for checks

## Obstructions the yard puts on the ground: every prop and built part a person
## would have to walk round. Flush things and things overhead are not.
static func obstacles(plan: HousePlan) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for prop in plan.yard:
		var b := HouseExterior.bounds_of(prop)
		if b.position.y + b.size.y > STEP and b.position.y < HEAD:
			out.append(Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)))
	for piece in plan.yard_pieces:
		for part in piece["parts"]:
			var b := part_aabb(part)
			if b.position.y + b.size.y > STEP and b.position.y < HEAD:
				out.append(Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)))
	return out


## The access rule: the front door is reached from the road edge, and so is every
## ground-floor door the bare house would have been reached at. A shell whose own
## chimney stands in its back door is the shell's defect, not the yard's; the yard
## may only never make a reachable door unreachable.
static func access_ok(plan: HousePlan) -> bool:
	if plan.entrance() < 0 or not has_road_edge(plan):
		return true
	var with_yard := HouseExterior.reached_doors(plan, true)
	if plan.entrance() not in with_yard:
		return false
	for d in HouseExterior.reached_doors(plan, false):
		if d not in with_yard:
			return false
	return true


## The ground rectangle holding everything the yard actually placed (props and
## built pieces, the path included); empty when there is none.
static func extent(plan: HousePlan) -> Rect2:
	var r := Rect2()
	var first := true
	for p in plan.yard:
		var b := HouseExterior.bounds_of(p)
		var pr := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
		r = pr if first else r.merge(pr)
		first = false
	for piece in plan.yard_pieces:
		r = piece["rect"] if first else r.merge(piece["rect"])
		first = false
	return r


## The catalogue categories this house already puts outside, on the wall and in
## the yard: what a village dressing the same ground must not add again.
static func categories(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	for p in plan.exterior + plan.yard:
		var cat := PropCatalog.category(str(p["key"]))
		if cat != "" and cat not in out and str(p.get("host", "")) != "path":
			out.append(cat)
	out.sort()
	return out


## Where the road meets the yard on the line of the front door: the point the
## walk starts from.
static func road_point(plan: HousePlan) -> Vector2:
	var door: Dictionary = plan.doors[plan.entrance()]
	var env := HouseGeometry.yard_rect(plan)
	var n: Vector2 = door["normal"]
	var pos: Vector2 = door["pos"]
	var t := INF
	if absf(n.x) > 0.5:
		t = ((env.end.x if n.x > 0.0 else env.position.x) - pos.x) / n.x
	else:
		t = ((env.end.y if n.y > 0.0 else env.position.y) - pos.y) / n.y
	return pos + n * maxf(t - 0.12, 0.0)
